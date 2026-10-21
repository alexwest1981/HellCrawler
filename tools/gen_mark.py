#!/usr/bin/env python3
"""Grus till byns mark — en stor textur som inte upprepar sig synligt.

Alex: *"Marken behöver få en annan textur som inte tile'ar så synligt. Bäst hade varit om vi hade kunnat
rendrera random grus-effekt över hela marken?"*

Texturen ritas i 4096x4096 och läggs EN gång över hela torget (40x40 m), alltså ingen synlig upprepning.
Stenarna ritas också vid kanterna med omslag, så kanten möter sig själv om den används tiled någon annan
gång. Normalmapen genereras separat av tools/gen_normal.py.

Körs: PATH="/usr/bin:$PATH" python3 tools/gen_mark.py
"""
from PIL import Image, ImageDraw, ImageFilter
import random

SIDA = 4096
random.seed(20261021)

bild = Image.new("RGB", (SIDA, SIDA), (44, 44, 48))
d = ImageDraw.Draw(bild)


def sten(x, y, rx, ry, ton, rotation):
    """En sten med ljus ovankant och mörk underkant, ritad med omslag vid kanterna."""
    for dx in (-SIDA, 0, SIDA):
        for dy in (-SIDA, 0, SIDA):
            px, py = x + dx, y + dy
            if px < -rx or px > SIDA + rx or py < -ry or py > SIDA + ry:
                continue
            d.ellipse([px - rx, py - ry, px + rx, py + ry], fill=ton)
            d.arc([px - rx, py - ry, px + rx, py + ry], 190, 350,
                  fill=tuple(min(255, c + 26) for c in ton), width=max(1, int(rx * 0.16)))
            d.arc([px - rx, py - ry, px + rx, py + ry], 10, 170,
                  fill=tuple(max(0, c - 26) for c in ton), width=max(1, int(rx * 0.16)))


# GRUSET: tusentals stenar i olika storlek, från grus till kullersten.
for _ in range(26000):
    x = random.randrange(SIDA)
    y = random.randrange(SIDA)
    r = random.choice([2, 3, 4, 5, 6, 7, 9, 12, 16])
    rx = r * random.uniform(0.8, 1.5)
    ry = rx * random.uniform(0.7, 1.1)
    bas = random.randint(62, 118)
    ton = (bas, bas - random.randint(0, 4), bas + random.randint(0, 6))
    sten(x, y, rx, ry, ton, random.uniform(0, 6.28))

# FINARE GRUS MELLAN STENARNA: mörka prickar som fyller fogarna.
for _ in range(90000):
    x = random.randrange(SIDA)
    y = random.randrange(SIDA)
    r = random.uniform(0.6, 1.8)
    bas = random.randint(26, 54)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(bas, bas, bas + 3))

# MOSSFLÄCKAR: få, stora och mjuka, så marken inte är jämngrå.
lager = Image.new("RGB", (SIDA, SIDA), (0, 0, 0))
moss = ImageDraw.Draw(lager)
for _ in range(70):
    x = random.randrange(SIDA)
    y = random.randrange(SIDA)
    rx = random.randrange(60, 220)
    ry = rx * random.uniform(0.5, 1.0)
    moss.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(random.randint(30, 58), random.randint(64, 96), random.randint(28, 48)))
lager = lager.filter(ImageFilter.GaussianBlur(26))
bild = Image.blend(bild, Image.blend(bild, lager, 0.55), 0.5)

# JORD- OCH SLITFLÄCKAR (M240). Alex: *"marken är för platt och för jämnt utlagd"*. Stora mjuka
# jordpartier och nötta stigar bryter den enhetliga grusytan, så torget inte läser som en grusplatta.
jord = Image.new("RGB", (SIDA, SIDA), (0, 0, 0))
jordd = ImageDraw.Draw(jord)
for _ in range(40):
    x = random.randrange(SIDA)
    y = random.randrange(SIDA)
    rx = random.randrange(180, 520)
    ry = rx * random.uniform(0.35, 0.9)
    jordd.ellipse([x - rx, y - ry, x + rx, y + ry],
                  fill=(random.randint(56, 84), random.randint(48, 70), random.randint(38, 56)))
jord = jord.filter(ImageFilter.GaussianBlur(60))
bild = Image.blend(bild, jord, 0.42)

# LJUSARE SLITNA FÄLT där folk går: större, blekare grus.
slitet = Image.new("RGB", (SIDA, SIDA), (0, 0, 0))
slitd = ImageDraw.Draw(slitet)
for _ in range(26):
    x = random.randrange(SIDA)
    y = random.randrange(SIDA)
    rx = random.randrange(220, 640)
    ry = rx * random.uniform(0.25, 0.6)
    slitd.ellipse([x - rx, y - ry, x + rx, y + ry],
                  fill=(random.randint(96, 126), random.randint(94, 122), random.randint(92, 118)))
slitet = slitet.filter(ImageFilter.GaussianBlur(70))
bild = Image.blend(bild, slitet, 0.35)

bild.save("game/assets/tiles/material/mark_grus.png")
print("skrev game/assets/tiles/material/mark_grus.png", bild.size)
