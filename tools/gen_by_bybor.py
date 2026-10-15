"""Byns bybor som voxlar, klippta ur Alex' egen målning (M129).

    python3 tools/gen_by_bybor.py            # skriv game/assets/by/bybor/*.png + bybor.json
    python3 tools/gen_by_bybor.py --check    # mät mot källan och mot filerna på disk, exit 1 vid fel

Alex 15/10: *"Jag tog bort alla NPC's från modellen, tänkte att man kan klistra in från bilden de
karaktärer som finns, men som voxlar, så de står där, men platt... typ."*

Byborna i `game/assets/ui/byn.png` är målade figurer i scenen — samma personer som den gamla
Blender-modellen hade som lådfigurer (105 objekt under förledet `Patron_*`, `Blacksmith_NPC_*`,
`Bard_*`, `Walker_*`, `Herder_*`, `Shepherd_*`, `Jewel_Shopper_*`, `Gate_Traveler_*`, `Horse_*`,
`Sheep_*`, borttagna i commit 1f6b86f0). Den här generatorn klipper ut dem ur målningen så spelet
kan resa dem som voxlar i 3D-byn (se `game/ui/bybor.gd`).

VARFÖR RUTOR OCH INTE EN MASKIN: bakgrunden bakom en bybo är en målad by — kullersten, bänkar,
väggar, en ässja. Uppmätt 15/10: tre olika automatiska masker (lokal färgkontinuitet, kantbarriär,
kantpalett) läckte alla in i figuren (smedens ben och byxor försvann, eller hela rutan blev
"figur"), för figuren står INTE på en jämn duk. En ruta som följer figuren tätt plus en försiktig
borttagning av det som hänger ihop med rutans KANT (kantpalett, tolerans `tol` per post) ger ett
rent snitt där målningens egen kontur gör jobbet. `--check` mäter hur mycket som togs bort; en
post vars borttagning faller utanför sitt fönster är en ruta som sitter fel.

RUTORNA ÄR LÄSTA UR BILDEN, inte gissade: varje ruta är en mätning i remsor av `byn.png` med
rutnät (se `docs/`-anteckningen i commiten). Figurens mitt i bilden ger bybons x i världen genom
husmappningen nedan — husens rutor ur `PLATSER` i `game/ui/village_view.gd` mot husens egna
b-bboxar i `byn.glb` — så bybon hamnar vid samma hus som i målningen.

Höjden per kategori är PARITET med den gamla modellen (en människa 1,00 m, hästen 1,05, fåret
0,45, lammet 0,34), inte en skala ur rutans pixelantal: bilden är målad i perspektiv, så en figur
längre fram är ritad större, och att följa det hade gett en dvärg längst bak och en jätte längst
fram i stället för en by.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
KÄLLA = ROOT / "game" / "assets" / "ui" / "byn.png"
UT = ROOT / "game" / "assets" / "by" / "bybor"
DATA = ROOT / "game" / "assets" / "by" / "bybor.json"
KONTAKT = UT / "_kontaktkarta.png"

## HUSMAPPNINGEN: bybons x i världen ur figurens x i målningen.
## MÄTT: husens mitt i procent av bildbredden (PLATSER:s `x`-fält) mot husens mitt i `byn.glb`
## (Weaver -14,07 vid 8,5 %, Smith -9,93 vid 22,5 %, Tavern -3,74 vid 40 %, Gate 1,52 vid 53,5 %,
## Jeweler 6,90 vid 69 %, Exit 11,20 vid 80,5 %). Minsta-kvadrat-anpassning över de sex punkterna
## ger linjen nedan; största felet är 0,47 m, och de gamla NPC-positionerna i modellen hamnar inom
## 0,5 m från samma linje (Blacksmith_NPC -11,90 mot -11,52, Patron -5,55 mot -6,08). Byborna står
## alltså där målningen har dem, inte på en påhittad plats.
X_LUTNING = 0.35476
X_NOLLA = -17.55410
BILD_BREDD = 3232

## Höjd per kategori i meter — paritet med den gamla modellen (se filhuvudet).
KATEGORI_HÖJD = {"man": 1.00, "kvinna": 1.00, "barn": 0.72, "häst": 1.05, "får": 0.45,
                 "lamm": 0.34, "hund": 0.30}

## MARKENS HÖJD, mätt med bboxar ur byn.glb: gatans och hagens översta yta ligger på 0,05-0,12 m,
## så byborna ställs på 0,08 (gatan) respektive 0,12 (hagen) i stället för på 0 där fötterna sjunker.
Y_GATA, Y_HAGE = 0.08, 0.12

## Toleransen för kantborttagningen, MÄTT: fyra värden prövades mot hela tabellen 15/10 och andelen
## borttaget gick från 2-6 % (0,00 — bara den platta ytan närmast kanten) till 67 % (0,04), där både
## huvuden och byxor försvann. Bakgrunden bakom en bybo är MÅLAD (kullersten, bänkar, ässjan) med
## toner som ligger nära figurens egna, så toleransen får inte vara stor: 0,01 tar den platta ytan
## runt figuren och lämnar figuren hel.
TOL = 0.01

## Tabellen: (id, ruta i källans px (x0,y0,x1,y1), kategori, djup z, mark-y, text).
## Rutorna är figurens egen ruta med några pixlars marginal, lästa ur målningen (se filhuvudet).
BYBOR = [
    ("handlare",     (498, 880, 545, 968),    "kvinna", -0.10, Y_GATA, "handlerskan bakom saluståndet"),
    ("smed",         (513, 772, 588, 903),   "man",    -0.20, Y_GATA, "smeden vid ässjan"),
    ("pojke",        (592, 1002, 663, 1103), "barn",    0.60, Y_GATA, "pojken med käppen"),
    ("smedkund",     (922, 857, 978, 1043),  "man",     0.60, Y_GATA, "kunden vid städet"),
    ("krog_vänster", (1017, 862, 1073, 953), "man",    -0.20, Y_GATA, "gästen i värdshusfönstret, vänster"),
    ("krog_värd",    (1077, 817, 1128, 933), "man",    -0.20, Y_GATA, "värden bakom disken"),
    ("krog_höger",   (1132, 862, 1188, 953), "man",    -0.20, Y_GATA, "gästen i värdshusfönstret, höger"),
    ("krog_ute",     (1422, 777, 1478, 953), "kvinna",  0.60, Y_GATA, "kvinnan vid tunnan utanför krogen"),
    ("gångerska",    (1622, 817, 1678, 1043), "kvinna", 0.90, Y_GATA, "kvinnan som går över gatan"),
    ("juvel_kund_1", (2007, 1002, 2063, 1078), "man",   0.40, Y_GATA, "kunden utanför juveleraren"),
    ("juvel_kund_2", (2162, 997, 2211, 1075), "kvinna", 0.40, Y_GATA, "kvinnan vid juvelerarens dörr"),
    ("herdinna",     (2552, 877, 2638, 1043), "kvinna", 0.60, Y_HAGE, "herdinnan vid stigen"),
    ("får_1",        (2635, 997, 2698, 1048), "får",    0.70, Y_HAGE, "får på stigen"),
    ("får_2",        (2745, 997, 2813, 1051), "får",    0.70, Y_HAGE, "får på stigen"),
    ("lamm_1",       (2835, 1005, 2901, 1053), "lamm",  0.70, Y_HAGE, "lammet vid hästen"),
    ("häst",         (2885, 925, 3063, 1061), "häst",   0.70, Y_HAGE, "hästen"),
    ("får_3",        (3057, 999, 3123, 1058), "får",    0.70, Y_HAGE, "fåret vid herden"),
    ("herde",        (3062, 875, 3148, 1061), "man",    0.70, Y_HAGE, "herden med repet"),
    ("får_berg_1",   (2759, 787, 2833, 858), "får",    -1.00, Y_HAGE, "får uppe på gräset"),
    ("får_berg_2",   (2859, 757, 2965, 845), "får",    -1.00, Y_HAGE, "får uppe på gräset"),
    ("får_berg_3",   (2992, 755, 3078, 851), "får",    -1.00, Y_HAGE, "får uppe på gräset"),
]

## Fönstret för hur mycket kantborttagningen får ta. MÄTT: 4-22 % per figur vid toleransen 0,01, och
## 67 % vid 0,04 — där både huvuden och byxor försvann. Över taket har fyllningen alltså ätit figuren.
BORTA_MIN, BORTA_MAX = 0.02, 0.35
## Hur stor del av rutan som är FIGUR (längre än `FIGUR_TOL` från rutans kantfärger). Det är den
## siffra som avgör om snittet är en bybo eller en bit målning: mätt 20-40 % för byborna under den
## här versionen, alltså bär varje modell en bit av målningens bakgrund med sig.
##
## VARFÖR DET INTE GÅR ATT GÖRA RENARE (mätt 15/10, fyra metoder mot hela tabellen):
##   * lokal färgkontinuitet (0,06): åt smedens ben och byxor — figuren står inte på en jämn duk.
##   * kantbarriär + frö i figuren: gav 0 px för en figur och hela rutan för en annan (läcker/blockerar).
##   * kantpalett med tolerans: 0,04 åt 67 % (huvuden försvann), 0,01 tar 4-22 %.
##   * avståndströskel mot kantfärgerna (0,06-0,14): karvade sönder kropparna (största komponenten var
##     24-52 % av det kvarvarande för flera figurer).
## Bakgrunden bakom en bybo är MÅLAD (kullersten, bänkar, ässjan, eld) med toner som ligger nära
## figurens egna, så ingen färgregel skiljer dem. RENA SILHUETTER KRÄVER bildens egna sprites/lager
## (Alex' källfil) eller för hand ritade masker — den här generatorn gör resten av kedjan färdig.
FIGUR_TOL = 0.08


def kantpalett(patch: np.ndarray) -> np.ndarray:
    """De vanligaste färgerna på rutans yttersta ring. Bakgrunden runt en bybo är målad (mark, vägg,
    bänk) och har därför flera toner — en enda nyckelfärg hade bara tagit en.
    Färgerna är KÄLLANS EGNA, inte kvantiserade: pixelkonsten har få och platta färger, och en
    kvantisering hade lagt en osynlig tolerans på 1/24 (0,042) på varje jämförelse — mätt 15/10 åt
    den upp både byxor och huvuden på folk medan fåren (vitt mot grönt) klarade sig."""
    ring = np.concatenate([patch[0], patch[-1], patch[:, 0], patch[:, -1]])
    kvant = np.rint(ring * 255).astype(np.uint8)
    unika, antal = np.unique(kvant, axis=0, return_counts=True)
    return unika[antal >= 3].astype(np.float32) / 255.0


def ta_bort_bakgrund(patch: np.ndarray, tol: float) -> np.ndarray:
    """Flodfyllning från rutans kant: en pixel blir genomskinlig om den ligger inom `tol` från NÅGON
    kantfärg OCH hänger ihop med kanten. Figurens mitt når inte kanten och rörs därför inte."""
    h, b = patch.shape[:2]
    pal = kantpalett(patch)
    if len(pal) == 0:
        return np.ones((h, b), dtype=bool)
    borta = np.zeros((h, b), dtype=bool)
    kö: list[tuple[int, int]] = []

    def put(y: int, x: int) -> None:
        if not borta[y, x]:
            borta[y, x] = True
            kö.append((y, x))

    for x in range(b):
        put(0, x)
        put(h - 1, x)
    for y in range(h):
        put(y, 0)
        put(y, b - 1)
    huvud = 0
    while huvud < len(kö):
        y, x = kö[huvud]
        huvud += 1
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < b and not borta[ny, nx]:
                d = np.abs(pal - patch[ny, nx]).max(axis=1).min()
                if d < tol:
                    borta[ny, nx] = True
                    kö.append((ny, nx))
    return borta


## Hur stor andel av en rad/kolumn som får vara "bakgrundsfärg" innan raden räknas som bakgrund när
## figurens egen ruta letas upp. Figuren är smal i förhållande till rutans marginal, så dess rader och
## kolumner domineras av figurens egna färger medan markens och väggens rader domineras av bakgrunden.
RAD_ANDEL = 0.72
TRIM_TOL = 0.03


def bakgrundskarta(patch: np.ndarray, pal: np.ndarray) -> np.ndarray:
    """Per pixel: hur långt den ligger från den NÄRMASTE kantfärgen (största kanalskillnad)."""
    d = None
    for c in pal:
        a = np.abs(patch - c).max(axis=2)
        d = a if d is None else np.minimum(d, a)
    return d if d is not None else np.zeros(patch.shape[:2], dtype=np.float32)


def figur_ruta(patch: np.ndarray) -> tuple[int, int, int, int] | None:
    """Figurens EGEN ruta inuti den grova rutan, mätt som de rader och kolumner som inte domineras av
    kantens färger. Utan det här följer några pixlars marginal med in i modellen, och de pixlarna
    hamnar under fötterna (figuren svävar) och gör modellen bredare än figuren."""
    pal = kantpalett(patch)
    if len(pal) == 0:
        return None
    bak = bakgrundskarta(patch, pal) < TRIM_TOL
    kol = np.nonzero(bak.mean(axis=0) < RAD_ANDEL)[0]
    rad = np.nonzero(bak.mean(axis=1) < RAD_ANDEL)[0]
    if len(kol) == 0 or len(rad) == 0:
        return None
    return int(kol[0]), int(rad[0]), int(kol[-1]) + 1, int(rad[-1]) + 1


def klipp(id: str, ruta: tuple, kategori: str, z: float, y: float, text: str) -> dict:
    """En bybo: rutan ur källan, trimmad till figuren, bakgrunden borta, x i världen ur husmappningen."""
    x0, y0, x1, y1 = ruta
    patch = np.asarray(Image.open(KÄLLA).convert("RGB")).astype(np.float32)[y0:y1, x0:x1] / 255.0
    trimmad = figur_ruta(patch)
    if trimmad is not None:
        tx0, ty0, tx1, ty1 = trimmad
        patch = patch[ty0:ty1, tx0:tx1]
        x0, y0, x1, y1 = x0 + tx0, y0 + ty0, x0 + tx1, y0 + ty1
    borta = ta_bort_bakgrund(patch, TOL)
    rgba = np.dstack([(patch * 255).astype(np.uint8), np.where(borta, 0, 255).astype(np.uint8)])
    bild = Image.fromarray(rgba, mode="RGBA")
    bild.save(UT / f"{id}.png")
    andel = float(borta.mean())
    # FIGURANDELEN: hur mycket av rutan som inte är rutans egen kantfärg. Det är måttet på hur mycket
    # av målningens bakgrund modellen bär med sig (se FIGUR_ANDEL_MIN).
    figur = float((bakgrundskarta(patch, kantpalett(patch)) > FIGUR_TOL).mean())
    x_mitt = (x0 + x1) / 2.0
    return {
        "id": id,
        "bild": f"bybor/{id}.png",
        "text": text,
        "kategori": kategori,
        "höjd_m": KATEGORI_HÖJD[kategori],
        "pos": [round(X_LUTNING * (x_mitt / BILD_BREDD * 100.0) + X_NOLLA, 3), round(y, 3), round(z, 3)],
        "ruta": [x0, y0, x1, y1],
        "grov_ruta": list(ruta),
        "borta": round(andel, 3),
        "figur_andel": round(figur, 3),
        "px": [x1 - x0, y1 - y0],
    }


def bygg() -> list[dict]:
    UT.mkdir(parents=True, exist_ok=True)
    poster = [klipp(*rad) for rad in BYBOR]
    DATA.write_text(json.dumps({"bybor": poster}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    kontaktyta(poster)
    return poster


def kontaktyta(poster: list[dict]) -> None:
    """Alla bybor sida vid sida på schackbräde, i sin egen skala (2x). Figuren avgörs av ögat —
    siffrorna säger hur mycket som togs bort, inte om snittet blev rätt."""
    bilder = [(p["id"], Image.open(UT / f'{p["id"]}.png')) for p in poster]
    s = 2
    höjd = max(b.size[1] for _, b in bilder) * s + 24
    bredd = sum(b.size[0] * s + 12 for _, b in bilder) + 12
    duk = Image.new("RGB", (bredd, höjd), (26, 26, 30))
    for y in range(0, höjd, 8):
        for x in range(0, bredd, 8):
            if (x // 8 + y // 8) % 2:
                duk.paste((52, 52, 58), (x, y, min(x + 8, bredd), min(y + 8, höjd)))
    x = 12
    for id, b in bilder:
        b = b.resize((b.size[0] * s, b.size[1] * s), Image.NEAREST)
        duk.paste(b, (x, 12), b)
        x += b.size[0] + 12
    duk.save(KONTAKT)


def avtryck(p: Path) -> str:
    return hashlib.md5(p.read_bytes()).hexdigest()[:12]


def checka(poster: list[dict]) -> int:
    fel = 0

    def krav(ok: bool, text: str) -> None:
        nonlocal fel
        if not ok:
            fel += 1
        print(("  OK   " if ok else "  ##FEL## ") + text)

    src = np.asarray(Image.open(KÄLLA).convert("RGB"))
    print(f"källa {KÄLLA.name} {src.shape[1]}x{src.shape[0]}, {len(poster)} bybor")
    for p in poster:
        fil = UT / f'{p["id"]}.png'
        if not fil.exists():
            krav(False, f'{p["id"]}: filen saknas')
            continue
        bild = Image.open(fil)
        arr = np.asarray(bild)
        x0, y0, x1, y1 = p["ruta"]
        krav(bild.size == (x1 - x0, y1 - y0), f'{p["id"]}: rutan {bild.size} == {x1 - x0}x{y1 - y0}')
        # PIXLARNA STÄMMER MED KÄLLAN: en klippning får bara sätta alfan, aldrig röra färgen.
        samma = np.array_equal(arr[..., :3], src[y0:y1, x0:x1])
        krav(samma, f'{p["id"]}: färgerna är källans egna ({arr[..., :3].mean():.1f} i medel)')
        alfa = arr[..., 3]
        krav(0 < int((alfa > 0).sum()) < alfa.size, f'{p["id"]}: figuren finns ({(alfa > 0).mean() * 100:.0f} % kvar)')
        krav(BORTA_MIN <= p["borta"] <= BORTA_MAX, f'{p["id"]}: bakgrund borta {p["borta"] * 100:.0f} % inom {BORTA_MIN:.0%}-{BORTA_MAX:.0%}')
        # FIGURANDELEN mäts och skrivs ut men är ingen grind: måttet är för grovt för att fälla på
        # (en ruta inne i krogens mörka interiör får 96 % "figur" eftersom inget där liknar kantens
        # färger, medan ett vitt lamm på grus får 5 %). Det pekar ut vilka rutor som är för stora.
        print(f'  ..   {p["id"]}: figurandel {p["figur_andel"] * 100:.0f} % av rutan (resten är målningens bakgrund)')
        # FOTEN I NEDERKANT: figuren ska stå på rutans nederkant, annars svävar den i modellen.
        nederst = np.nonzero((alfa > 0).any(axis=1))[0]
        krav(len(nederst) > 0 and nederst[-1] >= alfa.shape[0] - 6,
             f'{p["id"]}: figuren når rutans nederkant (rad {int(nederst[-1]) if len(nederst) else -1} av {alfa.shape[0]})')
        krav(-17.0 < p["pos"][0] < 17.0, f'{p["id"]}: x {p["pos"][0]:.2f} inom byn')
    # DETERMINISM: alla filer har ett avtryck, och en andra körning ska ge samma.
    summa = hashlib.md5("".join(avtryck(UT / f'{p["id"]}.png') for p in poster).encode()).hexdigest()[:12]
    print(f"  avtryck {summa}")
    print(f"=== {'KLART' if fel == 0 else f'{fel} FEL'} ({len(poster)} bybor) ===")
    return 1 if fel else 0


def main() -> int:
    global TOL
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="mät i stället för att skriva")
    ap.add_argument("--tol", type=float, default=TOL, help="tolerans för kantborttagningen")
    a = ap.parse_args()
    TOL = a.tol
    poster = bygg()
    for p in poster:
        print(f'{p["id"]:14s} x {p["pos"][0]:7.2f}  z {p["pos"][2]:5.2f}  {p["höjd_m"]:.2f} m  '
              f'borta {p["borta"] * 100:3.0f} %  figur {p["figur_andel"] * 100:3.0f} %  {p["text"]}')
    if a.check:
        return checka(poster)
    return 0


if __name__ == "__main__":
    sys.exit(main())
