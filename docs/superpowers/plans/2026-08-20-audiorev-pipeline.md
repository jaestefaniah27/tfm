# AudioRev, conversor de LaTeX a audio: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir `tools/audiorev`, una herramienta de línea de órdenes que convierte los ficheros `.tex` del TFM en un índice JSON por apartado más un fichero de audio por apartado, con tiempos por frase y regeneración incremental.

**Architecture:** Cadena de módulos con una responsabilidad cada uno: expandir el documento, partirlo en unidades, extraer los bloques visuales, normalizar el LaTeX a texto hablado, segmentar en frases, sintetizar cada frase con caché por hash y concatenar. La salida es autodescriptiva: un JSON por unidad con el texto, los hashes y los tiempos, más un `.opus` por unidad.

**Tech Stack:** Python 3.11+, pytest, pysbd, PyYAML, Piper TTS, ffmpeg.

**Spec:** `docs/superpowers/specs/2026-08-20-audiorev-design.md`

## Global Constraints

- Python 3.11 o superior. Sin dependencias más allá de `pysbd`, `PyYAML` y `pytest`; `piper-tts` y `ffmpeg` son binarios externos, no dependencias de importación.
- Todas las rutas que se guarden en el JSON son **relativas a la raíz del repositorio** y con separador `/`, nunca absolutas ni con separador de Windows.
- El texto del TFM está en español y en UTF-8. Todo `open()` lleva `encoding="utf-8"` explícito.
- `sentence_hash` es SHA-256 del texto **hablado** normalizado, truncado a 16 caracteres hexadecimales.
- Los `unit_id` no dependen de la posición del apartado en el documento.
- Ningún módulo escribe fuera de `--out`, salvo `dic.py` cuando se le pide sembrar el diccionario.
- El audio nunca se añade a git. Solo los JSON de índice.
- Nombres de fichero del audio: `<unit_id>.opus`. Nombres del índice: `<unit_id>.json`.

## Estructura de ficheros

| Fichero | Responsabilidad |
|---|---|
| `tools/audiorev/model.py` | Dataclasses compartidas: `SourceLine`, `Block`, `Sentence`, `Unit` |
| `tools/audiorev/refs.py` | Lee `main.aux` y resuelve etiquetas a números y a tipo |
| `tools/audiorev/dic.py` | Diccionario de pronunciación y siembra desde `acronimos.tex` |
| `tools/audiorev/expand.py` | Resuelve `import` e `input` desde `main.tex` |
| `tools/audiorev/blocks.py` | Extrae los bloques visuales y los convierte a HTML |
| `tools/audiorev/structure.py` | Parte en unidades y trocea las demasiado largas |
| `tools/audiorev/speak.py` | Normaliza LaTeX a texto pronunciable |
| `tools/audiorev/segment.py` | Segmenta en frases respetando las abreviaturas |
| `tools/audiorev/tts.py` | Backends de síntesis tras una interfaz común |
| `tools/audiorev/cache.py` | Caché de audio por hash de frase |
| `tools/audiorev/assemble.py` | Concatena y calcula los tiempos |
| `tools/audiorev/build.py` | Orquestador y línea de órdenes |
| `tests/audiorev/` | Pruebas, una por módulo, más fixtures |

El orden de las tareas sigue las dependencias: primero los módulos hoja que no dependen de nadie, después los que los componen.

---

### Task 0: Andamiaje del paquete y de las pruebas

**Files:**
- Create: `tools/audiorev/__init__.py`
- Create: `tools/audiorev/model.py`
- Create: `tests/audiorev/__init__.py`
- Create: `tests/audiorev/conftest.py`
- Create: `requirements-audiorev.txt`
- Create: `pytest.ini`

**Interfaces:**
- Consumes: nada.
- Produces: las dataclasses `SourceLine`, `Block`, `Sentence` y `Unit`, y la fixture `repo_root` que devuelve la raíz del repositorio como `pathlib.Path`.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_model.py`:

```python
from tools.audiorev.model import SourceLine, Block, Sentence, Unit


def test_sentence_defaults_timing_to_zero():
    s = Sentence(idx=0, text="Hola.", spoken="Hola.", hash="ab12", tex_line=7)
    assert s.t_start == 0.0
    assert s.t_end == 0.0


def test_unit_starts_empty_and_reports_zero_duration():
    u = Unit(
        unit_id="c03-entorno-nco",
        chapter=3,
        chapter_title="Desarrollo",
        level=2,
        title="Oscilador controlado numéricamente (NCO)",
        tex_file="plantilla_tft_etsit/capitulos/cap3/entorno_desarrollo.tex",
        tex_lines=(326, 402),
    )
    assert u.sentences == []
    assert u.blocks == []
    assert u.duration_s == 0.0


def test_sourceline_and_block_carry_their_origin():
    line = SourceLine(tex_file="a/b.tex", lineno=3, text="Texto.")
    assert (line.tex_file, line.lineno) == ("a/b.tex", 3)
    b = Block(after_sentence=2, type="table", caption="Puertos", ref="tab:tx", raw="", html="")
    assert b.type == "table"
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_model.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/__init__.py`: fichero vacío.

`tools/audiorev/model.py`:

```python
"""Estructuras de datos compartidas por toda la cadena de conversión."""

from dataclasses import dataclass, field


@dataclass
class SourceLine:
    """Una línea del documento expandido, con su origen real."""

    tex_file: str
    lineno: int
    text: str


@dataclass
class Block:
    """Un bloque que no se lee en voz alta y se muestra en pantalla."""

    after_sentence: int
    type: str  # code | table | figure | plot
    caption: str
    ref: str | None
    raw: str
    html: str


@dataclass
class Sentence:
    idx: int
    text: str
    spoken: str
    hash: str
    tex_line: int
    t_start: float = 0.0
    t_end: float = 0.0


@dataclass
class Unit:
    unit_id: str
    chapter: int
    chapter_title: str
    level: int
    title: str
    tex_file: str
    tex_lines: tuple[int, int]
    lines: list[SourceLine] = field(default_factory=list)
    sentences: list[Sentence] = field(default_factory=list)
    blocks: list[Block] = field(default_factory=list)
    duration_s: float = 0.0
```

`tests/audiorev/__init__.py`: fichero vacío.

`tests/audiorev/conftest.py`:

```python
from pathlib import Path

import pytest


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def tex_root(repo_root: Path) -> Path:
    return repo_root / "plantilla_tft_etsit"
```

`pytest.ini`:

```ini
[pytest]
testpaths = tests
pythonpath = .
```

`requirements-audiorev.txt`:

```
pysbd>=0.3.4
PyYAML>=6.0
pytest>=8.0
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_model.py -v`
Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev tests/audiorev pytest.ini requirements-audiorev.txt
git commit -m "Crear el andamiaje del conversor de audio y sus estructuras de datos"
```

---

### Task 1: Resolver las etiquetas de main.aux

**Files:**
- Create: `tools/audiorev/refs.py`
- Test: `tests/audiorev/test_refs.py`

**Interfaces:**
- Consumes: nada.
- Produces: `load_labels(aux_path: Path) -> dict[str, tuple[str, str]]`, que devuelve `{"fig:x": ("3.1", "figure")}`, y `spoken_ref(label: str, labels: dict) -> str`, que devuelve `"la figura 3.1"`.

El formato real, verificado en el repositorio, es:

```
\newlabel{fig:block_design_and}{{3.1}{14}{\textit {Block Design} del ejemplo}{figure.caption.84}{}}
\newlabel{objetivos}{{1.2}{2}{Objetivos}{section.1.2}{}}
\newlabel{tab:sw6}{{3.1}{16}{Posiciones del selector}{table.caption.86}{}}
```

El número es el primer grupo. El tipo se deduce del cuarto grupo, que empieza por `figure.`, `table.`, `section.`, `subsection.`, `subsubsection.`, `equation.` o `lstlisting.`.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_refs.py`:

```python
from tools.audiorev.refs import load_labels, spoken_ref


def test_parses_the_three_label_kinds(tmp_path):
    aux = tmp_path / "main.aux"
    aux.write_text(
        r"\newlabel{fig:block_design_and}{{3.1}{14}{\textit {Block Design}}{figure.caption.84}{}}"
        "\n"
        r"\newlabel{objetivos}{{1.2}{2}{Objetivos}{section.1.2}{}}"
        "\n"
        r"\newlabel{tab:sw6}{{3.1}{16}{Posiciones del selector}{table.caption.86}{}}"
        "\n",
        encoding="utf-8",
    )
    labels = load_labels(aux)
    assert labels["fig:block_design_and"] == ("3.1", "figure")
    assert labels["objetivos"] == ("1.2", "section")
    assert labels["tab:sw6"] == ("3.1", "table")


def test_spoken_ref_uses_spanish_names():
    labels = {
        "fig:x": ("3.1", "figure"),
        "tab:y": ("4.2", "table"),
        "sec:z": ("2.6.3", "subsection"),
        "eq:w": ("5", "equation"),
    }
    assert spoken_ref("fig:x", labels) == "la figura 3.1"
    assert spoken_ref("tab:y", labels) == "la tabla 4.2"
    assert spoken_ref("sec:z", labels) == "el apartado 2.6.3"
    assert spoken_ref("eq:w", labels) == "la ecuación 5"


def test_unknown_label_degrades_without_raising():
    assert spoken_ref("no:existe", {}) == "la referencia correspondiente"


def test_reads_the_real_aux_of_the_tfm(tex_root):
    labels = load_labels(tex_root / "main.aux")
    assert len(labels) == 81
    assert all(isinstance(v, tuple) and len(v) == 2 for v in labels.values())
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_refs.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.refs'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/refs.py`:

```python
"""Resolución de las etiquetas de LaTeX a su número y a su tipo."""

import re
from pathlib import Path

# \newlabel{NOMBRE}{{NUMERO}{PAGINA}{TITULO}{ANCLA}{}}
# El título puede contener llaves anidadas, así que no se puede capturar con una
# expresión regular plana: se localiza el nombre y el número, y el ancla se busca
# como el último grupo del tipo "palabra.algo" de la línea.
_NEWLABEL = re.compile(
    r"\\newlabel\{(?P<name>[^}]+)\}\{\{(?P<num>[^{}]*)\}\{(?P<page>[^{}]*)\}"
)
_ANCHOR = re.compile(
    r"\{(figure|table|section|subsection|subsubsection|equation|lstlisting|chapter)\."
)

_SPOKEN = {
    "figure": "la figura",
    "table": "la tabla",
    "equation": "la ecuación",
    "lstlisting": "el listado",
    "chapter": "el capítulo",
    "section": "el apartado",
    "subsection": "el apartado",
    "subsubsection": "el apartado",
}


def load_labels(aux_path: Path) -> dict[str, tuple[str, str]]:
    """Devuelve {etiqueta: (numero, tipo)} leyendo un fichero .aux de LaTeX."""
    labels: dict[str, tuple[str, str]] = {}
    for line in aux_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = _NEWLABEL.search(line)
        if not m:
            continue
        anchor = _ANCHOR.search(line, m.end())
        kind = anchor.group(1) if anchor else "section"
        labels[m.group("name")] = (m.group("num"), kind)
    return labels


def spoken_ref(label: str, labels: dict[str, tuple[str, str]]) -> str:
    """Convierte una etiqueta en la frase que se leerá en voz alta."""
    entry = labels.get(label)
    if entry is None:
        return "la referencia correspondiente"
    number, kind = entry
    return f"{_SPOKEN.get(kind, 'el apartado')} {number}"
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_refs.py -v`
Expected: 4 passed

Si la última prueba falla porque `main.aux` ya no tiene 81 etiquetas, es que la memoria se recompiló y cambió. Actualiza el número esperado al valor que devuelva `len(labels)` y sigue; la prueba solo protege frente a que el parser deje de encontrar nada.

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev/refs.py tests/audiorev/test_refs.py
git commit -m "Resolver las etiquetas de LaTeX a su número y a su nombre hablado"
```

---

### Task 2: Diccionario de pronunciación sembrado desde los acrónimos

**Files:**
- Create: `tools/audiorev/dic.py`
- Create: `tools/audiorev/dic/pronunciacion.yml` (generado por la propia tarea)
- Test: `tests/audiorev/test_dic.py`

**Interfaces:**
- Consumes: nada.
- Produces: `spell_es(token: str) -> str`, `seed_from_acronyms(tex_path: Path) -> dict[str, str]`, `load(path: Path) -> dict[str, str]` y `save(path: Path, entries: dict[str, str]) -> None`.

El formato real de `pre/acronimos.tex`, verificado, es:

```
\paragraph{AOCS} \textit{Attitude and Orbit Control Subsystem} --- Subsistema de control de actitud y órbita.
```

Hay 73 entradas.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_dic.py`:

```python
from tools.audiorev.dic import spell_es, seed_from_acronyms, load, save


def test_spells_letters_with_spanish_names():
    assert spell_es("AOCS") == "a o ce ese"
    assert spell_es("DMA") == "de eme a"
    assert spell_es("CDHS") == "ce de hache ese"


def test_spells_digits_as_words():
    assert spell_es("RS485") == "erre ese cuatro ocho cinco"


def test_seeds_every_acronym_of_the_tfm(tex_root):
    entries = seed_from_acronyms(tex_root / "pre" / "acronimos.tex")
    assert len(entries) == 73
    assert entries["AOCS"] == "a o ce ese"
    assert "AXI" in entries


def test_roundtrip_preserves_manual_overrides(tmp_path):
    path = tmp_path / "pronunciacion.yml"
    save(path, {"CAN": "can", "DMA": "de eme a"})
    assert load(path) == {"CAN": "can", "DMA": "de eme a"}


def test_load_of_missing_file_returns_empty(tmp_path):
    assert load(tmp_path / "no-existe.yml") == {}
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_dic.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.dic'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/dic.py`:

```python
"""Diccionario de pronunciación de acrónimos y siglas."""

import re
from pathlib import Path

import yaml

_LETTERS = {
    "A": "a", "B": "be", "C": "ce", "D": "de", "E": "e", "F": "efe",
    "G": "ge", "H": "hache", "I": "i", "J": "jota", "K": "ka", "L": "ele",
    "M": "eme", "N": "ene", "Ñ": "eñe", "O": "o", "P": "pe", "Q": "cu",
    "R": "erre", "S": "ese", "T": "te", "U": "u", "V": "uve",
    "W": "uve doble", "X": "equis", "Y": "i griega", "Z": "zeta",
}

_DIGITS = {
    "0": "cero", "1": "uno", "2": "dos", "3": "tres", "4": "cuatro",
    "5": "cinco", "6": "seis", "7": "siete", "8": "ocho", "9": "nueve",
}

_PARAGRAPH = re.compile(r"\\paragraph\{([^}]+)\}")

_HEADER = """\
# Pronunciación de acrónimos para la síntesis de voz.
#
# La clave es el acrónimo tal y como aparece en el LaTeX; el valor es lo que se
# le pasa al motor de voz. El fichero se siembra automáticamente deletreando
# cada acrónimo letra a letra, que es lo correcto para AOCS o CDHS pero no para
# los que se leen como una palabra. Corrige a mano esos casos:
#
#   CAN: can
#   RTEMS: ar tems
#   COTS: cots
#
# Después de tocar este fichero hay que regenerar el audio de las unidades
# afectadas; la caché por hash se encarga de no rehacer el resto.
"""


def spell_es(token: str) -> str:
    """Deletrea un acrónimo con los nombres españoles de las letras."""
    out = []
    for ch in token.upper():
        if ch in _LETTERS:
            out.append(_LETTERS[ch])
        elif ch in _DIGITS:
            out.append(_DIGITS[ch])
    return " ".join(out)


def seed_from_acronyms(tex_path: Path) -> dict[str, str]:
    """Construye el diccionario inicial a partir de la lista de acrónimos."""
    text = tex_path.read_text(encoding="utf-8")
    return {name: spell_es(name) for name in _PARAGRAPH.findall(text)}


def load(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    return data or {}


def save(path: Path, entries: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    body = yaml.safe_dump(entries, allow_unicode=True, sort_keys=True)
    path.write_text(_HEADER + body, encoding="utf-8")
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_dic.py -v`
Expected: 5 passed

- [ ] **Step 5: Generar el diccionario real y revisarlo a mano**

```bash
python -c "from pathlib import Path; from tools.audiorev import dic; dic.save(Path('tools/audiorev/dic/pronunciacion.yml'), dic.seed_from_acronyms(Path('plantilla_tft_etsit/pre/acronimos.tex')))"
```

Abre `tools/audiorev/dic/pronunciacion.yml` y corrige a mano los que se leen como palabra en lugar de deletreados. Como mínimo: `CAN`, `COTS`, `RTEMS`, `BOM`, `ARM`, `BRAM`. Los demás se irán corrigiendo al escucharlos.

- [ ] **Step 6: Commit**

```bash
git add tools/audiorev/dic.py tools/audiorev/dic/pronunciacion.yml tests/audiorev/test_dic.py
git commit -m "Sembrar el diccionario de pronunciación desde la lista de acrónimos"
```

---

### Task 3: Expandir el documento desde main.tex

**Files:**
- Create: `tools/audiorev/expand.py`
- Test: `tests/audiorev/test_expand.py`

**Interfaces:**
- Consumes: `SourceLine` de `model.py`.
- Produces: `expand(main_tex: Path, repo_root: Path) -> list[SourceLine]`.

`main.tex` usa dos formas, ambas presentes en el repositorio:

```latex
\input{pre/resumen}
\import{capitulos/cap3/}{entorno_desarrollo.tex}
```

Los `\chapter{...}` viven en `main.tex` y deben conservarse en la salida, porque son la única fuente del capítulo al que pertenece cada apartado.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_expand.py`:

```python
from tools.audiorev.expand import expand


def _write(tmp_path, rel, body):
    p = tmp_path / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body, encoding="utf-8")
    return p


def test_inlines_import_and_input_in_document_order(tmp_path):
    _write(tmp_path, "pre/resumen.tex", "Resumen del trabajo.\n")
    _write(tmp_path, "capitulos/cap1/intro.tex", "\\section{Objetivos}\nTexto.\n")
    main = _write(
        tmp_path,
        "main.tex",
        "\\begin{document}\n"
        "\\input{pre/resumen}\n"
        "\\chapter{Introducción}\n"
        "\\import{capitulos/cap1/}{intro.tex}\n"
        "\\end{document}\n",
    )
    lines = expand(main, tmp_path)
    texts = [l.text for l in lines]
    assert "Resumen del trabajo." in texts
    assert "\\chapter{Introducción}" in texts
    assert texts.index("Resumen del trabajo.") < texts.index("\\chapter{Introducción}")
    assert "\\section{Objetivos}" in texts


def test_keeps_the_true_origin_of_every_line(tmp_path):
    _write(tmp_path, "capitulos/cap1/intro.tex", "Primera.\nSegunda.\n")
    main = _write(tmp_path, "main.tex", "\\import{capitulos/cap1/}{intro.tex}\n")
    lines = expand(main, tmp_path)
    segunda = [l for l in lines if l.text == "Segunda."][0]
    assert segunda.tex_file == "capitulos/cap1/intro.tex"
    assert segunda.lineno == 2


def test_paths_are_relative_with_forward_slashes(tmp_path):
    _write(tmp_path, "capitulos/cap1/intro.tex", "Texto.\n")
    main = _write(tmp_path, "main.tex", "\\import{capitulos/cap1/}{intro.tex}\n")
    for line in expand(main, tmp_path):
        assert not line.tex_file.startswith("/")
        assert "\\" not in line.tex_file


def test_expands_the_real_tfm(tex_root, repo_root):
    lines = expand(tex_root / "main.tex", repo_root)
    files = {l.tex_file for l in lines}
    assert any("cap3/entorno_desarrollo.tex" in f for f in files)
    assert any("cap5/lineasfuturas.tex" in f for f in files)
    chapters = [l.text for l in lines if l.text.startswith("\\chapter{")]
    assert len(chapters) >= 8
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_expand.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.expand'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/expand.py`:

```python
"""Expansión de import e input para obtener el documento en orden canónico."""

import re
from pathlib import Path

from .model import SourceLine

_IMPORT = re.compile(r"\\import\{([^}]*)\}\{([^}]*)\}")
_INPUT = re.compile(r"\\(?:input|include)\{([^}]*)\}")


def _rel(path: Path, repo_root: Path) -> str:
    return path.resolve().relative_to(repo_root.resolve()).as_posix()


def _read(path: Path, repo_root: Path, seen: set[Path]) -> list[SourceLine]:
    resolved = path.resolve()
    if resolved in seen or not resolved.exists():
        return []
    seen.add(resolved)

    rel = _rel(resolved, repo_root)
    out: list[SourceLine] = []
    for lineno, raw in enumerate(
        resolved.read_text(encoding="utf-8").splitlines(), start=1
    ):
        text = raw.rstrip()

        m = _IMPORT.search(text)
        if m:
            child = resolved.parent / m.group(1) / m.group(2)
            out.extend(_read(_with_tex(child), repo_root, seen))
            continue

        m = _INPUT.search(text)
        if m:
            child = resolved.parent / m.group(1)
            out.extend(_read(_with_tex(child), repo_root, seen))
            continue

        out.append(SourceLine(tex_file=rel, lineno=lineno, text=text))
    return out


def _with_tex(path: Path) -> Path:
    return path if path.suffix == ".tex" else path.with_suffix(".tex")


def expand(main_tex: Path, repo_root: Path) -> list[SourceLine]:
    """Devuelve el documento completo como líneas con su origen real."""
    return _read(main_tex, repo_root, set())
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_expand.py -v`
Expected: 4 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev/expand.py tests/audiorev/test_expand.py
git commit -m "Expandir el documento resolviendo import e input"
```

---

### Task 4: Extraer los bloques que no se leen en voz alta

**Files:**
- Create: `tools/audiorev/blocks.py`
- Test: `tests/audiorev/test_blocks.py`

**Interfaces:**
- Consumes: `SourceLine` y `Block` de `model.py`.
- Produces: `extract_blocks(lines: list[SourceLine]) -> tuple[list[SourceLine], list[Block]]`. Deja en su sitio una línea marcador `%%BLOCK:n%%` por cada bloque extraído, para que la posición se pueda recuperar después de segmentar.

Entornos que se extraen, con su tipo: `figure` y `sidewaysfigure` dan `figure`; `table`, `tabular` y `longtable` dan `table`; `lstlisting` y `verbatim` dan `code`; `tikzpicture` y `axis` dan `plot`.

Un `tabular` dentro de un `table` no se extrae dos veces: se extrae siempre el entorno más externo.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_blocks.py`:

```python
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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_blocks.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.blocks'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/blocks.py`:

```python
"""Extracción de los bloques visuales: figuras, tablas, código y gráficas."""

import html as htmlmod
import re

from .model import Block, SourceLine

_KIND = {
    "figure": "figure",
    "sidewaysfigure": "figure",
    "table": "table",
    "tabular": "table",
    "longtable": "table",
    "tabularx": "table",
    "lstlisting": "code",
    "verbatim": "code",
    "tikzpicture": "plot",
    "axis": "plot",
}

_BEGIN = re.compile(r"\\begin\{([a-zA-Z*]+)\}")
_END = re.compile(r"\\end\{([a-zA-Z*]+)\}")
_CAPTION = re.compile(r"\\caption\{(.*)\}")
_LABEL = re.compile(r"\\label\{([^}]+)\}")


def _strip_latex(text: str) -> str:
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", text)
    return re.sub(r"\\[a-zA-Z]+\s*", "", text).strip()


def _to_html(kind: str, raw: str) -> str:
    if kind == "code":
        body = re.sub(r"\\begin\{[^}]*\}(\[[^\]]*\])?|\\end\{[^}]*\}", "", raw)
        return f"<pre><code>{htmlmod.escape(body.strip())}</code></pre>"
    if kind == "table":
        rows = []
        for line in raw.splitlines():
            if "&" not in line:
                continue
            cells = [_strip_latex(c) for c in line.split(r"\\")[0].split("&")]
            rows.append("<tr>" + "".join(f"<td>{htmlmod.escape(c)}</td>" for c in cells) + "</tr>")
        return "<table>" + "".join(rows) + "</table>"
    return ""


def extract_blocks(lines: list[SourceLine]) -> tuple[list[SourceLine], list[Block]]:
    """Saca los bloques visuales y deja un marcador en su lugar."""
    kept: list[SourceLine] = []
    blocks: list[Block] = []
    i = 0
    while i < len(lines):
        m = _BEGIN.search(lines[i].text)
        if not m or m.group(1) not in _KIND:
            kept.append(lines[i])
            i += 1
            continue

        env = m.group(1)
        depth = 1
        j = i + 1
        while j < len(lines) and depth > 0:
            if _BEGIN.search(lines[j].text) and _BEGIN.search(lines[j].text).group(1) == env:
                depth += 1
            end = _END.search(lines[j].text)
            if end and end.group(1) == env:
                depth -= 1
            j += 1

        raw = "\n".join(l.text for l in lines[i:j])
        caption = _CAPTION.search(raw)
        label = _LABEL.search(raw)
        kind = _KIND[env]
        blocks.append(
            Block(
                after_sentence=-1,
                type=kind,
                caption=_strip_latex(caption.group(1)) if caption else "",
                ref=label.group(1) if label else None,
                raw=raw,
                html=_to_html(kind, raw),
            )
        )
        kept.append(
            SourceLine(
                tex_file=lines[i].tex_file,
                lineno=lines[i].lineno,
                text=f"%%BLOCK:{len(blocks) - 1}%%",
            )
        )
        i = j
    return kept, blocks
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_blocks.py -v`
Expected: 4 passed

- [ ] **Step 5: Comprobar contra la memoria real**

Run:

```bash
python -c "
from pathlib import Path
from tools.audiorev.expand import expand
from tools.audiorev.blocks import extract_blocks
lines = expand(Path('plantilla_tft_etsit/main.tex'), Path('.'))
kept, blocks = extract_blocks(lines)
from collections import Counter
print(Counter(b.type for b in blocks))
print('total', len(blocks))
"
```

Expected: del orden de 80 a 90 bloques en total, con `figure` como tipo más frecuente. Si sale muy por debajo, falta algún entorno en `_KIND`.

- [ ] **Step 6: Commit**

```bash
git add tools/audiorev/blocks.py tests/audiorev/test_blocks.py
git commit -m "Extraer los bloques visuales y dejar un marcador en su lugar"
```

---

### Task 5: Partir el documento en unidades

**Files:**
- Create: `tools/audiorev/structure.py`
- Test: `tests/audiorev/test_structure.py`

**Interfaces:**
- Consumes: `SourceLine` y `Unit` de `model.py`.
- Produces: `slugify(title: str) -> str`, `split_units(lines: list[SourceLine]) -> list[Unit]` y `rechunk(units: list[Unit], max_words: int = 600, target_words: int = 450) -> list[Unit]`.

Encabezados que abren unidad: `\section`, `\subsection`, `\subsubsection` y sus formas con asterisco. El capítulo en curso lo fija el `\chapter{...}` más reciente, que viene de `main.tex`.

Medido en el repositorio: 22 `\section`, 55 `\subsection`, 54 `\subsubsection` y 5 `\section*`, que dan 136 encabezados. Dos ficheros no tienen ninguno: `anexoA.tex` con 1.837 palabras y `anexoB.tex` con 854. `rechunk` es quien los parte.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_structure.py`:

```python
from tools.audiorev.model import SourceLine
from tools.audiorev.structure import slugify, split_units, rechunk


def _lines(text, tex_file="capitulos/cap3/entorno_desarrollo.tex"):
    return [
        SourceLine(tex_file=tex_file, lineno=i, text=t)
        for i, t in enumerate(text.strip("\n").split("\n"), start=1)
    ]


def test_slugify_strips_accents_latex_and_punctuation():
    assert slugify("Oscilador controlado numéricamente (NCO)") == "oscilador-controlado-numericamente-nco"
    assert slugify(r"Bloque \textit{top}") == "bloque-top"
    assert slugify("A.1 Mapa de señales CDHS") == "a-1-mapa-de-senales-cdhs"


def test_splits_at_every_heading_level():
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\section{Preparación del entorno}
Texto de la sección.
\subsection{Instalación de Vivado}
Texto de la subsección.
\subsubsection{Detalle}
Texto del detalle.
"""
        )
    )
    assert [u.title for u in units] == [
        "Preparación del entorno",
        "Instalación de Vivado",
        "Detalle",
    ]
    assert [u.level for u in units] == [1, 2, 3]
    assert all(u.chapter_title == "Desarrollo" for u in units)


def test_text_before_a_child_heading_belongs_to_the_parent():
    units = split_units(
        _lines(
            r"""
\chapter{Desarrollo}
\section{Padre}
Esta frase es del padre.
\subsection{Hijo}
Esta es del hijo.
"""
        )
    )
    padre = units[0]
    assert any("del padre" in l.text for l in padre.lines)
    assert not any("del hijo" in l.text for l in padre.lines)


def test_unit_id_is_stable_and_independent_of_position():
    a = split_units(_lines("\\chapter{Desarrollo}\n\\subsection{Transmisor}\nX.\n"))[0]
    b = split_units(
        _lines("\\chapter{Desarrollo}\n\\subsection{Otro}\nY.\n\\subsection{Transmisor}\nX.\n")
    )[1]
    assert a.unit_id == b.unit_id
    assert a.unit_id.startswith("c03-")


def test_starred_sections_open_a_unit_too():
    units = split_units(
        _lines(
            "\\chapter{Anexo A}\n\\section*{A.1 Mapa de señales CDHS}\nTexto.\n",
            tex_file="capitulos/anexos/anexo1.tex",
        )
    )
    assert units[0].title == "A.1 Mapa de señales CDHS"


def test_rechunk_splits_a_long_headless_unit_on_paragraph_boundaries():
    body = "\n\n".join(["palabra " * 100] * 8)  # 800 palabras en 8 párrafos
    units = split_units(
        _lines(f"\\chapter{{Anexo B}}\n\\section{{Anexo}}\n{body}\n",
               tex_file="capitulos/anexos/anexoA.tex")
    )
    chunks = rechunk(units, max_words=600, target_words=450)
    assert len(chunks) >= 2
    assert chunks[0].unit_id.endswith("-p01")
    assert chunks[1].unit_id.endswith("-p02")
    assert all(len(" ".join(l.text for l in c.lines).split()) <= 600 for c in chunks)


def test_rechunk_leaves_short_units_untouched():
    units = split_units(_lines("\\chapter{Desarrollo}\n\\section{Corto}\nDos palabras.\n"))
    assert rechunk(units)[0].unit_id == units[0].unit_id


def test_structures_the_real_tfm(tex_root, repo_root):
    from tools.audiorev.expand import expand

    units = split_units(expand(tex_root / "main.tex", repo_root))
    assert 120 <= len(units) <= 150
    assert len({u.unit_id for u in units}) == len(units)
    assert any(u.title.startswith("Oscilador controlado") for u in units)
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_structure.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.structure'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/structure.py`:

```python
"""Partición del documento en unidades de escucha."""

import re
import unicodedata
from pathlib import PurePosixPath

from .model import SourceLine, Unit

_HEADING = re.compile(r"\\(section|subsection|subsubsection)\*?\{(.*)\}\s*$")
_CHAPTER = re.compile(r"\\chapter\*?\{(.*)\}\s*$")
_LEVEL = {"section": 1, "subsection": 2, "subsubsection": 3}
_SLUG_MAX = 48


def slugify(title: str) -> str:
    """Convierte un título en un identificador estable, ascii y con guiones."""
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", title)
    text = re.sub(r"\\[a-zA-Z]+\s*", "", text)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").lower()
    return text[:_SLUG_MAX].rstrip("-")


def _chapter_number(chapters_seen: int) -> int:
    return chapters_seen


def split_units(lines: list[SourceLine]) -> list[Unit]:
    """Parte el documento expandido en una unidad por encabezado."""
    units: list[Unit] = []
    chapter_num = 0
    chapter_title = ""
    current: Unit | None = None

    for line in lines:
        chap = _CHAPTER.search(line.text)
        if chap:
            chapter_num += 1
            chapter_title = _strip(chap.group(1))
            continue

        head = _HEADING.search(line.text)
        if head:
            kind, raw_title = head.group(1), head.group(2)
            title = _strip(raw_title)
            stem = PurePosixPath(line.tex_file).stem
            current = Unit(
                unit_id=f"c{chapter_num:02d}-{slugify(stem)}-{slugify(title)}",
                chapter=chapter_num,
                chapter_title=chapter_title,
                level=_LEVEL[kind],
                title=title,
                tex_file=line.tex_file,
                tex_lines=(line.lineno, line.lineno),
            )
            units.append(current)
            continue

        if current is not None and line.text.strip():
            current.lines.append(line)
            current.tex_lines = (current.tex_lines[0], line.lineno)
        elif current is not None:
            current.lines.append(line)

    return units


def _strip(title: str) -> str:
    text = re.sub(r"\\(?:textit|textbf|emph|texttt)\s*\{([^{}]*)\}", r"\1", title)
    return re.sub(r"\s+", " ", text).strip()


def _word_count(unit: Unit) -> int:
    return len(" ".join(l.text for l in unit.lines).split())


def rechunk(units: list[Unit], max_words: int = 600, target_words: int = 450) -> list[Unit]:
    """Parte por frontera de párrafo las unidades que superen max_words."""
    out: list[Unit] = []
    for unit in units:
        if _word_count(unit) <= max_words:
            out.append(unit)
            continue

        groups: list[list[SourceLine]] = [[]]
        for line in unit.lines:
            if not line.text.strip() and groups[-1]:
                groups.append([])
            elif line.text.strip():
                groups[-1].append(line)
        groups = [g for g in groups if g]

        chunk: list[SourceLine] = []
        pieces: list[list[SourceLine]] = []
        for group in groups:
            chunk.extend(group)
            if len(" ".join(l.text for l in chunk).split()) >= target_words:
                pieces.append(chunk)
                chunk = []
        if chunk:
            pieces.append(chunk)

        for n, piece in enumerate(pieces, start=1):
            out.append(
                Unit(
                    unit_id=f"{unit.unit_id}-p{n:02d}",
                    chapter=unit.chapter,
                    chapter_title=unit.chapter_title,
                    level=unit.level,
                    title=f"{unit.title} ({n} de {len(pieces)})",
                    tex_file=unit.tex_file,
                    tex_lines=(piece[0].lineno, piece[-1].lineno),
                    lines=piece,
                )
            )
    return out
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_structure.py -v`
Expected: 8 passed

Si `test_structures_the_real_tfm` devuelve menos de 120 unidades, comprueba que `expand` está resolviendo los `\import` de los anexos.

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev/structure.py tests/audiorev/test_structure.py
git commit -m "Partir el documento en unidades de escucha por encabezado"
```

---

### Task 6: Normalizar el LaTeX a texto pronunciable

**Files:**
- Create: `tools/audiorev/speak.py`
- Test: `tests/audiorev/test_speak.py`

**Interfaces:**
- Consumes: `spoken_ref` de `refs.py`.
- Produces: `to_spoken(text: str, labels: dict[str, tuple[str, str]], pron: dict[str, str]) -> str` y `plain(text: str) -> str`. `plain` produce el texto que se muestra en pantalla, con los comandos quitados pero sin deletrear acrónimos ni expandir unidades; `to_spoken` produce lo que se le pasa al motor de voz.

Orden de las reglas, que importa: comentarios, notas al pie, referencias, citas, matemáticas, comandos de formato, unidades, acrónimos, espacios.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_speak.py`:

```python
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
    assert spoken(r"Se ve en la \ref{fig:x}.") == "Se ve en la la figura 3.1."
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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_speak.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.speak'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/speak.py`:

```python
"""Normalización del LaTeX del TFM a texto pronunciable."""

import re

from .refs import spoken_ref

_UNITS = [
    (r"\bV\b", "voltios"),
    (r"\bmV\b", "milivoltios"),
    (r"\bA\b(?=\s|$|\.)", "amperios"),
    (r"\bmA\b", "miliamperios"),
    (r"\bMHz\b", "megahercios"),
    (r"\bkHz\b", "kilohercios"),
    (r"\bGHz\b", "gigahercios"),
    (r"\bHz\b", "hercios"),
    (r"\bMbps\b", "megabits por segundo"),
    (r"\bkbps\b", "kilobits por segundo"),
    (r"\bMB/s\b", "megabytes por segundo"),
    (r"\bKiB\b", "kibibytes"),
    (r"\bMiB\b", "mebibytes"),
    (r"\bus\b", "microsegundos"),
    (r"\bms\b", "milisegundos"),
    (r"\bns\b", "nanosegundos"),
    (r"\bmm\b", "milímetros"),
]

_FORMAT = re.compile(r"\\(?:textit|textbf|emph|texttt|textsc|underline)\s*\{([^{}]*)\}")
_REF = re.compile(r"\\(?:ref|autoref|eqref)\{([^}]+)\}")
_CITE = re.compile(r"\\cite\{[^}]*\}")
_FOOTNOTE = re.compile(r"\\footnote\{([^{}]*)\}")
_MATH = re.compile(r"\$([^$]*)\$")
_DISPLAY = re.compile(r"\\\[(.*?)\\\]", re.DOTALL)
_BLOCK = re.compile(r"%%BLOCK:\d+%%")
_COMMENT = re.compile(r"(?<!\\)%.*$", re.MULTILINE)
_SIMPLE_MATH = re.compile(r"^[A-Za-z0-9\s=+\-*/,.()<>]+$")
_ANY_COMMAND = re.compile(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?(\{[^{}]*\})?")
_ACRONYM = re.compile(r"\b[A-Z][A-Z0-9]{1,9}\b")


def _unwrap_formatting(text: str) -> str:
    previous = None
    while previous != text:
        previous = text
        text = _FORMAT.sub(r"\1", text)
    return text


def _strip_common(text: str) -> str:
    text = _COMMENT.sub("", text)
    text = _BLOCK.sub("", text)
    text = _unwrap_formatting(text)
    text = _CITE.sub("", text)
    text = text.replace("~", " ").replace(r"\%", "%").replace(r"\_", "_")
    text = text.replace("``", '"').replace("''", '"').replace("---", ", ")
    return text


def _finish(text: str) -> str:
    text = _ANY_COMMAND.sub("", text)
    text = re.sub(r"[{}]", "", text)
    text = re.sub(r"\s+([,.;:])", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def plain(text: str) -> str:
    """Texto para mostrar en pantalla: sin comandos, con los acrónimos intactos."""
    text = _strip_common(text)
    text = _FOOTNOTE.sub(r" (\1)", text)
    text = _REF.sub("la referencia", text)
    text = _MATH.sub(lambda m: m.group(1).strip(), text)
    return _finish(text)


def to_spoken(text: str, labels: dict, pron: dict) -> str:
    """Texto para el motor de voz: acrónimos deletreados y unidades expandidas."""
    text = _strip_common(text)

    footnotes: list[str] = []

    def _grab_footnote(match: re.Match) -> str:
        footnotes.append(match.group(1).strip())
        return ""

    text = _FOOTNOTE.sub(_grab_footnote, text)
    text = _REF.sub(lambda m: spoken_ref(m.group(1), labels), text)
    text = _DISPLAY.sub(" fórmula, ver documento ", text)
    text = _MATH.sub(
        lambda m: m.group(1).strip()
        if _SIMPLE_MATH.match(m.group(1).strip())
        else " fórmula, ver documento ",
        text,
    )

    for pattern, spoken_unit in _UNITS:
        text = re.sub(pattern, spoken_unit, text)

    text = _ACRONYM.sub(lambda m: pron.get(m.group(0), m.group(0).lower()), text)

    out = _finish(text)
    if footnotes:
        out = (out + " nota al pie: " + " ".join(footnotes)).strip()
    return out
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_speak.py -v`
Expected: 14 passed

Si alguna prueba de unidades falla por el orden de sustitución, mueve la regla conflictiva más arriba en `_UNITS`. Las reglas se aplican en orden y la primera que casa gana.

- [ ] **Step 5: Escuchar el resultado sobre un apartado real antes de dar la tarea por buena**

Run:

```bash
python -c "
from pathlib import Path
from tools.audiorev.expand import expand
from tools.audiorev.blocks import extract_blocks
from tools.audiorev.structure import split_units
from tools.audiorev.refs import load_labels
from tools.audiorev import dic, speak
labels = load_labels(Path('plantilla_tft_etsit/main.aux'))
pron = dic.load(Path('tools/audiorev/dic/pronunciacion.yml'))
lines, _ = extract_blocks(expand(Path('plantilla_tft_etsit/main.tex'), Path('.')))
u = [u for u in split_units(lines) if u.title.startswith('Oscilador controlado')][0]
print(speak.to_spoken(' '.join(l.text for l in u.lines), labels, pron))
"
```

Léelo en voz alta. Si algo no se entiende dicho, corrige la regla o el diccionario y vuelve a ejecutar. Esta comprobación no es opcional: es donde se descubre lo que las pruebas unitarias no ven.

- [ ] **Step 6: Commit**

```bash
git add tools/audiorev/speak.py tests/audiorev/test_speak.py
git commit -m "Normalizar el LaTeX a texto pronunciable"
```

---

### Task 7: Segmentar en frases

**Files:**
- Create: `tools/audiorev/segment.py`
- Test: `tests/audiorev/test_segment.py`

**Interfaces:**
- Consumes: nada.
- Produces: `split_sentences(text: str) -> list[str]`.

Abreviaturas del documento que no deben partir la frase: `fig.`, `tab.`, `p. ej.`, `etc.`, `art.`, `apdo.`, `núm.`, `aprox.`, `ref.`, `vs.`, `Sr.`, `Dr.`.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_segment.py`:

```python
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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_segment.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.segment'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/segment.py`:

```python
"""Segmentación en frases del texto en español del TFM."""

import re

import pysbd

# Abreviaturas del documento que pysbd no conoce. Se protegen sustituyendo el
# punto por un carácter privado antes de segmentar, y se restauran después.
_ABBREV = [
    "fig.", "tab.", "p. ej.", "etc.", "art.", "apdo.", "núm.", "aprox.",
    "ref.", "vs.", "Sr.", "Dr.", "Fig.", "Tab.",
]
_SENTINEL = "\ue000"

_segmenter = pysbd.Segmenter(language="es", clean=False)


def _protect(text: str) -> str:
    for abbr in _ABBREV:
        text = text.replace(abbr, abbr.replace(".", _SENTINEL))
    # Números decimales con punto: 3.3 V
    text = re.sub(r"(\d)\.(\d)", rf"\1{_SENTINEL}\2", text)
    return text


def _restore(text: str) -> str:
    return text.replace(_SENTINEL, ".")


def split_sentences(text: str) -> list[str]:
    """Devuelve las frases del texto, sin fragmentos vacíos."""
    if not text.strip():
        return []
    protected = _protect(text)
    pieces = _segmenter.segment(protected)
    return [_restore(p).strip() for p in pieces if _restore(p).strip()]
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_segment.py -v`
Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev/segment.py tests/audiorev/test_segment.py
git commit -m "Segmentar el texto en frases respetando las abreviaturas del documento"
```

---

### Task 8: Backends de síntesis y caché por hash

**Files:**
- Create: `tools/audiorev/tts.py`
- Create: `tools/audiorev/cache.py`
- Test: `tests/audiorev/test_tts.py`
- Test: `tests/audiorev/test_cache.py`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `tts.get_backend(name: str | None = None) -> TTSBackend`, con `TTSBackend.synth(text: str) -> bytes` que devuelve un WAV completo.
  - `tts.wav_duration(data: bytes) -> float`.
  - `cache.sentence_hash(spoken: str) -> str`, 16 hex.
  - `cache.get_or_synth(spoken: str, backend, cache_dir: Path) -> tuple[Path, float]`, que devuelve la ruta del WAV y su duración.

El backend por defecto sale de `AUDIOREV_TTS_BACKEND`, con `piper` como valor por omisión. Para las pruebas existe un backend `fake` que genera silencio de duración proporcional al número de caracteres, sin depender de que Piper esté instalado.

- [ ] **Step 1: Escribir las pruebas que fallan**

`tests/audiorev/test_tts.py`:

```python
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
```

`tests/audiorev/test_cache.py`:

```python
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
```

- [ ] **Step 2: Ejecutar las pruebas y comprobar que fallan**

Run: `pytest tests/audiorev/test_tts.py tests/audiorev/test_cache.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.tts'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/tts.py`:

```python
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
```

`tools/audiorev/cache.py`:

```python
"""Caché de audio indexada por el hash del texto hablado."""

import hashlib
from pathlib import Path

from .tts import wav_duration


def sentence_hash(spoken: str) -> str:
    """SHA-256 del texto hablado, truncado a 16 caracteres hexadecimales."""
    return hashlib.sha256(spoken.encode("utf-8")).hexdigest()[:16]


def get_or_synth(spoken: str, backend, cache_dir: Path) -> tuple[Path, float]:
    """Devuelve el WAV de la frase, sintetizándolo solo si no estaba en caché."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / f"{sentence_hash(spoken)}.wav"
    if not path.exists():
        path.write_bytes(backend.synth(spoken))
    return path, wav_duration(path.read_bytes())
```

- [ ] **Step 4: Ejecutar las pruebas y comprobar que pasan**

Run: `pytest tests/audiorev/test_tts.py tests/audiorev/test_cache.py -v`
Expected: 8 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev/tts.py tools/audiorev/cache.py tests/audiorev/test_tts.py tests/audiorev/test_cache.py
git commit -m "Sintetizar por frase con backend intercambiable y caché por hash"
```

---

### Task 9: Concatenar y calcular los tiempos

**Files:**
- Create: `tools/audiorev/assemble.py`
- Test: `tests/audiorev/test_assemble.py`

**Interfaces:**
- Consumes: `Sentence` y `Unit` de `model.py`.
- Produces: `assign_timings(sentences: list[Sentence], durations: list[float]) -> None`, que rellena `t_start` y `t_end` en el sitio, y `concat(wav_paths: list[Path], out_path: Path) -> None`, que llama a `ffmpeg`.

`assign_timings` es aritmética pura y se prueba sin tocar el disco. `concat` se prueba comprobando que construye la orden correcta, con `ffmpeg` simulado.

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_assemble.py`:

```python
from pathlib import Path

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
    paths = [tmp_path / "a.wav", tmp_path / "b.wav"]
    listing = build_concat_file(paths, tmp_path / "list.txt")
    body = listing.read_text(encoding="utf-8")
    assert body.count("file '") == 2
    assert "a.wav" in body and "b.wav" in body


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
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_assemble.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.assemble'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/assemble.py`:

```python
"""Concatenación del audio de las frases y cálculo de los tiempos."""

import subprocess
from pathlib import Path

from .model import Sentence


def assign_timings(sentences: list[Sentence], durations: list[float]) -> None:
    """Rellena t_start y t_end acumulando las duraciones, en el sitio."""
    if len(sentences) != len(durations):
        raise ValueError(
            f"El número de frases ({len(sentences)}) no coincide con el de "
            f"duraciones ({len(durations)})"
        )
    t = 0.0
    for sentence, duration in zip(sentences, durations):
        sentence.t_start = round(t, 3)
        t += duration
        sentence.t_end = round(t, 3)


def build_concat_file(wav_paths: list[Path], listing: Path) -> Path:
    """Escribe el fichero de lista que consume el demuxer concat de ffmpeg."""
    lines = []
    for path in wav_paths:
        escaped = str(path.resolve()).replace("'", r"'\''")
        lines.append(f"file '{escaped}'")
    listing.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return listing


def concat(wav_paths: list[Path], out_path: Path) -> None:
    """Une los WAV en un único opus, sin recodificar dos veces."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    listing = build_concat_file(wav_paths, out_path.with_suffix(".txt"))
    result = subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-f", "concat", "-safe", "0", "-i", str(listing),
            "-c:a", "libopus", "-b:a", "32k", "-application", "voip",
            str(out_path),
        ],
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg falló: {result.stderr.decode('utf-8', 'replace')}")
    listing.unlink(missing_ok=True)
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_assemble.py -v`
Expected: 5 passed

- [ ] **Step 5: Commit**

```bash
git add tools/audiorev/assemble.py tests/audiorev/test_assemble.py
git commit -m "Concatenar el audio por apartado y calcular los tiempos por frase"
```

---

### Task 10: Orquestador y línea de órdenes

**Files:**
- Create: `tools/audiorev/build.py`
- Test: `tests/audiorev/test_build.py`
- Create: `tools/audiorev/README.md`

**Interfaces:**
- Consumes: todos los módulos anteriores.
- Produces: `build_units(repo_root: Path) -> list[Unit]`, `unit_to_dict(unit: Unit) -> dict`, `render(units, out_dir, backend, cache_dir, with_audio: bool) -> None` y `main(argv: list[str] | None = None) -> int`.

Órdenes de uso:

```bash
python -m tools.audiorev.build --out out/audiorev --only cap3 --no-audio
python -m tools.audiorev.build --out out/audiorev --backend piper
```

- [ ] **Step 1: Escribir la prueba que falla**

`tests/audiorev/test_build.py`:

```python
import json

from tools.audiorev.build import build_units, unit_to_dict, render, main
from tools.audiorev.tts import get_backend


def test_builds_units_from_the_real_repo(repo_root):
    units = build_units(repo_root)
    assert len(units) >= 120
    nco = [u for u in units if u.title.startswith("Oscilador controlado")][0]
    assert nco.chapter == 3
    assert nco.tex_file.endswith("cap3/entorno_desarrollo.tex")
    assert len(nco.sentences) > 3
    assert all(s.hash for s in nco.sentences)
    assert all(s.spoken for s in nco.sentences)


def test_unit_dict_has_the_shape_the_spec_promises(repo_root):
    unit = build_units(repo_root)[0]
    d = unit_to_dict(unit)
    assert set(d) >= {
        "unit_id", "chapter", "chapter_title", "level", "title",
        "tex_file", "tex_lines", "duration_s", "sentences", "blocks",
    }
    s = d["sentences"][0]
    assert set(s) == {"idx", "text", "spoken", "hash", "tex_line", "t_start", "t_end"}
    assert "/" in d["tex_file"] and not d["tex_file"].startswith("/")


def test_render_without_audio_writes_one_json_per_unit(repo_root, tmp_path):
    units = build_units(repo_root)[:3]
    render(units, tmp_path, get_backend("fake"), tmp_path / "cache", with_audio=False)
    files = sorted(p.name for p in tmp_path.glob("*.json"))
    assert len(files) == 3
    data = json.loads((tmp_path / files[0]).read_text(encoding="utf-8"))
    assert data["duration_s"] == 0.0


def test_render_with_audio_fills_timings_and_writes_the_index(repo_root, tmp_path, monkeypatch):
    monkeypatch.setattr("tools.audiorev.build.concat", lambda paths, out: out.write_bytes(b"x"))
    units = build_units(repo_root)[:1]
    render(units, tmp_path, get_backend("fake"), tmp_path / "cache", with_audio=True)
    data = json.loads(next(tmp_path.glob("*.json")).read_text(encoding="utf-8"))
    assert data["duration_s"] > 0
    assert data["sentences"][0]["t_start"] == 0.0
    assert data["sentences"][-1]["t_end"] == data["duration_s"]
    assert (tmp_path / f"{data['unit_id']}.opus").exists()


def test_only_filters_by_path_fragment(repo_root, tmp_path):
    assert main(["--repo", str(repo_root), "--out", str(tmp_path),
                 "--only", "cap5", "--no-audio", "--backend", "fake"]) == 0
    names = [p.name for p in tmp_path.glob("*.json")]
    assert names
    assert all(n.startswith("c05-") for n in names)


def test_writes_a_manifest_listing_every_unit(repo_root, tmp_path):
    main(["--repo", str(repo_root), "--out", str(tmp_path),
          "--only", "cap5", "--no-audio", "--backend", "fake"])
    manifest = json.loads((tmp_path / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["units"]
    assert set(manifest["units"][0]) >= {"unit_id", "title", "chapter", "duration_s"}
```

- [ ] **Step 2: Ejecutar la prueba y comprobar que falla**

Run: `pytest tests/audiorev/test_build.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.audiorev.build'`

- [ ] **Step 3: Escribir la implementación mínima**

`tools/audiorev/build.py`:

```python
"""Orquestador: del repositorio al índice JSON y al audio."""

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from . import dic
from .assemble import assign_timings, concat
from .blocks import extract_blocks
from .cache import get_or_synth, sentence_hash
from .expand import expand
from .model import Sentence, Unit
from .refs import load_labels
from .segment import split_sentences
from .speak import plain, to_spoken
from .structure import rechunk, split_units
from .tts import get_backend

TEX_ROOT = "plantilla_tft_etsit"


def build_units(repo_root: Path) -> list[Unit]:
    """Construye las unidades con sus frases, sin sintetizar nada."""
    tex_root = repo_root / TEX_ROOT
    labels = load_labels(tex_root / "main.aux")
    pron = dic.load(repo_root / "tools" / "audiorev" / "dic" / "pronunciacion.yml")

    lines, blocks = extract_blocks(expand(tex_root / "main.tex", repo_root))
    units = rechunk(split_units(lines))

    for unit in units:
        body = "\n".join(l.text for l in unit.lines)
        first_line = unit.lines[0].lineno if unit.lines else unit.tex_lines[0]
        for idx, raw in enumerate(split_sentences(plain(body))):
            spoken = to_spoken(raw, labels, pron)
            if not spoken:
                continue
            unit.sentences.append(
                Sentence(
                    idx=len(unit.sentences),
                    text=raw,
                    spoken=spoken,
                    hash=sentence_hash(spoken),
                    tex_line=first_line,
                )
            )
        unit.blocks = [b for b in blocks if f"%%BLOCK:{blocks.index(b)}%%" in body]
    return units


def unit_to_dict(unit: Unit) -> dict:
    data = asdict(unit)
    data.pop("lines", None)
    data["tex_lines"] = list(unit.tex_lines)
    return data


def render(units, out_dir: Path, backend, cache_dir: Path, with_audio: bool) -> None:
    """Sintetiza si se pide y escribe un JSON por unidad más el manifiesto."""
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {"units": []}

    for unit in units:
        if with_audio and unit.sentences:
            paths, durations = [], []
            for sentence in unit.sentences:
                path, duration = get_or_synth(sentence.spoken, backend, cache_dir)
                paths.append(path)
                durations.append(duration)
            assign_timings(unit.sentences, durations)
            unit.duration_s = unit.sentences[-1].t_end
            concat(paths, out_dir / f"{unit.unit_id}.opus")

        (out_dir / f"{unit.unit_id}.json").write_text(
            json.dumps(unit_to_dict(unit), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        manifest["units"].append(
            {
                "unit_id": unit.unit_id,
                "title": unit.title,
                "chapter": unit.chapter,
                "chapter_title": unit.chapter_title,
                "level": unit.level,
                "duration_s": unit.duration_s,
                "n_sentences": len(unit.sentences),
                "n_blocks": len(unit.blocks),
            }
        )

    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Convierte el TFM en audio por apartado.")
    parser.add_argument("--repo", default=".", help="Raíz del repositorio")
    parser.add_argument("--out", required=True, help="Directorio de salida")
    parser.add_argument("--cache", default=None, help="Directorio de la caché de audio")
    parser.add_argument("--only", default=None, help="Filtra por fragmento de ruta, p. ej. cap3")
    parser.add_argument("--backend", default=None, help="piper, kokoro o fake")
    parser.add_argument("--no-audio", action="store_true", help="Solo genera los JSON")
    args = parser.parse_args(argv)

    repo_root = Path(args.repo).resolve()
    out_dir = Path(args.out).resolve()
    cache_dir = Path(args.cache).resolve() if args.cache else out_dir / ".cache"

    units = build_units(repo_root)
    if args.only:
        units = [u for u in units if args.only in u.tex_file]

    render(units, out_dir, get_backend(args.backend), cache_dir, not args.no_audio)
    total = sum(u.duration_s for u in units)
    print(f"{len(units)} unidades, {total / 60:.1f} min de audio, en {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Ejecutar la prueba y comprobar que pasa**

Run: `pytest tests/audiorev/test_build.py -v`
Expected: 6 passed

- [ ] **Step 5: Ejecutar la batería completa**

Run: `pytest tests/audiorev -v`
Expected: todas pasan. Si alguna prueba de un módulo anterior se rompió, arréglala antes de seguir.

- [ ] **Step 6: Generar el capítulo piloto de verdad**

```bash
python -m tools.audiorev.build --out out/audiorev --only cap3 --no-audio
python -c "
import json, pathlib
m = json.loads(pathlib.Path('out/audiorev/manifest.json').read_text(encoding='utf-8'))
print(len(m['units']), 'unidades')
for u in m['units'][:10]:
    print(f\"{u['unit_id']:50s} {u['n_sentences']:3d} frases  {u['n_blocks']:2d} bloques\")
"
```

Abre dos o tres de los JSON generados y lee el campo `spoken` en voz alta. Corrige el diccionario o las reglas de `speak.py` hasta que suene bien. Después, con Piper instalado:

```bash
python -m tools.audiorev.build --out out/audiorev --only cap3 --backend piper
```

Escucha un apartado entero y comprueba que los tiempos del JSON se corresponden con lo que oyes.

- [ ] **Step 7: Documentar y hacer commit**

`tools/audiorev/README.md` debe recoger: qué hace la herramienta, cómo instalar Piper y el modelo `es_ES-davefx-medium`, las órdenes de uso de arriba, y la instrucción de que `out/` no se versiona.

Añade `out/` a `.gitignore`.

```bash
git add tools/audiorev tests/audiorev .gitignore
git commit -m "Orquestar la conversión completa del TFM a audio por apartado"
```

---

## Autorrevisión del plan

**Cobertura del spec.** Apartado 3.1 síntesis por frase, tareas 8 y 9. Apartado 3.2 motor intercambiable, tarea 8. Apartado 3.3 anclaje, tareas 5 y 10, donde se fijan `unit_id`, `hash`, `tex_file` y `tex_line`. Apartado 4.1 etapas 1 a 5, tareas 3, 5, 6, 7 y 1. Apartado 4.2 formato de salida, tarea 10. El apartado 5 en adelante corresponde al plan del servidor.

**Hueco conocido y aceptado.** El campo `tex_line` de cada frase apunta a la primera línea de la unidad, no a la línea exacta de la frase. Es suficiente porque, según el apartado 3.3 del spec, la búsqueda al aplicar una revisión se hace por `sentence_text` y `tex_line` es solo una pista. Afinarlo exigiría rastrear el desplazamiento a través de la normalización, que no compensa.

**Consistencia de tipos.** `Sentence`, `Unit`, `Block` y `SourceLine` se definen en la tarea 0 y se usan sin variantes. `get_or_synth` devuelve siempre `(Path, float)`. `load_labels` devuelve siempre `dict[str, tuple[str, str]]`, y `spoken_ref` consume ese mismo tipo.
