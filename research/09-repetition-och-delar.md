# 09 — Banornas rum, rummens delar, och hur referensen undviker upprepning

**Datum:** 2026-09-20
**Underlag:** `00-matningar-skarmbilder.md`, `01-spelmekanik.md`, `02-teknik-och-bygge.md`,
`03-prior-art.md`, `06-referensbygget.md`, `08-referensrum.md`, `referens-vokabular.txt`,
`referens-tillgangar.json` — **plus en ny mätning direkt i bygget**.

**Gränsen:** allt nedan är struktur, namn och tal ur deras bygge. Inga bilder, texter eller kod
därifrån hamnar i vårt spel (`06-referensbygget.md:8-11`, `08-referensrum.md:55-57`).

## Metod, och vad som var borta

`08-referensrum.md` byggde på en montering i `/tmp/vcmnt`. Katalogen finns kvar men är **tom** —
monteringen är borta. Därför monterade jag om *samma* DwarFS-avbild
(`~/Downloads/Referens.Crawlers-jc141/files/game-root.dwarfs`) read-only, utan root och utan skärm,
till `/tmp/vcmnt2`, och läste prefabsen med UnityPy 1.25.3 ur `/tmp/vcvenv`. Siffror märkta
**[mätt]** kommer därifrån; **[fil]** är citerat ur våra anteckningar. Ingenting här vilar på den
försvunna `/tmp/vcmnt`.

Rumsklassen är `Nosebleed.Pancake.ProceduralGeneration.RoomTemplate`. Det besvarar delvis den öppna
posten i `02-teknik-och-bygge.md:71` ("Vad `Pancake.dll` är"): **Pancake bär deras procedurgenerering
och deras genereringsconfig** (`…GameConfig.DungeonChoices`).

## 1. Rumstyperna: 67 handritade prefabs, och de är små

`08-referensrum.md:8` säger 67 handbyggda rum — det stämmer exakt **[mätt]**: 67 `RoomTemplate`-
komponenter i familjerna `RT_Generic_*`, `…-Boss`, `RT_Relic_2x2_*`, `RT_Spawn_Relic_2x1_*`,
`RT_GT-CM_*`/`RT_MF-DP-CM_*`, `RT_*Bridge_1x12` och SpecialUse/Test (`08-referensrum.md:13-20`).

**Storlek i rutor [mätt]** (`_roomDimensions`): 2×2 vanligast (**18 rum**), sedan 2×3 (11), 3×3 (11),
4×3 (4), 2×1 (3), 4×4 (3), 1×2 (3), 5×3 (2), 1×1 (2), enstaka 3×5, 5×5, 5×9 (Tutorial, Credits) och
**11×15** (`RT_EnderBoss`). Broarna är **1×22** trots namnet `_1x12`. **Storleken ska läsas ur data,
inte ur namnet.**

Varje rum bär **194 exit-kandidater och 92 spawn points** (`_exitCandidates`, `_spawnPoints` i
cellkoordinater) **[mätt]** — rummen är ritade för flera möjliga anslutningar, inte för en. Det är
huvudorsaken till att deras korridorer inte blir L-formade (`08-referensrum.md:24-27`).

**Innehållet skiljer sig i täthet [mätt]:** `_propTemplates` per rum är 0–9, fördelat
`{0:6, 1:13, 2:7, 3:14, 4:4, 5:13, 7:7, 9:3}`. Generiska rum 5–9, relikrum 0–4, balkongrum 1–3,
broar 1–2, `RT_Tutorial`/`RT_Credits`/`RT_EnderBoss` exakt 0.

## 2. Vad ett rum består av — utöver golv och vägg

**Cellnivån (det vår editor saknar).** `RoomTemplate._tileTemplates` är en `_gridArray` med en post
per ruta och fälten `PathfindingFlags`, `ConnectionFlags`, `UseProcGen`, `IsExitCandidate`,
`ExitDirection`, `ConnectsToNeighbours` **[mätt]**. 774 celler totalt; `PathfindingFlags` antar 16
distinkta värden, `ConnectionFlags` 26. **En cell med `ConnectionFlags = 0` är inert** — den finns i
rutnätet men är inte en del av banan.

**Geometrin byggs av Tilemaps [mätt]:** layout-prefabsen har barnen `WallGrid`, `Tilemap_Wall`,
`FloorGrid`, `Tilemap_Floor`, `Ceiling` — separata rutnätslager för vägg och golv, inte lösa plattor.
Det förklarar varför varje rutbild finns i **två varianter per roll**: `…_Corridor` och `…_Room`
(t.ex. `Art/Levels/InlaidLibrary/Prefabs/Tiles/Corridors/Library_Corridor_Straight_01_Corridor.prefab`
och `…/Tiles/Rooms/Library_Corridor_Straight_01_Room.prefab`) **[fil]**.

**Delarna, med exakta namn [fil]:**

| Del | Nyckel/sökväg |
|---|---|
| Rumsskalets ring och golvkanter | `…_Room_Edge_01`, `…_Room_CornerInner_01`, `…_Room_CornerOuter_01`, `…_Room_Fill_01` (per biom, t.ex. `MadForest_Room_Edge_01_Room.prefab`) |
| Ytterkant / gräns | `…_Bounds_Edge_01`, `_Bounds_DeadEnd_01`, `_Bounds_CornerOuter_01`, `_Bounds_Straight_01`, `_Bounds_Fill_01/02` + `…_Border_Inner_01…06`, `…_Border_Outer_01` (DairyPlant, MadForest) |
| Korridorformer | `…_Corridor_Straight_01…07`, `_Corridor_Corner_01/02`, `_Corridor_TJunction_01/02`, `_Corridor_Crossroads_01/02`, `_Corridor_DeadEnd_01/02`, `_Corridor_to_Room_01`, `_Corridor_to_Room_Corner_01/02/03` |
| Pelare | `CM_Pillar_01/02/03`, `Column_01/02`, `Bookpillar_Set_01/02` |
| Bråke/rekvisita | `Barrel_Set_01…03`, `Box_Set_01`, `Locker_Set_01…03`, `Machinery_Set_01…05`, `Cart_Rail_01/02`, `Book_Pile_01`, `Bottles_Clutter_01`, `Tomestone_01/02`, `Log_01/02`, `Ground_Dressing_01…06`, `Ground_Foliage_01…06` |
| Altare och statyer | `CM_Altar_01`, `CM_Statue_01/02/03`, `DestructibleManaStatue`, `DestructibleEvoStatue`, `DestructibleStatue` |
| Trappor/steg | `CM_StepTile_01…05.fbx` (fem stegplattor), `CM_WallTrim_01`, `CM_WallTile_01` |
| Räcken/staket | `CM_Handrail_Mid_01…03`, `CM_Handrail_End_01…04`, `Fence_3m`, `Fenced_Statue_01/02` |
| Broar | `RT_TeenyBridge_1x12`, `RT_WeenyBridge_1x12`, `RT_MeanyBridge_1x12`, `Layout_TinyBridge_1x12/16/20` |
| Facklor/ljus | `Brazier*`, `StandingLantern_01`/`…Broken_01`, `Chandelier_01/02`, `Candelabra_Standing`, `Candelabra_WallMountedTrio`, `DairyPlant-LightTower`, `DairyPlant_SmallLight`, `AllLightSources.prefab`, `DestructibleLightSource_{Card,Chicken,Coin,Empty,Mana,Random}.prefab`, shadern `UnlitTorchLight(.Tri).shadergraph` |
| Blockerare | `CappellaMagna_Blocker_01…03`, `MadForest_Blocker_01…05`, `BlockerBookcase_01/02`, `Book_Case_Block`, `GalloTower_Blocker(+_02)`, `GalloTower_BalconyBlocker` |
| Destruerbart | ~50 prefabs i `…/Prefabs/DungeonEnvironment/Destructibles/`: `DestructibleChicken`, `Coin`, `CoinBag`, `Card*`, `Shovel`, `Gargoyle`, `Bookcase`, `MilkBarrel`, `RailCart`, `Vase_01/02`, `Reroll`, `Mana`, `Evo`, `Relic` |

Dörrar finns **inte** som egen del i listan — bara `CappellaBossDoor.fbx`, `Gate_01…03` (Dairy
Plant) och `village_gate*` (byn) **[fil]**. Om rummen har springor i stället för dörrar är **UNVERIFIED**.

## 3. Så undviker de upprepning — siffrorna

Fem samtidiga mekanismer:

1. **Få rutbilder per tema, men flera varianter av varje roll [fil].** Per biom finns 33–51
   rut-prefabs i 2–3 lager: Corridors 19–25, Rooms 14–19, Border 7 (bara Dairy Plant, MadForest).
   `Rooms`-lagret är **exakt 14 plattor** i fyra av fem biomer — en fast rumsring. Variationen sitter
   i variantnumren: `DairyPlant_Corridor_Straight_01…07` är **sju** ritningar av samma roll.
2. **Få rum, många inre layouter [fil].** 262 layout-prefabs mot 67 rum: Gallo Tower 65, Capella
   Magna 59, Dairy Plant 46, Mad Forest 46, Inlaid Library 43, Tiny Bridge 3. Av dem **88 `_Dead_`**,
   38 `-Boss`, 22 `_Balcony`. Samma ruta får olika innehåll som återvändsgränd, bossrum eller balkong.
3. **Cellinnehållet genereras, formen är ritad [mätt].** `UseProcGen = 1` på **420 av 774 celler
   (54 %)**. Formen är människans, innehållet generatorns — motsatsen till vårt läge, där
   `tools/gen_tiles.py` genererar bilderna och Alex ritar formen.
4. **Per-ruta-händelser med vikt och sannolikhet [mätt].** Rummen bär `_roomTemplateEvents`
   (`RoomTemplateEvent` med `Coordinates`, `EventType`, `Conditions`, `UnlockCondition`,
   `ManualEventOptions`) som pekar på `DungeonChoices`-config med `Weight`, `Probability`,
   `_eventConfigReference`. Samma ritning ger olika strider per körning.
5. **Ljus och rekvisita är handplacerade per layout [mätt].** `Layout_InlaidLibrary_2x2_01` har 135
   barn, däribland **7 `Point Light`**, `Chandelier_01`, `Red_Curtain_03/04` och `Itembox_02`.
   `Layout_MadForest_2x2_01` (73 barn) har `MadForest_Blocked_Island_01`, `Tombstone_03` ×5,
   `Column_01/02` och `Ground_Foliage_03/04/06` med samlade `GrassBundle_*`-barn. Rekvisitan är
   alltså **knippen**, inte enskilda objekt.

Notera att `CappellaMagna_TallCeiling_Room_Edge_01`/`_Straight_01`/`_Corridor_to_Room_01` finns
**inuti** layout-prefabsen men inte i Addressables-listan **[mätt]**: tillgångslistan underskattar
antalet rutbilder.

## 4. Djup, kant och "avgrund"

Inget tillgångsnamn innehåller `abyss`, `pit`, `void`, `hole`, `water`, `fog` eller `decal`
**[fil]**. Fyra strukturella spår av ett "utanför" finns i stället:

- **Balkongrummen.** 22 `_Balcony_`-layouter plus `RT_CM_WingBalcony` och `RT_GT-CM_*_Balcony_*`.
  `CappellaMagna_Layout_2x3_Balcony_01` (353 barn) har ett barn som heter **`Balcony`**, ett flertal
  instanser av `CappellaMagna_Wall_Fill_03` och **`FauxSkyboxBlocker_02`** **[mätt]**.
- **Faux skybox.** `FakeSkyBox.shadergraph`, `CappellaStainedGlassFauxSkybox.mat`,
  `CappellaMagnaSkybox.psd`, `GalloTower_Sky.psd` **[fil]**. Utsikten utanför kanten är en *målad
  himmel*, inte tomt mörker.
- **Räckena** (§2) finns bara i de biomer som har balkongrum.
- **Broarna, tydligast i celldatan [mätt]:** `RT_Teeny/Weeny/MeanyBridge_1x12` är 1×22 celler där
  **y0–y7 har `PathfindingFlags = 0`, `ConnectionFlags = 0`, `UseProcGen = 0`** — åtta inerta celler
  innan gången börjar vid y8 och slutar vid y21. Rummet är en 14 rutor lång gång omgiven av icke-golv
  i sin egen datamodell.

**Slutsats:** referensen har ett "utanför", byggt som en **vista med räcken och målad himmel**, inte
som en klassisk grop. Om golvet faktiskt *saknas* över vissa rutor går inte att avgöra ur metadata.

## 5. Hur spelaren hindras att gå ut i det

1. **Data:** cellen har `ConnectionFlags = 0` → ingen anslutning, inte gångbar **[mätt]**. Kanten
   behöver ingen osynlig vägg; den är odefinierad i rutnätet. Exakt den mekanism vår editor saknar
   (den kan bara sätta `#` och `.`).
2. **Geometri:** `…_Bounds_Edge_01`, `Bounds_DeadEnd_01`, `Bounds_CornerOuter_01` och
   `Border_Inner_01…06`/`Border_Outer_01` är egna plattor för ytterkanten **[fil]** — kanten är
   modellerad, inte bara frånvarande.
3. **Blockerare:** `CappellaMagna_Blocker_01…03`, `MadForest_Blocker_01…05`,
   `GalloTower_BalconyBlocker`, `BlockerBookcase_01/02`, `FauxSkyboxBlocker_02` plus
   `Bumpable_Container`/`*_Bumpable` per biom **[fil]**/[mätt]. Att de *fungerar* som kollisionsplugg
   i oanvända anslutningar är en tolkning av namnet — **UNVERIFIED** — men cellens
   `ConnectsToNeighbours`-flagga pekar åt samma håll **[mätt]**.

## 6. Vad vi tar med oss (förslag, inget byggt här)

Vår baslinje är 5 teman × 5 rutbilder utan varianter; referensen har 14–25 **per lager** och **två
lager per roll**, och lägger **7 varianter av samma platta** i stället för att slumpa slitage.
Nästa steg i editorn är därför inte fler tecken utan **en tredje dimension i celldatan** (anslutning +
gångbarhet + "generera här") — precis vad deras `_gridArray` är.

## UNVERIFIED

1. **Hur rutbilderna ser ut.** Vi har namn, antal och lager — aldrig bilderna. Att `Rooms`- och
   `Corridors`-lagren har olika motiv är en tolkning av namnen.
2. **Om golvet faktiskt saknas i balkong- och bro-rummen.** `ConnectionFlags = 0` visar att cellen är
   inert, inte att man kan falla. Kräver mesh- eller skärmdumpsanalys.
3. **Betydelsen av `PathfindingFlags` (16 värden) och `ConnectionFlags` (26 värden).** Inga enums
   kunde läsas; bitmönstren (7, 17, 31, 112, 124, 193, 199, 241, 255) antyder bitpackade sidtillstånd,
   men det är en gissning.
4. **Vad `EventType` och `DungeonChoices` konkret gör.** Fälten är lästa ur Odin-serialiserade bytes;
   innehållet är inte avkodat.
5. **Blockerarnas funktion, och antal rutbilder spelet faktiskt använder.** Namngivna `*_Blocker`
   finns, men att de är kollisionsplugg i oanvända dörröppningar är en tolkning av namnet. Och vi kan
   räkna prefabs, inte vilka som är aktiva i en våning: `08-referensrum.md:36-37` visar att de behåller
   testrum och `…_Overkill (Unused)`, så listan är en övre gräns.
6. **Rutnätets mått i meter** (cellsize) — omätt även i `00-matningar-skarmbilder.md:52`; kräver
   mesh-bounds ur `MeshFilter`.
7. **Om rum har flera höjdnivåer.** `CM_StepTile_01…05` och `Balcony`-barnet pekar mot höjdskillnader,
   men ingen höjddata är läst. Detsamma gäller Tiny Bridge-layouternas längder
   (`Layout_TinyBridge_1x12/16/20`) mot `RT_*Bridge_1x12 = 1×22` celler: sambandet är inte utrett.
8. `/tmp/vcmnt` är borta; allt som krävde den mounten är ommätt i `/tmp/vcmnt2` ur samma avbild. Är
   avbilden en annan version än den `08-referensrum.md` mättes mot (v1.4 mot v1.5.1,
   `02-teknik-och-bygge.md:73`) kan enskilda namn skilja.
