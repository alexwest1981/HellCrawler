"""Skär vattenplattan ur Alex' vattenpaket — originalet, inte cylinderrenderingen.

Alex 15/10: "Vattnet ... behöver åtgärdas, se om du hittar något i mappen med vattentexturer jag gav
dig, 8'an jag bifogar eller någon annan som inte är renderad på en cylinder."

MATT, och han hade rätt. Varje N.png är renderad på en cylinder och har fog 9,8..18,2 i radled, alltså
9-18 gånger rutans egna kanter — det är banden man ser. Varje N_diffuseOriginal.bmp är 1024x1024 och
mäter 0,61..1,51, alltså sömlös. Källan är 8_diffuseOriginal.bmp, hans eget val.

Sömlös betyder att plattan kan KAKLAS i stället för att sträckas: 1024 px per meter över hela den
42 m breda ytan, mot 37 px per meter när en enda bild drogs ut. Vatten är därför borta ur HELA_YTAN.

TONEN. Ytan är kväll och natt i spelet. Plattan mäts mot konceptbildens eget vatten (52,66,70):
medelvärdet flyttas dit, en gamma drar ner de ljusa vågkammarna (en rak faktor gjorde det inte — det
är topparna som syns i en mörk scen), och kontrasten halveras så att inget sticker ut ur byn.
"""
import os
import numpy as np
from PIL import Image

PAKET = os.path.expanduser("~/Downloads/Textures/Water")
UT = "/home/alex/Projects/hellcrawlers/game/assets/by/tex/vatten.png"
KALLA = "8/8_diffuseOriginal.bmp"
MALTON = np.array([52.0, 66.0, 70.0])      # konceptbildens vatten, mätt
GAMMA = 1.35
KONTRAST = 0.55

def fog(x):
    k = np.abs(x[:, -1] - x[:, 0]).mean() / max(np.abs(np.diff(x, axis=1)).mean(), 1e-6)
    r = np.abs(x[-1, :] - x[0, :]).mean() / max(np.abs(np.diff(x, axis=0)).mean(), 1e-6)
    return k, r

def main():
    bild = Image.open(os.path.join(PAKET, KALLA)).convert("RGB")
    a = np.asarray(bild).astype(float)
    m0 = a.reshape(-1, 3).mean(axis=0)
    k0, r0 = fog(a)
    print("  kalla %s  %dx%d  ton (%d,%d,%d)  mättnad %.0f  fog %.2f/%.2f" % (
        KALLA, bild.width, bild.height, m0[0], m0[1], m0[2],
        (a.max(axis=2) - a.min(axis=2)).mean(), k0, r0))
    ## ORDNINGEN SPELAR ROLL. MÄTT: lades medelvärdet mot måltonen FÖRE gamman blev resultatet
    ## (31,41,44) i stället för (52,66,70) — kurvan drog ner det igen. Gamman och kontrasten först,
    ## tonen sist: då landar medelvärdet exakt.
    a = 255.0 * np.power(np.clip(a, 0, 255) / 255.0, GAMMA)
    m1 = a.reshape(-1, 3).mean(axis=0)
    a = m1 + (a - m1) * KONTRAST                     # halverad kontrast, inget som sticker ut
    m2 = a.reshape(-1, 3).mean(axis=0)
    a = a * (MALTON / m2)                            # medelvärdet till konceptbildens vatten, sist
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(UT)
    b = np.asarray(Image.open(UT).convert("RGB")).astype(float)
    m2 = b.reshape(-1, 3).mean(axis=0)
    k1, r1 = fog(b)
    print("  efter: ton (%d,%d,%d)  mättnad %.0f  99-percentil %.0f  fog %.2f/%.2f" % (
        m2[0], m2[1], m2[2], (b.max(axis=2) - b.min(axis=2)).mean(), np.percentile(b, 99), k1, r1))
    print("  mål: konceptbildens vatten (52,66,70), mättnad 25, fog under 1,0 = osynlig")
    print("  plattan kaklas: 1024 px per meter över ytan")

if __name__ == "__main__":
    main()
