----------------------------------------------------------------------------------
-- BRIDGE_UART_ADAPTER
--
-- Convierte entre la interfaz "plana" de BRIDGE_TOP y el bus ps_config/ps_out
-- de MULTI_SERIAL_CORE (que a su vez encapsula N instancias de
-- CONFIGURABLE_SERIAL_TOP).
--
-- Mapeado de PS_SERIAL_CONFIG (28 bits/canal):
--   [8:0]   = tx_din      (Data_in, 9 bits)
--   [9]     = tx_send     (TX_Send)
--   [10]    = '0'         (ERROR_OK — sin ACK de error desde el bridge)
--   [11]    = rx_fifo_rd  (Data_read)
--   [17:12] = baud_sel    (6 bits)
--   [19:18] = stop_bit    (2 bits)
--   [22:20] = parity      (3 bits)
--   [25:23] = data_bits   (3 bits)
--   [26]    = bit_order
--   [27]    = slo_cfg     (modo SLO)
--
-- Mapeado de PS_out (14 bits/canal):
--   [8:0]  = Data_out (RX, 9 bits; usamos solo [7:0])
--   [9]    = EMPTY_sig
--   [10]   = FULL
--   [11]   = PAR_ERROR
--   [12]   = FRAME_ERROR
--   [13]   = TX_RDY_sig
--
-- timeout[i]: se activa cuando el canal tiene datos (NOT EMPTY).
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity BRIDGE_UART_ADAPTER is
  generic (
    N_CH : integer := 14
  );
  port (
    -- ── Desde BRIDGE_TOP → hacia los cores UART ──────────────────────────────
    tx_din     : in  std_logic_vector(N_CH*9 - 1 downto 0);
    tx_send    : in  std_logic_vector(N_CH   - 1 downto 0);
    rx_fifo_rd : in  std_logic_vector(N_CH   - 1 downto 0);
    baud_sel   : in  std_logic_vector(N_CH*6 - 1 downto 0);
    stop_bit   : in  std_logic_vector(N_CH*2 - 1 downto 0);
    parity     : in  std_logic_vector(N_CH*3 - 1 downto 0);
    data_bits  : in  std_logic_vector(N_CH*3 - 1 downto 0);
    bit_order  : in  std_logic_vector(N_CH   - 1 downto 0);
    slo_cfg    : in  std_logic_vector(N_CH   - 1 downto 0);

    -- ── Hacia MULTI_SERIAL_CORE ───────────────────────────────────────────────
    ps_config    : out std_logic_vector(N_CH*28 - 1 downto 0);

    -- ── Desde MULTI_SERIAL_CORE ──────────────────────────────────────────────
    ps_out       : in  std_logic_vector(N_CH*14 - 1 downto 0);
    tx_rdy_empty : in  std_logic_vector(N_CH*2  - 1 downto 0);

    -- ── Hacia BRIDGE_TOP ← desde los cores UART ─────────────────────────────
    rx_fifo_dout  : out std_logic_vector(N_CH*8 - 1 downto 0);
    rx_fifo_empty : out std_logic_vector(N_CH   - 1 downto 0);
    send_ok       : out std_logic_vector(N_CH   - 1 downto 0);
    tx_rdy        : out std_logic_vector(N_CH   - 1 downto 0);
    timeout       : out std_logic_vector(N_CH   - 1 downto 0)
  );
end BRIDGE_UART_ADAPTER;

architecture RTL of BRIDGE_UART_ADAPTER is
begin

  gen_ch: for i in 0 to N_CH-1 generate

    -- ── Empaquetar ps_config del canal i ─────────────────────────────────────
    ps_config(i*28 +  8 downto i*28 +  0) <= tx_din(i*9 + 8 downto i*9);
    ps_config(i*28 +  9)                   <= tx_send(i);
    ps_config(i*28 + 10)                   <= '0';         -- ERROR_OK
    ps_config(i*28 + 11)                   <= rx_fifo_rd(i);
    ps_config(i*28 + 17 downto i*28 + 12)  <= baud_sel(i*6 + 5 downto i*6);
    ps_config(i*28 + 19 downto i*28 + 18)  <= stop_bit(i*2 + 1 downto i*2);
    ps_config(i*28 + 22 downto i*28 + 20)  <= parity(i*3 + 2 downto i*3);
    ps_config(i*28 + 25 downto i*28 + 23)  <= data_bits(i*3 + 2 downto i*3);
    ps_config(i*28 + 26)                   <= bit_order(i);
    ps_config(i*28 + 27)                   <= slo_cfg(i);

    -- ── Desempaquetar ps_out del canal i ─────────────────────────────────────
    -- rx_fifo_dout: 8 bits (ps_out[7:0] = Data_out[7:0])
    rx_fifo_dout(i*8 + 7 downto i*8) <= ps_out(i*14 + 7 downto i*14);
    -- rx_fifo_empty: EMPTY_sig (bit 9 de ps_out del canal)
    rx_fifo_empty(i)                  <= ps_out(i*14 + 9);
    -- send_ok y tx_rdy: TX_RDY_sig (bit 1 de tx_rdy_empty del canal)
    send_ok(i)                        <= tx_rdy_empty(i*2 + 1);
    tx_rdy(i)                         <= tx_rdy_empty(i*2 + 1);
    -- timeout: activo cuando el canal tiene datos (NOT EMPTY)
    timeout(i)                        <= not ps_out(i*14 + 9);

  end generate;

end RTL;
