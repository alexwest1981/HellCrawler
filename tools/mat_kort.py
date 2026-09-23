"""Mäter kortets pixeldata i en skärmbild: rutans kant, konstens pixelstorlek och kantövergångar.

Kör:  python3 tools/mat_kort.py <bild> [x0 y0 x1 y1]
"""
import sys
from collections import Counter

from PIL import Image

bild = Image.open(sys.argv[1]).convert("RGB")
x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6]) if len(sys.argv) >= 6 else (300, 120, 740, 640)
kort = bild.crop((x0, y0, x1, y1))
W, H = kort.size
px = kort.load()
print("utsnitt: %dx%d px (från %d,%d)" % (W, H, x0, y0))

# Bakgrunden i kortvalet är spelvyn bakom (mörk). Kortet = det område som avviker från sin egen kant.
bak = px[0, 0]
print("bakgrundsfärg: %s" % (bak,))


def olik(p, q, t=24):
    return abs(p[0] - q[0]) > t or abs(p[1] - q[1]) > t or abs(p[2] - q[2]) > t


# Kortets rektangel: rader/kolumner där merparten av pixlarna avviker från bakgrunden.
rader = [sum(1 for x in range(W) if olik(px[x, y], bak)) for y in range(H)]
kolumner = [sum(1 for x in range(W) if olik(px[x, y], bak)) for y in range(H)]
vänster = next((x for x in range(W) if kolumner[x] > H * 0.4), None)
höger = next((x for x in range(W - 1, -1, -1) if kolumner[x] > H * 0.4), None)
topp = next((y for y in range(H) if rader[y] > W * 0.3), None)
botten = next((y for y in range(H - 1, -1, -1) if rader[y] > W * 0.3), None)
print("kortets rektangel i utsnittet: x %s..%s, y %s..%s" % (vänster, höger, topp, botten))
if None not in (vänster, höger, topp, botten):
    print("  = %dx%d px på skärmen (kortkonsten är %s)" % (höger - vänster + 1, botten - topp + 1,
          "208x288 (baksidan)"))

# Kantövergång: hur många mellanfärger ligger mellan bakgrunden och kortets kant?
if None not in (vänster, topp, botten):
    mitt = (topp + botten) // 2
    rad = [px[x, mitt] for x in range(max(0, vänster - 6), vänster + 6)]
    print("pixlar över vänsterkanten (y=%d):" % mitt)
    print("  " + " ".join("%02x%02x%02x" % p for p in rad))
    unika = len({p for p in rad})
    print("  %d unika färger i 12 px över kanten — få = skarp kant, många = utfluten" % unika)

# Konstens pixelstorlek: längsta körningar av exakt samma färg inne i kortets konst.
if None not in (vänster, höger, topp, botten):
    inre = kort.crop((vänster + 6, topp + 6, höger - 6, botten - 6))
    iw, ih = inre.size
    ip = inre.load()
    körningar = []
    for y in range(0, ih, 7):
        x = 0
        while x < iw:
            p = ip[x, y]
            n = 1
            while x + n < iw and ip[x + n, y] == p:
                n += 1
            if n > 1:
                körningar.append(n)
            x += n
    if körningar:
        c = Counter(körningar)
        vanligast = c.most_common(4)
        print("konstens pixelbredd (vanligaste körningarna av en färg): %s" % vanligast)
    print("unika färger i konsten: %d" % len({ip[x, y] for y in range(0, ih, 3) for x in range(0, iw, 3)}))
