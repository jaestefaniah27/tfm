# rebuild_mcdma_pcb.tcl — reimplementa el proyecto MCDMA LIMPIO (sin loopback),
# el que necesita la caracterización de la PCB.
#
# Por qué hace falta: el .bit de impl_1 es del 8-jul, y el fix del DRAIN
# (MAX_PKT=256, para no bloquear el buffer store-and-forward del S2MM) entró en
# el RTL el 13-jul. El bitstream que hay implementado NO lo lleva.
#
# BRIDGE_AND_SERIALs es un MODULE REFERENCE del block design: Vivado cachea su
# .dcp fuera de contexto. Sin update_module_reference + reset_run, el top lo toma
# como caja negra y los cambios del RTL se pierden EN SILENCIO.
#
#   vivado -mode batch -source rebuild_mcdma_pcb.tcl

set xpr /home/mpsocv2/quick-start/app/serial_bridge/hardware/serial_bridge/serial_bridge.xpr
open_project $xpr

set MODREF system_mcdma_BRIDGE_AND_SERIALs_0_0

open_bd_design [get_files system_mcdma.bd]
update_module_reference $MODREF
save_bd_design
close_bd_design [get_bd_designs system_mcdma]

if {[llength [get_runs -quiet ${MODREF}_synth_1]]} {
    reset_run ${MODREF}_synth_1
}
reset_run synth_1

launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: synth_1 fallo"
    exit 1
}

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: impl_1 fallo"
    exit 1
}

open_run impl_1
puts "===== WNS=[get_property SLACK [get_timing_paths -delay_type max]]  WHS=[get_property SLACK [get_timing_paths -delay_type min]]"
puts "===== OK bitstream: [get_property DIRECTORY [get_runs impl_1]]/system_mcdma_wrapper.bit"
close_project
