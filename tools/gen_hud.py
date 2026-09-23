"""Bygger porträttet i statusblocket uppe till vänster (M40): en hjälmklädd ryttare, 48x48 pixlar.

    python3 tools/gen_hud.py            # skriv game/assets/ui/portratt.png
    python3 tools/gen_hud.py --check    # mät bilden (ram, metall, visir, symmetri) — exit 1 vid fel

Referensen (Alex' GUI-bild) har ett fyrkantigt porträtt till vänster om livsstaplarna. Spelet har ingen
spelarfigur att klippa ut — vyn är förstaperson — så porträttet ritas i kod ur spelets palett, som
menymärket och kortbaksidan. Hjälmen är en sluten stormhjälm med korsat visir: vid 48x48 är ögon och
näsa för små för att läsas, medan visiröppningen och nitsömmen syns direkt.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PALETT = ROOT / "game" / "assets" / "palette.json"
UT = ROOT / "game" / "assets" / "ui"

B = H = 48

TOM = -1
SOT = 1          # mörkast: visiret
MÖRK = 2
SKUGGA = 3
METALL = 4
METALL_LJUS = 5
METALL_MER = 6
HÖGDAGER = 7
BLOD = 10
BEN = 8


def palett() -> list[tuple[int, int, int, int]]:
    färger = json.loads(PALETT.read_text(encoding="utf-8"))
    return [(c[0], c[1], c[2], 255) for c in färger]


def ruta(px: list[list[int]], x: int, y: int, b: int, h: int, färg: int) -> None:
    for j in range(max(0, y), min(H, y + h)):
        for i in range(max(0, x), min(B, x + b)):
            px[j][i] = färg


def spegel(px: list[list[int]]) -> None:
    """Speglar vänster halva över höger: hjälmen ska vara symmetrisk, och att rita båda halvorna för
    hand bröt symmetrin på kortbaksidan (2 997 pixlar)."""
    for j in range(H):
        for i in range(B // 2):
            px[j][B - 1 - i] = px[j][i]


def porträtt() -> list[list[int]]:
    px = [[TOM] * B for _ in range(H)]
    m = B // 2                      # 24
    # HJÄLMEN: en rundad kupa. Halslinningen i underkanten (en ring av mörkare metall) och en
    # axelplåt under den, så porträttet inte slutar i luften.
    ruta(px, m - 13, 12, 26, 26, METALL)          # kupan
    ruta(px, m - 11, 8, 22, 6, METALL)            # överdelen smalnar av
    ruta(px, m - 8, 6, 16, 3, METALL_LJUS)
    ruta(px, m - 12, 13, 24, 2, METALL_LJUS)      # ljus överkant
    ruta(px, m - 13, 35, 26, 3, SKUGGA)           # halslinningen
    # AXELPLÅTEN som en trapetsoid som vidgar nedåt, inte en rak kloss: en rak kloss läses som en
    # sockel/piedestal (granskningen: "ser ut som en gravsten eller en brevlåda"), medan en sluttning
    # ger axlar och förankrar hjälmen på en kropp.
    ruta(px, m - 11, 38, 22, 2, METALL)
    ruta(px, m - 13, 40, 26, 3, METALL)
    ruta(px, m - 15, 43, 30, 4, METALL)     # sista raden fri: porträttet får inte nå sin egen kant
    ruta(px, m - 11, 38, 22, 1, METALL_LJUS)
    # VISIRET: en mörk öppning över ögonen och en lodrät springa ned över näsan (korset). Vid den här
    # storleken är det korset som gör att bilden läses som en hjälm och inte som en hink.
    ruta(px, m - 10, 20, 20, 5, SOT)
    ruta(px, m - 1, 16, 2, 14, SOT)
    ruta(px, m - 10, 19, 20, 1, MÖRK)             # skuggan ovanför öppningen
    # NITAR längs kanterna: fyra i kupan och två i axelplåten.
    for x in (m - 11, m + 8):
        for y in (15, 31):
            ruta(px, x, y, 2, 2, HÖGDAGER)
    for x in (m - 13, m + 11):
        ruta(px, x, 41, 2, 3, HÖGDAGER)
    ruta(px, m - 2, 43, 4, 2, MÖRK)               # halsens springa i axelplåten
    # En repa i kupan på vänster sida (fackelskenet faller från vänster i spelets korridorer).
    ruta(px, m - 9, 24, 4, 1, METALL_MER)
    ruta(px, m - 8, 25, 2, 1, METALL_MER)
    spegel(px)
    # Efter speglingen: en blodfläck med en droppe i nederkanten till vänster, och en ljus kant på
    # hjälmens vänstra sida — de två detaljerna är MEDVETET inte speglade, för ett porträtt som är
    # perfekt symmetriskt ser ut som ett vapenmärke och inte som en figur. En ensam röd pixel såg ut
    # som en felplacerad lysdiod (granskningen), så fläcken är nu 3x2 med en droppe under.
    ruta(px, m - 11, 36, 3, 2, BLOD)
    ruta(px, m - 10, 38, 1, 2, BLOD)
    ruta(px, m - 13, 18, 1, 14, HÖGDAGER)
    return px


## Ljussättningen läggs på EFTER symmetrikontrollen: hjälmen är byggd symmetrisk, men ljuset faller från
## vänster (facklorna i spelets korridorer står till vänster). Strukturen mäts på den osläckta bilden, så
## en gradient kan inte dölja en sned form.
def ljus(px: list[list[int]]) -> None:
    for j in range(H):
        for i in range(B):
            if px[j][i] in (METALL, METALL_LJUS, METALL_MER):
                if i < B // 2 - 7:
                    px[j][i] = min(px[j][i] + 1, HÖGDAGER)
                elif i > B // 2 + 7:
                    px[j][i] = max(px[j][i] - 1, SKUGGA)


def checka(px: list[list[int]]) -> int:
    """Mäter bilden: genomskinlig ram, att metall, visir och detaljer finns, och att hjälmen är
    symmetrisk (spegelprovet) — samma läxa som kortbaksidan och menymärket."""
    fel = 0
    ram = px[0] + [rad[0] for rad in px] + [rad[B - 1] for rad in px] + px[H - 1]
    if any(v != TOM for v in ram):
        print("  FEL  porträttet når ytterkanten (ingen genomskinlig ram kvar)")
        fel += 1
    else:
        print("  ok   genomskinlig ram runt porträttet (%d px)" % len(ram))
    metall = sum(1 for rad in px for v in rad if v in (METALL, METALL_LJUS, METALL_MER))
    visir = sum(1 for rad in px for v in rad if v == SOT)
    print("  %s   hjälmen syns (%d metallpixlar)" % ("ok  " if metall >= 250 else "FEL ", metall))
    fel += 0 if metall >= 250 else 1
    print("  %s   visiret syns (%d mörka pixlar)" % ("ok  " if visir >= 60 else "FEL ", visir))
    fel += 0 if visir >= 60 else 1
    # Symmetrin mäts i KUPA (raderna 8-34, kolumnerna 12-36). Blodfläcken i nederkanten och den ljusa
    # vänsterkanten ligger utanför med flit — ett porträtt som är perfekt symmetriskt ser ut som ett
    # vapenmärke, inte som en figur — och med dem inräknade mätte provet 20 px och föll.
    osym = 0
    for j in range(8, 35):
        for i in range(12, B // 2):
            if px[j][i] != px[j][B - 1 - i]:
                osym += 1
    print("  %s   hjälmen är symmetrisk (%d osymmetriska px i kupan)"
        % ("ok  " if osym == 0 else "FEL ", osym))
    fel += 0 if osym == 0 else 1
    return fel


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--skala", type=int, default=4)
    a = ap.parse_args()
    färger = palett()
    px = porträtt()
    fel = checka(px)                 # strukturen först ...
    ljus(px)                         # ... sedan ljuset, som är osymmetriskt med flit
    if not a.check:
        UT.mkdir(parents=True, exist_ok=True)
        im = Image.new("RGBA", (B, H), (0, 0, 0, 0))
        för = im.load()
        for j in range(H):
            for i in range(B):
                if px[j][i] >= 0:
                    för[i, j] = färger[px[j][i]]
        im.save(UT / "portratt.png")
        print("skrev %s (%dx%d)" % ((UT / "portratt.png").relative_to(ROOT), B, H))
        karta = Image.new("RGBA", (B * a.skala, H * a.skala), (10, 8, 12, 255))
        karta.paste(im.resize((B * a.skala, H * a.skala), Image.NEAREST), (0, 0))
        karta.save(UT / "_portratt_kontaktkarta.png")
        print("kontaktkarta: %s" % (UT / "_portratt_kontaktkarta.png").relative_to(ROOT))
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
