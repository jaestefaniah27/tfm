# build_mcdma_bridge.tcl
# =========================================================================
# Crea un block design NUEVO ("system_mcdma") DENTRO del proyecto existente
# serial_bridge.xpr, con la arquitectura asimétrica pedida:
#
#   TX → 1 canal  : MCDMA MM2S (1 ch) → BRIDGE_MCDMA_TOP (TX_DMA_ROUTER por
#                   cabecera [ID|LEN][LEN][payload]) → 14 cores UART.
#   RX → N canales: cada core UART cierra su mensaje con su timeout real →
#                   RX_AXIS_MC etiqueta TDEST=canal + tlast → MCDMA S2MM
#                   (14 canales) → un buffer DDR por canal, sin mezclar.
#
# Reutiliza las IP fifo_tx / fifo_rx ya generadas en el proyecto y NO toca
# MULTI_SERIAL_CORE ni la IP empaquetada (instancia CONFIGURABLE_SERIAL_TOP
# directamente para acceder al pulso Timeout).
#
# Ejecución:
#   cd hardware
#   vivado -mode batch -source scripts/build_mcdma_bridge.tcl
# =========================================================================

set HW   "/home/mpsocv2/quick-start/app/serial_bridge/hardware"
set XPR  "$HW/serial_bridge/serial_bridge.xpr"
set N    14
set BD   "system_mcdma"

# Mapa de memoria (GP0)
set cfg_addr   0xA0000000   ;# AXI_UART_CONFIG
set txisr_addr 0xA0001000   ;# TX ISR (TX_DONE/IRQ)
set mcdma_addr 0xA0010000   ;# MCDMA registros de control (256K)

puts "=== Abriendo proyecto $XPR ==="
open_project $XPR

# -------------------------------------------------------------------------
# 1. Asegurar fuentes RTL (cores UART + nuevos top/arbitrador)
# -------------------------------------------------------------------------
proc ensure_file {f} {
    if {[llength [get_files -quiet [file tail $f]]] == 0} {
        puts "  + add_files $f"
        add_files -norecurse $f
    } else {
        puts "  = ya presente [file tail $f]"
    }
}
foreach f {
    src/CONFIGURABLE_SERIAL_TOP.vhd
    src/CONFIGURABLE_SERIAL.vhd
    src/RX_CONFIGURABLE_SERIAL.vhd
    src/TX_CONFIGURABLE_SERIAL.vhd
    src/NCO.vhd
    src/ShiftRegister.vhd
    serial_bridge/serial_bridge.srcs/sources_1/new/RX_AXIS_MC.vhd
    serial_bridge/serial_bridge.srcs/sources_1/new/BRIDGE_MCDMA.vhd
    serial_bridge/serial_bridge.srcs/sources_1/new/BRIDGE_MCDMA_TOP.vhd
} {
    ensure_file "$HW/$f"
}
update_compile_order -fileset sources_1

# -------------------------------------------------------------------------
# 2. Block design nuevo
# -------------------------------------------------------------------------
if {[llength [get_bd_designs -quiet $BD]] > 0} {
    close_bd_design [get_bd_designs $BD]
}
set existing_bd [get_files -quiet ${BD}.bd]
if {$existing_bd ne ""} {
    puts "-> BD $BD ya existe en disco: se elimina y recrea"
    set wrap [get_files -quiet ${BD}_wrapper.vhd]
    if {$wrap ne ""} { remove_files -quiet $wrap }
    remove_files -quiet $existing_bd
    file delete -force [file dirname $existing_bd]
}
create_bd_design $BD

# ── ZynqMP PS ──────────────────────────────────────────────────────────────
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
                    -config {apply_board_preset "1"} $ps
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__IRQ0      {1} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__USE__S_AXI_GP3 {1} \
] $ps

set sys_clk  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
set sys_rstn [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]

# ── Reset ──────────────────────────────────────────────────────────────────
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen]
connect_bd_net $sys_clk  [get_bd_pins rst_gen/slowest_sync_clk]
connect_bd_net $sys_rstn [get_bd_pins rst_gen/ext_reset_in]
set aresetn [get_bd_pins rst_gen/peripheral_aresetn]

# ── AXI MCDMA: 1 canal MM2S (TX) + 14 canales S2MM (RX) ─────────────────────
puts "-> AXI MCDMA (1 MM2S + 14 S2MM)..."
set mcdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_mcdma axi_mcdma_0]
set_property -dict [list \
    CONFIG.c_num_mm2s_channels     {1}  \
    CONFIG.c_num_s2mm_channels     {14} \
    CONFIG.c_include_mm2s          {1}  \
    CONFIG.c_include_s2mm          {1}  \
    CONFIG.c_enable_multi_intr     {0}  \
    CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axi_s2mm_data_width {32} \
] $mcdma
connect_bd_net $sys_clk [get_bd_pins axi_mcdma_0/s_axi_aclk]
connect_bd_net $sys_clk [get_bd_pins axi_mcdma_0/s_axi_lite_aclk]
connect_bd_net $aresetn [get_bd_pins axi_mcdma_0/axi_resetn]

# ── Conversores de ancho AXI-Stream (MCDMA 32b ↔ puente 8b) ────────────────
# MM2S: MCDMA (32) → dw 32→8 → puente
set dw_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 dw_mm2s]
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {4} CONFIG.M_TDATA_NUM_BYTES {1}] $dw_mm2s
# S2MM: puente (8, con TDEST/tlast) → dw 8→32 → MCDMA (32)
set dw_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 dw_s2mm]
set_property -dict [list CONFIG.S_TDATA_NUM_BYTES {1} CONFIG.M_TDATA_NUM_BYTES {4}] $dw_s2mm
foreach c {dw_mm2s dw_s2mm} {
    connect_bd_net $sys_clk [get_bd_pins $c/aclk]
    connect_bd_net $aresetn [get_bd_pins $c/aresetn]
}

# ── Puente (module reference) ──────────────────────────────────────────────
puts "-> BRIDGE_MCDMA_TOP..."
set br [create_bd_cell -type module -reference BRIDGE_MCDMA_TOP bridge_0]
connect_bd_net $sys_clk [get_bd_pins bridge_0/aclk]
connect_bd_net $aresetn [get_bd_pins bridge_0/aresetn]

# Streams: MCDMA MM2S → dw → bridge S_AXIS_TX ; bridge M_AXIS_RX → dw → MCDMA S2MM
connect_bd_intf_net [get_bd_intf_pins axi_mcdma_0/M_AXIS_MM2S] [get_bd_intf_pins dw_mm2s/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins dw_mm2s/M_AXIS]         [get_bd_intf_pins bridge_0/S_AXIS_TX]
connect_bd_intf_net [get_bd_intf_pins bridge_0/M_AXIS_RX]     [get_bd_intf_pins dw_s2mm/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins dw_s2mm/M_AXIS]         [get_bd_intf_pins axi_mcdma_0/S_AXIS_S2MM]

# ── SmartConnect GP0 → cfg + txisr + MCDMA ctrl ─────────────────────────────
set smc_cfg [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_config]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $smc_cfg
connect_bd_net $sys_clk [get_bd_pins smc_config/aclk]
connect_bd_net $aresetn [get_bd_pins smc_config/aresetn]
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins smc_config/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_config/M00_AXI] [get_bd_intf_pins bridge_0/S_AXI_CFG]
connect_bd_intf_net [get_bd_intf_pins smc_config/M01_AXI] [get_bd_intf_pins bridge_0/S_AXI_TXISR]
connect_bd_intf_net [get_bd_intf_pins smc_config/M02_AXI] [get_bd_intf_pins axi_mcdma_0/S_AXI_LITE]

# ── SmartConnect HP0: MM2S (+ SG) → DDR ─────────────────────────────────────
set sg_intf [get_bd_intf_pins -quiet axi_mcdma_0/M_AXI_SG]
set hp0_si [expr {($sg_intf ne "") ? 2 : 1}]
set smc_hp0 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp0]
set_property CONFIG.NUM_SI $hp0_si [get_bd_cells smc_hp0]
connect_bd_net $sys_clk [get_bd_pins smc_hp0/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp0/aresetn]
connect_bd_intf_net [get_bd_intf_pins axi_mcdma_0/M_AXI_MM2S] [get_bd_intf_pins smc_hp0/S00_AXI]
if {$sg_intf ne ""} {
    connect_bd_intf_net $sg_intf [get_bd_intf_pins smc_hp0/S01_AXI]
}
connect_bd_intf_net [get_bd_intf_pins smc_hp0/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]

# ── SmartConnect HP1: S2MM → DDR ────────────────────────────────────────────
set smc_hp1 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp1]
set_property CONFIG.NUM_SI {1} [get_bd_cells smc_hp1]
connect_bd_net $sys_clk [get_bd_pins smc_hp1/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp1/aresetn]
connect_bd_intf_net [get_bd_intf_pins axi_mcdma_0/M_AXI_S2MM] [get_bd_intf_pins smc_hp1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_hp1/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk]

# ── IRQ: mm2s_introut + s2mm_introut + EOAF → pl_ps_irq0 ────────────────────
set irqc [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat]
set_property CONFIG.NUM_PORTS 3 $irqc
connect_bd_net [get_bd_pins axi_mcdma_0/mm2s_introut] [get_bd_pins irq_concat/In0]
connect_bd_net [get_bd_pins axi_mcdma_0/s2mm_introut] [get_bd_pins irq_concat/In1]
connect_bd_net [get_bd_pins bridge_0/EOAF]            [get_bd_pins irq_concat/In2]
connect_bd_net [get_bd_pins irq_concat/dout]         [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# ── Puertos físicos serie (vectores de 14) ─────────────────────────────────
create_bd_port -dir O -from 13 -to 0 TD
create_bd_port -dir I -from 13 -to 0 RD
create_bd_port -dir O -from 13 -to 0 DE
create_bd_port -dir O -from 13 -to 0 SLO
connect_bd_net [get_bd_pins bridge_0/TD]  [get_bd_ports TD]
connect_bd_net [get_bd_ports RD]          [get_bd_pins bridge_0/RD]
connect_bd_net [get_bd_pins bridge_0/DE]  [get_bd_ports DE]
connect_bd_net [get_bd_pins bridge_0/SLO] [get_bd_ports SLO]

# ── Relojes huérfanos ──────────────────────────────────────────────────────
foreach pin_name {maxihpm1_fpd_aclk maxihpm0_lpd_aclk} {
    set p [get_bd_pins -quiet zynq_ultra_ps_e_0/$pin_name]
    if {$p ne "" && [get_bd_nets -quiet -of_objects $p] eq ""} {
        connect_bd_net $sys_clk $p
    }
}

# -------------------------------------------------------------------------
# 3. Mapa de memoria
# -------------------------------------------------------------------------
puts "-> Asignando direcciones..."
set seg "zynq_ultra_ps_e_0/Data"

proc assign_lite {seg space offset} {
    set s [get_bd_addr_segs -quiet $space]
    if {$s ne ""} {
        assign_bd_address -target_address_space $seg $s -force -offset $offset -range 4K
    }
}
assign_lite $seg "bridge_0/S_AXI_CFG/*"   [format 0x%08X $cfg_addr]
assign_lite $seg "bridge_0/S_AXI_TXISR/*" [format 0x%08X $txisr_addr]
assign_bd_address -target_address_space $seg \
    [get_bd_addr_segs axi_mcdma_0/S_AXI_LITE/Reg] \
    -force -offset [format 0x%08X $mcdma_addr] -range 64K

# MCDMA masters → DDR (asignar DDR_LOW y excluir no-DDR)
set hp0_non {HP0_QSPI HP0_PCIE_LOW HP0_PCIE_HIGH1 HP0_PCIE_HIGH2 HP0_LPS_OCM HP0_DDR_HIGH}
set hp1_non {HP1_QSPI HP1_PCIE_LOW HP1_PCIE_HIGH1 HP1_PCIE_HIGH2 HP1_LPS_OCM HP1_DDR_HIGH}
foreach sp {axi_mcdma_0/Data_SG axi_mcdma_0/Data_MM2S} {
    set ddr [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW]
    if {$ddr ne "" && [llength [get_bd_addr_spaces -quiet $sp]] > 0} {
        assign_bd_address -target_address_space $sp $ddr -force
        foreach name $hp0_non {
            set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/$name]
            if {$s ne ""} { exclude_bd_addr_seg $s -target_address_space $sp }
        }
    }
}
set ddr1 [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW]
if {$ddr1 ne "" && [llength [get_bd_addr_spaces -quiet axi_mcdma_0/Data_S2MM]] > 0} {
    assign_bd_address -target_address_space axi_mcdma_0/Data_S2MM $ddr1 -force
    foreach name $hp1_non {
        set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/$name]
        if {$s ne ""} { exclude_bd_addr_seg $s -target_address_space axi_mcdma_0/Data_S2MM }
    }
}

# -------------------------------------------------------------------------
# 4. Validar + wrapper
# -------------------------------------------------------------------------
puts "-> Validando..."
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_file [get_files ${BD}.bd]
set wrapper [make_wrapper -fileset sources_1 -files $bd_file -top]
add_files -norecurse -fileset sources_1 $wrapper
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " LISTO: block design '$BD' creado en serial_bridge.xpr"
puts "   TX → MCDMA MM2S (1 canal) → BRIDGE_MCDMA_TOP router"
puts "   RX → 14 canales S2MM (TDEST por canal, tlast por timeout)"
puts "   [format 0x%08X $cfg_addr]  AXI_UART_CONFIG"
puts "   [format 0x%08X $txisr_addr]  TX ISR (TX_DONE/IRQ)"
puts "   [format 0x%08X $mcdma_addr]  MCDMA ctrl (64K)"
puts "   IRQ pl_ps_irq0[0]=mm2s [1]=s2mm [2]=EOAF"
puts "================================================================"
