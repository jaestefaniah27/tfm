# 🔴 Diagnóstico de Boot - No hay salida en puerto serial

## PASO 1: Verificar Configuración de Hardware Físico

### ✅ Verificar Jumpers de la ZCU102:

- [ ] **J15** (Mode Select): Debe estar en posición **0-1** (pines 1-2 conectados) = SD Boot
  - 0-1 = SD Boot ✅
  - 1-2 = JTAG Boot
  
- [ ] **J50** (PL DONE): Debe estar en posición **RUN**

- [ ] **J51** (PS Push Button): Configurado correctamente

### ✅ Verificar Conexiones USB/Serial:

- [ ] Micro USB conectado a **J50** (Puerto de Debug UART)
- [ ] Velocidad serial en terminal: **115200 baud**
- [ ] Data bits: 8, Stop bits: 1, Parity: None, Flow Control: None

### ✅ Verificar Placa/Power:

- [ ] El LED rojo **LED8** (DONE) está iluminado cuando la información se carga
- [ ] Los LED azules u otros cambian de estado
- [ ] La QSPi LED parpadea cuando se lee de SD

---

## PASO 2: Verificar ficheros en Tarjeta SD

Conecta la SD a una PC y verifica:

```bash
$ ls -la /media/mpsocv2/sd_card/
```

Debe contener:

- ✅ `BOOT.bin` (27 MB aproximadamente) - generado hace poco
- ✅ `image.bin` (Tu RTEMS image)
- ✅ Posiblemente `boot.scr` (opcional)

**Nota**: El  `BOOT.bin` debe estar en la **raíz** de la SD, con pines en modo SD Boot.

---

## PASO 3: Verificar si BOOT.bin se generó correctamente

```bash
$ cd /home/mpsocv2/quick-start/app/TEST_CDHS/hardware
$ file BOOT.bin
$ hexdump -C BOOT.bin | head -20  # Debe empezar con ciertos bytes
```

Un BOOT.bin válido debe empezar con el **Header de Boot**:
- Primeros 4 bytes: `AA 99 55 66` (en hexadecimal)

Si NO ves esos bytes, el BOOT.bin está corrupto.

---

## PASO 4: Verificar que el BIF correcto fue usado

```bash
$ cat /home/mpsocv2/quick-start/app/TEST_CDHS/hardware/lunes.bif
```

Verifica que:
- ✅ El FSBL existe y es correcto
- ✅ El bitstream (.bit) es el correcto
- ✅ Los paths son absolutos y correctos

---

## PASO 5: Regenerar BOOT.bin desde Vitis

1. En Vitis: **Vitis → Create Boot Image**
2. Verifica que sea **Zynq Ultrascale+ (ZYNQMP)**
3. Añade en este ORDEN exacto:
   - `cdhs_zynqmp_fsbl/build/cdhs_zynqmp_fsbl.elf` → **Bootloader**, CPU a53-0, EL-3
   - `pmufw.elf` → **pmufw_image**
   - `test_cdhs_generated_lunes.bit` → **datafile**, Device PL
   - `bl31.elf` → **datafile**, CPU a53-0, EL-3
   - `u-boot.elf` → **datafile**, CPU a53-0, EL-2
   - `system.dtb` → **datafile**, CPU a53-0, Load 0x100000

4. Verifica que el archivo de salida BIF sea correcto
5. Crea BOOT.bin

---

## PASO 6: Verificar salida en puerto Serial manualmente

```bash
$ screen /dev/ttyUSB0 115200
# o
$ python3 -m serial.tools.miniterm /dev/ttyUSB0 115200
```

Cuando enciendas la placa deberías ver:

```
ZYNQ FSBL [version info...]
NOTICE:  ATF starting...
[u-boot messages...]
```

Si no ves NADA → El FSBL no está corriendo

---

## PASO 7: Problemas Potenciales y Soluciones

| Síntoma | Causa Probable | Solución |
|---------|---------------|----------|
| **LED rojo encendido, nada en serial** | FSBL no ejecuta | Verificar BOOT.bin, BIF, Jumpers de boot |
| **Letras raras en serial** | Velocidad serial incorrecta | Cambiar a 115200 baud |
| **U-boot se para** | DDR no se inicializa | Verificar PSU (unidad de alimentación) |
| **Kernel panics** | Device tree incorrecto | Verificar system.dtb |
| **RTEMS no inicia** | Bootloader no carga image.bin | Verificar direcciones en RTEMS app |

---

## PASO 8: Logs Detallados

Si consigues llegar a U-boot, prueba estos comandos para debug:

```bash
=> printenv
=> md 0x100000 0x20  # Verificar que DTB está en memoria
=> reset
```

---

## PASO 9: Último Recurso - Regenerar desde Cero

Si nada funciona:

1. Elimina BOOT.bin y image.bin de la SD
2. Vuelve a ejecutar `./make_img.sh` en el proyecto RTEMS
3. Copia ambos archivos a la SD
4. Intenta de nuevo

