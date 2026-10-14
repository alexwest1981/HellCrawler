# Medieval Pixel-Art Auto Texturing for Blender -> Godot
# Blender 3.6+ / 4.x / 5.x
# 1) Extract the ZIP so the "textures" folder is beside this .py file.
# 2) Open your .blend, switch to Scripting, open this file and Run Script.
# 3) Save the .blend. Export selected scene/objects as glTF for Godot.
#
# This script:
# - creates/updates reusable pixel-art materials
# - automatically unwraps all mesh objects using Smart UV Project
# - classifies objects by their FIRST material; unmapped materials fall back to the name rules
# - sets nearest-neighbour image filtering for crisp pixel art
#
# IMPORTANT: Run on a COPY first. The script changes materials and UV maps.

import bpy
import json
import os
import re
from mathutils import Vector

# --- SETTINGS ---
# The default expects this script to live beside the "textures" directory.
# If running from Blender's internal Text Editor and __file__ is unavailable,
# replace TEXTURE_DIR with the absolute path to the extracted textures folder.
TEXTURE_DIR = "/home/alex/Projects/hellcrawlers/game/assets/by/tex"   # FIXAD: absolut sökväg — Blenders textredigerare har inget __file__,
# så den gamla raden letade efter textures/ bredvid .blend-filen (Alex .blend ligger i ~/Downloads).

# If the textures folder isn't found, try the folder beside the saved .blend.
if not os.path.isdir(TEXTURE_DIR):
    TEXTURE_DIR = bpy.path.abspath("//textures")

UV_NAME = "UVMap_PixelArt"
ISLAND_MARGIN = 0.015
REPLACE_EXISTING_MATERIALS = True
## Rutans storlek i meter. En ruta = en hel 512-platta, så 1,0 m ger 512 px per meter — samma täthet
## som projektets egna plattor (tools/gen_tiles_alex.py mätte 512 px/m).
TILE_METER = 1.0

## Mappningsrapporten skrivs hit. Kontrollskriptet (tools/byn_tex_prov.py) kör EFTER det här skriptet
## i samma Blender-session, och då är de ursprungliga materialen redan borta ur scenen — filen är
## enda vägen att få ut vilket material som blev vilken platta, till texturlistan.
try:
    ROT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
except NameError:  # Blenders textredigerare har inget __file__
    ROT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(TEXTURE_DIR))))
RAPPORT = os.path.join(ROT, "tools", "byn_mappning.json")

## Plattor ur Alex' EGNA paket (512 px, game/assets/by/tex/).
TEXTURES = {
    "Stone": "stone_wall.png",
    "Mossy Stone": "mossy_stone.png",
    "Dark Stone": "dark_stone.png",
    "Terracotta Roof": "roof_terracotta.png",
    "Slate Roof": "roof_slate.png",
    "Wood": "wood_planks.png",
    "Tudor Plaster": "tudor_wall.png",
    "Grass": "grass.png",
    "Dirt": "dirt.png",
    "Cobblestone Ground": "cobblestone_ground.png",
    "Hedge": "hedge.png",
    ## ATLASEN (Alex: "det som är nu är väldigt platt — använd atlasen med", och "de utsnitten där
    ## ytan är monoton i dag: mossig sten, gräs med blommor, jord, grus, sand"). Utsnitten är 256 px
    ## (halva paketets täthet) och ligger i game/assets/by/tex/atlas/, klippta ur
    ## medieval_pixel_texture_atlas_4x.png av tools/gen_tex_atlas.py. Varje val är mätt: sömlös kant
    ## mot kant (fog_sid) och palettavstånd mot game/assets/palette.json under tröskeln 0,18.
    "Grass Flowers": "atlas/grass.png",                          # gräs med små blommor, fog 3,08
    "Cobblestone Grey": "atlas/cobblestone_grey.png",            # kullersten grå, fog 5,78
    "Cobblestone Brown": "atlas/cobblestone_brown.png",          # kullersten brunorange, fog 9,84
    "Cobblestone Mossy": "atlas/cobblestone_mossy.png",          # kullersten med mossa, fog 5,93
    "Dirt Stony": "atlas/dirt_stony.png",                        # stenig jord (grusväg), fog 7,23
    "Sand Path": "atlas/sand_path.png",                          # sandig stig, fog 5,04
    "Stone Mossy": "atlas/stone_wall_mossy_small.png",           # mossig mursten, fog 12,80
    "Iron Riveted": "atlas/metal_riveted.png",                   # nitslagen metall, hamrad
    "Window Warm": "atlas/window_four_pane.png",                 # fyrdelat fönster, varmt ljus, fog 7,24
    "Window Bright": "atlas/window_narrow.png",                  # smalt tvådelat fönster, fog 9,97
}

def load_texture(filename):
    path = os.path.join(TEXTURE_DIR, filename)
    if not os.path.isfile(path):
        raise FileNotFoundError(
            "Texture not found: " + path +
            "\nExtract the ZIP and keep the textures folder beside this script."
        )
    image = bpy.data.images.load(path, check_existing=True)
    image.filepath = path
    image.pack()
    # Nearest filtering preserves pixel-art edges in Blender.
    try:
        image.colorspace_settings.name = "sRGB"
    except Exception:
        pass
    return image

def make_material(name, filename):
    mat = bpy.data.materials.get("PX_" + name)
    if mat is None:
        mat = bpy.data.materials.new("PX_" + name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (500, 0)
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (240, 0)
    bsdf.inputs["Roughness"].default_value = 0.88
    tex = nodes.new("ShaderNodeTexImage")
    tex.location = (-250, 50)
    tex.image = load_texture(filename)
    tex.interpolation = "Closest"
    tex.extension = "REPEAT"
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = UV_NAME
    uv.location = (-470, 50)
    links.new(uv.outputs["UV"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (0.35, 0.32, 0.27, 1.0)
    return mat

MATERIALS = {name: make_material(name, file) for name, file in TEXTURES.items()}

## THE PRIMARY MAPPING: Alex' own material name -> plate.
## MÄTT på scenen: objektens NAMN skiljer inte materialen. 745 objekt heter något med "tile" och där
## ligger BÅDE Roof_Slate_1/2 (378 objekt) och Roof_Red_1/2 (280) — namnreglerna gav därför 808 objekt
## "Terracotta Roof" och 0 "Slate Roof", och 324 stenhus hamnade utan nyckelord. Materialnamnen
## däremot är exakta (mätt: 50 material i scenen, 0 objekt med fler än en materialplats), så objektets
## FÖRSTA material avgör plattan. Ett material som inte står här har ingen platta än (214 objekt:
## Iron, Roof_Thatch, Bulb_Glow, Cloth_*, Sheep_Wool, Skin, Fire_*, Window_*, Gold, Horse_Brown,
## Gem_*, Mountain_Rock) och får namnreglerna nedan i stället.
MATERIAL_TO_PLATE = {
    # tak
    "Roof_Slate_1": "Slate Roof",
    "Roof_Slate_2": "Slate Roof",
    "Roof_Purple_1": "Slate Roof",
    "Roof_Purple_2": "Slate Roof",
    "Roof_Red_1": "Terracotta Roof",
    "Roof_Red_2": "Terracotta Roof",
    # mark — atlasen, för de ytor som var monotona med en enda platta (kullerstenen låg på SAMMA
    # platta för alla 295 objekten och gräset på en enda för 30)
    "Cobble_1": "Cobblestone Grey",
    "Cobble_2": "Cobblestone Brown",
    "Cobble_3": "Cobblestone Mossy",
    "Road_Base": "Dirt Stony",          # grusväg: packad jord med grus
    "Dirt_Cliff": "Sand Path",          # jordbranten: sandig, torr jord
    "Grass_Light": "Grass Flowers",
    "Grass_Mid": "Grass Flowers",
    "Grass_Dark": "Grass Flowers",
    "Mountain_Rock": "Stone Mossy",     # mossig sten; berget är 1237 m² och plattan är sömlös
    # vägg
    "Stone_Light": "Stone",
    "Stone_Dark": "Stone",
    "Stone_Wall": "Stone",
    "Plaster_Warm": "Tudor Plaster",
    "Plaster_Cream": "Tudor Plaster",
    # trä
    "Wood_Dark": "Wood",
    "Wood_Oak": "Wood",
    "Wood_Beam": "Wood",
    "Wood_Light": "Wood",
    # växtlighet
    "Leaf_Mid": "Hedge",
    "Leaf_Dark": "Hedge",
    "Leaf_Light": "Hedge",
    "Pine_Green": "Hedge",
    # järn och fönsterglas: hade ingen platta i paketet, atlasen har båda
    "Iron": "Iron Riveted",
    "Window_Warm": "Window Warm",
    "Window_Bright": "Window Bright",
}

## RÖKEN. Alex: "Röken som kommer upp ur ena huset är texturerad med sten — ta bort bollarna av rök
## och gör om dem till en smoke emitter." MÄTT: i den förra (namnklassade) körningen föll Cloud_* och
## Smoke_* igenom ända till Stone — 20 objekt moln/rök med stenplatta. Molnen och röken HOPPAS ÖVER i
## exporten (Alex' .blend rörs inte; skriptet sparar aldrig filen) och röken ersätts av en
## GPUParticles3D i Godot-scenen på det uppmätta klustercentrumet, se game/ui/by_3d.gd.
ROK_MATERIAL = ("Cloud_White", "Smoke_Grey")
ROK_ORD = ("smoke", "rök", "rok", "cloud", "puff", "smog", "mist")

def första_materialet(obj):
    """Objektets FÖRSTA materialnamn, eller None om objektet inte har något material."""
    if obj.data.materials and obj.data.materials[0] is not None:
        return obj.data.materials[0].name
    return None

def namnregler(obj):
    """FALLBACK: platta ur objektets NAMN, för material som ännu inte har en egen platta."""
    n = obj.name.lower()
    # vegetation / terrain
    if any(k in n for k in ("grass", "lawn", "meadow", "ground_grass", "field")):
        return "Grass"
    if any(k in n for k in ("hedge", "bush", "shrub", "leaf", "foliage", "tree", "pine", "oak")):
        return "Hedge"
    if any(k in n for k in ("dirt", "soil", "mud", "path", "earth")):
        return "Dirt"
    if any(k in n for k in ("cobble", "street", "road", "pavement", "plaza", "floor", "ground", "walkway")):
        return "Cobblestone Ground"

    # roofs
    if any(k in n for k in ("roof", "roofing", "tile", "shingle", "tavern_gable_roof")):
        if any(k in n for k in ("slate", "blue", "tower")):
            return "Slate Roof"
        return "Terracotta Roof"
    if "gable" in n and not any(k in n for k in ("wall", "front", "back")):
        return "Terracotta Roof"

    # wood / furniture / doors / barrels
    if any(k in n for k in ("wood", "timber", "beam", "plank", "barrel", "door", "gate_door",
                            "bench", "table", "chair", "sign", "frame", "rafter", "shutter",
                            "fence", "cart", "wheel", "crate", "ladder")):
        return "Wood"

    # Tudor/plaster wall
    if any(k in n for k in ("tudor", "plaster", "half_timber", "fachwerk", "gable")):
        return "Tudor Plaster"

    # vegetation/rock names
    if any(k in n for k in ("rock", "boulder", "stone", "merlon", "crenel", "wall", "tower",
                            "castle", "gate", "brick", "foundation", "chimney", "well")):
        if any(k in n for k in ("bg_wall", "moss", "ruin")):
            return "Mossy Stone"
        if any(k in n for k in ("tower", "gate", "merlon", "crenel")):
            return "Dark Stone"
        return "Stone"

    # Name clues from the screenshot: Tavern_Body / Tavern_Gable / Gate_Merlon etc.
    if any(k in n for k in ("tavern_body", "house_body", "building_body", "shop_body")):
        return "Tudor Plaster"

    return "Stone"

def är_rök(obj):
    """Sant för moln- och rökobjekten (material, eller namn med smoke/rök/cloud/puff ...)."""
    namn = första_materialet(obj)
    if namn in ROK_MATERIAL:
        return True
    n = obj.name.lower()
    return any(k in n for k in ROK_ORD)

def bakgrundstak(obj):
    """Takplattan för ett BAKGRUNDSOBJEKT som annars hamnar på sten.

    Alex: "de pyramidliknande varianterna borde ha tak-textur ... de ska ha tak, alltså
    roof_terracotta eller roof_slate efter sin originalmaterialfamilj — inte stone." De 39
    bakgrundsobjekten med stenmaterial är torn och krenelerade murar (BG_Tower, BG_Tower_Rim,
    BG_Wall_Crenel, BG_Castle_Wall) och har ingen takegen familj — de följer därför NAMNET: torn och
    skifferpurpur blir skiffer, resten tegel.
    """
    n = obj.name.lower()
    if any(k in n for k in ("slate", "purple", "tower")):
        return "Slate Roof"
    return "Terracotta Roof"

def classify_object(obj):
    """(platta, källa) för ett objekt: materialets platta först, namnreglerna som fallback.

    MÅSTE läsas INNAN assign_material tömmer materiallistan — annars finns inget material kvar att
    klassificera på.
    """
    namn = första_materialet(obj)
    if namn in MATERIAL_TO_PLATE:
        platta = MATERIAL_TO_PLATE[namn]
        # BAKGRUNDEN: ett bakgrundsobjekt får aldrig stenplattan (se bakgrundstak).
        if platta == "Stone" and "bg" in obj.name.lower():
            return bakgrundstak(obj), "material"
        return platta, "material"
    return namnregler(obj), "namn"

def sätt_uv(obj):
    """KUBPROJEKTION i världskoordinater — en ruta är TILE_METER i världen, överallt.

    ÄNDRAT AV OSS (andra ändringen i Alex' skript): smart_project(scale_to_bounds=True) lade
    texturen i 0..1 över OBJEKTETS EGEN box, så rutans storlek berodde på objektets storlek — en
    liten sten fick en hel platta på framsidan och en lång vägg samma platta utdragen över hela
    väggen. Det är "tapeten" Alex klagade på. Packens egen README varnar för samma sak
    ("the scale may need tuning for very large objects").

    I stället: varje ytas två UV-axlar tas ur ytans NORMAL, i VÄRLDSkoordinater, delat med
    TILE_METER. Då följer rutans pixelstorlek objektets verkliga storlek i meter.

    Den sista grenen är också vår: en yta som varken pekar mest i X, Y eller Z (takfallen) får sin
    bas i YTANS plan. Projektion på den dominanta axeln hade sträckt ett snedtak med 1/cos(vinkeln),
    och MÄTT på scenen är 34,4 % av arean lutande — värst 1,61x uttänjning. Med basen i ytans plan
    blir rutan exakt TILE_METER även där.
    """
    mesh = obj.data
    uv = mesh.uv_layers.get(UV_NAME)
    if uv is None:
        uv = mesh.uv_layers.new(name=UV_NAME)
    # Bara ETT UV-lager: glTF tar TEXCOORD_0 ur det FÖRSTA lagret, och ett kvarglömt lager från en
    # tidigare körning hade blivit det som exporterades (samma indata ska ge samma utdata).
    while len(mesh.uv_layers) > 1:
        mesh.uv_layers.remove(mesh.uv_layers[-1])
    mesh.uv_layers.active = uv
    uv.active_render = True

    M = obj.matrix_world
    inv = M.to_3x3().inverted_safe().transposed()
    vrld = [M @ v.co for v in mesh.vertices]
    for poly in mesh.polygons:
        n = (inv @ poly.normal).normalized()
        if abs(n.z) >= max(abs(n.x), abs(n.y)):
            a, b = 0, 1
        elif abs(n.x) >= abs(n.y):
            a, b = 1, 2
        else:
            a, b = 0, 2
        if max(abs(n.x), abs(n.y), abs(n.z)) <= 0.999:
            # Sned yta: basen i ytans eget plan, annars sträcks mönstret.
            axel = min(range(3), key=lambda i: abs(n[i]))
            e = Vector((0.0, 0.0, 0.0))
            e[axel] = 1.0
            u = (e - n * e.dot(n)).normalized()
            v = n.cross(u)
            for li in poly.loop_indices:
                co = vrld[mesh.loops[li].vertex_index]
                uv.data[li].uv = (co.dot(u) / TILE_METER, co.dot(v) / TILE_METER)
            continue
        for li in poly.loop_indices:
            co = vrld[mesh.loops[li].vertex_index]
            uv.data[li].uv = (co[a] / TILE_METER, co[b] / TILE_METER)

def assign_material(obj, mat):
    if obj.data.materials:
        if REPLACE_EXISTING_MATERIALS:
            obj.data.materials.clear()
        else:
            return
    obj.data.materials.append(mat)
    # Assign the one material to every polygon.
    for poly in obj.data.polygons:
        poly.material_index = 0

def main():
    if not os.path.isdir(TEXTURE_DIR):
        raise FileNotFoundError(
            "Could not find texture folder: " + TEXTURE_DIR +
            "\nSet TEXTURE_DIR near the top of this script."
        )

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        print("No mesh objects found.")
        return

    # Ensure Object Mode before processing.
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    counts = {}
    per_material = {}      # ursprungligt material -> antal objekt
    omappade = {}          # ursprungligt material -> [fallbackplatta, antal objekt]
    rök = []               # moln- och rökobjekt: textureras inte, hoppas över i exporten
    rök_hoppade = {}
    bg = {"tak": 0, "sten": 0, "antal": 0}
    for i, obj in enumerate(meshes, 1):
        try:
            # LÄSES FÖRE assign_material: den tömmer materiallistan, och då finns inget kvar att
            # klassificera på. Det här är hela poängen med ändringen — materialet, inte namnet.
            ursprung = första_materialet(obj)
            if är_rök(obj):
                rök.append(obj)
                rök_hoppade[obj.name] = ursprung
                continue
            category, källa = classify_object(obj)
            assign_material(obj, MATERIALS[category])
            sätt_uv(obj)
            counts[category] = counts.get(category, 0) + 1
            per_material[ursprung] = per_material.get(ursprung, 0) + 1
            if källa == "namn":
                rad = omappade.setdefault(ursprung, [category, 0])
                rad[1] += 1
            if "bg" in obj.name.lower():
                bg["antal"] += 1
                if category == "Stone":
                    bg["sten"] += 1
                elif category in ("Terracotta Roof", "Slate Roof"):
                    bg["tak"] += 1
            if i % 25 == 0:
                print(f"Pixel texturing: {i}/{len(meshes)} objects...")
        except Exception as e:
            print(f"[WARN] Skipped {obj.name}: {e}")

    print("=== Pixel-art texturing finished ===")
    print(f"Processed {len(meshes)} mesh objects.")
    for name, count in sorted(counts.items()):
        print(f"  {name}: {count} objects")

    # VILKET URSPRUNGLIGT MATERIAL FICK VILKEN PLATTA. Grupperat på platta, för att gå att jämföra
    # med plattan i game/assets/by/tex/.
    print("\n=== PLATE <- ORIGINAL MATERIAL (mapped from the material, not the name) ===")
    print("%-26s %-22s %s" % ("ORIGINAL MATERIAL", "PLATE", "OBJECTS"))
    for platta in sorted(set(MATERIAL_TO_PLATE.values())):
        rader = [(m, n) for m, n in per_material.items() if MATERIAL_TO_PLATE.get(m) == platta]
        for m, n in sorted(rader, key=lambda r: (-r[1], r[0])):
            print("%-26s %-22s %d" % (m, platta, n))
        print("%-26s %-22s %d  (sum)" % ("", "", sum(n for _, n in rader)))

    # UNDERLAGET FÖR ALEX: material utan platta, med namnreglernas nödlösning.
    print("\n=== NO PLATE IN THE PACKAGE: material -> fallback plate -> objects ===")
    print("%-26s %-22s %s" % ("ORIGINAL MATERIAL", "FALLBACK PLATE", "OBJECTS"))
    for m, (fb, n) in sorted(omappade.items(), key=lambda kv: (-kv[1][1], kv[0])):
        print("%-26s %-22s %d" % (m, fb, n))
    print("%-26s %-22s %d" % ("", "", sum(n for _, n in omappade.values())))

    # RÖKEN: exakt vilka objekt som hoppas över, och var rökens mitt ligger (för Godot-emittern).
    print("\n=== SMOKE/CLOUDS: SKIPPED IN THE EXPORT (the .blend is not touched) ===")
    rök_kluster = {}
    for o in rök:
        fam = re.sub(r"[\d_]+$", "", o.name)
        mw = o.matrix_world
        ctr = sum((mw @ v.co for v in o.data.vertices), Vector((0.0, 0.0, 0.0)))
        ctr /= max(len(o.data.vertices), 1)
        d = rök_kluster.setdefault(fam, {"n": 0, "v": Vector((0.0, 0.0, 0.0))})
        d["n"] += 1
        d["v"] += ctr
    for namn_, d in sorted(rök_kluster.items()):
        c = d["v"] / d["n"]
        print("%-16s %3d objekt  blender (%.2f, %.2f, %.2f)  gltf (%.2f, %.2f, %.2f)" %
              (namn_, d["n"], c.x, c.y, c.z, c.x, c.z, -c.y))
    print("%-16s %3d objekt  (varav %d rök, %d moln)" %
          ("TOTALT", len(rök),
           sum(d["n"] for n, d in rök_kluster.items() if "smoke" in n.lower()),
           sum(d["n"] for n, d in rök_kluster.items() if "cloud" in n.lower())))
    for namn_ in sorted(rök_hoppade):
        print("  %-28s %s" % (namn_, rök_hoppade[namn_]))
    # Rökmittens kluster (Chimney_Smoke_*) i glTF-koordinater — emitterns plats i game/ui/by_3d.gd.
    rök_mitt = None
    for namn_, d in rök_kluster.items():
        if "smoke" in namn_.lower():
            c = d["v"] / d["n"]
            rök_mitt = [round(c.x, 3), round(c.z, 3), round(-c.y, 3)]

    print("\n=== BACKGROUND (name contains 'bg') ===")
    print("objects %d, on a roof plate %d, on the stone plate %d" %
          (bg["antal"], bg["tak"], bg["sten"]))
    if bg["sten"]:
        print("FEL: %d background objects still on a stone plate" % bg["sten"])

    with open(RAPPORT, "w") as f:
        json.dump({
            "material_to_plate": MATERIAL_TO_PLATE,
            "plate_file": TEXTURES,
            "plates_used": sorted(counts),
            "objects_per_material": per_material,
            "unmapped": {m: {"fallback": fb, "objects": n} for m, (fb, n) in omappade.items()},
            "smoke_skipped": rök_hoppade,
            "smoke_clusters": {n: {"objects": d["n"],
                                   "gltf": [round((d["v"] / d["n"]).x, 3),
                                            round((d["v"] / d["n"]).z, 3),
                                            round(-(d["v"] / d["n"]).y, 3)]}
                               for n, d in rök_kluster.items()},
            "smoke_center_gltf": rök_mitt,
            "background": bg,
        }, f, indent=1, sort_keys=True)
    print("wrote %s" % RAPPORT)
    print("Save the .blend, then export to glTF (.glb) for Godot.")

main()
