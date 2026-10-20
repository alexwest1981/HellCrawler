"""Byns sex byggnader som lågpolymodeller (3D), ur spelets egna materialrutor.

    blender --background --python tools/gen_by_hus3d.py              # bygg + exportera GLB
    blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät

VARFÖR ETT EGET NAMN: `tools/gen_by_hus.py` klipper 2D-husen ur `byn.png` och körs av testsviten
(`tools/test.sh`, `game/tests/test_by_utklippt.gd`). Den här filen är 3D-modellerna och rör inte den.

FORMSPRÅKET: bara rätblock och prismor — inga rundningar, inga avfasningar. Samma platåiga voxel-/
pixelkänsla som resten av spelets grafik, och en polygontriangel per synlig yta i stället för en
slät yta. Allt byggs på ORIGO (markplan, mitt i byggnaden, +Z upp) så att GLB-filen kan instansieras
direkt i Godot; raden i .blend-filen läggs ut EFTER exporten.

TEXTURERNA är spelets egna (`game/assets/tiles/material/*.png`), aldrig något externt. UV-mappningen
är plan per yta (box-projektion) med `UPPREPNING` varv per meter, så en 256-pixlaruta täcker ~2,2 m
oavsett vilken byggnad den sitter på — samma tegelskala i hela byn.

`--kolla` läser tillbaka varje GLB i en tom scen: filen måste finnas, väga över 1 kB, importera, ha
mesh-ytor och ligga inom måtten i uppdraget (4-6 m bred, 3-4 m djup, 4-8 m hög). Utan det är
"exporterad" bara ett antagande.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROT = Path(__file__).resolve().parent.parent
RUTOR = ROT / "game" / "assets" / "tiles" / "material"
UT = ROT / "game" / "assets" / "by" / "models"
# .blend är en binär arbetsfil; repot har samma regel för assets/ (se .gitignore). Spelet läser GLB.
BLEND = ROT / "assets" / "by_hus_3d.blend"

## Texturvarv per meter. 0,45 ger en 256-pixlaruta på ~2,2 m: en stenrad blir ~25 cm hög, vilket är
## läsbart på 5-8 m hus på det avstånd byn ses (mätt mot byn_vc.png:s tegelskala).
UPPREPNING = 0.45

MAT: dict[str, bpy.types.Material] = {}
TEXTUR: dict[str, str] = {}  # materialnamn -> rutan i game/assets/tiles/material/
KOLL: bpy.types.Collection  # byggnadens samling, sätts av bygg_byggnad()


def material(namn, textur=None, färg=None, utstrålning=0.0, metall=0.0, grovhet=0.85):
    """Ett material per (namn). Textur slår färg; utstrålning gör fönster/lyktor varma i mörker."""
    if namn in MAT:
        return MAT[namn]
    m = bpy.data.materials.new(namn)
    # Nya material har noder som standard (2.8+); .get fångar ett material med tom nodträd
    bsdf = (m.node_tree.nodes.get("Principled BSDF")
            or m.node_tree.nodes.new("ShaderNodeBsdfPrincipled"))
    bsdf.inputs["Roughness"].default_value = grovhet
    bsdf.inputs["Metallic"].default_value = metall
    if textur:
        TEXTUR[namn] = textur  # README:n listar vilken ruta varje material kommer ur
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(RUTOR / (textur + ".png")))
        tex.interpolation = "Closest"  # pixelart: ingen utslätning mellan texlarna
        tex.extension = "REPEAT"
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if färg:
        f = tuple(c / 255.0 for c in färg) + (1.0,)
        bsdf.inputs["Base Color"].default_value = f
        if utstrålning:
            bsdf.inputs["Emission Color"].default_value = f
            bsdf.inputs["Emission Strength"].default_value = utstrålning
    MAT[namn] = m
    return m


def _yta(namn, hörn, ytor, mat, uvm=UPPREPNING):
    """Mesh ur hörn + ytor, med plan UV-projektion per yta (den axel ytan är minst vänd mot)."""
    me = bpy.data.meshes.new(namn)
    me.from_pydata([Vector(v) for v in hörn], [], ytor)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])  # vindningen får inte styra vilket håll ytan vetter
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        axel = max(range(3), key=lambda i: abs(p.normal[i]))
        u_axel, v_axel = ((1, 2), (0, 2), (0, 1))[axel]
        for li in p.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (v[u_axel] * uvm, v[v_axel] * uvm)
    me.materials.append(mat)
    ob = bpy.data.objects.new(namn, me)
    KOLL.objects.link(ob)
    return ob


def låda(namn, mitt, storlek, mat, matris=None):
    """Rätblock med undre mittpunkt i `mitt` = (x, y, z0). `matris` vrids kring hörnen (valv)."""
    cx, cy, z0 = mitt
    w, d, h = storlek
    x0, x1, y0, y1, z1 = cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2, z0 + h
    hörn = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
            (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    if matris:
        hörn = [matris @ Vector(v) for v in hörn]
    ytor = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
            (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return _yta(namn, hörn, ytor, mat)


def tak(namn, mitt, bredd, djup, z0, höjd, mat, nock="x"):
    """Sadeltak som prisma. nock="x" lägger nocklinjen i sidled (gavlar mot ±x),
    nock="y" lägger den i djupet (gavel mot gatan). `bredd`/`djup` är takets yttermått,
    alltså kroppens mått plus takutsprång."""
    cx, cy = mitt
    x0, x1, y0, y1 = cx - bredd / 2, cx + bredd / 2, cy - djup / 2, cy + djup / 2
    if nock == "x":  # nocklinjen i sidled, taken faller mot ±y, gavlar mot ±x
        hörn = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                (x0, cy, z0 + höjd), (x1, cy, z0 + höjd)]
        ytor = [(0, 1, 2, 3), (0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5)]
    else:  # nocklinjen i djupet, gavel mot gatan
        hörn = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                (cx, y0, z0 + höjd), (cx, y1, z0 + höjd)]
        ytor = [(0, 1, 2, 3), (1, 2, 5, 4), (3, 0, 4, 5), (0, 1, 4), (2, 3, 5)]
    return _yta(namn, hörn, ytor, mat)


def halvcirkel(namn, mitt, radie, z0, mat, djup=0.06, steg=7):
    """Halvcirkel som solfjäder i xz-planet, ytterkant nedåt z0 — valvets mörka insida."""
    cx, cy = mitt
    hörn = [(cx, cy - djup / 2, z0), (cx, cy + djup / 2, z0)]
    for i in range(steg + 1):
        a = math.pi * i / steg
        x, z = cx - radie * math.cos(a), z0 + radie * math.sin(a)
        hörn += [(x, cy - djup / 2, z), (x, cy + djup / 2, z)]
    ytor = []
    for i in range(steg):
        a, b = 2 + 2 * i, 4 + 2 * i
        ytor += [(0, a, b), (1, b + 1, a + 1), (a, a + 1, b + 1, b)]
    return _yta(namn, hörn, ytor, mat)


def ring(namn, mitt, inre, yttre, z0, mat, block=7, djup=0.22):
    """Valvband av kilstenar: `block` rätblock vridna kring valvets medelpunkt.

    Vinkeln v går från -x och uppåt, så tangenten i punkten är (sin v, cos v). Rotationen kring Y
    måste därför vara v - pi/2 (Matrix.Rotation vrider +x mot -z): med omvänt tecken blir varje
    kilsten vriden 90° fel och sticker ut som en spets ur väggen i stället för att ligga i bandet."""
    cx, cy = mitt
    for i in range(block):
        v = math.pi * (i + 0.5) / block
        r = (inre + yttre) / 2
        c = Vector((cx - r * math.cos(v), cy, z0 + r * math.sin(v)))
        kring = Matrix.Translation(c) @ Matrix.Rotation(v - math.pi / 2, 4, "Y") @ Matrix.Translation(-c)
        låda("%s_kil%d" % (namn, i),
             (c.x, cy, c.z - 0.17), (math.pi * inre / block * 1.1, djup, 0.34), mat, kring)


# --- materialnycklar -------------------------------------------------------------------------
def sten():        return material("sten", "ancient_stone")
def mur():         return material("mur", "fortified_stone_bricks")
def puts():        return material("puts", "chiseled_marble", grovhet=0.95)
def mörkt_virke(): return material("mörkt_virke", "wooden_palisades")
def ljust_virke(): return material("ljust_virke", "woven_bamboo", grovhet=0.9)
def skiffer():     return material("skiffer", "polished_obsidian_wall", grovhet=0.7)
def järn():        return material("järn", "corroded_metal", metall=0.7, grovhet=0.55)
def glöd():        return material("glöd", "magma_rock")
def murgröna():    return material("murgröna", "wall_with_ivy")
def fönster():     return material("fönster", färg=(246, 214, 120), utstrålning=2.2, grovhet=0.4)
def karm():        return material("fönsterkarm", färg=(26, 22, 32), grovhet=0.8)
def lykta():       return material("lykta", färg=(240, 156, 60), utstrålning=9.0, grovhet=0.3)
def tyg_rött():    return material("tyg_rött", färg=(168, 48, 40), grovhet=0.95)
def tyg_blått():   return material("tyg_blått", färg=(58, 96, 116), grovhet=0.95)
def glas_mörkt():  return material("glas_mörkt", färg=(12, 10, 16), grovhet=0.5)


def fönsterruta(namn, x, y, z, w, h, ram=None):
    """Ett lysande fönster 3 cm utanför väggen, med valfri träram och spröjs.

    Spröjsen (korset) sitter 2 cm framför glaset: utan den blir rutan en platt vit fyrkant i
    närbild i stället för ett fönster."""
    if ram:
        låda(namn + "_ram", (x, y, z), (w + 0.16, 0.06, h + 0.16), ram)
    låda(namn, (x, y - 0.02, z), (w, 0.06, h), fönster())
    låda(namn + "_spröjs", (x, y - 0.05, z), (0.09, 0.05, h), karm())
    låda(namn + "_tvär", (x, y - 0.05, z + h / 2 - 0.045), (w, 0.05, 0.09), karm())


def skylt(namn, x, y, z, bredd=0.9, höjd=0.7):
    """Hängande skylt: järnkonsol ut från väggen + en träskylt i två sidor om konsolen."""
    låda(namn + "_arm", (x, y - 0.35, z + höjd / 2 + 0.14), (0.07, 0.8, 0.07), järn())
    låda(namn + "_öglor", (x, y - 0.62, z + höjd / 2 + 0.02), (0.05, 0.05, 0.16), järn())
    låda(namn + "_bräda", (x, y - 0.62, z), (bredd, 0.08, höjd), ljust_virke())
    låda(namn + "_fält", (x, y - 0.65, z + 0.1), (bredd * 0.72, 0.03, höjd * 0.6),
         material("skyltfält", färg=(44, 38, 52)))


# --- 1. Thread of Destiny --------------------------------------------------------------------
def tradet():
    """Liten vävarstuga: stensockel, mörkt timmer, BRANT mörkt trätak, hängande tyg i fronten."""
    låda("tradet_sockel", (0, 0, 0), (4.4, 3.2, 0.9), sten())
    låda("tradet_stomme", (0, 0, 0.9), (4.2, 3.0, 2.4), mörkt_virke())
    tak("tradet_tak", (0, 0), 4.9, 3.7, 3.3, 1.9, mörkt_virke(), nock="y")  # 5,2 m nock, gavel mot gatan
    låda("tradet_dörr", (0.9, -1.55, 0.9), (1.0, 0.12, 2.1), ljust_virke())
    fönsterruta("tradet_fönster", 0.9, -1.55, 3.35, 0.7, 0.8, mörkt_virke())
    # hängande tyg: en bjälke ut från gaveln och tre paneler i olika tyg
    låda("tradet_bjälke", (-1.1, -1.85, 2.95), (2.6, 0.14, 0.14), mörkt_virke())
    for i, (tyg, x) in enumerate([(tyg_rött(), -2.0), (ljust_virke(), -1.35), (tyg_blått(), -0.7)]):
        låda("tradet_tyg%d" % i, (x, -1.95, 1.45), (0.55, 0.07, 1.45), tyg)
    skylt("tradet_skylt", 1.55, -1.6, 2.6, bredd=0.8, höjd=0.6)
    låda("tradet_tunna", (-1.6, -1.4, 0), (0.55, 0.55, 0.6), ljust_virke())


# --- 2. Blacksmith ---------------------------------------------------------------------------
def smed():
    """Smedja: mörk sten, öppen glödgad ässja i fronten, skorsten som sticker upp över nocken."""
    låda("smed_sockel", (0, 0, 0), (5.0, 3.6, 0.6), sten())
    låda("smed_stomme", (0, 0, 0.6), (4.8, 3.4, 2.6), mur())
    tak("smed_tak", (0, 0), 5.4, 4.1, 3.2, 1.7, mörkt_virke())  # nock i sidled, 4,9 m
    låda("smed_skorsten", (-1.5, 1.0, 3.4), (0.8, 0.8, 2.6), sten())
    låda("smed_skorstenshuv", (-1.5, 1.0, 6.0), (1.0, 1.0, 0.18), järn())
    # ässjan: en glödgad härd som skjuter ut ur fronten
    låda("smed_härd", (1.3, -1.9, 0), (1.9, 0.8, 1.3), mur())
    låda("smed_glöd", (1.3, -2.24, 0.25), (1.3, 0.12, 0.9), glöd())
    låda("smed_kåpa", (1.3, -1.95, 1.3), (2.2, 0.95, 0.3), järn())
    låda("smed_dörr", (-1.0, -1.75, 0.6), (1.1, 0.12, 2.1), ljust_virke())
    fönsterruta("smed_fönster", 1.2, -1.75, 2.2, 0.8, 0.7, mörkt_virke())
    låda("smed_ämnesbord", (-1.8, -2.1, 0), (1.2, 0.6, 0.75), ljust_virke())


# --- 3. The Tavern ---------------------------------------------------------------------------
def vardshus():
    """Två våningar: ljust puts med mörkt timmer, stora varma fönster, lyktor och skylt."""
    låda("vardshus_sockel", (0, 0, 0), (6.0, 4.0, 0.7), sten())
    låda("vardshus_botten", (0, 0, 0.7), (5.8, 3.8, 2.4), puts())
    låda("vardshus_bjälklag", (0, 0, 3.1), (6.3, 4.3, 0.25), mörkt_virke())  # kragbandet skjuter ut
    låda("vardshus_över", (0, 0, 3.35), (5.6, 3.6, 2.15), puts())
    tak("vardshus_tak", (0, 0), 6.6, 4.5, 5.5, 1.8, skiffer())  # 7,3 m nock
    # timmer: stolpar i fronten och två bjälkar per våning
    for x in (-2.75, -0.95, 0.95, 2.75):
        låda("vardshus_stolpe%s" % x, (x, -1.93, 0.7), (0.2, 0.1, 2.4), mörkt_virke())
        låda("vardshus_stolpe_u%s" % x, (x * 0.96, -1.83, 3.35), (0.2, 0.1, 2.15), mörkt_virke())
    for z, y, w in ((0.75, -1.93, 5.8), (2.95, -1.93, 5.8), (3.4, -1.83, 5.6), (5.35, -1.83, 5.6)):
        låda("vardshus_bjälke%.2f" % z, (0, y, z), (w, 0.1, 0.18), mörkt_virke())
    låda("vardshus_dörr", (0, -1.95, 0.7), (1.3, 0.12, 2.3), mörkt_virke())
    for x in (-1.85, 1.85):
        fönsterruta("vardshus_fönster%.1f" % x, x, -1.95, 1.35, 1.0, 1.1, mörkt_virke())
    for x in (-1.85, 0.0, 1.85):
        fönsterruta("vardshus_ufönster%.1f" % x, x, -1.85, 4.0, 0.8, 0.95, mörkt_virke())
    # lyktor på konsoler vid dörren
    for x in (-1.15, 1.15):
        låda("vardshus_lyktarm%.1f" % x, (x, -2.12, 2.75), (0.07, 0.35, 0.07), järn())
        låda("vardshus_lykta%.1f" % x, (x, -2.26, 2.25), (0.26, 0.26, 0.42), lykta())
        låda("vardshus_lykttak%.1f" % x, (x, -2.26, 2.67), (0.34, 0.34, 0.1), järn())
    skylt("vardshus_skylt", 2.35, -1.95, 4.55, bredd=1.2, höjd=0.85)


# --- 4. The Gate -----------------------------------------------------------------------------
def karta():
    """Porttorn i sten, 8 m till tinnarna, valvport i trä med järnband."""
    låda("karta_plint", (0, 0, 0), (5.2, 3.6, 0.9), sten())
    låda("karta_torn", (0, 0, 0.9), (4.6, 3.2, 6.2), mur())  # topp 7,1
    låda("karta_mellanbotten", (0, 0, 7.1), (5.0, 3.6, 0.3), sten())
    for i, (x, y) in enumerate([(-1.8, -1.3), (0, -1.3), (1.8, -1.3), (-1.8, 1.3), (0, 1.3), (1.8, 1.3)]):
        låda("karta_tinne_f%d" % i, (x, y, 7.4), (0.6, 0.5, 0.6), mur())
    for i, (y, s) in enumerate([(-0.7, -1), (0.7, 1)]):
        låda("karta_tinne_s%d" % i, (s * 2.0, y, 7.4), (0.5, 0.7, 0.6), mur())
    # valvporten: mörkt valv, träport under våningen, kilstenar runt, järnband över
    halvcirkel("karta_valv", (0, -1.62), 1.1, 2.9, glas_mörkt())
    låda("karta_port", (0, -1.6, 0.9), (2.2, 0.14, 2.0), mörkt_virke())
    for i, z in enumerate((1.25, 1.75, 2.25)):
        låda("karta_band%d" % i, (0, -1.66, z), (2.2, 0.06, 0.14), järn())
    ring("karta_kil", (0, -1.6), 1.15, 1.5, 2.9, sten(), block=7, djup=0.3)
    for x, y in ((-2.4, 0), (2.4, 0)):  # hörnkvadrar
        låda("karta_hörn%.0f" % x, (x, y, 0.9), (0.35, 3.3, 6.2), sten())
    for y in (-1.62, 1.62):
        låda("karta_glugg%.0f" % y, (0, y, 4.7), (0.3, 0.12, 1.2), glas_mörkt())


# --- 5. Jeweler ------------------------------------------------------------------------------
def juvelerare():
    """Litet stenhus med upplyst skyltfönster och metallram."""
    låda("juvelerare_sockel", (0, 0, 0), (4.2, 3.0, 0.5), sten())
    låda("juvelerare_stomme", (0, 0, 0.5), (4.0, 2.8, 2.6), sten())
    for x in (-1.9, 1.9):
        låda("juvelerare_kvader%.0f" % x, (x, -1.35, 0.5), (0.3, 0.3, 2.6), puts())
        låda("juvelerare_kvader_b%.0f" % x, (x, 1.35, 0.5), (0.3, 0.3, 2.6), puts())
    tak("juvelerare_tak", (0, 0), 4.6, 3.5, 3.1, 1.5, mörkt_virke(), nock="y")  # 4,6 m
    låda("juvelerare_skyltfönster_ram", (0.55, -1.42, 1.05), (2.0, 0.1, 1.5), järn())
    låda("juvelerare_skyltfönster", (0.55, -1.46, 1.15), (1.8, 0.08, 1.3), fönster())
    for x in (0.05, 1.05):  # spröjs: skyltfönstret är för brett för att läsas som en ruta utan
        låda("juvelerare_spröjs%.1f" % x, (x, -1.5, 1.15), (0.08, 0.05, 1.3), karm())
    låda("juvelerare_dörr", (-1.25, -1.42, 0.5), (0.95, 0.1, 2.05), mörkt_virke())
    låda("juvelerare_skylt", (0.55, -1.45, 2.75), (1.9, 0.1, 0.45), ljust_virke())
    låda("juvelerare_murgröna", (-1.4, -1.36, 0.5), (1.1, 0.12, 0.55), murgröna())


# --- 6. Exit ---------------------------------------------------------------------------------
def avsluta():
    """Liten grindstuga med skylt på grindstolpar framför."""
    låda("avsluta_sockel", (0, 0, 0), (4.2, 3.0, 0.4), sten())
    låda("avsluta_stomme", (0, 0, 0.4), (4.0, 2.8, 2.2), ljust_virke())
    tak("avsluta_tak", (0, 0), 4.6, 3.5, 2.6, 1.5, mörkt_virke(), nock="y")  # 4,1 m
    låda("avsluta_dörr", (0, -1.32, 0.4), (0.95, 0.1, 1.9), mörkt_virke())
    fönsterruta("avsluta_fönster", 1.1, -1.32, 1.2, 0.55, 0.65, mörkt_virke())
    for x in (-1.65, 1.65):
        låda("avsluta_stolpe%.0f" % x, (x, -2.1, 0), (0.2, 0.2, 2.3), mörkt_virke())
    låda("avsluta_skylt", (0, -2.1, 1.75), (3.0, 0.12, 0.85), ljust_virke())
    låda("avsluta_skyltfält", (0, -2.17, 1.9), (2.4, 0.04, 0.5),
         material("skyltfält", färg=(44, 38, 52)))


BYGGNADER = [
    ("tradet", tradet),
    ("smed", smed),
    ("vardshus", vardshus),
    ("karta", karta),
    ("juvelerare", juvelerare),
    ("avsluta", avsluta),
]


def tom_scen():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bygg_byggnad(id, fn):
    global KOLL
    KOLL = bpy.data.collections.new("by_" + id)
    bpy.context.scene.collection.children.link(KOLL)
    fn()
    return KOLL


def mät(koll):
    """(trianglar, total bbox, grundens bbox) för en samling.

    Grunden (sockeln/plinten) är byggnadens FOTPRINT; takutsprång, skyltar och lyktor sticker ut
    utanför den, så måtten i uppdraget (4-6 × 3-4 m) mäts mot grunden och höjden mot totalen."""
    trianglar = 0
    låg = Vector((1e9, 1e9, 1e9))
    hög = Vector((-1e9, -1e9, -1e9))
    bas = None
    for ob in koll.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        me.calc_loop_triangles()
        trianglar += len(me.loop_triangles)
        punkter = [ob.matrix_world @ v.co for v in me.vertices]
        if not punkter:
            continue
        b_låg = Vector((min(p[i] for p in punkter) for i in range(3)))
        b_hög = Vector((max(p[i] for p in punkter) for i in range(3)))
        låg = Vector((min(låg[i], b_låg[i]) for i in range(3)))
        hög = Vector((max(hög[i], b_hög[i]) for i in range(3)))
        if bas is None and ("sockel" in ob.name or "plint" in ob.name):
            bas = b_hög - b_låg
    total = hög - låg
    return trianglar, total, (bas if bas else total)


def bygg():
    tom_scen()
    UT.mkdir(parents=True, exist_ok=True)
    rader = []
    for i, (id, fn) in enumerate(BYGGNADER):
        koll = bygg_byggnad(id, fn)
        for ob in koll.objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = koll.objects[0]
        bpy.ops.export_scene.gltf(filepath=str(UT / (id + ".glb")), export_format="GLB",
                                  use_selection=True)
        # texturerna packas i .blend-filen: annars pekar den på PNG-filer som kan flyttas
        for ob in koll.objects:
            ob.select_set(False)
        trianglar, total, bas = mät(koll)
        rader.append((id, trianglar, total, bas, sorted({m.name for ob in koll.objects
                                                         for m in ob.data.materials if m})))
        print("  %-11s %4d tri  grund %.1f x %.1f m  högst %.1f m"
              % (id, trianglar, bas.x, bas.y, total.z))
        # raden i .blend-filen: 8 m mellan husen, byggt på origo under exporten ovan
        for ob in koll.objects:
            ob.location.x = (i - (len(BYGGNADER) - 1) / 2) * 8.0
    for im in bpy.data.images:
        if not im.packed_file:
            im.pack()
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    skriv_readme(rader)
    print("skrev %d GLB till %s och %s" % (len(rader), UT.relative_to(ROT), BLEND.relative_to(ROT)))


def skriv_readme(rader):
    """README:n skrivs av bygget, så mått och polygontal inte kan glida ifrån modellerna."""
    text = ["# Byns byggnader i 3D", "",
            "Lågpolymodeller, en GLB per byggnad. Byggs om med", "",
            "```", "blender --background --python tools/gen_by_hus3d.py",
            "blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät",
            "```", "",
            "Origo ligger på markplanet mitt i varje byggnad, +Z upp i Blender (GLB-exporten gör Y-up).",
            "Enheter är meter. Grunden (sockeln) är fotavtrycket; takutsprång, skyltar och lyktor sticker",
            "ut utanför den. Samlingsfilen med alla sex på rad är `assets/by_hus_3d.blend`",
            "(utanför git, samma regel som repots övriga .blend-filer).", "",
            "| Byggnad | Grund b × d (m) | Högsta punkt (m) | Trianglar | Texturer |",
            "|---|---|---|---|---|"]
    for id, trianglar, total, bas, matar in rader:
        texturer = ", ".join(m for m in matar if m not in ("glöd", "fönster", "lykta",
                                                          "tyg_rött", "tyg_blått",
                                                          "glas_mörkt", "skyltfält"))
        text.append("| `%s.glb` | %.1f × %.1f | %.1f | %d | %s |"
                    % (id, bas.x, bas.y, total.z, trianglar, texturer))
    text += ["", "Färgade material utan textur (samma palett som spelet): glöd, fönster, lykta,",
             "tyg_rött, tyg_blått, glas_mörkt, skyltfält, fönsterkarm.", "",
             "Texturerna är spelets egna rutor i `game/assets/tiles/material/`, ett varv per ~2,2 m", "",
             "| Material i GLB | Ruta |", "|---|---|"]
    for namn in sorted(TEXTUR):
        text.append("| `%s` | `%s.png` |" % (namn, TEXTUR[namn]))
    text += ["", "Referensbilderna (`by2d/byn_vc.png`, `vc_lan/town/Town_BG.png`) är bara tittade på —",
             "ingen av dem är använd som textur.", ""]
    (UT / "README.md").write_text("\n".join(text), encoding="utf-8")


def kolla():
    """Importera varje GLB tillbaka i en tom scen och mät. Exit 1 vid minsta fel."""
    fel = 0
    for id, _fn in BYGGNADER:
        p = UT / (id + ".glb")
        if not p.exists():
            print("FEL %s: filen finns inte" % id)
            fel += 1
            continue
        kb = p.stat().st_size / 1024
        tom_scen()
        bpy.ops.import_scene.gltf(filepath=str(p))
        trianglar, total, bas = mät(bpy.context.scene.collection)
        # Måtten ur uppdraget: grund 4-6 x 3-4 m, högst 8 m och lägst 4 m. Totalen får sticka ut
        # högst 1,5 m utanför grunden (takutsprång + skylt) — mer än så är en felplacerad detalj.
        ok = (kb > 1 and trianglar > 0
              and 3.95 <= bas.x <= 6.05 and 2.95 <= bas.y <= 4.05
              and 3.95 <= total.z <= 8.05
              and total.x <= bas.x + 1.5 and total.y <= bas.y + 1.5)
        print("%s %-11s %6.0f kB  %4d tri  grund %.1f x %.1f  totalt %.1f x %.1f x %.1f m  %d material"
              % ("ok  " if ok else "FEL ", id, kb, trianglar, bas.x, bas.y,
                 total.x, total.y, total.z, len(bpy.data.materials)))
        fel += 0 if ok else 1
    print("--- %s" % ("alla sex laddar" if not fel else "%d fel" % fel))
    return fel


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--kolla" in argv:
        sys.exit(1 if kolla() else 0)
    bygg()


if __name__ == "__main__":
    main()
