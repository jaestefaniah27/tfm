# 04 — Caracterización eléctrica de la PCB

El [banco de la sección 03](../03_bench_loopback/) mide el **transporte** PS↔PL, y
por eso puede correr con un loopback dentro de la FPGA. Esta sección mide **la
PCB**: los drivers RS-485/RS-422, el cobre, la terminación, la polarización y los
jumpers. Todo lo que se mide aquí sale por los pines y vuelve.

Corre sobre el transporte MCDMA, que es la solución final del TFM.

Los resultados medidos, con su interpretación, están en [RESULTADOS.md](RESULTADOS.md).
El titular: **la placa venía con el limitador de slew activado sin saberlo.** El pin
`SLO` del LTC2865 es un habilitador de modo lento *activo a nivel bajo* (0 = capado a
250 kbps; 1 = 20 Mbps), y el valor por defecto era 0. Poniéndolo a 1 los tres buses
pasan de 460 kbps–1 Mbps a 4 Mbps limpios. El hardware no está invertido: lo que
induce a error es el nombre de la macro en `transceiver.h`.

```
04_pcb_caracterizacion/
├── software/       la app RTEMS (pcb_main.c) + driver MCDMA + utilidades de flasheo
├── hardware/       reimplementación del bitstream sin loopback y empaquetado del BOOT.bin
├── imagen_sd/      BOOT.bin + rtems.img listos para la SD
├── resultados/     consolas capturadas y CSV
└── RESULTADOS.md   qué salió y qué significa
```

---

## El requisito que no se puede saltar

Hace falta el bitstream **sin loopback**. El `BOOT.bin` del benchmark
(`03_bench_loopback/imagenes_sd/03_MCDMA/`) desconecta los pines de recepción de
los transceptores y los alimenta desde un módulo interno de la PL: con él la PCB
es invisible, y los 14 canales saldrían mudos.

Además, el bitstream limpio que había implementado era anterior al fix del DRAIN
(`MAX_PKT=256`, que evita que el buffer *store-and-forward* del S2MM se bloquee),
así que hubo que reimplementar:

```bash
vivado -mode batch -source hardware/rebuild_mcdma_pcb.tcl   # ~40 min
hardware/make_boot_pcb.sh                                   # → imagen_sd/
```

`make_boot_pcb.sh` **aborta si el bitstream es más viejo que el RTL**, que es
exactamente la trampa en la que ya se cayó una vez: Vivado cachea el `.dcp` del
module reference `BRIDGE_AND_SERIALs` y, sin `update_module_reference`, los
cambios de RTL se pierden en silencio.

En `imagen_sd/` está el resultado ya construido, así que para repetir las medidas
basta con copiarlo a la SD.

## Ejecutar

```bash
# desde software/, con la placa arrancada:
./capture.py --out consola.txt --timeout 800     # resetea por JTAG y captura
```

Si solo cambia la app (no el bitstream), `flash_rtems.py` la sube por YMODEM sobre
U-Boot sin sacar la SD de la placa.

---

## Topología de la PCB

```
Bus A (RS485 multidrop):  maestro CH0   | esclavos CH1..CH6      ← 7 nodos en un bus compartido
Bus B (RS422 punto a punto): maestro CH7   | esclavos CH8..CH10  ← estrella desde el maestro
Bus C (RS422 punto a punto): maestro CH11  | esclavos CH12..CH13
```

Los drivers 7 y 11 no tienen pin DE: está fijado en la PCB. La diferencia entre A
y B/C importa para leer los resultados: en el bus A los seis esclavos se oyen
entre sí, mientras que en B y C los esclavos solo oyen al maestro.

**Ningún test da esta topología por supuesta**: T2 la mide y el resto se apoya en
lo medido.

---

## Los nueve tests, uno a uno

### T1 — Reposo: ¿la línea está polarizada o flota?

Con los 14 drivers callados, se escucha 300 ms en todos los canales y se cuenta
cuántos bytes aparecen.

Un bus RS-485 en reposo debe estar en un estado definido, que le dan las
resistencias de polarización (*fail-safe biasing*) y la terminación. Si la línea
flota, el receptor amplifica el ruido y lo interpreta como bytes: eso es lo que
cuenta este test. Es la comprobación más barata de que la red de polarización de
la placa existe y hace su trabajo.

**Qué esperar:** 0 bytes. Cualquier byte espurio es ruido entrando como dato.

### T2 — Matriz de conectividad 14×14: el cableado real

Cada canal emite por turno un patrón de 32 bytes que lo identifica (el byte
depende del emisor **y** de su posición, así que un byte recibido dice de quién
viene y si está en su sitio), y se escucha en los otros trece.

El resultado es una matriz de quién oye a quién: los buses tal como están
puenteados de verdad, los canales mudos (driver o pista de TX rota), los sordos
(receptor o pista de RX) y los cruces entre buses. Se imprime en texto:

```
      dst→   0   1   2   3 ...
  src  0:    ·   #   #   #        # = las 32 B íntegras
  src  1:    #   ·   #   #        n = n bytes correctos (enlace degradado)
  ...                             . = no oye  ·  · = él mismo
```

Un canal **no se oye a sí mismo**: el DE inhibe su propio receptor mientras
transmite. Eso no es un fallo, es cómo funciona el half-duplex.

Este test fue el que detectó que CH6 estaba desconectado en la placa.

> **Ojo con los conteos parciales.** T2 espera un tiempo fijo y lee una sola vez,
> así que un byte que llegue tarde se pierde y descuadra la comparación. Sirve
> para el **mapa** de conectividad, que es su cometido; para cuantificar la calidad
> de un enlace están T4 y T9.

### T3 — Integridad del multidrop

El maestro del bus A emite una vez y se comprueba cuántos de los seis esclavos
oyeron la trama **íntegra**, repitiéndolo a cada velocidad del barrido.

En un bus compartido, cuando habla el maestro **todos** deben oírle. Si solo le
oyen algunos, el bus no está realmente compartido (jumper suelto) o hay un stub
mal terminado que refleja.

### T4 — Velocidad máxima de cada bus

Por cada bus y cada velocidad (9600 → 4 Mbps), el maestro manda 16 tramas de 64
bytes al primer esclavo, y se cuentan los bytes correctos. La métrica es el
**BER en partes por millón**; la velocidad más alta con BER 0 es la que la PCB
soporta de verdad.

Por encima de ese punto ya no manda el firmware sino la física: la carga
capacitiva del bus, la terminación y la velocidad de flanco del driver.

Dos decisiones de método que importan:

- Si la DMA **no confirma la transmisión** (los bytes no llegaron a salir), el
  punto se marca como `fallos_tx` y **no se calcula BER**. Confundir "el
  transporte no transmitió" con "el bus corrompió los bytes" fue el fallo que
  invalidó la primera tanda entera.
- El barrido **se corta** en cuanto una velocidad no deja pasar un solo byte
  correcto: seguir subiendo con el canal ya colgado arrastraba el fallo al resto
  de la tanda.

### T5 — El limitador de slew (pin SLO)

El mismo barrido de T4, pero con el bit SLO puesto a 1, y se comparan las
velocidades máximas limpias.

El SLO no entra en el core serie: `CONFIGURABLE_SERIAL.vhd` no tiene ninguna
entrada `slo`. El bit va del registro `AXI_UART_CONFIG` al pin SLO del **chip
transceptor**, así que lo que este test caracteriza es el componente, no el RTL.

Es el test que destapó que el valor por defecto (`SLO = 0`) deja el limitador
**activado**: el datasheet del LTC2865 define el pin como *Slow Mode Enable* activo a
nivel bajo (0 = slew-limitado, 250 kbps máx.; 1 = 20 Mbps). Con el bit a 1 los tres
buses llegan limpios a 4 Mbps; con el bit a 0 el bus A se queda en 460 kbps. El chip
cumple su especificación; el que engaña es el nombre de la macro en `transceiver.h`.

### T6 — Vuelta del bus: el guard time del DE

En half-duplex el esclavo no puede contestar hasta que el maestro haya soltado la
línea. Si contesta antes, los dos drivers conducen a la vez y la respuesta sale
corrupta.

El esclavo espera *g* µs desde que recibe la consulta antes de responder, con *g*
recorriendo 0, 10, 25, 50, 100, 250, 500 y 1000 µs, y se busca el **menor *g* con
el que las 8 respuestas llegan íntegras**. Ese número caracteriza el tiempo de
deshabilitación del driver más el vuelo de la línea, y es el que hay que meter en
cualquier protocolo half-duplex que se monte encima.

### T7 — Diafonía entre buses

Se satura el bus A con una ráfaga a su velocidad máxima y se escucha en los
canales de los buses B y C. Cualquier byte que aparezca ahí es acoplamiento entre
pistas o un cruce de cableado.

### T8 — Colisión y recuperación

Dos esclavos del bus A emiten a la vez. Lo importante no es que la trama se
corrompa —eso es física: los drivers hacen un AND cableado—, sino que el bus
**se recupere**: el intercambio siguiente tiene que volver a ser limpio. Si no,
algún driver se ha quedado enganchado conduciendo.

La colisión hay que provocarla desde **dos tareas con barrera de semáforo**:
`Transceiver_Send` es bloqueante en MCDMA (vuelve cuando la UART ha sacado el
último bit), así que dos envíos en serie no se solaparían jamás en el cobre.

### T9 — Estabilidad sostenida

Diez segundos de tráfico continuo por bus, a la velocidad máxima limpia que cada
uno dio en T4. Es la tasa de error en régimen permanente —lo que se va a ver en
operación— y saca a la luz lo que solo aparece con el bus cargado.

> El contador `errores_hw` que se emite en este test **no es fiable**: marca
> millones de errores en tandas cuyo BER medido es 0. Está contando algo que no son
> errores de trama, y no se ha usado para ninguna conclusión.

---

## Salida

CSV por consola, prefijo `PCB,`:

```
PCB,<test>,<métrica>,<unidad>,<valor>,<nota>
```

```bash
grep '^PCB,' consola.txt > caracterizacion.csv
```

Cierra con `PCB,resumen,fallos_tx_total,...`: si ese contador no es 0, parte de lo
medido no llegó a salir al bus y las cifras de esos puntos no valen.

## Límite que impone el hardware

Los paquetes de recepción no pueden pasar de 256 B: el bloque
`BRIDGE_RX_FIFO_DRAIN` los trocea a ese tamaño para no bloquear el buffer
*store-and-forward* del S2MM del MCDMA (con más de 512 B el canal se quedaba
mudo). Todas las tramas de este test se quedan holgadamente por debajo: 32 y 64
bytes.
