# Guía de estilo y registro del TFM

Documento de referencia para homogeneizar la redacción de la memoria. Recoge las
decisiones acordadas durante la revisión, para aplicarlas al resto de secciones y
poder revisarlas después.

> **Principio general.** Escribir como una memoria técnica: exponer los hechos de
> forma cerrada, natural y estructurada. **No** narrar el trabajo como una aventura
> ni contar el orden en que se descubrieron las cosas. Se cuenta *qué es* y *cómo se
> comporta*, no *cómo lo averiguamos*.

---

## 1. Títulos de secciones y subsecciones

- **Cerrados y descriptivos**: el título nombra el contenido, no anticipa la trama
  ni hace preguntas.
- **Evitar los dos puntos narrativos** y las formas conversacionales.
- **Evitar títulos que suenen a capítulo de novela** o a numeración informal.

| Evitar | Preferir |
|---|---|
| `Los nueve tests` | `Batería de pruebas de caracterización` |
| `El hallazgo principal: el limitador de slew estaba activo por defecto` | `Efecto del limitador de slew rate sobre la velocidad máxima` |
| `Discusión: qué arquitectura y por qué` | `Selección de la arquitectura de transporte` |
| `Salvedades del método` | `Limitaciones del método de medida` |

---

## 2. Estructura del discurso: hechos, no descubrimientos

- **Abrir con el hecho técnico**, no con el suceso. Un resultado se presenta como un
  dato medido, no como una sorpresa.
- **No usar la estructura de "descubrimiento"**: nada de "resultó que…", "sin que
  nadie lo supiera", "descubrimos que al activar X se desbloqueaba Y".
- Cuando el comportamiento venga fijado por una fuente (datasheet, norma), **citarla
  como causa** y mostrar que la medida es coherente con ella.

**Ejemplo — apartado del slew rate:**

- *Antes (descubrimiento):* «El resultado más relevante es que la placa venía
  funcionando con el limitador activado sin que nadie lo supiera, y que desactivarlo
  multiplica por cuatro la velocidad.»
- *Después (hecho):* «El pin `SLO` del LTC2865 es activo a nivel bajo: con 0 (por
  defecto) el limitador está activo y limita a 250 kbps; con 1 se desactiva. Las
  medidas se obtuvieron con el limitador desactivado (SLO = 1); en esa configuración
  los tres buses operan a 4 Mbps. El efecto se observa en las pruebas (fig. …).»

---

## 3. Registro y voz

- **Tono expositivo y sobrio**. Eliminar lo efectista y coloquial.
- **Sin dramatización ni valoraciones de guion**: no "y era mentira", "no era una
  optimización, era la única vía", "requisito que no se puede saltar".
- **Sin verbos coloquiales** cuando hay uno técnico: `capar` → `limitar`; `topar` →
  `alcanzar el límite`; `desbloquear velocidad` → `alcanzar mayor velocidad`.
- **Litotes por afirmación clara**: `un solo error/byte` → `ningún error/byte`.
- Mantener negritas para las cifras/resultados clave, pero sin abusar del énfasis
  retórico.

| Evitar | Preferir |
|---|---|
| «…y era mentira.» | «…daba los buses B y C como defectuosos de forma incorrecta.» |
| «la PCB sería sencillamente invisible» | «la PCB no intervendría en la medida» |
| «capa el driver a 250 kbps» | «limita el driver a 250 kbps» |
| «el bus topa en 460 kbps» | «el bus alcanza 460 kbps» |
| «no era una optimización, era la única vía» | *(reformular como conclusión razonada)* |

---

## 4. Concisión: eliminar relleno

La memoria ya es extensa; se prioriza recortar sin perder información técnica.

- **No abrir una sección recordando lo que hacía la anterior.** Entrar directamente
  en el objeto de la sección. Los "puentes narrativos" entre secciones/subsecciones
  se podan.
  - *Ejemplo eliminado:* «La comparativa de la sección anterior mide el transporte…
    Esta sección mide otra cosa distinta…» → sustituido por entrada directa: «Esta
    sección caracteriza la placa de comunicación serie de diseño propio.»
- **No repetir el contexto** ya establecido en el capítulo.
- Preferir una explicación técnica compacta (una cita del datasheet + una frase de
  coherencia) frente a varios párrafos interpretativos.

---

## 5. Contenido técnico: qué NO se toca

El cambio es de **registro, titulación y longitud**, no de rigor:

- Se conservan **cifras, tablas, figuras, labels y código** intactos.
- Se conservan las **explicaciones físicas** (por qué un bus multipunto topa antes,
  coherencia con el nominal del chip, etc.).
- No se reduce la profundidad del análisis; se reduce la palabrería que lo rodea.

---

## 6. Formato / LaTeX

- **Figuras `[H]` vs. `[htbp]`**: al recortar texto, una figura clavada con `[H]`
  puede quedar sin sitio y dejar un gran hueco vertical (fuerza la figura a la página
  y deja el resto en blanco). Solución: cambiar esas figuras concretas a `[htbp]`
  para que floten y el texto rellene. Revisar tras compilar cada capítulo.
- La **separación entre párrafos** (espacio vertical, sin sangría de primera línea)
  es el estilo del documento y es correcta: **no** tocarla puntualmente.

---

## Registro de cambios ya aplicados

- `capitulos/cap4/pcb.tex` — revisión completa de registro, títulos y concisión;
  reducción del apartado del slew rate a la explicación del hardware + efecto medido;
  figuras del slew rate a `[htbp]`.
- `capitulos/cap4/benchmark.tex` — título «Selección de la arquitectura de transporte»;
  eliminadas las aperturas efectistas («Los números hablan por sí solos», «La prueba más
  reveladora de todas»), la frase «no era una optimización, era la única vía» y los
  «menos/más es mejor» repetidos; tabla de síntesis a `llll` + `\small` para evitar el
  cortado de palabras en las columnas.
- `capitulos/cap4/validacion_hardware.tex` — «dejó al descubierto» y «conviene advertir»
  reescritos como hecho medido.
- `capitulos/cap3/transporte.tex` — entrada directa de la sección; títulos «Lo que se
  aprendió: el precio de replicar», «Camino de transmisión: …», «El driver: …» cerrados;
  poda de la narrativa de depuración («no funcionó a la primera», «un último aprendizaje…
  merece mención», moralejas finales).
- `capitulos/cap3/entorno_desarrollo.tex` — apartado del flujo de desarrollo reescrito como
  hechos (fuera «costó bastante tiempo», «resultaba tedioso», «apareció un segundo
  problema»); «trampa que se destapó» del pin SLO convertida en dato del datasheet; títulos
  con dos puntos cerrados; «Decisiones de diseño destacadas» → «Decisiones de diseño».
- `cap2/transporte.tex` y `cap5/conclusiones.tex` — litotes «un solo byte/error» →
  «ningún byte/error».
- `cap5/conclusiones.tex` — el párrafo del slew rate estaba escrito como descubrimiento
  («sin que nadie lo supiera», «capado», «el hardware no estaba mal»), justo el ejemplo
  de la sección 2 de esta guía; reescrito como hecho, igual que en `cap4/pcb.tex`.
- Barrido final de «conviene señalar/advertir/declarar», «resultó ser», «a la primera» y
  «merece la pena» sobre los cinco capítulos y los tres anexos.

## Pendiente de aplicar

- Nada abierto de esta guía. Al añadir texto nuevo, revisar contra las secciones 1--6 y
  anotar aquí lo que quede pendiente.
