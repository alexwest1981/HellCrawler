#!/usr/bin/env python3
"""Replace my procedural trees and bushes with the kit's own models.

    blender -b assets/Untitled_byn_kedjan.blend --python jobb/kit_trad.py -- [--check] [--no-save]

Alex, after five procedural pine versions: "om du behöver veta hur träd ser ut, för det där ser inte
riktigt ut som granar... Använd antingen dessa träd, eller skapa likadana, för nu börjar det här gå
mig på nerverna."

He is right, and the answer is the first option: the kit he owns already has the trees. Every pine and
broadleaf is a real Quaternius model with bark and alpha-cut needles (Pine_1 3 947 tris, CommonTree_1
6 265), and the bushes are Bush_Common. Placing the artist's models beats my imitation of them.

Two rules carried over from the tree rebuilds, both learned the hard way:

* **Positions come from JSON, never from the objects in the scene.** Building from what stands in the
  file let a second run shrink every bush by another 15 % (busk_positioner.json explains why).
* **Snapshots before the batch.** The scene is the only copy of the placements.

The trees keep their original names (`Pine_Tree_5`, `Deciduous_Tree_2`) so the test suite and my own
checks still find them; the kit variant each one uses is written into the object's custom properties.
"""
from __future__ import annotations

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(ROOT, "game", "assets", "by", "quaternius", "nature")
TREES = os.path.join(ROOT, "jobb", "trad_positioner.json")
BUSHES = os.path.join(ROOT, "jobb", "busk_positioner.json")

# Fyra granar och fem lövträd räcker för variation; Pine_5 är den glesa unggranen och används till de
# minsta positionerna så att siluetten stämmer med höjden.
PINES = ("Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5")
LEAFY = ("CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5")
BUSH_VARIANTS = ("Bush_Common", "Bush_Common_Flowers")

COLL_NAME = "Kit_Vegetation"


def rnd(state: list) -> float:
    """Deterministic LCG — same numbers on every run, which is what makes a rebuild reviewable."""
    state[0] = (state[0] * 1103515245 + 12345) % (2 ** 31)
    return state[0] / (2 ** 31)


def collection() -> bpy.types.Collection:
    col = bpy.data.collections.get(COLL_NAME)
    if col is None:
        col = bpy.data.collections.new(COLL_NAME)
        bpy.context.scene.collection.children.link(col)
    return col


def import_kit(name: str, col) -> list:
    """Import one kit model and move it into our collection. Returns the mesh objects."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, name + ".gltf"))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for obj in meshes:
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        col.objects.link(obj)
    for obj in new:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    if len(meshes) != 1:
        raise SystemExit(f"{name}: väntade en mesh, fick {len(meshes)}")
    # eget prefix: annars raderar clear() källorna när den städar bort mina Bush_00..Bush_64
    meshes[0].name = "KitSrc_" + name
    meshes[0].data.name = "KitSrc_" + name
    return meshes[0]


def dedupe_materials(sources: dict) -> int:
    """One material per kit material, not one per import.

    Twelve glTF imports each bring their own copy (Bark_NormalTree.001 …), and the export then writes
    43 materials and 24 identical images into the glb. The copies are the same texture with the same
    settings, so the first one wins and the rest are remapped onto it."""
    canonical = {}
    swapped = 0
    for src in sources.values():
        for slot in src.material_slots:
            mat = slot.material
            if mat is None:
                continue
            base = mat.name.split(".")[0]
            if base not in canonical:
                canonical[base] = mat
                continue
            if slot.material != canonical[base]:
                slot.material = canonical[base]
                swapped += 1
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    return swapped


def place(src, name: str, base: Vector, height: float, yaw: float, col) -> bpy.types.Object:
    """Copy a kit model, scale it to the wanted height and put its foot at `base`."""
    obj = src.copy()
    obj.data = src.data                      # delad mesh: samma glb-mesh, 22 noder
    obj.name = name
    obj.data.name = src.data.name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)

    kit_h = src.dimensions.z or 1.0
    s = height / kit_h
    obj.matrix_world = (Matrix.Translation(base) @ Matrix.Rotation(yaw, 4, "Z")
                        @ Matrix.Scale(s, 4))
    obj["kit_variant"] = src.name.removeprefix("KitSrc_")
    return obj


def clear(prefixes: tuple, col) -> int:
    gone = 0
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or obj.name.startswith("KitSrc_") or not obj.name.startswith(prefixes):
            continue
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if data.users == 0 and data.name not in {o.data.name for o in bpy.data.objects if o.type == "MESH"}:
            bpy.data.meshes.remove(data)
        gone += 1
    return gone


def shrink_images() -> int:
    """Bring the kit's 2 048 px bark down to something a 30 px tree can use.

    The glTF importer PACKS the images into the blend, so resizing the files on disk changes nothing —
    the first export carried 3,8 + 4,3 MB of bark for trees that are ~385 px tall on screen. Scaling the
    datablock itself and re-packing is the only place it can be done."""
    limits = (("Bark", 512), ("Leaf", 1024), ("Leaves", 1024), ("Flowers", 1024))
    done = 0
    for img in bpy.data.images:
        base = img.name.split(".")[0]
        lim = next((v for k, v in limits if base.startswith(k)), None)
        if lim is None or img.size[0] == 0:
            continue
        if max(img.size) <= lim:
            continue
        w, h = img.size
        f = lim / max(w, h)
        img.scale(max(1, round(w * f)), max(1, round(h * f)))
        img.pack()
        done += 1
    return done


def purge() -> int:
    """Remove template objects, unused materials, duplicate images and orphan meshes.

    Every glTF import brings its own copy of the bark texture and the leaf material; without this the
    glb ended up with 48 materials and 24 identical images. The templates are deleted once the copies
    exist — the copies share their mesh data, so the geometry stays."""
    gone = 0
    for obj in list(bpy.data.objects):
        if obj.name.startswith("KitSrc_"):
            bpy.data.objects.remove(obj, do_unlink=True)
            gone += 1
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for img in list(bpy.data.images):
        if img.users == 0 and img.name not in ("Render Result", "Viewer Node"):
            bpy.data.images.remove(img)
    return gone


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    check = "--check" in args
    no_save = "--no-save" in args or check

    purge()                                   # rensa förra körningens mallar först
    positions = json.load(open(TREES))
    bushes = json.load(open(BUSHES))
    col = collection()
    state = [20261019]

    # källorna importeras en gång per variant och kopieras sedan; kopiorna delar mesh-data
    sources = {}
    for variant in PINES + LEAFY + BUSH_VARIANTS:
        sources[variant] = import_kit(variant, col)

    swapped = dedupe_materials(sources)
    print(f"MATERIALER slog ihop {swapped} platser")

    gone = clear(("Pine_Tree_", "Deciduous_Tree_", "Tree_Kit_", "Bush_"), col)
    print(f"RADERADE {gone} procedurella träd/buskar")

    made = 0
    for i, tree in enumerate(positions):
        pool = PINES if tree["kind"] == "pine" else LEAFY
        # minsta positionerna får den glesa unggranen / det minsta lövträdet
        idx = int(abs(tree["x"] * 7 + tree["y"] * 3)) % len(pool)
        if tree["h"] < 4.0:
            idx = len(pool) - 1
        variant = pool[idx]
        height = tree["h"] * 1.20
        yaw = rnd(state) * math.tau
        obj = place(sources[variant], tree["name"],
                    Vector((tree["x"], tree["y"], tree["z"])), height, yaw, col)
        made += 1
        if check:
            print(f"  {obj.name:22s} {variant:14s} h={height:5.2f}")

    bushes_made = 0
    for i, spot in enumerate(bushes):
        variant = BUSH_VARIANTS[0] if spot.get("hedge") else BUSH_VARIANTS[1]
        size = max(0.6, float(spot["w"])) * 1.05
        base = Vector((float(spot["x"]), float(spot["y"]) - 0.06, float(spot["z"])))
        obj = place(sources[variant], f"Bush_{i:02d}", base, size * 0.82,
                    rnd(state) * math.tau, col)
        bushes_made += 1

    shrunk = shrink_images()
    print(f"BILDER nedskalade {shrunk}")
    templates = purge()
    print(f"KIT trees={made} bushes={bushes_made} mallar_bort={templates}")
    print(f"MATERIALER kvar={len(bpy.data.materials)} BILDER kvar={len(bpy.data.images)}")

    if not no_save:
        bpy.ops.wm.save_mainfile()
        print("SAVED", bpy.data.filepath)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
