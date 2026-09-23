# Referensspelet — hur spelet är byggt och vad en egen version kräver

Sammanställd 2026-09-19. Allt nedan är antingen **mätt** (källa angiven) eller märkt **OSÄKERT**.
Underlaget ligger i `research/` — fyra djuprapporter plus 79 råa källfiler och sex officiella
skärmbilder jag själv mätt på. Källhänvisning per påstående finns i respektive delrapport.

---

## 0. Kort svar

- **Vad det är:** förstapersons rutnäts-"blobber" (Wizardry/Eye of the Beholder) i pixelart med
  **turordningsbaserad kortstrid** och roguelite-meta. poncle + Nosebleed Interactive, 21 april 2026,
  £8.99 / €9.99, Unity/IL2CPP, 20–30 h att klara, 22 crawlers, 58 gems, 15 relics, 9 dungeons, 161 achievements.
- **Vad som är kärnan:** en enda idé — kort spelas i **stigande mana-kostnad** och varje steg gör nästa
  kort starkare. Allt annat (by, dungeons, relics) är inramning. Galante själv: *"everything else is an
  accessory; it's an excuse to justify the combat system."*
- **Kan vi bygga en egen version?** Ja. Kärnan är fyra system, inte fyrtio: rutnätsrörelse, kortstrid med
  kedja, datadrivna kort/fiender, meta-progression. Det finns färdiga MIT-ramverk för två av dem.
- **Stack:** **Godot 4.7.2** (redan installerad) + GDScript + två MIT-addons + CC0-grafik.
  **Unity behövs inte** — dess roll här är konsolutgivning (IL2CPP/Addressables/Odin), inte spelmekanik.
- **Insats:** en spelbar vertical slice är kvällsarbete; den riktiga kostnaden är **innehållet**
  (58 gems, 17 evolutioner, 22 karaktärer) och **pixelarten** — inte koden.

---

## 1. Hur spelet faktiskt spelas (mätt)

**Kärnloopen, i ordning:**

1. **Byn Gorton** (nav efter tutorialen, åtta byggnader: Town Hall, Inn, Fortune Teller, World Map,
   Blacksmith, Museum, Shop) → World Map → välj Crawler och dungeon.
2. **Förstapersonsutforskning ruta för ruta** med fungerande väggar. Man headbuttar torches (guld +
   engångskort), kistor (gems), floor chickens (+10 HP). **Hela våningen är synlig på minikartan från
   första steget — ingen fog of war.** Fiender och kistor står som ikoner.
3. **Encounter:** fiender står i rader, en markeras som mål.
4. **Turstart:** Mana = Mana-staten (**bas 2**), Armor = Armor-staten, antal kort = Hand (**bas 3**).
5. **Spela kort i stigande mana-kostnad** (kostnader 0–8+, "FREE" och "Cost+" finns) → combo-stacken växer.
   Turen kan avslutas när som helst, eller tryckas igenom med **`Play All`** (spelets egna autospel).
6. **Fienderna slår** — främre raden först; nästa grupp måste avancera innan den når dig.
7. **Efter striden** helas du lika mycket som Recovery-staten.
8. **XP → level up → kortval** (tre val, fyra med Luck).
9. **Hitta shoveln, gräv ned** till nästa våning. Våningar per stage varierar (Mad Forest 4, Inlaid
   Library 5, Dairy Plant 5).
10. **Sista våningen: Red Death** slår **innan** du hunnit dra kort och dödar dig normalt — *det räknas
    som klarad dungeon*. Överlever och dödar du honom låser du upp en hemlig Crawler; varje dödad
    Red Death ger +100 % temporär Curse som gör nästa försök svårare.
11. **Tillbaka i byn** där guldet blir permanenta Power-Ups.

**"Turboturn"** är indatamodellen, inte en timer: korten köas och resolvas utan att vänta på animationer.
poncles egen formulering, ordagrant på både Xbox- och Nintendo-store: *"play turns as fast as you
humanly can: The outcome is always accurate."* Ingen reaktionstid, ingen timing-RNG.
Relicen *Sorceress' Tears* (**Hurry Mode**) snabbar upp animationerna och räknar speltiden dubbelt.

**Combo Stack är en relic, inte en startmekanik** — den hittas i tutorialen. Innan dess finns ingen kedja.

---

## 2. Hur det är byggt (teknik, med bevis)

| Del | Vad | Bevis |
|---|---|---|
| Motor | **Unity + IL2CPP + Burst** | SteamDB:s teknikkedja ur filerna för både app 3265700 och demon 4329470 (`Unity Engine, UnityBurst SDK, UnityIL2CPP SDK`) |
| Språk | C# | poncles jobbannons: *"Unity game engine and our own codebase, primarily we need C# programmers"* |
| Paketering | **Addressables**-bundlar per biome/rum/lokalisering (`biome-madforest_assets_all`, `roomtemplates-simple`, `tilemapmaterials`, `localization-string-tables-*`) | filnamn ur dumpad v1.4-fillista |
| Egna DLL:er | `Assembly-CSharp.dll`, **`Pancake.dll`** (Nosebleeds egna), `Sirenix.Serialization.dll` (Odin) | Il2CppDumper-interop i moddokumentation |
| Innehåll | **Data, inte kod**: `CardDatabase`, `EnemyDatabase`, `DungeonGenConfig`, `PowerUpDatabase`, `RelicDatabase`, `RewardConfig_Default` … en config-asset per objekt | dumpade JSON-filer; Unity-serialiserade `AnimationCurve`-fält bevisar formatet |
| ID-schema | `Card_A_0_Whip` (attack, mana 0), `RelicConfig_PancakeOfPower`, `PowerUp_Speed`/`PowerUp_Cooldown`, `DungeonGenConfig_CapellaMagna_01` | wikins tabeller + dumparna |
| 3D-vyn | **rutnätsblobber**: äkta 3D-geometri med pixelart-texturer, fiender/dekor som **billboardade 2D-sprites**, lågupplöst rendering i en ram | mina egna mätningar på sex officiella 1920×1080-bilder (`research/00-matningar-skarmbilder.md`) |
| Attackanimation | "flip the sprites around and move them forward a second" | Nosebleeds CEO Andreas Firnigl i GamesIndustry.biz |
| Dungeon-gen | lager: floor-config → rum som templates → korridorer via **minimum spanning tree** → svårighetskurva per våning | `DungeonGenConfig`, `FloorLayerConfig`, `RoomSpringLayer`, `PathMSTLayer`, `EventLayer` |
| Sparfiler | **JSON** i `AppData\LocalLow\Nosebleed Interactive\Referensspelet\Save\*.save` med ett `Checksum`-fält (får vara tomt) | PCGamingWiki + reverse-engineerad save-editor |
| Ljud | kompositörer Yoko Shimomura m.fl.; soundtracket säljs som DLC med varje spår i **"Crawling"- och "Turbo"-version** → tempobaserad dynamik. Ingen FMOD/Wwise syns i filistan → troligen Unitys inbyggda ljud | Steam-DLC, `_cardPlayedSFX` per kort i `CardDatabase.json` |
| Moddning | **BepInEx 6 IL2CPP/CoreCLR** (eller MelonLoader) — inget inbyggt modstöd | Nexus/Tunderstore-moddar, en skärmläsarmod |

**Vad som är OSÄKERT:** Unity-versionen, om kameran är ortografisk, exakt vad `Pancake.dll` innehåller,
och om ljudet kör Unity Audio eller en inbäddad middleware. Enskilda filnamn kommer från en inofficiell
v1.4-fillista — depotstorlekarna är däremot belagda via SteamDB.

---

## 3. Mekanik-specen (det vi ska implementera)

### 3.1 Resurser och stats

| Stat | Bas | PowerUp (by) | Not |
|---|---|---|---|
| **Mana** | 2 | *Cooldown* +1/rang, max +2 | cap 1 000 000; ges vid turstart, sparas inte mellan turer utan arcanan *Sharp Mind* |
| **Hand** | 3 kort/tur | *Speed* +1/rang, max +2 | nollställs efter varje strid |
| Armor | Armor-staten | — | läggs på vid turstart |
| Recovery | — | — | helar efter strid |
| Amount | — | +1/rang, max 3 | cap 50 |
| Area | — | +10 %/rang, max 5 | cap 1000 %; var 5:e % ger +1 % skada på allt framför |
| Might | — | — | cap 1000 % |
| Greed | — | +25 %/rang, max +100 % | mer guld |
| Curse | — | +20 %/rang | spelarens egen ratt: starkare fiender mot mer XP |

### 3.2 Skadan — formeln är dokumenterad

```
Damage = (CardDamage + CardDamage*Combo + BaseDamage*Amount)
         * (1+Might) * (1+Area/5) * GemMultiplier1 * GemMultiplier2
```

**Kedjan är linjär, inte exponentiell.** `CardDamage*Combo` betyder att varje kedjesteg lägger på
**+100 % av kortets egen skada**. Med Combo 0/1/2/3 blir termen ×1/×2/×3/×4 — jag har räknat det och
kontrollräknat wikins eget exempel (Knife 40, Combo 25, Amount 50, Might 1000 %, Area 1000 %, två
Triple Damage → **427 680**, exakt wikins siffra).

**Det motsäger de fan-sidor som påstår att 0→1→2→3 ger ×120** (de multiplicerar 2·3·4·5). Wikin säger
uttryckligen att "en XX-combo motsvarar att spela kortet XX gånger extra", vilket ger `40 + 40*25 = 1040`
= samma som formeln. Två oberoende wikisidor säger samma sak; SEO-sajterna säger olika saker inbördes
(×24 vs ×120). **Linjärt är det belagda.**

### 3.3 Kedjans regler (det som gör spelet)

- Stigande mana-kostnad. **Samma kostnad två gånger i rad (0,1,2,2) bryter kedjan.**
- **Wild cards** (kostnad "W") kan spelas var som helst, ger ingen egen multiplikator, förstörs oftast,
  och låter *nästa* kort fortsätta kedjan oavsett kostnad — de är broar över hål i handen.
- Kedjan gäller **aktuell hand**; nya kort nollställer stacken, och den bryts normalt i turskiftet
  (arcanan *Chain Link* behåller den).
- Combo skalar **stats och kortdragning, men inte gem-effekter**.
- Manapoolen är taket för kedjans längd: 0-1-2-3-4 kräver 10 mana. **Tomes** (Empty 0→+1, Light 1→+2,
  Weighty 2→+3, Ancient 3→+4, Song of Mana 4) är motorn som gör långa kedjor möjliga.
- Kedjar du för länge **spricker korten permanent**, och varje krossat kort spottar ut en **Purple Death**.

### 3.4 Kort och nyckelord (mätt ur spelt externa UI)

Kostnad 0–8+, raritetsbokstav, färg per typ (attack / item / wild / crawler / mana-generator).
Nyckelord som syns i bild: `Wild.` `Destroy.` `FREE` `Cost+` `Evolved.` `Crawler` `Copy` `Return`
`Knockback` `Area 2x`. Effekttexten är kort och numerisk: *"Deal 43 damage to multiple enemies with
20% Knockback chance."* Combo-multiplikatorn visas som ett **hexagonmärke på det valda kortet**
(mätta värden 1, 3, 40). Överdrift firas med popupen `ULTRA MAXIMUM OVERKILL`.

**Progression:** XP → level up → kortval · kistor i tre tiers (Tier 2 = låsta kistor där du offrar kort,
Tier 3 = högsta rariteterna, kräver relicen Gem Hammer) · **17 evolutioner** (Evolution Gem på ett
attackkort med ledig socket; primär- och sekundärkortet konsumeras) · **58 gems** (kan inte tas bort) ·
**15 relics** som var och en låser upp en mekanik · **arcanas** som ändrar reglerna.

**Crawlers:** 22 st. Den **först valda** bidrar med sina stats/Power-Ups och fyra startkort; efterföljande
bidrar bara med *ett* kort var. Upp till tre samtidigt. Grön Crawler-kort = summon: engångseffekt (skalas
av combo) plus en passiv trigger per färg du spelar, i antal = **Duration**, sedan tillbaka i decket.
En *Outhouse* i dungeonen rekryterar en slumpad upplåst Crawler för 100–500 guld.

**Bossar:** visar **sex lila ögon** som öppnas ett per spelat kort — vid sex öppna slår bossen. Det är
spelets svar på "hur länge får jag kedja?" och är värt att kopiera rakt av. Red Death: 1 000 000 HP,
level-skala 0.01, max hit 333, 99 % knockback-resist.

---

## 4. Vad en egen version kräver

### 4.1 Stack (rekommenderad, motiverad)

| Lager | Val | Varför |
|---|---|---|
| Motor | **Godot 4.7.2** (redan installerad, MIT) | `GridMap` + `MeshLibrary`, `SubViewport` för lågupplöst pixel-look, `Resource`-datafiler, `Tween` för stegvis rörelse, inbyggd CSV-lokalisering, seedad RNG. Ingen inloggning, ingen licensserver. |
| Kort-UI | **chun92/card-framework** (MIT, 376★, aktiv) | Hand som arrangerar sig, drag & drop, högar. Den tråkiga biten, redan löst. |
| Arkitektur-strömbak | **DesirePathGames/Slay-The-Robot** (MIT, 280★, senaste commit aug 2026) | Godot 4-ramverk för roguelike-deckbuilders: card packs, actions med timers, akter, deterministisk RNG. Läses och plockas isär — inte nödvändigtvis används rakt av. |
| Blobber-rörelse | **Rebelion-Board-game/DungonCrawler** (CC0) + **uheartbeast/3d-dungeon** (MIT) | GridMap-rörelse att kopiera rakt in. |
| Arkitektur för celler/ljus | **benc-uk/melkors-oubllette** (MIT) | Dörrar, brytare, facklor som brinner ut. |
| Turn-engine-mönstret | **jhavatar/kubriko-dungeon-crawler** (MIT, Kotlin) | En motor som hela simulationen (spelare, monster, dörrar) går igenom och som kan växla realtid/tur. Bästa arkitekturbeskrivningen som finns. |
| Dungeon-gen | algoritm från **glouw/dungen** (MIT) / BSP; FOV/vägar från **python-tcod** (BSD) | ~200 rader GDScript, inte ett beroende. |
| Grafik | **KayKit Dungeon Pack** (CC0, 200+ modulära 3D-delar) för väggar/golv, **0x72 Dungeon Tileset II** (CC0) för monster, **Kenney** (CC0) för UI och ljud | Allt CC0 → ingen attributionsträda, ingen jurist. |
| Pixelart-verktyg | `aur/aseprite-bin` (ännu inte installerad) | När vi behöver egen konst. |

**Undvik (licensfällor):** `db0/godot-card-game-framework` (AGPL), `oskarrough/slaytheweb` (AGPL),
`Card-Forge/forge` (GPL), allt **utan licens** (`huement/cotu`, `MutantStargoat/raydungeon` — läsbar kod
är inte återanvändbar kod), samt Grimrocks och Slay the Spires **assets** (får bara användas inuti
respektive spel). `JavierIslas/Card-Combat-System` är AGPL men säljs med kommersiell licens ($50) om vi
hellre köper än skriver ~600 rader själva.

### 4.2 Vad vi bygger själva (och vad vi inte bygger)

**Bygger:** stridslogiken headless (~600–1000 rader: kort som data + effekter som injicerade
`Callable`s + seedad RNG per domän), rutnätsrörelsen (~200), dungeongeneratorn (~200), meta-lagret
(~400: save med `save_version`, en karta, en butik, relics som passiva effekter).

**Bygger INTE:** motor, kort-UI, tillgångar, kort-DSL (vänta tills handeln passerat ~200 kort),
fiende-AI med behavior trees (en intent-tabell per fiende räcker långt), dialogmotor, multipla våningar,
dynamisk belysning, fler språk än sv/en.

### 4.3 MVP — den första vertical slice (acceptanskriterier)

1. Rutnätsdungeon, två våningar, 90°-svängar, dörrar, shoveln nedåt, minikarta utan fog of war.
2. En crawler, 12 kort i tre kostnadsnivåer + 2 wilds + 2 Tomes.
3. Strid: mana-orb, Hand 3, drag/discard/exile, stigande-kedja med synligt multiplikatorhexagon,
   `Play All`, `End Turn`, fiender i rader, en boss med sex ögon.
4. Fyra fiender med intent-tabeller, en evolution, två gems, en relic.
5. XP → kortval, kistor → guld, en by med tre Power-Ups, save/load med version.
6. **Kedjeformeln mätt:** ett självtest som spelar 0→1→2 och bevisar att tredje kortet gör exakt ×3 av
   sin egen skada (och att 0,1,2,2 bryter kedjan). Detta är den enda logiken som måste vara rätt från dag ett.

### 4.4 Juridik — gränsen går här

Får kopieras: **mekanik och struktur** (regler är inte upphovsrätt). Får **inte** kopieras: sprites,
pixelart, kort- och gemikoner, animationer, musik/jinglar, sfx, namn (Antonio, Whip, Runetracer, Gorton,
Red Death), korttext, logotyper och varumärkena **"Referensserien"**, **"Referensspelet"** och
**"TurboTurn™"** — hitta ett eget namn tidigt, det kostar inget nu och mycket senare. Även koden i
`Assembly-CSharp.dll`/`Pancake.dll` är upphovsrättsskyddad: att dumpa den för att *förstå* är en sak,
att återanvända den är intrång.

---

## 5. Det som fortfarande är omätt — och hur vi mäter det

| Lucka | Så mäter vi den |
|---|---|
| **Exakta siffror per kort** (skada, mana, gem-slots) | Demon är **gratis på Steam** (app 4329470), och publika dumpar av `CardDatabase.json`/`EnemyDatabase.json` finns på GitHub. Vi läser värdena som **kalibreringsreferens** och skriver egna tal — vi skeppar inte deras data. |
| XP-kurvan per nivå, fiende-HP per difficulty | samma dumpar; annars egen mätning i demon |
| Körningslängd i minuter | endast en svag sekundärkälla (60–90 min). Återförsäljarnas "20–30 min/run" är AI-genererat skräp — **mät själv i demon.** |
| Om kartan har fog of war | recensenter säger nej, jag har inte kunnat mäta det i bilderna |
| Om 3D-vyn är mesh-geometri eller raycasting | irrelevant för oss — vi väljer mesh i Godot oavsett |
| Demo vs fullversion: delad data? | inte belagt |

---

## 6. Underlaget

| Fil | Innehåll |
|---|---|
| `research/00-matningar-skarmbilder.md` | mina egna mätningar på sex officiella bilder (+ `research/screenshots/`) |
| `research/01-spelmekanik.md` | mekanik för mekanik, 44 käll-URL:er, turordning, combo, dungeon, meta |
| `research/02-teknik-och-bygge.md` | motor, paketering, 3D-vyn, ljud, moddning, vad som är återanvändbart vs IP |
| `research/03-prior-art.md` | 60 granskade repos med licens/liveness, motorval, 3D vs 2.5D-slitsar, plan |
| `research/04-intervjuer-och-postmortem.md` | produktion, Galantes designprinciper med citat, budget, mottagande |
| `research/sources/` | 79 råa källfiler (wiki-sidor, IGN/Polygon-texter, Steam-JSON) |
