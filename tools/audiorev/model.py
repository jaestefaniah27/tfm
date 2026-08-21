"""Estructuras de datos compartidas por toda la cadena de conversión."""

from dataclasses import dataclass, field


@dataclass
class SourceLine:
    """Una línea del documento expandido, con su origen real."""

    tex_file: str
    lineno: int
    text: str


@dataclass
class Block:
    """Un bloque que no se lee en voz alta y se muestra en pantalla."""

    after_sentence: int
    type: str  # code | table | figure | plot
    caption: str
    ref: str | None
    raw: str
    html: str


@dataclass
class Sentence:
    idx: int
    text: str
    spoken: str
    hash: str
    tex_line: int
    # Frase tal cual está en el .tex (comandos incluidos, solo con el
    # espaciado colapsado). Es el ancla primaria del apartado 3.3 del diseño:
    # `text` lleva los comandos quitados y los \ref resueltos, así que casi
    # nunca aparece literalmente en el fichero de origen. Vacío en las frases
    # sintéticas (el aviso hablado de un bloque visual), que no vienen del .tex.
    tex_raw: str = ""
    t_start: float = 0.0
    t_end: float = 0.0


@dataclass
class Unit:
    unit_id: str
    chapter: int
    chapter_title: str
    level: int
    title: str
    tex_file: str
    tex_lines: tuple[int, int]
    lines: list[SourceLine] = field(default_factory=list)
    sentences: list[Sentence] = field(default_factory=list)
    blocks: list[Block] = field(default_factory=list)
    duration_s: float = 0.0
