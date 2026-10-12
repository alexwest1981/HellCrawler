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

- **Gren → kolumn, nivå → rad.** Grenarna fördelas över bredden, nivåerna ligger 0,13 ifrån varandra
  nedåt (nivå 1 på 0,06). Syskonen i samma nivå ligger sida vid sida kring grenens kolumn — formen är
  omgjord i M99 (gafflar, staggrad höjd, se "Formen" nedan); M97:s jämna fördelning och 2,6 nodradier
  mellan syskonen är borta.
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

## Verktygen Alex skickade (okt 2026): domen, och vad vi tar av dem

Fyra länkar: en webbeditor, en Godot-plugin, ett addon och en shader. Alla fyra är lästa i källan
(addonerna nedladdade och genomgångna, inte bara deras README), inte gissade.

| Verktyget | Vad det är | Domen |
|---|---|---|
| `skilltree.akcan.cloud` (forum-tråden, Muhi) | Webbeditor som exporterar JSON **eller GDScript** med enum som dict-nycklar | **Nej.** Den redigerar ett *datablad* (nod, namn, beskrivning, pris, koppling, position). Vår nod bär dessutom `branch`, `tier`, `effect{}`, `soul_cost[]`, `max_rank`, `crown` och sina rader i 13 språk — och `tools/gen_tree.py` skriver filen. Verktyget skulle bli ett andra hem för trädet och ett handjobb mellan dem. Enum-nycklarna är en GDScript-bekvämlighet som `Meta.def_for(id)` redan täcker. |
| `Michael-Jalloh/SkillEditor` (MIT, 3 commits, 267 rader) | Godot-plugin: `GraphEdit` + `GraphNode`, varje nod bär en **fri textblob** och sin position, exporterar `{träd: {nodes:[{name,data,offsetx,offsety}], connections}}` | **Nej.** Vår `game/editor/trad_editor.gd` (807 rader) gör samma sak och vet dessutom vad en nod ÄR: effekt, rang, gren, klass, ikon, krav — och skriver `requires` till samma fil spelet läser, med spelets egen vy som förhandsvisning. Pluginen har ingen effektmodell alls, så den måste byggas ut till vår form innan den ger något. Dess enda försprång är att `GraphEdit` bjuder zoom/panorering/drag/marquee gratis i editorn. |
| `don-tnowe/godot-worldmap-builder` (asset 2270) | Addon med **både** editor i vyn och en runtime-vy: `WorldmapView` med punkter/kopplingar, tillstånd, återbetalning med säkerhetskontroll, `dependency_min_state`, `hide_inactive`, stil per nod, `get_state`/`load_state` | **Nej, men det är den enda som hade kunnat ersätta vyn** — och priset är att trädet flyttar in i Godot-resurser och scen-noder (`WorldmapNodeData`, `WorldmapViewItem`) med sitt tillstånd i vyns dict, i stället för `tree.json` + `Meta` + generatorn + 13 språk + de mätta grindarna (`gen_tree.py --check`, `test_trad_oandlig`, `test_i18n`, `test_gui`). Två idéer är värda att låna: **`dependency_min_state`** (en nod kräver N poäng i sina föräldrar — samma sak som "flera rang"-förslaget nedan) och **`hide_inactive`** (dölj noder som inte gränsar till en tagen; billigt att lägga i vyn den dag trädet blir stort). Att addonet bygger en editor I vyn med ritade kopplingar är dessutom ett kvitto på att vårt val var rätt. |
| `godotshaders.com/shader/normal-map-only-shader` | `shader_type canvas_item; render_mode light_only, blend_mul;` — lägger `COLOR.rgb` i `NORMAL_MAP` och ritar bara ljuspasset | **Går inte att använda, och vore en nedgradering.** Shadern är till för **2D-ljus** (`CanvasItem`/`Light2D`): spelet har ingen `Light2D` alls. Våra golv är riktiga 3D-ytor (`MultiMeshInstance3D`) med `StandardMaterial3D`: albedo + normal + ORM, upplysta av en riktig `SpotLight3D`, och `test_normalprov` mäter att kartorna når shadern (normal_scale 1,0 mot 0,0 ger 5,26 i medel och 60 i p99 per pixel). Normalkartorna ligger alltså redan i ett eget lager i materialet, vilket är precis vad shadern försöker uppnå i 2D. |

**Inget av de fyra skall in.** Det som *är* värt att göra är saker ingen av dem äger: trädets innehåll
(se "Trädet vid naturlig storlek" nedan) och flera rang på de tunga noderna (förslaget ovan).

## Trädet vid naturlig storlek — nu standarden (M99)

Alex valde "Inzoomat": trädet **öppnas i zoom 1,0** på spelarens front (den djupaste köpta noden,
annars spiralens mitt). `F` visar hela trädet. Mätt ur `-- shot skarm=trad` (M101:s spiral):

| | Zoom 1,0 (öppnas så) | `F`: hela trädet (0,356) |
|---|---|---|
| Noder som syns | ~11 per skärm (4 av 16 nivåer ryms lodrätt, fler i hörnen) | 93 (alla) |
| Minsta nod | 19 px | 6 px |
| Största nod | 32 px | 11 px |
| Radie i vyn | 76–421 px (panoreras) | 27–150 px (hela ryms) |
| **Luft mellan noder** | 17 px | 6 px |
| **Luft nod–koppling** | 24 px | 8 px |

`-- tradzoom=<tal> skarm=trad shot` fotograferar trädet vid vilken zoom som helst, så jämförelsen går
att göra om (`main.gd` väntar in en bildruta först: utan det sparades samma bild två gånger, mätt som
samma md5). **Ett negativt tal är helhetsvyn (`F`) själv**, med den zoom `centrera()` räknar fram — utan
det fotograferades ett utsnitt med panoreringen nollad, alltså inte det spelaren ser när hon trycker `F`.

## Formen: en spiral ur mitten (M100/M101)

Alex skickade en bildserie med spiraler och skrev: *"Jag tänker mig mer som 3 st spiraler som utgår från
centrum, runt varandra så man konstant arbetar sig utåt i spiralen från de 3 olika armarna."* Grenarna
är spiralens **armar**, och **djupet är avståndet utåt** — inte en rad nedåt. Det gamla rutnätet (M97:
kolumner och rader, M99: en gaffel som öppnade sig nedåt) är borta.

Sedan: *"De behöver ligga mer separerade, det måste vara luft mellan noderna och linjerna som ansluter
till dem. Det gör inget alls om man får pan'a över hela kartan med musen. Huvudnoderna kan ligga tätare
mot varandra, sen sprid ut dem mer."* Tre ändringar, alla mätta:

- **Bågen är konstant, vinkeln är inte.** Vinkeln per nivå är `SPIRAL_BUE` (0,22) delat med radien, så
  två nivåer ligger **lika långt ifrån varandra hela vägen ut** — mätt 56–62 px, mot 48–152 px när
  vinkeln var fast och radien växte. Spiralen varvar alltså tätt i mitten och långsammare utåt.
- **Spåren ligger på ömse sidor** om armens mittlinje (`SPIRAL_LED` 0,16 = 43 px), så huvudnoden — som
  är ensam på sin nivå — hamnar PÅ linjen och de två syskonen gafflar ut på var sin sida. Mätt: 17 px
  luft mellan syskonen (26 px noder). Låg båda spåren utanför linjen klev det inre spåret in i nivån
  innanför.
- **Kopplingarna ritas som bågar** genom trädrymden (`_båge`), inte som raka linjer. En rak linje mellan
  två nivåer skar genom nästa arms noder — mätt: 13 px IN i en nod — för bågen mellan två nivåer är
  ~59 px medan noderna är 26 px. Bågen följer spåret och håller sig i sin egen arm: **mätt 24 px luft**
  till varje annan nod.

Mätta tal (ur `test_trad_oandlig`, som mäter i radie ur mitten): minsta luften mellan två noder **17 px**,
minsta luften mellan en koppling och en annan nod **24 px**, nivåstegen 56–62 px, trädets radie 421 px i
zoom 1 och 150 px i helhetsvyn. Radietillväxten är `SPIRAL_DRAD` 0,08 per nivå ur `SPIRAL_R0` 0,28, och
15 nivåer blir 0,8 varv — spiralen är en *båge av ett varv*, inte flera varv.

Provet `game/tests/test_trad_oandlig.gd` mäter formen i **radie ur mitten** i stället för i rader:
nivåerna är ringar som går utåt, syskonen ligger på samma vinkel i två spår, **ingen nod ligger på en
annan**, och **ingen koppling går in i en annan nod** (den mätningen fångade den raka linjen: 13 px in i
en nod, 17 kolliderande par innan konstanterna var rätt). `test_gui` mäter att grenens huvudnod ligger
närmast mitten — "ovanför" fanns inte längre att mäta.

**Vad formen kostar.** Trädet är nu ~1,5 skärmar i radie, så spelaren **panorerar** (höger musknapp eller
mitten, som förut) i stället för att se allt på en gång; `F` visar helheten vid zoom 0,356, där noderna
ritas 6–11 px och formen syns men texten inte. Det är priset för luften, och Alex tog det uttryckligen:
*"Det gör inget alls om man får pan'a över hela kartan med musen."*

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
