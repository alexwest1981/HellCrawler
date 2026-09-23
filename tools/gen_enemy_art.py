#!/usr/bin/env python3
"""Fiendefigurerna: egen pixelkonst, räknad fram — inte nedladdad och inte ritad för hand.

    python3 tools/gen_enemy_art.py           # skriv game/assets/enemies/*.png
    python3 tools/gen_enemy_art.py --check   # mät i stället (fällor: osynliga delar, trasiga silhuetter)
    python3 tools/gen_enemy_art.py --sheet   # kontaktkarta att döma kvaliteten på

Sex rutor per fiende, i den ordning spelet byter dem:

    0  andas in          3  hugger
    1  andas ut          4  träffad
    2  spänner sig       5  död

Varför sex: en fiende som bara har två rutor kan inte BERÄTTA något — man ser att den rör sig, inte
att den tänker hugga. Med spännings- och huggruktor går attacken att läsa innan den landar, och
dödsrutan gör att en besegrad fiende ser besegrad ut i stället för borttagen.

Duken är 40x40 men figuren ritas i en 32x32-ruta som placeras med fötterna på rad 36. Marginalen
bär huvudutrymme och fötterna på en känd rad betyder att 3D-vyn kan räkna ut var
golvet är (main.gd: 16.5 px under dukens mitt) i stället för att gissa.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow saknas: uv pip install pillow", file=sys.stderr)
    raise

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "enemies"
PALETTE_FILE = ROOT / "game" / "assets" / "palette.json"
ENEMIES_FILE = ROOT / "game" / "data" / "enemies"
SHEET_FILE = ROOT / "game" / "assets" / "enemies" / "_kontaktkarta.png"

# DUBBLERINGEN (M33): duken är dubbelt så stor, men formerna ritar kvar i sina 32 logiska pixlar —
# varje logisk pixel blir S x S i duken. Skälet är att figuren ska ha nästan dubbel upplösning UTAN
# att byta ut konsten: silhuetten, hållningarna och accenterna är mätta och dömda, och att rita om
# dem för hand vore att slänga de mätningarna. Det som blir finare är allt som ritas i dukpixlar:
# konturen (1 px i stället för 2), ljusets band, skuggan — och `kanter()`, som ger silhuettens
# trappsteg dubbelt så många steg i stället för att varje steg blir dubbelt så stort.
S = 3                  # en logisk pixel blir S x S dukpixlar. Här är S > 1 med flit: formerna RITAS i
                       # LOGISKA pixlar (32), så uppskalningen är den enda vägen till fler dukpixlar
                       # för konturen, ljusets band och kanternas trappsteg. Alex' klippta ark
                       # (gen_enemy_sheet.py) är däremot redan i konstpixlar och har S = 1.
LOGISK = 32            # figurens ruta i logiska pixlar (= den gamla duken)
SIZE = 40 * S          # duken: 120x120 (var 80x80, och 40x40 före M33)
BOX = LOGISK * S       # figurens ruta i dukpixlar: 96x96
OFFSET = (SIZE - BOX) // 2   # marginalen (12): figuren centreras; nedre kanten bär huvudutrymme
FEET_ROW = OFFSET + 29 * S   # raden där fötterna står (99; mätt samma rad som de klippta arken).
                             # Fötternas höjd över golvet räknas i meter i main.gd
                             # (ENEMY_FEET_PX * pixel_size = 0,48 m), inte i dukpixlar — duken är bara
                             # upplösningen. Mätt, inte gissat: låg skuggan högre hamnade den under
                             # fötterna och räknades som en egen kropp (sammanhang 56 % på en frisk figur).
FRAMES = 6
SEED = "crawler-enemies-2026"

# DE TIO SOM ALEX RITADE (tools/gen_enemy_sheet.py): deras filer kommer ur hans ark, inte ur den här
# generatorn. Utan listan skrev `write_all` över dem vid nästa körning, och `--check` dömde hans konst
# på former och palett som den aldrig var gjord för. De har sitt eget prov i stället:
# `gen_enemy_sheet.py --check` mäter rutornas storlek, fötternas rad och att alla sex rutor rör sig.
FRÅN_ALEX: set[str] = {
    "skitterling", "candlewisp", "salt_wretch", "glass_herald", "chime_swarm",
    "hollow_choir", "verdigris", "ash_maw", "bell_drowned", "bellmother",
    # ... och de sju som Alex ritade om 22 sep 2026 (tools/gen_enemy_new.py klipper dem ur hans nya
    # monsterark). De stod här som former förut; utan listan skriver den här generatorn över dem.
    "copper_warden", "ossuary_king", "ash_sovereign", "mire_hound",
    "bone_wretch", "wax_sentinel", "pale_reaper",
}

# Palettindex (samma 16 färger som rutors och kortens konst, game/assets/palette.json)
INK, DARK, MORTAR = 1, 2, 3
STONE, STONE_D, STONE_L, EDGE = 4, 5, 6, 7
MOSS, SAND, BONE, AMBER = 8, 9, 10, 11
BLOOD, BLOOD_D, RED, ORANGE = 12, 13, 14, 15

# Formen per fiende, satt för hand. Namnmatchningen nedan räckte inte: den föll tillbaka på "biped"
# för allt den inte kände igen, och resultatet var tolv identiska humanoiden av sjutton (mätt i
# granskningen: "players will struggle to differentiate threat levels"). Blob-formen användes inte
# alls. Här är fördelningen avsiktlig: det som ÄR en humanoid får vara det, resten får en kropp som
# namnet antyder.
FORMER: dict[str, str] = {
    "skitterling": "crawler",
    "verdigris": "crawler",
    "mire_hound": "hound",
    "candlewisp": "wisp",
    "glass_herald": "wisp",
    "hollow_choir": "wisp",
    "chime_swarm": "swarm",
    "bellmother": "swarm",
    "ash_maw": "blob",
    "bell_drowned": "blob",
    "salt_wretch": "blob",
    "bone_wretch": "biped",
    "wax_sentinel": "biped",
    "ossuary_king": "biped",
    "copper_warden": "biped",
    "ash_sovereign": "biped",
    "pale_reaper": "biped",
}

# ACCENTEN: kroppen är formen, accenten är identiteten. Formen räckte inte — fem av sex humanoiden
# bar samma krona (den namnmatchade `horn`-flaggan slog till på king/sovereign/reaper/warden/
# sentinel, alltså precis de sex bipederna), och granskningen av kontaktkartan dömde dem som
# "players will struggle to differentiate threat levels" / "the silhouette test fails".
#
# Varje accent ändrar SILHUETTEN, inte bara färgen: ett vapen som sticker ut utanför kroppen syns
# på 40 px, ett annat färgval gör det inte. Vapnen ritas i BONE och AMBER — de två ljusaste tonerna
# i paletten, och de enda `light()` lämnar i fred. Det svarar mot det andra mätta omdömet på samma
# ark: "mörkt på mörkt, fienden smälter ihop med golvet".
#
# Fästpunkterna är med flit inuti kroppen (torso/kappa), inte vid handen: armarna flyttar sig med
# hållningen, och en accent som sitter i handen i stå-rundan kan bli ett LÖST FÖREMÅL i huggrundan
# — den buggklassen (lem utanför bålen = egen figur) är mätt tidigare och kontrollen fäller den.
ACCENTER: dict[str, str] = {
    "bone_wretch": "armar",         # två extra, knotiga armar
    "wax_sentinel": "sköld",        # sköld på vänster arm: bred och asymmetrisk
    "ossuary_king": "krona",        # taggig krona
    "copper_warden": "hammare",     # hammare från bålen och upp: bryter rektangeln
    "ash_sovereign": "hornpar",     # horn ut åt sidorna
    "pale_reaper": "lie",           # lie tvärs över kroppen: starkaste silhuettbrottet
}

ARCHETYPES = [
    ("wisp", "wisp"), ("wraith", "wisp"), ("flame", "wisp"), ("lantern", "wisp"),
    ("crawler", "crawler"), ("skitter", "crawler"), ("mite", "crawler"),
    ("hound", "hound"), ("wolf", "hound"), ("dog", "hound"),
    ("swarm", "swarm"), ("toll", "hound"), ("moth", "swarm"), ("bee", "swarm"),
    ("blob", "blob"), ("ooze", "blob"), ("slime", "blob"), ("mire", "blob"),
    ("king", "biped"), ("sovereign", "biped"), ("mother", "biped"), ("reaper", "biped"),
    ("warden", "biped"), ("sentinel", "biped"), ("champion", "biped"),
]

# --- lägena --------------------------------------------------------------------------------
# Varje ruta är en hållning, inte en ny figur: samma kropp, olika spänning. Det är så en fiende
# kan hugga utan att vara en andra teckning.
POSES = [
    {"namn": "andas in", "dy": 0, "lean": 0, "armar": 0, "gap": 0},
    {"namn": "andas ut", "dy": 1, "lean": 0, "armar": 0, "gap": 0},
    # Spänningen lutar kroppen två pixlar BAKÅT och hugget två framåt. En pixel räckte inte: i
    # granskningen lästes förvarningen som "en pixels hukning" och gick inte att se i tid.
    {"namn": "spänner", "dy": 0, "lean": -2, "armar": 2, "gap": 0},
    {"namn": "hugger", "dy": 1, "lean": 2, "armar": 3, "gap": 1},
    {"namn": "träffad", "dy": 1, "lean": -2, "armar": 1, "gap": 1, "ljus": 1},
    {"namn": "död", "dy": 3, "lean": 0, "armar": 0, "gap": 1, "platt": 0.42},
]


def load_palette() -> list[tuple[int, int, int]]:
    return [tuple(int(c) for c in f) for f in json.loads(PALETTE_FILE.read_text())]


def load_enemies() -> list[dict]:
    ut = []
    for fil in sorted(ENEMIES_FILE.glob("*.json")):
        ut += json.loads(fil.read_text())
    return ut


def blank() -> list[list[int]]:
    return [[INK] * SIZE for _ in range(SIZE)]


def put(px, x: int, y: int, c: int) -> None:
    """En LOGISK pixel (32x32) blir S x S dukpixlar, med marginalen OFFSET runt figuren.

    Rotorsaken till ett helt trasigt svep: `sym` lade på marginalen men `put`/`box` gjorde det inte,
    så armar och ben hamnade fyra pixlar fel och figurerna föll i bitar (mätt: 49-95 % sammanhang).
    Marginalen läggs nu på ETT ställe, här — och dubbleringen likaså, så formerna kan fortsätta
    rita i sina 32 logiska pixlar och ändå hamna rätt i den dubbla duken.
    """
    if 0 <= x < LOGISK and 0 <= y < LOGISK:
        for dy in range(S):
            for dx in range(S):
                duk_x, duk_y = x * S + OFFSET + dx, y * S + OFFSET + dy
                if 0 <= duk_x < SIZE and 0 <= duk_y < SIZE:
                    px[duk_y][duk_x] = c


def fin(px, x: int, y: int, c: int) -> None:
    """EN dukpixel. Till för de detaljer som bara finns i den dubbla upplösningen — munnar, glimtar,
    tygveck — alltså sådant som inte har någon plats i den logiska rutan."""
    if 0 <= x < SIZE and 0 <= y < SIZE:
        px[y][x] = c


def fin_box(px, x0: int, y0: int, x1: int, y1: int, c: int) -> None:
    for y in range(min(y0, y1), max(y0, y1) + 1):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            fin(px, x, y, c)


def box(px, x0: int, y0: int, x1: int, y1: int, c: int) -> None:
    for y in range(min(y0, y1), max(y0, y1) + 1):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            put(px, x, y, c)


def wang(x: int, y: int, salt: str = "") -> float:
    """Deterministiskt slumptal ur positionen: samma fiende blir sig lik varje generering."""
    h = hashlib.sha256(f"{SEED}:{salt}:{x}:{y}".encode()).hexdigest()
    return int(h[:8], 16) / 0xFFFFFFFF


def sym(px, x0: int, y0: int, x1: int, y1: int, c: int) -> None:
    """Rita en halva och spegla den kring mitten: symmetri ser avsiktligt ut, slump gör det inte.

    Speglingen sker i den LOGISKA rutan (32): pixel x hamnar på 31-x, och put() lägger på marginalen
    och dubbleringen åt båda. Att spegla kring BOX (64 dukpixlar) hade lagt halvorna ett halvt
    dussin pixlar fel — samma klass av fel som gav figurerna en spricka rakt igenom.
    """
    box(px, x0, y0, x1, y1, c)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(px, LOGISK - 1 - x, y, c)


def outline(px, c: int = DARK) -> None:
    """Kontur runt figuren: gör den läsbar mot golvet.

    DARK, inte INK. Första versionen kantade med INK — som ÄR bakgrunden — så konturen blev osynlig
    och mörka fiender försvann mot mörka golv (mätt i granskningen: "severe value blending, the
    silhouette will be completely lost on dark backgrounds"). Konturen är figurens sista chans att
    läsas, den får inte vara transparent.
    """
    kopia = [rad[:] for rad in px]
    for y in range(SIZE):
        for x in range(SIZE):
            if kopia[y][x] != INK:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < SIZE and 0 <= nx < SIZE and kopia[ny][nx] != INK:
                        # Skrivs direkt i duken: passet räknar dukpixlar, och put() tar logiska.
                        px[y][x] = c
                        break


def light(px, styrka: float = 1.0) -> None:
    """Ljussättning: lyktan hänger i taket, så figuren är ljusare upptill och mörkare nedtill.

    En platt figur med kontur läses som ett klistermärke. Att bara skugga kanten räcker för att den
    ska stå i rummet. Passet rör bara kroppsfärger — kontur och ögon lämnas i fred.
    """
    kropp = [c for rad in px for c in rad if c not in (INK, DARK, MORTAR, RED, AMBER, ORANGE, SAND, BONE)]
    if not kropp:
        return
    ys = [y for y in range(SIZE) for x in range(SIZE) if px[y][x] in kropp]
    topp, botten = min(ys), max(ys)
    höjd = max(1, botten - topp)
    for y in range(SIZE):
        for x in range(SIZE):
            c = px[y][x]
            if c not in kropp:
                continue
            andel = (y - topp) / höjd
            if andel < 0.28 * styrka:
                px[y][x] = _ljusare(c)
            elif andel > 0.90:
                px[y][x] = _mörkare(_mörkare(c))     # nedersta tiondelen: två steg, inte ett
            elif andel > 0.72:
                px[y][x] = _mörkare(c)
    # Kantljus överst: en rad ljus där figuren möter bakgrunden uppåt.
    kopia = [rad[:] for rad in px]
    for x in range(SIZE):
        for y in range(1, SIZE):
            if kopia[y][x] in kropp and kopia[y - 1][x] == INK:
                px[y][x] = _ljusare(kopia[y][x])


def _ljusare(c: int) -> int:
    return {STONE: STONE_L, STONE_D: STONE, STONE_L: EDGE, EDGE: BONE, MORTAR: STONE_D,
            MOSS: SAND, SAND: BONE, BLOOD: RED, BLOOD_D: BLOOD, RED: ORANGE}.get(c, c)


def _mörkare(c: int) -> int:
    return {STONE: STONE_D, STONE_D: DARK, STONE_L: STONE, EDGE: STONE_L, BONE: SAND,
            MOSS: STONE_D, SAND: MOSS, BLOOD: BLOOD_D, RED: BLOOD, ORANGE: RED}.get(c, c)


## MARKSKUGGAN BOR I SPELET NU (M71). Den MÅLADES i rutans nederkant förut, och då följde den med
## figuren upp och ned när 3D-vyn andades med `spr.position.y` — Alex: *"en platta som åker upp och ned,
## det ser lite märkligt ut"*. Skuggan är en egen platta på golvet i `main.gd` (`_dropskugga`), en för
## varje fiende, och den ligger still medan figuren rör sig. Att rita den i rutan är alltså borttaget
## här, inte avstängt: två skuggor på samma fiende är en bugg som väntar.


def kanter(px) -> None:
    """Silhuettens trappsteg: varje konvext hörn i figuren får ETT dukpixel-steg i stället för ett
    helt block. Det är den här raden som gör att dubbelt duk läses som dubbel upplösning i stället
    för som samma figur i dubbel storlek — utan den är varje trappsteg 2x2 klossar, precis som förut.

    Regeln: ett blocks hörn-dukpixel tas bort när BÅDA grannblocken vid sidan om är tomma OCH
    diagonalblocket är tomt (ett konvext hörn). Är diagonalen fylld står pixeln kvar, för då håller
    den ihop en tunn diagonal — en varelse får inte falla i bitar av en kantputs (se `largest_blob`,
    som mäter exakt det). Ett RAKT hörn (ena grannblocket tomt, det andra fyllt) rörs inte: där
    finns ingen trappa att mjuka upp.
    """
    fylld = []
    for by in range(LOGISK + 2):
        rad = []
        for bx in range(LOGISK + 2):
            inne = 0 <= bx - 1 < LOGISK and 0 <= by - 1 < LOGISK
            if not inne:
                rad.append(False)
                continue
            x, y = (bx - 1) * S + OFFSET, (by - 1) * S + OFFSET
            mängd = sum(1 for dy in range(S) for dx in range(S) if px[y + dy][x + dx] != INK)
            rad.append(mängd * 2 > S * S)          # mer än hälften fylld = ett fyllt block
        fylld.append(rad)

    def f(bx: int, by: int) -> bool:
        return fylld[by + 1][bx + 1]

    for by in range(LOGISK):
        for bx in range(LOGISK):
            if not f(bx, by):
                continue
            for hx, hy in ((0, 0), (S - 1, 0), (0, S - 1), (S - 1, S - 1)):
                dx = -1 if hx == 0 else 1
                dy = -1 if hy == 0 else 1
                if f(bx + dx, by) or f(bx, by + dy) or f(bx + dx, by + dy):
                    continue
                px[by * S + OFFSET + hy][bx * S + OFFSET + hx] = INK


def squash(px, faktor: float) -> None:
    """Dödsrutan: figuren trycks ihop nedåt. Generellt pass, så varje kroppsform får en egen död."""
    kopia = [rad[:] for rad in px]
    ys = [y for y in range(SIZE) for x in range(SIZE) if kopia[y][x] not in (INK, MORTAR, DARK)]
    if not ys:
        return
    topp, botten = min(ys), max(ys)
    mål = botten
    for y in range(topp, botten + 1):
        ny = int(mål - (botten - y) * faktor)
        for x in range(SIZE):
            if kopia[y][x] != INK:
                px[ny][x] = kopia[y][x]      # direkt i duken: squash är ett dukpass, inte en figurdel
    # Töm raderna ovanför den ihopklämda figuren, annars står originalet kvar bakom.
    for y in range(SIZE):
        if y < mål - int((botten - topp) * faktor):
            for x in range(SIZE):
                if px[y][x] not in (INK,):
                    px[y][x] = INK


# --- kroppsformerna ------------------------------------------------------------------------
# Varje form ritar i 32x32 (sym() lägger på marginalen). Hållningen kommer ur POSES.

def skjut(px, lean: int) -> None:
    """Luta figuren: flytta HELA kroppen i sidled — efter ritning, aldrig inuti en speglad del.

    Rotorsaken till att sex figurer föll i bitar: `sym` speglar kring dukens mitt, så en förskjutning
    inuti den speglade rektangeln gav två halvor med en spricka emellan (mätt: skitterlingen hade en
    tvåpixlig öppning rakt genom kroppen, spänner-rutan 50 % sammanhang). Ett förskjutningspass löser
    alla sex kroppsformerna på ett ställe.
    """
    if not lean:
        return
    kopia = [rad[:] for rad in px]
    for y in range(SIZE):
        for x in range(SIZE):
            if kopia[y][x] not in (INK, MORTAR):
                px[y][x] = INK
    for y in range(SIZE):
        for x in range(SIZE):
            c = kopia[y][x]
            if c not in (INK, MORTAR):
                nx = x + lean
                if 0 <= nx < SIZE:
                    px[y][nx] = c


def öga(px, x: int, y: int, pupill: int = RED, glöd: int = AMBER, stor: int = 1) -> None:
    """Ögat: mörk håla med en ljus pupill i, och en ögonbrynsrad över.

    Mätt på bild: en pixel röd läste som "single-pixel horizontal eye slits provide minimal
    directional cues" — figuren fick inget ansikte och ingen riktning. Ett öga är det billigaste
    ansiktet som finns: hålan ger kontrast mot kroppen, pupillen ger blicken, brynet ger ilskan.
    """
    if stor >= 2:
        box(px, x - 1, y - 1, x + 2, y + 2, DARK)        # hålan
        box(px, x, y, x + 1, y + 1, pupill)              # pupillen
        put(px, x, y, glöd)                              # glimten
    else:
        box(px, x - 1, y - 1, x + 1, y + 1, DARK)
        box(px, x, y, x, y, pupill)
    box(px, x - 1, y - 2, x + (1 if stor >= 2 else 0), y - 2, DARK)   # brynet


def accent(px, c, p: dict) -> None:
    """Ritar fiendens accent. Kallas av formen efter kroppen, före ljus- och konturpassen.

    Hållningen styr bara andningen (`d`): vapnet ska sitta still i figuren medan kroppen rör sig,
    annars flaxar det. Lutningen läggs på hela figuren efteråt (skjut), så hugget tar vapnet med
    sig utan att accenten behöver veta vilken ruta den ritas i.

    Färgerna väljs på LJUSSTYRKA med indexet utskrivet, inte på namn: paletten utökades till 27
    färger av temavarvet, och konstanterna högst upp i filen stämmer inte längre med innehållet
    (BONE = 10 är numera mörkrött rgb(108,30,32), ORANGE = 15 är mossgrönt). Ett vapen ritat i
    "BONE" blev därför mörkt mot en mörk kropp — mätt i granskningen: "the shaft is one pixel wide
    and disappears against the black robe". 8 = benvit (226,220,208), 13 = orange (240,156,60),
    5 = mellangrå (92,84,98).
    """
    namn = p.get("accent")
    if not namn:
        return
    _, _, mörk = c
    VAPEN, SKAFT, HET = 8, 5, 13                                   # benvit / mellangrå / orange
    d = p["dy"] + p.get("dh", 0)
    if namn == "krona":
        for x in (11, 15):                                        # bandet ovanför huvudet
            sym(px, x, 5 + d, x, 5 + d, HET)
        sym(px, 12, 3, 12, 4, VAPEN)                              # yttre taggar (12 och 19)
        sym(px, 15, 2, 15, 3, VAPEN)                              # inre, högre (15 och 16)
    elif namn == "hornpar":
        for x, y in ((12, 9), (11, 8), (10, 7), (9, 6)):          # båge från huvudets kant och ut
            sym(px, x, y + d, x, y + d, VAPEN)
        sym(px, 8, 5 + d, 8, 5 + d, HET)                          # spetsen
    elif namn == "hammare":
        for i in range(11):                                       # skaftet: två pixlar brett
            put(px, 11 - i, 20 + d - i, SKAFT)
            put(px, 11 - i, 21 + d - i, SKAFT)
        box(px, 0, 8 + d, 3, 11 + d, VAPEN)                       # huvudet
        box(px, 1, 9 + d, 2, 10 + d, HET)
    elif namn == "lie":
        box(px, 7, 8 + d, 8, 26 + d, SKAFT)                       # stången står vid sidan om kroppen
        box(px, 8, 6 + d, 14, 7 + d, VAPEN)                       # bladet hakar in över huvudet
        put(px, 14, 5 + d, VAPEN)
        box(px, 9, 8 + d, 13, 8 + d, HET)                         # eggen
    elif namn == "sköld":
        box(px, 4, 14 + d, 9, 21 + d, VAPEN)                      # bara vänster sida: asymmetri
        box(px, 5, 16 + d, 7, 19 + d, SKAFT)                      # bucklan
        box(px, 6, 15 + d, 6, 20 + d, DARK)                       # ribban
        box(px, 9, 16 + d, 9, 18 + d, DARK)                       # remmen mot armen: ingen glipa
    elif namn == "armar":
        for y in (18, 21):                                        # två extra armar, nedåt och ut
            sym(px, 6, y + d, 8, y + 1 + d, mörk)
        sym(px, 4, 22 + d, 5, 23 + d, mörk)
        sym(px, 3, 24 + d, 3, 25 + d, VAPEN)                      # klor


def biped(px, c, p: dict) -> None:
    kropp, ljus, mörk = c
    d = p["dy"] + p.get("dh", 0)
    hx = 1 if p.get("bred") else 0
    sym(px, 12, 6, 15, 12 + d, ljus)                                 # huvud
    öga(px, 12, 9 + d, RED, AMBER, 2 if p.get("horn") else 1)
    öga(px, 19, 9 + d, RED, AMBER, 2 if p.get("horn") else 1)
    accent(px, c, p)                                                 # kronan/hornet/vapnet: identiteten
    sym(px, 10 - hx, 13 + d, 15, 18 + d, mörk)                       # överkropp
    sym(px, 10 - hx, 19 + d, 16, 25 + d, kropp)                      # kappa/bröst
    # Leddelningen: en mörk rad mellan arm och kropp. Armarna ritas intill överkroppen, och utan
    # skiljelinjen flyter de ihop till en klump (mätt på bild: "layered body parts blend together").
    for y in range(13 + d, 26 + d):
        put(px, 9 - hx, y, DARK)
        put(px, 22 + hx, y, DARK)
    # Armarna: 0 ned, 1 halvt upp, 2 rakt upp (spänner sig), 3 framåt (hugger).
    arm = p["armar"]
    if arm == 3:
        sym(px, 6 - hx, 15 + d, 9 - hx, 17 + d, mörk)
        sym(px, 6 - hx, 18 + d, 8 - hx, 19 + d, kropp)
    else:
        sym(px, 8 - hx, 16 + d - (2 if arm == 2 else (1 if arm == 1 else 0)), 10 - hx, 22 + d, mörk)
        if arm == 2:
            sym(px, 8 - hx, 11 + d, 10 - hx, 13 + d, mörk)
    if p.get("gap"):                                                 # gapet öppnas vid hugget
        box(px, 12, 11 + d, 15, 12 + d, INK)
    # Benen: huggrundan sätter ned foten, dödsrundan viker dem.
    ben = 26 + d
    box(px, 11, ben, 13, 29 + d, mörk)
    box(px, 18, ben, 20, 29 + d - (2 if p["armar"] == 3 else 0), mörk)


def crawler(px, c, p: dict) -> None:
    kropp, ljus, mörk = c
    upp = p["dy"]
    sym(px, 9, 12 - upp, 15, 21 - upp, kropp)                        # låg och bred kropp
    sym(px, 12, 10 - upp, 15, 12 - upp, ljus)                        # huvudplatta
    öga(px, 12, 13 - upp, RED, AMBER, 1)
    öga(px, 19, 13 - upp, RED, AMBER, 1)
    # Benen ritas som länkar FRÅN kroppen och ut. Första försöket satte lösa pixelpar med tre raders
    # mellanrum, och med spridda ben hamnade fötterna utan förbindelse med kroppen (mätt: verdigris
    # 77 % sammanhang). Ett ben ska sitta i kroppen, annars är det skräp i bilden.
    sprid = p["armar"] + (1 if p.get("gap") else 0)
    for i, y in enumerate((16, 19, 21)):
        för = 9 - i - sprid
        for x in range(9, för - 1, -1):
            put(px, x, y - upp, mörk)
        put(px, för, y + 1 - upp, mörk)
        put(px, för - 1, y + 1 - upp, mörk)
        bak = 22 + i + sprid
        for x in range(22, bak + 1):
            put(px, x, y - upp, mörk)
        put(px, bak + 1, y + 1 - upp, mörk)
        put(px, bak + 2, y + 1 - upp, mörk)


def hound(px, c, p: dict) -> None:
    kropp, ljus, mörk = c
    kropp_y = 14 - p["dy"]
    box(px, 7, kropp_y, 21, kropp_y + 5, kropp)                      # kroppen vågrätt
    box(px, 21, kropp_y - 2, 26, kropp_y + 3, ljus)                  # huvudet framtill
    # Halsen: en mörk rad mellan huvud och kropp. Utan den läser huvudet som en utväxt på kroppen.
    box(px, 21, kropp_y - 2, 21, kropp_y + 3, DARK)
    öga(px, 24, kropp_y, RED, AMBER, 1)
    if p.get("gap"):                                                 # gapet öppnas
        box(px, 23, kropp_y + 4, 27, kropp_y + 6, mörk)
        box(px, 24, kropp_y + 5, 26, kropp_y + 5, RED)
    else:
        box(px, 23, kropp_y + 4, 27, kropp_y + 4, mörk)
    skjut_ben = p["armar"]
    for i, x in enumerate((9, 13, 18, 21)):                          # fyra ben
        fram = skjut_ben if i >= 2 else -skjut_ben
        box(px, x + fram, kropp_y + 6, x + 1 + fram, kropp_y + 9, mörk)


def wisp(px, c, p: dict) -> None:
    kropp, ljus, mörk = c
    höjd = p["dy"] + p["armar"]
    # Lågan smalnar av upptill — en rak rektangel läses som en lykta, inte som en varelse. Bredden
    # ökades efter granskningen: vid 1-2 px var ljusen "thin spindle drones" utan massa, och en
    # fiende som inte har någon kropp att träffa går inte att läsa i strid.
    for i, y in enumerate(range(6, 17)):
        t = i / 10.0
        bredd = max(2, int(3 + 4 * (1 - t)))
        box(px, 16 - bredd, y - höjd, 15 + bredd, y - höjd, kropp)
    sym(px, 12, 10 - höjd, 15, 15 - höjd, ljus)
    sym(px, 13, 12 - höjd, 15, 14 - höjd, SAND)
    # Krage: en mörk rad där lågan möter kärnan. Utan den läses hela figuren som EN kon — mätt på
    # bild: "top-heavy funnel-like shapes blend together without distinct anatomy".
    for x in range(11, 21):
        put(px, x, 16 - höjd, (DARK if x % 2 else INK))
    svans = 1 if p["armar"] else 0
    for i, y in enumerate((17, 19, 21, 23)):
        x = 14 + (svans if i % 2 else -svans)
        for dx in (0, 1):
            put(px, x + dx, y - höjd, AMBER)
            put(px, x + dx, y + 1 - höjd, ORANGE)
    if p.get("gap"):                                                 # ett öppet gap i lågan
        box(px, 15, 13 - höjd, 16, 14 - höjd, INK)


def swarm(px, c, p: dict) -> None:
    kropp, ljus, mörk = c
    # Fyra TYDLIGA individer med inre skugga i stället för ett moln av prickar. Mätt på bild läste
    # molnet som "indistinct, shifting clusters" — en svärm behöver individer man kan räkna, annars
    # är den bara brus, och brus har ingen träffyta.
    vid = p["dy"] * 0.6 + p["armar"] * 0.25
    mitt = []
    for i, (dx, dy) in enumerate([(-6, -5), (3, -3), (-4, 4), (5, 6)]):
        x = int(15 + dx + (vid if dx > 0 else -vid))
        y = int(14 + dy + (vid if i % 2 else -vid))
        box(px, x, y, x + 4, y + 4, kropp)
        box(px, x + 1, y + 1, x + 3, y + 3, mörk)          # inre skugga = kontrast mot kroppen
        put(px, x + 2, y + 1, ljus)                        # en glimt per individ
        put(px, x + 2, y + 4, DARK)                        # glipan mot nästa
        mitt.append((x + 2, y + 2))
    # Länkarna: en mörk pixelrad mellan individerna. Utan dem mäter kontrollen "figuren hänger inte
    # ihop" (25 %) — och den har rätt, fyra lösa klumpar ÄR fyra figurer i bilden. Raden binder dem
    # till en svärm utan att ta bort glipan som gör individerna räkningsbara.
    for i in range(len(mitt) - 1):
        x0, y0 = mitt[i]
        x1, y1 = mitt[i + 1]
        längd = max(abs(x1 - x0), abs(y1 - y0), 1)
        for t in range(längd + 1):
            x = round(x0 + (x1 - x0) * t / längd)
            y = round(y0 + (y1 - y0) * t / längd)
            put(px, x, y, DARK)


def blob(px, c, p: dict) -> None:
    kropp, ljus, mörk = c
    vid = p["dy"]
    # Rundad massa: bredden följer en cosinuskurva över höjden och hålls minst tre pixlar. Går den
    # mot noll delas figuren i två och läses som två objekt i stället för en varelse.
    for y in range(8, 27):
        t = (y - 8) / 18.0
        bredd = max(3, int(3 + 9 * (1 - abs(t - 0.45) * 2.1)) + vid)
        box(px, 16 - bredd, y, 15 + bredd, y, kropp)
    box(px, 11, 9, 20, 11, ljus)                                     # ljus kant upptill
    gap = 1 + p["armar"]
    box(px, 12, 17, 19, 17 + gap, mörk)                              # gapet
    for x in (13, 16, 19):                                           # tänder
        put(px, x, 17, SAND)
    öga(px, 12, 13, AMBER, ORANGE, 2)
    öga(px, 19, 13, AMBER, ORANGE, 2)


FORMS = {"biped": biped, "crawler": crawler, "hound": hound, "wisp": wisp,
         "swarm": swarm, "blob": blob}


def form_for(enemy: dict) -> str:
    """Kroppsformen: den handSatta tabellen först, namnmatchningen som reserv för nya fiender."""
    eid = str(enemy.get("id", ""))
    if eid in FORMER:
        return FORMER[eid]
    namn = eid.lower()
    for ord_, form in ARCHETYPES:
        if ord_ in namn:
            return form
    return "biped"


def assignments(enemies: list[dict]) -> dict[str, dict]:
    """Dela ut färg OCH formvariation så att ingen i samma kroppsform får samma kombination."""
    ut: dict[str, dict] = {}
    grupper: dict[tuple, list[dict]] = {}
    for e in enemies:
        grupper.setdefault((form_for(e), int(e.get("tier", 1))), []).append(e)
    for (form, tier), grupp in grupper.items():
        n = len(RAMPER[tier])
        for i, e in enumerate(sorted(grupp, key=lambda x: str(x.get("id", "")))):
            ut[str(e["id"])] = {
                "färg": i % n,
                "dh": (i // n) % 2,
                "bred": ((i // (2 * n)) % 2) == 0,
            }
    return ut


ASSIGN: dict[str, dict] = {}


def colours(enemy: dict) -> tuple[int, int, int]:
    tier = int(enemy.get("tier", 1))
    val = ASSIGN.get(str(enemy.get("id", "")))
    if val is None:
        h = int(hashlib.sha256(f"{SEED}:{enemy.get('id', '')}".encode()).hexdigest()[:8], 16)
        val = {"färg": h % len(RAMPER[tier]), "dh": (h >> 3) % 2, "bred": (h >> 7) % 3 == 0}
    return RAMPER.get(tier, RAMPER[1])[val["färg"] % len(RAMPER.get(tier, RAMPER[1]))]


# INK (1) är BAKGRUNDEN. Låg den som kroppsfärg ritades de delarna osynliga — mätt: en boss blev
# ett huvud och en kappa med en tom rad emellan. Den mörka accenten är DARK (2), aldrig INK.
RAMPER: dict[int, list] = {
    1: [(STONE, EDGE, MORTAR), (STONE_D, STONE, DARK), (BLOOD_D, BLOOD, DARK), (MOSS, STONE_L, DARK)],
    2: [(STONE_L, BONE, DARK), (BLOOD, RED, BLOOD_D), (MORTAR, STONE, DARK), (MOSS, SAND, DARK),
        (STONE, EDGE, DARK), (BLOOD_D, ORANGE, DARK)],
    3: [(BLOOD, ORANGE, BLOOD_D), (STONE_D, STONE_L, DARK), (BLOOD_D, RED, DARK), (MOSS, AMBER, DARK),
        (MORTAR, EDGE, DARK), (STONE_L, SAND, DARK)],
}


def variant(enemy: dict) -> dict:
    """Per-fiende-variation: samma kroppsform ska inte bli fyra identiska figurer."""
    val = ASSIGN.get(str(enemy.get("id", "")))
    if val is None:
        h = int(hashlib.sha256(f"{SEED}:v:{enemy.get('id', '')}".encode()).hexdigest()[:8], 16)
        val = {"dh": (h >> 3) % 2, "bred": (h >> 7) % 3 == 0}
    namn = str(enemy.get("id", ""))
    return {
        "dh": val["dh"],
        "bred": val["bred"],
        "horn": any(w in namn for w in ("king", "sovereign", "mother", "reaper", "warden", "sentinel")),
        "accent": ACCENTER.get(namn, ""),
    }


def draw(enemy: dict) -> list[list[list[int]]]:
    """Alla sex rutorna för en fiende — bara figuren (markskuggan bor i spelet sedan M71).
    """
    form = FORMS[form_for(enemy)]
    boss = str(enemy.get("kind", "")) == "boss"
    v = variant(enemy)
    rutor = []
    for pose in POSES:
        px = blank()
        h = dict(v)
        h.update(pose)
        form(px, colours(enemy), h)
        # Silhuettens hörn putsas innan ljus och kontur: konturen ska följa den putsade formen, och
        # ljusets kantrad ska ligga på den. Hållningen rör inte hörnen (passet arbetar i block).
        kanter(px)
        # Lutningen läggs på EFTER figuren: skuggan stannar på golvet medan kroppen reser sig och
        # faller framåt. Det är hela poängen med ett eget pass. Lutningen kommer i logiska pixlar och
        # förskjutningen sker i duken, alltså gånger S — annars lutar figuren hälften så mycket.
        skjut(px, int(pose.get("lean", 0)) * S)
        if boss:
            ögon = int(enemy.get("eyes", 0))
            if ögon > 0:
                for i in range(ögon):
                    x = 12 + (i * 8) // max(1, ögon - 1) if ögon > 1 else 15
                    put(px, x, 10, RED)
        if pose.get("platt"):
            squash(px, float(pose["platt"]))
        light(px, 1.4 if pose.get("ljus") else 1.0)
        outline(px)
        rutor.append(px)
    return rutor


def skriv_ruta(img, x0: int, y0: int, pal, figur) -> None:
    """Skriv en ruta som RGBA: kroppen opak, INK genomskinlig.

    Rotorsaken till en svart ruta i korridoren: bilderna sparades som RGB, och INK är en FÄRG
    (nästan svart), inte genomskinlighet. Varje fiende blev då en opak 40x40-ruta med en varelse
    inuti — i ett mörkt rum läses den som en svart rektangel, inte som en fiende. Alfa är inte en
    kosmetisk detalj när figuren ska klippas in i en 3D-vy.
    """
    for y in range(SIZE):
        for x in range(SIZE):
            c = figur[y][x]
            if c != INK:
                img.putpixel((x0 + x, y0 + y), (pal[c][0], pal[c][1], pal[c][2], 255))
            else:
                img.putpixel((x0 + x, y0 + y), (0, 0, 0, 0))


# MATERIALPLANEN (M73): vad ytan ÄR, som andelar av figurens höjd (0,0 = topp, 1,0 = fot). Grovt med
# flit — det här är BAND, inte ytor, och de skrivs som en maskfil bredvid konsten:
#   R = våt (glansig, låg råhet), G = metall (metallisk, spegel), B = glas (kantljus), A = aura (emission)
# Banden duger för att döma MEKANISMEN i spelet. En riktig målning (en fläck på axeln, inte ett varv
# runt benet) görs i materialeditorn, och den skriver samma filformat.
MATERIAL: dict[str, dict] = {
    "copper_warden": {"metall": (0.0, 1.0)},
    "ossuary_king": {"metall": (0.0, 0.45)},
    "ash_sovereign": {"metall": (0.0, 0.55), "aura": (0.0, 0.22)},
    "mire_hound": {"våt": (0.45, 1.0)},
    "bone_wretch": {"våt": (0.55, 1.0)},
    "wax_sentinel": {"våt": (0.0, 1.0)},
    # ANDARNA (M74): auran ar en KANT langs silhuetten (se fiende_material.gdshader), inte en dimma
    # over kroppen. Bandet sager bara VAR kanten far sitta, och for en ande ar det hela figuren.
    # Alex: "Spokena ser ut som de angar, det skall bara vara minimal aura runtom som ger en kansla
    # av etheritet".
    "pale_reaper": {"aura": (0.0, 1.0)},
    "candlewisp": {"aura": (0.0, 1.0)},
    "salt_wretch": {"aura": (0.0, 1.0)},
    "bell_drowned": {"aura": (0.0, 1.0)},
    "hollow_choir": {"aura": (0.0, 1.0)},
}


def täckt_av_figur(figurer) -> list:
    """Silhuetten ur generatorns egen form: en pixel är täckt när den inte är INK."""
    return [[[figur[y][x] != INK for x in range(SIZE)] for y in range(SIZE)] for figur in figurer]


def täckt_av_png(fil) -> list:
    """Silhuetten ur Alex' egen PNG: alfakanalen.

    Hans konst äger bilden, men MASKEN är materialdata — den ska kunna skrivas för ett klippt eller
    handritat ark också. Utan den här vägen blev masken frusen i samma sekund som en fiende flyttade
    in i FRÅN_ALEX: generatorn hoppar över hans ark, alltså kunde ingen ny mask någonsin skrivas.
    """
    with Image.open(fil) as öp:
        ark = öp.convert("RGBA")
    w, h = ark.width // FRAMES, ark.height
    ut = []
    for ruta in range(FRAMES):
        alfa = ark.crop((ruta * w, 0, (ruta + 1) * w, h)).getchannel("A")
        ut.append([[bool(alfa.getpixel((x, y))) for x in range(w)] for y in range(h)])
    return ut


def material_mask(täckt: list, plan: dict) -> "Image.Image":
    """Masken: samma rutnät som konsten, en kanal per material.

    `täckt` är en ruta per bildruta med sant/falskt (figuren finns där). Källan är antingen
    generatorns egen form (`täckt_av_figur`) eller alfakanalen i Alex' PNG (`täckt_av_png`).

    Banden mäts på FÖRSTA rutans silhuett och gäller alla rutorna — mättes de per ruta skulle en
    skenbens våta fläck flytta sig upp till låret när figuren andas. Kanalen får en mjuk kant över
    6 % av figurens höjd, annars klipps glansen av som en tapetkant mitt på kroppen.
    """
    h = len(täckt[0])
    w = len(täckt[0][0])
    topp, botten = h, 0
    for y in range(h):
        for x in range(w):
            if täckt[0][y][x]:
                topp = min(topp, y)
                botten = max(botten, y)
    höjd = max(1, botten - topp)
    img = Image.new("RGBA", (w * FRAMES, h), (0, 0, 0, 0))
    for ruta in range(FRAMES):
        figur = täckt[ruta]
        for y in range(h):
            andel = (y - topp) / höjd
            v = [0, 0, 0, 0]
            for i, namn in enumerate(("våt", "metall", "glas", "aura")):
                band = plan.get(namn)
                if band is None:
                    continue
                a, b = float(band[0]), float(band[1])
                if a <= andel <= b:
                    kant = min(1.0, (andel - a) / 0.06, (b - andel) / 0.06)
                    v[i] = int(round(255 * max(0.0, min(1.0, kant))))
            if any(v):
                for x in range(w):
                    if figur[y][x]:
                        img.putpixel((ruta * w + x, y), (v[0], v[1], v[2], v[3]))
    return img


def write_all(pal) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    masker = 0
    for e in load_enemies():
        eid = e["id"]
        plan = MATERIAL.get(eid)
        if eid in FRÅN_ALEX:
            # HANS KONST ÄGER BILDEN, VI ÄGER MASKEN (M74). Masken är materialdata och följer HANS
            # silhuett (alfakanalen) — utan den här vägen kunde ingen fiende i FRÅN_ALEX någonsin få
            # en mask, och en ändrad MATERIAL-plan hade tyst gjort ingenting.
            fil = OUT_DIR / f"{eid}.png"
            if plan and fil.exists():
                material_mask(täckt_av_png(fil), plan).save(OUT_DIR / f"{eid}_mask.png")
                masker += 1
            continue
        figurer = draw(e)
        img = Image.new("RGBA", (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
        for frame, figur in enumerate(figurer):
            skriv_ruta(img, frame * SIZE, 0, pal, figur)
        img.save(OUT_DIR / f"{eid}.png")
        if plan:
            material_mask(täckt_av_figur(figurer), plan).save(OUT_DIR / f"{eid}_mask.png")
            masker += 1
    if masker:
        print("  %d materialmasker (R=våt G=metall B=glas A=aura)" % masker)
    print("  %d fiender -> %s (%dx%d, %d rutor, RGBA)" % (
        len(load_enemies()) - len(FRÅN_ALEX), OUT_DIR.relative_to(ROOT), SIZE * FRAMES, SIZE, FRAMES))


def sheet(pal) -> None:
    """Kontaktkarta: alla fiender, alla rutor — den gås igenom med ögonen, inte av koden.

    Två band per fiende: överst mot GOLVET (samma sten som korridoren) och under mot INK. Första
    versionen visade bara mot INK, som är nästan svart — och då dömdes mörka fiender som "low value
    contrast" mot en bakgrund de aldrig möter i spelet. Konturen är mörk, så golvet är det som
    avgör om silhuetten syns.
    """
    fiender = load_enemies()
    rader = len(fiender)
    band = SIZE + SIZE // 2 + 6
    bild = Image.new("RGB", (SIZE * FRAMES, band * rader), pal[STONE])
    for i, e in enumerate(fiender):
        topp = i * band
        # Nedre bandet ligger mot INK: där är bakgrunden fylld i förväg, så bara figuren ritas.
        for frame in range(FRAMES):
            for y in range(SIZE // 2):
                for x in range(SIZE):
                    bild.putpixel((frame * SIZE + x, topp + SIZE + 3 + y), pal[INK])
        for frame, (figur, mark) in enumerate(draw(e)):
            px = compose(figur, mark)
            for y in range(SIZE):
                for x in range(SIZE):
                    c = px[y][x]
                    if c == INK:
                        continue      # genomskinligt: STONE lyser igenom i övre bandet
                    bild.putpixel((frame * SIZE + x, topp + y), pal[c])
                    bild.putpixel((frame * SIZE + x, topp + SIZE + 3 + y // 2), pal[c])
    bild.save(SHEET_FILE)
    print("  kontaktkarta: %s (%d fiender x %d rutor, övre raden mot golv)" % (
        SHEET_FILE.relative_to(ROOT), rader, FRAMES))
    print("  rad 1-%d uppifrån: %s" % (rader, ", ".join(str(e["id"]) for e in fiender)))


def largest_blob(px) -> float:
    """Hur stor del av figuren som hänger ihop i ETT stycke (8-koppling, så diagonaler räknas).

    Det här är kontrollen som betyder något: en figur i två delar läses som två objekt. Täckning
    ensam ser det inte, och en tröskel på täckning hade fällt en tunn vålnad som ska vara tunn.
    """
    sedd = [[False] * SIZE for _ in range(SIZE)]
    synliga = sum(1 for rad in px for c in rad if c != INK)
    if synliga == 0:
        return 0.0
    störst = 0
    for y0 in range(SIZE):
        for x0 in range(SIZE):
            if px[y0][x0] in (INK, MORTAR) or sedd[y0][x0]:
                continue
            kö = [(x0, y0)]
            sedd[y0][x0] = True
            n = 0
            while kö:
                x, y = kö.pop()
                n += 1
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < SIZE and 0 <= nx < SIZE and not sedd[ny][nx]:
                            if px[ny][nx] != INK:
                                sedd[ny][nx] = True
                                kö.append((nx, ny))
            störst = max(störst, n)
    return störst / synliga


def check(pal) -> int:
    fel = 0
    for e in load_enemies():
        if e["id"] in FRÅN_ALEX:
            continue                      # Alex' egen konst: mäts av gen_enemy_sheet.py --check
        rutor = draw(e)
        problem = []
        färger = {c for px in rutor for rad in px for c in rad}
        utanför = sorted(c for c in färger if c < 0 or c >= len(pal))
        if utanför:
            problem.append("färger utanför paletten: %s" % utanför)
        synliga = sum(1 for rad in rutor[0] for c in rad if c != INK) / (SIZE * SIZE)
        samman = min(largest_blob(px) for px in rutor)
        # Rutorna måste SKILJA sig, och dödsrutan måste vara lägre än stå-rutan: annars är
        # animationen en gissning som råkar ha sex bildrutor.
        olika = sum(1 for y in range(SIZE) for x in range(SIZE)
                    if rutor[0][y][x] != rutor[3][y][x]) / (SIZE * SIZE)
        höjd_figur = lambda px: (max((y for y in range(SIZE) for x in range(SIZE)
                                      if px[y][x] != INK), default=0)
                                 - min((y for y in range(SIZE) for x in range(SIZE)
                                        if px[y][x] != INK), default=0))
        lägre = höjd_figur(rutor[5]) < höjd_figur(rutor[0]) if höjd_figur(rutor[0]) > 4 else True
        # Golvet ligger lågt med flit: det vaktar mot en formfunktion som ritar TOMT (0 %), inte mot
        # en tunn figur. Ett ljus är smalt — candlewisp ligger på 5 % och ska få göra det.
        if synliga <= 0.03:
            problem.append("figuren syns knappt (%.0f %%)" % (100 * synliga))
        if samman < 0.88:
            problem.append("figuren hänger inte ihop (%.0f %%)" % (100 * samman))
        if olika < 0.02:
            problem.append("stå- och huggrundan är samma bild")
        if not lägre:
            problem.append("dödsrundan är inte lägre än stå-rundan")
        if problem:
            fel += 1
        print("  %-16s %s  figur %.0f %%  sammanhang %.0f %%  olika %.1f %%  %s%s" % (
            e["id"], "ok " if not problem else "FEL", 100 * synliga, 100 * samman, 100 * olika,
            form_for(e), "" if not problem else "  <- " + "; ".join(problem)))
    return fel


def main() -> int:
    global ASSIGN
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="mät i stället för att skriva")
    ap.add_argument("--sheet", action="store_true", help="kontaktkarta att granska med ögonen")
    args = ap.parse_args()
    pal = load_palette()
    ASSIGN = assignments(load_enemies())
    if args.check:
        fel = check(pal)
        print("%d fiender ritade här (%d från Alex' ark), %d fel" % (
            len(load_enemies()) - len(FRÅN_ALEX), len(FRÅN_ALEX), fel))
        return 1 if fel else 0
    if args.sheet:
        sheet(pal)
        return 0
    write_all(pal)
    return 0


if __name__ == "__main__":
    sys.exit(main())
