"""Segunda pasada: siglas contra la lista de acronimos, y frases/parrafos largos filtrados."""
import io, glob, re, collections

files = sorted(glob.glob('capitulos/**/*.tex', recursive=True)) + sorted(glob.glob('pre/*.tex'))
raw = {f: io.open(f, encoding='utf-8').read() for f in files}
S = lambda f: f.replace('\\', '/')

def body(s):
    s = re.sub(r"\\begin\{(lstlisting|tabular|axis|tikzpicture|sidewaystable)\}.*?\\end\{\1\}", "", s, flags=re.S)
    s = re.sub(r"\\begin\{(table|figure|sidewaysfigure)\}.*?\\end\{\1\}", "", s, flags=re.S)
    return re.sub(r"%.*", "", s)

# --- 1. siglas usadas vs lista de acronimos ---------------------------------
ac = io.open('pre/acronimos.tex', encoding='utf-8').read()
listadas = set(re.findall(r"\\paragraph\{([A-Za-z0-9\\_+-]{2,12})\}", ac))
listadas = {re.sub(r"\\", "", x) for x in listadas}
texto = "\n".join(body(v) for f, v in raw.items() if f.startswith('capitulos'))
texto_sin_codigo = re.sub(r"\\text(tt|bf)\{[^}]*\}", " ", texto)
usadas = collections.Counter(re.findall(r"(?<![A-Za-z\\{])([A-Z]{2,6})(?![A-Za-z])", texto_sin_codigo))
IGNORA = {"TX", "RX", "DE", "RE", "PS", "PL", "II", "III", "IV", "OK", "SD", "IP", "AND", "OR",
          "LA", "HA", "EL", "AL", "UN", "SE", "ES", "NO", "VHDL", "TCL", "BOOT", "BIN", "ELF"}
faltan = [(s, n) for s, n in usadas.items() if n >= 4 and s not in listadas and s not in IGNORA]
print("### Siglas usadas 4+ veces que NO estan en pre/acronimos.tex  (%d)" % len(faltan))
for s, n in sorted(faltan, key=lambda x: -x[1]):
    i = texto.find(s)
    print("    %-8s x%-4d 1a vez: ...%s..." % (s, n, ' '.join(texto[max(0, i - 55):i + 25].split())[-70:]))
print()

# --- 2. frases largas, solo prosa real --------------------------------------
print("### Frases de mas de 55 palabras (solo prosa, sin tablas)")
largas = []
for f, s in raw.items():
    t = body(s)
    plano = re.sub(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?", "", t).replace("{", "").replace("}", "")
    for m in re.finditer(r"[^.!?:]{100,}[.!?]", plano):
        frag = ' '.join(m.group(0).split())
        w = len(frag.split())
        if w > 55 and '&' not in frag and '\\\\' not in frag:
            largas.append((w, "%s:%d" % (S(f), plano[:m.start()].count('\n') + 1), frag[:72]))
largas.sort(reverse=True)
print("    total: %d\n" % len(largas))
for w, l, frag in largas:
    print("    %-3dp  %-42s %s..." % (w, l, frag))
