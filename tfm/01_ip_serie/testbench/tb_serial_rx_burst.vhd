----------------------------------------------------------------------------------
-- tb_serial_rx_burst
--
-- El unico bloque del camino de RX que nunca se habia simulado:
-- CONFIGURABLE_SERIAL, el receptor de la UART que ESCRIBE en fifo_rx.
--
-- Reproduce T2 sobre un canal: 1024 bytes seguidos a 115200 8N1 por la linea
-- serie, con la fifo_rx real dentro del core y el BRIDGE_RX_TOP real leyendola
-- (prog_full + timeout + handshake timeout_ok, igual que en la placa).
--
-- En la placa este caso entrega UN paquete de 514 bytes y el canal enmudece.
--
-- Se cuentan por separado:
--   bytes_wr   : pulsos de Fifo_write  -> bytes que el RX mete en la FIFO
--   bytes_axis : beats del AXI-Stream  -> bytes que salen hacia el MCDMA
--   full_hits  : ciclos con la FIFO llena (byte perdido: wr_en no mira full)
-- Si bytes_wr < 1024, el receptor deja de escribir: la causa esta en el core.
-- Si bytes_wr = 1024 y bytes_axis < 1024, se pierden aguas abajo.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_serial_rx_burst is
end tb_serial_rx_burst;

architecture sim of tb_serial_rx_burst is

  constant CLK_P   : time    := 10 ns;          -- 100 MHz
  constant BIT_T   : time    := 8681 ns;        -- 115200 baudios
  constant N_BYTES : integer := 1024;

  signal clk    : std_logic := '0';
  signal resetn : std_logic := '0';

  -- Linea serie (reposo '1', wired-AND RS485)
  signal line_rd : std_logic := '1';

  -- CONFIGURABLE_SERIAL
  signal data_out  : std_logic_vector(8 downto 0);
  signal data_read : std_logic;
  signal fifo_full : std_logic;
  signal fifo_empty: std_logic;
  signal prog_full : std_logic;
  signal timeout   : std_logic;
  signal timeout_ok: std_logic;
  signal dbg_rx    : std_logic_vector(3 downto 0);

  -- BRIDGE_RX_TOP (un canal)
  signal m_tdata  : std_logic_vector(7 downto 0);
  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '1';
  signal m_tlast  : std_logic;
  signal m_tdest  : std_logic_vector(3 downto 0);

  signal top_rd     : std_logic_vector(0 downto 0);
  signal top_empty  : std_logic_vector(0 downto 0);
  signal top_pfull  : std_logic_vector(0 downto 0);
  signal top_tmo    : std_logic_vector(0 downto 0);
  signal top_tmo_ok : std_logic_vector(0 downto 0);

  -- Metricas
  signal bytes_wr   : integer := 0;
  signal bytes_axis : integer := 0;
  signal pkt_count  : integer := 0;
  signal full_hits  : integer := 0;
  signal tx_done    : boolean := false;

  -- Envia un byte 8N1 por la linea
  procedure uart_send(signal l : out std_logic; b : in integer) is
    variable v : std_logic_vector(7 downto 0);
  begin
    v := std_logic_vector(to_unsigned(b, 8));
    l <= '0';  wait for BIT_T;                       -- start
    for i in 0 to 7 loop
      l <= v(i);  wait for BIT_T;                    -- LSB first
    end loop;
    l <= '1';  wait for BIT_T;                       -- stop
  end procedure;

begin

  clk <= not clk after CLK_P / 2;

  u_serial : entity work.CONFIGURABLE_SERIAL
    port map (
      Reset => resetn, Clk => clk,
      Data_in => (others => '0'), TX_Send => '0',
      TX_RDY => open, Send_ok => open, DE => open, TD => open,
      RD => line_rd,
      Data_out => data_out, Data_read => data_read,
      Full => fifo_full, Empty => fifo_empty,
      PAR_ERROR => open, FRAME_ERROR => open,
      ERROR_OK => '1',                 -- igual que en BRIDGE_AND_SERIALs
      Timeout => timeout, Timeout_ok => timeout_ok,
      Prog_Full => prog_full,
      baud_sel => "011101",            -- 29 = 115200
      stop_bit => "01",                -- 1 stop
      parity   => "100",               -- sin paridad
      bit_order => '0',                -- LSB first
      data_bits => "011",              -- 8 bits
      dbg_rx => dbg_rx);

  top_empty(0) <= fifo_empty;
  top_pfull(0) <= prog_full;
  top_tmo(0)   <= timeout;
  data_read    <= top_rd(0);
  timeout_ok   <= top_tmo_ok(0);

  u_top : entity work.BRIDGE_RX_TOP
    generic map (N_CH => 1)
    port map (
      aclk => clk, aresetn => resetn,
      m_axis_tdata => m_tdata, m_axis_tvalid => m_tvalid,
      m_axis_tready => m_tready, m_axis_tlast => m_tlast,
      m_axis_tdest => m_tdest,
      timeout_in => top_tmo, timeout_ok_out => top_tmo_ok,
      rx_fifo_empty => top_empty, rx_fifo_prog_full => top_pfull,
      rx_fifo_dout => data_out(7 downto 0), rx_fifo_rd => top_rd);

  -- ── Transmisor: 1024 bytes SEGUIDOS, sin huecos entre tramas ────────────
  tx_proc : process
  begin
    resetn  <= '0';
    line_rd <= '1';
    wait for 50 * CLK_P;
    resetn <= '1';
    wait for 200 * CLK_P;

    for i in 0 to N_BYTES - 1 loop
      uart_send(line_rd, i mod 256);
    end loop;

    tx_done <= true;
    wait for 20 ms;   -- silencio: deja que salte el Timeout y drene la cola

    report "=========== RESULTADO ===========" severity note;
    report "bytes enviados por la linea : " & integer'image(N_BYTES)     severity note;
    report "bytes escritos en la FIFO   : " & integer'image(bytes_wr)    severity note;
    report "ciclos con FIFO llena       : " & integer'image(full_hits)   severity note;
    report "bytes salidos por AXI-Stream: " & integer'image(bytes_axis)  severity note;
    report "paquetes (TLAST)            : " & integer'image(pkt_count)   severity note;

    if bytes_wr < N_BYTES then
      report "FALLO: el RX de CONFIGURABLE_SERIAL deja de escribir en la FIFO"
        severity error;
    elsif bytes_axis < bytes_wr then
      report "FALLO: se pierden bytes aguas abajo de la FIFO" severity error;
    else
      report "OK: los 1024 bytes atraviesan el camino completo" severity note;
    end if;
    std.env.stop;
  end process;

  -- dbg_rx = {empty, Fifo_write, Valid_out, RD}
  mon_wr : process(clk)
  begin
    if rising_edge(clk) then
      if dbg_rx(2) = '1' then bytes_wr <= bytes_wr + 1; end if;
      if fifo_full = '1' then full_hits <= full_hits + 1; end if;
    end if;
  end process;

  mon_axis : process(clk)
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        bytes_axis <= bytes_axis + 1;
        if m_tlast = '1' then
          pkt_count <= pkt_count + 1;
          report "paquete #" & integer'image(pkt_count + 1) &
                 " cerrado tras " & integer'image(bytes_axis + 1) & " bytes"
                 severity note;
        end if;
      end if;
    end if;
  end process;

end sim;
