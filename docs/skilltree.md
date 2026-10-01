# Trädet: läget, och förslaget

Alex: *"skill tree behöver vara permanent, men med så pass många noder att man måste spela spelet typ
20 ggr ... sista noderna skall göra så man mer eller mindre har god mode på ... Den skall vara på
gränsen till omöjlig utan att man fyllt hela skill tree't."* Och (M97): *"Ta bort bilden i
bakgrunden, vi gör ett vanligt nodträd enligt länken jag skickade innan, så får vi lösa grafiken
senare. Se till att verktygen faktiskt gör vad de är menade. Angående de 90 noderna - lägg till dem,
peka en direkt linje mellan föregående nod och den kommande noden."*

Alla siffror nedan är mätta ur spelets egna filer (`tools/gen_tree.py --check` räknar båda sidorna),
inte uppskattade.

## Läget, mätt

| | Mätt i dag |
|---|---|
| Noder | **93** — 3 grenar × (1 huvudnod + 30 undernoder) |
| Nivåer | 16 (nivå 1 = grenens huvudnod, nivå 16 = kronparet) |
| Inköp att fylla | 93 (en rang per nod; se förslaget om flera rang) |
| Kostnad att fylla allt | **3 468 CS** |
| En genomspelning ger | **2 722 CS** (90 banor × `5 + svårighetsgrad × 2`) |
| Alltså fullt träd efter | **1,27 genomspelningar** |

**Innan M97:** 63 noder, 1 098 CS — trädet var fullt efter 0,4 genomspelningar, alltså innan spelet var
halvkört. Att gå från 63 till 93 noder med stigande priser är vad som flyttar den siffran till 1,27.

Formen är 3 grenar med 2 parallella linjer var. En linje är "alltid mer av samma sak", så en spelare kan
gå djupt i en linje eller brett över båda.

## Ett vanligt nodträd (M97)

Plattan är borta. Ingen bakgrundsbild, inga uppmätta sockets — bilden kommer när formen sitter.

- **Gren → kolumn, nivå → rad.** Grenarna fördelas jämnt över bredden, nivåerna ligger 0,13 ifrån
  varandra nedåt (nivå 1 på 0,06). Syskonen i samma nivå ligger sida vid sida, 2,6 nodradier ifrån
  varandra, kring grenens kolumn.
- **Kopplingarna ritas ur `requires`** — en linje per kant, kortad till nodernas kanter. Varje nod pekar
  på sin föregångare i datat, så linjen från föregående nod till den kommande finns utan att någon
  ritar den för hand.
- **Nodens storlek är nivåns trappa:** nivå 1 stor (19 px i spelvyn), nivå 2–4 medelstor (12 px), 5–9
  liten (7 px), 10+ pytteliten (5 px). Ett eget val i trädeditorn (`L`) slår trappan.
- **Zoom och panorering:** hjul = zoom kring pekaren, höger (eller mitten) dragen = panorering, `F` =
  visa hela trädet. Allt bor i `_ur_bild`/`till_bild` i `game/ui/tree_view.gd`, så noder, ringar,
  kopplingar och editorns markör följer med automatiskt.
- **En nod läggs till utan att koden rörs.** Skriv den i `game/data/tree.json` (eller lägg den med `+`
  i trädeditorn); rutnätet ger den en plats. En nod som någon DRAGIT märks med `pin` och ligger kvar
  där den lades — `R` släpper den tillbaka till rutnätet.
- **En okänd gren blir en egen kolumn** i stället för att försvinna tyst.

Provet `game/tests/test_trad_oandlig.gd` mäter de egenskaperna, och `game/tests/test_trad_editor.gd`
mäter verktygen (se nedan).

## Vad Unity-tillägget har, och vad vi tar av det

Jämförelsen är gjord mot `Upgrade Tree - Skill, Tech & Perk Trees for Idle/Incremental/Roguelike`
(Unity Asset Store, 10 USD). Det är C# och DOTween och går inte att använda i Godot — men dess
funktionslista är en bra checklista, och M97 är svaret på den. *Godot-varianten är byggd, inte köpt.*

| Tillägget har | Hos oss i dag | Kvar att göra |
|---|---|---|
| Oändlig rityta som går att scrolla och zooma | Ja (`_pan` + `_zoom`, hjul/högerdrag/`F`) | — |
| Noder med **flera rang** (samma nod köps flera gånger, dyrare varje gång) | Dataformen finns (`max_rank`, `soul_cost` som lista per rang) men alla noder har rang 1 | **Förslaget:** kronorna och huvudnoderna får rang 2–3 (se nedan) |
| Upplåsningsträd (`requires`) | Ja, och editorn ritar om kedjan med ett drag | — |
| Valuta­medvetna tillstånd (har råd / låst / full) | Ja, fyra tillstånd: låst, köpt, maxad, krona | — |
| Steg-markeringar ("hur många gånger går den att uppgradera") | Ja: rang `x/y` i hovringstexten, steg `■□□` per kryss i trädeditorn | — |
| Fri placering och drag i en editor | Ja (`game/editor/trad_editor.gd`, via menyn) | — |
| Verktygslåda med hover-info (namn, effekt, pris) | Ja | — |
| Spara/ladda trädet | Ja (`tree.json` + `trad_sockets.json`) | — |
| Inkrementell/idle-inkomst (auto-guld per sekund) | **Nej, och ska inte ha:** vårt spel är körningsbaserat, själarna kommer från bossar | Medvetet valt bort |

## Förslaget: flera rang på de tunga noderna

Det som saknas är det tillägget är byggt kring: en nod som går att köpa mer än en gång. Det är också
vad den gamla planen kallade "~180 inköp ur ~90 noder", och det kräver **ingen kod** — `Meta` läser
redan `soul_cost[rang]` och vyn ritar redan rang `x/y`.

Förslag, i den ordning det ger mest:

1. **Kronorna (nivå 16) får rang 2.** Pris [118, 300]. Att "allt du slår på brinner" en gång till är inte
   meningslöst: andra rangen gör effekten starkare (samma fält, större tal), och det är den sista
   själ-sänkan i spelet. → 6 kronor × 1 extra rang = **+6 inköp, 1 800 CS**.
2. **Grenarnas huvudnoder (nivå 1) får rang 3.** Pris [40, 90, 180]. De öppnar grenen och är billiga att
   vilja ha mer av. → 3 huvudnoder × 2 extra rang = **+6 inköp, 810 CS**.
3. Nivå 15 (de yttersta vanliga noderna, två per gren) får rang 2. Pris [94, 200]. → 6 noder × 1 extra
   rang = **+6 inköp, 1 200 CS**.

Steg 1+2: **105 inköp, 6 078 CS = 2,2 genomspelningar.** Alla tre: **111 inköp, 7 278 CS = 2,7
genomspelningar.** Det är längre tid än 1,27, och det är hela poängen med förslaget — vill du ha mer
än 2,2 genomspelningar är kronorna + huvudnoderna den billigaste vägen dit. Säg till så lägger jag in
det i generatorn och mäter om (siffrorna ovan är räknade för hand ur `--check`s två tal, inte körda).

## Trädeditorn: verktygen

Öppnas via menyn (`tools/trad_editor.sh`). Panelens rader är formen — ett klick vet vad det träffade.

| Grepp | Gör |
|---|---|
| klick / drag | flytta noden (märker den `pin`; den ligger kvar) |
| piltangenter | nudge (1 steg, 5 med skift) |
| hjul | zoom kring pekaren |
| höger- eller mittendrag | panorera |
| `F` | visa hela trädet |
| `+` | lägg till en nod under den valda, i samma gren |
| `L` | nodens storlek genom de fyra klasserna |
| `G` | nästa ikon (alla PNG i `game/assets/tree/`, ingen lista i koden) |
| `1`–`9` / klick på raden | kryssa en uppgradering: av → x1 → x2 → x3 → av |
| `X` | ta bort / sätt tillbaka (gravsten i filen) |
| skift + drag | dra en koppling (`till` väntar på `från`; ett drag till tar bort den) |
| `C` | ta bort den valda nodens kopplingar |
| `T` | nästa nod |
| `R` | släpp noden tillbaka till rutnätet |
| `S` | spara till `game/data/trad_sockets.json` |
| `M` | tillbaka till menyn |

Två fel som är fixade och som provet nu mäter:

- **`C` gjorde ingenting.** Posten i filen tömdes, men metans definition behöll kravet — så låset och
  linjen stod kvar precis som förut. Nu går både ett drag och `C` genom samma skrivväg (`_skriv_krav`),
  som skriver posten OCH definitionen.
- **Panelen visade `branch: -` och en tom ikonrad** för varje genererad nod, eftersom den läste
  socketposten i stället för datat. Den läser nu `tree.json`s nod för namn, gren, nivå och ikon.
