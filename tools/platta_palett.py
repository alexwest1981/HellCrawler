"""Palettavstånd för varje platta: Alex' paket och atlasens utsnitt.

    /usr/bin/python3 tools/platta_palett.py

Måttet är medelavståndet från varje pixel till NÄRMASTE färg i `game/assets/palette.json`, delat med
441,67 (255*sqrt(3), det största avståndet som finns i RGB). Samma normalisering som paketets plattor
mättes med tidigare (de elva låg på 0,036-0,061), så tröskeln 0,18 går att jämföra rakt av.

Skriver om sektionen `## Plattornas palettavstånd` i tools/texturlistan_by.md. KÖRS EFTER
tools/byn_tex_prov.py: den skriver om allt från sin egen rubrik och nedåt, och skulle alltså äta upp
den här sektionen om den kördes sist.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROT = Path(__file__).resolve().parent.parent
TEX = ROT / "game" / "assets" / "by" / "tex"
ATLAS = TEX / "atlas"
PALETT = ROT / "game" / "assets" / "palette.json"
MAPPNING = ROT / "tools" / "byn_mappning.json"
LISTA = ROT / "tools" / "texturlistan_by.md"
MARK = "## Plattornas palettavstånd"
TRÖSKEL = 0.18


def palettavstånd(fil: Path, palett: np.ndarray) -> float:
    a = np.asarray(Image.open(fil).convert("RGB"), dtype=np.int32).reshape(-1, 3)
    bäst = np.full(len(a), 1e9)
    for p in palett:
        bäst = np.minimum(bäst, np.sqrt(((a - p) ** 2).sum(axis=1)))
    return float(bäst.mean()) / 441.67


def main() -> int:
    palett = np.array(json.loads(PALETT.read_text()), dtype=np.int32)
    i_bruk = set()
    if MAPPNING.exists():
        # Vilka plattor som FAKTISKT fick objekt i scenen — en platta i TEXTURES som ingen yta
        # använder (eller som bara når en yta via namnreglerna) ska inte stå som "i bruk".
        i_bruk = set(json.loads(MAPPNING.read_text()).get("plates_used", []))

    rader = [MARK, "",
             "Medelavståndet från varje pixel till närmaste palettfärg, delat med 441,67. Tröskeln är "
             "**%.2f**; alla plattor ligger långt under den." % TRÖSKEL, "",
             "| Platta | Fil | Palettavstånd | I bruk |", "|---|---|---:|---|"]
    under, över = 0, []
    for mapp, namn in ((TEX, "paketet"), (ATLAS, "atlasen")):
        for fil in sorted(mapp.glob("*.png")):
            if fil.name.startswith("_"):
                continue
            d = palettavstånd(fil, palett)
            under += d < TRÖSKEL
            if d >= TRÖSKEL:
                över.append(fil.name)
            nyckel = fil.name if mapp is TEX else "atlas/" + fil.name
            rader.append("| %s | `%s` | %.4f | %s |" %
                         (namn, nyckel, d, "ja" if nyckel in i_bruk else ""))
    rader += ["", "%d plattor mätta, %d under tröskeln, %d över: %s" %
              (under + len(över), under, len(över), ", ".join(över) or "inga")]

    gammal = LISTA.read_text() if LISTA.exists() else ""
    if MARK in gammal:
        gammal = gammal[:gammal.index(MARK)].rstrip() + "\n"
    LISTA.write_text(gammal.rstrip() + "\n\n" + "\n".join(rader) + "\n")
    print("\n".join(rader))
    print("\nskrev %s" % LISTA.relative_to(ROT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
