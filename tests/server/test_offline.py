"""Pruebas de escucha sin cobertura (service worker, cola IndexedDB) y del
webhook de GitHub que dispara la regeneración."""

import hashlib
import hmac
import json
import shutil
import subprocess
from pathlib import Path

import pytest


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


ARNES = Path(__file__).parent / "js" / "flush_queue_harness.mjs"
APP_JS = Path(__file__).parents[2] / "server" / "static" / "app.js"


def _flush(escenario: str) -> dict:
    """Ejecuta flushQueue() de verdad sobre un IndexedDB y un fetch de
    mentira dentro de Node, y devuelve lo que envió y lo que dejó en cola.

    Es comportamiento real, no comprobación de subcadenas: la cola vive en
    memoria y `fetch` se programa para fallar donde interesa."""
    node = shutil.which("node")
    if not node:
        pytest.skip("Node no está disponible para ejecutar el arnés de app.js")
    out = subprocess.run([node, str(ARNES), str(APP_JS), escenario],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def test_a_network_failure_mid_flush_keeps_the_rest_queued_without_duplicates():
    r = _flush("red-cae-en-la-segunda")
    # La primera nota se acepta; la segunda revienta el fetch (sin red) y el
    # vaciado para ahí, dejando segunda y tercera en la cola.
    assert r["primero"]["enviadas"] == ["uno", "dos"]
    assert [c["note"]["comment"] for c in r["primero"]["cola"]] == ["dos", "tres"]
    # En el siguiente intento NO se reenvía "uno": ya se borró al aceptarse,
    # así que no se duplica la revisión en el servidor.
    assert "uno" not in r["segundo"]["enviadas"]


def test_a_note_rejected_by_the_server_leaves_the_queue_and_does_not_block_the_rest():
    r = _flush("servidor-rechaza-la-segunda")
    # "dos" recibe un 422: la petición llegó al servidor, así que no se
    # reintenta eternamente. Se descarta de la cola y "tres" sí se envía.
    assert r["primero"]["enviadas"] == ["uno", "dos", "tres"]
    assert r["primero"]["cola"] == []
    assert r["segundo"]["enviadas"] == []


def test_the_queue_is_also_flushed_on_startup(client):
    """El evento 'online' no vuelve a dispararse si la pestaña muere sin
    cobertura y se reabre ya con red: hace falta vaciar al arrancar."""
    body = client.get("/app.js").text
    listener = body.index("addEventListener('online', flushQueue)")
    assert "flushQueue()" in body[listener:]


def test_the_service_worker_revalidates_the_unit_json(client):
    """Cache-first eterno sobre /api/units/ dejaba al móvil anclando notas a
    hashes de frase que el servidor ya había olvidado tras regenerar."""
    body = client.get("/sw.js").text
    assert "/api/units/" in body
    assert "stale-while-revalidate" in body


def test_the_player_can_close_and_publish_the_session(client):
    pagina = client.get("/player.html").text
    assert 'id="cerrar-sesion"' in pagina
    assert 'id="estado-sesion"' in pagina
    js = client.get("/player.js").text
    assert "/publicar" in js
    assert "503" in js  # mensaje propio para el fallo de git


def test_the_session_id_survives_a_discarded_tab(client):
    js = client.get("/player.js").text
    assert "localStorage" in js
    # El identificador ya no se guarda en sessionStorage (sólo se menciona
    # en el comentario que explica por qué).
    assert "sessionStorage.getItem" not in js and "sessionStorage.setItem" not in js
