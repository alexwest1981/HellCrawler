"""UV-MAPPNING AV BYN: varje mesh får ett riktigt UV-lager, rutorna lika stora i meter.

    /home/alex/.local/bin/blender -b /home/alex/Downloads/Untitled.blend --python tools/uv_byn.py
    ... -- --kolla            # mät bara: töjningen per yttyp, ingenting skrivs
    ... -- --lista            # skriv om texturlistan tools/texturlistan_by.md
    ... -- --platta 1.0       # annan rutstorlek i meter
    ... -- --rendera          # rendera rutmönstret (beviset)

LISTAN (`--lista`) pekar varje material i scenen på en platta i game/assets/by/tex/ — de som är
utklippta ur Alex' atlas av tools/gen_tex_atlas.py — och märker ut vilka plattor som är DEKORER
(fönster, dörr, valv) och därför bara får ligga på en enda yta. Plattornas beskrivning och
fogmätning läses ur tex/_plattor.json, så listan kan inte säga något annat än plattan gör.

KÖRS OM NÄR NYA TEXTURER KOMMER. Skriptet bakar UV mot scenens NUVARANDE geometri; kommer fler
hus till kör man det igen och får nya UV för de nya objekten. Det rör bara UV-lagret — material,
färger och kameror lämnas ifred. LJUSEN är undantaget: de delas med LJUS_DELARE innan filen skrivs
(se kommentaren vid konstanten), eftersom glTF bär dem med och Godot läser Blenders enheter rakt av.

MÄTT I UTGÅNGSLÄGET (2026-10-14): 1950 objekt, 1931 mesh, 37 292 trianglar, 50 material,
**0 av 1931 mesh-objekt hade ett UV-lager och filen innehöll inga bildtexturer alls**. Allt var
platta färger i Principled BSDF. Utan UV-lager kan ingen textur alls läggas på byn: en bildtextur
i Blender KAN mappas med noder (Generated/Object/Box) och ser rätt ut i vyn, men de noderna följer
INTE med till glTF — den vägen exporterar bara UV-koordinater + bild. UV-mappningen måste alltså
BAKAS IN i meshen som ett riktigt UV-lager, en gång, och det är det här skriptet gör.

RUTAN I METER. En platta (en texturruta) ska täcka SAMMA antal meter överallt, annars ligger
texturen tätt på en mursten och utsträckt över en hel vägg. Talet är projektets eget, inte påhittat:
tools/gen_tiles_alex.py mätte fram 512 px/m som spelets täthet och skriver sina plattor i 256 px —
alltså 0,5 m per ruta. Samma 256 px-rutor ligger redan i game/assets/tiles/.

KUBPROJEKTION, PER YTA. Varje yta projiceras på sitt EGET plan (normalen) med världskoordinater
delade med rutstorleken. Det ger tre saker på en gång:
  * exakt skala överallt, även på ett snedtak (en projektion på en DOMINANT axel hade sträckt
    sneda ytor med 1/cos(vinkeln) — mätt i kontrollen nedan),
  * samma rutnät i världen för alla SAMPLANAR ytor, eftersom basen byggs ur världsaxlarna och bara
    beror på normalen — två grannlådor på samma vägg delar rutnät, och skarven mellan dem syns inte,
  * ett helt antal rutor per yta utan att någon yta behöver sin egen skala.

BEVISET: --rendera lägger ett schackrutor-mönster (2x2 rutor per platta = 0,25 m per schackruta,
med en röd ram längs plattans kant) i varje materials basfärg och renderar byn från spelets egen
frontvy OCH en närbild på en vägg. Är mappningen rätt är schackrutorna lika stora på väggar, mark
och tak; är den fel syns det som olikformiga rutor. Renderingen muterar materialen i minnet och
SPARAS ALDRIG — exporten har redan skett vid det laget.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROT = Path(__file__).resolve().parent.parent
GLB = ROT / "game" / "assets" / "by" / "byn.glb"
TEX = ROT / "game" / "assets" / "by" / "tex" / "atlas"
TEX_REL = "game/assets/by/tex/atlas"
LISTA = ROT / "tools" / "texturlistan_by.md"
OMD = Path.home() / ".hermes" / "cache" / "scratch" / "omd"
BEVISFIL = OMD / "byn_uv_checker.png"
NÄRFIL = OMD / "byn_uv_checker_nara.png"

## LJUSEN: BLENDERS ENHETER -> GODOTS. Alex' ljus i .blend-filen är lux / candela och ligger tre
## storleksordningar över Godots `light_energy` (MÄTT: med talen orörda blir 52 % av spelets bild ren
## vit och byn en vit klump). Omräkningen bakas in HÄR, i själva exporten, och inte i spelets kod:
## `game/ui/by_3d.gd` delade varje ljus med 2000 varje gång scenen byggdes — men den raden kör bara när
## SPELET kör. I Godot-editorn (och för varje annan läsare av filen) stod ljusen kvar på Blenders värden
## och `game/scenes/by.tscn` visades HELT VIT, trots att hela poängen med scenen är att Alex ska kunna
## redigera den. Filen bär därför Godots enheter; ingen läsare behöver räkna om något.
##
## FAKTORN 2000 är exakt den koden använde (`LJUS_DELARE` i by_3d.gd), uniformt på alla ljus — de
## halverades en gång tidigare (1 000 -> 2 000) efter mätningen som visade att det var PUNKTLJUSEN och
## inte solen som brände stenfasaderna. Ändra den bara med en ny mätning av spelets egen rendering.
LJUS_DELARE = 2000.0


def dämpa_ljus(delare: float = LJUS_DELARE) -> list:
    """Delar varje ljus i scenen med `delare`. Returnerar [(ljus, ursprunglig energi)] .

    Anropas av `exportera` — den ENDA vägen till en .glb härifrån — så att ingen export kan hoppa över
    omräkningen och skicka ut Blenders enheter till Godot igen. Anroparen MÅSTE lägga tillbaka
    energierna efter exporten (`återställ_ljus`), annars ritar bevisrenderingarna byn i Godots enheter
    och blir nästan svarta.
    """
    ut = []
    for o in bpy.context.scene.objects:
        if o.type != "LIGHT":
            continue
        ut.append((o, o.data.energy))
        o.data.energy /= delare
    return ut


def återställ_ljus(sparade: list) -> None:
    """Lägger tillbaka Alex' egna ljusenergier efter exporten (se `dämpa_ljus`)."""
    for o, energi in sparade:
        o.data.energy = energi

UV_NAMN = "UVMap"
## Rutans kant i px. MÄTT: projektets egna plattor är 256x256 (super-rutorna 512), och
## tools/gen_tiles_alex.py mätte 512 px/m som spelets täthet — 256 px täcker alltså 0,5 m.
PLATTA_PX = 256
PLATTA_M = 0.5
UPP = (1280, 720)
## Spelets EGEN vinkel: 2.5D-konsten är ritad rakt framifrån (samma tal som tools/byn3d.py).
FRONTKAMERA = ((0.5, -22.0, 3.6), 1.5009831190109253, 34.0)

AXLAR = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
## Vilka två världsaxlar en yta med dominant axel i får sina UV-axlar ur.
AXELPAR = {0: (1, 2), 1: (0, 2), 2: (0, 1)}

## Palettens färger till bevisets schackruta (game/assets/palette.json index 1, 8 och 10).
SCHACK_MÖRK = (12, 10, 16)
SCHACK_LJUS = (226, 220, 208)
SCHACK_RAM = (168, 48, 40)


# ---------------------------------------------------------------- mätning

def yttyp(material: str) -> str:
    """Vilken sorts yta materialet är: vägg, mark, tak eller annat.

    Klassningen är en NAMNGISSNING på materialet (scenen har bara platta färger — ingen geometri
    säger vad som är ett tak), och den redovisas i utskriften så att siffrorna går att kontrollera.
    """
    if material.startswith("Roof_"):
        return "tak"
    if material.startswith(("Cobble_", "Road_", "Grass_", "Dirt_")):
        return "mark"
    if material.startswith(("Stone_", "Plaster_")):
        return "vägg"
    return "annat"


def ytarea(me, poly, w) -> float:
    """Ytans area i VÄRLDEN, räknad ur hörnens världskoordinater.

    `polygon.area` är i objektets LOKALA mått, och alla 1931 objekt har skala != 1 (mätt), så den
    siffran hade varit fel för varje objekt. Arean räknas därför med kryssprodukterna runt ytans
    hörn — samma formel oavsett hur många hörn ytan har.
    """
    s = Vector((0.0, 0.0, 0.0))
    i0 = poly.loop_start
    a = w[me.loops[i0].vertex_index]
    for k in range(1, poly.loop_total - 1):
        b = w[me.loops[i0 + k].vertex_index]
        c = w[me.loops[i0 + k + 1].vertex_index]
        s += (b - a).cross(c - a)
    return 0.5 * s.length


def uvarea(uv, poly) -> float:
    """Ytans area i UV-rymden (samma formel, rutor i stället för meter)."""
    s = 0.0
    i0 = poly.loop_start
    ax, ay = uv[i0]
    for k in range(1, poly.loop_total - 1):
        bx, by = uv[i0 + k]
        cx, cy = uv[i0 + k + 1]
        s += (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    return abs(0.5 * s)


def dom_uvarea(me, poly, w, n: Vector) -> float:
    """Samma area, men med DEN ENKLA varianten: projektion på den dominanta axeln.

    Den räknas bara för att mäta vad valet av bas är värt: på ett snedtak sträcker den varianten
    mönstret med 1/cos(vinkeln), och det talet står i kontrollen.
    """
    axel = max(range(3), key=lambda i: abs(n[i]))
    s = Vector((0.0, 0.0, 0.0))
    i0 = poly.loop_start
    p0 = w[me.loops[i0].vertex_index]
    for k in range(1, poly.loop_total - 1):
        p1 = w[me.loops[i0 + k].vertex_index]
        p2 = w[me.loops[i0 + k + 1].vertex_index]
        s += (p1 - p0).cross(p2 - p0)
    # Arean av den projicerade ytan = arean av dess skugga i planet, räknad med samma kryssprodukt
    # men bara den dominanta axelns komponent kvar.
    return abs(s[axel]) * 0.5


# ---------------------------------------------------------------- UV

def bas(n: Vector):
    """Ortonormal bas i ytans plan, byggd ur världsaxlarna så att samplanar ytor delar rutnät."""
    axel = max(range(3), key=lambda i: abs(n[i]))
    if abs(n[axel]) > 0.999:
        i, j = AXELPAR[axel]
        u, v = AXLAR[i].copy(), AXLAR[j].copy()
        # Baksidan speglas, annars läses en text (en skylt) bakvänt där. Samplanar ytor har samma
        # normaltecken, så rutnätet mellan två grannlådor är opåverkat av den här raden.
        if n[axel] < 0:
            u = -u
        return u, v
    # Sned yta (takfall): bas i ytans eget plan. Då blir skalan exakt även där, i stället för att
    # en projektion på dominant axel sträcker mönstret med 1/cos(vinkeln).
    w = AXLAR[min(range(3), key=lambda i: abs(n[i]))]
    u = (w - n * w.dot(n)).normalized()
    return u, n.cross(u)


def sätt_uv(obj, platta: float):
    """Bakar in ett UV-lager på objektet. Returnerar (antal ytor, antal hörn)."""
    me = obj.data
    if me.uv_layers:
        while len(me.uv_layers) > 1:
            me.uv_layers.remove(me.uv_layers[-1])
        lager = me.uv_layers[0]
        lager.name = UV_NAMN
    else:
        lager = me.uv_layers.new(name=UV_NAMN)
    me.uv_layers.active = lager
    lager.active_render = True

    mw = obj.matrix_world
    nm = mw.to_3x3().inverted_safe().transposed()
    w = [mw @ v.co for v in me.vertices]
    uv = [(0.0, 0.0)] * len(me.loops)
    for poly in me.polygons:
        u, v = bas((nm @ poly.normal).normalized())
        for l in range(poly.loop_start, poly.loop_start + poly.loop_total):
            p = w[me.loops[l].vertex_index]
            uv[l] = (p.dot(u) / platta, p.dot(v) / platta)
    lager.data.foreach_set("uv", [k for par in uv for k in par])
    me.update()
    return len(me.polygons), len(me.loops)


def mät_alla(meshar, platta: float) -> dict:
    """Töjningen per yttyp: hur många meter en platta täcker, med min/max och spridning."""
    typ = {}
    for obj in meshar:
        me = obj.data
        mw = obj.matrix_world
        nm = mw.to_3x3().inverted_safe().transposed()
        w = [mw @ v.co for v in me.vertices]
        uv = [(0.0, 0.0)] * len(me.loops)
        lager = me.uv_layers[0]
        buf = np.empty(len(me.loops) * 2, dtype=np.float32)
        lager.data.foreach_get("uv", buf)
        uv = list(zip(buf[0::2], buf[1::2]))
        for poly in me.polygons:
            namn = "<tom>"
            if poly.material_index < len(obj.material_slots):
                m = obj.material_slots[poly.material_index].material
                namn = m.name if m else "<tom>"
            a = ytarea(me, poly, w)
            b = uvarea(uv, poly)
            if a <= 0.0 or b <= 0.0:
                continue
            n = (nm @ poly.normal).normalized()
            d = typ.setdefault(yttyp(namn), {"ytor": 0, "area": 0.0, "m": [], "dom": []})
            d["ytor"] += 1
            d["area"] += a
            # meter per platta = sqrt(världens area / UV-arean). Är mappningen rätt är den = plattan.
            d["m"].append(math.sqrt(a / b))
            # Samma tal med den enkla projektionen (dominant axel), för att mäta vad basen är värd:
            # den projicerade arean är UV-arean * plattan^2, så meter per platta blir plattan*sqrt(a/dom).
            dom = dom_uvarea(me, poly, w, n)
            if dom > 0.0:
                d["dom"].append(platta * math.sqrt(a / dom))
    return typ


# ---------------------------------------------------------------- export och rendering

def exportera(glb: Path):
    glb.parent.mkdir(parents=True, exist_ok=True)
    # LJUSEN FÖRST (se LJUS_DELARE): filen ska bära Godots enheter, så att spelet, editorn och varje
    # annat program som öppnar den ser SAMMA by. Utskriften är kontrollen — står Blenders tal kvar här
    # har någon kopplat ur omräkningen.
    ljus = dämpa_ljus()
    print("LJUS: %d ljus delade med %.0f (Blender -> Godot): %s" %
          (len(ljus), LJUS_DELARE, ", ".join("%s %.4f" % (o.name, o.data.energy) for o, _ in sorted(ljus, key=lambda p: p[0].name))))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format="GLB", export_yup=True,
                              export_apply=True, export_extras=True, export_lights=True)
    # TILLBAKA: allt som ritas EFTER exporten (bevisbilderna i tools/byn_tex_prov.py) ska visa byn med
    # ALEX' ljus, inte med Godots enheter. Utan raden blir de renderingarna nästan svarta.
    återställ_ljus(ljus)


def schackruta(px: int = 128):
    """Bevisets mönster: 2x2 schackrutor per platta (0,25 m) och en röd ram längs plattans kant."""
    img = bpy.data.images.new("uv_schack", px, px, alpha=False)
    a = np.zeros((px, px, 4), dtype=np.float32)
    h = px // 2
    mörk = np.array([c / 255.0 for c in SCHACK_MÖRK] + [1.0], dtype=np.float32)
    ljus = np.array([c / 255.0 for c in SCHACK_LJUS] + [1.0], dtype=np.float32)
    a[:h, :h] = mörk
    a[h:, h:] = mörk
    a[:h, h:] = ljus
    a[h:, :h] = ljus
    ram = np.array([c / 255.0 for c in SCHACK_RAM] + [1.0], dtype=np.float32)
    for k in range(2):
        a[k, :] = ram
        a[-1 - k, :] = ram
        a[:, k] = ram
        a[:, -1 - k] = ram
    img.pixels.foreach_set(a.reshape(-1))
    img.pack()
    return img


def sätt_schack_material():
    """Lägger schackrutan i varje materials basfärg. Lyser/metaller mutas: beviset gäller UV:n."""
    img = schackruta()
    n = 0
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        m.node_tree.nodes.clear()
        ut = m.node_tree.nodes.new("ShaderNodeOutputMaterial")
        bsdf = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        tex.extension = "REPEAT"
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.node_tree.links.new(bsdf.outputs["BSDF"], ut.inputs["Surface"])
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Emission Strength"].default_value = 0.0
        n += 1
    return n


def rendera(path: Path, kamera):
    """Renderar med scenens EGNA ljus (Alex tände den), men med Standard-vylook: AgX-filmen
    tvättar ut schackrutornas kontrast, och det är kontrasten som är beviset."""
    scen = bpy.context.scene
    scen.camera = kamera
    scen.render.engine = "BLENDER_EEVEE"
    scen.render.resolution_x, scen.render.resolution_y = UPP
    scen.render.resolution_percentage = 100
    scen.render.image_settings.file_format = "PNG"
    try:
        scen.view_settings.view_transform = "Standard"
        scen.view_settings.look = "None"
    except (AttributeError, TypeError):
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    scen.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    # Ljusheten mäts: en svart bild ser ut som ett lyckat prov om ingen tittar på den.
    r = bpy.data.images.load(str(path))
    p = np.empty(len(r.pixels), dtype=np.float32)
    r.pixels.foreach_get(p)
    print("  %-28s %dx%d  medel-ljushet %.3f" % (path.name, r.size[0], r.size[1], p[0::4].mean()))


def frontkamera():
    (plats, rot, skala) = FRONTKAMERA
    kam = bpy.data.cameras.new("uv_front")
    kam.type = "ORTHO"
    kam.ortho_scale = skala
    o = bpy.data.objects.new("uv_front", kam)
    bpy.context.scene.collection.objects.link(o)
    o.location = plats
    o.rotation_euler = (rot, 0.0, 0.0)
    return o


def närkamera(meshar, ordning=("Plaster_", "Wood_", "Stone_")):
    """Närmast möjliga: en FRAMÅTVÄND fasadyta, ramad så att en platta syns i detalj.

    Ytan väljs ur geometrin, inte ur en gissad position. Två misstag är redan mätta bort:
    att ta den STÖRSTA ytan gav en 26 m lång slottsmur (39 px/m — 10 px per schackruta), och att ta
    den främsta gav en 17 x 0,18 m trottoarkant. Ytan ska därför vara en FASAD (minst 1,5 m på båda
    ledder), helst putsad (Plaster_*), och den ramas in till högst RUTA_RAM meter.

    `ordning` är materialnamnen i tur och ordning. Tom tupel = vilket material som helst, vilket
    behövs när materialen inte heter något man kan känna igen (Alex' texturpaket döper dem till
    PX_Stone, PX_Grass ... och då finns ingen puts att leta efter).
    """
    RUTA_RAM = 3.5
    MÅTT_MIN = 1.5
    bäst = None
    for obj in meshar:
        me = obj.data
        mw = obj.matrix_world
        nm = mw.to_3x3().inverted_safe().transposed()
        w = [mw @ v.co for v in me.vertices]
        for poly in me.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            m = obj.material_slots[poly.material_index].material
            if not m:
                continue
            if ordning:
                prio = next((i for i, p in enumerate(ordning) if m.name.startswith(p)), None)
                if prio is None:
                    continue
            else:
                prio = 0
            n = (nm @ poly.normal).normalized()
            if n.y > -0.99:
                continue
            hörn = [w[me.loops[l].vertex_index] for l in range(poly.loop_start,
                                                              poly.loop_start + poly.loop_total)]
            xs = [p.x for p in hörn]
            zs = [p.z for p in hörn]
            bredd, höjd = max(xs) - min(xs), max(zs) - min(zs)
            if bredd < MÅTT_MIN or höjd < MÅTT_MIN:
                continue
            nyckel = (prio, min(p.y for p in hörn), -ytarea(me, poly, w))
            if bäst is None or nyckel < bäst[0]:
                bäst = (nyckel, obj.name, m.name, hörn, bredd, höjd)
    if bäst is None:
        return None, None
    _, namn, mat, hörn, bredd, höjd = bäst
    xs = [p.x for p in hörn]
    zs = [p.z for p in hörn]
    ys = [p.y for p in hörn]
    skala = min(max(bredd, höjd) * 1.15, RUTA_RAM)
    kam = bpy.data.cameras.new("uv_nara")
    kam.type = "ORTHO"
    kam.ortho_scale = skala
    o = bpy.data.objects.new("uv_nara", kam)
    bpy.context.scene.collection.objects.link(o)
    o.location = ((min(xs) + max(xs)) / 2.0, min(ys) - 1.0, (min(zs) + max(zs)) / 2.0)
    o.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    info = "%s (%s): ytan %.2f x %.2f m, ram %.1f m, %.0f bildpixlar per meter" % (
        namn, mat, bredd, höjd, skala, UPP[0] / skala)
    return o, info


# ---------------------------------------------------------------- texturlistan

## MAPPEN: material -> den platta ur Alex' atlas som ska kaklas på det.
##
## Plattorna ligger i game/assets/by/tex/ och är utklippta ur hans eget ark av tools/gen_tex_atlas.py;
## beskrivningen och fogsiffrorna nedan läses ur tex/_plattor.json som det skriptet skriver — alltså
## EN sanning för vad en platta föreställer, inte två som kan glida ifrån varandra.
##
## Färgen: materialets basfärg MULTIPLICERAS med plattan. Därför pekar flera material på SAMMA platta
## (Stone_Light/Stone_Wall/Stone_Dark är samma mursten i tre toner, Grass_* samma gräs, Roof_*_1 och
## _2 samma pannor) — materialets egen ton gör jobbet, precis som i scenen i dag.
## DEN GAMLA VÄGEN. Mappningen som gäller i dag ligger i `tools/apply_pixel_textures.py`
## (`MATERIAL_TO_PLATE` + `trädplatta` + `TEXTURES`); den här tabellen används bara av det här
## skriptets egen texturering, som är överspelad. Plattfilerna nedan är ändå de som gäller.
MAPP: dict[str, str] = {
    "Stone_Light":  "stone_wall_light.png",     # ljus huggsten, 320 m²
    "Stone_Wall":   "stone_wall_dark.png",      # muren, 895 m² — mörkare, basfärgen tonar
    "Stone_Dark":   "stone_wall_dark.png",      # sockel och hörn, samma platta, mörkare ton
    "Roof_Red_1":   "roof_tiles_red.png",
    "Roof_Red_2":   "roof_tiles_red.png",
    "Roof_Slate_1": "roof_slate.png",
    "Roof_Slate_2": "roof_slate.png",
    "Roof_Purple_1": "roof_slate.png",          # ingen purpurplatta finns: skiffern får basfärgen
    "Roof_Purple_2": "roof_slate.png",
    "Wood_Beam":    "wood_planks.png",
    "Wood_Dark":    "wood_planks.png",
    "Wood_Oak":     "wood_planks.png",
    "Wood_Light":   "wood_planks_small.png",
    "Road_Base":    "sand_path.png",            # packad stig med grus
    "Cobble_1":     "cobblestone_grey.png",
    "Cobble_2":     "cobblestone_grey.png",
    "Cobble_3":     "cobblestone_brown.png",
    "Grass_Dark":   "grass.png",
    "Grass_Mid":    "grass.png",
    "Grass_Light":  "grass.png",
    "Dirt_Cliff":   "dirt_stony.png",
    "Mountain_Rock": "stone_mossy.png",         # närmaste sten; egentlig bergplatta saknas
    "Iron":         "metal_riveted.png",
    "Gold":         "metal_riveted.png",        # metallic 0,9 i materialet; plattan ger hamringen
    "Leaf_Mid":     "ivy.png",
    "Leaf_Dark":    "ivy.png",
    "Leaf_Light":   "ivy.png",
}

## DEKORER: plattor som visar ett MOTIV och därför bara får ligga på EN yta, aldrig upprepas.
## (fil, var i byn, vilket material i scenen)
DEKOR = {
    "window_four_pane.png":      ("fyrdelat fönster, varmt ljus", "husens fönster", "Window_Warm"),
    "window_arched_stone.png":   ("valvfönster i sten", "fönster i stenhus", "Window_Warm"),
    "window_round_stone.png":    ("runt fönster med kors", "torn och juveleraren", "Window_Warm"),
    "window_tall_panes.png":     ("högt spröjsat fönster", "höga fasader, lyktor", "Window_Bright"),
    "window_diamond_lattice.png": ("diamantgaller", "förråd och källare", "Window_Bright"),
    "window_narrow.png":         ("smalt fönster", "vindar och trapphus", "Window_Bright"),
    "door_wood_iron.png":        ("trädörr med järnband", "husens dörrar", "Wood_Dark/Wood_Oak"),
    "stone_arch.png":            ("stenvalv", "portar och öppningar", "Stone_Dark"),
    "castle_merlons.png":        ("krenelerad borgmur", "borgmuren bakom husen (BG_Castle_Wall)",
                                  "Stone_Light"),
    "forge_stone_glow.png":      ("glödande smidessten", "ässjan hos smeden", "Fire_Core"),
}

## SAKNAS: materialen som atlasen inte har någon platta för, med det närmaste den har.
SAKNAS = {
    "Plaster_Cream": ("puts, slät gräddvit yta", "wall_plaster_cream.png",
                      "Atlasen har ingen slät puts. `timber_frame.png` är korsvirke MED puts mellan "
                      "bjälkarna — den passar om hela fasaden ska bli korsvirkesvägg, men inte som "
                      "slät putsyta. 334 m² står otextrade utan den."),
    "Plaster_Warm":  ("puts, varm sandton", "wall_plaster_warm.png", ""),
    "Roof_Thatch":   ("vasstak, vassrör i lager", "roof_thatch.png",
                      "Inget vasstak i atlasen. 14,6 m² — låg prioritet."),
    "Pine_Green":    ("barr, täta barr i grenar", "pine_needles.png",
                      "Atlasen har löv (ivy.png), ingen barrskog. Närmast i dag: ivy.png."),
    "Cloth_Blue":    ("tyg, blekt av sol och regn", "cloth.png",
                      "Ingen tygplatta i atlasen. Fem material, 1-6 m² var (vimplar, skyltdukar)."),
    "Cloth_Cyan":    ("", "", ""),
    "Cloth_Green":   ("", "", ""),
    "Cloth_Purple":  ("", "", ""),
    "Cloth_Red":     ("", "", ""),
    "Sign_Text":     ("skyltens yta", "sign_text.png",
                      "Ingen skyltplatta. `wood_planks_small.png` duger som tom skyltbräda; texten "
                      "målas i så fall in i plattan, och OBS: spegelvändningen (se bas() i "
                      "tools/uv_byn.py) gör att en text blir bakvänd på baksidan av en skylt."),
    "Sheep_Wool":    ("ull, lockig yta", "wool.png",
                      "Ingen ullplatta. 10 m² — platt färg syns nästan lika bra."),
}

## Material som INTE ska ha någon platta, med skälet. Siffrorna i tabellen är MÄTTA ur scenen.
TEXTLÖSA = {
    "Bulb_Glow":    "41 glödlampor på 2 688 ytor: varje lampa är några centimeter. Lyser (emission 12) "
                    "och läses som LJUS, inte som yta — en platta syns inte.",
    "Fire_Core":    "lågans kärna, emission 18. Lyser.",
    "Fire_Orange":  "lågans kant, emission 10. Lyser.",
    "Gem_Cyan":     "EN yta, några decimeter. Lyser (emission 8): plattan är större än juvelen.",
    "Gem_Green":    "EN yta. Lyser (emission 7).",
    "Gem_Pink":     "EN yta. Lyser (emission 7).",
    "Skin":         "ansikten och händer på 10 figurer. En textur här kräver att UV:n sys per figur "
                    "(ögon, mun, näsa på rätt plats) — kubprojektion lägger ögat på kinden. "
                    "Platt färg ser bättre ut.",
    "Horse_Brown":  "hästen. För liten yta för att en platta ska synas; platt färg räcker.",
    "Cloud_White":  "himmelsplattor: molnen ska vara MJUKA och enfärgade, en platta gör dem prickiga. "
                    "Ligger dessutom bakom allt annat.",
    "Smoke_Grey":   "rök, mjukade partiklar. Samma skäl som molnen.",
}


def sv(tal: float, dec: int = 1) -> str:
    """Tal med komma, som i den svenska texten runtomkring (0,5 m — inte 0.5 m)."""
    return ("%%.%df" % dec % tal).replace(".", ",")


def skriv_lista(meshar) -> None:
    """Texturlistan: varje material -> plattan den ska ha, med plattans egen fogmätning.

    Plattornas beskrivning och fogsiffror läses ur tex/_plattor.json (skriven av
    tools/gen_tex_atlas.py). Står en platta i MAPP men inte i json:en är den inte utklippt, och det
    skrivs ut som ett fel — listan får inte peka på en fil som inte finns.
    """
    från = {}
    for obj in meshar:
        me = obj.data
        mw = obj.matrix_world
        w = [mw @ v.co for v in me.vertices]
        for poly in me.polygons:
            if poly.material_index >= len(obj.material_slots):
                continue
            m = obj.material_slots[poly.material_index].material
            if not m:
                continue
            d = från.setdefault(m.name, {"ytor": 0, "area": 0.0})
            d["ytor"] += 1
            d["area"] += ytarea(me, poly, w)

    plattor = {}
    if (TEX / "_plattor.json").exists():
        for p in json.loads((TEX / "_plattor.json").read_text()):
            plattor[p["fil"]] = p
    else:
        print("VARNING: %s saknas — kör tools/gen_tex_atlas.py först" % (TEX / "_plattor.json"))

    rader = ["# Texturlistan: varje material i byn och plattan det ska ha", "",
             "Plattorna är utklippta ur Alex' atlas av `tools/gen_tex_atlas.py` och ligger i "
             "`%s/`. **%d x %d px = %s m i världen**: en platta täcker %s x %s m, "
             "och UV-lagret (`tools/uv_byn.py`) ligger redan på alla %d mesh-objekt — en textur som "
             "läggs i materialets basfärg hamnar rätt utan vidare arbete." %
             (TEX_REL, PLATTA_PX, PLATTA_PX, sv(PLATTA_M), sv(PLATTA_M), sv(PLATTA_M), len(meshar)), "",
             "**Fogen** är fogens skillnad delad med plattans EGNA brus i samma ledd. Under 3,0 är "
             "skarven inte grövre än rutans eget brus och syns inte när plattan upprepas; över det "
             "blir den en linje. `—` = ingen mätning (dekorer kaklas inte).", "",
             "## Kaklas: material -> platta", "",
             "| Material | Yta i scenen | Plattfil | Sort | Fog sid | Fog höjd | Mått |",
             "|---|---:|---|---|---:|---:|---|"]

    problem = []
    använda = set()
    for namn in sorted(från):
        d = från[namn]
        fil = MAPP.get(namn)
        if not fil:
            continue
        använda.add(fil)
        p = plattor.get(fil)
        if not p:
            problem.append("%s -> %s (plattan finns inte i tex/)" % (namn, fil))
            continue
        varning = "" if p["sömlös_sid"] else " **FOG ÖPPEN**"
        rader.append("| `%s` | %.1f m² / %d ytor | `%s` | %s | %.2f (x%s) | %.1f (x%s) | %dx%d |" %
                     (namn, d["area"], d["ytor"], fil, p["sort"], p["fog_sid"], sv(p["kvot_sid"]),
                      p["fog_höjd"], sv(p["kvot_höjd"]), p["källa_px"][0], p["källa_px"][1]))
        if varning:
            rader[-1] = rader[-1][:-1] + varning + " |"

    rader += ["", "## Dekorer: läggs på EN yta, upprepas aldrig", "",
              "| Plattfil | Visar | Var i byn | Material i scenen |", "|---|---|---|---|"]
    for fil, (vad, var, mat) in DEKOR.items():
        p = plattor.get(fil)
        rader.append("| `%s` | %s | %s | `%s` |" % (fil, vad, var, mat))
        använda.add(fil)
        if not p:
            problem.append("dekor %s saknas i tex/" % fil)

    rader += ["", "## Saknas i atlasen (att måla)", "",
              "| Material | Vad som saknas | Föreslagen fil | Varför |", "|---|---|---|---|"]
    for namn, (vad, fil, varför) in SAKNAS.items():
        if not vad:
            continue
        rader.append("| `%s` | %s | `%s` | %s |" % (namn, vad, fil, varför))

    rader += ["", "## Behöver ingen platta", "",
              "| Material | Yta i scenen | Varför inte |", "|---|---:|---|"]
    for namn in sorted(TEXTLÖSA):
        d = från.get(namn, {"area": 0.0, "ytor": 0})
        rader.append("| `%s` | %.1f m² / %d ytor | %s |" % (namn, d["area"], d["ytor"], TEXTLÖSA[namn]))

    lediga = sorted(set(plattor) - använda)
    if lediga:
        rader += ["", "## Fler kakelplattor att välja på (oanvända)", "",
                  "| Plattfil | Sort | Fog sid | Fog höjd |", "|---|---|---:|---:|"]
        for fil in lediga:
            p = plattor[fil]
            if p["slag"] != "platta":
                continue
            rader += ["| `%s` | %s | %.2f (x%s) | %.1f (x%s) |" %
                      (fil, p["sort"], p["fog_sid"], sv(p["kvot_sid"]), p["fog_höjd"],
                       sv(p["kvot_höjd"]))]

    if problem:
        rader += ["", "## FEL", ""] + ["* %s" % s for s in problem]

    # Grinden: varje material ska stå i EXAKT en av listorna, annars glider listan ifrån scenen.
    utanför = [n for n in från if n not in MAPP and n not in TEXTLÖSA and n not in SAKNAS]
    if utanför:
        rader += ["", "## Material utan rad i listan", ""] + ["* `%s`" % s for s in sorted(utanför)]
        problem.append("%d material utan rad: %s" % (len(utanför), ", ".join(sorted(utanför))))

    LISTA.write_text("\n".join(rader) + "\n")
    print("skrev %s (%d kaklade, %d dekorer, %d saknas, %d utan platta, %d fel)" %
          (LISTA.relative_to(ROT), len(MAPP), len(DEKOR), len(SAKNAS), len(TEXTLÖSA), len(problem)))
    for p in problem:
        print("  FEL: %s" % p)


# ---------------------------------------------------------------- körning

def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--kolla", action="store_true", help="mät bara, skriv ingenting")
    ap.add_argument("--lista", action="store_true", help="skriv texturlistan")
    ap.add_argument("--rendera", action="store_true", help="rendera rutmönstret (beviset)")
    ap.add_argument("--platta", type=float, default=PLATTA_M)
    ap.add_argument("--ut", type=Path, default=GLB)
    a = ap.parse_args(argv)

    scen = bpy.context.scene
    meshar = [o for o in scen.objects if o.type == "MESH"]
    före = sum(len(o.data.uv_layers) for o in meshar)
    print("=== BYN: %d objekt, %d mesh, %d UV-lager i utgångsläget ===" % (len(scen.objects), len(meshar), före))

    if a.kolla:
        print("(--kolla: bakar i minnet och mäter, skriver ingenting)")

    t0 = time.time()
    ytor = hörn = 0
    for o in meshar:
        p, l = sätt_uv(o, a.platta)
        ytor += p
        hörn += l
    print("BAKAT IN: %d UV-lager på %d objekt (%d ytor, %d hörn) på %.1f s" %
          (sum(len(o.data.uv_layers) for o in meshar), len(meshar), ytor, hörn, time.time() - t0))

    med = sum(len(o.data.uv_layers) for o in meshar)
    print("\n=== UV-LAGER: %d av %d mesh-objekt ===" % (med, len(meshar)))

    print("\n=== TÖJNING: hur många meter en platta täcker, per yttyp ===")
    print("%-8s %-7s %-10s %-9s %-9s %-9s %-9s %-9s %s" %
          ("YTYP", "YTOR", "AREA m²", "MEDEL m", "MIN m", "MAX m", "SPRIDN.", "DOM.AXEL", "PLATTAN"))
    hela = []
    for typ, d in sorted(mät_alla(meshar, a.platta).items()):
        m = np.array(d["m"])
        dom = np.array(d["dom"]) if d["dom"] else np.array([a.platta])
        hela += d["m"]
        print("%-8s %-7d %-10.1f %-9.3f %-9.3f %-9.3f %-8.2f%% %-9s %.2f m" %
              (typ, d["ytor"], d["area"], m.mean(), m.min(), m.max(),
               100.0 * (m.max() - m.min()) / m.mean(),
               "%.2f m" % dom.max(), a.platta))
    if hela:
        h = np.array(hela)
        print("SAMTLIGA ytor: medel %.4f m, min %.4f, max %.4f, spridning %.3f%% (plattan %.2f m)" %
              (h.mean(), h.min(), h.max(), 100.0 * (h.max() - h.min()) / h.mean(), a.platta))
        # Grinden: plattan ska hålla inom några procent, annars är projektionen fel på någon yta.
        avvik = 100.0 * abs(h - a.platta).max() / a.platta
        print("STÖRSTA AVVIKELSEN från plattan: %.2f %%" % avvik)

    if a.lista:
        skriv_lista(meshar)

    if not a.kolla:
        exportera(a.ut)
        print("\n=== GLB: %s, %d byte ===" % (a.ut, a.ut.stat().st_size))

    if a.rendera:
        print("\n=== BEVISET: rutmönster i varje material ===")
        print("  schackrutan satt i %d material" % sätt_schack_material())
        rendera(BEVISFIL, frontkamera())
        kam, info = närkamera(meshar)
        if kam is None:
            print("  ingen framåtvänd vägg hittades — närmbilden uteblir")
        else:
            print("  närbild: %s" % info)
            rendera(NÄRFIL, kam)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
