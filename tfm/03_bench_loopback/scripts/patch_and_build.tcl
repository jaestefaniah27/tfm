# patch_and_build.tcl — inserta bench_loopback en un block design y re-implementa.
#
# Uso:
#   vivado -mode batch -source patch_and_build.tcl -tclargs <xpr> <bd> <estilo> <jobs>
#     estilo = scalar  (GPIO y DMA14: pines Transceiver_i/TD y /RD)
#            = vector  (MCDMA: bus BRIDGE_AND_SERIALs_0/TD y /RD)
#
# Qué hace: desconecta las líneas de recepción de los puertos físicos y las
# alimenta desde el loopback, dejando las de transmisión llegando además a los
# pines. Los puertos RX externos quedan sin carga a propósito: así los
# constraints de pines siguen siendo válidos y no hay que tocar el XDC.

if {[llength $argv] < 4} {
    puts "ERROR: faltan argumentos: <xpr> <bd> <scalar|vector> <jobs>"
    exit 1
}
set xpr   [lindex $argv 0]
set bdname [lindex $argv 1]
set style [lindex $argv 2]
set jobs  [lindex $argv 3]

set common [file dirname [file normalize [info script]]]

puts "\n===== abriendo $xpr"
open_project $xpr

# ── Añadir las fuentes del loopback ────────────────────────────────────────
set srcs [list $common/bench_loopback.v]
if {$style eq "scalar"} { lappend srcs $common/bench_loopback_scalar.v }
add_files -norecurse -fileset sources_1 $srcs
update_compile_order -fileset sources_1

# ── Parchear el block design ──────────────────────────────────────────────
open_bd_design [get_files $bdname.bd]

if {[llength [get_bd_cells -quiet bench_loopback_0]] > 0} {
    puts "AVISO: el loopback ya estaba insertado; se elimina para rehacerlo"
    delete_bd_objs [get_bd_cells bench_loopback_0]
}

if {$style eq "scalar"} {
    create_bd_cell -type module -reference bench_loopback_scalar bench_loopback_0
    for {set i 0} {$i < 14} {incr i} {
        # 1. Quitar la net que llevaba el pin externo UART_i_RX al transceptor.
        set net [get_bd_nets -quiet UART_${i}_RX_1]
        if {[llength $net] > 0} { delete_bd_objs $net }

        # 2. Alimentar la recepción del transceptor desde el loopback.
        connect_bd_net [get_bd_pins bench_loopback_0/rd${i}] \
                       [get_bd_pins Transceiver_${i}/RD]

        # 3. Llevar la transmisión también al loopback (sigue yendo al pin).
        connect_bd_net [get_bd_pins Transceiver_${i}/TD] \
                       [get_bd_pins bench_loopback_0/td${i}]
    }
} else {
    create_bd_cell -type module -reference bench_loopback bench_loopback_0
    set net [get_bd_nets -quiet RD_1]
    if {[llength $net] > 0} { delete_bd_objs $net }
    connect_bd_net [get_bd_pins bench_loopback_0/rd] \
                   [get_bd_pins BRIDGE_AND_SERIALs_0/RD]
    connect_bd_net [get_bd_pins BRIDGE_AND_SERIALs_0/TD] \
                   [get_bd_pins bench_loopback_0/td]
}

# Un puerto de entrada sin carga es intencionado: no es un error de diseño.
set_msg_config -id {BD 41-759} -new_severity INFO -quiet

validate_bd_design -quiet
save_bd_design
puts "===== block design parcheado y guardado"

generate_target all [get_files $bdname.bd]
export_ip_user_files -of_objects [get_files $bdname.bd] -no_script -sync -force -quiet

# ── Re-implementar desde cero ─────────────────────────────────────────────
puts "\n===== lanzando sintesis e implementacion ($jobs jobs)"
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set st [get_property STATUS [get_runs impl_1]]
set pr [get_property PROGRESS [get_runs impl_1]]
puts "\n===== impl_1: STATUS='$st' PROGRESS=$pr"
if {$pr ne "100%"} {
    puts "ERROR: la implementacion no termino"
    exit 1
}

# ── Informar del timing, que es lo que puede romper el loopback ───────────
open_run impl_1
set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "===== WNS=$wns ns  WHS=$whs ns"
if {$wns < 0 || $whs < 0} {
    puts "AVISO: el diseño NO cierra timing; los resultados no serian fiables"
}

set bit [glob -nocomplain [file dirname $xpr]/*.runs/impl_1/*.bit]
puts "===== bitstream: $bit"
close_project
puts "===== OK"
