# Revisión Rev2 — plan de trabajo

Este fichero es autosuficiente: se puede ejecutar desde una sesión nueva sin haber
leído las fuentes originales. Lee primero «Cómo trabajar con este plan».

## Fuentes

- `Revisiones/Rev2_mem_jae.pdf` — 128 páginas, 45 anotaciones del tutor.
  Volcadas en texto plano en **`Revisiones/rev2_anotaciones.md`**.
- `Revisiones/Terminología y ortografía del TFM.html` — informe de la pasada 2,
  con recuentos medidos sobre las fuentes tipográficas del PDF. El HTML **no se
  lee abriéndolo**: el contenido está en el `saved_resource.html` de la carpeta
  `_files`. Volcado en **`Revisiones/terminologia_ortografia.md`**.

No hace falta abrir ninguna de las dos fuentes para ejecutar el plan; están ahí
por si hay que consultar el original.

## Cómo trabajar con este plan

**Raíz del repositorio:** `c:\Users\jaest\OneDrive\Documentos\4_TELECO\TFM\tfm`.
Las rutas `capitulos/…`, `pre/…`, `IMG/…`, `main.tex` y `biblio.bib` son
relativas a `plantilla_tft_etsit/`. Las rutas `tfm/…` son código fuente del
proyecto, en la raíz.

**Compilar** (MiKTeX con pdflatex, desde `plantilla_tft_etsit/`):

```
pdflatex main && bibtex main && pdflatex main && pdflatex main
```

Hacen falta las tres pasadas para que cuadren índice, referencias y bibliografía.
Si quedan `??` en el PDF, falta una pasada. El autobuild de LaTeX Workshop está
desactivado en `.vscode/settings.json`, así que hay que compilar a mano.

**Páginas.** El plan cita folios impresos. Para ver el original de un folio:

```
pdftotext -f N -l N "Revisiones/Rev2_mem_jae.pdf" -    # N = folio + 17
```

**Commits.** Uno por pasada, con el mensaje que va al final de cada sección. Sin
firmas ni coautorías añadidas.

**Antes de tocar cada punto:** el PDF revisado se compiló antes de `dd6646a`
(«Reorganizar el capítulo de resultados y añadir la revisión Rev2»), así que
algún punto puede estar ya resuelto. Comprobar que sigue existiendo.

**Orden de las pasadas**, pensado para no rehacer trabajo: primero el preámbulo,
que recompone todo el documento; luego los reemplazos mecánicos; luego la prosa;
después la poda de alcance; y las figuras al final, cuando la paginación ya no se
va a mover.

## Mapa de ficheros

| Fichero | Contenido |
|---|---|
| `main.tex` | Preámbulo, márgenes, `\lstlistingname`, orden de capítulos y anexos |
| `pre/resumen.tex` | Resumen, Palabras Clave, Summary, Keywords |
| `pre/greetings.tex` | Agradecimientos |
| `pre/acronimos.tex` | Lista de acrónimos (78 entradas) |
| `capitulos/cap1/intro.tex` | 1. Introducción, Objetivos, Metodología, Estructura |
| `capitulos/cap2/contexto_proyecto.tex` | 2.1 LINCE · 2.2 ZCU102 · 2.3 Vivado/Vitis · 2.4 RTEMS · 2.5 Comunicaciones serie (RS485, RS422, SpaceWire, CAN) |
| `capitulos/cap2/transporte.tex` | 2.6 Transporte PS–PL: AXI, DMA, coste de la interrupción |
| `capitulos/cap3/entorno_desarrollo.tex` | 3.1 Entorno · 3.2 Transceptor (NCO, TX, RX, FIFO, canal, top) · 3.3 TCL · 3.4 Driver RTEMS · 3.5 Diseño hardware (las tres placas) · 3.6 Testing y arneses. **1933 líneas, el fichero grande** |
| `capitulos/cap3/transporte.tex` | 3.x Variantes A/B/C de transporte, comparación, depuración, banco de loopback |
| `capitulos/cap4/validacion_hardware.tex` | 4.1 Validación CDHS · 4.2 Validación AOCS |
| `capitulos/cap4/pcb.tex` | 4.3 Validación de la placa de comunicación serie: buses, slew rate, multipunto |
| `capitulos/cap4/benchmark.tex` | 4.4 Comparativa de transportes: hardware, software, interrupciones, latencia, throughput, barrido, robustez, selección |
| `capitulos/cap5/conclusiones.tex` | 5. Conclusiones |
| `capitulos/cap5/lineasfuturas.tex` | 5. Líneas futuras |
| `capitulos/anexos/anexoA.tex` | Anexo A: aspectos éticos, económicos, sociales y ambientales |
| `capitulos/anexos/anexoB.tex` | Anexo B: presupuesto |
| `capitulos/anexos/anexoC.tex` | Anexo C: mapas de señales, tabla del NCO, volumen de código, detalle RTL |
| `IMG/Desarrollo/*.tex` | Diagramas en TikZ, editables |

---

## Rev2.1 — Preámbulo y estructura

Solo `main.tex`. Cuatro cambios que arreglan varios bloques del informe de golpe.

- [x] `\appendix` antes del primer `\chapter` de anexo (`main.tex:270-282`).
      Arregla «Tabla 5.1» → A.1/B.1 y «Programación 5.1/5.2» del anexo C.
      *(p. 100 del PDF: «No es capítulo 5»; bloque F del HTML)*
- [x] `\usepackage[T1]{fontenc}`. **Causa raíz de las comillas**: sin fontenc, OT1
      no tiene guillemets y babel-spanish los compone con CMSY6 (`≪` / `≫`, los
      operadores «mucho menor/mayor que»). Las seis comillas del documento
      (`cap3/transporte.tex:410,459`, `cap4/pcb.tex:93,94,138`,
      `cap5/conclusiones.tex:62`) se arreglan con esta línea, sin tocar el texto.
      *(bloque C del HTML)*
- [x] `\renewcommand\lstlistingname{Listado}` y
      `\renewcommand\lstlistlistingname{Índice de listados}` (`main.tex:126-127`).
      «Programación» nombra la actividad, no el objeto. Cambia en los nueve listados.
      *(bloque F)*
- [x] Romanos en minúscula en el índice de los preliminares: el índice dice
      `II`, `IV`, `X` y las páginas imprimen `ii`, `iv`, `x`. Revisar también que
      el número del índice coincida con el folio real (el resumen empieza en ii).
      *(bloque F, `pdf 9`)*
- [x] Compilar y comprobar: sin `??`, índice correcto, anexos con letra, y que
      T1 no haya roto ninguna caja (cambia la partición silábica de todo el texto).

**Commit:** `Rev2.1: preambulo, appendix, fontenc T1 y rotulo de listados`

## Rev2.2 — Terminología unificada (buscar y reemplazar)

Ninguna variante es un error; el problema es que conviven. Se adopta la mayoritaria.

- [x] `RS-422` / `RS-485` → `RS422` / `RS485`. 19 ocurrencias en `capitulos/`
      (132 sin guion frente a 27 con guion; las Palabras Clave ya van sin guion).
      Conviven dentro de la tabla 4.9.
- [x] `transceiver` → `transceptor`. 7 ocurrencias, incluido el título de §3.3.1
      «Generación de transceivers con TCL».
- [x] Velocidad de línea siempre en **baudios** / **Mbaudios** (decisión tomada,
      en contra de lo que proponía el HTML). Hoy el cuerpo tiene 28 en baudios y
      35 en bps, y `cap4/pcb.tex` es casi todo bps mientras `cap3` y `cap4/benchmark`
      van en baudios. Convertir los de `cap4/pcb.tex:78,79,80,84,105,148,150,189,201,226`
      y los de `cap5/conclusiones.tex`.
      **Excepciones que se quedan en bps:** la cita literal del datasheet del
      LTC2865 (`pcb.tex:139`) y el máximo nominal que la referencia
      (`pcb.tex:143,149`), y las velocidades de estándares ajenos al transceptor
      (CAN y SpaceWire en `cap2/contexto_proyecto.tex`), que sus normas dan en bps.
- [x] `BOOT.bin` → `BOOT.BIN`. 8 ocurrencias. Es el nombre real en la FAT.
- [x] `data-strobe` → `Data-Strobe` (2). Es como lo escribe el ECSS.
- [x] `Half-Duplex` → `half-duplex` (5). **Excepción:** el jumper H/F del THVD1424
      va como lo serigrafía el fabricante.
- [x] `New Space` → `NewSpace` (1).
- [x] Xilinx / AMD: una frase en §2.2 («Xilinx, hoy AMD; en adelante AMD») y a
      partir de ahí una sola forma. Los nombres de IP y guías (`axi_dma`, PG021)
      y la bibliografía se quedan como los publica el fabricante.
- [x] `biblio.bib:6,14` — `Recuperado el` → `Consultado en` (4 frente a 2 en el
      mismo `.bib`).
- [x] LINCE con una sola grafía. Hoy hay tres:
      - `cap1/intro.tex:3` — «Línea de **IN**dustrialización de **C**argas de pago
        y plataformas **E**spaciales»
      - `cap2/contexto_proyecto.tex:6` — «Línea de industrialización de cargas de
        pago y plataformas espaciales»
      - `pre/acronimos.tex:75` — igual que la anterior, todo en minúscula.

      Las mayúsculas que explican el acrónimo están bien, pero entonces van en las
      tres. Adoptar la de `intro.tex` en los tres sitios.

**Commit:** `Rev2.2: unificar terminologia y nomenclatura`

## Rev2.3 — Cursivas de extranjerismos

El criterio ya existe y está bien aplicado en 36 términos. Falta declararlo y
cerrar los siete que se mezclan dentro de la misma página.

- [x] Declarar la política en §1.4 o en la lista de acrónimos: los términos
      ingleses sin equivalente asentado van en cursiva; los ya incorporados al uso
      técnico (*hardware*, *software*, *driver*, *firmware*) solo en su primera
      aparición.
- [x] `frame` / `frames` — p. 81 lleva dos en cursiva y dos en redonda; también
      p. 79 (cursiva) frente a pp. 68 y 81 (redonda).
- [x] `stream` — 12 cursivas y 21 redondas, mezcladas en pp. 12, 13, 59, 63.
- [x] `buffer` — 23 cursivas y 9 redondas; las nueve caen en pp. 13, 63, 64, que
      también lo llevan en cursiva.
- [x] `slew rate` — 10 cursivas y 2 redondas; la p. 85 tiene una de cada.
- [x] `sprint` y `backlog` — cursiva en p. 2, las dos formas dentro de la p. 3.
- [x] `full-duplex` — cursiva en pp. 8, 10, 44, 49; redonda solo en la p. 9.
- [x] `software` (39, nunca en cursiva) y `hardware` (4 cursivas de 70): van en
      pareja o no van. Con la política declarada, ambos solo en la primera vez.

No tocar: *livelock*, *benchmark* y *routers* en redonda en pp. 92–93 son títulos
de la bibliografía.

**Commit:** `Rev2.3: declarar y cerrar el criterio de cursivas`

## Rev2.4 — Números, unidades y acrónimos

- [x] Separador de millares con espacio fino (140 apariciones ya lo hacen bien):
      `anexoC.tex:200`, `cap3/entorno_desarrollo.tex:331` y
      `cap5/conclusiones.tex:11` → `4\,000\,000`;
      `anexoC.tex:274` y `cap5/conclusiones.tex:93` → `20\,188`.
- [x] Porcentajes con espacio fino: `6%` en la tabla del presupuesto (convive con
      `15 %` en filas consecutivas) y `η ≥ 96%` en la figura 3.8. 39 ya están bien.
- [x] Tabla 4.6 (p. 80): la cabecera escribe `115200 · 230400 · … · 1M · 2M · 4M`
      mientras la prosa de la misma página escribe «115 200», y dentro de la
      cabecera se mezclan cifra completa y sufijo M. Unificar a espacio fino, o
      dejarla compacta y decir la unidad en el pie. Lo que no vale es tener las
      dos notaciones en la misma fila.
- [x] Repasar que todas las magnitudes lleven `\,` **no separable** y no se
      partan al final de línea: `1,8 V`, `120 Ω`, `100 µs`, `460 kbaudios`,
      `3,52 W`, `32 bits`, `4,7 nF`, `±2 %`, `120 ppm`.
      **Sin `siunitx`** (decidido): son cinco sitios rotos frente a 140 correctos,
      y no compensa un segundo refactor de tipografía encima del `fontenc T1`.
- [x] Añadir a `pre/acronimos.tex` las 23 ausencias, y desarrollarlas también en
      su primera aparición: TDEST (20 usos), TLAST (13), BER (8, ya está en la
      lista pero sin desarrollar en el cap. 4), RTL (5), TVALID/TREADY (5+5, solo
      en nota al pie de la p. 11), SPW (5), HPC (3), HP (3), BIF (3), SMP (2),
      SAR (2), TVS (2), WNS (2, es una columna de la tabla 4.1), SG (2), y las de
      un solo uso: RSB, EMC, LDO, CRC, IDE, GUI, QEMU, PYMES, MMIO — o se
      desarrollan en el sitio, o se sustituyen por el nombre completo.
- [x] SLO está en la lista de acrónimos y no es un acrónimo. Solución adoptada:
      **renombrar la sección a «Lista de acrónimos y glosario»** y dejar la entrada
      donde está. Revisar de paso si hay más entradas que sean glosario y no sigla.

**Commit:** `Rev2.4: numeros, unidades y lista de acronimos`

## Rev2.5 — Ortografía, gramática y Summary

El cuerpo técnico sale limpio con el corrector es_ES. Todo lo que queda está en el
capítulo 3 y en los agradecimientos.

- [x] `semiperiodo` / `semiperiodos` → `semiperíodo` / `semiperíodos`, 7 veces
      (pp. 23, 24, 25×3, 29, 30). El documento ya usa «período» con tilde cinco
      veces; la palabra compuesta tiene que seguir a la simple.
- [x] p. 9: «por periodo de bit» → «por período de bit».
- [x] `pre/greetings.tex:24` — `examenes` → `exámenes`. La primera aparición del
      mismo párrafo ya está bien, lo que prueba que es errata.
- [x] `pre/greetings.tex:15` — paralelismo roto: «he podido disfrutar…,
      empaparme… y **contado** con…» → «…y **contar** con vuestra ayuda…».
      La coma antes de la «y» sobra en una enumeración de tres.
- [x] `pre/greetings.tex` — «han participado **de** este desarrollo» →
      «participado **en**». «Participar de» es compartir una opinión, no tomar parte.
- [x] `pre/greetings.tex` — repetición: «Al resto de compañeros del laboratorio,
      por hacer del **laboratorio** algo más…» → «por hacer **de él** algo más…».
- [x] `pre/resumen.tex` (Summary, p. ii) — «widen the development window» no
      significa nada en inglés; *window* se lee como ventana temporal. Propuesta:
      «…to extend its capabilities and broaden the range of interfaces that can be
      developed and tested on it».
- [x] `pre/resumen.tex` — «analogue» es ortografía británica en un texto que no
      marca variedad. Decidir una y aplicarla en Summary y Keywords.

No tocar: «las cerves», «el buen rollo» y el registro coloquial de los
agradecimientos. Ni los falsos positivos del corrector (listados de código,
volcados de terminal, rótulos de Altium, nombres de directorio).

**Commit:** `Rev2.5: ortografia, agradecimientos y Summary`

## Rev2.6 — Correcciones de fondo señaladas por el tutor

Puntos de precisión, cada uno con una comprobación detrás.

- [x] **p. 10** «La frase de proporciona queda rara o inconexa»: dos frases
      seguidas empiezan por «proporciona» en §2.5.3 (SpaceWire). Refundido en una
      sola: «…aporta una alta tolerancia al desfase. El estándar define enlaces
      punto a punto full-duplex…».
- [x] **p. 15** «¿Libro de instrucciones?» y «Ojo con esto, que no te pase como a
      Diego». Aclarado en persona con el tutor: el aviso era que la memoria no se
      lea como un manual, y aquí el detalle está justificado. No se toca el texto
      del entorno de desarrollo. Lo que sí sale de esa conversación es la pasada
      **Rev2.8**, más abajo.
- [x] **p. 53** La figura 3.17 (placa de comunicación serie soldada) no se cita en
      ningún sitio. Ya resuelto antes de esta pasada: `entorno_desarrollo.tex:1746`
      la cita con `\ref{fig:serial_soldada}`.
- [x] **p. 70** «¿Referencia exacta?»: la corrección de robustez del receptor se
      cita como «descrita en el Capítulo 3». Añadido `\label{sec:startbit_robustez}`
      en `entorno_desarrollo.tex:652` y `\ref` en `validacion_hardware.tex:55`
      (imprime «sección 3.2.3»).
- [x] **p. 76** `cap4/benchmark.tex:19` — «Revisa ese J3». Verificado: `ZCU102_RD_J3_6.xdc:39`
      rotula «PROTOTYPE HEADER (J3)» y mapea ahí las UART 8–12 con pines J3.6–J3.24.
      J3 es el conector correcto (cabecera de prototipo de la PL). No se toca.
- [x] **p. 83** `cap4/benchmark.tex:485` — «Revisa ese factor de 4». Erróneo:
      GPIO 6\,434 LUT frente a MCDMA 14\,191 (tabla 4.5) → «ocupa menos de la mitad
      de lógica que el MCDMA», con las cifras entre paréntesis.
- [x] **p. 86** «Esto no se ve en la tabla o gráfica»: la afirmación era falsa —
      con SLO=1 los tres buses llegan a 4~Mbaudios por igual (figura 4.9). Corregida:
      la penalización del bus multipunto solo aparece con el limitador activo.
- [x] **p. 89** `cap5/conclusiones.tex:42` — «¿Son 5 o 6?». Son 6
      (`entorno_desarrollo.tex:1004` y su itemize). Conclusiones decía «cinco» →
      «seis».
- [x] **p. 92** `biblio.bib:10` — «Antoniooooooo». Ya resuelto: el `.bib` y las
      cuatro portadas/encabezados dicen «Jorge Alejandro Estefanía Hidalgo». No
      queda ningún «Antonio» en el fuente.
- [x] **p. 95** `anexos/anexoA.tex:31` — falta un «de»: «conocimiento adquirido,
      por ejemplo cómo se sintetiza…» → «adquirido de, por ejemplo, cómo se
      sintetiza…».
- [x] **p. 98** `anexos/anexoA.tex:145` — añadida la sigla: «*single event upsets*
      (SEU)».
- [x] **p. 98** `anexos/anexoA.tex:164` — «Anexo~C» → `Anexo~\ref{anx:presupuesto}`
      (imprime «Anexo B»). `\label` añadidos a los tres anexos en `main.tex`.

**Commit:** `Rev2.6: correcciones de precision y referencias cruzadas`

## Rev2.7 — Anexo A: legibilidad y respuestas de tribunal

El tutor firma el enfoque («me ha encantado, mis dieces») y pide trabajo de
redacción encima, no de contenido.

- [x] **p. 96** «Suena un pelín a Claudia»: el párrafo del PERTE y la masa crítica.
      Criterio para todo el anexo, no solo para ese párrafo: **pasar el anexo
      entero buscando frases pedantes o poco naturales. Si no aportan información,
      fuera. Si son necesarias, se reescriben de forma directa.** Sospechosos
      típicos: la abstracción sin sujeto («es el mecanismo por el que…»), el
      paralelismo retórico y la frase que solo reformula la anterior.
- [x] **p. 96** «Separa en dos oraciones»: el párrafo del TFM como mecanismo de
      formación («Aplica conocimiento académico… y deja como resultado…»).
- [x] **p. 96** «No se termina de entender en la primera pasada, largo y
      complicado»: el párrafo NewSpace/COTS/residuos. Reordenar y partir.
- [x] **p. 96** «Ponlo el último entonces»: mover el apartado de consumo
      energético al final de la lista de impactos ambientales, ya que es el que se
      desarrolla en detalle a continuación.
- [x] **p. 97** Marcar en negrita que el consumo es el apartado sobre el que
      inciden directamente las decisiones de diseño de este trabajo. El tutor lo da
      por buen criterio de ampliación.
- [x] **p. 97** Pregunta de tribunal: ¿qué caudal real va a haber? Si se envían
      pocas muestras por segundo y el canal no se satura, ¿sigue compensando?
      No hay medida de caudal de misión, así que la respuesta va como **acotación
      honesta, no como dato**: el caudal de misión no está fijado, y el cambio es
      favorable en cualquiera de los dos escenarios. Con tráfico alto por el
      rendimiento y la energía por byte; con tráfico bajo porque la variante GPIO
      no era una opción de todos modos, ni por número de canales ni por coste de
      interrupción. Escrito de forma directa, sin adornar la falta de dato.
- [x] **p. 97** Matizar la conclusión de «menos satélites o más pequeños»: el
      margen liberado vale si por las interfaces viaja tráfico sostenido. Decir que
      la plataforma se diseña sin fijar si servirá para telemetría, carga de pago o
      ambas.
- [x] **p. 98** «Troppo longo, recorta»: el apartado de limitaciones del análisis.

**Commit:** `Rev2.7: reescribir el anexo etico para legibilidad`

## Rev2.8 — Alcance: bajar el detalle de bajo nivel a los anexos

Sale de la conversación en persona con el tutor. La memoria no debe leerse como
un manual: el detalle fino de implementación que no cambia el argumento se mueve
a los anexos y en el cuerpo queda el resultado más una frase de enlace con `\ref`.
Corte, no reescritura.

**Requiere que Jorge marque los apartados concretos antes de empezar.**
Candidatos, a confirmar:

- [ ] §3.1 Entorno de desarrollo: instalación y configuración paso a paso.
- [ ] §3.3 Generación de transceptores con TCL: el detalle del script.
- [ ] Configuración de RTEMS (las cajas de código de la p. 54).
- [ ] Las cinco hojas de esquemático a página completa.
- [ ] Mapas de registro y tablas exhaustivas que aún queden en el cuerpo.

**Commit:** `Rev2.8: bajar el detalle de bajo nivel a los anexos`

## Rev2.9 — Figuras y maquetación

Al final a propósito: T1, `\appendix`, los cambios de prosa y la poda de la Rev2.8
mueven la paginación. Aquí van solo las que se resuelven desde el `.tex`; las que
necesitan Altium, cámara o dibujo nuevo están en la lista manual del final.

- [ ] **p. 3** Figura 1.1 (metodología ágil): «se lee muy mal». Letra más grande,
      o un diagrama más básico que muestre el proceso de pensar más que la
      herramienta. `IMG/Desarrollo/diagrama_metodologia_agil.tex`
- [ ] **p. 6** Figura 2.1: señalar los puertos AXI con una flecha grande o un
      recuadro. Tal como está, el lector no encuentra lo que el texto le pide mirar.
- [ ] **p. 9** Figura de topologías RS: texto más grande, y valorar partirla en dos
      para facilitar el salto de página. `IMG/Desarrollo/diagrama_topologia_rs.tex`
- [ ] **p. 11** Figuras de AXI: «de 10», pero agrandar el texto pequeño sin
      aumentar el alto. `diagrama_axi_full/lite/stream.tex`
- [ ] **p. 12** Figura 2.6 (DMA): muy pequeña. `IMG/Desarrollo/diagrama_dma.tex`
- [ ] **p. 13** Figura 2.7 (MCDMA): muy pequeña. `IMG/Desarrollo/diagrama_mcdma.tex`
- [ ] **p. 54** Cajas de código sobre fondo blanco (configuración de RTEMS):
      «me tienden a decir poco». Resumir o pasar a tabla. Coordinado con la Rev2.8.
- [ ] **p. 56** Figuras de arneses: juntarlas en un `subfigure` para que ocupen
      menos. El recorte de las imágenes va en la lista manual.
- [ ] **p. 64** Convertir a tabla la comparativa de interrupciones por kilobyte y
      coste en lógica de las tres variantes. «¿Tablita?»
- [ ] **p. 72** Figuras 4.3 y 4.4 (CAN con y sin terminación): ponerlas en
      paralelo; aunque queden más pequeñas, la diferencia se ve.
- [ ] **p. 73** Listado 4.2 (barrido del ADC): los saltos de línea cortan la salida
      del terminal. Bajar el tamaño y reducir espacios para que cada línea entre
      entera.

No tocar: las figuras 4.2 (flancos con y sin limitador de slew rate) de la p. 71,
que el tutor da por buenas.

**Commit:** `Rev2.9: figuras y maquetacion`

## Rev2.10 — Compilación y verificación final

- [ ] Compilar de cero y comprobar: cero `??`, índice, índice de figuras, índice de
      tablas e índice de listados correctos.
- [ ] Anexos rotulados A, B, C, con tablas A.x/B.x/C.x y listados C.x.
- [ ] Repasar las seis comillas ya como `«»` reales, y la cita del LTC2865 de la
      p. 85 como `quote` sangrado en vez de entrecomillada.
- [ ] Regenerar el PDF y comprobar los folios citados en este plan.

**Commit:** `Rev2.10: regenerar el PDF con la revision Rev2 aplicada`

---

## Tareas manuales para Jorge

No salen del `.tex`: hacen falta Altium, cámara o un dibujo nuevo. Entran en la
Rev2.9 en cuanto el fichero esté en `IMG/`.

- [ ] **p. 5** Foto de la ZCU102 para §2.2. «Quiero ver una foto de la placa».
- [ ] **pp. 45, 50** Reexportar los esquemáticos recortados al bloque de interés
      en vez de la hoja completa. «El resto de la hoja te aporta poco», y «como te
      toque un viejete, ese texto no lo lee ni con telescopio». Aplica a todos.
- [ ] **p. 49** Render 3D de la placa AOCS con fondo blanco. Prioridad baja.
- [ ] **p. 56** Recortar las fotos de los arneses antes de juntarlas.
- [ ] **p. 9** Mini figura de SpaceWire para §2.5.3: muy ancha y corta, que ocupe
      poco y que ilustre el protocolo. El tribunal no lo ha visto nunca.
- [ ] **p. 13** Diagrama del coste de la interrupción para §2.6.3. El tutor
      apunta que probablemente adelanta trabajo de la presentación.

## Descartado

- **p. 100, licencias del presupuesto.** El tutor señalaba que el precio de las
  licencias de Vivado y Altium puede estar por encima del real frente a la tarifa
  educativa o de servidor. Se omite por decisión propia; el presupuesto se queda
  como está.

## Pendiente para más adelante (no entra aquí)

El hilo narrativo y la ordenación temporal, que el HTML deja señalados sin
insistir: en un trabajo desarrollado por sprints, el orden cronológico puede tener
razones que la memoria no cuenta.
