#!/usr/bin/env bash
# Reinicia la ZCU102 por JTAG (Digilent SMT2NC), equivalente a pulsar el boton
# fisico de CPU reset: srst sobre el nodo PSU reinicia el PS entero, la BootROM
# recarga BOOT.bin de la SD y arranca U-Boot con su ventana de autoboot.
#
# Requiere el segundo USB de la placa (JTAG) conectado.
VITIS_SETTINGS=/tools/Xilinx/2025.1/Vitis/settings64.sh
XSDB=/tools/Xilinx/2025.1/Vitis/bin/xsdb

# El cable JTAG (FTDI) es de acceso exclusivo: varios hw_server compitiendo lo
# cuelgan. Cerramos los que hayan quedado de resets anteriores antes de conectar.
# (Si tienes Vivado hw_manager abierto sobre esta placa, cierralo antes.)
pkill -9 -f "hw_server" 2>/dev/null || true
sleep 1

TCL=$(mktemp --suffix=.tcl)
trap 'rm -f "$TCL"' EXIT
cat > "$TCL" <<'EOF'
connect
targets -set -filter {name =~ "PSU"}
rst -srst
after 200
# El srst puede dejar el Cortex-A53 #0 detenido en el vector de reset
# ("Reset Catch"): la BootROM no arranca y la placa no manda un solo byte.
# Reanudarlo explicitamente hace que el boot siga su curso normal.
targets -set -filter {name =~ "Cortex-A53 #0"}
catch {con}
after 200
exit
EOF

# shellcheck disable=SC1090
source "$VITIS_SETTINGS" 2>/dev/null
timeout 90 "$XSDB" "$TCL" >/dev/null 2>&1
echo "[jtag_reset] srst enviado a PSU"
