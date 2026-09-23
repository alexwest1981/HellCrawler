#!/usr/bin/env python3
"""Partikelkonsten: lågan, röken, gnistan och droppen räknas fram här, inte laddas ner.

Samma skäl som för rutorna (tools/gen_tiles.py): ett pixelspel behöver former i spelets egen stil, och
en låga som består av mjuka runda prickar läses som en glödande kloss — inte som eld. Det är formen
som gör elden, inte färgen.

Filerna är GRÅSKALA + ALFA, aldrig färg: färgen kommer från partikelmaterialets färgskala i spelet
(het → varm → sval → genomskinlig). En fil räcker därför till både en het låga och en sval rök.

    python3 tools/gen_fx.py            # skriver game/assets/fx/*.png
    python3 tools/gen_fx.py --check    # mäter: formen är en form, inte en fyrkant
    python3 tools/gen_fx.py --sheet    # kontaktkarta, att döma på bild
"""

import math
import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "fx"

FRÖ = 7          ## allt brus är seedat: samma kommando ger samma former, varje gång


def _spara(namn: str, bredd: int, höjd: int, pixlar: list[list[tuple[float, float]]]) -> None:
    """pixlar[y][x] = (värde 0..1, alfa 0..1) → vit färg med alfa, så färgskalan i spelet bestämmer."""
    img = Image.new("RGBA", (bredd, höjd), (0, 0, 0, 0))
    for y in range(höjd):
        for x in range(bredd):
            v, a = pixlar[y][x]
            if a <= 0.0:
                continue
            grå = max(0, min(255, int(round(v * 255))))
            img.putpixel((x, y), (grå, grå, grå, max(0, min(255, int(round(a * 255))))))
    img.save(OUT_DIR / namn)


def låga() -> tuple[int, int, list[list[tuple[float, float]]]]:
    """En eldstunga: spetsig upptill, bredast en bit ner, med en het kärna i mitten och en vickande
    överkant. Värme (högt värde) längst ner — det är där elden är som hetast."""
    rnd = random.Random(FRÖ)
    b, h = 24, 32
    pixlar = [[(0.0, 0.0) for _ in range(b)] for _ in range(h)]
    vick = [rnd.uniform(-1.0, 1.0) for _ in range(h)]
    for y in range(h):
        t = y / (h - 1)                    # 0 = topp, 1 = botten
        # Formen: en tunga. Spetsen högst upp (bredden noll i toppen), bredast en bit ner, och en fot
        # som är smalare än magen men inte spetsig — elden står på en veke.
        if t < 0.35:
            bredd = (t / 0.35) ** 1.5
        else:
            bredd = 1.0 - 0.55 * ((t - 0.35) / 0.65) ** 2.2
        r = bredd * (b * 0.44)
        if r < 0.4:
            continue
        # Vickningen: överkanten far i sidled, mer ju längre upp vi är.
        mitten = b / 2.0 + math.sin(t * 2.1 + FRÖ) * 1.1 * (1.0 - t) + vick[y] * 0.5 * (1.0 - t)
        # Värmen: hetast i foten och svalare uppåt, med strimmor så kärnan inte blir jämn.
        värme = 0.60 + 0.40 * t ** 0.7
        strimma = 0.10 * math.sin(t * 9.0 + FRÖ) + 0.06 * math.sin(t * 23.0)
        for x in range(b):
            d = abs(x - mitten) / r
            if d >= 1.0:
                continue
            alfa = (1.0 - d ** 1.7) ** 0.9
            v = max(0.0, min(1.0, värme + strimma - 0.35 * d ** 2))
            pixlar[y][x] = (v, alfa)
    return b, h, pixlar


def rök() -> tuple[int, int, list[list[tuple[float, float]]]]:
    """Ett moln, inte en cirkel: radien vandrar med vinkeln och tätheten är ojämn. En perfekt rund
    prick i mjuk blandning ser ut som en bubbla; det är ojämnheten som gör att den läses som rök."""
    rnd = random.Random(FRÖ + 1)
    b = h = 32
    pixlar = [[(0.0, 0.0) for _ in range(b)] for _ in range(h)]
    # Fyra vågor i olika takt: en rund cirkel blir en klumpig, organisk kant.
    vågor = [(rnd.uniform(1.5, 3.5), rnd.uniform(0, 6.28), rnd.uniform(0.05, 0.13)) for _ in range(4)]
    for y in range(h):
        for x in range(b):
            dx = (x - (b - 1) / 2.0) / (b * 0.46)
            dy = (y - (h - 1) / 2.0) / (h * 0.46)
            d = math.hypot(dx, dy)
            if d >= 1.2:
                continue
            vinkel = math.atan2(dy, dx)
            kant = 0.78 + sum(a * math.sin(f * vinkel + p) for f, p, a in vågor)
            if d >= kant:
                continue
            alfa = (1.0 - (d / kant) ** 1.5) ** 0.8
            # Ojämn täthet: molnet ska ha tunga och lätta partier, inte vara en jämn fläck.
            täthet = 0.62 + 0.30 * math.sin(dx * 5.1 + dy * 3.7 + FRÖ) + 0.12 * math.sin(dy * 11.0)
            pixlar[y][x] = (max(0.0, min(1.0, täthet)), alfa * 0.85)
    return b, h, pixlar


def gnista() -> tuple[int, int, list[list[tuple[float, float]]]]:
    """En gnista: en het kärna med ett kors av svagare sken. Liten med flit — en gnista som är för
    stor är bara ännu ett dammkorn."""
    b, h = 8, 8
    pixlar = [[(0.0, 0.0) for _ in range(b)] for _ in range(h)]
    for y in range(h):
        for x in range(b):
            dx, dy = x - 3.5, y - 3.5
            d = math.hypot(dx, dy)
            if d <= 1.1:
                pixlar[y][x] = (1.0, 1.0)
            elif d <= 2.2:
                pixlar[y][x] = (0.85, 0.55)
            elif abs(dx) <= 0.5 or abs(dy) <= 0.5:
                pixlar[y][x] = (0.5, 0.22)
    return b, h, pixlar


def droppe() -> tuple[int, int, list[list[tuple[float, float]]]]:
    """En fallande droppe: rund i botten, avsmalnande upptill. Den ska se ut att vara på väg ner."""
    b, h = 6, 10
    pixlar = [[(0.0, 0.0) for _ in range(b)] for _ in range(h)]
    for y in range(h):
        t = y / (h - 1)                   # 0 = topp, 1 = botten
        # Droppen: spetsig topp (där den är på väg ner) och rundad botten. En rak cylinder läses som
        # ett streck, inte som en vattendroppe.
        if t < 0.55:
            bredd = (t / 0.55) ** 0.8
        else:
            u = (t - 0.55) / 0.45
            bredd = math.sqrt(max(0.0, 1.0 - u ** 2.6))
        r = (b * 0.46) * bredd
        if r < 0.35:
            continue
        mitten = (b - 1) / 2.0
        for x in range(b):
            d = abs(x - mitten) / r
            if d >= 1.0:
                continue
            alfa = (1.0 - d ** 2.0) ** 0.7
            # Högst upp i droppen sitter ljuset (där ljuset bryts), resten är vatten.
            pixlar[y][x] = (0.55 + 0.45 * (1.0 - t), alfa)
    return b, h, pixlar


FORMER = {
    "laga": låga,
    "rok": rök,
    "gnista": gnista,
    "droppe": droppe,
}

## Lägsta täthet per form. Röken SKA vara halvgenomskinlig (den är ett moln, inte en vägg) — de andra
## ska ha en kärna som är helt tät, annars är de bara suddiga fläckar.
MIN_ALFA = {"laga": 0.95, "rok": 0.80, "gnista": 0.95, "droppe": 0.90}


def check() -> int:
    """Fäller när en form inte är en form: en fyrkant, en jämn cirkel eller en tom ruta."""
    fel = 0
    for namn, bygg in FORMER.items():
        b, h, px = bygg()
        alfa = [[px[y][x][1] for x in range(b)] for y in range(h)]
        rader = [sum(1 for v in rad if v > 0.05) for rad in alfa]
        topp = rader[0]
        botten = rader[-1]
        maxa = max(max(rad) for rad in alfa)
        kantsumma = sum(alfa[0]) + sum(alfa[-1]) + sum(rad[0] for rad in alfa) + sum(rad[-1] for rad in alfa)
        # Bredden får inte vara konstant rad för rad: då är formen en fyrkant.
        aktiva = [r for r in rader if r > 0]
        variation = (max(aktiva) - min(aktiva)) if aktiva else 0
        print("  %-7s %2dx%-2d  rader %2d-%2d  topp %d botten %d  maxalfa %.2f  kant %.1f"
              % (namn, b, h, rader.count(0) + (1 if aktiva else 0), len(aktiva), topp, botten, maxa, kantsumma))
        if maxa < MIN_ALFA[namn]:
            print("    FEL: formen når inte sin täthet (maxalfa %.2f, krav %.2f)"
                  % (maxa, MIN_ALFA[namn]))
            fel += 1
        if variation < 2:
            print("    FEL: formen är en fyrkant (bredden varierar %d px mellan raderna)" % variation)
            fel += 1
    # Lågan och droppen är högre än breda, röken får inte vara en jämn cirkel.
    _, _, låg = FORMER["laga"]()
    _, _, drp = FORMER["droppe"]()
    if len(låg) <= len(låg[0]):
        print("    FEL: lågan är inte högre än bred")
        fel += 1
    if len(drp) <= len(drp[0]):
        print("    FEL: droppen är inte högre än bred")
        fel += 1
    # RIKTNINGEN. Det här är kontrollen som hade fångat den upp-och-nervända lågan: spetsen ska vara i
    # toppen och värmen i foten. Ögat såg felet, men en bild ska inte behöva tittas på för att veta.
    def _profil(px: list[list[tuple[float, float]]]) -> tuple[list[int], float]:
        höjd, bredd = len(px), len(px[0])
        rader = [sum(1 for v, a in rad if a > 0.05) for rad in px]
        vikt = [sum((v * a) for v, a in rad) for rad in px]
        tot = sum(vikt) or 1.0
        tyngd = sum(i * w for i, w in enumerate(vikt)) / (tot * (höjd - 1))
        return rader, tyngd

    låg_rader, låg_tyngd = _profil(låg)
    if max(låg_rader[:3]) > 2:
        print("    FEL: lågan är trubbig i toppen (radbredd %s) — spetsen ska upp" % låg_rader[:3])
        fel += 1
    if låg_tyngd < 0.5:
        print("    FEL: lågans värme ligger i överkanten (tyngdpunkt %.2f) — elden är hetast nere"
              % låg_tyngd)
        fel += 1
    drp_rader, _ = _profil(drp)
    if drp_rader[0] > 1 or drp_rader[-1] > 2:
        print("    FEL: droppen är trubbig upptill eller fyrkantig nertill (%s / %s)"
              % (drp_rader[:3], drp_rader[-3:]))
        fel += 1
    rök_px = FORMER["rok"]()[2]
    kant_rök = (sum(a for _, a in rök_px[0]) + sum(a for _, a in rök_px[-1])
        + sum(rad[0][1] for rad in rök_px) + sum(rad[-1][1] for rad in rök_px))
    if kant_rök > 0.01:
        print("    FEL: röken når ut till kanten (den ska vara ett moln med luft runt om)")
        fel += 1
    print("%d former, %d fel" % (len(FORMER), fel))
    return fel


def sheet() -> None:
    """Kontaktkarta: formerna sida vid sida, fyra gånger så stora, mot mörk botten så alfakanten syns."""
    skala = 4
    rad = sum(bygg()[0] * skala + 6 for bygg in FORMER.values()) + 6
    hög = max(bygg()[1] for bygg in FORMER.values()) * skala + 12
    img = Image.new("RGB", (rad, hög), (14, 14, 18))
    x0 = 6
    for bygg in FORMER.values():
        b, h, px = bygg()
        for y in range(h):
            for x in range(b):
                v, a = px[y][x]
                if a <= 0.02:
                    continue
                grå = int(round(v * a * 255))
                for dy in range(skala):
                    for dx in range(skala):
                        img.putpixel((x0 + x * skala + dx, 6 + y * skala + dy), (grå, grå, grå))
        x0 += b * skala + 6
    img.save(OUT_DIR / "_former.png")
    print("kontaktkarta: %s" % (OUT_DIR / "_former.png").relative_to(ROOT))


def main() -> int:
    if "--check" in sys.argv:
        return 1 if check() else 0
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for namn, bygg in FORMER.items():
        b, h, px = bygg()
        _spara("%s.png" % namn, b, h, px)
        print("  %s (%dx%d)" % ((OUT_DIR / ("%s.png" % namn)).relative_to(ROOT), b, h))
    if "--sheet" in sys.argv:
        sheet()
    return 0


if __name__ == "__main__":
    sys.exit(main())
