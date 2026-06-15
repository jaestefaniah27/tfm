library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

entity tb_NCO is
end entity;

architecture sim of tb_NCO is
  constant N           : integer := 32;
  constant CLK_FREQ_HZ : natural := 100_000_000;
  constant TCLK        : time    := 10 ns;

  signal clk        : std_logic := '0';
  signal rst        : std_logic := '0'; -- rst activo a '0' en el NCO
  signal en         : std_logic := '0';
  signal half_mode  : std_logic := '0';
  signal baudrate   : std_logic_vector(N-1 downto 0) := (others => '0');
  signal tick       : std_logic := '0';

  signal tick_d     : std_logic := '0';
  signal tick_rise  : std_logic := '0';

  component NCO
    generic(N : integer := 32);
    port(
      clk       : in  std_logic;
      rst       : in  std_logic;                 -- activo a '0'
      en        : in  std_logic;
      half_mode : in  std_logic;
      baudrate  : in  std_logic_vector(N-1 downto 0);
      tick      : out std_logic
    );
  end component;

  ----------------------------------------------------------------
  -- Lista de baudios
  ----------------------------------------------------------------
  constant BAUD_COUNT : natural := 37; -- número de entradas

  type int_arr is array (0 to BAUD_COUNT-1) of integer;

  constant BAUD_LIST : int_arr := (
    110,300,600,1200,1800,2400,4800,7200,9600,14400,19200,28800,31250,38400,
    56000,57600,74400,115200,128000,153600,230400,256000,312500,460800,500000,
    576000,614400,750000,921600,1000000,1152000,1500000,1843200,2000000,2500000,
    3000000,3686400
  );

  -- Parámetros globales de medida (declarados aquí)
  constant N_PERIODS_AVG : natural := 200;  -- número de periodos promediados
  constant SETTLE_SKIP   : natural := 10;   -- saltos iniciales para estabilizar

begin
  -- Instancia del UUT
  uut: NCO
    generic map(N => N)
    port map(
      clk       => clk,
      rst       => rst,
      en        => en,
      half_mode => half_mode,
      baudrate  => baudrate,
      tick      => tick
    );

  -- Reloj de 100 MHz
  clk <= not clk after TCLK/2;

  -- Detección de flanco
  process(clk)
  begin
    if rising_edge(clk) then
      tick_d    <= tick;
      if (tick = '1') and (tick_d = '0') then
        tick_rise <= '1';
      else
        tick_rise <= '0';
      end if;
    end if;
  end process;

  ----------------------------------------------------------------
  -- Proceso de estímulos y medición
  ----------------------------------------------------------------
  stim: process
    variable L : line;

    -- Procedimiento de logging simple
    procedure log(s : in string) is
    begin
      write(L, s);
      writeline(output, L);
    end procedure;

    -- Procedimiento de medida: recibe cfg_name como string (integer'image)
    procedure measure_config(
      constant cfg_name     : in string;
      constant baud_i       : in integer;
      constant half         : in std_logic;
      constant expected_hz  : in real;
      constant nperiods_avg : in natural;
      constant settle_skip  : in natural
    ) is
      variable cycles_between : natural := 0;
      variable sum_cycles     : natural := 0;
      variable periods_done   : natural := 0;
      variable skipped        : natural := 0;
      variable freq_meas      : real;
      variable err_hz         : real;
      variable err_ppm        : real;
      variable half_str       : string(1 to 1);
    begin
      if half = '1' then
        half_str := "1";
      else
        half_str := "0";
      end if;

      -- Cabecera
      write(L, string'("---- Configuración: "));
      write(L, cfg_name);
      write(L, string'(" half="));
      write(L, half_str);
      write(L, string'(" baud="));
      write(L, baud_i);
      write(L, string'(" ----"));
      writeline(output, L);

      -- Asignar baudrate al NCO (valor decimal en el vector)
      baudrate <= std_logic_vector(to_unsigned(baud_i, N));
      half_mode <= half;

      -- Esperar a que empiece a oscilar (dos ticks para estabilizar)
      wait until rising_edge(clk) and tick_rise = '1';
      wait until rising_edge(clk) and tick_rise = '1';

      cycles_between := 0;
      sum_cycles     := 0;
      periods_done   := 0;
      skipped        := 0;

      -- Bucle de medición
      while periods_done < nperiods_avg loop
        wait until rising_edge(clk);
        cycles_between := cycles_between + 1;
        if tick_rise = '1' then
          if skipped < settle_skip then
            skipped := skipped + 1;
            cycles_between := 0;
          else
            sum_cycles     := sum_cycles + cycles_between;
            periods_done   := periods_done + 1;
            cycles_between := 0;
          end if;
        end if;
      end loop;

      -- Evitar división entre 0
      if sum_cycles = 0 then
        log("ERROR: No se detectaron ticks, omitiendo medida.");
      else
        freq_meas := real(CLK_FREQ_HZ) / (real(sum_cycles) / real(nperiods_avg));
        err_hz    := freq_meas - expected_hz;
        err_ppm   := (err_hz / expected_hz) * 1.0e6;

        -- Imprime resumen con formato
        write(L, string'("CFG="));
        write(L, cfg_name);
        write(L, string'(" expected="));
        write(L, expected_hz, right, 0, 1);
        write(L, string'(" Hz  measured="));
        write(L, freq_meas, right, 0, 6);
        write(L, string'(" Hz  err="));
        write(L, err_hz, right, 0, 6);
        write(L, string'(" Hz ("));
        write(L, err_ppm, right, 0, 1);
        write(L, string'(" ppm)"));
        writeline(output, L);
      end if;
    end procedure;

  begin
    -- Reset (activo a '0'): arrancamos en reset, luego lo soltamos
    rst <= '0';
    en  <= '0';
    wait for 200 ns;
    rst <= '1'; -- desactivamos reset
    wait for 50 ns;
    en <= '1';
    wait for 100 ns;

    -- Recorre todo el array de baudios y prueba half=0 y half=1
    for i in 8 to BAUD_COUNT-1 loop
      -- half = '0' -> frecuencia nominal
      measure_config(integer'image(BAUD_LIST(i)), BAUD_LIST(i), '0', real(BAUD_LIST(i)),                      N_PERIODS_AVG, SETTLE_SKIP);
      -- half = '1' -> tick a 2x baud
      measure_config(integer'image(BAUD_LIST(i)), BAUD_LIST(i), '1', real(BAUD_LIST(i)) * 2.0,              N_PERIODS_AVG, SETTLE_SKIP);
    end loop;

    log("Fin del testbench: medidas completadas para todas las frecuencias.");
    wait;
  end process;

end architecture;
