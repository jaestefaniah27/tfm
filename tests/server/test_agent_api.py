"""Pruebas de la API que usa Claude Code para leer y aplicar revisiones."""

import json

AUTH = {"Authorization": "Bearer token-de-prueba"}

NOTE = {
    "session_id": "s1", "unit_id": "c03-entorno-nco", "sentence_idx": 0,
    "sentence_hash": "hash-viejo", "sentence_text": "Frase antigua.",
    "tex_file": "a/b.tex", "tex_line": 1, "audio_ts": 0.0,
    "tags": [], "comment": "Cambiar esto.",
}


def test_agent_lists_pending_revisions_with_the_token(client):
    client.post("/api/notes", json=NOTE)
    r = client.get("/api/revisiones?estado=pendiente", headers=AUTH)
    assert r.status_code == 200
    note = r.json()["revisiones"][0]
    assert note["sentence_text"] == "Frase antigua."
    assert note["tex_file"] == "a/b.tex"


def test_agent_api_rejects_the_session_cookie_alone(client):
    client.post("/api/notes", json=NOTE)
    assert client.get("/api/revisiones", headers={"Authorization": "Bearer malo"}).status_code == 401


def test_agent_marks_a_revision_as_applied(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    r = client.post(f"/api/revisiones/{note_id}/estado", json={"estado": "aplicada"}, headers=AUTH)
    assert r.status_code == 200
    assert client.get("/api/revisiones?estado=pendiente", headers=AUTH).json()["revisiones"] == []


def test_agent_cannot_set_an_invalid_state(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    r = client.post(f"/api/revisiones/{note_id}/estado", json={"estado": "inventado"}, headers=AUTH)
    assert r.status_code == 422


def test_notes_whose_sentence_disappeared_become_obsolete(client, data_dir):
    from server.app import db as db_module
    from server.app.index import mark_stale_notes

    client.post("/api/notes", json=NOTE)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco",
        "sentences": [{"idx": 0, "text": "Frase nueva.", "spoken": "Frase nueva.",
                       "hash": "hash-nuevo", "tex_line": 1, "t_start": 0, "t_end": 1}],
        "blocks": [],
    }), encoding="utf-8")

    with db_module.session() as conn:
        assert mark_stale_notes(conn, index_dir) == 1
    assert client.get("/api/revisiones?estado=obsoleta", headers=AUTH).json()["revisiones"]


def test_a_note_whose_sentence_survives_stays_pending(client, data_dir):
    from server.app import db as db_module
    from server.app.index import mark_stale_notes

    client.post("/api/notes", json=NOTE)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco",
        "sentences": [{"idx": 0, "text": "Frase antigua.", "spoken": "Frase antigua.",
                       "hash": "hash-viejo", "tex_line": 1, "t_start": 0, "t_end": 1}],
        "blocks": [],
    }), encoding="utf-8")

    with db_module.session() as conn:
        assert mark_stale_notes(conn, index_dir) == 0


def test_a_regenerated_unit_left_with_zero_sentences_marks_its_notes_stale(client, data_dir):
    from server.app import db as db_module
    from server.app.index import mark_stale_notes

    client.post("/api/notes", json=NOTE)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco", "sentences": [], "blocks": [],
    }), encoding="utf-8")

    with db_module.session() as conn:
        assert mark_stale_notes(conn, index_dir) == 1
    assert client.get("/api/revisiones?estado=obsoleta", headers=AUTH).json()["revisiones"]


def test_already_applied_notes_are_never_marked_obsolete(client, data_dir):
    from server.app import db as db_module
    from server.app.index import mark_stale_notes

    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.post(f"/api/revisiones/{note_id}/estado", json={"estado": "aplicada"}, headers=AUTH)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco", "sentences": [], "blocks": [],
    }), encoding="utf-8")

    with db_module.session() as conn:
        assert mark_stale_notes(conn, index_dir) == 0
