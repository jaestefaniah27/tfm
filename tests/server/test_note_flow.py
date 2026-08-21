"""Pruebas de la hoja de notas con etiquetas y dictado (tarea 8)."""


def test_the_note_sheet_exists_in_the_page(client):
    body = client.get("/player.html").text
    assert 'id="hoja-notas"' in body
    assert "<textarea" in body


def test_the_quick_tags_are_the_five_agreed_ones(client):
    body = client.get("/player.html").text
    for tag in ("muy_largo", "no_se_entiende", "repetido", "falta_dato", "reescribir"):
        assert tag in body


def test_saving_a_note_posts_the_anchor(client):
    body = client.get("/player.js").text
    assert "/api/notes" in body
    for field in ("sentence_idx", "sentence_hash", "sentence_text", "tex_file", "tex_line", "audio_ts"):
        assert field in body


def test_the_session_id_is_reused_from_session_storage(client):
    assert "sessionStorage" in client.get("/player.js").text


def test_a_note_posted_by_the_page_shape_is_accepted_by_the_api(client):
    session_id = client.post("/api/sessions").json()["session_id"]
    r = client.post("/api/notes", json={
        "session_id": session_id,
        "unit_id": "c03-entorno-nco",
        "sentence_idx": 4,
        "sentence_hash": "abc123",
        "sentence_text": "El NCO genera la referencia.",
        "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        "tex_line": 328,
        "audio_ts": 41.2,
        "tags": ["muy_largo"],
        "comment": "",
    })
    assert r.status_code == 201
