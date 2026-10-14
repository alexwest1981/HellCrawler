#!/usr/bin/env python3
"""Markens tre nivåer: gräset, gruset och brantens topp.

MÄTT (mat_remsor.py + mat_markplan.py; kameran tittar från -y, så mindre y är närmare):

    före:  Grass_Main  z -1,00.. 0,00   y -3,50..14,50
           Cliff_Face  z -3,00..-0,01   y -4,30..-2,10   <- toppen i SAMMA plan som gruset
           Road_Bed    z -0,03..-0,01   y -6,00.. 0,10   <- gruset, närmast kameran

Två fel av samma slag, båda syns som en remsa mellan gruset och gräset:

1. Brantens topp och grusbäddens topp låg i EXAKT samma plan (z -0,01, dz 0,0000 över 74,8 m²).
   Två ytor som båda pekar UPPÅT i samma plan kämpar om samma pixlar — det var remsan som flimrade.
2. Sedan de säkrats isär 4 cm låg brantens topp ÖVER grusets yta, och då syns i stället en stabil
   4 cm plinth av brantens mörkgrå toppyta. Att säkra isär räcker alltså INTE — nivåerna måste ligga
   i rätt ORDNING, med den övre ytan överst.

Den här filen sätter absoluta nivåer (inte relativa förskjutningar), så den ger samma resultat
oavsett vilket mellansteg den körs på:

    Grass_Main   0,00        gräset — referens, rörs inte
    Road_Bed    -0,05        gruset, 5 cm under gräset — närmast kameran, y -6,00..0,10
    Cliff_Face  -0,30        brantens topp 25 cm UNDER grusets yta, så bäddens översta yta täcker
                             den från kameran. Brantens FRAMSIDA (den mörka zonen i bilden) hänger
                             kvar under och fyller kanten.

    blender -b <modell.blend> --python laga_remsan.py -- <ut.blend>
"""
import sys

import bpy
from mathutils import Vector

UT = sys.argv[sys.argv.index("--") + 1]

MÅL = {"Road_Bed": -0.05, "Cliff_Face": -0.30}   # önskad z för objektets ÖVERSTA yta
MIN_MELLAN = 0.05                                # minsta tillåtna avstånd mellan två nivåer


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
    print("FEL: gräset ligger på %.4f, inte 0 — mät om innan något flyttas" % gräs_topp)
    sys.exit(1)

alle = {o.name: (botten(o), topp(o)) for o in bpy.data.objects if o.type == "MESH"}
for namn, mål in MÅL.items():
    o = bpy.data.objects.get(namn)
    if o is None:
        print("FEL: %s finns inte" % namn)
        sys.exit(1)
    if abs(topp(o) - mål) < 1e-6:
        print("  %-14s ligger redan på %.4f — rörs inte" % (namn, mål))
        continue
    o.location.z += mål - topp(o)
    bpy.context.view_layer.update()
    print("  %-14s z %.4f..%.4f -> %.4f..%.4f (mål topp %.4f)" %
          (namn, alle[namn][0], alle[namn][1], botten(o), topp(o), mål))

kvar = {}
for o in bpy.data.objects:
    if o.type != "MESH" or o.name not in alle:
        continue
    nu = (botten(o), topp(o))
    if o.name not in MÅL and (abs(nu[0] - alle[o.name][0]) > 1e-6 or abs(nu[1] - alle[o.name][1]) > 1e-6):
        kvar[o.name] = nu
if kvar:
    print("FEL: %d objekt rörde sig utan att vara avsedda: %s" % (len(kvar), list(kvar)[:6]))
    sys.exit(1)

## EFTER: nivåerna ska ligga i ordning gräs > grus > brant, med luft emellan.
nivåer = [("Grass_Main", gräs_topp)] + [(n, topp(bpy.data.objects[n])) for n in ("Road_Bed", "Cliff_Face")]
print("\nnivåer: %s" % " | ".join("%s %.4f" % (n, z) for n, z in nivåer))
for (na, za), (nb, zb) in zip(nivåer, nivåer[1:]):
    if not za - zb >= MIN_MELLAN:
        print("FEL: %s ligger %.4f m över %s (minst %.2f krävs)" % (na, za - zb, nb, MIN_MELLAN))
        sys.exit(1)
    print("  %-14s över %-14s %.4f m" % (na, nb, za - zb))
for namn, mål in MÅL.items():
    if abs(topp(bpy.data.objects[namn]) - mål) > 1e-6:
        print("FEL: %s toppar på %.4f, skulle vara %.4f" % (namn, topp(bpy.data.objects[namn]), mål))
        sys.exit(1)
print("ORDNING OK: gräs > grus > brant, minst %.0f cm mellan varje" % (MIN_MELLAN * 100))

bpy.ops.wm.save_as_mainfile(filepath=UT, copy=False)
print("SPARAD: %s" % UT)
