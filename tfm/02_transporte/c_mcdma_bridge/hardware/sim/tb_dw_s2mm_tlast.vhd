----------------------------------------------------------------------------------
-- tb_dw_s2mm_tlast
--
-- El unico tramo del camino de RX que nunca se habia simulado:
--     m_axis (8 bits) -> system_mcdma_dw_s2mm_0 (8->32) -> S_AXIS_S2MM
--
-- Se le meten los paquetes EXACTOS que emite el puente segun la simulacion S6
-- (257, 257, 257, 253 bytes) y se cuenta cuantos TLAST salen por el lado de 32
-- bits y con cuantos bytes cada uno (usando TKEEP para los beats parciales).
--
-- Hipotesis a refutar: un paquete cuya longitud no es multiplo de 4 deja un beat
-- parcial, y el convertidor se traga la frontera del paquete. 257 mod 4 = 1.
--
-- El generico PKT_LEN permite repetir el experimento con 256 (multiplo de 4) sin
-- tocar nada mas: si con 257 falla y con 256 no, la causa esta localizada.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_dw_s2mm_tlast is
  generic (
    PKT_LEN : integer := 257;   -- longitud de cada paquete de entrada
    N_PKT   : integer := 4
  );
end tb_dw_s2mm_tlast;

architecture sim of tb_dw_s2mm_tlast is

  constant CLK_P : time := 10 ns;

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal s_tvalid : std_logic := '0';
  signal s_tready : std_logic;
  signal s_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal s_tlast  : std_logic := '0';
  signal s_tdest  : std_logic_vector(3 downto 0) := "0001";

  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '1';
  signal m_tdata  : std_logic_vector(31 downto 0);
  signal m_tkeep  : std_logic_vector(3 downto 0);
  signal m_tlast  : std_logic;
  signal m_tdest  : std_logic_vector(3 downto 0);

  signal bytes_in   : integer := 0;
  signal pkts_in    : integer := 0;
  signal bytes_out  : integer := 0;   -- contados por TKEEP
  signal pkts_out   : integer := 0;
  signal bad_dest   : integer := 0;
  signal done       : boolean := false;

  component system_mcdma_dw_s2mm_0
    port (
      aclk : in STD_LOGIC;
      aresetn : in STD_LOGIC;
      s_axis_tvalid : in STD_LOGIC;
      s_axis_tready : out STD_LOGIC;
      s_axis_tdata : in STD_LOGIC_VECTOR (7 downto 0);
      s_axis_tlast : in STD_LOGIC;
      s_axis_tdest : in STD_LOGIC_VECTOR (3 downto 0);
      m_axis_tvalid : out STD_LOGIC;
      m_axis_tready : in STD_LOGIC;
      m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
      m_axis_tkeep : out STD_LOGIC_VECTOR (3 downto 0);
      m_axis_tlast : out STD_LOGIC;
      m_axis_tdest : out STD_LOGIC_VECTOR (3 downto 0)
    );
  end component;

begin

  clk <= not clk after CLK_P / 2;

  dut : system_mcdma_dw_s2mm_0
    port map (
      aclk => clk, aresetn => aresetn,
      s_axis_tvalid => s_tvalid, s_axis_tready => s_tready,
      s_axis_tdata => s_tdata, s_axis_tlast => s_tlast, s_axis_tdest => s_tdest,
      m_axis_tvalid => m_tvalid, m_axis_tready => m_tready,
      m_axis_tdata => m_tdata, m_axis_tkeep => m_tkeep,
      m_axis_tlast => m_tlast, m_axis_tdest => m_tdest);

  -- ── Emisor: N_PKT paquetes de PKT_LEN bytes, con TLAST en el ultimo byte ──
  drv : process
  begin
    aresetn  <= '0';
    wait for 20 * CLK_P;
    wait until rising_edge(clk);
    aresetn <= '1';
    wait for 20 * CLK_P;

    for p in 0 to N_PKT - 1 loop
      for i in 0 to PKT_LEN - 1 loop
        -- Presentar el byte. Las asignaciones surten efecto tras el delta, asi
        -- que el DUT las muestrea en el PROXIMO flanco. Una transferencia por
        -- iteracion: salir en cuanto se ve tready alto en un flanco.
        s_tvalid <= '1';
        s_tdata  <= std_logic_vector(to_unsigned(i mod 256, 8));
        if i = PKT_LEN - 1 then s_tlast <= '1'; else s_tlast <= '0'; end if;
        loop
          wait until rising_edge(clk);
          exit when s_tready = '1';
        end loop;
        bytes_in <= bytes_in + 1;
      end loop;
      pkts_in <= pkts_in + 1;
      -- Bajar tvalid SIN esperar otro flanco: si se espera, el DUT acepta un
      -- byte extra con tlast todavia alto y aparece un paquete espurio de 1 B.
      s_tvalid <= '0';
      s_tlast  <= '0';
      -- hueco entre paquetes, como el DRAIN al volver a Idle
      wait for 50 * CLK_P;
    end loop;

    wait until rising_edge(clk);
    s_tvalid <= '0';
    wait for 2000 * CLK_P;
    done <= true;

    report "=========== RESULTADO (PKT_LEN=" & integer'image(PKT_LEN) &
           ", " & integer'image(N_PKT) & " paquetes) ===========" severity note;
    report "bytes entrados  : " & integer'image(bytes_in)  severity note;
    report "paquetes entrados: " & integer'image(pkts_in)  severity note;
    report "bytes salidos   : " & integer'image(bytes_out) severity note;
    report "paquetes salidos: " & integer'image(pkts_out)  severity note;
    report "tdest malo      : " & integer'image(bad_dest)  severity note;

    if pkts_out /= pkts_in then
      report "FALLO: entran " & integer'image(pkts_in) & " paquetes y salen " &
             integer'image(pkts_out) & " -> el dw_s2mm se traga TLAST"
             severity error;
    elsif bytes_out /= bytes_in then
      report "FALLO: entran " & integer'image(bytes_in) & " bytes y salen " &
             integer'image(bytes_out) severity error;
    else
      report "OK: el dw_s2mm respeta todos los TLAST y todos los bytes"
             severity note;
    end if;
    std.env.stop;
  end process;

  -- ── Monitor del lado de 32 bits: TKEEP dice cuantos bytes validos hay ────
  mon : process(clk)
    variable n : integer;
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        n := 0;
        for b in 0 to 3 loop
          if m_tkeep(b) = '1' then n := n + 1; end if;
        end loop;
        bytes_out <= bytes_out + n;
        if to_integer(unsigned(m_tdest)) /= 1 then
          bad_dest <= bad_dest + 1;
        end if;
        if m_tlast = '1' then
          pkts_out <= pkts_out + 1;
          report "paquete salido #" & integer'image(pkts_out + 1) &
                 ": acumulado " & integer'image(bytes_out + n) &
                 " bytes, tkeep=" & integer'image(n) & " en el ultimo beat"
                 severity note;
        end if;
      end if;
    end if;
  end process;

end sim;
