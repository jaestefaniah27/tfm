# -*- coding: utf-8 -*-
"""Presentacion de defensa del TFM (16:9, python-pptx).

Las fotografias y las capturas de osciloscopio van en diapositivas propias, a
sangre o a altura completa sobre fondo oscuro: en proyeccion una foto pequena
no se ve, y el detalle (soldadura, jumpers, reflexiones del bus) es la prueba.
Las graficas se generan en formato apaisado con charts.py.
"""
import os
import re
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml import parse_xml
from pptx.oxml.ns import qn, nsdecls
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "assets")
CACHE = os.path.join(HERE, "fotos")
os.makedirs(CACHE, exist_ok=True)
IMG = r"C:\Users\jaest\OneDrive\Documentos\4_TELECO\TFM\tfm\plantilla_tft_etsit\IMG"
OUTDIR = r"C:\Users\jaest\OneDrive\Documentos\4_TELECO\TFM\tfm\Presentacion"
OUTPUT = os.environ.get("TFM_PPTX_OUT",
                        os.path.join(OUTDIR, "Presentacion_TFM_Jorge_Estefania.pptx"))
os.makedirs(OUTDIR, exist_ok=True)

# ----------------------------------------------------------------- paleta
NAVY = RGBColor(0x12, 0x34, 0x5C)
DEEP = RGBColor(0x0B, 0x1E, 0x36)
BLUE = RGBColor(0x1E, 0x63, 0xA8)
GOLD = RGBColor(0xE0, 0x9B, 0x2D)
CLAY = RGBColor(0xC2, 0x68, 0x5C)
INK = RGBColor(0x1F, 0x29, 0x33)
MUTE = RGBColor(0x62, 0x70, 0x7E)
LINE = RGBColor(0xD5, 0xDB, 0xE2)
BG = RGBColor(0xFF, 0xFF, 0xFF)
SOFT = RGBColor(0xF4, 0xF6, 0xF9)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
PALE = RGBColor(0x9F, 0xB6, 0xD1)

FONT = "Calibri"
W, H = Inches(13.333), Inches(7.5)
MARGIN = Inches(0.72)
CONTENT_W = W - 2 * MARGIN

prs = Presentation()
prs.slide_width, prs.slide_height = W, H
BLANK = prs.slide_layouts[6]


# ----------------------------------------------------------------- imagenes
def prepared(path, long_side=2200):
    """Reescala la foto para que el pptx no se dispare de tamano."""
    key = "prep_%d_%s.jpg" % (long_side, os.path.splitext(os.path.basename(path))[0])
    out = os.path.join(CACHE, key)
    if not os.path.exists(out):
        im = Image.open(path).convert("RGB")
        if max(im.size) > long_side:
            im.thumbnail((long_side, long_side), Image.LANCZOS)
        im.save(out, quality=88, subsampling=1)
    return out


def trimmed(path, tol=14):
    """Quita el marco liso que rodea a algunas capturas de catalogo."""
    key = "trim_" + os.path.splitext(os.path.basename(path))[0] + ".jpg"
    out = os.path.join(CACHE, key)
    if not os.path.exists(out):
        im = Image.open(path).convert("RGB")
        px = im.load()
        w, h = im.size
        ref = px[0, 0]

        def uniform(vals):
            return all(abs(c - r) <= tol for v in vals for c, r in zip(v, ref))

        top, bot, left, right = 0, h - 1, 0, w - 1
        step = max(1, w // 200)
        while top < bot and uniform([px[x, top] for x in range(0, w, step)]):
            top += 1
        while bot > top and uniform([px[x, bot] for x in range(0, w, step)]):
            bot -= 1
        step = max(1, h // 200)
        while left < right and uniform([px[left, y] for y in range(0, h, step)]):
            left += 1
        while right > left and uniform([px[right, y] for y in range(0, h, step)]):
            right -= 1
        pad = 4
        im = im.crop((max(0, left - pad), max(0, top - pad),
                      min(w, right + pad), min(h, bot + pad)))
        if max(im.size) > 2200:
            im.thumbnail((2200, 2200), Image.LANCZOS)
        im.save(out, quality=90, subsampling=1)
    return out


def cover(path, ar=16 / 9.0, anchor=0.5, long_side=2400):
    """Recorta al centro (o a la fraccion `anchor`) hasta la relacion pedida."""
    key = "cov_%.3f_%.2f_%s.jpg" % (ar, anchor,
                                    os.path.splitext(os.path.basename(path))[0])
    out = os.path.join(CACHE, key)
    if not os.path.exists(out):
        im = Image.open(path).convert("RGB")
        w, h = im.size
        if w / h > ar:
            nw = int(round(h * ar))
            x = int((w - nw) * anchor)
            im = im.crop((x, 0, x + nw, h))
        else:
            nh = int(round(w / ar))
            y = int((h - nh) * anchor)
            im = im.crop((0, y, w, y + nh))
        if max(im.size) > long_side:
            im.thumbnail((long_side, long_side), Image.LANCZOS)
        im.save(out, quality=88, subsampling=1)
    return out


# ----------------------------------------------------------------- helpers
def add_slide(notes=""):
    s = prs.slides.add_slide(BLANK)
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = BG
    if notes:
        s.notes_slide.notes_text_frame.text = notes
    return s


def rect(s, x, y, w, h, fill=None, line=None, lw=1.0, shape=MSO_SHAPE.RECTANGLE):
    sh = s.shapes.add_shape(shape, x, y, w, h)
    if fill is None:
        sh.fill.background()
    else:
        sh.fill.solid()
        sh.fill.fore_color.rgb = fill
    if line is None:
        sh.line.fill.background()
    else:
        sh.line.color.rgb = line
        sh.line.width = Pt(lw)
    sh.shadow.inherit = False
    return sh


def set_alpha(shape, opacity_pct):
    """Transparencia del relleno solido (0-100 = opacidad)."""
    spPr = shape._element.spPr
    solid = spPr.find(qn("a:solidFill"))
    if solid is None:
        return
    clr = solid.find(qn("a:srgbClr"))
    if clr is None:
        return
    for old in clr.findall(qn("a:alpha")):
        clr.remove(old)
    clr.append(parse_xml('<a:alpha %s val="%d"/>'
                         % (nsdecls("a"), int(opacity_pct * 1000))))


def textbox(s, x, y, w, h, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
    tb = s.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = 0
    tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    tf.paragraphs[0].alignment = align
    return tf


def tf_empty(tf):
    return len(tf.paragraphs) == 1 and len(tf.paragraphs[0].runs) == 0


def para(tf, text, size=18, color=INK, bold=False, italic=False, space_before=0,
         space_after=6, align=None, first=False, line_spacing=1.08, font=FONT):
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.space_before = Pt(space_before)
    p.space_after = Pt(space_after)
    p.line_spacing = line_spacing
    if align is not None:
        p.alignment = align
    r = p.add_run()
    r.text = text
    f = r.font
    f.name = font
    f.size = Pt(size)
    f.bold = bold
    f.italic = italic
    f.color.rgb = color
    return p


def rich(tf, chunks, size=18, space_before=0, space_after=6, align=None,
         first=False, line_spacing=1.08, bullet=None):
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.space_before = Pt(space_before)
    p.space_after = Pt(space_after)
    p.line_spacing = line_spacing
    if align is not None:
        p.alignment = align
    if bullet:
        chunks = [(bullet, {"color": GOLD, "bold": True})] + list(chunks)
    for text, st in chunks:
        r = p.add_run()
        r.text = text
        f = r.font
        f.name = st.get("font", FONT)
        f.size = Pt(st.get("size", size))
        f.bold = st.get("bold", False)
        f.italic = st.get("italic", False)
        f.color.rgb = st.get("color", INK)
    return p


def bullets(tf, items, size=17.5, space_after=11, color=INK, line_spacing=1.1):
    reuse = tf_empty(tf)
    for i, it in enumerate(items):
        if isinstance(it, tuple):
            lead, rest = it
            chunks = [(lead, {"bold": True, "color": NAVY}), (rest, {"color": color})]
        else:
            chunks = [(it, {"color": color})]
        rich(tf, chunks, size=size, first=(i == 0 and reuse),
             space_after=space_after, bullet="\u25aa  ", line_spacing=line_spacing)


def title(s, text, kicker=None, number=None):
    y = Inches(0.46)
    if kicker:
        tf = textbox(s, MARGIN, y, CONTENT_W, Inches(0.28))
        para(tf, kicker.upper(), size=12.5, color=GOLD, bold=True, first=True,
             space_after=0)
        y = Inches(0.78)
    tf = textbox(s, MARGIN, y, CONTENT_W - Inches(0.9), Inches(0.62))
    para(tf, text, size=30, color=NAVY, bold=True, first=True, space_after=0)
    rect(s, MARGIN, Inches(1.52), Inches(1.1), Pt(3.2), fill=GOLD)
    if number is not None:
        tf = textbox(s, W - MARGIN - Inches(1.0), Inches(0.46), Inches(1.0),
                     Inches(0.4), align=PP_ALIGN.RIGHT)
        para(tf, number, size=13, color=LINE, bold=True, first=True, space_after=0)
    return Inches(1.86)


def footer(s, text, page=None):
    """Pie de diapositiva. El numero se toma de la posicion real en el mazo."""
    tf = textbox(s, MARGIN, H - Inches(0.52), CONTENT_W - Inches(0.6), Inches(0.28))
    para(tf, text, size=10.5, color=MUTE, first=True, space_after=0)
    if page is None:
        page = len(prs.slides._sldIdLst)
    if page == "":
        return
    tf = textbox(s, W - MARGIN - Inches(0.6), H - Inches(0.52), Inches(0.6),
                 Inches(0.28), align=PP_ALIGN.RIGHT)
    para(tf, str(page), size=10.5, color=MUTE, bold=True, first=True, space_after=0)


def picture(s, path, x, y, max_w, max_h, center_x=True, center_y=True,
            frame=False, frame_color=None):
    """Encaja la imagen dentro de la caja conservando su proporcion."""
    with Image.open(path) as im:
        iw, ih = im.size
    ar = iw / ih
    w = max_w
    h = Emu(int(w / ar))
    if h > max_h:
        h = max_h
        w = Emu(int(h * ar))
    px = x + Emu(int((max_w - w) / 2)) if center_x else x
    py = y + Emu(int((max_h - h) / 2)) if center_y else y
    if frame:
        pad = Inches(0.06)
        rect(s, px - pad, py - pad, w + 2 * pad, h + 2 * pad,
             fill=frame_color or WHITE, line=None)
    return s.shapes.add_picture(path, px, py, width=w, height=h)


def stat_card(s, x, y, w, h, value, label, accent=BLUE, value_size=34,
              label_size=12.5, fill=SOFT):
    rect(s, x, y, w, h, fill=fill)
    rect(s, x, y, Pt(3.2), h, fill=accent)
    tf = textbox(s, x + Inches(0.22), y + Inches(0.14), w - Inches(0.34),
                 h - Inches(0.24), anchor=MSO_ANCHOR.MIDDLE)
    para(tf, value, size=value_size, color=accent, bold=True, first=True,
         space_after=2, line_spacing=0.95)
    para(tf, label, size=label_size, color=MUTE, space_after=0, line_spacing=1.0)


def table(s, x, y, w, headers, rows, col_ratios=None, row_h=Inches(0.36),
          head_h=Inches(0.4), size=13.5, head_size=12, highlight_row=None,
          highlight_color=None, align_right_from=1):
    n = len(headers)
    if col_ratios is None:
        col_ratios = [1.6] + [1.0] * (n - 1)
    total = sum(col_ratios)
    widths = [Emu(int(w * r / total)) for r in col_ratios]
    hc = highlight_color or BLUE

    rect(s, x, y, w, head_h, fill=NAVY)
    cx = x
    for i, htxt in enumerate(headers):
        al = PP_ALIGN.LEFT if i < align_right_from else PP_ALIGN.CENTER
        tf = textbox(s, cx + Inches(0.13), y, widths[i] - Inches(0.26), head_h,
                     align=al, anchor=MSO_ANCHOR.MIDDLE)
        para(tf, htxt, size=head_size, color=WHITE, bold=True, first=True,
             space_after=0, align=al)
        cx += widths[i]

    ry = y + head_h
    for ri, row in enumerate(rows):
        hi = (highlight_row is not None and ri == highlight_row)
        band = RGBColor(0xEC, 0xF2, 0xF9) if hi else (SOFT if ri % 2 else WHITE)
        rect(s, x, ry, w, row_h, fill=band)
        if hi:
            rect(s, x, ry, Pt(3.2), row_h, fill=hc)
        cx = x
        for ci, cell in enumerate(row):
            al = PP_ALIGN.LEFT if ci < align_right_from else PP_ALIGN.CENTER
            bold = hi or ci == 0
            col = hc if hi else INK
            tf = textbox(s, cx + Inches(0.13), ry, widths[ci] - Inches(0.26),
                         row_h, align=al, anchor=MSO_ANCHOR.MIDDLE)
            para(tf, cell, size=size, color=col, bold=bold, first=True,
                 space_after=0, align=al)
            cx += widths[ci]
        ry += row_h
    return ry


# ------------------------------------------------- diapositivas de imagen
def slide_bleed(img, rotulo, pie, notes, anchor=0.5, kicker=None):
    """Foto a sangre: ocupa las 13,33 x 7,5 pulgadas enteras."""
    s = add_slide(notes)
    s.shapes.add_picture(cover(img, 16 / 9.0, anchor), 0, 0, width=W, height=H)
    band = rect(s, 0, H - Inches(1.45), W, Inches(1.45), fill=DEEP)
    set_alpha(band, 80)
    tf = textbox(s, MARGIN, H - Inches(1.22), CONTENT_W, Inches(1.0))
    if kicker:
        para(tf, kicker.upper(), size=12, color=GOLD, bold=True, first=True,
             space_after=5)
        para(tf, rotulo, size=25, color=WHITE, bold=True, space_after=5)
    else:
        para(tf, rotulo, size=25, color=WHITE, bold=True, first=True,
             space_after=5)
    para(tf, pie, size=14, color=PALE, space_after=0, line_spacing=1.1)
    return s


def slide_galeria(imgs, rotulo, pie, notes, kicker=None, cols=None,
                  caption_size=13):
    """Fotos a altura completa sobre fondo oscuro, lo mas grandes posible.

    imgs: lista de (ruta, pie_de_foto | None).
    """
    s = add_slide(notes)
    rect(s, 0, 0, W, H, fill=DEEP)
    rect(s, 0, 0, Inches(0.13), H, fill=GOLD)

    tf = textbox(s, MARGIN, Inches(0.42), CONTENT_W, Inches(0.9))
    if kicker:
        para(tf, kicker.upper(), size=12, color=GOLD, bold=True, first=True,
             space_after=5)
        para(tf, rotulo, size=25, color=WHITE, bold=True, space_after=4)
    else:
        para(tf, rotulo, size=25, color=WHITE, bold=True, first=True,
             space_after=4)
    if pie:
        para(tf, pie, size=13.5, color=PALE, space_after=0)

    top = Inches(1.72)
    bottom = H - Inches(0.34)
    area_h = bottom - top
    n = len(imgs)
    cols = cols or n
    rows = (n + cols - 1) // cols
    gut = Inches(0.26)
    cell_w = Emu(int((CONTENT_W - gut * (cols - 1)) / cols))
    cell_h = Emu(int((area_h - gut * (rows - 1)) / rows))
    has_cap = any(c for _, c in imgs)
    cap_h = Inches(0.34) if has_cap else Inches(0)

    for i, (path, cap) in enumerate(imgs):
        r, c = divmod(i, cols)
        x = MARGIN + c * (cell_w + gut)
        y = top + r * (cell_h + gut)
        pic = picture(s, prepared(path), x, y, cell_w, cell_h - cap_h,
                      frame=True, frame_color=WHITE)
        if cap:
            tfc = textbox(s, x, pic.top + pic.height + Inches(0.13), cell_w,
                          Inches(0.3), align=PP_ALIGN.CENTER)
            para(tfc, cap, size=caption_size, color=PALE, first=True,
                 space_after=0, align=PP_ALIGN.CENTER)
    return s


def slide_foto_texto(img, rotulo, pie, bloques, notes, kicker=None,
                     img_frac=0.46):
    """Foto a altura completa a un lado y columna de texto al otro."""
    s = add_slide(notes)
    rect(s, 0, 0, W, H, fill=DEEP)
    rect(s, 0, 0, Inches(0.13), H, fill=GOLD)

    img_w = Emu(int(CONTENT_W * img_frac))
    picture(s, prepared(img), MARGIN, Inches(0.42), img_w,
            H - Inches(0.84), frame=True, frame_color=WHITE)

    cx = MARGIN + img_w + Inches(0.5)
    cw = W - MARGIN - cx
    tf = textbox(s, cx, Inches(0.78), cw, Inches(1.8))
    if kicker:
        para(tf, kicker.upper(), size=12, color=GOLD, bold=True, first=True,
             space_after=6)
        para(tf, rotulo, size=24, color=WHITE, bold=True, space_after=8,
             line_spacing=1.1)
    else:
        para(tf, rotulo, size=24, color=WHITE, bold=True, first=True,
             space_after=8, line_spacing=1.1)
    if pie:
        para(tf, pie, size=13.5, color=PALE, space_after=0, line_spacing=1.18)

    by = Inches(3.35)
    for titulo, cuerpo, col in bloques:
        h = Inches(1.5)
        band = rect(s, cx, by, cw, h, fill=WHITE)
        set_alpha(band, 9)
        rect(s, cx, by, Pt(3.2), h, fill=col)
        tfb = textbox(s, cx + Inches(0.28), by + Inches(0.18), cw - Inches(0.56),
                      h - Inches(0.34))
        para(tfb, titulo, size=15, color=WHITE, bold=True, first=True,
             space_after=6)
        para(tfb, cuerpo, size=13, color=PALE, space_after=0, line_spacing=1.16)
        by += h + Inches(0.24)
    return s


# ==================================================== fotos a pantalla completa
def color_borde(path):
    """Color dominante del marco de la imagen, para fundir el fondo con ella."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    step = max(1, w // 60)
    muestras = []
    for x in range(0, w, step):
        muestras.append(im.getpixel((x, 0)))
        muestras.append(im.getpixel((x, h - 1)))
    step = max(1, h // 60)
    for y in range(0, h, step):
        muestras.append(im.getpixel((0, y)))
        muestras.append(im.getpixel((w - 1, y)))
    muestras.sort(key=lambda c: sum(c))
    r, g, b = muestras[len(muestras) // 2]
    return RGBColor(r, g, b)


def chapa(s, x, y, texto, ancla="izq", size=15):
    """Rotulo superpuesto sobre la foto. No resta superficie a la imagen."""
    if not texto:
        return
    ancho = Inches(0.42) + Inches(0.108) * len(texto)
    if ancla == "der":
        x = x - ancho
    fondo = rect(s, x, y, ancho, Inches(0.46), fill=DEEP)
    set_alpha(fondo, 68)
    tf = textbox(s, x + Inches(0.2), y, ancho - Inches(0.4), Inches(0.46),
                 anchor=MSO_ANCHOR.MIDDLE)
    para(tf, texto, size=size, color=WHITE, bold=True, first=True, space_after=0)


def _tapar(s, path, x, y, w, h, ar, anchor=0.5):
    s.shapes.add_picture(cover(path, ar, anchor), x, y, width=w, height=h)


def foto_llena(img, notes, rotulo=None, anchor=0.5):
    """Una foto ocupando las 13,33 x 7,5 pulgadas."""
    s = add_slide(notes)
    _tapar(s, img, 0, 0, W, H, 16 / 9.0, anchor)
    chapa(s, Inches(0.42), H - Inches(0.92), rotulo)
    return s


def foto_fondo(img, notes, rotulo=None):
    """Foto escalada al alto completo sobre un fondo del color de su borde."""
    s = add_slide(notes)
    fondo = color_borde(img)
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = fondo
    rect(s, 0, 0, W, H, fill=fondo)
    picture(s, prepared(img, 2600), 0, 0, W, H)
    chapa(s, Inches(0.42), H - Inches(0.92), rotulo)
    return s


def foto_apiladas(imgs, notes, anchor=0.5):
    """Dos fotos apaisadas, una sobre otra, cubriendo la pantalla entera.

    Es la forma buena para capturas de osciloscopio: conserva todo el ancho de
    la traza y solo recorta la banda de menu y la de estado.
    """
    s = add_slide(notes)
    mitad = Emu(int(H / 2))
    ar = float(W) / float(mitad)
    for i, (path, rot) in enumerate(imgs):
        y = Emu(int(i * mitad))
        _tapar(s, path, 0, y, W, mitad, ar, anchor)
        chapa(s, Inches(0.42), y + mitad - Inches(0.78), rot)
    return s


def foto_columnas(imgs, notes, anchor=0.5):
    """Fotos verticales en columnas, de borde a borde y de arriba a abajo."""
    s = add_slide(notes)
    n = len(imgs)
    col = Emu(int(W / n))
    ar = float(col) / float(H)
    for i, (path, rot) in enumerate(imgs):
        x = Emu(int(i * col))
        _tapar(s, path, x, 0, col, H, ar, anchor)
        chapa(s, x + Inches(0.3), H - Inches(0.92), rot, size=14)
    return s


def foto_cuadrantes(imgs, notes, anchor=0.5):
    """Cuatro fotos en rejilla 2 x 2, sin junta ni margen."""
    s = add_slide(notes)
    cw = Emu(int(W / 2))
    ch = Emu(int(H / 2))
    ar = float(cw) / float(ch)
    for i, (path, rot) in enumerate(imgs):
        r, c = divmod(i, 2)
        x, y = Emu(int(c * cw)), Emu(int(r * ch))
        _tapar(s, path, x, y, cw, ch, ar, anchor)
        chapa(s, x + Inches(0.3), y + ch - Inches(0.74), rot, size=13.5)
    return s


def slide_divisor(num, titulo, sub, notes):
    """Portadilla de seccion: numero grande, nombre y una linea de contenido."""
    s = add_slide(notes)
    rect(s, 0, 0, W, H, fill=NAVY)
    rect(s, 0, 0, Inches(0.16), H, fill=GOLD)

    tf = textbox(s, Inches(1.4), Inches(2.35), Inches(2.4), Inches(1.9))
    para(tf, num, size=96, color=GOLD, bold=True, first=True, space_after=0,
         line_spacing=0.9)

    tf = textbox(s, Inches(4.2), Inches(2.55), Inches(8.2), Inches(1.9))
    para(tf, titulo, size=40, color=WHITE, bold=True, first=True, space_after=14)
    rect(s, Inches(4.2), Inches(4.05), Inches(1.6), Pt(2.6), fill=GOLD)
    tf = textbox(s, Inches(4.2), Inches(4.35), Inches(8.2), Inches(0.9))
    para(tf, sub, size=17, color=PALE, first=True, space_after=0,
         line_spacing=1.16)
    return s


def slide_rtems():
    s = add_slide(
        "Antes del driver conviene decir qué es RTEMS, porque condiciona el "
        "diseño. Es un sistema operativo de tiempo real de código abierto, "
        "estándar de facto en la industria aeroespacial: lo usan la ESA y la "
        "NASA. La característica que importa es que no tiene memoria virtual: "
        "un solo espacio de direcciones físico, un proceso y varios hilos. Eso "
        "da latencias de interrupción muy bajas y deterministas, que es lo que "
        "pide un ordenador de a bordo. El precio es que no hay driver hecho "
        "para periféricos propios: control total, pero hay que escribirlo todo "
        "desde el registro.")
    y = title(s, "RTEMS 7, el sistema operativo del procesador",
              kicker="02 · Firmware", number="02")

    cards = [("Tiempo real", "RTOS de código abierto para sistemas de misión crítica", BLUE),
             ("ESA y NASA", "estándar de facto en la industria aeroespacial", BLUE),
             ("Sin MMU", "un espacio físico, un proceso, varios hilos", GOLD)]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw + Inches(0.3)), y, cw, Inches(1.45), v, l,
                  accent=c, value_size=28, label_size=13)

    y2 = y + Inches(1.85)
    rows = [["Latencia de interrupción", "baja y determinista: no hay traducción de direcciones"],
            ["Concurrencia", "hilos sobre un único espacio de memoria, SMP habilitado"],
            ["Periféricos propios", "sin driver previo: control total y todo el trabajo"],
            ["En este trabajo", "BSP zynqmp_apu, compilado desde fuente con RTEMS Source Builder"]]
    table(s, MARGIN, y2, CONTENT_W, ["", ""], rows, col_ratios=[1.3, 3.6],
          size=15, row_h=Inches(0.56), head_h=Inches(0.06), align_right_from=99)

    y3 = y2 + Inches(2.42)
    rect(s, MARGIN, y3, CONTENT_W, Inches(0.72), fill=SOFT)
    rect(s, MARGIN, y3, Pt(3.2), Inches(0.72), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.32), y3, CONTENT_W - Inches(0.64),
                 Inches(0.72), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Sin memoria virtual no hay fallo de página que retrase una ISR",
               {"bold": True, "color": NAVY, "size": 15}),
              ("   ·   a cambio, el acceso a la lógica programable hay que "
               "declararlo a mano en el arranque.", {"color": INK, "size": 15})],
         first=True, space_after=0)

    footer(s, "02 · Firmware")


def slide_variante_a():
    s = add_slide(
        "La variante A es la de partida: un AXI GPIO por canal sobre el bus "
        "AXI-Lite, y el procesador escribiendo y leyendo byte a byte. Es la "
        "más sencilla y la que menos lógica ocupa, cuatrocientas sesenta LUT "
        "por canal. El defecto es estructural: la CPU toca cada byte, así que "
        "son mil doscientas cincuenta interrupciones por kilobyte y el caudal "
        "se queda en el treinta por ciento del techo físico, sin mejorar "
        "aunque se suba la velocidad de línea.")
    y = title(s, "Variante A · AXI GPIO", kicker="02 · Firmware", number="02")

    picture(s, os.path.join(ASSETS, "variante_1.png"), MARGIN, y,
            CONTENT_W, Inches(3.3))

    yb = y + Inches(3.6)
    cards = [("460", "LUT por canal · la más ligera", BLUE),
             ("1.250", "interrupciones por KB", CLAY),
             ("30 %", "del techo físico, y no escala", CLAY)]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw + Inches(0.3)), yb, cw, Inches(1.25), v,
                  l, accent=c, value_size=32, label_size=13)

    footer(s, "02 · Firmware  ·  un registro por canal, el procesador mueve "
              "cada byte")


def slide_variante_b():
    s = add_slide(
        "La variante B saca a la CPU del camino de datos poniendo un motor DMA "
        "completo por canal. Funciona, y el coste en interrupciones se "
        "desploma. Pero replicar el motor catorce veces cuesta dos mil "
        "ochocientas setenta y tres LUT por canal, casi siete veces la huella "
        "de GPIO. Y hay un límite duro que no depende del diseño: cada AXI DMA "
        "expone dos líneas de interrupción, catorce motores son veintiocho "
        "líneas, y el procesador solo ofrece ocho.")
    y = title(s, "Variante B · 14 × AXI DMA", kicker="02 · Firmware",
              number="02")

    picture(s, os.path.join(ASSETS, "variante_2.png"), MARGIN, y,
            CONTENT_W, Inches(3.3))

    yb = y + Inches(3.6)
    cards = [("2.873", "LUT por canal · 6× la huella de GPIO", CLAY),
             ("28", "líneas de IRQ, y el PS ofrece 8", CLAY),
             ("14,67 %", "del dispositivo: incompatible con TMR", CLAY)]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw + Inches(0.3)), yb, cw, Inches(1.25), v,
                  l, accent=c, value_size=32, label_size=13)

    footer(s, "02 · Firmware  ·  resuelve el problema correcto por un camino "
              "que no escala")


def slide_variante_c():
    s = add_slide(
        "La variante C comparte un único motor multicanal entre los catorce "
        "canales, y entre el motor y los transceptores va un puente en VHDL de "
        "diseño propio. Es la única variante con lógica propia en lugar de solo "
        "IP de terceros. Sale por mil catorce LUT por canal, menos de la mitad "
        "que la B, tres líneas de interrupción de las ocho disponibles y tres "
        "interrupciones por kilobyte. Es la que se adopta.")
    y = title(s, "Variante C · AXI MCDMA con puente VHDL",
              kicker="02 · Firmware", number="02")

    picture(s, os.path.join(ASSETS, "variante_3.png"), MARGIN, y,
            CONTENT_W, Inches(3.3))

    yb = y + Inches(3.6)
    cards = [("1.014", "LUT por canal · menos de la mitad que B", BLUE),
             ("3", "líneas de IRQ, de las 8 disponibles", BLUE),
             ("3", "interrupciones por KB", GOLD)]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw + Inches(0.3)), yb, cw, Inches(1.25), v,
                  l, accent=c, value_size=32, label_size=13)

    footer(s, "02 · Firmware  ·  única variante con lógica propia y no sólo IP "
              "de terceros")


def slide_tdest():
    s = add_slide(
        "Dentro del puente, el reparto es asimétrico por una razón física. En "
        "transmisión basta un canal: el destino viaja en el propio dato, en "
        "una cabecera de dos bytes que el router lee. En recepción hacen falta "
        "catorce, porque cada UART habla cuando quiere y necesita su propio "
        "buffer en memoria. Quien decide a qué buffer va cada paquete es la "
        "señal TDEST: el bloque de drenado etiqueta cada paquete con su canal "
        "de origen. Sin esa etiqueta todo cae en el canal cero, que fue "
        "exactamente el síntoma que vimos en placa.")
    y = title(s, "Reparto de los 14 canales dentro del puente",
              kicker="02 · Firmware", number="02")

    picture(s, os.path.join(ASSETS, "diagrama_mcdma_interior.png"), MARGIN,
            y - Inches(0.05), CONTENT_W, Inches(3.5))

    yb = y + Inches(3.7)
    cw = (CONTENT_W - Inches(0.4)) / 2
    for i, (titulo, cuerpo, col) in enumerate([
            ("Transmisión · 1 canal",
             "El destino viaja en el dato: cabecera de 2 B con canal y "
             "longitud.", BLUE),
            ("Recepción · 14 canales",
             "Cada UART habla sin avisar. TDEST marca el canal de origen de "
             "cada paquete.", GOLD)]):
        x = MARGIN + i * (cw + Inches(0.4))
        rect(s, x, yb, cw, Inches(1.2), fill=SOFT)
        rect(s, x, yb, Pt(3.2), Inches(1.2), fill=col)
        tf = textbox(s, x + Inches(0.3), yb + Inches(0.16), cw - Inches(0.6),
                     Inches(0.95))
        para(tf, titulo, size=15.5, color=NAVY, bold=True, first=True,
             space_after=5)
        para(tf, cuerpo, size=13, color=INK, space_after=0, line_spacing=1.14)

    footer(s, "02 · Firmware  ·  sin TDEST, los 14 flujos caen en el canal 0")


# ================================================================ PORTADA
def slide_portada():
    s = add_slide(
        "Buenos d\u00edas. Soy Jorge Estefan\u00eda y presento mi TFM: el desarrollo de "
        "una plataforma de comunicaci\u00f3n con perif\u00e9ricos sobre MPSoC para "
        "ordenadores de a bordo de sat\u00e9lite, realizado en el B105 Electronic "
        "Systems Lab dentro del proyecto LINCE.")
    rect(s, 0, 0, W, H, fill=NAVY)
    rect(s, 0, 0, Inches(0.16), H, fill=GOLD)

    tf = textbox(s, Inches(1.05), Inches(0.85), Inches(9.2), Inches(0.4))
    para(tf, "UNIVERSIDAD POLIT\u00c9CNICA DE MADRID  \u00b7  ETSI DE TELECOMUNICACI\u00d3N",
         size=13, color=PALE, bold=True, first=True, space_after=0)
    tf = textbox(s, Inches(1.05), Inches(1.22), Inches(9.2), Inches(0.35))
    para(tf, "Trabajo Fin de M\u00e1ster  \u00b7  M\u00e1ster Universitario en Ingenier\u00eda de "
             "Telecomunicaci\u00f3n", size=13, color=PALE, first=True, space_after=0)

    tf = textbox(s, Inches(1.05), Inches(2.05), Inches(10.6), Inches(2.4))
    para(tf, "Desarrollo de una plataforma de comunicaci\u00f3n\ncon perif\u00e9ricos sobre "
             "MPSoC de altas prestaciones", size=33, color=WHITE, bold=True,
         first=True, space_after=4, line_spacing=1.1)
    para(tf, "para Ordenadores de a Bordo en sistemas espaciales", size=33,
         color=GOLD, bold=True, space_after=0, line_spacing=1.1)

    rect(s, Inches(1.05), Inches(4.62), Inches(2.0), Pt(2.6), fill=GOLD)

    tf = textbox(s, Inches(1.05), Inches(5.0), Inches(6.2), Inches(1.6))
    para(tf, "Jorge Alejandro Estefan\u00eda Hidalgo", size=21, color=WHITE,
         bold=True, first=True, space_after=9)
    rich(tf, [("Tutor:  ", {"color": PALE}),
              ("Daniel S\u00e1nchez Garc\u00eda", {"color": WHITE})], size=14,
         space_after=3)
    rich(tf, [("Ponente:  ", {"color": PALE}),
              ("\u00c1lvaro Araujo Pinto", {"color": WHITE})], size=14,
         space_after=3)
    para(tf, "Departamento de Ingenier\u00eda Electr\u00f3nica  \u00b7  B105 Electronic "
             "Systems Lab", size=14, color=PALE, space_after=0)

    tf = textbox(s, W - Inches(3.4), Inches(6.35), Inches(2.6), Inches(0.4),
                 align=PP_ALIGN.RIGHT)
    para(tf, "Madrid, 2026", size=14, color=PALE, bold=True, first=True,
         space_after=0)

    logo = os.path.join(ASSETS, "logo_etsit_blanco.png")
    if os.path.exists(logo):
        picture(s, logo, W - Inches(3.6), Inches(0.75), Inches(2.6), Inches(1.1))


# ================================================================ INDICE
def slide_indice():
    s = add_slide(
        "El recorrido: contexto y objetivos; el firmware, que es el grueso del "
        "trabajo; el hardware, con las tres placas; los resultados; y las "
        "conclusiones.")
    y = title(s, "\u00cdndice", kicker="Recorrido de la defensa")
    entries = [
        ("01", "Contexto y objetivos", "LINCE \u00b7 el problema \u00b7 qu\u00e9 se pide a la plataforma"),
        ("02", "Firmware", "transceptor VHDL \u00b7 driver RTEMS 7 \u00b7 transporte PS\u2013PL"),
        ("03", "Hardware", "tres PCB de expansi\u00f3n de la ZCU102"),
        ("04", "Resultados", "validaci\u00f3n en placa \u00b7 comparativa de transportes"),
        ("05", "Conclusiones y l\u00edneas futuras", ""),
    ]
    cy = y + Inches(0.15)
    for num, name, sub in entries:
        rect(s, MARGIN, cy, CONTENT_W, Inches(0.86), fill=SOFT)
        rect(s, MARGIN, cy, Pt(3.2), Inches(0.86), fill=BLUE)
        tf = textbox(s, MARGIN + Inches(0.3), cy, Inches(0.9), Inches(0.86),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, num, size=25, color=GOLD, bold=True, first=True, space_after=0)
        tf = textbox(s, MARGIN + Inches(1.28), cy, CONTENT_W - Inches(1.6),
                     Inches(0.86), anchor=MSO_ANCHOR.MIDDLE)
        para(tf, name, size=19, color=NAVY, bold=True, first=True, space_after=2)
        if sub:
            para(tf, sub, size=13, color=MUTE, space_after=0)
        cy += Inches(0.97)
    footer(s, "Plataforma de comunicaci\u00f3n con perif\u00e9ricos sobre MPSoC \u00b7 LINCE")


# ================================================================ CONTEXTO
def slide_contexto():
    s = add_slide(
        "El trabajo se enmarca en LINCE, iniciativa del PERTE Aeroespacial "
        "liderada por Indra para microsatélites LEO de 100 a 200 kg, con la "
        "constelación demostradora STARTICAL. Sener aporta el firmware del OBC "
        "y traslada los requisitos de Indra; la UPM participa a través del "
        "B105, responsable del subsistema de comunicaciones del ordenador de a "
        "bordo, que es el ámbito de este trabajo. El enfoque es NewSpace: "
        "componentes comerciales COTS en lugar de rad-hard, mucho más caros, y "
        "la radiación se mitiga con redundancia.")
    y = title(s, "Proyecto LINCE", kicker="01 · Contexto", number="01")

    cards = [("100–200 kg", "microsatélites en órbita baja", BLUE),
             ("STARTICAL", "constelación demostradora", BLUE),
             ("COTS", "en lugar de silicio rad-hard", GOLD)]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw + Inches(0.3)), y, cw, Inches(1.3), v, l,
                  accent=c, value_size=30, label_size=13)

    y2 = y + Inches(1.7)
    rows = [["Indra", "lidera LINCE y fija los requisitos"],
            ["Sener", "firmware del ordenador de a bordo"],
            ["UPM · B105", "comunicaciones del OBC  ←  este TFM"]]
    table(s, MARGIN, y2, Inches(7.0), ["Quién", "Qué aporta"], rows,
          col_ratios=[1.0, 2.1], size=15, row_h=Inches(0.48),
          head_h=Inches(0.44), align_right_from=99, highlight_row=2)

    cx = MARGIN + Inches(7.4)
    cw2 = CONTENT_W - Inches(7.4)
    rect(s, cx, y2, cw2, Inches(2.36), fill=NAVY)
    tf = textbox(s, cx + Inches(0.32), y2 + Inches(0.28), cw2 - Inches(0.64),
                 Inches(1.9))
    para(tf, "ENFOQUE NewSpace", size=12.5, color=GOLD, bold=True, first=True,
         space_after=12)
    para(tf, "Componentes comerciales, no cualificados para espacio.", size=15,
         color=WHITE, space_after=10, line_spacing=1.14)
    para(tf, "La radiación se mitiga con redundancia.", size=15, color=PALE,
         space_after=0, line_spacing=1.14)

    footer(s, "01 · Contexto y objetivos")


# ================================================================ PROBLEMA
def slide_problema():
    s = add_slide(
        "El OBC habla con propulsores, cámaras, seguidores de estrellas y "
        "sensores térmicos por enlaces serie. LINCE exige catorce "
        "simultáneos, cada uno con sus propios parámetros. El MPSoC "
        "trae dos UART nativas en el procesador, así que para "
        "catorce se queda corto: hay que construirlas en la lógica "
        "programable. Y el reparto de recursos tiene que minimizar "
        "área de FPGA y carga de CPU sin penalizar el rendimiento.")
    y = title(s, "Requisitos de partida", kicker="01 · Contexto", number="01")

    cards = [("14", "enlaces RS422/RS485 simultáneos\nrequisito de LINCE", GOLD),
             ("2", "UART nativas en el PS\nfrente a las 14 que pide LINCE", CLAY),
             ("1", "banco de ensayo\nque hay que diseñar y fabricar", BLUE)]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw + Inches(0.3)), y, cw, Inches(1.6), v, l,
                  accent=c, value_size=44, label_size=13.5)

    y2 = y + Inches(2.0)
    tf = textbox(s, MARGIN, y2, CONTENT_W, Inches(0.4))
    para(tf, "CADA ENLACE, CON SU PROPIO FORMATO DE TRAMA", size=12,
         color=GOLD, bold=True, first=True, space_after=0)

    rows = [["Periféricos", "propulsores · cámaras · seguidores de estrellas · sensores térmicos"],
            ["Por enlace", "baudrate · paridad · bits de datos · bits de parada · orden de bit"],
            ["A minimizar", "área de lógica programable · carga de CPU"],
            ["El banco", "dos UART nativas se quedan cortas, y faltan los conectores del satélite"]]
    table(s, MARGIN, y2 + Inches(0.38), CONTENT_W, ["", ""], rows,
          col_ratios=[1.0, 4.6], size=15, row_h=Inches(0.52),
          head_h=Inches(0.06), align_right_from=99)

    footer(s, "01 · Contexto y objetivos")


# ================================================================ OBJETIVOS
def slide_objetivos():
    s = add_slide(
        "De ahí salen seis objetivos específicos. Uno: un transceptor serie en "
        "VHDL configurable en tiempo de ejecución. Dos: estudiar e implementar "
        "la arquitectura de transporte de datos entre procesador y lógica "
        "programable. Tres: el driver en C sobre RTEMS 7 con una API pública "
        "sencilla. Cuatro: la placa de comunicación serie para ejercitar los "
        "catorce transceptores. Cinco: las placas CDHS y AOCS bajo "
        "especificación de Indra. Y seis: integrar y validar el conjunto.")
    y = title(s, "Objetivos", kicker="01 · Contexto", number="01")

    tf = textbox(s, MARGIN, y - Inches(0.06), CONTENT_W, Inches(0.4))
    rich(tf, [("Objetivo principal · ", {"bold": True, "color": NAVY}),
              ("plataforma funcional y validada de comunicación con "
               "periféricos serie sobre el MPSoC ZCU102.", {"color": INK})],
         size=16, first=True, space_after=0)

    items = [
        ("1", "Transceptor serie VHDL", "configurable en ejecución"),
        ("2", "Transporte PL↔PS", "alternativas, medida y elección"),
        ("3", "Driver sobre RTEMS 7", "API pública de 6 funciones"),
        ("4", "Placa de comunicación serie", "los 14 canales a la vez"),
        ("5", "Placas CDHS y AOCS", "bajo especificación de Indra"),
        ("6", "Integrar y validar", "ZCU102 ↔ las tres placas"),
    ]
    cw = (CONTENT_W - Inches(0.34)) / 2
    ch = Inches(1.28)
    y0 = y + Inches(0.62)
    for i, (n, name, sub) in enumerate(items):
        col, row = i % 2, i // 2
        x = MARGIN + col * (cw + Inches(0.34))
        cy = y0 + row * (ch + Inches(0.2))
        rect(s, x, cy, cw, ch, fill=SOFT)
        circ = rect(s, x + Inches(0.26), cy + Inches(0.38), Inches(0.52),
                    Inches(0.52), fill=NAVY, shape=MSO_SHAPE.OVAL)
        ctf = circ.text_frame
        ctf.margin_left = ctf.margin_right = 0
        ctf.margin_top = ctf.margin_bottom = 0
        ctf.vertical_anchor = MSO_ANCHOR.MIDDLE
        pp = ctf.paragraphs[0]
        pp.alignment = PP_ALIGN.CENTER
        rr = pp.add_run()
        rr.text = n
        rr.font.size = Pt(16)
        rr.font.bold = True
        rr.font.name = FONT
        rr.font.color.rgb = WHITE
        tf = textbox(s, x + Inches(1.0), cy, cw - Inches(1.26), ch,
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, name, size=17, color=NAVY, bold=True, first=True, space_after=4)
        para(tf, sub, size=13.5, color=MUTE, space_after=0, line_spacing=1.1)

    footer(s, "01 · Contexto y objetivos")


# ================================================================ PLATAFORMA
def slide_plataforma():
    s = add_slide(
        "Esta es la plataforma completa. A la izquierda, el sistema de "
        "procesamiento con RTEMS 7 y la l\u00f3gica programable: los catorce "
        "transceptores y el bloque de transporte, donde se implementaron las tres "
        "arquitecturas A, B y C; la C, MCDMA con puente VHDL, es la soluci\u00f3n "
        "final. Todo sale por el conector FMC a 1,8 voltios hacia las tres placas "
        "de expansi\u00f3n, una cada vez. En azul, lo que es dise\u00f1o propio; en verde, "
        "software y hardware externo. Los n\u00fameros son los seis objetivos.")
    y = title(s, "Arquitectura de la plataforma", kicker="01 \u00b7 Contexto",
              number="01")

    picture(s, os.path.join(ASSETS, "diagrama_vision_general_ancho.png"),
            MARGIN, y - Inches(0.12), CONTENT_W, Inches(4.25))

    yb = Inches(6.16)
    rect(s, MARGIN, yb, CONTENT_W, Inches(0.72), fill=SOFT)
    rect(s, MARGIN, yb, Pt(3.2), Inches(0.72), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.3), yb, CONTENT_W - Inches(0.6),
                 Inches(0.72), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("En azul, dise\u00f1o propio; en verde, software y hardware externo \u00b7 ",
               {"bold": True, "color": NAVY}),
              ("los n\u00fameros marcan el objetivo espec\u00edfico que cubre cada bloque.",
               {"color": INK})], size=14, first=True, space_after=0)

    footer(s, "01 \u00b7 Contexto y objetivos")


# ================================================================ TRANSCEPTOR
def slide_transceptor():
    s = add_slide(
        "Primer bloque de firmware: el transceptor serie en VHDL. Como el "
        "dispositivo final es desconocido a priori, se diseñó configurable: "
        "todo el formato de trama se cambia en ejecución sin resintetizar. La "
        "temporización de bit no sale de un divisor entero del reloj, así que "
        "se usa un oscilador controlado numéricamente: un acumulador de 32 "
        "bits con el incremento tabulado por baudrate, y cada desbordamiento "
        "es un tick. Uno para transmisión y otro para recepción.")
    y = title(s, "Transceptor serie configurable en VHDL",
              kicker="02 · Firmware", number="02")

    picture(s, os.path.join(ASSETS, "diagrama_transceptor.png"), MARGIN,
            y - Inches(0.1), Inches(8.5), Inches(4.3))

    cx = MARGIN + Inches(8.8)
    cw = CONTENT_W - Inches(8.8)
    tf = textbox(s, cx, y - Inches(0.05), cw, Inches(0.35))
    para(tf, "CONFIGURABLE EN EJECUCIÓN", size=12, color=GOLD, bold=True,
         first=True, space_after=0)

    dy = y + Inches(0.42)
    for v, l in [("50 – 4 M", "baudios · 54 velocidades"),
                 ("5 – 9", "bits de datos"),
                 ("5", "modos de paridad"),
                 ("1 · 1,5 · 2", "bits de parada"),
                 ("LSB / MSB", "orden de bit"),
                 ("SLO", "limitador de slew rate")]:
        rect(s, cx, dy, cw, Inches(0.62), fill=SOFT)
        tf = textbox(s, cx + Inches(0.22), dy, Inches(1.45), Inches(0.62),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, v, size=15.5, color=BLUE, bold=True, first=True, space_after=0)
        tf = textbox(s, cx + Inches(1.75), dy, cw - Inches(1.97), Inches(0.62),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, l, size=12.5, color=MUTE, first=True, space_after=0)
        dy += Inches(0.68)

    footer(s, "02 · Firmware  ·  NCO · TX · RX · registro de desplazamiento · "
              "FIFO de 9 bits × 512")


# ================================================================ VERIFICACION
def slide_verificacion_rtl():
    s = add_slide(
        "Nada se integr\u00f3 sin verificarlo aislado antes. El NCO se midi\u00f3 "
        "velocidad a velocidad: 29 velocidades por dos modos, 58 medidas. El peor "
        "error es de 120 partes por mill\u00f3n a 3,6864 megabaudios, dos \u00f3rdenes de "
        "magnitud por debajo de la tolerancia habitual del \u00b12 % de un UART. El "
        "canal completo se barri\u00f3 entero: cinco anchuras por dos \u00f3rdenes por tres "
        "configuraciones de parada por cinco de paridad son 150 configuraciones, "
        "tres tramas cada una, 450 tramas comparadas dato a dato, todas "
        "correctas.")
    y = title(s, "Verificaci\u00f3n del transceptor en simulaci\u00f3n",
              kicker="02 \u00b7 Firmware", number="02")

    cw = (CONTENT_W - Inches(0.4)) / 2
    stat_card(s, MARGIN, y, cw, Inches(1.25), "58 medidas",
              "NCO \u00b7 29 velocidades \u00d7 2 modos, promediando 200 per\u00edodos",
              accent=BLUE, value_size=27)
    stat_card(s, MARGIN + cw + Inches(0.4), y, cw, Inches(1.25),
              "450 / 450 tramas",
              "canal completo \u00b7 150 configuraciones \u00d7 3 tramas, dato a dato",
              accent=GOLD, value_size=27)

    y2 = y + Inches(1.55)
    TW = Inches(5.95)
    tf = textbox(s, MARGIN, y2, TW, Inches(0.35))
    para(tf, "ERROR DE FRECUENCIA DEL NCO", size=12, color=GOLD, bold=True,
         first=True, space_after=0)
    table(s, MARGIN, y2 + Inches(0.34), TW, ["Baudios", "Medido (Hz)", "Error"],
          [["9.600", "9.600,002", "0,2 ppm"],
           ["115.200", "115.200,074", "0,6 ppm"],
           ["921.600", "921.616,515", "17,9 ppm"],
           ["3.686.400", "3.685.956,506", "\u2212120,3 ppm"]],
          col_ratios=[1.1, 1.3, 1.0], size=13)

    tf = textbox(s, MARGIN, y2 + Inches(2.3), TW, Inches(0.8))
    rich(tf, [("Peor caso: 120 ppm ", {"bold": True, "color": NAVY}),
              ("\u2014 dos \u00f3rdenes de magnitud por debajo de la tolerancia habitual "
               "de \u00b12 % de un UART.", {"color": INK})], size=14, first=True,
         space_after=0, line_spacing=1.14)

    cx = MARGIN + Inches(6.3)
    cwr = CONTENT_W - Inches(6.3)
    tf = textbox(s, cx, y2, cwr, Inches(0.35))
    para(tf, "BARRIDO COMPLETO DEL CANAL  \u00b7  tb_CONFIGURABLE_SERIAL_TOP",
         size=12, color=GOLD, bold=True, first=True, space_after=0)
    rect(s, cx, y2 + Inches(0.34), cwr, Inches(1.92),
         fill=RGBColor(0x11, 0x1B, 0x28))
    tf = textbox(s, cx + Inches(0.26), y2 + Inches(0.5), cwr - Inches(0.5),
                 Inches(1.6))
    mono = {"font": "Consolas", "size": 11}
    console = [("==== TB START: TX->RX loopback tests ====", RGBColor(0x8A, 0x9B, 0xB0)),
               ("PASS cfg bits=5 order='0' stop=1 par=0 sent=11 rec=11", RGBColor(0x7E, 0xD3, 0x8F)),
               ("...", RGBColor(0x8A, 0x9B, 0xB0)),
               ("PASS cfg bits=9 order='1' stop=3 par=4 sent=134 rec=134", RGBColor(0x7E, 0xD3, 0x8F)),
               ("==== TESTS FINISHED ====", RGBColor(0x8A, 0x9B, 0xB0))]
    for i, (txt, col) in enumerate(console):
        st = dict(mono)
        st["color"] = col
        rich(tf, [(txt, st)], first=(i == 0), space_after=5, line_spacing=1.0)
    rich(tf, [("Passed = 450 / Total = 450", dict(mono, color=GOLD, bold=True))],
         space_after=0, line_spacing=1.0)

    tf = textbox(s, cx, y2 + Inches(2.42), cwr, Inches(0.7))
    rich(tf, [("Ninguna configuraci\u00f3n dispar\u00f3 ", {"color": INK}),
              ("PAR_ERROR", {"font": "Consolas", "size": 13, "color": NAVY}),
              (" ni ", {"color": INK}),
              ("FRAME_ERROR", {"font": "Consolas", "size": 13, "color": NAVY}),
              (".", {"color": INK})], size=14, first=True, space_after=0,
         line_spacing=1.14)

    footer(s, "02 \u00b7 Firmware  \u00b7  ning\u00fan bloque se integra sin verificaci\u00f3n "
              "aislada previa")


# ================================================================ DRIVER
def slide_driver():
    s = add_slide(
        "En el lado del procesador, el driver en C sobre RTEMS 7. La API p\u00fablica "
        "son seis funciones y abstrae por completo del hardware. Dos decisiones de "
        "dise\u00f1o. Primera: no hay ninguna direcci\u00f3n fija en el c\u00f3digo. Un GPIO de "
        "solo lectura publica el n\u00famero de transceptores, el stride y la "
        "direcci\u00f3n base, y el driver deduce el resto, as\u00ed que el mismo binario "
        "sirve para cualquier bitstream, de uno a catorce canales. Segunda: "
        "procesado diferido. La rutina de interrupci\u00f3n hace lo m\u00ednimo y delega en "
        "una tarea worker, de modo que la latencia de interrupci\u00f3n no depende del "
        "volumen de datos.")
    y = title(s, "Driver serie sobre RTEMS 7", kicker="02 \u00b7 Firmware",
              number="02")

    tf = textbox(s, MARGIN, y - Inches(0.04), Inches(6.5), Inches(0.35))
    para(tf, "API P\u00daBLICA \u00b7 6 FUNCIONES", size=12, color=GOLD, bold=True,
         first=True, space_after=0)
    rect(s, MARGIN, y + Inches(0.3), Inches(6.5), Inches(3.92),
         fill=RGBColor(0x11, 0x1B, 0x28))
    tf = textbox(s, MARGIN + Inches(0.32), y + Inches(0.52), Inches(5.86),
                 Inches(3.5))
    api = [
        ("Transceiver_Global_INIT", "(void)", "descubre canales, prepara INTC, instala la ISR"),
        ("Transceiver_Init", "(dev, id, cfg)", "una vez por canal"),
        ("Transceiver_SetRxCallback", "(dev, cb, arg)", "callback de recepci\u00f3n"),
        ("Transceiver_Read", "(dev, buf, maxlen)", "extrae lo recibido, no bloquea"),
        ("Transceiver_Send", "(dev, data, len)", "encola y retorna"),
        ("Transceiver_SendString", "(dev, s)", "\u00eddem, para cadenas"),
    ]
    for i, (fn, args, desc) in enumerate(api):
        rich(tf, [(fn, {"font": "Consolas", "size": 13.5,
                        "color": RGBColor(0x7E, 0xC8, 0xF0), "bold": True}),
                  (args, {"font": "Consolas", "size": 13.5,
                          "color": RGBColor(0xC7, 0xD3, 0xE0)})],
             first=(i == 0), space_after=2, line_spacing=1.0)
        rich(tf, [("      " + desc, {"size": 12,
                                     "color": RGBColor(0x8A, 0x9B, 0xB0)})],
             space_after=11, line_spacing=1.0)

    cx = MARGIN + Inches(6.95)
    cw = CONTENT_W - Inches(6.95)
    boxes = [
        ("Descubrimiento din\u00e1mico del hardware",
         "Ninguna direcci\u00f3n fija en el c\u00f3digo. Un AXI GPIO de solo lectura "
         "publica N, el stride y la base; el driver deduce cada canal. El mismo "
         "binario sirve de 1 a 14 canales.", BLUE),
        ("Procesado diferido",
         "La ISR maestra hace lo m\u00ednimo y delega en una tarea worker por canal. "
         "La copia corre como tarea planificable: la latencia de interrupci\u00f3n no "
         "depende del volumen de datos.", GOLD),
        ("Gesti\u00f3n interna",
         "Buffer circular de 4 KB por canal y sem\u00e1foro binario que serializa las "
         "llamadas concurrentes. Los 14 canales comparten un \u00fanico AXI INTC: 28 "
         "fuentes reducidas a una l\u00ednea.", NAVY),
    ]
    by = y - Inches(0.04)
    bh = Inches(1.45)
    for name, body, col in boxes:
        rect(s, cx, by, cw, bh, fill=SOFT)
        rect(s, cx, by, Pt(3.2), bh, fill=col)
        tf = textbox(s, cx + Inches(0.3), by + Inches(0.18), cw - Inches(0.6),
                     bh - Inches(0.3))
        para(tf, name, size=15, color=NAVY, bold=True, first=True, space_after=6)
        para(tf, body, size=12.5, color=INK, space_after=0, line_spacing=1.14)
        by += bh + Inches(0.23)

    footer(s, "02 \u00b7 Firmware  \u00b7  transceiver.c / transceiver.h sobre el BSP "
              "zynqmp_apu")


# ================================================================ LIVELOCK
def slide_livelock():
    s = add_slide(
        "Con catorce canales, lo que limita el rendimiento es el camino que "
        "recorren los bytes entre la memoria y la lógica programable. Una "
        "interrupción cuesta del orden de microsegundos, y ese coste es casi "
        "constante: da igual que mueva un byte o mil. Si se interrumpe una vez "
        "por byte, al subir la velocidad el tiempo entre bytes baja pero el "
        "coste de la interrupción no, así que aparece un umbral de saturación, "
        "y con catorce enlaces llega catorce veces antes. Es lo que Mogul y "
        "Ramakrishnan llamaron interrupt livelock. La salida no es optimizar "
        "la rutina: es interrumpir por paquete en lugar de por byte, es decir, "
        "usar DMA.")
    y = title(s, "Coste de las interrupciones", kicker="02 · Firmware",
              number="02")

    datos = [("≈ µs", "cuesta una interrupción, mueva un byte o mil"),
             ("1 byte = 1 IRQ", "en la variante de partida"),
             ("× 14", "enlaces: el umbral de saturación llega 14 veces antes")]
    dy = y
    for v, l in datos:
        rect(s, MARGIN, dy, Inches(6.9), Inches(0.95), fill=SOFT)
        rect(s, MARGIN, dy, Pt(3.2), Inches(0.95), fill=CLAY)
        tf = textbox(s, MARGIN + Inches(0.3), dy, Inches(2.2), Inches(0.95),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, v, size=20, color=CLAY, bold=True, first=True, space_after=0)
        tf = textbox(s, MARGIN + Inches(2.6), dy, Inches(4.0), Inches(0.95),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, l, size=14, color=INK, first=True, space_after=0,
             line_spacing=1.12)
        dy += Inches(1.08)

    rect(s, MARGIN, dy + Inches(0.15), Inches(6.9), Inches(0.85), fill=NAVY)
    tf = textbox(s, MARGIN + Inches(0.3), dy + Inches(0.15), Inches(6.3),
                 Inches(0.85), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Interrupt livelock", {"bold": True, "color": GOLD, "size": 15.5,
                                      "italic": True}),
              ("   ·   Mogul y Ramakrishnan, 1997", {"color": WHITE,
                                                     "size": 14.5})],
         first=True, space_after=0)

    cx = MARGIN + Inches(7.35)
    cw = CONTENT_W - Inches(7.35)
    picture(s, os.path.join(ASSETS, "diagrama_dma.png"), cx, y, cw, Inches(2.2))
    rect(s, cx, y + Inches(2.6), cw, Inches(1.95),
         fill=RGBColor(0xEC, 0xF2, 0xF9))
    rect(s, cx, y + Inches(2.6), Pt(3.2), Inches(1.95), fill=BLUE)
    tf = textbox(s, cx + Inches(0.32), y + Inches(2.6), cw - Inches(0.64),
                 Inches(1.95), anchor=MSO_ANCHOR.MIDDLE)
    para(tf, "LA SALIDA", size=12, color=GOLD, bold=True, first=True,
         space_after=10)
    para(tf, "Interrumpir por paquete,\nno por byte.", size=21, color=NAVY,
         bold=True, space_after=0, line_spacing=1.14)

    footer(s, "02 · Firmware")


# ================================================================ VARIANTES
def slide_variantes():
    s = add_slide(
        "En lugar de elegir sobre el papel, se implementaron las tres "
        "arquitecturas completas y se midieron con el mismo programa de pruebas. "
        "La A es AXI GPIO, la de partida: un registro por canal y el procesador "
        "mov\u00eda byte a byte. La B son catorce AXI DMA, un motor completo por "
        "canal: saca a la CPU del camino de datos, pero replica el motor catorce "
        "veces. Y la C es un \u00fanico MCDMA multicanal compartido, con un puente en "
        "VHDL de dise\u00f1o propio que multiplexa los catorce canales sobre ese "
        "motor.")
    y = title(s, "Tres arquitecturas de transporte PS\u2013PL",
              kicker="02 \u00b7 Firmware", number="02")

    tf = textbox(s, MARGIN, y - Inches(0.08), CONTENT_W, Inches(0.4))
    para(tf, "Implementadas las tres por completo y medidas con el mismo "
             "programa de pruebas \u2014 no elegidas sobre el papel.", size=16,
         color=MUTE, italic=True, first=True, space_after=0)

    variants = [
        ("A", "AXI GPIO", "Un registro por canal sobre AXI-Lite.\nEl procesador toca cada byte.",
         "referencia de partida", CLAY),
        ("B", "14 \u00d7 AXI DMA", "Un motor DMA completo por canal.\nSaca a la CPU del camino de datos.",
         "PG021 \u00b7 un stream por motor", MUTE),
        ("C", "AXI MCDMA + puente VHDL", "Un motor multicanal compartido.\nMultiplexado por TDEST.",
         "PG288 \u00b7 \u00fanica variante con RTL propio", BLUE),
    ]
    cw = (CONTENT_W - Inches(0.6)) / 3
    y0 = y + Inches(0.52)
    for i, (letter, name, body, tag, col) in enumerate(variants):
        x = MARGIN + i * (cw + Inches(0.3))
        h = Inches(3.25)
        rect(s, x, y0, cw, h,
             fill=SOFT if col is not BLUE else RGBColor(0xEC, 0xF2, 0xF9))
        rect(s, x, y0, cw, Pt(4), fill=col)
        tf = textbox(s, x + Inches(0.3), y0 + Inches(0.3), cw - Inches(0.6),
                     Inches(0.6))
        para(tf, letter, size=40, color=col, bold=True, first=True,
             space_after=0, line_spacing=0.9)
        tf = textbox(s, x + Inches(0.3), y0 + Inches(1.05), cw - Inches(0.6),
                     Inches(2.2))
        para(tf, name, size=17.5, color=NAVY, bold=True, first=True,
             space_after=10, line_spacing=1.08)
        para(tf, body, size=14, color=INK, space_after=12, line_spacing=1.16)
        para(tf, tag, size=11.5, color=MUTE, italic=True, space_after=0)
        if col is BLUE:
            tf = textbox(s, x + Inches(0.3), y0 + h - Inches(0.62),
                         cw - Inches(0.6), Inches(0.4))
            para(tf, "\u25b8  SOLUCI\u00d3N FINAL", size=12.5, color=GOLD, bold=True,
                 first=True, space_after=0)

    yb = y0 + Inches(3.45)
    rect(s, MARGIN, yb, CONTENT_W, Inches(0.82), fill=SOFT)
    rect(s, MARGIN, yb, Pt(3.2), Inches(0.82), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.3), yb, CONTENT_W - Inches(0.6),
                 Inches(0.82), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Criterios de comparaci\u00f3n \u00b7 ", {"bold": True, "color": NAVY}),
              ("interrupciones por KB \u00b7 ocupaci\u00f3n de LUT \u00b7 l\u00edneas de interrupci\u00f3n "
               "disponibles \u00b7 caudal \u00b7 latencia \u00b7 escalado con la velocidad de "
               "l\u00ednea.", {"color": INK})], size=14, first=True, space_after=0,
         line_spacing=1.14)

    footer(s, "02 \u00b7 Firmware  \u00b7  el mismo transceptor de 14 canales y el mismo "
              "bench_main.c en las tres")


# ================================================================ MCDMA
# ================================================================ DEPURACION
def slide_depuracion():
    s = add_slide(
        "La parte más costosa fue depurar el bus AXI-Stream contra el motor "
        "DMA. No hay observabilidad desde software: ni bit de estado, ni "
        "interrupción, ni descriptor marcado; el motor deja de aceptar datos y "
        "el canal enmudece. Hubo que reproducirlo en simulación con "
        "contrapresión y ráfagas solapadas. De ahí salieron los dos "
        "invariantes estructurales que veis aquí, y los dos nacen de la misma "
        "causa: el motor de recepción trabaja en store-and-forward sobre un "
        "buffer de 512 bytes. Con las correcciones, la batería en placa pasó "
        "de 0 de 36 a 36 de 36.")
    y = title(s, "Depuración del bus AXI-Stream",
              kicker="02 · Firmware", number="02")

    rect(s, MARGIN, y - Inches(0.06), CONTENT_W, Inches(0.85), fill=NAVY)
    tf = textbox(s, MARGIN + Inches(0.32), y - Inches(0.06),
                 CONTENT_W - Inches(0.64), Inches(0.85), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Sin observabilidad desde software · ",
               {"bold": True, "color": GOLD, "size": 15.5}),
              ("el motor deja de aceptar datos y el canal enmudece, sin bit de "
               "estado ni interrupción.", {"color": WHITE, "size": 15})],
         first=True, space_after=0, line_spacing=1.12)

    cw = (CONTENT_W - Inches(0.4)) / 2
    y0 = y + Inches(1.05)
    inv = [("Paquete acotado", "512 B", "buffer interno del motor RX",
            "MAX_PKT = 256 B, la mitad: invariante, no una carrera ganada"),
           ("TLAST registrado", "1 ciclo", "se congela al ofrecer el byte",
            "combinacional sobre «FIFO vacía» lo tumbaría la contrapresión")]
    for i, (name, dato, pie, fix) in enumerate(inv):
        x = MARGIN + i * (cw + Inches(0.4))
        rect(s, x, y0, cw, Inches(2.45), fill=SOFT)
        rect(s, x, y0, Pt(3.2), Inches(2.45), fill=BLUE)
        tf = textbox(s, x + Inches(0.32), y0 + Inches(0.22), cw - Inches(0.64),
                     Inches(0.5))
        para(tf, name, size=17.5, color=NAVY, bold=True, first=True,
             space_after=0)
        tf = textbox(s, x + Inches(0.32), y0 + Inches(0.78), cw - Inches(0.64),
                     Inches(0.7))
        rich(tf, [(dato + "  ", {"size": 26, "bold": True, "color": BLUE}),
                  (pie, {"size": 13, "color": MUTE})], first=True,
             space_after=0)
        tf = textbox(s, x + Inches(0.32), y0 + Inches(1.6), cw - Inches(0.64),
                     Inches(0.8))
        rich(tf, [("▸  ", {"color": GOLD, "bold": True}), (fix, {"color": INK})],
             size=13.5, first=True, space_after=0, line_spacing=1.16)

    y1 = y0 + Inches(2.72)
    cards = [("0/36  →  36/36", "batería en placa tras las correcciones", GOLD),
             ("802 checks · 0 errores", "tb_bridge_rx, byte a byte", BLUE),
             ("SIM_RESULT: PASS", "tb_system_e2e a 921.600 8N1", BLUE)]
    cw3 = (CONTENT_W - Inches(0.6)) / 3
    for i, (v, l, c) in enumerate(cards):
        stat_card(s, MARGIN + i * (cw3 + Inches(0.3)), y1, cw3, Inches(1.05), v,
                  l, accent=c, value_size=20, label_size=12)

    footer(s, "02 · Firmware  ·  verificación aislada → integración "
              "incremental → regresión en placa")


# ================================================================ HARDWARE
def slide_hardware():
    s = add_slide(
        "Paso al hardware. Se diseñaron y fabricaron tres placas de expansión "
        "de la ZCU102 en Altium: la placa de comunicación serie, con los "
        "catorce transceptores, que es la de diseño libre; y las placas CDHS y "
        "AOCS, bajo especificación de Indra. Las reglas de diseño se ciñeron a "
        "las capacidades de PCBWay, el fabricante, en lugar de usar un "
        "conjunto propio: eso garantizó fabricabilidad a coste ordinario en "
        "primera tirada, como así fue.")
    y = title(s, "Tres PCB de expansión de la ZCU102", kicker="03 · Hardware",
              number="03")

    boards = [
        ("serial_3d_top.png", "Comunicación serie",
         ["14 × LTC2865", "bus A: RS485, 7 nodos", "buses B y C: RS422",
          "topología por jumper"]),
        ("cdhs_3d_top.png", "CDHS",
         ["CAN redundante", "3 × RS422/RS485", "4 PWM de calentadores",
          "ADC de 4 termistores"]),
        ("aocs_3d_top.png", "AOCS",
         ["6 × RS422/RS485", "PWM de motores, 3 ejes", "2 × SpaceWire",
          "8 conectores D-Sub-9"]),
    ]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (img, name, specs) in enumerate(boards):
        x = MARGIN + i * (cw + Inches(0.3))
        rect(s, x, y, cw, Inches(4.1), fill=SOFT)
        picture(s, os.path.join(IMG, "pcbs", img), x + Inches(0.16),
                y + Inches(0.16), cw - Inches(0.32), Inches(2.25))
        tf = textbox(s, x + Inches(0.3), y + Inches(2.6), cw - Inches(0.6),
                     Inches(0.4))
        para(tf, name, size=17, color=NAVY, bold=True, first=True, space_after=0)
        tf = textbox(s, x + Inches(0.3), y + Inches(3.08), cw - Inches(0.6),
                     Inches(1.0))
        for k, sp in enumerate(specs):
            rich(tf, [(sp, {"color": INK})], size=12.5, first=(k == 0),
                 space_after=3, bullet="· ", line_spacing=1.08)

    y2 = y + Inches(4.34)
    tf = textbox(s, MARGIN, y2, CONTENT_W, Inches(0.5))
    rich(tf, [("Altium Designer · reglas de PCBWay, no propias  ",
               {"bold": True, "color": NAVY}),
              ("→  fabricables a coste ordinario en primera tirada. Montaje "
               "propio: stencil, pasta y horno de reflujo.", {"color": INK})],
         size=14, first=True, space_after=0)

    footer(s, "03 · Hardware  ·  esquemáticos y BOM en el repositorio")


# ================================================================ 1,8 V
def slide_18v():
    s = add_slide(
        "La selección de componentes quedó condicionada por una restricción: "
        "los bancos de entrada y salida del conector FMC operan a 1,8 voltios, "
        "así que todo lo que se conecte directamente tiene que admitir esa "
        "tensión. Se buscó herencia de vuelo en catálogo y el resultado fue "
        "negativo: los transceptores con herencia de vuelo son de una "
        "generación anterior, con interfaz a 3,3 o 5 voltios, y ninguno opera "
        "a 1,8. Se recurrió a grado automotriz, AEC-Q100. Esto se declara "
        "explícitamente en la memoria: estas tarjetas son hardware de "
        "validación funcional, no modelo de vuelo.")
    y = title(s, "Selección de componentes", kicker="03 · Hardware",
              number="03")

    rect(s, MARGIN, y - Inches(0.06), CONTENT_W, Inches(0.8), fill=NAVY)
    tf = textbox(s, MARGIN + Inches(0.32), y - Inches(0.06),
                 CONTENT_W - Inches(0.64), Inches(0.8), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Los bancos de E/S del FMC operan a 1,8 V (carril VADJ)",
               {"bold": True, "color": GOLD, "size": 16}),
              ("   ·   todo lo conectado directamente tiene que admitirlo",
               {"color": WHITE, "size": 15})], first=True, space_after=0)

    y0 = y + Inches(1.05)
    cw = (CONTENT_W - Inches(0.4)) / 2

    rect(s, MARGIN, y0, cw, Inches(2.4), fill=SOFT)
    rect(s, MARGIN, y0, Pt(3.2), Inches(2.4), fill=CLAY)
    tf = textbox(s, MARGIN + Inches(0.32), y0 + Inches(0.26), cw - Inches(0.64),
                 Inches(1.9))
    para(tf, "Herencia de vuelo: 0 candidatos", size=17, color=NAVY, bold=True,
         first=True, space_after=12)
    for t in ["Generación tecnológica anterior",
              "Interfaz a 3,3 V o 5 V, nunca 1,8 V",
              "Rad-hard: coste y plazos fuera de NewSpace"]:
        rich(tf, [(t, {"color": INK})], size=14, space_after=8, bullet="· ")

    x2 = MARGIN + cw + Inches(0.4)
    rect(s, x2, y0, cw, Inches(2.4), fill=SOFT)
    rect(s, x2, y0, Pt(3.2), Inches(2.4), fill=BLUE)
    tf = textbox(s, x2 + Inches(0.32), y0 + Inches(0.26), cw - Inches(0.64),
                 Inches(1.9))
    para(tf, "Grado automotriz · AEC-Q100", size=17, color=NAVY, bold=True,
         first=True, space_after=12)
    for chip, what in [("THVD1424RGTR", "serie de CDHS y AOCS"),
                       ("TCAN1044AVDRQ1", "CAN"),
                       ("ADS7950QDBTRQ1", "ADC SAR 12 bits"),
                       ("LTC2865", "placa serie, hasta 20 Mbps")]:
        rich(tf, [(chip, {"font": "Consolas", "size": 13, "bold": True,
                          "color": NAVY}),
                  ("   " + what, {"size": 13, "color": MUTE})], space_after=7)

    y1 = y0 + Inches(2.62)
    rect(s, MARGIN, y1, CONTENT_W, Inches(0.95), fill=RGBColor(0xFD, 0xF4, 0xE3))
    rect(s, MARGIN, y1, Pt(3.2), Inches(0.95), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.32), y1, CONTENT_W - Inches(0.64),
                 Inches(0.95), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Hardware de validación funcional, no modelo de vuelo",
               {"bold": True, "color": NAVY, "size": 15}),
              ("   ·   para el modelo de vuelo habrá que cambiar VADJ o "
               "interponer adaptadores.", {"color": INK, "size": 15})],
         first=True, space_after=0)

    footer(s, "03 · Hardware")


# ================================================================ VALIDACION
def slide_validacion_placas():
    s = add_slide(
        "Validaci\u00f3n de CDHS y AOCS, interfaz por interfaz. Las comunicaciones "
        "serie se probaron con consola interactiva y arneses de loopback: el "
        "descubrimiento autom\u00e1tico encontr\u00f3 los transceptores y los loopbacks "
        "fueron correctos. El bus CAN se valid\u00f3 con la bater\u00eda de pruebas del "
        "driver CANps del TFG de Diego Ramos: veintis\u00e9is pruebas, veintis\u00e9is "
        "correctas, incluyendo transferencia f\u00edsica entre CAN0 y CAN1, filtrado "
        "de identificador est\u00e1ndar y extendido y tramas RTR. El ADC responde "
        "lineal en todo el rango y el PWM es correcto en las cuatro frecuencias. "
        "Queda una interfaz sin validar, y lo digo expl\u00edcitamente: SpaceWire.")
    y = title(s, "Validaci\u00f3n de las placas CDHS y AOCS",
              kicker="04 \u00b7 Resultados", number="04")

    stat_card(s, MARGIN, y, CONTENT_W, Inches(1.12), "26 / 26 PASS",
              "bater\u00eda del driver CANps \u00b7 inicializaci\u00f3n \u00b7 loopback interno \u00b7 "
              "transferencia f\u00edsica CAN0\u2194CAN1 \u00b7 filtrado de ID est\u00e1ndar y "
              "extendido \u00b7 tramas RTR \u00b7 interrupci\u00f3n hardware", accent=BLUE,
              value_size=28, label_size=13)

    y2 = y + Inches(1.45)
    rows = [["RS422 / RS485", "consola interactiva y arneses de loopback",
             "CDHS 3 canales \u00b7 AOCS 5", "correcto"],
            ["Bus CAN", "bater\u00eda CANps, 26 pruebas", "CAN0 \u2194 CAN1 f\u00edsico",
             "26/26 PASS"],
            ["ADC de termistores", "barrido de tensi\u00f3n en CH2",
             "ADS7950 \u00b7 12 bits por SPI", "lineal 0\u20134095"],
            ["PWM de calentadores", "medida en el conector J5",
             "10 / 5 / 1 kHz y 100 Hz", "correcto"],
            ["PWM de motores", "giro alternado en los 3 ejes",
             "puentes en H \u00b7 AOCS", "correcto"],
            ["SpaceWire", "\u2014", "capa f\u00edsica LVDS expuesta", "sin validar"]]
    table(s, MARGIN, y2, CONTENT_W, ["Interfaz", "Ensayo", "Detalle", "Resultado"],
          rows, col_ratios=[1.25, 1.75, 1.6, 1.0], size=13.5,
          row_h=Inches(0.42), highlight_row=1)

    y3 = y2 + Inches(3.0)
    rect(s, MARGIN, y3, CONTENT_W, Inches(0.92), fill=RGBColor(0xFD, 0xF4, 0xE3))
    rect(s, MARGIN, y3, Pt(3.2), Inches(0.92), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.3), y3, CONTENT_W - Inches(0.6),
                 Inches(0.92), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("SpaceWire sin validar \u00b7 ",
               {"bold": True, "color": NAVY, "size": 14.5}),
              ("la placa expone la capa f\u00edsica LVDS, pero ejercitarlo exige "
               "implementar Data-Strobe, la FSM de enlace y los niveles de "
               "paquete y red: excede el alcance.", {"color": INK, "size": 14.5})],
         first=True, space_after=0, line_spacing=1.14)

    footer(s, "04 \u00b7 Resultados  \u00b7  bater\u00eda CAN del driver CANps (TFG de Diego "
              "Ramos)")


# ================================================================ PLACA SERIE
def slide_placa_serie():
    s = add_slide(
        "Caracterización eléctrica de la placa serie: aquí la señal atraviesa "
        "cobre real y vuelve, con los catorce transceptores a la vez. Nueve "
        "tests y cero fallos de transmisión en toda la campaña: cero bytes "
        "espurios en reposo, cero fugas entre buses, guard time mínimo de cero "
        "microsegundos, recuperación limpia tras colisión, y tras diez segundos "
        "de tráfico continuo el BER es nulo en los dos buses RS422.")
    y = title(s, "Caracterización eléctrica de la placa serie",
              kicker="04 · Resultados", number="04")

    TW = Inches(7.6)
    tf = textbox(s, MARGIN, y - Inches(0.08), TW, Inches(0.32))
    para(tf, "9 TESTS SOBRE COBRE REAL · 14 TRANSCEPTORES", size=12, color=GOLD,
         bold=True, first=True, space_after=0)
    rows = [["T1  Reposo", "0 bytes espurios en 14 canales"],
            ["T2  Topología", "buses puenteados, 0 cruces"],
            ["T3  Multipunto", "6/6 esclavos íntegros hasta 460 kbaudios"],
            ["T5  Limitador SLO", "los 3 buses limpios a 4 Mbaudios"],
            ["T6  Vuelta del bus", "guard time mínimo de 0 µs"],
            ["T7  Diafonía", "0 bytes de fuga entre buses"],
            ["T8  Colisión", "trama corrupta y el bus se recupera"],
            ["T9  Estabilidad 10 s", "RS422: BER 0 · RS485 multipunto: 147 ppm"]]
    table(s, MARGIN, y + Inches(0.3), TW, ["Test", "Resultado"], rows,
          col_ratios=[1.0, 1.55], size=13.5, row_h=Inches(0.42),
          align_right_from=99)

    cx = MARGIN + Inches(8.05)
    cw = CONTENT_W - Inches(8.05)
    stat_card(s, cx, y + Inches(0.3), cw, Inches(1.5), "0 fallos",
              "de transmisión en la campaña completa, sobre las tres topologías "
              "de bus", accent=BLUE, value_size=34, label_size=13)

    tf = textbox(s, cx, y + Inches(2.1), cw, Inches(2.0))
    bullets(tf, [
        ("Bus A · ", "RS485 multipunto de 7 nodos."),
        ("Buses B y C · ", "RS422 en estrella, 4 y 3 nodos."),
    ], size=14, space_after=12)

    tf = textbox(s, cx, y + Inches(3.55), cw, Inches(1.2))
    para(tf, "El cronómetro va siempre en el receptor, nunca al retornar del "
             "envío: MCDMA bloquea en transmisión y las otras dos no.", size=13,
         color=MUTE, italic=True, first=True, space_after=0, line_spacing=1.16)

    footer(s, "04 · Resultados  ·  bus A: RS485 multipunto de 7 nodos  ·  "
              "buses B y C: RS422 en estrella")


# ============================================== LIMITADOR DE SLEW RATE
def slide_slo():
    s = add_slide(
        "Y este es el hallazgo de la campaña. El LTC2865 trae un limitador de "
        "slew rate que viene activo por defecto y limita a 250 kbps nominales. "
        "Con él activo, el bus multipunto saturaba en 460 kbaudios y los dos "
        "punto a punto en 1 Mbaudio. Desactivándolo desde el MPSoC con el bit "
        "SLO, sin tocar el cobre ni la lógica, los tres buses van limpios a 4 "
        "megabaudios con BER nulo. Un bit de configuración cuadruplicaba el "
        "techo de la placa.")
    y = title(s, "Efecto del limitador de slew rate",
              kicker="04 · Resultados", number="04")

    picture(s, os.path.join(ASSETS, "chart_slo.png"), MARGIN, y - Inches(0.05),
            CONTENT_W, Inches(3.7))

    yb = Inches(5.95)
    rect(s, MARGIN, yb, CONTENT_W, Inches(0.95), fill=RGBColor(0xFD, 0xF4, 0xE3))
    rect(s, MARGIN, yb, Pt(3.2), Inches(0.95), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.32), yb, CONTENT_W - Inches(0.64),
                 Inches(0.95), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Un bit de configuración cuadruplica el techo de la placa · ",
               {"bold": True, "color": NAVY, "size": 15}),
              ("el limitador viene activo de fábrica; desactivado desde el "
               "MPSoC con el bit SLO, los tres buses van limpios a 4 Mbaudios "
               "con BER nulo, sin tocar cobre ni lógica.",
               {"color": INK, "size": 15})], first=True, space_after=0,
         line_spacing=1.14)

    footer(s, "04 · Resultados  ·  LTC2865: SLO a nivel bajo limita a 250 kbps; "
              "a nivel alto admite hasta 20 Mbps")


# ============================================== COMPARATIVA: CAUDAL
def slide_comp_caudal():
    s = add_slide(
        "Y llegamos a la comparativa de los tres transportes. Esta campa\u00f1a se "
        "hizo sin ninguna de las placas: los buses se cierran dentro de la propia "
        "FPGA con un m\u00f3dulo de loopback que reproduce fielmente la topolog\u00eda de "
        "la PCB, incluido el wired-AND de RS485 y el hecho de que un canal no se "
        "oye a s\u00ed mismo. As\u00ed se mide el coste del transporte y no la capa f\u00edsica. "
        "Esta es la gr\u00e1fica clave del trabajo: GPIO se satura. Multiplicar por 35 "
        "la velocidad de l\u00ednea solo le da un 41 % m\u00e1s de caudal, porque el cuello "
        "de botella es la CPU, no el enlace. MCDMA escala linealmente hasta 345 "
        "kilobytes por segundo a 4 megabaudios: setenta veces m\u00e1s en el mismo "
        "punto.")
    y = title(s, "Comparativa de transportes \u00b7 caudal",
              kicker="04 \u00b7 Resultados", number="04")

    tf = textbox(s, MARGIN, y - Inches(0.12), CONTENT_W, Inches(0.34))
    rich(tf, [("Buses cerrados dentro de la FPGA ", {"bold": True, "color": NAVY}),
              ("\u2014 el m\u00f3dulo de loopback reproduce la topolog\u00eda de la PCB: mide "
               "el transporte PS\u2013PL, no la capa f\u00edsica.", {"color": MUTE})],
         size=13.5, first=True, space_after=0)

    picture(s, os.path.join(ASSETS, "chart_throughput.png"), MARGIN,
            y + Inches(0.25), CONTENT_W, Inches(4.55))

    yb = Inches(6.58)
    tf = textbox(s, MARGIN, yb, CONTENT_W, Inches(0.4))
    rich(tf, [("GPIO: \u00d735 en velocidad de l\u00ednea \u2192 solo +41 % de caudal. ",
               {"bold": True, "color": CLAY, "size": 14}),
              ("MCDMA escala linealmente hasta 344.781 B/s a 4 Mbaudios, "
               "el 99 % del techo f\u00edsico.",
               {"bold": True, "color": BLUE, "size": 15})], first=True,
         space_after=0)

    footer(s, "04 \u00b7 Resultados  \u00b7  misma ZCU102, mismo transceptor de 14 "
              "canales, mismo programa de pruebas")


# ============================================== COMPARATIVA: INTERRUPCIONES
def slide_comp_irq():
    s = add_slide(
        "Y la explicaci\u00f3n de todo lo anterior est\u00e1 en una sola cifra: 1.250 "
        "interrupciones por kilobyte frente a 3. En la variante GPIO, las "
        "interrupciones de transmisi\u00f3n igualan exactamente a los bytes "
        "transmitidos, veintid\u00f3s mil ciento sesenta y uno igual a veintid\u00f3s mil "
        "ciento sesenta y uno: la CPU toca cada byte. Cuatrocientas veces menos "
        "interrupciones es lo que explica la latencia, el 99 % del techo y la "
        "escalabilidad.")
    y = title(s, "Comparativa de transportes \u00b7 interrupciones",
              kicker="04 \u00b7 Resultados", number="04")

    picture(s, os.path.join(ASSETS, "chart_irq.png"), MARGIN, y + Inches(0.1),
            CONTENT_W, Inches(3.55))

    yb = Inches(5.85)
    cw = (CONTENT_W - Inches(0.4)) / 2
    rect(s, MARGIN, yb, cw, Inches(1.05), fill=SOFT)
    rect(s, MARGIN, yb, Pt(3.2), Inches(1.05), fill=CLAY)
    tf = textbox(s, MARGIN + Inches(0.3), yb, cw - Inches(0.6), Inches(1.05),
                 anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("En GPIO, IRQ de TX = bytes transmitidos ",
               {"bold": True, "color": NAVY, "size": 14.5}),
              ("(22.161 = 22.161): la CPU toca cada byte.",
               {"color": INK, "size": 14.5})], first=True, space_after=0,
         line_spacing=1.14)

    x2 = MARGIN + cw + Inches(0.4)
    rect(s, x2, yb, cw, Inches(1.05), fill=RGBColor(0xEC, 0xF2, 0xF9))
    rect(s, x2, yb, Pt(3.2), Inches(1.05), fill=BLUE)
    tf = textbox(s, x2 + Inches(0.3), yb, cw - Inches(0.6), Inches(1.05),
                 anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Esa \u00fanica cifra explica el resto \u00b7 ",
               {"bold": True, "color": NAVY, "size": 14.5}),
              ("latencia, 99 % del techo y escalabilidad.",
               {"color": INK, "size": 14.5})], first=True, space_after=0,
         line_spacing=1.14)

    footer(s, "04 \u00b7 Resultados  \u00b7  DMA14: cifra de transmisi\u00f3n \u00fanicamente, sin "
              "lazo de recepci\u00f3n operativo")


# ============================================== COMPARATIVA: OCUPACION
def slide_comp_lut():
    s = add_slide(
        "La decisi\u00f3n no se toma solo por rendimiento. Replicar catorce motores "
        "cuesta 2,8 veces m\u00e1s l\u00f3gica que compartir uno. Y mirando al futuro: "
        "endurecer frente a radiaci\u00f3n con triple redundancia modular multiplica "
        "el \u00e1rea por tres. El 5,18 % de MCDMA se convierte en un 16 % asumible; "
        "el 14,67 % de DMA14 se convierte en un 44 %, casi la mitad del "
        "dispositivo. Hay adem\u00e1s un l\u00edmite duro: cada AXI DMA expone dos l\u00edneas "
        "de interrupci\u00f3n, catorce motores son 28 l\u00edneas, y el procesador solo "
        "ofrece ocho.")
    y = title(s, "Comparativa de transportes \u00b7 ocupaci\u00f3n y margen para TMR",
              kicker="04 \u00b7 Resultados", number="04")

    picture(s, os.path.join(ASSETS, "chart_lut.png"), MARGIN, y + Inches(0.1),
            CONTENT_W, Inches(3.55))

    yb = Inches(5.85)
    cw = (CONTENT_W - Inches(0.4)) / 2
    rect(s, MARGIN, yb, cw, Inches(1.05), fill=SOFT)
    rect(s, MARGIN, yb, Pt(3.2), Inches(1.05), fill=CLAY)
    tf = textbox(s, MARGIN + Inches(0.3), yb, cw - Inches(0.6), Inches(1.05),
                 anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("28 l\u00edneas de interrupci\u00f3n en DMA14 ",
               {"bold": True, "color": NAVY, "size": 14.5}),
              ("y el silicio ofrece 8: l\u00edmite del dispositivo, no del dise\u00f1o.",
               {"color": INK, "size": 14.5})], first=True, space_after=0,
         line_spacing=1.14)

    x2 = MARGIN + cw + Inches(0.4)
    rect(s, x2, yb, cw, Inches(1.05), fill=RGBColor(0xEC, 0xF2, 0xF9))
    rect(s, x2, yb, Pt(3.2), Inches(1.05), fill=BLUE)
    tf = textbox(s, x2 + Inches(0.3), yb, cw - Inches(0.6), Inches(1.05),
                 anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Con TMR futuro \u00b7 ", {"bold": True, "color": NAVY, "size": 14.5}),
              ("MCDMA cabe en el 16 % del dispositivo; DMA14 pide el 44 %.",
               {"color": INK, "size": 14.5})], first=True, space_after=0,
         line_spacing=1.14)

    footer(s, "04 \u00b7 Resultados  \u00b7  XCZU9EG \u00b7 274.080 LUT")


# ============================================== COMPARATIVA: DECISION
def slide_comp_decision():
    s = add_slide(
        "Aqu\u00ed est\u00e1 el cuadro completo. GPIO queda descartado por CPU. DMA14 "
        "resuelve el problema correcto por un camino que no escala. Se adopta "
        "MCDMA con puente VHDL: mueve paquetes en lugar de bytes, y las tres se "
        "implementaron y midieron sobre la misma ZCU102, as\u00ed que la elecci\u00f3n est\u00e1 "
        "respaldada por medidas propias y no por cat\u00e1logo.")
    y = title(s, "Comparativa de transportes \u00b7 la decisi\u00f3n",
              kicker="04 \u00b7 Resultados", number="04")

    rows = [
        ["L\u00f3gica (LUT)", "6.434 \u00b7 2,35 %", "40.217 \u00b7 14,67 %", "14.191 \u00b7 5,18 %"],
        ["LUT por canal", "460", "2.873", "1.014"],
        ["IRQ por KB", "1.250", "3,8 (solo TX)", "3"],
        ["L\u00edneas IRQ necesarias", "1", "28  (el PS ofrece 8)", "3"],
        ["Caudal en 1 canal", "3.471 B/s \u00b7 30 %", "\u2014", "11.461 B/s \u00b7 99 %"],
        ["Latencia de trama", "4.606 \u00b5s", "\u2014", "1.530 \u00b5s"],
        ["Escala con el baudrate", "no", "\u2014", "s\u00ed"],
    ]
    TW = CONTENT_W
    table(s, MARGIN, y, TW, ["", "A \u00b7 GPIO", "B \u00b7 DMA14", "C \u00b7 MCDMA"], rows,
          col_ratios=[1.55, 1.12, 1.3, 1.25], size=14, row_h=Inches(0.42),
          head_h=Inches(0.44))

    cwid = TW * 1.25 / 5.22
    rect(s, MARGIN + TW * 3.97 / 5.22, y, cwid,
         Inches(0.44) + 7 * Inches(0.42), fill=None, line=BLUE, lw=2.2)

    yb = y + Inches(3.6)
    tf = textbox(s, MARGIN, yb, CONTENT_W, Inches(0.9))
    bullets(tf, [
        ("GPIO \u00b7 ", "descartado por CPU: interrupt livelock."),
        ("DMA14 \u00b7 ", "resuelve el problema correcto por un camino que no escala: 2,8\u00d7 m\u00e1s l\u00f3gica y 28 l\u00edneas de IRQ donde el silicio ofrece 8."),
    ], size=14, space_after=8)

    yb2 = Inches(6.1)
    rect(s, MARGIN, yb2, CONTENT_W, Inches(0.82), fill=NAVY)
    tf = textbox(s, MARGIN + Inches(0.32), yb2, CONTENT_W - Inches(0.64),
                 Inches(0.82), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Se adopta MCDMA con puente VHDL \u00b7 ",
               {"bold": True, "color": GOLD, "size": 15}),
              ("las tres se implementaron y midieron sobre la misma ZCU102: la "
               "elecci\u00f3n est\u00e1 respaldada por medidas propias, no por cat\u00e1logo.",
               {"color": WHITE, "size": 15})], first=True, space_after=0,
         line_spacing=1.12)

    footer(s, "04 \u00b7 Resultados  \u00b7  DMA14: sin lazo de recepci\u00f3n operativo, "
              "magnitudes que dependen de RX sin medir")


# ================================================================ CONCLUSIONES
def slide_conclusiones():
    s = add_slide(
        "Conclusiones. Los seis objetivos se cumplen, con una excepción "
        "declarada. El transceptor configurable funciona y está verificado "
        "configuración a configuración. El driver sobre RTEMS 7 expone seis "
        "funciones y descubre el hardware en arranque. La arquitectura de "
        "transporte es la contribución de mayor recorrido: tres implementadas "
        "y medidas, no elegidas sobre el papel, y la elegida pasa de 1.250 a 3 "
        "interrupciones por kilobyte. Las tres placas se fabricaron sin "
        "retrabajos y están caracterizadas. La única excepción es SpaceWire, y "
        "está dicho con su motivo. En total, 20.188 líneas de código propio, "
        "con la verificación casi a la par del RTL que verifica.")
    y = title(s, "Conclusiones", kicker="05 · Conclusiones", number="05")

    rows = [["1  Transceptor VHDL", "450/450 tramas · NCO a 120 ppm", "cumplido"],
            ["2  Transporte PL↔PS", "3 IRQ/KB · 99 % del techo", "cumplido"],
            ["3  Driver RTEMS 7", "API de 6 funciones · 1 a 14 canales", "cumplido"],
            ["4  Placa serie", "9 tests · 0 fallos · 4 Mbaudios", "cumplido"],
            ["5  Placas CDHS y AOCS", "fabricadas sin retrabajos", "cumplido"],
            ["6  Integración", "todo validado salvo SpaceWire", "con excepción"]]
    table(s, MARGIN, y, Inches(7.7), ["Objetivo", "Resultado medido", ""], rows,
          col_ratios=[1.35, 1.75, 0.85], size=14, row_h=Inches(0.46),
          head_h=Inches(0.44), highlight_row=1)

    cx = MARGIN + Inches(8.05)
    cw = CONTENT_W - Inches(8.05)
    stat_card(s, cx, y, cw, Inches(1.35), "20.188",
              "líneas de código propio", accent=BLUE, value_size=36,
              label_size=13)
    dy = y + Inches(1.6)
    for v, l in [("40,1 %", "automatización: TCL, Bash y Python"),
                 ("0,97 : 1", "testbench frente a RTL sintetizable"),
                 ("4.710", "líneas de VHDL sintetizable")]:
        rect(s, cx, dy, cw, Inches(0.62), fill=SOFT)
        tf = textbox(s, cx + Inches(0.24), dy, Inches(1.35), Inches(0.62),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, v, size=17, color=BLUE, bold=True, first=True, space_after=0)
        tf = textbox(s, cx + Inches(1.66), dy, cw - Inches(1.9), Inches(0.62),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, l, size=12, color=MUTE, first=True, space_after=0,
             line_spacing=1.08)
        dy += Inches(0.7)

    y2 = y + Inches(3.6)
    tf = textbox(s, MARGIN, y2, CONTENT_W, Inches(0.5))
    rich(tf, [("SpaceWire sin validar · ", {"bold": True, "color": CLAY}),
              ("la capa física LVDS está en la placa; ejercitarla exige "
               "Data-Strobe, FSM de enlace y niveles de red: excede el alcance.",
               {"color": INK})], size=14, first=True, space_after=0)

    rect(s, MARGIN, y2 + Inches(0.62), CONTENT_W, Inches(0.82), fill=NAVY)
    tf = textbox(s, MARGIN + Inches(0.32), y2 + Inches(0.62),
                 CONTENT_W - Inches(0.64), Inches(0.82), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Arquitectura elegida por datos, no por catálogo",
               {"bold": True, "color": GOLD, "size": 15}),
              ("   ·   contribución directa a LINCE y base de trabajo para el "
               "B105.", {"color": WHITE, "size": 15})], first=True,
         space_after=0)

    footer(s, "05 · Conclusiones y líneas futuras")


# ================================================================ FUTURAS
def slide_futuras():
    s = add_slide(
        "Líneas futuras, en orden de esfuerzo creciente. Lo inmediato: "
        "invertir el valor por defecto del bit SLO para arrancar ya a cuatro "
        "megabaudios, fabricar y probar la revisión V2 de AOCS, y completar la "
        "medida de recepción de la variante B. A medio plazo, poner en "
        "servicio SpaceWire sobre la capa física que ya está en la placa, "
        "colgándolo del transporte MCDMA, que admite canales adicionales sin "
        "rediseño. Y a largo plazo, endurecer la plataforma frente a radiación "
        "con triple redundancia modular y scrubbing de configuración.")
    y = title(s, "Líneas futuras", kicker="05 · Conclusiones", number="05")

    tracks = [
        ("INMEDIATO", [
            "Invertir el valor por defecto de SLO",
            "Fabricar y probar la revisión V2 de AOCS",
            "Completar la medida de recepción de DMA14",
        ], GOLD),
        ("MEDIO PLAZO", [
            "Poner en servicio SpaceWire sobre la capa física ya disponible",
            "Colgarlo del MCDMA: admite más canales sin rediseño",
            "Ampliar driver y pruebas a condiciones de operación",
        ], BLUE),
        ("LARGO PLAZO", [
            "TMR del transceptor, del puente y de la lógica propia",
            "Scrubbing de configuración, watchdog y ECC",
            "Componentes con herencia de vuelo",
        ], NAVY),
    ]
    cw = (CONTENT_W - Inches(0.6)) / 3
    for i, (name, items, col) in enumerate(tracks):
        x = MARGIN + i * (cw + Inches(0.3))
        h = Inches(4.2)
        rect(s, x, y, cw, h, fill=SOFT)
        rect(s, x, y, cw, Pt(4), fill=col)
        tf = textbox(s, x + Inches(0.3), y + Inches(0.34), cw - Inches(0.6),
                     Inches(3.6))
        para(tf, name, size=13.5, color=col, bold=True, first=True,
             space_after=16)
        for it in items:
            rich(tf, [(it, {"color": INK})], size=14.5, space_after=14,
                 bullet="▪  ", line_spacing=1.18)

    footer(s, "05 · Conclusiones y líneas futuras")


# ================================================================ GRACIAS
def slide_gracias():
    s = add_slide("Quedo a disposici\u00f3n del tribunal para las preguntas.")
    rect(s, 0, 0, W, H, fill=NAVY)
    rect(s, 0, 0, Inches(0.16), H, fill=GOLD)

    tf = textbox(s, Inches(1.05), Inches(2.35), Inches(9.0), Inches(1.4))
    para(tf, "Gracias por su atenci\u00f3n", size=42, color=WHITE, bold=True,
         first=True, space_after=14)
    para(tf, "Preguntas", size=22, color=GOLD, bold=True, space_after=0)

    rect(s, Inches(1.05), Inches(4.3), Inches(2.0), Pt(2.6), fill=GOLD)

    tf = textbox(s, Inches(1.05), Inches(4.7), Inches(9.0), Inches(1.3))
    para(tf, "Jorge Alejandro Estefan\u00eda Hidalgo", size=18, color=WHITE,
         bold=True, first=True, space_after=7)
    para(tf, "Tutor: Daniel S\u00e1nchez Garc\u00eda  \u00b7  Ponente: \u00c1lvaro Araujo Pinto",
         size=14, color=PALE, space_after=4)
    para(tf, "B105 Electronic Systems Lab  \u00b7  Departamento de Ingenier\u00eda "
             "Electr\u00f3nica  \u00b7  ETSIT-UPM", size=14, color=PALE, space_after=0)

    logo = os.path.join(ASSETS, "logo_etsit_blanco.png")
    if os.path.exists(logo):
        picture(s, logo, W - Inches(3.6), Inches(5.6), Inches(2.6), Inches(1.0))


# ============================================================ RESERVA
def slide_backup_divider():
    s = add_slide("A partir de aqu\u00ed, diapositivas de reserva para preguntas.")
    rect(s, 0, 0, W, H, fill=SOFT)
    rect(s, 0, 0, Inches(0.16), H, fill=GOLD)
    tf = textbox(s, Inches(1.2), Inches(3.05), Inches(9.0), Inches(1.4))
    para(tf, "Diapositivas de reserva", size=34, color=NAVY, bold=True,
         first=True, space_after=10)
    para(tf, "Material de apoyo para el turno de preguntas", size=17, color=MUTE,
         space_after=0)


def slide_backup_topologia():
    s = add_slide("Reserva: topolog\u00edas RS485 y RS422, y el mapa de buses de la "
                  "placa serie.")
    y = title(s, "RS485 y RS422 \u00b7 topolog\u00edas y buses", kicker="Reserva")
    picture(s, os.path.join(ASSETS, "diagrama_topologia_rs.png"), MARGIN, y,
            Inches(6.0), Inches(4.3))
    cx = MARGIN + Inches(6.4)
    cw = CONTENT_W - Inches(6.4)
    rows = [["A", "RS485 multipunto \u00b7 7 nodos", "CH0", "CH1\u2013CH6"],
            ["B", "RS422 punto a punto", "CH7", "CH8\u2013CH10"],
            ["C", "RS422 punto a punto", "CH11", "CH12\u2013CH13"]]
    table(s, cx, y, cw, ["Bus", "Tipo", "Maestro", "Esclavos"], rows,
          col_ratios=[0.5, 1.7, 0.8, 0.95], size=12.5, row_h=Inches(0.4),
          align_right_from=2)
    tf = textbox(s, cx, y + Inches(1.85), cw, Inches(2.2))
    bullets(tf, [
        ("RS485 \u00b7 ", "multipunto hasta 32 transceptores, half-duplex sobre 2 hilos con control de direcci\u00f3n por software, terminaci\u00f3n de 120 \u03a9 en extremos."),
        ("RS422 \u00b7 ", "punto a punto o multi-drop, full-duplex continuo sobre 4 hilos, sin arbitraje de bus."),
    ], size=13.5, space_after=11)
    footer(s, "Reserva", "")


def slide_backup_desglose():
    s = add_slide("Reserva: coste de software por variante y latencia.")
    y = title(s, "Coste de software y latencia por variante", kicker="Reserva")
    rows = [["GPIO", "3.099 B", "114.688 B", "1", "14", "28"],
            ["DMA14", "3.036 B", "115.584 B", "2", "1", "15"],
            ["MCDMA", "3.884 B", "122.434 B", "3", "1", "17"]]
    table(s, MARGIN, y, CONTENT_W,
          ["Variante", "C\u00f3digo", "RAM driver", "L\u00edneas IRQ", "Tareas",
           "Sem\u00e1foros"], rows, col_ratios=[1.0, 0.95, 1.15, 0.9, 0.8, 0.9],
          size=13.5, row_h=Inches(0.42), highlight_row=2)

    tf = textbox(s, MARGIN, y + Inches(2.1), CONTENT_W, Inches(1.0))
    bullets(tf, [
        ("Memoria total similar \u00b7 ", "112\u2013120 KB, dominada por los buffers de 4 KB por canal."),
        ("Diferencia clave \u00b7 ", "GPIO necesita una tarea de recepci\u00f3n por canal (14 tareas, 28 sem\u00e1foros); las variantes con DMA operan con una sola tarea de despacho."),
    ], size=14, space_after=10)

    picture(s, os.path.join(ASSETS, "chart_latencia.png"), MARGIN,
            y + Inches(2.88), CONTENT_W, Inches(2.05))
    footer(s, "Reserva  \u00b7  trama de 11 B, 50 muestras", "")


def slide_backup_presupuesto():
    s = add_slide("Reserva: presupuesto y aspectos energ\u00e9ticos.")
    y = title(s, "Presupuesto y coste energ\u00e9tico", kicker="Reserva")
    rows = [["Mano de obra (beca real)", "5.000,00 \u20ac"],
            ["Recursos materiales amortizados", "4.002,72 \u20ac"],
            ["Gastos generales (15 % s/ CD)", "1.350,41 \u20ac"],
            ["Beneficio industrial (6 %)", "621,19 \u20ac"],
            ["Material fungible", "1.442,92 \u20ac"],
            ["IVA (21 %)", "2.607,62 \u20ac"],
            ["TOTAL", "15.024,86 \u20ac"]]
    table(s, MARGIN, y, Inches(6.2), ["Partida", "Importe"], rows,
          col_ratios=[1.8, 1.0], size=13, row_h=Inches(0.4), highlight_row=6)
    tf = textbox(s, MARGIN, y + Inches(3.35), Inches(6.2), Inches(0.9))
    para(tf, "Con tarifa de mercado de ingeniero junior (30 \u20ac/h sobre 800 h "
             "equivalentes) el total rondar\u00eda los 43.000 \u20ac.", size=13,
         color=MUTE, italic=True, first=True, space_after=0, line_spacing=1.14)

    cx = MARGIN + Inches(6.6)
    cw = CONTENT_W - Inches(6.6)
    tf = textbox(s, cx, y - Inches(0.08), cw, Inches(0.32))
    para(tf, "ENERG\u00cdA POR BYTE \u00daTIL \u00b7 6 RECEPTORES SIMULT\u00c1NEOS", size=12,
         color=GOLD, bold=True, first=True, space_after=0)
    rows2 = [["GPIO", "3,52 W", "20.838 B/s", "169 \u00b5J"],
             ["MCDMA", "3,62 W", "68.504 B/s", "52,8 \u00b5J"]]
    table(s, cx, y + Inches(0.3), cw,
          ["Variante", "Potencia", "Caudal", "E/byte"], rows2,
          col_ratios=[0.9, 0.9, 1.1, 0.9], size=13, row_h=Inches(0.42),
          highlight_row=1)
    tf = textbox(s, cx, y + Inches(1.85), cw, Inches(2.2))
    bullets(tf, [
        ("3,2\u00d7 m\u00e1s eficiente por byte ", "consumiendo s\u00f3lo 0,10 W m\u00e1s (+2,8 %)."),
        ("Margen doble \u00b7 ", "CPU liberada y \u00e1rea liberada; en un sat\u00e9lite con presupuesto de potencia cerrado, cada vatio de avi\u00f3nica no est\u00e1 disponible para la carga de pago."),
        ("Limitaci\u00f3n \u00b7 ", "cifras de potencia estimadas por el implementador de Vivado, v\u00e1lidas para comparar variantes entre s\u00ed, no medidas en carril."),
    ], size=13, space_after=11)
    footer(s, "Reserva", "")


# ==================================================== diapositivas de foto
def foto_zcu102():
    foto_fondo(
        trimmed(os.path.join(IMG, "zcu102.png")),
        "Esta es la tarjeta: cuatro núcleos ARM y una matriz de lógica "
        "programable en el mismo chip. Los dos conectores FMC de la izquierda "
        "exponen los pines diferenciales de la FPGA, y por ahí entran las tres "
        "placas que diseñé.",
        rotulo="ZCU102 · Zynq UltraScale+ XCZU9EG")


def foto_placa_serie_fabricada():
    foto_llena(
        os.path.join(IMG, "serial_pcb_jumpers.jpg"),
        "Así quedó la placa de comunicación serie. Catorce transceptores "
        "LTC2865 y, en la cara de conectores, la fila de jumpers: cada driver "
        "tiene un conector Dupont de tres pines, y un jumper entre dos "
        "consecutivos une sus líneas A y B. Eso permite repartir los siete "
        "drivers RS485 en cualquier combinación de buses sin tocar el firmware "
        "ni el cableado.",
        rotulo="Placa de comunicación serie · 14 × LTC2865")


def foto_placas_soldadas():
    foto_columnas(
        [(os.path.join(IMG, "cdhs_soldada.jpg"), "CDHS"),
         (os.path.join(IMG, "aocs_soldada_caras.jpg"), "AOCS")],
        "El montaje se hizo en el laboratorio: pasta con el stencil alineado, "
        "colocación con pinzas y horno de reflujo. Seis unidades, dos de cada "
        "diseño, y ninguna necesitó retrabajo de fabricación.")


def foto_arneses():
    foto_columnas(
        [(os.path.join(IMG, "arnes_rs422.jpg"), "RS422 · 4 hilos"),
         (os.path.join(IMG, "arnes_rs485.jpg"), "RS485 · 2 hilos"),
         (os.path.join(IMG, "arnes_can.png"), "CAN · nominal a redundante")],
        "Para validar hubo que fabricar los arneses. El de RS422 lleva cuatro "
        "hilos y cruza transmisión con recepción; el de RS485, dos hilos entre "
        "drivers; el de CAN cruza el bus nominal con el redundante en el mismo "
        "conector. Con ellos se cierra cada bus sobre sí mismo y se mide sobre "
        "cobre de verdad.")


def foto_sistema_montado():
    foto_llena(
        os.path.join(IMG, "sistema_montado.jpg"),
        "Este es el banco completo: la ZCU102 con la placa CDHS sobre el "
        "conector FMC HPC0. Solo cabe una placa de expansión a la vez, así que "
        "la validación se hizo placa por placa.",
        rotulo="ZCU102 + CDHS sobre FMC HPC0", anchor=0.45)


def foto_can():
    foto_apiladas(
        [(os.path.join(IMG, "can_sin_term.png"), "sin terminación"),
         (os.path.join(IMG, "can_con_term.png"), "con 60 Ω + 60 Ω")],
        "Aquí se ve por qué la terminación importa. Arriba, sin terminar: las "
        "reflexiones deforman cada flanco. Abajo, con la terminación split de "
        "sesenta más sesenta ohmios, la señal queda limpia. Cada resistencia "
        "lleva su propio jumper, así que la placa permite ensayar el bus "
        "terminado en un extremo, en los dos o en ninguno.")


def foto_pwm():
    foto_apiladas(
        [(os.path.join(IMG, "cdhs_pwm_1khz.png"), "CDHS · calentadores, 1 kHz al 50 %"),
         (os.path.join(IMG, "aocs_pwm_motor.png"), "AOCS · motor, giro alternado")],
        "Las salidas PWM. En CDHS, los cuatro canales de calentadores se "
        "ejercitaron a diez, cinco y un kilohercio y a cien hercios, todos al "
        "cincuenta por ciento. En AOCS, el control de motores alterna el "
        "sentido de giro en los tres ejes. Aquí se detectó el error del eje Z, "
        "que era de placa y no de firmware, corregido en la revisión V2.")


def foto_placa_serie_montada():
    foto_fondo(
        os.path.join(IMG, "serial_pcb_zcu102.jpg"),
        "Y este es el montaje de la campaña eléctrica: la placa serie sobre el "
        "FMC, con los catorce transceptores ejercitándose a la vez. Los "
        "jumpers están puestos para formar tres buses: el A, RS485 multipunto "
        "de siete nodos, y el B y el C, RS422 en estrella.",
        rotulo="14 transceptores en 3 buses · A: RS485 de 7 nodos")


def foto_slew():
    base = os.path.join(IMG, "slew")
    foto_cuadrantes(
        [(os.path.join(base, "rs485_flanco_rapido.png"), "subida · sin limitador"),
         (os.path.join(base, "rs485_flanco_lento.png"), "subida · con limitador"),
         (os.path.join(base, "rs485_bajada_rapida.png"), "bajada · sin limitador"),
         (os.path.join(base, "rs485_bajada_lenta.png"), "bajada · con limitador")],
        "Y esto es lo que hace el limitador sobre el flanco. Sin él, la "
        "transición dura unas pocas decenas de nanosegundos; con él, cerca de "
        "un cuarto de microsegundo, casi un orden de magnitud más. Fijaos en "
        "las bases de tiempo: veinte nanosegundos por división a la izquierda, "
        "cien a la derecha. Eso reduce emisiones radiadas, pero es exactamente "
        "lo que fijaba el techo de velocidad de la placa.")


def foto_rs485():
    foto_fondo(
        os.path.join(ASSETS, "diagrama_topologia_rs485.png"),
        "Reserva: RS485 es un bus compartido, hasta treinta y dos "
        "transceptores, half-duplex sobre dos hilos, con el control de "
        "dirección en software y terminación de ciento veinte ohmios en los "
        "dos extremos. Solo un nodo transmite a la vez, y por eso el bus A "
        "satura antes que los otros dos.",
        rotulo="Bus A de la placa serie: 7 nodos")


def foto_rs422():
    foto_fondo(
        os.path.join(ASSETS, "diagrama_topologia_rs422.png"),
        "Y RS422 es punto a punto, full-duplex continuo sobre cuatro hilos, "
        "con un único transmisor por par: no hace falta compartir el medio ni "
        "arbitrar, así que llega más lejos en velocidad. Son los buses B y C "
        "de la placa serie.",
        rotulo="Buses B y C de la placa serie")


# ----------------------------------------------------------------- montaje
ORDEN = [
    slide_portada,
    slide_indice,
    lambda: slide_divisor("01", "Contexto y objetivos",
                          "El proyecto LINCE, qué se le pide a la plataforma y "
                          "qué se propone construir.",
                          "Empiezo por el contexto: dónde encaja este trabajo y "
                          "qué se le pide."),
    slide_contexto,
    slide_problema,
    foto_zcu102,
    slide_objetivos,
    slide_plataforma,
    lambda: slide_divisor("02", "Firmware",
                          "Transceptor en VHDL, driver sobre RTEMS 7 y el "
                          "transporte de datos entre procesador y FPGA.",
                          "Paso al firmware, que es el grueso del trabajo."),
    slide_transceptor,
    slide_verificacion_rtl,
    slide_rtems,
    slide_driver,
    slide_livelock,
    slide_variantes,
    slide_variante_a,
    slide_variante_b,
    slide_variante_c,
    slide_tdest,
    slide_depuracion,
    lambda: slide_divisor("03", "Hardware",
                          "Tres placas de expansión de la ZCU102, diseñadas, "
                          "fabricadas y montadas.",
                          "Segundo bloque: el hardware del banco."),
    slide_hardware,
    foto_placa_serie_fabricada,
    foto_placas_soldadas,
    slide_18v,
    foto_arneses,
    lambda: slide_divisor("04", "Resultados",
                          "Validación de las tres placas y comparativa medida "
                          "de las tres arquitecturas de transporte.",
                          "Y los resultados, que es donde están las medidas."),
    foto_sistema_montado,
    slide_validacion_placas,
    foto_can,
    foto_pwm,
    foto_placa_serie_montada,
    slide_placa_serie,
    slide_slo,
    foto_slew,
    slide_comp_caudal,
    slide_comp_irq,
    slide_comp_lut,
    slide_comp_decision,
    lambda: slide_divisor("05", "Conclusiones",
                          "Qué queda cumplido, qué queda declarado como "
                          "pendiente y por dónde sigue.",
                          "Cierro con las conclusiones."),
    slide_conclusiones,
    slide_futuras,
    slide_gracias,
    slide_backup_divider,
    foto_rs485,
    foto_rs422,
    slide_backup_desglose,
    slide_backup_presupuesto,
]
for fn in ORDEN:
    fn()

# Recortes del guion hablado (recortes.py): se quita de las notas lo que ya
# esta escrito en la propia diapositiva, nunca el argumento.
try:
    from recortes import RECORTES
except ImportError:
    RECORTES = []
try:
    from recortes2 import RECORTES2
    RECORTES = list(RECORTES) + list(RECORTES2)
except ImportError:
    pass

for sl in prs.slides:
    if not sl.has_notes_slide:
        continue
    tf_r = sl.notes_slide.notes_text_frame
    txt_r = tf_r.text
    for _old, _new in RECORTES:
        o = " ".join(_old.split())
        n = " ".join(_new.split())
        if o in txt_r:
            txt_r = txt_r.replace(o, n)
    tf_r.text = txt_r


N_CHARLA = 44  # hasta la diapositiva de gracias; el resto es reserva  # las siguientes son de reserva y no cuentan en el crono

# Tiempos: se recalcula la marca (~N s) sobre el texto real de las notas, a
# 140 palabras por minuto, que es un ritmo de defensa comodo en castellano.
WPM = 140.0
total = 0
for i, sl in enumerate(prs.slides, 1):
    if not sl.has_notes_slide:
        continue
    tf_n = sl.notes_slide.notes_text_frame
    txt = re.sub(r"\s*\(~\d+ s\)\s*$", "", tf_n.text).strip()
    if i > N_CHARLA:
        tf_n.text = txt
        continue
    secs = max(10, int(round(len(txt.split()) / WPM * 60 / 5.0)) * 5)
    total += secs
    tf_n.text = "%s (~%d s)" % (txt, secs)
print("Guion hablado: %d s = %.1f min a %.0f palabras/min" % (total, total / 60.0, WPM))

prs.core_properties.title = ("Desarrollo de una plataforma de comunicaci\u00f3n con "
                             "perif\u00e9ricos sobre MPSoC de altas prestaciones para "
                             "Ordenadores de a Bordo en sistemas espaciales")
prs.core_properties.author = "Jorge Alejandro Estefan\u00eda Hidalgo"
prs.core_properties.subject = "Trabajo Fin de M\u00e1ster \u00b7 ETSIT-UPM \u00b7 Proyecto LINCE"

prs.save(OUTPUT)
print("Guardado:", OUTPUT)
print("Diapositivas:", len(ORDEN))
