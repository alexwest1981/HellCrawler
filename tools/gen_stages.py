#!/usr/bin/env python3
"""Genererar HellCrawlers banor ur en kurva.

Alex: *"det skall ta tid att gå genom en bana"* och *"vi kanske behöver skapa ett gäng banor till,
typ så vi har 80-90 banor"*, och om namnen: *"bara nya namn osv, återanvänd merparten av det vi har
idag, mixa och matcha så gott det går så länge, så fixar jag mer material så länge"*.

Därför läser verktyget de 40 befintliga banfilerna och återanvänder deras namn, teman och bossar:

  * stage_01..40 behåller sina namn och teman exakt som de är.
  * stage_41..89 får nya namn, mixade ur ordbankerna nedan (byggda av de befintliga namnen).
  * stage_90 behåller "Första ugnen" - den sista banan hette så, och ska fortsätta heta det.

Storleken och svårighetsgraden kommer ur kurvan i docs/skilltree.md: band 1-15 ar 5 vaningar x 6 moten,
band 85-90 ar 12 x 10. Svårighetsgraden går 1..30 i stället för 1..9, eftersom formlerna i run.gd:17-19
redan är linjära och bara behövde mer spann.

Kör:  python3 tools/gen_stages.py            (skriver om alla 90 filerna)
       python3 tools/gen_stages.py --check    (skriver ingenting, granskar bara)  [alias: --kontroll]
"""
import json
import os
import sys

ROT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGES = os.path.join(ROT, "game", "data", "stages")
BESTIARY = os.path.join(ROT, "game", "data", "enemies", "00_bestiary.json")
ANTAL = 90


def tiers_i_bestiariet():
    """Tiers som FAKTISKT har fiender, ur bestiariet.

    Den gamla raden var `[(nr - 1) // 15 + 1]`, alltså en tier var femtonde bana upp till sex. Men
    bestiariet har TRE tiers (17 fiender: 4 i tier 1, 4 i tier 2, 9 i tier 3). Från stage_46 och framåt
    bad varje bana därför om en tier utan fiender, fick en tom pool, och spelet kunde inte bygga
    våningen alls — dungeon.gd indexerade den tomma listan, generate returnerade null, och provet
    hängde i stället för att säga att stage_46 saknade fiender i tier 4. Halva spelet var obyggbart.

    Generatorn läser därför bestiariet i stället för att gissa, och kurvan fördelar de 90 banorna
    jämnt över de tiers som finns. Växer bestiariet följer banorna med, utan att någon behöver komma
    ihåg ett tak.
    """
    db = json.load(open(BESTIARY, encoding="utf-8"))
    rader = db if isinstance(db, list) else list(db.values())
    return sorted({int(e["tier"]) for e in rader})


TIERS = tiers_i_bestiariet()

# Ordbanker byggda av de 40 befintliga namnen. LED markerar om en stavelse star i genitiv (Kalkens tar)
# eller ar ett adjektiv (Branda vreten) - bada ger samma form pa subjektet, och det ar spelets egen
# stil sedan de 40 forsta banorna.
LED = [
    ("Askans", "gen"), ("Brända", "adj"), ("Kalla", "adj"), ("Första", "adj"), ("Andra", "adj"),
    ("Koppargruvans", "gen"), ("Gruvgångens", "gen"), ("Ärggångens", "gen"), ("Myrens", "gen"),
    ("Kärrets", "gen"), ("Kalkens", "gen"), ("Kalkbrottets", "gen"), ("Blekta", "adj"),
    ("Krittornets", "gen"), ("Ribbgångens", "gen"), ("Kraniernas", "gen"), ("Märgens", "gen"),
    ("Benhusets", "gen"), ("Saltets", "gen"), ("Torkade", "adj"), ("Spegelns", "gen"),
    ("Klockornas", "gen"), ("Ringmurens", "gen"), ("Dova", "adj"), ("Klockmoderns", "gen"),
    ("Glasets", "gen"), ("Smältans", "gen"), ("Blåsterns", "gen"), ("Kupolens", "gen"),
    ("Sista", "adj"), ("Yttre", "adj"), ("Inre", "adj"), ("Nedre", "adj"), ("Övre", "adj"),
    ("Gömda", "adj"), ("Glömda", "adj"), ("Tysta", "adj"), ("Vita", "adj"), ("Svarta", "adj"),
    ("Svala", "adj"),
]

SUB = [
    "djuphålet", "vreten", "klyftan", "munnen", "hjärtat", "tystnaden", "tåren", "kammaren", "gången",
    "kryptan", "pelaren", "rummet", "hallen", "brunnen", "spegeln", "domen", "tornet", "valvet",
    "gjutningen", "skuggan", "ugnen", "salen", "trappan", "porten", "hålan", "glöden", "askan",
    "svalget", "mörkret", "kanten", "branten", "gapet", "muren", "lagen", "ringen", "kitteln",
    "vinden", "valen", "malmen", "sanden", "leran", "röken", "slagg", "sotet", "glaskupan",
]

TEMAN = ["asklunden", "bro", "grotta", "krypta", "tunnel"]
BOSSAR = ["hollow_choir", "copper_warden", "bellmother", "ash_sovereign"]
SLUTBOSS = "pale_reaper"

# Kurvan ur docs/skilltree.md: (forsta_bana, sista_bana, svarighetsgrad_fran, till, vaningar_fran, till,
#  moten_fran, till)
BAND = [
    (1, 15, 1, 4, 5, 5, 6, 6),
    (16, 35, 5, 9, 6, 8, 7, 7),
    (36, 55, 10, 14, 8, 10, 8, 8),
    # Bandens startvärde måste fortsätta där det förra slutade, annars DIPPAr kurvan: band 4 började
    # på 9 våningar efter att band 3 slutat på 10, så stage_55 hade 10 våningar och stage_56 nio —
    # och band 5 började på 10 efter 11, samma sak vid stage_72/73. Mätt med ett svep över alla 90
    # filer (difficulty och möten steg bara; våningarna föll två gånger). Alex: "det skall ta tid att
    # gå genom en bana" — en bana som blir KORTARE längre in i spelet motsäger det.
    (56, 72, 15, 19, 10, 11, 9, 9),
    (73, 84, 20, 24, 11, 12, 10, 10),
    (85, 90, 25, 30, 12, 12, 10, 10),
]


def _sprid(fran, till, n, i):
    """Jamn spridning over bandet, sa siffrorna vaxer utan trappsteg."""
    if n <= 1:
        return till
    return fran + round((till - fran) * i / (n - 1))


def kurva(nr):
    """Svårighetsgrad, våningar och möten per våning för bana nr (1..90)."""
    for (a, b, sf, st, vf, vt, mf, mt) in BAND:
        if a <= nr <= b:
            i = nr - a
            n = b - a
            return (_sprid(sf, st, n + 1, i), _sprid(vf, vt, n + 1, i), _sprid(mf, mt, n + 1, i))
    raise SystemExit("bana %d ligger utanfor kurvan" % nr)


def las_befintliga():
    """De 40 banor som redan finns, i nummerordning."""
    ut = {}
    for nr in range(1, 41):
        p = os.path.join(STAGES, "stage_%02d.json" % nr)
        if os.path.exists(p):
            ut[nr] = json.load(open(p, encoding="utf-8"))
    return ut


def nya_namn(antal, tagna):
    """Mixade namn ur ordbankerna. Båda listorna stegas med coprima tal (7 mot 40, 13 mot 45) så att
    leden och subjekten möts i ny kombination varje gång i stället för att en av dem står still."""
    ut = []
    i = j = 0
    varv = 0
    while len(ut) < antal:
        varv += 1
        if varv > 20000:
            raise SystemExit("ordbankerna räcker inte till %d unika namn" % antal)
        namn = "%s %s" % (LED[i % len(LED)][0], SUB[j % len(SUB)])
        i += 7
        j += 13
        if namn in tagna:
            continue
        tagna.add(namn)
        ut.append(namn)
    return ut


def bygg(nr, befintliga, namn, tagna_namn):
    svarighet, vaningar, moten = kurva(nr)
    gammal = befintliga.get(nr)
    # Namnet kommer färdigbestämt från main() — en plats som bestämmer, en plats att ändra.
    tema = (gammal or {}).get("theme") or TEMAN[(nr - 1) % len(TEMAN)]
    golv = [TEMAN[(nr + k) % len(TEMAN)] for k in range(vaningar)]
    boss = (gammal or {}).get("boss") or BOSSAR[min(len(BOSSAR) - 1, svarighet // 8)]
    return {
        "id": "stage_%02d" % nr,
        "name": namn,
        "difficulty": int(svarighet),
        "floors": int(vaningar),
        "encounters_per_floor": int(moten),
        "floor_themes": golv,
        "boss": boss,
        "bosses": (gammal or {}).get("bosses", []),
        "final_boss": SLUTBOSS if nr == ANTAL else "",
        "gold_bonus": round(0.02 * (nr - 1), 2),
        "xp_bonus": 0.0,
        "theme": tema,
        "tiers": [TIERS[min(len(TIERS) - 1, (nr - 1) * len(TIERS) // ANTAL)]],
        "regel": "",
    }


# Kartans nya platser, i samma stil som de tio som redan står där. De läggs mitt emellan de gamla,
# alltså mellan två namn som redan beskriver samma trakt.
NYA_PLATSER = ["Askskogen", "Kalkbranten", "Benfältet", "Saltängen", "Klockgraven", "Glasöknen",
               "Slaggfälten", "Ugnsbranten"]


def skriv_karta(ut, torr=False):
    """Skriver om karta.json så kartan rymmer alla banor.

    De tio platserna ritar en väg över en målad bild (varldskarta.png), med handplacerade koordinater.
    Nittio banor får plats som 18 platser med fem banor var, så de tio behåller sina namn, sin ordning
    och sina lägen, och åtta nya läggs i mittpunkten mellan dem — samma väg, utan nya handplacerade
    punkter. (Tio platser har nio mellanrum men det behövs bara åtta nya för att komma till 18, så det
    sista mellanrummet hoppas över; det går att dra i kart-editorn.) Namnen på de nya står i NYA_PLATSER
    och går att byta i samma editor.
    """
    vag = os.path.join(ROT, "game", "data", "karta.json")
    k = json.load(open(vag, encoding="utf-8"))
    gamla = k.get("noder", [])
    # Verktyget ska kunna köras om: första körningen utökar 10 platser till 18, senare körningar
    # fördelar bara banorna över de 18 igen (och behåller namn man ändrat i kart-editorn).
    if len(gamla) == 10:
        noder = []
        for i, n in enumerate(gamla):
            noder.append({"plats": n["plats"], "x": n["x"], "y": n["y"],
                          "sektion": n.get("sektion", 1), "nivåer": []})
            if i + 1 < len(gamla) and i < len(NYA_PLATSER):
                m = gamla[i + 1]
                noder.append({"plats": NYA_PLATSER[i], "x": round((n["x"] + m["x"]) / 2.0, 1),
                              "y": round((n["y"] + m["y"]) / 2.0, 1), "sektion": n.get("sektion", 1),
                              "nivåer": []})
    else:
        # Redan utökad (eller handredigerad i kart-editorn): fördela bara banorna över de platser som
        # finns. Delbarheten nedan är det som avgör om antalet duger — inte ett fast tal.
        noder = gamla
    antal_per = len(ut) // len(noder)
    if antal_per * len(noder) != len(ut):
        raise SystemExit("%d banor delas inte jämnt på %d platser" % (len(ut), len(noder)))
    for i, n in enumerate(noder):
        n["nivåer"] = [s["id"] for s in ut[i * antal_per:(i + 1) * antal_per]]
    alla = [i for n in noder for i in n["nivåer"]]
    if alla != [s["id"] for s in ut]:
        raise SystemExit("kartan täcker inte banorna i ordning — ingenting skrivet")
    k["noder"] = noder
    print("  kartan: %d platser x %d banor = %d nivåer" % (len(noder), antal_per, len(alla)))
    if torr:
        return
    with open(vag, "w", encoding="utf-8") as f:
        json.dump(k, f, ensure_ascii=False, indent=1)
        f.write("\n")


def granska(ut):
    """Kontrollen: allt som maste halla for att filerna ska vara spelbara."""
    fel = []
    idn = [s["id"] for s in ut]
    if idn != sorted(set(idn)):
        fel.append("id: dubbletter eller fel ordning")
    namn = [s["name"] for s in ut]
    dubbel = [n for n in set(namn) if namn.count(n) > 1]
    if dubbel:
        fel.append("namn som upprepas: %s" % dubbel[:5])
    for s in ut:
        if not s["floor_themes"] or len(s["floor_themes"]) != s["floors"]:
            fel.append("%s: floor_themes stammer inte med floors" % s["id"])
        if s["boss"] and s["boss"] not in BOSSAR:
            fel.append("%s: okand boss %s" % (s["id"], s["boss"]))
        if any(t not in TEMAN for t in s["floor_themes"]):
            fel.append("%s: okant tema" % s["id"])
        if s["difficulty"] < 1 or s["difficulty"] > 30:
            fel.append("%s: svarighetsgrad utanfor 1..30" % s["id"])
        if s["floors"] < 3 or s["encounters_per_floor"] < 1:
            fel.append("%s: for liten bana" % s["id"])
    if sum(1 for s in ut if s["final_boss"]) != 1:
        fel.append("final_boss maste finnas pa exakt en bana")
    if ut[-1]["final_boss"] != SLUTBOSS:
        fel.append("sista banan saknar %s" % SLUTBOSS)
    # kurvan ska vaxa, inte ga i back
    for a, b in zip(ut, ut[1:]):
        if b["difficulty"] < a["difficulty"]:
            fel.append("svarighetsgraden sjonker mellan %s och %s" % (a["id"], b["id"]))
    return fel


def main():
    # --check är standardnamnet i tools/ (14 andra generatorer har det, och tools/test_all.sh letar
    # efter just det). --kontroll behålls som alias så att inget handgrepp går förlorat.
    torr = "--check" in sys.argv or "--kontroll" in sys.argv
    befintliga = las_befintliga()
    # Namnen måste vara en FUNKTION av bana nummer, inte av vad som ligger på disken just nu. Poolen
    # byggdes förut ur alla befintliga filer ("tagna"), så andra körningen fick ett annat set än den
    # första — och stage_40, vars namn frigörs till "Första ugnen", bytte namn varannan gång. Mätt:
    # körning 1 och 3 gav c332c5f2…, körning 2 gav 167ce3a1…, och diffen var EN rad: stage_40:s namn.
    # Driftkontrollen i tools/test_all.sh hittade det genom att köra generatorn och jämföra.
    # stage_01..39 behåller sina namn för evigt och "Första ugnen" är reserverat, så poolen är stabil.
    tagna = {s["name"] for nr, s in befintliga.items() if nr < 40} | {"Första ugnen"}
    nya = nya_namn(ANTAL - 40, tagna)   # 50: stage_40 tappar sitt namn till sista banan
    ut = []
    for nr in range(1, ANTAL + 1):
        gammal = befintliga.get(nr)
        # De 40 första behåller sina namn exakt, med ett undantag: stage_40 hette "Första ugnen", och
        # den sista banan ska fortsätta heta det. stage_40 får ett mixat namn i stället.
        if nr == ANTAL:
            namn = "Första ugnen"
        elif gammal and nr != 40:
            namn = gammal["name"]
        else:
            namn = nya.pop(0)
        ut.append(bygg(nr, befintliga, namn, tagna))
    fel = granska(ut)
    if fel:
        for f in fel:
            print("FEL  %s" % f)
        raise SystemExit("%d fel - ingenting skrivet" % len(fel))
    tot_strider = sum(s["floors"] * s["encounters_per_floor"] for s in ut)
    print("%d banor kontrollerade, 0 fel" % ANTAL)
    print("  svarighetsgrad %d..%d   vaningar %d..%d   strider i spelet %d (var 1352)"
          % (ut[0]["difficulty"], ut[-1]["difficulty"], ut[0]["floors"], ut[-1]["floors"], tot_strider))
    if torr:
        print("  (--kontroll: ingenting skrivet)")
        return
    for s in ut:
        with open(os.path.join(STAGES, "%s.json" % s["id"]), "w", encoding="utf-8") as f:
            json.dump(s, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")
    print("  %d filer skrivna i game/data/stages/" % len(ut))
    skriv_karta(ut, torr)
    print("  nya namn: %s ..." % ", ".join(s["name"] for s in ut[40:44]))


if __name__ == "__main__":
    main()
