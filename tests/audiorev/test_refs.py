from tools.audiorev.refs import load_labels, spoken_ref


def test_parses_the_three_label_kinds(tmp_path):
    aux = tmp_path / "main.aux"
    aux.write_text(
        r"\newlabel{fig:block_design_and}{{3.1}{14}{\textit {Block Design}}{figure.caption.84}{}}"
        "\n"
        r"\newlabel{objetivos}{{1.2}{2}{Objetivos}{section.1.2}{}}"
        "\n"
        r"\newlabel{tab:sw6}{{3.1}{16}{Posiciones del selector}{table.caption.86}{}}"
        "\n",
        encoding="utf-8",
    )
    labels = load_labels(aux)
    assert labels["fig:block_design_and"] == ("3.1", "figure")
    assert labels["objetivos"] == ("1.2", "section")
    assert labels["tab:sw6"] == ("3.1", "table")


def test_spoken_ref_uses_spanish_names():
    labels = {
        "fig:x": ("3.1", "figure"),
        "tab:y": ("4.2", "table"),
        "sec:z": ("2.6.3", "subsection"),
        "eq:w": ("5", "equation"),
    }
    assert spoken_ref("fig:x", labels) == "la figura 3.1"
    assert spoken_ref("tab:y", labels) == "la tabla 4.2"
    assert spoken_ref("sec:z", labels) == "el apartado 2.6.3"
    assert spoken_ref("eq:w", labels) == "la ecuación 5"


def test_unknown_label_degrades_without_raising():
    assert spoken_ref("no:existe", {}) == "la referencia correspondiente"


def test_reads_the_real_aux_of_the_tfm(tex_root):
    labels = load_labels(tex_root / "main.aux")
    # 79 y no las 81 entradas \newlabel del .aux: RF1 y RF2 usan una forma
    # de un solo grupo, sin número y sin ancla de tipo, que no encaja con el
    # patrón \newlabel{n}{{num}{pág}...} y no se puede resolver a nada.
    assert len(labels) == 79
    assert all(isinstance(v, tuple) and len(v) == 2 for v in labels.values())
