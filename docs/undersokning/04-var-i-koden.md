# Var en belöning efter körningen kan kopplas in

## Körningens liv och död

`Run.play_out()` i `game/core/run.gd` loopar `advance()` till avslut; skyddsräcket `MAX_STEPS := 5000` ger annars `outcome = "dead"` och en `run_end`-händelse med noteringen `skyddsräcket slog till`. Vanlig död avgörs i `Run.finish_fight()`: vid HP ≤ 0 och utan revive anropas `_finish_with("dead")`, utom på sista våningen där döden räknas som nådd slutbana och ger `_finish_with("reaped")`. `Run.descend()` ger `_finish_with("cleared")` när spaden tas på sista våningen; `_finish()` är reservvägen när `_next_objective()` inte hittar något. Alla dessa skriver en `{"type":"run_end", "outcome":...}` i `run.events`, med statistik (guld, XP, HP, vunna/förlorade strider, dråp, steg och turer). Ingen separat lyckad seger över slutbossen krävs.

## Befintliga utdelningar

- **Guld:** `Run.finish_fight()` räknar stridsguld in i `run.gold`; `_open_chest()` lägger kistguld där. Vid slutet bankar `main.gd` i `_after_state_change()` med `meta.add_gold(run.gold)`.
- **Splitter och ädelstenar:** `Run._open_chest()` höjer `run.shards` och samlar fynd i `run.stenar`. `_after_state_change()` överför de båda till Meta en gång per körning via `_banked`. Grad 0–4 finns i `Meta.GRADER`; kistans djupval ligger i `Meta.pick_sten()` / `Meta.kista_splitter()`.
- **Kort:** vanliga nivåval i `Run._check_level()` går in i körningens deck genom `pick_card()`. Bossval skapas av `_boss_draft()` som `boss_reward` (tre val); `Run.pick_card()` lägger valt kort både i deck och permanent `meta.samling` via `meta.samla(id)`. Bosskort samlas alltså redan före körningens slut.
- **Sparning och progression:** `Meta.to_dict()`/`Meta.save()` persisterar guld, splitter, stenar, samling, körningsräknare m.m. `_after_state_change()` anropar `meta.note_run(...)` jämte unlock och därefter `meta.save()`. `run.gold/shards/stenar`, XP och deck är tillstånd under körningen, inte sparfilens saldo.

## Tre kopplingspunkter

1. **`game/main.gd`, `_after_state_change()`** — bästa stället för permanent utdelning: körningen är färdig, `_banked` skyddar mot dubbelbetalning, och sparning sker direkt efteråt. Lägg eventuell ny Meta-utdelning i samma engångsblock före `meta.save()`.
2. **`game/core/run.gd`, `_finish_with()`** — bästa stället att skapa en resultat-/belöningshändelse i `run.events`; centraliserar död, klarad bana och skördad slutbana, men bör inte själv visa UI eller spara.
3. **`game/main.gd`, `_visa_belöning(e)`** — befintlig presentationsväg för kvitto från en händelse; utöka `RewardFx.från_event()` om den nya belöningen ska få samma synliga stund.

Rör inte `_open_chest()` eller `finish_fight()` för en belöning *efter* körningen: de är lokala kist-/stridsutdelningar och kan köras flera gånger. Ändra inte `run_end`-semantik eller bossens befintliga draft.

## Återanvändning och minsta ingrepp

`RewardFx` i `game/ui/reward_fx.gd` visar redan ett kvitto på 54×74 px, med `LÄNGD := 1.7` sekunder och data från `RewardFx.från_event()`. `_visa_belöning()` kopplar det till händelseflödet. Kistan (`Run._open_chest`) har seedad logik, splitter och ädelstensval; bossens `_boss_draft()`/`pick_card()` löser redan tre kort och permanent samling. `Meta` har värdepåsar, priser (`next_cost`, `next_shard_cost`, `gem_slot_cost`) och atomisk JSON-sparning. Värdshuset är separat UI i `main.gd`; återanvänd dess Meta-köplogik bara om belöningen ska vara ett köp/val.

Minsta variant: skapa en ny belöningshändelse i `_finish_with()` (t.ex. `run_reward` med valt innehåll), låt `_after_state_change()` hantera den inom `if not _banked`, uppdatera saldo/samling och spara; om den kräver spelarval, visa i stället en liten valpanel och spara efter valet. För grind: bygg videre på `game/tests/test_run.gd` för att bevisa exakt en `run_reward` vid `run_end`; använd `game/tests/test_meta.gd` för tur-retur av ny sparad valuta/fält och `game/tests/test_reward.gd` för eventuell visuell översättning. Närmast för en belöningshändelse är `test_reward.gd`; för avslutsordning `test_run.gd`.

## Fallgropar

Spelvyn är 480×270 (`VY` i `main.gd`); slutskärmen är en centrerad panel och `_end_text()` växer redan med splitter/stenrader. Panelhöjd och kvittots placering behöver mätas. `_banked` är nödvändigt mot upprepade `_after_state_change()`-anrop. Ny sparad data kräver `Meta.to_dict()` och läsning/versionering  i  `Meta.load_or_new()`. Översatta UI-nycklar måste följa generatorn `tools/gen_i18n.py` och samtliga språk. `test_meta.gd` har innehållsförväntningar kring trädet och priserna; nya innehållsdefinitioner kan kräva att även de förväntningarna uppdateras.

## Vad jag inte kunde belägga

Jag belägger ingen generisk lootbox-/belöningskö efter `run_end` i nuläget. Om valet måste pausa körningen och vänta på svar är exakt input-/panelordning med befintliga drafts [osäkert] utan ett separat UI-genomspel.
