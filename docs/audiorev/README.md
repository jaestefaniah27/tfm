# AudioRev: empieza aquí

Sistema para escuchar la memoria del TFM desde el móvil y anotar las revisiones
ancladas a la frase exacta, para que el agente las aplique después sobre el
LaTeX.

## Qué leer y en qué orden

1. **Diseño:** [`docs/superpowers/specs/2026-08-20-audiorev-design.md`](../superpowers/specs/2026-08-20-audiorev-design.md).
   Qué se construye y por qué se decidió así. Empieza por aquí.
2. **Plan del conversor:** [`docs/superpowers/plans/2026-08-20-audiorev-pipeline.md`](../superpowers/plans/2026-08-20-audiorev-pipeline.md).
   Once tareas con pruebas, de `main.tex` al audio por apartado. **Va primero.**
3. **Plan del servidor:** [`docs/superpowers/plans/2026-08-20-audiorev-servidor.md`](../superpowers/plans/2026-08-20-audiorev-servidor.md).
   Once tareas más, de la API a la aplicación web. Consume la salida del anterior.

## Cómo ejecutarlo desde el móvil

Abre una sesión del agente en el servidor, con las herramientas MCP que dan
acceso a los ficheros y a la línea de órdenes, y pídele:

> Ejecuta `docs/superpowers/plans/2026-08-20-audiorev-pipeline.md` tarea a tarea.
> Usa la skill `superpowers:subagent-driven-development`.

Cada tarea acaba en un commit y en un criterio de aceptación comprobable. Cuando
el primer plan esté terminado, repite con el del servidor.

## Lo que hay que preparar en el servidor

Antes de empezar el plan del servidor:

- **Piper** y el modelo de voz `es_ES-davefx-medium`, más `ffmpeg`.
- **Un clon del repositorio** en `/var/lib/audiorev/repo`, con una deploy key de
  escritura restringida a este repositorio. El proceso automático solo escribe
  bajo `revisiones/`.
- **Un `location` en el reverse proxy** apuntando al contenedor, con HTTPS. La
  descarga para escuchar sin cobertura depende de que la web se sirva por HTTPS.
- **Tres secretos** en el `.env` del servidor: el hash de la contraseña, el token
  de la API y la clave de firma de la sesión. Se generan con las órdenes de la
  tarea 2 del plan del servidor. No van a git.

## Decisiones que conviene no olvidar

- El audio **no se versiona**. Solo los JSON de índice.
- Las revisiones se anclan por el **texto literal de la frase**, no por el número
  de línea, que se desplaza con cada edición.
- El motor de voz es intercambiable. Se empieza con Piper por ser gratis y local;
  si la prosodia acaba cansando, se cambia por variable de entorno y la caché por
  hash evita repetir el trabajo.
- El piloto es `cap3`. Es el capítulo más largo y el que más bloques visuales
  tiene: si el conversor funciona ahí, funciona en el resto.

## Cuando ya esté funcionando

Para aplicar las revisiones de una sesión de escucha, sigue
`docs/audiorev/APLICAR_REVISIONES.md`, que se escribe en la tarea 10 del plan del
servidor.
