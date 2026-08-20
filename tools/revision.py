"""Revision mecanica de la memoria del TFM. Solo informa; no modifica nada."""
import io, glob, re, collections, sys

files = sorted(glob.glob('capitulos/**/*.tex', recursive=True)) + sorted(glob.glob('pre/*.tex'))
raw = {f: io.open(f, encoding='utf-8').read() for f in files}

S = lambda f: f.replace('\\', '/')
def loc(f, s, i):
    return "%s:%d" % (S(f), s[:i].count('\n') + 1)

def body(s):
    s = re.sub(r"\\begin\{(lstlisting|tabular|axis|tikzpicture)\}.*?\\end\{\1\}", "", s, flags=re.S)
    return re.sub(r"%.*", "", s)

def scan(pat, use_body=True, flags=0):
    out = []
    for f, s in raw.items():
        t = body(s) if use_body else s
        for m in re.finditer(pat, t, flags):
            out.append((loc(f, t, m.start()), ' '.join(m.group(0).split())[:64]))
    return out

rep = collections.OrderedDict()

# --- tipografia -------------------------------------------------------------
rep["Dobles espacios entre palabras"] = scan(r"[a-záéíóúA-Z]  +[a-záéíóúA-Z]")
rep["\\ref/\\cite sin ~ delante"] = scan(r"[a-zA-ZáéíóúÁÉÍÓÚ] \\(?:ref|cite)\{[^}]+\}")
rep["'solo' con tilde"] = scan(r"\bs[oó]lo\b(?<=sólo)")
rep["Comillas ``'' en vez de guillemets"] = scan(r"``[^`']{1,50}''")
rep["Espacio antes de coma o punto"] = scan(r"[a-záéíóú] [,.](?:\s|$)")

# --- separador de miles -----------------------------------------------------
en_tabla = set()
for f, s in raw.items():
    for m in re.finditer(r"(\d{1,3})\\,(\d{3})", s):
        en_tabla.add(m.group(1) + m.group(2))
sueltas = []
for l, t in scan(r"(?<![\d.,\\A-Za-z])\d{4,6}(?![\d.,\\])"):
    if t in en_tabla:
        sueltas.append((l, t))
rep["Cifra sin \\, que en las tablas si lo lleva"] = sueltas

# --- anglicismos: cursiva si/no ---------------------------------------------
POLITICA = [("firmware", "recto"), ("hardware", "recto"), ("software", "recto"),
            ("driver", "recto"), ("throughput", "cursiva"), ("bitstream", "cursiva"),
            ("jumper", "cursiva"), ("loopback", "cursiva"), ("testbench", "cursiva"),
            ("worker", "cursiva"), ("stencil", "cursiva")]
for term, quiere in POLITICA:
    hits = []
    for f, s in raw.items():
        t = body(s)
        for m in re.finditer(r"(\\textit\{\s*)?" + term + r"s?\b", t, re.I):
            ital = bool(m.group(1))
            ctx = t[max(0, m.start() - 40):m.start()]
            if re.search(r"(texttt|lstinline|label|ref)\{[^}]*$", ctx):
                continue
            if (quiere == "recto" and ital) or (quiere == "cursiva" and not ital):
                hits.append((loc(f, t, m.start()), m.group(0)))
    if hits:
        rep["'%s' deberia ir %s" % (term, quiere)] = hits

# --- siglas sin desplegar en su primera aparicion ---------------------------
orden = ['pre/resumen.tex'] + [f for f in files if f.startswith('capitulos')]
texto_global = "\n".join(body(raw[f]) for f in orden if f in raw)
siglas = collections.Counter(re.findall(r"(?<![A-Za-z\\{])([A-Z]{2,6})(?![A-Za-z])", texto_global))
sin_desplegar = []
for sig, n in siglas.items():
    if n < 3:
        continue
    i = texto_global.find(sig)
    ventana = texto_global[max(0, i - 160):i + 160]
    if not re.search(r"\(" + sig + r"\)", ventana) and not re.search(re.escape(sig) + r"\s*[,(]?\s*(del|de|the)?\s*\w+\s+\w+", ventana):
        sin_desplegar.append((sig, n))
rep["Siglas frecuentes sin '(SIGLA)' en su 1a aparicion"] = [(s, "x%d" % n) for s, n in sorted(sin_desplegar, key=lambda x: -x[1])[:20]]

# --- frases y parrafos largos -----------------------------------------------
largas = []
for f, s in raw.items():
    t = re.sub(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?", "", body(s)).replace("{", "").replace("}", "")
    for m in re.finditer(r"[^.!?]{100,}[.!?]", t):
        w = len(m.group(0).split())
        if w > 55:
            largas.append((loc(f, t, m.start()), "%d palabras: %s..." % (w, ' '.join(m.group(0).split())[:50])))
rep["Frases de mas de 55 palabras"] = largas

parrafos = []
for f, s in raw.items():
    t = body(s)
    for m in re.finditer(r"(?:^|\n\n)((?:[^\n]+\n){12,})", t):
        parrafos.append((loc(f, t, m.start()), "%d lineas seguidas" % m.group(1).count('\n')))
rep["Parrafos de mas de 12 lineas"] = parrafos

# --- captions ---------------------------------------------------------------
sin_punto = []
for f, s in raw.items():
    for m in re.finditer(r"\\caption\{((?:[^{}]|\{[^{}]*\})*)\}", s):
        c = m.group(1).strip()
        if c and not c.endswith('.'):
            sin_punto.append((loc(f, s, m.start()), c[:55]))
rep["Caption que no termina en punto"] = sin_punto

# --- etiquetas huerfanas ----------------------------------------------------
labels = {}
refs = set()
for f, s in raw.items():
    for m in re.finditer(r"\\label\{([^}]+)\}", s):
        labels[m.group(1)] = loc(f, s, m.start())
    refs |= set(re.findall(r"\\ref\{([^}]+)\}", s))
rep["Etiquetas nunca referenciadas"] = [(v, k) for k, v in labels.items() if k not in refs]

# --- salida -----------------------------------------------------------------
total = 0
for k, v in rep.items():
    if not v:
        continue
    total += len(v)
    print("### %s  (%d)" % (k, len(v)))
    for l, t in v[:6]:
        print("    %-46s %s" % (l, t))
    if len(v) > 6:
        print("    ... y %d mas" % (len(v) - 6))
    print()
print("TOTAL INCIDENCIAS: %d" % total)
