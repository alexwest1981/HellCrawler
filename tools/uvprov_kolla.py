"""Testets andra del: läser UV:n EFTER att apply_pixel_textures.py kört i samma process.

Alex' objekt ska ha EXAKT samma viktade värde som före. Kontrollobjektet utan flagga SKA ha ett annat.
"""
import bpy


def kolla(namn, flagga):
    o = bpy.data.objects[namn]
    lager = o.data.uv_layers[0]
    viktad = sum((i + 1) * (d.uv[0] - d.uv[1]) for i, d in enumerate(lager.data))
    print("EFTER %-26s flagga=%-5s %3d punkter, viktad (u-v) %+.3f, %d UV-lager" %
          (namn, flagga, len(lager.data), viktad, len(o.data.uv_layers)))


kolla("Sign_Weaver_Board", True)
kontroll = next(o.name for o in bpy.data.objects
                if "Sign_" in o.name and "Board" in o.name and o.name != "Sign_Weaver_Board")
kolla(kontroll, False)
