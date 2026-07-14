----------------------------------------------------------------------------------
-- tb_CONFIGURABLE_SERIAL_TOP.vhd
-- Testbench para CONFIGURABLE_SERIAL_TOP: loopback TX->RD y comprobación RX
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_CONFIGURABLE_SERIAL_TOP is
end tb_CONFIGURABLE_SERIAL_TOP;

architecture Behavioral of tb_CONFIGURABLE_SERIAL_TOP is

  component CONFIGURABLE_SERIAL_TOP
    port (
      Reset     : in  std_logic;
      Clk       : in  std_logic;
      -- TX
      Data_in   : in  std_logic_vector(8 downto 0);
      TX_Send   : in  std_logic;
      Ack_in    : out std_logic;
      TX_RDY    : out std_logic;
      TD        : out std_logic;
      -- RX
      RD        : in  std_logic;
      Data_out  : out std_logic_vector(8 downto 0);
      Data_read : in  std_logic;
      Full      : out std_logic;
      Empty     : out std_logic;
      PAR_ERROR : out std_logic;
      FRAME_ERROR : out std_logic;
      ERROR_OK  : in std_logic;
      -- CONFIG
      baudrate  : in std_logic_vector(31 downto 0);
      stop_bit  : in std_logic_vector(2 downto 0);
      parity    : in std_logic_vector(2 downto 0);
      bit_order : in std_logic;
      data_bits : in std_logic_vector(2 downto 0)
    );
  end component;

  -- clock / reset
  signal Clk       : std_logic := '0';
  signal Reset     : std_logic := '0';

  -- TX side controls
  signal Data_in   : std_logic_vector(8 downto 0) := (others => '0');
  signal TX_Send   : std_logic := '1';  -- active low
  signal Ack_in    : std_logic;
  signal TX_RDY    : std_logic;
  signal TD         : std_logic := '1';

  -- RX side wiring (loopback RD <- TD)
  signal RD         : std_logic := '1';
  signal Data_out  : std_logic_vector(8 downto 0);
  signal Data_read : std_logic := '0';
  signal Full       : std_logic;
  signal Empty      : std_logic;
  signal PAR_ERROR  : std_logic;
  signal FRAME_ERROR: std_logic;

  signal ERROR_OK   : std_logic := '1';

  -- config signals
  signal baudrate   : std_logic_vector(31 downto 0) := (others => '0');
  signal stop_bit   : std_logic_vector(2 downto 0) := "010";
  signal parity     : std_logic_vector(2 downto 0) := "100"; -- disabled by default
  signal bit_order  : std_logic := '0';
  signal data_bits  : std_logic_vector(2 downto 0) := "011"; -- 8 bits default

  constant CLK_PERIOD : time := 10 ns; -- 100 MHz
  signal TD_loopback_delay : time := 0 ns; -- if you want to insert propagation delay

begin

  -- clock
  Clk <= not Clk after CLK_PERIOD/2;

  -- DUT
  DUT: CONFIGURABLE_SERIAL_TOP
    port map(
      Reset => Reset,
      Clk => Clk,
      Data_in => Data_in,
      TX_Send => TX_Send,
      Ack_in => Ack_in,
      TX_RDY => TX_RDY,
      TD => TD,
      RD => RD,
      Data_out => Data_out,
      Data_read => Data_read,
      Full => Full,
      Empty => Empty,
      PAR_ERROR => PAR_ERROR,
      FRAME_ERROR => FRAME_ERROR,
      ERROR_OK => ERROR_OK,
      baudrate => baudrate,
      stop_bit => stop_bit,
      parity => parity,
      bit_order => bit_order,
      data_bits => data_bits
    );

  -- loopback TD -> RD con retardo configurable
  RD <= TD after TD_loopback_delay;

  ------------------------------------------------------------------
  -- Stimulus and test procedure (inside single process; local procedures allowed)
  ------------------------------------------------------------------
  stim_proc: process
    -- variables
    variable pass_count : integer := 0;
    variable fail_count : integer := 0;
    variable total_tests: integer := 0;
    variable nbits      : integer;
    variable expected   : unsigned(8 downto 0);
    variable received   : unsigned(8 downto 0);
    variable mask      : unsigned(8 downto 0);
    variable t_wait    : time;
    variable timeout   : time;
    variable idx       : integer;
    -- helper inner procedure: send one byte via TX using handshake
    procedure send_tx_byte(byte9 : in std_logic_vector(8 downto 0)) is
    begin
      report "==== sending byte ====" severity note;

      -- wait TX ready
      if TX_RDY = '0' then
        wait until TX_RDY = '1';
      end if;
      -- place data and pulse TX_Send (active low)
      Data_in <= byte9;
      wait for CLK_PERIOD;
      TX_Send <= '0';
      wait for CLK_PERIOD;
      TX_Send <= '1';
      -- wait for ack (active low) with timeout
      timeout := 0 ns;
      while (Ack_in /= '0') and (timeout < 5 ms) loop
        wait for CLK_PERIOD;
        timeout := timeout + CLK_PERIOD;
      end loop;
      if Ack_in /= '0' then
        report "WARN: TX ack not asserted in time" severity warning;
      end if;
      -- small settle
      wait for CLK_PERIOD * 2;
    end procedure;

  begin
    -- initial reset
    Reset <= '0';
    wait for 200 ns;
    Reset <= '1';
    wait for 100 ns;

    -- set baudrate NCO value or direct baud (adapt if your top uses INC or baud)
    -- If top expects actual baud value, set to 921600 as decimal
    baudrate <= std_logic_vector(to_unsigned(921600, 32));

    report "==== TB START: TX->RX loopback tests ====" severity note;

    -- iterate configurations: data_bits 5..9, bit_order 0/1, stopbits 1/1.5/2, parity 0..4
    for db in 0 to 4 loop
      case db is
        when 0 => data_bits <= "000"; nbits := 5;
        when 1 => data_bits <= "001"; nbits := 6;
        when 2 => data_bits <= "010"; nbits := 7;
        when 3 => data_bits <= "011"; nbits := 8;
        when others => data_bits <= "100"; nbits := 9;
      end case;

      for order_i in 0 to 1 loop
        if order_i = 0 then 
            bit_order <= '0'; 
        else
            bit_order <= '1'; 
        end if;

        for sb in 1 to 3 loop
          case sb is
            when 1 => stop_bit <= "010"; -- 1 stop
            when 2 => stop_bit <= "011"; -- 1.5 stop (encoded as you use)
            when others => stop_bit <= "100"; -- 2 stop
          end case;

          for p in 0 to 4 loop
            case p is
              when 0 => parity <= "000"; -- EVEN
              when 1 => parity <= "001"; -- ODD
              when 2 => parity <= "010"; -- MARK
              when 3 => parity <= "011"; -- SPACE
              when others => parity <= "100"; -- DISABLED
            end case;

            -- send a sequence of bytes for this configuration
            for test_byte in 0 to 2 loop
              -- form unique 9-bit value; lower nbits will be used by TX/RX
              idx := test_byte + db*7 + order_i*3 + sb*11 + p*17;
              -- place pattern in lower bits (LSB-first assumption)
              --Data_in <= std_logic_vector(to_unsigned(idx mod (2**nbits), 9));
              Data_in <= "101010101";

              -- transmit using handshake
              send_tx_byte(Data_in);

              -- now wait for RX to produce data (Empty -> '0' means data available)
              timeout := 0 ns;
              t_wait := 0 ns;
              while (Empty = '1') and (timeout < 50 ms) loop
                wait for CLK_PERIOD;
                timeout := timeout + CLK_PERIOD;
              end loop;

              if Empty = '1' then
                -- timed out
                report "FAIL: timeout waiting for RX data (cfg db=" & integer'image(nbits) &
                       " order=" & std_logic'image(bit_order) & " stop=" & integer'image(sb) &
                       " par=" & integer'image(p) & ")" severity error;
                fail_count := fail_count + 1;
                total_tests := total_tests + 1;
                next; -- continue to next test_byte
              end if;

              -- read the data: pulse Data_read = '1' for one clk
              Data_read <= '1';
              wait for CLK_PERIOD;
              Data_read <= '0';
              wait for CLK_PERIOD; -- let Data_out settle

              -- build mask for nbits
              mask := (others => '0');
              for i in 0 to nbits-1 loop
                mask := mask or (to_unsigned(1,9) sll i);
              end loop;

              expected := unsigned(Data_in) and mask;
              received := unsigned(Data_out) and mask;

              -- check parity/frame error outputs and report (but don't fail the test automatically)
              if PAR_ERROR = '1' then
                report "NOTE: PARITY ERROR flagged by RX for this frame" severity warning;
              end if;
              if FRAME_ERROR = '1' then
                report "NOTE: FRAME ERROR flagged by RX for this frame" severity warning;
              end if;

              -- compare
              if received = expected then
                pass_count := pass_count + 1;
                report "PASS cfg bits=" & integer'image(nbits) &
                       " order=" & std_logic'image(bit_order) &
                       " stop=" & integer'image(sb) &
                       " par=" & integer'image(p) &
                       " sent=" & integer'image(to_integer(unsigned(Data_in) and mask)) &
                       " rec=" & integer'image(to_integer(unsigned(Data_out) and mask)) severity note;
              else
                fail_count := fail_count + 1;
                report "FAIL cfg bits=" & integer'image(nbits) &
                       " order=" & std_logic'image(bit_order) &
                       " stop=" & integer'image(sb) &
                       " par=" & integer'image(p) &
                       " sent=" & integer'image(to_integer(unsigned(Data_in) and mask)) &
                       " rec=" & integer'image(to_integer(unsigned(Data_out) and mask)) severity error;
              end if;
              total_tests := total_tests + 1;

              -- small gap between frames
              wait for 1 ms;
            end loop; -- test_byte
          end loop; -- parity
        end loop; -- stopbits
      end loop; -- order
    end loop; -- data_bits

    -- summary
    report "==== TESTS FINISHED ====" severity note;
    report "Passed = " & integer'image(pass_count) & " / Total = " & integer'image(total_tests) severity note;

    wait;
  end process stim_proc;

end Behavioral;
