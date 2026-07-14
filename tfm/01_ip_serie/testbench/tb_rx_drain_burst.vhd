----------------------------------------------------------------------------------
-- tb_rx_drain_burst
--
-- Reproduce el escenario de T2: una ráfaga CONTINUA de bytes entrando en la FIFO
-- de RX de un canal, al ritmo de una UART, sin silencios que disparen el timeout.
--
-- En la placa ese caso entrega UN solo paquete de 514 bytes y luego nada, cuando
-- deberían salir paquetes de ~257 (prog_full = 256) durante toda la ráfaga.
--
-- El TB usa el fifo_rx REAL (netlist del IP, umbral 256) y el DRAIN real. No
-- modela nada: si el fallo está en esa pareja, aquí se ve.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_rx_drain_burst is
end tb_rx_drain_burst;

architecture sim of tb_rx_drain_burst is

  constant CLK_P    : time    := 10 ns;      -- 100 MHz
  constant N_BYTES  : integer := 1024;       -- el bloque de T2
  -- Un byte cada 40 ciclos: ráfaga continua, mucho más rápida que 115200 para
  -- que la simulación acabe, pero igual de "sin huecos" desde la vista del FIFO.
  constant WR_GAP   : integer := 40;

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal srst    : std_logic;

  -- FIFO
  signal fifo_din   : std_logic_vector(8 downto 0) := (others => '0');
  signal fifo_wr    : std_logic := '0';
  signal fifo_rd    : std_logic;
  signal fifo_dout  : std_logic_vector(8 downto 0);
  signal fifo_full  : std_logic;
  signal fifo_empty : std_logic;
  signal fifo_pfull : std_logic;

  -- DRAIN
  signal drain_rd    : std_logic;
  signal m_tdata     : std_logic_vector(7 downto 0);
  signal m_tvalid    : std_logic;
  signal m_tready    : std_logic := '1';   -- el MCDMA siempre acepta
  signal m_tlast     : std_logic;
  signal m_tdest     : std_logic_vector(3 downto 0);
  signal rd_id       : std_logic_vector(3 downto 0);

  signal timeout_in  : std_logic := '0';
  signal timeout_ok  : std_logic;

  -- Métricas
  signal wr_count   : integer := 0;   -- bytes escritos en la FIFO
  signal lost_count : integer := 0;   -- escrituras con la FIFO llena
  signal rx_count   : integer := 0;   -- bytes salidos por el AXI-Stream
  signal pkt_count  : integer := 0;   -- TLAST vistos
  signal wr_done    : boolean := false;

  component fifo_rx
    port (
      clk         : IN  std_logic;
      srst        : IN  std_logic;
      din         : IN  std_logic_VECTOR(8 downto 0);
      wr_en       : IN  std_logic;
      rd_en       : IN  std_logic;
      dout        : OUT std_logic_VECTOR(8 downto 0);
      full        : OUT std_logic;
      empty       : OUT std_logic;
      prog_full   : OUT std_logic;
      wr_rst_busy : OUT std_logic;
      rd_rst_busy : OUT std_logic);
  end component;

begin

  clk  <= not clk after CLK_P / 2;
  srst <= not aresetn;

  -- El DRAIN sólo lee cuando la FIFO no está vacía (igual que CONFIGURABLE_SERIAL)
  fifo_rd <= (not fifo_empty) and drain_rd;

  u_fifo : fifo_rx
    port map (
      clk => clk, srst => srst,
      din => fifo_din, wr_en => fifo_wr, rd_en => fifo_rd,
      dout => fifo_dout, full => fifo_full, empty => fifo_empty,
      prog_full => fifo_pfull, wr_rst_busy => open, rd_rst_busy => open);

  u_drain : entity work.BRIDGE_RX_FIFO_DRAIN
    generic map (N_CH => 1)
    port map (
      aclk => clk, aresetn => aresetn,
      RD_ID             => rd_id,
      rx_fifo_data_out  => fifo_dout(7 downto 0),
      rx_fifo_prog_full => fifo_pfull,
      rx_fifo_empty     => fifo_empty,
      rx_fifo_rd_out    => drain_rd,
      rx_timeout_in     => timeout_in,
      rx_timeout_ok     => timeout_ok,
      m_axis_tdata      => m_tdata,
      m_axis_tvalid     => m_tvalid,
      m_axis_tready     => m_tready,
      m_axis_tlast      => m_tlast,
      m_axis_tdest      => m_tdest);

  -- ── Escritor: ráfaga continua, un byte cada WR_GAP ciclos ────────────────
  wr_proc : process
  begin
    aresetn <= '0';
    wait for 20 * CLK_P;
    wait until rising_edge(clk);
    aresetn <= '1';
    wait for 40 * CLK_P;   -- que el FIFO salga de reset

    for i in 0 to N_BYTES - 1 loop
      wait until rising_edge(clk);
      if fifo_full = '1' then
        lost_count <= lost_count + 1;   -- desbordamiento: byte perdido
      else
        fifo_din <= '0' & std_logic_vector(to_unsigned(i mod 256, 8));
        fifo_wr  <= '1';
        wr_count <= wr_count + 1;
      end if;
      wait until rising_edge(clk);
      fifo_wr <= '0';
      for g in 0 to WR_GAP - 2 loop
        wait until rising_edge(clk);
      end loop;
    end loop;

    wr_done <= true;

    -- Silencio al final: la UART real levantaría Timeout aquí
    wait for 200 * CLK_P;
    wait until rising_edge(clk);
    timeout_in <= '1';
    wait until timeout_ok = '1';
    wait until rising_edge(clk);
    timeout_in <= '0';

    wait for 2000 * CLK_P;

    report "=========== RESULTADO ===========" severity note;
    report "escritos en FIFO : " & integer'image(wr_count)   severity note;
    report "perdidos (full)  : " & integer'image(lost_count) severity note;
    report "salidos por AXIS : " & integer'image(rx_count)   severity note;
    report "paquetes (TLAST) : " & integer'image(pkt_count)  severity note;
    if lost_count > 0 then
      report "FALLO: la FIFO desborda -> el DRAIN no vacia a tiempo" severity error;
    elsif rx_count /= wr_count then
      report "FALLO: salen menos bytes de los que entraron" severity error;
    else
      report "OK: todos los bytes salen, en " & integer'image(pkt_count) & " paquetes"
        severity note;
    end if;
    std.env.stop;
  end process;

  -- ── Monitor del AXI-Stream ───────────────────────────────────────────────
  mon_proc : process(clk)
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        rx_count <= rx_count + 1;
        if m_tlast = '1' then
          pkt_count <= pkt_count + 1;
          report "paquete #" & integer'image(pkt_count + 1) &
                 " cerrado tras " & integer'image(rx_count + 1) & " bytes totales, tdest=" &
                 integer'image(to_integer(unsigned(m_tdest))) severity note;
        end if;
      end if;
    end if;
  end process;

  -- Aviso en cuanto la FIFO se llena: es el síntoma que buscamos
  full_proc : process(clk)
  begin
    if rising_edge(clk) then
      if fifo_full = '1' and wr_done = false then
        report "FIFO LLENA con " & integer'image(rx_count) & " bytes ya drenados"
          severity warning;
      end if;
    end if;
  end process;

end sim;
