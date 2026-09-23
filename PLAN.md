# Målbild och milstolpar

Alex målbild (2026-09-19): **80+ kort**, **~40 banor/stages**, och **communityns högst rankade
moddar inbyggda som egna funktioner från start**. Målet höjdes samma dag: **matcha och slå
referensens volym med marginal** — se M6 och `research/07-arkitekturguide.md` för de uppmätta
siffrorna (de offentliga källornas siffror, 58 gems / 15 relics / 9 dungeons, visade sig vara för
låga; ur bygget är de 137 / 68 / 42 nyckelrötter).

## Vad målbilden kräver av arkitekturen (och varför den redan är byggd så)

| Mål | Krav | Redan på plats |
|---|---|---|
| 80+ kort | Kort är **data**, effekter är en liten op-vokabulär | `data/cards/*.json` — ett kort = ett JSON-objekt; ny effekt = en rad i `Combat._apply_effects` |
| 80+ kort | Ingen manuell kortlista som växer | `Cards.load_all()` läser alla pack-filer, sorterade, med dubblettkontroll |
| ~40 stages | Stage = data (våningar, layertyp, difficulty, belöningar) | ej byggt — se M2 |
| ~40 stages | En generator, inte 40 handbyggda banor | BSP/MST-generatorn (M2) läser en `stage.json` |
| QoL-moddar inbakade | Funktionerna ska vara **våra**, inte patchar | `research/05-moddar.md` (pågår) blir en kravlista i M3 |
| Allt ovan | Balansen ska gå att mäta utan att spela | `core/` är headless; `tests/test_rules.gd` kör 21 kontroller på under en sekund |

## Milstolpar

**M0 — regelmotorn (klar 2026-09-19)**
`core/rules.gd`, `core/cards.gd`, `core/combat.gd`, 14 kort, 21 gröna kontroller.
Kedjan, mana-grinden, fiendeturen, bossögonen och skadeformeln är mätta mot referensens wiki.

**M2 — dungeon och stages som data (klar 2026-09-19)**
`core/db.gd` (en lastare för alla pack), `core/enemies.gd`, `core/stages.gd`, `core/dungeon.gd`
(BSP → rum → L-korridorer i sekvens = spännande träd, inga loopar än), `data/stages/*.json` (40 filer),
`data/enemies/00_bestiary.json` (17 fiender, 5 bossar varav en "Pale Reaper").
Svepet i `tests/test_dungeon.gd`: **1000 genererade våningar, 0 fel** — varje våning sammankopplad,
boss + shovel på plats, minst 4 strider, inga okända fiende-id:n, och determinism (samma seed = samma
våning, olika seed = olika). Mätt att testet biter: boss placerad i väggen → *"varje våning är
sammankopplad"* föll på 1000 våningar.
40 stages = 200 våningar, difficulty 1–9.

**M1 — första spelbara striden (GUI)**
*Logiken klar 2026-09-19* (`core/explore.gd` + `core/run.gd`, `tests/test_run.gd`): rörelse ruta för
ruta i 90°-svängar, BFS-väg till mål, strider via autospelaren, shovel och nedstigning, och en
**eventström** (`floor_enter`, `combat_start`, `combat_end`, `shovel`, `run_end`, `stuck` …) som UI,
ljud och skärmläsare ska läsa — den buss som communityns tillgänglighetsmoddar tvingades bygga i
efterhand. En hel körning på stage_01: **3/3 våningar, 25 strider vunna, 1 förlorad (Pale Reaper),
186 guld, 142 xp, utfall "reaped"** — att dö för reapern på sista våningen *är* att klara banan,
precis som i referensen. Mätt att testet biter: autospelaren avstängd → 6 kontroller föll.

*Klart 2026-09-19:* `main.gd` + `main.tscn` — förstapersonsvyn (MultiMesh för väggar/golv/tak,
billboard-`Sprite3D` för fiender och saker, kamera per ruta med tween), HUD (HP/guld/xp/nivå/steg),
stridspanel med fiende-HP + mana + kedja, och kortvalspanelen. **Egen kort-hand i stället för
`card-framework`**: en rad knappar är mindre kod än en dependency, och vi äger redan datan.
Korten går att klicka, tangenterna 1-9 fungerar, och rörelsen blockeras medan ett kortval väntar.
`-- shot` sparar en skärmbild och avslutar, så vyn går att verifiera utifrån.
Mätt: scenen kör 60 frames headless utan felmeddelanden; UI-vägen har egna 12 kontroller.

*Kvar:* egen pixelkonst i stället för genererade rutor, musstyrning av rörelsen, minikarta,
mana-orb och combo-hexagon *på* kortet som i referensen, ljud.

**M3.5 — progression: XP, level up och kortval (klar 2026-09-19)**
`core/progress.gd` (kurvan och valet, rena funktioner), `data/cards/01_core.json` (**25 nya kort** i
tre rarity-skikt → **39 totalt**), `Run.level` + kö av kortval, `pick_card()`, egen RNG-ström för
valen (samma seed = samma val oavsett hur striden gick). `tests/test_progress.gd`: 22 kontroller.

**M4 — metasiffrorna är mätta, inte gissade**
`tools/balance.gd` spelar 20 körningar per bana med **standardspelaren** (inga hack). Mätt läge:

| Svårighet | Når våning 2 | Klarar banan | Mediannivå |
|---|---|---|---|
| 1 (stage_01–04) | 18–20 av 20 | 15–17 av 20 | 4–5 |
| 2 (stage_05–08) | 17–20 av 20 | 11–14 av 20 | 4–5 |
| 3 (stage_09–12) | **2–4 av 20** | **0 av 20** | 2–3 |

Slutsatsen är inte "svårighet 3 är trasig": en färsk spelare **ska** inte klara svårighet 3 —
det är där meta-lagret (gems, permanenta uppgraderingar) ska bära. Väggen är alltså måttet på att
meta-lagret saknas, och den blir mätpunkten när M4 byggs. Kurvan för svårighet 1–2 är rimlig.

**M3 — QoL-baslinjen (kravlista från `research/05-moddar.md`, påbörjad 2026-09-19)**
Communityns rankade moddar blir krav, inte tillval. Mätt läge:

| Krav (från moddarna) | Läge |
|---|---|
| Smart autospel som combo-solver (referensens `Play All` spelar höger-till-vänster och fortsätter även när kort spricker) | **klart** — `Combat.auto_play()`, mätt: **501 skada mot 261** för naiv ordning med samma hand och samma mana |
| Aldrig autospela Destroy-kort / kort som kan spricka | **klart** — Destroy, plus `allow_wilds` som uttalad regel |
| Fiende-HP i UI (största luckan i referensen; tre moddar bygger samma sak) | **klart** — modellen (`total_enemy_hp`, `enemy_hp_percent`) och UI:t (`STRID`-panelen visar varje fiendes HP) |
| Combo-/evolutionshjälp i level-up-vyn (EVO / EVO-bis / NEW / ×N) | **klar (M28)** för EVO-delen — valet visar receptet i klartext (`UPPGRADERING: Axe + Ember Tome → Emberstorm`) och erbjuder bara en uppgradering när båda delarna ligger i leken; NEW/×N-märkningen är kvar |
| Handsortering som view-state (kostnad upp/ner, färg, wilds vänster/höger) | **klart** — `HandView.sorted()`, muterar aldrig originalhanden |
| Deck-overlay med kort per kostnad | **klart** — `HandView.deck_curve()` |
| Tillgänglighet som arkitektur: event-buss för spelläge (skärmläsare + ljudcues) | ej påbörjad — byggs när M1-scenen finns, men allt som ändrar state ska gå genom den |
| Kortets kvarvarande spelturer (break) synligt på kortet | **öppen mekanik**: att kedja för länge spricker kort i referensen, men siffrorna är inte kända. Lägg in som kalibreringsratt (`crack_after_steps`, avstängd som standard) — gissa inte |
| Combo-/evolutionshjälp i level-up-vyn (EVO / EVO-bis / NEW / ×N) | ej påbörjad; recepten ska vara data |
| Run-historik/statistik | ej påbörjad — billigt när varje run loggas strukturerat (eventströmmen finns redan) |
| Dev-konsol, bildutbyte, farmbot, save-editorer | **byggs inte** — det är felsökningsverktyg för att referensen inte exponerar något, inte funktioner |

**M4 — innehållsproduktionen: konst och ljud genereras (2026-09-19)**
`tools/gen_art.py` (kortikoner) och `tools/gen_sfx.py` (spelljud) — båda körbara utan att spela.
Bilderna kommer från bildmodellerna som redan ligger i OmniRoute (`gemini-3.1-flash-image` m.fl.;
23 bildmodeller och 6 Lyria-modeller inkopplade, inget att installera). Efterbehandlingen är
poängen: **64×64 med heltalsskalning till rutan, kvantiserade mot `game/assets/palette.json`,
bakgrunden borttagen**. Det är den som gör att 39 separata modellbilder ser ut som ett spel —
mätt i två omgångar: första försöket gav en flaska i stället för en bok (motivet nycklades på
effekttyp, nu på kortets egna ord) och ikoner i olika storlek (nu beskärs och centreras varje
ikon; ytan mäts och flaggas). Ljuden är nio oscillatorer med hölje (90–900 ms) — inga licenser,
ingen nedladdning, samma kommando ger samma ljud.

`tests/test_assets.gd` vaktar hela kedjan: varje kort i datan ska ha en 64×64-bild vars färger
finns i paletten, och varje ljudevent en WAV som Godot kan spela. Ett trasigt asset faller i
sviten i stället för att bli en tom knapp. Mätt: generatorn tappade 31 av 39 kort när en modell
svarade 429 — nu växlar den rutt själv.

**Korten är kort (2026-09-19).** Handen och kortvalet ritas nu som spelkort: `game/ui/card_view.gd`
ger ett kort med kostnadsbricka, typ, namn, konst och (i kortvalet) effekttext; kortet lyfts när
pekaren är över det eller när tangenten 1-9 tar det. Samma widget i båda, bara storleken skiljer
(64×88 i handen, 84×118 i valet). Fyra fel mätta på bild: handpanelen var måttad för de gamla
textknapparna så nedre halvan av varje kort klipptes; namnet låg under konsten och klipptes bort
(3 av 4 kort visade konst men inget namn); `HFlowContainer`s minsta bredd är dess bredaste barn, så
kortvalets tre kort staplades lodrätt utanför skärmen; och en lyft panel måste använda `scale` +
`z_index`, eftersom en container skriver över `position`. Prov: `test_ui_path` kontrollerar att
kortet har kortstorlek, kostnad, namn och hela effekten i tipset (7 nya kontroller).

**Korten hålls framför spelaren (2026-09-19).** Ingen ruta runt handen: korten placeras för hand i en
platt yta över vyn (inte i en container — den skriver över både position och rotation), roterade
kring sin nederkant i en solfjäder, omlott (avstånd 0,82 × kortbredd). Det kort pekaren är över
TRÄDER FRAM: rätar upp sig till 0°, växer 1,5× uppåt från sin egen nederkant, får guldkant och visar
sin effekttext. Demoläget fotograferar även det framträdda läget (`02-kort-fram.png`), annars går
huvudfunktionen aldrig att granska.

Två fel mätta på vägen. (1) Ett roterat kort kring sin nederkant sänker sin ena nederkant med
(bredd/2)·sin(vinkeln) — utan hänsyn till det klipptes ytterkortens hörn av skärmkanten. (2) Ett
kort blev **58×167, 58×105, 58×195 … i stället för 58×80**: en radbrytande `Label` rapporterar sin
minimihöjd för en pyttebred ruta, så `PanelContainer` tvingades växa efter texten — olika för varje
namn. Bilden såg ut som en hand hela tiden; det var **siffrorna per kort** som namngav felet
(`Choir Bell 58x167; Lash 58x120`). Fix: `RichTextLabel` med `fit_content = false` (klipper i
stället för att kräva plats), plus en kontroll att `get_combined_minimum_size()` ryms i kortstorleken
— den faller direkt om någon sätter in en radbrytande Label igen.

**Egen pixelkonst för väggar, golv och tak (2026-09-19).** `tools/gen_tiles.py` räknar fram fem
32×32-rutor i spelets 16-färgspalett: murverk, murverk med mossa, flagor, spruckna flagor, takplank.
Samma skäl som för ljudet — sömlösa rutor i EN palett är tråkigast i världen att leta efter och
lättast att räkna fram, och då finns ingen licens att hålla reda på. Vyn använder mossa och sprickor
på våningar med boss, så rum skiljer sig åt.

Provet mäter det ögat inte kan avgöra på en enskild ruta: att varje pixel ligger i paletten, att
ljusheten är rimlig, och att **skarven inte är värre än den värsta kanten inuti rutan** (rutan
upprepas per block, så en skarv blir ett rutnät över hela väggen). Tre fel föll ut ur mätningarna:
`wall` skrev aldrig sin färg (1 färg av 16 — den räknade fram färgen men tilldelade den aldrig), och
två gånger lästes väggen som "modular panels / high-contrast borders" på bild. Sista fixen var
skalan, inte mönstret: en 1 m-vägg visar hela rutan, så fyra tegelvarv blev 25 cm sten och lästes
som paneler — `uv1_scale = 2×2` ger 12,5 cm sten ur samma ruta, och då är domen "traditional stone
masonry / ashlar block construction, not large flat panels". Rutorna mäts i `tools/test.sh`.

**M5 — spelet går att spela och granska (2026-09-19)**
`main.gd` är en spelbar scen: förstapersonsvy, HUD, minikarta, kortstrid, kortval och slutskärm.
UI:t verifieras utifrån med `-- shots`, som spelar en hel körning genom **samma funktioner som
tangenterna anropar** och fotograferar varje skärm (körs på en virtuell skärm, `Xvfb :99`).
Fyra fel hittades och rättades genom att titta på bilderna i tre omgångar: HUD och knappar
klipptes vid högerkanten (HFlow radbryter), kortknapparna ritades under skärmkanten
(PanelContainer ankrad i botten växer nedåt → offset), panelerna hamnade snett nedåt höger (ett
center-ankare räknar position från mitten), minikartan syntes inte (en Control utan container
behåller storlek noll). Dessutom: `icon_max_width` är en tema-konstant, inte en egenskap.

**Riktigt fel som stoppade spelet:** shoveln ligger på bossens ruta med flit — den får man av
bossen — men `Explore.node_here()` returnerade den *första* noden på rutan. Efter bossen pekade
uppslaget på en avklarad boss, så shoveln kunde aldrig plockas upp och körningen stannade på
våning 1 för alltid. Mätt i demoläget: 900 varv utan att komma ned ("står på målet shovel;
node_here ger boss (cleared ja)"). Fix: `node_here()` returnerar första **oavklarade** noden, och
stridens slut letar igen på rutan. `test_ui_path` fick en kontroll för hela kedjan
(boss → shovel → nästa våning), och den är mätt att bita: 17 kontroller/1 fel utan fixen,
18/0 med. Efter fixen: 38 bilder, hela körningen, död på våning 3, nivå 4.

Två språkfel föll också ut ur bilderna: utfallet stod som `dead` i en svensk UI (`Run.outcome_text()`)
och HP kunde visas som `-2/60` (nu klampat i `Combat`, där skadan läggs på).

**M4 — meta-lagret: byn, guldet och sparfilen (2026-09-19)**
`core/meta.gd` håller guld, ranger och sparfilen. Filen är JSON med `save_version`, skrivs
**atomiskt** (temp-fil + namnbyte — en krasch halvvägs kan inte lämna en halv fil), och en trasig
fil **döps om** till `save.json.trasig` i stället för att skrivas över: framsteg ska inte kunna
försvinna i tysthet. En nyare version än spelet känner rörs inte alls. De åtta uppgraderingarna
ligger som data i `data/powerups.json`, och `Run` tar en `Meta` (nullbar = standardspelaren) och
lägger på statsen i `_init` och i `begin_fight` — en ny uppgradering är en rad i JSON.

Slutskärmen ÄR byn: `1`-`8` köper, `R` kör igen, och guldet ligger i banken mellan körningarna.
31 kontroller provar metan, varav sparfilen hårdast (tur och retur, trasig fil, för ny fil,
handredigerad rang 99 → 5, och att statsen verkligen når striden).

**Mätt, och det var frågan lagret skulle svara på:** svårighet 3 (`stage_09`, 20 körningar per rad)
klarades av **1/20** utan uppgraderingar, **3/20** vid rang 1, **12/20** vid rang 2 och **18/20**
vid rang 3. Väggen flyttar sig med metan — svårighet 3 var tidigare omöjlig och är nu en tröskel
man klättrar över, vilket är hela poängen med en roguelite. Mätningen körs med
`tools/balance.gd -- 20 stage_09 <rang>`.
**Kvar av M4:** gems (3 slumpade per kista, tre tiers), relics (15 som var och en låser upp en mekanik),
arcanas, companions (22+), och innehållsvolymen mot 80+ kort av 82 (67 grundkort + 15 uppgraderingar;
uppgraderingarna kommer bara ur sina recept). Alla är innehåll ovanpå motorn, inte nya system.
**Evolutionerna är klara — se M28** (17 recept; delarna konsumeras, resultatet är ett kort).

**M4 — innehållsvolym: 61 kort och två nya nyckelord (2026-09-19)**
22 nya kort i `data/cards/02_expansion.json` (39 → 61), en per rad i samma stil som de befintliga.
Två nya effekt-op i motorn: **knuff** (`knockback`, flyttar fienden bakåt i raden) och **frys**
(`freeze`, fienden står över N turer och tinar en tur i taget). De är varsin rad i `_apply_effects`
och en rad i kortdatat — ingen ny klass, inget nytt system. `hoarfrost` och `the_long_winter` fick
frysningen sina namn lovar.

**Regelfällan knuffen avslöjade:** den gamla regeln var "rad 0 slår, bakre rader väntar" — så fort
ingen stod i rad 0 (efter en knuff!) slog *alla*. En knuff kunde alltså göra fienden farligare.
Rätt regel är "**den lägsta besatta raden slår**": identisk i alla gamla fall, och en knuff tystar
den farliga främre raden i stället (mätt i provet: 9 skada → 3 när den svaga bakom tar över).
En ensam fiende slår ändå, så en knuff kan inte låsa striden.

**Ett prov för vokabulären:** `Combat.OPS` är motorns lista över effekter, och `test_assets`
jämför kortdatat mot den i båda riktningarna — en felstavad op (`knock_back`) blir ett rött prov i
stället för en tyst `push_error` mitt i en strid. `Cards.describe()` fick sina två fall också, med
prov: en op utan text på kortet är osynlig för spelaren även när regeln fungerar.

**Mätt efteråt (20 körningar per rad):** svårighet 1 = 17/20 och svårighet 2 = 17/20 utan meta
(orörd), svårighet 3 = **0/20** utan meta (var 1/20 med 39 kort) och **11/20** vid rang 2. Fler
kort späder ut kortvalen — de 22 nya är mest common, och draget väljer common/common/uncommon —
så svårighet 3 blir en aning hårdare för standardspelaren medan kurvan med uppgraderingar står
kvar. Det är rätt riktning för en roguelite, och det är en mätning, inte en gissning.

**M4 — fiender som figurer (2026-09-19)**
`tools/gen_enemy_art.py` ritar 17 fiender × 2 bildrutor (64×32, `hframes = 2`) ur fiendens eget
namn, tier och kroppsform (biped/crawler/hound/wisp/swarm/blob) — egen pixelkonst i paletten,
ingen kvot, ingen licens. `--check` mäter paletten, att figuren hänger ihop i **ett** stycke och att
rutorna skiljer sig; den hittade två riktiga buggar (benen lossnade på 8 av 17, och två bossar var
ett huvud utan kropp eftersom färgrampen använde bakgrundsfärgen till överkroppen).

**Rotorsaken till att de inte syntes:** striden startade när spelaren *stod på* noden, så figuren
hamnade 0,4 m vid sidan/bakom kameran (mätt i demoläget: `fiender 1: 0.4m vid sidan/bakom`). Nu
möter man noden man har **framför** sig (`Explore.node_ahead`), och mätningen säger 1,0–2,8 m
framför vid stridens start. Antalet figurer i rummet kommer ur `Run.enemy_count_for` — samma
funktion som `begin_fight` räknar med, så vyn aldrig visar tre varelser där det blir två.

**Kvar (Alex önskemål 2026-09-19):** startmeny med språkval — **klart i grunden samma dag**, se M6.

**M6 — språken, arkitekturguiden och målsiffrorna (2026-09-19)**

Alex: *"Vi kan ta in de språk de har till vårat med, så vi har samma scope som dem, men lägg till
även svenska. Siffrorna du grävt fram, vårt behöver matcha, och övermanövrera dem med god marginal.
Även gems, relics osv, vi behöver det med. Men kan du använda deras arkitektur och struktur som
guide till vårt?"*

- **13 språk** (deras tolv + svenska) i `data/i18n/*.json`, byggda av `tools/gen_i18n.py` ur spelets
  eget data — en nyckel kan inte glida ifrån spelet. `core/tr.gd` slår upp med svenska som källa och
  fallback; ett språk vars gränssnitt inte är komplett får inte väljas. `L` byter språk var som helst
  i spelet, valet sparas i sparfilen, och byn visar raden. `tests/test_i18n.gd`: **101 kontroller**,
  och `tools/gen_i18n.py --check` ligger i `tools/test.sh`.
- **Språktäckning (mätt):** svenska och engelska 100 %, de elva andra har hela gränssnittet
  (39 av 174 nycklar = 22 % — innehållsnamnen fylls på etappvis, siffran visas i menyn).
- **Arkitekturguiden:** `research/07-arkitekturguide.md` — deras 56 systemnyckelord, 21 stats, 8
  korttyper, gem-typerna, relikerna som *systemupplåsningar*, upplåsningskedjan (prestation →
  belöning → bana/relik/system), slutskärmens kolumner, loops och poängräkning, ställt mot vårt läge
  och med en prioriterad åtgärdslista. Underlaget är `research/referens-vokabular.txt` (deras egna
  nyckelnamn ur Shared Data — bara identifierare, ingen text, inga bilder, ingen kod).
- **Målsiffror (Alex: matcha och slå med marginal)** — ungefär 1,5 × deras volym:

| Tabell | Deras (mätt) | Vårt nu | Mål |
|---|---|---|---|
| Kort | 262 | 61 | **300** |
| Gems | 137 | 0 | **150** |
| Relics | 68 | 0 | **60** |
| Arcanor | 52 | 0 | **60** |
| Banor | 42 | 40 | **60** |
| Power-ups (stats) | 21 | 8 | **24** |
| Effekter/nyckelord | 358 | 7 | **90** |
| Prestationer | ~300 | 0 | **400** |
| Menyrader | 411 | 39 | **420** |
| Språk | 12 | **13** | 13 |

Byggordning från guiden: startmenyn (påbörjad), slutskärmens gems/relics/keyword-kolumner, relics +
upplåsningskedjan, gems som typbyte, arcanor, statsen `reroll`/`banish`/`revival`/`luck`,
effektkedjan `destroy`/`pierce`/`bounce`/`reverse_combo`/`scavenge`/`evolved`, sedan volymen.

**M7 — karteditorn: banorna ritas, inte gissas (2026-09-19)**

Alex: *"om du bygger en kart-editor kan jag bygga kartorna, så det behöver du inte tänka på då
isåfall"*. Sagt och gjort — och referensen gör exakt så: deras 67 rum är handbyggda prefabs, ett
rum per relik, bossrum markerade per storlek (research/08-referensrum.md).

- `core/mapio.gd` — formatet (`data/maps/<bana>_<våning>.json`: `#` vägg, `.` golv, noder för sig),
  atomiskt sparande, och **grinden**: exakt en start/boss/nedstigning, minst fyra strider, inga
  noder i väggar, allt nåbart. Samma kontroller som generatorn måste klara.
- `core/dungeon.gd` använder den ritade våningen om den finns; annars genereras den som förut. En
  bana kan alltså byggas våning för våning.
- `game/editor/editor.gd` + `tools/editor.sh` — rita, sudda, spara (`S`), läs (`L`), ny (`N`),
  playtest (`P` — sparar först och släpper in dig på våningen), byt våning (`[` `]`). Rörande
  bildruta: `res://editor/editor.tscn -- stage_01 0 shot`.
- `tests/test_mapio.gd` — 22 kontroller: tur och retur, att grinden vägrar en ospelbar våning, att en
  avskuren boss fångas, och att `Dungeon.generate` ger kartans rutor i stället för generatorns.
  Provet fångade direkt ett fel i min egen exempelkarta (korridoren till bossrummet saknade en ruta).
- `tests/test_dungeon.gd` mäter nu seed-spridning på en **genererad** våning och likformighet på en
  ritad — ritade våningar ska vara likadana varje gång, och det är avsiktligt.

**M8 — fienderna tillverkade, och namnet satt (2026-09-19 kväll)**

Alex: *"Fienden behöver tillverkas"* och *"Har ett förslag: Döpa om spelet till HellCrawler."*
Båda gjorda.

Namnet är **HellCrawler** (`game/project.godot: config/name`), sparmappen flyttad med
(`~/.local/share/godot/app_userdata/HellCrawler/save.json`, 1852 guld och språkvalet är med — den
gamla mappen ligger kvar orörd). Namnet var ledigt som spel; det som finns är ett kroatiskt
metalband, en förmåga i Baldur's Gate 3 och två små hobbyprojekt.

Fienderna: 40×40 duk, **sex rutor** (andas in, andas ut, spänner sig, hugger, träffad, död),
ljussättning uppifrån, markskugga, och kontur. Fyra fel hittades på vägen, alla mätta:

1. **Konturen var osynlig.** Den ritades i INK — som ÄR bakgrunden. Konturen finns för att figuren
   ska synas mot golvet; en genomskinlig kontur är ingen kontur. Nu DARK.
2. **Bilderna var RGB, inte RGBA.** INK är en nästan svart FÄRG, så varje fiende var en opak 40×40
   ruta med en varelse inuti. I ett mörkt rum lästes den som en svart rektangel — det är den "void"
   som syntes i korridoren. Fixat: kroppen opak, markskuggan halvtransparent (alfa 130), resten
   genomskinligt. Ett svitprov vaktar alfakanalen nu.
3. **`sym()` speglar kring dukens mitt, så `lean` inuti en speglad del slet isär figuren** —
   skitterlingen hade en tvåpixlig spricka rakt genom kroppen. Lutningen är ett eget pass efter
   ritningen.
4. **Markskuggan räknades som en kroppsdel**, eftersom kontrollen kände igen den på färgen MORTAR —
   som också är överkroppens färg i tier 1. Golv och figur har var sin kanal nu.

Dessutom: formen sätts **per fiende för hand** (FORMER), inte via namnmatchning — den gamla
ordningen gjorde 12 av 17 till samma humanoid. I vyn: `alpha_cut = DISCARD`, sex rutor kopplade till
striden (förvarning innan slaget faller, träffruta vid tappad hälsa, dödsruta som ligger kvar), och
fötterna placerade på rad 33 av 40 → 13,5 px över golvet, räknat ur konsten.

Verifierat i spel (`shots` + granskning av stridsbilden): figuren står på golvet, konturen syns,
ingen svart ruta. Kontaktkartan `game/assets/enemies/_kontaktkarta.png` ligger kvar som
granskningsbild — den visar varje fiende mot både golv och mörker.

Kvar till nästa pass: **kortens flyt** (Alex: *"korten är inte riktigt så där härligt flytande men
taktila som de är i originalet"*) — svikt i hover, släp, och en spelt-animation som går till målet.

**M9 — HUD:en ombyggd efter Alex genomgång (2026-09-19 kväll)**

Alex, med två skärmbilder: *"det finns inget enkelt sätt att se om man attackerar någon som är på väg
att dö eller ej, finns ingen healthbar"*, *"Rutan med text är överväldigande"*, *"Går det att flytta
ned korten"*, *"Kartan kan göras mindre, och sitta längre upp"*, *"De olika markeringarna på kartan
bör vara tydligare, t ex en döskalle på bossen"*, och *"Känslan när man bläddrar bland korten är
hackig med, den behöver vara flytande"*.

Sex ändringar:

1. **Healthbarer i världen.** Ett tunt streck över huvudet på de fiender man FAKTISKT slåss mot,
   vänsterankrat så det krymper från höger, grönt → gult → rött. Fiender i andra rum har ingen
   stapel — de har ingen hp att visa. Byggda av en 1×1 vit pixel och `scale`, alltså ingen ikonfil.
2. **Stridspanelen kortad.** Rubriken "STRID" och spelarens hp-rad bort (samma siffra stod i
   toppraden), och fienderadens hp/max bort — den visas som en stapel i världen nu. Kvar: vem som
   träffas och för hur mycket. Panelen halverades.
3. **Korten längst ned.** Underkanten 6 → 2 px från skärmkanten, ytterkortens lyft 5 → 2 px.
4. **Minikartan mindre och högst upp.** 92×74 → 76×60, och toppraden ligger till vänster i stället
   för över hela bredden, så kartan får plats i övre högra hörnet (den låg 26 px ned förut).
5. **Egna märken på kartan.** Färgade hela celler → döskalle för bossen, liten röd prick för
   strider, kista, låga och shovel. Granskat i 8× förstoring: alla sex läses.
6. **Handen flytande.** `set_forward` satte storlek och rotation DIREKT — kortet hoppade, och ögat
   läser ett hopp på 16 ms som ett hack. Nu tweenas storlek/rotation/position (TRANS_BACK, 0,16 s)
   med en liten översläng, och när ett kort träder fram öppnar solfjädern sig 16 % medan grannarna
   glider undan. Dessutom: `_place_panel` mätte om hela UI-trädet vid VARJE hover — den största
   enskilda orsaken till hackigheten. Storleken cachas nu per panel.

Verifierat med `shots` + granskning: baren sitter strax över huvudet (första försöket hamnade i
taket), ingen HUD-text krockar med panelen, kortnamnen ryms (7 px i handen, överlapp 0,9 i stället
för 0,82), och kartans märken är läsbara vid 8× förstoring.

**M10 — slagets kvitto (2026-09-19 kväll)**

Alex: *"Nu gäller det att få till så det är en visuell bekräftelse att man attackerar med."* Utan den
ser ett spelat kort likadant ut som ett ospelat: healthbaren krymper, men inget HÄNDER.

Tre saker samtidigt, för de svarar på olika frågor:

- **Siffran** (`Label3D` ovanför fienden) säger hur mycket, och färgen säger hur bra draget var:
  vitt vid ×1, gult vid ×2, orange vid ×3+ och vid ett dråp. Den stiger och tonar ut på 0,75 s.
- **Blinket** (`modulate` i 0,04 s) säger att det TOG.
- **Knuffen** i Z (0,09 m och tillbaka med TRANS_BACK) säger var. I Z, aldrig i Y: `_process` andas
  figuren i Y, och två tweens på samma egenskap slåss om sista ordet.

När man SJÄLV tar stryk blinkar hela vyn rött (`ColorRect` under panelerna, alltså inte över korten).

Tre placeringar mättes fram på bild, och de två första föll:

1. Huvudhöjd (+0,34 m) — hamnade uppe i stridspanelen. Fienden står 0,8 m bort, och 0,9 m över
   golvet är 24° över blickfånget: panelen sitter exakt där.
2. Figurens mitt — hamnade BAKOM figuren (billboardens quad är 1,44 m).
3. **Bredvid kroppen i midjehöjd**, 0,42 m åt sidan och 0,25 m mot kameran: syns, läsbar, fri från
   panelerna. Konturen sänktes från 12 till 6 px — vid 12 åt konturen upp bokstäverna och siffran
   lästes som ett mörkrött streck.

Demoläget fotograferar nu också `04-slag.png` direkt efter att draget lösts. Den gamla bilden
"kort-spelat" togs 0,07 s efter anropet, men kortet flyger i 0,14 s innan draget löses — siffran
fanns alltså inte i bilden, och det var därför första försöket såg tomt ut.

**M11 — attacken syns, och fienden står framför dig (2026-09-19 sen kväll)**

Alex: *"Det saknas fortfarande någon form av visuell bekräftelse att man gjort en attack, t ex kniv
som far förbi, en piska som snärtar till, osv. Sen ser man inte fienden riktigt, om man går in i dem
för att strida, de försvinner ur bild."*

**Fienden som försvann.** Rotorsaken var inte ritningen: figuren står på sin ruta i våningen, och när
man går in i striden står man PÅ den rutan — kameran hamnade inuti figuren. `_stage_fight()` ställer nu
upp striden framför blicken (två i främre ledet, resten bakom), och backar in i spelarens egen ruta
om rutan framför är en vägg. `_place_bar()` flyttar healthbaren med figuren — annars stod staplarna
kvar där fienden stod först.

**Ett andra fel, hittat på vägen:** stridens FÖRSTA kort var helt tyst. `_enemy_reaktion()` läste sin
första mätning som "baslinje, ingen träff", så siffran och svepet uteblev för just det slag man tittar
mest på. Baslinjen sätts nu när striden börjar.

**Angreppet.** `game/ui/attack_fx.gd`: ett eget lager över 3D-vyn som ritar vapnet med `Control._draw`
och EN tidsvariabel — inga texturer, ingen scen. Formen kommer ur kortet:

| typ | kort | vad som ritas |
|---|---|---|
| klinga | Dagger, nagel | ett streck som skär genom bilden, bladet vid spetsen |
| piska | Lash, törne | en lång kurva som snärtar och rullar tillbaka |
| kross | klubba, knogjärn | en tung båge som landar med stötstrålar |
| ring | Choir Bell, hymn | ringar som slår ut från målet |
| glöd | Tome, krita, runa | en glimt som stiger vid målet |
| mjuk | dryck, salva | stilla gnistor — ett rustningskort ska inte se ut som ett hugg |

Färgen tas ur `CardView.TYPE_COLORS` (samma tabell som kortets kant). `P` (spela allt) ger ett svep per
kort, tätt efter varandra — solvern tömmer hela handen, och ett enda svep hade sett ut som ett kort.

**Mätfel på vägen, för de kostade tre vändor:**
1. `AttackFx.size` är `(0,0)` — föräldern är ett CanvasLayer utan layout. Svepet startade i skärmens
   hörn. Mätt med utskrift; ritas nu mot `get_viewport_rect().size`.
2. Siffran sattes i VÄRLDSKOORDINATER och hamnade olika högt beroende på avståndet: vid 0,8 m bakom
   figuren, vid 1,15 m uppe i stridspanelen. Nu räknas en SKÄRMPUNKT om till världen
   (`project_position`) och kläms in i den läsbara korridoren (y 0,34–0,76 av vyn).
3. Demobilden `03-kort-spelat` tas 0,07 s efter anropet, men kortet flyger i 0,14 s innan draget löses
   — siffran fanns inte i bilden. `04-slag.png` tas efter slaget.

**Kvar mot deras spel** (ur `research/07-arkitekturguide.md`): kärnan är samma maskin, skalen saknas —
relics, gems (byter kortets typ), arcanor, karaktärer, prestationer, combo-högen, revive, 13 av 21
stats, och tre kolumner på slutskärmen. Det är den långa resan.

**M12 — skalet: byn, banvalet och upplåsningen (2026-09-19 natt)**

Alex: *"Var står vi i utvecklingen? Vi behöver börja tänka på allt från startmeny, byn man har tillgång
till de olika ställen man kan köpa på sig hjältar, uppgradera items och såna saker, till en karta över
vilka banor man låst upp osv."*

Spelet började kasta spelaren rakt in i bana 1, och byn var en textruta ovanför `R = ny körning`.
Nu är byn navet:

- **`shell` styr skärmen**: `hem` (byn) · `butik` · `karta` · `körning`. Bara körningen ritar 3D-vyn.
- **Sparfilen (version 2)**: `unlocked` (lista), `best_floor` (bana → högsta våning), `runs`. En
  version 1-fil behåller guld och ranger och får första banan öppen — att gissa vilka banor spelaren
  klarat vore värre än att låta hen spela om en bana.
- **Upplåsningen följer svårighetsordning** (`_stage_order`): nästa bana är nästa i listan, och den
  låses upp när man NÅR sista våningen. Regeln är referensens: Pale Reaper dödar dig på sista
  våningen, så "klar" betyder "kom dit", inte "överlevde".
- **Kartan visar sju banor i taget** (grannarna synliga) med `▶` vald, `·` öppen, `×` låst, `sv1..sv9`
  och "klar"/"v2/3". En bana i taget gjorde kartan till ett bläddringsverktyg — mätt på bild och
  ändrat samma kväll.
- Tangenterna: `1` karta · `2` butik · `←/→` välj · `Enter` gå in · `Esc` tillbaka · `T` från
  slutskärmen till byn · `L` språk · `Q` avsluta.

**Två fel som bilden avslöjade** (båda osynliga i koden):
1. Panelen mättes medan etiketten var TOM → en liten ruta som texten flöt ut ur ("Q = avsl…" skars av
   vid skärmkanten). Texten sätts nu före placeringen.
2. En kvarglömd **stridspanel** (9×21 px) låg över första bokstaven i toppraden. `_refresh_stats`
   gömmer den under en körning, men skalet anropar aldrig den funktionen. Skalet göms nu uttryckligen.

**Kvar att bygga i navet** (ordning motiverad: varje steg behöver det förra):

1. **Värdshuset — medhjälpare som kort.** Alex: *"man kan köpa loss medhjälparhjältar som agerar som
   ett kort, med egna buffs (genererar hp, mana, attackstyrka eller ger en extra kort random att
   spela med så länge de används i kortleken)"*. Referensen (research/01 §5): Crawler-kort spelas ur
   handen, engångseffekt skalad av combo plus en passiv trigger per färg, och en Outhouse i
   dungeonen rekryterar en för 100–500 guld. Vår form: `data/crawlers/*.json` med
   `{id, pris, kort: {kostnad, typ: "crawler", effekter}, passiv: {hp, mana, might, draw}}`, hyrda
   sparas i `meta.hired`, och `_start_run` bygger startleken = baslek + hyrda kort. Passiven gäller
   en gång per tur så länge kortet finns i leken (inte per kopia i handen) — det är regeln som avgör
   om systemet går att balansera, och den ska prövas med två lekar som skiljer sig i exakt en hyrd.
2. **Smeden — små nodnät att köpa.** Alex: *"en möjlighet att uppgradera sina kort, lite som
   incremental gaming, där man har nod-nät av små incremental upgrades"*. Behåll EN köpväg:
   `data/powerups.json` får `branch` och `requires`, `Meta.can_buy` får skälet "kraver X", och
   trädet ritas som kolumner av noder. Många billiga noder tidigt, stigande pris (`cost: [10,25,60,
   140…]`), små effekter (+1 % per nod) — 40–60 noder blir en långsiktig sjunker efter de åtta
   basuppgraderingarna. Ingen ny köpkod: samma `Meta.buy` som butiken.
3. **Juveleraren — gems som byter kortets TYP** (inte "+2 skada"): gör Dagger till ett manakort och
   kedjan räknas om. Det är därför 61 kort kan kännas som 200.
4. **Museet — relics** som låser upp system, med prestationer som motor (prestation → relic → system).
   `meta.relics` finns redan i sparfilen och är tom.
5. **Karaktärsval** — Crawlers man spelar som, med egen startlek och eget HP.

**Skuld:** skalets texter är svenska tills vidare (`Tr.t(nyckel, "svensk text")` faller tillbaka).
13-språksfilerna genereras ur `tools/gen_i18n.py`, och en översättningsomgång görs när texten i navet
slutat ändras — att översätta text som ändras nästa kväll är arbete som kastas.

**M13 — Värdshuset: hjältar som egna kort (2026-09-20)**

Alex: *"man kan köpa loss medhjälparhjältar som agerar som ett kort, med egna buffs (genererar hp,
mana, attackstyrka eller ger en extra kort random att spela med så länge de används i kortleken)."*

Byggt som **två filer och en rad i körningen**, för kortmaskinen fanns redan:

- `data/cards/03_kamrater.json` — sex kort av typen `crawler` (Askhound, Wick Sister, Bell Ringer,
  Bone Carver, Tar Boy, Cinder Nun). De spelas som alla andra kort; combon och handen rörs inte.
- `data/crawlers/00_kamrater.json` — priset och den passiva verkan: `{id, price, passiv: {mana,
  hand, max_hp, might, armor, recovery}, text}`.
- `Meta.stat()` räknar in hyrda kamrater. **Det är hela kopplingen till striden**: HP, mana, hand,
  rustning, läkning och skada läser redan samma funktion, så ingen av dem behövde en rad kod.
- `_start_run` bygger leken som `DECK + meta.hired` — en rad.

**Regeln som avgör balansen:** passiven gäller så länge kortet finns i leken, **en gång per tur** —
inte per kopia i handen och inte per gång kortet spelas. Provet mäter det: två körningar som skiljer
sig i exakt en hyrd kamrat ger `base_mana` 4 mot 3, och inget annat ändras (`max_hp` 60 mot 60).
Sparfilen är version 3 (`hired`), och en äldre fil får tom lista = samma som en ny spelare.

Prislistan är stigande (300 → 1200) — första versionen hade 300, 500, 400, … vilket såg ut som ett
fel i butiken (sett i granskningen av bilden).

**M14 — Smeden: nodnätet (2026-09-20)**

Alex: *"en möjlighet att uppgradera sina kort, lite som incremental gaming, där man har nod-nät av små
incremental upgrades."*

`data/tree.json` — fyra grenar, elva noder med 1–3 ranger: **Järnvägen** (skada), **Benknippet**
(max-HP, rustning, läkning), **Glöden** (area, mana, handkort) och **Girigheten** (förbannelse: starkare
fiender mot mer guld). Små steg (+2 % per nod), stigande pris (40 → 2400), och `requires` som binder
nätet samman — Glödens mananod kräver både *Veke i bröstet* OCH *Härdat stål*, så grenarna hakar i
varandra i stället för att vara fem raka linjer.

**Ingen ny köpkod.** Noderna ligger i samma `defs`-lista som butikens åtta uppgraderingar, alltså
samma `Meta.buy`, samma `can_buy`, samma `stat()`, samma sparfil. Det som skiljer är `branch` och
`requires`: `village_lines()` hoppar över grennoder (butiken visar sina åtta), `tree_lines(gren)`
visar dem med förkunskaper. `can_buy` fick ett nytt skäl — `kraver`, med namnet på den nod som
fattas — eftersom "LÅST" utan att säga av vad är en återvändsgränd.

**Mätt i provet:** andra noden är låst och går inte att köpa förbi (`kraver (Slipad egg)`); efter köp
av första noden öppnas den, priserna dras (1000 → 960 guld), stegen läggs ihop (0,02 → 0,05) och
rangen stannar vid taket (3/3 → `full`).

**Ett fel sett på bild:** första versionen bytte ut priset mot `låst: X` på låsta noder. I ett träd med
stigande priser är priset det man planerar efter — nu syns båda.

**M15 — Kistan och facklan gjorde ingenting (2026-09-20)**

De ritades på kartan (kista och låga i minikartan) och genererades av `dungeon.gd`, men `Run.enter_node`
hade inget fall för dem: man gick in i en kista och det hände exakt ingenting. Samma sorts döda
innehåll som Ash Sovereign.

- **Kista**: guld (nodens eget värde × girighet) eller en läkning på 15 %. Tärningen är körningens seed
  och nodens position — samma kista ger samma sak varje gång, annars vore våningens determinism en lögn.
- **Fackla**: en andhämtning, 16 % av max-HP, aldrig över taket.
- **Målet**: `_next_objective` hoppade över båda. Kistan ligger nu EFTER fienden (en svag spelare ska
  inte lockas dit först) och facklan bara om man är under halv HP.
- **Händelserna tömdes bara vid kortval**: `_flush_events` anropades från EN plats i UI:t, så kistor,
  facklor och stridslut låg kvar i kön utan ljud och utan logg. Nu töms kön i `_after_state_change`,
  en gång per tillståndsbyte.
- `torch`-noden hade ett `gold`-fält som ingen läste (facklan läker) — borttaget, hellre än att lämna
  ett fält som ljuger om vad noden är.

**Mätt i UI-vägen**, inte bara headless: `-- kistprov` går till kistan och facklan med samma kod som
tangentbordet och skriver ut före/efter — kista: guld 0 → 25, fackla: hp 18 → 28 av 60. Headless i
`test_run`: 10 kontroller, bl.a. att samma seed ger samma kista.

**M16 — fem teman, tema per våning, och fienderna fick ansikten (2026-09-20)**

Alex: *"tonvis med grafik, en metod att byta grafik i editorn på banorna (…broar i gigantiska grottor,
tunnlar, katakomber), och fienden ser ännu rätt svårtydliga ut."*

Fältet `theme` har funnits i varje banas JSON sedan M2 och **ingen läste det**: alla 200 våningar
byggdes med samma fem rutor. Nu:

- **`tools/gen_tiles.py` skriver fem teman** × fem rutor (wall, wall_alt, floor, floor_alt,
  ceiling) till `assets/tiles/<tema>/`: **asklunden** (murverk + mossa), **krypta** (mörk mur +
  bennischer och gravhällar), **grotta** (organiskt berg + vattendrag), **tunnel** (jord med
  träbalkar och gruvlampa), **bro** (brädgolv + raserad planka där man ser ner i mörkret).
  `--sheet` ritar en kontaktkarta, för en tileset ingen sett på är en tileset ingen granskat.
- **Två rutor som blev fel på bild och rättades:** berget var en 8-px-checkerboard med
  salt-och-peppar-brus ("the same blocky, square grid texture" som kryptan) — nu en mjukad,
  wrappande brusyta bandad i tre tonsteg med ljus överkant och skugga under. Träets ådring var
  enstaka fläckar ("digital artifacting") — nu sammanhängande ränder per bräda.
- **Tema per våning:** `stages.gd` har `floor_themes`, och alla 40 banor fick en lista där sista
  våningen (bossen) ser annorlunda ut än trappan upp. Ordning: våningens eget (ritad karta) →
  banans `floor_themes` → banans `theme` → de platta reservrutorna.
- **Tonen följer temat:** rutorna är ostrukturerade, så temat läggs inte på ljuset utan på
  materialets färg och på bakgrunden — kryptan mörk och kall, tunneln varm, brons grotta svart.
- **Editorn (T/Y)** byter tema och ritar ritytan med **temats egna rutor**, så man ser valet i
  stället för att gissa. `mapio.validate` avvisar ett tema som inte finns, och temat sparas i
  kartfilen.
- **Fienderna:** ögonen var 1 px slitsar ("minimal directional cues") → nu håla + pupill + bryn;
  armar/hals fick en mörk skiljelinje mot kroppen ("layered body parts blend together"); nedersta
  tiondelen skuggas två steg i stället för ett. Svärmen var ett moln av prickar → fyra räkningsbara
  individer bundna av mörka länkar, och lågan fick en krage så kärnan skiljs från elden.
  `gen_enemy_art.py --check`: 17 fiender, 0 fel (sammanhang 100 %).

**M17 — ljuset och skuggan: våningen är mörk, lyktan lyser (2026-09-20)**

Alex: *"Kan vi bygga in någon form av skugghantering, ljushantering, så det blir lite stämning med?"*

Fram till nu var **allt ostrukturerat** (`SHADING_MODE_UNSHADED`), det fanns inga ljus alls och ingen
dimma: rummet såg likadant ut på en meters håll som tio, och "stämningen" var en färgton per tema.
Nu:

- **Lyktan i handen** — en `OmniLight3D` på kameran (varm 1,0/0,86/0,68, energi 2,6, räckvidd 9 m,
  mjuk falloff 1,4). Den är spelets viktigaste ljussiffra: för kort räckvidd och man ser inte rummet
  man går in i, för lång och mörkret (hela stämningen) försvinner.
- **Facklorna lyser** — ett eget ljus per fackla i våningen, med fladder i `_process` (två sinuser
  med olika frekvens per ljus, så ingen fackla brinner i takt med sin granne). En fackla som inte
  lyser är bara en bild av en fackla.
- **Omgivningsljuset är takten, inte en sol** (0,18–0,30 per tema) och **dimman** bär avståndet där
  lyktan tar slut. Materialen är matt yta, ingen spegling (`SPECULAR_DISABLED`), så pixelkonsten inte
  ser ut som plast när ljuset faller på den. Fienderna och sakerna är `shaded` — annars står de kvar
  i full belysning medan rummet runt dem är mörkt.
- **Skuggor** på lyktan (`shadow_enabled`, bias 0,06 — 1x1-block mot 1x1-block ger randiga skuggor
  med standardvärdet).

**Mätt, inte gissat.** Först såg ljuset platt ut på bild, så jag misstänkte att det inte fungerade —
därför mätflaggor (`-- lykta=6 omgivning=0.05 skugga=0`) och en riktig bildrutemätning:

| mätning | siffra |
|---|---|
| ljusavfall över våningen (krypta, lykta 2,6 / falloff 1,4) | nära 50,8 mot långt 18,0 → **kvot 2,8** |
| baslinje: platt ljus, ingen lykta (omgivning 1,0) | 30,4 mot 16,1 → kvot 1,9, 3D-vyn 20,5 |
| lykta 8,0 / omgivning 0,05 | 78,7 mot 25,0 → kvot 3,2 |
| fps, skuggor på / av / utan ljus alls | **61 / 62 / 59** |

Svepet som följde: en granskning av brons våning ("the brightest focal point is the inert wall on the
left") visade att en ljus ruta 0,5 m från kameran blir bildens ljusaste punkt. Falloffen är kranen —
`falloff` 1,4 → 2,0 och energin 2,6 → 3,0 gav kryptan 3D-medel 47,8 med kvarvarande lyktkrets och inget
utfrätt. Brons våning ligger kvar på 78,8: det är de ljusa träplankorna och den bleka grottstenen, inte
ljuset (samma inställning ger 47,8 i kryptan). Allt tre siffrorna är mätta med `-- shots ... <flaggor>`,
inte uppskattade.

Skugghanteringen kostar alltså ingenting som går att mäta vid 60 fps. Två egna fel på vägen:
`mat.specular` finns inte i Godot 4 (det är en Godot 3-nyckel: *"SpatialMaterial remapped parameter not
found"* — rätt är `specular_mode`), och den första fps-siffran togs med `Engine.get_frames_per_second()`
vid ett enstaka tillfälle, vilket gav "36 fps med skuggor, 1 fps utan" — alltså bara att mätningen
skedde efter ett väntande. Nu mäts hela körningen (`-- fpsprov`, 6 s ren rendering).

**M18 — 2.5D: normaler, råhet, metall och reflektioner (2026-09-20)**

Alex: *"kan vi sätta en 2.5d-känsla på all grafik, så kan ha normalmapping och liknande, så vatten
speglar sig lite, sånt som skall vara blankt ger viss reflektion, sånt som skall se ut som sten har
rough yte."*

Ingen shader, inget nytt beroende: Godot 4.7 har `normal_texture`, `roughness_texture` (+ kanalväljare),
`metallic_texture` och `Environment.ssr_enabled/ssao_enabled` — jag mätte upp vilka egenskaper som
finns innan jag skrev något (`ClassDB`-lista, inte gissning).

- **Materialkartor ur paletten.** `gen_tiles.py` skriver två nya filer per ruta: `<namn>_n.png`
  (tangentnormal ur höjden, Sobel, wrappande så kartan är sömlös som rutan) och `<namn>_orm.png`
  (glTF-ordning: R ocklusion, G råhet, B metall). Höjden och råheten kommer ur **palettens index** —
  i den här konsten ÄR tonen höjden (ljus = upphöjd, mörk = indragen), och råheten är spelets
  materiallära: sten 0,95 (matt), trä 0,72, ben 0,45–0,60 (halvblankt), **vatten 0,05–0,12**.
  25 rutor → 50 nya kartor, och `--check` fäller om en karta är platt, felvänd eller om vattnet har
  hög råhet (mätt: vattenråhet 0,05).
- **Vattnet fick egna palettfärger** (WATER/WATER_L). Tidigare ritades det med bergfärger, och då kan
  varken ögat eller materialkartan skilja det från sten — alltså kan det inte spegla något heller.
  Nu: strilande vatten på grottans väggar (och brons), en pöl i grottans golv.
- **Materialen** är `SPECULAR_SCHLICK_GGX` med råheten ur kartan (var `SPECULAR_DISABLED`): stenen
  förblir matt, pölen blir blank. **SSR** på (skärmbaserade reflektioner, steg 32) och **SSAO** på
  (radie 1,1 m) — AO:n är det som gör reliefen läsbar i fogar och hörn.
- **Rutorna sprids**: var sjätte golvruta och var åttonde väggruta får temats slitna variant (hashat
  per ruta och våning, stabilt). Två saker på en gång: våningen slutar se ut som upprepad tapet, och
  vattnet blir synligt på vanliga våningar i stället för bara i bossrum (där det är tvärtom — där är
  slitaget basen). Första försöket hade vattnet bara i alt-rutorna, och då syntes inget vatten alls
  på en brons våning: alt-rutorna användes bara i bossrum.
- Fienderna och korten får inga kartor: de är billboards och 2D-konst där en normal inte betyder något.

**Mätt:** 25 rutor, 0 fel (relief z 219–255 = normalen pekar ut ur ytan utan att vara platt,
vattenråhet 0,05). FPS med allt på 65, med allt av 62 (vsync avstängt) — kartorna, SSR och AO kostar
inget som går att mäta i den här körningen; bildruteloppet ligger självt kring 60 fps oavsett.

**M19 — Effekter: eld, rök, damm, droppar och blött vatten (2026-09-20)**

Alex: *"Vi behöver hitta ett sätt att ge vatten 'blöt effekt', men vi behöver även skapa effekter
(eld, rinnande vatten, rök, damm, såna saker). Kika på möjligheten."*

Först en mätning av vad motorn har (`ClassDB`-lista, inte gissning): Godot 4.7 har hela
partikelstacken inbyggd — turbulens med brus, färg- och skalgrader, emissionsformer, `anim_offset` —
och `NoiseTexture2D` med `as_normal_map`. Alltså inga nya beroenden, och bara en shader (se nedan).

- **`game/core/fx.gd`** — eld, rök, glöd, damm och droppar. Byggt ur tre saker: en `QuadMesh` som
  står mot kameran (billboard), en `ParticleProcessMaterial` för formen, och en färgskala.
  `vertex_color_use_as_albedo` är den rad som gör färgskalan levande — partikelns färg kommer in som
  vertexfärg, och utan den raden blir elden grå.
- **`tools/gen_fx.py`** — partikelkonsten (låga, rök, gnista, droppe) räknas fram som gråskala + alfa.
  Färgen kommer från färgskalan i spelet, så en fil räcker till både het låga och sval rök. Det var
  nödvändigt: en låga av mjuka runda prickar läses som en glödande kloss, inte som eld — formen gör
  elden. `--check` fäller om formen är en fyrkant, om lågan är trubbig i toppen eller om värmen
  ligger i överkanten (den kontrollen hade fångat att första lågan blev upp och ner; ögat såg det).
- **Vattnet blev blött.** Pölen är en tunn platta med rutan vatten i rutans EGEN form
  (`<ruta>_vatten.png`, alfa-mask) — inte en rektangel ovanpå vattnet. Krusningen är ett brus som
  NORMAL-karta och rullar med tiden; det krävde en egen shader (`spatial`, ~20 rader) därför att
  `StandardMaterial3D` inte har någon UV per textur: en rullad `uv1_offset` hade dragit iväg med
  pölens form också. Vätan ligger i råheten (0,05) och i att glansen vandrar — inte i metallen:
  `metallic` 0,3 i en mörk korridor blev bara mörkt och platt.
- **Droppar och rinnande vatten**: droppar faller från taket ner i pölen, och från väggen där vattnet
  är målat. Tyngden räknas ur fallsträckan (`g = 2d/t²`) och livstiden sätts så droppen dör när den
  når marken. Dammet sitter på kameran — det syns bara i ljuset, och ett korn i mörkret är ingenting.
- **Facklan blev en eldstad**: en cylinder i mörk sten under lågan. Utan den svävade elden i luften,
  och den gamla rutmarkören (en 8×8-ruta i facklans färg) låg kvar under lågan som en orange fläck.
- **Rutmarkören för facklor ritas inte när fx är på** — elden och ljuset ÄR facklan.
- **BUGG som hittades på vägen**: bossrummets slitna rutor var en nolla sedan M18. Bytet
  (`golv_alt if boss_har else golv_hela` …) gav exakt samma fördelning åt båda hållen; bossrummet såg
  alltså ut som vilket rum som helst. Nu är slitaget basen där (`golv_hela + golv_alt`).

**Nytt mätverktyg:** `-- fackelprov stage=X` går till facklan, tar två steg bakåt och vänder sig om.
Skälet: en fackla är en eldstad på en GOLVRUTA — står man på den har man lågan inne i huvudet, och
då mäter bilden ingenting. Det var precis vad första försöket gjorde.

**Mätt:** sviten 657 kontroller, 1 fel (kortikonerna, cron-jobbet betar av dem). Effekternas kostnad:
**52 ritanrop mot 39** (allt av), ~1 fps skillnad kring 66 fps, 19 partikelmoln = 6 facklor × 3 + damm
(472 partiklar). Bildrutor per sekund är inte nog som mått här — hela körningen ligger nära 60 fps
oavsett — så `fpsprov` skriver nu också ritanrop och partikelantal.

**Lärdomar:** (1) en fackla är en golvruta: att verifiera elden genom att stå på den mäter ingenting.
(2) GLSL kommenterar med `//`, inte `#` — med `#` slutade hela shadern att kompilera, tyst i spelet
men högt i provet. (3) Ett `--check` som inte SKRIVER något gjorde att jag mätte en gammal PNG: ögat
(som såg att lågan var upp och ner) hade rätt och min mätning mätte gårdagens fil. (4) Mörk rök mot en
mörk grottvägg syns inte alls; röken var tvungen att vara LJUSARE än mörkret omkring den. (5)
`turbulence_noise_speed` är en `Vector3` i 4.7 (bruset rör sig per axel), inte en float.

**Kvar att veta:** pölens form upprepas med rutan (2×2 per meter), så golvet läses fortfarande som
rutnät på håll — boten är fler rutvarianter och ett val per ruta, alltså en konstpass, inte mer kod.
Vattnet *rinner* inte som en film över väggen (droppar + blanka strimmor i stället; en film hade
täckt pixelkonsten). Och elden kastar inget eget ljussken på eldstaden — fackelns punktljus gör det.

## M20 — Läsbarheten på golvet (Alex: "jag vet inte vad det skall föreställa")

Alex tittade på två skärmbilder och sa att han inte kände igen sakerna på golvet. Han hade rätt, och
det var tre olika fel samtidigt — inget av dem i effekterna han frågade om.

**1. Nodmarkörerna var schackrutor.** Kistan, spaden och facklan ritades som en 8×8-schackruta i nodens
färg (en platshållare från första våningen). På håll och i vinkel läses den som ett brusmönster, inte
som en sak. Nu finns `tools/gen_props.py`: kista (välvt lock, band, lås), spade (T-handtag, blekt blad,
kontur) och benhög (död boss). Konturen läggs runt hela silhuetten — utan den smälter spaden in i
pölarna, som är lika bleka.

**2. Grottgolvet hade ljusa stenfläckar.** `berg()` målade tre tonsteg och den ljusaste (`CAVE_L`) täckte
**17 %** av golvrutan. En ruta upprepas 2×2 per meter, så varje fläck lästes som ett FÖREMÅL: "grå
kullar på nästan varje golvruta". Golvet är nu två ton (**0 % CAVE_L**, mätt) — väggarna behåller
kontrasten, där är ljuset rimligt.

**3. Pölarnas kanter var 1-bits dither.** Masken samplades `filter_nearest` utan mipnivåer, så
alfatestet (`m.a < 0.5`) vippade på måfå på håll: 18–24 "high-frequency noise patches" vid varje pöl.
Med `filter_linear_mipmap` föll kantenergin på golvet **23,9 → 20,3** och bruset är borta (vision:
"completely eliminated"). Ett `-- ssr=0`-prov visade att skärmreflektionerna INTE var orsaken (26,5 mot
26,7 — mätt, inte gissat).

**4. Vätan på bron lästes fel hur den än målades.** Blekt vatten på bruna plankor blir mögel, frost
eller färgspill ("chalky mould, spilled paint"); blött trä som mörknar blir en fläck utan betydelse.
Ett hål i golvet var nästa försök och är sämre — på en bro lovar en mörk lucka en fara som inte finns.
Bron har nu en NYARE planka (en bräda i ljusare ton med spikhuvuden): variation utan hot. Vattnet
stannar där det läses, på sten. Dropparna från väggarna är kvar även utan pöl — de låg bakom samma
tidiga `return` och tystnade med pölarna.

**Mätt:** 3 rekvisiter, 0 fel i `gen_props.py --check` (sträcka, silhuett, kontur, palett). Kontrollen
fälldes med flit-bort-metoden: en schackruta i stället för kistan ger 3 fel (sträcka 1,0 px, platta,
ingen kontur). Rekvisiterna finns i spelet och läses på två stegs håll (vision, båda våningarna).

**Lärdomar:** (1) `fx=0` är ingen isolerad brytare — den släcker facklornas ljus också, så 62 % av
bilden ändras och varje fx-diff blir meningslös. (2) Ett mått som inte får falsklarm är värdelöst: mitt
första "lösryckta pixlar" fällde diagonala konturer, och 8-grannar gjorde en schackruta
sammanhängande — rätt mått är STRÄCKLÄNGDEN på det som inte är kontur. (3) Konturen ska inte räknas in
i sträckan: en 1 px kontur är rätt, en 1 px form är brus.

## M21 — Takdropp: vatten, slem, blod och lava (Alex: "inte överallt, random takt")

Alex: *"kan vi ha någon form av fx emitter från taken där det droppar allt från vatten, slem till blod
och lava? Men inte överallt, utan random runtom på banan, i random takt?"*

Byggt på det som redan fanns: `Fx.droppar()` fick två parametrar — vilket SLAG som faller och vilken
TAKT stället har. Slagen är olika trögflytande (slem lever 0,85 s mot vattnets 0,5 s, alltså faller det
långsammare, eftersom tyngden räknas ur falltiden), blodet är mörkt och lavan glöder (adderande
blandning). Färgerna kommer ur spelets palett, inte ur nya bildfiler.

Placeringen: 3-6 ställen per våning, slumpade bland GOLVRUTORNA (att slumpa rutor och kasta väggarna
hade gett små våningar helt utan dropp). Varje ställe har sin egen takt, och materialets
`lifetime_randomness` gör att inte ens ett enskilt ställe tickar som en metronom.

**Mätt:** 3 ställen på `stage_05` v1 (slem ×2, vatten ×1) = 57 partikelmoln mot 54 med `tak=0`, utan
att fps rör sig (63). Över nio våningar fördelar sig slagen slem 26 / vatten 22 / lava 28, och samma
frö ger samma ställen varje gång (provat två gånger per våning i sviten). 53 kontroller i test_fx.

**Fällan som kostade mest:** fröet togs först ur `run.stage` — som är en RESURS. `hash()` på ett objekt
är objektets identitet, alltså olika varje körning: samma våning fick olika slags droppar varje gång
(mätt: slem×4+lava×1 mot vatten×2+lava×2). Fröet tas nu ur `run.stage.id` (en sträng).

**En andra fälla:** `GPUParticles3D` har `randomness`; `lifetime_randomness` sitter på
ParticleProcessMaterial. Gissat fel → SCRIPT ERROR, och i en `SceneTree`-test betyder det att `quit()`
aldrig nås och körningen hänger till timeouten (såg ut som "långsam", var död).

**Kvar att veta:** droppen splaschar inte när den landar — den slocknar (livstiden är satt så att den
dör i marken). En lava-droppe kastar heller inget eget ljussken på golvet; den syns bara som en glödande
prick. Båda är medvetet bortprioriterade (YAGNI) och lätta att lägga till om Alex vill ha dem.


## Regler som inte får glömmas

- **Namn och tillgångar är våra egna.** Inga kortnamn, sprites, musik eller varumärken från
  referensen. Kortnamnen i `data/cards/00_starter.json` är platshållare.
- **Balans mäts, inte tycks.** Varje ny mekanik får en rad i `tests/` som visar vad den gör.
- **Saven versioneras från dag ett**, annars blir varje balansändring ett supportärende.

## M24 — Upplösningen, ljuset och rekvisitan (mätt, inte tyckt)

Alex: *"kan vi öka upplösningen? 64x64 känns som ett block i minecraft"* och *"Diablo 1/2 i känsla
på allt med. Blod, funkt, smuts, trasiga föremål"*.

**Upplösning är tre saker, och förhållandet mellan dem är det som syns.** Räkningen: skärmens
punkter per meter vid avstånd d är `bredd / (2·d·tan(fov/2))`, med fov 70°. Vid 1 m gav 480 bredd
343 px/m, våra texturer hade 64 px/m — alltså **5,4× förstoring**. Referensen (Grimrock) ligger på
341 px/m. En större skärmyta ENSAM gör det värre (640 bredd med gamla texturen = 7,1×), så fönster och
texturer måste flyttas ihop.

- Rutorna: 32×32 → 64×64 per 0,5 m = **128 px/m**. Accepttestet: ny 64×64 nedskalad till 32 mot den
  gamla filen gav medel 2,44 gråsteg, värst 9,77, **0 av 45 över 20** — samma bild i dubbel
  upplösning. Tjugo rutor exakt 0,00.
- Rekvisitan: dukarna dubblerade (kistan 32×24 → 64×48, fången 30×46 → 60×92), `pixel_size` 0,016 →
  0,008 så världsstorleken står kvar, och **markfärgsgrinden är ny**: en kropp får inte vara ritad i
  markens egen färg (index 17). Det var felet som gjorde kedjefången osynlig i tre varv.
- Fönstret står kvar på 480×270 tills byn/kartan är omskriven — annars blir UI-verifieringen fel.

**Fällor mätta på vägen.**
- PIL:s `Image.NEAREST` väljer den **udda** pixeln i varje 2×2-par. Allt som ritades på det jämna
  paret försvann i jämförelsen, och det avslöjade ett riktigt fel: trappstegets mörka linje låg mitt
  över paret (tunnel/floor_crack 23,71 → 3,93 efter rättning).
- `_kontur()` i gen_props.py var död kod: den letade efter `None` där duken har `0`, så ingen rekvisit
  hade någonsin fått sin kontur. De som läser ritar sin INK för hand. Borttagen.
- `game/main.gd` delade vattenrektangeln med `32.0` — ruttätheten i den gamla rutan. Med 64 px-rutor
  blev pölarna dubbelt så stora och hamnade fel, tyst. Läses nu ur texturen själv.
- Två saker var tysta i spelvyn och larmade ingenstans: `pixel_size` och vattenrektangeln. Båda
  hittades av att en skrivare läste den andres antaganden, inte av ett prov.

**Ljuset.** Utgångsläget: SSR på, dimma på, men **ingen glow, ingen tonemapping**, och ambientljuset en
platt grå dimma på 0,25 (samma fel som mättes bort i andra projektet: ett platt ljus lyfter de svarta
partierna lika mycket som de ljusa). Ändrat: ambient 0,25 → 0,08 (mätt: mörkaste 5 % 4,0 → 2,0,
medelljuset stilla på 38,3 — djupare skuggor utan att bilden blev mörk), glow med tröskel över vitt,
och tonemapping AgX.

**Varför elden är platt, mätt i kod:** partiklarnas material är `SHADING_MODE_UNSHADED`, och en
unshaded yta skriver ut sin albedo rakt av — högst 1,0. En låga kan alltså aldrig bli ljusare än
vitt, och då har varken glow eller AgX något att arbeta med (mätt: 222 ljusa pixlar efter mot 225
före). Ett eget shader-material för lågan byggdes och **föll på sviten**: `test_fx.gd` gick på timeout
(681 kontroller → 634, exit 124). Revertat, grönt igen. `_yta()` är delad av damm, dimma och droppar,
så emissiv måste vara en parameter — och färgrampen kommer in som vertexfärg, som `StandardMaterial3D`
inte kan använda i emissionen.

**Blockeraren för allt eldarbete:** ingen bild jag kan ta innehåller en låga. Demon ställer spelaren
**på** nodens ruta och elden ligger i bäcken vid golvet (en tidigare design: *"elden står i bäcken,
inte i ögonhöjd"*). Första steget i nästa eldskiva är därför ett provläge som ställer spelaren
**bredvid** noden.

**Kvar och mätt (nästa skivor, i ordning):**
1. Rutorna har 128 px/m men **konsten använder dem inte**: vision säger "släta posteriserade
   konturfläckar, som kamouflage" i stället för murbruk, korn och mikrojsprickor. Ritad struktur i
   generatorn — fogar med hård kant, per-block-toner, korn per pixel.
2. Provläget bredvid en nod, sedan HDR-elden (med hängningen i `test_fx.gd` utredd).
3. Metall i ORM-kartorna plus en ReflectionProbe per våning — SSR kan bara spegla det som redan syns
   i bild.
4. Blod som kvarleva efter strid, sot och smuts i generatorerna, tunnor och lådor med en förstörd
   variant som lämnar bråte.
5. Dither-passet: hela bilden genom paletten med Bayer-dither. Det är steget som gör att modern
   belysning läser som SNES/Diablo i stället för som en modern renderare — och det är så originalet
   ser ut.
6. Fönstret 480×270 → 640×360, efter att UI:t är omskrivet.


## M22 — Vad referensen faktiskt gör (research: två rapporter)

Alex: *"Sök efter information om hur Referensspelet banor ser ut, hur de löst det osv"* + *"vi
behöver variationer på väggarna ... utveckla editorn så man kan lägga till fler olika delar, t.ex.
avgrund"*. Underlaget: `research/09-repetition-och-delar.md` (referensbygget, mätt med UnityPy mot
samma DwarFS-avbild) och `research/10-antirepetition-tekniker.md` (genren, URL per påstående).

**Referensens rum, mätt:** 67 `RoomTemplate`-prefabs; vanligast 2x2 celler (18 rum), sedan 2x3 och 3x3
(11 vardera); broarna är 1x22 celler trots namnet `_1x12`. Varje cell bär `PathfindingFlags`,
`ConnectionFlags`, `UseProcGen`, `IsExitCandidate`, `ExitDirection`, `ConnectsToNeighbours`. **420 av
774 celler (54 %) har `UseProcGen = 1`** — formen är ritad, innehållet genereras.

**Variationen sitter i VARIANTER AV SAMMA ROLL, inte i fler roller:** per biom finns **33–51
rut-prefabs i 2–3 lager** (Corridors 19–25, Rooms 14–19, Border 7), och `Rooms`-lagret är exakt 14
plattor i fyra av fem biomer. `DairyPlant_Corridor_Straight_01…07` är **sju ritningar av samma roll**.
Vi har fem rutor per tema. Det är gapet — och det är konst, inte kod.

**Varför vårt golv läser som tapet:** Grimrocks grid är 3x3 m med 1024x1024 px per 3x3 m (≈341 px/m).
Vi har 32x32 px per 0,5 m (64 px/m) — upprepningen sker alltså ~6 gånger tätare. Quilez teknik 1 (hash
per ruta) tar bort periodiciteten men **lämnar kvar rutnätets skala**; det var exakt vad M21 gjorde.
Botemedlet är att blanda mot grannarna nära kanten och att upprepa mindre ofta.

**Avgrunden är ett VISTA, inte en grop:** inget tillgångsnamn i referensen innehåller abyss/pit/void.
De har 22 `_Balcony_`-layouter med ett barn som heter `Balcony`, faux-skybox-shaders och räcken — och i
broarnas celldata är **åtta celler runt gången inerta (`ConnectionFlags = 0`)**. "Man kan inte gå ut" är
alltså DATA, inte en osynlig vägg. Botten finns inte som geometri någonstans i genren: Minecraft säljer
djupet med void-fog, och Godot gör samma sak med `fog_mode = FOG_MODE_DEPTH` + `fog_depth_begin/end`
(dokumentationen: slå på både vanlig och volymetrisk dimma för att dölja avlägsna ytor).

**Trötthet:** ingen belagd toleranstid finns. En masteruppsats mäter ändå skillnaden: statisk nivå gav
testare som var "fatigued by the environment" och spelade om mindre, randomiserad layout uppmuntrade
utforskning — medan loot-placeringen hade försumbar effekt. Källorna pekar på **form, siluett och
fokalpunkt** (landmarks) snarare än fler material.

### Besluten som följer

1. **Varianter per tema, inte en ny ruta per idé.** Varje tema får minst tre vägg- och tre golvvarianter
   (sliten, våt/mossig, sotig/sprucken) med samma roll, ritade i `tools/gen_tiles.py` där de andra görs.
2. **Större upprepningsavstånd utan ny konst.** En 64x64 "super-ruta" byggs som 2x2 av fyra VARIANTER
   och väljs per ruta med hash (texture bombing utan shader: en MultiMesh per super-ruta, fyra draw
   calls i stället för en). Kombinationen upprepar sig sällan trots att rutorna är 32x32.
3. **Avgrunden blir en ny ruttyp i kartformatet** (`~`), icke gångbar av sig själv — samma mekanism som
   referensens `ConnectionFlags = 0` — ritad som ett schakt av temats väggmaterial nedåt plus kant på
   grannrutorna, med `FOG_MODE_DEPTH` så botten aldrig syns. Editorn får den i sin palett.
4. **Vertikalitet är nästa stora drag, inte detta.** Grimrock II:s `PlatformComponent`,
   `HeightmapComponent` och `PitComponent` är vad som ger nivåer höjdskillnad; vårt rutnät är platt.
   Medvetet uppskjutet.

**Kvar att belägga (UNVERIFIED i rapporterna):** om golvet faktiskt saknas i referensens balkong- och
bro-rum (en inert cell är inte samma sak som att man kan falla — kräver mesh- eller skärmdumpsanalys),
vad `PathfindingFlags` och `ConnectionFlags` betyder bit för bit, rutnätets mått i meter, och om rum har
flera höjdnivåer.


## M25 — Reliefen, den målade kanten och lågan (allt mätt i EN körning)

Alex: *"Normalmapping funkar inte än, allt ser plattare ut än ett a4"* och *"facklans låga kan vara
mindre med, den behöver inte vara stor alls, bara den lyser upp rummet"*.

**Misstanken: de stora ytorna saknar kartor.** Mätt, och fel. Per tema finns 21 basrutor (8 av dem
super-rutor) och 21 `_n.png` + 21 `_orm.png`; de två rutor som inte har några är `*_vatten.png`, som
är PÖLMASKER (`vatten_mask()` i gen_tiles.py, läses som mask i `_vatten_och_eld`) och aldrig ritas som
yta. Namnbygget i `_add_boxes` (`ruta + "_n"` / `"_orm"`) är rätt, och körningen loggar
`provruta=super: 8 av 35 material i vyn, 8 bär en normal_texture, 8 en ORM-texture`. ORM-kartan bär
AO 0,78 / råhet 0,94 / metall 0,00 — ingen metallisk yta, och `ao_light_affect = 1,0`.

**Vad provet som föll faktiskt hittade.** `albedo, normal och ORM hör till samma ruta` jämförde en TOM
sträng mot en filsökväg: albedon var en KÖRTIDSKOPIA. Orsaken var `_kant_dämpad(tex, _kant)` med
`KANT = 1,0` — kanten dämpades genom att blanda albedon mot en 4× nedskalad kopia, och vid 1,0 är det
hela bilden som blir suddig. **Det var alltså spelets albedon som var suddiga, inte kartorna som
saknades.** Nu `KANT = 0,0` (samma texturresurs som filen, ingen kopia) och testet har en rad som
säger varför kontrollen ovan kan falla.

| super-ruta, en körning, samma kamera | \|a−b\| medel | p99 |
|---|---|---|
| brusgolv (samma inställning två gånger) | 0,195 | 1,0 |
| normal_scale 0 mot 4, suddig albedo (kant 1,0) | 2,173 | 38,0 |
| normal_scale 0 mot 4, skarp albedo (kant 0,0) | 2,055 | 46,0 |
| normal_scale 0 mot 10 respektive 20 (skarp) | 2,735 / 3,006 | 48 / 50 |

**Hypotesen "den målade kanten överröstar reliefen" är alltså mätt falsk.** Suddig albedo ger 2,17
mot 2,06 skarp — inom bruset. Dämpningen kostar konst och köper ingen relief. Reliefen SYNS (10×
brusgolvet i medel, 40× i p99) men taket är nära: fyra gånger ratten (4 → 20) ger +43 %. **Ytan läser
platt för att rummet är mörkt** (vyns medelljushet 0,077 — normalens bidrag växer med ljuset på ytan,
inte med skalan). Nästa mätning är lyktan, inte `normal_scale`. Kvar att belägga: om en starkare lykta
eller mer spegling gör reliefen läsbar utan att rummet tappar stämning.

**Lågan: ljuset gör jobbet, lågan visar varifrån.** Rutan 0,15×0,20 → 0,075×0,115 m med bibehållen
densitet (22 → 44 partiklar, test_fx kräver minst 30) och egen glöd `LÅGA_GLÖD = 2,0` i stället för
den delade `GLÖD_ENERGI = 4,0` (lavan i sjön använder samma siffra och är inte mätt här).

| lågprov, en körning | kärna px | glöd px | vit andel av kärnan | rum medel | rum p95 |
|---|---|---|---|---|---|
| 0,15×0,20 m, glöd 4,0 | 1088 | 3712 | 0,89 | 50,11 | 121,67 |
| 0,075×0,115, glöd 4,0 | 560 | 1444 | 0,86 | 48,76 | 121,67 |
| 0,075×0,115, glöd **2,0** | 448 | 1332 | 0,77 | 48,65 | 121,67 |
| samma igen (brusgolv) | 312 | 1264 | 0,74 | 48,81 | 121,67 |

Lågans yta en tredjedel (3712 → 1332 px), den utbrända kärnan från 0,89 till 0,77 vit, och **rummets
p95 identiskt 121,67 i alla sex bilderna** — samma ljus, mindre låga. Omni-ljuset (1,5 / 6,5 m) rörs
inte av något av detta.


## M26 — Ljuset på ytorna (reliefen var där hela tiden) och striden i rummet

Alex: *"2.5D-retro med MODERN ljussättning, Diablo 1/2 — ljuspölar, djupa skuggor, blänk i metall och
vatten. Ljuset ska upp där det träffar VÄGGAR OCH GOLV (facklornas räckvidd, spelarens egen lampa),
utan att mörkret tvättas bort."* och *"en strid måste ske i en separat scen i det rum man befinner
sig, så det inte blir att man kliver fram, och tittar genom fienden, och bara ser sina kort."*

**M25 lämnade frågan öppen: "nästa mätning är lyktan, inte `normal_scale`".** Nu är den gjord, och
svaret är ja. `LJUS_STYRKA` är EN faktor på lyktan i handen och facklorna (aldrig på
omgivningsljuset — det är takten, inte en ljuskälla), och normalprovets tredje ratt (`skala@kant@ljus`)
mäter den i SAMMA körning som A/B:t: samma yta, samma kamera, ett prov per ljusnivå.

| en körning, `provruta=super`, Forward+ | vyns medel | p50 | p90 | p99 | mörkt | ljust | relief-signal medel / p99 |
|---|---|---|---|---|---|---|---|
| ljus ×1,0 (före, lykta 3,0) | 0,082 | 0,043 | 0,226 | 0,477 | 81 % | 0 % | **2,32 / 46** |
| ljus ×2,5 (efter, lykta 7,4) | 0,125 | 0,073 | 0,356 | 0,605 | 65 % | 1 % | **3,50 / 74** |
| brusgolv (×2,5 två gånger) | 0,125 mot 0,125 | | | | | | 0,30 / 1 |

**Relief-signalen VÄXER med ljuset (+51 % vid ×2,5, +101 % vid ×4,0 i svepningen) — det är beviset för
att ändringen gör det den ska.** Ytorna var inte platta i data; rummet var för mörkt för att ögat
skulle läsa dem. Vyns medelljushet 0,082 → 0,125 (p50 +70 %), och mörkret finns kvar: två tredjedelar
av vyn ligger under 0,15 mot 81 % före. ×4,0 mättes också (+101 % relief) men lyser halva rummet — där
börjar stämningen gå förlorad, så 2,5 är vald. En bildgranskning av före/efter: "relief readability:
high clarity", "the darkest corners still dark".

**En ratt som inte når fram är ingen ratt.** `_fladdra` skrev lyktans energi varje bildruta, så en
första svepning gav samma bild hur ratten än stod (lykta 2,9 / 3,0 / 3,0 / 3,1 — fladdret, inte
faktorn). Nu går både världsbygget, fladdret och mätprovet genom `_ljus_styrka(f)`, och
`test_normalprov` mäter faktorn EFTER tio bildrutor — provet faller på 3,03 mot 7,50 om fladdret
tappar den igen.

**Striden sker i rummet.** Kamera-tweenen hann inte med stegen (0,10 s mot en bildruta per steg), så
striden började med kameran en ruta efter — mätt i demoläget: fienden 2,3 m bort i stället för 1,15 —
och spelarens ruta VAR fiendens. Nu backas spelaren till rutan FÖRE fienden, vänds mot den, och
kameran snäpper dit (`_snap_cam` dödar tweenen): fienden 1,15 m rakt fram, i bild, med rummet kvar
bakom. `tests/test_strid.gd` mäter det som ren logik (ingen rendering): spelarens ruta ≠ fiendens,
kameran i rutan före och riktad mot fienden i samma bildruta, och varje fiende innanför synfältet och
utanför närplanet. **Utan ändringen faller sju av tretton kontroller** (fienden hamnar 7,8 m bort och
utanför bildrutan — den kameran stod kvar i den gamla rutan).

En egen kommandoyta behövs inte: rummet syns runt panelerna, och kortens solfjäder ligger under
fiendens fötter. Kommer striden att behöva mer plats är det panelernas höjd som ska mätas, inte en ny
scen.

**Röken över lågan: ingen "blocky patch".** `rok.png` har alfa 0,000 i hela ytterkanten (och 0,039 i
ringen innanför), en vågig silhuett och jämn täthet — ingen fyrkant att se. Kantprofilen i bilden
ovanför lågan är jämn (medianraden har 0 hopp över 3 nivåer; de få rader som hoppar är takbjälkarna,
och samma hopp finns i kontrollregionen utan rök), och den volymetriska dimman lägger inte till någon
rak kant (kolumnkant 14,3 med dimma mot 15,6 utan). Dömdes "blocky" på en 4× förstoring av en 480×270
vy där varje bildpunkt är ett 2×2-block i fönstret — blockighet i förstoringen, inte i röken.

**Kvar att belägga:** blänket — BELAGT i M27 nedan: `light_specular` 0,0 → 1,0 med en TRÖSKEL på
ytornas ORM-råhet (0,80) ger högdagrar på mossen, sprickan och rekvisitan, medan stenen förblir matt
(p50 i vyn oförändrad 0,0941). Metallen på järnet och vattnet är däremot MÄTT BORT (de blev bara
mörkare, utan en enda ljus högdager).

## M27 — Glansen: `light_specular` mot ORM-kartans råhet (allt mätt i EN körning)

Alex: *"att ljus reflekterar på riktigt i metall, att vatten blänker mot ljus"*. Ljuset bar
`light_specular = 0,0` på både lyktan och facklorna ("ingen glans: rutorna är målade, inte polerade"),
så ingen yta kunde få en högdager hur blank den än var. Mätningen skulle svara på tre saker: går glansen
att slå på utan att stenen blir mjölkig, ska metallrekvisitan bära `metallic > 0`, och ska vattnet?

**Ratten är inte en siffra.** `StandardMaterial3D.specular` finns INTE i Godot 4: en skrivning till den
ger bara `Godot 3.x SpatialMaterial remapped parameter not found: specular` och gör ingenting. Mätt med
`ClassDB` på den här motorn (4.7.2): egenskapen heter `metallic_specular` och styr metallens F0.
Dielektrikerns F0 (4 %) är alltså FAST, och den enda ratten per material är `specular_mode`: AV eller
GGX. Det blev den första mätningens fall: glansen på en sten med 4 % spegling och råhet 0,94 ger en lob
som är nästan halvklotformad, och lyktan sitter 30 cm från väggen.

**Mätt A/B, facklan i bild** (`godot --path game -- glansprov`, Forward+, samma kamera, 0,25 s mellan
bilderna i samma körning; 960×540-vyn ur 1280×720):

| # | läge | medel | p50 | p99 | mörkt | högdagrar |
|---|------|-------|-----|-----|-------|-----------|
| 01 | glans 0,0, ytorna GGX (läget FÖRE) | 0,1720 | 0,0941 | 0,7634 | 59 % | 2334 px |
| 02 | glans 1,0, ytorna GGX (naiva fixen) | 0,2141 | 0,1464 | 0,7791 | 50 % | 2338 px |
| 03 | glans 1,0, alla ytor AV | 0,1779 | 0,0941 | 0,7712 | 58 % | 2398 px |
| 04 | **glans 1,0 + tröskel 0,80 (spelet)** | **0,1767** | **0,0941** | 0,7686 | **58 %** | 2314 px |
| 05 | tröskel 0,60 | 0,1775 | 0,0941 | 0,7673 | 58 % | 2426 px |
| 06 | + metall 0,7 på järnet (råhet 0,55) | 0,1757 | 0,0941 | 0,7647 | 58 % | 2382 px |
| 07 | + metall 0,7 (råhet 0,25 = polerat) | 0,1744 | 0,0928 | 0,7647 | 58 % | 2290 px |
| 08 | = 01 (brusgolv) | 0,1726 | 0,0928 | 0,7660 | 59 % | 2350 px |

**Den naiva fixen är mjölkig, och det syns i MEDIANEN:** 01 → 02 lyfter medel 0,1720 → 0,2141 OCH p50
0,0941 → 0,1464 — den mittersta bildpunkten i vyn lyfts 55 %. |01−02| är 19,8 i medel och 70 i p99 mot
brusgolvets 1,2 / 13,7. **Hela lyftet kommer från ytorna:** 03 (glansen på, ytorna AV) ger 0,1779 —
|02−03| = 17,7 / 65,3 — och 03 skiljer sig från 01 med 0,004 i medel, alltså ingenting. Det är
beviset för var mjölkhinnan satt.

**Därför en TRÖSKEL på materialets EGEN ORM-råhet** (G-kanalen, glTF-ordningen R ocklusion / G råhet /
B metall): en yta mattare än 0,80 får `SPECULAR_DISABLED`, en blankare behåller GGX. Sten ligger på
0,90-1,00 och blir matt; mossen (0,65), sprickan (0,68), benet (0,45-0,60), träet (0,72) och vattnet
(0,05) behåller sin spegling. **Mätt: 04 skiljer sig från 01 med 3,7 i medel och 57 i p99, medan p50 är
IDENTISK (0,0941) och de mörka går 59 % → 58 %** — glansen syns i de blanka ytorna, inte som en hinna
över rummet. Samma sak i pöl-läget (`-- stage=stage_12 vaning=1 glansprov=pöl`, 124 pölplattor, inga
facklor): 01 → 02 lyfter 0,1225 → 0,1473 (p50 0,0745 → 0,0928), medan 03 är 0,1224 med p50 0,0745 —
identisk med 01 (|01−03| = 0,23 i medel, 152 px). Där är spelet 04: 0,1334 och 71 % → 68 %.

**Metallen: ETT MÄTT NEJ.** `metallic` 0,7 på järndelarna (plattan, kransen, stolpen, foten) gör
rekvisiten MÖRKARE, inte blankare: |04−06| = 2,6 / 49,7 och |04−07| (råhet 0,25, alltså polerat järn) =
2,9 / 50,3, med bildpunkter ner till −126 av 255 och ingen ljus högdager i rutan — vision läser 06 och
07 som *"darker and flatter"*, inte som polerat. En metallisk yta tappar sin albedo till en spegling,
och i en mörk korridor finns inget att spegla. Råheten (0,55, mörk jämfört med stenens 0,94) är kvar;
metallen är 0. **Vattnet: samma nej.** `glans` 0,06 → 0,70 i pölens shader: 0,1334 → 0,1244 (p99
0,7503 → 0,6732), |04−06| = 4,1 med 25 512 mörkare bildpunkter och 96 ljusare. Vattnet speglar av SSR
och sin råhet 0,05 — inte av en metallkonstant.

**Vad som lyser i stället:** i asklunden (våning 1) har alla 11 ritade ytor råhet ≥ 0,80 och är alltså
matta; det som lyfts av glansen är rekvisitan och järndelarna runt facklan (vision: lådorna och
plattan vid facklan får *"crisp, directional specular sheen"*, medan fiende-spriten förblir *"flat,
matte"* pixelkonst), och i grotta-lyktläget (pöl-läget) är det de våta sprick- och mossa-rutorna
(11 040 ljusare bildpunkter, 0 % av dem i pölplattornas område — glansen ligger på RUTAN kring vattnet,
inte i vattnet). Ett mätt nej är ett svar: metallen och vattnet behåller sina värden, och glansen bor
där råheten redan sa att den skulle.

**Reliefen: ratten är mätt slut (M27).** Frågan var om reliefen kan höjas ytterligare utan att tvätta
bort mörkret. `normal_scale` är den ratt som INTE rör ljuset, och spelet står redan på 4,0. Mätt i EN
körning (`-- normalprov=4,10,20,4`, 35 material i vyn): medel 0,120 → 0,107 → 0,099, mörkt 67 % → 74 %
→ 77 %, och ljuspölarna KRYMPER (p90 0,346 → 0,310 → 0,286). Den extra reliefen betalas alltså med
ljuset på golvet — mörkret tvättas inte bort, pölarna äts upp — och den köper bara +43 %/+47 % i
reliefsignal (M26). 4,0 är knät. Hävstången för mer relief är ljuset på ytan, och den tog M26.

**Provet som håller det:** `tests/test_normalprov.gd` mäter att `light_specular` NÅR lyktan och alla
facklor, att speglingsläget på varje ritad yta följer regelns tröskel mot materialets egen ORM-råhet,
att ratten når alla 11 ytor i båda riktningarna (`_yta_glans_svep(-2.0)` / `(-1.0)`), och att ingen
järndel är metallisk. **FLIT-BORT** (glansen satt till 0,0 och regeln ersatt av "alla ytor GGX"):
provet faller på fyra av tjugotvå kontroller — lyktan, de sex facklorna, regeln (0 matta, 11 blanka)
och "stenen är matt" (0 av 11). Ask Lundens elva ytor mäter råhet 0,93-1,00, alltså precis över tröskeln.

**M28 — evolutionerna: två kort blir ett, och en mätare som mätte fel (2026-09-21)**

Referensens "combo/evolution" ligger nu som DATA: `data/evolutions.json` (17 recept) och
`data/cards/04_evolutioner.json` (15 nya kort — `emberstorm` och `the_long_winter` fanns sedan M4).
Motorn är `game/core/evolution.gd` och är fyra regler: receptet läses ur data; båda delarna tas ur leken
och resultatet läggs in (netto −1 kort — ett BYTE, inte ett gratis kort); ett halvt recept genomförs
aldrig; och ett val vars delar redan gått åt stryks ur kortvalet i stället för att fastna eller bli ett
tomt kort. `Progress.draft` hoppar över kort märkta `Evolved`: en uppgradering kommer BARA ur sitt
recept, annars vore "två kort blir ett" en etikett. Kortvalet erbjuder högst ETT per val (raden är byggd
för fyra platser) och roterar mellan färdiga recept med nivån som startpunkt — mätt i en körning erbjöds
3 av 3 möjliga recept, där bara det första i datat hade synts utan rotationen. Rubriken säger vad som
konsumeras (`UPPGRADERING: Axe + Ember Tome → Emberstorm`), för ett val som tar två kort utan att säga
det är en fälla (M12).

**Mätt före/efter i samma körning** (`tools/balance.gd -- 20 <bana> <rang> <evo>`, `evo` 0 = läget före
och 1 = uppgraveringen tas när den erbjuds; samma 20-korts startlek i varje körning):

| bana | uppgraderingar | nådde våning 2 | klarade banan | median skada |
|---|---|---|---|---|
| stage_01 (sv 1) | av | 0/20 | 0/20 | 464 |
| stage_01 (sv 1) | **på** | **4/20** | **4/20** | **692** |
| stage_05 (sv 2) | av | 16/20 | 4/20 | 199 |
| stage_05 (sv 2) | **på** | 18/20 | **16/20** | **388** |
| stage_09 (sv 3) | av | 7/20 | 0/20 | 117 |
| stage_09 (sv 3) | **på** | 9/20 | 1/20 | 52 |
| stage_09 (sv 3, rang 2) | av | 6/20 | 2/20 | 626 |
| stage_09 (sv 3, rang 2) | **på** | 17/20 | **17/20** | **926** |

2,2 uppgraderingar per körning i standardleken (dagger+vial och axe+ember_tome ligger i startleken;
resten kommer ur kortvalen). Fyra gånger så många klarade banor på svårighet 2, åtta gånger på svårighet
3 med rang 2.

**Mätaren mätte fel — två fel, båda mätta.** (1) `deck` delades av alla 20 körningarna och
`Run.pick_card` lägger till i samma lista: körning 1 startade med 20 kort, körning 8 med 34. Mätaren
mätte alltså 20 olika lekar som blev starkare av sig själva, medan standardspelaren börjar varje körning
från samma startlek (main.gd bygger en färsk hög per körning). Det förklarar varför den gamla kurvan såg
rimlig ut: ackumuleringen var en grov låtsasversion av kortvalen. (2) Kortvalen besvarades EFTER
`play_out()`, alltså efter körningen: leken i mätningen var alltid startleken och uppgraderingarna kunde
inte påverka något — mätt: identiska siffror med och utan dem (stage_05 5/20 mot 5/20). Nu drivs
körningen steg för steg och varje val besvaras när det kommer, som spelaren gör. Med den riktiga mätaren
är svårighet 1 (banan som ska vara lättast) **0/20 för standardspelaren — ett mätt nej som står kvar
här i stället för att gömmas**: kurvan för svårighet 1 är för hård, och det som lyfter den är
uppgraderingarna (0/20 → 4/20). Siffrorna i PLAN.md före M28 är lästa med den gamla mätaren.
**Rättat i M29:** 0/20 var inte kurvan — den handritade våning 1 bar svårighet 7:s boss. Efter ett
datafält i kartan är svårighet 1 17/20 (11/20 klarade).

**UI-vägen, inte bara kärnan** (`tools/play.sh -- kortvalsprov`, nytt prov): xp in, samma
`_check_level()` som `finish_fight()` kallar, `_refresh()`, `_show_draft()` — och svaret genom samma
`_on_draft_pick()` som tangenten och klicket använder. Mätt i körningen: `4 val, 1 uppgradering
["cinder_toss", "shove", "ash_veil", "emberstorm"]`; raden kräver 354 px och panelen är byggd för 354;
texten i valet `NIVÅ 2 — välj ett kort | UPPGRADERING: Axe + Ember Tome → Emberstorm`; efter svaret
leken 22 → 21 kort, delarna [4, 2] → [3, 1], `emberstorm` 1 i leken. Bild: `user://shots/kortval.png`
(vyn måste hinna ritas först — en bild tagen direkt efter start blev 2,7 kB helsvart mot 111 kB färdig).

**Ett mätt sidofynd: nyckelordens översättningar var döda.** Kortet slog upp `"kw." + nyckelordet`, men
datat skriver `Evolved` med versal och tabellen har `kw.evolved` — uppslaget missade och ALLA nyckelord
(3 × 13 språk) visades som engelska på kortet i varje språk. Mätt: 17 av 82 kort visade det råa ordet,
nu 0 (sv: "Uppgraderad", de: "Entwickelt"). Fixen är en bokstav i `Cards.describe()`.

**Proven som biter** (`game/tests/test_evolution.gd`, 48 kontroller): hela kedjan i 12 000 kortval
(0 läckta), bytet (netto −1, delarna borta, ett halvt recept genomförs aldrig, ett inaktuellt val stryks
i stället för att bli ett gratis kort), determinismen (samma frö → samma erbjudanden), att uppgraveringen
aldrig är svagare eller billigare än sin första del (17 recept rad för rad) och att nyckelordet står på
spelarens språk. FLIT-BORT, varje mekanism avstängd för sig: (a) `Progress.draft` släpper in
uppgraderingarna → 3 fall ("12000 val, läckta: 17 kort"); (b) delarna konsumeras inte → **9 fall**
("leken KRYMPER med ett kort (9 → 10)"); (c) erbjudandet i `_check_level` borttaget → 5 fall;
(d) gemenningen i `Cards.describe()` borttagen → 3 fall ("17 kort av 82").

**Sviten:** 1077 kontroller, 1 fel — det enda felet är `varje kort har en bild` (11 kort saknade konst
före, de 17 nya kommer efter; cron-jobbet äger dem).

**Kvar av M28:** gems, relics, arcanas, companions och EVO/NEW/×N-märkningen i valet (bara
recept-raden finns; "×N" och "NEW" är kvar).

**M29 — den lättaste banan gick inte att vinna: en ritad våning lånade sin boss av svårighet 7 (2026-09-21)**

M28 lämnade ett mätt nej: svårighet 1 = 0/20 för standardspelaren. Det stod kvar som "kurvan är för hård".
Det var fel, och felet var ett DATA-fält: **den handritade våning 1 för stage_01 hade `bellmother` som
boss — 900 hp, 20 skada, 6 ögon, tier 3, alltså bossen för stage_25-40 (svårighet 7) — i stället för
banans egen `hollow_choir` (400 hp, 12 skada, 4 ögon) som `data/stages/stage_01.json` deklarerar.**
Kartan skrevs som exempelkarta i editorns commit `7bc63a0` och bar sin boss som ett löst `enemy_id` per
nod; editorn sätter sedan dess bossen ur `Stages.boss_for(stage, våningsnr)`, så en karta ritad i dag
hade fått rätt boss — den gamla filen gjorde det inte.

**De tre kandidaterna mätta var för sig** (20 körningar, samma 20-korts startlek, standardspelaren):

- **(c) Mätarfel? Nej.** Den rättade mätaren (`tools/balance.gd`, färsk lek per körning, kortvalen
  besvarade medan körningen pågår) ger samma 0/20 som M28: `median våning 1 · nådde våning 2 i 0/20 ·
  klarade banan 0/20 · döda 20`. Siffran var sann.
- **(b) Startleken för svag? Nej.** En diagnos över hela eventströmmen (tillfälligt skript, raderat)
  visar att spelaren **vinner 13 av 14 strider på våning 1** och kommer till bossen med nästan full HP —
  körning 19: `hp efter strid [57,60,60,60,60,58,60,51,54,57,60,60,60, 0]`, alltså 60 hp in i bossen.
  Fienderna på våningen biter inte; det är en enda strid som tar allt.
- **(a) Motståndet för hårt? JA — och det var EN nod.** Spelaren möter den på våning 1, gör 200-650 skada
  och dör: `bellmother` har 900 hp. Median skada 464 i den gamla mätningen ÄR den skadan — allt kastades
  mot en boss som var 2,25 gånger för tålig och tillhör svårighet 7. Det förklarar också varför
  uppgraderingarna (M28) var det enda som rörde siffran: 0/20 → 4/20 var vägen förbi en felaktig boss,
  inte en kalibrering av kurvan.

**Före/efter, samma mätare och samma körningar** (`tools/balance.gd -- 20`, 12 banor på svårighet 1-3;
endast stage_01:s kartfil är ändrad, så övriga rader står still):

| bana (svårighet) | boss i våning 1 | före: nådde våning 2 | före: klarade | efter: nådde våning 2 | efter: klarade | median skada |
|---|---|---|---|---|---|---|
| stage_01 (sv 1, ritad våning) | bellmother → **hollow_choir** | 0/20 | 0/20 | **17/20** | **11/20** | 464 → 194 |
| stage_02 (sv 1, genererad) | hollow_choir | 19/20 | 10/20 | 19/20 | 10/20 | 247 |
| stage_03 (sv 1, genererad) | hollow_choir | 19/20 | 10/20 | 19/20 | 10/20 | 247 |
| stage_04 (sv 1, genererad) | hollow_choir | 19/20 | 10/20 | 19/20 | 10/20 | 247 |
| stage_05 (sv 2) | hollow_choir | 16/20 | 4/20 | 16/20 | 4/20 | 199 |
| stage_09 (sv 3) | hollow_choir | 7/20 | 0/20 | 7/20 | 0/20 | 117 |

Den handritade våningen mäter nu som sina tre genererade syskon (17/20 mot 19/20 nådde våning 2, 11/20 mot
10/20 klarade), och kurvan är inte längre OMVÄND: före låg den lättaste banan (0/20) under svårighet 2
(16/20 nådde våning 2). Var de dör efter fixen, ur samma diagnos: 11 av 20 når våning 3 (och dör för
`pale_reaper`, vilket ÄR att klara banan — `reaped`), 6 dör på våning 2 för `hollow_choir` (de kommer dit
med 10-60 hp) och 3 dör på våning 1 (två mot `hollow_choir` med 48 hp, en mot `skitterling` x3 med 6 hp).

**Ratten är kvar som data och kalibrerbar:** bossen står i banans `boss`/`final_boss` i
`data/stages/*.json` och i kartans bossnod för en handritad våning; inget tal ändrades i `run.gd` eller
`combat.gd` (fiende-HP, fiende-skada, recovery och startleken står orörda). Med uppgraderingarna på
(ratt 4, `-- 20 stage_01 0 1`) är samma bana 20/20 klarad med 60 byten på 20 körningar — mätarens egen
grind (≥15/20 når våning 2 och minst en klarar banan) ger nu `0 problem`, alltså inget "FÖR HÅRT".

**Provet som biter** (`game/tests/test_mapio.gd`, ny avdelning "varje ritad våning använder banans egen
boss", +5 kontroller → 27): varje fil i `data/maps/` läses, banan slås upp ur filnamnet och bossens
`enemy_id` måste stå i banans egen lista (`boss`, `final_boss`, `bosses`) och finnas i bestiariet.
FLIT-BORT (mätt): `bellmother` satt tillbaka i kartan → **1 fel**, `stage_01_0.json: bossen bellmother står
i banans lista (["hollow_choir", "pale_reaper"])`; med `hollow_choir` 0 fel.

**Sviten:** 1085 kontroller, 1 fel — det enda felet är `varje kort har en bild` (26 kort saknar konst,
cron-jobbet äger dem). `tools/gen_i18n.py --check` är grön.

**Kvar av M29 (mätt, men inte rört — det är kurv-arbete, inte ett fel):** svårighet 3 är 0/20 klarade på
alla fyra banorna och bara 7/20 når ens våning 2 (`median våning 1`), alltså nästa steg i kurvan. Och den
handritade våning 1 bär **13 strider** medan `stage_01.json` deklarerar `encounters_per_floor: 4` — det är
en smakfråga för Alex, inte en gåta: striderna biter inte (spelaren möter bossen med full HP), så
våningens längd är kvar som ratt.

**Besvarat i M30:** 0/20 var inte kurvan och inte heller en kalibreringsfråga — **hela packet stod i rad 0**
så alla fiender slog varje runda (frontrads-regeln i `combat.gd` användes aldrig i spel), och
`stage.xp_bonus` lästes av ingen. Och 13-mot-4 är inte den ritade våningens fel: **fältet läses per
mellanrum, inte per våning** — en genererad våning får 8 (deklarerat 4) respektive 10 (deklarerat 5).

**M30 — tre banor som var samma bana, frontraden som aldrig användes och fältet som inte betyder vad det heter (2026-09-21)**

Tre mätbara punkter lämnades från M29. Alla tre är mätta, och två av dem var fel i koden — inte i kurvan.

**1. De identiska siffrorna var inte en trasig väljare — det var samma bana i fyra filer.**
Hela svepet gav `stage_10`, `stage_11` och `stage_12` samma rad in i sista decimal (median våning 1 · nådde
våning 2 i 7/20 · klarade banan 0/20 · median nivå 3 · döda 20 · median skada 117). Roten är data: filerna i
en svårighetsgrad är **kloner** — alla fält utom `id` och `name` är identiska — och mätaren kör **samma 20
seeds (1000+i) på varje bana**, vilket är själva poängen (samma spelare, samma körningar, bara banan byter).
Det finns ingen väljare att peka fel: `Run` får sin `StageDef` direkt ur `Stages.load_all()`.
Mätt över alla 40 filer: **9 unika uppsättningar rattar** (det som styr en körning: `floors`,
`encounters_per_floor`, `tiers`, `boss`, `final_boss`), alltså är 40 banor 9 banor med 4-8 namn:

| rattuppsättning | banor |
|---|---|
| sv 1: 3 våningar, 4 möten, tiers [1] | stage_01-04 (4) |
| sv 2: 3 våningar, 5 möten, tiers [1] | stage_05-08 (4) |
| sv 3: 4 våningar, 5 möten, tiers [1,2] | stage_09-12 (4) |
| sv 4: 4 våningar, 6 möten, tiers [1,2] | stage_13-16 (4) |
| sv 5: 5 våningar, 6 möten, tiers [1,2] | stage_17-20 (4) |
| sv 6: 5 våningar, 7 möten, tiers [2,3] | stage_21-24 (4) |
| sv 7: 6 våningar, 7 möten, tiers [2,3] | stage_25-28 (4) |
| sv 8: 6 våningar, 8 möten, tiers [2,3] | stage_29-32 (4) |
| sv 9: 7 våningar, 8 möten, tiers [3] | stage_33-40 (8) |

Det här är avsiktligt: M2 byggde 9 svårighetsgrader och M4:s tabell räknar redan i grupper
(`stage_01–04`, `05–08`, `09–12`). Temat skiljer sig mellan en del grupper (`stage_09` är grotta hela
vägen, `stage_01` asklunden → grotta), men temat ritar bara våningen — **det rör inte en siffra**, så
mätaren ska ge samma rad för två banor som bara skiljer sig i tema.

Vad som ändrades: mätaren skriver nu `· SAMMA BANA SOM stage_10, stage_11, stage_12` på varje rad som delar
avtryck (`_avtryck()` i `tools/balance.gd`), så en klonad bana läses som ett faktum i stället för som en
trasig mätare. Provet ligger i `tests/test_dungeon.gd` (avdelning "en svårighetsgrad = en uppsättning
rattar"): varje svårighetsgrad 1-9 har minst en bana, och **samma rattar hör till EN svårighetsgrad** — den
felklassen M29 hittade (ett fält som pekade på fel band). FLIT-BORT (mätt): `stage_10` satt till
`difficulty: 4` med sv 3:s rattar → **1 fel**, `stage_09 (sv 3), stage_10 (sv 4), stage_11 (sv 3), stage_12
(sv 3)`.

**FLAGGAT till Alex (smakfråga, inte avgjord här):** att ett band är EN bana klonad 4-8 gånger betyder att
40 filer bara kan uttrycka 9 banor så länge fältuppsättningen är den här. Ska bandets fyra filer vara fyra
platser (Myrmarken ≠ Sävbräddan) krävs innehåll: egen fiendepool per bana (i dag bara `tiers`), egna rum
eller egen boss-ramp i `bosses`-listan (finns i formatet, används av ingen bana). Det är innehållsarbete,
inte kod.

**2. Svårighet 3: 0/20 — mekanismen var frontraden, inte kurvan.**
Diagnos över hela eventströmmen (tillfälligt skript, raderat) på `stage_09`, 20 körningar, standardspelaren:

| var de dör | antal |
|---|---|
| våning 1 | 13/20 |
| våning 2 | 7/20 |
| våning 3-4 | 0/20 |

**Vad som dödade dem:** tier-1-striderna kostar ≈0-3 hp (recovery 3 hp per vinst täcker dem), medan
tier-2-packet kostar 8-17 hp som ensam fiende och **15-52 hp som packet**. Spelaren har 60 hp, +3 hp per
vinst och 9,6 hp per fackla. Kostnaden per våning (5 möten + boss) är alltså ~45-100 hp mot en budget på
~35 hp per våning — och de dör på våning 1 med packet 15-92 % vid liv, alltså av **skadan per runda**, inte
av utebliven skada.

Roten var **ETT argument**: `run.gd` satte alla fiender i **rad 0**
(`Combat.Enemy.new(..., 0, def.eyes)`), och `combat.gd`s regel — bara den främre raden slår, nästa rad tar
över när raden framför fallit, samma regel som referensen (research/01 §6: "främre raden attackerar; nästa
grupp måste avancera innan den kan slå") — användes därför aldrig i spel: ett packet på tre slog tre gånger
per runda, och `Shove` (som knuffar bakåt) var verkningslöst eftersom `front_row` stannade på 0. Regeln var
byggd, kommenterad och provad i `combat.gd` — den nådde bara aldrig spelaren. Fixen är ett argument i
`run.gd` (`i` i stället för `0`).

Andra roten: **`stage.xp_bonus` lästes av ingen.** Fältet står i alla 40 bana-filer (0,0 på svårighet 1 och
stigande till 0,6 på svårighet 7+) och gjorde ingenting: en svårare bana var bara dyrare, aldrig rikare på
xp. Nu räknas det i `finish_fight()`.

**Ratt-matrisen** (alla rader mätta med samma mätare, 20 körningar, standardspelaren; varje ingrepp
tillfälligt och återställt). `nådde v2` / `klarade`:

| ingrepp på svårighet 3 (`stage_09`) | nådde v2 | klarade |
|---|---|---|
| baslinjen | 7/20 | 0/20 |
| tier 2 ur bandet helt (`tiers [1]`) | 12/20 | 1/20 |
| tier 2 först från våning 2 | 12/20 | 0/20 |
| `encounters_per_floor` 5 → 4 | 9/20 | 0/20 |
| `encounters_per_floor` 5 → 3 | 10/20 | 0/20 |
| `floors` 4 → 3 | 7/20 | 0/20 |
| packet 1-3 → 1-2 fiender | 7/20 | 0/20 |
| packet 1-3 → 1-1 fiende | 12/20 | 1/20 |
| `xp_bonus` läst | 8/20 | 0/20 |
| **raderna (roten) + `xp_bonus`** | **11/20** | **1/20** |

Och samma sak läst från andra hållet: ett **svårighet 2-band med tier 2 påslaget** (tillfällig fil
`zz_t05tier2`, raderad) ger 8/20 nådde våning 2 och 0/20 klarade, mot bandets egna 16/20 och 4/20. Det är
tier-2-bandet och packet som är väggen, inte banans längd — längden rör siffran med 0-3 körningar.

**Före/efter, samma mätare och samma körningar** (`tools/balance.gd -- 20`; "före" ur ett `git worktree` på
HEAD med samma mätare, så instrumentet är detsamma):

| bana (svårighet) | före: nådde våning 2 | före: klarade | efter: nådde våning 2 | efter: klarade |
|---|---|---|---|---|
| stage_01 (1, ritad våning 1) | 17/20 | 11/20 | **20/20** | **18/20** |
| stage_02-04 (1, genererade) | 19/20 | 10/20 | **20/20** | **16/20** |
| stage_05-08 (2) | 16/20 | 4/20 | 17/20 | **8/20** |
| stage_09-12 (3) | 7/20 | 0/20 | **11/20** | **1/20** |

**0/20 för standardspelaren är meta-grinden M4 beskrev — nu mätt med meta-axeln** (`stage_09`, 20
körningar, efter fixen):

| meta | förbannelse | nådde våning 2 | klarade banan |
|---|---|---|---|
| ingen (standardspelaren) | – | 11/20 | 1/20 |
| rang 1 | +28 % | 12/20 | 6/20 |
| rang 2 | +56 % | 8/20 | 5/20 |
| rang 4 | +99 % | 13/20 | 6/20 |
| rang 4 utan förbannelsen | +19 % | 19/20 | **16/20** |

Sista raden är den intressanta: uppgraderingarna bär svårighet 3 (16/20 klarade, median våning 4), men
**Girighetens förbannelse äter dem** — +99 % fiende-HP på rang 4 mot bara guld gör den grenen till en
självmotverkande affär för band 3. Det är mätt, inte åtgärdat: förbannelsens text och gren är Alex design
(`powerups.json`, `tree.json`, 13 språk), och en ändring där är en designändring, inte en buggfix.
Rang-4-utan-förbannelse-raden krävde ett tillfälligt hack i mätaren (`meta.ranks["curse"] = 0`, återställt).

**Kvar som rattar (mätta, inte rörda):** `recovery` (3,0), fiende-HP/skada-skalningen
(`hp_per_difficulty` 0,10 · `hp_per_floor` 0,15 · `damage_per_difficulty` 0,06) och
`enemies_per_encounter` [1,3] ligger kvar i `run.gd` orörda — matrisen ovan visar vad var och en är värd.

**Provet som biter** (`tests/test_run.gd`, två nya avdelningar, +7 kontroller → 34): "packet står i rader"
hittar ett möte med fler än en fiende, kräver att raderna skiljer sig och att spelaren tappar **mindre** än
packets sammanlagda skada i en fienderunda; "banans xp_bonus räknas" mäter EN dödad fiende och kräver
`xp_bonus 1,0` = dubbel xp. FLIT-BORT (mätt): radargumentet tillbaka till 0 → **2 fel**
(`[0, 0]`, `tappade 12 av 12 möjliga`); xp_bonus-raden borttagen → **1 fel** (`4 mot 4`).

**3. De 13 ritade striderna mot `encounters_per_floor: 4` — inte den ritade våningens fel, men fältets namn ljuger.**
Mätt: `dungeon.gd` läser fältet **per mellanrum** (rad 115/124/127: `min(stage.encounters_per_floor,
spots.size())` i varje rum mellan start och boss), alltså ger en genererad våning i praktiken **~2× det
deklarerade antalet**: `stage_01` (deklarerat 4) får **8 strider** per genererad våning, `stage_05` och
`stage_09` (deklarerat 5) får **10**. Den ritade våning 1 bär **13** — alltså 1,6× generatorns våningar, inte
3,25× som det såg ut.

Dom: **inte en bugg i den ritade vägen.** En handritad våning har sina noder i filen, och editorn skapar en
ny våning som tom ruta (`MapIo.blank`, `editor.gd` rad 224) — aldrig ur generatorn — så fältet har aldrig
nått en ritad våning. Kartans eget krav är `MapIo.MIN_ENCOUNTERS` (4), och ett tak ur `encounters_per_floor`
skulle ge en ritad våning **färre** strider än generatorns egna. Provet pinnar beslutet: 13 laddade av 13 i
filen, fler än de deklarerade 4, minst `MIN_ENCOUNTERS`, och generatorns våning följer fortfarande fältet.
FLIT-BORT (mätt): en trunkering i `MapIo.load_map` → **2 fel** (`4 laddade av 13 i filen`,
`4 ritade mot deklarerat 4`).

**FLAGGAT till Alex (två frågor, inte avgjorda här):** (a) fältet heter `encounters_per_floor` men läses per
rum — ska det byta namn (och de 40 filerna med det), eller ska generatorn mena per våning? Vilket som
väljs ändrar antalet strider per våning med ~2×, så det är en kurvfråga, inte en namnfråga. (b) Ska en
ritad våning förhålla sig till fältet alls — i dag bestämmer den sin egen längd, och de 13 striderna biter
inte (spelaren möter bossen med full HP även efter raderna).

**Sviten:** 1097 kontroller, 1 fel — det enda felet är `varje kort har en bild` (26 kort saknar konst,
cron-jobbet äger dem). `tools/gen_i18n.py --check` är grön. Provet i `tests/test_dungeon.gd` skriver
grupptabellen ovan vid varje körning, så klonerna syns i sviten och inte bara i den här texten.


## M32 — Kartan i marginalen och kistan som föremål (mätt, inte tyckt)

Alex (2026-09-21): *"Rutan med döskalle, strid, kista osv, den ligger nu i spelytan, den skall helst
vara ren"*, *"skulle vilja flytta även minimap upp till högra hörnet"*, *"Kistor försvinner när man
kommer nära, det får de inte göra"*, *"…och inte snurra när man själv snurrar"*.

### Minikartan och teckenförklaringen till marginalen

Kartan låg INUTI spelvyn (480x270) med orden som en remsa tvärs över dess övre halva. Nu ligger båda
i den svarta marginalen: kartan i fönstrets övre högra hörn, de sex orden i en kolumn under den.

| | före | efter |
|---|---|---|
| kartans plats | i vyn, rättad mot vyns kant | fönstret, @ 1122,6 vid 1280x720 (marginalen är 160 px) |
| ordens plats (mätt i skärmbild) | x 14..37, y 66..123 — vänstra marginalen, över statusraden | x 1149..1218, y 130..257 — under kartan, i högra marginalen |
| ordens storlek | 9 px (halva den ritade) | 18 px = ORD_FONT x skalans heltal |
| spelvyns yta | legendremsa tvärs över övre halvan | ren — kontrollen ligger utanför 480x270-rutan |

**Två fel i mätaren själv, båda rättade:** (1) `_placera_vy` kördes i `_bygg_vy` innan minikartan
fanns och hakar bara på fönstrets storleksbyte — ett fönster som STARTAR i 1280x720 ändrar sig
aldrig, så kartan stod kvar i (0,0) över statusraden tills någon drog i fönsterkanten. (2) En nod i
marginalen har ingen SubViewportContainer, och `UiText` räknade sin skala ur den: orden ritades inte
alls (eller i halv storlek). Båda syns bara i en skärmbild på mål-fönstret, och båda står nu i
`tests/test_minikarta.gd` (15 kontroller; FLIT-BORT ger 1 respektive 3 fel).

**Legendraden var 11 px och typsnittet 13:** "döskalle"s översta två pixlar gick in i kartan och en
rad med underlängd (polska "gracz") rörde raden under sig. Radhöjden är 14 (13 px bläck + 1 px luft),
mätt i `ui/textprov.gd` (4373 kontroller, 0 fel i alla 13 språk).

### Kistan: byggd geometri i stället för en skylt

`-- kistnara` mäter kistan från rutan intill och 0,1 m i taget in i dess egen ruta: djup mot
närplanet, rutan på skärmen, och hur många bildpunkter som ändras när noden göms (A/B med trädet
pausat, brusgolv 0 px). Samma prov kördes före och efter, med samma kamera.

| | före (billboard-skylt) | efter (byggd geometri) |
|---|---|---|
| på spelarens egen ruta | 4/4 hörn innanför närplanet, 0 av 1 px kvar — **kistan försvann** | 44 640 av 44 640 px i rutan ändras: kistan ritas, kameran står 0,5 m över en 0,45 m hög kista |
| bredden från fyra håll (1,50 m) | 66-66 px (förhållande **1,00**) — skylten snurrar med spelaren | 60-79 px (förhållande **1,33**) — kistan har sin egen orientering |
| efter plundring | noden bort, ingenting kvar | 12 noder kvar: locket står öppet (-100° kring gångjärnet) och insidan är mörk |

Kistan är byggd av primitiver (kropp, lock, två järnband, lås, fyra fötter, mörk insida när den är
öppen) i gruppen "kista", med färgerna ur paletten. Framsidan vänder sig mot rutan spelaren kommer
ifrån, så man möter kistans framsida och inte dess gavel.

### Rutorna i dubbel upplösning (M33, första halvan)

`tools/gen_tiles.py`: SIZE 64 → 128 (128 px per 0,5 m = 256 px/m). 320 rutor omskrivna, generatorns
eget accepttest grönt (den nya rutan är den gamla i dubbel upplösning, samma mönster och samma
fysik). Reliefen håller: |a−b| mellan normal_scale 0,0 och 1,0 är medel **6,09** / p99 **73** i
samma körning (M27 mätte 5,26 / 60 med 64-rutorna), och brusgolvet i samma körning är 0,39 / 1. Kvar:
**fienderna** (17 x 6 rutor, 40x40 → ~76-80) och de sista mätningarna av glansen mot den nya
texeltätheten.

**Sviten:** 1135 kontroller, 1 fel — bara `varje kort har en bild` (26 kort saknar konst, cron-jobbet
äger dem). `tools/gen_i18n.py --check` och `tools/gen_tiles.py --check` är gröna.

### Fienderna i dubbel upplösning (M33, andra halvan)

`tools/gen_enemy_art.py`: duken 40x40 → **80x80** för alla 17 fiender (480x80 per ark, sex rutor),
och `pixel_size` halverad i `game/main.gd` (0,036 → 0,018, boss 0,052 → 0,026) så att figuren har
**samma storlek i världen**: 80 x 0,018 = 40 x 0,036 = 1,44 m, och fötterna 27 x 0,018 = 13,5 x
0,036 = 0,486 m över golvet. Även de två ställen som mätte höjden över figurens mitt i dukpixlar
(8,5 → 17,0) följde med, annars hade healthbaren hamnat på huvudet.

Dubbleringen är en siffra, `S = 2`: formerna ritar kvar i sina 32 logiska pixlar och `put()` lägger
S x S i duken. Skälet är att silhuetterna, hållningarna och accenterna är mätta och dömda — att rita
om dem för hand vore att slänga de mätningarna. Det som blir finare är allt som ritas i dukpixlar:
konturen (1 px i stället för 2), ljusets band, markskuggan — och **`kanter()`**, som ger silhuettens
trappsteg dubbelt så många steg i stället för att varje steg blir dubbelt så stort. Regeln är att ett
blocks hörn-dukpixel tas bort när båda grannblocken vid sidan om är tomma och diagonalen är tom (ett
konvext hörn); är diagonalen fylld står pixeln kvar, för då håller den ihop en tunn diagonal.

Mätt, inte tyckt:

| | före | efter |
|---|---|---|
| duken | 40x40 (240x40 per ark) | **80x80** (480x80 per ark) |
| figurens höjd i världen | 1,44 m | **1,44 m** (oförändrad, räknat ur pixel_size) |
| fötterna över golvet | 0,486 m | **0,486 m** |
| formen | — | **94,8 %** av masken oförändrad mot före; de ~5 % som skiljer är hörnen som `kanter()` putsar |
| generatorns grind | 17 fiender, 0 fel | **17 fiender, 0 fel** (sammanhang 96-100 %, figur 10-25 %) |
| `test_assets.gd` | krävde 240x40 | kräver **480x80**, genomskinliga hörn och palettens färger |

Vyn är alltså inte ommålad — samma varelser, samma hållningar, samma accenter — men varje kant har
dubbelt så många steg och konturen är hälften så tjock i förhållande till figuren.

### Glansen mot den nya texeltätheten (M33, sista mätningen)

M27 ställde in glansen mot 64-rutorna: `light_specular` 1,0 och en TRÖSKEL på materialets egen
ORM-råhet (0,80) — mattare ytor får `SPECULAR_DISABLED`, blankare behåller GGX. Rutorna är nu 128 px
(256 px/m) och därmed dubbelt så täta, så frågan var om inställningen står kvar eller om
mjölkhinnan kommer tillbaka.

Samma prov, samma kamera, facklan i bild: `godot --audio-driver Dummy --path game -- -- glansprov`
(åtta lägen i EN körning, 960x540-vyn ur 1280x720; per-pixel |Δ| i 0-255, samma mått som M27).

| led | medel | p50 | p99 | mörkt | högdagrar |
|---|---|---|---|---|---|
| 01 före (glans 0,0) | 0,1932 | 0,1111 | 0,7634 | 56 % | 2920 px |
| 02 naiv fix (glans 1,0, alla ytor GGX) | 0,2458 | 0,2013 | 0,7830 | 46 % | 3616 px |
| 03 glansen på, ytorna AV | 0,1964 | 0,1137 | 0,7608 | 55 % | 2452 px |
| **04 spelet (tröskel 0,80)** | **0,1964** | **0,1137** | 0,7634 | **55 %** | 2920 px |
| 08 = 01 igen (brusgolv) | 0,1942 | 0,1124 | 0,7595 | 56 % | 2512 px |

| skillnad | medel | p99 | px över tröskel |
|---|---|---|---|
| 01 mot 08 (brusgolv) | 1,5 | 26,7 | 9 509 |
| 01 mot 02 (naiva fixen) | **13,6** | 70,3 | 211 996 |
| 02 mot 03 | 13,5 | 72,3 | 207 816 |
| **01 mot 04 (spelet)** | **1,2** | 24,3 | 18 512 |
| 04 mot 05 (tröskel 0,60) | 1,1 | 12,3 | 5 279 |

**Inställningen står kvar, och den står bättre än förut.** Mjölkhinnan är fortfarande verklig och
kommer fortfarande från ytorna (01 → 02 lyfter medel 0,1932 → 0,2458, alltså p50 +77 %, och 02 mot 03
är lika stor som 01 mot 02). Spelets eget läge ligger nu **under brusgolvet** (01 mot 04 = 1,2 mot
brusgolvets 1,5), där M27 mätte 3,7 mot 1,2 — med dubbelt så täta rutor är glansen alltså ännu
mindre av en hinna över rummet, medan de blanka ytorna (mossen 0,65, sprickan 0,68, benet 0,45-0,60,
träet 0,72, vattnet 0,05) behåller sin spegling. Ett mätt ja på att M33 inte kräver någon omställning
av glansen.

### HUD-ramen: den svarta marginalen blir nitade plåtar (M36, första halvan)

Alex: *"den svarta ytan behöver få en grafisk HUD, lite som diablo 1/2, men korten har central plats
nedtill"*. `game/ui/hud_ram.gd` ritar fyra band runt spelvyn (tak, golv, vänster, höger) som nitade
metallplåtar: plåt 48 px med fasade kanter, en söm runt om och fyra nitar i varje plåthörn, plus en
indragen fasad längs vyns kant (mörk skugga innerst, neutralgrå metallist utanför, mörk linje
ytterst). Ritad i kod ur `palette.json` — samma skäl som byn och världskartan — och i fönstrets
upplösning gånger heltalsskalan, så ramen läses likadant i varje fönsterstorlek.

Två fel som mätningen tog, och som är värda att komma ihåg:

- **En fylld rektangel som är vyns ruta uppväxt några pixlar målar HELA vyn.** Första versionen
  ritade skuggan så, och spelvyn blev palettens c(1) (medel 12,7 i stället för 54,7) — det går inte
  att sudda bakom en fylld ruta, så ramen ritar nu RINGAR utanför vyn och aldrig en pixel innanför.
- **Rutnätet måste ankras i bandets eget hörn.** Med plåtar på 192 px som låg i fönstrets rutnät
  visade 90 px-bandet bara två lodräta sömmar och inga nitar alls — plåtrytorna råkade hamna utanför
  bandet. Nu ankras rutnätet i bandet, och plåten är 48 px så två ryms i det smalaste bandet.

Mätt (samma scen, samma kamera, `-- stage=stage_01 shot`):

| | före | efter |
|---|---|---|
| marginalen | svart, medel 6,3 | plåtyta, medel 47,1 (403 200 px, 330 färger) |
| innanför spelvyn | — | **0,00 i medel, 0 px över tröskeln**: ramen ritar ingenting i vyn |
| test_hud.gd | 41 kontroller | **45 kontroller, 0 fel** (fyra band, banden = fönstret minus vyn, ingen överlapp, ingen marginal = inga band) |

Granskat på bild: i 1:1 läses marginalen som metallplåtar med sömmar och nitar (inte som platt
färg), och granskningen säger att den "skulle tåla lite mer kontrast" — kvar är orben (hälso-, mana-
och rustningsvisare), kortens centrala plats nedtill, och att lägga om de befintliga ytorna så att
ingen hamnar över spelytan eller över varandra.

### Kärlen: hälsa, mana och rustning som nivåer (M36, andra halvan)

`game/ui/hud_orb.gd` ritar en skål (pixelcirkel rad för rad, ingen halvton), fyller den till nivån
med en ljus ytlinje och en glans inne i vätskan, och sätter en stenkant runt om. Tre instanser:
hälsan till vänster, manan till höger och rustningen i vänsterkolumnen ovanför hälsan.

- **Hälsan** är `hp / max_hp` (stridens HP medan en strid pågår, annars körningens).
- **Manan**: taket är en KALIBRERING, inte en spelregel — manan växer under striden och har inget tak
  i motorn, så kärlet skalas mot grundmanan plus en hands manakort (3 + 4 = 7).
- **Rustningen** har ett riktigt tak: stridens startvärde. Nivån är alltså hur mycket rustning som är
  KVAR, vilket är exakt det spelaren behöver veta.
- Utanför en strid visas bara hälsokärlet: mana och rustning finns inte då, och ett tomt kärl vore att
  visa något som inte gäller. I byn/kartan göms alla tre.

Ett fel som mätningen tog: **radie 38 gav 168 px diameter och kärlet hamnade 14 px in i spelvyn**
(marginalen är 160 px bred vid 1280x720). Kärlen står nu i sidokolumnerna med sin mitt i marginalens
mitt, radie 34 → 152 px, och provet mäter att spelvyn är orörd: **0 px över tröskeln, medel 0,01**.

## M34 (första halvan) — Solfjädern: handen är en båge, inte en rad

Alex: *"korten ligger ännu på rad"* — och en rad är en hylla, inte en hand. Handen låg i en rak linje
med 6 % mellanrum, och `CardView` hade redan allt som behövdes: `home_rot`, en pivot i kortets
NEDERKANT (`_recenter_pivot`) och `glide_to(pos, rot, fördröjning)`. Ändringen är därför bara
geometrin i `_rada_hand` — tre konstanter:

`FAN_STEG` 0,055 rad vridning per kort, `FAN_OMLOTT` 0,62 av kortets bredd i sidled, `FAN_SJUNK` 0,07
korthöjder lägre per steg från mitten. Pivoten i nederkanten är det som gör att vridningen svänger
kortets ÖVERKANT utåt — det är därför en solfjäder ser ut som en hand.

Raden dömdes tidigare bort för att omlottet gömde grannens namn (elva pixlar mättes); i en solfjäder
är det meningen, och namnet läser man på det framträdda kortet (som växer 1,5× och visar effekten).

**Mätt** (`-- handprov`, nytt prov: går fram till en fiende, startar striden och skriver varje korts
plats och vinkel):

| kort | t | x | y | vinkel |
|---|---|---|---|---|
| 0 (vänster) | -2,0 | 479 | 604 | -6,3° |
| 1 | -1,0 | 536 | 595 | -3,2° |
| 2 (mitten) | 0,0 | 594 | 586 | 0,0° |
| 3 | +1,0 | 651 | 595 | +3,2° |
| 4 (höger) | +2,0 | 709 | 604 | +6,3° |

Bågen: ytterkorten 18 px lägre, 12,6° mellan ytterkortens vinklar. Steget i sidled är 57 px mot
kortets 93 = **omlott 35 px**. A/B: med radens konstanter (0 rad, 1,06 i steg, ingen båge) mäter
samma prov **0 px båge och 0,0° vinkelskillnad** — siffrorna kommer alltså från solfjädern, inte från
brus.

**Ett fel på vägen, i BÅDA versionerna:** andra raden i tvåradiga namn klipptes av. Namnrutan var 15
px hög och en rad på 7 px tar ~10, så "Deep Tome" och "Choir Bell" tappade nedre halvan av rad två
mot konsten. Rutan är nu 20 px (28 på det stora kortet); de 5 px:en tas från konsten, som har
EXPAND_FILL — kortets yttermått är låst av HAND_SIZE och blev detsamma.

Granskat på bild (3x närbild före/efter): båda raderna hela, konsten och kostnadssiffran oförändrade.
`test_hud.gd` mäter formen i stället för antalet: omlott 20–60 % av kortets bredd, mittkortet högst
och rakt, ytterkorten vridna utåt, och mittkortets underkant 6 px in i fönstrets nederkant.

**Kvar av M34:** draghögen uppe till höger, högen av använda kort till vänster, insamlingen tillbaka
till högen.


## M39 — Intro, splashscreen och startmeny (känslan från referensbilderna)

Alex: *"Här har du en intro och en splashscreen. Lägg in startmenyn för 'Nytt spel' osv enligt sista
bilden."* och *"Där har du även lite känslan jag är ute efter med vårt spel."* Två referensbilder (en
splash och samma bild med menyn) plus musiken `Dungeon Arpeggios.mp3`.

**Menyn** (`game/ui/huvudmeny.gd`): splashbilden i fönstret, fyra val i mitten, det valda valet markerat
med en brinnande dödskalle till vänster, version och copyright i botten. Raderna är Labels med
`MOUSE_FILTER_STOP` och två signalvägar — `mouse_entered` väljer, `gui_input` bekräftar — och både
tangenten och klicket landar i samma `bekräfta()`, så de kan inte glida ifrån varandra. Radernas x
räknas ur TEXTENS EGEN bredd (`font.get_string_size`), inte ur en fast ruta: märket ska sitta tätt
intill, och en fast ruta hade gett ett glapp som beror på översättningens längd. En rad som inte går att
välja (LADDA SPEL utan sparad körning) är mörk och SÄGER varför i bottenraden i stället för att tiga.

**Märket** (`tools/gen_meny.py` → `assets/ui/markor.png`, 23x21): första försöket (17x15) föll i
granskningen — *"ser snarare ut som en dödskalle i en lykta/arkadmaskin på en piedestal"*: lågan var en
rak trappstegsform, tänderna två prickar i hörnen och hjässans skugga läste som en metallist (färg 7 är
neutralt grå; 22 är varmgrå). Nu tre spetsiga tungor bakom en större skalle med sammanhängande tandrad.
`--check` mäter genomskinlig ram, att skallen och lågan finns och EXAKT symmetri — samma läxa som
kortbaksidan (2 997 osymmetriska pixlar).

**CRT-lagret** (`game/ui/crt.gd` + `crt.gdshader`): en ruta överst i HUD-lagret som läser skärmen med
`hint_screen_texture` och lägger tillbaka den med skanlinjer (`FRAGCOORD`, alltså varannan RAD i
fönstret — inte i 480x270-vyn, där ränderna hade blivit 2,7 px och vandrat med fönsterstorleken), vinjett,
välvd kant och färgförskjutning. Rutan tar ingen pekare.

Tre mätta fel på vägen, alla av samma slag — något SÅG rätt ut och var fel:
1. **Färgerna bytte plats.** Guldfärgad menytext blev GRÖN (mätt: (247,184,80) → (116,183,3)) och
   granskningen såg "spökmenyer". Orsaken: `TEXTURE_PIXEL_SIZE` är den vita standardtexturens storlek
   (1x1) för en ColorRect utan textur, så en "pixel" blev en halv skärm och R/G/B hämtades från olika
   delar av bilden. `SCREEN_PIXEL_SIZE` är den storhet som avses.
2. **Shadern kompilerade inte alls**: Godots shader-tokenizer tar inte svenska tecken i IDENTIFIERARE
   (`skärm`, `välvning` → "Tokenizer: Unknown character #228"). Kommentarer på svenska går bra.
3. **Panelen hamnade uppe till vänster**: `_place_panel` räknar i spelvyns 480x270, och ALTERNATIV-panelen
   är ett barn till `_runt` (fönstret). Den centreras nu i fönstret och läggs UNDER menyraderna — mitt på
   skärmen skymde den logotypen och de två översta valen.

**Två fällor med nya resurser** (båda kostsamma att felsöka): en ny `class_name` kräver en
importkörning (`godot --headless --path game --import`) innan typen finns — annars "Could not find type
Huvudmeny" följt av ett tiotal följdfel i helt andra filer. Och en ÄNDRAD bild används i sin GAMLA
version tills importen körs om: den bortklippta copyright-raden låg kvar i spelet efter att filen var
omskriven (mätt: randen med ljusa pixlar fanns kvar på y 684-704).

**Körningen sparas** (`meta.korning`): bana, seed, våning, HP, max HP, xp och leken som id:n — korten
byggs ur datat igen, så en sparfil som bara bär id:n inte kan ljuga om vad ett kort gör när datat ändras.
Skrivningen sker från `_refresh()` med en signatur som spärr (våning, HP, xp, lekens innehåll): utan den
skrev spelet sparfilen varje gång HUD:en ritades om. En avslutad körning tömmer läget, så LADDA SPEL inte
återupptar ett avslut.

**Mätt:** `tests/test_meny.gd` 36 kontroller / 0 fel (valen och deras ordning, splashbildens täckning,
märket till vänster om raden och i höjd med dess mitt, att det flyttar med valet, att en spärrad rad
säger varför, att ett RIKTIGT musklick öppnar panelen, CRT-lagrets läge/filter/överst-position och dess
av/på, musikstycket + slingan + av/på, att NYTT SPEL lämnar menyn för byn och tystar musiken, och att
LADDA SPEL ger tillbaka våning 3 med HP 37, xp 12 och 22 kort). `-- menyprov` fotograferar menyn,
alternativen och CRT-av och skriver radernas, märkets och musikens tillstånd. `-- fpsprov` **51 fps**
`-- fpsprov` **51-56 fps** över tre körningar (55-56 utan CRT-lagret ligger i samma spann — lagret
kostar alltså inte mätbart här), sämsta bildruta 25-47 ms. Vinjetten sänktes från 0,85 till **0,6**
efter en granskning av en SPELskärmbild (*"läsbar men på gränsen till för mörk"*): statusraden uppe till
vänster och korthögarnas hörn ligger där vinjetten är starkast. Hela sviten: 1220 kontroller / 1 fel
(26 kort utan bild, extern cron).


## M34 (fjärde halvan) — Kortstora kort, en baksida, och vändningen

Alex: *"staplarna med kort måste bli lika stora som korten är i spelet. Det får inte se ut som små
rektanglar. Sen behöver vi generera en baksida till korten, de som visas i staplarna innan kort är
draget. Korten skall representera de faktiska korten man har i handen, så har jag 12 kort i min
samling, så skall det finnas 12 kort, t ex 1 kort som är använt till vänster, 4 i handen och 7 till
höger osv. Korten skall ha en och samma baksida, så man inte ser vad som ligger härnäst på tur."*
— och sedan: *"Går det att få det som en animation, att den vänder upp kortet, och inte bara
placerar ut det?"*

**Baksidan** genereras: `tools/gen_card_back.py` → `game/assets/cards/_back.png`, 116×160 (2× av
kortets 58×80), ram i sten och metall, åtta nitar, ett benkranium. `--check` mäter fyra saker:
konturen är hel, inga genomskinliga hål innanför ramen (ett hål visar bordet genom kortet), motivet
finns (≥ 300 benpixlar) och **symmetrin är exakt** — en baksida som lutar ser ut som ett kort som
ligger felvänt. Första försöket ritade båda halvorna för hand och bröt symmetrin på 2 997 pixlar
(mitten av en 116 px duk ligger på 57,5, inte 58); nu ritas den vänstra halvan och speglas.
Granskad på bild (3×): *"en stiliserad dödskalle ... perfekt symmetrisk"*. En detalj rättades efter
granskningen: käken bands ihop med hjässan i sidorna, annars läses tänderna som en lös kam.

**Korten i högarna** har kortets storlek (`CardView.HAND_SIZE * HAND_SKALA` = 93×128 px, mätt i
provet mot handens egna kort) och **ett kort ritas per kort i högen**. Steget mellan korten räknas ur
hur många som ska synas: `spridning / (antal - 1)`, klämt mellan 1,5 och 6 px — fler kort ger
tunnare kant, aldrig färre kort. 18 kort i leken ger 18 kanter i en 136 px bred stapel.

**Kanten var det som saknades:** med bara förskjutningen flöt korten ihop till ETT kort, eftersom
baksidans ram och kortet under har samma färg (granskningen: *"ser ut som platta rektanglar"*, och
*"man kan räkna till exakt 17 kortkanter, vilket matchar siffran 17 undertill"* efter fixen). Varje
kort får därför en 1 px ljus kant och 1 px skugga på sin blottade sida.

**Vändningen** (`CardView.vänd_upp`): kortet kommer från högen med baksidan upp (en `TextureRect`
med baksidan överst i kortet), glider in på sin plats och vrids runt sin lodräta axel — `scale:x`
går till 0,06 och tillbaka, och vid noll byts baksidan mot framsidan. Pivoten ligger i nederkanten,
så vändningen sker kring kortets egen fot. Vändningen sker EFTER vägen in: att vända mitt i
glidningen gav en vinglig rörelse. Ett kort som kommer från högen delas INTE ut (`dela_in` hoppas
över) — det ska dras, inte delas.

**Mätt** (`test_kortbord.gd`, 20 kontroller / 0 fel): högens kort är 93×128 = handens; ett kort per
kort ger stapelns bredd; varje kort får en egen kant (2,54 px vid 18 kort); baksidan finns som bild;
ett kort som kommer från högen ligger med baksidan upp och visar framsidan efter vändningen; den
använda högen står på 1 efter ett spelat kort; omshufflingen flyttar den vänstra högen.

**`-- handprov`** fotograferar nu en hel SVIT under turbytets dragning (11 bildrutor, 0,1 s isär) och
skriver hur många kort som ligger med baksidan upp vid varje sampel — en enstaka bild kan träffa före
eller efter vändningen. Mätt: **5 av 9 kort** med baksidan upp 0,6 s in i turbytet, **0 av 9** efter
1,1 s. Bildruta 8–10 i remsan visar korten på väg från högen med baksidan upp, bildruta 11 alla
vända (*"man ser tydligt hur korten rör sig in från höger och visar baksidan under dragrörelsen"*).


## M34 (tredje halvan) — Kortborden: högarna och flyttarna

Alex: *"en animation som flyttar korten man har tillgängliga från en korthög i höger hörn, till
handen man håller i ... och sedan till vänster sida i en hög av 'Använda kort'. Korten skall sedan
samlas ihop och läggas i högen prydligt igen på höger sida."*

`Combat` hade redan `draw_pile` / `hand` / `discard_pile` med omshuffling — det som saknades var att
de SYNS. `game/ui/kort_hog.gd` (som `hud_ram` och `hud_orb`: ritad i kod ur paletten) ritar en stapel
kortbaksidor med antalet under; samma form i båda högarna, färgen skiljer (vattnet för leken, blodet
för de använda — samma färger som manan och hälsan).

- **Placeringen** är vald efter vad som är ledigt: minikartan med sin ordkolumn äger övre högra
  hörnet och kärlen står i botten, så högarna ligger på 0,62 av vyns höjd — i linje med varandra, och
  den spelade kortets väg blir en rak linje åt vänster.
  * ponytail: antalet läses ur `size()` på spelets egna högar i `_refresh_högarna` — ingen egen
    räknare som kan glida isär med leken.
- **Flykten** (`CardView.fly_out(mål)`): kortet flyger till den använda högens MITT och krymper in i
  den (0,45 ×). Utan mål flyger det rakt upp som förut — kortvalet och proverna har ingen hög.
- **Nya kort kommer från högen:** i `_refresh_hand` jämförs handens id:n med förra handens, och de
  nya börjar vid draghögens mitt, tonar in och glider till sin plats i solfjädern.
- **Insamlingen** läses ur SIFFRORNA, inte ur en händelse: blir `draw_pile` fler samtidigt som
  `discard_pile` blir noll är det omshufflingen, och då far den vänstra (tomma) högen över till den
  högra och tillbaka.
- **Två fel hittade genom att granska bilden:** stapeln med 2 px förskjutning lästes som "en platt
  enfärgad rektangel" (nu 3 px + skugga under varje kort + ljus överkant), och den tomma högen ritas
  nu i sin egen dämpade färg i stället för i marginalens svarta — granskningen såg bara en siffra.

**Mätt** (`test_kortbord.gd`, 14 kontroller / 0 fel, i ett fönster på 1280x720 — headless startar i
64x64, där marginalerna inte finns): högarna är gömda utanför en strid; siffrorna är spelets egna
(18 mot 18 i leken, 0 använda); efter ett spelat kort står den använda högen på 1 och handen är en
kortare; använda högens mitt ligger på x 80 och lekens på x 1200 (fönstret är 1280 brett, handen i
mitten); och omshufflingen flyttar den vänstra högen 767 px mätt mitt i rörelsen.

`-- handprov` fotograferar nu både FÖRE och EFTER ett spelat kort, och skriver korträknarens ruta i
siffror: `(178, 654) 140x60 = nederkant 714` i ett 720 högt fönster. Det var den mätningen som
avgjorde att räknaren satt rätt: den hade legat 8 px OVANFÖR fönstret ända sedan den flyttades bort
från hörnet, för `position` räknas från förälderns övre vänstra hörn även när ankaret ligger i
botten — nu sätts rutan med offsets mot bottenankaret.


## M34 (andra halvan) — Albumet: indexet över samlingen

Alex: *"Man måste kunna öppna som en index över alla kort man äger och se vad de gör om man
klickar/trycker på ett kort, och allt detta som om man öppnar ett album."*

En skärm i skalet, som butiken och smeden — men byggd som kortvalet: panel, etikett och en rad kort,
med en STOR visning också (i valet väljer man, i albumet läser man). Det stora kortet är `CardView`
med `big = true`, som redan visar namn, kostnad och effekttexten — alltså precis svaret på "vad det
gör", utan en enda ny textväg.

- **Öppnas med I i byn.** A/D är upptagna av platsvalet, och `ui.by.hint` fick `· I = albumet` så
  att tangenten syns (i alla 13 språk, se `tools/gen_i18n.py` — 301 nycklar, `--check` grön).
- **Listan är SAMLINGEN, inte katalogen:** rang > 0 eller hyrd kamrat. 82 kort finns i datat, noll
  ägs innan man handlat — och då säger albumet det i stället för att visa en tom rad.
- **Raden är sju kort bred med det valda i mitten.** En rad som växer med samlingen blir bredare än
  skärmen vid 41 kort, och då syns varken första eller sista kortet.
- Bläddring: ←/→ (och klick på en tumnagel), som går RUNT i båda ändar — en rad som tar slut tyst är
  en rad man fastnar i.

**Mätt** (`test_album.gd`, 13 kontroller / 0 fel): ett kort med rang 0 är inte med; listan står i
kostnadsordning; den stora visningen är det valda kortet; exakt ett kort i raden står framträtt;
bläddringen går från första till sista och tillbaka; albumet är GÖMT under en körning (och minikartan
framme i stället).

**Granskningsflaggan** `-- skarm=album shot kortprov=8` fyller samlingen med åtta kort ur datat i
fotoläget (skriver aldrig i sparfilen) — spelets egen sparfil har inga köpta kort, och ett album man
inte kan se fyllt går inte att döma. Bilden dömdes: "ALBUMET — kort 1 av 8", sju tumnaglar, det valda
lyft, inget klippt, och *"en tydlig album-/katalogkänsla"*.


## M37b — Bildrutan: spelet gick i 4 fps, och det var därför rörelsen var statisk

Alex klagade på att rörelsen var statisk, och `-- fpsprov` gav svaret: **4 fps, sämsta bildruta 148
ms**. Mätt i tur och ordning, för att inte gissa:

| misstanke | mätning | svar |
|---|---|---|
| GPU:n (skuggor, lyktor, partiklar, upplösning) | 320x180 gav samma 145 ms som 1280x720; skuggor av, lyktor av, takdropp av gav 4 fps | nej |
| Mätmiljön (Xvfb) | ett TOMT Godot-projekt på samma skärm gav **88 fps** | nej |
| V-sync mot Xvfbs låtsas-uppdatering | `--disable-vsync` gav 4 fps | nej |
| Skriptet | `Performance.TIME_PROCESS`: **241 ms per bildruta** | **ja** |

**Orsaken:** byn och världskartan ligger kvar i trädet under en körning (bara gömda), och deras
`_process` byggde om sina textrader i VARJE bildruta — `UiText.storlek_som_ryms` mäter text mot en
ruta genom att prova fontstorlekar från störst nedåt, och varje prov är ett anrop till textservern.
Två gömda vyer gånger ett dussin mätningar per bildruta = 241 ms. Minikartans ordkolumn byggde
dessutom en sträng av 400 noder varje bildruta.

**Åtgärden** (tre ställen, samma princip): en gömd vy har inget att visa — `if not
is_visible_in_tree(): return` först i `_process` (byn, världskartan, minikartan). `_process` går före
ritningen, så raderna är satta innan den första synliga bildrutan — ingen tom bildruta. Minikartans
ord byggs nu i samma gren som redan avgjorde om kartan behövde ritas om, och läget jämförs som ett
TAL (antal öppnade noder) i stället för en sträng av 400 tecken.

**Mätt efteråt:** 4 fps → **55 fps**, sämsta bildruta 148 ms → 29 ms, skripttid 241 ms → 24,7 ms.
Det är den siffran som gör M37 synlig: ett steg på 0,16 s är 9 bildrutor i 55 fps och 0,6 bildrutor i
4 fps — i den gamla farten kunde ingen tween kännas, hur mjuk den än var. `-- fpsprov` värmer nu upp
90 bildrutor först (skuggprogrammen kompileras och våningen byggs under de första sekunderna) och
skriver skripttid och fysiktid bredvid fps.


## M37 — Rörelsen: steget får en puff, svängen blir mjuk (allt mätt med `-- stegprov`)

Alex: *"rörelsen är alldeles för statisk. Det behöver nästan bli en zoom-effekt när man går framåt,
och någon form av mjuk rörelse när man svänger."* Kameran gled 0,10 s rakt igenom, likadant för steg
och sväng, och vinkeln räknades på tre ställen i `main.gd`.

**Två rena funktioner i `core/explore.gd`** (ägaren av `facing`), så att vinkeln blir en sak på ett
ställe:

- `yaw_for(facing)` — riktningen som vinkel (0 = norr, 1 = öster = -90° …).
- `närmaste_vinkel(nu, mål)` — målet lagt inom ett halvt varv från nuläget.

Den andra är en riktig buggfix, inte polish: från väster (facing 3, yaw -4,71) till norr (facing 0,
yaw 0) tog tweenen vägen **+4,71 rad i stället för -1,57** — kameran snurrade 270 grader fel håll.
Med 0,10 s gick det som en snärt; med en mjukare sväng hade det synts som ett fel. `test_run.gd`
mäter båda: `yaw_for` för tre håll, att väster → norr tar -1,57 rad, och att **ingen** sväng mellan
två håll tar mer än ett halvt varv (ett halvt varv är tillåtet — två svängar i rad möter man mot man).

**Känslan** (`main.gd`): kameran vet själv om det är ett steg eller en sväng — flyttar målet sig är
det ett steg. Steget tar 0,16 s och vidvinkeln öppnar sig 8 grader under första 40 % av steget och
stänger sig under resten (puffen ligger i SAMMA tween som positionen; en egen tween hade slagits med
den om kameran). Svängen tar 0,20 s och kränger 1,3 grader i sidled, ut och tillbaka. `_snap_cam`
nollar vidvinkel och rullning också — dödas en puff mitt i steget stod kameran annars kvar med öppen
vidvinkel eller sned horisont in i striden.

**Mätt** (`-- stegprov`, samplar var 40:e ms — tid, inte bildrutor, för i demoläget går körningen i
7 fps och då vore varje sampel ett helt steg):

| | utgång | +0,04 s | +0,08 s | +0,12 s | +0,16 s |
|---|---|---|---|---|---|
| steg: vidvinkel | 70,00 | 70,00 | **78,00** | 70,00 | 70,00 |
| sväng: rot.z (kräng) | 0,0000 | **0,0220** | 0,0020 | 0 | 0 |
| sväng: rot.y | 0,000 | -1,361 | -1,571 | -1,571 | -1,571 |

Svängen gick 0 → -1,571 rad, alltså kortaste vägen (-90°). Provet skriver också ut det: *"kortaste
vägen är -1,571 rad (-90 grader)"*.

Granskat på bild: skålarna läses som kärl med vätska; ett FULLT kärl (60/60 HP) såg först ut som "en
platt röd cirkel" i granskningen, och det är därför glansen i vätskan finns — den ritas bara när
nivån är över 0,35.

**Ytan: mörk, smutsig metall.** Alex dömde första versionen: *"inte platt å grått som det är nu"* —
och den var platt: en jämn färg per plåt. Nu ligger plåten på c(2) med c(3) som ljus överkant, och
smutsen är formad i stället för strödd: sot längs kanter och hörn, rinningar som börjar i översta
sömmen och rinner ned, fläckar i klumpar (en stor med två små intill) och en sliten ljus fläck mitt på
plåten. Fönstrets fyra hörn har en 45-gradig skärning. Allt ur ett deterministiskt brus (`_brus`), så
fläckarna ligger stilla mellan ritningarna — en HUD som rör på sig ser trasig ut.

Tre granskningsrundor gick åt: (1) jämn färg = "platt grå", (2) jämnt strödda prickar = "brus, inte
patina — patina klumpar sig, följer kanter och varierar i skala", (3) formad smuts = "i huvudsak
avsiktlig patina/sot", nitar och sömmar läsbara. Mätt: marginalens medel 47,1 → **36,2**, spelvyn
orörd (0 px över tröskeln).

## M40 — GUI:t enligt referensen: statusblock, logg och fienderuta (korten kvar i handen)

Alex' referensbild visar en HUD där ALLT ligger i marginalerna: porträtt och staplar uppe till vänster,
en loggruta nere till vänster, en fienderuta nere till höger, och spelvyn helt fri. Hans enda
invändning: *"Kom dock ihåg att istället för Action Bar så skall vi ha korten"* — alltså behåller
solfjädern i mitten nedtill, och referensens action bar byggs inte alls.

**Byggt.** `game/ui/hud_status.gd` (porträtt 48x48 ur `assets/ui/portratt.png`, ritad av
`tools/gen_hud.py`, plus HP-, mana- och ruststapel), `game/ui/hud_bar.gd` (rubrik + fylld del + siffror
PÅ stapeln — referensens `HP: 140/150`), `game/ui/hud_plat.gd` (den nitade plåten, samma yta som
HUD-ramen i M36), `game/ui/hud_logg.gd` (fyra rader, ring-buffert: den nyaste sist, den äldsta faller
ut) och `game/ui/hud_fiende.gd` (mål, namn, bild, livstapel).

**Mätt, inte tyckt.** `game/tests/test_gui.gd`, 36 kontroller, plus `-- guiprov` som mäter samma sak i
ett RIKTIGT 1280x720-fönster (i huvudlöst läge är fönstret 64x64 och vyn ryms inte — att mäta en layout
i ett 64 px fönster mäter ingenting, så provet hoppar över läget där och säger det). Mätt i guiprovet:
status (8,6) 430x78, logg (8,630) 262x84, fiende (1010,630) 262x84 — **0 px innanför spelvyn** för alla
tre. Fyllningen följer VÄRDET (halvt liv = halv stapel), och fienderutan faller tillbaka till `_to_lower`
på filnamnet.

**Fyra fel som mätningen fångade på vägen:**
1. `_refresh` gick FÖRBI stridens startväg: statusblocket och fienderutan stod kvar med förra stridens
   värden tills något annat rörde tillståndet (fienderutan var tom ända till dess `_refresh` kallades
   för hand i provet). Raden `_refresh()` finns nu i den vägen — det var ett fel i spelet, inte i provet.
2. Rutorna var 94 px höga men bottenmarginalen är 90 px: de gick 10 px in över spelvyn (provet föll på
   "loggen ligger UNDER spelvyn"). Nu 84 px, fyra loggrader.
3. Fienderutans livstapel räknades utan rubrikens 44 px och slutade 20 px utanför rutan: siffran
   "16/16" kapades till "16/1…" vid kanten. Mätt i granskningen av skärmbilden, inte gissat.
4. Tipsraden sattes med `position` på ett HÖGERANKARE och hamnade 166 px utanför vänsterkanten — den
   syntes inte alls i högerkanten. Marginalens placeringar sätts nu på ett ställe, i fönsterpx.

**Bort taget.** Statusraden och sifferpanelen (mana/kedja/rustning) ritas inte längre: samma siffror står
i statusblocket som staplar. De finns kvar som OSYNLIGA etiketter, för `-- shot`s lägesutskrift och
proven läser HUD:ens tillstånd som text ur dem — en skärmbild visar att något saknas, siffrorna visar
varför. Stridspanelen flyttade ur mitten av vyn (den skymde korridoren och fienden) till vyns övre
vänstra hörn.

**Status:** klar. Korten ligger kvar i solfjädern i mitten nedtill — ingen action bar.

## M40-fix — kortvalet låg över handen (Alex: "kortet flyttar på sig till vänster")

**Felet.** När valet kom upp medan handen låg kvar (ett dråp mitt i striden ger nivån) låg valpanelen
i vyns NEDRE del: valets nederkant på 630 px i fönstret, handens överkant på 586. 44 px överlapp — och
eftersom handens kort ritas efter valets stal det vänstra valkortet klicket. Provet före rättningen:
**4431 px överlapp**, två röda kontroller.

**Roten, två delar.**
1. Valkorten ligger i VYN (480x270) och handens kort i FÖNSTRET. Att mäta dem mot varandra utan
   omräkning gav "0 px krock" med 44 px verklig överlapp — samma fälla som `_placera_orbarna`
   hade, och skälet till att måttet står i fönsterpx i både provet och `-- vinstprov`.
2. `_show_draft` frigjorde de gamla valkorten med `queue_free()` UTAN att ta bort dem ur containern.
   `HFlowContainer` lägger ut alla barn den har, alltså både de döda och de nya korten under en
   bildruta: de nya hamnade till vänster och de döda låg kvar ovanpå dem. `remove_child` först.

**Rättningen.** Valpanelen läggs i vyns TAK (`at_top`), 100 px ovanför handen, och stridspanelen (som
annars står i vyns övre vänstra hörn) viker undan medan valet står uppe och kommer tillbaka när det är
gjort. Ny kontroll i `tests/test_gui.gd` (40 kontroller): inget valkort får ligga över ett handkort,
mätt i fönsterpx — provet fälldes med den gamla placeringen och går igenom med den nya.

**Vägen dit.** `-- vinstprov` (nytt): spelar ett kort i en strid, sätter XP-tröskeln ett steg under så
dråpet tippar över nivån, och fotograferar valet FÖRE och EFTER klicket med varje synlig kortvy
utskriven (ruta, alfa, förälder). Det gamla kortvalsprovet byggde sitt val på en påtvingad nivå mitt i
lugnet — utan strid, utan spelade kort och utan hög att landa i, och kunde därför inte se felet.

## M41 — världskartan: Alex' egen karta, vinklad, med nivåer och editor

**Önskemålet** (ordagrant): kartan i 16-bit, "lätt vinklad ... som i 3d-ish", fokus som följer
markeringen, noder som matchar punkter på kartan, en editor, upp till tio nivåer per nod med grön
bock för klar — och möjlighet att spela om en bana för att farma.

**Delningen.** `game/data/karta.json` äger bilden, vinkeln (zoom 1,9 / komprimering 0,82 / lutning
0,18) och nodernas plats i procent av bilden. `game/core/karta.gd` läser och VALIDERAR filen (en nod
utanför bilden, en bana som inte finns, en elfte nivå blir rader i `fel` — inte en nod som tyst inte
går att klicka på). `game/ui/worldmap_view.gd` äger bara det som bär information.

**Vinkeln** är ingen 3D-kamera: kartan ritas i 96 horisontella remsor, där varje remsa kläms ihop i
y-led och skjuts i sidled. En remsa är fortfarande en rak ruta på skärmen, så ingen shader behövs.
Kameran hänger på markeringen och kläms 0,35 av kartytan innanför kartans kant — med halva rutan
räknades nedre porten (88 %) ut till y=199, alltså BAKOM sitt eget kort (mätt: 13 px in i listen).

**Nivåpanelen.** Enter på en öppen plats öppnar nivåerna (Alex' tak: `Karta.MAX_NIVÅER` = 10); Enter
igen kör den valda nivån. En helt klar plats öppnar på nivå 1, så farmning är ETT Enter och inte en
runda genom panelen. Grön bock på klara nivåer och på klara platser.

**Editorn** (E på kartan): musen drar en nod, piltangenterna finjusterar 0,1 % i taget (samma
precision som filen sparas med — ett mindre steg avrundades bort och tangenten gjorde ingenting, mätt:
26,0 -> 26,0), och S skriver tillbaka till filen man LÄSTE. Noder kläms till 0..100 %, så editorn inte
kan skapa det laddaren kallar ett fel.

**Proven** (`tests/test_worldmap.gd`, 88 kontroller): kartfilen och dess fel, markeringen (närmaste
plats inom ±60 grader — kartan är fri, så "höger" betyder höger; hela kartan ska gå att nå), lägena,
en låst plats med besked, nivåpanelen och farmningen, att varje vald plats hamnar i kartytan och att
namnplaketten inte ligger i listen, samt editorn (flytt, kläm, sparande och omläsning).

**Mätt i bild** (`-- skarm=karta shot` och `-- skarmar`, dömt i 1:1 och förstoring): fyra platser
syns i vyn med kortet och teckenförklaringen läsbara, nivåpanelen har ram och markerad rad, ingen text
skär in i bården. Tre fel rättade efter granskningen: namnplaketten låg KLISTRAD mot kartbården, och
efter första rättningen INUTI kortet (klämmen gick till BAR-12 = 244, kortet slutar på 252 — nu
`KORT.position.y - 14`), teckenförklaringens märken var för små att döma i en nedskalad bild (1:1 och
förstoring krävs — då syns hänglås, cirkel och grön bock), och nivåpanelen flöt ihop med listen under
sig (tät fyllnad och ram runt om).

## M42 — byn är Alex' egen 16-bit-scen, och EXIT-skylten stänger spelet

**Önskemålet:** *"Kan du använda detta som by istället? Att gaten i mitten är för att gå ut till
strid?"* och *"Exit på bilden behöver vara till att avsluta spelet."*

`game/assets/ui/byn.png` (hans bild, 1280x720) ritas som byn, och platserna äger bara en x-position på
gatan i procent: smed 12 %, värdshus 35 %, **karta/porten 56 %** (vägen ut till strid), butik 76 % och
**avsluta 91 %** (EXIT-skylten). 463 rader ritad by (himmel, stjärnor, måne, åsar, gräs, träd, gata,
staket, hus, tak, skorstenar, rekvisita) är BORTA — kvar är det som bär information: märkena,
markören och etikettlisten med namn och status.

**EXIT-skylten är ingen skärm:** `_på_plats` i main.gd tar "avsluta" FÖRE kontrollen mot SKAL_LÄGEN och
gör samma sak som menyns AVSLUTA. Utan den ordningen blir platsen "okänd plats" och skickar spelaren
tillbaka till byn — tyst. Nycklarna (`ui.by.plats.avsluta`, `ui.by.status.quit`) ligger i
`HUD_RADER` i `tools/meny_i18n.py`, alltså i alla 13 språk, som resten av byn.

## Korten: större och aldrig genomskinliga i handen

**Felet:** korten blev halvtransparenta när man hovrade. Roten var inte hoverrörelsen: utdelningen
(`dela_in`) sätter alfan till 0,25 och driver upp den med SAMMA tween som hoverrörelsen använder — kom
pekaren in under utdelningen dödade hoverkoden upptweenen, och kortet låg kvar på 25 % synlighet hela
striden. `set_forward` sätter nu slutläget (alfa 1, skala 1) innan rörelsen börjar. Kortstorleken:
`HAND_SKALA` 1,6 -> 1,75 (93x128 -> 102x140 px i fönstret). `tests/test_kort_alfa.gd` hovrar ett kort
mitt i utdelningen och läser alfan — utan rättningen: tre röda kontroller.

## M43 — sektionerna: grinden mellan kartans delar

**Önskemålet** (ordagrant): *"vi behöver även föra så man inte kan gå till en del av kartan om man inte
klarat minst en bana av delen innan, det måste vara uppdelat i sektioner 1, 2, 3 osv."*

`karta.json` har nu `sektion` per nod (1..4), och `core/karta.gd` äger regeln: sektion 1 är öppen,
sektion N öppnar när minst EN bana i sektion N-1 är klarad (`sektion_klar`, `sektion_öppen`, `klarad`).
Grinden ligger i DATAN, inte i koden — han kan flytta en nod mellan sektioner utan att röra logiken.

**Sektionen ERSATTE banordningen på kartan.** Meta låser upp banor i svårighetsordning (stage_05 kräver
stage_04), vilket är finmaskigare än sektionerna: med båda grindarna hade sektionsgrinden aldrig varit
den som höll, och den hade varit osynlig — "det fungerar inte". På kartan gäller därför sektionen åt
båda håll: innanför en öppen sektion är varje bana spelbar även om meta inte låst upp den, och en
upplåst bana i en låst sektion är ändå låst. `_first_playable` och nivåpanelens statuskolumn följer
samma regel (provet mäter båda riktningarna).

**Beskedet namnger sektionen** ("LÅST — klara en bana i sektion 4 först") i stället för banan strax före
i svårighetsordningen — den ligger ofta i en helt annan del av kartan, och "klara Lavafallen först" vore
ett felaktigt svar på fel fråga. Kortets tredje rad visar sektionen: "SEKTION 4 · 4 nivåer · 0 klara".

**Editorn** (E) flyttar den valda noden mellan sektioner med tangenterna 1..9, och `skriv()` skriver
sektionen tillbaka till filen. Utan det sista hade editorn SUDDAT sektionerna varje gång han sparade en
flyttad nod (provet läser tillbaka filen och kräver att sektionen följde med).

**Proven:** `test_worldmap` 102 kontroller, där sektionsblocket mäter att en ny spelare bara har
sektion 1 öppen, att EN klarad bana i sektion 1 öppnar hela sektion 2 (men inte 3 och 4), att beskedet
bär sektionens nummer, att en upplåst bana i en låst sektion är låst, och att en bana i en öppen
sektion är spelbar utan att meta låst upp den. 1284 kontroller totalt, 1 fel (kortikonerna).

## M45 — bossens byte: tre kort, och de blir permanenta

**Önskemålet** (ordagrant): *"När bossen dör skall ett minigame ge en 3 kort att välja mellan, och sedan
skall det sparas i ens permanenta kort-samling. Kortsamlingen skall vara tillgänglig mellan alla banor."*

Kortvalet fanns redan, men bara vid nivåuppgång och bara i Leken för körningen. Nu:

- **Bossvalet** köas i `finish_fight` när noden är en boss (`Run._boss_draft`): tre kort ur datat, alltid
  tre (`Progress.draft` håller uppgraderingar och kamrater utanför). Egen händelse `boss_reward` och en
  egen rubrik i panelen, så det syns att det är ett byte och inte en vanlig nivå.
- **Permanensen ligger i `Meta.samla`**, och skrivningen sker i `Run.pick_card` — ETT ställe. Hade UI:t
  gjort det hade en autospelad körning (prov, demoläge) tappat sina bossval i tysthet. Sparfilen skrivs
  direkt när kortet valts, så en krasch mitt i körningen inte kostar det.
- **Samlingen är tillgänglig mellan banor** i ordets rätta mening: `main._start_lek()` = grundleken +
  hyrda kamrater + samlingen, och albumet räknar den som ägd (`_ägda_kort`). Två exemplar av samma kort
  är två kort, som i referensen.
- **Sparfilen**: `SAVE_VERSION` 3 → 4 och `samling` med i `to_dict`. En version 3-fil läses som förut
  med tom samling — provet mäter det, och att guldet och rangerna är kvar.

**Proven:** `test_run` svarar på varje köat val själv och jämför samlingen mot de val som FAKTISKT var
bossval: ett byte per besegrad boss, tre val, samlingen stämmer, den överlever sparfilen, och en vanlig
nivåuppgång hamnar INTE i samlingen. `test_meta` mäter dubbletter, kopian ur `samlade_kort` och
version 3-filen. `test_album` mäter att ett vunnet kort syns i albumet och ligger i startleken.
`test_progress` räknar nu leken som nivåer + bossbyten (förut "ett kort per nivå" — provet hade annars
mätt en gammal sanning).

## M44 — spaden klickas, och grävningen syns

**Önskemålet** (ordagrant): *"Sen behövs en animation när man gräver sig ner till nästa nivå med
spaden. Och spaden måste klickas på när man dödat bossen."*

Förut tog vägen IN i rutan spaden (`_enter_node_here` → noden → `descend()`), och våningen byttes utan
ett tecken. Nu:

- **Klicket.** `_vy_korg.gui_input` → `_vy_klick`: ett musklick i spelvyn som landar inom 26 px (vyns
  mått) från spadens projicerade läge gräver. Klicket fångas på korgen, inte i `_unhandled_input`,
  eftersom korgen STOPPAR musen.
- **Kravet.** `_spade_redo()`: bossen på rutan måste vara besegrad, inget kortval får vänta, och
  spelaren ska stå PÅ rutan eller på rutan intill och titta på den. Annars nekas klicket med en rad i
  klartext ("spaden ligger på bossens ruta — besegra bossen och stå där") i stället för att tiga.
- **Animeringen.** Kameran sjunker 1,2 m genom golvet (0,40 s) medan bilden svartnar (grävslöjan i
  HUD-lagret, över vyn men under texten), våningen byts MITT I mörkret, och den nya våningens kamera
  börjar där den gamla slutade och stiger upp medan ljuset kommer tillbaka. Mätt i `-- grävprov`
  (kamerans y och slöjans alfa var 40:e ms): 0,50 → -0,70 → våning 2 → 0,50.
- **Spaden är den ENDA saken i korridoren som klickas** — allt annat sköts med tangenterna. Ett klick
  som gör "något" någon annanstans är ett klick spelaren inte kan förutse.

**MÄTT FALLA (två gånger, samma prov):** (1) `unproject_position` svarar (0,0) och skriver "Condition
p.d == 0" när spaden ligger UNDER spelaren — den som står på rutan kan inte projicera den, och klicket
hamnade i hörnet. `_spade_på_bild()` faller då tillbaka på mitten av vyn: man står på spaden.
(2) Provet byggde bossstriden för hand (`begin_fight`) i stället för `enter_node`, så bossen stod kvar
OKLARAD och klicket nekades av RÄTT skäl — ett prov som fejkar halva vägen mäter fel sak.

## Demoläget stod still (pre-existerande, hittat på vägen)

`-- shots` "körde" en strid som aldrig hände: `_on_play_all()` och `_on_end_turn()` är koroutiner, och
anropades utan `await`, så demon gick igenom sina 30 varv i EN bildruta medan fienderna stod orörda —
och bröt efter 8 bilder med ett tomt utfall. MÄTT: "striden står still efter 31 turer — fiende-hp 16 av
16", och samma sak på förra commiten (alltså inte från M44). Med `await` spelar demoläget HELA
körningen: 256 bilder, "reaped" på våning 3, och den klickar på spaden både på våning 1 och 2.

## Trädet in i körningen (M44, bevisat på nytt)

Trädet byggdes i `e8a450b` (smeden, 4 grenar och 12 noder i `data/tree.json`), men beviset stannade i
Metan: `test_meta` mätte köp, krav och tak. Att en permanent uppgradering ÄR permanent betyder att
körningens siffror följer den, så `test_run` bygger nu två körningar på samma meta — före och efter
köpen — och jämför talen HUD:en visar:

    max-HP 60 -> 64   (Tjockt skinn)      mana 3 -> 4   (Andra lågan)
    hand   4 -> 5     (Fullt bloss)       skada 0,05    (Släpad egg + Härdat stål)

`data/tree.json` har fyra grenar: Järnvägen (skada), Benknippet (HP, rustning, läkning), Glöden (area,
mana, hand) och Girigheten (fiende-HP och guld). Kostnaden är guld, samma mynt som butiken och
värdshuset — ett träd med en egen valuta hade varit en andra plånbok att hålla reda på.

## Valkortet hoppade till vänster (Alex två gånger, M44-fix)

Alex: *"Kort hoppar ännu till vänster när man försöker välja dem."* Och samma sak tidigare: *"kortet
flyttar på sig till vänster, och täcker över det som låg där innan."* Förra försöket tog symptomet
(`remove_child` före `queue_free`, så containern inte la ut både döda och nya kort) — den här gången
mättes orsaken:

- **Hemmplatsen.** `CardView` räknar både svikten (`_vik`) och lyftet (`_väx`) ur `home_pos`. Handens
  kort får sin av `_rada_hand`, men ett kort som en CONTAINER lägger ut (kortvalet) hade ingen — den
  stod på `(0,0)`, alltså containerns övre vänstra hörn. MÄTT i `-- vinstprov` med pekaren över ett
  valkort: **x 179 → −21** (200 px in i grannen), och höjden 118 → 177 px.
- **Fixen, på ett ställe:** `set_forward(true)` tar hemplatsen ur läget containern gav kortet när
  föräldern är en `Container`, och `målsize()` låter ett valkort (`big`) behålla sin storlek — i en
  jämn rad skjuter en växt kortet både in över grannen och ut över panelens ram, och kortet visar
  redan hela sin text. MÄTT efteråt: **0,00 px** i sidled, **0,00 px** i höjd.
- **Verktygstipset** (den inbyggda rutan med namn, kostnad och effekt) stängs av för valkort: i
  panelen ligger korten i en rad och visar sin text själva, och tipset blev en ruta ovanpå en granne
  (mätt: `PopupPanel` "Ash Veil (2) +12 rustning" över Emberstorm). I HANDEN är det kvar — där gömmer
  omlottet namnet.
- **Provet biter:** `test_kortrorelse` har en fas `valkort` som lägger ett kort i en `HFlowContainer`,
  pekar på det och kräver att position och höjd står stilla. Utan fixen: 23 px i sidled och 65 px i
  höjd = 2 fel. Med fixen: 0,00 px = 0 fel.

## Spaden gick inte att klicka på (Alex: "Det går inte att klicka på spaden")

Alex: *"Det går inte att klicka på spaden. Går man för nära försvinner den."* Två fel, båda mätta:

- **Klicket kom inte fram.** `gui_input` ger `event.position` i kontrollens LOKALA rum = vyns px
  (mätt: ett klick i fönstret (640,554) kommer in som (240,232), exakt). Koden delade med
  `_vy_korg.scale.x` en gång till — skalningen 2 — så avståndet blev 145 px i stället för 0 och
  klicket nekades TYST. OCH: `-- grävprov` bevisade klicket med ett eget `InputEvent` där skalningen
  delats bort i förväg, så provet mätte sin egen omräkning. Provet skickar nu ett RIKTIGT musklick
  (`Input.warp_mouse` + `get_window().push_input`) och FALLER (exit 4) om våningen inte byts.
- **Spaden försvinner när man står på hennes ruta** — det är geometri, inte ett fel: en
  förstapersonsvy kan inte visa det som ligger under fötterna. `unproject_position` svarar dessutom
  inte (0,0) utan ett påhittat tal utanför frustumet (mätt: (240,135) mot rätt (240,164)), så den
  gamla noll-kontrollen bet aldrig. Nu avgör `is_position_in_frustum` frågan, och står spelaren på
  rutan gäller HELA vyn som träffyta (spaden ligger vid fötterna). Ledtråden säger det i klartext:
  "DU STÅR PÅ SPADEN — klicka för att gräva ned" (ny nyckel i alla 13 språk).
- Ett klick som inte gör något skriver nu en rad i utdata (rå punkt, vyns punkt, spadens punkt,
  avstånd, radie, under fötterna) — tysta klick går inte att felsöka.

**Mätt efteråt:** ett riktigt musklick på spadens ruta byter våning (våning 1 → 2), och från rutan
intill är avståndet 0,0 px mot spadens projicerade punkt.

## Alex' tio monster in i spelet (M46)

Alex: *"Fienden på den sista bilden du visade, den gillar jag verkligen inte, den ser ut som något
obeskrivligt. Jag bifogar en bild med 10 monster, kan du använda dem i spelet? Animera dem osv."*
Han ritade tio monster (imp, vålnad, beholder, succubus, tusenfoting, baphomet, köttgolem, lich,
cerberus, balrog) i en rad på svart botten, och de ersätter precis de kroppar som var FORMER i stället
för varelser — blob/wisp/swarm/crawler i `gen_enemy_art.py`. De sju bipederna (som redan fått egna
accenter och bedömts åtskilda) rörs inte.

- **Källan är facit:** `research/alex_monster_20260921.jpg` och `tools/gen_enemy_sheet.py`. Koden
  klipper, skalar och bygger sex rutor; den ritar aldrig om en figur. Alex' färger behålls (hans regel:
  bilden äger utseendet), så hans tio är undantagna från palettkravet i `test_assets.gd` — mått,
  genomskinliga hörn och alfakravet gäller dem som alla andra.
- **Kartan monster -> fiende-id:** imp->skitterling, vålnad->candlewisp, beholder->salt_wretch,
  succubus->glass_herald, tusenfoting->chime_swarm, baphomet->hollow_choir, köttgolem->verdigris,
  lich->ash_maw, cerberus->bell_drowned, balrog->bellmother. Id:na är kvar, så allt data (hp,
  svårighetsgrad, banor) står orört.
- **Animationen** är spelets sex rutor (andas in, andas ut, spänner sig, hugger, träffad, död) byggda ur
  hans EN bild med rörelser som går att förklara: en pixels andning, spänning som lutar bakåt, hugg som
  lutar framåt och sträcks, träff som viker undan, död som faller ihop.
- **Duken** är 80x80 med fötterna på rad 66 — samma rad som spelet räknar golvet ur — och pixeltätheten
  följer spelets (S=2), annars hade hans monster haft en annan "pixelstorlek" än resten.

**FEM MÄTTA FÄLLOR på vägen** (alla i PLAN.md-arbetet, inte gissningar): en tröskel på 45 svalde
cerberus svarta kropp och delade den i bitar (44x53 px av en hel best); en tröskel på 14 band ihop
ramarna med konsten så hela arket blev ETT område ("ruta 1 är tom"); en ram som låg kvar i utsnittets
kant stoppade bakgrunden och gav hela rutan som "figur" (med ramens lodräta linje och en lös eldflisa);
gränsen mellan ruta 9 och 10 skymdes av balrogens eldränna och räknades fram ur avstånden; och en
sträckt figur i en lika stor ruta klipptes rakt av i kanten (därför har rutorna nu marginal att växa,
och figurens EGEN nederkant — inte arrayens sista rad — ställs på golvraden).

**Grinden:** `tools/gen_enemy_sheet.py --check` mäter arket (480x80), fötternas rad, att hörnen är
genomskinliga, att figuren inte rör kanten och att alla sex rutor rör sig — det sista som PIXLAR, inte
bara som fötter (en kropp kan andas med fötterna stilla). Den körs av `tools/test.sh`, och
`gen_enemy_art.py` hoppar över de tio (`FRÅN_ALEX`) så hans filer inte skrivs över.

## Korten 80 % större, och Alex' kortbild som baksida (M47)

Alex: *"Korten behöver ännu bli större, de är för små för spelet, kanske rent av 80 % större. Kortet
tänkte jag att vi kan använda som baksida för korten."*

- **Storleken:** `CardView.HAND_SIZE` 58x80 -> **104x144** och `BIG_SIZE` 84x118 -> **151x212** (1,8x).
  Allt som räknar ytor (händer, högar, valet, albumet, HUD) räknar ur de konstanterna, så en ändring
  slår igenom överallt. MÄTT i `-- shots`: handkortet är **182x252** fönsterpx mot 101x140 före =
  **+79 %**, och skalan står kvar på 1,75 (ingen krympning).
- **Solfjäderns steg är nu MÄTT, inte fast:** `clampf((fönster - 40 - kortbredd) / (n-1), 0,50*bredd,
  bredd)` — med få kort ligger de kant vid kant (fem kort visar hela kortet, namn och allt) och först
  när handen är stor tas omlottet i. Ett fast 0,62 gömde grannens namn för en liten hand.
- **Högens kort ryms:** marginalkolumnen är 160 px och handkortet 182 -> högen klipptes av mot
  skärmkanten. Kortet i högen skalas därför till kolumnens bredd OCH lämnar plats åt kanterna
  (`STEG_MIN` per kort), annars växte högen 16 px utanför CRT-ramen med 18 kort. Mätt på skärmbild
  efter: hela kortet med ram syns, och baksidans motiv (demon med horn och vingar i eld) läses.
- **Baksidan är Alex' bild:** `tools/gen_card_back.py` ritar inte längre en egen baksida — den klipper
  hans kort ur `research/alex_kortbaksida_20260921.jpg` (mätt: y 13..2296, den mörka remsan utanför
  ramen räknas fram) och skalar till **208x288** = 2x kortets yta, med `BOX` (medelvärde) eftersom
  bilden skalas ner sju gånger och `NEAREST` hade gett hackiga kedjor. Samma baksida på varje kort.
- **Valet (level up) och handen:** en valkort som är 212 px hög ryms inte ovanför handen i en 270 px
  vy (mätt: valets nederkant 592 mot handens överkant 468). Valets kort får därför ett tak
  (`(VY.y - 100) / BIG_SIZE.y`, golv 0,45) så panelen ryms i fönstret, och **handen viker undan** medan
  valet står uppe — en modal där valet är det man gör. Det återinförde annars Alex' M34-fel: handens
  kort stal klicket från valkortet (mätt i test_gui: "val 4 -> 4").
- **Provet mäter det spelaren förlorar på:** test_gui kontrollerar nu att valet ryms i fönstret och att
  inget SYNLIGT handkort ligger över ett valkort. Själva klicket mäts i `-- vinstprov` (där klickas ett
  valkort efter en riktig strid och valet går 4 -> 0) — i test_gui når den simulerade musen inte fram,
  och att tvinga fram ett grönt svar där hade varit att mäta sin egen koordinatmiss.

## Taket höjt så fienderna ryms (M48)

Alex: *"Höj taket, det är för lågt för fienden, de tar i taket."*

MÄTT först, med koden som facit: duken är 80 px, golvraden 66, normal pixel_size 0,018 och bossarnas
0,026. En figur som når rad 2 är alltså 64 px = **1,15 m som vanlig och 1,66 m som boss** — i en
**1,00 m** hög gång. Hans tio monster ligger på 52–64 px (0,94–1,15 m), de äldre på 40–62 px, så
huvudet gick genom taket. Mätt mot konsten, inte gissat.

- `TAK_HÖJD` 1,0 → **1,3** ✓ rymmer den högsta figuren (1,15 m) med 0,15 m luft.
- Väggblocken följer taket: `Vector3(1, TAK_HÖJD, 1)` i stället för 1×1×1, annars blev det en öppen
  springa mellan väggens överkant och takplattan. Stenkonsten blir 30 % högrest — vad en högre gång
  ser ut som (granskningen: "stenblocken är rektangulära, ingen vertikal utsträckning").
- Bossarnas pixel_size 0,026 → **0,0195**: 64 px blir 1,25 m, strax under taket, och bossen är ändå
  rummets största varelse (vanlig fiende toppar på 1,15 m).
- Allt som räknade ur taket följde med av sig självt (facklan ur `TAK_HÖJD − LAGA_TAK_AVSTÅND`,
  takdroppet ur `TAK_HÖJD − 0,06`), vilket var hela poängen med att facklan en gång byggdes så.
- Ny grind i `test_assets.gd`: "ingen fiende är högre än taket (inte ens som boss)" — höjden räknas ur
  KONSTEN (översta raden med färg mot golvraden 66) gånger pixel_size, och taket läses ur `main.gd`.
  Utan den hade en framtida hög fiende kunnat smyga in och sticka ut genom taket igen.
