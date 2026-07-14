#!/usr/bin/env bash
# finish_builds.sh — espera a DMA14, implementa MCDMA y empaqueta las tres.
set -uo pipefail
LB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V=/tools/Xilinx/2025.1/Vivado/bin/vivado
cd "$LB"

echo "[$(date +%T)] esperando a que termine DMA14…"
until grep -qE "^===== OK|^ERROR:" logs/dma14.out 2>/dev/null; do sleep 20; done
grep -E "^===== impl_1:|^===== WNS=|^ERROR" logs/dma14.out | tail -3

echo "[$(date +%T)] lanzando MCDMA…"
$V -mode batch -nojournal -log logs/mcdma.log -source common/patch_and_build.tcl \
   -tclargs "$LB/03_MCDMA/hardware/serial_bridge.xpr" system_mcdma vector 6 \
   > logs/mcdma.out 2>&1

grep -E "^===== impl_1:|^===== WNS=|^ERROR" logs/mcdma.out | tail -3

echo "[$(date +%T)] empaquetando…"
./common/make_boot.sh
echo "[$(date +%T)] FIN"
