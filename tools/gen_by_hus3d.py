"""Byns sex byggnader som lågpolymodeller (3D), ur spelets egna materialrutor.

    blender --background --python tools/gen_by_hus3d.py              # bygg + exportera GLB + rendera
    blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät

VARFÖR ETT EGET NAMN: `tools/gen_by_hus.py` klipper 2D-husen ur `byn.png` och körs av testsviten
(`tools/test.sh`, `game/tests/test_by_utklippt.gd`). Den här filen är 3D-modellerna och rör inte den.

FORMSPRÅKET: bara rätblock och plan — inga rundningar, inga avfasningar. Samma kantiga voxel-/
pixelkänsla som resten av spelets grafik (jämför `game/assets/by2d/byn_vc.png`): husen byggs av
samma beståndsdelar som referensbilderna visar, inte av en slät låda med en textur på.
Timmerstockar i skift, puts med synliga bjälkar och snedsträvor, takpannor/spån i förband,
fönster med karm, spröjs och bleck, dörr med gångjärn och handtag, skylt i konsol, skorsten.

ORIGO ligger på markplan, mitt i byggnaden, +Z upp. FASADEN LIGGER ÅT -Y i Blender, vilket blir
+Z i GLB:n (Blender -Y -> glTF +Z vid exporten); spelet roterar huset så fasaden pekar mot torget
och den konventionen är oförändrad — rör den inte.

TEXTURERNA är spelets egna (`game/assets/tiles/material/*.png`), aldrig något externt. UV-mappningen
är plan per yta (box-projektion) med `UPPREPNING` varv per meter, så en 256-pixlaruta täcker ~2,2 m
oavsett vilken byggnad den sitter på — samma tegelskala i hela byn. Små snickerier (takpannor,
fönsterbleck, gångjärn, glöd) är platta färger i byns palett; textur på en 30 cm panna blir bara
grus.

GEOMETRIN samlas per material i en `Bygge` och blir EN mesh per material — inte en nod per spik.
Det håller GLB:n på ~12 noder per hus i stället för ~800 och gör att Godot slipper 800 draw calls
per hus i byn. Sockeln ligger dock i sin egen mesh (`<id>_sockel`) eftersom `--kolla` mäter
fotavtrycket på den.

`--kolla` läser tillbaka varje GLB i en tom scen: filen måste finnas, väga över 1 kB, importera,
ha mesh-ytor, ligga på 3 000-15 000 trianglar och inom måtten i uppdraget (grund 4-6 m bred,
3-4 m djup, 4-8 m hög). Utan det är "exporterad" bara ett antagande.
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
GRANSKA = UT / "granskning"
# .blend är en binär arbetsfil; repot har samma regel för assets/ (se .gitignore). Spelet läser GLB.
BLEND = ROT / "assets" / "by_hus_3d.blend"

## Texturvarv per meter. 0,45 ger en 256-pixlaruta på ~2,2 m: en stenrad blir ~25 cm hög, vilket är
## läsbart på 5-8 m hus på det avstånd byn ses (mätt mot byn_vc.png:s tegelskala).
UPPREPNING = 0.45

MAT: dict[str, bpy.types.Material] = {}
TEXTUR: dict[str, str] = {}  # materialnamn -> rutan i game/assets/tiles/material/


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


# --- materialnycklar -------------------------------------------------------------------------
def sten():         return material("sten", "ancient_stone")
def mur():          return material("mur", "fortified_stone_bricks")
def puts():         return material("puts", "chiseled_marble", grovhet=0.95)
def mörkt_virke():  return material("mörkt_virke", "wooden_palisades")
def ljust_virke():  return material("ljust_virke", "woven_bamboo", grovhet=0.9)
def skiffer():      return material("skiffer", "polished_obsidian_wall", grovhet=0.7)
def järn():         return material("järn", "corroded_metal", metall=0.7, grovhet=0.55)
def glöd():         return material("glöd", "magma_rock", utstrålning=1.6)
def murgröna():     return material("murgröna", "wall_with_ivy")
def fönster():      return material("fönster", färg=(238, 186, 92), utstrålning=1.1, grovhet=0.4)
def karm():         return material("fönsterkarm", färg=(26, 22, 32), grovhet=0.8)
def lyktglas():     return material("lyktglas", färg=(240, 156, 60), utstrålning=3.0, grovhet=0.3)
def tyg_rött():     return material("tyg_rött", färg=(168, 48, 40), grovhet=0.95)
def tyg_blått():    return material("tyg_blått", färg=(58, 96, 116), grovhet=0.95)
def glas_mörkt():   return material("glas_mörkt", färg=(12, 10, 16), grovhet=0.5)
def skyltfält():    return material("skyltfält", färg=(44, 38, 52), grovhet=0.9)
# tak: skiffergrå pannor i två toner (förbandet syns som ett schack), spån i två trätoner
def panna_mörk():   return material("takpanna_mörk", färg=(52, 62, 70), grovhet=0.8)
def panna_ljus():   return material("takpanna_ljus", färg=(70, 82, 90), grovhet=0.8)
def spån_mörk():    return material("spån_mörk", färg=(64, 48, 36), grovhet=0.95)
def spån_ljus():    return material("spån_ljus", färg=(84, 64, 46), grovhet=0.95)
def tegel():        return material("tegel", färg=(112, 66, 50), grovhet=0.9)
def kol():          return material("kol", färg=(24, 22, 26), grovhet=0.95)
def mässing():      return material("mässing", färg=(176, 136, 62), metall=0.8, grovhet=0.4)
def vatten():        return material("vatten", färg=(30, 52, 64), grovhet=0.25)
def lera():         return material("lera", färg=(120, 88, 66), grovhet=0.95)


# --- bygget ----------------------------------------------------------------------------------
class Bygge:
    """Geometri insamlad per material; blir en mesh per material vid `mesha`."""

    def __init__(self):
        self.delar: dict = {}   # materialnamn -> (hörn, ytor)
        self.sockel: dict = {}  # sockeln får egen mesh så fotavtrycket kan mätas
        self.fot = (4.0, 3.0)   # (bredd, djup) sätts av plint()

    def _lägg(self, mål, mat, hörn, ytor):
        v, f = mål.setdefault(mat.name, ([], []))
        n = len(v)
        v.extend(Vector(p) for p in hörn)
        f.extend(tuple(n + i for i in y) for y in ytor)

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
        self._lägg(mål if mål is not None else self.delar, mat, hörn,
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
        self._lägg(mål if mål is not None else self.delar, mat, p, [(0, 1, 2, 3)])

    def tri(self, mat, punkter, ut, mål=None):
        """En triangel, vänt så normalen pekar åt `ut` (samma skäl som `skiva`)."""
        p = [Vector(q) for q in punkter]
        n = (p[1] - p[0]).cross(p[2] - p[0])
        if n.length < 1e-9:
            return
        if n.dot(Vector(ut)) < 0:
            p = p[::-1]
        self._lägg(mål if mål is not None else self.delar, mat, p, [(0, 1, 2)])

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

    def mesha(self, koll, namn):
        """Skriv ut geometrin som en mesh per material i samlingen `koll`.

        Den första sockelmeshen behåller namnet `<id>_sockel`; `mät` letar upp just den för att få
        fotavtrycket, och skiftstenarna runt om får egna namn så de inte förväxlas med kärnan.
        """
        obs = []
        for etikett, mål in (("sockel", self.sockel), (None, self.delar)):
            for i, (matnamn, (v, f)) in enumerate(mål.items()):
                me = bpy.data.meshes.new("%s_%s" % (namn, matnamn))
                me.from_pydata(v, [], f)
                me.update()
                uv = me.uv_layers.new(name="UVMap")
                for p in me.polygons:
                    axel = max(range(3), key=lambda i: abs(p.normal[i]))
                    u_axel, v_axel = ((1, 2), (0, 2), (0, 1))[axel]
                    for li in p.loop_indices:
                        co = me.vertices[me.loops[li].vertex_index].co
                        uv.data[li].uv = (co[u_axel] * UPPREPNING, co[v_axel] * UPPREPNING)
                me.materials.append(MAT[matnamn])
                if etikett == "sockel" and i == 0:
                    objnamn = "%s_sockel" % namn
                elif etikett:
                    objnamn = "%s_fot_%s" % (namn, matnamn)
                else:
                    objnamn = "%s_%s" % (namn, matnamn)
                ob = bpy.data.objects.new(objnamn, me)
                koll.objects.link(ob)
                obs.append(ob)
        return obs


# --- byggdelar -------------------------------------------------------------------------------
def stockvägg(b, w, d, z0, z1, mat, höjd=0.26, ut=0.03, överlapp=0.16):
    """Vägg av liggande timmerstockar i skift, med knutarna sticker ut i hörnen."""
    z, i = z0, 0
    while z < z1 - 1e-4:
        h = min(höjd * 0.94, z1 - z)
        # långsidor: stockarna löper i x och sticker ut över hörnen
        for y in (-d / 2 - ut + 0.07, d / 2 + ut - 0.07):
            b.låda((0, y, z), (w + 2 * överlapp, 0.15, h), mat)
        # gavlar: stockarna löper i y, indragna en aning varannat varv (skiftet syns i knuten)
        inskjut = 0.02 if i % 2 else -0.02
        for x in (-w / 2 + inskjut, w / 2 - inskjut):
            b.låda((x, 0, z), (0.15, d, h), mat)
        z += höjd
        i += 1
    # knutändar: korta stockbitar som sticker ut utanför hörnen, två per hörn och varv
    for x in (-w / 2 - överlapp / 2, w / 2 + överlapp / 2):
        for y in (-d / 2 - ut, d / 2 + ut):
            z = z0 + (0.26 if ((x > 0) != (y > 0)) else 0.0)
            b.låda((x, y, z), (0.22, 0.22, 0.2), mat)


def puts_vägg(b, w, d, z0, z1, mat_puts=None, mat_ram=None, stolp=1.35):
    """Putsad vägg med synligt korsvirke: stolpar, bjälkar och snedsträvor i fasaden.

    Strävorna sitter i ytterfacken och lutar inåt mot mitten — det är korsvirket som gör att
    huset läses som medeltida bygge i stället för som en låda.
    """
    mat_puts = mat_puts or puts()
    mat_ram = mat_ram or mörkt_virke()
    b.låda((0, 0, z0), (w, d, z1 - z0), mat_puts)
    y = -d / 2 - 0.05
    # bjälkar: syll, mittband, huvudband
    for z in (z0, (z0 + z1) / 2 - 0.09, z1 - 0.18):
        b.låda((0, y, z), (w, 0.1, 0.18), mat_ram)
    # stolpar
    n = max(2, int(round(w / stolp)))
    for i in range(n + 1):
        x = -w / 2 + w * i / n
        b.låda((x, y, z0), (0.16, 0.1, z1 - z0), mat_ram)
    # snedsträvor i ytterfacken, två per våning och sida
    for sida in (-1, 1):
        x = sida * (w / 2 - w / n / 2)
        for (za, zb) in ((z0 + 0.18, (z0 + z1) / 2 - 0.09),
                         ((z0 + z1) / 2 + 0.09, z1 - 0.18)):
            dx, dz = -sida * w / n * 0.9, zb - za
            längd = math.hypot(dx, dz)
            vinkel = math.atan2(-dz, dx)  # x-axeln -> (cos, 0, -sin)
            # strävan går från fackets ytterkant inåt: mitten ska ligga halva dx in, inte utanför
            c = Vector((x + dx / 2, y - 0.03, (za + zb) / 2))
            m = Matrix.Translation(c) @ Matrix.Rotation(vinkel, 4, "Y") @ Matrix.Translation(-c)
            b.låda((c.x, c.y, c.z - 0.07), (längd, 0.09, 0.14), mat_ram, m)


def gavel(b, w, d, z0, höjd, nock, mat, bräda=0.3, tjock=0.16):
    """Gavelspetsen över väggens överkant: ett tätt trekantigt prisma med brädor som relief.

    Tidigare var gaveln en trappa av allt smalare plank; stegen lämnade öppna trekantiga springor
    mot takets undersida. Nu är spetsen en sluten yta och brädorna ligger utanpå den.
    """
    for sida in (-1, 1):
        if nock == "y":
            ut = Vector((0, sida, 0))
            y0, y1 = sida * d / 2, sida * d / 2 - sida * tjock
            bas = [Vector((-w / 2, y0, z0)), Vector((w / 2, y0, z0)), Vector((0, y0, z0 + höjd))]
            inre = [Vector((p.x, y1, p.z)) for p in bas]
        else:
            ut = Vector((sida, 0, 0))
            x0, x1 = sida * w / 2, sida * w / 2 - sida * tjock
            bas = [Vector((x0, -d / 2, z0)), Vector((x0, d / 2, z0)), Vector((x0, 0, z0 + höjd))]
            inre = [Vector((x1, p.y, p.z)) for p in bas]
        b.tri(mat, bas, ut)
        b.tri(mat, inre, -ut)
        b.skiva(mat, [bas[0], bas[2], inre[2], inre[0]], Vector((-1, 0, 0)))
        b.skiva(mat, [bas[1], bas[2], inre[2], inre[1]], Vector((1, 0, 0)))
        b.skiva(mat, [bas[0], bas[1], inre[1], inre[0]], Vector((0, 0, -1)))
        # liggande brädor på gavelytan: relief, inte bärande
        z = z0 + bräda
        while z < z0 + höjd - 0.12:
            kvar = 1.0 - (z - z0) / höjd
            if nock == "y":
                b.låda((0, sida * (d / 2 + 0.02), z), (w * kvar * 0.97, 0.05, 0.24), mat)
            else:
                b.låda((sida * (w / 2 + 0.02), 0, z), (0.05, d * kvar * 0.97, 0.24), mat)
            z += bräda


def sadeltak(b, w, d, z0, höjd, nock="y", panna=None, panna2=None, utsprång=0.34,
             pannbredd=0.22, pannrad=0.2, sparrar=True):
    """Sadeltak med takpannor/spån i förband, underlag, nockpannor, sparrar och vindskivor.

    w/d är VÄGGENS mått; taket läggs `utsprång` utanför. Varje panna är en plan skiva (2 tri) med
    en hängande läpp (2 tri) — panntjocklek i verklig skala hade kostat 12 tri per panna utan att
    synas på det avstånd byn ses.
    """
    panna = panna or panna_mörk()
    panna2 = panna2 or panna_ljus()
    W, D = w + 2 * utsprång, d + 2 * utsprång
    if nock == "y":
        halv, längd, nockvektor = W / 2, D, Vector((0, 1, 0))
        kanter = [(1, Vector((W / 2, 0, z0))), (-1, Vector((-W / 2, 0, z0)))]
    else:
        halv, längd, nockvektor = D / 2, W, Vector((1, 0, 0))
        kanter = [(1, Vector((0, D / 2, z0))), (-1, Vector((0, -D / 2, z0)))]
    L = math.hypot(halv, höjd)
    for s, kant in kanter:
        if nock == "y":
            lut = Vector((-s * halv, 0, höjd)) / L
            nor = Vector((s * höjd, 0, halv)) / L
        else:
            lut = Vector((0, -s * halv, höjd)) / L
            nor = Vector((0, s * höjd, halv)) / L
        start = kant - nockvektor * (längd / 2)
        horisontell = Vector((nor.x, nor.y, 0)).normalized()
        # underlag: en mörk yta strax under pannorna, så springorna mellan dem blir skugga,
        # och en takfotsbräda underifrån så man inte ser rätt igenom taket under utsprånget
        b.skiva(panna, [start - nor * 0.03,
                        start + nockvektor * längd - nor * 0.03,
                        start + nockvektor * längd + lut * L - nor * 0.03,
                        start + lut * L - nor * 0.03], nor)
        b.skiva(panna, [start - nor * 0.07,
                        start + nockvektor * längd - nor * 0.07,
                        start + nockvektor * längd + lut * L - nor * 0.07,
                        start + lut * L - nor * 0.07], -nor)
        rader = max(2, int(round(L / pannrad)))
        # `start` ligger i takfotshörnet, så löpkoordinaten u går 0..längd längs nocken.
        # Varannat varv förskjuts ett halvt pannmått; kanterna räknas ut så radens ändpannor blir
        # halva i stället för att lämna en springa vid takfoten.
        for r in range(rader):
            v0, v1 = L * r / rader, L * (r + 1) / rader
            kanter = [0.0]
            pos = (pannbredd / 2) * (r % 2)
            while pos < längd - 0.02:
                kanter.append(pos)
                pos += pannbredd
            kanter.append(längd)
            for k, (u0, u1) in enumerate(zip(kanter, kanter[1:])):
                if u1 - u0 < 0.04:
                    continue
                A = start + nockvektor * u0 + lut * v1 + nor * 0.012
                B = start + nockvektor * u1 + lut * v1 + nor * 0.012
                C = start + nockvektor * u1 + lut * v0 + nor * 0.012
                Dd = start + nockvektor * u0 + lut * v0 + nor * 0.012
                mat = panna if (r + k) % 2 else panna2
                b.skiva(mat, [A, B, C, Dd], nor)
                # pannans kant: 2,5 cm ut och 3 cm ned = tjocklek, inte en spik som sticker upp
                kant = nor * 0.025 - Vector((0, 0, 0.03))
                b.skiva(mat, [Dd, C, C + kant, Dd + kant], horisontell)
        # sparrar under takfoten
        if sparrar:
            n = max(2, int(round(längd / 0.55)))
            for i in range(n + 1):
                u = längd * i / n
                c = start + nockvektor * u + lut * 0.12
                b.låda((c.x, c.y, c.z - 0.16), (0.1, 0.1, 0.1), mörkt_virke())
    # nockpannor + vindskivor längs gavlarna
    z_nock = z0 + höjd
    n = max(2, int(round(längd / 0.3)))
    for i in range(n):
        u = -längd / 2 + längd * (i + 0.5) / n
        c = nockvektor * u
        m = (0.34, 0.32, 0.13) if nock == "y" else (0.32, 0.34, 0.13)
        b.låda((c.x, c.y, z_nock - 0.04), m, panna if i % 2 else panna2)
    if nock == "y":
        for y in (-längd / 2 + 0.03, längd / 2 - 0.03):
            for sida in (-1, 1):
                c = Vector((sida * W / 4, y, z0 + höjd / 2))
                längd_skiva = math.hypot(W / 2, höjd)
                # Rotation om Y för x-axeln till (cos, 0, -sin): rätt lutning kräver -höjd
                vinkel = math.atan2(-höjd, -sida * W / 2)
                m = (Matrix.Translation(c) @ Matrix.Rotation(vinkel, 4, "Y")
                     @ Matrix.Translation(-c))
                b.låda((c.x, c.y, c.z - 0.1), (längd_skiva, 0.1, 0.2), panna2, m)


def fonster(b, x, y, z, w=0.8, h=1.0, glas=None, karm_mat=None, bleck=True, luckor=False,
            sprojs=(1, 1)):
    """Fönster med karm, spröjs, fönsterbleck och överliggare — i given fasadpunkt (y = fasad).

    Glaset ligger 2 cm utanför väggen och spröjsen 3 cm framför glaset; utan det blir rutan en
    platt fyrkant i närbild i stället för ett fönster.
    """
    glas = glas or fönster()
    karm_mat = karm_mat or karm()
    yo = y - 0.02  # glasets plan
    # karm: sidostycken, över- och understycke, 10 cm djup så den kastar skugga
    b.låda((x - w / 2 - 0.06, y - 0.05, z), (0.12, 0.14, h + 0.12), karm_mat)
    b.låda((x + w / 2 + 0.06, y - 0.05, z), (0.12, 0.14, h + 0.12), karm_mat)
    b.låda((x, y - 0.05, z + h + 0.01), (w + 0.24, 0.14, 0.1), karm_mat)
    # glasrutor: sprojs[0] x sprojs[1] rutor med spröjs emellan
    kx, kz = sprojs
    for i in range(kx):
        for j in range(kz):
            gw, gh = w / kx * 0.94, h / kz * 0.94
            gx = x - w / 2 + w * (i + 0.5) / kx
            gz = z + h * (j + 0.5) / kz
            b.låda((gx, yo, gz - gh / 2), (gw, 0.04, gh), glas)
    for i in range(1, kx):
        b.låda((x - w / 2 + w * i / kx, yo - 0.02, z), (0.05, 0.05, h), karm_mat)
    for j in range(1, kz):
        b.låda((x, yo - 0.02, z + h * j / kz - 0.025), (w, 0.05, 0.05), karm_mat)
    if bleck:  # fönsterbleck: skjuter ut och lutar utåt, som plåt
        b.låda((x, y - 0.1, z - 0.07), (w + 0.34, 0.22, 0.06), järn())
    if luckor:  # fönsterluckor med gångjärn, uppfällda mot väggen
        for s in (-1, 1):
            b.låda((x + s * (w / 2 + 0.26), y - 0.06, z), (0.36, 0.06, h + 0.06), mörkt_virke())
            b.låda((x + s * (w / 2 + 0.26), y - 0.1, z + h / 2), (0.32, 0.02, 0.06), järn())


def dorr(b, x, y, z, w=1.0, h=1.95, mat=None, karm_mat=None, steg=2, handtag=True):
    """Dörr: plankor i karm, två gångjärnsband, handtag, tröskel och steg framför."""
    mat = mat or mörkt_virke()
    karm_mat = karm_mat or mörkt_virke()
    # karm
    b.låda((x - w / 2 - 0.07, y - 0.06, z), (0.14, 0.18, h + 0.12), karm_mat)
    b.låda((x + w / 2 + 0.07, y - 0.06, z), (0.14, 0.18, h + 0.12), karm_mat)
    b.låda((x, y - 0.06, z + h), (w + 0.28, 0.2, 0.14), karm_mat)
    # dörrblad av plankor
    n = 6
    for i in range(n):
        px = x - w / 2 + w * (i + 0.5) / n
        b.låda((px, y - 0.03, z + 0.02), (w / n * 0.9, 0.08, h - 0.04), mat)
    # tvärslåar och gångjärn
    for zz in (z + 0.35, z + h - 0.45):
        b.låda((x, y - 0.09, zz), (w * 0.94, 0.05, 0.12), mat)
        b.låda((x - w / 2 + 0.06, y - 0.12, zz), (0.3, 0.05, 0.1), järn())
    if handtag:
        b.låda((x + w / 2 - 0.16, y - 0.14, z + h * 0.48), (0.05, 0.1, 0.05), järn())
        b.låda((x + w / 2 - 0.16, y - 0.19, z + h * 0.48 - 0.12), (0.04, 0.04, 0.16), järn())
        b.låda((x + w / 2 - 0.16, y - 0.2, z + h * 0.48 - 0.16), (0.09, 0.04, 0.1), mässing())
    # tröskelsten
    b.låda((x, y - 0.1, z - 0.06), (w + 0.4, 0.3, 0.08), sten())
    for i in range(steg):
        b.låda((x, y - 0.3 - 0.2 * i, 0), (w + 0.5 - 0.06 * i, 0.24, z - 0.02 - 0.16 * i),
               sten())


def trappa(b, x, y, z_topp, w=1.6, steg=4, mat=None):
    """Stentrappa framför en dörr: avsats + trappsteg med sidostycken."""
    mat = mat or sten()
    for i in range(steg):
        h = z_topp * (i + 1) / (steg + 1)
        b.låda((x, y - 0.22 * i, 0), (w, 0.26, h), mat)
    for s in (-1, 1):  # sidostycken (balkar) som håller trappan
        b.låda((x + s * (w / 2 + 0.06), y - 0.22 * (steg - 1) / 2, 0), (0.18, 0.3 * steg, z_topp),
               mat)


def skylt(b, x, y, z, bredd=1.0, höjd=0.7, emblem="ring", ut=0.55):
    """Hängande skylt: konsol med snedsträva, två öglor, bräda och ett målat fält."""
    b.låda((x, y - ut / 2, z + höjd + 0.16), (0.09, ut, 0.09), järn())
    # snedsträva under armen: stången lutar från väggen ut mot armens ytterände
    dy, dz = -ut * 0.92, -0.13
    c = Vector((x, y + dy / 2, z + höjd + 0.1 + dz / 2))
    m = (Matrix.Translation(c) @ Matrix.Rotation(math.atan2(dz, dy), 4, "X")
         @ Matrix.Translation(-c))
    b.låda((c.x, c.y, c.z - 0.03), (0.07, math.hypot(dy, dz), 0.06), järn(), m)
    for s in (-1, 1):
        b.låda((x + s * bredd * 0.32, y - ut, z + höjd - 0.02), (0.04, 0.04, 0.2), järn())
    b.låda((x, y - ut, z), (bredd, 0.08, höjd), ljust_virke())
    b.låda((x, y - ut - 0.04, z + höjd * 0.15), (bredd * 0.74, 0.02, höjd * 0.68), skyltfält())
    # emblem: enkla kantiga figurer som läses på håll
    if emblem == "ring":
        b.låda((x, y - ut - 0.06, z + höjd * 0.42), (bredd * 0.3, 0.02, 0.1), mässing())
        b.låda((x, y - ut - 0.06, z + höjd * 0.3), (0.1, 0.02, höjd * 0.36), mässing())
    elif emblem == "kanna":
        b.låda((x - 0.03, y - ut - 0.06, z + höjd * 0.34), (bredd * 0.24, 0.02, höjd * 0.3), mässing())
        b.låda((x + bredd * 0.14, y - ut - 0.06, z + höjd * 0.44), (0.06, 0.02, höjd * 0.16), mässing())
    elif emblem == "smed":
        b.låda((x, y - ut - 0.06, z + höjd * 0.34), (bredd * 0.4, 0.02, 0.09), järn())
        b.låda((x - bredd * 0.02, y - ut - 0.06, z + höjd * 0.46), (0.08, 0.02, höjd * 0.24), järn())
    elif emblem == "juvel":
        for dx, dz in ((0, 0.1), (-0.1, 0), (0.1, 0)):
            b.låda((x + dx * bredd, y - ut - 0.06, z + höjd * 0.36 + dz), (0.12, 0.02, 0.12),
                   mässing())


def skorsten(b, x, y, z0, h, bredd=0.7, mat=None, hatt=True):
    """Skorsten av murade skift med tätare fogar än husets, plus hatt och sotkant."""
    mat = mat or tegel()
    b.låda((x, y, z0), (bredd, bredd, h), mur())
    kurser = max(4, int(h / 0.22))
    for k in range(kurser):
        b.skift(bredd, bredd, z0 + h * k / kurser, h / kurser, mat, block=0.34,
                tjock=0.07, förskjut=(0.17 if k % 2 else 0.0))
    if hatt:
        b.låda((x, y, z0 + h), (bredd + 0.14, bredd + 0.14, 0.1), sten())
        b.låda((x, y, z0 + h + 0.1), (bredd * 0.6, bredd * 0.6, 0.16), kol())


def lykta(b, x, y, z, arm=0.3):
    """Vägglykta: järnarm, glaslykta som lyser, plåttak och krok."""
    b.låda((x, y - arm / 2, z + 0.34), (0.06, arm, 0.06), järn())
    b.låda((x, y - arm, z + 0.26), (0.04, 0.04, 0.12), järn())
    b.låda((x, y - arm, z), (0.24, 0.24, 0.4), lyktglas())
    for s in (-1, 1):
        b.låda((x + s * 0.12, y - arm, z), (0.02, 0.26, 0.42), järn())
        b.låda((x, y - arm + s * 0.12, z), (0.26, 0.02, 0.42), järn())
    b.låda((x, y - arm, z + 0.4), (0.32, 0.32, 0.08), järn())
    b.låda((x, y - arm, z + 0.48), (0.12, 0.12, 0.06), järn())
    b.låda((x, y - arm, z - 0.06), (0.28, 0.28, 0.06), järn())


def tunna(b, x, y, z, r=0.28, h=0.7, mat=None):
    """Tunna av stavar med två band — läsbar silhuett i byn."""
    mat = mat or ljust_virke()
    n = 10
    for i in range(n):
        a = 2 * math.pi * i / n
        c = Vector((x + r * math.cos(a), y + r * math.sin(a), z))
        m = Matrix.Translation(c) @ Matrix.Rotation(a + math.pi / 2, 4, "Z") @ Matrix.Translation(-c)
        b.låda((c.x, c.y, z), (r * 0.62, 0.07, h), mat, m)
    for zz in (z + 0.12, z + h - 0.16):
        b.låda((x, y, zz), (r * 2.06, r * 2.06, 0.06), järn())
    b.låda((x, y, z + h - 0.04), (r * 1.9, r * 1.9, 0.04), mat)


def kista(b, x, y, z, s=0.5, mat=None):
    """Låda/kista av plankor med hörnbeslag."""
    mat = mat or ljust_virke()
    b.låda((x, y, z), (s, s * 0.8, s * 0.8), mat)
    for sida in (-1, 1):
        b.låda((x, y + sida * (s * 0.4 + 0.01), z + 0.05), (s * 1.02, 0.02, 0.05), järn())
    for dx in (-1, 1):
        for dy in (-1, 1):
            b.låda((x + dx * (s / 2 - 0.03), y + dy * (s * 0.4 - 0.03), z),
                   (0.05, 0.05, s * 0.82), järn())


# --- 1. Thread of Destiny (vävarstugan) -------------------------------------------------------
def tradet(b):
    """Liten vävarstuga: timmer på stensockel, brant spåntak, vävställ och hängande tyg i fronten."""
    w, d = 4.6, 3.4
    b.plint(w, d, 0.62, block=0.9, kurser=2)
    stockvägg(b, w, d, 0.62, 3.02, mörkt_virke())
    gavel(b, w, d, 3.02, 2.0, "y", mörkt_virke())
    sadeltak(b, w, d, 3.02, 2.0, "y", spån_mörk(), spån_ljus(), utsprång=0.4,
             pannbredd=0.26, pannrad=0.22)
    y = -d / 2 - 0.13  # utanför stockarnas ytterkant
    dorr(b, 0.85, y, 0.62, 0.95, 1.9, ljust_virke(), mörkt_virke())
    fonster(b, 0.85, y, 2.56, 0.66, 0.66, karm_mat=mörkt_virke())
    fonster(b, -1.45, y, 1.55, 0.7, 0.85, karm_mat=mörkt_virke(), luckor=True)
    # vävstolen syns genom den öppna dörren: en bjälke och tre tygbanor i fronten
    b.låda((-1.15, y - 0.28, 2.86), (2.5, 0.13, 0.13), mörkt_virke())
    for i, (tyg, x) in enumerate([(tyg_rött(), -2.05), (ljust_virke(), -1.38),
                                  (tyg_blått(), -0.7)]):
        b.låda((x, y - 0.42, 1.42), (0.58, 0.06, 1.44), tyg)
        b.låda((x, y - 0.46, 2.78), (0.58, 0.03, 0.1), mörkt_virke())  # klämma
    # tygrulle och garnkorg utanför
    b.låda((-2.4, y - 0.5, 0), (0.9, 0.5, 0.36), ljust_virke())
    for i in range(3):
        b.låda((-2.66 + 0.26 * i, y - 0.5, 0.36), (0.2, 0.2, 0.22),
               (tyg_rött, tyg_blått, ljust_virke)[i]())
    skylt(b, 1.85, y, 2.3, 0.85, 0.6, emblem="ring")
    skorsten(b, 1.15, 0.85, 3.6, 1.9, 0.55)
    tunna(b, -2.05, y - 0.45, 0, 0.27, 0.62)
    b.låda((-0.2, y - 0.3, 0), (0.7, 0.5, 0.3), mörkt_virke())  # vedhög


# --- 2. Smedjan -------------------------------------------------------------------------------
def smed(b):
    """Smedja: murad sten med kurser, öppen ässja med glöd, bälg, städ med hammare, kolhög."""
    w, d = 5.2, 3.8
    b.plint(w, d, 0.6, block=0.95, kurser=2)
    # murade väggar: skift runt en kärna, så fogarna syns på alla fasader
    b.låda((0, 0, 0.6), (w, d, 2.5), mur())
    for k in range(7):
        b.skift(w, d, 0.6 + 2.5 * k / 7, 2.5 / 7, sten(), block=0.62, tjock=0.1,
                förskjut=(0.31 if k % 2 else 0.0))
    gavel(b, w, d, 3.1, 1.75, "x", mur())
    sadeltak(b, w, d, 3.1, 1.75, "x", panna_mörk(), panna_ljus(), utsprång=0.36,
             pannbredd=0.24, pannrad=0.22)
    y = -d / 2 - 0.09  # utanför murstenarnas ytterkant
    dorr(b, -1.05, y, 0.6, 1.1, 2.05, ljust_virke(), mörkt_virke())
    fonster(b, 0.35, y, 1.95, 0.72, 0.62, karm_mat=mörkt_virke())
    skorsten(b, -1.75, 0.85, 2.6, 4.1, 0.78)
    # --- ässjan: utbyggd härd med glödbädd, kåpa och egen skorsten ---
    ax, ay = 1.75, -d / 2 - 0.5
    b.låda((ax, ay, 0), (1.9, 1.0, 0.95), mur())
    for k in range(3):
        b.skift(1.9, 1.0, 0.95 * k / 3, 0.95 / 3, sten(), block=0.4, tjock=0.09,
                förskjut=(0.2 if k % 2 else 0.0))
    for s in (-1, 1):  # härdens sidoväggar
        b.låda((ax + s * 0.78, ay, 0.95), (0.34, 1.0, 0.7), mur())
    b.låda((ax, ay + 0.36, 0.95), (1.6, 0.28, 0.7), mur())  # bakvägg
    b.låda((ax, ay, 0.95), (1.5, 0.86, 0.12), kol())  # bädd
    slump = random.Random(7)
    for i in range(26):  # glödande kol
        gx = ax + slump.uniform(-0.62, 0.62)
        gy = ay + slump.uniform(-0.34, 0.28)
        b.låda((gx, gy, 1.05), (slump.uniform(0.1, 0.2), slump.uniform(0.1, 0.2),
                                slump.uniform(0.05, 0.12)),
               glöd() if i % 3 else panna_ljus())
    # kåpa över ässjan, avsmalnande mot skorstenen
    b.låda((ax, ay, 1.62), (2.1, 1.0, 0.12), järn())
    b.låda((ax, ay, 1.74), (1.5, 0.9, 0.4), järn())
    b.låda((ax, ay, 2.14), (0.85, 0.6, 0.5), mur())
    # --- bälgen vid ässjan ---
    bx, by = 0.55, -d / 2 - 0.45
    b.låda((bx, by, 0.55), (0.55, 0.95, 0.16), mörkt_virke())  # bälgens båda plank
    b.låda((bx, by, 1.15), (0.55, 0.95, 0.16), mörkt_virke())
    for s in (-1, 1):  # läderveck mellan plankorna
        b.låda((bx + s * 0.26, by, 0.7), (0.05, 0.9, 0.46), lera())
    b.låda((bx, by - 0.55, 0.72), (0.1, 0.1, 0.62), mörkt_virke())  # spak
    b.låda((bx + 0.4, by, 0.9), (0.24, 0.2, 0.2), järn())  # munstycke mot ässjan
    # --- städ på stubbe med hammare ---
    sx, sy = -2.05, -d / 2 - 0.62
    b.låda((sx, sy, 0), (0.54, 0.54, 0.72), mörkt_virke())  # stubbe
    b.låda((sx, sy, 0.72), (0.72, 0.36, 0.16), järn())  # städets fot
    b.låda((sx, sy - 0.06, 0.88), (0.34, 0.24, 0.26), järn())  # kropp
    b.låda((sx - 0.42, sy - 0.06, 0.98), (0.5, 0.14, 0.12), järn())  # horn
    b.låda((sx, sy - 0.06, 1.14), (0.3, 0.2, 0.06), järn())  # städets överkant
    # hammare på städet
    b.låda((sx + 0.04, sy - 0.06, 1.2), (0.34, 0.05, 0.05), ljust_virke())
    b.låda((sx - 0.14, sy - 0.06, 1.16), (0.14, 0.09, 0.14), järn())
    # --- verktygstavla på fasaden ---
    for i in range(7):
        tx = -1.0 + 0.3 * i
        b.låda((tx, y - 0.04, 2.4), (0.05, 0.06, 0.1), järn())
        b.låda((tx, y - 0.09, 2.05), (0.06, 0.05, 0.36), ljust_virke())
        if i % 2:
            b.låda((tx, y - 0.1, 1.92), (0.16, 0.05, 0.1), järn())
        else:
            b.låda((tx, y - 0.1, 2.42), (0.18, 0.05, 0.08), järn())
    # --- kolhög och släckvatten ---
    slump = random.Random(11)
    for i in range(22):
        kx = 2.35 + slump.uniform(-0.3, 0.3)
        ky = -d / 2 - 0.5 + slump.uniform(-0.25, 0.25)
        b.låda((kx, ky, slump.uniform(0, 0.22)),
               (slump.uniform(0.1, 0.22), slump.uniform(0.1, 0.22), slump.uniform(0.06, 0.16)),
               kol())
    tunna(b, -0.15, y - 0.4, 0, 0.3, 0.6, mörkt_virke())
    b.låda((-0.15, y - 0.7, 0.5), (0.5, 0.5, 0.02), vatten())
    skylt(b, 2.55, y, 2.55, 0.95, 0.65, emblem="smed", ut=0.45)


# --- 3. Värdshuset ----------------------------------------------------------------------------
def vardshus(b):
    """Två våningar: puts med korsvirke, utkragad övervåning, stora varma fönster, lyktor."""
    w, d = 6.0, 4.0
    b.plint(w, d, 0.68, block=1.0, kurser=2)
    puts_vägg(b, w, d, 0.68, 3.15, stolp=1.5)
    # bjälklaget skjuter ut 25 cm (utkragning), med tänderna synliga under
    b.låda((0, 0, 3.15), (w + 0.5, d + 0.5, 0.24), mörkt_virke())
    for i in range(11):
        b.låda((-w / 2 + 0.3 + i * (w - 0.6) / 10, -d / 2 - 0.25, 2.98), (0.16, 0.3, 0.2),
               mörkt_virke())
    puts_vägg(b, w - 0.5, d - 0.5, 3.39, 5.6, stolp=1.4)
    gavel(b, w - 0.5, d - 0.5, 5.6, 1.75, "y", mörkt_virke())
    sadeltak(b, w - 0.5, d - 0.5, 5.6, 1.75, "y", skiffer(), panna_mörk(), utsprång=0.42,
             pannbredd=0.22, pannrad=0.19)
    y = -d / 2 - 0.12
    dorr(b, 0.0, y, 0.68, 1.4, 2.35, mörkt_virke(), mörkt_virke(), steg=0)
    trappa(b, 0, y - 0.2, 0.68, 1.9, 3)
    # bottenvåningens fönster
    for x in (-2.0, 2.0):
        fonster(b, x, y, 1.4, 1.0, 1.1, karm_mat=mörkt_virke(), luckor=True, sprojs=(2, 2))
    # övervåningens fönster, fyra stycken med spröjs
    for x in (-1.9, -0.65, 0.65, 1.9):
        fonster(b, x, y - 0.13, 4.1, 0.78, 0.95, karm_mat=mörkt_virke(), sprojs=(2, 2))
    # balkong över dörren
    b.låda((0, y - 0.35, 2.72), (2.6, 0.75, 0.12), mörkt_virke())
    for i in range(7):
        b.låda((-1.2 + i * 0.4, y - 0.7, 2.84), (0.08, 0.08, 0.62), mörkt_virke())
    b.låda((0, y - 0.7, 3.42), (2.6, 0.1, 0.1), mörkt_virke())
    # lyktor på ömse sidor om dörren
    for x in (-1.25, 1.25):
        lykta(b, x, y, 2.35, 0.34)
    skylt(b, 2.45, y, 4.7, 1.15, 0.8, emblem="kanna", ut=0.7)
    skorsten(b, 1.65, 0.9, 6.0, 1.6, 0.6)
    # fat och kistor längs fasaden
    tunna(b, -2.5, y - 0.55, 0, 0.32, 0.78)
    tunna(b, 2.55, y - 0.5, 0, 0.28, 0.62)
    kista(b, 1.75, y - 0.45, 0, 0.55)


# --- 4. Porttornet ----------------------------------------------------------------------------
def karta(b):
    """Porttorn i sten: murverk med valvöppning, kilstenar, krenelering, port med järnband."""
    w, d = 5.4, 3.8
    b.plint(w, d, 0.75, block=1.1, kurser=2, kärna=sten())
    # tornkroppen i skift; framsidan muras block för block runt valvet
    z_topp = 6.9
    b.låda((0, 0, 0.75), (w, d, z_topp - 0.75), mur())
    R, z_valv = 1.15, 3.55
    for k in range(6):
        b.skift(w, d, 0.75 + (z_topp - 0.75) * k / 6, (z_topp - 0.75) / 6, sten(),
                block=0.9, tjock=0.12, förskjut=(0.45 if k % 2 else 0.0))
    # frontens murverk: kurser av block, med hål för valvet
    y = -d / 2 - 0.09  # utanför murstenarnas ytterkant
    rad = 0.42
    n_rad = int((z_topp - 0.9) / rad)
    for r in range(n_rad):
        z = 0.9 + r * rad
        n = 9
        bw = w / n
        for i in range(n):
            x = -w / 2 + bw * (i + 0.5)
            if r % 2:
                x += bw / 2
            if x > w / 2 - 0.1:
                continue
            # i valvöppningen? (rak under vågrät överkant, halvcirkel över)
            inne = (abs(x) < R - 0.05 and z < z_valv) or \
                   (abs(x) < R - 0.05 and (x * x + (z - z_valv) ** 2) < (R - 0.05) ** 2)
            if inne:
                continue
            b.låda((x, y, z), (bw * 0.93, 0.14, rad * 0.9), sten())
    # valvets insida (mörkt), port och järnband
    b.låda((0, y + 0.42, 0.75), (2 * R - 0.05, 0.06, z_valv - 0.75), glas_mörkt())
    b.låda((0, y - 0.04, 0.75), (2 * R - 0.22, 0.1, 1.85), mörkt_virke())
    for zz in (1.15, 1.7, 2.25):
        b.låda((0, y - 0.12, zz), (2 * R - 0.24, 0.05, 0.12), järn())
    b.låda((0, y - 0.12, 1.2), (0.12, 0.05, 1.0), järn())
    for i in range(6):  # spikar på porten
        b.låda((-0.7 + i * 0.28, y - 0.14, 1.55), (0.05, 0.03, 0.05), järn())
    # kilstenar kring valvet
    block = 9
    for i in range(block):
        v = math.pi * (i + 0.5) / block
        r = R + 0.14
        c = Vector((0 - r * math.cos(v), y, z_valv + r * math.sin(v)))
        m = (Matrix.Translation(c) @ Matrix.Rotation(v - math.pi / 2, 4, "Y")
             @ Matrix.Translation(-c))
        b.låda((c.x, y, c.z - 0.19), (math.pi * R / block * 1.05, 0.24, 0.38), sten(), m)
    for s in (-1, 1):  # anfangstenar
        b.låda((s * (R + 0.16), y, z_valv - 0.5), (0.34, 0.28, 0.5), sten())
    # krenelering: tinnar runt hela toppen + en skyttegång under
    b.låda((0, 0, z_topp), (w + 0.3, d + 0.3, 0.28), sten())
    for (px, py, sx, sy) in [(-2.2, -d / 2 - 0.1, 0.6, 0.5), (0, -d / 2 - 0.1, 0.6, 0.5),
                             (2.2, -d / 2 - 0.1, 0.6, 0.5), (-2.2, d / 2 + 0.1, 0.6, 0.5),
                             (0, d / 2 + 0.1, 0.6, 0.5), (2.2, d / 2 + 0.1, 0.6, 0.5),
                             (-w / 2 - 0.1, -0.9, 0.5, 0.6), (w / 2 + 0.1, -0.9, 0.5, 0.6),
                             (-w / 2 - 0.1, 0.9, 0.5, 0.6), (w / 2 + 0.1, 0.9, 0.5, 0.6)]:
        b.låda((px, py, z_topp + 0.28), (sx, sy, 0.62), sten())
        b.låda((px, py, z_topp + 0.9), (sx + 0.08, sy + 0.08, 0.09), mur())
    # skottgluggar: mörk slits i en ljus stenram, så den läses mot muren
    for x in (-1.7, 1.7):
        for zz in (5.1, 6.4):
            b.låda((x, y - 0.16, zz), (0.22, 0.12, 1.0), glas_mörkt())
            b.låda((x, y - 0.12, zz - 0.12), (0.46, 0.1, 0.14), puts())
            b.låda((x, y - 0.12, zz + 1.0), (0.46, 0.1, 0.14), puts())
            for s in (-1, 1):
                b.låda((x + s * 0.15, y - 0.12, zz), (0.1, 0.1, 1.0), puts())
    for sx in (-1, 1):
        for sy in (-1, 1):
            for i in range(9):
                z = 1.0 + i * 0.72
                b.låda((sx * (w / 2 + 0.02), sy * (d / 2 - 0.14), z),
                       (0.3 if i % 2 else 0.26, 0.32, 0.66), sten())
            b.låda((sx * (w / 2 + 0.02), sy * (d / 2 - 0.14), 7.0), (0.36, 0.36, 0.4), sten())
    # fana på en stång från fronten
    b.låda((w / 2 - 0.15, y - 0.3, 5.9), (0.08, 0.08, 1.4), mörkt_virke())
    b.låda((w / 2 - 0.15, y - 0.62, 6.5), (0.05, 0.62, 0.85), tyg_rött())
    b.låda((w / 2 - 0.15, y - 0.9, 6.5), (0.04, 0.06, 0.85), mässing())
    skylt(b, -1.95, y, 4.35, 0.8, 0.55, emblem="ring", ut=0.4)
    lykta(b, 1.95, y, 3.6, 0.32)


# --- 5. Juveleraren ---------------------------------------------------------------------------
def juvelerare(b):
    """Litet stenhus: kvadersten, skyltfönster med galler och spröjs, skylt, murgröna."""
    w, d = 4.6, 3.2
    b.plint(w, d, 0.55, block=0.85, kurser=2, kärna=sten())
    b.låda((0, 0, 0.55), (w, d, 2.55), mur())
    for k in range(6):
        b.skift(w, d, 0.55 + 2.55 * k / 6, 2.55 / 6, sten(), block=0.72, tjock=0.1,
                förskjut=(0.36 if k % 2 else 0.0))
    gavel(b, w, d, 3.1, 1.5, "y", puts())
    sadeltak(b, w, d, 3.1, 1.5, "y", panna_mörk(), panna_ljus(), utsprång=0.4,
             pannbredd=0.2, pannrad=0.18)
    y = -d / 2 - 0.09  # utanför kvaderstenens ytterkant
    # hörnkvadrar i puts (ljusare) så huset skiljer sig från smedjans mur
    for sx in (-1, 1):
        for i in range(5):
            b.låda((sx * (w / 2 - 0.02), y - 0.06, 0.55 + i * 0.62), (0.34, 0.1, 0.56), puts())
    dorr(b, -1.45, y, 0.55, 0.9, 2.0, mörkt_virke(), puts())
    # skyltfönster: karm i järn, 3 rutor, galler och varor på en hylla
    sw, sh = 2.1, 1.35
    b.låda((0.75, y - 0.04, 1.05), (sw + 0.2, 0.14, sh + 0.2), järn())
    b.låda((0.75, y - 0.08, 1.1), (sw, 0.06, sh), fönster())
    for i in range(1, 3):
        b.låda((0.75 - sw / 2 + sw * i / 3, y - 0.14, 1.1), (0.055, 0.05, sh), karm())
    for j in range(1, 2):
        b.låda((0.75, y - 0.14, 1.1 + sh * j / 2), (sw, 0.05, 0.055), karm())
    b.låda((0.75, y - 0.12, 1.05), (sw + 0.1, 0.06, 0.1), järn())  # spröjsens mittband
    for i in range(3):  # smycken på hyllan, i glasets överkant
        b.låda((0.1 + 0.6 * i, y - 0.11, 1.62), (0.16, 0.04, 0.14), mässing())
    b.låda((0.75, y - 0.2, 0.94), (sw + 0.5, 0.28, 0.09), järn())  # bleck
    for i in range(6):  # galler framför glaset
        b.låda((-0.3 + i * 0.42, y - 0.18, 1.1), (0.045, 0.045, sh), järn())
    for zz in (1.35, 1.85):
        b.låda((0.75, y - 0.18, zz), (sw, 0.045, 0.045), järn())
    # skylt ovanför dörren + hängande skylt
    b.låda((-1.45, y - 0.08, 2.62), (1.7, 0.1, 0.42), ljust_virke())
    b.låda((-1.45, y - 0.14, 2.68), (1.3, 0.03, 0.24), skyltfält())
    skylt(b, 1.0, y, 2.3, 0.8, 0.55, emblem="juvel", ut=0.4)
    skorsten(b, -1.2, 0.6, 3.5, 1.5, 0.5)
    # murgröna uppför vänstra sidan, i trappsteg
    for i in range(7):
        b.låda((-2.15 + 0.03 * (i % 2), y - 0.07, 0.6 + i * 0.36),
               (0.42 - 0.03 * i, 0.12, 0.4), murgröna())
    for i in range(4):
        b.låda((-1.85 + i * 0.2, y - 0.07, 3.0 - i * 0.06), (0.3, 0.1, 0.24), murgröna())
    fonster(b, -2.0, y, 2.15, 0.44, 0.5, karm_mat=puts())


# --- 6. Avsluta (grindstugan) -----------------------------------------------------------------
def avsluta(b):
    """Liten grindstuga: timmer, spåntak, grindstolpar med skylt och en lykta vid grinden."""
    w, d = 4.4, 3.0
    b.plint(w, d, 0.45, block=0.8, kurser=2)
    stockvägg(b, w, d, 0.45, 2.62, ljust_virke(), höjd=0.24)
    gavel(b, w, d, 2.62, 1.55, "y", mörkt_virke())
    sadeltak(b, w, d, 2.62, 1.55, "y", spån_mörk(), spån_ljus(), utsprång=0.34,
             pannbredd=0.24, pannrad=0.2)
    y = -d / 2 - 0.13  # utanför stockarnas ytterkant
    dorr(b, 0.1, y, 0.45, 0.95, 1.85, mörkt_virke(), mörkt_virke(), steg=1)
    fonster(b, 1.55, y, 1.35, 0.5, 0.6, karm_mat=mörkt_virke())
    fonster(b, -1.55, y, 1.35, 0.5, 0.6, karm_mat=mörkt_virke(), luckor=True)
    # grindstolpar med bom och skylt över vägen
    for x in (-2.35, 2.35):
        b.låda((x, y - 0.7, 0), (0.26, 0.26, 2.75), mörkt_virke())
        b.låda((x, y - 0.7, 2.75), (0.36, 0.36, 0.12), mörkt_virke())
        b.låda((x, y - 0.7, 0.35), (0.34, 0.34, 0.12), järn())
    b.låda((0, y - 0.7, 2.35), (4.96, 0.16, 0.22), mörkt_virke())
    b.låda((0, y - 0.7, 2.05), (4.4, 0.12, 0.14), mörkt_virke())
    # skylten: bräda med målat fält och kantlist
    b.låda((0, y - 0.85, 1.62), (2.7, 0.12, 0.8), ljust_virke())
    b.låda((0, y - 0.92, 1.72), (2.3, 0.03, 0.5), skyltfält())
    b.låda((0, y - 0.92, 1.72), (1.9, 0.02, 0.12), mässing())
    for x in (-1.2, 1.2):
        b.låda((x, y - 0.92, 1.72), (0.1, 0.02, 0.5), mässing())
    # bommen över vägen (nedfälld) med järnbeslag
    b.låda((0, y - 0.7, 0.85), (4.2, 0.12, 0.16), mörkt_virke())
    for x in (-1.4, 1.4):
        b.låda((x, y - 0.7, 0.8), (0.2, 0.16, 0.26), järn())
    lykta(b, 2.35, y - 0.7, 2.95, 0.0)
    skorsten(b, -1.2, 0.6, 3.1, 1.4, 0.45)
    tunna(b, -1.75, y - 0.4, 0, 0.24, 0.55)
    b.låda((1.6, y - 0.45, 0), (0.5, 0.4, 0.4), mörkt_virke())  # vedkorg


BYGGNADER = [
    ("tradet", tradet),
    ("smed", smed),
    ("vardshus", vardshus),
    ("karta", karta),
    ("juvelerare", juvelerare),
    ("avsluta", avsluta),
]

# vad som skiljer husen åt, för README:n (siffrorna där skrivs ur modellerna, inte härifrån)
DELAR = {
    "tradet": "timmerstockar med knutar, spåntak, hängande väv, tygrullar, tunna",
    "smed": "murat skiftverk, öppen ässja med glödbädd, kåpa, bälg, städ med hammare, "
            "verktygstavla, kolhög",
    "vardshus": "puts med korsvirke och snedsträvor, utkragad övervåning, balkong, lyktor",
    "karta": "murverk block för block runt valvet, kilstenar, krenelering, port med järnband, fana",
    "juvelerare": "kvadersten, skyltfönster med galler och smycken, murgröna, hörnkvadrar",
    "avsluta": "timmer, spåntak, grindstolpar, bom och skylt över vägen",
}


def tom_scen():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def bygg_byggnad(id, fn):
    koll = bpy.data.collections.new("by_" + id)
    bpy.context.scene.collection.children.link(koll)
    b = Bygge()
    fn(b)
    b.mesha(koll, id)
    return koll


def mät(koll):
    """(trianglar, total bbox, grundens bbox) för en samling.

    Grunden (sockeln) är byggnadens FOTPRINT; takutsprång, skyltar, trappor och ässjor sticker ut
    utanför den, så måtten i uppdraget (4-6 x 3-4 m) mäts mot grunden och höjden mot totalen.
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
    bg.inputs[1].default_value = 1.0
    s.world = värld
    # markplan: visar att huset står på marken och ger en skugga att läsa siluetten mot
    mark = bpy.data.meshes.new("mark")
    mark.from_pydata([(-30, -30, -0.002), (30, -30, -0.002), (30, 30, -0.002),
                      (-30, 30, -0.002)], [], [(0, 1, 2, 3)])
    mark.update()
    mark.materials.append(material("mark", färg=(58, 56, 52), grovhet=1.0))
    bpy.context.scene.collection.objects.link(bpy.data.objects.new("mark", mark))
    for typ, plats, energi, storlek in (("AREA", (6, -9, 9), 2600, 6),
                                        ("AREA", (-8, -4, 5), 900, 7),
                                        ("AREA", (0, 8, 7), 500, 8)):
        l = bpy.data.lights.new("ljus", typ)
        l.energy = energi
        l.size = storlek
        ob = bpy.data.objects.new("ljus", l)
        ob.location = plats
        bpy.context.scene.collection.objects.link(ob)
        rikt = Vector((0, 0, 3)) - Vector(plats)
        ob.rotation_euler = rikt.to_track_quat("-Z", "Y").to_euler()
    kam = bpy.data.objects.new("kamera", bpy.data.cameras.new("kamera"))
    kam.data.lens = 55
    bpy.context.scene.collection.objects.link(kam)
    s.camera = kam
    return kam


def rendera(id, kam, total, vyer=((-38, 12), (44, 16))):
    """Två vyer per hus (trekvarts framifrån, båda sidor) till granskning/<id>_<n>.png."""
    GRANSKA.mkdir(parents=True, exist_ok=True)
    mål = Vector((0, 0, total.z * 0.48))
    r = 2.35 * max(total.x, total.y, total.z)
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
    rader = []
    for i, (id, fn) in enumerate(BYGGNADER):
        koll = bygg_byggnad(id, fn)
        for ob in koll.objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = koll.objects[0]
        bpy.ops.export_scene.gltf(filepath=str(UT / (id + ".glb")), export_format="GLB",
                                  use_selection=True)
        for ob in koll.objects:
            ob.select_set(False)
        trianglar, total, bas = mät(koll)
        rader.append((id, trianglar, len(koll.objects), total, bas,
                      sorted({m.name for ob in koll.objects
                              for m in ob.data.materials if m})))
        print("  %-11s %5d tri  %2d noder  grund %.1f x %.1f m  högst %.1f m"
              % (id, trianglar, len(koll.objects), bas.x, bas.y, total.z))
        rendera(id, kam, total)
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
            "En GLB per byggnad, byggd av `tools/gen_by_hus3d.py` ur spelets egna materialrutor.",
            "Byggs om med", "",
            "```", "blender --background --python tools/gen_by_hus3d.py",
            "blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät",
            "```", "",
            "Origo ligger på markplanet mitt i varje byggnad, +Z upp i Blender (GLB-exporten gör Y-up).",
            "Fasaden ligger åt -Y i Blender, alltså +Z i GLB:n. Enheter är meter. Grunden (sockeln) är",
            "fotavtrycket; takutsprång, skyltar, trappor och ässjor sticker ut utanför den.",
            "Samlingsfilen med alla sex på rad är `assets/by_hus_3d.blend` (utanför git, samma regel",
            "som repots övriga .blend-filer). Turnaround-bilder ligger i `granskning/`.", "",
            "Varje hus exporteras som en mesh per material (Noder nedan), inte en nod per spik:",
            "det håller GLB:n på ett tiotal draw calls per hus i byn. `--kolla` kräver 3 000-15 000",
            "trianglar per hus, grund på 4-6 × 3-4 m och högsta punkt på 4-8 m.", "",
            "| Byggnad | Grund b × d (m) | Högsta punkt (m) | Trianglar | Noder | Texturer |",
            "|---|---|---|---|---|---|"]
    for id, trianglar, noder, total, bas, matar in rader:
        texturer = ", ".join(m for m in matar if m not in (
            "glöd", "fönster", "lyktglas", "tyg_rött", "tyg_blått", "glas_mörkt", "skyltfält",
            "takpanna_mörk", "takpanna_ljus", "spån_mörk", "spån_ljus", "tegel", "kol",
            "mässing", "vatten", "lera", "fönsterkarm"))
        text.append("| `%s.glb` | %.1f × %.1f | %.1f | %d | %d | %s |"
                    % (id, bas.x, bas.y, total.z, trianglar, noder, texturer))
    text += ["", "Varje hus är ihopsatt av riktiga byggdelar:", ""]
    for id, *_ in rader:
        text.append("- **%s** — %s" % (id, DELAR[id]))
    text += ["", "Material utan textur (platta färger i byns palett): takpannor, spån, tegel, glöd,",
             "fönster, lyktglas, tyg_rött, tyg_blått, glas_mörkt, skyltfält, mässing, kol, vatten, lera,",
             "fönsterkarm.", "",
             "Texturerna är spelets egna rutor i `game/assets/tiles/material/`, ett varv per ~2,2 m", "",
             "| Material i GLB | Ruta |", "|---|---|"]
    for namn in sorted(TEXTUR):
        text.append("| `%s` | `%s.png` |" % (namn, TEXTUR[namn]))
    text += ["", "Referensbilderna (`by2d/byn_vc.png`, `by2d/byn.png`, `vc_lan/town/Town_BG.png`) är",
             "bara tittade på — ingen av dem är använd som textur.", ""]
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
        # Måtten ur uppdraget: grund 4-6 x 3-4 m, högst 8 m och lägst 4 m, 3 000-15 000 trianglar.
        # Totalen får sticka ut högst 1,5 m utanför grunden (takutsprång + skylt) — mer är en
        # felplacerad detalj.
        ok = (kb > 1 and 3000 <= trianglar <= 15000
              and 3.95 <= bas.x <= 6.05 and 2.95 <= bas.y <= 4.05
              and 3.95 <= total.z <= 8.05
              and total.x <= bas.x + 1.5 and total.y <= bas.y + 1.5)
        print("%s %-11s %6.0f kB  %5d tri  grund %.1f x %.1f  totalt %.1f x %.1f x %.1f m  %d material"
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
