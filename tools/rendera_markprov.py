#!/usr/bin/env python3
"""Renderar markkanten (branten mot gruset) med SAMMA kamera och ljus ur två filer, så att en remsa
blir en mätbar skillnad i pixlar i stället för ett omdöme.

    blender -b <modell.blend> --python tools/apply_pixel_textures.py \\
        --python rendera_markprov.py -- <ut.png>
"""
import sys

import bpy
from mathutils import Vector

UT = sys.argv[sys.argv.index("--") + 1]
if len(sys.argv) > sys.argv.index("--") + 2:
    mål_arg = sys.argv[sys.argv.index("--") + 2]
else:
    mål_arg = None

## Kameran: låg och sned mot markkanten, samma i båda körningarna.
KAMERA = (0.5, -13.0, 1.35)
MÅL = Vector((0.0, -3.9, -0.06))

## Ett mål som "skylt" eller "fonster" letas upp ur scenen i stället för att skrivas in: båda är
## objekt Alex pekat på ("texturen sitter på fel ledd längs skyltar och balkar", "det är fönster över
## skylten här t.ex").
def sök_bräda():
    return next((o for o in bpy.data.objects if "Sign_" in o.name and "Board" in o.name), None)

def sök_fönster(bräda):
    """Glaset Alex pekade på: det som sitter NÄRMast en skylt av alla glas/skylt-par.

    MÄTT: nio glasobjekt ligger på materialen Window_Warm/Window_Bright. Det högsta är ett bakhushus
    (z 5,9) och det *första* Sign_*_Board är tavernans, vars närmaste glas ligger 4,2 m bort — men
    weavery-fönstret sitter 0,3 m över sin skylt, och det är det Alex pekade på ("fönster över skylten").
    """
    glas = [o for o in bpy.data.objects if "Win_Glass" in o.name or "Win_Glow" in o.name]
    if not glas:
        return None
    brädor = [o for o in bpy.data.objects if "Sign_" in o.name and "Board" in o.name]
    if not brädor:
        return max(glas, key=lambda o: o.matrix_world.translation.z)
    _, valt, _ = min(((g.matrix_world.translation.xy - b.matrix_world.translation.xy).length, g, b)
                     for g in glas for b in brädor)
    return valt

if mål_arg in ("skylt", "fonster"):
    bräda = sök_bräda()
    valt = bräda if mål_arg == "skylt" else sök_fönster(bräda)
    if valt is None:
        print("FEL: hittade inget %s" % ("Sign_*_Board" if mål_arg == "skylt" else "glasobjekt"))
        raise SystemExit(1)
    M0 = valt.matrix_world
    hörn = [M0 @ Vector(c) for c in valt.bound_box]
    mitten = sum(hörn, Vector((0.0, 0.0, 0.0))) / 8.0
    LED = (max(p.z for p in hörn) - min(p.z for p in hörn))
    MÅL = Vector((mitten.x, mitten.y, mitten.z))
    KAMERA = (mitten.x + 0.6, mitten.y - 4.2, mitten.z + 0.9)
    print("mål: %s i %s, led %s, höjd %.2f m" %
          (valt.name, tuple(round(v, 2) for v in mitten),
           tuple(round(abs(max(p[i] for p in hörn) - min(p[i] for p in hörn)), 2) for i in range(3)), LED))
elif mål_arg:
    siffror = [float(v) for v in mål_arg.split(",")]
    if len(siffror) != 3:
        print("FEL: målet ska vara 'skylt' eller 'x,y,z'")
        raise SystemExit(1)
    MÅL = Vector(siffror)
    KAMERA = (siffror[0] + 0.6, siffror[1] - 4.2, siffror[2] + 0.9)

sc = bpy.context.scene
cam_data = bpy.data.cameras.new("Markprov_Kamera")
cam_data.type = "PERSP"
cam_data.lens = 32.0
cam = bpy.data.objects.new("Markprov_Kamera", cam_data)
sc.collection.objects.link(cam)
cam.location = KAMERA
cam.rotation_mode = "QUATERNION"
cam.rotation_quaternion = (MÅL - Vector(KAMERA)).to_track_quat("-Z", "Y")
sc.camera = cam

## Samma renderare och storlek i båda körningarna (EEVEE, för att fånga z-fighting som Blender visar).
sc.render.engine = "BLENDER_EEVEE"
sc.eevee.use_raytracing = True
sc.eevee.use_shadows = True
sc.render.resolution_x = 1400
sc.render.resolution_y = 500
sc.render.resolution_percentage = 100
sc.render.film_transparent = False

## Alex' vy står i en User Perspective ur filen; den här kameran ersätter den bara i renderingen.
print("kamera %s -> %s, brant %.0f grader" %
      (tuple(round(v, 2) for v in KAMERA), tuple(round(v, 2) for v in MÅL),
       (Vector(KAMERA) - MÅL).angle(Vector((0, 0, -1))) * 57.2958))
for namn in ("Cliff_Face", "Road_Bed", "Grass_Main"):
    o = bpy.data.objects.get(namn)
    if o:
        h = [o.matrix_world @ Vector(c) for c in o.bound_box]
        print("  %-12s z %.3f..%.3f  y %.2f..%.2f" %
              (namn, min(p.z for p in h), max(p.z for p in h), min(p.y for p in h), max(p.y for p in h)))

sc.render.filepath = UT
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("RENDERAD: %s" % UT)
