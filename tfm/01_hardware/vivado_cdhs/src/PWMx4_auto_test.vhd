library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity PWMx4_auto_test is
    Port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        pwm_0 : out STD_LOGIC; -- 10 kHz
        pwm_1 : out STD_LOGIC; -- 5 kHz
        pwm_2 : out STD_LOGIC; -- 1 kHz
        pwm_3 : out STD_LOGIC  -- 100 Hz
    );
end PWMx4_auto_test;

architecture Behavioral of PWMx4_auto_test is
    -- Cálculos para reloj de 100 MHz (10 ns por ciclo)
    -- 10 kHz -> Periodo = 10.000 ciclos. Toggle en 5.000
    -- 5 kHz  -> Periodo = 20.000 ciclos. Toggle en 10.000
    -- 1 kHz  -> Periodo = 100.000 ciclos. Toggle en 50.000
    -- 100 Hz -> Periodo = 1.000.000 ciclos. Toggle en 500.000

    signal cnt_0 : integer range 0 to 9999 := 0;
    signal cnt_1 : integer range 0 to 19999 := 0;
    signal cnt_2 : integer range 0 to 99999 := 0;
    signal cnt_3 : integer range 0 to 999999 := 0;

    signal p_0, p_1, p_2, p_3 : std_logic := '0';
begin
process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt_0 <= 0; cnt_1 <= 0; cnt_2 <= 0; cnt_3 <= 0;
                pwm_0 <= '0'; pwm_1 <= '0'; pwm_2 <= '0'; pwm_3 <= '0';
            else
                -- Canal 0: 10 kHz
                if cnt_0 = 9999 then cnt_0 <= 0; else cnt_0 <= cnt_0 + 1; end if;
                if cnt_0 < 5000 then pwm_0 <= '1'; else pwm_0 <= '0'; end if;

                -- Canal 1: 5 kHz
                if cnt_1 = 19999 then cnt_1 <= 0; else cnt_1 <= cnt_1 + 1; end if;
                if cnt_1 < 10000 then pwm_1 <= '1'; else pwm_1 <= '0'; end if;

                -- Canal 2: 1 kHz
                if cnt_2 = 99999 then cnt_2 <= 0; else cnt_2 <= cnt_2 + 1; end if;
                if cnt_2 < 50000 then pwm_2 <= '1'; else pwm_2 <= '0'; end if;

                -- Canal 3: 100 Hz
                if cnt_3 = 999999 then cnt_3 <= 0; else cnt_3 <= cnt_3 + 1; end if;
                if cnt_3 < 500000 then pwm_3 <= '1'; else pwm_3 <= '0'; end if;
            end if;
        end if;
    end process;
end Behavioral;