"""Orquestador: del repositorio al índice JSON y al audio."""

import argparse
import json
import re
import sys
from dataclasses import asdict
from pathlib import Path

from . import dic
from .assemble import assign_timings, concat
from .blocks import extract_blocks, spoken_cue
from .cache import get_or_synth, sentence_hash
from .expand import expand
from .model import Sentence, Unit
from .refs import load_labels
from .segment import split_sentences
from .speak import plain, strip_comments, to_spoken
from .structure import rechunk, split_units
from .tts import get_backend

TEX_ROOT = "plantilla_tft_etsit"


_BLOCK_MARKER = re.compile(r"%%BLOCK:(\d+)%%")


def _raw_body(lines: list) -> tuple[str, list[int], list[tuple[int, int]]]:
    """Une las líneas de una unidad en un cuerpo en bruto y conserva el origen.

    Devuelve (cuerpo, línea de origen de cada carácter, marcadores). El cuerpo
    lleva los comentarios quitados y el espaciado colapsado a un solo espacio
    —el texto envuelve a 80 columnas en el .tex y ese salto no es un límite de
    frase—, pero se construye carácter a carácter para poder decir, de cada
    posición del cuerpo, en qué línea real del .tex está. Así `tex_line` es la
    línea de CADA frase y no la primera de la unidad.

    Los marcadores `%%BLOCK:n%%` no forman parte del cuerpo (el separador de
    comentarios los borraría, porque empiezan por `%`): se sacan aparte como
    (n, offset dentro del cuerpo) para poder situar el bloque entre las frases.
    """
    buf: list[str] = []
    origen: list[int] = []
    markers: list[tuple[int, int]] = []

    def push(text: str, lineno: int) -> None:
        for ch in text:
            if ch.isspace():
                if buf and buf[-1] != " ":
                    buf.append(" ")
                    origen.append(lineno)
            else:
                buf.append(ch)
                origen.append(lineno)

    for line in lines:
        pos = 0
        for m in _BLOCK_MARKER.finditer(line.text):
            push(strip_comments(line.text[pos : m.start()]), line.lineno)
            markers.append((int(m.group(1)), len(buf)))
            pos = m.end()
        push(strip_comments(line.text[pos:]), line.lineno)
        push("\n", line.lineno)

    body = "".join(buf).strip()
    return body, origen, markers


def build_units(repo_root: Path) -> list[Unit]:
    """Construye las unidades con sus frases, sin sintetizar nada."""
    tex_root = repo_root / TEX_ROOT
    labels = load_labels(tex_root / "main.aux")
    pron = dic.load(repo_root / "tools" / "audiorev" / "dic" / "pronunciacion.yml")

    lines, blocks = extract_blocks(expand(tex_root / "main.tex", repo_root))
    units = rechunk(split_units(lines))
    asignados: set[int] = set()

    for unit in units:
        body, origen, markers = _raw_body(unit.lines)

        def linea_de(offset: int) -> int:
            """Línea real del .tex en la que cae este offset del cuerpo."""
            if not origen:
                return unit.tex_lines[0]
            return origen[min(offset, len(origen) - 1)]

        def emitir_bloque(n: int, offset: int) -> None:
            """Sitúa el bloque n y añade su aviso hablado («tabla 4.2, ..., en
            pantalla», apartado 4 del diseño). `after_sentence` apunta a ese
            aviso; solo vale -1 si el bloque precede a toda la prosa de la
            unidad y no llegó a emitirse ningún aviso."""
            if n in asignados or n >= len(blocks):
                return
            asignados.add(n)
            block = blocks[n]
            cue = spoken_cue(block, labels)
            if cue:
                unit.sentences.append(
                    Sentence(
                        idx=len(unit.sentences),
                        text=cue,
                        spoken=to_spoken(cue, labels, pron),
                        hash=sentence_hash(to_spoken(cue, labels, pron)),
                        tex_line=linea_de(offset),
                        tex_raw="",
                    )
                )
            block.after_sentence = len(unit.sentences) - 1
            unit.blocks.append(block)

        # plain() y to_spoken() son dos normalizadores INDEPENDIENTES del
        # mismo LaTeX en bruto, no etapas de un pipeline: encadenarlos
        # (segmentar sobre la salida de plain() y luego pasar eso a
        # to_spoken()) destruye información que uno de los dos ya había
        # consumido (p. ej. un "\%" que plain() vuelve "%" bare, y que el
        # separador de comentarios de to_spoken() borra después). Por eso
        # aquí se segmenta el cuerpo en bruto y cada frase en bruto se pasa
        # por separado a plain() y a to_spoken().
        cursor = 0
        siguiente_marcador = 0
        for raw in split_sentences(body):
            pos = body.find(raw, cursor)
            if pos < 0:
                # La segmentación no devuelve el texto literal (no debería
                # pasar): se usa el cursor, que es una cota inferior correcta.
                pos = cursor
            cursor = pos + len(raw)

            while (
                siguiente_marcador < len(markers)
                and markers[siguiente_marcador][1] <= pos
            ):
                n, offset = markers[siguiente_marcador]
                emitir_bloque(n, offset)
                siguiente_marcador += 1

            spoken = to_spoken(raw, labels, pron)
            if not spoken:
                continue
            unit.sentences.append(
                Sentence(
                    idx=len(unit.sentences),
                    text=plain(raw),
                    spoken=spoken,
                    hash=sentence_hash(spoken),
                    tex_line=linea_de(pos),
                    tex_raw=raw,
                )
            )

        for n, offset in markers[siguiente_marcador:]:
            emitir_bloque(n, offset)
    return units


def unit_to_dict(unit: Unit) -> dict:
    data = asdict(unit)
    data.pop("lines", None)
    data["tex_lines"] = list(unit.tex_lines)
    return data


def render(units, out_dir: Path, backend, cache_dir: Path, with_audio: bool) -> None:
    """Sintetiza si se pide y escribe un JSON por unidad."""
    out_dir.mkdir(parents=True, exist_ok=True)

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


def write_manifest(units, out_dir: Path) -> None:
    """Escribe manifest.json con un resumen de cada unidad renderizada."""
    manifest = {
        "units": [
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
            for unit in units
        ]
    }
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
    write_manifest(units, out_dir)
    total = sum(u.duration_s for u in units)
    print(f"{len(units)} unidades, {total / 60:.1f} min de audio, en {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
