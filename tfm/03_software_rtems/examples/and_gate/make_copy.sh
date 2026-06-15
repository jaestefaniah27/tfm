#!/usr/bin/env bash
set -euo pipefail

# Carpeta donde tienes los scripts
BASE="${BASE:-$HOME/quick-start/app/hello}"
MAKE="$BASE/make_img.sh"
COPY="$BASE/copy_sd.sh"   # ← usa el nombre que tú has puesto

echo "[i] Usando BASE=$BASE"

# Comprueba que existen
[[ -f "$MAKE" ]] || { echo "ERROR: no existe $MAKE"; exit 1; }
[[ -f "$COPY" ]] || { echo "ERROR: no existe $COPY"; exit 1; }

# Asegura permisos de ejecución
chmod +x "$MAKE" "$COPY" || true

# Ejecuta make_img.sh (compila y genera rtems.img)
echo "[i] Ejecutando: $MAKE"
"$MAKE"

# Ejecuta copy_sh.sh (copia rtems.img a la SD)
# Pasa cualquier argumento que le des a este wrapper hacia copy_sh.sh
echo "[i] Ejecutando: $COPY $*"
"$COPY" "$@"

echo "✅ Listo: imagen generada y copiada."
