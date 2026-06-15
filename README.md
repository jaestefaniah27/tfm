# TFM — Sistema CDHS/AOCS sobre Zynq UltraScale+ MPSoC (ZCU102)

Repositorio del Trabajo Fin de Máster. Contiene el diseño hardware (FPGA/PL), el firmware de arranque y las aplicaciones de software (RTEMS) de un sistema CDHS (*Command and Data Handling System*) y AOCS (*Attitude and Orbit Control System*) sobre la plataforma **Xilinx Zynq UltraScale+ MPSoC ZCU102**.

## Plataforma objetivo

| Elemento | Detalle |
|---|---|
| Placa | Xilinx ZCU102 (`xczu9eg-ffvb1156-2-e`) |
| RTOS | RTEMS 7 (`aarch64-rtems7`) |
| Herramientas HW | Vivado 2025.1 + Vitis 2025.1 |
| Boot | SD Card → BOOT.bin (FSBL + Bitstream + U-Boot) + `rtems.img` |

---

## Estructura del repositorio

```
tfm/
├── 01_hardware/
│   ├── vivado_cdhs/              # Diseño Vivado del subsistema CDHS
│   ├── vivado_aocs/              # Diseño Vivado del subsistema AOCS
│   └── ip_transceiver_serie/     # IP VHDL del transceptor serie configurable
│
├── 02_firmware/
│   ├── boot_scripts/             # Scripts Python para generar BOOT.bin
│   └── fsbl_cdhs/                # FSBL modificado (First Stage Boot Loader)
│
├── 03_software_rtems/
│   ├── configurable_transceiver_inter/  # BSP definitivo del transceptor (con hardware/)
│   ├── test_cdhs/                       # App completa CDHS (CAN + SPI + RS-422)
│   ├── test_2_cdhs_setup/               # Setup CDHS v2 (con scripts Vivado integrados)
│   ├── spi_test/                        # Test SPI con ADC ADS7950
│   └── examples/
│       ├── and_gate/                    # Ejemplo básico PS-PL (AND gate via AXI GPIO)
│       └── serial_example_1/            # Ejemplo comunicación serie
│
└── 04_tools/                            # Scripts de desarrollo compartidos
    ├── make_img.sh                      # Compilar app RTEMS y generar rtems.img
    ├── automate_ymodem_update.py        # Cargar rtems.img (y BOOT.bin) en la SD vía YMODEM
    └── serial_gui.py                    # GUI Python para monitorizar el puerto serie
```

---

## Descripción de cada sección

### `01_hardware/` — Diseño Hardware (PL / FPGA)

#### `vivado_cdhs/`
Diseño Vivado para el subsistema CDHS. Incluye instancias del IP de transceptor serie configurable conectadas al PS vía AXI, junto con periféricos CAN y SPI del PS.

- `src/` — Fuentes VHDL: transceptor configurable (TX, RX, NCO, ShiftRegister, TOP), constraints ZCU102.
- `scripts/` — Scripts TCL para regenerar el Block Design desde cero (`new_rebuild_all.tcl`, `new_generate_transceivers.tcl`).

#### `vivado_aocs/`
Diseño Vivado para el subsistema AOCS. Añade sobre el CDHS el bloque `Motor_H_Bridge_test.vhd` para control de actuadores.

- `src/` — Fuentes VHDL (misma base que CDHS + H-Bridge), constraints ZCU102.
- `scripts/` — Scripts TCL para regenerar el diseño.

#### `ip_transceiver_serie/`
IP VHDL del transceptor serie configurable. Es el bloque fundamental del sistema: implementa un UART parametrizable instanciable múltiples veces en la PL.

- `vhdl/` — Fuentes del IP: `CONFIGURABLE_SERIAL.vhd`, `TX_CONFIGURABLE_SERIAL.vhd`, `RX_CONFIGURABLE_SERIAL.vhd`, `NCO.vhd`, `ShiftRegister.vhd`, `CONFIGURABLE_SERIAL_TOP.vhd`, `RS232top.vhd`.
- `testbench/` — Testbenches de simulación: `tb_CONFIGURABLE_SERIAL_TOP.vhd`, `tb_NCO.vhd`, `tb_RS232_TX.vhd`.
- `scripts/` — Scripts TCL para instanciar transcriptores (`generate_transceivers.tcl`, `add_transceiver.tcl`), constraints de pines (`zcu102_constraints.xdc`, `ZCU102_RD_J3_6.xdc`).

> Para regenerar el proyecto Vivado completo:
> ```tcl
> # Desde la consola TCL de Vivado:
> source scripts/rebuild_all.tcl
> ```

---

### `02_firmware/` — Firmware de arranque

#### `boot_scripts/`
Scripts Python para generar el `BOOT.bin` con distintas configuraciones de hardware (CAN+PWM+RS, H-Bridge, AOCS, etc.). Cada `setup_*.py` corresponde a una plataforma Vitis diferente.

- `generate_boot.sh` — Script shell de apoyo para el flujo de generación.

#### `fsbl_cdhs/`
Código fuente del FSBL (*First Stage Boot Loader*) de Xilinx, versión `fsbl_full_cdhs_with_rx_patch`. Esta es la versión más completa usada en el TFM, que incluye el parche para la inicialización correcta del receptor serie.

- `src/` — Fuentes C del FSBL: `xfsbl_main.c`, `xfsbl_hooks.c` (punto de entrada para personalización), `xfsbl_initialization.c`, `psu_init.c/h` (init específica del board), y todos los módulos estándar de Xilinx.

> Los archivos `psu_init.c/h` son generados por Vivado al exportar el XSA. Si se regenera el diseño HW, deben actualizarse desde Vitis.

---

### `03_software_rtems/` — Aplicaciones RTEMS

Todas las aplicaciones usan **Waf** como sistema de build y el framework `rtems_waf` (submódulo Git, no incluido en este repo). El script `make_img.sh` de `04_tools/` automatiza la compilación y generación de la imagen U-Boot.

> **Dependencias comunes** (no incluidas en este repo):
> ```bash
> git submodule update --init --recursive   # clona rtems_waf y device-tree-xlnx
> export RTEMS_PREFIX=$HOME/quick-start/rtems/7
> ../../04_tools/make_img.sh                # desde el directorio de la app
> ```

#### `configurable_transceiver_inter/`
**BSP definitivo del transceptor serie configurable**. Contiene el driver `transceiver.c/h`, la aplicación principal con lógica RX/TX (`main.c`), la GUI serie (`serial_gui.py`) y la carpeta `hardware/` con el diseño Vivado completo (VHDL + scripts TCL para regenerar el proyecto con múltiples instancias de transceptor).

#### `test_cdhs/`
**Aplicación principal del CDHS**. Prueba de integración completa que ejercita:
- Múltiples transceptores RS-422/RS-232 vía PL (driver `transceiver.c/h`).
- Bus CAN (CAN0 y CAN1) vía PS.
- Bus SPI vía PS.

Incluye:
- `hardware/` — Diseño Vivado con src VHDL y scripts TCL.
- `scripts/` — Scripts auxiliares de Vivado.
- `DIAGNOSTICO_BOOT.md` — Guía de diagnóstico si el boot falla.
- `visor_zcu102.html` — Visor web de señales para debug.

#### `test_2_cdhs_setup/`
Setup alternativo del CDHS v2. Incluye scripts TCL para recrear el proyecto Vivado directamente desde la raíz (`recreate_test_vivado.tcl`, `build_project_auto.tcl`).

#### `spi_test/`
Prueba del bus SPI con el ADC **ADS7950** de Texas Instruments.
- `ads7950.c/h` — Driver del ADC.
- `main.c` — Aplicación de prueba de adquisición.

#### `examples/and_gate/`
Ejemplo básico de integración PS-PL mediante AXI GPIO. Implementa una puerta AND en la PL y la controla desde software para verificar la tabla de verdad. Ver `02_firmware/PS_PL_instructions.md` para las instrucciones detalladas.

#### `examples/serial_example_1/`
Ejemplo mínimo de comunicación serie desde RTEMS.

---

### `04_tools/` — Scripts de desarrollo compartidos

Estos scripts son herramientas de apoyo al flujo de desarrollo. Son comunes a todas las aplicaciones RTEMS y están centralizados aquí para evitar duplicidades.

#### `make_img.sh`
Compila la aplicación RTEMS con Waf y genera el archivo `rtems.img` listo para cargar en la SD.

Detecta automáticamente el nombre de la aplicación a partir del directorio en el que se ejecuta, por lo que funciona para cualquier app sin modificarlo.

```bash
# Uso (desde el directorio de cualquier app RTEMS):
export RTEMS_PREFIX=$HOME/quick-start/rtems/7   # si no está en el PATH
cd tfm/03_software_rtems/test_cdhs
../../04_tools/make_img.sh
# → genera rtems.img en el directorio actual
```

El script:
1. Localiza el toolchain `aarch64-rtems7-*` en `RTEMS_PREFIX`.
2. Inicializa submódulos (`rtems_waf`) si no existen.
3. Ejecuta `./waf` (y `./waf configure` automáticamente si es la primera vez).
4. Convierte el `.exe` a binario plano con `objcopy`, lo comprime con gzip y genera la imagen U-Boot con `mkimage`.

#### `automate_ymodem_update.py`
Carga `rtems.img` en la tarjeta SD de la ZCU102 **sin sacar la SD del equipo**, enviándola por el puerto serie USB mediante el protocolo YMODEM y comandos de U-Boot.

```bash
# Uso básico (solo actualiza rtems.img):
python3 04_tools/automate_ymodem_update.py

# También actualizar el BOOT.bin (solo si cambió el hardware):
python3 04_tools/automate_ymodem_update.py --boot ./BOOT.bin
```

El script:
1. Abre el puerto serie (`/dev/ttyUSB0` a 115200), interrumpe el autoboot de U-Boot y manda `mmcinit`.
2. Envía el fichero por YMODEM (`sb`, paquete `lrzsz`) a la dirección de carga `loady`.
3. Escribe en la partición FAT de la SD con `fatwrite`.
4. Opcionalmente intenta un reset automático por JTAG vía XSDB antes de pedirte que pulses el botón físico.

> Requiere: `python3`, `pyserial`, `lrzsz` (`apt install lrzsz`).

#### `serial_gui.py`
GUI Python para monitorizar y enviar datos por el puerto serie USB de la ZCU102. Útil para visualizar en tiempo real la salida de los transcriptores durante el desarrollo, sin necesitar un terminal externo.

```bash
python3 04_tools/serial_gui.py
```

---

## Flujo de trabajo general

```
1. Generar HW (Vivado)
   └─ source tfm/01_hardware/vivado_cdhs/scripts/new_rebuild_all.tcl
       └─ Genera: design_wrapper.bit + design_wrapper.xsa

2. Generar BOOT.bin (Vitis + Python)
   └─ python tfm/02_firmware/boot_scripts/setup_full_cdhs_with_rx_patch.py
       └─ Entrada: .xsa + fsbl.elf + bitstream + u-boot.elf
       └─ Salida:  BOOT.bin

3. Compilar app RTEMS
   └─ cd tfm/03_software_rtems/test_cdhs
      ../../04_tools/make_img.sh
       └─ Salida: rtems.img

4. Cargar en SD Card (sin sacar la SD)
   └─ python tfm/04_tools/automate_ymodem_update.py [--boot ./BOOT.bin]
       └─ Envía rtems.img por YMODEM a U-Boot y escribe en FAT

5. Monitorizar
   └─ python tfm/04_tools/serial_gui.py  (o minicom/putty a 115200 8N1)
```

---

## Referencias

- [Xilinx ZCU102 Evaluation Board User Guide (UG1182)](https://www.xilinx.com/support/documentation/boards_and_kits/zcu102/ug1182-zcu102-eval-bd.pdf)
- [RTEMS Project](https://www.rtems.org/)
- [Vivado Design Suite User Guide](https://docs.xilinx.com/r/en-US/ug895-vivado-system-level-design-entry)
