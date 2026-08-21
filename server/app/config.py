"""Configuración del servidor, tomada de variables de entorno."""

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

_VALORES_FALSOS = {"0", "false", "no"}


def _parse_bool(valor: str, por_defecto: bool) -> bool:
    """Interpreta cadenas de entorno habituales como booleano."""
    if valor is None or valor == "":
        return por_defecto
    return valor.strip().lower() not in _VALORES_FALSOS


@dataclass(frozen=True)
class Settings:
    data_dir: Path
    repo_dir: Path
    password_hash: str
    api_token: str
    session_secret: str
    trust_proxy_user: str | None
    cookie_secure: bool
    public_host: str

    @property
    def index_dir(self) -> Path:
        return self.data_dir / "index"

    @property
    def audio_dir(self) -> Path:
        return self.data_dir / "audio"

    @property
    def db_path(self) -> Path:
        return self.data_dir / "audiorev.sqlite3"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    data_dir = Path(os.environ.get("AUDIOREV_DATA_DIR", "/data"))
    return Settings(
        data_dir=data_dir,
        repo_dir=Path(os.environ.get("AUDIOREV_REPO_DIR", str(data_dir / "repo"))),
        password_hash=os.environ.get("AUDIOREV_PASSWORD_HASH", ""),
        api_token=os.environ.get("AUDIOREV_API_TOKEN", ""),
        session_secret=os.environ.get("AUDIOREV_SESSION_SECRET", ""),
        trust_proxy_user=os.environ.get("AUDIOREV_TRUST_PROXY_USER") or None,
        cookie_secure=_parse_bool(os.environ.get("AUDIOREV_COOKIE_SECURE", ""), True),
        public_host=os.environ.get("AUDIOREV_PUBLIC_HOST", "tfm-jorgerente.duckdns.org"),
    )
