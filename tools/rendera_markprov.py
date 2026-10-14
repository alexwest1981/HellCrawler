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

## Kameran: låg och sned mot markkanten, samma i båda körningarna.
KAMERA = (0.5, -13.0, 1.35)
MÅL = Vector((0.0, -3.9, -0.06))

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
