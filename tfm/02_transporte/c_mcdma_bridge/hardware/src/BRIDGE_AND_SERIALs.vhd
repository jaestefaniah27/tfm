----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/03/2026 12:21:47 PM
-- Design Name: 
-- Module Name: BRIDGE_AND_SERIALs - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BRIDGE_AND_SERIALs is
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
    
    -- TX Outputs
    DE        : out std_logic_vector(N_CH-1 downto 0);   -- Driver Enable
    TD        : out std_logic_vector(N_CH-1 downto 0);   -- Serial Transmission line
	-- RX Inputs
    RD        : in  std_logic_vector(N_CH-1 downto 0);   -- Serial Reception line
    -- SLO output
    SLO       : out std_logic_vector(N_CH-1 downto 0)
  );
end BRIDGE_AND_SERIALs;

architecture Behavioral of BRIDGE_AND_SERIALs is

component BRIDGE_TOP
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
end component;

component CONFIGURABLE_SERIAL
    generic (DELAY_CYCLES : integer := 10);
    port (
      Reset       : in  std_logic;
      Clk         : in  std_logic;
      Data_in     : in  std_logic_vector(8 downto 0);
      TX_Send     : in  std_logic;
      TX_RDY      : out std_logic;
      Send_ok     : out std_logic;
      DE          : out std_logic;
      TD          : out std_logic;
      RD          : in  std_logic;
      Data_out    : out std_logic_vector(8 downto 0);
      Data_read   : in  std_logic;
      Full        : out std_logic;
      Empty       : out std_logic;
      Prog_Full   : out std_logic;
      PAR_ERROR   : out std_logic;
      FRAME_ERROR : out std_logic;
      ERROR_OK    : in  std_logic;
      Timeout     : out std_logic;
      Timeout_ok  : in  std_logic;
      baud_sel    : in  std_logic_vector(5 downto 0);
      stop_bit    : in  std_logic_vector(1 downto 0);
      parity      : in  std_logic_vector(2 downto 0);
      bit_order   : in  std_logic;
      data_bits   : in  std_logic_vector(2 downto 0);
      dbg_rx      : out std_logic_vector(3 downto 0)
    );
end component;

  -- ── Señales internas entre BRIDGE_TOP y CONFIGURABLE_SERIALs ─────────────
  signal tx_din_s       : std_logic_vector(N_CH*9-1 downto 0);
  signal tx_send_s      : std_logic_vector(N_CH-1 downto 0);
  signal tx_rdy_s       : std_logic_vector(N_CH-1 downto 0);
  signal send_ok_s      : std_logic_vector(N_CH-1 downto 0);
  signal rx_dout_9b_s   : std_logic_vector(N_CH*9-1 downto 0);
  signal rx_rd_s        : std_logic_vector(N_CH-1 downto 0);
  signal rx_full_s      : std_logic_vector(N_CH-1 downto 0);
  signal rx_empty_s     : std_logic_vector(N_CH-1 downto 0);
  signal rx_prog_full_s : std_logic_vector(N_CH-1 downto 0);
  -- Ack del timeout: lo emite el puente hacia el canal que acaba de atender.
  signal timeout_ok_s   : std_logic_vector(N_CH-1 downto 0);
  signal timeout_s      : std_logic_vector(N_CH-1 downto 0);
  signal baud_sel_s     : std_logic_vector(N_CH*6-1 downto 0);
  signal stop_bit_s     : std_logic_vector(N_CH*2-1 downto 0);
  signal parity_s       : std_logic_vector(N_CH*3-1 downto 0);
  signal data_bits_s    : std_logic_vector(N_CH*3-1 downto 0);
  signal bit_order_s    : std_logic_vector(N_CH-1 downto 0);
  signal rx_fifo_dout_s : std_logic_vector(N_CH*8-1 downto 0);
  signal slo_s          : std_logic_vector(N_CH-1 downto 0);

begin

-- ---------------------------------------------------------------
-- Bridge principal
-- ---------------------------------------------------------------
u_bridge : BRIDGE_TOP
    generic map (
      N_CH => N_CH
    )
    port map (
      aclk    => aclk,
      aresetn => aresetn,
    
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tlast  => s_axis_tlast,
    
      m_axis_tdata  => m_axis_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready,
      m_axis_tlast  => m_axis_tlast,
      m_axis_tdest  => m_axis_tdest,

      s_axi_tx_awaddr  => s_axi_tx_awaddr,
      s_axi_tx_awvalid => s_axi_tx_awvalid,
      s_axi_tx_awready => s_axi_tx_awready,
      s_axi_tx_wdata   => s_axi_tx_wdata,
      s_axi_tx_wstrb   => s_axi_tx_wstrb,
      s_axi_tx_wvalid  => s_axi_tx_wvalid,
      s_axi_tx_wready  => s_axi_tx_wready,
      s_axi_tx_bresp   => s_axi_tx_bresp,
      s_axi_tx_bvalid  => s_axi_tx_bvalid,
      s_axi_tx_bready  => s_axi_tx_bready,
      s_axi_tx_araddr  => s_axi_tx_araddr,
      s_axi_tx_arvalid => s_axi_tx_arvalid,
      s_axi_tx_arready => s_axi_tx_arready,
      s_axi_tx_rdata   => s_axi_tx_rdata,
      s_axi_tx_rresp   => s_axi_tx_rresp,
      s_axi_tx_rvalid  => s_axi_tx_rvalid,
      s_axi_tx_rready  => s_axi_tx_rready,
      EOAF             => EOAF,
    
      s_axi_cfg_awaddr  => s_axi_cfg_awaddr,
      s_axi_cfg_awvalid => s_axi_cfg_awvalid,
      s_axi_cfg_awready => s_axi_cfg_awready,
      s_axi_cfg_wdata   => s_axi_cfg_wdata,
      s_axi_cfg_wstrb   => s_axi_cfg_wstrb,
      s_axi_cfg_wvalid  => s_axi_cfg_wvalid,
      s_axi_cfg_wready  => s_axi_cfg_wready,
      s_axi_cfg_bresp   => s_axi_cfg_bresp,
      s_axi_cfg_bvalid  => s_axi_cfg_bvalid,
      s_axi_cfg_bready  => s_axi_cfg_bready,
      s_axi_cfg_araddr  => s_axi_cfg_araddr,
      s_axi_cfg_arvalid => s_axi_cfg_arvalid,
      s_axi_cfg_arready => s_axi_cfg_arready,
      s_axi_cfg_rdata   => s_axi_cfg_rdata,
      s_axi_cfg_rresp   => s_axi_cfg_rresp,
      s_axi_cfg_rvalid  => s_axi_cfg_rvalid,
      s_axi_cfg_rready  => s_axi_cfg_rready,
    
      tx_din  => tx_din_s,
      tx_send => tx_send_s,
      send_ok => send_ok_s,
      tx_rdy  => tx_rdy_s,
    
      rx_fifo_dout  => rx_fifo_dout_s,
      rx_fifo_empty => rx_empty_s,
      rx_fifo_prog_full => rx_prog_full_s,
      rx_fifo_rd    => rx_rd_s,
      timeout       => timeout_s,
      timeout_ok    => timeout_ok_s,
    
      baud_sel  => baud_sel_s,
      stop_bit  => stop_bit_s,
      parity    => parity_s,
      data_bits => data_bits_s,
      bit_order => bit_order_s,
      slo       => slo_s
);

  -- ---------------------------------------------------------------
  -- Transceptores UART, uno por canal
  -- ---------------------------------------------------------------
  gen_ch : for i in 0 to N_CH-1 generate
    u_core : CONFIGURABLE_SERIAL
      port map (
        Reset       => aresetn,
        Clk         => aclk,
        Data_in     => tx_din_s(i*9+8 downto i*9),
        TX_Send     => tx_send_s(i),
        TX_RDY      => tx_rdy_s(i),
        Send_ok     => send_ok_s(i),
        DE          => DE(i),
        TD          => TD(i),
        RD          => RD(i),
        Data_out    => rx_dout_9b_s(i*9+8 downto i*9),
        Data_read   => rx_rd_s(i),
        Full        => rx_full_s(i),
        Empty       => rx_empty_s(i),
        Prog_Full   => rx_prog_full_s(i),
        PAR_ERROR   => open,
        FRAME_ERROR => open,
        ERROR_OK    => '1',
        Timeout     => timeout_s(i),
        Timeout_ok  => timeout_ok_s(i),
        baud_sel    => baud_sel_s(i*6+5 downto i*6),
        stop_bit    => stop_bit_s(i*2+1 downto i*2),
        parity      => parity_s(i*3+2 downto i*3),
        data_bits   => data_bits_s(i*3+2 downto i*3),
        bit_order   => bit_order_s(i),
        dbg_rx      => open
      );
  end generate;

  -- Extrae los 8 bits de datos de cada Data_out de 9 bits (bit 8 = bit de paridad/frame)
  gen_rxd : for i in 0 to N_CH-1 generate
    rx_fifo_dout_s(i*8+7 downto i*8) <= rx_dout_9b_s(i*9+7 downto i*9);
  end generate;

  SLO <= slo_s;


end Behavioral;
