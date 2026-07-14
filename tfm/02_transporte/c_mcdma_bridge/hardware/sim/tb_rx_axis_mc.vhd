-- tb_rx_axis_mc.vhd
-- =========================================================================
-- Testbench del RX_AXIS_MC.
--
-- m_tready='0' por defecto: el UUT no puede hacer handshake durante los
-- ciclos de preparacion (push + espera). Solo se activa en get_beat.
-- drain_rd se llama en cada flanco de reloj para mantener el modelo FIFO
-- sincronizado con rx_rd (combinatorial).
--
-- Tests:
--   T1  1 byte, 1 canal                (tlast=1)
--   T2  3 bytes, 1 canal               (tlast en el ultimo)
--   T3  timeout latched antes de datos
--   T4  timeout obsoleto sin datos     (no debe generar beats)
--   T5  round-robin canales 0,1,13 simultaneos
--   T6  back-to-back dos mensajes canal 3
--   T7  back-pressure tready lento
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_rx_axis_mc is
end entity;

architecture sim of tb_rx_axis_mc is

  constant N_CH       : integer := 14;
  constant CLK_PERIOD : time    := 10 ns;

  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal rx_dout  : std_logic_vector(N_CH*8-1 downto 0) := (others => '0');
  signal rx_empty : std_logic_vector(N_CH-1 downto 0)   := (others => '1');
  signal timeout  : std_logic_vector(N_CH-1 downto 0)   := (others => '0');
  signal rx_rd    : std_logic_vector(N_CH-1 downto 0);

  signal m_tdata  : std_logic_vector(7 downto 0);
  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '0';   -- '0' por defecto; '1' solo en get_beat
  signal m_tlast  : std_logic;
  signal m_tdest  : std_logic_vector(3 downto 0);

  signal fail_count : integer := 0;

  component RX_AXIS_MC is
    generic (N_CH : integer := 14);
    port (
      aclk          : in  std_logic;
      aresetn       : in  std_logic;
      rx_dout       : in  std_logic_vector(N_CH*8-1 downto 0);
      rx_empty      : in  std_logic_vector(N_CH-1 downto 0);
      timeout       : in  std_logic_vector(N_CH-1 downto 0);
      rx_rd         : out std_logic_vector(N_CH-1 downto 0);
      m_axis_tdata  : out std_logic_vector(7 downto 0);
      m_axis_tvalid : out std_logic;
      m_axis_tready : in  std_logic;
      m_axis_tlast  : out std_logic;
      m_axis_tdest  : out std_logic_vector(3 downto 0)
    );
  end component;

begin

  aclk <= not aclk after CLK_PERIOD / 2;

  uut : RX_AXIS_MC
    generic map (N_CH => N_CH)
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      rx_dout       => rx_dout,
      rx_empty      => rx_empty,
      timeout       => timeout,
      rx_rd         => rx_rd,
      m_axis_tdata  => m_tdata,
      m_axis_tvalid => m_tvalid,
      m_axis_tready => m_tready,
      m_axis_tlast  => m_tlast,
      m_axis_tdest  => m_tdest
    );

  stim : process
    type byte_q   is array(0 to 7) of std_logic_vector(7 downto 0);
    type q_arr    is array(0 to N_CH-1) of byte_q;
    type cnt_arr  is array(0 to N_CH-1) of integer range 0 to 8;
    type head_arr is array(0 to N_CH-1) of integer range 0 to 7;

    variable q     : q_arr    := (others => (others => (others => '0')));
    variable qcnt  : cnt_arr  := (others => 0);
    variable qhead : head_arr := (others => 0);
    variable fc    : integer  := 0;

    procedure push(ch : integer; data : std_logic_vector(7 downto 0)) is
      variable tail : integer;
    begin
      tail              := (qhead(ch) + qcnt(ch)) mod 8;
      q(ch)(tail)       := data;
      qcnt(ch)          := qcnt(ch) + 1;
      rx_dout(ch*8+7 downto ch*8) <= q(ch)(qhead(ch));
      rx_empty(ch) <= '0';
    end procedure;

    -- Avanza la FIFO modelo segun rx_rd. Llamar tras cada flanco de reloj.
    procedure drain_rd is
    begin
      for i in 0 to N_CH-1 loop
        if rx_rd(i) = '1' and qcnt(i) > 0 then
          qhead(i) := (qhead(i) + 1) mod 8;
          qcnt(i)  := qcnt(i) - 1;
          if qcnt(i) > 0 then
            rx_dout(i*8+7 downto i*8) <= q(i)(qhead(i));
            rx_empty(i) <= '0';
          else
            rx_dout(i*8+7 downto i*8) <= (others => '0');
            rx_empty(i) <= '1';
          end if;
        end if;
      end loop;
    end procedure;

    -- Espera n ciclos con m_tready='0', procesando drain_rd en cada uno.
    procedure wait_clk(n : integer) is
    begin
      for k in 0 to n-1 loop
        wait until rising_edge(aclk);
        drain_rd;
      end loop;
    end procedure;

    -- Activa tready, espera y verifica un beat. Desactiva tready al terminar.
    procedure get_beat(
        exp_data : std_logic_vector(7 downto 0);
        exp_ch   : integer;
        exp_last : std_logic;
        tag      : string) is
      variable cycles : integer := 0;
    begin
      m_tready <= '1';
      loop
        wait until rising_edge(aclk);
        drain_rd;
        cycles := cycles + 1;
        if cycles > 100 then
          report tag & " TIMEOUT: beat no llego en 100 ciclos" severity error;
          fc := fc + 1;
          m_tready <= '0';
          return;
        end if;
        exit when m_tvalid = '1' and m_tready = '1';
      end loop;
      m_tready <= '0';
      if m_tdata /= exp_data then
        report tag & " TDATA: got=" & integer'image(to_integer(unsigned(m_tdata)))
               & " exp=" & integer'image(to_integer(unsigned(exp_data))) severity error;
        fc := fc + 1;
      end if;
      if to_integer(unsigned(m_tdest)) /= exp_ch then
        report tag & " TDEST: got=" & integer'image(to_integer(unsigned(m_tdest)))
               & " exp=" & integer'image(exp_ch) severity error;
        fc := fc + 1;
      end if;
      if m_tlast /= exp_last then
        report tag & " TLAST: got=" & std_logic'image(m_tlast)
               & " exp=" & std_logic'image(exp_last) severity error;
        fc := fc + 1;
      end if;
    end procedure;

    variable seen0, seen1, seen13 : boolean;
    variable beats : integer;

  begin
    aresetn  <= '0';
    m_tready <= '0';
    wait_clk(5);
    aresetn <= '1';
    wait_clk(3);

    -- =========================================================================
    -- T1: 1 byte canal 0 -> tlast=1
    -- =========================================================================
    report "T1: 1 byte canal 0";
    push(0, x"AB");
    wait_clk(2);
    wait until rising_edge(aclk); timeout(0) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(0) <= '0'; drain_rd;
    wait_clk(1);
    get_beat(x"AB", 0, '1', "T1");
    wait_clk(2);

    -- =========================================================================
    -- T2: 3 bytes canal 5 -> tlast solo en el ultimo
    -- =========================================================================
    report "T2: 3 bytes canal 5";
    push(5, x"11");
    push(5, x"22");
    push(5, x"33");
    wait_clk(2);
    wait until rising_edge(aclk); timeout(5) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(5) <= '0'; drain_rd;
    wait_clk(1);
    get_beat(x"11", 5, '0', "T2-B0");
    get_beat(x"22", 5, '0', "T2-B1");
    get_beat(x"33", 5, '1', "T2-B2");
    wait_clk(2);

    -- =========================================================================
    -- T3: timeout latched -- pulso llega antes de los datos
    -- =========================================================================
    report "T3: timeout latched";
    wait until rising_edge(aclk); timeout(2) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(2) <= '0'; drain_rd;
    wait_clk(2);
    push(2, x"CC");
    wait_clk(2);
    get_beat(x"CC", 2, '1', "T3");
    wait_clk(2);

    -- =========================================================================
    -- T4: timeout obsoleto sin datos -- no debe generar ningun beat
    -- =========================================================================
    report "T4: timeout obsoleto";
    wait until rising_edge(aclk); timeout(7) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(7) <= '0'; drain_rd;
    m_tready <= '1';
    for k in 0 to 9 loop
      wait until rising_edge(aclk);
      drain_rd;
      if m_tvalid = '1' and to_integer(unsigned(m_tdest)) = 7 then
        report "T4 FAIL: beat inesperado canal 7" severity error;
        fc := fc + 1;
      end if;
    end loop;
    m_tready <= '0';
    report "T4: OK";

    -- =========================================================================
    -- T5: round-robin canales 0,1,13 simultaneos
    -- =========================================================================
    report "T5: round-robin canales 0,1,13";
    push(0,  x"A0");
    push(1,  x"B1");
    push(13, x"CD");
    wait_clk(2);
    wait until rising_edge(aclk);
    timeout(0) <= '1'; timeout(1) <= '1'; timeout(13) <= '1'; drain_rd;
    wait until rising_edge(aclk);
    timeout(0) <= '0'; timeout(1) <= '0'; timeout(13) <= '0'; drain_rd;
    wait_clk(1);
    seen0  := false;
    seen1  := false;
    seen13 := false;
    beats  := 0;
    m_tready <= '1';
    while beats < 3 loop
      wait until rising_edge(aclk);
      drain_rd;
      if m_tvalid = '1' and m_tready = '1' then
        if m_tlast /= '1' then
          report "T5 FAIL: tlast esperado" severity error; fc := fc + 1;
        end if;
        case to_integer(unsigned(m_tdest)) is
          when 0  => seen0  := true;
          when 1  => seen1  := true;
          when 13 => seen13 := true;
          when others =>
            report "T5 FAIL: tdest inesperado " &
                   integer'image(to_integer(unsigned(m_tdest))) severity error;
            fc := fc + 1;
        end case;
        beats := beats + 1;
      end if;
    end loop;
    m_tready <= '0';
    if not seen0  then report "T5 FAIL: canal 0 no salio"  severity error; fc:=fc+1; end if;
    if not seen1  then report "T5 FAIL: canal 1 no salio"  severity error; fc:=fc+1; end if;
    if not seen13 then report "T5 FAIL: canal 13 no salio" severity error; fc:=fc+1; end if;
    wait_clk(2);

    -- =========================================================================
    -- T6: back-to-back dos mensajes canal 3
    -- =========================================================================
    report "T6: back-to-back canal 3";
    push(3, x"D1");
    push(3, x"D2");
    wait_clk(2);
    wait until rising_edge(aclk); timeout(3) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(3) <= '0'; drain_rd;
    wait_clk(1);
    get_beat(x"D1", 3, '0', "T6-msg1-B0");
    get_beat(x"D2", 3, '1', "T6-msg1-B1");
    -- segundo mensaje
    push(3, x"E1");
    push(3, x"E2");
    push(3, x"E3");
    wait_clk(2);
    wait until rising_edge(aclk); timeout(3) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(3) <= '0'; drain_rd;
    wait_clk(1);
    get_beat(x"E1", 3, '0', "T6-msg2-B0");
    get_beat(x"E2", 3, '0', "T6-msg2-B1");
    get_beat(x"E3", 3, '1', "T6-msg2-B2");
    wait_clk(2);

    -- =========================================================================
    -- T7: back-pressure tready bajo durante 8 ciclos
    -- =========================================================================
    report "T7: back-pressure tready lento";
    push(4, x"F1");
    push(4, x"F2");
    wait_clk(2);
    wait until rising_edge(aclk); timeout(4) <= '1'; drain_rd;
    wait until rising_edge(aclk); timeout(4) <= '0'; drain_rd;
    wait_clk(8);   -- tready='0' durante 8 ciclos extra (back-pressure)
    get_beat(x"F1", 4, '0', "T7-B0");
    get_beat(x"F2", 4, '1', "T7-B1");
    wait_clk(2);

    -- =========================================================================
    -- Veredicto
    -- =========================================================================
    wait_clk(3);
    fail_count <= fc;
    wait until rising_edge(aclk);
    if fc = 0 then
      report "SIM_RESULT: PASS -- RX_AXIS_MC OK";
    else
      report "SIM_RESULT: FAIL -- " & integer'image(fc) & " errores" severity failure;
    end if;
    stop;
  end process;

end architecture;
