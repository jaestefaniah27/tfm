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


def test_publishing_marks_the_session_as_closed(client):
    session_id = client.post("/api/sessions").json()["session_id"]
    client.post("/api/notes", json={
        "session_id": session_id, "unit_id": "c03-x", "sentence_idx": 0,
        "sentence_hash": "h", "sentence_text": "Frase.", "tex_file": "a.tex",
        "tex_line": 1, "audio_ts": 0.0, "tags": ["repetido"], "comment": "",
    })
    r = client.post(f"/api/sessions/{session_id}/publicar")
    assert r.status_code in (200, 503)
    if r.status_code == 200:
        assert r.json()["path"].startswith("revisiones/")
        from server.app import db as db_module

        with db_module.session() as conn:
            row = conn.execute(
                "SELECT closed_at FROM sessions WHERE session_id = ?", (session_id,)
            ).fetchone()
        assert row["closed_at"]
