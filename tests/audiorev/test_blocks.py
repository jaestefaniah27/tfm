from tools.audiorev.blocks import extract_blocks
from tools.audiorev.model import SourceLine


def _lines(text):
    return [
        SourceLine(tex_file="x.tex", lineno=i, text=t)
        for i, t in enumerate(text.strip("\n").split("\n"), start=1)
    ]


def test_replaces_a_figure_with_a_marker_and_keeps_the_prose():
    src = _lines(
        r"""
Antes de la figura.
\begin{figure}[H]
\centering
\includegraphics[width=0.8\textwidth]{IMG/x.png}
\caption{Diagrama de bloques}
\label{fig:x}
\end{figure}
Después de la figura.
"""
    )
    kept, blocks = extract_blocks(src)
    texts = [l.text for l in kept]
    assert texts == ["Antes de la figura.", "%%BLOCK:0%%", "Después de la figura."]
    assert len(blocks) == 1
    assert blocks[0].type == "figure"
    assert blocks[0].caption == "Diagrama de bloques"
    assert blocks[0].ref == "fig:x"


def test_extracts_listing_as_code():
    src = _lines(
        r"""
\begin{lstlisting}[language=VHDL]
signal x : std_logic;
\end{lstlisting}
"""
    )
    kept, blocks = extract_blocks(src)
    assert [l.text for l in kept] == ["%%BLOCK:0%%"]
    assert blocks[0].type == "code"
    assert "signal x" in blocks[0].raw


def test_nested_tabular_inside_table_yields_one_block():
    src = _lines(
        r"""
\begin{table}[H]
\begin{tabular}{ll}
a & b \\
\end{tabular}
\caption{Puertos}
\label{tab:p}
\end{table}
"""
    )
    kept, blocks = extract_blocks(src)
    assert len(blocks) == 1
    assert blocks[0].type == "table"
    assert blocks[0].caption == "Puertos"


def test_uses_the_outer_caption_and_label_not_a_subfigure_ones():
    src = _lines(
        r"""
\begin{figure}[H]
\centering
\begin{subfigure}[t]{0.48\textwidth}
\centering
\includegraphics[width=\textwidth]{IMG/a.jpg}
\caption{Vista superior de la placa.}
\label{fig:a}
\end{subfigure}
\hfill
\begin{subfigure}[t]{0.48\textwidth}
\centering
\includegraphics[width=\textwidth]{IMG/b.jpg}
\caption{Placa montada en el conector.}
\label{fig:b}
\end{subfigure}
\caption{PCB de comunicación serie en la campaña de caracterización.}
\label{fig:pcb_montaje}
\end{figure}
"""
    )
    kept, blocks = extract_blocks(src)
    assert len(blocks) == 1
    assert blocks[0].caption == "PCB de comunicación serie en la campaña de caracterización."
    assert blocks[0].ref == "fig:pcb_montaje"


def test_block_without_caption_or_label_does_not_raise():
    src = _lines(
        r"""
\begin{tabular}{ll}
a & b \\
\end{tabular}
"""
    )
    _, blocks = extract_blocks(src)
    assert blocks[0].caption == ""
    assert blocks[0].ref is None
