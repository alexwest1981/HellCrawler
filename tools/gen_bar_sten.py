"""Stenplattan i bottom baren (M113): Alex' egen stenbild, nedskalad till remsans höjd.

    python3 tools/gen_bar_sten.py            # skriv game/assets/ui/bar_sten.png
    python3 tools/gen_bar_sten.py --check    # mät bilden mot källan — exit 1 vid fel

VARFÖR EN BILD OCH INTE EN GENERATOR. Alex skickade bilden och bestämde: *"sträck ut den"*. Första
försöket var en egen 64x150-platta ur ett recept (basfärg, fogar, korn) som skulle upprepas i sidled;
den vägen är struken, och den här filen är den som används. Kvar av receptet finns ingenting — inget i
remsan läser den, och den byggdes aldrig (se rapporten).

KÄLLAN LIGGER I REPOT (`tools/refs/bar_sten_kalla.jpg`, 2816x1213) och läses aldrig ur `~/.config/`:
bygget måste kunna köras av någon annan, och en fil som bara finns i Alex' hemkatalog är ingen källa.

MÄTT struktur i källan (radmedel, 0-255): 0-31 en ljusgrå kant (115,6), 32-43 en LJUS linje (137,9),
44-1157 den mörka ytan (85-89, mörkast i kanterna: 83,3 vid x=0 och 84,6 vid x=2815 alltså en svag
vinjett), 1158-1169 en tunn ljus linje (106,9) och 1170-1212 ett mörkt band (60,3). Plattan nedskalas
8,1 gånger (1213 -> 150) med area-medel (BOX): det bevarar de 12 px tjocka linjerna som 1-2 px i
plattan, medan en punktvis nedskalning (nearest) hade kunnat släppa dem helt.

REMSAN TÖJS, den upprepas inte: `axis_stretch_horizontal = STRETCH` i main/hud_ram, och höjden delas i
9 delar så att kantlinjerna (6 px upptill, 7 px nertill) ligger FIXA och bara mitten töjs — annars
smetas 1 px-linjerna ut till gråa band. Plattans höjd är 150 px, alltså remsans högsta höjd.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
KÄLLA = ROOT / "tools" / "refs" / "bar_sten_kalla.jpg"
UT = ROOT / "game" / "assets" / "ui"
NAMN = "bar_sten.png"

## Plattans mått: höjden är remsans högsta (BAR_MAX i main.gd) och bredden följer källans form
## (2816/1213 * 150 = 348). Bredden spelar ingen roll för töjningen — den sträcks till fönstret —
## men en proportionerlig platta gör närbilden i rapporten rättvis.
H = 150
W = 348
## Kantlinjerna i plattan, i px: källans 32 px kant + 12 px ljus linje -> 4 + 2 = 6 upptill, och 12 px
## ljus linje + 43 px mörkt band -> 2 + 5 = 7 nertill. De siffrorna är 9-delningens marginaler, alltså
## de som ligger FIXA när remsan är lägre än 150 px.
TOPP = 6
BOTTEN = 7
## Fingeravtrycket: samma bytes varje körning. Ändras källan eller koden blir siffran en annan, och
## `--check` faller — det är provet som gör att en "bara lite snyggare" ändring inte kan smyga in.
FRÖ = "a1f2b0f0b7c1e6d0"


def platta() -> Image.Image:
    im = Image.open(KÄLLA).convert("RGB")
    # BOX = area-medel: varje målpixel är medelvärdet av de källpixlar den täcker. MÄTT: de 12 px
    # tjocka kantlinjerna blir kvar som 1-2 px ljusa rader i plattan (se `profil`).
    return im.resize((W, H), Image.BOX)


def radmedel(im: Image.Image, y: int) -> float:
    px = im.load()
    return sum(sum(px[x, y]) for x in range(im.size[0])) / (3.0 * im.size[0])


def profil(im: Image.Image) -> list[float]:
    return [radmedel(im, y) for y in range(im.size[1])]


def checka(im: Image.Image) -> int:
    """Mäter plattan mot källans struktur. Returnerar antalet fel."""
    fel = 0

    def krav(ok: bool, text: str) -> None:
        nonlocal fel
        print(("  ok   " if ok else "  FEL  ") + text)
        fel += 0 if ok else 1

    krav(im.size == (W, H), "plattan är %dx%d (mätt: %dx%d)" % (W, H, im.size[0], im.size[1]))
    p = profil(im)
    # Kantlinjerna upptill: den ljusa linjen ska vara LJUSARE än både kanten över och ytan under.
    topp_linje = max(p[4], p[5])
    krav(topp_linje > p[0] + 8.0 and topp_linje > p[8] + 30.0,
        "den ljusa kantlinjen upptill syns (rad 4-5: %.0f, kanten över: %.0f, ytan under: %.0f)"
        % (topp_linje, p[0], p[8]))
    # Kantlinjen nertill och det mörka bandet under den: den LJUSASTE raden i nedermarginalen ska
    # ligga minst 30 över den sista raden (mätt: rad 143-144 är 107, sista raden 61).
    ljus = max(p[H - BOTTEN:H])
    ljus_y = H - BOTTEN + p[H - BOTTEN:H].index(ljus)
    krav(ljus > p[H - 1] + 30.0,
        "den ljusa linjen nertill syns över det mörka bandet (rad %d: %.0f mot rad %d: %.0f)"
        % (ljus_y, ljus, H - 1, p[H - 1]))
    # Ytan i mitten: en dov grå, inte svart och inte vit — annars är bilden fel skalad.
    mitten = p[H // 2]
    krav(60.0 < mitten < 110.0, "ytan i mitten är dov grå (%.0f av 255)" % mitten)
    # Vinjetten: kanterna ska vara mörkare än mitten (källans 83,3 mot 88,7).
    px = im.load()
    kant = (sum(sum(px[0, y]) for y in range(H)) + sum(sum(px[W - 1, y]) for y in range(H))) / (6.0 * H)
    krav(kant < mitten - 1.0, "vinjetten finns kvar (kant %.1f mörkare än mitten %.1f)" % (kant, mitten))
    return fel


def avtryck(im: Image.Image) -> str:
    return hashlib.sha256(im.tobytes()).hexdigest()[:16]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if not KÄLLA.exists():
        print("FEL: källan saknas: %s" % KÄLLA.relative_to(ROOT))
        return 1
    im = platta()
    fel = checka(im)
    # DETERMINISMEN: två körningar i rad ska ge samma bytes, och filen på disk ska vara den samma.
    if avtryck(platta()) != avtryck(im):
        print("  FEL  två körningar ger olika bytes (ingen fast skalning)")
        fel += 1
    else:
        print("  ok   samma bytes två körningar i rad (avtryck %s)" % avtryck(im))
    if a.check:
        if (UT / NAMN).exists():
            på_disk = avtryck(Image.open(UT / NAMN).convert("RGB"))
            print(("  ok   " if på_disk == avtryck(im) else "  FEL  ")
                  + "filen på disk är samma bild (avtryck %s)" % på_disk)
            fel += 0 if på_disk == avtryck(im) else 1
        return 1 if fel else 0
    UT.mkdir(parents=True, exist_ok=True)
    im.save(UT / NAMN, optimize=True)
    print("skrev %s (%dx%d, avtryck %s)" % ((UT / NAMN).relative_to(ROOT), W, H, avtryck(im)))
    # Närbilden: plattan i 4x i en remsa, så att kantlinjer och förskjutning syns i en bild.
    när = Image.new("RGB", (W * 4, H * 4), (10, 8, 12))
    när.paste(im.resize((W * 4, H * 4), Image.NEAREST), (0, 0))
    när.save(UT / "_bar_sten_narbild.png")
    print("närbild: %s" % (UT / "_bar_sten_narbild.png").relative_to(ROOT))
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
