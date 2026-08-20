from tools.audiorev.segment import split_sentences


def test_splits_on_sentence_boundaries():
    out = split_sentences("Primera frase. Segunda frase. Tercera.")
    assert out == ["Primera frase.", "Segunda frase.", "Tercera."]


def test_does_not_split_on_document_abbreviations():
    assert len(split_sentences("Se muestra en la fig. 4.2 del anexo.")) == 1
    assert len(split_sentences("Los buses, p. ej. RS485, son serie.")) == 1
    assert len(split_sentences("Cables, conectores, etc. forman el arnés.")) == 1


def test_does_not_split_on_decimal_numbers():
    assert len(split_sentences("La tensión es de 1,8 V nominales.")) == 1
    assert len(split_sentences("Se midió 3.3 V en el pin.")) == 1


def test_splits_on_question_and_exclamation():
    assert len(split_sentences("¿Y esto? Pues sí.")) == 2


def test_drops_empty_fragments():
    assert split_sentences("   ") == []
    assert split_sentences("Una.  \n\n  ") == ["Una."]
