#!/usr/bin/env python3
"""Genererar HellCrawlers träd: game/data/tree.json, 4 grenar x 6 nivåer.

Alex: *"skill tree behöver vara permanent, men med så pass många noder att man måste spela spelet typ
20ggr"* och *"bara nya namn osv, återanvänd merparten av det vi har idag, mixa och matcha"*.

De 25 noder som redan finns behåller sina id:n, namn, effekter, priser och krav ORÖRDA — de är provade
i spel och test_meta räknar på dem. Verktyget LÄGGER TILL noder runt dem till sex nivåer per gren, och
skriver filen med samma form som förut.

Kronorna (nivå 6) bär sin mekanik som en TAGG (`crown`) i datat. Siffrorna de ger fungerar i spelet
direkt; taggen är där för att motorn ska kunna läsa dem när mekaniken byggs ("allt du slår på brinner",
"du reser dig tre gånger"). Att bygga mekaniken utan att datat finns hade varit att bygga två saker
samtidigt.

CS-priserna ligger i `soul_cost` och guldpriserna i `cost` lämnas orörda. Formen finns redan i metan:
`shard_cost` fungerar på exakt samma sätt (se meta.gd, next_shard_cost), så köpvägen för själar kan
läggas bredvid splitterna utan att röra guldets. Att byta `cost` till CS utan att byta köpvägen hade
gjort hela trädet gratis — priset hade lästs som guld.

    python3 tools/gen_tree.py            skriv game/data/tree.json
    python3 tools/gen_tree.py --check    skriv ingenting, mät bara (och visa ekonomin)
"""
import json
import os
import sys

ROT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAD = os.path.join(ROT, "game", "data", "tree.json")

# Grenarna och deras statistiknycklar (metans stat() känner dem). Ordningen är grenens ordning i
# vyn och i specen: Järnvägen (skada), Benknippet (tålighet och resning), Glöden (kort och mana),
# Girigheten (byte).
GRENAR = [
    ("Järnvägen", ["might", "area"]),
    ("Benknippet", ["max_hp", "armor", "recovery"]),
    ("Glöden", ["mana", "hand", "draw_first"]),
    ("Girigheten", ["gold", "gem_find", "chest_luck"]),
]

# Nivåerna och hur många noder varje gren har på dem. 22 per gren = 88 totalt (plus att de 25
# befintliga noderna placeras in på sin nivå i stället för att dubbleras).
NIVÅER = [1, 4, 5, 5, 5, 2]

# Priset i Corrupted Souls per RANG, ur docs/skilltree.md: nivå 1-2 kostar 1-3 CS, 3-4 kostar 4-9,
# nivå 5 kostar 10-18 och kronan 20-30.
PRIS = {1: [1, 2], 2: [2, 3, 3], 3: [4, 5, 6], 4: [6, 7, 9], 5: [10, 12, 15, 18], 6: [20, 30]}

# Effektens storlek per nivå, också ur specen: nivå 1-2 små steg (+2-4 %), 3-4 tydliga (+5-8 %),
# nivå 5 stora (+10-15 %), kronan ett språng.
STYRKA = {1: 0.02, 2: 0.03, 3: 0.05, 4: 0.07, 5: 0.12, 6: 0.30}

# Namnen på de nya noderna. Korta, i spelets ton: vad noden GÖR, inte vad den heter i en tabell.
ORD = {
    "Järnvägen": [("Vässad egg", "Slaggvikt", "Hammarfallet", "Glödgat grepp", "Stålets tunga",
                   "Bandad klinga", "Ugnshärd", "Bränd kant", "Städets slag", "Malmsmidd", "Rensad fog"),
                  ("Djupt hugg", "Bredare sving", "Två händer", "Genomträngande", "Klyvning",
                   "Smält slagg", "Eldspridning", "Skärvorna", "Härdat bett", "Ugnsvind")],
    "Benknippet": [("Tjockt ben", "Sparad hud", "Lappad läder", "Knytnäve", "Sammabit",
                    "Sårskorpa", "Gamla ärr", "Benmärg", "Härdad nacke", "Rakad rygg", "Sluten näve"),
                   ("Långsamt blod", "Ny hud", "Bensköld", "Stelnad", "Andra andetaget",
                    "Sista andetaget", "Resning", "Kvarleva")],
    "Glöden": [("Varm hand", "Snabb tanke", "Första draget", "Extra andetag", "Öppen hand",
                "Fylld näve", "Glödrök", "Skymt", "Första gnistan", "Tändved", "Lågan inne"),
               ("Brinnande kort", "Rykande drag", "Gnistregn", "Full hand", "Eldens rytm",
                "Andra handen", "Återtändning")],
    "Girigheten": [("Smal mynt", "Vass blick", "Kistlås", "Fickan", "Sprucken börs",
                    "Guldvikt", "Glittrande grus", "Räknad vinst", "Tom kista", "Rov", "Byten"),
                   ("Fet börs", "Ädelstenar", "Rik kista", "Dubbel fångst", "Girig hand",
                    "Guldfeber", "Skattkammare")],
}


def räkna_kronor():
    """Nivå 6 är grenens krona: en effekt som ändrar hur spelet spelas, plus sin tagg."""
    return {
        "Järnvägen": ("Ugnens gap", {"might": 0.30, "area": 0.25}, "burn",
                      "+30 % skada och allt du slår på brinner"),
        "Benknippet": ("Tre resningar", {"max_hp": 0.30, "revive": 2}, "three_revives",
                       "+3 resningar i stället för 1"),
        "Glöden": ("Full hand varje tur", {"hand": 3, "draw_first": 2}, "full_hand",
                   "Handen fylls till fullt varje tur"),
        "Girigheten": ("Rikets pris", {"gold": 0.50, "curse": 0.20}, "double_reward",
                       "Fienderna tål mer men ger dubbelt"),
    }


def nivå_av(nod, defs):
    """Nivån ur kraven: rotnoden är nivå 1, barnet till en nivå-1-nod nivå 2, osv."""
    if not nod.get("requires"):
        return 1
    for rid in nod["requires"]:
        if rid in defs and rid != nod["id"]:
            return nivå_av(defs[rid], defs) + 1
    return 1


def bygg(befintliga):
    """Behåller de befintliga noderna och fyller ut varje gren till sex nivåer."""
    defs = {n["id"]: n for n in befintliga}
    kronor = räkna_kronor()
    ut = [dict(n) for n in befintliga]        # orörda i sak, i samma ordning
    for n in ut:
        # Nivån är ett HÄRLETT fält: de 25 gamla noderna har det inte, och vyn behöver det för att
        # veta var noden ska stå. Id, namn, effekt, pris och krav rörs inte.
        n.setdefault("tier", nivå_av(n, defs))
        # CS-priset sätts också på de gamla noderna: hela trädet prissätts i Corrupted Souls enligt
        # specen, men deras `cost` (guld) lämnas orörd så att köpvägen kan bytas utan att något går
        # sönder. Utan den här raden summerade ekonomimätningen guld och CS i samma tal (57 561 CS),
        # vilket inte betyder någonting.
        if "soul_cost" not in n:
            rad = PRIS.get(n["tier"], PRIS[1])
            n["soul_cost"] = list(rad[:int(n.get("max_rank", 1))])
    per_gren = {}
    for n in befintliga:
        per_gren.setdefault(n["branch"], {}).setdefault(nivå_av(n, defs), []).append(n["id"])

    for gren, nycklar in GRENAR:
        kronnamn, kroneffekt, kron_tagg, krontext = kronor[gren]
        befintlig_per_nivå = per_gren.get(gren, {})
        for nivå in range(1, 7):
            har = len(befintlig_per_nivå.get(nivå, []))
            behöver = NIVÅER[nivå - 1] - har
            for k in range(max(0, behöver)):
                # Föräldern: rotnoden på nivå 2, annars en nod på nivån under. Tvärlänkar (en nod i
                # en ANNAN gren) sätts på nivå 3-4, precis som specen säger — de gör grenarna till
                # ett träd i stället för fyra staplar.
                förälder = None
                if nivå > 1:
                    kandidater = (befintlig_per_nivå.get(nivå - 1, []) +
                                  [n["id"] for n in ut if n["branch"] == gren and
                                   nivå_av(n, {x["id"]: x for x in ut}) == nivå - 1])
                    if kandidater:
                        förälder = kandidater[k % len(kandidater)]
                requires = [] if förälder is None else [förälder]
                if nivå in (3, 4):
                    # Tvärlänken: en nod i en annan gren på samma nivå.
                    annan = [n["id"] for n in ut if n["branch"] != gren]
                    if annan:
                        requires.append(annan[(k * 3) % len(annan)])
                i = len(ut)
                nyckel = nycklar[k % len(nycklar)]
                namnlista = ORD[gren][0] if nivå <= 3 else ORD[gren][1]
                namn = namnlista[(i * 5 + nivå) % len(namnlista)]
                if any(n["name"] == namn for n in ut):
                    namn = "%s %d" % (namn, nivå)
                if nivå == 6:
                    effekt = dict(kroneffekt)
                    text = krontext
                else:
                    effekt = {nyckel: STYRKA[nivå]}
                    text = "+%d %% %s" % (round(STYRKA[nivå] * 100), nyckel)
                pris = list(PRIS[nivå][:2]) if nivå >= 5 else list(PRIS[nivå][:3])
                nod = {
                    "id": "%s_%d" % (gren_id(gren), i),
                    "name": namn,
                    "branch": gren,
                    "tier": nivå,
                    "effect": effekt,
                    "cost": [0] * len(pris),          # guldkostnaden är noll: priset är i CS
                    "soul_cost": pris,
                    "max_rank": len(pris),
                    "requires": requires,
                    "text": text,
                }
                if nivå == 6:
                    nod["crown"] = kron_tagg
                ut.append(nod)
                befintlig_per_nivå.setdefault(nivå, []).append(nod["id"])
    return ut


def gren_id(gren):
    return {"Järnvägen": "iron", "Benknippet": "body", "Glöden": "wick", "Girigheten": "greed"}[gren]


def main():
    torr = "--check" in sys.argv
    befintliga = json.load(open(TRAD, encoding="utf-8"))
    ut = bygg(befintliga)

    per_nivå = {}
    totalt = 0
    for n in ut:
        per_nivå.setdefault(n.get("tier", 0), 0)
        per_nivå[n.get("tier", 0)] += 1
        totalt += sum(n.get("soul_cost", n.get("cost", [])))
    print("%d noder (var %d)" % (len(ut), len(befintliga)))
    for nivå in sorted(per_nivå):
        print("  nivå %s: %d noder" % (nivå or "?", per_nivå[nivå]))
    print("  att fylla: %d inköp" % sum(len(n.get("soul_cost", n.get("cost", []))) for n in ut))
    print("  hela trädet kostar %d CS" % totalt)
    # Inkomsten: en boss ger 1 + svårighet/2 CS, och en körning är en bana med 5-12 våningar — varje
    # våning har en boss. Vid svårighet 15 blir det alltså 5-12 x 8 = 40-96 CS per körning, plus 25
    # för den sista bossen. Talet nedan är det Alex ska bedöma mot "typ 20 gånger".
    print("  vid 40 CS per körning: %.0f körningar" % (totalt / 40.0))
    print("  vid 80 CS per körning: %.0f körningar" % (totalt / 80.0))
    if torr:
        print("  (--check: ingenting skrivet)")
        return
    with open(TRAD, "w", encoding="utf-8") as f:
        json.dump(ut, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  skrivet: %s" % TRAD)


if __name__ == "__main__":
    main()
