# simple_dma14_system.tcl
# =========================================================================
# Diseño PCB: 14 canales UART, cada uno con su AXI DMA simple (PG021).
# SIN loopback — para la PCB con los buses RS485 físicos.
#
# Topología física de la PCB:
#   Bus A (RS485 multidrop, jumpers): drivers 0-6
#   Bus B (RS422 maestro/esclavos):   7 maestro, 8-10 esclavos
#   Bus C (RS422 maestro/esclavos):   11 maestro, 12-13 esclavos
#
# Escalado a 14 canales (vs 4):
#   - Config GP0: árbol de SmartConnects (29 esclavos > 16 máx/SmartConnect)
#       root(1→2) → smc_periph(14 UART + SysInfo) , smc_dma(14 DMA)
#   - IRQ: 28 introut > 16 líneas PL→PS → OR-reduce a 2 líneas (mm2s, s2mm)
#       + ISR que escanea los 14 canales (ver transceiver.c del pcb)
#   - DE de drivers 7 y 11: sin pin físico (hardcodeado en HW) → no se crea puerto
#
# MAPA DE MEMORIA:
#   0xA000_0000 + i*0x1000   UART_i config (i=0..13)   → hasta 0xA000_D000
#   0xA001_0000 + i*0x1000   axi_dma_i registros        → hasta 0xA001_D000
#   0xA002_0000              SysInfo
#
# Ejecución (desde hardware/):
#   vivado -mode batch -source scripts/simple_dma14_system.tcl
# =========================================================================

set project_name "zynq_dma14_pcb"
set project_dir  "./dma14"
set src_dir      "./src"

set N 14

set uart_base 0xA0000000
set uart_step 0x1000
set dma_base  0xA0010000
set dma_step  0x1000
set sysinfo_base 0xA0020000

# Canales SIN pin DE (DE hardcodeado en HW): no se crea puerto físico
set no_de_channels {7 11}

proc has_de {ch} {
    global no_de_channels
    return [expr {[lsearch $no_de_channels $ch] < 0}]
}

puts "================================================================"
puts " PROYECTO PCB: $project_name  ($N canales, AXI DMA simple, sin loopback)"
puts "================================================================"

# =========================================================================
# 1. PROYECTO
# =========================================================================
create_project -force $project_name $project_dir -part xczu9eg-ffvb1156-2-e
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]

# =========================================================================
# 2. FUENTES (sin MULTI_SERIAL_CORE: no se usa)
# =========================================================================
foreach vhd [glob $src_dir/*.vhd] {
    if { [string match "*MULTI_SERIAL_CORE*" $vhd] } continue
    add_files $vhd
}
add_files -fileset constrs_1 $src_dir/zcu102_constraints.xdc
update_compile_order -fileset sources_1

# =========================================================================
# 3. IP FIFO
# =========================================================================
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name fifo_generator_0
set_property -dict [list \
    CONFIG.Interface_Type         {Native}                  \
    CONFIG.Performance_Options    {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width       {9}                       \
    CONFIG.Input_Depth            {512}                     \
    CONFIG.Output_Data_Width      {9}                       \
    CONFIG.Reset_Type             {Synchronous_Reset}       \
    CONFIG.Full_Flags_Reset_Value {0}                       \
    CONFIG.Use_Dout_Reset         {true}                    \
] [get_ips fifo_generator_0]
generate_target all [get_ips fifo_generator_0]
create_ip_run [get_ips fifo_generator_0]

# =========================================================================
# 4. PROC: jerarquía UART (sin loopback)
# =========================================================================
proc create_transceiver_hier { index } {
    set parent [current_bd_instance .]
    set hier   [create_bd_cell -type hier "Transceiver_${index}"]
    current_bd_instance $hier

    create_bd_cell -type module -reference UART_AXIS_TOP "uart_top"
    set_property CONFIG.CH_ID $index [get_bd_cells uart_top]

    create_bd_pin -dir I -type clk aclk
    create_bd_pin -dir I -type rst aresetn

    create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:aximm_rtl:1.0  S_AXI
    create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0   S_AXIS_TX
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0   M_AXIS_RX

    create_bd_pin -dir I RD
    create_bd_pin -dir O TD
    create_bd_pin -dir O DE
    create_bd_pin -dir O SLO

    connect_bd_net [get_bd_pins aclk]    [get_bd_pins uart_top/aclk]
    connect_bd_net [get_bd_pins aresetn] [get_bd_pins uart_top/aresetn]
    connect_bd_net [get_bd_pins RD]           [get_bd_pins uart_top/RD]
    connect_bd_net [get_bd_pins uart_top/TD]  [get_bd_pins TD]
    connect_bd_net [get_bd_pins uart_top/DE]  [get_bd_pins DE]
    connect_bd_net [get_bd_pins uart_top/SLO] [get_bd_pins SLO]

    connect_bd_intf_net [get_bd_intf_pins S_AXI]     [get_bd_intf_pins uart_top/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins S_AXIS_TX] [get_bd_intf_pins uart_top/S_AXIS_TX]
    connect_bd_intf_net [get_bd_intf_pins M_AXIS_RX] [get_bd_intf_pins uart_top/M_AXIS_RX]

    current_bd_instance $parent
}

# =========================================================================
# 5. BLOCK DESIGN
# =========================================================================
create_bd_design "system"

# ── ZynqMP PS ──────────────────────────────────────────────────────────────
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
                    -config {apply_board_preset "1"} $ps
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__IRQ0       {1} \
    CONFIG.PSU__USE__IRQ1       {0} \
    CONFIG.PSU__USE__S_AXI_GP2  {1} \
    CONFIG.PSU__USE__S_AXI_GP3  {1} \
] $ps

set sys_clk  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
set sys_rstn [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]

# ── Reset ──────────────────────────────────────────────────────────────────
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen]
connect_bd_net $sys_clk  [get_bd_pins rst_gen/slowest_sync_clk]
connect_bd_net $sys_rstn [get_bd_pins rst_gen/ext_reset_in]
set aresetn [get_bd_pins rst_gen/peripheral_aresetn]

# ── 14× AXI DMA simple ─────────────────────────────────────────────────────
puts "-> Creando $N × axi_dma (modo simple, 8-bit stream)..."
for {set i 0} {$i < $N} {incr i} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma "axi_dma_${i}"
    set_property -dict [list \
        CONFIG.c_include_sg              {0}  \
        CONFIG.c_m_axis_mm2s_tdata_width {8}  \
        CONFIG.c_s_axis_s2mm_tdata_width {8}  \
        CONFIG.c_mm2s_burst_size         {16} \
        CONFIG.c_s2mm_burst_size         {16} \
        CONFIG.c_addr_width              {32} \
    ] [get_bd_cells "axi_dma_${i}"]
    connect_bd_net $sys_clk  [get_bd_pins "axi_dma_${i}/m_axi_mm2s_aclk"]
    connect_bd_net $sys_clk  [get_bd_pins "axi_dma_${i}/m_axi_s2mm_aclk"]
    connect_bd_net $sys_clk  [get_bd_pins "axi_dma_${i}/s_axi_lite_aclk"]
    connect_bd_net $aresetn  [get_bd_pins "axi_dma_${i}/axi_resetn"]
}

# ── Árbol de SmartConnects para config GP0 ─────────────────────────────────
# root(1→2): M00→smc_periph(14 UART + SysInfo), M01→smc_dma(14 DMA)
puts "-> Creando árbol de SmartConnects de config..."
set smc_root [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_root]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $smc_root
connect_bd_net $sys_clk [get_bd_pins smc_root/aclk]
connect_bd_net $aresetn [get_bd_pins smc_root/aresetn]
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins smc_root/S00_AXI]

# smc_periph: 14 UART + 1 SysInfo = 15 MI
set smc_periph [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_periph]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI [expr {$N + 1}]] $smc_periph
connect_bd_net $sys_clk [get_bd_pins smc_periph/aclk]
connect_bd_net $aresetn [get_bd_pins smc_periph/aresetn]
connect_bd_intf_net [get_bd_intf_pins smc_root/M00_AXI] \
                    [get_bd_intf_pins smc_periph/S00_AXI]

# smc_dma: 14 DMA S_AXI_LITE
set smc_dma [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_dma]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI $N] $smc_dma
connect_bd_net $sys_clk [get_bd_pins smc_dma/aclk]
connect_bd_net $aresetn [get_bd_pins smc_dma/aresetn]
connect_bd_intf_net [get_bd_intf_pins smc_root/M01_AXI] \
                    [get_bd_intf_pins smc_dma/S00_AXI]

# DMA AXI-Lite → smc_dma
for {set i 0} {$i < $N} {incr i} {
    set mi [format "M%02d_AXI" $i]
    connect_bd_intf_net [get_bd_intf_pins "smc_dma/${mi}"] \
                        [get_bd_intf_pins "axi_dma_${i}/S_AXI_LITE"]
}

# ── SmartConnect HP0: 14× MM2S → DDR ───────────────────────────────────────
set smc_hp0 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp0]
set_property -dict [list CONFIG.NUM_SI $N CONFIG.NUM_MI {1}] $smc_hp0
connect_bd_net $sys_clk [get_bd_pins smc_hp0/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp0/aresetn]
for {set i 0} {$i < $N} {incr i} {
    set si [format "S%02d_AXI" $i]
    connect_bd_intf_net [get_bd_intf_pins "axi_dma_${i}/M_AXI_MM2S"] \
                        [get_bd_intf_pins "smc_hp0/${si}"]
}
connect_bd_intf_net [get_bd_intf_pins smc_hp0/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]

# ── SmartConnect HP1: 14× S2MM → DDR ───────────────────────────────────────
set smc_hp1 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp1]
set_property -dict [list CONFIG.NUM_SI $N CONFIG.NUM_MI {1}] $smc_hp1
connect_bd_net $sys_clk [get_bd_pins smc_hp1/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp1/aresetn]
for {set i 0} {$i < $N} {incr i} {
    set si [format "S%02d_AXI" $i]
    connect_bd_intf_net [get_bd_intf_pins "axi_dma_${i}/M_AXI_S2MM"] \
                        [get_bd_intf_pins "smc_hp1/${si}"]
}
connect_bd_intf_net [get_bd_intf_pins smc_hp1/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk]

# ── 14 jerarquías UART + conexión directa con su DMA + pines físicos ───────
puts "-> Creando $N jerarquías UART..."
for {set i 0} {$i < $N} {incr i} {
    create_transceiver_hier $i
    set cell "Transceiver_${i}"
    connect_bd_net $sys_clk [get_bd_pins "${cell}/aclk"]
    connect_bd_net $aresetn [get_bd_pins "${cell}/aresetn"]

    # UART config → smc_periph (M00..M13)
    set mi_uart [format "M%02d_AXI" $i]
    connect_bd_intf_net [get_bd_intf_pins "smc_periph/${mi_uart}"] \
                        [get_bd_intf_pins "${cell}/S_AXI"]

    # DMA directo ↔ UART
    connect_bd_intf_net [get_bd_intf_pins "axi_dma_${i}/M_AXIS_MM2S"] \
                        [get_bd_intf_pins "${cell}/S_AXIS_TX"]
    connect_bd_intf_net [get_bd_intf_pins "${cell}/M_AXIS_RX"] \
                        [get_bd_intf_pins "axi_dma_${i}/S_AXIS_S2MM"]

    # Pines físicos
    create_bd_port -dir I "UART_${i}_RX"
    create_bd_port -dir O "UART_${i}_TX"
    create_bd_port -dir O "UART_${i}_SLO"
    connect_bd_net [get_bd_ports "UART_${i}_RX"] [get_bd_pins "${cell}/RD"]
    connect_bd_net [get_bd_pins "${cell}/TD"]    [get_bd_ports "UART_${i}_TX"]
    connect_bd_net [get_bd_pins "${cell}/SLO"]   [get_bd_ports "UART_${i}_SLO"]

    # DE: solo si el driver tiene pin (7 y 11 no → DE queda interno sin conectar)
    if { [has_de $i] } {
        create_bd_port -dir O "UART_${i}_DE"
        connect_bd_net [get_bd_pins "${cell}/DE"] [get_bd_ports "UART_${i}_DE"]
    }
}

# ── SysInfo ────────────────────────────────────────────────────────────────
set sys_info [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_sys_info]
set_property -dict [list \
    CONFIG.C_IS_DUAL      {1} \
    CONFIG.C_ALL_INPUTS   {1} CONFIG.C_GPIO_WIDTH  {32} \
    CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {32} \
] $sys_info
set meta_val [expr {($uart_step << 16) | $N}]
set c_meta [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_meta]
set_property -dict [list CONFIG.CONST_VAL $meta_val CONFIG.CONST_WIDTH {32}] $c_meta
set c_base [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_base]
set_property -dict [list CONFIG.CONST_VAL $uart_base CONFIG.CONST_WIDTH {32}] $c_base
connect_bd_net [get_bd_pins const_meta/dout] [get_bd_pins axi_sys_info/gpio_io_i]
connect_bd_net [get_bd_pins const_base/dout] [get_bd_pins axi_sys_info/gpio2_io_i]
connect_bd_net $sys_clk  [get_bd_pins axi_sys_info/s_axi_aclk]
connect_bd_net $aresetn  [get_bd_pins axi_sys_info/s_axi_aresetn]
# SysInfo → smc_periph M14 (último MI)
set mi_si [format "M%02d_AXI" $N]
connect_bd_intf_net [get_bd_intf_pins "smc_periph/${mi_si}"] \
                    [get_bd_intf_pins axi_sys_info/S_AXI]

# ── IRQs: OR-reduce 14 mm2s + 14 s2mm → 2 líneas → pl_ps_irq0[1:0] ─────────
puts "-> Coalesciendo IRQs (14 mm2s + 14 s2mm → 2 líneas)..."
# concat de los 14 mm2s_introut → bus de 14 bits
set cc_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 cc_mm2s]
set_property CONFIG.NUM_PORTS $N $cc_mm2s
set cc_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 cc_s2mm]
set_property CONFIG.NUM_PORTS $N $cc_s2mm
for {set i 0} {$i < $N} {incr i} {
    connect_bd_net [get_bd_pins "axi_dma_${i}/mm2s_introut"] [get_bd_pins "cc_mm2s/In${i}"]
    connect_bd_net [get_bd_pins "axi_dma_${i}/s2mm_introut"] [get_bd_pins "cc_s2mm/In${i}"]
}
# OR-reduce cada bus de 14 bits → 1 bit
set or_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 or_mm2s]
set_property -dict [list CONFIG.C_SIZE $N CONFIG.C_OPERATION {or}] $or_mm2s
set or_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 or_s2mm]
set_property -dict [list CONFIG.C_SIZE $N CONFIG.C_OPERATION {or}] $or_s2mm
connect_bd_net [get_bd_pins cc_mm2s/dout] [get_bd_pins or_mm2s/Op1]
connect_bd_net [get_bd_pins cc_s2mm/dout] [get_bd_pins or_s2mm/Op1]
# concat de las 2 líneas → pl_ps_irq0
set cc_irq [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 cc_irq]
set_property CONFIG.NUM_PORTS 2 $cc_irq
connect_bd_net [get_bd_pins or_mm2s/Res] [get_bd_pins cc_irq/In0]
connect_bd_net [get_bd_pins or_s2mm/Res] [get_bd_pins cc_irq/In1]
connect_bd_net [get_bd_pins cc_irq/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# ── Relojes huérfanos ──────────────────────────────────────────────────────
foreach pin_name {maxihpm1_fpd_aclk maxihpm0_lpd_aclk} {
    set p [get_bd_pins -quiet zynq_ultra_ps_e_0/$pin_name]
    if { $p ne "" && [get_bd_nets -quiet -of_objects $p] eq "" } {
        connect_bd_net $sys_clk $p
    }
}

# =========================================================================
# 6. MAPA DE MEMORIA
# =========================================================================
puts "-> Asignando mapa de memoria..."
set seg "zynq_ultra_ps_e_0/Data"

for {set i 0} {$i < $N} {incr i} {
    set addr [expr {$uart_base + $i * $uart_step}]
    set segs [get_bd_addr_segs -quiet "Transceiver_${i}/uart_top/S_AXI/*"]
    if { $segs ne "" } {
        assign_bd_address -target_address_space $seg $segs \
            -force -offset [format "0x%08X" $addr] -range 4K
    }
}
for {set i 0} {$i < $N} {incr i} {
    set addr [expr {$dma_base + $i * $dma_step}]
    assign_bd_address -target_address_space $seg \
        [get_bd_addr_segs "axi_dma_${i}/S_AXI_LITE/Reg"] \
        -force -offset [format "0x%08X" $addr] -range 4K
}
assign_bd_address -target_address_space $seg \
    [get_bd_addr_segs axi_sys_info/S_AXI/Reg] \
    -force -offset [format "0x%08X" $sysinfo_base] -range 4K

# DMA masters → DDR
set hp0_non {HP0_QSPI HP0_PCIE_LOW HP0_PCIE_HIGH1 HP0_PCIE_HIGH2 HP0_LPS_OCM HP0_DDR_HIGH}
set hp1_non {HP1_QSPI HP1_PCIE_LOW HP1_PCIE_HIGH1 HP1_PCIE_HIGH2 HP1_LPS_OCM HP1_DDR_HIGH}
set ddr0 [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW]
set ddr1 [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW]
for {set i 0} {$i < $N} {incr i} {
    if { $ddr0 ne "" } {
        assign_bd_address -target_address_space "axi_dma_${i}/Data_MM2S" $ddr0 -force
    }
    foreach name $hp0_non {
        set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/$name]
        if { $s ne "" } { exclude_bd_addr_seg $s -target_address_space "axi_dma_${i}/Data_MM2S" }
    }
    if { $ddr1 ne "" } {
        assign_bd_address -target_address_space "axi_dma_${i}/Data_S2MM" $ddr1 -force
    }
    foreach name $hp1_non {
        set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/$name]
        if { $s ne "" } { exclude_bd_addr_seg $s -target_address_space "axi_dma_${i}/Data_S2MM" }
    }
}

# =========================================================================
# 7. VALIDAR Y WRAP
# =========================================================================
puts "-> Validando..."
validate_bd_design
save_bd_design
set wrapper [make_wrapper -fileset sources_1 -files [get_files system.bd] -top]
add_files -norecurse -fileset sources_1 $wrapper
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " LISTO: $project_name  ($N canales PCB, sin loopback)"
puts "   UART_i  : 0xA0000000 + i*0x1000"
puts "   axi_dma_i: 0xA0010000 + i*0x1000"
puts "   SysInfo : 0xA0020000"
puts "   IRQ: pl_ps_irq0[0]=mm2s(OR14)  [1]=s2mm(OR14)  → RTEMS 121, 122"
puts "   DE sin pin en drivers: $no_de_channels"
puts "================================================================"
