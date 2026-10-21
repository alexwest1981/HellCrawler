"""Byns sex byggnader + brunnen i 3D, byggda efter `game/assets/by2d/byn_referens.png`.

    blender --background --python tools/gen_by_hus3d.py              # bygg + exportera GLB + rendera
    blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät

VARFÖR ETT EGET NAMN: `tools/gen_by_hus.py` klipper 2D-husen ur `byn.png` och körs av testsviten
(`tools/test.sh`, `game/tests/test_by_utklippt.gd`). Den här filen är 3D-modellerna och rör inte den.

SKALA: husen är byggda i bynivå — 9-14 m breda, 6-9 m djupa och 10-18 m höga (porttornet högst),
alltså tre våningar och rejält tak. Brunnen är 2,4 m i diameter och 1,1 m hög.

FORMSPRÅKET: kantigt där bilden är kantig och runt där bilden är rund. Skifferpannor, stenblock,
plankor och bjälkar är rätblock och plan; tunnor, brunnsringen, vindspelstrumman och nockpannorna
byggs av mångsidiga prismor så de blir runda. Beståndsdelarna är referensbildens: öppet klädstånd
med kläder på lina, smedja i gråsten med rundbågig glödande ässja och hög skorstensstock, värdshus
i två våningar med korsvirke, utkragning och takkupa, krenelerat porttorn med valvport, litet
juvelerarhus med skyltfönster — och en trävinschbrunn.

ÖPPNINGARNA ÄR RIKTIGA HÅL: väggarna byggs av block som klipps runt fönster- och dörröppningarna
(`skär`), karmen fodrar öppningen genom hela väggtjockleken och glaset sitter på halva djupet.
Tidigare låg fönstren utanpå väggens yttersta skikt; det är samma fel som gjorde att gaveln blev
en trappa med springor — båda är borta.

ORIGO ligger på markplan, mitt i byggnaden, +Z upp. FASADEN LIGGER ÅT -Y i Blender, vilket blir
+Z i GLB:n (Blender -Y -> glTF +Z vid exporten); spelet roterar huset så fasaden pekar mot torget
och den konventionen är oförändrad — rör den inte.

TEXTURER: spelets egna 256-rutor i `game/assets/tiles/material/`, sexton rutor utklippta ur de
nedladdade mapseten (`tools/klipp_texturer.py` → `game/assets/by/texturer/`): linneduk, läder,
hyvlat virke, smidesjärn, mässing och gråsten, alla med BaseColor + Normal + ORM där kartorna
finns, och platta palettfärger för småsnickerier (takpannor, bleck, gångjärn, glöd) — textur på en
30 cm panna blir bara grus. Texeldensiteten är 512 px/m för de utklippta ytorna. Ingen preview-bild
eller skärmdump används som textur.

UV: varje mesh har två kartor. `UVMap` är en unik, packad 0-1-karta med samma texteldensitet i hela
byggnaden (den man målar en egen textur på), `Upprepning` är den löpande projektionen som materialen
använder (512 px/m). Virke projiceras med u längs fibern, så ådringen följer stocken även när den
ligger ner.

GEOMETRIN samlas per material i en `Bygge` och blir EN mesh per material — inte en nod per spik.
Det håller GLB:n på ett tiotal noder per hus i stället för tusentals och gör att Godot slipper
tusentals draw calls per hus i byn. Sockeln ligger dock i sin egen mesh (`<id>_sockel`) eftersom
`--kolla` mäter fotavtrycket på den.

`--kolla` läser tillbaka varje GLB i en tom scen: filen måste finnas, väga under 20 MB, importera,
ha mesh-ytor, två UV-kartor med den unika kartan inom 0-1, ligga på 20 000-250 000 trianglar och
inom måtten (grund 9-14 m bred, 6-9 m djup, 10-18 m hög); totalen får sticka ut högst 5 m utanför
grunden (takutsprång, skyltar, trappor, vedtravar). Utan det är "exporterad" bara ett antagande.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROT = Path(__file__).resolve().parent.parent
RUTOR = ROT / "game" / "assets" / "tiles" / "material"
UT = ROT / "game" / "assets" / "by" / "models"
BILD = ROT / "game" / "assets" / "by" / "texturer"
GRANSKA = UT / "granskning"
# .blend är en binär arbetsfil; repot har samma regel för assets/ (se .gitignore). Spelet läser GLB.
BLEND = ROT / "assets" / "by_hus_3d.blend"

## Texturvarv per meter. 0,45 ger en 256-pixlaruta på ~2,2 m: en stenrad blir ~25 cm hög, vilket är
## läsbart på 10-18 m hus på det avstånd byn ses (mätt mot byn_vc.png:s tegelskala).
UPPREPNING = 0.45

MAT: dict[str, bpy.types.Material] = {}
TEXTUR: dict[str, str] = {}  # materialnamn -> bildfil
MAT_SKALA: dict[str, float] = {}  # materialnamn -> UV-varv per meter (texeldensitet)


def material(namn, textur=None, färg=None, utstrålning=0.0, metall=0.0, grovhet=0.85,
             normal=None, orm=None, täthet=None, katalog="ruta", tint=None, alfa=1.0):
    """Ett material per (namn). Textur slår färg; utstrålning gör fönster/lyktor varma i mörker.

    `katalog="ruta"` är spelets egna 256-rutor i game/assets/tiles/material/, `katalog="bild"` är
    de utklippta ytorna i game/assets/by/texturer/ (se tools/klipp_texturer.py). `tint` multipliceras
    på basfärgen, så en enda linnetextur ger alla fem tygfärgerna med väv kvar.

    Texeldensiteten räknas ur bildens bredd: 512 px/m, alltså varv/m = 512 / bredd. Då sitter
    samma detaljskala på en bjälke som på en disk, oavsett vilken ruta materialet råkar använda.

    `normal` + `orm` (R=AO, G=grovhet, B=metall) kopplas in som riktiga kartor — ORM:en styr
    Roughness/Metallic via Separate Color och AO via nodgruppen glTF Material Output, så allt tre
    följer med i GLB:n.
    """
    if namn in MAT:
        return MAT[namn]
    m = bpy.data.materials.new(namn)
    nt = m.node_tree
    # Nya material har noder som standard (2.8+); .get fångar ett material med tom nodträd
    bsdf = nt.nodes.get("Principled BSDF") or nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = grovhet
    bsdf.inputs["Metallic"].default_value = metall
    beskrivning = []
    if textur:
        karta = RUTOR if katalog == "ruta" else BILD
        fil = karta / (textur + (".png" if katalog == "ruta" else ".png"))
        if katalog == "bild" and not fil.is_file():
            fil = karta / (textur + ".jpg")
        if not fil.is_file():
            raise SystemExit("Texturen saknas: %s (kör tools/klipp_texturer.py)" % fil)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(fil))
        tex.interpolation = "Closest" if katalog == "ruta" else "Linear"
        tex.extension = "REPEAT"
        MAT_SKALA[namn] = täthet if täthet is not None else (
            UPPREPNING if katalog == "ruta" else 512.0 / tex.image.size[0])
        beskrivning.append(fil.name)
        # den löpande UV-kartan (TEXCOORD_1) bär alla yttexturer: samma meterskala i hela byn
        uvnod = nt.nodes.new("ShaderNodeUVMap")
        uvnod.uv_map = "Upprepning"
        nt.links.new(uvnod.outputs["UV"], tex.inputs["Vector"])
        bas = tex.outputs["Color"]
        if tint:
            bland = nt.nodes.new("ShaderNodeMix")
            bland.data_type = "RGBA"
            bland.blend_type = "MULTIPLY"
            bland.inputs[0].default_value = 1.0          # Factor
            nt.links.new(bas, bland.inputs[6])            # A (färg)
            bland.inputs[7].default_value = tuple(c / 255.0 for c in tint) + (1.0,)  # B (färg)
            bas = bland.outputs[2]                        # Color
        nt.links.new(bas, bsdf.inputs["Base Color"])
        if normal:
            ntex = nt.nodes.new("ShaderNodeTexImage")
            nfil = BILD / (normal + ".png")
            if not nfil.is_file():
                nfil = BILD / (normal + ".jpg")
            ntex.image = bpy.data.images.load(str(nfil))
            ntex.image.colorspace_settings.name = "Non-Color"
            ntex.extension = "REPEAT"
            nt.links.new(uvnod.outputs["UV"], ntex.inputs["Vector"])
            nmap = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
            nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
            beskrivning.append(nfil.name)
        if orm:
            otex = nt.nodes.new("ShaderNodeTexImage")
            ofil = BILD / (orm + ".png")
            otex.image = bpy.data.images.load(str(ofil))
            otex.image.colorspace_settings.name = "Non-Color"
            otex.extension = "REPEAT"
            nt.links.new(uvnod.outputs["UV"], otex.inputs["Vector"])
            sep = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(otex.outputs["Color"], sep.inputs["Color"])
            nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
            nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
            # glTF-exportören läser AO ur en nodgrupp med exakt det här namnet
            grp = bpy.data.node_groups.get("glTF Material Output")
            if grp is None:
                grp = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
                grp.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
            gnod = nt.nodes.new("ShaderNodeGroup")
            gnod.node_tree = grp
            nt.links.new(sep.outputs["Red"], gnod.inputs["Occlusion"])
            beskrivning.append(ofil.name)
        TEXTUR[namn] = " + ".join(beskrivning)
    if utstrålning and färg is None:
        # texturerade glödmaterial (magma) får sin emission ur texturen — annars slocknar de
        varm = (1.0, 0.42, 0.12, 1.0)
        bsdf.inputs["Emission Color"].default_value = varm
        bsdf.inputs["Emission Strength"].default_value = utstrålning
        if textur:
            nt.links.new(bas, bsdf.inputs["Emission Color"])
    if alfa < 1.0:
        bsdf.inputs["Alpha"].default_value = alfa
        try:
            m.blend_method = "BLEND"                  # Blender <= 4.x
            m.surface_render_method = "BLENDED"       # Blender 5.x
        except (AttributeError, TypeError):
            pass
    if färg:
        f = tuple(c / 255.0 for c in färg) + (1.0,)
        if textur is None:
            bsdf.inputs["Base Color"].default_value = f
        if utstrålning:
            bsdf.inputs["Emission Color"].default_value = f
            bsdf.inputs["Emission Strength"].default_value = utstrålning
    MAT[namn] = m
    return m


# --- materialnycklar -------------------------------------------------------------------------
def sten():         return material("sten", "sten_grå", katalog="bild")
def mur():          return material("mur", "sten_grå", katalog="bild", grovhet=0.9)
def mur_grå():      return material("mur_grå", "sten_grå_neutral", katalog="bild", grovhet=0.9)
def puts():         return material("puts", "chiseled_marble", grovhet=0.95)
def mörkt_virke():  return material("mörkt_virke", "bark_normal", katalog="bild",
                                    normal="bark_normal_normal")
def ljust_virke():  return material("ljust_virke", "trä_ljust", katalog="bild",
                                    normal="trä_ljust_normal", orm="trä_ljust_orm")
def läder():        return material("läder", "läder", katalog="bild", normal="läder_normal",
                                    orm="läder_orm", tint=(206, 152, 104))
def skiffer():      return material("skiffer", "polished_obsidian_wall", grovhet=0.7)
def järn():         return material("järn", "järn", katalog="bild", normal="järn_normal",
                                    orm="järn_orm")
def glöd():         return material("glöd", "magma_rock", utstrålning=2.0)


def glöd_stark():   return material("glöd_stark", färg=(255, 132, 34), utstrålning=2.2, grovhet=0.6)
def låga():         return material("låga", färg=(255, 150, 52), utstrålning=2.6, grovhet=0.5)
def fönster():      return material("fönster", färg=(255, 186, 96), utstrålning=1.5, grovhet=0.4)
def karm():         return material("fönsterkarm", färg=(26, 22, 32), grovhet=0.8)
def lyktglas():     return material("lyktglas", färg=(246, 158, 60), utstrålning=2.2, grovhet=0.3)
# tygerna delar en neutral linnetextur (bas+normal+ORM) och tintas till byns fem plaggfärger
def _tyg(namn, färg):
    return material(namn, "tyg_väv", katalog="bild", normal="tyg_väv_normal", orm="tyg_väv_orm",
                    färg=färg, tint=färg)
def tyg_rött():     return _tyg("tyg_rött", (168, 48, 40))
def tyg_blått():    return _tyg("tyg_blått", (58, 96, 116))
def tyg_grönt():    return _tyg("tyg_grönt", (60, 112, 74))
def tyg_gult():     return _tyg("tyg_gult", (198, 168, 66))
def tyg_turkost():  return _tyg("tyg_turkost", (58, 148, 148))
def glas_mörkt():   return material("glas_mörkt", färg=(12, 10, 16), grovhet=0.5)
def skyltfält():    return material("skyltfält", färg=(44, 38, 52), grovhet=0.9)
# tak: skiffergrå pannor i två toner (förbandet syns som ett schack), spån i två trätoner
def panna_mörk():   return material("takpanna_mörk", färg=(34, 40, 48), grovhet=0.72)
def panna_ljus():   return material("takpanna_ljus", färg=(46, 54, 64), grovhet=0.72)
def spån_mörk():    return material("spån_mörk", färg=(64, 48, 36), grovhet=0.95)
def spån_ljus():    return material("spån_ljus", färg=(84, 64, 46), grovhet=0.95)
def tegel():        return material("tegel", färg=(112, 66, 50), grovhet=0.9)
def kol():          return material("kol", färg=(24, 22, 26), grovhet=0.95)
def sot():          return material("sot", färg=(19, 17, 18), grovhet=0.95)
def aska():         return material("aska", färg=(104, 99, 94), grovhet=1.0)
def glödhet():      return material("glödhet", färg=(255, 168, 58), utstrålning=2.6, grovhet=0.5)


def rök(alfa):
    """Halvgenomskinlig rökpuff; fyra styrkor så plymen tunnas ut uppåt."""
    steg = (0.30, 0.22, 0.15, 0.09)
    i = min(range(4), key=lambda k: abs(steg[k] - alfa))
    return material("rök_%d" % i, färg=(146, 144, 150), grovhet=1.0, alfa=steg[i])
def mässing():      return material("mässing", "mässing", katalog="bild", normal="mässing_normal",
                                    orm="mässing_orm")
def vatten():       return material("vatten", färg=(30, 52, 64), grovhet=0.25)
def lera():         return material("lera", färg=(120, 88, 66), grovhet=0.95)
def rep():          return material("rep", färg=(150, 126, 88), grovhet=0.95)
def halm():         return material("halm", färg=(148, 126, 78), grovhet=0.95)


# --- rektangelhjälp: klipp bort öppningar ------------------------------------------------------
def _överlappar(a, b) -> bool:
    return (a[0] < b[2] - 1e-6 and a[2] > b[0] + 1e-6
            and a[1] < b[3] - 1e-6 and a[3] > b[1] + 1e-6)


def skär(r, hål):
    """Rektangeln `r` delas i bitar utanför alla hål (upp till fyra per hål).

    Det är den här som gör att fönster och dörrar blir genomgående hål i väggen i stället för
    dekaler på yttersta skiktet.
    """
    bitar = [r]
    for h in hål:
        nya = []
        for q in bitar:
            x0, z0, x1, z1 = q
            hx0, hz0, hx1, hz1 = h
            if not _överlappar(q, h):
                nya.append(q)
                continue
            if hz0 > z0 + 1e-6:
                nya.append((x0, z0, x1, min(hz0, z1)))
            if hz1 < z1 - 1e-6:
                nya.append((x0, max(hz1, z0), x1, z1))
            mz0, mz1 = max(z0, hz0), min(z1, hz1)
            if hx0 > x0 + 1e-6:
                nya.append((x0, mz0, min(hx0, x1), mz1))
            if hx1 < x1 - 1e-6:
                nya.append((max(hx1, x0), mz0, x1, mz1))
        bitar = nya
    return [q for q in bitar if q[2] - q[0] > 0.02 and q[3] - q[1] > 0.02]


# --- bygget ----------------------------------------------------------------------------------
class Bygge:
    """Geometri insamlad per material; blir en mesh per material vid `mesha`.

    Varje geometri-anrop taggas med `b.delnamn` (vägg_fram, takpannor, dörr ...) och `b.fiber`
    (virke: x/y/z längs stocken). Taggarna styr både UV-kartorna och listan i README:n.
    """

    def __init__(self):
        self.delar: dict = {}   # materialnamn -> (hörn, ytor)
        self.sockel: dict = {}  # sockeln får egen mesh så fotavtrycket kan mätas
        self.etikett: dict = {"sockel": {}, "delar": {}}  # mål -> material -> [(del, fiber, från, till)]
        self.fot = (4.0, 3.0)   # (bredd, djup) sätts av plint()/brunn()
        self.delnamn = "stomme"     # namnet på byggdelen som följande geometri hör till
        self.uv_stat = []           # (del, material, uv-yta m²) — README:ns UV-tabell
        self.uv_täthet = 0.0
        self.fiber = None       # "x"/"y"/"z" när materialet har en fiberriktning (virke)

    def _lägg(self, mål, nyckel, mat, hörn, ytor):
        v, f = mål.setdefault(mat.name, ([], []))
        n = len(v)
        v.extend(Vector(p) for p in hörn)
        f.extend(tuple(n + i for i in y) for y in ytor)
        self.etikett[nyckel].setdefault(mat.name, []).append(
            (self.delnamn, self.fiber, len(f) - len(ytor), len(f)))

    def skala(self, sx, sy, sz):
        """Skalar all redan byggd geometri. Används för att göra porttornet till en PORT: bredare,
        lägre och grundare — proportionerna sitter i geometrin, inte i en efterhandsmatris i spelet."""
        for koll in (self.sockel, self.delar):
            for _mn, (v, _f) in koll.items():
                for p in v:
                    p.x *= sx
                    p.y *= sy
                    p.z *= sz

    def låda(self, mitt, storlek, mat, matris=None, mål=None):
        """Rätblock med undre mittpunkt i `mitt` = (x, y, z0). `matris` vrids kring hörnen."""
        cx, cy, z0 = mitt
        w, d, h = storlek
        if w <= 1e-4 or d <= 1e-4 or h <= 1e-4:
            return
        x0, x1, y0, y1, z1 = cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2, z0 + h
        hörn = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        if matris is not None:
            hörn = [matris @ Vector(p) for p in hörn]
        # vindningen är rättvänd utåt (botten 0-3-2-1, topp 4-5-6-7 osv): ingen normal-omräkning
        self._lägg(mål if mål is not None else self.delar,
                   "sockel" if mål is not None else "delar", mat, hörn,
                   [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                    (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)])

    def skiva(self, mat, punkter, ut, mål=None):
        """Ett plant fyrhörn, vänt så normalen pekar åt `ut`.

        Takpannor och bleck är enkelsidiga plan; med fel vindning cullar Godot bort dem och taket
        blir ett hål. Därför vänds de mot en känd utåtriktning i stället för att litas på ordningen.
        """
        p = [Vector(q) for q in punkter]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        if n.length < 1e-9:
            return
        if n.dot(Vector(ut)) < 0:
            p = p[::-1]
        self._lägg(mål if mål is not None else self.delar,
                   "sockel" if mål is not None else "delar", mat, p, [(0, 1, 2, 3)])

    def tri(self, mat, punkter, ut, mål=None):
        """En triangel, vänt så normalen pekar åt `ut` (samma skäl som `skiva`)."""
        p = [Vector(q) for q in punkter]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        if n.length < 1e-9:
            return
        if n.dot(Vector(ut)) < 0:
            p = p[::-1]
        self._lägg(mål if mål is not None else self.delar,
                   "sockel" if mål is not None else "delar", mat, p, [(0, 1, 2)])

    def platta(self, mat, punkter, ut, tjock=0.08):
        """Sluten skiva (12 tri) ur fyra punkter på ytterytan; `ut` är ytterytans riktning.

        Används för snedsträvor, kilstenar, takfötter och sparrar — allt som lutar och därför inte
        kan vara en axelriktad låda.
        """
        p = [Vector(q) for q in punkter]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        if n.length < 1e-9:
            return
        n.normalize()
        if n.dot(Vector(ut)) < 0:
            p = p[::-1]
            n = -n
        q = [x - n * tjock for x in p]
        mitt = sum(p + q, Vector()) / 8
        self.skiva(mat, p, n)
        self.skiva(mat, q, -n)
        for i in range(4):
            a, b, c, d = p[i], p[(i + 1) % 4], q[(i + 1) % 4], q[i]
            self.skiva(mat, [a, b, c, d], (a + b + c + d) / 4 - mitt)

    def prisma(self, mat, mitt, r, h, n=12, axel="z", lock=True):
        """N-sidigt prisma — rundning i den kantiga stilen (brunnstrumma, stockar, hink)."""
        mitt = Vector(mitt)
        cx, cy, cz = mitt
        ax = {"z": Vector((0, 0, 1)), "y": Vector((0, 1, 0)), "x": Vector((1, 0, 0))}[axel]
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            if axel == "z":
                ring.append(Vector((cx + r * math.cos(a), cy + r * math.sin(a), cz)))
            elif axel == "y":
                ring.append(Vector((cx + r * math.cos(a), cy, cz + r * math.sin(a))))
            else:
                ring.append(Vector((cx, cy + r * math.cos(a), cz + r * math.sin(a))))
        topp = [p + ax * h for p in ring]
        for i in range(n):
            j = (i + 1) % n
            q = [ring[i], ring[j], topp[j], topp[i]]
            mitt_q = sum(q, Vector()) / 4
            self.skiva(mat, q, mitt_q - (mitt + ax * (mitt_q - mitt).dot(ax)))
        if lock:
            for i in range(1, n - 1):
                self.tri(mat, [ring[0], ring[i + 1], ring[i]], -ax)
                self.tri(mat, [topp[0], topp[i], topp[i + 1]], ax)

    def plint(self, w, d, h=0.7, block=0.8, kurser=2, mat=None, kärna=None):
        """Stensockel med synliga skift. Sätter fotavtrycket (uppdragets grundmått)."""
        self.fot = (w, d)
        mat = mat or sten()
        self.låda((0, 0, 0), (w, d, h), kärna or mur(), mål=self.sockel)
        for k in range(kurser):
            self.skift(w, d, h * k / kurser, h / kurser, mat, block, mål=self.sockel,
                       förskjut=(block / 2 if k % 2 else 0.0))

    def skift(self, w, d, z, h, mat, block=0.8, tjock=0.14, mål=None, förskjut=0.0):
        """Ett varv mursten runt en w x d-kropp.

        Varannat varv förskjuts ett halvt block, och ändstenarna klipps mot hörnet — annars
        sticker halva hörnstenen ut och fotavtrycket blir större än sockeln det mäts mot.
        """
        hh = h * 0.9
        for fast in (-d / 2, d / 2):
            pos = -w / 2 - förskjut
            while pos < w / 2 - 0.02:
                a, b = max(pos, -w / 2), min(pos + block, w / 2)
                if b - a > 0.04:
                    self.låda(((a + b) / 2, fast, z), (b - a - 0.02, tjock, hh), mat, mål=mål)
                pos += block
        for fast in (-w / 2, w / 2):
            pos = -d / 2 - förskjut
            while pos < d / 2 - 0.02:
                a, b = max(pos, -d / 2), min(pos + block, d / 2)
                if b - a > 0.04:
                    self.låda((fast, (a + b) / 2, z), (tjock, b - a - 0.02, hh), mat, mål=mål)
                pos += block

    # --- UV ---------------------------------------------------------------------------------
    @staticmethod
    def _normal(v, yta):
        p = [v[i] for i in yta[:3]]
        if len(p) < 3:
            return Vector((0, 0, 1))
        return (p[1] - p[0]).cross(p[2] - p[0])

    @staticmethod
    def _rep_axlar(normal, fiber):
        """Vilka två koordinater den upprepade kartan ska använda på den här ytan.

        Virke har en fiberriktning: u läggs längs stockens längd, så ådringen följer stocken även
        när den ligger ner (det var felet förut — ådringen stod vertikalt på liggande stockar).
        """
        axel = max(range(3), key=lambda k: abs(normal[k]))
        if fiber is None:
            a, b = ((1, 2), (0, 2), (0, 1))[axel]
            return a, b
        fi = "xyz".index(fiber)
        if axel == fi:
            a, b = [k for k in range(3) if k != fi]
        else:
            a = fi
            b = [k for k in (0, 1, 2) if k != fi and k != axel][0]
        return a, b

    def _uv_banor(self, v, f, etiketter):
        """Dela in ytorna i (del, projektionsriktning) och räkna ut en bana per del.

        Varje bana projiceras plant i sin egen riktning (meter), får en egen plats i ett hyllpaket
        och samma skala som alla andra banor — det är så texteldensiteten blir jämn. Ingen yta
        projiceras i 0-1 för sig: banorna packas ihop först, efteråt.
        """
        del_av_yta = ["stomme"] * len(f)
        fiber_av_yta = [None] * len(f)
        for (delnamn, fiber, a, b) in etiketter:
            for i in range(a, min(b, len(f))):
                del_av_yta[i] = delnamn
                fiber_av_yta[i] = fiber
        poster = {}
        for i, yta in enumerate(f):
            normal = self._normal(v, yta)
            axel = max(range(3), key=lambda k: abs(normal[k]))
            nyckel = (del_av_yta[i], axel, 1 if normal[axel] >= 0 else -1)
            poster.setdefault(nyckel, []).append(i)
        banor = []
        for (delnamn, axel, _), ytor in poster.items():
            a, b = ((1, 2), (0, 2), (0, 1))[axel]
            punkter = [v[vi] for i in ytor for vi in f[i]]
            umin, umax = min(q[a] for q in punkter), max(q[a] for q in punkter)
            vmin, vmax = min(q[b] for q in punkter), max(q[b] for q in punkter)
            banor.append({"del": delnamn, "a": a, "b": b, "umin": umin, "vmin": vmin,
                          "w": umax - umin + 0.03, "h": vmax - vmin + 0.03,
                          "ytor": ytor, "ou": 0.0, "ov": 0.0})
        area = sum(q["w"] * q["h"] for q in banor)
        bredd = math.sqrt(max(area, 1e-6) / 0.7)
        for _ in range(6):  # hyllpaketet växer på höjden: bredda tills det ryms i en kvadrat
            y, x, hylle = 0.0, 0.0, 0.0
            for q in sorted(banor, key=lambda z: -z["h"]):
                if x + q["w"] > bredd and x > 0:
                    x, y, hylle = 0.0, y + hylle, 0.0
                q["ou"], q["ov"] = x, y
                x += q["w"]
                hylle = max(hylle, q["h"])
            höjd = y + hylle
            if höjd <= bredd * 1.02:
                break
            bredd = höjd
        per_yta = [None] * len(f)
        for q in banor:
            for i in q["ytor"]:
                per_yta[i] = (q["a"], q["b"], q["umin"], q["vmin"], q["ou"], q["ov"])
        return {"banor": banor, "per_yta": per_yta, "area": area,
                "sida": max(bredd, höjd), "fiber": fiber_av_yta}

    def mesha(self, koll, namn):
        """Skriv ut geometrin som en mesh per material i samlingen `koll`.

        Varje mesh får två UV-kartor:
          UVMap      – unik, packad 0-1 utan överlapp, samma texteldensitet i hela byggnaden.
                       Det är den man byter till en egen (målad) textur på.
          Upprepning – löpande projektion per byggdel, den spelets sömlösa rutor sitter på
                       (0,45 varv/m = en 256-ruta per ~2,2 m). Materialen pekar på den via en
                       UV Map-nod, så glTF exporterar den som TEXCOORD_1.
        """
        grupper = [("sockel", mn, v, f, self.etikett["sockel"].get(mn, []))
                   for mn, (v, f) in self.sockel.items()]
        grupper += [("delar", mn, v, f, self.etikett["delar"].get(mn, []))
                    for mn, (v, f) in self.delar.items()]
        layouter = [self._uv_banor(v, f, et) for (_, _, v, f, et) in grupper]
        # en densitet för hela byggnaden: den största materialgruppen sätter taket
        d = 0.94 / max(l["sida"] for l in layouter)
        obs = []
        for (nyckel, mn, v, f, _), lay in zip(grupper, layouter):
            me = bpy.data.meshes.new("%s_%s" % (namn, mn))
            me.from_pydata(v, [], f)
            me.update()
            skala = MAT_SKALA.get(mn, UPPREPNING)
            uv_unik = me.uv_layers.new(name="UVMap")
            uv_rep = me.uv_layers.new(name="Upprepning")
            for fi, p in enumerate(me.polygons):
                a, b, umin, vmin, ou, ov = lay["per_yta"][fi]
                ra, rb = self._rep_axlar(p.normal, lay["fiber"][fi])
                for li in p.loop_indices:
                    co = me.vertices[me.loops[li].vertex_index].co
                    uv_unik.data[li].uv = ((ou + co[a] - umin) * d, (ov + co[b] - vmin) * d)
                    uv_rep.data[li].uv = (co[ra] * skala, co[rb] * skala)
            me.materials.append(MAT[mn])
            if nyckel == "sockel" and mn == list(self.sockel)[0]:
                objnamn = "%s_sockel" % namn
            elif nyckel == "sockel":
                objnamn = "%s_fot_%s" % (namn, mn)
            else:
                objnamn = "%s_%s" % (namn, mn)
            ob = bpy.data.objects.new(objnamn, me)
            koll.objects.link(ob)
            obs.append(ob)
            ob["uv_täthet"] = d
        self.uv_stat = [(q["del"], mn, q["w"] * q["h"]) for q in lay["banor"]]
        self.uv_täthet = d
        return obs


class Yta:
    """En fasad som ett plan: u löper längs väggen (mitten = 0), z är höjd över marken.

    Allt som sitter på en vägg — fönster, dörr, skylt, bjälkar, bleck — byggs i de här lokala
    koordinaterna, så samma byggdel fungerar på alla fyra fasaderna.
    """

    def __init__(self, sida, w, d, tjock):
        self.sida, self.w, self.d, self.tjock = sida, w, d, tjock
        ut = {"fram": Vector((0, -1, 0)), "bak": Vector((0, 1, 0)),
              "vänster": Vector((-1, 0, 0)), "höger": Vector((1, 0, 0))}[sida]
        uax = {"fram": Vector((1, 0, 0)), "bak": Vector((-1, 0, 0)),
               "vänster": Vector((0, -1, 0)), "höger": Vector((0, 1, 0))}[sida]
        plan = {"fram": Vector((0, -d / 2, 0)), "bak": Vector((0, d / 2, 0)),
                "vänster": Vector((-w / 2, 0, 0)), "höger": Vector((w / 2, 0, 0))}[sida]
        self.n, self.u, self.plan = ut, uax, plan
        # sidoväggarna kortas en väggtjocklek så hörnen inte överlappar fram-/bakväggen
        self.längd = w if sida in ("fram", "bak") else d - 2 * tjock

    def punkt(self, u, z, ut=0.0):
        return self.plan + self.u * u + Vector((0, 0, z)) + self.n * ut

    def låda(self, b, u, z, du, dz, djup, mat, ut=0.0):
        """Låda på fasaden: närmaste yta `ut` från väggplanet, djupet går utåt."""
        c = self.punkt(u, z + dz / 2, ut + djup / 2)
        s = (du, djup, dz) if self.sida in ("fram", "bak") else (djup, du, dz)
        b.låda((c.x, c.y, c.z - dz / 2), s, mat)


def fasad_ytor(w, d, tjock):
    return {s: Yta(s, w, d, tjock) for s in ("fram", "bak", "vänster", "höger")}


# --- väggar ----------------------------------------------------------------------------------
def väggkärna(b, yta, z0, z1, hål, mat=None):
    """Tät kärna innanför murskinnet/timret: fogarna mellan blocken visar mörkt, inte himmel."""
    mat = mat or mur()
    for q in skär((-yta.längd / 2, z0, yta.längd / 2, z1), hål):
        yta.låda(b, (q[0] + q[2]) / 2, q[1], q[2] - q[0], q[3] - q[1],
                 yta.tjock * 0.55, mat, ut=-yta.tjock)


def fasadmur(b, yta, z0, z1, mat, block=(0.95, 0.45), hål=(), förband=True):
    """Murad fasad: skinn av block i skift med fogar, ovanpå en tät kärna.

    Blocken klipps runt öppningarna (skär), så fönster och dörrar är hål rakt igenom väggen.
    """
    hål = list(hål)
    väggkärna(b, yta, z0, z1, hål)
    z, rad = z0, 0
    while z < z1 - 1e-4:
        h = min(block[1], z1 - z)
        off = (block[0] / 2) * (rad % 2) if förband else 0.0
        u = -yta.längd / 2 - off
        while u < yta.längd / 2 - 1e-4:
            a, c = max(u, -yta.längd / 2), min(u + block[0], yta.längd / 2)
            if c - a > 0.05:
                for q in skär((a, z, c, z + h), hål):
                    # ingen bit får ligga i en öppning — det är hela poängen med skär
                    assert not any(_överlappar(q, hh) for hh in hål)
                    yta.låda(b, (q[0] + q[2]) / 2, q[1], q[2] - q[0] - 0.016,
                             q[3] - q[1] - 0.008, yta.tjock * 0.46, mat, ut=-yta.tjock * 0.46)
            u += block[0]
        z += block[1]
        rad += 1


def stång(b, mat, a, c, bredd=0.17, tjock=0.09, ut=(0, 1, 0)):
    """Sluten platta mellan två punkter — snedsträva, takstol eller stag var som helst i rummet."""
    a, c = Vector(a), Vector(c)
    if (c - a).length < 1e-6:
        return
    q = (c - a).normalized().cross(Vector(ut)).normalized() * (bredd / 2)
    b.platta(mat, [a + q, c + q, c - q, a - q], ut, tjock)


def sträva(b, yta, u0, z0, u1, z1, bredd=0.17, mat=None, ut=0.0, tjock=0.09):
    """Snedsträva i fasadplanet."""
    stång(b, mat or mörkt_virke(), yta.punkt(u0, z0, ut), yta.punkt(u1, z1, ut),
          bredd, tjock, yta.n)


def korsvirke(b, yta, z0, z1, hål, puts_mat=None, trä_mat=None, stolp=2.1):
    """Putsade fack med synliga bjälkar, stolpar och snedsträvor.

    Putsen är en tät skiva med hål (fönstren går igenom); bjälkarna ligger utanpå. Strävorna sitter
    i ytterfacken och lutar inåt mot mitten — det är korsvirket som gör att huset läses som
    medeltida bygge i stället för som en låda.
    """
    puts_mat = puts_mat or puts()
    trä_mat = trä_mat or mörkt_virke()
    hål = list(hål)
    for q in skär((-yta.längd / 2, z0, yta.längd / 2, z1), hål):
        yta.låda(b, (q[0] + q[2]) / 2, q[1], q[2] - q[0], q[3] - q[1], yta.tjock, puts_mat,
                 ut=-yta.tjock)
    # syll, mittband och huvudband: smala nog att putsen dominerar fasaden
    band = [z0, (z0 + z1) / 2 - 0.08, z1 - 0.16]
    for z in band:
        yta.låda(b, 0, z, yta.längd, 0.16, 0.09, trä_mat)
    n = max(2, int(round(yta.längd / stolp)))
    bw = yta.längd / n
    for i in range(n + 1):
        yta.låda(b, -yta.längd / 2 + bw * i, z0, 0.15, z1 - z0, 0.09, trä_mat)
    # snedsträvor i ytterfacken, en per våning och sida
    for sida in (-1, 1):
        x = sida * (yta.längd / 2 - bw / 2)
        for k in range(len(band) - 1):
            za, zb = band[k] + 0.16, band[k + 1]
            sträva(b, yta, x + sida * bw * 0.44, za, x - sida * bw * 0.44, zb,
                   bredd=0.14, mat=trä_mat, ut=0.045, tjock=0.08)


def gavel(b, w, d, z0, höjd, nock, mat, tjock=0.45, brädor=True, bräda=0.3):
    """Gavelspetsen över väggens överkant: ett tätt trekantigt prisma med brädor som relief.

    Spetsen är en SLUTEN yta (trekant + tre sidor), inte en trappa av allt smalare plank — det var
    trappan som lämnade öppna springor mot takets undersida.
    """
    for sida in (-1, 1):
        if nock == "y":
            ut = Vector((0, sida, 0))
            y0 = sida * d / 2
            y1 = y0 - sida * tjock
            bas = [Vector((-w / 2, y0, z0)), Vector((w / 2, y0, z0)), Vector((0, y0, z0 + höjd))]
        else:
            ut = Vector((sida, 0, 0))
            x0 = sida * w / 2
            x1 = x0 - sida * tjock
            bas = [Vector((x0, -d / 2, z0)), Vector((x0, d / 2, z0)), Vector((x0, 0, z0 + höjd))]
        inre = [Vector((p.x - ut.x * tjock, p.y - ut.y * tjock, p.z)) for p in bas]
        b.tri(mat, bas, ut)
        b.tri(mat, inre, -ut)
        b.skiva(mat, [bas[0], bas[2], inre[2], inre[0]], Vector((-ut.y, -ut.x, 0)))
        b.skiva(mat, [bas[1], bas[2], inre[2], inre[1]], Vector((ut.y, ut.x, 0)))
        b.skiva(mat, [bas[0], bas[1], inre[1], inre[0]], Vector((0, 0, -1)))
        if not brädor:
            continue
        # liggande brädor på gavelytan: relief, klippta mot trekanten så ingen sticker ut
        z = z0 + bräda
        while z < z0 + höjd - 0.16:
            kvar = 1.0 - (z - z0) / höjd
            if nock == "y":
                b.låda((0, sida * (d / 2 + 0.03), z), (w * kvar * 0.94, 0.06, bräda * 0.82), mat)
            else:
                b.låda((sida * (w / 2 + 0.03), 0, z), (0.06, d * kvar * 0.94, bräda * 0.82),
                       mat)
            z += bräda


def _panna(b, mat, P, du, dv, dn, ua, ub, v0, v1, tjock=0.05):
    """En skifferpanna med tjocklek: 10 tri — överyta, underyta, hängläpp och två kanter.

    Pannorna ligger med 2,4 cm springa i sidled och läppen vid varje rad ger skuggan som gör
    överlappet läsbart: förbandet syns som enskilda pannor, inte som en slät yta.
    """
    A, B = P(ua, v1, tjock), P(ub, v1, tjock)
    C, D = P(ub, v0, tjock), P(ua, v0, tjock)
    A2, B2, C2, D2 = A - dn * tjock, B - dn * tjock, C - dn * tjock, D - dn * tjock
    b.skiva(mat, [A, B, C, D], dn)
    b.skiva(mat, [D2, C2, B2, A2], -dn)
    b.skiva(mat, [D, C, C2, D2], -dv)
    b.skiva(mat, [D, D2, A2, A], -du)
    b.skiva(mat, [B, C, C2, B2], du)


def takplan(b, P, du, dv, dn, längd, L, mat_a, mat_b, panbredd=0.3, panrad=0.24,
            bredd=None, underlag=None, insida=None, mitt=0.0):
    """Ett takplan med enskilda pannor i förband.

    (u, v): u längs nocken, v uppåt (0..L). `mitt` är radens mitt i u — för ett sadeltak ligger
    takfotens vänstra hörn i u = 0 och mitten i längd/2; för en pyramid ligger mitten i 0. `bredd(v)`
    ger planens bredd på höjden v (konstant för sadeltak, avsmalnande för valm). Raderna delar L
    jämnt och varje rad delas jämnt i pannor, så planet blir helt täckt: ingen halv förskjutning,
    ingen springa vid takfot eller nock.
    """
    underlag = underlag or kol()
    insida = insida or mörkt_virke()
    rader = max(3, int(round(L / panrad)))
    for r in range(rader):
        v0, v1 = L * r / rader, L * (r + 1) / rader
        rb0 = bredd(v0) if bredd else längd
        rb1 = bredd(v1) if bredd else längd
        # underlaget (mörkt) täcker planet radvis, så springorna mellan pannorna blir skugga
        b.skiva(underlag, [P(mitt - rb0 / 2, v0, 0.0), P(mitt + rb0 / 2, v0, 0.0),
                           P(mitt + rb1 / 2, v1, 0.0), P(mitt - rb1 / 2, v1, 0.0)], dn)
        b.skiva(insida, [P(mitt - rb0 / 2, v0, -0.04), P(mitt + rb0 / 2, v0, -0.04),
                         P(mitt + rb1 / 2, v1, -0.04), P(mitt - rb1 / 2, v1, -0.04)], -dn)
        antal = max(1, int(round(rb1 / panbredd)))
        tw = rb1 / antal
        summa = 0.0
        for k in range(antal):
            u0 = mitt - rb1 / 2 + k * tw
            summa += tw
            _panna(b, mat_a if (r + k) % 2 else mat_b, P, du, dv, dn,
                   u0 + 0.012, u0 + tw - 0.012, v0, v1)
        assert abs(summa - rb1) < 1e-6, "pannorna täcker inte raden"
        if bredd is None:
            # fångar halva-taklängden-förskjutningen: raderna måste ligga i planet, inte utanför
            assert abs(mitt - längd / 2) < 1e-9, "takplanets rader ligger utanför planet"


def nock_rund(b, längd, z_nock, nockvektor, mat_a=None, mat_b=None, radie=0.28, steg=0.42,
              facet=6):
    """Nockpannor som halvrunda kammar: sex facetter över nocken, lagda i förband längs hela nocken.

    Rundningen är det enda i taket som inte är kantigt — en nock av platta skivor läses som en ås,
    inte som pannor.
    """
    mat_a = mat_a or panna_mörk()
    mat_b = mat_b or panna_ljus()
    q = Vector((0, 0, 1)).cross(nockvektor).normalized()
    topp = Vector((0, 0, z_nock))
    n = max(2, int(round(längd / steg)))
    for i in range(n):
        u0 = -längd / 2 + längd * i / n + 0.012
        u1 = -längd / 2 + längd * (i + 1) / n - 0.012
        mat = mat_a if i % 2 else mat_b
        ring = [q * (radie * math.cos(math.pi * k / facet))
                + Vector((0, 0, radie * math.sin(math.pi * k / facet))) for k in range(facet + 1)]
        for k in range(facet):
            p0, p1 = ring[k], ring[k + 1]
            ut = q * math.cos(math.pi * (k + 0.5) / facet) + \
                Vector((0, 0, math.sin(math.pi * (k + 0.5) / facet)))
            b.skiva(mat, [nockvektor * u0 + p0, nockvektor * u1 + p0,
                          nockvektor * u1 + p1, nockvektor * u0 + p1], ut)
        for u, sida in ((u0, -1), (u1, 1)):
            mittp = nockvektor * u + topp
            for k in range(facet):
                b.tri(mat, [mittp, nockvektor * u + ring[k + 1], nockvektor * u + ring[k]],
                      nockvektor * sida)


def sadeltak(b, w, d, z0, höjd, nock_riktning, pannor=None, utsprång=0.55, panbredd=0.3,
             panrad=0.24, sparrar=True):
    """Sadeltak med pannor i förband, nockpannor, sparrar under takfoten och vindskivor.

    w/d är VÄGGENS mått; taket läggs `utsprång` utanför. Takfoten ligger i väggens överkant och
    nocken `höjd` över den, så gavelns spets möter taket exakt.
    """
    pa, pb = pannor or (panna_mörk(), panna_ljus())
    if nock_riktning == "x":
        halv, längd, du = d / 2 + utsprång, w + 2 * utsprång, Vector((1, 0, 0))
        kanter = [(1, Vector((0, halv, z0))), (-1, Vector((0, -halv, z0)))]
    else:
        halv, längd, du = w / 2 + utsprång, d + 2 * utsprång, Vector((0, 1, 0))
        kanter = [(1, Vector((halv, 0, z0))), (-1, Vector((-halv, 0, z0)))]
    L = math.hypot(halv, höjd)
    for s, kant in kanter:
        if nock_riktning == "x":
            dv = Vector((0, -s * halv, höjd)) / L
            dn = Vector((0, s * höjd, halv)) / L
        else:
            dv = Vector((-s * halv, 0, höjd)) / L
            dn = Vector((s * höjd, 0, halv)) / L
        start = kant - du * (längd / 2)

        def P(u, v, o=0.0, start=start, du=du, dv=dv, dn=dn):
            return start + du * u + dv * v + dn * o

        takplan(b, P, du, dv, dn, längd, L, pa, pb, panbredd, panrad, mitt=längd / 2)
        # takfotsbräda + synliga sparrar under takfoten, och en hängränna i järn
        b.platta(panna_mörk(), [P(0, -0.02, -0.2), P(längd, -0.02, -0.2),
                                P(längd, 0.08, 0.02), P(0, 0.08, 0.02)], dn, 0.07)
        if sparrar:
            n = max(2, int(round(längd / 0.44)))
            for i in range(n + 1):
                u = längd * i / n
                a = P(max(u - 0.05, 0.0), -0.22, -0.07)
                c = P(min(u + 0.05, längd), -0.22, -0.07)
                d2 = P(min(u + 0.05, längd), L * 0.96, -0.07)
                e = P(max(u - 0.05, 0.0), L * 0.96, -0.07)
                b.platta(mörkt_virke(), [a, c, d2, e], dn, 0.2)
        # hängränna längs takfoten
        mitt_e = P(0.0, -0.06, 0.02)
        axel = "x" if nock_riktning == "x" else "y"
        b.prisma(järn(), (mitt_e.x, mitt_e.y, mitt_e.z), 0.1, längd, n=8, axel=axel)
        # vindskivor längs gavlarna, med droppnäsa
        for u in (0.0, längd):
            a = P(u, -0.12, -0.44)
            c = P(u, L, -0.44)
            d2 = P(u, L, 0.05)
            e = P(u, -0.12, 0.05)
            b.platta(panna_ljus(), [a, c, d2, e], du * (1 if u else -1), 0.07)
    nock_rund(b, längd, z0 + höjd, du, pa, pb)


def tälttak(b, w, d, z0, höjd, pannor=None, utsprång=0.35, panbredd=0.3, panrad=0.24):
    """Pyramidtak över en fyrkant: fyra plan med pannor som smalnar mot nocken.

    Varje plan är en triangel, så radernas bredd följer `bredd(v)`; springorna i hörnen (valmen)
    täcks av valmbrädor, precis som en riktig valm har valmspetsar.
    """
    pa, pb = pannor or (panna_mörk(), panna_ljus())
    W, D = w + 2 * utsprång, d + 2 * utsprång
    # (takfotens mitt, riktning längs takfoten, utåtriktning, bredd vid takfot, halv längd)
    plan = [(Vector((0, D / 2, z0)), Vector((1, 0, 0)), Vector((0, 1, 0)), W, D / 2),
            (Vector((0, -D / 2, z0)), Vector((-1, 0, 0)), Vector((0, -1, 0)), W, D / 2),
            (Vector((W / 2, 0, z0)), Vector((0, 1, 0)), Vector((1, 0, 0)), D, W / 2),
            (Vector((-W / 2, 0, z0)), Vector((0, -1, 0)), Vector((-1, 0, 0)), D, W / 2)]
    for start, du, ut, bredd, halv in plan:
        L = math.hypot(halv, höjd)
        dv = (-ut * halv + Vector((0, 0, höjd))) / L
        dn = (ut * höjd + Vector((0, 0, halv))) / L

        def P(u, v, o=0.0, start=start, du=du, dv=dv, dn=dn):
            return start + du * u + dv * v + dn * o

        takplan(b, P, du, dv, dn, bredd, L, pa, pb, panbredd, panrad,
                bredd=lambda v, bredd=bredd, L=L: bredd * (1.0 - v / L))
    # valmbrädor längs de fyra valmerna (hörn -> nock), täcker springan mellan planen
    topp = Vector((0, 0, z0 + höjd))
    for su in (-1, 1):
        for sv in (-1, 1):
            hörn = Vector((su * W / 2, sv * D / 2, z0))
            d2 = (topp - hörn).normalized()
            q = d2.cross(Vector((0, 0, 1))).normalized() * 0.17
            b.platta(panna_ljus(), [hörn + q, topp + q, topp - q, hörn - q],
                     Vector((su, sv, 0)), 0.08)
    # nock: en liten mössa där de fyra planen möts
    b.låda((0, 0, z0 + höjd - 0.08), (0.52, 0.52, 0.26), pa)
    b.låda((0, 0, z0 + höjd + 0.18), (0.3, 0.3, 0.12), pb)


def skorsten(b, x, y, z0, h, bredd=0.8, mat=None, hatt=True):
    """Skorsten av murade skift med tätare fogar än husets, plus hatt och sotkant."""
    mat = mat or tegel()
    b.låda((x, y, z0), (bredd, bredd, h), mur())
    kurser = max(5, int(h / 0.24))
    for k in range(kurser):
        b.skift(bredd, bredd, z0 + h * k / kurser, h / kurser, mat, block=0.36,
                tjock=0.07, förskjut=(0.18 if k % 2 else 0.0))
    if hatt:
        b.låda((x, y, z0 + h), (bredd + 0.16, bredd + 0.16, 0.1), sten())
        b.låda((x, y, z0 + h + 0.1), (bredd * 0.58, bredd * 0.58, 0.2), kol())
        b.låda((x, y, z0 + h - 0.18), (bredd + 0.08, bredd + 0.08, 0.06), järn())


# --- öppningar -------------------------------------------------------------------------------
def fonster(b, yta, hål, u, z, w, h, sprojs=(2, 2), luckor=False, glas=None, karm_mat=None,
            bleck=True):
    """Fönster med foder, bänk, spröjs, bleck och luckor — ett hål genom väggen med karmen i.

    Glaset sitter på halva väggdjupet med blyspröjs, karmen fodrar hela hålet och bänken skjuter ut.
    Utan djupet blir rutan en platt fyrkant i närbild; fodret i öppningen (inte utanpå väggen) är
    det som gör att fönstret sitter I väggen.
    """
    t = yta.tjock
    glas = glas or fönster()
    karm_mat = karm_mat or karm()
    hål.setdefault(yta.sida, []).append((u - w / 2, z, u + w / 2, z + h))
    # foder runt öppningen, genom hela väggtjockleken (sticker 2 cm ut på båda sidor)
    yta.låda(b, u - w / 2 + 0.05, z - 0.06, 0.1, h + 0.12, t + 0.05, karm_mat, ut=-t)
    yta.låda(b, u + w / 2 - 0.05, z - 0.06, 0.1, h + 0.12, t + 0.05, karm_mat, ut=-t)
    yta.låda(b, u, z + h - 0.05, w - 0.1, 0.1, t + 0.05, karm_mat, ut=-t)
    yta.låda(b, u, z, w - 0.1, 0.1, t + 0.05, karm_mat, ut=-t)
    # fönsterbänk som skjuter ut ur fasaden
    yta.låda(b, u, z - 0.09, w + 0.2, 0.09, 0.16, karm_mat, ut=-0.02)
    # glaset på halva djupet, delat i rutor
    kx, kz = sprojs
    gw, gh = (w - 0.16) / kx, (h - 0.16) / kz
    for i in range(kx):
        for j in range(kz):
            gx = u - (w - 0.16) / 2 + (i + 0.5) * gw
            gz = z + 0.08 + j * gh
            yta.låda(b, gx, gz, gw * 0.96, gh * 0.96, 0.045, glas, ut=-t * 0.5)
    # blyspröjs: tunna ribbor på glaset, och den grövre spröjsen utanför
    for i in range(1, kx):
        yta.låda(b, u - (w - 0.16) / 2 + i * gw, z + 0.06, 0.028, h - 0.12, 0.02, karm_mat,
                 ut=-t * 0.5 + 0.05)
    for j in range(1, kz):
        yta.låda(b, u, z + 0.08 + j * gh - 0.014, w - 0.16, 0.028, 0.02, karm_mat,
                 ut=-t * 0.5 + 0.05)
    for i in range(1, kx):
        yta.låda(b, u - (w - 0.16) / 2 + i * gw, z + 0.06, 0.055, h - 0.12, 0.055, karm_mat,
                 ut=-t * 0.5 + 0.05)
    for j in range(1, kz):
        yta.låda(b, u, z + 0.08 + j * gh - 0.028, w - 0.16, 0.055, 0.055, karm_mat,
                 ut=-t * 0.5 + 0.05)
    if bleck:  # fönsterbleck: skjuter ut och lutar utåt, som plåt
        yta.låda(b, u, z - 0.13, w + 0.34, 0.06, 0.24, järn())
    if luckor:  # fönsterluckor med brädor, gångjärn och tvärslå, uppfällda mot väggen
        for s in (-1, 1):
            su = u + s * (w / 2 + 0.25)
            n = 3
            for k in range(n):
                yta.låda(b, su - 0.2 + 0.2 * (k + 0.5), z - 0.05, 0.19, h + 0.1, 0.055,
                         mörkt_virke())
            yta.låda(b, su, z + h * 0.45, 0.42, 0.07, 0.04, ljust_virke(), ut=0.055)
            yta.låda(b, su, z + 0.06, 0.42, 0.07, 0.04, ljust_virke(), ut=0.055)
            sträva(b, yta, su - s * 0.18, z + 0.12, su + s * 0.18, z + h - 0.12, bredd=0.1,
                   mat=ljust_virke(), ut=0.08, tjock=0.03)
            for zz in (z + 0.14, z + h - 0.2):
                yta.låda(b, su - s * 0.18, zz, 0.2, 0.07, 0.05, järn(), ut=0.075)
                yta.låda(b, su - s * 0.05, zz + 0.02, 0.05, 0.05, 0.03, järn(), ut=0.02)
    # överliggare
    yta.låda(b, u, z + h + 0.1, w + 0.36, 0.2, 0.1, karm_mat)


def dörr(b, yta, hål, u, z, w=1.7, h=3.0, mat=None, karm_mat=None, steg=2, handtag=True):
    """Dörr: plankor i karm, smidda band med nitar, ringhandtag, tröskel och trappsteg.

    Öppningen är ett hål rakt genom väggen; bladet sitter på halva djupet och banden utanpå det.
    """
    t = yta.tjock
    mat = mat or mörkt_virke()
    karm_mat = karm_mat or mörkt_virke()
    hål.setdefault(yta.sida, []).append((u - w / 2, z, u + w / 2, z + h + 0.1))
    for s in (-1, 1):
        yta.låda(b, u + s * (w / 2 - 0.06), z, 0.12, h + 0.2, t + 0.05, karm_mat, ut=-t)
    yta.låda(b, u, z + h + 0.04, w - 0.12, 0.12, t + 0.05, karm_mat, ut=-t)
    # dörrblad av plankor på halva djupet
    n = max(7, int(round(w / 0.18)))
    for i in range(n):
        yta.låda(b, u - w / 2 + w * (i + 0.5) / n, z + 0.02, w / n * 0.9, h - 0.02, 0.09, mat,
                 ut=-t * 0.5)
    # tvärslåar på insidan och tre smidda band med nitar utanpå
    for zz in (z + 0.3, z + h * 0.52):
        yta.låda(b, u, zz, w * 0.94, 0.16, 0.06, ljust_virke(), ut=-t * 0.5 + 0.09)
    for zz, bredd_band in ((z + 0.34, w * 0.9), (z + h * 0.5, w * 0.76), (z + h - 0.36, w * 0.9)):
        yta.låda(b, u, zz, bredd_band, 0.13, 0.045, järn(), ut=-t * 0.5 + 0.09)
        for i in range(int(bredd_band / 0.22)):
            yta.låda(b, u - bredd_band / 2 + 0.11 + i * 0.22, zz + 0.03, 0.05, 0.05, 0.03, järn(),
                     ut=-t * 0.5 + 0.135)
    # gångjärn på gångjärnssidan
    for zz in (z + 0.34, z + h - 0.36):
        yta.låda(b, u - w / 2 + 0.34, zz - 0.02, 0.66, 0.16, 0.07, järn(), ut=-t * 0.5 + 0.09)
        yta.låda(b, u - w / 2 + 0.06, zz - 0.06, 0.1, 0.24, 0.09, järn(), ut=-t * 0.5 + 0.1)
    if handtag:
        hx = u + w / 2 - 0.26
        yta.låda(b, hx, z + h * 0.48, 0.14, 0.18, 0.05, järn(), ut=-t * 0.5 + 0.14)
        ring = yta.punkt(hx, z + h * 0.45, -t * 0.5 + 0.19)
        b.prisma(järn(), (ring.x, ring.y, ring.z), 0.11, 0.05, n=8, axel="y")
        yta.låda(b, hx, z + h * 0.48 + 0.02, 0.06, 0.08, 0.06, järn(), ut=-t * 0.5 + 0.17)
    # tröskelsten och steg
    yta.låda(b, u, z - 0.12, w + 0.5, 0.1, 0.36, sten())
    for i in range(steg):
        yta.låda(b, u, 0, w + 0.6 - 0.08 * i, z * (steg - i) / (steg + 1), 0.3 + 0.34 * i, sten())


def portvalv(b, yta, hål, u, z, w, h_spring, r=None, mat=None):
    """Välvd portöppning: rektangulärt hål till vederlaget + halvcirkelformat valv över.

    Hålet är rektangulärt (skär kan bara klippa rektanglar), så valvet byggs av en ring av kilstenar
    plus spandrillfyllning mellan ringen och hålets överkant. Porten blir ett hål rakt igenom.
    """
    r = r or w / 2
    mat = mat or sten()
    t = yta.tjock
    z_spring = z + h_spring
    z_topp = z_spring + r
    hål_rect = (u - w / 2, z, u + w / 2, z_topp)
    hål.setdefault(yta.sida, []).append(hål_rect)
    # spandrillfyllning: mursten utanför kilstensringen, rad för rad upp mot hålets överkant
    r_ring = r + 0.34
    rad = 0.26
    zz = z_spring
    while zz < z_topp - 0.02:
        hh = min(rad, z_topp - zz)
        dz = zz + hh / 2 - z_spring
        kvar = math.sqrt(max(r_ring * r_ring - dz * dz, 0.0))
        for s in (-1, 1):
            a, c = u + s * min(kvar, w / 2), u + s * (w / 2)
            if abs(c - a) > 0.05:
                yta.låda(b, (a + c) / 2, zz, abs(c - a) - 0.014, hh - 0.01, t * 0.46, mat,
                         ut=-t * 0.46)
        zz += rad
    # kilstensring runt bågen, 3 cm utanpå muren så fogarna syns
    kil = 13
    for i in range(kil):
        v0, v1 = math.pi * i / kil, math.pi * (i + 1) / kil
        ring = [yta.punkt(u - r * math.cos(v0), z_spring + r * math.sin(v0), 0.03),
                yta.punkt(u - r * math.cos(v1), z_spring + r * math.sin(v1), 0.03),
                yta.punkt(u - r_ring * math.cos(v1), z_spring + r_ring * math.sin(v1), 0.03),
                yta.punkt(u - r_ring * math.cos(v0), z_spring + r_ring * math.sin(v0), 0.03)]
        b.platta(mat, ring, yta.n, t * 0.5)
    # slutsten
    mittsten = yta.punkt(u, z_spring + r + 0.17, 0.05)
    b.låda((mittsten.x, mittsten.y, mittsten.z - 0.2), (0.34, 0.24, 0.44)
           if yta.sida in ("fram", "bak") else (0.24, 0.34, 0.44), puts())
    # tröskel och foder kring porten
    yta.låda(b, u, z, w + 0.3, 0.14, 0.34, sten())
    for s in (-1, 1):
        yta.låda(b, u + s * (w / 2 + 0.04), z, 0.12, h_spring + 0.1, t + 0.04, sten(), ut=-t)


def lykta(b, yta, u, z, arm=0.5):
    """Vägglykta: järnarm med krok, glaslykta som lyser, plåttak och fot."""
    yta.låda(b, u, z + 0.62, 0.07, 0.07, arm, järn())
    yta.låda(b, u, z + 0.4, 0.05, 0.3, 0.05, järn(), ut=arm - 0.02)
    yta.låda(b, u, z, 0.4, 0.56, 0.4, lyktglas(), ut=arm + 0.04)
    for s in (-1, 1):
        yta.låda(b, u + s * 0.19, z, 0.03, 0.6, 0.03, järn(), ut=arm + 0.04)
        yta.låda(b, u, z, 0.03, 0.6, 0.03, järn(), ut=arm + 0.04 + s * 0.19)
    yta.låda(b, u, z + 0.56, 0.52, 0.1, 0.52, järn(), ut=arm + 0.04)
    yta.låda(b, u, z - 0.08, 0.46, 0.08, 0.46, järn(), ut=arm + 0.04)
    yta.låda(b, u, z + 0.66, 0.1, 0.14, 0.1, järn(), ut=arm + 0.04)


def skylt(b, yta, u, z, bredd=1.4, höjd=1.0, emblem="ring", ut=0.8):
    """Hängande skylt: konsol med snedsträva, två öglor, bräda med målat fält och emblem."""
    yta.låda(b, u, z + höjd + 0.24, 0.1, 0.1, ut, järn())
    yta.låda(b, u, z + höjd + 0.02, 0.09, 0.09, ut * 0.55, järn())
    for s in (-1, 1):
        yta.låda(b, u + s * bredd * 0.33, z + höjd - 0.05, 0.05, 0.22, 0.05, järn(), ut=ut - 0.02)
    yta.låda(b, u, z, bredd, höjd, 0.09, ljust_virke(), ut=ut)
    yta.låda(b, u, z + höjd * 0.12, bredd * 0.76, höjd * 0.72, 0.03, skyltfält(), ut=ut + 0.09)
    # emblem: kantiga figurer som läses på håll
    if emblem == "ring":
        yta.låda(b, u, z + höjd * 0.42, bredd * 0.3, 0.12, 0.03, mässing(), ut=ut + 0.12)
        yta.låda(b, u, z + höjd * 0.3, 0.12, höjd * 0.36, 0.03, mässing(), ut=ut + 0.12)
    elif emblem == "kanna":
        yta.låda(b, u - 0.04, z + höjd * 0.32, bredd * 0.24, höjd * 0.3, 0.03, mässing(),
                 ut=ut + 0.12)
        yta.låda(b, u + bredd * 0.15, z + höjd * 0.42, 0.08, höjd * 0.16, 0.03, mässing(),
                 ut=ut + 0.12)
    elif emblem == "smed":
        yta.låda(b, u, z + höjd * 0.34, bredd * 0.44, 0.1, 0.03, järn(), ut=ut + 0.12)
        yta.låda(b, u - bredd * 0.02, z + höjd * 0.46, 0.09, höjd * 0.24, 0.03, järn(),
                 ut=ut + 0.12)
    elif emblem == "juvel":
        for dx, dz in ((0, 0.12), (-0.12, 0), (0.12, 0)):
            yta.låda(b, u + dx * bredd, z + höjd * 0.36 + dz, 0.14, 0.14, 0.03, mässing(),
                     ut=ut + 0.12)
    elif emblem == "brunn":
        yta.låda(b, u, z + höjd * 0.2, bredd * 0.3, 0.3, 0.03, puts(), ut=ut + 0.12)
        yta.låda(b, u, z + höjd * 0.5, 0.08, höjd * 0.4, 0.03, mässing(), ut=ut + 0.12)


def trappa(b, yta, u, z_topp, w=2.4, steg=4, mat=None):
    """Stentrappa framför en dörr: trappsteg med sidostycken."""
    mat = mat or sten()
    for i in range(steg):
        h = z_topp * (i + 1) / (steg + 1)
        yta.låda(b, u, 0, w, h, 0.3 + 0.36 * i, mat)
    for s in (-1, 1):
        yta.låda(b, u + s * (w / 2 + 0.09), 0, 0.2, z_topp, 0.3 + 0.36 * (steg - 1), mat)


# --- lös rekvisita ---------------------------------------------------------------------------
def tunna(b, x, y, z=0.0, r=0.45, h=1.15, mat=None):
    """Tunna av stavar med tre band — läsbar silhuett i byn."""
    mat = mat or ljust_virke()
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        c = Vector((x + r * 0.86 * math.cos(a), y + r * 0.86 * math.sin(a), z))
        m = (Matrix.Translation(c) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")
             @ Matrix.Translation(-c))
        b.låda((c.x, c.y, z), (r * 0.46, 0.07, h), mat, m)
    for zz in (z + 0.1, z + h * 0.5, z + h - 0.14):
        b.prisma(järn(), (x, y, zz), r * 1.02, 0.07, n=14)
    b.prisma(mat, (x, y, z + h - 0.05), r * 0.95, 0.06, n=14)
    b.prisma(mat, (x, y, z + 0.01), r * 0.9, 0.04, n=14)


def spann(b, x, y, z=0.0, r=0.32, h=0.55, mat=None):
    """Spann (hink) av stavar med band och bygel."""
    mat = mat or ljust_virke()
    for i in range(10):
        a = 2 * math.pi * i / 10
        c = Vector((x + r * 0.8 * math.cos(a), y + r * 0.8 * math.sin(a), z))
        m = (Matrix.Translation(c) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")
             @ Matrix.Translation(-c))
        b.låda((c.x, c.y, z), (r * 0.52, 0.05, h), mat, m)
    for zz in (z + 0.08, z + h - 0.1):
        b.prisma(järn(), (x, y, zz), r * 0.94, 0.05, n=10)
    b.prisma(mat, (x, y, z + 0.02), r * 0.8, 0.04, n=10)
    for s in (-1, 1):
        b.låda((x + s * r * 0.78, y, z + h), (0.05, 0.05, 0.34), järn())
    b.låda((x, y, z + h + 0.3), (r * 1.62, 0.05, 0.05), järn())


def kista(b, x, y, z=0.0, s=0.7, mat=None):
    """Låda/kista av plankor med hörnbeslag."""
    mat = mat or ljust_virke()
    b.låda((x, y, z), (s, s * 0.8, s * 0.8), mat)
    for sida in (-1, 1):
        b.låda((x, y + sida * (s * 0.4 + 0.01), z + 0.06), (s * 1.02, 0.03, 0.06), järn())
    for dx in (-1, 1):
        for dy in (-1, 1):
            b.låda((x + dx * (s / 2 - 0.03), y + dy * (s * 0.4 - 0.03), z),
                   (0.06, 0.06, s * 0.84), järn())
    b.låda((x, y, z + s * 0.8), (s * 1.04, s * 0.84, 0.05), ljust_virke())


def säck(b, x, y, z=0.0, s=0.55):
    """Säck med knuten öppning och band — ett par lådor, läses som halm/kol."""
    b.låda((x, y, z), (s, s * 0.8, s * 0.9), halm())
    b.låda((x, y, z + s * 0.9), (s * 0.6, s * 0.5, s * 0.3), halm())
    b.låda((x, y, z + s * 0.86), (s * 0.66, s * 0.56, 0.04), rep())


def vedhög(b, x, y, z=0.0, bredd=2.6, höjd=1.3):
    """Travad ved: stockar i två lager med ändträ utåt."""
    lager = max(2, int(höjd / 0.3))
    for l in range(lager):
        n = max(2, int(bredd / 0.3))
        for i in range(n):
            px = x - bredd / 2 + bredd * (i + 0.5) / n + (0.05 if l % 2 else 0.0)
            b.prisma(mörkt_virke(), (px, y - 0.7, z + 0.14 + l * 0.28), 0.14, 1.3, n=6, axel="y")
        b.låda((x, y - 0.72, z + l * 0.28), (bredd, 0.06, 0.06), mörkt_virke())


# --- rekvisita som hör till torget -------------------------------------------------------------
def plagg(b, x, y, z, mat, bredd=0.62, höjd=1.05):
    """Ett plagg på en klädstreck: liv, två ärmar, fåll och klämma."""
    b.låda((x, y, z), (bredd, 0.07, höjd), mat)
    for s in (-1, 1):
        b.låda((x + s * (bredd / 2 + 0.09), y, z + 0.14), (0.18, 0.07, höjd * 0.56), mat)
        b.låda((x + s * (bredd / 2 + 0.09), y, z + 0.14), (0.2, 0.05, 0.05), mat)
    b.låda((x, y, z + 0.02), (bredd * 0.92, 0.06, 0.07), mat)
    b.låda((x, y, z + höjd - 0.03), (0.06, 0.06, 0.1), rep())


def klädlina(b, x0, x1, y, z, tyger, höjd=1.05):
    """Klädstreck med plagg — ståndets hela poäng, det som syns först i bilden."""
    b.låda(((x0 + x1) / 2, y, z), (abs(x1 - x0), 0.03, 0.03), rep())
    n = len(tyger)
    for i, mat in enumerate(tyger):
        plagg(b, x0 + (x1 - x0) * (i + 0.5) / n, y, z - höjd - 0.02, mat, höjd=höjd)


def fackla(b, yta, u, z, arm=0.34):
    """Fackla i järnhållare: bygel, skål, trassel och en emissiv låga."""
    yta.låda(b, u, z, 0.1, 0.1, arm, järn())
    yta.låda(b, u, z - 0.02, 0.08, 0.24, 0.08, järn(), ut=arm - 0.06)
    yta.låda(b, u, z + 0.22, 0.3, 0.22, arm + 0.16, järn())
    yta.låda(b, u, z + 0.3, 0.22, 0.16, arm + 0.12, järn(), ut=0.0)
    yta.låda(b, u, z + 0.42, 0.3, 0.52, 0.3, låga(), ut=arm + 0.02)
    yta.låda(b, u, z + 0.9, 0.16, 0.34, 0.16, låga(), ut=arm + 0.07)


def askylt(b, x, y, z=0.0, bredd=1.1, höjd=1.3):
    """A-formad skylt på marken: två brädor mot varandra med kritfält."""
    for s in (-1, 1):
        a = Vector((x, y + s * 0.22, z + 0.02))
        c = Vector((x, y + s * 0.1, z + höjd))
        b.låda((x, y + s * 0.15, z + 0.04), (bredd, 0.06, höjd),
               mörkt_virke(), Matrix.Translation(a) @ Matrix.Rotation(s * 0.12, 4, "X")
               @ Matrix.Translation(-a))
        b.låda((x, y + s * 0.16, z + 0.16), (bredd * 0.78, 0.04, höjd * 0.72), skyltfält())
    b.låda((x, y, z + höjd - 0.06), (bredd * 0.8, 0.06, 0.08), mörkt_virke())


def pall(b, x, y, z=0.0, s=0.45, h=0.5):
    """Pall/stol med fyra ben och sits — smedens arbetsplats."""
    b.låda((x, y, z + h - 0.08), (s, s, 0.08), mörkt_virke())
    for dx in (-1, 1):
        for dy in (-1, 1):
            b.låda((x + dx * (s / 2 - 0.06), y + dy * (s / 2 - 0.06), z), (0.09, 0.09, h),
                   mörkt_virke())
    b.låda((x, y, z + 0.18), (s * 0.9, s * 0.9, 0.05), mörkt_virke())


def bänk(b, x, y, z=0.0, längd=2.0):
    """Bänk med sits och rygg — vid värdshusets fasad."""
    b.låda((x, y, z + 0.42), (längd, 0.4, 0.08), ljust_virke())
    for s in (-1, 1):
        b.låda((x + s * (längd / 2 - 0.14), y, z), (0.12, 0.36, 0.42), mörkt_virke())
    b.låda((x, y + 0.18, z + 0.5), (längd, 0.08, 0.4), ljust_virke())


def blomma(b, x, y, z, färg):
    """Liten blomma vid fasaden: stjälk och krona."""
    b.låda((x, y, z), (0.05, 0.05, 0.34), tyg_grönt())
    b.låda((x, y, z + 0.3), (0.16, 0.16, 0.12), färg)


def skyltfönster(b, yta, hål, u, z, w, h, stenar=(), karm_mat=None, tak=False):
    """Skyltfönster: öppning genom väggen, glas på halva djupet och varor i smygen innanför.

    Varorna ligger framför glaset men inne i öppningen, alltså i väggens djup — det är det som gör
    att de läses som "i skyltfönstret" och inte som klistermärken på fasaden.
    """
    karm_mat = karm_mat or järn()
    glas = fönster()
    t = yta.tjock
    hål.setdefault(yta.sida, []).append((u - w / 2, z, u + w / 2, z + h))
    for s in (-1, 1):
        yta.låda(b, u + s * (w / 2 - 0.06), z - 0.05, 0.12, h + 0.1, t + 0.06, karm_mat, ut=-t)
    yta.låda(b, u, z + h - 0.06, w - 0.12, 0.12, t + 0.06, karm_mat, ut=-t)
    yta.låda(b, u, z - 0.05, w - 0.12, 0.12, t + 0.06, karm_mat, ut=-t)
    # glaset innerst och en hylla i smygen
    yta.låda(b, u, z + 0.02, w - 0.16, h - 0.1, 0.04, glas, ut=-t * 0.72)
    yta.låda(b, u, z + 0.04, w - 0.2, 0.05, t * 0.62, ljust_virke(), ut=-t * 0.6)
    yta.låda(b, u, z + 0.34, w - 0.2, 0.05, t * 0.5, ljust_virke(), ut=-t * 0.5)
    for i, mat in enumerate(stenar):
        n = max(1, len(stenar))
        sx = u - (w - 0.5) / 2 + (w - 0.5) * (i + 0.5) / n
        yta.låda(b, sx, z + 0.1, 0.16, 0.18, 0.12, mat, ut=-t * 0.34)
        yta.låda(b, sx, z + 0.4, 0.14, 0.16, 0.1, mat, ut=-t * 0.3)
    # spröjs och bleck
    for i in range(1, 3):
        yta.låda(b, u - w / 2 + w * i / 3, z, 0.05, h, 0.06, karm_mat, ut=-t * 0.55)
    yta.låda(b, u, z - 0.14, w + 0.34, 0.07, 0.26, järn())
    if tak:  # litet skiffertak över fönstret, som i bilden
        b.platta(panna_mörk(), [yta.punkt(u - w / 2 - 0.2, z + h + 0.02, 0.02),
                                yta.punkt(u + w / 2 + 0.2, z + h + 0.02, 0.02),
                                yta.punkt(u + w / 2 + 0.2, z + h + 0.14, 0.62),
                                yta.punkt(u - w / 2 - 0.2, z + h + 0.14, 0.62)],
                 Vector((0, 0, 1)), 0.06)


# --- 1. Thread of Destiny (klädståndet) -------------------------------------------------------
def tradet(b):
    """Öppet klädstånd: mörka stolpar bär ett brant skiffertak, plaggen hänger på lina under taket.

    Inga väggar — det är ståndet i referensbilden: tak, stolpar, disk och kläder, inget mer.
    """
    w, d = 12.5, 7.5
    b.delnamn, b.fiber = "sockel", None
    b.plint(w, d, 0.55, block=0.9, kurser=2)
    # trägolv på sockeln
    b.delnamn = "golv"
    n = int(w / 0.26)
    for i in range(n):
        b.fiber = "x"
        b.låda((-w / 2 + w * (i + 0.5) / n, 0, 0.55), (w / n * 0.9, d - 0.7, 0.12),
               ljust_virke())
    # stolpar med stenfot och kapitäl
    b.delnamn, b.fiber = "stolpar", "z"
    xs = (-5.3, -1.8, 1.8, 5.3)
    for x in xs:
        for y in (-d / 2 + 0.45, d / 2 - 0.45):
            b.låda((x, y, 0.55), (0.46, 0.46, 0.14), sten())
            b.låda((x, y, 0.69), (0.3, 0.3, 5.1), mörkt_virke())
            b.låda((x, y, 5.72), (0.46, 0.46, 0.14), mörkt_virke())
        # knästrävor mot syllen
        b.fiber = None
        for y in (-d / 2 + 0.45, d / 2 - 0.45):
            for sx in (-1, 1):
                stång(b, mörkt_virke(), (x + sx * 0.16, y, 5.1), (x + sx * 1.0, y, 5.72),
                      0.16, 0.1, (0, 1, 0))
        b.fiber = "z"
    # syllar, hanbjälkar, kungstolpar, stöttor och åsar
    b.delnamn, b.fiber = "bjälkar", "x"
    z_ply = 5.86
    for y in (-d / 2 + 0.45, d / 2 - 0.45):
        b.låda((0, y, z_ply - 0.26), (w + 0.4, 0.28, 0.26), mörkt_virke())
    for x in xs:
        b.låda((x, 0, z_ply - 0.28), (0.28, d - 0.7, 0.28), mörkt_virke())
        b.fiber = "z"
        b.låda((x, 0, z_ply), (0.24, 0.24, 4.45), mörkt_virke())
        b.fiber = None
        for s in (-1, 1):
            stång(b, mörkt_virke(), (x, s * (d / 2 - 1.1), z_ply + 0.1),
                  (x, s * 0.2, z_ply + 3.3), 0.18, 0.14, (1, 0, 0))
    b.fiber = "x"
    b.låda((0, 0, 10.24), (w + 0.4, 0.22, 0.22), mörkt_virke())
    for s in (-1, 1):
        b.låda((0, s * 2.3, z_ply + 1.6), (w + 0.2, 0.18, 0.18), mörkt_virke())
    # taket
    b.delnamn, b.fiber = "takpannor", None
    sadeltak(b, w, d, z_ply, 4.4, "x", (panna_mörk(), panna_ljus()), utsprång=0.95,
             panbredd=0.24, panrad=0.19)
    # klädstreck under taket
    b.delnamn = "kläder"
    tyger = [tyg_blått(), tyg_rött(), tyg_grönt(), tyg_gult(), tyg_turkost(), tyg_rött(),
             tyg_blått(), tyg_grönt()]
    klädlina(b, -5.0, 5.0, -d / 2 + 1.15, 5.35, tyger)
    # ytterligare en lina längst fram i öppningen — plaggen är ståndets signatur och måste synas
    # utifrån, inte bara inifrån
    klädlina(b, -5.0, 5.0, -d / 2 - 0.35, 4.6,
             [tyg_rött(), tyg_gult(), tyg_blått(), tyg_grönt(), tyg_turkost(),
              tyg_blått(), tyg_rött(), tyg_grönt(), tyg_gult()], höjd=1.0)
    klädlina(b, -5.0, 5.0, -1.2, 5.2, [tyg_turkost(), tyg_gult(), ljust_virke(), tyg_rött(),
                                       tyg_blått(), tyg_grönt()], höjd=0.95)
    klädlina(b, -5.0, 5.0, 1.0, 5.05, [tyg_grönt(), tyg_rött(), tyg_blått(), tyg_turkost()],
             höjd=0.8)
    # valance: fransad tygkant under takfoten, så ståndet läser som marknad och inte som skjul
    b.delnamn = "valance"
    for i in range(14):
        xx = -5.2 + 0.76 * i
        b.låda((xx, -d / 2 - 0.62, 4.34), (0.74, 0.06, 0.5),
               (tyg_rött, tyg_gult, tyg_blått, tyg_grönt)[i % 4]())
        b.låda((xx, -d / 2 - 0.66, 4.02), (0.3, 0.05, 0.3),
               (tyg_gult, tyg_blått, tyg_grönt, tyg_rött)[i % 4]())
    b.delnamn, b.fiber = "disk", None

    # disk och hyllor längs baksidan
    b.delnamn, b.fiber = "disk", "x"
    b.låda((0, 2.75, 0.67), (10.0, 0.5, 1.25), mörkt_virke())
    b.låda((0, 2.75, 1.92), (10.2, 0.62, 0.1), ljust_virke())
    for i in range(9):
        b.låda((-4.4 + 1.1 * i, 2.6, 2.02), (0.62, 0.42, 0.3), ljust_virke())
        b.låda((-4.4 + 1.1 * i, 2.6, 2.32), (0.44, 0.36, 0.22),
               (tyg_rött, tyg_blått, tyg_gult, tyg_grönt, tyg_turkost)[i % 5]())
    b.låda((0, 2.75, 2.5), (10.0, 0.4, 0.14), mörkt_virke())
    for i in range(11):
        b.låda((-4.6 + 0.92 * i, 2.75, 2.64), (0.5, 0.34, 0.5),
               (tyg_blått, tyg_rött, ljust_virke, tyg_grönt, tyg_gult)[i % 5]())
    # skylt i konsol från vänster framstolpe
    b.delnamn, b.fiber = "skylt", None
    b.låda((-5.3, -d / 2 + 0.45 - 0.55, 4.9), (0.1, 1.1, 0.1), järn())
    b.låda((-5.3, -d / 2 - 0.62, 4.2), (0.1, 0.1, 0.72), järn())
    b.låda((-5.3, -d / 2 - 0.72, 2.95), (1.5, 0.1, 1.15), ljust_virke())
    b.låda((-5.3, -d / 2 - 0.79, 3.06), (1.24, 0.04, 0.92), skyltfält())
    for zz in (3.2, 3.5, 3.8):
        b.låda((-5.3, -d / 2 - 0.82, zz), (0.9 - 0.2 * (zz - 3.2), 0.03, 0.14), mässing())
    # tunnor, ved, plankor och kistor intill
    b.delnamn = "rekvisita"
    tunna(b, -4.9, -d / 2 - 1.9, 0, 0.5, 1.25)
    tunna(b, -3.9, -d / 2 - 2.4, 0, 0.44, 1.1, mörkt_virke())
    tunna(b, 5.6, -d / 2 - 1.5, 0, 0.46, 1.15)
    vedhög(b, 4.4, -d / 2 - 2.6, 0, 2.6, 1.3)
    for i in range(9):
        b.fiber = "x"
        b.låda((-2.0, -d / 2 - 1.9, 0.08 + 0.09 * i), (3.4, 0.5, 0.08), ljust_virke())
    b.fiber = None
    kista(b, 1.4, -d / 2 - 1.8, 0, 0.8)
    kista(b, 2.6, -d / 2 - 2.2, 0, 0.66, mörkt_virke())
    pall(b, -1.0, -d / 2 - 1.4, 0, 0.5, 0.55)


# --- 2. Smedjan -------------------------------------------------------------------------------

def ässja(b, yta, hål, u, w=3.8, z0=0.4):
    """Öppen smidesässja: rundbågig öppning rakt genom väggen, murad eldstad med glödbädd.

    Öppningen klipps av `portvalv` (hål genom hela väggtjockleken), eldstaden ligger 2,4 m in i
    huset med glödande botten och sotig ovandel, och ovanför bågen muras en huva i skift med
    sotflagor. Det är glöden innanför som syns utifrån — ingen textur på en plan yta.
    """
    t = yta.tjock
    r = w / 2
    z_spring = 1.55
    z_topp = z0 + z_spring + r
    portvalv(b, yta, hål, u, z0, w, z_spring, r=r, mat=sten())

    # --- eldstaden innanför bågen: förhöjd härd, glödbädd och het bakvägg ----------------------
    inre = -2.45
    hz = z0 + 0.34                                    # härden ligger en sten över tröskeln
    yta.låda(b, u, hz - 0.22, w + 0.6, 0.24, 2.6, sten(), ut=inre + 0.1)      # häll
    yta.låda(b, u, z0 - 0.1, w + 0.2, 0.34, 0.5, sten(), ut=-0.35)            # tröskelsten
    yta.låda(b, u, hz, w + 0.4, 0.95, 0.24, glöd_stark(), ut=inre - 0.22)     # het bakvägg
    yta.låda(b, u, hz + 0.95, w + 0.4, 1.2, 0.24, glöd(), ut=inre - 0.22)
    yta.låda(b, u, hz + 2.15, w + 0.4, max(0.3, z_topp - hz - 2.1), 0.24, sot(), ut=inre - 0.22)
    for s2 in (-1, 1):                                                        # sidomurar, sten för sten
        zz = z0
        rad = 0
        while zz < z_topp - 0.15:
            yta.låda(b, u + s2 * (r + 0.18), zz, 0.34, 0.28, 2.2, sten(), ut=inre + 0.05)
            zz += 0.3
            rad += 1
    # glödbädd på härden: tre lager kol, tätast och hetast närmast öppningen
    slump = random.Random(7)
    for lager, ztopp in enumerate((0.18, 0.36, 0.58)):
        for i in range(110):
            uu = u + slump.uniform(-r + 0.22, r - 0.22)
            dd = slump.uniform(0.0, 1.7)
            pkt = yta.punkt(uu, 0, inre + 0.3 + dd)
            b.låda((pkt.x, pkt.y, hz - 0.02 + ztopp * slump.uniform(0.3, 1.0)),
                   (slump.uniform(0.12, 0.3), slump.uniform(0.12, 0.28),
                    slump.uniform(0.07, 0.18)),
                   glödhet() if lager == 2 or i % 5 == 0 else (glöd() if i % 3 else glöd_stark()))
    # lågan: heta kilar mitt i bädden, framme vid öppningen
    for i, (uu, dd, hh) in enumerate(((-0.75, 0.35, 1.0), (0.0, 0.5, 1.35), (0.8, 0.3, 0.95),
                                      (-0.2, 1.0, 1.1))):
        c = yta.punkt(u + uu, 0, inre + 0.35 + dd)
        b.prisma(glödhet(), (c.x, c.y, hz), 0.3 - 0.03 * i, hh, n=6)

    # --- huva ovanför bågen: murade skift med sotflagor ---------------------------------------
    zz = z_topp + 0.05
    for k in range(6):
        h = 0.34
        bredd = w + 0.9 - 0.12 * k
        antal = max(3, int(bredd / 0.72))
        for i in range(antal):
            uu = u - bredd / 2 + bredd * (i + 0.5) / antal
            sotig = (k < 2 and i in (0, antal - 1)) or (k == 0 and i % 3 == 1)
            yta.låda(b, uu, zz, bredd / antal - 0.02, h - 0.02, 0.34,
                     sot() if sotig else sten(), ut=0.0)
        zz += h
    # sotflagor som rinner uppåt från bågens överkant
    for i in range(7):
        uu = u - r + 0.25 + i * (w - 0.5) / 6
        yta.låda(b, uu, z_topp - 0.35, 0.26, 1.5 + slump.uniform(0, 1.1), 0.05, sot(), ut=0.04)

    # --- stenhärd framför öppningen: enskilda kantstenar och kuller ----------------------------
    for rad in range(3):
        for i in range(14):
            uu = u - 2.3 + 0.34 * i + (0.17 if rad % 2 else 0)
            pkt = yta.punkt(uu, 0, 0.2 + rad * 0.4)
            b.låda((pkt.x, pkt.y, 0.0), (0.32, 0.38, 0.12), sten() if (i + rad) % 4 else mur())
    return z_topp


def smed(b):
    """Smedja: grått stenhus med brant skiffertak, hög skorstensstock till vänster och en
    rundbågig ässja som glöder — plus blåsbälg, städ på stubbe, verktygstavla, kolhög och släckfat."""
    w, d, t = 12.5, 8.5, 0.55
    b.delnamn, b.fiber = "sockel", None
    b.plint(w, d, 0.7, block=1.0, kurser=3)
    ytor = fasad_ytor(w, d, t)
    fram = ytor["fram"]
    hål = {}

    b.delnamn = "dörr"
    dörr(b, fram, hål, -4.3, 0.7, 1.8, 2.9, ljust_virke(), mörkt_virke(), steg=2)
    b.delnamn = "fönster"
    fonster(b, fram, hål, -2.1, 2.7, 1.2, 1.3, sprojs=(2, 3), karm_mat=mörkt_virke())
    for yta in (ytor["vänster"], ytor["höger"]):
        fonster(b, yta, hål, 0.0, 2.9, 1.3, 1.4, sprojs=(2, 3), karm_mat=mörkt_virke())
    fonster(b, ytor["bak"], hål, 0.0, 2.9, 1.6, 1.4, sprojs=(3, 3), karm_mat=mörkt_virke())
    # ässjan: rundbågig öppning rakt genom väggen, murad eldstad med glödbädd och huva
    b.delnamn = "ässja"
    ässja(b, fram, hål, 2.6, w=3.8, z0=0.45)
    # murade väggar
    b.delnamn = "vägg_fram"
    for sida, yta in ytor.items():
        b.delnamn = "vägg_" + sida
        fasadmur(b, yta, 0.7, 6.2, sten(), (0.62, 0.3), hål.get(sida, []))
    b.delnamn, b.fiber = "gavel", None
    gavel(b, w, d, 6.2, 4.4, "x", mur(), tjock=t, brädor=False)
    b.delnamn = "takpannor"
    sadeltak(b, w, d, 6.2, 4.4, "x", (panna_mörk(), panna_ljus()), utsprång=0.8,
             panbredd=0.2, panrad=0.16)
    # HÖG skorstensstock av sten på vänster sida
    b.delnamn = "skorsten"
    skorsten(b, -w / 2 - 0.62, 0.9, 0.0, 11.5, 1.15)
    b.låda((-w / 2 - 0.62, 0.9, 0.0), (1.5, 1.5, 0.35), sten())
    for zz in (2.4, 5.4, 8.4):
        b.låda((-w / 2 - 0.62, 0.9, zz), (1.28, 1.28, 0.16), puts())
    # rökplym ur skorstenshättan: allt tunnare uppåt, driven lite åt sidan av vinden
    b.delnamn = "rök"
    rslump = random.Random(23)
    for i in range(6):
        rr = 0.72 + 0.15 * i
        b.låda((-w / 2 - 0.62 + 0.22 * i + rslump.uniform(-0.1, 0.1), 0.9, 11.75 + 0.45 * i),
               (rr, rr * 0.9, rr * 0.8), rök(0.30 - 0.04 * i))
    b.delnamn = "skorsten"

    # --- STOR dubbel blåsbälg vid ässjan: gångjärn i bakkanten, läderskirt med veck, spak,
    #     järnmunstycke in i eldstaden och en ställning som håller den i höjd med bågen ---
    b.delnamn, b.fiber = "bälg", "x"
    bx, by = -1.15, -d / 2 - 1.45          # munstycket pekar +X, in mot ässjan
    bl, bb, bz = 2.4, 1.35, 1.15           # längd, bredd, underkant
    # ställning
    for sx2 in (-0.95, 0.95):
        for sy2 in (-0.55, 0.55):
            b.låda((bx + sx2, by + sy2, 0.0), (0.16, 0.16, bz - 0.02), mörkt_virke())
        b.låda((bx + sx2, by, bz - 0.16), (0.18, 1.5, 0.18), mörkt_virke())
    # undre och övre lock, öppna 20 grader kring gångjärnet i -X
    b.låda((bx, by, bz), (bl, bb, 0.16), mörkt_virke())
    lock = Matrix.Translation(Vector((bx - bl / 2, by, bz + 0.2))) \
        @ Matrix.Rotation(math.radians(20), 4, "Y") \
        @ Matrix.Translation(-Vector((bx - bl / 2, by, bz + 0.2)))
    b.låda((bx, by, bz + 0.2), (bl, bb, 0.16), mörkt_virke(), lock)
    # läderskirt: veckad på båda långsidor och i framkanten
    for s in (-1, 1):
        b.låda((bx, by + s * (bb / 2 - 0.04), bz + 0.14), (bl - 0.1, 0.08, 0.62), läder())
        for i in range(9):
            b.låda((bx - bl / 2 + 0.12 + i * (bl - 0.24) / 8, by + s * (bb / 2 + 0.01),
                    bz + 0.18), (0.09, 0.07, 0.56 + 0.05 * (i % 2)), läder())
        for i in range(5):                                    # spikrader som håller lädret
            b.låda((bx - bl / 2 + 0.2 + i * (bl - 0.4) / 4, by + s * (bb / 2 + 0.06), bz + 0.62),
                   (0.05, 0.05, 0.05), järn())
    b.låda((bx + bl / 2 - 0.05, by, bz + 0.36), (0.1, bb - 0.05, 0.5), läder())
    # gångjärn och spak med järnhandtag
    for s in (-1, 1):
        b.låda((bx - bl / 2 + 0.02, by + s * 0.4, bz + 0.14), (0.14, 0.3, 0.3), järn())
    spak = Matrix.Translation(Vector((bx - 0.1, by, bz + 1.05))) \
        @ Matrix.Rotation(math.radians(-34), 4, "Y") \
        @ Matrix.Translation(-Vector((bx - 0.1, by, bz + 1.05)))
    b.låda((bx - 0.35, by, bz + 1.05), (1.9, 0.13, 0.13), mörkt_virke(), spak)
    b.låda((bx + 0.55, by, bz + 1.62), (0.34, 0.11, 0.34), ljust_virke(), spak)
    # järnmunstycke mot ässjan + läderbälg mellan munstycke och lock
    for i in range(3):
        b.prisma(järn(), (bx + bl / 2 - 0.1 + 0.22 * i, by, bz + 0.42), 0.16 - 0.025 * i, 0.22, n=10,
                 axel="x")
    b.låda((bx + bl / 2 + 0.2, by, bz + 0.34), (0.5, 0.16, 0.16), läder())

    # --- städ på stubbe med hammare, tänger och hink ---
    b.delnamn = "städ"
    sx, sy = 1.55, -d / 2 - 1.75
    b.prisma(mörkt_virke(), (sx, sy, 0), 0.56, 1.02, n=16)      # stubbe
    for i in range(7):                                          # rotflikar vid marken
        v = 2 * math.pi * i / 7
        b.låda((sx + 0.62 * math.cos(v), sy + 0.62 * math.sin(v), 0.0), (0.3, 0.2, 0.14),
               mörkt_virke())
    b.prisma(järn(), (sx, sy, 1.02), 0.58, 0.08, n=16)
    b.låda((sx, sy, 1.1), (0.62, 0.4, 0.2), järn())             # fot
    b.låda((sx, sy, 1.3), (0.44, 0.3, 0.26), järn())            # midja
    b.låda((sx, sy, 1.56), (1.02, 0.44, 0.26), järn())          # kropp
    b.låda((sx + 0.02, sy, 1.82), (1.06, 0.46, 0.07), järn())   # städbanan
    b.prisma(järn(), (sx + 0.78, sy, 1.8), 0.16, 0.4, n=8, axel="x")   # hornet
    b.låda((sx - 0.42, sy, 1.56), (0.14, 0.3, 0.2), järn())     # hälen
    b.låda((sx + 0.12, sy - 0.02, 1.89), (0.46, 0.1, 0.1), ljust_virke())   # hammarskaft
    b.låda((sx + 0.34, sy - 0.02, 1.86), (0.26, 0.16, 0.18), järn())        # hammarhuvud
    for i in range(3):                                          # tänger på kanten
        b.låda((sx - 0.3 + 0.1 * i, sy + 0.24, 1.7), (0.05, 0.3, 0.06), järn())
        b.låda((sx - 0.3 + 0.1 * i, sy + 0.4, 1.6), (0.05, 0.16, 0.24), järn())
    b.prisma(järn(), (sx - 0.95, sy + 0.5, 0.0), 0.2, 0.34, n=10)
    b.prisma(vatten(), (sx - 0.95, sy + 0.5, 0.28), 0.17, 0.03, n=10)
    pall(b, sx + 0.15, sy - 1.1, 0, 0.6, 0.6)

    # --- verktygstavla på fasaden ---
    b.delnamn = "verktyg"
    b.låda((-1.6, -d / 2 - 0.12, 4.05), (3.4, 0.1, 1.9), mörkt_virke())
    for i in range(9):
        tx = -3.1 + 0.38 * i
        b.låda((tx, -d / 2 - 0.19, 5.55), (0.08, 0.09, 0.14), järn())
        b.låda((tx, -d / 2 - 0.23, 4.3), (0.08, 0.07, 1.15), ljust_virke())
        if i % 2:
            b.låda((tx, -d / 2 - 0.25, 4.22), (0.28, 0.07, 0.15), järn())
        else:
            b.låda((tx, -d / 2 - 0.25, 5.45), (0.32, 0.07, 0.13), järn())
    for i in range(3):
        b.låda((-3.0 + 1.15 * i, -d / 2 - 0.24, 4.2), (0.46, 0.05, 0.1), järn())

    # --- kolhög, släckfat, spann och ved ---
    b.delnamn = "rekvisita"
    slump = random.Random(11)
    for i in range(55):
        b.låda((5.5 + slump.uniform(-0.55, 0.55), -d / 2 - 0.5 + slump.uniform(-0.4, 0.4),
                slump.uniform(0, 0.4)),
               (slump.uniform(0.16, 0.34), slump.uniform(0.16, 0.34), slump.uniform(0.1, 0.26)),
               kol())
    b.låda((5.5, -d / 2 - 0.55, 0.0), (1.5, 1.1, 0.3), sten())    # stenlåda till kolet
    for i in range(5):
        b.låda((4.9 + 0.3 * i, -d / 2 - 1.05, 0.28), (0.28, 0.12, 0.34), sten())
    tunna(b, 4.55, -d / 2 - 2.25, 0, 0.6, 0.9, mörkt_virke())     # släckfat
    b.låda((4.55, -d / 2 - 2.25, 0.72), (0.98, 0.98, 0.05), vatten())
    b.låda((4.55, -d / 2 - 2.25, 0.2), (1.05, 1.05, 0.05), järn())
    b.låda((4.55, -d / 2 - 2.25, 0.62), (1.02, 1.02, 0.05), järn())
    spann(b, 3.55, -d / 2 - 2.35, 0, 0.3, 0.5)
    spann(b, -5.6, -d / 2 - 1.7, 0, 0.28, 0.46)
    vedhög(b, -5.0, -d / 2 - 2.7, 0, 2.6, 1.35)
    tunna(b, 5.0, -d / 2 - 2.3, 0, 0.46, 1.15)
    b.delnamn = "skylt"
    skylt(b, fram, 5.2, 4.6, 1.5, 1.05, emblem="smed", ut=0.7)
    b.delnamn = "lykta"
    lykta(b, fram, -1.5, 3.0, 0.5)


# --- 3. Värdshuset ----------------------------------------------------------------------------
def vardshus(b):
    """Värdshus: krämvit puts med mörkbrunt korsvirke i två våningar, utkragad övervåning,
    brant skiffertak med takkupa, tända spröjsade fönster, lyktor och en skylt med ölmugg."""
    w, d, t = 13.5, 8.5, 0.5
    b.delnamn, b.fiber = "sockel", None
    b.plint(w, d, 0.9, block=1.1, kurser=3)
    ytor = fasad_ytor(w, d, t)
    fram = ytor["fram"]
    hål = {}

    b.delnamn = "dörr"
    dörr(b, fram, hål, -0.6, 0.9, 2.2, 3.3, mörkt_virke(), mörkt_virke(), steg=0)
    trappa(b, fram, -0.6, 0.9, 3.2, 4)
    b.delnamn = "fönster"
    for x in (-4.6, 2.4, 5.2):
        fonster(b, fram, hål, x, 1.75, 1.5, 1.7, sprojs=(3, 3), karm_mat=mörkt_virke())
    for yta in (ytor["vänster"], ytor["höger"]):
        for u in (-1.9, 1.9):
            fonster(b, yta, hål, u, 1.75, 1.4, 1.7, sprojs=(2, 3), karm_mat=mörkt_virke())
    fonster(b, ytor["bak"], hål, 0.0, 1.75, 1.6, 1.6, sprojs=(3, 3), karm_mat=mörkt_virke())
    # bottenvåning: puts + korsvirke
    for sida, yta in ytor.items():
        b.delnamn = "vägg_" + sida
        korsvirke(b, yta, 0.9, 4.7, hål.get(sida, []), stolp=1.15)
    # utkragat bjälklag med synliga bjälkändar
    b.delnamn, b.fiber = "bjälklag", "x"
    b.låda((0, 0, 4.7), (w + 0.7, d + 0.7, 0.32), mörkt_virke())
    n = int(w / 0.72)
    for i in range(n + 1):
        for s in (-1, 1):
            b.låda((-w / 2 + w * i / n, s * (d / 2 + 0.42), 4.42), (0.22, 0.36, 0.3),
                   mörkt_virke())
    # övervåningen, indragen en aning: puts + korsvirke
    wt, dt, tt = w - 0.7, d - 0.7, 0.42
    u_y = fasad_ytor(wt, dt, tt)
    hål2 = {}
    b.delnamn = "fönster"
    for x in (-4.0, -1.4, 1.4, 4.0):
        fonster(b, u_y["fram"], hål2, x, 5.75, 1.15, 1.7, sprojs=(2, 3), karm_mat=mörkt_virke())
    for yta in (u_y["vänster"], u_y["höger"]):
        for u in (-1.7, 1.7):
            fonster(b, yta, hål2, u, 5.75, 1.1, 1.6, sprojs=(2, 3), karm_mat=mörkt_virke())
    fonster(b, u_y["bak"], hål2, 0.0, 5.75, 1.4, 1.7, sprojs=(3, 3), karm_mat=mörkt_virke())
    for sida, yta in u_y.items():
        b.delnamn = "vägg_" + sida
        korsvirke(b, yta, 5.0, 9.0, hål2.get(sida, []), stolp=1.15)
    b.delnamn = "gavel"
    gavel(b, wt, dt, 9.0, 5.6, "x", mörkt_virke(), tjock=tt, brädor=True, bräda=0.34)
    b.delnamn = "takpannor"
    sadeltak(b, wt, dt, 9.0, 5.6, "x", (panna_mörk(), panna_ljus()), utsprång=0.85,
             panbredd=0.24, panrad=0.2)
    # takkupa med fönster på höger sida av framsidan
    b.delnamn = "takkupa"
    kx = 3.3
    b.låda((kx, -3.0, 9.3), (2.9, 2.4, 2.9), mörkt_virke())
    b.låda((kx, -4.28, 9.3), (2.9, 0.2, 2.9), puts())
    sadeltak(b, 2.9, 2.2, 12.2, 0.9, "y", (panna_mörk(), panna_ljus()), utsprång=0.38,
             panbredd=0.22, panrad=0.17)
    b.låda((kx, -4.42, 10.2), (1.7, 0.1, 1.5), karm())
    b.låda((kx, -4.48, 10.3), (1.34, 0.06, 1.24), fönster())
    for i in range(1, 2):
        b.låda((kx - 1.7 / 2 + 1.7 * i / 2, -4.52, 10.3), (0.06, 0.04, 1.24), karm())
    b.låda((kx, -4.52, 10.92), (1.5, 0.04, 0.06), karm())
    b.låda((kx, -4.44, 11.7), (1.9, 0.12, 0.12), mörkt_virke())

    # lyktor på ömse sidor om dörren, skylt med ölmugg, bänk och tunnor
    b.delnamn = "lykta"
    for x in (-2.5, 1.3):
        lykta(b, fram, x, 3.5, 0.55)
    b.delnamn = "skylt"
    skylt(b, fram, 4.5, 6.2, 2.3, 1.55, emblem="kanna", ut=0.95)
    b.delnamn = "skorsten"
    skorsten(b, 3.9, 1.9, 12.6, 2.8, 0.95)
    b.delnamn = "rekvisita"
    tunna(b, -5.7, -d / 2 - 1.7, 0, 0.5, 1.4)
    tunna(b, 5.9, -d / 2 - 1.6, 0, 0.44, 1.2)
    tunna(b, 6.4, -d / 2 - 2.5, 0, 0.38, 1.0, mörkt_virke())
    kista(b, 3.4, -d / 2 - 2.2, 0, 0.85)
    bänk(b, -3.4, -d / 2 - 1.5, 0, 2.4)
    säck(b, -6.4, -d / 2 - 2.4, 0, 0.7)


# --- 4. Porttornet ----------------------------------------------------------------------------
def karta(b):
    """Porttorn i grå mursten: krenelerad topp med tinnar och kragstenar, skyttegluggar med ljus
    stenram, ett riktigt valv rakt genom tornet med kilstenar och anfangsstenar, tunga järnbandade
    portblad och ett upphissat fallgaller — facklor på ömse sidor om porten."""
    w, d, t = 11.5, 8.0, 0.55
    b.delnamn, b.fiber = "sockel", None
    b.plint(w, d, 1.0, block=1.2, kurser=3, kärna=mur_grå())
    ytor = fasad_ytor(w, d, t)
    fram, bak = ytor["fram"], ytor["bak"]
    hål = {}
    murmat = mur_grå()

    # --- porten: rundbåge genom hela tornet ---------------------------------------------------
    b.delnamn = "port"
    portvalv(b, fram, hål, 0.0, 0.2, 3.6, 3.4, r=1.8, mat=murmat)
    portvalv(b, bak, hål, 0.0, 0.2, 3.6, 3.4, r=1.8, mat=murmat)
    # anfangsstenar (springers) där bågen vilar, och en profilerad ring runt bågen
    for s2 in (-1, 1):
        for zz in (3.3, 3.75, 4.2):
            b.låda((s2 * 2.1, -d / 2 - 0.12, zz), (0.42, 0.3, 0.42), puts())
            b.låda((s2 * 2.1, d / 2 + 0.12, zz), (0.42, 0.3, 0.42), puts())
    # valvkammare: sidomurar och valvringar inuti gången
    for s2 in (-1, 1):
        for i in range(11):
            b.låda((s2 * 1.82, -d / 2 + 0.4 + i * 0.72, 0.95), (0.16, 0.7, 4.1), murmat)
    for i in range(9):
        yy = -d / 2 + 0.5 + i * 0.86
        for k in range(7):
            v0, v1 = math.pi * k / 7, math.pi * (k + 1) / 7
            c = Vector((1.7 * math.cos((v0 + v1) / 2) * -1, yy, 4.35 + 1.7 * math.sin((v0 + v1) / 2)))
            b.låda((c.x, c.y, c.z), (0.5, 0.5, 0.36), murmat)
    b.låda((0.0, 0.0, 0.05), (3.7, d - 0.3, 0.12), puts())          # gångens golv
    b.låda((0.0, 0.0, 3.6), (3.5, d - 0.6, 0.3), sot())            # mörkt valv inuti

    # --- portblad: plankor, järnband, spik och ringar (stängda, 1,6 m in i gången) ------------
    b.delnamn = "portblad"
    gy = -d / 2 + 1.6
    # PORTEN STÅR PÅ GLÄNT (M228). Alex: *"Porten får gärna stå lite på glänt, öppen, så man ser att
    # det är en väg ut ur byn"*. Varje blad vrids kring sitt gångjärn (ytterkanten) inåt gången, 35
    # grader, så öppningen syns och vägen ut är fri. `matris` i Bygge.låda vrider varje bräda rätt.
    for s2 in (-1, 1):
        gångjärn = Matrix.Translation((s2 * 1.8, gy, 0.0))
        M = gångjärn @ Matrix.Rotation(s2 * -0.61, 4, 'Z') @ Matrix.Translation((s2 * -1.8, -gy, 0.0))
        for i in range(9):
            b.låda((s2 * 0.9 + (i - 4) * 0.2, gy, 1.0), (0.18, 0.14, 4.6), mörkt_virke(), matris=M)
        for zz in (1.5, 2.6, 3.7, 4.8):
            b.låda((s2 * 0.9, gy - 0.09, zz), (1.8, 0.08, 0.24), järn(), matris=M)
            for i in range(9):                                     # spik
                b.låda((s2 * 0.9 - 0.8 + i * 0.2, gy - 0.14, zz + 0.06), (0.07, 0.05, 0.07), järn(), matris=M)
        b.låda((s2 * 0.5, gy - 0.16, 2.6), (0.09, 0.05, 0.4), järn(), matris=M)

    # --- fallgaller, upphissat i valvet ovanför porten ---------------------------------------
    b.delnamn = "fallgaller"
    for i in range(9):
        b.låda((-1.6 + 0.4 * i, -d / 2 + 0.75, 3.5), (0.12, 0.12, 2.6), järn())
    for i in range(5):
        b.låda((0.0, -d / 2 + 0.75, 3.6 + 0.5 * i), (3.3, 0.12, 0.12), järn())
    for s2 in (-1, 1):                                             # kättingar upp i valvet
        for i in range(6):
            b.låda((s2 * 1.6, -d / 2 + 0.75, 6.0 + 0.34 * i), (0.08, 0.08, 0.2), järn())

    # --- skyttegluggar med ljus stenram, sex på framsidan och fyra per sida -------------------
    b.delnamn = "skytteglugg"
    def glugg(yta, u, zz):
        yta.låda(b, u, zz, 0.3, 1.45, 0.1, glas_mörkt(), ut=0.05)
        yta.låda(b, u, zz - 0.22, 0.76, 0.22, 0.14, puts())
        yta.låda(b, u, zz + 1.45, 0.76, 0.22, 0.14, puts())
        for s2 in (-1, 1):
            yta.låda(b, u + s2 * 0.26, zz, 0.18, 1.45, 0.14, puts())
        yta.låda(b, u, zz + 0.9, 0.5, 0.14, 0.12, puts())          # tvärslå
    for x in (-4.0, -2.3, 2.3, 4.0):
        for zz in (6.6, 9.8, 13.0):
            glugg(fram, x, zz)
            glugg(bak, x, zz)
    for yta in (ytor["vänster"], ytor["höger"]):
        for u in (-2.2, 0.2, 2.2):
            for zz in (5.4, 8.8, 12.2):
                glugg(yta, u, zz)

    # --- muren: mindre block än förut, så skiften syns på en 17 m hög mur --------------------
    for sida, yta in ytor.items():
        b.delnamn = "vägg_" + sida
        fasadmur(b, yta, 1.0, 15.8, murmat, (0.5, 0.24), hål.get(sida, []))
    # hörnkvadrar, omväxlande långa och korta
    b.delnamn = "hörn"
    for sx in (-1, 1):
        for sy in (-1, 1):
            for i in range(34):
                lång = 0.66 if i % 2 else 0.42
                b.låda((sx * (w / 2 - 0.02), sy * (d / 2 - 0.3), 1.0 + i * 0.44),
                       (0.34, lång, 0.4), puts())
    # bälteskurs mitt på tornet
    b.låda((0, 0, 9.4), (w + 0.22, d + 0.22, 0.22), puts())

    # --- kragstenar och krenelering med tinnar ----------------------------------------------
    b.delnamn = "krenelering"
    b.låda((0, 0, 15.8), (w + 0.5, d + 0.5, 0.34), murmat)
    for i in range(14):                                            # kragstenar runt om
        b.låda((-w / 2 + w * (i + 0.5) / 14, -d / 2 - 0.42, 15.4), (0.44, 0.5, 0.4), puts())
        b.låda((-w / 2 + w * (i + 0.5) / 14, d / 2 + 0.42, 15.4), (0.44, 0.5, 0.4), puts())
    for i in range(9):
        b.låda((-w / 2 - 0.42, -d / 2 + d * (i + 0.5) / 9, 15.4), (0.5, 0.44, 0.4), puts())
        b.låda((w / 2 + 0.42, -d / 2 + d * (i + 0.5) / 9, 15.4), (0.5, 0.44, 0.4), puts())
    # tinnar: 5 fram, 5 bak, 4 per sida, var och en murad i tre skift
    for i in range(5):
        for sy in (-1, 1):
            xx = -w / 2 + w * (i + 0.5) / 5
            for k in range(3):
                b.låda((xx, sy * (d / 2 + 0.15), 16.14 + 0.34 * k),
                       (0.92 - 0.04 * k, 0.56, 0.32), murmat if k % 2 else puts())
    for i in range(4):
        for sx in (-1, 1):
            yy = -d / 2 + d * (i + 0.5) / 4
            for k in range(3):
                b.låda((sx * (w / 2 + 0.15), yy, 16.14 + 0.34 * k),
                       (0.56, 0.92 - 0.04 * k, 0.32), murmat if k % 2 else puts())
    b.låda((0, 0, 15.75), (w - 0.6, d - 0.6, 0.24), mörkt_virke())   # skyttegångens golv
    # tak över skyttegången? nej — öppen gång, men en låg bröstning mot gården
    for i in range(3):
        b.låda((0, d / 2 - 1.2 + i * 0.02, 15.99), (w - 1.0, 0.12, 0.9), mörkt_virke())

    # --- fanor, facklor och rekvisita ---------------------------------------------------------
    b.delnamn = "fana"
    for s2, mat in ((-1, tyg_rött), (1, tyg_blått)):
        xx = s2 * 4.6
        b.låda((xx, -d / 2 - 0.16, 8.6), (0.9, 0.08, 0.12), järn())
        b.låda((xx + s2 * 0.5, -d / 2 - 0.22, 5.6), (1.0, 0.06, 3.0), mat())
        b.låda((xx + s2 * 0.5, -d / 2 - 0.26, 5.6), (1.0, 0.04, 0.18), puts())
        for i in range(3):
            b.låda((xx + s2 * 0.22 + s2 * 0.3 * i, -d / 2 - 0.26, 5.3), (0.2, 0.04, 0.34), mat())
    b.delnamn = "fackla"
    for u in (-2.55, 2.55):
        fackla(b, fram, u, 3.9, 0.42)
    b.delnamn = "rekvisita"
    askylt(b, 2.9, -d / 2 - 1.5, 0, 1.0, 1.2)
    tunna(b, -4.6, -d / 2 - 1.4, 0, 0.46, 1.15)
    tunna(b, 4.9, -d / 2 - 1.6, 0, 0.4, 1.0, mörkt_virke())
    kista(b, 4.2, -d / 2 - 2.1, 0, 0.7)

    # --- PORT, INTE TORN (M230) ----------------------------------------------------------------
    # Alex: *"Det skall vara en Gate, en stor port, inte ett torn"*. Geometrin byggs som förut och
    # skalas sedan: bredare (1,55), lägre (0,68) och grundare (0,85). Portöppningen blir då ca 5,6 m
    # bred och 4,2 m hög i en 17,8 m bred, 11,6 m hög port — en stadsport, inte ett vakttorn.
    b.skala(1.55, 0.85, 1.02)

def juvelerare(b):
    """Juvelerarstuga: krämvit puts med mörkbrunt timmer, stort upplyst skyltfönster med
    färgade stenar till vänster, mörk trädörr till höger, litet fönster ovanför och skylt på marken."""
    w, d, t = 9.0, 6.5, 0.45
    b.delnamn, b.fiber = "sockel", None
    b.plint(w, d, 0.75, block=0.95, kurser=3, kärna=sten())
    ytor = fasad_ytor(w, d, t)
    fram = ytor["fram"]
    hål = {}

    b.delnamn = "skyltfönster"
    skyltfönster(b, fram, hål, -1.7, 1.4, 2.9, 1.9,
                 stenar=(tyg_blått(), ljust_virke(), tyg_rött(), tyg_gult(), puts()),
                 karm_mat=järn(), tak=True)
    b.delnamn = "dörr"
    dörr(b, fram, hål, 2.7, 0.75, 1.4, 2.7, mörkt_virke(), mörkt_virke(), steg=1)
    b.delnamn = "fönster"
    fonster(b, fram, hål, 2.7, 3.7, 1.0, 0.8, sprojs=(2, 2), karm_mat=mörkt_virke())
    for yta in (ytor["vänster"], ytor["höger"]):
        fonster(b, yta, hål, 0.0, 1.9, 1.1, 1.4, sprojs=(2, 2), karm_mat=mörkt_virke(),
                luckor=True)
    fonster(b, ytor["bak"], hål, 0.0, 3.4, 1.2, 1.3, sprojs=(2, 2), karm_mat=mörkt_virke())
    for sida, yta in ytor.items():
        b.delnamn = "vägg_" + sida
        korsvirke(b, yta, 0.75, 5.3, hål.get(sida, []), stolp=1.1)
    b.delnamn = "gavel"
    gavel(b, w, d, 5.3, 4.9, "x", mörkt_virke(), tjock=t, brädor=True, bräda=0.32)
    b.delnamn = "takpannor"
    sadeltak(b, w, d, 5.3, 4.9, "x", (panna_mörk(), panna_ljus()), utsprång=0.7,
             panbredd=0.23, panrad=0.18)
    b.delnamn = "skylt"
    b.låda((-1.7, -d / 2 - 0.12, 3.55), (2.9, 0.1, 0.5), mörkt_virke())
    b.låda((-1.7, -d / 2 - 0.18, 3.62), (2.5, 0.04, 0.34), skyltfält())
    skylt(b, fram, 0.2, 4.1, 1.2, 0.85, emblem="juvel", ut=0.55)
    b.delnamn = "skorsten"
    skorsten(b, -3.0, 1.2, 9.2, 2.6, 0.8)
    b.delnamn = "rekvisita"
    askylt(b, 0.9, -d / 2 - 1.3, 0, 0.95, 1.15)
    for i, f in enumerate((tyg_rött(), tyg_gult(), tyg_blått(), puts())):
        for k in range(4):
            blomma(b, -4.2 + 0.35 * k + 0.12 * i, -d / 2 - 0.22, 0.75, f)
    tunna(b, 3.9, -d / 2 - 1.5, 0, 0.36, 0.95)
    b.delnamn = "lykta"
    lykta(b, fram, -3.6, 2.4, 0.42)


# --- 6. Avsluta (grindstugan) -----------------------------------------------------------------
def avsluta(b):
    """Grindstuga i samma stil som värdshuset men mindre: puts, korsvirke, skiffertak, en diskret
    skylt, lykta, bänk och ved."""
    w, d, t = 9.5, 6.5, 0.42
    b.delnamn, b.fiber = "sockel", None
    b.plint(w, d, 0.65, block=0.9, kurser=3)
    ytor = fasad_ytor(w, d, t)
    fram = ytor["fram"]
    hål = {}

    b.delnamn = "dörr"
    dörr(b, fram, hål, 0.2, 0.65, 1.5, 2.7, mörkt_virke(), mörkt_virke(), steg=1)
    b.delnamn = "fönster"
    for x in (-2.7, 3.0):
        fonster(b, fram, hål, x, 1.6, 1.1, 1.4, sprojs=(2, 2), karm_mat=mörkt_virke(),
                luckor=True)
    fonster(b, fram, hål, -1.3, 4.1, 0.9, 0.9, sprojs=(2, 2), karm_mat=mörkt_virke())
    for yta in (ytor["vänster"], ytor["höger"]):
        fonster(b, yta, hål, 0.0, 2.0, 1.1, 1.3, sprojs=(2, 2), karm_mat=mörkt_virke())
    for sida, yta in ytor.items():
        b.delnamn = "vägg_" + sida
        korsvirke(b, yta, 0.65, 5.4, hål.get(sida, []), stolp=1.1)
    b.delnamn = "gavel"
    gavel(b, w, d, 5.4, 4.9, "x", mörkt_virke(), tjock=t, brädor=True, bräda=0.32)
    b.delnamn = "takpannor"
    sadeltak(b, w, d, 5.4, 4.9, "x", (panna_mörk(), panna_ljus()), utsprång=0.7,
             panbredd=0.23, panrad=0.18)
    b.delnamn = "skylt"
    skylt(b, fram, 2.0, 3.6, 1.1, 0.8, emblem="ring", ut=0.5)
    b.delnamn = "skorsten"
    skorsten(b, -2.8, 1.0, 9.4, 2.4, 0.7)
    b.delnamn = "lykta"
    lykta(b, fram, -1.2, 3.4, 0.45)
    b.delnamn = "rekvisita"
    tunna(b, -3.8, -d / 2 - 1.4, 0, 0.4, 1.05)
    spann(b, -3.0, -d / 2 - 1.9, 0, 0.28, 0.46)
    bänk(b, 1.9, -d / 2 - 1.2, 0, 1.8)
    vedhög(b, 4.0, -d / 2 - 2.4, 0, 2.2, 1.2)
    # diskret grind vid sidan: två låga stolpar och en bom
    for x in (4.6, 6.4):
        b.låda((x, -d / 2 - 0.6, 0), (0.24, 0.24, 1.3), mörkt_virke())
        b.låda((x, -d / 2 - 0.6, 1.3), (0.34, 0.34, 0.1), mörkt_virke())
    b.låda((5.5, -d / 2 - 0.6, 0.9), (1.9, 0.14, 0.16), mörkt_virke())


# --- 7. Brunnen -------------------------------------------------------------------------------
def brunn(b):
    """Rundad stenbrunn, 2,4 m i diameter och 1,1 m hög, med trävinsch: stolpar, vindspel med vev,
    rep och hink — som brunnen i referensbildens förgrund."""
    R = 1.2
    b.delnamn, b.fiber = "brunn_ring", None
    b.fot = (2 * R, 2 * R)
    # stenring i sex skift, 24 block per varv, förskjutna ett halvt block
    for k in range(6):
        z = 0.183 * k
        for i in range(24):
            a = 2 * math.pi * (i + 0.5 * (k % 2)) / 24
            c = Vector((1.02 * math.cos(a), 1.02 * math.sin(a), z))
            m = (Matrix.Translation(c) @ Matrix.Rotation(a - math.pi / 2, 4, "Z")
                 @ Matrix.Translation(-c))
            b.låda((c.x, c.y, z), (0.27, 0.3, 0.175), sten() if k % 2 else mur(), m,
                   mål=b.sockel)
    # krönsten: en ring av bredare hällar
    for i in range(18):
        a = 2 * math.pi * i / 18
        c = Vector((1.0 * math.cos(a), 1.0 * math.sin(a), 1.1))
        m = (Matrix.Translation(c) @ Matrix.Rotation(a - math.pi / 2, 4, "Z")
             @ Matrix.Translation(-c))
        b.låda((c.x, c.y, 1.1), (0.42, 0.42, 0.12), puts(), m, mål=b.sockel)
    # vatten i botten och en mörk schaktvägg under ringen
    b.prisma(vatten(), (0, 0, 0.42), 0.9, 0.03, n=24)
    b.prisma(glas_mörkt(), (0, 0, 0.02), 0.9, 0.4, n=24, lock=False)
    # två stolpar med knästrävor och en överliggare
    b.delnamn, b.fiber = "brunn_spel", "z"
    for s in (-1, 1):
        b.låda((s * 0.95, 0, 1.16), (0.22, 0.22, 1.24), mörkt_virke())
        b.låda((s * 0.95, 0, 1.14), (0.3, 0.3, 0.1), mörkt_virke())
        b.låda((s * 0.95, 0, 2.36), (0.3, 0.3, 0.1), mörkt_virke())
        b.fiber = None
        for sy in (-1, 1):
            b.platta(mörkt_virke(), [(s * 0.95, sy * 0.08, 2.0), (s * 0.95, sy * 1.0, 1.2),
                                     (s * 0.95, sy * 1.0, 1.34), (s * 0.95, sy * 0.08, 2.14)],
                     Vector((s, 0, 0)), 0.12)
        b.fiber = "z"
    b.fiber = "x"
    b.låda((0, 0, 2.36), (2.2, 0.26, 0.2), mörkt_virke())
    # vindspel: trumma med rep, lager och vev
    b.fiber = None
    b.prisma(mörkt_virke(), (-0.98, 0, 1.95), 0.19, 1.96, n=16, axel="x")
    for i in range(7):
        b.prisma(rep(), (-0.62 + 0.17 * i, 0, 1.95), 0.235, 0.12, n=16, axel="x")
    b.prisma(järn(), (-1.0, 0, 1.95), 0.11, 0.22, n=8, axel="x")
    b.prisma(järn(), (0.82, 0, 1.95), 0.11, 0.26, n=8, axel="x")
    b.prisma(järn(), (1.2, 0, 1.95), 0.055, 0.32, n=8, axel="x")
    b.låda((1.48, 0, 1.38), (0.09, 0.09, 0.62), järn())
    b.låda((1.48, 0, 1.38), (0.36, 0.09, 0.09), järn())
    b.prisma(mörkt_virke(), (1.64, 0, 1.28), 0.06, 0.46, n=8, axel="y")
    # rep ned till hinken
    b.delnamn = "rep"
    for i in range(8):
        b.låda((0.03, 0.0, 1.62 - 0.16 * i), (0.05, 0.05, 0.16), rep())
    # hink på repet
    b.delnamn = "hink"
    spann(b, 0.03, 0.0, 0.66, 0.3, 0.5, ljust_virke())
    b.låda((0.03, 0.0, 0.66), (0.42, 0.42, 0.04), vatten())
    b.låda((0.03, 0.0, 1.14), (0.46, 0.05, 0.05), järn())
    b.låda((0.03, 0.0, 0.92), (0.05, 0.05, 0.26), järn())
    # en spann och en kanna vid foten
    b.delnamn = "rekvisita"
    spann(b, 1.6, -1.45, 0, 0.26, 0.45)
    b.prisma(lera(), (-1.55, -1.25, 0), 0.16, 0.4, n=10)
    b.prisma(lera(), (-1.55, -1.25, 0.4), 0.09, 0.14, n=10)
    b.låda((-1.55, -1.25, 0.5), (0.24, 0.06, 0.06), lera())


BYGGNADER = [
    ("tradet", tradet),
    ("smed", smed),
    ("vardshus", vardshus),
    ("karta", karta),
    ("juvelerare", juvelerare),
    ("avsluta", avsluta),
    ("brunn", brunn),
]

# vad som skiljer husen åt, för README:n (siffrorna där skrivs ur modellerna, inte härifrån)
DELAR = {
    "tradet": "öppet klädstånd: åtta stolpar med knästrävor, sparrar och åsar, brant skiffertak, "
              "klädstreck med plagg i fem färger, disk med tygrullar, tunnor, ved och plankor",
    "smed": "murat grått stenhus med brant skiffertak, hög skorstensstock, rundbågig ässja med "
            "glödbädd och kåpa, stor blåsbälg med spak och läder, städ på stubbe med hammare, "
            "verktygstavla, pall, kolhög, släckfat, spann och ved",
    "vardshus": "krämvit puts med mörkbrunt korsvirke i två våningar, utkragad övervåning med "
                "bjälkändar, brant skiffertak med takkupa och fönster, tända spröjsade fönster, "
                "lyktor, skylt med ölmugg, bänk och tunnor",
    "karta": "massivt porttorn av stora stenblock, krenelerad topp med kragstenar, smala "
             "skyttegluggar, rundbågig port med järnbandade träportar, fallgaller, facklor, "
             "A-skylt och tunnor",
    "juvelerare": "puts med mörkbrunt korsvirke, stort upplyst skyltfönster med färgade stenar "
                  "och skiffertak över, mörk trädörr, litet fönster ovanför, A-skylt, blommor",
    "avsluta": "puts och korsvirke som värdshuset men mindre, skiffertak, diskret skylt, lykta, "
               "bänk, tunnor och ved samt en låg grind",
    "brunn": "rundad stenring i sex skift med krönsten, trästolpar med knästrävor, vindspel med "
             "vev, rep och hink, vatten i botten",
}

# måtten i uppdraget: (grund b, grund d, höjd), trianglar; totalen får sticka ut 2,5 m
KRAV_HUS = (9.0, 14.0, 6.0, 9.0, 10.0, 18.0, 20000, 250000)
KRAV_BRUNN = (2.2, 2.7, 2.2, 2.7, 2.2, 2.9, 2500, 40000)


def tom_scen():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bygg_byggnad(id, fn):
    koll = bpy.data.collections.new("by_" + id)
    bpy.context.scene.collection.children.link(koll)
    b = Bygge()
    fn(b)
    b.mesha(koll, id)
    return koll, b


def mät(koll):
    """(trianglar, total bbox, grundens bbox) för en samling.

    Grunden (sockeln/stenringen) är byggnadens FOTPRINT; takutsprång, skyltar, trappor och ässjor
    sticker ut utanför den, så måtten i uppdraget mäts mot grunden och höjden mot totalen.
    """
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


# --- granskningsrendering ---------------------------------------------------------------------
def scensätt():
    """Kamera, tre ljus, markplan och en neutral bakgrund för turnaround-bilderna."""
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x = s.render.resolution_y = 900
    s.render.film_transparent = False
    try:
        s.eevee.taa_render_samples = 24
    except AttributeError:
        pass
    s.view_settings.view_transform = "AgX"
    värld = bpy.data.worlds.new("granskning")
    värld.use_nodes = True
    bg = värld.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.2, 0.23, 0.3, 1.0)  # skymningshimmel som i byn
    bg.inputs[1].default_value = 0.8
    s.world = värld
    # markplan: visar att huset står på marken och ger en skugga att läsa siluetten mot
    mark = bpy.data.meshes.new("mark")
    mark.from_pydata([(-40, -40, -0.002), (40, -40, -0.002), (40, 40, -0.002),
                      (-40, 40, -0.002)], [], [(0, 1, 2, 3)])
    mark.update()
    mark.materials.append(material("mark", färg=(58, 56, 52), grovhet=1.0))
    bpy.context.scene.collection.objects.link(bpy.data.objects.new("mark", mark))
    for typ, plats, energi, storlek in (("AREA", (9, -14, 14), 2300, 9),
                                        ("AREA", (-12, -6, 8), 1100, 10),
                                        ("AREA", (0, 12, 10), 800, 12)):
        l = bpy.data.lights.new("ljus", typ)
        l.energy = energi
        l.size = storlek
        ob = bpy.data.objects.new("ljus", l)
        ob.location = plats
        bpy.context.scene.collection.objects.link(ob)
        rikt = Vector((0, 0, 5)) - Vector(plats)
        ob.rotation_euler = rikt.to_track_quat("-Z", "Y").to_euler()
    kam = bpy.data.objects.new("kamera", bpy.data.cameras.new("kamera"))
    kam.data.lens = 50
    bpy.context.scene.collection.objects.link(kam)
    s.camera = kam
    return kam


def rendera(id, kam, total, vyer=((-38, 10), (6, 5))):
    """Två vyer per modell: trekvarts framifrån och rakt framifrån (den senare att jämföra med
    referensbilden), till granskning/<id>_<n>.png."""
    GRANSKA.mkdir(parents=True, exist_ok=True)
    mål = Vector((0, 0, total.z * 0.46))
    r = 1.85 * max(total.x, total.y, total.z) + 2.0
    for i, (az, el) in enumerate(vyer):
        a, e = math.radians(az), math.radians(el)
        kam.location = (r * math.cos(e) * math.sin(a) * -1,
                        -r * math.cos(e) * math.cos(a),
                        mål.z + r * math.sin(e))
        kam.rotation_euler = (mål - Vector(kam.location)).to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.render.filepath = str(GRANSKA / ("%s_%d.png" % (id, i + 1)))
        bpy.ops.render.render(write_still=True)


def bygg():
    tom_scen()
    UT.mkdir(parents=True, exist_ok=True)
    kam = scensätt()
    rader, uv_stat = [], []
    for i, (id, fn) in enumerate(BYGGNADER):
        koll, b = bygg_byggnad(id, fn)
        for ob in koll.objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = koll.objects[0]
        bpy.ops.export_scene.gltf(filepath=str(UT / (id + ".glb")), export_format="GLB",
                                  use_selection=True)
        for ob in koll.objects:
            ob.select_set(False)
        uv_stat.extend((id, d, mn, yta) for (d, mn, yta) in b.uv_stat)
        trianglar, total, bas = mät(koll)
        rader.append((id, trianglar, len(koll.objects), total, bas,
                      sorted({m.name for ob in koll.objects
                              for m in ob.data.materials if m}), b.uv_täthet, i))
        print("  %-11s %7d tri  %2d noder  grund %.1f x %.1f m  högst %.1f m  UV %.3f varv/m"
              % (id, trianglar, len(koll.objects), bas.x, bas.y, total.z, b.uv_täthet))
        # bara den här modellen syns i granskningsbilden: grannhusen ligger kvar i scenen
        for k in bpy.data.collections:
            k.hide_render = k.name != ("by_" + id)
        rendera(id, kam, total)
        # raden i .blend-filen: 16 m mellan husen, byggt på origo under exporten ovan
        for ob in koll.objects:
            ob.location.x = (i - (len(BYGGNADER) - 1) / 2) * 26.0
    for im in bpy.data.images:
        if not im.packed_file:
            im.pack()
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    skriv_readme(rader, uv_stat)
    print("skrev %d GLB till %s och %s" % (len(rader), UT.relative_to(ROT), BLEND.relative_to(ROT)))


def skriv_readme(rader, uv_stat):
    """README:n skrivs av bygget, så mått, polygontal och UV-ytor inte kan glida ifrån modellerna."""
    text = ["# Byns byggnader i 3D", "",
            "En GLB per byggnad och en för brunnen, byggda av `tools/gen_by_hus3d.py` ur spelets",
            "egna materialrutor, de nedladdade mapseten i `texturer/` och platta palettfärger.",
            "Formerna följer `game/assets/by2d/byn_referens.png`. Byggs om med", "",
            "```", "blender --background --python tools/gen_by_hus3d.py",
            "blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät",
            "```", "",
            "Origo ligger på markplanet mitt i varje byggnad, +Z upp i Blender (GLB-exporten gör Y-up).",
            "Fasaden ligger åt -Y i Blender, alltså +Z i GLB:n. Enheter är meter. Grunden (sockeln)",
            "är fotavtrycket; takutsprång, skyltar, trappor och ässjor sticker ut utanför den.",
            "Samlingsfilen med alla sju på rad är `assets/by_hus_3d.blend` (utanför git, samma regel",
            "som repots övriga .blend-filer). Turnaround-bilder ligger i `granskning/`.", "",
            "Husen är byggda i bynivå: 9-14 m breda, 6-9 m djupa och 10-18 m höga (porttornet",
            "högst, värdshuset störst av husen). Varje hus exporteras som en mesh per material",
            "(Noder nedan), inte en nod per spik. `--kolla` kräver 20 000-250 000 trianglar per hus",
            "(brunnen 2 500-40 000), grund inom måtten ovan, högsta punkt 10-18 m och högst 20 MB",
            "per fil.", "",
            "| Modell | Grund b × d (m) | Högsta punkt (m) | Trianglar | Noder | UV-varv/m | Texturer |",
            "|---|---|---|---|---|---|---|"]
    for id, trianglar, noder, total, bas, matar, tath, i in rader:
        texturer = ", ".join(m for m in matar if m not in (
            "glöd", "fönster", "lyktglas", "tyg_rött", "tyg_blått", "tyg_grönt", "tyg_gult",
            "tyg_turkost", "glas_mörkt", "skyltfält", "takpanna_mörk", "takpanna_ljus",
            "spån_mörk", "spån_ljus", "tegel", "kol", "mässing", "vatten", "lera",
            "fönsterkarm", "rep", "halm", "låga", "glöd_stark"))
        text.append("| `%s.glb` | %.1f × %.1f | %.1f | %d | %d | %.3f | %s |"
                    % (id, bas.x, bas.y, total.z, trianglar, noder, tath, texturer))
    text += ["", "Varje modell är ihopsatt av riktiga byggdelar:", ""]
    for id, *_ in rader:
        text.append("- **%s** — %s" % (id, DELAR[id]))
    text += ["",
             "## UV-kartor", "",
             "Varje mesh har två UV-kartor:", "",
             "- **`UVMap`** (TEXCOORD_0) — unik, packad 0-1 utan överlapp, med några millimeters",
             "  marginal mellan öarna. En gemensam texteldensitet för hela byggnaden: den största",
             "  materialgruppen sätts till 0,94 av kartan, resten får samma skala. Det är den här",
             "  kartan man byter till en egen målad textur på. Dolda baksidor (insidan av en",
             "  väggkärna innanför murskinnet) delar UV-yta med framsidan — de syns aldrig, och",
             "  det sparar atlasutrymme; alla synliga ytor har egna icke överlappande öar.",
             "- **`Upprepning`** (TEXCOORD_1) — löpande projektion per byggdel, den spelets sömlösa",
             "  rutor sitter på via en UV Map-nod i materialet. Virke projiceras med u längs",
             "  fiberriktningen, så ådringen följer stockens längd även när den ligger ner.",
             "", "Densiteten i `UVMap` är densamma i alla delar av en byggnad men skiljer sig mellan",
             "byggnaderna (ett stort tak kräver mer UV-yta). Antalet pixlar per meter är varv/m ×",
             "atlasbredd:", "",
             "| Modell | Varv/m | px/m vid 2048² | px/m vid 8192² |", "|---|---|---|---|"]
    for id, _tri, _nod, _tot, _bas, _m, tath, _i in rader:
        text.append("| `%s` | %.3f | %d | %d |" % (id, tath, tath * 2048, tath * 8192))
    text += ["",
             "För att måla en egen textur räcker alltså inte 2048² för husen; UV-ytan är byggd för en",
             "atlas på 8-16 k. Den löpande kartan, som materialen använder i dag, ligger på 512 px/m:",
             "0,5 varv/m för de inkopierade 1024-bilderna (2 m per ruta) och 0,45 varv/m för spelets",
             "256-rutor (en ruta per ~2,2 m, samma tegelskala som referensen).", "",
             "### Del → material → UV-yta", "",
             "UV-ytan är den unika kartans area för delen, i m² (flera öar per del när delens ytor",
             "pekar åt olika håll).", "",
             "| Del | Material | UV-yta (m²) | Öar |", "|---|---|---|---|"]
    agg: dict = {}
    for (id, delnamn, mn, yta) in uv_stat:
        nyckel = (delnamn, mn)
        gammal = agg.get(nyckel, (0.0, 0))
        agg[nyckel] = (gammal[0] + yta, gammal[1] + 1)
    for (delnamn, mn), (yta, antal) in sorted(agg.items(), key=lambda q: (-q[1][0], q[0])):
        text.append("| `%s` | `%s` | %.2f | %d |" % (delnamn, mn, yta, antal))
    text += ["", "Material utan textur (platta färger i byns palett): takpannor, spån, tegel, glöd,",
             "låga, fönster, lyktglas, tyg_rött, tyg_blått, tyg_grönt, tyg_gult, tyg_turkost,",
             "glas_mörkt, skyltfält, mässing, kol, vatten, lera, fönsterkarm, rep, halm.", "",
             "## Texturer", "",
             "| Material i GLB | Bild |", "|---|---|"]
    for namn in sorted(TEXTUR):
        text.append("| `%s` | `%s` |" % (namn, TEXTUR[namn]))
    text += ["", "Två sorters ytor används:", "",
             "- **`game/assets/tiles/material/`** — spelets egna 256-rutor (puts, tegel, murgröna,",
             "  glöd, bambu m.m.), satta på den löpande UV-kartan med 0,45 varv/m så en ruta täcker",
             "  ~2,2 m — samma tegelskala som referensbilden.",
             "- **`texturer/`** — 16 rutor utklippta ur de nedladdade mapseten med",
             "  `tools/klipp_texturer.py`: kläd-, läder- (T_Trim_Props), trä- (T_Trim_Furniture),",
             "  järn- (T_Trim_Metal) och mässingsytor ur Fantasy Props MegaKit samt gråsten ur",
             "  Stylized Nature MegaKit. Alla fem har BaseColor + Normal + ORM (R = AO, G = grovhet,",
             "  B = metall) kopplade; GLB:n bär alltså även `occlusionTexture` och",
             "  `metallicRoughnessTexture`. Texeldensiteten är 512 px/m (varv/m = 512 / bildbredd),",
             "  så en 256-ruta upprepar sig var 0,5 m.", "",
             "Bara de atlasrutor som faktiskt används är inkopierade, och varje ruta är vald för",
             "låg kantmismatch (se `mät` i klippverktyget) så den kan repeteras utan synlig söm.",
             "Ingen preview-bild eller skärmdump används som textur, och",
             "`game/assets/by2d/`-bilderna är bara tittade på.", ""]
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
        mb = p.stat().st_size / (1024 * 1024)
        krav = KRAV_BRUNN if id == "brunn" else KRAV_HUS
        b0, b1, d0, d1, h0, h1, t0, t1 = krav
        tom_scen()
        bpy.ops.import_scene.gltf(filepath=str(p))
        trianglar, total, bas = mät(bpy.context.scene.collection)
        # UV: två kartor per mesh, den unika inom 0-1, och ingen yta helt utan UV
        uv_ok, uv_lager, utan_uv = True, set(), 0
        for ob in bpy.context.scene.collection.objects:
            if ob.type != "MESH":
                continue
            me = ob.data
            if len(me.uv_layers) < 2:
                uv_ok = False
            uv_lager.add("%d kartor" % len(me.uv_layers))
            unik = me.uv_layers[0].data if me.uv_layers else None
            if unik is not None:
                for q in unik:
                    if not (-0.001 <= q.uv[0] <= 1.001 and -0.001 <= q.uv[1] <= 1.001):
                        utan_uv += 1
        if utan_uv:
            uv_ok = False
        # Totalen får sticka ut högst 5 m utanför grunden: takutsprång, skyltar, trappor och
        # vedtravar står utanför sockeln, men en detalj 10 m bort är felplacerad.
        ok = (mb < 20 and t0 <= trianglar <= t1 and uv_ok
              and b0 - 0.05 <= bas.x <= b1 + 0.05 and d0 - 0.05 <= bas.y <= d1 + 0.05
              and h0 - 0.05 <= total.z <= h1 + 0.05
              and total.x <= bas.x + 5.0 and total.y <= bas.y + 5.0)
        print("%s %-11s %5.1f MB %7d tri  grund %.1f x %.1f  totalt %.1f x %.1f x %.1f m"
              "  UV %s  %d material"
              % ("ok  " if ok else "FEL ", id, mb, trianglar, bas.x, bas.y,
                 total.x, total.y, total.z, "/".join(sorted(uv_lager)), len(bpy.data.materials)))
        if utan_uv:
            print("     %d UV-hörn utanför 0-1" % utan_uv)
        fel += 0 if ok else 1
    print("--- %s" % ("alla sju laddar" if not fel else "%d fel" % fel))
    return fel


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--kolla" in argv:
        sys.exit(1 if kolla() else 0)
    bygg()


if __name__ == "__main__":
    main()
