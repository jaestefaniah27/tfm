# simple_dma4_system.tcl
# =========================================================================
# Diseño de prueba: 4 canales UART con 4× AXI DMA simple (PG021)
#
# DIFERENCIAS respecto al diseño MCDMA:
#   - Sin AXI MCDMA, sin axis_switch, sin dwidth_converter
#   - 4× axi_dma en modo registro simple (c_include_sg=0)
#     → sin descriptor rings, driver trivial (4 escrituras de registro)
#   - DMA directo: axi_dma_i/M_AXIS_MM2S → UART_i TX
#                  UART_i RX → axi_dma_i/S_AXIS_S2MM
#   - 8 IRQs (4× mm2s + 4× s2mm) en pl_ps_irq0
#
# MAPA DE MEMORIA:
#   0xA000_0000  UART_0 AXI-Lite config
#   0xA000_1000  UART_1
#   0xA000_2000  UART_2
#   0xA000_3000  UART_3
#   0xA000_4000  axi_dma_0 registros
#   0xA000_5000  axi_dma_1
#   0xA000_6000  axi_dma_2
#   0xA000_7000  axi_dma_3
#   0xA001_0000  SysInfo
#
# Ejecución (desde hardware/):
#   vivado -mode batch -source scripts/simple_dma4_system.tcl
# =========================================================================

set project_name "zynq_dma4_simple"
set project_dir  "./dma4"
set src_dir      "./src"

set N 4   ;# número de canales

# Loopback interno de diagnóstico: si es 1, cada canal conecta TD→RD DENTRO de
# la FPGA (cada UART se oye a sí mismo), saltándose el bus RS485 físico.
#   1 → aísla la cadena digital DMA+UART+stream (cada canal recibe SU envío)
#   0 → operación normal: RD viene del pin físico
# Sincronizar con #define INTERNAL_LOOPBACK en main.c
set LOOPBACK 1

set uart_base 0xA0000000
set uart_step 0x1000
set dma_base  0xA0004000
set dma_step  0x1000
set sysinfo_base 0xA0010000

puts "================================================================"
puts " PROYECTO: $project_name  ($N canales, AXI DMA simple)"
puts "================================================================"

# =========================================================================
# 1. PROYECTO
# =========================================================================
create_project -force $project_name $project_dir -part xczu9eg-ffvb1156-2-e
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]

# =========================================================================
# 2. FUENTES
# =========================================================================
# VHD — todos los del diseño base salvo MULTI_SERIAL_CORE (no se usa aquí)
foreach vhd [glob $src_dir/*.vhd] {
    add_files $vhd
}
add_files -fileset constrs_1 $src_dir/zcu102_constraints_4ch.xdc
update_compile_order -fileset sources_1

# =========================================================================
# 3. IP FIFO (requerido por CONFIGURABLE_SERIAL internamente)
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
# 4. PROCEDIMIENTO: jerarquía UART (idéntico al diseño MCDMA)
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

    connect_bd_intf_net [get_bd_intf_pins S_AXI]    [get_bd_intf_pins uart_top/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins S_AXIS_TX] [get_bd_intf_pins uart_top/S_AXIS_TX]
    connect_bd_intf_net [get_bd_intf_pins M_AXIS_RX] [get_bd_intf_pins uart_top/M_AXIS_RX]

    current_bd_instance $parent
}

# =========================================================================
# 5. BLOCK DESIGN
# =========================================================================
create_bd_design "system"

# ── ZynqMP PS ─────────────────────────────────────────────────────────────
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

# ── 4× AXI DMA simple (sin scatter-gather, stream 8 bits) ─────────────────
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

# ── SmartConnect config: GP0 → 4 UARTs + 4 DMAs + SysInfo ─────────────────
# Número de esclavos: N UARTs + N DMAs + 1 SysInfo
set n_mi [expr {$N * 2 + 1}]
set smc_cfg [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_config]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI $n_mi] $smc_cfg
connect_bd_net $sys_clk [get_bd_pins smc_config/aclk]
connect_bd_net $aresetn [get_bd_pins smc_config/aresetn]
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins smc_config/S00_AXI]

# ── SmartConnect HP0: 4× MM2S → DDR ───────────────────────────────────────
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

# ── SmartConnect HP1: 4× S2MM → DDR ───────────────────────────────────────
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

# ── 4 jerarquías UART + conexión directa con su DMA ───────────────────────
puts "-> Creando $N jerarquías UART y conectando con sus DMA..."
for {set i 0} {$i < $N} {incr i} {
    create_transceiver_hier $i

    set cell "Transceiver_${i}"
    connect_bd_net $sys_clk $aresetn -quiet
    connect_bd_net $sys_clk [get_bd_pins "${cell}/aclk"]
    connect_bd_net $aresetn [get_bd_pins "${cell}/aresetn"]

    # DMA config → SmartConnect config (índices 0..N-1)
    set mi_uart [format "M%02d_AXI" $i]
    connect_bd_intf_net [get_bd_intf_pins "smc_config/${mi_uart}"] \
                        [get_bd_intf_pins "${cell}/S_AXI"]

    # DMA AXI-Lite → SmartConnect config (índices N..2N-1)
    set mi_dma [format "M%02d_AXI" [expr {$N + $i}]]
    connect_bd_intf_net [get_bd_intf_pins "smc_config/${mi_dma}"] \
                        [get_bd_intf_pins "axi_dma_${i}/S_AXI_LITE"]

    # DMA MM2S → UART TX  (directo, sin switch)
    connect_bd_intf_net [get_bd_intf_pins "axi_dma_${i}/M_AXIS_MM2S"] \
                        [get_bd_intf_pins "${cell}/S_AXIS_TX"]

    # UART RX → DMA S2MM  (directo, sin switch)
    connect_bd_intf_net [get_bd_intf_pins "${cell}/M_AXIS_RX"] \
                        [get_bd_intf_pins "axi_dma_${i}/S_AXIS_S2MM"]

    # Pines físicos — se crean SIEMPRE los 4 para que el XDC cuadre en ambos
    # modos. En loopback, UART_i_RX queda colgado (warning inofensivo) y RD se
    # alimenta del propio TD dentro de la FPGA.
    create_bd_port -dir I "UART_${i}_RX"
    create_bd_port -dir O "UART_${i}_TX"
    create_bd_port -dir O "UART_${i}_DE"
    create_bd_port -dir O "UART_${i}_SLO"
    connect_bd_net [get_bd_pins "${cell}/TD"]  [get_bd_ports "UART_${i}_TX"]
    connect_bd_net [get_bd_pins "${cell}/DE"]  [get_bd_ports "UART_${i}_DE"]
    connect_bd_net [get_bd_pins "${cell}/SLO"] [get_bd_ports "UART_${i}_SLO"]

    if { $LOOPBACK } {
        # Loopback interno: TD → RD del mismo canal (se oye a sí mismo)
        connect_bd_net [get_bd_pins "${cell}/TD"] [get_bd_pins "${cell}/RD"]
    } else {
        # Operación normal: RD desde el pin físico del bus RS485
        connect_bd_net [get_bd_ports "UART_${i}_RX"] [get_bd_pins "${cell}/RD"]
    }
}

# ── SysInfo (compatible con el driver C existente) ─────────────────────────
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

set mi_si [format "M%02d_AXI" [expr {$N * 2}]]
connect_bd_intf_net [get_bd_intf_pins "smc_config/${mi_si}"] \
                    [get_bd_intf_pins axi_sys_info/S_AXI]

# ── IRQs: 4× mm2s + 4× s2mm = 8 líneas → pl_ps_irq0[7:0] ─────────────────
# pl_ps_irq0[0..3] = axi_dma_{0..3}/mm2s_introut  → GIC SPI 89-92 → RTEMS 121-124
# pl_ps_irq0[4..7] = axi_dma_{0..3}/s2mm_introut  → GIC SPI 93-96 → RTEMS 125-128
puts "-> Conectando IRQs ($N mm2s + $N s2mm → pl_ps_irq0)..."
set irq_concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat]
set_property CONFIG.NUM_PORTS [expr {$N * 2}] $irq_concat

for {set i 0} {$i < $N} {incr i} {
    connect_bd_net [get_bd_pins "axi_dma_${i}/mm2s_introut"] \
                   [get_bd_pins "irq_concat/In${i}"]
    connect_bd_net [get_bd_pins "axi_dma_${i}/s2mm_introut"] \
                   [get_bd_pins "irq_concat/In[expr {$N + $i}]"]
}
connect_bd_net [get_bd_pins irq_concat/dout] \
               [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

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

# UARTs AXI-Lite
for {set i 0} {$i < $N} {incr i} {
    set addr [expr {$uart_base + $i * $uart_step}]
    set segs [get_bd_addr_segs -quiet "Transceiver_${i}/uart_top/S_AXI/*"]
    if { $segs ne "" } {
        assign_bd_address -target_address_space $seg $segs \
            -force -offset [format "0x%08X" $addr] -range 4K
    }
}

# AXI DMA registros
for {set i 0} {$i < $N} {incr i} {
    set addr [expr {$dma_base + $i * $dma_step}]
    assign_bd_address \
        -target_address_space $seg \
        [get_bd_addr_segs "axi_dma_${i}/S_AXI_LITE/Reg"] \
        -force -offset [format "0x%08X" $addr] -range 4K
}

# SysInfo
assign_bd_address \
    -target_address_space $seg \
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

set wrapper [make_wrapper -fileset sources_1 \
    -files [get_files system.bd] -top]
add_files -norecurse -fileset sources_1 $wrapper
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " LISTO: $project_name"
puts ""
puts " Mapa de memoria:"
for {set i 0} {$i < $N} {incr i} {
    set u [format "0x%08X" [expr {$uart_base + $i * $uart_step}]]
    set d [format "0x%08X" [expr {$dma_base  + $i * $dma_step}]]
    puts "   $u  UART_$i config (AXI-Lite)"
    puts "   $d  axi_dma_$i registros"
}
puts "   [format 0x%08X $sysinfo_base]  SysInfo"
puts ""
puts " IRQs (RTEMS rtems_interrupt_handler_install):"
for {set i 0} {$i < $N} {incr i} {
    puts "   [expr {121+$i}]  axi_dma_$i MM2S completado"
    puts "   [expr {125+$i}]  axi_dma_$i S2MM completado"
}
puts ""
puts " Driver simple (4 registros por transferencia, ver PG021):"
puts "   TX: MM2S_DMACR=0x1001, MM2S_SA=buf, MM2S_LENGTH=n"
puts "   RX: S2MM_DMACR=0x1001, S2MM_DA=buf, S2MM_LENGTH=max"
puts "================================================================"
