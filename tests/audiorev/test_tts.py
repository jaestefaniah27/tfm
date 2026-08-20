import wave
import io

import pytest

from tools.audiorev.tts import get_backend, wav_duration


def test_fake_backend_produces_a_readable_wav():
    data = get_backend("fake").synth("Una frase de prueba.")
    with wave.open(io.BytesIO(data)) as w:
        assert w.getnchannels() == 1
        assert w.getframerate() == 22050
        assert w.getnframes() > 0


def test_duration_grows_with_the_length_of_the_text():
    backend = get_backend("fake")
    corta = wav_duration(backend.synth("Hola."))
    larga = wav_duration(backend.synth("Hola. " * 20))
    assert larga > corta


def test_env_var_selects_the_backend(monkeypatch):
    monkeypatch.setenv("AUDIOREV_TTS_BACKEND", "fake")
    assert type(get_backend()).__name__ == "FakeBackend"


def test_unknown_backend_raises_with_a_useful_message():
    with pytest.raises(ValueError, match="inexistente"):
        get_backend("inexistente")
