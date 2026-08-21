"""Pruebas de la carga del índice del pipeline en la base de datos."""

import json

from server.app import db, index


def _write_index(index_dir):
    index_dir.mkdir(parents=True, exist_ok=True)
    unit = {
        "unit_id": "c03-entorno-nco", "chapter": 3, "chapter_title": "Desarrollo",
        "level": 2, "title": "Oscilador controlado numéricamente (NCO)",
        "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        "tex_lines": [326, 402], "duration_s": 168.4,
        "sentences": [{"idx": 0, "text": "Una frase.", "spoken": "Una frase.",
                       "hash": "abc123", "tex_line": 328, "t_start": 0.0, "t_end": 3.9}],
        "blocks": [],
    }
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps(unit), encoding="utf-8")
    (index_dir / "manifest.json").write_text(json.dumps({"units": [
        {"unit_id": "c03-entorno-nco", "title": unit["title"], "chapter": 3,
         "chapter_title": "Desarrollo", "level": 2, "duration_s": 168.4,
         "n_sentences": 1, "n_blocks": 0}
    ]}), encoding="utf-8")


def test_loads_the_manifest_into_units(data_dir):
    _write_index(data_dir / "index")
    conn = db.connect()
    db.migrate(conn)
    assert index.load_index(conn, data_dir / "index") == 1
    row = conn.execute("SELECT * FROM units").fetchone()
    assert row["unit_id"] == "c03-entorno-nco"
    assert row["chapter"] == 3
    assert row["ord"] == 0


def test_reloading_updates_instead_of_duplicating(data_dir):
    _write_index(data_dir / "index")
    conn = db.connect()
    db.migrate(conn)
    index.load_index(conn, data_dir / "index")
    index.load_index(conn, data_dir / "index")
    assert conn.execute("SELECT count(*) FROM units").fetchone()[0] == 1


def test_reloading_preserves_progress_and_notes(data_dir):
    _write_index(data_dir / "index")
    conn = db.connect()
    db.migrate(conn)
    index.load_index(conn, data_dir / "index")
    conn.execute(
        "INSERT INTO progress (unit_id, state, position_s) VALUES ('c03-entorno-nco','escuchado',12.5)"
    )
    index.load_index(conn, data_dir / "index")
    row = conn.execute("SELECT * FROM progress").fetchone()
    assert row["state"] == "escuchado"
    assert row["position_s"] == 12.5


def test_unit_payload_returns_the_full_json(data_dir):
    _write_index(data_dir / "index")
    payload = index.unit_payload(data_dir / "index", "c03-entorno-nco")
    assert payload["sentences"][0]["t_end"] == 3.9


def test_unit_payload_of_unknown_id_returns_none(data_dir):
    _write_index(data_dir / "index")
    assert index.unit_payload(data_dir / "index", "no-existe") is None


def test_unit_payload_rejects_path_traversal(data_dir):
    _write_index(data_dir / "index")
    assert index.unit_payload(data_dir / "index", "../../etc/passwd") is None
