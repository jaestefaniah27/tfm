----------------------------------------------------------------------------------
-- TX_ISR_EOF_HANDLER - Behavioral
----------------------------------------------------------------------------------
-- Gestor de interrupciones de "fin de lote" (EOF) del puente de TX.
--
-- Recibe los pulsos EOF (uno por canal) que emiten los TX_WORKER cuando un canal
-- termina de transmitir TODO el lote que se le encargó. Los engancha en un
-- registro sticky y los expone a la PS por AXI-Lite, generando UNA sola línea de
-- interrupción (irq, por nivel). La ISR lee TX_DONE para saber QUÉ canal terminó
-- y limpia el bit atendido con un write-1-to-clear en TX_DONE_CLEAR.
--
-- Mapa de registros (AXI-Lite, 32 bits, los N_CH bits bajos son significativos):
--   0x00  TX_DONE        (RO)  : bits sticky de fin de lote por canal.
--   0x04  TX_DONE_CLEAR  (W1C) : escribir '1' en bit i -> borra TX_DONE(i).
--   0x08  IRQ_ENABLE     (RW)  : máscara por canal (reset = todos habilitados).
--   0x0C  IRQ_STATUS     (RO)  : TX_DONE and IRQ_ENABLE (lo que dispara irq).
--
-- irq = OR( TX_DONE and IRQ_ENABLE ). Como los bits son sticky, la IRQ se
-- mantiene alta (nivel) hasta que la ISR limpia → nunca se pierde un fin de lote.
-- El SET (llegada de EOF) tiene prioridad sobre el CLEAR (W1C): si coinciden en
-- el mismo ciclo, el bit queda a '1' y no se pierde la notificación.
--
-- VHDL-93 puro (no usa rasgos de 2008): sirva cual sea el file_type del proyecto.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TX_ISR_EOF_HANDLER is
  generic (
    N_CH : integer := 14
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- Pulsos de fin de lote por canal (desde los TX_WORKER)
    eof     : in  std_logic_vector(N_CH-1 downto 0);

    -- Interrupción única hacia la PS (nivel alto)
    irq     : out std_logic;

    -- ── AXI-Lite esclavo ─────────────────────────────────────────────────
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
end TX_ISR_EOF_HANDLER;

architecture Behavioral of TX_ISR_EOF_HANDLER is

  -- Registros
  signal done_flags : std_logic_vector(N_CH-1 downto 0);   -- TX_DONE (sticky)
  signal irq_enable : std_logic_vector(N_CH-1 downto 0);   -- IRQ_ENABLE
  signal clr_pulse  : std_logic_vector(N_CH-1 downto 0);   -- pulso 1 ciclo (W1C)

  -- FSM AXI-Lite (mismo esquema que el resto del proyecto)
  type axi_t is (S_IDLE, S_WRITE_RESP, S_READ_DATA);
  signal axi_st : axi_t;

  signal aw_rdy : std_logic;
  signal w_rdy  : std_logic;
  signal b_vld  : std_logic;
  signal ar_rdy : std_logic;
  signal r_vld  : std_logic;
  signal r_dat  : std_logic_vector(31 downto 0);

begin

  -- ── Salidas AXI-Lite ───────────────────────────────────────────────────
  s_axi_awready <= aw_rdy;
  s_axi_wready  <= w_rdy;
  s_axi_bresp   <= "00";          -- OKAY
  s_axi_bvalid  <= b_vld;
  s_axi_arready <= ar_rdy;
  s_axi_rdata   <= r_dat;
  s_axi_rresp   <= "00";          -- OKAY
  s_axi_rvalid  <= r_vld;

  -- ── Interrupción única (nivel) ─────────────────────────────────────────
  irq <= '1' when unsigned(done_flags and irq_enable) /= 0 else '0';

  -- ── Registro sticky TX_DONE: SET por EOF, CLEAR por W1C (SET gana) ──────
  process(aclk, aresetn)
  begin
    if aresetn = '0' then
      done_flags <= (others => '0');
    elsif rising_edge(aclk) then
      for i in 0 to N_CH-1 loop
        if eof(i) = '1' then
          done_flags(i) <= '1';
        elsif clr_pulse(i) = '1' then
          done_flags(i) <= '0';
        end if;
      end loop;
    end if;
  end process;

  -- ── FSM AXI-Lite: lecturas (RO) y escrituras (W1C / RW) ─────────────────
  process(aclk, aresetn)
  begin
    if aresetn = '0' then
      aw_rdy <= '0'; w_rdy <= '0'; b_vld <= '0';
      ar_rdy <= '0'; r_vld <= '0'; r_dat <= (others => '0');
      clr_pulse  <= (others => '0');
      irq_enable <= (others => '1');   -- por defecto todos los canales habilitados
      axi_st <= S_IDLE;
    elsif rising_edge(aclk) then
      aw_rdy    <= '0';
      w_rdy     <= '0';
      ar_rdy    <= '0';
      clr_pulse <= (others => '0');     -- W1C: pulso de un único ciclo

      case axi_st is
        when S_IDLE =>
          if b_vld = '1' and s_axi_bready = '1' then b_vld <= '0'; end if;
          if r_vld = '1' and s_axi_rready = '1' then r_vld <= '0'; end if;

          -- ── ESCRITURA (AW + W simultáneos) ──
          if s_axi_awvalid = '1' and s_axi_wvalid = '1' then
            aw_rdy <= '1';
            w_rdy  <= '1';
            b_vld  <= '1';
            case s_axi_awaddr(3 downto 2) is
              when "01" =>                                       -- 0x04 TX_DONE_CLEAR (W1C)
                clr_pulse <= s_axi_wdata(N_CH-1 downto 0);
              when "10" =>                                       -- 0x08 IRQ_ENABLE (RW)
                irq_enable <= s_axi_wdata(N_CH-1 downto 0);
              when others =>                                     -- 0x00 (RO) / 0x0C (RO): ignora
                null;
            end case;
            axi_st <= S_WRITE_RESP;

          -- ── LECTURA ──
          elsif s_axi_arvalid = '1' then
            ar_rdy <= '1';
            r_vld  <= '1';
            r_dat  <= (others => '0');
            case s_axi_araddr(3 downto 2) is
              when "00" =>                                       -- 0x00 TX_DONE
                r_dat(N_CH-1 downto 0) <= done_flags;
              when "10" =>                                       -- 0x08 IRQ_ENABLE
                r_dat(N_CH-1 downto 0) <= irq_enable;
              when "11" =>                                       -- 0x0C IRQ_STATUS
                r_dat(N_CH-1 downto 0) <= done_flags and irq_enable;
              when others =>                                     -- 0x04 (W1C): lee 0
                null;
            end case;
            axi_st <= S_READ_DATA;
          end if;

        when S_WRITE_RESP =>
          if s_axi_bready = '1' then
            b_vld  <= '0';
            axi_st <= S_IDLE;
          end if;

        when S_READ_DATA =>
          if s_axi_rready = '1' then
            r_vld  <= '0';
            axi_st <= S_IDLE;
          end if;
      end case;
    end if;
  end process;

end Behavioral;
