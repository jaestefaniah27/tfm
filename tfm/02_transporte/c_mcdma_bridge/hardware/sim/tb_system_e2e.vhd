-- tb_system_e2e.vhd  (VHDL-2008)
-- =============================================================================
-- Testbench end-to-end del sistema BRIDGE_TOP + BRIDGE_UART_ADAPTER +
-- MULTI_SERIAL_CORE (2 canales para velocidad de simulación).
--
-- Escenarios:
--   TEST-1  TX canal-0 (2 bytes: 0xA5, 0x3C) con loopback físico → verificar RX
--   TEST-2  TX canal-0 Y canal-1 simultáneos (1 byte cada uno) con loopback → verificar ambos
--   TEST-3  Inyección serie directa en canal-1 (0x55) sin usar la ruta TX → verificar RX
--
-- Resultado en salida estándar:
--   SIM_RESULT: PASS  /  SIM_RESULT: FAIL
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.STOP;
use STD.TEXTIO.ALL;

entity tb_system_e2e is
end entity;

architecture Behavioral of tb_system_e2e is

  -- ── Constantes de configuración ───────────────────────────────────────────
  constant N_CH        : integer := 2;
  constant CLK_PERIOD  : time    := 10 ns;        -- 100 MHz
  -- baud_sel=43 → 921 600 baud; bit_period ≈ 1085 ns
  constant BIT_PERIOD  : time    := 1085 ns;
  -- Registro AXI_UART_CONFIG para 921 600 baud, 8N1, LSB-first:
  --   [5:0]=43=0x2B, [7:6]=00, [10:8]=4(no parity), [13:11]=3(8b), [14]=0, [15]=0
  constant CFG_921K_8N1 : std_logic_vector(31 downto 0) := x"00001C2B";

  -- ── Reloj y reset ─────────────────────────────────────────────────────────
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- ── AXI-Stream TX (DMA→Bridge) ────────────────────────────────────────────
  signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tvalid : std_logic := '0';
  signal s_axis_tready : std_logic;
  signal s_axis_tlast  : std_logic := '0';

  -- ── AXI-Stream RX (Bridge→DMA) ────────────────────────────────────────────
  signal m_axis_tdata  : std_logic_vector(7 downto 0);
  signal m_axis_tvalid : std_logic;
  signal m_axis_tready : std_logic := '1';  -- siempre listo
  signal m_axis_tlast  : std_logic;

  -- ── AXI-Lite: UART config (s_axi_cfg) ─────────────────────────────────────
  signal cfg_awaddr  : std_logic_vector(5 downto 0)  := (others => '0');
  signal cfg_awvalid : std_logic := '0';
  signal cfg_awready : std_logic;
  signal cfg_wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal cfg_wstrb   : std_logic_vector(3 downto 0)  := "1111";
  signal cfg_wvalid  : std_logic := '0';
  signal cfg_wready  : std_logic;
  signal cfg_bresp   : std_logic_vector(1 downto 0);
  signal cfg_bvalid  : std_logic;
  signal cfg_bready  : std_logic := '1';
  signal cfg_araddr  : std_logic_vector(5 downto 0)  := (others => '0');
  signal cfg_arvalid : std_logic := '0';
  signal cfg_arready : std_logic;
  signal cfg_rdata   : std_logic_vector(31 downto 0);
  signal cfg_rresp   : std_logic_vector(1 downto 0);
  signal cfg_rvalid  : std_logic;
  signal cfg_rready  : std_logic := '1';

  -- ── BRIDGE_TOP ↔ BRIDGE_UART_ADAPTER ──────────────────────────────────────
  signal tx_din        : std_logic_vector(N_CH*9 - 1 downto 0);
  signal tx_send_s     : std_logic_vector(N_CH   - 1 downto 0);
  signal rx_fifo_rd_s  : std_logic_vector(N_CH   - 1 downto 0);
  signal baud_sel_s    : std_logic_vector(N_CH*6 - 1 downto 0);
  signal stop_bit_s    : std_logic_vector(N_CH*2 - 1 downto 0);
  signal parity_s      : std_logic_vector(N_CH*3 - 1 downto 0);
  signal data_bits_s   : std_logic_vector(N_CH*3 - 1 downto 0);
  signal bit_order_s   : std_logic_vector(N_CH   - 1 downto 0);
  signal slo_s         : std_logic_vector(N_CH   - 1 downto 0);
  signal rx_fifo_dout_s  : std_logic_vector(N_CH*8 - 1 downto 0);
  signal rx_fifo_empty_s : std_logic_vector(N_CH   - 1 downto 0);
  signal send_ok_s       : std_logic_vector(N_CH   - 1 downto 0);
  signal tx_rdy_s        : std_logic_vector(N_CH   - 1 downto 0);
  signal timeout_s       : std_logic_vector(N_CH   - 1 downto 0);
  signal EOAF_s          : std_logic;

  -- ── BRIDGE_UART_ADAPTER ↔ MULTI_SERIAL_CORE ──────────────────────────────
  signal ps_config_s    : std_logic_vector(N_CH*28 - 1 downto 0);
  signal ps_out_s       : std_logic_vector(N_CH*14 - 1 downto 0);
  signal tx_rdy_empty_s : std_logic_vector(N_CH*2  - 1 downto 0);

  -- ── Pines físicos UART ────────────────────────────────────────────────────
  signal uart_td  : std_logic_vector(N_CH-1 downto 0);
  signal uart_rd  : std_logic_vector(N_CH-1 downto 0) := (others => '1');
  signal uart_de  : std_logic_vector(N_CH-1 downto 0);
  signal uart_slo : std_logic_vector(N_CH-1 downto 0);

  -- ── Control del loopback y de inyección serial ────────────────────────────
  signal use_loop  : std_logic := '1';  -- '1'=loopback, '0'=inyección directa
  signal inj_ch1   : std_logic := '1';  -- inyección manual en canal-1 (idle='1')

  -- ── Monitor: recolección de bytes recibidos ───────────────────────────────
  type byte_array_t is array (0 to 63) of std_logic_vector(7 downto 0);
  signal rx_buf   : byte_array_t := (others => (others => '0'));
  signal rx_cnt   : integer := 0;

  -- ── AXI-Lite TX ISR (tie a idle) ─────────────────────────────────────────
  constant TX_AXI_AWADDR  : std_logic_vector(3 downto 0) := (others => '0');

begin

  -- ===========================================================================
  -- Reloj
  -- ===========================================================================
  clk <= not clk after CLK_PERIOD / 2;

  -- ===========================================================================
  -- Loopback / inyección
  -- ===========================================================================
  uart_rd(0) <= uart_td(0);
  uart_rd(1) <= uart_td(1) when use_loop = '1' else inj_ch1;

  -- ===========================================================================
  -- Instancia: BRIDGE_TOP  (N_CH=2)
  -- ===========================================================================
  UUT_BT : entity work.BRIDGE_TOP
    generic map (N_CH => N_CH)
    port map (
      aclk    => clk,
      aresetn => aresetn,
      -- AXI-Stream TX
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tlast  => s_axis_tlast,
      -- AXI-Stream RX
      m_axis_tdata  => m_axis_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready,
      m_axis_tlast  => m_axis_tlast,
      -- AXI-Lite TX ISR (idle)
      s_axi_tx_awaddr  => TX_AXI_AWADDR,
      s_axi_tx_awvalid => '0',
      s_axi_tx_awready => open,
      s_axi_tx_wdata   => (others => '0'),
      s_axi_tx_wstrb   => "1111",
      s_axi_tx_wvalid  => '0',
      s_axi_tx_wready  => open,
      s_axi_tx_bresp   => open,
      s_axi_tx_bvalid  => open,
      s_axi_tx_bready  => '1',
      s_axi_tx_araddr  => TX_AXI_AWADDR,
      s_axi_tx_arvalid => '0',
      s_axi_tx_arready => open,
      s_axi_tx_rdata   => open,
      s_axi_tx_rresp   => open,
      s_axi_tx_rvalid  => open,
      s_axi_tx_rready  => '1',
      EOAF             => EOAF_s,
      -- AXI-Lite UART config
      s_axi_cfg_awaddr  => cfg_awaddr,
      s_axi_cfg_awvalid => cfg_awvalid,
      s_axi_cfg_awready => cfg_awready,
      s_axi_cfg_wdata   => cfg_wdata,
      s_axi_cfg_wstrb   => cfg_wstrb,
      s_axi_cfg_wvalid  => cfg_wvalid,
      s_axi_cfg_wready  => cfg_wready,
      s_axi_cfg_bresp   => open,
      s_axi_cfg_bvalid  => cfg_bvalid,
      s_axi_cfg_bready  => cfg_bready,
      s_axi_cfg_araddr  => (others => '0'),
      s_axi_cfg_arvalid => '0',
      s_axi_cfg_arready => open,
      s_axi_cfg_rdata   => open,
      s_axi_cfg_rresp   => open,
      s_axi_cfg_rvalid  => open,
      s_axi_cfg_rready  => '1',
      -- Interfaz hacia UART cores (→ BRIDGE_UART_ADAPTER)
      tx_din        => tx_din,
      tx_send       => tx_send_s,
      send_ok       => send_ok_s,
      tx_rdy        => tx_rdy_s,
      rx_fifo_dout  => rx_fifo_dout_s,
      rx_fifo_empty => rx_fifo_empty_s,
      rx_fifo_rd    => rx_fifo_rd_s,
      timeout       => timeout_s,
      baud_sel      => baud_sel_s,
      stop_bit      => stop_bit_s,
      parity        => parity_s,
      data_bits     => data_bits_s,
      bit_order     => bit_order_s,
      slo           => slo_s
    );

  -- ===========================================================================
  -- Instancia: BRIDGE_UART_ADAPTER  (N_CH=2)
  -- ===========================================================================
  UUT_ADAPT : entity work.BRIDGE_UART_ADAPTER
    generic map (N_CH => N_CH)
    port map (
      tx_din        => tx_din,
      tx_send       => tx_send_s,
      rx_fifo_rd    => rx_fifo_rd_s,
      baud_sel      => baud_sel_s,
      stop_bit      => stop_bit_s,
      parity        => parity_s,
      data_bits     => data_bits_s,
      bit_order     => bit_order_s,
      slo_cfg       => slo_s,
      ps_config     => ps_config_s,
      ps_out        => ps_out_s,
      tx_rdy_empty  => tx_rdy_empty_s,
      rx_fifo_dout  => rx_fifo_dout_s,
      rx_fifo_empty => rx_fifo_empty_s,
      send_ok       => send_ok_s,
      tx_rdy        => tx_rdy_s,
      timeout       => timeout_s
    );

  -- ===========================================================================
  -- Instancia: MULTI_SERIAL_CORE  (N=2)
  -- ===========================================================================
  UUT_MSC : entity work.MULTI_SERIAL_CORE
    generic map (
      N        => N_CH,
      USE_DE   => true,
      USE_SLO  => true,
      DE_MASK  => x"00000003",
      SLO_MASK => x"00000003"
    )
    port map (
      clk          => clk,
      aresetn      => aresetn,
      ps_config    => ps_config_s,
      ps_out       => ps_out_s,
      tx_rdy_empty => tx_rdy_empty_s,
      TD           => uart_td,
      RD           => uart_rd,
      DE           => uart_de,
      SLO          => uart_slo
    );

  -- ===========================================================================
  -- Monitor: captura bytes de m_axis
  -- ===========================================================================
  proc_monitor : process(clk)
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        rx_cnt <= 0;
      elsif m_axis_tvalid = '1' and m_axis_tready = '1' then
        if rx_cnt < 64 then
          rx_buf(rx_cnt) <= m_axis_tdata;
          rx_cnt <= rx_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  -- ===========================================================================
  -- Estímulo principal
  -- ===========================================================================
  proc_stim : process

    -- Todas las variables declaradas aquí (XSim no soporta bloques declare/begin)
    variable found_a5   : boolean;
    variable found_3c   : boolean;
    variable found_de   : boolean;
    variable found_ad   : boolean;
    variable found_55   : boolean;
    variable base_cnt_2 : integer;
    variable base_cnt_3 : integer;
    variable L          : line;

    -- ── Esperar N flancos de subida ──────────────────────────────────────────
    procedure wait_clk(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- ── Escritura AXI-Lite a s_axi_cfg ──────────────────────────────────────
    procedure cfg_write(
      constant addr : in std_logic_vector(5 downto 0);
      constant data : in std_logic_vector(31 downto 0)
    ) is begin
      cfg_awaddr  <= addr;
      cfg_awvalid <= '1';
      cfg_wdata   <= data;
      cfg_wstrb   <= "1111";
      cfg_wvalid  <= '1';
      wait until rising_edge(clk) and cfg_awready = '1' and cfg_wready = '1';
      cfg_awvalid <= '0';
      cfg_wvalid  <= '0';
      wait until rising_edge(clk) and cfg_bvalid = '1';
      wait_clk(1);
    end procedure;

    -- ── Envío de un byte por AXI-Stream TX ───────────────────────────────────
    procedure axis_send(
      constant data    : in std_logic_vector(7 downto 0);
      constant is_last : in boolean
    ) is begin
      s_axis_tdata  <= data;
      s_axis_tvalid <= '1';
      if is_last then
        s_axis_tlast <= '1';
      else
        s_axis_tlast <= '0';
      end if;
      wait until rising_edge(clk) and s_axis_tready = '1';
      s_axis_tvalid <= '0';
      s_axis_tlast  <= '0';
    end procedure;

    -- ── Inyección de un byte UART serie (LSB first, 1 stop bit) ─────────────
    procedure uart_inject(
      signal rx_pin : out std_logic;
      constant data : in  std_logic_vector(7 downto 0)
    ) is begin
      rx_pin <= '0';
      wait for BIT_PERIOD;
      for i in 0 to 7 loop
        rx_pin <= data(i);
        wait for BIT_PERIOD;
      end loop;
      rx_pin <= '1';
      wait for BIT_PERIOD;
    end procedure;

    -- ── Esperar N bytes en m_axis (con timeout en ciclos) ────────────────────
    procedure wait_rx_bytes(constant n : in integer; constant timeout_cycles : in integer) is
      variable cnt : integer := 0;
    begin
      while rx_cnt < n and cnt < timeout_cycles loop
        wait until rising_edge(clk);
        cnt := cnt + 1;
      end loop;
    end procedure;

  begin

    -- =========================================================================
    -- RESET
    -- =========================================================================
    aresetn <= '0';
    wait_clk(20);
    aresetn <= '1';
    wait_clk(5);

    -- =========================================================================
    -- CONFIGURACIÓN: 921 600 baud, 8N1 en ambos canales
    -- =========================================================================
    write(L, string'("[CONFIG] Escribiendo 921600 8N1 en canales 0 y 1..."));
    writeline(output, L);

    cfg_write("000000", CFG_921K_8N1);   -- canal 0: offset 0x00
    cfg_write("000100", CFG_921K_8N1);   -- canal 1: offset 0x04
    wait_clk(5);

    -- =========================================================================
    -- TEST-1: TX canal-0 (2 bytes: 0xA5, 0x3C) con loopback
    -- =========================================================================
    write(L, string'("[TEST-1] TX->CH0 loopback: 0xA5, 0x3C ..."));
    writeline(output, L);

    axis_send(x"00", false);   -- {ch=0, len[11:8]=0}
    axis_send(x"02", false);   -- len[7:0]=2
    axis_send(x"A5", false);   -- payload byte 0
    axis_send(x"3C", true);    -- payload byte 1, TLAST

    -- 2 bytes a 921600 baud: TX+RX ≈ 2×1085 ciclos por byte + pipeline ≈ 25000 ciclos total
    wait_rx_bytes(4, 40000);

    if rx_cnt < 4 then
      write(L, string'("FAIL [TEST-1]: Solo ") & integer'image(rx_cnt) &
               string'(" bytes recibidos (esperado 4)"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    found_a5 := false;
    found_3c := false;
    for i in 0 to rx_cnt - 2 loop
      if rx_buf(i) = x"00" and rx_buf(i+1) = x"A5" then found_a5 := true; end if;
      if rx_buf(i) = x"00" and rx_buf(i+1) = x"3C" then found_3c := true; end if;
    end loop;

    if not found_a5 then
      write(L, string'("FAIL [TEST-1]: Par {0x00, 0xA5} no encontrado en m_axis"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;
    if not found_3c then
      write(L, string'("FAIL [TEST-1]: Par {0x00, 0x3C} no encontrado en m_axis"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    write(L, string'("[TEST-1] PASS"));
    writeline(output, L);

    -- =========================================================================
    -- TEST-2: TX simultáneo canal-0 (0xDE) y canal-1 (0xAD) con loopback
    -- =========================================================================
    write(L, string'("[TEST-2] TX->CH0(0xDE) y CH1(0xAD) simultaneo..."));
    writeline(output, L);

    base_cnt_2 := rx_cnt;

    axis_send(x"00", false);   -- ch=0, len_hi=0
    axis_send(x"01", false);   -- len=1
    axis_send(x"DE", true);    -- dato, TLAST
    wait_clk(2);
    axis_send(x"10", false);   -- ch=1, len_hi=0
    axis_send(x"01", false);   -- len=1
    axis_send(x"AD", true);    -- dato, TLAST

    -- 1 byte por canal con loopback: misma latencia que TEST-1 ≈ 25000 ciclos por canal
    wait_rx_bytes(base_cnt_2 + 4, 40000);

    if rx_cnt < base_cnt_2 + 4 then
      write(L, string'("FAIL [TEST-2]: Solo ") & integer'image(rx_cnt - base_cnt_2) &
               string'(" bytes nuevos (esperado 4)"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    found_de := false;
    found_ad := false;
    for i in base_cnt_2 to rx_cnt - 2 loop
      if rx_buf(i) = x"00" and rx_buf(i+1) = x"DE" then found_de := true; end if;
      if rx_buf(i) = x"01" and rx_buf(i+1) = x"AD" then found_ad := true; end if;
    end loop;

    if not found_de then
      write(L, string'("FAIL [TEST-2]: Par {0x00, 0xDE} (CH0) no encontrado"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;
    if not found_ad then
      write(L, string'("FAIL [TEST-2]: Par {0x01, 0xAD} (CH1) no encontrado"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    write(L, string'("[TEST-2] PASS"));
    writeline(output, L);

    -- =========================================================================
    -- TEST-3: Inyección serie directa en canal-1 (0x55), sin ruta TX
    -- =========================================================================
    write(L, string'("[TEST-3] Inyeccion serie directa CH1 <- 0x55 ..."));
    writeline(output, L);

    base_cnt_3 := rx_cnt;
    use_loop <= '0';
    wait_clk(2);
    uart_inject(inj_ch1, x"55");
    use_loop <= '1';

    wait_rx_bytes(base_cnt_3 + 2, 8000);

    if rx_cnt < base_cnt_3 + 2 then
      write(L, string'("FAIL [TEST-3]: Byte inyectado no llego a m_axis (") &
               integer'image(rx_cnt - base_cnt_3) & string'(" bytes recibidos)"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    found_55 := false;
    for i in base_cnt_3 to rx_cnt - 2 loop
      if rx_buf(i) = x"01" and rx_buf(i+1) = x"55" then found_55 := true; end if;
    end loop;

    if not found_55 then
      write(L, string'("FAIL [TEST-3]: Par {0x01, 0x55} no encontrado en m_axis"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    write(L, string'("[TEST-3] PASS"));
    writeline(output, L);

    -- =========================================================================
    -- FIN
    -- =========================================================================
    write(L, string'("SIM_RESULT: PASS"));
    writeline(output, L);
    wait_clk(10);
    stop;

  end process;

end Behavioral;
