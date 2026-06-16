#!/usr/bin/env python3
# serial_gui_hex.py
# GUI para monitorizar y editar registros (valores en hexadecimal).
# - muestra campos en hex
# - DUMP actualiza todos los campos
# - al editar, envía comandos SET ... (en decimal) al RTEMS

import sys
import serial
import threading
from functools import partial
from PyQt6 import QtWidgets, QtCore

# -------------------------
# Estado de registros (valores enteros)
# -------------------------
REG_STATE = {
    "GPIO0": {"RAW": 0, "BAUD": 0, "STOP": 0, "PARITY": 0, "DATABITS": 0, "BITORDER": 0},
    "GPIO1": {"RAW": 0, "DATA_READ": 0, "ERROR_OK": 0},
    "GPIO2": {"RAW": 0, "DATA_IN": 0, "TX_SEND": 0},
    "GPIO3": {"RAW": 0, "DATA": 0, "EMPTY": 0, "TXRDY": 0, "FULL": 0, "FRAME_ERR": 0, "PAR_ERR": 0},
}
STATE_LOCK = threading.Lock()

# -------------------------
# Parser CHG lines
# -------------------------
def parse_chg_line(line: str):
    """
    CHG <REG>.<NAME> KEY=VAL ...
    VAL puede ser 0x... o decimal
    Actualiza todos los campos en REG_STATE con los valores parseados.
    """
    try:
        parts = line.strip().split()
        if len(parts) < 3:
            return
        reg = parts[1].split('.')[0]  # e.g. GPIO0

        with STATE_LOCK:
            # actualizar todos los campos que vengan
            for token in parts[2:]:
                if '=' not in token:
                    continue
                key, val = token.split('=', 1)
                key = key.strip()
                val = val.strip()
                try:
                    if val.lower().startswith('0x'):
                        iv = int(val, 16)
                    else:
                        iv = int(val, 10)
                except Exception:
                    # si no es numérico, lo guardamos tal cual (poco probable)
                    continue
                # actualizar solo si la clave está en el dict (evitar crear keys raras)
                if reg in REG_STATE:
                    REG_STATE[reg][key] = iv
    except Exception as e:
        print("parse error:", e)

# -------------------------
# Serial Reader Thread
# -------------------------
class SerialReader(threading.Thread):
    def __init__(self, ser, callback_line):
        super().__init__(daemon=True)
        self.ser = ser
        self.callback_line = callback_line

    def run(self):
        buf = ""
        while True:
            try:
                ch = self.ser.read().decode(errors="ignore")
                if ch == "\n":
                    line = buf.strip()
                    buf = ""
                    if line:
                        if line.startswith("CHG"):
                            self.callback_line(line)
                        else:
                            print("[RTEMS]", line)
                else:
                    buf += ch
            except Exception as e:
                print("Serial read error:", e)
                break

# -------------------------
# Utilidades de formato
# -------------------------
def to_hex_str(v: int, width: int = 0):
    """Formato 0x... mayúsculas; ancho mínimo en dígitos hex (sin 0x)"""
    if isinstance(v, int):
        if width > 0:
            return "0x{:0{}X}".format(v, width)
        return "0x{:X}".format(v)
    return str(v)

def parse_int_from_text(txt: str):
    """Acepta '0x..' o decimal. Devuelve int o None."""
    s = txt.strip()
    if s.lower().startswith("0x"):
        try:
            return int(s, 16)
        except:
            return None
    try:
        return int(s, 10)
    except:
        return None

# -------------------------
# Widgets
# -------------------------
class HexEdit(QtWidgets.QLineEdit):
    """QLineEdit especializado para mostrar hex y detectar edición.
       editingFinished se usa para confirmar valor; text() contiene '0x...' cuando se actualiza desde código.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setPlaceholderText("0x0")
        # permitir seleccionar todo al focus
        self.selectAllOnFocus = True

    def focusInEvent(self, ev):
        super().focusInEvent(ev)
        # seleccionar todo para edición rápida
        QtCore.QTimer.singleShot(0, self.selectAll)

class RegWidget(QtWidgets.QWidget):
    """
    Widget general para un registro. 
    fields: dict nombre -> spec
    spec: {"type": "label"|"hex_edit"|"dec_edit", "width": optional hex digits, "toggle": bool}
    regname: "GPIO0", "GPIO1", ...
    send_command_fn: callable(cmd_str)
    """
    def __init__(self, title, fields, send_command_fn, regname):
        super().__init__()
        self.title = title
        self.fields = fields
        self.send_cmd = send_command_fn
        self.regname = regname  # "GPIO0", "GPIO1", ...
        self.editors = {}  # name -> widget (HexEdit/DecEdit/QLabel)
        self._build_ui()

    def _build_ui(self):
        layout = QtWidgets.QGridLayout(self)
        row = 0
        layout.addWidget(QtWidgets.QLabel(f"<b>{self.title}</b>"), row, 0, 1, 3)
        row += 1

        for fname, spec in self.fields.items():
            layout.addWidget(QtWidgets.QLabel(fname), row, 0)

            if spec["type"] == "label":
                lab = QtWidgets.QLabel("0x0")
                self.editors[fname] = lab
                layout.addWidget(lab, row, 1)

            elif spec["type"] == "hex_edit":
                he = HexEdit()
                he.setMaximumWidth(180)
                # use functools.partial to bind fname and widget cleanly
                he.editingFinished.connect(partial(self._on_edit_finished, fname, he))
                self.editors[fname] = he
                layout.addWidget(he, row, 1)

                if spec.get("toggle", False):
                    btn = QtWidgets.QPushButton("Toggle")
                    btn.setMaximumWidth(80)
                    btn.clicked.connect(partial(self._on_toggle_clicked, fname))
                    layout.addWidget(btn, row, 2)

            
            else:
                # unknown spec type -> treat as label
                lab = QtWidgets.QLabel("?")
                self.editors[fname] = lab
                layout.addWidget(lab, row, 1)

            row += 1

    def _on_edit_finished(self, field, widget):
        """Called when editingFinished fires for hex or dec editors."""
        txt = widget.text().strip()
        # decide parse based on widget type
        val = parse_int_from_text(txt)
        if val is None:
            with STATE_LOCK:
                cur = REG_STATE[self.regname].get(field, 0)
            widget.setText(to_hex_str(cur))
            return

        # Build command exactly as C expects
        if self.regname == "GPIO0":
            cmd = f"SET SERIAL {field} {val}"
        else:
            cmd = f"SET {self.regname} {field} {val}"

        # send and update local state
        self.send_cmd(cmd)
        with STATE_LOCK:
            REG_STATE[self.regname][field] = val

        # normalize display: hex for HexEdit, decimal for DecEdit
        widget.setText(to_hex_str(val))

    def _on_toggle_clicked(self, field):
        """Toggle a 1-bit field: flip, send SET, update local state and widget."""
        with STATE_LOCK:
            cur = int(REG_STATE.get(self.regname, {}).get(field, 0))
        new = 0 if cur else 1

        if self.regname == "GPIO0":
            cmd = f"SET SERIAL {field} {new}"
        else:
            cmd = f"SET {self.regname} {field} {new}"

        self.send_cmd(cmd)

        # update local state
        with STATE_LOCK:
            REG_STATE[self.regname][field] = new

        # update widget visual
        w = self.editors.get(field)
        w.setText(to_hex_str(new))
        # HexEdit or DecEdit
        old = w.blockSignals(True)
        w.setText(to_hex_str(new))
        w.blockSignals(old)

    def update_values(self, reg_state):
        """Update widgets from reg_state (respecting focus on editors)."""
        for fname, spec in self.fields.items():
            if fname not in reg_state:
                continue
            val = reg_state[fname]
            w = self.editors.get(fname)
            if w is None:
                continue
            if isinstance(w, QtWidgets.QLabel):
                w.setText(to_hex_str(val))
            else:
                # do not override if user is editing (has focus)
                if w.hasFocus():
                    continue
                old = w.blockSignals(True)
                w.setText(to_hex_str(val))
                w.blockSignals(old)
               
# -------------------------
# Ventana Principal
# -------------------------
class MainWindow(QtWidgets.QMainWindow):
    def __init__(self, ser):
        super().__init__()
        self.ser = ser
        self.setWindowTitle("FPGA Serial Register Monitor (hex)")

        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        layout = QtWidgets.QVBoxLayout(central)

        # Widgets: definimos campos y si son editables
        self.reg0 = RegWidget("GPIO0.SERIAL_CONFIG",
            {"RAW": {"type": "label"},
             "BAUD": {"type": "hex_edit", "width": 6},
             "STOP": {"type": "hex_edit", "width": 1},
             "PARITY": {"type": "hex_edit", "width": 1},
             "DATABITS": {"type": "hex_edit", "width": 1},
             "BITORDER": {"type": "hex_edit", "width": 1, "toggle": True}},
            self.send_cmd, regname="GPIO0")

        self.reg1 = RegWidget("GPIO1.RX_CTRL",
            {"RAW": {"type": "label"},
             "DATA_READ": {"type": "hex_edit", "width":1, "toggle": True},
             "ERROR_OK": {"type": "hex_edit", "width":1, "toggle": True}},
            self.send_cmd, regname="GPIO1")

        self.reg2 = RegWidget("GPIO2.TX_CTRL",
            {"RAW": {"type": "label"},
             "DATA_IN": {"type": "hex_edit", "width": 3},
             "TX_SEND": {"type": "hex_edit", "width": 1, "toggle": True}},
            self.send_cmd, regname="GPIO2")

        self.reg3 = RegWidget("GPIO3.PS_OUT",
            {"RAW": {"type": "label"},
             "DATA": {"type": "label"},
             "EMPTY": {"type": "label"},
             "TXRDY": {"type": "label"},
             "FULL": {"type": "label"},
             "FRAME_ERR": {"type": "label"},
             "PAR_ERR": {"type": "label"}},
            self.send_cmd, regname="GPIO3")

        layout.addWidget(self.reg0)
        layout.addWidget(self.reg1)
        layout.addWidget(self.reg2)

        # --- Campo y botón para TX BYTE (colocado tras self.reg2) ---
        tx_h = QtWidgets.QHBoxLayout()
        self.tx_byte_input = QtWidgets.QLineEdit()
        self.tx_byte_input.setPlaceholderText("0x41 or 65")
        self.tx_byte_input.setMaximumWidth(120)
        tx_send_btn = QtWidgets.QPushButton("Send TX BYTE")
        tx_send_btn.clicked.connect(self.send_tx_byte_from_ui)
        tx_h.addWidget(QtWidgets.QLabel("TX BYTE:"))
        tx_h.addWidget(self.tx_byte_input)
        tx_h.addWidget(tx_send_btn)
        layout.addLayout(tx_h)

        layout.addWidget(self.reg3)

        # Log
        self.log = QtWidgets.QTextEdit()
        self.log.setReadOnly(True)
        layout.addWidget(self.log)

        # Buttons: DUMP & GET SERIAL
        h = QtWidgets.QHBoxLayout()
        b_dump = QtWidgets.QPushButton("DUMP")
        b_dump.clicked.connect(lambda: self.send_cmd("DUMP"))
        h.addWidget(b_dump)
        b_gets = QtWidgets.QPushButton("GET SERIAL")
        b_gets.clicked.connect(lambda: self.send_cmd("GET SERIAL"))
        h.addWidget(b_gets)
        layout.addLayout(h)

        # Timer para refrescar GUI de forma periódica (leer REG_STATE)
        self.timer = QtCore.QTimer()
        self.timer.timeout.connect(self.update_gui)
        self.timer.start(150)

        # Auto-request initial DUMP on startup (to populate fields)
        QtCore.QTimer.singleShot(300, lambda: self.send_cmd("DUMP"))

    def send_cmd(self, cmd: str):
        try:
            self.ser.write((cmd + "\n").encode())
        except Exception as e:
            print("serial write error:", e)

    def send_tx_byte_from_ui(self):
        """Leer el campo TX byte y enviar 'TX BYTE 0x..' al RTEMS."""
        # preferimos el contenido del input; si está vacío tomamos DATA_IN actual
        txt = self.tx_byte_input.text().strip()
        if txt == "":
            # tomar el valor actual de REG_STATE GPIO2.DATA_IN
            with STATE_LOCK:
                v = REG_STATE.get("GPIO2", {}).get("DATA_IN", 0)
        else:
            # aceptar 0x.. o decimal
            v = parse_int_from_text(txt)
            if v is None:
                self.log.append(f"ERR: valor inválido para TX BYTE: '{txt}'")
                return

        # limitar a 9 bits por especificación
        v &= 0x1FF
        # enviar con formato que el C acepta (acepta 0x.. o decimal; usamos 0x.. para claridad)
        self.send_cmd(f"TX BYTE {v:X}")
        self.log.append(f"SENT: TX BYTE 0x{v:X}")

    def update_gui(self):
        with STATE_LOCK:
            # Actualizamos todo desde el estado (los RegWidget gestionan focus)
            self.reg0.update_values(REG_STATE["GPIO0"])
            self.reg1.update_values(REG_STATE["GPIO1"])
            self.reg2.update_values(REG_STATE["GPIO2"])
            self.reg3.update_values(REG_STATE["GPIO3"])

    def handle_chg_line(self, line: str):
        parse_chg_line(line)
        self.log.append(line)

# -------------------------
# MAIN
# -------------------------
def main():
    # Ajusta aquí el puerto que conecta al USB-PS
    PORT = "/dev/ttyUSB0"
    BAUD = 115200
    try:
        ser = serial.Serial(PORT, BAUD, timeout=0.1)
    except Exception as e:
        print("Error opening serial port:", e)
        return

    app = QtWidgets.QApplication(sys.argv)
    win = MainWindow(ser)
    win.resize(760, 900)
    win.show()

    reader = SerialReader(ser, win.handle_chg_line)
    reader.start()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
