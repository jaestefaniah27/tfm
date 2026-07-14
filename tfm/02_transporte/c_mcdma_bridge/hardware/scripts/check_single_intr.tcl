create_project -in_memory -part xczu9eg-ffvb1156-2-e
create_bd_design "test"
set mcdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_mcdma axi_mcdma_0]
set_property CONFIG.c_enable_multi_intr {0} $mcdma
puts "--- PINS AFTER SETTING MULTI_INTR=0 ---"
foreach p [get_bd_pins -of_objects $mcdma -filter "NAME =~ *introut*"] {
    puts "PIN: $p"
}
