library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AND_GATE is
    Port ( A_B_IN : in  STD_LOGIC_VECTOR (1 downto 0);
           Z_OUT  : out STD_LOGIC);
end AND_GATE;

architecture Behavioral of AND_GATE is
begin
    Z_OUT <= A_B_IN(1) and A_B_IN(0);
end Behavioral;
