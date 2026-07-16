# Auditoría de la memoria del TFM — 14 de julio de 2026

Informe de revisión completa del documento LaTeX (`plantilla_tft_etsit/`, 87 páginas compiladas)
contrastado con el contenido real del repositorio (`tfm/`). Organizado en:

1. [Veredicto global](#1-veredicto-global)
2. [Errores y contradicciones a corregir](#2-errores-y-contradicciones-a-corregir) (ordenados por gravedad)
3. [Partes pendientes de redacción](#3-partes-pendientes-de-redacción)
4. [Huecos de figuras](#4-huecos-de-figuras-25)
5. [Discrepancias memoria ↔ repositorio](#5-discrepancias-memoria--repositorio)
6. [Guía de lectura con preguntas tipo tribunal](#6-guía-de-lectura-con-preguntas-tipo-tribunal)
7. [Plan de trabajo sugerido](#7-plan-de-trabajo-sugerido)

---

## 1. Veredicto global

**El documento está en mucho mejor estado del que temes.** La estructura es coherente
(teoría → desarrollo → resultados sigue el hilo GPIO → DMA14 → MCDMA sin saltos), la
verificación mecánica sale limpia (**0 referencias cruzadas rotas, 18/18 citas con entrada
en `biblio.bib`**), y todas las cifras clave del benchmark que he contrastado contra los
logs del repo **coinciden exactamente**:

| Cifra en la memoria | Fuente en el repo | ¿Coincide? |
|---|---|---|
| GPIO: 3.471 B/s, latencia 4.606 µs, 22.161 IRQ TX = 22.161 bytes TX | `tfm/03_bench_loopback/resultados/01_GPIO.txt` | ✅ |
| MCDMA: 11.461 B/s, 1.530 µs, 344.781 B/s a 4M, 101.472 bytes RX | `resultados/03_MCDMA.txt` | ✅ |
| PCB: 6/6 esclavos a 460k, BER 147 ppm, SLO → 4 Mbps | `tfm/04_pcb_caracterizacion/resultados/caracterizacion.csv` | ✅ |
| Utilización: 6.434 / 40.217 / 14.191 LUT | `tfm/00_docs/informe_benchmark.html` | ✅ |
| CAN 26/26 PASS, ADC barrido CH2 | `tfm/00_docs/logs_terminal/` | ✅ |

Los problemas reales son pocos y localizados: **una contradicción temporal grave en el
capítulo 1**, un párrafo del benchmark con cifras que no puedo rastrear en el repo, rutas
de repositorio citadas que ya no existen, y los anexos A/B + Summary sin hacer.

---

## 2. Errores y contradicciones a corregir

### 🔴 GRAVES (contradicen otra parte del documento)

**G1. ✅ CORREGIDO (15-jul-2026).** Se eliminó el párrafo de pendientes de la metodología, se
añadió una Fase 3 (junio–julio: estudio del transporte + caracterización de la PCB) y se quitó
la mención a septiembre de 2026. Texto original del hallazgo:

**La introducción decía que la PCB propia está sin fabricar; el capítulo 4 la caracteriza entera.**
- `cap1/intro.tex:112-114`: *"Quedan pendientes para la fase final, antes de la entrega del
  TFM en septiembre de 2026, la fabricación y validación de la PCB de diseño propio y el
  desarrollo de la aplicación de testing exhaustivo de los 14 transceptores en paralelo."*
- Pero `cap4/pcb.tex` presenta la PCB **fabricada, con 9 tests y campaña completa**, y
  `cap5/conclusiones.tex:42-45` la da por fabricada y caracterizada.
- **Arreglo:** borrar o reescribir ese párrafo final de la metodología. Aprovecha para decidir
  si quieres mencionar la fecha de entrega en el texto (yo lo quitaría: es una nota de plan,
  no de memoria).

**G2. ✅ CORREGIDO (15-jul-2026).** Ahora dice "las tres tarjetas de prueba: las dos oficiales
del proyecto (CDHS y AOCS) y la de comunicación serie de diseño propio, caracterizada
eléctricamente sobre sus catorce transceptores". Hallazgo original: `cap1/intro.tex` decía
"**dos** tarjetas de prueba" cuando son tres.

**G3. ✅ CORREGIDO (15-jul-2026).** Se reescribió el párrafo eliminando las cifras de la corrida
intermedia (24.576→33.736, 73.912→101.472): ahora el argumento "descartes altos = transporte sano"
se sostiene solo con la lógica (el GPIO desborda menos porque su cuello de botella frena la
entrega) y remite a la sección de depuración del cap. 3 para la historia del debug, aclarando que
las cifras de la tabla son de la campaña final (36/36). Hallazgo original:

**Párrafo de robustez del benchmark con cifras no trazables** (`cap4/benchmark.tex:403-416`):
- La **tabla** \ref{tab:bench_robustez} da para MCDMA "Bytes descartados = 24.576" (es el dato
  de T5, y está en el log ✅).
- El **texto** dice *"la cifra creció de 24.576 a 33.736"* y *"los bytes recibidos pasaron de
  73.912 a 101.472"*. El 33.736 existe en el log final (`efficiency,errors`) y el 101.472
  también, **pero los valores "antes" (24.576 como total de campaña y 73.912) no están en
  `resultados/run1_previo/`** — esa corrida previa tiene `bytes_rx = 0` (era la del 0/36).
  Parece que hubo una corrida intermedia que no está en el repo.
- Además el texto mezcla dos métricas distintas con el mismo nombre: los 24.576 de la tabla
  son *descartados en T5*, los 33.736 del texto son *descartados en la campaña completa*.
- **Arreglo:** o (a) recuperas y subes la corrida intermedia que respalda el 24.576→33.736 y
  el 73.912→101.472 y aclaras en el texto que hablas del total de campaña (no del T5 de la
  tabla), o (b) reescribes el párrafo usando solo cifras presentes en el repo. Tal como está,
  es el punto más fácil de atacar de todo el capítulo de resultados.

### 🟠 MEDIOS (imprecisiones que un tribunal puede pinchar)

**M1. ✅ CORREGIDO (15-jul-2026).** Las dos leyendas dicen ahora "latencia de entrega… del envío
en el maestro a la recepción completa en el esclavo". Hallazgo original:
**"Latencia de ida y vuelta" vs. definición de ida** (`cap4/benchmark.tex:176-218`).
El texto define la medida como *"desde justo antes de la llamada de envío hasta que el
receptor tiene el frame completo"* (un solo sentido), pero la tabla y las dos figuras la
llaman *"ida y vuelta"*. Unificar (por lo que describe el bench, es **ida**: maestro → esclavo
por el loopback).

**M2. ✅ CORREGIDO (15-jul-2026).** La subsección del NCO en cap3 cuenta ahora la narrativa
necesidad→diseño a medida→testbench→tabla del Anexo 1→conclusión (peor error 120 ppm, dos
órdenes por debajo de la tolerancia UART), y las conclusiones reflejan esa misma cifra en vez
del "<20 ppm para la mayoría". Hallazgo original:
**Precisión del NCO en conclusiones** (`cap5/conclusiones.tex:9-11`): *"error de baudrate
inferior a 20 ppm para la mayoría de las velocidades […] desde 9.600 hasta 4.000.000 baudios"*.
La tabla del Anexo 1 tiene puntos a −50, +100 y −120,3 ppm (1,5M / 3M / 3,6864M). "La mayoría"
te salva formalmente, pero es mejor cuantificar: *"<1 ppm en las velocidades estándar hasta
1 Mbaudio; el peor caso del rango completo es −120 ppm a 3,6864 Mbaudios, muy por debajo de la
tolerancia del ±2 % de un UART"*. Además: cap3 dice que el transceptor va **de 50 baudios** a 4M
y la tabla del anexo empieza en 9.600 y se anuncia como "extracto" de 54 frecuencias con solo
29 filas — decide si pones la tabla completa o cambias el título del extracto.

**M3. ✅ CORREGIDO (15-jul-2026).** El cap. 2 dice ahora "SPI 89–96 y 104–111, que corresponden a
los vectores 121–128 y 136–143 en la numeración de RTEMS". Hallazgo original:
**Nomenclatura SPI/vector inconsistente entre capítulos.**
- `cap2/transporte.tex:143-145`: pl_ps_irq0/1 *"mapeadas a interrupciones compartidas del GIC
  (SPI 121–128 y 136–143 en la numeración de RTEMS)"*.
- `cap3/transporte.tex:260-262`: *"mm2s_introut (SPI 89, vector 121 en RTEMS)"*.
- Lo correcto: los **SPI son 89–96 / 104–111** y los **IRQ ID / vectores RTEMS son 121–128 /
  136–143** (ID = SPI + 32). El cap3 lo hace bien; el cap2 llama "SPI" a los vectores.
  Unificar terminología en ambos.

**M4. ✅ CORREGIDO (15-jul-2026).** Añadido párrafo de selección en la subsección de la placa
propia (cap3): LTC2865 elegido por su pin VL (interfaz digital a 1,8 V nativa), 20 Mbps y pin
SLO; difiere del THVD1424 por cronología — la sugerencia del THVD1424 (compañero del proyecto
LINCE) llegó después de diseñada esta placa. El párrafo además planta el pin SLO antes del
hallazgo del cap4. Hallazgo original:
**El transceptor de la placa propia aparece "de la nada" como LTC2865.** En `cap3` la placa
de comunicación serial no declara qué transceptor monta (las CDHS/AOCS sí: THVD1424). El LTC2865
aparece por primera vez en `cap4/pcb.tex` con el hallazgo SLO. Pregunta segura de tribunal:
*"¿por qué la placa propia lleva LTC2865 y las oficiales THVD1424?"*. Añade en cap3 (sección de
la placa propia) la selección del LTC2865 y su motivo, y de paso el hilo queda plantado para el
hallazgo del cap4.

**M5. ✅ VERIFICADO (15-jul-2026) — la memoria es correcta.** El esquemático
(`LINCE_comunicacion_serial.pdf`, hoja 4, `RS485-Driver-422-Master-FD`) confirma que los
drivers 7 y 11 son los maestros RS-422 full-duplex con "TX always enabled (DE)": el DE va fijo
en hardware y por eso no aparece en el mapa de señales. La justificación del Anexo A1.1 es
defendible tal cual; respuesta de tribunal: "son los maestros de los buses B y C, transmisor
siempre habilitado porque en full-duplex punto a punto no hay que ceder el bus".

**M6. Objetivo 2 dice "sin recurrir a polling de CPU"** (`cap1/objetivos.tex:28`) y el driver
final es de interrupciones ✅, pero en la historia de la depuración (`cap3/transporte.tex:316-321`)
cuentas que hubo una fase de polling. Está bien contado, pero prepárate la respuesta: *el polling
fue un paso intermedio hasta regenerar el IP con `c_enable_multi_intr`*.

### 🟡 MENORES (estilo/coherencia)

- `cap3/ejemploDesarrollo.tex:833+`: la sección de la app de testing dice formato
  `[RX UART 02]` con buffer de 1024 B por canal; consistente con los logs ✅. Sin problema.
- `cap4/benchmark.tex` tabla software: "RAM del driver 114.688 B ≈ 112 KB" y el texto dice
  "112–120 KB" ✅ coherente.
- Nombres de ficheros de la plantilla sin renombrar: `cap2/ejemplo.tex`,
  `cap3/ejemploDesarrollo.tex`, `cap4/ejemploResultados.tex`. No afecta al PDF, pero renombrarlos
  (`marco.tex`, `desarrollo.tex`, `validacion.tex`) te evita confusiones a ti mismo.
- `main.log` sin warnings de referencias; solo 2 warnings de fuentes (ignorables).

---

## 3. Partes pendientes de redacción

| Qué | Dónde | Nota |
|---|---|---|
| **Summary en inglés** (máx. 500 palabras) | `pre/resumen.tex:52` | Obligatorio ETSIT |
| **Keywords en inglés** | `pre/resumen.tex:67` | Trivial: traducir la lista |
| **Anexo A** — impactos (A2, A3, A4) | `anexos/anexoA.tex` | Ya hay guion en el placeholder: soberanía tecnológica, doble uso, residuos, consumo FPGA |
| **Anexo B** — presupuesto | `anexos/anexoB.tex` | ⚠️ **Sigue siendo la tabla de EJEMPLO de la plantilla** (300 h × 15 €, impresora láser…). Hay que rehacerla con horas reales, ZCU102, coste de las 3 PCBs (PCBWay + Mouser/DigiKey), licencias |
| **Radiación / TMR en líneas futuras** | `cap5/lineasfuturas.tex` | No existe ninguna mención a TMR en todo el documento. Ver propuesta abajo |
| **Agradecimientos** | `pre/greetings.tex` | Revisar si está hecho |

> **Actualización 15-jul-2026:** la narrativa del DMA14 se reescribió en cap3 (variante B),
> cap4 (salvedad previa + discusión) y cap5 (conclusiones + línea futura): ahora cuenta que fue
> el primer intento de mejora frente a AXI GPIO, que funcionó en placa (TX), que el loopback no
> se consiguió hacer funcionar sobre esa variante y que por tiempo + coste de área (incompatible
> con TMR futuro) se pasó al MCDMA. El argumento TMR del punto "discusión del benchmark" de la
> propuesta de abajo **ya está aplicado**.
>
> **Actualización 15-jul-2026 (2):** la línea futura de radiación **ya está escrita** en
> `lineasfuturas.tex`: replicar la variante MCDMA con TMR (votadores incluidos) y demostrar que
> supera la misma campaña de 36 comprobaciones, con el argumento de área 16 % vs 44 %. El tema
> radiación/TMR queda cerrado.

### Propuesta para la línea futura de radiación/TMR (tu petición)

Añadir un bloque en `lineasfuturas.tex` y **una frase en la discusión del benchmark**
(`cap4/benchmark.tex`, subsección "Discusión") que refuerce el descarte del DMA14:

- **En la discusión del benchmark:** el 14,7 % de LUT del DMA14 no es solo un coste, es
  *presupuesto de área que hipoteca la mitigación de radiación*: una futura triplicación TMR
  de la lógica crítica multiplicaría por ~3 la huella, y 3 × 14,7 % ≈ 44 % del dispositivo es
  inasumible, mientras que 3 × 5,2 % del MCDMA sigue siendo viable.
- **En líneas futuras:** párrafo "Endurecimiento frente a radiación" — la PL comercial es
  susceptible a SEU en la memoria de configuración; líneas concretas: (1) TMR de los bloques
  propios (puente, transceptores) con votadores, para lo que la reserva de área del MCDMA es
  condición habilitante; (2) *scrubbing* de la memoria de configuración (SEM IP / lectura
  readback); (3) ECC en BRAMs y en los buffers DDR de descriptores; (4) ensayos de inyección
  de fallos. Enlaza con la filosofía COTS+arquitectura de la introducción (cap1 ya planta esa
  semilla: "trasladando la fiabilidad desde la pieza individual hacia la arquitectura").

---

## 4. Huecos de figuras (25)

Placeholders `[Figura pendiente…]` por sección — tu lista de fotos/diagramas pendientes:

**cap3/ejemploDesarrollo.tex (14):**
1. FSM del transmisor (3 partes) — diagrama
2. FSM del receptor — diagrama
3. Circuito NCO 32 bits — diagrama
4. Arquitectura general placa serial (7×RS485 + FMC + 7×RS422) — diagrama
5. Diagrama jerárquico CDHS — diagrama (¿del PDF de Altium?)
6. Render 3D CDHS
7. Esquemático CAN (TCAN1044 + terminación split + ESD)
8. Esquemático canal RS (THVD1424 + TVS)
9. Diagrama jerárquico AOCS
10. Render 3D AOCS
11. Esquemático SpaceWire
12. Foto proceso fabricación (pasta + stencil)
13. Foto CDHS soldada
14. Foto AOCS soldada

**cap3/transporte.tex (1):**
15. Diagrama de bloques variante MCDMA (MM2S→conversor→BRIDGE_TX→14 UART; 14 UART→BRIDGE_RX→S2MM) — **la figura más importante que falta de todo el TFM**

**cap4/ejemploResultados.tex (10):**
16. Foto sistema montado (ZCU102 + CDHS en FMC)
17. Foto CDHS montada
18. Foto AOCS montada
19. Captura terminal RS CDHS (el log está en `tfm/00_docs/logs_terminal/`)
20. Captura terminal RS AOCS
21. Osciloscopio: CAN sin terminación
22. Osciloscopio: CAN con terminación
23. Captura terminal ADC
24. Osciloscopio: PWM en J5 CDHS
25. Osciloscopio: par PWM complementario AOCS

Sugerencia: las capturas de terminal (19, 20, 23) pueden resolverse hoy mismo componiendo una
imagen desde los `.txt` de `logs_terminal/` (o directamente sustituyendo la figura por un
`lstlisting` más largo, que ya usas). Las de osciloscopio y fotos son las que dependen del
laboratorio. Los diagramas FSM/NCO/bloques puedes generarlos con TikZ, igual que ya haces con
las gráficas del benchmark (que están muy bien resueltas, por cierto).

---

## 5. Discrepancias memoria ↔ repositorio

**R1. ✅ CORREGIDO (15-jul-2026).** Rutas actualizadas: `generate_boot.sh` →
`tfm/06_firmware/boot_scripts/`; terminales → `tfm/00_docs/logs_terminal/`; `HARDWARE/*` →
`tfm/00_docs/pcbs/{serial,cdhs,aocs}/` con la frase suavizada a "esquemáticos (PDF) y BOM".
Hallazgo original — rutas citadas en la memoria que NO existían en el repo:

| La memoria dice | Realidad | Dónde se cita |
|---|---|---|
| `tfm/04_tools/` | `tfm/07_tools/` | cap3 (generate_boot.sh) |
| `tfm/terminal/` | `tfm/00_docs/logs_terminal/` | cap4, 3 placeholders de figura |
| `HARDWARE/`, `HARDWARE/CDHS/`, `HARDWARE/AOCS/`, `HARDWARE/lince_comunicacion_serial/` | `tfm/00_docs/pcbs/{serial,cdhs,aocs}/` (solo PDF + BOM; no hay proyectos Altium en el repo) | cap3, 4 veces |

Decide una convención (yo citaría rutas relativas al repo: `tfm/00_docs/pcbs/cdhs/`) y haz una
pasada con grep. Ojo: si dices "esquemáticos completos… disponibles en el repositorio", ahora
mismo lo que hay son **PDFs y BOMs**, no los proyectos Altium — o subes los `.PrjPcb` o suavizas
la frase ("los esquemáticos completos (PDF) y las BOM").

**R2. ✅ CORREGIDO (15-jul-2026).** Cabeceras actualizadas a # 05 / # 06 / # 07.
Hallazgo original — cabeceras de README desincronizadas tras la renumeración de carpetas:
`tfm/05_aplicaciones_cdhs_aocs/README.md` dice "# 04 —…", `tfm/06_firmware` dice "# 05 —…",
`tfm/07_tools` dice "# 06 —…". Tres ediciones de una línea.

**R3. La cifra de 20.188 líneas de código no es reproducible desde el repo.** El recuento crudo
de `tfm/` da ~14,5k de VHDL, ~11k de TCL, ~54k de C (con FSBL/psu_init generados)… El criterio
del anexo (excluir generado, terceros y duplicados entre variantes) es razonable, pero si un
tribunal pide demostrarlo no hay forma. **Arreglo barato:** un script `tools/count_loc.sh` (o un
`.cloc` config) en el repo que aplique exactamente ese criterio y reproduzca la tabla del anexo.
Eso convierte una cifra defendible en una cifra *demostrable*.

**R4. La duplicación de código entre variantes es intencional y está justificada** en el README
raíz y en `SOFTWARE.md` ("las tres copias difieren en cuatro líneas") ✅ — este era uno de tus
miedos y está bien resuelto. Solo asegúrate de poder explicarlo con esa frase.

**R5. La corrida intermedia del benchmark MCDMA no está en `resultados/`** (ver G3): el repo
salta de `run1_previo` (RX roto, 0 bytes) al resultado final. Si existió una corrida "arreglado
a medias" cuyos números usa el texto, súbela.

---

## 6. Guía de lectura con preguntas tipo tribunal

Orden de lectura recomendado (no lineal — primero el esqueleto argumental, luego el relleno):

### Pasada 1 — el argumento (1 tarde): resumen → objetivos → cap3/transporte → cap4/benchmark → conclusiones
Es la columna vertebral del TFM. Autoexamen:

1. ¿Por qué una interrupción por byte mata el sistema si a 115.200 baudios hay 87 µs entre
   bytes? (Respuesta en `cap2/transporte.tex`: 14 canales × tasa de símbolo + coste de
   conmutación de contexto → *interrupt livelock*, Mogul 1997.)
2. ¿Por qué la topología MCDMA es asimétrica (1 canal TX / 14 RX)? ¿Qué pasaría con 1 solo
   canal RX? (Los flujos se mezclarían en un buffer único; en TX el destino viaja en la cabecera.)
3. ¿Qué es TDEST y qué pasa si no se propaga? (Todo el RX acaba en el canal 0 — te pasó.)
4. ¿Por qué `Transceiver_Send` es bloqueante SOLO en la variante MCDMA? (Mutex sobre el único
   canal MM2S compartido.)
5. ¿Por qué el cronómetro del bench para en el receptor y no al retornar del send? (Porque el
   send es bloqueante en MCDMA y no en las otras: mediría cosas distintas.)
6. ¿Por qué MAX_PKT = 256 si el buffer store-and-forward admite 512? (Margen ×2 para que la
   invariante sea estructural y no dependa de carreras drenado-vs-línea; el S2MM en S&F se
   bloquea sin error con paquetes > buffer.)
7. ¿Por qué TLAST tiene que ser registrado y no combinacional? (Un byte que llega durante
   contrapresión tumbaría un TLAST ya presentado → paquete reabierto → mismo bloqueo.)
8. ¿Por qué el DMA14 "no escala" si funciona? (28 líneas de IRQ vs 8 del silicio + 14,7 % LUT;
   el límite es del dispositivo, no del diseño. + tu nuevo argumento TMR.)
9. IRQ/KB del GPIO: ¿por qué 1.250 y no 1.024 si fuera exactamente 1 por byte? (RX añade
   eventos de estado: 129.382 IRQ para 101.890 bytes.)
10. ¿Qué mide y qué NO mide el loopback en la PL? (Transporte PS–PL sí; integridad física,
    terminación, guard time, no — eso es el cap. de la PCB.)

### Pasada 2 — resultados PCB (1 mañana): cap4/pcb + cap5/lineasfuturas
11. ¿El hardware de la placa está invertido? (NO — el pin SLO del LTC2865 es *activo a nivel
    bajo* según datasheet; lo que está mal es el **nombre de la macro** en `transceiver.h`.)
12. ¿Por qué el bus A topa en 460k y los B/C en 1M con el mismo chip capado a 250k nominales?
    (7 nodos cargan más la línea; el nominal es garantizado/conservador y aquí hay pistas
    cortas a temperatura ambiente.)
13. ¿Por qué el limitador de slew NO mejora la integridad a alta velocidad? (Al revés: cierra
    el ojo; su función es EMC a baja velocidad.)
14. ¿De dónde salen los 147 ppm del bus A y por qué no te preocupan? (T9, cerca del límite de
    velocidad del multipunto; los RS-422 dan 0 en ~1 M bytes.)
15. ¿Por qué el contador de errores hardware de T9 no se usó? (Marca millones en tandas con
    BER 0 medido byte a byte; cuenta otra cosa.)

### Pasada 3 — desarrollo clásico (1 tarde): cap3/ejemploDesarrollo + cap4/ejemploResultados
16. ¿Por qué DE y RE van cortocircuitados en el THVD1424? (Half-duplex comparte par; Indra
    confirma que los esclavos solo hablan bajo demanda; evita eco propio.)
17. ¿Por qué componentes AEC-Q100 y no calificados espacio? (VIO 1,8 V del FMC incompatible
    con el catálogo espacial de 3,3/5 V → filosofía NewSpace/COTS, y son placas de validación,
    no de vuelo.)
18. ¿Cómo funciona la verificación de start-bit a mitad de período y qué problema resolvió?
    (Pulsos de ruido → start espurios → caracteres corruptos; remuestreo a T/2.)
19. ¿Qué expone el bloque de info del sistema en 0xA0020000 y para qué? (count/stride/base →
    mismo binario para cualquier nº de transceptores; INTC = base + count × stride.)
20. ¿Por qué el `module reference` de Vivado te costó días? (Cachea el checkpoint OOC: editas
    VHDL, reimplementas, y el .bit lleva el RTL viejo → verificación por hash del BOOT.bin.)

### Pasada 4 — marco y envoltorio (1 mañana): cap1 + cap2 + anexos
- Verifica tú mismo las afirmaciones del cap2 que la IA redactó "de libro": límites RS485
  (32 nodos, 1.200 m, 50 Mbps), RS422 (1 TX / 10 RX), SpaceWire (DS, XOR, 2–400 Mbps), CAN
  (CSMA/CD+AMP). Son estándar, pero es tu nombre el que va en la portada.

---

## 7. Plan de trabajo sugerido

Con más de un mes, en este orden (cada punto deja el documento estrictamente mejor):

1. **Correcciones G1–G3** (una tarde). Son las únicas contradicciones internas.
2. **Pasada de rutas** (R1) + READMEs (R2) (1 hora, mecánico).
3. **Anexo B real** — presupuesto con costes verdaderos (una tarde; ten a mano facturas
   PCBWay/Mouser).
4. **Summary + keywords en inglés** (1 hora).
5. **Línea futura de radiación/TMR** + frase en la discusión del benchmark (una tarde).
6. **Anexo A** (una tarde; el guion ya está en el placeholder).
7. **Lecturas guiadas 1–4** con el cuestionario de la sección 6 — reparte una pasada por
   semana. Anota todo lo que no sepas responder sin mirar: eso es lo que hay que estudiar
   o reescribir.
8. **Figuras**: primero la 15 (diagrama MCDMA, la más importante), luego terminales desde
   los logs, y deja fotos/osciloscopio para la sesión de laboratorio.
9. **M1–M6** al hilo de las lecturas (cada una es una edición local).
10. **Script de recuento LOC** (R3) si quieres blindar la cifra de 20.188.

---

*Generado por revisión automática contrastada con: `plantilla_tft_etsit/*.tex` (los 15
ficheros), `main.log`, `biblio.bib`, `tfm/03_bench_loopback/resultados/`,
`tfm/04_pcb_caracterizacion/resultados/`, `tfm/00_docs/informe_benchmark.html`, y los
READMEs de las secciones 00–07.*
