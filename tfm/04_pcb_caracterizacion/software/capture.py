#!/usr/bin/env python3
"""capture.py — resetea la ZCU102 por JTAG y captura la consola hasta el final
del test (o hasta agotar el timeout). No toca la SD: arranca lo que ya hay.

  ./capture.py --out out/consola.txt --timeout 900
"""
import argparse, subprocess, sys, time
from pathlib import Path
import serial

HERE = Path(__file__).resolve().parent
END = "=== FIN DE LA CARACTERIZACION"

ap = argparse.ArgumentParser()
ap.add_argument("--port", default="/dev/ttyUSB0")
ap.add_argument("--baud", type=int, default=115200)
ap.add_argument("--out", default="out/consola.txt")
ap.add_argument("--timeout", type=int, default=900)
ap.add_argument("--no-reset", action="store_true")
a = ap.parse_args()

out = Path(a.out)
out.parent.mkdir(parents=True, exist_ok=True)

ser = serial.Serial(a.port, a.baud, timeout=1)
ser.reset_input_buffer()

if not a.no_reset:
    # El reset tarda unos segundos; se lanza en paralelo para no perder los
    # primeros bytes de la consola.
    subprocess.Popen(["bash", str(HERE / "jtag_reset.sh")],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

t0 = time.time()
lines, done = [], False
with out.open("w") as f:
    while time.time() - t0 < a.timeout:
        raw = ser.readline()
        if not raw:
            continue
        line = raw.decode("utf-8", "replace").rstrip("\r\n")
        print(line, flush=True)
        f.write(line + "\n")
        f.flush()
        lines.append(line)
        if END in line:
            done = True
            break

ser.close()
n_pcb = sum(1 for l in lines if l.startswith("PCB,"))
print(f"\n[capture] {'FIN detectado' if done else 'TIMEOUT'} — "
      f"{len(lines)} lineas, {n_pcb} filas PCB → {out}")
sys.exit(0 if done else 1)
