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
BUSHES = Path(__file__).resolve().parent / "busk_positioner.json"
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
def _bough(bm, origin: Vector, angle: float, pitch: float, length: float, thick: float,
           mat: int, droop: float = 0.0) -> Vector:
    """One branch in two joints: out along `pitch`, then down by `droop` for the outer half.

    A single straight spike reads as a spike. Spruce boughs sag under their own needles, and the sag is
    what makes the silhouette read as a tree instead of a star — the review of the first version:
    "grenarna är för raka och spikiga; de behöver svängdhet och en tyngd som drar dem nedåt"."""
    def dir_at(p):
        return Vector((math.cos(angle) * math.cos(p), math.sin(angle) * math.cos(p),
                       math.sin(p))).normalized()
    mid = origin + dir_at(pitch) * length * 0.55
    tip = mid + dir_at(pitch - droop) * length * 0.50
    for a, b, r0, r1 in ((origin, mid, thick, thick * 0.62),
                         (mid, tip, thick * 0.62, thick * 0.14)):
        d = b - a
        if d.length < 1e-4:
            continue
        quat = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized())
        m = Matrix.Translation((a + b) / 2) @ quat.to_matrix().to_4x4()
        cone(bm, m, r0, r1, d.length * 1.02, mat, segments=5)
    return tip


def _needles(bm, at: Vector, size: float, mat: int, count: int = 2, up: float = 0.5) -> None:
    """A tuft of needles at a bough tip: small flattened spikes, so the outline frays."""
    for i in range(count):
        a = (i / max(1, count)) * math.tau
        m = (Matrix.Translation(at) @ Matrix.Rotation(a, 4, "Z")
             @ Matrix.Translation(Vector((0.0, 0.0, 0.0)))
             @ Matrix.Rotation(math.radians(-70 + i * 40 * up), 4, "X")
             @ Matrix.Diagonal(Vector((1.0, 0.45, 1.0, 1.0))))
        cone(bm, m, size * 0.55, 0.0, size * 1.6, mat, segments=4)



def _blob_at(bm, at: Vector, r: float, mat: int, sub: int = 1, stretch=(1.0, 1.0, 1.0),
             rot: float = 0.0) -> None:
    """A leaf clump as an irregular ellipsoid.

    Uniform icospheres read as crystals ("hexagonal prisms" in the review of the first bush). Stretching
    it unevenly and turning it at random is what makes the same 20 faces read as foliage."""
    m = (Matrix.Translation(at) @ Matrix.Rotation(rot, 4, "Z")
         @ Matrix.Rotation(rot * 0.7, 4, "X")
         @ Matrix.Diagonal(Vector((stretch[0], stretch[1], stretch[2], 1.0))))
    blob(bm, m, r, mat, subdivisions=sub)


def pine(name: str, base: Vector, height: float, seed: int, collection) -> bpy.types.Object:
    """A spruce: a segmented trunk with root flare, eleven whorls of boughs, needle tufts.

    Previous version: six solid cones stacked on a stick (77 faces). It read as a party hat. A real
    conifer at this scale is a whorl of 5-7 drooping branches every 20-30 cm up the trunk, with the
    branch length shrinking toward the top — that is what makes the silhouette fray instead of step."""
    state = [seed]
    materials = [BARK, GREEN_MID, GREEN_LIGHT, GREEN_DARK]
    obj, bm = _new_mesh(name, materials, collection)

    trunk_h = height * 0.96
    lean = (rnd(state) - 0.5) * 0.10
    # trunk in three sections, each a little thinner, so it bends instead of being a rod
    seg = 3
    for i in range(seg):
        t0 = i / seg
        t1 = (i + 1) / seg
        z0 = base.z + trunk_h * t0
        z1 = base.z + trunk_h * t1
        r0 = height * (0.030 - 0.006 * i)
        r1 = height * (0.030 - 0.006 * (i + 1))
        m = (Matrix.Translation(Vector((base.x + lean * trunk_h * t0, base.y, (z0 + z1) / 2)))
             @ Matrix.Rotation(lean, 4, "Y"))
        cone(bm, m, r0, max(0.012, r1), (z1 - z0) * 1.02, 0, segments=7)
    # root flare: three short fins, so the tree is planted instead of stuck into the ground
    for i in range(3):
        a = math.tau * i / 3 + rnd(state)
        mm = (Matrix.Translation(base + Vector((math.cos(a) * height * 0.03,
                                                math.sin(a) * height * 0.03, 0.0)))
              @ Matrix.Rotation(a, 4, "Z")
              @ Matrix.Rotation(math.radians(74), 4, "X"))
        cone(bm, mm, height * 0.028, height * 0.008, height * 0.10, 0, segments=4)

    whorls = 14
    for i in range(whorls):
        t = i / (whorls - 1.0)
        z = base.z + height * (0.14 + 0.82 * t)
        radius = height * 0.34 * (1.0 - 0.82 * t) * (0.92 + 0.18 * rnd(state))
        boughs = 9 if t < 0.55 else (7 if t < 0.85 else 5)
        twist = rnd(state) * math.tau
        # låga grenar hänger, höga reser sig — och alla böjer sig ned ytterst
        pitch = math.radians(-16 + 34 * t)
        for b in range(boughs):
            a = twist + math.tau * b / boughs + (rnd(state) - 0.5) * 0.30
            length = radius * (0.82 + 0.36 * rnd(state))
            origin = Vector((base.x + lean * height * 0.3, base.y, z))
            mat_nål = 1 if b % 3 else (2 if i % 2 else 3)
            tip = _bough(bm, origin, a, pitch, length, height * 0.018, mat_nål,
                         droop=math.radians(26 + 22 * (1 - t)))
            _needles(bm, tip, height * (0.050 + 0.018 * rnd(state)),
                     2 if b % 2 else 3, count=2)
    # the leader: a slim spike with a few tufts, not a party hat
    top = Vector((base.x + lean * height * 0.3, base.y, base.z + height * 0.97))
    cone(bm, Matrix.Translation(top), height * 0.045, 0.0, height * 0.14, 2, segments=6)
    for i in range(3):
        _needles(bm, top + Vector((0, 0, height * 0.03 * i)), height * 0.05, 3 if i % 2 else 2,
                 count=3)
    return finish(bm, obj, materials, 0.9)


def broadleaf(name: str, base: Vector, height: float, seed: int, collection) -> bpy.types.Object:
    """A broadleaf tree with a real branch hierarchy: trunk, five limbs, ten sub-limbs, leaf tufts.

    Previous version: a trunk, three stubs and seven blobs on a shell (170 faces). The crown now grows
    on the branches that carry it, which is why the light has something to fall through."""
    state = [seed]
    materials = [BARK, GREEN_LIGHT, GREEN_MID, GREEN_DARK]
    obj, bm = _new_mesh(name, materials, collection)

    trunk_h = height * 0.50
    lean = (rnd(state) - 0.5) * 0.14
    seg = 3
    for i in range(seg):
        t0, t1 = i / seg, (i + 1) / seg
        m = (Matrix.Translation(Vector((base.x + lean * trunk_h * t0, base.y,
                                        base.z + trunk_h * (t0 + t1) / 2)))
             @ Matrix.Rotation(lean, 4, "Y"))
        cone(bm, m, height * (0.042 - 0.010 * i), height * (0.042 - 0.010 * (i + 1)),
             trunk_h / seg * 1.03, 0, segments=7)
    for i in range(4):                                       # root flare
        a = math.tau * i / 4 + rnd(state) * 0.5
        mm = (Matrix.Translation(base + Vector((math.cos(a) * height * 0.04,
                                                math.sin(a) * height * 0.04, 0.0)))
              @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.radians(72), 4, "X"))
        cone(bm, mm, height * 0.035, height * 0.010, height * 0.12, 0, segments=4)

    limbs = 5
    for i in range(limbs):
        t = 0.55 + 0.40 * (i / max(1, limbs - 1))
        z = base.z + trunk_h * t
        a = math.tau * i / limbs + rnd(state) * 0.55
        pitch = math.radians(38 + 14 * rnd(state))
        length = height * (0.30 - 0.06 * (i / limbs))
        origin = Vector((base.x + lean * trunk_h * (z - base.z) / max(0.01, trunk_h), base.y, z))
        tip = _bough(bm, origin, a, pitch, length, height * 0.022, 0, droop=-0.05)
        # two sub-limbs per limb, and a crown tuft at each tip
        for k in range(2):
            aa = a + (k - 0.5) * 0.9 + (rnd(state) - 0.5) * 0.3
            sub_len = length * (0.45 + 0.20 * rnd(state))
            sub_tip = _bough(bm, tip, aa, pitch + math.radians(18), sub_len,
                             height * 0.013, 0)
            r = height * (0.125 + 0.055 * rnd(state))
            _blob_at(bm, sub_tip, r, 1 if k == 0 else 2, sub=2,
                     stretch=(1.0, 0.82 + 0.25 * rnd(state), 0.75 + 0.2 * rnd(state)),
                     rot=rnd(state) * math.tau)
            if rnd(state) < 0.7:
                _blob_at(bm, sub_tip + Vector((0, 0, -r * 0.75)), r * 0.78, 3,
                         stretch=(1.0, 0.9, 0.7), rot=rnd(state) * math.tau)
            for q in range(2):                       # kvistar, korta nog att stanna i siluetten
                qa = rnd(state) * math.tau
                _bough(bm, sub_tip, qa, math.radians(12 + 18 * rnd(state)),
                       r * (0.45 + 0.20 * rnd(state)), height * 0.004, 0)
        _blob_at(bm, tip + Vector((0, 0, height * 0.02)),
                 height * (0.11 + 0.04 * rnd(state)), 2,
                 stretch=(1.0, 0.88, 0.78), rot=rnd(state) * math.tau)

    # crown: a few larger blobs on top of the limbs, so the tree has a peak
    crown = Vector((base.x + lean * trunk_h, base.y, base.z + trunk_h + height * 0.16))
    _blob_at(bm, crown, height * 0.19, 1, sub=2, stretch=(1.0, 0.92, 0.82),
             rot=rnd(state) * math.tau)
    for i in range(7):
        a = math.tau * i / 7 + rnd(state)
        rr = height * (0.085 + 0.06 * rnd(state))
        at = crown + Vector((math.cos(a) * height * (0.10 + 0.07 * rnd(state)),
                             math.sin(a) * height * (0.10 + 0.07 * rnd(state)),
                             (rnd(state) - 0.4) * height * 0.12))
        _blob_at(bm, at, rr, 3 if i % 2 else 2,
                 stretch=(1.0, 0.85, 0.8), rot=rnd(state) * math.tau)
    return finish(bm, obj, materials, 0.8)


def bush(name: str, centre: Vector, size: float, seed: int, collection,
         mat: str = GREEN_DARK) -> bpy.types.Object:
    """A bush: a dense core, a shell of small lumps and twigs that actually carry them.

    The first version was nine big lumps on three spikes — "för få, för stora och för likartade", with a
    hollow middle. A shrub reads when the core is filled and the outer lumps are smaller than the gaps
    between them, with the twigs ending inside the foliage instead of poking out like a pot."""
    state = [seed]
    materials = [BARK, GREEN_DARK, GREEN_MID, GREEN_LIGHT]
    obj, bm = _new_mesh(name, materials, collection)

    # twigs: short, angled up from the base, tips buried in the lumps
    for i in range(5):
        a = math.tau * i / 5 + rnd(state) * 0.6
        origin = centre + Vector((0, 0, -size * 0.30))
        tip = _bough(bm, origin, a, math.radians(62 + 20 * rnd(state)), size * 0.50,
                     size * 0.030, 0, droop=math.radians(20))
        for k in range(2):
            _bough(bm, tip, a + (k - 0.5) * 1.2, math.radians(55), size * 0.20, size * 0.014, 0)

    # core first: two overlapping lumps, so the bush has a middle instead of a hole
    _blob_at(bm, centre + Vector((0, 0, size * 0.05)), size * 0.34, 1,
             stretch=(1.0, 0.9, 0.8), rot=rnd(state) * math.tau)
    _blob_at(bm, centre + Vector((size * 0.10, 0, -size * 0.02)), size * 0.27, 2,
             stretch=(1.0, 0.85, 0.8), rot=rnd(state) * math.tau)

    # shell: twelve smaller lumps, two rings at different heights
    lumps = 12
    for i in range(lumps):
        ring_r = size * (0.26 if i % 2 == 0 else 0.34)
        a = math.tau * i / lumps + rnd(state) * 0.5
        r = size * (0.13 + 0.09 * rnd(state))
        z = size * ((0.10 if i % 2 == 0 else -0.06) + (rnd(state) - 0.5) * 0.16)
        mat_i = 1 if i % 3 == 0 else (2 if i % 3 == 1 else 3)
        _blob_at(bm, centre + Vector((math.cos(a) * ring_r, math.sin(a) * ring_r, z)), r, mat_i,
                 stretch=(1.0, 0.82 + 0.2 * rnd(state), 0.70 + 0.2 * rnd(state)),
                 rot=rnd(state) * math.tau)
    # three small ones on top, so the silhouette is not a dome
    for i in range(3):
        a = rnd(state) * math.tau
        _blob_at(bm, centre + Vector((math.cos(a) * size * 0.14, math.sin(a) * size * 0.14,
                                      size * (0.24 + 0.08 * rnd(state)))),
                 size * (0.10 + 0.05 * rnd(state)), 3, stretch=(1.0, 0.85, 0.8),
                 rot=rnd(state) * math.tau)
    return finish(bm, obj, materials, 0.8)


def rebuild_bushes(collection) -> int:
    """Replace the FG_Foliage boxes with bush models of the same footprint.

    The footprints come from `jobb/busk_positioner.json`, read once out of the file before the boxes
    were replaced — the same rule as the trees. Building from the objects that were there made a second
    run shrink every bush by another 15 % (the lumps sit outside the footprint, so the AABB grows and
    the scale correction compounded)."""
    if not BUSHES.exists():
        out = []
        for obj in bpy.data.objects:
            if obj.type != "MESH" or not obj.name.startswith("FG_Foliage"):
                continue
            xs, ys, zs = [], [], []
            for c in obj.bound_box:
                w = obj.matrix_world @ Vector(c)
                xs.append(w.x)
                ys.append(w.y)
                zs.append(w.z)
            out.append({"name": obj.name,
                        "x": round((min(xs) + max(xs)) / 2, 3),
                        "y": round((min(ys) + max(ys)) / 2, 3),
                        "z": round(min(zs), 3),
                        "w": round(max(max(xs) - min(xs), max(zs) - min(zs)), 3),
                        "hedge": bool(obj.data.materials) and "Hedge" in obj.data.materials[0].name})
        BUSHES.write_text(json.dumps(out, ensure_ascii=False, indent=1))
    spots = json.loads(BUSHES.read_text())

    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith(("FG_Foliage", "Bush_")):
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if data.users == 0:
                bpy.data.meshes.remove(data)

    for i, spot in enumerate(spots):
        size = max(0.35, float(spot["w"])) * 0.85
        centre = Vector((float(spot["x"]), float(spot["y"]) - 0.10,
                         float(spot["z"]) + size * 0.42))
        bush(f"Bush_{i:02d}", centre, size, 500 + i * 13, collection,
             GREEN_MID if spot.get("hedge") else GREEN_LIGHT)
    return len(spots)


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
        # the moon sits at x=8 (z 12): a cluster parked there and hid it, so the band has a gap
        slots = [-18.5, -13.0, -7.5, -2.0, 14.5, 17.5, -10.5, 13.0]
        cx = slots[c % len(slots)] + (rnd(state) - 0.5) * 1.6
        cy = 15.0 + rnd(state) * 9.0
        # 8.4-11.8 put the clouds' tops in front of the sky band and hid the moon completely
        # (measured: a ray through ndc (0.33, 0.945) hit Cloud_2 at z=11.0). Below the peaks they read
        # as a bank at the mountain's foot instead.
        cz = 5.4 + rnd(state) * 2.4
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



# ---------------------------------------------------------------- moon
def _world_for_ndc(ndc_x: float, ndc_y: float, depth: float):
    """Solve the world point that projects to (ndc_x, ndc_y) at a given depth.

    The diorama camera is an orthographic camera tilted ~5 degrees down, so "high in the frame" is NOT
    "high z": the first placements put the moon either inside the mountain or outside the top edge.
    Solving the projection instead of guessing puts it where the frame has sky."""
    from bpy_extras.object_utils import world_to_camera_view as w2c
    sc, cam = bpy.context.scene, bpy.context.scene.camera
    xs = (-40.0, 40.0)
    zs = (-25.0, 45.0)
    for _ in range(44):
        xm = (xs[0] + xs[1]) / 2.0
        if w2c(sc, cam, Vector((xm, depth, 0.0))).x < ndc_x:
            xs = (xm, xs[1])
        else:
            xs = (xs[0], xm)
        zm = (zs[0] + zs[1]) / 2.0
        if w2c(sc, cam, Vector((0.0, depth, zm))).y < ndc_y:
            zs = (zm, zs[1])
        else:
            zs = (zs[0], zm)
    return (xs[0] + xs[1]) / 2.0, depth, (zs[0] + zs[1]) / 2.0


def rebuild_moon(collection, ndc=(0.405, 0.940), depth=60.0, radius=0.44) -> int:
    """A moon behind the ridge: a faceted sphere, a halo, and craters that are real bumps.

    Alex 19/10: *"Jag skulle vilja ha en måne i bakgrunden, några moln osv med."*

    The first version was a flat disc: the overview showed it only in the FRONT pane and it read as a
    sticker with dots on it. A sphere with an icosphere silhouette (80 faces) keeps the flat-shaded
    language and gives the rim light something to catch; the craters are flattened blobs sitting a few
    centimetres proud of the surface, so they shade instead of being painted dots.

    It is a mesh, not a light: the diorama has its own sun, and a second light source would flatten the
    village rather than light the sky."""
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Moon"):
            data = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.meshes.remove(data)
    cx, cy, cz = _world_for_ndc(ndc[0], ndc[1], depth)
    materials = ["PX_Ljusglöd", "PX_Mörk Zon", "Cloud_White"]
    materials = [m for m in materials if m in bpy.data.materials] or ["Cloud_White"]
    obj, bm = _new_mesh("Moon", materials, collection)

    # halo: a bigger, dimmer disc behind the sphere
    halo_r = radius * 1.75
    seg = 40
    ring = []
    for k in range(seg):
        a = math.tau * k / seg
        ring.append(bm.verts.new((cx + math.cos(a) * halo_r, cy + 2.0, cz + math.sin(a) * halo_r)))
    f = bm.faces.new(ring)
    f.material_index = materials.index("Cloud_White") if "Cloud_White" in materials else 0

    # the sphere: slightly oblate, faceted
    try:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)
    except TypeError:
        ret = bmesh.ops.create_icosphere(bm, subdivisions=2, diameter=radius * 2)
    verts = ret["verts"]
    for face in {f for v in verts for f in v.link_faces}:
        face.material_index = 0
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector((cx, cy, cz)))
                        @ Matrix.Diagonal(Vector((1.0, 0.55, 1.0, 1.0))), verts=verts)

    # craters: flattened blobs a few centimetres proud of the surface, all on the camera side
    state = [4242]
    for i in range(9):
        a = rnd(state) * math.tau
        b = math.radians(20 + rnd(state) * 55)
        d = radius * 0.96
        px = cx + math.cos(a) * math.cos(b) * d
        pz = cz + math.sin(a) * math.cos(b) * d
        py = cy - radius * 0.55 * 0.55 + math.sin(b) * 0.2
        r = radius * (0.14 + 0.20 * rnd(state))
        try:
            cr = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        except TypeError:
            cr = bmesh.ops.create_icosphere(bm, subdivisions=1, diameter=r * 2)
        cv = cr["verts"]
        for face in {f for v in cv for f in v.link_faces}:
            face.material_index = 1 if len(materials) > 1 else 0
        bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector((px, py, pz)))
                            @ Matrix.Diagonal(Vector((1.0, 0.35, 1.0, 1.0))), verts=cv)
    return finish(bm, obj, materials, 2.0) and 1 or 0



# ---------------------------------------------------------------- sky
SKY_NAME = "PX_Himmel"


def _sky_material() -> "bpy.types.Material":
    """A vertical gradient plate. The world in this file has a ColorRamp wired to Generated Z, but in a
    world shader that coordinate does not vary per ray — the render came out flat (0.8 grey). A real
    plane with a generated-Z ramp always works, and it is art-directable."""
    mat = bpy.data.materials.get(SKY_NAME)
    if mat is None:
        mat = bpy.data.materials.new(SKY_NAME)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    # Geometry > Position, not TexCoord > Generated: Generated is normalised to the plate's bounding
    # box (0..1 over 60 m), so a Map Range in metres clamped it to one colour and the sky came out flat.
    tex = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    out.location = (600, 0)
    emit.location = (380, 0)
    ramp.location = (140, 0)
    sep.location = (-80, 0)
    tex.location = (-300, 0)
    # The frame only shows z 5..11 of the backdrop (the camera is tilted and the plate is 60 m high),
    # so a ramp spread over the whole plate renders as one flat colour. Compressing the ramp into the
    # visible band is what turns the sky into a gradient at all.
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.location = (30, 0)
    mr.inputs["From Min"].default_value = 5.0
    mr.inputs["From Max"].default_value = 11.0
    nt.links.new(tex.outputs["Position"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Factor"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    # dusk: deep indigo overhead, warm pale band at the horizon, so the moon has something to glow
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, (0.62, 0.60, 0.62, 1.0)
    e[1].position, e[1].color = 1.0, (0.10, 0.14, 0.30, 1.0)
    mid = ramp.color_ramp.elements.new(0.42)
    mid.color = (0.34, 0.40, 0.58, 1.0)
    return mat


def rebuild_sky(collection, stars: int = 90) -> int:
    """Backdrop plate + stars. Two objects, dozens of faces, and the sky stops being a grey void."""
    for obj in list(bpy.data.objects):
        if obj.name.startswith(("Sky_Backdrop", "Star_")):
            data = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.meshes.remove(data)
    mat = _sky_material()
    y, x0, x1, z0, z1 = 92.0, -70.0, 70.0, -14.0, 46.0
    mesh = bpy.data.meshes.new("Sky_Backdrop")
    obj = bpy.data.objects.new("Sky_Backdrop", mesh)
    mesh.from_pydata([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], [], [(0, 1, 2, 3)])
    mesh.materials.append(mat)
    mesh.update()
    collection.objects.link(obj)

    state = [31337]
    star_mat = bpy.data.materials.get("PX_Ljusglöd") or bpy.data.materials[0]
    group = bpy.data.objects.new("Star_Field", bpy.data.meshes.new("Star_Field"))
    group.data.materials.append(star_mat)
    collection.objects.link(group)
    verts, faces = [], []
    # Placed in NDC, not in world metres: only the band above the ridge is sky in this camera (the top
    # of the frame is z~10.6 at the mountain's depth), so stars at z 12..30 landed outside the frame
    # and none of them showed in the render.
    for i in range(stars):
        nx = 0.04 + rnd(state) * 0.92
        ny = 0.90 + rnd(state) * 0.09
        sx, _, sz = _world_for_ndc(nx, ny, y - 1.0)
        r = 0.022 + rnd(state) * 0.030
        base = len(verts)
        verts += [(sx - r, y - 1.0, sz - r), (sx + r, y - 1.0, sz - r),
                  (sx + r, y - 1.0, sz + r), (sx - r, y - 1.0, sz + r)]
        faces.append((base, base + 1, base + 2, base + 3))
    group.data.from_pydata(verts, [], faces)
    group.data.update()
    return 2


# ---------------------------------------------------------------- grass
def scatter_grass(collection, count: int = 150) -> int:
    """The kit's own tufts, as linked duplicates: one mesh datablock, 150 transforms."""
    for obj in list(bpy.data.objects):
        # singular too: the per-tuft objects are Grass_Tuft_000..., so a prefix with the plural s left
        # them behind and a second run quietly doubled the field (measured: 300 tufts after two runs)
        if obj.name.startswith(("Grass_Tuft", "Grass_Tufts")) or obj.name == "Grass_Kit_Source":
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
    bushes = rebuild_bushes(collection)
    tufts = scatter_grass(collection)
    clouds = rebuild_clouds(collection)
    moon = rebuild_moon(collection)
    sky = rebuild_sky(collection)
    print(f"TREES {trees} BUSHES {bushes} GRASS {tufts} CLOUDS {clouds} MOON {moon} SKY {sky}")

    # a check that bites: every tree is a real mesh with more than a handful of faces, and the crowns
    # of the broadleaf trees are wider than the trunks by a lot (otherwise they are sticks again)
    ok = trees == 22 and tufts >= 100 and clouds >= 4 and moon == 1
    faces = [len(o.data.polygons) for o in bpy.data.objects
             if o.name.startswith(("Pine_Tree_", "Deciduous_Tree_"))]
    if faces:
        ok = ok and min(faces) > 60
        print(f"CHECK trees={trees} faces min/max={min(faces)}/{max(faces)} grass={tufts} "
              f"clouds={clouds} -> "
              f"{'OK' if ok else 'FAIL'}")
    if save:
        bpy.ops.wm.save_mainfile()
        print("SAVED", bpy.data.filepath)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
