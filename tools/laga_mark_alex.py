#!/usr/bin/env python3
"""Alex' manuella grusväg in i kedjan.

MÄTT I HANS SESSION (bryggan, läsning av matrix_world mot bound_box):

    Grass_Main    z -1,0000.. 0,0000   skala 1,0                (orörd)
    Road_Bed      z -0,0100.. 0,0100   skala (1,4021, 0,4288, 1) y -1,99..0,62
    Cliff_Face    z -3,0380..-0,0321   skala (1,0053, 2,4542, 1,0053) y -8,78..-3,38

Han flyttade grusvägen till en 2,6 m djup sträng vid gatan (var y -6,00..0,10) och skalade båda
objekten. ORDNINGEN är rätt — gräs 0,000 > grus +0,010 > brant -0,032 — men avståndet gräs till grus
är 1,0 cm, alltså exakt det som z-fightade förut (mätt 122,4 m² över samma par, samma par i den
första mätningen låg på dz 0,0100).

Den här filen: (1) bakar in skalorna i meshen så skalan blir 1 igen (finaliseringens regel), och
(2) lyfter gruset till +0,05 — 4 cm högre, 1,7 px i spelvyn, men 5 cm ifrån gräset i stället för 1.
Brantens topp lämnas exakt där han satte den (-0,0321, 3,2 cm under gräset, alltså dold under det).

    blender -b <Alex fil.blend> --python laga_mark_alex.py -- <ut.blend>
"""
import sys

import bpy
from mathutils import Vector

UT = sys.argv[sys.argv.index("--") + 1]
GRUS_TOPP = 0.05          # hans +0,0100 lyft till 5 cm över gräset (4 cm luft i stället för 1)
BRANT_TOPP = -0.0521      # hans -0,0321 sänkt 2 cm: 6,2 cm under gruset, 5,2 cm under gräset
MIN_MELLAN = 0.05


def topp(o):
    return max((o.matrix_world @ Vector(c)).z for c in o.bound_box)


def botten(o):
    return min((o.matrix_world @ Vector(c)).z for c in o.bound_box)


gräs = bpy.data.objects.get("Grass_Main")
if gräs is None:
    print("FEL: Grass_Main finns inte")
    sys.exit(1)
gräs_topp = topp(gräs)
if abs(gräs_topp) > 1e-6:
    print("FEL: gräset ligger på %.4f, inte 0 — mät om" % gräs_topp)
    sys.exit(1)

## 1) Baka in skalorna. Alex skalade Road_Bed (1,4021, 0,4288, 1) och Cliff_Face
## (1,0053, 2,4542, 1,0053); finaliseringen kräver skala 1 på varje objekt. Tar ALLA med skala != 1,
## men rör aldrig ett mesh som delas av flera objekt (då skulle deras form ändras också).
före = {}
for o in bpy.data.objects:
    if o.type != "MESH" or max(abs(s - 1.0) for s in o.scale) <= 1e-6:
        continue
    if o.data.users > 1:
        print("FEL: %s har skala %s men delar mesh med %d objekt — bakas inte" %
              (o.name, tuple(round(v, 4) for v in o.scale), o.data.users))
        sys.exit(1)
    if o.name in ("Road_Bed", "Cliff_Face"):
        före[o.name] = (tuple(o.location), tuple(o.scale), botten(o), topp(o))
    tr = tuple(round(v, 4) for v in o.scale)
    bpy.context.view_layer.objects.active = o
    for annat in bpy.context.selected_objects:
        annat.select_set(False)
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.select_set(False)
    bpy.context.view_layer.update()
    print("  %-16s skala %s bakad i meshen" % (o.name, tr))
for namn in ("Road_Bed", "Cliff_Face"):
    o = bpy.data.objects.get(namn)
    if o is None:
        print("FEL: %s finns inte" % namn)
        sys.exit(1)
    if max(abs(s - 1.0) for s in o.scale) > 1e-6:
        print("FEL: %s har fortfarande skala %s" % (namn, tuple(o.scale)))
        sys.exit(1)

## 2) Lyft gruset till absolut topp, och branten 2 cm under Alex' värde (samma skäl: 3,2 cm mot
## gräset är under de 4 cm som visade sig stabilt, och ytan de delar är bara 0,12 x 42 m).
grus = bpy.data.objects["Road_Bed"]
if abs(topp(grus) - GRUS_TOPP) > 1e-6:
    grus.location.z += GRUS_TOPP - topp(grus)
    bpy.context.view_layer.update()
brant = bpy.data.objects["Cliff_Face"]
if abs(topp(brant) - BRANT_TOPP) > 1e-6:
    brant.location.z += BRANT_TOPP - topp(brant)
    bpy.context.view_layer.update()
print("  %-12s topp %.4f -> %.4f (var %.4f hos Alex)" %
      ("Road_Bed", före["Road_Bed"][3], topp(grus), före["Road_Bed"][3]))
print("  %-12s topp %.4f -> %.4f (Alex' värde, 2 cm ned för luft mot gräset)" %
      ("Cliff_Face", före["Cliff_Face"][3], topp(brant)))

## ORDNINGEN är Alex' egen: gruset ligger PÅ gräset (en upphöjd väg), och gräset ligger över
## brantens topp. Gräset är alltså mitten, inte toppen, så här.
nivåer = [("Road_Bed", topp(grus)), ("Grass_Main", gräs_topp), ("Cliff_Face", topp(brant))]
print("\nnivåer: %s" % " | ".join("%s %.4f" % (n, z) for n, z in nivåer))
for (na, za), (nb, zb) in zip(nivåer, nivåer[1:]):
    if not za - zb >= MIN_MELLAN - 1e-6:
        print("FEL: %s ligger %.4f m över %s (minst %.2f)" % (na, za - zb, nb, MIN_MELLAN))
        sys.exit(1)
    print("  %-12s över %-12s %.4f m" % (na, nb, za - zb))
if topp(grus) <= gräs_topp:
    print("FEL: gruset ligger inte över gräset — fel ordning")
    sys.exit(1)

## 3) Ingen annan skala kvar i scenen (finaliseringens regel).
kvar = [o.name for o in bpy.data.objects
        if o.type == "MESH" and max(abs(s - 1.0) for s in o.scale) > 1e-6]
if kvar:
    print("FEL: %d objekt har skala != 1: %s" % (len(kvar), kvar[:6]))
    sys.exit(1)
print("skala 1 på alla mesh-objekt")

bpy.ops.wm.save_as_mainfile(filepath=UT, copy=False)
print("SPARAD: %s" % UT)
