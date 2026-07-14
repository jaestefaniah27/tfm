----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 07/01/2026 01:55:50 PM
-- Design Name:
-- Module Name: BRIDGE_RX_TOP - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity BRIDGE_RX_TOP is
  generic (
    N_CH : integer := 14
  );
  Port (
    aclk              : in  std_logic;
    aresetn           : in  std_logic;
    -- AXI-Stream master hacia la DMA
    m_axis_tdata      : out std_logic_vector(7 downto 0);
    m_axis_tvalid     : out std_logic;
    m_axis_tready     : in  std_logic;
    m_axis_tlast      : out std_logic;
    m_axis_tdest      : out std_logic_vector(3 downto 0);
    -- Timeout por canal (un bit por transceiver, 16 en total)
    timeout_in        : in  std_logic_vector(N_CH-1 downto 0);
    -- Ack del timeout, dirigido por el DEMUX al canal que el DRAIN atendió.
    -- Cierra el handshake con el RX de cada CONFIGURABLE_SERIAL.
    timeout_ok_out    : out std_logic_vector(N_CH-1 downto 0);
    -- FIFOs RX de los transceivers (N_CH canales activos)
    rx_fifo_empty     : in  std_logic_vector(N_CH-1 downto 0);
    rx_fifo_prog_full : in  std_logic_vector(N_CH-1 downto 0);
    rx_fifo_dout      : in  std_logic_vector(N_CH*8-1 downto 0);
    rx_fifo_rd        : out std_logic_vector(N_CH-1 downto 0)
  );
end BRIDGE_RX_TOP;

architecture Behavioral of BRIDGE_RX_TOP is

  -- ---------------------------------------------------------------
  -- Component declarations
  -- ---------------------------------------------------------------

  component BRIDGE_RX_FIFO_DEMUX is
    Port (
      RX_ID             : in  std_logic_vector(3 downto 0);
      fifo_rd_in        : in  std_logic;
      fifo_rd_out       : out std_logic_vector(15 downto 0);
      rx_timeout_in     : in  std_logic_vector(15 downto 0);
      rx_timeout_out    : out std_logic;
      rx_timeout_ok_in  : in  std_logic;
      rx_timeout_ok_out : out std_logic_vector(15 downto 0);
      fifo_empty_in     : in  std_logic_vector(15 downto 0);
      fifo_empty_out    : out std_logic;
      fifo_dout_in      : in  std_logic_vector(127 downto 0);
      fifo_dout_out     : out std_logic_vector(7 downto 0)
    );
  end component;

  component BRIDGE_RX_FIFO_DRAIN is
    generic (
      N_CH : integer := 14
    );
    Port (
      aclk              : in  std_logic;
      aresetn           : in  std_logic;
      RD_ID             : out std_logic_vector(3 downto 0);
      rx_fifo_data_out  : in  std_logic_vector(7 downto 0);
      rx_fifo_prog_full : in  std_logic;
      rx_fifo_empty     : in  std_logic;
      rx_fifo_rd_out    : out std_logic;
      rx_timeout_in     : in  std_logic;
      rx_timeout_ok     : out std_logic;
      m_axis_tdata      : out std_logic_vector(7 downto 0);
      m_axis_tvalid     : out std_logic;
      m_axis_tready     : in  std_logic;
      m_axis_tlast      : out std_logic;
      m_axis_tdest      : out std_logic_vector(3 downto 0)
    );
  end component;

  -- ---------------------------------------------------------------
  -- Internal signals: DRAIN <-> DEMUX
  -- ---------------------------------------------------------------

  signal rx_id_s             : std_logic_vector(3 downto 0);
  signal drain_rd_s          : std_logic;
  signal drain_data_s        : std_logic_vector(7 downto 0);
  signal drain_empty_s       : std_logic;
  signal drain_prog_full_s   : std_logic;
  signal drain_timeout_s     : std_logic;
  signal drain_timeout_ok_s  : std_logic;

  -- DEMUX buses (16-wide; canales N_CH..15 rellenos)
  signal demux_rd_out_s          : std_logic_vector(15 downto 0);
  signal demux_empty_in_s        : std_logic_vector(15 downto 0);
  signal demux_dout_in_s         : std_logic_vector(127 downto 0);
  signal demux_timeout_in_s      : std_logic_vector(15 downto 0);
  signal demux_timeout_ok_out_s  : std_logic_vector(15 downto 0);

begin

  -- ---------------------------------------------------------------
  -- Pad DEMUX input buses.
  -- Channels N_CH..15 unused: empty='1', dout=0x00.
  -- ---------------------------------------------------------------
  demux_empty_in_s(N_CH-1 downto 0) <= rx_fifo_empty;
  demux_empty_in_s(15 downto N_CH)  <= (others => '1');

  demux_dout_in_s(N_CH*8-1 downto 0) <= rx_fifo_dout;
  demux_dout_in_s(127 downto N_CH*8)  <= (others => '0');

  demux_timeout_in_s(N_CH-1 downto 0) <= timeout_in;
  demux_timeout_in_s(15 downto N_CH)  <= (others => '0');

  rx_fifo_rd <= demux_rd_out_s(N_CH-1 downto 0);

  -- El DEMUX ya encamina el ack del DRAIN al canal en curso; solo faltaba
  -- sacarlo al exterior. Antes se calculaba y se descartaba.
  timeout_ok_out <= demux_timeout_ok_out_s(N_CH-1 downto 0);

  -- Select prog_full bit for the channel currently being scanned
  drain_prog_full_s <= rx_fifo_prog_full(to_integer(unsigned(rx_id_s)))
                         when unsigned(rx_id_s) < N_CH else '0';

  -- ---------------------------------------------------------------
  -- DEMUX: steers DRAIN rd/empty/dout to/from the selected channel
  -- ---------------------------------------------------------------
  U_DEMUX : BRIDGE_RX_FIFO_DEMUX
    port map (
      RX_ID             => rx_id_s,
      fifo_rd_in        => drain_rd_s,
      fifo_rd_out       => demux_rd_out_s,
      rx_timeout_in     => demux_timeout_in_s,
      rx_timeout_out    => drain_timeout_s,
      rx_timeout_ok_in  => drain_timeout_ok_s,
      rx_timeout_ok_out => demux_timeout_ok_out_s,
      fifo_empty_in     => demux_empty_in_s,
      fifo_empty_out    => drain_empty_s,
      fifo_dout_in      => demux_dout_in_s,
      fifo_dout_out     => drain_data_s
    );

  -- ---------------------------------------------------------------
  -- DRAIN: recorre los canales y vuelca hacia DMA por AXI-Stream
  -- ---------------------------------------------------------------
  U_DRAIN : BRIDGE_RX_FIFO_DRAIN
    generic map (
      N_CH => N_CH
    )
    port map (
      aclk              => aclk,
      aresetn           => aresetn,
      RD_ID             => rx_id_s,
      rx_fifo_data_out  => drain_data_s,
      rx_fifo_prog_full => drain_prog_full_s,
      rx_fifo_empty     => drain_empty_s,
      rx_fifo_rd_out    => drain_rd_s,
      rx_timeout_in     => drain_timeout_s,
      rx_timeout_ok     => drain_timeout_ok_s,
      m_axis_tdata      => m_axis_tdata,
      m_axis_tvalid     => m_axis_tvalid,
      m_axis_tready     => m_axis_tready,
      m_axis_tlast      => m_axis_tlast,
      m_axis_tdest      => m_axis_tdest
    );

end Behavioral;
