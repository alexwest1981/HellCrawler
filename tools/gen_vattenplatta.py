"""Gor vattenplattan kaklingsbar och skriver den.

Plattan ur paketet ar en renderad vattenyta, inte en kakelplatta: basta 256-rutan hade fog
kol 8,60 / rad 5,79 (fogen ar 6..9 ganger rutans egna kanter). Klippan ar 42 m bred och plattan
upprepas 42 ganger, sa fogen skulle synas som 42 linjer. Har blandas en remsa over fogen —
sista n raderna mot de forsta och sista n kolumnerna mot de forsta — och fogen mats om.
"""
import glob
import os
import numpy as np
from PIL import Image

PAKET = os.path.expanduser("~/Downloads/Textures/Water")
UT = "/home/alex/Projects/hellcrawlers/game/assets/by/tex/vatten.png"
MALTON = np.array([56, 71, 73])
RUTA = 256
REMSA = 64

def fog(f):
    k = np.abs(f[:, -1] - f[:, 0]).mean() / max(np.abs(np.diff(f, axis=1)).mean(), 1e-6)
    r = np.abs(f[-1, :] - f[0, :]).mean() / max(np.abs(np.diff(f, axis=0)).mean(), 1e-6)
    return k, r

def somlos(a):
    """Spegla rutan i bada led: 256 -> 512. Da mots kanterna per konstruktion.

    MATT: kantblandning (sista n raderna mot de forsta) rackte inte — fogen blev 27,9 nivaer
    mot rutans egna 3,5, alltsa synlig som linjer nar plattan upprepas 42 ganger. En spegling
    ar exakt i stallet for approximerad: sista kolumnen ar den forsta kolumnens bild. For en
    vattenyta utan landmarken syns spegelvandningen inte.
    """
    ut = np.concatenate([a, a[::-1, :]], axis=0)
    return np.concatenate([ut, ut[:, ::-1]], axis=1)

def basta_rutan():
    bast = None
    for fil in sorted(glob.glob(PAKET + "/*/*.png")):
        if "_" in os.path.basename(fil):
            continue
        a = np.asarray(Image.open(fil).convert("RGB")).astype(float)
        for y0 in range(0, max(1, a.shape[0] - RUTA), 32):
            for x0 in range(0, max(1, a.shape[1] - RUTA), 32):
                bit = a[y0:y0 + RUTA, x0:x0 + RUTA]
                if bit.shape[:2] != (RUTA, RUTA):
                    continue
                k, r = fog(bit)
                ton = bit.reshape(-1, 3).mean(axis=0)
                tal = (k + r) + 0.02 * float(np.abs(ton - MALTON).sum())
                if bast is None or tal < bast[0]:
                    bast = (tal, fil, x0, y0)
    return bast

def main():
    _, fil, x0, y0 = basta_rutan()
    bit = np.asarray(Image.open(fil).convert("RGB")).astype(float)
    bit = bit[y0:y0 + RUTA, x0:x0 + RUTA]
    k0, r0 = fog(bit)
    ut = np.clip(somlos(bit), 0, 255).astype(np.uint8)   # 256 -> 512, exakt somlos
    k1, r1 = fog(ut.astype(float))
    print("  ruta ur %s x %d y %d" % (fil.split("/Water/")[-1], x0, y0))
    print("  fog FORE  kol %.2f  rad %.2f" % (k0, r0))
    print("  fog EFTER kol %.2f  rad %.2f" % (k1, r1))
    m = ut.reshape(-1, 3).mean(axis=0)
    print("  ton (%d,%d,%d)" % (m[0], m[1], m[2]))
    Image.fromarray(ut).save(UT)

if __name__ == "__main__":
    main()
