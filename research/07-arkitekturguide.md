# Arkitekturguiden: så gör referensen, och så gör vi

Underlag: `research/06-referensbygget.md` (vad som går att läsa ur installationen) och
`research/referens-vokabular.txt` (deras egna nyckelnamn ur Shared Data-tabellerna — **bara
identifierare**, ingen text, inga bilder, ingen kod). Ingenting av deras innehåll hamnar i vårt
spel: vi lånar **strukturen**, namnen och texterna är våra egna.

Alex målbild (2026-09-19): *"kan du använda deras arkitektur och struktur som guide till vårt?
Allt från effekter när man vinner eller låser upp saker, till hur poängen räknas ut, gameloops,
osv? Du skall inte kopiera något, vi skall bygga eget."*

---

## 1. Deras systemkarta, och vår

Deras `GlobalKeywords` är en lista över allt spelet består av. Läst rakt av, och ställt mot oss:

| Deras system | Vad det är | Vårt läge |
|---|---|---|
| `VILLAGE` | Byn mellan körningarna: köp, upplåsningar | **klart** — byn är slutskärmen (`_village_text`) |
| `DUNGEONS` | Banor med våningar, taggade (`DungeonTag`) | **klart**, 40 banor / 200 våningar |
| `CARDS` | Kort som data (`CardModel`) | **klart**, 61 kort |
| `CRAWLERS` | Karaktärer man spelar som, med BIO/FN | **saknas** — vår plan: karaktärsval i menyn |
| `POWER_UPS` | 21 permanenta stats, ranger köpta för guld (`PowerUpConfig`) | **klart** för 8 av 21 |
| `RELICS` | Upplåsningar av *system*, inte stats (`RelicConfig`) | **saknas** — `meta.relics` finns redan i sparfilen |
| `GEMS` | Gem som byter kortets **typ** (`GemSlotModel`, `CardGemsModel`) | **saknas** — fältet `gems` finns i `Run` |
| `ARCANA` | Run-modifierare man hittar och väljer (`Arcanas`) | **saknas** |
| `ACHIEVEMENTS` | Upplåsningsmotorn (`PowerUpAchievement`) | **saknas** |
| `COFFIN`, `MUSEUM`, `BLACKSMITH`, `JEWELLER`, `INN_KEY` | Rum/verkstäder i byn som *låses upp av relics* | **saknas** |
| `COMBO`, `COMBO_PILE` | Kedjan lägger kort i en hög man kan spela ur | delvis: vi har kedjan, inte högen |
| `HAND`, `DECK`, `DRAW_PILE`, `DISCARD_PILE` | Högarna | **klart** motsvarande (hand, draghög, slänghög) |
| `REVIVE` | Återuppståndelse (Revival-stat) | **saknas** |
| `STAT_*` (19 st) | Se tabellen i §3 | 8 av 19 |
| `TYPE_*` (8 st) | attack, debuff, def, free, mana, pickup_void, special, wild | 5 av 8 (vi har ingen debuff/def/free/special-åtskillnad) |
| `ENDER` | Kort som avslutar turen | **saknas** — vår plan: `ender` som korttyp |

**Slutsats:** vår kärna (kort, kedja, mana, motståndartur, våningar, by, guld) är samma maskin som
deras — det är därför balansen håller. Det som fattas är *skalen runt omkring*: upplåsningar,
gem-systemet, arcanor och karaktärer. Det är också precis de fyra som gör en roguelite långlivad.

## 2. Gameloopen, i deras ord och våra

```
DERAS                                    VÅRT (idag)
village → välj dungeon                   byn → R = ny körning
  ↓                                        ↓
våning (rum, fiender, skatt, coffin)     våning (rum, 17 fiender, shovel)
  ↓                                        ↓
strid: hand ur draghögen                 strid: hand ur draghögen        ✓
  tur: spela kort i stigande mana        tur: samma, kedja ger ×1..×6    ✓
  combo → COMBO_PILE (spela ur högen)    kedja, men ingen hög            ✗
  fienden svarar, lägsta raden slår      samma regel                     ✓
  ↓                                        ↓
level up → välj 1 av 3                   nivå → välj 1 av N              ✓
  ↓                                        ↓
shovel → nedåt                           shovel → nedåt                  ✓
  ↓                                        ↓
död/sista våningen → END_SHEET           död/sista → slutskärm           ✓
  END_SHEET visar: våningar, strider,      visar: våningar, strider,
  guld, xp, GEMS, RELICS, KEYWORDS         guld, xp                        ✗ (tre kolumner kvar)
  ↓                                        ↓
guldet bankas → byn: power-ups            guldet bankas → byn             ✓
  achievements → relics → SYSTEM           (ingen upplåsningskedja)        ✗
```

**Att ta efter, i den ordning det ger mest:**

1. **Slutskärmen ska visa vad man *samlat*** — deras har fyra decimal-kolumner
   (`END_SHEET_4_DEC_GEMS/RELICS/KEYWORDS`). Vår slutskärm visar bara summor. Det är den billigaste
   belöningen i hela spelet: spelaren ser sitt eget innehåll växa.
2. **Upplåsningskedjan: prestation → relik → system.** Deras prestationer bär namnet på vad de låser
   upp (`REWARD_UNLOCK_MF_01`, `UNLOCK_COMBO`, `UNLOCK_BRAVESTORY`) — alltså: *en prestation är en
   upplåsning*, inte en trofé. Vår by ska växa på samma sätt: klara banan tre gånger → lås upp
   smeden (uppgradera kort) → lås upp juveleraren (gems) → osv. Det gör att byn ser olika ut för
   två spelare.
3. **Gems byter kortets typ** (deras gem-typer: `ARMOR`, `ATTACK`, `MANA`, `RAINBOW`, `SPECIAL`).
   En gem är alltså inte "+2 skada" utan *"det här attackkortet räknas som manakort"* — det ändrar
   vilka kedjor som är möjliga. Det är därför deras kort inte tar slut på idéer. Vår motsvarighet:
   `gems` på kortet ändrar dess `card_type`, och kedjeregeln (stigande kostnad) läses om.
4. **Arcanor är run-modifierare**, inte permanenta: de gör varje körning olikartad (deras lista har
   bl.a. `BATTLE_STANCE`, `AND_ANOTHER`). Vår plan: en arcana väljs vid körningens start och ändrar
   en regel (t.ex. "kedjan ger ×2 vid 5 kort", "första kortet varje tur är gratis").
5. **Revive efter döden**: deras `REVIVE`-stat och `COFFIN`-system gör döden till en händelse i
   stället för ett slut. Värdigt att ta efter när arcanorna finns.

## 3. Statsen: deras 21, våra 8

| Deras | Betydelse | Vårt idag |
|---|---|---|
| `MIGHT` | skada | ✓ `might` |
| `AREA` | area | ✓ `area` |
| `COOLDOWN` | mana per tur | ✓ `cooldown` |
| `SPEED` | kort i handen (`STAT_HAND_SIZE`) | ✓ `speed` |
| `ARMOR` | rustning | ✓ `armor` |
| `RECOVERY` | läkning per strid | ✓ `recovery` |
| `MAX_HEALTH` | max-HP | ✓ `hollow_heart` |
| `CURSE` | fiende-HP upp, guld upp | ✓ `curse` |
| `AMOUNT` | antal (skademultiplikator) | — |
| `DURATION` | varaktighet | — |
| `LUCK` | tur (draftval, drops) | — |
| `GREED` | guld | — |
| `GROWTH` | xp | — |
| `MAGNET` | upplockningsradie | — |
| `REVIVAL` | återuppståndelser | — |
| `REROLL` | slå om kortvalet | — |
| `BANISH` | plocka bort kort ur poolen | — |
| `SKIP` | hoppa över ett kortval | — |
| `CHARM` | övertala fiender | — |
| `RISK` | risken i körningen | — |
| `CHARACTER_SLOT` | fler karaktärer | — |

De fyra som betyder mest för känslan och är billigast att bygga: **`REROLL`** (gör kortvalet till en
valsituation i stället för ett lotteri), **`BANISH`** (låt spelaren forma sin egen hög),
**`REVIVAL`** (döden blir ett beslut), **`LUCK`/`GREED`** (gör körningarna olika rika). Alla fyra
är en rad i `data/powerups.json` + en rad i `Run`, eftersom metan redan är stat-driven.

## 4. Poängen och belöningen: så räknar de, så räknar vi

| | Deras | Vårt |
|---|---|---|
| Mjuk valuta i körningen | guld, skalat av `GREED` | `gold` × `gold_bonus()` (curse ger mer) ✓ |
| Belöning per strid | guld + xp + drop-chans | guld + xp ✓ |
| Permanent valuta | guld bankat i byn | `meta.gold`, bankas vid körningens slut ✓ |
| Risk | `CURSE` höjer fiende-HP **och** guld; `RISK_CAPS`/`RISK_DETAIL` visar taket i gränssnittet | `curse_scale()` gör samma sak — men vi **visar inte taket** ✗ |
| Svårighet | fler våningar + fler varianter per biom (`MAD_FOREST`, `_02`, `_03`) | 40 banor, difficulty 1–9 ✓ |
| Slutsumma | `END_SHEET` med våningar, strider, guld, xp + gems/relics/keywords | fyra av sex ✓ |

Åtgärdspunkter: **visa förbannelsens tak** (deras `RISK_CAPS` är en varning innan spelaren trycker,
inte en förklaring efteråt) och **tre fler kolumner på slutskärmen**.

## 5. Effekter vid vinst och upplåsning

Deras `Effects`-tabell har 358 nycklar, varav en stor del är `*_KEYWORD` — varje kort kan bära
nyckelord som *ändrar regler*: `Knockback`, `Reverse Combo`, `Destroy`, `Bounce`, `Pierce`,
`Freeze`, `Evolved`, `Wild`, `Scavenge`. Våra sju ops (`damage`, `armor`, `heal`, `mana`, `draw`,
`knockback`, `freeze`) täcker fyra av dem.

**Kedjan vi bör bygga, i ordning:** `destroy` (kortet förstörs när det spelas — gör tunga kort
engångs), `pierce` (slår igenom till nästa rad), `bounce` (studsar till en annan fiende),
`reverse_combo` (spelas i fallande kostnad — en andra väg genom handen), `scavenge` (drar ett kort
ur slänghögen), `evolved` (kortet uppgraderas när ett villkor är uppfyllt).

För upplåsningar: **deras upplåsningseffekt sitter i prestationen** (`REWARD_UNLOCK_*`), och
belöningen är alltid något *namngivet* — en bana, en relik, ett system. Vår motsvarighet blir
`data/achievements.json` med `{id, villkor, belöning}` där belöningen är ett `unlock`-id som
byn läser. Då kan en prestation aldrig bli en död trofé.

## 6. Gränssnittet: deras 411 menyrader mot våra 39

Deras `Menus`-tabell är en checklista för allt en färdig startmeny innehåller, och den är
mätt — inte gissad. Deras nycklar i urval:

- **Start:** `NEW_GAME`, `CONTINUE`, `LOAD_GAME`, `DELETE_ALL_SAVE_DATA`, `QUIT`
- **I körningen:** `ABORT_RUN` (avbryt mitt i), `ACHIEVEMENT_STATUS_LOCKED/OBTAINED`
- **Inställningar:** `ACTION_COMPOSITE_*` (tangentbindningar — de låter spelaren binda om), ljud,
  bild, språk
- **Kortvalet:** namn, beskrivning, nyckelordstooltip (`KeywordTooltip` är en egen klass)

Vår plan för startmenyn (Alex önskemål: språkval i settings) är alltså: **Ny körning, Fortsätt,
Bana, Karaktär, Inställningar (språk, ljud, tangenter), Statistik/Prestationer, Avsluta** — och
språkdelen är redan byggd (§7). Tangentbindningar är den enda punkten där de är klart före oss och
där en QoL-modds hela existensberättigande ligger (tillgänglighetsmoddarna i `research/05-moddar.md`
finns just för att originalet inte hade det från början).

## 7. Språken: gjort

Byggt 2026-09-19: 13 språk (deras tolv + svenska), tvålagersmodell som deras — nycklar i data,
värden per språk, `PseudoLocale`-principen översatt till vårt prov (en nyckel som saknas syns).
`Tr` faller tillbaka på svenska, och en språkfil som inte har hela gränssnittet får inte väljas.
Mätt i `tests/test_i18n.gd`: **101 kontroller**, alla gröna. Svenska och engelska är 100 %,
de elva andra har hela gränssnittet (22 % av alla nycklar) och fylls på med innehållsnamn etappvis
— siffran visas i menyn i stället för att döljas.

## 8. Siffrorna: deras, våra, och vårt mål

Uppmätta ur bygget (nyckelrötter; deras faktiska antal innehållsposter ligger oftast något lägre
eftersom namn/beskrivning delar rot):

| Tabell | Deras (mätt) | Vårt nu | **Vårt mål** |
|---|---|---|---|
| Kort | 262 | 61 | **300** |
| Gems | 137 | 0 | **150** |
| Relics | 68 | 0 | **60** |
| Arcanor | 52 | 0 | **60** |
| Banor | 42 | 40 | **60** |
| Power-ups (stats) | 21 | 8 | **24** |
| Effekter/nyckelord | 358 | 7 | **90** |
| Globala nyckelord | 56 | 3 | **60** |
| Prestationer | ~300 | 0 | **400** |
| Menyrader | 411 | 39 | **420** |
| Språk | 12 | **13** | 13 |

Målet är alltså ungefär **1,5 gånger deras volym** — "matcha och övermanövrera med god marginal" —
med samma arkitektur, egna namn och egna texter.

## 9. Vad vi tar härnäst, i ordning

1. **Startmeny med settings** (språkvalet är klart, menyn är inte byggd) — Alex första önskemål.
2. **Slutskärmen: gems/relics/keywords-kolumnerna** — belöningen för allt annat.
3. **Relics + upplåsningskedjan** (`data/relics.json` + `data/achievements.json`) — byn börjar växa.
4. **Gems** som typbyte på kort, med juveleraren som upplåst verkstad.
5. **Arcanor** vid körningens start.
6. **De fyra statsen** `reroll`, `banish`, `revival`, `luck`.
7. **Effektkedjan** `destroy`, `pierce`, `bounce`, `reverse_combo`, `scavenge`, `evolved`.
8. **Kort- och banexpansion** till målen i §8 — mekaniskt när 3–7 är på plats.
