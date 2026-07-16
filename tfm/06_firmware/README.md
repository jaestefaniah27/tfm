# 06 — Firmware de arranque

## `fsbl_cdhs/`
FSBL (*First Stage Boot Loader*) de Xilinx, versión `fsbl_full_cdhs_with_rx_patch`: la más completa usada en el TFM, con el parche de inicialización del receptor serie.

`psu_init.c/h` los genera Vivado al exportar el XSA. **Si se regenera el hardware hay que actualizarlos desde Vitis**, o el FSBL configurará mal el PS.

## `boot_scripts/`
Scripts Python que construyen el `BOOT.bin` (FSBL + bitstream + U-Boot) para cada configuración de hardware. Cada `setup_*.py` corresponde a una plataforma Vitis distinta; `generate_boot.sh` es el envoltorio en shell.

Las variantes de `02_transporte/` traen además su propio `hardware/scripts/generate_boot.sh`, que es el camino recomendado para ellas.
