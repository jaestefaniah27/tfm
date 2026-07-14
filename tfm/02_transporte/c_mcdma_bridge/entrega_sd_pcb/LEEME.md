# Entrega SD — PCB 14 drivers RS485/RS422 (bus de campo maestro/esclavo)

Proyecto para la **PCB conectada** (sin loopback interno): 14 transceptores serie,
cada uno con su AXI DMA simple. La app RTEMS simula un bus de campo donde la
ZCU102 es el controlador: unos canales hacen de **maestro** y otros de **esclavo**
(sensores/actuadores que responden).

## Archivos

| Archivo     | Qué es                                                       |
|-------------|--------------------------------------------------------------|
| `BOOT.bin`  | FSBL + PMUFW + **bitstream 14ch (con los 4 fixes del UART)** + BL31 + U-Boot + DTB |
| `rtems.img` | App de testing maestro/esclavo de la PCB                     |

## Topología física esperada (jumpers de la PCB)

```
Bus A (RS485 multidrop):   maestro CH0   | esclavos CH1..CH6
Bus B (RS422 maestro/escl): maestro CH7   | esclavos CH8..CH10
Bus C (RS422 maestro/escl): maestro CH11  | esclavos CH12..CH13
```

(Drivers 7 y 11 no tienen pin DE — DE hardcodeado en la PCB.)

## Cómo cargar

1. Copia **ambos** archivos a la partición FAT de la SD.
2. ZCU102 en modo SD boot, UART de consola a 115200 8N1.
3. Enciende. U-Boot carga `rtems.img`.

## Protocolo del test

Frame: `[SOF=0xAA][DST][SRC][CMD][LEN][DATA..][CHK]`  (CHK = XOR de DST..DATA)

Por cada bus y cada esclavo, el maestro ejecuta:
- **PING** → el esclavo responde PONG.
- **LEER SENSOR** → el esclavo responde una lectura simulada (0x1000 + canal·16).
- **ESCRIBIR ACTUADOR** → el maestro fija un setpoint, el esclavo responde ACK.

Además, por cada bus comprueba **integridad multidrop**: al emitir el maestro,
TODOS los esclavos del bus deben oír la trama (aunque solo responda el direccionado).

## Salida esperada (con la PCB bien cableada)

```
=== Bus A (RS485 multidrop) | maestro CH0 | esclavos: CH1 CH2 ... ===
  [multidrop] ... -> 6/6 esclavos oyeron al maestro  [PASS]
    [PASS] PING           CH0->CH1  PONG
    [PASS] LEER SENSOR    CH0->CH1  sensor=0x1010
    [PASS] ESCRIBIR ACT   CH0->CH1  setpoint=0x21 ACK
    ... (CH2..CH6) ...
=== Bus B ... ===  === Bus C ... ===
  >>> TEST PCB SUPERADO <<<  (N/N comprobaciones)
```

## Diagnóstico si falla

- **Un esclavo no responde**: revisar cableado/jumpers de ese driver en el bus,
  o que el DE conmute (drivers 0-6, 8-10, 12-13 tienen DE).
- **multidrop < n esclavos**: el bus no está realmente compartido (jumpers).
- El firmware del UART (TX/RX por DMA) está verificado y funciona; los fallos
  aquí apuntan al cableado físico de la PCB.

## Notas de hardware (14 canales)

- IRQs: 28 introut OR-coalescidas a 2 líneas (pl_ps_irq0[0]=mm2s, [1]=s2mm);
  la ISR escanea los 14 canales.
- Mapa: UART_i @ 0xA0000000+i·0x1000 ; axi_dma_i @ 0xA0010000+i·0x1000 ;
  SysInfo @ 0xA0020000.
