"""Expansión de import e input para obtener el documento en orden canónico."""

import re
import sys
from pathlib import Path

from .model import SourceLine

_IMPORT = re.compile(r"\\import\{([^}]*)\}\{([^}]*)\}")
_INPUT = re.compile(r"\\(?:input|include)\{([^}]*)\}")


def _rel(path: Path, repo_root: Path) -> str:
    return path.resolve().relative_to(repo_root.resolve()).as_posix()


def _warn(message: str) -> None:
    print(f"audiorev: aviso: {message}", file=sys.stderr)


def _read(
    path: Path, repo_root: Path, seen: set[Path], desde: str | None = None
) -> list[SourceLine]:
    resolved = path.resolve()
    if resolved in seen:
        return []
    if not resolved.exists():
        # Un \import mal escrito o un fichero renombrado quitaba un capítulo
        # entero del audio sin decir nada, mientras que un main.aux ausente
        # revienta ruidosamente dos líneas después en build.py. La asimetría
        # era el fallo.
        origen = f" incluido desde {desde}" if desde else ""
        _warn(f"no existe {path}{origen}: se queda fuera del audio")
        return []
    seen.add(resolved)

    rel = _rel(resolved, repo_root)
    out: list[SourceLine] = []
    for lineno, raw in enumerate(
        resolved.read_text(encoding="utf-8").splitlines(), start=1
    ):
        text = raw.rstrip()

        m = _IMPORT.search(text)
        if m:
            child = resolved.parent / m.group(1) / m.group(2)
            out.extend(_read(_with_tex(child), repo_root, seen, rel))
            continue

        m = _INPUT.search(text)
        if m:
            child = resolved.parent / m.group(1)
            out.extend(_read(_with_tex(child), repo_root, seen, rel))
            continue

        out.append(SourceLine(tex_file=rel, lineno=lineno, text=text))
    return out


def _with_tex(path: Path) -> Path:
    return path if path.suffix == ".tex" else path.with_suffix(".tex")


def expand(main_tex: Path, repo_root: Path) -> list[SourceLine]:
    """Devuelve el documento completo como líneas con su origen real."""
    return _read(main_tex, repo_root, set())
