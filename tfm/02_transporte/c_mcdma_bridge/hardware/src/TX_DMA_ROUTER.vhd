----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/26/2026 04:57:30 PM
-- Design Name: 
-- Module Name: TX_DMA_ROUTER - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TX_DMA_ROUTER is
    Port ( 
           aclk : in STD_LOGIC;
           aresetn : in STD_LOGIC;
           -- S_AXIS_TX
           s_axis_tdata : in STD_LOGIC_VECTOR (7 downto 0);
           s_axis_tvalid : in STD_LOGIC;
           s_axis_tready : out STD_LOGIC;
           s_axis_tlast : in STD_LOGIC;
           -- TX_FIFO
           TX_ID : out STD_LOGIC_VECTOR (3 downto 0);
           fifo_din : out STD_LOGIC_VECTOR (7 downto 0);
           fifo_full : in STD_LOGIC;
           fifo_wr : out STD_LOGIC);
end TX_DMA_ROUTER;

architecture Behavioral of TX_DMA_ROUTER is

type estados is (Idle, TX_ID_store_MSG_LEN_store, TX_FIFO_STORE_MSG);
signal current_state, next_state: estados;

signal TX_index_reg, TX_index_next : std_logic_vector(3 downto 0);
signal MSG_LEN_reg, MSG_LEN_next : std_logic_vector(11 downto 0);

constant MSG_LEN_ZERO : std_logic_vector(11 downto 0) := (others => '0');

begin
-- TX_Index and message length registers
Process(aclk, aresetn)
begin
    if aresetn = '0' then
        TX_index_reg <= (others=>'0');
        MSG_LEN_reg <= (others=>'0');
    elsif rising_edge(aclk) then
        TX_index_reg <= TX_index_next;
        MSG_LEN_reg <= MSG_LEN_next;
    end if;
end process;

-- State register
process(aclk, aresetn)
begin
    if aresetn = '0' then
        current_state <= Idle;
    elsif rising_edge(aclk) then
        current_state <= next_state;
    end if;
end process;

-- FSM Combinational
Process(current_state, s_axis_tdata, s_axis_tvalid, MSG_LEN_reg, TX_index_reg, fifo_full)
begin
-- Defaults
next_state <= current_state;
TX_index_next <= TX_index_reg;
MSG_LEN_next <= MSG_LEN_reg;
fifo_wr <= '0';
s_axis_tready <= '1';

case current_state is

    when Idle =>
        if s_axis_tvalid = '1' then
            next_state <= TX_ID_store_MSG_LEN_store;
            TX_index_next <= s_axis_tdata(7 downto 4);
            MSG_LEN_next(11 downto 8) <= s_axis_tdata(3 downto 0);
        end if;
        
    when TX_ID_store_MSG_LEN_store => 
        if s_axis_tvalid = '1' then
            next_state <= TX_FIFO_STORE_MSG;
            MSG_LEN_next(7 downto 0) <= s_axis_tdata;
        end if;
    
    -- Contrapresión: la FIFO del canal se vacía al ritmo de la UART (115200 bps)
    -- mientras la DMA vuelca a la frecuencia del bus. Sin bajar tready, todo lo
    -- que no cabía se perdía en silencio y el frame se truncaba al tamaño de la
    -- FIFO. Con la FIFO llena se retiene tready y no se escribe ni se decrementa.
    when TX_FIFO_STORE_MSG =>
        if MSG_LEN_reg = MSG_LEN_ZERO then
            next_state <= Idle;
            s_axis_tready <= '0';
        else
            s_axis_tready <= not fifo_full;
            if s_axis_tvalid = '1' and fifo_full = '0' then
                fifo_wr <= '1';
                MSG_LEN_next <= std_logic_vector(unsigned(MSG_LEN_reg) - 1);
            end if;
        end if;
end case;
end process;

-- Outputs
TX_ID <= TX_index_reg;
fifo_din <= s_axis_tdata;
end Behavioral;
