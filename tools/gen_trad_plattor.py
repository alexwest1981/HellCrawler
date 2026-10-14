#!/usr/bin/env python3
"""PLATTORNA SOM SAKNAS: bark, lövverk, barr, gräs, mursten och virke.

VARFÖR. Alex' paket (`game/assets/by/tex/*.png`) och atlasen
(`medieval_pixel_texture_atlas_4x.png`, 61 rutor) har sten, tegel, plank, murgröna, gräs, jord —
men INGEN bark, inget barr och ingen trädkrona (mätt: lästa ruta för ruta i atlasen, ingen har stam
eller barr). Modellens träd fick därför stammarnas planka (`wood_planks`) och tallarnas kronor
`Grass Flowers` — MÄTT i byn.glb: 17 stammar på Wood, 8 tallar på blomgräs.

KÄLLORNA är Alex' EGNA nedladdade paket i ~/Downloads/Textures (handmålade speltexturer, inte
fotorealistiska, inte pixelkonst). Kopian i `tex/src/` läses, så körningen går att göra om utan
nedladdningsmappen. Varje val är MÄTT mot bildens yta — ingen variant vald på känsla:

    yta        platta        källa                        medel        bildens yta   avstånd
    trädstam   bark.png      Tree Bark 9                  (107,75,57)  (102,78,56)    2,9
    trädkrona  lov.png       Bush_Hedge 4                 ( 84,99,71)  ( 80,105,62)   6,5
    tallkrona  barr.png      Bush_Hedge 4, mörknad        ( 47,72,62)  ( 47, 72,62)   0,4
    gräsband   gras.png      Grass 9                      ( 88,83,58)  ( 75, 84,62)   6,1
    mursten    mursten.png   Stone Wall 1                 ( 91,88,80)  (102,83,85)    7,1
    virke      virke.png     Wood Planks 1                ( 91,71,56)  ( 89, 63,60)   4,6
    förgrund   mork_zon.png  dark_stone.png (Alex' egen)  ( 40,47,50)  ( 40, 47,50)   0,2

    Bildens ytor är mätta i byn.png. Mursten och virke SLÅR de plattor som används i dag
    (stone_wall 16,4 mot 7,1; wood_planks 12,6 mot 4,6) — Alex' egna originalfiler ligger kvar, det
    är bara mappningen i apply_pixel_textures.py som pekar på de nya. Kullerstenen byts INTE:
    atlasens cobblestone_grey ligger 4,8 från gatans färg och paketets bästa 3,7 — en marginal som
    inte är värd ett byte. Förgrundszonen: inget paket slog dark_stone (Mud 20,1, Swamp 20,4,
    Roots 23,4, Ground 22,8, Water 77,1).

Rutan görs kvadratisk (källorna är ~713x840 och får inte sträckas), skalas till 512 och får samma
sömlösa kant som projektets egna plattor (`gen_tiles_alex.sömlös`: halvt varv + utsuddad gammal
kant). Sist skjuts medelvärdet till bildens uppmätta färg — motivet behålls, tonen blir bildens.

    python3 tools/gen_trad_plattor.py           # skriver game/assets/by/tex/<namn>.png
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROT / "tools"))
from gen_tiles_alex import sömlös  # noqa: E402

TEX = ROT / "game" / "assets" / "by" / "tex"
SRC = TEX / "src"
SIDA = 512

## namn -> (källa, vridning i kvartsvarv, mål i sRGB ur byn.png)
## ".." i sökvägen = en platta som redan ligger i tex/ (Alex' egen), inte i src/.
PLATTOR = {
    "bark.png": ("bark_tree-bark-9.png", 0, (102, 78, 56)),
    "lov.png": ("lov_bush-hedge-4.png", 0, (80, 105, 62)),
    "barr.png": ("lov_bush-hedge-4.png", 0, (47, 72, 62)),
    "gras.png": ("gras_grass-9.png", 0, (75, 84, 62)),
    "mursten.png": ("mursten_stone-wall-1.png", 0, (102, 83, 85)),
    "virke.png": ("virke_wood-planks-1.png", 0, (89, 63, 60)),
    ## FÖRGRUNDSZONEN: inget paket slog Alex' egen dark_stone (Mud 20,1, Swamp 20,4, Roots 23,4,
    ## Ground 22,8), så den räknas ur dark_stone — vriden 90 grader, och med ett BREDARE sömband än
    ## de andra (mätt: fog_sid 22,1 mot 4-11 för de övriga; mörk kornig sten behöver mer utsuddning).
    "mork_zon.png": ("../dark_stone.png", 1, (40, 47, 50), 48),
}


def kvadrat(im: Image.Image) -> Image.Image:
    """Största kvadraten ur mitten — källorna är inte kvadratiska och får inte sträckas."""
    sida = min(im.size)
    x, y = (im.width - sida) // 2, (im.height - sida) // 2
    return im.crop((x, y, x + sida, y + sida))


def kör() -> int:
    gjorda = 0
    for namn, rad in PLATTOR.items():
        källa, varv, mål = rad[0], rad[1], rad[2]
        band = rad[3] if len(rad) > 3 else 20
        väg = (SRC / källa).resolve()
        if not väg.is_file():
            print("SAKNAS: %s" % väg)
            return 1
        im = kvadrat(Image.open(väg).convert("RGB"))
        if varv:
            im = im.rotate(-90 * varv, expand=True)
        im = im.resize((SIDA, SIDA), Image.LANCZOS)
        im = sömlös(im, band)
        a = np.asarray(im).astype(np.float64)
        ## Linjär förskjutning per kanal: motivets variation behålls, medelvärdet blir bildens.
        a += (np.array(mål, dtype=np.float64) - a.reshape(-1, 3).mean(axis=0))
        np.clip(a, 0, 255, out=a)
        ut = Image.fromarray(a.round().astype(np.uint8))
        ut.save(TEX / namn)
        b = np.asarray(ut).astype(np.float64)
        ny = b.reshape(-1, 3).mean(axis=0)
        fog = float(np.abs(b[:, -1] - b[:, 0]).mean())
        fel = float(np.abs(ny - np.array(mål)).max())
        print("  %-14s <- %-24s medel %s  mål %s  fel %.1f  fog_sid %.1f"
              % (namn, källa, ny.round(0).astype(int), list(mål), fel, fog))
        if fel > 2.0:
            print("FEL: %s hamnade %.1f från målet" % (namn, fel))
            return 1
        gjorda += 1
    print("SKRIVNA: %d plattor i %s" % (gjorda, TEX))
    return 0


if __name__ == "__main__":
    sys.exit(kör())
