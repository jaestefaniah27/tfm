# -*- coding: utf-8 -*-
"""Graficas de resultados para la presentacion del TFM.

Formato apaisado para que ocupen el ancho de la pantalla de proyeccion. Las
leyendas van fuera de los ejes, a la derecha, para no robar altura al area de
datos: en pantalla el alto es el recurso escaso, no el ancho.
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")
os.makedirs(OUT, exist_ok=True)

NAVY = "#12345C"
BLUE = "#1E63A8"
GOLD = "#E09B2D"
CLAY = "#C2685C"
GREY = "#9AA5B1"
INK = "#1F2933"
LINE = "#D5DBE2"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 16,
    "axes.edgecolor": LINE,
    "axes.labelcolor": INK,
    "text.color": INK,
    "xtick.color": INK,
    "ytick.color": INK,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "savefig.facecolor": "white",
})

WIDE = (13.2, 4.7)     # grafica protagonista de una diapositiva
STRIP = (13.2, 4.4)    # franja ancha, media diapositiva


def save(fig, name):
    path = os.path.join(OUT, name)
    fig.savefig(path, dpi=200, bbox_inches="tight", pad_inches=0.18)
    plt.close(fig)
    print("ok", name)


def side_legend(ax, handles, labels, fontsize=15):
    """Leyenda fuera del area de datos, pegada al margen derecho."""
    return ax.legend(handles, labels, frameon=False, fontsize=fontsize,
                     loc="center left", bbox_to_anchor=(1.015, 0.5),
                     handlelength=1.5, handletextpad=0.7, labelspacing=1.1,
                     borderaxespad=0.0)


def note_legend(ax, text, fontsize=15, color=NAVY):
    """Bloque de texto en el margen derecho, donde iria la leyenda."""
    ax.text(1.03, 0.5, text, transform=ax.transAxes, va="center", ha="left",
            fontsize=fontsize, color=color, fontweight="bold", linespacing=1.5)


# ---------------------------------------------------------------- throughput
def chart_throughput():
    baud = [115200, 230400, 460800, 921600, 1000000, 2000000, 4000000]
    gpio = [3471, 4087, 4485, 4714, 4733, 4848, 4907]
    mcdma = [11458, 22789, 45104, 88298, 96186, 183053, 344781]

    fig, ax = plt.subplots(figsize=WIDE)
    fig.subplots_adjust(right=0.82)
    l1, = ax.loglog(baud, mcdma, "o-", color=BLUE, lw=3.4, ms=10, zorder=3)
    l2, = ax.loglog(baud, gpio, "s-", color=CLAY, lw=3.4, ms=10, zorder=3)
    ax.grid(True, which="both", color=LINE, lw=0.8, alpha=0.8)
    ax.set_axisbelow(True)
    ax.set_xlabel("Velocidad de línea (baudios)")
    ax.set_ylabel("Caudal útil (B/s)")
    ax.set_ylim(2200, 620000)
    ax.set_xlim(9.5e4, 5.2e6)
    ax.set_xticks([115200, 230400, 460800, 921600, 2000000, 4000000])
    ax.set_xticklabels(["115,2 k", "230,4 k", "460,8 k", "921,6 k", "2 M", "4 M"],
                       fontsize=14)
    ax.get_xaxis().set_minor_formatter(plt.NullFormatter())
    ax.yaxis.set_major_formatter(FuncFormatter(
        lambda v, p: f"{v/1000:.0f} k" if v >= 1000 else f"{v:.0f}"))
    ax.annotate("344.781 B/s", xy=(4000000, 344781), xytext=(1.25e6, 430000),
                color=BLUE, fontsize=17, fontweight="bold")
    ax.annotate("saturado en 4.907 B/s", xy=(4000000, 4907),
                xytext=(1.45e5, 7200), color=CLAY, fontsize=17,
                fontweight="bold")
    ax.annotate("", xy=(3.2e6, 270000), xytext=(3.2e6, 5300),
                arrowprops=dict(arrowstyle="<->", color=NAVY, lw=2.4))
    ax.text(3.45e6, 40000, "70×", fontsize=30, fontweight="bold",
            color=NAVY, ha="left", va="center")
    side_legend(ax, [l1, l2], ["C · MCDMA", "A · GPIO"], fontsize=16)
    save(fig, "chart_throughput.png")


# ---------------------------------------------------------------- IRQ por KB
def chart_irq():
    fig, ax = plt.subplots(figsize=STRIP)
    fig.subplots_adjust(right=0.80)
    names = ["A · GPIO", "B · DMA14", "C · MCDMA"]
    vals = [1250, 3.8, 3]
    cols = [CLAY, GREY, BLUE]
    ypos = [2, 1, 0]
    bars = ax.barh(ypos, vals, color=cols, height=0.62, zorder=3)
    ax.set_xscale("log")
    ax.set_xlim(1, 9000)
    ax.set_yticks(ypos)
    ax.set_yticklabels(names)
    ax.set_xlabel("Interrupciones por KB  ·  escala logarítmica")
    ax.grid(axis="x", color=LINE, lw=0.8)
    ax.set_axisbelow(True)
    for b, v, t in zip(bars, vals, ["1.250", "3,8", "3"]):
        ax.text(v * 1.4, b.get_y() + b.get_height() / 2, t, va="center",
                fontsize=21, fontweight="bold", color=INK)
    note_legend(ax, "≈ 400× menos\ninterrupciones\nen MCDMA")
    ax.text(1.0, -0.26, "DMA14: sólo transmisión", transform=ax.transAxes,
            fontsize=12.5, color=GREY, ha="right")
    save(fig, "chart_irq.png")


# ---------------------------------------------------------------- ocupacion
def chart_lut():
    fig, ax = plt.subplots(figsize=STRIP)
    fig.subplots_adjust(right=0.76)
    names = ["A · GPIO", "B · DMA14", "C · MCDMA"]
    base = [2.35, 14.67, 5.18]
    tmr = [b * 3 for b in base]
    ypos = [2, 1, 0]
    b1 = ax.barh([y + 0.19 for y in ypos], base, height=0.36,
                 color=[CLAY, GREY, BLUE], zorder=3)
    b2 = ax.barh([y - 0.19 for y in ypos], tmr, height=0.36, color="white",
                 zorder=3, edgecolor=NAVY, hatch="///", lw=1.4)
    ax.set_yticks(ypos)
    ax.set_yticklabels(names)
    ax.set_xlabel("Ocupación de LUT del XCZU9EG (%)")
    ax.set_xlim(0, 54)
    ax.grid(axis="x", color=LINE, lw=0.8)
    ax.set_axisbelow(True)
    for y, b, t in zip(ypos, base, tmr):
        ax.text(b + 0.8, y + 0.19, f"{b:.2f}".replace(".", ",") + " %",
                va="center", fontsize=14, fontweight="bold")
        ax.text(t + 0.8, y - 0.19, f"{t:.0f} %", va="center", fontsize=14,
                color=NAVY, fontweight="bold")
    side_legend(ax, [b1[2], b2[0]],
                ["implementado", "proyección ×3\ncon TMR"], fontsize=14)
    save(fig, "chart_lut.png")


# ---------------------------------------------------------------- latencia
def chart_latencia():
    fig, ax = plt.subplots(figsize=STRIP)
    fig.subplots_adjust(right=0.78)
    ypos = [1, 0]
    vals = [4606, 1530]
    bars = ax.barh(ypos, vals, color=[CLAY, BLUE], height=0.46, zorder=3)
    ax.set_yticks(ypos)
    ax.set_yticklabels(["A · GPIO", "C · MCDMA"])
    ax.set_xlabel("Latencia media de una trama de 11 B (µs)")
    ax.set_xlim(0, 5600)
    ax.grid(axis="x", color=LINE, lw=0.8)
    ax.set_axisbelow(True)
    for b, v in zip(bars, vals):
        ax.text(v + 120, b.get_y() + b.get_height() / 2,
                f"{v:,}".replace(",", ".") + " µs", va="center",
                fontsize=19, fontweight="bold")
    note_legend(ax, "3× más rápido\ny determinista:\n6 µs de dispersión",
                fontsize=14)
    save(fig, "chart_latencia.png")


# ---------------------------------------------------------------- SLO
def chart_slo():
    fig, ax = plt.subplots(figsize=STRIP)
    fig.subplots_adjust(right=0.74)
    names = ["Bus A · RS485 · 7 nodos", "Bus B · RS422", "Bus C · RS422"]
    slo0 = [0.4608, 1.0, 1.0]
    slo1 = [4.0, 4.0, 4.0]
    ypos = [2, 1, 0]
    b0 = ax.barh([y + 0.19 for y in ypos], slo0, height=0.36, color=GREY,
                 zorder=3)
    b1 = ax.barh([y - 0.19 for y in ypos], slo1, height=0.36, color=GOLD,
                 zorder=3)
    ax.set_yticks(ypos)
    ax.set_yticklabels(names, fontsize=14)
    ax.set_xlabel("Velocidad máxima sin errores (Mbaudios)")
    ax.set_xlim(0, 4.7)
    ax.grid(axis="x", color=LINE, lw=0.8)
    ax.set_axisbelow(True)
    for y, a, b in zip(ypos, slo0, slo1):
        ax.text(a + 0.08, y + 0.19,
                f"{a:.2f}".rstrip("0").rstrip(".").replace(".", ","),
                va="center", fontsize=15, fontweight="bold")
        ax.text(b + 0.08, y - 0.19, "4,0", va="center", fontsize=15,
                fontweight="bold", color="#9A6410")
    side_legend(ax, [b0[0], b1[0]],
                ["limitador activo\n(por defecto)", "limitador\ndesactivado"],
                fontsize=14)
    save(fig, "chart_slo.png")


# ---------------------------------------------------------------- codigo
def chart_codigo():
    fig, ax = plt.subplots(figsize=STRIP)
    fig.subplots_adjust(right=0.84)
    labels = ["TCL · automatización", "VHDL · RTL", "VHDL · testbench",
              "C · driver y apps", "Python", "Bash", "XDC"]
    vals = [5338, 4710, 4551, 2617, 1525, 1231, 216]
    cols = [GOLD, NAVY, BLUE, CLAY, "#4C8C8C", "#7E8B99", LINE]
    ypos = list(range(len(vals)))[::-1]
    ax.barh(ypos, vals, color=cols, height=0.66, zorder=3)
    ax.set_yticks(ypos)
    ax.set_yticklabels(labels, fontsize=14)
    ax.set_xlim(0, 6300)
    ax.set_xlabel("Líneas de código propio")
    ax.grid(axis="x", color=LINE, lw=0.8)
    ax.set_axisbelow(True)
    for y, v in zip(ypos, vals):
        ax.text(v + 110, y, f"{v:,}".replace(",", "."), va="center",
                fontsize=14, fontweight="bold")
    note_legend(ax, "20.188 líneas\nen total\n\nautomatización\n40,1 %",
                fontsize=14)
    save(fig, "chart_codigo.png")


if __name__ == "__main__":
    chart_throughput()
    chart_irq()
    chart_lut()
    chart_latencia()
    chart_slo()
    chart_codigo()
