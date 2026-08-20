"""Concatenación del audio de las frases y cálculo de los tiempos."""

import subprocess
from pathlib import Path

from .model import Sentence


def assign_timings(sentences: list[Sentence], durations: list[float]) -> None:
    """Rellena t_start y t_end acumulando las duraciones, en el sitio."""
    if len(sentences) != len(durations):
        raise ValueError(
            f"El número de frases ({len(sentences)}) no coincide con el de "
            f"duraciones ({len(durations)})"
        )
    t = 0.0
    for sentence, duration in zip(sentences, durations):
        sentence.t_start = round(t, 3)
        t += duration
        sentence.t_end = round(t, 3)


def build_concat_file(wav_paths: list[Path], listing: Path) -> Path:
    """Escribe el fichero de lista que consume el demuxer concat de ffmpeg."""
    lines = []
    for path in wav_paths:
        escaped = str(path.resolve()).replace("'", r"'\''")
        lines.append(f"file '{escaped}'")
    listing.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return listing


def concat(wav_paths: list[Path], out_path: Path) -> None:
    """Une los WAV en un único opus, sin recodificar dos veces."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    listing = build_concat_file(wav_paths, out_path.with_suffix(".txt"))
    try:
        result = subprocess.run(
            [
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "concat", "-safe", "0", "-i", str(listing),
                "-c:a", "libopus", "-b:a", "32k", "-application", "voip",
                str(out_path),
            ],
            capture_output=True,
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"ffmpeg falló: {result.stderr.decode('utf-8', 'replace')}"
            )
    finally:
        listing.unlink(missing_ok=True)
