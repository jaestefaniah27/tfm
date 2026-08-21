"""Conexión y esquema de la base de datos SQLite."""

import sqlite3
from contextlib import contextmanager
from typing import Iterator

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


def _configure(conn: sqlite3.Connection) -> sqlite3.Connection:
    """Aplica los PRAGMA comunes a cualquier conexión nueva.

    WAL permite lectores concurrentes con un único escritor; busy_timeout
    hace que una escritura concurrente espere en vez de fallar de inmediato
    con "database is locked" cuando otra petición está escribiendo.
    """
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.isolation_level = None
    return conn


def connect() -> sqlite3.Connection:
    """Conexión de larga duración, pensada para arranque (migrar, cargar el
    índice) y para las pruebas que necesitan reutilizar la misma conexión."""
    settings = get_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.db_path, check_same_thread=False)
    return _configure(conn)


@contextmanager
def session() -> Iterator[sqlite3.Connection]:
    """Conexión de corta duración, una por operación/petición.

    Se elige esta forma (en vez de una única conexión compartida protegida
    por un lock de Python) porque FastAPI ejecuta las rutas síncronas en un
    threadpool: con una conexión por hilo, SQLite en modo WAL más
    busy_timeout ya serializa las escrituras concurrentes dentro del propio
    motor, sin necesidad de coordinar un lock adicional en Python y sin
    limitar la concurrencia de lectura a un único hilo a la vez.
    """
    settings = get_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.db_path, check_same_thread=True)
    _configure(conn)
    try:
        yield conn
    finally:
        conn.close()


def get_db() -> Iterator[sqlite3.Connection]:
    """Dependencia de FastAPI: entrega una conexión por petición y la cierra
    al terminar, ocurra o no un error en la ruta."""
    with session() as conn:
        yield conn


def migrate(conn: sqlite3.Connection) -> None:
    conn.executescript(_SCHEMA)
