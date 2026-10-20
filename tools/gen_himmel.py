#!/usr/bin/env python3
"""Himlen till byn: en equirectangular panorama i spelets palett, ritad i PIL.

Alex: *"Vi behöver någon form av skybox som funkar med stilen med"*. Himlen ska inte vara en
fotohimmel: den ska ha samma bandiga, blockiga ton som bykonsten — mörk blågrå natt, bleka moln i
rader, en måne och enstaka stjärnor, och en bergssilhuett längst ned mot horisonten.

Körs: PATH="/usr/bin:$PATH" python3 tools/gen_himmel.py
Skriver: game/assets/by2d/himmel.png (2048x1024, equirectangular)
"""
from PIL import Image, ImageDraw
import random

BREDD, HÖJD = 2048, 1024
random.seed(20261020)

# Palett ur bykonsten: kall natt upptill, lite varmare nära horisonten.
TOPP = (16, 20, 30)
MITt = (34, 42, 58)
HORISONT = (66, 74, 92)
UNDER = (22, 24, 30)

bild = Image.new("RGB", (BREDD, HÖJD))
d = ImageDraw.Draw(bild)

# BANDAD GRADIENT: 24 steg, inte en mjuk ton — pixelkonst har trappor, inte gradients.
steg = 24
for i in range(steg):
    andel = i / float(steg - 1)
    if andel < 0.62:
        a = andel / 0.62
        färg = tuple(int(TOPP[k] + (MITt[k] - TOPP[k]) * a) for k in range(3))
    else:
        a = (andel - 0.62) / 0.38
        färg = tuple(int(MITt[k] + (HORISONT[k] - MITt[k]) * a) for k in range(3))
    d.rectangle([0, int(HÖJD * i / steg), BREDD, int(HÖJD * (i + 1) / steg) + 1], fill=färg)

# MÅNEN: en blek skiva med en ljusare rand, högt uppe till vänster i vyn.
måne = (520, 210)
d.ellipse([måne[0] - 46, måne[1] - 46, måne[0] + 46, måne[1] + 46], fill=(206, 212, 224))
d.ellipse([måne[0] - 46, måne[1] - 46, måne[0] + 46, måne[1] + 46], outline=(232, 236, 244))

# STJÄRNOR: små fyrkanter, aldrig runda.
for _ in range(260):
    x = random.randrange(BREDD)
    y = random.randrange(int(HÖJD * 0.55))
    ljus = random.choice([(120, 128, 146), (150, 158, 176), (96, 104, 122)])
    s = random.choice([2, 2, 3])
    d.rectangle([x, y, x + s, y + s], fill=ljus)

# MOLNEN: liggande block i rader, som i konsten — aldrig mjuka.
for _ in range(26):
    x = random.randrange(BREDD)
    y = random.randrange(int(HÖJD * 0.10), int(HÖJD * 0.52))
    w = random.randrange(120, 420)
    h = random.randrange(14, 34)
    ton = random.choice([(58, 66, 84), (70, 78, 98), (48, 56, 72)])
    d.rectangle([x, y, x + w, y + h], fill=ton)
    d.rectangle([x + w // 5, y - h // 3, x + w - w // 4, y], fill=tuple(min(255, c + 10) for c in ton))

# BERGEN längst ned: två lager silhuetter, det bakersta ljusare (dis).
def berg(lager_y, höjd, färg):
    punkter = [(0, HÖJD)]
    x = 0
    while x < BREDD:
        steg_w = random.randrange(60, 160)
        topp = lager_y - random.randrange(0, höjd)
        punkter.append((x, topp))
        punkter.append((x + steg_w // 2, topp - random.randrange(0, 18)))
        x += steg_w
    punkter.append((BREDD, HÖJD))
    d.polygon(punkter, fill=färg)

berg(int(HÖJD * 0.74), 90, (46, 54, 70))
berg(int(HÖJD * 0.80), 60, (30, 36, 48))
d.rectangle([0, int(HÖJD * 0.86), BREDD, HÖJD], fill=UNDER)

bild.save("game/assets/by2d/himmel.png")
print("skrev game/assets/by2d/himmel.png", bild.size)
