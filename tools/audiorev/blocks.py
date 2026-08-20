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
        caption = _CAPTION.search(raw)
        label = _LABEL.search(raw)
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
