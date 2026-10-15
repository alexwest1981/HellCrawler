"""Testets första del: vrid UV:n på TVÅ objekt — ett som Alex äger (uv_keep) och ett utan flagga.

Det andra är det negativa provet: utan flagga SKA kedjan skriva över vinkeln. Utan den kontrollen
vet man inte om mätningen kan falla alls (den första versionen summerade u+v, vilket ett byte av u och
v bevarar — summan var lika för båda och testet kunde inte misslyckas).

    blender -b <kopia.blend> --python uvprov_setup.py --python tools/apply_pixel_textures.py --python uvprov_kolla.py
"""
import bpy


def vrid(namn, flagga):
    o = bpy.data.objects[namn]
    if flagga:
        o["uv_keep"] = True
    lager = o.data.uv_layers.get("UVMap_PixelArt") or o.data.uv_layers[0]
    for d in lager.data:
        d.uv = (d.uv[1], d.uv[0])          # byt plats på u och v
    viktad = sum((i + 1) * (d.uv[0] - d.uv[1]) for i, d in enumerate(lager.data))
    print("FÖRE  %-26s flagga=%-5s %3d punkter, viktad (u-v) %+.3f" %
          (namn, flagga, len(lager.data), viktad))


vrid("Sign_Weaver_Board", True)
kontroll = next(o.name for o in bpy.data.objects
                if "Sign_" in o.name and "Board" in o.name and o.name != "Sign_Weaver_Board")
print("kontrollobjekt utan flagga: %s" % kontroll)
vrid(kontroll, False)
