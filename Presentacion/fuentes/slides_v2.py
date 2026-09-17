# -*- coding: utf-8 -*-
"""Versiones con menos prosa de las diapositivas de texto.

Criterio: en pantalla van datos y etiquetas cortas; el desarrollo va en la
boca del ponente, no en la pared. Ninguna frase pasa de una linea.
"""

NUEVAS = {}

NUEVAS["slide_contexto"] = '''
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
'''

NUEVAS["slide_problema"] = '''
def slide_problema():
    s = add_slide(
        "¿Cuál es el problema concreto? El OBC habla con propulsores, cámaras, "
        "seguidores de estrellas y sensores térmicos por enlaces serie. LINCE "
        "exige catorce enlaces RS422/RS485 simultáneos, cada uno con sus "
        "propios parámetros, porque cada periférico es distinto. El reparto de "
        "recursos debe minimizar el área en lógica programable y el uso de CPU "
        "sin penalizar el rendimiento.")
    y = title(s, "El problema", kicker="01 · Contexto", number="01")

    cards = [("14", "enlaces RS422/RS485 simultáneos\\nrequisito de LINCE", GOLD),
             ("0", "transceptores serie\\nen la ZCU102 de fábrica", CLAY),
             ("1", "banco de ensayo\\nque hay que diseñar y fabricar", BLUE)]
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
            ["El banco", "la ZCU102 no trae los transceptores ni los conectores del satélite"]]
    table(s, MARGIN, y2 + Inches(0.38), CONTENT_W, ["", ""], rows,
          col_ratios=[1.0, 4.6], size=15, row_h=Inches(0.52),
          head_h=Inches(0.06), align_right_from=99)

    footer(s, "01 · Contexto y objetivos")
'''

NUEVAS["slide_objetivos"] = '''
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
'''

NUEVAS["slide_livelock"] = '''
def slide_livelock():
    s = add_slide(
        "Y aquí aparece el problema de fondo, que es el eje del trabajo. Con "
        "catorce canales, lo que determina el rendimiento no es el transceptor "
        "ni el driver: es el camino por el que viajan los bytes entre la DDR y "
        "la lógica programable. Una interrupción cuesta del orden de "
        "microsegundos, y ese coste es casi constante, independiente de "
        "cuántos bytes muevas. Si interrumpes una vez por byte, al subir la "
        "velocidad el tiempo entre bytes baja pero el coste de la interrupción "
        "no: hay un umbral de saturación, y con N enlaces llega N veces antes. "
        "La solución de fondo no es optimizar la rutina: es interrumpir por "
        "paquete. Es decir, DMA.")
    y = title(s, "El cuello de botella: interrupt livelock",
              kicker="02 · Firmware", number="02")

    tf = textbox(s, MARGIN, y - Inches(0.06), Inches(6.7), Inches(1.1))
    para(tf, "El factor determinante no es el transceptor ni el driver: es el "
             "camino que recorren los bytes entre la DDR y la lógica "
             "programable.", size=17, color=NAVY, bold=True, first=True,
         space_after=0, line_spacing=1.16)

    datos = [("≈ µs", "coste de una interrupción, independiente de los bytes"),
             ("1 byte = 1 IRQ", "en la variante de partida"),
             ("×14", "enlaces: el umbral de saturación llega 14 veces antes")]
    dy = y + Inches(1.28)
    for v, l in datos:
        rect(s, MARGIN, dy, Inches(6.7), Inches(0.82), fill=SOFT)
        rect(s, MARGIN, dy, Pt(3.2), Inches(0.82), fill=CLAY)
        tf = textbox(s, MARGIN + Inches(0.28), dy, Inches(2.1), Inches(0.82),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, v, size=19, color=CLAY, bold=True, first=True, space_after=0)
        tf = textbox(s, MARGIN + Inches(2.5), dy, Inches(4.0), Inches(0.82),
                     anchor=MSO_ANCHOR.MIDDLE)
        para(tf, l, size=13.5, color=INK, first=True, space_after=0,
             line_spacing=1.12)
        dy += Inches(0.94)

    rect(s, MARGIN, dy + Inches(0.1), Inches(6.7), Inches(0.92), fill=NAVY)
    tf = textbox(s, MARGIN + Inches(0.3), dy + Inches(0.1), Inches(6.1),
                 Inches(0.92), anchor=MSO_ANCHOR.MIDDLE)
    rich(tf, [("Interrupt livelock", {"bold": True, "color": GOLD, "size": 15.5,
                                      "italic": True}),
              ("  ·  Mogul y Ramakrishnan, 1997", {"color": WHITE, "size": 15})],
         first=True, space_after=0)

    cx = MARGIN + Inches(7.15)
    cw = CONTENT_W - Inches(7.15)
    picture(s, os.path.join(ASSETS, "diagrama_dma.png"), cx, y, cw, Inches(2.1))
    rect(s, cx, y + Inches(2.5), cw, Inches(2.0), fill=RGBColor(0xEC, 0xF2, 0xF9))
    rect(s, cx, y + Inches(2.5), Pt(3.2), Inches(2.0), fill=BLUE)
    tf = textbox(s, cx + Inches(0.32), y + Inches(2.5), cw - Inches(0.64),
                 Inches(2.0), anchor=MSO_ANCHOR.MIDDLE)
    para(tf, "LA SOLUCIÓN DE FONDO", size=12, color=GOLD, bold=True,
         first=True, space_after=10)
    para(tf, "Interrumpir por paquete,\\nno por byte.", size=20, color=NAVY,
         bold=True, space_after=0, line_spacing=1.14)

    footer(s, "02 · Firmware")
'''

NUEVAS["slide_depuracion"] = '''
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
    y = title(s, "Depuración: dos invariantes estructurales",
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
'''

NUEVAS["slide_hardware"] = '''
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
'''

NUEVAS["slide_18v"] = '''
def slide_18v():
    s = add_slide(
        "Una restricción condicionó toda la selección de componentes: los "
        "bancos de entrada/salida del conector FMC operan a 1,8 voltios, así "
        "que todo lo que se conecte directamente debe admitir esa tensión. Se "
        "buscó herencia de vuelo en catálogo y el resultado fue negativo: los "
        "transceptores con herencia de vuelo son de una generación anterior, "
        "con interfaz a 3,3 o 5 voltios; ninguno opera a 1,8. Se recurrió a "
        "grado automotriz, AEC-Q100. Esto se declara explícitamente en la "
        "memoria: estas tarjetas son hardware de validación funcional, no "
        "modelo de vuelo.")
    y = title(s, "La restricción de 1,8 V", kicker="03 · Hardware", number="03")

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
    rich(tf, [("Declarado: hardware de validación funcional, no modelo de vuelo",
               {"bold": True, "color": NAVY, "size": 15}),
              ("   ·   para el modelo de vuelo habrá que cambiar VADJ o "
               "interponer adaptadores.", {"color": INK, "size": 15})],
         first=True, space_after=0)

    footer(s, "03 · Hardware")
'''

NUEVAS["slide_conclusiones"] = '''
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
    y = title(s, "Conclusiones", kicker="05 · Cierre", number="05")

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
    picture(s, os.path.join(ASSETS, "chart_codigo.png"), cx, y + Inches(1.55),
            cw, Inches(1.9))

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
'''
