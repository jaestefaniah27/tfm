library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ============================================================================
-- AXI_UART_CONFIG
-- Banco de N_CH registros de 32 bits accesible por AXI-Lite.
-- Cada registro almacena la configuración estática de un canal UART.
--
-- Layout de cada registro (32 bits):
--   [31:16]  reservado (write ignored, read 0)
--   [15]     SLO
--   [14]     bit_order
--   [13:11]  data_bits
--   [10:8]   parity
--   [7:6]    stop_bit
--   [5:0]    baud_sel
--
-- Mapa de direcciones AXI-Lite:
--   0x00 → Canal 0 | 0x04 → Canal 1 | ... | 0x34 → Canal 13
--
-- Los canales se resetean con baud_sel=0x12 (9600 bps para clk=100MHz),
-- 1 stop bit, sin paridad (parity=4), 8 bits de datos, LSB-first, SLO=0.
-- ============================================================================

entity AXI_UART_CONFIG is
  generic (
    N_CH : integer := 14   -- Número de canales UART activos (1..14)
  );
  port (
    -- ── AXI-Lite esclavo ────────────────────────────────────────────────────
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    -- Write address
    s_axi_awaddr  : in  std_logic_vector(5 downto 0);   -- [5:2] = índice canal
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    -- Write data
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    -- Write response
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    -- Read address
    s_axi_araddr  : in  std_logic_vector(5 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    -- Read data
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;
    -- ── Salidas de configuración: un vector por parámetro ───────────────────
    -- Canal i ocupa el slice [i*W+W-1 : i*W] de cada vector
    baud_sel  : out std_logic_vector(N_CH*6-1 downto 0);  -- 6b/canal → ps_config[17:12]
    stop_bit  : out std_logic_vector(N_CH*2-1 downto 0);  -- 2b/canal → ps_config[19:18]
    parity    : out std_logic_vector(N_CH*3-1 downto 0);  -- 3b/canal → ps_config[22:20]
    data_bits : out std_logic_vector(N_CH*3-1 downto 0);  -- 3b/canal → ps_config[25:23]
    bit_order : out std_logic_vector(N_CH-1 downto 0);    -- 1b/canal → ps_config[26]
    slo       : out std_logic_vector(N_CH-1 downto 0)     -- 1b/canal → ps_config[27]
  );
end AXI_UART_CONFIG;

architecture Behavioral of AXI_UART_CONFIG is

  -- ── Valor de reset: 921600 bps (baud_sel=43=0x2B), 1 stop bit, sin paridad,
  --    8 bits de datos (data_bits=3), LSB-first, SLO=0
  --    [5:0]=0x2B=43, [7:6]=0, [10:8]=4 (paridad OFF), [13:11]=3, [14]=0, [15]=0
  --    = 0x00001C2B
  constant REG_RESET_VAL : std_logic_vector(31 downto 0) := x"00001C2B";

  -- Array de registros de configuración, inicializado a 9600/8N1
  type reg_array_t is array (0 to 15) of std_logic_vector(31 downto 0);
  signal regs : reg_array_t := (others => REG_RESET_VAL);

  -- Control interno AXI-Lite escritura
  signal aw_en       : std_logic := '1';
  signal aw_addr_lat : std_logic_vector(3 downto 0) := (others => '0');
  signal awready_r   : std_logic := '0';
  signal wready_r    : std_logic := '0';
  signal bvalid_r    : std_logic := '0';

  -- Control interno AXI-Lite lectura
  signal ar_addr_lat : std_logic_vector(3 downto 0) := (others => '0');
  signal arready_r   : std_logic := '0';
  signal rvalid_r    : std_logic := '0';
  signal rdata_r     : std_logic_vector(31 downto 0) := (others => '0');

begin

  -- ── Conexión directa de señales de salida ───────────────────────────────
  s_axi_awready <= awready_r;
  s_axi_wready  <= wready_r;
  s_axi_bresp   <= "00";   -- siempre OKAY
  s_axi_bvalid  <= bvalid_r;
  s_axi_arready <= arready_r;
  s_axi_rdata   <= rdata_r;
  s_axi_rresp   <= "00";   -- siempre OKAY
  s_axi_rvalid  <= rvalid_r;

  -- ============================================================
  -- CANAL DE ESCRITURA
  -- ============================================================

  -- awready: se acepta cuando ambos awvalid y wvalid están listos
  p_awready : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        awready_r   <= '0';
        aw_en       <= '1';
        aw_addr_lat <= (others => '0');
      else
        if awready_r = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and aw_en = '1' then
          awready_r   <= '1';
          aw_en       <= '0';
          aw_addr_lat <= s_axi_awaddr(5 downto 2);
        elsif s_axi_bready = '1' and bvalid_r = '1' then
          aw_en     <= '1';
          awready_r <= '0';
        else
          awready_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- wready: sincronizado con awready
  p_wready : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        wready_r <= '0';
      else
        if wready_r = '0' and s_axi_wvalid = '1' and s_axi_awvalid = '1' and aw_en = '1' then
          wready_r <= '1';
        else
          wready_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Escritura efectiva al registro con soporte de byte strobes
  p_reg_write : process(s_axi_aclk)
    variable idx : integer range 0 to 15;
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        regs <= (others => REG_RESET_VAL);
      elsif awready_r = '1' and wready_r = '1' and
            s_axi_awvalid = '1' and s_axi_wvalid = '1' then
        idx := to_integer(unsigned(aw_addr_lat));
        if idx < N_CH then
          for b in 0 to 3 loop
            if s_axi_wstrb(b) = '1' then
              regs(idx)(b*8+7 downto b*8) <= s_axi_wdata(b*8+7 downto b*8);
            end if;
          end loop;
        end if;
      end if;
    end if;
  end process;

  -- Respuesta de escritura
  p_bresp : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        bvalid_r <= '0';
      else
        if awready_r = '1' and wready_r = '1' and
           s_axi_awvalid = '1' and s_axi_wvalid = '1' and bvalid_r = '0' then
          bvalid_r <= '1';
        elsif s_axi_bready = '1' and bvalid_r = '1' then
          bvalid_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ============================================================
  -- CANAL DE LECTURA
  -- ============================================================

  -- arready: pulso de un ciclo al recibir arvalid
  p_arready : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        arready_r   <= '0';
        ar_addr_lat <= (others => '0');
      else
        if arready_r = '0' and s_axi_arvalid = '1' then
          arready_r   <= '1';
          ar_addr_lat <= s_axi_araddr(5 downto 2);
        else
          arready_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Datos de lectura
  p_rdata : process(s_axi_aclk)
    variable idx : integer range 0 to 15;
  begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        rvalid_r <= '0';
        rdata_r  <= (others => '0');
      else
        if arready_r = '1' and s_axi_arvalid = '1' and rvalid_r = '0' then
          idx := to_integer(unsigned(ar_addr_lat));
          if idx < N_CH then
            rdata_r <= regs(idx);
          else
            rdata_r <= (others => '0');
          end if;
          rvalid_r <= '1';
        elsif rvalid_r = '1' and s_axi_rready = '1' then
          rvalid_r <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ============================================================
  -- SALIDAS DE CONFIGURACIÓN — un slice por canal por parámetro
  -- ============================================================
  gen_config_out : for i in 0 to N_CH-1 generate
    baud_sel (i*6+5 downto i*6) <= regs(i)(5  downto 0);
    stop_bit (i*2+1 downto i*2) <= regs(i)(7  downto 6);
    parity   (i*3+2 downto i*3) <= regs(i)(10 downto 8);
    data_bits(i*3+2 downto i*3) <= regs(i)(13 downto 11);
    bit_order(i)                 <= regs(i)(14);
    slo      (i)                 <= regs(i)(15);
  end generate;

end Behavioral;
