----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 06/30/2026 02:19:25 PM
-- Design Name:
-- Module Name: BRIDGE_RX_FIFO_DEMUX - Behavioral
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

entity BRIDGE_RX_FIFO_DEMUX is
  Port (
    RX_ID              : in  std_logic_vector(3 downto 0);
    fifo_rd_in         : in  std_logic;
    fifo_rd_out        : out std_logic_vector(15 downto 0);
    rx_timeout_in      : in  std_logic_vector(15 downto 0);
    rx_timeout_out     : out std_logic;
    rx_timeout_ok_in   : in  std_logic;
    rx_timeout_ok_out  : out std_logic_vector(15 downto 0);
    fifo_empty_in      : in  std_logic_vector(15 downto 0);
    fifo_empty_out     : out std_logic;
    fifo_dout_in       : in  std_logic_vector(127 downto 0);
    fifo_dout_out      : out std_logic_vector(7 downto 0)
  );
end BRIDGE_RX_FIFO_DEMUX;

architecture Behavioral of BRIDGE_RX_FIFO_DEMUX is

begin

  with RX_ID select fifo_rd_out <=
    (0  => fifo_rd_in, others => '0') when "0000",
    (1  => fifo_rd_in, others => '0') when "0001",
    (2  => fifo_rd_in, others => '0') when "0010",
    (3  => fifo_rd_in, others => '0') when "0011",
    (4  => fifo_rd_in, others => '0') when "0100",
    (5  => fifo_rd_in, others => '0') when "0101",
    (6  => fifo_rd_in, others => '0') when "0110",
    (7  => fifo_rd_in, others => '0') when "0111",
    (8  => fifo_rd_in, others => '0') when "1000",
    (9  => fifo_rd_in, others => '0') when "1001",
    (10 => fifo_rd_in, others => '0') when "1010",
    (11 => fifo_rd_in, others => '0') when "1011",
    (12 => fifo_rd_in, others => '0') when "1100",
    (13 => fifo_rd_in, others => '0') when "1101",
    (14 => fifo_rd_in, others => '0') when "1110",
    (15 => fifo_rd_in, others => '0') when "1111",
    (others => '0')                   when others;

  with RX_ID select rx_timeout_out <=
    rx_timeout_in(0)  when "0000",
    rx_timeout_in(1)  when "0001",
    rx_timeout_in(2)  when "0010",
    rx_timeout_in(3)  when "0011",
    rx_timeout_in(4)  when "0100",
    rx_timeout_in(5)  when "0101",
    rx_timeout_in(6)  when "0110",
    rx_timeout_in(7)  when "0111",
    rx_timeout_in(8)  when "1000",
    rx_timeout_in(9)  when "1001",
    rx_timeout_in(10) when "1010",
    rx_timeout_in(11) when "1011",
    rx_timeout_in(12) when "1100",
    rx_timeout_in(13) when "1101",
    rx_timeout_in(14) when "1110",
    rx_timeout_in(15) when "1111",
    '0'            when others;

  with RX_ID select rx_timeout_ok_out <=
    (0  => rx_timeout_ok_in, others => '0') when "0000",
    (1  => rx_timeout_ok_in, others => '0') when "0001",
    (2  => rx_timeout_ok_in, others => '0') when "0010",
    (3  => rx_timeout_ok_in, others => '0') when "0011",
    (4  => rx_timeout_ok_in, others => '0') when "0100",
    (5  => rx_timeout_ok_in, others => '0') when "0101",
    (6  => rx_timeout_ok_in, others => '0') when "0110",
    (7  => rx_timeout_ok_in, others => '0') when "0111",
    (8  => rx_timeout_ok_in, others => '0') when "1000",
    (9  => rx_timeout_ok_in, others => '0') when "1001",
    (10 => rx_timeout_ok_in, others => '0') when "1010",
    (11 => rx_timeout_ok_in, others => '0') when "1011",
    (12 => rx_timeout_ok_in, others => '0') when "1100",
    (13 => rx_timeout_ok_in, others => '0') when "1101",
    (14 => rx_timeout_ok_in, others => '0') when "1110",
    (15 => rx_timeout_ok_in, others => '0') when "1111",
    (others => '0')                   when others;

  with RX_ID select fifo_empty_out <=
    fifo_empty_in(0)  when "0000",
    fifo_empty_in(1)  when "0001",
    fifo_empty_in(2)  when "0010",
    fifo_empty_in(3)  when "0011",
    fifo_empty_in(4)  when "0100",
    fifo_empty_in(5)  when "0101",
    fifo_empty_in(6)  when "0110",
    fifo_empty_in(7)  when "0111",
    fifo_empty_in(8)  when "1000",
    fifo_empty_in(9)  when "1001",
    fifo_empty_in(10) when "1010",
    fifo_empty_in(11) when "1011",
    fifo_empty_in(12) when "1100",
    fifo_empty_in(13) when "1101",
    fifo_empty_in(14) when "1110",
    fifo_empty_in(15) when "1111",
    '0'            when others;


  with RX_ID select fifo_dout_out <=
    fifo_dout_in(7   downto 0)   when "0000",
    fifo_dout_in(15  downto 8)   when "0001",
    fifo_dout_in(23  downto 16)  when "0010",
    fifo_dout_in(31  downto 24)  when "0011",
    fifo_dout_in(39  downto 32)  when "0100",
    fifo_dout_in(47  downto 40)  when "0101",
    fifo_dout_in(55  downto 48)  when "0110",
    fifo_dout_in(63  downto 56)  when "0111",
    fifo_dout_in(71  downto 64)  when "1000",
    fifo_dout_in(79  downto 72)  when "1001",
    fifo_dout_in(87  downto 80)  when "1010",
    fifo_dout_in(95  downto 88)  when "1011",
    fifo_dout_in(103 downto 96)  when "1100",
    fifo_dout_in(111 downto 104) when "1101",
    fifo_dout_in(119 downto 112) when "1110",
    fifo_dout_in(127 downto 120) when "1111",
    (others => '0')              when others;

end Behavioral;
