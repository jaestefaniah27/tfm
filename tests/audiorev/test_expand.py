from tools.audiorev.expand import expand


def _write(tmp_path, rel, body):
    p = tmp_path / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body, encoding="utf-8")
    return p


def test_inlines_import_and_input_in_document_order(tmp_path):
    _write(tmp_path, "pre/resumen.tex", "Resumen del trabajo.\n")
    _write(tmp_path, "capitulos/cap1/intro.tex", "\\section{Objetivos}\nTexto.\n")
    main = _write(
        tmp_path,
        "main.tex",
        "\\begin{document}\n"
        "\\input{pre/resumen}\n"
        "\\chapter{Introducción}\n"
        "\\import{capitulos/cap1/}{intro.tex}\n"
        "\\end{document}\n",
    )
    lines = expand(main, tmp_path)
    texts = [l.text for l in lines]
    assert "Resumen del trabajo." in texts
    assert "\\chapter{Introducción}" in texts
    assert texts.index("Resumen del trabajo.") < texts.index("\\chapter{Introducción}")
    assert "\\section{Objetivos}" in texts


def test_keeps_the_true_origin_of_every_line(tmp_path):
    _write(tmp_path, "capitulos/cap1/intro.tex", "Primera.\nSegunda.\n")
    main = _write(tmp_path, "main.tex", "\\import{capitulos/cap1/}{intro.tex}\n")
    lines = expand(main, tmp_path)
    segunda = [l for l in lines if l.text == "Segunda."][0]
    assert segunda.tex_file == "capitulos/cap1/intro.tex"
    assert segunda.lineno == 2


def test_paths_are_relative_with_forward_slashes(tmp_path):
    _write(tmp_path, "capitulos/cap1/intro.tex", "Texto.\n")
    main = _write(tmp_path, "main.tex", "\\import{capitulos/cap1/}{intro.tex}\n")
    for line in expand(main, tmp_path):
        assert not line.tex_file.startswith("/")
        assert "\\" not in line.tex_file


def test_expands_the_real_tfm(tex_root, repo_root):
    lines = expand(tex_root / "main.tex", repo_root)
    files = {l.tex_file for l in lines}
    assert any("cap3/entorno_desarrollo.tex" in f for f in files)
    assert any("cap5/lineasfuturas.tex" in f for f in files)
    chapters = [l.text for l in lines if l.text.startswith("\\chapter{")]
    assert len(chapters) >= 8


def test_a_missing_include_warns_instead_of_disappearing(tmp_path, capsys):
    (tmp_path / "main.tex").write_text(
        "Antes.\n\\input{capitulos/perdido}\nDespués.\n", encoding="utf-8"
    )
    lines = expand(tmp_path / "main.tex", tmp_path)
    assert [l.text for l in lines] == ["Antes.", "Después."]
    err = capsys.readouterr().err
    assert "perdido" in err and "main.tex" in err
