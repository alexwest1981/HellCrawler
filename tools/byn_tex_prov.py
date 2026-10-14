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

import json
import sys
from pathlib import Path

import bpy
import numpy as np

ROT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROT / "tools"))
import uv_byn as UV  # noqa: E402

GLB = ROT / "game" / "assets" / "by" / "byn.glb"
OMD = Path.home() / ".hermes" / "cache" / "scratch" / "omd"
TEXTURBILD = OMD / "byn_tex2.png"
TEXTURBILD_B = OMD / "byn_tex2_b.png"
NÄRBILD = OMD / "byn_tex2_nara.png"
LISTA = ROT / "tools" / "texturlistan_by.md"
## Mappningen ur objektens URSPRUNGLIGA material, skriven av apply_pixel_textures.py i samma session.
MAPPNING = ROT / "tools" / "byn_mappning.json"

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
    """Lägger skriptets klassning i tools/texturlistan_by.md (ersätter en tidigare sådan sektion).

    Klassningen läses ur objektens URSPRUNGLIGA material (tools/byn_mappning.json, skriven av
    apply_pixel_textures.py i samma session). Den gamla varianten klassade på objektets NAMN och det
    gick mätbart fel: namnen skiljer inte materialen — 745 objekt heter något med "tile" och där
    ligger både Roof_Slate_1/2 och Roof_Red_1/2, så skiffern blev tegel och 324 stenhus hamnade utan
    nyckelord.
    """
    MARK = "## Skriptets klassning: material -> platta"
    mapp = json.loads(MAPPNING.read_text())
    per_mat = mapp["objects_per_material"]
    till_platta = mapp["material_to_plate"]
    plattfil = mapp["plate_file"]
    omappade = mapp["unmapped"]

    rader = [MARK, "",
             "Alex' `tools/apply_pixel_textures.py` klassar varje objekt på dess **FÖRSTA material** "
             "(`obj.data.materials[0].name`) och ger det en av tjugoen plattor (elva ur Alex' paket i "
             "`game/assets/by/tex/` och tio ur atlasen i `game/assets/by/tex/atlas/`). "
             "Objektnamns-reglerna finns kvar, men bara som **fallback** för material som ännu inte har "
             "en platta. Siffrorna är mätta i scenen, inte skriptets avsikt.", "",
             "Namnklassningen som låg före den här mätningen gav 808 objekt Terracotta Roof, 0 Slate "
             "Roof och 324 stenhus utan nyckelordsträff — namnen skiljer helt enkelt inte materialen.", "",
             "### Objektets första material -> platta", "",
             "| Originalmaterial | Platta | Plattfil | Objekt |", "|---|---|---|---:|"]
    for platta in sorted(set(till_platta.values())):
        rader_ = sorted(((m, n) for m, n in per_mat.items() if till_platta.get(m) == platta),
                        key=lambda r: (-r[1], r[0]))
        for m, n in rader_:
            rader.append("| `%s` | %s | `%s` | %d |" % (m, platta, plattfil[platta], n))
        rader.append("| **%d material** | | | **%d** |" % (len(rader_), sum(n for _, n in rader_)))

    rader += ["", "### Material utan platta i paketet — underlaget för vilka plattor Alex behöver", "",
              "| Originalmaterial | Objekt | Nödlösning (namnregeln) |", "|---|---:|---|"]
    for m, d in sorted(omappade.items(), key=lambda kv: (-kv[1]["objects"], kv[0])):
        rader.append("| `%s` | %d | %s |" % (m, d["objects"], d["fallback"]))
    rader.append("| **%d material** | **%d** | |" %
                 (len(omappade), sum(d["objects"] for d in omappade.values())))

    rök = mapp["smoke_skipped"]
    rader += ["", "### Rök och moln — tas ur exporten, ersätts av en smoke emitter i Godot", "",
              "Alex' .blend rörs inte; exportskriptet kopplar loss objekten ur samlingen och lägger en "
              "`GPUParticles3D` på rökens uppmätta mitt i stället (`game/ui/by_3d.gd`). glTF bär inga "
              "partikelsystem, så en Blender-emitter hade inte överlevt exporten.", "",
              "| Objekt | Originalmaterial |", "|---|---|"]
    for n in sorted(rök):
        rader.append("| `%s` | `%s` |" % (n, rök[n]))
    rader += ["", "| Rökkluster | Objekt | Mitt, glTF (x, y, z) |", "|---|---:|---|"]
    for n, d in sorted(mapp["smoke_clusters"].items()):
        c = d["gltf"]
        rader.append("| %s | %d | %.2f, %.2f, %.2f |" % (n, d["objects"], c[0], c[1], c[2]))

    bg = mapp["background"]
    rader += ["", "### Bakgrunden (namn med `bg`) — tak, inte sten", "",
              "`BG_House_*` är små hus i bakgrunden; taken (`*_TileL`/`*_TileR`) och de krenelerade "
              "murarna får takplatta i stället för sten.", "",
              "| Bakgrundsobjekt | Antal |", "|---|---:|",
              "| på en takplatta (`roof_terracotta` / `roof_slate`) | %d |" % bg["tak"],
              "| kvar på stenplattan | %d |" % bg["sten"],
              "| totalt | %d |" % bg["antal"]]

    rader += ["", "### Vad klassningen blev i scenen (materialet i den exporterade filen)", "",
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


def ta_bort_röken():
    """Kopplar loss rök- och molnobjekten ur samlingarna: då är de borta ur BÅDE exporten och
    renderingen. Alex' .blend rörs inte — skriptet sparar aldrig filen — och listan kommer ur
    tools/byn_mappning.json (skriven av apply_pixel_textures.py i samma session).
    """
    mapp = json.loads(MAPPNING.read_text())
    bort = [n for n in mapp["smoke_skipped"] if n in bpy.data.objects]
    for n in bort:
        for c in list(bpy.data.objects[n].users_collection):
            c.objects.unlink(bpy.data.objects[n])
    return bort, mapp


def jämför_bilder(a: Path, b: Path, tröskel: int = 8) -> None:
    """Två renderingar av SAMMA scen, jämförda med TOLERANS i stället för md5.

    EEVEE jittrar sin sampling (TAA), så två renderingar av exakt samma scen är aldrig bit-identiska —
    det är mätt, inte antaget (se raden i utskriften). Medelavvikelsen per kanal och andelen pixlar
    som skiljer mer än `tröskel` steg skiljer jitter från en riktig bugg: jitter är några tiondels
    procent, en strukturell skillnad (fel textur, fel UV) är en hög andel.
    """
    ia = bpy.data.images.load(str(a))
    ib = bpy.data.images.load(str(b))
    fa = np.empty(len(ia.pixels), dtype=np.float32)
    ia.pixels.foreach_get(fa)
    fb = np.empty(len(ib.pixels), dtype=np.float32)
    ib.pixels.foreach_get(fb)
    if fa.shape != fb.shape:
        print("  FEL: bilderna har olika storlek (%d mot %d tal)" % (fa.size, fb.size))
        return
    # Blender levererar 0-1 i linjärt ljus; gånger 255 blir det kanalsteg att jämföra med tröskeln.
    d = np.abs(fa - fb)[: len(fa) // 4 * 4].reshape(-1, 4)[:, :3] * 255.0
    print("  %-18s mot %-18s medelavvikelse %.3f kanalsteg, %.4f %% av pixlarna skiljer mer än %d steg"
          % (a.name, b.name, float(d.mean()), 100.0 * float((d.max(axis=1) > tröskel).mean()), tröskel))


def main() -> int:
    scen = bpy.context.scene
    bort, mapp = ta_bort_röken()
    print("\n=== KONTROLL AV TEXTURPAKETET ===")
    if bort:
        print("rök/moln ur scenen (hoppas över i exporten): %d objekt" % len(bort))
    meshar = [o for o in scen.objects if o.type == "MESH"]
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
    print("%-18s %-7s %-11s %-11s %-11s %s" % ("MATERIAL", "YTOR", "MEDIAN m", "MIN m", "MAX m", "OMDÖME"))
    alla = []
    for namn2 in sorted(per_material, key=lambda n: -len(per_material[n])):
        v = np.array([x[0] for x in per_material[namn2]])
        alla += list(v)
        med_ = float(np.median(v))
        print("%-18s %-7d %-11.4f %-11.4f %-11.4f %s" %
              (namn2, len(v), med_, v.min(), v.max(),
               "ok" if MÅL[0] <= med_ <= MÅL[1] else ("för tätt" if med_ < MÅL[0] else "för utdraget")))

    print("\nper YTTYP (ytans normal — samma gruppering som den förra mätningen):")
    print("%-8s %-8s %-11s %-11s %-11s" % ("YTYP", "YTOR", "MEDIAN m", "MIN m", "MAX m"))
    for typ in ("vägg", "mark", "tak"):
        v = np.array(per_typ.get(typ, [0.0]))
        print("%-8s %-8d %-11.4f %-11.4f %-11.4f" % (typ, len(v), np.median(v), v.min(), v.max()))
    h = np.array(alla) if alla else np.array([0.0])
    print("SAMTLIGA ytor: median %.4f m, min %.4f, max %.4f" % (np.median(h), h.min(), h.max()))
    # GRINDEN: en ruta = 1,0 m överallt är hela poängen med kubprojektionen. Toleransen är 0,1 %:
    # UV-koordinaterna lagras som float32 (Blenders UV-lager), så själva avrundningen ger upp till
    # 0,05 % — mätt är största avvikelsen 0,0005 m (1,0005 m).
    avvik = max(abs(h.max() - 1.0), abs(h.min() - 1.0))
    print("största avvikelsen från 1,0000 m: %.4f m (%.3f %%)" % (avvik, 100.0 * avvik))
    if avvik > 0.001:
        print("FEL: rutan är inte 1,0000 m överallt (min %.4f, max %.4f)" % (h.min(), h.max()))

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

    print("\n=== (d2) SAMMA SCEN, TVÅ RENDERINGAR (jittret mätt, inte gissat) ===")
    UV.rendera(TEXTURBILD_B, UV.frontkamera())
    jämför_bilder(TEXTURBILD, TEXTURBILD_B)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
