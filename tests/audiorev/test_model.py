from tools.audiorev.model import SourceLine, Block, Sentence, Unit


def test_sentence_defaults_timing_to_zero():
    s = Sentence(idx=0, text="Hola.", spoken="Hola.", hash="ab12", tex_line=7)
    assert s.t_start == 0.0
    assert s.t_end == 0.0


def test_unit_starts_empty_and_reports_zero_duration():
    u = Unit(
        unit_id="c03-entorno-nco",
        chapter=3,
        chapter_title="Desarrollo",
        level=2,
        title="Oscilador controlado numéricamente (NCO)",
        tex_file="plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        tex_lines=(326, 402),
    )
    assert u.sentences == []
    assert u.blocks == []
    assert u.duration_s == 0.0


def test_sourceline_and_block_carry_their_origin():
    line = SourceLine(tex_file="a/b.tex", lineno=3, text="Texto.")
    assert (line.tex_file, line.lineno) == ("a/b.tex", 3)
    b = Block(after_sentence=2, type="table", caption="Puertos", ref="tab:tx", raw="", html="")
    assert b.type == "table"
