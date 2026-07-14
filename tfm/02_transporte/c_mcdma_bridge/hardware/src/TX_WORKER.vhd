----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2026 01:37:58 PM
-- Design Name: 
-- Module Name: TX_WORKER - Behavioral
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

entity TX_WORKER is
  Port (
    aclk        : in  std_logic;
    aresetn     : in  std_logic;
    wr_en       : in  std_logic;
    din         : in  std_logic_vector(7 downto 0);
    fifo_full   : out std_logic;   -- contrapresión hacia TX_DMA_ROUTER
    TX_din      : out std_logic_vector(8 downto 0);
    TX_Send     : out std_logic;
    Send_ok     : in  std_logic;
    TX_RDY      : in  std_logic;
    EOT         : in  std_logic;
    EOF         : out std_logic);
end TX_WORKER;

architecture Behavioral of TX_WORKER is

  component fifo_tx
    port (
      clk   : IN  std_logic;
      srst  : IN  std_logic;
      din   : IN  std_logic_VECTOR(7 downto 0);
      wr_en : IN  std_logic;
      rd_en : IN  std_logic;
      dout  : OUT std_logic_VECTOR(7 downto 0);
      full  : OUT std_logic;
      empty : OUT std_logic);
  end component;

  -- FSM que alimenta el core UART byte a byte:
  --   S_IDLE  : con dato en el FIFO (FWFT → dout válido) y core listo (TX_RDY='1')
  --   S_START : se mantiene TX_Send hasta que el core captura el dato y arranca
  --             (Send_ok pasa a '1'); en ese momento se hace pop del FIFO (rd_en).
  --   S_BUSY  : se espera a que el core termine la trama (TX_RDY vuelve a '1') antes
  --             de lanzar el siguiente byte. Si el FIFO queda vacío → pulso EOF.
  type estados is (S_IDLE, S_START, S_BUSY);
  signal current_state, next_state : estados;

  signal fifo_reset, rd_en, full, empty : std_logic;
  signal dout : std_logic_vector(7 downto 0);

begin

  fifo_reset <= not aresetn;

  Shift: fifo_tx
    port map (
      Clk  => aclk,
      srst => fifo_reset,
      din => din,
      wr_en => wr_en,
      rd_en => rd_en,
      dout => dout,
      full => full,
      empty => empty);

  fifo_full <= full;

  -- Registro de estado
  process(aclk, aresetn)
  begin
    if aresetn = '0' then
      current_state <= S_IDLE;
    elsif rising_edge(aclk) then
      current_state <= next_state;
    end if;
  end process;

  -- Lógica de próximo estado / salidas
  process(current_state, empty, TX_RDY, Send_ok)
  begin
    next_state <= current_state;
    TX_Send    <= '0';
    rd_en      <= '0';
    EOF        <= '0';

    case current_state is
      when S_IDLE =>
        if empty = '0' and TX_RDY = '1' then
          next_state <= S_START;
        end if;

      when S_START =>
        TX_Send <= '1';
        if Send_ok = '1' then       -- el core capturó el dato y empezó a transmitir
          rd_en      <= '1';       -- avanza el FIFO al siguiente byte (FWFT)
          next_state <= S_BUSY;
        end if;

      when S_BUSY =>
        if TX_RDY = '1' then       -- transmisión completa
          if empty = '1' then
            EOF <= '1';            -- canal drenó su trama por completo
          end if;
          next_state <= S_IDLE;
        end if;
    end case;
  end process;

  -- Salida de datos hacia el core (bit 8 = '0', byte de 8 bits)
  TX_din <= '0' & dout;

end Behavioral;
