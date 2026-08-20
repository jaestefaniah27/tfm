"""Corrector ortografico de la memoria (hunspell es_ES a traves de spylls).

Uso, desde plantilla_tft_etsit/:
    python ../tools/ortografia.py            # solo palabras desconocidas
    python ../tools/ortografia.py -s         # con sugerencias (mas lento)

Ignora: listados y figuras tikz, contenido de \\texttt y \\lstinline, argumentos
de \\ref/\\cite/\\label, texto en \\textit (anglicismos deliberados), nombres de
entorno, siglas en mayusculas y las palabras de tools/dic/whitelist.txt.

Las palabras correctas que el diccionario no reconozca se anaden a esa
whitelist; asi cada ejecucion deja solo erratas de verdad.
"""
import io, os, re, sys, glob, collections
from spylls.hunspell import Dictionary

AQUI = os.path.dirname(os.path.abspath(__file__))
dic = Dictionary.from_files(os.path.join(AQUI, 'dic', 'es_ES'))

wl_path = os.path.join(AQUI, 'dic', 'whitelist.txt')
WHITE = set()
if os.path.exists(wl_path):
    for l in io.open(wl_path, encoding='utf-8'):
        l = l.split('#')[0].strip().lower()
        if l:
            WHITE.add(l)

FUERA = [
    r"\\begin\{(lstlisting|tikzpicture|axis|verbatim)\}.*?\\end\{\1\}",
    r"\\addcontentsline\{[^{}]*\}\{[^{}]*\}",
    r"\\(begin|end)\{[^{}]*\}",
    r"\\lstinline\|[^|]*\|",
    r"\\(texttt|lstinline|ref|cite|label|input|import|includegraphics|url|href|textcolor)\{[^{}]*\}",
    r"\\textit\{[^{}]*\}",
    r"\\[a-zA-Z]+\*?",
    r"%.*",
    r"\{[rlcp|@ ]{2,}\}",
]

def limpia(s):
    for p in FUERA:
        s = re.sub(p, " ", s, flags=re.S)
    return s

PALABRA = re.compile(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ'-]{2,}")

def revisa(files, sugerir=False):
    malas = collections.Counter()
    donde = {}
    for f in files:
        s = io.open(f, encoding='utf-8').read()
        for i, linea in enumerate(limpia(s).split('\n'), 1):
            for m in PALABRA.finditer(linea):
                w = m.group(0)
                if w.isupper() or any(c.isdigit() for c in w):
                    continue
                if w.lower() in WHITE:
                    continue
                if dic.lookup(w) or dic.lookup(w.lower()) or dic.lookup(w.capitalize()):
                    continue
                malas[w] += 1
                donde.setdefault(w, "%s:%d" % (f.replace('\\', '/'), i))
    print("=== palabras no reconocidas: %d distintas, %d apariciones ===" % (len(malas), sum(malas.values())))
    for w, n in malas.most_common():
        linea = "  %-24s x%-3d %s" % (w, n, donde[w])
        if sugerir:
            try:
                sug = list(dic.suggest(w))[:3]
            except Exception:
                sug = []
            if sug:
                linea += "   -> " + ", ".join(sug)
        print(linea)
    return malas

if __name__ == '__main__':
    # main.tex se excluye: es preambulo, y los nombres de paquete no son prosa.
    files = sorted(glob.glob('capitulos/**/*.tex', recursive=True)) + sorted(glob.glob('pre/*.tex'))
    files = [f for f in files if os.path.exists(f)]
    revisa(files, sugerir='-s' in sys.argv)
