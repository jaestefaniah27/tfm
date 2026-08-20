"""Caché de audio indexada por el hash del texto hablado."""

import hashlib
from pathlib import Path

from .tts import wav_duration


def sentence_hash(spoken: str) -> str:
    """SHA-256 del texto hablado, truncado a 16 caracteres hexadecimales."""
    return hashlib.sha256(spoken.encode("utf-8")).hexdigest()[:16]


def get_or_synth(spoken: str, backend, cache_dir: Path) -> tuple[Path, float]:
    """Devuelve el WAV de la frase, sintetizándolo solo si no estaba en caché."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / f"{sentence_hash(spoken)}.wav"
    if not path.exists():
        path.write_bytes(backend.synth(spoken))
    return path, wav_duration(path.read_bytes())
