# rebuild_mcdma_drain.tcl — re-sintetiza 03_MCDMA con el DRAIN corregido.
#
# OJO (2026-07-13): BRIDGE_AND_SERIALs es un MODULE REFERENCE del block design.
# Vivado lo sintetiza fuera de contexto y CACHEA su .dcp. Si no se refresca el
# module_ref y no se resetea SU run, el top-level lo toma como caja negra (stub) y
# el bitstream sigue llevando el RTL viejo: los cambios en BRIDGE_RX_FIFO_DRAIN.vhd
# se pierden EN SILENCIO. El .dcp llevaba clavado desde el 9-jul.
#
#   vivado -mode batch -source common/rebuild_mcdma_drain.tcl

set xpr /home/mpsocv2/quick-start/app/bench_loopback/03_MCDMA/hardware/serial_bridge.xpr
open_project $xpr

set MODREF system_mcdma_BRIDGE_AND_SERIALs_0_0

# 1) Releer el RTL del module reference (puertos + cuerpo)
open_bd_design [get_files system_mcdma.bd]
update_module_reference $MODREF
save_bd_design
close_bd_design [get_bd_designs system_mcdma]

# 2) Forzar la re-sintesis del OOC y del top.
# update_module_reference ya suele ELIMINAR el run OOC viejo (y con el, su .dcp
# cacheado), asi que este reset_run puede no encontrar nada: no es un error.
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
puts "===== OK"
close_project
