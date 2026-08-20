"""Segmentación en frases del texto en español del TFM."""

import re

import pysbd

# Abreviaturas del documento que pysbd no conoce. Se protegen sustituyendo el
# punto por un carácter privado antes de segmentar, y se restauran después.
_ABBREV = [
    "fig.", "tab.", "p. ej.", "etc.", "art.", "apdo.", "núm.", "aprox.",
    "ref.", "vs.", "Sr.", "Dr.", "Fig.", "Tab.",
]
_SENTINEL = ""

_segmenter = pysbd.Segmenter(language="es", clean=False)


def _protect(text: str) -> str:
    for abbr in _ABBREV:
        text = text.replace(abbr, abbr.replace(".", _SENTINEL))
    # Números decimales con punto: 3.3 V
    text = re.sub(r"(\d)\.(\d)", rf"\1{_SENTINEL}\2", text)
    return text


def _restore(text: str) -> str:
    return text.replace(_SENTINEL, ".")


def split_sentences(text: str) -> list[str]:
    """Devuelve las frases del texto, sin fragmentos vacíos."""
    if not text.strip():
        return []
    protected = _protect(text)
    pieces = _segmenter.segment(protected)
    return [_restore(p).strip() for p in pieces if _restore(p).strip()]
