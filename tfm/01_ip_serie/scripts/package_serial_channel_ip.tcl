# =========================================================================
# package_serial_channel_ip.tcl
#
# Empaqueta SERIAL_CHANNEL_IP como IP del catálogo de Vivado.
# Es un IP de UN SOLO canal. Arrastra N instancias al block design,
# una por canal. Cada instancia configura sus propios USE_DE y USE_SLO
# mediante checkboxes en el diálogo del IP.
#
# Uso (desde la carpeta hardware/):
#   vivado -mode batch -source scripts/package_serial_channel_ip.tcl
#
# El IP resultante se guarda en:
#   hardware/ip_repo/serial_channel_ip/
# Añade ese repo a tu proyecto en Settings → IP → Repository.
# =========================================================================

set origin_dir [pwd]
set src_dir    "$origin_dir/src"
set ip_repo    "$origin_dir/ip_repo"
set tmp_proj   "$origin_dir/.ip_pkg_proj_ch"
set part       "xczu9eg-ffvb1156-2-e"

file mkdir $ip_repo

# -------------------------------------------------------------------------
# 1) Proyecto temporal de empaquetado
# -------------------------------------------------------------------------
create_project -force pkg_serial_ch $tmp_proj -part $part
set_property target_language VHDL [current_project]

# -------------------------------------------------------------------------
# 2) Sub-IP: fifo_generator_0 (9-bit, depth 512, First-Word-Fall-Through)
#    Mismo config que usa internamente CONFIGURABLE_SERIAL.
# -------------------------------------------------------------------------
create_ip -name fifo_generator -vendor xilinx.com -library ip \
          -module_name fifo_generator_0
set_property -dict [list \
    CONFIG.Interface_Type         {Native}                  \
    CONFIG.Performance_Options    {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width       {9}                       \
    CONFIG.Input_Depth            {512}                     \
    CONFIG.Output_Data_Width      {9}                       \
    CONFIG.Reset_Type             {Synchronous_Reset}       \
    CONFIG.Full_Flags_Reset_Value {0}                       \
    CONFIG.Use_Dout_Reset         {true}                    \
] [get_ips fifo_generator_0]
generate_target all [get_ips fifo_generator_0]

# -------------------------------------------------------------------------
# 3) Fuentes RTL (de abajo hacia arriba: primitivas → top)
# -------------------------------------------------------------------------
add_files -norecurse [list \
    $src_dir/NCO.vhd                     \
    $src_dir/ShiftRegister.vhd           \
    $src_dir/RX_CONFIGURABLE_SERIAL.vhd  \
    $src_dir/TX_CONFIGURABLE_SERIAL.vhd  \
    $src_dir/CONFIGURABLE_SERIAL.vhd     \
    $src_dir/CONFIGURABLE_SERIAL_TOP.vhd \
    $src_dir/SERIAL_CHANNEL_IP.vhd       ]

set_property top SERIAL_CHANNEL_IP [current_fileset]
update_compile_order -fileset sources_1

# -------------------------------------------------------------------------
# 4) Empaquetar el proyecto como IP
# -------------------------------------------------------------------------
ipx::package_project -root_dir $ip_repo/serial_channel_ip \
    -vendor lince.com -library user -taxonomy /UserIP \
    -import_files -set_current true -force

set core [ipx::current_core]
set_property name             serial_channel_ip                  $core
set_property version          1.0                                $core
set_property display_name     {Serial Channel (1 transceptor)}   $core
set_property description      {Un canal serie configurable. Instanciar N veces en el BD. USE_DE y USE_SLO controlan si los pines DE/SLO se exponen.} $core
set_property vendor_display_name {Lince}                         $core
set_property company_url      {http://lince.com}                 $core

# -------------------------------------------------------------------------
# 5) Parámetros visibles en la GUI del IP
#    USE_DE  → checkbox "Habilitar pin DE (Driver Enable)"
#    USE_SLO → checkbox "Habilitar pin SLO (Slow Rate)"
# -------------------------------------------------------------------------
foreach p {USE_DE USE_SLO} {
    set par [ipx::get_user_parameters $p -of_objects $core]
    if { [llength $par] == 0 } {
        ipx::add_user_parameter $p $core
        set par [ipx::get_user_parameters $p -of_objects $core]
    }
    set_property value_resolve_type  user    $par
    set_property value               true    $par
    set_property value_format        bool    $par
    ipgui::add_param -name $p -component $core
}

# Etiquetas descriptivas en la GUI
set_property display_name {Habilitar pin DE (Driver Enable)}  \
    [ipgui::get_guiparamspec -name USE_DE  -component $core]
set_property display_name {Habilitar pin SLO (Slow Rate)}     \
    [ipgui::get_guiparamspec -name USE_SLO -component $core]

set_property tooltip {Si se desmarca, el pin DE se fuerza a 0 y no aparece en el BD. Usar cuando el Driver Enable está hardcodeado en hardware.} \
    [ipgui::get_guiparamspec -name USE_DE  -component $core]
set_property tooltip {Si se desmarca, el pin SLO se fuerza a 0 y no aparece en el BD.} \
    [ipgui::get_guiparamspec -name USE_SLO -component $core]

# -------------------------------------------------------------------------
# 6) Ocultar los puertos DE / SLO en el BD según USE_DE / USE_SLO.
#    Cuando el parámetro es false, Vivado no requiere conexión del puerto.
# -------------------------------------------------------------------------
set p_de  [ipx::get_ports DE  -of_objects $core]
set p_slo [ipx::get_ports SLO -of_objects $core]
if { [llength $p_de]  } { set_property enablement_dependency {$USE_DE  = true} $p_de  }
if { [llength $p_slo] } { set_property enablement_dependency {$USE_SLO = true} $p_slo }

# Marcar clk como puerto de reloj (Vivado lo reconoce para timing)
set clk_port [ipx::get_ports clk -of_objects $core]
if { [llength $clk_port] } {
    ipx::add_bus_interface clk $core
    set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 \
        [ipx::get_bus_interfaces clk -of_objects $core]
    set_property bus_type_vlnv xilinx.com:signal:clock:1.0 \
        [ipx::get_bus_interfaces clk -of_objects $core]
    set_property interface_mode master \
        [ipx::get_bus_interfaces clk -of_objects $core]
    ipx::add_port_map CLK [ipx::get_bus_interfaces clk -of_objects $core]
    set_property physical_name clk \
        [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces clk -of_objects $core]]
}

# Marcar aresetn como reset activo-bajo
set rst_port [ipx::get_ports aresetn -of_objects $core]
if { [llength $rst_port] } {
    ipx::add_bus_interface aresetn $core
    set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 \
        [ipx::get_bus_interfaces aresetn -of_objects $core]
    set_property bus_type_vlnv xilinx.com:signal:reset:1.0 \
        [ipx::get_bus_interfaces aresetn -of_objects $core]
    set_property interface_mode slave \
        [ipx::get_bus_interfaces aresetn -of_objects $core]
    ipx::add_port_map RST [ipx::get_bus_interfaces aresetn -of_objects $core]
    set_property physical_name aresetn \
        [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces aresetn -of_objects $core]]
    # Polarity: active-low
    ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces aresetn -of_objects $core]
    set_property value ACTIVE_LOW \
        [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces aresetn -of_objects $core]]
}

# -------------------------------------------------------------------------
# 7) Guardar, verificar y refrescar catálogo
# -------------------------------------------------------------------------
ipx::create_xgui_files $core
ipx::update_checksums  $core
ipx::check_integrity   $core
ipx::save_core         $core

set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog -rebuild

puts ""
puts "================================================================"
puts " IP empaquetada en: $ip_repo/serial_channel_ip"
puts ""
puts " USO:"
puts "   1. Settings → IP → Repository → añade hardware/ip_repo"
puts "   2. IP Catalog → busca 'Serial Channel'"
puts "   3. Arrastra al BD tantas veces como canales necesites"
puts "   4. En el diálogo de cada instancia: desmarca USE_DE o USE_SLO"
puts "      si ese canal no necesita el pin (ej. ch7 y ch11 sin DE)"
puts "================================================================"

close_project
