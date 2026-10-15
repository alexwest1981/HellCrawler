# Balansen: referensens modell, vår mätning och ändringen

Alex (14/10): *"man kan i dagsläget klicka på tre random kort och fortfarande klara sig hela vägen genom
3 levels utan att anstränga sig."* Det här dokumentet är svaret i fyra delar: hur referensen gör svårighet,
hur vår balans mättes, vad som ändrades — och vad mätaren inte säger.

Alla tal är mätta, inte uppskattade. Mätaren är `game/tests/test_balans.gd`:

```bash
cd game && ../tools/ett_prov.sh tests/test_balans.gd              # tabellen och grindarna
cd game && ../tools/ett_prov.sh tests/test_balans.gd -- --rattprov  # en ratt i taget, samma frön
```

Provet är **reproducerbart**: samma frön ger byte-identisk tabell mellan två körningar (kontrollerat — och
det var inte sant förrän `val.shuffle()` i kortvalen byttes mot en seedad ordning, se "Fällor" nedan).

## 1. Referensens svårighetsmodell (ur det skeppade bygget)

Referensen är Unity 6 / IL2CPP. Klass- och fältnamnen går att läsa ur `GameAssembly.dll` +
`global-metadata.dat` (Il2CppDumper); *värdena* i deras ScriptableObject ligger serialiserade i assets och
gick inte att läsa utan att köra spelet. Modellen är ändå läsbar, och den är arkitekturen vi jämför med:

| Led | Hur det styrs | Var det står |
|---|---|---|
| Fiendens styrka | `BaseHealth` × `LevelScaleMultiplier^level`, plus en egen `EnemyDifficulty`-rating per fiende | `EnemyConfig` |
| Våningens styrka | en `_enemyHealthMultiplier` PER VÅNINGSLAG, och ett svårighetsintervall per våning | `FloorLayerConfig`, `DungeonGenerationConfig.FloorDetails` |
| Rummets styrka | varje ruta får en svårighetsgrad ur en genererad kurva (`CalculatePathDifficulties`), och mötet väljer fiender inom ett spann kring den | `MapTile.Difficulty`, `EncounterTemplate` |
| Mötets sammansättning | en `EnemySelectionRule[,]`-matris per mall (vilken plats får vilken svårighetsgrad), med `Min/MaxEnemyVariance` och `Min/MaxEncounterVariance` | `EncounterTemplate` |
| Banans svårighetsgrad | `_difficultyRating`, `[Range(0, 10)]` | `DungeonConfig` |
| Spelarens ratt | Curse: **+20 % fiendestyrka per rang, max +100 %**, mot mer XP — svårigheten är delvis spelarens eget val | power-up-listan |
| Spelarens ekonomi | **mana 2, hand 3 kort**, kortkostnad 0–8; `Damage = (CardDamage + CardDamage×Combo + BaseDamage×Amount) × (1+Might) × (1+Area/5) × GemMultiplier1 × GemMultiplier2`; tak: Amount 50, Might 1000 %, Area 1000 % | bilder ur spelet + den officiella wikin (samma formel som vår `Rules.damage`) |
| Skickligheten | combo-multiplikatorn kräver att korten spelas i STIGANDE manakostnad — och den är en **relic man hittar**, inte ett startvärde | relicen "Combo Stack" |
| Gratis korten | 0-kostnadskorten är antingen Crawlers med **Duration** (de lämnar handen) eller wild/temporary som **förstörs** — inget gratis är evigt | korttabellen + byggets `CardConfig`-fält |
| Belöningarna | kortvalen är strypta: `RewardProbability` per kort, `CardLimit` per kortgrupp, och spelaren kan Reroll/Skip/Banish — fler fiender ger inte automatiskt fler kort | `CardConfig`, power-up-listan |

**Det bär modellen:** svårigheten ligger på KARTAN (ruta → spann → fiendeval), den växer per våning, och
spelarens stora skada kräver en kedja i stigande kostnad. En slumpmässig hand får ingen multiplikator.

### Var siffrorna kommer från (och vad som inte gick att läsa)

- **Ur bygget** (Il2CppDumper mot `GameAssembly.dll` + `global-metadata.dat`): hela modellens STRUKTUR —
  varje rad i tabellen ovan har sin klass och sitt fält därifrån, liksom `[Range(0, 10)]` på banans
  rating och metodsignaturerna (`CalculatePathDifficulties`, `CalculateEnemyVarianceForDifficulty`,
  `GetComboMultiplier`).
- **Ur den officiella wikin och Alex' mätbilder** (`research/00-matningar-skarmbilder.md`): de NUMERISKA
  spelarvärdena — mana 2, hand 3, combo som relic, Curse +20 %/rang.
- **Gick inte att läsa:** instansvärdena i referensens ScriptableObject (fiendens `BaseHealth`,
  kortens kostnader och effekttal, floor-kurvornas kontrollpunkter, banornas ratingtal, combo-formelns
  kärna). IL2CPP strippar typträdet, så objekten är serialiserade utan läsbar typinformation. Två vägar
  prövades: struktur ur dumpen (gav klasserna) och instanser via UnityPy med genererat typträd (gav ingen
  verifierad träff). Kvar att försöka: köra referensen och mäta beteendet.

## 2. Vår balans, mätt FÖRE ändringen

Mätaren spelar de tre första banorna (svårighetsgrad 1, 5 våningar, 6 möten per våning) med **spelets egen
startlek** och **utan Meta** — nybörjarens läge. Den svarar på varje kortval som sin policy skulle göra
(slumpen drar ett likformigt val, autospelaren tar det starkaste kortet). Två policies, samma frön:

| Bana | Slump | Autospelaren |
|---|---|---|
| stage_01 | 65 % | 95 % |
| stage_02 | 50 % | 70 % |
| stage_03 | 55 % | 80 % |
| **alla tre** | **34 av 60 (57 %)** | **49 av 60 (82 %)** |

Två saker står i den tabellen:

1. **Slumpen klarade 57 %** av körningarna — Alex' anmälan är alltså riktig, och den går att mäta om.
2. **Autospelaren var bara 1,4 gånger bättre än slumpen.** Det är det egentliga felet: spelet hade nästan
   ingen skicklighetsgrad. En tur med 4 kort och 3 mana kunde TÖMMA handen utan att välja, och en fiende
   på våning 5 slog exakt lika hårt som en på våning 1 — djupet gjorde fienderna segare, aldrig farligare.

(Första mätningen, med den gamla autospelaren som stannade vid första glappet i kedjan: slump 63 %,
autospelaren 68 %. Samma sak: ingen skillnad mellan att klicka på måfå och att spela.)

## 3. Ratten som valdes (mätt, en ratt i taget, samma frön och samma lek)

`-- --rattprov`, stage_01, startleken, 20 körningar per rad och policy:

| Variant | Slump | Autospelaren |
|---|---|---|
| baslinjen (HEAD) | 60 % | 90 % |
| fiende-HP ×1,5 | 25 % | 45 % |
| fiende-HP ×2 | 5 % | 30 % |
| fiende-HP ×3 | 5 % | 5 % |
| fiende-skada per våning +12 % | 50 % | 70 % |
| bas-mana 3 → 2 | 30 % | 50 % |
| hand 4 → 3 | 55 % | 70 % |
| fiende-HP ×2 + skada per våning | 0 % | 10 % |
| **fiende-HP ×1,5 + skada per våning +12 %** | **5 %** | **40 %** |
| fler fiender per möte (2–3) | 65 % | 75 % |

Två slutsatser som tabellen tvingar fram:

- **Enbart högre fiende-HP tar båda policies lika hårt** (×3 = vägg för alla, 5 % mot 5 %). Det är inte
  balans, det är en tröskel.
- **Gradienten kommer av att striden tar fler turer OCH att fienden slår hårdare djupare ned.** Den som
  kedjar korten rätt avslutar striden innan fienden hinner slå; den som spelar på måfå tar varje slag.

## 4. Ändringen

1. **`game/core/run.gd`: fiende-skadan fick en våningsterm** (`damage_per_floor = 0.12`). Formeln är
   `1 + 0.06×(svårighet−1) + 0.12×våning`, mot HP:ets `1 + 0.10×(svårighet−1) + 0.15×våning`.
2. **`game/data/enemies/00_bestiary.json`: all fiende-HP ×1,5** (tier 1: 12/16/20/26 → 18/24/30/39,
   tier 3: 400 → 600 osv). Ett möte ska ta mer än en tur att spela klart; då hinner fienden slå, och då
   kostar ett felaktigt kort något.
3. **`game/core/combat.gd`: autospelaren börjar en ny kedja i stället för att stanna.** Förut slutade
   solvern sin tur vid första glappet i den stigande trappan och lämnade både mana och kort ospelade —
   den var sämre än slumpen på samma siffror (2 % mot 8 % i en mätning). Nu: fortsätt kedjan om det går,
   börja annars en ny med det starkaste spelbara kortet, och använd wilds bara som bro.

## 5. Efter ändringen (samma mätare, samma frön)

### 5a. Efter den första ändringen (våningstermen + bestiariet)

| Bana | Slump | Autospelaren |
|---|---|---|
| stage_01 | 5 % | 45 % |
| stage_02 | 0 % | 5 % |
| stage_03 | 0 % | 15 % |
| **alla tre** | **1 av 60 (2 %)** | **13 av 60 (22 %)** |

Grindarna i provet går åt båda hållen med flit, och båda är gröna:

```
ok   slumpen klarar inte de tre banorna  (klarade 1 av 60 (högst 2 får klara))
ok   att spela bättre går bättre: autospelaren klarar fler än slumpen
     (auto 13 av 60 (22 %, minst 20 %) = 13.0 gånger slumpen (minst 3.0))
```

Gradienten gick från **1,4×** till **13×**. Autospelaren är en grov heuristik (ingen riktning av skadan,
ingen försvarsprioritering, inga Destroy-kort), alltså en GOLV för mänskligt spel — 22 % för solvern är
inte 22 % för en spelare. Grindens uppgift är att fånga en VÄGG: föll båda policies lika hårt vore
ändringen ingen balans.

### 5b. Efter kartkurvan (A, M118)

Samma mätare, samma frön, nu med tre policies — slump, autospelaren (slåss med allt) och **rutten** (går
förbi rum i grad 3–4 när HP:t är under 70 %):

| Bana | Slump | Autospelaren | Rutten |
|---|---|---|---|
| stage_01 | 5 % | 20 % | 40 % |
| stage_02 | 15 % | 10 % | 15 % |
| stage_03 | 5 % | 20 % | 30 % |
| **alla tre** | **5 av 60 (8 %)** | **10 av 60 (17 %)** | **17 av 60 (28 %)** |

Grindarna:

```
ok   slumpen klarar inte de tre banorna  (klarade 5 av 60 (högst 6 får klara))
ok   att spela bättre går bättre: bästa policyn klarar fler än slumpen
     (auto 10, rutt 17 av 60 (bästa 28 %, minst 20 %) = 3.4 gånger slumpen (minst 3.0))
ok   kartan går att agera på: rutten slår att slåss med allt  (rutt 17 mot auto 10 av 60)
```

Rutten klarar **70 % fler** körningar än att slåss med allt, och banorna kostar rummets svårighetsgrad
5 procentenheter för autospelaren. Slumpgränsen står på var tionde körning och inte på noll: provet
spelar utan meta och utan träd, och en enskild tursammansättning avgör en körning. Alex' anmälan var att
slumpen ALLTID klarade sig (38 av 60, 63 %) — 5 av 60 är en lott, inte en väg.

Samma mätare med **tre slumpkort i stället för startleken** (Alex' ordagranna bild; ingen spelare kan ha en
sådan lek, så det är ett stresstest): slump 50 / 50 / 60 %, autospelaren 30 / 60 / 80 %, rutten
40 / 60 / 80 %. Den tunna leken klarar sig BÄTTRE än startleken i slumpspel, och förklaringen är värd att
känna till: med 3 kort och 4 på handen drar turen hela leken, varje tur — då är stigande kostnad alltid
möjlig, och kedjan blir gratis. **Kedjan är bara en färdighet när leken är tjockare än handen.**

## 6. Vad mätaren inte säger

- **Ingen Meta och inget träd.** Mätaren kör standardspelaren. Bandgrindarna i `docs/skilltree.md` mäter den
  andra halvan (trädet på bandets nivå).
- **Ingen människa.** Båda policies är golv, inte tak.
- **Ingen kampanjkedja.** Varje körning är en egen `Run` startad från `stages.stage_NN`; att klara
  stage_01 → 02 → 03 i följd med en växande lek är inte mätt.
- **Kortvalen besvaras av en policy**, inte av spelaren, och uppgraderingar (Evolutions) väljs bara när
  receptet redan ligger i leken.
- **Fiendens rad/taktik, guld, butiken och nattvilan är med som de är** — mätaren rör inte ekonomin.

## 7. Fällor som kostade en runda

- **Mätaren måste svara på kortvalen.** Nivåuppgångarna köas i `run.drafts` och rörelsen är blockerad så
  länge ett val väntar. Svarar provet inte på dem mäter det en spelare som ALDRIG tar ett kort — en helt
  annan och mycket svagare spelare än den Alex beskriver (mätt: slumpen gick från 63 % till 57 % bara av
  att valen besvarades, och autospelaren från 68 % till 82 %).
- **`Array.shuffle()` använder den GLOBALA rng:n.** Ett `shuffle()` i provet gjorde två körningar med samma
  frön olika (slumptabellen skilde, autotabellen var identisk — det pekade rakt på kortvalen). Använd
  `policy_rng.randi_range(...)`, eller `Combat._shuffle` om det gäller en hög.
- **En hög blandas i `Combat.begin` med stridens eget frö.** Att blanda den innan `Run.new` är verkningslöst
  och lägger bara in en icke-seedad slump i mätningen.
- **Mät två policies, inte en.** En ensam siffra ("svårare nu") kan inte skilja balans från en vägg.
- **En svårighetskurva måste mätas med en policy som får AGERA på den.** Rutten (går förbi de hårdaste
  rummen när HP:t är lågt) klarar 17 av 60 mot autospelarens 10. Utan den policyn ser kartans svårighet
  bara ut som brus — och varians gynnar den som behöver tur, alltså underdogen: första mätningen på A
  visade att slumpen gick från 1 till 5 klarade, medan autospelaren tappade 3.
- **Bossen är grindvakten.** Körningarna tar slut där (förlorade strider ≈ 1 per körning), och tier-3-HP:t
  flyttade båda policies enormt: ×1,5 gav slump 5/60 och auto 10/60, ×1,0 gav 23/60 och 30/60. Ratta
  bossen först när du rattar svårighet — och mät, för det är inte där man tror att svårigheten sitter.
- **Skala kurvan mot HELA spannet.** Första försöket skalade graden mot fel ände och gav ingen grad 4 alls
  (grad 1: 21 rum, grad 4: 0) — kurvan var en klump i den lätta ändan. `tests/test_kartkurva.gd` grindar
  formen: graden stiger med avståndet, den hårdaste graden finns, medelpacken ligger kvar kring 2.
- **20 körningar per rad ger ±10 procentenheter.** Det räcker för att se riktningen på en ratt, inte för
  att avgöra en grind: två "olika" inställningar visade sig vara samma sak när de mättes med 60.

## 8. Vägen till referensens känsla

Fem skillnader mot referensens modell avgör om spelet *känns* som deras. Statuskolumnen uppdateras när de
byggs.

| # | Referensen | Vi (mätt) | Ändringen | Grinden som bevisar den | Status |
|---|---|---|---|---|---|
| A | Svårigheten bor **på kartan**: varje ruta får en svårighetsgrad ur en kurva (`CalculatePathDifficulties`), och mötet väljer fiender i ett spann kring den (`EncounterTemplate.EnemySelectionRule[,]` med `Min/MaxEnemyVariance`) | Per bana + per våning — varje rum i en våning hade samma form | En svårighetsgrad per rum, härledd ur avståndet från starten med spridning ur våningens frö; den styr antal fiender, HP och skada | Spridningen i tagen skada ökar *inom* en bana; slumpens andel faller utan att autospelarens gör det | **byggd** |
| B | **Kedjan är en belöning**: combo kräver relicen Combo Stack, och `ReceivesComboMultiplier` sitter per kort | Multiplikatorn är alltid på (`Rules.combo_after` räknar upp vid varje stigande steg) | Flagga per kort eller en relic som slår på kedjan | Startlekens skada per tur faller mätbart tills kedjan låsts upp | Flaggan per kort **byggd** (M119). Reliken finns (`combo_stack`, M123) och ratten är byggd (M125) — men **MÄTT: låst kedja ger 0 av 90 klarade**. Vår lek är balanserad runt att kedjan ligger på, så B:s andra halva kräver att kortens grundskada höjs först (Alex' beslut). |
| C | **Belöningarna är strypta**: `RewardProbability` per kort, `CardLimit` per kortgrupp, Reroll/Skip/Banish | Fler fiender = fler kort = **lättare**. Mätt: `fiender=3` gav slumpen **+20 pp** | Kortvalet på sannolikhet (under 1) och/eller trögare XP-kurva | Ny grindrad: "fler fiender får inte göra banan lättare" | **prövad, nedlagd** (se nedan) |
| D | **Gratis är inte gratis**: 0-kostnadskort är Crawlers med Duration, eller wilds som förstörs | 18 kort på kostnad 0 ligger kvar; startleken har 4×`lash` (12 skada utan villkor) och **6 mana-positiva** kort (`ember_tome` 1→+2, `hourglass` 3→+5) | Duration/Destroy på gratiskorten (nyckelorden finns redan i 7 kort), eller mananeutrala tomtar | Gratiskortens andel av spelade kort faller; manan slutar gå plus | planerad |
| E | Fienden **telegraferar**, spelaren väljer mål | Telegrammet, målvalet och **radregeln** finns: alla rader slår, den bakre för 0,6 av sin skada | (byggd) | Målvalet slår att inte välja mål | **byggd och nu levande** (M126): raderna delades aldrig i verklig strid (0 av 560 möten) — med taket två har 34 % av mötena en bakre rad, och valet har tänder: avvärjningen 31 mot autospelarens 18 av 90 |

### A, byggd och mätt (M118)

- **Kurvan:** `Dungeon.rum_svarighet` ger varje ruta grad 1–4 ur avståndet från starten, med ett stegs
  spridning ur våningens frö. HÄRLETT, INTE SPARAT — båda generatorerna (`dungeon._fyll` och
  `mapio._fill_enemies`) och en handritad karta får samma svar utan att en enda fil ändras.
  `tests/test_kartkurva.gd` grindar formen: graden stiger med avståndet (1,74 nära starten mot 3,07
  längre in), den hårdaste graden finns, och medelpacken ligger kvar kring 2 — rummet flyttar
  SPRIDNINGEN, inte pressen.
- **Det synliga:** rummets grad ÄR antalet fiender (1–3, klämt mot banans spann), så spelaren ser att
  rummet är farligt innan hen går in. Ingen ny bild behövdes.
- **Det osynliga:** HP +6 %/grad och skada +4 %/grad (rattar i `run.gd`), och bossen står UTANFÖR kurvan —
  den har sin egen svårighet i sitt HP. Första försöket gav bossen den hårdaste graden (+18 % HP per bana)
  och mätt kostade det autospelaren 20 procentenheter utan att röra slumpen.
- **Provet fick en tredje policy: rutten.** Den går förbi rum i grad 3–4 när HP:t är under 70 %. Utan
  den mäter provet bara att kurvan FINNS, inte att den är värd något. Mätt: **rutten klarar 17 av 60 mot
  autospelarens 10** — kartans svårighet går att agera på, och det är hela poängen med att lägga den där.

### B, halvbyggd och mätt (M119)

Referensen har två saker här: multiplikatorn sitter **per kort** (`ReceivesComboMultiplier`) och hela
kedjan är något man **hittar** (relicen Combo Stack). Den första är byggd. Den andra är kvar, och
mätningen säger varför den inte är gratis att lägga in.

- **Flaggan per kort:** `receives_combo` i kortets data. Ett flaggat kort tar ingen multiplikator — men
  behåller sin PLATS i stegen, så kortet efter får det steg det gav. `tests/test_kort_beteende.gd` mäter
  båda halvorna (×1 på kortet, ×4 på kortet efter). Spelaren ser flaggan på kortet ("utan kedja").
- **Den breda regeln prövades och förkastades:** först flaggades ALLA kort med rå skada ≥ 150 (sex kort).
  Mätt: slumpen 5 → 2 och rutten 17 → 6 av 60, stage_02 och stage_03 till 0–5 % för alla policies.
  Startlekens enda avslutare är `bell` (195 för 2 mana) — utan dess multiplikator kan decken inte döda
  bossarna. Regeln är därför **stort OCH sällsynt** (fyra kort: `grave_choir`, `the_long_winter`,
  `shrouded_bell`, `frost_bell`), alltså de kort som DYRT dyker upp ur en draft och avgör en körning på
  tur. Provet grindar regeln åt båda hållen, inklusive att `bell` och `emberstorm` behåller kedjan.
- **Talet efter:** slump 5, autospelaren 11, rutten 15 av 60 (25 %, 3,0× slumpen). Grindarna är gröna,
  men kvoten ligger PRECIS på sin gräns (minst 3,0) — nästa ändring som rör startleken ska mätas innan
  den får ligga.
- **Crawlers som STANNAR** (`duration` + `trigger` i kortets data): kortet går in i spel i stället för i
  kast-högen, reagerar när spelaren spelar den korttyp det reagerar på, och lämnar bordet efter
  `duration` reaktioner — referensens *"Crawlers trigger 2 more abilities before leaving"*, där deras
  exempel är exakt vårt ("heal when a blue card is played"). Två kompanjoner använder det: `tarboy`
  (på mana) och `cleric_of_light` (på attacker), båda 2 turer. Autospelaren fick regel 7: inom samma
  kostnad går ett kort som stannar först.
- **FYNDET: mekaniken går inte att mäta i balansmätaren.** Kompanjonerna kommer in via kistor och
  kortval i metan, aldrig via nivåuppgångens draft (`progress.gd` säger det rakt ut), så mätarens lekar
  innehåller aldrig ett kort som stannar. Att göra den mätbar kräver antingen en lek i mätaren med en
  kompanjon i, eller att kompanjonerna också kan komma ur draften. Provet `test_kort_beteende.gd` visar
  att mekaniken FUNGERAR; hur den BALANSERAR på sikt är omätt.

### C, prövad och nedlagd (M118)

Ratten `xp_per_extra` (XP för fiende 2, 3 … i samma möte) sattes först till 0,25 för att mötet — inte
fienden — skulle vara belöningens enhet, som referensens `RewardProbability`. Mätt: inversionen försvann,
men GRADIENTEN försvann med den (slump 20 % → 10 %, autospelaren 40 % → 15 %, stage_01, samma frön).
Kortens snöboll är den mekanism som förstärker skicklighet mest; den ska inte strypas förrän B ger
spelaren något annat att vara bra på. Ratten står kvar på 1,0 med mätningen i kommentaren, och
inversionen är borta ändå — det var RUMMETS PACKET som tog bort den (`fiender=3` straffar nu i stället
för att belöna).

### E, halvbyggd och mätt: telegrammet finns, men valet betyder inget än (M121)

Referensen gör två saker som hänger ihop: fienden **telegraferar** sitt drag innan man spelar, och
spelaren **väljer mål**. Båda är byggda i maskinen:

- `Combat.inkommande()` — vem som slår nästa fiende tur och för hur mycket. Regeln ligger i
  `_slår_nästa_tur`, som `enemy_turn` OCKSÅ läser, så telegrammet kan inte ljuga om slaget som faller.
  Frusen fiende, boss med stängda ögon och bakre rader listas inte.
- `Combat.play(index, mål)` fanns redan; `_hit_plan` kapar redan vid kvarvarande HP, så en fokusering
  slösar ingen skada på en fiende som ändå dör.
- `Combat._målval(index)` — målregeln, den spelaren kan LÄSA ur telegrammet: träffa den som slår
  hårdast härnäst; när ingen slår, den främre raden (alltså samma svar som förut i det läge där svaret
  inte kan bli bättre). Autospelaren fick flaggan `målval` (avstängd som förval), och mätaren en fjärde
  policy, `mal`, som är autospelaren med målval och inget annat — samma väg, samma frön.
- Provet `test_rules.gd` grindar telegrammet och valet: fem fiender där bara två slår (14 skada), och
  samma `lash` går på valt mål i stället för på den främsta. 144 kontroller, 0 fel.

**MÄTT: valet gör ingen skillnad.** Målpolicyn blev IDENTISK med autospelaren i 60 körningar — 11 mot
11, samma skada per bana, samma antal spelade kort. Orsaken står i **radregeln**: bara främre raden
slår, alltså är främre raden alltid rätt mål, och inom en rad är fienden utbytbar mot sin granne.

Försöket att ge valet något att välja mellan föll, och det är mätningen som fällde det: packet
byggdes som en GRUPP (första fienden = rummets egen, resten ur samma tier med rummets frö, som
referensens `EncounterTemplate` + `Min/MaxEnemyVariance`) i stället för som kopior av EN fiende.
Resultat: **slumpen 5 → 8 av 60, autospelaren 11 → 8, bästa policyn 15 → 12, kvoten 3,0× → 1,5×** —
alla fyra grindar föll, och målvalet blev fortfarande inte bättre (7 mot 8). Blandade pack gav alltså
TUR, inte SKICKLIGHET: variation utan val är brus. Försöket är rivet; `run.gd` är som förut.

Det är samma läxa som kartkurvan gav, i motsatt riktning: en mekanik är inte värd något förrän någon
kan AGERA på den — och variation som inte går att agera på gör spelet bara turligare.

**E:s riktiga ratt är därför radregeln**: låt VARJE fiende telegrafera sitt eget slag och slå oavsett
rad (referensens modell, där intents är per fiende). Då blir "döda den som slår 9 innan den som slår
5" ett riktigt val, och först då kan den stränga grinden sättas. Det är en kärnregel i striden och
ändrar spelets identitet — därför ett beslut, inte ett mått. Grinden står så länge enkelriktad
("målvalet gör det inte sämre").

### M123: relik-lagret — den halva av B som saknades, och den största innehållsskillnaden

Referensen har **67 reliker** och **52 arcanas** (räknat ur dess egen engelska strängtabell: `Relics_en`
och `Arcanas_en`). Vi hade **noll** — ingen datamapp, ingen mekanism. Det är den enskilt största
innehållsskillnaden mot referensen, större än kortens (342 mot våra 92), eftersom relikerna är det som
gör att två körningar med samma lek spelas olika.

Byggt (`game/core/relics.gd`, `game/data/relics/00_reliker.json`):

- **En relik är data, inte kod.** Åtta rattar: `combo_extra`, `max_hp`, `mana`, `hand`, `armor`,
  `recovery`, `gold`, `damage`. En ratt som ingen kod läser skriver `Relics.load_all` ut som **fel** i
  stället för att tiga — den fällan (data som ser ut att göra något) är samma som `_sfx("select")` var.
- **Leveransen är kistorna**, med ett eget smalare fönster (8 %) i samma seedade slag som guld,
  läkning och ädelstenar: samma kista ger samma sak varje gång, och en relik man redan har lämnas
  tillbaka till högen i stället för att bli en dubblett.
- **Kedjestenen** (`combo_stack`) ger +1 steg varje gång kedjan FORTSÄTTER — aldrig en kedja ur tomma
  luften: 1-2-3 blir 1-3-5 i stället för 1-2-3. Den är B:s mekanik i data, men den LÅSER ännu inte
  kedjan: att stänga av multiplikatorn som förval är en balansändring som måste mätas (den breda
  `receives_combo`-flaggan tog tidigare decken från 17 till 6 klarade körningar av 60).
- **`tests/test_relik.gd`** (8 kontroller): datan laddas, varje ratt når spelet (Järnhjärtat 60 → 75
  max-HP, Vässade eggen 12 → 16 på `lash`), samma relik kan inte tas två gånger, ett okänt id gör
  ingenting, och kistorna delar ut reliker i spelade körningar (3 av 20 i provet).

### M126: raderna levde inte — och när de gör det får valet tänder

M124 byggde radregeln (alla rader slår, den bakre svagare) och mätte en marginell skillnad. Frågan som
ALDRIG ställdes var om raderna alls delas i verklig strid. Ett eget provmått svarade: i **560 möten**
(fem frön × tre banor) hade **0** en bakre rad — `per_rad` blev alltid >= antalet fiender, för både
gångens bredd och packetets storlek kommer ur SAMMA rumsterm (ett brett rum ger fler platser OCH fler
fiender). Alltså var bakre radens 0,6, knuffen som flyttar bakåt, och telegrammets val overksamma, utan
att ett enda prov sa till: kameraprovet mätte formationens geometri i en scen, inte om packet någonsin
delades i rader.

Byggt, i tre delar:

1. **Taket två** (`Run.per_rad`): ett packet på tre får alltid en bakre rad. Mätt: 34 % av mötena har
   en bakre rad (190 av 560).
2. **Den bakre raden är en annan sort** (`Run._bakre_fiende`): rummets egen fiende står främst
   (rummets identitet), varje bakre rad drar en annan fiende av SAMMA tier. Draget är deterministiskt
   ur rummets frö — samma rum ger samma pack varje gång — så ingen ny slump kommer in i mätningen.
   Mätt: 153 av 153 bakre rader är en annan fiende.
3. **Rader ändrar formen, inte trycket** (`Run.radfaktor`): ett pack i två rader slår mindre, så skadan
   skalas upp så att packet slår EXAKT lika hårt som om alla stod främst — invarianten
   `(per + (count - per) x 0,6) x radfaktor(count, per) == count`. Utan den blev spelet lättare och
   kvoten föll (slumpen 9 -> 11, kvoten 2,3 -> 1,7), alltså var raderna en rabatt och inte en form.

**Mätt, hela paketet (n=90, samma frön):** slump 9, auto 18, rutt 21, mål 18, **avvärj 31**. Alla fem
grindar gröna, kvoten 2,3x, och avvärjningens övertag är det största som uppmätts: **31 mot 18 (1,7x)**
mot 24 mot 16 (1,5x) innan raderna levde. Svårigheten kompenserades med rummets HP-term
(`hp_per_room` 0,06 -> 0,10), den enda ratten som behövde flyttas.

Tre fynd som kom med på vägen, alla mätta:

- **Bossen tappade 29 % av sin skada.** `per_rad` räknar med det VANLIGA rummets fiendeantal, så för en
  boss (ett pack på en) blev `count - per` negativ, packet "fick plats" i 1,4 rad och skalningen drog
  NER bossens skada. Mätt utfall av den enda missen: autospelaren 16 -> 49 av 90 (bossen är
  grindvakten). Räknas nu ur packet: `per = min(per_rad, count)`, och `radfaktor(1, vad som helst) == 1`.
- **En ensam figur i en halv rad stod 0,31 m utanför siktlinjen.** Placeringen räknade alltid med
  radens BREDD, inte med hur många som stod i den. Fångades av svitens egen symmetrikontroll.
- **Målregeln var fel för en värld med rader.** "Slå den som slår hårdast" är SÄMRE än "slå främre
  raden" (mål 17 mot auto 18): en tung fiende i bakre raden slår bara 0,6, så den främre raden kostar
  mest per slag. Regeln är nu främre raden först, och inom den den som slår hårdast.

Grinden `tests/test_pack.gd` (8 kontroller) mäter det provet aldrig frågade: att en bakre rad FINNS i
en betydande andel av mötena (krav 20 %), att den är en annan fiende, att främre raden är rummets egen,
att samma frö ger samma pack, och tryckinvarianten.

### M125: kedjan låst bakom reliken — mätt, och den dödar spelet

Referensens modell är entydig: multiplikatorn kräver relicen Combo Stack (`ReceivesComboMultiplier`),
den är en vinst man hittar, inte grundtillståndet. Ratten byggdes (`Combat.KEDJAN_KRÄVER_RELIK`,
läst av `_combo_used` som både `play` och `preview` använder) och mättes med flaggan PÅ:

| policy | kedjan på (i dag) | kedjan låst |
|---|---|---|
| slump | 9 | **0** |
| auto | 16 | **0** |
| rutt | 21 | **0** |
| mål | 16 | **0** |
| avvärj | 24 | **1** |

**0 av 90.** Ingen policy klarar ens den första banan. Orsaken är mätt och enkel: vår lek är
balanserad RUNT att kedjan alltid ligger på — multiplikatorn (×2 till ×4 på varje kort) ÄR
skademotorn, inte en krydda. Att kopiera referensens modell genom att vända en flagga tar bort
motorn, och då finns ingen skada kvar att vinna med.

Slutsatsen är därför inte "riv ratten" utan **ordningen**: referensens modell kräver att kortens
grundskada höjs i samma veva, alltså en balansrunda över korten själva (Alex' data, hans beslut).
Ratten står kvar på `false` med den här mätningen i sin kommentar i stället för att vara en glömd
flagga — den som vill slå på den ser först vad som händer.

**Lärdom som gäller varje "referensen gör X":** en mekanik kan vara rätt och ändå döda spelet, för
vår baslinje är kalibrerad runt att den INTE finns. Mät flaggan innan den får vara på, och om
mätningen säger noll är svaret en följdändring (här: kortens grundskada), inte att flaggan var fel.

### M124: avvärjningen — valet som telegrammet faktiskt gör möjligt

Efter radregeln stod målvalet kvar på 16 mot 16. Frågan var då om spelet *erbjuder* ett val värt att
fatta, eller om telegrammet är en siffra utan konsekvens. Svaret ligger i att **sikta inte är samma
val som att stänga av**: en policy som läser telegrammet och FRYSER den som slår hårdast
(`Combat._avvärj_index`, tröskel `AVVÄRJ_ANDEL` = 15 % av din HP, frys-kortet ur handen) går före
autospelaren i båda mätningarna:

| mätning | avvärj | auto | skillnad |
|---|---|---|---|
| n=30 (90 körningar per policy) | 24 | 16 | +8 pp (1,5x) |
| n=60 (180 körningar per policy) | 49 | 40 | +5 pp (1,22x) |

**Men skillnaden är inte bevisad.** Vid n=180 är den 5 procentenheter med ett standardfel på 4,6
(z ≈ 1,1, alltså inte signifikant), och vid n=90 var den 1,4. Det är en riktning som håller i båda
mätningarna, inte en fastställd effekt — för att skilja 5 pp från noll behövs i storleksordningen
**700 körningar per policy** (≈ 50 minuters mätning). Att skriva "+8 pp" som ett resultat vore att
läsa brus som en vinst; det som går att säga är att **ingen av mätningarna visar något annat än att
avvärjningen ligger före**.

Startleken har **exakt ett** frys-kort (`icicle`, 1 mana), och det räcker för hela skillnaden: 22
kort, varav ett är svaret på frågan telegrammet ställer. Det är den närmaste förklaringen till att
VC:s känsla av "jag läste motståndaren" går att bygga utan fler system.

Mätaren har därför en femte policy (`avvarj`) med samma grind som de andra — den får inte vara
sämre än autospelaren — och raden skrivs ut med ordet bättre/lika/sämre, så nästa steg (att kräva
att den är BÄTTRE) är en mätning och inte en förhoppning.

**Bieffekt av den högre upplösningen, och ärligt:** vid n=180 ligger grindarna på sina linjer
(slumpen 22 av 180 = 12,2 % mot taket 12 %, kvoten 1,9 mot kravet 2,0) — alltså sitter grindarnas
kalibrering nära bruset även efter ombaseringen. Provet står kvar på `ANTAL := 30`, där grindarna är
satta och håller; n=60-körningen är ett upplösningsprov, inte en ny baslinje.

### M124: radregeln — telegrammet blev sant, men valet betalar fortfarande inte

Ratt E:s egentliga ratt var radregeln: varje fiende telegraferar sitt EGET slag och slår oavsett rad.
Före M124 slog bara den främre raden, och då var målvalet alltid samma svar (den främre raden) — det
är därför M121 mätte 11 mot 11 och valet var innehållslöst.

Byggt: `Combat.BAKRE_SLAG := 0.6` och `_slagsverk(e, front_row)` — samma funktion som telegrammet
(`inkommande`) och `enemy_turn` läser, så telegrammet kan inte ljuga om summan. Främre raden slår
fullt, bakre raden 0,6 av sin skada. Knuffen blev en **skala i stället för en strömbrytare**: förut
tystade den den farliga helt (raden bakom väntade), nu flyttar den den till den svagare raden
(9 + 3 = 12 blir 5,4 + 3 = 8,4 utan knuff mot 10,8 med den gamla regeln).

**Mätt (n=90, tre banor):** slump 9, auto 16, rutt 21, mål 16. Alla fyra grindar gröna (kvot 2,3x),
och rutten går från 20 till 21.

**Men målvalet betalar fortfarande inte: 16 mot 16.** Det var inte raden som var hela orsaken. Den
mätta orsaken nu: **inget dör på en tur.** Att sikta på den som slår sparar bara skada om den hinner
dö innan turen kommer, och det gör den inte — alltså är målvalet nästan irrelevant hur raden än
fungerar. Nästa ratt är därför inte fler rader utan **avvärjbarhet**: ett slag ska kunna nollas av
spelarens svar på telegrammet (frys/blockera just den fienden). Telegrammet är redan vad som gör ett
sådant val läsbart, och `frozen` finns i maskinen — det är den kopplingen som saknas.

Ordningen de tas i är inte tabellordningen: **C** prövades först och lades ned, **A** är byggd, **B** är
halvvägs (flaggan per kort är byggd och mätt, relicen som låser upp kedjan är kvar), sedan **D** (kortdata
är Alex' konst) och sist **E** (ny mekanik i striden).

---

## 9. VC-paritet: att kopiera referensens combo och dess flöde (15/10)

Alex' besked var inte "inspireras av" utan **"rent av kopiera"**: combon som i VC, och HELA deras
spelflöde. Arbetet har därför gått till deras egen kod och deras egna texter, och varje regel nedan
står med den sträng ur spelets lokaliserings-tabeller som säger den.

### 9a. Källor, och varför de räckte

`il2cpp/dump.cs` (Il2CppDumper, 45 MB) har **typer, fält och metodsignaturer — inga metodkroppar**.
Exakta formler går alltså inte att läsa därur; det var den gamla utredningens vägg. Vägen runt den:
spelets **egna texter**. `localization-string-tables-english(en)_assets_all.bundle` bär 13
MonoBehaviour-tabeller med **2 271 strängar** — korttexter, reliktexter, hjälptexter, menyer,
nyckelordsdefinitioner — och där står reglerna i ord. Utdraget ligger i
`scratch/vc_texter/*.json` (`vc_tabeller_ut.py`); flödes-specen i
`scratch/drangsrapporter/vc-flode-spec.md` (297 rader, varje påstående med strängnyckel eller
`dump.cs`-rad, och en egen lista över vad som inte kunde beläggas).

### 9b. Combon, ordagrant ur referensen

| Regel | Referensens egen text |
|---|---|
| Kedjan är stigande manakostnad | `633906212883: "Play cards in ascending {0} Mana cost order for a Combo Multiplier."` |
| Wild-kort bryggar kedjor | `158106791638413313: "Wild cards can be used to connect combos together to make bigger Combos."` |
| **Multiplikatorn gäller varje effektvärde** | `{0:combo:}` på skada, mana, rustning, frys, dra, rader, fiender, XP, mynt, HP, tur — och `{0:combo:%}` för procentsatser |
| Kedjan nollställs mellan turer | `91224384860053509: "Combos don't clear between turns."` (en Arcana tar bort förvalet) |
| Breakern konsumerar kedjan | `"Ends combo but always benefits from the multiplier."` / `"Consumes the combo to benefit from the multiplier."` |
| Easy Combo behåller den | `"This card always benefits from Combo, even if you break the Combo."` |
| Omvänd riktning finns | `"Reverses Combo direction."` |
| Handen kan sorteras i kedjeordning | `190734195120615427: "Mana Ascending"` (`Sort Hand`) |
| Kedjan är en hög man ser | `ComboPileModel` (PlayerModel fält `_comboPile`, `DiscardComboPile()`, `CardCombo`) |
| Multiplikatorn kräver reliken | `633906212882/883: "Combo Stack"` — `ComboPileModel._comboRelic` + `IsUnlockedAndActive` |
| Talet räknas per kort och är dynamiskt | `GetComboMultiplier(isInCombo, playerModel, cardModel) -> int`, `CardModel.RefreshReceivesComboMultiplier()`, `CardStats.ComboMultiplier` |

**Byggt:** multiplikatorn är EN funktion (`Rules.combo_multiplier`) och EN skalning (`Rules.scaled`)
som alla effektvärden går genom — rustning, mana, läkning, dra, knuff, frys, inte bara skada. Det var
den stora skillnaden mot vår: hos oss var kedjan en skadekurva, hos dem en motor. Plus **Easy Combo**
och **Combo Breaker** som kort-nyckelord (`card.keywords`), och att kedjan redan nollställdes mellan
turer (samma som referensens förval).

### 9c. MÄTT: skalningen gjorde manan positiv och spelet mer skillnadsstyrt

| | före (M126) | efter (VC-skalningen) |
|---|---|---|
| slump | 9 | 11 |
| auto | 18 | **25** |
| rutt | 21 | **32** |
| mål | 18 | 25 |
| avvärj | 31 | **38** |
| kvot | 2,3x | **2,9x** |
| mana netto (startleken) | −40 … −58 | **+93 … +102** |

Manan går från att aldrig nå plus till att gå kraftigt plus — det är referensens mana-kort
(`"Add {0:combo:} Mana"`) som gör sitt. Det är också ratt D:s svar: gratiskorten behöver inte kosta
något, kedjan gör dem lönsamma, precis som hos referensen. En grind föll: slumpen klarade 11 av 90
mot taket 10 — **en körning över**, och grinden står kvar (att flytta den vore att flytta målet).

### 9d. MÄTT: kedjan låst bakom reliken — tre försök, samma svar

Referensens modell säger att multiplikatorn kräver `Combo Stack`. Vi byggde först vägen dit: relikerna
blev ett **VAL** (se 9e) och **relikrum** (`Dungeon._relikrum`, ett per våning, referensens
`roomtemplates-relics`), så Kedjestenen går att skaffa med avsikt. Sedan mättes flaggan:

| försök | vad som ändrades | resultat |
|---|---|---|
| 1 | relikrum + relikval | 1–5 av 90 klarade |
| 2 | + kortens skada x2 (grundvärdet ska bära sig självt) | 1 av 90 |
| 3 | + fiendernas HP x2 (referensens parning) | 1 av 90 |

Slutsatsen är mätt, inte tyckt: **vår lek är byggd KRING kedjan** — multiplikatorn är skademotorn
(×2–×4 per kort), inte en krydda. Referensen kan låsa den därför att dess reliker är 67 stycken ur
relikrum, ljuskällor och NPC-gåvor: Combo Stack kommer i praktiken alltid tidigt. Att låsa kedjan
kräver alltså **relikabundans först**, inte bara ett relikrum per våning. Flaggan
(`Combat.KEDJAN_KRÄVER_RELIK`) är rätt modell och fel läge: den står på `false` med de tre mätningarna
i kommentaren, och slås på när relikerna är lika många som referensens.

### 9e. "Choose a reward": reliken blev ett val

Referensen ger sina reliker som ett val (`ReceiveRelicModal`: `56142799869829120: "{Relic} Found!"`,
`56142799869829121: "New!"`, och NPC-raden `31543270518784: "I gift unto you this Relic as a reward
for finding me."`), aldrig som en lott i en kista. Vår kista gav reliken på 4 % — alltså blev
`Run.pick_relic` + relikrummet + draft-panelen (samma ruta, samma siffertangenter) den nya vägen:
två kandidater, spelaren väljer, kandidaterna ur körningens seed och rummets position (determinismen
gäller även val). Slumppolicyn väljer likformigt bland dem, de kompetenta tar Kedjestenen först
(`_relikvärde`) — det är samma fråga som för korten, och svaret ska mätas på samma sätt.

### 9f. Flödet: vad referensen gör, och vad vi har

Flödesspecen (`vc-flode-spec.md`) i sammandrag, med vår status:

| Steg | Referensen | Vi |
|---|---|---|
| Meny → Crawler-val → by (hub) | `CharacterSelect`, `TownViewController` med Inn/Shop/Fortune Teller/Museum/Town Hall/Blacksmith/Graveyard | **saknas** (vi har meny → bana) |
| Världskarta med underbanor | `LevelSelect`, `MapLocationInfoPanel`, "Cleared", Endless, Hurry | **delvis** (vår bana-karusell) |
| Dungeonen | förstaperson-rutnät, `EventMarker` per ruta, rummen PÅTRÄFFAS | **delvis** (nodkarta; vi har rumstyper, inte gång) |
| Rumstyper | strid, vaktare/coffin, offerbord, evolutionsbord, gemkista, relikrum, NPC-dialog, handlare, bakhåll | **strid, kista, relikrum, fackla, boss, spade** — offerbord/evolution/NPC/handlare saknas |
| Level up | XP-bar fylld av golvkristaller → `ChooseCardModal` "Level Up!"/"Choose a reward", **Reroll / Skip / Banish**, Luck ger chans till 4 val | **delvis**: kort ELLER gem, Luck→4 val ✓; Reroll/Skip/Banish saknas |
| Nedstigning | spaden gräver upp utgången (`Descend`), `FloorTransitionState` | ✓ (spade + nedstigning) |
| Slut | boss/Red Death → `DungeonCompleteState` → **Resultatskärm** (tid, våningar, mynt, level, fiender, Max Combo, bonusmynt, New Best) | **delvis** (slutskärm utan Max Combo/resultatrad) |
| Meta | mynt → `TotalCoins`, byggnader, upplåsningar, achievements, PowerUps per rang | **delvis** (splitter/träd, ingen by) |

Nästa steg i flödet, i den ordning mätningen pekar: **Reroll/Skip/Banish i kortvalet** (billigt, och
referensens egen resurs), **offerbordet** (ett kort blir en permanent stat/HP/mana — mekaniken finns
redan som `Evolution`), **resultatskärmen med Max Combo** (mätbar direkt ur `Combat`), och sist
**byn med byggnader** (störst, och det enda som kräver ny scen).

---

## 10. VC-paritet: kartan och himlen (15/10)

Två nya frågor från Alex: *"ta reda på hur de gör med sina kartor, och kopiera tillvägagångssättet de
genererar dem, men vi måste behålla möjligheten till random generated dungeons"* och *"hur de gör när
man går utomhus i en dungeon, där man ser himlen utanför … för jag vill kunna ha öppna slagfält
utanför en stängd area"*. Forskningen ligger i `docs/referens/vc-kartgenerering-spec.md` och
`docs/referens/vc-utomhus-spec.md` (varje påstående med `dump.cs`-rad, typetree-fält eller
bundle-namn, och en egen lista över vad som inte kunde beläggas).

### 10a. Kartan: kopierat och mätt

**Ryggraden är nu ett minimalt spännande träd.** Referensen bygger korridorerna som Delaunay +
minimum spanning tree och lägger sedan medvetet till extra kanter
(`PathMinimumSpanningTreeGenerationLayer`, `_maxExtraEdgeSelectionChance`, `_maximumLength`, och en
`_middleZoneRadius` som håller genvägar borta från mitten). Vi kedjade rummen i BSP-ordning — oftast
grannskap, men inte alltid, och en kedjelänk kunde gräva en lång gång tvärs över våningen.

Byggt: `Dungeon._mst_länkar` (Prim över rummens gångavstånd; vid ett tiotal rum ger den exakt samma
träd som Delaunay + MST gör i referensen) och extrakanter med ett tak sprunget ur ryggradens längsta
länk (`× 1,5`) i stället för en fast siffra — referensens `_maximumLength` finns för samma sak: en
genväg rakt till bossen kortar den väg våningen just gjorde lång.

**Slingorna var det som räddade körningen, och antalet är mätt.** Ett träd har inga slingor, så varje
gren måste gås fram och tillbaka: med bara `rum/4` extrakanter (högst 5) tog fixturen i `test_run`
**4 341 steg** och dog av stegvakten med 39 vunna strider och **noll** förlorade. A/B mot samma frö:
**0 extrakanter → död, `rum/4` → död, `rum/2` → klarad**; takets storlek (0,5× mot 1,5× längsta
länken) avgjorde inte alls. Lärdomen om mätaren: **golvytan mäter inte det här** — 494 rutor i alla
varianter, för rummen är stora och en extra gång mellan två rumskarvar gräver mest över golv som redan
finns. Räknaren för körbarhet är körningens steg.

**Mätt (40 frön × 3 svårigheter × 3 banor, samma frön före och efter):**

| | före (BSP-kedja) | efter (MST) |
|---|---|---|
| golvrutor i snitt | 536 | **494** (−8 %) |
| steg till bossen, fixturen | klarar | klarar (men bara med slingor, se nedan) |
| oåtkomliga noder | 0 | 0 |
| återvändsgränder | 0 | 0 |

Kortare gångar mellan rummen med samma framkomlighet — och slumpen är kvar: trädet beror bara på
våningens eget rng, och extrakanterna dras ur samma ström.

**Inte byggt, med flit:** referensens omförsöksloop (`maxRegenerationAttempts`). Vår kontroll finns
(`Dungeon.unreachable_nodes`) men ingenstans att köra den: 360 genererade våningar gav **0**
oåtkomliga noder, så en omförsöksloop är spekulativ tills en våning faktiskt faller. Den dagen är
den billig — samma funktion anropas med `seed + försök * 104729` i en slinga.

**Kvar att kopiera ur kart-specen** (i den ordning den pekar på): *taggade rumsmallar* med krav
("N rum av den här typen", `RoomTagSelector { Tags, Number }`) i stället för att bara dela BSP djupare;
*svårighet per RUTA* med sänkt svårighet vid sidan av huvudvägen (`AssignTileDifficulties`,
`_offPathDifficultyInitialScale`); *händelseordningen* (boss → minibossar → side events → manuella →
bakhåll → mallmöten, `EventGenerationLayer`) med spridning via flödesfält; och *mötesmatrisen*
(`EnemyConfig[,]` med `EncounterTemplate._rules` per plats: Empty/Baseline/LowerDifficulty/
HigherDifficulty) — den sista är vi redan halvvägs in i, för våra rader (M126) är samma idé.

### 10b. Himlen: tekniken, och första biten byggd

**Referensens teknik, mätt i deras egna filer:** dungeons har *inget* skybox-material — kameran
rensar till färg (`m_ClearFlags = 2`), `RenderSettings.m_SkyboxMaterial` är NULL och
`m_AmbientMode = 3` (Flat). Himlen ligger i stället som **geometri i rumsmallen**: faux-skybox-plan
med en kubkarta (`GalloFauxSkybox` med `_RotatingCubemap`, `_Color = 4.35, 7.22, 11.98`), horisonten
i en shader (`cloudscroll_*` med `_ScreenPositionSplit` 0.4–0.6 av skärmhöjden plus `_ColorTop`/
`_ColorBottom`), och i Gallo Towers en `FauxSkyboxBlocker`-slabbe som skymmer. Ljuset är platt
ambient plus identiska punktlampor (`0.877, 0.658, 0.203`, intensitet 0.75, range 2.0,
**m_Shadows = None**) — och hela spelet saknar lightmaps. Spelaren hålls inne av en osynlig 10×10-
platta per ruta, inte av väggar. Kyrkfönstren i Cappella Magna *är* hålet mot himlen: samma
faux-skybox-material i en egen materialplats.

**Byggt hos oss** (`Dungeon.Floor.öppna` + `main.gd: _öppen_himmel`): en våning kan bära **öppna rum**,
och i dem byggs takrutorna inte — i stället läggs en himmelyta (ett gradientkort, oupplyst) över
rummet och en varm lampa utan skuggor, med referensens egen lampfärg.

**Var himlen får finnas är ett VAL, inte generatorns påhitt.** Första versionen gjorde bossrummet på
varje genererad våning öppet; Alex' dom efter en titt: *"vi ser ut att behöva tak på stället"*. Nu
fyller generatorn aldrig `Floor.öppna`, och ett öppet rum kommer ur **kartdatan** —
`"öppna": [[x, y, bredd, höjd]]` i `data/maps/<bana>_<våning>.json` (läses och skrivs av
`MapIo`). Ett slagfält under öppen himmel är alltså något man ritar in, vilket också är referensens
modell: himlen ligger i RUMSMALLEN, så en våning kan ha öppna och stängda rum sida vid sida.

**Himlen är ett VALV, inte en skiva** (Alex: *"kunna gå över en bro å se himlen runtom"*). En enda
yta räcker rakt upp men inte när man står på en bro och tittar ut; därför är himlen en **cylinder runt
hela våningen** (radie = kartans diagonal/2 + 4 m, höjd 6 m, öppna ändar) plus en plan yta överst.
Cylindern ligger utanför kartans kant och kan därför aldrig stå i en dörröppning eller en gång, och en
våning utan öppna rum ser den aldrig (taket är i vägen). Taket över det öppna har **en** färg i
stället för gradientkortet: på en vågrät yta ligger texturens v-axel i golvplanet, så tonövergången
drogs i sidled och såg ut som en rand — horisonten hör till cylinderns väggar, där "upp" betyder något.

**Mätt i pixlar** (andel blåaktig yta i bildens toppband, 1 280×720): **öppet fält 69,5 % framåt och
71,6 % åt sidan** — himlen står still och finns runtom. **Bro, 1 ruta bred: 30,3 % framåt, 0 % åt
sidan** — skygglorna står en halvmeter från näsan och skymmer sidan upp till 58° höjd, vilket är
precis vad en bro med räcken gör. Dörröppningar och broar är redan gångbara: ett steg tas bara mot
golv (`Explore.forward()` → `"vaggen"`), så rutnätet ÄR stängslet och ingen fysik behövs.
`test_utomhus` (21 kontroller) håller båda ändarna — generatorns våningar har **noll** öppna rum
(taket står på), kartdatans nyckel öppnar ett rum och överlever en sparad karta, och när ett rum väl är
öppet bygger renderaren himmelytan + lampan med referensens färg och utan skuggor. I bild (första
versionen, bossrummet öppet): en trapetsformad öppning mot ljusblå himmel över slagfältet, ~15–20 % av
bilden, med tydliga kanter mot de mörka grottväggarna.

**Kvar:** höga väggar runt det öppna rummet (referensens `FauxSkyboxBlocker`) om kanterna stör — man
ser grannrummens tak ovanför våra låga väggar när man tittar i sidled; en **flaggai kartdatan** så en
handritad våning kan sätta öppna rum själv (i dag bara generatorn); och horisonten i en shader
(`SCREEN_UV.y` mot en split) i stället för ett gradientkort, om himlen ska kunna stå still när man rör
sig.

---

## 11. Väggarna: mörka av sin egen albedo (15/10)

Alex: *"kan vi kika över grafiken på väggarna nu då? Det är alldeles för murrigt och svårt att se
något."* Mätt först, ändrat sedan.

**Mätt i bild** (spelvyn, 1 280×720, en vanlig körning på Asklunden, frisk process per mätning):
medel 0,059, **median 0,0025**, **82 % av vyn under 0,12**, 10 högdagerpixlar. Bilden visade "svarta
ytor med svaga konturerr och ett fläckigt mönster av orange punkter mot svart" — dvs. texturens
LJUSA punkter överlevde medan allt annat krossades.

**Orsaken var albedon, inte ljuset.** Väggarnas textur har median **0,212 i sRGB** — det är **0,035
linjärt**, alltså en vägg som reflekterar 3,5 % av ljuset. Ingen lykta kan lysa upp den: ljus × 0,035
är mörkt hur starkt ljuset än är. Till det kom att **väggarna inte fick någon ton alls**:
`_add_boxes_ytor(..., ruta, skugga_frö, upprepa, ton)` har `ton = Color.WHITE` som default, och
vägganropet skickade bara fyra argument medan golvet skickade `GOLV_TON`. Golvet kunde alltså ses,
väggen inte.

**Åtgärden:** en egen `VÄGG_TON` (3,00, 3,10, 3,40 — samma kyliga nyans som `COL_WALL`), och
golv-/taktonerna ned från ett tidigare försök (golvet blev utfrätt av 5,0; p90 gick till 0,74).
Taket 0,60 → 1,50. Dessutom golvet i den volymetriska dimman från 0,022 till 0,030 och facklans ljus
i dimman från 6,0 till 9,0 (mätt i `-- ljusprov`: 778 → 1 397 högdagerpixlar).

**Mätt efter:** medel 0,059 → **0,237**, median 0,0025 → **0,209**, mörkt 82 % → **23 %**, högdagrar
10 → 2 890 px, och p90 0,433 (alltså inget utfrätt — försöket med 5,0 gav 0,74 och ett vitt golv).
I bild syns nu "block, fogar och stenmönster"; mörkret som är kvar ligger i fogar, skuggor och
avstånd, vilket är dimman som ska bära avståndet.

**Grind:** `test_ljus.gd` kör en våning och läser dimman, facklans dimenergi, avståndsdimman och
väggtonen (och att väggbygget faktiskt skickar in den — den gamla buggen var ett argument som
saknades, inte ett tal som var fel).

---

## 12. Texturpaketet: vad som faktiskt blev bättre (15/10)

Alex pekade på `~/Downloads/Textures` och frågade om något därifrån kan användas i stället, och bad
mig använda normalmappar och råhetskartor. Arbetet ligger i `tools/gen_ytor_paket.py` (egen generator —
`gen_tiles_alex.py` rörs inte, den äger Alex' egna ark).

**Två fällor som kostade mätningar:**
1. **`N.png` i paketet är en PREVIEW**, inte rutan: en rendering av materialet på en cylinder med
   inbakad belysning, och inte kvadratisk (729x745). Albedon är `N_diffuseOriginal.bmp` (1024x1024).
   Mätte jag fel fil fick paketet "dubbelt så brett tonomfång" — det var cylinderns belysning.
2. **Godots importcache.** Att skriva om en PNG gör ingenting förrän `godot --headless --editor --quit`
   har importerat om: första mätningen efter bytet gav *identiska* siffror (0,2368 mot 0,2370) och det
   var inte texturen, det var den gamla `.ctex`-filen.

**Mätt, den här gången på rätt filer** (median / spann p90−p10), vår vägg mot paketets kandidater:

| | median | spann |
|---|---|---|
| vår `asklunden/wall.png` | 0,212 | **0,224** |
| Roots/2 (asklunden) | 0,408 | 0,404 |
| Stone Wall/1 (krypta) | 0,384 | 0,435 |
| Cave Wall/7 (grotta) | 0,318 | 0,329 |
| Cobble Stone/2 (tunnel) | 0,431 | 0,380 |
| Wood Planks/5 (bro) | 0,365 | 0,294 |

Skarven mäts mot rutan **invändigt** (kant mot typisk grannkolumn): fyra av fem är sömlösa, och
`Tiles/6` som hade bredast spann av alla (0,522) hade en SYNLIG skarv (23,9 mot 9,9) — att vrida rutan
ett halvt varv gjorde den värre (36,3), så bytet gick till `Cobble Stone/2` i stället.

**Vad bytet gav — och vad det INTE gav.** I spelvyn (samma fras, samma frö, frisk process per mätning):

| | medel | mörkt | detalj (grannpixlar) |
|---|---|---|---|
| före ljusfixen (M130) | 0,059 | 82 % | 0,0113 |
| efter ljusfixen, egna ytor | 0,237 | 23 % | 0,0234 |
| efter ljusfixen, paketets ytor | 0,232 | 24 % | 0,0236 |

Alltså: **den synliga detaljen kom från ljusfixen** (5,8 % → 11,5 % av pixlarna är kanter), medan
paketets ytor ger +0,0002 — knappt mätbart i den här vyn. Vinsten med paketet är i stället att ytorna
nu bär **riktiga PBR-kartor** (normal, AO, råhet ur `_smoothness`; `_metallic` används INTE — den ligger
på 0,83–0,90 i median i hela paketet, alltså "allt är metall", och skulle göra sten och trä blanksvart).
Reliefen syns svagt, och att höja `normal_scale` från 4,0 hjälper INTE: 7,0 och 10,0 sänker både
detaljen (0,0236 → 0,0209) och ljuset (p50 0,202 → 0,184), samma resultat som den tidigare mätningen i
`_add_boxes`. Reliefen binds av ljuset på ytan, inte av skalan.

**Licensen: CC0 1.0** (Texture Pack by Lynocs, https://lynocs.itch.io/texture-pack) — verifierad på
paketets sida efter att Alex pekat på den. Fri för privata och kommersiella projekt, även ändrad; bara
vidareförsäljning av texturena som de är är förbjuden. Credit är frivilligt och står i `CREDITS.md`.

**Kvar:** golv och tak är fortfarande Alex' egna ark (bytet gäller väggarna, som var klagomålet).

---

## 13. Golv och tak ur samma paket (15/10)

Samma generator, `tools/gen_ytor_paket.py`, ritar nu även `floor_super_0..3`, `floor`,
`floor_crack` och `ceiling` — alltså exakt de namn `_add_boxes_ytor` frågar efter. 25 ytor över fem
teman byts: **albedo och normalmap**, men **inte `_orm`** — Alex' egna råhetskartor ligger kvar.

**Varför ORM:en inte byts (mätt):** paketets `_smoothness` är jämnt matt (median 0,13 → råhet 0,87),
och med den hittar spelets regel "fuktiga ytor blänker" (`GLANS_BLÖT_ANDEL`, Alex: *"så väggar kan se
fuktiga ut, så det blänker gentemot ljus"*) **noll** blöta fläckar: `test_normalprov` föll, hela spelet
blev matt och högdagrarna försvann. Hans kartor har de blöta partierna (33 av temats 33 ORM-rutor i
`bro` ligger över gränsen). Priset är att AO-kartan är ritad för hans mönster i stället för paketets —
en skillnad som knappt syns, mot en glans som försvinner helt.

**Valet sköter generatorn själv nu, på mätning:** för varje plats provas alla varianter i mappvalet,
och den med bredast spann vinner — men bara om skarven är ren. Resultatet: **alla 25 ytor sömlösa**
och alla utom en över vår egen vägg (0,224): kryptans golv har bredast spann av allt (0,702),
asklundens gräs 0,537, brons virke 0,294.

| tema | vägg | sliten vägg | golv | sprucket golv | tak |
|---|---|---|---|---|---|
| asklunden | Roots/2 | Mystical/6 | Grass/16 | Fall Ground/6 | Roof/7 |
| krypta | Stone Wall/1 | Damaged Wall/2 | Floor/18 | Damaged Parquet/3 | Cave Wall/2 |
| grotta | Cave Wall/7 | Mystical/6 | Cave Floor/7 | Fall Ground/6 | Cave Wall/2 |
| tunnel | Cobble Stone/2 | Damaged Wall/2 | Tiles/3 | Damaged Parquet/3 | Magical Wood Planks/3 |
| bro | Wood Planks/5 | Magical Wood Planks/3 | Wood Planks/5 | Damaged Parquet/3 | Wood Planks/5 |

**Tonerna var satta för de gamla, mörka ytorna och blev utfrätta.** Paketets albedon ligger 2–2,5
gånger högre (0,38–0,60 mot 0,21–0,24), så `VÄGG_TON` 3,0 / `GOLV_TON` 1,6 / `TAK_TON` 1,5 gav medel
**0,78** och p90 0,97 — nästan vitt. Svept ned till 0,90 / 0,55 / 0,70, som ger medel 0,281, mörkt
24 % och den högsta detaljen av paket-varianterna (0,0151). Jämför `VÄGG_TON` 1,2/0,9/0,9 → medel
0,428, mörkt 10 %; 0,75/0,42/0,58 → medel 0,218, mörkt 35 %.

**En fjärde ruta kan behöva fyllas på med svag skarv:** `tiles` har bara tre skarvfria rutor, och utan
påfyllning stod `tunnel/floor_super_3.png` kvar **orörd från förra milstolpen** — en ruta av ett annat
material mitt bland de nya. Generatorn tar nu de rena först och fyller på med de ore na; bara om mappen
inte har fyra rutor alls räknas det som fel (0 fel).

**Rutstorleken provad: 512 gav +7 % detalj (0,0133 → 0,0142) för 2,5 gånger tyngre filer** — inte
värt det, så 256 står kvar. **Och den ärliga slutsatsen:** paketets ytor visar mindre fin detalj i vår
vy än Alex' egna (0,0151 mot 0,0236, kanter 5,7 % mot 11,5 %). Det beror inte på skalan — paketet är
målat med större, renare former medan hans ark är brusiga AI-texturer. Bytet är alltså ett byte av
**utseende** (målade material, riktiga PBR-kartor, relief och fogar som syns) och inte av skärpa; i
bild läses rummet som ett sammanhållet målarmaterial, inte som tre olika spel, och högdagrarna ligger
kring 0,54 (p90) — inget som är utfrätt.

---

## 14. Ett material per yta (15/10)

Alex: *"det ser ut som någon kräkts upp färg på väggarna huller om buller ... du blandar hej vilt
texturer mitt på golvet"*. Felet var mitt: `wall_super_0..3` och `floor_super_0..3` tog de fyra
**renaste varianterna** i en paketmapp — men varianterna i en mapp är olika **material** (Grass 16,
15, 14, 13 är fyra olika växter), så varje våning blev ett lapptäcke. Dessutom kom `wall_moss`,
`floor_crack` och `ceiling` från **andra mappar** (asklundens slitna vägg var `Mystical` = det lila
valvet intill grå sten).

**Reglerna nu** (och generatorn skriver bara två mappar per tema):

| regel | varför |
|---|---|
| `wall_super_0..3` och `floor_super_0..3` = **samma ruta fyra gånger** | variationen ska komma från spelets UV, inte från fyra material |
| `wall_moss` / `floor_crack` = näst bästa rutan i **samma** mapp | en sliten variant av samma material, inte ett främmande |
| `ceiling` = väggfamiljens ruta | ett valv av samma sten som väggarna |

Mappvalen ändrades också efter att ha tittat på dem: kryptans golv var paketets `Floor` (teal-mosaik)
och `Tiles` visade sig vara **färgade spelhallsplattor** — kryptan fick `Cobble Stone`, tunneln
`Cave Floor`. Allt mätt med samma spann/skarv-prov som förut: **0 fel, alla ytor över vår egen (0,224)**.

**Tonerna gjordes neutrala** (`VÄGG_TON` 0,95 / `GOLV_TON` 0,58 / `TAK_TON` 0,72, gråa i stället för
färgade). De gamla var varma för att kompensera Alex' varma ark; med målade material *färgade* de om
dem (gräset blev brunt). Mätt efter: vyns medel 0,301, mörkt 18 %, detalj 0,0156, p90 0,554 — inget
utfrätt, och gräset är grönt i bild.
