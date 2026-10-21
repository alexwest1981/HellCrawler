"""Klipper ut de texturrutor 3D-husen använder ur de nedladdade mapseten.

    python3 tools/klipp_texturer.py

Mapseten ligger i ~/Downloads (Fantasy Props MegaKit / Stylized Nature MegaKit) och är atlaser:
en enda bild rymmer många olika ytor. Här väljs EN jämn ruta per material och samma ruta klipps ur
BaseColor, Normal och ORM, så de tre kartorna ligger exakt över varandra. Resultatet hamnar i
`game/assets/by/texturer/` — bara de set som faktiskt används kopieras in.

Rutorna är valda med avseende på låg gradient och låg kantmismatch (se `mät`), så de kan repeteras
utan synlig söm. Texturmåtten styr texeldensiteten: `gen_by_hus3d.py` räknar varv/m = 512 / bredd.
"""

import pathlib
import sys

import numpy as np
from PIL import Image

HEM = pathlib.Path.home()
KÄLLOR = {
    "props": HEM / "Downloads" / "Fantasy Props MegaKit[Standard] (1)" / "Textures",
    "natur": HEM / "Downloads" / "Stylized Nature MegaKit[Standard]" / "Textures",
}
UT = pathlib.Path(__file__).resolve().parent.parent / "game" / "assets" / "by" / "texturer"

# (utnamn, paket, atlas, x, y, storlek)  — samma ruta klipps ur BaseColor/Normal/ORM
RUTOR = [
    ("tyg_väv",   "props", "T_Trim_Cloth",     800,  512, 256),   # neutralt linnetyg, tintas per plagg
    ("läder",     "props", "T_Trim_Props",    1760,  496, 256),   # segt canvas/läder till bälg och säckar
    ("trä_ljust", "props", "T_Trim_Furniture", 880,  624, 256),   # hyvlat virke: plank, disk, spån
    ("järn",      "props", "T_Trim_Metal",    1760, 1264, 256),   # smidesjärn: gångjärn, band, städ
    ("mässing",   "props", "T_Trim_Props",     144, 1392, 256),   # mässing: beslag, skylt, kanna
    ("sten_grå",  "natur", "Rocks_Diffuse",    240,  864, 384),   # gråsten till mur och sockel (ingen ORM)
]

# Kartor som inte finns i källmapseten (naturpaketet har bara diffuse + normal till barken)
UTAN_NORMAL_ORM = {"sten_grå"}


def mät(a: np.ndarray) -> tuple:
    """Kantmismatch mot inre brus — litet tal betyder att rutan går att repetera."""
    lr = float(np.abs(a[:, :4] - a[:, -4:]).mean())
    tb = float(np.abs(a[:4] - a[-4:]).mean())
    inre = float(np.abs(np.diff(a, axis=1)).mean())
    return lr, tb, inre


def neutral(src: pathlib.Path, dst: pathlib.Path, mättnad: float = 0.22) -> tuple:
    """Drar ner mättnaden i en ruta (grönstenen läses som mossa på en stor slät mur).

    Görs här och inte som en Hue/Saturation-nod i Blender: noden följer inte med i glTF-exporten.
    """
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(float)
    grå = a.mean(axis=2, keepdims=True)
    ut = np.clip(grå + (a - grå) * mättnad, 0, 255).astype("uint8")
    Image.fromarray(ut).save(dst, optimize=True)
    return tuple(ut.reshape(-1, 3).mean(axis=0).astype(int))


def main() -> int:
    UT.mkdir(parents=True, exist_ok=True)
    saknas = [str(p) for p in KÄLLOR.values() if not p.is_dir()]
    if saknas:
        print("Hittar inte mapseten:\n  " + "\n  ".join(saknas))
        return 1
    for namn, paket, atlas, x, y, s in RUTOR:
        for ände, utände in (("BaseColor", ""), ("Normal", "_normal"), ("ORM", "_orm")):
            if namn in UTAN_NORMAL_ORM and ände != "BaseColor":
                continue
            # props-atlaserna heter T_Trim_<yta>_<karta>.png, naturpaketet <yta>.png
            namn_på_fil = ("%s.png" % atlas if paket == "natur" and ände == "BaseColor"
                           else "%s_%s.png" % (atlas, ände))
            källa = KÄLLOR[paket] / namn_på_fil
            if not källa.is_file():
                print("SAKNAS: %s" % källa)
                return 1
            im = Image.open(källa).convert("RGB")
            if x + s > im.width or y + s > im.height:
                print("RUTAN UTANFÖR %s: %s" % (källa.name, (x, y, s)))
                return 1
            ruta = im.crop((x, y, x + s, y + s))
            a = np.asarray(ruta).astype(float)
            lr, tb, inre = mät(a)
            # en giltig normalmap är blå; en ORM har grön kanal > 0 (grovhet)
            if ände == "Normal" and a[..., 2].mean() < 120:
                print("FEL: %s_normal är ingen normalmap (blå medel %.0f)" % (namn, a[..., 2].mean()))
                return 1
            if ände == "ORM" and a[..., 1].mean() < 8:
                print("FEL: %s_orm saknar grovhet i grön kanal" % namn)
                return 1
            ut = UT / (namn + utände + ".png")
            ruta.save(ut, optimize=True)
            if ände == "BaseColor":
                print("  %-11s %dx%d  kant LR %.1f TB %.1f (inre %.1f)  färg %s"
                      % (namn, s, s, lr, tb, inre,
                         tuple(a.reshape(-1, 3).mean(axis=0).astype(int))))
    # neutral grå variant till porttornets murar
    färg = neutral(UT / "sten_grå.png", UT / "sten_grå_neutral.png")
    print("  %-11s neutraliserad  färg %s" % ("sten_grå_n", färg))
    antal = sum(1 if n in UTAN_NORMAL_ORM else 3 for n, *_ in RUTOR)
    print("skrev %d texturrutor till %s" % (antal, UT.relative_to(UT.parents[2])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
