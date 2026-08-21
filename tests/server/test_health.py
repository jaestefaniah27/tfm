"""Pruebas del esqueleto del servidor: health check y configuración."""


def test_healthz_is_public_and_reports_the_version(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_unknown_api_route_is_404_not_500(client):
    assert client.get("/api/no-existe").status_code in (401, 404)


def test_settings_read_the_environment(monkeypatch, tmp_path):
    from server.app.config import get_settings

    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("AUDIOREV_API_TOKEN", "secreto")
    get_settings.cache_clear()
    s = get_settings()
    assert s.data_dir == tmp_path
    assert s.api_token == "secreto"
    assert s.index_dir == tmp_path / "index"
    assert s.audio_dir == tmp_path / "audio"


def test_cookie_secure_defaults_true_and_parses_falsey_strings(monkeypatch, tmp_path):
    from server.app.config import get_settings

    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.delenv("AUDIOREV_COOKIE_SECURE", raising=False)
    get_settings.cache_clear()
    assert get_settings().cookie_secure is True

    for valor in ("0", "false", "False", "no", "NO"):
        monkeypatch.setenv("AUDIOREV_COOKIE_SECURE", valor)
        get_settings.cache_clear()
        assert get_settings().cookie_secure is False, valor


def test_public_host_defaults_to_the_real_domain(monkeypatch, tmp_path):
    from server.app.config import get_settings

    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.delenv("AUDIOREV_PUBLIC_HOST", raising=False)
    get_settings.cache_clear()
    assert get_settings().public_host == "tfm-jorgerente.duckdns.org"
