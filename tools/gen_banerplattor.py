"""Skär fanplattorna ur konceptbilden.

Alex 15/10: konceptbilden har två fanor ovanför porten — en röd till vänster, en blå med
guldkant och gul lilja till höger. Modellen har bara ett sköldobjekt med en stenplatta.
Rutorna hittades med färg- och formmätning i byn.png (mättade, smala, höga fält):
    röd: x 1914..1947  y 461..522  (34 x 62 px)
    blå: x 1997..2027  y 442..540  (31 x 99 px)
Kanten (guld respektive mörk) skalas bort med 15 % indrag, så plattan bara bär fältet —
ramen byggs av objektets egen kant.

Plattorna behåller fanans eget format (512 px bred, höjden följer proportionen), för
sätt_uv lägger hela plattan över ytan. Då blir ingen bild utsträckt.
"""
import os
import numpy as np
from PIL import Image

HAR = "/home/alex/Projects/hellcrawlers"
KONCEPT = os.path.join(HAR, "game/assets/ui/byn.png")
UT = os.path.join(HAR, "game/assets/by/tex")
## Fönstren fanorna ligger i. Första försöket tog bara den BLÅ tonen och då skars liljans
## sidoblad av och guldkanten föll bort; den röda tog en rå rektangel och fick stenvägg i
## hörnen. Nu letas hela fanan: fältet PLUS kant och symbol.
## MÄTTA rektanglar (rad- och kolumnavkodning av byn.png, se rapporten): hela fanan med
## sin kant och sin symbol. Den blå har guldkant vid x 1993..1995 och 2030 med fältet
## 1997..2027 och liljan 2009..2014; den röda har mörk kant och fackelbelyst mitt.
## Första försöket tog bara den blå tonen (liljan skars av, guldkanten föll bort) och en rå
## rektangel för den röda (stenvägg i hörnen). Sätt_uv lägger hela plattan över ytan, så
## plattans proportion är det som styr — ingen bild sträcks.
## Andra matningen: den blå hade kvar en mörk list i överkanten (fanan hänger i något) och
## den röda rutan gick för långt åt vänster, där konceptbilden har en rödbrun trävägg som
## färgmässigt är samma röda som tyget. Nu är båda rutorna mätta mot fanans EGNA kanter.
FANOR = {"baner_bla.png": (1993, 441, 2030, 546), "baner_rod.png": (1914, 458, 1944, 532)}
INDRAG = 0.0

def hela_fanan(a, x0, y0, x1, y1, rod):
    """Rektangeln för HELA fanan i fönstret: tyg, kant och symbol — men inte väggen."""
    reg = a[y0:y1 + 1, x0:x1 + 1].astype(int)
    r, g, b = reg[:, :, 0], reg[:, :, 1], reg[:, :, 2]
    if rod:
        ## rött OCH fackelbelyst rött (kärnan av fanan är upplyst, kanten mörk)
        mask = (r > 1.35 * g) & (r > 1.35 * b) & (r > 95)
    else:
        ## blått tyg, gyllene lilja och guldkant — allt som hör till fanan
        bla = (b > 100) & (b > 1.15 * r)
        guld = (r > 130) & (g > 100) & (b < 120)
        mask = bla | guld
    ys, xs = np.nonzero(mask)
    if len(ys) < 100:
        raise SystemExit("hittade ingen fana i fönstret %s" % ((x0, y0, x1, y1),))
    return (x0 + int(xs.min()), y0 + int(ys.min()), x0 + int(xs.max()), y0 + int(ys.max()))

def main():
    kalla = Image.open(KONCEPT).convert("RGB")
    for filnamn, (x0, y0, x1, y1) in FANOR.items():
        print("  %-14s hela fanan: x %d..%d y %d..%d  (%d x %d)" % (
            filnamn, x0, x1, y0, y1, x1 - x0 + 1, y1 - y0 + 1))
        ## kanten (guld respektive mörk) skalas bort — ramen byggs av objektets egen kant
        dx = (x1 - x0 + 1) * INDRAG
        dy = (y1 - y0 + 1) * INDRAG
        falt = kalla.crop((round(x0 + dx), round(y0 + dy), round(x1 + 1 - dx), round(y1 + 1 - dy)))
        h = round(512 * falt.height / falt.width)
        platta = falt.resize((512, h), Image.NEAREST)
        platta.save(os.path.join(UT, filnamn))
        ton = np.asarray(platta).reshape(-1, 3).mean(axis=0)
        print("  %-14s %4d x %-4d  ton (%d,%d,%d)" % (filnamn, platta.width, platta.height, ton[0], ton[1], ton[2]))

if __name__ == "__main__":
    main()
