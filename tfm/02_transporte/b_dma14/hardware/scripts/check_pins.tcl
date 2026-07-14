create_project -in_memory -part xczu9eg-ffvb1156-2-e
create_bd_design "test"
set mcdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_mcdma axi_mcdma_0]
puts "--- MCDMA PINS ---"
foreach p [get_bd_pins -of_objects $mcdma] {
    puts "PIN: $p"
}
puts "------------------"
