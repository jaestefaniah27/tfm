-- tb_uart_axis_loopback.vhd
-- =========================================================================
-- Testbench AUTO-ACOTADO del camino de datos PL del UART, aislado del DMA y
-- de RTEMS/PS. Replica el loopback interno del BD: UART_AXIS_TOP con TD→RD.
--
-- Verifica:  S_AXIS_TX → UART TX → serie TD → RD → UART RX → M_AXIS_RX
--
-- DISEÑO DEFENSIVO: nunca se cuelga. Tiene:
--   · Watchdog global  → fuerza fin pase lo que pase.
--   · axis_send acotado → si TREADY no llega, lo reporta y sigue (no cuelga).
--   · Sondas visibles   → cuenta flancos de TD, observa DE, cuenta RX.
--     Así localiza el fallo aunque no haya waveform:
--       - TD no conmuta            → TX no arranca
--       - TD conmuta, EOT atascado → TX no completa (TREADY no vuelve)
--       - TD ok pero RX=0          → bug en el RX / FIFO
--
-- Resultado: imprime "SIM_RESULT: PASS" o "SIM_RESULT: FAIL ..." (grepeable).
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_uart_axis_loopback is
end entity;

architecture sim of tb_uart_axis_loopback is

  constant CLK_PERIOD : time    := 10 ns;   -- 100 MHz
  constant BAUD_SEL   : integer := 44;       -- 1 Mbaud (sobremuestreo seguro)
  constant DELAY_CYC  : integer := 2000;     -- hueco grande entre tramas (aisla bug TX); real=10000

  -- Timeouts (en ciclos de reloj)
  constant TREADY_TIMEOUT : integer := 30000;  -- ~300us esperando TREADY/byte
  constant RX_TIMEOUT     : integer := 60000;  -- ~600us esperando todos los RX

  type byte_array is array(natural range <>) of std_logic_vector(7 downto 0);
  constant TEST_DATA : byte_array := (x"55", x"AA", x"00", x"FF", x"3C", x"81");
  constant N_BYTES : integer := TEST_DATA'length;

  -- ── Señales ───────────────────────────────────────────────────────────
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal sim_end : boolean   := false;

  signal s_axi_awaddr  : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_axi_awvalid : std_logic := '0';
  signal s_axi_awready : std_logic;
  signal s_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal s_axi_wstrb   : std_logic_vector(3 downto 0)  := "1111";
  signal s_axi_wvalid  : std_logic := '0';
  signal s_axi_wready  : std_logic;
  signal s_axi_bresp   : std_logic_vector(1 downto 0);
  signal s_axi_bvalid  : std_logic;
  signal s_axi_bready  : std_logic := '0';
  signal s_axi_araddr  : std_logic_vector(3 downto 0)  := (others => '0');
  signal s_axi_arvalid : std_logic := '0';
  signal s_axi_arready : std_logic;
  signal s_axi_rdata   : std_logic_vector(31 downto 0);
  signal s_axi_rresp   : std_logic_vector(1 downto 0);
  signal s_axi_rvalid  : std_logic;
  signal s_axi_rready  : std_logic := '0';

  signal s_axis_tx_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tx_tvalid : std_logic := '0';
  signal s_axis_tx_tready : std_logic;

  signal m_axis_rx_tdata  : std_logic_vector(7 downto 0);
  signal m_axis_rx_tvalid : std_logic;
  signal m_axis_rx_tready : std_logic := '1';
  signal m_axis_rx_tlast  : std_logic;
  signal m_axis_rx_tdest  : std_logic_vector(3 downto 0);

  signal td, rd, de, slo : std_logic;

  -- Sondas de diagnóstico
  signal rx_count   : integer := 0;
  signal rx_errors  : integer := 0;
  signal td_edges   : integer := 0;   -- nº de transiciones de TD
  signal de_seen    : boolean := false;
  signal tx_stuck   : boolean := false;
  signal stuck_byte : integer := -1;

  -- Sondas del handshake AXI-Lite (latcheadas)
  signal saw_awready : boolean := false;
  signal saw_wready  : boolean := false;
  signal saw_bvalid  : boolean := false;
  signal axi_timeout : boolean := false;

  -- ── Sondas INTERNAS del RX vía puerto de debug dbg_rx ──────────────────
  -- dbg_rx = {EMPTY_sig(3), Fifo_write(2), Valid_out(1), LineRD_in(0)}
  signal dbg_rx : std_logic_vector(3 downto 0);
  alias rx_linerd  is dbg_rx(0);
  alias rx_valid   is dbg_rx(1);
  alias rx_fifo_wr is dbg_rx(2);
  alias rx_empty_i is dbg_rx(3);

  signal n_valid_pulses : integer := 0;   -- bits muestreados por la FSM RX
  signal n_fifo_writes  : integer := 0;   -- escrituras al FIFO (bytes completos)
  signal linerd_edges   : integer := 0;   -- transiciones de la línea RX interna

begin

  clk <= not clk after CLK_PERIOD / 2;
  rd  <= td;   -- loopback interno TD → RD

  DUT : entity work.UART_AXIS_TOP
    generic map ( CH_ID => 0, DELAY_CYCLES => DELAY_CYC )
    port map (
      aclk    => clk,
      aresetn => aresetn,
      s_axi_awaddr  => s_axi_awaddr,  s_axi_awvalid => s_axi_awvalid, s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,   s_axi_wstrb   => s_axi_wstrb,   s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,  s_axi_bresp   => s_axi_bresp,   s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,  s_axi_araddr  => s_axi_araddr,  s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready, s_axi_rdata   => s_axi_rdata,   s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,  s_axi_rready  => s_axi_rready,
      s_axis_tx_tdata  => s_axis_tx_tdata,  s_axis_tx_tvalid => s_axis_tx_tvalid, s_axis_tx_tready => s_axis_tx_tready,
      m_axis_rx_tdata  => m_axis_rx_tdata,  m_axis_rx_tvalid => m_axis_rx_tvalid, m_axis_rx_tready => m_axis_rx_tready,
      m_axis_rx_tlast  => m_axis_rx_tlast,  m_axis_rx_tdest  => m_axis_rx_tdest,
      TD  => td, RD => rd, DE => de, SLO => slo,
      dbg_rx => dbg_rx );

  -- ── Watchdog global: pase lo que pase, la sim termina ──────────────────
  watchdog : process
  begin
    wait for 2 ms;
    if not sim_end then
      report "WATCHDOG global: la simulacion no termino sola (posible cuelgue)" severity warning;
      report "SIM_RESULT: FAIL (watchdog)" severity note;
      stop;
    end if;
    wait;
  end process;

  -- ── Sondas: flancos de TD, DE y handshake AXI ─────────────────────────
  probe : process(clk)
    variable td_prev : std_logic := '1';
  begin
    if rising_edge(clk) then
      if td /= td_prev then
        td_edges <= td_edges + 1;
        td_prev  := td;
      end if;
      if de = '1'            then de_seen     <= true; end if;
      if s_axi_awready = '1' then saw_awready <= true; end if;
      if s_axi_wready  = '1' then saw_wready  <= true; end if;
      if s_axi_bvalid  = '1' then saw_bvalid  <= true; end if;
    end if;
  end process;

  -- ── Sondas internas del RX (cuenta pulsos) ─────────────────────────────
  rx_probe : process(clk)
    variable v_prev, w_prev, l_prev : std_logic := '0';
  begin
    if rising_edge(clk) then
      if rx_valid = '1' and v_prev = '0' then n_valid_pulses <= n_valid_pulses + 1; end if;
      if rx_fifo_wr = '1' and w_prev = '0' then n_fifo_writes <= n_fifo_writes + 1; end if;
      if rx_linerd /= l_prev then linerd_edges <= linerd_edges + 1; end if;
      v_prev := rx_valid;
      w_prev := rx_fifo_wr;
      l_prev := rx_linerd;
    end if;
  end process;

  -- ── Captura y verificación de RX — MODELA DMA S2MM LENGTH=1 (ESTRÉS) ──────
  -- Modela fielmente la placa: el DMA lee UN byte (1 beat), completa, baja
  -- TREADY, y la ISR tarda 'rearm_gap' ciclos en re-armar. Con rearm_gap mayor
  -- que el periodo de byte, el FIFO ACUMULA bytes → si el camino de lectura no
  -- es estricto (1 byte por beat) se perderían bytes (era el bug "1 de cada 4").
  -- Con el register slice, cada byte se entrega exactamente una vez, en orden.
  rx_proc : process(clk)
    variable expected : std_logic_vector(7 downto 0);
    variable gap      : integer := 0;
    constant rearm_gap : integer := 2000;   -- ISR lenta a propósito → FIFO acumula
  begin
    if rising_edge(clk) then
      if gap > 0 then
        m_axis_rx_tready <= '0';
        gap := gap - 1;
        if gap = 0 then
          m_axis_rx_tready <= '1';
        end if;
      elsif m_axis_rx_tvalid = '1' and m_axis_rx_tready = '1' then
        if rx_count < N_BYTES then
          expected := TEST_DATA(rx_count);
          if m_axis_rx_tdata = expected then
            report "RX byte " & integer'image(rx_count) &
                   " = 0x" & to_hstring(m_axis_rx_tdata) & "  OK" severity note;
          else
            report "RX byte " & integer'image(rx_count) &
                   " = 0x" & to_hstring(m_axis_rx_tdata) &
                   "  ESPERADO 0x" & to_hstring(expected) & "  MISMATCH" severity warning;
            rx_errors <= rx_errors + 1;
          end if;
          if m_axis_rx_tlast /= '1' then
            report "RX byte " & integer'image(rx_count) & ": TLAST no asertado" severity warning;
            rx_errors <= rx_errors + 1;
          end if;
        end if;
        rx_count <= rx_count + 1;
        m_axis_rx_tready <= '0';   -- DMA LENGTH=1: 1 byte y a re-armar
        gap := rearm_gap;
      end if;
    end if;
  end process;

  -- ── Estímulo principal ─────────────────────────────────────────────────
  stim_proc : process

    -- Escritura AXI-Lite ACOTADA: no cuelga. Si no completa, marca axi_timeout.
    procedure axi_write(addr : in std_logic_vector(3 downto 0);
                        data : in std_logic_vector(31 downto 0)) is
      variable waited : integer := 0;
    begin
      wait until rising_edge(clk);
      s_axi_awaddr <= addr; s_axi_awvalid <= '1';
      s_axi_wdata  <= data; s_axi_wvalid  <= '1'; s_axi_wstrb <= "1111";
      s_axi_bready <= '1';
      -- esperar AW & W ready
      waited := 0;
      loop
        wait until rising_edge(clk);
        exit when s_axi_awready = '1' and s_axi_wready = '1';
        waited := waited + 1;
        if waited >= 5000 then
          axi_timeout <= true;
          s_axi_awvalid <= '0'; s_axi_wvalid <= '0'; s_axi_bready <= '0';
          return;
        end if;
      end loop;
      s_axi_awvalid <= '0'; s_axi_wvalid <= '0';
      -- esperar respuesta B
      waited := 0;
      loop
        wait until rising_edge(clk);
        exit when s_axi_bvalid = '1';
        waited := waited + 1;
        if waited >= 5000 then
          axi_timeout <= true;
          s_axi_bready <= '0';
          return;
        end if;
      end loop;
      s_axi_bready <= '0';
    end procedure;

    -- Envía un byte; ACOTADO: si TREADY no llega en TREADY_TIMEOUT ciclos,
    -- marca tx_stuck y retorna (no cuelga la simulación).
    procedure axis_send(b : in std_logic_vector(7 downto 0); idx : in integer) is
      variable waited : integer := 0;
    begin
      wait until rising_edge(clk);
      s_axis_tx_tdata  <= b;
      s_axis_tx_tvalid <= '1';
      loop
        wait until rising_edge(clk);
        exit when s_axis_tx_tready = '1';
        waited := waited + 1;
        if waited >= TREADY_TIMEOUT then
          tx_stuck   <= true;
          stuck_byte <= idx;
          s_axis_tx_tvalid <= '0';
          return;
        end if;
      end loop;
      s_axis_tx_tvalid <= '0';
    end procedure;

    variable cfg : std_logic_vector(31 downto 0);
    variable rx_wait : integer := 0;
    variable ti : integer := 0;
  begin
    -- Reset
    aresetn <= '0';
    wait for 20 * CLK_PERIOD;
    aresetn <= '1';
    wait for 20 * CLK_PERIOD;
    report "Reset liberado" severity note;

    -- Config 8N1, LSB-first, baud = BAUD_SEL
    cfg := (others => '0');
    cfg(17 downto 12) := std_logic_vector(to_unsigned(BAUD_SEL, 6));
    cfg(19 downto 18) := "00";    -- 1 stop
    cfg(22 downto 20) := "100";   -- parity none
    cfg(25 downto 23) := "011";   -- 8 data bits
    cfg(26) := '0'; cfg(27) := '0';
    axi_write(x"0", cfg);
    report "AXI write -> awready_visto=" & boolean'image(saw_awready) &
           " wready_visto=" & boolean'image(saw_wready) &
           " bvalid_visto=" & boolean'image(saw_bvalid) &
           " timeout=" & boolean'image(axi_timeout) severity note;
    if axi_timeout then
      report "DIAGNOSTICO: el handshake AXI-Lite no completo." severity note;
      report "SIM_RESULT: FAIL (AXI write timeout)" severity note;
      sim_end <= true;
      stop;
    end if;
    report "Config escrita: 0x" & to_hstring(cfg) severity note;
    wait for 50 * CLK_PERIOD;

    -- Enviar bytes MODELANDO EL DMA MM2S: stream continuo, tvalid alto, avanza
    -- en cada beat (tvalid & tready), SIN huecos. Así expone si el wrapper TX
    -- acepta bytes más rápido de lo que el core los transmite (sobrescritura
    -- de tx_data_ff → se pierden bytes). El DMA real funciona exactamente así.
    ti := 0;
    wait until rising_edge(clk);
    s_axis_tx_tdata  <= TEST_DATA(0);
    s_axis_tx_tvalid <= '1';
    while ti < N_BYTES loop
      wait until rising_edge(clk);
      if s_axis_tx_tready = '1' then     -- beat aceptado
        report "TX beat " & integer'image(ti) &
               " = 0x" & to_hstring(TEST_DATA(ti)) severity note;
        ti := ti + 1;
        if ti < N_BYTES then
          s_axis_tx_tdata <= TEST_DATA(ti);
        end if;
      end if;
    end loop;
    s_axis_tx_tvalid <= '0';

    -- Esperar a que lleguen los RX (acotado)
    rx_wait := 0;
    while rx_count < N_BYTES and rx_wait < RX_TIMEOUT loop
      wait until rising_edge(clk);
      rx_wait := rx_wait + 1;
    end loop;

    -- ── Veredicto con diagnóstico ───────────────────────────────────────
    report "------------------------------------------------------------";
    report "TD flancos observados : " & integer'image(td_edges);
    report "DE asertado alguna vez: " & boolean'image(de_seen);
    report "RX LineRD_in flancos  : " & integer'image(linerd_edges);
    report "RX Valid_out pulsos   : " & integer'image(n_valid_pulses) & " (bits muestreados)";
    report "RX Fifo_write pulsos  : " & integer'image(n_fifo_writes) & " (bytes a FIFO)";
    report "RX FIFO empty (final) : " & std_logic'image(rx_empty_i);
    report "Bytes enviados        : " & integer'image(N_BYTES);
    report "Bytes recibidos       : " & integer'image(rx_count);
    report "Errores de dato       : " & integer'image(rx_errors);

    if tx_stuck then
      report "DIAGNOSTICO: TX se atasco en el byte " & integer'image(stuck_byte) &
             " (TREADY/EOT nunca volvio a '1')." severity note;
      if td_edges = 0 then
        report "  -> TD no conmuto: el TX no llega a transmitir." severity note;
      else
        report "  -> TD si conmuto: el TX transmite pero no vuelve a Idle." severity note;
      end if;
      report "SIM_RESULT: FAIL (TX stuck)" severity note;
    elsif rx_count = 0 then
      report "DIAGNOSTICO: TX completo pero el RX no recibio NADA." severity note;
      if td_edges = 0 then
        report "  -> TD nunca conmuto." severity note;
      else
        report "  -> TD conmuto (" & integer'image(td_edges) &
               " flancos) pero el RX/FIFO no entrega bytes." severity note;
      end if;
      report "SIM_RESULT: FAIL (RX vacio)" severity note;
    elsif rx_count < N_BYTES then
      report "SIM_RESULT: FAIL (RX incompleto)" severity note;
    elsif rx_errors > 0 then
      report "SIM_RESULT: FAIL (datos erroneos)" severity note;
    else
      report "SIM_RESULT: PASS" severity note;
    end if;
    report "------------------------------------------------------------";

    sim_end <= true;
    stop;
    wait;
  end process;

end architecture;
