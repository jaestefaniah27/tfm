# audiorev

Convierte la memoria del TFM (los `.tex` bajo `plantilla_tft_etsit/`) en un
índice JSON por apartado y, opcionalmente, en su audio correspondiente, para
poder revisar el texto escuchándolo.

## Qué hace

1. Expande `\import`/`\input`/`\include` a partir de `main.tex` para obtener
   el documento en orden canónico, conservando el fichero y la línea de
   origen de cada línea (`expand.py`).
2. Extrae figuras, tablas, código y gráficas como bloques aparte, dejando un
   marcador en el texto que ocupaban (`blocks.py`).
3. Parte el documento en unidades de escucha por encabezado (`\section`,
   `\subsection`, `\subsubsection`) y trocea las que son demasiado largas en
   partes de un tamaño de palabras razonable (`structure.py`).
4. Normaliza cada unidad a texto pronunciable: quita comandos de LaTeX,
   resuelve referencias cruzadas a su número y tipo, expande unidades y
   deletrea acrónimos según el diccionario de pronunciación
   (`speak.py`, `refs.py`, `dic.py`), y la parte en frases (`segment.py`).
5. Sintetiza cada frase con el backend de voz elegido, cacheando el audio
   por el hash del texto hablado para no resintetizar lo que no ha cambiado
   (`tts.py`, `cache.py`), y concatena las frases de cada unidad en un único
   fichero de audio con sus tiempos (`assemble.py`).
6. Todo esto lo orquesta `build.py`, que escribe un `<unit_id>.json` y un
   `<unit_id>.opus` por unidad, más un `manifest.json` con el resumen de
   todas las unidades generadas.

Cada frase del JSON lleva su `hash`, el fichero y la línea de origen
(`tex_line`) y sus tiempos (`t_start`, `t_end`) dentro del audio de la
unidad, de forma que una revisión hablada se pueda anclar de vuelta al
LaTeX.

## Instalar Piper y el modelo de voz

El backend por defecto es [Piper](https://github.com/rhasspy/piper), que
sintetiza localmente sin depender de ningún servicio externo. Instálalo y
descarga la voz española `es_ES-davefx-medium`:

```bash
pip install piper-tts

# Modelo y su configuración .json, en el mismo directorio:
python -m piper.download_voices es_ES-davefx-medium
```

Por defecto `tools/audiorev/tts.py` busca `es_ES-davefx-medium.onnx` en el
directorio desde el que se ejecuta `piper`; si el modelo está en otra ruta,
indícalo con la variable de entorno `AUDIOREV_PIPER_MODEL`:

```bash
export AUDIOREV_PIPER_MODEL=/ruta/a/es_ES-davefx-medium.onnx
```

La concatenación final a `.opus` usa `ffmpeg`, que también debe estar
instalado y en el `PATH`.

## Uso

Generar solo los índices JSON de un capítulo, sin sintetizar audio (rápido,
útil para revisar el texto que se leerá):

```bash
python -m tools.audiorev.build --out out/audiorev --only cap3 --no-audio
```

Generar índices y audio de todo el documento con Piper:

```bash
python -m tools.audiorev.build --out out/audiorev --backend piper
```

Otras opciones de `python -m tools.audiorev.build`:

- `--repo`: raíz del repositorio (por defecto, el directorio actual).
- `--out`: directorio de salida (obligatorio).
- `--cache`: directorio de la caché de audio por frase (por defecto,
  `<out>/.cache`).
- `--only`: filtra las unidades cuyo fichero `.tex` de origen contenga este
  fragmento de ruta, p. ej. `cap3`.
- `--backend`: `piper` (por defecto), `fake` (silencio, solo para pruebas).
- `--no-audio`: no sintetiza nada; solo escribe los JSON con
  `duration_s: 0.0`.

## `out/` no se versiona

El directorio de salida (`out/audiorev` en los ejemplos de arriba) contiene
JSON y audio generados a partir del `.tex`, así que no se sube al
repositorio: está en `.gitignore`. Lo único que se versiona es el propio
código de `tools/audiorev` y el diccionario de pronunciación en
`tools/audiorev/dic/pronunciacion.yml`.
