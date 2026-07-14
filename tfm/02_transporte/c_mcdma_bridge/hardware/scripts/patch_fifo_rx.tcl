# patch_fifo_rx.tcl — baja el umbral prog_full de la FIFO de recepción y
# re-implementa el diseño MCDMA.
#
# Por qué: el DRAIN (BRIDGE_RX_FIFO_DRAIN) arranca a drenar un canal cuando su
# FIFO llega a prog_full, o cuando el UART señala 8,5 periodos de bit de
# silencio. En una ráfaga continua ese timeout nunca salta, así que el único
# disparador es prog_full. Estaba en 508 sobre una FIFO de 512: el drenado
# empezaba con la FIFO casi llena y, como el DRAIN no emite TLAST hasta vaciar
# el canal, el paquete seguía creciendo con los bytes que entraban mientras
# tanto. El resultado superaba los 512 B del descriptor de recepción del MCDMA
# (DMA_RX_DMA_SIZE) y el canal se quedaba mudo.
#
# Con 256 el drenado arranca a media FIFO: 256 bytes de margen en vez de 4, y el
# paquete cabe holgadamente en el descriptor.
#
# Uso:
#   vivado -mode batch -source patch_fifo_rx.tcl -tclargs <xpr> <bd> <thresh> <jobs>

if {[llength $argv] < 4} {
    puts "ERROR: faltan argumentos: <xpr> <bd> <thresh> <jobs>"
    exit 1
}
set xpr    [lindex $argv 0]
set bdname [lindex $argv 1]
set thresh [lindex $argv 2]
set jobs   [lindex $argv 3]

puts "\n===== abriendo $xpr"
open_project $xpr

set fifo [get_ips -quiet fifo_rx]
if {[llength $fifo] == 0} {
    puts "ERROR: no encuentro el IP fifo_rx"
    exit 1
}

set old [get_property CONFIG.Full_Threshold_Assert_Value $fifo]
set depth [get_property CONFIG.Input_Depth $fifo]
puts "===== fifo_rx: profundidad=$depth  prog_full actual=$old  -> nuevo=$thresh"

if {$thresh >= $depth} {
    puts "ERROR: el umbral ($thresh) debe ser menor que la profundidad ($depth)"
    exit 1
}

# El negate ha de quedar por debajo del assert (histéresis de un byte).
set negate [expr {$thresh - 1}]
set_property -dict [list \
    CONFIG.Full_Threshold_Assert_Value $thresh \
    CONFIG.Full_Threshold_Negate_Value $negate \
] $fifo

puts "===== regenerando el IP"
reset_target all $fifo
generate_target all $fifo
export_ip_user_files -of_objects $fifo -no_script -sync -force -quiet
create_ip_run -quiet $fifo

puts "\n===== lanzando sintesis e implementacion ($jobs jobs)"
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set st [get_property STATUS   [get_runs impl_1]]
set pr [get_property PROGRESS [get_runs impl_1]]
puts "\n===== impl_1: STATUS='$st' PROGRESS=$pr"
if {$pr ne "100%"} {
    puts "ERROR: la implementacion no termino"
    exit 1
}

open_run impl_1
set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "===== WNS=$wns ns  WHS=$whs ns"
if {$wns < 0 || $whs < 0} {
    puts "AVISO: el diseño NO cierra timing; los resultados no serian fiables"
}
close_project
puts "===== OK"
