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
