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
| B | **Kedjan är en belöning**: combo kräver relicen Combo Stack, och `ReceivesComboMultiplier` sitter per kort | Multiplikatorn är alltid på (`Rules.combo_after` räknar upp vid varje stigande steg) | Flagga per kort eller en relic som slår på kedjan | Startlekens skada per tur faller mätbart tills kedjan låsts upp | **byggd som lager** (M123): flaggan per kort, och relik-lagret med Kedjestenen finns och mäts. Kvar: att LÅSA kedjan bakom reliken (en balansändring som kräver mätning) |
| C | **Belöningarna är strypta**: `RewardProbability` per kort, `CardLimit` per kortgrupp, Reroll/Skip/Banish | Fler fiender = fler kort = **lättare**. Mätt: `fiender=3` gav slumpen **+20 pp** | Kortvalet på sannolikhet (under 1) och/eller trögare XP-kurva | Ny grindrad: "fler fiender får inte göra banan lättare" | **prövad, nedlagd** (se nedan) |
| D | **Gratis är inte gratis**: 0-kostnadskort är Crawlers med Duration, eller wilds som förstörs | 18 kort på kostnad 0 ligger kvar; startleken har 4×`lash` (12 skada utan villkor) och **6 mana-positiva** kort (`ember_tome` 1→+2, `hourglass` 3→+5) | Duration/Destroy på gratiskorten (nyckelorden finns redan i 7 kort), eller mananeutrala tomtar | Gratiskortens andel av spelade kort faller; manan slutar gå plus | planerad |
| E | Fienden **telegraferar**, spelaren väljer mål | Telegrammet, målvalet (`inkommande()`, `play(i, mål)`, `_målval`) och **radregeln** finns: alla rader slår, den bakre för 0,6 av sin skada (`BAKRE_SLAG`) | (byggd) | Målvalet slår att inte välja mål (i dag enkelriktad: får inte bli sämre) | **byggd, men valet betalar fortfarande inte: mätt 16 mot 16.** Orsaken är mätt: inget dör på en tur, så att slå den som slår sparar ingenting. Nästa ratt är att göra slaget AVVÄRJBLIGT (frys/nolla den namngivna slagmannen) — telegrammet är vad som gör det valet läsbart |

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
