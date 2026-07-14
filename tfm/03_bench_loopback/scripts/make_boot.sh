#!/usr/bin/env bash
# make_boot.sh — empaqueta BOOT.bin + rtems.img de las tres variantes con loopback.
#
# El software es exactamente el mismo que el de los proyectos originales (el
# loopback vive solo en la PL), así que se reutilizan sus rtems.img. Lo que
# cambia es el bitstream: aquí se toma el reimplementado con bench_loopback.
set -euo pipefail

LB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$(cd "$LB/.." && pwd)"
BOOTGEN=/tools/Xilinx/2025.1/Vitis/bin/bootgen

# variante : proyecto_sw : bitstream (relativo a $LB) : fsbl : componentes
build() {
    local name="$1" sw="$2" bit="$3" fsbl="$4" comp="$5"
    local out="$LB/out/$name"
    mkdir -p "$out"

    if [ ! -f "$LB/$bit" ]; then
        echo "[$name] FALTA el bitstream: $LB/$bit — ¿terminó la implementación?" >&2
        return 1
    fi

    cat > "$out/boot.bif" <<EOF
//arch = zynqmp; split = false; format = BIN
the_ROM_image:
{
	[bootloader, destination_cpu = a53-0]$fsbl
	[pmufw_image]$comp/pmufw.elf
	[destination_device = pl]$LB/$bit
	[destination_cpu = a53-0, exception_level = el-3]$comp/bl31.elf
	[destination_cpu = a53-0, exception_level = el-2]$comp/u-boot.elf
	[load = 0x100000, destination_cpu = a53-0]$comp/system.dtb
}
EOF

    echo "[$name] bootgen…"
    "$BOOTGEN" -arch zynqmp -image "$out/boot.bif" -o "$out/BOOT.bin" -w on > /dev/null

    echo "[$name] rtems.img desde $sw"
    ( cd "$APP/$sw" && ./make_img.sh > /dev/null 2>&1 )
    cp "$APP/$sw/rtems.img" "$out/rtems.img"

    echo "[$name] listo: $(du -h "$out/BOOT.bin" | cut -f1) + $(du -h "$out/rtems.img" | cut -f1)"
}

GPIO_C="$APP/configurable_transceiver_inter/hardware/boot_components"
DMA_C="$APP/lince_comunicacion_serial_dma_pcb/hardware/boot_components"
MC_C="$APP/serial_bridge/hardware/scripts/boot_components"

# Se salta, sin abortar, la variante cuyo bitstream aún no esté implementado:
# así se puede ir empaquetando conforme terminan las síntesis.
build 01_GPIO  configurable_transceiver_inter \
      "01_GPIO/hardware/zynq_transceiver_system.runs/impl_1/system_wrapper.bit" \
      "$GPIO_C/configurable_transcerver_fsbl.elf" "$GPIO_C" || true

build 02_DMA14 lince_comunicacion_serial_dma_pcb \
      "02_DMA14/hardware/zynq_dma14_pcb.runs/impl_1/system_wrapper.bit" \
      "$DMA_C/configurable_transcerver_fsbl.elf" "$DMA_C" || true

build 03_MCDMA serial_bridge \
      "03_MCDMA/hardware/serial_bridge.runs/impl_1/system_mcdma_wrapper.bit" \
      "$APP/serial_bridge/hardware/scripts/vitis_ws/fsbl_dma_irq_concat/build/fsbl_dma_irq_concat.elf" \
      "$MC_C" || true

( cd "$LB/out" && md5sum */BOOT.bin */rtems.img > MANIFEST.md5 2>/dev/null || true )
echo
echo "=== $LB/out"
cat "$LB/out/MANIFEST.md5"
