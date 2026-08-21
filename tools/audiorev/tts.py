"""Backends de síntesis de voz tras una interfaz común."""

import io
import os
import subprocess
import tempfile
import wave
from pathlib import Path
from typing import Protocol

SAMPLE_RATE = 22050


class TTSBackend(Protocol):
    def synth(self, text: str) -> bytes:
        """Devuelve un WAV mono completo con el texto leído."""


class FakeBackend:
    """Silencio de duración proporcional al texto. Solo para las pruebas."""

    def synth(self, text: str) -> bytes:
        seconds = max(0.2, len(text) / 15.0)
        frames = int(SAMPLE_RATE * seconds)
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SAMPLE_RATE)
            w.writeframes(b"\x00\x00" * frames)
        return buf.getvalue()


class PiperBackend:
    """Síntesis local con Piper (piper1-gpl, el paquete `piper-tts` de PyPI).

    Es el Piper que documenta el README, y su CLI usa `-m/--model` y
    `-f/--output-file` con GUION, no el `--output_file` con guion bajo del
    viejo Piper en C++. Se escribe a un fichero temporal en vez de a la
    salida estándar porque es la forma que ambos aceptan sin ambigüedad, y
    lo que se devuelve es el WAV completo.
    """

    INSTALL_HINT = (
        "Piper no está instalado o no está en el PATH. Instálalo con "
        "`pip install piper-tts` y descarga la voz con "
        "`python -m piper.download_voices es_ES-davefx-medium`."
    )

    def __init__(self, model: str | None = None) -> None:
        self.model = model or os.environ.get(
            "AUDIOREV_PIPER_MODEL", "es_ES-davefx-medium.onnx"
        )

    def synth(self, text: str) -> bytes:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "frase.wav"
            argv = ["piper", "-m", self.model, "-f", str(out)]
            try:
                result = subprocess.run(
                    argv,
                    input=text.encode("utf-8"),
                    capture_output=True,
                )
            except FileNotFoundError as exc:
                raise RuntimeError(self.INSTALL_HINT) from exc

            if result.returncode != 0 or not out.exists():
                # check=True escondía la queja de piper dentro de un
                # CalledProcessError que solo lleva el código de salida: sin
                # el stderr no hay forma de saber si falla el modelo, la voz
                # o la frase.
                raise RuntimeError(
                    f"piper falló (código {result.returncode}) con la frase "
                    f"{text[:80]!r}: {result.stderr.decode('utf-8', 'replace').strip()}"
                )
            return out.read_bytes()


_BACKENDS = {"fake": FakeBackend, "piper": PiperBackend}


def get_backend(name: str | None = None) -> TTSBackend:
    key = (name or os.environ.get("AUDIOREV_TTS_BACKEND") or "piper").lower()
    if key not in _BACKENDS:
        raise ValueError(
            f"Backend de TTS {key!r} inexistente. Disponibles: {sorted(_BACKENDS)}"
        )
    return _BACKENDS[key]()


def wav_duration(data: bytes) -> float:
    with wave.open(io.BytesIO(data)) as w:
        return w.getnframes() / float(w.getframerate())
