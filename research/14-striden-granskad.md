# Striden granskad mot referensen (mätt 19/10)

Frågorna: håller balansen, liknar korten varandra i effekt, och finns det specialeffekter när man
attackerar, blir attackerad och får ett nytt kort?

## 1. Balansen — grön, och den mäter rätt sak

`tools/ett_prov.sh tests/test_balans.gd` → **5 kontroller, 0 fel**:

| Policy | Klarade av 90 |
|---|---|
| slumpen | 12 |
| autospelaren | 33 |
| rutten (spela efter kartan) | **47** |
| målval (välj mål) | 35 |
| avvärjning (blocka) | 45 |

Provet kräver tre saker: slumpen klarar högst 12, bästa policyn är minst 2× slumpen, och både målval
och avvärjning gör det **inte sämre**. Vi ligger på 3,9×. Balansen är alltså inte bara "densamma" —
den är mätt, och bättre spel belönas.

Svagheten: 3 banor × 3 frön. Det räcker för att upptäcka att spelet blivit för lätt eller för svårt,
men inte för att säga något om en enskild banas kurva.

## 2. Kortens effekter — sju operationer, och de tunga multiplikatorerna finns

92 kort i fem filer: **47 attack, 18 crawler, 17 item, 6 mana, 4 wild**.

| Operation | Antal |
|---|---|
| `damage` | 61 |
| `armor` | 22 |
| `heal` | 17 |
| `draw` | 16 |
| `mana` | 12 |
| `freeze` | 9 |
| `knockback` | 6 |

Stridsmotorn bär dessutom det som gör referensens skada till referensens skada: `combo` (1+combo
multiplicerar), `might`, `area`, `gems` (multiplikatorer per kort) och `duration` (kort som stannar i
spel och triggar N gånger). Det är samma formel-familj som referensens
`(CardDamage + CardDamage*Combo + …) * (1+Might) * (1+Area/5) * Gems`.

**Det som saknas mot referensen:** `disarm` (finns som resistens där, inte alls hos oss), `coins`/`greed`
och `xp` som kortoperationer, och **triggers per kortfärg** — bara 2 av 92 kort har ett `trigger`-fält,
medan referensen har en trigger på varje Crawler.

## 3. Specialeffekter — attack ja, träff ja, nytt kort bara ljud

| Händelse | Vad som händer i dag |
|---|---|
| **Du attackerar** | `AttackFx` ritar en av fem former beroende på korttyp (klinga, piska, kross, ringar, glöd), skalad av combo; hit-stop 0,045 s (0,11 s vid combo ≥ 3); siffra med kontur; pixelregn; splitter vid dråp; skärmen skakar vid dråp |
| **Du träffas** | Röd blink över vyn (`_blink_röd`, styrka efter skadan) + HP-, mana- och rustningskärlen far till. **Vyn skakade inte** — tillagt nu |
| **Du får ett nytt kort** | Ljudet `card`, och kortet DELAS IN: `CardView.dela_in()` skalar från `DELA_KRYMP` till 1 med TRANS_BACK och tonar in, förskjutet ett steg per kort. Ankomsten fanns redan |
| **Nivå upp** | Ljudet `level_up` |

Det är den tydligaste obalansen i feedbacken: **anfallet har fem former och en skakning, medan de två
ögonblick som betyder mest för spelarens beslut — att bli träffad och att få ett kort — har ett ljud.**

## 4. Vad jag skulle göra först, i ordning

1. ~~Nytt kort får en ankomst~~ — **fanns redan** (`dela_in`). Enda kvarvarande yta: ingen glöd på
   kortet när det är nytt, bara rörelse och ljud.
2. ✅ **Träffad: vy-skakningen** — `_blink_röd` anropar nu `skaka()` med styrka efter skadan. Blinken
   fanns redan; det var rörelsen som saknades.
3. **Trigger per färg**: låt `trigger` läsa kortets `type`/färg på de 16 crawler-korten. Motorn har
   redan `field` (kort som stannar) och `_reagera_i_spel`.
4. `disarm` som operation — nyckelordet finns i referensens fiendedata; hos oss är det bara `freeze`.

## 5. To-do (tillagt i `ONSKEMAL.md`)

Punkt **40 Unlocks**, **41 Relics**, **42 Permanenta boosts för det man åstadkommit** (3 000 fiender,
1 000 kort av en typ, med mera). Formen för 42 är en räknare i `Meta` och en boost i samma
nyckelvokabulär som kamraternas passiv, så den går in i striden genom `Meta.stat()` utan ny kod där.
