"""Bygger startmenyns märke: en brinnande dödskalle som sitter till vänster om det valda menyvalet.

    python3 tools/gen_meny.py            # skriv game/assets/ui/markor.png
    python3 tools/gen_meny.py --check    # mät bilden (alfa, färger, form) — exit 1 vid fel

Referensen (Alex bild 2) markerar det valda menyvalet med en vit dödskalle i en flamma i stället för
med en ram eller en pil. Märket ritas i kod och ur spelets palett: ett eget märke kunde inte lånas ur
kortbaksidan, för den bilden är OPak — en urklippt skalle hade fått en mörk ruta omkring sig i stället
för genomskinlig bakgrund.
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

INRE_B, INRE_H = 21, 19   # formens storlek; udda bredd så flamman kan vara symmetrisk
B, H = INRE_B + 2, INRE_H + 2   # duken: 1 px genomskinlig ram runt om, annars tar lågan i kanten

# Färgindex ur palette.json. Namnen är spelets, inte bildens — paletten är en lista, och en gissning
# om ordningen är ett fel som syns först på bild.
TOM = -1
SOT = 1
MÖRK = 2
BEN_SKUGGA = 22   # varmgrå; 7 är neutralt grå och läste som en metallist över skallen (granskningen)
BEN = 8
BLOD = 10
ELD_MÖRK = 12
ELD = 13
ELD_LJUS = 14


def palett() -> list[tuple[int, int, int, int]]:
    färger = json.loads(PALETT.read_text(encoding="utf-8"))
    return [(c[0], c[1], c[2], 255) for c in färger]


def ruta(px: list[list[int]], x: int, y: int, b: int, h: int, färg: int) -> None:
    """Fyller en ruta, klippt mot duken: en form som ritas utanför kanten ska inte krascha provet."""
    for j in range(max(1, y), min(H - 1, y + h)):
        for i in range(max(1, x), min(B - 1, x + b)):
            px[j][i] = färg


def märke() -> list[list[int]]:
    # Formen ritas i den inre rutan och får sedan 1 px genomskinlig ram runt om.
    #
    # Första försöket (17x15) föll i granskningen: "ser snarare ut som en dödskalle i en
    # lykta/arkadmaskin på en piedestal" — lågan var en rak trappstegsform och tänderna två prickar i
    # hörnen. Nu är lågan TRE spetsiga tungor som reser sig bakom skallen (mittentungan högst), skallen
    # är större, käken har en sammanhängande tandrad och grålisten över hjässan är borta (7 är neutralt
    # grå och läste som en metallkant; 22 är varmgrå).
    px = [[TOM] * B for _ in range(H)]
    m = B // 2                      # mitten i en 23 px bred duk (1 px ram + 11)

    # FLAMMAN ritas först och skallen läggs över. Tre lager: mörk ytterst, sedan eld, ljusast innerst —
    # det är lagren som gör att den läses som eld och inte som en gul klump. Varje ruta är speglad kring
    # mittenkolumnen, vilket är det provet mäter.
    ruta(px, m - 8, 12, 17, 6, ELD_MÖRK)     # 3..19
    ruta(px, m - 7, 10, 15, 6, ELD)          # 4..18
    ruta(px, m - 6, 9, 13, 6, ELD_LJUS)      # 5..17
    ruta(px, m - 7, 5, 3, 7, ELD)            # vänster tunga
    ruta(px, m + 5, 5, 3, 7, ELD)            # höger tunga (spegeln: 22-6 = 16 .. 18)
    ruta(px, m - 1, 3, 3, 9, ELD_LJUS)       # mittentungan, högst
    ruta(px, m - 2, 6, 1, 4, ELD_MÖRK)       # skuggan mellan tungorna
    ruta(px, m + 2, 6, 1, 4, ELD_MÖRK)

    # SKALLEN: hjässa (6 rader), käke (3 rader), ögonhålor, näsa och en TANDRAD som är sammanhängande
    # (fyra mörka rutor i käkens nederkant) i stället för två prickar i hörnen.
    ruta(px, m - 5, 7, 11, 6, BEN)           # 6..16, hjässan
    ruta(px, m - 5, 7, 11, 1, BEN_SKUGGA)    # hjässans överkant i skugga
    ruta(px, m - 3, 13, 7, 3, BEN)           # käken, 8..14
    ruta(px, m - 4, 8, 2, 2, MÖRK)           # vänster öga, 7..8
    ruta(px, m + 3, 8, 2, 2, MÖRK)           # höger öga, 14..15 (spegeln av 7..8)
    ruta(px, m, 10, 1, 2, MÖRK)              # näsan
    for t in range(m - 3, m + 4, 2):         # tänder: 8, 10, 12, 14
        ruta(px, t, 15, 1, 1, MÖRK)
    return px


def rita(px: list[list[int]], färger: list[tuple[int, int, int, int]]) -> Image.Image:
    im = Image.new("RGBA", (B, H), (0, 0, 0, 0))
    för = im.load()
    for j in range(H):
        for i in range(B):
            if px[j][i] >= 0:
                för[i, j] = färger[px[j][i]]
    return im


def checka(px: list[list[int]], färger: list[tuple[int, int, int, int]]) -> int:
    """Mäter bilden: ett märke som tappar kontur, alfa eller färg syns först på skärmen — inte här.

    Fyra saker: (1) alfa runt om (annars blir märket en ruta över bakgrunden), (2) skallen finns,
    (3) lågan finns, (4) märket är symmetriskt kring sin mittkolumn — en sned skalle ser ut som ett
    fel, och det felet gjorde kortbaksidan en gång redan (2 997 osymmetriska pixlar).
    """
    fel = 0
    ytterst = px[0] + [rad[0] for rad in px] + [rad[B - 1] for rad in px] + px[H - 1]
    if any(v != TOM for v in ytterst):
        print("  FEL  märket når ytterkanten (ingen genomskinlig ram kvar)")
        fel += 1
    else:
        print("  ok   genomskinlig ram runt märket (%d px)" % len(ytterst))

    ben = sum(1 for rad in px for v in rad if v in (BEN, BEN_SKUGGA))
    eld = sum(1 for rad in px for v in rad if v in (ELD_MÖRK, ELD, ELD_LJUS))
    # Parenteser och inte hakparentes: i Python är en lista ETT värde, så "%s %d" % [a, b] ger
    # "not enough arguments" (i GDScript är det tvärtom — där är en array rätt).
    print("  %s   skallen syns (%d benpixlar)" % ("ok  " if ben >= 20 else "FEL ", ben))
    fel += 0 if ben >= 20 else 1
    print("  %s   lågan syns (%d eldpixlar)" % ("ok  " if eld >= 30 else "FEL ", eld))
    fel += 0 if eld >= 30 else 1

    osym = 0
    for j in range(H):
        for i in range(B // 2):
            if px[j][i] != px[j][B - 1 - i]:
                osym += 1
    print("  %s   märket är symmetriskt kring mitten (%d osymmetriska px)"
        % ("ok  " if osym == 0 else "FEL ", osym))
    fel += 0 if osym == 0 else 1
    return fel


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="mät i stället för att skriva")
    ap.add_argument("--skala", type=int, default=3, help="förstoring i kontaktkartan")
    a = ap.parse_args()

    färger = palett()
    px = märke()
    fel = checka(px, färger)

    if not a.check:
        UT.mkdir(parents=True, exist_ok=True)
        im = rita(px, färger)
        im.save(UT / "markor.png")
        print("skrev %s (%dx%d)" % ((UT / "markor.png").relative_to(ROOT), B, H))
        karta = Image.new("RGBA", (B * a.skala, H * a.skala), (10, 8, 12, 255))
        karta.paste(im.resize((B * a.skala, H * a.skala), Image.NEAREST), (0, 0))
        karta.save(UT / "_markor_kontaktkarta.png")
        print("kontaktkarta: %s" % (UT / "_markor_kontaktkarta.png").relative_to(ROOT))
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
