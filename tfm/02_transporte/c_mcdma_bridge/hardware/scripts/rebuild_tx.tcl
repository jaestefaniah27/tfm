# Re-sintetiza el MCDMA tras un cambio de fuentes VHDL (sin tocar ningún IP).
# uso: vivado -mode batch -source rebuild_tx.tcl -tclargs <xpr> <jobs>

set xpr  [lindex $argv 0]
set jobs [expr {[llength $argv] > 1 ? [lindex $argv 1] : 8}]

open_project $xpr

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set st [get_property STATUS   [get_runs impl_1]]
set pr [get_property PROGRESS [get_runs impl_1]]
puts "===== impl_1: STATUS='$st' PROGRESS=$pr"
if {$pr ne "100%"} { puts "ERROR: implementacion incompleta"; exit 1 }

open_run impl_1
set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "===== WNS=$wns ns  WHS=$whs ns"
if {$wns < 0 || $whs < 0} { puts "ERROR: timing no cierra"; exit 1 }

puts "===== OK"
exit 0
