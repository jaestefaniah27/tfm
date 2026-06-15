# add_2_transceivers.tcl
# -----------------------------------------------------------------------------------------
# Script de un solo uso: Añade Transceiver_3 y Transceiver_4 al block design existente
# que ya tiene Transceiver_0..2 con la infraestructura generada por new_generate_transceivers.tcl
#
# Estrategia: Los IPs bloqueados (irq_concat, const_sys_meta) no se pueden modificar,
# así que se BORRAN y se RECREAN con la configuración correcta para 5 canales.
#
# Uso en la consola Tcl de Vivado (con el proyecto ya abierto):
#   source /home/mpsocv2/vivado_aocs/scripts/add_2_transceivers.tcl
# -----------------------------------------------------------------------------------------

puts "================================================================"
puts " AÑADIENDO 2 TRANSCEPTORES (indices 3 y 4) AL DISEÑO EXISTENTE"
puts "================================================================"

# --- Abrir el block design si no está abierto ---
open_bd_design [get_files design_1.bd]

# === PARÁMETROS ===
set ps_name       "zynq_ultra_ps_e_0"
set xbar_name     "axi_smc"
set old_count     3
set new_count     5
set uart_base     0xA0000000
set uart_stride   0x1000
set sys_info_addr 0xA0020000

set sys_clk            [get_bd_pins $ps_name/pl_clk0]
set rst_cell           [get_bd_cells rst_gen]
set peripheral_aresetn [get_bd_pins $rst_cell/peripheral_aresetn]

# =====================================================================
# 1. AMPLIAR SmartConnect: 5 → 7 puertos master
#    Antes: M00..M02 = Transceptores, M03 = intc, M04 = sys_info
#    Ahora: M00..M04 = Transceptores, M05 = intc, M06 = sys_info
# =====================================================================
puts "  -> Ampliando SmartConnect a [expr {$new_count + 2}] puertos master..."
set needed_ports [expr {$new_count + 2}]
set_property CONFIG.NUM_MI $needed_ports [get_bd_cells $xbar_name]

# =====================================================================
# 2. REUBICAR axi_intc_global: M03 → M05
# =====================================================================
puts "  -> Reubicando axi_intc_global de M03 a M05..."
set old_intc_net [get_bd_intf_nets -of_objects [get_bd_intf_pins ${xbar_name}/M03_AXI]]
if { $old_intc_net ne "" } {
    delete_bd_objs $old_intc_net
}
connect_bd_intf_net [get_bd_intf_pins ${xbar_name}/M05_AXI] [get_bd_intf_pins axi_intc_global/s_axi]

# =====================================================================
# 3. REUBICAR axi_sys_info: M04 → M06
# =====================================================================
puts "  -> Reubicando axi_sys_info de M04 a M06..."
set old_sys_net [get_bd_intf_nets -of_objects [get_bd_intf_pins ${xbar_name}/M04_AXI]]
if { $old_sys_net ne "" } {
    delete_bd_objs $old_sys_net
}
connect_bd_intf_net [get_bd_intf_pins ${xbar_name}/M06_AXI] [get_bd_intf_pins axi_sys_info/S_AXI]

# =====================================================================
# 4. BORRAR Y RECREAR irq_concat (bloqueado, no se puede modificar)
#    Antes: 3 puertos. Ahora: 5 puertos.
# =====================================================================
puts "  -> Recreando irq_concat con $new_count puertos..."

# 4a. Desconectar las señales del viejo irq_concat
#     - In0..In2 vienen de Transceiver_0..2/irq_raw
#     - dout va a axi_intc_global/intr
foreach net_obj [get_bd_nets -quiet -of_objects [get_bd_cells irq_concat]] {
    delete_bd_objs $net_obj
}

# 4b. Borrar el irq_concat viejo
delete_bd_objs [get_bd_cells irq_concat]

# 4c. Crear uno nuevo con 5 puertos
set concat [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irq_concat]
set_property CONFIG.NUM_PORTS $new_count $concat

# 4d. Reconectar In0..In2 a los transceptores existentes
for {set i 0} {$i < $old_count} {incr i} {
    connect_bd_net [get_bd_pins Transceiver_${i}/irq_raw] [get_bd_pins irq_concat/In${i}]
}
# In3 e In4 se conectarán al crear los nuevos transceptores (paso 7)

# 4e. Reconectar dout -> intc (se hace al final, después de actualizar intc)

# =====================================================================
# 5. ACTUALIZAR axi_intc_global para 5 canales (10 interrupciones)
#    Si está bloqueado, se borra y recrea también.
# =====================================================================
puts "  -> Actualizando axi_intc_global para $new_count canales..."

# Calcular nueva máscara de edge
set edge_val 0
for {set k 0} {$k < $new_count} {incr k} {
    set shift [expr {$k * 2}]
    set pattern [expr {2 << $shift}]
    set edge_val [expr {$edge_val | $pattern}]
}
set edge_hex [format "0x%X" $edge_val]
puts "     Edge mask: $edge_hex"

# Intentar modificar; si falla por bloqueo, borrar y recrear
set intc_locked 0
set intc_ip [get_ips -quiet -of_objects [get_bd_cells axi_intc_global]]
if { $intc_ip ne "" } {
    set intc_locked [get_property IS_LOCKED $intc_ip]
}

if { $intc_locked } {
    puts "     axi_intc_global está bloqueado -> borrando y recreando..."
    # Desconectar todo del intc
    set intc_intf_net [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins axi_intc_global/s_axi]]
    if { $intc_intf_net ne "" } { delete_bd_objs $intc_intf_net }
    foreach net_obj [get_bd_nets -quiet -of_objects [get_bd_cells axi_intc_global]] {
        delete_bd_objs $net_obj
    }
    delete_bd_objs [get_bd_cells axi_intc_global]

    # Recrear
    set intc_global [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_global]
    set_property -dict [list CONFIG.C_IRQ_CONNECTION {1} CONFIG.C_NUM_INTR_INPUTS [expr {$new_count * 2}] \
                             CONFIG.C_KIND_OF_INTR {0xFFFFFFFF} CONFIG.C_KIND_OF_EDGE $edge_hex] $intc_global
    connect_bd_net $sys_clk [get_bd_pins axi_intc_global/s_axi_aclk]
    connect_bd_net $peripheral_aresetn [get_bd_pins axi_intc_global/s_axi_aresetn]
    connect_bd_intf_net [get_bd_intf_pins ${xbar_name}/M05_AXI] [get_bd_intf_pins axi_intc_global/s_axi]
    connect_bd_net [get_bd_pins axi_intc_global/irq] [get_bd_pins ${ps_name}/pl_ps_irq0]
} else {
    puts "     axi_intc_global NO está bloqueado -> modificando in-place..."
    set_property -dict [list \
        CONFIG.C_NUM_INTR_INPUTS [expr {$new_count * 2}] \
        CONFIG.C_KIND_OF_EDGE $edge_hex \
    ] [get_bd_cells axi_intc_global]
}

# Conectar dout del concat al intc
connect_bd_net [get_bd_pins irq_concat/dout] [get_bd_pins axi_intc_global/intr]

# =====================================================================
# 6. BORRAR Y RECREAR const_sys_meta (bloqueado)
# =====================================================================
puts "  -> Recreando const_sys_meta (count=$new_count)..."
set meta_val [expr {($uart_stride << 16) | $new_count}]

# Desconectar y borrar
foreach net_obj [get_bd_nets -quiet -of_objects [get_bd_cells const_sys_meta]] {
    delete_bd_objs $net_obj
}
delete_bd_objs [get_bd_cells const_sys_meta]

# Recrear con el nuevo valor
set const_meta [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_sys_meta]
set_property -dict [list CONFIG.CONST_VAL $meta_val CONFIG.CONST_WIDTH {32}] $const_meta
connect_bd_net [get_bd_pins const_sys_meta/dout] [get_bd_pins axi_sys_info/gpio_io_i]

# =====================================================================
# 7. CREAR LOS 2 NUEVOS TRANSCEPTORES (índices 3 y 4)
# =====================================================================

proc create_transceiver_hier_inline { index } {
    puts "  -> Generando jerarquía: Transceiver_${index}..."

    set hier_name "Transceiver_${index}"
    set current_bd_instance [current_bd_instance .]
    set hier_obj [create_bd_cell -type hier $hier_name]
    current_bd_instance $hier_obj

    set s "_${index}"

    # RTL Core
    set rtl [create_bd_cell -type module -reference CONFIGURABLE_SERIAL_TOP "rtl_core${s}"]

    # AXI GPIO Unificado (Dual Channel)
    set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 "axi_gpio${s}"]
    set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_GPIO_WIDTH {28} \
                             CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {14}] $gpio

    # Conexiones Internas
    connect_bd_net [get_bd_pins ${gpio}/gpio_io_o] [get_bd_pins ${rtl}/PS_SERIAL_CONFIG]
    connect_bd_net [get_bd_pins ${rtl}/PS_out]     [get_bd_pins ${gpio}/gpio2_io_i]

    # Interfaz AXI
    create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI
    connect_bd_intf_net [get_bd_intf_pins S_AXI] [get_bd_intf_pins ${gpio}/S_AXI]

    # Pines de Sistema
    create_bd_pin -dir I -type clk aclk
    create_bd_pin -dir I -type rst aresetn
    connect_bd_net [get_bd_pins aclk]    [get_bd_pins ${gpio}/s_axi_aclk] [get_bd_pins ${rtl}/Clk]
    connect_bd_net [get_bd_pins aresetn] [get_bd_pins ${gpio}/s_axi_aresetn] [get_bd_pins ${rtl}/Reset]

    # Pines UART
    create_bd_pin -dir I RD
    create_bd_pin -dir O TD
    create_bd_pin -dir O DE
    create_bd_pin -dir O SLO
    connect_bd_net [get_bd_pins RD] [get_bd_pins ${rtl}/RD]
    connect_bd_net [get_bd_pins TD] [get_bd_pins ${rtl}/TD]
    connect_bd_net [get_bd_pins DE] [get_bd_pins ${rtl}/DE]
    connect_bd_net [get_bd_pins SLO] [get_bd_pins ${rtl}/SLO]

    # Interrupción
    create_bd_pin -dir O -from 1 -to 0 irq_raw
    connect_bd_net [get_bd_pins ${rtl}/TX_RDY_EMPTY] [get_bd_pins irq_raw]

    current_bd_instance $current_bd_instance
}

# Instanciar Transceiver_3 y Transceiver_4
foreach i {3 4} {
    create_transceiver_hier_inline $i
    set cell "Transceiver_$i"

    # Clk y Reset
    connect_bd_net $sys_clk [get_bd_pins ${cell}/aclk]
    connect_bd_net $peripheral_aresetn [get_bd_pins ${cell}/aresetn]

    # AXI: M03 para Transceiver_3, M04 para Transceiver_4
    set mi_idx [format "%02d" $i]
    connect_bd_intf_net [get_bd_intf_pins ${xbar_name}/M${mi_idx}_AXI] [get_bd_intf_pins ${cell}/S_AXI]

    # IRQ
    connect_bd_net [get_bd_pins ${cell}/irq_raw] [get_bd_pins irq_concat/In${i}]

    # Puertos Físicos (ambos son < 13, así que tienen pines reales)
    create_bd_port -dir I "UART_${i}_RX"
    create_bd_port -dir O "UART_${i}_TX"
    create_bd_port -dir O "UART_${i}_DE"
    create_bd_port -dir O "UART_${i}_SLO"

    connect_bd_net [get_bd_ports "UART_${i}_RX"] [get_bd_pins ${cell}/RD]
    connect_bd_net [get_bd_pins ${cell}/TD]      [get_bd_ports "UART_${i}_TX"]
    connect_bd_net [get_bd_pins ${cell}/DE]      [get_bd_ports "UART_${i}_DE"]
    connect_bd_net [get_bd_pins ${cell}/SLO]     [get_bd_ports "UART_${i}_SLO"]

    puts "     Transceiver_${i} creado y conectado."
}

# =====================================================================
# 8. ASIGNAR DIRECCIONES A LOS NUEVOS TRANSCEPTORES
# =====================================================================
puts "  -> Asignando direcciones de memoria..."
set seg "${ps_name}/Data"

foreach i {3 4} {
    set addr [expr {$uart_base + ($i * $uart_stride)}]
    assign_bd_address -target_address_space $seg \
        [get_bd_addr_segs Transceiver_${i}/*/S_AXI/Reg] \
        -force -offset [format "0x%08X" $addr] -range 4K
    puts "     Transceiver_${i} @ [format "0x%08X" $addr]"
}

# Reasignar intc (ahora en la nueva posición)
set intc_addr [expr {$uart_base + ($new_count * $uart_stride)}]
assign_bd_address -target_address_space $seg \
    [get_bd_addr_segs axi_intc_global/S_AXI/Reg] \
    -force -offset [format "0x%08X" $intc_addr] -range 4K
puts "     axi_intc_global @ [format "0x%08X" $intc_addr]"

# sys_info se queda en 0xA0020000 (reasignar por seguridad)
assign_bd_address -target_address_space $seg \
    [get_bd_addr_segs axi_sys_info/S_AXI/Reg] \
    -force -offset [format "0x%08X" $sys_info_addr] -range 4K
puts "     axi_sys_info @ [format "0x%08X" $sys_info_addr]"

# =====================================================================
# 9. VALIDAR Y GUARDAR
# =====================================================================
puts "  -> Validando diseño..."
validate_bd_design
save_bd_design

puts "================================================================"
puts " COMPLETADO: 2 transceptores añadidos correctamente."
puts ""
puts " Mapa de memoria final:"
puts "   Transceiver_0  @ 0xA0000000"
puts "   Transceiver_1  @ 0xA0001000"
puts "   Transceiver_2  @ 0xA0002000"
puts "   Transceiver_3  @ 0xA0003000"
puts "   Transceiver_4  @ 0xA0004000"
puts "   axi_intc_global @ 0xA0005000"
puts "   axi_sys_info   @ 0xA0020000"
puts ""
puts " NOTA: Añade los pines en el .xdc para UART_3 y UART_4"
puts "================================================================"
