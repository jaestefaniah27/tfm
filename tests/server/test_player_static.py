"""Pruebas del reproductor con resaltado por frase (tarea 7)."""


def test_player_page_is_served(client):
    r = client.get("/player.html")
    assert r.status_code == 200
    assert "<audio" in r.text


def test_player_js_declares_the_public_functions(client):
    body = client.get("/player.js").text
    for name in ("load", "currentSentence", "seekToSentence"):
        assert name in body


def test_player_uses_media_session_for_lock_screen_controls(client):
    assert "mediaSession" in client.get("/player.js").text


def test_player_saves_progress_before_leaving(client):
    body = client.get("/player.js").text
    assert "visibilitychange" in body or "pagehide" in body
