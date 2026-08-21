"""Normalización del LaTeX del TFM a texto pronunciable."""

import re

from .refs import spoken_ref

_UNITS = [
    (r"\bV\b", "voltios"),
    (r"\bmV\b", "milivoltios"),
    # lookahead para no confundir la "A" de amperios con la letra "A" suelta
    # (p. ej. un ítem de lista "A)" o la inicial de un nombre) en medio de una frase
    (r"\bA\b(?=\s|$|\.)", "amperios"),
    (r"\bmA\b", "miliamperios"),
    (r"\bMHz\b", "megahercios"),
    (r"\bkHz\b", "kilohercios"),
    (r"\bGHz\b", "gigahercios"),
    (r"\bHz\b", "hercios"),
    (r"\bMbps\b", "megabits por segundo"),
    (r"\bkbps\b", "kilobits por segundo"),
    (r"\bMB/s\b", "megabytes por segundo"),
    (r"\bKiB\b", "kibibytes"),
    (r"\bMiB\b", "mebibytes"),
    (r"\bus\b", "microsegundos"),
    (r"\bms\b", "milisegundos"),
    (r"\bns\b", "nanosegundos"),
    (r"\bmm\b", "milímetros"),
]

_FORMAT = re.compile(r"\\(?:textit|textbf|emph|texttt|textsc|underline|paragraph|subparagraph)\s*\{([^{}]*)\}")
_REF = re.compile(r"\\(?:ref|autoref|eqref)\{([^}]+)\}")
# El LaTeX ya escribe el artículo (y muchas veces el sustantivo) delante de la
# referencia --«la figura~\ref{...}», «en la sección~\ref{...}»--, y spoken_ref
# añade los suyos: se oía «la figura la figura 3.1» y «la sección el apartado
# 4.1». Se absorbe lo que la expansión va a repetir.
_REF_CON_ARTICULO = re.compile(
    r"(?P<lead>"
    r"(?:\b(?:el|la|los|las)\s+)?"
    r"(?:\b(?:figuras?|tablas?|secci(?:ón|on|ones)|apartados?|cap[ií]tulos?"
    r"|ecuaci(?:ón|on|ones)|listados?|gr[aá]ficas?)\s*)?"
    r")\\(?:ref|autoref|eqref)\{(?P<label>[^}]+)\}",
    re.IGNORECASE,
)
_CITE = re.compile(r"\\cite\{[^}]*\}")
_FOOTNOTE = re.compile(r"\\footnote\{([^{}]*)\}")
_MATH = re.compile(r"\$([^$]*)\$")
_DISPLAY = re.compile(r"\\\[(.*?)\\\]", re.DOTALL)
_BLOCK = re.compile(r"%%BLOCK:\d+%%")
_COMMENT = re.compile(r"(?<!\\)%.*$", re.MULTILINE)
_SIMPLE_MATH = re.compile(r"^[A-Za-z0-9\s=+\-*/,.()<>]+$")
_ANY_COMMAND = re.compile(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?(\{[^{}]*\})?")
# Detección puramente ortográfica (mayúsculas seguidas): acepta falsos positivos
# como palabras en mayúsculas o números romanos, que el .lower() de más abajo
# deja igualmente legibles.
_ACRONYM = re.compile(r"\b[A-Z][A-Z0-9]{1,9}\b")


def _unwrap_formatting(text: str) -> str:
    previous = None
    while previous != text:
        previous = text
        text = _FORMAT.sub(r"\1", text)
    return text


def _strip_common(text: str, guion_bajo: str = "_") -> str:
    text = _COMMENT.sub("", text)
    text = _BLOCK.sub("", text)
    text = _unwrap_formatting(text)
    text = _CITE.sub("", text)
    text = text.replace("~", " ").replace(r"\%", "%").replace(r"\_", guion_bajo)
    text = text.replace(r"\,", "")  # separador de miles en LaTeX: 9\,600 -> 9600
    text = text.replace("``", '"').replace("''", '"').replace("---", ", ")
    return text


def _finish(text: str) -> str:
    text = _ANY_COMMAND.sub("", text)
    text = re.sub(r"[{}]", "", text)
    text = re.sub(r"\s+([,.;:])", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def strip_comments(text: str) -> str:
    """Elimina los comentarios de LaTeX (% no escapado hasta fin de línea).

    Se expone aparte porque build.py necesita partir el cuerpo en frases
    ANTES de normalizar, y un comentario sin quitar desplazaría o rompería
    esa segmentación; tanto plain() como to_spoken() siguen quitando sus
    propios comentarios internamente para poder usarse de forma independiente.
    """
    return _COMMENT.sub("", text)


def plain(text: str) -> str:
    """Texto para mostrar en pantalla: sin comandos, con los acrónimos intactos."""
    text = _strip_common(text)
    text = _FOOTNOTE.sub(r" (\1)", text)
    text = _REF.sub("referencia", text)
    text = _MATH.sub(lambda m: m.group(1).strip(), text)
    return _finish(text)


def _ref_hablada(match: re.Match, labels: dict) -> str:
    """Sustituye la referencia y lo que la precede por la expansión hablada,
    conservando la mayúscula inicial si la llevaba lo absorbido."""
    hablada = spoken_ref(match.group("label"), labels)
    lead = match.group("lead")
    if lead[:1].isupper():
        hablada = hablada[:1].upper() + hablada[1:]
    return hablada


def to_spoken(text: str, labels: dict, pron: dict) -> str:
    """Texto para el motor de voz: acrónimos deletreados y unidades expandidas."""
    # El apartado 4.1 del diseño: en \texttt{mi\_var} el guion bajo se lee
    # como una pausa breve, no como «guion bajo» ni pegando las dos mitades.
    # Solo en la voz: plain() lo conserva para el texto en pantalla.
    text = _strip_common(text, guion_bajo=", ")

    footnotes: list[str] = []

    def _grab_footnote(match: re.Match) -> str:
        footnotes.append(match.group(1).strip())
        return ""

    text = _FOOTNOTE.sub(_grab_footnote, text)
    text = _REF_CON_ARTICULO.sub(lambda m: _ref_hablada(m, labels), text)
    text = _REF.sub(lambda m: spoken_ref(m.group(1), labels), text)
    text = _DISPLAY.sub(" fórmula, ver documento ", text)
    text = _MATH.sub(
        lambda m: m.group(1).strip()
        if _SIMPLE_MATH.match(m.group(1).strip())
        else " fórmula, ver documento ",
        text,
    )

    for pattern, spoken_unit in _UNITS:
        text = re.sub(pattern, spoken_unit, text)

    text = _ACRONYM.sub(lambda m: pron.get(m.group(0), m.group(0).lower()), text)

    out = _finish(text)
    if footnotes:
        out = (out + " nota al pie: " + " ".join(footnotes)).strip()
    return out
