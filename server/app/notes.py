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
