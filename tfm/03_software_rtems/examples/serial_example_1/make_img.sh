#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
RTEMS_PREFIX="${RTEMS_PREFIX:-$HOME/quick-start/rtems/7}"
APP_NAME="serial_example_1"
EXE_NAME="${APP_NAME}.exe"

export PATH="$RTEMS_PREFIX/bin:$PATH"

# --- rtems_waf opcional (si tu repo lo usa) ---
if [ ! -d rtems_waf ] && [ -f .gitmodules ]; then
  echo "[INFO] Inicializando submódulos (rtems_waf si aplica)..."
  git submodule update --init --recursive || true
fi

# --- Build con detección de 'not configured' ---
echo "[INFO] Ejecutando waf build..."
set +e
WAF_OUT="$(./waf 2>&1)"
WAF_RC=$?
set -e

if [ $WAF_RC -ne 0 ]; then
  if echo "$WAF_OUT" | grep -qi "not configured"; then
    echo "[WARN] Proyecto no configurado. Ejecutando './waf configure' (autodetección BSP)..."
    ./waf configure
    echo "[INFO] Reintentando compilación..."
    ./waf
  else
    echo "[ERROR] waf falló:"
    echo "$WAF_OUT"
    exit 1
  fi
fi

# --- Crear imagen binaria comprimida ---
BIN_FILE="${APP_NAME}.bin"
IMG_FILE="rtems.img"

echo "[INFO] Generando binario..."
aarch64-rtems7-objcopy -Obinary build/*/"${EXE_NAME}" "${BIN_FILE}"
gzip -9f "${BIN_FILE}"

if ! command -v mkimage >/dev/null; then
  echo "[ERROR] mkimage no está instalado (paquete 'u-boot-tools')."
  exit 1
fi

echo "[INFO] Creando rtems.img..."
mkimage -A arm64 -O rtems -T kernel -a 0x10000 -e 0x10000 \
  -n RTEMS -d "${BIN_FILE}.gz" "${IMG_FILE}"

echo "[OK] Hecho: ${IMG_FILE}"
