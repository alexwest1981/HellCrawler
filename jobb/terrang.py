#!/usr/bin/env python3
"""Rebuild the diorama's backdrop: a stepped mountain ridge instead of five pyramids, voxel trees
with layered crowns, and grass tufts with flowers on the verges.

    blender -b assets/Untitled_byn_kedjan.blend --python jobb/terrang.py -- [--check] [--no-save]

Why: Alex, looking at the overview sheet - "bergen i bakgrunden ser ut som 5 pyramider, å inte berg"
and "sen träden ... gör om dem så de ser ut som i det här spelet" (Luminati: chunky pixel/voxel,
layered crowns, dense low vegetation, no bare geometry).

Measured before the change: Mountain_0..4 were five 4-sided pyramids (6 verts each, 9-11.6 m wide,
7.5-9.4 m tall, PX_Stone Mossy) standing in a row at y~15 - the village is 44 m wide, so a "mountain"
was twice a house. The trees were 10 identical tiers per pine, 6 identical blobs per deciduous.

The scene is left addressable: the range is Mountain_Range + Mountain_Ground, all 22 trees become one
object (Trees_Rebuilt, same positions and heights), and every material used already exists in the file. Deterministic (fixed seed),
so a rerun produces the same range.
"""
from __future__ import annotations

import argparse
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

# --- the look -----------------------------------------------------------------------------------
RIDGE_SPAN = 78.0          # world x from -39 to 39; the village itself is 44 m
STEP = 0.9                 # every height is quantised to this, so the crest reads as voxel steps
CELL = 1.3                 # terrain cell: mountains are a heightfield, not a wall of boxes
MTN_SCALE = 0.40           # Alex 19/10: "berget blev en smula för högt" - one knob for the whole range
STEP_MTN = 1.8             # terrace height: at 0.9 the steps vanished at render scale and the slope read
                           # as smooth low-poly next to voxel houses (measured)
CREST_BAND = 2.6           # the top of a column is bare rock; below it is moss/vegetation
# far: the massif itself. near: foothills in front of it, lower, so a summit is always broken by a
# shoulder in the other layer instead of every crest lining up (that is what made five "pyramids").
RIDGE_FAR = dict(y0=22.0, y1=35.0, x0=-37.0, x1=37.0, scale=1.25,
                 body="PX_Stone Mossy", crest="PX_Stone")
RIDGE_NEAR = dict(y0=14.0, y1=25.0, x0=-30.0, x1=30.0, scale=0.80,
                  body="PX_Stone Mossy", crest="PX_Stone")
TUFT_COUNT = 210
FLOWER_COUNT = 64
SEED = 20261019


def rnd(state: list) -> float:
    """Deterministic 0..1 (the project uses the same LCG style everywhere; no random module state)."""
    state[0] = (state[0] * 1103515245 + 12345) % 2147483648
    return state[0] / 2147483648.0


def sines(x: float) -> float:
    """Ridge profile: three periods plus a fine wobble - a ridge, not a row of cones."""
    return (6.2 * math.sin(x * 0.085 + 0.6)
            + 3.1 * math.sin(x * 0.19 + 2.1)
            + 1.4 * math.sin(x * 0.46 + 0.35)
            + 0.7 * math.sin(x * 1.05))


def ridge_height(x: float) -> float:
    return 16.5 + sines(x)


# --- geometry -----------------------------------------------------------------------------------
def uv_box_project(mesh, metres_per_tile: float = 1.0) -> None:
    """Per-face box projection, in metres per texture tile.

    Done by hand rather than with bpy.ops.uv.cube_project: the operator needs an edit-mode context and
    its poll failed on the second object in a run (measured), and a silent no-op is worse than no UVs.
    The project's rule for pixel plates is 0.5-1 m per tile.
    """
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    mesh.update()
    layer = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            u, w = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[axis]
            layer[li].uv = (u / metres_per_tile, w / metres_per_tile)


def box_object(name: str, boxes: list, materials: list, collection) -> bpy.types.Object:
    """One mesh from many boxes; each box carries (centre, size, rot_z, material name)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    index = {m: i for i, m in enumerate(materials)}
    for centre, size, rot_z, mat in boxes:
        ret = bmesh.ops.create_cube(bm, size=1.0)
        verts = ret["verts"]
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = index[mat]
        mx = (Matrix.Translation(Vector(centre))
              @ Matrix.Rotation(rot_z, 4, "Z")
              @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1.0))))
        bmesh.ops.transform(bm, matrix=mx, verts=verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    for m in materials:
        obj.data.materials.append(bpy.data.materials[m])
    collection.objects.link(obj)
    # UVs or nothing: a textured slot on a mesh with no UV layer samples one undefined texel, which
    # rendered as black and chequered fields over the whole range. Cube projection at one tile per
    # metre is the project's own rule for pixel textures (blender-headless: 0.5-1 m per tile).
    uv_box_project(mesh, 1.0)
    return obj


def crest(x: float) -> float:
    """Height of the crest at x, before the falloff down the slopes is applied."""
    return max(6.0, 17.5 + sines(x))


def ridge_y(x: float) -> float:
    """Where the crest runs in depth. It snakes, so the range has spurs instead of a straight edge."""
    return 25.0 + 5.5 * math.sin(x * 0.065 + 1.1)


def ridge_half(x: float) -> float:
    """Half the depth of the ridge: wide shoulders, narrower saddles."""
    return 8.5 + 2.5 * math.sin(x * 0.13 + 2.6)


def _smooth(values: list, passes: int = 2) -> list:
    """Three-tap smoothing: a crest needs shoulders. Unsmoothed, every cell is its own spike and the
    range reads as a row of pillars (measured on the first two attempts)."""
    out = list(values)
    for _ in range(passes):
        out = [(out[max(0, i - 1)] + 2.0 * out[i] + out[min(len(out) - 1, i + 1)]) / 4.0
               for i in range(len(out))]
    return out


def _hash01(i: int, j: int, seed: int) -> float:
    n = (i * 374761393 + j * 668265263 + seed * 1442695040) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / float(0x1000000)


def _value_noise(x: float, y: float, seed: int) -> float:
    ix, iy = int(math.floor(x)), int(math.floor(y))
    fx, fy = x - ix, y - iy
    sx = fx * fx * (3 - 2 * fx)
    sy = fy * fy * (3 - 2 * fy)
    a = _hash01(ix, iy, seed)
    b = _hash01(ix + 1, iy, seed)
    c = _hash01(ix, iy + 1, seed)
    d = _hash01(ix + 1, iy + 1, seed)
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def _fbm(x: float, y: float, seed: int, octaves: int = 5) -> float:
    total, amp, freq, norm = 0.0, 1.0, 1.0, 0.0
    for _ in range(octaves):
        total += _value_noise(x * freq, y * freq, seed) * amp
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


# Peaks: (x, y, height, radius). Chosen so the row has several summits and real saddles between them,
# and so nothing stands directly above the village gate.
PEAKS = [
    (-34.0, 30.0, 17.0, 11.0),
    (-22.0, 26.0, 21.0, 9.0),
    (-11.0, 32.0, 24.0, 12.0),
    (1.0, 28.0, 19.0, 9.5),
    (11.0, 33.0, 26.0, 12.0),
    (22.0, 27.0, 20.0, 10.0),
    (33.0, 31.0, 16.0, 10.0),
    (6.0, 41.0, 30.0, 16.0),          # the massif behind the row
    (-18.0, 43.0, 27.0, 15.0),
    # foothills: a band of low summits in front of the range, so the mountain rises out of the ground
    # instead of being a wedge parked behind the village (the wedge silhouette was the last complaint)
    (-34.0, 17.5, 4.0, 6.5),
    (-24.0, 15.5, 5.5, 7.5),
    (-14.0, 16.5, 3.5, 6.0),
    (-3.0, 15.0, 5.0, 7.0),
    (8.0, 16.0, 4.2, 6.5),
    (19.0, 15.0, 5.8, 7.5),
    (30.0, 16.5, 4.0, 6.5),
    # spurs off the main crest: shoulders that break the wedge in the side view
    (-27.0, 23.0, 9.0, 8.0),
    (-9.0, 24.0, 11.0, 8.5),
    (13.0, 23.5, 10.0, 8.0),
    (28.0, 25.0, 8.5, 7.5),
]


def _envelope(x: float, y: float, x0: float, x1: float, y0: float, y1: float, fade: float = 12.0) -> float:
    """Fade to zero at the grid border, so the range ends in foothills instead of a sawn-off cliff."""
    e = min((x - x0) / fade, (x1 - x) / fade, (y - y0) / fade, (y1 - y) / fade)
    e = max(0.0, min(1.0, e))
    return e * e * (3.0 - 2.0 * e)


def height_at(x: float, y: float, x0: float = -48.0, x1: float = 48.0,
              y0: float = 14.5, y1: float = 46.0) -> float:
    """Real mountain height: the MAX of several gaussian peaks (a max, not a sum, is what makes sharp
    ridges and saddles between summits) plus ridged noise for shoulders and gullies."""
    h = 0.0
    for px, py, ph, pr in PEAKS:
        d2 = ((x - px) ** 2 + (y - py) ** 2) / (pr * pr)
        if d2 < 9.0:
            h = max(h, ph * math.exp(-d2))
    ridge = 1.0 - abs(2.0 * _fbm(x * 0.055, y * 0.055, 17) - 1.0)
    h *= (0.72 + 0.55 * ridge) * MTN_SCALE
    # fine relief: gullies and ribs. 1.1 was too little on an 11 m range - the surface read as paper
    h += (2.6 * _fbm(x * 0.22, y * 0.22, 91) - 1.0) * 1.7
    h += (1.4 * _fbm(x * 0.55, y * 0.55, 311) - 1.0) * 0.9
    return max(0.0, h) * _envelope(x, y, x0, x1, y0, y1)


def build_ridge(collection) -> list:
    """A modelled mountain range: one triangulated heightfield, flat-shaded, with the project's stone
    textures and cube-projected UVs.

    History, because each attempt failed for a measurable reason: the original was five 4-sided
    pyramids; boxes filled to the ground read as a jagged wall (a horizontal top face is edge-on in
    the ortho front view) and their coincident faces rendered as a black/grey chequer; a box relief
    read as a thin backdrop. A real surface mesh is the only shape that reads as a mountain from all
    four views, and flat shading keeps it in the project's low-poly language."""
    cx, cy, cell = 0.0, 30.0, 0.9
    nx, ny = 78, 36                    # 70 x 32 m: the range must not out-measure the village 2x
    x0, x1 = cx - nx * cell / 2.0, cx + nx * cell / 2.0
    y0, y1 = cy - ny * cell / 2.0, cy + ny * cell / 2.0
    verts, faces, mat_of_face = [], [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = cx + (i - nx / 2) * cell
            y = cy + (j - ny / 2) * cell
            # a quarter-cell of jitter breaks the regular grid; a real mountain has no rows
            jx = (_hash01(i, j, 5) - 0.5) * 0.75
            jy = (_hash01(i, j, 6) - 0.5) * 0.75
            # heights are quantised into terraces: the project's whole language is voxel, and a smooth
            # hillside next to voxel houses reads as two different games (measured: "smooth grey clay
            # versus the village's sharp voxels")
            h = height_at(x, y, x0, x1, y0, y1)
            verts.append((x + jx, y + jy, round(h / STEP_MTN) * STEP_MTN))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            b, c, d = a + 1, a + nx + 1, a + nx + 2
            h = (verts[a][2] + verts[b][2] + verts[c][2] + verts[d][2]) / 4.0
            # three bands: grass at the foot, mossy stone as a treeline, bare rock on the summits.
            # Two bands only left a dark rock strip along the whole foot, which read as a cut band.
            # thresholds were 1.6/7.0 m against a 12.7 m range, so almost the whole massif got the dark
            # mossy plate and read as a black wall. Measured plates: grass 0.288, mossy 0.255,
            # stone 0.354 luma - the rock is what should dominate a mountain.
            band = 0 if h < 1.2 else (1 if h < 3.4 else 2)
            mat_of_face += [band, band]
            faces += [(a, b, d), (a, d, c)]
    mesh = bpy.data.meshes.new("Mountain_Range")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    for poly, m in zip(mesh.polygons, mat_of_face):
        poly.material_index = m
        poly.use_smooth = False
    mesh.update()
    obj = bpy.data.objects.new("Mountain_Range", mesh)
    for mat in ("PX_Grass", "PX_Stone Mossy", "PX_Stone"):
        obj.data.materials.append(bpy.data.materials[mat])
    collection.objects.link(obj)

    uv_box_project(mesh, 2.0)

    ground = box_object("Mountain_Ground",
                        [((0.0, 30.5, -0.45), (98.0, 33.0, 0.6), 0.0, "PX_Grass")],
                        ["PX_Grass"], collection)
    ground.visible_shadow = False

    # the range must not shadow the village: measured 10 % of the front pane at near-black when the
    # far peaks cast onto the near slopes
    obj.visible_shadow = False
    return [obj]


def _frange(a: float, b: float, step: float):
    out = []
    x = a
    while x <= b:
        out.append(x)
        x += step
    return out


def add_boxes(boxes: list, centre, size, rot_z, mat) -> None:
    boxes.append((centre, size, rot_z, mat))


def build_pine(boxes: list, base: Vector, height: float, state: list) -> None:
    """Trunk plus five shrinking tiers. Tier widths and the shadow tier are what stop it reading as a
    single stacked triangle."""
    trunk_h = height * 0.34
    add_boxes(boxes, (base.x, base.y, base.z + trunk_h / 2.0),
              (0.36, 0.36, trunk_h), 0.0, "PX_Bark")
    tiers = 6
    z = base.z + trunk_h * 1.05
    for i in range(tiers):
        t = i / (tiers - 1.0)
        w = height * (0.40 - 0.26 * t)
        h = height * (0.22 - 0.08 * t)
        jx = (rnd(state) - 0.5) * 0.16 * height
        jy = (rnd(state) - 0.5) * 0.16 * height
        mat = "PX_Barr" if i == 2 else "PX_Lövverk"
        add_boxes(boxes, (base.x + jx, base.y + jy, z + h / 2.0), (w, w * 0.94, h), 0.0, mat)
        z += h * 0.72


def build_deciduous(boxes: list, base: Vector, height: float, state: list) -> None:
    """Trunk plus four lumpy blobs: one main crown, three shoulders, one low branch clump. Offsets are
    what make the silhouette read as leaves rather than a box on a stick."""
    trunk_h = height * 0.46
    add_boxes(boxes, (base.x, base.y, base.z + trunk_h / 2.0),
              (0.42, 0.42, trunk_h), 0.0, "PX_Bark")
    cz = base.z + trunk_h * 0.95
    main = height * 0.52
    add_boxes(boxes, (base.x, base.y, cz + main * 0.42), (main, main * 0.92, main * 0.80), 0.0,
              "PX_Lövverk")
    for i, (dx, dy, dz, s) in enumerate([(-0.34, 0.06, 0.04, 0.62), (0.36, -0.04, 0.08, 0.58),
                                         (0.06, 0.30, 0.26, 0.50), (0.12, -0.26, 0.12, 0.48),
                                         (-0.14, -0.02, -0.22, 0.54), (0.20, 0.10, -0.10, 0.44)]):
        add_boxes(boxes, (base.x + dx * main, base.y + dy * main, cz + main * (0.42 + dz)),
                  (main * s, main * s * 0.92, main * s * 0.82), 0.0,
                  "PX_Hedge" if i % 2 else "PX_Lövverk")


def rebuild_trees(collection) -> tuple:
    """Keep every tree's place and height; replace its parts. Placement was already composed."""
    families = {}
    import re as _re
    pattern = _re.compile(r"^((?:Pine|Deciduous)_Tree_\d+)")
    for obj in list(bpy.data.objects):
        if obj.type != "MESH":
            continue
        m = pattern.match(obj.name)
        if m:
            families.setdefault(m.group(1), []).append(obj)
    if not families:
        # second run: the trees are already rebuilt, and rebuilding from nothing would delete them
        existing = bpy.data.objects.get("Trees_Rebuilt")
        if existing is not None:
            return existing, 22, len(existing.data.polygons) // 6
    boxes = []
    state = [SEED + 99]
    # build every new tree BEFORE removing any old part: a crash between the two left the file with no
    # trees at all (measured - a failed run deleted all 22 families and saved nothing back)
    doomed = []
    for fam, parts in sorted(families.items()):
        xs, ys, zs = [], [], []
        for p in parts:
            for c in p.bound_box:
                w = p.matrix_world @ Vector(c)
                xs.append(w.x)
                ys.append(w.y)
                zs.append(w.z)
        base = Vector(((min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0, min(zs)))
        height = (max(zs) - min(zs)) * 1.08
        if fam.startswith("Pine"):
            build_pine(boxes, base, height, state)
        else:
            build_deciduous(boxes, base, height, state)
        doomed.extend(parts)
    old = bpy.data.objects.get("Trees_Rebuilt")
    if old is not None:
        data = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if data.users == 0:
            bpy.data.meshes.remove(data)
    obj = box_object("Trees_Rebuilt", boxes,
                     ["PX_Bark", "PX_Barr", "PX_Hedge", "PX_Lövverk"], collection)
    for p in doomed:
        data = p.data
        bpy.data.objects.remove(p, do_unlink=True)
        if data.users == 0:
            bpy.data.meshes.remove(data)
    return obj, len(families), len(boxes)


def build_grass(collection) -> tuple:
    """Tufts and flowers on the two verges the front view actually shows (in front of the street and
    behind the houses). Scattered inside those bands only, so nothing pokes through a floor."""
    boxes = []
    state = [SEED + 501]
    bands = [(-2.85, -1.95), (10.6, 14.4)]
    for _ in range(TUFT_COUNT // 3):
        y0, y1 = bands[int(rnd(state) * 2) % 2]
        cx = -20.0 + rnd(state) * 40.0
        cy = y0 + rnd(state) * (y1 - y0)
        # a tuft is a CLUSTER: three blades at different heights, else it reads as a hedge
        for blade in range(3):
            x = cx + (rnd(state) - 0.5) * 0.55
            y = cy + (rnd(state) - 0.5) * 0.55
            h = 0.35 + rnd(state) * 0.75
            ang = (rnd(state) - 0.5) * 0.5
            add_boxes(boxes, (x, y, h / 2.0), (0.10, 0.10, h), ang,
                      "PX_Barr" if blade == 2 else "PX_Grass")
    for _ in range(FLOWER_COUNT):
        y0, y1 = bands[int(rnd(state) * 2) % 2]
        x = -20.0 + rnd(state) * 40.0
        y = y0 + rnd(state) * (y1 - y0)
        add_boxes(boxes, (x, y, 0.60), (0.26, 0.26, 0.26), 0.0, "PX_Ljus Varm")
        add_boxes(boxes, (x, y, 0.28), (0.07, 0.07, 0.56), 0.0, "PX_Grass")
    obj = box_object("Grass_Tufts", boxes, ["PX_Grass", "PX_Barr", "PX_Ljus Varm"], collection)
    return obj, len(boxes)


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    check = "--check" in args
    save = "--no-save" not in args and not check
    collection = bpy.data.collections.get("Collection") or bpy.context.scene.collection

    removed = []
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Mountain_"):
            removed.append(obj.name)
            data = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if data and data.users == 0:
                bpy.data.meshes.remove(data)

    ridge = build_ridge(collection)
    print(f"REMOVED {removed}")
    for o in ridge:
        print(f"BUILT {o.name:26s} tris={len(o.data.polygons):5d} verts={len(o.data.vertices):6d}")

    sampled = [height_at(x, 30.0) for x in _frange(-40.0, 40.0, 1.5)]
    peaks = sum(1 for i in range(1, len(sampled) - 1)
                if sampled[i] > sampled[i - 1] and sampled[i] > sampled[i + 1] and sampled[i] > 5.0)
    spread = max(sampled) - min(sampled)
    ok = peaks >= 3 and spread > 5.0 and max(sampled) > 9.0
    print(f"CHECK peaks={peaks} spread={spread:.1f} max={max(sampled):.1f} -> {'OK' if ok else 'FAIL'}")

    if save:
        bpy.ops.wm.save_mainfile()
        print("SAVED", bpy.data.filepath)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
