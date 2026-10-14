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
## EEVEE: ray tracing ger kontakt-skuggor och AO. Utan den står scenen platt i Rendered-läget
## (mätt: filen hade use_raytracing = False, och Alex' vy såg "påklistrad" ut). Bara visningsfilen —
## glb:n bär inga renderingsinställningar.
sc = bpy.context.scene
if hasattr(sc.eevee, "use_raytracing"):
    sc.eevee.use_raytracing = True
    sc.eevee.use_shadows = True
    if hasattr(sc.eevee, "ray_tracing_options"):
        sc.eevee.ray_tracing_options.use_denoise = True
    print("EEVEE: ray tracing och skuggor PÅ")
bpy.ops.wm.save_as_mainfile(filepath=ut, copy=False)
print("SPARAD: %s" % ut)
