# run_sim_rx_axis_mc.tcl
# =========================================================================
# Simulación behavioral del RX_AXIS_MC:
#   14 canales UART → 1 AXI-Stream + TDEST + tlast por timeout.
#
# Tests: 1-byte, multi-byte, timeout latched, timeout obsoleto,
#        round-robin, back-to-back, back-pressure tready lento.
#
# Uso (desde hardware/):
#   vivado -mode batch -source scripts/run_sim_rx_axis_mc.tcl
#
# Veredicto: busca "SIM_RESULT: PASS" / "SIM_RESULT: FAIL" en la salida.
# =========================================================================

set proj_name "tb_rx_axis_mc_sim"
set proj_dir  "./sim_proj_rx_axis_mc"
set new_dir   "./serial_bridge/serial_bridge.srcs/sources_1/new"
set sim_dir   "./sim"
set part      "xczu9eg-ffvb1156-2-e"

puts "================================================================"
puts " SIMULACIÓN: RX_AXIS_MC (14 UART -> AXI-Stream TDEST + tlast)"
puts "================================================================"

# ── 1. Proyecto ────────────────────────────────────────────────────────────
create_project -force $proj_name $proj_dir -part $part
set_property target_language VHDL [current_project]

# ── 2. RTL bajo test ───────────────────────────────────────────────────────
add_files -norecurse $new_dir/RX_AXIS_MC.vhd
set_property file_type {VHDL 2008} [get_files $new_dir/RX_AXIS_MC.vhd]

# ── 3. Testbench ───────────────────────────────────────────────────────────
add_files -fileset sim_1 -norecurse $sim_dir/tb_rx_axis_mc.vhd
set_property file_type {VHDL 2008} [get_files $sim_dir/tb_rx_axis_mc.vhd]
set_property top tb_rx_axis_mc [get_filesets sim_1]

set_property source_mgmt_mode None [current_project]
set_property top tb_rx_axis_mc      [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property -name {xsim.elaborate.debug_level}    -value {off}   -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.runtime}         -value {0}     -objects [get_filesets sim_1]

# ── 4. Lanzar ──────────────────────────────────────────────────────────────
puts "-> Lanzando simulación behavioral..."
launch_simulation
run all

puts "================================================================"
puts " Simulación terminada. Busca 'SIM_RESULT:' arriba."
puts "================================================================"
