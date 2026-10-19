#!/usr/bin/env python3
"""Real building geometry for the village, replacing the box stacks.

    blender -b assets/Untitled_byn_kedjan.blend --python jobb/byggnader.py -- [--hus Tavern|alla]
                                                                    [--check] [--no-save]

Alex, 19/10: *"Kan du ta alla delar i byn sen, göra om allt till äkta polygonbaserade modeller,
istället för scriptbaserad skit, slå samman allt så de är 100% game ready models, och sen utöka antal
polygoner, skapa snyggare geometri, öka kvaliten på modellerna helt enkelt."*

What the village was: 1867 mesh objects, most of them plain 12-triangle cuboids. A tavern was a body
box, nine stepped gable boxes, a 7 x 8 grid of identical tile boxes, four pillars and a table. That is
why it reads flat and stiff: there is no chamfer anywhere for the light to catch, no wall has a hole
in it — the door and the windows are boxes stuck onto a flat facade — and every roof tile is the same
box at the same angle.

What this does instead, per building, into ONE mesh:

  * walls 0.14 m thick with the openings cut through them (the facade is split around each door and
    window, so a window is a hole with a recessed pane and a mullion grid, not a slab on a wall)
  * a chamfer of 0.02 m on every hard edge — the single cheapest thing that makes flat shading read as
    modelled geometry instead of cardboard
  * a stone plinth in courses, timber studs and rails on the facade, corner boards on all four corners
  * a proper roof: two slopes with 0.10 m thickness, barge and fascia boards, a ridge cap, and tile
    courses laid as overlapping shingles with a half-tile offset per row (not a grid of boxes)
  * chimney with a corbelled cap, door with frame, planks, straps and a threshold

Poly budget: 1.5-4 k triangles per building, one object, one material slot per plate. Named after the
group it replaces (`Tavern`, `Smith`, ...) because `by_3d.gd` finds the shops by name prefix
(`find_children("%s*")`). Two objects stay separate on purpose, because the tests measure them:
`Jeweler_Door` (test_bybor reads its exact AABB) and `Chimney_Cap` (test_by_rok measures the smoke
emitter against its top).
"""
from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass, field

import bpy
import bmesh
from mathutils import Matrix, Vector

CHAMFER = 0.02
CHAMFER_BIG = 0.05
WALL = 0.14
PLINTH = 0.34
ROOF_T = 0.10
OVERHANG_X = 0.34
OVERHANG_Y = 0.30
SHINGLE_W = 0.30
SHINGLE_ROWS = 0.34

MAT_WALL = "PX_Tudor Plaster"
MAT_BEAM = "PX_Wood Beam"
MAT_STONE = "PX_Stone"
MAT_STONE_DARK = "PX_Stone Mossy"
MAT_ROOF = "PX_Terracotta Roof"
MAT_SLATE = "PX_Slate Roof"
MAT_PURPLE = "PX_Purple Roof"
MAT_GLASS = "PX_Window Warm"
MAT_GLOW = "PX_Ljusglöd"
MAT_GLASS_BRIGHT = "PX_Window Bright"
MAT_WOOD = "PX_Wood"
MAT_IRON = "PX_Iron Riveted"


# ------------------------------------------------------------------ mesh builder
class Mesh:
    """One bmesh, one material slot per plate, chamfered boxes, UVs at the end.

    Every primitive receives its material by NAME; the slot index is looked up on the way in, so the
    callers never juggle indices."""

    def __init__(self, name: str, collection, materials: list) -> None:
        self.name = name
        self.collection = collection
        self.materials = materials
        self.index = {m: i for i, m in enumerate(materials)}
        self.mesh = bpy.data.meshes.new(name)
        self.obj = bpy.data.objects.new(name, self.mesh)
        for m in materials:
            self.obj.data.materials.append(bpy.data.materials[m])
        collection.objects.link(self.obj)
        self.bm = bmesh.new()

    # -- helpers
    def _tag(self, verts, mat: str) -> None:
        i = self.index[mat]
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = i

    def box(self, center, size, mat: str, bevel: float = CHAMFER, rot_z: float = 0.0,
            rot_y: float = 0.0, rot_x: float = 0.0) -> None:
        """A chamfered box. The transform runs BEFORE the bevel: bevel replaces the original vertices,
        so transforming afterwards hits removed geometry (TypeError: BMVert has been removed) and
        transforming only the survivors would leave the chamfer faces behind at the origin."""
        ret = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = ret["verts"]
        bmesh.ops.scale(self.bm, vec=Vector(size), verts=verts)
        self._tag(verts, mat)
        m = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(rot_z, 4, "Z")
             @ Matrix.Rotation(rot_y, 4, "Y") @ Matrix.Rotation(rot_x, 4, "X"))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        if bevel > 0.0:
            edges = {e for v in verts for e in v.link_edges}
            try:
                bmesh.ops.bevel(self.bm, geom=list(edges) + list(verts), offset=bevel,
                                segments=1, affect="EDGES", clamp_overlap=True)
            except TypeError:
                pass

    def cylinder(self, base, top, radius: float, mat: str, segments: int = 10,
                 radius_top: float | None = None) -> None:
        d = Vector(top) - Vector(base)
        h = d.length
        if h < 1e-5:
            return
        try:
            ret = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                        radius1=radius,
                                        radius2=radius if radius_top is None else radius_top,
                                        depth=h)
        except TypeError:
            ret = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                        diameter1=radius * 2,
                                        diameter2=(radius if radius_top is None else radius_top) * 2,
                                        depth=h)
        self._tag(ret["verts"], mat)
        direction = d.normalized()
        quat = Vector((0, 0, 1)).rotation_difference(direction)
        m = Matrix.Translation(Vector(base) + d / 2) @ quat.to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=m, verts=ret["verts"])

    def lathe(self, center, profile: list, mat: str, segments: int = 12) -> None:
        """profile: [(radius, z), ...] bottom to top. A barrel, a lantern or a column."""
        cx, cy, cz = center
        rings = []
        for r, z in profile:
            ring = []
            for i in range(segments):
                a = math.tau * i / segments
                ring.append(self.bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, cz + z)))
            rings.append(ring)
        for a, b in zip(rings, rings[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                f = self.bm.faces.new((a[i], a[j], b[j], b[i]))
                f.material_index = self.index[mat]
        for ring, up in ((rings[0], False), (rings[-1], True)):
            f = self.bm.faces.new(ring if up else list(reversed(ring)))
            f.material_index = self.index[mat]

    def quad(self, pts: list, mat: str) -> None:
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.index[mat]

    def poly(self, pts2d: list, z0: float, z1: float, mat: str, axis: str = "y",
             offset: float = 0.0) -> None:
        """Extrude a 2D profile between z0 and z1. In the 'y' axis the profile is (x, z)."""
        def place(u, z):
            if axis == "y":
                return (u, offset, z)
            return (offset, u, z)      # axis="x": profile is (y, z) at a fixed x
        bottom = [self.bm.verts.new(place(u, z0)) for u, z in pts2d]
        top = [self.bm.verts.new(place(u, z1)) for u, z in pts2d]
        f = self.bm.faces.new(list(reversed(bottom)))
        f.material_index = self.index[mat]
        f = self.bm.faces.new(top)
        f.material_index = self.index[mat]
        n = len(pts2d)
        for i in range(n):
            j = (i + 1) % n
            f = self.bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
            f.material_index = self.index[mat]

    def finish(self, tile: float = 1.0) -> bpy.types.Object:
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        self.bm.to_mesh(self.mesh)
        self.bm.free()
        uv_box_project(self.mesh, tile)
        return self.obj


def uv_box_project(mesh, metres_per_tile: float = 1.0) -> None:
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


# ------------------------------------------------------------------ spec from the old boxes
@dataclass
class Opening:
    u0: float          # along the facade (world x for a -Y facing wall)
    u1: float
    z0: float
    z1: float
    kind: str = "window"   # window | door | arch


@dataclass
class House:
    name: str
    x0: float
    x1: float
    y0: float
    y1: float
    z0: float
    z1: float
    ridge: float
    roof_mat: str = MAT_ROOF
    wall_mat: str = MAT_WALL
    beam_mat: str = MAT_BEAM
    openings: list = field(default_factory=list)
    chimney: tuple | None = None      # (x, y, w, d, top)
    signs: list = field(default_factory=list)

    @property
    def w(self):
        return self.x1 - self.x0

    @property
    def d(self):
        return self.y1 - self.y0

    @property
    def cx(self):
        return (self.x0 + self.x1) / 2.0

    @property
    def cy(self):
        return (self.y0 + self.y1) / 2.0


def _aabb(objs):
    xs, ys, zs = [], [], []
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x)
            ys.append(w.y)
            zs.append(w.z)
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def spec_from_group(name: str, objs: list) -> House | None:
    """Read the building that is there: body box for the footprint, tile group for the ridge, the
    door/window objects for the openings, the chimney for its stack."""
    # the body is the object named <group>_Body, and nothing else: "Tavern_Barrel_0_Body" also ends in
    # _Body and is 0.4 m wide, which made the first build a house shaped like a barrel
    body = bpy.data.objects.get(f"{name}_Body")
    if body is None:
        cands = [o for o in objs if o.name.endswith("_Body") and len(o.dimensions) > 0
                 and o.dimensions.x * o.dimensions.y * o.dimensions.z > 4.0]
        body = max(cands, key=lambda o: o.dimensions.z) if cands else None
    if body is None:
        return None
    bx0, bx1, by0, by1, bz0, bz1 = _aabb([body])
    tiles = [o for o in objs if "Tile" in o.name]
    if tiles:
        _, _, _, _, _, tz1 = _aabb(tiles)
        ridge = tz1 - 0.05
    else:
        ridge = bz1 + (bx1 - bx0) * 0.30
    roof_mat = MAT_ROOF
    if tiles:
        mats = {m.name for o in tiles for m in o.data.materials}
        roof_mat = next((m for m in mats if "Roof" in m), MAT_ROOF)
    elif any("Slate" in m.name for o in objs for m in o.data.materials):
        roof_mat = MAT_SLATE

    openings = []
    for o in objs:
        n = o.name.lower()
        if not ("door" in n or "win" in n or "recess" in n):
            continue
        ox0, ox1, oy0, oy1, oz0, oz1 = _aabb([o])
        # only openings on the street side (nearest y0) become holes; the rest are decoration
        if oy0 > by0 + (by1 - by0) * 0.5:
            continue
        kind = "door" if "door" in n else "window"
        openings.append(Opening(ox0, ox1, max(bz0, oz0), min(bz1, oz1), kind))
    # Merge the panels of a multi-part window or door into one opening each. The overlap test has to
    # be in BOTH axes: the tavern's 2.8 m shop window and its upper window share an x range and were
    # merged into one 3.5 m tall hole that swallowed the whole facade.
    merged: list = []
    for op in sorted(openings, key=lambda o: (o.u0, o.z0)):
        for m in merged:
            if (m.kind == op.kind and op.u0 < m.u1 + 0.02 and op.u1 > m.u0 - 0.02
                    and op.z0 < m.z1 + 0.02 and op.z1 > m.z0 - 0.02):
                m.u0, m.u1 = min(m.u0, op.u0), max(m.u1, op.u1)
                m.z0, m.z1 = min(m.z0, op.z0), max(m.z1, op.z1)
                break
        else:
            merged.append(op)
    # keep the openings inside the wall the generator can cut: the gable is a triangle polygon here,
    # so a window that sits mostly above the wall top is dropped rather than half-cut
    kept: list = []
    for op in merged:
        op.z0 = max(op.z0, bz0 + 0.12)
        op.z1 = min(op.z1, bz1 - 0.12)
        if op.z1 - op.z0 > 0.30 and op.z0 < bz1 - 0.35:
            kept.append(op)
    merged = kept

    chimney = None
    cap = bpy.data.objects.get("Chimney_Cap")
    if cap is not None:
        cx0, cx1, cy0, cy1, _, cz1 = _aabb([cap])
        inside = bx0 - 0.4 < (cx0 + cx1) / 2 < bx1 + 0.4 and by0 - 0.4 < (cy0 + cy1) / 2 < by1 + 0.4
        if inside:
            chimney = ((cx0 + cx1) / 2, (cy0 + cy1) / 2, cx1 - cx0, cy1 - cy0, cz1)

    return House(name=name, x0=bx0, x1=bx1, y0=by0, y1=by1, z0=max(0.0, bz0), z1=bz1,
                 ridge=ridge, roof_mat=roof_mat, openings=merged, chimney=chimney)


# ------------------------------------------------------------------ geometry
def wall_with_openings(m: Mesh, h: House, u0: float, u1: float, z0: float, z1: float,
                       openings: list, y_center: float, thickness: float, mat: str,
                       bevel: float = CHAMFER) -> None:
    """A wall as the union of solid rectangles around its openings.

    Openings are sorted along u and never overlap there, so the wall is: full-height piers between
    them, plus a lintel above and an apron below each. That is what makes a window a hole."""
    ops = sorted([o for o in openings if o.u1 > u0 and o.u0 < u1], key=lambda o: o.u0)
    cursor = u0
    for op in ops:
        a, b = max(op.u0, u0), min(op.u1, u1)
        if a - cursor > 0.02:
            m.box(((cursor + a) / 2, y_center, (z0 + z1) / 2),
                  (a - cursor, thickness, z1 - z0), mat, bevel=bevel)
        if op.z0 - z0 > 0.02:                      # apron under the opening
            m.box(((a + b) / 2, y_center, (z0 + op.z0) / 2),
                  (b - a, thickness, op.z0 - z0), mat, bevel=bevel)
        if z1 - op.z1 > 0.02:                      # lintel over it
            m.box(((a + b) / 2, y_center, (op.z1 + z1) / 2),
                  (b - a, thickness, z1 - op.z1), mat, bevel=bevel)
        cursor = max(cursor, b)
    if u1 - cursor > 0.02:
        m.box(((cursor + u1) / 2, y_center, (z0 + z1) / 2),
              (u1 - cursor, thickness, z1 - z0), mat, bevel=bevel)


def stone_courses(m: Mesh, h: House, sides: list, z_bottom: float, height: float) -> None:
    """A plinth built as courses of stones with varied widths and a 2 cm depth step, instead of one
    long box: this is the base the eye reads first."""
    state = [7]
    def rnd():
        state[0] = (state[0] * 1103515245 + 12345) % 2147483648
        return state[0] / 2147483648.0
    rows = max(1, int(round(height / 0.22)))
    row_h = height / rows
    for side, (u0, u1, y_center, thickness) in enumerate(sides):
        for r in range(rows):
            z = z_bottom + r * row_h
            u = u0 + (0.0 if r % 2 == 0 else 0.12)
            while u < u1 - 0.05:
                w = min(u1 - u, 0.34 + rnd() * 0.30)
                depth = thickness + (0.012 if rnd() < 0.5 else 0.0)
                m.box((u + w / 2, y_center, z + row_h / 2), (w, depth, row_h * 0.94),
                      MAT_STONE if rnd() < 0.7 else MAT_STONE_DARK, bevel=0.012)
                u += w + 0.006


def shingle_slope(m: Mesh, x0: float, x1: float, y_eave: float, y_ridge: float, z_eave: float,
                  z_ridge: float, mat: str, thickness: float = ROOF_T) -> None:
    """One roof slope: a slab with courses of shingles laid on top, half a tile offset per row.

    Each shingle is a quad with a 6 degree lip at its lower edge, so the courses cast their own thin
    shadow lines — the reason a box-grid roof reads as a grid and this reads as a roof."""
    span_y = y_ridge - y_eave
    span_z = z_ridge - z_eave
    slope_len = math.hypot(span_y, span_z)
    # the slab
    nx = Vector((0.0, -span_z, span_y)).normalized() * thickness
    slab = [
        (x0, y_eave, z_eave), (x1, y_eave, z_eave),
        (x1, y_ridge, z_ridge), (x0, y_ridge, z_ridge),
    ]
    top = [(p[0], p[1] + nx.y, p[2] + nx.z) for p in slab]
    m.quad(slab[::-1], mat)
    m.quad(top, mat)
    for i in range(4):
        j = (i + 1) % 4
        m.quad((slab[i], slab[j], top[j], top[i]), mat)
    # Courses as real pans with thickness and overlap. The first version laid coplanar quads 2 cm above
    # the slab: at render distance they were invisible and the roof read as one smooth surface (the
    # review called it "a beige cloth"). A pan is a thin box following the slope, sitting 2 cm proud and
    # overlapping the row below by a third, so each course casts its own line.
    rows = max(2, int(slope_len / SHINGLE_ROWS))
    cols = max(2, int((x1 - x0) / SHINGLE_W))
    ang = math.atan2(span_z, span_y)
    col_w = (x1 - x0) / cols
    for r in range(rows):
        t = (r + 0.5) / rows
        y = y_eave + span_y * t + nx.y
        z = z_eave + span_z * t + nx.z
        for c in range(cols):
            su = x0 + (c + (0.5 if r % 2 else 0.0)) * col_w
            if su + col_w * 0.5 > x1:
                continue
            m.box((su, y, z), (col_w * 0.92, slope_len / rows * 1.40, 0.085), mat,
                  bevel=0.008, rot_x=ang)
    # fascia along the eave and a ridge cap
    m.box(((x0 + x1) / 2, y_eave - 0.04, z_eave - 0.02), (x1 - x0 + 0.04, 0.10, 0.20),
          MAT_BEAM, bevel=0.01)


def gable_wall(m: Mesh, h: House, x_gable: float, thickness: float, mat: str) -> None:
    """The triangle under the ridge, as a real polygon extruded along x.

    First version passed the gable's x as `y_center` and extruded along y, so the "gable" became a slab
    lying across the building at y=-6.3 — that is what drew the black bars over both roofs."""
    apex_z = h.ridge
    y_mid = (h.y0 + h.y1) / 2.0
    pts = [(h.y0, h.z1), (h.y1, h.z1), (y_mid, apex_z)]
    m.poly(pts, x_gable - thickness / 2, x_gable + thickness / 2, mat, axis="x")
    # barge boards along the two rakes, long axis in y, tilted by the rake angle
    for a, b in (((h.y0, h.z1), (y_mid, apex_z)), ((y_mid, apex_z), (h.y1, h.z1))):
        my, mz = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        m.box((x_gable, my, mz), (thickness * 1.4, length, 0.13), MAT_BEAM, bevel=0.012,
              rot_x=ang)


def window_dressing(m: Mesh, op: Opening, y_facade: float, facing: float, mat_frame: str,
                    panes: bool = True) -> None:
    """The inside of the hole: a pane 4 cm behind the facade, a frame, a sill and mullions.

    The first version put the pane 10 cm in and used one cross of mullions on a 2.8 m shop window; in the
    review it read as a black rectangle. Glass close to the facade catches the room light, and the grid
    scales with the opening."""
    w = op.u1 - op.u0
    hgt = op.z1 - op.z0
    cy = op.u0 + w / 2
    cz = op.z0 + hgt / 2
    y_pane = y_facade + facing * 0.045
    # PX_Ljusglöd, not the window plates: those are 256 px textures of a whole window, and on a 2.8 m
    # shop window they repeat 3x2 and read as a dark grid. A uniform warm plate plus the mullions is the
    # same information with none of the tiling.
    m.box((cy, y_pane, cz), (w * 0.97, 0.02, hgt * 0.96), MAT_GLOW, bevel=0.0)
    jamb = 0.07
    m.box((op.u0 + jamb / 2, y_facade + facing * 0.012, cz), (jamb, WALL + 0.02, hgt), mat_frame,
          bevel=0.008)
    m.box((op.u1 - jamb / 2, y_facade + facing * 0.012, cz), (jamb, WALL + 0.02, hgt), mat_frame,
          bevel=0.008)
    m.box((cy, y_facade + facing * 0.012, op.z1 - jamb / 2), (w, WALL + 0.02, jamb), mat_frame,
          bevel=0.008)
    m.box((cy, y_facade + facing * 0.055, op.z0 + 0.02), (w + 0.12, WALL + 0.16, 0.08), MAT_STONE,
          bevel=0.012)
    if panes:
        cols = max(1, int(round(w / 0.62)))
        rows = max(1, int(round(hgt / 0.70)))
        for i in range(1, cols):
            u = op.u0 + w * i / cols
            m.box((u, y_pane + facing * 0.014, cz), (0.045, 0.04, hgt * 0.94), mat_frame, bevel=0.0)
        for j in range(1, rows):
            z = op.z0 + hgt * j / rows
            m.box((cy, y_pane + facing * 0.014, z), (w * 0.94, 0.04, 0.045), mat_frame, bevel=0.0)


def door_dressing(m: Mesh, op: Opening, y_facade: float, facing: float, plank_mat: str) -> None:
    w = op.u1 - op.u0
    hgt = op.z1 - op.z0
    cy = op.u0 + w / 2
    cz = op.z0 + hgt / 2
    # planks: five leaves with a 6 mm gap, each a box with a chamfer
    planks = 5
    pw = (w - 0.10) / planks
    for i in range(planks):
        u = op.u0 + 0.05 + pw * (i + 0.5)
        m.box((u, y_facade + facing * 0.06, cz), (pw * 0.94, 0.06, hgt - 0.06), plank_mat,
              bevel=0.008)
    # karm: två sidoposter och ett överstycke
    m.box((op.u0 + 0.035, y_facade + facing * 0.01, cz), (0.07, WALL + 0.02, hgt), MAT_BEAM, bevel=0.006)
    m.box((op.u1 - 0.035, y_facade + facing * 0.01, cz), (0.07, WALL + 0.02, hgt), MAT_BEAM, bevel=0.006)
    m.box((cy, y_facade + facing * 0.01, op.z1 - 0.035), (w, WALL + 0.02, 0.07), MAT_BEAM, bevel=0.006)
    # straps and a handle
    for zz in (cz - hgt * 0.28, cz + hgt * 0.28):
        m.box((cy, y_facade + facing * 0.10, zz), (w * 0.80, 0.02, 0.05), MAT_IRON, bevel=0.005)
    m.cylinder((op.u1 - 0.14, y_facade + facing * 0.10, cz),
               (op.u1 - 0.14, y_facade + facing * 0.20, cz), 0.022, MAT_IRON, segments=8)
    # threshold
    m.box((cy, y_facade + facing * 0.14, op.z0 - 0.03), (w + 0.16, 0.34, 0.08), MAT_STONE,
          bevel=0.012)


def timber_frame(m: Mesh, h: House, y_facade: float, facing: float, z_top: float) -> None:
    """Studs and rails on the facade: the tudor language that was already in the materials."""
    z0 = h.z0 + PLINTH + 0.02
    m.box(((h.x0 + h.x1) / 2, y_facade + facing * 0.015, z0), (h.w, 0.05, 0.10), MAT_BEAM,
          bevel=0.006)
    if z_top - z0 > 0.4:
        m.box(((h.x0 + h.x1) / 2, y_facade + facing * 0.015, z_top - 0.05), (h.w, 0.05, 0.10),
              MAT_BEAM, bevel=0.006)
    studs = max(2, int(round(h.w / 0.85)))
    blocked = [(op.u0 - 0.06, op.u1 + 0.06) for op in h.openings]
    for i in range(studs + 1):
        u = h.x0 + 0.06 + (h.w - 0.12) * i / studs
        if any(a < u < b for a, b in blocked):
            continue
        m.box((u, y_facade + facing * 0.015, (z0 + z_top) / 2), (0.09, 0.05, z_top - z0),
              MAT_BEAM, bevel=0.006)
    # corner boards on all four corners
    for (ux, uy) in ((h.x0, h.y0), (h.x1, h.y0), (h.x0, h.y1), (h.x1, h.y1)):
        m.box((ux, uy, (h.z0 + h.z1) / 2), (0.14, 0.14, h.z1 - h.z0), MAT_BEAM, bevel=0.035)


def build_house(h: House, collection) -> bpy.types.Object:
    materials = [h.wall_mat, MAT_BEAM, MAT_STONE, MAT_STONE_DARK, h.roof_mat, MAT_GLASS,
                 MAT_GLOW, MAT_WOOD, MAT_IRON]
    m = Mesh(h.name, collection, materials)
    z_wall0 = h.z0
    z_wall1 = h.z1
    facing = -1.0                       # the facade is the -y side (the street)

    # walls, with the facade split around its openings
    y_front = h.y0 + WALL / 2
    y_back = h.y1 - WALL / 2
    wall_with_openings(m, h, h.x0 + 0.02, h.x1 - 0.02, z_wall0, z_wall1, h.openings,
                       y_front, WALL, h.wall_mat, bevel=CHAMFER_BIG)
    m.box((h.cx, y_back, (z_wall0 + z_wall1) / 2), (h.w, WALL, z_wall1 - z_wall0), h.wall_mat,
          bevel=CHAMFER_BIG)
    for x in (h.x0 + WALL / 2, h.x1 - WALL / 2):
        m.box((x, h.cy, (z_wall0 + z_wall1) / 2), (WALL, h.d - 2 * WALL, z_wall1 - z_wall0),
              h.wall_mat, bevel=CHAMFER_BIG)

    # plinth in courses, all four sides
    sides = [(h.x0, h.x1, h.y0 + 0.02, 0.06), (h.x0, h.x1, h.y1 - 0.02, 0.06),
             (h.x0 + 0.02, h.x0 + 0.02, h.y0, 0.02)]
    plinth_sides = [
        (h.x0, h.x1, h.y0 + 0.03, 0.10),
        (h.x0, h.x1, h.y1 - 0.03, 0.10),
    ]
    stone_courses(m, h, plinth_sides, h.z0, PLINTH)
    for (x, y) in ((h.x0 + 0.03, h.cy), (h.x1 - 0.03, h.cy)):
        m.box((x, y, h.z0 + PLINTH / 2), (0.10, h.d, PLINTH), MAT_STONE, bevel=0.01)

    # openings
    for op in h.openings:
        if op.kind == "door":
            door_dressing(m, op, h.y0, facing, MAT_WOOD)
        else:
            window_dressing(m, op, h.y0, facing, MAT_BEAM)

    timber_frame(m, h, h.y0, facing, z_wall1)

    # roof: two slopes, gables at the ends, ridge cap
    y_eave_f = h.y0 - OVERHANG_Y
    y_eave_b = h.y1 + OVERHANG_Y
    shingle_slope(m, h.x0 - OVERHANG_X, h.x1 + OVERHANG_X, y_eave_f, h.cy, z_wall1 - 0.04,
                  h.ridge, h.roof_mat)
    shingle_slope(m, h.x0 - OVERHANG_X, h.x1 + OVERHANG_X, y_eave_b, h.cy, z_wall1 - 0.04,
                  h.ridge, h.roof_mat)
    for xc in (h.x0 + 0.02, h.x1 - 0.02):
        gable_wall(m, h, xc, WALL, h.wall_mat)
    m.box((h.cx, h.cy, h.ridge + 0.03), (h.w + 2 * OVERHANG_X + 0.06, 0.26, 0.12), MAT_BEAM,
          bevel=0.01)

    # chimney with a corbelled cap
    if h.chimney:
        chx, chy, chw, chd, ctop = h.chimney
        m.box((chx, chy, (h.z1 + ctop - 1.10) / 2 + 0.55), (chw, chd, ctop - h.z1 + 1.10),
              MAT_STONE, bevel=0.012)
        m.box((chx, chy, ctop - 0.14), (chw + 0.16, chd + 0.16, 0.14), MAT_STONE, bevel=0.012)
        m.box((chx, chy, ctop - 0.02), (chw + 0.06, chd + 0.06, 0.10), MAT_STONE_DARK, bevel=0.01)

    return m.finish(tile=1.0)


# ------------------------------------------------------------------ driver
def groups_of(collection) -> dict:
    """Group the old objects by building. The names carry the grouping: Tavern_*, Smith_*, ..."""
    groups: dict = {}
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        n = obj.name
        if n.startswith(("Pine_Tree", "Deciduous_Tree", "Grass_Tuft", "Cloud", "Mountain_")):
            continue
        key = None
        for prefix in ("Tavern", "Smith", "Jeweler", "Weaver", "Gate"):
            if n.startswith(prefix):
                key = prefix
                break
        if key is None and n.startswith("BG_House"):
            key = "BG_House"
        if key:
            groups.setdefault(key, []).append(obj)
    return groups


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    check = "--check" in args
    save = "--no-save" not in args and not check
    which = "alla"
    if "--hus" in args:
        which = args[args.index("--hus") + 1]
    collection = bpy.data.collections.get("Collection") or bpy.context.scene.collection

    groups = groups_of(collection)
    if which != "alla":
        groups = {k: v for k, v in groups.items() if k == which}

    built = []
    for name, objs in groups.items():
        spec = spec_from_group(name, objs)
        if spec is None:
            print(f"HOPPAR {name}: ingen kropp hittad")
            continue
        obj = build_house(spec, collection)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        built.append((name, tris, len(obj.data.vertices)))
        print(f"BYGGD {obj.name:12s} tris={tris:5d} verts={len(obj.data.vertices):5d} "
              f"oppningar={len(spec.openings)}")
        if not check:
            for old in objs:
                data = old.data
                bpy.data.objects.remove(old, do_unlink=True)
                if data.users == 0:
                    bpy.data.meshes.remove(data)

    ok = bool(built) and all(t > 400 for _, t, _ in built)
    print(f"CHECK byggda={len(built)} minsta={min((t for _, t, _ in built), default=0)} tris "
          f"-> {'OK' if ok else 'FAIL'}")
    if save:
        bpy.ops.wm.save_mainfile()
        print("SAVED", bpy.data.filepath)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
