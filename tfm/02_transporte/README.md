# 02 — Transporte PS↔PL: las tres variantes

Aquí está el objeto de estudio del TFM. Los 14 UART de la PL son siempre los mismos (`01_ip_serie`); lo que cambia es **el camino por el que los bytes viajan entre la DDR del PS y esos UART**, y el driver `transceiver.c/h` que lo gobierna.

Cada subcarpeta es autocontenida:

```
<variante>/
├── hardware/
│   ├── src/       RTL propio de la variante (lo común está en 01_ip_serie)
│   ├── scripts/   TCL que reconstruyen el proyecto y el block design desde cero
│   └── sim/       testbenches del transporte
└── software/      driver transceiver.c/h + app RTEMS (wscript, init.c, mmu_pl_map.c)
```

## a_gpio — AXI-GPIO / AXI-Lite

El PS lee y escribe **un registro por canal**. Cada byte recibido genera una interrupción. Es la implementación de partida y la referencia contra la que se mide todo lo demás.

- **Coste**: 1 IRQ por byte en recepción → ~1250 IRQ/KB. El PS no da abasto y el throughput se queda en un tercio del techo de línea.
- **Ventaja**: simplicidad, pocos recursos de PL, sin coherencia de caché de la que preocuparse.

## b_dma14 — 14× AXI-DMA (PG021)

Un `axi_dma` **por canal**, sin *scatter-gather*. Cada UART se convierte en AXI-Stream con `UART_AXIS_TOP` y cuelga de su propio DMA.

- TX: se escribe dirección y longitud, el DMA transfiere, la ISR MM2S libera un semáforo.
- RX: el DMA se arma con `LENGTH=1`; el `TLAST` de cada byte completa el paquete, la ISR S2MM copia al *ring* de software y rearma.
- **Coste**: 14 DMA ocupan mucha PL y 28 líneas de interrupción; el PS solo tiene 8 IRQ `pl_ps_irq0`. Este límite es lo que empuja a la variante C.

## c_mcdma_bridge — AXI-MCDMA (PG288) + puente VHDL

**La solución final.** Un único MCDMA multicanal, con un puente en VHDL que reparte y recoge de los 14 UART. La topología es asimétrica:

- **TX**: 1 canal MM2S → conversor de ancho 32→8 → `BRIDGE_TX_TOP` → 14 UART. El canal destino va **en la cabecera del frame**: `[{CH_ID[3:0], LEN[11:8]}, {LEN[7:0]}, payload…]`, así que un solo canal DMA sirve a los 14 UART.
- **RX**: 14 UART → `BRIDGE_RX_TOP` (una FIFO por canal + DEMUX + DRAIN) → conversor 8→32 → 14 canales S2MM, uno por UART.

Mapa de memoria y de interrupciones (en la cabecera de `software/transceiver.h`):

| Dirección | Bloque |
|---|---|
| `0xA000_0000` | `AXI_UART_CONFIG` — 4 KB, un registro de 32 b por canal |
| `0xA000_1000` | `TX_ISR_EOF_HANDLER` |
| `0xA001_0000` | Registros de control del MCDMA (64 KB) |

`pl_ps_irq0[0]` = `mm2s_introut` → SPI 89 → RTEMS 121; `pl_ps_irq0[1]` = `s2mm_introut` → SPI 90 → RTEMS 122.

- **Resultado**: 3 IRQ/KB y 99 % del techo de línea (ver [03_bench_loopback](../03_bench_loopback/README.md)).
- **Trampas encontradas** (documentadas en los memos de depuración):
  - El S2MM en modo *store-and-forward* se bloquea con paquetes de más de 512 B; el bloque DRAIN los trocea a 256 B.
  - Si se cambia el RTL de `BRIDGE_AND_SERIALs` hay que ejecutar `update_module_reference` en Vivado, o el bitstream se genera con la versión antigua sin avisar.

`entrega_sd_pcb/` contiene el `BOOT.bin` + `rtems.img` de esta variante para la PCB real (no el loopback), con su `LEEME.md`.
