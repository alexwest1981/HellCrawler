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

  * SILHUETTEN: för varje kolumn i husets ruta mäts husets överkant mot himlen/bakgrunden (den
    första raden nedifrån sett uppåt som inte är himmel, dis eller blek himmel). Konturen
    kvantiseras till NIVÅER höjdsteg, och varje sammanhängande kolumnremsa blir ett rätblock per steg
    — taklutning, tillbyggnader, torn och skorstenar sitter då där bilden visar dem, för de ÄR
    bildens kontur. En smal, hög remsa blir en skorsten; en låg remsa vid sidan blir en tillbyggnad.
  * FÄRGEN: varje rätblock färgas av de pixlar det täcker i bilden (närmaste palettfärg i
    palette.json). Bilden är INTE palettindexerad (mätt: 249 141 unika färger, 0 % exakta
    palettpixlar, 2,1 % inom |Δ|<10), så färgen är en NÄRMASTE träff, inte ett uppslag.
  * DETALJERNA: dörren läggs där bilden är som mörkast i husets nederkant, fönstren där bilden är
    ljus i väggen — mätt, inte gissat. Torn/skorsten kommer ur silhuetten (se ovan). Skylten
    (skyltbrädan) sitter på fasaden; ässja, tunnor, tinnar, baner och facklor är ORDBOKEN från
    Alex' referensbyggnad, men färgerna är palettens.

SPRIDNINGEN: husen står på EN gata i PLATSER:s ordning med luft mellan sig — luften är 0,55 av
grannarnas medelbredd, och husens inbördes BREDDER är bildens (smedjan 550 px är den bredaste,
EXIT 356 px den smalaste). Kontrollen räknar parvis att inga hus' x-intervall skär varandra.

BAKGRUNDSLAGRET: bakom husen en stadsmur med torn, bakgrundshus, träd, berg och en kulle med får —
samma lager som i referensen, bara rätblock, och färgerna ur paletten (muren 22/7, bergen 20/21,
träden 15). Utan det står husen mot en tom himmel.

FORMSPRÅKET: bara rätblock, inga rundningar, inga avfasningar, inga högdetaljerade modeller — samma
platåiga voxelstil som spelets egen grafik.

UTFILER: game/assets/by/byn.glb (mesharna, importerbar i Godot), en renderad stillbild av hela byn
och en NÄRBILD på ett hus bredvid dess egen bildyta. Provet `-- --kolla` håller räkningen i kontroll
(ytor = 6 * antal lådor), mäter att inga hus' x-intervall skär varandra och faller hellre än skriver
en tom fil.
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

## Den bredaste platsen (smedjan, 550 px) blir så här bred i världen. 1 bildpixel = 0,0109 enheter.
BREDASTE_HUS = 6.0
## Luften mellan två grannar, som andel av deras medelbredd. Referensbyn: husen 2,8-5,6 breda med
## 1,1-2,0 luft mellan sig (centrum 4,5-5,7 isär) — samma sorts luft.
MELLANRUM = 0.55
## Husets djup som andel av dess bredd. Sidovyn säger ingenting om djupet: det är designat.
DJUP = 0.50
## Hur många höjdsteg bildens kontur kvantiseras till. Fler steg = trognare kontur, fler lådor.
NIVÅER = 8
## En kolumnremsa som är smalare än så här (andel av husets bredd) smälts in i grannen.
MIN_REMSA = 0.035
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
        self.mörk = rgb.max(axis=2) < 88
        self.ljus = (rgb.min(axis=2) > 168) & ~self.bakgrund

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


def mät_hus(p: dict, bild: Bild, palett_np: np.ndarray, hus_topp: float, gata_procent: float) -> dict:
    """Husets mått ur dess EGEN ruta i byn.png: bredd, kontur per kolumn och färg per höjdband."""
    x0 = int(round(bild.bredd * p["x0"] / 100.0))
    x1 = int(round(bild.bredd * p["x1"] / 100.0))
    y0 = int(round(bild.höjd * hus_topp / 100.0))
    gata = int(round(bild.höjd * gata_procent / 100.0))
    if x1 - x0 < 8:
        raise SystemExit("FEL: %s har en ruta på %d px" % (p["id"], x1 - x0))
    # 1) SILHUETTEN: första raden ovanifrån som inte är bakgrund, per kolumn.
    topp = np.full(x1 - x0, gata, dtype=int)
    for c in range(x0, x1):
        k = np.nonzero(~bild.bakgrund[y0:gata, c])[0]
        if k.size:
            topp[c - x0] = y0 + int(k[0])
    topp = medianfiltra(topp, 10)               # ±10 px: en fågel eller ett moln får inte bli ett torn
    profil = (gata - topp).astype(int)          # husets höjd över gatan, i px, per kolumn
    # 2) HÖJDSTEGEN: kvantisera konturen. Ett steg är en sjättedel av husets egen höjd.
    steg = max(1.0, float(profil.max()) / NIVÅER)
    nivå = np.clip(np.round(profil / steg), 1, NIVÅER).astype(int)
    # 3) REMSOR: slå ihop korta remsor med grannen till vänster (en 3 px spik är ingen tillbyggnad).
    remsor: list[list[int]] = []
    for i in range(nivå.size):
        if remsor and remsor[-1][2] == nivå[i]:
            remsor[-1][1] = i
        else:
            remsor.append([i, i, int(nivå[i])])
    min_px = max(4, int(MIN_REMSA * (x1 - x0)))
    ren: list[list[int]] = []
    for a, b, n in remsor:
        if (b - a + 1) < min_px and ren:
            ren[-1][1] = b                     # smält in i grannen: behåll grannens nivå
        else:
            ren.append([a, b, n, n])
    # 4) FÄRGEN per band: de pixlar bandet täcker i bilden, matchade mot paletten.
    idx = bild.närmast_palett(palett_np, (y0, gata, x0, x1))
    idx = idx.reshape(gata - y0, x1 - x0)
    bandfärg: dict[tuple[int, int, int], int] = {}
    for a, b, n, _ in ren:
        for L in range(1, n + 1):
            ra = max(0, (gata - y0) - int(L * steg))
            rb = max(1, (gata - y0) - int((L - 1) * steg))
            region = idx[ra:rb, a:b + 1].ravel()
            egna = region[~np.isin(region, list(FÄRG_BAKGRUND))]
            if egna.size == 0:
                egna = region
            bandfärg[(a, b, L)] = int(np.bincount(egna).argmax()) if egna.size else int(p["färg"])
    # 5) DETALJER: dörr (mörkt i nederkanten), fönster (ljust i väggen), skylt (ljust/guld högt).
    höjd = int(profil.max())
    mörkreg = bild.mörk[y0:gata, x0:x1]
    ljusreg = bild.ljus[y0:gata, x0:x1]
    dörrband = mörkreg[max(0, (gata - y0) - int(0.30 * höjd)):, :]
    dörr = _kluster(dörrband, 0.45, max(6, int(0.04 * (x1 - x0))))
    fönsterband = ljusreg[max(0, (gata - y0) - int(0.80 * höjd)):max(1, (gata - y0) - int(0.30 * höjd)), :]
    fönster = _kluster(fönsterband, 0.25, max(6, int(0.05 * (x1 - x0))))[:3]
    skyltband = ljusreg[max(0, (gata - y0) - int(1.0 * höjd)):max(1, (gata - y0) - int(0.80 * höjd)), :]
    skylt = _kluster(skyltband, 0.30, max(6, int(0.06 * (x1 - x0))))
    return {
        "x0_px": x0, "x1_px": x1, "y0_px": y0, "gata_px": gata,
        "bredd_px": x1 - x0, "höjd_px": höjd,
        "topp_px": topp.tolist(), "profil_px": profil.tolist(),
        "remsor": ren, "bandfärg": bandfärg, "steg_px": steg,
        "dörr": dörr, "fönster": fönster, "skylt": skylt,
        "färger": _dominanta(idx, 6),
    }


def _kluster(reg: np.ndarray, andel: float, min_px: int) -> list[tuple[int, int]]:
    """Sammanhängande kolumnremsor där en andel av raderna är markerade. (x-led, i rutan.)"""
    if reg.size == 0 or reg.shape[0] == 0:
        return []
    kol = reg.mean(axis=0) >= andel
    ut: list[tuple[int, int]] = []
    a = -1
    for i, v in enumerate(kol):
        if v and a < 0:
            a = i
        elif not v and a >= 0:
            if i - a >= min_px:
                ut.append((a, i))
            a = -1
    if a >= 0 and len(kol) - a >= min_px:
        ut.append((a, len(kol)))
    return sorted(ut, key=lambda t: t[0] - t[1])


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


def bygg_hus(p: dict, mått: dict, palett: list, skala: float, x_mitt: float, botten: float) -> Bygge:
    """Ett hus: bildens kontur som staplade rätblock, bildens färger, dörr och fönster där de sitter."""
    b = mått["bredd_px"] * skala
    d = DJUP * b
    bygge = Bygge("hus_" + p["id"])
    steg = mått["steg_px"] * skala
    # KROPPEN: en stapel per kolumnremsa och höjdsteg — konturen blir trappad, aldrig en slät låda.
    for a, bb, n, _ in mått["remsor"]:
        bredd = (bb - a + 1) * skala
        cx = x_mitt - b / 2.0 + (a + (bb - a + 1) / 2.0) * skala
        # Ett smalt, högt torn är smalare på djupet än en bred kropp (annars blir det en platta).
        djup = min(d, max(0.45, DJUP * bredd))
        for L in range(1, n + 1):
            fi = mått["bandfärg"].get((a, bb, L), FÄRG_SKYLT)
            bygge.låda((cx, 0.0, botten + (L - 0.5) * steg), (bredd, djup, steg), fi)
    # DÖRREN: där bilden är som mörkast i husets nederkant (annars mitt på fasaden).
    fram = -d / 2.0 - 0.05
    höjd = mått["höjd_px"] * skala
    hus_a, hus_b = x_mitt - b / 2.0, x_mitt + b / 2.0
    if mått["dörr"]:
        a, bb = mått["dörr"][0]
        dx = x_mitt - b / 2.0 + (a + bb) / 2.0 * skala
        dbredd = max(0.5, (bb - a) * skala)
    else:
        dx, dbredd = x_mitt, max(0.5, b * 0.20)
    bygge.låda((_innanför(dx, dbredd, hus_a, hus_b), fram, botten + höjd * 0.16),
               (min(dbredd, b), 0.12, höjd * 0.32), FÄRG_DÖRR)
    # FÖNSTREN: där bilden är ljus i väggen (annars två symmetriska).
    if mått["fönster"]:
        for a, bb in mått["fönster"]:
            fx = x_mitt - b / 2.0 + (a + bb) / 2.0 * skala
            fbredd = max(0.35, (bb - a) * skala)
            bygge.låda((_innanför(fx, fbredd, hus_a, hus_b), fram, botten + höjd * 0.52),
                       (min(fbredd, b), 0.12, höjd * 0.16), FÄRG_FÖNSTER)
    else:
        for dx_ in (-0.28, 0.28):
            bygge.låda((x_mitt + b * dx_, fram, botten + höjd * 0.52),
                       (b * 0.16, 0.12, höjd * 0.16), FÄRG_FÖNSTER)
    # SKYLTEN: en bräda på fasaden där bilden är ljus högt upp (annars över dörren).
    if mått["skylt"]:
        a, bb = mått["skylt"][0]
        sx = x_mitt - b / 2.0 + (a + bb) / 2.0 * skala
        sbredd = max(0.5, (bb - a) * skala)
    else:
        sx, sbredd = x_mitt, max(0.5, b * 0.55)
    bygge.låda((_innanför(sx, sbredd, hus_a, hus_b), fram - 0.08, botten + höjd * 0.78),
               (min(sbredd, b), 0.10, höjd * 0.12), FÄRG_SKYLT)
    # PLATSENS EGET: ordboken från referensen, färgerna ur paletten.
    bygge = _saken(p, bygge, x_mitt, b, d, höjd, botten)
    return bygge


def _innanför(x: float, bredd: float, hus_a: float, hus_b: float) -> float:
    """Håll en detalj inom husets EGET x-intervall.

    Utan den här raden sticker en dörr, en tunna eller en städ ut i luften mellan husen, och då
    gäller inte kontrollen att inga hus' x-intervall skär varandra (mätt: smedjan byggdes 0,12
    enheter utanför sin egen ruta).
    """
    halv = min(bredd, hus_b - hus_a) / 2.0
    return min(max(x, hus_a + halv), hus_b - halv)


def _saken(p: dict, bygge: Bygge, x: float, b: float, d: float, h: float, botten: float) -> Bygge:
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
        # PORTEN: tinnar (krenelering) längs taket, facklor och två baner.
        steg = max(0.30, b * 0.07)
        n = max(3, int(b / (steg * 2.2)))
        for i in range(n):
            dlåda(-b / 2.0 + b * (i + 0.5) / n, 0.0, h * 0.98, (steg, d * 0.5, h * 0.06), 22)
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


def exportera(glb: Path, objekt: list) -> int:
    """glTF binär med bara byggnaderna: kameran och solen hör till bilden, inte till modellen."""
    glb.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objekt:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objekt[0]
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True)
    return glb.stat().st_size


# ------------------------------------------------------------------ närbilden


def läs_renderad(sökväg: Path, bredd: int, höjd: int) -> np.ndarray:
    """En renderad PNG tillbaka som byte-värden (samma väg som byn.png lästes: Non-Color)."""
    img = bpy.data.images.load(str(sökväg), check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    buf = np.empty(bredd * höjd * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    return (buf.reshape(höjd, bredd, 4)[::-1, :, :3] * 255.0 + 0.5).astype(np.int32)


def närbild(p: dict, mått: dict, bild: Bild, hus_obj: "bpy.types.Object", sökväg: Path) -> tuple:
    """Närbilden: huset renderat rakt framifrån BREDVID sin egen bildyta, i samma pixelmått.

    Vänster halva = modellen (ortografiskt, en bildpixel = en enhet), höger halva = husets EGEN
    ruta ur byn.png. Sedan läses den färdiga bilden tillbaka och den högra halvan jämförs pixel för
    pixel med byn.png — är den inte identisk faller skriptet.
    """
    x0, x1 = mått["x0_px"], mått["x1_px"]
    y0, y1 = mått["y0_px"], mått["gata_px"]
    b_px, h_px = x1 - x0, y1 - y0
    scen = bpy.context.scene
    hus_rend = sökväg.parent / "_hus.png"

    # --- 1) huset rakt framifrån, ortografiskt, i rutans eget pixelmått
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj is not hus_obj
    ort = bpy.data.cameras.new("närkamera")
    ort.type = "ORTHO"
    # ORTOGRAFISKT och i husets EGEN skala: höjden i världen är husets höjd i bilden gånger skalan,
    # och bildrutan har samma proportioner som husets ruta — då hamnar modellen och bildytan i
    # EXAKT samma pixelmått och kan jämföras kant mot kant.
    hus_höjd = mått["höjd_px"] * mått["skala"]
    ort.ortho_scale = hus_höjd              # höjden är den större dimensionen (sensor-fit AUTO)
    kobj = bpy.data.objects.new("närkamera", ort)
    xs = [v.co.x for v in hus_obj.data.vertices]
    kobj.location = ((min(xs) + max(xs)) / 2.0, -60.0, hus_höjd / 2.0)
    kobj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scen.collection.objects.link(kobj)
    scen.camera = kobj
    bpy.context.view_layer.update()
    scen.render.resolution_x, scen.render.resolution_y = b_px, h_px
    scen.render.filepath = str(hus_rend)
    scen.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)

    # --- 2) de två halvorna sida vid sida: modellen till vänster, husets EGEN ruta till höger.
    # Bilden läggs ihop av BYTE-värden (Bild.px) i stället för att renderas som två texturerade
    # plan: en textur som samplar en bild i en rendervy prickar fel texel vid hårda kanter (mätt:
    # 0,8 % av pixlarna avvek mer än 20 av 255 även med exakt träffpunkt). Byte mot byte kan inte
    # hamna snett.
    modell = läs_renderad(hus_rend, b_px, h_px)
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

    # --- 3) KONTROLLEN: högra halvan ska vara husets EGEN ruta ur byn.png, pixel för pixel — och
    # vänstra halvan ska visa modellen (inte en tom himmel).
    ut = läs_renderad(sökväg, bredd, höjd)
    avvikelse = int(np.abs(ut[:, b_px:, :] - ruta).max())
    # Vänstra halvan: modellens andel av rutans yta, mätt mot renderingens EGEN himmel (hörnpixeln).
    himmel = ut[0, 0, :]
    modell_andel = float((np.abs(ut[:, :b_px, :] - himmel).max(axis=2) > 12).mean())
    print("  närbildens högra halva mot byn.png: största avvikelse %d av 255 %s"
          % (avvikelse, "(identisk)" if avvikelse == 0 else "(AVVIKER)"))
    print("  närbildens vänstra halva: modellen täcker %.0f %% av rutan" % (100 * modell_andel))
    if avvikelse != 0:
        raise SystemExit("FEL: närbildens högra halva är inte husets ruta i bilden (max %d)" % avvikelse)
    if not 0.10 < modell_andel < 0.95:
        raise SystemExit("FEL: närbildens vänstra halva ser fel ut (%.1f %% modell)" % (100 * modell_andel))

    # LIKHETEN, mätt: modellens överkant per kolumn mot husets egen överkant i bilden. Samma
    # pixelmått i de två halvorna, så skillnaden är i bildpixlar. Modellens kontur är bildens
    # kvantiserad i sex steg, så ett par tiotal px är väntat — ett steg är husets höjd / 6.
    vänster_mask = np.abs(ut[:, :b_px, :] - ut[0, 0, :]).max(axis=2) > 12
    höger_mask = ~bild.bakgrund[y0:y1, x0:x1]
    v_tak = np.full(b_px, h_px)
    h_tak = np.full(b_px, h_px)
    for c in range(b_px):
        kv = np.nonzero(vänster_mask[:, c])[0]
        kh = np.nonzero(höger_mask[:, c])[0]
        if kv.size:
            v_tak[c] = kv[0]
        if kh.size:
            h_tak[c] = kh[0]
    båda = (v_tak < h_px) & (h_tak < h_px)
    skillnad = np.abs(v_tak[båda] - h_tak[båda])
    print("  likheten: modellens överkant ligger i medeltal %.0f px från bildens (störst %d, %.0f %% inom 20 px)"
          " — ett kvantiseringssteg är %d px"
          % (skillnad.mean(), int(skillnad.max()), 100 * (skillnad <= 20).mean(),
             int(mått["steg_px"])))
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
    ap.add_argument("--kolla", action="store_true", help="räkna och kontrollera, rendera inte")
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
    mått = [mät_hus(p, bild, palett_np, hus_topp, gata_procent) for p in platser]
    bredaste = max(m["bredd_px"] for m in mått)
    skala = BREDASTE_HUS / bredaste
    for m in mått:
        m["skala"] = skala          # husets skala hör till dess mått (närbilden räknar ur den)
    print("  skala: %d px (bredaste huset, %s) → %.1f enheter  = %.5f enheter per bildpixel"
          % (bredaste, platser[mått.index(max(mått, key=lambda m: m["bredd_px"]))]["id"],
             BREDASTE_HUS, skala))

    print("\n  %-11s %-13s %7s %7s %7s %7s %7s %s" % (
        "plats", "ruta px", "bredd", "höjd", "höjd/b", "taktopp", "stenar", "vanligaste färger"))
    for p, m in zip(platser, mått):
        b = m["bredd_px"] * skala
        h = m["höjd_px"] * skala
        print("  %-11s %4d-%-4d %7.2f %7.2f %7.2f %6.1f%% %5d %s" % (
            p["id"], m["x0_px"], m["x1_px"], b, h, h / b, 100 * (m["gata_px"] - m["höjd_px"]) / bild.höjd,
            len(m["remsor"]), " ".join("%d:%d%%" % f for f in m["färger"][:4])))

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
        print("  KONTROLL: ok (%d objekt, %d ytor, 6 ytor/rätblock, %d par utan skärning)"
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
    vy = läs_renderad(Path(args.bild), 1280, 720)
    färger, antal = np.unique(vy.reshape(-1, 3), axis=0, return_counts=True)
    himmel = färger[int(antal.argmax())]
    by_andel = float((np.abs(vy - himmel).max(axis=2) > 12).mean())
    print("  kontroll: %.0f %% av bilden är by (hus, gata, bakgrund) och inte himmel %s"
          % (100 * by_andel, tuple(int(v) for v in himmel)))
    if by_andel < 0.20:
        raise SystemExit("FEL: den renderade bilden är nästan bara himmel (%.0f %%)" % (100 * by_andel))
    storlek = exportera(Path(args.ut), objekt)
    print("  bild: %s (%d byte, %dx%d)"
          % (args.bild, Path(args.bild).stat().st_size, 1280, 720))
    print("  glb:  %s (%d byte, %d mesh-noder)" % (args.ut, storlek, len(objekt)))
    # NÄRBILDEN: det valda huset bredvid sin egen bildyta (kräver att scenen byggs om efteråt).
    valt = [i for i, p in enumerate(platser) if p["id"] == args.narhus]
    if valt:
        i = valt[0]
        w, h = närbild(platser[i], mått[i], bild, hus_objekt[i], Path(args.narbild))
        print("  närbild: %s (%dx%d — modellen till vänster, husets egen ruta %dx%d till höger)"
              % (args.narbild, 2 * w, h, w, h))
    print("  hel tid: %.2f s" % (time.time() - t0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
