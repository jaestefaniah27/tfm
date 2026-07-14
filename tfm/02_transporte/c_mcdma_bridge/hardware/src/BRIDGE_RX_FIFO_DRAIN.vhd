library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Drena la FIFO del canal seleccionado hacia el AXI-Stream del MCDMA.
--
-- INVARIANTE CRITICA: un paquete NUNCA puede superar MAX_PKT bytes.
-- El S2MM del axi_mcdma esta en modo store-and-forward (c_include_s2mm_sf=1):
-- acumula el paquete ENTERO en su buffer interno (512 B) antes de volcarlo a DDR.
-- Un paquete mas largo lo bloquea para siempre (baja tready esperando un TLAST que
-- no puede llegar porque el buffer esta lleno). Ese fue el bug del "514 = 512+2".
entity BRIDGE_RX_FIFO_DRAIN is
    generic (
        N_CH    : integer := 14;
        MAX_PKT : integer := 256   -- < 512 del buffer S&F del S2MM
    );
    Port (
        aclk              : in  std_logic;
        aresetn           : in  std_logic;

        RD_ID             : out std_logic_vector(3 downto 0);

        -- fifo_rx es First-Word-Fall-Through: con empty='0', rx_fifo_data_out ya
        -- muestra la cabeza; rd_out la consume y en el ciclo siguiente aparece la
        -- palabra sucesora.
        rx_fifo_data_out  : in  std_logic_vector(7 downto 0);
        rx_fifo_prog_full : in  std_logic;
        rx_fifo_empty     : in  std_logic;
        rx_fifo_rd_out    : out std_logic;

        rx_timeout_in     : in  std_logic;
        rx_timeout_ok     : out std_logic;

        m_axis_tdata      : out std_logic_vector(7 downto 0);
        m_axis_tvalid     : out std_logic;
        m_axis_tready     : in  std_logic;
        m_axis_tlast      : out std_logic;
        m_axis_tdest      : out std_logic_vector(3 downto 0)
    );
end BRIDGE_RX_FIFO_DRAIN;

architecture Behavioral of BRIDGE_RX_FIFO_DRAIN is
    type state_type is (Idle, Drain);
    signal current_state, next_state : state_type;

    signal rx_id_reg, rx_id_next : std_logic_vector(3 downto 0);
    signal data_reg,  data_next  : std_logic_vector(7 downto 0);

    -- Decision de fin de paquete, CONGELADA una vez ofrecido el byte: AXI-Stream
    -- exige que TLAST no cambie mientras TVALID='1' y TREADY='0'. Sin esto, un byte
    -- que llega por la linea serie durante el stall borraria el TLAST ya presentado
    -- y reabriria el paquete.
    signal last_reg,  last_next  : std_logic;  -- valor congelado
    signal lvld_reg,  lvld_next  : std_logic;  -- 1 = last_reg ya es firme

    -- Bytes ya aceptados del paquete en curso.
    signal cnt_reg, cnt_next : unsigned(15 downto 0);

    signal is_last : std_logic;
begin

    RD_ID <= rx_id_reg;

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                current_state <= Idle;
                rx_id_reg     <= (others=>'0');
                data_reg      <= (others=>'0');
                last_reg      <= '0';
                lvld_reg      <= '0';
                cnt_reg       <= (others=>'0');
            else
                current_state <= next_state;
                rx_id_reg     <= rx_id_next;
                data_reg      <= data_next;
                last_reg      <= last_next;
                lvld_reg      <= lvld_next;
                cnt_reg       <= cnt_next;
            end if;
        end if;
    end process;

    process(current_state, rx_id_reg, data_reg, last_reg, lvld_reg, cnt_reg,
            rx_fifo_prog_full, rx_fifo_empty, rx_timeout_in, rx_fifo_data_out,
            m_axis_tready, is_last)
    begin
        next_state     <= current_state;
        rx_id_next     <= rx_id_reg;
        data_next      <= data_reg;
        last_next      <= last_reg;
        lvld_next      <= lvld_reg;
        cnt_next       <= cnt_reg;

        rx_fifo_rd_out <= '0';
        rx_timeout_ok  <= '0';

        m_axis_tvalid  <= '0';
        m_axis_tdata   <= (others=>'0');
        m_axis_tlast   <= '0';
        m_axis_tdest   <= (others=>'0');

        case current_state is
            when Idle =>
                if rx_fifo_prog_full = '1' or (rx_timeout_in = '1' and rx_fifo_empty = '0') then
                    -- Cargar la cabeza (FWFT) y consumirla: en el ciclo siguiente
                    -- rx_fifo_empty dira si data_reg tiene sucesor.
                    data_next      <= rx_fifo_data_out;
                    rx_fifo_rd_out <= '1';
                    lvld_next      <= '0';   -- aun no se sabe si es el ultimo
                    cnt_next       <= (others=>'0');
                    if rx_timeout_in = '1' then
                        rx_timeout_ok <= '1';
                    end if;
                    next_state <= Drain;
                else
                    if rx_timeout_in = '1' then
                        rx_timeout_ok <= '1';
                    end if;
                    if (unsigned(rx_id_reg) = to_unsigned(N_CH - 1, 4)) then
                        rx_id_next <= (others=>'0');
                    else
                        rx_id_next <= std_logic_vector(unsigned(rx_id_reg) + 1);
                    end if;
                end if;

            when Drain =>
                m_axis_tvalid <= '1';
                m_axis_tdata  <= data_reg;
                m_axis_tdest  <= rx_id_reg;
                m_axis_tlast  <= is_last;

                -- Congelar la decision en cuanto el byte se ofrece.
                last_next <= is_last;
                lvld_next <= '1';

                if m_axis_tready = '1' then
                    lvld_next <= '0';        -- el proximo byte se juzga de nuevo
                    if is_last = '1' then
                        next_state <= Idle;
                        if (unsigned(rx_id_reg) = to_unsigned(N_CH - 1, 4)) then
                            rx_id_next <= (others=>'0');
                        else
                            rx_id_next <= std_logic_vector(unsigned(rx_id_reg) + 1);
                        end if;
                    else
                        data_next      <= rx_fifo_data_out;
                        rx_fifo_rd_out <= '1';
                        cnt_next       <= cnt_reg + 1;
                    end if;
                end if;

        end case;
    end process;

    -- Cierra el paquete si el byte ofrecido no tiene sucesor en la FIFO, o si con el
    -- se alcanza MAX_PKT. Una vez ofrecido (lvld_reg='1') el valor queda congelado.
    is_last <= last_reg when lvld_reg = '1' else
               '1'      when rx_fifo_empty = '1' else
               '1'      when cnt_reg = to_unsigned(MAX_PKT - 1, cnt_reg'length) else
               '0';

end Behavioral;
