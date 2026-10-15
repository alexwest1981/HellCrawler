#!/usr/bin/env python3
"""Ytorna i spelet ur texturpaketet — väggar, golv OCH tak, per tema.

VARFÖR: Alex 15/10 — "texturerna ser inte så bra ut just nu ... kolla i denna mapp om du kan använda
något istället". Mätt på vår egen vägg (`assets/tiles/asklunden/wall.png`): median 0,212 och spann
(p90-p10) 0,224. Paketets rutor ligger på 0,33-0,70. Samma diagnos som murrigheten: ytan är flack.

VAD SOM ANVÄNDS, OCH VAD SOM INTE:
  `_diffuseOriginal.bmp`  -> albedo (rutan, INTE `N.png` — den är en preview-rendering på en cylinder
                             med inbakad belysning och är inte kvadratisk; Alex 15/10)
  `_normal.bmp`           -> normalmap (spelet läser redan `<ruta>_n.png` per tema)
  `_ao.bmp` + `_smoothness.bmp` -> ORM (R = AO, G = råhet = 1 - smoothness, B = 0)
  `_metallic.bmp`         -> ANVÄNDS INTE: den ligger på 0,83-0,90 i median i hela paketet, alltså
                             "allt är metall", vilket skulle göra sten och trä blanksvart.
  `_height.bmp`, `_edge.bmp` -> används inte (spelet har ingen parallax, och `_kant` räknas ur albedon).

VILKA FILER SOM SKRIVS (exakt de namn spelet läser, se `_add_boxes_ytor` i `main.gd`):
  wall_super_0..3, floor_super_0..3   de STORA ytorna (fyra olika rutor av samma material)
  wall, wall_moss                     små väggrutor, varav den andra är den slitna varianten
  floor, floor_crack                  små golvrutor, varav den andra är den spruckna
  ceiling                             taket (spelet ritar taket som EN yta)
Varje ruta skalas till 256x256 och får en `_n` (normal). `_orm` skrivs INTE — Alex' egna behålls, se
`skriv()`. Ingen palettkvantisering: de nuvarande ytorna är mjuka AI-texturer med ~12 000 färger, så en
nedskalad 1024-ruta är samma sorts bild.

VALET AV RUTA ÄR MÄTT, inte tyckt: för varje plats och mapp provas alla varianter, och den med bredast
spann vinner — men bara om skarven är REN. Skarven mäts som kanten (sista kolumnen mot första) mot den
typiska skillnaden mellan två grannkolumner inuti rutan; är kanten mer än dubbelt så stor syns den som
ett rutnät över hela ytan. (En synlig skarv går inte att vrida bort: 23,9 -> 36,3 för Tiles/6.)

KÖRNING:  PATH=/usr/bin:$PATH python3 tools/gen_ytor_paket.py [--prov]
LICENS: CC0 1.0 — Texture Pack by Lynocs, https://lynocs.itch.io/texture-pack (verifierad 15/10).
Fri för privata och kommersiella projekt, även ändrad; texturena får bara inte säljas vidare som de är.
"""
import glob
import os
import sys
from PIL import Image

PAKET = os.path.expanduser("~/Downloads/Textures")
UT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "tiles")
# RUTANS STORLEK: 256. Provat 512 (2x nedskalning i stället för 4x): vyns detalj gick från 0,0133 till
# 0,0142, alltså +7 %, medan filerna blir 2,5 gånger tyngre — inte värt det. (Att rutorna ändå visar
# mindre detalj än Alex' egna, 0,0236, beror inte på skalan: paketets ytor är målade med större, renare
# former, medan hans ark är brusiga AI-texturer. Det är ett byte av utseende, inte av skärpa.)
STORLEK = 256
KÄLLA = 1024       # paketets rutor
SUPER = 4          # antal super-rutor per yta (SUPER_YTOR i main.gd)
VÅR_SPANN = 0.224  # vår egen vägg — det tal varje val måste slå

# tema -> plats -> paketmapp. Varje plats tar den bästa rena rutan ur sin mapp.
VAL = {
    "asklunden": {                       # lunden: rötter, gräs, löv, trätak
        "wall": "Roots", "wall_moss": "Mystical",
        "floor": "Grass", "floor_crack": "Fall Ground", "ceiling": "Roof",
    },
    "krypta": {                          # kryptan: murad sten, golvplattor, valv
        "wall": "Stone Wall", "wall_moss": "Damaged Wall",
        "floor": "Floor", "floor_crack": "Damaged Parquet", "ceiling": "Cave Wall",
    },
    "grotta": {                          # grottan: berg överallt
        "wall": "Cave Wall", "wall_moss": "Mystical",
        "floor": "Cave Floor", "floor_crack": "Fall Ground", "ceiling": "Cave Wall",
    },
    "tunnel": {                          # byggd gång: kullersten, plattor, träbalkar i taket
        "wall": "Cobble Stone", "wall_moss": "Damaged Wall",
        "floor": "Tiles", "floor_crack": "Damaged Parquet", "ceiling": "Magical Wood Planks",
    },
    "bro": {                             # bron: virke, även i taket
        "wall": "Wood Planks", "wall_moss": "Magical Wood Planks",
        "floor": "Wood Planks", "floor_crack": "Damaged Parquet", "ceiling": "Wood Planks",
    },
}


def las(sökväg: str) -> Image.Image:
    """2x nedskalning av hela rutan (sömlös förblir sömlös; se STORLEK)."""
    return Image.open(sökväg).convert("RGB").resize((STORLEK, STORLEK), Image.LANCZOS)


def grå(img: Image.Image) -> list:
    g = img.convert("L")
    return list(g.get_flattened_data()) if hasattr(g, "get_flattened_data") else list(g.getdata())


def spann(pix: list) -> float:
    px = sorted(pix)
    return (px[int(len(px) * 0.9)] - px[int(len(px) * 0.1)]) / 255.0


def skarv(pix: list) -> tuple:
    """Kanten (sista kolumnen mot första) mot den typiska skillnaden inuti rutan."""
    def kol(x: int) -> list:
        return [pix[y * STORLEK + x] for y in range(STORLEK)]
    kant = sum(abs(a - b) for a, b in zip(kol(STORLEK - 1), kol(0))) / float(STORLEK)
    inre = sorted(sum(abs(p - q) for p, q in zip(kol(x - 1), kol(x))) / float(STORLEK)
                  for x in range(1, STORLEK))[STORLEK // 2]
    return kant, inre


def kandidater(mapp: str) -> list:
    """Alla rutor i en paketmapp, sorterade på spann (bredast först), med skarven kvar."""
    ut = []
    for fil in sorted(glob.glob(os.path.join(PAKET, mapp, "*", "*_diffuseOriginal.bmp"))):
        nr = os.path.basename(fil).split("_")[0]
        pix = grå(las(fil))
        kant, inre = skarv(pix)
        ut.append({"nr": nr, "spann": spann(pix), "ren": kant <= 2.0 * max(inre, 0.5)})
    ut.sort(key=lambda k: -k["spann"])
    return ut


def orm(mapp: str, nr: str) -> Image.Image:
    """Godots ORM: R = AO, G = råhet (1 - smoothness), B = metall (0, se filhuvudet)."""
    ao = las(os.path.join(PAKET, mapp, nr, "%s_ao.bmp" % nr)).convert("L")
    slät = las(os.path.join(PAKET, mapp, nr, "%s_smoothness.bmp" % nr)).convert("L")
    ut = Image.new("RGB", (STORLEK, STORLEK))
    ut.putdata([(a, 255 - s, 0) for a, s in zip(ao.getdata(), slät.getdata())])
    return ut


def skriv(tema: str, namn: str, mapp: str, nr: str) -> None:
    """Albedo och normal byts. ORM:en lämnas — Alex' egna bär spelets blöta glans.

    MÄTT: paketets `_smoothness` är jämnt matt (median 0,13 → råhet 0,87), så med paketets ORM hittar
    spelets regel "fuktiga ytor blänker" (GLANS_BLÖT_ANDEL, Alex: "så väggar kan se fuktiga ut, så det
    blänker gentemot ljus") NOLL blöta fläckar: `test_normalprov` föll med "0 av 11 ytor" och hela
    spelet blev matt. Hans ORM:er har de blöta partierna, och att behålla dem kostar bara att AO-kartan
    är ritad för hans mönster i stället för paketets — en skillnad som knappt syns, mot en glans som
    försvinner helt."""
    mål = os.path.join(UT, tema)
    os.makedirs(mål, exist_ok=True)
    las(os.path.join(PAKET, mapp, nr, "%s_diffuseOriginal.bmp" % nr)).save(os.path.join(mål, "%s.png" % namn))
    las(os.path.join(PAKET, mapp, nr, "%s_normal.bmp" % nr)).save(os.path.join(mål, "%s_n.png" % namn))


def main() -> int:
    torr = "--prov" in sys.argv
    fel = 0
    print("%-10s %-12s %-22s %-7s %s" % ("tema", "plats", "mapp/ruta", "spann", "skarv"))
    for tema, platser in VAL.items():
        for plats, mapp in platser.items():
            kand = kandidater(mapp)
            if not kand:
                print("%-10s %-12s %-22s SAKNAS" % (tema, plats, mapp))
                fel += 1
                continue
            rena = [k for k in kand if k["ren"]]
            bäst = rena[0] if rena else kand[0]
            # wall/floor ritas som fyra super-rutor och behöver fyra OLIKA rutor; de andra en.
            antal = SUPER if plats in ("wall", "floor") else 1
            valda = rena[:antal] if len(rena) >= antal else (rena if rena else kand[:1])
            if len(valda) < antal:
                print("%-10s %-12s %-22s bara %d rena rutor (behöver %d)" % (tema, plats, mapp, len(valda), antal))
                fel += 1
            print("%-10s %-12s %-22s %-7.3f %s" % (tema, plats, "%s/%s" % (mapp, bäst["nr"]), bäst["spann"],
                "ren" if bäst["ren"] else "SKARV SYNS — tog näst bästa rena"))
            if bäst["spann"] <= VÅR_SPANN:
                print("   OBS: spannet slår inte vår egen yta (%.3f)" % VÅR_SPANN)
                fel += 1
            if torr:
                continue
            for i, k in enumerate(valda):
                if antal > 1:
                    skriv(tema, "%s_super_%d" % (plats, i), mapp, k["nr"])
                    if i == 0:
                        skriv(tema, plats, mapp, k["nr"])      # smårutorna = den bästa av de fyra
                else:
                    skriv(tema, plats, mapp, k["nr"])
            print("   skrivet: %s/%s%s" % (tema, plats, "_super_0..%d" % (len(valda) - 1) if antal > 1 else ""))
    print("%d fel" % fel)
    return 1 if fel else 0


if __name__ == "__main__":
    raise SystemExit(main())
