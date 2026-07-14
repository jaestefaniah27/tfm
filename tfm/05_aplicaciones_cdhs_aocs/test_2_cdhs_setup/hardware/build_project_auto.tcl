#!/usr/bin/tclsh
#====================================================================
# Script de Recreación Automática de Proyecto Vivado - test_2_cdhs
# Vivado 2025.1
#====================================================================

# ============= CONFIGURACIÓN =============

set PROJECT_NAME "zynq_transceiver_system"
set DEVICE_PART "xczu9eg-ffvb1156-2-e"

# Detectar directorio origen
if { [info exists ::env(VIVADO_SCRIPT_DIR)] } {
    set origin_dir $::env(VIVADO_SCRIPT_DIR)
} else {
    set origin_dir [file dirname [info script]]
    set origin_dir [string map [list "hardware" ""] $origin_dir]
}

puts "======================================================================"
puts "🔄 RECREANDO PROYECTO VIVADO: $PROJECT_NAME"
puts "======================================================================"
puts "Origen: $origin_dir"
puts "Timestamp: [clock format [clock seconds]]"
puts "======================================================================"

# ============= CREAR PROYECTO =============

puts "\n📁 Creando proyecto..."
cd $origin_dir
create_project $PROJECT_NAME ./$PROJECT_NAME -part $DEVICE_PART -force

set proj_dir [get_property directory [current_project]]
puts "✅ Proyecto creado en: $proj_dir"

# ============= CONFIGURAR PROPIEDADES =============

puts "\n⚙️  Configurando propiedades del proyecto..."
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/$PROJECT_NAME.cache/ip" -objects $obj
set_property -name "part" -value $DEVICE_PART -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO XPM_MEMORY" -objects $obj
puts "✅ Propiedades configuradas"

# ============= AÑADIR FUENTES =============

puts "\n📄 Añadiendo archivos fuente VHDL..."
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}

set obj [get_filesets sources_1]
set files [list \
    "$origin_dir/hardware/src/CONFIGURABLE_SERIAL.vhd" \
    "$origin_dir/hardware/src/NCO.vhd" \
    "$origin_dir/hardware/src/RX_CONFIGURABLE_SERIAL.vhd" \
    "$origin_dir/hardware/src/ShiftRegister.vhd" \
    "$origin_dir/hardware/src/TX_CONFIGURABLE_SERIAL.vhd" \
    "$origin_dir/hardware/src/CONFIGURABLE_SERIAL_TOP.vhd" \
]

foreach file $files {
    if {[file exists $file]} {
        add_files -norecurse -fileset $obj $file
        puts "  ✓ Añadido: [file tail $file]"
    } else {
        puts "  ✗ ADVERTENCIA: No encontrado $file"
    }
}

# Establecer propiedades de archivos
foreach file $files {
    set file_obj [get_files -of_objects [get_filesets sources_1] [list "*[file tail $file]"]]
    if {$file_obj != ""} {
        set_property -name "file_type" -value "VHDL" -objects $file_obj
    }
}

set_property -name "top" -value "system_wrapper" -objects $obj
set_property -name "top_auto_set" -value "0" -objects $obj
puts "✅ Archivos VHDL añadidos"

# ============= AÑADIR CONSTRAINTS =============

puts "\n📌 Añadiendo constraints XDC..."
if {[string equal [get_filesets -quiet constrs_1] ""]} {
    create_fileset -constrset constrs_1
}

set obj [get_filesets constrs_1]
set xdc_file "$origin_dir/hardware/src/zcu102_constraints.xdc"

if {[file exists $xdc_file]} {
    add_files -norecurse -fileset $obj $xdc_file
    puts "✅ Constraints añadidos: [file tail $xdc_file]"
} else {
    puts "⚠️  ADVERTENCIA: No encontrado $xdc_file"
}

set obj [get_filesets constrs_1]
set_property -name "target_part" -value $DEVICE_PART -objects $obj

# ============= CREAR BLOCK DESIGN =============

puts "\n🎨 Creando Block Design..."
set design_name "system"

# Import de fuentes TCL del script original
source "[file dirname [info script]]/recreate_test_vivado.tcl" -tclargs --origin_dir $origin_dir

# Llamar a la función de creación del BD (del script original)
if {[catch {
    cr_bd_system ""
} err]} {
    puts "⚠️  NOTA: Block Design podría no haberse creado correctamente"
    puts "   Detalle: $err"
    puts "   Continuando con el flujo..."
}

puts "✅ Block Design procesado"

# ============= GENERAR WRAPPER =============

puts "\n🔨 Generando HDL Wrapper..."
if {[catch {
    set wrapper [make_wrapper -files [get_files *.bd] -top -force]
    puts "✅ Wrapper generado: $wrapper"
} err]} {
    puts "⚠️  Wrapper: $err"
}

# ============= LISTAR ARCHIVOS =============

puts "\n📊 Resumen de archivos del proyecto:"
puts "  VHDL files: [llength [get_files -filter {FILE_TYPE == VHDL}]]"
puts "  XDC files:  [llength [get_files -filter {FILE_TYPE == XDC}]]"
puts "  BD files:   [llength [get_files -filter {FILE_TYPE == Block_Designs}]]"
puts "  IP cores:   [llength [get_ips]]"

# ============= MENSAJES FINALES =============

puts "\n======================================================================"
puts "✅ RECREACIÓN COMPLETADA"
puts "======================================================================"
puts "Proyecto: $PROJECT_NAME"
puts "Ubicación: $proj_dir"
puts ""
puts "📋 PRÓXIMOS PASOS:"
puts "  1. Abre el proyecto en Vivado:"
puts "     open_project $proj_dir/$PROJECT_NAME.xpr"
puts ""
puts "  2. Genera synthesis:"
puts "     launch_runs synth_1 -jobs 4"
puts "     wait_on_run synth_1"
puts ""
puts "  3. Genera implementation:"
puts "     launch_runs impl_1 -jobs 4"
puts "     wait_on_run impl_1"
puts ""
puts "  4. Genera bitstream:"
puts "     launch_runs impl_1 -to_step write_bitstream"
puts "     wait_on_run impl_1"
puts ""
puts "  5. Exporta hardware para Vitis:"
puts "     write_hw_platform -fixed -include_bit -force $proj_dir/$PROJECT_NAME.xsa"
puts ""
puts "======================================================================"
puts "Timestamp final: [clock format [clock seconds]]"
puts "======================================================================"
