-- UART_AXIS_TOP.vhd
-- Wrapper sobre CONFIGURABLE_SERIAL_TOP que expone:
--   · S_AXI      : AXI-Lite esclavo para el registro de configuración
--   · S_AXIS_TX  : AXI-Stream esclavo para datos TX (desde MCDMA MM2S)
--   · M_AXIS_RX  : AXI-Stream maestro para datos RX (hacia MCDMA S2MM)
--
-- Bit-packing del registro de config (offset 0x00, igual que antes en GPIO CH1):
--   [8:0]  = DataIn TX  (uso interno, no escrito por SW)
--   [9]    = TX_Send    (uso interno)
--   [10]   = ERROR_OK   (fijo a '1')
--   [11]   = Data_read  (uso interno)
--   [17:12]= baud_sel
--   [19:18]= stop_bits
--   [22:20]= parity
--   [25:23]= data_bits
--   [26]   = bit_order
--   [27]   = SLO
--
-- TLAST se aserta en cada byte recibido (1 byte = 1 frame AXI-Stream).
-- El ISR del MCDMA coalesce via IRQTHRESH=64 → 64× menos IRQs que con GPIO.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UART_AXIS_TOP is
  generic (
    -- Identificador de canal (TDEST). El switch RX (14→1) NO inyecta TDEST
    -- automáticamente; cada UART debe emitir su propio TDEST = índice de canal
    -- para que el MCDMA S2MM demultiplexe correctamente hacia su canal.
    CH_ID : integer := 0;
    -- Settling de DE (ver TX_CONFIGURABLE_SERIAL). Default 10000=100us @100MHz.
    -- El testbench lo baja a ~16 para acelerar la simulación.
    DELAY_CYCLES : integer := 10000
  );
  port (
    -- ----------------------------------------------------------------
    -- Sistema
    -- ----------------------------------------------------------------
    aclk    : in std_logic;
    aresetn : in std_logic;   -- Activo en bajo (igual que peripheral_aresetn del Zynq)

    -- ----------------------------------------------------------------
    -- AXI-Lite esclavo — registro de configuración único (offset 0x00)
    -- ----------------------------------------------------------------
    s_axi_awaddr  : in  std_logic_vector(3 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(3 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- ----------------------------------------------------------------
    -- AXI-Stream TX esclavo (MCDMA MM2S → UART TX)
    -- ----------------------------------------------------------------
    s_axis_tx_tdata  : in  std_logic_vector(7 downto 0);
    s_axis_tx_tvalid : in  std_logic;
    s_axis_tx_tready : out std_logic;

    -- ----------------------------------------------------------------
    -- AXI-Stream RX maestro (UART RX → MCDMA S2MM)
    -- ----------------------------------------------------------------
    m_axis_rx_tdata  : out std_logic_vector(7 downto 0);
    m_axis_rx_tvalid : out std_logic;
    m_axis_rx_tready : in  std_logic;
    m_axis_rx_tlast  : out std_logic;
    m_axis_rx_tdest  : out std_logic_vector(3 downto 0);  -- = CH_ID (canal S2MM destino)

    -- ----------------------------------------------------------------
    -- Pines físicos UART
    -- ----------------------------------------------------------------
    TD  : out std_logic;
    RD  : in  std_logic;
    DE  : out std_logic;
    SLO : out std_logic;

    -- DEBUG (simulación): {EMPTY, Fifo_write, Valid_out, LineRD_in}. Open en el BD.
    dbg_rx : out std_logic_vector(3 downto 0) := (others => '0')
  );
end UART_AXIS_TOP;

architecture RTL of UART_AXIS_TOP is

  component CONFIGURABLE_SERIAL_TOP
    generic (
      DELAY_CYCLES : integer := 10000
    );
    port (
      Reset            : in  std_logic;
      Clk              : in  std_logic;
      PS_out           : out std_logic_vector(13 downto 0);
      PS_SERIAL_CONFIG : in  std_logic_vector(27 downto 0);
      TX_RDY_EMPTY     : out std_logic_vector(1 downto 0);
      TD               : out std_logic;
      RD               : in  std_logic;
      DE               : out std_logic;
      SLO              : out std_logic;
      dbg_rx           : out std_logic_vector(3 downto 0)
    );
  end component;

  -- ----------------------------------------------------------------
  -- Señales hacia CONFIGURABLE_SERIAL_TOP
  -- ----------------------------------------------------------------
  signal ps_config    : std_logic_vector(27 downto 0);
  signal ps_out_sig   : std_logic_vector(13 downto 0);
  signal trdy_empty   : std_logic_vector(1 downto 0);

  signal tx_rdy       : std_logic;   -- '1' = núcleo TX listo para nuevo byte
  signal rx_empty     : std_logic;   -- '1' = FIFO RX vacío

  -- ----------------------------------------------------------------
  -- Estado TX
  -- ----------------------------------------------------------------
  signal tx_data_ff   : std_logic_vector(8 downto 0);
  signal tx_send      : std_logic;
  signal tx_pending   : std_logic;   -- '1' = byte aceptado, esperando que el core arranque

  -- ----------------------------------------------------------------
  -- Estado RX
  -- ----------------------------------------------------------------
  signal data_read    : std_logic;
  signal rx_data_out  : std_logic_vector(8 downto 0);

  -- Register slice de salida RX: retiene 1 byte y garantiza exactamente
  -- 1 lectura del FIFO por byte presentado (robusto frente al timing de TREADY)
  signal rx_hold       : std_logic_vector(7 downto 0);
  signal rx_hold_valid : std_logic;
  signal rx_pop        : std_logic;   -- pulso de 1 ciclo: sacar byte del FIFO

  -- ----------------------------------------------------------------
  -- Registro de configuración AXI-Lite
  -- ----------------------------------------------------------------
  signal cfg_reg      : std_logic_vector(31 downto 0);

  -- FSM AXI-Lite simplificada
  type axi_t is (S_IDLE, S_WRITE_RESP, S_READ_DATA);
  signal axi_st : axi_t;

  signal aw_rdy : std_logic;
  signal w_rdy  : std_logic;
  signal b_vld  : std_logic;
  signal ar_rdy : std_logic;
  signal r_vld  : std_logic;
  signal r_dat  : std_logic_vector(31 downto 0);

begin

  -- ================================================================
  -- Ensamblado de PS_SERIAL_CONFIG
  --  [8:0]   = byte TX (latched)
  --  [9]     = TX_Send (pulso)
  --  [10]    = ERROR_OK (constante '1')
  --  [11]    = Data_read (pulso)
  --  [27:12] = bits de config del registro AXI-Lite
  -- ================================================================
  ps_config <= cfg_reg(27 downto 12) & data_read & '1' & tx_send & tx_data_ff;

  -- ================================================================
  -- Instancia del núcleo UART
  -- ================================================================
  UART_CORE : CONFIGURABLE_SERIAL_TOP
    generic map (
      DELAY_CYCLES => DELAY_CYCLES )
    port map (
      Reset            => aresetn,
      Clk              => aclk,
      PS_out           => ps_out_sig,
      PS_SERIAL_CONFIG => ps_config,
      TX_RDY_EMPTY     => trdy_empty,
      TD               => TD,
      RD               => RD,
      DE               => DE,
      SLO              => SLO,
      dbg_rx           => dbg_rx
    );

  -- TX_RDY_EMPTY: bit1 = TX_RDY_sig, bit0 = EMPTY_sig
  tx_rdy      <= trdy_empty(1);
  rx_empty    <= trdy_empty(0);
  rx_data_out <= ps_out_sig(8 downto 0);

  -- ================================================================
  -- AXI-Stream TX esclavo — handshake de UN byte por transmisión
  --
  -- PROBLEMA (antes): tready = tx_rdy (= EOT, nivel). Tras aceptar un byte,
  -- EOT sigue alto varios ciclos (hasta que el core arranca StartTX→PreDE).
  -- El DMA MM2S, con tvalid alto, metía 3-4 bytes en esos ciclos sobrescribiendo
  -- tx_data_ff → solo se transmitía ~1 de cada 4 ("every 4th byte").
  --
  -- FIX: tx_pending. Se acepta UN byte; tready baja hasta que el core lo consume
  -- (EOT cae a 0 = arrancó). Garantiza 1 byte aceptado por transmisión.
  -- ================================================================
  s_axis_tx_tready <= tx_rdy and not tx_pending;

  p_tx : process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        tx_send    <= '0';
        tx_data_ff <= (others => '0');
        tx_pending <= '0';
      else
        tx_send <= '0';
        -- aceptar UN byte cuando el core está listo y no hay otro pendiente
        if s_axis_tx_tvalid = '1' and tx_rdy = '1' and tx_pending = '0' then
          tx_data_ff <= '0' & s_axis_tx_tdata;
          tx_send    <= '1';
          tx_pending <= '1';
        end if;
        -- el core arrancó (EOT/tx_rdy cayó a 0) → byte consumido, listo el siguiente
        if tx_pending = '1' and tx_rdy = '0' then
          tx_pending <= '0';
        end if;
      end if;
    end if;
  end process p_tx;

  -- ================================================================
  -- AXI-Stream RX maestro — register slice de 1 byte
  --
  -- Presenta EXACTAMENTE un byte (rx_hold) por beat. El FIFO se lee una sola
  -- vez por byte (pulso rx_pop), y no se carga el siguiente hasta que el actual
  -- se acepta (tvalid & tready). Esto hace la salida correcta sea cual sea el
  -- comportamiento de TREADY del DMA:
  --   · Antes (rd_en = flanco de Data_read): relecturas → bytes triplicados.
  --   · Luego (rd_en = nivel = not empty and tready): el DMA, con TREADY alto
  --     varios ciclos y LENGTH=1, sacaba varios bytes del FIFO y solo guardaba
  --     uno → se perdían 3 de cada 4.
  --   · Ahora: 1 lectura de FIFO por byte, 1 byte por beat. Sin pérdidas.
  --
  -- rx_pop pulsa cuando el hold está vacío y el FIFO tiene dato; el núcleo hace
  -- rd_en = (not empty) and Data_read, con Data_read = rx_pop.
  -- ================================================================
  m_axis_rx_tvalid <= rx_hold_valid;
  m_axis_rx_tdata  <= rx_hold;
  m_axis_rx_tlast  <= rx_hold_valid;   -- 1 byte = 1 paquete
  m_axis_rx_tdest  <= std_logic_vector(to_unsigned(CH_ID, 4));

  rx_pop    <= (not rx_hold_valid) and (not rx_empty);
  data_read <= rx_pop;

  p_rx : process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        rx_hold_valid <= '0';
        rx_hold       <= (others => '0');
      else
        -- aceptar beat: liberar el hold cuando el consumidor toma el byte
        if rx_hold_valid = '1' and m_axis_rx_tready = '1' then
          rx_hold_valid <= '0';
        end if;
        -- cargar siguiente byte del FIFO (FWFT: dout válido en el ciclo de pop)
        if rx_pop = '1' then
          rx_hold       <= rx_data_out(7 downto 0);
          rx_hold_valid <= '1';
        end if;
      end if;
    end if;
  end process p_rx;

  -- ================================================================
  -- AXI-Lite esclavo — registro único en offset 0x00
  -- ================================================================
  s_axi_awready <= aw_rdy;
  s_axi_wready  <= w_rdy;
  s_axi_bresp   <= "00";
  s_axi_bvalid  <= b_vld;
  s_axi_arready <= ar_rdy;
  s_axi_rdata   <= r_dat;
  s_axi_rresp   <= "00";
  s_axi_rvalid  <= r_vld;

  p_axi : process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        cfg_reg <= (others => '0');
        aw_rdy  <= '0'; w_rdy  <= '0'; b_vld <= '0';
        ar_rdy  <= '0'; r_vld  <= '0'; r_dat <= (others => '0');
        axi_st  <= S_IDLE;
      else
        aw_rdy <= '0';
        w_rdy  <= '0';
        ar_rdy <= '0';

        case axi_st is
          when S_IDLE =>
            if b_vld = '1' and s_axi_bready = '1' then b_vld <= '0'; end if;
            if r_vld = '1' and s_axi_rready = '1' then r_vld <= '0'; end if;

            if s_axi_awvalid = '1' and s_axi_wvalid = '1' then
              aw_rdy  <= '1';
              w_rdy   <= '1';
              cfg_reg <= s_axi_wdata;
              b_vld   <= '1';
              axi_st  <= S_WRITE_RESP;
            elsif s_axi_arvalid = '1' then
              ar_rdy <= '1';
              r_dat  <= cfg_reg;
              r_vld  <= '1';
              axi_st <= S_READ_DATA;
            end if;

          when S_WRITE_RESP =>
            if s_axi_bready = '1' then
              b_vld  <= '0';
              axi_st <= S_IDLE;
            end if;

          when S_READ_DATA =>
            if s_axi_rready = '1' then
              r_vld  <= '0';
              axi_st <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process p_axi;

end RTL;
