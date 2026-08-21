"""Prueba de concurrencia: varias escrituras simultáneas contra la misma
base de datos SQLite deben aterrizar todas y de forma consistente."""

import threading

from server.app import db


def test_concurrent_writes_all_land_consistently(data_dir):
    conn = db.connect()
    db.migrate(conn)
    conn.close()

    n = 25
    errors = []

    def write(i: int) -> None:
        try:
            with db.session() as c:
                c.execute(
                    "INSERT INTO progress (unit_id, state, position_s) VALUES (?, 'escuchado', ?)",
                    (f"unit-{i}", float(i)),
                )
        except Exception as exc:  # se recoge para que el hilo no lo trague en silencio
            errors.append(exc)

    threads = [threading.Thread(target=write, args=(i,)) for i in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert errors == []

    with db.session() as c:
        rows = c.execute("SELECT unit_id, position_s FROM progress ORDER BY unit_id").fetchall()

    assert len(rows) == n
    seen = {r["unit_id"]: r["position_s"] for r in rows}
    for i in range(n):
        assert seen[f"unit-{i}"] == float(i)


def test_concurrent_updates_to_the_same_row_do_not_lose_writes(data_dir):
    """Muchos incrementos concurrentes sobre la misma fila no deben perder
    ninguno: SQLite (WAL + busy_timeout) serializa las escrituras."""
    conn = db.connect()
    db.migrate(conn)
    conn.execute(
        "INSERT INTO progress (unit_id, state, position_s) VALUES ('u1', 'escuchado', 0)"
    )
    conn.close()

    n = 25
    errors = []

    def bump() -> None:
        try:
            with db.session() as c:
                c.execute("UPDATE progress SET position_s = position_s + 1 WHERE unit_id = 'u1'")
        except Exception as exc:
            errors.append(exc)

    threads = [threading.Thread(target=bump) for _ in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert errors == []
    with db.session() as c:
        row = c.execute("SELECT position_s FROM progress WHERE unit_id = 'u1'").fetchone()
    assert row["position_s"] == n
