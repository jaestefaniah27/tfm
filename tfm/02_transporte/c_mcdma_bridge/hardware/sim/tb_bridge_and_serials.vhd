-- tb_bridge_and_serials.vhd  (VHDL-2008)
-- =============================================================================
-- Testbench de BRIDGE_AND_SERIALs (N_CH=2).
-- Loopback físico: TD(i) → RD(i) en ambos canales.
--
-- El reset del AXI_UART_CONFIG (Verilog) inicializa baud_sel=43 (921600 bps),
-- 8N1, LSB-first. No es necesario configurar por AXI-Lite para que funcione.
--
-- Escenarios:
--   TEST-1  TX ch0, 1 byte (0xA5) con loopback → m_axis_tdata = 0xA5
--   TEST-2  TX ch0 (0xDE) y ch1 (0xAD) consecutivo → ambos aparecen en m_axis
--   TEST-3  Inyección serie directa en RD(1) (0x55) → m_axis_tdata = 0x55
--
-- El DRAIN envía 1 beat por byte recibido (m_axis_tdest=canal, m_axis_tdata=dato).
-- BRIDGE_AND_SERIALs no expone tdest, verificamos sólo los valores de tdata.
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.STOP;
use STD.TEXTIO.ALL;

entity tb_bridge_and_serials is
end entity;

architecture Behavioral of tb_bridge_and_serials is

  constant N_CH       : integer := 2;
  constant CLK_PERIOD : time    := 10 ns;
  -- baud_sel=44 → 1000000 baud; bit_period ≈ 1000 ns
  constant BIT_PERIOD : time    := 1000 ns;

  -- ── Reloj y reset ─────────────────────────────────────────────────────────
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  -- ── AXI-Stream TX ─────────────────────────────────────────────────────────
  signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tvalid : std_logic := '0';
  signal s_axis_tready : std_logic;
  signal s_axis_tlast  : std_logic := '0';

  -- ── AXI-Stream RX ─────────────────────────────────────────────────────────
  signal m_axis_tdata  : std_logic_vector(7 downto 0);
  signal m_axis_tvalid : std_logic;
  signal m_axis_tready : std_logic := '1';
  signal m_axis_tlast  : std_logic;

  -- ── AXI-Lite TX ISR (idle) ────────────────────────────────────────────────
  constant AXI_ZERO4  : std_logic_vector(3 downto 0) := (others => '0');

  -- ── AXI-Lite UART config ──────────────────────────────────────────────────
  signal cfg_awaddr  : std_logic_vector(5 downto 0)  := (others => '0');
  signal cfg_awvalid : std_logic := '0';
  signal cfg_awready : std_logic;
  signal cfg_wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal cfg_wstrb   : std_logic_vector(3 downto 0)  := "1111";
  signal cfg_wvalid  : std_logic := '0';
  signal cfg_wready  : std_logic;
  signal cfg_bvalid  : std_logic;
  signal cfg_bready  : std_logic := '1';

  -- ── Pines físicos UART ────────────────────────────────────────────────────
  signal uart_td  : std_logic_vector(N_CH-1 downto 0);
  signal uart_rd  : std_logic_vector(N_CH-1 downto 0) := (others => '1');
  signal uart_de  : std_logic_vector(N_CH-1 downto 0);
  signal uart_slo : std_logic_vector(N_CH-1 downto 0);

  -- Loopback e inyección manual
  signal use_loop : std_logic := '1';
  signal inj_ch1  : std_logic := '1';

  -- ── Monitor: captura bytes de m_axis ─────────────────────────────────────
  type byte_array_t is array (0 to 63) of std_logic_vector(7 downto 0);
  signal rx_buf : byte_array_t := (others => (others => '0'));
  signal rx_cnt : integer := 0;

begin

  clk <= not clk after CLK_PERIOD / 2;

  -- Loopback: ch0 directo, ch1 conmutable
  uart_rd(0) <= uart_td(0);
  uart_rd(1) <= uart_td(1) when use_loop = '1' else inj_ch1;


  -- ==========================================================================
  -- DUT: BRIDGE_AND_SERIALs (N_CH=2)
  -- ==========================================================================
  DUT : entity work.BRIDGE_AND_SERIALs
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
      -- AXI-Lite TX ISR: idle
      s_axi_tx_awaddr  => AXI_ZERO4,
      s_axi_tx_awvalid => '0',
      s_axi_tx_awready => open,
      s_axi_tx_wdata   => (others => '0'),
      s_axi_tx_wstrb   => "1111",
      s_axi_tx_wvalid  => '0',
      s_axi_tx_wready  => open,
      s_axi_tx_bresp   => open,
      s_axi_tx_bvalid  => open,
      s_axi_tx_bready  => '1',
      s_axi_tx_araddr  => AXI_ZERO4,
      s_axi_tx_arvalid => '0',
      s_axi_tx_arready => open,
      s_axi_tx_rdata   => open,
      s_axi_tx_rresp   => open,
      s_axi_tx_rvalid  => open,
      s_axi_tx_rready  => '1',
      EOAF             => open,
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
      -- Pines físicos UART
      DE  => uart_de,
      TD  => uart_td,
      RD  => uart_rd,
      SLO => uart_slo
    );

  -- ==========================================================================
  -- Monitor: captura beats de m_axis
  -- ==========================================================================
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

  -- ==========================================================================
  -- Estímulo
  -- ==========================================================================
  proc_stim : process

    variable found : boolean;
    variable base  : integer;
    variable L     : line;

    procedure wait_clk(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- Escritura AXI-Lite cfg
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

    -- Envío de un byte por AXI-Stream TX
    procedure axis_send(
      constant data    : in std_logic_vector(7 downto 0);
      constant is_last : in boolean
    ) is begin
      s_axis_tdata  <= data;
      s_axis_tvalid <= '1';
      if is_last then s_axis_tlast <= '1'; else s_axis_tlast <= '0'; end if;
      wait until rising_edge(clk) and s_axis_tready = '1';
      s_axis_tvalid <= '0';
      s_axis_tlast  <= '0';
    end procedure;

    -- Inyección UART serie en pin RD (LSB-first, 8N1)
    procedure uart_inject(
      signal rx_pin : out std_logic;
      constant data : in  std_logic_vector(7 downto 0)
    ) is begin
      rx_pin <= '0';                      -- start bit
      wait for BIT_PERIOD;
      for i in 0 to 7 loop
        rx_pin <= data(i);
        wait for BIT_PERIOD;
      end loop;
      rx_pin <= '1';                      -- stop bit
      wait for BIT_PERIOD;
    end procedure;

    -- Esperar hasta tener N bytes o agotar timeout_cycles ciclos
    procedure wait_rx(constant n : in integer; constant timeout_cycles : in integer) is
      variable cnt : integer := 0;
    begin
      while rx_cnt < n and cnt < timeout_cycles loop
        wait until rising_edge(clk);
        cnt := cnt + 1;
      end loop;
    end procedure;

    -- Buscar un byte en rx_buf[from .. rx_cnt-1]
    function find_byte(buf : byte_array_t; from_idx : integer;
                       cnt : integer; val : std_logic_vector(7 downto 0))
      return boolean is
    begin
      for i in from_idx to cnt-1 loop
        if buf(i) = val then return true; end if;
      end loop;
      return false;
    end function;

  begin

    -- =========================================================================
    -- RESET
    -- =========================================================================
    aresetn <= '0';
    wait_clk(20);
    aresetn <= '1';
    wait_clk(10);

    -- =========================================================================
    -- CONFIG: 1000000 baud 8N1 en ch0 y ch1 (misma que el valor de reset del IP,
    -- pero lo escribimos explícitamente para verificar el bus AXI-Lite cfg)
    -- =========================================================================
    write(L, string'("[CONFIG] 1000000 8N1 ch0+ch1..."));
    writeline(output, L);

    cfg_write("000000", x"00001C2C");   -- canal 0  (offset 0x00)
    cfg_write("000100", x"00001C2C");   -- canal 1  (offset 0x04)
    wait_clk(5);

    -- =========================================================================
    -- TEST-1: TX ch0 → 1 byte 0xA5 → loopback → m_axis
    -- 1 byte UART a 921600: ~1085 ciclos TX + ~1085 RX + ~923 timeout ≈ 3100
    -- =========================================================================
    write(L, string'("[TEST-1] TX ch0 -> 0xA5 loopback..."));
    writeline(output, L);

    -- Paquete: [ch_hi=0x00 (ch=0,len_hi=0)][len_lo=0x01][data=0xA5,TLAST]
    axis_send(x"00", false);
    axis_send(x"01", false);
    axis_send(x"A5", true);

    -- Esperar 1 byte en m_axis (timeout generoso: 10x bit_period*10bits*2)
    wait_rx(1, 50000);

    if rx_cnt < 1 then
      write(L, string'("FAIL [TEST-1]: no llego ningun byte a m_axis"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    found := find_byte(rx_buf, 0, rx_cnt, x"A5");
    if not found then
      write(L, string'("FAIL [TEST-1]: 0xA5 no encontrado en m_axis (got ") &
               integer'image(to_integer(unsigned(rx_buf(0)))) & string'(")"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    write(L, string'("[TEST-1] PASS"));
    writeline(output, L);

    -- =========================================================================
    -- TEST-2: TX ch0 (0xDE) seguido de TX ch1 (0xAD) → ambos en m_axis
    -- =========================================================================
    write(L, string'("[TEST-2] TX ch0->0xDE, ch1->0xAD loopback..."));
    writeline(output, L);

    base := rx_cnt;

    -- Canal 0: [0x00][0x01][0xDE,TLAST]
    axis_send(x"00", false);
    axis_send(x"01", false);
    axis_send(x"DE", true);

    wait_clk(3);

    -- Canal 1: [0x10][0x01][0xAD,TLAST]
    axis_send(x"10", false);
    axis_send(x"01", false);
    axis_send(x"AD", true);

    -- Esperar 2 bytes nuevos (ch0 + ch1)
    wait_rx(base + 2, 25000);

    if rx_cnt < base + 2 then
      write(L, string'("FAIL [TEST-2]: solo ") & integer'image(rx_cnt - base) &
               string'(" bytes nuevos (esperado 2)"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    if not find_byte(rx_buf, base, rx_cnt, x"DE") then
      write(L, string'("FAIL [TEST-2]: 0xDE (ch0) no encontrado"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    if not find_byte(rx_buf, base, rx_cnt, x"AD") then
      write(L, string'("FAIL [TEST-2]: 0xAD (ch1) no encontrado"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    write(L, string'("[TEST-2] PASS"));
    writeline(output, L);

    -- =========================================================================
    -- TEST-3: Inyección serie directa en RD(1) → 0x55 en m_axis
    -- =========================================================================
    write(L, string'("[TEST-3] Inyeccion serie CH1 <- 0x55..."));
    writeline(output, L);

    base := rx_cnt;
    use_loop <= '0';
    wait_clk(2);
    uart_inject(inj_ch1, x"55");
    use_loop <= '1';

    wait_rx(base + 1, 10000);

    if rx_cnt < base + 1 then
      write(L, string'("FAIL [TEST-3]: 0x55 no llego a m_axis"));
      writeline(output, L);
      report "SIM_RESULT: FAIL" severity failure;
    end if;

    if not find_byte(rx_buf, base, rx_cnt, x"55") then
      write(L, string'("FAIL [TEST-3]: 0x55 no encontrado (got ") &
               integer'image(to_integer(unsigned(rx_buf(base)))) & string'(")"));
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
