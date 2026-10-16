"""Hjältarna ur Alex' hjälteark — figuren som GÅR på kartan och i byn (M134).

    python3 tools/gen_hjalte.py            # skriv game/assets/ui/hjalte/*.png + hjalte.json
    python3 tools/gen_hjalte.py --check    # mät mot arket och mot filerna på disk, exit 1 vid fel

Alex 15/10: *"Skapade även en med hjältar som man kan använda att gå på kartan och i byn med."* —
`game/images/heroes.jpeg`, 2 rader x 5: AURIC PALADIN, SYLVAN RANGER, RUNIC GUARDIAN, ARCANE MAGE,
SHADOWBLADE ROGUE / CLERIC OF LIGHT, FURY BARBARIAN, AEON GUARDIAN, DRUIDIC SAGE, SOLAR SERAPH.
Namnen står under varje figur och FÖLJER MED i `hjalte.json` (Alex: "Ignorera allt om hp och attack
å sånt, men spara namnen"). Inga siffror finns i arket.

VARFÖR EN EGEN FIL: byborna (`tools/gen_by_bybor.py`) klipps mot VIT botten, och där räcker ett
avstånd till arkets hörnfärg. Hjältarket har en MÖRK botten med vinjett och glöd, och figurens egen
rustning ligger nära botten i ton — mätt 15/10: ett avståndskrav på 0,16 lämnade en rektangel av
botten kvar kring figuren och skar sönder rustningen i flytande bitar (största fältet blev 15-26 % av
figuren), medan en flodfyllning från rutans kant på 0,01 gav en hel figur (största fältet 82 % av
figuren) men bara tog 71 % av botten. Klippningen här är därför flodfyllning från kanten vid 0,015 och
den STÖRSTA figuren i rutan — mätt blir 75 % av botten borta och figuren hänger ihop. Ett ark på vit
botten (som byboarken) hade gett ett renare snitt; det är Alex' beslut, inte en siffra.
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
ARK = ROOT / "game" / "images" / "heroes.jpeg"
UT = ROOT / "game" / "assets" / "ui" / "hjalte"
DATA = ROOT / "game" / "assets" / "ui" / "hjalte.json"
KONTAKT = UT / "_kontaktkarta.png"

RADER, KOLONNER = 3, 4
## Hur nära hörnfärgen en pixel får ligga för att räknas som botten (JPEG-bruset i grått gör
## steg på upp till 4/255 = 0,016, så 0,015 blockerade fyllningen helt).
BAKGRUND_TOL = 0.05
## Fält mindre än så är etikettbokstäver och glödflagor, inte figuren.
FALT_MIN = 800
## Målhöjd i px: 48 px ritas i vyn i skalan 1,0 och blir då lika hög som den gamla 23x21-markören
## ritades (46 px mot husens ~250 vy-px) — en människa mot ett tvåvåningshus, inte en prick.
MÅL_PX = 48

## Namnen ur arket, i ordning (rad för rad). De står under varje figur i arket och sparas i json:en,
## så spelet kan visa hjältens namn utan att någon skriver av bilden för hand.
NAMN = [
    "VALERIUS", "ELARA", "GREGOR", "SYLVIA", "RAGNAR", "SERAPHINA",
    "KAEL", "ARTHUR", "LYRA", "BRUTUS", "ZOLTAR", "ISABEL",
]
## Filnamnen blir id:n i json:en (gemener, understreck).
ID = [n.lower().replace(" ", "_") for n in NAMN]


def ark() -> np.ndarray:
    if not ARK.exists():
        raise SystemExit(f"FEL: arket saknas: {ARK}")
    return np.asarray(Image.open(ARK).convert("RGB")).astype(np.float32) / 255.0


def bakgrund(patch: np.ndarray, tol: float) -> np.ndarray:
    """Bakgrunden: de pixlar inom `tol` från rutans HÖRNFÄRG som hänger ihop med rutans kant.
    Arkets botten är NUMERA en platt grå yta (Alex genererade om arket 15/10), så hörnregeln räcker —
    och den måste vara rymlig: arket är JPEG, och bruset i grått gör steg på upp till 4/255 = 0,016
    mellan två grannpixlar. Den gamla lokala kontinuitetsregeln vid 0,015 stannade därför vid första
    steget och fyllde NOLL pixlar (mätt: hela rutan lästes som figur). Kantregeln behålls ändå: en
    grå ficka inuti en figur (t.ex. en grå ärm) får inte bli genomskinlig."""
    h, b = patch.shape[:2]
    hörn = np.median(np.concatenate([patch[:4, :4].reshape(-1, 3), patch[:4, -4:].reshape(-1, 3)]), axis=0)
    nära = np.abs(patch - hörn).max(axis=2) <= tol
    m = np.zeros((h, b), dtype=bool)
    kö: deque[tuple[int, int]] = deque()

    def put(y: int, x: int) -> None:
        if nära[y, x] and not m[y, x]:
            m[y, x] = True
            kö.append((y, x))

    for x in range(b):
        put(0, x)
        put(h - 1, x)
    for y in range(h):
        put(y, 0)
        put(y, b - 1)
    while kö:
        y, x = kö.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < b and nära[ny, nx] and not m[ny, nx]:
                m[ny, nx] = True
                kö.append((ny, nx))
    return m


def största(mask: np.ndarray) -> tuple[int, int, int, int, int]:
    """Den största sammanhängande figuren i masken, som (px, x0, y0, x1, y1)."""
    h, b = mask.shape
    sedd = np.zeros((h, b), dtype=bool)
    bäst = (0, 0, 0, 0, 0)
    for y in range(h):
        for x in range(b):
            if mask[y, x] and not sedd[y, x]:
                kö = deque([(y, x)])
                sedd[y, x] = True
                xs_min, ys_min, xs_max, ys_max, n = x, y, x, y, 0
                while kö:
                    cy, cx = kö.popleft()
                    n += 1
                    xs_min, ys_min = min(xs_min, cx), min(ys_min, cy)
                    xs_max, ys_max = max(xs_max, cx), max(ys_max, cy)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < b and mask[ny, nx] and not sedd[ny, nx]:
                            sedd[ny, nx] = True
                            kö.append((ny, nx))
                if n > bäst[0]:
                    bäst = (n, xs_min, ys_min, xs_max, ys_max)
    return bäst


def radband(a: np.ndarray) -> list[tuple[int, int]]:
    """Radbanden MÄTS: arket är inte jämnt delat i höjdled (MÄTT 15/10: figurerna börjar på y 80, 720
    och 1 380 i ett ark som är 2 400 högt, med 500 px tom botten — en jämn delning på tre skar Brutus,
    Lyra, Zoltar och Isabel mitt i kroppen och gav fyra benpar). Ett band är sammanhängande rader med
    figur, och ett gap på minst 30 tomma rader skiljer två band."""
    grå = np.abs(a - np.median(np.concatenate([a[:4, :4].reshape(-1, 3), a[:4, -4:].reshape(-1, 3)]), axis=0)).max(axis=2) <= BAKGRUND_TOL
    rader = (~grå).mean(axis=1) > 0.01
    band: list[tuple[int, int]] = []
    y = 0
    while y < len(rader):
        if rader[y]:
            slut = y
            tom = 0
            while slut + 1 < len(rader) and tom < 30:
                slut += 1
                tom = tom + 1 if not rader[slut] else 0
            band.append((y, slut - tom + 1))
            y = slut
        else:
            y += 1
    return band


def ruta(a: np.ndarray, rad: int, kol: int) -> tuple[int, int, int, int]:
    """Figurens ruta i arket: kolumnen ur rutnätet, raden ur det MÄTTA radbandet, och den största
    sammanhängande figuren i den rutan blir hjälten (bokstäverna i namnraden är små och faller på
    `FALT_MIN` — därför behövs ingen egen etikettgräns)."""
    h, b = a.shape[:2]
    cw = b / KOLONNER
    x0, x1 = int(round(kol * cw)), int(round((kol + 1) * cw))
    y0, y1 = radband(a)[rad]
    patch = a[y0:y1, x0:x1]
    m = ~bakgrund(patch, BAKGRUND_TOL)
    n, xs0, ys0, xs1, ys1 = största(m)
    if n < FALT_MIN:
        raise SystemExit(f"FEL: ingen figur i {ARK.name} rad {rad} kol {kol} ({n} px)")
    return x0 + xs0, y0 + ys0, x0 + xs1 + 1, y0 + ys1 + 1


def klipp(rad: int, kol: int) -> dict:
    id = ID[rad * KOLONNER + kol]
    a = ark()
    rx0, ry0, rx1, ry1 = ruta(a, rad, kol)
    patch = a[ry0:ry1, rx0:rx1]
    alfa = np.where(~bakgrund(patch, BAKGRUND_TOL), 255, 0).astype(np.uint8)
    bild = Image.fromarray(np.dstack([(patch * 255).astype(np.uint8), alfa]), mode="RGBA")
    bild = skala(bild)
    bild.save(UT / f"{id}.png")
    return {
        "id": id,
        "namn": NAMN[rad * KOLONNER + kol],
        "bild": f"hjalte/{id}.png",
        "ark_ruta": [rx0, ry0, rx1, ry1],
        "px": [bild.size[0], bild.size[1]],
    }


def skala(bild: Image.Image) -> Image.Image:
    """Ned till `MÅL_PX` höjd. Färgen viktas med alfan INNAN den skalas ned (annars medelvärdesbildas
    kanten mot genomskinligt svart och figuren blir grå — samma fix som i `gen_by_bybor.py`), och alfan
    trösklas efteråt så konturen förblir hård."""
    if bild.size[1] <= MÅL_PX:
        return bild
    f = bild.size[1] / float(MÅL_PX)
    ny = (max(1, round(bild.size[0] / f)), MÅL_PX)
    a = np.asarray(bild).astype(np.float32)
    al = a[..., 3]
    vikt = al / 255.0
    förädlad = (a[..., :3] * vikt[..., None]).astype(np.uint8)
    rgb = np.asarray(Image.fromarray(förädlad, "RGB").resize(ny, Image.Resampling.BOX)).astype(np.float32)
    viktad = np.asarray(Image.fromarray(al.astype(np.uint8), "L").resize(ny, Image.Resampling.BOX)).astype(np.float32)
    rgb = np.clip(rgb * 255.0 / np.maximum(viktad, 1.0)[..., None], 0.0, 255.0).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, np.where(viktad > 128.0, 255, 0).astype(np.uint8)]), mode="RGBA")


def bygg() -> list[dict]:
    UT.mkdir(parents=True, exist_ok=True)
    poster = [klipp(rad, kol) for rad in range(RADER) for kol in range(KOLONNER)]
    DATA.write_text(json.dumps({"hjalte": poster}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    kontaktyta(poster)
    return poster


def kontaktyta(poster: list[dict]) -> None:
    bilder = [Image.open(UT / f'{p["id"]}.png') for p in poster]
    s = 2
    höjd = max(b.size[1] for b in bilder) * s + 24
    bredd = sum(b.size[0] * s + 12 for b in bilder) + 12
    duk = Image.new("RGB", (bredd, höjd), (26, 26, 30))
    for y in range(0, höjd, 8):
        for x in range(0, bredd, 8):
            if (x // 8 + y // 8) % 2:
                duk.paste((52, 52, 58), (x, y, min(x + 8, bredd), min(y + 8, höjd)))
    x = 12
    for b in bilder:
        b = b.resize((b.size[0] * s, b.size[1] * s), Image.Resampling.NEAREST)
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

    a = ark()
    print(f"{len(poster)} hjältar ur {ARK.name} {a.shape[1]}x{a.shape[0]}")
    for p in poster:
        fil = UT / f'{p["id"]}.png'
        if not fil.exists():
            krav(False, f'{p["id"]}: filen saknas')
            continue
        bild = Image.open(fil)
        arr = np.asarray(bild)
        alfa = arr[..., 3]
        x0, y0, x1, y1 = p["ark_ruta"]
        krav(bild.size == (p["px"][0], p["px"][1]), f'{p["id"]}: måttet {bild.size} är tabellens')
        krav(0 <= x0 < x1 <= a.shape[1] and 0 <= y0 < y1 <= a.shape[0],
             f'{p["id"]}: rutan ({x0},{y0})-({x1},{y1}) ligger i arket')
        kvar = float((alfa > 0).mean())
        krav(0.15 < kvar < 0.95, f'{p["id"]}: figuren fyller rutan, inte bottnen ({kvar * 100:.0f} %)')
        # FOTEN I NEDERKANT: figuren ska stå på sin egen underkant, annars svävar den i vyn.
        rader = np.nonzero((alfa > 0).any(axis=1))[0]
        krav(len(rader) > 0 and rader[-1] >= alfa.shape[0] - 4,
             f'{p["id"]}: figuren når sin nederkant (rad {int(rader[-1]) if len(rader) else -1} av {alfa.shape[0]})')
        krav(p["namn"].isupper() and len(p["namn"]) > 3, f'{p["id"]}: namnet är sparat ({p["namn"]})')
    summa = hashlib.md5("".join(avtryck(UT / f'{p["id"]}.png') for p in poster).encode()).hexdigest()[:12]
    print(f"  avtryck {summa}")
    print(f"=== {'KLART' if fel == 0 else f'{fel} FEL'} ({len(poster)} hjältar) ===")
    return 1 if fel else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="mät i stället för att skriva")
    a = ap.parse_args()
    poster = bygg()
    for p in poster:
        print(f'{p["id"]:18s} {p["px"][0]:3d}x{p["px"][1]:3d} px  {p["namn"]}')
    if a.check:
        return checka(poster)
    return 0


if __name__ == "__main__":
    sys.exit(main())
