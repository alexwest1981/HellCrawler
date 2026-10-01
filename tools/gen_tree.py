#!/usr/bin/env python3
"""Generates HellCrawler's tree: game/data/tree.json - 3 branches x (1 main node + 30 sub-nodes).

Alex: *"it is 3 columns, 3 main nodes, then 20 sub-nodes per main node, as you see in the picture,
make it work"*, and later *"Angående de 90 noderna - lägg till dem, peka en direkt linje mellan
föregående nod och den kommande noden, så man vet var den är på väg."* Three branches with two
parallel lines each is what the shape can carry: 1 main + 15 tiers of two = 31 nodes per branch, 93 in
all. Every node names its parent in `requires`, so the line from the previous node to the next is in the
data - the view draws it.

Shape per branch:
  tier 1        the main node (one purchase, opens the branch, 40 CS)
  tier 2..15    two sub-nodes per tier, 30 in all - two parallel lines of fifteen, so a player can go
                deep in one line or spread across both.
  tier 16       the capstone pair: the two nodes that change how the game plays, carrying a `crown` tag
                the engine can read later ("everything you hit burns", "you rise three times").

Every node costs Corrupted Souls (`soul_cost`), never gold: `cost` is kept at zero so a price can never
be read as gold by mistake (the first version of the tree left gold prices in `cost`, and a tree that
reads the wrong field is free). What the whole tree costs is printed by --check, next to what one
playthrough pays (see game/core/run.gd) - the two numbers are what the pacing is made of.

    python3 tools/gen_tree.py            write game/data/tree.json
    python3 tools/gen_tree.py --check    write nothing, just measure (and show the economy)
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREE = os.path.join(ROOT, "game", "data", "tree.json")

# The three branches, in the order the view draws them (left to right) and in the plate's own metals:
# Järnvägen (damage, steel), Benknippet (body, bone), Glöden (cards and mana, ember).
BRANCHES = [
    ("Järnvägen", "iron", ("might", "area")),
    ("Benknippet", "body", ("max_hp", "armor")),
    ("Glöden", "wick", ("mana", "hand")),
]

# Main node per branch: what the branch is FOR, in one purchase. Opens the branch, so it is bought
# first and its two sub-lines both hang from it.
MAINS = {
    "Järnvägen": ("Smidesmästaren", {"might": 0.08, "area": 0.05}, "+8 % skada och +5 % area"),
    "Benknippet": ("Benbyggaren", {"max_hp": 10, "armor": 1}, "+10 max-HP och +1 rustning"),
    "Glöden": ("Väktaren av lågan", {"mana": 1, "hand": 1}, "+1 mana och +1 kort på handen"),
}

# Fourteen pairs of names per branch: the first is the upper line, the second the lower one.
NAMES = {
    "Järnvägen": [
        ("Vässad egg", "Slaggvikt"), ("Djupt hugg", "Bredare sving"),
        ("Två händer", "Genomträngande"), ("Klyvning", "Skärvorna"),
        ("Härdat bett", "Ugnsvind"), ("Städets slag", "Glödgat grepp"),
        ("Malmsmidd", "Rensad fog"), ("Bandad klinga", "Bränd kant"),
        ("Hammarfallet", "Stålets tunga"), ("Slipad malm", "Smidessång"),
        ("Stålets lag", "Hetta"), ("Ässjan", "Hammarfästet"),
        ("Slaggmun", "Skärseld"), ("Sotig andedräkt", "Fjädrad hammare"),
    ],
    "Benknippet": [
        ("Tjockt ben", "Sparad hud"), ("Lappad läder", "Knytnäve"),
        ("Sammabit", "Sårskorpa"), ("Gamla ärr", "Benmärg"),
        ("Härdad nacke", "Rakad rygg"), ("Långsamt blod", "Ny hud"),
        ("Stelnad", "Andra andetaget"), ("Sista andetaget", "Kvarleva"),
        ("Benskölden", "Järnben"), ("Märgskal", "Stelnat blod"),
        ("Benkronan", "Segt kött"), ("Gravfrid", "Urdjup ro"),
        ("Ättens ben", "Obruten"), ("Torkad sen", "Tyst hjärta"),
    ],
    "Glöden": [
        ("Varm hand", "Snabb tanke"), ("Första draget", "Extra andetag"),
        ("Öppen hand", "Fylld näve"), ("Glödrök", "Skymt"),
        ("Första gnistan", "Tändved"), ("Lågan inne", "Brinnande kort"),
        ("Rykande drag", "Gnistregn"), ("Eldens rytm", "Andra handen"),
        ("Återtändning", "Fylld hand"), ("Glödvind", "Tändtråd"),
        ("Lågans lag", "Vedförråd"), ("Rökridå", "Gnistväv"),
        ("Askan själv", "Evig ved"), ("Flamman minns", "Fjärde handen"),
    ],
}

# The capstone pair of each branch: the two nodes that change how the game plays, plus their tag.
CAPSTONES = {
    "Järnvägen": [
        ("Ugnens gap", {"might": 0.30}, "burn", "+30 % skada och allt du slår på brinner"),
        ("Malmens hjärta", {"might": 0.20, "gold": 0.20}, "rich_blood", "+20 % skada och guld"),
    ],
    "Benknippet": [
        ("Tre resningar", {"revive": 2, "max_hp": 0.30}, "three_revives",
         "+3 resningar i stället för 1"),
        ("Benmur", {"armor": 4, "max_hp": 0.20}, "bone_wall", "+4 rustning vid turstart"),
    ],
    "Glöden": [
        ("Full hand varje tur", {"hand": 3, "draw_first": 2}, "full_hand",
         "Handen fylls till fullt varje tur"),
        ("Evig glöd", {"mana": 3, "gold": 0.15}, "eternal_ember",
         "+3 mana varje tur och +15 % guld"),
    ],
}

# Effect size per tier: small steps at first, then a steady climb. The last ordinary tier (15) is the
# biggest step before the capstone pair, which does something else entirely.
STRENGTH = {2: 0.02, 3: 0.03, 4: 0.04, 5: 0.05, 6: 0.06, 7: 0.08, 8: 0.10, 9: 0.12, 10: 0.15,
            11: 0.18, 12: 0.22, 13: 0.26, 14: 0.30, 15: 0.35}
# Price in Corrupted Souls per node, rising with the tier (the same ~1.25 ratio all the way: a deeper
# node is worth more to the player and costs more). Measured against what a playthrough pays - see
# --check: the whole tree is ~1.3 playthroughs of souls, so the tree is still being filled late in the
# game instead of being finished before the game is half over.
PRICE = {2: 4, 3: 5, 4: 7, 5: 9, 6: 12, 7: 15, 8: 19, 9: 24, 10: 30, 11: 38,
         12: 48, 13: 60, 14: 75, 15: 94, 16: 118}
MAIN_PRICE = 40
TIERS = 16                      ## tier 1 = the main node, tier 2..15 = the 30 sub-nodes, 16 = crowns


def build() -> list:
    out = []
    for branch, prefix, keys in BRANCHES:
        main_name, main_effect, main_text = MAINS[branch]
        out.append({
            "id": "%s_main" % prefix,
            "name": main_name,
            "branch": branch,
            "tier": 1,
            "effect": dict(main_effect),
            "cost": [0],
            "soul_cost": [MAIN_PRICE],
            "max_rank": 1,
            "requires": [],
            "text": main_text,
        })
        for step, names in enumerate(NAMES[branch]):
            tier = step + 2
            for side in range(2):
                node_id = "%s_%d" % (prefix, step * 2 + side + 1)
                parent = ("%s_main" % prefix if tier == 2
                          else "%s_%d" % (prefix, (step - 1) * 2 + side + 1))
                name = names[side]
                effect = {keys[side]: STRENGTH[tier]}
                text = "+%d %% %s" % (round(STRENGTH[tier] * 100), keys[side])
                out.append({
                    "id": node_id,
                    "name": name,
                    "branch": branch,
                    "tier": tier,
                    "effect": effect,
                    "cost": [0],
                    "soul_cost": [PRICE[tier]],
                    "max_rank": 1,
                    "requires": [parent],
                    "text": text,
                })
        # CROWN-PARET SIST, på nivå TIERS: samma två linjer och samma krav-kedja som de andra, men sina
        # egna effekter och sin egen tagg. Det ligger utanför namnlistan, så en ny nivå av vanliga noder
        # aldrig kan tränga bort kronan (den låg förut inuti loopen och försvann tyst när TIERS höjdes).
        step = TIERS - 2
        for side in range(2):
            node_id = "%s_%d" % (prefix, step * 2 + side + 1)
            parent = ("%s_main" % prefix if step == 0
                      else "%s_%d" % (prefix, (step - 1) * 2 + side + 1))
            name, effect, tag, text = CAPSTONES[branch][side]
            node = {
                "id": node_id,
                "name": name,
                "branch": branch,
                "tier": TIERS,
                "effect": effect,
                "cost": [0],
                "soul_cost": [PRICE[TIERS]],
                "max_rank": 1,
                "requires": [parent],
                "text": text,
            }
            if tag:
                node["crown"] = tag
            out.append(node)
    return out


def main() -> int:
    dry = "--check" in sys.argv
    nodes = build()

    per_branch = {}
    for node in nodes:
        per_branch.setdefault(node["branch"], []).append(node)
    print("%d nodes in %d branches" % (len(nodes), len(per_branch)))
    for branch, rows in per_branch.items():
        tiers = sorted({int(n["tier"]) for n in rows})
        print("  %-12s %2d nodes, %d tiers (1 main + %d sub)" % (
            branch, len(rows), len(tiers), len(rows) - 1))
    total = sum(sum(n["soul_cost"]) for n in nodes)
    print("  purchases to fill it: %d" % len(nodes))
    print("  the whole tree costs %d CS" % total)
    # KONTROLLRÄKNAT MOT BANORNA (inte gissat): en hel genomspelning ger `5 + difficulty*2` per boss,
    # en boss per bana - samma formel och samma data som game/core/run.gd läser. Ett prispaket som inte
    # är räknat mot summan blir fel med en faktor, och det syns först när någon spelar.
    stages = sorted(glob.glob(os.path.join(ROOT, "game", "data", "stages", "stage_*.json")))
    if stages:
        income = 0
        for path in stages:
            with open(path, encoding="utf-8") as f:
                income += 5 + int(json.load(f).get("difficulty", 1)) * 2
        print("  one playthrough pays %d CS (%d stages)" % (income, len(stages)))
        print("  so the tree is full after %.2f playthroughs" % (total / float(income)))
    else:
        print("  (no stage files: the pacing could not be measured)")

    # What has to hold: every parent exists, and each branch has exactly one root (the main node).
    # The PRICE is deliberately not checked against the parent: the main node is much more expensive
    # than its first children because it opens the branch - that is the design, not a bug.
    known = {n["id"]: n for n in nodes}
    for node in nodes:
        for parent in node["requires"]:
            if parent not in known:
                print("  FEL %s kräver %s som inte finns" % (node["id"], parent))
                return 1
    for branch in {n["branch"] for n in nodes}:
        roots = [n for n in nodes if n["branch"] == branch and not n["requires"]]
        if len(roots) != 1 or not str(roots[0]["id"]).endswith("_main"):
            print("  FEL %s har %d rötter (skall ha exakt en, huvudnoden)" % (branch, len(roots)))
            return 1

    if dry:
        print("  (--check: nothing written)")
        return 0
    with open(TREE, "w", encoding="utf-8") as f:
        json.dump(nodes, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("  written: %s" % TREE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
