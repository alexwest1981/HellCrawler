#!/usr/bin/env python3
"""Skär Alex ark (game/images/Gemini_Generated_Image_*.jpeg) till rekvisiter i game/assets/props/.

Alex: *"Det ligger nya bilder i images"* — fem ark med miljöföremål (kristaller, svampar, rötter,
benhögar, altare, lavapölar). De hör till samma lager som `gen_props.py` ritar: rekvisiter och
dekoration, och de ska ha samma palett och samma täthet (128 px per meter) för att smälta in.

VARFÖR ETT EGET VERKTYG: `gen_props.py` RITAR former ur paletten, det här verket SKÄR ur en bild.
Grinden är däremot densamma — de skurna bitarna läggs in i `gen_props.FORMER` som färdiga `Duk`-ar, så
`check(pal)` mäter dem med samma regler som de ritade (kontur, ingen golvfärg i kroppen, ingen brusig
form). Ingen regel dupliceras.

MÄTT STRUKTUR (2816x1536-arken): bakgrunden är (1,1,1) och 67-71 % av arket. Innehållet ligger i
4-7 band om 290-378 px. ETIKETTERNA ÄR EGNA BAND: 35-43 px höga med 86-96 smala kolumner
(12-34 px breda) — de känns igen på formen och kastas, inte på en gissad y-koordinat.

Kör:  python3 tools/gen_props_alex.py [ark]      (utan argument: alla fem)
       python3 tools/gen_props_alex.py --lista    (bara mät arken, skriv inget)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_props as gp  # noqa: E402  (palett, Duk, kontur, grinden)

ROOT = gp.ROOT
ARK_MAPP = ROOT / "game" / "images"
UT = ROOT / "game" / "assets" / "props"

PPM = 128.0            ## px per meter i spelet — samma som rekvisiten (DEKOR_PIXEL 0,008)
STÖRST_M = 1.2         ## det största föremålet på ett ark blir 1,2 m; resten följer samma skala
TRÖSKEL = 40           ## avstånd från bakgrundsfärgen som räknas som innehåll

## Arken och (för de namngivna) föremålen i läsordning. Nummer utan namn får arkets namn + index.
##
## MÄTT 2026-09-23: de här banden/kolumnerna FUNGERAR på 2816x1536-arken (4 rader x 7-10 föremål) och
## FUNGERAR INTE på 1312x3264-arken (6 rader x 2 stora isometriska föremål). På de höga arken ligger
## föremålen tätt (banden smälter ihop: en 498x1309-bit visade sig vara både svärdet och malmådern) och
## enstaka föremål delas vid ett internt glapp (Pile of Spoils blev tre bitar, två av dem 6-30 px).
## Namnen blev också fel: 5 av 9 granskade namn pekade på fel föremål, eftersom listan skrevs i
## läsordning och inte ur rutnätet.
##
## RÄTT VÄG för de två höga arken: ETIKETTERNA ÄR RUTNÄTET. Varje föremål har en tryckt etikett under
## sig, etiketterna ligger i ett jämnt rutnät (mätt: 6 etikettband på 183mbc), så ett föremåls ruta är
## området mellan föregående etikettrad och dess egen — x-centrum från etiketten, y från raden ovanför.
## Tills det är byggt skärs bara de tre ark som klarar band-metoden.
ARK = {
    "4ngxvx": ["klippblock", "stenblock", "stalaktit", "kristall_lila", "kristall_turkos",
               "svamp_lysande", "vattenpöl", "gruvstötta", "gruvvagn", "hacka", "rep",
               "trälåda", "fackla", "malm_guld", "ädelsten_röd", "ädelsten_blå", "benhög",
               "kranium", "hornskalle", "fladdermus", "spindelnät", "stengolv"],
    # Namnen ovan är en gissning i läsordning och 5 av 9 granskade stämde inte — de ska bytas mot
    # etikettavläsning (se ovan) innan något av dem kopplas in i spelet.
    "pwa97m": [], "8gunzn": [],
    # "w739us" och "183mbc": höga ark, kräver etikett-rutnätet. Se den långa kommentaren ovan.
}


def band(v: np.ndarray, min_längd: int = 4) -> list[tuple[int, int]]:
    """Sammanhängande partier av True, som (start, slut)."""
    ut, start = [], None
    for i, x in enumerate(v):
        if x and start is None:
            start = i
        elif not x and start is not None:
            if i - start >= min_längd:
                ut.append((start, i - 1))
            start = None
    if start is not None:
        ut.append((start, len(v) - 1))
    return ut


def kvantisera(rgb: np.ndarray, pal: list[tuple[int, int, int]]) -> np.ndarray:
    """Närmaste palettfärg per pixel — men ALDRIG golvets egen ton.

    DIRT (17) hålls utanför kandidaterna. Grinden mätte 8-44 % av kroppen i DIRT på de skurna bitarna:
    samma färg som golvet, alltså en sak som försvinner när den ställs ner (exakt samma mätning som
    fällde första versionen av roten). Palettindex 0 betyder 'tom' i Duk och är inte heller en kandidat.
    """
    kvar = [i for i in range(1, len(pal)) if i != 17]           # 17 = DIRT = golvet
    p = np.array([pal[i] for i in kvar], dtype=np.int16)
    avstånd = np.abs(rgb[:, :, None, :] - p[None, None, :, :]).sum(axis=3)
    return np.array(kvar, dtype=np.int16)[avstånd.argmin(axis=2)]


def jämna_ut(idx: np.ndarray, varv: int = 2) -> np.ndarray:
    """3x3-majoritet i två varv: varje pixel blir den färg flest av dess nio rutor har.

    MÄTT: grinden fällde 13 av bitarna på sträckan 1,2-1,7 px — "formen är brus". Det är kvantiseringen
    av AI-graderingar: en jämn ton blir ett mönster av närliggande palettfärger där ingen färg håller
    två rutor i rad. Spelets egen konst är platta fält, så bruset ska bort.

    Ett svep av ensampixelfiltret tog 23 fel -> 17 ("jämna_ut" första versionen). Majoriteten tar
    resten: ett jämnt fält har nio röster på sin egen färg och rörs inte, medan en dither-fläck
    tvingas till sin omgivnings vanligaste färg. Lika röster behåller den ursprungliga färgen.
    """
    ut = idx.copy()
    for _ in range(varv):
        kant = np.pad(ut, 1, mode="edge")
        bästa_antal = np.zeros(ut.shape, dtype=np.int16)
        bästa = ut.copy()
        for c in np.unique(kant):
            antal = np.zeros(ut.shape, dtype=np.int16)
            for dy in range(3):
                for dx in range(3):
                    antal += (kant[dy:dy + ut.shape[0], dx:dx + ut.shape[1]] == c)
            vinner = antal > bästa_antal
            bästa[vinner] = c
            bästa_antal[vinner] = antal[vinner]
        ut = bästa
    return ut


def skär(fil: Path, pal) -> tuple[np.ndarray, np.ndarray, list[tuple[int, int, int, int]]]:
    b = np.asarray(Image.open(fil).convert("RGB")).astype(np.int16)
    bak = b[4, 4]
    mask = np.abs(b - bak).sum(axis=2) > TRÖSKEL
    bitar = []
    for s, e in band(mask.sum(axis=1) > 8):
        kol = band(mask[s:e + 1].sum(axis=0) > 2)
        bredder = sorted(q - k + 1 for k, q in kol)
        # ETIKETTRADEN: många smala kolumner. Mätt på 8gunzn: 86-96 kolumner, 12-34 px breda.
        if len(kol) > 20 and bredder[len(bredder) // 2] < 40:
            print("      (hoppar etikettrad: %d kolumner, median %d px)" % (len(kol), bredder[len(bredder) // 2]))
            continue
        for k, q in kol:
            m = mask[s:e + 1, k:q + 1]
            fylld = float(m.sum()) / float(m.size)
            # ETIKETTEN SOM BLEV EN REKVISIT: en rad bokstäver är tunn och låg — mätt 0,10-0,20 fyllnad
            # i sin ruta, medan en sten ligger runt 0,7 och en kedja runt 0,4. Utan det här klipptes
            # "Cresd of Prid" och "P s v e s s" ut som föremål (bedömningen såg dem som en sköld).
            if fylld < 0.18 and (e - s + 1) < 70:
                print("      (hoppar etikettbit: %dx%d px, %.0f %% fyllnad)"
                      % (q - k + 1, e - s + 1, fylld * 100.0))
                continue
            bitar.append((k, s, q, e))
    return b, mask, bitar


def klipp(b, mask, ruta: tuple[int, int, int, int]) -> tuple[np.ndarray, np.ndarray]:
    k, s, q, e = ruta
    m = mask[s:e + 1, k:q + 1]
    färg = b[s:e + 1, k:q + 1]
    ys, xs = np.where(m)
    m, färg = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1], färg[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return färg, m


def main() -> int:
    pal = [tuple(c) for c in json.loads((ROOT / "game" / "assets" / "palette.json").read_text())]
    ark = [a for a in sys.argv[1:] if not a.startswith("--")]
    ark = ark or list(ARK)
    lista = "--lista" in sys.argv
    for namn in ark:
        träff = sorted(ARK_MAPP.glob("Gemini_Generated_Image_%s*.jpeg" % namn))
        if not träff:
            print("  saknas: %s" % namn)
            continue
        f = träff[0]
        b, mask, bitar = skär(f, pal)
        if not bitar:
            print("%s: hittade inga föremål" % namn)
            continue
        höjder = [e - s + 1 for _, s, _, e in bitar]
        skala = (STÖRST_M * PPM) / max(höjder)
        print("%s: %d föremål, högsta %d px -> skala %.3f (största blir %.2f m)"
              % (namn, len(bitar), max(höjder), skala, STÖRST_M))
        if lista:
            continue
        namnlista = ARK.get(namn, [])
        bort: list[tuple[str, int, int, str]] = []
        for i, ruta in enumerate(bitar):
            färg, m = klipp(b, mask, ruta)
            h = int(round(färg.shape[0] * skala))
            br = int(round(färg.shape[1] * skala))
            # TVÅ SORTER SOM INTE BLIR REKVISITER — mätta, inte gissade:
            #  - PLATTAN (bredast >= 1,6 x höjden): golvplattor, pölar och stigar på arken. Som upprätt
            #    billboard blir en golvplatta en STÅENDE platta; de hör till rutan, inte hit.
            #  - PYTTEN (någon sida < 32 px): efter nedskalningen finns ingen form kvar, bara brus
            #    (grinden mätte sträckan 1,4 px). Bättre att inte skapa den än att skapa skräp.
            if h < 4 or br < 4:
                continue
            if br >= h * 1.6 or min(br, h) < 32:
                bort.append((namn, br, h, "platta" if br >= h * 1.6 else "pytt"))
                continue
            liten = np.asarray(Image.fromarray(färg.astype(np.uint8)).resize((br, h), Image.NEAREST)).astype(np.int16)
            lm = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((br, h), Image.NEAREST)) > 127
            idx = kvantisera(liten, pal)
            idx = jämna_ut(idx)
            d = gp.Duk(br, h)
            for y in range(h):
                for x in range(br):
                    if lm[y, x]:
                        d.px[y][x] = int(idx[y, x])
            # Konturen: grinden kräver den mörkaste färgen i silhuetten, och ett skuret föremål har
            # ingen egen pixelkontur kvar efter nedskalningen. Samma kant som de ritade rekvisiten får.
            gp._kontur(d)
            nyckel = namnlista[i] if i < len(namnlista) else "%s_%02d" % (namn, i + 1)
            gp.FORMER[nyckel] = (lambda dd: (lambda: dd))(d)
            print("      %-18s %3dx%-3d px  %.2f x %.2f m" % (nyckel, br, h, br / PPM, h / PPM))
        if bort:
            plattor = sum(1 for rad in bort if rad[3] == "platta")
            print("      (hoppar %d plattor och %d pyttar)" % (plattor, len(bort) - plattor))
    if lista:
        return 0
    print("\nskriver alla former (ritade + skurna):")
    gp.main()
    print("\ngrinden på allt:")
    fel = gp.check(pal)
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
