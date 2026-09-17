# -*- coding: utf-8 -*-
"""Tercera pasada: separadores de seccion, RTEMS, una variante por diapositiva
y limpieza de titulos.
"""

NUEVAS = {}

# --------------------------------------------------------------- separador
NUEVAS["slide_divisor"] = '''
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
'''

# --------------------------------------------------------------- RTEMS
NUEVAS["slide_rtems"] = '''
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

    y3 = y2 + Inches(2.5)
    rect(s, MARGIN, y3, CONTENT_W, Inches(0.85), fill=SOFT)
    rect(s, MARGIN, y3, Pt(3.2), Inches(0.85), fill=GOLD)
    tf = textbox(s, MARGIN + Inches(0.32), y3, CONTENT_W - Inches(0.64),
                 Inches(0.85), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Sin memoria virtual no hay fallo de página que retrase una ISR",
               {"bold": True, "color": NAVY, "size": 15}),
              ("   ·   a cambio, el acceso a la lógica programable hay que "
               "declararlo a mano en el arranque.", {"color": INK, "size": 15})],
         first=True, space_after=0)

    footer(s, "02 · Firmware")
'''

# --------------------------------------------- transceptor sin la caja del NCO
NUEVAS["slide_transceptor"] = '''
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
'''

# --------------------------------------------- coste de las interrupciones
NUEVAS["slide_livelock"] = '''
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
    para(tf, "Interrumpir por paquete,\\nno por byte.", size=21, color=NAVY,
         bold=True, space_after=0, line_spacing=1.14)

    footer(s, "02 · Firmware")
'''

# --------------------------------------------- una variante por diapositiva
NUEVAS["slide_variante_a"] = '''
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
'''

NUEVAS["slide_variante_b"] = '''
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
'''

NUEVAS["slide_variante_c"] = '''
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
'''

NUEVAS["slide_tdest"] = '''
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
'''

# --------------------------------------------- seleccion de componentes
NUEVAS["slide_18v"] = '''
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
'''

# --------------------------------------------- lineas futuras sin la coletilla
NUEVAS["slide_futuras"] = '''
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
'''
