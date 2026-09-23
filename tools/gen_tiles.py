#!/usr/bin/env python3
"""Tilegeneratorn: väggar, golv och tak räknas fram här, inte laddas ner.

Skäl, samma som för ljudet: ett pixelspel behöver sömlösa 128x128-rutor i EN palett. Det är
tråkigast i världen att leta efter och lättast att räkna fram — och då finns ingen licens att
hålla reda på, ingen fil att tappa bort, och samma kommando ger samma rutor (allt brus är seedat).

    python3 tools/gen_tiles.py            # skriver game/assets/tiles/<tema>/*.png
    python3 tools/gen_tiles.py --check    # mäter: rätt palett, rimlig ljushet, sömlös skarv
    python3 tools/gen_tiles.py --sheet    # kontaktkarta: alla teman sida vid sida, att döma på bild

FEM TEMAN, inte en ruta i fem färger. Varje tema har sin egen YTA (murverk, berg, jord med balkar,
träplank) och sin egen ALT-ruta (mossa, bennischer, vattendrag, sot med lampa, rasad planka) som
spelet använder där våningen har något att säga — en boss eller en trappa. Filnamnen är desamma i
varje tema, så spelet byter katalog och ingenting annat.

Sömlöshet är det enda som inte syns på en enskild ruta: rutan upprepas per block, så en skarv blir
ett rutnät över hela väggen. Provet jämför därför skillnaden ÖVER skarven (sista kolumnen mot
första) med den VÄRSTA kanten inuti rutan.

GRINDEN MÄTER OCKSÅ UPPREPNINGEN, för det är den Alex klagar på och den går att mäta: basvarianterna
läggs ihop till fyra super-rutor (fyra ordningar), och två av dem fick inte vara samma bild. Det
felet hade redan hänt — `wall_super_0.png` och `wall_super_3.png` var byte för byte samma ruta när
varje roll hade tre varianter. Dessutom skrivs rutans nät ut per ruta: ledens höjd och hur stor del
av stenarna som slogs ihop till hällar. Det är de två talen som avgör om ytan läses som hällberg
eller som förband, och de stod tidigare bara i en mening i en lämning.

Ponytail: fem teman räcker för att varje bana ska kännas som en plats. Ett sjätte läggs till när
en plats bevisligen ser ut som en annan.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PALETTE_FILE = ROOT / "game" / "assets" / "palette.json"
OUT_DIR = ROOT / "game" / "assets" / "tiles"
SHEET_FILE = OUT_DIR / "_teman.png"
SIZE = 128          ## Rutan täcker 0,5 m i spelet: 256 px/m (var 64 px = 128 px/m, 32 px = 64).
SEED = 20260919

# Palettens index (se palette.json). 0-15 är spelets grund; 16-24 är tillägg för jord/trä (16-18),
# grottblå (19-21) och ben (22-24). De ligger efter grunden och i ramper, så inget befintligt index
# flyttar sig och en yta kan ljusas/mörkas ett steg i taget.
INK, DARK, MORTAR = 1, 2, 3
STONE_D, STONE, STONE_L, EDGE_L, PALE = 4, 5, 6, 7, 8
RED_D, MOSS = 10, 15
EMBER, FLAME = 12, 13
DIRT_D, DIRT, WOOD_L = 16, 17, 18
CAVE_D, CAVE, CAVE_L = 19, 20, 21
BONE, BONE_L, BONE_D = 22, 23, 24
WATER, WATER_L = 25, 26

## Per-pixel material, ur palettens index: (höjd, råhet, metall).
##
## Tonen ÄR höjden i den här konsten — ljus = upphöjd, mörk = indragen — så kartorna kan räknas ur
## palettens ordning i stället för att varje mönster måste skriva tre arrayer. Det är en härledning,
## inte en gissning: faller den syns det direkt som fel relief i bild (murbruket blir upphöjt).
## Råheten är den egenskap Alex frågade efter: sten är matt (1,0), ben är halvblankt, vatten blankt.
MATERIAL: dict[int, tuple[float, float, float]] = {
    INK: (0.00, 1.00, 0.0),
    DARK: (0.18, 1.00, 0.0),
    MORTAR: (0.30, 1.00, 0.0),          # fog/murbruk: indraget och matt
    STONE_D: (0.45, 0.95, 0.0),
    STONE: (0.60, 0.95, 0.0),
    STONE_L: (0.78, 0.90, 0.0),
    EDGE_L: (0.92, 0.85, 0.0),
    PALE: (1.00, 0.80, 0.0),
    RED_D: (0.55, 0.70, 0.0),
    MOSS: (0.72, 1.00, 0.0),            # mjukt: matt, ingen glans
    EMBER: (0.40, 0.90, 0.0),
    FLAME: (0.50, 0.60, 0.0),
    DIRT_D: (0.30, 1.00, 0.0),
    DIRT: (0.50, 1.00, 0.0),
    WOOD_L: (0.72, 0.72, 0.0),          # trä: halvmatt, lite glans i ådringen
    CAVE_D: (0.30, 0.90, 0.0),
    CAVE: (0.55, 0.90, 0.0),
    CAVE_L: (0.80, 0.85, 0.0),
    BONE_D: (0.50, 0.60, 0.0),
    BONE: (0.75, 0.50, 0.0),            # ben: halvblankt
    BONE_L: (1.00, 0.45, 0.0),
    WATER: (0.40, 0.12, 0.30),          # vatten: blankt och svagt metalliskt -> speglar lyktan
    WATER_L: (0.50, 0.05, 0.40),
}


## Höjden kommer INTE bara ur palettindexet. Tonen är höjd på en slät yta, men grottgolvet är med
## flit tvåtons (se grotta/floor: en ljus tredje ton lästes som föremål på golvet), och då försvann
## reliefen med tonerna — mätt: grottgolvets normal låg på 4,3 grader mot murens 12,4. Ytor ritade av
## blockverk bär därför sin EGEN höjd (fogens ränna, blockets kant, sprickans spår) ovanpå tonen.
RÄNNA = 0.45        ## Fog/spricka i höjdkartan: så mycket lägre än stenen intill (en ränna).
KANT_OVAN = 0.16    ## Blockets kant: en liten upphöjning, inte bara en ljus pixel i albedon.
KORN_OVAN = 0.08    ## Kornet: 1 px mikrorelief i höjden också — stenen är inte slät.
AO_BOTTEN = 0.45    ## Ocklusionen (ORM, R-kanalen) i det lägsta partiet — fogen — av rutans eget spann.


class Ruta(list):
    """Pixelrutan PLUS sin höjd i 2.5D, när ytan är ritad av blockverk.

    Höjden hänger på rutan i stället för att lämnas tillbaka som ett par, för då behöver ingen av
    anropen ändras (TEMA:s lambdas ritar en ruta, inte en ruta och en karta — och accenterna, som
    lägger mossa eller ben ovanpå, rör inte höjden). Rutorna är listor hela vägen igenom; bara den
    här bär en extra egenskap.
    """
    höjd: list[list[float | None]] | None = None
    ## Hur nätet blev, för den som vill MÄTA upprepningen i stället för att tycka om den:
    ## radhöjderna i tur och ordning, och hur stor andel av stenarna som slogs ihop med en granne.
    rader: list[int] | None = None
    ihop: float = 0.0


def stenhöjd(c: int) -> float:
    """Höjden för en palettfärg — samma tabell som material() läser.

    Behövs för att en ränna ska bli RÄNNA djup i varje tema: fogen mäts mot stenen den ligger intill,
    inte mot noll. En mörk grottsten ligger redan på 0, och en ränna som dras av från 0 blir platt
    (mätt: grottans och kryptans tak låg kvar på 7,9 och 7,3 grader när resten låg på 18-22)."""
    return MATERIAL.get(c, (0.5, 0.95, 0.0))[0]


def material(px: list[list[int]]) -> tuple[list[list[float]], list[list[float]], list[list[float]]]:
    """(höjd, råhet, metall) per pixel ur paletten, plus rutans ritade höjd om den har någon.
    Okända index blir matt sten — en ny färg ska inte kunna ge en yta som speglar utan att någon har
    bestämt det.

    Rutans ritade höjd är ABSOLUT där den finns (fogen vet hur djupt under sin sten den ligger) och
    None där tonen gäller — ingen klämning mot 0..1: en ränna under en sten som redan står på 0 ska
    bli en ränna, inte en plan yta."""
    över = getattr(px, "höjd", None)
    h, r, m = [], [], []
    for y, rad in enumerate(px):
        hr, rr, mr = [], [], []
        for x, c in enumerate(rad):
            v = MATERIAL.get(c, (0.5, 0.95, 0.0))
            ritad = över[y][x] if över else None
            hr.append(v[0] if ritad is None else ritad)
            rr.append(v[1])
            mr.append(v[2])
        h.append(hr)
        r.append(rr)
        m.append(mr)
    return h, r, m


def jämna(h: list[list[float]]) -> list[list[float]]:
    """En 3x3-medelvärdesrundning av höjden. Utan den blir normalen spretig av enstaka pixlar
    (murbruksfogen är en pixel bred) och reliefen läses som brus i stället för som form.

    Radien står STILL, och det är MÄTT, inte gissat. Rundningen är ett texelmått: en tonkant är en
    pixel i 32-, 64- och 128-rutan, och det som ska slätas är spretighet på en-två PIXLARS avstånd —
    det gör en 3x3 lika bra när fogen är 2-4 pixlar bred. Att skala filtret i stället ("samma bredd i
    meter") ändrade reliefen: 6x6 mot den gamla kartan gav 0,35 gånger så branta normaler (platt) och
    fällde relief-grinden i 8 av 45 rutor. 3x3 ligger på 0,91 — samma ljus."""
    ut = [[0.0] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            summa = 0.0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    summa += h[(y + dy) % SIZE][(x + dx) % SIZE]
            ut[y][x] = summa / 9.0
    return ut


def normal_karta(h: list[list[float]], styrka: float = 2.6):
    """Tangentrymdsnormal ur höjden (Sobel). Wrapen (modulo) är det som gör kartan sömlös — samma
    skäl som för rutorna: sista kolumnen är granne med den första i den upprepade väggen.

    Steget är EN pixel och styrkan står därför STILL: en tonkant är en pixel i 32-, 64- och 128-rutan,
    alltså samma höjdskillnad mellan två grannpixlar och samma lutning i kartan. Mätt mot den gamla
    normal-kartan (medel av 255-blå över 45 rutor, nedskalad med NEAREST) ger 2,6 0,91 gånger den
    gamla reliefen — samma 2.5D-ljus. Dubblad styrka gav 1,44: hårdare ljus, alltså ett ANNAT
    utseende. Lutningen är en egenskap hos rutan, inte en längd i meter."""
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            hx = h[y][(x + 1) % SIZE] - h[y][(x - 1) % SIZE]
            hy = h[(y + 1) % SIZE][x] - h[(y - 1) % SIZE][x]
            nx, ny, nz = -hx * styrka, -hy * styrka, 1.0
            längd = (nx * nx + ny * ny + nz * nz) ** 0.5
            img.putpixel((x, y), (int((nx / längd * 0.5 + 0.5) * 255),
                                  int((ny / längd * 0.5 + 0.5) * 255),
                                  int((nz / längd * 0.5 + 0.5) * 255)))
    return img


def orm_karta(h: list[list[float]], r: list[list[float]], m: list[list[float]]) -> Image.Image:
    """ORM i glTF-ordning: R = ocklusion, G = råhet, B = metall.
    En karta i stället för två, och kanalerna läses med roughness_texture_channel i spelet.

    Ocklusionen är HÄRLEDD ur höjden (R var 1,0 överallt, alltså ingen kontaktmörkring alls): fogen,
    sprickan och kanten är räknade i samma höjdkarta som normalen, och det som ligger lägre ska vara
    mörkare. Det är den andra halvan av 2.5D-djupet — fogarna blir mörka även där ingen skugga råkar
    falla, i stället för att bara blänka till när lyktan står rätt.

    Skalan är rutans EGEN (min..max): en mörk grotta har annars samma ocklusion som en ljus mur, och
    en ruta utan struktur (en plan yta) får jämn ocklusion i stället för falska fogar.
    """
    låg, hög = min(min(rad) for rad in h), max(max(rad) for rad in h)
    spann = (hög - låg) or 1.0
    img = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            t = (h[y][x] - låg) / spann
            img.putpixel((x, y), (int((AO_BOTTEN + (1.0 - AO_BOTTEN) * t) * 255),
                                  int(r[y][x] * 255), int(m[y][x] * 255)))
    return img


## Reliefen, mätt ur _n-kartan som skrivs: 90-percentilen av lutningen i grader (arcsin ur R/G mot
## 128 — samma mått som ögat och Alex använder, inte en härledning ur höjden). Gränsen står därför
## att en normal UTAN kant inte passerar: mätt före den ritade strukturen låg grottans golv på 19
## grader och tunnelns tak på 20, medan kryptans mur låg på 29. Det var golven Alex klagade på
## ("normalkartan märks knappt"), och en grind som släpper 19 mäter fel sak.
REL_P90 = 20.0


def lutning(n: Image.Image) -> tuple[float, float]:
    """(medel, 90-percentil) av normalens lutning i grader, läst ur den färdiga _n-kartan."""
    data = n.tobytes()                     # R,G,B per pixel i radordning
    vinklar = []
    for i in range(0, len(data), 3):
        d = min(1.0, max(abs(data[i] - 128), abs(data[i + 1] - 128)) / 127.5)
        vinklar.append(math.degrees(math.asin(d)))
    vinklar.sort()
    return sum(vinklar) / len(vinklar), vinklar[int(len(vinklar) * 0.9)]


def load_palette() -> list[tuple[int, int, int]]:
    return [(int(c[0]), int(c[1]), int(c[2])) for c in json.loads(PALETTE_FILE.read_text())]


FRÖ = 0  ## Variantfrö. wang() lägger det till saltet, så FRÖ=0 ger exakt de rutor som är
         ## granskade sedan tidigare och FRÖ=1,2 ger ANDRA dragningar av samma material.


def variant(build, frö: int):
    """Samma generator, annat frö — en annan dragning av samma berg/jord/trä.

    Så gör referensen sina sju korridorvarianter (`DairyPlant_Corridor_Straight_01…07`, research/09):
    sju dragningar av SAMMA roll. Ett nytt MOTIV per variant (en oval fläck, en stenklump) läses som
    ett föremål när rutan upprepas var halvmeter — Alex: *"jag vet inte vad det skall föreställa"*.
    Två dragningar av samma berg läses som berg.
    """
    global FRÖ
    def kört():
        global FRÖ
        sparat = FRÖ
        FRÖ = frö
        try:
            return build()
        finally:
            FRÖ = sparat
    return kört


def wang(x: int, y: int, salt: int = 0) -> float:
    """Deterministiskt brus 0..1 som TÅL upprepning: samma (x,y) ger samma värde varje körning."""
    salt += FRÖ * 7919
    h = hashlib.sha256(f"{SEED}:{salt}:{x}:{y}".encode()).digest()
    return int.from_bytes(h[:4], "big") / 0xFFFFFFFF


def blank() -> Ruta:
    """En tom ruta: rutans grund är alltid INK, och rutan bär sin egen höjd (se Ruta)."""
    return Ruta([[INK for _ in range(SIZE)] for _ in range(SIZE)])


def put(px: list[list[int]], x: int, y: int, c: int) -> None:
    px[y % SIZE][x % SIZE] = c


# --- ytor ---------------------------------------------------------------------
# Varje yta tar sina tonsteg (mörk, mellan, ljus), så samma mönster kan bli sten, berg eller jord.

KORN = 0.03        ## Andel av blockets pixlar som får ett korn (2-4 %): per pixel, inte per band.
SPRICKA = 0.34     ## Andel block som får en mikrojspricka — några få, aldrig alla.


def radhöjder(bh: int, salt: int, ojämn: float) -> list[int]:
    """Radhöjderna i nätet: olika höga rader, men summan är fortfarande SIZE.

    Det här är vad den förra skrivaren lämnade efter sig: *"Grottans väggar läser som väl jämna
    rektanglar ('industrial cinder blocks')"*. Rader med exakt samma höjd är en mur, inte ett berg —
    i ett riktigt hällberg ligger hällarna i olika tjocklek, och fogen går inte att dra linjal efter.

    Antalet rader står STILL (`SIZE // bh`) och bara höjden flyttar mellan dem. Skarvgrinden är
    skälet: nätet mäts modulo rutan, så en rad som fattas eller blir över hamnar på fel ställe vid
    63 -> 0, och då är rutans kant en fog i stället för en pixel mitt i en sten — mätt som en synbar
    söm över hela väggen. Höjderna kläms därför in i [minsta, SIZE - minsta*(n-1)] och resten
    fördelas ett steg i taget tills summan ÄR SIZE.
    """
    antal = SIZE // bh
    if not ojämn:
        return [bh] * antal
    minsta = max(12, bh // 2)
    tak = SIZE - minsta * (antal - 1)
    # Höjden avrundas till ETT STEG som är bh//16 pixlar: en pixel i 64-rutan, två i 128-rutan. Utan
    # det blir raderna 28,33,33,34 i stället för 28,32,34,34 (mätt) — alltså inte dubbelt av den gamla
    # rutan — och då ändras hällarnas AREOR, tonbalanseringen nedan sorterar dem i en annan ordning
    # och hela väggen får andra toner. Mätt som 29 gråstegs skillnad mot den gamla rutan i dubbel
    # upplösning (accepttestet), samma mönster men fel färg per sten.
    steg = max(1, bh // 16)
    höjder = [max(minsta, min(tak, steg * int(round(
        bh * (1.0 + (wang(i, 7, salt + 71) - 0.5) * 2.0 * ojämn) / steg)))) for i in range(antal)]
    diff = SIZE - sum(höjder)
    i = 0
    while diff and i < 8 * antal:
        k = i % antal
        steg_fel = steg if diff > 0 else -steg
        if höjder[k] + steg_fel >= minsta:
            höjder[k] += steg_fel
            diff -= steg_fel
        i += 1
    return höjder


def _jopp(x: int, y: int, salt: int, bruten: float) -> int:
    """+2, 0 eller -2: hur långt en kant flyttar sig. `bruten` är andelen kanter som rör sig.

    Två pixlar, inte en: kanten ska flytta sig lika långt i METER som när rutan var 64 px (se
    jämna om varför texelmåttet står still).

    Det är den lilla ojämnheten som skiljer huggen sten från en tegelsten: en fog som ligger på
    exakt samma pixel i varje led läses som en ritad linje, och en ritad linje är en byggsten.
    """
    if not bruten:
        return 0
    u = wang(x, y, salt)
    if u < bruten * 0.5:
        return -2
    return 2 if u > 1.0 - bruten * 0.5 else 0


def blockverk(t: tuple[int, int, int], fog: int, kant: int | None, salt: int,
              bw: int = 32, bh: int = 32, slå: float = 0.0, slå_upp: float = 0.0,
              ojämn: float = 0.0, bruten: float = 0.0, långa: int = 0) -> list[list[int]]:
    """RITAD mur: fog med hård kant, ton per block, korn per pixel och mikrojsprickor.

    Ersätter de mjukade brusfälten (bilinjär _värde ur _brusruta) som berg, jord och golv restes av.
    Upplösningen fanns, men formerna var VALV: mätta på bild i spelet läste de som "topographic
    elevation map, camouflage fabric, or melted wax" — och ingenstans fanns en RITAD kant. Här är
    varje element ritat, inte utjämnat:

      fog       fyra pixlar av fogfärgen med HÅRD kant (inget mellansteg mot stenen)
      kant      två pixlar ljusa i blockets över- och vänsterkant — ljuset kommer uppifrån, så stenen
                får en kant och reliefkartan en trappa (fog = låg, kant = hög)
      ton       per BLOCK, ur blockets egen position — inte per pixel, och inte ur ett mjukt fält
      korn      2-4 % enstaka pixlar ett tonsteg från blockets egen ton
      spricka   en 1 px olikformad väg inuti några få block
      slå       andel block som slås ihop med sin vänstra granne: hällar i stället för förband
      slå_upp   samma sak uppåt, så hällen blir HÖGRE än en sten också (berg, inte förband)
      ojämn     hur mycket radhöjderna får skilja (se radhöjder): 0 = linjalräta led
      bruten    andel kanter som flyttar sig en pixel, så fogen inte ligger på samma pixel överallt
      långa     antal sprickor som går TVÄRS ÖVER nätet och över fogarna (se nedan)

    SKARVEN: blocknätet är förskjutet en kvarts block (bw//4, bh//4), och blocket är 32 px (12,5 cm)
    — samma sten i meter som när rutan var 64 px, bara ritad i dubbel täthet. Då hamnar rutans kant INUTI
    ett block i stället för på en fog — och fogen är rutans hårdaste kant, så en fog på kanten mäts
    som en synbar söm (grinden jämför skarven med rutans värsta INRE kant). Förskjutningen är fyra
    pixlar på en 16-pixelsten, alltså samma mönster, bara inte delat mitt på en fog. Radhöjderna
    (ojämn) summerar fortfarande till SIZE, så nätet går jämnt ut i rutan åt båda hållen även när
    raderna är olika höga.
    """
    px = blank()
    höjd: list[list[float | None]] = [[None] * SIZE for _ in range(SIZE)]   # ritad höjd (se Ruta)
    kolumner = SIZE // bw
    rader_h = radhöjder(bh, salt, ojämn)
    rader = len(rader_h)
    # Rad 0 börjar på by-rad 0, så start[r] är radens första by och vilken[by] är raden by hör till.
    start, vilken = [], []
    s = 0
    for r, h in enumerate(rader_h):
        start.append(s)
        vilken += [r] * h
        s += h
    fx, fy = bw // 4, min(bh // 4, max(rader_h[0] - 8, 0))
    # Vilka stenar som slås ihop med en granne. KEDJOR TILLÅTS — och det är rättat efter mätning:
    # förbudet mot kedjor (ett block fick bara slås ihop om grannen inte redan var ihopslagen) såg
    # rimligt ut men gjorde att bara 3 av 12 möjliga lodräta platser var lediga på grottans vägg,
    # alltså blev lodrät sammanslagning en död parameter. Det förbudet fanns för att två block
    # annars ärver OLIKA toner utan fog emellan och tonkanten syns som en mjuk fläck — men det
    # problemet sitter i TONUPPslagningen, inte i kedjan: med hällens ROT som nyckel (se `rot`) har
    # hela hällen EN ton, hur många stenar den än består av. Kvar står att fogen försvinner inuti
    # hällen (se med_x/med_y), och det är själva poängen.
    #
    # Block 0 slås aldrig ihop vågrätt: dess vänsterfog ligger vid rutkanten och hör till nästa
    # rutas block 3 — slås den ihop försvinner en fog mitt i väggen vid varje skarv.
    ihop: dict[tuple[int, int], tuple[int, int]] = {}
    for r in range(rader):
        for bi in range(1, kolumner):
            if slå and wang(bi, r, salt + 9) < slå:
                ihop[(bi, r)] = (bi - 1, r)
    if slå_upp:
        for r in range(1, rader):
            for bi in range(kolumner):
                if (bi, r) not in ihop and wang(bi, r, salt + 27) < slå_upp:
                    ihop[(bi, r)] = (bi, r - 1)

    def rot(k: tuple[int, int]) -> tuple[int, int]:
        """Hällens rot: en kedja av hopslagningar har EN ton, inte en per sten."""
        while k in ihop:
            k = ihop[k]
        return k

    # Tonerna fördelas JÄMNT över hällarnas YTA, inte över deras antal. Skälet är mätt: med 16
    # stenar och tre toner kan en dragning ge fyra hällar av den LJUSA tonen och en av den mörka,
    # och då skiljer rutans medelljus 20 gråsteg från en annan variant av samma berg. Grinden fällde
    # det (OLIK_LJUS = 15), och med rätta — det är inte samma material längre. Större hällar gjorde
    # det värre, för en stor häll av en avvikande ton äger en större del av rutans yta: därför räcker
    # det inte att balansera ANTALET hällar (mätt: spannet gick från 22 till 16 gråsteg, fortfarande
    # över gränsen), det är ytan som syns. Här får hällarna ton i fallande storleksordning, var och
    # en till den ton som har minst yta hittills; blandningsnyckeln är fortfarande hällens EGEN
    # position, så tonen ligger där den låg — det är bara fördelningen som inte längre slumpas.
    area: dict[tuple[int, int], int] = {}
    for r in range(rader):
        for bi in range(kolumner):
            k = rot((bi, r))
            area[k] = area.get(k, 0) + bw * rader_h[r]
    toner: dict[tuple[int, int], int] = {}
    upptagen = [0, 0, 0]
    for k in sorted(area, key=lambda k: (-area[k], wang(k[0], k[1], salt + 3))):
        i = upptagen.index(min(upptagen))
        toner[k] = i
        upptagen[i] += area[k]
    for y in range(SIZE):
        by = (y + fy) % SIZE
        r = vilken[by]
        inom_y = by - start[r]
        off = (bw // 2) if r % 2 else 0                        # förband: varannan rad förskjuten
        jy = _jopp(r, 0, salt + 43, bruten)                    # hela ledet flyttar sig, inte en sten
        for x in range(SIZE):
            bx = (x + off + fx) % SIZE
            bi = bx // bw
            inom_x = bx % bw
            egen = rot((bi, r))                                 # tonen är HÄLLENS, inte stenens
            i = toner[egen]
            bas = stenhöjd(t[i])                        # stenen runtom: rännan mäts mot den
            # Fogen ritas bara där hällen SLUTAR: en sten som slogs ihop med sin vänstra granne har
            # ingen vänsterfog, en som slogs ihop uppåt har ingen övre fog. Det är det som gör
            # hällen till en häll i stället för två stenar med en fog emellan.
            mål = ihop.get((bi, r))
            med_x = mål is not None and mål[1] == r
            med_y = mål is not None and mål[1] != r
            # Fogen är en RÄNNA i höjden, kanten en liten upphöjning, kornet 1 px mikrorelief. Det är
            # höjden som ger normalen en hård lutning längs fogen — albedon behöver inte bära den.
            # Kanten ligger en pixel inåt eller utåt ur sin egen position (bruten), så fogen inte är
            # en linje man kan dra linjal efter.
            jx = _jopp(bi, r, salt + 47, bruten)
            if (inom_y < 4 + jy and not med_y) or (inom_x < 4 + jx and not med_x):
                c, upp = fog, bas - RÄNNA
            # Kanten är TVÅ pixlar (en pixel i den gamla 64-rutan): en pixel här är en halv pixel i
            # meter, alltså en tunnare ljus rand än den gamla rutan hade.
            elif (inom_y in (4 + jy, 5 + jy) and not med_y) or (inom_x in (4 + jx, 5 + jx) and not med_x):
                c, upp = (t[i] if kant is None else kant), bas + KANT_OVAN
            elif wang(x, y, salt + 5) < KORN:
                c, upp = t[(i + (1 if wang(x, y, salt + 6) < 0.5 else -1)) % 3], bas + KORN_OVAN
            else:
                c, upp = t[i], None
            px[y][x] = c
            höjd[y][x] = upp
    # Mikrojsprickor: korta, 1 px breda vägar inuti blocken, med ett riktningsbyte så de är
    # olikformade och inte en rak linje. Bara i blockens inre — fogen ritas inte över.
    for r in range(rader):
        off = (bw // 2) if r % 2 else 0
        for bi in range(kolumner):
            if (bi, r) in ihop or wang(bi, r, salt + 11) > SPRICKA:
                continue
            ax = (bi * bw - off - fx) % SIZE
            ay = (start[r] - fy) % SIZE
            wx = 6 + int(wang(bi, r, salt + 13) * (bw - 16))
            wy = 6 + int(wang(bi, r, salt + 17) * (rader_h[r] - 16))
            for k in range(8 + int(wang(bi, r, salt + 19) * 16)):
                if wy >= rader_h[r] - 6:
                    break
                put(px, ax + wx, ay + wy, t[0])
                # Sprickan är ett SPÅR i höjden (grundare än fogen): 1 px mörk ton räcker inte för
                # att synas vid fackelsken, men en ränna i normalen gör det.
                höjd[(ay + wy) % SIZE][(ax + wx) % SIZE] = stenhöjd(t[toner[(bi, r)]]) - RÄNNA * 0.55
                wy += 1
                if wang(bi * 41 + k, r, salt + 23) < 0.35:
                    # Riktningsbytet är två pixlar, som resten av måtten: en pixel här är en halv
                    # pixel i meter, alltså en rakare spricka än den gamla rutan hade.
                    wx += 2 if wang(bi * 41 + k, r, salt + 29) < 0.5 else -2
                    wx = min(max(wx, 6), bw - 8)
    # Långa sprickor: 1 px spår som vandrar tvärs över rutan och över fogarna, några stenar långt.
    # Det är den sista pusselbiten i "naturligt sprucket berg i stället för jämna rektanglar": en
    # spricka som STANNAR vid fogen säger att fogen är en riktig kant i berget, och då är hällen en
    # byggsten hur ojämn dess kant än är. Sprickorna läggs EFTER blocken, så de skär över både fog,
    # kant och granne. Allt skrivs modulo SIZE (put/höjd-indexen), alltså är de sömlösa som resten.
    ## Starten räknas i HALVA rutan och dubblas, och vägen tar två rader och två kolumner per steg: en
    ## spricka som flyttar sig en pixel i 128-rutan är annars en halv pixel i meter, alltså en ANNAN
    ## spricka än den gamla (samma skäl som radhöjder avrundar i steg).
    for n in range(långa):
        x = 2 * int(wang(n, 1, salt + 101) * (SIZE // 2))
        y = 2 * int(wang(n, 2, salt + 103) * (SIZE // 2))
        rikt = 1 if wang(n, 3, salt + 107) < 0.5 else -1
        for _ in range(24 + int(wang(n, 4, salt + 109) * 40)):
            for dy in (0, 1):
                px[(y + dy) % SIZE][x] = t[0]
                # rännan mäts mot STENEN, inte mot noll
                höjd[(y + dy) % SIZE][x] = stenhöjd(t[1]) - RÄNNA * 0.6
            y = (y + 2) % SIZE
            if wang(x, y, salt + 113) < 0.45:
                x = (x + 2 * rikt) % SIZE
            if wang(x, y, salt + 127) < 0.09:
                rikt = -rikt
    px.höjd = höjd
    px.rader = rader_h
    px.ihop = len(ihop) / float(rader * kolumner)
    return px


def murverk(t: tuple[int, int, int], fog: int, kant: int) -> list[list[int]]:
    """Murverk: block 32x32 (12,5 cm) i jämnt förband, en halv sten förskjutna varannan rad.

    Formen är den gamlas — den lästes på bild redan som byggd sten ("classic running-bond ashlar
    masonry", med fogar och fasade kanter). Det nya är kornet och mikrojsprickorna på 1 px (förr
    mättes de i 2x2-rutor, alltså dubbelt så grova) och att fogen har en hård kant i stället för
    ett mjukt tonsteg.

    Här är ojämnheten MILD (0,12 radhöjd, 0,3 brutna kanter): det är byggd sten, och fogarna ska
    följa en linje. Lagom mycket gör att två närliggande rutor inte är samma bild; för mycket tar
    bort läsningen "det här är en MUUR" — och muren var det enda i uppsättningen som redan lästes
    rätt. Berg (se berg) får den bryska varianten.
    """
    return blockverk(t, fog, kant, salt=0, bw=32, bh=32, ojämn=0.12, bruten=0.3)


def berg(t: tuple[int, int, int], spricka: int, långa: int = 2, salt: int = 41) -> list[list[int]]:
    """Oregelbundet berg: hällar med ritad kant, i stället för en mjukad brusyta.

    Gamla berg kom ur _värde/_brusruta (bilinjärt, mjukat brus) och lästes på bild som "topographic
    contour map ... camouflage fabric ... melted wax": upplösningen fanns, men formen var ett VALV
    utan kant. Nu är hällarna ritade (blockverk).

    Det här är ytan Alex klagade på efter c184fdc: *"Grottans väggar läser som väl jämna rektanglar
    ('industrial cinder blocks') — bara hälften av hällarna slås ihop till bredare."* Fyra svar på
    det, alla ritade och alla MÄTBARA i --check:

      ojämn 0,30     leden är olika höga (24-40 px i stället för 32,32,32,32) — mätt i --check
      bruten 0,5     varannan kant flyttar sig en pixel, så fogen inte ligger på samma rad överallt
      slå_upp 0,35   hällarna slås ihop UPPÅT också: två stenar höga, inte bara två breda
      långa 2        två sprickor som går tvärs över nätet och skär genom fogarna

    MÄTT på grottans vägg, samma mått före och efter (2x2-nätet är 16 stenar):

      före   5 av 16 stenar hopslagna, VARJE häll exakt 2 stenar bred, 10 av 16 stenar (62 %) i en
             häll, och leden 16,16,16,16 px — det är "cinder blocks" i en enda mätning
      efter  8 av 16 hopslagna, hällarna 5,3,2,2 stenar, 12 av 16 stenar (75 %) i en häll, leden
             12-20 px

    Att bara skruva upp `slå` gjorde INGENTING: 0,45 och 0,55 gav samma 31 % med den gamla
    kedjeregeln, eftersom det var REGELN och inte tröskeln som band. En häll som bara blir bredare
    är fortfarande en rad i ett förband, och det var förbandet som lästes som tegel.

    `långa=2` är för VÄGGEN. Golvet får en (se TEMA, grotta/floor): en lång spricka är ett
    igenkännbart MÄRKE, och på en golvruta som upprepas 2x2 per meter läser ögat att SAMMA spricka
    kommer tillbaka var halvmeter — bedömning av golvet: *"the eye instantly spots these identical
    cracks repeating in a strict 2x2 grid"*. Väggen bär två: den ses i svep, är mörk, och där gör
    sprickorna nytta (mätt i bedömning: "reads significantly more like weathered, cracked rock").

    SALTET är DRAGNINGEN, och det delas av alla berg som vill se ut som samma berg. Grottan och bron
    är två rum i samma grotta: samma hällar, samma färger, men de får inte vara SAMMA ruta — mätt på
    de sex väggrutorna skilde de bara 9-10 steg i medelfärg och 12-18 % av pixlarna (fogfärgen:
    MORTAR mot INK), medan reliefen var identisk pixel för pixel. Bara färgen skilde, och Alex regel
    är att två rum inte ska kunna förväxlas. Bron drar därför samma berg med ett annat salt (se
    TEMA, bro/wall) och grinden mäter att ingen annan temapunkt delar både mönster och färg.
    """
    return blockverk(t, spricka, t[2], salt=salt, slå=0.55, slå_upp=0.35,
                     ojämn=0.30, bruten=0.5, långa=långa)


def jord(t: tuple[int, int, int], balk: int, balk_ljus: int) -> list[list[int]]:
    """Jordvägg med träbalkar: gruvgången. Stöttorna sitter två per meter — det är de som gör att
    väggen läses som en TUNNEL och inte som packad jord.

    Jorden är ritade klumpar med hård kant (blockverk, ingen ljus rand: packad jord har ingen
    murbruksrand) i stället för den mjukade brusyta som mättes som "the muddiest texture in the set".
    Klumparna är ojämna som berget men utan långa sprickor — packad jord SPricker inte i skivor.
    """
    px = blockverk(t, t[0], None, salt=61, slå=0.35, slå_upp=0.25, ojämn=0.22, bruten=0.4)
    for y in range(0, 16):                           # takbalken
        for x in range(SIZE):
            px[y][x] = t[0] if y < 4 else balk
    for x in range(SIZE):
        for y in (12, 13, 14, 15):
            px[y][x] = balk_ljus
    for x0 in (16, 80):                              # två stöttor per meter, ljus kant mot ljuset
        for x in range(x0, x0 + 16):
            for y in range(SIZE):
                px[y][x] = balk_ljus if x - x0 < 4 else balk
    return px


def jordgolv(t0: int, t1: int, t2: int) -> list[list[int]]:
    """Packad jord som golv: samma klumpar som väggen, utan balkar och med ett annat frö i nätet."""
    return blockverk((t0, t1, t2), t0, None, salt=63, slå=0.25, slå_upp=0.2,
                     ojämn=0.18, bruten=0.35)


def plankor(t: tuple[int, int, int], springa: int) -> list[list[int]]:
    """Tak i plankor. Plankbredden (16) delar rutans höjd, så skarven hamnar mellan plankor.

    Springan mellan plankorna är ett SPÅR i höjden också — annars är taket den plattaste ytan i
    temat (mätt: tunnelns tak låg på 19,7 grader där muren låg på 12,4 och golven på 4-7)."""
    px = blank()
    höjd: list[list[float | None]] = [[None] * SIZE for _ in range(SIZE)]
    bas = min(stenhöjd(t[0]), stenhöjd(t[1]))            # spåret mäts mot plankorna, inte mot noll
    for y in range(SIZE):
        plank = y // 16
        for x in range(SIZE):
            c = t[plank % 2]
            if y % 16 < 4:
                c = springa
                höjd[y][x] = bas - RÄNNA * 0.7
            elif wang(x // 32, y // 4, 31) < 0.12:
                c = t[0] if c == t[1] else t[1]
            px[y][x] = c
    px.höjd = höjd
    return px


def tragolv(t: tuple[int, int, int]) -> list[list[int]]:
    """Brädgolv: 32 px breda plankor med ådring, lagda i längdriktningen. Golvet under fötterna på
    en bro ska visa att det ÄR plankor och inte sten.

    Ådringen är sammanhängande ränder per bräda, inte enstaka fläckar: mätt på bild läste prickarna
    som "digital artifacting, dirt speckling", inte som trä.
    """
    px = blank()
    höjd: list[list[float | None]] = [[None] * SIZE for _ in range(SIZE)]
    bas = min(stenhöjd(t[0]), stenhöjd(t[1]), stenhöjd(t[2]))
    antal = SIZE // 32
    ränder = {}
    for b in range(antal):
        # Ådringen läggs på JÄMNA rader, fyra pixlar hög: samma sträck var en pixel bred, två rader
        # gjorde den dubbelt så bred i pixlar och 4*(4 + …) är samma radläge i meter en täthet till.
        ränder[b] = sorted({4 * (4 + int(wang(b, k, 73) * (SIZE // 4 - 8))) for k in range(3)})
    for y in range(SIZE):
        for x in range(SIZE):
            b = x // 32
            c = t[b % 3]
            if x % 32 < 4:
                c = t[0]                             # springan mellan brädorna
                höjd[y][x] = bas - RÄNNA * 0.7         # springan är ett spår, inte bara en mörk rad
            elif y // 4 * 4 in ränder[b]:
                c = t[0] if c != t[0] else t[2]      # ådringen
                höjd[y][x] = bas - RÄNNA * 0.3
            px[y][x] = c
    px.höjd = höjd
    return px


# --- alt-ytorna ---------------------------------------------------------------
# Varje tema har en variant som spelet byter till där våningen har något att säga.

def accent_mossa(px: list[list[int]]) -> list[list[int]]:
    for x in range(SIZE):
        for y in range(72, SIZE):
            if wang(x // 4, y // 4, 11) < ((y - 72) / 56.0) * 0.85:
                put(px, x, y, MOSS)
    return px


def accent_nischer(px: list[list[int]]) -> list[list[int]]:
    """Kryptans vägg: nischer med ben. Två per meter, med ljus benkant inåt."""
    for x0 in (12, 76):
        for y in range(16, 96):
            for x in range(x0, x0 + 32):
                put(px, x, y, BONE_D if (x - x0 < 4 or y < 20) else DARK)
        for x in range(x0 + 8, x0 + 24):
            put(px, x, 72, BONE)
            put(px, x, 73, BONE)
            put(px, x, 74, BONE_L)
            put(px, x, 75, BONE_L)
    return px


def accent_vatten(px: list[list[int]]) -> list[list[int]]:
    """Grottans vägg: vatten som rinner ned, med en ljus kant där det blänker. Vattnet har EGNA
    palettfärger (WATER/WATER_L) — annars går det inte att skilja från berg, varken för ögat eller
    för materialkartan, och då kan det inte heller spegla något."""
    for x0 in range(0, SIZE, 4):                     # en droppe per halvmeter, nu fyra pixlar bred
        if wang(x0 // 4, 0, 81) < 0.35:
            längd = 4 * (10 + int(wang(x0 // 4, 1, 83) * 18))
            for y in range(längd):
                blänk = WATER_L if wang(x0 // 4, y // 4, 87) < 0.3 else WATER
                for dx in range(8):
                    put(px, x0 + dx, y, WATER if dx < 4 else blänk)
    return px


def accent_pol(px: list[list[int]]) -> list[list[int]]:
    """En pöl i golvet: en blöt fläck med vattenfärger. Den är den yta i våningen som SPEGLAR —
    därför ligger den i materialkartan och inte bara i bilden."""
    for y in range(SIZE):
        for x in range(SIZE):
            avstånd = ((x - 64) ** 2 + (y - 80) ** 2) ** 0.5
            kant = 38.0 + (wang(x // 12, y // 12, 95) - 0.5) * 12.0
            if avstånd < kant:
                put(px, x, y, WATER_L if avstånd > kant - 6.4 else WATER)
    return px


def alt_bräda(px: list[list[int]]) -> list[list[int]]:
    """Nyare bräda: en planka är bytt och står ljusare än de gamla.

    Bron hade en pöl (accent_pol, sedan accent_blöt) och den lästes fel hur den än målades: blekt
    vatten på bruna plankor ser ut som mögel, frost eller färgspill ("chalky mould, spilled paint").
    Vatten hör till STEN i den här våningen.

    Ett HÅL i golvet var nästa försök och det är sämre: på en bro läses en mörk lucka som en fara
    ("a gap leading into the abyss → unnecessary player hesitation"), och våningen har ingen fara att
    falla i. En ljusare planka ger samma variation utan att lova något som inte finns.
    """
    for y in range(12, 120):
        for x in range(32, 64):
            put(px, x, y, WOOD_L if y % 12 > 3 else DIRT)     # nyslipad, ljusare ådring
    for y in range(12, 120):
        for x in (32, 33, 34, 35, 60, 61, 62, 63):
            put(px, x, y, DIRT_D)                             # skarven mot grannplankorna
    for x, y in ((40, 24), (52, 88), (40, 100), (52, 36)):    # spikhuvuden
        for dy in range(4):
            for dx in range(4):
                put(px, x + dx, y + dy, MORTAR)
    return px


def accent_blöt(px: list[list[int]]) -> list[list[int]]:
    """Blött brädgolv: vätan följer BRÄDORNA i stället för att ligga som en pöl ovanpå dem.

    Bron är plankor. En organisk pöl mitt på en planka läses som fel: \"är bron översvämmad, eller är
    det en texturglitch?\" (Alex: *\"jag vet inte vad det skall föreställa på golvet\"*). Vatten rinner
    i springorna, så vätan ligger som mörka, glansiga ränder i två springor och en tunn blänk i dem.
    Masken (vattnet) blir två smala band — shadern ger dem glans och krusning som förut.
    """
    for x in range(SIZE):
        for y in range(SIZE):
            if x % 32 >= 28:                                  # springorna mellan plankorna
                if 12 <= y % 64 <= 46:
                    put(px, x, y, WATER)                      # vattenfilmen i springan
                elif wang(x // 4, y // 4, 77) < 0.35:
                    put(px, x, y, DIRT_D)
            elif 20 <= x < 28 and 16 <= y % 64 <= 42:
                # Blött trä blir MÖRKARE, det blir inte vitt: vätan ligger som mörk, glansig planka
                # intill springan med en tunn blänk överst. (Vision: "wet wood typically darkens the
                # planks rather than coating them in light opaque pigment" — chalky = mögel.)
                if y % 64 < 20:
                    put(px, x, y, WATER_L)
                elif x < 24:
                    put(px, x, y, DIRT_D)
                elif wang(x // 4, y // 4, 78) < 0.6:
                    put(px, x, y, DIRT_D)
    return px


def accent_sot(px: list[list[int]]) -> list[list[int]]:
    """Tunnelns vägg: sot i taket och en gruvlampa. Lampan är märket som gör att rummet läses som
    BEBOTT — berg och jord gör det inte."""
    for x in range(SIZE):
        for y in range(24):
            if wang(x // 4, y // 4, 91) < 0.7:
                put(px, x, y, DARK)
    for x in range(96, 112):
        for y in range(40, 56):
            put(px, x, y, FLAME if abs(x - 102) + abs(y - 46) < 10.0 else EMBER)
    return px


def accent_ras(px: list[list[int]]) -> list[list[int]]:
    """Brons golv: en rasad planka. Man ser NER i mörkret under bron — det är hela poängen med att
    gå på en bro inne i en jättegrotta."""
    for x in range(44, 88):
        djup = 4 * (2 + int(wang(x // 4, 0, 93) * 3))        # samma djup i meter, i dubbla pixlar
        for y in range(SIZE):
            if y < djup or y > SIZE - 1 - djup:
                put(px, x, y, INK if wang(x // 4, y // 4, 97) < 0.7 else DARK)
    return px


def alt_spricka(färg: int):
    def f(px: list[list[int]]) -> list[list[int]]:
        for i in range(SIZE):
            j = 4 * (i // 8)                     # samma lutning i meter, sprickan fyra pixlar bred
            for dy in range(4):
                put(px, i, j + dy, färg)
                put(px, i, j + 4 + dy, MORTAR)
        return px
    return f


def alt_gravhall(px: list[list[int]]) -> list[list[int]]:
    """Kryptans golv: gravhällar, 32 px (en kvarts meter) med benkant — rummet ska läsa som grav."""
    for x in range(SIZE):
        for y in range(SIZE):
            if x % 64 < 4 or y % 64 < 4:
                put(px, x, y, BONE_D)
            elif x % 64 < 8 or y % 64 < 8:
                put(px, x, y, BONE)
    return px


def alt_trappa(px: list[list[int]]) -> list[list[int]]:
    """Trappan ned: steg i ljus sten. Samma FORM i varje tema — trappan ska kännas igen på formen,
    inte på färgen."""
    for i, y in enumerate(range(24, 104, 20)):
        for x in range(16, 112):
            for dy in range(4):
                put(px, x, y + dy, EDGE_L if i % 2 == 0 else PALE)
            for dy in range(4, 8):
                put(px, x, y + dy, DARK)
    return px


## Fyra varianter av varje roll, inte EN. Mätt i referensbygget (research/09): per biom finns 33-51
## rut-prefabs i 2-3 lager, och `DairyPlant_Corridor_Straight_01…07` är sju ritningar av samma korridor.
## Variationen sitter alltså i varianter av SAMMA roll. Vi hade två (hel och sliten) — här är fem.
##
## VARFÖR FEM OCH INTE TRE. Super-rutorna (se write_tiles) är fyra ordningar av basvarianterna, och
## spelet väljer en av dem per ruta. Med TRE varianter blev två av de fyra ordningarna IDENTISKA —
## mätt: `wall_super_0.png` och `wall_super_3.png` var samma bild, byte för byte, eftersom k=0 och
## k=3 ger samma följd när listan är tre lång. En fjärdedel av väggens variation var alltså ingen
## variation alls. Med fem varianter är de fyra ordningarna fyra olika bilder, och tillsammans
## använder de fem av fem varianter i stället för tre. Grinden mäter det (se check).
##
## Varje roll får fem varianter med olika dragning (hel, väta, sot/spricka, kross) eftersom det är
## skillnaden mellan dem som syns. Slit-rutorna (wall_moss, floor_crack) byggs ovanpå och hör till
## slitaget, som spelet lägger ut i partier med sina egna plattor.
TEMA: dict[str, dict] = {
    "asklunden": {
        "wall": lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L),
        "wall_moss": lambda: accent_mossa(murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L)),
        "wall_2": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 1),
        "wall_3": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 2),
        "wall_4": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 5),
        "wall_5": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 6),
        "floor": lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L),
        "floor_crack": lambda: alt_spricka(RED_D)(murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L)),
        "floor_2": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 3),
        "floor_3": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 4),
        "floor_4": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 7),
        "floor_5": variant(lambda: murverk((STONE_D, STONE, STONE_L), MORTAR, EDGE_L), 8),
        "ceiling": lambda: plankor((DARK, MORTAR, DARK), INK),
    },
    "krypta": {
        "wall": lambda: murverk((MORTAR, STONE_D, STONE), DARK, STONE_L),
        "wall_moss": lambda: accent_nischer(murverk((MORTAR, STONE_D, STONE), DARK, STONE_L)),
        "wall_2": variant(lambda: murverk((MORTAR, STONE_D, STONE), DARK, STONE_L), 1),
        "wall_3": lambda: alt_spricka(INK)(murverk((MORTAR, STONE_D, STONE), DARK, STONE_L)),
        "wall_4": variant(lambda: murverk((MORTAR, STONE_D, STONE), DARK, STONE_L), 5),
        "wall_5": variant(lambda: murverk((MORTAR, STONE_D, STONE), DARK, STONE_L), 6),
        "floor": lambda: murverk((DARK, MORTAR, STONE_D), INK, STONE),
        "floor_crack": lambda: alt_gravhall(murverk((DARK, MORTAR, STONE_D), INK, STONE)),
        "floor_2": variant(lambda: murverk((DARK, MORTAR, STONE_D), INK, STONE), 3),
        "floor_3": variant(lambda: murverk((DARK, MORTAR, STONE_D), INK, STONE), 4),
        "floor_4": variant(lambda: murverk((DARK, MORTAR, STONE_D), INK, STONE), 7),
        "floor_5": variant(lambda: murverk((DARK, MORTAR, STONE_D), INK, STONE), 8),
        "ceiling": lambda: plankor((INK, DARK, MORTAR), MORTAR),
    },
    "grotta": {
        "wall": lambda: berg((CAVE_D, CAVE, CAVE_L), MORTAR),
        "wall_moss": lambda: accent_vatten(berg((CAVE_D, CAVE, CAVE_L), MORTAR)),
        "wall_2": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), MORTAR), 1),
        "wall_3": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), MORTAR), 2),
        "wall_4": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), MORTAR), 5),
        "wall_5": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), MORTAR), 6),
        # Golvet är TVÅ ton, inte tre. Med den ljusa tredje tonen (CAVE_L) blev en tredjedel av
        # rutans yta en ljus stenfläck, och på en golvruta som upprepas 2x2 per meter läses varje
        # fläck som ett FÖREMÅL: Alex såg "grå kullar på nästan varje golvruta" och kunde inte säga
        # vad de föreställde. Väggarna (som är vertikala) behåller kontrasten — där är ljuset rimligt.
        # Golvets kross är därför MÖRK mot mörk (sten=CAVE_D, ljus sida=CAVE): formen syns på kanten,
        # inte på ljusheten, och då läses den inte som ett föremål.
        # Golvet: EN lång spricka, inte två. En lång spricka är ett igenkännbart märke, och en
        # golvruta upprepas 2x2 per meter — två märken per ruta blir "samma spricka var halvmeter"
        # (bedömt på bild: "the eye instantly spots these identical cracks repeating"). Väggen bär
        # två; den ses i svep och är mörk.
        "floor": lambda: berg((CAVE_D, CAVE, CAVE), CAVE_D, 1),
        "floor_crack": lambda: accent_pol(berg((CAVE_D, CAVE, CAVE), CAVE_D, 1)),
        "floor_2": variant(lambda: berg((CAVE_D, CAVE, CAVE), CAVE_D, 1), 3),
        "floor_3": variant(lambda: berg((CAVE_D, CAVE, CAVE), CAVE_D, 1), 4),
        "floor_4": variant(lambda: berg((CAVE_D, CAVE, CAVE), CAVE_D, 1), 7),
        "floor_5": variant(lambda: berg((CAVE_D, CAVE, CAVE), CAVE_D, 1), 8),
        "ceiling": lambda: berg((INK, CAVE_D, DARK), INK),
    },
    "tunnel": {
        "wall": lambda: jord((DIRT_D, DIRT, WOOD_L), DIRT_D, WOOD_L),
        "wall_moss": lambda: accent_sot(jord((DIRT_D, DIRT, WOOD_L), DIRT_D, WOOD_L)),
        "wall_2": variant(lambda: jord((DIRT_D, DIRT, WOOD_L), DIRT_D, WOOD_L), 1),
        "wall_3": variant(lambda: jord((DIRT_D, DIRT, WOOD_L), DIRT_D, WOOD_L), 2),
        "wall_4": variant(lambda: jord((DIRT_D, DIRT, WOOD_L), DIRT_D, WOOD_L), 5),
        "wall_5": variant(lambda: jord((DIRT_D, DIRT, WOOD_L), DIRT_D, WOOD_L), 6),
        "floor": lambda: jordgolv(DIRT_D, DIRT, WOOD_L),
        "floor_crack": lambda: alt_trappa(jordgolv(DIRT_D, DIRT, WOOD_L)),
        "floor_2": variant(lambda: jordgolv(DIRT_D, DIRT, WOOD_L), 3),
        "floor_3": variant(lambda: jordgolv(DIRT_D, DIRT, WOOD_L), 4),
        "floor_4": variant(lambda: jordgolv(DIRT_D, DIRT, WOOD_L), 7),
        "floor_5": variant(lambda: jordgolv(DIRT_D, DIRT, WOOD_L), 8),
        "ceiling": lambda: plankor((DIRT_D, DIRT, WOOD_L), DIRT_D),
    },
    "bro": {
        # Brons berg är GROTTANS berg — samma sten, samma färger — men inte samma DRAGNING: salt 47 i
        # stället för 41 (se berg om saltet). Före: reliefen var identisk med grottans pixel för pixel
        # och bara fogfärgen skilde (9 steg i medelfärg, 12-18 % av pixlarna) — två rum som såg ut som
        # samma rum. Efter: samma material (±5 gråsteg i ljushet över alla fem varianter) och 92 % av
        # mönstret olikt. Grinden mäter det (se check, "samma ruta i två teman").
        "wall": lambda: berg((CAVE_D, CAVE, CAVE_L), INK, salt=47),
        "wall_moss": lambda: accent_vatten(berg((CAVE_D, CAVE, CAVE_L), INK, salt=47)),
        "wall_2": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), INK, salt=47), 1),
        "wall_3": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), INK, salt=47), 2),
        "wall_4": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), INK, salt=47), 5),
        "wall_5": variant(lambda: berg((CAVE_D, CAVE, CAVE_L), INK, salt=47), 6),
        "floor": lambda: tragolv((WOOD_L, DIRT, DIRT_D)),
        # Ingen pöl på bron: en trasig planka (se alt_bräda om varför).
        "floor_crack": lambda: alt_bräda(tragolv((WOOD_L, DIRT, DIRT_D))),
        "floor_2": variant(lambda: tragolv((WOOD_L, DIRT, DIRT_D)), 3),
        "floor_3": variant(lambda: tragolv((WOOD_L, DIRT, DIRT_D)), 4),
        "floor_4": variant(lambda: tragolv((WOOD_L, DIRT, DIRT_D)), 7),
        "floor_5": variant(lambda: tragolv((WOOD_L, DIRT, DIRT_D)), 8),
        # Bron får sitt EGET tak: (DARK, MORTAR) var samma bild byte för byte som asklundens tak —
        # mätt, 0 av 4096 pixlar skilde. plankorna läses av t[0] och t[1] (den tredje är oanvänd), så
        # taket är ritat i brons eget trä (golvets WOOD_L/DIRT_D) i stället: samma konstruktion, annat
        # virke, och 81 palettsteg från asklundens tak.
        "ceiling": lambda: plankor((WOOD_L, DIRT_D, WOOD_L), INK),
    },
}


def vatten_ruta(px: list[list[int]]) -> list[int] | None:
    """[x, y, w, h] i pixlar för rutans vatten, eller None om rutan är torr.

    Kartan är ritad av koden, men bara koden vet VAR i rutan vattnet ligger. Spelet behöver veta det
    för att kunna lägga sin blanka platta (krusningen som rör sig) på rätt ställe i stället för att
    gissa — och för att veta var dropparna ska falla.
    """
    punkter = [(x, y) for y in range(SIZE) for x in range(SIZE) if px[y][x] in (WATER, WATER_L)]
    if not punkter:
        return None
    xs = [p[0] for p in punkter]
    ys = [p[1] for p in punkter]
    return [min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1]


def vatten_mask(px: list[list[int]], pal: list[tuple[int, int, int]]) -> Image.Image | None:
    """Vattnet som RGBA: vattnet i palettens färger, allt annat genomskinligt.

    Pölens platta i spelet är den här formen — inte en rektangel. Utan masken blev pölen ett fyrkantigt
    glaslock över en rund vattenfläck, med synliga kanter.
    """
    if not any(px[y][x] in (WATER, WATER_L) for y in range(SIZE) for x in range(SIZE)):
        return None
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            if px[y][x] in (WATER, WATER_L):
                r, g, b = pal[px[y][x]]
                img.putpixel((x, y), (r, g, b, 255))
    return img


def dela_kant(px: list[list[int]], bas: list[list[int]]) -> list[list[int]]:
    """Ger rutan sin BASvarianters ytterkant, så alla varianter möts utan söm.

    Utan det här går super-rutorna inte att bygga: rutorna är var för sig sömlösa, men kanten mellan
    två OLIKA varianter i samma ark möts inte — mätt blev skarven 28 gråsteg mot 7,9 invändigt, och
    det syns som block i väggen. Med gemensam kant är vilken ordning som helst sömlös, och bara
    rutornas inre skiljer.
    """
    if len(px) != len(bas) or len(px[0]) != len(bas[0]):
        return px
    s = len(px)
    # Kanten är två pixlar i 128-rutan (en pixel i 64-rutan): annars blir den mötande kanten en halv
    # pixel bred i meter, alltså en tunnare söm än varianten intill har.
    b = SIZE // 64
    for i in range(s):
        for k in range(b):
            px[k][i], px[s - 1 - k][i] = bas[k][i], bas[s - 1 - k][i]
            px[i][k], px[i][s - 1 - k] = bas[i][k], bas[i][s - 1 - k]
    return px


def write_tiles(pal: list[tuple[int, int, int]]) -> None:
    for tema, ytor in TEMA.items():
        d = OUT_DIR / tema
        d.mkdir(parents=True, exist_ok=True)
        vatten: dict[str, list[int]] = {}
        for name, build in ytor.items():
            px = build()
            # Varianterna delar kant med sin bas (wall_2/wall_3 med wall osv), annars blir varje
            # möte mellan två varianter i ett super-ark en synlig söm. Siffran i slutet är det som
            # avgör (wall_4, floor_5) — med tre varianter räckte "_2"/"_3", och då hade en fjärde
            # variant fått sin EGEN kant och lämnat en söm i super-arket.
            if name[-1].isdigit():
                basnamn = "wall" if name.startswith("wall") else "floor"
                if basnamn in ytor:
                    px = dela_kant(px, ytor[basnamn]())
            img = Image.new("RGB", (SIZE, SIZE))
            for y in range(SIZE):
                for x in range(SIZE):
                    img.putpixel((x, y), pal[px[y][x]])
            img.save(d / f"{name}.png")
            # 2.5D: höjd -> normal, råhet/metall -> ORM. Samma ruta, samma namn + _n / _orm, så
            # spelet hittar dem utan att någon behöver lista vilka som finns.
            h, r, m = material(px)
            # Samma höjd till båda kartorna: normalen läser lutningen, ocklusionen hur djupt pixeln
            # ligger. Två kartor ur EN höjd kan inte säga olika saker om var fogen är.
            hh = jämna(h)
            normal_karta(hh).save(d / f"{name}_n.png")
            orm_karta(hh, r, m).save(d / f"{name}_orm.png")
            ruta = vatten_ruta(px)
            if ruta:
                vatten[name] = ruta
            mask = vatten_mask(px, pal)
            if mask:
                mask.save(d / f"{name}_vatten.png")
            print("  %s (+ _n, _orm%s%s)" % ((d / f"{name}.png").relative_to(ROOT),
                ", vatten %s" % ruta if ruta else "", ", _vatten.png" if mask else ""))
        # Super-rutor: de fyra varianterna i 2x2, i fyra olika ORDNINGAR. Kombinationen upprepar sig
        # då över fyra meter i stället för en, och det är upprepningsavståndet ögat läser — inte
        # antalet bilder (Grimrock: 1024 px per 3x3 m mot våra 128 px per 0,5 m).
        #
        # Bara BASvarianterna: slit-rutorna (wall_moss, floor_crack) hör till slitaget, som spelet
        # lägger ut i partier med sina egna plattor. Låg de i bas-arket skulle en röd spricka eller en
        # pöl målas i var fjärde ruta — och den blöta rutan har sin blanka platta utlagd på bestämda
        # rutor, så en målad pöl hade glänst där ingen platta ligger.
        SLITNA = ("wall_moss", "floor_crack")
        for grupp in ("wall", "floor"):
            bas = [n for n in sorted(ytor) if n.startswith(grupp) and n not in SLITNA and vatten.get(n) is None]
            if len(bas) < 2:
                continue
            for k in range(4):
                ordning = [bas[(i + k) % len(bas)] for i in range(4)]
                ark = Image.new("RGB", (SIZE * 2, SIZE * 2))
                ark_n = Image.new("RGB", (SIZE * 2, SIZE * 2))
                ark_o = Image.new("RGB", (SIZE * 2, SIZE * 2))
                for i, namn in enumerate(ordning):
                    pos = ((i % 2) * SIZE, (i // 2) * SIZE)
                    ark.paste(Image.open(d / f"{namn}.png"), pos)
                    ark_n.paste(Image.open(d / f"{namn}_n.png"), pos)
                    ark_o.paste(Image.open(d / f"{namn}_orm.png"), pos)
                ark.save(d / f"{grupp}_super_{k}.png")
                ark_n.save(d / f"{grupp}_super_{k}_n.png")
                ark_o.save(d / f"{grupp}_super_{k}_orm.png")
            print("  %s (+ 4 super-rutor, %d varianter: %s)"
                % ((d / f"{grupp}_super_0.png").relative_to(ROOT), len(bas), ", ".join(bas)))

        # Vattnet som egen fil: spelet läser den för pölar och droppar. En torr våning får ingen fil.
        v = d / "_vatten.json"
        if vatten:
            v.write_text(json.dumps(vatten, indent=1) + "\n")
        elif v.exists():
            v.unlink()


def seam_cost(px: list[list[int]]) -> tuple[float, float, float]:
    """(skarv, värsta kant inuti rutan, medelkant) i palettsteg.

    Skarven jämförs med den VÄRSTA kanten inuti rutan, inte med medelkanten: en ruta med mönster
    har hårda kanter även inuti, och en skarv som ser ut som en sådan kant syns inte.
    """
    def dist(a: int, b: int) -> float:
        return abs(a - b)

    över = sum(dist(px[y][0], px[y][SIZE - 1]) for y in range(SIZE)) / SIZE
    lod = sum(dist(px[0][x], px[SIZE - 1][x]) for x in range(SIZE)) / SIZE
    kanter = [dist(px[y][x], px[y][x + 1]) for y in range(SIZE) for x in range(SIZE - 1)]
    kanter += [dist(px[y][x], px[y + 1][x]) for x in range(SIZE) for y in range(SIZE - 1)]
    return max(över, lod), max(kanter), sum(kanter) / len(kanter)


## Varianternas två gränser i palettsteg. Under den undre är de samma ruta två gånger, över den
## övre är de olika material. Mätt mellan de fem temanas varianter: 2,2 steg (ingen variation) upp
## till 33 steg (mörkare berg) — båda felen fångas här.
## Andel pixlar som måste skilja för att två varianter ska räknas som två dragningar, och hur många
## gråsteg de får skilja i medelljus innan de är olika material.
##
## Mätt över de fem temana: samma ruta två gånger gav 0,1 %, en spricka som enda skillnad 3,9 %, ett
## annat frö i tegeltonerna 8 %, berg med annat frö 30-50 %. Tröskeln ligger därför på 3 % — den
## fångar det första och släpper de andra. Medelljuset skilde 0,2-14 steg mellan varianter som är
## samma material, så 15 är taket.
DUBBEL_ANDEL = 0.03
OLIK_LJUS = 15.0

## Samma RUTA i två teman: reliefen (mönstret) identisk OCH medelfärgen närmare än så här många
## palettsteg. Två rum i samma spel får inte vara samma rum.
##
## Mätt: grottans och brons sex väggrutor hade identisk relief pixel för pixel och skilde 7-10 steg i
## medelfärg (fogfärgen MORTAR mot INK var det enda som skilde) — bara färgen skilde, alltså samma
## berg två gånger. Brons tak var värre: 0 av 4096 pixlar skilde mot asklundens tak, samma bild byte
## för byte. Rutor som ÄR olika material ligger 30-150 steg isär (tak med annat virke mättes till 81),
## så 30 fångar båda felen och släpper allt som faktiskt är två olika ytor.
SAMMA_FÄRG = 30.0


def check(pal: list[tuple[int, int, int]]) -> int:
    fel = 0
    antal = 0
    mönster: dict[tuple[str, str], tuple[list[list[float]], list[float]]] = {}
    for tema, ytor in TEMA.items():
        for name, build in ytor.items():
            antal += 1
            px = build()
            färger = {c for rad in px for c in rad}
            utanför = sorted(c for c in färger if c < 0 or c >= len(pal))
            medel = sum(sum(pal[c][0] + pal[c][1] + pal[c][2] for c in rad) / 3 / SIZE for rad in px) / SIZE
            skarv, värsta, kant = seam_cost(px)
            # 2.5D-kartorna: normalen ska peka ut ur ytan (hög blå), ÄNDÅ inte vara platt, och ha en
            # HÅRD lutning längs kanterna (90-percentilen) — det är den Alex mäter och den fackelsken
            # läser. Samma höjd till båda kartorna, som i write_tiles.
            h, r, m = material(px)
            hh = jämna(h)
            # Rutans mönster och dess medelfärg, till par-jämförelsen längst ner: en ruta som delar
            # mönster med en annan ruta i ett annat tema får bara göra det om färgen skiljer.
            mönster[(tema, name)] = (hh, [sum(sum(pal[c][i] for c in rad) for rad in px) / (SIZE * SIZE)
                                          for i in range(3)])
            n = normal_karta(hh)
            blå = [n.getpixel((x, y))[2] for y in range(SIZE) for x in range(SIZE)]
            lut_medel, lut_p90 = lutning(n)
            # Ocklusionen (ORM, R) ska BÄRA data: platt höjd ger 255 överallt, alltså ingen
            # kontaktmörkring i fogarna. Spannet mäts, inte ett enstaka värde — en ruta där bara en
            # pixel skiljer är lika tom som en platt.
            o = orm_karta(hh, r, m).tobytes()
            ao = [o[i] for i in range(0, len(o), 3)]
            vatten = [r[y][x] for y in range(SIZE) for x in range(SIZE) if px[y][x] in (WATER, WATER_L)]
            relief_ok = min(blå) < 250 and sum(blå) / len(blå) > 200 and lut_p90 >= REL_P90
            ao_ok = max(ao) - min(ao) >= 20
            vatten_ok = not vatten or min(vatten) < 0.3
            # Vattenrektangeln är det spelet lägger sin blanka platta på. Ligger den utanför rutan
            # hamnar pölen vid sidan av vattnet (eller utanför golvet), och en mask utan rektangel
            # (eller tvärtom) betyder att spelet och generatorn inte är överens om samma ruta.
            ruta = vatten_ruta(px)
            # ponytail: kontrollen mäter rutan, inte att filen finns — filerna skrivs av körningen
            # utan --check, och en kontroll som kräver en tidigare körning mäter fel sak.
            ruta_ok = ruta is None or (0 <= ruta[0] and 0 <= ruta[1]
                and ruta[0] + ruta[2] <= SIZE and ruta[1] + ruta[3] <= SIZE and ruta[2] > 1 and ruta[3] > 1)
            ok = (not utanför and 20 < medel < 215 and skarv <= värsta + 0.5 and relief_ok and ao_ok
                and vatten_ok and ruta_ok)
            if not ok:
                fel += 1
            # Nätet, MÄTT: radhöjderna (ojämnheten) och hur stor andel av stenarna som slogs ihop.
            # Det är de två talen den förra skrivaren gissade om ("bara hälften av hällarna slås
            # ihop") — nu står de i utskriften i stället för i en mening.
            nät = ""
            if getattr(px, "rader", None):
                nät = "  nät %d rader %d-%d  ihop %2.0f%%" % (
                    len(px.rader), min(px.rader), max(px.rader), px.ihop * 100.0)
            print("  %-9s %-12s %s  färger %2d/%d  ljushet %3.0f  skarv %.2f/%.2f  relief z %3d-%3d"
                "  lutning %4.1f/%4.1f  ocklusion %3d-%3d  vattenråhet %s%s"
                % (tema, name, "ok " if ok else "FEL", len(färger), len(pal), medel, skarv, värsta,
                min(blå), max(blå), lut_medel, lut_p90, min(ao), max(ao),
                ((" %.2f %s" % (min(vatten), ruta)) if vatten else "—"), nät))
            if utanför:
                print("      färger utanför paletten: %s" % utanför)
    # Varianterna: de ska SKILJA sig (annars är de samma ruta två gånger — mätt: två av fem teman
    # skilde bara 2 gråsteg, alltså ingen variation alls) och ändå vara SAMMA material (skiljer de
    # för mycket läses de som olika sten, och då är det inte en variant utan ett annat tema).
    #
    # Grinden mäter det generatorn faktiskt producerar. Rutorna i spelvyn mäts INTE här — de skrivs
    # av körningen utan --check (se ponytail-noten ovan), och den här kontrollen ska kunna säga 'fel'
    # utan att en tidigare körning har gjort filerna.
    for tema, ytor in TEMA.items():
        for grupp in ("wall", "floor"):
            egna = [n for n in sorted(ytor) if n.startswith(grupp) and n not in ("wall_moss", "floor_crack")]
            if len(egna) < 2:
                continue
            px, ljus = [ytor[n]() for n in egna], []
            for ruta in px:
                ljus.append(sum(sum(pal[c][0] + pal[c][1] + pal[c][2] for c in rad) / 3 / SIZE
                    for rad in ruta) / SIZE)
            for i in range(len(px)):
                for j in range(i + 1, len(px)):
                    olika = sum(1 for y in range(SIZE) for x in range(SIZE)
                        if px[i][y][x] != px[j][y][x]) / (SIZE * SIZE)
                    if olika < DUBBEL_ANDEL:
                        print("  FEL  %s %s/%s skiljer bara %.1f %% av pixlarna — inte en variant"
                            % (tema, egna[i], egna[j], olika * 100))
                        fel += 1
                    elif abs(ljus[i] - ljus[j]) > OLIK_LJUS:
                        print("  FEL  %s %s/%s skiljer %.0f gråsteg — olika material, inte varianter"
                            % (tema, egna[i], egna[j], abs(ljus[i] - ljus[j])))
                        fel += 1
    # UPPREPNINGEN. Super-rutorna byggs av basvarianterna i fyra ordningar (se write_tiles), och
    # spelet väljer en av dem per ruta: en av de fyra ska vara samma upprepning som en annan.
    #
    # Grinden finns för att det felet REDAN HADE HÄNT och ingen mätte det: med tre varianter ger
    # k=0 och k=3 samma följd (listan är kortare än fyra), så `wall_super_0.png` och
    # `wall_super_3.png` var samma bild byte för byte — en fjärdedel av väggens variation var
    # ingen. Varianternas par-grind ovan ser det inte (varianterna ÄR olika); det är ORDNINGARNA
    # som blev två. Mätt med sha256 över de fyra paren.
    for tema, ytor in TEMA.items():
        for grupp in ("wall", "floor"):
            bas = [n for n in sorted(ytor)
                   if n.startswith(grupp) and n not in ("wall_moss", "floor_crack")]
            if len(bas) < 2:
                continue
            ordningar = [tuple(bas[(i + k) % len(bas)] for i in range(4)) for k in range(4)]
            if len(set(ordningar)) != len(ordningar):
                upprepade = sorted({o for o in ordningar if ordningar.count(o) > 1})
                print("  FEL  %s %s: %d av super-rutorna är samma ordning (%s) — upprepningen är "
                    "kortare än de fyra rutorna"
                    % (tema, grupp, len(ordningar) - len(set(ordningar)),
                       " ".join("+".join(o) for o in upprepade)))
                fel += 1
            print("  %-9s %-12s super-rutorna: %s  (%d av %d varianter används)"
                % (tema, grupp, " | ".join("+".join(o) for o in ordningar),
                   len(set(sum(ordningar, ()))), len(bas)))
    # SAMMA MÖNSTER I TVÅ TEMAN (se SAMMA_FÄRG): reliefen identisk och färgen för lika. Grinden finns
    # för att felet REDAN HADE HÄNT: grottans och brons sex väggrutor var samma berg — identisk relief,
    # 9 stegs färgskillnad (fogfärgen) — och brons tak var asklundens tak byte för byte. Det syns inte
    # i någon enskild ruta; det syns när två rum ligger sida vid sida.
    par: dict[str, list[tuple[str, list[list[float]], list[float]]]] = {}
    for (tema, namn), (hh, färg) in mönster.items():
        par.setdefault(namn, []).append((tema, hh, färg))
    for namn, lista in par.items():
        for i in range(len(lista)):
            for j in range(i + 1, len(lista)):
                ta, ra, ca = lista[i]
                tb, rb, cb = lista[j]
                avstånd = sum((ca[k] - cb[k]) ** 2 for k in range(3)) ** 0.5
                if ra == rb and avstånd < SAMMA_FÄRG:
                    print("  FEL  %s: %s och %s har SAMMA mönster (medelfärgen skiljer bara %.0f steg)"
                        " — två rum går inte att skilja" % (namn, ta, tb, avstånd))
                    fel += 1
    print("%d rutor i %d teman (plus %d normal- och %d ORM-kartor), %d fel"
        % (antal, len(TEMA), antal, antal, fel))
    # DENSITETEN OCH TEXTURMINNET, mätta ur samma siffra som rutorna ritas med. Rutan är 0,5 m, alltså
    # är px/m = SIZE * 2 — det är den siffran Alex frågar efter när han säger "katigt". Minnet är per
    # karta: albedo, normal och ORM. Oformaterat (RGB8) är den övre gränsen, BC1 (4x4-block, Godots
    # VRAM-komprimering när texturen används i 3D) är vad den faktiskt kostar.
    super_rutor = 0
    for _tema, ytor in TEMA.items():
        for grupp in ("wall", "floor"):
            if len([x for x in ytor if x.startswith(grupp)
                    and x not in ("wall_moss", "floor_crack")]) >= 2:
                super_rutor += 4
    texturer = (antal + super_rutor) * 3
    pixlar = (antal + super_rutor * 4) * SIZE * SIZE
    print("  %d px per ruta (0,5 m) = %d px/m. %d texturer i %dx%d (%d rutor + %d super-rutor): "
        "%.1f MB oformaterat (RGB8), %.1f MB i VRAM (BC1)"
        % (SIZE, SIZE * 2, texturer, SIZE, SIZE, antal, super_rutor,
           pixlar * 3 * 3 / 1048576.0, pixlar * 3 * 0.5 / 1048576.0))
    return fel


def sheet(pal: list[tuple[int, int, int]]) -> None:
    """Kontaktkarta: alla teman staplade, ytorna i samma ordning som i main.gd. Att döma på bild —
    en tileset ingen har sett på är en tileset ingen har granskat.

    Två filer: albedon och normalerna. Normalerna är den karta som avgör om 2.5D:n är rätt — ser
    murbruket ut som en ås i stället för en fog syns det direkt här.
    """
    rader = list(TEMA.keys())
    kolumner = ["wall", "wall_moss", "floor", "floor_crack", "ceiling"]
    skala = 2                     # 2x128 = 256 px per ruta: samma arkstorlek som vid 64 px och 3x
    for läge in ("albedo", "normal"):
        img = Image.new("RGB", (len(kolumner) * SIZE * skala, len(rader) * SIZE * skala), pal[0] if läge == "albedo" else (128, 128, 255))
        for ry, tema in enumerate(rader):
            for rx, namn in enumerate(kolumner):
                px = TEMA[tema][namn]()
                if läge == "albedo":
                    bild = Image.new("RGB", (SIZE, SIZE))
                    for y in range(SIZE):
                        for x in range(SIZE):
                            bild.putpixel((x, y), pal[px[y][x]])
                else:
                    h, _, _ = material(px)
                    bild = normal_karta(jämna(h))
                for y in range(SIZE):
                    for x in range(SIZE):
                        f = bild.getpixel((x, y))
                        for dy in range(skala):
                            for dx in range(skala):
                                img.putpixel((rx * SIZE * skala + x * skala + dx,
                                    ry * SIZE * skala + y * skala + dy), f)
        ut = SHEET_FILE if läge == "albedo" else SHEET_FILE.with_name("_teman_normal.png")
        img.save(ut)
        print("kontaktkarta: %s" % ut.relative_to(ROOT))
    print("rader (uppifrån): %s" % " · ".join(rader))
    print("kolumner: %s" % " · ".join(kolumner))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="mät i stället för att skriva")
    ap.add_argument("--sheet", action="store_true", help="kontaktkarta att döma på bild")
    args = ap.parse_args()
    pal = load_palette()
    if args.check:
        return 1 if check(pal) else 0
    if args.sheet:
        sheet(pal)
        return 0
    write_tiles(pal)
    return 0


if __name__ == "__main__":
    sys.exit(main())
