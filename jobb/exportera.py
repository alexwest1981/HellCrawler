#!/usr/bin/env python3
"""Export the diorama to game/assets/by/byn.glb, without the render-only props.

    blender -b assets/Untitled_byn_kedjan.blend --python jobb/exportera.py -- [--check]

Three things this has to get right, and the reason it is a script instead of a manual export:

1. **The lights are in Blender's units and Godot reads them raw.** Divided by 2000 before export and
   put back afterwards — the same factor and the same reason as `tools/uv_byn.py` (measured there:
   it is the point lights, not the sun, that burned the stone facades).
2. **Clouds and grass tufts are scenery for the Blender renders and must not reach the game.**
   `test_by_rok.gd` asserts byn.glb holds ZERO cloud/smoke nodes, and the game builds its own grass
   from the Quaternius kit (1500 tufts, `by_3d.gd`), so exporting my 150 would draw the field twice.
   They are unlinked from every collection for the duration of the export and linked back after.
3. **Nothing else is touched.** The buildings already carry the UVs `tools/uv_byn.py` baked, and the
   mountain/trees carry mine, so there is no re-baking here — an export that re-unwrapped the meshes
   would silently throw away both.
"""
from __future__ import annotations

import json
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB = os.path.join(ROOT, "game", "assets", "by", "byn.glb")
LJUS_DELARE = 2000.0

# scenery that belongs to the renders, not to the game
RENDER_ONLY = ("Cloud", "Grass_Tuft", "Grass_Kit_Source", "Moon", "Star_", "Sky_Backdrop")


def render_only(obj) -> bool:
    return obj.name.startswith(RENDER_ONLY)


def main() -> int:
    check = "--check" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    parked = []
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and render_only(obj):
            parked.append((obj, [c for c in obj.users_collection]))
            for c in obj.users_collection:
                c.objects.unlink(obj)

    lights = [(o, o.data.energy) for o in bpy.context.scene.objects if o.type == "LIGHT"]
    for o, _ in lights:
        o.data.energy /= LJUS_DELARE

    try:
        if check:
            print("CHECK (torrkörning): %d renderbara objekt parkerade, %d ljus delade med %.0f"
                  % (len(parked), len(lights), LJUS_DELARE))
        else:
            bpy.ops.export_scene.gltf(
                filepath=GLB, export_format="GLB", export_yup=True, export_apply=True,
                export_extras=True, export_lights=True)
            print("GLB %s, %d byte, %d renderbara objekt parkerade"
                  % (GLB, os.path.getsize(GLB), len(parked)))
    finally:
        for o, energies in lights:
            o.data.energy = energies
        for obj, collections in parked:
            for c in collections:
                c.objects.link(obj)

    if check:
        return 0

    # verify by reading the file, not by trusting the exporter
    data = open(GLB, "rb").read()
    jlen = int.from_bytes(data[12:16], "little")
    gltf = json.loads(data[20:20 + jlen])
    names = [n.get("name", "") for n in gltf.get("nodes", [])]
    clouds = [n for n in names if n.startswith("Cloud")]
    tufts = [n for n in names if n.startswith("Grass_Tuft")]
    trees = [n for n in names if n.startswith(("Pine_Tree", "Deciduous_Tree"))]
    ridge = [n for n in names if n.startswith("Mountain_")]
    pyramids = [n for n in names if n in ("Mountain_0", "Mountain_1", "Mountain_2",
                                          "Mountain_3", "Mountain_4")]
    ok = not clouds and not tufts and len(trees) == 22 and "Mountain_Range" in names and not pyramids
    print("CHECK nodes=%d trees=%d ridge=%s clouds=%d tufts=%d pyramider=%d -> %s"
          % (len(names), len(trees), ridge[:3], len(clouds), len(tufts), len(pyramids),
             "OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
