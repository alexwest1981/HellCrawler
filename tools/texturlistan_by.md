# Texturlistan: vad Alex' by behöver målas med

Varje rad är ett material ur scenen (50 st). Rutstorleken är **256 x 256 px** = **0,5 m i världen** (projektets egen täthet: 512 px/m i `tools/gen_tiles_alex.py`), så motiven ska passa ett helt antal gånger inom 0,5 m. Alla plattor måste vara **sömlösa kant mot kant** och hålla sig till de **27 färgerna i `game/assets/palette.json`**.

Genereras av `tools/uv_byn.py --lista`. Kör om den när scenen fått nya material.

## Plattor att måla

| Material | Yta i scenen | Sort | Fil | px | Färg |
|---|---:|---|---|---:|---|
| `Cloth_Blue` | 6.4 m² / 72 ytor | tyg: vimpel, blekt av sol och regn | `cloth_blue.png` | 256 | ljusgrå |
| `Cloth_Cyan` | 1.6 m² / 34 ytor | tyg i cyan, samma väv | `cloth_blue.png` | 256 | ljusgrå |
| `Cloth_Green` | 0.7 m² / 18 ytor | tyg i grönt, samma väv | `cloth_blue.png` | 256 | ljusgrå |
| `Cloth_Purple` | 0.9 m² / 16 ytor | tyg i purpur, samma väv | `cloth_blue.png` | 256 | ljusgrå |
| `Cloth_Red` | 3.6 m² / 40 ytor | tyg i rött, samma väv (skyltdukar) | `cloth_blue.png` | 256 | ljusgrå |
| `Cobble_1` | 29.5 m² / 690 ytor | kullersten, runda stenar i jord, tätast | `cobble_1.png` | 256 | ljusgrå |
| `Cobble_2` | 22.9 m² / 546 ytor | kullersten, medel mellanrum | `cobble_2.png` | 256 | ljusgrå |
| `Cobble_3` | 23.5 m² / 534 ytor | kullersten, oregelbunden, glest | `cobble_3.png` | 256 | ljusgrå |
| `Dirt_Cliff` | 450.0 m² / 6 ytor | jordbrant: torr jord, rötter, smulor | `dirt_cliff.png` | 256 | målad (jordbrun) |
| `Gold` | 1.6 m² / 112 ytor | förgyllning: slät metall, svag vågighet | `gold_trim.png` | 256 | målad (guld) |
| `Grass_Dark` | 86.7 m² / 6 ytor | gräs, tuvor med jord emellan | `grass_dark.png` | 256 | ljusgrå |
| `Grass_Light` | 261.4 m² / 2166 ytor | gräs, ljust och kort | `grass_light.png` | 256 | ljusgrå |
| `Grass_Mid` | 1708.0 m² / 6 ytor | gräs, tätare | `grass_mid.png` | 256 | ljusgrå |
| `Iron` | 11.5 m² / 1532 ytor | smidesjärn: hamrat, nött, med nitar | `iron_forged.png` | 256 | målad (järngrå) |
| `Leaf_Dark` | 168.1 m² / 2240 ytor | lövverk, mörkare löv | `leaf.png` | 256 | ljusgrå |
| `Leaf_Light` | 137.6 m² / 1440 ytor | lövverk, ljusgröna löv | `leaf.png` | 256 | ljusgrå |
| `Leaf_Mid` | 261.3 m² / 2960 ytor | lövverk: tät lövmassa, mörka hål emellan | `leaf.png` | 256 | ljusgrå |
| `Mountain_Rock` | 1237.8 m² / 40 ytor | berg: sprängd gråsten med sprickor | `rock_mountain.png` | 256 | målad (gråblå) |
| `Pine_Green` | 322.1 m² / 448 ytor | barr: täta barr i grenar, mörk botten | `pine_needles.png` | 256 | målad (mörkgrön) |
| `Plaster_Cream` | 333.7 m² / 168 ytor | puts, slät med en kornig yta och lagade fläckar | `wall_plaster_cream.png` | 256 | gräddvit |
| `Plaster_Warm` | 529.2 m² / 258 ytor | puts, varm sandton, strävare | `wall_plaster_warm.png` | 256 | gräddvit |
| `Road_Base` | 199.1 m² / 12 ytor | grusväg: packad jord med grus och hjulspår | `road_ground.png` | 256 | målad (gråbrun) |
| `Roof_Purple_1` | 22.1 m² / 300 ytor | takpannor, purpur (juveleraren och magiska hus) | `roof_tile_purple.png` | 256 | ljusgrå |
| `Roof_Purple_2` | 21.2 m² / 288 ytor | samma purpurpannor, ljusare | `roof_tile_purple.png` | 256 | ljusgrå |
| `Roof_Red_1` | 58.9 m² / 840 ytor | takpannor, tegel, två pannor i bredd per ruta | `roof_tile_red.png` | 256 | ljusgrå |
| `Roof_Red_2` | 58.9 m² / 840 ytor | samma pannor, ljusare tegel | `roof_tile_red.png` | 256 | ljusgrå |
| `Roof_Slate_1` | 53.1 m² / 852 ytor | takpannor, skiffer, skivor i förband | `roof_tile_slate.png` | 256 | ljusgrå |
| `Roof_Slate_2` | 51.4 m² / 828 ytor | samma skiffer, ljusare | `roof_tile_slate.png` | 256 | ljusgrå |
| `Roof_Thatch` | 14.2 m² / 252 ytor | vasstak: vassrör i lager, ojämn kant | `roof_thatch.png` | 256 | målad (halmgul) |
| `Sheep_Wool` | 9.9 m² / 84 ytor | ull: lockig, mjuk yta | `wool.png` | 256 | målad (vit) |
| `Stone_Dark` | 39.0 m² / 258 ytor | mursten, mörk (sockel och hörn) | `wall_stone_dark.png` | 256 | ljusgrå |
| `Stone_Light` | 319.8 m² / 1230 ytor | slätare mursten, ljust hugg | `wall_stone_light.png` | 256 | ljusgrå |
| `Stone_Wall` | 895.3 m² / 204 ytor | grov stenmur, huggna block med murbruk i fogarna | `wall_stone_rough.png` | 256 | ljusgrå |
| `Window_Bright` | 5.2 m² / 12 ytor | fönsterglas med kallt ljus (lykta, skyltfönster) | `window_glass_bright.png` | 256 | målad (blekgul) |
| `Window_Warm` | 18.4 m² / 42 ytor | fönsterglas med varmt ljus inifrån, fyra rutor spröjs | `window_glass_warm.png` | 256 | målad (bärnsten) |
| `Wood_Beam` | 128.0 m² / 444 ytor | grov bjälke, synlig fiber och ändträ | `wood_beam.png` | 256 | målad (mörk ek) |
| `Wood_Dark` | 382.2 m² / 630 ytor | plank, mörkt trä, hyvlade ränder | `wood_plank_dark.png` | 256 | ljusgrå |
| `Wood_Light` | 0.7 m² / 18 ytor | plank, ljust trä, hyvlade ränder | `wood_plank_light.png` | 256 | ljusgrå |
| `Wood_Oak` | 266.4 m² / 534 ytor | plank, ek, kvistar och fiber | `wood_plank_oak.png` | 256 | ljusgrå |

## Behöver INGEN platta

| Material | Yta i scenen | Varför inte |
|---|---:|---|
| `Bulb_Glow` | 2.1 m² / 2688 ytor | 41 glödlampor på 2 688 ytor: varje lampa är några centimeter. Lyser (emission 12) och läses som LJUS, inte som yta — en platta syns inte. |
| `Cloud_White` | 205.5 m² / 1200 ytor | himmelsplattor: molnen ska vara MJUKA och enfärgade, en platta gör dem prickiga. Ligger dessutom bakom allt annat. |
| `Fire_Core` | 2.3 m² / 646 ytor | lågans kärna, emission 18. Lyser. |
| `Fire_Orange` | 1.7 m² / 6 ytor | lågans kant, emission 10. Lyser. |
| `Gem_Cyan` | 0.2 m² / 80 ytor | EN yta, några decimeter. Lyser (emission 8): plattan är större än juvelen. |
| `Gem_Green` | 0.2 m² / 80 ytor | EN yta. Lyser (emission 7). |
| `Gem_Pink` | 0.2 m² / 80 ytor | EN yta. Lyser (emission 7). |
| `Horse_Brown` | 2.3 m² / 18 ytor | hästen. För liten yta för att en platta ska synas; platt färg räcker. |
| `Skin` | 3.5 m² / 60 ytor | ansikten och händer på 10 figurer. En textur här kräver att UV:n sys per figur (ögon, mun, näsa på rätt plats) — kubprojektion lägger ögat på kinden. Platt färg ser bättre ut. |
| `Smoke_Grey` | 10.7 m² / 400 ytor | rök, mjukade partiklar. Samma skäl som molnen. |

## Rutnätet

En platta = **0,5 m**. UV-lagret ligger redan på alla 1931 mesh-objekt (`tools/uv_byn.py`), så en textur som läggs i materialets basfärg hamnar rätt utan vidare arbete. Materialets egen basfärg MULTIPLICERAS med plattan — därav `ljusgrå` i färgkolumnen: måla mönstret neutralt så tonar materialet det, precis som scenens platta färger redan gör.

## Skriptets klassning: material -> platta

Alex' `tools/apply_pixel_textures.py` klassar varje objekt på dess **FÖRSTA material** (`obj.data.materials[0].name`) och ger det en av tjugoen plattor (elva ur Alex' paket i `game/assets/by/tex/` och tio ur atlasen i `game/assets/by/tex/atlas/`). Objektnamns-reglerna finns kvar, men bara som **fallback** för material som ännu inte har en platta. Siffrorna är mätta i scenen, inte skriptets avsikt.

Namnklassningen som låg före den här mätningen gav 808 objekt Terracotta Roof, 0 Slate Roof och 324 stenhus utan nyckelordsträff — namnen skiljer helt enkelt inte materialen.

### Objektets första material -> platta

| Originalmaterial | Platta | Plattfil | Objekt |
|---|---|---|---:|
| `Cobble_2` | Cobblestone Brown | `atlas/cobblestone_brown.png` | 91 |
| **1 material** | | | **91** |
| `Cobble_1` | Cobblestone Grey | `atlas/cobblestone_grey.png` | 115 |
| **1 material** | | | **115** |
| `Cobble_3` | Cobblestone Mossy | `atlas/cobblestone_mossy.png` | 89 |
| **1 material** | | | **89** |
| `Road_Base` | Dirt Stony | `atlas/dirt_stony.png` | 2 |
| **1 material** | | | **2** |
| `Grass_Light` | Grass Flowers | `atlas/grass.png` | 28 |
| `Grass_Dark` | Grass Flowers | `atlas/grass.png` | 1 |
| `Grass_Mid` | Grass Flowers | `atlas/grass.png` | 1 |
| **3 material** | | | **30** |
| `Leaf_Mid` | Hedge | `hedge.png` | 37 |
| `Pine_Green` | Hedge | `hedge.png` | 32 |
| `Leaf_Dark` | Hedge | `hedge.png` | 28 |
| `Leaf_Light` | Hedge | `hedge.png` | 18 |
| **4 material** | | | **115** |
| `Iron` | Iron Riveted | `atlas/metal_riveted.png` | 44 |
| **1 material** | | | **44** |
| `Dirt_Cliff` | Sand Path | `atlas/sand_path.png` | 1 |
| **1 material** | | | **1** |
| `Roof_Slate_1` | Slate Roof | `roof_slate.png` | 142 |
| `Roof_Slate_2` | Slate Roof | `roof_slate.png` | 138 |
| `Roof_Purple_1` | Slate Roof | `roof_slate.png` | 50 |
| `Roof_Purple_2` | Slate Roof | `roof_slate.png` | 48 |
| **4 material** | | | **378** |
| `Stone_Light` | Stone | `stone_wall.png` | 201 |
| `Stone_Dark` | Stone | `stone_wall.png` | 43 |
| `Stone_Wall` | Stone | `stone_wall.png` | 30 |
| **3 material** | | | **274** |
| `Mountain_Rock` | Stone Mossy | `atlas/stone_wall_mossy_small.png` | 5 |
| **1 material** | | | **5** |
| `Roof_Red_1` | Terracotta Roof | `roof_terracotta.png` | 140 |
| `Roof_Red_2` | Terracotta Roof | `roof_terracotta.png` | 140 |
| **2 material** | | | **280** |
| `Plaster_Warm` | Tudor Plaster | `tudor_wall.png` | 43 |
| `Plaster_Cream` | Tudor Plaster | `tudor_wall.png` | 28 |
| **2 material** | | | **71** |
| `Window_Bright` | Window Bright | `atlas/window_narrow.png` | 2 |
| **1 material** | | | **2** |
| `Window_Warm` | Window Warm | `atlas/window_four_pane.png` | 7 |
| **1 material** | | | **7** |
| `Wood_Dark` | Wood | `wood_planks.png` | 99 |
| `Wood_Oak` | Wood | `wood_planks.png` | 82 |
| `Wood_Beam` | Wood | `wood_planks.png` | 67 |
| `Wood_Light` | Wood | `wood_planks.png` | 3 |
| **4 material** | | | **251** |

### Material utan platta i paketet — underlaget för vilka plattor Alex behöver

| Originalmaterial | Objekt | Nödlösning (namnregeln) |
|---|---:|---|
| `Roof_Thatch` | 42 | Terracotta Roof |
| `Bulb_Glow` | 41 | Stone |
| `Sheep_Wool` | 14 | Stone |
| `Cloth_Blue` | 12 | Stone |
| `Skin` | 10 | Stone |
| `Fire_Core` | 9 | Stone |
| `Cloth_Red` | 6 | Stone |
| `Cloth_Cyan` | 5 | Stone |
| `Gold` | 5 | Stone |
| `Cloth_Green` | 3 | Stone |
| `Horse_Brown` | 3 | Stone |
| `Cloth_Purple` | 2 | Stone |
| `Fire_Orange` | 1 | Stone |
| `Gem_Cyan` | 1 | Stone |
| `Gem_Green` | 1 | Stone |
| `Gem_Pink` | 1 | Stone |
| **16 material** | **156** | |

### Rök och moln — tas ur exporten, ersätts av en smoke emitter i Godot

Alex' .blend rörs inte; exportskriptet kopplar loss objekten ur samlingen och lägger en `GPUParticles3D` på rökens uppmätta mitt i stället (`game/ui/by_3d.gd`). glTF bär inga partikelsystem, så en Blender-emitter hade inte överlevt exporten.

| Objekt | Originalmaterial |
|---|---|
| `Chimney_Smoke_0` | `Smoke_Grey` |
| `Chimney_Smoke_1` | `Smoke_Grey` |
| `Chimney_Smoke_2` | `Smoke_Grey` |
| `Chimney_Smoke_3` | `Smoke_Grey` |
| `Chimney_Smoke_4` | `Smoke_Grey` |
| `Cloud_L_0` | `Cloud_White` |
| `Cloud_L_1` | `Cloud_White` |
| `Cloud_L_2` | `Cloud_White` |
| `Cloud_L_3` | `Cloud_White` |
| `Cloud_L_4` | `Cloud_White` |
| `Cloud_Main_0` | `Cloud_White` |
| `Cloud_Main_1` | `Cloud_White` |
| `Cloud_Main_2` | `Cloud_White` |
| `Cloud_Main_3` | `Cloud_White` |
| `Cloud_Main_4` | `Cloud_White` |
| `Cloud_R_0` | `Cloud_White` |
| `Cloud_R_1` | `Cloud_White` |
| `Cloud_R_2` | `Cloud_White` |
| `Cloud_R_3` | `Cloud_White` |
| `Cloud_R_4` | `Cloud_White` |

| Rökkluster | Objekt | Mitt, glTF (x, y, z) |
|---|---:|---|
| Chimney_Smoke | 5 | -10.65, 7.03, -1.85 |
| Cloud_L | 5 | -0.28, 9.13, -18.00 |
| Cloud_Main | 5 | 1.10, 9.38, -18.00 |
| Cloud_R | 5 | 2.48, 9.19, -18.00 |

### Bakgrunden (namn med `bg`) — tak, inte sten

`BG_House_*` är små hus i bakgrunden; taken (`*_TileL`/`*_TileR`) och de krenelerade murarna får takplatta i stället för sten.

| Bakgrundsobjekt | Antal |
|---|---:|
| på en takplatta (`roof_terracotta` / `roof_slate`) | 305 |
| kvar på stenplattan | 0 |
| totalt | 365 |

### Vad klassningen blev i scenen (materialet i den exporterade filen)

| Material | Plattfil | Objekt | Ytor | Area m² |
|---|---|---:|---:|---:|
| `Bulb_Glow` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cloth_Blue` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cloth_Cyan` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cloth_Green` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cloth_Purple` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cloth_Red` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cloud_White` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cobble_1` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cobble_2` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Cobble_3` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Dirt_Cliff` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Fire_Core` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Fire_Orange` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Gem_Cyan` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Gem_Green` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Gem_Pink` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Gold` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Grass_Dark` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Grass_Light` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Grass_Mid` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Horse_Brown` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Iron` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Leaf_Dark` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Leaf_Light` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Leaf_Mid` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Mountain_Rock` | `**ingen bild**` | 0 | 0 | 0.0 |
| `PX_Cobblestone Brown` | `cobblestone_brown.png` | 91 | 546 | 22.9 |
| `PX_Cobblestone Grey` | `cobblestone_grey.png` | 115 | 690 | 29.5 |
| `PX_Cobblestone Ground` | `cobblestone_ground.png` | 0 | 0 | 0.0 |
| `PX_Cobblestone Mossy` | `cobblestone_mossy.png` | 89 | 534 | 23.5 |
| `PX_Dark Stone` | `dark_stone.png` | 6 | 36 | 3.7 |
| `PX_Dirt` | `dirt.png` | 0 | 0 | 0.0 |
| `PX_Dirt Stony` | `dirt_stony.png` | 2 | 12 | 199.1 |
| `PX_Grass` | `grass.png` | 0 | 0 | 0.0 |
| `PX_Grass Flowers` | `grass.png` | 30 | 2178 | 2056.1 |
| `PX_Hedge` | `hedge.png` | 115 | 7088 | 889.2 |
| `PX_Iron Riveted` | `metal_riveted.png` | 44 | 1532 | 11.5 |
| `PX_Mossy Stone` | `mossy_stone.png` | 0 | 0 | 0.0 |
| `PX_Sand Path` | `sand_path.png` | 1 | 6 | 450.0 |
| `PX_Slate Roof` | `roof_slate.png` | 382 | 2340 | 353.3 |
| `PX_Stone` | `stone_wall.png` | 340 | 5378 | 737.4 |
| `PX_Stone Mossy` | `stone_wall_mossy_small.png` | 5 | 40 | 1237.8 |
| `PX_Terracotta Roof` | `roof_terracotta.png` | 357 | 2142 | 475.6 |
| `PX_Tudor Plaster` | `tudor_wall.png` | 71 | 426 | 862.9 |
| `PX_Window Bright` | `window_narrow.png` | 2 | 12 | 5.2 |
| `PX_Window Warm` | `window_four_pane.png` | 7 | 42 | 18.4 |
| `PX_Wood` | `wood_planks.png` | 254 | 1656 | 778.1 |
| `Pine_Green` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Plaster_Cream` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Plaster_Warm` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Road_Base` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Purple_1` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Purple_2` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Red_1` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Red_2` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Slate_1` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Slate_2` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Roof_Thatch` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Sheep_Wool` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Sign_Text` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Skin` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Smoke_Grey` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Stone_Dark` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Stone_Light` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Stone_Wall` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Window_Bright` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Window_Warm` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Wood_Beam` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Wood_Dark` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Wood_Light` | `**ingen bild**` | 0 | 0 | 0.0 |
| `Wood_Oak` | `**ingen bild**` | 0 | 0 | 0.0 |

Objekt utan platta alls (materialet saknar bildtextur) räknas inte i tabellen ovan; alla 71 material i filen står med.

## Plattornas palettavstånd

Medelavståndet från varje pixel till närmaste palettfärg, delat med 441,67. Tröskeln är **0.18**; alla plattor ligger långt under den.

| Platta | Fil | Palettavstånd | I bruk |
|---|---|---:|---|
| paketet | `cobblestone_ground.png` | 0.0444 |  |
| paketet | `dark_stone.png` | 0.0399 |  |
| paketet | `dirt.png` | 0.0426 |  |
| paketet | `grass.png` | 0.0875 |  |
| paketet | `hedge.png` | 0.0895 |  |
| paketet | `mossy_stone.png` | 0.0412 |  |
| paketet | `roof_slate.png` | 0.0365 |  |
| paketet | `roof_terracotta.png` | 0.0581 |  |
| paketet | `stone_wall.png` | 0.0385 |  |
| paketet | `tudor_wall.png` | 0.0626 |  |
| paketet | `wood_planks.png` | 0.0460 |  |
| atlasen | `atlas/castle_merlons.png` | 0.0370 |  |
| atlasen | `atlas/clay_red.png` | 0.0335 |  |
| atlasen | `atlas/cobblestone_brown.png` | 0.0515 |  |
| atlasen | `atlas/cobblestone_grey.png` | 0.0367 |  |
| atlasen | `atlas/cobblestone_mossy.png` | 0.0476 |  |
| atlasen | `atlas/dirt.png` | 0.0435 |  |
| atlasen | `atlas/dirt_stony.png` | 0.0391 |  |
| atlasen | `atlas/door_wood_iron.png` | 0.0302 |  |
| atlasen | `atlas/forge_stone_glow.png` | 0.0287 |  |
| atlasen | `atlas/grass.png` | 0.0933 |  |
| atlasen | `atlas/ivy.png` | 0.0762 |  |
| atlasen | `atlas/metal_riveted.png` | 0.0257 |  |
| atlasen | `atlas/roof_slate.png` | 0.0351 |  |
| atlasen | `atlas/roof_tiles_red.png` | 0.0467 |  |
| atlasen | `atlas/sand_path.png` | 0.0509 |  |
| atlasen | `atlas/stone_arch.png` | 0.0304 |  |
| atlasen | `atlas/stone_mossy.png` | 0.0654 |  |
| atlasen | `atlas/stone_wall_dark.png` | 0.0334 |  |
| atlasen | `atlas/stone_wall_dark_small.png` | 0.0319 |  |
| atlasen | `atlas/stone_wall_light.png` | 0.0386 |  |
| atlasen | `atlas/stone_wall_light_small.png` | 0.0391 |  |
| atlasen | `atlas/stone_wall_mossy_small.png` | 0.0517 |  |
| atlasen | `atlas/timber_frame.png` | 0.0502 |  |
| atlasen | `atlas/timber_frame_small.png` | 0.0509 |  |
| atlasen | `atlas/window_arched_stone.png` | 0.0491 |  |
| atlasen | `atlas/window_diamond_lattice.png` | 0.0524 |  |
| atlasen | `atlas/window_four_pane.png` | 0.0507 |  |
| atlasen | `atlas/window_narrow.png` | 0.0458 |  |
| atlasen | `atlas/window_round_stone.png` | 0.0458 |  |
| atlasen | `atlas/window_tall_panes.png` | 0.0516 |  |
| atlasen | `atlas/wood_planks.png` | 0.0397 |  |
| atlasen | `atlas/wood_planks_small.png` | 0.0381 |  |

43 plattor mätta, 43 under tröskeln, 0 över: inga
