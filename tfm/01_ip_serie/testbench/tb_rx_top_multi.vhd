----------------------------------------------------------------------------------
-- tb_rx_top_multi
--
-- La diferencia entre las simulaciones anteriores (que salen limpias) y la placa:
-- allí escribía en UN canal, aquí escriben los SEIS del bus a la vez, que es lo
-- que ocurre con el loopback (CH0 transmite; CH1..CH6 reciben lo mismo).
--
-- El DRAIN es una única FSM compartida por los 14 canales, con RD_ID en
-- round-robin. Con un canal activo, un desajuste entre el índice con el que se
-- LEE la FIFO y el índice con el que se marca el TDEST es invisible. Con seis,
-- no.
--
-- Cada canal escribe bytes cuyo valor ES su propio número. Así, todo byte que
-- salga con tdest /= dato es un byte encaminado al canal equivocado.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_rx_top_multi is
end tb_rx_top_multi;

architecture sim of tb_rx_top_multi is

  constant CLK_P   : time    := 10 ns;
  constant N_CH    : integer := 14;
  constant LO_CH   : integer := 1;      -- primer receptor del bus
  constant HI_CH   : integer := 6;      -- último receptor del bus
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

  signal top_rd    : std_logic_vector(N_CH-1 downto 0);
  signal rx_dout_v : std_logic_vector(N_CH*8-1 downto 0);

  signal m_tdata  : std_logic_vector(7 downto 0);
  signal m_tvalid : std_logic;
  signal m_tready : std_logic := '1';
  signal m_tlast  : std_logic;
  signal m_tdest  : std_logic_vector(3 downto 0);

  signal timeout_in : std_logic_vector(N_CH-1 downto 0) := (others => '0');
  signal timeout_ok : std_logic_vector(N_CH-1 downto 0);

  type int_arr is array (0 to N_CH-1) of integer;
  signal wr_count   : int_arr := (others => 0);
  signal lost_count : int_arr := (others => 0);
  signal rx_count   : int_arr := (others => 0);   -- por tdest
  signal mis_count  : integer := 0;               -- byte con tdest /= dato
  signal pkt_count  : integer := 0;
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

  -- ── Los seis receptores del bus reciben el mismo flujo, a la vez ─────────
  wr_proc : process
  begin
    aresetn <= '0';
    wait for 20 * CLK_P;
    wait until rising_edge(clk);
    aresetn <= '1';
    wait for 60 * CLK_P;

    for i in 0 to N_BYTES - 1 loop
      wait until rising_edge(clk);
      for c in LO_CH to HI_CH loop
        if fifo_full(c) = '1' then
          lost_count(c) <= lost_count(c) + 1;
        else
          -- el dato ES el número de canal: delata cualquier desvío
          fifo_din(c) <= '0' & std_logic_vector(to_unsigned(c, 8));
          fifo_wr(c)  <= '1';
          wr_count(c) <= wr_count(c) + 1;
        end if;
      end loop;
      wait until rising_edge(clk);
      fifo_wr <= (others => '0');
      for g in 0 to WR_GAP - 2 loop
        wait until rising_edge(clk);
      end loop;
    end loop;

    wr_done <= true;
    wait for 20000 * CLK_P;   -- margen para drenar

    report "=========== RESULTADO ===========" severity note;
    for c in LO_CH to HI_CH loop
      report "CH" & integer'image(c) &
             ": escritos=" & integer'image(wr_count(c)) &
             "  perdidos=" & integer'image(lost_count(c)) &
             "  salidos=" & integer'image(rx_count(c)) severity note;
    end loop;
    report "paquetes (TLAST)   : " & integer'image(pkt_count) severity note;
    report "bytes mal encaminados: " & integer'image(mis_count) severity note;

    if mis_count > 0 then
      report "FALLO: bytes con TDEST distinto de su canal de origen" severity error;
    else
      report "sin desvios de TDEST" severity note;
    end if;
    std.env.stop;
  end process;

  mon_proc : process(clk)
    variable d : integer;
  begin
    if rising_edge(clk) then
      if m_tvalid = '1' and m_tready = '1' then
        d := to_integer(unsigned(m_tdest));
        if d < N_CH then
          rx_count(d) <= rx_count(d) + 1;
        end if;
        -- el dato debe coincidir con el canal al que se atribuye
        if to_integer(unsigned(m_tdata)) /= d then
          mis_count <= mis_count + 1;
          if mis_count < 8 then
            report "DESVIO: dato=" & integer'image(to_integer(unsigned(m_tdata))) &
                   " pero tdest=" & integer'image(d) severity warning;
          end if;
        end if;
        if m_tlast = '1' then
          pkt_count <= pkt_count + 1;
        end if;
      end if;
    end if;
  end process;

  full_proc : process(clk)
    variable avisado : std_logic_vector(N_CH-1 downto 0) := (others => '0');
  begin
    if rising_edge(clk) then
      for c in LO_CH to HI_CH loop
        if fifo_full(c) = '1' and not wr_done and avisado(c) = '0' then
          report "FIFO CH" & integer'image(c) & " LLENA" severity warning;
          avisado(c) := '1';
        end if;
      end loop;
    end if;
  end process;

end sim;
