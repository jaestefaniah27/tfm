import pytest

NOTE = {
    "session_id": "s1",
    "unit_id": "c03-entorno-nco",
    "sentence_idx": 4,
    "sentence_hash": "abc123",
    "sentence_text": "El NCO genera la referencia de reloj del transceptor.",
    "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
    "tex_line": 328,
    "audio_ts": 41.2,
    "tags": ["muy_largo", "reescribir"],
    "comment": "Partir en dos frases, la segunda mitad sobra.",
}


def test_creating_a_note_returns_its_id_and_stores_the_anchor(client):
    r = client.post("/api/notes", json=NOTE)
    assert r.status_code == 201
    note_id = r.json()["id"]
    stored = client.get("/api/notes").json()["notes"][0]
    assert stored["id"] == note_id
    assert stored["sentence_text"] == NOTE["sentence_text"]
    assert stored["tags"] == ["muy_largo", "reescribir"]
    assert stored["state"] == "pendiente"
    assert stored["created_at"]


def test_a_note_needs_either_a_comment_or_a_tag(client):
    bad = {**NOTE, "comment": "", "tags": []}
    assert client.post("/api/notes", json=bad).status_code == 422


def test_notes_can_be_filtered_by_state(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.patch(f"/api/notes/{note_id}", json={"state": "aplicada"})
    assert client.get("/api/notes?estado=pendiente").json()["notes"] == []
    assert len(client.get("/api/notes?estado=aplicada").json()["notes"]) == 1


def test_marking_applied_records_the_timestamp(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.patch(f"/api/notes/{note_id}", json={"state": "aplicada"})
    stored = client.get("/api/notes?estado=aplicada").json()["notes"][0]
    assert stored["applied_at"]


def test_invalid_state_is_rejected(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    assert client.patch(f"/api/notes/{note_id}", json={"state": "inventado"}).status_code == 422


def test_patching_an_unknown_note_is_404(client):
    assert client.patch("/api/notes/9999", json={"state": "aplicada"}).status_code == 404


def test_a_note_can_be_edited_and_deleted(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.patch(f"/api/notes/{note_id}", json={"comment": "Texto corregido."})
    assert client.get("/api/notes").json()["notes"][0]["comment"] == "Texto corregido."
    assert client.delete(f"/api/notes/{note_id}").status_code == 204
    assert client.get("/api/notes").json()["notes"] == []


def test_opening_a_session_returns_a_new_identifier(client):
    a = client.post("/api/sessions").json()["session_id"]
    b = client.post("/api/sessions").json()["session_id"]
    assert a != b


def test_creating_a_note_marks_its_unit_as_having_notes(client, data_dir):
    from server.app import db as db_module

    client.post("/api/notes", json=NOTE)
    with db_module.session() as conn:
        row = conn.execute(
            "SELECT state FROM progress WHERE unit_id = ?", (NOTE["unit_id"],)
        ).fetchone()
    assert row["state"] == "con_notas"
