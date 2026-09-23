#!/usr/bin/env python3
"""Rekvisitkonsten: kistan och spaden räknas fram här, inte laddas ner.

Alex: *"Den andra bilden vet jag inte vad det skall föreställa på golvet."* Han hade rätt — det som
låg på golvet var våningens noder (kistan, spaden, facklan), ritade som en 8x8 SCHACKRUTA i nodens
färg. En schackruta på 1-2 pixlar per ruta läses som salt-och-peppar-brus, inte som en sak, och i
brons ljusa sken såg spadens blekblå ruta ut som en grå hög av ingenting.

Samma skäl som för rutorna och fienderna: en sak ska vara en FORM. Filerna ligger i spelets palett,
med mörk kontur, och byggs av rektanglar, bågar och kanter — inte av slumpade pixlar.

**Dubbel pixelstorlek.** Väggarna går från 64 till 128 px per meter och rekvisiten följer med: varje
duk är ritad i 2x (kistan 32x24 -> 64x48, kedjefången 30x46 -> 60x92) så att rekvisitan har samma
pixeltäthet som väggen den hänger på. Det är inte koordinaterna som är dubblerade — vid 2x finns
plats för detaljer som inte fanns vid 1x: plankor i kistans lock, näsa/käke/tänder i skallen,
kedjelänkar som omväxlar framifrån/sidled, fler ben i högen, fler steg i elden och en brusten kant på
sprickan. Samma bild i dubbel storlek vore samma bild, inte skarpare.
OBS: `pixel_size` för rekvisiten står i game/main.gd och måste halveras samtidigt (0,016 -> 0,008),
annars blir saken dubbelt så stor i världen i stället för finare.

Konturen ritas FÖR HAND i varje form. Den gamla `_kontur()` letade efter `None` där duken har `0`,
hittade aldrig något och gjorde ingenting — död kod som såg ut som en livlina.

    python3 tools/gen_props.py            # skriver game/assets/props/*.png
    python3 tools/gen_props.py --check    # mäter: formen hänger ihop (inga lösryckta pixlar)
    python3 tools/gen_props.py --sheet    # kontaktkarta, att döma på bild
"""

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "game" / "assets" / "props"

# Palettens index (samma fil som rutorna och fienderna kvantiseras mot).
INK, DARK, MORTAR = 1, 2, 3
STONE_D, STONE, STONE_L, EDGE_L, PALE = 4, 5, 6, 7, 8
RED_D, RED, RED_L = 9, 10, 11
EMBER, FLAME, GLOW = 12, 13, 14
MOSS = 15
DIRT_D, DIRT, WOOD_L = 16, 17, 18
WOOD = 24          # tredje trätonen: kistans framsida, mörkare än locket
BONE, BONE_L = 22, 23

## JÄRNET. Rekvisiter som hänger i en vägg eller ett tak ritades i stenens egna toner: cuffs, ringar,
## kedjelänkar, stänger och nav stod i STONE_D/STONE/STONE_L/MORTAR. Mot grottans nya vägg (blockverk,
## hällar i CAVE_D/CAVE/CAVE_L) mättes de 22-27 palettsteg från väggens sten och 5-10 gråsteg i
## ljushet — mindre än väggens EGEN struktur (hällarna spänner 56-123 i ljushet), så buren och
## kandelabern försvann in i stenen och kvar syntes bara skelettet och ljuset. Färgen ÄR formen när
## bakgrunden är känd — samma läxa som kedjefångens bål, som var exakt markfärgen (se väggkedja).
##
## IRON (110,102,84) är den enda tonen i paletten som ligger långt från BÅDE väggens stenar (minst 56
## steg) och takets (81 steg): en bur hänger med kedjan mot taket och kroppen mot väggen, så en ton som
## bara skiljer sig från väggen försvinner i taket — DARK (26,22,32) ÄR takets sten och MORTAR ÄR
## väggens fog. IRON_MÖRK (58,42,32) är skuggsidan, EDGE_L den tända kanten och INK konturen.
IRON, IRON_MÖRK = 24, 16

# Rekvisiten som hänger i en VÄGG i stället för att stå på golvet. Kontaktkartan ger dem en
# stenbakgrund: mot golvfärgen försvinner den mörka bålen (mätt: "figuren försvinner på mitten"),
# och en bedömning mot fel yta är ingen bedömning.
VÄGG = ("väggkedja", "bur", "kandelaber", "spricka_eld")


class Duk:
    """En liten ritduk med palettindex. Allt ritas som SAMMANHÄNGANDE former — en pixel här och en
    där är precis vad schackrutan gjorde, och det är därför den inte gick att läsa."""

    def __init__(self, bredd: int, höjd: int) -> None:
        self.b, self.h = bredd, höjd
        self.px = [[0 for _ in range(bredd)] for _ in range(höjd)]

    def sätt(self, x: int, y: int, färg: int) -> None:
        if 0 <= x < self.b and 0 <= y < self.h:
            self.px[y][x] = färg

    def ruta(self, x0: int, y0: int, x1: int, y1: int, färg: int) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.sätt(x, y, färg)

    def ring(self, x0: int, y0: int, x1: int, y1: int, färg: int) -> None:
        """Bara kanten — används för konturen."""
        for x in range(x0, x1 + 1):
            self.sätt(x, y0, färg)
            self.sätt(x, y1, färg)
        for y in range(y0, y1 + 1):
            self.sätt(x0, y, färg)
            self.sätt(x1, y, färg)

    def båge(self, x0: int, y0: int, x1: int, y1: int, färg: int) -> None:
        """Överkanten av en rundad form: en cirkelbåge ritad pixel för pixel (kistan har lock)."""
        cx = (x0 + x1) / 2.0
        cy = y1 + 0.5
        r = (x1 - x0) / 2.0
        for x in range(x0, x1 + 1):
            if abs(x - cx) > r:
                continue
            y = int(round(cy - (r * r - (x - cx) ** 2) ** 0.5))
            self.sätt(x, y, färg)

    def fyll(self, x: int, y: int, färg: int) -> None:
        """Fyller ett slutet område från (x, y) — så att plankor och band hamnar innanför konturen."""
        mål = self.px[y][x]
        if mål == färg:
            return
        stack = [(x, y)]
        while stack:
            cx, cy = stack.pop()
            if not (0 <= cx < self.b and 0 <= cy < self.h) or self.px[cy][cx] != mål:
                continue
            self.px[cy][cx] = färg
            stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]

    def sträcka(self, x0: int, y0: int, x1: int, y1: int, färg: int) -> None:
        """En linje pixel för pixel (Bresenham) — benen i högen ligger i vinkel, inte rakt upp."""
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        fel = dx + dy
        while True:
            self.sätt(x0, y0, färg)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * fel
            if e2 >= dy:
                fel += dy
                x0 += sx
            if e2 <= dx:
                fel += dx
                y0 += sy


# ---------------------------------------------------------------- delade delar
#
# Skallen sitter i tre rekvisiter (benhögen, kedjefången, buren) och kedjelänken i tre (kedjefången,
# buren, kandelabern). Ritade en gång var, med parametern som enda skillnad — annars driver de isär
# och då ser samma skalle olika ut i samma spel.

def _ellips(d: Duk, cx: float, cy: float, rx: float, ry: float, färg: int) -> None:
    """Fylld ellips, RAD FÖR RAD — varje rad blir en sammanhängande sträcka i stället för en slinga
    av enstaka pixlar (vilket är precis vad grinden fäller på)."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        if not (0 <= y < d.h):
            continue
        u = (y - cy) / ry
        if abs(u) > 1.0:
            continue
        halv = rx * (1.0 - u * u) ** 0.5
        x0, x1 = int(round(cx - halv)), int(round(cx + halv))
        if x1 >= x0:
            d.ruta(x0, y, x1, y, färg)


def _ellips_ring(d: Duk, cx: float, cy: float, rx: float, ry: float, färg: int, tjock: int = 1) -> None:
    """Kanten av en ellips, `tjock` pixlar inåt. Konturen runt en RUND form: en rektangel runt en rund
    sak läses som en ram, och en ram runt en skalle läses som två lösa former. En 1 px ring runt en
    stor ellips blir gles (mätt: "cirkulära prickmönster") — därför går tjockleken att välja."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        if not (0 <= y < d.h):
            continue
        u = (y - cy) / ry
        if abs(u) > 1.0:
            continue
        halv = rx * (1.0 - u * u) ** 0.5
        x0, x1 = int(round(cx - halv)), int(round(cx + halv))
        for k in range(tjock):
            d.sätt(x0 + k, y, färg)
            d.sätt(x1 - k, y, färg)


def _skalle(d: Duk, cx: float, cy: float, r: float) -> None:
    """En skalle: hjässa, tinningar, ögonhålor, NÄSHÅLA, KÄKE och TÄNDER.

    Detaljen är ny för 2x — vid 1x var skallen en oval med två mörka rutor, och en oval med två rutor
    är en mask. Vid 2x finns plats för näshålan som egen kil, för en tandrad och för en underkäke som
    egen del. `r` är halva hjässans bredd i pixlar.

    Två rättningar efter bedömning: näsan och munnen låg först i samma mörka fält ("mask, skägg eller
    näbb"), och tänderna satt med 1 px mellanrum, vilket läses som en KAM — och gav enpixlade
    sträckor, som grinden mäter. Nu: 2 px tand med 2 px mörker emellan, och näshålan ovanför.
    """
    ix = int(round(cx))
    rx, ry = r, r * 0.94
    _ellips_ring(d, cx, cy, rx + 1, ry + 1, INK)
    _ellips(d, cx, cy, rx, ry, BONE)
    # Ljuset ligger i KANTEN (vänsterkanten, där ljuset faller in) — ett ljust band över pannan läses
    # som en mössa, och ett mörkt band över bröstet som ett brott.
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        u = (y - cy) / ry
        if abs(u) > 1.0:
            continue
        halv = rx * (1.0 - u * u) ** 0.5
        x0 = int(round(cx - halv))
        d.ruta(x0, y, x0 + max(1, int(r * 0.26)), y, BONE_L)
    # Ögonhålorna: ovala hål under pannbenet, inte rutor i mitten — och med ben emellan, så att de
    # inte flyter ihop med näsan (mätt: "ögonhålorna och näsan bildar en fjärilsform").
    for rikt in (-1, 1):
        _ellips(d, cx + rikt * r * 0.48, cy - r * 0.15,
                max(2.0, r * 0.30), max(2.0, r * 0.34), INK)
    # Näsan: en kil OVANFÖR munnen, med ben emellan.
    ny0, ny1 = int(round(cy + r * 0.08)), int(round(cy + r * 0.40))
    for y in range(ny0, ny1 + 1):
        t = (y - ny0) / max(ny1 - ny0, 1)
        halv = max(1, int(round(r * 0.05 + t * r * 0.17)))
        d.ruta(ix - halv, y, ix + halv, y, INK)
    # Tandraden: en mörk munhåla med 2 px tänder och 2 px mörker emellan.
    mun = max(4, int(r * 0.56))
    ty0 = int(round(cy + r * 0.62))
    th = max(3, int(round(r * 0.30)))
    d.ruta(ix - mun, ty0, ix + mun, ty0 + th, INK)
    for tx in range(ix - mun + 1, ix + mun - 1, 4):
        d.ruta(tx, ty0 + 1, tx + 1, ty0 + th, BONE_L)
    # Underkäken: en egen del under tandraden, smalare nedtill, med haklinje.
    ky0, ky1 = ty0 + th + 1, int(round(cy + r * 1.36))
    for y in range(ky0, ky1 + 1):
        t = (y - ky0) / max(ky1 - ky0, 1)
        halv = int(round(r * (0.56 - 0.22 * t)))
        d.ruta(ix - halv, y, ix + halv, y, BONE)
        d.ruta(ix - halv, y, ix - halv + 1, y, BONE_L)
        d.sätt(ix - halv - 1, y, INK)
        d.sätt(ix + halv + 1, y, INK)
    d.ruta(ix - int(r * 0.42), ky1 + 1, ix + int(r * 0.42), ky1 + 1, INK)


def _länk_fram(d: Duk, x: int, y: int) -> None:
    """En kedjelänk sedd framifrån: en 9x11 px RING med ett 4x6 px hål. Ett litet hål läses som en
    kloss med en prick i (mätt: "två platta rektanglar, som batteriikoner") — hålet är länken."""
    d.ruta(x + 1, y, x + 7, y + 9, IRON)
    d.ruta(x + 1, y, x + 2, y + 9, EDGE_L)
    d.ring(x, y, x + 8, y + 10, INK)
    d.ruta(x + 3, y + 3, x + 6, y + 7, INK)


def _länk_sida(d: Duk, x: int, y: int) -> None:
    """En kedjelänk sedd från sidan: en 5x6 px bygel. Omväxlingen framifrån/sidled är det som gör att
    en kedja läses som länkar — likadana klossar i rad är ett rör, hur många de än är."""
    d.ruta(x + 1, y, x + 3, y + 5, EDGE_L)
    d.ruta(x + 1, y + 1, x + 3, y + 4, IRON)
    d.ring(x, y, x + 4, y + 5, INK)


def _kedja(d: Duk, cx: int, y_botten: int, y_topp: int) -> None:
    """En kedja från `y_botten` och upp till `y_topp`, länk för länk. Två saker var fel först: länkarna
    satt med glapp emellan (mätt: "länkarna svävar fritt", "en pistol") och kedjan slutade några pixlar
    under fästet (mätt: "kedjorna är avhuggna"). Nu hakar varje länk i den förra och den översta
    ritas ända upp i fästet, även om taket skär av den."""
    botten = y_botten
    i = 0
    while botten > y_topp:
        h = 11 if i % 2 == 0 else 6
        if i % 2 == 0:
            _länk_fram(d, cx - 4, botten - h + 1)
        else:
            _länk_sida(d, cx - 2, botten - h + 1)
        botten -= h - 1
        i += 1


def _ben(d: Duk, x0: int, y0: int, x1: int, y1: int) -> None:
    """Ett ben i vinkel: en 4 px tjock pipa med mörk kant, ljus överkant och LEDER i båda ändar.

    Utan kontur flöt benen ihop till en grå massa (mätt: "en grötig massa, aska, smältande vax eller
    lera"), och utan leder är de pinnar. Båda delarna är vad som gör en hög av ben läsbar.
    """
    d.sträcka(x0, y0 - 1, x1, y1 - 1, INK)
    d.sträcka(x0, y0, x1, y1, BONE_L)
    d.sträcka(x0, y0 + 1, x1, y1 + 1, BONE)
    d.sträcka(x0, y0 + 2, x1, y1 + 2, INK)
    dx, dy = x1 - x0, y1 - y0
    längd = max((dx * dx + dy * dy) ** 0.5, 1.0)
    nx, ny = -dy / längd, dx / längd              # vinkelrät mot benet
    for ex, ey in ((x0, y0 + 1), (x1, y1 + 1)):
        for sida in (-1, 1):
            _ellips(d, ex + nx * 2.2 * sida, ey + ny * 2.2 * sida, 1.7, 1.5, BONE_L)


def _revben(d: Duk, cx: float, cy: float, vidd: float, djup: float) -> None:
    """Ett revben: en BÅGE från ryggraden och ut, som böjer nedåt, med mörk kant över och under.

    Raka band tvärs över en kropp läses som fristående bjälkar (mätt två gånger) — en båge läses som
    ett revben. Kanten är det som skiljer revbenet från benen bakom.
    """
    steg = max(2, int(vidd))
    for i in range(steg + 1):
        t = i / steg
        for rikt in (-1, 1):
            x = int(round(cx + rikt * vidd * t))
            y = int(round(cy + djup * t * t))
            d.sätt(x, y - 1, INK)
            d.sätt(x, y, BONE_L)
            d.sätt(x, y + 1, BONE)
            d.sätt(x, y + 2, INK)


def _låga(d: Duk, cx: int, y_botten: int, höjd: int = 13) -> None:
    """En låga: en droppe i tre steg utifrån och in. En jämn orange fläck läses som en lampa och en
    fyrkant som en blomlåda — en kandelaber känns igen på att lågorna har en topp."""
    for i in range(höjd):
        t = i / (höjd - 1.0)
        halv = max(0.9, (1.0 - t) ** 0.6 * 3.6)
        y = y_botten - i
        d.ruta(int(round(cx - halv)), y, int(round(cx + halv)), y, EMBER)
        if halv >= 2.0:
            d.ruta(int(round(cx - halv + 1)), y, int(round(cx + halv - 1)), y, FLAME)
        if halv >= 3.0 and t < 0.55:
            d.ruta(cx - 1, y, cx, y, GLOW)


def kista() -> Duk:
    """En kista med VÄLVT LOCK av plankor, järnband, lås och fötter (64x48 px).

    Vid 1x var locket en slät yta med två band på. Vid 2x finns plankorna i locket, fogarna i
    framsidan, banden som följer välvningen, hakens platta och nyckelhålet — det är den nya detaljen.

    Rättat efter bedömning: locket var lika brett som kroppen och läste som "bara ett lock som ligger
    på golvet" eller "en tunnel". Nu skjuter locket ut 4 px över kroppen, locket och framsidan har
    var sin träton, skuggan under locket är ritad, och kistan har en markskugga. Gångjärnen på
    lockets framkant och nitarna i banden ("två svävande klossar", "kuggspår") är borta.
    Ett LOCK är en tredjedel av kistan: är det lika högt som kroppen läses silhuetten som en ugn.
    """
    d = Duk(64, 48)
    lx0, lx1 = 4, 59                     # lockets kanter — det skjuter ut över kroppen
    bx0, bx1 = 8, 55                     # kroppens kanter
    topp, underkant, höjd = 10, 24, 10.0
    välvt = _välvning(lx0, lx1, topp, höjd)
    # Locket: välvt från kant till kant, med skuggan i välvningens kant (skuggning hör till kanten).
    for x, ystart in välvt.items():
        d.ruta(x, ystart, x, underkant, WOOD_L)
        d.ruta(x, ystart, x, ystart + 1, DIRT_D)
    kant = list(välvt)                                     # de yttre kolumnerna ligger i skuggan
    for x in kant[:4] + kant[-4:]:
        d.ruta(x, max(välvt[x], underkant - 3), x, underkant, DIRT_D)
    d.ruta(lx0, underkant - 3, lx1, underkant, WOOD)       # välvningen mörknar ned mot kanten
    d.ruta(lx0, underkant - 1, lx1, underkant, DIRT_D)     # lockets underkant, hela vägen
    for sx in (18, 32, 46):                                # plankfogarna följer välvningen
        d.ruta(sx, välvt[sx] + 3, sx + 1, underkant - 1, DIRT_D)
    # Kroppen: framsidan i en mörkare ton än locket, fogar, och skuggan locket kastar på den.
    d.ruta(bx0, 25, bx1, 43, WOOD_L)
    d.ruta(bx0, 25, bx1, 26, WOOD)                        # skuggan locket kastar på framsidan
    for sx in (18, 32, 46):
        d.ruta(sx, 27, sx + 1, 42, DIRT_D)
    d.ruta(bx0, 41, bx1, 43, DIRT_D)
    # Järnbanden följer välvningen ner över kanten — ett rakt band över ett välvt lock läses som ett
    # streck ovanpå kistan. 4 px: 1 px ljus kant, 3 px järn.
    for bx in (12, 48):
        for x in range(bx, bx + 4):
            for y in range(max(välvt[min(max(x, lx0), lx1)], topp), 42):
                d.sätt(x, y, EDGE_L if x == bx else MORTAR)
    # Låset mitt på framsidan, med haken upp i locket och nyckelhålet i plattan.
    d.ruta(31, 24, 34, 31, MORTAR)
    d.ruta(31, 24, 34, 24, EDGE_L)
    d.ruta(27, 31, 36, 42, INK)
    d.ruta(28, 32, 35, 41, EDGE_L)
    d.ruta(30, 33, 33, 40, MORTAR)
    d.ruta(31, 35, 32, 37, INK)                            # nyckelhålet
    d.ruta(30, 38, 33, 39, INK)
    # Fötterna: två klossar med öppet emellan, så att kistan står i golvet i stället för att flyta.
    for fx in (10, 46):
        d.ruta(fx, 44, fx + 7, 46, DIRT_D)
        d.ruta(fx, 44, fx + 7, 44, WOOD)
    # Markskuggan: ojämn, som under benhögen — en rak linje läses som en klistermärkeskant.
    for x in range(bx0, bx1 + 1):
        if _brus(x, 47, 9) < 0.7 or _brus(x - 1, 47, 9) < 0.7:
            d.sätt(x, 47, INK)
    # Konturen, för hand: över välvningen, längs lockets och kroppens sidor, under fötterna.
    for x, ystart in välvt.items():
        d.sätt(x, ystart - 1, INK)
    for y in range(välvt[lx0], underkant + 1):
        d.sätt(lx0 - 1, y, INK)
        d.sätt(lx1 + 1, y, INK)
    d.ruta(lx0 - 1, underkant + 1, lx0 + 1, underkant + 1, INK)
    d.ruta(lx1 - 1, underkant + 1, lx1 + 1, underkant + 1, INK)
    for y in range(underkant + 1, 44):
        d.sätt(bx0 - 1, y, INK)
        d.sätt(bx1 + 1, y, INK)
    for fx in (10, 46):
        for y in range(44, 47):
            d.sätt(fx - 1, y, INK)
            d.sätt(fx + 8, y, INK)
        d.ruta(fx, 47, fx + 7, 47, INK)
    return d


def spade() -> Duk:
    """En spade som står i golvet (32x64 px): T-handtag, skaft med tre tonlägen, holk med nitar och ett
    blad med fotstöd, egg och jord på.

    Tre rättningar efter bedömning: bladet var först en ellips ("en skål, en mätkopp"), sedan en jämnt
    avsmalnande trapets med rak botten ("en tratt, ett borr, en mejsel") — ett spadblad är brett
    upptill, har nästan raka sidor och slutar i en RUNDAD spets, vilket är en egen profil och inte en
    formel. Den breda vita högdagern längs hela vänsterkanten läses som en separat cylinder och är
    kortad till bladets övre del, och jordfläckarna ligger i kanten, i klumpar.
    """
    d = Duk(32, 64)
    # Skaftet: mörk kant, ljus mitt, mörk kant = en rund stång. Kornen ("hackig skuggning") är borta.
    for y in range(4, 39):
        d.sätt(11, y, INK)
        d.ruta(12, y, 13, y, DIRT_D)
        d.ruta(14, y, 16, y, WOOD_L)
        d.ruta(17, y, 18, y, DIRT_D)
        d.sätt(19, y, INK)
    # T-handtaget: en tvärslå med rundade ändar, inte en planka.
    d.ruta(8, 3, 23, 8, WOOD_L)
    d.ruta(9, 2, 22, 2, WOOD_L)
    d.ruta(8, 8, 23, 8, DIRT_D)
    d.ruta(8, 3, 23, 3, DIRT_D)
    d.ruta(7, 3, 7, 7, INK)
    d.ruta(24, 3, 24, 7, INK)
    d.ruta(8, 9, 23, 9, INK)
    d.ruta(9, 2, 22, 2, INK)
    d.ruta(6, 4, 6, 6, INK)
    d.ruta(25, 4, 25, 6, INK)
    # Holken: stålets fattning om skaftet, med två nitar.
    d.ruta(11, 39, 19, 43, STONE)
    d.ruta(11, 39, 19, 40, EDGE_L)
    d.ruta(11, 42, 19, 43, STONE_D)
    d.ruta(10, 39, 10, 43, INK)
    d.ruta(20, 39, 20, 43, INK)
    d.ruta(12, 41, 13, 42, MORTAR)
    d.ruta(17, 41, 18, 42, MORTAR)
    # Fotstöden: plattorna kängan trycker på, en pixel bredare än bladet.
    d.ruta(4, 44, 26, 45, STONE)
    d.ruta(4, 44, 26, 44, EDGE_L)
    d.sätt(3, 45, INK)
    d.sätt(27, 45, INK)
    # Bladet: en PROFIL, inte en formel. Brett upptill, raka sidor, rundad spets — och konturen sätts
    # rad för rad utanför eggen (en diagonal slinga gav en hackig krok vid spetsen).
    profil = [7, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 8, 8, 6, 4, 2]
    for i, halv in enumerate(profil):
        y = 46 + i
        d.sätt(15 - halv - 1, y, INK)
        d.sätt(15 + halv + 1, y, INK)
        d.ruta(15 - halv, y, 15 + halv, y, STONE_L)
        if i < 9:                                          # ljuset: bara i bladets övre del
            d.ruta(15 - halv, y, 15 - halv + 1, y, PALE)
        d.ruta(15 + halv - 1, y, 15 + halv, y, STONE)      # skuggan i högerkanten
    d.ruta(14, 63, 16, 63, INK)
    # Jorden: klumpar i kanten, tre pixlar breda — en 2x2 klump i mitten läses som en saknad pixel.
    d.ruta(7, 48, 9, 50, DIRT_D)
    d.ruta(8, 51, 9, 52, DIRT_D)
    d.ruta(20, 53, 22, 54, DIRT_D)
    for i, halv in enumerate(profil):                      # eggens kontur ända ner i spetsen
        y = 46 + i
        d.sätt(15 - halv - 1, y, INK)
        d.sätt(15 + halv + 1, y, INK)
    return d


def benhög() -> Duk:
    """Bossens märke: en skalle över en hög av ben (64x48 px).

    Fler ben och fler revben än vid 1x, med LEDER i ändarna och mörk kant — ben utan kontur flöt ihop
    till en grå massa ("en grötig massa, aska, lera") och ben utan leder är pinnar i ett staket.

    Rättat efter bedömning: den mörka tvärslån under skallen ("en hylla, en piedestal") är borta, den
    ojämna skuggan under hakan är borta (den gav enpixlade svarta prickar, som lästes som misstag),
    och skallen är mindre så att högen får plats.
    """
    d = Duk(64, 48)
    # Marken under högen, med OJÄMN skugga — en rak svart baslinje läses som en klistermärkeskant.
    for x in range(6, 58):
        if _brus(x, 45, 12) < 0.62 or _brus(x - 1, 45, 12) < 0.62:
            d.sätt(x, 45, INK)
            d.sätt(x, 46, INK)
    # Revbenen ligger underst i högen: bågar med mörk kant, inte bjälkar.
    # Benen, i olika vinkel och längd, med leder i ändarna.
    ben = [(12, 44, 28, 43), (34, 44, 52, 44), (10, 41, 26, 33), (48, 42, 57, 33),
           (26, 39, 44, 36), (20, 30, 44, 32)]
    for x0, y0, x1, y1 in ben:                    # det sista benet ligger under hakan
        _ben(d, x0, y0, x1, y1)
    # Revbenen läggs ÖVER benen, i en egen grupp till vänster: inne bland benen försvann de ("raka
    # horisontella spjälor"). En båge med krök läses som ett revben.
    for ry, vidd in ((29, 7), (32, 10), (35, 13)):
        _revben(d, 17, ry, vidd, 4.5)
    _ben(d, 8, 40, 8, 27)                                  # ryggraden: revbenen sitter i något
    # Skallen överst: med näsa, käke och tänder.
    _skalle(d, 30, 13, 10)
    return d


def väggkedja() -> Duk:
    """En stackare i kedjor på väggen, sedd rakt framifrån (60x92 px).

    Alex: *"på ena väggen skall det kunna sitta någon stackare fastspänd med kedjor"*. Läsningen kom
    efter tre rättningar: axlarna är bredast och kroppen smalnar av nedåt, armarna går från axlarna UPP
    till haken (samma pixel, annars hänger inget i något) och revbenen är borta — ett ljust band tvärs
    över bålen lästes som fristående bjälkar och ett mörkt som ett brott i kroppen.

    2x-rättningar efter bedömning: kedjan var EN länk ("en pistol") och nådde inte takringen ("kedjorna
    är avhuggna"), manschetterna hade kuggar ("borgmurar, hydrauliska kolvar"), händerna saknades
    ("armarna är avhuggna och instuckna i blocken") och fötterna hade en svart linje tvärs över, som
    gjorde dem till "kammar". Allt det är rättat.
    """
    d = Duk(60, 92)
    # Bålen är DIRT_D, inte DIRT. Första versionen ritade kroppen i DIRT — som är exakt markfärgen — och
    # då fanns det ingen kropp: bedömningen såg "ett fritt svävande huvud, lösa armar och ben" medan
    # benen (DIRT_D) syntes. Färgen ÄR formen när bakgrunden är känd.
    d.ruta(16, 40, 43, 52, DIRT_D)            # axlarna, bredast
    d.ruta(18, 53, 41, 65, DIRT_D)            # bröstkorgen
    d.ruta(22, 66, 37, 76, DIRT_D)            # midjan, smalare
    d.ruta(20, 77, 27, 90, DIRT_D)            # benen rakt ned
    d.ruta(32, 77, 39, 90, DIRT_D)
    # Skuggningen ligger i KANTEN: en ljus rand till vänster och längs axlarna, en mörk till höger.
    # Inget band över mitten — det var det som lästes som ett brott.
    for y0, y1, xa, xb in ((40, 52, 16, 43), (53, 65, 18, 41), (66, 76, 22, 37),
                           (77, 90, 20, 27), (77, 90, 32, 39)):
        d.ruta(xa, y0, xa + 2, y1, WOOD_L)
        d.ruta(xb - 1, y0, xb, y1, DIRT_D)
    d.ruta(16, 40, 43, 42, WOOD_L)            # axellinjen: nyckelbenen, inte ett band
    # Fötterna: benvita, med tår, och UTAN en svart linje tvärs över vristen (den gjorde dem till
    # kammar). Konturen går runt om, inte över.
    for fx in (19, 31):
        d.ruta(fx, 86, fx + 8, 90, BONE)
        d.ruta(fx, 86, fx + 8, 87, BONE_L)
        d.ruta(fx - 1, 86, fx - 1, 90, INK)
        d.ruta(fx + 9, 86, fx + 9, 90, INK)
        d.ruta(fx, 91, fx + 8, 91, INK)
        for tx in (fx + 2, fx + 6):
            d.ruta(tx, 88, tx, 90, DIRT_D)     # tår: 1 px skåra, samma ton som benet
    # Armarna är BARA och benvita: de skall gå att följa från axeln upp i manschetten, och mot en mörk
    # bål är det den ljusa armen som syns. Två pixlar brunt mot en brun kropp försvann helt.
    for x0 in (8, 45):
        d.ruta(x0, 34, x0 + 6, 47, BONE)
        d.ruta(x0, 34, x0 + 1, 47, BONE_L)
        d.ruta(x0 - 1, 34, x0 - 1, 47, INK)
        d.ruta(x0 + 7, 34, x0 + 7, 47, INK)
        _ellips(d, x0 + 3.5, 43, 3.6, 3.0, BONE_L)          # armbågen: en led, inte ett brott
    # Handlovsmanschetten: en slät järnring om armen, och HANDEN ovanför — annars ser armen avhuggen
    # ut där den går in i järnet (mätt).
    for kx in (4, 41):
        d.ruta(kx, 26, kx + 14, 34, IRON)
        d.ruta(kx, 26, kx + 14, 27, EDGE_L)
        d.ruta(kx, 33, kx + 14, 34, IRON_MÖRK)
        for y in range(26, 35):
            d.sätt(kx - 1, y, INK)
            d.sätt(kx + 15, y, INK)
        d.ruta(kx, 35, kx + 14, 35, INK)
    for hx in (7, 43):
        d.ruta(hx, 22, hx + 7, 29, BONE_L)                  # näven: griper om kedjan och manschetten
        for kx in (hx + 1, hx + 4, hx + 6):                 # knogarna: tre knölar överst
            d.ruta(kx, 21, kx + 1, 22, BONE)
        for y in range(21, 30):
            d.sätt(hx - 1, y, INK)
            d.sätt(hx + 8, y, INK)
        d.ruta(hx, 20, hx + 7, 20, INK)
        for fx in (hx + 3, hx + 6):
            d.ruta(fx, 25, fx, 29, DIRT_D)                  # fingrarna om länken
    # Taket: två järnringar med mörk kant, och kedjan ända upp i dem.
    for cx in (11, 48):
        _ellips_ring(d, cx, 4, 8, 5, IRON, 2)
        _ellips_ring(d, cx, 4, 8, 5, INK)
        _ellips(d, cx, 4, 5, 2, IRON)
        _kedja(d, cx, 25, 6)
    # Skallen, hängande framför bröstet: näsa, käke, tänder.
    _skalle(d, 30, 32, 9)
    return d


def bur() -> Duk:
    """En bur med ett skelett, hängande i taket (68x100 px).

    Alex: *"någonstans i taket skall en sån där bur med ett skelett hänga"*. Kedjan överst är smal
    (grinden kräver att toppraden är smalare än den bredaste) och buren är en tunna: två band, stänger
    emellan och en botten.

    2x-rättningar efter bedömning: kedjan var "två platta rektanglar med en pinne emellan" (nu ringar
    med 4x6 px hål) och satt inte fast i taket, banden var 1 px ellipser ("cirkulära prickmönster"),
    armslutets knölar såg ut som "teddybjörnsöron" och bäckenet var "en solid klump". Stängerna sitter
    nu i två plan: de inre bakom skelettet, de yttre framför.

    Järnet är IRON/IRON_MÖRK (se JÄRNET ovan): i stenens toner försvann buren in i grottväggen.
    """
    d = Duk(68, 100)
    # Takringen och kedjan ner till burens översta band.
    _ellips_ring(d, 34, 4, 8, 5, IRON, 2)
    _ellips_ring(d, 34, 4, 8, 5, INK)
    _ellips(d, 34, 4, 5, 2, IRON)
    _kedja(d, 34, 28, 6)
    # Lock och botten: två bågar, för en bur är rund och en rak kant läses som en låda.
    _ellips_ring(d, 34, 33, 21, 8, IRON, 2)
    _ellips_ring(d, 34, 86, 21, 8, IRON, 2)
    d.ruta(14, 33, 54, 34, IRON)
    d.ruta(14, 33, 54, 33, EDGE_L)
    d.ruta(14, 85, 54, 86, IRON)
    d.ruta(14, 86, 54, 86, EDGE_L)
    # Stängerna i bakersta planet: mörka, 5 px breda, 3 px glipa. Gliporna läses som mörker mellan
    # järn, vilket är hela poängen med en bur.
    for bx in (16, 24, 32, 40, 48):
        d.ruta(bx + 1, 34, bx + 3, 85, IRON_MÖRK)
        d.ruta(bx, 34, bx, 85, INK)
        d.ruta(bx + 4, 34, bx + 4, 85, INK)
    d.ruta(15, 32, 53, 32, INK)
    d.ruta(15, 87, 53, 87, INK)
    # Skelettet inuti: skalle med käke, revben som bågar, armar upp i översta bandet och ben ned.
    _skalle(d, 34, 45, 7)
    d.ruta(33, 57, 35, 71, BONE)              # ryggraden
    d.ruta(33, 57, 33, 71, BONE_L)
    for i in range(4):                        # revbenen
        _revben(d, 34, 60 + i * 4, 8 - i, 2.0)
    for rikt in (-1, 1):                      # bäckenet: två ben med en glipa emellan
        _ellips(d, 34 + rikt * 4, 74, 4.5, 3.0, BONE)
        _ellips(d, 34 + rikt * 4, 73, 4.5, 1.5, BONE_L)
    for rikt in (-1, 1):                      # armarna upp mot översta bandet
        x_end = 25 if rikt < 0 else 43
        d.sträcka(34 + rikt * 5, 59, x_end, 40, BONE)
        d.sträcka(34 + rikt * 5, 60, x_end, 41, BONE_L)
        d.ruta(x_end - 1, 37, x_end + 1, 40, BONE)        # handen om bandet
        d.ruta(x_end - 1, 36, x_end + 1, 36, BONE_L)
        d.ruta(x_end - 2, 36, x_end + 2, 36, INK)
    for rikt in (-1, 1):                      # benen ned mot botten
        x_end = 28 if rikt < 0 else 40
        d.sträcka(34 + rikt * 4, 76, x_end, 83, BONE)
        d.ruta(x_end - 2, 82, x_end + 2, 85, BONE)
        d.ruta(x_end - 2, 82, x_end + 2, 82, BONE_L)
        d.ruta(x_end - 3, 86, x_end + 3, 86, INK)
    # Främre stängerna, ritade SIST: de två yttersta ligger framför skelettet, så att buren har ett
    # fram- och ett bakplan i stället för att vara "två spjälväggar på sidorna" (mätt).
    for bx in (16, 48):
        d.ruta(bx + 1, 34, bx + 3, 85, IRON)
        d.ruta(bx + 1, 34, bx + 2, 85, EDGE_L)
        d.ruta(bx, 34, bx, 85, INK)
        d.ruta(bx + 4, 34, bx + 4, 85, INK)
    return d


def kandelaber() -> Duk:
    """En kandelaber i taket, sedd underifrån (88x52 px).

    Alex: *"det skall kunna hända kandelaber i taket"*. Första försöket var en fyrkantig ram med ett
    kryss i och lästes som *"en gallerplatta"*: underifrån ser man navet, armarna och lågorna. Kedjan
    upp i taket säger att saken hänger, och varje arm slutar i en stake med en låga.

    2x-rättningen: en 1 px mörk linje tvärs över staken skar av ljuset från staken, och bedömningen
    såg "två ljus som svävar mitt på korsande stänger och två tomma socklar". Ljuset står nu i en skål
    på staken, och kedjan hakar i navet och går upp i takringen.

    Järnet är IRON/IRON_MÖRK (se JÄRNET ovan). Kandelabern sitter i TAKET, och takets stenar är de
    mörkaste i grottan (INK/CAVE_D/DARK): järnet måste skilja sig från både tak och vägg, och det gör
    bara den varma tonen — DARK och MORTAR ÄR takets respektive väggens egna toner.
    """
    d = Duk(88, 52)
    _ellips_ring(d, 44, 4, 8, 4, IRON, 2)
    _ellips_ring(d, 44, 4, 8, 4, INK)
    _kedja(d, 44, 24, 6)
    # Navet: mörk kant, kanneler, knopp i mitten.
    d.ruta(36, 24, 51, 39, INK)
    d.ruta(37, 25, 50, 38, IRON)
    d.ruta(38, 26, 49, 37, IRON_MÖRK)
    for kx in (40, 44, 48):
        d.ruta(kx, 27, kx + 1, 36, IRON)
    d.ruta(42, 29, 45, 33, EDGE_L)
    d.ruta(43, 30, 44, 32, PALE)
    # Armarna: 4 px järn med ljus rygg, från navet och ut till varje stake. Alla först.
    för = [(9, 32), (78, 32), (22, 48), (65, 48)]
    for ax, ay in för:
        d.sträcka(38, 36, ax, ay, IRON_MÖRK)
        d.sträcka(38, 35, ax, ay - 1, IRON)
        d.sträcka(38, 34, ax, ay - 2, EDGE_L)
    # Stakarna, ljusen och lågorna sist, så att de står FRAMFÖR armen: en cylinder skymmer det som
    # ligger bakom. Skålen är en skål — inte en linje tvärs över ljusets fot.
    for ax, ay in för:
        d.ruta(ax - 6, ay, ax + 6, ay + 3, IRON)           # foten
        d.ruta(ax - 6, ay, ax + 6, ay, EDGE_L)
        d.ruta(ax - 6, ay + 4, ax + 6, ay + 4, INK)
        d.ruta(ax - 3, ay - 3, ax + 3, ay - 1, IRON)       # stakens hals
        for y in range(ay - 3, ay):                        # halsens kanter: syns mot stenväggen
            d.sätt(ax - 4, y, INK)
            d.sätt(ax + 4, y, INK)
        d.ruta(ax - 5, ay - 5, ax + 5, ay - 4, EDGE_L)     # skålen, bredare än halsen
        d.sätt(ax - 6, ay - 4, INK)
        d.sätt(ax + 6, ay - 4, INK)
        d.ruta(ax - 2, ay - 15, ax + 2, ay - 5, PALE)      # ljuset står i skålen
        d.ruta(ax + 3, ay - 15, ax + 3, ay - 5, DIRT_D)    # skuggan i ljusets kant
        _låga(d, ax, ay - 16, 13)
    return d


def spricka_eld() -> Duk:
    """En spricka i väggen med eld bakom (64x68 px).

    Alex: *"det skall vara sprickor i en vägg där man kan se eld i bakgrunden"*.

    Fem rättningar, och de två sista var de avgörande. (1) Elden låg i koncentriska steg runt varje rad
    och kanten hade en 3-4 px ram per rad: *"horisontella lameller, som scanlines"*. (2) 1 px färgband:
    grinden fällde (1,6 px sträcka). (3) Eldtungor i en ljus, stor öppning: *"en virvel, en portal"*.
    (4) Mörk klyfta med glödbädd: fortfarande *"en mörk energivirvel, en portal"*, med *"alla utstickare
    strikt horisontella linjer"*. Det sista felet satt i RYGGEN: en mjukt slingrande kant ger ett streck
    som flyttar sig någon pixel per rad, och det läses som rörelse (virvel). En spricka i sten går i
    RAKA STYCKEN med olika brant och skarpa riktningsbyten, är smal (3 px) utom vid de ställen där den
    öppnar sig, och glöden finns bara där elden syns — inte som en rand längs hela sprickan.
    Rekvisitan skall dömas mot en VÄGG: den sitter i en väggruta i spelet.
    """
    d = Duk(64, 68)
    # Ryggraden: sex raka stycken, interpolerade rad för rad, med ett steg brus (±1 px).
    bryt = [(2, 28), (13, 34), (21, 25), (33, 37), (45, 28), (55, 36), (66, 31)]
    def rygg(y: int) -> float:
        for (y0, x0), (y1, x1) in zip(bryt, bryt[1:]):
            if y0 <= y <= y1:
                t = (y - y0) / max(y1 - y0, 1)
                return x0 + (x1 - x0) * t
        return bryt[-1][1]

    # Öppningarna: där elden syns är sprickan vid (halv vidd i px), annars är den en smal klyfta.
    öppning = {}
    for y in range(2, 67):
        halv = 1
        for (o0, o1) in ((9, 17), (26, 35), (44, 51), (57, 65)):
            if o0 <= y <= o1:
                t = 1.0 - abs((y - (o0 + o1) / 2.0) / ((o1 - o0) / 2.0))
                halv = 1 + int(round(t * 4.0))
        öppning[y] = halv
    glöd = set()
    for g0, g1 in ((8, 19), (28, 37), (44, 54), (60, 65)):
        glöd.update(range(g0, g1 + 1))
    for y in range(2, 67):
        x = int(round(rygg(y) + (_brus(3, y, 11) - 0.5) * 2.0))
        halv = öppning[y]
        if halv <= 1:
            # Den smala klyftan: 3 px mörker, stenens BRUSTNA kant (2 px) på ena sidan och glöden
            # (2 px) på den andra. Kanten ger väggen tjocklek — utan den ligger sprickan "ovanpå"
            # väggen (mätt) — och glöden sitter bara på ett stycke i taget, inte längs hela sprickan.
            d.ruta(x - 1, y, x + 1, y, INK)
            d.ruta(x - 4, y, x - 2, y, STONE_D)            # stenens brutna kant, samma sida
            if y in glöd:                                  # glöden läcker ut där elden är
                d.ruta(x + 2, y, x + 3, y, RED_D)
            else:
                d.ruta(x + 2, y, x + 4, y, STONE_D)
        else:
            d.ruta(x - halv, y, x + halv, y, INK)
            d.ruta(x - halv, y, x - halv + 1, y, RED_D)
            d.ruta(x + halv - 1, y, x + halv, y, RED_D)
            if halv >= 3:
                c = x + int(round((_brus(7, y, 17) - 0.5) * 2.0))
                d.ruta(c - 1, y, c + 1, y, EMBER)
                if halv >= 4 and y > 24:
                    d.ruta(c - 1, y, c, y, FLAME)
    # Glödbädden nederst: där elden står.
    for y in range(58, 65):
        x = int(round(rygg(y) + (_brus(3, y, 11) - 0.5) * 2.0))
        d.ruta(x - 2, y, x + 2, y, EMBER)
        d.ruta(x - 1, y, x + 1, y, FLAME)
        if y > 61:
            d.ruta(x - 1, y, x, y, GLOW)
    # Brutna stenflisor i kanten och grenar som sitter FAST i sprickan (lösa grenar i tomma luften var
    # spindelbenen i första försöket).
    for y, sida in ((13, -1), (24, 1), (33, -1), (46, 1), (52, -1)):
        x = int(round(rygg(y)))
        px = x - 5 if sida < 0 else x + 4
        d.ruta(px, y, px + 1, y, STONE_D)
        d.ruta(px, y + 1, px + 1, y + 1, STONE_D)
    for by, sida, längd, brant in ((14, -1, 9, 1.6), (25, 1, 7, 2.2), (47, -1, 8, 1.4),
                                   (57, 1, 6, 1.9)):
        x = int(round(rygg(by))) + (sida * 2)
        for steg in range(längd):
            y = by - int(round(steg * brant))
            if not (2 <= y <= 66):
                break
            d.ruta(x, y, x + 3, y, INK)                 # grenen: 4 px, mörk med glöd inuti
            d.ruta(x + 1, y, x + 2, y, RED_D)
            x += sida
    return d


# ---------------------------------------------------------------- dekoration (M84)
#
# Saker i miljön som inte ska ha någon kollision men ändå ge rummet liv: gräs i springorna, rötter,
# mossa, småsten. Alex: *"Hur ser vi på möjlighet att skapa t ex gräs, rötter, andra saker i miljön
# som inte skall ha någon collision, men bidrar till mer... känsla?"*
#
# De ritas här i samma palett och samma täthet (128 px per meter) som rekvisiten, men de blir inga
# noder: `_bygg_dekor` i game/main.gd lägger dem som instanser i EN MultiMesh per art. En MultiMesh
# har ingen fysik alls, så "ingen kollision" är en EGENSKAP och inte en flagga någon kan glömma.
#
# Färgerna är valda ur paletten och inte på känsla: MOSS (15) är den enda gröna, BONE (22) den torra
# stråtoppen, DIRT/DIRT_D/WOOD_L (16-18) rötterna och stenen ur STONE-serien.

def _kontur(d: Duk, färg: int = INK) -> None:
    """Mörk kant runt formen. Grinden kräver den: en sak utan kontur flyter in i golvet den står på —
    samma regel som rekvisiten, och den gäller ännu mer för en tuva som är tunn."""
    for y in range(d.h):
        for x in range(d.b):
            if d.px[y][x] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < d.b and 0 <= ny < d.h and d.px[ny][nx] != 0:
                    d.sätt(x, y, färg)
                    break


def gräs() -> Duk:
    """En tuva torrt gräs, 16x26: en klump vid marken och blad som böjer sig ur den.

    Klumpen är inte dekoration: grinden mätte sträckan 1,2 px på en tuva av bara 2 px breda blad —
    "formen är brus" — och en tuva ÄR en klump med strån ur, inte sex lösa hårstrån. Basen ger rader
    med sammanhängande färg och tuvan läses som en sak."""
    d = Duk(16, 26)
    # SILHUETTEN ÄR EN KLUMP, inte sex strån: grinden mätte sträckan 1,2 px hur jag än breddade bladen,
    # eftersom varje 2 px brett strån fick en egen kant emellan. En tuva gräs vid 128 px per meter ÄR
    # en klump med en taggig överkant — bladen sitter ihop nedtill och kanten ligger bara runt om.
    toppar = {2: 17, 6: 8, 7: 7, 10: 4, 12: 13}
    for x, topp in toppar.items():
        d.ruta(x, topp, x + 3, 25, MOSS)
    # Den torra toppen: de högsta stråna, i BONE.
    for x, topp in toppar.items():
        if topp < 12:
            d.ruta(x, topp, x + 3, topp + 1, BONE)
    _kontur(d)
    return d


def rot() -> Duk:
    """En rot som vuxit fram ur en springa, 26x10 — välvd överkant, mörk undersida.

    Färgerna är WOOD_L/DIRT_D och inte DIRT: grinden mätte att 52 % av kroppen låg i DIRT (17), som är
    en av GOLVETS egna toner — roten hade alltså försvunnit i golvet den ligger på."""
    d = Duk(26, 10)
    for x in range(0, 26):
        y = 7 - int(round(2.0 * (1.0 - abs(x - 13) / 13.0)))
        d.ruta(x, y, x, 9, WOOD_L)
        d.sätt(x, y, WOOD_L)
        d.sätt(x, 9, DIRT_D)
    for x, upp in ((4, 3), (12, 4), (20, 2)):
        for i in range(upp):
            d.sätt(x, 6 - i, DIRT_D)
            d.sätt(x + 1, 6 - i, DIRT_D)
    _kontur(d)
    return d


def mossa() -> Duk:
    """En mossfläck, 18x8: en låg kudde med ojämn överkant."""
    d = Duk(18, 8)
    for x in range(1, 17):
        topp = 3 + int(round(1.6 * (1.0 - abs(x - 9) / 8.0))) + (1 if (x * 5) % 7 < 2 else 0)
        d.ruta(x, topp, x, 7, MOSS)
        if x % 3 == 0:
            d.sätt(x, topp, DIRT_D)
    d.ruta(0, 6, 0, 7, DIRT_D)
    d.ruta(17, 6, 17, 7, DIRT_D)
    _kontur(d)
    return d


def småsten() -> Duk:
    """Tre stenar i en springa, 12x7 — grus, inte en mur.

    Stenarna ligger mot varandra: grinden mätte sträckan 1,2 px när de stod lösa med var sin kontur,
    och tre enstaka stenar med en kant var är tre prickar. En liten hög är en sak."""
    d = Duk(12, 7)
    for cx, cy, r in ((3, 4, 3), (8, 5, 3)):
        for y in range(cy - r, cy + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 1:
                    d.sätt(x, y, STONE_L if y <= cy - r + 1 else STONE)
    d.sätt(3, 5, STONE_D)
    d.sätt(7, 4, STONE_D)
    _kontur(d)
    return d


FORMER = {"chest": kista, "shovel": spade, "boss": benhög,
          "väggkedja": väggkedja, "bur": bur, "kandelaber": kandelaber, "spricka_eld": spricka_eld,
          "gräs": gräs, "rot": rot, "mossa": mossa, "småsten": småsten}


def _välvning(x0: int, x1: int, topp: int, höjd: float) -> dict:
    """Lockets välvning: hur långt ner varje kolumn börjar. En ELLIPS över hela bredden — toppen i
    mitten och kanterna en höjd ner, så locket välver sig från kant till kant.

    Första försöket använde välvningsradien som horisontell radie, och då blev de yttre kolumnerna
    platta medan mitten reste sig: en kulle i en låda (vision: "en ugn eller en port")."""
    cx = (x0 + x1) / 2.0
    halv = max((x1 - x0) / 2.0, 1.0)
    ut = {}
    for x in range(x0, x1 + 1):
        u = min(abs(x - cx) / halv, 1.0)
        ut[x] = topp + int(round(höjd * (1.0 - (1.0 - u * u) ** 0.5)))
    return ut


def _brus(x: int, y: int, frö: int) -> float:
    """Deterministiskt brus i [0,1) — samma frö ger samma bild varje gång (allt annat vore ett prov
    som bara ibland fäller)."""
    n = (x * 374761393 + y * 668265263 + frö * 2246822519) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65536.0


def _grannar(px, x, y, färg) -> int:
    """ÅTTA grannar, inte fyra: en diagonal kontur (en trappa av enpixlade steg) hänger ihop diagonalt,
    och med fyra grannar räknades varje sådan pixel som lösryckt. Schackrutan är fortfarande lösryckt
    hur man än räknar — varannan pixel har samma färg två steg bort."""
    n = 0
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            if 0 <= y + dy < len(px) and 0 <= x + dx < len(px[0]) and px[y + dy][x + dx] == färg:
                n += 1
    return n


## Rekvisiten som är FÖREMÅL framför en yta. spricka_eld är inte ett: den ÄR väggen — sprickans kanter
## ska vara sten, och elden i den är formen.
HÄNGER = ("väggkedja", "bur", "kandelaber")

## Ytans DOMINERANDE toner: de som täcker minst så här stor del av rutan. Fogar och 1-2 px linjer faller
## bort (grottans väggfog är 16 % av rutan) — en kropp som möter fogen möter en linje, inte en yta.
## Tonerna läses ur rutorna själva och inte ur en hårdkodad lista: byter ytorna ton följer grinden.
YTANDEL = 0.20

## Hur långt ifrån (palettsteg) kroppen måste ligga ytans toner, och hur stor del av kroppen som får
## ligga närmare. Mätt: järnet i stenens egna toner låg 8-25 steg från väggens stenar och var 42 % av
## kroppen — buren och kandelabern försvann in i väggen. Med järnet i IRON/IRON_MÖRK ligger 0 % av
## kroppen inom 30 steg, och en kropp som LÄSES mot samma ytor (kedjefångens bål i DIRT_D) låg 38 steg
## bort. 30 steg och 15 % fångar det första och släpper det andra.
KONTRAST = 30.0
DOLD = 0.15


def _yttoner() -> list[int] | None:
    """Toner (≥ YTANDEL av rutan) för de ytor de hängande rekvisiten ses mot: grottans vägg och tak.

    Samma väg till rutorna som kontaktkartan (se _väggruta) — generatorn, inte en kopia av den. Går
    den inte att importera hoppas mätningen över i stället för att fällas: en grind som kräver ett
    helt verktygsträd mäter verktygsträdet, inte konsten.
    """
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import gen_tiles as tiles
        rader = tiles.TEMA["grotta"]["wall"]() + tiles.TEMA["grotta"]["ceiling"]()
    except (ImportError, OSError, KeyError):
        return None
    antal: dict[int, int] = {}
    for rad in rader:
        for c in rad:
            antal[c] = antal.get(c, 0) + 1
    n = sum(antal.values())
    return [c for c, k in antal.items() if k >= YTANDEL * n]


def check(pal: list[tuple[int, int, int]]) -> int:
    """Fäller på det som gjorde markörerna oläsbara: lösryckta pixlar, en fyrkantig silhuett och
    färger utanför paletten. Fäller också på markfärgen: en kropp i samma färg som ytan den hänger på
    försvinner helt (kedjefångens bål var DIRT, alltså exakt markfärgen, och bedömningen såg "ett
    fritt svävande huvud, lösa armar och ben"). Samma sak mot väggen och taket: se ytkontrasten.
    """
    fel = 0
    yttoner = _yttoner()
    for namn, bygg in FORMER.items():
        d = bygg()
        färger = {c for rad in d.px for c in rad} - {0}
        utanför = sorted(c for c in färger if c < 0 or c >= len(pal))
        # LÖSRYCKTA PIXLAR: en pixel med färre än två grannar av samma färg är ett ensamt sandkorn.
        # En schackruta har fyra — alla fyra pixlarna är ensamma. Det här är kontrollen som hade
        # fångat markörerna som Alex inte kände igen.
        fyllda = sum(1 for y in range(d.h) for x in range(d.b) if d.px[y][x] != 0)
        # STRÄCKLÄNGDEN: hur långa sammanhängande partier av samma färg en rad har. En schackruta har
        # 1,0 (varje pixel byter färg), en ritad form har närmare tre. Det här är måttet som skiljer
        # "en form" från "brus" — 8-grannar gjorde schackrutan sammanhängande och lurade mig först.
        sträckor = []
        for rad in d.px:
            längd = 0
            förra = 0
            for c in rad:
                if c == INK or förra == INK:      # konturen får vara 1 px — den är en kontur
                    förra = c
                    längd = 1
                    continue
                if c == förra and c != 0:
                    längd += 1
                else:
                    if förra != 0:
                        sträckor.append(längd)
                    längd = 1
                förra = c
            if förra != 0:
                sträckor.append(längd)
        medel_sträcka = sum(sträckor) / max(len(sträckor), 1)
        ensamma = sum(1 for y in range(d.h) for x in range(d.b)
            if d.px[y][x] != 0 and _grannar(d.px, x, y, d.px[y][x]) == 0)
        andel = ensamma / max(fyllda, 1)
        # MARKFÄRGEN: en rekvisit får inte ha sin kropp i samma färg som ytan den står på.
        mark = sum(1 for rad in d.px for c in rad if c == DIRT)
        andel_mark = mark / max(fyllda, 1)
        rader = [sum(1 for c in rad if c != 0) for rad in d.px]
        aktiva = [r for r in rader if r > 0]
        # Toppraden ska vara SMALARE än den bredaste raden: en sak har en form (ett välvt lock, ett
        # handtag, en spets). En platta har samma bredd hela vägen — schackrutan hade det.
        topp = rader.index(max(aktiva)) > 0 or rader[0] < max(aktiva)
        # Kontur: den mörkaste färgen ska finnas, annars flyter saken in i golvet.
        har_kontur = INK in färger
        print("  %-7s %2dx%-2d  färger %2d/%d  fyllda %3d  sträcka %.1f px  radbredd %d-%d  "
              "mark %d px (%.0f%%)  kontur %s"
            % (namn, d.b, d.h, len(färger), len(pal), fyllda, medel_sträcka,
               min(aktiva), max(aktiva), mark, andel_mark * 100.0,
               "ja" if har_kontur else "NEJ"))
        if utanför:
            print("      färger utanför paletten: %s" % utanför)
            fel += 1
        if medel_sträcka < 1.8:
            print("      FEL: sträckan är %.1f px i innanmätet — formen är brus, inte en form "
                  "(schackrutan: 1,0)"
                  % medel_sträcka)
            fel += 1
        if andel > 0.15:
            print("      FEL: %.0f %% av pixlarna saknar grannar — formen hänger inte ihop" % (andel * 100.0))
            fel += 1
        if andel_mark > 0.05:
            print("      FEL: %.0f %% av pixlarna är MARKFÄRG (index 17 = golvet) — en kropp i "
                  "markfärgen försvinner när rekvisitan står på golvet" % (andel_mark * 100.0))
            fel += 1
        if not topp:
            print("      FEL: silhuetten är en platta (toppraden %d px, bredaste %d px)"
                  % (rader[0], max(aktiva)))
            fel += 1
        if not har_kontur:
            print("      FEL: ingen kontur (INK) — saken flyter in i golvet")
            fel += 1
        # YTKONTRASTEN. Kroppen (allt utom konturen) får inte ligga i tonerna hos ytan rekvisiten
        # hänger framför — se KONTRAST/DOLD. Konturen undantas: den SKA vara INK, och INK är takets
        # egen ton (taket ritas i INK/CAVE_D/DARK), så konturen mäts mot en yta den ligger an mot med
        # flit.
        if namn in HÄNGER:
            if not yttoner:
                print("      ytkontrast: kunde inte läsa ytorna (gen_tiles) — hoppar över")
            else:
                def avstånd(a: int, b: int) -> float:
                    return sum((pal[a][k] - pal[b][k]) ** 2 for k in range(3)) ** 0.5
                kropp = [(y, x) for y in range(d.h) for x in range(d.b)
                         if d.px[y][x] not in (0, INK)]
                dolda = sum(1 for y, x in kropp
                            if min(avstånd(d.px[y][x], c) for c in yttoner) < KONTRAST)
                andel_dold = dolda / max(len(kropp), 1)
                print("      ytkontrast: %.0f %% av kroppen ligger inom %.0f steg från vägg/tak (%s)"
                    % (andel_dold * 100.0, KONTRAST, "ok" if andel_dold <= DOLD else "FEL"))
                if andel_dold > DOLD:
                    print("      FEL: %.0f %% av kroppen ligger i ytans egna toner (gräns %.0f %%) — "
                        "en rekvisit som hänger framför en vägg måste ha en egen ton (se JÄRNET)"
                        % (andel_dold * 100.0, DOLD * 100.0))
                    fel += 1
    print("%d rekvisiter, %d fel" % (len(FORMER), fel))
    return fel


def _väggruta(img: Image.Image, x0: int, y0: int, b: int, h: int, pal) -> None:
    """En bit av den RIKTIGA stenväggen att döma väggrekvisiten mot.

    Rekvisitan hänger i en vägg, inte på ett golv, och en mörk bål mot golvfärgen läses som "en figur
    som försvinner på mitten" (mätt). Fram till nu målades bakgrunden av `_brus` — ett slagsmål om
    sten- och murbruksrutor som inte finns i spelet sedan rutorna ritades om (c184fdc, se
    tools/gen_tiles.py). En bedömning mot en yta som inte finns är ingen bedömning: väggen hämtas
    därför ur generatorn, samma kod som skriver spelets rutor. Saknas den (ett trasigt verktygsträd)
    faller vi tillbaka på den gamla brusväggen i stället för att inte visa något alls.
    """
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import gen_tiles as tiles                                  # samma generator som spelets rutor
        px = tiles.TEMA["grotta"]["wall"]()
        for y in range(h):
            for x in range(b):
                img.putpixel((x0 + x, y0 + y), pal[px[y % tiles.SIZE][x % tiles.SIZE]])
        return
    except (ImportError, OSError, KeyError):
        pass
    for y in range(h):
        for x in range(b):
            n = _brus((x0 + x) // 26, (y0 + y) // 26, 5)
            färg = STONE_D if n < 0.35 else (STONE_L if n > 0.80 else STONE)
            img.putpixel((x0 + x, y0 + y), pal[färg])
    for y in range(0, h, 26):
        for x in range(b):
            img.putpixel((x0 + x, y0 + y), pal[MORTAR])


def sheet(pal: list[tuple[int, int, int]]) -> None:
    """Kontaktkarta: rekvisterna sida vid sida, de på golvet mot en golvplanka och de i väggen mot en
    stenvägg, så att silhuetten syns mot den yta den faktiskt sitter på."""
    skala = 6
    bredd = sum(bygg().b * skala + 8 for bygg in FORMER.values()) + 8
    höjd = max(bygg().h for bygg in FORMER.values()) * skala + 16
    img = Image.new("RGB", (bredd, höjd), pal[DIRT])
    x0 = 8
    for namn, bygg in FORMER.items():
        d = bygg()
        if namn in VÄGG:                                   # bara bakom DEN här rekvisitan
            _väggruta(img, x0 - 2, 6, d.b * skala + 4, d.h * skala + 4, pal)
        for y in range(d.h):
            for x in range(d.b):
                c = d.px[y][x]
                if c == 0:
                    continue
                for dy in range(skala):
                    for dx in range(skala):
                        img.putpixel((x0 + x * skala + dx, 8 + y * skala + dy), pal[c])
        x0 += d.b * skala + 8
    img.save(OUT_DIR / "_rekvisiter.png")
    print("kontaktkarta: %s" % (OUT_DIR / "_rekvisiter.png").relative_to(ROOT))


def main() -> int:
    pal = [tuple(c) for c in json.loads((ROOT / "game" / "assets" / "palette.json").read_text())]
    if "--check" in sys.argv:
        return 1 if check(pal) else 0
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for namn, bygg in FORMER.items():
        d = bygg()
        img = Image.new("RGBA", (d.b, d.h), (0, 0, 0, 0))
        for y in range(d.h):
            for x in range(d.b):
                if d.px[y][x] != 0:
                    r, g, b = pal[d.px[y][x]]
                    img.putpixel((x, y), (r, g, b, 255))
        img.save(OUT_DIR / ("%s.png" % namn))
        print("  %s (%dx%d)" % ((OUT_DIR / ("%s.png" % namn)).relative_to(ROOT), d.b, d.h))
    if "--sheet" in sys.argv:
        sheet(pal)
    return 0


if __name__ == "__main__":
    sys.exit(main())
