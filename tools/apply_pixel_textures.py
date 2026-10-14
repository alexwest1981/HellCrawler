# Medieval Pixel-Art Auto Texturing for Blender -> Godot
# Blender 3.6+ / 4.x / 5.x
# 1) Extract the ZIP so the "textures" folder is beside this .py file.
# 2) Open your .blend, switch to Scripting, open this file and Run Script.
# 3) Save the .blend. Export selected scene/objects as glTF for Godot.
#
# This script:
# - creates/updates reusable pixel-art materials
# - automatically unwraps all mesh objects using Smart UV Project
# - classifies objects by their names; unknown names get stone
# - sets nearest-neighbour image filtering for crisp pixel art
#
# IMPORTANT: Run on a COPY first. The script changes materials and UV maps.

import bpy
import os
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

def classify_object(obj):
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
    for i, obj in enumerate(meshes, 1):
        try:
            category = classify_object(obj)
            assign_material(obj, MATERIALS[category])
            sätt_uv(obj)
            counts[category] = counts.get(category, 0) + 1
            if i % 25 == 0:
                print(f"Pixel texturing: {i}/{len(meshes)} objects...")
        except Exception as e:
            print(f"[WARN] Skipped {obj.name}: {e}")

    print("=== Pixel-art texturing finished ===")
    print(f"Processed {len(meshes)} mesh objects.")
    for name, count in sorted(counts.items()):
        print(f"  {name}: {count} objects")
    print("Save the .blend, then export to glTF (.glb) for Godot.")

main()
