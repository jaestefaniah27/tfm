"""Escritura de las revisiones en el repositorio y empuje a GitHub."""

import subprocess
from pathlib import Path, PurePosixPath

_TAG_NAMES = {
    "muy_largo": "muy largo",
    "no_se_entiende": "no se entiende",
    "repetido": "repetido",
    "falta_dato": "falta dato",
    "reescribir": "reescribir",
}

ALLOWED_PREFIX = "revisiones/"


def render_markdown(notes: list[dict], session_id: str, when: str) -> str:
    """Genera el documento de la sesión, agrupado por apartado."""
    lines = [
        f"# Revisiones de la sesión {when[:10]}",
        "",
        f"Sesión `{session_id}`, cerrada el {when}. {len(notes)} revisiones.",
        "",
        "Cada revisión se aplica buscando la frase anclada por su texto literal. "
        "El número de línea es solo una pista: si la frase ya no aparece, marca la "
        "revisión como obsoleta en lugar de editar a ciegas.",
        "",
    ]

    current_unit = None
    for note in notes:
        if note["unit_id"] != current_unit:
            current_unit = note["unit_id"]
            lines += [f"## {current_unit}", ""]

        tags = ", ".join(_TAG_NAMES.get(t, t) for t in note.get("tags") or [])
        lines += [
            f"### Revisión {note['id']}",
            "",
            f"- **Fichero:** `{note['tex_file']}`",
            f"- **Línea aproximada:** {note['tex_line']}",
            f"- **Frase número:** {note['sentence_idx']} (hash `{note['sentence_hash']}`)",
        ]
        if tags:
            lines.append(f"- **Etiquetas:** {tags}")
        lines += [
            "- **Frase anclada:**",
            "",
            f"> {note['sentence_text']}",
            "",
        ]
        if (note.get("comment") or "").strip():
            lines += [f"**Qué cambiar:** {note['comment'].strip()}", ""]
        else:
            lines += ["**Qué cambiar:** solo etiquetas, sin comentario.", ""]

    return "\n".join(lines)


def _git(repo_dir: Path, *args: str) -> None:
    result = subprocess.run(
        ["git", *args], cwd=repo_dir, capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} falló: {result.stderr.strip()}")


def _push(repo_dir: Path) -> None:
    _git(repo_dir, "push", "origin", "HEAD")


def write_and_push(repo_dir: Path, relative_path: str, body: str, message: str) -> None:
    """Escribe el fichero bajo revisiones/, hace commit y lo empuja."""
    normalized = PurePosixPath(relative_path)
    if ".." in normalized.parts or not relative_path.startswith(ALLOWED_PREFIX):
        raise ValueError(
            f"Solo se puede escribir bajo {ALLOWED_PREFIX!r}, no en {relative_path!r}"
        )

    target = repo_dir / normalized
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding="utf-8")

    remotes = subprocess.run(
        ["git", "remote"], cwd=repo_dir, capture_output=True, text=True
    ).stdout.split()
    if "origin" in remotes:
        _git(repo_dir, "pull", "--rebase", "--autostash")
    _git(repo_dir, "add", str(normalized))
    _git(repo_dir, "commit", "-m", message)
    _push(repo_dir)
