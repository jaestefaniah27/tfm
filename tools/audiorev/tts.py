"""Backends de síntesis de voz tras una interfaz común."""

import io
import os
import subprocess
import wave
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
    """Síntesis local con Piper. Requiere el binario piper en el PATH."""

    def __init__(self, model: str | None = None) -> None:
        self.model = model or os.environ.get(
            "AUDIOREV_PIPER_MODEL", "es_ES-davefx-medium.onnx"
        )

    def synth(self, text: str) -> bytes:
        result = subprocess.run(
            ["piper", "--model", self.model, "--output_file", "-"],
            input=text.encode("utf-8"),
            capture_output=True,
            check=True,
        )
        return result.stdout


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
