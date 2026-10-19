#!/usr/bin/env python3
"""Overview and safety tools for a .blend I am about to touch.

Three things, in one file because they are always used together:

    who()       -> which Blender answered: pid, background mode, open file, counts
    snapshot()  -> copy the open file to jobb/snapshots/ BEFORE a batch of writes
    overview()  -> four views of the scene in ONE 2560x1440 sheet

Runs headless against a file, or inside a live instance through the MCP bridge:

    blender -b scene.blend --python jobb/blender_tools.py -- --overview
    exec(open("/path/to/jobb/blender_tools.py").read()); result = who()

Why the resolution: a 1280x720 pane per view, stacked to 2560x1440. The village is ~40 m wide, so
the camera pane lands around 30 px per metre - enough to see a stretched texture or a blown-out
wall, which is what an overview is for. Smaller panes hide exactly those defects.

The scene is left as found: render settings and the temporary cameras are restored, and nothing is
saved into the file.
"""
import os
import shutil
import subprocess
import sys
import time

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
IMAGES = os.path.join(HERE, "bilder")
SNAPSHOTS = os.path.join(HERE, "snapshots")

# Pane size per view. 2x2 of these is the sheet, and every pane is ALSO kept on disk so a detail can be
# judged at full size (a 55 m village at 1920 px is ~35 px/m). Measured cost: ~2 s per pane.
PANE_W, PANE_H = 1920, 1080


def _visible_meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.visible_get()]


def who():
    """Identity of the instance that answered - the first thing to know before writing anything."""
    return {
        "pid": os.getpid(),
        "background": bpy.app.background,
        "filepath": bpy.data.filepath or "(unsaved)",
        "objects": len(bpy.data.objects),
        "meshes": len(bpy.data.meshes),
        "materials": len(bpy.data.materials),
        "images": len(bpy.data.images),
        "engine": bpy.context.scene.render.engine,
        "camera": bpy.context.scene.camera.name if bpy.context.scene.camera else None,
    }


def snapshot(label="auto"):
    """Copy the open file into jobb/snapshots/. Returns the path, or None when nothing is saved yet.

    Takes a copy of the file on disk, not a save of the live session: a batch that segfaults must not
    be able to leave the snapshot half-written.
    """
    src = bpy.data.filepath
    if not src:
        return None
    os.makedirs(SNAPSHOTS, exist_ok=True)
    stem = os.path.splitext(os.path.basename(src))[0]
    dst = os.path.join(SNAPSHOTS, f"{time.strftime('%Y-%m-%d_%H%M')}_{stem}_{label}.blend")
    shutil.copy2(src, dst)
    return dst


def _bbox():
    lo = Vector((1e18, 1e18, 1e18))
    hi = Vector((-1e18, -1e18, -1e18))
    for obj in _visible_meshes():
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    if lo.x > hi.x:
        return None
    return lo, hi


def _temp_camera(name, location, rotation, ortho_scale=None):
    cam_data = bpy.data.cameras.new(name)
    if ortho_scale:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho_scale
    else:
        cam_data.lens = 50
    cam_data.clip_start = 0.05
    cam_data.clip_end = max(1000.0, (ortho_scale or 10) * 20)
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = rotation
    bpy.context.view_layer.update()
    return cam


def _stack(pngs, out):
    """2x2 stack with view labels. ffmpeg, because it copies pixels instead of re-encoding them."""
    ffmpeg = shutil.which("ffmpeg") or "/home/alex/.hermes/tools/ffmpeg-9.0.1-linux-x64/bin/ffmpeg"
    font = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
    labels = ["CAMERA", "FRONT", "SIDE", "TOP"]
    chain = "[0:v][1:v]hstack[t];[2:v][3:v]hstack[b];[t][b]vstack"
    if os.path.exists(font):
        # label each pane, because an unlabelled sheet makes the reader guess which view is which
        chain = ""
        for i, text in enumerate(labels):
            chain += (f"[{i}:v]drawtext=fontfile={font}:text='{text}':x=16:y=16:fontsize=44:"
                      f"fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=10[v{i}];")
        chain += "[v0][v1]hstack[t];[v2][v3]hstack[b];[t][b]vstack"
    cmd = [ffmpeg, "-y", "-loglevel", "error"]
    for p in pngs:
        cmd += ["-i", p]
    cmd += ["-filter_complex", chain, out]
    subprocess.run(cmd, check=True)
    return out


def overview(out=None, engine=None):
    """Render camera / front / side / top into one sheet. Returns a dict with the path and the numbers."""
    scene = bpy.context.scene
    os.makedirs(IMAGES, exist_ok=True)
    stamp = time.strftime("%Y-%m-%d_%H%M")
    stem = os.path.splitext(os.path.basename(bpy.data.filepath))[0] or "osparad"
    out = out or os.path.join(IMAGES, f"{stamp}_{stem}_oversikt.png")

    keep = {
        "engine": scene.render.engine,
        "x": scene.render.resolution_x,
        "y": scene.render.resolution_y,
        "pct": scene.render.resolution_percentage,
        "filepath": scene.render.filepath,
        "camera": scene.camera,
        "film_transparent": scene.render.film_transparent,
    }

    wanted = engine or keep["engine"]
    for name in (wanted, "BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = name
            break
        except TypeError:
            continue
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = 32

    scene.render.resolution_x, scene.render.resolution_y = PANE_W, PANE_H
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False

    box = _bbox()
    temps = []
    pngs = []
    try:
        # 1: the owner's own camera, untouched - this is the viewpoint they judge the scene from
        if scene.camera:
            pngs.append(_render(scene, os.path.join(IMAGES, f"{stamp}_{stem}_1kamera.png")))
        else:
            pngs.append(_blank(os.path.join(IMAGES, f"{stamp}_{stem}_1kamera.png")))

        if box:
            lo, hi = box
            centre = (lo + hi) / 2
            size = hi - lo
            span = max(size.x, size.y, size.z)
            dist = span * 3 + 5
            # ortho_scale spans the LARGER frame dimension (width here), so a view whose vertical
            # extent is bigger than scale/1.78 gets cropped - fit both axes instead of one.
            aspect = PANE_W / PANE_H

            def scale_for(u, v):
                return max(u, v * aspect) * 1.05

            # front: Blender's own front view, from -Y looking +Y
            temps.append(_temp_camera("_ov_front", centre + Vector((0, -dist, 0)),
                                      (1.5708, 0, 0), ortho_scale=scale_for(size.x, size.z)))
            pngs.append(_render(scene, os.path.join(IMAGES, f"{stamp}_{stem}_2front.png"), temps[-1]))
            # side: from +X looking -X
            temps.append(_temp_camera("_ov_side", centre + Vector((dist, 0, 0)),
                                      (1.5708, 0, 1.5708), ortho_scale=scale_for(size.y, size.z)))
            pngs.append(_render(scene, os.path.join(IMAGES, f"{stamp}_{stem}_3sida.png"), temps[-1]))
            # top: from +Z looking down
            temps.append(_temp_camera("_ov_top", centre + Vector((0, 0, dist)),
                                      (0, 0, 0), ortho_scale=scale_for(size.x, size.y)))
            pngs.append(_render(scene, os.path.join(IMAGES, f"{stamp}_{stem}_4topp.png"), temps[-1]))
        while len(pngs) < 4:
            pngs.append(_blank(os.path.join(IMAGES, f"_pane_blank{len(pngs)}.png")))

        _stack(pngs, out)
    finally:
        for cam in temps:
            data = cam.data
            bpy.data.objects.remove(cam, do_unlink=True)
            bpy.data.cameras.remove(data)
        scene.camera = keep["camera"]
        scene.render.engine = keep["engine"]
        scene.render.resolution_x, scene.render.resolution_y = keep["x"], keep["y"]
        scene.render.resolution_percentage = keep["pct"]
        scene.render.filepath = keep["filepath"]
        scene.render.film_transparent = keep["film_transparent"]


    return {
        "sheet": out,
        "bytes": os.path.getsize(out),
        "pane": f"{PANE_W}x{PANE_H}",
        "sheet_size": f"{PANE_W * 2}x{PANE_H * 2}",
        "views": ["camera", "front", "side", "top"],
        "objects_visible": len(_visible_meshes()),
        "bbox": [list(box[0]), list(box[1])] if box else None,
        "identity": who(),
    }


def _render(scene, path, camera=None):
    prev = scene.camera
    if camera:
        scene.camera = camera
        bpy.context.view_layer.update()
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    scene.camera = prev
    return path


def _blank(path):
    """A missing view must still occupy its pane, or a 3-pane sheet silently reads as 4."""
    import numpy as np
    img = bpy.data.images.new("_ov_blank", PANE_W, PANE_H, alpha=False)
    img.pixels.foreach_set(np.full(PANE_W * PANE_H * 4, 0.05, dtype=np.float32))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = args[0] if args else "--overview"
    if mode == "--who":
        result = who()
    elif mode == "--snapshot":
        result = {"snapshot": snapshot(args[1] if len(args) > 1 else "cli")}
    else:
        target = args[1] if len(args) > 1 else None
        result = overview(target)
    print("RESULT " + repr(result))
