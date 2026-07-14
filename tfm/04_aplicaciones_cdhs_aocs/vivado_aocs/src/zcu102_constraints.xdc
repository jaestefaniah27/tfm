# =========================================================================
# Constraints ZCU102 - Proyecto AOCS
# Señales mapeadas según signals_table.html (FMC HPC0)
# =========================================================================

# -------------------------------------------------------------------------
# RS1 (Serial J1) / UART_0
#   TX  -> FMC_HPC0_LA20_N (G22) -> M13
#   RX  -> FMC_HPC0_LA20_P (G21) -> N13
#   DE  -> FMC_HPC0_LA19_P (H22) -> L13
# -------------------------------------------------------------------------
set_property PACKAGE_PIN M13 [get_ports UART_0_TX]
set_property PACKAGE_PIN N13 [get_ports UART_0_RX]
set_property PACKAGE_PIN L13 [get_ports UART_0_DE]

# -------------------------------------------------------------------------
# RS3 (Serial J3) / UART_1
#   TX  -> FMC_HPC0_LA11_N (H17) -> AB5
#   RX  -> FMC_HPC0_LA12_P (G15) -> W7
#   DE  -> FMC_HPC0_LA11_P (H16) -> AB6
# -------------------------------------------------------------------------
set_property PACKAGE_PIN AB5 [get_ports UART_1_TX]
set_property PACKAGE_PIN W7  [get_ports UART_1_RX]
set_property PACKAGE_PIN AB6 [get_ports UART_1_DE]

# -------------------------------------------------------------------------
# RS4 (Serial J4) / UART_2
#   TX  -> FMC_HPC0_LA09_P (D14) -> W2
#   RX  -> FMC_HPC0_LA08_N (G13) -> V3
#   DE  -> FMC_HPC0_LA07_N (H14) -> U4
# -------------------------------------------------------------------------
set_property PACKAGE_PIN W2 [get_ports UART_2_TX]
set_property PACKAGE_PIN V3 [get_ports UART_2_RX]
set_property PACKAGE_PIN U4 [get_ports UART_2_DE]

# -------------------------------------------------------------------------
# RS5 (Serial J5) / UART_3
#   TX  -> FMC_HPC0_LA07_P (H13) -> U5
#   RX  -> FMC_HPC0_LA05_P (D11) -> AB3
#   DE  -> FMC_HPC0_LA08_P (G12) -> V4
# -------------------------------------------------------------------------
set_property PACKAGE_PIN U5  [get_ports UART_3_TX]
set_property PACKAGE_PIN AB3 [get_ports UART_3_RX]
set_property PACKAGE_PIN V4  [get_ports UART_3_DE]

# -------------------------------------------------------------------------
# RS8 (Serial J8) / UART_4
#   TX  -> FMC_HPC0_LA22_N (G25) -> M14
#   RX  -> FMC_HPC0_LA19_N (H23) -> K13
#   DE  -> FMC_HPC0_LA22_P (G24) -> M15
# -------------------------------------------------------------------------
set_property PACKAGE_PIN M14 [get_ports UART_4_TX]
set_property PACKAGE_PIN K13 [get_ports UART_4_RX]
set_property PACKAGE_PIN M15 [get_ports UART_4_DE]

# -------------------------------------------------------------------------
# IOSTANDARD para todas las UART (FMC HPC0, Banco 65/66 = LVCMOS18)
# -------------------------------------------------------------------------
set_property IOSTANDARD LVCMOS18 [get_ports {UART_*}]

# -------------------------------------------------------------------------
# MOT-PWM (Motor J2) - 6 señales PWM para Puentes en H
# -------------------------------------------------------------------------
set_property PACKAGE_PIN N11  [get_ports pwm_x_1]
set_property PACKAGE_PIN Y9   [get_ports pwm_x_2]
set_property PACKAGE_PIN AA12 [get_ports pwm_y_1]
set_property PACKAGE_PIN Y10  [get_ports pwm_y_2]
set_property PACKAGE_PIN Y12  [get_ports pwm_z_1]
set_property PACKAGE_PIN AC8  [get_ports pwm_z_2]
set_property IOSTANDARD LVCMOS18 [get_ports {pwm_*}]

# -------------------------------------------------------------------------
# TODO: SpaceWire (SPW1 J6, SPW2 J7) - pines diferencial
# -------------------------------------------------------------------------

# ===========================================================================
# 8 INTERRUPTORES SW13 (Banco 44 a 3.3V)
# ===========================================================================
set_property PACKAGE_PIN AN14 [get_ports {sw_user[0]}]
set_property PACKAGE_PIN AP14 [get_ports {sw_user[1]}]
set_property PACKAGE_PIN AM14 [get_ports {sw_user[2]}]
set_property PACKAGE_PIN AN13 [get_ports {sw_user[3]}]
set_property PACKAGE_PIN AN12 [get_ports {sw_user[4]}]
set_property PACKAGE_PIN AP12 [get_ports {sw_user[5]}]
set_property PACKAGE_PIN AL13 [get_ports {sw_user[6]}]
set_property PACKAGE_PIN AK13 [get_ports {sw_user[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_user[*]}]

# ===========================================================================
# 8 LEDS DE USUARIO (Banco 44 a 3.3V)
# ===========================================================================
set_property PACKAGE_PIN AG14 [get_ports {ld_user[0]}]
set_property PACKAGE_PIN AF13 [get_ports {ld_user[1]}]
set_property PACKAGE_PIN AE13 [get_ports {ld_user[2]}]
set_property PACKAGE_PIN AJ14 [get_ports {ld_user[3]}]
set_property PACKAGE_PIN AJ15 [get_ports {ld_user[4]}]
set_property PACKAGE_PIN AH13 [get_ports {ld_user[5]}]
set_property PACKAGE_PIN AH14 [get_ports {ld_user[6]}]
set_property PACKAGE_PIN AL12 [get_ports {ld_user[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ld_user[*]}]