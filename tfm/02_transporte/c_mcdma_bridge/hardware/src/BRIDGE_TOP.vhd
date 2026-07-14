----------------------------------------------------------------------------------
-- Module Name: BRIDGE_TOP - Behavioral
--
-- Puente entre la DMA AXI-Stream y N_CH canales UART externos.
-- Contiene: BRIDGE_TX_TOP, BRIDGE_RX_TOP, AXI_UART_CONFIG.
-- Los cores UART (CONFIGURABLE_SERIAL_TOP / MULTI_SERIAL_CORE) van fuera.
--
-- Interfaz hacia los UART cores (desempaquetada por señal, sin ps_config):
--   TX:     tx_din, tx_send, send_ok, tx_rdy
--   RX:     rx_fifo_dout, rx_fifo_empty, rx_fifo_rd, timeout
--   Config: baud_sel, stop_bit, parity, data_bits, bit_order, slo
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BRIDGE_TOP is
  generic (
    N_CH : integer := 14
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- ── AXI-Stream MM2S: DMA → Bridge TX ─────────────────────────────────────
    s_axis_tdata  : in  std_logic_vector(7 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;

    -- ── AXI-Stream S2MM: Bridge RX → DMA ─────────────────────────────────────
    m_axis_tdata  : out std_logic_vector(7 downto 0);
    m_axis_tvalid : out std_logic;
    m_axis_tready : in  std_logic;
    m_axis_tlast  : out std_logic;
    m_axis_tdest  : out std_logic_vector(3 downto 0);

    -- ── AXI-Lite: ISR de TX (TX_DONE / IRQ) ──────────────────────────────────
    s_axi_tx_awaddr  : in  std_logic_vector(3 downto 0);
    s_axi_tx_awvalid : in  std_logic;
    s_axi_tx_awready : out std_logic;
    s_axi_tx_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_tx_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_tx_wvalid  : in  std_logic;
    s_axi_tx_wready  : out std_logic;
    s_axi_tx_bresp   : out std_logic_vector(1 downto 0);
    s_axi_tx_bvalid  : out std_logic;
    s_axi_tx_bready  : in  std_logic;
    s_axi_tx_araddr  : in  std_logic_vector(3 downto 0);
    s_axi_tx_arvalid : in  std_logic;
    s_axi_tx_arready : out std_logic;
    s_axi_tx_rdata   : out std_logic_vector(31 downto 0);
    s_axi_tx_rresp   : out std_logic_vector(1 downto 0);
    s_axi_tx_rvalid  : out std_logic;
    s_axi_tx_rready  : in  std_logic;
    EOAF             : out std_logic;

    -- ── AXI-Lite: configuración de canales UART ───────────────────────────────
    s_axi_cfg_awaddr  : in  std_logic_vector(5 downto 0);
    s_axi_cfg_awvalid : in  std_logic;
    s_axi_cfg_awready : out std_logic;
    s_axi_cfg_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_cfg_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_cfg_wvalid  : in  std_logic;
    s_axi_cfg_wready  : out std_logic;
    s_axi_cfg_bresp   : out std_logic_vector(1 downto 0);
    s_axi_cfg_bvalid  : out std_logic;
    s_axi_cfg_bready  : in  std_logic;
    s_axi_cfg_araddr  : in  std_logic_vector(5 downto 0);
    s_axi_cfg_arvalid : in  std_logic;
    s_axi_cfg_arready : out std_logic;
    s_axi_cfg_rdata   : out std_logic_vector(31 downto 0);
    s_axi_cfg_rresp   : out std_logic_vector(1 downto 0);
    s_axi_cfg_rvalid  : out std_logic;
    s_axi_cfg_rready  : in  std_logic;

    -- ── Interfaz TX hacia UART cores ──────────────────────────────────────────
    tx_din  : out std_logic_vector(N_CH*9-1 downto 0);  -- dato TX, 9 bits/canal
    tx_send : out std_logic_vector(N_CH-1 downto 0);    -- pulso de envío TX
    send_ok : in  std_logic_vector(N_CH-1 downto 0);    -- core aceptó el dato
    tx_rdy  : in  std_logic_vector(N_CH-1 downto 0);    -- transmisor libre

    -- ── Interfaz RX desde UART cores ─────────────────────────────────────────
    rx_fifo_dout  : in  std_logic_vector(N_CH*8-1 downto 0); -- dato RX, 8 bits/canal
    rx_fifo_empty : in  std_logic_vector(N_CH-1 downto 0);   -- FIFO RX vacía
    rx_fifo_prog_full : in std_logic_vector(N_CH-1 downto 0);-- FIFO RX sobre el umbral
    rx_fifo_rd    : out std_logic_vector(N_CH-1 downto 0);   -- avance FIFO RX
    timeout       : in  std_logic_vector(N_CH-1 downto 0);   -- pulso timeout RX
    timeout_ok    : out std_logic_vector(N_CH-1 downto 0);   -- ack del timeout atendido

    -- ── Configuración UART hacia UART cores (desde AXI_UART_CONFIG) ──────────
    baud_sel  : out std_logic_vector(N_CH*6-1 downto 0);
    stop_bit  : out std_logic_vector(N_CH*2-1 downto 0);
    parity    : out std_logic_vector(N_CH*3-1 downto 0);
    data_bits : out std_logic_vector(N_CH*3-1 downto 0);
    bit_order : out std_logic_vector(N_CH-1 downto 0);
    slo       : out std_logic_vector(N_CH-1 downto 0)
  );
end BRIDGE_TOP;

architecture Behavioral of BRIDGE_TOP is

  component BRIDGE_TX_TOP
    generic (N_CH : integer := 14);
    port (
      aclk          : in  std_logic;
      aresetn       : in  std_logic;
      s_axis_tdata  : in  std_logic_vector(7 downto 0);
      s_axis_tvalid : in  std_logic;
      s_axis_tready : out std_logic;
      s_axis_tlast  : in  std_logic;
      TX_din        : out std_logic_vector(N_CH*9-1 downto 0);
      TX_Send       : out std_logic_vector(N_CH-1 downto 0);
      Send_ok       : in  std_logic_vector(N_CH-1 downto 0);
      TX_RDY        : in  std_logic_vector(N_CH-1 downto 0);
      EOT           : in  std_logic_vector(N_CH-1 downto 0);
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
      EOAF          : out std_logic
    );
  end component;

  component BRIDGE_RX_TOP
    generic (N_CH : integer := 14);
    port (
      aclk              : in  std_logic;
      aresetn           : in  std_logic;
      m_axis_tdata      : out std_logic_vector(7 downto 0);
      m_axis_tvalid     : out std_logic;
      m_axis_tready     : in  std_logic;
      m_axis_tlast      : out std_logic;
      m_axis_tdest      : out std_logic_vector(3 downto 0);
      timeout_in        : in  std_logic_vector(N_CH-1 downto 0);
      timeout_ok_out    : out std_logic_vector(N_CH-1 downto 0);
      rx_fifo_empty     : in  std_logic_vector(N_CH-1 downto 0);
      rx_fifo_prog_full : in  std_logic_vector(N_CH-1 downto 0);
      rx_fifo_dout      : in  std_logic_vector(N_CH*8-1 downto 0);
      rx_fifo_rd        : out std_logic_vector(N_CH-1 downto 0)
    );
  end component;

  -- Sim wrapper generado por Vivado: serial_bridge.gen/.../sim/AXI_UART_CONFIG_0.v
  -- Puertos fijos para N_CH=14; se usan señales intermedias para hacer el slice.
  component AXI_UART_CONFIG_0
    port (
      baud_sel          : out std_logic_vector(83 downto 0);
      stop_bit          : out std_logic_vector(27 downto 0);
      parity            : out std_logic_vector(41 downto 0);
      data_bits         : out std_logic_vector(41 downto 0);
      bit_order         : out std_logic_vector(13 downto 0);
      slo               : out std_logic_vector(13 downto 0);
      s00_axi_aclk      : in  std_logic;
      s00_axi_aresetn   : in  std_logic;
      s00_axi_awaddr    : in  std_logic_vector(5 downto 0);
      s00_axi_awprot    : in  std_logic_vector(2 downto 0);
      s00_axi_awvalid   : in  std_logic;
      s00_axi_awready   : out std_logic;
      s00_axi_wdata     : in  std_logic_vector(31 downto 0);
      s00_axi_wstrb     : in  std_logic_vector(3 downto 0);
      s00_axi_wvalid    : in  std_logic;
      s00_axi_wready    : out std_logic;
      s00_axi_bresp     : out std_logic_vector(1 downto 0);
      s00_axi_bvalid    : out std_logic;
      s00_axi_bready    : in  std_logic;
      s00_axi_araddr    : in  std_logic_vector(5 downto 0);
      s00_axi_arprot    : in  std_logic_vector(2 downto 0);
      s00_axi_arvalid   : in  std_logic;
      s00_axi_arready   : out std_logic;
      s00_axi_rdata     : out std_logic_vector(31 downto 0);
      s00_axi_rresp     : out std_logic_vector(1 downto 0);
      s00_axi_rvalid    : out std_logic;
      s00_axi_rready    : in  std_logic
    );
  end component;

  signal cfg_baud_sel  : std_logic_vector(83 downto 0);
  signal cfg_stop_bit  : std_logic_vector(27 downto 0);
  signal cfg_parity    : std_logic_vector(41 downto 0);
  signal cfg_data_bits : std_logic_vector(41 downto 0);
  signal cfg_bit_order : std_logic_vector(13 downto 0);
  signal cfg_slo       : std_logic_vector(13 downto 0);

begin

  baud_sel  <= cfg_baud_sel(N_CH*6-1 downto 0);
  stop_bit  <= cfg_stop_bit(N_CH*2-1 downto 0);
  parity    <= cfg_parity(N_CH*3-1 downto 0);
  data_bits <= cfg_data_bits(N_CH*3-1 downto 0);
  bit_order <= cfg_bit_order(N_CH-1 downto 0);
  slo       <= cfg_slo(N_CH-1 downto 0);

  -- ── BRIDGE_TX_TOP ─────────────────────────────────────────────────────────
  u_tx : BRIDGE_TX_TOP
    generic map (N_CH => N_CH)
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tlast  => s_axis_tlast,
      TX_din        => tx_din,
      TX_Send       => tx_send,
      Send_ok       => send_ok,
      TX_RDY        => tx_rdy,
      EOT           => tx_rdy,   -- TX_RDY y EOT son la misma señal
      s_axi_awaddr  => s_axi_tx_awaddr,
      s_axi_awvalid => s_axi_tx_awvalid,
      s_axi_awready => s_axi_tx_awready,
      s_axi_wdata   => s_axi_tx_wdata,
      s_axi_wstrb   => s_axi_tx_wstrb,
      s_axi_wvalid  => s_axi_tx_wvalid,
      s_axi_wready  => s_axi_tx_wready,
      s_axi_bresp   => s_axi_tx_bresp,
      s_axi_bvalid  => s_axi_tx_bvalid,
      s_axi_bready  => s_axi_tx_bready,
      s_axi_araddr  => s_axi_tx_araddr,
      s_axi_arvalid => s_axi_tx_arvalid,
      s_axi_arready => s_axi_tx_arready,
      s_axi_rdata   => s_axi_tx_rdata,
      s_axi_rresp   => s_axi_tx_rresp,
      s_axi_rvalid  => s_axi_tx_rvalid,
      s_axi_rready  => s_axi_tx_rready,
      EOAF          => EOAF
    );

  -- ── BRIDGE_RX_TOP ─────────────────────────────────────────────────────────
  u_rx : BRIDGE_RX_TOP
    generic map (N_CH => N_CH)
    port map (
      aclk              => aclk,
      aresetn           => aresetn,
      m_axis_tdata      => m_axis_tdata,
      m_axis_tvalid     => m_axis_tvalid,
      m_axis_tready     => m_axis_tready,
      m_axis_tlast      => m_axis_tlast,
      m_axis_tdest      => m_axis_tdest,
      timeout_in        => timeout,
      timeout_ok_out    => timeout_ok,
      rx_fifo_empty     => rx_fifo_empty,
      rx_fifo_prog_full => rx_fifo_prog_full,
      rx_fifo_dout      => rx_fifo_dout,
      rx_fifo_rd        => rx_fifo_rd
    );

  -- ── AXI_UART_CONFIG_0 (IP core Verilog wizard) ───────────────────────────
  u_cfg : AXI_UART_CONFIG_0
    port map (
      baud_sel          => cfg_baud_sel,
      stop_bit          => cfg_stop_bit,
      parity            => cfg_parity,
      data_bits         => cfg_data_bits,
      bit_order         => cfg_bit_order,
      slo               => cfg_slo,
      s00_axi_aclk      => aclk,
      s00_axi_aresetn   => aresetn,
      s00_axi_awaddr    => s_axi_cfg_awaddr,
      s00_axi_awprot    => (others => '0'),
      s00_axi_awvalid   => s_axi_cfg_awvalid,
      s00_axi_awready   => s_axi_cfg_awready,
      s00_axi_wdata     => s_axi_cfg_wdata,
      s00_axi_wstrb     => s_axi_cfg_wstrb,
      s00_axi_wvalid    => s_axi_cfg_wvalid,
      s00_axi_wready    => s_axi_cfg_wready,
      s00_axi_bresp     => s_axi_cfg_bresp,
      s00_axi_bvalid    => s_axi_cfg_bvalid,
      s00_axi_bready    => s_axi_cfg_bready,
      s00_axi_araddr    => s_axi_cfg_araddr,
      s00_axi_arprot    => (others => '0'),
      s00_axi_arvalid   => s_axi_cfg_arvalid,
      s00_axi_arready   => s_axi_cfg_arready,
      s00_axi_rdata     => s_axi_cfg_rdata,
      s00_axi_rresp     => s_axi_cfg_rresp,
      s00_axi_rvalid    => s_axi_cfg_rvalid,
      s00_axi_rready    => s_axi_cfg_rready
    );

end Behavioral;
