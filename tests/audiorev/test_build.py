import json

from tools.audiorev.build import build_units, unit_to_dict, render, main
from tools.audiorev.tts import get_backend


def test_builds_units_from_the_real_repo(repo_root):
    units = build_units(repo_root)
    assert len(units) >= 120
    nco = [u for u in units if u.title.startswith("Oscilador controlado")][0]
    assert nco.chapter == 3
    assert nco.tex_file.endswith("cap3/entorno_desarrollo.tex")
    assert len(nco.sentences) > 3
    assert all(s.hash for s in nco.sentences)
    assert all(s.spoken for s in nco.sentences)


def test_unit_dict_has_the_shape_the_spec_promises(repo_root):
    unit = build_units(repo_root)[0]
    d = unit_to_dict(unit)
    assert set(d) >= {
        "unit_id", "chapter", "chapter_title", "level", "title",
        "tex_file", "tex_lines", "duration_s", "sentences", "blocks",
    }
    s = d["sentences"][0]
    assert set(s) == {
            "idx", "text", "spoken", "hash", "tex_raw", "tex_line", "t_start", "t_end",
        }
    assert "/" in d["tex_file"] and not d["tex_file"].startswith("/")


def test_render_without_audio_writes_one_json_per_unit(repo_root, tmp_path):
    units = build_units(repo_root)[:3]
    render(units, tmp_path, get_backend("fake"), tmp_path / "cache", with_audio=False)
    files = sorted(p.name for p in tmp_path.glob("*.json"))
    assert len(files) == 3
    data = json.loads((tmp_path / files[0]).read_text(encoding="utf-8"))
    assert data["duration_s"] == 0.0


def test_render_with_audio_fills_timings_and_writes_the_index(repo_root, tmp_path, monkeypatch):
    monkeypatch.setattr("tools.audiorev.build.concat", lambda paths, out: out.write_bytes(b"x"))
    units = build_units(repo_root)[:1]
    render(units, tmp_path, get_backend("fake"), tmp_path / "cache", with_audio=True)
    data = json.loads(next(tmp_path.glob("*.json")).read_text(encoding="utf-8"))
    assert data["duration_s"] > 0
    assert data["sentences"][0]["t_start"] == 0.0
    assert data["sentences"][-1]["t_end"] == data["duration_s"]
    assert (tmp_path / f"{data['unit_id']}.opus").exists()


def test_only_filters_by_path_fragment(repo_root, tmp_path):
    assert main(["--repo", str(repo_root), "--out", str(tmp_path),
                 "--only", "cap5", "--no-audio", "--backend", "fake"]) == 0
    # manifest.json convive en el mismo out_dir con los índices por unidad
    # (el otro test de main() exige que exista ahí), así que se excluye
    # aquí: esta comprobación es sobre los nombres de los índices por unidad.
    names = [p.name for p in tmp_path.glob("*.json") if p.name != "manifest.json"]
    assert names
    assert all(n.startswith("c05-") for n in names)


def test_writes_a_manifest_listing_every_unit(repo_root, tmp_path):
    main(["--repo", str(repo_root), "--out", str(tmp_path),
          "--only", "cap5", "--no-audio", "--backend", "fake"])
    manifest = json.loads((tmp_path / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["units"]
    assert set(manifest["units"][0]) >= {"unit_id", "title", "chapter", "duration_s"}


def test_percent_sign_does_not_truncate_the_rest_of_the_sentence(repo_root):
    # entorno_desarrollo.tex: "... con duty cycle del 50\% a partir del
    # reloj de 100~MHz de la FPGA: canal 0 a 10~kHz, ...". El "\%" no debe
    # cortar la frase antes de "a partir del reloj".
    units = build_units(repo_root)
    hit = [s for u in units for s in u.sentences if "duty cycle del 50%" in s.spoken]
    assert hit
    assert any("a partir del reloj" in s.spoken for s in hit)


def test_ref_resolves_to_a_number_not_the_word_referencia(repo_root):
    # entorno_desarrollo.tex: "El diseño resultante es el de la
    # figura~\ref{fig:block_design_and}.", y main.aux resuelve esa etiqueta
    # a "3.1". El resultado hablado debe llevar ese número, no la palabra
    # "referencia" con la que plain() (para pantalla) sustituye el \ref.
    units = build_units(repo_root)
    hit = [s for u in units for s in u.sentences if "El diseño resultante" in s.spoken]
    assert hit
    assert all("3.1" in s.spoken for s in hit)
    assert all("referencia" not in s.spoken for s in hit)


def test_sentences_carry_their_own_tex_line_not_the_first_of_the_unit(repo_root):
    # El apartado 4.2 del diseño enseña un tex_lines de [326, 402] con una
    # frase en la línea 328: tex_line es la línea de CADA frase.
    units = [u for u in build_units(repo_root) if len(u.sentences) > 5]
    multilinea = [u for u in units if u.tex_lines[1] - u.tex_lines[0] > 10]
    assert multilinea
    for unit in multilinea:
        lineas = {s.tex_line for s in unit.sentences}
        assert len(lineas) > 1, unit.unit_id
        assert min(lineas) >= unit.tex_lines[0]
        assert max(lineas) <= unit.tex_lines[1]
        # Monótono: las frases van en el orden en que aparecen en el fichero.
        seguidas = [s.tex_line for s in unit.sentences]
        assert seguidas == sorted(seguidas), unit.unit_id


def test_tex_raw_lets_a_sentence_be_found_back_in_its_own_tex_file(repo_root):
    # Ancla primaria del apartado 3.3: la frase se busca por su texto, así que
    # tiene que aparecer literalmente en el fichero del que salió. `text` no
    # sirve: lleva los comandos quitados y los \ref resueltos.
    import re

    fuentes: dict[str, str] = {}

    def normaliza(text: str) -> str:
        return re.sub(r"\s+", " ", text)

    total = encontradas = 0
    for unit in build_units(repo_root):
        if unit.tex_file not in fuentes:
            fuentes[unit.tex_file] = normaliza(
                (repo_root / unit.tex_file).read_text(encoding="utf-8")
            )
        for sentence in unit.sentences:
            if not sentence.tex_raw:
                continue  # aviso hablado de un bloque: no viene del .tex
            total += 1
            if sentence.tex_raw in fuentes[unit.tex_file]:
                encontradas += 1

    assert total > 1000
    assert encontradas / total > 0.90, f"solo {encontradas}/{total} localizables"


def test_blocks_of_a_unit_get_a_real_after_sentence(repo_root):
    units = build_units(repo_root)
    bloques = [(u, b) for u in units for b in u.blocks]
    assert len(bloques) > 50
    for unit, block in bloques:
        assert 0 <= block.after_sentence < len(unit.sentences), unit.unit_id
        # after_sentence apunta al aviso hablado del propio bloque.
        aviso = unit.sentences[block.after_sentence]
        assert aviso.text.endswith("en pantalla.")
    # Y no todos caen en el mismo sitio.
    assert len({b.after_sentence for _, b in bloques}) > 5
