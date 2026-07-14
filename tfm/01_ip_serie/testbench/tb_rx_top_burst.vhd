----------------------------------------------------------------------------------
-- tb_rx_top_burst
--
-- Igual que tb_rx_drain_burst, pero con el BRIDGE_RX_TOP completo: DEMUX,
-- barrido round-robin de RD_ID y las 14 FIFOs reales. Se escribe SOLO por CH1
-- (el canal que enmudece en la placa) y se deja timeout_in a cero, de modo que
-- la única vía posible de drenado es prog_full.
--
-- En la placa este caso entrega un único paquete de 514 bytes. Si el DEMUX y el
-- barrido están bien, aquí deben salir ~4 paquetes con tdest=1 y 0 bytes perdidos.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_rx_top_burst is
end tb_rx_top_burst;

architecture sim of tb_rx_top_burst is

  constant CLK_P   : time    := 10 ns;
  constant N_CH    : integer := 14;
  constant TX_CH   : integer := 1;      -- canal que recibe la ráfaga
  constant N_BYTES : integer := 1024;
  constant WR_GAP  : integer := 40;

  signal clk     : std_logic := '0';
  signal aresetn : std_logic := '0';
  signal srst    : std_logic;

  type slv9_arr is array (0 to N_CH-1) of std_logic_vector(8 downto 0);
  signal fifo_din  : slv9_arr := (others => (others => '0'));
  signal fifo_dout : slv9_arr;

  signal fifo_wr    : std_logic_vector(N_CH-1 downto 0) := (others => '0');
  signal fifo_rd    : std_logic_vector(N_CH-1 downto 0);
  signal fifo_full  : std_logic_vector(N_CH-1 downto 0);
  signal fifo_empty : std_logic_vector(N_CH-1 downto 0);
  signal fifo_pfull : std_logic_vector(N_CH-1 downto 0);

  signal top_rd     : std_logic_vector(N_CH-1 downto 0);
  signal rx_dout_v  : std_logic_vector(N_CH*8-1 downto 0);

  signal m_tdata  : std_logic_vector(7 downto 0);
  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '1';
  signal m_tlast  : std_logic;
  signal m_tdest  : std_logic_vector(3 downto 0);

  signal timeout_in : std_logic_vector(N_CH-1 downto 0) := (others => '0');
  signal timeout_ok : std_logic_vector(N_CH-1 downto 0);

  signal wr_count   : integer := 0;
  signal lost_count : integer := 0;
  signal rx_count   : integer := 0;
  signal pkt_count  : integer := 0;
  signal bad_dest   : integer := 0;
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

  gen_fifo : for i in 0 to N_CH-1 generate
    -- igual que CONFIGURABLE_SERIAL: nunca se lee en vacío
    fifo_rd(i) <= (not fifo_empty(i)) and top_rd(i);

    u_fifo : fifo_rx
      port map (
        clk => clk, srst => srst,
        din => fifo_din(i), wr_en => fifo_wr(i), rd_en => fifo_rd(i),
        dout => fifo_dout(i), full => fifo_full(i), empty => fifo_empty(i),
        prog_full => fifo_pfull(i), wr_rst_busy => open, rd_rst_busy => open);

    rx_dout_v(i*8+7 downto i*8) <= fifo_dout(i)(7 downto 0);
  end generate;

  u_top : entity work.BRIDGE_RX_TOP
    generic map (N_CH => N_CH)
    port map (
      aclk => clk, aresetn => aresetn,
      m_axis_tdata  => m_tdata,
      m_axis_tvalid => m_tvalid,
      m_axis_tready => m_tready,
      m_axis_tlast  => m_tlast,
      m_axis_tdest  => m_tdest,
      timeout_in        => timeout_in,
      timeout_ok_out    => timeout_ok,
      rx_fifo_empty     => fifo_empty,
      rx_fifo_prog_full => fifo_pfull,
      rx_fifo_dout      => rx_dout_v,
      rx_fifo_rd        => top_rd);

  wr_proc : process
  begin
    aresetn <= '0';
    wait for 20 * CLK_P;
    wait until rising_edge(clk);
    aresetn <= '1';
    wait for 60 * CLK_P;

    for i in 0 to N_BYTES - 1 loop
      wait until rising_edge(clk);
      if fifo_full(TX_CH) = '1' then
        lost_count <= lost_count + 1;
      else
        fifo_din(TX_CH) <= '0' & std_logic_vector(to_unsigned(i mod 256, 8));
        fifo_wr(TX_CH)  <= '1';
        wr_count        <= wr_count + 1;
      end if;
      wait until rising_edge(clk);
      fifo_wr(TX_CH) <= '0';
      for g in 0 to WR_GAP - 2 loop
        wait until rising_edge(clk);
      end loop;
    end loop;

    wr_done <= true;
    wait for 3000 * CLK_P;   -- margen para que drene lo que quede

    report "=========== RESULTADO ===========" severity note;
    report "escritos en FIFO CH1 : " & integer'image(wr_count)   severity note;
    report "perdidos (full)      : " & integer'image(lost_count) severity note;
    report "salidos por AXIS     : " & integer'image(rx_count)   severity note;
    report "paquetes (TLAST)     : " & integer'image(pkt_count)  severity note;
    report "paquetes con tdest malo: " & integer'image(bad_dest) severity note;
    if lost_count > 0 then
      report "FALLO: la FIFO de CH1 desborda: el DRAIN no la atiende" severity error;
    elsif rx_count /= wr_count then
      report "FALLO: salen " & integer'image(rx_count) & " de " &
             integer'image(wr_count) & " bytes" severity error;
    elsif bad_dest > 0 then
      report "FALLO: TDEST incorrecto" severity error;
    else
      report "OK: todos los bytes salen por tdest=1, en " &
             integer'image(pkt_count) & " paquetes" severity note;
    end if;
    std.env.stop;
  end process;

  mon_proc : process(clk)
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        rx_count <= rx_count + 1;
        if to_integer(unsigned(m_tdest)) /= TX_CH then
          bad_dest <= bad_dest + 1;
        end if;
        if m_tlast = '1' then
          pkt_count <= pkt_count + 1;
          report "paquete #" & integer'image(pkt_count + 1) &
                 " cerrado tras " & integer'image(rx_count + 1) &
                 " bytes, tdest=" & integer'image(to_integer(unsigned(m_tdest)))
                 severity note;
        end if;
      end if;
    end if;
  end process;

  full_proc : process(clk)
    variable avisado : boolean := false;
  begin
    if rising_edge(clk) then
      if fifo_full(TX_CH) = '1' and not wr_done and not avisado then
        report "FIFO CH1 LLENA con " & integer'image(rx_count) & " bytes drenados"
          severity warning;
        avisado := true;
      end if;
    end if;
  end process;

end sim;
