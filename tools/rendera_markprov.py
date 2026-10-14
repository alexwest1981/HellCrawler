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

## Ett mål som "skylt" letas upp ur scenen i stället för att skrivas in: skyltbrädan är det objekt
## som Alex pekade på ("texturen sitter på fel ledd längs skyltar och balkar").
if mål_arg == "skylt":
    bräda = next((o for o in bpy.data.objects if "Sign_" in o.name and "Board" in o.name), None)
    if bräda is None:
        print("FEL: ingen Sign_*_Board hittades")
        raise SystemExit(1)
    M0 = bräda.matrix_world
    hörn = [M0 @ Vector(c) for c in bräda.bound_box]
    mitten = sum(hörn, Vector((0.0, 0.0, 0.0))) / 8.0
    LED = (max(p.z for p in hörn) - min(p.z for p in hörn))
    MÅL = Vector((mitten.x, mitten.y, mitten.z))
    KAMERA = (mitten.x + 0.6, mitten.y - 4.2, mitten.z + 0.9)
    print("mål: %s i %s, led %s, skyltens höjd %.2f m" %
          (bräda.name, tuple(round(v, 2) for v in mitten),
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
