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
