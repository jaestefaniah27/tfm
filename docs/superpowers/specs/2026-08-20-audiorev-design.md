# AudioRev: escucha y revisión hablada del TFM

**Fecha:** 2026-08-20
**Estado:** diseño aprobado, pendiente de implementación
**Autor:** Jorge A. Estefanía Hidalgo

## 1. Problema

La memoria del TFM tiene unas 39.000 palabras repartidas en 13 ficheros `.tex`.
Revisarla leyendo en pantalla es lento y se pierde la concentración. Se necesita
poder escucharla entera desde el móvil, en trayectos o paseando, e ir marcando lo
que hay que cambiar sin sentarse a escribir. Las anotaciones deben volver después
al agente para aplicarlas sobre el LaTeX.

### Objetivos

1. Escuchar la memoria completa en unidades cortas, en cualquier sitio, desde el móvil.
2. Anotar una revisión anclada a la frase exacta que se está oyendo, con el mínimo
   de fricción posible.
3. Que el agente recoja esas revisiones y las aplique sobre el fichero y la línea
   correctos.
4. Que el ciclo se pueda repetir muchas veces conforme la memoria evoluciona, sin
   coste creciente.

### No objetivos

- Editar el LaTeX desde la web. Las notas describen qué cambiar; el cambio lo hace
  el agente sobre el repositorio.
- Sustituir la revisión visual. Los bloques que no son prosa (código, tablas,
  figuras) se muestran en pantalla, no se leen en voz alta.
- Multiusuario, colaboración o comentarios de terceros. Un solo usuario.

## 2. Material de partida

Medido sobre el repositorio el 2026-08-20:

| Magnitud | Valor |
|---|---|
| Ficheros `.tex` de contenido | 13 (5 capítulos + 3 anexos) |
| Palabras totales | 38.980 |
| Apartados (`\section` y `\subsection`) | ~137 |
| Media por apartado | ~285 palabras, ~2 min de audio |
| Duración total estimada a 160 ppm | ~4 h 05 min |
| Acrónimos ya catalogados en `pre/acronimos.tex` | 73 |
| Bloques visuales (`lstlisting`, `tabular`, `figure`, `axis`) | 83 |
| Etiquetas resolubles en `main.aux` (`\newlabel`) | 81 |

El fichero más denso es `capitulos/cap3/entorno_desarrollo.tex`: 14.959 palabras,
41 apartados y 28 bloques visuales. Es el piloto.

## 3. Decisiones de arquitectura

### 3.1 Síntesis por frase, entrega concatenada

Se sintetiza **frase a frase**. Cada frase produce un `.wav` guardado en una caché
indexada por el hash de su texto normalizado. Después `ffmpeg` concatena las frases
de un apartado en un único `.opus` y se emite un JSON con los puntos de corte.

Consecuencias, que son la razón de elegirlo:

- **Los tiempos salen gratis.** El inicio de la frase *n* es la suma de las
  duraciones anteriores. No hace falta alineación forzada ni un modelo aparte.
- **Regeneración incremental.** Si cambia un párrafo, solo se re-sintetizan las
  frases cuyo hash cambió y se vuelve a concatenar el apartado. Editar la memoria
  no obliga a regenerar cuatro horas de audio.
- **Motor intercambiable.** Todo el TTS queda detrás de una función
  `synth(texto: str) -> bytes`. Cambiar de motor no toca el resto del sistema.
- **Un solo elemento de audio** por apartado: reproducción sin huecos, seek nativo,
  controles en la pantalla de bloqueo y descarga offline con una sola petición.

Alternativas descartadas: un fichero monolítico por apartado, que imposibilita el
resaltado por frase, y una petición HTTP por frase, cuya reproducción encadenada es
frágil en el móvil y depende de la red.

### 3.2 Motor TTS

Por defecto **Piper** local, voz `es_ES-davefx-medium`, sobre CPU y sin coste. El
motivo es que la memoria se va a regenerar muchas veces durante la revisión, y un
coste por regeneración introduce fricción justo donde no debe haberla.

Limitación conocida y aceptada: la prosodia de Piper es plana y cansa en sesiones
largas. Mitigaciones previstas:

1. Control de velocidad de 0,8x a 2,0x en el reproductor.
2. Backend seleccionable por la variable de entorno `AUDIOREV_TTS_BACKEND`.
   Escalones previstos: `piper` por defecto, `kokoro` (ONNX en CPU, mejor prosodia,
   sin coste) y `cloud` (OpenAI, ElevenLabs o Google).

Gracias a la caché por hash, pasarse a un motor de pago más adelante solo cuesta la
primera pasada completa.

### 3.3 Anclaje de las revisiones

Es el punto crítico del sistema. Cada nota guarda:

| Campo | Contenido |
|---|---|
| `unit_id` | Identificador estable del apartado, por ejemplo `c03-entorno-nco` |
| `sentence_idx` | Índice de la frase dentro del apartado |
| `sentence_hash` | Hash del texto normalizado de la frase |
| `sentence_text` | Copia literal de la frase en el momento de anotar |
| `tex_file` | Ruta relativa del `.tex` de origen |
| `tex_line` | Línea aproximada dentro de ese fichero |
| `audio_ts` | Segundo del audio en que se anotó |
| `tags` | Etiquetas rápidas seleccionadas |
| `comment` | Texto libre, dictado o escrito |
| `state` | `pendiente`, `aplicada`, `descartada` u `obsoleta` |

Al aplicar una revisión, el agente **busca por `sentence_text`, no por
`tex_line`**. Los números de línea se desplazan con cada edición; el texto literal
de la frase es un ancla mucho más fiable. `tex_line` sirve solo como pista para
acotar la búsqueda. Si la frase ya no aparece en el fichero, la nota se marca
`obsoleta` y se avisa, en lugar de editar a ciegas.

Los `unit_id` son estables por construcción: se derivan del capítulo y de un slug
del título del apartado, no de su posición. Reordenar la memoria no invalida las
notas.

## 4. Conversor de LaTeX a guion hablado

Es la parte con más trabajo real y de la que depende que el sistema sirva de algo.
Vive en `tools/audiorev/` y se ejecuta igual en el PC que en el servidor.

### 4.1 Etapas

**1. Expansión.** Partiendo de `main.tex`, se resuelven las órdenes `import` e
`input` para obtener el orden canónico del documento. Se conserva para cada
fragmento su origen, es decir, el fichero y la línea.

**2. Estructuración.** El documento se parte en unidades por `\section` y
`\subsection`. El capítulo se toma de `main.tex`, que es donde están los
`\chapter`. Cada unidad recibe un `unit_id` estable y hereda la ruta de su `.tex`.

**3. Normalización para la voz.** Reglas, en orden de aplicación:

| Elemento | Tratamiento |
|---|---|
| Comentarios de LaTeX | Se eliminan |
| `\textit`, `\textbf`, `\emph` | Se sustituyen por su contenido |
| `\texttt{...}` | Contenido plano; los guiones bajos se leen como pausa breve, no como «guion bajo» |
| Acrónimos | Deletreo fonético desde el diccionario: `AOCS` pasa a «a o ce ese» |
| Unidades y números | `1,8 V` pasa a «uno coma ocho voltios»; `MHz` a «megahercios» |
| `\ref{...}` | Se resuelve contra `main.aux` y da «la figura 4.2» o «la tabla 3.1» |
| `\cite{...}` | Se omite |
| `\footnote{...}` | Se extrae y se lee al final del párrafo, precedida de «nota al pie» |
| Matemática en línea | Traducción de los casos simples; si es compleja, «fórmula, ver documento» |
| Matemática destacada | «ecuación N, ver documento» |

El diccionario de pronunciación vive en `tools/audiorev/dic/pronunciacion.yml`. Se
siembra automáticamente a partir de los 73 acrónimos de `pre/acronimos.tex` y se
corrige a mano cuando algo suena mal al escucharlo. Es un activo de primera clase
del proyecto, no un detalle de implementación.

**4. Bloques visuales.** Los 83 bloques que no son prosa no se leen. En su lugar:

- El audio contiene un marcador corto: «tabla 4.2, mapa de registros, en pantalla».
- El índice JSON registra el bloque con su tipo, su caption y su contenido.
- La interfaz inserta en ese punto exacto del texto una **tarjeta plegable** con el
  contenido renderizado: el código con formato, la tabla como HTML, la figura como
  imagen.
- Se puede anotar sobre la tarjeta igual que sobre una frase.

Esto cubre el tercio de la memoria que no es prosa en lugar de saltárselo.

Para las figuras, la primera versión muestra el caption y la ruta esperada. El
renderizado de las que provienen de TikZ y de `pgfplots`, que exige recortar del
`main.pdf` o compilarlas por separado, queda para una fase posterior.

**5. Segmentación en frases.** Con `pysbd` en modo español, más una lista de
abreviaturas propias del documento para no partir en «p. ej.», «fig. 4.2» o
«1,8 V».

### 4.2 Salida

Un JSON por apartado, versionado en git porque es pequeño y su historial interesa:

```json
{
  "unit_id": "c03-entorno-nco",
  "chapter": 3,
  "title": "Oscilador controlado numéricamente (NCO)",
  "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
  "tex_lines": [326, 402],
  "duration_s": 168.4,
  "sentences": [
    {
      "idx": 0,
      "text": "El NCO genera la referencia de reloj del transceptor.",
      "spoken": "El e ne ce o genera la referencia de reloj del transceptor.",
      "hash": "a1b2c3",
      "tex_line": 328,
      "t_start": 0.0,
      "t_end": 3.9
    }
  ],
  "blocks": [
    {
      "after_sentence": 12,
      "type": "table",
      "caption": "Tabla de frecuencias del NCO",
      "ref": "tab:nco",
      "html": "<table></table>"
    }
  ]
}
```

## 5. Aplicación web

### 5.1 Stack

**FastAPI, SQLite y una PWA en JavaScript sin cadena de compilación**, en un
contenedor detrás del reverse proxy que ya está en servicio.

El motivo de esta elección: `tools/` del repositorio ya es Python, así que el
conversor y el servidor comparten lenguaje y dependencias; no hay paso de
compilación que mantener; y SQLite es un único fichero que se copia para respaldar.

### 5.2 Autenticación

Un solo usuario. Contraseña almacenada con hash Argon2, cookie de sesión firmada
con los atributos `HttpOnly`, `Secure` y `SameSite=Lax`, con caducidad de 30 días
para no tener que reautenticarse en cada trayecto. Límite de intentos en `/login`.

Si en el servidor ya hay un portal de autenticación como Authelia o Authentik, se
delega en él y la aplicación no gestiona credenciales: confía en la cabecera de
usuario que inyecta el proxy y no expone `/login`.

La API que consume el agente usa un token *bearer* distinto de la sesión web,
guardado en una variable de entorno.

### 5.3 Pantallas

**Lista de tareas.** Capítulos plegables con sus apartados. Por apartado: título,
duración, estado (pendiente, en curso, escuchado, con notas) y número de notas.
Arriba, progreso global en tiempo, «2 h 10 min de 4 h 05 min», y un botón para
seguir donde se dejó.

**Reproductor.** Texto completo del apartado, desplazable, con la frase en curso
resaltada y autoscroll. Las tarjetas visuales aparecen embebidas en su posición.
Controles grandes: reproducir y pausar, saltar 10 s, frase anterior y siguiente,
velocidad, y el botón de anotar. Se integra con la Media Session API para que
funcionen los controles de la pantalla de bloqueo y el botón de los auriculares.
Wake lock opcional mientras se sigue el texto en pantalla.

**Hoja de notas.** Se abre desde abajo al pulsar anotar. Pausa el audio
automáticamente, muestra la frase anclada, ofrece una fila de etiquetas de un toque
(«muy largo», «no se entiende», «repetido», «falta dato», «reescribir») y un campo
de texto que se puede rellenar con el dictado nativo del móvil. Al guardar, la
reproducción continúa donde estaba.

**Cierre de sesión.** Lista de las notas de la sesión, editables y borrables, y un
botón para enviar las revisiones que dispara la escritura en el repositorio.

### 5.4 Funcionamiento sin cobertura

Un service worker precachea el audio y el índice de los apartados marcados para
descarga. Permite escuchar en el metro o en zonas sin datos. Las notas creadas
estando sin red se encolan en IndexedDB y se sincronizan al recuperar conexión.

## 6. Generación y despliegue

Modelo **híbrido**:

- El servidor mantiene un clon del repositorio. Un webhook de GitHub, o un `git
  pull` periódico como alternativa, detecta los cambios y lanza la regeneración
  incremental: solo se re-sintetizan las frases cuyo hash cambió.
- Existe además un endpoint `POST /api/regenerar` protegido por token, que permite
  forzar la regeneración a mano desde el PC o desde el móvil.

El audio **no se versiona en git**: cuatro horas ocupan del orden de 150 a 250 MB.
Vive en un volumen del servidor con su propia copia de seguridad. En git solo van
los JSON de índice, que son pequeños y cuyo historial sí resulta útil.

## 7. Vuelta al agente

Se implementan los dos caminos, que se complementan.

**Camino git.** Al cerrar una sesión, el servidor escribe en su clon
`revisiones/AAAA-MM-DD-sesion-NN.md`: un documento legible con una entrada por
nota, cada una con su bloque de metadatos de anclaje, y hace commit y push con una
deploy key. Desde el móvil basta con pedirle al agente que aplique las
revisiones pendientes: hace pull y ya las tiene, sin depender de que el servidor
esté accesible en ese momento.

**Camino API.** `GET /api/revisiones?estado=pendiente` devuelve las notas en JSON y
`POST /api/revisiones/{id}/estado` permite marcarlas como aplicadas o descartadas.
Así el estado no se bifurca entre el repositorio y la base de datos del servidor.

**Cierre del bucle.** Cuando el agente hace push del `.tex` corregido, el
servidor detecta el cambio, recalcula los hashes, marca automáticamente como
resueltas las notas cuya frase ya no existe y regenera solo esas frases.

Las revisiones se aplican respetando `GUIA_ESTILO_TFM.md` y las convenciones ya
fijadas para la memoria.

### Seguridad de la deploy key

La deploy key del servidor tiene permiso de escritura y está restringida a este
repositorio. El proceso automático solo escribe bajo `revisiones/` y nunca toca
`plantilla_tft_etsit/`. Si esto resulta demasiado permisivo, se puede desactivar el
push y dejar únicamente el camino de la API, haciendo el pull a mano.

## 8. Estructura en el repositorio

```
tools/audiorev/
  parse.py            expansión de import e input, y estructura del documento
  speak.py            normalización de LaTeX a texto hablado
  segment.py          segmentación en frases
  tts.py              backends de síntesis tras una interfaz común
  build.py            orquestador: del repositorio al índice JSON y al audio
  dic/pronunciacion.yml
server/
  app/                FastAPI: rutas, modelos y autenticación
  static/             PWA: HTML, CSS, JS y service worker
  Dockerfile
  compose.yml
  README.md           despliegue, variables de entorno y respaldo
docs/audiorev/
  PLAN.md             plan de implementación por fases
docs/superpowers/specs/
  2026-08-20-audiorev-design.md
revisiones/           salida de las sesiones de escucha
```

## 9. Fases

| Fase | Contenido | Criterio de aceptación |
|---|---|---|
| F0 | Esqueleto FastAPI, autenticación y despliegue con tres apartados sintetizados a mano | Se accede desde el móvil por HTTPS y suena un apartado |
| F1 | Conversor de LaTeX a guion sobre `cap3` y diccionario sembrado desde `acronimos.tex` | El guion de `cap3` se lee en voz alta y se entiende |
| F2 | Síntesis por frase, caché por hash, concatenación e índice de tiempos | Un apartado suena entero y sus tiempos son correctos |
| F3 | PWA completa: lista, reproductor con resaltado, tarjetas visuales y hoja de notas | Se escucha `cap3` de principio a fin anotando por el camino |
| F4 | Cierre de sesión, escritura en `revisiones/`, push y API de estado | el agente aplica una revisión anotada desde el móvil |
| F5 | Extensión a los 13 ficheros, descarga offline e invalidación por hash | La memoria completa está disponible y regenera de forma incremental |

El piloto de F1 a F3 es `cap3`, por ser el más largo y el que más bloques visuales
contiene: si el conversor sobrevive ahí, sobrevive al resto.

## 10. Riesgos

1. **El conversor es el grueso del trabajo.** Convertir LaTeX en prosa que se
   entienda al oído no es una sustitución de expresiones regulares. Habrá que
   iterar escuchando y corrigiendo el diccionario. Se mitiga acotando el piloto a
   un capítulo antes de sintetizar las cuatro horas.
2. **Fatiga de la voz sintética.** Piper es plano en sesiones largas. Se mitiga con
   el control de velocidad y con la posibilidad de cambiar de motor sin rehacer
   nada.
3. **Volumen de escucha.** Cuatro horas son muchas. La interfaz debe premiar el
   avance: progreso visible, apartados cortos y sesiones de 15 a 20 minutos.
4. **Permisos del servidor sobre el repositorio.** Descrito en el apartado 7.
5. **Deriva entre el audio y el texto.** Si la memoria cambia y el audio no se
   regenera, se escucha una versión antigua. Se mitiga marcando en la lista los
   apartados cuyo audio está desactualizado respecto al hash del `.tex`.
