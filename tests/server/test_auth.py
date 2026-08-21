"""Pruebas de autenticación: cookie de sesión para la persona, token para el agente."""

import pytest

from server.app.auth import hash_password, verify_password


def test_password_hash_roundtrip():
    stored = hash_password("una contraseña larga")
    assert stored != "una contraseña larga"
    assert verify_password("una contraseña larga", stored)
    assert not verify_password("otra", stored)


def test_verify_against_empty_hash_is_always_false():
    assert not verify_password("lo que sea", "")


@pytest.fixture
def client_with_password(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient

    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("AUDIOREV_API_TOKEN", "token-de-prueba")
    monkeypatch.setenv("AUDIOREV_SESSION_SECRET", "secreto-de-prueba")
    monkeypatch.setenv("AUDIOREV_PASSWORD_HASH", hash_password("clave-correcta"))
    monkeypatch.setenv("AUDIOREV_COOKIE_SECURE", "0")
    from server.app.config import get_settings

    get_settings.cache_clear()
    from server.app.main import create_app

    with TestClient(create_app()) as c:
        yield c


def test_api_requires_authentication(client_with_password):
    assert client_with_password.get("/api/me").status_code == 401


def test_login_sets_a_session_cookie_and_opens_the_api(client_with_password):
    r = client_with_password.post("/login", json={"password": "clave-correcta"})
    assert r.status_code == 200
    cookie = client_with_password.cookies.get("audiorev_session")
    assert cookie
    assert client_with_password.get("/api/me").status_code == 200


def test_wrong_password_is_rejected(client_with_password):
    assert client_with_password.post("/login", json={"password": "mala"}).status_code == 401


def test_logout_closes_the_session(client_with_password):
    client_with_password.post("/login", json={"password": "clave-correcta"})
    client_with_password.post("/logout")
    assert client_with_password.get("/api/me").status_code == 401


def test_bearer_token_opens_the_agent_api(client_with_password):
    r = client_with_password.get(
        "/api/revisiones", headers={"Authorization": "Bearer token-de-prueba"}
    )
    assert r.status_code == 200
    assert r.json() == {"revisiones": []}


def test_wrong_bearer_token_is_rejected(client_with_password):
    r = client_with_password.get(
        "/api/revisiones", headers={"Authorization": "Bearer falso"}
    )
    assert r.status_code == 401


def test_proxy_mode_trusts_the_header_and_hides_login(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient

    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("AUDIOREV_TRUST_PROXY_USER", "Remote-User")
    monkeypatch.setenv("AUDIOREV_API_TOKEN", "t")
    monkeypatch.setenv("AUDIOREV_SESSION_SECRET", "s")
    from server.app.config import get_settings

    get_settings.cache_clear()
    from server.app.main import create_app

    with TestClient(create_app()) as c:
        assert c.post("/login", json={"password": "x"}).status_code == 404
        assert c.get("/api/me", headers={"Remote-User": "jorge"}).status_code == 200
        assert c.get("/api/me").status_code == 401


def test_login_is_rate_limited_after_a_few_failures(client_with_password):
    """El spec pide límite de intentos en /login. Es un contador en memoria
    por IP (aplicación de un solo usuario, no hace falta Redis)."""
    from server.app import main as main_module

    main_module._login_fails.clear()
    for _ in range(main_module.LOGIN_MAX_FAILS):
        assert client_with_password.post("/login", json={"password": "mala"}).status_code == 401

    r = client_with_password.post("/login", json={"password": "mala"})
    assert r.status_code == 429
    assert "intentos" in r.json()["detail"]

    # Con el límite agotado, ni siquiera la contraseña buena entra hasta que
    # pase la ventana: el bloqueo es por IP, no por contraseña.
    assert client_with_password.post(
        "/login", json={"password": "clave-correcta"}).status_code == 429
    main_module._login_fails.clear()


def test_a_successful_login_clears_the_failure_counter(client_with_password):
    from server.app import main as main_module

    main_module._login_fails.clear()
    client_with_password.post("/login", json={"password": "mala"})
    assert client_with_password.post(
        "/login", json={"password": "clave-correcta"}).status_code == 200
    assert not main_module._login_fails
