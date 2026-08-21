"""Pruebas de publicación de revisiones en el repositorio."""

import subprocess

import pytest

from server.app import publish

NOTES = [
    {
        "id": 12, "unit_id": "c03-entorno-nco", "sentence_idx": 4,
        "sentence_hash": "abc123",
        "sentence_text": "El NCO genera la referencia de reloj del transceptor.",
        "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        "tex_line": 328, "audio_ts": 41.2, "tags": ["muy_largo", "reescribir"],
        "comment": "Partir en dos frases; la segunda mitad sobra.",
        "state": "pendiente", "created_at": "2026-08-21T18:40:00+00:00",
    }
]


def test_markdown_carries_every_anchor_field():
    body = publish.render_markdown(NOTES, "a1b2c3d4e5f6", "2026-08-21T18:42:00+00:00")
    assert "c03-entorno-nco" in body
    assert "entorno_desarrollo.tex" in body
    assert "328" in body
    assert "El NCO genera la referencia" in body
    assert "Partir en dos frases" in body
    assert "muy largo" in body
    assert "Revisión 12" in body


def test_markdown_groups_by_unit():
    two = NOTES + [{**NOTES[0], "id": 13, "unit_id": "c04-pcb-alimentacion"}]
    body = publish.render_markdown(two, "s", "2026-08-21T18:42:00+00:00")
    # Contamos solo cabeceras de apartado ("## "), no "### " de cada
    # revisión: como substring, "## " también aparece dentro de "### ".
    assert sum(1 for line in body.splitlines() if line.startswith("## ")) == 2


def test_empty_session_still_produces_a_readable_file():
    body = publish.render_markdown([], "s", "2026-08-21T18:42:00+00:00")
    assert "0 revisiones" in body


def test_refuses_to_write_outside_revisiones(tmp_path):
    with pytest.raises(ValueError, match="revisiones/"):
        publish.write_and_push(tmp_path, "plantilla_tft_etsit/main.tex", "x", "m")
    with pytest.raises(ValueError, match="revisiones/"):
        publish.write_and_push(tmp_path, "revisiones/../main.tex", "x", "m")


def test_writes_and_commits_in_a_real_repo(tmp_path, monkeypatch):
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    monkeypatch.setattr(publish, "_push", lambda repo_dir: None)

    publish.write_and_push(repo, "revisiones/2026-08-21-sesion-01.md", "# Hola\n", "Añadir revisiones")

    assert (repo / "revisiones" / "2026-08-21-sesion-01.md").read_text(encoding="utf-8") == "# Hola\n"
    log = subprocess.run(["git", "log", "--oneline"], cwd=repo, capture_output=True, text=True)
    assert "Añadir revisiones" in log.stdout


@pytest.fixture
def repo_de_verdad(data_dir, monkeypatch):
    """Clon git real en `AUDIOREV_REPO_DIR` con el push anulado.

    Antes esta prueba se conformaba con `status_code in (200, 503)` y el
    camino bueno no se ejecutaba nunca (el repo_dir del fixture no era un
    repositorio git, así que siempre daba 503). Con un repositorio de
    verdad se comprueba la respuesta y el cierre de la sesión."""
    repo = data_dir / "repo"
    repo.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    monkeypatch.setattr(publish, "_push", lambda repo_dir: None)
    return repo


def test_publishing_writes_the_file_and_closes_the_session(client, repo_de_verdad):
    session_id = client.post("/api/sessions").json()["session_id"]
    client.post("/api/notes", json={
        "session_id": session_id, "unit_id": "c03-x", "sentence_idx": 0,
        "sentence_hash": "h", "sentence_text": "Frase.", "tex_file": "a.tex",
        "tex_line": 1, "audio_ts": 0.0, "tags": ["repetido"], "comment": "",
    })

    r = client.post(f"/api/sessions/{session_id}/publicar")
    assert r.status_code == 200
    body = r.json()
    assert body["path"].startswith("revisiones/") and body["path"].endswith(".md")
    assert body["notes"] == 1

    escrito = (repo_de_verdad / body["path"]).read_text(encoding="utf-8")
    assert "Frase." in escrito

    from server.app import db as db_module

    with db_module.session() as conn:
        row = conn.execute(
            "SELECT closed_at, published_path FROM sessions WHERE session_id = ?",
            (session_id,),
        ).fetchone()
    assert row["closed_at"]
    assert row["published_path"] == body["path"]


def test_publishing_a_client_generated_session_creates_its_row(client, repo_de_verdad):
    """Cuando se anota sin cobertura el identificador lo genera el cliente y
    nunca hubo fila en `sessions`: el UPSERT del cierre debe crearla, o la
    sesión se quedaría sin cerrar para siempre."""
    session_id = "sesion-generada-en-el-movil"
    client.post("/api/notes", json={
        "session_id": session_id, "unit_id": "c03-x", "sentence_idx": 0,
        "sentence_hash": "h", "sentence_text": "Otra frase.", "tex_file": "a.tex",
        "tex_line": 1, "audio_ts": 0.0, "tags": [], "comment": "Reescribir.",
    })

    r = client.post(f"/api/sessions/{session_id}/publicar")
    assert r.status_code == 200

    from server.app import db as db_module

    with db_module.session() as conn:
        row = conn.execute(
            "SELECT closed_at, published_path FROM sessions WHERE session_id = ?",
            (session_id,),
        ).fetchone()
    assert row is not None
    assert row["closed_at"] and row["published_path"] == r.json()["path"]


def test_publishing_without_a_git_repo_answers_503(client):
    """Sin clon git en AUDIOREV_REPO_DIR, `write_and_push` falla y la ruta
    debe devolver 503 con un mensaje, no un 500."""
    session_id = client.post("/api/sessions").json()["session_id"]
    client.post("/api/notes", json={
        "session_id": session_id, "unit_id": "c03-x", "sentence_idx": 0,
        "sentence_hash": "h", "sentence_text": "Frase.", "tex_file": "a.tex",
        "tex_line": 1, "audio_ts": 0.0, "tags": ["repetido"], "comment": "",
    })
    r = client.post(f"/api/sessions/{session_id}/publicar")
    assert r.status_code == 503
    assert "No se pudo publicar" in r.json()["detail"]
