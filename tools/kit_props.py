"""Ta in Quaternius Fantasy Props MegaKit (CC0) i byn: bara baskartorna, pixelade.

Kitet är CC0 1.0 (`License_Standard.txt`), alltså fritt att lägga i ett publikt repo. Men modellerna
bär 4K-atlaser med normal- och ORM-kartor (38 MB), och ytorna är målade och lena — de skulle se ut som
en annan spelvärld bredvid byns 128 px/m-konst. Det här skriptet gör tre saker:

  1. kopierar de modeller vi använder (glTF + bin) till `game/assets/by/quaternius/props/`
  2. RENSAR bort normal-, ORM- och ocklusionstexturerna ur materialen (de behövs inte: byns ytor är
     platta och ljussätts av scenens ljus, och en 4K-normal hade ändå bara kostat minne)
  3. pixelar de tre baskartorna (Furniture, Metal, Cloth) till 256 px och kvantiserar dem till 24 färger

Kör: python3 tools/kit_props.py [--check]
"""
import json
import os
import shutil
import sys

from PIL import Image

KÄLLA = os.path.expanduser("~/Downloads/Fantasy Props MegaKit[Standard] (1)")
UT = "game/assets/by/quaternius/props"
ATLAS = ["T_Trim_Furniture_BaseColor.png", "T_Trim_Metal_BaseColor.png", "T_Trim_Cloth_BaseColor.png"]
MODELLER = ["Barrel", "Barrel_Holder", "Crate_Wooden", "Bag", "Bucket_Wooden_1", "Pot_1",
            "Rope_3", "Chest_Wood", "Bench", "Lantern_Wall", "FarmCrate_Empty"]
ATLAS_PX = 256
ATLAS_FÄRGER = 24


def rensa(gltf: dict) -> dict:
    """Behåll bara baskartorna; släpp normal, ORM och ocklusion."""
    behåll = set()
    for m in gltf.get("materials", []):
        for nyckel in ("normalTexture", "occlusionTexture"):
            m.pop(nyckel, None)
        pbr = m.get("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        if "baseColorTexture" in pbr:
            behåll.add(pbr["baseColorTexture"]["index"])
    if not behåll:
        return gltf
    gamla = gltf.get("textures", [])
    ny_tex, karta = [], {}
    for gammal_i in sorted(behåll):
        karta[gammal_i] = len(ny_tex)
        ny_tex.append(gamla[gammal_i])
    bilder = gltf.get("images", [])
    ny_bild, bild_karta = [], {}
    for t in ny_tex:
        b = t["source"]
        if b not in bild_karta:
            bild_karta[b] = len(ny_bild)
            ny_bild.append(bilder[b])
        t["source"] = bild_karta[b]
    gltf["textures"] = ny_tex
    gltf["images"] = ny_bild
    for m in gltf.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        if "baseColorTexture" in pbr:
            pbr["baseColorTexture"]["index"] = karta[pbr["baseColorTexture"]["index"]]
    return gltf


def main() -> int:
    if "--check" in sys.argv:
        saknas = [m for m in MODELLER if not os.path.exists("%s/%s.gltf" % (UT, m))]
        print("OK   alla %d modeller finns" % len(MODELLER) if not saknas
              else "FEL  saknas: %s" % ", ".join(saknas))
        return 0 if not saknas else 1
    if not os.path.isdir(KÄLLA):
        print("FEL  kitet finns inte i %s" % KÄLLA)
        return 1
    os.makedirs(UT, exist_ok=True)
    for m in MODELLER:
        p = "%s/Exports/glTF/%s.gltf" % (KÄLLA, m)
        if not os.path.exists(p):
            print("FEL  %s saknas i kitet" % m)
            return 1
        shutil.copy(p, "%s/%s.gltf" % (UT, m))
        shutil.copy("%s/Exports/glTF/%s.bin" % (KÄLLA, m), "%s/%s.bin" % (UT, m))
        d = json.load(open("%s/%s.gltf" % (UT, m), encoding="utf-8"))
        json.dump(rensa(d), open("%s/%s.gltf" % (UT, m), "w", encoding="utf-8"), indent=1)
    for a in ATLAS:
        im = Image.open("%s/Textures/%s" % (KÄLLA, a)).convert("RGB")
        im = im.resize((ATLAS_PX, ATLAS_PX), Image.BOX)
        im = im.quantize(colors=ATLAS_FÄRGER, method=Image.Quantize.MEDIANCUT).convert("RGB")
        im.save("%s/%s" % (UT, a))
        print("   %-32s %d px, %d färger" % (a, ATLAS_PX, ATLAS_FÄRGER))
    shutil.copy("%s/License_Standard.txt" % KÄLLA, "%s/LICENSE.txt" % UT)
    print("skrev %d modeller + %d atlaser till %s" % (len(MODELLER), len(ATLAS), UT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
