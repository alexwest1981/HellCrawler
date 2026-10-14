#!/usr/bin/env python3
"""Klipper Alex' texturatlas i plattor och mäter dem, en fil per platta.

    python3 tools/gen_tex_atlas.py             # klipper, mäter och skriver game/assets/by/tex/
    python3 tools/gen_tex_atlas.py --kalkyl     # bara kontaktkartan (raderna med namn), inget skrivet
    python3 tools/gen_tex_atlas.py --prov       # kalkprovet: plattorna 2x2 sida vid sida
    python3 tools/gen_tex_atlas.py --kolla      # mäter om det som redan ligger på disk

Alex: *"Alex har gjort en riktig texturatlas ... använd den i stället för allt annat."* Atlaskopian
ligger i game/assets/by/tex/_atlas.png (mästerkopian — chatkatalogen den kom ifrån är ingen plats
för en tillgång). Det här skriptet är det ENDA som läser den: plattorna i samma katalog är dess
utklipp, och kör man skriptet igen får man samma filer igen.

MÄTT PÅ ATLASEN (6144x4096, RGB, ingen alfa, bakgrunden en mörk marinblå ~(18,22,30)):
fyra rader innehåll, mätta ur bildens EGNA radprofil (52-1007, 1068-2003, 2068-3235, 3312-3927 —
Alex mätte 956/944/1172/640 px, skriptet 956/936/1168/616: samma rader, mätt på varsitt sätt).
Kolumnerna hittas likadant: en kolumn som inte avviker från bakgrunden är en LUCKA, och plattorna
är det som ligger mellan luckorna. Luckorna mättes till 52-72 px (rad 1-3) respektive 44-84 px
(rad 4), så en lucka kortare än GLAPP = 30 px är innehåll i plattan och slås ihop med sin granne —
utan den raden sprängdes rad 4:s elva plattor i femton bitar (mätt).

DEKOR ELLER PLATTA. En platta som ska kaklas över en yta måste vara SÖMLÖS. Provet kaklar plattan
2x2 och jämför fogen (sista raden mot första, sista kolumnen mot första) med rutans EGNA inre kanter:
plattan har 254 kanter mellan grannrader och fogen är den 255:e. Fogens percentil bland dem är domen
— ligger den bland de värsta 5 % syns skarven som en linje där plattan upprepas. En fönsterruta, en
dörr, ett valv och en krenelerad mur KAN inte kaklas (de visar ett motiv), och de märks DEKOR i
stället: de läggs på EN yta, aldrig upprepade. Fogsiffran står kvar för dem också, som bevis på varför.

FÄRGERNA: palettavståndet mot game/assets/palette.json mäts och skrivs ut per platta (närmaste
palettfärg per pixel, medel). Plattorna kommer ur Alex' eget ark och ska hålla sig till hans färger.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROT = Path(__file__).resolve().parent.parent
## Utklippen ligger i en EGEN mapp under tex/: paketet Alex skickade (game/assets/by/tex/*.png) har
## plattor med samma namn (wood_planks, grass, dirt, roof_slate), och första försöket skrev över fyra
## av utklippen (mätt: grass.png gick från 256x256 till 512x512). Två uppsättningar plattor med samma
## namn får inte bo i samma mapp.
TEX = ROT / "game" / "assets" / "by" / "tex" / "atlas"
ATLAS = TEX / "_atlas.png"
BILD = TEX / "_kalkprov.png"
KONTAKT = Path.home() / ".hermes" / "cache" / "scratch" / "omd" / "atlas_kontakt.png"
PALETT = ROT / "game" / "assets" / "palette.json"

## Rutans kant, samma som projektets egna plattor (game/assets/tiles) och samma som UV-mappningen
## räknar med: 256 px = 0,5 m (tools/uv_byn.py).
RUTA_PX = 256
BAKGRUND = np.array([18, 22, 30])
AVVIKELSE = 30         # summerad kanalskillnad mot bakgrunden innan en pixel räknas som innehåll
GLAPP = 30             # lucka kortare än så är innehåll i plattan, inte en lucka mellan två
## Fogens gräns: kvoten fog/inre (skarven jämförd med rutans eget brus i samma ledd). Under 3
## kanalstegs-kvot skiljer sig inte skarven från rutans eget brus. MÄTT på projektets egna plattor
## (tools/gen_tiles.py --check) ligger deras fogar på 8-10 kanalsteg mot ett inre brus på 8-10 —
## alltså en kvot kring 1. Samma mått, samma dom.
SÖMLÖS_KVOT = 3.0

## (rad, kolumn) -> filnamn, sort och om plattan kaklas ("platta") eller ligger på EN yta ("dekor").
## Namnen är lästa ur bilden (se --kalkyl, kontaktkartan med namn under varje utklipp), inte ur en
## gissning: varje rad har 7 / 7 / 7 / 11 plattor, mätt ur atlasens egen kolumnprofil.
PLATTOR: dict[tuple[int, int], tuple[str, str, str]] = {
    # RAD 1 — mark och murverk
    (0, 0): ("cobblestone_grey",   "kullersten, grå, i jord", "platta"),
    (0, 1): ("cobblestone_brown",  "kullersten, brunorange, i jord", "platta"),
    (0, 2): ("cobblestone_mossy",  "kullersten med mossa i fogarna", "platta"),
    (0, 3): ("stone_wall_light",   "mursten, ljust hugg", "platta"),
    (0, 4): ("stone_wall_dark",    "mursten, mörkt hugg", "platta"),
    (0, 5): ("castle_merlons",     "krenelerad borgmur med tinnar", "dekor"),
    (0, 6): ("stone_arch",         "stenvalv med slutsten", "dekor"),
    # RAD 2 — husets delar
    (1, 0): ("wood_planks",        "träplankor med spik, hyvlade ränder", "platta"),
    (1, 1): ("timber_frame",       "korsvirke med puts mellan bjälkarna", "platta"),
    (1, 2): ("roof_tiles_red",     "röda takpannor i förband", "platta"),
    (1, 3): ("roof_slate",         "skiffertak, skivor i förband", "platta"),
    (1, 4): ("door_wood_iron",     "trädörr med järnband och ring", "dekor"),
    (1, 5): ("metal_riveted",      "nitslagen metall, hamrad", "platta"),
    (1, 6): ("forge_stone_glow",   "glödande smidessten, ugnens öppning", "dekor"),
    # RAD 3 — mark och växtlighet
    (2, 0): ("grass",              "gräs med små blommor", "platta"),
    (2, 1): ("stone_mossy",        "mossiga stenar", "platta"),
    (2, 2): ("ivy",                "murgröna över sten", "platta"),
    (2, 3): ("dirt",               "jord och lera", "platta"),
    (2, 4): ("dirt_stony",         "stenig jord", "platta"),
    (2, 5): ("clay_red",           "rödbrun lera", "platta"),
    (2, 6): ("sand_path",          "sandig stig", "platta"),
    # RAD 4 — fönster och små varianter
    (3, 0): ("window_four_pane",    "fyrdelat fönster med kraftig träram, varmt ljus", "dekor"),
    (3, 1): ("window_arched_stone", "valvformat fönster i stenmur, varmt ljus", "dekor"),
    (3, 2): ("window_round_stone",  "runt fönster med kors, stenram", "dekor"),
    (3, 3): ("window_tall_panes",   "högt sexdelat fönster med träram", "dekor"),
    (3, 4): ("window_diamond_lattice", "fönster med diamantgaller", "dekor"),
    (3, 5): ("window_narrow",       "smalt tvådelat fönster", "dekor"),
    (3, 6): ("timber_frame_small", "korsvirke, mindre platta", "platta"),
    (3, 7): ("wood_planks_small",  "plankor, mindre platta", "platta"),
    (3, 8): ("stone_wall_light_small", "ljus mursten, mindre platta", "platta"),
    (3, 9): ("stone_wall_dark_small",  "mörk mursten, mindre platta", "platta"),
    (3, 10): ("stone_wall_mossy_small", "mossig mursten, mindre platta", "platta"),
}


def font(storlek: int):
    for sökväg in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
                   "/usr/share/fonts/TTF/DejaVuSans.ttf"):
        if Path(sökväg).exists():
            return ImageFont.truetype(sökväg, storlek)
    return ImageFont.load_default()


def hitta(atlas: np.ndarray) -> list[list[tuple[int, int, int, int]]]:
    """Plattornas rutor ur bildens EGEN bakgrund: rader ur radprofilen, kolumner ur kolumnprofilen.

    Höjden mäts dessutom om PER PLATTA: radprofilen ger ett band som är alla sju plattornas
    union, och en enskild platta kan börja några pixlar in i bandet (mätt på krenelerade muren:
    bandet börjar på 52, plattan på 56). Med bandets kant hade de pixlarna blivit plattans överkant
    och fogen hade mätts mot bakgrunden i stället för mot motivet.
    """
    d = np.abs(atlas.astype(np.int16) - BAKGRUND).sum(axis=2)
    rader = []
    i = 0
    while i < d.shape[0]:
        if (d[i] > AVVIKELSE).mean() > 0.5:
            j = i
            while j < d.shape[0] and (d[j] > AVVIKELSE).mean() > 0.5:
                j += 1
            if j - i > 60:
                rader.append((i, j - 1))
            i = j
        else:
            i += 1
    ut = []
    for (y0, y1) in rader:
        tom = (d[y0:y1 + 1] > AVVIKELSE).mean(axis=0) < 0.02
        # Slå ihop bitar som skiljs av en för kort lucka: innehåll i plattan, inte en lucka.
        bitar = []
        k = 0
        while k < len(tom):
            if not tom[k]:
                m = k
                while m < len(tom) and not tom[m]:
                    m += 1
                if m - k > 30:
                    bitar.append([k, m - 1])
                k = m
            else:
                k += 1
        slått = []
        for bit in bitar:
            if slått and bit[0] - slått[-1][1] - 1 < GLAPP:
                slått[-1][1] = bit[1]
            else:
                slått.append(list(bit))
        rad = []
        for b in slått:
            andel = (d[y0:y1 + 1, b[0]:b[1] + 1] > AVVIKELSE).mean(axis=1)
            inne = np.nonzero(andel > 0.5)[0]
            rad.append((b[0], y0 + int(inne[0]), b[1], y0 + int(inne[-1])))
        ut.append(rad)
    return ut


def fog(ruta: Image.Image) -> dict:
    """Fogens styrka i båda ledderna, och hur den står sig mot rutans EGNA inre brus.

    Ett kanalsteg säger ingenting ensamt: en brusig pixeltextur har höga skillnader överallt.
    Domen är därför KVOTEN fog/inre — fogen jämförd med medel-|skillnaden| mellan två grannrader
    inuti plattan. Är kvoten nära 1 syns ingen skarv när plattan upprepas; är den 10 blir skarven
    en linje (mätt: Alex' atlas har kvoten 1,4-1,6 i SIDLED och 8-30 i HÖJDLED).
    """
    a = np.asarray(ruta.convert("RGB"), dtype=np.float64)
    inre_lod = float(np.abs(np.diff(a, axis=0)).mean())
    inre_tvär = float(np.abs(np.diff(a, axis=1)).mean())
    fog_lod = float(np.abs(a[0, :] - a[-1, :]).mean())
    fog_tvär = float(np.abs(a[:, 0] - a[:, -1]).mean())
    return {"fog_lod": fog_lod, "fog_tvär": fog_tvär,
            "inre_lod": inre_lod, "inre_tvär": inre_tvär,
            "kvot_lod": fog_lod / max(inre_lod, 1e-6),
            "kvot_tvär": fog_tvär / max(inre_tvär, 1e-6)}


def palettavstånd(ruta: Image.Image, palett: np.ndarray) -> float:
    """Medelavståndet från varje pixel till NÄRMASTE palettfärg (8-bitars kanaler).

    Pixlarna måste upp i 32 bitar först: (255-0)^2 = 65 025 ryms inte i int16, och rutan blev
    mätt till "nan" innan raden fanns (negativt tal under kvadratroten).
    """
    a = np.asarray(ruta.convert("RGB"), dtype=np.int32).reshape(-1, 3)
    bäst = np.full(len(a), 1e9)
    for p in palett.astype(np.int32):
        bäst = np.minimum(bäst, np.sqrt(((a - p) ** 2).sum(axis=1)))
    return float(bäst.mean())


def klipp(atlas: Image.Image, ruta: tuple[int, int, int, int]) -> Image.Image:
    """Plattan skalad till rutans mått — HELA plattan, inte en kvadrat ur mitten.

    Första försöket tog en kvadrat ur mitten (plattorna är 848x956, alltså inte kvadratiska) och
    skevade därmed mönstret 13 %. MÄTT: det klippte bort plattans ÖVER- och UNDERKANT, och det är
    just de kanterna som avgör om plattan kan kaklas. Hela plattan skalas därför i stället, i båda
    ledder — en skevning på 13 % syns inte på en kullersten, men en bortklippt kant gör att fogen
    mäts på fel ställe. Sidokanterna lämnas orörda: de är plattans egen ram, och med den kvar mäter
    sidledsfogen 5,5 kanalsteg (se tools/gen_tex_atlas.py --kolla).
    """
    bit = atlas.crop((ruta[0], ruta[1], ruta[2] + 1, ruta[3] + 1)).convert("RGB")
    return bit.resize((RUTA_PX, RUTA_PX), Image.LANCZOS)


def kör(klipp_ut: bool, kalkyl: bool, prov: bool, kolla: bool) -> int:
    if not ATLAS.exists():
        print("atlasen saknas: %s" % ATLAS, file=sys.stderr)
        return 1
    atlas = Image.open(ATLAS).convert("RGB")
    palett = np.array(json.loads(PALETT.read_text()), dtype=np.int16)

    if kolla:
        filer = sorted(f for f in TEX.glob("*.png") if not f.name.startswith("_"))
        print("=== %d utklippta plattor på disk ===" % len(filer))
        for f in filer:
            im = Image.open(f).convert("RGB")
            m = fog(im)
            print("  %-26s %dx%d fog sid %.1f (x%.1f) höjd %.1f (x%.1f) palett %.2f" %
                  (f.stem, im.width, im.height, m["fog_tvär"], m["kvot_tvär"],
                   m["fog_lod"], m["kvot_lod"], palettavstånd(im, palett)))
        return 0

    rader = hitta(np.asarray(atlas))
    print("=== ATLASEN %dx%d: %d rader, %s plattor ===" %
          (atlas.width, atlas.height, len(rader), "/".join(str(len(r)) for r in rader)))

    if kalkyl:
        KONTAKT.parent.mkdir(parents=True, exist_ok=True)
        bild = atlas.copy()
        d = ImageDraw.Draw(bild)
        f = font(30)
        for ri, rad in enumerate(rader):
            for ki, ruta in enumerate(rad):
                namn = PLATTOR.get((ri, ki), ("<%d,%d>" % (ri, ki), "", ""))[0]
                d.rectangle(ruta, outline=(255, 80, 80), width=3)
                d.text((ruta[0] + 6, ruta[1] + 6), namn, fill=(255, 240, 80), font=f)
        bild.resize((bild.width // 2, bild.height // 2), Image.LANCZOS).save(KONTAKT)
        print("kontaktkarta med namnen: %s" % KONTAKT)
        for ri, rad in enumerate(rader):
            print("  rad %d: %s" % (ri + 1, ", ".join(
                PLATTOR.get((ri, ki), ("<%d,%d>" % (ri, ki),))[0] for ki in range(len(rad)))))
        return 0

    # Klipp, mät och skriv.
    if klipp_ut:
        TEX.mkdir(parents=True, exist_ok=True)
    lista = []
    fel = 0
    for ri, rad in enumerate(rader):
        for ki, ruta in enumerate(rad):
            post = PLATTOR.get((ri, ki))
            if not post:
                print("FEL: rad %d platta %d saknar namn i PLATTOR" % (ri + 1, ki + 1))
                fel += 1
                continue
            namn, sort, slag = post
            im = klipp(atlas, ruta)
            m = fog(im)
            pal = palettavstånd(im, palett)
            kaklas = slag == "platta"
            # Domen: en KAKLAD platta måste vara sömlös i SIDLED (det är ledden en vägg upprepas i
            # mest) — kvoten fog/inre under 3 betyder att skarven inte skiljer sig från rutans eget
            # brus. Höjdledsfogen mäts och skrivs ut men fäller ingen: den går inte att klippa bort.
            sömlös = m["kvot_tvär"] < SÖMLÖS_KVOT
            ok = "ok  " if (not kaklas or sömlös) else "FOG "
            print("  %s %-26s %4dx%-4d  fog sid %5.1f (x%4.1f)  höjd %5.1f (x%5.1f)  palett %5.2f  %s" %
                  (ok, namn, ruta[2] - ruta[0] + 1, ruta[3] - ruta[1] + 1,
                   m["fog_tvär"], m["kvot_tvär"], m["fog_lod"], m["kvot_lod"], pal, slag))
            if kaklas and not sömlös:
                fel += 1
            lista.append({"fil": "%s.png" % namn, "sort": sort, "slag": slag, "px": RUTA_PX,
                          "källa": [ruta[0], ruta[1], ruta[2], ruta[3]],
                          "källa_px": [ruta[2] - ruta[0] + 1, ruta[3] - ruta[1] + 1],
                          "fog_sid": round(m["fog_tvär"], 2), "fog_höjd": round(m["fog_lod"], 2),
                          "kvot_sid": round(m["kvot_tvär"], 2), "kvot_höjd": round(m["kvot_lod"], 2),
                          "sömlös_sid": bool(sömlös), "palett": round(pal, 3)})
            if klipp_ut:
                im.save(TEX / ("%s.png" % namn))

    if klipp_ut:
        (TEX / "_plattor.json").write_text(
            json.dumps(lista, ensure_ascii=False, indent=1) + "\n")
        print("skrev %d plattor i %s" % (len(lista), TEX.relative_to(ROT)))

    if prov:
        kalkprov(lista)
    print("=== %d plattor, %d kaklade med för grov fog ===" % (len(lista), fel))
    return 1 if fel else 0


def kalkprov(lista: list) -> None:
    """Kalkprovet: varje KAKLAD platta 2x2 sida vid sida, i spelets täthet.

    En platta är 256 px och 0,5 m, alltså 512 px per meter — provet ritas därför i 512 px per
    platta (2x2 rutor), så det Alex ser är mönstret i den storlek det hamnar på väggen. Fogen syns
    som en linje mitt i varje prov: är den borta är plattan sömlös.
    """
    kaklade = [p for p in lista if p["slag"] == "platta"]
    if not kaklade:
        print("inga kaklade plattor att visa")
        return
    kant, text = RUTA_PX * 2, 46
    kol = 4
    rader = (len(kaklade) + kol - 1) // kol
    bild = Image.new("RGB", (kol * (kant + 16) + 16, rader * (kant + text + 16) + 16), (18, 22, 30))
    d = ImageDraw.Draw(bild)
    f = font(26)
    for i, p in enumerate(kaklade):
        im = Image.open(TEX / p["fil"]).convert("RGB")
        bx, by = 16 + (i % kol) * (kant + 16), 16 + (i // kol) * (kant + text + 16)
        for ry in range(2):
            for rx in range(2):
                bild.paste(im, (bx + rx * RUTA_PX, by + ry * RUTA_PX))
        d.rectangle((bx, by, bx + kant, by + kant), outline=(90, 96, 110), width=2)
        d.text((bx, by + kant + 8), "%s  (1 m)" % p["fil"][:-4], fill=(230, 226, 214), font=f)
    bild.save(BILD)
    print("kalkprov: %s (%dx%d, %d kaklade plattor, 1 m per prov)" %
          (BILD.relative_to(ROT), bild.width, bild.height, len(kaklade)))


if __name__ == "__main__":
    a = sys.argv[1:]
    raise SystemExit(kör(klipp_ut="--kalkyl" not in a and "--kolla" not in a,
                         kalkyl="--kalkyl" in a, prov="--prov" in a, kolla="--kolla" in a))
