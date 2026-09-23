#!/usr/bin/env python3
"""Kortikoner ur Alex' ark: han ritade materialet, koden klipper och färgsätter.

Alex: *"Du fick en bildfil med tonvis av potions, du borde kunna använda någon av dem på Vial"*
(sagt om `Vial`, som visades med ett gult frågetecken i spelet).

Källan är hans egna ark i `game/images/` (potionsarket: tjugo flaskor i två rader, var och en i sin
ruta med namnet under). Verktyget klipper flaskan ur rutan, skalar till kortikonens 64x64 och lägger
färgerna på spelets palett — ikonerna i spelet delar palett med allt annat, och `test_assets.gd`
fäller en ikon som har en färg utanför.

    python3 tools/gen_card_icons.py            # skriver game/assets/cards/<kort-id>.png
    godot --headless --path game --import      # OBS: en ny PNG syns inte i spelet forran den importerats
    python3 tools/gen_card_icons.py --check    # mäter: 64x64, tät nog, bara palettfärger
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_enemy_sheet import bakgrund, kluster          # samma klippmekanik som fiendearket

ROOT = Path(__file__).resolve().parent.parent
UT = ROOT / "game" / "assets" / "cards"
ARK = ROOT / "game" / "images" / "Gemini_Generated_Image_7gasso7gasso7gas.jpeg"
ARK_VAPEN = ROOT / "game" / "images" / "Gemini_Generated_Image_62jqhj62jqhj62jq.jpeg"
PALETT = ROOT / "game" / "assets" / "palette.json"

SIDA = 128                 # kortikonens mått. 64 var för litet: Alex' potionsark har 2-5 källpixlar
                           # per konstpixel (mätt: kantavstånden i arket), så en flaska är ~200
                           # konstpixlar hög, och 64-duken skalade ned hans konst 3 gånger — samma fel
                           # som fienderna hade i M76, och samma svar: duken i konstens egen
                           # storleksordning. 128 är dubbelt mot förut (Alex om korten: *"pixeltätheten
                           # på korten behöver dubbleras eller mer"*), 1,6 gånger ned från arket i
                           # stället för 3, och stort kort ritar den i steg 2 = 2 dukpixlar per
                           # konstpixel mot 4 förut (mätt i kortvalsprovet: ikonrutan är 290 px).
MARGINAL = 2               # luft runt figuren, annars ser ikonen klippt ut
RUTKANT = 10               # px innanför rutans ram: ramen är inte en del av flaskan

# RUTA I ARKET -> KORT. Rutorna räknas vänster till höger, uppifrån och ned (0-9 överst, 10-19
# underst), och namnen är Alex' egna etiketter under varje flaska. Bara flaskor som FAKTISKT passar
# kortet mappas: en klocka ska inte ha en dryck som ikon, hur fin drycken än är.
KARTA = {
    1: "vial",            # Health potion — liten vial med röd vätska (kortet: "Heal 1 HP")
    2: "wild_mana",       # Mana potion — blå, månskärekork (kortet ger mana)
    11: "wild_ember",     # Flaridy elixir — brinnande orange (kortet heter Wild Ember)
    18: "whiteout",       # Potion of fortitude — isblå kristallin (kortet är köld)
    10: "wellspring",     # Stone-skin Elixir — krus (kortet är en källa/flaska, inte en dryck)
}


# VAPENARKET (20 rutor, samma uppbyggnad som flaskarket). Alex: *"det finns många vapen, hjältar
# osv"* — kvar att fylla var 21 kort utan bild, och åtta av dem ÄR vapen. Kopplingen följer samma
# regel som för flaskorna: bara där bilden passar kortet. En klocka får ingen yxa, och en dolk får
# inte lånas ut till två kort — de 21 räknas ner, inte bort.
KARTA_VAPEN = {
    17: "whiplash",        # piska (kortet: en piska)
    2: "leech_dagger",     # dolk
    4: "marrow_axe",       # dubbelyxa
    10: "chalk_flail",     # gissel med spikklot
    11: "hooked_ward",     # hillebard, kroken i namnet
    19: "warlock_shard",   # mörk klinga
    5: "brass_oath",       # stridshammare
    13: "seam_weaver",     # stav
}
ARKOR = {"flaskor": (ARK, KARTA), "vapen": (ARK_VAPEN, KARTA_VAPEN)}

# FÖRMÅGS- OCH FÖREMÅLSARKEN har inte samma rutor som flask- och vapenarken: de är hela paneler
# med ikoner och en etikett under varje, och klustringen hittar dem inte (mätt: 1 område i stället
# för 40). Därför läses de med OCR: etiketten ger ikonens x-läge, och ikonen ligger i bandet rakt
# ovanför den. Raderna ligger 203 px isär på förmågsarket; etiketten är ~28 px hög.
ARK_FORMAGOR = ROOT / "game" / "images" / "Gemini_Generated_Image_nsl5ocnsl5ocnsl5.jpeg"
ARK_FOREMAL = ROOT / "game" / "images" / "Gemini_Generated_Image_fuhnl5fuhnl5fuhn.jpeg"
ARK_HJALTAR = ROOT / "game" / "images" / "Gemini_Generated_Image_5xtdaw5xtdaw5xtd.jpeg"
ARK_ARSENAL = ROOT / "game" / "images" / "Gemini_Generated_Image_mz0drkmz0drkmz0d.jpeg"
# (kort, ark, etikettens x-mitt, etikettens överkant). Kopplingen följer samma regel som förut:
# bara där bilden passar kortet. En klocka får ingen sköld, och fyra klockkort står kvar utan bild
# — arken har ingen klocka.
KORT_UR_BAND = [
    ("ward",            ARK_FORMAGOR, 1817,  202),   # Shield Bash — en sköld
    ("wild_aegis",      ARK_FORMAGOR, 1541,  410),   # Divine Shield — ett sköldemblem
    # Blixtens fönster är smalare: med 250 px kom etiketten intill med i bandet (mätt: "SLASH"
    # låg kvar i ikonens överkant efter två trimmningar).
    ("twitch",          ARK_FORMAGOR,  665,  410, 160),   # Lightning — en stöt
    ("icicle_storm",    ARK_FORMAGOR, 1266, 1224),   # Resist Cold — is
    ("tallow_dagger",   ARK_FORMAGOR, 2098,  205),   # Dagger Toss — en dolk
    ("wicksister",      ARK_FORMAGOR,  414, 1224),   # Regeneration — läkning
    ("scrying_pebbles", ARK_HJALTAR,  2097, 1424),   # gem — en sten
    ("warding_ring",    ARK_FOREMAL,   990, 1424),   # Signet ring — en ring
    # ARSENAL: ADVENTURING GEAR (mz0drk): arket har samma uppbyggnad som förmågsarken — paneler med
    # etikett under, ingen ruta att klippa ur (mätt: klustringen hittar ETT område, precis som för
    # förmågorna). Raden med föremål ligger y ≈ 785-1490, ikonerna y ≈ 845-1290 och etiketterna från
    # y ≈ 1326 — därför höjd=480 i stället för standardens 195, annars klipps klockans överdel av.
    # Alex' fyra klockor och fyra kritor matchar de fem kort som stod utan bild. Klockorna sitter i
    # panel 1-4 (x ≈ 290/840/1380/1930), kritorna i fyra smalare fack i panel 5 (x ≈ 2275-2665).
    # Rutnätet mättes två gånger och siffrorna kom från FACKEN, inte från en gissning: klockornas
    # ikoner sitter på x ≈ 235/625/990/1445 och kritorna på x ≈ 1855/2110/2370/2630 (8 fack i den
    # nedre raden, etiketterna bekräftade både av OCR-raden och av klippet). Bredden hålls under
    # fackbredden så att grannens kant inte kan bli den största figuren i fönstret.
    ("bell_of_rites",   ARK_ARSENAL,   235, 1326, 340, 480, True),   # Ritual Bell (Bronze)
    ("frost_bell",      ARK_ARSENAL,   625, 1326, 340, 480, True),   # Alarm Bell (Silver)
    # Varningsklockan hänger högre än de andra och miste sin upphängning med standardhöjden (mätt två
    # gånger: 237 px hög och avklippt, sedan 392 px hög och hel). Fönstret går därför ned till y 786,
    # strax under raddelaren på y ≈ 780 — annars kommer raden ovanför med i klippet.
    ("iron_chime",      ARK_ARSENAL,   990, 1326, 340, 540, True),   # Warning Bell (Iron)
    ("shrouded_bell",   ARK_ARSENAL,  1445, 1326, 340, 480, True),   # Holy Bell (Gilded)
    ("wild_chalk",      ARK_ARSENAL,  1855, 1326, 240, 480, True),   # Chalk (White) — en krita
]


def rutor(img: Image.Image) -> list:
    """Arkets tjugo rutor som (x0, y0, x1, y1), i läsordning. Rutorna hittas som sammanhängande
    områden i figuren — ramen runt varje ruta är figurens kant, och insidan hänger inte ihop med
    bildens ytterkant, så varje ruta blir ett eget område."""
    a = np.asarray(img.convert("RGB")).astype(int)
    figur = ~bakgrund(a.mean(axis=2))
    delar = [d for d in kluster(figur, 5000) if d[4] > 20000]
    delar.sort(key=lambda d: (round(d[1] / 300), d[0]))
    return delar


def klipp(img: Image.Image, ruta) -> Image.Image:
    """Flaskan ur sin ruta: innanför ramen, och sedan allt som inte hänger ihop med rutan bakgrund."""
    x0, y0, x1, y1 = ruta[0] + RUTKANT, ruta[1] + RUTKANT, ruta[2] - RUTKANT, ruta[3] - RUTKANT
    cell = np.asarray(img.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGB")).astype(int)
    inne = ~bakgrund(cell.mean(axis=2))
    prickar = kluster(inne, 200)
    if not prickar:
        return None
    storst = max(prickar, key=lambda d: d[4])
    # Glöden kring flaskan (partiklar, aura) ligger i flera små områden. De hör till figuren, men
    # bara om de sitter NÄRA den: ett litet skräp i rutan ska inte bli en egen flaska.
    nära = [d for d in prickar if d[4] > 60 and abs(d[0] - storst[0]) < 60 and abs(d[1] - storst[1]) < 60]
    xs = min(d[0] for d in nära); ys = min(d[1] for d in nära)
    xe = max(d[2] for d in nära); ye = max(d[3] for d in nära)
    return img.crop((x0 + xs, y0 + ys, x0 + xe + 1, y0 + ye + 1)).convert("RGB")


def klipp_band(im: Image.Image, cx: int, etikett_y: int, bredd: int = 250, höjd: int = 195,
        hela: bool = False) -> Image.Image:
    """Ikonen i bandet ovanför sin etikett.

    Skillnaden mellan en ikon och en etikettrad är TJOCKLEKEN: en ikonrad har tusentals ljusa
    pixlar, en textrad några hundra. Bandet tas därför där raderna är ljusa, med en låg tröskel
    (8 % av rutans max) så att ikonens över- och underkant följer med — en hög tröskel klippte av
    både sköldens kant och dolkens fäste (mätt i två försök).
    """
    a = np.asarray(im.convert("L"), dtype=float)
    h, w = a.shape
    x0, x1 = max(0, cx - bredd // 2), min(w, cx + bredd // 2)
    y0, y1 = max(0, etikett_y - höjd), min(h, etikett_y - 18)
    fönster = a[y0:y1, x0:x1]
    if fönster.size == 0:
        return None
    ljus = fönster > 42
    per_rad = ljus.sum(axis=1)
    if per_rad.max() <= 0:
        return None
    rader = np.where(per_rad > per_rad.max() * 0.08)[0]
    if len(rader) == 0:
        return None
    if hela:
        # Ark med fack och tomma ytor (arsenalen): längsta sammanhängande ljusa raden är bara klockans
        # blanka nederkant — den mörka metallen ovanför är inte "ljus" nog. Här tas hela spannet från
        # första till sista ljusa raden i stället, och den andra passningen nedan rensar bort textrader.
        bästa = (int(rader[0]), int(rader[-1]))
    else:
        bästa, nu = (rader[0], rader[0]), (rader[0], rader[0])
        for r in rader[1:]:
            nu = (nu[0], r) if r - nu[1] <= 2 else (r, r)
            if nu[1] - nu[0] > bästa[1] - bästa[0]:
                bästa = nu
    band = ljus[bästa[0]:bästa[1] + 1, :]
    per_kol = band.sum(axis=0)
    kol = np.where(per_kol > max(1, per_kol.max() * 0.05))[0]
    if len(kol) == 0:
        return None
    ruta = im.crop((x0 + int(kol[0]), y0 + int(bästa[0]), x0 + int(kol[-1]) + 1,
        y0 + int(bästa[1]) + 1)).convert("RGB")
    # Andra passningen: bandet kan ha fått med en textrad som låg tätt intill (mätt: "SLASH" ovanför
    # blixten). Textraden är GLES — den har långt färre ljusa pixlar per rad än ikonen — så samma
    # mätning körs en gång till med hög tröskel och klipper bort det som inte är ikon.
    b = np.asarray(ruta.convert("L"), dtype=float)
    ljus2 = b > 42
    per_rad2 = ljus2.sum(axis=1)
    om2 = per_rad2.max() * 0.35
    rader2 = np.where(per_rad2 > om2)[0]
    if len(rader2) > 4:
        return ruta.crop((0, int(rader2[0]), ruta.width, int(rader2[-1]) + 1))
    return ruta


def ikon(flaska: Image.Image, palett: Image.Image) -> Image.Image:
    """Flaskan till SIDA x SIDA på paletten. BOX (medelvärde) och inte NEAREST: arket skalas ned, och
    nearest hade plockat enstaka pixlar ur varje block."""
    mål = SIDA - 2 * MARGINAL
    f = flaska.copy()
    f.thumbnail((mål, mål), Image.BOX)
    duk = Image.new("RGB", (SIDA, SIDA), (0, 0, 0))
    duk.paste(f, ((SIDA - f.width) // 2, (SIDA - f.height) // 2))
    # Paletten läggs på RGB, och bakgrunden blir genomskinlig EFTERÅT: quantize rör bara färgerna, och
    # en genomskinlig kant hade blivit svart om alfakanalen varit med i räkningen.
    duk = duk.quantize(palette=palett, dither=Image.NONE).convert("RGB")
    ut = duk.convert("RGBA")
    a = np.asarray(ut).copy()
    a[:, :, 3] = 255
    # Allt utanför figuren är den döda vinkeln: originalets svarta hörn blir genomskinliga.
    korn = np.asarray(flaska.resize((f.width, f.height), Image.BOX).convert("L"))
    mask = np.zeros((SIDA, SIDA), dtype=np.uint8)
    mask[(SIDA - f.height) // 2:(SIDA - f.height) // 2 + f.height,
         (SIDA - f.width) // 2:(SIDA - f.width) // 2 + f.width] = (
        korn > 16).astype(np.uint8) * 255
    a[:, :, 3] = mask
    return Image.fromarray(a, "RGBA")


def main() -> int:
    palett = Image.new("P", (1, 1))
    färger = [tuple(c) for c in json.loads(PALETT.read_text())]
    platt = [v for c in färger for v in c]
    palett.putpalette(platt + [0] * (768 - len(platt)))
    if "--check" in sys.argv:
        fel = 0
        alla = [(namn, r, kid) for namn, (_, karta) in ARKOR.items() for r, kid in karta.items()]
        alla += [("band", i, rad[0]) for i, rad in enumerate(KORT_UR_BAND)]
        for namn, r, kid in sorted(alla, key=lambda x: x[2]):
            p = UT / ("%s.png" % kid)
            if not p.exists():
                print("  FEL  %s saknas" % p.name); fel += 1; continue
            img = Image.open(p).convert("RGBA")
            a = np.asarray(img).astype(int)
            if img.size != (SIDA, SIDA):
                print("  FEL  %s är %s" % (p.name, img.size)); fel += 1; continue
            täckta = int((a[:, :, 3] > 128).sum())
            utanför = 0
            for c in np.unique(a[:, :, :3][a[:, :, 3] > 128].reshape(-1, 3), axis=0):
                if tuple(int(v) for v in c) not in {tuple(x) for x in json.loads(PALETT.read_text())}:
                    utanför += 1
            if täckta < SIDA * SIDA / 20:
                print("  FEL  %s är för tom (%d px)" % (p.name, täckta)); fel += 1
            if utanför:
                print("  FEL  %s har %d färger utanför paletten" % (p.name, utanför)); fel += 1
            if not fel:
                print("  ok   %s (ruta %d, %d px täckta)" % (p.name, r, täckta))
        # Antalet ARK räknas ur källorna, inte ur grupperna: raden sa "2 ark" medan band-korten kom
        # ur tre ark till (mätt: texten påstod något annat än koden gjorde).
        ark_antal = len({str(f) for _, (f, _) in ARKOR.items()} | {str(rad[1]) for rad in KORT_UR_BAND})
        print("  %d kortikoner ur %d ark, %d fel" % (len(alla), ark_antal, fel))
        return 1 if fel else 0
    UT.mkdir(parents=True, exist_ok=True)
    skrivna = 0
    for namn, (ark, karta) in ARKOR.items():
        if not ark.exists():
            print("arket saknas: %s" % ark.relative_to(ROOT), file=sys.stderr)
            return 1
        img = Image.open(ark)
        rutnät = rutor(img)
        if len(rutnät) < max(karta) + 1:
            print("hittade bara %d rutor i %s" % (len(rutnät), namn), file=sys.stderr)
            return 1
        for r, kid in sorted(karta.items()):
            figur = klipp(img, rutnät[r])
            if figur is None:
                print("  FEL  %s ruta %d (%s) gav ingenting" % (namn, r, kid))
                continue
            ikon(figur, palett).save(UT / ("%s.png" % kid))
            skrivna += 1
            print("  %-14s <- %s ruta %2d  (%dx%d px)" % (kid, namn, r, figur.width, figur.height))
    for rad in KORT_UR_BAND:
        var_ = list(rad) + [250, 195, False]      # (kort, ark, cx, etikett_y, bredd, höjd, hela)
        kid, ark, cx, etikett_y, bredd = var_[0], var_[1], var_[2], var_[3], var_[4]
        höjd, hela = int(var_[5]), bool(var_[6])
        if not ark.exists():
            print("arket saknas: %s" % ark.relative_to(ROOT), file=sys.stderr)
            return 1
        figur = klipp_band(Image.open(ark), cx, etikett_y, int(bredd), höjd, hela)
        if figur is None:
            print("  FEL  %s: inget band ovanför etiketten" % kid)
            continue
        ikon(figur, palett).save(UT / ("%s.png" % kid))
        skrivna += 1
        print("  %-14s <- band %4d,%4d  (%dx%d px)" % (kid, cx, etikett_y, figur.width, figur.height))
    print("skrev %d ikoner i %s" % (skrivna, UT.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
