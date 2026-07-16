# 07 — Herramientas de desarrollo

Comunes a todas las apps RTEMS del repo.

## `make_img.sh`
Compila la app con Waf y genera `rtems.img` para U-Boot. Deduce el nombre de la app del directorio desde el que se lanza, así que sirve para cualquiera sin tocarlo.

```bash
export RTEMS_PREFIX=$HOME/quick-start/rtems/7
cd tfm/02_transporte/c_mcdma_bridge/software
../../../07_tools/make_img.sh          # → rtems.img
```

Localiza el toolchain `aarch64-rtems7-*`, inicializa `rtems_waf` si falta, ejecuta `./waf` (y `configure` la primera vez), pasa el `.exe` a binario plano con `objcopy`, lo comprime y lo empaqueta con `mkimage`.

## `automate_ymodem_update.py`
Carga `rtems.img` en la SD de la ZCU102 **sin sacar la tarjeta**: interrumpe el autoboot de U-Boot, envía el fichero por YMODEM (`loady`) y lo escribe en la FAT con `fatwrite`.

```bash
python3 07_tools/automate_ymodem_update.py               # solo rtems.img
python3 07_tools/automate_ymodem_update.py --boot ./BOOT.bin   # además el bitstream
```

Requiere `pyserial` y `lrzsz` (`apt install lrzsz`).

> Tras un reset por JTAG el A53 puede quedarse en «Reset Catch» y la placa no arranca. Se sale mandando `con` en XSDB después del `srst`.

## `serial_gui.py`
GUI para monitorizar y enviar por el puerto serie USB (115200 8N1), útil para ver la salida de los transceptores en vivo.
