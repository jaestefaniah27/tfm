# =========================================================================
# package_multi_serial_ip.tcl
# Empaqueta MULTI_SERIAL_CORE como IP del catálogo de Vivado, incluyendo el
# sub-IP fifo_generator_0 que usa el core. Tras ejecutarlo, añade el repo
# ./ip_repo a tu proyecto y arrastra "Multi Serial Core" al block design.
#
# Uso (desde la carpeta hardware/):
#   vivado -mode batch -source scripts/package_multi_serial_ip.tcl
# =========================================================================

set origin_dir [pwd]
set src_dir    "$origin_dir/src"
set ip_repo    "$origin_dir/ip_repo"
set tmp_proj   "$origin_dir/.ip_pkg_proj"
set part       "xczu9eg-ffvb1156-2-e"

file mkdir $ip_repo

# Proyecto temporal de empaquetado
create_project -force pkg_multi_serial $tmp_proj -part $part

# -------------------------------------------------------------------------
# 1) Sub-IP: fifo_generator_0 (9-bit, depth 512, First-Word-Fall-Through)
#    Mismo config que usa CONFIGURABLE_SERIAL. Se incluirá DENTRO del IP.
# -------------------------------------------------------------------------
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name fifo_generator_0
set_property -dict [list \
    CONFIG.Interface_Type        {Native} \
    CONFIG.Performance_Options   {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width      {9} \
    CONFIG.Input_Depth           {512} \
    CONFIG.Output_Data_Width     {9} \
    CONFIG.Reset_Type            {Synchronous_Reset} \
    CONFIG.Full_Flags_Reset_Value {0} \
    CONFIG.Use_Dout_Reset        {true} \
] [get_ips fifo_generator_0]
generate_target all [get_ips fifo_generator_0]

# -------------------------------------------------------------------------
# 2) Fuentes RTL: transceptor + wrapper multi-canal
# -------------------------------------------------------------------------
add_files -norecurse [list \
    $src_dir/NCO.vhd \
    $src_dir/ShiftRegister.vhd \
    $src_dir/RX_CONFIGURABLE_SERIAL.vhd \
    $src_dir/TX_CONFIGURABLE_SERIAL.vhd \
    $src_dir/CONFIGURABLE_SERIAL.vhd \
    $src_dir/CONFIGURABLE_SERIAL_TOP.vhd \
    $src_dir/MULTI_SERIAL_CORE.vhd ]

set_property top MULTI_SERIAL_CORE [current_fileset]
update_compile_order -fileset sources_1

# -------------------------------------------------------------------------
# 3) Empaquetar el proyecto como IP (incluye el fifo como subcore y deduce
#    los anchos de bus dependientes de N a partir del RTL).
# -------------------------------------------------------------------------
ipx::package_project -root_dir $ip_repo/multi_serial_core \
    -vendor lince.com -library user -taxonomy /UserIP \
    -import_files -set_current true -force

set core [ipx::current_core]
set_property name         multi_serial_core $core
set_property version      1.0               $core
set_property display_name {Multi Serial Core (N transceptores)} $core
set_property description   {N x CONFIGURABLE_SERIAL_TOP. Interfaz paralela aplanada por canal, sin AXI. DE/SLO con habilitacion global y mascara por canal.} $core
set_property vendor_display_name {Lince} $core
set_property company_url {http://lince.com} $core

# -------------------------------------------------------------------------
# 4) Parámetros visibles en la GUI del IP
# -------------------------------------------------------------------------
foreach p {N USE_DE USE_SLO DE_MASK SLO_MASK} {
    if { [llength [ipx::get_user_parameters $p -of_objects $core]] } {
        ipgui::add_param -name $p -component $core
    }
}

# Rango sugerido para N (las máscaras son de 32 bits)
set par_N [ipx::get_user_parameters N -of_objects $core]
if { [llength $par_N] } {
    set_property value_validation_type     range_long $par_N
    set_property value_validation_range_minimum 1  $par_N
    set_property value_validation_range_maximum 32 $par_N
}

# -------------------------------------------------------------------------
# 5) Ocultar el vector DE / SLO completo según USE_DE / USE_SLO
# -------------------------------------------------------------------------
set p_de [ipx::get_ports DE -of_objects $core]
if { [llength $p_de] } { set_property enablement_dependency {$USE_DE = true} $p_de }
set p_slo [ipx::get_ports SLO -of_objects $core]
if { [llength $p_slo] } { set_property enablement_dependency {$USE_SLO = true} $p_slo }

# -------------------------------------------------------------------------
# 6) Guardar el IP y refrescar el catálogo
# -------------------------------------------------------------------------
ipx::create_xgui_files $core
ipx::update_checksums  $core
ipx::check_integrity   $core
ipx::save_core         $core

set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog -rebuild

puts ""
puts "================================================================"
puts " IP empaquetada en: $ip_repo/multi_serial_core"
puts " Anade ese repo a tu proyecto (ip_repo_paths) y arrastra"
puts " 'Multi Serial Core' al block design."
puts "================================================================"

close_project
