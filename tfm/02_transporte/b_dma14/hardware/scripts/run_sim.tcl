# run_sim.tcl
# =========================================================================
# Simulación behavioral del camino de datos PL del UART, aislado del DMA y
# de RTEMS/PS. Compila el RTL del UART + el fifo_generator IP + el testbench
# tb_uart_axis_loopback y ejecuta xsim en batch.
#
# Iteración rápida: edita el RTL o el TB y re-ejecuta — segundos, sin bitstream.
#
# Uso (desde hardware/):
#   vivado -mode batch -source scripts/run_sim.tcl
#
# Veredicto: busca "SIM_RESULT: PASS" / "SIM_RESULT: FAIL" en la salida.
# =========================================================================

set proj_name "tb_uart_sim"
set proj_dir  "./sim_proj"
set src_dir   "./src"
set sim_dir   "./sim"
set part      "xczu9eg-ffvb1156-2-e"

puts "================================================================"
puts " SIMULACIÓN: UART_AXIS_TOP loopback (TD→RD), aislado de DMA/PS"
puts "================================================================"

# ── 1. Proyecto ──────────────────────────────────────────────────────────
create_project -force $proj_name $proj_dir -part $part
set_property target_language VHDL [current_project]

# ── 2. RTL del UART (sin MULTI_SERIAL_CORE: no se usa aquí) ──────────────
add_files -norecurse [list \
    $src_dir/NCO.vhd                     \
    $src_dir/ShiftRegister.vhd           \
    $src_dir/RX_CONFIGURABLE_SERIAL.vhd  \
    $src_dir/TX_CONFIGURABLE_SERIAL.vhd  \
    $src_dir/CONFIGURABLE_SERIAL.vhd     \
    $src_dir/CONFIGURABLE_SERIAL_TOP.vhd \
    $src_dir/UART_AXIS_TOP.vhd           ]

# ── 3. FIFO IP que usa el RX (mismo config que el diseño real) ──────────
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
generate_target {simulation} [get_ips fifo_generator_0]

# ── 4. Testbench (VHDL-2008 por to_hstring / std.env.stop) ──────────────
add_files -fileset sim_1 -norecurse $sim_dir/tb_uart_axis_loopback.vhd
set_property file_type {VHDL 2008} \
    [get_files $sim_dir/tb_uart_axis_loopback.vhd]
set_property top tb_uart_axis_loopback [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# ── 5. xsim rápido: las señales internas del RX salen por el puerto dbg_rx,
#    así que no hace falta visibilidad de debug ni volcado de waveform.
set_property -name {xsim.elaborate.debug_level} -value {off} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]

# ── 6. Ejecutar xsim hasta std.env.stop ─────────────────────────────────
puts "-> Lanzando simulación behavioral..."
launch_simulation
run all

puts "================================================================"
puts " Simulación terminada. Busca 'SIM_RESULT:' arriba."
puts "================================================================"
