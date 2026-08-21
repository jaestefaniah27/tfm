"""Pruebas de escucha sin cobertura (service worker, cola IndexedDB) y del
webhook de GitHub que dispara la regeneración."""

import hashlib
import hmac
import json


def test_service_worker_is_served_from_the_root(client):
    r = client.get("/sw.js")
    assert r.status_code == 200
    assert "javascript" in r.headers["content-type"]


def test_service_worker_caches_audio_and_index(client):
    body = client.get("/sw.js").text
    assert "caches" in body
    assert "/audio/" in body
    assert "/api/units/" in body


def test_the_queue_survives_without_network(client):
    body = client.get("/app.js").text
    assert "indexedDB" in body or "IndexedDB" in body
    assert "flushQueue" in body


def test_saving_a_note_without_a_session_yet_still_falls_back_to_the_queue(client):
    """No hay entorno de navegador en esta batería (sin jsdom/Playwright) para
    disparar `Notes.save()` de verdad, así que se comprueba de forma
    estructural que ya no puede perderse una nota cuando todavía no hay
    `session_id` en caché: la llamada a `sessionId()` (que hace su propia
    petición de red) debe quedar DENTRO del mismo `try` que envuelve el
    `POST /api/notes` y cae al mismo `catch` que llama a `AudioRev.enqueue`,
    en vez de poder lanzar antes de construir el `payload`."""
    body = client.get("/player.js").text
    save_start = body.index("async function save()")
    save_body = body[save_start:body.index("\n  }\n", save_start)]

    try_start = save_body.index("try {")
    catch_start = save_body.index("} catch")
    session_call = save_body.index("await sessionId()")

    # await sessionId() debe invocarse después de abrir el try y antes del
    # cierre que da paso al catch, nunca fuera de él.
    assert try_start < session_call < catch_start
    assert "AudioRev.enqueue" in save_body[catch_start:]


def test_webhook_rejects_a_bad_signature(client, monkeypatch):
    monkeypatch.setenv("AUDIOREV_WEBHOOK_SECRET", "s3cr3t")
    from server.app.config import get_settings

    get_settings.cache_clear()
    r = client.post("/api/webhook/github", json={"ref": "refs/heads/main"},
                    headers={"X-Hub-Signature-256": "sha256=falso"})
    assert r.status_code == 401


def test_webhook_accepts_a_good_signature(client, monkeypatch):
    monkeypatch.setenv("AUDIOREV_WEBHOOK_SECRET", "s3cr3t")
    from server.app.config import get_settings

    get_settings.cache_clear()
    payload = json.dumps({"ref": "refs/heads/main"}).encode()
    digest = hmac.new(b"s3cr3t", payload, hashlib.sha256).hexdigest()
    r = client.post("/api/webhook/github", content=payload,
                    headers={"X-Hub-Signature-256": f"sha256={digest}",
                             "Content-Type": "application/json"})
    assert r.status_code == 202


def test_webhook_ignores_pushes_to_other_branches(client, monkeypatch):
    monkeypatch.setenv("AUDIOREV_WEBHOOK_SECRET", "s3cr3t")
    from server.app.config import get_settings

    get_settings.cache_clear()
    payload = json.dumps({"ref": "refs/heads/otra"}).encode()
    digest = hmac.new(b"s3cr3t", payload, hashlib.sha256).hexdigest()
    r = client.post("/api/webhook/github", content=payload,
                    headers={"X-Hub-Signature-256": f"sha256={digest}",
                             "Content-Type": "application/json"})
    assert r.status_code == 200
    assert r.json()["ignored"] is True
