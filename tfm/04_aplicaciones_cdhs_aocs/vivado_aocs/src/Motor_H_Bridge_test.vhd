library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Motor_H_Bridge_test
-- Test de puentes en H: genera PWM a 10kHz (~50% duty) y alterna
-- cada 2 segundos entre los dos sentidos de giro de los 3 ejes.
--
-- Fase A (dir='0'): PWM en pwm_x_1, pwm_y_1, pwm_z_1  (x_2, y_2, z_2 = '0')
-- Fase B (dir='1'): PWM en pwm_x_2, pwm_y_2, pwm_z_2  (x_1, y_1, z_1 = '0')

entity Motor_H_Bridge_test is
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        pwm_x_1  : out STD_LOGIC;
        pwm_x_2  : out STD_LOGIC;
        pwm_y_1  : out STD_LOGIC;
        pwm_y_2  : out STD_LOGIC;
        pwm_z_1  : out STD_LOGIC;
        pwm_z_2  : out STD_LOGIC
    );
end Motor_H_Bridge_test;

architecture Behavioral of Motor_H_Bridge_test is

    -- PWM a 10 kHz con reloj de 100 MHz -> periodo = 10_000 ciclos
    constant PWM_PERIOD : integer := 10_000;
    constant PWM_DUTY   : integer := 5_000;   -- 50% duty cycle

    -- Cambio de sentido cada 2 s -> 200_000_000 ciclos
    constant DIR_PERIOD : integer := 200_000_000;

    signal pwm_cnt : integer range 0 to PWM_PERIOD - 1 := 0;
    signal dir_cnt : integer range 0 to DIR_PERIOD - 1 := 0;
    signal pwm_sig : std_logic := '0';
    signal dir     : std_logic := '0';  -- '0' = grupo 1, '1' = grupo 2

begin

    -- Generador PWM (10 kHz, 50% duty)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                pwm_cnt <= 0;
                pwm_sig <= '0';
            else
                if pwm_cnt = PWM_PERIOD - 1 then
                    pwm_cnt <= 0;
                else
                    pwm_cnt <= pwm_cnt + 1;
                end if;

                if pwm_cnt < PWM_DUTY then
                    pwm_sig <= '1';
                else
                    pwm_sig <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Contador de dirección (alterna cada 2 s)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                dir_cnt <= 0;
                dir     <= '0';
            else
                if dir_cnt = DIR_PERIOD - 1 then
                    dir_cnt <= 0;
                    dir     <= not dir;
                else
                    dir_cnt <= dir_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Enrutamiento: PWM al grupo activo, '0' al inactivo
    pwm_x_1 <= pwm_sig when dir = '0' else '0';
    pwm_y_1 <= pwm_sig when dir = '0' else '0';
    pwm_z_1 <= pwm_sig when dir = '0' else '0';

    pwm_x_2 <= pwm_sig when dir = '1' else '0';
    pwm_y_2 <= pwm_sig when dir = '1' else '0';
    pwm_z_2 <= pwm_sig when dir = '1' else '0';

end Behavioral;