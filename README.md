# TFM — Plataforma de comunicación con periféricos sobre MPSoC (ZCU102)

Repositorio del Trabajo Fin de Máster de Jorge Alejandro Estefanía Hidalgo (UPM ETSIT, 2026), desarrollado en el marco del proyecto LINCE en colaboración con el laboratorio B105 Electronic Systems Lab, Sener e Indra.

El trabajo cubre el codiseño hardware-software de un subsistema de comunicaciones serie sobre el **Xilinx Zynq UltraScale+ MPSoC ZCU102**: IP VHDL de transceptor RS422/RS485 configurable, driver RTEMS multi-instancia, y tres PCBs de validación.

## Plataforma objetivo

| Elemento | Detalle |
|---|---|
| Placa | Xilinx ZCU102 (`xczu9eg-ffvb1156-2-e`) |
| RTOS | RTEMS 7 (`aarch64-rtems7`) |
| Herramientas HW | Vivado 2025.1 + Vitis 2025.1 |
| Boot | SD Card → `BOOT.bin` (FSBL + Bitstream + U-Boot) + `rtems.img` |

---

## Estructura del repositorio

```
tfm/
├── 01_hardware/
│   ├── ip_transceiver_serie/     # IP VHDL del transceptor serie (fuente canónica)
│   ├── vivado_cdhs/              # Proyecto Vivado para la placa CDHS (3 transceptores)
│   └── vivado_aocs/              # Proyecto Vivado para la placa AOCS (5 transceptores)
│
├── 03_software_rtems/
│   ├── configurable_transceiver_inter/  # Driver serie RTEMS + app de test
│   ├── cdhs/
│   │   └── spi_adc/              # App de test del ADC ADS7950 (SPI)
│   └── examples/
│       ├── and_gate/             # Ejemplo básico PS-PL (AND gate vía AXI GPIO)
│       └── serial_example_1/     # Ejemplo mínimo de comunicación serie
│
├── 04_tools/                     # Herramientas de desarrollo compartidas
│   ├── generate_boot.sh          # Wizard Vivado → Vitis → BOOT.bin
│   ├── make_img.sh               # Compilar app RTEMS y generar rtems.img
│   ├── automate_ymodem_update.py # Cargar rtems.img en la SD vía YMODEM
│   ├── serial_gui.py             # GUI Python para el puerto serie
│   └── generar_visor.py          # Genera visor web de señales ZCU102
│
├── PCBs/
│   ├── CDHS/                     # Esquemáticos y BOM placa CDHS
│   ├── AOCS/                     # Esquemáticos y BOM placa AOCS
│   └── lince_comunicacion_serial/ # Esquemáticos y BOM placa de comunicación serie
│
└── terminal/                     # Capturas de terminal de las sesiones de validación
```

---

## Descripción de cada sección

### `01_hardware/` — Diseño hardware (PL / FPGA)

#### `ip_transceiver_serie/`
Fuente canónica del IP VHDL del transceptor serie configurable. Es el único lugar donde vive este código; los proyectos Vivado lo referencian desde aquí.

- `vhdl/` — Fuentes del IP: `CONFIGURABLE_SERIAL_TOP.vhd`, `CONFIGURABLE_SERIAL.vhd`, `TX_CONFIGURABLE_SERIAL.vhd` (con estados PreDE/PostDE), `RX_CONFIGURABLE_SERIAL.vhd` (con verificación de start-bit), `NCO.vhd`, `ShiftRegister.vhd`.
- `testbench/` — Testbenches de simulación.
- `scripts/` — Scripts TCL compartidos: `new_generate_transceivers.tcl` (generador parametrizable del Block Design), `last_uart.tcl`, constraints de pines (`zcu102_constraints.xdc`, `ZCU102_RD_J3_6.xdc`).

#### `vivado_cdhs/`
Proyecto Vivado para la placa CDHS (3 transceptores serie + PWM autónomo).

- `scripts/new_rebuild_all.tcl` — Regenera el proyecto Vivado completo desde cero. Referencia el VHDL canónico de `ip_transceiver_serie/vhdl/` y los scripts compartidos de `ip_transceiver_serie/scripts/`.
- `src/PWMx4_auto_test.vhd` — Bloque VHDL específico del CDHS: genera 4 señales PWM autónomas (10 kHz, 5 kHz, 1 kHz, 100 Hz) para validar la interfaz de calentadores.

```tcl
# Regenerar el proyecto (desde Vivado, con CWD en vivado_cdhs/):
source scripts/new_rebuild_all.tcl
```

#### `vivado_aocs/`
Proyecto Vivado para la placa AOCS (5 transceptores serie + control de motores).

- `scripts/new_rebuild_all.tcl` — Análogo al de CDHS, configurado para 5 transceptores.
- `src/Motor_H_Bridge_test.vhd` — Bloque VHDL específico del AOCS: genera 3 pares de señales PWM complementarias para control de dirección de puentes en H (ejes X, Y, Z).

---

### `03_software_rtems/` — Aplicaciones RTEMS

Todas las aplicaciones usan **Waf** como sistema de build. El script `04_tools/make_img.sh` automatiza la compilación.

> **Dependencia común** (no incluida en este repo):
> ```bash
> export RTEMS_PREFIX=$HOME/quick-start/rtems/7
> ```

#### `configurable_transceiver_inter/`
Driver serie y aplicación principal de test multi-transceptor. Funciona con cualquier número de instancias del IP gracias al descubrimiento dinámico de hardware en tiempo de arranque.

- `transceiver.c / transceiver.h` — Driver del transceptor: descubrimiento del hardware, modelo de interrupciones con ISR maestra y tareas worker por canal, buffers circulares RX/TX, API pública de 5 funciones.
- `main.c` — Consola interactiva multi-transceptor (envío individual o broadcast, modo slow rate).
- `init.c`, `mmu_pl_map.c`, `wscript`, `configurable_transceiver.bif` — Infraestructura de la app RTEMS.

#### `cdhs/spi_adc/`
App de test del ADC ADS7950 de la placa CDHS por SPI.

- `ads7950.c / ads7950.h` — Driver de bajo nivel (acceso MMIO directo al controlador SPI Cadence del PS).
- `main.c` — Lectura continua de los 4 canales del ADC.

#### `examples/`
Ejemplos de referencia para entender el flujo PS-PL básico.

- `and_gate/` — Puerta AND implementada en la PL, controlada desde la PS vía AXI GPIO.
- `serial_example_1/` — Comunicación serie mínima desde RTEMS.

---

### `04_tools/` — Herramientas de desarrollo

#### `generate_boot.sh`
Wizard interactivo que automatiza el pipeline completo desde el proyecto de Vivado hasta el `BOOT.bin`. Ofrece tres puntos de entrada: generar bitstream desde cero, exportar XSA con bitstream existente, o usar un XSA ya exportado. Invoca Vivado y Vitis en modo batch y ensambla el `BOOT.bin` con `bootgen`.

```bash
./tfm/04_tools/generate_boot.sh
```

#### `make_img.sh`
Compila la aplicación RTEMS con Waf y genera `rtems.img` listo para cargar en la SD. Se ejecuta desde el directorio de la app.

```bash
cd tfm/03_software_rtems/configurable_transceiver_inter
../../04_tools/make_img.sh
```

#### `automate_ymodem_update.py`
Carga `rtems.img` (y opcionalmente `BOOT.bin`) en la SD de la ZCU102 sin sacarla del equipo, enviándola por YMODEM a través del puerto serie USB a U-Boot.

```bash
python3 tfm/04_tools/automate_ymodem_update.py [--boot ./BOOT.bin]
```

> Requiere: `pyserial`, `lrzsz` (`apt install lrzsz`).

#### `serial_gui.py`
GUI Python para monitorizar y enviar datos por el puerto serie de la ZCU102.

#### `generar_visor.py`
Genera `visor_zcu102.html`, un visor web de señales para debug del diseño en la ZCU102.

---

### `PCBs/` — Esquemáticos y listas de materiales

- `CDHS/` — Placa LINCE3 CDHS BreakoutBox: interfaces CAN, RS422/RS485 (×3), PWM (×4), ADC SPI.
- `AOCS/` — Placa LINCE3 AOCS BreakoutBox: interfaces RS422/RS485 (×5), SpaceWire LVDS (×2), PWM para puentes en H.
- `lince_comunicacion_serial/` — Placa de diseño propio: 14 canales serie (7 RS485 en bus compartido + 7 RS422 maestro/esclavo).

---

### `terminal/` — Capturas de validación

Salidas de terminal de las sesiones de prueba sobre las placas CDHS y AOCS:

- `cdhs_testing_rs` — Loopback RS422/RS485 en CDHS (3 transceptores).
- `aocs_testing_rs.txt` — Loopback RS422/RS485 en AOCS (5 transceptores).
- `cdhs_testing_can.txt` — Suite CAN: 26/26 tests PASS.
- `cdhs_testing_adc.txt` — Lecturas ADC ADS7950 con barrido de tensión en CH2.

---

## Flujo de trabajo general

```
1. Generar hardware (Vivado)
   └─ source tfm/01_hardware/vivado_cdhs/scripts/new_rebuild_all.tcl
      → genera bitstream + .xsa

2. Generar BOOT.bin
   └─ ./tfm/04_tools/generate_boot.sh   (wizard interactivo)
      → genera BOOT.bin

3. Compilar app RTEMS
   └─ cd tfm/03_software_rtems/configurable_transceiver_inter
      ../../04_tools/make_img.sh
      → genera rtems.img

4. Cargar en SD (sin sacarla del equipo)
   └─ python3 tfm/04_tools/automate_ymodem_update.py [--boot ./BOOT.bin]

5. Monitorizar
   └─ python3 tfm/04_tools/serial_gui.py  (o minicom/putty a 115200 8N1)
```

---

## Referencias

- [Xilinx ZCU102 Evaluation Board User Guide (UG1182)](https://www.xilinx.com/support/documentation/boards_and_kits/zcu102/ug1182-zcu102-eval-bd.pdf)
- [RTEMS Project](https://www.rtems.org/)
- [Vivado Design Suite User Guide (UG895)](https://docs.xilinx.com/r/en-US/ug895-vivado-system-level-design-entry)
- [Zynq UltraScale+ MPSoC Technical Reference Manual (UG1085)](https://docs.amd.com/r/en-US/ug1085-zynq-ultrascale-trm)
