# 03 — Banco de pruebas comparativo (loopback en la PL)

Mide las tres variantes de transporte con el mismo programa de pruebas y **sin necesidad de la PCB ni de cables**: un módulo de loopback insertado en la PL cierra los buses dentro de la FPGA.

El programa (`bench_main.c`) vive junto a cada variante, en `02_transporte/<variante>/software/bench/`. El porqué y cómo compilarlo, en [SOFTWARE.md](SOFTWARE.md).

## El loopback (`rtl/`)

Reproduce dentro de la FPGA la topología de buses que `bench_compat.h` da por supuesta en la PCB:

| Bus | Maestro | Esclavos |
|---|---|---|
| A (multipunto) | CH0 | CH1..CH6 |
| B | CH7 | CH8..CH10 |
| C | CH11 | CH12..CH13 |

Un bus RS-485 en reposo está a `1` y sus drivers hacen *wired-AND*. La línea de recepción de un canal es, por tanto, el AND de las transmisiones de **los demás** canales de su bus:

```
rd[1] = td[0] & td[2] & … & td[6]   →  con los esclavos callados, rd[1] = td[0]
rd[0] = td[1] & td[2] & … & td[6]   →  con los esclavos callados, rd[0] = 1
```

**Un canal no se oye a sí mismo**, igual que en la PCB, donde el receptor se inhibe mientras `DE` está activo. Si se realimentara el eco, cada byte enviado se contaría dos veces en `bytes_rx` y el test de *overrun* mediría el doble de pérdidas. Los buses están además aislados entre sí, de modo que el test de transmisión concurrente (T3) mide solapamiento real y no diafonía.

`scripts/patch_and_build.tcl` desconecta la net que unía cada pin físico de recepción con su transceptor y la alimenta desde el loopback. Las líneas de transmisión siguen llegando a los pines y además entran al loopback. Los puertos de recepción externos se dejan declarados aunque queden sin carga: así el XDC sigue siendo válido y no hubo que tocar ni un constraint de pines.

`rtl/tb_bench_loopback.v` verifica el módulo con 16 comprobaciones (todas pasan).

## Ejecutar el benchmark

No hace falta compilar nada. Copia a una SD FAT32 el `BOOT.bin` y el `rtems.img` de **una sola** carpeta de `imagenes_sd/`, arranca la ZCU102 y captura la consola (115200 8N1). El autodiagnóstico debe decir:

```
[BENCH] Autodiagnostico OK: 14 canales, lazo CH0->CH1 cerrado.
```

Si dice que no hay lazo, el bitstream grabado no lleva el loopback y las cifras de recepción no valen. Las salidas se emiten como CSV con prefijo `BENCH,`, listas para filtrar con `grep '^BENCH,'`.

## Reconstruir desde cero

```bash
V=/tools/Xilinx/2025.1/Vivado/bin/vivado

# simular el loopback (16 comprobaciones)
cd rtl && xvlog bench_loopback.v tb_bench_loopback.v && xelab tb_bench_loopback -s tb && xsim tb -R

# re-implementar cada variante (~10-40 min cada una)
$V -mode batch -source scripts/patch_and_build.tcl -tclargs <ruta>/zynq_transceiver_system.xpr system       scalar 6
$V -mode batch -source scripts/patch_and_build.tcl -tclargs <ruta>/zynq_dma14_pcb.xpr        system       scalar 6
$V -mode batch -source scripts/patch_and_build.tcl -tclargs <ruta>/serial_bridge.xpr         system_mcdma vector 6

# empaquetar BOOT.bin + rtems.img
./scripts/make_boot.sh
```

Los `.xpr` se regeneran antes con los scripts TCL de cada variante en [../02_transporte](../02_transporte).

## Resultados (`resultados/`)

Una consola capturada por variante. `run1_previo/` guarda una primera tanda anterior a las correcciones del RX.

| Métrica (14 canales, 115200 8N1) | GPIO | DMA14 | MCDMA |
|---|---|---|---|
| Latencia ida y vuelta, frame de 11 B | 4606 µs | — | **1530 µs** |
| Throughput 1 canal (techo de línea 11520 B/s) | 3471 B/s | — | **11461 B/s** |
| IRQ por KB (recepción) | 1250 | — | **3** |
| IRQ por KB (transmisión) | 1250 | 3 | 3 |

**El run de DMA14 no tiene el lazo cerrado**: el bitstream que se grabó no llevaba el loopback, así que no recibió ningún byte y T1–T7 salen a cero o en *timeout*. Sus cifras de recepción **no son comparables**; lo válido es la parte de transmisión. Para completarlo hay que re-implementar esa variante con `patch_and_build.tcl` y repetir la captura.

La conclusión que sí sostienen los datos es la del coste por interrupción: GPIO interrumpe una vez por byte recibido y por eso se queda en el 30 % del techo de línea, mientras que el MCDMA, moviendo paquetes completos, llega al 99 % y deja la línea serie como único cuello de botella.

## Qué mide y qué no

Con el loopback en la PL la señal no atraviesa los transceptores RS-485 ni el cableado. Lo que se mide sigue siendo el **coste del transporte PS↔PL**, que es el objeto de la comparativa: latencia, throughput, interrupciones por kilobyte, comportamiento en *overrun* y recuperación ante frames corruptos.

Lo que **no** se mide es la integridad física del bus: reflexiones, terminación, tiempos de vuelta de `DE`, ruido. Para eso hace falta la PCB. En particular, el barrido de velocidad (T6) hasta 4 Mbps da aquí bastante mejor de lo que dará en cobre.
