from tools.audiorev.dic import spell_es, seed_from_acronyms, load, save


def test_spells_letters_with_spanish_names():
    assert spell_es("AOCS") == "a o ce ese"
    assert spell_es("DMA") == "de eme a"
    assert spell_es("CDHS") == "ce de hache ese"


def test_spells_digits_as_words():
    assert spell_es("RS485") == "erre ese cuatro ocho cinco"


def test_seeds_every_acronym_of_the_tfm(tex_root):
    entries = seed_from_acronyms(tex_root / "pre" / "acronimos.tex")
    assert len(entries) == 73
    assert entries["AOCS"] == "a o ce ese"
    assert "AXI" in entries


def test_roundtrip_preserves_manual_overrides(tmp_path):
    path = tmp_path / "pronunciacion.yml"
    save(path, {"CAN": "can", "DMA": "de eme a"})
    assert load(path) == {"CAN": "can", "DMA": "de eme a"}


def test_load_of_missing_file_returns_empty(tmp_path):
    assert load(tmp_path / "no-existe.yml") == {}
