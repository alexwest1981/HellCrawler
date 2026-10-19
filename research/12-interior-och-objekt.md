# Interiören och objekten i Vampire Crawlers — mätt ur bygget

Källa: `research/referens-tillgangar.json` (adressables-katalogen ur den skeppade releasen,
1 014 poster i de 12 bundlar som katalogen listar). Bara **namn, struktur och format** härifrån —
inga bilder, meshar, ljud eller texter används i vårt spel.

## A. Vad de faktiskt gör

### 1. Det finns ingen 2D-rekvisita. Allt är prefabs i 3D.

| Format | Antal |
|---|---|
| `.prefab` | 726 |
| `.asset` | 183 |
| `.fbx` | 21 |
| `.psd` (himmler, skyltar, byns delar) | 20 |
| `.png` | **6** |
| `.spriteatlasv2` | **4** |

De sex PNG-filerna och fyra atlasarna räcker inte till en enda rekvisita — de är FX-texturer och UI.
**Varje ljusstake, kista, tunna och bokhylla är en mesh i en prefab.** Det är därför de kan gå sönder,
välta och lysa: en bild kan inget av det.

### 2. Rummets skal byggs av modulära plattor med geometriska roller

Per biom, samma vokabulär:

| Mapp | Antal | Roller |
|---|---|---|
| `Tiles/Rooms` | 75 | `Room_Fill`, `Room_Edge`, `Room_CornerInner`, `Room_CornerOuter` |
| `Tiles/Corridors` | 106 | `Corridor_Straight`, `_Corner`, `_TJunction`, `_Crossroads`, `_DeadEnd`, `_to_Room`, `_to_Room_Corner` |
| `Tiles/Border` | 14 | `Border_Inner_01..06`, `Border_Outer_01` |

Ett rum är alltså **inte en mesh** — det är en samling golv-/vägg-/hörnplattor som sätts ihop efter
vilken roll rutan har i rummet. Det är samma princip som en tilemap, men i 3D, och därför kan de byta
biom utan att rita om geometrin.

### 3. Möbleringen ligger i egna layout-prefabs, inte i koden

164 prefabs under `Prefabs/Layouts`, namngivna `<Biom>_<WxH>_<NN>`: `Layout_MadForest_2x3_02`,
`Layout_DairyPlant_4x4_03` osv. Varje layout är **en handplacerad möblering för en rumstorlek**, och
de finns i varianter som säger vad rummet är:

* `-Boss` — bossrummet (samma storlek, annan möblering)
* `_Dead_01..05` — det övergivna/trasiga rummet
* `_GemChest` — rummet med gemkistan
* `_Spawn` — startrummet

Storlekarna är grova: 1x1, 2x1, 2x2, 2x3, 3x3, 4x3, 4x4, 5x3 — plus `Layout_TinyBridge_1x12/16/20`,
där **bron är ett rum som är en enda lång korridor**.

### 4. Rekvisitan finns i set, och i vägg- och golvvariant

251 unika prop-prefabs. Namnen visar systemet:

* **Set för variation**: `Barrel_Set_01..03`, `Bookshelves_Set_01..04`, `Machinery_Set_01..05`,
  `Walldesk_01..06`, `WallDressing_01..03`, `Ground_Dressing_01..06`, `Ground_Foliage_01..06`,
  `Tree_Dressing_01..05`, `Tombstones_Set_01`, `Locker_Set_01..03`, `Mirror_Set_01`, `Table_Set_01..04`.
* **Monteringssätt i namnet**: `Candelabra_Standing` mot `Candelabra_WallMountedTrio`, `Wall_Shelves`,
  `Chandelier` (tak), `WallDressing` (vägg) mot `Ground_Dressing` (golv). Ett objekt har alltså en
  variant per yta det kan sitta på.
* **Blockers**: `BlockerBookcase_01/02`, `Book_Case_Block`, `MadForest_Blocker_01..05` — rekvisita som
  också är vägg (samma prefab, annan kollisionsprofil).
* **Skräp i mängd**: `Book_Pile_01`, `Bottles_Clutter_01`, `Ground_Foliage` — småsaker som gör rummet
  bebott utan att vara interaktiva.

### 5. Interaktivt = samma prefab med en annan komponent

45 prefabs under `DungeonEnvironment/Destructibles`:

`DestructibleCandelabrador`, `DestructibleBookcase`, `DestructibleCart`, `DestructibleRailCart`,
`DestructibleManaStatue`, `DestructibleEvoStatue`, `DestructibleStatue`, `DestructibleGargoyle`,
`DestructibleRelic`, `DestructibleCoin`, `DestructibleChicken`, `DestructibleMana`, `DestructibleReroll`,
`DestructibleMossyLog`, `DestructibleMilkBarrel`, `DestructibleAmount` …

Namnet på objektet står kvar; det som skiljer är **vilket beteende som sitter på det**. En kandelaber
är en kandelaber, och en kandelaber man kan slå sönder är samma prefab med en `Destructible`-komponent.
Det är därför de kunde lägga till nya interaktioner utan att rita nya modeller.

### 6. Ljuset är en PLATS, inte ett objekt

Det här är den finaste detaljen i hela systemet:

* `DestructibleLightSourceMarker` — en markör som säger "här får det stå en ljuskälla".
* `AllLightSources` — tabellen över vad som får stå där.
* Sex typade källor: `DestructibleLightSource_Card`, `_Chicken`, `_Coin`, `_Mana`, `_Empty`, `_Random`.
* `LightCone.fbx` + `UnlitTorchLight.shadergraph` — ljuskonen är egen geometri med en unlit-shader.

Rummen har alltså **ljusplatser**, och en tabell bestämmer vad som står på dem (ett kort, en kyckling,
ett mynt, mana, ingenting, eller slumpat). Det ger variation utan att någon ritar fler facklor.

### 7. Krocken är per biom, inte per objekt

`Props/Bumpables` innehåller exakt sex prefabs — en per biom: `MadForest_Bumpable`,
`DairyPlant_Bumpable`, `GallerTower_Bumpable`, `InlaidLibrary_Bumpable`, `CappellaMagna_Bumpable`,
`CappellaMagna_WingBalcony_Bumpable`. Regeln för "vad händer när spelaren går in i något" sitter alltså
på biomnivå, och objekten ärver den.

### 8. Konsten är voxel

`VoxelArtwork.fbx`, `Brazier.fbx`, `StandingLantern_01.fbx`, `DestructableCandelabra.fbx`,
`Chandelier_01.fbx`, `LightCone.fbx`. En mesh per objekt, gjord i voxel — inte en bild som roteras mot
kameran.

## B. Vad vi har, mätt mot deras

| Deras | Vårt | Status |
|---|---|---|
| Rekvisita som mesh | `core/voxel.gd` bygger en mesh ur pixelarket (`Voxel.ur_ark`); `VOXLAR := true`, så rekvisitan ritas redan som voxlar | ✅ maskinen finns |
| Modellerade objekt | våra voxlar är **reliefer**: bilden sampas ned och ges ett djup på `VOXEL_DJUP` celler, alltså en utskuren plåt — från sidan är de en kant | ❌ gapet |
| Layouter per rumstorlek | `data/blocks/*.json` (5 block: 7×7, 7×5, 5×5, 7×7, 9×3) | 🟡 samma idé, för få |
| Ljusplats + tabell | facklor placeras **direkt** i rummen | ❌ |
| Set-varianter | en bild per art | ❌ |
| Destructible-komponent | noder med beteende, men knutna till arten | 🟡 |
| Modulära rumplattor | hela rummet ritas som en mesh per ruta | 🟡 |

## C. Gapet, rangordnat efter hur mycket det syns

1. **Våra voxlar är reliefer, deras är modeller.** En tunna hos oss är tunnans färg med en plåt bakom;
   hos dem är den en cylinder med lock. Det syns så fort kameran inte står rakt framför, och det är
   därför våra rum läser som kulisser. → de mest sedda objekten (tunnor, kistor, ljusstakar, bokhyllor)
   behöver modelleras med djup, inte sampas ur en bild.
2. **För få layouter.** Fem block mot deras 164. Ett rum ska se olika ut varje gång, och det gör det
   bara om det finns flera möbleringar per storlek.
3. **Ljusplatser.** Vi sätter facklan där vi vill ha den; de sätter en *plats* och slumpar innehållet.
   Det är billigare och ger mer variation.
4. **Set.** `Barrel_Set_02` kostar en modell och ger ett rum som inte ser duplicerat ut.
5. **Blockerare som rekvisita.** Bokhyllan som både är möbel och vägg — vi har väggar och rekvisita som
   två separata lager.

## D. Nästa snitt

1. **Voxelisera rekvisitan** i `_bygg_dekor`: samma `Voxel.ur_ark` som fienderna, med `VOXEL_SIDOR`
   lägre för småsaker. Mät trianglar och bildrutor före/efter och ta en skärmbild.
2. **Ljusplats-markör** i karteditorn: en ruta som heter "ljusplats", med tabellen kort/kyckling/mynt/
   mana/tomt/slumpat. Kräver ingen ny konst — bara att facklan flyttas från placering till tabell.
3. **Fler block per storlek**, med `_dead`-variant (övergivet rum) som första nya typ.
