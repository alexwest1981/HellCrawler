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

Samma mätare med **tre slumpkort i stället för startleken** (Alex' ordagranna bild; ingen spelare kan ha en
sådan lek, så det är ett stresstest): slump 40 / 40 / 50 %, autospelaren 20 / 60 / 80 %. Den tunna leken
klarar sig BÄTTRE än startleken i slumpspel, och förklaringen är värd att känna till: med 3 kort och 4 på
handen drar turen hela leken, varje tur — då är stigande kostnad alltid möjlig, och kedjan blir gratis.
**Kedjan är bara en färdighet när leken är tjockare än handen.**

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
