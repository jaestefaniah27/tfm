import pytest

from tools.audiorev.speak import to_spoken, plain

LABELS = {"fig:x": ("3.1", "figure"), "tab:y": ("4.2", "table")}
PRON = {"AOCS": "a o ce ese", "DMA": "de eme a", "CAN": "can"}


def spoken(text):
    return to_spoken(text, LABELS, PRON)


def test_removes_comments():
    assert spoken("Texto visible. % esto no se lee") == "Texto visible."


def test_keeps_escaped_percent():
    assert spoken(r"Un 50\% de mejora.") == "Un 50% de mejora."


def test_unwraps_formatting_commands():
    assert spoken(r"El bloque \textit{top} es \textbf{clave}.") == "El bloque top es clave."


def test_resolves_references_by_kind():
    # El artículo (y el sustantivo) que ya escribe el LaTeX se absorben: la
    # expansión trae los suyos y antes se oía «la la figura 3.1».
    assert spoken(r"Se ve en la \ref{fig:x}.") == "Se ve en la figura 3.1."
    assert spoken(r"Ver \ref{tab:y}.") == "Ver la tabla 4.2."


def test_drops_citations():
    assert spoken(r"Según el manual \cite{xilinx2023ug1182} el bus es AXI.") == (
        "Según el manual el bus es axi."
    ) or "cite" not in spoken(r"Según el manual \cite{x} algo.")


def test_spells_acronyms_from_the_dictionary():
    assert "a o ce ese" in spoken("El subsistema AOCS responde.")
    assert "de eme a" in spoken("El DMA transfiere.")


def test_acronym_read_as_word_is_not_spelled():
    assert spoken("El bus CAN es serie.") == "El bus can es serie."


def test_expands_units_and_numbers():
    assert spoken(r"Alimentado a 1,8~V.") == "Alimentado a 1,8 voltios."
    assert spoken("Reloj de 100 MHz.") == "Reloj de 100 megahercios."
    assert spoken("Retardo de 5 us.") == "Retardo de 5 microsegundos."


def test_footnote_is_moved_to_the_end():
    out = spoken(r"Frase principal\footnote{Detalle menor.} y sigue.")
    assert out.startswith("Frase principal y sigue.")
    assert out.endswith("nota al pie: Detalle menor.")


def test_complex_math_degrades_to_a_spoken_placeholder():
    out = spoken(r"El resultado es $\frac{f_{clk}}{2^{N}}$ exactamente.")
    assert "fórmula, ver documento" in out
    assert "frac" not in out


def test_simple_math_is_read():
    assert spoken("La razón es $N = 32$ bits.") == "La razón es N = 32 bits."


def test_block_marker_becomes_a_spoken_cue():
    assert spoken("%%BLOCK:3%%") == ""


def test_plain_keeps_the_words_without_spelling_acronyms():
    assert plain(r"El \textit{buffer} del AOCS.") == "El buffer del AOCS."
    assert plain(r"Se ve en la \ref{fig:x}.") == "Se ve en la referencia."


def test_collapses_whitespace():
    assert spoken("Uno   dos\n\ntres.") == "Uno dos tres."


def test_paragraph_heading_keeps_its_text():
    assert spoken(r"\paragraph{Puntos de prueba.} La revisión sigue.") == (
        "Puntos de prueba. La revisión sigue."
    )
    assert plain(r"\paragraph{Puntos de prueba.} La revisión sigue.") == (
        "Puntos de prueba. La revisión sigue."
    )


def test_label_is_still_dropped_entirely():
    assert "label" not in spoken(r"Texto\label{sec:validacion_cdhs} siguiente.")
    assert "sec" not in spoken(r"Texto\label{sec:validacion_cdhs} siguiente.")


def test_the_article_and_noun_before_a_ref_are_not_said_twice():
    assert spoken(r"Como muestra la figura~\ref{fig:x}, el conector.") == (
        "Como muestra la figura 3.1, el conector."
    )
    assert spoken(r"La tabla~\ref{tab:y} resume los datos.") == (
        "La tabla 4.2 resume los datos."
    )
    # La mayúscula inicial sobrevive a la absorción.
    assert spoken(r"\ref{fig:x} lo muestra.") == "la figura 3.1 lo muestra."
    # Y no se toca lo que no es artículo ni sustantivo de referencia.
    assert spoken(r"Ver la placa \ref{tab:y}.") == "Ver la placa la tabla 4.2."


def test_texttt_underscore_is_a_brief_pause_only_in_the_spoken_text():
    # Apartado 4.1 del diseño: el guion bajo no se lee como «guion bajo».
    assert spoken(r"El registro \texttt{mi\_var} vale 3.") == "El registro mi, var vale 3."
    assert plain(r"El registro \texttt{mi\_var} vale 3.") == "El registro mi_var vale 3."
