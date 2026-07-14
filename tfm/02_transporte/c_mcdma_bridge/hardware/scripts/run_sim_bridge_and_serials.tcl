# run_sim_bridge_and_serials.tcl
# =============================================================================
# Simulación de BRIDGE_AND_SERIALs (N_CH=2):
#   BRIDGE_AND_SERIALs contiene BRIDGE_TOP + 2×CONFIGURABLE_SERIAL
#   BRIDGE_TOP contiene BRIDGE_TX_TOP + BRIDGE_RX_TOP + AXI_UART_CONFIG (Verilog)
#
# Uso (desde hardware/):
#   vivado -mode batch -source scripts/run_sim_bridge_and_serials.tcl
# =============================================================================

set proj_name "sim_bridge_and_serials"
set part      "xczu9eg-ffvb1156-2-e"

set script_dir [file dirname [file normalize [info script]]]
set hw_dir     [file normalize [file join $script_dir ".."]]
set proj_dir   [file join $hw_dir "sim_proj_bridge_and_serials"]
set new_dir    [file join $hw_dir "serial_bridge" "serial_bridge.srcs" "sources_1" "new"]
set imp_dir    [file join $hw_dir "serial_bridge" "serial_bridge.srcs" "sources_1" "imports" "src"]
set gen_ip_dir [file join $hw_dir "serial_bridge" "serial_bridge.gen" "sources_1" "ip" "AXI_UART_CONFIG_0"]
set sim_dir    [file join $hw_dir "sim"]

puts "================================================================"
puts " hw_dir    = $hw_dir"
puts " new_dir   = $new_dir"
puts " imp_dir   = $imp_dir"
puts " gen_ip_dir= $gen_ip_dir"
puts "================================================================"

foreach d [list $new_dir $imp_dir $gen_ip_dir $sim_dir] {
    if {![file isdirectory $d]} { error "Directorio no encontrado: $d" }
}

# =============================================================================
# 1. Crear proyecto (borrando el anterior)
# =============================================================================
file delete -force $proj_dir
create_project -force $proj_name $proj_dir -part $part
set_property target_language VHDL [current_project]

# =============================================================================
# 2. RTL VHDL: orden de compilación bottom-up
# =============================================================================
set vhd_files [list \
    [file join $imp_dir NCO.vhd]                       \
    [file join $imp_dir ShiftRegister.vhd]             \
    [file join $imp_dir RX_CONFIGURABLE_SERIAL.vhd]    \
    [file join $imp_dir TX_CONFIGURABLE_SERIAL.vhd]    \
    [file join $imp_dir CONFIGURABLE_SERIAL.vhd]       \
    [file join $new_dir TX_DMA_ROUTER.vhd]            \
    [file join $new_dir MUX_2x16.vhd]                 \
    [file join $new_dir TX_WORKER.vhd]                \
    [file join $new_dir TX_ISR_EOF_HANDLER.vhd]       \
    [file join $new_dir BRIDGE_TX_TOP.vhd]            \
    [file join $new_dir BRIDGE_RX_FIFO_DEMUX.vhd]    \
    [file join $new_dir BRIDGE_RX_FIFO_DRAIN.vhd]    \
    [file join $new_dir BRIDGE_RX_TOP.vhd]            \
    [file join $new_dir BRIDGE_TOP.vhd]               \
    [file join $new_dir BRIDGE_AND_SERIALs.vhd]      \
]

foreach f $vhd_files {
    if {![file exists $f]} { error "Fichero no encontrado: $f" }
    add_files -fileset sim_1 -norecurse $f
}
set vhd_rtl [get_files -of_objects [get_filesets sim_1] -filter {FILE_TYPE == VHDL}]
set_property file_type {VHDL 2008} $vhd_rtl

# =============================================================================
# 3. Verilog IP core AXI_UART_CONFIG_0: usar los archivos generados por Vivado
#    sim/AXI_UART_CONFIG_0.v  = wrapper con module AXI_UART_CONFIG_0
#    hdl/*.v                  = implementación subyacente
# =============================================================================
set vlog_files [list \
    [file join $gen_ip_dir "hdl" "AXI_UART_CONFIG_slave_lite_v1_0_S00_AXI.v"] \
    [file join $gen_ip_dir "hdl" "AXI_UART_CONFIG.v"]                          \
    [file join $gen_ip_dir "sim" "AXI_UART_CONFIG_0.v"]                        \
]
foreach f $vlog_files {
    if {![file exists $f]} { error "Fichero Verilog no encontrado: $f" }
    add_files -fileset sim_1 -norecurse $f
    set_property library xil_defaultlib [get_files $f]
}

# =============================================================================
# 4. IP: fifo_tx (8 bits, FWFT, 512 deep) — para TX_WORKER
# =============================================================================
puts "-> Generando IP fifo_tx..."
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name fifo_tx
set_property -dict [list \
    CONFIG.Performance_Options    {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width       {8}                       \
    CONFIG.Input_Depth            {512}                     \
    CONFIG.Reset_Type             {Synchronous_Reset}       \
    CONFIG.Full_Flags_Reset_Value {0}                       \
    CONFIG.Use_Dout_Reset         {true}                    \
] [get_ips fifo_tx]
generate_target {simulation} [get_ips fifo_tx]

# =============================================================================
# 5. IP: fifo_rx (9 bits, FWFT, 512 deep, prog_full) — para CONFIGURABLE_SERIAL
# =============================================================================
puts "-> Generando IP fifo_rx (9-bit, prog_full)..."
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name fifo_rx
set_property -dict [list \
    CONFIG.Interface_Type              {Native}                  \
    CONFIG.Performance_Options         {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width            {9}                       \
    CONFIG.Input_Depth                 {512}                     \
    CONFIG.Output_Data_Width           {9}                       \
    CONFIG.Reset_Type                  {Synchronous_Reset}       \
    CONFIG.Full_Flags_Reset_Value      {0}                       \
    CONFIG.Use_Dout_Reset              {true}                    \
    CONFIG.Almost_Full_Flag            {false}                   \
    CONFIG.Programmable_Full_Type      {Single_Programmable_Full_Threshold_Constant} \
    CONFIG.Full_Threshold_Assert_Value {480}                     \
] [get_ips fifo_rx]
generate_target {simulation} [get_ips fifo_rx]

# =============================================================================
# 6. Testbench
# =============================================================================
set tb_file [file join $sim_dir tb_bridge_and_serials.vhd]
if {![file exists $tb_file]} { error "Testbench no encontrado: $tb_file" }
add_files -fileset sim_1 -norecurse $tb_file
set_property file_type {VHDL 2008} [get_files $tb_file]

# =============================================================================
# 7. Propiedades de simulación
# =============================================================================
set_property top     tb_bridge_and_serials [get_filesets sim_1]
set_property top_lib xil_defaultlib        [get_filesets sim_1]

set_property -name {xsim.elaborate.debug_level}    -value {off}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime}         -value {0}     -objects [get_filesets sim_1]

# =============================================================================
# 8. Ejecutar simulación
# =============================================================================
puts "-> Lanzando simulacion BRIDGE_AND_SERIALs (N_CH=2)..."
puts "   Tiempo estimado sim: ~55 us (3 tests x ~18 us)"
launch_simulation
run all

puts ""
puts "================================================================"
puts " Busca 'SIM_RESULT: PASS' o 'SIM_RESULT: FAIL' arriba."
puts "================================================================"
