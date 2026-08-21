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
