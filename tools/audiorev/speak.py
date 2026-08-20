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


def _strip_common(text: str) -> str:
    text = _COMMENT.sub("", text)
    text = _BLOCK.sub("", text)
    text = _unwrap_formatting(text)
    text = _CITE.sub("", text)
    text = text.replace("~", " ").replace(r"\%", "%").replace(r"\_", "_")
    text = text.replace(r"\,", "")  # separador de miles en LaTeX: 9\,600 -> 9600
    text = text.replace("``", '"').replace("''", '"').replace("---", ", ")
    return text


def _finish(text: str) -> str:
    text = _ANY_COMMAND.sub("", text)
    text = re.sub(r"[{}]", "", text)
    text = re.sub(r"\s+([,.;:])", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def plain(text: str) -> str:
    """Texto para mostrar en pantalla: sin comandos, con los acrónimos intactos."""
    text = _strip_common(text)
    text = _FOOTNOTE.sub(r" (\1)", text)
    text = _REF.sub("referencia", text)
    text = _MATH.sub(lambda m: m.group(1).strip(), text)
    return _finish(text)


def to_spoken(text: str, labels: dict, pron: dict) -> str:
    """Texto para el motor de voz: acrónimos deletreados y unidades expandidas."""
    text = _strip_common(text)

    footnotes: list[str] = []

    def _grab_footnote(match: re.Match) -> str:
        footnotes.append(match.group(1).strip())
        return ""

    text = _FOOTNOTE.sub(_grab_footnote, text)
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
