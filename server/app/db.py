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
