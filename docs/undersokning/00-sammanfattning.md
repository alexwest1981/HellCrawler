# Belöning efter körningen: fyra undersökningar och ett förslag

Fyra agenter kördes parallellt i varsin Orca-worktree den 2 oktober 2026, en fråga var. Deras rapporter
ligger i den här katalogen. Alla fil- och funktionshänvisningar i rapporterna är eftergranskade mot koden
(`Run.play_out`, `_finish_with`, `_after_state_change`, `_banked`, `Progress.draft`, `draft_panel`,
`Meta.pick_sten`, `kista_splitter`, `relics`, `eyes_max/open`, `PlayResult.multiplier/broke_chain`,
`stages.difficulty 1..30`, banornas 5-12 våningar) — inga påhittade namn hittades.

| Rapport | Fråga | Agent |
|---|---|---|
| `01-beroendeloopen.md` | Vad som faktiskt håller en runda vid liv, och vad som är branschmyt | opencode (deepseek-reasoner) |
| `02-lootbox-efter-korningen.md` | Lootboxens form, odds och risker | opencode (deepseek-v4-pro) |
| `03-alternativ-till-lootbox.md` | Tio alternativ till lootboxen | opencode (deepseek-chat) |
| `04-var-i-koden.md` | Var belöningen kopplas in, minsta ingrepp | codex |

(En femte agent, Antigravity, stod still utan att skriva en rad — 6 minuter, 5 sekunders CPU — och
ersattes av den tredje opencode-körningen.)

## Kortversionen

1. **Slumpen är inte det som håller.** Det som driver är ovissheten (förutsägelsefelet), den egna
   skickligheten och det man äger — inte tärningen i sig (01). En lootbox är därför ett *format*, inte
   en motor.
2. **Spelet har redan två starka slutbelöningar:** bankningen av guld/splitter/stenar vid varje körnings
   slut (`_banked` i `main.gd`) och bossvalet "1 av 3 permanenta kort" (`Progress.draft` + `draft_panel`).
   En box som bara lägger till en rullning ovanpå det blir brus (02).
3. **Boxens unika utrymme är den döda körningen** — bossbytet kräver att man fällde en boss, och efter en
   död händer inget annat än en kvittenslista (02).

## Alternativen (ur 03, med min bedömning)

| # | Alternativ | Slag | En runda till | Byggkostnad | Passar i dag |
|---|---|---|:---:|:---:|:---:|
| 1 | Smedens milstolpe | Helt deterministisk | 3 | Liten | Ja |
| 2 | Själa-draften (välj 1 av 3 vid körningens slut) | Spelarens val | 4 | Liten | Ja |
| 3 | Djupets efterlysningar (50 fladdermöss …) | Milstolpar över körningar | 4 | Medel | Ja |
| 4 | Skärselds-trappan (nästa svårighetsgrad som belöning) | Svårighet | 5 | Medel | Ja |
| 5 | Neows arv (tre startvillkor att välja mellan) | Kortbyggande | 4 | Liten | Ja |
| 6 | Räddade själar (fånge flyttar in i värdshuset) | Berättelse/upptäckt | 4 | Stor | Tveksamt |
| 7 | Mörkrets vadslagning (satsa guld/splitter före körningen) | Risk mot belöning | 3 | Medel | Tveksamt |
| 8 | Dagens förbannelse (fast seed + regel, garanterad sten) | Korta mål | 3 | Medel | Ja |
| 9 | Kistans tröst (behåll en del vid död) | Tröst | 3 | Liten | Ja |
| 10 | Rena arkad-loopen (inget sparas) | Inget alls | 2 | Noll | Nej |

## Min rekommendation

**Bygg 1 + 2, och låt boxen vara formen på 2 — inte en egen mekanik.**

- **Grunden (1):** körningens slut betalar deterministiskt efter djup och utförande. `_finish_with()`
  bokför redan allt som behövs (`floor_index`, `kills`, `gold`, `xp`), så det är några rader i
  `_after_state_change()`. Spelaren kan räkna hem nästa trädnod i förväg → målklarhet.
- **Stunden (2):** vid körningens slut, **tre kort att välja mellan** — återanvänder `Progress.draft()`
  och `draft_panel`, samma signatur som bossbytet, ingen ny UI. Ett lågt utfall känns då självvalt i
  stället för utdelat (02:s huvudpoäng).
- **Pity:** räkna boxar i sparfilen, garantera det stora utfallet efter N = 10 utan träff. Synliga odds.

Vill du ha en *slumpbox* ändå: gör den till en tredje väg (a = ren slump, b = välj bland tre,
c = garanterat efter N), men 02 visar att ren slump är den enda varianten som gör ett miss till något
spelet gjorde mot spelaren. Slumpen bör alltså bo i *innehållet*, inte i om spelaren får något.

Oddsen i 02 (per box, stigande med djupet): guld 60/40/25 %, splitter ~20 %, ädelsten 15/22/28 %,
permanent kort 4/12/20 %, kamrat eller relik 1/4/7 % vid våning 1-2 / 5-6 / 9-12. 4 % = 1 av 25 boxar
≈ 8 speltimmar på ytan — **för glest**; 02:s egen slutsats är att siffran bara duger tillsammans med
pity, eller om "stor vinst" räknas som kort + kamrat (5/16/27 %).

## Vad som är belagt, resonerat och osäkert

- **Belagt mot koden:** alla kopplingspunkter, valutorna, att bosskort och splitter redan persisteras,
  att `_banked` skyddar mot dubbelbetalning, att bossen slår först när ögonen öppnats.
- **Resonemang (ingen källa):** alla konkreta odds och trösklar i 02, körningslängden ~20 min,
  30 %-bärgning vid död i 03, och förslagen i 03 i stort.
- **Svagt belagt (01):** källorna är för det mesta Wikipedia och två DOI-artiklar; förlustaversionens
  storlek ifrågasätts i replikationer, och Zeigarnik-effekten är tunn. Behandla 01 som riktning, inte facit.
- **Osäkert:** körningstid per våning, och hur en belöningspanel mitt i en pågående körning samspelar med
  befintliga drafts (04, `[osäkert]`).

## Nästa steg om du säger ja

1. Ny händelse i `Run._finish_with()` (`run_reward` med djup och utfall) — ingen UI, ingen sparning där.
2. Engångsblock i `main.gd:_after_state_change()` innanför `if not _banked`: räkna ut och betala ut.
3. Valpanelen vid körningens slut återanvänder `draft_panel`; spara först efter valet.
4. Grind: `game/tests/test_run.gd` (exakt en `run_reward` per `run_end`), `test_meta.gd` (tur och retur
   för nytt sparfält), `test_reward.gd` (den synliga stunden).
