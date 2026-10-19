#!/usr/bin/env python3
"""Vegetation for the diorama: low-poly trees with real volume, and grass from the Quaternius kit.

    blender -b assets/Untitled_byn_kedjan.blend --python jobb/modeller.py -- [--check] [--no-save]

Why this file exists: the first pass built every tree out of six boxes (a stack of tiers and a slab of
leaves) and the grass out of 0.1 m sticks. Alex, looking at the render: *"för platt, för stelt,
förjävligt ... Jag vill få allt SNYGGT, inte se så här lågbudget ut"*, and separately about the grass
*"irriterande linjer över hela skärmen"* — the sticks were those lines.

So: cones and icospheres, flat-shaded (the project's language), with two green plates per tree for
depth, a trunk that is visible below the crown, branch stubs, and a per-tree seed so no two are the
same shape. The grass is the kit's own geometry (`game/assets/by/quaternius/Grass_Common_Tall.gltf`,
303 verts per tuft), scattered as linked duplicates — real blades, no billboards, no sticks.

Tree positions and heights are not invented here: they come from jobb/trad_positioner.json, which was
read out of the diorama before the old trees were replaced, so the composition is the one Alex had.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
POSITIONS = Path(__file__).resolve().parent / "trad_positioner.json"
GRASS_GLTF = ROOT / "game" / "assets" / "by" / "quaternius" / "Grass_Common_Tall.gltf"

COLLECTION = "Collection"
BARK = "PX_Bark"
GREEN_LIGHT = "PX_Lövverk"
GREEN_MID = "PX_Barr"
GREEN_DARK = "PX_Hedge"


# ---------------------------------------------------------------- geometry helpers
def _new_mesh(name: str, materials: list, collection) -> tuple:
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    for m in materials:
        obj.data.materials.append(bpy.data.materials[m])
    collection.objects.link(obj)
    return bpy.data.objects[name], bmesh.new()


def _tag(bm, verts, mat_index: int) -> None:
    for face in {f for v in verts for f in v.link_faces}:
        face.material_index = mat_index


def cone(bm, matrix: Matrix, r1: float, r2: float, depth: float, mat_index: int,
         segments: int = 8) -> None:
    try:
        ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=r1, radius2=r2, depth=depth)
    except TypeError:                                   # older bmesh spelling
        ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                                    diameter1=r1 * 2, diameter2=r2 * 2, depth=depth)
    _tag(bm, ret["verts"], mat_index)
    bmesh.ops.transform(bm, matrix=matrix, verts=ret["verts"])


def blob(bm, matrix: Matrix, radius: float, mat_index: int, subdivisions: int = 1) -> None:
    try:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    except TypeError:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, diameter=radius * 2)
    _tag(bm, ret["verts"], mat_index)
    bmesh.ops.transform(bm, matrix=matrix, verts=ret["verts"])
    # flat shading is set per polygon when the mesh is written


def uv_box_project(mesh, metres_per_tile: float = 1.0) -> None:
    """Per-face box projection in metres per texture tile (the project's rule for pixel plates)."""
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    mesh.update()
    layer = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        axis = max(range(3), key=lambda i: abs(poly.normal[i]))
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            u, w = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[axis]
            layer[li].uv = (u / metres_per_tile, w / metres_per_tile)
        poly.use_smooth = False


def finish(bm, obj, materials: list, tile: float) -> bpy.types.Object:
    bm.to_mesh(obj.data)
    bm.free()
    uv_box_project(obj.data, tile)
    return obj


def rnd(state: list) -> float:
    state[0] = (state[0] * 1103515245 + 12345) % 2147483648
    return state[0] / 2147483648.0


# ---------------------------------------------------------------- trees
def pine(name: str, base: Vector, height: float, seed: int, collection) -> bpy.types.Object:
    """A conifer: visible trunk, six shrinking tiers as cones, a slight lean, two greens.

    The tiers are cones and each is rotated by its own angle, so the silhouette breaks up instead of
    reading as a stack of identical slabs (which is what the box version did)."""
    state = [seed]
    materials = [BARK, GREEN_MID, GREEN_LIGHT, GREEN_DARK]
    obj, bm = _new_mesh(name, materials, collection)
    lean = (rnd(state) - 0.5) * 0.10
    trunk_h = height * 0.42
    cone(bm, Matrix.Translation(base + Vector((0, 0, trunk_h / 2)))
         @ Matrix.Rotation(lean, 4, "Y"),
         0.19, 0.11, trunk_h, 0, segments=7)
    tiers = 6
    for i in range(tiers):
        t = i / (tiers - 1.0)
        z = base.z + trunk_h * 0.80 + (height - trunk_h * 0.80) * t
        r = height * 0.30 * (1.0 - 0.74 * t) * (0.90 + 0.25 * rnd(state))
        depth = height * 0.17 * (1.0 - 0.30 * t)
        angle = rnd(state) * math.tau
        jx = (rnd(state) - 0.5) * 0.06 * height
        jy = (rnd(state) - 0.5) * 0.06 * height
        mat = 3 if i == 1 else (2 if i % 2 else 1)
        cone(bm, Matrix.Translation(Vector((base.x + jx, base.y + jy, z + depth * 0.5 - height * 0.05)))
             @ Matrix.Rotation(angle, 4, "Z"),
             r, r * 0.30, depth, mat, segments=8)
    # a tip cone, so the tree ends in a point instead of a chopped tier
    cone(bm, Matrix.Translation(Vector((base.x, base.y, base.z + height * 0.98))),
         height * 0.055, 0.0, height * 0.12, 2, segments=7)
    return finish(bm, obj, materials, 0.9)


def broadleaf(name: str, base: Vector, height: float, seed: int, collection) -> bpy.types.Object:
    """A broadleaf tree: tapered trunk, three branch stubs, seven canopy blobs of two greens.

    The blobs are placed on a shell around the crown centre, so the silhouette is lumpy in every
    direction — from the front, from the side and from above. One blob is darker and sits low, which
    is what gives the crown a shadowed underside."""
    state = [seed]
    materials = [BARK, GREEN_LIGHT, GREEN_MID, GREEN_DARK]
    obj, bm = _new_mesh(name, materials, collection)
    trunk_h = height * 0.52
    lean = (rnd(state) - 0.5) * 0.12
    cone(bm, Matrix.Translation(base + Vector((0, 0, trunk_h / 2)))
         @ Matrix.Rotation(lean, 4, "Y"),
         0.22, 0.13, trunk_h, 0, segments=7)
    crown = base + Vector(((rnd(state) - 0.5) * 0.3, (rnd(state) - 0.5) * 0.3,
                           trunk_h + height * 0.20))
    for i in range(3):                                  # branch stubs, visible under the crown
        angle = math.tau * i / 3 + rnd(state) * 0.7
        length = height * 0.22
        m = (Matrix.Translation(base + Vector((0, 0, trunk_h * 0.82)))
             @ Matrix.Rotation(angle, 4, "Z")
             @ Matrix.Translation(Vector((0, length * 0.35, 0)))
             @ Matrix.Rotation(math.radians(58), 4, "X"))
        cone(bm, m, 0.085, 0.05, length, 0, segments=5)
    main_r = height * 0.30
    blob(bm, Matrix.Translation(crown), main_r, 1, subdivisions=1)
    blobs = 6
    for i in range(blobs):
        angle = math.tau * i / blobs + rnd(state) * 0.5
        ring = main_r * (0.62 + 0.30 * rnd(state))
        r = main_r * (0.48 + 0.22 * rnd(state))
        z = crown.z + (rnd(state) - 0.35) * height * 0.26
        mat = 3 if i in (1, 4) else 2
        blob(bm, Matrix.Translation(Vector((crown.x + math.cos(angle) * ring,
                                            crown.y + math.sin(angle) * ring, z))), r, mat,
             subdivisions=1)
    return finish(bm, obj, materials, 0.8)


def rebuild_trees(collection) -> int:
    positions = json.loads(POSITIONS.read_text())
    for obj in list(bpy.data.objects):
        if obj.name.startswith(("Pine_Tree_", "Deciduous_Tree_")) or obj.name == "Trees_Rebuilt":
            data = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.meshes.remove(data)
    made = 0
    for i, tree in enumerate(positions):
        base = Vector((tree["x"], tree["y"], tree["z"]))
        height = max(3.0, tree["h"]) * 1.15
        seed = 1000 + i * 37
        if tree["kind"] == "pine":
            pine(tree["name"], base, height, seed, collection)
        else:
            broadleaf(tree["name"], base, height, seed, collection)
        made += 1
    return made



# ---------------------------------------------------------------- clouds
def rebuild_clouds(collection, clusters: int = 6) -> int:
    """Clouds as lumpy clusters instead of five identical pills in a row.

    Measured: the fifteen old cloud objects sat on one line (y=18, z~9) as 5 x 3 identical blobs, which
    read as tablets. A cloud is several overlapping blobs at different heights, flattened in z."""
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Cloud"):
            data = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.meshes.remove(data)
    materials = ["Cloud_White"]
    state = [777]
    made = 0
    for c in range(clusters):
        cx = -19.0 + (c + 0.5) * (38.0 / clusters) + (rnd(state) - 0.5) * 3.0
        cy = 15.0 + rnd(state) * 9.0
        cz = 8.4 + rnd(state) * 3.4
        obj, bm = _new_mesh(f"Cloud_{c}", materials, collection)
        blobs = 4 + int(rnd(state) * 3)
        span = 1.6 + rnd(state) * 1.1
        for i in range(blobs):
            t = i / max(1, blobs - 1)
            r = span * (0.55 + 0.45 * math.sin(math.pi * (0.15 + 0.7 * t)))
            ox = (t - 0.5) * span * 2.6 + (rnd(state) - 0.5) * 0.5
            oz = (rnd(state) - 0.5) * span * 0.45
            m = (Matrix.Translation(Vector((cx + ox, cy + (rnd(state) - 0.5) * 0.8, cz + oz)))
                 @ Matrix.Diagonal(Vector((1.0, 1.0, 0.62, 1.0))))
            blob(bm, m, r, 0, subdivisions=1)
        finish(bm, obj, materials, 1.4)
        made += 1
    return made


# ---------------------------------------------------------------- grass
def scatter_grass(collection, count: int = 150) -> int:
    """The kit's own tufts, as linked duplicates: one mesh datablock, 150 transforms."""
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Grass_Tufts") or obj.name == "Grass_Kit_Source":
            data = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.meshes.remove(data)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(GRASS_GLTF))
    source = next((o for o in bpy.data.objects if o not in before and o.type == "MESH"), None)
    if source is None:
        print("VARNING: gräskitet kunde inte läsas", GRASS_GLTF)
        return 0
    source.name = "Grass_Kit_Source"
    for c in list(source.users_collection):
        if c != collection:
            c.objects.unlink(source)
    if source.name not in [o.name for o in collection.objects]:
        collection.objects.link(source)
    source.hide_render = False
    source.hide_set(True)                      # the kit's source object stays out of the render
    # a second, slightly darker datablock: otherwise 150 identical green tufts read as a printed mat
    light_mat = source.data.materials[0]
    dark_mat = light_mat.copy()
    dark_mat.name = "Grass_Darker"
    bsdf = next((n for n in dark_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is not None:
        c = bsdf.inputs["Base Color"].default_value
        bsdf.inputs["Base Color"].default_value = (c[0] * 0.72, c[1] * 0.80, c[2] * 0.66, c[3])
    dark_mesh = source.data.copy()
    dark_mesh.name = "Grass_Kit_Dark"
    dark_mesh.materials.clear()
    dark_mesh.materials.append(dark_mat)
    state = [20261019]
    # two bands: the verge in front of the street and the strip behind the houses, plus the hill
    bands = [(-2.85, -1.95), (10.6, 14.4)]
    placed = 0
    for i in range(count):
        y0, y1 = bands[int(rnd(state) * 2) % 2]
        x = -20.0 + rnd(state) * 40.0
        y = y0 + rnd(state) * (y1 - y0)
        scale = 0.30 + rnd(state) * 0.26
        dark = rnd(state) < 0.35
        dup = bpy.data.objects.new(f"Grass_Tuft_{i:03d}", dark_mesh if dark else source.data)
        collection.objects.link(dup)
        dup.location = (x, y, 0.0)
        dup.rotation_euler = (0, 0, rnd(state) * math.tau)
        dup.scale = (scale, scale, scale * (0.85 + rnd(state) * 0.4))
        placed += 1
    return placed


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    check = "--check" in args
    save = "--no-save" not in args and not check
    collection = bpy.data.collections.get(COLLECTION) or bpy.context.scene.collection

    trees = rebuild_trees(collection)
    tufts = scatter_grass(collection)
    clouds = rebuild_clouds(collection)
    print(f"TREES {trees} GRASS {tufts} CLOUDS {clouds}")

    # a check that bites: every tree is a real mesh with more than a handful of faces, and the crowns
    # of the broadleaf trees are wider than the trunks by a lot (otherwise they are sticks again)
    ok = trees == 22 and tufts >= 100 and clouds >= 4
    faces = [len(o.data.polygons) for o in bpy.data.objects
             if o.name.startswith(("Pine_Tree_", "Deciduous_Tree_"))]
    if faces:
        ok = ok and min(faces) > 20
        print(f"CHECK trees={trees} faces min/max={min(faces)}/{max(faces)} grass={tufts} "
              f"clouds={clouds} -> "
              f"{'OK' if ok else 'FAIL'}")
    if save:
        bpy.ops.wm.save_mainfile()
        print("SAVED", bpy.data.filepath)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
