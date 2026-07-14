# 📋 Instrucciones para Recrear Proyecto Vivado - test_2_cdhs

## Opción 1: Usar el Script TCL (✅ RECOMENDADO)

### Paso 1: En tu máquina local

1. Descarga/Copia toda la carpeta `test_2_cdhs_setup` a tu máquina local:
   ```bash
   # Desde tu máquina local, via SCP o descarga directa:
   scp -r mpsocv2@192.168.x.x:/home/mpsocv2/quick-start/app/test_2_cdhs_setup ~/
   ```

2. Abre **Vivado 2025.1** en tu máquina local

3. En la consola Tcl de Vivado, ejecuta:
   ```tcl
   # Navega a la carpeta hardware
   cd ~/test_2_cdhs_setup/hardware
   
   # Ejecuta el script con el parámetro correcto
   source recreate_test_vivado.tcl -tclargs --origin_dir ..
   ```

   **O directamente desde la línea de comandos (sin abrir GUI):**
   ```bash
   vivado -mode tcl -source ~/test_2_cdhs_setup/hardware/recreate_test_vivado.tcl -tclargs --origin_dir ~/test_2_cdhs_setup
   ```

### Paso 2: Espera a que termine

- El script recreará el proyecto `zynq_transceiver_system`
- Creará todas las fuentes, IP cores, block designs, etc.
- **Nota:** Este proceso puede tardar 10-30 minutos

### Paso 3: Genera el Bitstream

Una vez terminado el script:

```tcl
# En la consola Tcl de Vivado
open_project ./zynq_transceiver_system/zynq_transceiver_system.xpr

# Generar synthesis
launch_runs synth_1
wait_on_run synth_1

# Generar implementation
launch_runs impl_1
wait_on_run impl_1

# Generar bitstream
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

# Generar XSA
write_hw_platform -fixed -include_bit ./zynq_transceiver_system.xsa
```

---

## Opción 2: Recrear Manualmente (Sin TCL)

Si prefieres hacerlo a mano:

### Paso 1: Crear proyecto
1. File → New Project
2. Nombre: `zynq_transceiver_system`
3. Ubicación: `/home/mpsocv2/quick-start/app/test_2_cdhs_setup`
4. FPGA Part: `xczu9eg-ffvb1156-2-e` (ZCU102)

### Paso 2: Añadir fuentes
1. Add Sources → Add Files
2. Selecciona todos los archivos en `hardware/src/`:
   - `CONFIGURABLE_SERIAL_TOP.vhd`
   - `CONFIGURABLE_SERIAL.vhd`
   - `NCO.vhd`
   - `RX_CONFIGURABLE_SERIAL.vhd`
   - `TX_CONFIGURABLE_SERIAL.vhd`
   - `ShiftRegister.vhd`
   - `zcu102_constraints.xdc` (XDC file)

### Paso 3: Crear Block Design
1. Create Block Design
2. Nombre: `system`
3. Click en "+" para añadir IPs:
   - **Zynq UltraScale+ MPSoC** (zynq_ultra_ps_e)
   - **AXI Interconnect** (smartconnect)
   - **AXI GPIO** (x3) - para los transceivers
   - **AXI Interrupt Controller** (axi_intc)
   - **System Reset Module** (proc_sys_reset)

### Paso 4: Configurar el Block Design
- Conectar M_AXI_HPM0_FPD del PS al smartconnect
- Conectar GPIO cores al interconnect
- Ejecutar "Connection Automation"
- Generate Wrapper

### Paso 5: Sintetizar e Implementar
```tcl
# En Tcl:
launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -jobs 4
wait_on_run impl_1

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

### Paso 6: Exportar Hardware
```tcl
# En Tcl:
write_hw_platform -fixed -include_bit -force ./zynq_transceiver_system.xsa
```

---

## Archivos que se generarán

Después de ejecutar el script, deberías tener:

```
test_2_cdhs_setup/hardware/
├── zynq_transceiver_system/           # Proyecto Vivado
│   ├── zynq_transceiver_system.xpr
│   ├── zynq_transceiver_system.runs/
│   │   ├── synth_1/
│   │   └── impl_1/
│   └── ...
├── zynq_transceiver_system.xsa        # Export (para Vitis)
├── zynq_transceiver_system.bit        # Bitstream
├── src/
│   ├── *.vhd
│   └── *.xdc
└── recreate_test_vivado.tcl
```

---

## 🔴 Troubleshooting

### Problema: "Could not find file..."
**Solución:** Asegúrate de que el `--origin_dir` apunta correctamente a la raíz de `test_2_cdhs_setup`:
```tcl
source recreate_test_vivado.tcl -tclargs --origin_dir /ruta/completa/test_2_cdhs_setup
```

### Problema: "Vivado mode tcl not found"
**Solución:** Usa la ruta completa de Vivado:
```bash
/path/to/vivado/bin/vivado -mode tcl -source ...
```

### Problema: Script se cuelga
**Solución:** Presiona Ctrl+C y ejecuta:
```tcl
# Cancela el job
cancel_runs [get_runs]
```

---

## 📝 Próximos pasos después de recrear

1. ✅ Verificar que el proyecto se abrió correctamente en Vivado
2. ✅ Generar bitstream (`write_bitstream`)
3. ✅ Exportar a Vitis (`write_hw_platform`)
4. ✅ Copiar el `.xsa` a la carpeta `hardware/` en TEST_CDHS
5. ✅ Recrear el platform en Vitis
6. ✅ Generar nuevo BOOT.bin
7. ✅ Copiar a tarjeta SD y testear

---

## 💡 Tip: Script Automatizado

Si quieres automatizar todo, crea un archivo `build_project.tcl`:

```tcl
#!/usr/bin/tclsh

# Set the project directory
set proj_dir [file normalize "./zynq_transceiver_system"]
set origin_dir [file normalize "."]

# Source the recreation script
source recreate_test_vivado.tcl -tclargs --origin_dir $origin_dir

# Wait for project to load
after 5000

# Open the project
open_project "$proj_dir/zynq_transceiver_system.xpr"

# Run all builds
puts "Starting synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

puts "Starting implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1

puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

# Export hardware
puts "Exporting hardware..."
write_hw_platform -fixed -include_bit -force ./zynq_transceiver_system.xsa

puts "✅ Project recreation complete!"
exit 0
```

Ejecuta con:
```bash
vivado -mode tcl -source build_project.tcl
```

