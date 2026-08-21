"""Fixtures compartidas para las pruebas del servidor de AudioRev."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def data_dir(tmp_path, monkeypatch) -> Path:
    """Directorio de datos temporal con las variables de entorno mínimas."""
    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("AUDIOREV_API_TOKEN", "token-de-prueba")
    monkeypatch.setenv("AUDIOREV_SESSION_SECRET", "secreto-de-prueba")
    monkeypatch.setenv("AUDIOREV_PASSWORD_HASH", "")
    monkeypatch.setenv("AUDIOREV_COOKIE_SECURE", "0")
    from server.app.config import get_settings

    get_settings.cache_clear()
    return tmp_path


@pytest.fixture
def client(data_dir):
    from server.app.main import create_app

    with TestClient(create_app()) as c:
        yield c
