"""Pruebas de la conexión y el esquema de la base de datos SQLite."""

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
