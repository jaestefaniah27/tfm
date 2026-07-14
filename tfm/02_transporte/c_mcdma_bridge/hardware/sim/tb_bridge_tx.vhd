-- tb_bridge_tx.vhd
-- =========================================================================
-- Testbench AUTO-ACOTADO del BRIDGE_TX_TOP: el puente que enruta el stream
-- de la DMA MM2S (AXI-Stream) hacia 14 transceptores UART.
--
-- Modela:
--   · La DMA MM2S como maestro AXI-Stream que envía tramas
--       [ {ID[3:0], LEN[11:8]} , {LEN[7:0]} , payload(0..LEN-1) ]
--     una detrás de otra, con handshake tvalid/tready real.
--   · Los 14 cores UART (CONFIGURABLE_SERIAL_TOP) configurados a la
--     velocidad MÁXIMA (baud_sel=53 -> 4 Mbaud, 25 ciclos/bit @100MHz) y con
--     DELAY_CYCLES pequeño, para que la simulación sea lo más corta posible.
--
-- Verifica que el puente:
--   1. Acepta el stream AXI (tready correcto, sin colgarse).
--   2. Enruta cada byte de payload al canal indicado por el ID.
--   3. Lanza los envíos: cada core transmite por su línea serie TD.
--   4. Los bytes recuperados (decodificando TD, 8N1 LSB-first) coinciden EN
--      ORDEN con lo enviado a cada canal.
--
-- Tests variados: distintos IDs (0,1,5,13 incluido el canal máximo), distintas
-- longitudes (1..4), patrones de datos variados (0x00,0xFF,0x55,0xAA,...), y
-- dos tramas al MISMO canal (0) para probar back-to-back.
--
-- Resultado: imprime "SIM_RESULT: PASS" o "SIM_RESULT: FAIL ..." (grepeable).
-- =========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_bridge_tx is
end entity;

architecture sim of tb_bridge_tx is

  constant N_CH       : integer := 14;
  constant CLK_PERIOD : time    := 10 ns;             -- 100 MHz
  constant BAUD_SEL   : integer := 53;                -- 4 Mbaud (máxima) -> 25 ciclos/bit
  constant DELAY_CYC  : integer := 4;                 -- settling de DE mínimo (acelera sim)
  constant BIT_TIME   : time    := 25 * CLK_PERIOD;   -- periodo de bit ~ 250 ns

  -- ── Estímulo: stream de la DMA (varias tramas concatenadas) ─────────────
  type byte_arr is array(natural range <>) of std_logic_vector(7 downto 0);

  -- Byte0 = ID(7:4) & LEN(11:8) ; Byte1 = LEN(7:0) ; luego payload.
  constant STREAM : byte_arr := (
    x"00", x"03", x"55", x"AA", x"10",              -- CH0  len=3
    x"10", x"01", x"C3",                            -- CH1  len=1
    x"50", x"02", x"00", x"FF",                     -- CH5  len=2
    x"D0", x"04", x"DE", x"AD", x"BE", x"EF",       -- CH13 len=4 (canal maximo)
    x"00", x"02", x"77", x"88"                      -- CH0  len=2 (back-to-back mismo canal)
  );
  -- TLAST por trama (el router usa la longitud interna, pero lo marcamos por realismo)
  constant LAST : std_logic_vector(0 to STREAM'length-1) :=
    "0000100100010000010001";

  -- ── Resultado esperado por canal (en orden de transmisión) ──────────────
  type int_vec is array(0 to N_CH-1) of integer;
  constant EXP_LEN : int_vec := (0 => 5, 1 => 1, 5 => 2, 13 => 4, others => 0);
  constant MAXB    : integer := 5;
  type exp_mem_t is array(0 to N_CH-1, 0 to MAXB-1) of std_logic_vector(7 downto 0);
  constant EXP : exp_mem_t := (
    0  => (x"55", x"AA", x"10", x"77", x"88"),
    1  => (x"C3", x"00", x"00", x"00", x"00"),
    5  => (x"00", x"FF", x"00", x"00", x"00"),
    13 => (x"DE", x"AD", x"BE", x"EF", x"00"),
    others => (others => x"00")
  );
  constant TOTAL_EXPECTED : integer := 5 + 1 + 2 + 4;   -- 12 bytes

  -- Tras transmitir, deben quedar sticky los bits de los canales con tráfico.
  constant EXP_DONE : std_logic_vector(N_CH-1 downto 0) :=
    (0 | 1 | 5 | 13 => '1', others => '0');

  -- ── Scoreboard (tipo protegido: varias decodificadoras lo actualizan) ───
  type t_score is protected
    procedure record_result(ok : boolean);
    impure function errors  return integer;
    impure function checked return integer;
  end protected;

  type t_score is protected body
    variable n_err : integer := 0;
    variable n_chk : integer := 0;
    procedure record_result(ok : boolean) is
    begin
      n_chk := n_chk + 1;
      if not ok then n_err := n_err + 1; end if;
    end procedure;
    impure function errors  return integer is begin return n_err; end function;
    impure function checked return integer is begin return n_chk; end function;
  end protected body;

  shared variable score : t_score;

  -- ── Señales ─────────────────────────────────────────────────────────────
  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal sim_end : boolean   := false;

  signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal s_axis_tvalid : std_logic := '0';
  signal s_axis_tready : std_logic;
  signal s_axis_tlast  : std_logic := '0';

  signal tx_din   : std_logic_vector(N_CH*9-1 downto 0);
  signal tx_send  : std_logic_vector(N_CH-1 downto 0);
  signal send_ok_v: std_logic_vector(N_CH-1 downto 0);
  signal tx_rdy   : std_logic_vector(N_CH-1 downto 0);
  signal eot      : std_logic_vector(N_CH-1 downto 0);
  signal eoaf     : std_logic;

  -- AXI-Lite (la PS lee TX_DONE y limpia con TX_DONE_CLEAR)
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

  signal td_lines : std_logic_vector(N_CH-1 downto 0);
  signal de_lines : std_logic_vector(N_CH-1 downto 0);

  -- Sondas
  signal de_seen  : boolean := false;
  signal td_edges : integer := 0;

begin

  clk <= not clk after CLK_PERIOD / 2;

  -- ── DUT: el puente de TX ────────────────────────────────────────────────
  DUT : entity work.BRIDGE_TX_TOP
    generic map ( N_CH => N_CH )
    port map (
      aclk          => clk,
      aresetn       => aresetn,
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tlast  => s_axis_tlast,
      TX_din        => tx_din,
      TX_Send       => tx_send,
      Send_ok       => send_ok_v,
      TX_RDY        => tx_rdy,
      EOT           => eot,
      s_axi_awaddr  => s_axi_awaddr,  s_axi_awvalid => s_axi_awvalid, s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,   s_axi_wstrb   => s_axi_wstrb,   s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,  s_axi_bresp   => s_axi_bresp,   s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,  s_axi_araddr  => s_axi_araddr,  s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready, s_axi_rdata   => s_axi_rdata,   s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,  s_axi_rready  => s_axi_rready,
      EOAF          => eoaf
    );

  -- ── 14 cores UART, configurados a la velocidad máxima ───────────────────
  gen_cores : for i in 0 to N_CH-1 generate
    signal cfg : std_logic_vector(27 downto 0);
    signal rdy_empty : std_logic_vector(1 downto 0);
  begin
    -- PS_SERIAL_CONFIG:
    --  (8:0)=Data_in  (9)=TX_Send  (10)=ERROR_OK  (11)=Data_read
    --  (17:12)=baud   (19:18)=stop (22:20)=parity (25:23)=data_bits
    --  (26)=bit_order (27)=SLO
    cfg <= '0'                                            -- 27 SLO
         & '0'                                            -- 26 bit_order (LSB-first)
         & "011"                                          -- 25:23 data_bits = 8
         & "100"                                          -- 22:20 parity = none
         & "00"                                           -- 19:18 stop = 1
         & std_logic_vector(to_unsigned(BAUD_SEL, 6))     -- 17:12 baud_sel
         & '0'                                            -- 11 Data_read
         & '1'                                            -- 10 ERROR_OK
         & tx_send(i)                                     -- 9  TX_Send
         & tx_din(i*9+8 downto i*9);                      -- 8:0 Data_in

    u_core : entity work.CONFIGURABLE_SERIAL_TOP
      generic map ( DELAY_CYCLES => DELAY_CYC )
      port map (
        Reset            => aresetn,             -- activo en bajo
        Clk              => clk,
        PS_out           => open,
        PS_SERIAL_CONFIG => cfg,
        TX_RDY_EMPTY     => rdy_empty,
        Send_ok          => send_ok_v(i),
        TD               => td_lines(i),
        RD               => '1',                 -- RX en reposo (no se usa)
        DE               => de_lines(i),
        SLO              => open,
        dbg_rx           => open
      );

    -- TX_RDY del core (= transmisor en reposo) hacia el puente.
    tx_rdy(i) <= rdy_empty(1);
    eot(i)    <= rdy_empty(1);
  end generate;

  -- ── Decodificadores serie por canal (8N1 LSB-first) ─────────────────────
  gen_dec : for i in 0 to N_CH-1 generate
    dec : process
      variable b : std_logic_vector(7 downto 0);
      variable k : integer := 0;
      variable ok : boolean;
    begin
      wait until aresetn = '1';
      if EXP_LEN(i) = 0 then
        wait;   -- canal sin tráfico esperado
      end if;
      while k < EXP_LEN(i) loop
        -- esperar el flanco de bajada del start bit (TD en reposo = '1')
        wait until td_lines(i) = '0';
        wait for BIT_TIME * 3 / 2;          -- centro del bit de datos 0
        for j in 0 to 7 loop
          b(j) := td_lines(i);              -- LSB-first
          wait for BIT_TIME;
        end loop;
        ok := (b = EXP(i, k));
        score.record_result(ok);
        if ok then
          report "CH" & integer'image(i) & " rx[" & integer'image(k) &
                 "] = 0x" & to_hstring(b) & "  OK" severity note;
        else
          report "CH" & integer'image(i) & " rx[" & integer'image(k) &
                 "] = 0x" & to_hstring(b) & "  ESPERADO 0x" &
                 to_hstring(EXP(i, k)) & "  MISMATCH" severity warning;
        end if;
        k := k + 1;
      end loop;
      wait;
    end process;
  end generate;

  -- ── Sondas: actividad en TD y DE ────────────────────────────────────────
  probe : process(clk)
    variable td_prev : std_logic_vector(N_CH-1 downto 0) := (others => '1');
  begin
    if rising_edge(clk) then
      for i in 0 to N_CH-1 loop
        if td_lines(i) /= td_prev(i) then
          td_edges <= td_edges + 1;
        end if;
      end loop;
      td_prev := td_lines;
      if unsigned(de_lines) /= 0 then de_seen <= true; end if;
    end if;
  end process;

  -- ── Watchdog global ─────────────────────────────────────────────────────
  watchdog : process
  begin
    wait for 5 ms;
    if not sim_end then
      report "WATCHDOG global: la simulacion no termino sola (posible cuelgue)" severity warning;
      report "SIM_RESULT: FAIL (watchdog)" severity note;
      stop;
    end if;
    wait;
  end process;

  -- ── Estímulo principal: maestro AXI-Stream (modelo DMA MM2S) ────────────
  stim : process
    variable idx        : integer := 0;
    variable waited     : integer := 0;
    variable stalled    : boolean := false;
    variable done_fail  : boolean := false;
    variable clear_fail : boolean := false;
    variable rd         : std_logic_vector(31 downto 0);

    -- Lectura AXI-Lite (acotada).
    procedure axi_read(addr : in std_logic_vector(3 downto 0);
                       data : out std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      s_axi_araddr  <= addr;
      s_axi_arvalid <= '1';
      s_axi_rready  <= '1';
      loop
        wait until rising_edge(clk);
        exit when s_axi_arready = '1';
      end loop;
      s_axi_arvalid <= '0';
      loop
        exit when s_axi_rvalid = '1';
        wait until rising_edge(clk);
      end loop;
      data := s_axi_rdata;
      s_axi_rready <= '0';
    end procedure;

    -- Escritura AXI-Lite (acotada). Como el esclavo responde B en el mismo ciclo
    -- que AWREADY/WREADY (bready se mantiene alto), se capturan los handshakes en
    -- un único bucle para no perder el pulso de BVALID.
    procedure axi_write(addr : in std_logic_vector(3 downto 0);
                        data : in std_logic_vector(31 downto 0)) is
    begin
      wait until rising_edge(clk);
      s_axi_awaddr  <= addr; s_axi_awvalid <= '1';
      s_axi_wdata   <= data; s_axi_wvalid  <= '1'; s_axi_wstrb <= "1111";
      s_axi_bready  <= '1';
      loop
        wait until rising_edge(clk);
        if s_axi_awready = '1' then s_axi_awvalid <= '0'; end if;
        if s_axi_wready  = '1' then s_axi_wvalid  <= '0'; end if;
        exit when s_axi_bvalid = '1';
      end loop;
      s_axi_bready <= '0';
    end procedure;
  begin
    aresetn <= '0';
    wait for 20 * CLK_PERIOD;
    aresetn <= '1';
    wait for 20 * CLK_PERIOD;
    report "Reset liberado; enviando stream de la DMA..." severity note;

    -- Enviar el stream completo con handshake AXI-Stream real.
    wait until rising_edge(clk);
    s_axis_tvalid <= '1';
    while idx <= STREAM'high loop
      s_axis_tdata <= STREAM(idx);
      s_axis_tlast <= LAST(idx);
      wait until rising_edge(clk);
      if s_axis_tready = '1' then
        idx     := idx + 1;
        waited  := 0;
      else
        waited := waited + 1;
        if waited >= 100000 then          -- ~1 ms sin avanzar -> atasco
          stalled := true;
          exit;
        end if;
      end if;
    end loop;
    s_axis_tvalid <= '0';
    s_axis_tlast  <= '0';

    if stalled then
      report "DIAGNOSTICO: el maestro AXI-Stream se atasco en el beat " &
             integer'image(idx) & " (TREADY nunca llego)." severity note;
      report "SIM_RESULT: FAIL (AXIS stall)" severity note;
      sim_end <= true;
      stop;
    end if;
    report "Stream completo enviado (" & integer'image(STREAM'length) &
           " beats). Esperando transmisiones serie..." severity note;

    -- Esperar a que se decodifiquen todos los bytes esperados (acotado).
    waited := 0;
    while score.checked < TOTAL_EXPECTED and waited < 400000 loop
      wait until rising_edge(clk);
      waited := waited + 1;
    end loop;
    -- margen extra por si llega algún byte de más
    wait for 50 * BIT_TIME;

    -- ── Comprobación vía AXI-Lite: TX_DONE + interrupción EOAF + W1C ───────
    -- 1) La PS lee TX_DONE (0x00): deben quedar enganchados los bits 0,1,5,13
    --    y la interrupción (EOAF) debe estar alta (nivel, sin atender todavía).
    axi_read(x"0", rd);
    report "AXI rd TX_DONE = 0x" & to_hstring(rd) severity note;
    if rd(N_CH-1 downto 0) /= EXP_DONE then
      done_fail := true;
      report "DIAGNOSTICO: TX_DONE = " & to_hstring(rd(N_CH-1 downto 0)) &
             "  ESPERADO " & to_hstring(EXP_DONE) severity warning;
    end if;
    if eoaf /= '1' then
      done_fail := true;
      report "DIAGNOSTICO: EOAF no esta alto con lotes pendientes." severity warning;
    end if;

    -- 2) La ISR limpia (write-1-to-clear en TX_DONE_CLEAR, 0x04) los bits leídos.
    axi_write(x"4", rd);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    -- 3) Tras la limpieza: TX_DONE debe estar a 0 y EOAF desactivada.
    axi_read(x"0", rd);
    report "AXI rd TX_DONE (tras W1C) = 0x" & to_hstring(rd) severity note;
    if unsigned(rd) /= 0 then
      clear_fail := true;
      report "DIAGNOSTICO: tras W1C, TX_DONE no quedo a cero: 0x" &
             to_hstring(rd) severity warning;
    end if;
    if eoaf /= '0' then
      clear_fail := true;
      report "DIAGNOSTICO: tras W1C, la interrupcion EOAF no se desactivo." severity warning;
    end if;

    -- ── Veredicto ─────────────────────────────────────────────────────────
    report "------------------------------------------------------------";
    report "TD flancos observados : " & integer'image(td_edges);
    report "DE asertado alguna vez: " & boolean'image(de_seen);
    report "Bytes esperados       : " & integer'image(TOTAL_EXPECTED);
    report "Bytes decodificados   : " & integer'image(score.checked);
    report "Errores de dato       : " & integer'image(score.errors);

    if td_edges = 0 then
      report "DIAGNOSTICO: ninguna linea TD conmuto: el puente no lanzo envios." severity note;
      report "SIM_RESULT: FAIL (sin transmision)" severity note;
    elsif score.checked < TOTAL_EXPECTED then
      report "DIAGNOSTICO: faltan bytes (algun canal no transmitio todo)." severity note;
      report "SIM_RESULT: FAIL (RX incompleto)" severity note;
    elsif score.errors > 0 then
      report "SIM_RESULT: FAIL (datos erroneos)" severity note;
    elsif score.checked > TOTAL_EXPECTED then
      report "DIAGNOSTICO: se decodificaron bytes de mas." severity note;
      report "SIM_RESULT: FAIL (bytes extra)" severity note;
    elsif done_fail then
      report "SIM_RESULT: FAIL (tx_done/EOAF incorrecto)" severity note;
    elsif clear_fail then
      report "SIM_RESULT: FAIL (write-1-to-clear no funciona)" severity note;
    else
      report "SIM_RESULT: PASS" severity note;
    end if;
    report "------------------------------------------------------------";

    sim_end <= true;
    stop;
    wait;
  end process;

end architecture;
