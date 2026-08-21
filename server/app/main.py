"""Aplicación FastAPI de AudioRev."""

import re
import sqlite3
from datetime import datetime, timezone
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Response, status
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, model_validator

from . import db as db_module
from . import notes as notes_module
from .auth import COOKIE, MAX_AGE, issue_session, require_api_token, require_user, verify_password
from .config import get_settings
from .index import load_index, unit_payload

VERSION = "0.1.0"

_SAFE_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,120}$")


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
    def login(body: LoginBody, response: Response) -> dict:
        if settings.trust_proxy_user:
            raise HTTPException(status_code=404, detail="No disponible en modo proxy")
        if not verify_password(body.password, settings.password_hash):
            raise HTTPException(status_code=401, detail="Contraseña incorrecta")
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

    @app.put("/api/progress/{unit_id}")
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

    @app.delete("/api/notes/{note_id}", status_code=204)
    def delete_note(note_id: int, user: str = Depends(require_user),
                     conn: sqlite3.Connection = Depends(db_module.get_db)) -> Response:
        if not notes_module.delete(conn, note_id):
            raise HTTPException(status_code=404, detail="Revisión desconocida")
        return Response(status_code=status.HTTP_204_NO_CONTENT)

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
    app.mount("/", StaticFiles(directory="server/static", html=True), name="static")

    return app


app = create_app()
