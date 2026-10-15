# Vampire Crawlers — kart-/dungeongenerering, specifikation

Källor (allt LÄST, inget i spelet ändrat):

- `il2cpp/dump.cs` — Il2CppDumper av `Assembly-CSharp`. **Inga metodkroppar**: bara typer, fält, egenskaper, metodsignaturer, enumvärden och de kompilatorgenererade tillståndsmaskinernas lokala variabler (som avslöjar namn på saker koden räknar med). Radnummer citeras `dump.cs:NNNNN`.
- `vc-mnt/.../StreamingAssets/aa/StandaloneWindows64/*.bundle` — UnityPy-typetrees och objektdumpningar (körd med `./vcvenv/bin/python`, UnityPy 1.25.4).
- `vc_texter/*.json` — VC:s lokaliseringsrader.

**Metodnot (viktig):** UnityPy kan läsa typetrees ur VC:s bundles, men för spelets EGNA skripttyper innehåller de bara basfälten (`m_GameObject`, `m_Enabled`, `m_Script`, `m_Name`); exempel: `roomtamplates-unique_assets_rt_gemchest.bundle` gav `['m_GameObject','m_Enabled','m_Script','m_Name']`. Alltså: **fältnamn finns i dump.cs, men konfigvärden går inte att läsa ur bundlarna.** Det som går att läsa med värde är i stället (a) objektnamn (prefab- och assetnamn), (b) Unitys egna nativa typer (t.ex. `Grid.m_CellSize`), (c) vilken klass varje MonoBehaviour-instans tillhör — löst via `m_Script`-pekare mot de 4365 MonoScript-objekten i `globalgamemanagers.assets` (4502 klasser totalt i den byggda klasskartan; klasslösningen gav 0 olösta i `roomtemplates-simple` och i scenfilerna, men 31–270 olösta i `roomtemplates-relics`, `rt_enderboss`, `rt_tutorial`, `biome-madforest` och `biome-capellamagna` — de klasserna ligger i bundles vars MonoScripts inte fanns i den laddade uppsättningen).

---

## 1. Hur VC bygger en våning, steg för steg

VC genererar inte en dungeon i en enda funktion. En **våning** är en lista av **lager** (`GenerationLayer`) som körs i tur och ordning mot ett delat kartobjekt `TiledMapData`.

### Steg 0 — start: våningens konfiguration väljs

1. `DungeonConfig` (en asset) pekar på `GenerationConfig : DungeonGenerationConfig` (`dump.cs:89713`).
2. `DungeonGenerationConfig` bär `_floors : List<FloorDetails>` (`dump.cs:90791`), `_allowEndlessMode` (`dump.cs:90793`), `_endlessModeStatConfig` (`dump.cs:90795`) och egenskapen `NumberOfFloors` (`dump.cs:90798`).
3. Varje `FloorDetails` = `{ FloorLayerConfig FloorLayer; DifficultyRange Difficulty; }` (`dump.cs:90772`–`90777`). Alltså: **en dungeon är en lista av våningar, och varje våning har egen lagerlista och eget svårighetsspann.**
4. `FloorLayerConfig` bär `_dungeonTag` (`dump.cs:70116`), `_floorCoinBonus` (`dump.cs:70118`), `_enemyHealthMultiplier` (`dump.cs:70120`), `_stepConfig` (`dump.cs:70123`), **`_floorLayers : List<GenerationLayer>`** (`dump.cs:70126`), `_dungeonEnvironmentPrefab` (`dump.cs:70128`), `_forceDisableMinimap` (`dump.cs:70130`), `_hasCustomEndingSequence` (`dump.cs:70132`).
5. Anropet från spelkoden: `Dungeon3DMapModel.GenerateDungeonFloor(DungeonConfig dungeonConfig, int floorIndexToGenerate, int visitedFloorCount)` (`dump.cs:79144`) → `GenerateDungeonFloorTask(...)` (`dump.cs:79155`), vars tillståndsmaskin har en lokal `DungeonGenerationConfig.FloorDetails floorDetails` (`dump.cs:78685`) — dvs den slår upp rätt `FloorDetails` innan den genererar.

### Steg 1 — generatorn startar, seedar och kör lagren

`LayeredDungeonGenerator` (`dump.cs:74147`) är motorn:

- Fält: `_layers : List<GenerationLayer>` (`dump.cs:74153`), **`_runSeed : SeedVariable`** (`dump.cs:74155`), **`_rng : RandomAsset`** (`dump.cs:74157`), `_saveLoader : DungeonSaveLoader` (`dump.cs:74159`), `_mapData : TiledMapData` (`dump.cs:74161`), `_currentLayer` (`dump.cs:74162`).
- Publik ingång: `UniTask<TiledMapData> GenerateDungeonFloor(FloorLayerConfig floorConfig, DungeonGenerationConfig.DifficultyRange difficulty, int floorSeed = 0, bool allowFailure = False)` (`dump.cs:74175`) — **seedningen är per våning (`floorSeed`), inte bara per körning.**
- Tillståndsmaskinen för den metoden har lokalerna `maxRegenerationAttempts` (`dump.cs:74129`), `mapGenerated` (`dump.cs:74130`), `i` (`dump.cs:74133`) och `timeSliceStopwatch` (`dump.cs:74128`) — dvs **genereringen körs om upp till ett antal försök tills en karta godkänns, och den tidsdelas (time slicing) så den inte blockerar en frame.**
- `ApplyDungeonLayers(Stopwatch timeSliceStopwatch, bool ignoreRestrictions)` (`dump.cs:74182`) har lokalen `layerSuccess` (`dump.cs:74101`) — varje lager kan alltså misslyckas och hanteras.
- Varje lager är en `SerializedScriptableObject` med `virtual int GenerationOrder` och `abstract UniTask<bool> Apply(TiledMapData data, RandomAsset rng, bool ignoreRestrictions, CancellationToken cancellationToken)` (`dump.cs:74019`, `dump.cs:74027`, `dump.cs:74030`). **Lagret får alltså både kartan och slumptalsgeneratorn in; ordningen bestäms av `GenerationOrder`.**

Lagren som finns (klasslista ur dump.cs, alla i `Nosebleed.Pancake.ProceduralGeneration`):

| # | Lager | Rad | Vad det gör (belagt via fält/metodnamn) |
|---|---|---|---|
| – | `RoomGenerationLayer` | `dump.cs:73173` | Placerar rumslådor och separerar dem: `_roomSizeRestriction` (`73179`), `_minDistanceBetweenRooms` (`73186`), `_mapBoundingBoxBorder` (`73188`), `_badExitDirectionThreshold` (`73192`); `IterateRoomSeperation` (`73212`), `SnapRoomsToGrid` (`73227`), `FillRoomsOnGrid` (`73230`), `ValidateRoomOrientations` (`73218`). |
| – | `RoomSpringGenerationLayer` | `dump.cs:73385` | Samma sak men med fjäderkrafter: `_maximumPossibleDungeonSize` (`73397`), **`_targetDungeonSize` (`73399`)**, `CreateBoxes(rng)` (`73437`), `FindAllNeighbours` (`73440`), `CalculateSpringForce` (`73443`), `SpringLoop(iterations)` (`73447`), `CalculateSeparation` (`73498`), `SnapRoomPosition` (`73501`), `OptimiseRoomOrientationForExits` (`73468`), `DisableBlockedExits` (`73486`), `ValidatePlacedRooms` (`73489`), `ValidateUncontainedSpace` (`73480`). Regler i `RoomSpringGenerationLayerConfig` (`dump.cs:73540`): `_targetNeighbourSeparation` (`73559`), `_separationSpringStrength` (`73562`), `_boundarySpringStrength` (`73564`), `_centrePullSpringStrength` (`73568`), `_dampeningStrength` (`73570`), `_allowedUncontainedRooms`/`_allowedUncontainedCells` (`73575`/`73577`) — **rummen "flyter" isär, dras mot mitten och snäpps sedan till rutnätet.** |
| – | `RoomWhirlGenerationLayer` | `dump.cs:73849` | Tredje alternativet: rum splattas i "Space"/"PossibleSpace"/"RoomSplat"/"SplatGroup" (`dump.cs:73694`–`73725`) med ett `attempt`-tal (`dump.cs:73741`) och `CheckTargetSize` som returnerar `(valid, size)` (`dump.cs:73755`). |
| – | `BasePathGenerationLayer` | `dump.cs:70836` | Korridorer med A*/vägkostnad: `_distanceHeuristic` (`70844`), `_roomPadding` (`70848`), `_roomPaddingTraversalCost` (`70850`), `BlockRoomsOnGrid` (`70886`), `TryPathfindBetweenCoords` (`70877`), `ConvertToPath(...) -> Path` (`70880`); `Path = { FromRoomIndex, ToRoomIndex, Vector2Int[] Nodes }` (`dump.cs:70785`–`70790`). Heuristiker: `ShortestPathHeuristic`, `StraightPathHeuristic` (med `_turnPenalty`), `WigglyPathHeuristic` (med `Frequency`/`Amplitude`) (`dump.cs:70240`–`70284`). |
| – | `PathGenerationLayer` | `dump.cs:72570` | Utfallsviktning: `_forceClosedLoop` (`72575`), `_centreProximityReward` (`72579`), `_exitProximityReward` (`72583`), `_facingCentreReward` (`72585`), `_usedExitPunishment` (`72587`); jobbar på rankade utfall (`Exit { Coords, ExitScore, ExitUsed }`, `dump.cs:72511`–`72517`). |
| – | `PathMinimumSpanningTreeGenerationLayer` | `dump.cs:72876` | **Delaunay + MST:** `BuildDelaunayGraph` (`72933`), `CalculateEdgeWeights` (`72940`), `BuildMinimumSpanningTree` (`72944`) med union-find (`FindParent`/`Union`, `dump.cs:73000`/`73004`), sedan **extra kanter**: `FindExtraEdgesFromUnused(rng)` (`72948`) styrt av `_maximumLength` (`72895`), `_middleZoneRadius` (`72897`) och **`_maxExtraEdgeSelectionChance` (`72899`)**, samt `OpenExit(room, exit)` (`72958`). |
| – | `MetadataGenerationLayer` | `dump.cs:72363` | Kartans "metadata": `LinkRoomTiles` (`72416`), `CollectAvailableTiles` (`72422`), `SelectPrefabsForTiles(rng)` (`72425`), `FindBossCoords` (`72432`), `FindMainPath(fromBoss)` (`72429`), `FindDistanceFromMainPath` (`72436`), `GetFlowFieldFromCell(s)` (`72440`/`72444`), `FindBestSpawnCoords(flowField)` (`72447`), `GetUniquePathSegments` (`72451`), `FindPointsOfInterest` (`72464`), **`AssignTileDifficulties(Grid2D<float> fromSpawn)`** (`72468`). Konfig: `_prioritySpawnTag` (`72372`), `_offPathDifficultyInitialScale` (`72375`), `_offPathDifficultyMaxScale` (`72377`), `_maximumValidPathSegmentLength` (`72379`). Datatyper: `PathSegment` med `NumberOfCorners/NumberOfJunctions/NumberOfCrossroads` (`dump.cs:72051`–`72056`), `RoomOfInterest { RoomID, Interest }` (`72086`), `PointOfInterest { Coords, Interest }` (`72078`). |
| – | `EventGenerationLayer` | `dump.cs:71582` | Se steg 4 och 5 nedan. |
| – | `PropGenerationLayer` | `dump.cs:73060` | Rekvisita per rum: `TryPopulatePropTemplate(PropTemplate, PlacedRoom, DungeonTag)` (`73080`), `DoesPropMeetSpawnConditions` (`73083`), `TrySelectProp` (`73086`); `PropTemplate` har `_tagFilters` (`dump.cs:74423`), **`_spawnChance` (`dump.cs:74426`, `[Range(0,1)]`)**, `_spawnConditions` (`dump.cs:74428`). |
| – | `LightSourceGenerationLayer` | `dump.cs:71903` | Ljus/facklor: `_lightSourceTag` (`71910`), `_bumpableTag` (`71912`), `_priorityDrops` (`71915`), **`_randomLightSourceRange : Vector2Int` (`71919`, `[MinMax]`)**, **`_randomTable : List<DropWeight>`** (`71921`) där `DropWeight = { DropConfig Drop, int Weight, bool CapMaxAmount, int MaxNumberOfDropAllowed }` (`dump.cs:71756`–`71762`), `_lightSourceCoinRange` (`71924`), `_randomBumpableFurnitureRange` (`71928`); `SelectWeightedRandomDrop` (`71978`), `SelectMostInterestingSpawn` (`71975`). |
| – | `BorderGenerationLayer` | `dump.cs:71144` | Ytterkant: `_borderConfigs` med `BorderConfig { List<TagToggle> Tags }` (`dump.cs:71148`, `dump.cs:71103`–`71106`). |
| – | `MapInstantiationGenerationLayer` | `dump.cs:72032` | Instansierar kartan (enda lagret utan konfigfält). |

### Steg 2 — rutnätet: rum som mallar med rutor, utfarter och händelseplatser

- `TiledMapData` (`dump.cs:74680`) är våningen: `TileSize` (`74683`), **`MapTiles : Grid2D<MapTile>`** (`74684`), `Difficulty` (`74685`), `DifficultyRange` (`74686`), `DungeonTag` (`74687`), `PlacedRooms` (`74688`), `RoomConnections : List<Path>` (`74689`), `PathSegments` (`74690`), **`DefaultSpawnPoint : Vector2Int`** (`74691`), `Props` (`74692`), `Destructibles` (`74693`), `RoomsOfInterest` (`74695`), `PointsOfInterest` (`74696`).
- En ruta är en `MapTile` (`dump.cs:74705`) med `EncounterTemplate` (`74708`), `TileEvent : DungeonEvent` (`74709`), `TileEventDetails` (`74710`), `EnemyContainer` (`74711`), **`Difficulty : float` (`74713`)**, `IsOnMainPath` (`74714`), `IsRoom` (`74715`), `IsFloorExit` (`74717`), `ContainsAmbush` (`74718`), `EventEdge` (`74719`), `Connections` (`74721`), `ValidExits` (`74722`), `TileDefinition` (`74724`), `TileRotationOffset` (`74725`) och egenskaperna `HasEvent`, `IsTileEventDestructible`, `ShouldTileEventAutoComplete`, `IsEventOnTileEdge` (`74728`–`74731`).
- Rutans utseende/riktningar: `MapTileDefinition` (`dump.cs:74223`) med `ConnectionDirections` (`74230`), `TileExitDirections { None=0, North=1, East=2, South=4, West=8 }` (`dump.cs:74197`–`74201`), `EXITS_BIT_MASK = 15`, `NUMBER_OF_EXIT_DIRECTIONS = 4`, `CONNECTIONS_BIT_MASK = 255` (`dump.cs:74226`–`74228`) och rotationshjälparna (`74255`–`74267`).
- **Rummallarna** har riktig geometri: `RoomTemplate` (`dump.cs:74534`) med **`_roomDimensions : Vector2Int`** (`74543`), `_preferredCentreEdge` (`74545`), `_spawnPoints` (`74547`), `_propTemplates` (`74550`), `_roomTemplateEventsOdin` (`74553`), **`_tileTemplates : Grid2D<TileTemplate>`** (`74556`), `_exitCandidates` (`74559`), plus `GetEventCoordinates(...)` (`74602`) och `GetRoomBounds()` (`74605`).
- Varje ruta i mallen: `TileTemplate = { PathfindingFlags, ConnectionFlags, UseProcGen, IsExitCandidate, ExitDirection, ConnectsToNeighbours }` (`dump.cs:74453`–`74461`).
- **Rummallarnas faktiska mått står i deras namn i bundlarna** (GameObject-namn, lästa ur rumsmallarnas bundles): `RT_Generic_1x1_01`, `RT_Generic_2x1_01`, `RT_Generic_2x2_01-Boss`, `RT_Generic_2x3_01`, `RT_Generic_3x3_01`, `RT_Generic_4x4_01`, `RT_Generic_5x3_01`, `RT_MF-DP-CM_4x3_01`, `RT_GT-CM_2x3_Balcony_01`, `RT_GT_3x3_CentralBoss`, `RT_GT_5x3_Balcony_GalloBoss`, `RT_MeanyBridge_1x12`, `RT_TeenyBridge_1x12`, `RT_WeenyBridge_1x12` (ur `roomtemplates-simple_assets_all.bundle`, 40 `RT_`-namn och 42 `RoomTemplate`-instanser).
- **Rutstorleken är 1×1 världsenhet:** `Grid`-komponenten i `level2` har typetree-värdet `m_CellSize {x: 1.0, y: 1.0}` (och samma i sex Grid-instanser), och `Tilemap`-objekten har `m_TileAnchor {x: 0.5, y: 0.5}`.
- Rummallarna poolas i databaser: `RoomTemplateDatabase : TaggableAssetDatabase<RoomTemplateHandle>` (`dump.cs:74613`), `RoomTemplateHandle` med `_assetId`, `_tags`, **`_dimensions : Vector2Int`** (`dump.cs:74630`), `_assetReference` (`dump.cs:74622`–`74632`).

### Steg 3 — rum väljs och placeras

- Baslagret för rum har **`_roomRequirements : List<RoomTagSelector>`** (`dump.cs:71068`) och `RoomTagSelector = { List<TagToggle> Tags; int Number; }` (`dump.cs:70974`–`70978`) — dvs **"N rum som matchar dessa taggar"**.
- `SelectRoomTemplates(DungeonTag dungeonTag)` (`dump.cs:71082`) hämtar kandidater; `SortAndSelectRooms(List<RoomTemplateHandle> availableRooms, int roomsRequired)` (`dump.cs:71096`) väljer ut dem; `LoadSelectedRoomTemplates()` (`dump.cs:71086`) laddar prefabsen; **`PlaceRoom(data, handle, template, placedExtents, rotation)`** (`dump.cs:71089`) placerar rummet med en rotation.
- `PlacedRoom` (`dump.cs:70957`) = `{ RoomExtents Extents; Rotation Rotation; RoomTemplateHandle Handle; RoomTemplate Template; Grid2D<PlacedTileInfo> TemplateToGridLookup; List<ExitInfo> Exits; }`; `Rotation { _0=0, _90=1, _180=2, _270=3 }` (`dump.cs:70945`–`70953`).
- Taggar som styr urvalet är riktiga assets. Ur `globalgamemanagers.assets` (typetree-lästa namn): `Tag_Room`, `Tag_Room_2x2`, `Tag_Room_2x3`, `Tag_Room_3x3`, `Tag_Room_4x3`, `Tag_Room_4x4`, `Tag_Room_5x3`, `Tag_Corridor`, `Tag_InnerBorder`, `Tag_OuterBorder`, `Tag_Spawn`, `Tag_End`, `Tag_LightSource`, `Tag_Bumpable`, `Tag_Shovel`, `Tag_CoinDrop`, `Tag_ChickenDrop`, `Tag_Relic_GemHammer`. Dessutom ligger **per-mall-taggar i samma bundle som mallen**, t.ex. `Tag_Layout_2x3_01`, `Tag_Layout_2x3_Balcony_04-Boss`, `Tag_Layout_5x3_GalloBoss`, `Tag_Layout_TinyBridge_1x20`, `Tag_Layout_2x2_GemChest`, `Tag_Layout_WingBalcony` (roomtemplates-simple, rt_gemchest, rt_wingbalcony). Egna taggtyper finns: `DungeonTag` (`dump.cs:90101`), `MultiTag` (flera taggar i en, `dump.cs:74296`), `GenerationTag` (`dump.cs:74047`), matchning via `TagToggle.MatchesTags(List<GenerationTag>)` (`dump.cs:74084`).
- Rummen placeras alltså som **färdiga, taggade mallar med egna mått** — inte som genererade rektanglar.

### Steg 4 — händelser (strider, boss, side events, ambushes, manuella) stoppas in

`EventGenerationLayer` (`dump.cs:71582`) är våningens händelseplanerare. Konfigfält:

- **`_targetTemplateEncounterNumber : int`** (`71594`) — antal mall-styrda möten på våningen.
- **`_bossEvent : DungeonChoices`** (`71597`), `_minibossEvents : List<DungeonChoices>` (`71600`).
- **`_numberOfSideEventsToSpawn : int`** (`71604`) + `_sideEvents : List<DungeonChoices>` (`71606`).
- **`_maxAmbushes : int`** (`71609`), `_overrideAmbushChance : bool` (`71611`), **`_ambushChanceOverride : float` `[Range(0,1)]`** (`71614`), `_ambushEvents : List<DungeonChoices>` (`71616`).

Körordningen syns i metodnamnen: `InitFlowGraph` (`71650`) → `Setup` (`71654`) → **`AssignBossEncounter` (`71658`) → `AssignMinibosses` (`71662`) → `AssignSideEvents` (`71666`)` (+ `CheckSideEventRequirements`, `71669`) → `AssignManualEvents` (`71673`) → `AssignAmbushEvents` (`71677`) → `AssignTemplateEvents` (`71681`)**.

Placeringen är flödesbaserad, inte slumpmässig:

- Fälten `_flowGraph : Grid2D<int>` (`71632`), `_maxFlowDistance` (`71634`), `_usedCells : Grid2D<bool>` (`71627`), `_allRoomEventSpawns : Grid2D<EventGenerationLayer.RoomTileInfo>` (`71633`) och metoderna `AddCoordToFlowGraph` (`71685`), `GetMaxValueInGrid` (`71688`), `CanEventSpawnAtCoordinates` (`71738`) betyder att varje placerad händelse skjuter upp avstånd i ett flödesfält så **nästa händelse hamnar så långt bort som möjligt**.
- `GetBossCoordinates()` (`71713`) och `FindBossCoords` (`72432`) ger bossens ruta; `GetEventSpawnSideForTile` (`71741`) ger vilken sida av rutan markören ska stå på.
- Placering sker i prioritetsordning mot "intressanta" platser: `TrySpawnInROI` (`71702`, `RoomOfInterest`), `TrySpawnOnPOI` (`71706`, `PointOfInterest`), `TrySpawnInRoom` (`71710`), annars `AddEventToWorld(handle, interesting)` (`71698`) / `AssignEventHandle(handle, coords, forceOverride, veryBoring)` (`71717`) — **`veryBoring`-parametern visar att det finns ett medvetet "tråkigt" fall när inget bättre finns.**
- Malloceller: `GetValidEventSpacesOfTypeInRoom(room, type, ...)` (`71726`), `DoesEventMeetConditions` (`71729`), `RemoveEventsNotMeetingConditions` (`71732`), `GetBestRoomTemplateEvent(room, options)` (`71691`), `AssignEncounterTemplateEvent(coords)` (`71723`).
- Händelsetyper: `EventHandleType { Boss=0, Miniboss=1, Side=2, Template=3, Manual=4, Ambush=5 }` (`dump.cs:71167`–`71177`) och mallplatsernas typer `RoomTemplateEventType { Manual=0, TemplateCandidate=1, MiniBossCandidate=2, BossCandidate=3 }` (`dump.cs:74522`–`74529`). Ikon-strängarna i lagret är `RoomTemplates/icon_boss`, `icon_miniboss`, `icon_manual`, `icon_template`, `icon_ambush` (`dump.cs:71585`–`71590`).
- En mallplats har koordinat: `RoomTemplateEvent = { Vector2Int Coordinates; RoomTemplateEventType EventType; List<SpawnConditionInfo> Conditions; DungeonChoices ManualEventOptions; }` (`dump.cs:74476`–`74484`).
- Villkor: `SpawnCondition { IsUsedAsExit=0, IsUsedAsEventSpace=1, IsMapBossSpace=2, IsMapSpawnPoint=3, HasUnlockCriteria=4 }` (`dump.cs:74510`–`74518`), med `SpawnConditionInfo { ConditionCoords, Condition, InvertCondition, UnlockType }` (`dump.cs:74494`–`74501`) och `MeetsSpawnCondition(mapData, gridCoords, conditionInfo)` (`dump.cs:74838`).

### Steg 5 — vilken händelse som faktiskt hamnar på platsen (viktning)

- `DungeonChoices` (`dump.cs:87875`) håller `List<DungeonEvent> _possibleDungeonEvents` (`87888`) och `_totalWeight` (`87883`), med `CalculateProbabilities()` (`87903`) och **`GetWeightedRandomEvent(RandomAsset random)`** (`87909`).
- `DungeonEvent` (`dump.cs:87926`) är den viktade posten: **`IsGuaranteed` (`87931`), `Weight : int` (`87934`), `Probability : float` (`87935`), `IsFinalEventForFloor` (`87937`)**, `_eventConfigReference` (`87939`), `_shouldOverrideEventDetails` (`87941`), `_isAmbush` (`87945`), och `CalculateProbability(IDungeonChoice choices)` (`88013`).
- `CalculateTotalWeight`/`GetTotalWeight`/`CalculateProbabilities` (`87911`–`87918`) ⇒ **vikter normaliseras till sannolikheter en gång, sedan dras en viktad slump per plats.**

### Steg 6 — svårighetsgraden läggs på rutorna

- `MetadataGenerationLayer.AssignTileDifficulties(Grid2D<float> fromSpawn)` (`dump.cs:72468`) sätter `MapTile.Difficulty`; under huven finns `FindMainPath(fromBoss)` (`72429`), `FindDistanceFromMainPath` (`72436`), `GetFlowFieldFromCells` (`72444`) och lokalerna `maxDistanceFromMainPath`, `difficultyAtMaxDistance` (`dump.cs:72191`–`72192`).
- Kurvan ligger i `DungeonGenerationConfig.DifficultyRange` (`dump.cs:90748`): `Vector2 MinMaxDifficulty`, `AnimationCurve MinEnemyVariance`, `MaxEnemyVariance`, `MinEncounterVariance`, `MaxEncounterVariance`, plus `CalculateEnemyVarianceForDifficulty(float tileDifficulty)` (`90764`) och `CalculateEncounterVarianceForDifficulty` (`90767`).
- `TiledMapUtils.CalculatePathDifficulties(Grid2D<MapTile> map, List<PathNode> path, float difficultyMin, float difficultyMax)` (`dump.cs:74805`) lägger kurvan längs vägen.
- Vid sidan av huvudvägen sänks svårigheten: `_offPathDifficultyInitialScale` / `_offPathDifficultyMaxScale` (`dump.cs:72375`/`72377`).

### Steg 7 — mötet fylls med fiender (2D-matris, rader)

- `EnemyEncounterConfig` (`dump.cs:90439`): **`_enemies : EnemyConfig[,]`** (`90460`), `_shouldEnemiesGoFirst` (`90445`), `_completeDungeonOnDeath` (`90449`), `_blocksOverkill` (`90451`), `_allowsDynamicBossSpawning` (`90453`), `_enemyMarkerOverride` (`90455`), `_markerOverrideShouldFaceExit` (`90457`).
- `EnemyContainer` (`dump.cs:90324`) håller samma matris (`_enemies`, `dump.cs:90327`) och serialiseras som `EnemyContainer.SaveData { int ColumnCount; int RowCount; string[] EnemyConfigIds; bool DoEnemiesGoFirst; bool BlocksOverkill; bool AllowsDynamicBossSpawning; }` (`dump.cs:90312`–`90320`) — **kolumn- och radantalet sparas per möte, så matrisen är inte en fast storlek; antalet rader/kolumner varierar mellan möten.**
- Matrisen motsvarar rutor i en layout: `DungeonEnemyMarker` (`dump.cs:77111`) har `_enemies : EnemyConfig[,]` (`77119`) och **`_spawnedEnemyModels : Dictionary<Vector2Int, EnemyModel>`** (`77118`) med `SetEnemies(EnemyConfig[,])` (`77131`).
- Striden är radbaserad: `RowMovementModel` (`dump.cs:86165`) har `_rows : List<EnemyGroupModel>` (`86173`) och egenskaperna `TotalRowCount`, `ActiveRowCount`, `FrontRow`, `FrontRowIdx` (`86190`–`86199`); `EncounterRowsView` (`dump.cs:43445`) har `SetupRows(List<EnemyGroupModel> rowModels)` (`43475`).
- Mallarna genererar mötet: `EncounterTemplate` (`dump.cs:90228`) med `_encounterDifficulty` (`90237`), **`_preSelectEnemies`** (`90240`, kommentar: "If true will pre-select the Low and High difficulty enemy and use it in all slots. If false, each slot will be individually chosen."), **`_rules : EnemySelectionRule[,]`** (`90242`), `_allowedDungeonTags` (`90245`), **`public const int MAX_ENEMY_RULES = 4`** (`90231`).
- Urvalsregler per plats: `EnemySelectionRule { Empty=0, Baseline=1, LowerDifficulty=2, HigherDifficulty=3 }` (`dump.cs:90184`–`90191`) och `EnemyDifficultyRange { float Difficulty; float MinVariance; float MaxVariance; }` (`dump.cs:90195`–`90201`).
- Algoritmen syns i metodnamnen: `GenerateEncounter(dungeonTags, rng, difficulty)` (`90268`/`90271`/`90274`), `PopulateEnemyPool(enemyPool, dungeonTags, enemies, ref minDifficulty, ref maxDifficulty)` (`90277`), `SelectBaselineEnemy(enemyPool, tileDifficulty)` (`90283`), `FindLowerEnemies(...minVariance)` (`90286`), `FindHigherEnemies(...maxVariance)` (`90289`), `WeightedSelectEnemy(configs, maxDelta, ...)` (`90304`), `FindClosestEnemyMatch(enemyPool, targetDifficulty)` (`90280`) — dvs **basfiende närmast rutans svårighetsgrad, sedan en lättare och en tyngre inom tillåten varians, och den valda fienden sprids eller väljs per plats.**
- Fiendepoolen filtreras på `EnemyConfig._dungeonTags` (`dump.cs:91157`) och `EnemyConfig.AllowInTemplate` (`dump.cs:91128`); `EnemyConfig.EnemyDifficulty` (`91146`) är vikten som matchas.
- Guarded/vaktmöten är egen klass: `GuardianEncounterConfig` (`dump.cs:90605`) med **`totalGuardians` (`90620`), `activeCount` ("Number of enemies that the player can attack and can perform an action at a time", `90622`), `endTurnRotationStep` (`90624`), `guardianCircleRadius` (`90628`)** — vakter står i en cirkel och roterar.

### Steg 8 — våningen instansieras och sparas

- `Dungeon3DMapModel.SpawnDungeonObjects(DungeonGenerationConfig, floorIdx, TiledMapData)` (`dump.cs:79170`) → `SpawnEventMarkers` (`79173`), `SpawnEventMarker(coords)` (`79186`), `TrySpawnTileEventMarker` (`79195`), `TrySpawnTemplateEncounterMarker` (`79189`), `SpawnEnemyMarker(EnemyContainer, worldPos, rotationOffset, isAmbush, markerOverride)` (`79192`), `SpawnDestructibleEvents` (`79177`), `ClearEventMarkers` (`79198`).
- Markörer registreras per koordinat: `_eventMarkers : Dictionary<Vector2Int, EventMarker>` (`dump.cs:78922`), `TryGetEventMarker(coords, out marker)` (`dump.cs:79092`).
- **Autostart av en rutehändelse:** signaturen `public bool ShouldTileEventAutoStart(Vector2Int roomCoords)` finns (`dump.cs:79049`), tillsammans med `OnStepTaken()` (`79052`), `StartCurrentTileEvent()` (`79131`), `StartCurrentTileEventTask` (`79135`) och `DisableAutoCompleteEvents()` (`79180`). Logiken i kroppen kan inte läsas (inga metodkroppar), men flaggorna den rimligen bygger på finns: `MapTile.ShouldTileEventAutoComplete` (`74730`), `DungeonEventConfig.AutoCompleteEvent` (`90034`) och `EmptyEventConfig` som överridar den (`90173`–`90174`), samt `_isEdgeEvent` (`90007`) och `IsEventOnTileEdge` (`74731`) för kant-event man "buffar" in i (`_edgeEventBumpSFX`, `dump.cs:90026`).
- **Våningen sparas som serialiserad text, inte som ett seed:** `DungeonSaveLoader.SaveMapAsString(TiledMapData)` (`dump.cs:70762`), `CreateMap(string serializedMap, ...)` (`70732`), `CreateSaveData(TiledMapData) -> MapSaveData` (`70765`), `FromSaveData(MapSaveData)` (`70769`), `GetMapFromString` (`70759`); komprimering via `BinaryExtensions.WriteDungeonMap`/`ReadDungeonMap` (`dump.cs:70182`/`70186`) och `CompressData`/`DecompressData` (`70221`/`70224`).
- `MapSaveData` (`dump.cs:74752`) innehåller hela kartan: `Width`/`Height` (`74755`/`74756`), `RoomMinimumExtents`/`RoomMaximumExtents` (`74759`/`74760`), `RoomTemplateLookupIDs` (`74761`), `RoomRotations` (`74762`), `TileDifficulties` (`74774`), `ExitTile` (`74775`), `TileEventLookupIDs` (`74778`), `EnemyContainerData` (`74782`), `TileEventsCleared` (`74784`), `TilesContainAmbush` (`74785`).
- `Dungeon3DMapModel.SaveData` (`dump.cs:78614`) har `DungeonMapString` (`78617`), `PlayerCoords` (`78618`), `StepsTakenThisFloor` (`78621`).

### Steg 9 — våningar och ändlöst läge

- `DungeonModel` (`dump.cs:81781`) håller `_completedFloorsCount` (`81816`), `CompletedFloorsCount` (`81852`), `FloorIndex` (`81853`) och eventet `Action<DungeonConfig, int, int> DungeonFloorCompleted` (`81842`) samt `DungeonLoaded` (`81844`).
- `FloorTransitionState : StateBehaviour<GameModel>` (`dump.cs:68216`) är övergången mellan våningar (en spellägestillståndsmaskin, inte en genereringsdel).
- Ändlöst läge: `DungeonGenerationConfig._allowEndlessMode` (`90793`), `AllowsEndlessMode` (`90800`), `GetEndlessStatChangesForEndOfFloor(int totalVisitedFloorNumber, ref List<ValueTuple<PlayerStats.Stats,float>> statChanges)` (`90814`), och `EndlessModeStatSettings { StatToChange; _baseValue; _increasePerFloor; }` med `GetStatToAddValue(int numberOfFloorsCompleted)` (`dump.cs:90969`–`90986`) — när `visitedFloorCount` överstiger antalet konfigurerade våningar återanvänds konfigurationen med eskalerande statistik.

### Steg 10 — seedning och återskapande

- **Seed:** `SeedVariable` (`dump.cs:4747`) är en asset med `private int _seed` (`4751`) och metoderna `Generate()` (`4762`) och `SetSeed(int seed)` (`4765`).
- Slumptalskällan är en asset: `RandomAsset : ScriptableObject` med **`public Random Random`** (`dump.cs:3061`–`3064`) — ett `System.Random` som skickas in i varje lager (`Apply(..., RandomAsset rng, ...)`, `dump.cs:74030`).
- Per våning: `_runSeed : SeedVariable` (`74155`) i generatorn och parametern `int floorSeed = 0` i `GenerateDungeonFloor` (`74175`).
- **Samma dungeon återskapas genom att kartan sparas, inte genom att seedet körs om** (steg 8 ovan). Det finns ingen "regenerera från seed"-väg belagd för en pågående körning; däremot finns `SeedVariableText : MonoBehaviour` (`dump.cs:12092`) som visar seedet i gränssnittet.

---

## 2. Rumstyper och deras garanterade/viktade förekomst

Källa för "garanterad/viktad": endast kodstrukturen (fält/metodnamn) — konfigvärdena är oläsbara, se avsnitt 3.

| Rumstyp | Belägg | Garanterad eller viktad |
|---|---|---|
| Bossrum | `_bossEvent : DungeonChoices` (`dump.cs:71597`), `AssignBossEncounter` (`71658`), `GetBossCoordinates` (`71713`), `FindBossCoords` (`72432`), `MapTile.IsFloorExit` (`74717`), `RoomTemplateEventType.BossCandidate` (`74529`) | **Garanterad** — bossen tilldelas alltid i ett eget steg, och `DungeonEvent.IsGuaranteed` (`87931`) finns som flagga för att tvinga en post. |
| Mini-boss | `_minibossEvents : List<DungeonChoices>` (`71600`), `AssignMinibosses` (`71662`), `MiniBossCandidate` (`74528`) | Viktad ur listan; antalet kommer från listans innehåll (värdet oläsbart). |
| Side events (valfria händelser) | `_numberOfSideEventsToSpawn : int` (`71604`), `_sideEvents` (`71606`), `AssignSideEvents` (`71666`), `CheckSideEventRequirements` (`71669`) | **Antalstyrd** (fast antal per våning) men innehållet viktas. |
| Bakhåll (ambush) | `_maxAmbushes` (`71609`), `_ambushChanceOverride` `[Range(0,1)]` (`71614`), `_ambushEvents` (`71616`), `AssignAmbushEvents` (`71677`), `MapTile.ContainsAmbush` (`74718`), `DungeonEvent._isAmbush` (`87945`) | **Slumpad med tak** — ett maxantal och en chans. |
| Mall-möten (template encounters) | `_targetTemplateEncounterNumber : int` (`71594`), `AssignTemplateEvents` (`71681`), `AssignEncounterTemplateEvent` (`71723`), `TemplateCandidate` (`74527`) | **Antalstyrt mål** per våning. |
| Manuella händelser i mallen | `AssignManualEvents` (`71673`), `RoomTemplateEventType.Manual` (`74526`), `RoomTemplateEvent.ManualEventOptions : DungeonChoices` (`74484`) | Fasta platser som mallen själv pekar ut, med viktat innehåll. |
| Relikrum | Bundle `roomtemplates-relics_assets_all.bundle` med 18 `RoomTemplate`-instanser och namnen `RT_Relic_2x2_BombaInfernale`, `RT_Relic_2x2_GrimGrimoire`, `RT_Relic_2x2_MilkyWayMap`, `RT_Relic_2x2_Overkill (Unused)`, `RT_Spawn_Relic_2x1_FccPamphlet`, `RT_Spawn_Relic_2x1_GemHammer`, `RT_Spawn_Relic_2x1_LapidaryLoupe` m.fl. | **Kan inte beläggas som garanterad per våning** — egna rum, men ingen läsbar garanti-flagga. Två varianter syns dock: `RT_Relic_*` (2x2) och `RT_Spawn_Relic_*` (2x1). |
| Gemskattrum | `roomtamplates-unique_assets_rt_gemchest.bundle` → `RT_GemChest`, tagg `Tag_Layout_2x2_GemChest` | Egen enkelrumstyp; antal/garanti oläsbart. |
| Slutboss | `roomtamplates-unique_assets_rt_enderboss.bundle` → 1 `RoomTemplate` | Egen rumstyp för dungeonslut. |
| Bakhåll-övergång till boss | `roomtamplates-unique_assets_rt_mf_3x3_ambushintoboss.bundle` → `RT_MF_3x3_AmbushIntoBoss`, tagg `Tag_Layout_3x3_06` | Egen 3x3-mall som leder in i bossen. |
| Balkongrum (wing balcony) | `roomtamplates-unique_assets_rt_wingbalcony.bundle` → `RT_CM_WingBalcony`, tagg `Tag_Layout_WingBalcony`; `RT_GT-CM_2x3_Balcony_01` m.fl. i simple-bundlen | Endast för vissa dungeons (balconys är taggade `Tag_BalconyDungeons`/`Tag_BalconyBlocker`). |
| Tutorial- och kreditrum | `roomtamplates-unique_assets_rt_tutorial.bundle` (1 `RoomTemplate`, `TutorialDungeonCutscene`), `roomtamplates-unique_assets_rt_credits.bundle` → `RT_Credits` | Speciella, ej i normalpoolen. |
| Broar | `RT_TeenyBridge_1x12`, `RT_WeenyBridge_1x12`, `RT_MeanyBridge_1x12`, tagg `Tag_Layout_TinyBridge_1x20` (roomtemplates-simple) | 1×12/1×20-rader — en annan geometri än de kvadratiska rummen. |
| Vaktmöte (guardian/coffin) | `GuardianEncounterConfig` (`dump.cs:90605`) med `totalGuardians`, `activeCount`, `endTurnRotationStep` | Egen händelsetyp, placeras som händelse (inte som rumstyp). |
| Passiva/föremålshändelser | `PassiveEventConfig` (`dump.cs:90704`), `PassiveEventView`, `PassiveEventName` (`90713`) | Placering via händelselagret. |
| Förstörbara händelser | `DestructibleEventConfig` (`dump.cs:89927`), `_requireNonExitEdge` (`89934`), `EventIsDestructible` (`89942`) | Kräver en kant som inte är utgång. |
| Tom händelse | `EmptyEventConfig` (`dump.cs:90142`) med egen `AutoCompleteEvent` (`90173`) | Används för platser som ska tömmas/kvitteras automatiskt. |

---

## 3. Vad som INTE kunde beläggas

1. **Alla konfigvärden.** Typetrees för spelets egna skripttyper innehåller bara basfälten (`m_GameObject`, `m_Enabled`, `m_Script`, `m_Name` — läst ur `roomtamplates-unique_assets_rt_gemchest.bundle`), och `dump.cs` har inga metodkroppar. Därför oläsbara: `_targetDungeonSize`, `_maximumPossibleDungeonSize`, `_targetTemplateEncounterNumber`, `_numberOfSideEventsToSpawn`, `_maxAmbushes`, `_ambushChanceOverride`, `_maxExtraEdgeSelectionChance`, `_maximumLength`, `_middleZoneRadius`, `_randomLightSourceRange`, `_lightSourceCoinRange`, `_allowedUncontainedRooms/Cells`, alla `DungeonEvent.Weight`/`Probability`, `maxRegenerationAttempts`, `_stepConfig`, `_floorCoinBonus`, `_enemyHealthMultiplier`, alla kurvor i `DifficultyRange`.
2. **Lagrens ordningstal.** `GenerationOrder` finns som egenskap, men konstanterna kan inte läsas (metodkroppar saknas). Att `BorderGenerationLayer`, `EventGenerationLayer` och `PropGenerationLayer` har *identiska* RVA:n för `get_GenerationOrder` (`0x24A3690`, `dump.cs:71156`/`71643`/`73073`) betyder bara att de returnerar samma konstant — vilket värde framgår inte.
3. **Kartans storlek i rutor, antal rum per våning, antal våningar per dungeon.** Inga siffervärden går att läsa; bara att storleken är konfigurerad (`_targetDungeonSize`, `MapSaveData.Width/Height`, `DungeonGenerationConfig._floors`). Rutstorleken är dock belagd som 1×1 enhet (`Grid.m_CellSize {1.0, 1.0}`).
4. **`RoomTemplate._roomDimensions`-värden.** Fältet finns (`dump.cs:74543`) men värdet är oläsbart. Måtten i tabellen ovan är lästa ur **prefabnamnen** (`RT_Generic_2x3_01`), inte ur fältet.
5. **`ShouldTileEventAutoStart`-logiken.** Endast signaturen (`dump.cs:79049`) och angränsande metoder/flaggor är belagda; villkoren i kroppen går inte att läsa.
6. **Konkreta fienderadantal per möte.** `EnemyContainer.SaveData` har `RowCount`/`ColumnCount`, men de är körningsvärden; `MAX_ENEMY_RULES = 4` (`dump.cs:90231`) är den enda belagda konstanten, och om den gäller matrisens bredd eller antalet urvalsregler går inte att avgöra utan metodkroppar.
7. **Vilka rumstyper som är garanterade per våning, som lista.** Bara kodvägarna är belagda (boss alltid via `AssignBossEncounter`; antalstyrda side/template/ambush via konfigvärden som är oläsbara).
8. **Huruvida `floorSeed` härleds ur körningens `_runSeed` eller dras slumpmässigt.** Signaturerna visar att båda finns, inte hur de hänger ihop.
9. **Om en redan genererad våning kan återskapas från seed utan sparfil.** Sparvägen är belagd (`SaveMapAsString`/`MapSaveData`); någon seed-baserad återuppbyggnad av en pågående körning kunde inte beläggas.
10. **Innehållet i `_runSeed`/`SeedVariable`-asseterna** (det faktiska standardseedet) — assetvärden oläsbara.
11. **Vilka `_roomRequirements`-taggar och `Number`-värden våningarna faktiskt använder** — endast att mekanismen finns (`RoomTagSelector`), samt att tagg-asseterna existerar med namn som `Tag_Room_2x3` och `Tag_Layout_2x3_01`.

---

## 4. Jämförelse mot vår generator (`game/core/dungeon.gd`)

Vår våning byggs i en enda funktion: `generate()` gör BSP-delning (`_split`, `dungeon.gd:400`), gräver rum och L-korridorer i BSP-ordning (`dungeon.gd:166`–`180`), lägger till några extra förbindelser, väljer boss bland de bortersta fjärdedelsrummen (`dungeon.gd:190`–`195`), delar ut strider/kista/relik/facklor och returnerar.

**Vad VC gör som vi inte gör**

1. **Rummallar i stället för genererade rektanglar.** VC:s rum är färdiga prefabs med egna mått (`RT_Generic_2x3_01`), utfartsflaggor per ruta (`TileTemplate.IsExitCandidate`, `ExitDirection`), spawnpunkter och händelseplatser med koordinater. Vi genererar rektanglar och placerar noder på slumpade inre rutor.
2. **Rum väljs via taggar med antal.** `RoomTagSelector { Tags, Number }` (`dump.cs:70974`) gör att man kan säga "3 st 2x3-rum och 1 relikrum" och få exakt det. Vår BSP-delning ger ett brett men ostyrt blandat rumssortiment och ingen möjlighet att beställa en typ.
3. **Rummen packas med krafter, inte genom delning.** `RoomSpringGenerationLayer` flyttar isär rum, drar dem mot mitten och snäpper dem till rutnätet (`_targetNeighbourSeparation`, `_centrePullSpringStrength`, `SnapToGrid`), med validering (`ValidatePlacedRooms`, `ValidateUncontainedSpace`) och regler per tagg (`RoomSpringRules`). Våra rum ligger där delningen lade dem — avståndet mellan rum varierar helt utan kontroll.
4. **Korridorer är en graf, inte en kedja.** VC bygger Delaunay + minimum spanning tree och lägger sedan *avsiktligt* till extra kanter med en chans (`_maxExtraEdgeSelectionChance`) för att få slingor. Vi kedjar rummen i BSP-ordning och slår in upp till `rooms.size()/4` extra förbindelser på måfå — samma idé, men utan MST som garanti och utan kontroll över hur många slingor som uppstår.
5. **Svårighet per RUTA ur ett flödesfält, inte per rum ur avstånd.** VC sätter `MapTile.Difficulty` via `AssignTileDifficulties(fromSpawn)` med egna kurvor och sänker svårigheten vid sidan av huvudvägen (`_offPathDifficultyInitialScale`). Vår `rum_svarighet` (`dungeon.gd:75`) använder Manhattan-avstånd från start med ett stegs brus — grövre, och den känner inte av huvudväg kontra sidoväg.
6. **Möten är 2D-matriser med rader i striden.** VC:s `EnemyConfig[,]` + `RowMovementModel` gör ett rum till en *pack* med frontrad/aktiva rader, och varje plats fylls med bas/lägre/högre fiende kring rutans svårighetsgrad. Våra `encounter`-noder har **en** `enemy_id` per ruta (`dungeon.gd:255`), så "pack" finns inte som begrepp hos oss.
7. **Händelser hamnar på mallplatser med villkor och spridning.** VC:s händelselager använder flödesfält för att sprida ut händelser maximalt, prioriterar intressanta rum (RoomsOfInterest/PointsOfInterest) och kontrollerar villkor per plats (`IsUsedAsExit`, `IsMapBossSpace`, `InvertCondition`, `UnlockType`). Våra noder läggs på `_spots` (slumpad ordning i rummet) med undantag för boss- och startrutan.
8. **Genereringen kan misslyckas och köras om.** `maxRegenerationAttempts` + `allowFailure` + `layerSuccess` + `ValidatePlacedRooms` betyder att VC kastar och gör om tills våningen är giltig. Vi bygger en gång; blir det fel (t.ex. tom fiende-pool) returnerar `generate` `null` (`dungeon.gd:226`).
9. **Ljus är en egen viktad tabell med tak.** VC:s `DropWeight { Drop, Weight, CapMaxAmount, MaxNumberOfDropAllowed }` låter varje ljuskälla ha egen vikt OCH eget tak. Vi har en global andel med min/max (`FACKLOR_MIN/ANDEL/TAK`, `dungeon.gd:62`–`64`), vilket är nära men inte per-typ.
10. **Flera våningar med egen lagerlista och eget svårighetsspann.** VC:s `FloorDetails { FloorLayer, Difficulty }` ger varje våning sin egen uppsättning lager och sin egen kurva, plus ändlöst läge med eskalerande statistik. Vår `Floor` skiljer sig bara via `stage` och `floor_index`, och ytan styrs av svårighetsgraden (`_yta`, `dungeon.gd:22`).

**Vad som är värt att kopiera medan slumpen behålls**

- **Taggning av rum med antal** (rung 2 ovan): låt `_split` fortsätta slumpa fram rummen, men märk dem (storlek/tema/innehåll) och låt en liten tabell beställa "minst N av X" — t.ex. garantera ett relikrum och ett "stort" rum per våning. Slumpen i formen behålls, blandningen blir avsiktlig. Detta är samma mekanik som `RoomTagSelector { Tags, Number }` men utan mallsystemet.
- **Kraftbaserad separering i stället för ren delning** är för stor omskrivning för att vara värd det; däremot är VC:s **validering + omförsök** (`ValidatePlacedRooms`, `maxRegenerationAttempts`) billig att kopiera: kör `generate`, kontrollera med det vi redan har (`reachable`, `unreachable_nodes`, `dungeon.gd:618`/`635`), och generera om med nästa seed om kontrollen faller. Vi har redan kontrollerna — vi saknar bara omförsöksloopen.
- **Svårighet per ruta** är den enskilt största kvalitetsskillnaden: VC:s rutor har egen `Difficulty` som mötet läser, medan vår svårighet sitter på rummet. Att flytta vår `rum_svarighet` till en ruta-nivå (och lägga huvudvägen som en billig flödesberäkning) skulle göra "ju längre in, desto hårdare" jämnare utan att något sparas i sparfilen.
- **Seedet i klartext** (`SeedVariableText`) och **våningen som serialiserad karta** (`SaveMapAsString`/`MapSaveData`) är båda prisvärda: vi har redan `MapIo` med handritade `data/maps/*.json` som går genom `MapIo.validate` — en genererad våning kan gå genom *samma* väg (skriv JSON, läs tillbaka exakt samma våning) och vi får både återskapande och "dela en karta" utan ny mekanik.
- **Pack som begrepp** (fiendematris + rader) är en speldesignfråga snarare än kartgenerering — värt att notera, men den rör stridssystemet, inte `dungeon.gd`.

**Slutsats:** VC:s kartgenerering är inte "samma sorts slump, mer inställningar" — den är **mallbaserad**: rum, händelseplatser och svårighetskurva är författade assets som genereringen väljer och placerar. Vår styrka är att våningen är ny varje gång och att den är deterministisk från `(stage, våning, seed)`. Det som kan kopieras utan att ge upp slumpen är **validering med omförsök**, **taggar med antalskrav ovanpå den slumpade delningen**, **svårighet per ruta**, och **seed/karta i klartext för återskapande**.
