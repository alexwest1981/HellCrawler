# Kreditering — HellCrawler

Det här spelet står på andra människors arbete. Konsten, modellerna och ljuden nedan är gjorda av
andra utvecklare och konstnärer, och de används **med tacksamhet**. Varje paket har sin egen rad i
listan, med upphovsman, licens och — där licensen kräver det — den kreditrad som måste stå ordagrant.

Samma kreditering finns **i spelet**, under **TACK TILL** i startmenyn (rubriken översätts till alla
tretton språk; själva kreditraderna är egennamn och står på engelska i alla språk). Listan där läses
ur `game/data/credits.json`, så ett nytt paket är en datarad och inte en kodändring.

Licenstexterna ligger kvar i sina paketmappar under `game/assets/tredjepart/` — filnamnet står i
tabellen nedan. Det här dokumentet är sammanställningen; paketets egen fil är beviset.

---

## Översikt

| Paket | Upphovsman | Licens | I repot | Licensfil |
|---|---|---|---|---|
| Medieval Village MegaKit | Quaternius | CC0 1.0 | ja | `game/assets/tredjepart/quaternius_medieval_village/License_Standard.txt` |
| Fantasy Props MegaKit | Quaternius | CC0 1.0 | ja | `game/assets/tredjepart/quaternius_fantasy_props/License_Standard.txt` |
| KayKit Dungeon Pack | Kay Lousberg | CC0 1.0 | ja | `game/assets/tredjepart/kaykit_dungeon/License.txt` |
| KayKit RPG Tools Bits | Kay Lousberg | CC0 1.0 | ja | `game/assets/tredjepart/kaykit_rpg_tools/License.txt` |
| KayKit Fantasy Weapons Bits | Kay Lousberg | CC0 1.0 | ja | `game/assets/tredjepart/kaykit_fantasy_weapons/License.txt` |
| SBS Tiny Texture Pack 1 | Screaming Brain Studios | CC0 1.0 | ja | `game/assets/tredjepart/sbs_tiny_textures_1/License.txt` |
| SBS Tiny Texture Pack 2 | Screaming Brain Studios | CC0 1.0 | ja | `game/assets/tredjepart/sbs_tiny_textures_2/License.txt` |
| SBS Horror Texture Pack | Screaming Brain Studios | CC0 1.0 | ja | `game/assets/tredjepart/sbs_horror_textures/License.txt` |
| Super Pixel Effects Gigapack | Will Tice / unTied Games | egen licens, **kredit krävs** | ja | `game/assets/tredjepart/untied_super_pixel_effects/license.txt` |
| 32rogues | Seth Boyles | egen licens, **får ej vidaredistribueras** | **nej — undantagen** | (utanför repot) |
| 400 Sounds Pack | okänd upphovsman | ingen licensfil hittad | **nej — utanför git** | — se nedan. Används av `data/sfx.json` (M122); licensen är fortfarande obekräftad |
| Horror SFX Free | okänd upphovsman | ingen licensfil hittad | **nej — utanför git** | — se nedan |
| Item icons (1244 st, 16x16) | okänd upphovsman | ingen licensfil hittad | **nej — utanför git** | — se nedan |

Tröskeln är repots publika läge: **den som får ligga här måste licensen tillåta det.** Ett paket
vars licens förbjuder vidaredistribution ligger utanför git men används ändå i spelet — och tackas
för det. Ett tack är inte samma sak som vidaredistribution.

---

## CC0 1.0 — får ligga i repot

### Medieval Village MegaKit (Quaternius)
- **Licensfil:** `game/assets/tredjepart/quaternius_medieval_village/License_Standard.txt`
- **Citerat:**
  > `License:`
  > `CC0 1.0 Universal (CC0 1.0)`
  > `Public Domain Dedication`
  > `https://creativecommons.org/publicdomain/zero/1.0/`
- **Kredit:** inte obligatorisk. Upphovsmannen står ändå i krediteringen: *Models by @Quaternius*.
- **I repot:** `glTF/` (176 modeller, självförsörjande — modellerna bär sina egna texturer).
  **Valt bort:** `FBX/` och `OBJ/` (samma geometri i två format till; Godot läser glTF), `Preview.jpg`
  och den separata `Textures/`-mappen (textursats för andra motorer — modulerna ska ändå köras genom
  `tools/apply_pixel_textures.py` och få spelets egna plattor, se `hellcrawlers`-skillen).

### Fantasy Props MegaKit (Quaternius)
- **Licensfil:** `game/assets/tredjepart/quaternius_fantasy_props/License_Standard.txt`
- **Citerat:** samma licenstext som ovan (CC0 1.0, *Models by @Quaternius*).
- **I repot:** `glTF/` (94 modeller, självförsörjande).
  **Valt bort:** `FBX/`, `OBJ/`, `Preview_*.jpg` och `Textures/Normals-UnrealEngine/`
  (normal-kartor i Unreals konvention — fel motor och fel konvention i ett Godot-repo).

### KayKit Dungeon Pack (Kay Lousberg)
- **Licensfil:** `game/assets/tredjepart/kaykit_dungeon/License.txt`
- **Citerat:**
  > `License: (Creative Commons Zero, CC0)`
  > `This content is free to use in personal, educational and commercial projects.`
- **Kredit:** inte obligatorisk (*"If you wish to credit me you can do so by crediting \"Kay Lousberg,
  www.kaylousberg.com\" (this is not mandatory)"*). Han står i krediteringen ändå.
- **I repot:** `gltf/` (185 moduler, binär glTF) och `Characters/gltf/` (4 karaktärer + extra huvuden).
  **Valt bort:** `fbx/`, `dae/`, `obj/` (57 MB samma geometri i tre format till), `KayKit Brand
  Resouces/` (logotyper) och `Overview.png`/`Sample*.png` (översiktsbilder).

### KayKit RPG Tools Bits (Kay Lousberg)
- **Licensfil:** `game/assets/tredjepart/kaykit_rpg_tools/License.txt`
- **Citerat:** samma licenstext som Dungeon Pack ovan.
- **I repot:** `gltf/`, `Textures/` (modellerna refererar sina texturer — kontrollerat: 0 saknade
  referenser).
  **Valt bort:** `fbx/`, `fbx(unity)/`, `obj/`, `contents.png`, `*.url`.

### KayKit Fantasy Weapons Bits (Kay Lousberg)
- **Licensfil:** `game/assets/tredjepart/kaykit_fantasy_weapons/License.txt`
- **Citerat:** samma licenstext som Dungeon Pack ovan.
- **I repot:** `gltf/`, `Textures/`.
  **Valt bort:** `fbx/`, `fbx(unity)/`, `obj/`, `contents.png`, `*.url`.

### SBS Tiny Texture Pack 1 (Screaming Brain Studios)
- **Licensfil:** `game/assets/tredjepart/sbs_tiny_textures_1/License.txt`
- **Citerat:**
  > `All Screaming Brain Studios assets have been released under the CC0/Public Domain License.`
  > `You are free to use these assets in any and all projects, commercial or non-commercial, with no restrictions, and can be released with or without credit.`
- **I repot:** `512x512/` (125 texturer) + licensfilen.

### SBS Tiny Texture Pack 2 (Screaming Brain Studios)
- **Licensfil:** `game/assets/tredjepart/sbs_tiny_textures_2/License.txt`
- **Citerat:** samma licenstext som ovan.
- **I repot:** `512x512/` (160 texturer) + licensfilen.

### SBS Horror Texture Pack (Screaming Brain Studios)
- **Licensfil:** `game/assets/tredjepart/sbs_horror_textures/License.txt`
- **Citerat:** samma licenstext som ovan.
- **I repot:** `512x512/` (100 texturer, sju motivmappar) + licensfilen.

---

## Kredit krävs — får ligga i repot med krediten

### Super Pixel Effects Gigapack (Will Tice / unTied Games)
- **Licensfil:** `game/assets/tredjepart/untied_super_pixel_effects/license.txt`
- **Citerat:**
  > `2. If you use the contents of the asset pack zip file in a game or application product, please give attribution in the credits or wherever appropriate.`
  > `    "(Name of asset pack) - Will Tice / unTied Games"`
  > `    -- or --`
  > `    "Pixel Art Assets - Will Tice / unTied Games"`
  > `3. Commercial use and non-commercial use are both OK!`
  > `5. Use of the asset packs as AI training material is forbidden.`
- **KREDITRADEN SOM MÅSTE STÅ ORDAGRANT:**
  > **Pixel Art Assets - Will Tice / unTied Games**
- **Så här står den:** ordagrant i `game/data/credits.json` (fältet `kredit`) och därmed i spelets
  TACK TILL-ruta, och här i dokumentet. Den visas ihop med paketets namn och upphovsman, i alla
  tretton språk (kreditrader översätts inte).
- **Villkor att känna till** (samma fil, punkt 1 och 4): innehållet får inte läggas upp på en
  asset-store eller buntas med en spelmotor, och får inte säljas vidare. Att bunta det med *spelet*
  är uttryckligen tillåtet (*"Bundle the assets with your game: OK!"*). Om repot en dag ska publiceras
  på ett sätt som gör paketet hämtbart som **fristående tillgångar** (och inte som en del av spelets
  källkod) är det den punkten som ska läsas en gång till.
- **I repot:** `spritesheet/` (408 ark — den form Godot använder, med sin `spritesheet.txt` som bär
  rutan för varje ram) samt `license.txt`, `readme.txt`, `guide.txt`, `asset_list.txt`, `changelog.txt`.
  **Utanför git:** `PNG/` (5 685 enskilda rambilder). Paketets egen README säger att man väljer den ena
  ELLER den andra formen, så ramdumparna är en dublett av arken — arken är 5,5 MB, ramarna 45 MB.
  Regeln står i `.gitignore`; båda formerna ligger kvar på disk.

---

## Undantaget — används i spelet, får INTE ligga i repot

### 32rogues (Seth Boyles)
- **Licensfil:** paketets egen `LICENSE.txt` (finns i paketet, **inte** i det här repot).
- **Citerat ur licensen:**
  > `"32rogues" may be used in both non-commercial and commercial projects, excluding those relating to or containing non-fungible tokens ("NFT"), blockchain-related projects. It may not be used in conjunction with generative artificial intelligence projects or machine learning projects. You may modify it to suit your needs. You may not redistribute or resell it. Credit is not necessary, but very much appreciated.`
  > `Copyright 2024 Seth Boyles`
- **Varför det inte ligger i repot:** *"You may not redistribute or resell it."* Repot är publikt, och
  att lägga filerna här är vidaredistribution. Användning i spelet är tillåten, vidaredistribution är
  det inte — de två sakerna är olika, och det är därför paketet tackas utan att ligga här.
- **Kredit:** *"Credit is not necessary, but very much appreciated."* Han tackas i spelet:
  **32rogues — Seth Boyles.**
- **Skydd mot misstag:** `game/assets/tredjepart/32rogues/` står i `.gitignore` (med orsaken
  utskriven), så filerna kan inte committas av misstag om de läggs dit lokalt.

---

## Ingen licensfil hittad — används i spelet, ligger utanför git

De tre paketen nedan kom utan `license.txt`/`README`. Alex uppger att de är hämtade från itch.io
under en free-licens. Den uppgiften räcker för att **använda** dem i spelet, men den är ingen
licenstext — och utan en licenstext finns inget som tillåter vidaredistribution, vilket är precis vad
ett publikt repo är. **Alla tre togs därför ur git 14/10** (reglerna står i `.gitignore`, i samma form
som 32rogues-regeln): filerna ligger kvar på disk och spelet använder dem, men de publiceras inte.
Underlaget står skrivet i paketets `KÄLLA.txt` så att det går att ändra tillbaka i efterhand om källan
kan beläggas.

| Paket | Mapp | I repot | Vad som ligger där |
|---|---|---|---|
| 400 Sounds Pack | `game/assets/tredjepart/ljud_400/` | **nej — utanför git** | 400 wav i nio underkataloger (Card and Board, Weapons, …). **Används sedan M122:** `game/data/sfx.json` pekar på 9 av dem (kort, klick, mana, helande, rustning, fiendedöd, kortval, boss). Ligger paketet inte där tiger de ljuden — spelet faller tillbaka på de egna `assets/sfx/`, och `tests/test_ljud.gd` skriver ut hur många som saknas |
| Horror SFX Free | `game/assets/tredjepart/ljud_horror/` | **nej — utanför git** | 149 wav i sex underkataloger (Ambient, Monsters & Ghosts, …) — **en fil är utelämnad**, se nedan |
| Item icons | `game/assets/tredjepart/ikoner_1244/` | **nej — utanför git** | 1244 png, 16x16 |

**En fil är utelämnad ur Horror SFX Free:** `Ambient/Suburban Neighborhood_morning.wav`,
141,6 MB (2 kanaler, 48 kHz, 16 bit, 773 s). GitHub tar inte emot en fil över 100 MB, så
den kan inte ligga i repot — och 141 MB rå PCM hade dessutom kostat 141 MB RAM i spelet,
eftersom Godot importerar wav i minnet. Anledningen och kommandot som kodar om den till OGG
står i `game/assets/tredjepart/ljud_horror/KÄLLA.txt`; originalfilen ligger kvar i paketet
utanför repot.

Upphovsmannen är okänd för alla tre — det finns ingen författarsträng i filerna, ingen URL och ingen
metadata. Krediteringen skriver därför *unknown artist* i stället för ett namn; det är ett ärligt svar,
inte en platshållare.

---

## Övrigt som spelet bygger på

Spelets egen konst (kort, fiender, hjältar, byn, plattorna) är Alex' egen. Byns 3D-modell är hans egen
Blender-scen exporterad till glTF. Schablonerna i `game/ui/*.gdshader` bär sina upphovsmän i
filhuvudet där krediten hör hemma. Den här filen handlar om de **externa paketen**.

## Texturpaketet — Texture Pack by Lynocs (CC0 1.0)

Väggytorna i `game/assets/tiles/<tema>/wall{,_super_0..3}{,_n,_orm}.png` klipps sedan 15/10 ur
**Texture Pack by Lynocs** — https://lynocs.itch.io/texture-pack — med `tools/gen_ytor_paket.py`.
Originalen ligger utanför git i `~/Downloads/Textures`.

Licensen är **CC0 1.0** (verifierad på paketets sida 15/10): fri att använda i privata och
kommersiella projekt, även att ändra, med ett undantag — texturena får inte säljas vidare som de är.
Credit "would be nice but is not necessary"; den står här ändå. Paketet är AI-assisterat och gjort av
Lynocs, som släppt 536 texturer med diffuse, AO, edge, height, metallic, normal och smoothness.
