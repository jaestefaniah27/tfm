# Servidor de AudioRev

API y PWA que sirven el índice y el audio generados por `tools/audiorev` a un
teléfono, y recogen las revisiones habladas.

## Variables de entorno

Se leen todas con el prefijo `AUDIOREV_`. Colócalas en `server/.env` (fichero
**no versionado**, ver `.gitignore`) o expórtalas antes de arrancar el
contenedor.

| Variable                    | Obligatoria | Por defecto                        | Descripción                                                                 |
|------------------------------|:-----------:|-------------------------------------|------------------------------------------------------------------------------|
| `AUDIOREV_DATA_DIR`          | no          | `/data`                             | Directorio raíz de datos persistentes (índice, audio, base de datos, repo). |
| `AUDIOREV_REPO_DIR`          | no          | `<data_dir>/repo`                   | Clon del repositorio LaTeX del TFM usado para regenerar el índice.          |
| `AUDIOREV_PASSWORD_HASH`     | no          | (vacío)                             | Hash Argon2 de la contraseña del único usuario. **Opcional**: si se deja vacío (y `AUDIOREV_TRUST_PROXY_USER` tampoco está puesto), la app no pide contraseña y cualquiera con la URL entra directamente. Ver más abajo. |
| `AUDIOREV_API_TOKEN`         | sí          | (vacío)                             | Token portador para endpoints de servicio (p. ej. `/api/reload`).           |
| `AUDIOREV_SESSION_SECRET`    | sí          | (vacío)                             | Secreto para firmar la cookie de sesión.                                    |
| `AUDIOREV_TRUST_PROXY_USER`  | no          | `None`                              | Cabecera de usuario de confianza si se despliega tras un proxy que autentica. |
| `AUDIOREV_COOKIE_SECURE`     | no          | `True`                              | Si la cookie de sesión lleva el flag `Secure`. Ponlo a `0`/`false`/`no` sólo en pruebas locales por HTTP; en producción debe quedar en `True` porque se sirve por HTTPS. |
| `AUDIOREV_PUBLIC_HOST`       | no          | `tfm-jorgerente.duckdns.org`        | Dominio público desde el que se sirve la app (usado por el manifest de la PWA y el webhook de GitHub). |
| `AUDIOREV_TTS_BACKEND`       | no          | (según compose, `piper`)            | Motor de texto a voz usado al regenerar audio.                              |
| `AUDIOREV_WEBHOOK_SECRET`    | sí          | (vacío)                             | Secreto compartido con el webhook de GitHub; firma en `X-Hub-Signature-256`. |

Además, **`SSH_KEY_PATH`** es una variable **del propio Docker Compose**, no
una opción de la aplicación (`config.py` no la lee y no lleva prefijo
`AUDIOREV_`): apunta al fichero de clave privada de despliegue **en el host**,
que `compose.yml` monta en `/root/.ssh/id_ed25519` dentro del contenedor. Si
no la defines se usa `~/.ssh/audiorev_deploy`. Sin una clave válida en esa
ruta, `docker compose up` monta un directorio vacío y el `git push` de la
publicación falla.

| Variable       | Obligatoria | Por defecto                | Descripción                                                          |
|----------------|:-----------:|-----------------------------|-----------------------------------------------------------------------|
| `SSH_KEY_PATH` | no          | `~/.ssh/audiorev_deploy`    | Ruta **en el host** de la clave de despliegue (variable de Compose). |

### Por qué `env_file` y no `environment:`

`compose.yml` pasa `server/.env` con `env_file:` en vez de listar cada
variable como `AUDIOREV_PASSWORD_HASH: ${AUDIOREV_PASSWORD_HASH}`. Compose
interpola `$VAR` en los valores que sustituye dentro del YAML, y un hash
Argon2 (`$argon2id$v=19$m=65536,...`) perdía por el camino `$argon2id`, `$v`
y `$m`: el hash llegaba corrupto al contenedor y el login fallaba siempre con
«Contraseña incorrecta», sin ningún diagnóstico. Las claves de `env_file` se
entregan al contenedor **literalmente**, sin esa sustitución, así que el hash
y los tokens llegan intactos. Como efecto secundario, cualquier variable
nueva que pongas en `.env` (por ejemplo `AUDIOREV_WEBHOOK_SECRET`, que antes
no se pasaba y dejaba el webhook rechazando toda entrega con 401) llega sola
al contenedor sin tocar `compose.yml`.

No pongas comillas alrededor de los valores en `.env` salvo que formen parte
del valor: `env_file` las conserva tal cual.

## Cómo ejecutarlo

```bash
cd server
cp .env.example .env   # si existe; si no, crea .env con las variables de arriba
docker compose up -d --build
curl -s localhost:8091/healthz
```

El contenedor expone la API únicamente en `127.0.0.1:8091` del host: no es
accesible directamente desde fuera, sólo a través del reverse proxy.

## Cómo apuntar el dominio

El despliegue objetivo es **tfm-jorgerente.duckdns.org**, servido por Caddy
(`server/Caddyfile`) delante del contenedor:

```bash
sudo caddy run --config server/Caddyfile
# o, si Caddy corre como servicio del sistema:
sudo cp server/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Requisitos que debes cumplir tú mismo en la máquina de despliegue, Caddy no
los resuelve:

- **DuckDNS debe resolver ya** `tfm-jorgerente.duckdns.org` a la IP pública
  de este host (actualiza el registro en duckdns.org antes de arrancar Caddy).
- **Los puertos 80 y 443 del host deben ser alcanzables desde Internet**
  (reenvío de puertos en el router / reglas de firewall abiertas), porque
  Caddy los usa para el reto ACME HTTP-01 y para servir HTTPS. Sin esto la
  emisión del certificado de Let's Encrypt fallará.

Una vez emitido el certificado, verifica desde el móvil (fuera de la red
local, con datos móviles) que `https://tfm-jorgerente.duckdns.org/healthz`
responde `{"status":"ok",...}`.

El `Caddyfile` reenvía todo el tráfico del dominio al contenedor con un único
bloque `reverse_proxy`, así que no hace falta ninguna `location` aparte para
`POST /api/webhook/github`: en GitHub, configura la URL de entrega del
webhook como `https://tfm-jorgerente.duckdns.org/api/webhook/github`.

## ¿Hace falta contraseña?

`AUDIOREV_PASSWORD_HASH` es **opcional**. Si no lo defines (y tampoco defines
`AUDIOREV_TRUST_PROXY_USER`), el servidor no muestra ninguna pantalla de
acceso: `/api/*` responde directamente a cualquiera que llegue a la URL, sin
cookie ni cabecera. Esta es una decisión explícita para un despliegue de un
solo usuario en un subdominio DuckDNS privado que nadie más conoce: no hay
enlaces públicos ni buscadores que lo indexen, así que el riesgo asumido es
que **cualquiera que consiga la URL exacta puede usar la app sin
autenticarse**. Si en algún momento compartes el enlace, lo publicas en un
dominio más descubrible, o simplemente prefieres una capa extra de
seguridad, sigue configurando `AUDIOREV_PASSWORD_HASH` como se explica a
continuación para recuperar la pantalla de login.

## Cómo generar la contraseña y los tokens

`AUDIOREV_PASSWORD_HASH` (opcional, ver arriba), `AUDIOREV_API_TOKEN`,
`AUDIOREV_SESSION_SECRET` y `AUDIOREV_WEBHOOK_SECRET` son secretos que
generas tú, no los da ningún servicio externo:

```bash
# Hash Argon2 de la contraseña (usa la propia librería del servidor):
python3 -c "from argon2 import PasswordHasher; print(PasswordHasher().hash('tu-contraseña'))"

# Token portador para /api/revisiones, /api/regenerar, etc.:
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Secreto para firmar la cookie de sesión:
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Secreto del webhook de GitHub (el mismo valor se pega en GitHub → Settings
# → Webhooks → Secret, al configurar la entrega a POST /api/webhook/github
# con content type application/json y el evento "push"):
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Pega cada valor en `server/.env`. `AUDIOREV_WEBHOOK_SECRET` es lo único que
autentica ese endpoint (no lleva sesión ni token portador): sin él configurado
en ambos lados, todo push se rechaza con 401.

## Instalar Piper y el modelo de voz

El servidor no sintetiza directamente: delega en `tools.audiorev.build`, que
es quien usa Piper. **En el contenedor ya viene todo instalado**:
`server/Dockerfile` instala también `requirements-audiorev.txt` (las
dependencias del pipeline, `pysbd` y `PyYAML`, que antes faltaban y hacían
fallar cada regeneración al instante) y el paquete `piper-tts`, y descarga la
voz `es_ES-davefx-medium` en `/opt/piper`, a la que apunta
`AUDIOREV_PIPER_MODEL`.

Se eligió instalar Piper **dentro de la imagen** en vez de montar un binario
del host porque Piper (piper1-gpl) es un paquete de PyPI, no un binario
suelto: `pip install piper-tts` basta y evita depender de la arquitectura y
las librerías del host.

Dos avisos:

- La descarga de la voz ocurre **durante `docker compose build`** y necesita
  red en la máquina de construcción (unos 60 MB).
- Si tu entorno de construcción no tiene red, quita esa capa del `Dockerfile`,
  descarga el modelo en el host siguiendo `tools/audiorev/README.md` y móntalo
  en el contenedor añadiendo a `compose.yml` un volumen
  `- /ruta/host/piper:/opt/piper:ro`; `AUDIOREV_PIPER_MODEL` ya apunta ahí.

Comprueba que la síntesis funciona de verdad antes de confiar en el webhook:

```bash
docker compose exec audiorev piper -m "$AUDIOREV_PIPER_MODEL" -f /tmp/p.wav <<< "Prueba."
docker compose exec audiorev ls -l /tmp/p.wav
```

Si algún paso de la regeneración falla (Piper, `ffmpeg`, `git pull`), queda
registrado en la salida estándar con el prefijo `[audiorev]`: míralo con
`docker logs`. Antes fallaba en silencio.

## Clave de despliegue para publicar revisiones

El endpoint `POST /api/sessions/{session_id}/publicar` escribe el fichero de
revisiones bajo `revisiones/` en `AUDIOREV_REPO_DIR` y hace `git push`. Para
que funcione, prepara a mano en el servidor (esto no lo hace el contenedor):

1. Genera una clave de despliegue dedicada (sin passphrase) y, en GitHub,
   añádela al repositorio como **deploy key con permiso de escritura**
   restringido a este repositorio:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/audiorev_deploy -N ""
   ```

2. Apunta `SSH_KEY_PATH` a esa clave en `server/.env` (o déjala en
   `~/.ssh/audiorev_deploy`, que es el valor por defecto de `compose.yml`).

3. Clona el repositorio **dentro del volumen que ve el contenedor**, no en
   una ruta cualquiera del host. `compose.yml` fija
   `AUDIOREV_REPO_DIR=/data/repo`, y `/data` es el volumen `audiorev-data`:
   el clon tiene que quedar ahí, así que se hace desde dentro del propio
   contenedor, que ya tiene montada la clave en `/root/.ssh/id_ed25519`:

   ```bash
   docker compose up -d
   docker compose exec audiorev git clone \
     git@github.com:jaestefaniah27/tfm.git /data/repo
   ```

   La primera conexión a GitHub tiene que verificar su clave de host o el
   `git push` falla. La imagen fija
   `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/data/known_hosts"`,
   así que la acepta y la **fija en el volumen** la primera vez; a partir de
   ahí sí se verifica. Si prefieres no aceptar nada a ciegas, escribe el
   `known_hosts` antes del clon con la clave publicada por GitHub:

   ```bash
   docker compose exec audiorev sh -c \
     "ssh-keyscan github.com >> /data/known_hosts"
   ```

4. Configura la identidad del bot en ese clon:

   ```bash
   docker compose exec audiorev git -C /data/repo config user.name "AudioRev"
   docker compose exec audiorev git -C /data/repo config user.email "audiorev@localhost"
   ```

5. Antes de confiar en el endpoint, comprueba a mano que el push funciona
   desde dentro del contenedor: escribe un fichero de prueba bajo
   `revisiones/` en `/data/repo`, haz commit y `git push`, y confirma que
   llega a GitHub.

## Límite de intentos en el login

`POST /login` lleva un limitador en memoria por IP: tras
**5 intentos fallidos en 5 minutos** responde `429` con
«Demasiados intentos fallidos. Espera unos minutos.», incluso si a partir de
ahí se acierta la contraseña; el contador se borra al entrar bien o al pasar
la ventana. Es un contador del proceso (no Redis): con un solo contenedor y
un solo usuario basta, pero un reinicio del contenedor lo pone a cero. La IP
se toma de `X-Forwarded-For`, que Caddy fija y sobrescribe.

## Antes de fiarte de esto en producción

Las pruebas automáticas del frontend son, en su mayor parte, comprobaciones
de que el JavaScript contiene lo que debe: **no hay navegador de verdad en la
batería** (sólo la cola de notas de `app.js` se ejecuta a fondo en Node con un
IndexedDB y un `fetch` de mentira). Nada de esto se ha ejecutado nunca en
Docker ni ha sintetizado audio real. Repasa a mano esta lista la primera vez,
en el móvil y contra el dominio público:

1. **Login.** Entra con la contraseña buena; falla cinco veces seguidas y
   comprueba que la sexta responde 429.
2. **Reproducción y avance.** Abre un apartado, escucha un minuto, manda la
   app a segundo plano y vuelve: la lista debe mostrar tiempo escuchado y
   «Seguir donde lo dejé» debe llevarte a ese apartado. (Si `listened_duration_s`
   sigue a cero, el guardado por *beacon* no está llegando.)
3. **Anotar sin cobertura.** Con el apartado ya cacheado, pon el modo avión,
   anota dos frases, **cierra la app del todo**, quita el modo avión y
   vuelve a abrirla: las notas deben aparecer en `GET /api/notes` sin tocar
   nada, y no duplicadas.
4. **Cerrar sesión.** Pulsa «Cerrar sesión y publicar»: debe mostrar la ruta
   del fichero y ese fichero debe aparecer en `revisiones/` en GitHub.
5. **Arranque.** `docker compose up -d --build` y `curl -s localhost:8091/healthz`
   debe responder `{"status":"ok",...}`.
6. **Webhook.** Empuja algo a `main` y comprueba en `docker logs` que se ve
   el `git pull` y la reconstrucción, sin líneas `[audiorev] falló ...`.
7. **Regeneración.** Tras regenerar, abre un apartado ya visitado en el móvil
   y comprueba que el texto es el nuevo (el service worker revalida
   `/api/units/` en segundo plano, así que puede hacer falta una segunda
   apertura).

## Copia de seguridad del volumen de datos

Todo el estado persistente vive en el volumen `audiorev-data` (montado en
`/data` dentro del contenedor): índice, audio, base de datos de revisiones y
el clon del repositorio.

Para respaldarlo sin parar el servicio:

```bash
docker run --rm \
  -v audiorev-data:/data:ro \
  -v "$(pwd)":/backup \
  alpine \
  tar czf /backup/audiorev-data-$(date +%Y%m%d).tar.gz -C / data
```

Para restaurarlo en un volumen nuevo:

```bash
docker run --rm \
  -v audiorev-data:/data \
  -v "$(pwd)":/backup \
  alpine \
  sh -c "cd / && tar xzf /backup/audiorev-data-YYYYMMDD.tar.gz"
```
