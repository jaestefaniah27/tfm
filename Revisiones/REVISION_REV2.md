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

El análisis está hecho y vive en **`Revisiones/REV2_8_analisis.md`**, con el
reparto cuerpo/anexo de cada bloque y el orden de ejecución. Dos criterios que
gobiernan la pasada: se poda **prosa densa, no páginas** (una figura a página
completa alivia la lectura, no la carga), y el anexo **no es un vertedero**, así
que solo baja lo que tenga sentido consultar aparte.

Apartados confirmados, en orden de ejecución:

- [x] §3.6.1 Aplicación de testing del driver (líneas 1781--1846): bajar las dos
      cajas de código y la secuencia de `Init()`. Arriba quedan diez líneas, y la
      reconfiguración del `slew rate` se menciona solo de pasada. Cierra el punto
      de la p. 54 de la Rev2.9.
- [x] §3.1.3 Validación del flujo de extremo a extremo (líneas 55--346): bajar el
      VHDL, la lista de componentes del BIF, la secuencia de Vitis, la tabla del
      `SW6` y el volcado de la tabla de verdad. Arriba se queda el bloque de
      automatización, y **hay que decir que cada iteración llevaba casi una hora
      de media**: es lo que justifica los tres scripts.
- [x] §3.1.1, §3.1.2 y §3.3: comprimir en el sitio, sin mover nada al anexo.
- [x] Reordenar el anexo C en tres bloques: referencia (C.1--C.5), implementación
      trasladada (C.6--C.8) y volcados de terminal (C.9--C.10). El orden ya salió
      así del traslado; lo que se hizo fue anunciarlo en el párrafo de entrada.
      No se añadieron encabezados de bloque para no renumerar y no tocar a mano
      las referencias `C.x` repartidas por los capítulos 3 y 4.

**Descartados por Jorge, con la poda ya en marcha:**

- [~] §3.5.4 y §3.5.5: bajar los cinco subsistemas que nombran componentes sin
      decisión detrás (ADC, alimentación CDHS, conectores externos, alimentación
      AOCS y las frecuencias del `PWMx4_auto_test`), unas 70 líneas. Se deja
      estar: poca ganancia para lo que cuesta.
- [~] §3.4 Gestión interna de la transmisión y la recepción: descartada **por
      riesgo**. Era la poda de prosa más grande que quedaba, así que el capítulo 3
      baja bastante menos de lo que preveía el análisis. Si más adelante hace
      falta recortar de verdad, este es el bloque al que volver, con el cuidado ya
      identificado: la independencia entre latencia y volumen de datos tiene que
      quedarse arriba porque la §4.4 la necesita.

No entran: §3.2 (transmisor y receptor), §3.5.6 (fabricación),
`cap3/transporte.tex` y la interfaz con el hardware del driver (§3.4, el
descubrimiento del mapa de direcciones).

**Commit:** `Rev2.8: bajar el detalle de bajo nivel a los anexos`

## Rev2.9 — Figuras y maquetación

Al final a propósito: T1, `\appendix`, los cambios de prosa y la poda de la Rev2.8
mueven la paginación. Aquí van solo las que se resuelven desde el `.tex`; las que
necesitan Altium, cámara o dibujo nuevo están en la lista manual del final.

Las páginas que cita cada punto son las de la Rev2.7. La Rev2.8 movió la
paginación, así que abajo se anota entre paréntesis dónde ha quedado cada cosa.

La palanca común a casi todas las figuras TikZ es la misma: son ficheros
`standalone` cuyo dibujo va en centímetros fijos, de modo que la letra no
depende del tamaño de fuente del fichero sino del factor con que LaTeX escala el
PDF hasta el ancho de caja. Pasar la clase a `12pt` agranda el texto sin tocar
la caja envolvente, que es justo lo que pedía el tutor.

- [x] **p. 3 (ahora p. 3)** Figura 1.1 (metodología ágil): «se lee muy mal».
      Rehecha. A 620 pt de ancho por 277 de alto la figura se escalaba a 0,70 y
      ningún tamaño de letra la salvaba, así que se cambió la planta: la reunión
      de cierre se apila bajo el sprint en vez de alinearse a su derecha, y la
      lista de las cuatro fases pasa a una sola columna. Queda en 381 $\times$ 311
      pt, se incluye al 0,82 del ancho de caja y el rótulo sale a cuerpo de
      texto. De paso, el estilo `cap` chocaba con la clave `cap` de TikZ (error
      de `pgfkeys` en cada compilación): renombrado a `note`.
- [x] **p. 6 (ahora p. 7)** Figura 2.1: señalar los puertos AXI.
      **Ojo, decisión que conviene revisar.** El diagrama oficial de AMD que
      ocupaba esa figura no dibuja los puertos AXI en ninguna parte, así que no
      había nada que recuadrar: de ahí que «el lector no encuentre lo que el
      texto le pide mirar». El repositorio ya tenía `diagrama_mpsoc_zynq.tex`,
      propio y huérfano desde hace commits, que sí los dibuja. Ahora es la
      figura 2.1, con la banda AXI recuadrada en azul y rotulada, y el diagrama
      de AMD pasa a ser la 2.2 con el detalle interno. Si sobra una de las dos,
      la que se cae es la de AMD.
- [x] **p. 9 (ahora p. 10)** Topologías RS: clase a `12pt` y paso de 0,92 a 1,0
      del ancho de caja. **No se parte en dos**: las dos mitades comparten un
      único `\ref` y partirla obliga a renumerar figuras por todo el capítulo 2
      para poca ganancia. A 14,3 cm de alto cabe holgada en su página.
- [x] **p. 11 (ahora p. 12)** Figuras de AXI: clase a `12pt`. La caja no se
      mueve (470,4 $\times$ 135,0 pt frente a 470,4 $\times$ 134,5) y el texto sube
      un 20 %. Alto intacto, que era la condición.
- [x] **p. 12 (ahora p. 12)** Figura del DMA: clase a `12pt` y ancho de caja
      completo.
- [x] **p. 13 (ahora p. 13)** Figura del MCDMA: igual que la anterior.
- [x] **p. 54** Cajas de código de la configuración de RTEMS: ya lo cerró la
      Rev2.8 al bajarlas al apartado C.7. Se comprobó sobre el PDF actual.
- [x] **p. 56 (ahora p. 51)** Arneses: los tres en un `subfigure`, y los tres
      `\subsubsection` de una frase fundidos en un párrafo. De tres páginas a
      media. El recorte de las fotos sigue en la lista manual.
- [x] **p. 64 (ahora p. 58)** Tabla 3.10 con IRQ/KB, LUT totales, LUT por canal
      y líneas de interrupción de las tres variantes, más las dos notas al pie
      (el AXI INTC que reduce por OR, y las ocho líneas de `pl_ps_irq0`). Los
      párrafos que venían detrás sueltan las cifras que ahora están en la tabla.
- [x] **p. 72 (ahora p. 66)** CAN con y sin terminación: en paralelo, figura 4.3
      con dos `subfigure`.
- [x] **p. 73 (ahora p. 66)** Listado 4.2: se añade un estilo `terminal` en
      `main.tex` (cuerpo `\scriptsize`, sin numeración de línea, márgenes e
      interlineado ajustados) y se aplica a los doce volcados de terminal del
      documento, que hasta ahora alternaban el estilo por defecto con un
      `basicstyle` puesto a mano. Cada línea entra entera.

También se quitó un residuo de edición de la Rev2.8: un `ef{anx:rtl}.` suelto
en `cap3/entorno_desarrollo.tex`, que salía impreso.

Comprobado sobre el PDF: 129 páginas, cero referencias sin resolver, cero
errores y las mismas diez cajas desbordadas que ya había antes de tocar nada.

No tocar: las figuras 4.2 (flancos con y sin limitador de slew rate) de la p. 71,
que el tutor da por buenas.

**Commit:** `Rev2.9: figuras y maquetacion`

## Rev2.10 — Compilación y verificación final

- [x] Compilar de cero y comprobar: cero `??`, índice, índice de figuras, índice de
      tablas e índice de listados correctos. Cero `??` y cero referencias sin
      resolver. **Faltaba el índice de listados**: `main.tex` llamaba a
      `\tableofcontents`, `\listoffigures` y `\listoftables`, pero no a
      `\lstlistoflistings`, aunque el nombre en español ya estaba puesto desde
      hacía tiempo. Añadido; recoge los quince listados del documento.
- [x] Anexos rotulados A, B, C, con tablas A.x/B.x/C.x y listados C.x. Correcto:
      tablas `B.1` y `C.1`–`C.6`, listados `C.1`–`C.7`. El anexo A no tiene
      ninguna tabla, así que no hay `A.x` que comprobar.

      Lo que sí estaba mal es que **los veinte apartados del anexo C eran
      `\section*`**, sin numerar, con el «C.1» escrito a mano dentro del título.
      No entraban en el índice: treinta y seis páginas que solo se podían recorrer
      pasando hojas. Convertidos a `\section` con su `\label`. La numeración que
      genera `\appendix` coincide exactamente con la que estaba a mano, así que
      ninguna cita del cuerpo cambia de número.
- [x] Las once menciones al anexo repartidas por los capítulos 3, 4 y 5 iban
      escritas a mano (`apartado C.8 del Anexo~C`). Pasan a `\ref`. Las tres del
      mapa de señales decían solo «el Anexo C» y ahora apuntan al apartado de su
      placa, que es lo que el lector busca.
- [x] Repasar las seis comillas ya como `«»` reales, y la cita del LTC2865 de la
      p. 85 como `quote` sangrado en vez de entrecomillada. Ya estaba hecho: la
      cita va en `quote` con comillas angulares, y en prosa no queda ninguna
      comilla recta. Las que aparecen en el fuente están todas dentro de volcados
      de terminal, donde son literales de la salida.
- [x] Regenerar el PDF y comprobar los folios citados en este plan. Regenerado:
      131 páginas. **Los folios que cita este plan son los de la Rev2.7 y ya no
      valen**; la Rev2.8 y la Rev2.9 movieron la paginación y el desfase no es
      constante. Cada punto de la Rev2.9 lleva anotado entre paréntesis dónde ha
      quedado.

**Descartado, decisión de Jorge:** el apartado «Equipo de laboratorio utilizado»
de la §3.6.3 se queda con su única frase. No cita modelos ni ancho de banda del
osciloscopio, que es lo que un tribunal de electrónica puede preguntar después de
leer medidas de flancos de decenas de nanosegundos.

**Commit:** `Rev2.10: regenerar el PDF con la revision Rev2 aplicada`

---

## Tareas manuales para Jorge

No salen del `.tex`: hacen falta Altium, cámara o un dibujo nuevo. Entran en la
Rev2.9 en cuanto el fichero esté en `IMG/`.

- [x] **p. 5** Foto de la ZCU102 para §2.2. «Quiero ver una foto de la placa».
      Puesta como figura 2.1, justo detrás del párrafo que nombra los dos FMC, que
      es donde la foto aporta: van señalados en ella. Citada al pie como la guía de
      usuario de la placa, que es de donde sale.
- [x] **pp. 45, 50** Reexportar los esquemáticos recortados al bloque de interés
      en vez de la hoja completa. «El resto de la hoja te aporta poco», y «como te
      toque un viejete, ese texto no lo lee ni con telescopio». Aplica a todos.
      Hechos los cinco por Jorge y colocados en `IMG/Esquematicos/`: la hoja de
      nivel superior de la placa serie (3.4), el subsistema CAN (3.8) y el canal
      RS (3.9) de la CDHS, la hoja de nivel superior de la AOCS (3.10) y su
      subsistema SpaceWire (3.12). A la hoja de la AOCS se le quitaron los 30
      píxeles de abajo, donde asomaba cortado el cajetín de Altium. Las hojas
      completas siguen en `IMG/pcbs/` como fuente y para el anexo.

      La hoja de la placa serie (3.4) se queda apaisada y a página completa. El
      recorte permitía ponerla derecha al ancho de caja, pero es la más densa de
      las cinco y el criterio no es si se lee en pantalla: el tribunal puede
      leerla en papel, donde no se puede ampliar. Girada gana un 40 % de tamaño
      lineal. La hoja de la AOCS (3.10) sí va derecha, porque tiene pocos bloques
      y rótulos grandes.
- [x] **p. 49** Render 3D de la placa AOCS con fondo blanco. Prioridad baja.
- [x] **p. 56** Recortar las fotos de los arneses antes de juntarlas.
- [x] **p. 9** Mini figura de SpaceWire para §2.5.3: muy ancha y corta, que ocupe
      poco y que ilustre el protocolo. El tribunal no lo ha visto nunca.
      Hecha a mano en TikZ, `IMG/Desarrollo/diagrama_data_strobe.tex`, copiando la
      referencia que pasó Jorge: cronograma de diez bits con las líneas Data y
      Strobe, las tres conmutaciones de Strobe marcadas, el reloj recuperado y la
      XOR que lo produce. Sale a 17,0 $\times$ 5,3 cm, que es la proporción ancha y
      baja que pedía el tutor. Los niveles se calcularon con la regla del estándar
      y son coherentes: Strobe conmuta en los bits 3, 5 y 8, los que repiten al
      anterior, y `D xor S` da un flanco por bit.
- [x] **p. 13** Diagrama del coste de la interrupción para §2.6.3. El tutor
      apunta que probablemente adelanta trabajo de la presentación.

Los tres puntos manuales que quedaban abiertos (render 3D con fondo blanco,
recorte de las fotos de los arneses y diagrama del coste de la interrupción) se
dan por cerrados: son mejoras de prioridad baja y la Rev2 se cierra sin ellos.

## Descartado

- **p. 100, licencias del presupuesto.** El tutor señalaba que el precio de las
  licencias de Vivado y Altium puede estar por encima del real frente a la tarifa
  educativa o de servidor. Se omite por decisión propia; el presupuesto se queda
  como está.

## Pendiente para más adelante (no entra aquí)

El hilo narrativo y la ordenación temporal, que el HTML deja señalados sin
insistir: en un trabajo desarrollado por sprints, el orden cronológico puede tener
razones que la memoria no cuenta.
