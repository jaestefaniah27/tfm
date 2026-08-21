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
    assert set(s) == {"idx", "text", "spoken", "hash", "tex_line", "t_start", "t_end"}
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
