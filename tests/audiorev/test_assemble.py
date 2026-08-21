from pathlib import Path

import pytest

from tools.audiorev.assemble import assign_timings, concat, build_concat_file
from tools.audiorev.model import Sentence


def _sentences(n):
    return [
        Sentence(idx=i, text=f"F{i}.", spoken=f"F{i}.", hash=f"h{i}", tex_line=i)
        for i in range(n)
    ]


def test_timings_are_cumulative():
    s = _sentences(3)
    assign_timings(s, [1.0, 2.5, 0.5])
    assert (s[0].t_start, s[0].t_end) == (0.0, 1.0)
    assert (s[1].t_start, s[1].t_end) == (1.0, 3.5)
    assert (s[2].t_start, s[2].t_end) == (3.5, 4.0)


def test_timings_are_rounded_to_three_decimals():
    s = _sentences(2)
    assign_timings(s, [0.3333333, 0.3333333])
    assert s[1].t_end == 0.667


def test_length_mismatch_raises():
    import pytest

    with pytest.raises(ValueError, match="no coincide"):
        assign_timings(_sentences(2), [1.0])


def test_concat_file_lists_every_wav_with_escaped_quotes(tmp_path):
    # El demuxer concat de ffmpeg entrecomilla con comillas simples, así que
    # un apóstrofo en la ruta rompe el listado si no se escapa: la ruta de
    # prueba tiene que llevar uno para que la prueba compruebe algo.
    con_apostrofo = tmp_path / "d'Artagnan"
    con_apostrofo.mkdir()
    paths = [con_apostrofo / "a.wav", tmp_path / "b.wav"]
    listing = build_concat_file(paths, tmp_path / "list.txt")
    body = listing.read_text(encoding="utf-8")
    assert body.count("file '") == 2
    assert "a.wav" in body and "b.wav" in body
    assert r"'\''" in body
    assert "d'Artagnan/a.wav'" not in body  # sin escapar cerraría la comilla


def test_concat_invokes_ffmpeg_with_the_concat_demuxer(tmp_path, monkeypatch):
    seen = {}

    def fake_run(cmd, **kwargs):
        seen["cmd"] = cmd

        class R:
            returncode = 0

        return R()

    monkeypatch.setattr("tools.audiorev.assemble.subprocess.run", fake_run)
    (tmp_path / "a.wav").write_bytes(b"")
    concat([tmp_path / "a.wav"], tmp_path / "out.opus")
    assert "ffmpeg" in seen["cmd"][0]
    assert "concat" in seen["cmd"]
    assert str(tmp_path / "out.opus") in seen["cmd"]


def test_concat_raises_when_ffmpeg_fails(tmp_path, monkeypatch):
    def fake_run(cmd, **kwargs):
        class R:
            returncode = 1
            stderr = b"Invalid data found when processing input"

        return R()

    monkeypatch.setattr("tools.audiorev.assemble.subprocess.run", fake_run)
    (tmp_path / "a.wav").write_bytes(b"")
    with pytest.raises(RuntimeError, match="Invalid data"):
        concat([tmp_path / "a.wav"], tmp_path / "out.opus")
    # Y el listado temporal no se queda por medio.
    assert not (tmp_path / "out.txt").exists()
