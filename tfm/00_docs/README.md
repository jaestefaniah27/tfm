# 00 — Documentación

| Fichero | Qué es |
|---|---|
| `informe_benchmark.html` | Informe con la comparativa de las tres variantes de transporte. Ábrelo en el navegador. |
| `registro_investigacion_rx.txt` | Bitácora de la depuración del camino de recepción: el fallo «514 de 1024 bytes», el bloqueo del S2MM en *store-and-forward* con paquetes de más de 512 B, la pérdida del TDEST en el RX y el porqué del bloque DRAIN. Es la traza de razonamiento detrás del diseño final del puente. |
| `PS_PL_instructions.md` | Notas de integración PS-PL (arranque desde el ejemplo de la puerta AND). |
| `pcbs/` | Esquemáticos (PDF) y listas de materiales (BOM) de las tres placas: `cdhs/`, `aocs/` y `serial/` (la de 14 transceptores que se caracteriza en [04](../04_pcb_caracterizacion/README.md), con su XDC de pines). |
| `logs_terminal/` | Capturas de consola de las campañas de prueba: RS de AOCS, ADC y CAN de CDHS, y las de la placa serie (GPIO y DMA). |
| `lince_comunicacion_serial.html` | Visor de señales de la placa de comunicación serie. |

La memoria del TFM vive en la raíz del repositorio: `TFM_JORGE_A_E.md` (texto), `plantilla_tft_etsit/` (LaTeX de la ETSIT) y `plan_arqu_dma.md` (notas de arquitectura del DMA).
