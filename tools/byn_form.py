"""FORMGRANSKNING: ligger en takplatta på något som står LÅGT (en mur), eller en murplatta på
något som ligger som ett TAK? Granskar byn.glb objekt för objekt.

Kittens tak är byggda av kuber, så orienteringen på en enstaka yta säger inte mycket (en kub har
fyra vertikala sidor). I stället mäts objektets HÖJD över marken och dess fotavtryck: en takplatta
hör hemma högt uppe på en byggnad, en murplatta lågt och brett.

    python3 tools/byn_form.py            # tabell
    python3 tools/byn_form.py --lista    # + namnen
"""
import json
import struct
import sys
import collections

GLB = "game/assets/by/byn.glb"
TAK = ("Roof",)
MUR = ("PX_Stone", "PX_Wood", "PX_Tudor Plaster", "PX_Iron Riveted", "PX_Dark Stone", "PX_Hedge",
       "PX_Cobblestone Brown", "PX_Cobblestone Grey", "PX_Cobblestone Mossy", "PX_Stone Mossy")


def läs_glb(sökväg):
    d = open(sökväg, "rb").read()
    off = 12
    js = None
    bin_data = None
    while off < len(d):
        ln, ty = struct.unpack_from("<II", d, off)
        off += 8
        if ty == 0x4E4F534A:
            js = json.loads(d[off:off + ln])
        elif ty == 0x004E4942:
            bin_data = d[off:off + ln]
        off += ln
    return js, bin_data


def nod_matris(nod):
    """(translation, rotation, skala) ur glTF-noden, så att objektets ruta hamnar i världen."""
    t = nod.get("translation", [0.0, 0.0, 0.0])
    r = nod.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = nod.get("scale", [1.0, 1.0, 1.0])
    if "matrix" in nod:
        m = nod["matrix"]
        # kolumnvis (glTF är kolumn-major): translation = m[12..14]
        t = [m[12], m[13], m[14]]
        # skala = längden på axlarna (rotationen bortses från; kuben är symmetrisk nog)
        s = [abs(m[0] ** 2 + m[1] ** 2 + m[2] ** 2) ** 0.5,
             abs(m[4] ** 2 + m[5] ** 2 + m[6] ** 2) ** 0.5,
             abs(m[8] ** 2 + m[9] ** 2 + m[10] ** 2) ** 0.5]
    return t, r, s


def rotera(p, q):
    x, y, z = p
    qx, qy, qz, qw = q
    ux, uy, uz = qx, qy, qz
    s = qw
    return [
        (1 - 2 * (uy * uy + uz * uz)) * x + 2 * (ux * uy - uz * s) * y + 2 * (ux * uz + uy * s) * z,
        2 * (ux * uy + uz * s) * x + (1 - 2 * (ux * ux + uz * uz)) * y + 2 * (uy * uz - ux * s) * z,
        2 * (ux * uz - uy * s) * x + 2 * (uy * uz + ux * s) * y + (1 - 2 * (ux * ux + uy * uy)) * z,
    ]


def main():
    js, _ = läs_glb(GLB)
    matnamn = [m.get("name", "?") for m in js["materials"]]
    rader = []
    for nod in js["nodes"]:
        if "mesh" not in nod:
            continue
        mesh = js["meshes"][nod["mesh"]]
        namn = nod.get("name", "?")
        t, r, s = nod_matris(nod)
        for prim in mesh["primitives"]:
            mi = prim.get("material")
            material = matnamn[mi] if mi is not None else "(inget)"
            a = js["accessors"][prim["attributes"]["POSITION"]]
            if "min" not in a:
                continue
            mn, mx = a["min"], a["max"]
            # rutan i objektets eget rum, skalad och flyttad (rotationen är oftast 0 i kiten)
            hörn = [[mn[0], mn[1], mn[2]], [mx[0], mn[1], mn[2]], [mn[0], mx[1], mn[2]],
                    [mx[0], mx[1], mn[2]], [mn[0], mn[1], mx[2]], [mx[0], mn[1], mx[2]],
                    [mn[0], mx[1], mx[2]], [mx[0], mx[1], mx[2]]]
            v = []
            for h in hörn:
                p = [h[i] * s[i] for i in range(3)]
                p = rotera(p, r)
                v.append([p[i] + t[i] for i in range(3)])
            lo = [min(p[i] for p in v) for i in range(3)]
            hi = [max(p[i] for p in v) for i in range(3)]
            rader.append({"namn": namn, "material": material, "lo": lo, "hi": hi,
                          "d": [hi[i] - lo[i] for i in range(3)]})

    print("FORMGRANSKNING AV BYN.GLB (" + str(len(rader)) + " objekt)")
    # 1. TAKPLATTA LÅGT: en takplatta på ett objekt vars överkant ligger under takfoten.
    låga_tak = [r for r in rader if r["material"] in TAK and r["hi"][1] < 2.0]
    print()
    print("1. TAKPLATTA LÅGT (överkant under 2,0 m = en mur eller ett golv, inte ett tak): "
          + str(len(låga_tak)) + " objekt")
    c = collections.Counter(r["namn"] for r in låga_tak)
    for m, n in c.most_common(10):
        print("     " + m.ljust(34) + str(n))
    # 2. MURPLATTA SOM LIGGER SOM ETT TAK: bred och platt, uppe på en byggnad.
    platta_högt = [r for r in rader if r["material"] in MUR and r["hi"][1] > 3.0
                   and r["d"][1] < 0.35 * max(r["d"][0], r["d"][2])]
    print()
    print("2. MURPLATTA SOM ETT TAK (platt och bred, över 3 m, under 35 % av bredden tjock): "
          + str(len(platta_högt)) + " objekt")
    c2 = collections.Counter(r["namn"] for r in platta_högt)
    for m, n in c2.most_common(10):
        print("     " + m.ljust(34) + str(n) + "   " + str([[round(x, 1) for x in rader[0]["d"]]]))
    # 3. MATERIAL PER NAMNFAMILJ: vilket material har objekten med mur-/taknamn?
    print()
    print("3. MATERIAL PER NAMN (mur- och takord):")
    for ord_ in ("wall", "crenel", "castle", "tower", "merlon", "gate", "tile", "roof", "gable",
                 "spire", "thatch"):
        cc = collections.Counter(r["material"] for r in rader if ord_ in r["namn"].lower())
        if cc:
            print("     " + ord_.ljust(12) + str(dict(cc)))
    if "--lista" in sys.argv:
        print()
        print("NAMNEN (takplatta lågt):")
        for r in låga_tak[:40]:
            print("   " + r["namn"].ljust(34) + r["material"].ljust(20)
                  + "y %.2f..%.2f  d %s" % (r["lo"][1], r["hi"][1], [round(x, 2) for x in r["d"]]))


if __name__ == "__main__":
    main()
