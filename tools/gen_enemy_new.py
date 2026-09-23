#!/usr/bin/env python3
"""Nya monsterark -> spelets sex rutor. Klipper Alex' nyaste bilder (game/images, 22 sep 2026).

    python3 tools/gen_enemy_new.py              # skriv de fiender som tabellen pekar ut
    python3 tools/gen_enemy_new.py --prova      # skriv bara en kontaktkarta att döma på bild

Arken är pixelkonst-ark med 2 rader x 5 kolumner (tio monster) och en TITELBAND överst, på mörk
skifferbotten. Rutnätet är KÄNT — titelbandet är 130 px och varje cell är 552 x 687 px — därför klipps
cellerna som rektanglar i stället för att letas upp med kluster. (Mätt: kluster på de här arken gav 1-4
områden, inte tio; skifferbotten och cellramarna hänger ihop. Rutnätet är billigare och exakt.)

Bara URTAGET är nytt här. Rutor, golvrad, nedskalning till logiska pixlar och arkformen kommer från
`gen_enemy_sheet.py` — samma maskineri som Alex förra ark, mätt och grönt.
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_enemy_sheet as G  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "game" / "images"
OUT = ROOT / "game" / "assets" / "enemies"

TITEL_H = 130          # titelbandet överst på arken (mätt: första figuren börjar på y 158)
TEXTFRAKTION = 0.62    # nedre andelen av cellen som är NAMNBAND (mätt: figurens fötter slutar ~35 %
                       # ovanför cellens botten och texten står under den; utan kapningen följde namnet
                       # med in i spriten — mätt som 8 spridda pixlar på rad 64-65 under en tom rad)
RADER, KOLUMNER = 2, 5

# Vilket monster i vilket ark som blir vilken fiende. Sifferordningen är LÄSORDNING i arket (vänster
# till höger, uppifrån och ned). Ändra en rad här i stället för någon annanstans.
#
#   ark 1 (hg2q75): 1 Abyssal Crawler  2 Soul Maelstrom  3 Hellforge Warden  4 Ascended Banshee
#                   5 Scuttling Desolator  6 Umbral Stalker  7 Cereberal Hound  8 Aeon Beholder
#                   9 Ritualist  10 Horned Overlord
PLAN = [
    {
        "ark": "Gemini_Generated_Image_hg2q75hg2q75hg2q.jpeg",
        "karta": {
            3: "copper_warden",     # pansarvagnen med sin hammare
            4: "ossuary_king",      # skallespet med gloria
            10: "ash_sovereign",    # den hornade demonherren
            7: "mire_hound",        # den trehövdade besten
            1: "bone_wretch",       # den köttiga krälande
            6: "wax_sentinel",      # kåpvålnaden
            2: "pale_reaper",       # den spektrale liemannen
        },
    },
]


def största_området(mask: np.ndarray) -> tuple[int, int, int, int, int]:
    """Största sammanhängande området (x0, y0, x1, y1, area). Ramar och textrester är mindre."""
    h, w = mask.shape
    sedd = np.zeros_like(mask)
    bäst = (0, 0, 0, 0, 0)
    for y0 in range(0, h, 2):
        for x0 in range(0, w, 2):
            if not mask[y0, x0] or sedd[y0, x0]:
                continue
            q = deque([(y0, x0)])
            sedd[y0, x0] = True
            n = 0
            minx = maxx = x0
            miny = maxy = y0
            while q:
                y, x = q.popleft()
                n += 1
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not sedd[ny, nx]:
                        sedd[ny, nx] = True
                        q.append((ny, nx))
            if n > bäst[4]:
                bäst = (minx, miny, maxx, maxy, n)
    return bäst


def behåll_stora(mask: np.ndarray, min_andel: float = 0.02) -> np.ndarray:
    """Alla områden utom de små (skräp). Staven och glorian hänger fritt men är stora nog att stanna."""
    h, w = mask.shape
    sedd = np.zeros_like(mask)
    områden = []
    for y0 in range(0, h, 2):
        for x0 in range(0, w, 2):
            if not mask[y0, x0] or sedd[y0, x0]:
                continue
            q = deque([(y0, x0)])
            sedd[y0, x0] = True
            punkter = []
            while q:
                y, x = q.popleft()
                punkter.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not sedd[ny, nx]:
                        sedd[ny, nx] = True
                        q.append((ny, nx))
            områden.append(punkter)
    if not områden:
        return mask
    tröskel = max(60, min_andel * max(len(p) for p in områden))
    ut = np.zeros_like(mask)
    for p in områden:
        if len(p) >= tröskel:
            for y, x in p:
                ut[y, x] = True
    return ut


def fyll_hål(mask: np.ndarray) -> np.ndarray:
    """Fyll igen hål inuti figuren: allt som inte nås från cellens kant hör till figuren.

    Första försöket tog största sammanhängande området, och då föll mörka partier bort — en vålnad i
    mörk kåpa mot mörk skiffer har samma färg som bakgrunden, så bara konturerna och de ljusa delarna
    blev kvar och figuren blev en flisa (mätt på kontaktkartan: fyra av sju figurer kapade). Hålen
    fylls därför med kant-fyllning i stället: det som är inneslutet av kontur är figur, hur mörkt det
    än är.
    """
    h, w = mask.shape
    yttre = np.zeros_like(mask)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not mask[y, x] and not yttre[y, x]:
                yttre[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not mask[y, x] and not yttre[y, x]:
                yttre[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not yttre[ny, nx]:
                yttre[ny, nx] = True
                q.append((ny, nx))
    return mask | ~yttre


def plocka(cell: np.ndarray, namnband: float = TEXTFRAKTION) -> np.ndarray | None:
    """Figuren ur cellen: allt som avviker från cellens egen kantfärg, med hålen ifyllda, som RGBA.

    Kantfärgen mäts i cellens ytterkant i stället för som en fast siffra: skifferbottnen skiljer sig
    mellan arken, och ett fast värde hade antingen ätit hål i mörka varelser eller lämnat kvar en
    grå fyrkant runt ljusa.
    """
    h, w = cell.shape[:2]
    kant = np.concatenate([cell[:8].reshape(-1, 3), cell[-8:].reshape(-1, 3),
                           cell[:, :8].reshape(-1, 3), cell[:, -8:].reshape(-1, 3)])
    bak = np.median(kant, axis=0)
    avvik = np.abs(cell.astype(float) - bak).max(axis=2)
    mask = fyll_hål(avvik > 26)
    # Cellens ram och titeltext ligger i ytterkanten och ska inte bli figuren.
    mask[:6] = False; mask[-6:] = False; mask[:, :6] = False; mask[:, -6:] = False
    # Namnbandet under figuren kapas. Textens överkant ligger inte på samma rad överallt (namnen är
    # olika långa och står ibland i två rader), så klippet mäts: den T O M M A radföljden mellan
    # fötterna och texten är gränsen. Ett fast mått (första försöket: 30 % av cellen) lämnade kvar
    # texten under de figurer vars namn var kort — mätt på kontaktkartan.
    # MÄTT cellstruktur (Hellforge Warden, cell 687 px): figur rad 47-425, tomt 425-438, namnrad 1
    # 444-504, tomt 505-527, namnrad 2 528-590, tomt 590-687. Gränsen är alltså den ÖVERSTA tomma
    # följden i cellens nedre del — att leta nedifrån tog fel (den hittade tomrummet MELLAN de två
    # namnraderna och lämnade kvar den första raden).
    # Gränsen är MÄTT över hela arket: den tomma följden mellan figurens fötter och namnet ligger på
    # 0,60-0,64 av cellhöjden i sju av tio celler (rad 409-437 av 687). Ett per-cell-letande tog fel i
    # de två celler där namnet ligger lägre (där hittades tomrummet MELLAN namnraderna i stället), så
    # måttet används rakt av — arket är maskinellt och alla celler har samma layout.
    # Klippet mäts per cell, med arkets mått som fallback: namnet ligger olika högt (mätt 0,63-0,79 i
    # hjältearket, 0,60-0,64 i monsterarket), och ett fast mått lämnade kvar "SHADOWBLADE" under en av
    # hjältarna. Letandet börjar på halva cellen — en ficka inne i figuren (mellan benen) ligger
    # ovanför det, och namnets två rader ligger under den första följden.
    rader_mask = mask.sum(axis=1)
    tom = rader_mask == 0
    kap = h if namnband > 1 else int(round(h * namnband))
    # NAMNBLOCKET, INTE FÖRSTA TOMRUMMET (M81). Namnet står i TVÅ rader (mätt: "ABYSSAL" rad
    # 439-516, tomt 517-525, "CRAWLER" 526-602 i cell 1,1), och glappet mellan figurens fötter och
    # den första namntexten är bara 1-3 rader. Den gamla regeln — första tomrummet på minst sex rader
    # efter cellens mitt — hittade därför TOMRUMMET MELLAN DE TVÅ NAMNRADERNA och kapade bort bara den
    # andra raden: kvar i spriten stod "ABYSSAL" under figuren hos Alex.
    # Rätt gräns är det KORTA glappet före namnet: ett glapp på 1-5 rader följt av innehåll och sedan
    # ett långt glapp (>= 6) är namnets överkant. Finns inget sådant (figuren slutar långt ovanför
    # namnet, som i rad 2 där glappet är 126 rader) kapas vid det första långa glappet.
    tomma: list[tuple[int, int]] = []
    i = int(0.5 * h)
    while i < h:
        if tom[i]:
            j = i
            while j < h and tom[j]:
                j += 1
            tomma.append((i, j - i))
            i = j
        else:
            i += 1
    if namnband <= 1:
        for n, (y, längd) in enumerate(tomma):
            if 1 <= längd <= 5:
                # innehåll och sedan ett långt glapp inom 200 rader?
                for y2, längd2 in tomma[n + 1:]:
                    if y2 - y > 200:
                        break
                    if längd2 >= 6:
                        kap = y
                        break
                if kap == y:
                    break
            elif längd >= 6:
                kap = y
                break
    mask[kap:] = False
    # Skräp (lösa pixlar, en rambit som överlevde kanten) tas bort, men BARA skräp: figuren är inte
    # alltid ETT sammanhängande område — staven, glorian och svärdet kan hänga fritt. Första försöket
    # behöll största området och dess omfång, och då kapades just de delarna (mätt: hjälten
    # "druidic_sage" gick från 500x419 px till 172x217, och fyra monster tappade 4-6 logiska pixlar i
    # höjd). Här behålls i stället varje område som är minst 2 % av det största.
    mask = behåll_stora(mask)
    rader = np.where(mask.any(axis=1))[0]
    kolumner = np.where(mask.any(axis=0))[0]
    if not rader.size or not kolumner.size or mask.sum() < 2000:
        return None
    y0, y1 = rader[0], rader[-1]
    x0, x1 = kolumner[0], kolumner[-1]
    figur = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 4), dtype=np.uint8)
    figur[:, :, :3] = cell[y0:y1 + 1, x0:x1 + 1]
    figur[:, :, 3] = (mask[y0:y1 + 1, x0:x1 + 1] * 255).astype(np.uint8)
    return figur


def rita(källa: Path, karta: dict, prova: bool) -> int:
    ark = np.asarray(Image.open(källa).convert("RGB"))
    höjd, bredd = ark.shape[:2]
    cell_h = (höjd - TITEL_H) // RADER
    cell_w = bredd // KOLUMNER
    skrivna = 0
    figurer = []
    for nr in sorted(karta):
        rad, kol = divmod(nr - 1, KOLUMNER)
        cell = ark[TITEL_H + rad * cell_h: TITEL_H + (rad + 1) * cell_h, kol * cell_w:(kol + 1) * cell_w]
        fig = plocka(cell)
        if fig is None:
            print("  cell %2d: ingen figur hittad" % nr, file=sys.stderr)
            continue
        px, _ = G.pixelstorlek(fig)
        logisk, f = G.logisk_bild(fig, px)
        duk = G.duk_av(logisk)
        figurer.append({"id": karta[nr], "duk": duk, "källa": källa.name, "cell": nr, "px": px})
        if not prova:
            Image.fromarray(duk).save(OUT / ("%s.png" % karta[nr]))
        skrivna += 1
        print("  %-16s <- %s ruta %2d: %d källpixlar/konstpixel, figur %dx%d logiska pixlar"
              % (karta[nr], källa.name[-24:], nr, px, logisk.shape[1], logisk.shape[0]))
    return skrivna


def kontroll() -> int:
    """GRINDEN (M81): namnet får inte ligga kvar i figuren.

    Mäter det provet ska fånga: för varje cell i PLAN klipps figuren och den sista raden med innehåll
    letas upp. Under figuren ska det finnas ett tomrum på minst sex rader — finns det innehåll tätt
    under figuren är det namntexten som överlevde kapningen (precis felet Alex såg: "ABYSSAL" under
    figuren). Provet biter: med den gamla regeln (första tomrummet på minst sex rader) faller cell 1,
    där kapet hamnade MELLAN namnets två rader och den första raden stod kvar.
    """
    fel = 0
    for plan in PLAN:
        källa = IMAGES / plan["ark"]
        ark = np.asarray(Image.open(källa).convert("RGB"))
        höjd, bredd = ark.shape[:2]
        cell_h = (höjd - TITEL_H) // RADER
        cell_w = bredd // KOLUMNER
        for nr in sorted(plan["karta"]):
            rad, kol = divmod(nr - 1, KOLUMNER)
            cell = ark[TITEL_H + rad * cell_h: TITEL_H + (rad + 1) * cell_h, kol * cell_w:(kol + 1) * cell_w]
            fig = plocka(cell)
            if fig is None:
                print("  FEL  %-16s ruta %2d: ingen figur" % (plan["karta"][nr], nr))
                fel += 1
                continue
            # NAMNBLOCKETS SIGNATUR: en KORT lucka (1-5 rader) med innehåll under sig inne i klippet är
            # namntexten som står kvar — figurens fötter och namnet skiljs av precis ett sådant glapp
            # (mätt 2-3 rader), medan en riktig led i figuren är sammanhängande. Klippet är ett
            # omfång, så figuren slutar alltid på sin sista innehållsrad och "tomt under figuren" kan
            # inte mätas i efterhand: det är luckan INUTI som avslöjar namnet.
            alfa = [bool(v) for v in np.ravel((fig[:, :, 3] > 0).any(axis=1))]
            kort_lucka_med_innehåll = False
            i = 0
            while i < len(alfa):
                if not alfa[i]:
                    j = i
                    while j < len(alfa) and not alfa[j]:
                        j += 1
                    if 1 <= (j - i) <= 5 and any(alfa[j:]):
                        kort_lucka_med_innehåll = True
                        break
                    i = j
                else:
                    i += 1
            print("  %s  %-16s ruta %2d: %s" %
                  ("FEL" if kort_lucka_med_innehåll else "ok ", plan["karta"][nr], nr,
                   "kort lucka med innehåll under = namntext kvar" if kort_lucka_med_innehåll
                   else "inga namntext-rader i klippet"))
            if kort_lucka_med_innehåll:
                fel += 1
    print("kontroll: %d fel" % fel)
    return 1 if fel else 0


def main() -> int:
    prova = "--prova" in sys.argv
    if "--kontroll" in sys.argv:
        return kontroll()
    totalt = 0
    figurer = []
    for plan in PLAN:
        källa = IMAGES / plan["ark"]
        if not källa.exists():
            print("källbilden saknas: %s" % källa, file=sys.stderr)
            return 1
        print("%s:" % plan["ark"])
        totalt += rita(källa, plan["karta"], prova)
    print("%d fiender %s" % (totalt, "mätta (inget skrivet)" if prova else "-> game/assets/enemies"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
