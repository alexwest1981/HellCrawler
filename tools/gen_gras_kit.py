"""Pixelera kitets gräsfärg: Quaternius `Grass.png` (CC0) -> byns egen grönskala.

Kitet är målat och lent (737 färger i en 512x512-rand). By-vyn är 128 px/m pixelkonst, så texturen
måste ned och kvantiseras — men MÄTT räcker det inte att kvantisera mot `palette.json`: den paletten
är kryptans (27 färger, EN grön), så kitets gulbruna höstveck blev orange halm i stället för gräs.
Rampen tas därför ur byns EGEN marktextur (`assets/by/tex/grass.png`), så gräset och marken delar
färg per konstruktion.

Kör: python3 tools/gen_gras_kit.py
"""
import os

from PIL import Image

KÄLLA = "game/assets/by/quaternius/Grass.png"
MARK = "game/assets/by/tex/grass.png"
UT = "game/assets/by/quaternius/Grass_pixel.png"
SIDA = 128
RAMP_STEG = 5


def ramp() -> list:
    """Markens egna färger, sorterade mörk -> ljus. Antalet är RAMP_STEG, inte fler: fler steg än så
    syns inte på ett blad som är 2-3 px brett, och då är de bara dyra."""
    im = Image.open(MARK).convert("RGB")
    kvt = im.quantize(colors=RAMP_STEG, method=Image.Quantize.MEDIANCUT)
    pal = kvt.getpalette()[: RAMP_STEG * 3]
    färger = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)][:RAMP_STEG]
    return sorted(färger, key=lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])


def main() -> int:
    if not os.path.exists(KÄLLA):
        print("FEL  %s saknas (kitet är CC0, men filen måste ligga i repot)" % KÄLLA)
        return 1
    källa = Image.open(KÄLLA).convert("RGB").resize((SIDA, SIDA), Image.BOX)
    steg = ramp()
    px = källa.load()
    mörkast = 0.2126 * steg[0][0] + 0.7152 * steg[0][1] + 0.0722 * steg[0][2]
    ljusast = 0.2126 * steg[-1][0] + 0.7152 * steg[-1][1] + 0.0722 * steg[-1][2]
    spann = max(1.0, ljusast - mörkast)
    for y in range(SIDA):
        for x in range(SIDA):
            r, g, b = px[x, y]
            l = 0.2126 * r + 0.7152 * g + 0.0722 * b
            i = int(round((l - mörkast) / spann * (len(steg) - 1)))
            px[x, y] = steg[max(0, min(len(steg) - 1, i))]
    källa.save(UT)
    print("skrev %s (%dx%d), ramp ur marken: %s" % (UT, SIDA, SIDA, " ".join(str(c) for c in steg)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
