# Redigera byn själv

Allt i byn är data eller filer du kan byta rakt av — ingen kod behöver röras. Tre nivåer, från
"flytta ett hus" till "rita en ny fasad".

## 1. Layout, mått och rotation — `game/data/by.json`

Ändra, spara, starta spelet. Ingen ombyggnad.

| Fält | Betyder |
|---|---|
| `radie` | ringens radie i meter (hur långt från byns mitt husen står) |
| `mur.radie` / `mur.hojd` | skyddsmurens ring och stenhöjd |
| `port.radie` | hur långt från mitten porten står |
| `port.bredd` | **öppningens bredd.** Styr både portmodellens skala och hur stort glapp muren lämnar — de kan inte glida ifrån varandra |
| `hus[].id` | filnamn: `assets/by/models/<id>.glb` |
| `hus[].namn` | etiketten under vyn |
| `hus[].vinkel` | grader runt ringen, 0 = porten |
| `hus[].w` / `d` / `h` | bredd, djup, höjd i meter (används för fasadlampan) |
| `hus[].vag` / `tak` | materialnamn i spelets egna rutor (ritas inte längre, men sparas) |

Lägg till ett hus: kopiera ett block, ge det nytt `id`, sätt `vinkel`. Saknas GLB-filen ritas ingen
kropp — inget kraschar.

Ta bort ett hus ur karusellen: sätt `"skepp": ""` (tomt) så hoppas det över i `_synliga`.

## 2. Husmodellerna — Blender

Modellerna byggs av ett skript, inte för hand, men allt ligger i en `.blend` du kan öppna:

- `assets/by_hus_3d.blend` — hela byggsatsen (alla sex hus + portvalv)
- `tools/gen_by_hus3d.py` — generatorn: `Bygge`-klassen, `stockvägg`, `puts_vägg`, `sadeltak`,
  `fonster`, `dorr`, `trappa`, `skylt`, `skorsten`, `lykta`, `tunna`, `kista`, `portvalv`, `skala()`

Ändra i `.py`-filen och kör om:

```sh
tools/bygg_by.sh          # Blender bygger + Godot importerar, 8–9 min för alla sex
tools/bygg_by.sh --kolla  # bara triangelantal och mått per hus
```

Vill du hellre modellera för hand: öppna `.blend`, exportera till `game/assets/by/models/<id>.glb`
(filnamnet måste matcha `hus[].id`), kör `godot --headless --editor --quit` i `game/` så importeras den.

**Materialen måste heta som i materialkartan** (se punkt 3) — `mur`, `puts`, `mörkt_virke`,
`ljust_virke`, `takpanna_ljus`, `takpanna_mörk`, `sten`, `tegel`, `järn`. Det är namnet som avgör
vilken textur huset får; UV-kartan behöver bara finnas.

## 3. Texturerna — `game/assets/by/texturer/pixel/`

Elva rutor i 512×512 (pixelpacken), plus en `_normal.png` per ruta. **Byt en fil mot en annan med samma
namn** — inget mer behövs:

```
stone_wall  mossy_stone  dark_stone  tudor_wall  wood_planks
roof_slate  roof_terracotta  cobblestone_ground  dirt  grass  hedge
```

Normalmapen ritas om ur albedon med:

```sh
python3 -c "import sys; sys.path.insert(0,'tools'); from gen_normal import normalmap; \
from PIL import Image; normalmap(Image.open('game/assets/by/texturer/pixel/stone_wall.png').convert('RGB'), styrka=2.6) \
.save('game/assets/by/texturer/pixel/stone_wall_normal.png')"
```

Vill du koppla ett **nytt materialnamn** till en textur: lägg en rad i `MATERIALTEX` högst upp i
`game/ui/village_view.gd`. Specifika nycklar först — `takpanna_ljus` före `tak`.

## 4. Marken — `game/assets/tiles/material/mark_grus.png`

4096×4096, ritad av `tools/gen_mark.py` (26 000 stenar, 90 000 gruskorn, jord- och slitfält).
Läggs en gång över hela torget, alltså ingen upprepning. Vill du byta mark: ersätt filen, eller ändra i
generatorn och kör `python3 tools/gen_mark.py`.

## 5. Träd, rekvisita, himmel

- `game/assets/by/trad2/` — sex trädmodeller (16 filer); antal, storlek och spridning sätts i `_bygg_skog()`
- `game/assets/by/rekvisita/` — 34 pjäser; möbleringen per hus ligger som en plan i `_bygg_rekvisita()`
- `game/assets/by2d/kvallshimmel.hdr` — skyboxen

## 6. Vad som INTE är data

Byns kod — kameran, rotationen, ljuset — ligger i `game/ui/village_view.gd` (`_bygg_ring`,
`_bygg_landskap`, `_bygg_skog`, `_bygg_rekvisita`, `_ring_titta`). Där behöver du bara gå in om du vill
ändra beteende, inte utseende.
