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
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |
| **0 material** | | | **0** |

### Material utan platta i paketet — underlaget för vilka plattor Alex behöver

| Originalmaterial | Objekt | Nödlösning (namnregeln) |
|---|---:|---|
| **0 material** | **0** | |

### Rök och moln — tas ur exporten, ersätts av en smoke emitter i Godot

Alex' .blend rörs inte; exportskriptet kopplar loss objekten ur samlingen och lägger en `GPUParticles3D` på rökens uppmätta mitt i stället (`game/ui/by_3d.gd`). glTF bär inga partikelsystem, så en Blender-emitter hade inte överlevt exporten.

| Objekt | Originalmaterial |
|---|---|
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
| Cloud_L | 5 | -0.28, 9.13, -18.00 |
| Cloud_Main | 5 | 1.10, 9.39, -18.00 |
| Cloud_R | 5 | 2.48, 9.21, -18.00 |

### Bakgrunden (namn med `bg`) — bara det TAKFORMADE får en takplatta

`BG_House_*` är små hus i bakgrunden och deras tak (`*_TileL`/`*_TileR`) kommer ur materialet, som alla andra tak. För bakgrundsobjekt med STENmaterial gäller namnet: ett takformat namn (tile/roof/gable/pyramid/spire) får en takplatta efter sin familj, och en MUR eller ett TORN behåller sin sten — den förra raden gav takplatta åt alla 39, och då låg teglet på kreneleringen (34) och borgmuren (1) samt skiffern på tornkroppen (4). MÄTT i den exporterade filen: `BG_Wall_Crenel` 34 och `BG_Castle_Wall` 1 gick från `PX_Terracotta Roof` till `PX_Stone`, `BG_Tower` 2 och `BG_Tower_Rim` 2 från `PX_Slate Roof` till `PX_Stone`.

| Bakgrundsobjekt | Antal |
|---|---:|
| på en takplatta (`roof_terracotta` / `roof_slate`) | 266 |
| på stenplattan (murar och torn) | 39 |
| varav MUR/TORN på en takplatta (ska vara 0) | 0 |
| totalt | 365 |

### Granskningen av hela mappningen (båda riktningarna)

Båda riktningarna mäts nu utan Blender, direkt i den exporterade `byn.glb`, av `tools/byn_form.py`:

* **En takplatta på en mur.** Namntabellen visar `wall` 35, `crenel` 34, `castle` 1, `tower` 26 och `merlon` 37 — alla på `PX_Stone`, noll på en takplatta. Skillnaden mot den COMMITTADE filen är exakt de 39 objekt Alex såg: 35 `PX_Terracotta Roof` → `PX_Stone` (34 kreneleringar på `BG_Wall_Crenel` + `BG_Castle_Wall`) och 4 `PX_Slate Roof` → `PX_Stone` (`BG_Tower_0/1`, `BG_Tower_Rim_0/1`).
* **En murplatta på ett tak** (baklänges): räknaren `tak_pa_mur` i `tools/apply_pixel_textures.py` mäter objekt med ett TAKMATERIAL som inte hamnade på en takplatta. Senaste körningen: 0. Väverskans tegelliknande tak är inte det felet — MÄTT: de 42 objekten (`Weaver_TileL_*` / `Weaver_TileR_*`) bär trämaterialen `Wood_*` och ska ha träplattan.
* Vasstaket står numera i `MATERIAL_TO_PLATE` (`Roof_Thatch` → `Terracotta Roof`, 42 objekt), så valet hänger inte längre på att objektnamnet råkar innehålla "tile".

### Vad klassningen blev i scenen (materialet i den exporterade filen)

| Material | Plattfil | Objekt | Ytor | Area m² |
|---|---|---:|---:|---:|
| `Cloud_White` | `**ingen bild**` | 0 | 0 | 0.0 |
| `PX_Bark` | `bark.png` | 22 | 198 | 128.8 |
| `PX_Barr` | `barr.png` | 44 | 616 | 692.2 |
| `PX_Cobblestone Brown` | `cobblestone_brown.png` | 91 | 546 | 22.9 |
| `PX_Cobblestone Grey` | `cobblestone_grey.png` | 115 | 690 | 29.5 |
| `PX_Cobblestone Ground` | `cobblestone_ground.png` | 0 | 0 | 0.0 |
| `PX_Cobblestone Mossy` | `cobblestone_mossy.png` | 89 | 534 | 23.5 |
| `PX_Dark Stone` | `dark_stone.png` | 6 | 36 | 3.7 |
| `PX_Dirt` | `dirt.png` | 0 | 0 | 0.0 |
| `PX_Dirt Stony` | `dirt_stony.png` | 2 | 12 | 280.0 |
| `PX_Grass` | `gras.png` | 30 | 2178 | 2079.4 |
| `PX_Grass Flowers` | `grass.png` | 0 | 0 | 0.0 |
| `PX_Hedge` | `hedge.png` | 38 | 3040 | 177.4 |
| `PX_Iron Riveted` | `metal_riveted.png` | 44 | 1532 | 11.5 |
| `PX_Ljus Varm` | `ljus_varm.png` | 2 | 12 | 5.2 |
| `PX_Lövverk` | `lov.png` | 55 | 4400 | 705.8 |
| `PX_Mossy Stone` | `mossy_stone.png` | 0 | 0 | 0.0 |
| `PX_Mörk Zon` | `mork_zon.png` | 1 | 6 | 742.2 |
| `PX_Purple Roof` | `tak_lila.png` | 98 | 588 | 43.3 |
| `PX_Ram` | `ram.png` | 33 | 198 | 54.7 |
| `PX_Sand Path` | `sand_path.png` | 0 | 0 | 0.0 |
| `PX_Skylt` | `skylt.png` | 8 | 48 | 15.1 |
| `PX_Slate Roof` | `tak_skiffer.png` | 280 | 1680 | 104.5 |
| `PX_Stone` | `mursten.png` | 378 | 5654 | 1282.8 |
| `PX_Stone Mossy` | `stone_wall_mossy_small.png` | 5 | 40 | 1237.8 |
| `PX_Terracotta Roof` | `tak_tegel.png` | 322 | 1932 | 131.9 |
| `PX_Tudor Plaster` | `puts.png` | 71 | 426 | 862.9 |
| `PX_Window Bright` | `window_narrow.png` | 0 | 0 | 0.0 |
| `PX_Window Warm` | `window_four_pane.png` | 0 | 0 | 0.0 |
| `PX_Wood` | `virke.png` | 207 | 1322 | 669.7 |
| `Sign_Text` | `**ingen bild**` | 0 | 0 | 0.0 |

Objekt utan platta alls (materialet saknar bildtextur) räknas inte i tabellen ovan; alla 31 material i filen står med.
