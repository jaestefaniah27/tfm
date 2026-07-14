# TFM — Transceptores serie configurables en FPGA y transporte PS↔PL sobre Zynq UltraScale+ (ZCU102)

Repositorio del Trabajo Fin de Máster. El sistema implementa **14 UART configurables en la PL** de una Xilinx ZCU102 y los explota desde **RTEMS 7** en el PS.

La pregunta que vertebra el trabajo es **cómo mover los datos entre el PS y esos 14 UART**. Se implementaron y midieron tres arquitecturas de transporte distintas sobre el *mismo* IP serie y el *mismo* software de aplicación:

| Variante | Transporte PS↔PL | Estado |
|---|---|---|
| **A — GPIO** | AXI-Lite / AXI-GPIO, un registro por canal, byte a byte por interrupción | Funciona; muy costosa en CPU |
| **B — DMA14** | 14× AXI-DMA (PG021), un DMA por canal, AXI-Stream | Funciona en TX; recursos elevados |
| **C — MCDMA + puente** | 1× AXI-MCDMA (PG288) + puente VHDL que multiplexa 14 canales | **Solución final** |

El banco de pruebas (`03_bench_loopback/`) ejecuta el mismo `bench_main.c` sobre las tres, con un módulo de *loopback* insertado en la PL para poder medir sin la PCB. (Las tres copias del programa difieren en cuatro líneas; el porqué está en [SOFTWARE.md](tfm/03_bench_loopback/SOFTWARE.md).)

## Plataforma

| Elemento | Detalle |
|---|---|
| Placa | Xilinx ZCU102 (`xczu9eg-ffvb1156-2-e`) |
| RTOS | RTEMS 7 (`aarch64-rtems7`), build con Waf |
| Herramientas | Vivado 2025.1 + Vitis 2025.1 |
| Arranque | SD FAT32 → `BOOT.bin` (FSBL + bitstream + U-Boot) + `rtems.img` |

---

## Estructura

```
tfm/
├── 00_docs/                  Documentación transversal e informes
│   ├── informe_benchmark.html        comparativa de las 3 variantes
│   ├── registro_investigacion_rx.txt bitácora de depuración del RX
│   └── PS_PL_instructions.md
│
├── 01_ip_serie/              IP VHDL del transceptor serie configurable (común a todo)
│   ├── vhdl/                     CONFIGURABLE_SERIAL, TX/RX, NCO, ShiftRegister,
│   │                             MULTI_SERIAL_CORE, SERIAL_CHANNEL_IP, UART_AXIS_TOP
│   ├── testbench/                testbenches del canal y del RX
│   ├── constraints/              XDC de la ZCU102
│   └── scripts/                  empaquetado del IP y generación de N transceptores
│
├── 02_transporte/            LAS TRES VARIANTES (el núcleo del TFM)
│   ├── a_gpio/                   AXI-GPIO          → hardware/ + software/
│   ├── b_dma14/                  14× AXI-DMA       → hardware/ + software/
│   └── c_mcdma_bridge/           MCDMA + puente    → hardware/ + software/ + entrega_sd_pcb/
│
├── 03_bench_loopback/        Banco de pruebas comparativo
│   ├── rtl/                      loopback en la PL (bus wired-AND) + su testbench
│   ├── scripts/                  parcheo del block design, build y flasheo
│   ├── resultados/               consolas capturadas de cada variante
│   ├── SOFTWARE.md               dónde vive bench_main.c y cómo compilarlo
│   └── imagenes_sd/              BOOT.bin + rtems.img listos para la SD
│
├── 04_pcb_caracterizacion/   Caracterización eléctrica de la PCB (bitstream SIN loopback)
│   ├── software/                 app RTEMS: 9 tests sobre los drivers y el cobre
│   ├── hardware/                 reimplementación del bitstream limpio + BOOT.bin
│   ├── imagen_sd/                BOOT.bin + rtems.img listos para la SD
│   └── resultados/               consolas y CSV de las medidas
│
├── 05_aplicaciones_cdhs_aocs/  Línea previa: CDHS/AOCS (CAN, SPI, RS-422, puente en H)
├── 06_firmware/              FSBL modificado y scripts de generación de BOOT.bin
└── 07_tools/                 make_img.sh, carga por YMODEM, GUI serie
```

Cada carpeta relevante tiene su propio `README.md` con el detalle.

### Por qué esta estructura

El IP serie (`01_ip_serie`) es el mismo en las tres variantes, y el programa de pruebas (`bench_main.c`) también. **Lo único que cambia entre variantes es el transporte**: el bloque de la PL que conecta los UART al PS, y el driver `transceiver.c/h` que lo maneja. Por eso el árbol separa lo común (01) de lo que se compara (02) y de lo que lo mide (03), en vez de guardar tres copias completas del proyecto.

---

## Resultados del benchmark

Medidos con el loopback en la PL, 14 canales, 115200 8N1. Ver [03_bench_loopback/README.md](tfm/03_bench_loopback/README.md) para la interpretación completa y las salvedades.

| Métrica | GPIO | MCDMA |
|---|---|---|
| Latencia ida y vuelta (frame de 11 B) | 4606 µs | **1530 µs** |
| Throughput 1 canal (techo de línea 11520 B/s) | 3471 B/s (30 %) | **11461 B/s (99 %)** |
| Interrupciones por KB transferido | 1250 | **3** |

El salto decisivo es `irq_per_kb`: la variante GPIO interrumpe al PS **una vez por byte** en recepción, lo que satura la CPU y limita el throughput a un tercio del techo de línea. El MCDMA transfiere paquetes completos por DMA y baja a 3 IRQ/KB, con lo que la línea serie pasa a ser el único cuello de botella.

> La variante DMA14 se midió con un bitstream cuyo lazo de loopback no quedó cerrado, así que sus cifras de recepción **no son comparables** y salen a cero en `resultados/02_DMA14.txt`. Lo aprovechable de ese run es la transmisión (3 IRQ/KB, igual que MCDMA).

---

## Flujo de trabajo

```
1. Hardware (Vivado)
   cd tfm/02_transporte/c_mcdma_bridge/hardware
   vivado -mode batch -source scripts/build_mcdma_bridge.tcl   → .bit + .xsa

2. BOOT.bin (Vitis)
   scripts/generate_boot.sh                                    → BOOT.bin

3. Aplicación RTEMS
   cd tfm/02_transporte/c_mcdma_bridge/software
   export RTEMS_PREFIX=$HOME/quick-start/rtems/7
   ../../../07_tools/make_img.sh                               → rtems.img

4. Carga en la SD sin sacarla de la placa (YMODEM sobre U-Boot)
   python3 tfm/07_tools/automate_ymodem_update.py [--boot ./BOOT.bin]

5. Monitorizar
   python3 tfm/07_tools/serial_gui.py    (o minicom, 115200 8N1)
```

Para reproducir solo el benchmark no hace falta compilar nada: en `03_bench_loopback/imagenes_sd/` están las tres imágenes listas para copiar a la SD. Lo mismo para la caracterización de la PCB, en `04_pcb_caracterizacion/imagen_sd/` — pero **son bitstreams distintos**: el del benchmark lleva el loopback dentro de la PL, el de la PCB no.

---

## Caracterización de la PCB

Medida la placa de verdad (14 transceptores RS-485/RS-422), con los nueve tests de [04_pcb_caracterizacion](tfm/04_pcb_caracterizacion/README.md): polarización de reposo, mapa de conectividad real, integridad del multidrop, velocidad máxima por bus, efecto del limitador de slew, guard time del DE, diafonía, colisión y estabilidad.

El resultado que cambia las cosas: **el bit SLO está invertido respecto al chip transceptor**. Con el valor por defecto (`SLO=0`), que es en realidad el modo *slew-limitado*, el bus A multidrop topa en 460 kbps y los RS-422 en 1 Mbps. Poniendo ese bit a 1, los tres buses van limpios a **4 Mbps**. Detalle y salvedades en [RESULTADOS.md](tfm/04_pcb_caracterizacion/RESULTADOS.md).

## Dependencias no versionadas

```bash
git submodule update --init --recursive   # rtems_waf, device-tree-xlnx
export RTEMS_PREFIX=$HOME/quick-start/rtems/7
```

Los proyectos de Vivado (`.xpr`, `.runs`, `.cache`) **no** están en el repo: se regeneran desde los scripts TCL de cada variante.

## Referencias

- [ZCU102 Evaluation Board User Guide (UG1182)](https://docs.xilinx.com/v/u/en-US/ug1182-zcu102-eval-bd)
- [AXI DMA v7.1 (PG021)](https://docs.xilinx.com/r/en-US/pg021_axi_dma)
- [AXI MCDMA v1.1 (PG288)](https://docs.xilinx.com/r/en-US/pg288-axi-mcdma)
- [RTEMS Project](https://www.rtems.org/)
