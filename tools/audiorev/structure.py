"""Partición del documento en unidades de escucha."""

import re
import unicodedata
from pathlib import PurePosixPath

from .model import SourceLine, Unit

_HEADING = re.compile(r"\\(section|subsection|subsubsection)\*?\{(.*)\}\s*$")
_CHAPTER = re.compile(r"\\chapter\*?\{(.*)\}\s*$")
_LEVEL = {"section": 1, "subsection": 2, "subsubsection": 3}
_SLUG_MAX = 48
_CAP_PATH = re.compile(r"(?:^|/)cap(\d+)(?:/|$)")


def slugify(title: str) -> str:
    """Convierte un título en un identificador estable, ascii y con guiones."""
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", title)
    text = re.sub(r"\\[a-zA-Z]+\s*", "", text)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").lower()
    return text[:_SLUG_MAX].rstrip("-")


def _chapter_number(tex_file: str, chapters_seen: int) -> int:
    """Deriva el número de capítulo de la ruta (capN) cuando existe.

    Contar los `\\chapter{...}` vistos hasta el momento es frágil: main.tex
    incluye capítulos sin numerar (agradecimientos, acrónimos) antes de los
    numerados, así que el contador no coincide con el número real del
    capítulo. La ruta `capitulos/capN/...` es la fuente de verdad cuando
    existe; solo se recurre al contador para ficheros sin ese fragmento
    (anexos y ficheros de `pre/`).
    """
    m = _CAP_PATH.search(tex_file)
    if m:
        return int(m.group(1))
    return chapters_seen


def split_units(lines: list[SourceLine]) -> list[Unit]:
    """Parte el documento expandido en una unidad por encabezado."""
    units: list[Unit] = []
    chapter_num = 0
    chapter_title = ""
    current: Unit | None = None
    # Algunos apartados repiten título dentro del mismo fichero (p.ej. varias
    # subsecciones llamadas "Alimentación" bajo distintos padres). Se añade un
    # sufijo por orden de aparición solo cuando hay colisión, para no romper
    # la estabilidad del caso normal (un único título por fichero).
    seen: dict[str, int] = {}

    for line in lines:
        chap = _CHAPTER.search(line.text)
        if chap:
            chapter_num += 1
            chapter_title = _strip(chap.group(1))
            continue

        head = _HEADING.search(line.text)
        if head:
            kind, raw_title = head.group(1), head.group(2)
            title = _strip(raw_title)
            stem = PurePosixPath(line.tex_file).stem
            base_id = f"c{_chapter_number(line.tex_file, chapter_num):02d}-{slugify(stem)}-{slugify(title)}"
            seen[base_id] = seen.get(base_id, 0) + 1
            unit_id = base_id if seen[base_id] == 1 else f"{base_id}-{seen[base_id]}"
            current = Unit(
                unit_id=unit_id,
                chapter=_chapter_number(line.tex_file, chapter_num),
                chapter_title=chapter_title,
                level=_LEVEL[kind],
                title=title,
                tex_file=line.tex_file,
                tex_lines=(line.lineno, line.lineno),
            )
            units.append(current)
            continue

        if current is not None and line.text.strip():
            current.lines.append(line)
            current.tex_lines = (current.tex_lines[0], line.lineno)
        elif current is not None:
            current.lines.append(line)

    return units


def _strip(title: str) -> str:
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", title)
    return re.sub(r"\s+", " ", text).strip()


def _word_count(unit: Unit) -> int:
    return len(" ".join(l.text for l in unit.lines).split())


def rechunk(units: list[Unit], max_words: int = 600, target_words: int = 450) -> list[Unit]:
    """Parte por frontera de párrafo las unidades que superen max_words."""
    out: list[Unit] = []
    for unit in units:
        if _word_count(unit) <= max_words:
            out.append(unit)
            continue

        groups: list[list[SourceLine]] = [[]]
        for line in unit.lines:
            if not line.text.strip() and groups[-1]:
                groups.append([])
            elif line.text.strip():
                groups[-1].append(line)
        groups = [g for g in groups if g]

        chunk: list[SourceLine] = []
        pieces: list[list[SourceLine]] = []
        for group in groups:
            chunk.extend(group)
            if len(" ".join(l.text for l in chunk).split()) >= target_words:
                pieces.append(chunk)
                chunk = []
        if chunk:
            pieces.append(chunk)

        for n, piece in enumerate(pieces, start=1):
            out.append(
                Unit(
                    unit_id=f"{unit.unit_id}-p{n:02d}",
                    chapter=unit.chapter,
                    chapter_title=unit.chapter_title,
                    level=unit.level,
                    title=f"{unit.title} ({n} de {len(pieces)})",
                    tex_file=unit.tex_file,
                    tex_lines=(piece[0].lineno, piece[-1].lineno),
                    lines=piece,
                )
            )
    return out
