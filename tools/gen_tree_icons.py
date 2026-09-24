#!/usr/bin/env python3
"""Trädets ikoner: en per gren, plus en kronvariant. 32x32 pixlar.

Alex: *"Trädet skall vara en egen vy, och det skall vara ikoner, med text när man hovrar över en
ikon."* Fyra grenar behöver fyra ikoner — nivån syns i stället på hur starkt ikonen lyser (metans
rang tonar den i vyn), så att rita 88 olika ikoner hade varit 88 bilder för information som redan
finns i datat. Kronan (nivå 6) får en egen variant med en gloria, så att grenens slut syns även när
ikonen är släckt.

32x32 är valt med flit: spelvyn är 480x270, och med rutnätet 4x6 blir varje ruta ungefär 32 px. En
källpixel per ritad pixel — samma räkning som bänken (assets/ui/bench.png, 512x288), och därmed
ingen omsampling i spelet.

Färgerna läses ur game/assets/palette.json, som all annan grafik i huset. Nyansen väljs genom att
MÄTA paletten i stället för att gissa ett index: guldet är den varmaste gula, elden den rödaste,
benet den ljusaste och stålet den blåaste. Ett handplockat index hade glidit isär från paletten utan
att någon märkt det.

    python3 tools/gen_tree_icons.py            skriv game/assets/tree/*.png
    python3 tools/gen_tree_icons.py --check    mät de skrivna ikonerna
"""
import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROT = Path(__file__).resolve().parent.parent
PALETT = ROT / "game" / "assets" / "palette.json"
UT = ROT / "game" / "assets" / "tree"
SIDA = 32


def färger():
    """Paletten som (r,g,b)-tupler, plus de fyra nyanser grenarna behöver — valda genom att mäta."""
    rader = json.load(open(PALETT, encoding="utf-8"))
    rgb = [tuple(int(v) for v in r) for r in rader]
    varmast = lambda t: t[0] + t[1] - t[2]                       # guld: mycket rött och grönt, lite blått
    rödast = lambda t: t[0] - (t[1] + t[2]) // 2                  # eld
    ljusast = lambda t: sum(t)                                   # ben
    blåast = lambda t: t[2] - t[0] // 2                          # stål
    mörk = min(rgb, key=sum)
    return {
        "outline": mörk,
        "guld": max(rgb, key=varmast),
        "eld": max(rgb, key=rödast),
        "ben": max(rgb, key=ljusast),
        "stål": max(rgb, key=blåast),
        "ljust": max(rgb, key=sum),
    }


def kant(d, pts, fill, outline, w=1):
    d.polygon(pts, fill=outline)
    d.polygon(pts, fill=fill, outline=outline, width=w)


def svärd(f):
    """Järnvägen: ett stående blad med parerstång och fäste."""
    im = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    kant(d, [(16, 2), (19, 7), (19, 20), (13, 20), (13, 7)], f["stål"], f["outline"])
    d.line([(9, 21), (23, 21)], fill=f["outline"], width=3)
    d.line([(9, 21), (23, 21)], fill=f["ljust"], width=1)
    d.rectangle([14, 22, 18, 28], fill=f["outline"])
    d.ellipse([13, 27, 19, 31], fill=f["guld"], outline=f["outline"])
    return im


def ben(f):
    """Benknippet: ett ben med två knoppar i varje ände."""
    im = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(10, 8), (22, 24)], fill=f["outline"], width=7)
    d.line([(10, 8), (22, 24)], fill=f["ben"], width=4)
    for x, y in ((9, 8), (13, 5), (19, 27), (23, 24)):
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=f["outline"])
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=f["ben"])
    return im


def låga(f):
    """Glöden: en tårformad låga med ljus kärna."""
    im = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    kant(d, [(16, 2), (24, 14), (25, 21), (21, 29), (11, 29), (7, 21), (8, 14)], f["eld"], f["outline"])
    d.polygon([(16, 12), (20, 21), (16, 27), (12, 21)], fill=f["ljust"])
    return im


def mynt(f):
    """Girigheten: ett mynt med ljus kant och en glansfläck.

    Första versionen hade ett kors i mitten, och den oberoende granskningen läste den som en sköld
    eller en knapp. Ett mynt är en skiva med kant och glans — korset var den enda detaljen som
    drog läsningen fel, så den är borta.
    """
    im = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([5, 5, 27, 27], fill=f["outline"])
    d.ellipse([7, 7, 25, 25], fill=f["guld"])
    d.ellipse([9, 9, 23, 23], outline=f["outline"], width=2)
    d.ellipse([11, 11, 14, 14], fill=f["ljust"])
    return im


def gloria(im, f):
    """Kronan: samma ikon med en ring av GULDGLÖD runt, så att grenens slut syns även släckt.

    Ringen var först i samma orangea eld som lågan, och granskningen påpekade att kransen då smälte
    ihop med glödens egen ikon. Guldet skiljer kronan från alla fyra grenarna.
    """
    ut = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(ut)
    for a in range(0, 360, 30):
        import math
        x = 16 + 13 * math.cos(math.radians(a))
        y = 16 + 13 * math.sin(math.radians(a))
        d.ellipse([x - 1.7, y - 1.7, x + 1.7, y + 1.7], fill=f["guld"], outline=f["outline"])
    mindre = im.resize((SIDA - 8, SIDA - 8), Image.Resampling.LANCZOS)
    ut.alpha_composite(mindre, (4, 4))
    return ut


def is_(f):
    """Is: en sexarmad kristall med ljus kärna. Färgen är palettens blåaste (stålet)."""
    im = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for dx, dy in ((0, -12), (0, 12), (12, 0), (-12, 0), (9, -9), (-9, 9), (9, 9), (-9, -9)):
        d.line([(16, 16), (16 + dx, 16 + dy)], fill=f["outline"], width=3)
    for dx, dy in ((0, -11), (0, 11), (11, 0), (-11, 0), (8, -8), (-8, 8), (8, 8), (-8, -8)):
        d.line([(16, 16), (16 + dx, 16 + dy)], fill=f["stål"], width=1)
    d.ellipse([10, 10, 22, 22], fill=f["stål"], outline=f["outline"])
    d.ellipse([13, 13, 19, 19], fill=f["ljust"])
    return im


def magi(f):
    """Magi: en femuddig stjärna över en glöd, i guld och eld."""
    im = Image.new("RGBA", (SIDA, SIDA), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    stjärna = [(16, 2), (19, 11), (28, 11), (21, 17), (24, 26), (16, 21), (8, 26), (11, 17), (4, 11), (13, 11)]
    kant(d, stjärna, f["guld"], f["outline"])
    d.ellipse([13, 27, 19, 31], fill=f["eld"], outline=f["outline"])
    return im


GRENAR = {"jarnvagen": svärd, "benknippet": ben, "gloden": låga, "girigheten": mynt}

# EXTRA IKONER, till noder man väljer grafik på i trädeditorn (Alex: "sätta grafik på dem (eld, is,
# magi)"). De hör inte till en gren och får därför ingen krona — kransen är grenens slut, inte en
# ikonstil.
EXTRA = {"eld": låga, "is": is_, "magi": magi}
# Filnamnen är ASCII: en resursväg med å/ä/ö är samma fälla som ett variabelnamn med å/ä/ö (Alex'
# regel: kod ska tåla att köras hos någon som inte har svensk locale). Grenens NAMN i spelet är
# förstås kvar som det är — det är text, inte en identifierare.


def skriv():
    f = färger()
    UT.mkdir(parents=True, exist_ok=True)
    for namn, ritare in GRENAR.items():
        bas = ritare(f)
        bas.save(UT / ("%s.png" % namn))
        gloria(bas, f).save(UT / ("%s_krona.png" % namn))
        print("  %-16s %s" % (namn, "krona + bas"))
    for namn, ritare in EXTRA.items():
        ritare(f).save(UT / ("%s.png" % namn))
        print("  %-16s %s" % (namn, "nodikon"))
    print("%d ikoner -> %s" % (len(GRENAR) * 2 + len(EXTRA), UT))


def checka():
    fel = []
    for namn in GRENAR:
        for fil in ("%s.png" % namn, "%s_krona.png" % namn):
            p = UT / fil
            if not p.exists():
                fel.append("%s saknas" % fil)
                continue
            if Image.open(p).size != (SIDA, SIDA):
                fel.append("%s är %s" % (fil, Image.open(p).size))
    for namn in EXTRA:
        p = UT / ("%s.png" % namn)
        if not p.exists():
            fel.append("%s.png saknas" % namn)
        elif Image.open(p).size != (SIDA, SIDA):
            fel.append("%s.png är %s" % (namn, Image.open(p).size))
    print("%d ikoner, %d fel" % (len(GRENAR) * 2 + len(EXTRA), len(fel)))
    for f in fel:
        print("  %s" % f)
    return 1 if fel else 0


def main():
    if "--check" in sys.argv:
        raise SystemExit(checka())
    skriv()


if __name__ == "__main__":
    main()
