# Aplicar revisiones de AudioRev

Guía para una sesión de Claude Code (típicamente desde el móvil) que aplica
las revisiones dictadas durante la escucha con AudioRev.

Requiere una variable de entorno `AUDIOREV_TOKEN` con el token de la API del
agente (`AUDIOREV_API_TOKEN` del servidor) y `AUDIOREV_URL` con la URL base
del servidor (p. ej. `https://audiorev.ejemplo.org`). El token **nunca** se
escribe en este documento ni en ningún commit; se lee siempre de la variable
de entorno.

## Procedimiento

1. **Sincronizar el repositorio y leer las revisiones nuevas.**

   ```bash
   git pull
   ```

   Lee los ficheros nuevos o modificados en `revisiones/` (uno por sesión de
   escucha, en Markdown). Cada revisión trae al menos: `id`, `unit_id`,
   `tex_file`, `sentence_text` y el comentario dictado.

2. **Para cada revisión, localizar la frase.**

   Busca `sentence_text` **literalmente** (cadena exacta, sin normalizar ni
   aproximar) dentro de `tex_file`. Si no aparece —el `.tex` ha cambiado desde
   que se grabó la nota—, no la edites a ciegas: márcala `obsoleta` con la
   API y pasa a la siguiente revisión.

   ```bash
   curl -sS -X POST \
     -H "Authorization: Bearer $AUDIOREV_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"estado": "obsoleta"}' \
     "$AUDIOREV_URL/api/revisiones/<id>/estado"
   ```

3. **Si la frase aparece, aplicar el cambio** respetando `GUIA_ESTILO_TFM.md`
   (terminología, tono, formato LaTeX del proyecto).

4. **Marcar la revisión como aplicada.**

   ```bash
   curl -sS -X POST \
     -H "Authorization: Bearer $AUDIOREV_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"estado": "aplicada"}' \
     "$AUDIOREV_URL/api/revisiones/<id>/estado"
   ```

5. **Un único commit por sesión de revisiones**, citando los identificadores
   de todas las revisiones aplicadas (y, si procede, las descartadas como
   obsoletas) en el mensaje de commit.

6. **Regenerar el audio y el índice al terminar**, para que el servidor
   sintetice de nuevo lo que ha cambiado y marque como obsoletas las notas
   ancladas a frases que ya no existen:

   ```bash
   curl -sS -X POST \
     -H "Authorization: Bearer $AUDIOREV_TOKEN" \
     "$AUDIOREV_URL/api/regenerar"
   ```

   Responde **202** con `{"queued": true}` en cuanto acepta el encargo: la
   regeneración completa (`git pull`, síntesis con Piper, recarga del
   índice) dura minutos y corre en segundo plano, no dentro de la petición.
   Si ya hay una regeneración en curso, esta se descarta y queda anotado en
   el log del contenedor. Para comprobar el resultado, mira `docker logs` o
   vuelve a consultar `GET /api/revisiones?estado=obsoleta` pasados unos
   minutos.

## Consulta de revisiones pendientes

Para listar solo las revisiones pendientes antes de empezar:

```bash
curl -sS \
  -H "Authorization: Bearer $AUDIOREV_TOKEN" \
  "$AUDIOREV_URL/api/revisiones?estado=pendiente"
```
