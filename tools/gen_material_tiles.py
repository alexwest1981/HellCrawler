#!/usr/bin/env python3
"""Materialrutor ur Alex' materialark: han ritade ytorna, koden klipper dem till spelets rutor.

Alex: *"editorn behöver ha så man kan välja texturer för väggar, tak, golv osv, även om man vill
klistra in rekvisita"* och *"byta textur om något skulle se galet ut"*.

Arken är band: fyra rader, varje rad ett materialprov med sin rubrik under. Den vänstra panelen är
dubbelt så bred och bär ibland TVÅ material sida vid sida (mätt på arket: raderna 3 och 4). Ramen och
rubrikremsan klipps bort — kvar blir bara själva ytan, skalad till spelets rutstorlek.

    python3 tools/gen_material_tiles.py                  # skriver game/assets/tiles/material/<id>.png
    python3 tools/gen_material_tiles.py --check          # mäter: rätt mått, tät nog, inte bara ram
    godot --headless --path game --import                # en ny PNG syns inte förrän den importerats
"""

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
UT = ROOT / "game" / "assets" / "tiles" / "material"
ARK_DIR = ROOT / "game" / "images"

# Rutstorleken läses ur en befintlig ruta i spelet i stället för att gissas: materialrutorna ska vara
# samma mått som tematrutorna, annars ser en övermålad ruta annorlunda ut än sina grannar.
MALL = ROOT / "game" / "assets" / "tiles" / "krypta" / "floor.png"

KANT = 8                       # px innanför panelens ram: ramen är inte en del av materialet

# (ark, [(y0, y1, [(x0, x1, id), ...]), ...]) — mätta på arket, rad för rad, rubrikerna lästa med OCR.
ARK = [
    ("Gemini_Generated_Image_rl0t2trl0t2trl0t.jpeg", [
        (20, 320, [(16, 1380, "bio_lume_matrix"), (1380, 1810, "wall_with_ivy"),
                   (1810, 2260, "ancient_stone"), (2260, 2744, "chiseled_marble", 30)]),
        (385, 690, [(16, 1380, "scarred_ogre_hide"), (1380, 2170, "wooden_palisades"),
                    (2170, 2744, "corroded_metal")]),
        # Den breda vänsterpanelen är ETT material, inte två: att dela den på mitten gav samma yta
        # två gånger (mätt i granskningen — serpentin och pansarplåt var samma bild som sin granne).
        (755, 1060, [(16, 1380, "sunstone_crystals"),
                     (1380, 2170, "polished_obsidian_wall"), (2170, 2744, "woven_bamboo")]),
        (1125, 1430, [(16, 1380, "hammered_alloy"),
                      (1380, 2170, "fortified_stone_bricks"), (2170, 2744, "magma_rock")]),
    ]),
]

NAMN = {
    "bio_lume_matrix": "Bio-Lume Matrix", "ancient_stone": "Ancient Stone",
    "wall_with_ivy": "Wall with Ivy", "chiseled_marble": "Chiseled Marble",
    "scarred_ogre_hide": "Scarred Ogre Hide", "wooden_palisades": "Wooden Palisades",
    "corroded_metal": "Corroded Metal", "sunstone_crystals": "Sunstone Crystals",
    "polished_obsidian_wall": "Polished Obsidian Wall",
    "woven_bamboo": "Woven Bamboo", "hammered_alloy": "Hammered Alloy",
    "fortified_stone_bricks": "Fortified Stone Bricks",
    "magma_rock": "Magma Rock",
}


def ruta_storlek() -> tuple:
    return Image.open(MALL).size


def klipp(im: Image.Image, rad: tuple) -> list:
    """Materialproven i en rad, skalade till spelets rutstorlek."""
    y0, y1, paneler = rad
    sida = ruta_storlek()
    ut = []
    for panel in paneler:
        x0, x1, kid = panel[0], panel[1], panel[2]
        # Marmorn bär en gyllene ram som hör till arket, inte till stenen: den panelen klipps djupare.
        kant = panel[3] if len(panel) > 3 else KANT
        bit = im.crop((x0 + kant, y0 + kant, x1 - kant, y1 - kant)).convert("RGB")
        # Kvadrat först (annars blir en bred panel utdragen när den skalas), sedan rutans mått.
        s = min(bit.width, bit.height)
        bit = bit.crop(((bit.width - s) // 2, (bit.height - s) // 2,
                        (bit.width - s) // 2 + s, (bit.height - s) // 2 + s))
        ut.append((kid, bit.resize(sida, Image.BOX)))
    return ut


def kör(skriv: bool) -> int:
    if not MALL.exists():
        print("mallen saknas: %s" % MALL.relative_to(ROOT), file=sys.stderr)
        return 1
    if skriv:
        UT.mkdir(parents=True, exist_ok=True)
    antal, fel = 0, 0
    lista = {}
    for filnamn, rader in ARK:
        ark = ARK_DIR / filnamn
        if not ark.exists():
            print("arket saknas: %s" % filnamn, file=sys.stderr)
            return 1
        im = Image.open(ark)
        for rad in rader:
            for kid, bit in klipp(im, rad):
                antal += 1
                lista[kid] = {"namn": NAMN.get(kid, kid), "ark": filnamn}
                if not skriv:
                    # Kontrollen: rätt mått och att ytan faktiskt har innehåll (en tom eller enfärgad
                    # ruta är ett felklipp, inte ett material).
                    från = Image.open(UT / ("%s.png" % kid))
                    olika = len({p[0] for p in från.convert("RGB").getdata()})
                    ok = från.size == ruta_storlek() and olika > 8
                    print("  %s %s (%dx%d, %d färger)" % ("ok  " if ok else "FEL ",
                          kid, från.width, från.height, olika))
                    if not ok:
                        fel += 1
                    continue
                bit.save(UT / ("%s.png" % kid))
                print("  %-24s <- %s (%dx%d px)" % (kid, filnamn[24:30], bit.width, bit.height))
    if skriv:
        (UT / "_material.json").write_text(json.dumps(lista, ensure_ascii=False, indent=1) + "\n")
        print("skrev %d materialrutor i %s" % (antal, UT.relative_to(ROOT)))
        return 0
    print("=== %d materialrutor, %d fel ===" % (antal, fel))
    return 1 if fel else 0


if __name__ == "__main__":
    raise SystemExit(kör("--check" not in sys.argv))
