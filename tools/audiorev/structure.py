"""Partición del documento en unidades de escucha."""

import re
import unicodedata
from pathlib import PurePosixPath

from .model import SourceLine, Unit

_HEADING_CMD = re.compile(r"\\(section|subsection|subsubsection)\*?\{")
_CHAPTER_CMD = re.compile(r"\\chapter\*?\{")
_LEVEL = {"section": 1, "subsection": 2, "subsubsection": 3}
_SLUG_MAX = 48
_CAP_PATH = re.compile(r"(?:^|/)cap(\d+)(?:/|$)")
_BLOCK_MARKER = re.compile(r"%%BLOCK:\d+%%")
# Comando de LaTeX con sus argumentos opcionales y su primer grupo: se usa
# solo para decidir si una línea tiene contenido propio (prosa) o es pura
# maquetación (\newpage, \begin{center}, \tableofcontents...).
_ANY_COMMAND = re.compile(r"\\[a-zA-Z]+\*?(?:\[[^\]]*\])?(?:\{[^{}]*\})?")



def _balanced_group(text: str, open_idx: int) -> str | None:
    r"""Devuelve el contenido de `{...}` que empieza en `open_idx`, contando
    profundidad para respetar llaves anidadas (p.ej. `\textit{...}` dentro
    del título). `None` si el grupo no cierra en la misma línea."""
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1 : i]
    return None


def _match_chapter(text: str) -> str | None:
    r"""Extrae el título de un `\chapter{...}`, ignorando lo que venga
    después del `}` de cierre (p.ej. un `\label{...}` en la misma línea)."""
    m = _CHAPTER_CMD.search(text)
    if not m:
        return None
    return _balanced_group(text, m.end() - 1)


def _match_heading(text: str) -> tuple[str, str] | None:
    r"""Extrae (kind, título) de un `\section`/`\subsection`/`\subsubsection`.

    El título es el PRIMER grupo `{...}` balanceado tras el comando, no todo
    lo que haya hasta la última llave de la línea: un `\label{...}` en la
    misma línea no debe colarse en el título, y un título con llaves
    anidadas (p.ej. `\textit{jumper}`) no debe truncarse en la primera `}`.
    """
    m = _HEADING_CMD.search(text)
    if not m:
        return None
    title = _balanced_group(text, m.end() - 1)
    if title is None:
        return None
    return m.group(1), title


def _is_content(text: str) -> bool:
    """¿Esta línea aporta contenido propio, o es pura maquetación?

    Se usa para decidir si hay que abrir una unidad sintética: `\newpage`,
    `\begin{center}` o `\tableofcontents` no son prosa y no deben crear una
    unidad, pero el primer párrafo de un capítulo sí. Un marcador de bloque
    visual cuenta como contenido: la tarjeta necesita una unidad donde vivir.
    """
    if _BLOCK_MARKER.search(text):
        return True
    stripped = re.sub(r"(?<!\\)%.*$", "", text)
    previous = None
    while previous != stripped:
        previous = stripped
        stripped = _ANY_COMMAND.sub(" ", stripped)
    stripped = re.sub(r"[{}$~\\]", " ", stripped)
    return bool(re.search(r"[0-9A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}", stripped))


def _file_title(tex_file: str) -> str:
    """Título de recambio para una unidad sintética sin capítulo con nombre."""
    stem = PurePosixPath(tex_file).stem.replace("_", " ").replace("-", " ")
    return stem[:1].upper() + stem[1:]


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
    # Pila de encabezados abiertos (level, slug) para poder cualificar por
    # ancestro cuando dos apartados del mismo fichero comparten título.
    # Se vacía al cambiar de capítulo o de fichero: un capítulo o anexo que
    # empieza directamente en \subsection/\subsubsection (sin \section
    # propio) no debe heredar el último ancestro del capítulo o fichero
    # anterior, que sería un padre semánticamente incorrecto.
    ancestry: list[tuple[int, str]] = []
    current_tex_file: str | None = None
    # base_id -> lista de (unit, prefijo "cNN-stem", slug del título,
    # slug del padre inmediato o None), en orden de aparición. Se resuelve
    # al final para desambiguar por ancestro en vez de por posición (ver
    # _disambiguate): el `unit_id` no debe depender de en qué orden
    # aparecen los apartados hermanos, solo de su ancestro.
    by_base_id: dict[str, list[tuple[Unit, str, str, str | None]]] = {}

    # El texto anterior al primer encabezado de un fichero (o de un capítulo)
    # NO pertenece a la última unidad del fichero anterior: se le abre una
    # unidad sintética propia, con su `tex_file` y su capítulo correctos. Sin
    # esto, la introducción de un capítulo se archiva bajo el capítulo previo
    # y un fichero sin ningún encabezado —como `pre/resumen.tex`, que abre con
    # `\chapter*{}`— se pierde entero y en silencio.
    # La unidad sintética se abre de forma perezosa, al ver la primera línea
    # con contenido, para no crear unidades vacías por cada fichero ni
    # convertir en unidad la maquetación de `main.tex` (portadas, índices).
    chapter_seen = False

    def _open_synthetic(line: SourceLine) -> Unit:
        chapter = _chapter_number(line.tex_file, chapter_num)
        stem = PurePosixPath(line.tex_file).stem
        prefix = f"c{chapter:02d}-{slugify(stem)}"
        base_id = f"{prefix}-intro"
        unit = Unit(
            unit_id=base_id,
            chapter=chapter,
            chapter_title=chapter_title,
            # Nivel 0: por encima de \section, que es el nivel 1.
            level=0,
            title=chapter_title or _file_title(line.tex_file),
            tex_file=line.tex_file,
            tex_lines=(line.lineno, line.lineno),
        )
        units.append(unit)
        by_base_id.setdefault(base_id, []).append((unit, prefix, "intro", None))
        return unit

    for line in lines:
        if line.tex_file != current_tex_file:
            current_tex_file = line.tex_file
            ancestry.clear()
            current = None

        chap_title = _match_chapter(line.text)
        if chap_title is not None:
            chapter_num += 1
            chapter_seen = True
            chapter_title = _strip(chap_title)
            ancestry.clear()
            current = None
            continue

        head = _match_heading(line.text)
        if head:
            kind, raw_title = head
            title = _strip(raw_title)
            level = _LEVEL[kind]
            title_slug = slugify(title)
            stem = PurePosixPath(line.tex_file).stem

            while ancestry and ancestry[-1][0] >= level:
                ancestry.pop()
            parent_slug = ancestry[-1][1] if ancestry else None
            ancestry.append((level, title_slug))

            prefix = f"c{_chapter_number(line.tex_file, chapter_num):02d}-{slugify(stem)}"
            base_id = f"{prefix}-{title_slug}"
            current = Unit(
                unit_id=base_id,
                chapter=_chapter_number(line.tex_file, chapter_num),
                chapter_title=chapter_title,
                level=level,
                title=title,
                tex_file=line.tex_file,
                tex_lines=(line.lineno, line.lineno),
            )
            units.append(current)
            by_base_id.setdefault(base_id, []).append((current, prefix, title_slug, parent_slug))
            continue

        if current is None:
            if not chapter_seen or not _is_content(line.text):
                continue
            current = _open_synthetic(line)

        if line.text.strip():
            current.lines.append(line)
            current.tex_lines = (current.tex_lines[0], line.lineno)
        else:
            current.lines.append(line)

    _disambiguate(by_base_id)
    return units


def _disambiguate(by_base_id: dict[str, list[tuple[Unit, str, str, str | None]]]) -> None:
    """Resuelve colisiones de `unit_id` cualificando por el ancestro más cercano.

    El identificador no puede depender de la posición del apartado en el
    documento (invalidaría la caché de audio si alguien inserta un apartado
    antes), así que la colisión se rompe con el slug del encabezado padre
    inmediato (el `\\subsection` que contiene al `\\subsubsection`, etc.),
    no con un ordinal de aparición. Solo si dos apartados colisionan también
    tras cualificar por ancestro —o no tienen ancestro— se recurre a un
    ordinal como último recurso.

    La unicidad se comprueba contra el conjunto GLOBAL de identificadores ya
    asignados en toda la memoria, no solo entre los hermanos que comparten
    `base_id`: el recorte a `_SLUG_MAX` de un id cualificado podría, en
    principio, coincidir con el id de un apartado que nunca colisionó, y eso
    tiene que detectarse igualmente.
    """
    used: set[str] = set()

    # Los apartados que no colisionan reservan su id tal cual, sin cualificar.
    for base_id, entries in by_base_id.items():
        if len(entries) == 1:
            unit = entries[0][0]
            unit.unit_id = base_id
            used.add(base_id)

    for base_id, entries in by_base_id.items():
        if len(entries) == 1:
            continue

        for unit, prefix, title_slug, parent_slug in entries:
            if parent_slug is None:
                candidate = base_id
            else:
                tail = f"{parent_slug}-{title_slug}"[:_SLUG_MAX].rstrip("-")
                candidate = f"{prefix}-{tail}"

            final_id = candidate
            n = 1
            while final_id in used:
                # Sigue colisionando (mismo padre cualificado, sin padre, o
                # choque con un id de otro apartado ya asignado): último
                # recurso, un ordinal.
                n += 1
                final_id = f"{candidate}-{n}"

            unit.unit_id = final_id
            used.add(final_id)


def _strip(title: str) -> str:
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", title)
    return re.sub(r"\s+", " ", text).strip()


def _word_count(unit: Unit) -> int:
    return len(" ".join(l.text for l in unit.lines).split())


def _split_oversized_group(group: list[SourceLine], max_words: int) -> list[list[SourceLine]]:
    """Trocea un párrafo que por sí solo ya supera max_words.

    Se intenta primero por frontera de frase (`.`, `!`, `?`) para que el
    corte sea legible; si una sola frase sigue superando max_words (o no
    hay puntuación), se trocea directamente por palabras. El resultado
    sintetiza SourceLine nuevas (mismo tex_file/lineno de origen que el
    grupo) porque el corte puede caer en mitad de una línea real.
    """
    text = " ".join(l.text for l in group)
    words = text.split()
    if len(words) <= max_words:
        return [group]

    sentences = re.split(r"(?<=[.!?])\s+", text)
    pieces_text: list[str] = []
    current: list[str] = []

    def _flush() -> None:
        if current:
            pieces_text.append(" ".join(current))
            current.clear()

    for sentence in sentences:
        sentence_words = sentence.split()
        if len(sentence_words) > max_words:
            _flush()
            for i in range(0, len(sentence_words), max_words):
                pieces_text.append(" ".join(sentence_words[i : i + max_words]))
            continue
        if current and len(current) + len(sentence_words) > max_words:
            _flush()
        current.extend(sentence_words)
    _flush()

    tex_file = group[0].tex_file
    lineno = group[0].lineno
    return [[SourceLine(tex_file=tex_file, lineno=lineno, text=p)] for p in pieces_text]


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

        # Un párrafo que por sí solo ya supere max_words se trocea antes de
        # empaquetar, para que la garantía de "ningún trozo supera
        # max_words" sea real y no dependa de que los párrafos del origen
        # sean cortos.
        expanded: list[list[SourceLine]] = []
        for g in groups:
            expanded.extend(_split_oversized_group(g, max_words))
        groups = expanded

        chunk: list[SourceLine] = []
        pieces: list[list[SourceLine]] = []
        for group in groups:
            chunk_words = len(" ".join(l.text for l in chunk).split())
            group_words = len(" ".join(l.text for l in group).split())
            if chunk and chunk_words + group_words > max_words:
                pieces.append(chunk)
                chunk = []
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
