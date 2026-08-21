"""Pruebas de la pantalla de lista de apartados (tarea 6)."""


def test_index_is_served_at_the_root(client):
    r = client.get("/")
    assert r.status_code == 200
    assert "text/html" in r.headers["content-type"]
    assert "AudioRev" in r.text


def test_the_manifest_makes_it_installable(client):
    body = client.get("/manifest.webmanifest").json()
    assert body["display"] == "standalone"
    assert body["start_url"] == "/"
    assert body["icons"]


def test_the_page_declares_the_mobile_viewport(client):
    assert "width=device-width" in client.get("/").text


def test_app_js_is_served(client):
    r = client.get("/app.js")
    assert r.status_code == 200
    assert "fmtDuration" in r.text


def test_login_page_is_served(client):
    r = client.get("/login.html")
    assert r.status_code == 200
    assert "text/html" in r.headers["content-type"]
    assert "password" in r.text


def test_an_earlier_route_is_not_shadowed_by_the_static_mount(client):
    r = client.get("/api/units")
    assert r.status_code == 200
    assert "chapters" in r.json()
