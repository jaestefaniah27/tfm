# Resultados de la caracterización de la PCB

ZCU102 + PCB de 14 transceptores RS-485/RS-422, bitstream MCDMA **sin loopback**
(`BOOT.bin` md5 `150f7f33`). Todo lo medido aquí sale por los pines, atraviesa
los drivers y el cobre, y vuelve.

Tanda de referencia: `resultados/consola.txt` (con CH6 ya conectado).
CSV: `resultados/caracterizacion.csv`.

## Resumen

| Test | Resultado |
|---|---|
| T1 Reposo | **0 bytes espurios** en los 14 canales: la polarización de fail-safe funciona. |
| T2 Topología real | Los tres buses están puenteados como esperaban los jumpers y **no hay ni un cruce entre buses**. |
| T3 Multidrop | **6/6 esclavos** del bus A oyen íntegro al maestro, hasta 460 kbps. |
| T4 Velocidad máxima | Bus A: **460 kbps**. Buses B y C: **1 Mbps**. Por encima, la tasa de error se dispara. |
| T5 SLO | Con el bit SLO a 1, los tres buses llegan **limpios a 4 Mbps**. El nombre de la macro está invertido: ver abajo. |
| T6 Vuelta del bus | Guard time mínimo **0 µs**: el DE automático del core suelta la línea a tiempo, no hace falta guarda en software. |
| T7 Diafonía | **0 bytes de fuga** del bus A a los buses B y C. |
| T8 Colisión | La trama sale corrupta (como debe) y el bus **se recupera**: el siguiente intercambio es limpio. |
| T9 Estabilidad | 10 s de tráfico continuo: bus A a 460 kbps → BER 147 ppm; buses B y C a 1 Mbps → **BER 0**. |

`fallos_tx_total = 0`: ni un envío se quedó sin transmitir, así que todas las
cifras corresponden a bytes que de verdad viajaron por el bus.

## El hallazgo principal: el bit SLO está invertido respecto al chip

El software llama `TRANSCEIVER_SLO_OFF` al 0 (valor por defecto) y
`TRANSCEIVER_SLO_ON` al 1. Medido, en dos tandas independientes:

| Bus | SLO = 0 (por defecto) | SLO = 1 |
|---|---|---|
| A (RS485, multidrop de 7 nodos) | 460 kbps | **4 Mbps** |
| B (RS422) | 1 Mbps | **4 Mbps** |
| C (RS422) | 1 Mbps | **4 Mbps** |

Un limitador de slew **no puede subir** la velocidad máxima: frena los flancos, y
eso solo puede costar velocidad. Que el bit a 1 dé más velocidad significa que el
1 es el modo **rápido** del transceptor. Es decir, lo que el software llama
"SLO OFF" es en realidad el driver *slew-limitado*, y por eso el bus A se queda en
460 kbps en la configuración por defecto.

El bit no entra en el core serie —`CONFIGURABLE_SERIAL.vhd` no tiene ninguna
entrada `slo`—, sino que sale directo al pin SLO del chip transceptor:
`AXI_UART_CONFIG` → `BRIDGE_UART_ADAPTER` → puerto `SLO[13:0]`. La polaridad la
fija el chip. Está verificado el **efecto**, no la hoja de características: para
cerrarlo del todo hay que mirar el datasheet del transceptor.

Consecuencia práctica: **la PCB da 4 Mbps en los tres buses**, cuatro veces más de
lo que se venía usando, sin más que poner ese bit a 1. Conviene corregir el nombre
de la macro en `transceiver.h`, que induce a error.

## Qué cambió al conectar CH6

CH6 estaba desconectado en la PCB y la primera tanda lo detectó como canal mudo y
sordo (el único aislado de la matriz 14×14). Ya conectado:

- El multidrop del bus A pasa de 5/6 a **6/6 esclavos íntegros**.
- Los enlaces medidos suben de 40 a 52 de los 60 esperados.
- El BER sostenido del bus A a 460 kbps baja de 5167 a **147 ppm**.

Los 8 enlaces que siguen sin aparecer **no son un fallo**: son los esclavos de los
buses B y C, que no se oyen entre sí porque esos buses son RS-422 punto a punto en
estrella desde el maestro, no multidrop. La topología medida coincide con la
física de la placa.

## Salvedades del método

- **Los conteos parciales de T2 no son una medida de calidad de enlace.** En la
  matriz aparecen enlaces con 25 de 32 bytes correctos, pero T3 y T4 a esa misma
  velocidad dan 6/6 esclavos íntegros y BER 0 sobre 1024 bytes. Es un artefacto de
  T2, que espera un tiempo fijo y lee una sola vez: si un byte llega tarde se
  pierde y descuadra la comparación. T2 vale para el **mapa de conectividad**, que
  es para lo que está; no para cuantificar.
- **`errores_hw` de T9 no es fiable**: marca millones de errores en tandas cuyo BER
  medido es 0. Ese contador del driver (`g_bench_err`) está contando algo que no
  son errores de trama. No se ha usado para ninguna conclusión.
- **La primera tanda fue inválida**, y se conserva como
  `resultados/consola_run1_metodo_roto.txt` a modo de registro. El test no miraba
  el valor de retorno de `Transceiver_Send`: cuando la DMA no confirmaba la
  transmisión (los bytes ni salían), lo apuntaba como si el bus hubiera corrompido
  el 100 % de los bytes, y encima seguía subiendo de velocidad con el canal ya
  colgado, arrastrando el fallo al resto de la tanda. Los buses B y C aparecían
  rotos y era mentira. Ahora los fallos de transporte se cuentan aparte
  (`fallos_tx`), el barrido se corta en cuanto no llega nada, y los canales se
  reinicializan entre buses.
- Que el bus A tope antes que B y C (460 kbps frente a 1 Mbps con el mismo ajuste
  de SLO) es coherente con su naturaleza: siete nodos en multidrop cargan más el
  bus y reflejan más que un enlace punto a punto. Esta diferencia es independiente
  del hallazgo del SLO, y se mantiene también con SLO a 1 en la parte alta del
  barrido.
