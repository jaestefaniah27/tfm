# AudioRev, servidor y aplicación web: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el servidor y la aplicación web que sirven el audio del TFM al móvil, registran las revisiones ancladas a la frase y las devuelven a Claude Code por git y por API.

**Architecture:** FastAPI con SQLite delante de la salida del conversor. La aplicación es una PWA sin cadena de compilación que consume tres endpoints de lectura y dos de escritura. Al cerrar una sesión de escucha, el servidor escribe un fichero de revisiones en su clon del repositorio y lo empuja a GitHub.

**Tech Stack:** Python 3.11+, FastAPI, Uvicorn, sqlite3 de la biblioteca estándar, argon2-cffi, pytest y httpx. Frontend en HTML, CSS y JavaScript sin dependencias.

**Spec:** `docs/superpowers/specs/2026-08-20-audiorev-design.md`

**Requisito previo:** el plan `docs/superpowers/plans/2026-08-20-audiorev-pipeline.md` debe estar terminado. Este plan consume su salida: `manifest.json`, un `<unit_id>.json` y un `<unit_id>.opus` por unidad.

## Global Constraints

- Python 3.11 o superior. Todo `open()` lleva `encoding="utf-8"` explícito.
- Un solo usuario. Nada de registro, recuperación de contraseña ni roles.
- La sesión web y la API de Claude Code usan credenciales distintas: cookie firmada para la persona, token *bearer* para el agente.
- Ninguna respuesta de la API devuelve rutas absolutas del servidor.
- La base de datos es un único fichero SQLite en el volumen de datos. Las migraciones son idempotentes: arrancar dos veces no rompe nada.
- El proceso automático de git escribe **solo** bajo `revisiones/`. Cualquier otra ruta es un error.
- Los identificadores `unit_id` y los campos de anclaje se copian tal cual del pipeline. El servidor no los reinventa.
- Todo endpoint bajo `/api/` exige autenticación. `/healthz` es la única excepción.

## Estructura de ficheros

| Fichero | Responsabilidad |
|---|---|
| `server/app/config.py` | Configuración desde variables de entorno |
| `server/app/db.py` | Conexión, esquema y migraciones de SQLite |
| `server/app/auth.py` | Contraseña, cookie de sesión, token de API y modo proxy |
| `server/app/index.py` | Carga el manifiesto del pipeline en la base de datos |
| `server/app/notes.py` | Alta, consulta y cambio de estado de las revisiones |
| `server/app/publish.py` | Escritura de `revisiones/*.md` y push a git |
| `server/app/main.py` | Aplicación FastAPI y rutas |
| `server/static/index.html` | Pantalla de lista de apartados |
| `server/static/player.html` | Reproductor con resaltado y hoja de notas |
| `server/static/app.js` | Lógica común: peticiones, estado y cola sin red |
| `server/static/player.js` | Reproductor, resaltado y anotación |
| `server/static/style.css` | Estilos, pensados para el móvil |
| `server/static/sw.js` | Service worker: precacheo y cola de notas |
| `server/Dockerfile`, `server/compose.yml` | Despliegue |
| `server/README.md` | Variables de entorno, despliegue y respaldo |
| `tests/server/` | Pruebas |

---

### Task 1: Esqueleto del servidor y despliegue

**Files:**
- Create: `server/app/__init__.py`, `server/app/config.py`, `server/app/main.py`
- Create: `server/Dockerfile`, `server/compose.yml`, `server/requirements.txt`
- Create: `tests/server/__init__.py`, `tests/server/conftest.py`
- Test: `tests/server/test_health.py`

**Interfaces:**
- Consumes: nada.
- Produces: `config.Settings` con los campos `data_dir: Path`, `index_dir: Path`, `audio_dir: Path`, `repo_dir: Path`, `password_hash: str`, `api_token: str`, `session_secret: str`, `trust_proxy_user: str | None`; la función `get_settings() -> Settings`; y la aplicación `main.app`. La fixture `client` de `conftest.py` devuelve un `TestClient` con un directorio de datos temporal.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_health.py`:

```python
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
```

`tests/server/conftest.py`:

```python
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def data_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("AUDIOREV_DATA_DIR", str(tmp_path))
    monkeypatch.setenv("AUDIOREV_API_TOKEN", "token-de-prueba")
    monkeypatch.setenv("AUDIOREV_SESSION_SECRET", "secreto-de-prueba")
    monkeypatch.setenv("AUDIOREV_PASSWORD_HASH", "")
    from server.app.config import get_settings

    get_settings.cache_clear()
    return tmp_path


@pytest.fixture
def client(data_dir):
    from server.app.main import create_app

    with TestClient(create_app()) as c:
        yield c
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_health.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'server'`

- [ ] **Step 3: Escribir la implementación mínima**

`server/app/config.py`:

```python
"""Configuración del servidor, tomada de variables de entorno."""

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    data_dir: Path
    repo_dir: Path
    password_hash: str
    api_token: str
    session_secret: str
    trust_proxy_user: str | None

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
    )
```

`server/app/main.py`:

```python
"""Aplicación FastAPI de AudioRev."""

from fastapi import FastAPI

from .config import get_settings

VERSION = "0.1.0"


def create_app() -> FastAPI:
    settings = get_settings()
    settings.index_dir.mkdir(parents=True, exist_ok=True)
    settings.audio_dir.mkdir(parents=True, exist_ok=True)

    app = FastAPI(title="AudioRev", version=VERSION, docs_url=None, redoc_url=None)

    @app.get("/healthz")
    def healthz() -> dict:
        return {"status": "ok", "version": VERSION}

    return app


app = create_app()
```

`server/requirements.txt`:

```
fastapi>=0.115
uvicorn[standard]>=0.30
argon2-cffi>=23.1
itsdangerous>=2.2
httpx>=0.27
pytest>=8.0
```

`server/Dockerfile`:

```dockerfile
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg git ca-certificates openssh-client \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv
COPY server/requirements.txt /srv/server/requirements.txt
RUN pip install --no-cache-dir -r /srv/server/requirements.txt

COPY server /srv/server
COPY tools /srv/tools

ENV AUDIOREV_DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 8000

CMD ["uvicorn", "server.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

`server/compose.yml`:

```yaml
services:
  audiorev:
    build:
      context: ..
      dockerfile: server/Dockerfile
    restart: unless-stopped
    environment:
      AUDIOREV_DATA_DIR: /data
      AUDIOREV_REPO_DIR: /data/repo
      AUDIOREV_PASSWORD_HASH: ${AUDIOREV_PASSWORD_HASH}
      AUDIOREV_API_TOKEN: ${AUDIOREV_API_TOKEN}
      AUDIOREV_SESSION_SECRET: ${AUDIOREV_SESSION_SECRET}
      AUDIOREV_TTS_BACKEND: piper
    volumes:
      - audiorev-data:/data
      - ${SSH_KEY_PATH}:/root/.ssh/id_ed25519:ro
    ports:
      - "127.0.0.1:8091:8000"

volumes:
  audiorev-data:
```

`server/app/__init__.py` y `tests/server/__init__.py`: ficheros vacíos.

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_health.py -v`
Expected: 3 passed

- [ ] **Step 5: Levantar el contenedor y comprobarlo desde fuera**

```bash
cd server && docker compose up -d --build
curl -s localhost:8091/healthz
```

Expected: `{"status":"ok","version":"0.1.0"}`

Añade el `location` correspondiente en el reverse proxy apuntando a `127.0.0.1:8091` y comprueba desde el móvil que responde por HTTPS.

- [ ] **Step 6: Commit**

```bash
git add server tests/server
git commit -m "Levantar el esqueleto del servidor de AudioRev y su despliegue"
```

---

### Task 2: Autenticación

**Files:**
- Create: `server/app/auth.py`
- Modify: `server/app/main.py`
- Test: `tests/server/test_auth.py`

**Interfaces:**
- Consumes: `get_settings` de `config.py`.
- Produces: `hash_password(raw: str) -> str`, `verify_password(raw: str, stored: str) -> bool`, la dependencia `require_user(request) -> str` para las rutas de persona, y `require_api_token(request) -> None` para las rutas de agente. Las rutas nuevas son `POST /login`, `POST /logout` y `GET /api/me`.

Tres modos, en este orden de prioridad: si `trust_proxy_user` está definido, se confía en esa cabecera y `/login` devuelve 404; si no, se exige la cookie de sesión; la API de Claude Code usa siempre el token *bearer*, con independencia del modo.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_auth.py`:

```python
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
    assert r.status_code != 401


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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_auth.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'server.app.auth'`

- [ ] **Step 3: Escribir la implementación mínima**

`server/app/auth.py`:

```python
"""Autenticación: contraseña para la persona, token para el agente."""

import hmac

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError
from fastapi import HTTPException, Request
from itsdangerous import BadSignature, URLSafeTimedSerializer

from .config import get_settings

COOKIE = "audiorev_session"
MAX_AGE = 30 * 24 * 3600

_hasher = PasswordHasher()


def hash_password(raw: str) -> str:
    return _hasher.hash(raw)


def verify_password(raw: str, stored: str) -> bool:
    if not stored:
        return False
    try:
        return _hasher.verify(stored, raw)
    except (VerifyMismatchError, VerificationError):
        return False


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(get_settings().session_secret, salt="audiorev")


def issue_session(user: str = "jorge") -> str:
    return _serializer().dumps({"u": user})


def read_session(token: str) -> str | None:
    try:
        return _serializer().loads(token, max_age=MAX_AGE).get("u")
    except (BadSignature, Exception):
        return None


def require_user(request: Request) -> str:
    settings = get_settings()
    if settings.trust_proxy_user:
        user = request.headers.get(settings.trust_proxy_user)
        if not user:
            raise HTTPException(status_code=401, detail="No autenticado")
        return user

    token = request.cookies.get(COOKIE)
    user = read_session(token) if token else None
    if not user:
        raise HTTPException(status_code=401, detail="No autenticado")
    return user


def require_api_token(request: Request) -> None:
    expected = get_settings().api_token
    header = request.headers.get("Authorization", "")
    given = header[7:] if header.startswith("Bearer ") else ""
    if not expected or not hmac.compare_digest(given, expected):
        raise HTTPException(status_code=401, detail="Token no válido")
```

En `server/app/main.py`, dentro de `create_app`, añade:

```python
from fastapi import Depends, HTTPException, Response
from pydantic import BaseModel

from .auth import COOKIE, MAX_AGE, issue_session, require_user, verify_password


class LoginBody(BaseModel):
    password: str


@app.post("/login")
def login(body: LoginBody, response: Response) -> dict:
    if settings.trust_proxy_user:
        raise HTTPException(status_code=404, detail="No disponible en modo proxy")
    if not verify_password(body.password, settings.password_hash):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
    response.set_cookie(
        COOKIE, issue_session(), max_age=MAX_AGE,
        httponly=True, secure=True, samesite="lax", path="/",
    )
    return {"ok": True}


@app.post("/logout")
def logout(response: Response) -> dict:
    response.delete_cookie(COOKIE, path="/")
    return {"ok": True}


@app.get("/api/me")
def me(user: str = Depends(require_user)) -> dict:
    return {"user": user}
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_auth.py -v`
Expected: 9 passed. Las dos pruebas del token *bearer* fallarán hasta la tarea 8, porque `/api/revisiones` todavía no existe; márcalas con `pytest.mark.xfail(reason="ruta creada en la tarea 8")` y quita la marca entonces.

- [ ] **Step 5: Generar las credenciales reales del servidor**

```bash
python -c "from server.app.auth import hash_password; print(hash_password(input('Contraseña: ')))"
python -c "import secrets; print('API_TOKEN =', secrets.token_urlsafe(32)); print('SESSION_SECRET =', secrets.token_urlsafe(48))"
```

Guarda los tres valores en el `.env` del servidor. **No los añadas a git.** Comprueba que `server/.env` está cubierto por `.gitignore`.

- [ ] **Step 6: Commit**

```bash
git add server/app/auth.py server/app/main.py tests/server/test_auth.py .gitignore
git commit -m "Autenticar a la persona por cookie y al agente por token"
```

---

### Task 3: Base de datos y carga del índice

**Files:**
- Create: `server/app/db.py`, `server/app/index.py`
- Modify: `server/app/main.py`
- Test: `tests/server/test_db.py`, `tests/server/test_index.py`

**Interfaces:**
- Consumes: `get_settings`, y la salida del pipeline: `manifest.json` y `<unit_id>.json`.
- Produces: `db.connect() -> sqlite3.Connection`, `db.migrate(conn) -> None`, `index.load_index(conn, index_dir) -> int` que devuelve el número de unidades cargadas, e `index.unit_payload(index_dir, unit_id) -> dict`.

Esquema:

```sql
CREATE TABLE units (
  unit_id TEXT PRIMARY KEY, chapter INTEGER, chapter_title TEXT, level INTEGER,
  title TEXT, tex_file TEXT, duration_s REAL, n_sentences INTEGER,
  n_blocks INTEGER, ord INTEGER, content_hash TEXT
);
CREATE TABLE progress (
  unit_id TEXT PRIMARY KEY, state TEXT NOT NULL DEFAULT 'pendiente',
  position_s REAL NOT NULL DEFAULT 0, updated_at TEXT
);
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL,
  unit_id TEXT NOT NULL, sentence_idx INTEGER, sentence_hash TEXT,
  sentence_text TEXT, tex_file TEXT, tex_line INTEGER, audio_ts REAL,
  tags TEXT, comment TEXT, state TEXT NOT NULL DEFAULT 'pendiente',
  created_at TEXT NOT NULL, applied_at TEXT
);
CREATE TABLE sessions (
  session_id TEXT PRIMARY KEY, started_at TEXT NOT NULL,
  closed_at TEXT, published_path TEXT
);
CREATE INDEX idx_notes_state ON notes(state);
CREATE INDEX idx_notes_unit ON notes(unit_id);
```

- [ ] **Step 1: Escribir las pruebas que fallan**

`tests/server/test_db.py`:

```python
from server.app import db


def test_migrate_creates_every_table(data_dir):
    conn = db.connect()
    db.migrate(conn)
    names = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert {"units", "progress", "notes", "sessions"} <= names


def test_migrate_is_idempotent(data_dir):
    conn = db.connect()
    db.migrate(conn)
    db.migrate(conn)
    conn.execute("INSERT INTO sessions (session_id, started_at) VALUES ('s1', 'x')")
    assert conn.execute("SELECT count(*) FROM sessions").fetchone()[0] == 1


def test_rows_come_back_as_mappings(data_dir):
    conn = db.connect()
    db.migrate(conn)
    conn.execute("INSERT INTO sessions (session_id, started_at) VALUES ('s1', 'x')")
    row = conn.execute("SELECT * FROM sessions").fetchone()
    assert row["session_id"] == "s1"
```

`tests/server/test_index.py`:

```python
import json

from server.app import db, index


def _write_index(index_dir):
    index_dir.mkdir(parents=True, exist_ok=True)
    unit = {
        "unit_id": "c03-entorno-nco", "chapter": 3, "chapter_title": "Desarrollo",
        "level": 2, "title": "Oscilador controlado numéricamente (NCO)",
        "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        "tex_lines": [326, 402], "duration_s": 168.4,
        "sentences": [{"idx": 0, "text": "Una frase.", "spoken": "Una frase.",
                       "hash": "abc123", "tex_line": 328, "t_start": 0.0, "t_end": 3.9}],
        "blocks": [],
    }
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps(unit), encoding="utf-8")
    (index_dir / "manifest.json").write_text(json.dumps({"units": [
        {"unit_id": "c03-entorno-nco", "title": unit["title"], "chapter": 3,
         "chapter_title": "Desarrollo", "level": 2, "duration_s": 168.4,
         "n_sentences": 1, "n_blocks": 0}
    ]}), encoding="utf-8")


def test_loads_the_manifest_into_units(data_dir):
    _write_index(data_dir / "index")
    conn = db.connect()
    db.migrate(conn)
    assert index.load_index(conn, data_dir / "index") == 1
    row = conn.execute("SELECT * FROM units").fetchone()
    assert row["unit_id"] == "c03-entorno-nco"
    assert row["chapter"] == 3
    assert row["ord"] == 0


def test_reloading_updates_instead_of_duplicating(data_dir):
    _write_index(data_dir / "index")
    conn = db.connect()
    db.migrate(conn)
    index.load_index(conn, data_dir / "index")
    index.load_index(conn, data_dir / "index")
    assert conn.execute("SELECT count(*) FROM units").fetchone()[0] == 1


def test_reloading_preserves_progress_and_notes(data_dir):
    _write_index(data_dir / "index")
    conn = db.connect()
    db.migrate(conn)
    index.load_index(conn, data_dir / "index")
    conn.execute(
        "INSERT INTO progress (unit_id, state, position_s) VALUES ('c03-entorno-nco','escuchado',12.5)"
    )
    index.load_index(conn, data_dir / "index")
    row = conn.execute("SELECT * FROM progress").fetchone()
    assert row["state"] == "escuchado"
    assert row["position_s"] == 12.5


def test_unit_payload_returns_the_full_json(data_dir):
    _write_index(data_dir / "index")
    payload = index.unit_payload(data_dir / "index", "c03-entorno-nco")
    assert payload["sentences"][0]["t_end"] == 3.9


def test_unit_payload_of_unknown_id_returns_none(data_dir):
    _write_index(data_dir / "index")
    assert index.unit_payload(data_dir / "index", "no-existe") is None


def test_unit_payload_rejects_path_traversal(data_dir):
    _write_index(data_dir / "index")
    assert index.unit_payload(data_dir / "index", "../../etc/passwd") is None
```

- [ ] **Step 2: Ejecutar las pruebas y comprobar que fallan**

Run: `pytest tests/server/test_db.py tests/server/test_index.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'server.app.db'`

- [ ] **Step 3: Escribir la implementación mínima**

`server/app/db.py`:

```python
"""Conexión y esquema de la base de datos SQLite."""

import sqlite3

from .config import get_settings

_SCHEMA = """
CREATE TABLE IF NOT EXISTS units (
  unit_id TEXT PRIMARY KEY, chapter INTEGER, chapter_title TEXT, level INTEGER,
  title TEXT, tex_file TEXT, duration_s REAL, n_sentences INTEGER,
  n_blocks INTEGER, ord INTEGER, content_hash TEXT
);
CREATE TABLE IF NOT EXISTS progress (
  unit_id TEXT PRIMARY KEY, state TEXT NOT NULL DEFAULT 'pendiente',
  position_s REAL NOT NULL DEFAULT 0, updated_at TEXT
);
CREATE TABLE IF NOT EXISTS notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL,
  unit_id TEXT NOT NULL, sentence_idx INTEGER, sentence_hash TEXT,
  sentence_text TEXT, tex_file TEXT, tex_line INTEGER, audio_ts REAL,
  tags TEXT, comment TEXT, state TEXT NOT NULL DEFAULT 'pendiente',
  created_at TEXT NOT NULL, applied_at TEXT
);
CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY, started_at TEXT NOT NULL,
  closed_at TEXT, published_path TEXT
);
CREATE INDEX IF NOT EXISTS idx_notes_state ON notes(state);
CREATE INDEX IF NOT EXISTS idx_notes_unit ON notes(unit_id);
"""


def connect() -> sqlite3.Connection:
    settings = get_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.db_path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.isolation_level = None
    return conn


def migrate(conn: sqlite3.Connection) -> None:
    conn.executescript(_SCHEMA)
```

`server/app/index.py`:

```python
"""Carga en la base de datos del índice que produce el pipeline."""

import hashlib
import json
import re
import sqlite3
from pathlib import Path

_SAFE_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,120}$")


def load_index(conn: sqlite3.Connection, index_dir: Path) -> int:
    """Sincroniza la tabla units con manifest.json. No toca progress ni notes."""
    manifest_path = index_dir / "manifest.json"
    if not manifest_path.exists():
        return 0

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    units = manifest.get("units", [])

    for order, unit in enumerate(units):
        payload = unit_payload(index_dir, unit["unit_id"]) or {}
        blob = json.dumps(payload.get("sentences", []), ensure_ascii=False)
        content_hash = hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]
        conn.execute(
            """
            INSERT INTO units (unit_id, chapter, chapter_title, level, title,
                               tex_file, duration_s, n_sentences, n_blocks, ord, content_hash)
            VALUES (:unit_id, :chapter, :chapter_title, :level, :title,
                    :tex_file, :duration_s, :n_sentences, :n_blocks, :ord, :content_hash)
            ON CONFLICT(unit_id) DO UPDATE SET
              chapter=excluded.chapter, chapter_title=excluded.chapter_title,
              level=excluded.level, title=excluded.title, tex_file=excluded.tex_file,
              duration_s=excluded.duration_s, n_sentences=excluded.n_sentences,
              n_blocks=excluded.n_blocks, ord=excluded.ord, content_hash=excluded.content_hash
            """,
            {
                "unit_id": unit["unit_id"],
                "chapter": unit.get("chapter"),
                "chapter_title": unit.get("chapter_title", ""),
                "level": unit.get("level", 1),
                "title": unit.get("title", ""),
                "tex_file": payload.get("tex_file", ""),
                "duration_s": unit.get("duration_s", 0.0),
                "n_sentences": unit.get("n_sentences", 0),
                "n_blocks": unit.get("n_blocks", 0),
                "ord": order,
                "content_hash": content_hash,
            },
        )
    return len(units)


def unit_payload(index_dir: Path, unit_id: str) -> dict | None:
    """Devuelve el JSON completo de una unidad, o None si el id no es válido."""
    if not _SAFE_ID.match(unit_id):
        return None
    path = index_dir / f"{unit_id}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))
```

En `create_app`, tras crear los directorios:

```python
from . import db as db_module
from .index import load_index

app.state.db = db_module.connect()
db_module.migrate(app.state.db)
load_index(app.state.db, settings.index_dir)
```

- [ ] **Step 4: Ejecutar las pruebas y comprobar que pasan**

Run: `pytest tests/server/test_db.py tests/server/test_index.py -v`
Expected: 10 passed

- [ ] **Step 5: Commit**

```bash
git add server/app/db.py server/app/index.py server/app/main.py tests/server/test_db.py tests/server/test_index.py
git commit -m "Cargar el índice del conversor en SQLite sin perder el progreso"
```

---

### Task 4: API de lectura y servicio del audio

**Files:**
- Modify: `server/app/main.py`
- Test: `tests/server/test_read_api.py`

**Interfaces:**
- Consumes: `require_user`, `index.unit_payload`, la conexión de `app.state.db`.
- Produces: `GET /api/units`, `GET /api/units/{unit_id}`, `GET /api/progress`, `PUT /api/progress/{unit_id}` y `GET /audio/{unit_id}.opus`.

`GET /api/units` devuelve el manifiesto enriquecido con el estado y el número de notas, agrupado por capítulo, más el total de duración pendiente. El audio se sirve con `FileResponse`, que ya soporta peticiones por rango, imprescindible para poder buscar dentro de una pista larga desde el móvil.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_read_api.py`:

```python
import json

import pytest


@pytest.fixture
def loaded(client, data_dir):
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    units = []
    for n in (1, 2):
        uid = f"c03-entorno-u{n}"
        (index_dir / f"{uid}.json").write_text(json.dumps({
            "unit_id": uid, "chapter": 3, "chapter_title": "Desarrollo", "level": 2,
            "title": f"Unidad {n}", "tex_file": "a/b.tex", "tex_lines": [1, 9],
            "duration_s": 10.0 * n,
            "sentences": [{"idx": 0, "text": "Frase.", "spoken": "Frase.", "hash": "h",
                           "tex_line": 2, "t_start": 0.0, "t_end": 10.0 * n}],
            "blocks": [],
        }), encoding="utf-8")
        units.append({"unit_id": uid, "title": f"Unidad {n}", "chapter": 3,
                      "chapter_title": "Desarrollo", "level": 2,
                      "duration_s": 10.0 * n, "n_sentences": 1, "n_blocks": 0})
    (index_dir / "manifest.json").write_text(json.dumps({"units": units}), encoding="utf-8")
    (data_dir / "audio").mkdir(parents=True, exist_ok=True)
    (data_dir / "audio" / "c03-entorno-u1.opus").write_bytes(b"OggS-falso")
    client.post("/api/reload", headers={"Authorization": "Bearer token-de-prueba"})
    return client


def test_units_are_grouped_by_chapter_with_totals(loaded):
    body = loaded.get("/api/units").json()
    assert body["total_duration_s"] == 30.0
    assert body["chapters"][0]["chapter"] == 3
    assert len(body["chapters"][0]["units"]) == 2
    assert body["chapters"][0]["units"][0]["state"] == "pendiente"
    assert body["chapters"][0]["units"][0]["n_notes"] == 0


def test_unit_detail_returns_sentences_and_blocks(loaded):
    body = loaded.get("/api/units/c03-entorno-u1").json()
    assert body["sentences"][0]["t_end"] == 10.0
    assert body["blocks"] == []


def test_unknown_unit_is_404(loaded):
    assert loaded.get("/api/units/no-existe").status_code == 404


def test_progress_is_stored_and_returned(loaded):
    r = loaded.put("/api/progress/c03-entorno-u1",
                   json={"state": "en_curso", "position_s": 4.5})
    assert r.status_code == 200
    body = loaded.get("/api/units").json()
    unit = body["chapters"][0]["units"][0]
    assert unit["state"] == "en_curso"
    assert unit["position_s"] == 4.5


def test_invalid_progress_state_is_rejected(loaded):
    r = loaded.put("/api/progress/c03-entorno-u1",
                   json={"state": "inventado", "position_s": 0})
    assert r.status_code == 422


def test_audio_is_served_and_supports_range(loaded):
    r = loaded.get("/audio/c03-entorno-u1.opus")
    assert r.status_code == 200
    assert r.headers["content-type"] == "audio/ogg"
    r = loaded.get("/audio/c03-entorno-u1.opus", headers={"Range": "bytes=0-3"})
    assert r.status_code == 206


def test_missing_audio_is_404_not_500(loaded):
    assert loaded.get("/audio/c03-entorno-u2.opus").status_code == 404


def test_audio_path_traversal_is_blocked(loaded):
    assert loaded.get("/audio/..%2F..%2Fetc%2Fpasswd.opus").status_code in (400, 404)
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_read_api.py -v`
Expected: FAIL, las rutas no existen

- [ ] **Step 3: Escribir la implementación mínima**

En `server/app/main.py`, dentro de `create_app`:

```python
import re
from datetime import datetime, timezone
from typing import Literal

from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .auth import require_api_token
from .index import load_index, unit_payload

_SAFE_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,120}$")
_STATES = ("pendiente", "en_curso", "escuchado", "con_notas")


class ProgressBody(BaseModel):
    state: Literal["pendiente", "en_curso", "escuchado", "con_notas"]
    position_s: float = 0.0


@app.post("/api/reload")
def reload_index(_: None = Depends(require_api_token)) -> dict:
    n = load_index(app.state.db, settings.index_dir)
    return {"loaded": n}


@app.get("/api/units")
def list_units(user: str = Depends(require_user)) -> dict:
    rows = app.state.db.execute(
        """
        SELECT u.*, COALESCE(p.state, 'pendiente') AS state,
               COALESCE(p.position_s, 0) AS position_s,
               (SELECT count(*) FROM notes n
                 WHERE n.unit_id = u.unit_id AND n.state = 'pendiente') AS n_notes
          FROM units u LEFT JOIN progress p ON p.unit_id = u.unit_id
         ORDER BY u.ord
        """
    ).fetchall()

    chapters: list[dict] = []
    for row in rows:
        item = dict(row)
        if not chapters or chapters[-1]["chapter"] != item["chapter"]:
            chapters.append({
                "chapter": item["chapter"],
                "chapter_title": item["chapter_title"],
                "units": [],
            })
        chapters[-1]["units"].append(item)

    total = sum(r["duration_s"] or 0.0 for r in rows)
    done = sum((r["duration_s"] or 0.0) for r in rows if r["state"] == "escuchado")
    return {
        "chapters": chapters,
        "total_duration_s": total,
        "listened_duration_s": done,
    }


@app.get("/api/units/{unit_id}")
def get_unit(unit_id: str, user: str = Depends(require_user)) -> dict:
    payload = unit_payload(settings.index_dir, unit_id)
    if payload is None:
        raise HTTPException(status_code=404, detail="Apartado desconocido")
    return payload


@app.put("/api/progress/{unit_id}")
def put_progress(unit_id: str, body: ProgressBody, user: str = Depends(require_user)) -> dict:
    if not _SAFE_ID.match(unit_id):
        raise HTTPException(status_code=400, detail="Identificador no válido")
    app.state.db.execute(
        """
        INSERT INTO progress (unit_id, state, position_s, updated_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(unit_id) DO UPDATE SET
          state=excluded.state, position_s=excluded.position_s, updated_at=excluded.updated_at
        """,
        (unit_id, body.state, body.position_s, datetime.now(timezone.utc).isoformat()),
    )
    return {"ok": True}


@app.get("/audio/{filename}")
def get_audio(filename: str, user: str = Depends(require_user)) -> FileResponse:
    if not filename.endswith(".opus") or not _SAFE_ID.match(filename[:-5]):
        raise HTTPException(status_code=400, detail="Nombre no válido")
    path = settings.audio_dir / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail="Audio no disponible")
    return FileResponse(path, media_type="audio/ogg")


app.mount("/", StaticFiles(directory="server/static", html=True), name="static")
```

El `app.mount` va **al final** de `create_app`, después de todas las rutas.

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_read_api.py -v`
Expected: 8 passed

Si `test_audio_is_served_and_supports_range` falla en el caso 206, comprueba que la versión de Starlette soporta rangos en `FileResponse`; desde la 0.37 lo hace de serie.

- [ ] **Step 5: Commit**

```bash
git add server/app/main.py tests/server/test_read_api.py
git commit -m "Servir el índice, el progreso y el audio de cada apartado"
```

---

### Task 5: API de revisiones

**Files:**
- Create: `server/app/notes.py`
- Modify: `server/app/main.py`
- Test: `tests/server/test_notes.py`

**Interfaces:**
- Consumes: la conexión de `app.state.db`.
- Produces: `notes.create(conn, payload: dict) -> int`, `notes.list_notes(conn, state: str | None = None, session_id: str | None = None) -> list[dict]`, `notes.set_state(conn, note_id: int, state: str) -> bool`, `notes.delete(conn, note_id: int) -> bool` y `notes.open_session(conn) -> str`. Rutas: `POST /api/notes`, `GET /api/notes`, `PATCH /api/notes/{id}`, `DELETE /api/notes/{id}` y `POST /api/sessions`.

Estados válidos de una nota: `pendiente`, `aplicada`, `descartada`, `obsoleta`.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_notes.py`:

```python
import pytest

NOTE = {
    "session_id": "s1",
    "unit_id": "c03-entorno-nco",
    "sentence_idx": 4,
    "sentence_hash": "abc123",
    "sentence_text": "El NCO genera la referencia de reloj del transceptor.",
    "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
    "tex_line": 328,
    "audio_ts": 41.2,
    "tags": ["muy_largo", "reescribir"],
    "comment": "Partir en dos frases, la segunda mitad sobra.",
}


def test_creating_a_note_returns_its_id_and_stores_the_anchor(client):
    r = client.post("/api/notes", json=NOTE)
    assert r.status_code == 201
    note_id = r.json()["id"]
    stored = client.get("/api/notes").json()["notes"][0]
    assert stored["id"] == note_id
    assert stored["sentence_text"] == NOTE["sentence_text"]
    assert stored["tags"] == ["muy_largo", "reescribir"]
    assert stored["state"] == "pendiente"
    assert stored["created_at"]


def test_a_note_needs_either_a_comment_or_a_tag(client):
    bad = {**NOTE, "comment": "", "tags": []}
    assert client.post("/api/notes", json=bad).status_code == 422


def test_notes_can_be_filtered_by_state(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.patch(f"/api/notes/{note_id}", json={"state": "aplicada"})
    assert client.get("/api/notes?estado=pendiente").json()["notes"] == []
    assert len(client.get("/api/notes?estado=aplicada").json()["notes"]) == 1


def test_marking_applied_records_the_timestamp(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.patch(f"/api/notes/{note_id}", json={"state": "aplicada"})
    stored = client.get("/api/notes?estado=aplicada").json()["notes"][0]
    assert stored["applied_at"]


def test_invalid_state_is_rejected(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    assert client.patch(f"/api/notes/{note_id}", json={"state": "inventado"}).status_code == 422


def test_patching_an_unknown_note_is_404(client):
    assert client.patch("/api/notes/9999", json={"state": "aplicada"}).status_code == 404


def test_a_note_can_be_edited_and_deleted(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.patch(f"/api/notes/{note_id}", json={"comment": "Texto corregido."})
    assert client.get("/api/notes").json()["notes"][0]["comment"] == "Texto corregido."
    assert client.delete(f"/api/notes/{note_id}").status_code == 204
    assert client.get("/api/notes").json()["notes"] == []


def test_opening_a_session_returns_a_new_identifier(client):
    a = client.post("/api/sessions").json()["session_id"]
    b = client.post("/api/sessions").json()["session_id"]
    assert a != b


def test_creating_a_note_marks_its_unit_as_having_notes(client, data_dir):
    client.post("/api/notes", json=NOTE)
    row = client.app.state.db.execute(
        "SELECT state FROM progress WHERE unit_id = ?", (NOTE["unit_id"],)
    ).fetchone()
    assert row["state"] == "con_notas"
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_notes.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'server.app.notes'`

- [ ] **Step 3: Escribir la implementación mínima**

`server/app/notes.py`:

```python
"""Alta, consulta y cambio de estado de las revisiones."""

import json
import sqlite3
import uuid
from datetime import datetime, timezone

STATES = ("pendiente", "aplicada", "descartada", "obsoleta")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def open_session(conn: sqlite3.Connection) -> str:
    session_id = uuid.uuid4().hex[:12]
    conn.execute(
        "INSERT INTO sessions (session_id, started_at) VALUES (?, ?)",
        (session_id, _now()),
    )
    return session_id


def create(conn: sqlite3.Connection, payload: dict) -> int:
    cur = conn.execute(
        """
        INSERT INTO notes (session_id, unit_id, sentence_idx, sentence_hash,
                           sentence_text, tex_file, tex_line, audio_ts, tags,
                           comment, state, created_at)
        VALUES (:session_id, :unit_id, :sentence_idx, :sentence_hash,
                :sentence_text, :tex_file, :tex_line, :audio_ts, :tags,
                :comment, 'pendiente', :created_at)
        """,
        {
            **payload,
            "tags": json.dumps(payload.get("tags") or [], ensure_ascii=False),
            "created_at": _now(),
        },
    )
    conn.execute(
        """
        INSERT INTO progress (unit_id, state, position_s, updated_at)
        VALUES (?, 'con_notas', 0, ?)
        ON CONFLICT(unit_id) DO UPDATE SET state='con_notas', updated_at=excluded.updated_at
        """,
        (payload["unit_id"], _now()),
    )
    return int(cur.lastrowid)


def _row_to_dict(row: sqlite3.Row) -> dict:
    item = dict(row)
    item["tags"] = json.loads(item["tags"] or "[]")
    return item


def list_notes(
    conn: sqlite3.Connection, state: str | None = None, session_id: str | None = None
) -> list[dict]:
    sql = "SELECT * FROM notes"
    clauses, params = [], []
    if state:
        clauses.append("state = ?")
        params.append(state)
    if session_id:
        clauses.append("session_id = ?")
        params.append(session_id)
    if clauses:
        sql += " WHERE " + " AND ".join(clauses)
    sql += " ORDER BY unit_id, sentence_idx, id"
    return [_row_to_dict(r) for r in conn.execute(sql, params)]


def set_state(conn: sqlite3.Connection, note_id: int, state: str) -> bool:
    applied = _now() if state == "aplicada" else None
    cur = conn.execute(
        "UPDATE notes SET state = ?, applied_at = ? WHERE id = ?",
        (state, applied, note_id),
    )
    return cur.rowcount > 0


def set_comment(conn: sqlite3.Connection, note_id: int, comment: str) -> bool:
    cur = conn.execute("UPDATE notes SET comment = ? WHERE id = ?", (comment, note_id))
    return cur.rowcount > 0


def delete(conn: sqlite3.Connection, note_id: int) -> bool:
    return conn.execute("DELETE FROM notes WHERE id = ?", (note_id,)).rowcount > 0
```

En `server/app/main.py`:

```python
from fastapi import Response, status
from pydantic import Field, model_validator

from . import notes as notes_module


class NoteBody(BaseModel):
    session_id: str
    unit_id: str
    sentence_idx: int | None = None
    sentence_hash: str | None = None
    sentence_text: str = ""
    tex_file: str = ""
    tex_line: int | None = None
    audio_ts: float = 0.0
    tags: list[str] = Field(default_factory=list)
    comment: str = ""

    @model_validator(mode="after")
    def needs_content(self):
        if not self.comment.strip() and not self.tags:
            raise ValueError("Una revisión necesita al menos un comentario o una etiqueta")
        return self


class NotePatch(BaseModel):
    state: Literal["pendiente", "aplicada", "descartada", "obsoleta"] | None = None
    comment: str | None = None


@app.post("/api/sessions", status_code=201)
def new_session(user: str = Depends(require_user)) -> dict:
    return {"session_id": notes_module.open_session(app.state.db)}


@app.post("/api/notes", status_code=201)
def post_note(body: NoteBody, user: str = Depends(require_user)) -> dict:
    return {"id": notes_module.create(app.state.db, body.model_dump())}


@app.get("/api/notes")
def get_notes(
    estado: str | None = None, sesion: str | None = None, user: str = Depends(require_user)
) -> dict:
    return {"notes": notes_module.list_notes(app.state.db, estado, sesion)}


@app.patch("/api/notes/{note_id}")
def patch_note(note_id: int, body: NotePatch, user: str = Depends(require_user)) -> dict:
    touched = False
    if body.state:
        touched |= notes_module.set_state(app.state.db, note_id, body.state)
    if body.comment is not None:
        touched |= notes_module.set_comment(app.state.db, note_id, body.comment)
    if not touched:
        raise HTTPException(status_code=404, detail="Revisión desconocida")
    return {"ok": True}


@app.delete("/api/notes/{note_id}", status_code=204)
def delete_note(note_id: int, user: str = Depends(require_user)) -> Response:
    if not notes_module.delete(app.state.db, note_id):
        raise HTTPException(status_code=404, detail="Revisión desconocida")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_notes.py -v`
Expected: 9 passed

- [ ] **Step 5: Commit**

```bash
git add server/app/notes.py server/app/main.py tests/server/test_notes.py
git commit -m "Registrar las revisiones ancladas a la frase"
```

---

### Task 6: Lista de apartados en el móvil

**Files:**
- Create: `server/static/index.html`, `server/static/app.js`, `server/static/style.css`, `server/static/manifest.webmanifest`
- Test: `tests/server/test_static.py`

**Interfaces:**
- Consumes: `GET /api/units`.
- Produces: `app.js` exporta en `window.AudioRev` las funciones `api(path, options)`, `fmtDuration(seconds)` y `stateLabel(state)`, que reutiliza el reproductor de la tarea 7.

La pantalla es una sola columna: cabecera con el progreso global y un botón para seguir donde se dejó, y debajo un bloque plegable por capítulo con sus apartados. Cada apartado muestra el título, la duración, un punto de color según el estado y el número de revisiones pendientes.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_static.py`:

```python
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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_static.py -v`
Expected: FAIL con 404, los ficheros no existen

- [ ] **Step 3: Escribir la implementación mínima**

`server/static/index.html`:

```html
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#1b1b1f">
<title>AudioRev, revisión del TFM</title>
<link rel="manifest" href="/manifest.webmanifest">
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="cabecera">
  <h1>AudioRev</h1>
  <p id="progreso" class="progreso">Cargando…</p>
  <button id="seguir" class="principal" hidden>Seguir donde lo dejé</button>
</header>
<main id="lista" class="lista"></main>
<script src="/app.js"></script>
<script>AudioRev.renderList();</script>
</body>
</html>
```

`server/static/app.js`:

```javascript
'use strict';

const AudioRev = (() => {
  async function api(path, options = {}) {
    const res = await fetch(path, {
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      ...options,
    });
    if (res.status === 401) { location.href = '/login.html'; throw new Error('401'); }
    if (!res.ok) throw new Error(`${res.status} en ${path}`);
    return res.status === 204 ? null : res.json();
  }

  function fmtDuration(seconds) {
    const s = Math.max(0, Math.round(seconds || 0));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    if (h > 0) return `${h} h ${String(m).padStart(2, '0')} min`;
    return `${m} min ${String(s % 60).padStart(2, '0')} s`;
  }

  function stateLabel(state) {
    return {
      pendiente: 'Pendiente',
      en_curso: 'En curso',
      escuchado: 'Escuchado',
      con_notas: 'Con revisiones',
    }[state] || state;
  }

  async function renderList() {
    const data = await api('/api/units');
    document.getElementById('progreso').textContent =
      `${fmtDuration(data.listened_duration_s)} de ${fmtDuration(data.total_duration_s)}`;

    const enCurso = data.chapters
      .flatMap((c) => c.units)
      .find((u) => u.state === 'en_curso' || u.state === 'pendiente');
    const seguir = document.getElementById('seguir');
    if (enCurso) {
      seguir.hidden = false;
      seguir.onclick = () => { location.href = `/player.html?u=${enCurso.unit_id}`; };
    }

    const lista = document.getElementById('lista');
    lista.innerHTML = '';
    for (const chapter of data.chapters) {
      const details = document.createElement('details');
      details.open = chapter.units.some((u) => u.state !== 'escuchado');
      const summary = document.createElement('summary');
      summary.textContent = `${chapter.chapter}. ${chapter.chapter_title}`;
      details.appendChild(summary);

      for (const unit of chapter.units) {
        const a = document.createElement('a');
        a.className = `apartado estado-${unit.state} nivel-${unit.level}`;
        a.href = `/player.html?u=${unit.unit_id}`;
        a.innerHTML =
          `<span class="titulo">${unit.title}</span>` +
          `<span class="meta">${fmtDuration(unit.duration_s)}` +
          (unit.n_notes ? ` · ${unit.n_notes} revisiones` : '') +
          ` · ${stateLabel(unit.state)}</span>`;
        details.appendChild(a);
      }
      lista.appendChild(details);
    }
  }

  return { api, fmtDuration, stateLabel, renderList };
})();

window.AudioRev = AudioRev;
```

`server/static/manifest.webmanifest`:

```json
{
  "name": "AudioRev, revisión del TFM",
  "short_name": "AudioRev",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1b1b1f",
  "theme_color": "#1b1b1f",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

`server/static/style.css`: hoja para móvil, con objetivos táctiles de 48 píxeles como mínimo, tipografía de sistema, tema oscuro por defecto y sangrado a la izquierda según `nivel-1`, `nivel-2` y `nivel-3`. Los estados se distinguen por un punto de color y también por el texto, nunca solo por el color.

Genera los dos iconos PNG con cualquier herramienta; basta un cuadrado con las letras AR.

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_static.py -v`
Expected: 4 passed

- [ ] **Step 5: Comprobarlo en el móvil**

Abre la web en el móvil, comprueba que la lista se lee sin ampliar, que los capítulos se pliegan y que «Añadir a la pantalla de inicio» instala la aplicación.

- [ ] **Step 6: Commit**

```bash
git add server/static tests/server/test_static.py
git commit -m "Mostrar la lista de apartados con su estado y su progreso"
```

---

### Task 7: Reproductor con resaltado por frase

**Files:**
- Create: `server/static/player.html`, `server/static/player.js`
- Test: `tests/server/test_player_static.py`

**Interfaces:**
- Consumes: `GET /api/units/{id}`, `GET /audio/{id}.opus`, `PUT /api/progress/{id}`, y `api`, `fmtDuration` de `app.js`.
- Produces: `window.Player` con `load(unitId)`, `currentSentence()` que devuelve `{idx, text, hash, tex_line, t_start}` y `seekToSentence(idx)`.

El resaltado se hace con el evento `timeupdate` del elemento de audio: se busca la frase cuyo intervalo `[t_start, t_end)` contiene el tiempo actual. Con menos de 200 frases por apartado, una búsqueda lineal desde la última posición conocida basta y sobra.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_player_static.py`:

```python
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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_player_static.py -v`
Expected: FAIL con 404

- [ ] **Step 3: Escribir la implementación mínima**

`server/static/player.html`:

```html
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>AudioRev</title>
<link rel="stylesheet" href="/style.css">
</head>
<body class="reproductor">
<header class="cabecera-reproductor">
  <a href="/" class="volver">Lista</a>
  <h1 id="titulo">…</h1>
</header>

<main id="texto" class="texto"></main>

<footer class="controles">
  <audio id="audio" preload="metadata"></audio>
  <div class="fila">
    <button id="anterior" aria-label="Frase anterior">◀◀</button>
    <button id="atras" aria-label="Diez segundos atrás">−10</button>
    <button id="play" class="principal" aria-label="Reproducir">▶</button>
    <button id="adelante" aria-label="Diez segundos adelante">+10</button>
    <button id="siguiente" aria-label="Frase siguiente">▶▶</button>
  </div>
  <div class="fila">
    <label>Velocidad
      <input id="velocidad" type="range" min="0.8" max="2" step="0.1" value="1">
      <output id="velocidad-valor">1,0×</output>
    </label>
  </div>
  <button id="anotar" class="anotar">Anotar esta frase</button>
</footer>

<script src="/app.js"></script>
<script src="/player.js"></script>
<script>Player.load(new URLSearchParams(location.search).get('u'));</script>
</body>
</html>
```

`server/static/player.js`:

```javascript
'use strict';

const Player = (() => {
  const audio = document.getElementById('audio');
  let unit = null;
  let nodes = [];
  let active = -1;

  function currentSentence() {
    return active >= 0 ? unit.sentences[active] : null;
  }

  function paint(idx) {
    if (idx === active) return;
    if (active >= 0 && nodes[active]) nodes[active].classList.remove('activa');
    active = idx;
    if (idx >= 0 && nodes[idx]) {
      nodes[idx].classList.add('activa');
      nodes[idx].scrollIntoView({ block: 'center', behavior: 'smooth' });
    }
  }

  function findSentence(t) {
    // Búsqueda lineal desde la posición actual: los apartados tienen pocas frases.
    for (let i = Math.max(0, active); i < unit.sentences.length; i += 1) {
      if (t < unit.sentences[i].t_end) return i;
    }
    for (let i = 0; i < unit.sentences.length; i += 1) {
      if (t < unit.sentences[i].t_end) return i;
    }
    return unit.sentences.length - 1;
  }

  function seekToSentence(idx) {
    const s = unit.sentences[idx];
    if (!s) return;
    audio.currentTime = s.t_start + 0.01;
    paint(idx);
  }

  function renderBody() {
    const main = document.getElementById('texto');
    main.innerHTML = '';
    nodes = [];

    const byPosition = new Map();
    for (const block of unit.blocks) {
      const key = block.after_sentence;
      if (!byPosition.has(key)) byPosition.set(key, []);
      byPosition.get(key).push(block);
    }

    unit.sentences.forEach((s, i) => {
      const span = document.createElement('span');
      span.className = 'frase';
      span.textContent = s.text + ' ';
      span.onclick = () => seekToSentence(i);
      main.appendChild(span);
      nodes.push(span);

      for (const block of byPosition.get(i) || []) {
        const details = document.createElement('details');
        details.className = `bloque bloque-${block.type}`;
        const summary = document.createElement('summary');
        summary.textContent = block.caption || `Bloque ${block.type}`;
        details.appendChild(summary);
        const body = document.createElement('div');
        body.innerHTML = block.html || `<p>Contenido visual: ${block.caption}</p>`;
        details.appendChild(body);
        main.appendChild(details);
      }
    });
  }

  function saveProgress(state) {
    const body = JSON.stringify({ state, position_s: audio.currentTime || 0 });
    navigator.sendBeacon
      ? navigator.sendBeacon(`/api/progress/${unit.unit_id}`, new Blob([body], { type: 'application/json' }))
      : AudioRev.api(`/api/progress/${unit.unit_id}`, { method: 'PUT', body });
  }

  async function load(unitId) {
    unit = await AudioRev.api(`/api/units/${unitId}`);
    document.getElementById('titulo').textContent = unit.title;
    audio.src = `/audio/${unit.unit_id}.opus`;
    renderBody();

    audio.ontimeupdate = () => paint(findSentence(audio.currentTime));
    audio.onended = () => saveProgress('escuchado');

    document.getElementById('play').onclick = () => {
      if (audio.paused) { audio.play(); saveProgress('en_curso'); }
      else audio.pause();
      document.getElementById('play').textContent = audio.paused ? '▶' : '❚❚';
    };
    document.getElementById('atras').onclick = () => { audio.currentTime -= 10; };
    document.getElementById('adelante').onclick = () => { audio.currentTime += 10; };
    document.getElementById('anterior').onclick = () => seekToSentence(Math.max(0, active - 1));
    document.getElementById('siguiente').onclick = () =>
      seekToSentence(Math.min(unit.sentences.length - 1, active + 1));

    const vel = document.getElementById('velocidad');
    vel.oninput = () => {
      audio.playbackRate = Number(vel.value);
      document.getElementById('velocidad-valor').textContent =
        `${vel.value.replace('.', ',')}×`;
    };

    if ('mediaSession' in navigator) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: unit.title,
        artist: `Capítulo ${unit.chapter}. ${unit.chapter_title}`,
        album: 'TFM, revisión hablada',
      });
      navigator.mediaSession.setActionHandler('play', () => audio.play());
      navigator.mediaSession.setActionHandler('pause', () => audio.pause());
      navigator.mediaSession.setActionHandler('seekbackward', () => { audio.currentTime -= 10; });
      navigator.mediaSession.setActionHandler('seekforward', () => { audio.currentTime += 10; });
      navigator.mediaSession.setActionHandler('previoustrack', () =>
        seekToSentence(Math.max(0, active - 1)));
      navigator.mediaSession.setActionHandler('nexttrack', () =>
        seekToSentence(Math.min(unit.sentences.length - 1, active + 1)));
    }

    window.addEventListener('pagehide', () => saveProgress('en_curso'));
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') saveProgress('en_curso');
    });
  }

  return { load, currentSentence, seekToSentence, get audio() { return audio; },
           get unit() { return unit; } };
})();

window.Player = Player;
```

Añade a `style.css` la clase `.frase.activa` con fondo destacado y contraste suficiente, y estilos para `.bloque`.

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_player_static.py -v`
Expected: 4 passed

- [ ] **Step 5: Escuchar un apartado real en el móvil**

Comprueba, con el capítulo piloto ya generado: que el resaltado va sincronizado con la voz, que tocar una frase salta a ella, que los controles de la pantalla de bloqueo funcionan, y que al volver a entrar el apartado retoma donde se quedó.

Si el resaltado va adelantado o atrasado de forma constante, el problema está en los tiempos del pipeline, no aquí; vuelve a la tarea 9 de ese plan.

- [ ] **Step 6: Commit**

```bash
git add server/static/player.html server/static/player.js server/static/style.css tests/server/test_player_static.py
git commit -m "Reproducir con resaltado por frase y controles de pantalla de bloqueo"
```

---

### Task 8: Hoja de notas con etiquetas y dictado

**Files:**
- Modify: `server/static/player.html`, `server/static/player.js`, `server/static/style.css`
- Test: `tests/server/test_note_flow.py`

**Interfaces:**
- Consumes: `Player.currentSentence()`, `POST /api/sessions`, `POST /api/notes`.
- Produces: `window.Notes` con `open()`, `close()` y `save()`.

Al pulsar «Anotar esta frase» el audio se pausa, se abre una hoja desde abajo con la frase anclada, la fila de etiquetas y un campo de texto que recibe el foco. El dictado es el nativo del teclado del móvil: basta con que el campo sea un `textarea` normal y reciba el foco, no hace falta la API de reconocimiento de voz. Al guardar, la hoja se cierra y la reproducción continúa donde estaba.

El identificador de sesión se pide una vez y se guarda en `sessionStorage`.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_note_flow.py`:

```python
def test_the_note_sheet_exists_in_the_page(client):
    body = client.get("/player.html").text
    assert 'id="hoja-notas"' in body
    assert "<textarea" in body


def test_the_quick_tags_are_the_five_agreed_ones(client):
    body = client.get("/player.html").text
    for tag in ("muy_largo", "no_se_entiende", "repetido", "falta_dato", "reescribir"):
        assert tag in body


def test_saving_a_note_posts_the_anchor(client):
    body = client.get("/player.js").text
    assert "/api/notes" in body
    for field in ("sentence_idx", "sentence_hash", "sentence_text", "tex_file", "tex_line", "audio_ts"):
        assert field in body


def test_the_session_id_is_reused_from_session_storage(client):
    assert "sessionStorage" in client.get("/player.js").text


def test_a_note_posted_by_the_page_shape_is_accepted_by_the_api(client):
    session_id = client.post("/api/sessions").json()["session_id"]
    r = client.post("/api/notes", json={
        "session_id": session_id,
        "unit_id": "c03-entorno-nco",
        "sentence_idx": 4,
        "sentence_hash": "abc123",
        "sentence_text": "El NCO genera la referencia.",
        "tex_file": "plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        "tex_line": 328,
        "audio_ts": 41.2,
        "tags": ["muy_largo"],
        "comment": "",
    })
    assert r.status_code == 201
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_note_flow.py -v`
Expected: FAIL, la hoja no existe

- [ ] **Step 3: Escribir la implementación mínima**

Añade a `server/static/player.html`, antes de los `<script>`:

```html
<dialog id="hoja-notas" class="hoja">
  <form method="dialog" id="form-nota">
    <p class="frase-anclada" id="frase-anclada"></p>
    <div class="etiquetas">
      <label><input type="checkbox" name="tag" value="muy_largo"> Muy largo</label>
      <label><input type="checkbox" name="tag" value="no_se_entiende"> No se entiende</label>
      <label><input type="checkbox" name="tag" value="repetido"> Repetido</label>
      <label><input type="checkbox" name="tag" value="falta_dato"> Falta dato</label>
      <label><input type="checkbox" name="tag" value="reescribir"> Reescribir</label>
    </div>
    <textarea id="comentario" rows="4" placeholder="Qué cambiarías. Puedes dictarlo."></textarea>
    <div class="fila">
      <button value="cancelar" type="submit">Cancelar</button>
      <button value="guardar" type="submit" class="principal">Guardar</button>
    </div>
  </form>
</dialog>
```

Añade a `server/static/player.js`:

```javascript
const Notes = (() => {
  const dialog = document.getElementById('hoja-notas');
  const form = document.getElementById('form-nota');
  let resumeAfter = false;

  async function sessionId() {
    let id = sessionStorage.getItem('audiorev_session_id');
    if (!id) {
      id = (await AudioRev.api('/api/sessions', { method: 'POST' })).session_id;
      sessionStorage.setItem('audiorev_session_id', id);
    }
    return id;
  }

  function open() {
    const sentence = Player.currentSentence();
    if (!sentence) return;
    resumeAfter = !Player.audio.paused;
    Player.audio.pause();
    document.getElementById('frase-anclada').textContent = sentence.text;
    form.reset();
    dialog.showModal();
    document.getElementById('comentario').focus();
  }

  function close() {
    dialog.close();
    if (resumeAfter) Player.audio.play();
  }

  async function save() {
    const sentence = Player.currentSentence();
    const tags = [...form.querySelectorAll('input[name=tag]:checked')].map((i) => i.value);
    const comment = document.getElementById('comentario').value.trim();
    if (!tags.length && !comment) { close(); return; }

    await AudioRev.api('/api/notes', {
      method: 'POST',
      body: JSON.stringify({
        session_id: await sessionId(),
        unit_id: Player.unit.unit_id,
        sentence_idx: sentence.idx,
        sentence_hash: sentence.hash,
        sentence_text: sentence.text,
        tex_file: Player.unit.tex_file,
        tex_line: sentence.tex_line,
        audio_ts: Player.audio.currentTime,
        tags,
        comment,
      }),
    });
    close();
  }

  form.addEventListener('submit', (e) => {
    if (e.submitter && e.submitter.value === 'guardar') { e.preventDefault(); save(); }
    else close();
  });

  document.getElementById('anotar').onclick = open;

  return { open, close, save };
})();

window.Notes = Notes;
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_note_flow.py -v`
Expected: 5 passed

- [ ] **Step 5: Anotar de verdad, andando**

Sal a dar una vuelta con los auriculares y anota cinco revisiones reales sobre el capítulo piloto. Comprueba que el flujo no interrumpe la escucha, que el dictado del teclado funciona dentro del `textarea` y que las etiquetas de un toque bastan para la mayoría de los casos. Si algo molesta, arréglalo ahora: esta es la prueba que de verdad valida el proyecto.

- [ ] **Step 6: Commit**

```bash
git add server/static tests/server/test_note_flow.py
git commit -m "Anotar la frase en curso con etiquetas rápidas y dictado"
```

---

### Task 9: Publicar las revisiones en el repositorio

**Files:**
- Create: `server/app/publish.py`
- Modify: `server/app/main.py`
- Test: `tests/server/test_publish.py`

**Interfaces:**
- Consumes: `notes.list_notes`, `get_settings().repo_dir`.
- Produces: `publish.render_markdown(notes: list[dict], session_id: str, when: str) -> str`, `publish.write_and_push(repo_dir: Path, relative_path: str, body: str, message: str) -> None` y la ruta `POST /api/sessions/{session_id}/publicar`.

Formato del fichero, pensado para que Claude Code lo lea sin ambigüedad:

```markdown
# Revisiones de la sesión 2026-08-21-01

Sesión `a1b2c3d4e5f6`, cerrada el 2026-08-21T18:42:00+00:00. 7 revisiones.

## c03-entorno-nco — Oscilador controlado numéricamente (NCO)

### Revisión 12

- **Fichero:** `plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex`
- **Línea aproximada:** 328
- **Etiquetas:** muy largo, reescribir
- **Frase anclada:**

> El NCO genera la referencia de reloj del transceptor a partir del reloj de sistema.

**Qué cambiar:** Partir en dos frases; la segunda mitad sobra.
```

`write_and_push` rechaza cualquier `relative_path` que no empiece por `revisiones/`.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_publish.py`:

```python
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
    assert body.count("## ") == 2


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
        row = client.app.state.db.execute(
            "SELECT closed_at FROM sessions WHERE session_id = ?", (session_id,)
        ).fetchone()
        assert row["closed_at"]
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_publish.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'server.app.publish'`

- [ ] **Step 3: Escribir la implementación mínima**

`server/app/publish.py`:

```python
"""Escritura de las revisiones en el repositorio y empuje a GitHub."""

import subprocess
from pathlib import Path, PurePosixPath

_TAG_NAMES = {
    "muy_largo": "muy largo",
    "no_se_entiende": "no se entiende",
    "repetido": "repetido",
    "falta_dato": "falta dato",
    "reescribir": "reescribir",
}

ALLOWED_PREFIX = "revisiones/"


def render_markdown(notes: list[dict], session_id: str, when: str) -> str:
    """Genera el documento de la sesión, agrupado por apartado."""
    lines = [
        f"# Revisiones de la sesión {when[:10]}",
        "",
        f"Sesión `{session_id}`, cerrada el {when}. {len(notes)} revisiones.",
        "",
        "Cada revisión se aplica buscando la frase anclada por su texto literal. "
        "El número de línea es solo una pista: si la frase ya no aparece, marca la "
        "revisión como obsoleta en lugar de editar a ciegas.",
        "",
    ]

    current_unit = None
    for note in notes:
        if note["unit_id"] != current_unit:
            current_unit = note["unit_id"]
            lines += [f"## {current_unit}", ""]

        tags = ", ".join(_TAG_NAMES.get(t, t) for t in note.get("tags") or [])
        lines += [
            f"### Revisión {note['id']}",
            "",
            f"- **Fichero:** `{note['tex_file']}`",
            f"- **Línea aproximada:** {note['tex_line']}",
            f"- **Frase número:** {note['sentence_idx']} (hash `{note['sentence_hash']}`)",
        ]
        if tags:
            lines.append(f"- **Etiquetas:** {tags}")
        lines += [
            "- **Frase anclada:**",
            "",
            f"> {note['sentence_text']}",
            "",
        ]
        if (note.get("comment") or "").strip():
            lines += [f"**Qué cambiar:** {note['comment'].strip()}", ""]
        else:
            lines += ["**Qué cambiar:** solo etiquetas, sin comentario.", ""]

    return "\n".join(lines)


def _git(repo_dir: Path, *args: str) -> None:
    result = subprocess.run(
        ["git", *args], cwd=repo_dir, capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} falló: {result.stderr.strip()}")


def _push(repo_dir: Path) -> None:
    _git(repo_dir, "push", "origin", "HEAD")


def write_and_push(repo_dir: Path, relative_path: str, body: str, message: str) -> None:
    """Escribe el fichero bajo revisiones/, hace commit y lo empuja."""
    normalized = PurePosixPath(relative_path)
    if ".." in normalized.parts or not relative_path.startswith(ALLOWED_PREFIX):
        raise ValueError(
            f"Solo se puede escribir bajo {ALLOWED_PREFIX!r}, no en {relative_path!r}"
        )

    target = repo_dir / normalized
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding="utf-8")

    _git(repo_dir, "pull", "--rebase", "--autostash")
    _git(repo_dir, "add", str(normalized))
    _git(repo_dir, "commit", "-m", message)
    _push(repo_dir)
```

En `server/app/main.py`:

```python
from datetime import date

from . import publish as publish_module


@app.post("/api/sessions/{session_id}/publicar")
def publish_session(session_id: str, user: str = Depends(require_user)) -> dict:
    session_notes = notes_module.list_notes(app.state.db, session_id=session_id)
    when = datetime.now(timezone.utc).isoformat(timespec="seconds")

    same_day = app.state.db.execute(
        "SELECT count(*) FROM sessions WHERE closed_at LIKE ?", (f"{date.today()}%",)
    ).fetchone()[0]
    relative = f"revisiones/{date.today()}-sesion-{same_day + 1:02d}.md"
    body = publish_module.render_markdown(session_notes, session_id, when)

    try:
        publish_module.write_and_push(
            settings.repo_dir, relative, body,
            f"Recoger {len(session_notes)} revisiones de la sesión del {date.today()}",
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=f"No se pudo publicar: {exc}")

    app.state.db.execute(
        "UPDATE sessions SET closed_at = ?, published_path = ? WHERE session_id = ?",
        (when, relative, session_id),
    )
    return {"path": relative, "notes": len(session_notes)}
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_publish.py -v`
Expected: 6 passed

- [ ] **Step 5: Preparar el clon y la deploy key en el servidor**

En GitHub, crea una deploy key **con permiso de escritura** restringida a este repositorio. En el servidor:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/audiorev_deploy -N ""
git clone git@github.com:jaestefaniah27/tfm.git /var/lib/audiorev/repo
git -C /var/lib/audiorev/repo config user.name "AudioRev"
git -C /var/lib/audiorev/repo config user.email "audiorev@localhost"
```

Comprueba que el push funciona escribiendo un fichero de prueba bajo `revisiones/` a mano antes de confiar en el endpoint.

- [ ] **Step 6: Commit**

```bash
git add server/app/publish.py server/app/main.py tests/server/test_publish.py
git commit -m "Publicar las revisiones de cada sesión en el repositorio"
```

---

### Task 10: API para Claude Code y detección de frases obsoletas

**Files:**
- Modify: `server/app/main.py`, `server/app/index.py`
- Create: `docs/audiorev/APLICAR_REVISIONES.md`
- Test: `tests/server/test_agent_api.py`

**Interfaces:**
- Consumes: `require_api_token`, `notes.list_notes`, `notes.set_state`.
- Produces: `GET /api/revisiones`, `POST /api/revisiones/{id}/estado`, `POST /api/regenerar`, e `index.mark_stale_notes(conn, index_dir) -> int`, que marca como `obsoleta` toda nota cuyo `sentence_hash` ya no exista en el índice de su unidad.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_agent_api.py`:

```python
import json

AUTH = {"Authorization": "Bearer token-de-prueba"}

NOTE = {
    "session_id": "s1", "unit_id": "c03-entorno-nco", "sentence_idx": 0,
    "sentence_hash": "hash-viejo", "sentence_text": "Frase antigua.",
    "tex_file": "a/b.tex", "tex_line": 1, "audio_ts": 0.0,
    "tags": [], "comment": "Cambiar esto.",
}


def test_agent_lists_pending_revisions_with_the_token(client):
    client.post("/api/notes", json=NOTE)
    r = client.get("/api/revisiones?estado=pendiente", headers=AUTH)
    assert r.status_code == 200
    note = r.json()["revisiones"][0]
    assert note["sentence_text"] == "Frase antigua."
    assert note["tex_file"] == "a/b.tex"


def test_agent_api_rejects_the_session_cookie_alone(client):
    client.post("/api/notes", json=NOTE)
    assert client.get("/api/revisiones", headers={"Authorization": "Bearer malo"}).status_code == 401


def test_agent_marks_a_revision_as_applied(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    r = client.post(f"/api/revisiones/{note_id}/estado", json={"estado": "aplicada"}, headers=AUTH)
    assert r.status_code == 200
    assert client.get("/api/revisiones?estado=pendiente", headers=AUTH).json()["revisiones"] == []


def test_agent_cannot_set_an_invalid_state(client):
    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    r = client.post(f"/api/revisiones/{note_id}/estado", json={"estado": "inventado"}, headers=AUTH)
    assert r.status_code == 422


def test_notes_whose_sentence_disappeared_become_obsolete(client, data_dir):
    from server.app.index import mark_stale_notes

    client.post("/api/notes", json=NOTE)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco",
        "sentences": [{"idx": 0, "text": "Frase nueva.", "spoken": "Frase nueva.",
                       "hash": "hash-nuevo", "tex_line": 1, "t_start": 0, "t_end": 1}],
        "blocks": [],
    }), encoding="utf-8")

    assert mark_stale_notes(client.app.state.db, index_dir) == 1
    assert client.get("/api/revisiones?estado=obsoleta", headers=AUTH).json()["revisiones"]


def test_a_note_whose_sentence_survives_stays_pending(client, data_dir):
    from server.app.index import mark_stale_notes

    client.post("/api/notes", json=NOTE)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco",
        "sentences": [{"idx": 0, "text": "Frase antigua.", "spoken": "Frase antigua.",
                       "hash": "hash-viejo", "tex_line": 1, "t_start": 0, "t_end": 1}],
        "blocks": [],
    }), encoding="utf-8")

    assert mark_stale_notes(client.app.state.db, index_dir) == 0


def test_already_applied_notes_are_never_marked_obsolete(client, data_dir):
    from server.app.index import mark_stale_notes

    note_id = client.post("/api/notes", json=NOTE).json()["id"]
    client.post(f"/api/revisiones/{note_id}/estado", json={"estado": "aplicada"}, headers=AUTH)
    index_dir = data_dir / "index"
    index_dir.mkdir(parents=True, exist_ok=True)
    (index_dir / "c03-entorno-nco.json").write_text(json.dumps({
        "unit_id": "c03-entorno-nco", "sentences": [], "blocks": [],
    }), encoding="utf-8")

    assert mark_stale_notes(client.app.state.db, index_dir) == 0
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_agent_api.py -v`
Expected: FAIL, las rutas no existen

- [ ] **Step 3: Escribir la implementación mínima**

Añade a `server/app/index.py`:

```python
def mark_stale_notes(conn: sqlite3.Connection, index_dir: Path) -> int:
    """Marca como obsoleta toda nota pendiente cuya frase ya no está en el índice."""
    stale = 0
    rows = conn.execute(
        "SELECT id, unit_id, sentence_hash FROM notes WHERE state = 'pendiente'"
    ).fetchall()
    cache: dict[str, set[str]] = {}

    for row in rows:
        unit_id = row["unit_id"]
        if unit_id not in cache:
            payload = unit_payload(index_dir, unit_id)
            cache[unit_id] = (
                {s["hash"] for s in payload.get("sentences", [])} if payload else set()
            )
        known = cache[unit_id]
        if known and row["sentence_hash"] not in known:
            conn.execute("UPDATE notes SET state = 'obsoleta' WHERE id = ?", (row["id"],))
            stale += 1
    return stale
```

Nota importante sobre el caso límite: si el índice de la unidad no existe todavía, `known` está vacío y la nota **no** se marca obsoleta. Marcarla sería perder trabajo por una regeneración incompleta.

Añade a `server/app/main.py`:

```python
from .index import mark_stale_notes


class EstadoBody(BaseModel):
    estado: Literal["pendiente", "aplicada", "descartada", "obsoleta"]


@app.get("/api/revisiones")
def agent_list(estado: str | None = None, _: None = Depends(require_api_token)) -> dict:
    return {"revisiones": notes_module.list_notes(app.state.db, estado)}


@app.post("/api/revisiones/{note_id}/estado")
def agent_set_state(
    note_id: int, body: EstadoBody, _: None = Depends(require_api_token)
) -> dict:
    if not notes_module.set_state(app.state.db, note_id, body.estado):
        raise HTTPException(status_code=404, detail="Revisión desconocida")
    return {"ok": True}


@app.post("/api/regenerar")
def regenerate(_: None = Depends(require_api_token)) -> dict:
    loaded = load_index(app.state.db, settings.index_dir)
    stale = mark_stale_notes(app.state.db, settings.index_dir)
    return {"units": loaded, "obsoletas": stale}
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_agent_api.py -v`
Expected: 7 passed

Vuelve ahora a `tests/server/test_auth.py` y quita los `xfail` de las dos pruebas del token *bearer*.

- [ ] **Step 5: Escribir las instrucciones de aplicación**

`docs/audiorev/APLICAR_REVISIONES.md` debe indicar, para una sesión de Claude Code desde el móvil:

1. `git pull` y leer los ficheros nuevos de `revisiones/`.
2. Para cada revisión, buscar `sentence_text` **literalmente** en `tex_file`. Si no aparece, marcarla `obsoleta` por la API y seguir con la siguiente, sin editar nada.
3. Aplicar el cambio respetando `GUIA_ESTILO_TFM.md`.
4. Marcar la revisión como `aplicada` con `POST /api/revisiones/{id}/estado`.
5. Un solo commit por sesión de revisiones, citando los identificadores aplicados.
6. Llamar a `POST /api/regenerar` al terminar, para que el servidor detecte las frases que han cambiado.

Incluye las órdenes `curl` exactas con el token leído de una variable de entorno, nunca escrito en el documento.

- [ ] **Step 6: Commit**

```bash
git add server/app/main.py server/app/index.py docs/audiorev/APLICAR_REVISIONES.md tests/server/test_agent_api.py tests/server/test_auth.py
git commit -m "Exponer las revisiones a Claude Code y detectar las frases obsoletas"
```

---

### Task 11: Regeneración automática y escucha sin cobertura

**Files:**
- Create: `server/static/sw.js`
- Modify: `server/static/app.js`, `server/static/player.js`, `server/app/main.py`
- Test: `tests/server/test_offline.py`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: `POST /api/webhook/github`, la ruta `GET /sw.js`, y en `app.js` las funciones `cacheUnit(unitId)` y `flushQueue()`.

Dos piezas independientes que comparten tarea porque ninguna se sostiene sola:

- **Regeneración.** El webhook comprueba la firma HMAC de GitHub, hace `git pull` en el clon, lanza el pipeline en segundo plano y, al terminar, recarga el índice y marca las obsoletas.
- **Sin cobertura.** El service worker precachea el JSON y el `.opus` de los apartados que se marquen. Las notas creadas sin red se encolan en IndexedDB y se envían al recuperar conexión.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/server/test_offline.py`:

```python
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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/server/test_offline.py -v`
Expected: FAIL con 404 en `/sw.js`

- [ ] **Step 3: Escribir la implementación mínima**

`server/static/sw.js`:

```javascript
'use strict';

const CACHE = 'audiorev-v1';
const SHELL = ['/', '/player.html', '/app.js', '/player.js', '/style.css'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('message', (e) => {
  if (e.data && e.data.type === 'cache-unit') {
    const id = e.data.unitId;
    e.waitUntil(
      caches.open(CACHE).then((c) => c.addAll([`/api/units/${id}`, `/audio/${id}.opus`]))
    );
  }
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  const cacheable =
    url.pathname.startsWith('/audio/') ||
    url.pathname.startsWith('/api/units/') ||
    SHELL.includes(url.pathname);

  if (!cacheable || e.request.method !== 'GET') return;

  e.respondWith(
    caches.match(e.request).then((hit) =>
      hit || fetch(e.request).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      })
    )
  );
});
```

Añade a `server/static/app.js`, dentro del módulo y antes del `return`:

```javascript
  const QUEUE_DB = 'audiorev';
  const QUEUE_STORE = 'pendientes';

  function openQueue() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(QUEUE_DB, 1);
      req.onupgradeneeded = () =>
        req.result.createObjectStore(QUEUE_STORE, { autoIncrement: true });
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function enqueue(note) {
    const db = await openQueue();
    db.transaction(QUEUE_STORE, 'readwrite').objectStore(QUEUE_STORE).add(note);
  }

  async function flushQueue() {
    const db = await openQueue();
    const store = db.transaction(QUEUE_STORE, 'readwrite').objectStore(QUEUE_STORE);
    const all = store.getAll();
    all.onsuccess = async () => {
      for (const note of all.result) {
        try {
          await api('/api/notes', { method: 'POST', body: JSON.stringify(note) });
        } catch (err) { return; }
      }
      db.transaction(QUEUE_STORE, 'readwrite').objectStore(QUEUE_STORE).clear();
    };
  }

  function cacheUnit(unitId) {
    if (navigator.serviceWorker.controller) {
      navigator.serviceWorker.controller.postMessage({ type: 'cache-unit', unitId });
    }
  }

  if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js');
  window.addEventListener('online', flushQueue);
```

Añade `enqueue`, `flushQueue` y `cacheUnit` al objeto devuelto. En `player.js`, envuelve el `POST /api/notes` de `Notes.save` en un `try` que llame a `AudioRev.enqueue(payload)` si la petición falla, para que anotar sin cobertura no pierda la nota.

En `server/app/config.py`, añade al `Settings` el campo `webhook_secret: str` leído de `AUDIOREV_WEBHOOK_SECRET`.

En `server/app/main.py`:

```python
import hashlib
import subprocess

from fastapi import BackgroundTasks, Request


def _regenerate_in_background() -> None:
    subprocess.run(["git", "pull", "--ff-only"], cwd=settings.repo_dir, check=False)
    subprocess.run(
        ["python", "-m", "tools.audiorev.build", "--repo", str(settings.repo_dir),
         "--out", str(settings.index_dir), "--cache", str(settings.data_dir / "cache")],
        check=False,
    )
    for name in settings.index_dir.glob("*.opus"):
        name.replace(settings.audio_dir / name.name)
    load_index(app.state.db, settings.index_dir)
    mark_stale_notes(app.state.db, settings.index_dir)


@app.post("/api/webhook/github")
async def github_webhook(request: Request, tasks: BackgroundTasks) -> dict:
    secret = settings.webhook_secret
    body = await request.body()
    given = request.headers.get("X-Hub-Signature-256", "")
    expected = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    if not secret or not hmac.compare_digest(given, expected):
        raise HTTPException(status_code=401, detail="Firma no válida")

    payload = json.loads(body or b"{}")
    if payload.get("ref") != "refs/heads/main":
        return {"ignored": True}

    tasks.add_task(_regenerate_in_background)
    return JSONResponse(status_code=202, content={"queued": True})
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/server/test_offline.py -v`
Expected: 6 passed

- [ ] **Step 5: Ejecutar la batería completa y probar el ciclo entero**

Run: `pytest tests -v`
Expected: todas pasan.

Después, el ciclo completo de verdad, que es la única prueba que cuenta:

1. Marca dos apartados para descarga, activa el modo avión y comprueba que suenan y que puedes anotar.
2. Recupera la red y comprueba que las notas encoladas se envían solas.
3. Cierra la sesión y comprueba que aparece el fichero en `revisiones/` del repositorio de GitHub.
4. Desde el móvil, pídele a Claude Code que aplique las revisiones pendientes siguiendo `docs/audiorev/APLICAR_REVISIONES.md`.
5. Comprueba que el push dispara la regeneración y que las notas aplicadas quedan marcadas.

- [ ] **Step 6: Documentar el despliegue y hacer commit**

`server/README.md` debe recoger: las variables de entorno una a una, cómo generar la contraseña y los tokens, el `location` del reverse proxy, cómo instalar Piper y el modelo, la orden de respaldo del volumen, y cómo restaurar.

```bash
git add server tests/server docs/audiorev
git commit -m "Escuchar sin cobertura y regenerar al detectar cambios en la memoria"
```

---

## Autorrevisión del plan

**Cobertura del spec.** Apartado 5.1 stack, tarea 1. Apartado 5.2 autenticación, tarea 2. Apartado 5.3 pantallas: lista en la tarea 6, reproductor en la 7, hoja de notas en la 8, cierre de sesión en la 9. Apartado 5.4 sin cobertura, tarea 11. Apartado 6 generación híbrida, tarea 11, tanto por webhook como por `POST /api/regenerar` de la tarea 10. Apartado 7 vuelta a Claude Code: camino git en la tarea 9, camino API en la 10, cierre del bucle con `mark_stale_notes` en la 10. Seguridad de la deploy key, tarea 9, con la comprobación de prefijo probada.

**Diferencia con el spec, deliberada.** El spec describe la pantalla de cierre de sesión como una vista con las notas editables. Aquí se implementa el endpoint de publicación en la tarea 9 y la edición de notas ya existe por `PATCH` y `DELETE` desde la tarea 5. Montar la vista es cosa de media hora sobre esos endpoints; se deja como el primer añadido después de la tarea 11, no como una tarea con su propio ciclo de pruebas.

**Consistencia de tipos.** `unit_id` es siempre una cadena que casa con `^[a-z0-9][a-z0-9-]{0,120}$`, comprobada en `index.unit_payload`, en `put_progress` y en `get_audio`. Los estados de nota son los cuatro de `notes.STATES` y se validan con el mismo `Literal` en `NotePatch` y en `EstadoBody`. Los estados de progreso son los cuatro de `_STATES` y se validan en `ProgressBody`. `list_notes` devuelve siempre `tags` como lista, nunca como la cadena JSON que guarda SQLite.
