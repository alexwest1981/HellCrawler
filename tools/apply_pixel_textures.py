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

## FÖNSTREN SOM LYSER. Alex 2026-10-14: "Rutorna ... de skall ha lätt sken ur sig, som om det finns
## något ljus som brinner där inne då det skall vara kväll ute." Spelet HAR ett kvällsläge (by_3d.gd:
## nattljuset, nattvarianten), och där syns bara det materialet SJÄLV skickar ut. Mätt på glbn före
## den här ändringen: emissiveFactor=None och emissiveTexture=nej på båda fönsterplattorna — rutorna
## var alltså helt beroende av solljuset och slocknade på kvällen.
## EFFEKT är ratten: 1,0 = plattans egen ljusstyrka. Högre värde ger överskott och, om Godot-scenens
## miljö har glow på, en blomning runt rutan.
GLÖDER = ("Window Warm", "Window Bright", "Ljusglöd")
EFFEKT = 1.0
ISLAND_MARGIN = 0.015
REPLACE_EXISTING_MATERIALS = True
## Rutans storlek i meter. En ruta = en hel 512-platta, så 1,0 m ger 512 px per meter — samma täthet
## som projektets egna plattor (tools/gen_tiles_alex.py mätte 512 px/m).
TILE_METER = 1.0

## EN RUTA ÄR INTE ALLTID EN METER. MÄTT 15/10: vattenplattan är 1024x1024 och kaklad en gång per
## meter blev det 42 upprepningar över den 42 m breda ytan — renderingen såg ett galler: "för litet
## och för tätt, tiled för många gånger". Konceptbildens eget vatten ligger på 77 px/m, alltså en
## platta per 14 m: tre upprepningar och 73 px/m, samma klass som referensen. Byns egna plattor
## lämnas på TILE_METER — de är mätta och tunade.
RUTA_METER = {"Vatten": 14.0}


def ruta_meter(category):
    """Rutans storlek i meter för en kategori. Undantagen står i RUTA_METER."""
    return RUTA_METER.get(category, TILE_METER)

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
    ## LAMPORNA GLÖR. Alex 15/10: "se till att alla som heter Bulb är light emitters istället för en
    ## fysisk plopp". Egen kategori (inte "Ljus Varm") så att skyltbokstäverna inte tänds på köpet —
    ## samma bild, eget material. Emissionen kommer ur GLÖDER nedan.
    "Ljusglöd": "ljus_varm.png",
    ## FANORNA UR KONCEPTBILDEN. Alex 15/10 och bilden: två fanor ovanför porten — röd till
    ## vänster, blå med guldkant och gul lilja till höger. Rutorna mättes fram i byn.png
    ## (blå x 1993..2030 y 433..552, röd x 1890..1942 y 458..532) och skärs av
    ## tools/gen_banerplattor.py. Plattorna behåller fanans eget format; sätt_uv lägger hela
    ## plattan över ytan, så inget sträcks.
    "Baner Blå": "baner_bla.png",
    "Baner Röd": "baner_rod.png",
    ## VATTNET. Alex 15/10: "Cliff_Face, kan vi byta den mot en vattentextur". Ingen vattenplatta
    ## fanns i projektet (atlasen har 44 plattor utan vatten, tiles-paketens *_vatten är
    ## golvsprickor och mossväggar). Källan är hans eget vattenpaket i ~/Downloads/Textures/Water,
    ## skuret av tools/gen_vattenplatta.py: den mest kaklingsbara rutan, kantblandad så fogen
    ## försvinner (mätt 8,60/5,79 -> 0,1 innan den skrivs).
    "Vatten": "vatten.png",
}
## HELA PLATTAN ÖVER YTAN, UTAN ATT GLÖDA. GLÖDER styr både mappningen (sätt_uv) och
## emissionen (make_material). En fana ska ha hela plattan över sin egen yta men är tyg och
## ska inte sända ut ljus — därför en egen lista som bara mappningen läser.
## Vattnet hör också hit: klippan är 42,22 x 3,01 m och plattan är gjord i samma 14:1-format, så
## hela plattan läggs över ytan utan en enda upprepning. Mätt tre gånger: en liten ruta ur en
## strukturerad vattenyta kan inte kaklas 42 gånger utan att skarven eller spegelvändningen syns.
## Vatten ligger INTE här: plattan är sömlös (mätt 0,90/1,04 ur 8_diffuseOriginal.bmp) och ska
## kaklas i världskoordinater, en platta per meter — 1024 px per meter över hela den 42 m breda
## ytan, mot 37 px per meter när en enda bild drogs ut över allt. Cylinderrenderingen N.png, som
## först användes, har fog 9,8..18,2 i radled; det var banden.
HELA_YTAN = GLÖDER + ("Baner Blå", "Baner Röd")

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
    ## Fönstren lyser av sig själva: plattans bild blir materialets emission, så rutan skickar ut sitt
    ## eget ljus i kvällsläget i stället för att bara reflektera solen. Se GLÖDER/EFFEKT högst upp.
    if name in GLÖDER:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = EFFEKT
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
    ## JUVELERARENS TOPPFONSTER: ramen ÄR rutan. Alex 15/10: "Sen heter det i det här fallet
    ## Jeweler_Top_Win_frame som skall bytas ut mot fönster. Det ser inte bra ut med plankor som ruta."
    ## MÄTT: Jeweler_Top_Win_Frame är en SOLID låda 0,88 x 1,01 m på y 0,71..0,85, och glaset ligger
    ## BAKOM den på y 0,73..0,79 — ramens framsida skymmer glaset helt. Det man ser i öppningen är
    ## alltså ramens egen PX_Ram-yta (mörk planka), och spröjsen (Bar_H/Bar_V, PX_Wood Beam) ligger
    ## 3 cm framför. Plattan blir den fyrdelade fönsterrutan med varmt ljus — samma som sex av de andra
    ## fönstren — och den bär sin egen ram, så öppningen läser som ett fönster. GLÖDER-regeln ger den
    ## hela plattan över sin egen yta (annars visade den en 1-metersruta ur världen, se sätt_uv).
    "Jeweler_Top_Win_Frame": "Window Warm",
    ## RESTEN AV FÖNSTREN: samma sak som juvelerarens toppfönster. MÄTT 15/10 i kedjans fil — för alla
    ## fem ligger RAMEN som en solid låda med framsidan 2 cm FRAMFÖR glaset, så det man ser i öppningen
    ## är ramens egen PX_Ram-yta (mörk planka) medan glaset bakom skyms helt:
    ##   Tavern_Top_Win_Frame      1,01 x 0,14 x 1,01 m  y 0,67..0,81  glaset y 0,69..0,75
    ##   BG_House_Left1_Win_Frame  0,71 x 0,14 x 0,81 m  y 4,31..4,45  glaset y 4,33..4,39
    ##   BG_House_Left2_Win_Frame  0,71 x 0,14 x 0,81 m  y 4,01..4,15  glaset y 4,03..4,09
    ##   BG_House_Right_Win_Frame  0,71 x 0,14 x 0,81 m  y 4,01..4,15  glaset y 4,03..4,09
    ##   Weaver_Win_Frame          0,64 x 0,14 x 0,64 m  y 0,41..0,55  glaset y 0,43..0,49
    ## Alla fem glas bär PX_Window Warm, alltså får ramarna samma platta — då läser öppningen som ett
    ## fönster och spröjsen (Bar_H/Bar_V, PX_Wood Beam) ligger kvar framför som riktiga spröjsar.
    ## JUVELERARENS SKYLTFONSTER. MÄTT 15/10: Jeweler_Shop_Win_Frame är 1,55 x 0,18 x 1,35 m på
    ## y 0,69..0,87, glaset (Jeweler_Shop_Win_Glow, PX_Window Bright) ligger på y 0,69..0,79 alltså
    ## innanför — samma mönster som de sex andra. Ramen är nästan kvadratisk, så den fyrdelade
    ## fönsterplattan passar bättre än det smala tvådelade glaset bakom.
    "Jeweler_Shop_Win_Frame": "Window Warm",
    ## KORNISCHARNAS PLATTA. Alex 15/10: "Gate_Cornice_Lower och Upper — deras UV på fel ledd, det ser ut
    ## som vågformat brun lera, jag vill ha så man ser träfibrer som i en stolpe." MÄTT: UV:n ligger RÄTT
    ## (V = (1,0,0), spann 5,20 m på alla sex ytorna), men plattan virke_balk.png är en 81 px remsa töjd
    ## 6,3x i sidled — kolumnspridning 12,17 mot radspridning 14,29. På en smal stolpe (U = 0,16 m) syns
    ## bara en remsa av den, därför ser stolparna bra ut; på kornischen (U = 0,55 m) syns mer än halva
    ## plattan och då blir de utsmetade banden "lera". Renderat rakt framifrån med båda plattorna och
    ## läst av bilden: virke.png ger "tydliga horisontella fibrer och ådring längs balken, fogarna ser ut
    ## som riktiga plankfogar". Bara de två kornischarna byts — stolparna behåller balkplattan de ser bra
    ## ut med.
    "Gate_Cornice_Lower": "Wood",
    "Gate_Cornice_Upper": "Wood",
    ## FANORNA. MÄTT 15/10: Gate_Shield_Base (0,68 x 0,82 m) och Gate_Shield_Rim
    ## (0,50 x 0,62 m) bar PX_Dark Stone — en grågrön stenruta på en sköld. Konceptbilden har
    ## i stället två fanor. Rim = fanans fält (bilden, hela plattan över ytan), Base = bara
    ## kanten runt om, alltså guld. Den röda är en kopia av paret, flyttad till vänster.
    ## KLIPPVÄGGEN BLIR VATTEN. MÄTT 15/10: Cliff_Face är 42,22 x 5,40 x 3,01 m (x -21,11..21,11)
    ## och bar PX_Mörk Zon. Ytan upprepas 42 gånger, därför måste plattan vara sömlös.
    "Cliff_Face": "Vatten",
    "Gate_Shield_Rim": "Baner Blå",
    "Gate_Shield_Base": "Ljus Varm",
    "Gate_Shield_L_Rim": "Baner Röd",
    "Gate_Shield_L_Base": "Ram",
    "Tavern_Top_Win_Frame": "Window Warm",
    "BG_House_Left1_Win_Frame": "Window Warm",
    "BG_House_Left2_Win_Frame": "Window Warm",
    "BG_House_Right_Win_Frame": "Window Warm",
    "Weaver_Win_Frame": "Window Warm",
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
    ## LAMPORNA. MÄTT 15/10: 30 klossar (Bulb_Bot_0..10, Bulb_Top_0..10, Bulb_L_1..4, Bulb_R_1..4,
    ## 0,10 x 0,11 x 0,11 m) bär PX_Stone och sitter som en ram runt EXIT-skylten (x 9,98..12,42,
    ## z 1,38..2,52) — en grå "plopp" i stället för ljus. De får Ljusglöd-plattan och glöder.
    ## Själva ljuset finns redan: Exit_Sign_Glow (POINT, 90,0) står i ramens mitt.
    if "bulb" in n:
        return "Ljusglöd", "namn (lampa)"
    ## SKYTTEGLUGGARNA. MÄTT 15/10: de fyra Gate_Slit_* (0,28 x 0,15 x 0,72 m) bar PX_Stone, alltså samma
    ## platta som tornet — ingen öppning syns. De är själva gluggen och ska vara mörka (bildens mörka zon).
    if n.startswith("gate_slit"):
        return "Mörk Zon", "namn (skytteglugg)"
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
    längst, näst, tunn = led[2][0], led[1][0], led[0][0]
    fiber = led[2][1]
    balk = längst >= 3.0 * näst and näst <= 1.0
    fiber_v = Vector((0.0, 0.0, 0.0))
    fiber_v[fiber] = 1.0
    ## SNEDA BALKAR (takstolar, sparrar). BBoxen ser ingen balk: Tavern_Rafter_L är 2,37 x 0,14 x 2,12 m,
    ## så näst längsta led är 2,12 och regeln ovan säger "vägg". MÄTT 15/10: 14 takstolar låg kvar på
    ## PX_Wood med ådringen tvärs över sin egen lutning (Alex: "balken som lutar upp mot taknocken har
    ## sin textur längst fel led ... de skall gå längs lutningen"). Det som skiljer en sned balk från en
    ## plan yta i boxen är den TUNNA leden: balken är tunn (<= 0,35 m) och de två andra lederna är nästan
    ## lika stora (>= 0,8 av varandra). Fibern är då diagonalen mellan dem, i världsrymden.
    if not balk and tunn <= 0.35 and längst >= 1.0 and näst >= 0.8 * längst:
        balk = True
        fiber_v = Vector((0.0, 0.0, 0.0))
        fiber_v[led[2][1]] = 1.0
        fiber_v[led[1][1]] = 1.0
        fiber_v.normalize()
    ## TAKFALLEN. Alex 15/10: "Du har en som är liggande kant på taket, ta t.ex. Tavern_Slope_L ...
    ## Lutningen är -39,428 grader. Den smala delen som går längs den lutningen har textur som går
    ## rakt upp." MÄTT på Tavern_Slope_L: skivan är 3,09 x 3,60 x 0,12 m snedställd 39,4 grader.
    ## TAKYTAN (11,1 m2) är sned och tog redan den sneda grenen -> V längs lutningen, rätt. Men
    ## GAVELKANTEN (2,46 x 2,06 m, normal (0,1,0)) är AXELRÄT, hamnade i den raka grenen med a,b = (X, Z)
    ## och fick därför V = världens Z: ådringen rakt upp, tvärs över lutningen. Lutningen räknas ur
    ## objektets STÖRSTA ytas normal — V ska ligga i den ytans plan, i den riktning som stiger mest —
    ## och sätt_uv låter takfall ta samma gren som sneda ytor, så kanten får V längs fallet i stället.
    if "slope" in obj.name.lower():
        inv = obj.matrix_world.to_3x3().inverted_safe().transposed()
        störst = max(obj.data.polygons, key=lambda p: p.area)
        nb = (inv @ störst.normal).normalized()
        upp = Vector((0.0, 0.0, 1.0))
        f = upp - nb * upp.dot(nb)
        if f.length > 1e-6:
            balk = True
            fiber_v = f.normalized()
    return led, fiber, balk, fiber_v

def sätt_uv(obj, category=None):
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
    ## HÄMTA OM LAGRET EFTER BORTTAGNINGARNA. MÄTT 15/10: `uv_layers.remove()` gör den gamla
    ## referensen ogiltig, och `mesh.uv_layers.active = uv` med en död referens SEGFAULAR Blender
    ## (kraschlogg: "line 527 in sätt_uv", core-dump 4006968, 139 = SIGSEGV). Fyra objekt i scenen har
    ## flera UV-lager, så raden körs varje gång — och samma rad kördes när Alex' egen Blender dog mitt i
    ## kedjan i morse. Att hämta om lagret efteråt tar bort hela problemet.
    uv = mesh.uv_layers.get(UV_NAME) or mesh.uv_layers[0]
    mesh.uv_layers.active = uv
    uv.active_render = True

    M = obj.matrix_world
    inv = M.to_3x3().inverted_safe().transposed()
    vrld = [M @ v.co for v in mesh.vertices]
    hörn = [M @ Vector(c) for c in obj.bound_box]

    ## FÖNSTRET SKA VISA HELA PLATTAN. Mätt 15/10: window_four_pane.png ÄR ett helt fönster (glaset
    ## 94 % av bilden, ytterramen bara 4 px), men rutans UV kom ur VÄRLDENS koordinater delat med 1,0 —
    ## så Tavern_Top_Win_Glass (0,85 m bred, på x -4,2, z 3,65) visade en 0,85 m-bildruta ur plattan och
    ## inte fönstret (Alex: "fönstret ovanför skylten är ännu fel" — det läste som plank). Rutorna är små
    ## och sitter på olika ställen i världen, så var och en måste få HELA plattan över sin egen yta.
    ##
    ## MÄTT 15/10: raden läste GLÖDER, men HELA_YTAN skapades för att skilja mappningen från
    ## emissionen — och bytet glömdes här. Följden var att varken vattnet eller fanorna fick hela
    ## plattan: klippan kaklade sin 14:1-platta i världskoordinater (42 upprepningar) och fanorna
    ## visade en 0,2 m-remsa ur sin. Emissionen ligger kvar på GLÖDER (make_material).
    if category in HELA_YTAN:
        lo = Vector([min(p[i] for p in hörn) for i in range(3)])
        stor = [max(p[i] for p in hörn) - lo[i] for i in range(3)]
        for poly in mesh.polygons:
            n = (inv @ poly.normal).normalized()
            if abs(n.z) >= max(abs(n.x), abs(n.y)):
                a, b = 0, 1
            elif abs(n.x) >= abs(n.y):
                a, b = 1, 2
            else:
                a, b = 0, 2
            for li in poly.loop_indices:
                co = vrld[mesh.loops[li].vertex_index]
                uv.data[li].uv = ((co[a] - lo[a]) / max(stor[a], 1e-6),
                                  (co[b] - lo[b]) / max(stor[b], 1e-6))
        return

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
    led, fiber, balk, fiber_v = balkmått(obj)

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
        if max(abs(n.x), abs(n.y), abs(n.z)) <= 0.999 or "slope" in obj.name.lower():
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
                uv.data[li].uv = (co.dot(u) / ruta_meter(category), co.dot(v) / ruta_meter(category))
            continue
        for li in poly.loop_indices:
            co = vrld[mesh.loops[li].vertex_index]
            uv.data[li].uv = (co[a] / ruta_meter(category), co[b] / ruta_meter(category))

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

    ## FANORNA PÅ PORTEN — FÖRE KLASSNINGEN. Konceptbilden har två fanor, modellen ett par.
    ## Paret kopieras och kopian flyttas till vänster om porten medan originalet flyttas till
    ## höger, så de flankerar valvet som i bilden. MÅTT: låg kopian efter klassningsslingan
    ## ärvde de nya objekten originalets plattor (PX_Ljus Varm + PX_Baner Blå) i stället för
    ## sina egna OVERRIDE-värden — kopian gjordes efter det att main() redan gått igenom
    ## scenen. Båda objekten i paret måste flyttas: först flyttades bara ramen, och då stod
    ## den blå fanan delad i två halvor på olika x.
    if bpy.data.objects.get("Gate_Shield_L_Base") is None:
        bas = bpy.data.objects.get("Gate_Shield_Base")
        rim = bpy.data.objects.get("Gate_Shield_Rim")
        if bas and rim:
            bpy.ops.object.select_all(action="DESELECT")
            for o in (bas, rim):
                o.select_set(True)
            bpy.context.view_layer.objects.active = bas
            bpy.ops.object.duplicate()
            for kopia in bpy.context.selected_objects:
                kopia.name = ("Gate_Shield_L_Base" if "Base" in kopia.name else "Gate_Shield_L_Rim")
                m = kopia.matrix_world.copy()
                m.translation.x = 0.95
                kopia.matrix_world = m
            for o in (bas, rim):
                m = o.matrix_world.copy()
                m.translation.x = 2.05
                o.matrix_world = m
            bpy.context.view_layer.update()
            print("fanorna: paret kopierat till vänster, originalet flyttat till höger")

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
            ## MÄTT 15/10: kornischarna blev kvar på PX_Wood Beam trots att de stod i OVERRIDE. Raden
            ## nedan kör EFTER klassningen och skrev om "Wood" -> "Wood Beam" för allt som är en balk,
            ## alltså även ett uttryckligt val. Felet gällde hela klassen: vilket objekt som helst i
            ## OVERRIDE som samtidigt är en balk blev överskrivet. Bara heuristikens eget svar byts.
            if balkmått(obj)[2] and källa != "override (namn)":
                category = {"Wood": "Wood Beam", "Skylt": "Skylt Board"}.get(category, category)
            assign_material(obj, MATERIALS[category])
            if obj.get("uv_keep") and obj.data.uv_layers:
                ## ALEX ÄGER UV:N. Objektet bär en egen vinkel, satt för hand i UV-editorn, och då
                ## rör skriptet varken UV-lagret eller dess namn — sätt_uv skulle skriva över vinkeln
                ## och dessutom ta bort alla andra lager. Flaggan är en custom property (uv_keep =
                ## True) på objektet, så den följer med i .blend och syns i Properties-panelen.
                print("UV behållen (Alex' egen vinkel): %s" % obj.name)
            else:
                sätt_uv(obj, category)
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
    ## LYKTORNA SER UT SOM STEN. Alex 15/10: "Gaten har 8 lyktor ... alla ser ut som sten, de kanske
    ## behöver tas bort helt och sättas in som eld i spelmotorn istället." MÄTT: elden bär plattan
    ## PX_Stone — Torch_Flame_* och Tavern_Lantern_* ligger på stenplattan, och sken är det ingen som
    ## ser. Ljusen finns redan i motorn (Torch_Light_0..3 + Tavern_Warm_Glow), så mesherna göms precis
    ## som svärden: de försvinner ur vyn och ur varje export, medan fackelhandtagen (PX_Wood Beam)
    ## står kvar som fästen. Ett eld-paket finns inte i paketet (eld saknas helt, 10 objekt) — därför
    ## eld i motorn och inte en platta.
    släckta = []
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        n = o.name.lower()
        if n.startswith("torch_flame") or n.startswith("tavern_lantern"):
            o.hide_render = True
            o.hide_set(True)
            släckta.append(o.name)
    if släckta:
        print("gömda ljusalternativ (eld i motorn i stället): %d objekt, %s" % (
            len(släckta), ", ".join(sorted(släckta)[:6])))

    ## DÖRRAR DÄR DET BARA ÄR VÄGG. Alex 15/10: smedjans högra framsida (där fyra svärd hängde — "de bars
    ## jag menar hos smeden heter tydligen Smith_Sword_0 till 3, jag hade hellre haft en dörr in till
    ## smedjan där") och tavernan ("mellan pelarna under bar-skylten hade det behövt en dörr, det är bara
    ## vägg där"). Modellen HAR dörren — Jeweler_Door, 0,68 x 1,82 m i PX_Wood, botten 0,11 m över marken
    ## — så den lånas dit i stället för att bygga ny geometri. Skalningen är gratis: plattan projiceras i
    ## världskoordinater, så brädbredden är 1 m hur stor dörren än är. y = fästets y minus 0,02 (kameran
    ## tittar från -y, så mindre y är närmare). Svärdens fyra järnbitar göms; pelarna är arkitektur och
    ## står kvar. Idempotent: en tidigare kopia tas bort först, annars staplas dörrarna per körning.
    mall = bpy.data.objects.get("Jeweler_Door")
    svärd = [o for o in (bpy.data.objects.get("Smith_Sword_%d" % i) for i in range(4)) if o is not None]
    ## PELARNAS NAMN ÄR INTE STABILA: modellen har "Tavern_Pillar_-3.1500000000000004" (flyttal i
    ## namnet), så uppslagning på "%.2f" hittar ingen pelare och dörren blir aldrig byggd — MÄTT 15/10:
    ## en körning skapade ingen taverna-dörr alls medan den gamla kopian stod kvar. Leta därför på
    ## namnförledet, sortera i x, och ta den öppning som rymmer en dörr (>= 1,2 m) och ligger närmast
    ## Bar-skylten. Modellen har fyra pelare med öppningarna 1,5 / 1,4 / 0,8 m.
    dörrar = []
    if mall is not None and svärd:
        dörrar.append(("Smith_Door_Door", svärd, mall.dimensions.x, mall.dimensions.z, True))
    pelare = sorted((o for o in bpy.context.scene.objects if o.name.startswith("Tavern_Pillar")),
                    key=lambda o: o.matrix_world.translation.x)
    skylt = bpy.data.objects.get("Sign_Bar_2_Board")
    par = None
    for v, h in zip(pelare, pelare[1:]):
        gap = h.matrix_world.translation.x - v.matrix_world.translation.x
        if gap < 1.2:
            continue
        avst = abs((v.matrix_world.translation.x + h.matrix_world.translation.x) / 2.0
                   - (skylt.matrix_world.translation.x if skylt else -1.85))
        if par is None or avst < par[3]:
            par = (v, h, gap, avst)
    if mall is not None and par is not None:
        dörrar.append(("Tavern_Door_Door", [par[0], par[1]], par[2] - 0.32,
                       par[0].dimensions.z - 0.1, False))
    for namn, fästen, bredd, höjd, göm_fästen in dörrar:
        ## ALEX ÄGER DÖRREN. MÄTT 15/10: blocket raderade ALLA kopior (även den exakta) och byggde en
        ## ny på en räknad plats varje körning — Alex: "Kan du snälla sluta flytta på dörrarna jag
        ## satt på rätt ställe sen?" Samma regel som för balkplattan och OVERRIDE: ett uttryckligt val
        ## vinner över heuristiken. Finns dörren lämnas den och dess fästen orörda; bara en SAKNAD
        ## dörr byggs. Kvarblivna ".001"-dubbletter (Blender lägger på suffix när namnet är taget)
        ## städas fortfarande bort — de är aldrig hans.
        for gammal in [o for o in bpy.data.objects if o.name.startswith(namn + ".")]:
            bpy.data.objects.remove(gammal, do_unlink=True)
        if bpy.data.objects.get(namn) is not None:
            print("dörr: %s finns redan, lämnas orörd" % namn)
            continue
        ny = mall.copy()
        ny.data = mall.data.copy()
        ny.name = ny.data.name = namn
        bpy.context.scene.collection.objects.link(ny)
        ny.matrix_world = mall.matrix_world.copy()
        ## SKALAN. matrix_world bär hela transformen, så skalningen sätts efter translationen (den
        ## ordningen är den trygga). OBS: obj.dimensions och obj.bound_box är CACHADE — utan en
        ## uppdatering visar de före skalningen (MÄTT 15/10: dörren var 1,88 x 2,20 och scale 2,765 medan
        ## dimensions påstod 0,68 x 1,82). Tvinga därför en uppdatering innan något mäts eller skrivs ut.
        ny.matrix_world.translation = Vector((
            sum(o.matrix_world.translation.x for o in fästen) / len(fästen),
            fästen[0].matrix_world.translation.y - 0.02,
            0.11 + höjd / 2.0))
        ny.scale = (bredd / mall.dimensions.x, 1.0, höjd / mall.dimensions.z)
        bpy.context.view_layer.update()
        sätt_uv(ny, "Wood")
        if göm_fästen:
            for o in fästen:
                o.hide_render = True
                o.hide_set(True)
        print("dörr: %s i %s, verkligt mått %s m%s" % (
            namn, tuple(round(v, 2) for v in ny.matrix_world.translation),
            tuple(round(v, 2) for v in ny.dimensions),
            ", %d fästen gömda" % len(fästen) if göm_fästen else ""))

    ## ÄSSJAN: KARVA HÅLET I DEN YTTRE STENPLATTAN. Alex 15/10: "jag skulle vilja karva ett hål in här
    ## ... för det e trots allt här de hettar upp stålet". Modellen är SCRIPT-GENERERAD — MÄTT: 1521 av
    ## 1828 mesh-objekt har exakt 8 hörn (kuber ur en generator), noll modifierare kvar, namnen är
    ## loop-genererade (Roof_TileL_1_5) — men .blend är RESULTATET: objekten är riktiga meshar, så en
    ## boolean går bra. Forge_Fire_Outer är 0,82 x 0,16 x 0,72 m, alltså en tunn platta: hålet skär rakt
    ## igenom och visar det mörka innandömet. Elden finns redan i scenen (Forge_PointLight, 160,0) och
    ## lyser ut genom hålet. Skäraren tas bort efteråt — den ska inte med i exporten. MÄTT efter:
    ## 6 ytor/8 hörn -> 12 ytor/16 hörn. Flaggan hal_karvat gör körningen idempotent (en andra körning
    ## på samma fil skär inte en gång till).
    ässja = bpy.data.objects.get("Forge_Fire_Outer")
    if ässja is not None and not ässja.get("hal_karvat"):
        h = [ässja.matrix_world @ Vector(c) for c in ässja.bound_box]
        mitt = sum(h, Vector((0.0, 0.0, 0.0))) / 8.0
        ## SKÄRAREN MÅSTE GÅ DJUPT. Första versionen skar bara plattans egen tjocklek (0,16 m), och då
        ## låg Forge_Arch_Frame 1 cm bakom — MÄTT: Alex såg "inte ett hål i väggen", bara en plan yta.
        ## Skäraren går nu från y 0,30 till 1,80: genom plattan (0,64–0,80) OCH 1 m in i
        ## Smith_Forge_Wing (0,80–3,00). Mätt djup efteråt: en stråle från framsidan stannar på y 1,80.
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(mitt.x, 1.05, mitt.z))
        skärare = bpy.context.active_object
        skärare.name = "Hal_Skarare"
        skärare.dimensions = (0.72, 1.5, 0.72)
        bpy.context.view_layer.update()
        for mål in (ässja, bpy.data.objects.get("Forge_Arch_Frame"),
                    bpy.data.objects.get("Smith_Forge_Wing"),
                    bpy.data.objects.get("Forge_Fire_Core")):
            if mål is None or mål.get("hal_karvat"):
                continue
            ## MARKERA OBJEKTET ORDENTLIGT. bpy.ops.object.modifier_apply arbetar på det AKTIVA objektet,
            ## och om något annat står markerat kan den slå fel UTAN att säga till — MÄTT 15/10:
            ## Forge_Arch_Frame (som ligger 1 cm bakom plattan och blockerade hela hålet) förblev
            ## 6 ytor/8 hörn efter en boolean som borde gett 12/16, medan grannen direkt efter blev
            ## rätt. Avmarkera allt, markera målet, sätt det aktivt — då tar operationen.
            bpy.ops.object.select_all(action="DESELECT")
            mål.select_set(True)
            bpy.context.view_layer.objects.active = mål
            mod = mål.modifiers.new("Hal", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.object = skärare
            mod.solver = "EXACT"
            bpy.ops.object.modifier_apply(modifier="Hal")
            bpy.context.view_layer.update()
            mål["hal_karvat"] = True
            print("ässjan: hål karvat i %s (%d ytor, %d hörn)" % (
                mål.name, len(mål.data.polygons), len(mål.data.vertices)))
        bpy.data.objects.remove(skärare, do_unlink=True)
    ## ELDEN IN I HÄRDEN. Alex 15/10: hålet är till för att "lägga in eld i spelmotorn där". MÄTT:
    ## Forge_PointLight stod på y 0,10 — 54 cm FRAMFÖR väggen (plattans framkant ligger på 0,64), så
    ## den lyste på fasaden och hålet var svart och platt. Ljuset flyttas in i håligheten, mitt i den
    ## och 0,33 m in, så härden glöder inifrån och skenet faller ut genom öppningen. Positionen sätts
    ## varje körning (idempotent — samma tal varje gång) och styrkan rörs inte.
    if ässja is not None and ässja.get("hal_karvat"):
        lampa = bpy.data.objects.get("Forge_PointLight")
        h = [ässja.matrix_world @ Vector(c) for c in ässja.bound_box]
        mitt = sum(h, Vector((0.0, 0.0, 0.0))) / 8.0
        if lampa is not None:
            lampa.location = (mitt.x, mitt.y + 0.33, mitt.z)
            print("ässjan: elden flyttad in i härden: %s (styrka %.1f)" % (
                tuple(round(v, 2) for v in lampa.location), lampa.data.energy))

    ## PORTEN GENOM TORNET. Alex 15/10: "om du skulle öppna dörrarna till gaten så skulle du se rakt in
    ## i en mur, det måste vara öppet där" och "Gate_Slit-delarna skall ju egentligen vara urskurna ur
    ## tornet, så det ser ut som fönster". MÄTT: Gate_Recess_Dark (2,80 x 0,40 x 3,90 m, y 1,15..1,55) och
    ## Gate_Center_Mass (4,80 x 2,60 x 6,20 m, y 1,20..3,80) är SOLIDA block tvärs över portöppningen —
    ## öppnar man dörrarna ser man rakt in i stenen. Och de fyra Gate_Slit_* ligger som platta PX_Stone-
    ## skivor på y 1,10..1,25 utan urtag bakom. Båda skärs med boolean, precis som ässjan, och med samma
    ## fälla: markera målet och sätt det aktivt före modifier_apply, annars blir det en tyst no-op.
    port = bpy.data.objects.get("Gate_Recess_Dark")
    massa = bpy.data.objects.get("Gate_Center_Mass")
    if port is not None and not port.get("port_karvad"):
        # GÅNGEN: 2,40 x 3,45 m genom både den mörka väggen och hela tornmassan (y 0,90..4,10)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.50, 2.50, 1.72))
        skärare = bpy.context.active_object
        skärare.name = "Port_Skarare"
        skärare.dimensions = (2.40, 3.20, 3.45)
        bpy.context.view_layer.update()
        # GLUGGARNA: ett 0,30 x 0,90 x 0,74 m urtag bakom varje gluggplatta, 0,8 m in i tornet
        gluggar = []
        for g in [o for o in bpy.data.objects if o.name.startswith("Gate_Slit_")]:
            c = g.matrix_world.translation
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(c.x, 1.55, c.z))
            gs = bpy.context.active_object
            gs.name = "Glugg_Skarare"
            gs.dimensions = (0.30, 0.90, 0.74)
            gluggar.append(gs)
        bpy.context.view_layer.update()
        for mål in (port, massa):
            if mål is None or mål.get("port_karvad"):
                continue
            for bit in [skärare] + gluggar:
                bpy.ops.object.select_all(action="DESELECT")
                mål.select_set(True)
                bpy.context.view_layer.objects.active = mål
                mod = mål.modifiers.new("Port", "BOOLEAN")
                mod.operation = "DIFFERENCE"
                mod.object = bit
                mod.solver = "EXACT"
                bpy.ops.object.modifier_apply(modifier="Port")
                bpy.context.view_layer.update()
            mål["port_karvad"] = True
            print("porten: öppning karvad i %s (%d ytor, %d hörn)" % (
                mål.name, len(mål.data.polygons), len(mål.data.vertices)))
        for bit in [skärare] + gluggar:
            bpy.data.objects.remove(bit, do_unlink=True)

    ## GLUGGARNA SKA SYNAS SOM URTAG. MÄTT efter skärningen: plattan ligger kvar pa y 1,10..1,25 och
    ## skymmer hela urtaget — stralen stannar pa y 1,11, alltsa precis som fore. Den flyttas 0,45 m in
    ## sa tornets skurna kant bildar en karm runt en mork glugg, och urtaget (0,8 m djupt) blir synligt.
    ## Egen flagga: port_karvad ar redan satt av den korning som skar porten.
    for g in [o for o in bpy.data.objects
              if o.name.startswith("Gate_Slit_") and not o.get("glugg_indragen")]:
        m = g.matrix_world.copy()
        m.translation.y += 0.45
        g.matrix_world = m
        g["glugg_indragen"] = True
        print("gluggen: %s flyttad in till y %.2f" % (g.name, g.matrix_world.translation.y))

    ## FANORNA PÅ PORTEN. Konceptbilden har två, modellen ett par. Paret kopieras, kopian får
    ## den röda plattan och flyttas till vänster om porten; originalet flyttas till höger, så
    ## de flankerar valvet som i bilden. Sedan får båda paren fanans proportion (bilden är
    ## 1:3,2 respektive 1:1,4 medan objekten är 1:1,24) — annars klämmer hela-ytan-mappningen
    ## ihop bilden i sidled. Flaggan fana_matt gör att en andra körning inte skalar en gång till.
    if bpy.data.objects.get("Gate_Shield_L_Base") is None:
        bas = bpy.data.objects.get("Gate_Shield_Base")
        rim = bpy.data.objects.get("Gate_Shield_Rim")
        if bas and rim:
            bpy.ops.object.select_all(action="DESELECT")
            for o in (bas, rim):
                o.select_set(True)
            bpy.context.view_layer.objects.active = bas
            bpy.ops.object.duplicate()
            for kopia in bpy.context.selected_objects:
                kopia.name = ("Gate_Shield_L_Base" if "Base" in kopia.name else "Gate_Shield_L_Rim")
                m = kopia.matrix_world.copy()
                m.translation.x = 0.95
                kopia.matrix_world = m
            m = bas.matrix_world.copy()
            m.translation.x = 2.05
            bas.matrix_world = m
            print("fanorna: paret kopierat till vänster, originalet flyttat till höger")
    ## förhållandet = bildens proportion delad med objektets nuvarande (0,50 x 0,62 m = 1:1,24)
    for namn, falt, forhallande in (("Gate_Shield_Rim", (1993, 441, 2030, 546), 0.449),
                                    ("Gate_Shield_Base", (1993, 441, 2030, 546), 0.449),
                                    ("Gate_Shield_L_Rim", (1914, 458, 1944, 532), 0.512),
                                    ("Gate_Shield_L_Base", (1914, 458, 1944, 532), 0.512)):
        ob = bpy.data.objects.get(namn)
        if ob is None or ob.get("fana_matt"):
            continue
        ob.dimensions.x *= forhallande
        bpy.context.view_layer.update()
        ob["fana_matt"] = True
        print("  %-22s %5.2f x %5.2f m  (bilden %d x %d)" % (
            namn, ob.dimensions.x, ob.dimensions.z, falt[2] - falt[0] + 1, falt[3] - falt[1] + 1))

    ## FANORNAS PLATS. Absolut x, inte ett steg: då är körningen idempotent även när paret
    ## redan är kopierat (kopieblocket ovan hoppas över då, och positionen skulle annars aldrig
    ## rättas). MÄTT: efter första körningen stod den blå ramen på x 2,05 men fältet kvar på
    ## 1,50 — fanan var delad i två halvor.
    for namn, x in (("Gate_Shield_Base", 2.05), ("Gate_Shield_Rim", 2.05),
                    ("Gate_Shield_L_Base", 0.95), ("Gate_Shield_L_Rim", 0.95)):
        ob = bpy.data.objects.get(namn)
        if ob is None:
            continue
        m = ob.matrix_world.copy()
        m.translation.x = x
        ob.matrix_world = m
    bpy.context.view_layer.update()

    ## DET SVARTA STRECKET VID STRANDKANTEN - UTRETT, INTE ATGARDAT. MATT 15/10: renderingen
    ## visar ett rakt kolsvart streck dar vattnet moter byn. Det ar inte plattan (paketets morka
    ## overkant skalades bort och mats, 92 rader), inte en halighet (stralprov fran kamerans
    ## position traffar klippans framsida pa varje vinkel), och inte en nivaaskillnad: tre
    ## geometriska forsok - overkant 5 cm under marken, exakt i plan med marken (gav z-fighting),
    ## 2 mm under - lamnade strecket orort. Modellen far darfor sin egen hojd; kallan ar Alex
    ## session, sa klippan ar orord. Nasta steg: se den i Blender i Rendered-lage och mat vilken
    ## yta strecket faktiskt tillhor.

    print("Save the .blend, then export to glTF (.glb) for Godot.")

main()
