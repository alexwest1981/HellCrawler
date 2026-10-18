"""REKVISITEN I 3D: nio modeller ur spelets egen palett, ut till EN glTF.

    blender -b --factory-startup --python tools/rekvisita3d.py
    ... -- --kolla               # mät och kontrollera, rendera inte
    ... -- --bild                # rendera en bild per rekvisit (att döma på)

VARFÖR: rekvisiten var voxelreliefer byggda ur sina egna 2D-ark (`Voxel.ur_ark`, M108) — en bild
som fått tjocklek. Alex: *"den är otroligt platt idag"*. Här byggs i stället en riktig modell per
rekvisit: rund bur, kandelaber med fyra armar, spade med blad, benhög med skalle, tuva med strån.
Formerna följer arket (tools/gen_props.py) men DJUPET är designat — en bild säger ingenting om det.

FÄRGEN ÄR PALETTENS, i VERTEXFÄRG. Spelets egna voxlar lägger palettens 8-bitstal rakt i
vertexfärgen (`Color8`, alltså utan sRGB-kurva), och shadern `ui/voxel_rekvisit.gdshader` läser
COLOR — därför skrivs samma tal här, så att rekvisiten och fienderna färgas av samma regel. En
kopia av färgerna i skriptet hade glidit ifrån palette.json utan att någon såg det.

MÅTTET är spelets: DEKOR_PIXEL = 0,008 m per arkpixel (128 px/m), och modellen centreras kring sitt
eget origo — då gäller `Main._dekor_y` oförändrad: nederkanten på golvet, överkanten i taket för
det som hänger. Bredden är arkets; djupet står i PROPS.

UTFIL: game/assets/props/rekvisita.glb — EN nod per rekvisit, namngiven som arten, så spelet slår
upp meshen på namnet. `--kolla` mäter: ytor > 0, vertexfärger i paletten, djup >= 25 % av bredden
(ingen platt skylt), höjden inom 20 % av den byggda rutan, och att glb-filen innehåller alla noder.
"""

from __future__ import annotations

import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
PALETT = ROOT / "game" / "assets" / "palette.json"
GLB = ROOT / "game" / "assets" / "props" / "rekvisita.glb"
BILDMAPP = Path.home() / ".hermes" / "cache" / "scratch" / "rekvisita3d"

## Spelets pixelstorlek (game/main.gd: DEKOR_PIXEL) — 128 arkpixlar per meter.
PX = 0.008

# Palettens index (samma fil som rutorna, fienderna och gen_props.py).
INK, DARK, MORTAR = 1, 2, 3
STONE_D, STONE, STONE_L, EDGE_L, PALE = 4, 5, 6, 7, 8
RED_D, RED, RED_L = 9, 10, 11
EMBER, FLAME, GLOW = 12, 13, 14
MOSS = 15
DIRT_D, DIRT, WOOD_L = 16, 17, 18
BONE, BONE_L = 22, 23
## IRON_MÖRK är inget palettnamn: paletten har ingen mörk järnton, så skuggan i järnet ritas med
## DIRT_D (den varma mörkbruna som arket själv använder i metallen). Ett eget påhittat värde hade
## brutit palettregeln som `--kolla` prövar.
IRON, IRON_MÖRK = 24, 16

# Boxens sex ytor, vindade utåt (samma ordning som tools/byn3d.py).
FACES = ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7))


def färg8(pal: list, i: int) -> tuple[int, int, int]:
    """Palettens 8-bitstal, med samma kläm som spelets Palett.c()."""
    return pal[max(0, min(len(pal) - 1, i))]


class Bygge:
    """En rekvisit som en lista hörn, ytor och en palettfärg per yta."""

    def __init__(self, namn: str) -> None:
        self.namn = namn
        self.hörn: list[tuple[float, float, float]] = []
        self.ytor: list[tuple[int, ...]] = []
        self.färger: list[int] = []
        self.rutor = 0
        ## Ytintervall som är LÅGA (M149). Glöden sitter i ett EGET material i stället för i en
        ## färgregel: då är det bygget — inte en gissning om paletten — som avgör vad som lyser.
        self.lågor: list[tuple[int, int]] = []

    # ---------------------------------------------------------------- primitiver

    def låda(self, mitt, mått, färg: int, m: Matrix | None = None) -> None:
        """Ett rätblock kring `mitt` (px), `m` vrider det kring sin egen mitt."""
        hx, hy, hz = mått[0] / 2.0, mått[1] / 2.0, mått[2] / 2.0
        if hx <= 0 or hy <= 0 or hz <= 0:
            raise SystemExit("FEL: %s fick en låda utan mått %s" % (self.namn, mått))
        hörn = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
                (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        n = len(self.hörn)
        for p in hörn:
            q = (m @ Vector(p)) if m is not None else Vector(p)
            self.hörn.append((q.x + mitt[0], q.y + mitt[1], q.z + mitt[2]))
        for yta in FACES:
            self.ytor.append(tuple(n + i for i in yta))
            self.färger.append(färg)
        self.rutor += 1

    def _ring_hörn(self, n: int, radie: float, z: float, m: Matrix | None) -> list[Vector]:
        ut = []
        for i in range(n):
            a = 2.0 * math.pi * i / n
            p = Vector((math.cos(a) * radie, math.sin(a) * radie, z))
            ut.append((m @ p) if m is not None else p)
        return ut

    def prisma(self, mitt, radie: float, höjd: float, färg: int, sidor: int = 8,
               m: Matrix | None = None) -> None:
        """En sluten n-hörning kring `mitt`, från -höjd/2 till +höjd/2."""
        n = len(self.hörn)
        for z in (-höjd / 2.0, höjd / 2.0):
            for p in self._ring_hörn(sidor, radie, z, m):
                self.hörn.append((p.x + mitt[0], p.y + mitt[1], p.z + mitt[2]))
        for i in range(sidor):
            j = (i + 1) % sidor
            self.ytor.append((n + i, n + j, n + sidor + j, n + sidor + i))   # sida, utåt
            self.färger.append(färg)
        botten = len(self.hörn)
        self.hörn.append((mitt[0], mitt[1], mitt[2] - höjd / 2.0))
        topp = len(self.hörn)
        self.hörn.append((mitt[0], mitt[1], mitt[2] + höjd / 2.0))
        for i in range(sidor):
            j = (i + 1) % sidor
            self.ytor.append((botten, n + j, n + i))
            self.färger.append(färg)
            self.ytor.append((topp, n + sidor + i, n + sidor + j))
            self.färger.append(färg)
        self.rutor += 1

    def rör(self, p0, p1, radie: float, färg: int, sidor: int = 6) -> None:
        """En cylinder mellan två punkter — stag, kedjelänkar, ben."""
        a, b = Vector(p0), Vector(p1)
        d = b - a
        längd = d.length
        if längd < 0.01:
            return
        m = d.to_track_quat("Z", "Y").to_matrix()
        n = len(self.hörn)
        for z in (0.0, längd):
            for p in self._ring_hörn(sidor, radie, z, m):
                self.hörn.append((p.x + a.x, p.y + a.y, p.z + a.z))
        for i in range(sidor):
            j = (i + 1) % sidor
            self.ytor.append((n + i, n + j, n + sidor + j, n + sidor + i))
            self.färger.append(färg)
        botten = len(self.hörn)
        self.hörn.append(tuple(a))
        topp = len(self.hörn)
        self.hörn.append(tuple(b))
        for i in range(sidor):
            j = (i + 1) % sidor
            self.ytor.append((botten, n + j, n + i))
            self.färger.append(färg)
            self.ytor.append((topp, n + sidor + i, n + sidor + j))
            self.färger.append(färg)
        self.rutor += 1

    def ring(self, mitt, yttre: float, inre: float, höjd: float, färg: int, sidor: int = 12,
             m: Matrix | None = None) -> None:
        """Ett ihåligt rör (band, takring, kedjelänk) kring `mitt`."""
        if inre <= 0 or inre >= yttre:
            raise SystemExit("FEL: %s fick en ring med radierna %s/%s" % (self.namn, yttre, inre))
        n = len(self.hörn)
        for i in range(sidor):
            a = 2.0 * math.pi * i / sidor
            for r in (yttre, inre):
                for z in (-höjd / 2.0, höjd / 2.0):
                    p = Vector((math.cos(a) * r, math.sin(a) * r, z))
                    p = (m @ p) if m is not None else p
                    self.hörn.append((p.x + mitt[0], p.y + mitt[1], p.z + mitt[2]))
        # hörnindex: i*4 + (0 = yttre botten, 1 = inre botten, 2 = yttre topp, 3 = inre topp)
        for i in range(sidor):
            j = (i + 1) % sidor
            ob, ib, ot, it = n + i * 4, n + i * 4 + 1, n + i * 4 + 2, n + i * 4 + 3
            ob2, ib2, ot2, it2 = n + j * 4, n + j * 4 + 1, n + j * 4 + 2, n + j * 4 + 3
            self.ytor.append((ob, ob2, ot2, ot))          # yttervägg
            self.färger.append(färg)
            self.ytor.append((ib, it, it2, ib2))          # innervägg
            self.färger.append(färg)
            self.ytor.append((ob, ot, it, ib))            # överkant
            self.färger.append(färg)
            self.ytor.append((ob2, ib2, it2, ot2))        # underkant
            self.färger.append(färg)
        self.rutor += 1

    def låga(self, mitt, bredd: float, höjd: float) -> None:
        """En låga i fyra steg som smalnar till en SPETS (EMBER/FLAME/FLAME/GLOW).

        Tre lika tjocka klumpar läses som en orange hatt på ljuset; det är spetsen som gör lågan.
        """
        z = mitt[2]
        först = len(self.ytor)
        for andel, radie, färg_i in ((0.38, 0.52, EMBER), (0.30, 0.38, FLAME),
                                     (0.20, 0.24, FLAME), (0.12, 0.10, GLOW)):
            h = höjd * andel
            self.prisma((mitt[0], mitt[1], z + h / 2.0), bredd * radie, h, färg_i, 6)
            z += h
        self.lågor.append((först, len(self.ytor)))

    def revben(self, mitt, radie: float, färg: int, antal: int = 5, vid: float = 2.0) -> None:
        """En båge av små klossar i XY-planet — ett revben, inte en bjälke."""
        for i in range(antal):
            a = math.radians(-100.0 + 200.0 * i / max(1, antal - 1))
            m = Matrix.Rotation(a, 3, "Z")
            p = Vector((math.cos(a) * radie, math.sin(a) * radie * 0.7, 0.0))
            self.låda((mitt[0] + p.x, mitt[1] + p.y, mitt[2]), (vid, vid * 1.4, vid), färg, m)


def töm_scenen() -> None:
    """--factory-startup ger en kub, ett ljus och en kamera. Bort med dem."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for samling in (bpy.data.meshes, bpy.data.materials):
        for d in list(samling):
            if d.users == 0:
                samling.remove(d)


# ------------------------------------------------------------------ rekvisiten


def gräs(b: Bygge) -> None:
    """En tuva: en låg klump och sju SMALA strån med glipor emellan (16x12x26 px).

    Stråna är tre smalnande stycken (1,8 → 1,4 → 1,0 px) med luft mellan sig. Första försöket hade
    2,4 px breda blad utan glipor, och då blev tuvan en grön kub — en tuva känns igen på att man ser
    MELLAN bladen. Den torra toppen är BONE, som i arket.
    """
    b.låda((8, 6, 0.6), (16, 12, 1.2), INK)
    b.låda((8, 6, 3.4), (12, 9.0, 4.8), MOSS)
    b.låda((8, 6, 6.4), (8, 7.0, 2.2), MOSS)
    b.låda((8, 8.8, 3.8), (10, 2.2, 6.0), DIRT_D)
    for x, y, topp, lut in ((1.6, 5.0, 13.0, -0.42), (3.6, 7.0, 17.0, -0.20),
                            (5.8, 4.6, 21.0, -0.08), (8.0, 6.4, 26.0, 0.02),
                            (10.2, 4.8, 22.5, 0.18), (12.4, 7.0, 18.0, 0.34),
                            (14.2, 5.2, 14.5, 0.46)):
        h = topp - 8.0
        if h <= 0:
            continue
        z = 8.0
        for andel, bredd, djup in ((0.50, 1.8, 2.6), (0.33, 1.4, 2.2), (0.17, 1.0, 1.8)):
            hh = h * andel
            m = Matrix.Rotation(lut * (0.4 + z / 26.0), 3, "Y")
            b.låda((x + math.sin(lut) * (z - 8.0) * 0.6, y, z + hh / 2.0),
                   (bredd, djup, hh + 0.2), BONE if andel == 0.17 else MOSS, m)
            z += hh
    for x, y, a in ((3.0, 9.4, 74.0), (13.0, 9.0, -68.0)):        # två torra strån på marken
        b.låda((x, y, 1.8), (5.0, 1.0, 1.0), BONE, Matrix.Rotation(math.radians(a), 3, "Y"))


def rot(b: Bygge) -> None:
    """En rot som vuxit fram ur en springa: gaffelformad, avsmalnande, vågig (26x14x10 px).

    Första försöket var tolv lika stycken med fyra jämnt utspridda pinnar — det läste som en
    kam. En rot DELAR sig: en stam som går ut i en gaffel, en sned rotstubbe upp ur marken och
    några tunna hårstrån. Allt avsmalnar utåt.
    """
    b.låda((13, 7, 0.5), (26, 14, 1.0), INK)

    def sträcka(x0, y0, z0, x1, y1, z1, r0, r1, färg) -> None:
        längd = math.hypot(x1 - x0, y1 - y0)
        a = math.degrees(math.atan2(y1 - y0, x1 - x0))
        for i in range(5):
            u = (i + 0.5) / 5.0
            x, y, z = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, z0 + (z1 - z0) * u
            r = r0 + (r1 - r0) * u
            b.låda((x, y, z), (längd / 5.0 + 0.5, r * 2.4, r * 2.0), färg,
                   Matrix.Rotation(math.radians(a), 3, "Z"))
            b.låda((x, y, z + r * 0.9), (längd / 5.0 + 0.5, r * 2.0, r * 0.5), WOOD_L,
                   Matrix.Rotation(math.radians(a), 3, "Z"))
            b.låda((x, y + r * 0.9, z - r * 0.2), (längd / 5.0 + 0.5, r * 0.7, r * 1.2), DIRT_D,
                   Matrix.Rotation(math.radians(a), 3, "Z"))

    sträcka(0.4, 8.0, 2.4, 16.0, 7.0, 2.8, 2.3, 1.7, DIRT)        # stammen
    sträcka(16.0, 7.0, 2.8, 25.6, 10.2, 1.8, 1.7, 0.8, DIRT)      # gaffel, nedre
    sträcka(16.0, 7.0, 2.8, 20.4, 3.2, 2.2, 1.5, 0.7, DIRT)       # gaffel, övre
    sträcka(9.0, 7.0, 3.6, 12.4, 6.2, 9.2, 1.3, 0.7, DIRT_D)      # stubben upp ur marken
    for x0, y0, x1, y1 in ((4.0, 7.4, 1.0, 4.4), (17.0, 8.4, 22.0, 13.0), (7.0, 5.6, 3.0, 1.4)):
        sträcka(x0, y0, 1.2, x1, y1, 0.9, 0.7, 0.4, DIRT_D)       # rotstrån


def mossa(b: Bygge) -> None:
    """En mosskudde: en mjuk massa med OJÄMN kant, inte en grön låda (18x12x8 px).

    Kuddarna är sju och ligger omlott, och kanten är kantad av tio små puckel — en jämn kant läses
    som en bänk. Den bruna listen under var för stor och blev en egen sak; nu är skuggan en tunn
    linje längst ned och det bruna bara fläckar.
    """
    b.låda((9, 6, 0.4), (18, 12, 0.8), INK)
    for x, y, rx, ry, h, v in ((6.0, 6.0, 8.0, 8.0, 3.0, -8), (11.4, 6.4, 8.0, 7.0, 4.4, 6),
                               (8.4, 5.0, 6.4, 5.6, 5.6, 12), (13.8, 4.8, 4.2, 5.0, 3.6, -14),
                               (3.2, 5.2, 4.2, 5.6, 2.4, 4), (9.4, 8.4, 6.2, 4.0, 2.6, -6),
                               (13.0, 8.6, 3.4, 3.6, 2.0, 18)):
        b.låda((x, y, 0.8 + h / 2.0), (rx, ry, h), MOSS, Matrix.Rotation(math.radians(v), 3, "Z"))
    for i in range(10):                                          # pucklar längs kanten
        a = math.radians(36.0 * i)
        x, y = 9.0 + math.cos(a) * 7.4, 6.0 + math.sin(a) * 4.6
        b.låda((x, y, 1.5), (2.6, 2.2, 2.0), MOSS, Matrix.Rotation(a, 3, "Z"))
    for x, y, z, f in ((4.0, 4.0, 3.2, STONE_D), (8.2, 7.0, 6.2, DIRT_D),
                       (11.8, 5.0, 6.0, BONE), (13.2, 7.6, 3.0, STONE_D),
                       (6.2, 8.4, 2.4, DIRT_D), (10.0, 9.2, 2.0, MOSS)):
        b.låda((x, y, z), (1.4, 1.4, 1.2), f)


def småsten(b: Bygge) -> None:
    """Nio LÅGA stenar i en springa — grus, inte en mur (12x8x7 px).

    Den stora stenen var 6 px hög på 12 px bredd och läste som en rest sten. Nu ligger den största
    på 4,2 px, de andra under 3, och några sitter halvt nere i INK-kanten.
    """
    b.låda((6, 4, 0.4), (12, 8, 0.8), INK)
    for x, y, r, h, f, a in ((2.4, 3.6, 1.5, 3.2, STONE, 10), (5.0, 4.4, 2.0, 5.8, STONE_L, 24),
                             (8.2, 3.2, 1.5, 2.8, STONE, 52), (10.4, 4.8, 1.3, 2.4, STONE_D, 8),
                             (7.0, 6.2, 1.2, 2.0, STONE, 70), (3.8, 6.2, 1.0, 1.6, STONE_D, 40),
                             (9.6, 6.6, 1.0, 1.6, STONE_L, 30), (1.4, 6.0, 0.9, 1.4, STONE, 60),
                             (11.4, 2.4, 0.9, 1.4, STONE_D, 80)):
        b.prisma((x, y, 0.6 + h / 2.0), r, h, f, 8, Matrix.Rotation(math.radians(a), 3, "Z"))
    b.låda((5.0, 4.4, 6.2), (1.8, 1.6, 0.6), EDGE_L, Matrix.Rotation(math.radians(24), 3, "Z"))
    b.låda((8.2, 3.2, 2.5), (1.2, 1.0, 0.4), PALE, Matrix.Rotation(math.radians(52), 3, "Z"))


def bur(b: Bygge) -> None:
    """En bur med skelett, hängande i taket (30x24x88 px).

    BREDDEN ÄR BURENS, INTE KANVASENS (M150). Arket är 68 px brett men själva buren bara 39 px —
    marginalerna runt om är tomma. Första modellen byggdes till kanvasen och blev 68 px bred, alltså
    58 % för vid: i spel såg den ut som en tunna och skelettet simmade omkring inuti. Alex: *"De är
    alldeles för vida, de behöver vara MYCKET smalare, så skelettet får trängas."* Nu är buren 30 px
    (0,24 m) och skelettet 13 px över revbenen mot 13,3 px innanför stängerna — det tar i, och det är
    meningen.

    Kontrasten bär läsbarheten på 480x270: stängerna är MÖRK metall (IRON_MÖRK med IRON som kant) och
    benen ljusa (BONE_L), annars går skelettet i ett med buren. Kedjan är sju länkar i växlande plan —
    fem korta läses som ett pärlband.
    """
    cx, cy = 16.0, 12.0
    ellips = Matrix.Diagonal((1.0, 0.75, 1.0)).to_3x3()
    # Hake och kedja: sju länkar, varannan vriden ett kvarts varv.
    b.låda((cx, cy, 92.0), (2.2, 2.2, 2.4), IRON_MÖRK)
    b.ring((cx, cy, 90.0), 3.4, 1.8, 1.8, IRON, 10)
    for i in range(6):
        z = 88.0 - i * 4.0
        m = Matrix.Rotation(math.radians(90), 3, "X" if i % 2 == 0 else "Y")
        m = m @ Matrix.Diagonal((1.0, 1.0, 1.5)).to_3x3()
        b.ring((cx, cy, z), 3.2, 1.6, 1.3, IRON if i % 2 else IRON_MÖRK, 8, m)
    # Kupolen: trappsteg som smalnar uppåt, med sex ribbor över — en plan skiva läses som ett lock.
    for z, r in ((67.2, 12.2), (68.8, 9.4), (70.2, 6.4)):
        b.prisma((cx, cy, z), r, 1.6, IRON_MÖRK, 14, ellips)
    b.prisma((cx, cy, 71.6), 2.6, 2.0, IRON, 8)                    # knoppen överst
    b.prisma((cx, cy, 65.8), 14.8, 2.2, IRON_MÖRK, 16, ellips)
    b.ring((cx, cy, 66.8), 15.0, 12.6, 1.0, IRON, 16, ellips)
    for i in range(6):
        a = 2.0 * math.pi * i / 6.0
        x, y = cx + math.cos(a) * 11.0, cy + math.sin(a) * 11.0 * 0.75
        b.rör((x * 0.35 + cx * 0.65, y * 0.35 + cy * 0.65, 71.2), (x, y, 66.6), 1.2, IRON, 6)
    # Stängerna: sex, mörk metall — de ska rama in skelettet, inte smälta in i det.
    for i in range(6):
        a = 2.0 * math.pi * i / 6.0
        x, y = cx + math.cos(a) * 14.0, cy + math.sin(a) * 14.0 * 0.75
        b.rör((x, y, 9.0), (x, y, 64.6), 1.4, IRON_MÖRK, 8)
    for z, h in ((10.0, 2.2),):   # inget band på mitten: det skar rakt genom revbenen (M150)
        b.ring((cx, cy, z), 15.0, 13.2, h, IRON_MÖRK, 14, ellips)
        b.ring((cx, cy, z + h / 2.0), 15.1, 13.3, 0.8, IRON, 14, ellips)
    b.prisma((cx, cy, 6.2), 12.4, 2.4, IRON_MÖRK, 14, ellips)
    b.ring((cx, cy, 8.0), 14.4, 12.2, 1.2, IRON, 14, ellips)
    # SKELETTET: 22 px över revbenen mot 26,6 px innanför stängerna (radie 14 minus stav 0,7).
    # Räkna i BREDD, inte i radie — första försöket satte 12,6 px revben och kallade det trångt; det
    # var halva buren. Skallen nära taket, armarna upp (hänger), ena benet böjt.
    sy = cy - 1.0
    b.låda((cx, sy, 54.6), (10.0, 7.0, 8.8), BONE_L)               # skallen: ljusast i buren
    b.låda((cx, sy + 0.2, 50.2), (8.4, 6.0, 2.4), BONE)            # käken
    for dx in (-2.5, 2.5):
        b.låda((cx + dx, sy - 3.6, 56.2), (2.4, 1.2, 3.0), INK)    # ögonhålorna
    b.låda((cx, sy - 3.7, 52.8), (1.6, 1.0, 1.4), INK)
    b.rör((cx, sy, 38.0), (cx, sy, 49.4), 2.0, BONE_L, 6)          # ryggraden
    # Revbenen som TVÄRGÅENDE band (se `revben`: bågen passar benhögen på golvet, inte en bur sedd
    # framifrån). 22 px breda = 2 px luft mot stängerna på var sida.
    for z, bredd in ((48.6, 17.0), (46.4, 21.0), (44.2, 22.0), (42.0, 22.0), (39.8, 20.4), (37.6, 17.6)):
        b.låda((cx, sy, z), (bredd, 5.0, 1.5), BONE_L)
    b.låda((cx, sy - 2.6, 43.0), (2.4, 1.4, 11.6), BONE)           # bröstbenet
    for dx in (-3.6, 3.6):
        b.låda((cx + dx, sy, 33.0), (4.0, 4.0, 3.4), BONE)         # bäckenet
    for dx in (-1, 1):
        b.rör((cx + dx * 5.2, sy, 49.0), (cx + dx * 6.4, sy, 61.0), 1.8, BONE_L, 6)
        b.låda((cx + dx * 6.4, sy, 62.4), (3.2, 2.8, 3.0), BONE)   # händerna ovanför huvudet
    b.rör((cx - 3.2, sy, 31.4), (cx - 4.2, sy, 11.0), 1.8, BONE_L, 6)
    b.rör((cx + 3.2, sy, 31.4), (cx + 5.2, sy + 0.4, 19.0), 1.8, BONE_L, 6)   # ena benet böjt
    b.låda((cx - 4.6, sy - 0.6, 9.0), (3.6, 2.6, 2.6), BONE, Matrix.Rotation(math.radians(16), 3, "Y"))
    b.låda((cx + 6.0, sy + 0.8, 17.2), (3.4, 2.6, 2.6), BONE)


def kandelaber(b: Bygge) -> None:
    """En kandelaber i taket: nav, fyra armar med ljushållare och en liten droppe i mitten.

    Alex' ark visar en krona sedd underifrån: kedja i mitten, nav, fyra armar ut till var sin stake
    med ljus. Första versionen hade en FOTPLATTA under varje ljus och en ring mellan armändarna —
    det läste som en stående fyrskaftad ljusstake. Nu slutar armen i en UPPÅTVÄND hållare (en skål
    med ljuset i), det finns ingen ring vid golvet, och mittdroppen är liten: en krona hänger.
    """
    cx, cy = 44.0, 26.0
    b.låda((cx, cy, 51.0), (12.0, 12.0, 2.0), IRON)                  # takplattan
    b.låda((cx, cy, 49.7), (9.0, 9.0, 0.8), EDGE_L)
    for i, z in enumerate((47.0, 41.8, 36.6)):
        m = Matrix.Rotation(math.radians(90), 3, "X" if i % 2 == 0 else "Y")
        m = m @ Matrix.Diagonal((1.0, 1.0, 1.4)).to_3x3()
        b.ring((cx, cy, z), 5.0, 2.8, 1.4, IRON if i % 2 else IRON_MÖRK, 10, m)
    # Navet: tolvkant med ljus överkant, knopp i mitten och en liten droppe under.
    b.prisma((cx, cy, 30.0), 9.5, 6.0, IRON, 12)
    b.prisma((cx, cy, 33.4), 8.2, 1.0, EDGE_L, 12)
    b.prisma((cx, cy, 26.6), 7.0, 1.0, IRON_MÖRK, 12)
    b.prisma((cx, cy, 30.0), 3.2, 3.0, EDGE_L, 8)   # knoppen: metall, inte vax (M149)
    b.rör((cx, cy, 6.0), (cx, cy, 27.0), 1.6, IRON, 8)
    b.prisma((cx, cy, 4.0), 3.6, 4.0, IRON, 10)
    b.prisma((cx, cy, 1.0), 2.2, 2.0, IRON_MÖRK, 8)
    # Fyra LIKADANA armar (kronan är rund): samma vinkel och samma längd, annars läses den som
    # en sned, trasig ställning. Armen går in i navet och slutar i en uppåtvänd ljushållare.
    for i in range(4):
        a = math.radians(90.0 * i)
        m = Matrix.Rotation(a, 3, "Z")
        ex, ey = cx + math.cos(a) * 34.0, cy + math.sin(a) * 34.0
        dx, dz = 27.0, 17.5 - 29.0
        längd = math.sqrt(dx * dx + dz * dz)
        mitt = (cx + math.cos(a) * 20.5, cy + math.sin(a) * 20.5, (29.0 + 17.5) / 2.0)
        lut = Matrix.Rotation(math.atan2(dz, dx), 3, "Y")
        b.låda(mitt, (längd, 4.4, 3.4), IRON, m @ lut)
        b.låda((ex, ey, 18.2), (5.4, 5.4, 1.8), IRON_MÖRK)           # svetsfogen mot armen
        b.prisma((ex, ey, 19.6), 3.4, 3.6, IRON, 8)                  # hållarens hals
        b.prisma((ex, ey, 21.8), 5.6, 1.2, EDGE_L, 12)               # droppskålen
        b.låda((ex, ey, 26.6), (5.0, 5.0, 9.0), PALE)                # ljuset
        b.låda((ex + 1.8, ey, 26.6), (1.2, 5.0, 8.6), DIRT_D)
        b.låga((ex, ey, 31.1), 5.5, 6.0)      # SMÅ lågor (M149): toppen, inte hela staken


def spricka_eld(b: Bygge) -> None:
    """En spricka i GOLVET med eld: brutna hällar och en glödande klyfta (64x64x14 px).

    Arket visar en spricka i en VÄGG, men spelet lägger rekvisiten på en golvruta. Hällarna ligger i
    ett 4x4-rutnät där VARJE häll är delad i två halvor med olika höjd, och klyftan går i RAKA
    STYCKEN med skarpa riktningsbyten — en mjukt slingrande klyfta läses som en virvel (arket).
    """
    b.låda((32, 32, 0.5), (64, 64, 1.0), INK)
    bryt = ((4, 54), (12, 44), (19, 48), (28, 35), (37, 41), (45, 28), (52, 32), (60, 15))
    def klyfta(y: float) -> float:
        for (y0, x0), (y1, x1) in zip(bryt, bryt[1:]):
            if y0 <= y <= y1:
                return x0 + (x1 - x0) * (y - y0) / max(1, y1 - y0)
        return bryt[-1][1]

    for gx in range(4):
        for gy in range(4):
            for halva in (0, 1):
                x = gx * 16.0 + 8.0 + (halva * 8.0 - 4.0)
                y = gy * 16.0 + 8.0
                # Hällen krymper mot klyftan: kanten följer sprickan i trappsteg.
                kant = klyfta(y + (halva * 2 - 1) * 7.0)
                avstånd = abs(x - kant)
                if avstånd < 6.5:
                    continue
                h = 4.8 - 0.6 * ((gx + gy + halva) % 3)
                f = (STONE, STONE_D, STONE_L, STONE_D)[(gx * 3 + gy + halva) % 4]
                b.låda((x, y, 1.0 + h / 2.0), (7.4, 14.6, h), f)
                b.låda((x, y, 0.4 + h), (7.4, 14.6, 0.7), STONE_L if f != STONE_L else EDGE_L)
    # Klyftan: glödbädd längs de raka styckena, med kolsvart kant och eldtungor.
    for (y0, x0), (y1, x1) in zip(bryt, bryt[1:]):
        steg = max(1, int(abs(y1 - y0) / 4))
        for i in range(steg):
            t = (i + 0.5) / steg
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            b.låda((x, y, 2.2), (5.6, 6.0, 2.0), INK, Matrix.Rotation(math.atan2(-(x1 - x0), y1 - y0), 3, "Z"))
            b.låda((x, y, 3.2), (4.2, 4.8, 1.2), RED_D, Matrix.Rotation(math.atan2(-(x1 - x0), y1 - y0), 3, "Z"))
            b.låda((x, y, 4.0), (2.6, 3.2, 0.8), EMBER, Matrix.Rotation(math.atan2(-(x1 - x0), y1 - y0), 3, "Z"))
    for t, h in ((0.06, 7.0), (0.30, 9.6), (0.52, 7.4), (0.74, 10.0), (0.92, 6.0)):
        y = 58.0 - 52.0 * t
        b.låga((min(60.0, max(4.0, klyfta(y) + 0.4)), y, 4.2), 5.6, h)
    for y, sida in ((12, -1), (22, 1), (36, -1), (50, 1)):
        x = klyfta(y)
        b.låda((x + sida * 5.0, y, 5.0), (3.0, 3.4, 1.8), STONE_D,
               Matrix.Rotation(math.radians(24 * sida), 3, "Z"))


def spade(b: Bygge) -> None:
    """En spade som står i golvet: T-handtag, skaft, holk, fotstöd och skålformat blad (24x8x64 px)."""
    cx, cy = 12.0, 4.0
    b.låda((cx, cy, 60.5), (16.0, 4.0, 4.0), WOOD_L)
    b.låda((cx, cy, 62.2), (13.0, 3.2, 1.2), WOOD_L)
    b.låda((cx, cy, 58.7), (14.0, 3.4, 1.2), DIRT_D)
    for dx in (-10.0, 10.0):
        b.prisma((cx + dx, cy, 60.5), 2.0, 3.8, INK, 6, Matrix.Rotation(math.radians(90), 3, "Y"))
    b.rör((cx, cy, 23.0), (cx, cy, 57.0), 1.7, WOOD_L, 8)
    b.rör((cx + 1.2, cy + 0.8, 23.0), (cx + 1.2, cy + 0.8, 57.0), 0.8, DIRT_D, 6)
    b.låda((cx, cy, 21.0), (8.0, 5.0, 6.0), STONE)
    b.låda((cx, cy, 23.7), (8.4, 5.2, 1.0), EDGE_L)
    b.låda((cx, cy, 18.4), (8.4, 5.2, 1.0), STONE_D)
    for dx in (-2.4, 2.4):
        b.låda((cx + dx, cy - 2.6, 21.0), (1.4, 0.8, 1.4), MORTAR)
    for dx in (-9.0, 9.0):
        b.låda((cx + dx, cy, 17.4), (6.0, 6.0, 1.6), STONE)
        b.låda((cx + dx, cy, 18.3), (6.0, 6.0, 0.6), EDGE_L)
    # Bladet: brett upptill, rundad spets OCH en skål — tre lager som viker framåt i djupet.
    for z0, z1, bredd in ((11.0, 16.4, 18.0), (6.0, 11.0, 15.0), (2.4, 6.0, 10.0), (0.0, 2.4, 6.0)):
        b.låda((cx, cy - 0.4, (z0 + z1) / 2.0), (bredd, 2.4, z1 - z0), STONE)
        b.låda((cx, cy - 1.6, (z0 + z1) / 2.0), (bredd - 1.4, 1.2, z1 - z0), STONE_L)
        b.låda((cx, cy + 1.0, (z0 + z1) / 2.0), (bredd - 1.0, 1.0, z1 - z0), STONE_D)
    b.låda((cx - 4.6, cy - 2.0, 13.2), (2.2, 0.9, 5.0), PALE)
    for dx, dz in ((-8.0, 14.6), (7.4, 12.8), (-5.2, 7.0)):
        b.låda((cx + dx, cy - 1.4, dz), (2.6, 1.8, 2.6), DIRT_D)


def benhög(b: Bygge) -> None:
    """Bossens märke: en TÄT hög av ben med skallen vilande på (64x32x32 px).

    Skallen låg förut ovanför högen med luft under sig och läste som ett svävande huvud; en hög
    med tolv korta ben i tre lager under den läses som en hög. Benen har leder i ändarna (ben utan
    leder är pinnar i ett staket), och inget sticker upp som en påle.
    """
    b.låda((32, 16, 0.5), (62, 30, 1.0), INK)
    ben = ((9, 12, -14, 16, 3.0), (24, 10, 6, 14, 2.6), (43, 9, -8, 16, 3.2),
           (52, 14, 26, 13, 2.8), (16, 21, 12, 15, 3.4), (34, 22, -20, 14, 2.8),
           (47, 24, 8, 12, 3.0), (12, 26, -4, 11, 5.0), (29, 17, 74, 12, 5.2),
           (40, 20, -66, 13, 5.4), (21, 15, 40, 10, 5.6), (50, 19, 52, 10, 5.8))
    for x, y, a, längd, z in ben:
        m = Matrix.Rotation(math.radians(a), 3, "Z")
        dx, dy = math.cos(math.radians(a)) * längd / 2.0, math.sin(math.radians(a)) * längd / 2.0
        b.rör((x - dx, y - dy, z), (x + dx, y + dy, z), 1.9, BONE, 6)
        for s in (-1, 1):
            b.låda((x + s * dx, y + s * dy, z + 0.4), (3.4, 3.4, 3.2), BONE_L, m)
    # Bäcken och revben: högens mitt, med skallen vilande ovanpå.
    for dx in (-3.4, 3.4):
        b.låda((33.0 + dx, 15.0, 9.0), (4.2, 5.0, 3.6), BONE, Matrix.Rotation(math.radians(-12), 3, "Z"))
    b.rör((33.0, 15.0, 8.0), (33.0, 15.0, 19.0), 1.8, BONE, 8)
    for z, r in ((12.0, 6.4), (15.0, 7.4), (18.0, 6.2)):
        b.revben((33.0, 15.0, z), r, BONE_L, 5, 1.9)
    # Skallen: underkanten i lagret (vilar, svävar inte), med näsa, käke och tänder.
    b.låda((36.0, 14.0, 23.4), (16.0, 13.0, 12.0), BONE)
    b.låda((36.0, 14.0, 28.8), (13.4, 11.4, 1.3), BONE_L)
    b.låda((36.0, 13.6, 16.9), (12.6, 11.8, 2.8), BONE)
    for dx in (-3.4, 2.6):
        b.låda((36.0 + dx, 7.0, 24.6), (4.0, 1.6, 3.4), INK)
    b.låda((36.0, 6.6, 20.2), (2.2, 1.4, 2.2), INK)
    for dx in (-4.0, -1.4, 1.2, 3.8):
        b.låda((36.0 + dx, 7.8, 15.4), (1.8, 1.2, 2.4), BONE_L)
    b.låda((36.0, 20.6, 21.0), (11.6, 2.0, 8.4), DIRT_D, Matrix.Rotation(math.radians(-8), 3, "X"))
    # Två ben som lutar mot skallen (korta — inget sticker upp som en påle).
    for x, y, a in ((48.0, 22.0, 58.0), (52.0, 10.0, -54.0)):
        m = math.radians(a)
        b.rör((x, y, 7.0), (x + math.cos(m) * 9.0, y + math.sin(m) * 9.0, 20.0), 1.9, BONE, 6)
    b.låda((32.0, 26.0, 4.0), (10.0, 2.0, 1.4), DIRT_D)


## art -> (bredd, djup, höjd i arkpixlar, byggfunktion). Djupet är designat: arket är platt.
PROPS = {
    "gräs": (16, 12, 26, gräs),
    "rot": (26, 14, 10, rot),
    "mossa": (18, 12, 8, mossa),
    "småsten": (12, 8, 7, småsten),
    "bur": (30, 24, 88, bur),   # 30 px bred (kanvasen är 68), 88 = det bygget spänner
    "kandelaber": (80, 80, 52, kandelaber),
    "spricka_eld": (64, 64, 14, spricka_eld),
    "shovel": (24, 6, 64, spade),
    "boss": (64, 30, 30, benhög),
}


## Vilka rekvisiter som LYSer (M149). Bara de får en lågyta, och bara lågytan lyser i spelet —
## allt annat på modellen är fast material, hur varm färgen än är.
LYSER = {"kandelaber", "spricka_eld"}

# ------------------------------------------------------------------ mesh och material


def material(namn: str = "rekvisita") -> "bpy.types.Material":
    """Materialet för en rekvisit: färgen bor i hörnen (COLOR_0), inte i materialet.

    `låga` är det ENDA som skiljer: samma vertexfärg, men med emission, så `--bild` visar samma
    glöd som spelet ritar. I Godot byts ytan mot glöd-shadern (se `Main._dekor_nod`).
    """
    mat = bpy.data.materials.get(namn)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(namn)
    mat.use_nodes = True
    noder = mat.node_tree.nodes
    bsdf = noder["Principled BSDF"]
    attribut = noder.new("ShaderNodeVertexColor")
    attribut.layer_name = "Col"
    mat.node_tree.links.new(attribut.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
    if namn == "låga":
        mat.node_tree.links.new(attribut.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 0.6
    return mat


def gör_objekt(art: str, b: Bygge, pal: list) -> "bpy.types.Object":
    """Bygget blir EN mesh, centrerad kring sitt eget origo (som quadden den ersätter)."""
    xs = [p[0] for p in b.hörn]
    ys = [p[1] for p in b.hörn]
    zs = [p[2] for p in b.hörn]
    cx, cy, cz = (min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0, (min(zs) + max(zs)) / 2.0
    hörn = [((x - cx) * PX, (y - cy) * PX, (z - cz) * PX) for x, y, z in b.hörn]
    mesh = bpy.data.meshes.new(art)
    mesh.from_pydata(hörn, [], b.ytor)
    mesh.validate()
    mesh.materials.append(material())
    if b.lågor:
        mesh.materials.append(material("låga"))
    col = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    lågindex = {i for a, b_ in b.lågor for i in range(a, b_)}
    for i, (poly, färg_i) in enumerate(zip(mesh.polygons, b.färger)):
        if i in lågindex:
            poly.material_index = 1
        r, g, bl = färg8(pal, färg_i)
        for li in poly.loop_indices:
            col.data[li].color = (r / 255.0, g / 255.0, bl / 255.0, 1.0)
    # Platta ytor med flit: voxelstilen har inga rundningar, och en slät skugga hade gömt formen.
    obj = bpy.data.objects.new(art, mesh)
    return obj


# ------------------------------------------------------------------ scenen och proven


def bygg_alla(pal: list, samling) -> dict:
    """Bygger alla rekvisiter i samlingen. Returnerar art -> (objekt, mått i meter)."""
    ut = {}
    for art, (w, d, h, fn) in PROPS.items():
        b = Bygge(art)
        fn(b)
        obj = gör_objekt(art, b, pal)
        samling.objects.link(obj)
        mått = obj.dimensions
        ut[art] = (obj, (mått.x, mått.y, mått.z), b.rutor)
    return ut


def kolla(ut: dict, pal: list) -> list[str]:
    """Proven: form, djup, färger och att varje nod har en mesh och en vertexfärg."""
    fel = []
    for art, (obj, mått, rutor) in ut.items():
        w, d, h = mått
        väntad = [v * PX for v in PROPS[art][:3]]
        if len(obj.data.polygons) < 12:
            fel.append("%s: bara %d ytor" % (art, len(obj.data.polygons)))
        for namn, fick, vänt in (("bredd", w, väntad[0]), ("djup", d, väntad[1]),
                                 ("höjd", h, väntad[2])):
            if abs(fick - vänt) > 0.012:
                fel.append("%s: %s %.3f m mot rutan %.3f m" % (art, namn, fick, vänt))
        if d < 0.25 * w:
            fel.append("%s: djupet %.3f är under 25 %% av bredden %.3f (en platt skylt)" % (art, d, w))
        if h < 0.02:
            fel.append("%s: höjden %.3f är ingenting" % (art, h))
        if not obj.data.color_attributes or obj.data.color_attributes[0].name != "Col":
            fel.append("%s: ingen vertexfärg" % art)
            continue
        färger = {tuple(round(c, 4) for c in obj.data.color_attributes[0].data[i].color[:3])
                  for i in range(len(obj.data.color_attributes[0].data))}
        palett = {tuple(round(v / 255.0, 4) for v in färg8(pal, i)) for i in range(len(pal))}
        utanför = färger - palett
        if utanför:
            fel.append("%s: %d färger utanför paletten (%s)" % (art, len(utanför), list(utanför)[:2]))
        if len(färger) < 3:
            fel.append("%s: bara %d färger — ingen skuggning" % (art, len(färger)))
        # LÅGYTAN (M149): en lysande rekvisit har TVÅ material (fast + låga), och lågan är LITEN.
        # En glöd som brer ut sig över staken är precis felet Alex såg; provet sätter en gräns.
        antal_material = len(obj.data.materials)
        if art in LYSER:
            if antal_material != 2:
                fel.append("%s: lyser men har %d material (ska vara 2: fast + låga)" % (art, antal_material))
                continue
            # ANDEL AV AREAN, inte av ytantalet: en låga är en sexkantig stapel med många små ytor,
            # så ytantalet säger ingenting om hur mycket den syns. Arean gör det.
            area_låga = sum(poly.area for poly in obj.data.polygons if poly.material_index == 1)
            area_all = sum(poly.area for poly in obj.data.polygons)
            andel = area_låga / max(1e-9, area_all)
            if area_låga <= 0.0:
                fel.append("%s: ingen lågyta" % art)
            elif andel > 0.30:
                # Taket är mätt, inte gissat: kronans fyra lågor (5,5 px breda på en 80 px krona) är
                # 25 % av arean — modellens smala järn har många men små ytor. Över 30 % är inte en låga.
                fel.append("%s: lågan är %.0f %% av arean (taket är 30 %%)" % (art, andel * 100.0))
        elif antal_material != 1:
            fel.append("%s: lyser inte men har %d material" % (art, antal_material))
    return fel


def exportera(objekt: list, glb: Path) -> int:
    glb.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objekt:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objekt[0]
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", use_selection=True,
                              export_apply=True, export_vertex_color="ACTIVE")
    return glb.stat().st_size


def läs_glb(glb: Path) -> dict:
    """glb-filens JSON-huvud: nodnamn och meshar, så exporten kan mätas och inte bara lovas."""
    data = glb.read_bytes()
    if data[:4] != b"glTF":
        raise SystemExit("FEL: %s är ingen glb" % glb)
    längd = int.from_bytes(data[12:16], "little")
    return json.loads(data[20:20 + längd])


def sätt_scen() -> None:
    scen = bpy.context.scene
    scen.render.engine = "BLENDER_EEVEE"
    scen.render.resolution_x = scen.render.resolution_y = 420
    scen.render.film_transparent = False
    scen.render.image_settings.file_format = "PNG"
    scen.view_settings.view_transform = "Standard"
    v = bpy.data.worlds.new("grå")
    v.use_nodes = True
    v.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.12, 0.14, 1.0)
    v.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scen.world = v
    for namn, energy, rot in (("nyckel", 4.0, (0.9, 0.2, 0.7)), ("fyllnad", 1.6, (1.1, 0.0, 3.9))):
        ljus = bpy.data.lights.new(namn, type="SUN")
        ljus.energy = energy
        o = bpy.data.objects.new(namn, ljus)
        o.rotation_euler = rot
        scen.collection.objects.link(o)
    kam = bpy.data.cameras.new("kamera")
    kam.type = "ORTHO"
    kobj = bpy.data.objects.new("kamera", kam)
    scen.collection.objects.link(kobj)
    scen.camera = kobj


def rendera(obj: "bpy.types.Object", mått, sökväg: Path) -> None:
    """En bild per rekvisit, snett ovanifrån — modellen ska dömas, inte bara mätas."""
    scen = bpy.context.scene
    for annan in bpy.data.objects:
        if annan.type == "MESH":
            annan.hide_render = annan is not obj
    w, d, h = mått
    riktning = Vector((0.62, -1.0, 0.42)).normalized()
    avstånd = max(w, d, h) * 3.0 + 0.4
    kobj = scen.camera
    kobj.data.ortho_scale = max(w, h) * 1.35 + 0.08
    kobj.location = riktning * avstånd
    kobj.rotation_euler = (-kobj.location).to_track_quat("-Z", "Y").to_euler()
    scen.render.filepath = str(sökväg)
    bpy.context.view_layer.update()
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kolla_bara = "--kolla" in argv
    rendera_bilder = "--bild" in argv or not kolla_bara

    t0 = time.time()
    töm_scenen()
    pal = [tuple(int(v) for v in rad)
           for rad in json.loads(PALETT.read_text(encoding="utf-8"))]
    samling = bpy.data.collections.new("rekvisita")
    bpy.context.scene.collection.children.link(samling)
    ut = bygg_alla(pal, samling)

    print("REKVISITEN I 3D — %d arter ur %s" % (len(ut), PALETT.relative_to(ROOT)))
    print("  %-12s %5s %6s %8s %8s %8s %6s %9s %s" %
          ("art", "rutor", "ytor", "bredd", "djup", "höjd", "färger", "djup/bredd", "låga"))
    for art, (obj, mått, rutor) in ut.items():
        n_färger = len({tuple(round(c, 4) for c in obj.data.color_attributes[0].data[i].color[:3])
                        for i in range(len(obj.data.color_attributes[0].data))})
        area_låga = sum(poly.area for poly in obj.data.polygons if poly.material_index == 1)
        area_all = sum(poly.area for poly in obj.data.polygons)
        print("  %-12s %5d %6d %7.3f %8.3f %8.3f %6d %9.2f %9s" %
              (art, rutor, len(obj.data.polygons), mått[0], mått[1], mått[2], n_färger,
               mått[1] / mått[0],
               ("%.0f %% area" % (100.0 * area_låga / area_all)) if area_låga else "-"))
    fel = kolla(ut, pal)
    if fel:
        raise SystemExit("FEL: " + " · ".join(fel))
    print("  KONTROLL: form, djup och färger ok (%d arter)" % len(ut))

    objekt = [obj for obj, _, _ in ut.values()]
    storlek = exportera(objekt, GLB)
    glb = läs_glb(GLB)
    noder = {n.get("name"): n.get("mesh") for n in glb.get("nodes", [])}
    saknas = [art for art in PROPS if noder.get(art) is None]
    if saknas:
        raise SystemExit("FEL: glb saknar noder för %s (fick %s)" % (saknas, sorted(noder)))
    # LÅGYTAN I FILEN (M149): glTF gör ett material per yta till en primitiv, så en lysande rekvisit
    # ska ha TVÅ primitiver — den fasta och lågan. Ett svar på papperet är inte ett svar i filen.
    meshar = glb.get("meshes", [])
    for art in LYSER:
        index = noder.get(art)
        antal = len(meshar[index].get("primitives", [])) if index is not None else 0
        if antal != 2:
            raise SystemExit("FEL: %s har %d primitiver i glb (ska vara 2: fast + låga)" % (art, antal))
    print("  glb: %s (%d byte, %d mesh-noder, %d material)" %
          (GLB.relative_to(ROOT), storlek, len(noder), len(glb.get("materials", []))))

    if rendera_bilder:
        sätt_scen()
        BILDMAPP.mkdir(parents=True, exist_ok=True)
        for art, (obj, mått, _) in ut.items():
            rendera(obj, mått, BILDMAPP / ("%s.png" % art))
        print("  bilder: %s (%d st)" % (BILDMAPP, len(ut)))
    print("  tid: %.2f s" % (time.time() - t0))
    return {"status": "ok", "arter": len(ut), "glb_byte": storlek,
            "bilder": str(BILDMAPP) if rendera_bilder else "", "fel": fel}


# MCP-vägen kör filen med exec(); då finns ingen __main__ att gå in i. Sätts av anropet.
if __name__ == "__main__":
    svar = main()
    if isinstance(svar, dict):
        print("  %s" % svar)
    else:
        sys.exit(svar)
