#!/usr/bin/env python3
"""Hjältarna ur Alex' ark -> 64x64-ikoner på spelets palett.

    python3 tools/gen_hero_icons.py            # skriv game/assets/heroes/<id>.png
    python3 tools/gen_hero_icons.py --prova    # bara mäta och skriva en kontaktkarta
    python3 tools/gen_hero_icons.py --check    # mäta de skrivna ikonerna

Källan är `game/images/heroes.jpeg` — "CHAMPION'S ROSTER: NOBLE ALLIES", tio hjältar i 2x5 rutor med
titelband överst och namn under varje figur, exakt samma arkform som monsterarken (tools/gen_enemy_new.py).
Urtaget, nedskalningen och palettläggningen ÅTERANVÄNDS därifrån och från gen_card_icons.py — bara
tabellen över vilken ruta som blir vem är ny.

Korten för de sex kamrater man kan hyra (ashhound, wicksister, bellringer, tarboy, bonecarver,
cindernun) har REDAN bilder från Alex' förra ark. De tio här är en annan uppsättning (en paladin, en
ranger, en magiker ...) och har därför fått en egen mapp med sina egna id:n i stället för att skriva
över någon annans kort. Ska de bli tavernans hjältar pekar koden på `res://assets/heroes/<id>.png`.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_card_icons as K  # noqa: E402
import gen_enemy_new as N  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ARK = ROOT / "game" / "images" / "heroes.jpeg"
OUT = ROOT / "game" / "assets" / "heroes"

# Namnbandet ligger LÄGRE i hjältearket än i monsterarken: mätt är tomrummet mellan figur och namn
# vid 0,69-0,79 av cellen (median 0,73) mot 0,62 i monsterarken. Med monsterarkets mått kapades
# paladinens svärd rakt av (granskat: "svärdets spets skärs av tvärt vid randen").
HJÄLTEBAND = 0.73

# Ruta i arket (1 = överst till vänster) -> id. Namnen är lästa ur arket.
KARTA = {
    1: "auric_paladin",
    2: "sylvan_ranger",
    3: "runic_guardian",
    4: "arcane_mage",
    5: "shadowblade_rogue",
    6: "cleric_of_light",
    7: "fury_barbarian",
    8: "aeon_guardian",
    9: "druidic_sage",
    10: "solar_seraph",
}


def palett() -> Image.Image:
    p = Image.new("P", (1, 1))
    platt = [v for c in [tuple(x) for x in json.loads(K.PALETT.read_text())] for v in c]
    p.putpalette(platt + [0] * (768 - len(platt)))
    return p


def ikon_av(figur: Image.Image, pal: Image.Image) -> Image.Image:
    """Figuren (RGBA med egen alfa) till 64x64 på paletten.

    INTE gen_card_icons.ikon(): den räknar fram alfan ur LJUSSTYRKA (allt över 16 är figur), vilket
    fungerar på flaskarket med svart botten. Hjältearket har mörkgrå botten kring 40, så allt blev
    "figur" och ikonerna kom ut som solida grå rutor — granskat: "bakgrunden är solid ... inte
    transparent". Här följer alfan med från urtaget i stället.
    """
    mål = K.SIDA - 2 * K.MARGINAL
    f = figur.copy()
    f.thumbnail((mål, mål), Image.BOX)
    duk = Image.new("RGBA", (K.SIDA, K.SIDA), (0, 0, 0, 0))
    duk.alpha_composite(f, ((K.SIDA - f.width) // 2, (K.SIDA - f.height) // 2))
    rgb = duk.convert("RGB").quantize(palette=pal, dither=Image.NONE).convert("RGBA")
    rgb.putalpha(duk.getchannel("A"))
    return rgb


def skriv(prova: bool) -> int:
    ark = np.asarray(Image.open(ARK).convert("RGB"))
    h, w = ark.shape[:2]
    cell_h = (h - N.TITEL_H) // N.RADER
    cell_w = w // N.KOLUMNER
    pal = palett()
    OUT.mkdir(parents=True, exist_ok=True)
    rader = []
    for nr in sorted(KARTA):
        rad, kol = divmod(nr - 1, N.KOLUMNER)
        cell = ark[N.TITEL_H + rad * cell_h: N.TITEL_H + (rad + 1) * cell_h, kol * cell_w:(kol + 1) * cell_w]
        figur = N.plocka(cell, HJÄLTEBAND)
        if figur is None:
            print("  ruta %d: ingen figur" % nr, file=sys.stderr)
            continue
        ikon = ikon_av(Image.fromarray(figur, "RGBA"), pal)
        if not prova:
            ikon.save(OUT / ("%s.png" % KARTA[nr]))
        rader.append((KARTA[nr], figur.shape[1], figur.shape[0]))
    for namn, bw, bh in rader:
        print("  %-20s figur %dx%d px ur arket" % (namn, bw, bh))
    return len(rader)


def checka() -> int:
    fel = []
    for fil in sorted(OUT.glob("*.png")):
        im = Image.open(fil).convert("RGBA")
        if im.size != (K.SIDA, K.SIDA):
            fel.append("%s: %s" % (fil.name, im.size))
            continue
        a = np.asarray(im)
        for c in np.unique(a[a[:, :, 3] > 0][:, :3].reshape(-1, 3), axis=0):
            if tuple(int(v) for v in c) not in {tuple(x) for x in json.loads(K.PALETT.read_text())}:
                fel.append("%s: färg utanför paletten %s" % (fil.name, tuple(c)))
                break
    print("%d hjältar, %d fel" % (len(list(OUT.glob("*.png"))), len(fel)))
    for f in fel:
        print("  " + f, file=sys.stderr)
    return 1 if fel else 0


# ÖVRIGA MONSTERARK (bestiariets sidor): klipps till samma ikonformat och hamnar i
# game/assets/bestiary/<ark>_<ruta>.png. Ingen fiende pekar på dem än — spelets 17 fiender har alla
# bilder, och dessa är en LIBRARY att välja ur; rutan i arket är id:t tills vidare.
#
# LÄGET: körningen hittade 30 figurer (10 per ark), men en granskning av pg1 visade att rutnätet inte
# är 2x5 med samma namnband som de andra arken: texten ligger kvar under flera figurer och några är
# kapade. Arken har alltså olika layout, och den måste MÄTAS per ark (titelband, radhöjd, namnband)
# innan de klipps — precis som 0,62 mättes fram för monsterarket och 0,73 för hjältearket. Ingen mapp
# skrivs därför ut förrän måtten finns; figurerna ligger kvar i game/images.
BIBLIOTEK = {
    "pg1": "Gemini_Generated_Image_bnl3m9bnl3m9bnl3.jpeg",
    "pg2": "Gemini_Generated_Image_npicy9npicy9npic.jpeg",
    "pg3": "Gemini_Generated_Image_94096b94096b9409.jpeg",
}
UT_BIBLIOTEK = ROOT / "game" / "assets" / "bestiary"


def grupper(rader: list, glapp: int = 2) -> list:
    """Sammanhängande rader/kolumner till band, med små avbrott (2 px) tillåtna."""
    g = []
    for i in rader:
        if g and i - g[-1][-1] <= glapp:
            g[-1].append(i)
        else:
            g.append([i])
    return [(x[0], x[-1]) for x in g]


def dela_rad(kol: np.ndarray, bredd: int) -> list:
    """Dela en figurrad i enskilda figurer. Gränsen mellan två figurer är en DAL i kolumn-täckningen —
    under en fjärdedel av radens median — som håller i minst 30 px. Ett fast glapp mellan grupper
    fungerade inte: mätta glapp i samma rad var 2, 43, 59 och 152 px, så tröskeln måste komma från
    radens egen täckning. Dalen är självjusterande och bryr sig inte om figurernas inbördes avstånd."""
    positiv = kol[kol > 0]
    if not len(positiv):
        return []
    dal = kol < max(3.0, 0.25 * float(np.median(positiv)))
    ut = []
    x = 0
    while x < bredd:
        if dal[x]:
            x += 1
            continue
        start = x
        tyst = 0
        while x < bredd:
            if dal[x]:
                tyst += 1
                if tyst >= 30:
                    break
            else:
                tyst = 0
            x += 1
        ut.append((start, max(start, x - tyst)))
    return ut


def figurer_i_ark(ark: np.ndarray) -> list:
    """Figurerna i ett ark UTAN rutnät: varje figur ligger i ett eget innehållsband med namnet i bandet
    under. Band som är kortare än 12 % av höjden är titel eller namn och hoppas över. Rutnätet antas
    alltså inte alls — pg1/pg2/pg3 har olika många rader (mätt: 5, 4 och 2-4), och 2x5-antagandet klippte
    text in i spriten (granskat)."""
    h, w = ark.shape[:2]
    kant = np.concatenate([ark[:6].reshape(-1, 3), ark[-6:].reshape(-1, 3),
                           ark[:, :6].reshape(-1, 3), ark[:, -6:].reshape(-1, 3)])
    bak = np.median(kant, axis=0)
    m = np.abs(ark.astype(float) - bak).max(axis=2) > 26
    rader = m.sum(axis=1)
    ut = []
    for y0, y1 in grupper([y for y in range(h) if rader[y] >= 0.02 * w]):
        if y1 - y0 < 0.12 * h:
            continue                                   # titel eller namnband
        # Kolumnerna är kända: arken har fem celler om 2760/5 = 552 px (mätt: ramarna ligger vid 527-574
        # och 1098-1141, dvs kring 552 och 1104). Raderna kommer från innehållsbanden. Figurerna ligger
        # sedan centrerade i sin cell, så cellens omfång räcker — skräp och rester fångas av plocka.
        for k in range(N.KOLUMNER):
            ut.append((y0, y1, k * (w // N.KOLUMNER), (k + 1) * (w // N.KOLUMNER) - 1))
    return ut


def bibliotek() -> int:
    pal = palett()
    UT_BIBLIOTEK.mkdir(parents=True, exist_ok=True)
    n = 0
    for kort, fil in BIBLIOTEK.items():
        ark = np.asarray(Image.open(ROOT / "game" / "images" / fil).convert("RGB"))
        funna = figurer_i_ark(ark)
        bredder = []
        for nr, (y0, y1, x0, x1) in enumerate(funna, start=1):
            figur = N.plocka(ark[y0:y1 + 1, x0:x1 + 1], 2.0)   # bandet är redan fritt från namn
            if figur is None:
                print("  %s figur %d: ingen figur" % (kort, nr), file=sys.stderr)
                continue
            ikon_av(Image.fromarray(figur, "RGBA"), pal).save(UT_BIBLIOTEK / ("%s_%02d.png" % (kort, nr)))
            bredder.append(figur.shape[1])
            n += 1
        print("  %-5s %d figurer (band: %s)" % (kort, len(bredder),
              [(y0, y1) for y0, y1, _, _ in funna]), file=sys.stderr)
    print("%d figurer -> game/assets/%s" % (n, UT_BIBLIOTEK.name))
    return n


def main() -> int:
    if "--check" in sys.argv:
        return checka()
    if "--bibliotek" in sys.argv:
        return 0 if bibliotek() else 1
    if not ARK.exists():
        print("källbilden saknas: %s" % ARK, file=sys.stderr)
        return 1
    n = skriv("--prova" in sys.argv)
    print("%d hjältar %s" % (n, "mätta (inget skrivet)" if "--prova" in sys.argv else "-> game/assets/heroes"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
