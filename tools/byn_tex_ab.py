"""A/B: byn MED texturer mot en KONTROLLRENDERING av samma scen UTAN texturer.

    /home/alex/.local/bin/blender -b /home/alex/Downloads/Untitled.blend --python tools/byn_tex_ab.py

Kontrollen är Alex' scen som den är (platta färger, inga bilder) renderad med EXAKT samma kamera och
samma renderinställningar som texturrenderingen — samma funktioner ur tools/uv_byn.py, så kameran
kan inte glida isär mellan de två bilderna. Skriptet körs därför EFTER texturrenderingen, för det
läser byn_tex2.png.

MÅTTET: Laplace-energi per frekvensband (3 nivåer av en Laplacian-pyramid på gråskalebilden).
Band 1 är finast och fångar själva texturpixlarna. En texturerad bild har mer energi i de finare
banden än samma bild med platta färger; är texturerna osynliga (ingen bild i materialet, fel UV,
fel skala) blir kvoten ~1.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
import numpy as np

ROT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROT / "tools"))
import uv_byn as UV  # noqa: E402

OMD = Path.home() / ".hermes" / "cache" / "scratch" / "omd"
TEXTUR = OMD / "byn_tex2.png"
KONTROLL = OMD / "byn_tex2_utan.png"
BAND = 3


def gråbild(path: Path) -> np.ndarray:
    """Bildens ljushet 0-255 som float-array (PNG:en räknas i sRGB-värden, inte Blenders linjära)."""
    img = bpy.data.images.load(str(path))
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    return buf.reshape(h, w, 4)[::-1, :, :3].mean(axis=2) * 255.0


def bandar(g: np.ndarray, n: int = BAND):
    """Laplacian-pyramid: band 1 = finast (högsta frekvensen), band n = grövst."""
    g = g[: g.shape[0] // 2 * 2, : g.shape[1] // 2 * 2]
    ut = []
    x = g
    for _ in range(n):
        d = (x[0::2, 0::2] + x[1::2, 0::2] + x[0::2, 1::2] + x[1::2, 1::2]) * 0.25
        u = np.repeat(np.repeat(d, 2, 0), 2, 1)
        ut.append(x - u)
        x = d
    return ut


def main() -> int:
    print("\n=== (e) A/B: texturerad mot kontroll UTAN texturer (samma kamera) ===")
    UV.rendera(KONTROLL, UV.frontkamera())
    a, b = gråbild(TEXTUR), gråbild(KONTROLL)
    if a.shape != b.shape:
        print("FEL: bilderna har olika storlek %s mot %s" % (a.shape, b.shape))
        return 1
    print("%-6s %-16s %-16s %s" % ("BAND", "TEXTURERAD", "KONTROLL", "KVOT"))
    for i, (x, y) in enumerate(zip(bandar(a), bandar(b)), 1):
        ex, ey = float(np.abs(x).mean()), float(np.abs(y).mean())
        print("%-6d %-16.4f %-16.4f %.2fx%s" %
              (i, ex, ey, ex / max(ey, 1e-9), "  (finast)" if i == 1 else ""))
    print("bilderna: %s (%dx%d) mot %s (%dx%d)" %
          (TEXTUR.name, a.shape[1], a.shape[0], KONTROLL.name, b.shape[1], b.shape[0]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
