# Revisión Rev1 del tutor — plan de trabajo

Origen: `Rev1_mem_jae.pdf` (120 páginas, 77 anotaciones).
Offset de páginas PDF → página del documento: **−17**.

Orden de las pasadas pensado para no rehacer trabajo: primero mover, luego corregir
hechos, luego escribir, luego dibujar, luego maquetar. Cada pasada es un commit.

Aviso de nomenclatura: los ficheros de anexo están cruzados con sus rótulos.
`anexo1.tex` es el Anexo A, `anexoA.tex` es el Anexo B y `anexoB.tex` es el Anexo C.

---

## Pasada 1 — Reordenar y renombrar (estructura)

Solo `main.tex` y títulos. Nada de prosa.

- [x] p115. Anexo ético y presupuesto pasan delante del resto. `main.tex:271-282`
- [x] Renombrar los ficheros de anexo para que coincidan con su rótulo
- [x] p21. `1.4 Estructura de la memoria` → «Estructura de la memoria y documentación»,
      y subir el `\section` un par de párrafos. `capitulos/cap1/intro.tex`
- [x] p20. Partir `1.3 Metodología`: lo cronológico a subsección propia
      («Planificación temporal») o al anexo
- [x] p30. Título con forma rara en 3.1.3. `capitulos/cap3/entorno_desarrollo.tex:46`
- [x] Compila sin `??` y con índice correcto

## Pasada 2 — Mover material a anexos (volumen)

Corte, no reescritura. El texto se mueve tal cual y queda una frase de enlace con `\ref`.
Regla: en el cuerpo, el resultado y la figura; en el anexo, la tabla exhaustiva.

- [x] p34. 3.2 Diseño del transceptor: el detalle RTL fino (registro de desplazamiento,
      FIFO) al anexo. `capitulos/cap3/entorno_desarrollo.tex:282`
- [x] p81. 4.1.2 Comunicaciones serie RS422/RS485: tablas de barrido completas al anexo.
      `capitulos/cap4/validacion_hardware.tex`
- [x] p86. 4.1.5 PWM (calentadores): igual que el anterior

## Pasada 3 — Correcciones técnicas y de precisión

- [x] **p51.** «Catálogo cualificado» está mal usado. Cualificado es el rad-hard caro;
      en New Space se usan componentes de catálogo no cualificados oficialmente, con
      herencia de vuelo. El tutor marca además «te estás haciendo un poco de lío».
      `capitulos/cap3/entorno_desarrollo.tex:1232`
- [x] p22. FPGA sin adjetivo de tipo; añadir «reconfigurable»
- [x] p22. Xilinx → «Xilinx (hoy AMD)»
- [x] p22. Definir las siglas en su primera aparición, no solo en el glosario
- [x] p24. «de 2 a más de 400» → «de hasta 400 nodos»
- [x] p25. Falta el término «memoria DDR»
- [x] p34. Siglas sin explicar: «¿de bus?», «¿es CRC?», «¿esto lo has explicado?»
- [x] p51. Aclarar «(voltaje de bus)»
- [x] p52. Erratas: «ningun» → «ningún»; «ruteado» → «rutado» (dos veces)
- [x] p71. «catorce» → «14×». `capitulos/cap3/transporte.tex:65`
- [x] p102. «¿A qué te refieres?» en conclusiones: desambiguar
- [x] p23. «¿A qué te refieres con propios?»

## Pasada 4 — Reescribir lo que suena a texto generado

Reescritura desde cero, no parafraseo. Síntomas a cazar: tricolon
(«no solo…, sino…, sino también»), listas de tres adjetivos, frases de cierre
valorativas, conectores de relleno.

- [x] p27. Final de 2.6. `capitulos/cap2/transporte.tex`
- [x] p52. Final de 3.5.1 y apertura de 3.5.2.
      `capitulos/cap3/entorno_desarrollo.tex:1275`
- [x] p105. Líneas futuras: hay cosas listadas que ya están hechas o que van mucho más
      allá de una línea futura, como la DDR. Separar lo hecho de la línea futura real.
      `capitulos/cap5/lineasfuturas.tex`
- [x] Añadir esta categoría a `GUIA_ESTILO_TFM.md`

## Pasada 5 — Motivar al lector

La nota más repetida en espíritu. p22 la resume: que el lector sepa para qué se le
cuenta cada cosa antes de leerlo.

- [x] p22. Frase de para-qué al abrir cada bloque teórico del capítulo 2. Ejemplo en
      2.2: el OBC del satélite se construye sobre este MPSoC
- [x] p66. Intro para 3.6 Desarrollo de herramientas de testing.
      `capitulos/cap3/entorno_desarrollo.tex:1765`
- [x] p30. «¿Qué pretendes que vea el lector cuando llegue a esto?» y «¿dónde? ¿yo
      puedo verlo?»: o se explica qué mirar, o se quita
- [x] p6. En el resumen: la primera placa prueba los RS, las otras dos responden a las
      necesidades del OBC flat-sat. `pre/resumen.tex`
- [x] p6. Quitar el número de líneas de código del resumen
- [x] p23. Mencionar la contrapartida: mayor curva de aprendizaje y complejidad a
      cambio del control
- [x] p28. Responder de forma explícita a «¿en tu caso, habrías podido hacerlo?»
- [x] p115. Ampliar el impacto socioeconómico: por qué se persigue empleo cualificado,
      dificultad de generarlo y retenerlo, y que estos programas buscan abrir una
      industria en España que después se sostenga sola

## Pasada 6 — Estilo y registro

Barrido mecánico sobre todo el documento. Extiende `GUIA_ESTILO_TFM.md`.

- [x] p28, p46. Frases largas: ninguna oración de más de dos líneas. Buscar párrafos
      con punto y coma. Prioridad en 3.1, 3.2.8 y 3.5
- [x] p6, p29, p47, p52. Tiempos verbales: pasado para el trabajo realizado, presente
      para describir lo que existe. Capítulo a capítulo
- [x] p18, p27, p15. Formalidad: p27 «no me grites» (mayúsculas y negritas), p18 «poco
      formal», p15 agradecimientos
- [x] p25. Notas al pie: deben ampliar, no ser imprescindibles para seguir la línea.
      Subir al cuerpo la que haga falta para entender el texto
- [x] p28. «¿Merece la pena poner los nombres completos?»: abreviar
- [x] p23, p30. Puntuales: «dale una vuelta a esta frase», «¿el qué?», «¿muy bajo nivel?»
- [x] p19. Ironía del tutor sobre una obviedad: «Durante la reunión los participantes
      se turnan para hablar». Eliminar la frase, o sustituirla por información real de
      la reunión (quién asiste, qué rol tiene cada parte).
      `capitulos/cap1/intro.tex:94`
- [x] p19. De paso, unificar `	extit{Sprint}` / `sprint` / `sprints` en el mismo párrafo

## Pasada 7 — Figuras y diagramas

La nota más repetida en número. Se hace después del texto, cuando ya se sabe qué hay
que dibujar. Mismo estilo TikZ que `IMG/Desarrollo/diagrama_arquitectura_mcdma.tex` y
`diagrama_transceptor.tex`.

- [x] p22. Imagen del MPSoC Zynq / ZCU102
- [x] p24. RS485 y RS422: topología multipunto frente a punto a punto
- [x] p25. Diagrama del bus AXI
- [x] p26. Diagrama del DMA
- [x] p26. Diagrama del interior del bloque
- [x] p19. Diagrama de scrum/kanban
- [x] p54. 3.5.4 placa CDHS: diagrama de bloques en vez de imagen
- [x] p69. Sustituir la foto real grande por un esquemático

## Pasada 8 — Maquetación

Solo tras compilar con el texto ya estable.

- [x] p44. Página en horizontal (`pdflscape`, `\begin{landscape}`)
- [x] p73. Página en horizontal
- [x] p53. Figura al límite de utilidad por tamaño y disposición: recolocar o ampliar
- [x] p71. Trazo «más fino» en una figura
- [x] Revisar `[H]` → `[htbp]` donde el recorte de las pasadas 2 y 6 deje huecos
      (`GUIA_ESTILO_TFM.md` §6)

## Pasada 9 — Blindaje frente a tribunal

Lectura final con ojos de tribunal, no de autor.

- [x] p24. «Si fuese tribunal te pincharía con esto y lo de debajo»: la afirmación no
      se ve clara de primeras. Añadir la justificación o el dato que la sostiene
- [x] p30. «¿Dónde? ¿Yo puedo verlo?»: dar referencia verificable
- [x] p27. «Esta es la clave de todo»: comprobar que está destacado y no enterrado
- [x] p102. Releer las conclusiones contra los objetivos del capítulo 1

---

## Ya está bien, no tocar

- p120. «Cortita y al pie, me encanta, muy bien explicado»
- p115. «Mejorable pero pasable, dale otra vuelta cuando tengas listo lo demás».
  Prioridad baja, al final de todo

---

## Notas de ejecución (sesión del 1 de septiembre de 2026)

Las anotaciones del PDF se extrajeron con su texto subrayado. Tres puntos del plan
partían de una lectura equivocada de la nota:

- **p24, «de 2 a más de 400»**: la nota está sobre la velocidad de SpaceWire en Mbps,
  no sobre el número de nodos de un bus. Corregido como «de hasta 400 Mbps».
- **p71, «más fino»**: la nota está sobre el texto «El enfoque no escala», no sobre el
  trazo de una figura. Pedía precisar la afirmación, y así se ha hecho.
- **p44 y p73**: las dos páginas ya estaban en horizontal con `sidewaysfigure`.

Otros ajustes sobre el plan:

- **p86 (PWM, calentadores)**: no hay ningún volcado exhaustivo que mover al anexo, solo
  figuras de osciloscopio. No aplica.
- **p6, número de líneas de código**: ese dato no aparecía en el resumen. No aplica.
- **p15, agradecimientos**: la frase que el tutor marca no está en `pre/greetings.tex`
  sino en la entrada GPIO de `pre/acronimos.tex`. Corregida ahí.
- **p86 (PWM, calentadores)** y **p6 (número de líneas de código)**: comprobado que no
  aplican; el detalle correspondiente no existía en el texto.
- **p19, información real de la reunión**: se optó por eliminar la frase de la obviedad.
  Queda por decidir si se sustituye por quién asiste a la reunión y con qué rol.
- **p50, «Piensa en mencionar»**: la nota está sobre el título del apartado 3.5 y no dice
  qué mencionar. Pendiente de aclarar con el tutor.
