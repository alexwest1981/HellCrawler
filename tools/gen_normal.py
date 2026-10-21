#!/usr/bin/env python3
"""Ritar normalmaps ur albedon — så ljuset får något att landa på.

Alex: *"vad hände med att sätta på normalmapping, så det ger det hela lite liv, någon för ljuset att
landa på och skapa skuggor?"*. Stenmaterialen i spelet har ingen normalmap alls; de här filerna
genereras ur höjdskillnaden i albedon (Sobel) och läggs bredvid originalet som <namn>_normal.png.

Körs: PATH="/usr/bin:$PATH" python3 tools/gen_normal.py
"""
from PIL import Image, ImageFilter, ImageOps
import os

FILER = [
    "game/assets/tiles/material/fortified_stone_bricks.png",
    "game/assets/tiles/material/ancient_stone.png",
    "game/assets/tiles/material/chiseled_marble.png",
    "game/assets/tiles/material/wall_with_ivy.png",
]
STYRKA = 3.2


def normalmap(bild: Image.Image, styrka: float = STYRKA) -> Image.Image:
    grå = ImageOps.grayscale(bild).filter(ImageFilter.GaussianBlur(0.6))
    bredd, höjd = grå.size
    px = grå.load()
    ut = Image.new("RGB", (bredd, höjd))
    mål = ut.load()
    for y in range(höjd):
        förra = y - 1 if y > 0 else 0
        nästa = y + 1 if y < höjd - 1 else höjd - 1
        for x in range(bredd):
            v = x - 1 if x > 0 else 0
            h = x + 1 if x < bredd - 1 else bredd - 1
            dx = (px[h, y] - px[v, y]) / 255.0 * styrka
            dy = (px[x, nästa] - px[x, förra]) / 255.0 * styrka
            # normaliserad normal, Z upp ur ytan
            längd = (dx * dx + dy * dy + 1.0) ** 0.5
            mål[x, y] = (
                int(max(0, min(255, (0.5 - dx / längd * 0.5) * 255))),
                int(max(0, min(255, (0.5 + dy / längd * 0.5) * 255))),
                int(max(0, min(255, (0.5 + 1.0 / längd * 0.5) * 255))),
            )
    return ut


if __name__ == "__main__":
    # Bara när filen körs själv — annars skrev import av normalmap() om alla stenormaler som
    # sidoeffekt (hände när gen_mark.py importerade funktionen).
    for fil in FILER:
        if not os.path.exists(fil):
            print("hoppar över (saknas):", fil)
            continue
        bild = Image.open(fil).convert("RGB")
        mål = fil.rsplit(".", 1)[0] + "_normal.png"
        normalmap(bild).save(mål)
        print("skrev", mål, bild.size)
