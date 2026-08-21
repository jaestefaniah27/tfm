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
