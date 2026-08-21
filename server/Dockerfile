FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg git ca-certificates openssh-client \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv
# Dependencias del servidor y, además, las del propio pipeline
# (pysbd, PyYAML): `_regenerate_in_background` lanza
# `python -m tools.audiorev.build` dentro de esta misma imagen, así que sin
# ellas toda regeneración fallaba nada más arrancar.
COPY server/requirements.txt /srv/server/requirements.txt
COPY requirements-audiorev.txt /srv/requirements-audiorev.txt
RUN pip install --no-cache-dir -r /srv/server/requirements.txt \
 && pip install --no-cache-dir -r /srv/requirements-audiorev.txt

# Piper (piper1-gpl, el paquete `piper-tts` de PyPI) y la voz española.
# La descarga de la voz necesita red durante el build; si tu entorno de
# construcción no la tiene, quita esta capa y monta el modelo desde el host
# apuntando AUDIOREV_PIPER_MODEL a la ruta montada (ver server/README.md).
ENV AUDIOREV_PIPER_MODEL=/opt/piper/es_ES-davefx-medium.onnx
RUN pip install --no-cache-dir piper-tts \
 && mkdir -p /opt/piper \
 && python -m piper.download_voices es_ES-davefx-medium --data-dir /opt/piper

COPY server /srv/server
COPY tools /srv/tools

# El clon de /data/repo empuja por SSH desde dentro del contenedor. Sin
# known_hosts, el primer `git push` falla por verificación de clave de
# host: se acepta la clave la primera vez y se fija en el volumen para que
# los siguientes push sí la verifiquen.
ENV GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/data/known_hosts"

ENV AUDIOREV_DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 8000

CMD ["uvicorn", "server.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
