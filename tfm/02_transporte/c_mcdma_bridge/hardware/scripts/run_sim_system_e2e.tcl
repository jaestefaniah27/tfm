# run_sim_system_e2e.tcl
# =============================================================================
# Simulación end-to-end del sistema completo:
#   BRIDGE_TOP (N_CH=2) + BRIDGE_UART_ADAPTER + MULTI_SERIAL_CORE
#
# Escenarios verificados:
#   TEST-1  TX canal-0 (2 bytes) con loopback físico → verificar RX en m_axis
#   TEST-2  TX canal-0 y canal-1 simultáneo con loopback → verificar ambos
#   TEST-3  Inyección serie directa en canal-1 → verificar RX sin ruta TX
#
# Uso (desde hardware/):
#   vivado -mode batch -source scripts/run_sim_system_e2e.tcl
# =============================================================================

set proj_name "tb_sys_e2e"
set part      "xczu9eg-ffvb1156-2-e"

# Rutas absolutas derivadas de la ubicación de este script
set script_dir   [file dirname [file normalize [info script]]]
set hw_dir       [file normalize [file join $script_dir ".."]]
set proj_dir     [file join $hw_dir "sim_proj_e2e"]
set new_dir      [file join $hw_dir "serial_bridge" "serial_bridge.srcs" "sources_1" "new"]
set ip_src       [file join $hw_dir "ip_repo" "multi_serial_core" "src"]
set sim_dir      [file join $hw_dir "sim"]

puts "================================================================"
puts " hw_dir  = $hw_dir"
puts " new_dir = $new_dir"
puts " ip_src  = $ip_src"
puts "================================================================"

# Verificar que los directorios existen
foreach d [list $new_dir $ip_src $sim_dir] {
    if {![file isdirectory $d]} {
        error "Directorio no encontrado: $d"
    }
}

# =============================================================================
# 1. Crear proyecto de simulación (borrar el anterior primero)
# =============================================================================
file delete -force $proj_dir
create_project -force $proj_name $proj_dir -part $part
set_property target_language VHDL [current_project]

# =============================================================================
# 2. RTL: añadir TODOS los ficheros directamente a sim_1 en orden de compilación
#    (RTL → testbench). Esto garantiza que Vivado los incluye en el compile.sh.
# =============================================================================
set all_vhd [list \
    [file join $ip_src NCO.vhd]                     \
    [file join $ip_src ShiftRegister.vhd]           \
    [file join $ip_src RX_CONFIGURABLE_SERIAL.vhd]  \
    [file join $ip_src TX_CONFIGURABLE_SERIAL.vhd]  \
    [file join $ip_src CONFIGURABLE_SERIAL.vhd]     \
    [file join $ip_src CONFIGURABLE_SERIAL_TOP.vhd] \
    [file join $ip_src MULTI_SERIAL_CORE.vhd]       \
    [file join $new_dir TX_DMA_ROUTER.vhd]          \
    [file join $new_dir MUX_2x16.vhd]               \
    [file join $new_dir TX_WORKER.vhd]              \
    [file join $new_dir TX_ISR_EOF_HANDLER.vhd]     \
    [file join $new_dir BRIDGE_TX_TOP.vhd]          \
    [file join $new_dir BRIDGE_RX_FIFO_FILL.vhd]    \
    [file join $new_dir BRIDGE_RX_FIFO_DEMUX.vhd]   \
    [file join $new_dir BRIDGE_RX_FIFO_DRAIN.vhd]   \
    [file join $new_dir BRIDGE_RX_TOP.vhd]          \
    [file join $new_dir AXI_UART_CONFIG.vhd]        \
    [file join $new_dir BRIDGE_TOP.vhd]             \
    [file join $new_dir BRIDGE_UART_ADAPTER.vhd]    \
]

foreach vhd $all_vhd {
    if {![file exists $vhd]} { error "Fichero no encontrado: $vhd" }
    puts "   add_sim: $vhd"
    add_files -fileset sim_1 -norecurse $vhd
}

# Marcar como VHDL-2008 todos los ficheros de sim_1 (excepto el tb que se añade después)
set sim_rtl [get_files -of_objects [get_filesets sim_1] -filter {FILE_TYPE == VHDL}]
puts "-> [llength $sim_rtl] ficheros VHDL en sim_1; marcando como VHDL 2008..."
set_property file_type {VHDL 2008} $sim_rtl

# =============================================================================
# 3. IP FIFO: fifo_tx (8-bit, FWFT, para TX_WORKER)
# =============================================================================
puts "-> Generando IP fifo_tx (8-bit, FWFT, 512 deep)..."
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
# 4. IP FIFO: fifo_generator_0 (9-bit, FWFT, para CONFIGURABLE_SERIAL RX)
# =============================================================================
puts "-> Generando IP fifo_generator_0 (9-bit, FWFT, 512 deep)..."
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name fifo_generator_0
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
generate_target {simulation} [get_ips fifo_generator_0]

# =============================================================================
# 5. IP FIFO: common_fifo_rx (8-bit, FWFT, 512 deep, prog_full @509)
# =============================================================================
puts "-> Generando IP common_fifo_rx (8-bit, FWFT, 512 deep, prog_full)..."
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name common_fifo_rx
set_property -dict [list \
    CONFIG.Performance_Options             {First_Word_Fall_Through}                  \
    CONFIG.Input_Data_Width                {8}                                        \
    CONFIG.Input_Depth                     {512}                                      \
    CONFIG.Output_Data_Width               {8}                                        \
    CONFIG.Reset_Type                      {Synchronous_Reset}                        \
    CONFIG.Full_Flags_Reset_Value          {0}                                        \
    CONFIG.Use_Dout_Reset                  {true}                                     \
    CONFIG.Programmable_Full_Type          {Single_Programmable_Full_Threshold_Constant} \
    CONFIG.Full_Threshold_Assert_Value     {509}                                      \
] [get_ips common_fifo_rx]
generate_target {simulation} [get_ips common_fifo_rx]

# =============================================================================
# 6. Testbench
# =============================================================================
puts "-> Añadiendo testbench tb_system_e2e.vhd..."
set tb_file [file join $sim_dir tb_system_e2e.vhd]
if {![file exists $tb_file]} { error "Testbench no encontrado: $tb_file" }
add_files -fileset sim_1 -norecurse $tb_file
set_property file_type {VHDL 2008} [get_files $tb_file]

# Modo manual: compilar en el orden de inserción, top fijo
set_property source_mgmt_mode None [current_project]
set_property top     tb_system_e2e [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "-> Simulation top: [get_property top [get_filesets sim_1]]"

# =============================================================================
# 7. Propiedades de simulación
# =============================================================================
set_property -name {xsim.elaborate.debug_level}    -value {off}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
# Runtime 0 → corre hasta std.env.stop (llamado desde el testbench)
set_property -name {xsim.simulate.runtime}         -value {0}     -objects [get_filesets sim_1]

# =============================================================================
# 8. Ejecutar simulación
# =============================================================================
puts "-> Lanzando simulación behavioral del sistema E2E..."
puts "   (baud_sel=43 → 921600 baud; tiempo estimado: ~30 µs de simulación)"
launch_simulation
run all

puts ""
puts "================================================================"
puts " Simulación terminada."
puts " Busca 'SIM_RESULT: PASS' o 'SIM_RESULT: FAIL' arriba."
puts "================================================================"
