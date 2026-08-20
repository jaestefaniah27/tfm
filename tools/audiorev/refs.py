"""Resolución de las etiquetas de LaTeX a su número y a su tipo."""

import re
from pathlib import Path

# \newlabel{NOMBRE}{{NUMERO}{PAGINA}{TITULO}{ANCLA}{}}
# El título puede contener llaves anidadas, así que no se puede capturar con una
# expresión regular plana: se localiza el nombre y el número, y el ancla se busca
# como el último grupo del tipo "palabra.algo" de la línea.
_NEWLABEL = re.compile(
    r"\\newlabel\{(?P<name>[^}]+)\}\{\{(?P<num>[^{}]*)\}\{(?P<page>[^{}]*)\}"
)
_ANCHOR = re.compile(
    r"\{(figure|table|section|subsection|subsubsection|equation|lstlisting|chapter)\."
)

_SPOKEN = {
    "figure": "la figura",
    "table": "la tabla",
    "equation": "la ecuación",
    "lstlisting": "el listado",
    "chapter": "el capítulo",
    "section": "el apartado",
    "subsection": "el apartado",
    "subsubsection": "el apartado",
}


def load_labels(aux_path: Path) -> dict[str, tuple[str, str]]:
    """Devuelve {etiqueta: (numero, tipo)} leyendo un fichero .aux de LaTeX."""
    labels: dict[str, tuple[str, str]] = {}
    for line in aux_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = _NEWLABEL.search(line)
        if not m:
            continue
        anchor = _ANCHOR.search(line, m.end())
        kind = anchor.group(1) if anchor else "section"
        labels[m.group("name")] = (m.group("num"), kind)
    return labels


def spoken_ref(label: str, labels: dict[str, tuple[str, str]]) -> str:
    """Convierte una etiqueta en la frase que se leerá en voz alta."""
    entry = labels.get(label)
    if entry is None:
        return "la referencia correspondiente"
    number, kind = entry
    return f"{_SPOKEN.get(kind, 'el apartado')} {number}"
