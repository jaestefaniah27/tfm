# -------------------------------------------------------------------------
# SPI (ADC)
# -------------------------------------------------------------------------
set_property PACKAGE_PIN V1 [get_ports SPI_MISO]
set_property PACKAGE_PIN Y3 [get_ports SPI_MOSI]
set_property PACKAGE_PIN V2 [get_ports SPI_SCLK]
set_property PACKAGE_PIN Y4 [get_ports SPI_CS_N]

# -------------------------------------------------------------------------
# CAN Nominal
# -------------------------------------------------------------------------
set_property PACKAGE_PIN P12 [get_ports CAN_TX_N]
set_property PACKAGE_PIN M15 [get_ports CAN_RX_N]

# -------------------------------------------------------------------------
# CAN Redundante
# -------------------------------------------------------------------------
set_property PACKAGE_PIN N12 [get_ports CAN_TX_R]
set_property PACKAGE_PIN M14 [get_ports CAN_RX_R]

# -------------------------------------------------------------------------
# RS1 (Serial 1) / UART_0 
# -------------------------------------------------------------------------
set_property PACKAGE_PIN Y10 [get_ports UART_0_TX]
set_property PACKAGE_PIN AB5 [get_ports UART_0_RX]
set_property PACKAGE_PIN Y12 [get_ports UART_0_DE]

# -------------------------------------------------------------------------
# RS2 (Serial 2) / UART_1
# -------------------------------------------------------------------------
set_property PACKAGE_PIN W6 [get_ports UART_1_TX]
set_property PACKAGE_PIN W7 [get_ports UART_1_RX]
set_property PACKAGE_PIN AB6 [get_ports UART_1_DE]

# -------------------------------------------------------------------------
# RS3 (Serial 3) / UART_2
# -------------------------------------------------------------------------
set_property PACKAGE_PIN U4 [get_ports UART_2_TX]
set_property PACKAGE_PIN U5 [get_ports UART_2_RX]
set_property PACKAGE_PIN V3 [get_ports UART_2_DE]

# -------------------------------------------------------------------------
# PWM (Heaters)
# -------------------------------------------------------------------------
set_property PACKAGE_PIN AA1 [get_ports PWM_0]
set_property PACKAGE_PIN AA2 [get_ports PWM_1]
set_property PACKAGE_PIN Y2  [get_ports PWM_2]
set_property PACKAGE_PIN Y1  [get_ports PWM_3]

# -------------------------------------------------------------------------
# IOSTANDARD LVCMOS18 para todos los puertos FMC 
# -------------------------------------------------------------------------
set_property IOSTANDARD LVCMOS18 [get_ports SPI_*]
set_property IOSTANDARD LVCMOS18 [get_ports CAN_*]
set_property IOSTANDARD LVCMOS18 [get_ports UART_*]
set_property IOSTANDARD LVCMOS18 [get_ports PWM_*]