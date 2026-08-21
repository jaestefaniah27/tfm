import io
import subprocess
import wave

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


def test_piper_invokes_the_cli_the_readme_documents(monkeypatch, tmp_path):
    # El README instala piper1-gpl (`pip install piper-tts`), cuya CLI usa
    # `-m` y `-f` con guion. El viejo `--output_file` con guion bajo es de
    # otro Piper y moriría con "unrecognized arguments".
    from pathlib import Path

    import tools.audiorev.tts as tts

    visto = {}

    def fake_run(argv, **kwargs):
        visto["argv"] = argv
        visto["input"] = kwargs["input"]
        Path(argv[argv.index("-f") + 1]).write_bytes(tts.FakeBackend().synth("x"))
        return subprocess.CompletedProcess(argv, 0, b"", b"")

    monkeypatch.setattr(tts.subprocess, "run", fake_run)
    data = tts.PiperBackend(model="voz.onnx").synth("Hola.")

    assert visto["argv"][:4] == ["piper", "-m", "voz.onnx", "-f"]
    assert visto["argv"][4].endswith(".wav")
    assert visto["input"] == b"Hola."
    assert tts.wav_duration(data) > 0


def test_piper_failure_names_the_sentence_and_pipers_stderr(monkeypatch):
    import tools.audiorev.tts as tts

    def fake_run(argv, **kwargs):
        return subprocess.CompletedProcess(argv, 2, b"", b"error: unrecognized arguments")

    monkeypatch.setattr(tts.subprocess, "run", fake_run)
    with pytest.raises(RuntimeError) as exc:
        tts.PiperBackend().synth("Una frase cualquiera.")
    assert "unrecognized arguments" in str(exc.value)
    assert "Una frase cualquiera." in str(exc.value)


def test_piper_missing_binary_says_how_to_install_it(monkeypatch):
    import tools.audiorev.tts as tts

    def fake_run(argv, **kwargs):
        raise FileNotFoundError(argv[0])

    monkeypatch.setattr(tts.subprocess, "run", fake_run)
    with pytest.raises(RuntimeError, match="pip install piper-tts"):
        tts.PiperBackend().synth("Hola.")
