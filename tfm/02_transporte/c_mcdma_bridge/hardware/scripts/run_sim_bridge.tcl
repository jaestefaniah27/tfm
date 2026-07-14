# run_sim_bridge.tcl
# =========================================================================
# Simulación behavioral del BRIDGE_TX_TOP: stream de la DMA MM2S (AXI-Stream)
# -> router -> demux -> 14 TX_WORKER (FIFO) -> 14 cores UART (a baud máximo).
# Verifica el enrutado y el lanzamiento de envíos decodificando las líneas
# serie TD de cada canal.
#
# Uso (desde hardware/):
#   vivado -mode batch -source scripts/run_sim_bridge.tcl
#
# Veredicto: busca "SIM_RESULT: PASS" / "SIM_RESULT: FAIL" en la salida.
# =========================================================================

set proj_name "tb_bridge_sim"
set proj_dir  "./sim_proj_bridge"
set src_dir   "./src"
set sim_dir   "./sim"
set new_dir   "./serial_bridge/serial_bridge.srcs/sources_1/new"
set part      "xczu9eg-ffvb1156-2-e"

puts "================================================================"
puts " SIMULACIÓN: BRIDGE_TX_TOP (DMA AXI-Stream -> 14 UART TX)"
puts "================================================================"

# ── 1. Proyecto ────────────────────────────────────────────────────────────
create_project -force $proj_name $proj_dir -part $part
set_property target_language VHDL [current_project]

# ── 2. RTL del core UART (la cadena TX/RX configurable) ────────────────────
add_files -norecurse [list \
    $src_dir/NCO.vhd                     \
    $src_dir/ShiftRegister.vhd           \
    $src_dir/RX_CONFIGURABLE_SERIAL.vhd  \
    $src_dir/TX_CONFIGURABLE_SERIAL.vhd  \
    $src_dir/CONFIGURABLE_SERIAL.vhd     \
    $src_dir/CONFIGURABLE_SERIAL_TOP.vhd ]

# ── 3. RTL nuevo del puente ────────────────────────────────────────────────
add_files -norecurse [list \
    $new_dir/TX_DMA_ROUTER.vhd      \
    $new_dir/MUX_2x16.vhd           \
    $new_dir/TX_WORKER.vhd          \
    $new_dir/TX_ISR_EOF_HANDLER.vhd \
    $new_dir/BRIDGE_TX_TOP.vhd ]

# Compilados como VHDL-2008 por consistencia (no es estrictamente necesario).
set_property file_type {VHDL 2008} [get_files $new_dir/TX_DMA_ROUTER.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/MUX_2x16.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/TX_WORKER.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/TX_ISR_EOF_HANDLER.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/BRIDGE_TX_TOP.vhd]

# ── 4a. FIFO de TX del puente (8 bits, FWFT) — componente 'fifo_tx' ────────
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name fifo_tx
set_property -dict [list \
    CONFIG.Performance_Options    {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width       {8}                       \
    CONFIG.Input_Depth            {512}                      \
    CONFIG.Reset_Type             {Synchronous_Reset}        \
    CONFIG.Full_Flags_Reset_Value {0}                        \
    CONFIG.Use_Dout_Reset         {true}                     \
] [get_ips fifo_tx]
generate_target {simulation} [get_ips fifo_tx]

# ── 4b. FIFO de RX del core UART (9 bits, FWFT) — componente 'fifo_generator_0'
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name fifo_generator_0
set_property -dict [list \
    CONFIG.Interface_Type         {Native}                  \
    CONFIG.Performance_Options    {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width       {9}                       \
    CONFIG.Input_Depth            {512}                      \
    CONFIG.Output_Data_Width      {9}                       \
    CONFIG.Reset_Type             {Synchronous_Reset}       \
    CONFIG.Full_Flags_Reset_Value {0}                       \
    CONFIG.Use_Dout_Reset         {true}                    \
] [get_ips fifo_generator_0]
generate_target {simulation} [get_ips fifo_generator_0]

# ── 5. Testbench (VHDL-2008: to_hstring, std.env.stop, tipo protegido) ─────
add_files -fileset sim_1 -norecurse $sim_dir/tb_bridge_tx.vhd
set_property file_type {VHDL 2008} [get_files $sim_dir/tb_bridge_tx.vhd]
set_property top tb_bridge_tx [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property -name {xsim.elaborate.debug_level} -value {off}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {0}          -objects [get_filesets sim_1]

# ── 6. Ejecutar xsim hasta std.env.stop ────────────────────────────────────
puts "-> Lanzando simulación behavioral del puente..."
launch_simulation
run all

puts "================================================================"
puts " Simulación terminada. Busca 'SIM_RESULT:' arriba."
puts "================================================================"
</content>
