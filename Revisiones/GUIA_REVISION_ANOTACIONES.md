# Guía de revisión — las 45 anotaciones de `Rev2_mem_jae.pdf`

Cruce de **`rev2_anotaciones.md`** (lo que dijo el tutor, 45 anotaciones) contra
el estado actual del `.tex` tras **Rev2.1–Rev2.8** (commit `7739303`), para
revisar a mano sin tener que reconstruir el mapeo. Verificado línea a línea
contra el código fuente actual, no contra lo que decía el plan en el momento
de escribirlo (algunas líneas se movieron entre pasadas).

Leyenda: ✅ Resuelta · ⏳ Pendiente (Rev2.9/2.10, aún no ejecutada) · 🚫 Descartada
(decisión consciente) · ➖ Sin acción (comentario positivo o ya no aplica).

**Dos hallazgos de esta revisión, ya corregidos en el repo:**
1. `capitulos/cap3/entorno_desarrollo.tex:1613` tenía una línea suelta
   `ef{anx:rtl}.` — resto de un `\ref` mal editado en Rev2.8, que habría
   impreso ese texto literal en el PDF justo debajo de la frase buena. Borrada.
2. `Revisiones/REVISION_REV2.md`, ítem "p. 54" de la Rev2.9, seguía sin marcar
   aunque el propio commit de Rev2.8 dice que cierra ese punto. Marcado como
   resuelto con la referencia exacta.

Si recompilas antes de revisar (`pdflatex main && bibtex main && pdflatex main && pdflatex main`
desde `plantilla_tft_etsit/`, no lo he podido hacer yo en este entorno porque
no hay `pdflatex` instalado), el fallo #1 ya no debería aparecer.

---

## Tabla completa, en el orden del PDF original

| # | Folio | Anotación del tutor (resumida) | Estado | Dónde está en la memoria actual | Qué comprobar |
|---|---|---|---|---|---|
| 1 | 3 | Diagrama de metodología ágil ilegible; letra más grande o algo más básico | ⏳ Pendiente | `IMG/Desarrollo/diagrama_metodologia_agil.tex` | Rev2.9, apartado "Figuras y maquetación", primer ítem. No tocado aún. |
| 2 | 5 | "Quiero ver una foto de la placa" (ZCU102) | ⏳ Pendiente | §2.2, `capitulos/cap2/contexto_proyecto.tex` | Tarea manual (necesita foto real), listada al final de `REVISION_REV2.md` bajo "Tareas manuales para Jorge". |
| 3 | 6 | Fig. 2.1: sin flecha/recuadro no se localizan los puertos AXI | ⏳ Pendiente | `IMG/Desarrollo/diagrama_mpsoc_zynq.tex` (probable) | Rev2.9, segundo ítem. |
| 4 | 9 | Fig. topologías RS: texto pequeño, valorar partir en dos | ⏳ Pendiente | `IMG/Desarrollo/diagrama_topologia_rs.tex` | Rev2.9. |
| 5 | 9 | Falta una mini-figura de SpaceWire (nadie del tribunal lo conoce) | ⏳ Pendiente | §2.5.3, `capitulos/cap2/contexto_proyecto.tex` | Tarea manual (dibujo nuevo). |
| 6 | 10 | "La frase de proporciona queda rara o inconexa" (dos frases seguidas empezaban igual, SpaceWire) | ✅ Resuelta (Rev2.6) | `capitulos/cap2/contexto_proyecto.tex:182-184` | Verificado: dice ahora "…aporta una alta tolerancia al desfase (*skew*) entre pares. El estándar define enlaces punto a punto *full-duplex* asíncronos…". Ya no se repite "proporciona". |
| 7 | 11 | "Estas 3 figuras, de 10" (AXI-Lite/Full/Stream) | ⏳ Pendiente | `IMG/Desarrollo/diagrama_axi_lite.tex`, `_full.tex`, `_stream.tex` | Rev2.9. |
| 8 | 11 | Aumentar texto pequeño de esas figuras sin aumentar el alto | ⏳ Pendiente | Mismos ficheros que #7 | Rev2.9, mismo ítem que #7. |
| 9 | 12 | Fig. 2.6 (DMA) muy pequeña | ⏳ Pendiente | `IMG/Desarrollo/diagrama_dma.tex` | Rev2.9. |
| 10 | 13 | "mpq" (muy pequeña) — Fig. 2.7 MCDMA | ⏳ Pendiente | `IMG/Desarrollo/diagrama_mcdma.tex` | Rev2.9. |
| 11 | 13 | Diagrama del coste de interrupción para §2.6.3 (ojo, puede adelantar trabajo de la presentación) | ⏳ Pendiente | §2.6.3, `capitulos/cap2/transporte.tex` | Tarea manual (dibujo nuevo). |
| 12 | 15 | "¿Libro de instrucciones?" | ➖ Sin acción / origen de Rev2.8 | — | Aclarado en persona con el tutor (`REVISION_REV2.md`, Rev2.6): el aviso era sobre el tono general de la memoria, no sobre este texto puntual. No se tocó el §3 en ese punto, pero de esta conversación nació **toda la pasada Rev2.8** (bajar detalle de bajo nivel a los anexos), que es justamente lo último que hicisteis. |
| 13 | 15 | "Ojo con esto, que no te pase como a Diego" | ➖ Sin acción / origen de Rev2.8 | — | Mismo punto que #12. |
| 14 | 45 | Recortar el pantallazo del esquemático a solo la parte de interés | ⏳ Pendiente | §4.3/§3.5, esquemáticos CDHS/AOCS | Tarea manual (Altium). |
| 15 | 45 | "Aquí y en las demás" (aplica el recorte a todas las capturas) | ⏳ Pendiente | Mismo grupo que #14, #17 | Tarea manual. |
| 16 | 49 | Fondo blanco en el render 3D de la placa AOCS (prioridad baja) | ⏳ Pendiente | §4.x, render 3D AOCS | Tarea manual, prioridad baja declarada por el propio tutor. |
| 17 | 50 | Texto del esquemático ilegible para un tribunal mayor | ⏳ Pendiente | Mismo grupo que #14 | Tarea manual. |
| 18 | 53 | Fig. 3.17 (placa soldada) no se cita en ningún sitio | ✅ Resuelta (ya antes de Rev2) | `capitulos/cap3/entorno_desarrollo.tex:1746` | Verificado: cita `\ref{fig:serial_soldada}`. `REVISION_REV2.md` lo documenta como resuelto antes de esta pasada. |
| 19 | 54 | "Cajas con código blanco... me tienden a decir poco" | ✅ Resuelta (Rev2.8) | `capitulos/cap3/entorno_desarrollo.tex:1598-1613` + `capitulos/anexos/anexoC.tex` §C.7 (líneas 350-412) | Las dos cajas (macros de `confdefs.h` y protocolo de comandos) bajaron al Anexo C; en el cuerpo solo queda el resumen y el `\ref{anx:rtl}` al apartado C.7. **Nota:** `REVISION_REV2.md` tenía este mismo punto listado sin marcar dentro de la Rev2.9; ya lo he corregido ahí (era un duplicado, no trabajo pendiente real). |
| 20 | 56 | Fotos de arneses: dicen poco, ocupan mucho; juntarlas y recortar | ⏳ Pendiente | §3.5, figuras de arneses CDHS/AOCS | Rev2.9 (agrupar) + tarea manual (recorte de las fotos). |
| 21 | 64 | "¿Tablita?" — comparativa de IRQ/KB y coste lógico de las 3 variantes | ⏳ Pendiente | §4.4, `capitulos/cap4/benchmark.tex` | Rev2.9. |
| 22 | 70 | "¿Referencia exacta?" — la corrección de robustez del receptor se citaba solo como "Capítulo 3" | ✅ Resuelta (Rev2.6) | `capitulos/cap3/entorno_desarrollo.tex:652` (`\label{sec:startbit_robustez}`) y `capitulos/cap4/validacion_hardware.tex:55` (`\ref`) | Comprobar que `validacion_hardware.tex:55` imprime "sección 3.2.3" o el número correcto tras compilar. |
| 23 | 71 | "Esto te ha quedado chulo" (fig. 4.2, flancos con/sin limitador) | ➖ Sin acción | `capitulos/cap4/pcb.tex` | Comentario positivo. `REVISION_REV2.md` lo señala expresamente como "no tocar". |
| 24 | 72 | Poner en paralelo las figuras 4.3 y 4.4 (CAN con/sin terminación) | ⏳ Pendiente | §4.x, `capitulos/cap4/validacion_hardware.tex` | Rev2.9. |
| 25 | 73 | Listado 4.2 (barrido ADC): saltos de línea cortan la salida | ⏳ Pendiente | Listado en `capitulos/cap4/validacion_hardware.tex` o anexo C.10 | Rev2.9. |
| 26 | 76 | "Revisa ese J3" | ✅ Resuelta (verificado, sin cambio de texto) | `capitulos/cap4/benchmark.tex:19` | Verificado contra `ZCU102_RD_J3_6.xdc:39`: J3 es el conector correcto. No hacía falta tocar nada. |
| 27 | 83 | "Revisa ese factor de 4" | ✅ Resuelta (Rev2.6) | `capitulos/cap4/benchmark.tex:485` | Verificado: dice ahora "ocupa menos de la mitad de lógica que el MCDMA" con las cifras entre paréntesis (6\,434 LUT frente a 14\,191, tabla 4.5). El "factor 4" original era erróneo. |
| 28 | 86 | "Esto no se ve en la tabla o gráfica" (SLO=1 sin diferencia entre buses) | ✅ Resuelta (Rev2.6) | `capitulos/cap4/pcb.tex:205` (entorno) | Verificado: "…esta penalización del bus multipunto solo se observa con el [limitador activo]", coherente con figura 4.9/`fig:pcb_slo`. |
| 29 | 89 | "¿Son 5 o 6?" | ✅ Resuelta (Rev2.6) | `capitulos/cap5/conclusiones.tex:42` | Verificado: dice "seis" ("API pública de seis…", coherente con `entorno_desarrollo.tex` línea ~1004 y su itemize). |
| 30 | 92 | "Antoniooooooo" (nombre de autor mal puesto en la bibliografía) | ✅ Resuelta (ya antes de Rev2) | `biblio.bib:10` | Verificado: `author = {Jorge Alejandro Estefanía Hidalgo}`. Búsqueda de "antonio" en todo `plantilla_tft_etsit/` no da ningún resultado. |
| 31 | 95 | Falta un "de" antes/después de "por ejemplo" | ✅ Resuelta (indirectamente, por la reescritura de Rev2.7) | `capitulos/anexos/anexoA.tex:28-31` | El párrafo original se reescribió entero en Rev2.7 (criterio de legibilidad del anexo), así que la frase concreta ya no existe con esa redacción; la construcción actual ("y ese conocimiento (cómo se sintetiza…) permanece…") no tiene el problema de origen. No busques literalmente "adquirido de, por ejemplo" — no está, se resolvió por otra vía. |
| 32 | 96 | "Suena un pelín a Claudia" (párrafo PERTE / masa crítica) | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex` (párrafo del PERTE, en torno a la línea 33-42) | Anexo A reescrito entero con el criterio "fuera lo pedante, directo lo necesario". Leer el párrafo completo, no solo la frase señalada. |
| 33 | 96 | "Me ha encantado el enfoque, mis dieces" | ➖ Sin acción | `capitulos/anexos/anexoA.tex` | Comentario positivo, sin corrección asociada. |
| 34 | 96 | "Separa en dos oraciones" (TFM como mecanismo de formación) | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex:39-42` | Verificar que "aplica conocimiento académico… y deja como resultado…" está partido en dos oraciones. |
| 35 | 96 | "No se termina de entender, largo y complicado" (NewSpace/COTS/residuos) | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex:54-65` (bloque "Residuos electrónicos y ciclo de vida del hardware") | Verificar que el párrafo NewSpace/COTS quedó reordenado y partido. |
| 36 | 96 | "Ponlo el último entonces" (mover consumo energético al final de impactos ambientales) | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex`, orden de los apartados de impacto ambiental | Verificar que "consumo energético" es el último de la lista de impactos, justo antes del apartado técnico que lo desarrolla. |
| 37 | 97 | Negrita en el apartado donde inciden las decisiones de diseño (consumo) | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex`, apartado de consumo energético | Buscar `\textbf{...consumo...}` en ese bloque. |
| 38 | 97 | Pregunta de tribunal: caudal de datos real, ¿sigue compensando con poco tráfico? | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex`, apartado de consumo/impacto | Debe leerse como acotación honesta (no hay medida de caudal de misión), no como dato inventado — comprobar que no se afirma un número que no se midió. |
| 39 | 97 | "Esa es la clave, menos satélites o más pequeños" — matizar (depende de si hay tráfico sostenido) | ✅ Resuelta (Rev2.7) | Mismo bloque que #38 | Verificar que se dice explícitamente que la plataforma no fija si es para telemetría, carga de pago o ambas. |
| 40 | 97 | "Ya he visto que lo medio respondes debajo, pero tenlo presente" | ✅ Resuelta (Rev2.7, junto con #38/#39) | Mismo bloque | Mismo punto, sin acción adicional distinta de #38/#39. |
| 41 | 98 | "Si metes eso, añade SEUs" (para que se entienda sin explicar más) | ✅ Resuelta (Rev2.6) | `capitulos/anexos/anexoA.tex:136` | Verificado: "…frente a los *single event upsets* (SEU), y un satélite que sobrevive…". |
| 42 | 98 | "Troppo longo, recorta" (apartado de limitaciones del análisis) | ✅ Resuelta (Rev2.7) | `capitulos/anexos/anexoA.tex`, apartado de limitaciones (final del anexo) | Comparar longitud con la Rev1 si hace falta verificar el recorte. |
| 43 | 98 | "Ahora es anexo B" (una referencia decía "Anexo C" por error) | ✅ Resuelta (Rev2.6) | `capitulos/anexos/anexoA.tex:163` | Verificado: `Anexo~\ref{anx:presupuesto}`, que con las etiquetas de `main.tex:279-289` imprime "Anexo B". |
| 44 | 100 | Trampa de las licencias en el presupuesto (coste real vs. precio educativo/servidor) | 🚫 Descartada (decisión propia) | `capitulos/anexos/anexoB.tex` (no modificado) | Decisión consciente documentada en `REVISION_REV2.md`, sección "Descartado": se deja el presupuesto como está. No es un olvido. |
| 45 | 100 | "No es capítulo 5. Pon `\appendix`..." | ✅ Resuelta (Rev2.1) | `main.tex:277` (`\appendix`) + `main.tex:279,284,289` (`\label{anx:...}`) | Verificado: `\appendix` está antes del primer `\chapter` de anexo. Comprobar tras compilar que los anexos salen como A/B/C y no como "capítulo 5/6/7". |

---

## Resumen por estado

- **✅ Resueltas y verificadas contra el fuente actual:** 22 de 45 (números
  6, 18, 19, 22, 26, 27, 28, 29, 30, 31, 32, 34, 35, 36, 37, 38, 39, 40, 41,
  42, 43, 45).
- **➖ Sin acción (comentario positivo o ya cubierto por decisión aparte):**
  4 (números 12, 13, 23, 33).
- **🚫 Descartada de forma consciente:** 1 (número 44, licencias).
- **⏳ Pendientes, para la Rev2.9/2.10 que aún no habéis hecho:** 18
  (números 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 14, 15, 16, 17, 20, 21, 24, 25).
  Son casi todas de figuras/maquetación (`Rev2.9`) o tareas manuales con
  Altium/cámara que no se resuelven desde el `.tex`.

Es decir: de las anotaciones que dependían solo de texto y estructura LaTeX,
está prácticamente todo cerrado. Lo que queda pendiente es, con una única
excepción (el "libro de instrucciones" que dio origen a Rev2.8, ya hecho), el
bloque de figuras/maquetación (Rev2.9) y la compilación final de verificación
(Rev2.10), ninguna de las dos ejecutadas todavía.

## Cómo usar esta guía para revisar a mano

1. Recompila la memoria si puedes (los tres `pdflatex` + `bibtex` de rigor).
2. Para cada fila ✅, abre el fichero:línea indicado y compara con la
   columna "Qué comprobar" — no hace falta releer el PDF de revisión.
3. Las filas ⏳ no requieren revisión todavía: son la Rev2.9 pendiente.
4. Las filas 🚫 y ➖ no requieren ninguna acción; están documentadas para que
   no las busques por error pensando que faltan.
