"""Aplicación FastAPI de AudioRev."""

import hashlib
import hmac
import json
import re
import sqlite3
import subprocess
import threading
import time
from collections import defaultdict, deque
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Literal

from fastapi import BackgroundTasks, Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, model_validator

from . import db as db_module
from . import notes as notes_module
from . import publish as publish_module
from .auth import COOKIE, MAX_AGE, issue_session, require_api_token, require_user, verify_password
from .config import get_settings
from .index import load_index, mark_stale_notes, unit_payload

VERSION = "0.1.0"

_SAFE_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,120}$")

# Límite de intentos de /login: ventana deslizante en memoria, por IP. Es
# una aplicación de un solo usuario, así que no necesita Redis ni ningún
# almacén compartido; basta con recordar los fallos recientes del proceso.
LOGIN_MAX_FAILS = 5
LOGIN_WINDOW_S = 300.0
_login_fails: dict[str, deque] = defaultdict(deque)
_login_lock = threading.Lock()

# Una sola regeneración a la vez en todo el proceso (ver
# _regenerate_in_background).
_regen_lock = threading.Lock()


def _run_step(argv: list[str], cwd=None) -> int:
    """Ejecuta un paso de la regeneración y DEJA RASTRO en la salida
    estándar cuando falla, para que `docker logs` lo muestre.

    Antes era un `subprocess.run(..., check=False)` mudo: si faltaban las
    dependencias del pipeline o Piper, cada entrega del webhook fallaba al
    instante y en silencio."""
    result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(
            f"[audiorev] falló {' '.join(argv)} (código {result.returncode}): "
            f"{(result.stderr or result.stdout or '').strip()[:2000]}",
            flush=True,
        )
    return result.returncode


def _login_client_ip(request: Request) -> str:
    """IP del cliente, respetando X-Forwarded-For porque siempre se sirve
    detrás de Caddy (que la fija y sobrescribe)."""
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "desconocido"


def _login_blocked(ip: str) -> bool:
    """True si esa IP ya ha agotado los intentos de la ventana actual."""
    now = time.monotonic()
    with _login_lock:
        fails = _login_fails[ip]
        while fails and now - fails[0] > LOGIN_WINDOW_S:
            fails.popleft()
        return len(fails) >= LOGIN_MAX_FAILS


def _login_record_failure(ip: str) -> None:
    with _login_lock:
        _login_fails[ip].append(time.monotonic())


def _login_reset(ip: str) -> None:
    with _login_lock:
        _login_fails.pop(ip, None)


class LoginBody(BaseModel):
    password: str


class ProgressBody(BaseModel):
    state: Literal["pendiente", "en_curso", "escuchado", "con_notas"]
    position_s: float = 0.0


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


class EstadoBody(BaseModel):
    estado: Literal["pendiente", "aplicada", "descartada", "obsoleta"]


def create_app() -> FastAPI:
    settings = get_settings()
    settings.index_dir.mkdir(parents=True, exist_ok=True)
    settings.audio_dir.mkdir(parents=True, exist_ok=True)

    app = FastAPI(title="AudioRev", version=VERSION, docs_url=None, redoc_url=None)

    # Conexión de arranque de corta vida: migra y carga el índice, y se
    # cierra de inmediato. Las peticiones usan conexiones por petición
    # (db.get_db / db.session), así que no queda ninguna conexión abierta
    # de forma indefinida en app.state.
    startup_conn = db_module.connect()
    try:
        db_module.migrate(startup_conn)
        load_index(startup_conn, settings.index_dir)
    finally:
        startup_conn.close()

    @app.get("/healthz")
    def healthz() -> dict:
        return {"status": "ok", "version": VERSION}

    @app.post("/login")
    def login(body: LoginBody, request: Request, response: Response) -> dict:
        if settings.trust_proxy_user:
            raise HTTPException(status_code=404, detail="No disponible en modo proxy")
        ip = _login_client_ip(request)
        if _login_blocked(ip):
            raise HTTPException(
                status_code=429,
                detail="Demasiados intentos fallidos. Espera unos minutos.",
            )
        if not verify_password(body.password, settings.password_hash):
            _login_record_failure(ip)
            raise HTTPException(status_code=401, detail="Contraseña incorrecta")
        _login_reset(ip)
        response.set_cookie(
            COOKIE, issue_session(), max_age=MAX_AGE,
            httponly=True, secure=settings.cookie_secure, samesite="lax", path="/",
        )
        return {"ok": True}

    @app.post("/logout")
    def logout(response: Response) -> dict:
        response.delete_cookie(COOKIE, path="/")
        return {"ok": True}

    @app.get("/api/me")
    def me(user: str = Depends(require_user)) -> dict:
        return {"user": user}

    @app.post("/api/reload")
    def reload_index(_: None = Depends(require_api_token),
                      conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        n = load_index(conn, settings.index_dir)
        return {"loaded": n}

    @app.get("/api/units")
    def list_units(user: str = Depends(require_user),
                    conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        rows = conn.execute(
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

    # Se acepta tanto PUT como POST con el mismo cuerpo y el mismo efecto:
    # `navigator.sendBeacon` (lo que usa el reproductor para guardar el
    # avance al pasar a segundo plano) SIEMPRE envía POST y no permite
    # elegir el método, así que sin esta ruta todo guardado por beacon se
    # perdía con un 405 silencioso.
    @app.put("/api/progress/{unit_id}")
    @app.post("/api/progress/{unit_id}")
    def put_progress(unit_id: str, body: ProgressBody, user: str = Depends(require_user),
                      conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        if not _SAFE_ID.match(unit_id):
            raise HTTPException(status_code=400, detail="Identificador no válido")
        conn.execute(
            """
            INSERT INTO progress (unit_id, state, position_s, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(unit_id) DO UPDATE SET
              state=excluded.state, position_s=excluded.position_s, updated_at=excluded.updated_at
            """,
            (unit_id, body.state, body.position_s, datetime.now(timezone.utc).isoformat()),
        )
        return {"ok": True}

    @app.post("/api/sessions", status_code=201)
    def new_session(user: str = Depends(require_user),
                     conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        return {"session_id": notes_module.open_session(conn)}

    @app.post("/api/notes", status_code=201)
    def post_note(body: NoteBody, user: str = Depends(require_user),
                  conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        return {"id": notes_module.create(conn, body.model_dump())}

    @app.get("/api/notes")
    def get_notes(estado: str | None = None, sesion: str | None = None,
                  user: str = Depends(require_user),
                  conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        return {"notes": notes_module.list_notes(conn, estado, sesion)}

    @app.patch("/api/notes/{note_id}")
    def patch_note(note_id: int, body: NotePatch, user: str = Depends(require_user),
                    conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        touched = False
        if body.state:
            touched |= notes_module.set_state(conn, note_id, body.state)
        if body.comment is not None:
            touched |= notes_module.set_comment(conn, note_id, body.comment)
        if not touched:
            raise HTTPException(status_code=404, detail="Revisión desconocida")
        return {"ok": True}

    @app.post("/api/sessions/{session_id}/publicar")
    def publish_session(session_id: str, user: str = Depends(require_user),
                         conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        session_notes = notes_module.list_notes(conn, session_id=session_id)
        when = datetime.now(timezone.utc).isoformat(timespec="seconds")

        same_day = conn.execute(
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

        # UPSERT y no UPDATE: si la sesión se creó en el cliente (el
        # `crypto.randomUUID()` de cuando se anota sin cobertura) nunca
        # hubo fila en `sessions`, y un UPDATE se quedaba en un no-op
        # silencioso que dejaba la sesión sin cerrar para siempre.
        conn.execute(
            """
            INSERT INTO sessions (session_id, started_at, closed_at, published_path)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
              closed_at=excluded.closed_at, published_path=excluded.published_path
            """,
            (session_id, when, when, relative),
        )
        return {"path": relative, "notes": len(session_notes)}

    @app.delete("/api/notes/{note_id}", status_code=204)
    def delete_note(note_id: int, user: str = Depends(require_user),
                     conn: sqlite3.Connection = Depends(db_module.get_db)) -> Response:
        if not notes_module.delete(conn, note_id):
            raise HTTPException(status_code=404, detail="Revisión desconocida")
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.get("/api/revisiones")
    def agent_list(estado: str | None = None, _: None = Depends(require_api_token),
                    conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        return {"revisiones": notes_module.list_notes(conn, estado)}

    @app.post("/api/revisiones/{note_id}/estado")
    def agent_set_state(note_id: int, body: EstadoBody, _: None = Depends(require_api_token),
                         conn: sqlite3.Connection = Depends(db_module.get_db)) -> dict:
        if not notes_module.set_state(conn, note_id, body.estado):
            raise HTTPException(status_code=404, detail="Revisión desconocida")
        return {"ok": True}

    @app.post("/api/regenerar", status_code=202)
    def regenerate(tasks: BackgroundTasks, _: None = Depends(require_api_token)) -> dict:
        # Antes sólo recargaba el índice de disco: no regeneraba nada, pese
        # a que APLICAR_REVISIONES.md la llama justo después de empujar el
        # .tex corregido esperando audio nuevo. Ahora encola exactamente el
        # mismo trabajo que el webhook (git pull + build + recarga + notas
        # obsoletas) en vez de duplicar la invocación del pipeline. Se
        # encola en segundo plano, como el webhook, porque una regeneración
        # completa dura minutos y no cabe en una petición síncrona.
        tasks.add_task(_regenerate_in_background)
        return {"queued": True}

    def _regenerate_in_background() -> None:
        """Se ejecuta tras un push a main: actualiza el clon, regenera el
        audio y el índice, y marca como obsoletas las notas ancladas a
        frases que hayan cambiado. Abre su propia conexión de corta
        duración porque corre fuera de cualquier petición (BackgroundTasks
        no tiene un Depends que la entregue)."""
        # Si el clon aún no existe (por ejemplo en pruebas, donde no se
        # prepara), se ignora en vez de tumbar la tarea de fondo: check=False
        # ya cubre que el propio "git pull" falle, pero un cwd inexistente
        # lanza OSError antes incluso de llegar a ejecutar el proceso.
        # Guardia contra regeneraciones simultáneas: dos entregas del
        # webhook seguidas compartirían el mismo clon, el mismo índice y la
        # misma caché de TTS. La segunda se descarta (no se encola: el
        # trabajo es idempotente, la que está en curso ya recogerá el
        # último estado del repositorio tras su `git pull`).
        if not _regen_lock.acquire(blocking=False):
            print("[audiorev] regeneración ya en curso, se omite esta entrega", flush=True)
            return
        try:
            if settings.repo_dir.exists():
                _run_step(["git", "pull", "--ff-only"], cwd=settings.repo_dir)
                _run_step(
                    ["python", "-m", "tools.audiorev.build", "--repo", str(settings.repo_dir),
                     "--out", str(settings.index_dir),
                     "--cache", str(settings.data_dir / "cache")],
                )
            else:
                print(f"[audiorev] no existe el clon {settings.repo_dir}, no se regenera",
                      flush=True)
            for name in settings.index_dir.glob("*.opus"):
                name.replace(settings.audio_dir / name.name)
            with db_module.session() as conn:
                load_index(conn, settings.index_dir)
                mark_stale_notes(conn, settings.index_dir)
        finally:
            _regen_lock.release()

    @app.post("/api/webhook/github")
    async def github_webhook(request: Request, tasks: BackgroundTasks) -> dict:
        # No lleva require_user ni require_api_token: la propia firma HMAC
        # es su autenticación. Se relee get_settings() (en vez de usar el
        # `settings` cerrado sobre create_app) para que un secreto fijado
        # después de arrancar la app —como en las pruebas— se tenga en
        # cuenta sin reiniciar el proceso.
        secret = get_settings().webhook_secret
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

    @app.get("/audio/{filename}")
    def get_audio(filename: str, user: str = Depends(require_user)) -> FileResponse:
        if not filename.endswith(".opus") or not _SAFE_ID.match(filename[:-5]):
            raise HTTPException(status_code=400, detail="Nombre no válido")
        path = settings.audio_dir / filename
        if not path.exists():
            raise HTTPException(status_code=404, detail="Audio no disponible")
        return FileResponse(path, media_type="audio/ogg")

    # El frontend estático (lista, reproductor, hoja de notas) se sirve al
    # final para no tapar ninguna ruta de la API definida más arriba.
    # La ruta se resuelve a partir de este fichero, no del directorio de
    # trabajo: el proceso no siempre arranca desde la raíz del repositorio.
    static_dir = Path(__file__).resolve().parents[1] / "static"
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")

    return app


app = create_app()
