#!/usr/bin/env python3
"""Hittar tunna remsor i marken: objekt vars ÖVERSTA yta ligger inom några centimeter av ett annat
markobjekt OCH vars fotavtryck i XY överlappar. En sådan kant blir en 2-4 px remsa i vyn (z-fighting).

    blender -b <modell.blend> --python mat_remsor.py -- [tröskel i meter]
"""
import sys

import bpy
from mathutils import Vector

TRÖSKEL = float(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else 0.05
MARK = ("grass", "road", "cobble", "cliff", "foreground", "fg_", "dirt", "plaza", "path", "ground",
        "sand", "mur", "wall")

def mått(o):
    mw = o.matrix_world
    hörn = [mw @ Vector(c) for c in o.bound_box]
    xs = [h.x for h in hörn]; ys = [h.y for h in hörn]; zs = [h.z for h in hörn]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)

mark = [o for o in bpy.context.scene.objects
        if o.type == "MESH" and any(k in o.name.lower() for k in MARK)]
print("markobjekt: %d" % len(mark))
info = [(o.name, mått(o)) for o in mark]

def överlappar(a, b):
    return not (a[1] < b[0] or b[1] < a[0] or a[3] < b[2] or b[3] < a[2])

def area(a):
    return (a[1] - a[0]) * (a[3] - a[2])

fynd = []
for i in range(len(info)):
    for j in range(i + 1, len(info)):
        na, a = info[i]
        nb, b = info[j]
        if not överlappar(a, b):
            continue
        ## Ytorna nära varandra i höjd: den enas topp mot den andras topp eller botten
        dz = min(abs(a[5] - b[5]), abs(a[5] - b[4]), abs(a[4] - b[5]))
        if dz > TRÖSKEL:
            continue
        ox = min(a[1], b[1]) - max(a[0], b[0])
        oy = min(a[3], b[3]) - max(a[2], b[2])
        ## VERKLIG överlapp: två grannplattor i samma plan delar kant men inte yta (mätt: arean 0,00
        ## för 1 150 par kullerstenstegelplattor). Bara par som ligger OVANPÅ varandra syns som remsa.
        if ox <= 0.02 or oy <= 0.02:
            continue
        fynd.append((dz, ox * oy, na, a[4], a[5], nb, b[4], b[5]))
fynd.sort(key=lambda r: (-r[1], r[0]))
print("\npar inom %.3f m med VERKLIG överlapp, sorterade på största överlappsarea:" % TRÖSKEL)
print("%-8s %-10s %-30s %-16s %-30s %s" % ("dz", "area m²", "A", "A z", "B", "B z"))
for dz, ar, na, az0, az1, nb, bz0, bz1 in fynd[:25]:
    print("%-8.4f %-10.2f %-30s %-16s %-30s %s" %
          (dz, ar, na, "%.4f..%.4f" % (az0, az1), nb, "%.4f..%.4f" % (bz0, bz1)))
print("\nantal par: %d" % len(fynd))
