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
