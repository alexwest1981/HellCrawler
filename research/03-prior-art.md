# 03 — Prior art: befintlig öppen källkod och färdiga ramverk att bygga på

**Datum:** 2026-09-19
**Projekt:** Referensspelet — förstapersons rutnätsbaserad dungeon crawler (Wizardry / Eye of the Beholder / Legend of Grimrock) i pixelart, med turordningsbaserad kortstrid och roguelite-deckbuilding.
**Syfte:** Inventera vad som redan finns färdigt att låna, i stället för att bygga allt själva.

---

## 0. TL;DR — rekommenderad återanvändning

| Lager | Vad vi använder | Licens | Egen kod kvar |
|---|---|---|---|
| Motor | **Godot 4.x** (GDScript) | MIT | 0 |
| Rutnät + first-person-rörelse | Egen tunn GDScript (stulen arkitektur från `uheartbeast/3d-dungeon` + `DungonCrawler`) + **GridMap** | MIT / CC0 | ~200 rader |
| Kortstridslogik | Egen headless-logik, arkitektur lånad från **DesirePathGames/Slay-The-Robot** (MIT) eller **guladam/deck_builder_tutorial** (MIT) | MIT | ~600–1000 rader |
| Kort-UI (hand, drag & drop, högar) | **chun92/card-framework** (MIT) | MIT | 0 |
| Dungeongenerering | Algoritm från **glouw/dungen** (MIT) / BSP + cellular automata, porterad | MIT | ~200 rader |
| FOV, pathfinding, RNG-hjälpare | **python-tcod / rot.js / bracket-lib** som algoritmreferens | BSD / MIT | ~100 rader |
| Grafik | **Kenney** (CC0), **0x72 Dungeon Tileset II** (CC0), **KayKit Dungeon** (CC0, 3D-moduler) | CC0 | 0 |
| Font / ikoner / ljud | Kenney (CC0), game-icons.net (CC BY 3.0), sfxr/jsxfr (MIT) | — | 0 |
| Dialog/narrativ | **nathanhoad/godot_dialogue_manager** (MIT) — om/när dialog behövs | MIT | 0 |
| Fiende-AI | **LimboAI** (MIT) — först när fiendebeteendet blir komplext | MIT | 0 |
| Roguelite-meta (karta, relics, butik, save, seed) | Byggs själva. Ingen mogen lib finns. | — | ~400 rader |

**Huvudfynd:** det finns **ingen** färdig öppen källkods-klon av exakt vår kombination (förstapersons rutnätsblobber + turordningskort + roguelite). Närmaste träff är en övergiven prototyp (`kaandesu/deck-crawler`, GPL-3.0, Go+Raylib, bara maze/rörelse klart). Delarna finns däremot var för sig och är mogna, med bra licenser. Rätt strategi är **Godot 4 + 3 små MIT-addons + CC0-tillgångar**, inte att bygga motor, kort-UI eller tillgångar från grunden.

**Undvik (licensfällor):** allt AGPL i produktionskoden (`db0/godot-card-game-framework`, `oskarrough/slaytheweb`, `JavierIslas/Card-Combat-System` utan köpt licens), allt GPL (`Card-Forge/forge`, `Cockatrice`), projekt **utan licens** (`huement/cotu`, `MutantStargoat/raydungeon`, `davidxn/phobianodyssey` — läsbar kod, inte återanvändbar kod), samt Grimrocks och Slay the Spires **assets** (får bara användas inuti respektive spel, aldrig i en egen titel).

---

## 1. Metod och avgränsning

* Genomsökning via webbsök (GitHub, Godot Asset Library/Store, itch.io, RogueBasin, dmweb, forum) plus direkta GitHub-API-uppslag för stjärnor, licens, språk och senaste push.
* Siffror märkta med ★/licens är hämtade från GitHub-API:t vid analystillfället. En del av de sista uppslagen blockerades av GitHubs oautentiserade rate limit och är markerade "ej verifierad" i stället för gissade.
* "Prior art" = kod vi kan läsa, kopiera eller länka in. Ren inspirationskälla (kommersiella spel, wiki-sidor) är markerad som sådan.
* Avgränsning: rapporten bedömer **återanvändbarhet och licens**, inte kvalitet i sig.

---

## 2. Motorval — rung 1 på stegen

| Alternativ | Fördel | Nackdel | Dom |
|---|---|---|---|
| **Godot 4.x** (MIT, 117 450★, aktiv) | Inbyggd `GridMap` + `MeshLibrary`, inbyggd kort-/UI-scen, integer scaling + låg basresolution för pixelart, gratis, MIT tillåter stängd källkod | GDScript-prestanda vid tusentals kortobjekt (lösbart med data-resurser, inte noder per kort) | **Väljs** |
| Unity | Störst ekosystem, `DeckBuilderRoguelikeEngine` m.fl. finns | Licensvillkor för kommersiell release, tyngre för 2D-pixelart, överdrivet för grid+2.5D | Nej |
| Bevy / Rust | Snabbt, bra ECS | Få färdiga kort-/UI-addons, mycket egen infrastruktur | Nej |
| Egna raycasters (`Arthur`, `raydungeon`, PHP-motorn m.fl.) | Lärorikt, litet | Vi skriver alla editor-verktyg, UI, animation, ljud själva | Nej (rung 7) |
| LÖVE / Pygame + rot.js/python-tcod | Snabb prototyp av *striden* | Ingen 3D-vy, inget färdigt UI | Bara för balansprototyp |

Godot 4 har dessutom `GridMap`, `Resource`-baserade datafiler, `Tween` (för stegvis rörelse), `SubViewport`, inbyggd CSV-lokalisering och `RandomNumberGenerator` med seed — allt vi annars skulle behövt bibliotek för.

**Pixelart-looken i Godot** (inga plugins behövs): låg basupplösning (t.ex. 320×240 eller 480×270) + `Display/Window/Stretch` i *viewport*-läge + `Scale Mode: integer`, texture filter *nearest* överallt, och enkla unshaded/vertex-lit material. Se GDQuests guide "Setting up pixel art graphics in Godot 4" och Godots multi-resolution-dokumentation. Vill man ha mjuk sub-pixel-kamera finns dokumenterade lösningar (notkey.studio-artikeln) — men för en *stegvis* rutnätsblobber är hackig, diskret rörelse rätt känsla, så problemet behöver inte lösas.

---

## 3. Förstapersons rutnätsblobber — befintlig kod

Detta är den del där mest finns att låna. Rangordnat efter användbarhet:

### 3.1 Direkt användbara (permissiv licens)

| Repo | Licens | Språk | Vad den ger | Hur vi använder den |
|---|---|---|---|---|
| `Rebelion-Board-game/DungonCrawler` (42★) | **CC0** | GDScript, Godot 4 | GridMap-baserad dungeon-skapelse + spelarrörelse; port av `uheartbeast/3d-dungeon` | Startpunkt att kopiera rakt in |
| `uheartbeast/3d-dungeon` (126★) | **MIT** | GDScript | Originalet: tile-map → 3D-cell, rutnätsrörelse | Läs som referens, kopiera fritt |
| `benc-uk/melkors-oubllette` (7★) | **MIT** | GDScript, Godot | Dungeon Master/EotB-stil: dörrar (trä/portcullis), brytare med action-system, dynamisk belysning, facklor som brinner ut, egna kartor | Arkitektur för interagerbara celler + ljus |
| `antzGames/Godot-A-Star-Pathfinding-for-Gridmaps` (21★) | **MIT** | GDScript | A* + editor-visualisering för `GridMap` | Om fiender ska patrullera i rutnätet |
| `DanchieGO/EnhancedGridMap` (21★) | **MIT** | GDScript | Cell-tillstånd, **multi-floor**, A* med kostnader, slumpgenerering, editor-dock | Om vi vill ha flera våningar och cellmetadata |
| `kaandesu/deck-crawler` (3★, senast 2024) | **GPL-3.0** | Go + Raylib | *Exakt vår pitch*: first-person dungeon crawl + deckbuilding. Bara maze + rörelse implementerat | **Läs för design/roadmap, kopiera inte kod** (GPL) |

### 3.2 Läsvärda men licensmässigt oanvändbara

| Repo | Status | Varför intressant |
|---|---|---|
| `huement/cotu` (1★) | **Ingen licens** | Wizardry/SMT-inspirerad blobber i Godot 4: rutnätsrörelse, 90°-svängar, partystrid. Läs för struktur, kopiera inget. |
| `jhavatar/kubriko-dungeon-crawler` (0★) | MIT (Kotlin/Compose) | **Bästa arkitekturbeskrivningen jag hittade**: separata libs för `tilemap` (TileMap, GridPosition, Facing, DoorState) och `dungeon-crawler` (renderer som projicerar grid-position + möbler/dörrar/monster till draw-commands via "fixed-frustum slot-algoritm med angular occlusion buffer"). Hela simulationen körs på **en konfigurerbar turn-engine som kan växla mellan realtid och turordning**. Värt att efterlikna 1:1 i GDScript. |
| `davidxn/phobianodyssey` (2★) | Ingen licens | GZDoom-baserad rutnätscrawler med slumpmässiga encounters och inventarium. |
| `MutantStargoat/raydungeon` | **Ingen licens**, "experiment" | Distance-field ray-marching-renderare för grid-blobbers. Elegant, men onödigt för oss. |
| `andreasganje/dungeon-crawler` (14★, PHP) | MIT | Klassisk renderare: drar färdigrenderade vyer per djup-slits + automap. Bra referens för 2.5D-metoden. |
| `rocket-boots/dungeon-boots` (Three.js) | Ej verifierad | Ramverk för rutnätsbaserade web-crawlers: instanssteg, 90°-svängar. |

### 3.3 Klassiska blobber-motorer att studera (fri programvara/freeware, oklar eller stängd licens)

* **DSB (Dungeon Strikes Back)** — Lua-skriptbar klon av Dungeon Master/Chaos Strikes Back. Bästa exemplet på hur långt man kan komma med *data + skript* i stället för hårdkodade rum. Se dmweb.free.fr/community/clones.
* **CSBwin** och **DMJava** — äldre kloner, källa till Dungeon Masters exakta rutnätsregler (monsterrörelse-tickning, dörrtillstånd, säckar/objektstackar).
* **Legend of Grimrock 1/2 dungeon editor + skriptreferens** (grimrock.net/modding): innehåller dokumenterat **hur ett blobber-dungeon byggs** (nivåer, connectors, scripting med Lua, kombolås, spar-variabler). Assets är Almost Humans IP och får bara användas i Grimrock-mods — **dokumentationen får däremot läsas fritt som designspecifikation.**

### 3.4 Renderingsstrategi: 3D-GridMap eller 2.5D-slitsar?

Två beprövade vägar, båda pixelartsvänliga:

1. **Riktig 3D med GridMap** (Godot): väggar/golv/tak som moduler i en `MeshLibrary`, låg-upplöst texturatlas, `Sprite3D` med billboard för monster. Rekommenderas — vi får belysning, occlusion och dörranimation gratis.
2. **2.5D-slits-rendering** (Eye of the Beholder/`raydungeon`/PHP-motorn/kubriko): rendera 2D-bilder per djup-slits, med "angular occlusion buffer" för att avgöra vad som syns. Kräver ingen 3D-motor alls och är extremt pixelart-troget, men varje ny vy/geometri är ny konst.

För oss: alternativ 1 för dörrar, ljus och monsterbillboards; håll dörrarna som riktiga noder så vi senare kan byta den visuella representationen.

---

## 4. Rutnät, turordning och strid i rutnät

### 4.1 Rutnätsrörelse (permissiva ramverk)

| Repo/asset | Licens | Kommentar |
|---|---|---|
| `MeshLabDev/Grid-Tactics-Foundation` (3★) | **MIT** | 2D-plug-and-play: A*, räckvidds-flood-fill runt väggar/enheter, klick-för-att-flytta, waypoints, data-drivna enheter via `Resource`. Innehåller *medvetet inte* strid/turn-ordning. Testad på Godot 4.6, headless-tester med. |
| `zapturk/Indie-Game-Components` (10★) | **MIT** | Komponenter: `GridMoverComponent` (tile-till-tile med tween), `GridFollowerComponent` (party-follow), health/mana. Signals-first, ingen boilerplate. |
| Godot Asset Library: **GBM2K Framework** | — | RPG Maker 2003-lik rutnätsrörelse i 2D (input-prioritering, gånganimation, NPC:er). Nyttig om vi vill ha en 2D-vy någonstans (karta/overworld). |
| Godot Asset Library: **GMODY Turn-Based Strategy Framework** | — | Grid rules, turn/initiative, ability-datamodell, exempel-AI, liten kampanj. Bra startstruktur om man vill slippa designa turordningen själv. |
| `aroelke/godot-tbs-framework` | ej verifierad (C#) | Faktioner, allianser, objectives, behaviors för CPU-enheter, terrängkostnader per unit-class. Bara relevant om vi väljer C#. |

### 4.2 Turordning / tidssteg

Ingen lib behövs, och `kubriko`-projektet visar rätt mönster: **en enda turn-engine** som hela simulationen (spelare, monster, dörrar, brytare, props) går igenom. Antingen:

* **Energisystem/tick** (klassikern, se RogueBasin "Turn scheduling"): varje aktör har energi, handlingar kostar, högsta energi får agera. Passar om rörliga saker ska reagera på spelarens steg (patruller, facklor som brinner).
* **Initiativkö för striden** (vår kortstrid): en kö av aktörer, kortstriden som tillståndsmaskin (drag → spela → fiendeintents → end turn).

`libtcod`/`python-tcod` (BSD-3/BSD-2) och `rot.js` (BSD-3) innehåller färdiga schedulers *och* är licensmässigt fria att översätta idéer ifrån. `amethyst/bracket-lib` (RLTK, MIT) är Rust-motsvarigheten.

### 4.3 Fiende-AI i strid

* `limbonaut/limboai` (**MIT**, 2 978★) — behavior trees + tillståndsmaskiner för Godot 4. Bra när fienden ska ha intents som beror på handen/positionen.
* Börja utan: en intent-tabell per fiende räcker långt (Slay the Spire-modellen). **Skjut upp LimboAI tills fienden faktiskt behöver det.**

---

## 5. Kortstrid och deckbuilding — den mest återanvändbara delen

### 5.1 Färdiga ramverk

| Projekt | Licens | ★ | Vad den ger | Bedömning |
|---|---|---|---|---|
| **`DesirePathGames/Slay-The-Robot`** | **MIT** | 280 | Godot 4-ramverk för roguelike-deckbuilders: card packs (kort grupperas i packar, tusentals kort utan manuella listor), actions med timers, sync/async-actions, animationer kopplade till fiendeattacker/kort, **3-aktstruktur + ascensions + custom run-modifiers**, run start-options, **deterministisk RNG**, wiki + jämförelsespreadsheet mot Slay the Spire. Aktiv (push 2026-09-19) | **Bästa enskilda träffen i hela inventeringen.** MIT ⇒ kan vändas in direkt eller plockas isär. Läs "translation spreadsheet" för att se hur STS mappas. |
| `guladam/deck_builder_tutorial` | **MIT** | 452 | Godot 4-tutorialprojektet som de flesta andra kloner bygger på: kort som `Resource`, `CardPile`, `Effect`, `Stats` (player/enemy-subklasser), `Intent` för fiendeplaner | Bästa pedagogiska arkitekturen. `GeWuYou/Slay-the-Spire-Like` är en C#-port av exakt denna. |
| `chun92/card-framework` | **MIT** | 376 | Lättviktigt toolkit för 2D-kortspel i Godot: hand som automatiskt arrangeras om, drag & drop inom/mellan containrar, flera händer och högar | **Ta den för UI:t** — det är den biten som är tråkig och redan löst. |
| `JavierIslas/Card-Combat-System` | **AGPL-3.0** el. köpt kommersiell licens ($50) | 12 | Headless, domänagnostisk stridslogik för Godot 4.6+: turn-FSM, mana, draw, attack/block med simultan skaderesolution, pluggbar AI, 14 nyckelordsförmågor (TAUNT, LIFESTEAL, BATTLECRY…). Kort-metadata är fria dictionaries; allt spelspecifikt injiceras via `Callable` | **Bra design att kopiera**: agnosticism-via-injektion, inga `if keyword ==`-grenar i motorn. AGPL ⇒ antingen betala $50 eller skriv eget (~600 rader) med samma mönster. |
| `db0/godot-card-game-framework` | **AGPL-3.0** | 1 396 | Populäraste Godot-kortramverket: färdiga scener/klasser + kraftfull skriptmotor för kortregler | AGPL diskvalificerar den för stängd källa. Läs för idéer, använd inte. |
| `oskarrough/slaytheweb` | **AGPL-3.0** | 314 | Slay the Spires kärnlogik implementerad i JS med tester, aktivt underhållet | **Utmärkt referens för balanssiffror och effektarkitektur** (energi, relics, kortuppgraderingar). AGPL ⇒ läs, kopiera inte. |
| `Card-Forge/forge` | GPL-3.0 | 2 710 | 28 000+ kort i en regelmotor — kort som *dataskript* (DSL) i stället för kod | Den enda riktigt skalbara lösningen för många kort. GPL ⇒ vi tittar på DSL-designen (kort = data + effektlista) men implementerar egen tolk (~300 rader). |
| `Cockatrice/Cockatrice` | GPL-2.0 | 1 835 | Virtuellt bräde, ingen regelkörning | Irrelevant för oss. |
| `K-mohameduuu/DeckBuilderRoguelikeEngine` (Unity, 13★) och `Denizkusu/DeckBuilder` | — | — | Ytterligare Godot/Unity-tutorialprojekt | Bara om vi väljer Unity. |

### 5.2 Kort som data — den enda arkitekturfrågan som spelar roll

Alla mogna lösningar gör samma sak: **kortet är data, effekten är kod som injiceras.** Godot-varianten:

* Kort som `Resource` (`.tres`) eller JSON: id, kostnad, typ, mål, keywords, metadata.
* Effekter som `Callable`/skriptreferens per nyckelord, registrerade i en ordbok — inte en `match`-sats som växer med varje kort.
* Deterministisk RNG: **en seedad ström per domän** (strid / dungeon / belöningar) så en run går att spela upp och buggrapportera. Slay the Robot gör detta och har rätt resonemang kring varför.

Detta är ~200 rader egen kod och är hela skillnaden mellan "100 kort är kul" och "100 kort är ounderhållbart". **Bygg inte ett eget DSL** (Card Forge-nivå) innan korthandeln passerat ~200 kort.

---

## 6. Dungeongenerering och algoritmer

| Källa | Licens | Vad |
|---|---|---|
| `glouw/dungen` (55★) | **MIT** | Genererar grafbaserade grottdungeons (Delaunay-triangulering + MST), C. Liten och portabel — läses på en kvart, portas till GDScript på en dag. |
| `libtcod/libtcod` (1 227★, BSD-3) / `libtcod/python-tcod` (477★, BSD-2) | BSD | BSP-rum, tunnlar, FOV (synfält), A*/Dijkstra, brus, name generator, **turn scheduler**. Referensimplementationer för nästan allt vi behöver i rutnätslogik. |
| `ondras/rot.js` (2 717★) | BSD-3 | Samma sak i JS: hex-stöd, FOV, ljussättning, BSP/cellular/maze-generatorer, asynkron motor. Bra för att jämföra algoritmer. |
| `amethyst/bracket-lib` (RLTK, 1 691★) | MIT | Rust-motsvarigheten. |
| `JnyJny/DungeonGenerator` | ej verifierad | Python, grafbaserad generator (bloggen "Dungeon generation — from simple to complex" beskriver algoritmen steg för steg). |
| `marukrap/RoguelikeDevResources` | kuraterad lista | Samlar alla generatorvarianter (BSP, cellular automata, graf, TinyKeep-metoden). |
| `slsdo.github.io/procedural-dungeon` | demo | Interaktiv jämförelse av generatorer. |

**Rekommendation:** låna *algoritmen* (BSP för rum+kartografisk logik, cellular automata för grottor, graf/MST för "rum-måste-nås-i-ordning"), inte koden. 150–250 rader GDScript räcker, och vi undviker en beroendekedja. För ett *handskapat* roguelite-dungeon (som Grimrock/Etrian) är generatorn dessutom bara en krydda — lägg den efter att rörelse + strid fungerar.

---

## 7. Meta-lagret (karta, relics, butik, save, seed) — bygg själva

Inget moget bibliotek finns, och det är rimligt: det är spelspecifikt.

* **Karta över rum/våningar med val:** enkel graf + viktad slump; Slay the Spire-strukturen är dokumenterad i detalj i communityn (se `slaytheweb`-koden och STS-referensspreadsheet).
* **Save/load:** Godot inbyggt — `ResourceSaver`/`JSON` + `user://`. Ingen addon. Versionera saven från dag ett (fältet `save_version`), annars blir varje balansändring en supportärende.
* **Determinism:** seedad `RandomNumberGenerator`, en ström per domän (se 5.2). Krävs för bugg-rapporter och för "daily run"-läget.
* **Lokalisering:** Godots inbyggda CSV-översättningar. Bygg in svenska/engelska från början (gratis, sparar en omskrivning).

---

## 8. Tillgångar: grafik, ljud, text, ikoner

| Resurs | Licens | Innehåll |
|---|---|---|
| **Kenney — Tiny Dungeon** (130 sprites, 16×16) | **CC0** | Dungeon-tiles, vapen, items, karaktärer + Tiled-exempelkarta |
| **Kenney — Roguelike Caves & Dungeons** (520 filer) / **Roguelike/RPG pack** (1 700 filer, 16×16) | **CC0** | Grottor/gruvor respektive RPG-tiles, knappar/paneler (perfekt för kort-UI) |
| **0x72 — Dungeon Tileset II** (+ Niji-utökning) | **CC0** | 16×16 fantasy-dungeon: monster, hjältar, dörrar, facklor (animerade), palett + Aseprite-arkiv |
| **KayKit — Dungeon Pack (Remastered)** | **CC0** | **200+ modulära 3D-delar** (väggar, golv, trappor, dörrar, props, facklor tal. inkl. `.gltf`) — idealisk för Godots `MeshLibrary`/`GridMap`. Enda CC0 3D-dungeonkitet av den här kvaliteten jag hittade. |
| **Kenney — Modular Dungeon Kit** (40 filer, 3D) | **CC0** | Alternativ/komplement till KayKit |
| **Kenney — Playing Cards Pack** | **CC0** | Kortlekar att bygga kortramar/ikoner ovanpå |
| **game-icons.net** | **CC BY 3.0** (kräver attribution) | ~4 000 SVG-ikoner — perfekt för kortikonografi (attributionen löses i en credits-skärm) |
| **Kenney Game Icons / UI-paket** | **CC0** | Alternativ när vi inte vill ha CC BY |
| **Fonts:** m5x7/m6x11 (Daniel Linssen), Monogram, Kenney-fonts | fria/CC0 | Pixelfonter för korttext och UI |
| **Ljud: jsfxr / sfxr** (MIT) och **Kenney Audio** (CC0) | MIT/CC0 | Generera/protokollföra kortljud, steg, dörrar |
| **OpenGameArt CC0-samlingen**, `jdsherbert` Tabletop SFX, `olexmazur` Fantasy Card Game SFX | CC0 (verifiera per fil) | Bords/kortljud |

**IP-varning (viktig):**
* **Legend of Grimrocks och Slay the Spires assets** får användas i moddar till respektive spel — inte i vår egen titel. Läs licenssidorna innan något kopieras "bara som placeholder".
* Projektnamnet antyder vampyr-tema: undvik **Referens: The Masquerade**-specifik terminologi (Clans, Disciplines, "Kindred") och varumärket. Egen mytologi är billigare än en varumärkesprocess.

---

## 9. Designförebilder för kombinationen kort + rutnät

Det här är den enda delen där kommersiella spel är den bästa källan, och det finns **en dokumenterad fallgrop**:

* **Fallgropen:** när förflyttning ligger i leken blir en hand utan rörelsekort katastrofal — värre än en vanlig dålig hand. (Diskussionen på r/gamedesign "Why deckbuilding and grid tactics usually fight each other" är explicit om detta.)
* **Beprövade lösningar, i tur och ordning:**
  1. **Garanterad rörelseresurs utanför leken** — ett gratis move per tur (Marvel's Midnight Suns: en hjälte får flytta fritt varje runda; Gordian Quest: action points kan användas för att flytta; Alina of the Arena: ett move som måste användas först). Midnight Suns har dessutom **ingen rutnätsgrid** — position manipuleras via attacker, och Firaxis valde bort XCOM:s träffchans/cover helt.
  2. **Varje kort har två lägen** — "attackera 5 *eller* flytta 2 framåt" (föreslaget i samma tråd).
  3. **Varje kort har en svag default-action** (svag attack / svag förflyttning) som alltid finns.
  4. **Card Hunter-modellen**: utrustning genererar korten, och man *garanterar* ett eller två rörelsekort i utdragen.
* **Fights in Tight Spaces** är ankaret för "kort + rutnät": knuffar, väggar och adjacency gör att en svag attack blir stark om den flyttar dig rätt. **Trials of Fire** (turordning + rutnät + deck) och **Wildfrost** (lanes, frontline, countdowns) är de andra två att studera.

**Slutsats för oss:** förstapersons-rutnätet gör redan förflyttning till en *positionsfråga*, inte en kortfråga. Den enklaste design som håller är: **gå/backa/vrid = gratis speltangenter (utforskarläget); kort spelas i stridsläget där rutnätet handlar om avstånd, linje, höjd och knuff.** Om rörelse ändå ska in i leken — välj lösning 1 eller 2 ovan, inte 0.

---

## 10. Licensriskmatris (för stängd/kommersiell release)

| Licens | Exempel i rapporten | Får användas? |
|---|---|---|
| **CC0 / public domain** | Kenney, 0x72, KayKit, `DungonCrawler` | Ja, fritt, ingen attribution krävs |
| **MIT** | Godot, Slay-The-Robot, chun92/card-framework, Grid-Tactics-Foundation, EnhancedGridMap, Dialogue Manager, LimboAI, dunge, bracket-lib, uheartbeast/3d-dungeon, melkors-oubllette | Ja — behåll copyright-raden i en tredjepartsfil |
| **BSD (2/3-clause)** | libtcod, python-tcod, rot.js | Ja — behåll copyright-raden |
| **CC BY** | game-icons.net | Ja **med attribution** |
| **GPL-2.0/3.0** | Card-Forge, Cockatrice, Barony, Dungeon Crawl Stone Soup | Nej för stängd källa. Ideer/design får studeras. |
| **AGPL-3.0** | db0/godot-card-game-framework, slaytheweb, Card-Combat-System | Nej för stängd källa (AGPL kräver källkod även för nätverkstjänst). Card-Combat-System säljs med kommersiell licens ($50) — den vägen är öppen. |
| **Ingen licens** | cotu, raydungeon, phobianodyssey | **Nej.** Utan licens är allt "alla rättigheter förbehållna"; läs koden för att lära, skriv egen. |
| **Spelassets med egna villkor** | Grimrock, Slay the Spire | Nej, aldrig. |

---

## 11. Rekommenderad plan (vad vi INTE bygger)

1. **Motor: Godot 4 + GDScript.** (Inte Unity, inte egen raycastare.)
2. **Blobber-delen:** kopiera `DungonCrawler` (CC0) → byt ut `GridMap`-mesherna mot KayKit/CC0-moduler → sätt basupplösning 320×240/480×270, integer scaling, nearest filter → lägg billboard-`Sprite3D` för monster. Stulen arkitektur från `kubriko` (turn-engine som driver spelare, monster, dörrar, brytare).
3. **Kortstriden:** läs `Slay-The-Robot` (MIT) och `guladam/deck_builder_tutorial` (MIT) i sin helhet, plocka `chun92/card-framework` (MIT) för handen/högarna. Bygg stridslogiken headless (~600–1000 rader) med kort-som-data + injicerade effekter och seedad RNG.
4. **Dungeon:** enkel BSP-generator (~200 rader). Ingen generator alls i v1.
5. **Meta:** egen, minimal — seed, save-version, en karta, en butik, relics som passiva effekter.
6. **Tillgångar:** Kenney + 0x72 (2D) och/eller KayKit (3D), Kenney-ljud, pixelfont. Allt CC0 ⇒ ingen attributionsträda, ingen jurist.
7. **Skjut upp:** LimboAI, Dialogue Manager, eget kort-DSL, multipla våningar, dynamisk belysning, lokalisation till fler språk än sv/en.

**Backloggade risker att bevaka:** (a) licensrevision av varje inkopierad fil, (b) AGPL-fällan ovan, (c) rörelse-i-leken-designfällan (avsnitt 9), (d) savens versionshantering.

---

## 12. Källförteckning (urval)

**Motorer & ramverk**
- Godot Engine — https://github.com/godotengine/godot (MIT)
- DesirePathGames/Slay-The-Robot — https://github.com/DesirePathGames/Slay-The-Robot (MIT)
- guladam/deck_builder_tutorial — https://github.com/guladam/deck_builder_tutorial (MIT)
- chun92/card-framework — https://github.com/chun92/card-framework (MIT)
- JavierIslas/Card-Combat-System — https://github.com/JavierIslas/Card-Combat-System (AGPL / $50 kommersiell)
- db0/godot-card-game-framework — https://github.com/db0/godot-card-game-framework (AGPL)
- oskarrough/slaytheweb — https://github.com/oskarrough/slaytheweb (AGPL)
- Card-Forge/forge — https://github.com/Card-Forge/forge (GPL-3.0)

**Blobber / first-person rutnät**
- Rebelion-Board-game/DungonCrawler — (CC0) https://github.com/Rebelion-Board-game/DungonCrawler
- uheartbeast/3d-dungeon — (MIT) https://github.com/uheartbeast/3d-dungeon
- benc-uk/melkors-oubllette — (MIT) https://github.com/benc-uk/melkors-oubllette
- jhavatar/kubriko-dungeon-crawler — (MIT) https://github.com/jhavatar/kubriko-dungeon-crawler
- huement/cotu — (ingen licens) https://github.com/huement/cotu
- kaandesu/deck-crawler — (GPL-3.0) https://github.com/kaandesu/deck-crawler
- MutantStargoat/raydungeon — (ingen licens) https://github.com/MutantStargoat/raydungeon
- Grimrock-modding & skriptreferens — https://www.grimrock.net/modding
- Dungeon Master-kloner (DSB, CSBwin, DMJava) — http://dmweb.free.fr/community/clones/ och https://dmwiki.atomas.com

**Rutnät, turordning, algoritmer**
- MeshLabDev/Grid-Tactics-Foundation — (MIT) https://github.com/MeshLabDev/Grid-Tactics-Foundation
- DanchieGO/EnhancedGridMap — (MIT) https://github.com/DanchieGO/EnhancedGridMap
- antzGames/Godot-A-Star-Pathfinding-for-Gridmaps — (MIT) https://github.com/antzGames/Godot-A-Star-Pathfinding-for-Gridmaps
- zapturk/Indie-Game-Components — (MIT) https://github.com/zapturk/Indie-Game-Components
- libtcod / python-tcod / rot.js / bracket-lib — https://github.com/libtcod/libtcod, /libtcod/python-tcod, /ondras/rot.js, /amethyst/bracket-lib
- glouw/dungen — (MIT) https://github.com/glouw/dungen
- RoguelikeDevResources — https://github.com/marukrap/RoguelikeDevResources
- Godot-integer scaling & pixelart — https://www.gdquest.com/library/pixel_art_setup_godot4/

**Narrativ/AI (senare)**
- nathanhoad/godot_dialogue_manager — (MIT) https://github.com/nathanhoad/godot_dialogue_manager
- limbonaut/limboai — (MIT) https://github.com/limbonaut/limboai

**Tillgångar**
- Kenney — https://kenney.nl/assets (CC0)
- 0x72 Dungeon Tileset II / Niji Extended — https://nijikokun.itch.io/dungeontileset-ii-extended (CC0)
- KayKit Dungeon Pack — https://kaylousberg.itch.io/kaykit-dungeon-pack (CC0)
- game-icons.net — https://game-icons.net (CC BY 3.0)
- OpenGameArt CC0-samling — https://opengameart.org/content/cc0-resources

**Designreferenser (kommersiella, endast inspiration)**
- Card Hunter (utrustning → kort, garanterade rörelsekort)
- Fights in Tight Spaces, Trials of Fire, Wildfrost, Gordian Quest, Alina of the Arena
- Marvel's Midnight Suns — https://blog.playstation.com/2022/10/26/marvels-midnight-suns-super-heroic-turn-based-combat-and-card-tactics-explained
- Diskussion om deckbuilding + grid-taktik — https://www.reddit.com/r/gamedesign/comments/1pu5q5n/

---

### Öppna poster / att verifiera själv
1. Licenserna för `rocket-boots/dungeon-boots`, `JnyJny/DungeonGenerator` och `aroelke/godot-tbs-framework` — GitHub-API:t svarade rate limitat vid sista kontrollen; verifiera i repona innan något inkorporeras.
2. Grimrocks "Asset Usage Terms" och Slay the Spires moddingvillkor — läs originaltexten innan något ens används som temporär placeholder.
3. `Slay-The-Robot`s wiki/spreadsheet är den snabbaste vägen till att förstå hur en etablerad deckbuilder-struktur ser ut i praktiken — rekommenderas som läsning före första stridskoden.
