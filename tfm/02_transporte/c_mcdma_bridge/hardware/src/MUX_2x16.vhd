----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2026 02:59:16 PM
-- Design Name: 
-- Module Name: MUX_2x16 - Behavioral
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

entity MUX_2x16 is
  Port (
    TX_ID        : in  std_logic_vector(3 downto 0);
    fifo_wr_in   : in  std_logic;
    fifo_wr_out  : out std_logic_vector(15 downto 0)
  );
end MUX_2x16;

architecture Behavioral of MUX_2x16 is

begin

  with TX_ID select fifo_wr_out <=
    (0  => fifo_wr_in, others => '0') when "0000",
    (1  => fifo_wr_in, others => '0') when "0001",
    (2  => fifo_wr_in, others => '0') when "0010",
    (3  => fifo_wr_in, others => '0') when "0011",
    (4  => fifo_wr_in, others => '0') when "0100",
    (5  => fifo_wr_in, others => '0') when "0101",
    (6  => fifo_wr_in, others => '0') when "0110",
    (7  => fifo_wr_in, others => '0') when "0111",
    (8  => fifo_wr_in, others => '0') when "1000",
    (9  => fifo_wr_in, others => '0') when "1001",
    (10 => fifo_wr_in, others => '0') when "1010",
    (11 => fifo_wr_in, others => '0') when "1011",
    (12 => fifo_wr_in, others => '0') when "1100",
    (13 => fifo_wr_in, others => '0') when "1101",
    (14 => fifo_wr_in, others => '0') when "1110",
    (15 => fifo_wr_in, others => '0') when "1111",
    (others => '0')                   when others;
    

end Behavioral;
