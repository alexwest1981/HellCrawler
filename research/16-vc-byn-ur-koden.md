# VC:s by, läst ur koden (20/10)

Källa: `~/Games/Vampire.Crawlers-jc141` — DwarFS-paketerat Unity-bygge (IL2CPP), uppackat till
`~/Games/vc_extract`. `Vampire Crawlers_Data/il2cpp_data/Metadata/global-metadata.dat` (18,7 MB) bär
alla typ- och medlemsnamn i klartext; `GameAssembly.dll` (87 MB) är den kompilerade koden.

## Det som bevisar uppbyggnaden

Byggnader, vyer och data är egna typer med egna filer i källträdet (sökvägarna står i metadata):

| Typ | Fil |
|---|---|
| `Nosebleed.Pancake.LevelSelect.TownBuilding` | `Assets/_GameAssets/Scripts/TownMap/…` |
| `Nosebleed.Pancake.LevelSelect.TownBuilding.TownBuildingUISettings` | samma |
| `Nosebleed.Pancake.View.TownViewController` | `Assets/_GameAssets/Scripts/TownMap/…` |
| `Nosebleed.Pancake.View.CarouselSelectionView` | `Assets/_GameAssets/Scripts/TownMap/CarouselSelectionView.cs` |
| `Nosebleed.Pancake.View.CarouselSelectionViewController` | samma |
| `Nosebleed.Pancake.View.UI.ButtonCarousel` | `Assets/_GameAssets/Scripts/Views/GameUI/ButtonCarousel.cs` |
| `Nosebleed.Pancake.View.UI.ButtonCarousel.CarouselItem` | samma |
| `Nosebleed.Pancake.View.UI.IButtonCarouselItemValidator` | samma |
| `Nosebleed.Pancake.GameConfig.TownBuildingDatabase` | konfig |
| `Nosebleed.Pancake.GameConfig.ShopConfigs.TownBuildingConfig` | konfig |

**Byn är alltså en KARUSELL, inte en panoramabild.** Det är därför den "roterar" mellan porten,
smeden, museet och resten: byggnaderna står på en ring, och man vrider ringen ett steg i taget.

## Medlemsnamn som säger hur den fungerar

Lästa ur metadatans strängheap (`_` = fält, `On…` = händelse):

* `_buttonCarousel` — vyn äger en `ButtonCarousel`, alltså själva vridningen.
* `_townBuildingDatabase`, `_townBuildingConfigsToUnlock` — byggnaderna är DATA, inte scener.
* `_linkedBuilding`, `_shopBuilding`, `_arcanaBuildingConfig` — byggnader kan peka på varandra
  (juveleraren ligger inne i smeden, arcanan i spågumman).
* `_unlockedBuildingDesc`, `_lockedBuildingDesc`, `_townBuildingName` — varje byggnad har en
  beskrivning för både upplåst och låst läge, alltså syns den även innan den går att använda.
* `_isBuildingViewOpen` — att "gå in" är att öppna en vy ovanpå byn, inte att byta scen.
* `_moveToTownHallDuration`, `_cutToTimeScaleBeforeTownHall` — kameran glider till rådhuset med en
  egen varaktighet; det är rörelsen mellan två vyer som är animerad, inte gatan.
* `_debugUnlockBuildings` — upplåsningen är en flagga per byggnad.
* `IsVillage`, `GoToVillage`, `OnVillageClicked`, `UpdateVillagePanel`, `SetVillageConfig` — vägen in
  och ut ur byn går genom en panel; byn är en plats man går TILL, inte en meny man står i.

## Vad det betyder för vår by

1. **Byggnaderna är objekt på en ring.** Varje byggnad har egen bild, egen ruta och egen text — inte
   en fläck i en gemensam målning.
2. **Vridningen är ett steg per byggnad**, med mjuk övergång; den mittersta är vald.
3. **Låsta byggnader SYNS** (de har en `lockedBuildingDesc`) — de försvinner inte ur ringen.
4. **Att gå in öppnar en vy över byn**; kameran glider, scenen byts inte.
5. **Upplåsning är data** (`TownBuildingDatabase` + `_townBuildingConfigsToUnlock`), inte hårdkodad
   ordning i vyn.

## Vad som INTE är läst

Metodkropparna. IL2CPP kompilerar C# till maskinkod i `GameAssembly.dll`, så logiken (hur mycket
varje steg vrider, hur låsta byggnader ritas, hur kameran glider) kräver Ghidra eller REA mot
binären — namnen ovan ger strukturen, inte talen. Det är nästa steg om vi vill ha exakta vinklar och
tider i stället för rimliga.
