"""Caché de audio indexada por el hash del texto hablado."""

import hashlib
import os
import tempfile
from pathlib import Path

from .tts import wav_duration


def sentence_hash(spoken: str) -> str:
    """SHA-256 del texto hablado, truncado a 16 caracteres hexadecimales."""
    return hashlib.sha256(spoken.encode("utf-8")).hexdigest()[:16]


def get_or_synth(spoken: str, backend, cache_dir: Path) -> tuple[Path, float]:
    """Devuelve el WAV de la frase, sintetizándolo solo si no estaba en caché.

    La escritura es atómica: se sintetiza a un fichero temporal en el mismo
    directorio y se renombra al destino final con os.replace, de forma que
    un lector nunca ve un WAV a medio escribir. Si la síntesis o la
    escritura fallan, el temporal se borra y no queda ninguna entrada en
    la caché, para que el siguiente intento vuelva a sintetizar.
    """
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / f"{sentence_hash(spoken)}.wav"
    if not path.exists():
        tmp = tempfile.NamedTemporaryFile(dir=cache_dir, delete=False)
        tmp_path = Path(tmp.name)
        tmp.close()
        try:
            tmp_path.write_bytes(backend.synth(spoken))
            os.replace(tmp_path, path)
        except BaseException:
            tmp_path.unlink(missing_ok=True)
            raise
    return path, wav_duration(path.read_bytes())
