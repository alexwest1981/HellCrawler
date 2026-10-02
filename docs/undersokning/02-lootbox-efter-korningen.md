# Lootbox efter körningen — form, sannolikheter, effekt

Jag har inte sökt på nätet. Alla siffror är ur repot (`game/data/`, `game/core/meta.gd`, `game/core/run.gd`,
`game/main.gd`) eller märkta `[resonemang]`. Inget är "andra spels data".

## 1. Vad boxen är till för här

Ingen butik, inga köp, en lokal sparfil — boxen kan aldrig bli intäkt. Dess enda uppgift är att göra
slutet av en körning bättre. Tre jobb den KAN göra: (a) tröst efter en död — i dag bankas guld, splitter
och stenar (`main.gd:_after_state_change`) men skärmen läses som en kvittenslista; (b) anledning att gå en
våning till, om oddsen stiger med djupet; (c) variation mellan körningar, om permanent kort eller kamrat
ändrar nästa startlek. Den kan INTE fylla retention, dagslogin eller sälj.

Ärligt: mycket är redan gjort. Bossbytet (välj 1 av 3 permanenta kort, `run.gd:_boss_draft` → `meta.samla`)
och nästa banas upplåsning är redan slutbelöningar. En box som bara lägger till en rullning utan eget jobb
blir brus. Dess unika utrymme: en belöning till en körning som DOG (bossbytet kräver att man fällde en
boss), och en liten chans på något man inte kan köpa direkt (kamrat/relik).

## 2. Innehållstabell

Utfallen använder spelets valutor och bestånd ur `meta.gd`:

| Utfall | Intervall | Värde |
|---|---|---|
| Guld | 60–300 | skräp–neutral; aldrig under en kista |
| Splitter | 2–8 | användbart (trädets permanenta noder, `kostar_splitter`) |
| Ädelsten (grad 1–4) | en sten, familj ur `gems.json` | användbar; grad följer djup som `pick_sten` |
| Permanent kort | 1, ur samma pool som kortvalet (ej crawler/evolution) | stor vinst, går till `samling` |
| Kamrat | rabatt 25–50 % eller fri hyra (1200–12000) | störst; rör ekonomin |

Corrupted Souls ska INTE i boxen — de kommer bara ur bossar (`meta.add_souls`), och en annan källa bryter
den tänkta bromsen. Relics är en tom lista i sparfilen; kan inte falla än.

"Användbart" = splitter, sten grad ≥2, permanent kort, kamrat. Skräp = lågt guld, sten grad 0–1, en duplikat
common. Skräp känns som en förolämpning om det står ensamt; därför: golv = minst en kistas värde, skräpet
väger nedåt mot djupet, och ett miss syns som "inte än" (pity räknar) i stället för "du förlorade".

## 3. Djup-skalningen i siffror

En box efter varje avslutad körning. Våning = `floor_index+1` (banorna har 5–12 våningar, `stage_*.json`).

| Utfall | våning 1–2 | våning 5–6 | våning 9–12 |
|---|---|---|---|
| Guld | 60 % | 40 % | 25 % |
| Splitter | 20 % | 22 % | 20 % |
| Ädelsten | 15 % (grad 1) | 22 % (grad 2–3) | 28 % (grad 3–4) |
| Permanent kort | 4 % | 12 % | 20 % |
| Kamrat/relik | 1 % | 4 % | 7 % |

4 % = förväntat 1 av 25 boxar — precis exemplet. Vid ~20 min per körning `[resonemang]` är det 25 körningar
≈ **8 timmar per permanent kort på ytan: för glest** för ett lokalt spel utan anledning att sträcka sig.
Mitt i (12 %): 1 av 8 ≈ 2,7 h. Djupt (20 %): 1 av 5 ≈ 1,7 h. Slutsats: 4 % duger bara om "riktig vinst"
räknas som summan av permanent kort + kamrat (5 % / 16 % / 27 %), och kompletteras med pity. Djupet ska ge
≈ +2–4 procentenheter per våning på stora vinsten — litet, märkbart, verkligt.

## 4. Trovärdigt i stället för fuskigt

Synliga odds (procenten står på boxen). Pity: räkna boxar i sparfilen, garantera permanent kort efter N=10
(reset vid träff). Ingen dold ränta. Visning: kort (2–3 s), bläddringsbar med Esc/Enter, samma ton som
bossbytet — inte en spelautomat. Osund blir boxen om den blir sysselsättning i stället för spel (stopp: max
en per körning), om död blir billig (stopp: boxen kräver våning 2) eller om save-scumning uppmuntras (stopp:
slå utfallet med körningens seed och skriv det med `_banked` direkt vid körningsslut — samma determinism som
kistan; ingen anledning att skydda hårdare när inget kostar pengar).

## 5. Tre varianter

Samma innehåll, tre former:

- (a) **Ren slump** — ett utfall rullas och visas. Minst kod, men "spelet bestämde"; ett miss känns
  utdelat, inte valt.
- (b) **Val bland tre** — tre dolda val, spelaren väljer ett. Störst agentskap; ett miss känns självvalt,
  vilket löser "skräp = förolämpning". Återanvänder draftpanelen och matchar bossbytets form — konsekvens.
- (c) **Garanterat efter N** — pity, se ovan. Inte en form för sig, ett tillägg till a eller b.

Rekommendation: **(b) val bland tre + pity N=10**. Skälet: spelet har redan "välj 1 av 3" som sin
belöningssignatur, koden finns, och valet gör att en låg roll blir spelarens egen — inget som spelet gjorde
mot henne. (a) sparar en rad men byter bort exakt den känsla som gör boxen trovärdig.

## 6. Risklista

- **Belöningsinflation** (boxen skenar förbi smeden/värdshuset) — broms: kapa boxens tak under butikens
  prisnivå; kamrat bara som rabatt, aldrig alltid gratis.
- **Boxen blir enda skälet att spela** — broms: en per körning, bonus inte mål; djupet betalar redan.
- **Död körning känns billig** (dö på våning 1 för gratis box) — broms: kräv våning 2, och skala oddsen så
  en ytlig död ger nästan bara guld.
- **Sparfilen fylls av skräp** — broms: drop bara valutor (tal) och enstaka kort-id; duplikat i `samling`
  är redan meningsfulla (två kort i startleken).

## Vad jag inte kunde belägga

Körningstid per våning (jag antar ~20 min per körning `[resonemang]`). Någon extern källa om
lootbox-psykologi eller pity-praxis: inga användes. Relikernas innehåll (tom lista i dag). Alex'
tolerans för "för glest" — 4 %/8 h är en siffra, inte ett facit; den är en mätpunkt att bygga efter, inte
en slutsats.
