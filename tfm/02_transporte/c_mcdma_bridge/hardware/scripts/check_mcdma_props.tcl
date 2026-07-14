create_project -in_memory -part xczu9eg-ffvb1156-2-e
create_bd_design "test"
set mcdma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_mcdma axi_mcdma_0]
puts "--- PROPERTIES ---"
report_property $mcdma
puts "------------------"
