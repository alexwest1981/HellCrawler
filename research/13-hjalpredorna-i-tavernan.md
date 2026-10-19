# Hjälpredorna i tavernan (Crawlers) — hur referensen gör, och vad vi gör

Källor: `vampire.survivors.wiki/w/Crawlers:Characters`, `Crawlers:Inn`, `Crawlers:Power_Ups`,
`01-spelmekanik.md` §4.

## 1. Flödet in i tavernan

* **Inn låses upp** av att klara **våning 1 i Mad Forest**. Samma händelse låser upp köpet av Imelda —
  alltså: första gången man kommer tillbaka till byn efter en halv dungeon står det en ny post i menyn
  *och* en ny figur i tavernan.
* Byns post heter **Crawlers**, byggnaden heter **Gorton Bell Inn**, och knappen inuti heter **Add**
  (hette "Equip" före juni-uppdateringen — ordet byttes för att köpet är permanent).
* Köpet är **engångsköp**: man köper en Crawler, den är i partyt, och det finns ingen "sälj" eller
  "ta bort". Det som styr hur många man får ha är en **PowerUp (Crawler Slot)**, inte en meny.

## 2. Priset är upplåsningen, inte bara guldet

Varje Crawler har **två** trösklar i tabellen: ett guldpris och en upplåsning.

| Crawler | Pris (guld) | Låses upp av |
|---|---|---|
| Antonio, Ambrojoe | 0 | start |
| Imelda | 0 | klara våning 1 (samma som Inn) |
| Arca | 300 | — |
| Cavallo, Gennaro | 500 | — |
| Clerici, Concetta, Dommario, Giovanna | 800 | — |
| Gallo | 2 000 | — |
| Christine | 1 000 | — |

Mönstret: **billig först, dyr sist**, och de dyra är också de som ändrar spelet mest (Gallo = Greed,
Christine = mana-kostnad). Ingen Crawler är dyr *och* svag.

## 3. Den viktigaste regeln: bara den FÖRSTA ger stats

* **Main** (den först valda) bidrar med **sina egna parametrar/stats/power-ups** till partyt, och med
  **fyra kort** till startleken.
* **Varje följande** Crawler bidrar med **noll stats** och **ett enda kort**.
* Varje Crawler har dessutom en **egen passiv trigger** som utlöses av att man spelar ett kort i en
  viss färg, och varar ett antal triggers = **Duration**-statten.

Exempel ur tabellen: Antonio ger +3 Armor (main) och "deal 10 % more damage when a red card is played"
(trigger, 5 gånger). Arca ger +3 Mana och +1 Mana när ett lila kort spelas (5 gånger).

Det är därför valet av första Crawler är ett **byggval** och de följande är **kortval**: main är din
stat-profil, resten är extra kort i leken med en liten motor på.

## 4. Taket och rabatten

* **Crawler Slot** (PowerUp): +1 plats, max 2 köp → **1 plats från start, högst 3**.
* **Disco mode**: när **fem** Crawlers är köpta finns **10 % chans** vid ett besök i tavernan. I disco
  läget är alla köp **5 % billigare**, discot tar slut när man lämnar tavernan, och chansen tänds igen
  först efter en ny dungeon-körning. Egen musik (disco-versionen av tavernans spår).
* Det finns ingen "respec" för Crawlers — bara för Power-Ups.

## 5. Vad det gör för spelaren

1. **Första köpet är alltid värt mest** (stats + fyra kort), så tavernan ger en tydlig första belöning
   efter våning 1.
2. **Taket på tre** gör att man väljer, inte samlar: 22 Crawlers och tre platser är ett valsystem.
3. **Duration** gör att triggern har en klocka: en Crawler är inte permanent, den räcker ett antal kort.
4. **Upplåsningen via guld** ligger i dungeonloopen: guldet man fick i våning 1 räcker till Imelda.

## 6. Vad vi har, och vad som ändrades

| Referensen | Vi | Status |
|---|---|---|
| Inn låses upp av våning 1 | tavernan finns från start | 🟡 |
| Engångsköp, ingen sälj | `hired`-lista, ingen sälj | ✅ |
| **Bara main ger stats** | **alla hyrda summerades** | ❌ → **fixat** |
| Main ger 4 kort, följande 1 | kort per kamrat | 🟡 |
| Tak 1 → 3 via PowerUp | inget tak (man kunde hyra alla tio) | ❌ → **fixat** |
| Disco (10 % efter fem köp, 5 % rabatt) | saknas | ❌ |
| Duration-styrd trigger | kamraten är en passiv stat-bonus | 🟡 |
| Knappen heter "Add" | "HYR" | ✅ → **"LÄGG TILL"** |

### Ändrat i kod (M176)

* `Meta.stat()` räknar **bara `hired[0]`**. Att summera alla gjorde att tio kamrater gav tio gånger
  passiven, och då spelade det ingen roll vilken man valde först.
* `Meta.party_tak()` = 1 + `crawler_slot` (högst 3). `can_hire` svarar `partyt_fullt` över taket.
* Tavernans detaljrad skriver **"partyt är fullt (3/3)"** och stänger köpknappen, i stället för att
  tyst dra guldet.
* Knappen heter **LÄGG TILL** / **ADD**, som referensen.

## 7. Kvar att göra, i ordning

1. **Disco-läget** — 10 % efter fem köp, 5 % rabatt, eget ljud. Ren slump + en flagga i tavernaskärmen.
2. **Duration-triggers** — kamraten ska vara en motor som räknar ned, inte en statisk bonus. Kräver att
   `Run` räknar "spelat kort i färg X" per strid.
3. **Fyra kort från main, ett från övriga** — `startleken` byggs nu ur kamratens kort; regeln ska vara
   fyra respektive ett.
4. **Upplåsning av tavernan** efter våning 1, i stället för från start.
