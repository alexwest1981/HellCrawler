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

KÄLLAN MÅSTE VARA PLATT (M120). Paketets `<N>.png` är en FÖRHANDSVISNING: materialet renderat på en
demo-kropp — bark på en CYLINDER, lövverk på en kula — med bakgrund runt motivet (mätt: 661-776 x
650-840 px, RGBA). Den platta albedon ligger bredvid i samma mapp som `<N>_diffuseOriginal.bmp`
(1024x1024 RGB, fyller hela rutan), och det är den som ligger i `tex/src/<namn>_flat.png`.
Första körningen tog förhandsvisningen, och Alex såg det direkt: *"det var runda rendreringar av
texturen på en cylinder, inte en platt textur"* — stammen visade en bild av en cylinder.
`källa_är_platt` vägrar en källa med alfa eller utan kvadrat, så filen kan inte tas fel igen.

    yta        platta        källa (kartans medel)            bildens yta   förskjutning
    trädstam   bark.png      Tree Bark 9      (110,64,43)    (102,78,56)   11,8
    trädkrona  lov.png       Bush_Hedge 4     ( 76,106,65)   ( 80,105,62)   2,5
    tallkrona  barr.png      Bush_Hedge 8     ( 51, 98,50)   ( 47, 72,62)  13,9
    gräsband   gras.png      Grass 9          ( 86, 81,43)   ( 75, 84,62)  11,1
    mursten    mursten.png   Stone Wall 1     ( 97, 97,93)   (102,83,85)    9,2
    virke      virke.png     Wood Planks 1    ( 88, 57,39)   ( 89, 63,60)    9,5
    förgrund   mork_zon.png  Ground 15        ( 39, 46,45)   ( 40, 47,50)    2,4
    tegeltak   tak_tegel.png Roof 11          (167, 92,76)   (141, 94,74)   10,0
    skiffertak tak_skiffer.png Roof 9         ( 92,112,88)   ( 69, 89,86)   16,0
    lila tak   tak_lila.png  Roof 9          ( 92,112,88)   (118, 99,100)  17,0

    Talen är KARTORNAS, inte förhandsvisningarnas: varje variant mättes med `_diffuseOriginal` mot
    bildens yta (radvis ur byn.png), och raden är den variant som låg närmast. Kullerstenen byts
    INTE (atlasens cobblestone_grey 4,8 mot paketets Cobble Stone 5 5,9 — marginalen är inte värd ett
    byte) och taken rörs inte. Två val skiljer sig från första försöket: barr ur Bush_Hedge 8 i
    stället för 4 (kartans avstånd 13,9 mot 23,9 — en mindre förskjutning bränner mindre av
    motivet), och förgrundszonen ur Ground 15 i stället för dark_stone vriden 90 grader (ett
    MURSTENsmönster i gräset; Ground 15 är mörk jord, 2,4 från bildens (40,47,50)).

Kartan (1024x1024) skalas till 512 och får samma sömlösa kant som projektets egna plattor
(`gen_tiles_alex.sömlös`: halvt varv + utsuddad gammal kant). Sist skjuts medelvärdet till bildens
uppmätta färg — motivet behålls, tonen blir bildens.

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
    "bark.png": ("bark_tree-bark-9_flat.png", 0, (102, 78, 56)),
    "lov.png": ("lov_bush-hedge-4_flat.png", 0, (80, 105, 62)),
    "barr.png": ("barr_bush-hedge-8_flat.png", 0, (47, 72, 62)),
    "gras.png": ("gras_grass-9_flat.png", 0, (75, 84, 62)),
    "mursten.png": ("mursten_stone-wall-1_flat.png", 0, (102, 83, 85)),
    "virke.png": ("virke_wood-planks-1_flat.png", 0, (89, 63, 60)),
    ## FÖRGRUNDSZONEN: Ground 15 — mörk jord, 2,4 från bildens (40,47,50). Förut dark_stone vriden
    ## 90 grader, vilket satte ett MURSTENsmönster i gräset. Bredare sömband än de andra (mätt:
    ## mörk kornig jord behöver mer utsuddning).
    "mork_zon.png": ("mork_zon_ground-15_flat.png", 0, (40, 47, 50), 48),
    ## TAKEN: modellens takplattor (roof_slate.png 2 009 byte, roof_terracotta.png 2 051 byte) är
    ## PLATTA FÄRGER — inga tegelrader alls. Bildens tak har rader överallt och tre familjer:
    ## tegel 199 224 varma pixlar (141,94,74), skiffer 180 521 blågrå (69,89,86), och JEWELER-husets
    ## lila (118,99,100). Roof 11 är ett tegeltak (rader), Roof 9 är ett mossigt skiffertak (rader);
    ## båda får sin ton skjuten till bildens. Paketen har INGET lila tak — Roof 9 används därför två
    ## gånger, andra gången mot den lila tonen (motivet är rätt, färgen blir bildens).
    "tak_tegel.png": ("tak_tegel_roof-11_flat.png", 0, (141, 94, 74)),
    "tak_skiffer.png": ("tak_roof-9_flat.png", 0, (69, 89, 86)),
    "tak_lila.png": ("tak_roof-9_flat.png", 0, (118, 99, 100)),
    ## SKYLT OCH FÖNSTER (Alex 2026-10-14: "skyltarna ... fönstren ... nu flyter allt ihop").
    ## Skyltarnas bräda, kanter och bokstäver har samma virkesmaterial som bjälkarna, och
    ## fönsterplattorna var brunare än väggen. Bildens uppmätta värden: skyltbräda (115,91,72),
    ## ram/skugga (39,29,37) — samma som fönstrets mörka öppning — och lysande bokstäver/lyst glas
    ## (235,181,119). Motivet är virkets planka (Wood Planks 1), bara tonen byts.
    "skylt.png": ("virke_wood-planks-1_flat.png", 0, (115, 91, 72)),
    "ram.png": ("virke_wood-planks-1_flat.png", 0, (39, 29, 37)),
    "ljus_varm.png": ("virke_wood-planks-1_flat.png", 0, (235, 181, 119)),
    ## PUTSEN. tudor_wall.png väger 1 776 byte — en PLATT färg, och den ligger på alla korsvirkeshusens
    ## puts (71 objekt). Det är de stora enfärgade fälten i Alex' vy. Bildens puts är (190,175,154) med
    ## spridning 28,8 (fläckig, inte jämn). Paketens ljusa ytor är mest MURVERK (Damaged Wall 3, Stone
    ## Wall, Sand) — Indoor Walls 2 är den enda som är rappad puts: krämvit, fin kornighet, bara
    ## hårfina sprickor (avstånd 19,4, spridning 35,4).
    "puts.png": ("puts_indoor-walls-2_flat.png", 0, (190, 175, 154)),
}


def källa_är_platt(im: Image.Image) -> bool:
    """Är källan en PLATT textur — eller paketets FÖRHANDSVISNING?

    MÄTT (M120): paketets `<N>.png` är en rendering av materialet på en DEMO-KROPP — bark på en
    CYLINDER, lövverk på en kula — 661-776 x 650-840 px, MED alfa och bakgrund runt motivet.
    Albedon ligger bredvid i samma mapp som `<N>_diffuseOriginal.bmp`: 1024x1024 RGB, fyller hela
    rutan. Alex såg följden av att använda fel fil: *"det var runda rendreringar av texturen på en
    cylinder, inte en platt textur"* — stammen visade en BILD av en cylinder.

    Regeln: en källa med alfa, eller som inte är kvadratisk, är en förhandsvisning och får inte bli
    en platta. Grinden står här och inte i en anteckning, för felet är osynligt i en liten bild.
    """
    if im.mode in ("RGBA", "LA") or "transparency" in im.info:
        return False
    return abs(im.width - im.height) <= 0.02 * max(im.size)


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
        im = Image.open(väg)
        if not källa_är_platt(im):
            print("FEL: %s är en FÖRHANDSVISNING (%dx%d %s — motiv med bakgrund runt), inte en platt "
                  "textur. Använd paketets <N>_diffuseOriginal.bmp (1024x1024 RGB)."
                  % (källa, im.width, im.height, im.mode))
            return 1
        im = kvadrat(im.convert("RGB"))
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
        ## Grinden mot en slät källa: en förhandsvisning (eller ett platt fält) har nästan ingen
        ## spridning kvar efter förskjutningen. En riktig textur ligger långt över 8.
        spridning = float(b.reshape(-1, 3).std())
        fog = float(np.abs(b[:, -1] - b[:, 0]).mean())
        fel = float(np.abs(ny - np.array(mål)).max())
        print("  %-14s <- %-32s medel %s  fel %.1f  spridning %.1f  fog_sid %.1f"
              % (namn, källa, ny.round(0).astype(int), fel, spridning, fog))
        ## En platta i ÄNDEN av skalan når inte sitt mål exakt — förskjutningen klipps, så ramen
        ## (39,29,37) landar på (41,31,37) och guldet (235,181,119) på (231,181,119). Grinden är
        ## därför vidare för mörka och ljusa mål: den ska fånga grova fel, inte klippning.
        gräns = 2.0 if 150 <= sum(mål) <= 480 else 5.0
        if fel > gräns:
            print("FEL: %s hamnade %.1f från målet (gräns %.1f)" % (namn, fel, gräns))
            return 1
        if spridning < 8.0:
            print("FEL: %s har spridning %.1f — källan är en slät yta, inte en textur" % (namn, spridning))
            return 1
        gjorda += 1
    print("SKRIVNA: %d plattor i %s" % (gjorda, TEX))
    return 0


if __name__ == "__main__":
    sys.exit(kör())
