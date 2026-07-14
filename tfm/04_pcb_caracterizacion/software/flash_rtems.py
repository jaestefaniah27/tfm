#!/usr/bin/env python3
"""
Flujo completo, sin tocar la placa fisicamente:

  1. Reinicia la ZCU102 por JTAG (jtag_reset.sh)  -> aparece U-Boot.
  2. Interrumpe el autoboot.
  3. Sube rtems.img por YMODEM (loady + sb) y lo escribe en la FAT.
  4. Arranca (bootm) y CAPTURA la consola a un fichero hasta un patron de fin
     (o timeout), para poder leer el resultado del benchmark automaticamente.

Solo cambia rtems.img; el BOOT.bin de la SD no se toca.

Uso:
  flash_rtems.py --img RTEMS.IMG --out CONSOLA.TXT
                 [--end "=== FIN DEL BENCHMARK"] [--timeout 180]
                 [--port /dev/ttyUSB0] [--no-reset]
"""
import os, sys, time, re, subprocess, argparse
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESET_SH = HERE / "jtag_reset.sh"

LOAD_ADDR = "0x800000"
FAT_DEV   = "mmc 0:1"
EOL       = "\n"
BAUD      = 115200


def log(m): print(m, flush=True)


def jtag_reset_async():
    # El reset (connect de xsdb) tarda varios segundos y el bootdelay de U-Boot
    # es de ~2s: si esperamos a que termine el reset, la ventana de autoboot ya
    # ha pasado. Lo lanzamos en paralelo y escuchamos el serie a la vez.
    log("[flash] reiniciando la placa por JTAG (en paralelo)…")
    return subprocess.Popen(["bash", str(RESET_SH)],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def fpga_program(bit: Path):
    """Reconfigura la PL por JTAG con la placa parada en el prompt de U-Boot.

    Sirve para probar un bitstream nuevo SIN reescribir los 28 MB de BOOT.bin en
    la SD por YMODEM (~40 min). OJO: NO es persistente — al siguiente reset la
    BootROM vuelve a cargar el bitstream que hay en el BOOT.bin de la SD.
    """
    log(f"\n[flash] programando la PL por JTAG con {bit.name}…")
    tcl = f"""
connect
targets -set -filter {{name =~ "PL"}}
fpga -file {bit}
puts "FPGA_OK"
exit
"""
    p = Path("/tmp/_fpga_prog.tcl"); p.write_text(tcl)
    r = subprocess.run(
        f"source /tools/Xilinx/2025.1/Vitis/settings64.sh; "
        f"/tools/Xilinx/2025.1/Vitis/bin/xsdb {p}",
        shell=True, executable="/bin/bash", capture_output=True, text=True, timeout=300)
    if "FPGA_OK" not in r.stdout:
        log(f"ERROR: fallo al programar la PL:\n{r.stdout}\n{r.stderr}")
        sys.exit(1)
    log("[flash] PL reconfigurada con el bitstream nuevo")


def open_serial(port):
    import serial
    ser = serial.Serial(port, BAUD, timeout=0, write_timeout=2)
    ser.reset_input_buffer(); ser.reset_output_buffer()
    return ser


def read_avail(ser):
    out = b""
    while ser.in_waiting > 0:
        out += ser.read(ser.in_waiting)
        time.sleep(0.001)
    return out


def wait_for(ser, pattern, timeout, echo=True):
    rx = re.compile(pattern, re.S)
    buf = ""; end = time.time() + timeout
    while time.time() < end:
        d = read_avail(ser)
        if d:
            s = d.decode(errors="ignore"); buf += s
            if echo: print(s, end="", flush=True)
            if rx.search(buf):
                return buf
        time.sleep(0.02)
    raise TimeoutError(f"patron {pattern!r} no aparecio en {timeout}s")


def send_line(ser, line):
    ser.write((line + EOL).encode()); ser.flush()


PROMPT = r"(?:^|\n)\s*(?:=>|ZynqMP>|Zynq-?MP>)\s*$"


def wait_prompt(ser, timeout):
    return wait_for(ser, PROMPT, timeout)


def interrupt_autoboot(ser):
    # El boot de esta placa es lento (~18s: timeouts de SATA, escaneo USB), asi
    # que el autoboot puede tardar. Margen amplio.
    buf = wait_for(ser, r"Hit any key to stop autoboot:|" + PROMPT, 75.0)
    if re.search(PROMPT, buf):
        return
    ser.write(b" "); ser.flush()
    wait_prompt(ser, 15.0)


def fatwrite_via_ymodem(ser, port, file_path: Path, target_name: str):
    log(f"\n[flash] enviando {file_path.name} como {target_name} por YMODEM…")
    send_line(ser, f"loady {LOAD_ADDR}")
    try:
        wait_for(ser, r"(?:Ready for binary|C{2,})", 3.0)
    except TimeoutError:
        pass
    ser.close()
    
    # A 115200 el YMODEM va a ~11 KB/s: rtems.img (85 KB) tarda segundos, pero
    # BOOT.bin (28 MB) necesita ~45 min. Timeout proporcional al tamaño, con
    # holgura x2, y nunca menos de 600 s.
    est = file_path.stat().st_size / 11000.0
    tmo = max(600.0, est * 2.0)
    log(f"[flash] {file_path.stat().st_size/1e6:.1f} MB por YMODEM: "
        f"~{est/60:.0f} min estimados (timeout {tmo/60:.0f} min)")
    subprocess.run(f"sb --ymodem '{file_path}' < {port} > {port}",
                   shell=True, check=True, timeout=tmo)
                   
    ser = open_serial(port)
    wait_prompt(ser, 10.0)
    send_line(ser, f"fatwrite {FAT_DEV} {LOAD_ADDR} {target_name} ${{filesize}}")
    wait_prompt(ser, 20.0)
    return ser

def upload(ser, port, img: Path, boot: Path = None):
    send_line(ser, "mmc dev 0; mmc rescan"); wait_prompt(ser, 5.0)
    if boot:
        ser = fatwrite_via_ymodem(ser, port, boot, "BOOT.bin")
    ser = fatwrite_via_ymodem(ser, port, img, "rtems.img")
    send_line(ser, f"bootm {LOAD_ADDR}")
    return ser


def capture(ser, out_path: Path, end_pat, timeout):
    log(f"\n[flash] capturando consola hasta {end_pat!r} (max {timeout}s)…\n")
    rx = re.compile(end_pat)
    buf = ""; end = time.time() + timeout
    with open(out_path, "w") as f:
        while time.time() < end:
            d = read_avail(ser)
            if d:
                s = d.decode(errors="ignore")
                print(s, end="", flush=True)
                f.write(s); f.flush()
                buf += s
                if rx.search(buf):
                    log(f"\n[flash] patron de fin detectado. Consola en {out_path}")
                    return True
                if len(buf) > 65536:
                    buf = buf[-8192:]
            else:
                time.sleep(0.02)
    log(f"\n[flash] timeout de captura. Lo recibido esta en {out_path}")
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--img", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--boot", default=None)
    ap.add_argument("--end", default=r"=== FIN DEL BENCHMARK")
    ap.add_argument("--timeout", type=float, default=180.0)
    ap.add_argument("--port", default=os.environ.get("RTEMS_SERIAL", "/dev/ttyUSB0"))
    ap.add_argument("--no-reset", action="store_true")
    ap.add_argument("--fpga", default=None,
                    help="reconfigura la PL por JTAG con este .bit (no persistente)")
    a = ap.parse_args()

    img = Path(a.img).resolve()
    if not img.exists():
        log(f"ERROR: no existe {img}"); sys.exit(1)
        
    boot_path = None
    if a.boot:
        boot_path = Path(a.boot).resolve()
        if not boot_path.exists():
            log(f"ERROR: no existe {boot_path}"); sys.exit(1)

    ser = open_serial(a.port)
    log(f"[flash] {a.port} @ {BAUD}")
    rst_proc = None
    if not a.no_reset:
        rst_proc = jtag_reset_async()   # corre mientras escuchamos el autoboot
    try:
        interrupt_autoboot(ser)
        if rst_proc is not None:
            rst_proc.wait(timeout=30)
        if a.fpga:
            # La PL se reconfigura con la placa detenida en U-Boot: el PS sigue
            # vivo, y RTEMS (que aun no ha arrancado) inicializara el MCDMA
            # despues, ya sobre el diseño nuevo.
            fpga_program(Path(a.fpga).resolve())
        ser = upload(ser, a.port, img, boot_path)
        ok = capture(ser, Path(a.out), a.end, a.timeout)
    finally:
        try: ser.close()
        except Exception: pass
    sys.exit(0 if ok else 2)


if __name__ == "__main__":
    main()
