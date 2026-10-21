#!/usr/bin/env python3
"""Världskartan, PLATT (M257).

Alex: *"Sen behöver vi verkligen lösa kartan. Ta bort all form av skew eller 'vinkel' på den, lägg den
platt."* Den gamla `varldskarta.png` var målad i isometriskt perspektiv — vinkeln låg i bilden, inte i
koden, så `lutning = 0` räckte inte.

Kartan ritas ovanifrån i fyra lager:
  1. fraktal höjd (fyra oktaver) — dalar och kammar,
  2. zontillhörighet ur `data/karta.json` — närmaste sektion färgar marken, utjämnad så gränserna blir
     mjuka i stället för raka skarvar,
  3. hillshade ur höjdens gradient — relief, inte påklistrade koner,
  4. detaljer: vägar mellan platserna, lava i den varma zonen, is i den kalla, träd med skugga.

Platsernas markörer ritas av spelet ovanpå, så kartan innehåller inga ikoner.

Körs: PATH="/usr/bin:$PATH" python3 tools/gen_varldskarta.py
"""
from PIL import Image, ImageDraw, ImageFilter
import json, math, random
import numpy as np

B, H = 1280, 720
random.seed(20261021)
rng = np.random.default_rng(20261021)

data = json.load(open("game/data/karta.json"))
noder = data["noder"]


def brus(bredd, höjd):
    """Fraktalt värdebrus i 0..1."""
    ut = np.zeros((höjd, bredd), np.float32)
    vikt, summa = 1.0, 0.0
    for oktav in range(4):
        låg = max(2, int(bredd / (2 ** (4 - oktav))))
        g = rng.random((låg, låg)).astype(np.float32)
        g = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((bredd, höjd), Image.BICUBIC)) / 255.0
        ut += g * vikt
        summa += vikt
        vikt *= 0.5
    return ut / summa


höjd = brus(B, H)

# ZONFÄRGER: aska, frost, demonisk sten, mossa.
FÄRG = {1: (62, 38, 28), 2: (40, 52, 70), 3: (52, 32, 50), 4: (34, 50, 38)}
zon = np.zeros((H, B, 3), np.float32)
avstånd = np.full((H, B), 1e9, np.float32)
for n in noder:
    ax, ay = n["x"] / 100.0 * B, n["y"] / 100.0 * H
    färg = np.array(FÄRG.get(int(n.get("sektion", 1)), (40, 38, 44)), np.float32)
    r = 150.0 + 60.0 * rng.random()
    d = np.hypot(np.arange(B)[None, :] - ax, np.arange(H)[:, None] - ay)
    träff = (d < r) & (d < avstånd)
    zon[träff] = färg
    avstånd[träff] = d[träff]
zon = np.array(Image.fromarray(zon.astype(np.uint8)).filter(ImageFilter.GaussianBlur(26)), np.float32)

# HILLSHADE: ljuset från nordväst, gradienten ur höjden.
gy, gx = np.gradient(höjd)
skugga = np.clip(1.55 - 5.2 * gx - 4.0 * gy, 0.30, 2.35)
bild = np.clip(zon * (0.75 + 1.05 * höjd[..., None]) * skugga[..., None], 0, 255).astype(np.uint8)
bas = Image.fromarray(bild)

# FINKORN: dither så ytan inte blir slät gradient.
korn = (rng.random((H, B, 1)) - 0.5) * 14
bas = Image.fromarray(np.clip(np.array(bas, np.float32) + korn, 0, 255).astype(np.uint8))
# KAMMAR: mörka konturer där höjden skiftar snabbt, så marken får åsar i stället för koner.
kant = (np.clip(np.abs(gx) + np.abs(gy), 0, 1) * 255).astype(np.uint8)
kant = np.array(Image.fromarray(kant).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
bild = np.array(bas, np.float32)
bild *= (1.0 - 0.55 * (kant > 0.085)[..., None])
bas = Image.fromarray(np.clip(bild, 0, 255).astype(np.uint8))

d = ImageDraw.Draw(bas)


def pt(n):
    return (n["x"] / 100.0 * B, n["y"] / 100.0 * H)


def sling(x0, y0, x1, y1, steg=16):
    ut = []
    for i in range(steg + 1):
        t = i / steg
        ut.append((x0 + (x1 - x0) * t + math.sin(t * math.pi * 2.3) * 10,
                   y0 + (y1 - y0) * t + math.cos(t * math.pi * 1.7) * 10))
    return ut


# VÄGARNA: platserna i filens ordning.
förra = None
for n in noder:
    p = pt(n)
    if förra is not None:
        linje = sling(förra[0], förra[1], p[0], p[1])
        d.line(linje, fill=(46, 36, 26), width=11)
        d.line(linje, fill=(126, 104, 74), width=6)
        d.line(linje, fill=(132, 112, 82), width=1)
    förra = p

# LAVA i den varma zonen.
varma = [pt(n) for n in noder if int(n.get("sektion", 1)) == 1]
for i in range(len(varma) - 1):
    (x0, y0), (x1, y1) = varma[i], varma[i + 1]
    for bredd, färg in ((10, (110, 28, 10)), (5, (198, 78, 20)), (2, (250, 170, 66))):
        d.line(sling(x0, y0 + 30, x1, y1 + 30, 12), fill=färg, width=bredd)

# IS i den kalla zonen: oregelbundna flak, inga raka kanter.
for n in noder:
    if int(n.get("sektion", 1)) != 2:
        continue
    x, y = pt(n)
    for _ in range(6):
        cx = x + random.randint(-100, 100)
        cy = y + random.randint(-70, 70)
        punkter = []
        for k in range(8):
            v = k / 8 * math.tau
            r = random.randint(22, 54)
            punkter.append((cx + math.cos(v) * r, cy + math.sin(v) * r * 0.62))
        d.polygon(punkter, fill=(146, 172, 194))
        d.line(punkter + [punkter[0]], fill=(112, 136, 158), width=2)


def nära_plats(x, y, minsta=95):
    return any((x - pt(n)[0]) ** 2 + (y - pt(n)[1]) ** 2 < minsta ** 2 for n in noder)


# TRÄD med skugga, glesare nära platserna.
for _ in range(420):
    x, y = random.randrange(24, B - 24), random.randrange(24, H - 24)
    if nära_plats(x, y):
        continue
    for k in range(random.randint(2, 4)):
        cx, cy = x + k * 3, y + k * 4
        d.ellipse([cx - 7, cy - 6, cx + 9, cy + 8], fill=(12, 14, 12))
        d.ellipse([cx - 6, cy - 8, cx + 6, cy + 4], fill=(28, 46, 32))
        d.ellipse([cx - 4, cy - 7, cx + 2, cy - 1], fill=(42, 62, 42))

# RAM.
kantlager = Image.new("RGB", (B, H), (0, 0, 0))
kd = ImageDraw.Draw(kantlager)
kd.rectangle([0, 0, B - 1, H - 1], outline=(10, 9, 12), width=22)
bas = Image.blend(bas, kantlager, 0.3)

bas.save("game/assets/ui/varldskarta.png", optimize=True)
print("skrev game/assets/ui/varldskarta.png (platt kartvy,", B, "x", H, ")")
