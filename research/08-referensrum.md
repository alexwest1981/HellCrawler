# Referensens rum och tillgångar — och vad vi tar av det

Mätt ur bygget 2026-09-19 (`research/referens-tillgangar.json`, 2 408 adresserbara tillgångar i
35 bundlar). Bara struktur och namn: inga bilder, ingen text, ingen kod därifrån används i vårt spel.

## Rummen: 67 stycken, och de är ritade för hand

Deras våningar byggs inte av en generator. De sätts ihop av **67 handbyggda rum** — prefabs med
namn som säger storlek och funktion:

| Namnmönster | Antal | Vad det är |
|---|---|---|
| `RT_Generic_<WxH>_NN` | 24 | Standardrum i storlekarna 1x1, 2x1, 2x2, 2x3, 3x3, 4x3, 4x4, 5x3 |
| `RT_Generic_<WxH>_NN-Boss` | 7 | Samma rum, markerade som **bossrum** |
| `RT_Relic_2x2_<Relik>` | 15 | **Ett eget rum per relik** — reliken ligger i ett rum byggt för den |
| `RT_Spawn_Relic_2x1_<Relik>` | 3 | Relikrum i annan form (FccPamphlet, GemHammer, LapidaryLoupe) |
| `RT_GT-CM_*`, `RT_MF_*`, `RT_MF-DP-CM_*`, `RT_CM_*` | 16 | Rum som bara hör till vissa biomer (Gallo Tower/Capella Magna m.fl.) |
| `RT_<Namn>Bridge_1x12/16/20` | 5 | **Broar: ett rum som är en enda lång korridor** (Tiny Bridge finns i tre varianter + två testrum) |
| `RT_GemChest` | 1 | Rummet med gemkistan |
| `RT_Tutorial`, `RT_Credits`, `RT_EnderBoss`, `RT_GT_3x3_CentralBoss`, `RT_Moongolow_teaser` | 5 | Specialrum |

**Så här gör de, och det är det vi tar:**

1. **Rum är data, inte genererade former.** En våning är en samling rum ur en pool, och poolen är
   ritad av en människa. Det är därför deras korridorer är intressanta och våra är L-formade.
   → vår väg: karteditorn (`tools/editor.sh`), där Alex ritar våningarna. Generatorn blir reserven
   för de våningar ingen ritat (core/dungeon.gd väljer handritad karta om den finns).
2. **Storleken står i namnet, och den är grov.** 1x1 upp till 5x3, oftast 2x2 och 2x3. Rummen är
   alltså *små* — variationen kommer av mängden rum, inte av stora salar.
3. **Funktionen står i namnet.** Bossrum är markerade per storlek. Samma rum finns i en bossvariant.
   → vår nod `boss` på en ruta gör samma sak, och karteditorn visar den.
4. **En relik = ett rum.** När reliksystemet byggs (se `research/07-arkitekturguide.md` §1) ska varje
   relik ha sin egen ruta — det är därför deras reliker känns hittade och inte utdelade.
5. **Broar är en egen rumstyp**: en korridor som *är* rummet (1x12 till 1x20 rutor). Ett billigt sätt
   att skapa rytm mellan rum utan att bygga något nytt.
6. **De behåller testrum i bygget** (`Test_RT_TinyBridge_1x16/1x20`) och märker oanvända rum
   (`..._Overkill (Unused)`). Det är en vana värd att kopiera: hellre märkt än bortglömt.

## Tillgångarna: 2 408 adresserbara, och art är nästan allt

| Grupp | Antal | Vad det säger |
|---|---|---|
| `Art/` | 684 | varav **`Levels` 647** — rummens och världens konst |
| `Localization/` | 183 | 12 språk × ~15 tabeller (matchar `research/06-referensbygget.md`) |
| `Prefabs/` | 128 | rummen + UI + rekvisita |
| `FX Quest`, `TextMesh Pro`, shaders | 15 | effekt- och textlager |

Att `Characters` och `Items` bara har **en** fil var är inte ett fel: deras figurer och föremål är
inte adresserbara för sig — de ligger inuti prefabsen, som drar sin egen konst. **Lärdomen för oss:**
en sak = en prefab/sprite som bär sin bild, inte ett register av bilder vid sidan av. Vår
`gen_enemy_art.py` och `gen_tiles.py` gör redan rätt (bilden hör till sin JSON-post).

## Vad vi INTE tar

Namnen (MilkyWay, GrimGrimoire, Ovenkilt …), rummens innehåll, konsten, texterna. De är deras
innehåll. Strukturen — små rum i diskreta storlekar, bossrum markerade, en relik per rum, broar som
egen typ, testrum kvar och märkta — är designkunskap, och den använder vi.

## Vårt läge efter det här

- `data/maps/stage_01_0.json` — en handritad våning (exempel; Alex ersätter den med sina egna).
- `core/mapio.gd` — formatet, kontrollerna och sparandet. **Grinden:** en våning som inte går att
  spela (avskuren boss, för få strider, nod i en vägg) får inte sparas. Provet fångade direkt ett
  fel i min egen exempelkarta: korridoren ner till bossrummet saknade en ruta.
- `game/editor/editor.gd` + `tools/editor.sh` — rita, spara (`S`), läs (`L`), ny (`N`), spela (`P`),
  byt våning (`[` `]`). Startar på den genererade våningen om ingen ritad finns, så man alltid
  börjar med något spelbart.
- `tests/test_mapio.gd` — 22 kontroller: tur och retur, att grinden vägrar, att en avskuren boss
  fångas, och att spelet faktiskt spelar den ritade våningen i stället för generatorns.
