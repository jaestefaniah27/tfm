# =============================================================
#  Constraints - 4 drivers (test simple DMA)
#  Drivers 0-3 del bus RS485 A
#  IOSTANDARD: LVCMOS18
# =============================================================

# --- Driver0 ---
set_property PACKAGE_PIN T11  [get_ports { UART_0_TX  }]
set_property PACKAGE_PIN K15  [get_ports { UART_0_RX  }]
set_property PACKAGE_PIN L10  [get_ports { UART_0_SLO }]
set_property PACKAGE_PIN V11  [get_ports { UART_0_DE  }]

# --- Driver1 ---
set_property PACKAGE_PIN V12  [get_ports { UART_1_TX  }]
set_property PACKAGE_PIN U6   [get_ports { UART_1_RX  }]
set_property PACKAGE_PIN U11  [get_ports { UART_1_SLO }]
set_property PACKAGE_PIN M10  [get_ports { UART_1_DE  }]

# --- Driver2 ---
set_property PACKAGE_PIN V6   [get_ports { UART_2_TX  }]
set_property PACKAGE_PIN L15  [get_ports { UART_2_RX  }]
set_property PACKAGE_PIN V7   [get_ports { UART_2_SLO }]
set_property PACKAGE_PIN V8   [get_ports { UART_2_DE  }]

# --- Driver3 ---
set_property PACKAGE_PIN U8   [get_ports { UART_3_TX  }]
set_property PACKAGE_PIN U9   [get_ports { UART_3_RX  }]
set_property PACKAGE_PIN T6   [get_ports { UART_3_SLO }]
set_property PACKAGE_PIN T7   [get_ports { UART_3_DE  }]

set_property IOSTANDARD LVCMOS18 [get_ports { UART_* }]
