# Byns flöde i Vampire Crawlers — isärplockat och rangordnat

Källor: `vampire.survivors.wiki` (`Crawlers:Village`, `Crawlers:World Map`, `Crawlers:Shop`, `Crawlers:Inn`,
`Crawlers:Blacksmith`, `Crawlers:Buildings`) samt `01-spelmekanik.md` i den här mappen. Sifferfakta om
priser/effekter står i `01`; det här dokumentet handlar bara om **flödet**.

Rangordningen är efter hur mycket varje del påverkar hur spelet känns att spela. Punkt 1–4 är
strukturen; punkt 5–7 är det som gör att strukturen inte skaver; punkt 8–10 är yta.

---

## 1. Det finns EN axel, och allt annat hänger på den

```
byn  →  World Map  →  dungeon (våning 1..n, shoveln nedåt)  →  tillbaka till byn
```

* Byn är **start och slut** för varje körning. Ingen annan skärm leder någon annanstans än tillbaka
  till byn.
* **World Map är den enda "framåt"-posten** i hela byn. Alla andra byggnader är avstickare som tar
  slut och lämnar tillbaka.
* Dungeon är en **kedja av våningar** där shoveln är övergången nedåt; sista våningen avslutas av
  Red Death, och det räknas som "klarat" även när man dör.

**Konsekvens:** det finns inget behov av att navigera ett rum. Spelaren behöver aldrig veta var i byn
hen är — bara vilken post som är "ut".

## 2. Byn är en meny, inte en plats man går omkring i

Åtta poster, alla nåbara från samma lista:

| Post | Byggnad | Jobb |
|---|---|---|
| Unlocks | Town Hall | spåra upplåsningar |
| Settings | Settings (kyrkogården) | inställningar |
| Crawlers | Inn (Gorton Bell) | köpa och utrusta Crawlers |
| Arcana | Fortune Teller | arcanas |
| World Map | World Map | välja dungeon — **den enda vägen ut** |
| Blacksmith | Blacksmith | gem-slots (Blacksmith) + raritet (Jeweller) |
| Relics | Museum | bläddra bland relics |
| Power Ups | Shop | köpa power-ups |

Ingen gångyta, ingen kollision, ingen kamera. Bakgrunden är målad och posterna ligger ovanpå.
Vinsten är tempo: by → byggnad → by tar under en sekund, och kostnaden för en ny byggnad är en
**rad i listan**, inte en ny yta att bygga och kollisionstesta.

## 3. Upplåsningskedjan ÄR innehållet

Varje byggnad dyker upp när spelaren har en anledning att gå in i den:

| Byggnad | Låses upp av |
|---|---|
| Town Hall, Settings, World Map | klara tutorialen |
| Inn (Crawlers) | klara våning 1 i Mad Forest |
| Shop (Power Ups) | samla 250 mynt |
| Museum (Relics) | spela två dungeons |
| Fortune Teller (Arcana) | hitta relicen Polentír |
| Blacksmith | hitta relicen Stardust Anvil |
| Jeweller (i Blacksmith) | hitta relicen Lapidary Loupe |

Det är därför byn känns levande trots att den bara är en meny: **listan växer**. Första gången man
kommer tillbaka efter våning 1 står det en post där som inte fanns.

## 4. En byggnad = ett jobb, och jobbet är färdigt när man lämnar den

Ingen byggnad gör två saker (undantaget Blacksmith, som rymmer två butiker: slots och raritet).
Ingen byggnad leder vidare till en annan byggnad. Ingen byggnad har en egen "tillbaka till X" —
man lämnar den och är i byn.

## 5. Samma tangent ut ur allt

* **Backspace** = tillbaka. I en butik → byn. I byn → World Map-posten. I World Map → byn.
* **Esc** = inställningarna, från byn och från World Map (sedan 1.5; före dess gick Esc till World Map).
* World Map har en **egen post "Village"** för att gå tillbaka med markören, för den som inte vill
  använda tangenten.

Poängen: en återvändsgränd är ett designfel, inte ett tillstånd. Varje skärm har en väg ut som inte
kräver att man läser en rad.

## 6. Guld är enda valutan mellan körningar

Allt som köps i byn betalas med guld som dungeonen gav: power-ups, Crawlers, gem-slots, gem-raritet.
Priser stiger per köp (raritet har tak 50 000). Inget annat resurslager finns mellan körningarna —
det är därför byn aldrig behöver en "växla"-skärm.

## 7. Tempot: inga laddningstider, inga kvitton

Köp sker direkt, med ljud (Buy/Fail), utan bekräftelsedialog. Musik per byggnad. Ingen animation som
måste spelas klart innan man får klicka igen — samma princip som TurboTurn i striden.

## 8. Statusraden syns alltid

Guld, upplåsningar, shards står i byns nederkant, utan att man öppnar något. Spelaren behöver aldrig
fråga "har jag råd?" — svaret står på skärmen medan hen tittar på priset.

## 9. Dagens körning finns inte i VC

VC har ingen daglig körning; där är retry-loopen allt. (Vi har `T` = dagens körning med dagens frö —
behåll den, men den ska inte ta plats i byns huvudlista.)

## 10. Ytan: målad bakgrund + egen musik per byggnad

Byn har en bakgrundsbild med byggnaderna utritade; varje byggnad har en egen målning och ett eget
spår. Ingen av dem är interaktiv utöver posten som leder dit. Det är dekor, och det är billigt.

---

## Vad vi har, mätt mot listan

| VC | Vi | Status |
|---|---|---|
| En axel by → karta → dungeon → by | samma | ✅ |
| Byn är en meny | menyrad längst ned + klickbara hus i bilden | ✅ (två vägar in — se risken nedan) |
| Upplåsningskedja | byggnader syns men är grå med orsak ("no workshop yet") | 🟠 **avvikelse**: vi visar allt från start |
| En byggnad = ett jobb | shop, inn, jeweller, smith (slots), karta | ✅ |
| Samma tangent ut | Esc → byn från alla skärmar | ✅ (Backspace tillagd nu) |
| Backspace: by → World Map | tillagd nu | ✅ |
| Esc = inställningar | Esc = tillbaka i stället | 🟠 **avvikelse**: Esc gör två saker beroende på skärm |
| Guld som enda valuta | guld | ✅ |
| Statusrad alltid synlig | statusrad i nederkant | ✅ |
| Town Hall (upplåsningar) | saknas (album finns för kort) | ❌ |
| Museum (relics) | relics finns i `core/relics.gd`, ingen skärm | ❌ |
| Fortune Teller (arcana) | saknas | ❌ |

### Två risker i vårt flöde

1. **Två vägar in i varje byggnad** — markören i menyraden *och* klick på huset i bilden. VC har
   bara en. Två vägar betyder två ställen att hålla i synk (vilket vi redan har haft fel på: klickytorna
   pekade på den gamla konstens hus). Antingen låser vi husen till markören, eller så är husen den enda
   vägen och menyraden bara en etikett.
2. **Esc gör två saker.** VC: Esc = inställningar, alltid. Vi: Esc = tillbaka. Det är bekvämare för
   oss, men det betyder att inställningarna måste ha en egen tangent som syns i ledtexten.

## Nästa snitt, i ordning

1. **Backspace hela vägen** (klart i M175).
2. **Town Hall / upplåsningar** — en lista över vad som är upplåst och vad som låser upp resten. Det är
   byns billigaste nya post och den som gör kedjan synlig.
3. **Museum / relics** — relics finns redan som data; en bläddringsskärm är en panel, inte ett system.
4. **Arcana** — kräver att arcanas finns som mekanik först; väntar.
5. **Upplåsningskedja i menyn** — posterna ska dyka upp när de får ett jobb, inte gråas ut.
