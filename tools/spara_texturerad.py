"""Packar in bilderna i .blend och sparar. Körs i SAMMA Blender-session som
tools/apply_pixel_textures.py (den sätter material, UV och packar varje bild för sig).

    blender -b <modell.blend> --python tools/apply_pixel_textures.py --python spara_texturerad.py -- <ut.blend>
"""
import bpy, sys

ut = sys.argv[sys.argv.index("--") + 1]
saknade = [i.name for i in bpy.data.images if i.source == 'FILE' and not i.packed_file]
print("bilder: %d, varav opackade: %s" % (len(bpy.data.images), saknade or "inga"))
if saknade:
    bpy.ops.file.pack_all()
    print("packade: %d" % len([i for i in bpy.data.images if i.packed_file]))
print("texturerade material: %d" % sum(
    1 for m in bpy.data.materials if m.use_nodes and
    any(n.type == 'TEX_IMAGE' for n in m.node_tree.nodes)))
## EEVEE: ray tracing ger kontakt-skuggor och AO i Rendered-läget, och den är INTE gratis i viewporten
## — men MÄTT kostar den nästan inget på den här scenen: samma bild (16 sampel, 1400x500) tog 0,45 s
## utan och 0,47 s med (1,0x). Den får stå PÅ som i originalet (~/Downloads/Untitled.blend, som också
## har den på ... nej: originalet har False). Alex' fil hade True, alltså lämnas den som den var.
## Lärdomen som står kvar: en SPARAD viewport-inställning ÄR användarens vy — den styr vad han ser när
## han öppnar filen, och "bara visningsfilen" är ingen ursäkt för att ändra den otestad.
## Alex 2026-10-14 om vy-navigeringen: "allt så svårnavigerat ... inte så smidigt jag kunde i början."
## MÄTT då: view_rotate_method TURNTABLE, känslighet 0,006981316953897476 = 0,4°/px = fabriksvärdet,
## scenen 1950 -> 1976 objekt och 26 258 -> 26 888 ytor (alltså inte tyngre), material 50 -> 24.
## Inget av det förklarade känslan — kvar som förklaring står var vyn roterar (pivotens avstånd),
## vilket inte går att läsa ur en fil eller genom bryggan. Home-tangenten prövar saken på en sekund.
## glb:n bär inga renderingsinställningar; det här gäller bara .blend som någon ska titta i.
sc = bpy.context.scene
if hasattr(sc.eevee, "use_raytracing"):
    sc.eevee.use_raytracing = True
    sc.eevee.use_shadows = True
    if hasattr(sc.eevee, "ray_tracing_options"):
        sc.eevee.ray_tracing_options.use_denoise = True
    print("EEVEE: ray tracing och skuggor PÅ")
bpy.ops.wm.save_as_mainfile(filepath=ut, copy=False)
print("SPARAD: %s" % ut)
