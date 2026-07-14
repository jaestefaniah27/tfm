# 01 — IP del transceptor serie configurable

El bloque base del TFM: un UART parametrizable en VHDL, instanciable N veces en la PL. Es **común a las tres variantes de transporte**; lo que cambia entre ellas es cómo se conecta al PS, no este IP.

## Fuentes (`vhdl/`)

| Fichero | Papel |
|---|---|
| `NCO.vhd` | Oscilador controlado numéricamente: genera el reloj de baudios a partir de una palabra de fase. Permite cambiar la velocidad en caliente sin resintetizar. |
| `ShiftRegister.vhd` | Registro de desplazamiento usado por TX y RX. |
| `TX_CONFIGURABLE_SERIAL.vhd` | Transmisor: serializa el byte con el formato configurado (bits de datos, paridad, stop, orden de bits). |
| `RX_CONFIGURABLE_SERIAL.vhd` | Receptor: muestreo por sobremuestreo, detección de start, validación de paridad y stop. |
| `CONFIGURABLE_SERIAL.vhd` | Un canal completo: TX + RX + NCO + registro de configuración. |
| `CONFIGURABLE_SERIAL_TOP.vhd` | Envoltorio del canal con su interfaz hacia el bus. |
| `MULTI_SERIAL_CORE.vhd` | Agrupa N canales bajo una sola interfaz AXI-Lite. Usado por la **variante GPIO**. |
| `SERIAL_CHANNEL_IP.vhd` | Un canal empaquetado como IP con interfaz AXI-Stream. Usado por la **variante DMA14**. |
| `UART_AXIS_TOP.vhd` | Adaptador UART ↔ AXI-Stream (TDATA/TVALID/TREADY/TLAST). Base de las variantes DMA y MCDMA. |

## Configuración de un canal

Cada canal expone un registro de 32 bits con: orden de bits (LSB/MSB), bits de datos (5–9), bits de stop (1 / 1.5 / 2), paridad (par, impar, ninguna, marca, espacio), palabra de baudios del NCO y modo SLO. Los `#define` correspondientes están en `transceiver.h` de cada variante.

## Testbenches (`testbench/`)

```bash
# desde esta carpeta
xvlog --sv ...            # (o xvhdl para VHDL)
xvhdl vhdl/*.vhd testbench/tb_CONFIGURABLE_SERIAL_TOP.vhd
xelab tb_CONFIGURABLE_SERIAL_TOP -s tb && xsim tb -R
```

- `tb_CONFIGURABLE_SERIAL_TOP.vhd`, `tb_NCO.vhd`, `tb_RS232_TX.vhd` — verificación del canal y del generador de baudios.
- `tb_uart_axis_loopback.vhd` — comprueba el camino UART ↔ AXI-Stream.
- `tb_serial_rx_*.vhd`, `tb_rx_top_*.vhd`, `tb_rx_drain_burst.vhd` — banco de pruebas del receptor: ráfagas, contrapresión (*backpressure*), varios canales simultáneos y vaciado de la FIFO. Salieron de la depuración del RX documentada en [00_docs/registro_investigacion_rx.txt](../00_docs/registro_investigacion_rx.txt).

## Scripts (`scripts/`)

- `package_multi_serial_ip.tcl` — empaqueta `MULTI_SERIAL_CORE` como IP de Vivado (variante GPIO).
- `package_serial_channel_ip.tcl` — empaqueta `SERIAL_CHANNEL_IP` (variante DMA).
- `generate_transceivers.tcl` / `add_transceiver.tcl` — instancian N transceptores en el block design.
- `generar_visor.py` — genera `visor_zcu102.html`, una vista de las señales asignadas a pines para comprobar el mapeo.

## Constraints (`constraints/`)

XDC de la ZCU102 con la asignación de pines de los 14 canales (TD/RD y las señales de habilitación de los transceptores RS-485 en la PCB).
