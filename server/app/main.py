"""Aplicación FastAPI de AudioRev."""

from fastapi import Depends, FastAPI, HTTPException, Response
from pydantic import BaseModel

from .auth import COOKIE, MAX_AGE, issue_session, require_user, verify_password
from .config import get_settings

VERSION = "0.1.0"


class LoginBody(BaseModel):
    password: str


def create_app() -> FastAPI:
    settings = get_settings()
    settings.index_dir.mkdir(parents=True, exist_ok=True)
    settings.audio_dir.mkdir(parents=True, exist_ok=True)

    app = FastAPI(title="AudioRev", version=VERSION, docs_url=None, redoc_url=None)

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

    return app


app = create_app()
