----------------------------------------------------------------------------------
-- tb_serial_rx_bp  (S8a)
--
-- Reproduccion de T2 con la pieza que S5 y S6 nunca tuvieron JUNTAS:
--   * entrada serie a 115200 real, 1024 B seguidos          (como S6)
--   * contrapresion del MCDMA sobre m_axis_tready            (como S5, pero
--     sobre el camino completo CONFIGURABLE_SERIAL + BRIDGE_RX_TOP real)
--
-- DATO DE PLACA A REPRODUCIR (contadores del motor, 2026-07-13):
--   por el puerto S_AXIS_S2MM cruzo UN paquete de 514 B y el canal enmudecio;
--   PKTDROP=0 (el motor no tiro nada), el motor tenia BDs libres por delante y
--   un solo BD cabe 1024 B. Luego el motor cerro el BD a 514 porque le llego un
--   TLAST a los 514: TLAST prematuro del DRAIN (m_axis_tlast <= rx_fifo_empty).
--
-- PREGUNTA QUE ESTE BANCO RESPONDE (no la que asume):
--   Tras ese primer paquete de 514, ¿el DRAIN VUELVE a drenar los 510 B
--   restantes, o se queda mudo?
--     bytes_axis = 1024  -> el DRAIN reentra: el mudo NO esta en el DRAIN
--                           (siguiente paso: netlist real de axi_mcdma, S8b).
--     bytes_axis = 514   -> el DRAIN NO reentra: causa localizada en el DRAIN.
--
-- La ventana de contrapresion de ARRANQUE (BP_START) NO se ajusta "para que de
-- 514": se fija lo bastante larga para que la FIFO se llene a ~512 mientras el
-- DRAIN esta frenado, reproduciendo el primer paquete de 514 que ya se OBSERVO
-- en placa. El 514 es el ESTIMULO reproducido, no la respuesta buscada. La
-- respuesta es el conteo TOTAL y si hay silencio despues.
--
-- Se barre ademas una ventana por-TLAST (BP_BD) que emula el cierre de BD +
-- latencia de la ISR de rearme, para ver si la reentrada depende de ella.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_serial_rx_bp is
  generic (
    -- Ventana de contrapresion de ARRANQUE en ns: tready bajo este tiempo desde
    -- el reset, para que la FIFO se llene a ~512 antes de que el DRAIN la vacie.
    -- ~512 bytes * 86.8 us/byte ~ 44 ms; con 46 ms la FIFO llega holgada a 512.
    BP_START_NS : integer := 46000000;   -- 46 ms
    -- Ventana por-TLAST en ns: tready bajo tras CADA TLAST aceptado, emulando
    -- cierre de BD + latencia de ISR de rearme. Barrer (0 = sin contrapresion extra).
    BP_BD_NS    : integer := 0
  );
end tb_serial_rx_bp;

architecture sim of tb_serial_rx_bp is

  constant CLK_P   : time    := 10 ns;          -- 100 MHz
  constant BIT_T   : time    := 8681 ns;        -- 115200 baudios
  constant N_BYTES : integer := 1024;
  constant BP_START : time := BP_START_NS * 1 ns;
  constant BP_BD    : time := BP_BD_NS    * 1 ns;

  signal clk    : std_logic := '0';
  signal resetn : std_logic := '0';

  signal line_rd : std_logic := '1';

  signal data_out  : std_logic_vector(8 downto 0);
  signal data_read : std_logic;
  signal fifo_full : std_logic;
  signal fifo_empty: std_logic;
  signal prog_full : std_logic;
  signal timeout   : std_logic;
  signal timeout_ok: std_logic;
  signal dbg_rx    : std_logic_vector(3 downto 0);

  signal m_tdata  : std_logic_vector(7 downto 0);
  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '0';   -- arranca BAJO (contrapresion de arranque)
  signal m_tlast  : std_logic;
  signal m_tdest  : std_logic_vector(3 downto 0);

  signal top_rd     : std_logic_vector(0 downto 0);
  signal top_empty  : std_logic_vector(0 downto 0);
  signal top_pfull  : std_logic_vector(0 downto 0);
  signal top_tmo    : std_logic_vector(0 downto 0);
  signal top_tmo_ok : std_logic_vector(0 downto 0);

  signal bytes_wr   : integer := 0;
  signal bytes_axis : integer := 0;
  signal pkt_count  : integer := 0;
  signal full_hits  : integer := 0;
  signal tx_done    : boolean := false;

  procedure uart_send(signal l : out std_logic; b : in integer) is
    variable v : std_logic_vector(7 downto 0);
  begin
    v := std_logic_vector(to_unsigned(b, 8));
    l <= '0';  wait for BIT_T;
    for i in 0 to 7 loop
      l <= v(i);  wait for BIT_T;
    end loop;
    l <= '1';  wait for BIT_T;
  end procedure;

begin

  clk <= not clk after CLK_P / 2;

  u_serial : entity work.CONFIGURABLE_SERIAL
    port map (
      Reset => resetn, Clk => clk,
      Data_in => (others => '0'), TX_Send => '0',
      TX_RDY => open, Send_ok => open, DE => open, TD => open,
      RD => line_rd,
      Data_out => data_out, Data_read => data_read,
      Full => fifo_full, Empty => fifo_empty,
      PAR_ERROR => open, FRAME_ERROR => open,
      ERROR_OK => '1',
      Timeout => timeout, Timeout_ok => timeout_ok,
      Prog_Full => prog_full,
      baud_sel => "011101",            -- 29 = 115200
      stop_bit => "01",
      parity   => "100",
      bit_order => '0',
      data_bits => "011",
      dbg_rx => dbg_rx);

  top_empty(0) <= fifo_empty;
  top_pfull(0) <= prog_full;
  top_tmo(0)   <= timeout;
  data_read    <= top_rd(0);
  timeout_ok   <= top_tmo_ok(0);

  u_top : entity work.BRIDGE_RX_TOP
    generic map (N_CH => 1)
    port map (
      aclk => clk, aresetn => resetn,
      m_axis_tdata => m_tdata, m_axis_tvalid => m_tvalid,
      m_axis_tready => m_tready, m_axis_tlast => m_tlast,
      m_axis_tdest => m_tdest,
      timeout_in => top_tmo, timeout_ok_out => top_tmo_ok,
      rx_fifo_empty => top_empty, rx_fifo_prog_full => top_pfull,
      rx_fifo_dout => data_out(7 downto 0), rx_fifo_rd => top_rd);

  -- ── Contrapresion del MCDMA sobre tready (UN solo driver) ───────────────
  --  1) Ventana de ARRANQUE: tready bajo BP_START tras el reset -> la FIFO se
  --     llena a ~512 mientras el DRAIN esta frenado (reproduce el 1er pkt=514).
  --  2) Tras liberar, tready alto salvo una ventana BP_BD tras CADA TLAST
  --     aceptado (cierre de BD + latencia de la ISR de rearme).
  bp_proc : process
  begin
    m_tready <= '0';
    wait until resetn = '1';
    wait for BP_START;
    loop
      m_tready <= '1';
      -- esperar el proximo TLAST aceptado (o salir por tiempo si ya no hay mas)
      wait until rising_edge(clk) and m_tvalid = '1' and m_tlast = '1' for 100 ms;
      exit when not (m_tvalid = '1' and m_tlast = '1');   -- se agoto el tiempo: fin
      if BP_BD > 0 us then
        m_tready <= '0';
        wait for BP_BD;
      end if;
    end loop;
    m_tready <= '1';
    wait;
  end process;

  -- ── Transmisor: 1024 bytes SEGUIDOS ────────────────────────────────────
  tx_proc : process
  begin
    resetn  <= '0';
    line_rd <= '1';
    wait for 50 * CLK_P;
    resetn <= '1';
    wait for 200 * CLK_P;

    for i in 0 to N_BYTES - 1 loop
      uart_send(line_rd, i mod 256);
    end loop;

    tx_done <= true;
    wait for 30 ms;   -- silencio: deja saltar el Timeout y drenar la cola

    report "=========== RESULTADO S8a ===========" severity note;
    report "BP_START = " & time'image(BP_START) &
           "   BP_BD = " & time'image(BP_BD) severity note;
    report "bytes enviados por la linea : " & integer'image(N_BYTES)     severity note;
    report "bytes escritos en la FIFO   : " & integer'image(bytes_wr)    severity note;
    report "ciclos con FIFO llena       : " & integer'image(full_hits)   severity note;
    report "bytes salidos por AXI-Stream: " & integer'image(bytes_axis)  severity note;
    report "paquetes (TLAST)            : " & integer'image(pkt_count)   severity note;

    if bytes_wr < N_BYTES then
      report "El RX dejo de escribir en la FIFO (bytes_wr<1024): perdida en el core"
        severity warning;
    end if;
    if bytes_axis = N_BYTES then
      report "VEREDICTO: el DRAIN REENTRA y drena los 1024. El mudo NO esta en el "
           & "DRAIN -> siguiente: netlist real de axi_mcdma (S8b)." severity note;
    elsif bytes_axis > 0 and bytes_axis < N_BYTES then
      report "VEREDICTO: el DRAIN se queda mudo tras " & integer'image(bytes_axis)
           & " bytes. CAUSA LOCALIZADA EN EL DRAIN (reentrada rota)." severity note;
    end if;
    std.env.stop;
  end process;

  -- dbg_rx = {empty, Fifo_write, Valid_out, RD}
  mon_wr : process(clk)
  begin
    if rising_edge(clk) then
      if dbg_rx(2) = '1' then bytes_wr <= bytes_wr + 1; end if;
      if fifo_full = '1' then full_hits <= full_hits + 1; end if;
    end if;
  end process;

  mon_axis : process(clk)
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        bytes_axis <= bytes_axis + 1;
        if m_tlast = '1' then
          pkt_count <= pkt_count + 1;
          report "paquete #" & integer'image(pkt_count + 1) &
                 " cerrado tras " & integer'image(bytes_axis + 1) & " bytes (acum)"
                 severity note;
        end if;
      end if;
    end if;
  end process;

end sim;
