"""Byns byggnader som EGNA objekt (M123): husen klipps ur game/assets/ui/byn.png.

    python3 tools/gen_by_hus.py            # skriv game/assets/ui/byn/hus_*.png + bak.png
    python3 tools/gen_by_hus.py --check    # mät mot källan och mot filerna på disk, exit 1 vid fel

Alex, om den förra byn: *"Husen skulle lyftas ut och läggas som objekt i en 2.5D-vy, gatan framför
skulle vara 'marken de stod på'. Det här såg förjävligt ut."* Den här generatorn är det första ledet:
varje byggnad blir en EGEN textur, klippt ur samma bild som gatan och himlen kommer ifrån.

RÄTTERNA MÄTS INTE FRAM HÄR. De läses ur `game/ui/village_view.gd` (`PLATSER`:s `x0`/`x1`, `HUS_TOPP`
och `BILDENS_GATA`), alltså samma tal som den platta vyn och 3D-scenen använde. En egen kopia av
siffrorna här hade kunnat glida ifrån vyn utan att någon såg det; `--check` faller i stället, och
prov nr 1 i `game/tests/test_by_utklippt.gd` mäter samma sak i körtid.

HIMLEN LÄSES UR BILDENS ÖVERKANT (flodfyllning, samma väg som `game/core/voxel.gd` läser en bakgrund
ur en kant): allt som hänger ihop med överkanten och ligger inom toleransen av himlens färg blir
GENOMSKINLIGT i husets textur. Utan det släpar varje hus med sig en bit himmel, och när huset glider i
paralaxen glider himlen med — det syns som en rak skarv ovanför taket.

HÅLET BAKOM HUSEN. Tar man bort huset ur bakgrunden uppstår ett hål där det stod. Hålet fylls per rad
med en linjär toning mellan pixeln strax till VÄNSTER om rutan och pixeln strax till HÖGER om den —
alltså med vad som faktiskt står bredvid huset på den raden (himmel högt upp, gata eller granne
nedtill). Vid kameran i vila syns inte en enda hålad pixel (huset ligger exakt över sitt eget hål), så
nolläget är byte-identiskt med källan; hålet syns bara som en remsa när huset glider ifrån bakgrunden.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
KÄLLA = ROOT / "game" / "assets" / "ui" / "byn.png"
VYN = ROOT / "game" / "ui" / "village_view.gd"
UT = ROOT / "game" / "assets" / "ui" / "byn"

## Himlens färg läses ur bildens första pixel — inte gissad — och toleransen är satt så att himlens
## egen toning (mätt: 106-108, 169-171, 209-212 över 2000 px i överkanten) ryms medan takens
## antialiaserade kant stannar utanför. Provet nedan mäter hur stor andel av varje ruta som blev
## genomskinlig; en läckande fyllning syns där som en orimlig siffra.
FÄRG_TOL = 16

## Rimlig andel himmel i en husruta: taket börjar på HUS_TOPP, så bara hörnen ovanför takfallet är
## himmel. Mätt 3-9 % per hus. Ett läckage genom ett ljust fönster hade gett tiotals procent.
HIMMEL_MIN, HIMMEL_MAX = 0.005, 0.20

## Fingeravtrycket bevisar att två körningar ger samma bytes (se `--check`).
FRÖ = "b7e2a0f1c9d4e3a8"


def rätter() -> list[tuple[str, tuple[int, int, int, int]]]:
    """Husrutorna i KONSTENS px, ur `PLATSER` i village_view.gd. Kastar hellre än gissar."""
    text = VYN.read_text(encoding="utf-8")
    m = re.search(r"const HUS_TOPP := ([\d.]+)", text)
    g = re.search(r"const BILDENS_GATA := ([\d.]+)", text)
    if not m or not g:
        raise SystemExit("FEL: hittar inte HUS_TOPP/BILDENS_GATA i %s" % VYN)
    topp, gata = float(m.group(1)), float(g.group(1))
    rader = re.findall(r'\{"id": "([^"]+)",[^\n]*?"x0": ([\d.]+), "x1": ([\d.]+)', text)
    if len(rader) < 4:
        raise SystemExit("FEL: hittar inte PLATSER:s rutor i %s (%d rader)" % (VYN, len(rader)))
    bild = Image.open(KÄLLA)
    w, h = bild.size
    # SAMMA formel som `VillageView._bygg_scen`, bara avrundad till hela konstpixlar: en halv pixel
    # här hade gjort att huset inte längre ligger på sitt eget hål.
    ut = []
    for id, x0p, x1p in rader:
        x0 = int(round(w * float(x0p) / 100.0))
        x1 = int(round(w * float(x1p) / 100.0))
        y0 = int(round(h * topp / 100.0))
        y1 = int(round(h * gata / 100.0))
        ut.append((id, (x0, y0, x1, y1)))
    return ut


def himmeln(src: np.ndarray) -> np.ndarray:
    """Himlen: per KOLUMN den sammanhängande himmellika remsan från bildens överkant och nedåt.

    Samma tanke som flodfyllningen i `game/core/voxel.gd` (en bakgrund läses ur en kant), men gjord
    kolumnvis: `logical_and.accumulate` slår av vid första pixeln i kolumnen som inte är himmel.
    Fördelen mot en flodfyllning är att den aldrig kan LÄCKA in genom ett ljust fönster: den fyller
    aldrig på andra sidan om en pixel som inte är himmel. Priset är att en himmelpixel som bara hänger
    ihop med överkanten via en omväg i sidled blir kvar — den är himmelfärgad och rör sig med huset,
    alltså osynlig.
    """
    färg = src[0, 0].astype(int)
    lika = (np.abs(src.astype(int) - färg) <= FÄRG_TOL).all(axis=2)
    return np.logical_and.accumulate(lika, axis=0)


def husmasker(src: np.ndarray, himmel: np.ndarray, rutor: list) -> list[np.ndarray]:
    """Ett hus = rutan minus himlen. Masken är GLOBAL (en enda himmelfyllning för hela bilden), så
    två hus som överlappar varandra kan inte säga olika saker om samma pixel."""
    return [~himmel[y0:y1, x0:x1] for (_id, (x0, y0, x1, y1)) in rutor]


def fyll_hål(src: np.ndarray, rutor: list, masker: list[np.ndarray]) -> np.ndarray:
    """Bakgrunden med husen borta. Per rad en toning mellan pixlarna strax utanför rutan."""
    bak = src.copy()
    for (_id, (x0, y0, x1, y1)), mask in zip(rutor, masker):
        h, w = mask.shape
        vänster = src[y0:y1, max(0, x0 - 1)].astype(np.float32)
        höger = src[y0:y1, min(src.shape[1] - 1, x1)].astype(np.float32)
        t = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :, None]
        fyll = np.rint(vänster[:, None, :] * (1.0 - t) + höger[:, None, :] * t)
        fyll = np.clip(fyll, 0, 255).astype(np.uint8)
        region = bak[y0:y1, x0:x1]
        region[mask] = fyll[mask]
    return bak


def bygg() -> tuple[dict[str, Image.Image], Image.Image]:
    rå = Image.open(KÄLLA).convert("RGB")
    src = np.asarray(rå, dtype=np.uint8)
    rutor = rätter()
    himmel = himmeln(src)
    masker = husmasker(src, himmel, rutor)
    hus: dict[str, Image.Image] = {}
    for (id, (x0, y0, x1, y1)), mask in zip(rutor, masker):
        region = src[y0:y1, x0:x1]
        rgba = np.dstack([region, (mask * 255).astype(np.uint8)])
        hus[id] = Image.fromarray(rgba, mode="RGBA")
    bak = Image.fromarray(fyll_hål(src, rutor, masker), mode="RGB")
    return hus, bak


def avtryck(im: Image.Image) -> str:
    return hashlib.sha256(im.tobytes()).hexdigest()[:16]


def checka(hus: dict[str, Image.Image], bak: Image.Image, rutor: list) -> int:
    """Mäter utdata mot källan. Returnerar antalet fel."""
    fel = 0

    def krav(ok: bool, text: str) -> None:
        nonlocal fel
        print(("  ok   " if ok else "  FEL  ") + text)
        fel += 0 if ok else 1

    rå = Image.open(KÄLLA).convert("RGB")
    src = np.asarray(rå, dtype=np.uint8)
    for (id, (x0, y0, x1, y1)) in rutor:
        im = hus[id]
        krav(im.size == (x1 - x0, y1 - y0),
             "%s: huset är %dx%d, precis sin ruta i bilden (%dx%d)"
             % (id, im.size[0], im.size[1], x1 - x0, y1 - y0))
        a = np.asarray(im)
        # RGB: NOLL ändrade pixlar mot källan. Huset är klippt, inte ritat.
        krav(np.array_equal(a[:, :, :3], src[y0:y1, x0:x1]),
             "%s: 0 ändrade RGB-pixlar mot bildens ruta" % id)
        andel = float((a[:, :, 3] == 0).mean())
        krav(HIMMEL_MIN < andel < HIMMEL_MAX,
             "%s: %.1f %% av rutan blev genomskinlig himmel (rimligt: %.0f-%.0f %%)"
             % (id, 100.0 * andel, 100.0 * HIMMEL_MIN, 100.0 * HIMMEL_MAX))
        krav(int(a[:, :, 3].min()) == 0 and int(a[:, :, 3].max()) == 255,
             "%s: både genomskinliga och ogenomskinliga pixlar (inte en tom eller hel fylld ruta)" % id)
    # BAKGRUNDEN: ändrad BARA där husen stod, alltså inuti rutornas husmasker.
    b = np.asarray(bak)
    hål = np.zeros(src.shape[:2], dtype=bool)
    himmel = himmeln(src)
    for (_id, (x0, y0, x1, y1)) in rutor:
        hål[y0:y1, x0:x1] |= ~himmel[y0:y1, x0:x1]
    ändrad = np.any(b != src, axis=2)
    krav(int((ändrad & ~hål).sum()) == 0,
         "bakgrunden: 0 ändrade pixlar UTANFÖR husens hål (%d utanför)"
         % int((ändrad & ~hål).sum()))
    krav(int((ändrad & hål).sum()) > 100000,
         "bakgrunden: hålen är ifyllda (%d pixlar)" % int((ändrad & hål).sum()))
    return fel


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if not KÄLLA.exists():
        print("FEL: källan saknas: %s" % KÄLLA.relative_to(ROOT))
        return 1
    rutor = rätter()
    hus, bak = bygg()
    fel = checka(hus, bak, rutor)
    # DETERMINISMEN: två körningar i rad ska ge samma bytes, annars kan filen inte --check:as.
    hus2, bak2 = bygg()
    samma = all(avtryck(hus[i]) == avtryck(hus2[i]) for i in hus) and avtryck(bak) == avtryck(bak2)
    krav_text = "samma bytes två körningar i rad (%d hus + bakgrunden)" % len(hus)
    print(("  ok   " if samma else "  FEL  ") + krav_text)
    fel += 0 if samma else 1
    if a.check:
        for id in hus:
            p = UT / ("hus_%s.png" % id)
            if not p.exists():
                print("  FEL  filen saknas på disk: %s" % p.relative_to(ROOT))
                fel += 1
                continue
            på_disk = Image.open(p).convert("RGBA")
            ok = avtryck(på_disk) == avtryck(hus[id])
            print(("  ok   " if ok else "  FEL  ") + "%s är samma bild som generatorn ger" % p.relative_to(ROOT))
            fel += 0 if ok else 1
        p = UT / "bak.png"
        if not p.exists():
            print("  FEL  filen saknas på disk: %s" % p.relative_to(ROOT))
            fel += 1
        else:
            ok = avtryck(Image.open(p).convert("RGB")) == avtryck(bak)
            print(("  ok   " if ok else "  FEL  ") + "%s är samma bild som generatorn ger" % p.relative_to(ROOT))
            fel += 0 if ok else 1
        return 1 if fel else 0
    UT.mkdir(parents=True, exist_ok=True)
    for id in hus:
        hus[id].save(UT / ("hus_%s.png" % id), optimize=True)
        print("skrev %s (%dx%d, avtryck %s)"
              % ((UT / ("hus_%s.png" % id)).relative_to(ROOT), hus[id].size[0], hus[id].size[1], avtryck(hus[id])))
    bak.save(UT / "bak.png", optimize=True)
    print("skrev %s (%dx%d, avtryck %s)"
          % ((UT / "bak.png").relative_to(ROOT), bak.size[0], bak.size[1], avtryck(bak)))
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main())
