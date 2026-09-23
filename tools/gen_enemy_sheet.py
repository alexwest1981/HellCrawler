#!/usr/bin/env python3
"""Fienderna ur ALEX' ARK: tio monster han ritade, klippta ur en bild och gjorda till spelets sex rutor.

    python3 tools/gen_enemy_sheet.py            # skriv game/assets/enemies/<id>.png för de tio
    python3 tools/gen_enemy_sheet.py --check    # mät i stället (storlek, rutor, fötter, genomskinlighet)
    python3 tools/gen_enemy_sheet.py --sheet    # kontaktkarta att döma på bild

KÄLLAN är `research/alex_monster_20260921.jpg` (hans egen bild, tio monster i rad på svart botten) och
är FACIT för utseendet: koden klipper, skalar och bygger rutor — den ritar aldrig om en figur.
Alex: *"Fienden ... den ser ut som något obeskrivligt ... Jag bifogar en bild med 10 monster, kan du
använda dem i spelet? Animera dem osv."* De tio ersätter precis de kroppar som var former i stället för
varelser (blob/wisp/swarm/crawler i gen_enemy_art.py), så ingen av de sju redan åtskilda bipederna rörs.

Kartan monster -> fiende-id:

    imp            -> skitterling        (liten demon, 12 hp)
    vålnad         -> candlewisp         (svävande varelse, 16 hp)
    tusenfoting    -> chime_swarm        (många ben = svärmen, 45 hp)
    succubus       -> glass_herald       (bevingad härold, 75 hp)
    cacodemon      -> salt_wretch        (svällande svävare, 90 hp)
    köttgolem      -> verdigris          (tung, ruttnande kropp, 240 hp)
    lich           -> ash_maw            (kåpa och skalle, 280 hp)
    cerberus       -> bell_drowned       (besten, 320 hp)
    baphomet       -> hollow_choir       (demonherre, 400 hp, boss)
    balrog         -> bellmother         (den största, 900 hp, boss)

RUTORNA (samma sex som gen_enemy_art.py, i den ordning spelet byter dem):

    0 andas in   1 andas ut   2 spänner sig   3 hugger   4 träffad   5 död

De byggs ur hans ENDA bild med rörelser som går att förklara: en liten andning (1 logisk px),
spänningen lutar bakåt, hugget lutar framåt och sträcks, träffen viker undan och dödsrutan faller
ihop. Allt i logiska pixlar och multiplicerat med S till duken, precis som gen_enemy_art.py — annars
skulle hans monster ha en annan pixeltäthet än resten av spelet.

Duken är 80x80 (S=2, 40 logiska pixlar) med figuren i en ruta centrerad i sidled och fötterna på
rad 66 — samma rad som spelet räknar golvet ur (main.gd: FEET_ROW * pixel_size under dukens mitt).
Bakgrunden tas bort med ett GENOMSKINLIGHETSKRAV, inte med en färgnyckel: svarta partier INUTI en
figur (lichens kåpa) är svarta med flit och blir inte ett hål.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, deque
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("Pillow och numpy behövs: uv pip install pillow numpy", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "enemies"
SHEET_FILE = OUT_DIR / "_kontaktkarta.png"
KALLA = ROOT / "research" / "alex_monster_20260921.jpg"
PALETTE_FILE = ROOT / "game" / "assets" / "palette.json"
SHEET_OUT = OUT_DIR / "_kontaktkarta_alex.png"

S = 1                      # en logisk pixel blir S x S dukpixlar. HÄR ÄR S = 1 MED FLIT (M76): den
                           # logiska rutan är nu ALEX' EGNA KONSTPIXLAR (mätt: 8 källpixlar per
                           # konstpixel i hans ark), så 1:1 är den högsta täthet konsten har. Att
                           # skala upp den med S gör bara blocken större, inte figuren finare.
LOGISK = 120               # duken i logiska pixlar = konstpixlar
MAX_BREDD = 100            # figurens tak i logiska pixlar. Över taket tvingas en förminskning fram
MAX_HÖJD = 100             # (den gamla duken kapade den högsta figuren 86 -> 32, alltså 2,7 gånger
                           # förminskad: det var därför fienden såg suddig ut, inte för att duken
                           # var liten — duken är oförändrad i meter, bara räknad i konstpixlar).
SIZE = LOGISK * S          # 120x120
FEET_ROW = 100             # raden fötterna står på: dukens mitt (60) + 40, samma som spelet räknar
                           # golvet ur (ENEMY_FEET_PX = 40 i main.gd) — 40 * 0,012 = 0,48 m
FRAMES = 6

# monster -> fiende-id, i den ordning de står i bilden
MAPPING: list[tuple[str, str]] = [
    ("imp", "skitterling"),
    ("vanlad", "candlewisp"),
    ("cacodemon", "salt_wretch"),
    ("succubus", "glass_herald"),
    ("tusenfoting", "chime_swarm"),
    ("baphomet", "hollow_choir"),
    ("kottgolem", "verdigris"),
    ("lich", "ash_maw"),
    ("cerberus", "bell_drowned"),
    ("balrog", "bellmother"),
]

# Bakgrunden är MÄTT: i springorna mellan rutorna och ovanför dem ligger ljusheten på median 5,
# 99-percentilen 7,3 och max 10,3. Konsten börjar strax över. Tröskeln 45 (första gissningen) svalde
# därför mörka DELAR av figurerna — cerberus och lichens kåpa är svarta med flit — och delade dem i
# bitar (mätt: "största området" i en ruta blev 44x53 px av en hel best).
TRÖSKEL = 14.0             # ljushet under den här = bakgrund (JPEG-svart med brus)


# ---------------------------------------------------------------- klippningen

def bakgrund(lum: np.ndarray) -> np.ndarray:
    """Bakgrund = mörka pixlar som hänger ihop med bildens kant (flood fill). Svarta partier inne i
    en figur nås aldrig därifrån och behålls — det är skillnaden mellan ett hål och en kåpa."""
    h, w = lum.shape
    mörk = lum < TRÖSKEL
    sedd = np.zeros_like(mörk)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mörk[y, x] and not sedd[y, x]:
                sedd[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mörk[y, x] and not sedd[y, x]:
                sedd[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mörk[ny, nx] and not sedd[ny, nx]:
                sedd[ny, nx] = True
                q.append((ny, nx))
    return sedd


def kluster(mask: np.ndarray, min_area: int) -> list[tuple[int, int, int, int, int]]:
    """Sammanhängande områden (fyrkant-grannar) som en lista (x0, y0, x1, y1, area)."""
    h, w = mask.shape
    sedd = np.zeros_like(mask)
    ut = []
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0, x0] or sedd[y0, x0]:
                continue
            q = deque([(y0, x0)])
            sedd[y0, x0] = True
            area = 0
            minx = maxx = x0
            miny = maxy = y0
            while q:
                y, x = q.popleft()
                area += 1
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not sedd[ny, nx]:
                        sedd[ny, nx] = True
                        q.append((ny, nx))
            if area >= min_area:
                ut.append((minx, miny, maxx, maxy, area))
    return ut


def pixelstorlek(ruta: np.ndarray) -> tuple[int, float]:
    """Konstpixelns storlek i källan, mätt som PLANHET: vid rätt faktor är nästan varje pixel lik sin
    granne fyra block bort. Alex' bild är pixelkonst uppskalad med interpolering (mätt: mjuka kanter
    och inga rena block), så en körningslängd räknar 1 överallt — planheten gör det inte."""
    q = (ruta // 16).astype(int)
    bästa, bästa_v = 1, -1.0
    for f in range(2, 11):
        if ruta.shape[0] <= f + 1 or ruta.shape[1] <= f + 1:
            break
        a = q[:-f, :-f]
        b = q[f:, :-f]
        c = q[:-f, f:]
        lika = ((a == b).all(axis=2) & (a == c).all(axis=2)).mean()
        if lika > bästa_v:
            bästa, bästa_v = f, lika
    return bästa, bästa_v


def ark_rutnät(lum: np.ndarray) -> tuple[list[int], int, int]:
    """Rutnätet i Alex' ark: x-gränserna mellan rutorna (mitten av varje ram, en mer än antalet
    rutor) och det vertikala bandet innanför ramens över- och underkant."""
    h, w = lum.shape
    rader = np.where((lum > 24).any(axis=1))[0]
    y0, y1 = int(rader[0]) + 6, int(rader[-1]) - 6
    band = lum[y0:y1]
    a = lum
    mx = np.maximum.reduce([band])
    # Ramfärgen är mörk men inte svart, och nästan grå. ANDELEN är det som skiljer ramen från en
    # ljus figur: ramen löper över hela bandet (~420 rader), en vålnads ljusa kant gör det inte.
    # Mätt: tröskeln 0,6 tog en kant i vålnaden (x 441) för en ram och gav elva rutor i stället för tio.
    ram = (band > 35) & (band < 150)
    andel = ram.mean(axis=0)
    kand = np.where(andel > 0.9)[0]
    # Ramarna står i PAR: den högra ramen i en ruta och den vänstra i nästa ligger ~18 px isär,
    # medan avståndet mellan två RUTOR är ~255 px. Slå ihop par inom 40 px — då blir varje gräns
    # mellan två rutor en punkt, och antalet gränser är antalet rutor + 1.
    grupper: list[list[int]] = []
    for x in kand:
        if grupper and x - grupper[-1][-1] <= 40:
            grupper[-1].append(int(x))
        else:
            grupper.append([int(x)])
    if not grupper:
        return []
    mitt = [int(round(sum(g) / len(g))) for g in grupper]
    # Fyll luckor: rutorna står jämnt, så ett avstånd som är dubbelt så stort som de andra betyder att
    # en ram inte hittades (mätt: balrogens eldränna skymde ramen mellan ruta 9 och 10 och gav tio
    # gränser i stället för elva). Lägg in de saknade gränserna på jämna avstånd — och säg det.
    steg = float(np.median(np.diff(mitt))) if len(mitt) > 1 else 0.0
    ut = [mitt[0]]
    for a1, b1 in zip(mitt, mitt[1:]):
        n = max(1, int(round((b1 - a1) / steg))) if steg > 0 else 1
        for k in range(1, n + 1):
            ut.append(int(round(a1 + (b1 - a1) * k / n)))
    if len(ut) != len(mitt):
        print(f"  ({len(ut) - len(mitt)} ramar hittades inte och räknades fram ur avstånden)", file=sys.stderr)
    return ut, y0, y1


def läs_arket() -> list[dict]:
    """Alex' bild -> tio figurer med sin RGBA-bild (i KÄLLANS skala, utan bakgrund).

    RUTA FÖR RUTA, inte hela bilden på en gång: ramarna har samma ljushet som mörk konst, så en
    tröskel som behåller lichens svarta kåpa binder också ihop alla tio rutorna till ett enda område
    (mätt: "ruta 1 är tom"), och en tröskel som håller rutorna åtskilda skär sönder en svart figur
    (mätt: cerberus blev 44x53 px av en hel best). Innanför ramen finns ingen av fällorna.
    """
    im = Image.open(KALLA).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    lum = a.sum(2) / 3.0
    gränser, ytopp, ybotten = ark_rutnät(lum)
    if len(gränser) != len(MAPPING) + 1:
        print(f"hittade {len(gränser) - 1} rutor i bilden, väntade {len(MAPPING)}", file=sys.stderr)
        return []
    rå = np.asarray(im).astype(np.uint8)
    ut = []
    for i, (namn, fid) in enumerate(MAPPING):
        # 14 px innanför gränsen: ramen är 3-4 px bred och står ~9 px in, så kanten på utsnittet är
        # rutans mörka INRE. Med 6 px låg ramen (ljushet ~40) kvar i kanten, och en bakgrund som ska
        # växa inifrån kanten stannade där — mätt blev varje figur 263x410, alltså hela rutan.
        # 20 px innanför gränsen: ramen är 3-4 px bred och står ~9 px in, och en gräns som räknats
        # fram ur avstånden (balrogens eldränna skymde en ram) kan ligga några pixlar fel. Låg en
        # ramkant kvar i utsnittets kant stannade bakgrunden där: hela rutan blev "figuren", med
        # ramens lodräta linje och en lös eldflisa som följde med i varje ruta (mätt).
        cx0, cx1 = gränser[i] + 20, gränser[i + 1] - 20
        rutl = lum[ytopp:ybotten, cx0:cx1]
        rfigur = ~bakgrund(rutl)                 # det som INTE hänger ihop med rutans kant
        delar_i = kluster(rfigur, min_area=60)
        if not delar_i:
            print(f"ruta {i + 1} är tom ({cx0}..{cx1})", file=sys.stderr)
            return []
        störst = max(delar_i, key=lambda d: d[4])
        # Figuren får ha lösa delar (en vinge, en eldstråle): allt som är minst en tjugondel av den
        # största kroppen hör till figuren, resten är flarn.
        # Kvar hänger vingar och eldstrålar (stora områden), men inte en tunn ramkant vid sidan om
        # figuren — mätt: cerberus fick en ljus lodrät linje bredvid sig vid tröskeln 5 %.
        behåll = [d for d in delar_i if d[4] >= störst[4] * 0.10 and d[2] - d[0] >= 3 and d[3] - d[1] >= 3]
        mask = np.zeros_like(rfigur)
        for d in behåll:
            mask[d[1]:d[3] + 1, d[0]:d[2] + 1] |= rfigur[d[1]:d[3] + 1, d[0]:d[2] + 1]
        # Klipp till figurens egen ruta (den största kroppens), så källan inte får en massa tomrum.
        x0, y0, x1, y1 = störst[0], störst[1], störst[2], störst[3]
        rader, kolumner = np.where(mask)
        y0, y1 = int(rader.min()), int(rader.max())
        x0, x1 = int(kolumner.min()), int(kolumner.max())
        crop = rå[ytopp + y0:ytopp + y1 + 1, cx0 + x0:cx0 + x1 + 1]
        alfa = (mask[y0:y1 + 1, x0:x1 + 1] * 255).astype(np.uint8)
        px, planhet = pixelstorlek(crop)
        ut.append({"namn": namn, "id": fid, "rgba": np.dstack([crop, alfa]), "px": px,
                   "planhet": round(planhet, 3), "källa": (x1 - x0 + 1, y1 - y0 + 1),
                   "yta": int(mask.sum())})
    return ut


# ---------------------------------------------------------------- rutorna

def logisk_bild(rgba: np.ndarray, px: int) -> tuple[np.ndarray, int]:
    """Skala ned figuren till LOGISKA pixlar med ett HELTALSFÖRHÅLLANDE: konstpixelns faktor gånger
    ett heltal till, så figuren ryms i duken (bredd ≤ 38, höjd ≤ 34 med fötterna på rad 33). Ett
    brutet förhållande ger en pixel 3 källpixlar och nästa 4 — det syns som ojämna kanter.

    BOX, inte NEAREST: källan är interpolerad, och ett blockmedelvärde är den exakta inversen. Med
    NEAREST hade varje ruta fått sin färg ur EN interpolerad kantpixel — kanterna blir gråsuddiga."""
    h, w = rgba.shape[:2]
    k = 1
    while (w / (px * k) > MAX_BREDD or h / (px * k) > MAX_HÖJD) and k < 16:
        k += 1
    f = px * k
    lw = max(1, w // f)
    lh = max(1, h // f)
    im = Image.fromarray(rgba, "RGBA").resize((lw, lh), Image.BOX)
    return np.asarray(im).astype(np.uint8), f


def sätt_in(figur: np.ndarray) -> np.ndarray:
    """Figuren in i duken: centrerad i sidled och med sin EGEN nederkant på golvraden, därefter
    uppskalad med S så duken får samma pixeltäthet som resten av spelets fiender.

    Nederkanten mäts som sista raden med färg — inte som arrayens sista rad. En genomskinlig rad i
    botten (marginalen som rörelserna behöver) hade annars lyft hela figuren: mätt stod balrogen på
    rad 67 i fem av sex rutor medan spelets golvrad är 65."""
    rader = np.where((figur[:, :, 3] > 0).any(axis=1))[0]
    kolumner = np.where((figur[:, :, 3] > 0).any(axis=0))[0]
    if not rader.size or not kolumner.size:
        return np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    fig = figur[rader[0]:rader[-1] + 1, kolumner[0]:kolumner[-1] + 1]
    lh, lw = fig.shape[:2]
    duk = np.zeros((LOGISK, LOGISK, 4), dtype=np.uint8)
    x = max(0, (LOGISK - lw) // 2)
    y = max(0, FEET_ROW // S - lh)          # nederkanten på dukens golvrad (FEET_ROW)
    duk[y:y + min(lh, LOGISK - y), x:x + min(lw, LOGISK - x)] = \
        fig[:min(lh, LOGISK - y), :min(lw, LOGISK - x)]
    duk = np.kron(duk, np.ones((S, S, 1), dtype=np.uint8))
    # TÄT FIGUR (M76). Dukens alfa blir 0 eller 255. Nedskalningen (BOX) medelvärdesbildar kanten och
    # lämnar halvgenomsläppliga pixlar, och spelets alpha_cut KASTAR dem — figuren blev gles och man
    # såg väggen genom den (Alex: *"de får inte bli transparenta om de är som i detta fall, en
    # cerberus"*). Mätt i ruta 0 av mire_hound: 1168 halvgenomsläppliga pixlar mot 392 helt täta.
    # Ett halvt täck är täck — konsten är pixelkonst, kanten ska vara hård.
    duk[:, :, 3] = np.where(duk[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    return duk


def ruta(figur: np.ndarray, dx: int, dy: int, sx: float, sy: float) -> np.ndarray:
    """En ruta: figuren skjuten (dx, dy) logiska pixlar och sträckt/kramad i sid- och höjdled kring
    sina fötter. Ingen omritning — bara förflyttning och skalning av hans egna pixlar.

    Taket är hårt: en figur får inte växa utanför duken. Mätt på balrogen (32 logiska pixlar hög av
    34 lediga) klipptes hugg- och träffrutan rakt av i överkanten — en rät skärkant ser ut som ett fel,
    inte som en rörelse. Skalan krymps till det som ryms i stället."""
    h, w = figur.shape[:2]
    sx = min(sx, LOGISK / max(1, w))
    sy = min(sy, (FEET_ROW // S - 1) / max(1, h))    # 32 logiska rader är det som ryms ovan golvraden
    ny = max(1, int(round(h * sy)))
    nx = max(1, int(round(w * sx)))
    im = np.asarray(Image.fromarray(figur, "RGBA").resize((nx, ny), Image.NEAREST), dtype=np.uint8)
    # Rutan får PLATS att växa: en sträckt figur i en lika stor ruta klipptes rakt av i kanten (mätt:
    # huggrutan på köttgolem, cerberus och balrog). Duken runt figuren är 40 logiska pixlar och figuren
    # högst 32, så en växt på ett par pixlar ryms — utrymmet fanns bara inte i den här arrayen.
    # Marginalen ligger ÖVER och PÅ SIDORNA, aldrig under: fötterna är rutan botten, och en extra rad
    # där hade lyft figuren en pixel över golvet (mätt: balrogens alla sex rutor stod på rad 67 i
    # stället för 65). Ett dy nedåt tas bort av ankaret, ett dy uppåt lyfter — det är andningen.
    ut = np.zeros((max(h, ny) + 2, max(w, nx) + 4, 4), dtype=np.uint8)
    hh, ww = ut.shape[:2]
    x = max(0, min((ww - nx) // 2 + dx, ww - nx))
    y = max(0, min(hh - ny + dy, hh - ny))
    ut[y:y + ny, x:x + nx] = im
    return ut


def sex_rutor(figur: np.ndarray) -> list[np.ndarray]:
    """De sex rutorna, i spelets ordning. Rörelserna är små med flit: en fiende som hoppar tre pixlar
    ser trasig ut, en som andas en pixel ser levande ut."""
    andas = ruta(figur, 0, 1, 1.0, 0.98)                 # 0 andas in: en pixel ned, lite ihop
    return [
        andas,
        figur,                                            # 1 andas ut
        ruta(figur, 0, 1, 0.94, 1.0),                      # 2 spänner sig: bakåt, kramad
        ruta(figur, 0, -1, 1.06, 1.02),                    # 3 hugger: framåt och sträckt
        ruta(figur, 1 if figur.shape[1] > 2 else 0, 1, 1.0, 0.96),   # 4 träffad: viker undan
        ruta(figur, 0, 2, 1.08, 0.72),                      # 5 död: faller ihop
    ]


def duk_av(figur: np.ndarray) -> np.ndarray:
    """Sex rutor i en rad, 80x80 var — spelets arkform."""
    ark = np.zeros((SIZE, SIZE * FRAMES, 4), dtype=np.uint8)
    for i, r in enumerate(sex_rutor(figur)):
        ark[:, i * SIZE:(i + 1) * SIZE] = sätt_in(r)
    return ark


# ---------------------------------------------------------------- kommandona

def skriv() -> list[dict]:
    if not KALLA.exists():
        print(f"källbilden saknas: {KALLA}", file=sys.stderr)
        return []
    figurer = läs_arket()
    rader = []
    for f in figurer:
        logisk, faktor = logisk_bild(f["rgba"], f["px"])
        ark = duk_av(logisk)
        Image.fromarray(ark, "RGBA").save(OUT_DIR / f"{f['id']}.png")
        rader.append({"id": f["id"], "namn": f["namn"], "källa": f["källa"], "px": f["px"],
                      "planhet": f["planhet"], "logisk": (logisk.shape[1], logisk.shape[0]),
                      "faktor": faktor})
    return rader


def kontaktkarta(figurer: list[dict]) -> None:
    """Alla tio i en bild, var sin rad, så helheten går att döma på bild."""
    rader = len(figurer)
    ut = np.zeros((SIZE * rader, SIZE * FRAMES, 4), dtype=np.uint8)
    for i, f in enumerate(figurer):
        ut[i * SIZE:(i + 1) * SIZE] = np.asarray(
            Image.open(OUT_DIR / f"{f['id']}.png").convert("RGBA"), dtype=np.uint8)
    Image.fromarray(ut, "RGBA").save(SHEET_OUT)
    print(f"kontaktkarta: {SHEET_OUT}")


def checka() -> int:
    """Mät det som spelet räknar med: arkets storlek, varje ruta, fötterna och genomskinligheten."""
    fel = 0
    for namn, fid in MAPPING:
        p = OUT_DIR / f"{fid}.png"
        if not p.exists():
            print(f"  FEL {fid}: filen saknas")
            fel += 1
            continue
        im = Image.open(p).convert("RGBA")
        a = np.asarray(im)
        if im.size != (SIZE * FRAMES, SIZE):
            print(f"  FEL {fid}: arket är {im.size}, ska vara {(SIZE * FRAMES, SIZE)}")
            fel += 1
            continue
        # figuren ska ha fötterna på FEET_ROW och röra sig mellan rutorna
        fot = []
        for i in range(FRAMES):
            r = a[:, i * SIZE:(i + 1) * SIZE]
            rad = np.where((r[:, :, 3] > 0).any(axis=1))[0]
            fot.append(int(rad.max()) if rad.size else -1)
        if fot[1] != FEET_ROW - 1 and abs(fot[1] - (FEET_ROW - 1)) > 1:
            print(f"  FEL {fid}: fötterna på rad {fot[1]}, ska vara {FEET_ROW - 1}")
            fel += 1
        # RÖRELSEN mäts som skillnad i PIXLAR mot första rutan. Att bara jämföra fötternas rad räckte
        # inte: en kropp kan andas, luta och kramas med fötterna stilla (och de ska stå stilla — det
        # är en fot på ett golv), och då sa kontrollen "ingen rörelse" om sex olika rutor.
        bas = a[:, 0:SIZE]
        rörliga = 0
        for i in range(1, FRAMES):
            r = a[:, i * SIZE:(i + 1) * SIZE]
            olika = (r != bas).any(axis=2).mean()
            if olika >= 0.015:
                rörliga += 1
        if rörliga < FRAMES - 2:
            print(f"  FEL {fid}: bara {rörliga} av {FRAMES - 1} rutor skiljer sig från den första")
            fel += 1
        # hörnen ska vara genomskinliga och figuren får inte röra kanten
        hörn = [a[0, 0, 3], a[0, -1, 3], a[-1, 0, 3], a[-1, -1, 3]]
        if any(h != 0 for h in hörn):
            print(f"  FEL {fid}: hörnen är inte genomskinliga ({hörn})")
            fel += 1
        if (a[0, :, 3] > 0).any() or (a[:, 0, 3] > 0).any():
            print(f"  FEL {fid}: figuren rör arkets kant")
            fel += 1
        if fel == 0:
            print(f"  ok   {fid}: fötter {fot}, {im.size[0] // SIZE} rutor")
    return fel


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--skriv", action="store_true")
    args = ap.parse_args()
    if args.check:
        print("— Alex' fienden ark —")
        return 1 if checka() else 0
    if args.sheet:
        kontaktkarta(läs_arket())
        return 0
    rader = skriv()
    if rader:
        kontaktkarta(läs_arket())
        print(json.dumps(rader, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
