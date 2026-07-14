# new_dma_system.tcl
# =========================================================================
# Genera un proyecto Vivado completo para ZCU102 con arquitectura
# AXI-Stream + AXI MCDMA (14 canales simultáneos, DMA sin carga de CPU).
#
# Diferencias respecto al diseño anterior (GPIO):
#   - ELIMINA : 14× AXI GPIO de datos + AXI INTC global
#   - AGREGA  : 1× AXI MCDMA (14 canales MM2S + 14 S2MM)
#   - AGREGA  : UART_AXIS_TOP.vhd (wrapper AXI-Lite config + AXI-Stream datos)
#   - MANTIENE: SysInfo (descubrimiento de hardware por el driver C)
#   - IRQ     : mm2s_introut → pl_ps_irq0, s2mm_introut → pl_ps_irq1
#
# Ejecución desde Vivado:
#   source ./scripts/new_dma_system.tcl
# =========================================================================

set project_name "zynq_uart_dma"
set project_dir  "./dma"
set src_dir      "./src"

set num_transceivers 14

# Mapa de memoria
set uart_base_addr  0xA0000000   ;# Base config AXI-Lite UART (stride 0x1000)
set uart_stride     0x1000
set sys_info_addr   0xA0010000   ;# Bloque SysInfo
set mcdma_ctrl_addr 0xA0100000   ;# Registros de control AXI MCDMA (256 KB)

puts "================================================================"
puts " CREANDO PROYECTO DMA: $project_name"
puts " Canales UART : $num_transceivers"
puts " Base UART    : [format 0x%08X $uart_base_addr]"
puts " MCDMA ctrl   : [format 0x%08X $mcdma_ctrl_addr]"
puts "================================================================"

# =========================================================================
# 1. PROYECTO
# =========================================================================
create_project -force $project_name $project_dir -part xczu9eg-ffvb1156-2-e
set_property board_part xilinx.com:zcu102:part0:3.4 [current_project]

# =========================================================================
# 2. FUENTES VHDL + CONSTRAINTS
# =========================================================================
add_files [glob $src_dir/*.vhd]
add_files -fileset constrs_1 $src_dir/zcu102_constraints.xdc
update_compile_order -fileset sources_1

# =========================================================================
# 3. IP FIFO (requerido por CONFIGURABLE_SERIAL internamente)
# =========================================================================
puts "-> Generando IP: fifo_generator_0 (9 bits, 512 deep, FWFT)..."
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name fifo_generator_0
set_property -dict [list \
    CONFIG.Interface_Type          {Native} \
    CONFIG.Performance_Options     {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width        {9} \
    CONFIG.Input_Depth             {512} \
    CONFIG.Output_Data_Width       {9} \
    CONFIG.Reset_Type              {Synchronous_Reset} \
    CONFIG.Full_Flags_Reset_Value  {0} \
    CONFIG.Use_Dout_Reset          {true} \
] [get_ips fifo_generator_0]
generate_target all [get_ips fifo_generator_0]
create_ip_run [get_ips fifo_generator_0]

# =========================================================================
# 4. PROCEDIMIENTO: JERARQUÍA POR TRANSCEPTOR
#    Cada jerarquía expone:
#      S_AXI      → AXI-Lite config  (desde SmartConnect GP0)
#      S_AXIS_TX  → Stream TX data   (desde MCDMA MM2S chN)
#      M_AXIS_RX  → Stream RX data   (hacia MCDMA S2MM chN)
#      aclk, aresetn, RD, TD, DE, SLO
# =========================================================================
proc create_transceiver_hier { index } {
    puts "  -> Transceiver_${index}..."

    set parent [current_bd_instance .]
    set hier   [create_bd_cell -type hier "Transceiver_${index}"]
    current_bd_instance $hier

    # -- RTL: UART_AXIS_TOP --
    # Vivado infiere S_AXI, S_AXIS_TX, M_AXIS_RX desde los nombres de puertos.
    create_bd_cell -type module -reference UART_AXIS_TOP "uart_top"
    # CH_ID = índice de canal → el UART emite M_AXIS_RX_TDEST=CH_ID para que el
    # MCDMA S2MM demultiplexe el RX al canal correcto (el switch NO inyecta TDEST).
    set_property CONFIG.CH_ID $index [get_bd_cells uart_top]

    # -- Pines de sistema en la frontera de jerarquía --
    create_bd_pin -dir I -type clk aclk
    create_bd_pin -dir I -type rst aresetn

    # -- Interfaces AXI en la frontera --
    create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI
    create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0  S_AXIS_TX
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0  M_AXIS_RX

    # -- Pines físicos UART --
    create_bd_pin -dir I RD
    create_bd_pin -dir O TD
    create_bd_pin -dir O DE
    create_bd_pin -dir O SLO

    # -- Reloj y reset --
    connect_bd_net [get_bd_pins aclk]    [get_bd_pins uart_top/aclk]
    connect_bd_net [get_bd_pins aresetn] [get_bd_pins uart_top/aresetn]

    # -- Pines físicos --
    connect_bd_net [get_bd_pins RD]           [get_bd_pins uart_top/RD]
    connect_bd_net [get_bd_pins uart_top/TD]  [get_bd_pins TD]
    connect_bd_net [get_bd_pins uart_top/DE]  [get_bd_pins DE]
    connect_bd_net [get_bd_pins uart_top/SLO] [get_bd_pins SLO]

    # -- AXI-Lite: conectar interfaz de jerarquía a módulo --
    connect_bd_intf_net [get_bd_intf_pins S_AXI] [get_bd_intf_pins uart_top/S_AXI]

    # -- AXI-Stream TX: MCDMA MM2S → S_AXIS_TX de la jerarquía → uart_top --
    connect_bd_intf_net [get_bd_intf_pins S_AXIS_TX] [get_bd_intf_pins uart_top/S_AXIS_TX]

    # -- AXI-Stream RX: uart_top → M_AXIS_RX de la jerarquía → MCDMA S2MM --
    connect_bd_intf_net [get_bd_intf_pins M_AXIS_RX] [get_bd_intf_pins uart_top/M_AXIS_RX]

    current_bd_instance $parent
}

# =========================================================================
# 5. BLOCK DESIGN
# =========================================================================
puts "-> Creando Block Design 'system'..."
create_bd_design "system"

# -------------------------------------------------------------------------
# 5.1  ZynqMP PS
# -------------------------------------------------------------------------
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
                    -config {apply_board_preset "1"} $ps

set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0  {1} \
    CONFIG.PSU__USE__M_AXI_GP1  {0} \
    CONFIG.PSU__USE__M_AXI_GP2  {0} \
    CONFIG.PSU__USE__IRQ0       {1} \
    CONFIG.PSU__USE__IRQ1       {0} \
    CONFIG.PSU__USE__S_AXI_GP2  {1} \
    CONFIG.PSU__USE__S_AXI_GP3  {1} \
] $ps
# PSU__USE__S_AXI_GP2 habilita S_AXI_HP0_FPD y su pin saxihp0_fpd_aclk
# PSU__USE__S_AXI_GP3 habilita S_AXI_HP1_FPD y su pin saxihp1_fpd_aclk
# (En Vivado 2025.1 el nombre del parámetro es S_AXI_GPx, no S_AXI_HPx)

set sys_clk  [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
set sys_rstn [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

# Reloj del master AXI GP0 (control path)
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
# saxihp0/hp1_fpd_aclk se conectan en sección 5.5 tras habilitar S_AXI_GP2/GP3

# -------------------------------------------------------------------------
# 5.2  Reset del sistema
# -------------------------------------------------------------------------
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen]
connect_bd_net $sys_clk  [get_bd_pins rst_gen/slowest_sync_clk]
connect_bd_net $sys_rstn [get_bd_pins rst_gen/ext_reset_in]
set aresetn [get_bd_pins rst_gen/peripheral_aresetn]

# -------------------------------------------------------------------------
# 5.3  AXI MCDMA  — 14 canales MM2S (TX) + 14 S2MM (RX)
# -------------------------------------------------------------------------
puts "-> Creando AXI MCDMA (14 canales)..."
set mcdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_mcdma axi_mcdma_0]
set_property -dict [list \
    CONFIG.c_num_mm2s_channels          {14} \
    CONFIG.c_num_s2mm_channels          {14} \
    CONFIG.c_sg_include_stscntrl_strm   {0}  \
    CONFIG.c_enable_multi_intr          {0}  \
    CONFIG.c_m_axi_mm2s_data_width      {64} \
    CONFIG.c_m_axi_s2mm_data_width      {64} \
] $mcdma

# s_axi_aclk es el reloj compartido para todas las interfaces AXI (C_PRMRY_IS_ACLK_ASYNC=0)
# m_axi_mm2s_aclk y m_axi_s2mm_aclk solo existen cuando C_PRMRY_IS_ACLK_ASYNC=1
connect_bd_net $sys_clk  [get_bd_pins axi_mcdma_0/s_axi_aclk]
connect_bd_net $sys_clk  [get_bd_pins axi_mcdma_0/s_axi_lite_aclk]
connect_bd_net $aresetn  [get_bd_pins axi_mcdma_0/axi_resetn]

# -------------------------------------------------------------------------
# 5.4  SmartConnect: GP0 → UART configs (×14) + MCDMA ctrl + SysInfo
#      Número de esclavos = num_transceivers + 2  (MCDMA + SysInfo)
# -------------------------------------------------------------------------
set num_mi_cfg [expr {$num_transceivers + 2}]
set smc_cfg [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_config]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI $num_mi_cfg] $smc_cfg
connect_bd_net $sys_clk [get_bd_pins smc_config/aclk]
connect_bd_net $aresetn [get_bd_pins smc_config/aresetn]
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins smc_config/S00_AXI]

# -------------------------------------------------------------------------
# 5.5  DMA → DDR: SmartConnect manual para HP0 (MM2S + SG) y HP1 (S2MM)
#
# En Vivado 2022+, conectar una interfaz a S_AXI_HP0_FPD habilita HP0
# automáticamente, haciendo disponible saxihp0_fpd_aclk justo después.
# No se usa apply_bd_automation (falla al parsear -config en 2025.1).
# -------------------------------------------------------------------------
puts "-> Creando SmartConnect HP0 (MM2S+SG) y HP1 (S2MM)..."

# HP0: MM2S (lectura TX desde DDR) + SG (lectura de descriptores desde DDR)
# Verificar M_AXI_SG antes de crear SmartConnect para dimensionarlo correctamente
set sg_intf [get_bd_intf_pins -quiet axi_mcdma_0/M_AXI_SG]
set hp0_num_si [expr { ($sg_intf ne "") ? 2 : 1 }]

set smc_hp0 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp0]
set_property CONFIG.NUM_SI $hp0_num_si [get_bd_cells smc_hp0]
connect_bd_net $sys_clk [get_bd_pins smc_hp0/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp0/aresetn]

connect_bd_intf_net [get_bd_intf_pins axi_mcdma_0/M_AXI_MM2S] \
                    [get_bd_intf_pins smc_hp0/S00_AXI]
if { $sg_intf ne "" } {
    connect_bd_intf_net $sg_intf [get_bd_intf_pins smc_hp0/S01_AXI]
}

connect_bd_intf_net [get_bd_intf_pins smc_hp0/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
# saxihp0_fpd_aclk está disponible tras conectar S_AXI_HP0_FPD
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]

# HP1: S2MM (escritura RX a DDR)
set smc_hp1 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_hp1]
set_property CONFIG.NUM_SI {1} [get_bd_cells smc_hp1]
connect_bd_net $sys_clk [get_bd_pins smc_hp1/aclk]
connect_bd_net $aresetn [get_bd_pins smc_hp1/aresetn]

connect_bd_intf_net [get_bd_intf_pins axi_mcdma_0/M_AXI_S2MM] \
                    [get_bd_intf_pins smc_hp1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_hp1/M00_AXI] \
                    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]
connect_bd_net $sys_clk [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk]

# -------------------------------------------------------------------------
# 5.5b  axis_switch: multiplexación AXI-Stream entre MCDMA y 14 UARTs
#
# MCDMA tiene UNA sola M_AXIS_MM2S y UNA S_AXIS_S2MM multiplexadas por TDEST.
# TX demux (1→14): MCDMA M_AXIS_MM2S (TDEST=canal) → axis_switch_tx → UART[i]
# RX mux  (14→1): UART[i] → axis_switch_rx → MCDMA S_AXIS_S2MM
#
# IMPORTANTE: el axis_switch NO inyecta TDEST=índice de slave; solo PROPAGA el
# TDEST que recibe del slave. Por eso cada UART_AXIS_TOP genera su propio
# M_AXIS_RX_TDEST = CH_ID (ver set_property CONFIG.CH_ID en create_transceiver_hier).
# Sin ese TDEST, todo el RX llegaría con TDEST=0 y el S2MM lo metería todo en
# el canal 0 (causa raíz del fallo de recepción multi-canal).
# -------------------------------------------------------------------------
puts "-> Creando axis_switch TX (1→14 demux) y RX (14→1 mux)..."

set sw_tx [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch axis_switch_tx]
set_property -dict [list \
    CONFIG.NUM_SI          {1}  \
    CONFIG.NUM_MI          {14} \
    CONFIG.TDEST_WIDTH     {4}  \
    CONFIG.TDATA_NUM_BYTES {1}  \
    CONFIG.ARB_ON_TLAST    {1}  \
] $sw_tx

set sw_rx [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_switch axis_switch_rx]
set_property -dict [list \
    CONFIG.NUM_SI          {14} \
    CONFIG.NUM_MI          {1}  \
    CONFIG.TDEST_WIDTH     {4}  \
    CONFIG.TDATA_NUM_BYTES {1}  \
    CONFIG.ARB_ON_TLAST    {1}  \
    CONFIG.ARB_ALGORITHM   {0}  \
] $sw_rx

connect_bd_net $sys_clk [get_bd_pins axis_switch_tx/aclk]
connect_bd_net $aresetn [get_bd_pins axis_switch_tx/aresetn]
connect_bd_net $sys_clk [get_bd_pins axis_switch_rx/aclk]
connect_bd_net $aresetn [get_bd_pins axis_switch_rx/aresetn]

# axis_dwidth_converter: MCDMA opera en 32-bit TDATA; UART y axis_switch en 8-bit.
# MM2S: MCDMA (32-bit) → dw_mm2s (32→8) → axis_switch_tx (8-bit)
# S2MM: axis_switch_rx (8-bit) → dw_s2mm (8→32) → MCDMA (32-bit)
# TDEST y demás señales laterales se propagan automáticamente por el conversor.
set dw_mm2s [create_bd_cell -type ip \
             -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dw_mm2s]
set_property -dict [list \
    CONFIG.S_TDATA_NUM_BYTES {4} \
    CONFIG.M_TDATA_NUM_BYTES {1} \
] $dw_mm2s

set dw_s2mm [create_bd_cell -type ip \
             -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dw_s2mm]
set_property -dict [list \
    CONFIG.S_TDATA_NUM_BYTES {1} \
    CONFIG.M_TDATA_NUM_BYTES {4} \
] $dw_s2mm

connect_bd_net $sys_clk [get_bd_pins axis_dw_mm2s/aclk]
connect_bd_net $aresetn [get_bd_pins axis_dw_mm2s/aresetn]
connect_bd_net $sys_clk [get_bd_pins axis_dw_s2mm/aclk]
connect_bd_net $aresetn [get_bd_pins axis_dw_s2mm/aresetn]

connect_bd_intf_net [get_bd_intf_pins axi_mcdma_0/M_AXIS_MM2S] \
                    [get_bd_intf_pins axis_dw_mm2s/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_dw_mm2s/M_AXIS] \
                    [get_bd_intf_pins axis_switch_tx/S00_AXIS]

connect_bd_intf_net [get_bd_intf_pins axis_switch_rx/M00_AXIS] \
                    [get_bd_intf_pins axis_dw_s2mm/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins axis_dw_s2mm/M_AXIS] \
                    [get_bd_intf_pins axi_mcdma_0/S_AXIS_S2MM]

# -------------------------------------------------------------------------
# 5.6  MCDMA control → SmartConnect config
# -------------------------------------------------------------------------
set mcdma_mi_idx [format "%02d" $num_transceivers]
connect_bd_intf_net \
    [get_bd_intf_pins smc_config/M${mcdma_mi_idx}_AXI] \
    [get_bd_intf_pins axi_mcdma_0/S_AXI_LITE]

# -------------------------------------------------------------------------
# 5.7  SysInfo (misma lógica que versión GPIO — driver C la sigue leyendo)
# -------------------------------------------------------------------------
puts "-> Creando bloque SysInfo..."
set sys_info [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_sys_info]
set_property -dict [list \
    CONFIG.C_IS_DUAL      {1} \
    CONFIG.C_ALL_INPUTS   {1} CONFIG.C_GPIO_WIDTH  {32} \
    CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {32} \
] $sys_info

set meta_val [expr {($uart_stride << 16) | $num_transceivers}]
set c_meta [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_meta]
set_property -dict [list CONFIG.CONST_VAL $meta_val CONFIG.CONST_WIDTH {32}] $c_meta

set c_base [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_base]
set_property -dict [list CONFIG.CONST_VAL $uart_base_addr CONFIG.CONST_WIDTH {32}] $c_base

connect_bd_net [get_bd_pins const_meta/dout]  [get_bd_pins axi_sys_info/gpio_io_i]
connect_bd_net [get_bd_pins const_base/dout]  [get_bd_pins axi_sys_info/gpio2_io_i]
connect_bd_net $sys_clk  [get_bd_pins axi_sys_info/s_axi_aclk]
connect_bd_net $aresetn  [get_bd_pins axi_sys_info/s_axi_aresetn]

set sysinfo_mi_idx [format "%02d" [expr {$num_transceivers + 1}]]
connect_bd_intf_net \
    [get_bd_intf_pins smc_config/M${sysinfo_mi_idx}_AXI] \
    [get_bd_intf_pins axi_sys_info/S_AXI]

# -------------------------------------------------------------------------
# 5.8  BUCLE: Crear 14 jerarquías Transceiver + conectar
# -------------------------------------------------------------------------
puts "-> Generando $num_transceivers jerarquías Transceiver..."

for {set i 0} {$i < $num_transceivers} {incr i} {
    # Crear jerarquía con UART_AXIS_TOP
    create_transceiver_hier $i

    set cell "Transceiver_${i}"
    set ch   [expr {$i + 1}]    ;# MCDMA usa índices 1-based

    # Reloj y reset
    connect_bd_net $sys_clk [get_bd_pins ${cell}/aclk]
    connect_bd_net $aresetn [get_bd_pins ${cell}/aresetn]

    # Config AXI-Lite desde SmartConnect GP0
    set mi_idx [format "%02d" $i]
    connect_bd_intf_net \
        [get_bd_intf_pins smc_config/M${mi_idx}_AXI] \
        [get_bd_intf_pins ${cell}/S_AXI]

    # AXI-Stream TX: axis_switch_tx M{i}_AXIS → Transceiver S_AXIS_TX
    connect_bd_intf_net \
        [get_bd_intf_pins axis_switch_tx/M${mi_idx}_AXIS] \
        [get_bd_intf_pins ${cell}/S_AXIS_TX]

    # AXI-Stream RX: Transceiver M_AXIS_RX → axis_switch_rx S{i}_AXIS
    connect_bd_intf_net \
        [get_bd_intf_pins ${cell}/M_AXIS_RX] \
        [get_bd_intf_pins axis_switch_rx/S${mi_idx}_AXIS]

    # Puertos físicos
    create_bd_port -dir I "UART_${i}_RX"
    create_bd_port -dir O "UART_${i}_TX"
    create_bd_port -dir O "UART_${i}_DE"
    create_bd_port -dir O "UART_${i}_SLO"

    connect_bd_net [get_bd_ports "UART_${i}_RX"] [get_bd_pins ${cell}/RD]
    connect_bd_net [get_bd_pins ${cell}/TD]      [get_bd_ports "UART_${i}_TX"]
    connect_bd_net [get_bd_pins ${cell}/DE]      [get_bd_ports "UART_${i}_DE"]
    connect_bd_net [get_bd_pins ${cell}/SLO]     [get_bd_ports "UART_${i}_SLO"]
}

# -------------------------------------------------------------------------
# 5.9  IRQ: MCDMA → PS
#   mm2s_introut → pl_ps_irq0  (GIC SPI 89 = IRQ ID 121)
#   s2mm_introut → pl_ps_irq1  (GIC SPI 90 = IRQ ID 122)
#
# NOTA: el MCDMA expone mm2s_introut y s2mm_introut como pines escalares
# directos (NO como bus interfaces). La función anterior usaba
# get_bd_intf_pins que devolvía vacío, desconectando silenciosamente las IRQ.
# -------------------------------------------------------------------------
puts "-> Conectando IRQ MCDMA al PS (vía xlconcat a pl_ps_irq0)..."

set mcdma_irq_concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 mcdma_irq_concat]
set_property CONFIG.NUM_PORTS 2 $mcdma_irq_concat

connect_bd_net [get_bd_pins axi_mcdma_0/mm2s_introut] [get_bd_pins mcdma_irq_concat/In0]
connect_bd_net [get_bd_pins axi_mcdma_0/s2mm_introut] [get_bd_pins mcdma_irq_concat/In1]
connect_bd_net [get_bd_pins mcdma_irq_concat/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# -------------------------------------------------------------------------
# 5.10  Relojes AXI huérfanos (fix robustez)
# -------------------------------------------------------------------------
foreach pin_name {maxihpm1_fpd_aclk maxihpm0_lpd_aclk} {
    set p [get_bd_pins -quiet zynq_ultra_ps_e_0/$pin_name]
    if { $p ne "" && [get_bd_nets -quiet -of_objects $p] eq "" } {
        connect_bd_net $sys_clk $p
    }
}

# =========================================================================
# 6. ASIGNACIÓN DE DIRECCIONES
# =========================================================================
puts "-> Asignando mapa de memoria..."
set seg "zynq_ultra_ps_e_0/Data"

# 14 UARTs: AXI-Lite config
# Los módulos RTL referenciados pueden usar nombres de segmento distintos de "Reg";
# usar wildcard para obtener sea cual sea el nombre que Vivado infiere.
for {set i 0} {$i < $num_transceivers} {incr i} {
    set addr [expr {$uart_base_addr + ($i * $uart_stride)}]
    set uart_segs [get_bd_addr_segs -quiet "Transceiver_${i}/uart_top/S_AXI/*"]
    if { $uart_segs ne "" } {
        assign_bd_address \
            -target_address_space $seg \
            $uart_segs \
            -force -offset [format "0x%08X" $addr] -range 4K
    } else {
        puts "WARNING: No se encontró segmento en Transceiver_${i}/uart_top/S_AXI — omitido"
    }
}

# MCDMA: registros de control (256 KB para cubrir todos los canales)
assign_bd_address \
    -target_address_space $seg \
    [get_bd_addr_segs axi_mcdma_0/S_AXI_LITE/Reg] \
    -force -offset [format "0x%08X" $mcdma_ctrl_addr] -range 256K

# SysInfo
assign_bd_address \
    -target_address_space $seg \
    [get_bd_addr_segs axi_sys_info/S_AXI/Reg] \
    -force -offset [format "0x%08X" $sys_info_addr] -range 4K

# MCDMA master interfaces: asignar DDR_LOW y excluir segmentos no-DDR.
# Sin esto, validate_bd_design emite CRITICAL WARNINGs por cada segmento
# del PS visible desde HP0/HP1 que no esté asignado ni excluido.
set hp0_spaces {axi_mcdma_0/Data_SG axi_mcdma_0/Data_MM2S}
set hp0_non_ddr {HP0_QSPI HP0_PCIE_LOW HP0_PCIE_HIGH1 HP0_PCIE_HIGH2 HP0_LPS_OCM HP0_DDR_HIGH}
foreach sp $hp0_spaces {
    set ddr [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW]
    if { $ddr ne "" } { assign_bd_address -target_address_space $sp $ddr -force }
    foreach name $hp0_non_ddr {
        set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP2/$name]
        if { $s ne "" } { exclude_bd_addr_seg $s -target_address_space $sp }
    }
}
set hp1_non_ddr {HP1_QSPI HP1_PCIE_LOW HP1_PCIE_HIGH1 HP1_PCIE_HIGH2 HP1_LPS_OCM HP1_DDR_HIGH}
set ddr1 [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW]
if { $ddr1 ne "" } { assign_bd_address -target_address_space axi_mcdma_0/Data_S2MM $ddr1 -force }
foreach name $hp1_non_ddr {
    set s [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/SAXIGP3/$name]
    if { $s ne "" } { exclude_bd_addr_seg $s -target_address_space axi_mcdma_0/Data_S2MM }
}

# =========================================================================
# 7. VALIDACIÓN Y WRAPPER
# =========================================================================
puts "-> Validando diseño..."
validate_bd_design
save_bd_design

set bd_file      [get_files system.bd]
set wrapper_path [make_wrapper -fileset sources_1 -files $bd_file -top]
add_files -norecurse -fileset sources_1 $wrapper_path

set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " GENERACIÓN COMPLETADA"
puts ""
puts " Mapa de memoria:"
puts "   [format 0x%08X $uart_base_addr]  UART_0  AXI-Lite config"
set last_uart_addr [expr {$uart_base_addr + ($num_transceivers - 1) * $uart_stride}]
puts "   [format 0x%08X $last_uart_addr]  UART_13 AXI-Lite config"
puts "   [format 0x%08X $sys_info_addr]  SysInfo (count/base para driver C)"
puts "   [format 0x%08X $mcdma_ctrl_addr]  AXI MCDMA registros de control"
puts ""
puts " IRQs (ajustar IRQ_MCDMA_* en transceiver.h si difieren):"
puts "   pl_ps_irq0 = mm2s_introut  (TX completado)"
puts "   pl_ps_irq1 = s2mm_introut  (RX disponible)"
puts ""
puts " Para obtener los vectores GIC exactos, revisar el .dtb generado:"
puts "   dtc -I dtb -O dts system.dtb | grep -A5 mcdma"
puts ""
puts " Siguiente paso: Generate Bitstream"
puts "================================================================"
