"""Extracción de los bloques visuales: figuras, tablas, código y gráficas."""

import html as htmlmod
import re

from .model import Block, SourceLine

_KIND = {
    "figure": "figure",
    "sidewaysfigure": "figure",
    "table": "table",
    "tabular": "table",
    "longtable": "table",
    "tabularx": "table",
    "lstlisting": "code",
    "verbatim": "code",
    "tikzpicture": "plot",
    "axis": "plot",
}

_BEGIN = re.compile(r"\\begin\{([a-zA-Z*]+)\}")
_END = re.compile(r"\\end\{([a-zA-Z*]+)\}")
_CAPTION = re.compile(r"\\caption\{(.*)\}")
_LABEL = re.compile(r"\\label\{([^}]+)\}")


def _own_caption_and_label(block_lines: list[SourceLine]) -> tuple[re.Match | None, re.Match | None]:
    """Busca el `\\caption` y el `\\label` propios del bloque (profundidad 0),
    ignorando los que pertenezcan a entornos anidados (p.ej. `subfigure`)."""
    caption = None
    label = None
    depth = 0
    # Las líneas primera y última son el propio \begin/\end del bloque:
    # se excluyen para que la profundidad 0 represente el nivel del bloque.
    for line in block_lines[1:-1]:
        if caption is None and depth == 0:
            m = _CAPTION.search(line.text)
            if m:
                caption = m
        if label is None and depth == 0:
            m = _LABEL.search(line.text)
            if m:
                label = m
        for _ in _BEGIN.finditer(line.text):
            depth += 1
        for _ in _END.finditer(line.text):
            depth -= 1
    return caption, label


def _strip_latex(text: str) -> str:
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", text)
    return re.sub(r"\\[a-zA-Z]+\s*", "", text).strip()


def _to_html(kind: str, raw: str) -> str:
    if kind == "code":
        body = re.sub(r"\\begin\{[^}]*\}(\[[^\]]*\])?|\\end\{[^}]*\}", "", raw)
        return f"<pre><code>{htmlmod.escape(body.strip())}</code></pre>"
    if kind == "table":
        rows = []
        for line in raw.splitlines():
            if "&" not in line:
                continue
            cells = [_strip_latex(c) for c in line.split(r"\\")[0].split("&")]
            rows.append("<tr>" + "".join(f"<td>{htmlmod.escape(c)}</td>" for c in cells) + "</tr>")
        return "<table>" + "".join(rows) + "</table>"
    return ""


def extract_blocks(lines: list[SourceLine]) -> tuple[list[SourceLine], list[Block]]:
    """Saca los bloques visuales y deja un marcador en su lugar."""
    kept: list[SourceLine] = []
    blocks: list[Block] = []
    i = 0
    while i < len(lines):
        m = _BEGIN.search(lines[i].text)
        if not m or m.group(1) not in _KIND:
            kept.append(lines[i])
            i += 1
            continue

        env = m.group(1)
        depth = 1
        j = i + 1
        while j < len(lines) and depth > 0:
            if _BEGIN.search(lines[j].text) and _BEGIN.search(lines[j].text).group(1) == env:
                depth += 1
            end = _END.search(lines[j].text)
            if end and end.group(1) == env:
                depth -= 1
            j += 1

        raw = "\n".join(l.text for l in lines[i:j])
        caption, label = _own_caption_and_label(lines[i:j])
        kind = _KIND[env]
        blocks.append(
            Block(
                after_sentence=-1,
                type=kind,
                caption=_strip_latex(caption.group(1)) if caption else "",
                ref=label.group(1) if label else None,
                raw=raw,
                html=_to_html(kind, raw),
            )
        )
        kept.append(
            SourceLine(
                tex_file=lines[i].tex_file,
                lineno=lines[i].lineno,
                text=f"%%BLOCK:{len(blocks) - 1}%%",
            )
        )
        i = j
    return kept, blocks


_CUE_NOUN = {"figure": "figura", "table": "tabla", "code": "listado", "plot": "gráfica"}


def spoken_cue(block: Block, labels: dict[str, tuple[str, str]]) -> str:
    """Aviso hablado que ocupa en el audio el sitio del bloque visual.

    El apartado 4 del diseño lo describe así: «tabla 4.2, mapa de registros,
    en pantalla». El número sale de resolver el `\\label` del bloque contra
    `main.aux`; si no lo tiene, se dice solo el tipo.
    """
    noun = _CUE_NOUN.get(block.type, "bloque")
    entry = labels.get(block.ref) if block.ref else None
    partes = [f"{noun} {entry[0]}" if entry else noun]
    if block.caption:
        partes.append(block.caption.rstrip(" ."))
    partes.append("en pantalla")
    return ", ".join(partes) + "."
