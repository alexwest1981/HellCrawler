#!/usr/bin/env python3
"""Mäter auran: är den en KANT langs silhuetten eller en FYLLNING över kroppen?

Alex: *"Spökena ser ut som de ångar, det skall bara vara minimal aura runtom som ger en känsla av
etheritet"*. Känslan går att mäta: läs två bildrutor ur SAMMA prov (före och efter) och titta på det
ljus som TILLKOMMIT.

  * en KANT ger korta löpmått i sidled — några px vid silhuettens vänster- och högerkant per rad
  * en FYLLNING ger ett långt svep över hela figurens bredd

    python3 tools/mat_aura.py fore.png efter.png [x0 y0 x1 y1]

Utskriften ger antalet px som ljusnat, löpmåttens medel och max, hur mycket de ljusnat (medel och
topp) och hur många px som bränt ut (>240, alltså vit klump i stället för kant). Felkod 1 om
löpmåttet är en fyllning (> 12 px) — provet biter, det är hela poängen.
"""
import sys

from PIL import Image

TRÖSKEL = 25        # över brusgolvet mellan två körningar av samma prov (mätt: 3 272 px > 25)
UTBRÄNT = 240
FYLLNING = 12       # px: ett längre sammanhängande svep i sidled är en fyllning, inte en kant


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    fore = Image.open(sys.argv[1]).convert("RGB")
    efter = Image.open(sys.argv[2]).convert("RGB")
    if fore.size != efter.size:
        print("bilderna har olika storlek: %s mot %s" % (fore.size, efter.size))
        return 2
    if len(sys.argv) >= 7:
        ruta = (int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]))
    else:
        ruta = (0, 0, fore.size[0], fore.size[1])
    a = fore.tobytes()
    b = efter.tobytes()
    bredd = fore.size[0]

    # Tillskottet per pixel: den största kanalens skillnad (auran är additiv, alltså uppåt).
    tillskott = {}
    for y in range(ruta[1], ruta[3]):
        for x in range(ruta[0], ruta[2]):
            i = (y * bredd + x) * 3
            d = max(b[i] - a[i], b[i + 1] - a[i + 1], b[i + 2] - a[i + 2])
            if d > TRÖSKEL:
                tillskott[(x, y)] = d
    if not tillskott:
        print("INGEN aura alls i rutan: 0 px ljusnade mer än %d" % TRÖSKEL)
        return 1

    # Löpmåtten i sidled: hur brett svep auran lägger per rad.
    längder = []
    for y in range(ruta[1], ruta[3]):
        rad = 0
        for x in range(ruta[0], ruta[2] + 1):
            if (x, y) in tillskott:
                rad += 1
            elif rad:
                längder.append(rad)
                rad = 0
    medel = sum(längder) / len(längder)
    värden = sorted(tillskott.values())
    topp = värden[-1]
    utbränt = sum(1 for v in värden if v > UTBRÄNT)
    print("tillskott: %d px (%.2f %% av rutan)" % (len(tillskott),
        100.0 * len(tillskott) / ((ruta[2] - ruta[0]) * (ruta[3] - ruta[1]))))
    print("löpmått i sidled: medel %.1f px, max %d px, %d svep" % (medel, max(längder), len(längder)))
    print("ljuset: medel %+.1f, topp %+d, %d px över %d" % (sum(värden) / len(värden), topp, utbränt, UTBRÄNT))
    if medel > FYLLNING:
        print("FYLLNING, inte kant: auran sveper %.0f px per rad (gräns %d)" % (medel, FYLLNING))
        return 1
    print("kant: auran ligger %.0f px in från silhuetten (gräns %d)" % (medel, FYLLNING))
    return 0


if __name__ == "__main__":
    sys.exit(main())
