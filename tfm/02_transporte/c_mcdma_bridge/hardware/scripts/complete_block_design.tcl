# complete_block_design.tcl
# =============================================================================
# Construye el block design "design_1" del proyecto serial_bridge.
#
# Arquitectura:
#   ZynqMP PS  ←→  AXI DMA (simple, 8-bit)  ←→  BRIDGE_TOP
#                                                      ↕
#                                              BRIDGE_UART_ADAPTER
#                                                      ↕
#                                           MULTI_SERIAL_CORE (14 UARTs)
#                                                      ↕
#                                         Puertos físicos UART[13:0]
#
# Mapa de memoria:
#   0xA000_0000  AXI DMA (control)
#   0xA000_1000  BRIDGE_TOP TX ISR (s_axi_tx)
#   0xA000_2000  BRIDGE_TOP UART config (s_axi_cfg)
#
# IRQs → pl_ps_irq0[2:0]:
#   [0] mm2s_introut   [1] s2mm_introut   [2] EOAF
#
# Ejecución (desde hardware/):
#   vivado -mode batch -source scripts/complete_block_design.tcl
#   — o bien desde la consola Tcl de Vivado:
#   source scripts/complete_block_design.tcl
# =============================================================================

set script_dir [file dirname [info script]]
set hw_dir     [file normalize "$script_dir/.."]

# =============================================================================
# 1. Abrir proyecto
# =============================================================================
if { [catch {current_project} err] } {
    puts "-> Abriendo proyecto..."
    open_project "$hw_dir/serial_bridge/serial_bridge.xpr"
} else {
    puts "-> Proyecto ya abierto: [current_project]"
}

# =============================================================================
# 2. Registrar IP repo (multi_serial_core)
# =============================================================================
puts "-> Registrando IP repo..."
set ip_repo "$hw_dir/ip_repo"
set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog -rebuild -scan_changes

# =============================================================================
# 3. Añadir BRIDGE_UART_ADAPTER al proyecto (si no está ya)
# =============================================================================
set adapter_vhd \
    "$hw_dir/serial_bridge/serial_bridge.srcs/sources_1/new/BRIDGE_UART_ADAPTER.vhd"
if { ![file exists $adapter_vhd] } {
    error "No se encuentra $adapter_vhd. Ejecuta primero el script que lo genera."
}
if { [get_files -quiet $adapter_vhd] eq "" } {
    puts "-> Añadiendo BRIDGE_UART_ADAPTER.vhd..."
    add_files $adapter_vhd
    update_compile_order -fileset sources_1
}

# =============================================================================
# 4. Eliminar BD existente y empezar de cero
# =============================================================================
puts "-> Eliminando block design previo (si existe)..."
catch { close_bd_design [get_bd_designs -quiet design_1] }
set old_bd [get_files -quiet design_1.bd]
if { $old_bd ne "" } {
    remove_files $old_bd
}

puts "-> Creando block design 'design_1'..."
create_bd_design "design_1"

# =============================================================================
# 5. ZynqMP PS — preset de la placa ZCU102
# =============================================================================
puts "-> Añadiendo ZynqMP PS con preset ZCU102..."
set ps [create_bd_cell -type ip \
            -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
                    -config {apply_board_preset "1"} $ps

set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__USE__S_AXI_GP3 {1} \
    CONFIG.PSU__USE__IRQ0      {1} \
] $ps

set sys_clk  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
set sys_rstn [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

# Reloj del master GP0
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]

# =============================================================================
# 6. Reset del sistema
# =============================================================================
puts "-> Añadiendo reset..."
create_bd_cell -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
connect_bd_net $sys_clk  [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net $sys_rstn [get_bd_pins proc_sys_reset_0/ext_reset_in]
set aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

# =============================================================================
# 7. AXI DMA simple (8-bit streams, sin Scatter-Gather)
# =============================================================================
puts "-> Añadiendo AXI DMA (simple, 8-bit)..."
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma axi_dma_0
set_property -dict [list \
    CONFIG.c_include_sg              {0}  \
    CONFIG.c_m_axis_mm2s_tdata_width {8}  \
    CONFIG.c_s_axis_s2mm_tdata_width {8}  \
    CONFIG.c_mm2s_burst_size         {16} \
    CONFIG.c_s2mm_burst_size         {16} \
    CONFIG.c_addr_width              {32} \
] [get_bd_cells axi_dma_0]

connect_bd_net $sys_clk [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net $sys_clk [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net $sys_clk [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net $aresetn [get_bd_pins axi_dma_0/axi_resetn]

# =============================================================================
# 8. BRIDGE_TOP (módulo RTL)
# =============================================================================
puts "-> Añadiendo BRIDGE_TOP..."
create_bd_cell -type module -reference BRIDGE_TOP BRIDGE_TOP_0
connect_bd_net $sys_clk [get_bd_pins BRIDGE_TOP_0/aclk]
connect_bd_net $aresetn [get_bd_pins BRIDGE_TOP_0/aresetn]

# =============================================================================
# 9. BRIDGE_UART_ADAPTER (módulo RTL — glue entre BRIDGE_TOP y MSC)
# =============================================================================
puts "-> Añadiendo BRIDGE_UART_ADAPTER..."
create_bd_cell -type module -reference BRIDGE_UART_ADAPTER BRIDGE_UART_ADAPTER_0

# =============================================================================
# 10. MULTI_SERIAL_CORE (IP empaquetado, 14 canales)
# =============================================================================
puts "-> Añadiendo MULTI_SERIAL_CORE (14 canales)..."
create_bd_cell -type ip -vlnv lince.com:user:multi_serial_core:1.0 multi_serial_core_0
set_property -dict [list \
    CONFIG.N       {14}    \
    CONFIG.USE_DE  {true}  \
    CONFIG.USE_SLO {true}  \
] [get_bd_cells multi_serial_core_0]

connect_bd_net $sys_clk [get_bd_pins multi_serial_core_0/clk]
connect_bd_net $aresetn [get_bd_pins multi_serial_core_0/aresetn]

# =============================================================================
# 11. SmartConnect de control: PS GP0 → DMA + BRIDGE_TOP(×2 AXI-Lite)
# =============================================================================
puts "-> Creando SmartConnect de control (1→3)..."
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_ctrl
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] \
    [get_bd_cells smc_ctrl]
connect_bd_net $sys_clk [get_bd_pins smc_ctrl/aclk]
connect_bd_net $aresetn [get_bd_pins smc_ctrl/aresetn]

connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins smc_ctrl/S00_AXI]

# M00 → DMA control
connect_bd_intf_net [get_bd_intf_pins smc_ctrl/M00_AXI] \
                    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

# M01 → BRIDGE_TOP TX ISR
connect_bd_intf_net [get_bd_intf_pins smc_ctrl/M01_AXI] \
                    [get_bd_intf_pins BRIDGE_TOP_0/s_axi_tx]

# M02 → BRIDGE_TOP UART config
connect_bd_intf_net [get_bd_intf_pins smc_ctrl/M02_AXI] \
                    [get_bd_intf_pins BRIDGE_TOP_0/s_axi_cfg]

# =============================================================================
# 12. SmartConnect HP0: DMA MM2S → PS DDR (lectura TX)
# =============================================================================
puts "-> Creando SmartConnect HP0 (MM2S → DDR)..."
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp0
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] \
    [get_bd_cells smc_hp0]
connect_bd_net $sys_clk [get_bd_pins smc_hp0/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp0/aresetn]

connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] \
                    [get_bd_intf_pins smc_hp0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_hp0/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]

# =============================================================================
# 13. SmartConnect HP1: DMA S2MM → PS DDR (escritura RX)
# =============================================================================
puts "-> Creando SmartConnect HP1 (S2MM → DDR)..."
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp1
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] \
    [get_bd_cells smc_hp1]
connect_bd_net $sys_clk [get_bd_pins smc_hp1/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp1/aresetn]

connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] \
                    [get_bd_intf_pins smc_hp1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_hp1/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk]

# =============================================================================
# 14. AXI-Stream: DMA ↔ BRIDGE_TOP
# =============================================================================
puts "-> Conectando AXI-Stream DMA ↔ BRIDGE_TOP..."
# TX: DMA MM2S → BRIDGE_TOP s_axis
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] \
                    [get_bd_intf_pins BRIDGE_TOP_0/s_axis]
# RX: BRIDGE_TOP m_axis → DMA S2MM
connect_bd_intf_net [get_bd_intf_pins BRIDGE_TOP_0/m_axis] \
                    [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# =============================================================================
# 15. BRIDGE_TOP ↔ BRIDGE_UART_ADAPTER (bus lateral de señales UART)
# =============================================================================
puts "-> Conectando BRIDGE_TOP ↔ BRIDGE_UART_ADAPTER..."

# TX path: BRIDGE_TOP → ADAPTER
connect_bd_net [get_bd_pins BRIDGE_TOP_0/tx_din]     \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/tx_din]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/tx_send]    \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/tx_send]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/rx_fifo_rd] \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/rx_fifo_rd]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/baud_sel]   \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/baud_sel]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/stop_bit]   \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/stop_bit]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/parity]     \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/parity]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/data_bits]  \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/data_bits]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/bit_order]  \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/bit_order]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/slo]        \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/slo_cfg]

# RX path: ADAPTER → BRIDGE_TOP
connect_bd_net [get_bd_pins BRIDGE_UART_ADAPTER_0/rx_fifo_dout]  \
               [get_bd_pins BRIDGE_TOP_0/rx_fifo_dout]
connect_bd_net [get_bd_pins BRIDGE_UART_ADAPTER_0/rx_fifo_empty] \
               [get_bd_pins BRIDGE_TOP_0/rx_fifo_empty]
connect_bd_net [get_bd_pins BRIDGE_UART_ADAPTER_0/send_ok]       \
               [get_bd_pins BRIDGE_TOP_0/send_ok]
connect_bd_net [get_bd_pins BRIDGE_UART_ADAPTER_0/tx_rdy]        \
               [get_bd_pins BRIDGE_TOP_0/tx_rdy]
connect_bd_net [get_bd_pins BRIDGE_UART_ADAPTER_0/timeout]       \
               [get_bd_pins BRIDGE_TOP_0/timeout]

# =============================================================================
# 16. BRIDGE_UART_ADAPTER ↔ MULTI_SERIAL_CORE
# =============================================================================
puts "-> Conectando BRIDGE_UART_ADAPTER ↔ MULTI_SERIAL_CORE..."
connect_bd_net [get_bd_pins BRIDGE_UART_ADAPTER_0/ps_config]  \
               [get_bd_pins multi_serial_core_0/ps_config]
connect_bd_net [get_bd_pins multi_serial_core_0/ps_out]       \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/ps_out]
connect_bd_net [get_bd_pins multi_serial_core_0/tx_rdy_empty] \
               [get_bd_pins BRIDGE_UART_ADAPTER_0/tx_rdy_empty]

# =============================================================================
# 17. IRQs → PS pl_ps_irq0[2:0]
#   [0] DMA MM2S   [1] DMA S2MM   [2] BRIDGE_TOP EOAF
# =============================================================================
puts "-> Conectando IRQs al PS..."
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat
set_property CONFIG.NUM_PORTS {3} [get_bd_cells irq_concat]
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut]  \
               [get_bd_pins irq_concat/In0]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut]  \
               [get_bd_pins irq_concat/In1]
connect_bd_net [get_bd_pins BRIDGE_TOP_0/EOAF]       \
               [get_bd_pins irq_concat/In2]
connect_bd_net [get_bd_pins irq_concat/dout]          \
               [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# =============================================================================
# 18. Puertos físicos UART (vectores de 14 bits)
# =============================================================================
puts "-> Creando puertos físicos UART[13:0]..."
create_bd_port -dir I -from 13 -to 0 UART_RX
create_bd_port -dir O -from 13 -to 0 UART_TX
create_bd_port -dir O -from 13 -to 0 UART_DE
create_bd_port -dir O -from 13 -to 0 UART_SLO

connect_bd_net [get_bd_ports UART_RX]               [get_bd_pins multi_serial_core_0/RD]
connect_bd_net [get_bd_pins multi_serial_core_0/TD]  [get_bd_ports UART_TX]
connect_bd_net [get_bd_pins multi_serial_core_0/DE]  [get_bd_ports UART_DE]
connect_bd_net [get_bd_pins multi_serial_core_0/SLO] [get_bd_ports UART_SLO]

# =============================================================================
# 19. Relojes huérfanos del PS (fix de robustez)
# =============================================================================
foreach pin_name {maxihpm1_fpd_aclk maxihpm0_lpd_aclk} {
    set p [get_bd_pins -quiet zynq_ultra_ps_e_0/$pin_name]
    if { $p ne "" && [get_bd_nets -quiet -of_objects $p] eq "" } {
        connect_bd_net $sys_clk $p
    }
}

# =============================================================================
# 20. Mapa de memoria
# =============================================================================
puts "-> Asignando mapa de memoria..."
set seg "zynq_ultra_ps_e_0/Data"

# --- DMA control ---
assign_bd_address \
    -target_address_space $seg \
    [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] \
    -force -offset 0xA0000000 -range 4K

# --- BRIDGE_TOP TX ISR (s_axi_tx, dir 4-bit) ---
set tx_segs [get_bd_addr_segs -quiet "BRIDGE_TOP_0/s_axi_tx/*"]
if { $tx_segs ne "" } {
    assign_bd_address -target_address_space $seg $tx_segs \
        -force -offset 0xA0001000 -range 4K
} else {
    puts "WARNING: Segmento BRIDGE_TOP_0/s_axi_tx no encontrado — omitido"
}

# --- BRIDGE_TOP UART config (s_axi_cfg, dir 6-bit) ---
set cfg_segs [get_bd_addr_segs -quiet "BRIDGE_TOP_0/s_axi_cfg/*"]
if { $cfg_segs ne "" } {
    assign_bd_address -target_address_space $seg $cfg_segs \
        -force -offset 0xA0002000 -range 4K
} else {
    puts "WARNING: Segmento BRIDGE_TOP_0/s_axi_cfg no encontrado — omitido"
}

# --- DMA masters → DDR (HP0: MM2S, HP1: S2MM) ---
set hp0_non {HP0_QSPI HP0_PCIE_LOW HP0_PCIE_HIGH1 HP0_PCIE_HIGH2 HP0_LPS_OCM HP0_DDR_HIGH}
set hp1_non {HP1_QSPI HP1_PCIE_LOW HP1_PCIE_HIGH1 HP1_PCIE_HIGH2 HP1_LPS_OCM HP1_DDR_HIGH}

set ddr0 [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW]
set ddr1 [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW]

if { $ddr0 ne "" } {
    assign_bd_address -target_address_space axi_dma_0/Data_MM2S $ddr0 -force
}
foreach name $hp0_non {
    set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/$name]
    if { $s ne "" } { exclude_bd_addr_seg $s -target_address_space axi_dma_0/Data_MM2S }
}

if { $ddr1 ne "" } {
    assign_bd_address -target_address_space axi_dma_0/Data_S2MM $ddr1 -force
}
foreach name $hp1_non {
    set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/$name]
    if { $s ne "" } { exclude_bd_addr_seg $s -target_address_space axi_dma_0/Data_S2MM }
}

# =============================================================================
# 21. Validar, guardar y generar wrapper
# =============================================================================
puts "-> Validando block design..."
validate_bd_design
save_bd_design

set bd_file      [get_files design_1.bd]
set wrapper_path [make_wrapper -fileset sources_1 -files $bd_file -top]
add_files -norecurse -fileset sources_1 $wrapper_path
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " BLOCK DESIGN COMPLETADO: design_1"
puts ""
puts " Mapa de memoria:"
puts "   0xA000_0000  AXI DMA (registros de control)"
puts "   0xA000_1000  BRIDGE_TOP TX ISR (s_axi_tx)"
puts "   0xA000_2000  BRIDGE_TOP UART config (s_axi_cfg)"
puts ""
puts " IRQs → pl_ps_irq0:"
puts "   [0] mm2s_introut  — DMA TX finalizado"
puts "   [1] s2mm_introut  — DMA RX disponible"
puts "   [2] EOAF          — BRIDGE_TOP: lote TX completado"
puts ""
puts " Puertos externos (vectores 14 bits):"
puts "   UART_RX[13:0]   entradas serie"
puts "   UART_TX[13:0]   salidas serie"
puts "   UART_DE[13:0]   driver enable (RS485)"
puts "   UART_SLO[13:0]  modo lento"
puts ""
puts " Siguiente paso: Generate Bitstream"
puts "================================================================"
