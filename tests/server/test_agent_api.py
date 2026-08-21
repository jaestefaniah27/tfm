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


def test_regenerating_queues_the_same_work_as_the_webhook(client):
    """`/api/regenerar` sólo recargaba el índice de disco: no regeneraba
    nada, aunque APLICAR_REVISIONES.md la llama justo tras empujar el .tex
    corregido esperando audio nuevo. Ahora encola la misma tarea de fondo
    que el webhook y responde 202."""
    r = client.post("/api/regenerar", headers=AUTH)
    assert r.status_code == 202
    assert r.json() == {"queued": True}


def test_regenerating_without_the_token_is_rejected(client):
    assert client.post("/api/regenerar").status_code == 401


def test_a_failing_regeneration_step_is_logged(capfd, data_dir):
    """El `check=False` mudo de antes hacía que cada regeneración fallara en
    silencio: sin dependencias del pipeline o sin Piper no quedaba ni una
    línea en `docker logs`."""
    from server.app.main import _run_step

    codigo = _run_step(["python3", "-c", "import sys; sys.stderr.write('boom'); sys.exit(3)"])
    assert codigo == 3
    assert "boom" in capfd.readouterr().out


def test_two_regenerations_do_not_run_at_the_same_time(client, capfd, monkeypatch):
    """Dos entregas seguidas del webhook compartirían clon, índice y caché
    de TTS. Con una regeneración en curso, la siguiente se descarta y lo
    deja dicho en el log, sin lanzar ningún proceso."""
    from server.app import main as main_module

    def prohibido(*a, **k):
        raise AssertionError("no debería lanzarse ningún proceso")

    monkeypatch.setattr(main_module.subprocess, "run", prohibido)
    assert main_module._regen_lock.acquire(blocking=False)
    try:
        r = client.post("/api/regenerar", headers=AUTH)
        assert r.status_code == 202
    finally:
        main_module._regen_lock.release()
    assert "ya en curso" in capfd.readouterr().out
