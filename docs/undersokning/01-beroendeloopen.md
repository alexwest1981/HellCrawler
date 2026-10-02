# 01. Beroendeloopen: vad som håller, vad som är myt

Vad i en roguelite-runda håller spelaren kvar, och vad är branschmyt? Varje påstående är märkt
`[belagt: <url>]` (länken svarar) eller `[resonemang]` (min tolkning, ingen källa). Där källan inte
går att nå står det uttryckligen.

## Hållande mekanismer

### Variabel förstärkning
Ett schema där belöningen kommer efter ett oväntat antal svar ger högst svarsfrekvens och tål
utsläckning bäst. `[belagt: https://en.wikipedia.org/wiki/Reinforcement]` I HellCrawler är kistans
utfall oviss för spelaren men seedat i motorn (`_open_chest`-seed, `pick_sten`), så samma körning
ger samma kista. Det som håller är alltså ovissheten, inte slumpen i sig. `[resonemang]`

### Förlustaversion
Förluster väger tyngre än lika stora vinster. `[belagt: https://en.wikipedia.org/wiki/Loss_aversion]`
Det förklarar varför en räddad körning känns viktig, men roguelite-metans permanenta uppgraderingar
(meta.gd, guld/splitter) tar bort den verkliga förlusten. Förlustaversion driver därför
beslutsångest inne i rundan, inte dödsångesten. `[resonemang]`

### Nära-miss
Nästan-vinster rekryterar vinstkretsar och ökar spelustan, närmast belagt i spelmaskiner och
simulerat spel. `[belagt: https://doi.org/10.1016/j.neuron.2008.12.031]` I HellCrawler är bossens
ögon (`eyes_max`/`eyes_open`: den slår först när alla öppnats) den tydligaste near-miss-knappen.
Effekten kräver att missen är trovärdig; en övertydlig nästan-vinst avskräcker. `[resonemang]`

### Kompetens och flow
Motivation kräver autonomi, kompetens och tillhörighet.
`[belagt: https://en.wikipedia.org/wiki/Self-determination_theory]` Kedjan i stigande manakostnad
(combat.gd, `PlayResult.multiplier` = 1 + combo) är ren kompetensmätning: spelaren ser sin egen
skicklighet som en siffra, och tappar den när kedjan bryts. `[resonemang]`

### Ägande
Man värderar det man äger högre än det man kan få. `[belagt: https://en.wikipedia.org/wiki/Endowment_effect]`
Permanenta kort, ädelstenar och trädnoder (tree.json `soul_cost`) gör nästa körning till "min" och
sänker tröskeln att börja om. `[resonemang]`

### Lärande som drivkraft
Dopamin kodar förutsägelsefel — avvikelsen mellan väntat och faktiskt utfall — inte själva
belöningen. `[belagt: https://doi.org/10.1126/science.275.5306.1593]` En oväntad kista lär spelaren
något och driver därför mer än en garanterad. Det är samma mekanism som gör variabel förstärkning
uthållig, men förklarar varför den gör det. `[resonemang]`

## Myt / tunt

- **"Dopamin = njutning, spel hackar njutningscentrum."** Dopamin är förutsägelsefel och *wanting*,
  inte *liking* (Berridge & Robinsons incentive-salience). `[belagt: https://en.wikipedia.org/wiki/Reward_system]`
- **"Permadeath är kroken."** Förlustaversion förutspår motsatsen — döden driver bort. Det är
  metan (det som behålls) som håller kvar. `[belagt: https://en.wikipedia.org/wiki/Loss_aversion]`
  `[resonemang]`
- **"Variabel förstärkning gör spel beroendeframkallande."** Schemat ger uthållighet, inte njutning,
  och spelarens egna kedjebyggen är inget rent förstärkningsschema. `[resonemang]`
- **"Nära-miss fungerar alltid."** Effekten är kontextberoende och kan vända. `[belagt: https://doi.org/10.1016/j.neuron.2008.12.031]`
  `[resonemang]`
- **"Förlustaversion är robust."** Storleken (~2x) ifrågasätts i replikationer. `[belagt: https://en.wikipedia.org/wiki/Loss_aversion]`
- **"100 %-samlande är motorn."** Tunt. Dragkraften ligger i förväntan och i den egna förmågan, inte
  i att kryssa en lista. `[resonemang]`

## Loopens anatomi i HellCrawler

`Run._init` bygger startleken ur metan och går in på första våningen. `_next_objective` prioriterar
encounter före kista, fackla (bara om hp < 50 %), boss och spade — spänningen bor i HP-poolen och i
rustningspoolen som följer genom körningen (M75, combat.gd). Kedjan i stigande manakostnad nollställs
vid turstart och bryts av två lika kostnader i rad; villkort bryter aldrig. `finish_fight` med hp <= 0
ger död om ingen resningsnod finns, och död på sista våningen räknas som "reaped" (klarad). Belöningar:
level up-draft på 3–4 kort (progress.gd `draft`), bossval 1 av 3 permanenta kort, kista med
guld/läkning/sten, samt splitter per kista. Bossens ögon är den mest avsiktliga nära-miss-knappen.

## Vad man kan mäta lokalt

Räknarna finns redan i motorn; ingen ny telemetri behövs.

- `run_end`: outcome, floors, gold, xp, hp, fights_won, fights_lost, kills, steps, turns — dödsvåning
  per körning.
- `level_up`/`boss_reward`/`card_picked`: erbjudna mot valda kort, alltså pick-rate per kort.
- Per strid: `total_damage`, antal brutna kedjor (`PlayResult.broke_chain`), hp kvar vid seger.
- Kista: faktisk fördelning guld/läkning/sten mot `sten_fönster`/`guld_fönster`.
- M75-rustningspoolens överlevnad över strider.
- trädnoder: intjänad splitter mot `soul_cost` (tree.json) — antal körningar per nod.
- Bossögon: spelade kort innan bossen slår, hp kvar vid träffen.

## Vad jag inte kunde belägga

- Zeigarnik-effektens storlek (svag replikation) — endast `[resonemang]`.
- Målgradientens (Kivetz m.fl. 2006) bidrag i just den här loopen — ingen verifierad källa här.
- Att sessionslängd/"one more turn" har en specifik bevisad mekanism — tunt.
- Förlustaversionens exakta koefficient i spel- (inte lotteri-)kontext.
- PubMed blockerade hämtning (cookies); nära-miss och dopamin belagda via DOI i stället.
