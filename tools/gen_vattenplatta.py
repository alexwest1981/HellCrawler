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
BREDD = 1536
MATTNAD = 0.42      # hur mycket färgen dras mot sin egen ljushet (dov natt)               # 14:1 mot ytans 42,22 x 3,01 m

def main():
    bild = Image.open(os.path.join(PAKET, KALLA)).convert("RGB")
    print("  kalla %s  %dx%d" % (KALLA, bild.width, bild.height))
    ## HELA bilden, inte ett band. MÄTT: ett 14:1-band gav 109 px på höjden, alltså 36 px per
    ## meter över klippans 3 m — byns övriga plattor ligger på 512 px per meter, och blockigheten
    ## syntes i renderingen. Formatet spelar ingen roll (hela plattan läggs över ytan och sträcks
    ## dit), men upplösningen gör det: 798 px över 3 m ger 266 px per meter, alltså i klass med
    ## byn. Sidledes sträcks bilden till 14:1, vilket för vatten blir mjuka horisontella drag.
    platta = bild.resize((BREDD, max(8, round(BREDD * bild.height / bild.width))), Image.LANCZOS)
    ## NATTLÄGE. Alex 15/10: "Sänk ljuset på vattnet, då det skall vara kväll/natt i spelet när man
    ## är i byn." MÄTT: plattan höll medel 93 och en 99-percentil på 222 — de vita vågkammarna.
    ## En rak faktor sänker medelvärdet men lämnar kammarna kvar (255 x 0,58 = 148, alltså ändå
    ## ljusast i byn, och renderingen dömde: "lyser starkt och sticker ut oproportionerligt").
    ## En gamma drar ner mitten och de ljusa mer än de mörka, faktorn sätter taket.
    ## DEN MÖRKA KANTEN. MÄTT: bildens översta rader är mycket mörkare än resten (medel 22..26
    ## mot 58 i mitten, max 36 mot 183) — en ram i paketets renderade bild. Lades den med blev det
    ## ett svart band där klippans ytor möts; renderingen kallade det "en grov renderingsmiss".
    ## Kanten hittas med mätning, inte med en gissad procentsats: skala bort rader så länge radens
    ## medel ligger under halva bildens.
    a0 = np.asarray(platta).astype(float)
    mitt = a0.reshape(-1, 3).mean()
    topp = 0
    while topp < a0.shape[0] // 4 and a0[topp].mean() < mitt * 0.6:
        topp += 1
    if topp:
        platta = platta.crop((0, topp, platta.width, platta.height))
        print("  mörk kant bortskalad: %d rader i överkant" % topp)
    g, f = 1.45, 0.72
    a = np.asarray(platta).astype(float)
    m0, h0 = a.reshape(-1, 3).mean(), np.percentile(a, 99)
    platta = Image.fromarray(np.clip(255.0 * np.power(a / 255.0, g) * f, 0, 255).astype(np.uint8))
    ## MÄTTNADEN. MÄTT: plattan höll 38,5 i mättnad (max-min per pixel) mot 24,7 i konceptbildens
    ## vatten — den låg kvar som klarblå medan byn är dov, och renderingen dömde två gånger att
    ## vattnet "lyser starkare" trots att medelvärdet var rätt. En dov natt drar därför ut färgen
    ## mot sin egen ljushet.
    b = np.asarray(platta).astype(float)
    ljus = b @ np.array([0.299, 0.587, 0.114])
    b = b * (1 - MATTNAD) + ljus[:, :, None] * MATTNAD
    platta = Image.fromarray(np.clip(b, 0, 255).astype(np.uint8))
    b = np.asarray(platta).astype(float)
    print("  nattkurva gamma %.2f faktor %.2f:  medel %.0f -> %.0f   99-percentil %.0f -> %.0f" % (
        g, f, m0, b.reshape(-1, 3).mean(), h0, np.percentile(b, 99)))
    print("  mättnad %.1f -> %.1f   (konceptbildens vatten 24,7)" % (
        (a0.max(axis=2) - a0.min(axis=2)).mean(), (b.max(axis=2) - b.min(axis=2)).mean()))
    platta.save(UT)
    a = np.asarray(platta).astype(float)
    print("  plattan %dx%d  ton (%d,%d,%d)  variation %.2f" % (
        platta.width, platta.height, *a.reshape(-1, 3).mean(axis=0),
        np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean()))
    print("  ingen upprepning: hela plattan laggs over ytan")

if __name__ == "__main__":
    main()
