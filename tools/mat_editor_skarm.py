"""Mäter karteditorns yta och textstorlek ur en renderad skärmbild (fönstret, 1280x720).

Kör:  python3 tools/mat_editor_skarm.py <bild> [...]   — en eller flera bilder jämförs sida vid sida.
"""
import statistics
import sys

from PIL import Image

BAK = (15, 15, 20)  # Color(0.06,0.06,0.08) i 8 bitar


def när(a, b, t=10):
    return abs(a[0] - b[0]) <= t and abs(a[1] - b[1]) <= t and abs(a[2] - b[2]) <= t


def mät(väg):
    im = Image.open(väg).convert("RGB")
    W, H = im.size
    px = im.load()
    innehåll = [[not när(px[x, y], BAK) for x in range(W)] for y in range(H)]
    rader = [sum(1 for v in r if v) for r in innehåll]
    kolumner = [sum(1 for y in range(H) if innehåll[y][x]) for x in range(W)]

    def kant(värden, riktning):
        träffar = [i for i, n in enumerate(värden) if n > 0]
        return (min(träffar), max(träffar)) if träffar else (-1, -1)

    x0, x1 = kant(kolumner, 1)
    y0, y1 = kant(rader, 1)
    # Glappet mellan ritytan och panelen är den LÄNGSTA obrutna tomma kolumnen: rutnätet är tätt, så
    # glappet är bredare än de tomma springorna inne i paneltexten.
    bästa = (0, 0); längd = 0; start = 0
    for x in range(x0, x1 + 2):
        if x <= x1 and kolumner[x] == 0:
            if längd == 0:
                start = x
            längd += 1
        else:
            if längd > bästa[1] - bästa[0]:
                bästa = (start, start + längd - 1)
            längd = 0
    raster = (x0, bästa[0] - 1) if bästa[1] > bästa[0] else (x0, x1)
    panel = (bästa[1] + 1, x1) if bästa[1] > bästa[0] else (x1 + 1, x1)

    # texthöjd: grupper av rader med innehåll i panelens spalt
    textrader = []
    if panel[1] > panel[0]:
        radernas = [y for y in range(H) if any(innehåll[y][x] for x in range(panel[0], panel[1] + 1))]
        if radernas:
            start = förra = radernas[0]
            for y in radernas[1:]:
                if y - förra > 1:
                    textrader.append(förra - start + 1)
                    start = y
                förra = y
            textrader.append(förra - start + 1)

    print("== %s  (%dx%d)" % (väg.rsplit("/", 1)[-1], W, H))
    print("  innehåll:          x %d..%d, y %d..%d = %dx%d px = %.1f %% av fönstret"
          % (x0, x1, y0, y1, x1 - x0 + 1, y1 - y0 + 1, 100.0 * (x1 - x0 + 1) * (y1 - y0 + 1) / (W * H)))
    print("  ritytan (rutnät):  x %d..%d  = %d px bred" % (raster[0], raster[1], raster[1] - raster[0] + 1))
    print("  panelen:           x %d..%d  = %d px bred%s"
          % (panel[0], panel[1], panel[1] - panel[0] + 1,
             "  <-- UTANFÖR fönstret!" if panel[1] >= W - 1 else ""))
    print("  ruta (cell):       %.1f px  (%d rutor på höjden = %d px)"
          % ((raster[1] - raster[0] + 1) / 17.0, 17, raster[1] - raster[0] + 1))
    if textrader:
        print("  paneltext:         %d rader, höjd median %g px, min %d, max %d"
              % (len(textrader), statistics.median(textrader), min(textrader), max(textrader)))
    print("  nedre kanten:      sista innehåll y=%d av %d %s"
          % (y1, H, "(klippt!)" if y1 >= H - 2 else ""))
    # överlapp: ritar panelen in i ritytan? (panelens x0 ska ligga höger om ritytans x1)
    print("  glapp rityta->panel: %d px" % (panel[0] - raster[1] - 1))


for väg in sys.argv[1:]:
    mät(väg)
