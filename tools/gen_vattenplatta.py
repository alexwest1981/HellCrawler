"""Skär vattenplattan ur Alex' vattenpaket, med ytans format och utan upprepning.

Alex 15/10: "Cliff_Face, kan vi byta den mot en vattentextur ... @folder:Downloads/Textures/Water".

TRE VÄGAR PROVADE, ALLA MÄTTA:
 1. Paketrutan kaklad 256 -> 512. Fogen 8,60/5,79 (synlig), och kantblandning gav 27,9 nivåer
    mot rutans egna 3,5.
 2. Speglad ruta. Fogen exakt 0,00 — men renderingen dömde: "tydliga upprepade skarvar och ett
    rutmönster där texturen spegelvänds". Spegling av en riktningskänslig yta blir ett kalejdoskop.
 3. Konceptbildens vatten, speglat. Slätare (1,15), men paketets vågkam syns ändå: "pixlad
    damast, Rorschach-liknande former". Fogen mäter kanten, inte symmetrin.

LÄRDOMEN: en 42 m yta kan inte täckas med en upprepad liten ruta ur en strukturerad textur. Hela
plattan läggs därför över ytan (HELA_YTAN i kedjan), och då plattans format görs efter ytans
(42,22 x 3,01 m = 14:1) blir ingenting utsträckt heller. Ingen upprepning, ingen fog, ingen
symmetri — och ingen skarv att dölja.
"""
import os
import numpy as np
from PIL import Image

PAKET = os.path.expanduser("~/Downloads/Textures/Water")
UT = "/home/alex/Projects/hellcrawlers/game/assets/by/tex/vatten.png"
KALLA = "2/2.png"          # den mest kaklingsbara rutan i paketet (mätt)
BREDD = 1536               # 14:1 mot ytans 42,22 x 3,01 m

def main():
    bild = Image.open(os.path.join(PAKET, KALLA)).convert("RGB")
    print("  kalla %s  %dx%d" % (KALLA, bild.width, bild.height))
    ## HELA bilden, inte ett band. MÄTT: ett 14:1-band gav 109 px på höjden, alltså 36 px per
    ## meter över klippans 3 m — byns övriga plattor ligger på 512 px per meter, och blockigheten
    ## syntes i renderingen. Formatet spelar ingen roll (hela plattan läggs över ytan och sträcks
    ## dit), men upplösningen gör det: 798 px över 3 m ger 266 px per meter, alltså i klass med
    ## byn. Sidledes sträcks bilden till 14:1, vilket för vatten blir mjuka horisontella drag.
    platta = bild.resize((BREDD, max(8, round(BREDD * bild.height / bild.width))), Image.LANCZOS)
    platta.save(UT)
    a = np.asarray(platta).astype(float)
    print("  plattan %dx%d  ton (%d,%d,%d)  variation %.2f" % (
        platta.width, platta.height, *a.reshape(-1, 3).mean(axis=0),
        np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean()))
    print("  ingen upprepning: hela plattan laggs over ytan")

if __name__ == "__main__":
    main()
