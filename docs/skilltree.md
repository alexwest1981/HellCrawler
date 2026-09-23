# Plan: massivt permanent skill tree

Alex: *"skill tree behöver vara permanent, men med så pass många noder att man måste spela spelet typ
20 ggr ... sista noderna skall göra så man mer eller mindre har god mode på, vilket behövs för att
klara sista banan ... Den skall vara på gränsen till omöjlig utan att man fyllt hela skill tree't."*

Alla siffror nedan är mätta ur spelets egna filer, inte uppskattade.

## Utgångsläget, mätt

**Trädet i dag:** 25 noder, **58 inköp** att fylla (Järnvägen 14, Benknippet 16, Glöden 12, Girigheten 16).
Fullt ger det: `max_hp +30`, `armor +5`, `start_mana +3`, `mana +2/tur`, `hand +1`, `draw_first +2`,
`recovery +2`, `heal_kill +2`, `revive +1`, `might +0.58`, `area +0.50`, `gold +0.28`, `curse +0.19`.

**Inkomsten:** en bana = 3–7 våningar × 4–8 möten och **en boss** (`stage_01`: 3×4, `hollow_choir`).
Sista banan `stage_40` "Första ugnen": svårighetsgrad 9, **7 × 8 = 56 strider**, boss `bellmother`,
`final_boss pale_reaper`.

**Svårighetsskalan** (`run.gd:17–19`, `350–352`): fiende-HP `1 + 0.10 × (svårighet − 1) + hp_per_floor ×
våning`, fiende-skada `1 + 0.06 × (svårighet − 1)`. Vid svårighetsgrad 9 är fienderna alltså **+80 % HP**
och **+48 % skada**.

**Glappet:** ett fullt träd ger i dag +58 % skada och +30 HP medan sista banan är +80 % tåligare. Banan
går alltså att klara utan fullt träd — den är svår, inte en grind. Det är det som ska ändras.

## Målet

| | I dag | Mål |
|---|---|---|
| Noder | 25 | **~90** |
| Inköp att fylla | 58 | **~180** |
| Körningar att fylla | ~15 | **~20** |
| Fullt träd ger (skada) | +58 % | **~+150 %**, och de sista noderna ger stora språng |
| Sista banan utan trädet | klaras | **förloras** |
| Sista banan med fullt träd | trivialt | **vinns med 5–10 % marginal** |

## Formen: 4 grenar × 6 nivåer + tvärlänkar

Grenarna behålls (Järnvägen, Benknippet, Glöden, Girigheten) och får sex nivåer var i stället för tre
till fem. Nivå 1 är rotnoden, nivå 6 är grenens krona.

- **Nivå 1–2:** priser 1–3 CS, små steg (+2–4 %), öppnar grenen.
- **Nivå 3–4:** priser 4–9 CS, tydliga steg, och här sitter **tvärlänkarna** — noder som kräver en nod i
  *en annan* gren (mönstret finns redan: `wick_2` kräver `wick_1` + `iron_2`). De gör grenarna till ett
  träd i stället för fyra staplar.
- **Nivå 5:** priser 10–18 CS, stora steg (+10–15 %), förkraven hårda.
- **Nivå 6 — kronan:** priser 20–30 CS, och effekter som ändrar hur spelet spelas:
  - **Järnvägen:** *allt du slår på brinner* (skada over area i stället för bara den träffade).
  - **Benknippet:** *du reser dig tre gånger i stället för en*.
  - **Glöden:** *handen fylls till fullt varje tur* (ingen kortsnålhet kvar).
  - **Girigheten:** *fienderna tål mer men ger dubbelt* — risken blir en affär, inte ett straff.

Kronorna är "god mode" med flit: de är meningslösa att köpa förrän man är i slutet, och tillsammans är
de skillnaden mellan att dö på våning 5 i sista banan och att gå igenom den.

## Inkomsten: CS per boss, stigande

En boss ger `1 + svårighetsgrad / 2`, avrundat nedåt — **1 CS** i Asklunden, **5 CS** i Första ugnen —
och `final_boss` ger **25 CS** en gång per genomspelning. Det gör tidiga körningar långsamma och sena
körningar värdefulla, vilket är rätt: de sista nivåerna i trädet ska kännas som om de kommer från det
du klarade, inte från att du nötte samma bana.

Kontrollräkning mot målet: 20 körningar över hela svårighetsspannet ger `20 × (1…5 + enstaka 25)` ≈
**190 CS**, mot en total kostnad på **~180 CS**. Trädet fylls alltså på ungefär tjugo genomspelningar,
och sista banan är både grindet och inkomstkällan.

## Grinden, som prov

Sista banan tunas mot trädet och mäts, inte tycks:

- `stage_40`: bossens HP höjs så att en full trädkörning vinner med **5–10 %** marginal.
- Provet (`game/tests/test_grind.gd`) spelar **stage_40 headless två gånger** — en gång med tomt träd,
  en gång med fullt — och kräver: **tomt = förlust, fullt = vinst**. Ändrar någon fiendesiffrorna eller
  trädets effekter så att den ena halvan faller, går provet rött.

Det provet är hela poängen med planen: "på gränsen till omöjlig" ska vara ett tal, inte ett omdöme.

## Byggordning

1. `souls`-kassan i `Meta` + droppen där bossen dör (`run.gd:101–109`) — efter formeln ovan.
2. `tools/gen_tree.py` som genererar `tree.json` ur gren/tier-specen (som konstverktygen genererar
   sina ark ur en form). ~90 noder för hand är 90 chanser att skriva fel samma sak två gånger.
3. Priserna och kronorna, med ett prov som räknar summan: **180 inköp, ~180 CS**.
4. Glöden i vyn: alla noder syns, upplåsta lyser starkare per rang, olåsta står släckta.
5. `test_grind.gd` och tuning av `stage_40` mot det.

## Prestige (efter allt ovan)

Trädet är permanent, så prestige ska inte nollställa det. Rätt form är ett **lager ovanpå**: när trädet
är fullt öppnar korrumperade själar en fortsättning — "trädet brinner" — där noderna kan korrumperas
vidare mot något nytt. Det byggs när trädet går att fylla, inte innan.
