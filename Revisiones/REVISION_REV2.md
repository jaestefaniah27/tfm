# Revisión Rev2 — plan de trabajo

Dos fuentes:

- `Rev2_mem_jae.pdf` — 128 páginas, 45 anotaciones del tutor.
- `Terminología y ortografía del TFM.html` — pasada 2 (ortografía y terminología),
  con recuentos medidos sobre las fuentes tipográficas del PDF.

Offset de páginas: **folio impreso = página del PDF − 17**. Aquí las páginas se
citan como folio (igual que en el HTML) salvo donde se indique `pdf N`.

Aviso: el PDF revisado se compiló antes de `dd6646a` («Reorganizar el capítulo de
resultados y añadir la revisión Rev2»). Antes de tocar cada punto, comprobar que
sigue existiendo.

Orden de las pasadas pensado para no rehacer trabajo: primero el preámbulo (que
recompone todo el documento), luego los reemplazos mecánicos, luego la prosa, y
las figuras al final, cuando la paginación ya no se va a mover. Cada pasada es un
commit.

---

## Rev2.1 — Preámbulo y estructura

Solo `main.tex`. Cuatro cambios que arreglan varios bloques del informe de golpe.

- [ ] `\appendix` antes del primer `\chapter` de anexo (`main.tex:270-282`).
      Arregla «Tabla 5.1» → A.1/B.1 y «Programación 5.1/5.2» del anexo C.
      *(p. 100 del PDF: «No es capítulo 5»; bloque F del HTML)*
- [ ] `\usepackage[T1]{fontenc}`. **Causa raíz de las comillas**: sin fontenc, OT1
      no tiene guillemets y babel-spanish los compone con CMSY6 (`≪` / `≫`, los
      operadores «mucho menor/mayor que»). Las seis comillas del documento
      (`cap3/transporte.tex:410,459`, `cap4/pcb.tex:93,94,138`,
      `cap5/conclusiones.tex:62`) se arreglan con esta línea, sin tocar el texto.
      *(bloque C del HTML)*
- [ ] `\renewcommand\lstlistingname{Listado}` y
      `\renewcommand\lstlistlistingname{Índice de listados}` (`main.tex:126-127`).
      «Programación» nombra la actividad, no el objeto. Cambia en los nueve listados.
      *(bloque F)*
- [ ] Romanos en minúscula en el índice de los preliminares: el índice dice
      `II`, `IV`, `X` y las páginas imprimen `ii`, `iv`, `x`. Revisar también que
      el número del índice coincida con el folio real (el resumen empieza en ii).
      *(bloque F, `pdf 9`)*
- [ ] Compilar y comprobar: sin `??`, índice correcto, anexos con letra, y que
      T1 no haya roto ninguna caja (cambia la partición silábica de todo el texto).

**Commit:** `Rev2.1: preambulo, appendix, fontenc T1 y rotulo de listados`

## Rev2.2 — Terminología unificada (buscar y reemplazar)

Ninguna variante es un error; el problema es que conviven. Se adopta la mayoritaria.

- [ ] `RS-422` / `RS-485` → `RS422` / `RS485`. 19 ocurrencias en `capitulos/`
      (132 sin guion frente a 27 con guion; las Palabras Clave ya van sin guion).
      Conviven dentro de la tabla 4.9.
- [ ] `transceiver` → `transceptor`. 7 ocurrencias, incluido el título de §3.3.1
      «Generación de transceivers con TCL».
- [ ] `baudios` / `Mbaudios` → `kbps` / `Mbps`. ~32 cambios en §4.3.2, §4.3.3 y
      conclusiones. **Excepción:** los límites del LTC2865 (250 kbps, 20 Mbps) van
      como los da la hoja de características.
- [ ] `BOOT.bin` → `BOOT.BIN`. 8 ocurrencias. Es el nombre real en la FAT.
- [ ] `data-strobe` → `Data-Strobe` (2). Es como lo escribe el ECSS.
- [ ] `Half-Duplex` → `half-duplex` (5). **Excepción:** el jumper H/F del THVD1424
      va como lo serigrafía el fabricante.
- [ ] `New Space` → `NewSpace` (1).
- [ ] Xilinx / AMD: una frase en §2.2 («Xilinx, hoy AMD; en adelante AMD») y a
      partir de ahí una sola forma. Los nombres de IP y guías (`axi_dma`, PG021)
      y la bibliografía se quedan como los publica el fabricante.
- [ ] `biblio.bib:6,14` — `Recuperado el` → `Consultado en` (4 frente a 2 en el
      mismo `.bib`).
- [ ] LINCE con una sola grafía en las tres apariciones (p. 1, p. 5 y lista de
      acrónimos). Las mayúsculas que explican el acrónimo están bien, pero
      entonces van en las tres.

**Commit:** `Rev2.2: unificar terminologia y nomenclatura`

## Rev2.3 — Cursivas de extranjerismos

El criterio ya existe y está bien aplicado en 36 términos. Falta declararlo y
cerrar los siete que se mezclan dentro de la misma página.

- [ ] Declarar la política en §1.4 o en la lista de acrónimos: los términos
      ingleses sin equivalente asentado van en cursiva; los ya incorporados al uso
      técnico (*hardware*, *software*, *driver*, *firmware*) solo en su primera
      aparición.
- [ ] `frame` / `frames` — p. 81 lleva dos en cursiva y dos en redonda; también
      p. 79 (cursiva) frente a pp. 68 y 81 (redonda).
- [ ] `stream` — 12 cursivas y 21 redondas, mezcladas en pp. 12, 13, 59, 63.
- [ ] `buffer` — 23 cursivas y 9 redondas; las nueve caen en pp. 13, 63, 64, que
      también lo llevan en cursiva.
- [ ] `slew rate` — 10 cursivas y 2 redondas; la p. 85 tiene una de cada.
- [ ] `sprint` y `backlog` — cursiva en p. 2, las dos formas dentro de la p. 3.
- [ ] `full-duplex` — cursiva en pp. 8, 10, 44, 49; redonda solo en la p. 9.
- [ ] `software` (39, nunca en cursiva) y `hardware` (4 cursivas de 70): van en
      pareja o no van. Con la política declarada, ambos solo en la primera vez.

No tocar: *livelock*, *benchmark* y *routers* en redonda en pp. 92–93 son títulos
de la bibliografía.

**Commit:** `Rev2.3: declarar y cerrar el criterio de cursivas`

## Rev2.4 — Números, unidades y acrónimos

- [ ] Separador de millares con espacio fino (140 apariciones ya lo hacen bien):
      `anexoC.tex:200`, `cap3/entorno_desarrollo.tex:331` y
      `cap5/conclusiones.tex:11` → `4\,000\,000`;
      `anexoC.tex:274` y `cap5/conclusiones.tex:93` → `20\,188`.
- [ ] Porcentajes con espacio fino: `6%` en la tabla del presupuesto (convive con
      `15 %` en filas consecutivas) y `η ≥ 96%` en la figura 3.8. 39 ya están bien.
- [ ] Tabla 4.6 (p. 80): la cabecera escribe `115200 · 230400 · … · 1M · 2M · 4M`
      mientras la prosa de la misma página escribe «115 200», y dentro de la
      cabecera se mezclan cifra completa y sufijo M. Unificar a espacio fino, o
      dejarla compacta y decir la unidad en el pie. Lo que no vale es tener las
      dos notaciones en la misma fila.
- [ ] Repasar que todas las magnitudes lleven `\,` **no separable** y no se
      partan al final de línea: `1,8 V`, `120 Ω`, `100 µs`, `460 kbps`, `3,52 W`,
      `32 bits`, `4,7 nF`, `±2 %`, `120 ppm`. Valorar `siunitx`, que lo unifica y
      de paso fija la coma decimal.
- [ ] Añadir a `pre/acronimos.tex` las 23 ausencias, y desarrollarlas también en
      su primera aparición: TDEST (20 usos), TLAST (13), BER (8, ya está en la
      lista pero sin desarrollar en el cap. 4), RTL (5), TVALID/TREADY (5+5, solo
      en nota al pie de la p. 11), SPW (5), HPC (3), HP (3), BIF (3), SMP (2),
      SAR (2), TVS (2), WNS (2, es una columna de la tabla 4.1), SG (2), y las de
      un solo uso: RSB, EMC, LDO, CRC, IDE, GUI, QEMU, PYMES, MMIO — o se
      desarrollan en el sitio, o se sustituyen por el nombre completo.
- [ ] SLO está en la lista de acrónimos y no es un acrónimo. Decidir: o la sección
      pasa a «Lista de acrónimos y glosario», o SLO baja al texto (ya está
      explicado en §3.4.2 y §4.3.3).

**Commit:** `Rev2.4: numeros, unidades y lista de acronimos`

## Rev2.5 — Ortografía, gramática y Summary

El cuerpo técnico sale limpio con el corrector es_ES. Todo lo que queda está en el
capítulo 3 y en los agradecimientos.

- [ ] `semiperiodo` / `semiperiodos` → `semiperíodo` / `semiperíodos`, 7 veces
      (pp. 23, 24, 25×3, 29, 30). El documento ya usa «período» con tilde cinco
      veces; la palabra compuesta tiene que seguir a la simple.
- [ ] p. 9: «por periodo de bit» → «por período de bit».
- [ ] `pre/greetings.tex:24` — `examenes` → `exámenes`. La primera aparición del
      mismo párrafo ya está bien, lo que prueba que es errata.
- [ ] `pre/greetings.tex:15` — paralelismo roto: «he podido disfrutar…,
      empaparme… y **contado** con…» → «…y **contar** con vuestra ayuda…».
      La coma antes de la «y» sobra en una enumeración de tres.
- [ ] `pre/greetings.tex` — «han participado **de** este desarrollo» →
      «participado **en**». «Participar de» es compartir una opinión, no tomar parte.
- [ ] `pre/greetings.tex` — repetición: «Al resto de compañeros del laboratorio,
      por hacer del **laboratorio** algo más…» → «por hacer **de él** algo más…».
- [ ] `pre/resumen.tex` (Summary, p. ii) — «widen the development window» no
      significa nada en inglés; *window* se lee como ventana temporal. Propuesta:
      «…to extend its capabilities and broaden the range of interfaces that can be
      developed and tested on it».
- [ ] `pre/resumen.tex` — «analogue» es ortografía británica en un texto que no
      marca variedad. Decidir una y aplicarla en Summary y Keywords.

No tocar: «las cerves», «el buen rollo» y el registro coloquial de los
agradecimientos. Ni los falsos positivos del corrector (listados de código,
volcados de terminal, rótulos de Altium, nombres de directorio).

**Commit:** `Rev2.5: ortografia, agradecimientos y Summary`

## Rev2.6 — Correcciones de fondo señaladas por el tutor

Puntos de precisión, cada uno con una comprobación detrás.

- [ ] **p. 10** «La frase de proporciona queda rara o inconexa»: dos frases
      seguidas empiezan por «proporciona» en §2.5.3 (SpaceWire). Refundir.
- [ ] **p. 15** «¿Libro de instrucciones?» y «Ojo con esto, que no te pase como a
      Diego» sobre la máquina virtual del entorno de desarrollo. Añadir la nota de
      respaldo y reproducibilidad de la VM, y decidir si va aquí o en el anexo.
- [ ] **p. 53** La figura 3.17 (placa de comunicación serie soldada) no se cita en
      ningún sitio. Citarla con las otras dos.
- [ ] **p. 70** «¿Referencia exacta?»: la corrección de robustez del receptor se
      cita como «descrita en el Capítulo 3». Poner `\ref` a la subsección exacta.
- [ ] **p. 76** `cap4/benchmark.tex:19` — «Revisa ese J3». Confirmar que el
      conector de la ZCU102 usado para los canales adicionales es realmente J3.
- [ ] **p. 83** `cap4/benchmark.tex:485` — «Revisa ese factor de 4». Contrastar el
      «cuatro veces más pequeño en lógica» del GPIO con la tabla 4.1.
- [ ] **p. 86** «Esto no se ve en la tabla o gráfica»: se afirma que la diferencia
      del bus A se mantiene en la parte alta del barrido incluso con SLO=1, y los
      datos no lo enseñan. O se corrige la afirmación, o se marca en la tabla.
- [ ] **p. 89** `cap5/conclusiones.tex:42` — «¿Son 5 o 6?». Contar las funciones
      de la API pública en §3.5 y cuadrar la cifra.
- [ ] **p. 92** `biblio.bib:10` — «Antoniooooooo». El `.bib` dice «Jorge
      **Alejandro** Estefanía Hidalgo» y el PDF revisado imprimía «Jorge
      **Antonio**». Fijar el nombre correcto.
- [ ] **p. 95** `anexos/anexoA.tex:31` — falta un «de»: «conocimiento adquirido,
      por ejemplo cómo se sintetiza…» → «adquirido de, por ejemplo, cómo se
      sintetiza…».
- [ ] **p. 98** `anexos/anexoA.tex:145` — añadir la sigla junto al término:
      «*single event upsets* (SEU)». Ya está definida en `pre/acronimos.tex:117`.
- [ ] **p. 98** `anexos/anexoA.tex:164` — «Anexo~C» debe ser el Anexo B
      (presupuesto). Poner un `\label` y un `\ref` en vez de la letra a mano.

**Commit:** `Rev2.6: correcciones de precision y referencias cruzadas`

## Rev2.7 — Anexo A: legibilidad y respuestas de tribunal

El tutor firma el enfoque («me ha encantado, mis dieces») y pide trabajo de
redacción encima, no de contenido.

- [ ] **p. 96** «Suena un pelín a Claudia»: el párrafo del PERTE y la masa crítica.
      Reescribir con voz propia, frases más cortas y menos abstracción.
- [ ] **p. 96** «Separa en dos oraciones»: el párrafo del TFM como mecanismo de
      formación («Aplica conocimiento académico… y deja como resultado…»).
- [ ] **p. 96** «No se termina de entender en la primera pasada, largo y
      complicado»: el párrafo NewSpace/COTS/residuos. Reordenar y partir.
- [ ] **p. 96** «Ponlo el último entonces»: mover el apartado de consumo
      energético al final de la lista de impactos ambientales, ya que es el que se
      desarrolla en detalle a continuación.
- [ ] **p. 97** Marcar en negrita que el consumo es el apartado sobre el que
      inciden directamente las decisiones de diseño de este trabajo. El tutor lo da
      por buen criterio de ampliación.
- [ ] **p. 97** Pregunta de tribunal a dejar respondida en el texto: ¿qué caudal
      real va a haber? Si se envían pocas muestras por segundo y el canal no se
      satura, ¿sigue compensando el MCDMA? ¿Se ha medido? La tabla de energía por
      byte responde a media pregunta; conviene cerrarla de forma explícita.
- [ ] **p. 97** Matizar la conclusión de «menos satélites o más pequeños»: el
      margen liberado vale si por las interfaces viaja tráfico sostenido. Decir que
      la plataforma se diseña sin fijar si servirá para telemetría, carga de pago o
      ambas.
- [ ] **p. 98** «Troppo longo, recorta»: el apartado de limitaciones del análisis.

**Commit:** `Rev2.7: reescribir el anexo etico para legibilidad`

## Rev2.8 — Figuras y maquetación

Al final a propósito: T1, `\appendix` y los cambios de prosa mueven la paginación.

- [ ] **p. 3** Figura 1.1 (metodología ágil): «se lee muy mal». Letra más grande,
      o un diagrama más básico que muestre el proceso de pensar más que la
      herramienta. `IMG/Desarrollo/diagrama_metodologia_agil.tex`
- [ ] **p. 5** Añadir una foto de la ZCU102.
- [ ] **p. 6** Figura 2.1: señalar los puertos AXI con una flecha grande o un
      recuadro. Tal como está, el lector no encuentra lo que el texto le pide mirar.
- [ ] **p. 9** Figura de topologías RS: texto más grande, y valorar partirla en dos
      para facilitar el salto de página. `IMG/Desarrollo/diagrama_topologia_rs.tex`
- [ ] **p. 9** §2.5.3: añadir una mini figura muy ancha y corta que ilustre
      SpaceWire. El tribunal no lo ha visto nunca.
- [ ] **p. 11** Figuras de AXI: «de 10», pero agrandar el texto pequeño sin
      aumentar el alto. `diagrama_axi_full/lite/stream.tex`
- [ ] **p. 12** Figura 2.6 (DMA): muy pequeña. `IMG/Desarrollo/diagrama_dma.tex`
- [ ] **p. 13** Figura 2.7 (MCDMA): ídem, y añadir un diagrama del coste de la
      interrupción en §2.6.3. Adelanta trabajo de la presentación.
- [ ] **pp. 45, 50** Esquemáticos: recortar al bloque de interés en vez de la hoja
      completa, para que se vean más grandes. «Aquí y en las demás».
- [ ] **p. 49** Fondo blanco en el render 3D de la placa AOCS (prioridad baja).
- [ ] **p. 54** Cajas de código sobre fondo blanco (configuración de RTEMS):
      «me tienden a decir poco». Resumir o pasar a tabla.
- [ ] **p. 56** Figuras de arneses: juntarlas y recortar la imagen.
- [ ] **p. 64** Convertir a tabla la comparativa de interrupciones por kilobyte y
      coste en lógica de las tres variantes. «¿Tablita?»
- [ ] **p. 71** Figuras 4.2 (flancos con y sin limitador de slew rate): el tutor
      las da por buenas, no tocar.
- [ ] **p. 72** Figuras 4.3 y 4.4 (CAN con y sin terminación): ponerlas en
      paralelo; aunque queden más pequeñas, la diferencia se ve.
- [ ] **p. 73** Listado 4.2 (barrido del ADC): los saltos de línea cortan la salida
      del terminal. Bajar el tamaño y reducir espacios para que cada línea entre
      entera.

**Commit:** `Rev2.8: figuras, esquematicos y maquetacion`

## Rev2.9 — Presupuesto (Anexo B)

- [ ] **p. 100** «La única trampa que te imputaría»: se usan costes reales de
      personal, pero el precio de las licencias de Vivado ML Enterprise y Altium
      puede estar por encima del real. Las educativas y las de servidor, como las
      que se usan aquí, salen más baratas por puesto. Justificar la fuente del
      precio o cambiar a la tarifa que corresponde, y decirlo en el texto.

**Commit:** `Rev2.9: justificar el coste de licencias del presupuesto`

## Rev2.10 — Compilación y verificación final

- [ ] Compilar de cero y comprobar: cero `??`, índice, índice de figuras, índice de
      tablas e índice de listados correctos.
- [ ] Anexos rotulados A, B, C, con tablas A.x/B.x/C.x y listados C.x.
- [ ] Repasar las seis comillas ya como `«»` reales, y la cita del LTC2865 de la
      p. 85 como `quote` sangrado en vez de entrecomillada.
- [ ] Regenerar el PDF y comprobar los folios citados en este plan.

**Commit:** `Rev2.10: regenerar el PDF con la revision Rev2 aplicada`

---

## Pendiente para la siguiente pasada (no entra aquí)

El HTML anuncia una pasada 3 de **alcance**: qué se poda del cuerpo y qué se va a
los anexos, con §3.1 y las cinco hojas de esquemático a página completa como
candidatos. Y detrás, el hilo narrativo y la ordenación temporal.
