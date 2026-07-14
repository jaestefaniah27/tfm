# 04 — Línea previa: aplicaciones CDHS / AOCS

Trabajo anterior a la comparativa de transporte, conservado porque es donde nació el IP serie y donde se validó la integración PS-PL completa. Usa el transceptor con transporte **AXI-GPIO** (equivalente a la variante A).

| Carpeta | Contenido |
|---|---|
| `vivado_cdhs/` | Diseño Vivado del subsistema CDHS: transceptores serie en la PL + CAN y SPI del PS. |
| `vivado_aocs/` | Igual que el CDHS más `Motor_H_Bridge_test.vhd`, control de actuadores. |
| `test_cdhs/` | App RTEMS de integración: RS-422/RS-232 por PL, CAN0/CAN1 y SPI por PS. Incluye `DIAGNOSTICO_BOOT.md`. |
| `test_2_cdhs_setup/` | Setup alternativo del CDHS con scripts TCL que recrean el proyecto Vivado. |
| `spi_test/` | Prueba del ADC ADS7950 por SPI (`ads7950.c/h`). |
| `examples/and_gate/` | Ejemplo mínimo PS-PL: una puerta AND en la PL controlada por AXI-GPIO. |
| `examples/serial_example_1/` | Ejemplo mínimo de comunicación serie desde RTEMS. |

Las apps se compilan igual que las demás: `../../07_tools/make_img.sh` desde la carpeta de la app.
