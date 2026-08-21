import re

from tools.audiorev.model import SourceLine, Unit
from tools.audiorev import structure
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


def test_colliding_titles_are_disambiguated_by_parent_not_by_ordinal():
    # Dos subsecciones hijas con el mismo título bajo dos padres distintos:
    # el unit_id debe cualificarse con el slug del padre, no con un ordinal
    # de aparición (eso haría que insertar un apartado antes cambiara el id
    # de otro y se invalidara su audio ya generado).
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\subsection{Diseño de la placa CDHS}
Texto.
\subsubsection{Alimentación}
Uno.
\subsection{Diseño de la placa AOCS}
Texto.
\subsubsection{Alimentación}
Dos.
"""
        )
    )
    aliment = [u for u in units if u.title == "Alimentación"]
    assert len(aliment) == 2
    ids = {u.unit_id for u in aliment}
    assert len(ids) == 2
    for uid in ids:
        # Ninguno debe terminar en un ordinal desnudo tipo "...-alimentacion-2".
        assert not re.search(r"-\d+$", uid)
    assert any("cdhs" in uid for uid in ids)
    assert any("aocs" in uid for uid in ids)


def test_heading_ignores_a_trailing_label_on_the_same_line():
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\subsection{Objetivos} \label{objetivos}
Texto.
"""
        )
    )
    assert units[0].title == "Objetivos"


def test_heading_title_survives_nested_braces():
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\subsubsection{Topología RS485 con bus compartido configurable por \textit{jumper}}
Texto.
"""
        )
    )
    assert units[0].title == "Topología RS485 con bus compartido configurable por jumper"



def test_rechunk_never_exceeds_max_words_even_with_one_huge_paragraph():
    # Un único párrafo muy por encima de max_words, sin puntuación que
    # ofrezca fronteras de frase: rechunk debe trocearlo igualmente.
    body = "palabra " * 700
    units = split_units(
        _lines(f"\\chapter{{Anexo B}}\n\\section{{Anexo}}\n{body}\n",
               tex_file="capitulos/anexos/anexoA.tex")
    )
    chunks = rechunk(units, max_words=600, target_words=450)
    assert len(chunks) >= 2
    for c in chunks:
        assert len(" ".join(l.text for l in c.lines).split()) <= 600


def test_ancestry_does_not_leak_across_chapter_or_file_boundary():
    # El segundo fichero abre directamente con un \subsection, sin
    # \section propio: no debe heredar el ancestro del capítulo/fichero
    # anterior.
    lines = _lines(
        "\\chapter{Uno}\n\\section{Padre}\n\\subsection{Hijo}\nTexto.\n",
        tex_file="capitulos/cap1/uno.tex",
    ) + _lines(
        "\\chapter{Dos}\n\\subsection{Suelto}\nOtro texto.\n",
        tex_file="capitulos/cap2/dos.tex",
    )
    units = split_units(lines)
    suelto = next(u for u in units if u.title == "Suelto")
    assert "padre" not in suelto.unit_id


def test_global_uniqueness_survives_truncated_qualified_collision(monkeypatch):
    # Se fuerza un _SLUG_MAX muy pequeño para que el id cualificado y
    # truncado de una colisión coincida EXACTAMENTE con el id, ya
    # reservado, de otro apartado que nunca colisionó. La desambiguación
    # debe seguir garantizando unicidad global, no solo entre hermanos.
    monkeypatch.setattr(structure, "_SLUG_MAX", 1)

    a = Unit(unit_id="", chapter=3, chapter_title="X", level=2,
             title="A", tex_file="f.tex", tex_lines=(1, 1))
    b1 = Unit(unit_id="", chapter=3, chapter_title="X", level=3,
              title="B", tex_file="f.tex", tex_lines=(2, 2))
    b2 = Unit(unit_id="", chapter=3, chapter_title="X", level=3,
              title="B", tex_file="f.tex", tex_lines=(3, 3))

    base_id_a = "c03-f-a"
    base_id_b = "c03-f-b"
    by_base_id = {
        base_id_a: [(a, "c03-f", "a", None)],
        # Con _SLUG_MAX=1, "a-b"[:1] == "a", así que el id cualificado de
        # b1/b2 sería "c03-f-a", idéntico al de `a`.
        base_id_b: [
            (b1, "c03-f", "b", "a"),
            (b2, "c03-f", "b", "a"),
        ],
    }

    structure._disambiguate(by_base_id)

    ids = [a.unit_id, b1.unit_id, b2.unit_id]
    assert len(set(ids)) == 3
    assert a.unit_id == base_id_a


def _word_count_for_test(unit):
    return len(" ".join(l.text for l in unit.lines).split())


def test_rechunk_over_the_real_tfm_respects_max_words_and_stays_unique(tex_root, repo_root):
    from tools.audiorev.expand import expand

    units = split_units(expand(tex_root / "main.tex", repo_root))
    chunks = rechunk(units, max_words=600, target_words=450)

    assert all(
        len(" ".join(l.text for l in c.lines).split()) <= 600 for c in chunks
    )
    assert len({c.unit_id for c in chunks}) == len(chunks)

    # Los anexos (sin encabezados propios) son la razón de ser de rechunk:
    # al menos una unidad original superaba max_words y debe haberse
    # partido en varios trozos "-p01", "-p02", ...
    oversized = [u for u in units if _word_count_for_test(u) > 600]
    assert oversized
    for u in oversized:
        pieces = [c for c in chunks if c.unit_id.startswith(f"{u.unit_id}-p")]
        assert len(pieces) >= 2


def test_every_prose_line_of_the_real_tfm_belongs_to_exactly_one_unit(tex_root, repo_root):
    # Invariante que cubre los dos fallos de archivado: la prosa que precede
    # al primer encabezado de un fichero no puede quedarse fuera de toda
    # unidad (era el caso de pre/resumen.tex, que se perdía entero) ni caer
    # en una unidad de OTRO fichero (era el caso del primer párrafo de
    # cap4/validacion_hardware.tex, archivado bajo cap3/transporte.tex).
    from tools.audiorev.blocks import extract_blocks
    from tools.audiorev.expand import expand

    lines, _ = extract_blocks(expand(tex_root / "main.tex", repo_root))
    units = split_units(lines)

    # Una línea puede estar en varias unidades solo si es el mismo objeto
    # repetido, cosa que no ocurre: se comprueba por identidad.
    owner: dict[int, Unit] = {}
    for unit in units:
        for line in unit.lines:
            assert id(line) not in owner, f"línea duplicada en dos unidades: {line}"
            owner[id(line)] = unit

    huerfanas: list[SourceLine] = []
    descolocadas: list[SourceLine] = []
    chapter_seen = False
    for line in lines:
        if structure._match_chapter(line.text) is not None:
            chapter_seen = True
            continue
        if not chapter_seen or structure._match_heading(line.text):
            continue  # preámbulo, portadas e índices, o el propio encabezado
        if not line.text.strip() or not structure._is_content(line.text):
            continue  # línea en blanco o pura maquetación (\newpage, \begin{center})
        unit = owner.get(id(line))
        if unit is None:
            huerfanas.append(line)
        elif unit.tex_file != line.tex_file:
            descolocadas.append(line)

    assert not huerfanas, f"{len(huerfanas)} líneas de prosa fuera de toda unidad: {huerfanas[:3]}"
    assert not descolocadas, (
        f"{len(descolocadas)} líneas archivadas bajo el tex_file equivocado: {descolocadas[:3]}"
    )


def test_prose_before_the_first_heading_of_a_file_opens_its_own_unit():
    # Al cambiar de fichero, la unidad anterior se cierra: el párrafo de
    # apertura del nuevo fichero no puede acabar en la última unidad del
    # fichero anterior.
    lines = _lines(
        "\\chapter{Uno}\n\\section{Padre}\nTexto del uno.\n",
        tex_file="capitulos/cap1/uno.tex",
    ) + _lines(
        "Párrafo de apertura del dos.\n\\section{Hijo}\nTexto del dos.\n",
        tex_file="capitulos/cap2/dos.tex",
    )
    units = split_units(lines)
    padre = next(u for u in units if u.title == "Padre")
    assert not any("del dos" in l.text for l in padre.lines)

    intro = next(u for u in units if u.unit_id == "c02-dos-intro")
    assert intro.tex_file == "capitulos/cap2/dos.tex"
    assert intro.chapter == 2
    assert intro.level == 0
    assert any("apertura del dos" in l.text for l in intro.lines)


def test_a_file_with_an_empty_starred_chapter_and_no_heading_is_not_dropped():
    # pre/resumen.tex: abre con \chapter*{} (título vacío) y no tiene ningún
    # \section. Antes se descartaba entero y en silencio.
    lines = _lines(
        "\\chapter*{}\n\\addcontentsline{toc}{chapter}{Resumen}\nEl resumen de la memoria.\n",
        tex_file="pre/resumen.tex",
    )
    units = split_units(lines)
    assert len(units) == 1
    assert units[0].tex_file == "pre/resumen.tex"
    assert units[0].title == "Resumen"  # sin capítulo con nombre: el del fichero
    assert any("resumen de la memoria" in l.text for l in units[0].lines)


def test_pure_layout_before_a_heading_does_not_open_a_unit():
    lines = _lines(
        "\\chapter{Uno}\n\\newpage\n\\begin{center}\n\\tableofcontents\n\\end{center}\n"
        "\\section{Padre}\nTexto.\n",
        tex_file="capitulos/cap1/uno.tex",
    )
    units = split_units(lines)
    assert [u.title for u in units] == ["Padre"]
