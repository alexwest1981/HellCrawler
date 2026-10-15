"""Byns bybor som voxlar, klippta ur Alex' byboark (M129).

    python3 tools/gen_by_bybor.py            # skriv game/assets/by/bybor/*.png + bybor.json
    python3 tools/gen_by_bybor.py --check    # mät mot arken och mot filerna på disk, exit 1 vid fel

Alex 15/10: *"Jag la till två bilder med npc's i assets."* — `game/images/townfolks.jpeg` (20 bybor i
4x5 rutor: Blacksmith, Innkeeper, Farmer, Merchant, Elder / Guard, Baker, Young Boy, Young Girl,
Miller / Herbalist, Alchemist, Fisherman, Carpenter, Maid / Noblewoman, Nobleman, Priest, Archer,
Tavern Patron) och `game/images/townfolks2.jpeg` (8 i 2x4: Blacksmith, Jeweler, Drunkard, Mage /
sittande, herde med hund, häst, två får).

Det första försöket klippte byborna ur MÅLNINGEN (`assets/ui/byn.png`) och det gick inte: bakgrunden
där är målad och ingen färgregel skiljer figur från kullersten, bänk och ässja (fyra metoder mätta och
förkastade, se `hellcrawlers`-skillen). Arken är ritade på VIT botten, och då är klippningen en mätning
i stället för en gissning: rutnätet delar arket, bakgrunden läses ur bildens hörn, och figuren blir de
sammanhängande fälten i rutan (etikettens bokstäver är för små för att räknas).

VAR DE STÅR ÄR OFÖRÄNDRAT: positionerna kommer ur husmappningen mot den gamla modellen (husens mitt i
`PLATSER` mot husens mitt i `byn.glb`, sex punkter, största felet 0,47 m) och bor i tabellen nedan.
Arken ändrar hur en bybo SER UT, inte var han står. Höjden per kategori är paritet med den gamla
modellen (människa 1,00 m, häst 1,05, får 0,45, lamm 0,34); en post som bär rekvisita i samma ruta
(smeden har städ och ässja) har sin egen höjd i stället, så mannen blir en man.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
UT = ROOT / "game" / "assets" / "by" / "bybor"
DATA = ROOT / "game" / "assets" / "by" / "bybor.json"
KONTAKT = UT / "_kontaktkarta.png"

## Arken och antalet rader i dem. Filerna ligger i game/images/ som Alex' övriga ark.
## Raderna är jämna band (ark 1: 384 px, ark 2: 768 px) och figurerna ligger i x-ordning inom bandet —
## rutnätets KOLUMNER är däremot inte figurens rutor: flera figurer står över en kolumngräns (mätt 15/10
## skar den kolumnbundna klippningen av maidens vänstra sida med 78 px och tavernapatronens med 78 px).
## Figuren väljs därför på sin PLATS I RADEN, inte i en kolumn.
ARK = {
    "bybor": (ROOT / "game" / "images" / "townfolks.jpeg", 4),
    "bybor2": (ROOT / "game" / "images" / "townfolks2.jpeg", 2),
}

## Bakgrunden: avståndet från arkets egen hörnfärg (vit). Låg nog att ta jpeg-bruset nära vitt, hög nog
## att lämna kvar figurens mörka kontur och skugga.
BAKGRUND_TOL = 0.12
## Fält mindre än så är etikettbokstäver och brus, inte figurer. MÄTT: figurens egna fält ligger på
## 18 000-160 000 px, medan bokstäverna under etiketten ligger på 550-1 400 px — de faller bort både på
## storleken och på att de sitter i rutans nederkant (se `ETIKETT_TOPP`).
FALT_MIN = 800
## Etiketten (blacktexten under varje figur) sitter i rutans nederkant. FÄLT SOM BÖRJAR här eller
## längre ned är text: mätt 15/10 börjar bokstäverna på 0,91 av rutans höjd i båda arken, medan den
## lägsta figuren slutar på 0,78.
ETIKETT_TOPP = 0.80
## Rimligt mått på en klippt figur i arkets px. MÄTT: 200-360 px i ark 1, 300-660 px i ark 2. Utanför
## det betyder det att rutnätet eller bakgrunden mättes fel, och då blir modellen fel i spelet.
PX_MIN, PX_MAX = 120, 900
## Fåren i ark 2 står ihop: två djur i samma fält och INGET gap mellan dem. Delningen sker därför på
## mitten av fältet. MÄTT 15/10: den smalaste kolumnen letades upp först, låg 45 px fel och skar av det
## högra fårets huvud; en delning på mitten (och bara den vänstra halvan) ger EN hel sheep — huvud, alla
## fyra ben, inget av grannen.
FAR_HALVA = 0.50
## Målhöjden på den sparade figuren, i px. Voxlarna använder 16 celler över figurens höjd (`Voxel.ur_ark`
## med `sidor` 8 x `DETALJ` 2) och cellen blir därför 8 px med den här höjden — ändå fyra gånger mer
## källpixel per cell än vad `DETALJ` tillåter. MÄTT 15/10: 21 bybor klippta i arkets egen storlek
## (442-577 px höga) byggde byn på 874-1025 ms, mot 103 ms för de gamla små rutorna; nedskalningen tar
## 96 % av pixelarbetet utan att ändra rutnätet. Färgen medelvärdesbildas (BOX) och alfan trösklas, så
## konturen förblir hård.
MÅL_PX = 128
## Hur stort ett fält måste vara för att räknas som figur, i andel av radens största fält. Rekvisitan
## (smedens städ och ässja) ligger på 9-19 % av mannen medan minsta figuren i ett band är 36 % av bandets
## största, så gränsen skiljer dem åt med god marginal.
FIGUR_ANDEL = 0.30

## Höjd per kategori i meter — paritet med den gamla modellen.
KATEGORI_HÖJD = {"man": 1.00, "kvinna": 1.00, "barn": 0.72, "häst": 1.05, "får": 0.45,
                 "lamm": 0.34, "hund": 0.30}

## Tabellen: (id, kategori, z, mark-y, x, ark, rad, figur i raden, halva, höjd (0 = kategorins), text).
## Figuren väljs på sin plats i raden (se ARK): ark 1 är 4 rader x 5 bybor, ark 2 är 2 rader där rad 1
## har den sittande, herden med hunden, hästen och fåren.
BYBOR = [
    ("handlare",     "kvinna", -0.10, 0.08, -11.83, "bybor",  0, 3, None, 0.0, "handlerskan bakom saluståndet (Merchant)"),
    ("smed",         "man",    -0.20, 0.08, -11.51, "bybor2", 0, 0, None, 0.0, "smeden vid ässjan (Blacksmith)"),
    ("pojke",        "barn",    0.60, 0.08, -10.67, "bybor",  1, 2, None, 0.0, "pojken med käppen (Young Boy)"),
    ("smedkund",     "man",     0.60, 0.08,  -7.13, "bybor",  0, 2, None, 0.0, "kunden vid städet (Farmer)"),
    ("krog_vänster", "man",    -0.20, 0.08,  -6.08, "bybor2", 0, 2, None, 0.0, "gästen i värdshusfönstret, vänster (Drunkard)"),
    ("krog_värd",    "man",    -0.20, 0.08,  -5.45, "bybor",  0, 1, None, 0.0, "värden bakom disken (Innkeeper)"),
    ("krog_höger",   "man",    -0.20, 0.08,  -4.82, "bybor",  3, 4, None, 0.0, "gästen i värdshusfönstret, höger (Tavern Patron)"),
    ("krog_ute",     "kvinna",  0.60, 0.08,  -1.64, "bybor",  2, 4, None, 0.0, "kvinnan vid tunnan utanför krogen (Maid)"),
    ("gångerska",    "kvinna",  0.90, 0.08,   0.56, "bybor",  2, 0, None, 0.0, "kvinnan som går över gatan (Herbalist)"),
    ("juvel_kund_1", "man",     0.40, 0.08,   4.78, "bybor2", 0, 1, None, 0.0, "juveleraren utanför sin dörr (Jeweler)"),
    ("juvel_kund_2", "kvinna",  0.40, 0.08,   6.45, "bybor2", 0, 3, None, 0.0, "kunden vid juveleraren (Mage)"),
    ("herdinna",     "kvinna",  0.60, 0.12,  10.93, "bybor2", 1, 0, None, 0.0, "herdinnan vid stigen (sittande)"),
    ("får_1",        "får",     0.70, 0.12,  11.72, "bybor2", 1, 3, 0,    0.0, "får på stigen"),
    ("får_2",        "får",     0.70, 0.12,  12.95, "bybor2", 1, 3, 0,    0.0, "får på stigen"),
    ("lamm_1",       "lamm",    0.70, 0.12,  13.93, "bybor2", 1, 3, 0,    0.0, "lammet vid hästen"),
    ("häst",         "häst",    0.70, 0.12,  15.10, "bybor2", 1, 2, None, 0.0, "hästen"),
    ("får_3",        "får",     0.70, 0.12,  16.36, "bybor2", 1, 3, 0,    0.0, "fåret vid herden"),
    ("herde",        "man",     0.70, 0.12,  16.53, "bybor2", 1, 1, None, 0.0, "herden med hunden"),
    ("får_berg_1",   "får",    -1.00, 0.12,  13.14, "bybor2", 1, 3, 0,    0.0, "får uppe på gräset"),
    ("får_berg_2",   "får",    -1.00, 0.12,  14.34, "bybor2", 1, 3, 0,    0.0, "får uppe på gräset"),
    ("får_berg_3",   "får",    -1.00, 0.12,  15.71, "bybor2", 1, 3, 0,    0.0, "får uppe på gräset"),
]


def ark_bild(namn: str) -> tuple[np.ndarray, np.ndarray]:
    """Arket som flyttal 0-1 och dess bakgrundsfärg (ur bildens hörn)."""
    väg = ARK[namn][0]
    if not väg.exists():
        raise SystemExit(f"FEL: arket saknas: {väg}")
    a = np.asarray(Image.open(väg).convert("RGB")).astype(np.float32) / 255.0
    hörn = np.concatenate([a[0:8, 0:8].reshape(-1, 3), a[0:8, -8:].reshape(-1, 3),
                           a[-8:, 0:8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)])
    return a, hörn.mean(axis=0)


def falt(mask: np.ndarray) -> list[tuple[int, int, int, int, int]]:
    """Sammanhängande fält i en mask, som (px, x0, y0, x1, y1)."""
    h, b = mask.shape
    sedd = np.zeros((h, b), dtype=bool)
    ut = []
    for y in range(h):
        for x in range(b):
            if mask[y, x] and not sedd[y, x]:
                kö = deque([(y, x)])
                sedd[y, x] = True
                xs_min, ys_min, xs_max, ys_max, n = x, y, x, y, 0
                while kö:
                    cy, cx = kö.popleft()
                    n += 1
                    xs_min = min(xs_min, cx)
                    xs_max = max(xs_max, cx)
                    ys_min = min(ys_min, cy)
                    ys_max = max(ys_max, cy)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < b and mask[ny, nx] and not sedd[ny, nx]:
                            sedd[ny, nx] = True
                            kö.append((ny, nx))
                ut.append((n, xs_min, ys_min, xs_max, ys_max))
    return ut


def figur_ruta(namn: str, rad: int, nr: int, val: int | None) -> tuple[int, int, int, int]:
    """Figurens ruta i arket, MÄTT: radbandet delas upp i sammanhängande fält, etikettens bokstäver
    (i bandets nederkant) och rekvisitan (små fält — smedens städ och ässja) faller bort, och det som
    blir kvar sorteras i x-ordning: `nr` är figurens plats i raden.
    `val` väljer halvan när rutan har TVÅ djur i samma fält (fåren står ihop, se `FAR_HALVA`). Rutan är
    figurens EGEN bbox utan marginal — modellens underkant är fötterna, och provet mäter att figuren når
    rutans båda kanter."""
    a, bg = ark_bild(namn)
    _, rader = ARK[namn]
    h, b = a.shape[:2]
    ch = h / rader
    y0, y1 = int(round(rad * ch)), int(round((rad + 1) * ch))
    mask = np.abs(a[y0:y1] - bg).max(axis=2) > BAKGRUND_TOL
    fält = [f for f in falt(mask) if f[0] >= FALT_MIN and f[2] < ETIKETT_TOPP * (y1 - y0)]
    if not fält:
        raise SystemExit(f"FEL: inga figurer i {namn} rad {rad}")
    # Rekvisitan är ett eget fält och mycket mindre än figuren (mätt: städet och ässjan 9-19 % av
    # mannen, medan minsta figuren i ett band är 36 % av bandets största).
    gräns = FIGUR_ANDEL * max(f[0] for f in fält)
    figurer = sorted([f for f in fält if f[0] >= gräns], key=lambda f: f[1])
    if nr >= len(figurer):
        raise SystemExit(f"FEL: {namn} rad {rad} har {len(figurer)} figurer, nr {nr}")
    n, xs0, ys0, xs1, ys1 = figurer[nr]
    if val is not None:
        skarv = xs0 + int((xs1 - xs0) * FAR_HALVA)
        xs0, xs1 = (xs0, skarv) if val == 0 else (skarv + 1, xs1)
        # Halvan mäts om: de två fåren har olika höjd, och en halva som ärver hela fältets höjd får
        # genomskinliga rader över och under sig (modellen blir högre än djuret).
        inne = mask[ys0:ys1 + 1, xs0:xs1 + 1]
        rader = np.nonzero(inne.any(axis=1))[0]
        kolonner = np.nonzero(inne.any(axis=0))[0]
        if len(rader) == 0 or len(kolonner) == 0:
            raise SystemExit(f"FEL: tom halva i {namn} rad {rad} nr {nr} val {val}")
        ys0, ys1 = ys0 + int(rader[0]), ys0 + int(rader[-1])
        xs0, xs1 = xs0 + int(kolonner[0]), xs0 + int(kolonner[-1])
    return xs0, y0 + ys0, xs1 + 1, y0 + ys1 + 1


def skala(bild: Image.Image) -> Image.Image:
    """Ned till `MÅL_PX` höjd (se den konstanten): färgen medelvärdesbildas och alfan trösklas, så
    konturen förblir hård. Utan nedskalningen bygger byn på ~1 s (mätt) för pixelarbete voxlarna
    ändå kastar bort."""
    if bild.size[1] <= MÅL_PX:
        return bild
    f = bild.size[1] / float(MÅL_PX)
    ny = (max(1, round(bild.size[0] / f)), MÅL_PX)
    a = np.asarray(bild.resize(ny, Image.Resampling.BOX)).copy()
    a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    return Image.fromarray(a, mode="RGBA")


def klipp(post: tuple) -> dict:
    """En bybo: figurens ruta i arket, bakgrunden genomskinlig, resten orörd färg."""
    id, kat, z, y, x, ark, rad, nr, val, höjd_egen, text = post
    a, bg = ark_bild(ark)
    rx0, ry0, rx1, ry1 = figur_ruta(ark, rad, nr, val)
    ruta = a[ry0:ry1, rx0:rx1]
    alfa = np.where(np.abs(ruta - bg).max(axis=2) > BAKGRUND_TOL, 255, 0).astype(np.uint8)
    bild = Image.fromarray(np.dstack([(ruta * 255).astype(np.uint8), alfa]), mode="RGBA")
    bild = skala(bild)
    bild.save(UT / f"{id}.png")
    höjd = höjd_egen if höjd_egen > 0.0 else KATEGORI_HÖJD[kat]
    return {
        "id": id,
        "bild": f"bybor/{id}.png",
        "text": text,
        "kategori": kat,
        "höjd_m": round(höjd, 3),
        "pos": [round(x, 3), round(y, 3), round(z, 3)],
        "källa": f"{ARK[ark][0].name} rad {rad} figur {nr}" + ("" if val is None else f", halva {val}"),
        "ark": ark,
        "ark_ruta": [rx0, ry0, rx1, ry1],
        "px": [bild.size[0], bild.size[1]],
    }


def bygg() -> list[dict]:
    UT.mkdir(parents=True, exist_ok=True)
    poster = [klipp(rad) for rad in BYBOR]
    DATA.write_text(json.dumps({"bybor": poster}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    kontaktyta(poster)
    return poster


def kontaktyta(poster: list[dict]) -> None:
    """Alla bybor sida vid sida på schackbräde (2x). Siffrorna säger att klippningen är gjord; bara
    ögat säger om figuren blev rätt."""
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
    for _, b in bilder:
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

    print(f"{len(poster)} bybor ur {len(ARK)} ark")
    for p in poster:
        fil = UT / f'{p["id"]}.png'
        if not fil.exists():
            krav(False, f'{p["id"]}: filen saknas')
            continue
        bild = Image.open(fil)
        arr = np.asarray(bild)
        alfa = arr[..., 3]
        a, bg = ark_bild(p["ark"])
        x0, y0, x1, y1 = p["ark_ruta"]
        krav(bild.size == (p["px"][0], p["px"][1]), f'{p["id"]}: måttet {bild.size} är tabellens')
        krav(bild.size[0] / bild.size[1] > 0.1, f'{p["id"]}: rutan är {bild.size[0]}x{bild.size[1]} px')
        # RUTAN LIGGER I ARKET, och figuren är högst lika hög som rutan (nedskalningen krymper, aldrig
        # tvärtom) — ett negativt eller förskjutet svar betyder att rutnätet mättes fel.
        krav(0 <= x0 < x1 <= a.shape[1] and 0 <= y0 < y1 <= a.shape[0],
             f'{p["id"]}: rutan ({x0},{y0})-({x1},{y1}) ligger i arket {a.shape[1]}x{a.shape[0]}')
        krav(bild.size[1] <= y1 - y0, f'{p["id"]}: figuren är {bild.size[1]} px hög av rutans {y1 - y0}')
        # FÄRGEN ÄR ARKETS. Bara figurens pixlar jämförs: nedskalningen av en RGBA-bild lämnar
        # genomskinliga pixlar svarta (Pillow premultiplicerar om alfakanalen), och de pixlarna syns
        # aldrig i spelet. Medelvärdet över figuren är däremot oförändrat av nedskalningen.
        källa = a[y0:y1, x0:x1] * 255.0
        källa_figur = np.abs(a[y0:y1, x0:x1] - bg).max(axis=2) > BAKGRUND_TOL
        avvikelse = float(np.abs(arr[..., :3][alfa > 0].mean(axis=0)
                                 - källa[källa_figur].mean(axis=0)).max())
        krav(avvikelse < 4.0, f'{p["id"]}: figurens medelfärg är arkets ({avvikelse:.2f} steg från källan)')
        kvar = float((alfa > 0).mean())
        krav(0.10 < kvar < 0.95, f'{p["id"]}: figuren fyller rutan, inte bakgrunden ({kvar * 100:.0f} %)')
        # FOTEN I NEDERKANT och hjässan i överkant: annars står modellen och svävar, eller så bar
        # rutan med sig mark över figuren.
        rader = np.nonzero((alfa > 0).any(axis=1))[0]
        krav(len(rader) > 0 and rader[0] <= 2 and rader[-1] >= alfa.shape[0] - 3,
             f'{p["id"]}: figuren fyller rutan på höjden (rad {int(rader[0]) if len(rader) else -1}'
             f'-{int(rader[-1]) if len(rader) else -1} av {alfa.shape[0]})')
        krav(PX_MIN <= p["px"][1] <= PX_MAX, f'{p["id"]}: figuren är {p["px"][1]} px hög (arkets mått)')
        krav(-17.0 < p["pos"][0] < 17.0, f'{p["id"]}: x {p["pos"][0]:.2f} inom byn')
        krav(0.3 <= p["höjd_m"] <= 2.0, f'{p["id"]}: höjd {p["höjd_m"]:.2f} m')
    # DETERMINISM: alla filer har ett avtryck, och en andra körning ska ge samma summa.
    summa = hashlib.md5("".join(avtryck(UT / f'{p["id"]}.png') for p in poster).encode()).hexdigest()[:12]
    print(f"  avtryck {summa}")
    print(f"=== {'KLART' if fel == 0 else f'{fel} FEL'} ({len(poster)} bybor) ===")
    return 1 if fel else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="mät i stället för att skriva")
    a = ap.parse_args()
    poster = bygg()
    for p in poster:
        print(f'{p["id"]:14s} x {p["pos"][0]:7.2f}  z {p["pos"][2]:5.2f}  {p["höjd_m"]:.2f} m  '
              f'{p["px"][0]:3d}x{p["px"][1]:3d} px  {p["källa"]}')
    if a.check:
        return checka(poster)
    return 0


if __name__ == "__main__":
    sys.exit(main())
