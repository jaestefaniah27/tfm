-- MULTI_SERIAL_CORE.vhd
-- =========================================================================
-- N instancias del transceptor CONFIGURABLE_SERIAL_TOP en un único bloque IP.
--
-- PUERTOS:
--   Vectorizados de ancho fijo (14 canales máximo) para que el packager
--   pueda mapear rodajas estáticas a las interfaces de canal expandibles.
--   Los canales ≥ N no se instancian y sus salidas quedan a '0'.
--
-- DE / SLO:
--   Genérico booleano individual por canal (CH0_USE_DE … CH13_USE_DE).
--   Si es false → la salida queda fija a '0' y el puerto se oculta en el BD.
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package multi_serial_pkg is
  function bool_to_sl(b : boolean) return std_logic;
  function de_en_vec(
      e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12,e13 : boolean
  ) return std_logic_vector;
end package;

package body multi_serial_pkg is
  function bool_to_sl(b : boolean) return std_logic is
  begin
    if b then return '1'; else return '0'; end if;
  end function;

  function de_en_vec(
      e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12,e13 : boolean
  ) return std_logic_vector is
    variable v : std_logic_vector(13 downto 0);
  begin
    v(0)  := bool_to_sl(e0);  v(1)  := bool_to_sl(e1);
    v(2)  := bool_to_sl(e2);  v(3)  := bool_to_sl(e3);
    v(4)  := bool_to_sl(e4);  v(5)  := bool_to_sl(e5);
    v(6)  := bool_to_sl(e6);  v(7)  := bool_to_sl(e7);
    v(8)  := bool_to_sl(e8);  v(9)  := bool_to_sl(e9);
    v(10) := bool_to_sl(e10); v(11) := bool_to_sl(e11);
    v(12) := bool_to_sl(e12); v(13) := bool_to_sl(e13);
    return v;
  end function;
end package body;

-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.multi_serial_pkg.all;

entity MULTI_SERIAL_CORE is
  generic (
    N              : integer := 14;   -- Canales activos (1..14)

    -- ── Driver Enable por canal ───────────────────────────────────────────
    -- false → DE fijo a '0', puerto oculto en el block design
    -- (ej: ch7 y ch11 con DE hardcodeado en hardware → false)
    CH0_USE_DE     : boolean := true;
    CH1_USE_DE     : boolean := true;
    CH2_USE_DE     : boolean := true;
    CH3_USE_DE     : boolean := true;
    CH4_USE_DE     : boolean := true;
    CH5_USE_DE     : boolean := true;
    CH6_USE_DE     : boolean := true;
    CH7_USE_DE     : boolean := true;
    CH8_USE_DE     : boolean := true;
    CH9_USE_DE     : boolean := true;
    CH10_USE_DE    : boolean := true;
    CH11_USE_DE    : boolean := true;
    CH12_USE_DE    : boolean := true;
    CH13_USE_DE    : boolean := true;

    -- ── Slow Rate por canal ───────────────────────────────────────────────
    -- false → SLO fijo a '0', puerto oculto en el block design
    CH0_USE_SLO    : boolean := true;
    CH1_USE_SLO    : boolean := true;
    CH2_USE_SLO    : boolean := true;
    CH3_USE_SLO    : boolean := true;
    CH4_USE_SLO    : boolean := true;
    CH5_USE_SLO    : boolean := true;
    CH6_USE_SLO    : boolean := true;
    CH7_USE_SLO    : boolean := true;
    CH8_USE_SLO    : boolean := true;
    CH9_USE_SLO    : boolean := true;
    CH10_USE_SLO   : boolean := true;
    CH11_USE_SLO   : boolean := true;
    CH12_USE_SLO   : boolean := true;
    CH13_USE_SLO   : boolean := true
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;   -- Reset activo en bajo

    -- ── Interfaz paralela aplanada (14 canales fijos, canales ≥N inactivos)
    -- Canal i ocupa los bits [i*W + W-1 : i*W]  (W = 28 / 14 / 2)
    -- El packager mapea cada rodaja a la interfaz expandible channel_XX.
    ps_config    : in  std_logic_vector(14*28 - 1 downto 0);   -- 392b: config + TX
    ps_out       : out std_logic_vector(14*14 - 1 downto 0);   -- 196b: status + RX
    tx_rdy_empty : out std_logic_vector(14*2  - 1 downto 0);   --  28b: TX_RDY, EMPTY

    -- ── Líneas serie físicas (14b, un bit por canal) ──────────────────────
    TD  : out std_logic_vector(13 downto 0);
    RD  : in  std_logic_vector(13 downto 0);
    DE  : out std_logic_vector(13 downto 0);
    SLO : out std_logic_vector(13 downto 0)
  );
end MULTI_SERIAL_CORE;

architecture RTL of MULTI_SERIAL_CORE is

  component CONFIGURABLE_SERIAL_TOP
    port (
      Reset            : in  std_logic;
      Clk              : in  std_logic;
      PS_out           : out std_logic_vector(13 downto 0);
      PS_SERIAL_CONFIG : in  std_logic_vector(27 downto 0);
      TX_RDY_EMPTY     : out std_logic_vector(1 downto 0);
      TD               : out std_logic;
      RD               : in  std_logic;
      DE               : out std_logic;
      SLO              : out std_logic
    );
  end component;

  signal de_int  : std_logic_vector(13 downto 0);
  signal slo_int : std_logic_vector(13 downto 0);
  signal rst_hi  : std_logic;

  -- Vectores de habilitación derivados de los genéricos individuales
  constant DE_EN  : std_logic_vector(13 downto 0) := de_en_vec(
      CH0_USE_DE,  CH1_USE_DE,  CH2_USE_DE,  CH3_USE_DE,
      CH4_USE_DE,  CH5_USE_DE,  CH6_USE_DE,  CH7_USE_DE,
      CH8_USE_DE,  CH9_USE_DE,  CH10_USE_DE, CH11_USE_DE,
      CH12_USE_DE, CH13_USE_DE);

  constant SLO_EN : std_logic_vector(13 downto 0) := de_en_vec(
      CH0_USE_SLO,  CH1_USE_SLO,  CH2_USE_SLO,  CH3_USE_SLO,
      CH4_USE_SLO,  CH5_USE_SLO,  CH6_USE_SLO,  CH7_USE_SLO,
      CH8_USE_SLO,  CH9_USE_SLO,  CH10_USE_SLO, CH11_USE_SLO,
      CH12_USE_SLO, CH13_USE_SLO);

begin

  assert N >= 1 and N <= 14
    report "MULTI_SERIAL_CORE: N debe estar en el rango 1..14"
    severity failure;

  rst_hi <= not aresetn;

  -- ── Canales activos (0 .. N-1) ─────────────────────────────────────────
  gen_active : for i in 0 to 13 generate
    gen_inst : if i < N generate
      u_core : CONFIGURABLE_SERIAL_TOP
        port map (
          Reset            => rst_hi,
          Clk              => clk,
          PS_out           => ps_out(i*14 + 13 downto i*14),
          PS_SERIAL_CONFIG => ps_config(i*28 + 27 downto i*28),
          TX_RDY_EMPTY     => tx_rdy_empty(i*2 + 1 downto i*2),
          TD               => TD(i),
          RD               => RD(i),
          DE               => de_int(i),
          SLO              => slo_int(i)
        );
      DE(i)  <= de_int(i)  when (DE_EN(i)  = '1') else '0';
      SLO(i) <= slo_int(i) when (SLO_EN(i) = '1') else '0';
    end generate gen_inst;

    -- ── Canales inactivos (N .. 13): salidas a '0' ─────────────────────
    gen_tie : if i >= N generate
      ps_out(i*14 + 13 downto i*14)  <= (others => '0');
      tx_rdy_empty(i*2 + 1 downto i*2) <= (others => '0');
      TD(i)  <= '0';
      DE(i)  <= '0';
      SLO(i) <= '0';
    end generate gen_tie;
  end generate gen_active;

end RTL;
