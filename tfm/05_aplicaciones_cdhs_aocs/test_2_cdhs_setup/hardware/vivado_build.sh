#!/bin/bash
#====================================================================
# Script Bash para recrear proyecto Vivado - test_2_cdhs
# Uso: ./vivado_build.sh [opciones]
#====================================================================

set -e  # Exit on error

# ============= CONFIGURACIÓN =============

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="zynq_transceiver_system"
DEVICE_PART="xczu9eg-ffvb1156-2-e"
VIVADO_VERSION="2025.1"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============= FUNCIONES =============

print_header() {
    echo -e "\n${BLUE}=====================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================================================${NC}\n"
}

print_ok() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ============= VERIFICACIONES =============

check_vivado() {
    print_info "Verificando instalación de Vivado..."
    
    if command -v vivado &> /dev/null; then
        print_ok "Vivado encontrado: $(vivado -version | grep Vivado | cut -d' ' -f2)"
    else
        print_error "Vivado no encontrado en PATH"
        echo -e "${YELLOW}Soluciones:${NC}"
        echo "  1. Instala Vivado $VIVADO_VERSION"
        echo "  2. Añade Vivado al PATH:"
        echo "     export PATH=\$PATH:/path/to/vivado/bin"
        exit 1
    fi
}

check_files() {
    print_info "Verificando archivos necesarios..."
    
    local missing=0
    
    local files=(
        "hardware/src/CONFIGURABLE_SERIAL.vhd"
        "hardware/src/NCO.vhd"
        "hardware/src/RX_CONFIGURABLE_SERIAL.vhd"
        "hardware/src/ShiftRegister.vhd"
        "hardware/src/TX_CONFIGURABLE_SERIAL.vhd"
        "hardware/src/CONFIGURABLE_SERIAL_TOP.vhd"
        "hardware/src/zcu102_constraints.xdc"
        "hardware/recreate_test_vivado.tcl"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            print_ok "Encontrado: $file"
        else
            print_error "Falta: $file"
            ((missing++))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        print_error "$missing archivo(s) faltante(s)"
        exit 1
    fi
}

# ============= BUILD =============

create_project() {
    print_header "Recreando Proyecto Vivado"
    
    cd "$SCRIPT_DIR/hardware"
    
    # Backup si existe
    if [ -d "$PROJECT_NAME" ]; then
        print_warn "Directorio $PROJECT_NAME ya existe"
        read -p "¿Eliminar y recrear? (s/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            rm -rf "$PROJECT_NAME"
            print_info "Directorio eliminado"
        else
            print_warn "Abortado"
            exit 0
        fi
    fi
    
    # Crear proyecto usando TCL
    print_info "Ejecutando script Vivado..."
    
    vivado -mode tcl <<EOF
source recreate_test_vivado.tcl -tclargs --origin_dir ..
puts "\n✅ Script completado"
exit 0
EOF
    
    print_ok "Proyecto recreado"
}

run_synthesis() {
    print_header "Ejecutando Synthesis"
    
    cd "$SCRIPT_DIR/hardware"
    
    vivado -mode tcl <<EOF
open_project $PROJECT_NAME/$PROJECT_NAME.xpr

puts "Iniciando synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

puts "\n✅ Synthesis completada"
exit 0
EOF
    
    print_ok "Synthesis completada"
}

run_implementation() {
    print_header "Ejecutando Implementation"
    
    cd "$SCRIPT_DIR/hardware"
    
    vivado -mode tcl <<EOF
open_project $PROJECT_NAME/$PROJECT_NAME.xpr

puts "Iniciando implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1

puts "\n✅ Implementation completada"
exit 0
EOF
    
    print_ok "Implementation completada"
}

generate_bitstream() {
    print_header "Generando Bitstream"
    
    cd "$SCRIPT_DIR/hardware"
    
    vivado -mode tcl <<EOF
open_project $PROJECT_NAME/$PROJECT_NAME.xpr

puts "Generando bitstream..."
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

puts "\n✅ Bitstream generado"
exit 0
EOF
    
    print_ok "Bitstream generado"
}

export_hardware() {
    print_header "Exportando Hardware para Vitis"
    
    cd "$SCRIPT_DIR/hardware"
    
    vivado -mode tcl <<EOF
open_project $PROJECT_NAME/$PROJECT_NAME.xpr

puts "Exportando hardware..."
write_hw_platform -fixed -include_bit -force ./$PROJECT_NAME.xsa

puts "\n✅ Hardware exportado"
exit 0
EOF
    
    print_ok "Hardware exportado: $PROJECT_NAME.xsa"
}

# ============= MAIN =============

main() {
    print_header "RECREACIÓN DE PROYECTO VIVADO - TEST_2_CDHS"
    
    echo "Directorio: $SCRIPT_DIR"
    echo "Proyecto: $PROJECT_NAME"
    echo "FPGA: $DEVICE_PART"
    echo ""
    
    # Verificaciones
    check_vivado
    check_files
    
    # Menu de opciones
    echo -e "\n${YELLOW}Selecciona opción:${NC}"
    echo "  1) Recrear proyecto (solo TCL)"
    echo "  2) Synthesis"
    echo "  3) Implementation"
    echo "  4) Generar Bitstream"
    echo "  5) Exportar Hardware"
    echo "  6) TODO (crear + synth + impl + bit + export)"
    echo "  0) Salir"
    echo ""
    read -p "Opción (0-6): " option
    
    case $option in
        1)
            create_project
            ;;
        2)
            run_synthesis
            ;;
        3)
            run_implementation
            ;;
        4)
            generate_bitstream
            ;;
        5)
            export_hardware
            ;;
        6)
            create_project &&\
            run_synthesis &&\
            run_implementation &&\
            generate_bitstream &&\
            export_hardware
            
            print_header "🎉 ¡PROCESO COMPLETADO EXITOSAMENTE!"
            echo "Archivos generados:"
            echo "  • Proyecto: $SCRIPT_DIR/$PROJECT_NAME/$PROJECT_NAME.xpr"
            echo "  • Bitstream: $SCRIPT_DIR/$PROJECT_NAME.bit"
            echo "  • XSA: $SCRIPT_DIR/$PROJECT_NAME.xsa"
            ;;
        0)
            print_info "Saliendo..."
            exit 0
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
    
    print_ok "¡Completado!"
}

# Ejecutar main
main
