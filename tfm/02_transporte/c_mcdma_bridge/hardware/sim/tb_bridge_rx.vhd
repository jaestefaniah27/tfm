-- tb_bridge_rx.vhd
-- =========================================================================
-- Testbench auto-verificado del BRIDGE_RX_TOP.
--
-- Modela las FIFOs RX de los 14 transceivers directamente (sin UART real).
-- El DUT recibe bytes, los empaqueta como pares [header=0x0N , data] en la
-- FIFO comun, y los drena hacia DMA por AXI-Stream.
--
-- Tests:
--   T1: canal unico (ch2), 3 bytes, trigger por timeout
--   T2: multiples canales simultaneos (ch0,ch5,ch13), trigger por timeout
--   T3: 256 bytes en ch1, trigger automatico por prog_full + flush final
--   T4: back-to-back en ch7: dos eventos de timeout independientes
--
-- Verificacion automatica: cada par [header,data] del AXI-Stream se compara
-- con la cola de esperados por canal.
--
-- Resultado: "SIM_RESULT: PASS" / "SIM_RESULT: FAIL ..." (grepeable).
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_bridge_rx is
end entity;

architecture sim of tb_bridge_rx is

  constant N_CH       : integer := 14;
  constant CLK_PERIOD : time    := 10 ns;
  constant FIFO_DEPTH : integer := 256;  -- profundidad del modelo de FIFO por canal

  -- ── Push desde estimulo hacia los modelos de FIFO por canal ──────────────
  signal push_valid : std_logic := '0';
  signal push_ch    : integer   := 0;
  signal push_data  : std_logic_vector(7 downto 0) := (others => '0');

  -- ── Interfaz del DUT ─────────────────────────────────────────────────────
  signal aclk          : std_logic := '0';
  signal aresetn       : std_logic := '0';
  signal m_axis_tdata  : std_logic_vector(7 downto 0);
  signal m_axis_tvalid : std_logic;
  signal m_axis_tready : std_logic := '1';   -- DMA siempre acepta
  signal m_axis_tlast  : std_logic;
  signal timeout_in    : std_logic_vector(15 downto 0) := (others => '0');
  signal rx_fifo_empty : std_logic_vector(N_CH-1 downto 0);
  signal rx_fifo_dout  : std_logic_vector(N_CH*8-1 downto 0);
  signal rx_fifo_rd    : std_logic_vector(N_CH-1 downto 0);

  signal sim_end : boolean := false;

  -- ── Colas de esperados por canal (tipo protegido, acceso desde dos procesos)
  type t_exp is protected
    procedure push_exp(ch : natural; d : std_logic_vector(7 downto 0));
    impure function pop_exp (ch : natural) return std_logic_vector;
    impure function is_empty(ch : natural) return boolean;
    impure function total            return natural;
  end protected;

  type t_exp is protected body
    type byte_t  is array(0 to 511) of std_logic_vector(7 downto 0);
    type queue_t is array(0 to N_CH-1) of byte_t;
    type idx_t   is array(0 to N_CH-1) of integer;

    variable q    : queue_t := (others => (others => x"00"));
    variable head : idx_t   := (others => 0);
    variable tail : idx_t   := (others => 0);
    variable cnt  : idx_t   := (others => 0);

    procedure push_exp(ch : natural; d : std_logic_vector(7 downto 0)) is
    begin
      q(ch)(tail(ch)) := d;
      tail(ch) := (tail(ch) + 1) mod 512;
      cnt(ch)  := cnt(ch)  + 1;
    end procedure;

    impure function pop_exp(ch : natural) return std_logic_vector is
      variable v : std_logic_vector(7 downto 0);
    begin
      v        := q(ch)(head(ch));
      head(ch) := (head(ch) + 1) mod 512;
      cnt(ch)  := cnt(ch)  - 1;
      return v;
    end function;

    impure function is_empty(ch : natural) return boolean is
    begin return cnt(ch) = 0; end function;

    impure function total return natural is
      variable s : natural := 0;
    begin
      for i in 0 to N_CH-1 loop s := s + cnt(i); end loop;
      return s;
    end function;
  end protected body;

  shared variable exp_q : t_exp;

  -- ── Marcador de test (para mensajes del checker) ──────────────────────────
  shared variable current_test : integer := 0;

  -- ── Scoreboard ────────────────────────────────────────────────────────────
  type t_score is protected
    procedure check(ok : boolean; msg : string);
    impure function errors  return integer;
    impure function checked return integer;
  end protected;

  type t_score is protected body
    variable n_err : integer := 0;
    variable n_chk : integer := 0;
    procedure check(ok : boolean; msg : string) is
    begin
      n_chk := n_chk + 1;
      if not ok then
        n_err := n_err + 1;
        report "[T" & integer'image(current_test) & "] FAIL: " & msg severity warning;
      end if;
    end procedure;
    impure function errors  return integer is begin return n_err; end function;
    impure function checked return integer is begin return n_chk; end function;
  end protected body;

  shared variable score : t_score;

begin

  aclk <= not aclk after CLK_PERIOD / 2;

  -- ── DUT ──────────────────────────────────────────────────────────────────
  DUT : entity work.BRIDGE_RX_TOP
    generic map (N_CH => N_CH)
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      m_axis_tdata  => m_axis_tdata,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tready => m_axis_tready,
      m_axis_tlast  => m_axis_tlast,
      timeout_in    => timeout_in,
      rx_fifo_empty => rx_fifo_empty,
      rx_fifo_dout  => rx_fifo_dout,
      rx_fifo_rd    => rx_fifo_rd
    );

  -- ── Modelos FWFT de FIFO RX por canal ────────────────────────────────────
  gen_fifo : for ch in 0 to N_CH-1 generate
    type mem_t is array(0 to FIFO_DEPTH-1) of std_logic_vector(7 downto 0);
    signal mem    : mem_t    := (others => (others => '0'));
    signal wr_ptr : natural range 0 to FIFO_DEPTH-1 := 0;
    signal rd_ptr : natural range 0 to FIFO_DEPTH-1 := 0;
    signal cnt    : natural range 0 to FIFO_DEPTH   := 0;
  begin
    rx_fifo_empty(ch)                    <= '1' when cnt = 0 else '0';
    rx_fifo_dout((ch+1)*8-1 downto ch*8) <= mem(rd_ptr);

    process(aclk)
      variable do_push : boolean;
      variable do_pop  : boolean;
    begin
      if rising_edge(aclk) then
        do_push := (push_valid = '1') and (push_ch = ch);
        do_pop  := (rx_fifo_rd(ch) = '1') and (cnt > 0);
        if do_push then
          mem(wr_ptr) <= push_data;
          wr_ptr <= (wr_ptr + 1) mod FIFO_DEPTH;
        end if;
        if do_pop then
          rd_ptr <= (rd_ptr + 1) mod FIFO_DEPTH;
        end if;
        if    do_push and not do_pop then cnt <= cnt + 1;
        elsif do_pop  and not do_push then cnt <= cnt - 1;
        end if;
      end if;
    end process;
  end generate;

  -- ── Checker: verifica cada par [header, data] en m_axis ──────────────────
  checker : process
    variable hdr : std_logic_vector(7 downto 0);
    variable dat : std_logic_vector(7 downto 0);
    variable ch  : natural;
    variable exp : std_logic_vector(7 downto 0);
  begin
    wait until aresetn = '1';
    loop
      -- header byte
      wait until rising_edge(aclk) and m_axis_tvalid = '1' and m_axis_tready = '1';
      if sim_end then exit; end if;
      hdr := m_axis_tdata;
      ch  := to_integer(unsigned(hdr(3 downto 0)));
      score.check(hdr(7 downto 4) = "0000",
                  "nibble alto del header != 0: 0x" & to_hstring(hdr));
      score.check(ch < N_CH,
                  "canal fuera de rango en header: " & integer'image(ch));
      -- data byte
      wait until rising_edge(aclk) and m_axis_tvalid = '1' and m_axis_tready = '1';
      if sim_end then exit; end if;
      dat := m_axis_tdata;
      if not exp_q.is_empty(ch) then
        exp := exp_q.pop_exp(ch);
        score.check(dat = exp,
                    "CH" & integer'image(ch) &
                    " dato incorrecto: recibido 0x" & to_hstring(dat) &
                    " esperado 0x" & to_hstring(exp));
      else
        score.check(false,
                    "CH" & integer'image(ch) &
                    " byte inesperado: 0x" & to_hstring(dat));
      end if;
    end loop;
    wait;
  end process;

  -- ── Watchdog global ───────────────────────────────────────────────────────
  watchdog : process
  begin
    wait for 15 ms;
    if not sim_end then
      report "WATCHDOG: la simulacion no termino" severity warning;
      report "SIM_RESULT: FAIL (watchdog)" severity note;
      stop;
    end if;
    wait;
  end process;

  -- ── Estimulo principal ────────────────────────────────────────────────────
  stim : process
    -- Escribe un byte en el modelo de FIFO del canal indicado
    procedure fifo_push(ch : integer; d : std_logic_vector(7 downto 0)) is
    begin
      wait until rising_edge(aclk);
      push_ch    <= ch;
      push_data  <= d;
      push_valid <= '1';
      wait until rising_edge(aclk);
      push_valid <= '0';
    end procedure;

    -- Asercion breve de timeout para disparar el DRAIN
    procedure send_timeout(mask : std_logic_vector(15 downto 0)) is
    begin
      wait until rising_edge(aclk);
      timeout_in <= mask;
      wait until rising_edge(aclk);
      wait until rising_edge(aclk);
      timeout_in <= (others => '0');
    end procedure;

    -- Espera hasta que el checker haya consumido todos los esperados
    procedure wait_drain(max_cycles : integer) is
      variable t : integer := 0;
    begin
      while exp_q.total > 0 and t < max_cycles loop
        wait until rising_edge(aclk);
        t := t + 1;
      end loop;
      wait for 10 * CLK_PERIOD;  -- margen extra
      score.check(exp_q.total = 0,
                  "drain timeout: quedan " & integer'image(exp_q.total) &
                  " bytes esperados");
    end procedure;

  begin
    -- Reset
    aresetn <= '0';
    wait for 30 * CLK_PERIOD;
    aresetn <= '1';
    wait for 20 * CLK_PERIOD;
    report "-- Reset liberado --" severity note;

    -- ═══════════════════════════════════════════════════════════════════
    -- T1: Canal unico (ch2), 3 bytes, timeout trigger
    -- ═══════════════════════════════════════════════════════════════════
    current_test := 1;
    report "T1: canal unico ch2 (3 bytes, timeout)" severity note;
    exp_q.push_exp(2, x"AB");
    exp_q.push_exp(2, x"CD");
    exp_q.push_exp(2, x"EF");
    fifo_push(2, x"AB");
    fifo_push(2, x"CD");
    fifo_push(2, x"EF");
    wait for 200 * CLK_PERIOD;        -- FILL tiene tiempo de ver los datos
    send_timeout(x"0004");            -- bit 2 -> ch2
    wait_drain(5000);

    -- ═══════════════════════════════════════════════════════════════════
    -- T2: Varios canales simultaneos (ch0, ch5, ch13), timeout
    -- ═══════════════════════════════════════════════════════════════════
    current_test := 2;
    report "T2: multi-canal ch0/ch5/ch13 (1 byte c/u, timeout)" severity note;
    exp_q.push_exp(0,  x"11");
    exp_q.push_exp(5,  x"22");
    exp_q.push_exp(13, x"33");
    fifo_push(0,  x"11");
    fifo_push(5,  x"22");
    fifo_push(13, x"33");
    wait for 400 * CLK_PERIOD;        -- FILL explora los 14 canales
    send_timeout(x"2021");            -- bits 0,5,13
    wait_drain(5000);

    -- ═══════════════════════════════════════════════════════════════════
    -- T3: 256 bytes en ch1, disparo por prog_full + flush final
    -- ═══════════════════════════════════════════════════════════════════
    current_test := 3;
    report "T3: 256 bytes ch1, prog_full auto-trigger" severity note;
    for i in 0 to 255 loop
      exp_q.push_exp(1, std_logic_vector(to_unsigned(i, 8)));
      fifo_push(1, std_logic_vector(to_unsigned(i, 8)));
    end loop;
    -- Esperar que FILL procese y que prog_full (>=509 bytes en FIFO comun)
    -- dispare el DRAIN automaticamente. Con 14 canales y 1 activo el FILL
    -- tarda ~15 ciclos/byte x 256 = ~3840 ciclos. Dejamos margen.
    wait for 60000 * CLK_PERIOD;
    -- Flush final por si quedaron bytes tras el drain de prog_full
    send_timeout(x"0002");            -- bit 1 -> ch1
    wait_drain(20000);

    -- ═══════════════════════════════════════════════════════════════════
    -- T4: Back-to-back en ch7: dos timeouts separados, sin mezcla
    -- ═══════════════════════════════════════════════════════════════════
    current_test := 4;
    report "T4: back-to-back ch7 (2 eventos de timeout)" severity note;
    -- Primer evento
    exp_q.push_exp(7, x"AA");
    fifo_push(7, x"AA");
    wait for 200 * CLK_PERIOD;
    send_timeout(x"0080");            -- bit 7
    wait_drain(5000);
    -- Segundo evento
    exp_q.push_exp(7, x"BB");
    fifo_push(7, x"BB");
    wait for 200 * CLK_PERIOD;
    send_timeout(x"0080");            -- bit 7
    wait_drain(5000);

    -- ── Veredicto ────────────────────────────────────────────────────
    wait for 20 * CLK_PERIOD;
    report "------------------------------------------------------------" severity note;
    report "Checks totales  : " & integer'image(score.checked) severity note;
    report "Errores         : " & integer'image(score.errors)  severity note;
    report "Pendientes exp  : " & integer'image(exp_q.total)   severity note;
    report "------------------------------------------------------------" severity note;

    if score.errors = 0 and exp_q.total = 0 then
      report "SIM_RESULT: PASS" severity note;
    else
      report "SIM_RESULT: FAIL" severity note;
    end if;

    sim_end <= true;
    stop;
    wait;
  end process;

end architecture sim;
