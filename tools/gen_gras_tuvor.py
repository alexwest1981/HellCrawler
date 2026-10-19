"""Grässtrån till byns förgrund: tre tuvor i en 96x32-ark, ur paletten.

Alex 19/10: *"jag vill kunna ha liknande effekter, känsla, rörliga grässtrån osv"* (referensen
Luminati har ett fält av gräs som vajar). Tuvorna ritas här i stället för att klippas ur ett ark:
32x32 är samma pixelstorlek som spelets övriga rekvisita (128 px/m), och formen är en båge av strån
som smalnar av upptill — det är silhuetten som gör att de läser som gräs och inte som pinnar.

Kör: python3 tools/gen_gras_tuvor.py [--check]
"""
import random
import sys

from PIL import Image

UT = "game/assets/by/gras_tuvor.png"
RUTA = 32
ANTAL = 3
# Mörkast längst ned, ljusast i toppen: ett strå som är mörkt upptill läser som en pinne.
FÄRGER = [(52, 74, 40), (84, 116, 56), (120, 152, 74), (168, 194, 104)]


def strå(d, x0, y0, höjd, böj, färg):
    """Ett strå: en 2 px bred båge som smalnar av till 1 px i toppen."""
    for i in range(höjd):
        t = i / max(1, höjd - 1)
        x = int(round(x0 + böj * t * t))
        y = y0 - i
        if not (0 <= x < RUTA and 0 <= y < RUTA):
            continue
        d[x, y] = färg
        if t < 0.55:                      # nedre halvan är två pixlar bred
            if x + 1 < RUTA:
                d[x + 1, y] = färg


def tuvor(seed: int) -> Image.Image:
    rng = random.Random(seed)
    ark = Image.new("RGBA", (RUTA * ANTAL, RUTA), (0, 0, 0, 0))
    for n in range(ANTAL):
        ruta = Image.new("RGBA", (RUTA, RUTA), (0, 0, 0, 0))
        d = ruta.load()
        # Roten står på rad 30 (2 px luft under): tuvan ska kunna sjunka ned i marken utan att klippas.
        for _ in range(9 + n * 2):
            x0 = 12 + rng.randint(0, 7)
            höjd = rng.randint(9, 17) + (2 if n == 1 else 0)
            böj = rng.choice([-4, -3, -2, 2, 3, 4])
            färg = FÄRGER[min(3, rng.randint(1, 3))]
            strå(d, x0, 30, höjd, böj, färg)
        # Ett par mörka strån längst ned, så tuvan har en fot och inte svävar.
        for x in range(10, 22):
            if rng.random() < 0.55:
                d[x, 30] = FÄRGER[0]
                d[x, 29] = FÄRGER[0] if rng.random() < 0.5 else FÄRGER[1]
        ark.paste(ruta, (n * RUTA, 0))
    return ark


def main() -> int:
    img = tuvor(20261019)
    if "--check" in sys.argv:
        gammal = Image.open(UT)
        if gammal.tobytes() != img.tobytes():
            print("FEL  %s skiljer sig från generatorns utdata" % UT)
            return 1
        print("OK   %s är generatorns utdata" % UT)
        return 0
    img.save(UT)
    print("skrev %s (%dx%d)" % (UT, img.width, img.height))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
