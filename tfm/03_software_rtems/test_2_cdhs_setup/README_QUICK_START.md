# 🚀 Guía Rápida - Recrear Proyecto Vivado test_2_cdhs

## 📦 Estructura Preparada

La carpeta `test_2_cdhs_setup` contiene:

```
test_2_cdhs_setup/
├── INSTRUCCIONES_RECREAR_VIVADO.md  ← Lee esto primero
├── hardware/
│   ├── vivado_build.sh              ← Script bash automatizado
│   ├── build_project_auto.tcl       ← Script TCL optimizado
│   ├── recreate_test_vivado.tcl     ← Script original del proyecto
│   └── src/
│       ├── *.vhd                    ← Código VHDL
│       └── *.xdc                    ← Constraints de pines
```

---

## ⚡ Opción Rápida (Recomendado)

### En tu máquina local con Vivado 2025.1:

```bash
# 1. Descarga la carpeta
scp -r usuario@servidor:/home/mpsocv2/quick-start/app/test_2_cdhs_setup ~

# 2. Entra a la carpeta
cd ~/test_2_cdhs_setup/hardware

# 3. Ejecuta el script (modo interactivo)
./vivado_build.sh

# 4. Selecciona opción 6 (TODO en un solo comando)
```

Eso es todo. El script hará:
- ✓ Crear proyecto Vivado
- ✓ Añadir fuentes VHDL
- ✓ Síntesis
- ✓ Implementación
- ✓ Generar bitstream
- ✓ Exportar para Vitis

**Tiempo total:** ~30-60 minutos

---

## 🎯 Opción Manual (Si prefieres control total)

### Desde Vivado Tcl Console:

```tcl
cd ~/test_2_cdhs_setup/hardware
source recreate_test_vivado.tcl -tclargs --origin_dir ..
```

### Línea de comandos (sin GUI):

```bash
vivado -mode tcl -source ~/test_2_cdhs_setup/hardware/recreate_test_vivado.tcl \
  -tclargs --origin_dir ~/test_2_cdhs_setup
```

---

## 📂 Pasos Post-Recreación

Una vez que el proyecto está recreado:

1. **Copia los archivos generados** al proyecto original:
   ```bash
   cp -v ~/test_2_cdhs_setup/hardware/zynq_transceiver_system.bit \
         /path/to/TEST_CDHS/hardware/
   
   cp -v ~/test_2_cdhs_setup/hardware/zynq_transceiver_system.xsa \
         /path/to/TEST_CDHS/hardware/
   ```

2. **Regenera el platform** en Vitis:
   - Crea nuevo platform con el `.xsa` actualizado

3. **Genera nuevo BOOT.bin** en Vitis:
   - Create Boot Image → Zynq Ultrascale+

4. **Copia a SD y testea** en la ZCU102

---

## 🔧 Troubleshooting

### "Vivado no encontrado"
```bash
# Añade Vivado al PATH
export PATH="/opt/Xilinx/Vivado/2025.1/bin:$PATH"

# O en Bash permanentemente:
echo 'export PATH="/opt/Xilinx/Vivado/2025.1/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### "Script timeout"
- Los scripts pueden tardar mucho. Espera pacientemente.
- Si se cuelga, presiona Ctrl+C y ejecuta nuevamente

### "Archivos faltantes"
- Verifica que todos los `.vhd` y `.xdc` estén en `hardware/src/`
- Compara con el proyecto original en `TEST_CDHS/hardware/src/`

---

## 📝 Alternativa: Copiar Proyecto Existente

Si solo quieres una copia del proyecto actual:

```bash
# Desde la máquina remota
cp -r /home/mpsocv2/quick-start/app/TEST_CDHS/hardware/vivado_proj \
      /home/mpsocv2/quick-start/app/test_2_cdhs_setup/hardware/

# Renombra si necesario
mv test_2_cdhs_setup/hardware/vivado_proj \
   test_2_cdhs_setup/hardware/zynq_transceiver_system
```

---

## ✅ Verificación Final

Después de completar, deberías tener:

```
test_2_cdhs_setup/hardware/
├── zynq_transceiver_system/           ← Proyecto Vivado
│   ├── zynq_transceiver_system.xpr
│   ├── zynq_transceiver_system.runs/
│   │   └── impl_1/
│   │       └── system_wrapper.bit
│   └── ...
├── zynq_transceiver_system.bit        ← Bitstream ✓
├── zynq_transceiver_system.xsa        ← Para Vitis ✓
└── src/
    └── *.vhd, *.xdc
```

---

## 💻 Scripts Disponibles

| Script | Uso | Donde |
|--------|-----|-------|
| `vivado_build.sh` | Menú interactivo completo | `hardware/` |
| `build_project_auto.tcl` | Creación automática TCL | `hardware/` |
| `recreate_test_vivado.tcl` | Script original del proyecto | `hardware/` |
| `INSTRUCCIONES_RECREAR_VIVADO.md` | Documentación detallada | Raíz |

---

## 📞 Soporte Rápido

### Preguntas comunes:

**P: ¿Cuánto tarda?**
- Crear proyecto: 2-5 min
- Síntesis: 10-15 min
- Implementación: 15-30 min
- Bitstream: 5-10 min
- **Total: 40-60 minutos**

**P: ¿Puedo cancelar a mitad?**
- Sí, presiona Ctrl+C
- El proyecto parcial se guardará

**P: ¿Por qué TCL y no GUI?**
- TCL es automatizable
- Funciona sin interfaz gráfica
- Reproducible y versionable

**P: ¿Necesito Vivado en la máquina remota?**
- NO, solo necesitas localmente donde ejecutes Vivado

---

## 🎓 Próximos Pasos Después de esto:

1. Actualizar BOOT.bin en TEST_CDHS
2. Arreglar el problema de boot (ver DIAGNOSTICO_BOOT.md)
3. Testear SPI y CAN en la placa
4. Debugging si es necesario

---

¡Listo! 🚀 Descarga la carpeta y ejecuta `./vivado_build.sh`
