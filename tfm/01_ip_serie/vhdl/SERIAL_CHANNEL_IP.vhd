-- SERIAL_CHANNEL_IP.vhd
-- =========================================================================
-- Wrapper de un canal serie sobre CONFIGURABLE_SERIAL_TOP.
-- Añade dos genéricos booleanos (USE_DE, USE_SLO) que controlan si el pin
-- DE / SLO se expone o se fuerza a '0'.
--
-- USO EN BLOCK DESIGN:
--   Arrastrar N instancias de este IP al BD, una por canal.
--   Cada instancia tiene su propio diálogo con USE_DE y USE_SLO.
--   Puertos (máximo 9, algunos opcionales):
--     clk, aresetn, ps_config[27:0], ps_out[13:0], tx_rdy_empty[1:0]
--     TD, RD, DE (si USE_DE=true), SLO (si USE_SLO=true)
--
-- Reset: activo en bajo (aresetn). El core interno espera activo en alto;
--        se invierte aquí.
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;

entity SERIAL_CHANNEL_IP is
  generic (
    USE_DE  : boolean := true;   -- Expone y activa el pin DE
    USE_SLO : boolean := true    -- Expone y activa el pin SLO
  );
  port (
    clk     : in  std_logic;
    aresetn : in  std_logic;     -- Reset activo en bajo (compatible con Zynq peripheral_aresetn)

    -- Interfaz de configuración y estado (28b in / 14b out)
    -- Layout idéntico a PS_SERIAL_CONFIG / PS_out de CONFIGURABLE_SERIAL_TOP:
    --   ps_config[8:0]  = DataIn TX   [9]=TX_Send  [10]=ERROR_OK  [11]=Data_read
    --   ps_config[17:12]= baud_sel  [19:18]=stop_bits  [22:20]=parity
    --   ps_config[25:23]= data_bits  [26]=bit_order  [27]=SLO_mode
    --   ps_out[8:0]=RX data  [9]=EMPTY  [10]=FULL  [11]=PAR_ERR
    --   ps_out[12]=FRAME_ERR  [13]=TX_RDY
    ps_config    : in  std_logic_vector(27 downto 0);
    ps_out       : out std_logic_vector(13 downto 0);
    tx_rdy_empty : out std_logic_vector(1 downto 0);   -- [1]=TX_RDY  [0]=EMPTY

    -- Líneas físicas serie
    TD  : out std_logic;   -- Transmit Data
    RD  : in  std_logic;   -- Receive Data
    DE  : out std_logic;   -- Driver Enable  (sólo conectar si USE_DE=true)
    SLO : out std_logic    -- Slow Rate       (sólo conectar si USE_SLO=true)
  );
end SERIAL_CHANNEL_IP;

architecture RTL of SERIAL_CHANNEL_IP is

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

  signal de_int  : std_logic;
  signal slo_int : std_logic;
  signal rst_hi  : std_logic;   -- reset activo en alto para el core interno

begin

  rst_hi <= not aresetn;

  u_core : CONFIGURABLE_SERIAL_TOP
    port map (
      Reset            => rst_hi,
      Clk              => clk,
      PS_out           => ps_out,
      PS_SERIAL_CONFIG => ps_config,
      TX_RDY_EMPTY     => tx_rdy_empty,
      TD               => TD,
      RD               => RD,
      DE               => de_int,
      SLO              => slo_int
    );

  -- Gating: si el genérico está desactivado, el pin queda en '0' constante.
  -- El packager oculta el puerto en el BD (enablement_dependency).
  DE  <= de_int  when USE_DE  else '0';
  SLO <= slo_int when USE_SLO else '0';

end RTL;
