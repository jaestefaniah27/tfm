# -*- coding: utf-8 -*-
"""Parte el diagrama de topologias RS en sus dos mitades.

Apiladas dan una relacion de aspecto de 1,03: en una pantalla 16:9 eso obliga
a dejar la mitad del ancho sin usar. Por separado cada topologia ronda 2,5:1 y
llena el ancho completo, con la letra casi al doble de tamano.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "assets")
SRC = os.path.join(ASSETS, "diagrama_topologia_rs.png")

im = Image.open(SRC).convert("RGB")
w, h = im.size
px = im.load()


def fila_blanca(y):
    for x in range(0, w, 3):
        r, g, b = px[x, y]
        if r < 245 or g < 245 or b < 245:
            return False
    return True


# Banda blanca mas ancha en el tercio central: ahi esta la junta.
mejor = (0, 0, 0)
y = int(h * 0.30)
fin = int(h * 0.70)
while y < fin:
    if fila_blanca(y):
        y0 = y
        while y < fin and fila_blanca(y):
            y += 1
        if y - y0 > mejor[0]:
            mejor = (y - y0, y0, y)
    y += 1

alto, y0, y1 = mejor
corte = (y0 + y1) // 2
print("junta encontrada: %d px de alto, corte en y=%d de %d" % (alto, corte, h))


def recorta(caja, nombre):
    sub = im.crop(caja)
    # se quita el blanco sobrante alrededor
    bbox = sub.convert("L").point(lambda v: 0 if v > 244 else 255).getbbox()
    if bbox:
        pad = 12
        sub = sub.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad),
                        min(sub.size[0], bbox[2] + pad),
                        min(sub.size[1], bbox[3] + pad)))
    ruta = os.path.join(ASSETS, nombre)
    sub.save(ruta)
    print("%-38s %dx%d  AR=%.2f" % (nombre, sub.size[0], sub.size[1],
                                    sub.size[0] / sub.size[1]))


recorta((0, 0, w, corte), "diagrama_topologia_rs485.png")
recorta((0, corte, w, h), "diagrama_topologia_rs422.png")
