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

## Plattor ur Alex' EGNA paket (512 px, game/assets/by/tex/) — de sex sista (mursten, virke, gras,
## bark, lövverk, barr) är räknade ur hans nedladdade texturpaket av tools/gen_trad_plattor.py.
TEXTURES = {
    "Stone": "mursten.png",
    "Mossy Stone": "mossy_stone.png",
    "Dark Stone": "dark_stone.png",
    "Terracotta Roof": "tak_tegel.png",
    "Slate Roof": "tak_skiffer.png",
    "Purple Roof": "tak_lila.png",
    "Wood": "virke.png",
    ## BALKPLATTORNA. virke.png och skylt.png är PLANKVÄGGAR — mätt 12 brädskarvar i U, 0 vågräta —
    ## och plattan upprepas var 1:e meter. På en balk blir U = höjden (0,55 m), alltså ~7 skarvar per
    ## meter: en 5,2 m lång list såg ut som ~36 sågade bitar. Alex 2026-10-14: "det är EN balk som
    ## ligger vågrätt, inte 40 på höjden avsågade och ihopklistrade" och "detsamma gäller taknockar,
    ## skyltar osv" — dvs allt trä som är längre än en meter. Balkplattan är EN planka ur samma källa
    ## (den bredaste plankytan, 81 px), töjd till 512 och tonad till förlagans medelton. MÄTT:
    ## kolumnspridning 17,2 -> 6,2 (skarvarna borta), radspridning 2,0 -> 3,5 (ådringen kvar, starkare).
    ## UV-regeln rörs inte: U blir fortfarande höjden, V längden, och nu är U en enda bräda.
    "Wood Beam": "virke_balk.png",
    "Skylt Board": "skylt_balk.png",
    "Tudor Plaster": "puts.png",
    "Grass": "gras.png",
    "Dirt": "dirt.png",
    "Cobblestone Ground": "cobblestone_ground.png",
    "Hedge": "hedge.png",
    ## ATLASEN (Alex: "det som är nu är väldigt platt — använd atlasen med", och "de utsnitten där
    ## ytan är monoton i dag: mossig sten, gräs med blommor, jord, grus, sand"). Utsnitten är 256 px
    ## (halva paketets täthet) och ligger i game/assets/by/tex/atlas/, klippta ur
    ## medieval_pixel_texture_atlas_4x.png av tools/gen_tex_atlas.py. Varje val är mätt: sömlös kant
    ## mot kant (fog_sid) och palettavstånd mot game/assets/palette.json under tröskeln 0,18.
    "Grass Flowers": "atlas/grass.png",                          # gräs med små blommor, fog 3,08
    ## TRÄDEN. Alex' paket och atlasen saknar bark, barr och trädkrona (mätt: lästa ruta för ruta,
    ## ingen har stam eller barr), så träden fick stammarnas planka och tallarnas kronor blomgräs.
    ## tools/gen_trad_plattor.py bygger de fyra ur en befintlig platta + bildens uppmätta färg.
    "Bark": "bark.png",                                          # stammen, ur wood_planks vriden
    "Lövverk": "lov.png",                                        # lövkronan, ur atlas/ivy
    "Barr": "barr.png",                                          # tallarnas våningar, ur hedge
    "Mörk Zon": "mork_zon.png",                                  # förgrundszonen längst ned i bilden
    "Cobblestone Grey": "atlas/cobblestone_grey.png",            # kullersten grå, fog 5,78
    "Cobblestone Brown": "atlas/cobblestone_brown.png",          # kullersten brunorange, fog 9,84
    "Cobblestone Mossy": "atlas/cobblestone_mossy.png",          # kullersten med mossa, fog 5,93
    "Dirt Stony": "atlas/dirt_stony.png",                        # stenig jord (grusväg), fog 7,23
    "Sand Path": "atlas/sand_path.png",                          # sandig stig, fog 5,04
    "Stone Mossy": "atlas/stone_wall_mossy_small.png",           # mossig mursten, fog 12,80
    "Iron Riveted": "atlas/metal_riveted.png",                   # nitslagen metall, hamrad
    "Window Warm": "atlas/window_four_pane.png",                 # fyrdelat fönster, varmt ljus, fog 7,24
    "Window Bright": "atlas/window_narrow.png",                   # smalt tvådelat fönster, fog 9,97
    ## SKYLT OCH FÖNSTER. Skyltarnas bräda och kanter låg på "Wood" — samma platta som bjälkarna —
    ## och fönstren på atlasens bruna rutor (97,54,29) / (115,69,32), brunare än väggen. Allt flöt
    ## ihop (Alex 2026-10-14). Bildens uppmätta värden: skyltbräda (115,91,72), ram/skugga
    ## (39,29,37), lysande bokstäver och lyst glas (235,181,119). Plattorna räknas ur virkets
    ## planka av tools/gen_trad_plattor.py — motivet är trä, bara tonen är bildens.
    "Skylt": "skylt.png",
    "Ram": "ram.png",
    "Ljus Varm": "ljus_varm.png",
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
    "Roof_Purple_1": "Purple Roof",
    "Roof_Purple_2": "Purple Roof",
    "Roof_Red_1": "Terracotta Roof",
    "Roof_Red_2": "Terracotta Roof",
    ## VASSTAKET. Alex' paket har ingen vassplatta (roof_thatch.png finns inte i tex/), så materialet
    ## stod inte i tabellen och 42 objekt föll vidare till namnreglerna, som gav samma platta
    ## (MÄTT i tools/byn_mappning.json: Roof_Thatch -> Terracotta Roof, 42 objekt). Raden gör valet
    ## uttalat i stället för beroende av att objektnamnet råkar innehålla "tile".
    "Roof_Thatch": "Terracotta Roof",
    # mark — atlasen, för de ytor som var monotona med en enda platta (kullerstenen låg på SAMMA
    # platta för alla 295 objekten och gräset på en enda för 30)
    "Cobble_1": "Cobblestone Grey",
    "Cobble_2": "Cobblestone Brown",
    "Cobble_3": "Cobblestone Mossy",
    "Road_Base": "Cobblestone Grey",     # GATAN (Alex 2026-10-14: "Gatan framför husen är av gräs
                                         # just nu, den behöver vara kullersten"). MÄTT med strålar
                                         # ned över gatans remsa: den översta ytan var 29,1 %
                                         # Road_Bed med grusplattan och bara ~9 % kullersten — och
                                         # kullerstenarna ÄR rätt mappade (Cobble_1/2/3 -> Grey/
                                         # Brown/Mossy), de ligger bara glest ovanpå bädden, så
                                         # gruset syns emellan. Bäddens yta får därför samma
                                         # kullersten: gatan läses som sten utan att geometrin rörs.
    ## JORDBRANTEN LÄNGST FRAM. Den fick Sand Path, men bildens nedersta band — där branten ligger —
    ## är den MÖRKA zonen (MÄTT radvis: (40,47,50) mot gatans (109,88,80) och gräsets (75,84,62)).
    "Dirt_Cliff": "Mörk Zon",
    ## GRÄSET. Det fick atlasens "Grass Flowers", men bildens gräsband har inga blommor (MÄTT i
    ## remsan: grönt utan ljusa blomfläckar, medel (75,84,62)). Alex' egen grass.png är vanligt gräs.
    "Grass_Light": "Grass",
    "Grass_Mid": "Grass",
    "Grass_Dark": "Grass",
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
    ## Fönstren: ATLASENS riktiga fönsterplattor. Den tidigare mappningen (Ram / Ljus Varm) träffade
    ## bildens FÄRGER exakt men var PLATT — mätt: ram.png 83,7 % mörkt och 0,0 % varmt, ljus_varm.png
    ## 100 % varmt och 0,0 % mörkt, alltså en enfärgad ruta utan spröjs och utan ljus inifrån. Atlasen
    ## har båda: window_four_pane 35,4 % mörkt + 27,4 % varmt (29 529 unika färger), window_narrow
    ## 40,4 % + 18,4 % (24 932). Alex 2026-10-14: "Det är fönster över skylten här t.ex, kolla så du
    ## inte hittar fler fönster som behöver texturer." MÄTT: NIO glasobjekt ligger på modellens egna
    ## Window_Warm/Window_Bright, och alla nio bar en platt platta — sju Ram, två Ljus Varm — däribland
    ## Weaver_Win_Glass, fönstret precis ovanför skylten (z 2,69 mot skyltens 1,55).
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
                            "bench", "table", "chair", "rafter",
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

def bakgrundstak(obj, platta):
    """Plattan för ett BAKGRUNDSOBJEKT vars material är sten.

    Alex: "de pyramidliknande varianterna borde ha tak-textur ... de ska ha tak, alltså
    roof_terracotta eller roof_slate efter sin originalmaterialfamilj — inte stone." Det gäller
    TAKFORMADE objekt — takpannor, sadeltak, spiror.

    FÖRRA RADEN GAV TAKPLATTA ÅT ALLA bakgrundsobjekt med stenmaterial, och då hamnade teglet på
    MURAR: MÄTT i byn.glb, 39 bakgrundsobjekt på en takplatta varav 35 är krenelering/borgmur
    (BG_Wall_Crenel 34, BG_Castle_Wall 1) och 4 är torn (BG_Tower 2, BG_Tower_Rim 2 — en tornkropp
    är ingen takyta). Alex: "muren bakom till höger är fel texturer på". Namnet avgör därför bara
    för de takformade; muren och tornet behåller sin EGEN stenplatta (`platta`, ur materialet).
    """
    n = obj.name.lower()
    if not any(k in n for k in ("tile", "roof", "gable", "pyramid", "spire")):
        return platta
    if any(k in n for k in ("slate", "purple", "tower")):
        return "Slate Roof"
    return "Terracotta Roof"

## TRÄDENS DELAR. MÅSTE komma FÖRE MATERIAL_TO_PLATE: stammarna har Wood_Beam/Wood_Dark (samma
## material som bjälkar, sparrar och plank) och tallarnas våningar Grass_Light (samma som gräset).
## Materialtabellen gav därför 17 stammar plank och 8 tallar blomgräs (MÄTT i byn.glb). Namnet är
## det som skiljer dem från virket och marken.
TRÄD_ORD = (("trunk", "Bark"), ("tier", "Barr"), ("canopy", "Lövverk"))

def trädplatta(obj):
    """Plattan för en trädstam/krona/våning, eller None om objektet inte är en del av ett träd."""
    n = obj.name.lower()
    for ord_, platta in TRÄD_ORD:
        if ord_ in n:
            return platta
    return None

## ÖVERSTYRDA OBJEKT, efter namn. Kedjan körs på Alex' redan texturerade fil, där materialet bär
## plattans EGNA namn ("PX_Dirt Stony") — mappningstabellen är då frusen och en ändrad mappning når
## inte fram (mätt: Road_Base -> kullersten hade ingen verkan alls förrän källan byttes). Namnet är
## det enda handtag som finns kvar. Alex 2026-10-14: "Gatan framför husen är av gräs just nu, den
## behöver vara kullersten." MÄTT med strålar ned över gatans remsa (y -1,0..1,6): den översta ytan
## var 29,1 % Road_Bed med grusplattan och 4,7 % Gate_Plaza_Bed, mot bara ~9 % kullersten.
## De två är gatans och platsens BÄDDAR; kullerstenarna ligger glest ovanpå och gruset syntes emellan.
## Körningen på REN källa (finaliserad_alex_ren.blend) ger dem samma platta ur tabellen — det här är
## samma svar, men utan att röra de ~50 objekt vars frusna plattor skiljer sig från tabellen.
OVERRIDE = {
    "Road_Bed": "Cobblestone Grey",
    "Gate_Plaza_Bed": "Cobblestone Grey",
    ## GLASET. MÄTT ur modellens EGNA material Window_Warm/Window_Bright: nio objekt, och i en
    ## texturerad fil bar ALLA nio en platt platta (sju PX_Ram = mörk skyltram, två PX_Ljus Varm = plat
    ## guld) — fönster utan spröjs och utan ljus. Materialvägen kan inte nå dem (frusen) och NAMNET kan
    ## inte skilja warm från bright (Weaver_Win_Glass och Jeweler_Top_Win_Glass heter likadant), så
    ## listan skrivs ut. Alex 2026-10-14: "Det är fönster över skylten här t.ex, kolla så du inte
    ## hittar fler fönster som behöver texturer." Fönsterprovet i byn_tex_prov.py vaktar listan.
    "BG_House_Left1_Win_Glass": "Window Warm",
    "BG_House_Left2_Win_Glass": "Window Warm",
    "BG_House_Right_Win_Glass": "Window Warm",
    "Jeweler_Door_Glass_Glass": "Window Warm",
    "Jeweler_Shop_Win_Glow": "Window Bright",
    "Jeweler_Top_Win_Glass": "Window Bright",
    "Tavern_Interior_Recess": "Window Warm",
    "Tavern_Top_Win_Glass": "Window Warm",
    "Weaver_Win_Glass": "Window Warm",
}

def classify_object(obj):
    """(platta, källa) för ett objekt: trädens delar först, materialets platta, namnreglerna sist.

    MÅSTE läsas INNAN assign_material tömmer materiallistan — annars finns inget material kvar att
    klassificera på.
    """
    if obj.name in OVERRIDE:
        return OVERRIDE[obj.name], "override (namn)"
    träd = trädplatta(obj)
    if träd:
        return träd, "namn (träd)"
    ## SKYLT OCH FÖNSTER FÖRE MATERIALET. Brädan, kanterna och bokstäverna heter Sign_* men delar
    ## MATERIAL med bjälkarna (Wood_Beam/Wood_Dark), och fönsterramarna heter *_Frame med samma
    ## virkesmaterial — materialvägen nedan kan inte skilja dem, så de hamnade på väggens platta och
    ## försvann i den (Alex 2026-10-14: "skyltarna ... fönstren ... nu flyter allt ihop"). Samma väg
    ## som trädens delar: NAMNET först. MÄTT i bilden: bräda (115,91,72), ram (39,29,37),
    ## bokstäver och lyst glas (235,181,119).
    n = obj.name.lower()
    if n.endswith("_txt"):
        return "Ljus Varm", "namn (skylttext)"
    ## SKYLTENS KANT ÄR RAMEN: i bilden är ramen mörk (39,29,37) och brädan ljusare (115,91,72) — med
    ## samma platta på båda blir skylten ett enda brunt fält utan ram.
    if "sign" in n and "border" in n:
        return "Ram", "namn (skyltkant)"
    if "sign" in n and "glow" not in n:
        return "Skylt", "namn (skylt)"
    if "frame" in n or "shutter" in n:
        return "Ram", "namn (ram)"
    namn = första_materialet(obj)
    ## IDEMPOTENS (mätt 2026-10-14): en redan texturerad fil har plattans EGNA materialnamn,
    ## "PX_Mörk Zon". Det finns inte i MATERIAL_TO_PLATE, så objektet föll igenom till namnreglerna
    ## och vidare till standarden Stone: kört på Alex' texturerade fil blev Cliff_Face PX_Stone
    ## (mursten, ljus grå) i stället för Mörk Zon (bildens mörka förgrundszon) — samma objekt blev
    ## Mörk Zon i min egen kedja, där materialet fortfarande hette Dirt_Cliff. Plattans namn ÄR
    ## kategorin, så räcker det att skala av prefixet: en andra körning ger samma svar som den första.
    if namn is not None and namn.startswith("PX_"):
        namn = namn[3:]
    if namn in TEXTURES:
        return namn, "material (plattans namn)"
    if namn in MATERIAL_TO_PLATE:
        platta = MATERIAL_TO_PLATE[namn]
        # BAKGRUNDEN: ett bakgrundsobjekt får takplatta bara om det är TAKFORMAT (se bakgrundstak).
        if platta == "Stone" and "bg" in obj.name.lower():
            return bakgrundstak(obj, platta), "material"
        return platta, "material"
    return namnregler(obj), "namn"

def balkmått(obj):
    """(led, fiber, balk) för ett objekt — SAMMA mått som sätt_uv använder, så klassningen och UV:n
    inte kan glida isär.

    balk = smal i BÅDA de andra leden (näst längsta <= 1 m): en planka, en balk, en taknock, en
    skyltbräda. En vägg (3,0 m) eller en dörr är det inte.
    """
    hörn = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    led = sorted((max(p[i] for p in hörn) - min(p[i] for p in hörn), i) for i in range(3))
    return led, led[2][1], (led[2][0] >= 3.0 * led[1][0] and led[1][0] <= 1.0)

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

    ## FIBERRIKTNINGEN. Alex 2026-10-14: "texturen sitter på fel ledd längs skyltar och balkar".
    ## Kubprojektionen ger varje yta världsaxlar, och då blir V alltid "upp" — en VÅGRÄT balk fick
    ## därför ådringen tvärs över i stället för längs med, medan stående plank blev rätt av sig
    ## själva. Plattans ådring ligger i V, så för en balk ska V byta plats med balkens längdaxel.
    ##
    ## VAD ÄR EN BALK? MÄTT på scenen: en lång vägg (12 x 3 x 0,3) och en skyltbräda (2,3 x 0,6 x
    ## 0,1) har nästan samma förhållande mellan längsta och näst längsta led (4,0 mot 3,8), så
    ## förhållandet ensamt skiljer dem inte — och en vägg ska behålla stående plank. En balk är smal
    ## i BÅDA de andra leden (näst längsta <= 1 m), det är en vägg eller en dörr inte. Mätt på
    ## scenen: skyltbrädan 0,6 m (balk), tavernaväggen 3,0 m (inte balk).
    hörn = [M @ Vector(c) for c in obj.bound_box]
    led, fiber, balk = balkmått(obj)
    fiber_v = Vector((0.0, 0.0, 0.0))
    fiber_v[fiber] = 1.0

    for poly in mesh.polygons:
        n = (inv @ poly.normal).normalized()
        if abs(n.z) >= max(abs(n.x), abs(n.y)):
            a, b = 0, 1
        elif abs(n.x) >= abs(n.y):
            a, b = 1, 2
        else:
            a, b = 0, 2
        ## V följer fibern när fibern ligger i ytans plan. En ändyta (normalen längs fibern) har
        ## inget att vrida; ett snedtak har ingen fiber (tak är inte balkar) och rörs inte.
        if balk and a == fiber:
            a, b = b, a
        if max(abs(n.x), abs(n.y), abs(n.z)) <= 0.999:
            # Sned yta: basen i ytans eget plan, annars sträcks mönstret.
            axel = min(range(3), key=lambda i: abs(n[i]))
            e = Vector((0.0, 0.0, 0.0))
            e[axel] = 1.0
            u = (e - n * e.dot(n)).normalized()
            v = n.cross(u)
            ## Samma fiberregel på en sned yta: en avsmalnande stam och ett vridet fackelhandtag har
            ## bara sneda sidoytor, och där blev V vågrät av sig själv (mätt: 28 balkar kvar efter
            ## den raka grenen ovan). Fibern projiceras i ytans plan och blir V; U vinkelrät mot den.
            if balk:
                f = fiber_v - n * fiber_v.dot(n)
                if f.length > 1e-6:
                    v = f.normalized()
                    u = n.cross(v)
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
    ## FONT/KURVA har inga polygoner — skyltbokstäverna är TextCurve-objekt och föll förut här
    ## (`AttributeError: 'TextCurve' object has no attribute 'polygons'`).
    for poly in getattr(obj.data, "polygons", ()):
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
    bg = {"tak": 0, "sten": 0, "antal": 0, "mur_pa_tak": 0}
    MUR_ORD = ("wall", "crenel", "castle", "tower", "merlon")
    ## BAKLÄNGES: ett TAKMATERIAL som inte fick en takplatta. Det var den här vägen felet gick
    ## (Väverskans vasstak -> träplatta), och den hade ingen räknare.
    tak_pa_mur = []
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
            ## BALKPLATTAN I STÄLLET FÖR PLANKVÄGGEN, för allt trä som är en balk (planka, taknock,
            ## skyltbräda): virke.png/skylt.png är plankväggar med 12 brädskarvar i U, och på en 5,2 m
            ## list blir U höjden, alltså ~36 skarvar längs balken — "40 på höjden avsågade och
            ## ihopklistrade". Bara de två plankkategorierna byts; kanter (Ram) och bokstäver
            ## (Ljus Varm) ligger kvar på sina platta plattor.
            if balkmått(obj)[2]:
                category = {"Wood": "Wood Beam", "Skylt": "Skylt Board"}.get(category, category)
            assign_material(obj, MATERIALS[category])
            if obj.get("uv_keep") and obj.data.uv_layers:
                ## ALEX ÄGER UV:N. Objektet bär en egen vinkel, satt för hand i UV-editorn, och då
                ## rör skriptet varken UV-lagret eller dess namn — sätt_uv skulle skriva över vinkeln
                ## och dessutom ta bort alla andra lager. Flaggan är en custom property (uv_keep =
                ## True) på objektet, så den följer med i .blend och syns i Properties-panelen.
                print("UV behållen (Alex' egen vinkel): %s" % obj.name)
            else:
                sätt_uv(obj)
            counts[category] = counts.get(category, 0) + 1
            per_material[ursprung] = per_material.get(ursprung, 0) + 1
            if källa == "namn":
                rad = omappade.setdefault(ursprung, [category, 0])
                rad[1] += 1
            if ursprung and ursprung.startswith("Roof_") and category not in ("Terracotta Roof", "Slate Roof", "Purple Roof"):
                tak_pa_mur.append((obj.name, ursprung, category))
            if "bg" in obj.name.lower():
                bg["antal"] += 1
                if category == "Stone":
                    bg["sten"] += 1
                elif category in ("Terracotta Roof", "Slate Roof"):
                    bg["tak"] += 1
                    # EN MUR SKA INTE HA EN TAKPLATTA. Räknaren är grinden som saknades: felet
                    # (BG_Wall_Crenel/BG_Castle_Wall på tegel) hade fallit här i stället för att
                    # upptäckas på en bild.
                    if any(k in obj.name.lower() for k in MUR_ORD):
                        bg["mur_pa_tak"] += 1
            if i % 25 == 0:
                print(f"Pixel texturing: {i}/{len(meshes)} objects...")
        except Exception as e:
            print(f"[WARN] Skipped {obj.name}: {e}")

    ## SKYLTBOKSTÄVERNA. De är FONT-objekt, inte meshar, och loopen ovan går bara över `meshes` — så
    ## bokstäverna stod helt utan platta (mätt via bryggan på den texturerade filen: Sign_*_Txt ->
    ## None, sex skyltar, medan brädan runtom fick PX_Wood). De får skyltens guldplatta här.
    texter = [o for o in bpy.context.scene.objects
              if o.type in ("FONT", "CURVE") and o.name.lower().endswith("_txt")]
    for o in texter:
        assign_material(o, MATERIALS["Ljus Varm"])
    if texter:
        counts["Ljus Varm (skylttext)"] = len(texter)
        print("Sign lettering: %d FONT objects -> %s" % (len(texter), TEXTURES["Ljus Varm"]))

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
    print("objects %d, on a roof plate %d, on the stone plate %d, WALL/TOWER on a roof plate %d" %
          (bg["antal"], bg["tak"], bg["sten"], bg["mur_pa_tak"]))
    if bg["mur_pa_tak"]:
        print("FEL: %d background WALL/TOWER objects sit on a roof plate (a roof tile on a wall)" %
              bg["mur_pa_tak"])
    print("\n=== ROOF MATERIAL ON A WALL PLATE (the other direction) ===")
    print("roof-material objects NOT on a roof plate: %d" % len(tak_pa_mur))
    for namn_, ursprung_, kategori_ in tak_pa_mur[:20]:
        print("   %-30s %-14s -> %s" % (namn_, ursprung_, kategori_))
    if tak_pa_mur:
        print("FEL: %d objects with a ROOF material sit on a wall plate (a wall plate on a roof)" %
              len(tak_pa_mur))

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
            "roof_material_on_wall_plate": [t[0] for t in tak_pa_mur],
        }, f, indent=1, sort_keys=True)
    print("wrote %s" % RAPPORT)
    print("Save the .blend, then export to glTF (.glb) for Godot.")

main()
