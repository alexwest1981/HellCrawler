#!/usr/bin/env python3
"""Find every socket in the tree plate and write them out as data.

WHY A TOOL AND NOT EYEBALLING: the first attempt measured six rows and four columns out of the image
and put the game's nodes on that grid. Alex: "the red rings miss the sockets in many places, and many
sockets do not even have a ring". The sockets in the image are not on a grid - they sit where they
sit, so each one is measured.

SNAPPING (the mode that matters). A lattice over the image cannot hit sockets that do not sit on a
lattice - Alex: "the red rings miss the sockets in many places, and many sockets do not even have a
ring". So the tree's own arrangement is used only as a first guess, and every node is then SNAPPED to
the socket nearest to it: a local search for the point where (ring minus pit) is largest. The guess
may be off by centimetres; the snap lands in the pit.

METHOD. A socket is a dark pit ringed by brighter metal. For every point and every radius we take
(mean of the ring) - (mean of the pit); points where that difference is large are sockets. Both means
come from an integral image, which keeps the whole sweep at a few seconds instead of writing a Hough
transform.

The check lives in the same run: a picture with a circle on every find is written to /tmp, so the
finds can be looked at instead of believed.

    python3 tools/gen_tree_sockets.py --check                 # draw the check picture only
    python3 tools/gen_tree_sockets.py --snap nodes.txt        # snap every node to its socket
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
IMAGE = ROOT / "game/images/Gemini_Generated_Image_68qy7x68qy7x68qy.jpeg"
DATA = ROOT / "game/data/trad_sockets.json"
CHECK_PICTURE = pathlib.Path("/tmp/hc_skarm/sockets_check.png")
SNAP_PICTURE = pathlib.Path("/tmp/hc_skarm/snap_check.png")

## Radii swept, as a fraction of the image side. The image is square, so x and y share one scale.
RADII = [0.009, 0.013, 0.018, 0.025, 0.033, 0.043, 0.055, 0.070]
SIDE = 1024                      ## working side: half of 2048 is enough and four times faster
DARK_LIMIT = 0.40                ## a pit has to be darker than this, in 0..1 lightness
MIN_DISTANCE = 0.75              ## finds closer than this (times the diameter) are the same socket
SCAN_STEP = 2


def integral(a: np.ndarray) -> np.ndarray:
    return np.cumsum(np.cumsum(a, axis=0), axis=1)


def box_mean(I: np.ndarray, cy: int, cx: int, r: int, n: int) -> float:
    """Mean over a square around (cy, cx). Crude shape, cheap - and for a ring the error sits in the
    corners, which the ring's own edge eats."""
    y0, y1 = max(0, cy - r), min(n, cy + r + 1)
    x0, x1 = max(0, cx - r), min(n, cx + r + 1)
    if y1 <= y0 or x1 <= x0:
        return 0.0
    s = I[y1 - 1, x1 - 1]
    if y0 > 0:
        s -= I[y0 - 1, x1 - 1]
    if x0 > 0:
        s -= I[y1 - 1, x0 - 1]
    if y0 > 0 and x0 > 0:
        s += I[y0 - 1, x0 - 1]
    return float(s) / ((y1 - y0) * (x1 - x0))


def find_sockets(threshold: float) -> list[tuple[float, float, float]]:
    image = Image.open(IMAGE).convert("L").resize((SIDE, SIDE), Image.Resampling.LANCZOS)
    a = np.asarray(image).astype(np.float32) / 255.0
    I = integral(a)

    best = np.zeros((SIDE, SIDE), np.float32)
    best_radius = np.zeros((SIDE, SIDE), np.float32)
    pit_floor = 2                        ## smallest pit radius in pixels, against noise
    for radius in RADII:
        r = radius * SIDE
        if r < 5:
            continue
        r_out = int(r * 1.05)
        pit = max(pit_floor, int(r * 0.55))
        outer_area = float((2 * r_out + 1) ** 2)
        pit_area = float((2 * pit + 1) ** 2)
        for cy in range(r_out + 1, SIDE - r_out - 1, SCAN_STEP):
            for cx in range(r_out + 1, SIDE - r_out - 1, SCAN_STEP):
                outer_mean = box_mean(I, cy, cx, r_out, SIDE)
                pit_mean = box_mean(I, cy, cx, pit, SIDE)
                # Only the metal band: the outer square minus the pit, so we score the ring, not the pit.
                band = (outer_mean * outer_area - pit_mean * pit_area) / max(1.0, outer_area - pit_area)
                score = band - pit_mean
                if score > best[cy, cx]:
                    best[cy, cx] = score
                    best_radius[cy, cx] = radius

    candidates = []
    for cy in range(1, SIDE - 1):
        for cx in range(1, SIDE - 1):
            score = best[cy, cx]
            if score < threshold:
                continue
            if score < best[cy - 1:cy + 2, cx - 1:cx + 2].max() - 1e-6:
                continue
            if box_mean(I, cy, cx, 3, SIDE) > DARK_LIMIT:
                continue
            candidates.append((float(score), cy / SIDE, cx / SIDE, float(best_radius[cy, cx])))
    candidates.sort(reverse=True)

    chosen: list[tuple[float, float, float]] = []
    for _, y, x, radius in candidates:
        if any((x - vx) ** 2 + (y - vy) ** 2 < (MIN_DISTANCE * radius * 2) ** 2 for vx, vy, _ in chosen):
            continue
        chosen.append((x, y, radius))
    chosen.sort(key=lambda v: (round(v[1] / 0.02), v[0]))
    return chosen


def draw_check(finds: list[tuple[float, float, float]]) -> None:
    CHECK_PICTURE.parent.mkdir(parents=True, exist_ok=True)
    image = Image.open(IMAGE).convert("RGB").resize((SIDE, SIDE), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(image)
    for x, y, radius in finds:
        cx, cy, r = x * SIDE, y * SIDE, max(3.0, radius * SIDE)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(0, 255, 0), width=3)
        d.point([(cx, cy)], fill=(255, 0, 0))
    image.save(CHECK_PICTURE)


def snap(nodes_path: str) -> int:
    """Take the game's own node positions (name=x,y,size in view pixels) and snap each to the socket
    nearest to it. The view is 480x270 and the plate is square, drawn at the view height and centred,
    so the image fraction is (x - (view_width - view_height) / 2) / view_height in x and y / view_height
    in y. Written from the same measurement the game uses, so a change here changes the game."""
    import re
    text = pathlib.Path(nodes_path).read_text(encoding="utf-8")
    match = re.search(r"vyn \((\d+(?:\.\d+)?) x?\s*(\d+(?:\.\d+)?)\)", text.replace(",", " x"))
    if match:
        view_w, view_h = float(match.group(1)), float(match.group(2))
    else:
        numbers = re.search(r"vyn \(([\d.]+), ([\d.]+)\)", text)
        view_w, view_h = (float(numbers.group(1)), float(numbers.group(2))) if numbers else (480.0, 270.0)

    image = Image.open(IMAGE).convert("L").resize((SIDE, SIDE), Image.Resampling.LANCZOS)
    a = np.asarray(image).astype(np.float32) / 255.0
    I = integral(a)

    guesses = []
    for m in re.finditer(r"(\w+_?\d*)=([\d.]+),([\d.]+),(\d+)", text):
        name, px, py, size = m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4))
        fx = (px + size / 2 - (view_w - view_h) / 2) / view_h
        fy = (py + size / 2) / view_h
        guesses.append((name, fx, fy))

    sockets = []
    tagna = set()
    for name, fx, fy in guesses:
        best, best_x, best_y, best_r = -9.0, fx, fy, 0.02
        for radius in RADII:
            r = radius * SIDE
            if r < 5:
                continue
            r_out = int(r * 1.05)
            pit = max(2, int(r * 0.55))
            outer_area = float((2 * r_out + 1) ** 2)
            pit_area = float((2 * pit + 1) ** 2)
            cx0, cy0 = int(fx * SIDE), int(fy * SIDE)
            window = int(0.12 * SIDE)     # vidare fönster: plattans sockets sitter inte i gissningens rad
            for cy in range(max(r_out + 1, cy0 - window), min(SIDE - r_out - 1, cy0 + window), 2):
                for cx in range(max(r_out + 1, cx0 - window), min(SIDE - r_out - 1, cx0 + window), 2):
                    outer_mean = box_mean(I, cy, cx, r_out, SIDE)
                    pit_mean = box_mean(I, cy, cx, pit, SIDE)
                    band = (outer_mean * outer_area - pit_mean * pit_area) / max(1.0, outer_area - pit_area)
                    score = band - pit_mean
                    if score > best:
                        # Ta bara en ledig socket: två noder i samma grop syns som en klump.
                        nyckel = (round(cx / SIDE, 2), round(cy / SIDE, 2))
                        if nyckel in tagna:
                            continue
                        best, best_x, best_y, best_r = score, cx / SIDE, cy / SIDE, radius
        tagna.add((round(best_x, 2), round(best_y, 2)))
        sockets.append({"id": name, "x": round(best_x, 4), "y": round(best_y, 4), "r": round(best_r, 4),
                        "score": round(best, 3), "guess_x": round(fx, 4), "guess_y": round(fy, 4)})

    weak = [s for s in sockets if s["score"] < 0.10]
    moved = [s for s in sockets if abs(s["x"] - s["guess_x"]) + abs(s["y"] - s["guess_y"]) > 0.004]
    print("snapped: %d nodes, %d moved from the guess, %d with a weak pit (< 0.10)" % (
        len(sockets), len(moved), len(weak)))
    for s in weak:
        print("  weak: %s score %.3f" % (s["id"], s["score"]))

    check = Image.open(IMAGE).convert("RGB").resize((SIDE, SIDE), Image.Resampling.LANCZOS)
    d = ImageDraw.Draw(check)
    for s in sockets:
        cx, cy = s["x"] * SIDE, s["y"] * SIDE
        r = max(6.0, s["r"] * SIDE * 0.55)
        färg = (0, 255, 0) if s["score"] >= 0.10 else (255, 140, 0)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=färg, width=3)
        d.line([(s["guess_x"] * SIDE, s["guess_y"] * SIDE), (cx, cy)], fill=(255, 60, 60), width=2)
    check.save(SNAP_PICTURE)
    print("check picture: %s" % SNAP_PICTURE)

    DATA.write_text(json.dumps({
        "image": "res://images/Gemini_Generated_Image_68qy7x68qy7x68qy.jpeg",
        "side": SIDE,
        "method": "each node snapped to the socket nearest to its lattice guess; see tools/gen_tree_sockets.py",
        "sockets": sockets,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("written: %s" % DATA)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="draw the check picture only")
    parser.add_argument("--snap", metavar="NODES",
                        help="file with the game's node positions; snap each to its socket")
    parser.add_argument("--threshold", type=float,
                        default=float(os.environ.get("SOCKET_THRESHOLD", "0.075")),
                        help="how much brighter the ring must be than the pit")
    args = parser.parse_args()

    if args.snap:
        return snap(args.snap)

    finds = find_sockets(args.threshold)
    print("sockets found: %d (threshold %.3f)" % (len(finds), args.threshold))
    draw_check(finds)
    print("check picture: %s" % CHECK_PICTURE)

    if args.check:
        return 0
    DATA.write_text(json.dumps({
        "image": "res://images/Gemini_Generated_Image_68qy7x68qy7x68qy.jpeg",
        "side": SIDE,
        "method": "ring minus pit; see tools/gen_tree_sockets.py",
        "sockets": [{"x": round(x, 4), "y": round(y, 4), "r": round(r, 4)} for x, y, r in finds],
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("written: %s" % DATA)
    return 0


if __name__ == "__main__":
    sys.exit(main())
