# Diseño: Bridge RTL "1 DMA + 14 UART" con buffering por canal y TX por paquetes

> Documento de arquitectura. Pensado como **guía de implementación por fases**
> para hacerlo a mano y entender cada pieza. No se implementa todavía.

## 1. Contexto y motivación

### 1.0 Evolución de la arquitectura (de dónde venimos)

Entender la mejora exige ver el punto de partida y por qué cada salto:

- **v0 — AXI-GPIO (PIO, byte a byte).** Diseño original: cada canal era un **AXI
  GPIO**; la CPU leía/escribía **cada byte** a través de registros (status +
  dato) con handshake, más un **AXI INTC** global para las IRQ. La CPU está
  metida en *cada* byte (Programmed I/O). A 14×115200 ≈ **200 KB/s agregado** la
  CPU se satura solo moviendo bytes y haciendo polling/IRQ por byte → **no
  escala** a 14 canales con margen para lógica de aplicación. Área pequeña (los
  GPIO son baratos) pero **coste de CPU máximo**. (El bit-packing de config
  actual `PS_SERIAL_CONFIG[27:12]` es herencia de aquí — del CH1 del GPIO.)

- **v1 — 14× AXI DMA (PCB actual).** El **DMA mueve los bytes sin CPU por byte**:
  en TX un mensaje = una transferencia; en RX la CPU ya no hace PIO. Gran salto
  en CPU. **Pero** el área se dispara: **14 DMA** + **árbol de SmartConnects**
  (config de 29 esclavos) + coalescencia de **28 IRQ**; y el RX sigue con **1 IRQ
  por byte** (la DMA completa por byte con TLAST por byte).

- **v1b — AXI MCDMA (intentado, descartado).** 1 MCDMA con 14 canales por
  *descriptores* (scatter-gather) + `axis_switch` + `dwidth_converter`. Reducía
  área (1 DMA) pero los descriptor rings + TDEST + switch eran **demasiado
  complejos** y nunca llegó a funcionar de forma fiable. Se abandonó.

- **v2 — Bridge RTL (esta propuesta).** **1 DMA + buffering en PL.** Combina lo
  mejor de las dos ramas: **CPU baja** (DMA + TX por paquete + RX por lotes) **y
  área baja** (1 DMA, sin árbol de SmartConnects, sin scatter-gather). El bridge
  es lógica RTL simple (FSMs + FIFOs), no IP pesado.

> Resumen del arco: GPIO optimiza área a costa de CPU; 14-DMA optimiza CPU a
> costa de área; el **bridge optimiza ambas** moviendo la complejidad a un poco
> de RTL a medida.

### 1.1 El diseño actual y sus límites

El diseño actual de la PCB (`lince_comunicacion_serial_dma_pcb`) usa **14 AXI DMA
simples** (uno por canal) + un **árbol de SmartConnects** (config de 29 esclavos)
+ coalescencia de 28 IRQs. Funciona, pero:

- **Área**: 14 DMAs + el SmartConnect de 14 esclavos por HP es lo más caro del
  diseño. Cada AXI DMA son varios miles de LUT/FF.
- **CPU/IRQ**: el RX es byte a byte (una IRQ por byte recibido) y en TX cada DMA
  queda "ocupado" durante toda la transmisión física (el UART va a 115200 baud,
  ~87 µs/byte) porque se llena paced por `EOT`.

**Idea**: poner **una sola DMA** y un **bridge RTL** entre la DMA y los 14 cores
UART. El bridge:
- desacopla el *llenado* (rápido, vía DMA) del *vaciado* (lento, el UART) con un
  **FIFO TX por canal** → la DMA se libera en cuanto el paquete está en el FIFO,
  así **una sola DMA da servicio a los 14 canales**;
- enruta por **cabecera** (`[idx][len]`) qué canal transmite;
- avisa por **IRQ** cuando un canal termina de transmitir su paquete (espacio
  libre en el FIFO);
- en RX **etiqueta cada byte con su canal** y los entrega a la DMA **en lotes**
  (flush por inactividad) para no tener una IRQ por byte.

**Resultado esperado**: −13 DMAs y el árbol de SmartConnects (gran ahorro de
área), TX gestionado por paquete (no byte) y RX por lotes (pocas IRQ).

**Reutilización clave (bajo riesgo)**: el core UART `CONFIGURABLE_SERIAL_TOP` ya
está **verificado** (los 4 fixes de esta sesión: data_count/ERROR_OK, rd_en del
FIFO RX, register slice RX, y `tx_pending` en TX). El bridge **lo instancia 14×**
tal cual. Lo único nuevo es la lógica de multiplexado/buffering alrededor — que
sustituye al wrapper `UART_AXIS_TOP`.

---

## 2. Decisiones tomadas

| Decisión | Elección |
|---|---|
| RX hacia la DMA | **Por lotes**: el bridge acumula pares `[idx][byte]` y asierta `TLAST` tras inactividad (o al llenar) → la DMA completa un lote. Sin scatter-gather. |
| Profundidad FIFO TX/canal | **Genérico VHDL**, default **512 B** (~1 BRAM18/canal). Tamaño máx de paquete acordado = profundidad; permite encolar varios. |
| Ubicación | **Carpeta nueva clonada** (p.ej. `lince_comunicacion_serial_dma_bridge`). El diseño 14-DMA actual queda como fallback probado. |

---

## 3. Arquitectura global

```
            PS (RTEMS)
              │  GP0 (AXI-Lite: config + estado + IRQ)
              │  HP0 (DMA MM2S lee paquetes TX de DDR)
              │  HP1 (DMA S2MM escribe lotes RX a DDR)
   ┌──────────┴───────────┐
   │     1× AXI DMA        │   (c_include_sg=0, stream 8-bit)
   │  MM2S ─►   ◄─ S2MM    │
   └───┬───────────┬───────┘
  S_AXIS_TX │   │ M_AXIS_RX        (AXI-Stream 8-bit)
   ┌────────▼───┴────────────────────────────────────────┐
   │              SERIAL_DMA_BRIDGE (RTL nuevo)           │
   │                                                      │
   │  TX: parser cabecera [idx][len] → FIFO_TX[idx]       │
   │       (9 bits: dato + bit "fin de paquete")          │
   │       motor TX/canal vacía el FIFO al core UART;     │
   │       al transmitir el byte con eop=1 → tx_done[idx] │
   │                                                      │
   │  RX: árbitro round-robin lee los RX-FIFO de los      │
   │      cores → empuja pares [idx][byte] al stream;     │
   │      flush (TLAST) por inactividad o batch lleno     │
   │                                                      │
   │  AXI-Lite: 14× CFG, TXDONE_STATUS, TX_FREE, CTRL...  │
   │  IRQs: irq_mm2s(DMA), irq_s2mm(DMA), irq_tx_done(PL) │
   │                                                      │
   │     14×  CONFIGURABLE_SERIAL_TOP  (core verificado)  │
   └───┬───┬───┬─────────────────────────────────┬───────┘
      TD0 RD0 DE0/SLO0  ...                    TD13 RD13 ...
              (pines físicos RS485/RS422 de la PCB)
```

Tres líneas de IRQ → `pl_ps_irq0[2:0]`:
- `irq_mm2s` (DMA MM2S done): un trozo llegó al FIFO; la DMA queda libre.
- `irq_s2mm` (DMA S2MM done): hay un **lote** RX listo en DDR para procesar.
- `irq_tx_done` (PL): uno o más canales terminaron de transmitir un paquete
  (espacio libre en su FIFO).

---

## 4. Protocolo sobre el AXI-Stream

**TX (PS → bridge), `S_AXIS_TX`:** flujo de bytes con cabecera por paquete
```
[ idx ][ len ][ d0 ][ d1 ] ... [ d(len-1) ]
  1B    1B      ── len bytes de payload ──
```
- `idx`  = canal destino (0..13).
- `len`  = nº de bytes de payload (1..255; ≤ profundidad FIFO).
- El bridge escribe los `len` bytes en `FIFO_TX[idx]`, poniendo el bit
  **eop=1** en el último (d(len-1)). El resto de bytes eop=0.
- `TLAST` del stream NO es necesario para delimitar (usamos `len`), pero el
  driver puede ponerlo en el último byte por higiene.

**RX (bridge → PS), `M_AXIS_RX`:** lote de pares etiquetados
```
[ idx ][ byte ][ idx ][ byte ] ... TLAST en el último byte del lote
```
- Cada byte recibido por cualquier canal se emite como par `idx,byte`.
- El `TLAST` (flush) se asierta **solo en frontera de par** (tras un `byte`,
  nunca entre `idx` y `byte`), para que el lote contenga pares completos.
- Flush cuando: (a) `idle_count > RX_IDLE_TIMEOUT` con ≥1 par pendiente, o
  (b) el lote alcanza `RX_BATCH_MAX` (= tamaño del buffer S2MM).

> Nota: el `len` no se repite en RX (siempre sería 1). Si prefieres simetría
> estricta `[idx][1][byte]`, es un cambio menor; aquí se opta por `[idx][byte]`
> por eficiencia (33% menos tráfico RX).

---

## 5. El bridge RTL — `SERIAL_DMA_BRIDGE.vhd`

### 5.1 Genéricos
- `N_CH       : integer := 14`   — nº de canales.
- `TX_DEPTH   : integer := 512`  — profundidad FIFO TX por canal (bytes).
- `RX_IDLE_TO : integer := 8680` — ciclos de inactividad para flush RX
  (≈ 1 char-time @115200/100 MHz ≈ 8680; ajustar).
- (los canales sin pin DE — 7 y 11 — se manejan en el BD/XDC igual que ahora).

### 5.2 Interfaces
- `aclk`, `aresetn`.
- `S_AXIS_TX`  (axis 8b slave)  — paquetes TX desde la DMA.
- `M_AXIS_RX`  (axis 8b master) — lotes RX hacia la DMA.
- `S_AXI`      (AXI-Lite slave) — registros (ver 5.5).
- `irq_tx_done` (out, 1b).
- 14× `TD,RD,DE,SLO`.

### 5.3 Datapath TX
- **Parser de cabecera** (FSM sobre `S_AXIS_TX`): estados `IDX → LEN → PAYLOAD`.
  - En `PAYLOAD` cuenta `len` bytes; en cada uno hace `wr_en` en `FIFO_TX[idx]`
    con `din = (eop & data)` donde eop = (contador == len-1).
  - `tready` del stream = `not FIFO_TX[idx].full` (backpressure real; aunque el
    driver garantiza que cabe, esto evita corrupción).
- **FIFO_TX[idx]**: 9 bits de ancho (`eop & data`), `TX_DEPTH` de profundidad,
  FWFT (igual configuración que el FIFO RX del core, reutilizable). Expone
  `data_count` (ocupación) → registro `TX_FREE[idx] = TX_DEPTH − data_count`.
- **Motor TX por canal** (FSM pequeña ×14, o una compartida multiplexada):
  - Si `FIFO_TX[idx]` no vacío y core[idx] `TX_RDY=1` (EOT): leer byte del FIFO,
    presentar `DataIn=data`, pulsar `TX_Send`. El core ya hace el handshake
    correcto (`tx_pending`, verificado).
  - Cuando el core **termina** ese byte (flanco de `EOT` a 1 tras transmitir):
    si el byte tenía `eop=1` → `tx_done_set[idx]=1` (latch en TXDONE_STATUS) y
    pulso a `irq_tx_done`.
  - (El "byte transmitido" se detecta por el retorno de EOT a Idle, igual que el
    `tx_pending` del wrapper actual.)

### 5.4 Datapath RX
- **Árbitro round-robin**: recorre los 14 cores; para el primero con `EMPTY=0`
  (RX FIFO con dato) hace `Data_read` (1 pulso) y captura el byte (`PS_out[7:0]`).
- **Empaquetador**: emite por `M_AXIS_RX` primero `idx` y luego `byte` (2 beats).
- **Flush por inactividad**: contador `idle_cnt` que se resetea con cada par
  emitido; si supera `RX_IDLE_TO` y hay ≥1 par desde el último TLAST → marca
  `TLAST` en el siguiente cierre de par. También cierra si el lote llega a
  `RX_BATCH_MAX`.
- (Opcional v2) un FIFO RX intermedio para absorber ráfagas si la DMA va lenta.

### 5.5 Registros AXI-Lite (mapa propuesto)
| Offset | Reg | Acceso | Descripción |
|---|---|---|---|
| `0x000`..`0x034` | `CFG[0..13]` | RW | Config UART por canal (mismo packing que `PS_SERIAL_CONFIG[27:12]`: baud/stop/parity/databits/order/SLO). |
| `0x040` | `CTRL` | RW | bit0 enable global, bit1 soft-reset. |
| `0x044` | `RX_IDLE_TO` | RW | ciclos de inactividad para flush RX. |
| `0x048` | `TXDONE_STATUS` | R/W1C | 14 bits; bit i = canal i terminó un paquete. Fuente de `irq_tx_done`. |
| `0x04C` | `IRQ_EN` | RW | habilita `irq_tx_done`. |
| `0x080`..`0x0B4` | `TX_FREE[0..13]` | R | espacio libre (bytes) en FIFO TX por canal. |
| `0x0C0`..`0x0F4` | `RX_OVF[0..13]` | R/W1C | (opcional) flags de overflow RX por canal. |

> El SysInfo (count/base/stride) puede integrarse aquí o seguir como bloque GPIO
> aparte; el driver lo descubre igual.

---

## 6. El driver RTEMS — capas de TX

API pública **sin cambios** (`transceiver.h`): `Transceiver_Init`,
`Transceiver_Send/SendString`, `Transceiver_Read`, `Transceiver_SetRxCallback`,
`Transceiver_Global_INIT`. Cambian las **tripas**.

### 6.1 Estructuras por canal
```c
typedef struct {
  uint8_t  tx_ring[TX_RING_SZ];   // bytes pendientes de mandar a la PL (cola SW)
  size_t   tx_head, tx_tail, tx_count;
  uint16_t pl_occupancy;          // bytes "en vuelo" dentro del FIFO TX de la PL
  // cola de tamaños de trozos en vuelo (para descontar al llegar tx_done):
  uint16_t inflight[INFLIGHT_MAX]; uint8_t if_head, if_tail, if_count;
  // ... RX ring SW (igual que ahora) ...
} ChanState;
```

### 6.2 Flujo TX (capas)
1. `Transceiver_Send(ch, data, len)`: copia `data` al `tx_ring[ch]` (cola SW) y
   despierta al **planificador TX**. Retorna enseguida (no bloqueante).
2. **Planificador TX** (tarea o disparado por IRQ): la DMA es **un recurso
   único**, así que serializa. Round-robin entre canales con
   `tx_count>0 && TX_FREE[ch]>0`:
   - `chunk = min(tx_count[ch], TX_FREE[ch], MAX_CHUNK=TX_DEPTH)`.
   - Construye `[ch][chunk][bytes...]` en el buffer DMA, flush cache.
   - Programa MM2S (SA, LENGTH=2+chunk). 
   - `pl_occupancy[ch]+=chunk`; `inflight[ch].push(chunk)`; saca `chunk` bytes
     del `tx_ring[ch]`.
   - Espera **`irq_mm2s`** (trozo en el FIFO, DMA libre) → atiende el siguiente
     canal pendiente.
3. **`irq_tx_done`** (PL): lee `TXDONE_STATUS` (14b, W1C). Para cada bit i:
   `pl_occupancy[i] -= inflight[i].pop()`. Si quedan bytes en `tx_ring[i]` y ahora
   hay hueco, re-despierta al planificador para mandar el siguiente trozo de i.

Resultado: **transmites por trozos del tamaño que quepa**, la CPU solo actúa en
eventos (IRQ), nunca byte a byte; un mensaje grande se trocea solo, y un 2º
mensaje se encola y sale cuando hay hueco — exactamente tu descripción.

### 6.3 Flujo RX (lotes)
- S2MM armado con `LENGTH = RX_BATCH_MAX` sobre un buffer DMA de lote.
- `irq_s2mm`: lee cuántos bytes llegaron (residual del LENGTH), invalida cache,
  recorre el lote en **pares** `[idx][byte]`, empuja cada `byte` al ring RX SW
  del canal `idx` y dispara su callback. Re-arma S2MM.
- Mucho menos IRQ que el byte-a-byte actual.

---

## 7. Cambios en el Block Design (Vivado)

Respecto a `simple_dma14_system.tcl`:
- **Quitar**: los 14 `axi_dma`, `smc_dma`, `smc_periph`/`smc_root` (árbol),
  `smc_hp0/hp1` de 14 SI, los `xlconcat`/`util_reduced_logic` de 28 IRQ.
- **Poner**: 1× `axi_dma` (simple), 1× `SERIAL_DMA_BRIDGE` (module ref del RTL
  nuevo). Conexiones:
  - `GP0 → SmartConnect(1→2) → {bridge.S_AXI, axi_dma.S_AXI_LITE}` (+SysInfo).
    (Solo 2-3 esclavos → un SmartConnect pequeño, adiós al árbol.)
  - `axi_dma.M_AXIS_MM2S → bridge.S_AXIS_TX`.
  - `bridge.M_AXIS_RX → axi_dma.S_AXIS_S2MM`.
  - `axi_dma.M_AXI_MM2S → HP0`, `axi_dma.M_AXI_S2MM → HP1` (1 SI cada uno).
  - IRQ → `xlconcat(3) → pl_ps_irq0`: `[0]=mm2s, [1]=s2mm, [2]=bridge.irq_tx_done`.
  - Pines físicos `TD/RD/DE/SLO` igual que ahora (7 y 11 sin DE).
- Mapa de memoria sugerido: bridge `0xA000_0000` (config+estado, p.ej. 64 KB),
  axi_dma `0xA001_0000`, SysInfo `0xA002_0000`.

---

## 8. Análisis área / CPU

- **Área**: se eliminan 13 AXI DMA (cada uno ~2-3k LUT + FF) y todo el árbol de
  SmartConnects de 14 SI (caro en LUT y el cuello de la síntesis de 14ch). Se
  añaden 14 FIFO_TX de 9×512 (≈ 1 BRAM18/canal = 14 BRAM) + el datapath del
  bridge (FSMs ligeras). **Balance neto: bastante menos LUT/FF, +14 BRAM.** El
  ZU9EG tiene 912 BRAM18 → holgado.
- **CPU**: TX en eventos por trozo (no byte); RX en lotes (1 IRQ por lote vs 1
  por byte). Menos contención de DMA (1 sola, pero cada operación es corta).
- **Knob `TX_DEPTH`** (genérico): mayor → menos "pendientes" en el driver (menos
  CPU) a cambio de más BRAM; menor → menos BRAM, más troceo. 512 B es un punto
  de partida razonable; medible.

---

## 9. Roadmap de implementación (por fases, para hacerlo a mano)

Cada fase es verificable de forma aislada (reutiliza el **flujo de simulación
xsim** ya montado: `hardware/sim/` + `scripts/run_sim.tcl`).

1. **F1 — Esqueleto del bridge, 1 canal, TX.** `SERIAL_DMA_BRIDGE` con `N_CH=1`:
   parser de cabecera + FIFO_TX + motor TX sobre 1 `CONFIGURABLE_SERIAL_TOP`.
   TB que inyecta `[0][len][payload]` por `S_AXIS_TX` y comprueba TD en loopback.
2. **F2 — `irq_tx_done` y TX_FREE.** Añadir eop/contador, IRQ y registro de hueco.
   TB: enviar 2 paquetes, ver que el 2º espera hueco y que `irq_tx_done` casa con
   el fin de transmisión.
3. **F3 — RX por lotes, 1 canal.** Árbitro + empaquetador `[idx][byte]` + flush
   por inactividad. TB en loopback (TD→RD): enviar paquete, ver el lote RX.
4. **F4 — Escalar a `N_CH=14`.** Generalizar con `generate`. TB multicanal.
5. **F5 — AXI-Lite y mapa de registros.** CFG por canal, CTRL, TXDONE, TX_FREE.
6. **F6 — Driver RTEMS.** Reescribir tripas de `transceiver.c` (planificador TX
   por trozos + ocupación + RX por lotes), API pública intacta.
7. **F7 — Block Design + bitstream + BOOT.bin + prueba en placa** (app
   maestro/esclavo reutilizable; el firmware UART ya está verificado).

> Recomendado empezar por F1-F3 en **simulación** (segundos por iteración) antes
> de tocar el BD; el sim reproduce el camino completo DMA-stream ↔ UART.

---

## 10. Puntos abiertos / riesgos

- **Detección de "byte transmitido"** en el motor TX: usar el flanco de `EOT`
  (igual semántica que el `tx_pending` ya verificado). Validar en F1.
- **Alineación de `TLAST` RX** a frontera de par (nunca entre idx y byte).
- **Residual del S2MM**: confirmar cómo el AXI DMA simple reporta los bytes de un
  lote acortado por TLAST (lectura del `S2MM_LENGTH`/SR tras completar).
- **Arbitraje RX justo**: round-robin para que ningún canal monopolice el stream
  en ráfagas (14×115200 ≈ 200 KB/s agregado, trivial para 100 MHz).
- **Tamaño de `tx_ring` SW y `INFLIGHT_MAX`**: dimensionar según nº de mensajes
  encolables por canal.
- **DE de 7 y 11**: sin pin (igual que el diseño actual), sin impacto en el bridge.

---

## 11. Banco de pruebas comparativo (eficiencia CPU y área FPGA)

Objetivo final: **cuantificar** la mejora midiendo las tres arquitecturas con la
**misma carga** y las mismas métricas. Cierra el círculo de la motivación (v0/v1/v2).

### 11.1 Arquitecturas a comparar
- **A — AXI-GPIO (PIO)**: baseline histórico (v0). Si no es reconstruible con
  facilidad, se mide conceptual/históricamente y se centra la comparación
  empírica en B vs C.
- **B — 14× AXI DMA** (PCB actual, v1) — ya construida.
- **C — Bridge** (v2) — la de este documento.

### 11.2 Métricas
1. **Área FPGA** — de `report_utilization` de cada `impl_1`:
   LUT, FF, BRAM18/36, DSP y % del dispositivo. (Vivado batch:
   `open_run impl_1; report_utilization -file util_<arch>.rpt`.)
2. **Eficiencia CPU** — bajo carga fija sostenida:
   - **%CPU del subsistema serie**: tarea *idle* de prioridad mínima que
     incrementa un contador; `%CPU = 1 − (cuentas_bajo_carga / cuentas_en_reposo)`.
   - **IRQ/seg** atendidas (contadores `g_dbg_mm2s/s2mm/tx_done`).
   - **ciclos de CPU por byte** TX y RX: leer el contador de ciclos del ARM
     (`CNTVCT_EL0` / PMU `CCNT`) alrededor del test y dividir por bytes movidos.
3. **Latencia** (opcional): tiempo desde `Send()` hasta primer byte en el cable,
   y desde byte en el cable hasta callback RX.

### 11.3 Carga de prueba común (idéntica en A/B/C)
- TX: transmitir un mensaje de **K bytes** en **cada uno de los 14 canales**,
  durante **R rondas** (p.ej. K=256, R=100).
- RX: recibir esos mensajes (en loopback interno para aislar de la PCB, o en bus
  físico para el caso real).
- Registrar: tiempo total, %CPU, IRQ totales, ciclos/byte TX y RX.

### 11.4 Cómo medirlo
- **Área**: un script TCL que abre cada `impl_1` y vuelca el utilization a `.rpt`;
  tabular. (Las tres comparten parte; el delta clave es DMA/SmartConnect vs
  bridge/FIFOs.)
- **CPU**: una **fase de benchmark** común en `main.c` (reutilizable entre
  builds): arranca el contador idle + PMU, lanza la carga, y al final imprime
  %CPU, IRQ totales y ciclos/byte. Misma carga y misma medición en las tres →
  comparable.

### 11.5 Tabla de resultados (a rellenar)

| Métrica                | A: GPIO | B: 14-DMA | C: Bridge |
|------------------------|---------|-----------|-----------|
| LUT                    |         |           |           |
| FF                     |         |           |           |
| BRAM18                 |         |           |           |
| DSP                    |         |           |           |
| %CPU @ carga           |         |           |           |
| IRQ/seg                |         |           |           |
| ciclos CPU/byte TX     |         |           |           |
| ciclos CPU/byte RX     |         |           |           |

Hipótesis esperada: **A** = área mínima / CPU máxima; **B** = CPU baja / área
máxima; **C** = CPU mínima y área media → mejor balance global.

---

## 12. Archivos (carpeta nueva `lince_comunicacion_serial_dma_bridge`)

- `hardware/src/SERIAL_DMA_BRIDGE.vhd` — **nuevo** (el bridge).
- `hardware/src/CONFIGURABLE_SERIAL*.vhd`, `NCO/ShiftRegister/...` — reutilizados
  tal cual (verificados).
- `hardware/src/UART_AXIS_TOP.vhd` — ya no se usa (lo sustituye el bridge).
- `hardware/scripts/bridge_system.tcl` — **nuevo** BD (sección 7).
- `hardware/sim/tb_bridge_*.vhd` + `run_sim.tcl` — TBs por fase.
- `transceiver.c/.h` — tripas nuevas (sección 6), API intacta.
- `main.c` — app de test reutilizable (maestro/esclavo o loopback).
