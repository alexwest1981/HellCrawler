# Alternativen till lootboxen — tio sätt att belöna en avslutad körning

*Undersökningsmetod:* Nätåtkomst aktiv. Externa källor märks `[belagt: <url>]`; resonemang och kodanalys märks `[resonemang]`. Källor jag inte kunnat kontrollera anges i slutet.

**Utgångspunkt.** En lootbox ger variabel belöning men kopplas till speltrötthet och minskad autonomi [belagt: https://doi.org/10.1371/journal.pone.0206767]. Self-Determination Theory pekar i stället på valfrihet och bemästring som långsiktiga drivkrafter [belagt: https://doi.org/10.1037/0003-066X.55.1.68]. HellCrawler har redan flera valutor: guld, ädelstenar (`game/data/gems.json`), splitter (`meta.shards`), permanenta bosskort (`meta.samling`) och hyrbara kamrater (`game/data/crawlers/00_kamrater.json`). Här är tio alternativ, ett per slag.

## 1. Smedens milstolpe (Helt deterministisk)
Belöningen vid körningens slut räknas fram ur fakta, aldrig ur en tärning: guld **plus** splitter som en funktion av nådda våningar, fiender och banans `gold_bonus`/`xp_bonus` [resonemang]. Körningen bokför redan allt som behövs i `_finish_with()` i `game/core/run.gd` (`floor_index`, `kills`, `gold`, `xp`). Spelaren ser exakt vad som väntar och kan räkna hem nästa trädnod (`meta.next_cost`, `next_shard_cost` i `game/core/meta.gd`). Drivkraften är målklarhet, inte överraskning. Risk: kan kännas som kalkylark om summorna inte varieras mellan banor.

## 2. Själa-draften (Spelarens val)
Vid körningens slut visas tre kort och spelaren väljer ett [resonemang]. HellCrawler har redan exakt den mekaniken: `Progress.draft()` i `game/core/progress.gd` bygger tre val (varav ett fjärde med tur) och `draft_panel` i `game/main.gd` visar dem. Att låta en boss körningens sista val gå genom samma panel ger autonomi utan ny UI. Drivkraft: spelaren väljer en synergi och vill testa den i nästa bana. Risk: ett val kan dominera och döda variationen.

## 3. Djupets efterlysningar (Milstolpar över flera körningar)
Kumulativa mål över många körningar — "fäll 50 fladdermöss", "nå våning 5 med en kamrat" — som var och en låser upp ett kort eller en kamrat, i stil med *Vampire Survivors* [belagt: https://vampire-survivors.fandom.com/wiki/Unlocks]. HellCrawler har räknare i `game/core/meta.gd` (`runs`, `best_floor`) och en händelseström (`run_end`, `combat_end`) att hänga lyssnare på. Drivkraft: att se räknaren stå på 45/50 ger en impuls att ta en runda till. Risk: enkla mål kan nötas på låga våningar.

## 4. Skärselds-trappan (Svårighetsökning som belöning)
Att klara en bana låser upp nästa svårighetsgrad med tuffare fiender och glesare kistor, som Ascension i *Slay the Spire* [belagt: https://slaythespire.wiki.gg/wiki/Ascension]. Repot har redan skalan: `stages.difficulty` (1–30 i `game/core/stages.gd`) och banregler (mutatorer) via `regel` och `game/core/regler.gd`. Drivkraft: bemästring och prestige — segern bevisar skicklighet och öppnar en hårdare utmaning [resonemang]. Risk: stöter bort spelare som vill ha avkopplande maktfantasi.

## 5. Neows arv (Kortbyggande som belöning)
En slutförd runda ger tre startvillkor att välja mellan (t.ex. starta med extra mana eller en permanent uppgradering), likt Neow i *Slay the Spire* [belagt: https://slaythespire.wiki.gg/wiki/Neow]. Repot har byggstenarna: permanenta uppgrapplingar i `game/data/powerups.json` (`DEFS_PATH` i `meta.gd`) och `meta.stat()` som läses i `begin_fight()` i `game/core/run.gd`. Drivkraft: nästa runda börjar med en unik regelbrytare som spelaren vill prova [resonemang]. Risk: spelaren kan starta om tills rätt bonus ges.

## 6. Värdshusets räddade själar (Berättelse och upptäckt)
Att nå bestämda våningar befriar en fånge som flyttar in i värdshuset (`game/ui/village_view.gd`) med ny replik och passiv förmåga [resonemang]. Kamratdatat ligger i `game/data/crawlers/00_kamrater.json` och hyrs för 1200–12000 guld. Drivkraft: upptäckarglädje — belöningen vidgar världen i stället för att blåsa upp siffror [resonemang]. Risk: kräver löpande text och porträtt; när karaktärerna tar slut upphör drivkraften.

## 7. Mörkrets vadslagning (Risk mot belöning)
Före körningen satsar spelaren guld eller splitter ur `meta.shards` på ett villkor — överlev våning 5 oskadd ger tre gånger insatsen [resonemang]. Valet görs i byn (`game/ui/village_view.gd`), villkoret kontrolleras i `_finish_with()` i `game/core/run.gd` och avräkningen sker där splittret bankas i `game/main.gd`. Drivkraft: förlustaversion och spänning; revanschlust efter torsk, snabbare väg till dyra kamrater efter vinst. Risk: stora förluster kan skapa tilt och avhopp.

## 8. Dagens förbannelse (Korta mål i stunden)
En daglig runda med fast seed och en modifierare ur `game/core/regler.gd` ger en garanterad ädelsten vid första klarade försöket [resonemang]. Godot ger datum via `Time.get_date_dict_from_system()`, som kan bli seed på samma sätt som `run.seed_value` redan styr kistor (`_open_chest` i `game/core/run.gd`). Drivkraft: tidsaktualitet och avgränsning — en färdig utmaning bryter vanemönstret. Risk: utan topplista falnar intresset snabbt.

## 9. Kistans tröst (Tröst för förlorad körning)
Vid död behålls en del av guldet och splittret, medan en klarad bana ger allt [resonemang]. Bankningen ligger redan på ett ställe, `_banked` i `game/main.gd`, och utfallet sätts i `_finish_with()` (`"dead"`, `"reaped"`, `"cleared"`). En koefficient på det bankade beloppet räcker. Drivkraft: minskar förlustsmärtan och gör döden till ett taktiskt avvägande i stället för ett straff. Risk: för generös tröst tar bort nerven, för snål skapar uppgivenhet.

## 10. Den rena arkad-loopen (Inget alls)
Körningen tar slut och ingenting sparas; bara spelarens skicklighet följer med, som i klassiska arkad-roguelikes [resonemang]. Full inre motivation och mästerskap [belagt: https://doi.org/10.1037/0003-066X.55.1.68]. Kostnaden i repot är noll — koppla bort bankningen i `_banked` i `game/main.gd`. Men det passar inte HellCrawler: värdshuset, ädelstenarna och talangträdet (`game/data/tree.json`) bygger helt på att splitter och guld sparas mellan körningar.

## Sammanställning och rekommendation

| Mekanism | Driver "en runda till" (1–5) | Byggkostnad | Passar HellCrawler i dag |
|---|:---:|:---:|:---:|
| **4. Skärselds-trappan** | 5 | Medel | Ja |
| **2. Själa-draften** | 4 | Liten | Ja |
| **5. Neows arv** | 4 | Liten | Ja |
| **3. Djupets efterlysningar** | 4 | Medel | Ja |
| **6. Räddade själar** | 4 | Stor | Tveksamt |
| **9. Kistans tröst** | 3 | Liten | Ja |
| **1. Smedens milstolpe** | 3 | Liten | Ja |
| **8. Dagens förbannelse** | 3 | Medel | Ja |
| **7. Mörkrets vadslagning** | 3 | Medel | Tveksamt |
| **10. Den rena arkad-loopen** | 2 | Noll | Nej |

**Rekommendation:** **Smedens milstolpe (1)** som grund — den kräver nästan ingen ny kod, eftersom `_finish_with()` och bankningen redan bokför allt — och **Själa-draften (2)** ovanpå, eftersom `Progress.draft()` och `draft_panel` redan finns. Tillsammans ger de kalkylbarhet *och* ett val, vilket är precis den kombination SDT pekar på [belagt: https://doi.org/10.1037/0003-066X.55.1.68]. Skärselds-trappan (4) är det starkaste långsiktiga tillägget, men kräver balansarbete över de 90 banorna.

## Vad jag inte kunde belägga
- Exakta retention-siffror för "daily challenges" i spel utan globala topplistor — ingen tillförlitlig källa hittad.
- Den exakta siffran för optimal bärgningsprocent vid död i kort-roguelites; alla värden ovan (t.ex. 30 %) är mina egna förslag [resonemang], inte mätta.
- Att `meta.shards` räcker som enda riskvaluta i en vadslagning — det är ett förslag, inte verifierat mot hur spelare faktiskt värderar splittret.
