#!/usr/bin/env bash
# make_boot_pcb.sh — empaqueta el BOOT.bin de la caracterización de la PCB.
#
# Toma el bitstream MCDMA SIN loopback recién reimplementado (el que lleva el fix
# del DRAIN) y lo mete en un BOOT.bin junto al FSBL, PMUFW, BL31, U-Boot y DTB
# del proyecto serial_bridge.
#
# Es DISTINTO del BOOT.bin del benchmark: aquel lleva el loopback en la PL y deja
# los pines de recepción sin conectar, así que con él la PCB no se puede medir.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB=/home/mpsocv2/quick-start/app/serial_bridge/hardware
BOOTGEN=/tools/Xilinx/2025.1/Vitis/bin/bootgen

BIT="$SB/serial_bridge/serial_bridge.runs/impl_1/system_mcdma_wrapper.bit"
COMP="$SB/scripts/boot_components"
FSBL="$SB/scripts/vitis_ws/fsbl_dma_irq_concat/build/fsbl_dma_irq_concat.elf"
OUT="$HERE/../out"

[ -f "$BIT" ] || { echo "FALTA el bitstream: $BIT — ¿terminó la implementación?" >&2; exit 1; }

# Cinturón: el bitstream tiene que ser MÁS NUEVO que el RTL, o llevará el DRAIN viejo.
RTL="$SB/serial_bridge/serial_bridge.srcs/sources_1/new/BRIDGE_RX_FIFO_DRAIN.vhd"
if [ "$RTL" -nt "$BIT" ]; then
    echo "ERROR: el bitstream es más viejo que BRIDGE_RX_FIFO_DRAIN.vhd." >&2
    echo "       Reimplementa con rebuild_mcdma_pcb.tcl antes de empaquetar." >&2
    exit 1
fi

mkdir -p "$OUT"
cat > "$OUT/boot_pcb.bif" <<EOF
//arch = zynqmp; split = false; format = BIN
the_ROM_image:
{
	[bootloader, destination_cpu = a53-0]$FSBL
	[pmufw_image]$COMP/pmufw.elf
	[destination_device = pl]$BIT
	[destination_cpu = a53-0, exception_level = el-3]$COMP/bl31.elf
	[destination_cpu = a53-0, exception_level = el-2]$COMP/u-boot.elf
	[load = 0x100000, destination_cpu = a53-0]$COMP/system.dtb
}
EOF

echo "[pcb] bootgen…"
"$BOOTGEN" -arch zynqmp -image "$OUT/boot_pcb.bif" -o "$OUT/BOOT.bin" -w on > /dev/null

echo "[pcb] rtems.img…"
( cd "$HERE/.." && ./make_img.sh > /dev/null )
cp "$HERE/../rtems.img" "$OUT/rtems.img"

( cd "$OUT" && md5sum BOOT.bin rtems.img > MANIFEST.md5 )
echo
echo "=== $OUT"
cat "$OUT/MANIFEST.md5"
