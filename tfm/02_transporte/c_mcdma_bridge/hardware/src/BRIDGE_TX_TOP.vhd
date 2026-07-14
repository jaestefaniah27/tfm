library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BRIDGE_TX_TOP is
  generic (
    N_CH : integer := 14
  );
  Port (
    aclk          : in  std_logic;
    aresetn       : in  std_logic;
    -- AXI-Stream desde la DMA MM2S
    s_axis_tdata  : in  std_logic_vector(7 downto 0);
    s_axis_tvalid : in  std_logic;
    s_axis_tready : out std_logic;
    s_axis_tlast  : in  std_logic;
    -- Por canal hacia los cores UART (buses aplanados)
    TX_din        : out std_logic_vector(N_CH*9-1 downto 0);  -- 9 bits × N_CH
    TX_Send       : out std_logic_vector(N_CH-1 downto 0);
    Send_ok       : in  std_logic_vector(N_CH-1 downto 0);
    TX_RDY        : in  std_logic_vector(N_CH-1 downto 0);
    EOT           : in  std_logic_vector(N_CH-1 downto 0);
    -- ── Notificación a la PS: gestionada por TX_ISR_EOF_HANDLER ───────────────
    -- AXI-Lite esclavo (registros TX_DONE / TX_DONE_CLEAR / IRQ_ENABLE / IRQ_STATUS)
    s_axi_awaddr  : in  std_logic_vector(3 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(3 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;
    -- Interrupción ÚNICA hacia la PS (por nivel). La ISR lee TX_DONE por AXI-Lite
    -- para discriminar qué canal(es) terminaron su lote. (antes "End Of Any Frame")
    EOAF          : out std_logic
  );
end BRIDGE_TX_TOP;

architecture Behavioral of BRIDGE_TX_TOP is

  -- ── Componentes ────────────────────────────────────────────────────────────
  component TX_DMA_ROUTER
    port (
      aclk          : in  std_logic;
      aresetn       : in  std_logic;
      s_axis_tdata  : in  std_logic_vector(7 downto 0);
      s_axis_tvalid : in  std_logic;
      s_axis_tready : out std_logic;
      s_axis_tlast  : in  std_logic;
      TX_ID         : out std_logic_vector(3 downto 0);
      fifo_din      : out std_logic_vector(7 downto 0);
      fifo_full     : in  std_logic;
      fifo_wr       : out std_logic
    );
  end component;

  component MUX_2x16
    port (
      TX_ID       : in  std_logic_vector(3 downto 0);
      fifo_wr_in  : in  std_logic;
      fifo_wr_out : out std_logic_vector(15 downto 0)
    );
  end component;

  component TX_WORKER
    port (
      aclk    : in  std_logic;
      aresetn : in  std_logic;
      wr_en     : in  std_logic;
      din       : in  std_logic_vector(7 downto 0);
      fifo_full : out std_logic;
      TX_din  : out std_logic_vector(8 downto 0);
      TX_Send : out std_logic;
      Send_ok : in  std_logic;
      TX_RDY  : in  std_logic;
      EOT     : in  std_logic;
      EOF     : out std_logic
    );
  end component;

  component TX_ISR_EOF_HANDLER
    generic (
      N_CH : integer := 14
    );
    port (
      aclk          : in  std_logic;
      aresetn       : in  std_logic;
      eof           : in  std_logic_vector(N_CH-1 downto 0);
      irq           : out std_logic;
      s_axi_awaddr  : in  std_logic_vector(3 downto 0);
      s_axi_awvalid : in  std_logic;
      s_axi_awready : out std_logic;
      s_axi_wdata   : in  std_logic_vector(31 downto 0);
      s_axi_wstrb   : in  std_logic_vector(3 downto 0);
      s_axi_wvalid  : in  std_logic;
      s_axi_wready  : out std_logic;
      s_axi_bresp   : out std_logic_vector(1 downto 0);
      s_axi_bvalid  : out std_logic;
      s_axi_bready  : in  std_logic;
      s_axi_araddr  : in  std_logic_vector(3 downto 0);
      s_axi_arvalid : in  std_logic;
      s_axi_arready : out std_logic;
      s_axi_rdata   : out std_logic_vector(31 downto 0);
      s_axi_rresp   : out std_logic_vector(1 downto 0);
      s_axi_rvalid  : out std_logic;
      s_axi_rready  : in  std_logic
    );
  end component;

  -- ── Señales internas ───────────────────────────────────────────────────────
  signal router_tx_id    : std_logic_vector(3 downto 0);
  signal router_fifo_din : std_logic_vector(7 downto 0);
  signal router_fifo_wr  : std_logic;
  signal mux_wr_out      : std_logic_vector(15 downto 0);
  signal worker_eof      : std_logic_vector(N_CH-1 downto 0);
  signal worker_full     : std_logic_vector(N_CH-1 downto 0);
  signal sel_full        : std_logic;

begin

  -- El router escribe en la FIFO del canal que indica TX_ID: la contrapresión
  -- que le importa es la de ese canal, no la del resto.
  process(router_tx_id, worker_full)
    variable idx : integer range 0 to 15;
  begin
    idx := to_integer(unsigned(router_tx_id));
    if idx < N_CH then
      sel_full <= worker_full(idx);
    else
      sel_full <= '0';          -- canal inexistente: no bloquear el flujo
    end if;
  end process;

  -- ── Router: parsea [idx][len][payload] desde la DMA ───────────────────────
  u_router: TX_DMA_ROUTER
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      s_axis_tdata  => s_axis_tdata,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tready => s_axis_tready,
      s_axis_tlast  => s_axis_tlast,
      TX_ID         => router_tx_id,
      fifo_din      => router_fifo_din,
      fifo_full     => sel_full,
      fifo_wr       => router_fifo_wr
    );

  -- ── Demux: activa el wr_en del canal seleccionado ─────────────────────────
  u_mux: MUX_2x16
    port map (
      TX_ID       => router_tx_id,
      fifo_wr_in  => router_fifo_wr,
      fifo_wr_out => mux_wr_out
    );

  -- ── Un TX_WORKER por canal ─────────────────────────────────────────────────
  -- fifo_din es el mismo para todos (broadcast); solo wr_en varía por canal
  gen_workers: for i in 0 to N_CH-1 generate
    u_worker: TX_WORKER
      port map (
        aclk    => aclk,
        aresetn => aresetn,
        wr_en     => mux_wr_out(i),
        din       => router_fifo_din,
        fifo_full => worker_full(i),
        TX_din  => TX_din(i*9+8 downto i*9),
        TX_Send => TX_Send(i),
        Send_ok => Send_ok(i),
        TX_RDY  => TX_RDY(i),
        EOT     => EOT(i),
        EOF     => worker_eof(i)
      );
  end generate;

  -- ── Gestor de interrupciones de fin de lote (sticky + AXI-Lite + IRQ) ──────
  u_isr: TX_ISR_EOF_HANDLER
    generic map (
      N_CH => N_CH
    )
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      eof           => worker_eof,
      irq           => EOAF,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready
    );

end Behavioral;
