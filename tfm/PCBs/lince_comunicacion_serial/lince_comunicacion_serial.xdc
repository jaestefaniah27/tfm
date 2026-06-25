# =============================================================
#  Constraints — 14 drivers RS-485
#  TX / RX / SLO / DE (drivers con DE hardcodeado no aparecen)
#  Conector: P2  |  IOSTANDARD: LVCMOS18
#  Generado automáticamente por generate_xdc.py
# =============================================================

# --- Driver0 ---
set_property PACKAGE_PIN T11      [get_ports { UART_0_TX }]
set_property PACKAGE_PIN K15      [get_ports { UART_0_RX }]
set_property PACKAGE_PIN L10      [get_ports { UART_0_SLO }]
set_property PACKAGE_PIN V11      [get_ports { UART_0_DE }]

# --- Driver1 ---
set_property PACKAGE_PIN V12      [get_ports { UART_1_TX }]
set_property PACKAGE_PIN U6       [get_ports { UART_1_RX }]
set_property PACKAGE_PIN U11      [get_ports { UART_1_SLO }]
set_property PACKAGE_PIN M10      [get_ports { UART_1_DE }]

# --- Driver2 ---
set_property PACKAGE_PIN V6       [get_ports { UART_2_TX }]
set_property PACKAGE_PIN L15      [get_ports { UART_2_RX }]
set_property PACKAGE_PIN V7       [get_ports { UART_2_SLO }]
set_property PACKAGE_PIN V8       [get_ports { UART_2_DE }]

# --- Driver3 ---
set_property PACKAGE_PIN U8       [get_ports { UART_3_TX }]
set_property PACKAGE_PIN U9       [get_ports { UART_3_RX }]
set_property PACKAGE_PIN T6       [get_ports { UART_3_SLO }]
set_property PACKAGE_PIN T7       [get_ports { UART_3_DE }]

# --- Driver4 ---
set_property PACKAGE_PIN AC7      [get_ports { UART_4_TX }]
set_property PACKAGE_PIN AC8      [get_ports { UART_4_RX }]
set_property PACKAGE_PIN M15      [get_ports { UART_4_SLO }]
set_property PACKAGE_PIN K13      [get_ports { UART_4_DE }]

# --- Driver5 ---
set_property PACKAGE_PIN M13      [get_ports { UART_5_TX }]
set_property PACKAGE_PIN Y9       [get_ports { UART_5_RX }]
set_property PACKAGE_PIN L13      [get_ports { UART_5_SLO }]
set_property PACKAGE_PIN N13      [get_ports { UART_5_DE }]

# --- Driver6 ---
set_property PACKAGE_PIN Y10      [get_ports { UART_6_TX }]
set_property PACKAGE_PIN AB8      [get_ports { UART_6_RX }]
set_property PACKAGE_PIN AA12     [get_ports { UART_6_SLO }]
set_property PACKAGE_PIN Y12      [get_ports { UART_6_DE }]

# --- Driver7 ---
set_property PACKAGE_PIN AC2      [get_ports { UART_7_TX }]
set_property PACKAGE_PIN AC4      [get_ports { UART_7_RX }]
set_property PACKAGE_PIN AB4      [get_ports { UART_7_SLO }]
# DE7: hardcodeado en HW (sin pin en P2)

# --- Driver8 ---
set_property PACKAGE_PIN AB3      [get_ports { UART_8_TX }]
set_property PACKAGE_PIN AC3      [get_ports { UART_8_RX }]
set_property PACKAGE_PIN AC1      [get_ports { UART_8_SLO }]
set_property PACKAGE_PIN W5       [get_ports { UART_8_DE }]

# --- Driver9 ---
set_property PACKAGE_PIN V2       [get_ports { UART_9_TX }]
set_property PACKAGE_PIN Y3       [get_ports { UART_9_RX }]
set_property PACKAGE_PIN Y4       [get_ports { UART_9_SLO }]
set_property PACKAGE_PIN V1       [get_ports { UART_9_DE }]

# --- Driver10 ---
set_property PACKAGE_PIN W2       [get_ports { UART_10_TX }]
set_property PACKAGE_PIN Y1       [get_ports { UART_10_RX }]
set_property PACKAGE_PIN Y2       [get_ports { UART_10_SLO }]
set_property PACKAGE_PIN AA2      [get_ports { UART_10_DE }]

# --- Driver11 ---
set_property PACKAGE_PIN V3       [get_ports { UART_11_TX }]
set_property PACKAGE_PIN V4       [get_ports { UART_11_RX }]
set_property PACKAGE_PIN AA1      [get_ports { UART_11_SLO }]
# DE11: hardcodeado en HW (sin pin en P2)

# --- Driver12 ---
set_property PACKAGE_PIN W4       [get_ports { UART_12_TX }]
set_property PACKAGE_PIN U4       [get_ports { UART_12_RX }]
set_property PACKAGE_PIN U5       [get_ports { UART_12_SLO }]
set_property PACKAGE_PIN W1       [get_ports { UART_12_DE }]

# --- Driver13 ---
set_property PACKAGE_PIN AB5      [get_ports { UART_13_TX }]
set_property PACKAGE_PIN AB6      [get_ports { UART_13_RX }]
set_property PACKAGE_PIN W7       [get_ports { UART_13_SLO }]
set_property PACKAGE_PIN W6       [get_ports { UART_13_DE }]

# --- IOSTANDARD global ---
set_property IOSTANDARD LVCMOS18 [get_ports { UART_* }]
