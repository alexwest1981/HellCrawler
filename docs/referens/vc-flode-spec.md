# Vampire Crawlers — spelflöde, specifikation

Källor (allt LÄST, inget i spelet ändrat):

- `vc_texter/*.json` — VC:s egna lokaliseringsrader (id → text). Citerade som `nyckel: "text"`.
- `il2cpp/dump.cs` — Il2CppDumper av `Assembly-CSharp`. **Inga metodkroppar** finns: endast typer, fält, egenskaper och metodsignaturer. Radnummer citeras som `dump.cs:NNNNN`.
- `vc-mnt/.../StandaloneWindows64/*.bundle` — bundle-namn citeras som bevis för rumstyper.

Genomgående: där något inte går att belägga står **"kunde inte beläggas"**.

---

## 1. Flödet från Start till körningens slut

### A. Uppstart och huvudmeny

1. **Bootstrap / varningsskärm.**
   `Menus` `101908280530427904: "PHOTOSENSITIVITY WARNING"`, `101909572128595968: "PRESS TO START"`.
   Scenen styrs av `GameStateManager.State` vars första värden är `Bootstrap = 0`, `MainMenu = 1` (`dump.cs:15587`).

2. **Huvudmenyn** (`MenuScreenView`, `dump.cs:48782`).
   Knappar belagda som serialiserade fält: `_newGameButton`, `_newGameSkipTutorialButton`, `_continueButton`, `_loadGameButton`, `_deleteSettingsButton`, `_wishlistButton`, `_optionsButton`, `_quitButton`, `_creditsButton`.
   Texter: `4895032311808: "New Game"`, `4895044894720: "Continue"`, `4895044894721: "Load Game"`, `4895044894722: "Delete All Save Data"`, `4895049089025: "Options"`, `102218972898779136: "Credits"`, `4895049089024: "Quit"`.
   Val av sparfil sker i `SaveSelectModal` (`dump.cs:32846`) + `SaveSlotOptionsModal` (`dump.cs:32944`); `21355045683200: "Save Slot Options"`, `24098296659968: "Max saves used. Delete a save."`, `68177629904896: "Save Profile {ID}"`, `68177634099200: "Playtime: {0}"`.
   Nytt spel kan hoppa över tutorialen (`Button_NewGameSkipTutorial`, `dump.cs:48820`).

3. **Sparande/avslut under körning** (`PauseMenuModal`, `dump.cs:32436`).
   `216014488408633344: "Save and Quit"`, `221060502103601152: "Save and Quit to Desktop"`, `142475212509667328: "Continue Playing"`, `408962925690880: "Exit to {GlobalKeywords.Village}"`, `408962925690881: "Exit to Menu"`, `408962925690882: "Resume"`.
   Bekräftelser: `Common` `779383328419840: "Abandon dungeon and escape to the {GlobalKeywords.Village}?"`, `779383328419841: "Return to Main Menu?"`.

### B. Crawler-val (karaktärsval)

4. **`GameStateManager.State.CharacterSelect = 2`** (`dump.cs:15587`).
   Skärmen heter `381325620641792: "{GlobalKeywords.Crawler} Selection"`.
   Spelaren väljer **en huvud-Crawler**: `382333843243008: "Select a main {GlobalKeywords.Crawler}"`, `55506202922135552: "Pick a {GlobalKeywords.Crawler}"`.
   Spelaren väljer **Arcana**: `55506202934718464: "Pick an {GlobalKeywords.Arcana}"`, sektionstitel `21088455160225792: "{GlobalKeywords.Arcana}"`.
   Färdig preset kan väljas: `380731644280832: "Dungeon Preset"`.
   Start: `55506202934718465: "Begin Expedition"` / `382150686375936: "Enter Dungeon"`.
   Antal platser: `46453830996537344: "{GlobalKeywords.Crawler} Slot"`, `21088455160225792` (Arcana); utökas i metan via `GlobalConfig.MetaUpgradeConfig` med fälten `characterSlot2Cost`, `characterSlot3Cost`, `arcanaSlot2Cost`, `arcanaSlot3Cost` (`dump.cs:93932`).
   Skärmens tillstånd sparas i `RunMetaSaveData`: `SelectedDungeonID`, `SelectedPartyFccIds`, `ActiveArcanasIds`, `EquippedArcanaIds`, `EnabledRelics`, `HurryModeActive`, `EndlessModeActive`, `IsJewellerDisabled` (`dump.cs:7015`).

### C. Byn (hubben) och världskartan

5. **Byn "Village" / Gorton.** `48349900800000: "In {GlobalKeywords.Village}"`.
   Bybeskrivning: `Dungeons` `11824022745088: "The village of Gorton, a sleepy, parochial place. …"`
   Byn är en karusell av byggnader: `TownViewController : CarouselSelectionViewController` med `List<CarouselSelectionView> _buildingPriorities`, `_infoPanelEnterButton`, `_partySummaryView`, `_playerStatsView`, coin-panel, `_worldMapExit`, `_leftGate`/`_rightGate` (`dump.cs:37441`). Varje byggnad är en `TownBuilding` med `EnterBuilding()` / `ExitBuilding()` (`dump.cs:21622`).
   Byggnader och deras texter (nyckel: text ur `Menus`):
   - `38844414491176960: "Inn"` — `38848921946107904: "The Gorton Bell Inn. Relax with a pint of milk and ask mighty {:color(Building):{GlobalKeywords.Crawlers}} to join your party."`
   - `38844414512148480: "Shop"` — `40213610215059456: "Purchase {:color(Building):{GlobalKeywords.PowerUps}} to boost your stats. …"`
   - `38844414512148481: "Fortune Teller"` — `40213610231836672: "Step right up for all things {:color(Building):{GlobalKeywords.Arcana}} related."`
   - `38844414512148482: "{GlobalKeywords.Museum}"` — `40213610231836673: "The {GlobalKeywords.Museum} of antiquities. …"`
   - `38844414512148483: "Town Hall"` — `40213610231836674: "Track your {:color(Building):{GlobalKeywords.Achievements}}."`
   - `38844414512148484: "Blacksmith"` — `40213610231836675: "In the {GlobalKeywords.Blacksmith} you can modify {:color(Building):{GlobalKeywords.Cards}} and {:color(Building):{GlobalKeywords.Gems}}."`
   - `65994653094195200: "Options"` (i en grav) — `65994653106778112: "A Graveyard seems the most appropriate place for a {:color(Building):{GlobalKeywords.Settings}} menu."`
   - Utgång: `40953451968139264: "World Map"`, `40953451930390528: "Venture forth with your party and {GlobalKeywords.Arcana}. Adventure awaits!"`
   Låsta byggnader visar egen text: `41046129290326016: "The Inn seems closed for now. …"`, `41049037184512001: "The shop is closed to unworthy adventurers. …"`, `41049037184512003: "The Town Hall is only accessible to adventurers who achievements are worth noting."`, `41049037184512004: "The Museum has nothing to display yet. …"`, `41049037184512002: "An empty pitching site. …"`, `41049037184512005: "There's {:color(red): nothing} to see here right now except flint and steel."`
   Upplåsning sker per byggnad via `TownBuildingConfig.UnlockType` (`dump.cs:96836`) — typerna är `DefaultUnlockType`, `ArcanaUnlockType`, `RelicUnlockType`, `ShopTierUnlockType`, `AchievementUnlockType` (`dump.cs:95235`–`95379`).

6. **Rekrytering av Crawlers i Inn.** `84063263239577600: "Recruit a {GlobalKeywords.Crawler} for {CoinCost:color(Building):N0} coins."` och `84072974911414272: "Not enough coins to recruit this {GlobalKeywords.Crawler}. …"` Betalar görs i `CharacterShop : ShopViewController<FccConfig>` (`dump.cs:22637`) med `_purchaseButton`, `_refundButton`, `_equipButton` (`dump.cs:21984`). `Rusty Key` (relik `17309176422281216`) beskrivs som `17309176439058432: "A rusty old key for the Gorton Bell Inn. …"` — nyckeln är alltså ett upplåsningsföremål för Inn, inte en dörr-mekanik.
   Inn har också ett disco-läge: `GlobalConfig.InnDiscoSettings` med `NumberRequiredCrawlersPurchased`, `TriggerOncePerRun`, `PercentageChanceOfTriggering`, `EnableCheaperRatesInDisco`, `DiscoDiscountPercentageRate` (`dump.cs:94366`).

7. **Butik (meta-uppgraderingar).** `PowerUpShop : ShopViewController<PowerUpConfig>` (`dump.cs:21679`), köp/återköp: `4717948386770947: "Buy"`, `4717948386770944: "Refund {GlobalKeywords.PowerUps}"`, `25393397689737216: "Equip"`, `21060025576316928: "Remove"`, `5875627767463936: "Max"`.
   Varje PowerUp har `initialPrice`, `availableLevels`, `baseLevel`, `powerUpIncreasePerLevel` och `targetedStat` ur `PowerUpConfig.PowerUpTargetedStat` = Might, Luck, Armor, MaxHealth, Recovery, MoveSpeed, Area, ProjectileSpeed, Duration, Amount, Cooldown, Growth, Greed, Curse, Magnet, Revival, ReRoll, Skip, Banish, Charm, CharacterSlots (`dump.cs:96902`).
   Effekttexter ur `PowerUps`: `2283735013732356: "{GlobalKeywords.Reroll} choices, {PowerUpValue:N0} per rank."`, `2283735013732358: "{GlobalKeywords.Skip} choices and get XP instead, {PowerUpValue:N0} per rank."`, `2283735013732354: "Remove {PowerUpValue:N0} {PowerUpValue:p:card|cards} from level up choices per rank."`, `43555440361025536: "Add an extra {GlobalKeywords.Crawler} slot per rank."`, `2541682885210112: "If you are about to die, you may {GlobalKeywords.Revive} once per rank."`, `2192685012168706: "Increase {GlobalKeywords.Handsize} by {PowerUpValue:N0} {PowerUpValue:p:card|cards} per rank."`
   Risk-spaken: `225046963139108864: "Risk"` + `225046963168468994: "Enemy Health is currently increased by {HealthValue:N0}% and Damage by {DamageValue:N0}%."` (`GlobalConfig.RiskConfig.RiskHealthMultiplier` / `RiskDamageMultiplier`, `dump.cs:94393`).

8. **Smedjan / Juveleraren** (kort- och gem-modifiering i byn). `BlacksmithShopController` (`dump.cs:22941`), underdelar `CardBlacksmith` (`dump.cs:23228`) och `GemJeweller` (`dump.cs:23463`).
   `147149190873559041: "{GlobalKeywords.Blacksmith}"`, `147149190873559042: "Add more Gem slots to cards you've discovered."`, `157038805037035520: "Pick a card and add a Gem slot."`, `155227398570192896: "Add Gem Slot?"`
   Juveleraren: `147149190848393216: "Jeweller"`, `147149190873559040: "See all available Gems and adjust their rarity."`, `147508368460820480: "Decrease Rarity"`, `147508368485986304: "Increase Rarity"`, `157508249928544256: "Seal"`, `147514945741860865: "Unseal"`, `147954813437554688: "Hide Sealed"`, `151878755706347520: "Sacrifice cards of the correct color to unlock."`
   Priser: `GlobalConfig.BlacksmithShopConfig` = `BaseSlotFee`, `SlotFeeMultiplier`, `BaseFrequencyChangeFee`, `FrequencyFeeMultiplier`, `JewellerPriceCap`, `BaseSealGemPrice` (`dump.cs:94330`). Gem-rariteter: `10441288646209536: "Normal"`, `10441288675569664: "Polished"`, `10441288675569665: "Rare"`, `10441288675569666: "Epic"`, `10441288675569667: "Legendary"`.

9. **Världskartan / Stage Selection.** `13055022896066560: "Stage Selection"`, `40953451968139264: "World Map"`.
   Panelklasser i namespace `Nosebleed.Pancake.LevelSelect`: `MapLocationInfoPanel` (`dump.cs:21167`, med `_upArrowButton`/`_downArrowButton`, `_stageInfoPanelPrefab`, `SubLevelLocationInfo`) och `StageInfoPanel` (`dump.cs:21444`, `_levelNameText`, `_levelDescriptionText`, `_levelThumbnailImage`, `_clearedUI`).
   Varje plats är en `LevelSelectConfig` med `_locationType`, `_locationThumbnail`, `_locationNameLoc`, `_locationDescLoc`, `_lockedLevelString`, `BaseDungeonLevel` och `List<DungeonConfig> LevelDungeons` (`dump.cs:95436`). Egenskaperna `IsVillage`, `IsDungeon`, `HasMultipleLevels`, `IsLevelUnlocked(config)`.
   Platser och underbanor ur `Dungeons`: `11824022745089: "Mad Forest"`, `11824022745091: "Inlaid Library"`, `11824022745093: "Dairy Plant"`, `11824022745095: "Gallo Tower"`, `11824022745097: "Cappella Magna"`, samt underbanor `5409240946401281: "Teeny Bridge"`, `5409240946401283: "Weeny Bridge"`, `5409240946401285: "Meany Bridge"`, `12266632501878784: "Furious Forest"`, `12266632527044609: "Berserk Wood"`, `40868002012160000: "Library West Wing"`, `40868002045714433: "Library Sanctum"`, `40868002045714435: "Milk Factory"`, `40868002045714437: "Curd Refinery"`, `40868002045714439: "Cappella Ultima"`, `195993120258600960: "Moongolow"`.
   Panelen visar vilka upplåsningar som finns i banan: `DungeonConfig` har `_relicsInLevel` ("Used for World Map to show Level Relics") och `_coffinsInLevel` ("Used for World Map to show Level Coffins/ Crawlers") (`dump.cs:89740`), och `SubLevelLocationInfo` har `List<RelicUnlockIcon> _relicIcons` och `List<CrawlerUnlockIcon> _crawlerIcons` (`dump.cs:21476`).
   Svårighetsgrad och läge: `116754034454507520: "Difficulty"`, `377799293108224: "Dungeon {ID}"`, `96537769042456576: "Cleared"`, `205456101243494400: "Endless"`, `205459670092881920: "Best: {furthestFloor}"`, `213505174802407424: "{dungeonName}: Endless"`.
   Reliker som ändrar själva kartskärmen: `633906212865: "Choose the music in the World Map."`, `633906212867: "Adds a Hurry button to the World Map."`, `157993411795693568: "Adds an Endless button to the World Map."`, `633906212889: "Shows an estimated completion time on level select."`, `633906212877: "Permanently allows access to a harder version of any stage."`.
   Startknapp: `157290391449624576: "Enter Region"` (`SubLevelLocationInfo._actionButton` + `_startString`).

### D. Nedstigning och körningens start

10. **Start av körningen.** `GameStateManager.State.Game = 3` (`dump.cs:15587`), eller `Tutorial = 4` (`58359185648115712: "In Tutorial"`).
    Första speltillståndet är `RunStartState : StateBehaviour<GameModel>` (`dump.cs:68578`) med fältet `_3dDungeonView` och `_isPlayingTutorialCutscene`; anropen `OnDungeonLoaded(TiledMapData)` och `ExecuteAfterInitialisation()`.
    Tutorialen är en egen dungeon: `TutorialConfig` (`dump.cs:95198`) = `_startingMana`, `_tutorialDungeon` (DungeonConfig), `_tutorialDeck` (DeckConfig), `List<CardList> _tutorialCardRewards` med `GetRewardCardsForLevel(int level)`.
    Körningen mäts: `GameModel.OnStartRun()`, `OnResumeRun()`, `TotalTimeInRun`, `_runSeed` (`dump.cs:83407`).

### E. Dungeonen: karta, rörelse, rum och händelser

11. **Våningsgenerering.** `Dungeon3DMapModel : MonoBehaviour, ISaveableComponent` (`dump.cs:78875`) med `Dungeon3DMapModel.State` = `Waiting`, `Generating`, `Loading`, `Ready` (`dump.cs:78603`).
    Kartan är **rutnätsbaserad och sparad som sträng**: `SaveData` har `DungeonMapString`, `PlayerCoords`, `PlayerRotation`, `IsMinimapDisabled`, `StepsTakenThisFloor` (`dump.cs:78614`). Modellen håller `TiledMapData _mapData`, `Vector2Int _playerMapCoords`, `Dictionary<Vector2Int, EventMarker> _eventMarkers`, `Dictionary<Vector2Int, GameObject> _destructibleEvents`, `int _stepsTakenThisFloor`.
    Generering via `LayeredDungeonGenerator _floorGenerator` och `CreateNewDungeon(DungeonConfig)` / `GenerateDungeonFloor(dungeonConfig, floorIndexToGenerate, visitedFloorCount)`.

12. **Rörelse i dungeonen (förstapersons-rutnät).** Tillståndet är `DungeonMovementState : StateBehaviour<GameModel>` (`dump.cs:67781`) med `_eventIndex` och `_3dDungeonView`.
    `GlobalConfig.DungeonMovementConfig` (`dump.cs:93951`) har `MovementStyleOption RotateAndMove`, `turnTime`, `moveTime`, `movementEasing`, `rotationEasing`, `instantMovementInputBuffer`, `shouldTurnToFaceExit`, `shouldOnlyPartEnterEncounters`, `distanceToWalkIntoTile`, `bumpDistance`.
    Kontrolltexter: `97161848904736768: "Move Forward"`, `97161848942485504: "Move Backwards"`, `97161848942485505: "Move Right"`, `97161848942485506: "Move Left"`, `96810551957512192: "Strafe"`, `76516400015441922: "Turn Right"`, `76516400015441923: "Turn Left"`, `76516400015441920: "Move with Rotation"`, `91366824885493760: "Instant Movement"`, `76516399977693184: "Interact"`, `76516400015441924: "Toggle Tooltips"`.
    Minikarta: `DungeonMinimapView` (`dump.cs:42806`), `MinimapConfig` (`dump.cs:94585`), inställningen `Rotate Map With Player` (`10952414029512704`). Reliker som påverkar den: `633881047040: "Milky Way Map"` / `633902018560: "Shows enemy positions and more on the mini map."`, `633906212872: "Yellow Sign"` / `633906212873: "Shows full map on Pause menu including enemies, secret areas, items etc."`, `633902018561: "Grim Grimoire"` / `633902018562: "Adds a list of discovered weapon evolutions and unions to the Pause menu."`, `32524480840544256: "Guiding Light"` / `32524480861515776: "Shows breakable light sources on the minimap."`, `58306081112186880: "Shows breakable light sources and {GlobalKeywords.Relics} on the minimap."`.

13. **Rumshändelser.** Varje ruta kan bära en `EventMarker`; när spelaren kliver in anropas `StartCurrentTileEvent()` → `StartCurrentTileEventTask()`, och `ShouldTileEventAutoStart(coords)` avgör om händelsen startar själv.
    Händelsekonfigurationer (`DungeonEventConfig`-subklasser, `dump.cs:89995`): `EnemyEncounterConfig` (`dump.cs:90439`), `GuardianEncounterConfig` (`dump.cs:90605`), `PassiveEventConfig` (`dump.cs:90704`), `DestructibleEventConfig` (`dump.cs:89927`), `EmptyEventConfig` (`dump.cs:90142`).
    Urval: `DungeonEvent` har `IsGuaranteed`, `Weight`, `Probability`, `IsFinalEventForFloor`, `IsAmbush` (`dump.cs:87926`). Rumstyper bekräftas av bundle-namnen: `roomtemplates-simple`, `roomtemplates-relics`, `roomtemplates-unique-shared`, `roomtamplates-unique_assets_rt_tutorial.bundle`, `…rt_enderboss.bundle`, `…rt_gemchest.bundle`, `…rt_mf_3x3_ambushintoboss.bundle`, `…rt_wingbalcony.bundle`, `…rt_credits.bundle`.
    **Rumstyper som belagts:**
    - **Strid:** `EnemyEncounterView` / `EnemyEncounterModel` (`dump.cs:44265`, `82286`). Konfig: `EnemyEncounterConfig` med `EncounterName`, `_shouldEnemiesGoFirst`, `_completeDungeonOnDeath` ("Should the dungeon count as completed if the player dies in this encounter? (Red Death)"), `_blocksOverkill`, `_allowsDynamicBossSpawning`, `EnemyConfig[,] _enemies` (rutnät) (`dump.cs:90439`). Bakhåll: `98708192530214912: "Ambush"` och `DungeonEnemyAmbushMarker`.
    - **Kista/coffin (vaktare):** `GuardianEncounterConfig` (`dump.cs:90605`) med `guardian`, `unlockedAchievement`, `doEnemiesGoFirst`, `completeDungeonOnDeath`, `rotateToFillSpace`, `totalGuardians`, `activeCount` ("Number of enemies that the player can attack and can perform an action at a time"), `endTurnRotationStep`, `playCardRotationStep`, `guardianCircleRadius`. Vyer: `GuardianEncounterView` (`dump.cs:47515`), `CharacterCoffinView` (`dump.cs:47645`), `TreasureCoffinView` (`dump.cs:47870`). Texten vid avklarad coffin: `10947185868877825: "JOINS THE CRAWLERS!"`; om figuren redan tagits används `_treasureEventDetailsReference` ("The event details used if the character in the coffin has already been collected").
    - **Passiva händelser** (`PassiveEventView`-subklasser, `dump.cs:35436`): `CrystalPickupView` (1197), `ManaPickupView` (1225), `FloorChickenView` (1216), `GemChestEventView` (1220), `SilverGemChestEventView` (1232), `DialogueEventView` (1206, `IRelicReward`), `OfferingTableEventView` (1227), `EvoTableEventView` (1213), `GunForHireEventView` (1223), `DarkanaChoiceEventView` (1201), `EnemyCardThrowingEventView` (1211).
    - **Offerbord** (`OfferingTableModal`, `dump.cs:32143`): undertyper `StatOfferingTableModal` → `CardStatOfferingTableModal` / `RandomStatOfferingTableModal`, `ChickenOfferingTableModal`, `ManaOfferingTableModal`, `DuplicateOfferingTableModal`, `SilverGemChestModal`.
      Texter: `96461261324034048: "Spend a card to get a permanent stat boost."`, `96461261353394176: "Spend a card to restore HP."`, `96461261353394178: "Spend a card to gain {GlobalKeywords.Mana}."`, `96461261353394177: "Choose a card to duplicate."`, `96461261353394179: "Choose a card to upgrade."`, `96461261353394180: "Choose an Evolution."`, samt `190734195120615434: "Sacrifice a card to get a permanent stat boost."`, `190734195120615435: "Sacrifice a card to restore HP."`, `190734195120615436: "Sacrifice a card to gain {GlobalKeywords.Mana}."`, `195455775763542016: "Sacrifice a card."` och `178076416950087681: "Choose a card to sacrifice."`
      Klassen har `_cardsRequired` och `_destroySelectedPileCards` (`dump.cs:32143`). Val av kort: `_scrollableCardSelector` (`ScrollableCardSelectionView`).
    - **Evolutioner/Unioner:** `EvoTableEventView` + `EvoTableModal` (`dump.cs:30396`), `_grimoireViewButton` / `WeaponEvolutionsView` i `ChooseCardModal`; `66377352040493056: "Weapon Evolutions & Unions"`, `401978759413760: "Evolve"`, `401978759413761: "{Amount} Left"`.
    - **NPC-dialog:** `JRPGDialogueModal` (`dump.cs:31377`) och `DialogueEventView`. Exempel i Moongolow: `Dialogue` `31543236964352: "Greetings Crawler, you are the first person to visit in a very long time!"`, `31543270518784: "The Moongolow shop is not open yet, but I gift unto you this Relic as a reward for finding me."`, `31543270518786: "A toot from this special Trumpet will let you loop Endlessly through dungeons... …"` — alltså en NPC som ger Endless-verktyget.
    - **Gem-kista:** `GemChestManager` (`dump.cs:77859`), `ChestTiers`, `GemChestMarker`, `DestructibleGemChest`; reliken som lägger till dem: `633906212869: "Adds {GlobalKeywords.Arcana} events to dungeons."` och `139155747105660928: "Adds {GlobalKeywords.Arcana} chests to dungeons."`.
    - **Mörk Arcana:** `DarkanaChoiceEventView` + reliken `18050765511798784: "Adds Darkana events to dungeons."`
    - **Handlare:** reliken `633906212871: "Adds Merchants to dungeons."`; `GunForHireEventView` / `GunForHireModal` (`dump.cs:30645`).

14. **Level up och kortval — runnens belöningsloop.**
    XP samlas som **kristaller** på golvet: `GlobalConfig.XpCrystalConfig` med `collectCrystalsOnLevelUp`, `collectionRadius`, `maxCrystalsSpawnedPerEnemy`, `Dictionary<CrystalColor, CrystalTierInfo> CrystalTierDefinitions` (`dump.cs:93882`); `CrystalPickupView`, `CrystalEmitterModel`, `ExperienceEffect : CardEffect` (`dump.cs:61014`), `CrystalXpBarMarker` (`dump.cs:65514`).
    XP-baren är `PlayerXpBarView` (`dump.cs:51478`) med `_playerXp`, `_maxXp`, `_playerLevel`, `_chooseCardPrefab` och metoderna `DoViewLevelUp()`, `TryOpenChooseCardModal()`, `ContinueXpFillAfterLevelUp()`. **Baren öppnar alltså reward-modalen vid level up.**
    Modalen är `ChooseCardModal : Modal` (`dump.cs:28195`);
    titel/undertext: `392421828034560: "Level Up!"`, `392421828034561: "Choose a reward"`;
    `402859882020864: "Increase your {GlobalKeywords.Luck} for a chance to get 4 choices"` (fältet `_increaseLuckLabel`).
    Spelarens val: ett `CardChoiceView` (kort) eller ett `GemSelectionView` (gem) — `ChooseCardModal.RewardChoiceInfo` har `GemChoice`, `CardChoice`, `IsCard` (`dump.cs:28005`).
    Knappar och resurser som serialiserade fält: `_skipButton`, `_rerollButton`, `_banishButton`, `_cancelBanishButton`, `_remainingSkipsLabel`, `_remainingRerollsLabel`, `_remainingBanishesLabel`.
    Metoderna `PopulateCardRewardChoices(bool isReroll)`, `PopulateRewards(playerModel, rewardCount, cardRewardPool, gemRewardPool, chosenRewards, isReroll)`, `RollForLevelUpChance`, `GetLevelUpChance`, `OnlyOfferCards`, `RemoveCurrentCardChoicesFromPool`, `RemoveCurrentLevelUpChoicesFromPool`, `RemoveBanishedCardsFromPool`, `FilterOutPreviousEvoChoices`.
    Vikter och gates ligger i `GlobalConfig.CardLevelConfig` (`dump.cs:93742`): `minLevelForLevelUps`, `cardOnlyFloorAchievements` ("Putting and achievement for MF1 F1 here will prevent card level ups from being offered until the player has completed the floor at least once"), `levelUpChoiceLuckFactor` ("Luck increases the chance receiving a card level up choice"), `normalCardChance`, `normalLevelUpChance`, `singleTypeCardChance`, `singleTypeLevelUpChance`, `weaponsOnlyUntilLevel`, `newCardsOnlyUntilLevel`, `cardsInDeckMultiplier`, `List<CardConfig> bonusCards` ("Cards to give as rewards if we run out of other cards to give (gold etc)"), `BaseGemChance` ("The chance of seeing a gem choice at base 100 luck"), `LuckScaleFactor`, `GemLuckCap`.
    Kortpoolen är nivåstyrd: `CardRewardConfig.LevelRange` har `Vector2Int levelRange`, `List<AllowedCardCost> allowedCardCosts` (cost + weight), `_cards`, `_cardGroups` (`dump.cs:89275`). XP-kurvan: `PlayerLevelConfig` med `_xpCurveExponent`, `_xpCurveMultiplier`, `_baseXpReq`, `_levelRanges`, `GetLevelUpXp(level)` (`dump.cs:94895`).
    Övriga belöningsval i samma familj: `ReceiveRelicModal` (`dump.cs:32666`, `56142799869829120: "{GlobalKeywords.Relic} Found!"`, `56142799869829121: "New!"`), `ChooseArcanaModal` (`dump.cs:27883`), `NewCharacterModal` (`dump.cs:31936`), `InsertGemModal` (`dump.cs:31070`, `140240664066600960: "Insert Gem into a Card"`), `ChooseGemModal` (`dump.cs:28636`).

15. **Belöningsmodalen är återanvändbar och kan också ge gems.** `ChooseGemModal` har exakt samma fyra spelarval: `_rerollButton`, `_skipButton`, `_banishButton`, `_leaveButton`, plus `CashOutButtonView` (`151894741905973248: "Cash Out"`) och `_baseChoiceCount`. Texter: `151894741905973248: "Cash Out"`, `195455775792902144: "No available Gem slots.\n\nCome back when you have more cards,\nor choose Cash Out to take coins instead."`, `195461860050284544: "Come back when you have cards with gem slots, or cash out to take coins instead."`, `141774471022325760: "No available Gem slots.\\nCome back when you have more cards."`
    Sekvensen styrs av `GemInsertionSequence` (`dump.cs:64385`): `OnGemEventFound(guaranteeEvoGems, choiceCount, gemFrequencies, canCashOut, allowFallbacks, ensureNonEvoGem)` → `TryOpenChooseGemModal()` → `TryOpenInsertGemModal(gemConfig, evoCardConfig)`.
    Om valen inte hänger ihop: `187718176982642704: "Incomplete combination, choose a reward."` och `178076416950087680: "No compatible card combinations."`, `178076416903950336: "Choose an item to Banish from the run."`

### F. Striden

16. **Stridssekvensen** (tillstånden i `Nosebleed.Pancake.GameLogic.GameStates`, registrerade som serialiserade fält i `GameStateMachine` `dump.cs:65866`):
    `EncounterStartState` (`dump.cs:67951`) → `PrePlayerTurnState` (`dump.cs:68543`) → `PlayerTurnState` (`dump.cs:68434`) → `PlayerEndTurnState` (`dump.cs:68418`) → `PostPlayerEndTurnState` (`dump.cs:68527`) → `EnemyTurnState` (`dump.cs:68033`) → tillbaka till spellarens tur. Utgångar: `EncounterDefeatedState` (`dump.cs:67848`, sätter `_isInCombat`), `EncounterResetState` (`dump.cs:67889`), `PlayerDiedState` (`dump.cs:68342`, `ShowGameOver`), `GameOverState` (`dump.cs:68277`, `ExecuteGameOver`).
    `EncounterStartState` fördröjs via `DelayExecute(CancellationToken)`; `EnemyTurnState` har `ExecuteStateTask(context)` + `WaitForTurnEnd()`.
    `PrePlayerTurnState` har `TickState(context, dt)` — alltså en tillståndsticking, inte en händelse.
    Övervakare: `EnemyInterruptModel` (`dump.cs:66102`) med `InterruptDetails { CountdownMax, CountdownCurrent }`, `RegisterEnemyWithInterrupt(enemy, intentGroup)`, `DecrementInterruptCountdowns`, `OnCardPlayed(card)`, och events `CountdownUpdated`, `InterruptStarted`, `InterruptEnded`, `CountdownReachedZero`.
    Fiendeavsikter: `EncounterIntentView` (`dump.cs:43354`), `EnemyIntentGroup` / `EnemyIntent` (`dump.cs:91292`, `91342`), `GlobalConfig.EnemyIntentConfig` (`dump.cs:93844`). Rader: `EncounterRowsView` (`dump.cs:43445`), `EncounterInfoView` (`dump.cs:43185`), `EnemyBossView` (`dump.cs:43574`).
    Inställningar: `98710875244802048: "Show boss health"`, `98710875274162176: "Show enemy health"`, `93900612181241856: "Combo Multiplier"`.

17. **Spelarens tur.** `PlayerModel` (`dump.cs:85112`) håller `DrawPileModel _drawPile`, `HandPileModel _handPile`, `ThrowingPileModel _throwingPileModel`, `DiscardPileModel _discardPile`, `DestroyPileModel _destroyPile`, `FccPileModel _fccPile`, `ComboPileModel _comboPile`, `CardHistoryModel _turnHistory`, `_encounterHistory`, `IntVariable CardCombo`, `TotalTurnCount`, `CurrentCard`/`PreviousCard`/`PreviousComboCard`, `PreviousCardCost`, `PreviousComboCardCost`, `_playerLevelAtStartEncounter`, `_encounterTurnCount`, `_hasPlayedCardThisTurn`, `_isInEncounter`, `_banishedCardGroups`, `_banishedGems`.
    Metoder: `OnStartTurn(bool wasSaveDataLoaded)`, `Button_EndTurn()`, `Button_AutoPlay()`, `OnEndTurn()`, `PostPlayerEndTurn()`, `DiscardHand(bool retainCards)`, `DiscardComboPile()`, `TryAddDiscardPileToDeck()`, `AddCardConfigToHand(cardConfig, isTemporary)`, `InsertCardIntoDeckAtRandomIndex(...)`, `OnUseArcana(arcanaConfig)`.
    Events: `TurnStarted`, `TurnEnded`, `CardPlayed`, `HandEmptied`, `PlayerDied`, `PlayerRevived`, `EncounterStarted`, `EncounterEnded`, `RiskChanged`, `AllCardEffectsReset`.
    Kontrolltexter: `387709435215872: "Play All"`, `387709439410176: "End Turn"`, `13133158429417472: "Auto End Turn"`, `96779665052524544: "End Turn"`, `96781231948029952: "Turn"`, `215318707187998720: "Play Card"`, `119614224296128512: "Discard"`, `94566361659858944: "Show {GlobalKeywords.DeckPile}"`, `94566361693413376: "Show {GlobalKeywords.DiscardPile}"`, `96763288208007168: "Re-arrange Cards"`, `190734195082866688: "Sort Hand"`, `190734195120615425: "Mana"`, `190734195120615426: "Color"`, `190734195120615431: "Type"`, `96765936441221120: "Next Page ({db.relic.RelicConfig_DeckBox.Name})"`.
    Combo-regler i ord: `158106791638413313: "Wild cards can be used to connect combos together to make bigger Combos."`, `158106791638413314: "Connect and continue Combos."`, `633906212883: "Play cards in ascending {0} {:color(Mana):{GlobalKeywords.Mana} cost} order for a Combo Multiplier."`, `91224384860053508: "Repeated cards this turn are Free."`, `91224384860053509: "Combos don't clear between turns."`.
    Kortlådor: `DeckBoxController` / `DeckBoxPile` / `DeckBoxModal` (`dump.cs:68614`, `68673`, `30032`), relik `633906212885: "A simple box to hold a deck of cards. …"`, `101974478517383168: "Unlocks {GlobalKeywords.DeckPile} and {GlobalKeywords.DiscardPile}."`.
    Objektspelaren kan trycka på: `_autoPlayButton`, `_endTurnButton` (`dump.cs:85112`), samt reliken `633906212896: "Slate of Indecision"` / `633906212897: "Unlocks the autoplay button."` och `633906212892: "Rage Virus"` / `633906212893: "Large Damage buff and autoplay all cards."`.
    Crawlers i striden: reliken `85855072138899456: "{GlobalKeywords.Crawlers} Tutorial"` + `85855072164065280: "Crawlers help you in combat when you play their corresponding colored cards."`; `Crawler`-kort finns som kort i `Cards` (t.ex. `640583595556868: "Antonio"`, `640583595556869: "Arca"`, `640583595556870: "Cavallo"`).

18. **Seger i en strid.** `EncounterDefeatedState` sätter `_isInCombat = false` och kör `ExecuteTask(gameModel, CancellationToken)`; `EnemyInterruptModel.OnEncounterDefeated()`, `PlayerBirdManager.OnEncounterDefeated()`, `GemChestManager`, `TreasureChestManager` reagerar också på det.
    Vinstbelöningar ligger inte i en egen state — de kommer från loot i rummet (kristaller, mynt via `CoinEffect`/`MetricCoinEffect`, `DestructibleCoins`) och från XP som fyller baren → `ChooseCardModal`.

### G. Nedstigning, boss och slut på körningen

19. **Våningens slut och nedstigning.** `Dungeon3DMapModel.AnyEncountersRemaining()`, `GetRemainingEventsForFloor()`, `ShouldUnlockEvosAfterCompletingFloor()`, `MarkCurrentEventMarkerAsComplete()`, `ClearDungeonFloor()`.
    En **spade** gräver upp utgången: fältet `TrySpawnShovel()` / `IsShovelAlreadySpawned()` / `TryGetActiveShovel(out DestructibleShovel)` / `ShouldWaitForExitShovelSpawn()` / `CheckExitShovel(mapData)`, klassen `DestructibleShovel` (`dump.cs:76698`), konfig `GlobalConfig.DescendShovelConfig`. Texten: `15591101787074560: "Descend"`.
    Våningsovergången är `FloorTransitionState : StateBehaviour<GameModel>` (`dump.cs:68216`) med `Dungeon3DMapModel _3DmapModel` och `OnDungeonGenerated(TiledMapData)`.
    **Bomba Infernale (nuke):** `Dungeon3DMapModel.NukeDungeonEncounters()`, `IsNuking`, `TriggeredBombaInfernale`, `ResetBombaInfernale()`, `ClearDungeonEncountersExceptBosses()`; texten `96763288245755904: "Hell Bomb"` och reliken `633906212887: "Instantly vaporise all enemies on the first floor of a dungeon you have previously cleared."`.
    Chefen kan läggas till dynamiskt: `_allowsDynamicBossSpawning` (i båda encounter-konfigarna) och rumsmallen `rt_mf_3x3_ambushintoboss.bundle`.

20. **Boss / Ender / Red Death.** Klasserna `EnderBossSequence` (`dump.cs:2013`), `EnderEnemyInitializer` (`43603`), `EnderHandsView` (`43790`), `EnderBossSky` (`77635`), `RedDeathAnimationView` (`43979`), rumssmallen `roomtamplates-unique_assets_rt_enderboss.bundle`.
    Att en strid kan avsluta dungeonen även vid dödsfall ligger i `EnemyEncounterConfig._completeDungeonOnDeath` med kommentaren "Should the dungeon count as completed if the player dies in this encounter? (Red Death)" (`dump.cs:90449`) — samma fält finns på `GuardianEncounterConfig`.
    Segertexten: `157851068723572738: "With the Red Death vanquished, there is nothing else to prove here."`

21. **Dungeon Complete.** `DungeonCompleteState : State<GameModel>` (`dump.cs:67759`) med `ShowDungeonComplete(GameModel context)`.
    Texter: `5810703343124480: "Dungeon Complete"`, `5810703343124481: "Bonus coins: {Amount}"` (`DungeonConfig.BonusCoins`), `157851068685824000: "Complete Dungeon"`, `157851068723572740: "Complete dungeon and return to the {GlobalKeywords.Village}?"`.
    `GameModel.OnDungeonComplete()` och `UpdateGlobalMetricsAtEndOfRun()`.

22. **Resultatskärmen.** `ResultsSummaryModal : Modal` (`dump.cs:33644`) med fälten `_runTimeTextValue`, `_floorsClearedValue`, `_goldEarnedTextValue`, `_levelReachedTextValue`, `_enemiesDefeatedTextValue`, `_overkillDamageTextValue`, `_overkillMaxDamageTextValue`, `_maxComboTextValue`, `_healthHealedValue`, `_freeCardsPlayedValue`, `_crawlersTriggeredValue`, `_weaponsSummaryArea`, `_evolutionSummaryArea`, `_playerSummaryArea`, `_bonusCoins`, `_newBestLabelContainer`, `_achievementSummaryModal`, `_endOfDemoModal`; egenskapen `WasDungeonCompleted`.
    Texterna: `10586001420398600: "Results"`, `10586001399427072: "Survived"`, `10586001420398592: "Coins Earned"`, `10586001420398593: "Level Reached"`, `10586001420398594: "Enemies Defeated"`, `10586001420398595: "Weapon"`, `10586001420398596: "LVL"`, `10586001420398597: "{GlobalKeywords.Damage}"`, `10586001420398598: "Time"`, `10586001420398599: "AVG."`, `10586001420398601: "{db.relic.RelicConfig_Overkill.Name} Damage"`, `10586001420398602: "Max {db.relic.RelicConfig_Overkill.Name} Damage"`, `10586001420398603: "Max Combo"`, `174789803139739648: "Floors Cleared"`, `216014488408633345: "New Best"`.
    Ackompanjerande modaler: `AchievementSummaryModal` (`dump.cs:33548`), `AchievementsSummaryScreen` (`dump.cs:97965`), `EndOfDemoModal` (`dump.cs:30211`).

23. **Död och game over.** `PlayerDiedState.ShowGameOver(context)` → `GameOverState.ExecuteGameOver()`; `GameModel.OnPlayerDied()` / `OnGameOver()`.
    Val: `157851068723572736: "Succumb to Death"` och `157851068723572737: "Victorious Retreat"` med texterna `157851068723572739: "Give in to the inevitable and return to the {GlobalKeywords.Village}?"` och `157851068723572741: "Death comes for us all eventually."`
    Manuell avbrytning finns som flagga: `GameModel.TriggerManualAbort(bool isDungeonCompleted)`, `ManualAbortRun`, `OnManualAbortEvent`, `_triggeredManualAbort`.

24. **Epilog (om belagd skärm finns).** `GameModel` har `IsEpilogueTriggered`, `IsEpilogueFinished`, `EpilogueStarted()`, `EpilogueCompleted()`, `OnEpilogueFinishedEvent` (`dump.cs:83407`).
    Demoslut: `173373384597385216: "Congratulations, you have completed the Demo! …"`, `173373384643522560: "Your progress up to this point will transfer into the full game. …"`, `137011709770412032: "End of the line...for now!"`, `137011709799772160: "Thank you, bye bye!"`

### H. Tillbaka i byn: meta-loopen

25. **Mynt ackumuleras till metan.** `ProgressionSaveData` har `public long TotalCoins;` (`dump.cs:6985`) tillsammans med `IsTutorialComplete`, `IsWildCardTutorialComplete`, `ChestsSpawned`, `CharactersPurchased`, `PowerUpLevelsUnlocked`, `PowerUpEnabled`, `AchievementsUnlocked`, `DiscoveredCards`, `BuildingsVisited`, `DungeonsVisited`, `CardGemSlots`, `GemFrequencies`, `SealedGems`, `PreviouslySealedGems`, `UnlockedGemRarities`, `UnlocksHideCompleted`.
    I körningen hålls mynt i `PlayerModel._currentCoinCount` (`IntAsset`), med `MAX_COINS = 2147000000` (`dump.cs:85112`) och metoderna `AddCoins(coins, useGreed)`, `SubtractCoins(coins)`, `CashOutCoins(coins, useGreed)`, `GetGreedCoins(...)`.
    Sparfiler delas upp i `SaveLoadManager` i profil-, progression-, game-, settings- och **runMeta**-laddare (`dump.cs:8482`). Byn har `PlayerCoinStatView` (`dump.cs:50630`) och `TownViewController.ShakeCoinUI()`.

26. **Upplåsningar och achievements.** `AchievementManager` (`dump.cs:97437`), `ProgressionData` (`dump.cs:24643`) och `ProgressionSaveLoadManager` (`dump.cs:8146`).
    Texter: `20011298121134080: "Unlocked: {AchievementsUnlocked:N0} of {TotalAchievements:N0}"`, `20022452721627136: "Unlocks"`, `114178403937017876: "New Unlocks"`, `23258883510317056: "Unlock: ???"`, `93884449107816448: "Obtained"`, `93884449124593664: "Locked"`, `58002534140293120: "Hide Completed"`, `58004461800468480: "Active"`.
    Upplåsningstyper: `AchievementUnlockType` (kräver `_achievementForUnlock`), `ArcanaUnlockType`, `DefaultUnlockType`, `RelicUnlockType`, `ShopTierUnlockType` (`dump.cs:95235`–`95379`).
    Achievements exempel: `163522942057000960: "Is This The Ender?"` / `163522942094749696: "Complete the final level."`, `163522942094749697: "Crawl The Way To The End"` / `163522942094749698: "Find and kill the Vampire, there must be one somewhere."`, `163522942098944000: "Explore the world and uncover its mysteries."`

27. **Nästa körning.** Byn/kartan startar om samma cykel; `RunMetaSaveData` bevarar vald dungeon, party, arcanas, reliker och lägen. `GameModel.ResetRun()` nollställer körningen.
    Reliker är de permanenta reglage som ändrar nästa körning: `633906212874: "Great Gospel"` / `633906212875: "Permanently allows to level up weapons beyond their limit. Enabled during Endless mode."`, `633906212892: "Rage Virus"` / `633906212893: "Large Damage buff and autoplay all cards."`, `633906212894: "Possessed Sneakers"` / `633906212895: "Auto navigate through the dungeon towards a boss."`.
    Endless-läget: `205456101243494400: "Endless"`, `EndlessModeStatConfig` (`dump.cs:90991`), `BestEndlessForDungeonView` (`dump.cs:37803`), `DungeonConfig.MaxEndlessModeFloorsMetricKey`.

---

## 2. Skärmar och paneler

| Skärm / panel | Klass (dump.cs) | Innehåll (belagt) |
|---|---|---|
| Förvarning + startskärm | `MenuScreenView` (48782) | Photosensitivity-varning, "PRESS TO START" |
| Huvudmeny | `MenuScreenView` (48782) | New Game, New Game (skip tutorial), Continue, Load Game, Delete All Save Data, Wishlist, Options, Credits, Quit |
| Sparfilsval | `SaveSelectModal` (32846), `SaveSlotView` (48632), `SaveSlotOptionsModal` (32944) | Sparprofiler, playtime, datum, max antal sparade |
| Inställningar | `GameOptionsModal` (27348), `GameOptions` (27222), `OptionsPanelView` (36190) + underpaneler | Gameplay, Accessibility, Sound and Music, Display, Input, Controller, KBM, Deadzones |
| Crawlerval | `GameStateManager.State.CharacterSelect` (15587) | Val av huvud-Crawler + Arcana + preset + platser |
| By-vy (hubben) | `TownViewController` (37441), `TownBuilding` (21622), `BuildingInfoView` (37194) | Karusell av byggnader, myntpanel, spelarstatistik, partysammanfattning, gated utgång till världskartan |
| Shop (PowerUps) | `PowerUpShop` (21679), `PowerUpItemView` (22460) | Köp/återköp/equipa permanent stat-uppgradering per rank |
| Inn (rekrytering) | `CharacterShop` (22637), `CrawlerItemView` (22530), `FccPortraits` | Rekrytera Crawlers för mynt, disco-rabatt |
| Fortune Teller | `ArcanaShop` (23867), `ArcanaSlots` (23947), `ArcanaSlotView` (23985) | Arcana-köp och arcana-platser |
| Museum | `RelicShop` (2567), `RelicShopItemView` (2632) | Samling av hittade reliker |
| Town Hall | `AchievementsSummaryScreen` (97965), `AchievementItemView` (97912) | Achievements / "Unlocks" |
| Blacksmith | `BlacksmithShopController` (22941), `CardBlacksmith` (23228), `GemJeweller` (23463), `JewellerGemView` (23755) | Lägg till gemslots, ändra gem-raritet, seala gems |
| Graveyard (Options) | `TownViewController._optionsBuildingSelectionView` + `GraveyardGameOptions` (37441) | Inställningar i spel |
| Världskarta / Stage Selection | `MapLocationInfoPanel` (21167), `StageInfoPanel` (21444), `SubLevelLocationInfo` (21528) | Platser, underbanor, svårighet, relik-/crawler-ikoner, Cleared, Endless, Hurry, Enter Region |
| Laddningsskärm | `LoadingScreenManager` (16209), `ScreenTransitionManager` (14188) | Övergångar |
| Dungeon-vy (förstaperson) | `Dungeon3DMapView` (42510), `Dungeon3DMapModel` (78875) | Rutnätsrörelse, event-markörer, fiende-markörer, ambush-markörer |
| Minikarta | `DungeonMinimapView` (42806), `MinimapConfig` (94585) | Roterbar karta, fiender, reliker, ljuskällor (relikstyrda lager) |
| Stridsvy | `EnemyEncounterView` (44265), `EncounterInfoView` (43185), `EncounterIntentView` (43354), `EncounterRowsView` (43445) | Rader, fiendeavsikter, boss-/fiendehälsa |
| Vaktarring | `GuardianEncounterView` (47515), `CharacterCoffinView` (47645), `TreasureCoffinView` (47870) | Roterande vaktare runt en coffin |
| Spelarhand och högar | `PlayerXpBarView` (51478), `PlayerView`, `DrawPileView` (39590), `DiscardPileView` (39399), `ComboPileView` (39103), `DeckBoxModal` (30032) | XP-bar (öppnar reward-modalen), hand, Däck/Discard/Combo-högar |
| Level-up-modalen | `ChooseCardModal` (28195), `CardChoiceView` (38268), `CardLevelUpView` (38577), `EvoLevelUpView` (45880) | "Level Up!" / "Choose a reward", kort- eller gemval, Reroll, Skip, Banish, Grim Grimoire |
| Gem-modalen | `ChooseGemModal` (28636), `GemSelectionView` (53391), `InsertGemModal` (31070), `GemInsertionSequence` (64385) | Gemval, Cash Out, Leave, sedan in i ett kort |
| Offerbord | `OfferingTableModal` (32143), `CardStatOfferingTableModal` (27710), `ChickenOfferingTableModal` (27801), `ManaOfferingTableModal` (31522), `DuplicateOfferingTableModal` (30112), `RandomStatOfferingTableModal` (32620), `SilverGemChestModal` (33101) | Offra kort mot statistik, HP, mana, duplikat, uppgradering |
| Evolutionsbord | `EvoTableModal` (30396), `EvoTableEventView` (50040) | Välj en evolution |
| Relikval | `ReceiveRelicModal` (32666) | "{Relic} Found!" / "New!" / GET |
| Arcana-val | `ChooseArcanaModal` (27883) | Välj en Arcana |
| Ny karaktär | `NewCharacterModal` (31936) | "JOINS THE CRAWLERS!" |
| NPC-dialog | `JRPGDialogueModal` (31377), `DialogueEventView` (49735) | Dialogrutor, ibland relik som belöning |
| Pausmeny | `PauseMenuModal` (32436) | Resume, Save and Quit, Exit to Village, Exit to Menu, Save and Quit to Desktop |
| Resultat | `ResultsSummaryModal` (33644), `AchievementSummaryModal` (33548), `EndOfDemoModal` (30211) | Tid, våningar, mynt, level, fiender, max combo, vapensammanfattning, bonusmynt, achievements, New Best |
| Bekräftelser | `OkPromptModal` (32300), `YesNoModal` (33407), `UIMessageBoxPanel` (27042) | Ja/nej, sparfel |

---

## 3. Skillnader mot en klassisk deckbuilder

1. **Ingen nodkarta — förstaperson i ett rutnät.** Klassiska deckbuilders (Slay the Spire) har en graf av noder man klickar sig igenom. VC har i stället `Dungeon3DMapModel` med `TiledMapData`, `Vector2Int _playerMapCoords` och `GlobalConfig.DungeonMovementConfig.MovementStyleOption RotateAndMove` (`dump.cs:93951`) — spelaren **går och roterar** steg för steg, och rum/händelser hittas som markörer på rutor (`Dictionary<Vector2Int, EventMarker> _eventMarkers`).
2. **Rummen väljs inte, de påträffas.** Händelser ligger på rutor och startar när man kliver in (`ShouldTileEventAutoStart`, `StartCurrentTileEvent`) eller genom att interagera. Inget "välj väg"-val mellan rum.
3. **Inga nycklar och nyckelhål.** Ingen Key/Lock-klass finns i dumpen. Utgången till nästa våning kommer i stället från en **spade** (`DestructibleShovel`, `TrySpawnShovel`, `ShouldWaitForExitShovelSpawn`) och reliken `Bomba Infernale` kan utplåna alla fiender på en redan klar våning.

   (Sökning efter Key/Door/Lock/Portal gav inga träffar utöver input- och tangentbordsklasser samt *Rusty Key*, som är en upplåsningsrelik för Inn.)
4. **Nivåvalet sker mitt i en körning, från en XP-bar.** XP är fysiska kristaller på golvet (`XpCrystalConfig`, `CrystalPickupView`, `ExperienceEffect`) och `PlayerXpBarView.TryOpenChooseCardModal()` öppnar `ChooseCardModal` när baren fylls — det är inte en "vila vid bål"-skärm mellan strider som i många deckbuilders.
5. **Reroll, Skip och Banish finns — på riktigt, som resurser.** `_rerollButton`, `_skipButton`, `_banishButton` med `_remainingRerollsLabel`, `_remainingSkipsLabel`, `_remainingBanishesLabel` i både `ChooseCardModal` och `ChooseGemModal`. De köps permanent i byn: `2283735013732356: "{GlobalKeywords.Reroll} choices, {PowerUpValue:N0} per rank."` och `2283735013732358: "{GlobalKeywords.Skip} choices and get XP instead, {PowerUpValue:N0} per rank."`
6. **Valen kan vara kort ELLER gems, inte bara kort.** `ChooseCardModal.RewardChoiceInfo { GemConfig GemChoice; CardConfig CardChoice; bool IsCard; }` (`dump.cs:28005`). Luck styr om ett gem-val dyker upp (`BaseGemChance`, `GemChoiceModalConfig`), och `ChooseGemModal` har dessutom **Cash Out** för mynt i stället för gem.
7. **Luck är en riktig spak med flera effekter.** `402859882020864: "Increase your {GlobalKeywords.Luck} for a chance to get 4 choices"` och `levelUpChoiceLuckFactor` ("Luck increases the chance receiving a card level up choice", `dump.cs:93752`).
8. **Kortvalet är viktat och nivå-gatat, inte en jämn dragning.** `CardLevelConfig` har separata sannolikheter för "nytt kort" vs "level up av ett kort du redan har" (`normalCardChance`, `normalLevelUpChance`, `singleTypeCardChance`, `singleTypeLevelUpChance`), plus `cardsInDeckMultiplier`, `weaponsOnlyUntilLevel`, `newCardsOnlyUntilLevel` och en achievement-grind per våning (`cardOnlyFloorAchievements`).
9. **En butik finns — men i byn, inte i dungeonen.** Effektiva köp sker i Village (PowerUps, Crawlers, Arcana) med den **permanenta** valutan `ProgressionSaveData.TotalCoins`. Inne i dungeonen tillkommer handlare först via reliken `633906212871: "Adds Merchants to dungeons."` och `GunForHireEventView`.
10. **Sällskapet (Crawlers) är kort i leken.** `Crawlers help you in combat when you play their corresponding colored cards.` Antal platser köps i metan (`characterSlot2Cost`/`characterSlot3Cost`), Crawlers hittas också i coffins i dungeonen (`CharacterCoffinView`, `GuardianEncounterConfig`).
11. **Combo är en mekanik ovanpå kortkostnaden.** `633906212883: "Play cards in ascending {0} {:color(Mana):{GlobalKeywords.Mana} cost} order for a Combo Multiplier."`, `158106791638413313: "Wild cards can be used to connect combos together to make bigger Combos."`, samt en egen Combo-hög (`ComboPileModel`).
12. **Endless-läge och Red Death.** `205456101243494400: "Endless"`, `Best: {furthestFloor}`, och en strid kan avsluta dungeonen **även om spelaren dör** (`_completeDungeonOnDeath`, kommentar: "Red Death").
13. **Kortet kan modifieras utanför körningen.** Smedjan ger gemslots på kort man redan hittat (`CardGemSlots` sparas i progressionen), och gems har raritetsnivåer som kan säljas/sealas — dvs. kortutveckling sker delvis som meta-progression, inte bara inom en körning.

---

## 4. Kunde inte beläggas

- **Exakt antal val i nivåvalet.** Luck ger *chans till 4*, men basantalet (3 eller annat) kunde inte beläggas — `rewardCount` är en metodparameter utan värde i dumpen.
- **När reward-modalen öppnas i förhållande till striden.** Att `PlayerXpBarView` öppnar `ChooseCardModal` är belagt, och `ChooseCardModal` har fältet `_isPlayerTurn`, men om modalen kan öppnas mitt i en strid eller bara i säkra lägen kunde inte beläggas.
- **Exakta formler.** Dumpen saknar metodkroppar: XP-kurva, kombo-multiplikator, skada, `GetLevelUpChance`, `GetProgressForLevel`, `NukeDungeonEncounters` osv. går inte att läsa.
- **Antal våningar per dungeon och antal rum per våning.** `LayeredDungeonGenerator` och `GenerateDungeonFloor(...)` finns, men inga talvärden. Inte heller `DungeonGenerationConfig`-fältens värden.
- **Hur mynt går från körningen till `ProgressionSaveData.TotalCoins`.** Båda sidor är belagda (`PlayerModel._currentCoinCount` resp. `TotalCoins`), men kopplingen dem emellan kunde inte beläggas.
- **Vad en "Merchant" i dungeonen säljer**, och vad `GunForHireModal` / `GunForHireEventView` gör i sak.
- **Vad "Darkana" är** utöver `18050765511798784: "Adds Darkana events to dungeons."`.
- **Vad `EnemyCardThrowingEventView` gör** utöver namnet.
- **Om "Victorious Retreat" / "Succumb to Death" är spelarval i pausmenyn** — texterna finns, men UI-kopplingen kunde inte beläggas.
- **Antal sparplatser** ("Max saves used. Delete a save." finns, men inget maxantal).
- **Siffervärden för `ChooseGemModal._baseChoiceCount`** och `GlobalConfig.MetaUpgradeConfig`-kostnaderna.
- **Kartans topologi i detalj** (hur `TiledMapData` genereras, hur `LayeredDungeonGenerator` lägger lager).
- **Vad `PlayerLevelConfig._xpCurveExponent`/`_xpCurveMultiplier`/`_baseXpReq` faktiskt är satta till.**
- **Epilog-innehållet.** Flaggor och events finns (`EpilogueStarted`, `EpilogueCompleted`), men ingen text eller skärm kunde beläggas.
- **Om `boss` är en egen rumstyp i allmänhet.** `rt_enderboss`-bundlen och `_allowsDynamicBossSpawning` är belagda, men om alla banor har en namngiven boss kunde inte beläggas.
- **`Credits`-innehållet** och hur `Credits`-bundlen spelas upp.
- **Hur `TreasureChestManager` och `GemChestManager.ChestTiers` mappar till rum** — klasserna finns men ingen koppling till konfigvärden kunde läsas.
- **Hur man väljer Hard Mode / "harder version of any stage"** i praktiken (endast reliktexten `633906212877` är belagd).

---

## 5. Sammanfattning för Alex

**Huvudsteg i ordning:**

1. **Huvudmeny** — New Game / Continue / Load Game / Options / Credits / Quit, sparfilsval, "PRESS TO START".
2. **Crawler-val** — välj huvud-Crawler, Arcana och preset; platser för fler köps i metan.
3. **Byn Gorton** — karusell av byggnader: Inn (rekrytera Crawlers), Shop (PowerUps per rank), Fortune Teller (Arcana), Museum (reliker), Town Hall (achievements), Blacksmith (gemslots/gem-raritet), Graveyard (Options), och en gated utgång till världskartan.
4. **Världskartan / Stage Selection** — platser med underbanor, svårighet, Cleared-markering, relik- och crawler-ikoner, Hurry, Endless, Enter Region.
5. **Dungeonen** — förstaperson-rutnät: gå/rotera (Rotate and Move), minikarta, händelsemarkörer. Rummen: strid, coffin med roterande vaktare, offerbord, evolutionsbord, gemkista, relik, NPC-dialog, handlare, ambush.
6. **Striden** — EncounterStart → player turn (lägg kort, combo, mana) → end turn → post-turn-effekter → enemy turn, i loop. Fiendeavsikter med nedräknare (`EnemyInterruptModel`).
7. **Level up från XP-baren** — kristaller på golvet fyller baren, `ChooseCardModal` öppnar "Level Up!" / "Choose a reward": ett kort eller ett gem, med Reroll / Skip / Banish / Cash Out. Luck ger chans till 4 val.
8. **Nedstigning och boss** — spaden gräver upp utgången, `FloorTransitionState` byter våning, Ender/Red Death-boss, `DungeonCompleteState` eller `PlayerDiedState` → **Resultatskärm** med tid, våningar, mynt, level, fiender, max combo, vapensammanfattning, bonusmynt, achievements, New Best.
9. **Tillbaka i byn** — mynt hamnar i `ProgressionSaveData.TotalCoins`, upplåsningar/achievements triggas, reliker och PowerUp-ranks ändrar nästa körning.

**De tre viktigaste skillnaderna mot en vanlig deckbuilder:**

1. **Ingen nodkarta** — i stället ett förstapersons-rutnät där man går och roterar, och rummen *påträffas* som markörer på rutor (ingen "välj väg"-nod, ingen nyckel/nyckelhål — utgången kommer från en spade).
2. **Nivåvalet är kopplat till en XP-bar som fylls av fysiska kristaller mitt i körningen**, inte till en skärm mellan strider; och varje val kan vara antingen ett kort eller ett gem som senare stoppas in i ett kort.
3. **Reroll, Skip och Banish är permanenta meta-resurser man köper i byn** (per rank), precis som kort-platser, crawler-platser, Luck och Risk — själva butiken och kortutvecklingen (gemslots, evolutions) ligger i hubben, medan dungeonen bara får handlare om man hittat en specifik relik.
