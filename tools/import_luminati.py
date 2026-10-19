#!/usr/bin/env python3
"""Läs en Luminati-nivå (broad-grass-…workers.dev/editor, "format": "luminati-level") och skriv den
som en HellCrawler-våning.

    python3 tools/import_luminati.py ~/Downloads/untitled.level.json --id luminati --tema grotta
    python3 tools/import_luminati.py <fil> --kolla        # bara kontrollerna, inget skrivs

Vad som följer med: rutorna (golv/vägg/halvvägg), markmaterial (som `ytor` där namnet finns i vårt
tema, annars som `täcken`: gräs, mossa, grus, vatten), startpunkten och de noder en våning MÅSTE ha
(boss, spade, strider).

Vad som INTE följer med, och varför: höjder (våra golv ligger på en nivå — en nivå som är byggd i
trappor blir platt), vatten som fysik (vårt vatten är ett täcke man går på), och möblerna (hus,
väderkvarn, marknadsstånd, bänk): HellCrawler har ingen av dem i sin rekvisitalista.
"""
import argparse
import json
import random
import sys
from collections import deque
from pathlib import Path

KARTA = Path(__file__).resolve().parent.parent / "game" / "data" / "maps"
STAGE = Path(__file__).resolve().parent.parent / "game" / "data" / "stages"

# Luminatis `top` -> vårt material (`ytor`) eller vårt täcke. Tom sträng = temats ruta duger.
MATERIAL = {
    "cobblestone": "ancient_stone", "stone_tiles": "ancient_stone", "moss_stone": "",
    "polished_stone": "chiseled_marble",
}
TACKE = {
    "grass": "gräs", "grass_flowers": "gräs", "grass_dark": "mossa", "sand": "småsten",
    "farmland": "småsten", "dirt": "småsten", "dirt_path": "småsten", "riverbed": "vattenpöl",
}
GOLV, VAGG, HALV, TOM = ".", "#", "~", " "
STRIDER = 6          # samma tak som generatorn: encounters_per_floor 6
# Bossen måste stå i banans `bosses`-lista och finnas i bestiariet, annars går våningen inte att spela
# (`test_mapio` kontrollerar varje karta). Sätts med --boss om banan ska ha en annan.
BOSS = "hollow_choir"


def läs(sökväg: Path) -> dict:
    nivå = json.loads(sökväg.read_text(encoding="utf-8"))
    if nivå.get("format") != "luminati-level":
        sys.exit(f"{sökväg.name}: inte en luminati-level (format={nivå.get('format')!r})")
    return nivå


def bygg(nivå: dict, stage_id: str, tema: str, frö: int, boss: str = BOSS) -> tuple[dict, list[str]]:
    """Returnerar (vår karta, lista med saker som inte kunde följa med)."""
    bortfall: list[str] = []
    legend = nivå["legend"]
    rader = nivå["tiles"]
    h, w = len(rader), max(len(r) for r in rader)
    if nivå.get("width") != w or nivå.get("depth") != h:
        bortfall.append(f"storleken i filen ({nivå.get('width')}×{nivå.get('depth')}) stämmer inte "
                        f"med rutorna ({w}×{h}) — rutorna användes")

    # Höjder: våningen har ETT golv. Är inte alla rutor lika höga sägs det, sedan ritas de platt.
    höjder = nivå.get("heights") or []
    if höjder and len(set("".join(höjder))) > 1:
        bortfall.append("våningen har höjdskillnader — alla rutor ligger på samma nivå här")

    tiles, ytor, täcken = [], {}, {}
    for y in range(h):
        rad = ""
        for x in range(w):
            tecken = rader[y][x] if x < len(rader[y]) else " "
            ruta = legend.get(tecken, {})
            if ruta.get("void"):
                rad += TOM          # Luminatis void är vår tomma ruta: inget golv, ingen vägg
                continue
            vatten = bool(ruta.get("water"))
            # Vatten är inte golv att gå på i Luminati; här blir det golv med ett vattentäcke, eftersom
            # vårt vatten är dekor. En blockerad ruta som inte är vatten blir vägg.
            if ruta.get("walkable"):
                rad += GOLV
            elif vatten:
                rad += GOLV
            else:
                rad += VAGG
                continue
            top = str(ruta.get("top", ""))
            if vatten:
                täcken[f"{x},{y}"] = TACKE.get(top, "vattenpöl")
            elif top in MATERIAL and MATERIAL[top]:
                ytor[f"{x},{y}"] = MATERIAL[top]
            elif top in TACKE and TACKE[top]:
                täcken[f"{x},{y}"] = TACKE[top]
        tiles.append(rad)

    # Startpunkten: Luminatis spawn, avrundad till en ruta (den ligger på en kant, t.ex. 16.5).
    sp = nivå.get("spawn") or {}
    start = (int(sp.get("x", w / 2)), int(sp.get("z", h / 2)))
    if not (0 <= start[0] < w and 0 <= start[1] < h) or tiles[start[1]][start[0]] != GOLV:
        start = nästa_golv(tiles, start, w, h)

    # Stäng fickor: allt golv som inte nås från start blir vägg (samma regel som generatorn).
    nåbar = nåbarhet(tiles, start, w, h)
    for y in range(h):
        for x in range(w):
            if tiles[y][x] == GOLV and (x, y) not in nåbar:
                tiles[y] = tiles[y][:x] + VAGG + tiles[y][x + 1:]
                täcken.pop(f"{x},{y}", None)
                ytor.pop(f"{x},{y}", None)

    golv = sorted(nåbar)
    if len(golv) < 6:
        sys.exit(f"bara {len(golv)} nåbara golvrutor — för litet för att bli en våning")

    # Noderna: boss och spade längst bort från start, striderna utspridda emellan.
    slump = random.Random(frö)
    avstånd = {p: d for p, d in nåbar.items()}
    längst = sorted(golv, key=lambda p: -avstånd[p])
    boss_ruta = längst[0]
    spade = next((p for p in längst[1:]
                  if abs(p[0] - boss_ruta[0]) + abs(p[1] - boss_ruta[1]) > 3), längst[-1])
    kandidater = [p for p in golv if p not in (start, boss_ruta, spade)]
    slump.shuffle(kandidater)
    strider = kandidater[:STRIDER]
    noder = [{"kind": "start", "pos": list(start)},
             {"kind": "boss", "pos": list(boss_ruta), "enemy_id": boss},
             {"kind": "shovel", "pos": list(spade)}]
    noder += [{"kind": "encounter", "pos": list(p)} for p in strider]

    karta = {"stage_id": stage_id, "floor": 0, "theme": tema, "tiles": tiles, "nodes": noder,
             "ytor": ytor, "täcken": täcken}
    for o in nivå.get("objects", []):
        bortfall.append(f"{o.get('type')} på ({o.get('x')},{o.get('z')})")
    return karta, bortfall


def nästa_golv(tiles, p, w, h) -> tuple[int, int]:
    for radie in range(1, max(w, h)):
        for y in range(max(0, p[1] - radie), min(h, p[1] + radie + 1)):
            for x in range(max(0, p[0] - radie), min(w, p[0] + radie + 1)):
                if tiles[y][x] == GOLV:
                    return (x, y)
    sys.exit("våningen har inget golv alls")


def nåbarhet(tiles, start, w, h) -> dict:
    """BFS över golv (halvvägg och vägg stänger) — ger också gångavståndet noderna väljs på."""
    sedd = {start: 0}
    kö = deque([start])
    while kö:
        x, y = kö.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in sedd and tiles[ny][nx] == GOLV:
                sedd[(nx, ny)] = sedd[(x, y)] + 1
                kö.append((nx, ny))
    return sedd


def kolla(karta: dict) -> list[str]:
    """Samma krav som MapIo.validate, utan Godot: en start, en boss, en spade, minst fyra strider."""
    fel = []
    slag = {}
    for n in karta["nodes"]:
        slag.setdefault(n["kind"], []).append(tuple(n["pos"]))
    for krav, antal in (("start", 1), ("boss", 1), ("shovel", 1)):
        if len(slag.get(krav, [])) != antal:
            fel.append(f"{krav}: {len(slag.get(krav, []))} (ska vara {antal})")
    if len(slag.get("encounter", [])) < 4:
        fel.append(f"strider: {len(slag.get('encounter', []))} (minst 4)")
    tiles = karta["tiles"]
    alla = [p for lista in slag.values() for p in lista]
    if len(set(alla)) != len(alla):
        fel.append("två noder står på samma ruta")
    nåbar = nåbarhet(tiles, slag["start"][0], len(tiles[0]), len(tiles))
    for p in alla:
        if tiles[p[1]][p[0]] != GOLV:
            fel.append(f"nod i vägg: {p}")
        elif p not in nåbar:
            fel.append(f"nod går inte att nå: {p}")
    return fel


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("fil", type=Path)
    ap.add_argument("--id", default="luminati", help="stage-id (skrivs som <id>_0.json)")
    ap.add_argument("--tema", default="grotta", help="tema för våningen (grotta, krypta, tunnel …)")
    ap.add_argument("--frö", type=int, default=1, help="frö för var striderna hamnar")
    ap.add_argument("--boss", default=BOSS, help="bossens enemy_id (måste finnas i bestiariet)")
    ap.add_argument("--kolla", action="store_true", help="kör bara kontrollerna")
    a = ap.parse_args()

    karta, bortfall = bygg(läs(a.fil), a.id, a.tema, a.frö, a.boss)
    fel = kolla(karta)
    golv = sum(r.count(GOLV) for r in karta["tiles"])
    print(f"{a.fil.name}: {len(karta['tiles'][0])}×{len(karta['tiles'])} rutor, {golv} golv, "
          f"{len(karta['ytor'])} material, {len(karta['täcken'])} täcken, "
          f"{len(karta['nodes'])} noder")
    for b in bortfall:
        print(f"  följde inte med: {b}")
    for f in fel:
        print(f"  FEL {f}")
    if fel:
        sys.exit(1)
    if a.kolla:
        print("  kontrollerna gick igenom")
        return

    KARTA.mkdir(parents=True, exist_ok=True)
    mål = KARTA / f"{a.id}_0.json"
    mål.write_text(json.dumps(karta, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"  skrev {mål}")

    stag = STAGE / f"{a.id}.json"
    if not stag.exists():
        stag.write_text(json.dumps({
            "id": a.id, "name": a.id.capitalize(), "theme": a.tema, "floors": 1,
            "difficulty": 1, "tiers": [1], "encounters_per_floor": STRIDER,
            "boss": a.boss, "bosses": [a.boss], "final_boss": "", "regel": "",
            "floor_themes": [a.tema], "gold_bonus": 0.0, "xp_bonus": 0.0,
        }, indent=1, ensure_ascii=False), encoding="utf-8")
        print(f"  skrev {stag} (behövs för att spelet ska hitta banan)")


if __name__ == "__main__":
    main()
