"""KONTROLL AV TEXTURPAKETET: mäter vad Alex' skript gjorde, exporterar och renderar.

    blender -b /home/alex/Downloads/Untitled.blend \
        --python tools/apply_pixel_textures.py \
        --python tools/byn_tex_prov.py

Två --python i SAMMA Blender-session, i den ordningen: Alex' skript bygger material, UV och packar
bilderna, och det här skriptet mäter resultatet och skriver filerna medan sessionen lever. Att köra
dem i två körningar hade tappat allt Alex' skript gjorde — det sparar inte .blend-filen.

VARFÖR ETT KONTROLLSKRIPT: paketets skript har ingen egen kontroll (mätt: det skriver bara ut hur
många objekt varje kategori fick). Det säger ingenting om UV-lagren blev ett per objekt, om
texturerna kom med i glb:n, eller om kakelstorleken blev rimlig — och just de tre sakerna avgör om
byn går att se på. Skriptet rör INTE material, UV eller geometri; det läser och skriver ut.

TALET SOM SPELAR ROLL: meter per texturupprepning. En platta är 512 px; täcker den en halv meter
ligger den tätt, täcker den sex meter är den utdragen. Målet är 0,5-1,0 m. Det mäts per MATERIAL
(Alex' skript döper dem PX_Stone, PX_Grass ...) och per YTTYP (sida/mark/tak via ytans normal), för
att båda grupperingarna ska gå att jämföra med den förra mätningen.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
import numpy as np

ROT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROT / "tools"))
import uv_byn as UV  # noqa: E402

GLB = ROT / "game" / "assets" / "by" / "byn.glb"
OMD = Path.home() / ".hermes" / "cache" / "scratch" / "omd"
TEXTURBILD = OMD / "byn_tex.png"
NÄRBILD = OMD / "byn_tex_nara.png"
LISTA = ROT / "tools" / "texturlistan_by.md"

## Målet: en platta ska täcka 0,5-1,0 m på väggen (samma täthet som projektets egna plattor:
## 512 px per meter i tools/gen_tiles_alex.py).
MÅL = (0.5, 1.0)


def uv_status(meshar):
    """Hur många mesh-objekt som har ett UV-lager, och vad lagren heter."""
    namn = {}
    utan = []
    flera = 0
    for o in meshar:
        lager = [u.name for u in o.data.uv_layers]
        if not lager:
            utan.append(o.name)
        if len(lager) > 1:
            flera += 1
        for n in lager:
            namn[n] = namn.get(n, 0) + 1
    return namn, utan, flera


def materialbilder():
    """Material -> bildfil + hur många objekt och ytor som använder det."""
    ut = {}
    for m in bpy.data.materials:
        bild = None
        if m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    bild = n.image
                    break
        ut[m.name] = {"bild": bild, "objekt": 0, "ytor": 0, "area": 0.0}
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        me = o.data
        mw = o.matrix_world
        w = [mw @ v.co for v in me.vertices]
        sedda = set()
        for poly in me.polygons:
            if poly.material_index >= len(o.material_slots):
                continue
            m = o.material_slots[poly.material_index].material
            if m is None or m.name not in ut:
                continue
            ut[m.name]["ytor"] += 1
            ut[m.name]["area"] += UV.ytarea(me, poly, w)
            sedda.add(m.name)
        for n in sedda:
            ut[n]["objekt"] += 1
    return ut


def mät_per_material(meshar):
    """Meter per texturupprepning, per material OCH per yttyp (ytans normal).

    Formeln är densamma som i tools/uv_byn.py: sqrt(världens area / UV-arean). Den fungerar på vilket
    UV-lager som helst — även Smart UV Projects, som packar varje objekt för sig.
    """
    per_material = {}
    per_typ = {}
    for obj in meshar:
        me = obj.data
        if not me.uv_layers:
            continue
        mw = obj.matrix_world
        nm = mw.to_3x3().inverted_safe().transposed()
        w = [mw @ v.co for v in me.vertices]
        buf = np.empty(len(me.loops) * 2, dtype=np.float32)
        me.uv_layers[0].data.foreach_get("uv", buf)
        uv = list(zip(buf[0::2], buf[1::2]))
        for poly in me.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            m = obj.material_slots[poly.material_index].material
            if m is None:
                continue
            a = UV.ytarea(me, poly, w)
            b = UV.uvarea(uv, poly)
            if a <= 0.0 or b <= 0.0:
                continue
            n = (nm @ poly.normal).normalized()
            if abs(n.z) >= 0.7:
                typ = "mark" if n.z > 0 else "tak"
            else:
                typ = "vägg"
            m_ = (a / b) ** 0.5
            per_material.setdefault(m.name, []).append((m_, obj.name))
            per_typ.setdefault(typ, []).append(m_)
    return per_material, per_typ


def skriv_mappning(ut) -> None:
    """Lägger skriptets klassning i tools/texturlistan_by.md (ersätter en tidigare sådan sektion)."""
    MARK = "## Skriptets klassning: material -> platta"
    rader = [MARK, "",
             "Alex' `tools/apply_pixel_textures.py` klassar varje objekt på NAMN och ger det en av "
             "elva plattor ur paketet (`game/assets/by/tex/`). Det här är vad klassningen blev i "
             "scenen, räknat ur materialen, inte ur skriptets avsikt.", "",
             "| Material | Plattfil | Objekt | Ytor | Area m² |", "|---|---|---:|---:|---:|"]
    for namn in sorted(ut):
        d = ut[namn]
        bild = Path(d["bild"].filepath).name if d["bild"] else "**ingen bild**"
        rader.append("| `%s` | `%s` | %d | %d | %.1f |" %
                     (namn, bild, d["objekt"], d["ytor"], d["area"]))
    rader += ["", "Objekt utan platta alls (materialet saknar bildtextur) räknas inte i tabellen "
                  "ovan; alla %d material i filen står med." % len(ut)]

    gammal = LISTA.read_text() if LISTA.exists() else ""
    if MARK in gammal:
        gammal = gammal[:gammal.index(MARK)].rstrip() + "\n"
    LISTA.write_text(gammal.rstrip() + "\n\n" + "\n".join(rader) + "\n")
    print("skrev mappningen i %s" % LISTA.relative_to(ROT))


def main() -> int:
    scen = bpy.context.scene
    meshar = [o for o in scen.objects if o.type == "MESH"]
    print("\n=== KONTROLL AV TEXTURPAKETET ===")
    print("objekt %d, mesh %d, material %d, bilder %d" %
          (len(scen.objects), len(meshar), len(bpy.data.materials), len(bpy.data.images)))

    namn, utan, flera = uv_status(meshar)
    print("\n=== (a) UV-LAGER ===")
    print("mesh-objekt MED UV-lager: %d av %d" % (len(meshar) - len(utan), len(meshar)))
    for n, antal in sorted(namn.items()):
        print("  lagret %-18s på %d objekt" % (n, antal))
    print("objekt med FLERA UV-lager: %d" % flera)
    if utan:
        print("  UTAN UV (%d): %s" % (len(utan), ", ".join(utan[:12])))

    ut = materialbilder()
    print("\n=== (b) MATERIAL OCH BILDTEXTURER ===")
    med = sum(1 for d in ut.values() if d["bild"])
    print("material med en bildtextur i sig: %d av %d" % (med, len(ut)))
    if med == 0:
        print("  INGEN bild i något material — texturerna kom inte in i sessionen")
    skriv_mappning(ut)

    per_material, per_typ = mät_per_material(meshar)
    print("\n=== (c) KAKELSTORLEK: meter per texturupprepning (mål %.1f-%.1f m) ===" % MÅL)
    print("%-18s %-7s %-9s %-9s %-9s %s" % ("MATERIAL", "YTOR", "MEDIAN m", "MIN m", "MAX m", "OMDÖME"))
    alla = []
    for namn2 in sorted(per_material, key=lambda n: -len(per_material[n])):
        v = np.array([x[0] for x in per_material[namn2]])
        alla += list(v)
        med_ = float(np.median(v))
        print("%-18s %-7d %-9.2f %-9.2f %-9.2f %s" %
              (namn2, len(v), med_, v.min(), v.max(),
               "ok" if MÅL[0] <= med_ <= MÅL[1] else ("för tätt" if med_ < MÅL[0] else "för utdraget")))

    print("\nper YTTYP (ytans normal — samma gruppering som den förra mätningen):")
    print("%-8s %-8s %-9s %-9s %-10s" % ("YTYP", "YTOR", "MEDIAN m", "MIN m", "MAX m"))
    for typ in ("vägg", "mark", "tak"):
        v = np.array(per_typ.get(typ, [0.0]))
        print("%-8s %-8d %-9.2f %-9.2f %-9.2f" % (typ, len(v), np.median(v), v.min(), v.max()))
    h = np.array(alla) if alla else np.array([0.0])
    print("SAMTLIGA ytor: median %.2f m, spridning %.1f-%.1f m (kvot max/median %.1f)" %
          (np.median(h), h.min(), h.max(), h.max() / max(np.median(h), 1e-6)))

    UV.exportera(GLB)
    print("\n=== GLB: %s, %d byte ===" % (GLB.relative_to(ROT), GLB.stat().st_size))

    print("\n=== (d) RENDERINGAR ===")
    UV.rendera(TEXTURBILD, UV.frontkamera())
    # Närmbilden: vilket material som helst duger när materialen heter PX_* — ytan väljs ur geometrin.
    kam, info = UV.närkamera(meshar, ())
    if kam is None:
        print("  ingen framåtvänd vägg hittades — närmbilden uteblir")
    else:
        print("  närbild: %s" % info)
        UV.rendera(NÄRBILD, kam)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
