#!/usr/bin/env python3
"""Ytorna ur Alex' ark: väggar, golv och tak klipps ur bilderna i game/images/.

Skäl: gen_tiles.py räknar fram sina rutor ur paletten, och de är släta och sömlösa men de är inte
HANS ytor. Alex lade arken i game/images/ och bad att de används. Regeln från fiende- och
kortikonsgeneratorerna gäller här också: bilden äger utseendet, koden äger bara informationen —
den här filen bestämmer VILKEN ruta i vilket ark som blir vilken yta, och ingenting annat.

MÄTT, inte tyckt: arkens rutor är AI-texturer och är INTE sömlösa (skarven mättes till 30-134
gråsteg mellan sista och första kolumnen, mot 8-10 inuti de räknade rutorna). En ruta upprepas per
block, så en sådan skarv blir ett rutnät över hela väggen. Därför vrids varje ruta ett halvt varv
(ImageChops.offset) — då fortsätter motivet över kanten och skarven försvinner — och den gamla
kanten, som hamnar mitt i rutan, suddas ut med en mjuk mask över ett band.

    python3 tools/gen_tiles_alex.py            # skriver game/assets/tiles/<tema>/*.png
    python3 tools/gen_tiles_alex.py --prov     # kontaktkarta av alla ytor, att döma på bild
    python3 tools/gen_tiles_alex.py --kolla    # mäter skarv och upprepning i det som skrevs

Rutnätet i arken är 4x2 (fyra kolumner, två rader) — mätt med båda layouterna sida vid sida, 4x2
träffade motiven och 2x4 skar sönder dem. Filnamnen som skrivs är desamma som gen_tiles.py skriver,
så spelet byter inte en rad: ytan, normalen (_n) och ORM-kartan (_orm) byts ut, plus
super-rutorna (4 block i fyra ordningar) som är spelets bot mot upprepning.

Themabytet är en rad per yta i KÄLLOR. Fler ytor finns i arken (marmor, mosaik, ben, lava, is) och
läggs till när en plats behöver dem — fem teman räcker tills en plats ser ut som en annan.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROT = Path(__file__).resolve().parent.parent
ARK = ROT / "game" / "images"
UT = ROT / "game" / "assets" / "tiles"

STL = 128          # rutans kant, samma som gen_tiles.py
SUPER = 256        # super-rutan = fyra block, samma som gen_tiles.py

# (fil, ruta) — rutan räknas 4 per rad, 0-3 övre raden, 4-7 undre. Numren kommer från
# kontaktkartan över arken, inte från en gissning: varje ruta i arken bär sin egen titel.
A8 = "Gemini_Generated_Image_4ct7fl4ct7fl4ct7.jpeg"    # murverk, sandsten, krypta, runor
A9 = "Gemini_Generated_Image_lm7x2nlm7x2nlm7x.jpeg"    # marmor, mosaik, rötter, basalt, is
A10 = "Gemini_Generated_Image_tu85smtu85smtu85.jpeg"   # runsten, svedd mark, avlopp, ben, koppar
A11 = "Gemini_Generated_Image_9a998f9a998f9a99.jpeg"   # fyra golv (mossa/löv) + fyra tak (balkar)
A12 = "Gemini_Generated_Image_q3n93eq3n93eq3n9.jpeg"   # plank och takbalkar, starka

KÄLLOR: dict[str, dict[str, tuple[str, int]]] = {
    # temat: yta -> (ark, ruta). Vägg, golv och tak är spelets tre ytor; moss och spricka är
    # ALT-rutorna som spelet lägger där våningen har något att säga (boss, trappa).
    "krypta": {
        "wall": (A8, 5),          # Slimy Crypt Wall
        "wall_moss": (A8, 6),     # Runic Carved Stone
        "floor": (A10, 4),        # Bone Mosaic Floor
        "floor_crack": (A9, 1),   # Crimson Mosaic
        "ceiling": (A11, 5),      # Dungeon Ceiling, balk
    },
    "grotta": {
        "wall": (A8, 0),          # Dark Stone Bricks
        "wall_moss": (A8, 2),     # grottvägg, grövre berg
        "floor": (A11, 1),        # Dungeon Floor
        "floor_crack": (A9, 3),   # Volcanic Basalt, lava i sprickorna
        "ceiling": (A12, 7),      # takbalkar, mörka
    },
    "asklunden": {
        "wall": (A9, 2),          # Gnarled Root Wall
        "wall_moss": (A8, 3),     # Chipped Stone and Mortar
        "floor": (A11, 0),        # Dungeon Floor, mossa
        "floor_crack": (A10, 1),  # Scorched Earth
        "ceiling": (A11, 4),      # Dungeon Ceiling
    },
    "tunnel": {
        "wall": (A10, 2),         # Sewer Pipe Wall
        "wall_moss": (A10, 7),    # Verdigris Copper Plate
        "floor": (A10, 0),        # Runestone Floor
        "floor_crack": (A11, 2),  # Dungeon Floor, andra varianten
        "ceiling": (A11, 6),      # Dungeon Ceiling
    },
    "bro": {
        "wall": (A10, 7),         # Verdigris Copper Plate
        "wall_moss": (A8, 1),     # Sandstone
        "floor": (A9, 0),         # Polished Marble Floor
        "floor_crack": (A9, 7),   # Obsidian Pavement
        "ceiling": (A11, 7),      # Dungeon Ceiling
    },
}

# Rutorna i samma ark har olika upplösning (2816x1536 eller 2912x1440), så rutan räknas ur arkets
# storlek i stället för ur ett fast tal.
KOLUMNER, RADER = 4, 2

# Varje ytas varianter: samma sömlösa ruta vriden olika mycket. Vridningar bevarar sömlösheten
# (kanten fortsätter fortfarande över rutan) och ger olika bilder, som spelets upprepningsgrind vill.
VRIDNINGAR = [(0, 0), (29, 71), (64, 0), (71, 29), (13, 47)]


def klipp(ark: str, ruta: int) -> Image.Image:
    """Rutan ur arket, som kvadrat ur panelens texturfält.

    MÄTT på arket: varje panel har sin titel i en egen mörk remsa i panelens UNDERKANT och en tunn
    delningslinje runt om. Första försöket tog en kvadrat ur cellens mitt och fick med både titel och
    ram — på en upprepad vägg hade titelremsan blivit ett band över hela ytan. Därför: panelens övre
    81 % (under det ligger titelremsan), 1 % bort från sidokanterna, och den största kvadraten ur
    det som blir kvar.
    """
    im = Image.open(ARK / ark).convert("RGB")
    w, h = im.size
    cw, ch = w // KOLUMNER, h // RADER
    i, j = ruta % KOLUMNER, ruta // KOLUMNER
    bx, by = int(cw * 0.01), int(ch * 0.01)
    fält = im.crop((i * cw + bx, j * ch + by, (i + 1) * cw - bx, j * ch + int(ch * 0.81)))
    sida = min(fält.size)
    mitten = ((fält.width - sida) // 2, (fält.height - sida) // 2)
    return fält.crop((mitten[0], mitten[1], mitten[0] + sida, mitten[1] + sida))


def sömlös(im: Image.Image, band: int = 20) -> Image.Image:
    """Vrider rutan ett halvt varv och smälter över den gamla kanten.

    Efter vridningen är det som förut var rutan kant i mitten, och det som var mitten ligger vid
    kanten — så motivet fortsätter över rutan kant. Det är själva sömlösheten. Kvar ligger den gamla
    kanten som ett streck i mitten; det suddas ut med en mask som är stark längs mitten och noll
    utanför bandet, så resten av rutan är orörd.
    """
    w, h = im.size
    vriden = ImageChops.offset(im, w // 2, h // 2)
    mjuk = vriden.filter(ImageFilter.GaussianBlur(band * 0.5))
    ys, xs = np.mgrid[0:h, 0:w]

    def vikt(c: np.ndarray, n: int) -> np.ndarray:
        a = np.minimum(np.abs(c - n // 2), n - np.abs(c - n // 2)).astype(float)
        return np.clip(1.0 - a / float(band), 0.0, 1.0)

    m = np.maximum(vikt(xs, w), vikt(ys, h))
    mask = Image.fromarray((m * 255.0).astype(np.uint8))
    return Image.composite(mjuk, vriden, mask)


def normal(im: Image.Image, styrka: float = 2.4) -> Image.Image:
    """Normalen räknas ur ljusheten: höjd där det är ljust. Samma väg som gen_tiles.py."""
    g = np.asarray(im.convert("L"), dtype=float) / 255.0
    gy, gx = np.gradient(g)
    nz = np.ones_like(g)
    nx, ny = -gx * styrka * 255.0, gy * styrka * 255.0
    v = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([(nx / v * 0.5 + 0.5), (ny / v * 0.5 + 0.5), (nz / v * 0.5 + 0.5)], axis=-1)
    return Image.fromarray((rgb * 255.0).clip(0, 255).astype(np.uint8))


def vattenmönster(h: int, w: int, yta: str, frö: int) -> np.ndarray:
    """Var ytan är BLÖT, 0 (torr) till 1 (blöt). Råheten i ORM:ns G-kanal följer den.

    Alex: *"så väggar kan se fuktiga ut, så det blänker gentemot ljus osv"*. Ett blankt lager över hela
    rutan hade bara sett ut som plast, så mönstret följer hur vatten faktiskt beter sig på ytan:

      * VÄGG: rinningar. Vattnet rinner NEDÅT, så mönstret varierar i sidled och är nästan likadant
        uppifrån och ned — smala vertikala band, tätare nedtill där vattnet samlas.
      * GOLV: pölar. Fläckar i två riktningar, större än de är höga (vatten lägger sig plant).
      * TAK: fukt. Mjuka, stora fläckar — taket droppar men står inte under vatten.

    Mönstret ritas ur ett eget frö per tema och ruta, så samma ruta får samma fukt varje gång filen
    byggs (annars ändras bilden varje körning och ingenting går att jämföra).
    """
    rng = np.random.default_rng(frö)
    if yta == "wall":
        # Ett smalt rutnät i sidled (8 punkter) och ett i höjdled (3): banden blir vertikala.
        litet = rng.random((3, 8))
        blöt = np.asarray(Image.fromarray((litet * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC),
            dtype=float) / 255.0
        # Nedtill samlas vattnet: en svag ökning från topp till botten.
        blöt = blöt * (0.75 + 0.5 * np.linspace(0.0, 1.0, h)[:, None])
    elif yta == "ceiling":
        litet = rng.random((3, 3))
        blöt = np.asarray(Image.fromarray((litet * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC),
            dtype=float) / 255.0
    else:                                    # golv och allt annat: pölar
        litet = rng.random((4, 4))
        blöt = np.asarray(Image.fromarray((litet * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC),
            dtype=float) / 255.0
    # Tröskeln gör skillnaden mellan torrt och blött: utan den blir hela rutan halvblöt och ingen
    # högdager syns någonstans (mätt: 0,55 i råhet överallt gav samma bild som förut).
    #
    # Tröskeln är PER YTA och MÄTT: taket hamnade på 0 % blött och golvet på 0-8 % med samma tröskel
    # som väggen, och en fuktfläck man inte kan se är ingen fukt. Taket är fuktigast (det droppar),
    # golvet har pölar, väggen har rinningar — siffrorna nedan ger 5-25 % blött på varje yta.
    tröskel = {"wall": 0.50, "ceiling": 0.30, "floor": 0.46}.get(yta, 0.46)
    return np.clip((blöt - tröskel) / (1.0 - tröskel), 0.0, 1.0)


def orm(im: Image.Image, yta: str = "floor", frö: int = 1) -> Image.Image:
    """ORM-kanalen: R = skugga (ur ljusheten), G = råhet, B = metall.

    G-kanalen bär FUKTEN (M59): torr sten står på 0,85 och blöt yta faller till 0,20, där ljuset från
    lyktan och facklan får en högdager. Utan våt mönstret vore hela ytan matt och väggen såg ut som
    wellpapp — det var precis vad Alex såg.
    """
    g = np.asarray(im.convert("L"), dtype=float) / 255.0
    r = (0.45 + 0.55 * (1.0 - g)) * 255.0
    blöt = vattenmönster(g.shape[0], g.shape[1], yta, frö)
    gr = (0.85 - 0.65 * blöt) * 255.0
    b = np.zeros_like(g)
    return Image.fromarray(np.stack([r, gr, b], axis=-1).clip(0, 255).astype(np.uint8))


def vrid(im: Image.Image, dx: int, dy: int) -> Image.Image:
    return ImageChops.offset(im, dx, dy)


def skarv(im: Image.Image) -> tuple[float, float]:
    """(skarv, värsta kant inuti) i gråsteg — samma mått som gen_tiles.py:s grind använder."""
    a = np.asarray(im.convert("L"), dtype=float)
    kant_x = np.abs(a[:, -1] - a[:, 0]).mean()
    kant_y = np.abs(a[-1, :] - a[0, :]).mean()
    yttre = max(kant_x, kant_y)
    # VÄRSTA kanten inuti rutan, inte medelkanten: en sömlös ruta kan ha ett hårt streck var som
    # helst inuti sig, och skarven ska bara fällas om den är hårdare än rutans egen hårdaste kant
    # (gen_tiles.py jämför på samma sätt).
    inre = max(float(np.abs(np.diff(a, axis=1)).mean(axis=0).max()),
        float(np.abs(np.diff(a, axis=0)).mean(axis=1).max()))
    return float(yttre), float(inre)


def skriv_tema(tema: str, val: dict[str, tuple[str, int]]) -> list[tuple[str, Image.Image]]:
    """Skriver ett temas ytor och lämnar tillbaka dem för provkartan."""
    mapp = UT / tema
    mapp.mkdir(parents=True, exist_ok=True)
    ut: list[tuple[str, Image.Image]] = []
    for yta, (ark, ruta) in val.items():
        grund = sömlös(klipp(ark, ruta)).resize((STL, STL), Image.LANCZOS)
        varianter = [vrid(grund, dx, dy) for dx, dy in VRIDNINGAR]
        for n, bild in enumerate(varianter):
            namn = yta if n == 0 else f"{yta}_{n + 1}"
            bild.save(mapp / f"{namn}.png")
            normal(bild).save(mapp / f"{namn}_n.png")
            # Fröet per tema OCH ruta: två grannrutor i samma ark ska inte få samma pölmönster.
            orm(bild, yta, frö=abs(hash((tema, ruta, namn))) % (2 ** 31)).save(mapp / f"{namn}_orm.png")
            if n == 0:
                ut.append((f"{tema}/{yta}", bild))
        if yta in ("floor", "wall"):
            for ordning in range(4):
                kant = Image.new("RGB", (SUPER, SUPER))
                for b in range(4):
                    i, j = b % 2, b // 2
                    # fyra ordningar: varje ordning lägger varianterna i en egen följd, så två
                    # super-rutor aldrig blir samma bild (det felet har gen_tiles.py råkat ut för).
                    v = varianter[(ordning + b) % len(VRIDNINGAR)]
                    kant.paste(v.resize((STL, STL)), (i * STL, j * STL))
                kant.save(mapp / f"{yta}_super_{ordning}.png")
                normal(kant).save(mapp / f"{yta}_super_{ordning}_n.png")
                orm(kant, yta, frö=abs(hash((tema, yta, ordning))) % (2 ** 31)).save(
                    mapp / f"{yta}_super_{ordning}_orm.png")
    (mapp / "BILDKALLA.txt").write_text(
        "Rutorna i den har mappen ar klippta ur Alex' ark i game/images/ av "
        "tools/gen_tiles_alex.py, inte raknade ur paletten. Kop: python3 tools/gen_tiles_alex.py\n",
        encoding="utf-8")
    return ut


def kolla(teman: list[str]) -> int:
    """Mäter det som spelar roll: skarven (blir ett rutnät annars) och att varianterna skiljer sig."""
    fel = 0
    for tema in teman:
        mapp = UT / tema
        for yta in ("floor", "wall", "ceiling"):
            filer = [mapp / f"{yta}.png"] + [mapp / f"{yta}_{n}.png" for n in range(2, 6)]
            filer = [f for f in filer if f.exists()]
            hash: set[str] = set()
            for f in filer:
                im = Image.open(f)
                s, inre = skarv(im)
                hash.add(hashlib.sha256(f.read_bytes()).hexdigest())
                if s > max(12.0, inre * 2.5):
                    print(f"  FEL {tema}/{f.name}: skarv {s:.1f} mot värsta inre kant {inre:.1f}")
                    fel += 1
            if len(hash) != len(filer):
                print(f"  FEL {tema}/{yta}: {len(filer)} varianter men bara {len(hash)} olika bilder")
                fel += 1
    print(f"  {len(teman)} teman kontrollerade, {fel} fel")
    return fel


def provkarta(ut: list[tuple[str, Image.Image]]) -> None:
    TW = 150
    kol = 6
    rader = (len(ut) + kol - 1) // kol
    ark = Image.new("RGB", (TW * kol, (TW + 20) * rader), (18, 18, 22))
    d = ImageDraw.Draw(ark)
    for n, (namn, bild) in enumerate(ut):
        x, y = (n % kol) * TW, (n // kol) * (TW + 20)
        ark.paste(bild.resize((TW - 6, TW - 6), Image.NEAREST), (x + 3, y + 18))
        d.text((x + 3, y + 3), namn, fill=(255, 255, 180))
    ark.save("/tmp/hc_ytor_nya.png")
    print("  provkarta /tmp/hc_ytor_nya.png", ark.size)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--prov", action="store_true")
    p.add_argument("--kolla", action="store_true")
    a = p.parse_args()
    teman = sys.argv[1:] if not a.prov and not a.kolla else []
    teman = [t for t in teman if t in KÄLLOR] or list(KÄLLOR)
    if a.kolla:
        return 1 if kolla(teman) else 0
    ut: list[tuple[str, Image.Image]] = []
    for tema in teman:
        ut += skriv_tema(tema, KÄLLOR[tema])
        print(f"  {tema}: {len(KÄLLOR[tema])} ytor skrivna")
    if a.prov:
        provkarta(ut)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
