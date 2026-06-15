library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_RS232_TX is
end tb_RS232_TX;

architecture sim of tb_RS232_TX is

    -- DUT signals
    signal clk       : std_logic := '0';
    signal reset     : std_logic := '0';
    signal start     : std_logic := '0';
    signal data      : std_logic_vector(8 downto 0) := (others => '0');
    signal baudrate  : std_logic_vector(31 downto 0);
    signal stop_bit  : std_logic_vector(2 downto 0) := "011"; -- 1 stop
    signal parity    : std_logic_vector(2 downto 0) := "100"; -- NO PARITY
    signal bit_order : std_logic := '0'; -- LSB-first
    signal data_bits : std_logic_vector(2 downto 0) := "011"; -- 8 bits

    signal EOT       : std_logic;
    signal TX        : std_logic := '1';

    constant CLK_PERIOD : time := 10 ns;   -- 100 MHz clock
    constant BAUD_INT   : integer := 921600;
    constant BIT_NS     : integer := integer(1000000000 / BAUD_INT); -- truncates fractional ns
    constant HALF_NS    : time := (BIT_NS / 2) * 1 ns;
    constant BIT_TIME   : time := BIT_NS * 1 ns;

begin

    --------------------------------------------------------------------
    -- CLOCK
    --------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    --------------------------------------------------------------------
    -- DUT instantiation (assumes module RS232_TX exists in work)
    --------------------------------------------------------------------
    DUT: entity work.RS232_TX
    port map(
        Clk       => clk,
        Reset     => reset,
        Start     => start,
        Data      => data,
        baudrate  => baudrate,
        stop_bit  => stop_bit,
        parity    => parity,
        bit_order => bit_order,
        data_bits => data_bits,
        EOT       => EOT,
        TX        => TX
    );

    --------------------------------------------------------------------
    -- Baudrate constant (INC value used previously)
    --------------------------------------------------------------------
    baudrate <= std_logic_vector(to_unsigned(BAUD_INT, 32)); -- 115200 @100MHz NCO_INC

    --------------------------------------------------------------------
    -- STIMULUS + AUTOCHECK (reemplaza el proceso anterior)
    --------------------------------------------------------------------
    stim: process
        variable expected : std_logic_vector(8 downto 0);
        variable nbits_i  : integer;
        variable stop_half_count : integer;
        variable order_var : integer;
        variable p_var     : integer;

        -- contadores de resultados
        variable pass_count : integer := 0;
        variable fail_count : integer := 0;

        -- resultado temporal de la comprobación (declarado AQUI)
        variable okres : boolean := false;

        -- procedimiento local dentro del process (permite usar wait)
        procedure check_frame(
            signal tx_sig      : in std_logic;
            expected_word      : in std_logic_vector(8 downto 0);
            nbits              : in integer;
            order_lsb          : in boolean;
            stop_half_count_in : in integer;
            parity_mode        : in std_logic_vector(2 downto 0);
            result             : out boolean
        ) is
            variable sampled_bits : std_logic_vector(8 downto 0) := (others => '0');
            variable i            : integer;
            variable received_val : unsigned(8 downto 0) := (others => '0');
            variable ok           : boolean := true;
            variable stop_i       : integer;
            variable mask         : unsigned(8 downto 0) := (others => '0');
            variable parity_raw   : std_logic := '0';
            variable parity_expected : std_logic := '0';
            variable sampled_parity  : std_logic := '0';
        begin
            -- Wait half bit to sample center of start
            wait for HALF_NS;
            -- sample start bit center (should be '0')
            if tx_sig /= '0' then
                report "FAIL: start bit not 0" severity warning;
                ok := false;
            end if;

            -- wait one full BIT to reach center of data bit 0
            wait for BIT_TIME;

            -- sample data bits
            for i in 0 to nbits-1 loop
                if order_lsb then
                    sampled_bits(i) := tx_sig;  -- LSB-first fills from LSB upward
                else
                    sampled_bits(nbits-1 - i) := tx_sig;
                end if;
                wait for BIT_TIME;
            end loop;

            -- At this point we are at center of next bit: parity (if any) or first stop half
            -- If parity enabled (mode not "100"), sample parity bit now
            if parity_mode /= "100" then
                sampled_parity := tx_sig;  -- center of parity
                -- compute parity_raw from expected_word (only nbits)
                parity_raw := '0';
                for i in 0 to nbits-1 loop
                    parity_raw := parity_raw xor expected_word(i);
                end loop;
                -- parity_expected according to mode
                if parity_mode = "000" then            -- EVEN
                    parity_expected := parity_raw;
                elsif parity_mode = "001" then         -- ODD
                    parity_expected := not parity_raw;
                elsif parity_mode = "010" then         -- MARK
                    parity_expected := '1';
                elsif parity_mode = "011" then         -- SPACE
                    parity_expected := '0';
                else
                    parity_expected := '0';
                end if;

                if sampled_parity /= parity_expected then
                    report "FAIL: parity mismatch. expected=" & std_logic'image(parity_expected) &
                           " sampled=" & std_logic'image(sampled_parity) severity warning;
                    ok := false;
                end if;

                -- after sampling parity, move to first stop half center
                wait for BIT_TIME;
            end if;

            -- Check stop bits (sample centers). We expect '1'
            for stop_i in 1 to stop_half_count_in loop
                if tx_sig /= '1' then
                    report "FAIL: stop bit not 1 at half-index " & integer'image(stop_i) severity warning;
                    ok := false;
                end if;
                wait for BIT_TIME;
            end loop;

            -- Build received_val from sampled_bits (mask to nbits)
            for i in 0 to nbits-1 loop
                if sampled_bits(i) = '1' then
                    received_val := received_val or (to_unsigned(1,9) sll i);
                end if;
                mask := mask or (to_unsigned(1,9) sll i);
            end loop;

            -- comparación de datos (tipos unsigned)
            if (received_val and mask) = (unsigned(expected_word) and mask) then
                if ok then
                    if order_lsb then
                        report "PASS: received matches expected (bits=" & integer'image(nbits) &
                               ", order=LSB, stop_half=" & integer'image(stop_half_count_in) severity note;
                    else
                        report "PASS: received matches expected (bits=" & integer'image(nbits) &
                               ", order=MSB, stop_half=" & integer'image(stop_half_count_in) severity note;
                    end if;
                    result := true;
                else
                    report "WARN: data matched but framing/parity had issues" severity warning;
                    result := false;
                end if;
            else
                report "FAIL: data mismatch. expected=" &
                       integer'image(to_integer(unsigned(expected_word) and mask)) &
                       " received=" &
                       integer'image(to_integer(received_val and mask)) severity error;
                result := false;
            end if;
        end procedure;

    begin
        -- Reset
        reset <= '0';
        wait for 200 ns;
        reset <= '1';
        wait for 100 ns;

        report "==== INICIANDO TEST UART TX AUTOCHECK (incluye paridad) ====" severity note;

        for bits in 0 to 4 loop  -- 5..9 bits
            case bits is
                when 0 => data_bits <= "000"; nbits_i := 5;
                when 1 => data_bits <= "001"; nbits_i := 6;
                when 2 => data_bits <= "010"; nbits_i := 7;
                when 3 => data_bits <= "011"; nbits_i := 8;
                when others => data_bits <= "100"; nbits_i := 9;
            end case;

            for order_var in 0 to 1 loop
                if order_var = 0 then bit_order <= '0'; else bit_order <= '1'; end if;

                for sb in 1 to 3 loop  -- 1, 1.5, 2
                    case sb is
                        when 1 => stop_bit <= "010"; stop_half_count := 2; -- 1 bit = 2 half-ticks
                        when 2 => stop_bit <= "011"; stop_half_count := 3; -- 1.5 bit = 3 half-ticks
                        when others => stop_bit <= "100"; stop_half_count := 4; -- 2 bits = 4 half-ticks
                    end case;

                    for p_var in 0 to 4 loop  -- parity modes 0..4
                        case p_var is
                            when 0 => parity <= "000"; -- EVEN
                            when 1 => parity <= "001"; -- ODD
                            when 2 => parity <= "010"; -- MARK
                            when 3 => parity <= "011"; -- SPACE
                            when others => parity <= "100"; -- DISABLED
                        end case;

                        -- prepare data; unique per test
                        expected := std_logic_vector(to_unsigned( (16#155# + bits*7 + order_var*3 + sb + p_var), 9));
                        data <= expected;

                        report "TEST -> bits=" & integer'image(nbits_i) & " order=" & std_logic'image(bit_order) &
                               " stop=" & integer'image(sb) & " parity=" & integer'image(p_var) severity note;

                        -- issue start pulse
                        start <= '1';
                        wait for CLK_PERIOD;
                        start <= '0';

                        -- now call the checker (it samples TX)
                        check_frame(TX, expected, nbits_i, (bit_order='0'), stop_half_count, parity, okres);

                        if okres then
                            pass_count := pass_count + 1;
                        else
                            fail_count := fail_count + 1;
                        end if;

                        -- small gap between frames
                        wait for 200 ns;
                    end loop; -- parity
                end loop; -- stopbits
            end loop; -- order
        end loop; -- bits

        report "==== TODAS LAS PRUEBAS FINALIZADAS ====" severity note;
        report "RESULT: Passed = " & integer'image(pass_count) & " / Total = " & integer'image(pass_count + fail_count) severity note;

        wait;
    end process;
    

    

end architecture;
