from tools.audiorev.cache import sentence_hash, get_or_synth
from tools.audiorev.tts import get_backend


def test_hash_is_16_hex_chars_and_stable():
    h = sentence_hash("Una frase.")
    assert len(h) == 16
    assert all(c in "0123456789abcdef" for c in h)
    assert h == sentence_hash("Una frase.")


def test_different_text_gives_different_hash():
    assert sentence_hash("Una frase.") != sentence_hash("Otra frase.")


def test_second_call_does_not_synthesise_again(tmp_path):
    calls = []

    class Counting:
        def synth(self, text):
            calls.append(text)
            return get_backend("fake").synth(text)

    backend = Counting()
    p1, d1 = get_or_synth("Una frase.", backend, tmp_path)
    p2, d2 = get_or_synth("Una frase.", backend, tmp_path)
    assert p1 == p2
    assert d1 == d2
    assert len(calls) == 1


def test_changed_text_creates_a_new_file(tmp_path):
    backend = get_backend("fake")
    p1, _ = get_or_synth("Una frase.", backend, tmp_path)
    p2, _ = get_or_synth("Una frase distinta.", backend, tmp_path)
    assert p1 != p2
    assert p1.exists() and p2.exists()


def test_failed_synthesis_leaves_no_file_at_the_cache_path(tmp_path):
    import pytest

    class Failing:
        def synth(self, text):
            raise RuntimeError("fallo simulado de síntesis")

    with pytest.raises(RuntimeError, match="fallo simulado"):
        get_or_synth("Una frase.", Failing(), tmp_path)

    path = tmp_path / f"{sentence_hash('Una frase.')}.wav"
    assert not path.exists()
    # No debe quedar tampoco ningún temporal huérfano en la caché.
    assert list(tmp_path.iterdir()) == []


def test_cache_hit_still_avoids_resynthesis_after_the_atomic_write_fix(tmp_path):
    calls = []

    class Counting:
        def synth(self, text):
            calls.append(text)
            return get_backend("fake").synth(text)

    backend = Counting()
    p1, d1 = get_or_synth("Otra frase distinta.", backend, tmp_path)
    p2, d2 = get_or_synth("Otra frase distinta.", backend, tmp_path)
    assert p1 == p2
    assert d1 == d2
    assert len(calls) == 1
