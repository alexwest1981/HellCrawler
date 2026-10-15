#!/usr/bin/env python3
"""Väggytorna ur Alex' texturpaket (~/Downloads/Textures) i stället för de egna arken.

VARFÖR: Alex 15/10 — "texturerna ser inte så bra ut just nu ... kolla i denna mapp om du kan använda
något istället". Mätt på vår egen vägg (`assets/tiles/asklunden/wall.png`): median 0,212 och spann
(p90-p10) 0,224. Paketets rutor ligger på spann 0,33-0,52 — alltså 1,5-2,3 gånger bredare tonomfång,
och det är samma diagnos som murrigheten: ytan är flack, inte mörk.

VAD SOM ANVÄNDS, OCH VAD SOM INTE:
  `_diffuseOriginal.bmp`  -> albedo (rutan, INTE `N.png` — den är en preview-rendering på en cylinder
                             med inbakad belysning och är inte kvadratisk; Alex 15/10)
  `_normal.bmp`           -> normalmap (spelet läser redan `<ruta>_n.png` per tema)
  `_ao.bmp` + `_smoothness.bmp` -> ORM (R = AO, G = råhet = 1 - smoothness, B = 0)
  `_metallic.bmp`         -> ANVÄNDS INTE: den ligger på 0,83-0,90 i median i hela paketet, alltså
                             "allt är metall", vilket skulle göra sten och trä blanksvart. Våra ytor
                             är icke-metaller, och B-kanalen sätts därför till 0.
  `_height.bmp`, `_edge.bmp` -> används inte (spelet har ingen parallax, och `_kant` räknas ur albedon).

Varje ruta skalas till 256x256 (samma storlek som de nuvarande, som är mjuka AI-texturer med ~12 000
färger — ingen palettkvantisering behövs) och skarven mäts: sista kolumnen mot första, i gråsteg. En
ruta upprepas per block, så en skarv blir ett rutnät över hela väggen.

KÖRNING:  python3 tools/gen_ytor_paket.py [--prov]
LICENSEN: paketet har INGEN licensfil (varken i mapparna eller i zip-filerna, kontrollerat 15/10).
Filerna skrivs därför med en varning i CREDITS.md — de får inte publiceras förrän källan är känd.
"""
import os
import sys
from PIL import Image

PAKET = os.path.expanduser("~/Downloads/Textures")
UT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "tiles")
STORLEK = 256

# tema -> (paketmapp, nummer). Valet är MÄTT: bredast tonomfång bland kandidaterna för det temat,
# med ögat på att kryptan ska vara mörkare än grottan. (Spann i parentes.)
## temats fyra SUPER-rutor tas ur fyra OLIKA rutor av samma material (2, 3, 4, 5). Spelet ritar
## stora ytor som `wall_super_0..3` och smårutorna som `wall` — båda måste bytas, annars står de stora
## väggarna kvar med det gamla utseendet (mätt: bara `wall.png` byttes först, och det är smårutorna).
VAL = {
    "asklunden": ("Roots", 2, 0.404),         # lunden: rötter, inte bark (bark hade 0,16-0,28)
    "krypta": ("Stone Wall", 1, 0.435),       # murad sten, bredast spann av 15 varianter
    # Cave Wall har 1-10; starten ligger på 7 så alla fyra SUPER-rutorna (7-10) finns.
    "grotta": ("Cave Wall", 7, 0.341),        # grottvägg, mindre urblekt än 2:an (0,604 i median)
    "tunnel": ("Cobble Stone", 2, 0.380),     # byggd gång. Tiles/6 hade bredast spann (0,522) men en
                                              # SYNLIG skarv (23,9 mot 9,9 inuti); att vrida rutan ett
                                              # halvt varv gjorde den värre (36,3) — byt variant i stället.
    "bro": ("Wood Planks", 5, 0.294),         # bron är virke
}
SUPER = 4


def las(sökväg: str) -> Image.Image:
    return Image.open(sökväg).convert("RGB").resize((STORLEK, STORLEK), Image.LANCZOS)


def skarv(img: Image.Image) -> tuple:
    """Skarven mot rutan INVÄNDIGT: en kant är bara en skarv om skillnaden där är större än den
    typiska skillnaden mellan två angränsande kolumner inuti rutan. (Samma resonemang som
    `gen_tiles_alex.py`: 30-134 gråsteg vid kanten mot 8-10 inuti var en synlig skarv.)"""
    g = img.convert("L")
    pix = list(g.get_flattened_data()) if hasattr(g, "get_flattened_data") else list(g.getdata())
    def kolumn(x: int) -> list:
        return [pix[y * STORLEK + x] for y in range(STORLEK)]
    sista, första = kolumn(STORLEK - 1), kolumn(0)
    kant = sum(abs(a - b) for a, b in zip(sista, första)) / float(STORLEK)
    inre = []
    for x in range(1, STORLEK):
        a, b = kolumn(x - 1), kolumn(x)
        inre.append(sum(abs(p - q) for p, q in zip(a, b)) / float(STORLEK))
    inre.sort()
    return kant, inre[len(inre) // 2]


def orm(mapp: str, nr: str) -> Image.Image:
    """Godots ORM: R = AO, G = råhet (1 - smoothness), B = metall (0, se filhuvudet)."""
    ao = las(os.path.join(mapp, "%s_ao.bmp" % nr)).convert("L")
    slät = las(os.path.join(mapp, "%s_smoothness.bmp" % nr)).convert("L")
    ut = Image.new("RGB", (STORLEK, STORLEK))
    ut.putdata([(a, 255 - s, 0) for a, s in zip(ao.getdata(), slät.getdata())])
    return ut


def main() -> int:
    torr = "--prov" in sys.argv
    rad = "%-10s %-16s %-10s %-8s %-8s %-12s %s"
    print(rad % ("tema", "källa", "albedo", "median", "spann", "kant/inuti", "skarv?"))
    fel = 0
    for tema, (källa, start, förväntat) in VAL.items():
        mapp = os.path.join(PAKET, källa)
        nr = str(start)
        albedo_fil = os.path.join(mapp, nr, "%s_diffuseOriginal.bmp" % nr)
        if not os.path.exists(albedo_fil):
            print("%-10s %-16s SAKNAS (%s)" % (tema, källa, albedo_fil))
            fel += 1
            continue
        albedo = las(albedo_fil)
        g = albedo.convert("L")
        px = sorted(g.get_flattened_data()) if hasattr(g, "get_flattened_data") else sorted(g.getdata())
        median = px[len(px) // 2] / 255.0
        spann = (px[int(len(px) * 0.9)] - px[int(len(px) * 0.1)]) / 255.0
        # En synlig skarv går INTE att vrida bort (mätt: 23,9 -> 36,3 för Tiles/6) — välj en annan
        # variant. Raden säger till i stället för att dölja det.
        kant, inre = skarv(albedo)
        syns = "nej" if kant <= 2.0 * max(inre, 0.5) else "SYNS"
        print(rad % (tema, "%s/%s" % (källa, nr), "%dx%d" % albedo.size, "%.3f" % median, "%.3f" % spann,
            "%.1f / %.1f" % (kant, inre), syns))
        if abs(spann - förväntat) > 0.02:
            print("   OBS: spannet är %.3f, inte %.3f som valet byggde på" % (spann, förväntat))
            fel += 1
        if torr:
            continue
        mål = os.path.join(UT, tema)
        os.makedirs(mål, exist_ok=True)
        # Smårutorna: den valda rutan. SUPER-rutorna: fyra på varandra följande rutor av samma material.
        for namn, n2_ in [("wall", nr)] + [("wall_super_%d" % i, str(start + i)) for i in range(SUPER)]:
            källa2 = os.path.join(mapp, n2_)
            if not os.path.exists(os.path.join(källa2, "%s_diffuseOriginal.bmp" % n2_)):
                print("   saknas: %s/%s" % (källa, n2_))
                fel += 1
                continue
            las(os.path.join(källa2, "%s_diffuseOriginal.bmp" % n2_)).save(os.path.join(mål, "%s.png" % namn))
            las(os.path.join(källa2, "%s_normal.bmp" % n2_)).save(os.path.join(mål, "%s_n.png" % namn))
            orm(källa2, n2_).save(os.path.join(mål, "%s_orm.png" % namn))
        print("   skrivet: %s/wall{,_n,_orm}.png + wall_super_0..%d" % (tema, SUPER - 1))
    print("%d fel" % fel)
    return 1 if fel else 0


if __name__ == "__main__":
    raise SystemExit(main())
