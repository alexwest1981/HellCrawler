#!/usr/bin/env python3
"""Kortbaksidan: Alex' egen kortbild, klippt till kortets yta.

Alex: *"Kortet tänkte jag att vi kan använda som baksida för korten."*

Källan är hans bild (`research/alex_kortbaksida_20260921.jpg`) — koden klipper och skalar, den ritar
ingenting själv. Bilden äger utseendet. Baksidan är 2x kortets yta (208x288 för ett 104x144-kort),
alltså samma pixelstorlek som kortens konst, och det är EN fil för alla kort: spelet laddar samma
textur till varje kort, så man inte ser vad som ligger näst på tur.

    python3 tools/gen_card_back.py            # skriver game/assets/cards/_back.png
    python3 tools/gen_card_back.py --check    # mäter: mått, helt tät, motivet finns
    python3 tools/gen_card_back.py --sheet    # kontaktkarta (3x), att döma på bild
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
UT = ROOT / "game" / "assets" / "cards"
KÄLLA = ROOT / "research" / "alex_kortbaksida_20260921.jpg"
FIL = "_back.png"
BILD = "_baksida_kontaktkarta.png"

# Kortets yta i spelet är CardView.HAND_SIZE (104x144); baksidan ligger på 2x, samma täthet som
# kortkonsten. Alex' bild är 2:3 mot kortets 5:7, alltså en sträckning i sidled på 7 % — ramen är
# dekor, inte geometri, och 7 % syns inte.
B, H = 208, 288
TRÖSKEL = 60.0             # ljushet över det här = kortet (bildens överkant har en mörk remsa utanför)


def kortet(img: Image.Image) -> Image.Image:
    """Bildens yta som är själva kortet. Alex' bild har en mörk remsa i överkanten utanför ramen; den
    mäts fram i stället för att antas, och mätningen skrivs ut."""
    a = np.asarray(img.convert("RGB")).astype(int)
    ljus = a.mean(axis=2) > TRÖSKEL
    rader = np.where(ljus.any(axis=1))[0]
    kolumner = np.where(ljus.any(axis=0))[0]
    if not rader.size or not kolumner.size:
        return img
    print("  kortet: x %d..%d  y %d..%d  av %dx%d" % (
        kolumner[0], kolumner[-1], rader[0], rader[-1], img.width, img.height))
    return img.crop((kolumner[0], rader[0], kolumner[-1] + 1, rader[-1] + 1))


def skriv() -> int:
    if not KÄLLA.exists():
        print("källan saknas: %s" % KÄLLA.relative_to(ROOT), file=sys.stderr)
        return 1
    # BOX (medelvärde per block) och inte NEAREST: bilden skalas ner sju gånger, och nearest hade
    # plockat enstaka pixlar ur varje block och gett hackiga kedjor och en flimrig eld.
    ut = kortet(Image.open(KÄLLA)).convert("RGB").resize((B, H), Image.BOX).convert("RGBA")
    UT.mkdir(parents=True, exist_ok=True)
    ut.save(UT / FIL)
    ut.resize((B * 3, H * 3), Image.NEAREST).save(UT / BILD)
    print("  %s (%dx%d)" % ((UT / FIL).relative_to(ROOT), B, H))
    print("  kontaktkarta: %s" % (UT / BILD).relative_to(ROOT))
    return 0


def check() -> int:
    p = UT / FIL
    if not p.exists():
        print("  FEL  %s saknas" % FIL)
        return 1
    fel = 0
    img = Image.open(p)
    if img.size != (B, H):
        print("  FEL  %s är %s, ska vara %dx%d" % (FIL, img.size, B, H))
        fel += 1
    a = np.asarray(img.convert("RGBA")).astype(int)
    # Baksidan ska vara TÄT: ett genomskinligt kort i en hög visar bordet genom kortet.
    if (a[:, :, 3] < 255).any():
        print("  FEL  %s har %d genomskinliga pixlar" % (FIL, int((a[:, :, 3] < 255).sum())))
        fel += 1
    färger = len(np.unique(a[:, :, :3].reshape(-1, 3), axis=0))
    if färger < 500:
        print("  FEL  %s har bara %d färger — motivet ser inte ut att ha kommit med" % (FIL, färger))
        fel += 1
    medel = a[:, :, :3].mean()
    if medel < 12:
        print("  FEL  %s är nästan helt svart (medelljus %.1f)" % (FIL, medel))
        fel += 1
    if not fel:
        print("  ok   %s %dx%d, tät, %d färger, medelljus %.1f" % (FIL, B, H, färger, medel))
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(check() if "--check" in sys.argv else skriv())
