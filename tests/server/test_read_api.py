import json

import pytest


@pytest.fixture
def loaded(client, data_dir):
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    units = []
    for n in (1, 2):
        uid = f"c03-entorno-u{n}"
        (index_dir / f"{uid}.json").write_text(json.dumps({
            "unit_id": uid, "chapter": 3, "chapter_title": "Desarrollo", "level": 2,
            "title": f"Unidad {n}", "tex_file": "a/b.tex", "tex_lines": [1, 9],
            "duration_s": 10.0 * n,
            "sentences": [{"idx": 0, "text": "Frase.", "spoken": "Frase.", "hash": "h",
                           "tex_line": 2, "t_start": 0.0, "t_end": 10.0 * n}],
            "blocks": [],
        }), encoding="utf-8")
        units.append({"unit_id": uid, "title": f"Unidad {n}", "chapter": 3,
                      "chapter_title": "Desarrollo", "level": 2,
                      "duration_s": 10.0 * n, "n_sentences": 1, "n_blocks": 0})
    (index_dir / "manifest.json").write_text(json.dumps({"units": units}), encoding="utf-8")
    (data_dir / "audio").mkdir(parents=True, exist_ok=True)
    (data_dir / "audio" / "c03-entorno-u1.opus").write_bytes(b"OggS-falso")
    client.post("/api/reload", headers={"Authorization": "Bearer token-de-prueba"})
    return client


def test_units_are_grouped_by_chapter_with_totals(loaded):
    body = loaded.get("/api/units").json()
    assert body["total_duration_s"] == 30.0
    assert body["chapters"][0]["chapter"] == 3
    assert len(body["chapters"][0]["units"]) == 2
    assert body["chapters"][0]["units"][0]["state"] == "pendiente"
    assert body["chapters"][0]["units"][0]["n_notes"] == 0


def test_unit_detail_returns_sentences_and_blocks(loaded):
    body = loaded.get("/api/units/c03-entorno-u1").json()
    assert body["sentences"][0]["t_end"] == 10.0
    assert body["blocks"] == []


def test_unknown_unit_is_404(loaded):
    assert loaded.get("/api/units/no-existe").status_code == 404


def test_progress_is_stored_and_returned(loaded):
    r = loaded.put("/api/progress/c03-entorno-u1",
                   json={"state": "en_curso", "position_s": 4.5})
    assert r.status_code == 200
    body = loaded.get("/api/units").json()
    unit = body["chapters"][0]["units"][0]
    assert unit["state"] == "en_curso"
    assert unit["position_s"] == 4.5


def test_progress_is_also_stored_when_it_llega_por_post(loaded):
    """`navigator.sendBeacon` (lo que usa el reproductor al pasar a segundo
    plano) sólo sabe enviar POST: sin esta ruta el guardado del avance
    moría en un 405 silencioso en cualquier navegador moderno."""
    r = loaded.post("/api/progress/c03-entorno-u1",
                    json={"state": "escuchado", "position_s": 9.25})
    assert r.status_code == 200
    unit = loaded.get("/api/units").json()["chapters"][0]["units"][0]
    assert unit["state"] == "escuchado"
    assert unit["position_s"] == 9.25


def test_invalid_progress_state_is_rejected(loaded):
    r = loaded.put("/api/progress/c03-entorno-u1",
                   json={"state": "inventado", "position_s": 0})
    assert r.status_code == 422


def test_audio_is_served_and_supports_range(loaded):
    r = loaded.get("/audio/c03-entorno-u1.opus")
    assert r.status_code == 200
    assert r.headers["content-type"] == "audio/ogg"
    r = loaded.get("/audio/c03-entorno-u1.opus", headers={"Range": "bytes=0-3"})
    assert r.status_code == 206


def test_missing_audio_is_404_not_500(loaded):
    assert loaded.get("/audio/c03-entorno-u2.opus").status_code == 404


def test_audio_path_traversal_is_blocked(loaded):
    assert loaded.get("/audio/..%2F..%2Fetc%2Fpasswd.opus").status_code in (400, 404)
