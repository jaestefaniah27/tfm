"""Orquestador: del repositorio al índice JSON y al audio."""

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from . import dic
from .assemble import assign_timings, concat
from .blocks import extract_blocks
from .cache import get_or_synth, sentence_hash
from .expand import expand
from .model import Sentence, Unit
from .refs import load_labels
from .segment import split_sentences
from .speak import plain, to_spoken
from .structure import rechunk, split_units
from .tts import get_backend

TEX_ROOT = "plantilla_tft_etsit"


def build_units(repo_root: Path) -> list[Unit]:
    """Construye las unidades con sus frases, sin sintetizar nada."""
    tex_root = repo_root / TEX_ROOT
    labels = load_labels(tex_root / "main.aux")
    pron = dic.load(repo_root / "tools" / "audiorev" / "dic" / "pronunciacion.yml")

    lines, blocks = extract_blocks(expand(tex_root / "main.tex", repo_root))
    units = rechunk(split_units(lines))

    for unit in units:
        body = "\n".join(l.text for l in unit.lines)
        first_line = unit.lines[0].lineno if unit.lines else unit.tex_lines[0]
        for idx, raw in enumerate(split_sentences(plain(body))):
            spoken = to_spoken(raw, labels, pron)
            if not spoken:
                continue
            unit.sentences.append(
                Sentence(
                    idx=len(unit.sentences),
                    text=raw,
                    spoken=spoken,
                    hash=sentence_hash(spoken),
                    tex_line=first_line,
                )
            )
        # Se usa enumerate en vez de blocks.index(b): list.index devuelve
        # siempre la primera coincidencia, así que dos bloques idénticos
        # (mismo raw/caption/etc.) colisionarían en el mismo índice y la
        # asignación de bloques a unidades quedaría mal.
        unit.blocks = [b for i, b in enumerate(blocks) if f"%%BLOCK:{i}%%" in body]
    return units


def unit_to_dict(unit: Unit) -> dict:
    data = asdict(unit)
    data.pop("lines", None)
    data["tex_lines"] = list(unit.tex_lines)
    return data


def render(units, out_dir: Path, backend, cache_dir: Path, with_audio: bool) -> None:
    """Sintetiza si se pide y escribe un JSON por unidad."""
    out_dir.mkdir(parents=True, exist_ok=True)

    for unit in units:
        if with_audio and unit.sentences:
            paths, durations = [], []
            for sentence in unit.sentences:
                path, duration = get_or_synth(sentence.spoken, backend, cache_dir)
                paths.append(path)
                durations.append(duration)
            assign_timings(unit.sentences, durations)
            unit.duration_s = unit.sentences[-1].t_end
            concat(paths, out_dir / f"{unit.unit_id}.opus")

        (out_dir / f"{unit.unit_id}.json").write_text(
            json.dumps(unit_to_dict(unit), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )


def write_manifest(units, out_dir: Path) -> None:
    """Escribe manifest.json con un resumen de cada unidad renderizada."""
    manifest = {
        "units": [
            {
                "unit_id": unit.unit_id,
                "title": unit.title,
                "chapter": unit.chapter,
                "chapter_title": unit.chapter_title,
                "level": unit.level,
                "duration_s": unit.duration_s,
                "n_sentences": len(unit.sentences),
                "n_blocks": len(unit.blocks),
            }
            for unit in units
        ]
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convierte el TFM en audio por apartado.")
    parser.add_argument("--repo", default=".", help="Raíz del repositorio")
    parser.add_argument("--out", required=True, help="Directorio de salida")
    parser.add_argument("--cache", default=None, help="Directorio de la caché de audio")
    parser.add_argument("--only", default=None, help="Filtra por fragmento de ruta, p. ej. cap3")
    parser.add_argument("--backend", default=None, help="piper, kokoro o fake")
    parser.add_argument("--no-audio", action="store_true", help="Solo genera los JSON")
    args = parser.parse_args(argv)

    repo_root = Path(args.repo).resolve()
    out_dir = Path(args.out).resolve()
    cache_dir = Path(args.cache).resolve() if args.cache else out_dir / ".cache"

    units = build_units(repo_root)
    if args.only:
        units = [u for u in units if args.only in u.tex_file]

    render(units, out_dir, get_backend(args.backend), cache_dir, not args.no_audio)
    write_manifest(units, out_dir)
    total = sum(u.duration_s for u in units)
    print(f"{len(units)} unidades, {total / 60:.1f} min de audio, en {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
