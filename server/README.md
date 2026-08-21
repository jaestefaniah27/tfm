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
| `AUDIOREV_PASSWORD_HASH`     | sí          | (vacío)                             | Hash Argon2 de la contraseña del único usuario.                             |
| `AUDIOREV_API_TOKEN`         | sí          | (vacío)                             | Token portador para endpoints de servicio (p. ej. `/api/reload`).           |
| `AUDIOREV_SESSION_SECRET`    | sí          | (vacío)                             | Secreto para firmar la cookie de sesión.                                    |
| `AUDIOREV_TRUST_PROXY_USER`  | no          | `None`                              | Cabecera de usuario de confianza si se despliega tras un proxy que autentica. |
| `AUDIOREV_COOKIE_SECURE`     | no          | `True`                              | Si la cookie de sesión lleva el flag `Secure`. Ponlo a `0`/`false`/`no` sólo en pruebas locales por HTTP; en producción debe quedar en `True` porque se sirve por HTTPS. |
| `AUDIOREV_PUBLIC_HOST`       | no          | `tfm-jorgerente.duckdns.org`        | Dominio público desde el que se sirve la app (usado por el manifest de la PWA y el webhook de GitHub). |
| `AUDIOREV_TTS_BACKEND`       | no          | (según compose, `piper`)            | Motor de texto a voz usado al regenerar audio.                              |
| `AUDIOREV_WEBHOOK_SECRET`    | sí          | (vacío)                             | Secreto compartido con el webhook de GitHub; firma en `X-Hub-Signature-256`. |

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

## Cómo generar la contraseña y los tokens

`AUDIOREV_PASSWORD_HASH`, `AUDIOREV_API_TOKEN`, `AUDIOREV_SESSION_SECRET` y
`AUDIOREV_WEBHOOK_SECRET` son secretos que generas tú, no los da ningún
servicio externo:

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
es quien usa Piper. Instálalo y descarga el modelo `es_ES-davefx-medium`
siguiendo `tools/audiorev/README.md` (sección "Instalar Piper y el modelo de
voz"); ese mismo binario debe estar disponible en el `PATH` del contenedor o
del entorno donde se ejecute `_regenerate_in_background` (imagen de
`server/compose.yml`).

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

2. Clona el repositorio en la ruta a la que apunta `AUDIOREV_REPO_DIR`
   (o `<data_dir>/repo` si no la defines) usando esa clave:

   ```bash
   git clone git@github.com:jaestefaniah27/tfm.git /var/lib/audiorev/repo
   ```

3. Configura la identidad del bot en ese clon:

   ```bash
   git -C /var/lib/audiorev/repo config user.name "AudioRev"
   git -C /var/lib/audiorev/repo config user.email "audiorev@localhost"
   ```

4. Antes de confiar en el endpoint, comprueba a mano que el push funciona:
   escribe un fichero de prueba bajo `revisiones/` en ese clon, haz commit y
   `git push`, y confirma que llega a GitHub.

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
