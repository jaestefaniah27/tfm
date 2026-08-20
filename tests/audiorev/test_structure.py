from tools.audiorev.model import SourceLine
from tools.audiorev.structure import slugify, split_units, rechunk


def _lines(text, tex_file="capitulos/cap3/entorno_desarrollo.tex"):
    return [
        SourceLine(tex_file=tex_file, lineno=i, text=t)
        for i, t in enumerate(text.strip("\n").split("\n"), start=1)
    ]


def test_slugify_strips_accents_latex_and_punctuation():
    assert slugify("Oscilador controlado numéricamente (NCO)") == "oscilador-controlado-numericamente-nco"
    assert slugify(r"Bloque \textit{top}") == "bloque-top"
    assert slugify("A.1 Mapa de señales CDHS") == "a-1-mapa-de-senales-cdhs"


def test_splits_at_every_heading_level():
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\section{Preparación del entorno}
Texto de la sección.
\subsection{Instalación de Vivado}
Texto de la subsección.
\subsubsection{Detalle}
Texto del detalle.
"""
        )
    )
    assert [u.title for u in units] == [
        "Preparación del entorno",
        "Instalación de Vivado",
        "Detalle",
    ]
    assert [u.level for u in units] == [1, 2, 3]
    assert all(u.chapter_title == "Desarrollo" for u in units)


def test_text_before_a_child_heading_belongs_to_the_parent():
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\section{Padre}
Esta frase es del padre.
\subsection{Hijo}
Esta es del hijo.
"""
        )
    )
    padre = units[0]
    assert any("del padre" in l.text for l in padre.lines)
    assert not any("del hijo" in l.text for l in padre.lines)


def test_unit_id_is_stable_and_independent_of_position():
    a = split_units(_lines("\\chapter{Desarrollo}\n\\subsection{Transmisor}\nX.\n"))[0]
    b = split_units(
        _lines("\\chapter{Desarrollo}\n\\subsection{Otro}\nY.\n\\subsection{Transmisor}\nX.\n")
    )[1]
    assert a.unit_id == b.unit_id
    assert a.unit_id.startswith("c03-")


def test_starred_sections_open_a_unit_too():
    units = split_units(
        _lines(
            "\\chapter{Anexo A}\n\\section*{A.1 Mapa de señales CDHS}\nTexto.\n",
            tex_file="capitulos/anexos/anexo1.tex",
        )
    )
    assert units[0].title == "A.1 Mapa de señales CDHS"


def test_rechunk_splits_a_long_headless_unit_on_paragraph_boundaries():
    body = "\n\n".join(["palabra " * 100] * 8)  # 800 palabras en 8 párrafos
    units = split_units(
        _lines(f"\\chapter{{Anexo B}}\n\\section{{Anexo}}\n{body}\n",
               tex_file="capitulos/anexos/anexoA.tex")
    )
    chunks = rechunk(units, max_words=600, target_words=450)
    assert len(chunks) >= 2
    assert chunks[0].unit_id.endswith("-p01")
    assert chunks[1].unit_id.endswith("-p02")
    assert all(len(" ".join(l.text for l in c.lines).split()) <= 600 for c in chunks)


def test_rechunk_leaves_short_units_untouched():
    units = split_units(_lines("\\chapter{Desarrollo}\n\\section{Corto}\nDos palabras.\n"))
    assert rechunk(units)[0].unit_id == units[0].unit_id


def test_structures_the_real_tfm(tex_root, repo_root):
    from tools.audiorev.expand import expand

    units = split_units(expand(tex_root / "main.tex", repo_root))
    assert 120 <= len(units) <= 150
    assert len({u.unit_id for u in units}) == len(units)
    assert any(u.title.startswith("Oscilador controlado") for u in units)


def test_chapter_number_falls_back_to_counter_when_no_cap_fragment():
    # Ni los anexos (capitulos/anexos/) ni los ficheros de pre/ tienen fragmento capN
    # en su ruta, así que deben usar el contador de \chapter vistos.
    lines = _lines(
        "\\chapter{Introducción}\n\\chapter{Anexo A}\n\\section{Primero}\nTexto.\n",
        tex_file="capitulos/anexos/anexoA.tex",
    )
    units = split_units(lines)
    assert units[0].chapter == 2
    assert units[0].unit_id.startswith("c02-")
