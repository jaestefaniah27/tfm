#!/usr/bin/env python3
import os, sys, time, re, subprocess, signal
from pathlib import Path

# ---------- Ajustes ----------
PORT = os.environ.get("RTEMS_SERIAL", "/dev/ttyUSB0")         # tu Silicon Labs
BAUD = int(os.environ.get("RTEMS_BAUD", "115200"))
APP_DIR = Path(os.environ.get("APP_DIR", str(Path.home() / "quick-start/app/and")))
MAKE = APP_DIR / "make_img.sh"
IMG  = APP_DIR / "rtems.img"

LOAD_ADDR = os.environ.get("RTEMS_LOADADDR", "0x800000")      # alto para evitar solapes
FAT_DEV   = os.environ.get("RTEMS_FATDEV", "mmc 0:1")         # partición FAT
EOL = os.environ.get("RTEMS_EOL", "\n")                       # Line ending LF

# Tiempos
T_AUTOboot = 20.0                                              # ventana de autoboot
T_PROMPT   = 2.5                                              # espera rápida al prompt
T_YMODEM   = 600.0                                            # margen envío YMODEM
READ_SLICE = 0.02                                             # 20 ms por ciclo
# -----------------------------

def run(cmd, **kw):
    print(f"[cmd] {cmd}")
    return subprocess.run(cmd, shell=True, check=True, **kw)

def make_image():
    if not MAKE.exists():
        print(f"ERROR: no existe {MAKE}")
        sys.exit(1)
    run(f"cd '{APP_DIR}' && chmod +x '{MAKE}' && '{MAKE}'")
    if not IMG.exists():
        print(f"ERROR: no se generó {IMG}")
        sys.exit(1)

def open_serial():
    import serial
    # timeout=0 => lectura no bloqueante (reacciona rápido)
    ser = serial.Serial(PORT, BAUD, timeout=0, write_timeout=1)
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    return ser

def read_available(ser):
    """Lee todo lo disponible ahora mismo (no bloqueante)."""
    out = b""
    while True:
        n = ser.in_waiting
        if n <= 0:
            break
        out += ser.read(n)
        time.sleep(0.001)
    return out

def wait_for(ser, pattern, timeout, echo=True):
    """Espera regex 'pattern' hasta 'timeout'."""
    regex = re.compile(pattern, re.S)
    buf   = ""
    end   = time.time() + timeout
    while time.time() < end:
        data = read_available(ser)
        if data:
            s = data.decode(errors="ignore")
            buf += s
            if echo and s:
                print(s, end="", flush=True)
            if regex.search(buf):
                return buf
        time.sleep(READ_SLICE)
    raise TimeoutError(f"No apareció el patrón {pattern!r} en {timeout}s")

def send_line(ser, line):
    ser.write((line + EOL).encode())
    ser.flush()

def wait_prompt_once(ser, timeout):
    """Espera SOLO el PRIMER prompt y retorna al instante."""
    regex = re.compile(r"(?:^|\n)\s*(?:=>|Zynq-?MP>)\s*$", re.S)
    end = time.time() + timeout
    buf = ""
    while time.time() < end:
        data = read_available(ser)
        if data:
            s = data.decode(errors="ignore")
            buf += s
            print(s, end="", flush=True)  # eco
            if regex.search(buf):
                return
        time.sleep(READ_SLICE)
    raise TimeoutError("No apareció el prompt en tiempo")

def interrupt_autoboot(ser):
    """
    Si vemos 'Hit any key...' enviamos 1 espacio y esperamos SOLO el primer prompt.
    Si ya hay prompt, seguimos sin enviar nada.
    """
    try:
        buf = wait_for(
            ser,
            r"Hit any key to stop autoboot:|(?:^|\n)\s*(?:=>|Zynq-?MP>)\s*$",
            T_AUTOboot,
            echo=True
        )
        if re.search(r"(?:^|\n)\s*(?:=>|Zynq-?MP>)\s*$", buf):
            return
        ser.write(b" "); ser.flush()      # cortamos autoboot con UN espacio
        wait_prompt_once(ser, 2.0)
    except TimeoutError:
        send_line(ser, "")
        wait_prompt_once(ser, T_PROMPT)

def send_cmd(ser, cmd, wait_prompt=True, timeout=3.0):
    """Envía comando y, si se pide, espera SOLO el primer prompt."""
    print(f"[uboot] {cmd}")
    send_line(ser, cmd)
    if wait_prompt:
        wait_prompt_once(ser, timeout)

def ymodem_send(img_path: Path):
    # usa 'sb' (lrzsz). Necesita el puerto libre -> serial cerrado.
    run(f"cd '{APP_DIR}' && sb -vv --ymodem '{img_path.name}' < {PORT} > {PORT}",
        timeout=T_YMODEM)

def monitor_stream(ser):
    """Deja el puerto abierto mostrando salida hasta Ctrl+C."""
    print("\n--- Monitor serie activo (Ctrl+C para salir) ---\n")
    try:
        while True:
            data = read_available(ser)
            if data:
                try:
                    print(data.decode(errors="ignore"), end="", flush=True)
                except Exception:
                    pass
            time.sleep(READ_SLICE)
    except KeyboardInterrupt:
        print("\n[monitor] Cancelado por usuario (Ctrl+C). Cerrando puerto…")

def main():
    # 1) build imagen
    make_image()

    # 2) abrir serie y parar autoboot
    try:
        ser = open_serial()
    except Exception as e:
        print(f"ERROR abriendo {PORT}: {e}")
        sys.exit(2)

    print(f"[i] Abierto {PORT} @ {BAUD} (EOL=LF)")
    try:
        interrupt_autoboot(ser)

        # 3) prepara SD y modo YMODEM
        send_cmd(ser, "mmc dev 0; mmc rescan", wait_prompt=True, timeout=5.0)
        print("[i] Lanzando recepción YMODEM en U-Boot…")
        send_cmd(ser, f"loady {LOAD_ADDR}", wait_prompt=False, timeout=2.0)

        # U-Boot suele imprimir estas marcas al entrar en YMODEM
        try:
            wait_for(ser, r"(?:## Ready for binary|Ready for binary|C{1,})", 3.0, echo=True)
        except TimeoutError:
            pass

        # 4) cerrar puerto y enviar YMODEM
        ser.close()
        print("[i] Enviando rtems.img por YMODEM…")
        ymodem_send(IMG)

        # 5) reabrir, esperar PRIMER prompt y escribir + boot
        ser = open_serial()
        wait_prompt_once(ser, 10.0)
        send_cmd(ser, f"fatwrite {FAT_DEV} {LOAD_ADDR} rtems.img ${{filesize}}", wait_prompt=True, timeout=20.0)
        send_cmd(ser, f"bootm {LOAD_ADDR}", wait_prompt=False, timeout=2.0)

        # 6) monitor serie vivo hasta Ctrl+C
        monitor_stream(ser)
        ser.close()

    except Exception as e:
        try:
            ser.close()
        except Exception:
            pass
        print(f"ERROR: {e}")
        sys.exit(3)

if __name__ == "__main__":
    # salida limpia al SIGINT/SIGTERM
    signal.signal(signal.SIGINT, signal.default_int_handler)
    signal.signal(signal.SIGTERM, signal.SIG_DFL)
    main()
