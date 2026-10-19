"""BYN I 3D: varje hus byggs ur SIN EGEN bildyta i byns panoramabild, ut till glTF.

    /home/alex/.local/bin/blender -b --factory-startup --python tools/byn3d.py
    ... -- --kolla              # mät och kontrollera, rendera inte
    ... -- --bara smed          # bara EN plats
    ... -- --bild /tmp/x.png --ut /tmp/x.glb --narbild /tmp/n.png

VARFÖR ETT SKRIPT OCH INTE EN MODELL: 2,5D-vyns PLATSER (game/ui/village_view.gd) är redan
sanningen om vilka hus byn har och i vilken ordning de står — `x0`/`x1` är husets kropp i procent av
`byn.png`s bredd. Skriptet LÄSER de talen (samma regex som tools/gen_by_hus.py) och färgerna ur
game/assets/palette.json. En kopia av siffrorna här hade kunnat glida ifrån vyn utan att någon såg
det, och färgen får inte hittas på: palettfilen är enda sanningen för materialens färg.

HUSEN BYGGS UR BILDEN (M-ny). Förr var varje hus en generisk låda med en takplatta, dörr och två
fönster, och alla stod dörr i dörr. Alex: *"De skall spridas ut, men behöver även modelleras så de
ser ut som på bilden."* Nu kommer formen ur husets EGNA ruta i byn.png:

  * SILHUETTEN: för varje kolumn i husets ruta mäts husets överkant mot himlen — den första raden i
    en SAMMANHÄNGANDE husmassa (MIN_SOLID px i rad). Utan den raden blev dis och molnkanter i himlen
    en falsk skorsten (mätt: smedjans ruta hade 1-33 lösryckta "huspixlar" per rad 130 px över taket).
  * HÖJDSTEGEN ÄR EN MÄTNING, inte en konstant: konturen kvantiseras till ett steg per STEG_PIXLAR
    källpixlar i husets EGEN höjd. Förr var stegen 8, och då blev ett steg 111 px — en spetsig gavel
    med nock kunde inte ritas: taket blev platt, kroppen för bred och skorstenen nådde inte över
    nocken fast konsten visar den där. Ett rätblock per kolumnremsa och steg blir då tusentals lådor,
    så rutnätet (kolumn × steg) slås ihop till så få rätblock som möjligt — i sidled, i höjdled och
    mellan grannar vars färger ligger inom FÄRG_TOL. Samma princip som spelets Voxel._stäng:
    silhuetten ska bli REN, inte en randig trappa.
  * FÄRGEN: varje rätblock färgas av de pixlar det täcker i bilden (närmaste palettfärg i
    palette.json), mätt över ett grovt block. Bilden är INTE palettindexerad (mätt: 249 141 unika
    färger, 0 % exakta palettpixlar, 2,1 % inom |Δ|<10), så färgen är en NÄRMASTE träff över ett
    block — pixel för pixel blev fasaden ränder av bildens brus.
  * DETALJERNA: dörren sitter där bilden är som MÖRKAST i husets nederkant och är så bred och så hög
    som bilden visar; skylten sitter där väggen är som LJUSAST mellan dörren och takfoten (mätt: förr
    satt den på 78 % av höjden, nära taket, oavsett bilden). Torn och skorstenar kommer ur
    silhuetten. Ett DJUP per hus: annars blir varje remsa sin egen platta ut mot gatan och huset en
    färgpelare i stället för en fasad. Ässja, tunnor, tinnar, baner och facklor är ORDBOKEN från
    Alex' referensbyggnad, men färgerna är palettens.

SPRIDNINGEN: husen står på EN gata i PLATSER:s ordning med luft mellan sig — luften är 0,55 av
grannarnas medelbredd, och husens inbördes BREDDER är bildens (smedjan 550 px är den bredaste,
EXIT 356 px den smalaste). Kontrollen räknar parvis att inga hus' x-intervall skär varandra.

BAKGRUNDSLAGRET: bakom husen en stadsmur med torn, bakgrundshus, träd, berg och en kulle med får —
samma lager som i referensen, bara rätblock, och färgerna ur paletten (muren 22/7, bergen 20/21,
träden 15). Utan det står husen mot en tom himmel.

FORMSPRÅKET: bara rätblock, inga rundningar, inga avfasningar, inga högdetaljerade modeller — samma
platåiga voxelstil som spelets egen grafik.

UTFILER: game/assets/by/byn.glb (mesharna, importerbar i Godot), en renderad stillbild av hela byn,
en helhetsbild från spelets EGEN vinkel (ortografiskt rakt framifrån, se FRONTKAMERA) och en NÄRBILD
på ett hus bredvid dess egen bildyta. Provet `-- --kolla` håller räkningen i kontroll (ytor = 6 *
antal lådor), mäter att inga hus' x-intervall skär varandra, RENDERAR varje hus framifrån och mäter
modellens tak mot husets EGEN överkant i bilden (medel och störst, i bildpixlar, och riktningarna var
för sig) — och faller om dörren saknas eller drunknar i väggen, om skorstenen inte når över nocken
där bilden visar en skorsten, eller om skylten sitter mer än ett höjdsteg fel.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
VYN = ROOT / "game" / "ui" / "village_view.gd"
PALETT = ROOT / "game" / "assets" / "palette.json"
BYBILD = ROOT / "game" / "assets" / "ui" / "byn.png"
GLB = ROOT / "game" / "assets" / "by" / "byn.glb"
BILD = Path.home() / ".hermes" / "cache" / "scratch" / "omd" / "byn3d.png"
NÄRBILD = Path.home() / ".hermes" / "cache" / "scratch" / "omd" / "byn3d_nara.png"
## Spelets EGEN vinkel: 2.5D-konsten är ritad RAKT FRAMIFRÅN, så det är den vyn Alex känner igen sin
## by i. Ortografiskt, med referensens egna kameratal (plats, rotation, ortho_scale).
FRONTBILD = Path.home() / ".hermes" / "cache" / "scratch" / "omd" / "byn_front.png"
FRONTKAMERA = ((0.5, -22.0, 3.6), 1.5009831190109253, 34.0)

## Den bredaste platsen (smedjan, 550 px) blir så här bred i världen. 1 bildpixel = 0,0109 enheter.
BREDASTE_HUS = 6.0
## Luften mellan två grannar, som andel av deras medelbredd. Referensbyn: husen 2,8-5,6 breda med
## 1,1-2,0 luft mellan sig (centrum 4,5-5,7 isär) — samma sorts luft.
MELLANRUM = 0.55
## Husets djup som andel av dess bredd. Sidovyn säger ingenting om djupet: det är designat.
DJUP = 0.50
## Ett höjdsteg per så här många KÄLLPIXLAR i husets egen höjd. Det är en mätning av vad källan
## försvarar (1-3 px), inte en konstant: de gamla 8 stegen gav 111 px per steg på smedjan.
STEG_PIXLAR = 2.0
## Färgen mäts i block: FÄRGBAND_PX pixlar i höjdled och FÄRG_BLOCK av husets bredd i sidled. Bilden
## är brusig (249 141 unika färger), så en pixel-trogen färg blir ränder i stället för en vägg.
FÄRGBAND_PX = 24
FÄRG_BLOCK = 0.10
## Två grannblock vars palettfärger ligger närmare varandra än så här (8-bitars kanalavstånd) är
## SAMMA yta. Utan toleransen blir rutnätet randigt och huset en färgpelare.
FÄRG_TOL = 26
## Silhuetten: en kolumns överkant räknas först när så här många huspixlar ligger i rad — annars blir
## dis och molnkanter i himlen en falsk skorsten.
MIN_SOLID = 6
## Dörren: den mörkaste sektionen i husets nederkant. Söks i DÖRR_BAND (av husets höjd), är DÖRR_ANDEL
## av husets bredd och får inte bli högre än DÖRR_HÖJD_MAX av husets höjd.
DÖRR_BAND = 0.30
DÖRR_ANDEL = 0.16
DÖRR_HÖJD_MAX = 0.55
## Skylten: den LJUSASTE sektionen i väggen mellan dörren och takfoten — aldrig nära taket.
SKYLT_BAND = (0.30, 0.78)
SKYLT_HÖJD = 0.10
SKYLT_ANDEL = 0.30
## Modellens kontur ska följa bildens inom så här många BILDPIXLAR (källans egen upplösning). Ett
## tak som ligger mer än så UNDER bildens kontur är ett fel; det är den här raden som fäller en för
## grov kvantisering (mätt: 8 fasta höjdsteg gav 56-132 px under).
KONTUR_PX = 3.0
## Rätblocken följer bildens kontur inom ett par höjdsteg. En UTSMYCKNING (tinne, skyltbräda) sitter
## ovanpå och får sticka upp med högst så här mycket av husets höjd — utan undantaget hade portens
## tinnar fällt provet trots att kroppen sitter rätt, för tinnar sitter PÅ taket.
UTSMYCKNING = 0.04
## Bakgrundsfamiljer i paletten: himmel/blågrått, skogsgrönt och blekt (moln/dis). Det som ligger
## ovanför huset och hör till himlen eller åsen bakom.
FÄRG_HIMMEL = 26
FÄRG_BAKGRUND = {15, 20, 21, 25, 26}
## Fallback när bilden inte har någon mätbar detalj på den platsen (dörr, fönster, skylt).
FÄRG_DÖRR = 3
FÄRG_FÖNSTER = 8
FÄRG_SKYLT = 24
FÄRG_GATA = 24                      # mätt: gatans band 71-78 % domineras av 24/4 (kullersten)
FÄRG_MARK = 17                      # jordbrun mark runt gatan
FÄRG_GRÄS = 15
FÄRG_MUR = 22                       # mätt: bakgrundens ås i palettfamiljen gråbrun/benvit
FÄRG_BERG = 20
FÄRG_TRÄD = 15
FÄRG_ULLE = 8
## Alla platsers EGET kännetecken ur referensbyn (HUR delen byggs), keyed på id. Färgerna är palettens.
SAKER = {
    "tradet": {"sak": "tyg", "tyg": (11, 25)},       # väveriet: två tygrullar (rött och blått)
    "smed": {"sak": "ässja", "glöd": 13},            # smedjan: ässja med glöd + städ
    "vardshus": {"sak": "tunnor"},                   # tavernan: tunnor utanför dörren
    "karta": {"sak": "port"},                        # porten ut ur byn: tinnar, facklor, baner
    "juvelerare": {"sak": "juvel"},
    "avsluta": {"sak": "stolpe"},
}
## De sex platsernas ordning i PLATSER är gatuordningen vänster → höger (bilden).


# ------------------------------------------------------------------ spelets egen data


def läs_platser() -> tuple[list[dict], float, float]:
    """PLATSER ur village_view.gd: id, namn, x0, x1, färg — och bildens två höjdlinjer."""
    text = VYN.read_text(encoding="utf-8")
    m = re.search(r"const HUS_TOPP := ([\d.]+)", text)
    g = re.search(r"const BILDENS_GATA := ([\d.]+)", text)
    if not m or not g:
        raise SystemExit("FEL: hittar inte HUS_TOPP/BILDENS_GATA i %s" % VYN)
    rader = re.findall(
        r'\{"id": "([^"]+)", "namn": "([^"]+)"[^\n]*?"x0": ([\d.]+), "x1": ([\d.]+), "färg": (\d+)\}',
        text,
    )
    if len(rader) < 4:
        raise SystemExit("FEL: hittar inte PLATSER:s rutor i %s (%d rader)" % (VYN, len(rader)))
    platser = [
        {"id": i, "namn": n, "x0": float(a), "x1": float(b), "färg": int(f)}
        for i, n, a, b, f in rader
    ]
    return platser, float(m.group(1)), float(g.group(1))


def läs_palett() -> list[tuple[int, int, int]]:
    """Färgerna ur palette.json, i filens radordning. Index clampas som Palett.c() gör."""
    data = json.loads(PALETT.read_text(encoding="utf-8"))
    return [(int(r[0]), int(r[1]), int(r[2])) for r in data]


def färg(palett: list, i: int) -> tuple[int, int, int]:
    """Samma clamp som spelets Palett.c(i) — ett index utanför filen får filens sista färg."""
    return palett[max(0, min(len(palett) - 1, i))]


def ljushet(c) -> float:
    """Upplevd ljushet i en palettfärg (samma vikter som bildens luminans)."""
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def linjär(c8: tuple[int, int, int]) -> tuple[float, float, float]:
    """8-bitars sRGB → linjärt (Blender räknar i linjärt ljus, palettens tal är sRGB)."""

    def en(v: float) -> float:
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    return (en(c8[0]), en(c8[1]), en(c8[2]))


# ------------------------------------------------------------------ bilden


class Bild:
    """byn.png som pixlar. Läses med bpy (PIL finns inte i Blenders python), i sRGB-byte-värden.

    `colorspace_settings = 'Non-Color'` är det som gör att pixlarna kommer tillbaka som bildens EGNA
    byte-värden i stället för lineariserade tal — utan den raden hade varje färg mätts fel.
    """

    def __init__(self, sökväg: Path):
        if not sökväg.exists():
            raise SystemExit("FEL: byns bild saknas: %s" % sökväg)
        img = bpy.data.images.load(str(sökväg))
        img.colorspace_settings.name = "Non-Color"
        self.bredd, self.höjd = img.size
        buf = np.empty(self.bredd * self.höjd * 4, dtype=np.float32)
        img.pixels.foreach_get(buf)
        # Blender läser nedifrån och upp: vänd på raderna så rad 0 är bildens överkant.
        self.px = (buf.reshape(self.höjd, self.bredd, 4)[::-1, :, :3] * 255.0 + 0.5).astype(np.int32)
        rgb = self.px.astype(np.int32)
        r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
        # BAKGRUND = blå/dis (B > G >= R med marginal) eller blek (moln). Mätt: åsen bakom husen
        # ligger i samma färgfamilj som taken (gråbrun/skiffer), så himlen kan inte skiljas från
        # huset med enbart ljushet — blåheten är det som skiljer.
        self.bakgrund = ((b > g) & (g >= r) & (b - r > 15)) | (rgb.min(axis=2) > 168)
        # Ljusheten per pixel. Detaljerna (dörr, skylt) mäts mot husets EGEN ljushet och inte mot ett
        # fast tal: bildens hus ligger på median 74-89 av 255, så "mörk" med fast tröskel blev ett
        # slumpmässigt urval av kolumner i stället för den mörka sektionen.
        self.luminans = 0.2126 * r + 0.7152 * g + 0.0722 * b

    def topprader(self, y0: int, gata: int, x0: int, x1: int,
                  min_solid: int = MIN_SOLID) -> np.ndarray:
        """Husets överkant per kolumn: första raden i en SAMMANHÄNGANDE husmassa (min_solid rader).

        Mätt: smedjans ruta hade 1-33 lösryckta "huspixlar" per rad ända upp i rutans överkant (dis
        och molnkanter som inte är blå nog att kännas igen som himmel). Utan kravet på sammanhang
        blev de en falsk skorsten så hög som hela rutan. Kolumner utan hus alls får gata (profil 0).
        """
        m = ~self.bakgrund[y0:gata, x0:x1]
        löp = np.zeros(m.shape, dtype=np.int32)
        nästa = np.zeros(m.shape[1], dtype=np.int32)
        for rad_i in range(m.shape[0] - 1, -1, -1):
            nästa = (nästa + 1) * m[rad_i]
            löp[rad_i] = nästa
        klar = löp >= min_solid
        har = klar.any(axis=0)
        ut = np.full(m.shape[1], gata, dtype=np.int32)
        ut[har] = klar.argmax(axis=0)[har] + y0
        return ut

    def närmast_palett(self, palett_np: np.ndarray, ruta: tuple) -> np.ndarray:
        """Närmaste palettindex per pixel i en ruta (y0, y1, x0, x1). Kastar hellre än gissar."""
        y0, y1, x0, x1 = ruta
        reg = self.px[y0:y1, x0:x1].reshape(-1, 3).astype(np.int32)
        if reg.size == 0:
            return np.zeros(0, dtype=np.int32)
        # Dela i block: 550x905 pixlar x 27 färger är 13 M avstånd, inte 113 M.
        ut = np.empty(reg.shape[0], dtype=np.int32)
        för = 200_000
        for a in range(0, reg.shape[0], för):
            bit = reg[a:a + för]
            d = ((bit[:, None, :] - palett_np[None, :, :]) ** 2).sum(axis=2)
            ut[a:a + bit.shape[0]] = d.argmin(axis=1)
        return ut


def medianfiltra(v: np.ndarray, halv: int) -> np.ndarray:
    """Medianfilter i sidled (±halv px). Konturen är ritad för hand och har enstaka spikar."""
    ut = np.empty_like(v)
    for i in range(v.size):
        a, b = max(0, i - halv), min(v.size, i + halv + 1)
        ut[i] = int(np.median(v[a:b]))
    return ut


# ------------------------------------------------------------------ mätningen av ett hus


def mät_hus(p: dict, bild: Bild, palett_np: np.ndarray, hus_topp: float, gata_procent: float,
            tvinga_steg: int = 0) -> dict:
    """Husets mått ur dess EGEN ruta i byn.png: bredd, kontur per kolumn, dörr, skylt och färger.

    `tvinga_steg` finns bara för NEGATIVTESTET (--bryt tak): det tvingar fram det gamla felet, 8 fasta
    höjdsteg, så att provet kan visas bita.
    """
    x0 = int(round(bild.bredd * p["x0"] / 100.0))
    x1 = int(round(bild.bredd * p["x1"] / 100.0))
    y0 = int(round(bild.höjd * hus_topp / 100.0))
    gata = int(round(bild.höjd * gata_procent / 100.0))
    if x1 - x0 < 8:
        raise SystemExit("FEL: %s har en ruta på %d px" % (p["id"], x1 - x0))
    bredd, rutt = x1 - x0, gata - y0
    # 1) SILHUETTEN: husets överkant per kolumn (en sammanhängande massa, se Bild.topprader).
    topp = medianfiltra(bild.topprader(y0, gata, x0, x1), 10)   # ±10 px: en fågel blir inget torn
    profil = (gata - topp).astype(int)                          # höjden över gatan, i px, per kolumn
    höjd = int(profil.max())
    if höjd < 40:
        raise SystemExit("FEL: %s har bara %d px hus över gatan" % (p["id"], höjd))
    # 2) HÖJDSTEGEN ÄR EN MÄTNING: ett steg per STEG_PIXLAR källpixlar i husets EGEN höjd.
    antal = tvinga_steg or max(2, int(round(höjd / STEG_PIXLAR)))
    steg = höjd / antal
    nivå = np.clip(np.round(profil / steg), 1, antal).astype(int)
    # 3) FÄRGEN per kolumn och höjdsteg, mätt i grova block, och rutnätet slaget ihop till rätblock.
    idx = bild.närmast_palett(palett_np, (y0, gata, x0, x1)).reshape(rutt, bredd)
    färgkort = _färgkort(bild.px[y0:gata, x0:x1], idx, palett_np, antal, steg, bredd, rutt)
    rutor = _rätblock(nivå, färgkort, palett_np)
    # 4) DETALJERNA: dörren (mörkast i nederkanten) och skylten (ljusast i väggen, inte vid taket).
    ljus = bild.luminans[y0:gata, x0:x1]
    inne = np.zeros((rutt, bredd), dtype=bool)                   # husets egen massa, inte himlen
    for c in range(bredd):
        inne[rutt - profil[c]:, c] = True
    dörr, dörrfärg, dörr_kand, dörr_vägg = _dörren(ljus, inne, idx, bredd, höjd, rutt, p["färg"], palett_np)
    if dörr:
        # Dörren ska inte smälta in i KROPPENS rätblock den ligger an mot (mätt: skylten låg 8 av 255
        # från blocket under sig och försvann i renderingen). Bildens väggfärg intill räcker inte som
        # mått — färgen väljs om mot blocken under dörrens ruta.
        dörrfärg = _skild_färg(palett_np, dörr_kand,
                               [dörr_vägg] + _rutor_bak(rutor, dörr[0], dörr[1], 0,
                                                        int(round(dörr[2] / steg))), mörkast=True)
    skylt = _skylten(ljus, inne, idx, bredd, höjd, rutt, dörr, palett_np, profil)
    skyltfärg = skylt[1] if skylt else FÄRG_SKYLT
    if skylt:
        sk, sk_kand, sk_vägg = skylt[0], skylt[2], skylt[3]
        band = max(8, int(round(SKYLT_HÖJD * höjd)))
        skyltfärg = _skild_färg(palett_np, sk_kand,
                                [sk_vägg] + _rutor_bak(rutor, sk[0], sk[1],
                                                       int((sk[2] - band / 2) / steg),
                                                       int((sk[2] + band / 2) / steg)), mörkast=False)
    skylt = skylt[0] if skylt else None
    return {
        "x0_px": x0, "x1_px": x1, "y0_px": y0, "gata_px": gata,
        "bredd_px": bredd, "höjd_px": höjd,
        "topp_px": topp.tolist(), "profil_px": profil.tolist(),
        "rutor": rutor, "antal_steg": antal, "steg_px": steg,
        "dörr": dörr, "dörrfärg": dörrfärg, "dörr_bild": dörr[2] if dörr else 0,
        "skylt": skylt, "skyltfärg": skyltfärg, "skylt_bild": skylt[2] if skylt else 0,
        "skorsten": _skorstenen(profil, höjd, bredd),
        "färger": _dominanta(idx, 6),
    }


def _färgkort(px_rut: np.ndarray, idx: np.ndarray, palett_np: np.ndarray, antal: int, steg: float,
              bredd: int, rutt: int) -> np.ndarray:
    """Palettindex per höjdsteg och kolumn, mätt i grova block (FÄRGBAND_PX × FÄRG_BLOCK).

    Färgen är det VANLIGASTE palettindexet i blocket, utan bakgrundsfärgerna. Mätt pixel för pixel
    blev fasaden ränder av bildens brus (249 141 unika färger, 2,1 % inom |Δ|<10 av paletten).
    Ett block som BARA består av himmelsfärger (bildens bleka torn och tak ligger i samma familj som
    himlen) får den närmaste palettfärgen UTANFÖR familjen — annars byggdes de i himlens egen färg
    och försvann mot himlen i renderingen (mätt: smedjans torn saknades i renderingen).
    """
    block = max(4, int(FÄRG_BLOCK * bredd))
    band = max(1, int(math.ceil(antal * steg / FÄRGBAND_PX)))
    bandfärg = np.empty((band, bredd), dtype=np.int32)
    förbjudna = list(FÄRG_BAKGRUND)
    for b_i in range(band):
        rb = rutt - int(b_i * FÄRGBAND_PX)
        ra = max(0, rutt - int((b_i + 1) * FÄRGBAND_PX))
        ra = min(ra, rb - 1)
        rad = idx[ra:rb, :]
        for c in range(0, bredd, block):
            c2 = min(bredd, c + block)
            cell = rad[:, c:c2].ravel()
            egna = cell[~np.isin(cell, förbjudna)]
            if egna.size >= max(4, 0.10 * cell.size):
                bandfärg[b_i, c:c2] = int(np.bincount(egna).argmax())
            else:
                medel = px_rut[ra:rb, c:c2].reshape(-1, 3).mean(axis=0)
                d = ((palett_np - medel) ** 2).sum(axis=1)
                d[förbjudna] = 10 ** 9
                bandfärg[b_i, c:c2] = int(d.argmin())
    # varje höjdsteg hör till bandet kring sin egen mitt
    nivåband = np.array([min(band - 1, int(((L + 0.5) * steg) / FÄRGBAND_PX)) for L in range(antal)])
    return bandfärg[nivåband]


def _nära(f1: int, f2: int, palett_np: np.ndarray, tol: int = FÄRG_TOL) -> bool:
    """Är två palettindex SAMMA yta? Nära nog räknas som samma färg — bruset ska inte bli ränder."""
    return int(np.abs(palett_np[f1] - palett_np[f2]).max()) <= tol


def _rätblock(nivå: np.ndarray, färgkort: np.ndarray, palett_np: np.ndarray) -> list[tuple]:
    """Rutnätet (kolumn × höjdsteg) → så få rätblock som möjligt.

    Rad för rad (nedifrån) slås celler med samma färg ihop i sidled, och en remsa med EXAKT samma
    x-intervall och färg som remsan under växer i höjdled i stället för att bli en ny låda. Samma
    princip som spelets Voxel._stäng: grannar med samma färg ska bli EN yta, inte en randig trappa —
    ett hus med 450 höjdsteg blev annars tusentals smålådor. Returnerar (a, b, nivå0, nivå1, färg).
    """
    bredd = nivå.size
    klara: list[list[int]] = []
    öppna: dict[tuple[int, int], list[int]] = {}
    for r in range(färgkort.shape[0]):
        nya: dict[tuple[int, int], list[int]] = {}
        c = 0
        while c < bredd:
            if nivå[c] <= r:                      # huset är lägre här: ingen cell
                c += 1
                continue
            f0 = int(färgkort[r, c])
            e = c + 1
            while e < bredd and nivå[e] > r and _nära(f0, int(färgkort[r, e]), palett_np):
                e += 1
            nyckel = (c, e - 1)
            gammal = öppna.pop(nyckel, None)
            if gammal is not None and _nära(gammal[4], f0, palett_np):
                gammal[3] = r                     # samma remsa som under → väx uppåt
                nya[nyckel] = gammal
            else:
                if gammal is not None:
                    klara.append(gammal)
                nya[nyckel] = [c, e - 1, r, r, f0]
            c = e
        klara += list(öppna.values())             # remsor som inte fortsätter uppåt
        öppna = nya
    klara += list(öppna.values())
    return [(a, b, r0, r1, f) for a, b, r0, r1, f in klara]


def _skild_färg(palett_np: np.ndarray, kandidater: list, vägg, mörkast: bool) -> int:
    """Den mörkaste/ljusaste av kandidaterna — och som SYNS mot väggfärgen/färgerna intill.

    En dörr med palettens mörka rakt av drunknade i en lika mörk vägg (mätt: 0 av 255 i skillnad):
    färgen ska vara bildens OCH skilja sig från fasaden den sitter på, annars syns detaljen inte.
    `vägg` får vara en färg eller en LISTA av färger (kroppens rätblock under detaljen).
    """
    if not kandidater:
        kandidater = list(range(palett_np.shape[0]))
    mot = [int(v) for v in ([vägg] if isinstance(vägg, (int, np.integer)) else list(vägg))]
    for i in sorted(kandidater, key=lambda i2: ljushet(palett_np[i2]), reverse=not mörkast):
        if not any(_nära(i, v, palett_np) for v in mot):
            return i
    return max(range(palett_np.shape[0]),
               key=lambda i2: min(int(np.abs(palett_np[i2] - palett_np[v]).max()) for v in mot))


def _rutor_bak(rutor: list, ka: int, kb: int, r0: int, r1: int) -> list[int]:
    """Färgerna på de rätblock i KROPPEN som en detalj ligger an mot.

    Bildens väggfärg intill är inte samma sak som kroppens blockfärg: mätt låg smedjans skylt 8 av
    255 från blocket under sig och försvann i renderingen, trots att den skilde sig från bildens vägg.
    """
    return sorted({f for a, b, p0, p1, f in rutor if a <= kb and b >= ka and p0 <= r1 and p1 >= r0})


def _dörren(ljus: np.ndarray, inne: np.ndarray, idx: np.ndarray, bredd: int, höjd: int, rutt: int,
            fallback: int, palett_np: np.ndarray) -> tuple:
    """Dörren: den MÖRKASTE sektionen i husets nederkant — mätt, inte satt på en fast höjd.

    Tröskeln är husets EGEN ljushet i bandet (bildens hus ligger på median 74-89 av 255, så ett fast
    tal gav en slumpmässig kolumn). Höjden är överkanten på den mörka massan i den kolumnsektionen —
    MÄTT: den nedersta raden är markens skugga, inte dörren, så mörkret räknas ovanför den.
    Returnerar ((a, b, överkant_px), palettindex).
    """
    band = min(rutt, max(8, int(round(DÖRR_BAND * höjd))))
    sektion = max(6, int(round(DÖRR_ANDEL * bredd)))
    if sektion >= bredd:
        sektion = max(4, bredd // 2)
    under = ljus[rutt - band:, :]
    under_inne = inne[rutt - band:, :]
    if not under_inne.any():
        return None, FÄRG_DÖRR
    mask = np.where(under_inne, under, np.nan)
    kolm = np.nanmean(mask, axis=0)
    kolm = np.where(np.isnan(kolm), np.nanmax(kolm), kolm)
    medel = np.convolve(kolm, np.ones(sektion) / sektion, mode="valid")
    a = int(np.argmin(medel))
    b = a + sektion - 1
    tröskel = float(np.median(kolm))
    # rad 0 i bandet är överkanten (band px över gatan), band-1 är marken.
    mörka = np.nan_to_num(np.nanmean(mask[:, a:b + 1], axis=1), nan=1e9) < tröskel
    topp = 0
    i = band - 1
    while i >= 0:
        if mörka[i]:
            j = i
            while j >= 0 and mörka[j]:
                j -= 1
            if i - j >= 3:                       # en riktig massa, inte en enstaka rad
                topp = band - j                  # överkanten, i px över gatan
                break
            i = j - 1
            continue
        i -= 1
    topp = int(min(max(topp, 0.10 * höjd), DÖRR_HÖJD_MAX * höjd))
    # färgen: den mörkaste palettfärgen i rutan, men SKILD från väggen intill.
    region = idx[rutt - topp:rutt, a:b + 1].ravel()
    u, n = np.unique(region, return_counts=True)
    kandidater = [int(i2) for i2, n2 in zip(u, n) if n2 >= max(3, 0.05 * region.size)]
    sidor = np.concatenate([
        idx[rutt - topp:rutt, max(0, a - 2 * sektion):a].ravel(),
        idx[rutt - topp:rutt, b + 1:min(bredd, b + 1 + 2 * sektion)].ravel()])
    if sidor.size == 0:
        sidor = region
    vägg = int(np.bincount(sidor).argmax())
    return (a, b, topp), _skild_färg(palett_np, kandidater or [fallback], vägg, mörkast=True), \
        (kandidater or [fallback]), vägg


def _skylten(ljus: np.ndarray, inne: np.ndarray, idx: np.ndarray, bredd: int, höjd: int, rutt: int,
             dörr, palett_np: np.ndarray, profil: np.ndarray) -> tuple | None:
    """Skylten: den LJUSASTE sektionen i väggen mellan dörren och takfoten.

    Mätt ur bilden: det band (SKYLT_HÖJD av husets höjd) i SKYLT_BAND vars ljusaste femtedel är
    ljusast, och inom bandet den bredaste ljusa kolumnsektionen (SKYLT_ANDEL av husets bredd). Förr
    satt skylten på 78 % av husets höjd, tätt under taket, oavsett var bilden visar den.
    Returnerar (a, b, höjd_px, färg) med höjden i bandets mitt, i px över gatan.
    """
    dtopp = dörr[2] if dörr else int(0.25 * höjd)
    band = max(8, int(round(SKYLT_HÖJD * höjd)))
    under = int(max(dtopp, SKYLT_BAND[0] * höjd))
    bästa = None
    while under + band <= SKYLT_BAND[1] * höjd:
        ra, rb = rutt - (under + band), rutt - under
        egna = ljus[ra:rb, :][inne[ra:rb]]
        if egna.size:
            p = float(np.percentile(egna, 90))
            if bästa is None or p > bästa[0]:
                bästa = (p, under)
        under += max(2, band // 3)
    if bästa is None:
        return None
    under = bästa[1]
    ra, rb = rutt - (under + band), rutt - under
    kolm = np.clip(np.where(inne[ra:rb], ljus[ra:rb], 0.0).max(axis=0), 0.0, None)
    sektion = min(bredd, max(6, int(round(SKYLT_ANDEL * bredd))))
    a = 0 if sektion >= bredd else int(np.argmax(np.convolve(
        kolm, np.ones(sektion) / sektion, mode="valid")))
    b = a + sektion - 1
    # Skylten får inte skjuta upp över taket i sina EGNA kolumner (mätt: smedjans skylt låg 15 px över
    # bildens kontur vid takfoten och syntes som en platta tvärs över taket).
    mitt = min(under + band // 2, int(profil[a:b + 1].min()) - band // 2)
    mitt = max(mitt, int(0.12 * höjd))
    # färgen: den ljusaste palettfärgen i rutan, men skild från väggen UNDER — annars syns inte skylten.
    under_ra = max(0, ra - band)
    väggyta = idx[under_ra:ra, a:b + 1].ravel()
    vägg = int(np.bincount(väggyta).argmax()) if väggyta.size else 0
    region = idx[ra:rb, a:b + 1].ravel()
    u, n = np.unique(region, return_counts=True)
    kandidater = [int(i2) for i2, n2 in zip(u, n) if n2 >= max(3, 0.03 * region.size)]
    return (a, b, mitt), _skild_färg(palett_np, kandidater, vägg, mörkast=False), kandidater, vägg


def _skorstenen(profil: np.ndarray, höjd: int, bredd: int) -> tuple | None:
    """Var bilden visar en skorsten: en smal kolumnremsa som sticker upp över taket runtomkring.

    Returnerar (a, b, topp_px, nock_px): kolumnerna, hur högt skorstenen når och hur högt taket
    runtomkring ligger. Visar bilden ingen skorsten blir det None — då ställer provet inget krav.
    """
    fönster = max(5, int(0.25 * bredd))
    med = np.array([np.median(profil[max(0, c - fönster):c + fönster + 1]) for c in range(bredd)])
    höga = profil > med + max(20.0, 0.10 * höjd)
    bästa = None
    a = -1
    for i in range(bredd + 1):
        v = bool(höga[i]) if i < bredd else False
        if v and a < 0:
            a = i
        elif not v and a >= 0:
            if (i - a) < 0.6 * bredd and (bästa is None or
                                          profil[a:i].max() > profil[bästa[0]:bästa[1]].max()):
                bästa = (a, i)
            a = -1
    if bästa is None:
        return None
    a, b = bästa
    runtom = np.concatenate([profil[max(0, a - fönster):a], profil[b:b + fönster]])
    if runtom.size == 0:
        return None
    return (a, b, int(profil[a:b].max()), int(round(np.median(runtom))))


def _dominanta(idx: np.ndarray, antal: int) -> list[tuple[int, int]]:
    """De vanligaste palettindexen i ett hus, som (index, andel i procent)."""
    flat = idx.ravel()
    if flat.size == 0:
        return []
    u, n = np.unique(flat, return_counts=True)
    o = np.argsort(-n)[:antal]
    return [(int(u[i]), int(round(100 * n[i] / flat.size))) for i in o]


# ------------------------------------------------------------------ meshen


class Bygge:
    """Ett hus som rätblock. Lägger ihop hörn och ytor i listor; en mesh per byggnad."""

    def __init__(self, namn: str):
        self.namn = namn
        self.hörn: list[tuple[float, float, float]] = []
        self.ytor: list[tuple[int, ...]] = []
        self.färger: list[int] = []
        self.lådor = 0
        self.x_min = math.inf
        self.x_max = -math.inf

    def låda(self, mitt, mått, färgindex: int) -> None:
        """Ett rätblock kring `mitt` med storleken `mått` (x, y, z). 8 hörn, 6 fyrkantiga ytor."""
        cx, cy, cz = mitt
        hx, hy, hz = mått[0] / 2.0, mått[1] / 2.0, mått[2] / 2.0
        if hx <= 0 or hy <= 0 or hz <= 0:
            raise SystemExit("FEL: %s fick en låda utan mått %s" % (self.namn, mått))
        n = len(self.hörn)
        self.hörn += [
            (cx - hx, cy - hy, cz - hz),
            (cx + hx, cy - hy, cz - hz),
            (cx + hx, cy + hy, cz - hz),
            (cx - hx, cy + hy, cz - hz),
            (cx - hx, cy - hy, cz + hz),
            (cx + hx, cy - hy, cz + hz),
            (cx + hx, cy + hy, cz + hz),
            (cx - hx, cy + hy, cz + hz),
        ]
        self.ytor += [
            (n + 0, n + 3, n + 2, n + 1),  # botten
            (n + 4, n + 5, n + 6, n + 7),  # toppen
            (n + 0, n + 1, n + 5, n + 4),  # fram
            (n + 2, n + 3, n + 7, n + 6),  # bak
            (n + 1, n + 2, n + 6, n + 5),  # höger
            (n + 3, n + 0, n + 4, n + 7),  # vänster
        ]
        self.färger += [färgindex] * 6
        self.lådor += 1
        self.x_min = min(self.x_min, cx - hx)
        self.x_max = max(self.x_max, cx + hx)


def material(i: int, palett: list) -> "bpy.types.Material":
    """Material för palettindex i, skapat en gång. Diffusfärgen sätts också (workbench-läget)."""
    namn = "palett_%02d" % i
    mat = bpy.data.materials.get(namn)
    if mat is None:
        c8 = färg(palett, i)
        mat = bpy.data.materials.new(namn)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        lin = linjär(c8)
        bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Metallic"].default_value = 0.0
        mat.diffuse_color = (*lin, 1.0)
        mat["palett_index"] = i
        mat["palett_rgb8"] = list(c8)
    return mat


def gör_objekt(bygge: Bygge, palett: list, samling) -> "bpy.types.Object":
    """Byggnaden blir EN mesh och EN nod — antalet hus i glb-filen är antalet platser."""
    mesh = bpy.data.meshes.new(bygge.namn)
    mesh.from_pydata(bygge.hörn, [], bygge.ytor)
    mesh.validate()
    for i in sorted(set(bygge.färger)):
        mesh.materials.append(material(i, palett))
    slots = [m.name for m in mesh.materials]
    for f, färgindex in zip(mesh.polygons, bygge.färger):
        f.material_index = slots.index("palett_%02d" % färgindex)
    obj = bpy.data.objects.new(bygge.namn, mesh)
    samling.objects.link(obj)
    return obj


# ------------------------------------------------------------------ byggnaderna ur bilden


def _kroppen(bygge: Bygge, mått: dict, skala: float, x_mitt: float, botten: float) -> None:
    """Husets KROPP: rutnätet ur bilden, slaget ihop till rätblock (se _rätblock).

    ETT djup per hus: blev varje rätblock sin egen platta ut mot gatan blev fasaden en trappa av
    fenor och huset en färgpelare i stället för en huskropp. Kroppen byggs också för sig själv (se
    --kolla): då kan provet rendera huset MED och UTAN detaljer och se att dörren och skylten syns.
    """
    b = mått["bredd_px"] * skala
    d = DJUP * b
    steg = mått["steg_px"] * skala
    for a, bb, r0, r1, fi in mått["rutor"]:
        bredd = (bb - a + 1) * skala
        cx = x_mitt - b / 2.0 + (a + (bb - a + 1) / 2.0) * skala
        z0, z1 = botten + r0 * steg, botten + (r1 + 1) * steg
        bygge.låda((cx, 0.0, (z0 + z1) / 2.0), (bredd, d, z1 - z0), fi)


def _utan_detalj(pl: dict, mått: dict, palett: list, skala: float, hoppa: str,
                 samling: "bpy.types.Collection", sökväg: Path) -> np.ndarray:
    """Samma hus utan EN detalj (dörren eller skylten), i samma kamera.

    Provet jämför den renderingen med huset med allt: skillnaden ÄR detaljen. En detalj som inte
    byggdes, eller som gömmer sig inne i ett block, ger ingen skillnad alls — då faller provet.
    """
    sparat = {nyckel: mått.get(nyckel) for nyckel in ("dörr_byggd", "skylt_byggd")}
    mått[hoppa] = True
    variant = bygg_hus(pl, mått, palett, skala, mått["x_mitt"], 0.0)
    mått.pop(hoppa)
    mått.update(sparat)
    return hus_framifrån(mått, gör_objekt(variant, palett, samling), sökväg)[0]


def bygg_hus(p: dict, mått: dict, palett: list, skala: float, x_mitt: float, botten: float) -> Bygge:
    """Ett hus: bildens kontur som staplade rätblock, bildens färger, dörr och skylt där de sitter."""
    b = mått["bredd_px"] * skala
    d = DJUP * b
    höjd = mått["höjd_px"] * skala
    bygge = Bygge("hus_" + p["id"])
    _kroppen(bygge, mått, skala, x_mitt, botten)
    fram = -d / 2.0 - 0.05      # 0,05 utanför fasaden: aldrig två ytor i samma plan (z-fighting)
    hus_a, hus_b = x_mitt - b / 2.0, x_mitt + b / 2.0
    # DÖRREN: mätt ur bilden — den mörkaste sektionen i nederkanten, med sin EGEN bredd och höjd.
    if mått.get("hoppa_dörr"):
        topp_px = 0.0           # NEGATIVTEST (--bryt dörr): ingen dörr alls
        mått["dörr_byggd"] = None
    else:
        if mått["dörr"]:
            a, bb, topp_px = mått["dörr"]
            dx = x_mitt - b / 2.0 + (a + (bb - a + 1) / 2.0) * skala
            dbredd = max(0.5, (bb - a + 1) * skala)
        else:
            dx, dbredd, topp_px = x_mitt, max(0.5, b * 0.20), 0.32 * mått["höjd_px"]
        dbredd = min(dbredd, b)
        dxk = _innanför(dx, dbredd, hus_a, hus_b)
        bygge.låda((dxk, fram, botten + topp_px * skala / 2.0),
                   (dbredd, 0.12, topp_px * skala), mått["dörrfärg"])
        # Bygget redovisar VAR dörren hamnade (kolumner i husets egen ruta) och hur hög den blev:
        # provet mäter synligheten på den byggda rutan, inte på den mätta (den kläms in i huset).
        mått["dörr_byggd"] = (int(round((dxk - dbredd / 2.0 - hus_a) / skala)),
                              int(round((dxk + dbredd / 2.0 - hus_a) / skala)), topp_px)
    # SKYLTEN: mätt ur bilden — den ljusaste sektionen i väggen mellan dörren och takfoten.
    if mått["skylt"]:
        sa, sb, sho = mått["skylt"]
        sx = x_mitt - b / 2.0 + (sa + (sb - sa + 1) / 2.0) * skala
        sbredd = max(0.5, (sb - sa + 1) * skala)
    else:
        sx, sbredd, sho = x_mitt, max(0.5, b * 0.55), 0.62 * mått["höjd_px"]
    sh = max(0.10, SKYLT_HÖJD * höjd)
    sbredd = min(sbredd, b)
    sxk = _innanför(sx, sbredd, hus_a, hus_b)
    if not mått.get("hoppa_skylt"):
        bygge.låda((sxk, fram - 0.08, botten + sho * skala), (sbredd, 0.10, sh), mått["skyltfärg"])
        mått["skylt_byggd"] = (int(round((sxk - sbredd / 2.0 - hus_a) / skala)),
                               int(round((sxk + sbredd / 2.0 - hus_a) / skala)), sho)
    else:
        mått["skylt_byggd"] = None
    # FÖNSTREN: två symmetriska i väggen under skylten. Bildens fönster går inte att mäta: de ljusa
    # pixlarna ligger i samma familj som himlen och blir bakgrund i Bild.bakgrund.
    fz = botten + 0.5 * (topp_px * skala + sho * skala)
    for dx_ in (-0.28, 0.28):
        bygge.låda((x_mitt + b * dx_, fram, fz),
                   (b * 0.16, 0.12, max(0.20, höjd * 0.16)), FÄRG_FÖNSTER)
    _detaljer(bygge, mått, x_mitt, b, höjd, botten, fram)
    # PLATSENS EGET: ordboken från referensen, färgerna ur paletten.
    bygge = _saken(p, bygge, x_mitt, b, d, höjd, botten, mått["profil_px"], skala)
    return bygge


def _detaljer(bygge: Bygge, mått: dict, x_mitt: float, b: float, höjd: float, botten: float,
              fram: float) -> None:
    """Takfot, knutar, bjälkar, fönsterfoder och trappsteg — det som gör ett hus BYGGT (M152).

    Husen var staplar av rätblock med en platt dörr och en platt skylt. Alex: *"inte så här otroligt
    basic former"*. Det som får en fasad att läsa som byggd i stället för klippt är tre saker:
    SKUGGAN under takfoten, DJUPET kring fönstren och VIRKET som sticker ut. Allt är fortfarande
    rätblock — inga rundade former — och måtten är andelar av husets egen bredd, så det följer skalan.
    """
    tak = max(mått["rutor"], key=lambda r: r[3])[4] if mått["rutor"] else FÄRG_MUR
    virke = FÄRG_DÖRR if FÄRG_DÖRR != tak else 4
    fot = botten + höjd * 0.60                       # där väggen möter taket
    # 1) TAKFOTEN: en platta som sticker ut framför och vid sidan om väggen, med en mörk kant under.
    bygge.låda((x_mitt, fram - 0.05 * b, fot), (b * 0.98, 0.09 * b, 0.018 * b), tak)
    bygge.låda((x_mitt, fram - 0.085 * b, fot - 0.016 * b), (b * 0.97, 0.02 * b, 0.012 * b), virke)
    # 2) KNUTAR OCH BJÄLKE: fyra stolpar i hörnen och en vågrät bjälke en bit upp — halvtimmer hus.
    for dx in (-1.0, 1.0):
        bygge.låda((x_mitt + dx * b * 0.47, fram - 0.012 * b, (botten + fot) * 0.5),
                   (0.035 * b, 0.02 * b, fot - botten), virke)
    bygge.låda((x_mitt, fram - 0.012 * b, botten + (fot - botten) * 0.62),
               (b * 0.94, 0.02 * b, 0.014 * b), virke)
    # 3) FÖNSTERFODER: fyra smala rätblock kring varje fönster, 3 cm utanför glaset — djup i stället
    #    för en platt ruta.
    fz = botten + 0.5 * (höjd * 0.18 + höjd * 0.62)  # samma mitt som bygg_hus räknar
    fw, fh = b * 0.16, max(0.20, höjd * 0.16)
    for dx in (-0.28, 0.28):
        cx = x_mitt + b * dx
        bygge.låda((cx, fram - 0.03 * b, fz + fh * 0.5), (fw * 1.25, 0.02 * b, 0.02 * b), 8)
        bygge.låda((cx, fram - 0.03 * b, fz - fh * 0.5), (fw * 1.25, 0.02 * b, 0.02 * b), 8)
        for sx in (-1.0, 1.0):
            bygge.låda((cx + sx * fw * 0.6, fram - 0.03 * b, fz), (0.02 * b, 0.02 * b, fh), 8)
    # 4) TRAPPSTEGET: en sten framför dörren, så huset står på marken och inte i den.
    if mått.get("dörr_byggd"):
        a, bb, _ = mått["dörr_byggd"]
        dxk = x_mitt - b / 2.0 + ((a + bb) / 2.0) * (b / mått["bredd_px"])
        stegbr = max(0.5, (bb - a) * b / mått["bredd_px"] * 1.3)
        # Steget hålls inom tomten som alla andra detaljer: annars sticker det ut i grannens ruta.
        dxk = _innanför(dxk, stegbr, x_mitt - b / 2.0, x_mitt + b / 2.0)
        bygge.låda((dxk, fram - 0.05 * b, botten + 0.012 * b),
                   (stegbr, 0.08 * b, 0.024 * b), 6)


def _innanför(x: float, bredd: float, hus_a: float, hus_b: float) -> float:
    """Håll en detalj inom husets EGET x-intervall.

    Utan den här raden sticker en dörr, en tunna eller en städ ut i luften mellan husen, och då
    gäller inte kontrollen att inga hus' x-intervall skär varandra (mätt: smedjan byggdes 0,12
    enheter utanför sin egen ruta).
    """
    halv = min(bredd, hus_b - hus_a) / 2.0
    return min(max(x, hus_a + halv), hus_b - halv)


def _saken(p: dict, bygge: Bygge, x: float, b: float, d: float, h: float, botten: float,
           profil: list, skala: float) -> Bygge:
    """Ässja, tunnor, tinnar, facklor, baner, tygrullar, städ — det som skiljer platserna åt."""
    sak = SAKER.get(p["id"], {}).get("sak", "")
    fram = -d / 2.0
    hus_a, hus_b = x - b / 2.0, x + b / 2.0

    def dlåda(dx: float, dy: float, dz: float, mått, fi: int) -> None:
        """En detalj: x hålls innanför husets ruta, måtten klipps mot husets bredd."""
        mx, my, mz = min(mått[0], b), mått[1], mått[2]
        bygge.låda((_innanför(x + dx, mx, hus_a, hus_b), dy, botten + dz), (mx, my, mz), fi)

    if sak == "ässja":
        # SMEDJAN: glödgrop i fasaden, städ och en sten utanför — glöden är en egen palettfärg (13).
        dlåda(-b * 0.22, fram - 0.06, h * 0.20, (b * 0.22, 0.14, h * 0.30), 13)
        dlåda(b * 0.30, fram - 0.55, h * 0.06, (b * 0.16, 0.30, h * 0.12), 4)
        dlåda(-b * 0.42, fram - 0.50, h * 0.03, (b * 0.20, 0.25, h * 0.06), 22)
    elif sak == "tunnor":
        # TAVERNAN: tre tunnor utanför dörren och ett varmt fönster.
        for i, dx in enumerate((-0.34, -0.26, -0.30)):
            dlåda(b * dx, fram - 0.45 - 0.12 * i, h * 0.10, (b * 0.10, b * 0.10, h * 0.20), 16)
        dlåda(0.0, fram - 0.06, h * 0.30, (b * 0.34, 0.12, h * 0.22), 13)
    elif sak == "port":
        # PORTEN: tinnar (krenelering) längs taket, facklor och två baner. Tinnarna sitter PÅ taket
        # där bildens kontur går — och i den LÄGSTA punkten inom sin egen bredd. En fast höjd lade dem
        # 62 px över bildens kontur vid portens hörn (en platta tvärs över taket), och att följa bara
        # mittenkolumnen lämnade 63 px över vid kanten där taket sluttar. Tinnens egen höjd är det
        # enda den får sticka upp med.
        tinnbredd = max(0.30, b * 0.07)
        n = max(3, int(b / (tinnbredd * 2.2)))
        halv = max(1, int(tinnbredd / 2.0 / skala))
        for i in range(n):
            kx = -b / 2.0 + b * (i + 0.5) / n
            kol = int(min(len(profil) - 1, max(0, (kx + b / 2.0) / skala)))
            tak = min(profil[max(0, kol - halv):kol + halv + 1]) * skala
            dlåda(kx, 0.0, tak + h * 0.015, (tinnbredd, d * 0.5, h * 0.03), 22)
        for dx, fi in ((-0.34, 11), (0.34, 25)):
            dlåda(b * dx, fram - 0.05, h * 0.62, (b * 0.10, 0.10, h * 0.16), 13)
            dlåda(b * dx, fram - 0.02, h * 0.80, (b * 0.14, 0.06, h * 0.22), fi)
        dlåda(0.0, fram - 0.06, h * 0.50, (b * 0.20, 0.12, h * 0.18), 14)
    elif sak == "juvel":
        # JUVELERAREN: ett fönster med kallt ljus (vitt) och ett varmt (guld).
        dlåda(-b * 0.26, fram - 0.06, h * 0.34, (b * 0.24, 0.12, h * 0.26), 8)
        dlåda(b * 0.26, fram - 0.06, h * 0.60, (b * 0.20, 0.12, h * 0.20), 14)
    elif sak == "tyg":
        # VÄVERIET: två tygrullar på tork utanför (röda och blå, ur paletten).
        färger = SAKER["tradet"]["tyg"]
        for i, dx in enumerate((-0.22, 0.22)):
            dlåda(b * dx, fram - 0.55, h * 0.22, (b * 0.09, 0.10, h * 0.44), färger[i % 2])
        dlåda(0.0, fram - 0.55, h * 0.46, (b * 0.60, 0.10, h * 0.05), 16)
    elif sak == "stolpe":
        # EXIT: en stolpe med en skylt — dörren ut ur spelet (ingen byggnad).
        bygge = Bygge(bygge.namn)
        bygge.låda((x, 0.0, botten + h * 0.24), (b * 0.10, d * 0.4, h * 0.48), 16)
        bygge.låda((x, fram - 0.20, botten + h * 0.52), (b * 0.90, 0.16, h * 0.12), 24)
        bygge.låda((x, fram - 0.28, botten + h * 0.52), (b * 0.70, 0.04, h * 0.08), 14)
    return bygge


def bryt_provet(mått: list, vad: str) -> None:
    """NEGATIVTEST: bryt med flit mot EN regel så att `--kolla` MÅSTE falla (se `--bryt`).

    Varje rad gör exakt det som ett prov ska fånga, och används för att visa att provet biter:
      tak      — 8 fasta höjdsteg (det gamla felet; sätts i mät_hus),
      dörr     — ingen dörr byggs (`hoppa_dörr`),
      skylt    — skylten sätts på 78 % av höjden, nära taket (den gamla fasta höjden),
      skorsten — taket kapas vid nocken, så inget torn når över.
    """
    for m in mått:
        if vad == "dörr":
            m["hoppa_dörr"] = True
        elif vad == "skylt":
            if m["skylt"]:
                a, b, _ = m["skylt"]
                m["skylt"] = (a, b, int(0.78 * m["höjd_px"]))
        elif vad == "skorsten":
            nock = int(m["skorsten"][3] / m["steg_px"]) if m["skorsten"] else m["antal_steg"]
            m["rutor"] = [(a, b, r0, min(r1, nock - 1), f)
                          for a, b, r0, r1, f in m["rutor"] if r0 < nock]


def dela_ut(mått: list, skala: float, mellanrum: float = MELLANRUM) -> list[tuple[float, float]]:
    """Husen på EN gata i PLATSER:s ordning, med luft mellan sig: inga x-intervall skär varandra.

    Luften är `mellanrum` av grannarnas medelbredd. Bredderna är bildens, så smedjan (550 px) blir
    bredare än EXIT (356 px) precis som i bilden. Returnerar varje hus' (vänster, höger) i världen.
    """
    bredder = [m["bredd_px"] * skala for m in mått]
    intervall: list[tuple[float, float]] = []
    x = 0.0
    for i, b in enumerate(bredder):
        if i > 0:
            x += 0.5 * mellanrum * (bredder[i - 1] + b)   # luft mot grannen till vänster
        intervall.append((x, x + b))
        x += b
    # Centrera gatan kring 0. Halva längden är det sista husets högerkant.
    halv = (intervall[-1][1]) / 2.0
    return [(a - halv, b - halv) for a, b in intervall]


# ------------------------------------------------------------------ marken och bakgrunden


def bygg_mark(x0: float, x1: float, palett: list) -> Bygge:
    """Marken, kullerstensgatan och gräskanten — färgerna ur paletten (gatan mätt till 24/4)."""
    mark = Bygge("mark")
    längd = x1 - x0
    mitt = (x0 + x1) / 2.0
    mark.låda((mitt, 6.0, -0.30), (längd + 26.0, 30.0, 0.60), FÄRG_GRÄS)          # gräset bakom
    # UNDERLAGET: spelets EGEN vy är ortografisk rakt framifrån (se FRONTKAMERA), och där ser kameran
    # också UNDER gatans nivå. Utan den här plattan syntes ett tomt hål under marken (mätt: nedersta
    # femtedelen av frontbilden var himmel). Den går fram till kameran och ned under bildrutan, och
    # möter gräset kant mot kant (överkant -0,6 = gräsets underkant) så inga ytor hamnar i samma plan.
    mark.låda((mitt, -15.0, -8.3), (längd + 26.0, 12.0, 15.4), FÄRG_GRÄS)
    mark.låda((mitt, -0.6, -0.15), (längd + 10.0, 9.0, 0.30), FÄRG_MARK)          # jorden
    mark.låda((mitt, -1.4, 0.02), (längd + 8.0, 4.6, 0.10), FÄRG_GATA)            # kullerstensgatan
    mark.låda((mitt, 0.9, 0.06), (längd + 8.0, 0.30, 0.16), FÄRG_MUR)             # trottoarkanten
    # Några stenar i gatan: samma tanke som referensbyn, men få och deterministiska (ingen slump).
    frö = 12345
    for i in range(18):
        frö = (frö * 1103515245 + 12345) % 2147483648
        rx = x0 - 3.0 + (frö % 10000) / 10000.0 * (längd + 6.0)
        frö = (frö * 1103515245 + 12345) % 2147483648
        ry = -3.0 + (frö % 10000) / 10000.0 * 2.6
        mark.låda((rx, ry, 0.09), (0.44, 0.34, 0.05), 4)
    return mark


def bygg_bakgrund(x0: float, x1: float, höjd: float) -> list[tuple[str, Bygge]]:
    """Bakgrunden: stadsmur med torn, bakgrundshus, träd, berg och en kulle med får.

    Referensbyn bygger samma lager; färgerna här är palettens (mur 22/7, berg 20/21, träd 15/16).
    """
    längd = x1 - x0
    mitt = (x0 + x1) / 2.0
    mur = Bygge("bakgrund_mur")
    # STADSMUREN: en lång mur bakom husen med torn med jämna mellanrum.
    mur.låda((mitt, 7.0, höjd * 0.16), (längd + 16.0, 1.6, höjd * 0.32), FÄRG_MUR)
    mur.låda((mitt, 7.0, höjd * 0.33), (längd + 16.0, 1.9, 0.18), 7)          # murens krön
    n_torn = max(3, int((längd + 16.0) / 13.0))
    for i in range(n_torn):
        tx = x0 - 8.0 + (i + 0.5) * (längd + 16.0) / n_torn
        mur.låda((tx, 7.0, höjd * 0.32), (2.6, 3.0, höjd * 0.64), 22)
        mur.låda((tx, 7.0, höjd * 0.66), (3.2, 3.6, 0.30), 7)
    hus = Bygge("bakgrund_hus")
    # BAKGRUNDSHUS: lägre hus bakom muren, i bildens varma toner.
    for i in range(6):
        hx = x0 - 4.0 + (i + 0.5) * (längd + 8.0) / 6.0
        hb = 3.2 + (i % 3) * 0.7
        hh = höjd * (0.26 + 0.05 * (i % 4))
        hus.låda((hx, 10.5, hh / 2.0), (hb, 3.0, hh), (17, 18, 22)[i % 3])
        hus.låda((hx, 10.5, hh + 0.16), (hb * 1.12, 3.4, 0.32), 16)
    träd = Bygge("bakgrund_träd")
    # TRÄDEN: stam + krona, grönt ur paletten (15) med mörk stam.
    for i in range(9):
        tx = x0 - 6.0 + (i + 0.5) * (längd + 12.0) / 9.0
        th = höjd * (0.34 + 0.05 * (i % 3))
        träd.låda((tx, 13.5, th * 0.30), (0.5, 0.5, th * 0.60), 16)
        träd.låda((tx, 13.5, th * 0.72), (2.2, 2.2, th * 0.56), FÄRG_TRÄD)
    berg = Bygge("bakgrund_berg")
    # BERGEN: tre stora block långt bak, blågrå (20/21) som diset i bilden.
    for i, (dx, w, h) in enumerate([(-0.34, 0.42, 0.86), (0.02, 0.50, 1.00), (0.36, 0.36, 0.74)]):
        berg.låda((mitt + dx * längd, 22.0, höjd * h / 2.0), (längd * w, 6.0, höjd * h),
                  FÄRG_BERG if i != 1 else 21)
    kulle = Bygge("kulle")
    # KULLEN med fåren, till höger om husen — som i referensen.
    kulle.låda((x1 + 6.5, 0.5, 0.35), (9.0, 8.0, 0.70), FÄRG_GRÄS)
    for i, (dx, dy) in enumerate([(1.5, 1.2), (3.4, 2.4), (4.6, 0.6)]):
        kulle.låda((x1 + 6.5 + dx * 0.5 - 1.0, dy, 0.88), (0.60, 0.38, 0.38), FÄRG_ULLE)
        kulle.låda((x1 + 6.5 + dx * 0.5 - 1.3, dy, 0.95), (0.24, 0.24, 0.24), 2)
    return [("mur", mur), ("hus", hus), ("träd", träd), ("berg", berg), ("kulle", kulle)]


# ------------------------------------------------------------------ scenen


def töm_scenen() -> None:
    """--factory-startup ger en standardkub, ett ljus och en kamera. Bort med dem."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for datablock in (bpy.data.meshes, bpy.data.materials):
        for d in list(datablock):
            if d.users == 0:
                datablock.remove(d)


def sätt_scen(palett: list, upplösning=(1280, 720)) -> None:
    scen = bpy.context.scene
    scen.render.engine = "BLENDER_EEVEE"
    scen.render.resolution_x, scen.render.resolution_y = upplösning
    scen.render.resolution_percentage = 100
    scen.render.film_transparent = False
    scen.eevee.taa_render_samples = 32
    # STANDARD vylook: palettens färger ska ut ur renderingen som de gick in, inte genom AgX-filmen
    # (mätt: närbildens högra halva avvek 65 av 255 mot byn.png med AgX).
    try:
        scen.view_settings.view_transform = "Standard"
        scen.view_settings.look = "None"
    except (AttributeError, TypeError):
        pass
    v = bpy.data.worlds.new("himmel")
    v.use_nodes = True
    v.node_tree.nodes["Background"].inputs[0].default_value = (*linjär(färg(palett, FÄRG_HIMMEL)), 1.0)
    v.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scen.world = v
    ljus = bpy.data.lights.new("sol", type="SUN")
    ljus.energy = 3.0
    ljus.angle = 0.2
    lobj = bpy.data.objects.new("sol", ljus)
    lobj.rotation_euler = (0.85, 0.25, 0.6)
    bpy.context.scene.collection.objects.link(lobj)


def sätt_kamera(x0: float, x1: float, topp: float, objekt: list, namn: str = "kamera"):
    """Sned bild ovanifrån, RAMAD UR GEOMETRIN: hela gatans längd och husens höjd ska rymmas.

    Avståndet räknas fram och prövas sedan mot kamerans EGEN projektion: ryms inte alla hus flyttas
    kameran bakåt tills de gör det. En handräknad vinkel räckte inte (mätt: fyra hus hamnade utanför
    bildrutan med den första formeln).
    """
    scen = bpy.context.scene
    lens = 42.0
    scen.render.resolution_x, scen.render.resolution_y = 1280, 720
    scen.render.pixel_aspect_x = scen.render.pixel_aspect_y = 1.0
    # Sensorns bredd är 36 mm och höjden följer bildförhållandet → den HORISONTELLA vinkeln är
    # 2*atan(18/lens), oberoende av upplösningen.
    fov_x = 2.0 * math.atan(18.0 / lens)
    spann = x1 - x0
    mål = Vector(((x0 + x1) / 2.0, 0.0, topp * 0.45))
    riktning = Vector((0.34, -1.0, 0.46)).normalized()
    kam = bpy.data.cameras.new(namn)
    kam.lens = lens
    kobj = bpy.data.objects.new(namn, kam)
    scen.collection.objects.link(kobj)
    scen.camera = kobj
    avstånd = (spann * 0.56) / math.tan(fov_x / 2.0)
    for _ in range(24):
        kobj.location = mål + riktning * avstånd
        kobj.rotation_euler = (mål - kobj.location).to_track_quat("-Z", "Y").to_euler()
        # Utan den här raden är kamerans matris FÖRÅLDRAD och projektionen mäter en kamera som inte
        # finns: mätt — fyra hus "låg utanför bildrutan" med identiska tal före och efter flytten.
        bpy.context.view_layer.update()
        if not allt_i_bild(kobj, objekt):
            break
        avstånd *= 1.10
    return kobj


def allt_i_bild(kobj, objekt: list) -> list[str]:
    """Kontroll: ryms varje hus inom bildrutan? Mätt med kamerans egen projektion."""
    from bpy_extras.object_utils import world_to_camera_view

    scen = bpy.context.scene
    utanför = []
    for obj in objekt:
        if not obj.name.startswith("hus_"):
            continue
        hörn = [(v.co.x, v.co.y, v.co.z) for v in obj.data.vertices]
        xs = [p[0] for p in hörn]
        zs = [p[2] for p in hörn]
        for p in [(min(xs), 0.0, min(zs)), (max(xs), 0.0, max(zs)),
                  (min(xs), 0.0, max(zs)), (max(xs), 0.0, min(zs))]:
            v = world_to_camera_view(scen, kobj, Vector(p))
            if not (0.005 < v.x < 0.995 and 0.005 < v.y < 0.995):
                utanför.append("%s %s → (%.2f, %.2f)" % (obj.name, p, v.x, v.y))
    return utanför


def rendera(bild: Path) -> None:
    bild.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(bild)
    bpy.context.scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def rendera_front(bild: Path) -> None:
    """Helhetsbilden från spelets EGEN vinkel: ortografiskt rakt framifrån (FRONTKAMERA).

    Den sneda bilden ovanifrån visar byn som modell; den här visar den som spelet ser den (2.5D-konsten
    är ritad rakt framifrån), och från den vinkeln syns också att marken räcker ned under gatan.
    """
    scen = bpy.context.scene
    plats, rot_x, ortoskala = FRONTKAMERA
    kam = bpy.data.cameras.new("frontkamera")
    kam.type = "ORTHO"
    kam.ortho_scale = ortoskala
    kobj = bpy.data.objects.new("frontkamera", kam)
    kobj.location = plats
    kobj.rotation_euler = (rot_x, 0.0, 0.0)
    scen.collection.objects.link(kobj)
    scen.camera = kobj
    scen.render.film_transparent = False
    scen.render.image_settings.color_mode = "RGB"
    scen.render.resolution_x, scen.render.resolution_y = 1280, 720
    bpy.context.view_layer.update()
    rendera(bild)


def exportera(glb: Path, objekt: list) -> int:
    """glTF binär med bara byggnaderna: kameran och solen hör till bilden, inte till modellen."""
    glb.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objekt:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objekt[0]
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True)
    return glb.stat().st_size


# ------------------------------------------------------------------ mätningen av modellen mot bilden


def läs_renderad(sökväg: Path, bredd: int, höjd: int) -> tuple[np.ndarray, np.ndarray]:
    """En renderad PNG tillbaka som byte-värden (samma väg som byn.png lästes: Non-Color) OCH alfa.

    Alfa är modellens egen mask: den är EXAKT (en pixel är modell eller himmel), medan en mask byggd
    på "skiljer sig från himlen" är opålitlig — bildens hus är blågrå och ligger nära himlens egen
    färg (mätt: 7-11 av 255 i skillnad, alltså under varje rimlig tröskel).
    """
    img = bpy.data.images.load(str(sökväg), check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    buf = np.empty(bredd * höjd * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = buf.reshape(höjd, bredd, 4)[::-1]
    return ((arr[:, :, :3] * 255.0 + 0.5).astype(np.int32),
            (arr[:, :, 3] * 255.0 + 0.5).astype(np.int32))


def _srgb8(lin: np.ndarray) -> np.ndarray:
    """Linjärt ljus tillbaka till 8-bitars sRGB (samma kurva som linjär(), baklänges)."""
    v = np.clip(lin, 0.0, 1.0)
    ut = np.where(v <= 0.0031308, v * 12.92, 1.055 * np.power(v, 1.0 / 2.4) - 0.055)
    return ut * 255.0


def hus_framifrån(mått: dict, hus_obj: "bpy.types.Object", sökväg: Path) -> tuple[np.ndarray, np.ndarray]:
    """(modell, mask) för huset rakt framifrån, ORTOGRAFISKT, i husets EGNA pixelmått.

    1 renderingpixel = 1 bildpixel: RUTANS höjd styr skalan (inte silhuettens), så modellen och
    husets bildyta hamnar i exakt samma pixelmått och kan jämföras kant mot kant. Förr styrde
    silhuettens höjd, så för varje hus där den inte råkade vara rutans höjd mättes modellen i en
    annan skala än bilden (väveriet: 11 % fel). Renderingen görs med film_transparent så att
    alfastrålen ÄR modellens silhuett (se läs_renderad).
    """
    scen = bpy.context.scene
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj is not hus_obj
    b_px = mått["bredd_px"]
    h_px = mått["gata_px"] - mått["y0_px"]
    rutt = h_px * mått["skala"]
    ort = bpy.data.cameras.new("mätkamera")
    ort.type = "ORTHO"
    ort.ortho_scale = rutt                 # höjden är den större dimensionen (sensor-fit AUTO)
    kobj = bpy.data.objects.new("mätkamera", ort)
    xs = [v.co.x for v in hus_obj.data.vertices]
    kobj.location = ((min(xs) + max(xs)) / 2.0, -60.0, rutt / 2.0)
    kobj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scen.collection.objects.link(kobj)
    scen.camera = kobj
    bpy.context.view_layer.update()
    scen.render.resolution_x, scen.render.resolution_y = b_px, h_px
    scen.render.film_transparent = True
    scen.render.image_settings.color_mode = "RGBA"
    scen.render.filepath = str(sökväg)
    scen.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    return läs_renderad(sökväg, b_px, h_px)


def _toppmönster(mask: np.ndarray, min_solid: int) -> np.ndarray:
    """Överkant per kolumn i en mask: första raden i en sammanhängande massa (min_solid rader).

    Modellens rendering och bilden mäts med SAMMA regel — annars jämförs modellens tak med molnkanter
    (se Bild.topprader). Kolumner utan massa får maskens höjd (räknas inte).
    """
    löp = np.zeros(mask.shape, dtype=np.int32)
    nästa = np.zeros(mask.shape[1], dtype=np.int32)
    for rad_i in range(mask.shape[0] - 1, -1, -1):
        nästa = (nästa + 1) * mask[rad_i]
        löp[rad_i] = nästa
    klar = löp >= min_solid
    har = klar.any(axis=0)
    ut = np.full(mask.shape[1], mask.shape[0], dtype=np.int32)
    ut[har] = klar.argmax(axis=0)[har]
    return ut


def mät_likhet(modell: np.ndarray, mask: np.ndarray, mått: dict, bild: Bild) -> dict:
    """Modellens silhuett mot husets egen i bilden — samma pixelmått, så skillnaden är i bildpixlar.

    Jämförelsen är mot SAMMA kontur som modellen byggdes ur (mått["topp_px"]: bildens massa, median-
    filtrerad), så talet mäter kvantiseringen och sammanslagningen — inte filtret. `*_rå` mäts mot
    bildens råa kontur (där också dis och molnkanter räknas som hus). Båda sidorna mäts med samma
    regel (överkant = första raden i en sammanhängande massa), och modellens mask är renderingens
    egen alfa — en tröskel mot himlens färg går inte (husen är blågrå, se läs_renderad).
    """
    h_px = modell.shape[0]
    v_tak = _toppmönster(mask, MIN_SOLID)
    y0, x0 = mått["y0_px"], mått["x0_px"]
    hmask = ~bild.bakgrund[y0:mått["gata_px"], x0:mått["x1_px"]]
    h_rå = _toppmönster(hmask, 1)
    h_ren = np.array(mått["topp_px"], dtype=np.int32) - y0
    båda = (v_tak < h_px) & (h_ren < h_px)
    skillnad = v_tak.astype(float) - h_ren.astype(float)     # positiv = modellen ligger LÄGRE
    d = np.abs(skillnad[båda])
    drå = np.abs(v_tak[båda] - h_rå[båda]).astype(float)
    return {
        "medel": float(d.mean()), "max": int(d.max()),
        "andel": float((d <= max(1.0, mått["steg_px"])).mean()),
        "medel_rå": float(drå.mean()), "max_rå": int(drå.max()),
        # Riktningarna var för sig: UNDER = tak som saknas (allvarligt), ÖVER = utsmyckning.
        "under": float(np.maximum(0.0, skillnad[båda]).max()),
        "över": float(np.maximum(0.0, -skillnad[båda]).max()),
        "v_tak": v_tak, "h_ren": h_ren, "h_rå": h_rå, "båda": båda,
    }


def _syns(modell: np.ndarray, utan: np.ndarray, ruta: tuple) -> float:
    """Hur stor del av en detaljs ruta som SKILJER sig från samma hus UTAN den detaljen.

    Provet renderar huset två gånger — med och utan dörren (respektive skylten) — i samma kamera och
    med samma utsmyckning. Skillnaden ÄR detaljen: en dörr som inte byggdes, eller som är instoppad
    i ett block, ger noll skillnad och provet faller.
    """
    ra, rb, a, b = ruta
    if rb - ra < 3 or b - a < 3:
        return 0.0
    bit, bit_u = modell[ra:rb, a:b], utan[ra:rb, a:b]
    if bit.size == 0 or bit_u.size == 0:
        return 0.0
    return float((np.abs(bit.astype(int) - bit_u.astype(int)).max(axis=2) > 8).mean())


def kontrollera_hus(p: dict, mått: dict, mät: dict, modell: np.ndarray, utan_dörr: np.ndarray,
                    utan_skylt: np.ndarray, mask: np.ndarray, palett: list) -> list[str]:
    """Proven på ETT hus: silhuett, dörr, skorsten och skylt. Returnerar felen som texter.

    Dörren ska finnas, sitta där bilden visar den och SYNAS (renderingen med huset mot renderingen
    med bara kroppen). Skorstenen ska nå minst två höjdsteg ÖVER nocken där bilden visar en skorsten,
    med toppen inom ett steg från bildens. Skylten ska sitta inom ett steg från bildens höjd (förr:
    78 %, vid taket). Taket får inte ligga mer än KONTUR_PX under bildens kontur.
    """
    fel: list[str] = []
    h_px, b_px = modell.shape[0], modell.shape[1]
    steg = mått["steg_px"]
    if SAKER.get(p["id"], {}).get("sak") == "stolpe":
        # EXIT är ingen huskropp: en skyltstolpe, med flit olik bildens ruta (den är dörren ut ur
        # spelet). Silhuetten kan därför inte mätas mot huset i bilden — men den ska finnas där.
        if int(mask.sum()) < 200:
            fel.append("%s: skyltstolpen syns inte i renderingen (%d px)" % (p["id"], int(mask.sum())))
        return fel
    rutt_px = mått["gata_px"] - mått["y0_px"]
    if mät["under"] > KONTUR_PX:
        fel.append("%s: taket ligger %.0f px UNDER bildens kontur (tillåtet %.0f px)"
                   % (p["id"], mät["under"], KONTUR_PX))
    tak = max(2.0 * steg, UTSMYCKNING * rutt_px)
    if mät["över"] > tak:
        fel.append("%s: modellen sticker %.0f px ÖVER bildens kontur (en utsmyckning får %.0f px)"
                   % (p["id"], mät["över"], tak))
    # DÖRREN: mätt läge och höjd ur bilden, byggd på samma höjd och synlig på fasaden.
    if not mått["dörr"]:
        fel.append("%s: ingen dörr funnen i bildens nederkant" % p["id"])
    else:
        topp = mått["dörr"][2]
        byggd = mått.get("dörr_byggd")
        if byggd is None:
            fel.append("%s: ingen dörr byggdes" % p["id"])
        else:
            ka, kb, byggd_topp = byggd
            if abs(float(byggd_topp) - topp) > steg:
                fel.append("%s: dörren byggdes %.0f px hög men bilden visar %d px"
                           % (p["id"], byggd_topp, topp))
            ra, rb = max(0, h_px - int(byggd_topp) + 2), h_px - 2
            mått["syns_dörr"] = _syns(modell, utan_dörr, (ra, rb, ka + 2, kb - 1))
            # Tröskeln är MÄTT, inte gissad: dörrarna ligger på 39-100 % (smedjan 81 %, juveleraren
            # 100 %), och en dörr som inte byggs ger 0 %. Utsmyckningen framför (tyg, tunnor, ässja)
            # skymmer en del av dörren i den här vyn — därför krävs synlig massa, inte full täckning.
            if mått["syns_dörr"] < 0.30:
                fel.append("%s: dörren syns inte på fasaden (%.0f %% av rutans ytor skiljer sig från "
                           "huset utan dörr)" % (p["id"], 100 * mått["syns_dörr"]))
    # SKORSTENEN: över nocken, och i bildens höjd.
    if mått["skorsten"]:
        sa, sb, skorstens_topp, nock_px = mått["skorsten"]
        runtom = np.concatenate([mät["v_tak"][max(0, sa - int(0.2 * b_px)):sa],
                                 mät["v_tak"][sb:min(b_px, sb + int(0.2 * b_px))]])
        modell_topp = h_px - int(mät["v_tak"][sa:sb].min())
        nock = h_px - float(np.median(runtom)) if runtom.size else float(nock_px)
        if modell_topp - nock < 2.0 * steg:
            fel.append("%s: skorstenen når bara %.0f px över taket runtomkring (två steg är %.0f)"
                       % (p["id"], modell_topp - nock, 2.0 * steg))
        if abs(modell_topp - skorstens_topp) > steg:
            fel.append("%s: skorstenens topp ligger %d px från bildens (%d mot %d)"
                       % (p["id"], abs(modell_topp - skorstens_topp), modell_topp, skorstens_topp))
    # SKYLTEN: ett höjdsteg fel är tillåtet, två är ett fel — och den ska synas på väggen.
    if not mått["skylt"]:
        fel.append("%s: ingen skylt funnen i bilden" % p["id"])
    else:
        sho = mått["skylt"][2]
        byggd = mått.get("skylt_byggd")
        if byggd is None or abs(byggd[2] - mått["skylt_bild"]) > steg:
            fel.append("%s: skylten byggdes på %.0f px men bilden visar %d px"
                       % (p["id"], byggd[2] if byggd else -1.0, mått["skylt_bild"]))
        if byggd:
            ka, kb, höjd = byggd
            band = max(8, int(SKYLT_HÖJD * mått["höjd_px"]))
            ra, rb = max(0, h_px - int(höjd) - band // 3), max(1, h_px - int(höjd) + band // 3)
            mått["syns_skylt"] = _syns(modell, utan_skylt, (ra, rb, ka + 2, kb - 1))
            if mått["syns_skylt"] < 0.30:
                fel.append("%s: skylten syns inte på fasaden (%.0f %% av rutans ytor skiljer sig "
                           "från huset utan skylt)" % (p["id"], 100 * mått["syns_skylt"]))
    return fel


def närbild(p: dict, mått: dict, bild: Bild, hus_obj: "bpy.types.Object", sökväg: Path,
            palett: list) -> tuple:
    """Närbilden: huset renderat rakt framifrån BREDVID sin egen bildyta, i samma pixelmått.

    Vänster halva = modellen (samma väg som provet mäter: hus_framifrån), höger halva = husets EGEN
    ruta ur byn.png. Sedan läses den färdiga bilden tillbaka och den högra halvan jämförs pixel för
    pixel med byn.png — är den inte identisk faller skriptet. Bilden läggs ihop av BYTE-värden
    (Bild.px) i stället för att renderas som två texturerade plan: en textur som samplar en bild i en
    rendervy prickar fel texel vid hårda kanter (mätt: 0,8 % av pixlarna avvek mer än 20 av 255 även
    med exakt träffpunkt). Byte mot byte kan inte hamna snett.
    """
    x0, x1 = mått["x0_px"], mått["x1_px"]
    y0, y1 = mått["y0_px"], mått["gata_px"]
    b_px, h_px = x1 - x0, y1 - y0
    modell, alfa = hus_framifrån(mått, hus_obj, sökväg.parent / "_hus.png")
    # Modellen läggs på himlen igen (renderingen har genomskinlig film för maskens skull). Himlens
    # färg i en rendering är palettens himmel gånger världens styrka, i linjärt ljus — mätt: (81,124,143).
    himmel8 = _srgb8(np.array(linjär(färg(palett, FÄRG_HIMMEL))) * 0.6)
    a = (alfa.astype(np.float64) / 255.0)[:, :, None]
    modell = (modell * a + himmel8[None, None, :] * (1.0 - a)).astype(np.int32)
    ruta = bild.px[y0:y1, x0:x1]
    ihop = np.concatenate([modell, ruta], axis=1)
    höjd, bredd = ihop.shape[:2]
    img = bpy.data.images.new("närbild", bredd, höjd, alpha=False, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    arr = np.dstack([ihop.astype(np.float32) / 255.0, np.ones((höjd, bredd), dtype=np.float32)])
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel())
    img.file_format = "PNG"
    sökväg.parent.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(sökväg)
    img.save()

    # KONTROLLEN: högra halvan ska vara husets EGEN ruta ur byn.png, pixel för pixel — och vänstra
    # halvan ska visa modellen (inte en tom himmel). Masken kommer ur renderingen själv (alfan).
    ut, _ = läs_renderad(sökväg, bredd, höjd)
    avvikelse = int(np.abs(ut[:, b_px:, :] - ruta).max())
    modell_andel = float((alfa > 128).mean())
    print("  närbildens högra halva mot byn.png: största avvikelse %d av 255 %s"
          % (avvikelse, "(identisk)" if avvikelse == 0 else "(AVVIKER)"))
    print("  närbildens vänstra halva: modellen täcker %.0f %% av rutan" % (100 * modell_andel))
    if avvikelse != 0:
        raise SystemExit("FEL: närbildens högra halva är inte husets ruta i bilden (max %d)" % avvikelse)
    if not 0.10 < modell_andel < 0.95:
        raise SystemExit("FEL: närbildens vänstra halva ser fel ut (%.1f %% modell)" % (100 * modell_andel))

    # LIKHETEN: modellens överkant per kolumn mot husets egen i bilden, i bildpixlar.
    m = mät_likhet(modell, alfa > 128, mått, bild)
    print("  likheten: modellens överkant ligger i medeltal %.0f px från bildens (störst %d, "
          "%.0f %% inom ett steg) — ett kvantiseringssteg är %.1f px, bildens råa kontur %d px"
          % (m["medel"], m["max"], 100 * m["andel"], mått["steg_px"], m["max_rå"]))
    return b_px, h_px


# ------------------------------------------------------------------ main


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Bygger byn i 3D ur spelets egen data och byns bild.")
    ap.add_argument("--bara", default="", help="bygg bara den här platsen (id ur PLATSER)")
    ap.add_argument("--bild", default=str(BILD))
    ap.add_argument("--ut", default=str(GLB))
    ap.add_argument("--narbild", default=str(NÄRBILD))
    ap.add_argument("--narhus", default="smed", help="huset i närbilden (id ur PLATSER)")
    ap.add_argument("--kolla", action="store_true",
                    help="mät och kontrollera (renderar varje hus framifrån), rendera inte hela byn")
    ap.add_argument("--bryt", default="", choices=["", "tak", "dörr", "skylt", "skorsten"],
                    help="NEGATIVTEST: bryt med flit mot en regel och visa att --kolla faller")
    args = ap.parse_args(argv)

    t0 = time.time()
    töm_scenen()
    platser, hus_topp, gata_procent = läs_platser()
    palett = läs_palett()
    palett_np = np.array(palett, dtype=np.int32)
    if args.bara:
        platser = [p for p in platser if p["id"] == args.bara]
        if not platser:
            raise SystemExit("FEL: ingen plats med id %r" % args.bara)

    bild = Bild(BYBILD)
    print("BYN I 3D — ur %s och %s" % (VYN.relative_to(ROOT), BYBILD.relative_to(ROOT)))
    print("  bild: %dx%d px (%.2f gånger bredare än hög), himmel/ås bakom husen: %.0f %%"
          % (bild.bredd, bild.höjd, bild.bredd / bild.höjd, 100 * bild.bakgrund.mean()))
    print("  HUS_TOPP %.1f %% (rad %d, ovanför alla tak) · BILDENS_GATA %.1f %% (rad %d)"
          % (hus_topp, int(round(bild.höjd * hus_topp / 100)), gata_procent,
             int(round(bild.höjd * gata_procent / 100))))

    # MÄT alla hus först: bredden i världen kommer ur den bredaste rutan.
    mått = [mät_hus(p, bild, palett_np, hus_topp, gata_procent,
                    8 if args.bryt == "tak" else 0) for p in platser]
    if args.bryt:
        bryt_provet(mått, args.bryt)
        print("  NEGATIVTEST: bryter med flit mot '%s' — provet ska falla" % args.bryt)
    bredaste = max(m["bredd_px"] for m in mått)
    skala = BREDASTE_HUS / bredaste
    for m in mått:
        m["skala"] = skala          # husets skala hör till dess mått (närbilden räknar ur den)
    print("  skala: %d px (bredaste huset, %s) → %.1f enheter  = %.5f enheter per bildpixel"
          % (bredaste, platser[mått.index(max(mått, key=lambda m: m["bredd_px"]))]["id"],
             BREDASTE_HUS, skala))

    print("\n  %-11s %-13s %7s %7s %7s %7s %7s %s" % (
        "plats", "ruta px", "bredd", "höjd", "höjd/b", "taktopp", "block", "vanligaste färger"))
    for p, m in zip(platser, mått):
        b = m["bredd_px"] * skala
        h = m["höjd_px"] * skala
        print("  %-11s %4d-%-4d %7.2f %7.2f %7.2f %6.1f%% %5d %s" % (
            p["id"], m["x0_px"], m["x1_px"], b, h, h / b, 100 * (m["gata_px"] - m["höjd_px"]) / bild.höjd,
            len(m["rutor"]), " ".join("%d:%d%%" % f for f in m["färger"][:4])))

    intervall = dela_ut(mått, skala)
    x0, x1 = min(a for a, _ in intervall), max(b for _, b in intervall)
    print("\n  gatan: %.1f enheter lång, %d hus, luft %.0f %% av grannarnas medelbredd"
          % (x1 - x0, len(platser), 100 * MELLANRUM))
    for p, (a, b) in zip(platser, intervall):
        print("     %-11s x %6.2f .. %6.2f  (bredd %5.2f)" % (p["id"], a, b, b - a))

    # KONTROLLEN: inga hus' x-intervall får skära varandra, parvis.
    skär = []
    for i in range(len(intervall)):
        for j in range(i + 1, len(intervall)):
            if intervall[i][1] > intervall[j][0]:
                skär.append("%s/%s" % (platser[i]["id"], platser[j]["id"]))
    par = len(intervall) * (len(intervall) - 1) // 2
    if skär:
        raise SystemExit("FEL: husens x-intervall skär varandra: %s" % ", ".join(skär))
    print("  KONTROLL: inga hus' x-intervall skär varandra (%d hus, %d par)" % (len(intervall), par))

    # BYGG: husen ur bilden, plus marken och bakgrundslagret.
    samling = bpy.data.collections.new("byn")
    bpy.context.scene.collection.children.link(samling)
    mark = bygg_mark(x0, x1, palett)
    objekt = [gör_objekt(mark, palett, samling)]
    räkning = {"hus": 0, "lådor": mark.lådor, "ytor": len(mark.ytor), "hörn": len(mark.hörn)}
    hus_objekt = []
    for p, m, (a, _b) in zip(platser, mått, intervall):
        bygge = bygg_hus(p, m, palett, skala, (a + _b) / 2.0, 0.0)
        m["x_mitt"] = (a + _b) / 2.0
        # Huset får aldrig gå UTANFÖR sin egen tomt (annars skär två hus' x-intervall varandra), och
        # ska fylla merparten av den — EXIT är en skyltstolpe och får därför vara smalare.
        if bygge.x_min < a - 0.01 or bygge.x_max > _b + 0.01:
            raise SystemExit("FEL: %s byggdes på x %.2f..%.2f men tomten är %.2f..%.2f"
                             % (p["id"], bygge.x_min, bygge.x_max, a, _b))
        if bygge.x_max - bygge.x_min < 0.5 * (_b - a):
            raise SystemExit("FEL: %s fyller bara %.2f av sin tomt på %.2f"
                             % (p["id"], bygge.x_max - bygge.x_min, _b - a))
        obj = gör_objekt(bygge, palett, samling)
        objekt.append(obj)
        hus_objekt.append(obj)
        räkning["hus"] += 1
        räkning["lådor"] += bygge.lådor
        räkning["ytor"] += len(bygge.ytor)
        räkning["hörn"] += len(bygge.hörn)
        if len(bygge.ytor) != 6 * bygge.lådor:
            raise SystemExit("FEL: %s har %d ytor men %d lådor" % (p["id"], len(bygge.ytor), bygge.lådor))
    for namn, bygge in bygg_bakgrund(x0, x1, max(m["höjd_px"] * skala for m in mått)):
        objekt.append(gör_objekt(bygge, palett, samling))
        räkning["lådor"] += bygge.lådor
        räkning["ytor"] += len(bygge.ytor)
        räkning["hörn"] += len(bygge.hörn)
    # Varje hus LOVAS stå på sin plats: bygget ovan mäter det (x_min/x_max mot intervallet).
    print("\n  hus byggda ur bilden: %d · rätblock: %d · ytor: %d · hörn: %d"
          % (räkning["hus"], räkning["lådor"], räkning["ytor"], räkning["hörn"]))
    if räkning["ytor"] != 6 * räkning["lådor"] or räkning["hörn"] != 8 * räkning["lådor"]:
        raise SystemExit("FEL: räkningen stämmer inte (ytor/hörn mot rätblock)")
    if any(len(o.data.polygons) == 0 for o in objekt):
        raise SystemExit("FEL: ett objekt utan ytor")
    print("  byggtid: %.2f s" % (time.time() - t0))

    if args.kolla:
        # PROVEN: varje hus renderas framifrån (ortografiskt, 1 pixel = 1 bildpixel) och modellens
        # tak, dörr, skorsten och skylt mäts mot husets EGEN ruta i byn.png.
        sätt_scen(palett)
        temp = Path(args.bild).parent / "_kolla.png"
        print("\n  %-11s %5s %6s %7s %7s %8s %7s %7s   %s" % (
            "plats", "steg", "block", "medel", "max", "max (rå)", "under", "över",
            "dörr / skylt / skorsten"))
        alla_fel: list[str] = []
        for i, (pl, m) in enumerate(zip(platser, mått)):
            modell, alfa = hus_framifrån(m, hus_objekt[i], temp)
            mask = alfa > 128
            mät = mät_likhet(modell, mask, m, bild)
            # Provet renderar huset TRE gånger: med allt, utan dörr och utan skylt. Skillnaden mellan
            # två renderingar AV SAMMA HUS är detaljen — syns den inte där den byggdes, faller provet.
            utan_dörr = _utan_detalj(pl, m, palett, skala, "hoppa_dörr", samling, temp)
            utan_skylt = _utan_detalj(pl, m, palett, skala, "hoppa_skylt", samling, temp)
            alla_fel += kontrollera_hus(pl, m, mät, modell, utan_dörr, utan_skylt, mask, palett)
            d, sk, ko = m["dörr"], m["skylt"], m["skorsten"]
            stolpe = SAKER.get(pl["id"], {}).get("sak") == "stolpe"
            print("  %-11s %5.1f %6d %7s %7s %8s %7s %7s   %s" % (
                pl["id"], m["steg_px"], len(m["rutor"]),
                "—" if stolpe else "%.1f" % mät["medel"], "—" if stolpe else "%d" % mät["max"],
                "%d" % mät["max_rå"], "—" if stolpe else "%.0f" % mät["under"],
                "—" if stolpe else "%.0f" % mät["över"],
                "stolpe (ingen huskropp i bildens ruta) — silhuetten mäts inte" if stolpe else
                " · ".join([
                    ("dörr x %d-%d, %d px hög, palett %d, syns %.0f %%"
                     % (d[0], d[1], d[2], m["dörrfärg"], 100 * m.get("syns_dörr", 0.0)))
                    if d else "DÖRR SAKNAS",
                    ("skylt x %d-%d på %d px, palett %d, syns %.0f %%"
                     % (sk[0], sk[1], sk[2], m["skyltfärg"], 100 * m.get("syns_skylt", 0.0)))
                    if sk else "SKYLT SAKNAS",
                    ("skorsten x %d-%d: %d px, nock %d px" % ko) if ko else "ingen skorsten i bilden"])))
        if alla_fel:
            if args.bryt:
                print("  NEGATIVTEST: provet föll som det skulle (%d fel):\n    %s"
                      % (len(alla_fel), "\n    ".join(alla_fel)))
                return 0
            raise SystemExit("FEL: " + " · ".join(alla_fel))
        if args.bryt:
            raise SystemExit("FEL: negativtestet '%s' fällde INTE provet — provet biter inte" % args.bryt)
        print("  KONTROLL: ok (%d objekt, %d ytor, 6 ytor/rätblock, %d par utan skärning, "
              "tak/dörr/skylt/skorsten mot bilden)"
              % (len(objekt), räkning["ytor"], par))
        return 0

    sätt_scen(palett)
    topp = max(m["höjd_px"] * skala for m in mått)
    kam = sätt_kamera(x0, x1, topp, hus_objekt)
    utanför = allt_i_bild(kam, hus_objekt)
    if utanför:
        raise SystemExit("FEL: hus utanför bildrutan: %s" % ", ".join(utanför))
    print("  kamera: alla %d hus ryms i bildrutan (mätt med kamerans projektion)" % len(hus_objekt))
    rendera(Path(args.bild))
    # KONTROLL: bilden är inte tom. Referensen är bildens VANLIGASTE färg (himlen, som täcker mest),
    # inte palettens 26 rakt av — världens ljusstyrka gör renderingens himmel mörkare än palettfärgen.
    vy, _ = läs_renderad(Path(args.bild), 1280, 720)
    färger, antal = np.unique(vy.reshape(-1, 3), axis=0, return_counts=True)
    himmel = färger[int(antal.argmax())]
    by_andel = float((np.abs(vy - himmel).max(axis=2) > 12).mean())
    print("  kontroll: %.0f %% av bilden är by (hus, gata, bakgrund) och inte himmel %s"
          % (100 * by_andel, tuple(int(v) for v in himmel)))
    if by_andel < 0.20:
        raise SystemExit("FEL: den renderade bilden är nästan bara himmel (%.0f %%)" % (100 * by_andel))
    # HELHETEN FRÅN SPElets EGEN VINKEL (ortografiskt rakt framifrån, se FRONTKAMERA).
    rendera_front(FRONTBILD)
    fram, _ = läs_renderad(FRONTBILD, 1280, 720)
    toppfärger, toppantal = np.unique(fram[:72, :, :].reshape(-1, 3), axis=0, return_counts=True)
    himmel_f = toppfärger[int(toppantal.argmax())]
    tomt = float((np.abs(fram[612:, :, :] - himmel_f).max(axis=2) <= 12).mean())
    print("  frontbild (spelets egen vinkel): %s (%d byte) — %.0f %% av nederkanten är mark, "
          "inte himmel" % (FRONTBILD, FRONTBILD.stat().st_size, 100 * (1 - tomt)))
    if tomt > 0.20:
        raise SystemExit("FEL: frontbilden visar tom himmel under marken (%.0f %% av nederkanten)"
                         % (100 * tomt))
    storlek = exportera(Path(args.ut), objekt)
    print("  bild: %s (%d byte, %dx%d)"
          % (args.bild, Path(args.bild).stat().st_size, 1280, 720))
    print("  glb:  %s (%d byte, %d mesh-noder)" % (args.ut, storlek, len(objekt)))
    # NÄRBILDEN: det valda huset bredvid sin egen bildyta (kräver att scenen byggs om efteråt).
    valt = [i for i, p in enumerate(platser) if p["id"] == args.narhus]
    if valt:
        i = valt[0]
        w, h = närbild(platser[i], mått[i], bild, hus_objekt[i], Path(args.narbild), palett)
        print("  närbild: %s (%dx%d — modellen till vänster, husets egen ruta %dx%d till höger)"
              % (args.narbild, 2 * w, h, w, h))
    print("  hel tid: %.2f s" % (time.time() - t0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
