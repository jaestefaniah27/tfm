#!/usr/bin/env bash
set -e
export PATH="$HOME/quick-start/rtems/7/bin:$PATH"
./waf
aarch64-rtems7-objcopy -Obinary build/*/and.exe and.bin
gzip -9f and.bin
mkimage -A arm64 -O rtems -T kernel -a 0x10000 -e 0x10000 -n RTEMS -d and.bin.gz rtems.img
echo "Hecho: rtems.img"
