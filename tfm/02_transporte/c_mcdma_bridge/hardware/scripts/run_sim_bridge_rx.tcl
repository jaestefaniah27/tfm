# run_sim_bridge_rx.tcl
# =========================================================================
# Simulacion behavioral del BRIDGE_RX_TOP: 14 FIFOs RX de transceivers
# -> FIFO comun -> AXI-Stream master hacia DMA.
#
# Uso (desde hardware/):
#   vivado -mode batch -source scripts/run_sim_bridge_rx.tcl
#
# Veredicto: busca "SIM_RESULT: PASS" / "SIM_RESULT: FAIL" en la salida.
# =========================================================================

set proj_name "tb_bridge_rx_sim"
set proj_dir  "./sim_proj_bridge_rx"
set sim_dir   "./sim"
set new_dir   "./serial_bridge/serial_bridge.srcs/sources_1/new"
set part      "xczu9eg-ffvb1156-2-e"

puts "================================================================"
puts " SIMULACION: BRIDGE_RX_TOP (14 UART RX -> FIFO comun -> DMA)"
puts "================================================================"

# ── 1. Proyecto ────────────────────────────────────────────────────────────
create_project -force $proj_name $proj_dir -part $part
set_property target_language VHDL [current_project]

# ── 2. RTL del receptor ────────────────────────────────────────────────────
add_files -norecurse [list \
    $new_dir/BRIDGE_RX_FIFO_DEMUX.vhd \
    $new_dir/BRIDGE_RX_FIFO_FILL.vhd  \
    $new_dir/BRIDGE_RX_FIFO_DRAIN.vhd \
    $new_dir/BRIDGE_RX_TOP.vhd        ]

set_property file_type {VHDL 2008} [get_files $new_dir/BRIDGE_RX_FIFO_DEMUX.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/BRIDGE_RX_FIFO_FILL.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/BRIDGE_RX_FIFO_DRAIN.vhd]
set_property file_type {VHDL 2008} [get_files $new_dir/BRIDGE_RX_TOP.vhd]

# ── 3. FIFO comun RX (8 bits, 512 profundidad, FWFT, reset sincrono,
#        prog_full constante en 509) ────────────────────────────────────────
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name common_fifo_rx

set_property -dict [list \
    CONFIG.Performance_Options              {First_Word_Fall_Through}                   \
    CONFIG.Input_Data_Width                 {8}                                         \
    CONFIG.Input_Depth                      {512}                                       \
    CONFIG.Output_Data_Width                {8}                                         \
    CONFIG.Reset_Type                       {Synchronous_Reset}                         \
    CONFIG.Full_Flags_Reset_Value           {0}                                         \
    CONFIG.Use_Dout_Reset                   {true}                                      \
    CONFIG.Enable_Safety_Circuit            {false}                                     \
    CONFIG.Programmable_Full_Type           {Single_Programmable_Full_Threshold_Constant} \
    CONFIG.Full_Threshold_Assert_Value      {509}                                       \
    CONFIG.Full_Threshold_Negate_Value      {508}                                       \
] [get_ips common_fifo_rx]

generate_target {simulation} [get_ips common_fifo_rx]

# ── 4. Testbench (VHDL-2008) ───────────────────────────────────────────────
add_files -fileset sim_1 -norecurse $sim_dir/tb_bridge_rx.vhd
set_property file_type {VHDL 2008} [get_files $sim_dir/tb_bridge_rx.vhd]
set_property top tb_bridge_rx [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property -name {xsim.elaborate.debug_level}    -value {off}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime}         -value {0}     -objects [get_filesets sim_1]

# ── 5. Lanzar hasta std.env.stop ───────────────────────────────────────────
puts "-> Compilando y lanzando simulacion behavioral..."
launch_simulation
run all

puts "================================================================"
puts " Simulacion terminada. Busca 'SIM_RESULT:' arriba."
puts "================================================================"
