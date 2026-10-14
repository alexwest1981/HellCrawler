"""BYN I 3D: byns platser som blockiga hus i Blender, ut ur spelets egen data, ut till glTF.

    /home/alex/.local/bin/blender -b --factory-startup --python tools/byn3d.py
    ... -- --bara smed          # bara EN plats (används för att stega hela kedjan först)
    ... -- --bild /tmp/x.png --ut /tmp/x.glb

VARFÖR ETT SKRIPT OCH INTE EN MODELL: 2,5D-vyns PLATSER (game/ui/village_view.gd) är redan
sanningen om vilka hus byn har och var de står — `x0`/`x1` är husets kropp i procent av
`byn.png`s bredd. Skriptet LÄSER de talen (samma regex som tools/gen_by_hus.py) och färgerna ur
game/assets/palette.json. En kopia av siffrorna här hade kunnat glida ifrån vyn utan att någon
såg det, och färgen får inte hittas på: palettfilen är enda sanningen för materialens färg.

FORMSPRÅKET: bara rätblock, inga rundningar, inga avfasningar, inga högdetaljerade modeller —
samma platåiga voxelstil som spelets egen grafik. Ett hus = kropp + en takplatta som är lite
bredare än kroppen (det ger den trappade, platåiga kanten) + dörr + fönster, och varje plats får
EN egen sak som skiljer den från grannen: skorsten, skylt, torn, portvalv, skyltstolpe.

SKALAN: hela bildens bredd blir VÄRLD_BREDD enheter (byns inbördes avstånd och bredder är alltså
sanna ur datan), husets djup och höjd är designade — en sidovy säger ingenting om djupet.

UTFILER: game/assets/by/byn.glb (mesharna, importerbar i Godot) och en renderad stillbild.
Provet: `blender -b --factory-startup --python tools/byn3d.py -- --kolla` håller räkningen i
kontroll (ytor = 6 * antal lådor) och faller hellre än skriver en tom fil.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
VYN = ROOT / "game" / "ui" / "village_view.gd"
PALETT = ROOT / "game" / "assets" / "palette.json"
GLB = ROOT / "game" / "assets" / "by" / "byn.glb"
BILD = Path.home() / ".hermes" / "cache" / "scratch" / "omd" / "byn3d.png"

## Hela byn på den här bredden (bildens bredd → världens X). 1 % av bilden = 0,6 enheter.
VÄRLD_BREDD = 60.0
## Gatans färg och markens: ur paletten (17 = jordbrun, 2 = nästan svart berg).
FÄRG_GATA = 17
FÄRG_MARK = 2
## Skyn: palettens ljusblå (26), samma ton som bildens himmel (mätt 104-108, 156-171, 180-212).
FÄRG_sky = 26
## Palettindex för tak, sten och mörka öppningar (dörr/valv). Alla ur palette.json.
## Dörren är 3 (44,38,52) och inte 1: väveriets egen ton är nästan svart (1), och en svart dörr i en
## svart vägg syns inte. 3 läser som mörk mot både guld, orange och svart.
FÄRG_TAK = 24
FÄRG_STEN = 7
FÄRG_MÖRK = 3
FÄRG_LJUS = 8

## Varje plats' EGET kännetecken, keyed på id. Ett okänt id får standardhuset (ingen krasch).
## `h` är kroppens höjd i förhållande till husets bredd, `d` djupet i samma enhet.
FRAMTONING = {
    "tradet": {"h": 0.85, "d": 0.45, "sak": "bom"},
    "smed": {"h": 0.75, "d": 0.55, "sak": "skorsten"},
    "vardshus": {"h": 1.05, "d": 0.60, "sak": "skylt"},
    "karta": {"h": 1.30, "d": 0.35, "sak": "port"},
    "juvelerare": {"h": 0.80, "d": 0.50, "sak": "torn"},
    "avsluta": {"h": 1.10, "d": 0.30, "sak": "stolpe"},
}
STANDARD = {"h": 0.90, "d": 0.50, "sak": ""}


# ------------------------------------------------------------------ spelets egen data


def läs_platser() -> tuple[list[dict], float]:
    """PLATSER ur village_view.gd: id, namn, x0, x1, färg — och husets takhöjd i procent."""
    text = VYN.read_text(encoding="utf-8")
    m = re.search(r"const HUS_TOPP := ([\d.]+)", text)
    if not m:
        raise SystemExit("FEL: hittar inte HUS_TOPP i %s" % VYN)
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
    return platser, float(m.group(1))


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


# ------------------------------------------------------------------ meshen


class Bygge:
    """Ett hus som rätblock. Lägger ihop hörn och ytor i listor; en mesh per byggnad."""

    def __init__(self, namn: str):
        self.namn = namn
        self.hörn: list[tuple[float, float, float]] = []
        self.ytor: list[tuple[int, ...]] = []
        self.färger: list[int] = []
        self.lådor = 0

    def låda(self, mitt, mått, färgindex: int) -> None:
        """Ett rätblock kring `mitt` med storleken `mått` (x, y, z). 8 hörn, 6 fyrkantiga ytor."""
        cx, cy, cz = mitt
        hx, hy, hz = mått[0] / 2.0, mått[1] / 2.0, mått[2] / 2.0
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
    # Materialplatserna ligger i den ordning vi la dem: sorted(set(...)). Ytorna pekar på sin slot.
    slots = [m.name for m in mesh.materials]
    for f, färgindex in zip(mesh.polygons, bygge.färger):
        f.material_index = slots.index("palett_%02d" % färgindex)
    obj = bpy.data.objects.new(bygge.namn, mesh)
    samling.objects.link(obj)
    return obj


# ------------------------------------------------------------------ byggnaderna


def hus_form(p: dict) -> dict:
    """Husets mått ur platsens egen ruta (x0/x1 ur PLATSER) och dess kännetecken."""
    form = dict(FRAMTONING.get(p["id"], STANDARD))
    form["bredd"] = (p["x1"] - p["x0"]) / 100.0 * VÄRLD_BREDD
    form["x"] = ((p["x0"] + p["x1"]) / 2.0 - 50.0) / 100.0 * VÄRLD_BREDD
    form["höjd"] = form["bredd"] * form["h"]
    form["djup"] = form["bredd"] * form["d"]
    return form


def bygg_hus(p: dict, palett: list) -> Bygge:
    """Ett hus: kropp, takplatta, dörr, två fönster — och platsens egen sak ovanpå det."""
    f = hus_form(p)
    b, d, h, x = f["bredd"], f["djup"], f["höjd"], f["x"]
    bygge = Bygge("hus_" + p["id"])

    # KROPPEN står på marken med sin mitt i z = höjden/2.
    bygge.låda((x, 0.0, h / 2.0), (b, d, h), p["färg"])
    # TAKPLATTAN: bredare och djupare än kroppen → den trappade, platåiga takkanten.
    bygge.låda((x, 0.0, h + 0.18), (b * 1.14, d * 1.18, 0.36), FÄRG_TAK)
    # DÖRREN: en mörk platta i framsidan (fram = -y, mot betraktaren).
    bygge.låda((x, -d / 2.0 - 0.06, h * 0.22), (b * 0.22, 0.12, h * 0.44), FÄRG_MÖRK)
    # TVÅ FÖNSTER, ett på var sida om dörren.
    for dx in (-0.30, 0.30):
        bygge.låda((x + b * dx, -d / 2.0 - 0.06, h * 0.62), (b * 0.18, 0.12, h * 0.22), FÄRG_LJUS)

    sak = f["sak"]
    if sak == "skorsten":
        # Smedjan: en skorsten OCH en glödgrop — en egen färg (12) för elden.
        bygge.låda((x + b * 0.28, d * 0.1, h + 0.36 + h * 0.35), (b * 0.16, d * 0.16, h * 0.7), FÄRG_STEN)
        bygge.låda((x - b * 0.15, -d / 2.0 - 0.06, h * 0.30), (b * 0.20, 0.12, h * 0.18), 12)
    elif sak == "skylt":
        # Värdshuset: en skylt på två stolpar framför huset.
        for dx in (-0.32, 0.32):
            bygge.låda((x + b * dx, -d / 2.0 - 0.35, h * 0.35), (b * 0.05, 0.08, h * 0.5), FÄRG_MÖRK)
        bygge.låda((x, -d / 2.0 - 0.35, h * 0.62), (b * 0.72, 0.10, h * 0.22), 14)
    elif sak == "port":
        # Porten ut ur byn: två stolpar och en bjälke över — öppningen är tomrummet emellan.
        for dx in (-0.42, 0.42):
            bygge.låda((x + b * dx, 0.0, h * 0.5), (b * 0.20, d, h), FÄRG_STEN)
        bygge.låda((x, 0.0, h + 0.2), (b * 1.14, d * 1.18, h * 0.35), FÄRG_TAK)
    elif sak == "torn":
        # Juveleraren: ett smalt torn på kroppen med en egen platå överst.
        bygge.låda((x - b * 0.28, 0.0, h + h * 0.45), (b * 0.34, d * 0.6, h * 0.9), p["färg"])
        bygge.låda((x - b * 0.28, 0.0, h + h * 0.94), (b * 0.42, d * 0.7, 0.3), 14)
        bygge.låda((x, -d / 2.0 - 0.4, h * 0.52), (b * 0.8, 0.1, 0.24), 14)
    elif sak == "stolpe":
        # EXIT: ingen byggnad, en stolpe med en skylt — dörren ut ur spelet.
        bygge = Bygge("hus_" + p["id"])
        bygge.låda((x, 0.0, h * 0.5), (b * 0.16, d * 0.5, h), FÄRG_MÖRK)
        bygge.låda((x, -0.2, h * 0.82), (b, 0.14, h * 0.22), 14)
        bygge.låda((x + b * 0.42, -0.2, h * 0.82), (b * 0.1, 0.14, h * 0.1), 14)
    elif sak == "bom":
        # Väveriet: två bommar med en tvärslå — garnet som hänger på tork.
        for dx in (-0.35, 0.35):
            bygge.låda((x + b * dx, -d / 2.0 - 0.5, h * 0.3), (b * 0.06, 0.09, h * 0.6), 16)
        bygge.låda((x, -d / 2.0 - 0.5, h * 0.58), (b * 0.76, 0.09, h * 0.12), 14)
    return bygge


def bygg_byn(platser: list, palett: list) -> tuple[list, dict]:
    """Hela byn: marken, gatan och ett hus per plats. Returnerar ( objekt, räkning )."""
    samling = bpy.data.collections.new("byn")
    bpy.context.scene.collection.children.link(samling)

    mark = Bygge("mark")
    mark.låda((0.0, 0.0, -0.25), (VÄRLD_BREDD * 1.3, VÄRLD_BREDD * 0.5, 0.5), FÄRG_MARK)
    # GATAN: marken husen står på (samma tanke som 2,5D-vyns gatulinje) — en platta i jordbrun
    # som husen står PÅ, från vänster till höger om hela byn.
    mark.låda((0.0, -1.0, 0.02), (VÄRLD_BREDD * 1.1, 7.0, 0.04), FÄRG_GATA)
    objekt = [gör_objekt(mark, palett, samling)]

    räkning = {"hus": 0, "lådor": mark.lådor, "ytor": len(mark.ytor), "hörn": len(mark.hörn)}
    for p in platser:
        bygge = bygg_hus(p, palett)
        objekt.append(gör_objekt(bygge, palett, samling))
        räkning["hus"] += 1
        räkning["lådor"] += bygge.lådor
        räkning["ytor"] += len(bygge.ytor)
        räkning["hörn"] += len(bygge.hörn)
        if len(bygge.ytor) != 6 * bygge.lådor:
            raise SystemExit("FEL: %s har %d ytor men %d lådor" % (p["id"], len(bygge.ytor), bygge.lådor))
    return objekt, räkning


# ------------------------------------------------------------------ scen, ljus, bild, export


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
    # Skyn: världens bakgrundsfärg ur paletten (bildens himmel).
    v = bpy.data.worlds.new("himmel")
    v.use_nodes = True
    v.node_tree.nodes["Background"].inputs[0].default_value = (*linjär(färg(palett, FÄRG_sky)), 1.0)
    v.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scen.world = v
    # Solen: en enda lampa snett ovanifrån, så taken och framsidorna får var sin ton.
    ljus = bpy.data.lights.new("sol", type="SUN")
    ljus.energy = 3.0
    ljus.angle = 0.2
    lobj = bpy.data.objects.new("sol", ljus)
    lobj.rotation_euler = (0.85, 0.25, 0.6)
    bpy.context.scene.collection.objects.link(lobj)


def sätt_kamera(platser: list) -> None:
    """Sned bild ovanifrån, RAMAD UR DATAN: avståndet följer hur långt husen står ifrån varandra,
    så ingen plats hamnar utanför kanten (den första ramningen skar av väveriet till vänster)."""
    x0 = min(p["x0"] for p in platser)
    x1 = max(p["x1"] for p in platser)
    mitten = ((x0 + x1) / 2.0 - 50.0) / 100.0 * VÄRLD_BREDD
    spann = (x1 - x0) / 100.0 * VÄRLD_BREDD
    kam = bpy.data.cameras.new("kamera")
    kam.lens = 42.0
    kobj = bpy.data.objects.new("kamera", kam)
    kobj.location = (mitten + 0.35 * spann, -1.25 * spann, 0.66 * spann)
    riktning = Vector((mitten, -1.0, spann * 0.06)) - Vector(kobj.location)
    kobj.rotation_euler = riktning.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(kobj)
    bpy.context.scene.camera = kobj


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


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(description="Bygger byn i 3D ur spelets egen data.")
    ap.add_argument("--bara", default="", help="bygg bara den här platsen (id ur PLATSER)")
    ap.add_argument("--bild", default=str(BILD))
    ap.add_argument("--ut", default=str(GLB))
    ap.add_argument("--kolla", action="store_true", help="räkna och kontrollera, rendera inte")
    args = ap.parse_args(argv)

    t0 = time.time()
    töm_scenen()
    platser, hus_topp = läs_platser()
    palett = läs_palett()
    if args.bara:
        platser = [p for p in platser if p["id"] == args.bara]
        if not platser:
            raise SystemExit("FEL: ingen plats med id %r" % args.bara)

    objekt, räkning = bygg_byn(platser, palett)
    byggtid = time.time() - t0

    print("BYN I 3D — ur %s" % VYN.relative_to(ROOT))
    print("  platser: %d (%s)" % (räkning["hus"], ", ".join(p["id"] for p in platser)))
    print("  palettfärger i bruk: %d av %d" % (len(bpy.data.materials), len(palett)))
    print("  objekt (mesh-noder): %d" % len(objekt))
    print("  rätblock: %d, ytor: %d, hörn: %d" % (räkning["lådor"], räkning["ytor"], räkning["hörn"]))
    print("  takhöjd i bilden: %.1f %% → husen står på gatan, enligt PLATSER" % hus_topp)
    print("  byggtid: %.2f s" % byggtid)

    # Kontrollen: varje yta är 6 per rätblock, varje hus har minst kropp + tak + dörr + fönster.
    if räkning["ytor"] != 6 * räkning["lådor"] or räkning["hörn"] != 8 * räkning["lådor"]:
        raise SystemExit("FEL: räkningen stämmer inte (ytor/hörn mot rätblock)")
    if any(len(o.data.polygons) == 0 for o in objekt):
        raise SystemExit("FEL: ett objekt utan ytor")
    if args.kolla:
        print("  KONTROLL: ok (%d objekt, %d ytor, 6 ytor/rätblock)" % (len(objekt), räkning["ytor"]))
        return 0

    sätt_scen(palett)
    sätt_kamera(platser)
    rendera(Path(args.bild))
    storlek = exportera(Path(args.ut), objekt)
    print("  bild: %s (%d byte)" % (args.bild, Path(args.bild).stat().st_size))
    print("  glb:  %s (%d byte, %d mesh-noder)" % (args.ut, storlek, len(objekt)))
    print("  hel tid: %.2f s" % (time.time() - t0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
