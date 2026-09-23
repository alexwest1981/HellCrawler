# Önskemål från Alex (2026-09-21)

Skrivet ned direkt ur hans meddelande, så inget tappas vid en omstart. Teknisk tolkning står under varje punkt; status uppdateras när punkten är mätt och committad.

## 1. Teckenförklaringsrutan ska bort från spelytan
> "Rutan med döskalle, strid, kista osv, den ligger nu i spelytan, den skall helst vara ren"

Mätt på skärmbild: legenden (`MapView._legend`, `MAP_SIZE = 76 × (KARTA_HÖJD + LEGEND_HÖJD)`) ritas inne i vyn, tvärs över övre halvan från mitten till högerkanten. Spelytan ska vara ren; orden hör hemma i den svarta marginalen (eller inte alls — märkena ritas redan på kartan).
**Status:** klar (M32). Kartan och de sex orden ligger i marginalen; mätt i skärmbild på 1280x720: orden på x 1149..1218, y 130..257, spelvyn ren. Prov: `tests/test_minikarta.gd`.

## 2. Minikartan till övre högra hörnet
> "skulle vilja flytta även minimap upp till högra hörnet"

`map_view.position = Vector2(VY.x - MAP_SIZE.x - MARGINAL, MARGINAL)` sätter den innanför vyns kant. Den ska till skärmens/hörnlinjens övre högra hörn. Obs: nyckelhintsen ligger redan där (`WASD gå · 1-9 kort · …`) — mät kollisionen och flytta hintsen om de krockar.
**Status:** klar (M32). Kartan står i fönstrets övre högra hörn (@ 1122,6 vid 1280x720), skalad med fönstrets heltal; tangenttipsen flyttade en rad ned och ställs mot kartans vänsterkant (de krockade, mätt).

## 3. Högre pixeltäthet — rutor och fiender
> "Normalmappingen ser MYCKET bättre ut, men skulle vilja öka pixeltätheten/upplösningen mer, då det är väldigt katigt. Gör även detta för alla fiender. De behöver få nästan dubbel upplösning."

Rutorna står på `SIZE = 64` px per 0,5 m = **128 px/m**; nästa steg är 256 px/m. Fienderna är 40×40 per ruta och ska till nästan det dubbla (~76–80 px), alla 17 och alla sex rutor var. Vyn ska inte ändras — bara detaljrikedomen, så `pixel_size` kalibreras om så att figuren har samma storlek i världen.
**Status:** klar (M33). Rutorna: SIZE 64 → 128 (256 px/m), 320 rutor omskrivna, reliefen mätt oförändrad (6,09/73 mot 5,26/60). Fienderna: duken 40x40 → **80x80** för alla 17 (alltså 480x80 per ark med sex rutor), `pixel_size` halverad (0,036 → 0,018 / 0,052 → 0,026) så figuren har **exakt samma storlek i världen** — 80 x 0,018 = 40 x 0,036 = 1,44 m, och fötterna 27 x 0,018 = 13,5 x 0,036 = 0,486 m över golvet. Nytt i generatorn: `S = 2` (formerna ritar kvar i sina 32 logiska pixlar, `put()` lägger S x S i duken) och `kanter()`, som ger silhuettens trappsteg dubbelt så många steg i stället för att varje steg blir dubbelt så stort.

## 4. Kistor får inte försvinna när man kommer nära
> "Kistor försvinner när man kommer nära, det får de inte göra."

Trolig orsak (att mäta, inte gissa): att stå på rutan sätter spriten innanför kamerans närplan, och då klipps den bort.
**Status:** klar (M32). Mätt med `-- kistnara`: 0 av 1 px kvar på spelarens egen ruta (kistan försvann) → 44 640 av 44 640 px, och bredden från fyra håll 66-66 px (1,00) → 60-79 px (1,33).

## 5. Kistan ska kännas som ett 3D-föremål
> "Det hade varit trevligt om de kunde upplevas som ett 3d-föremål och inte snurra när man själv snurrar."

En billboard som yaw:ar med kameran snurrar när spelaren snurrar. Kistan ska ha fast orientering (eller vara byggd geometri, som facklan).
**Status:** klar (M32). Kistan är byggd geometri i gruppen "kista": kropp, lock på gångjärn, två järnband, lås och fyra fötter, med framsidan mot rutan spelaren kommer ifrån. En plundrad kista STÅR KVAR med locket öppet (12 noder kvar i världen mot 0 förut).

## 6. Attackeffekt för de fiender som saknar
> "Det behöver ännu vara någon form av effekt under attacker för vissa, verkar det som."

Det finns redan en förvarning/hugg-effekt, men den är svagast i båda granskningarna och flera fiendegrupper (blob/wisp/swarm) saknar egen accent. Referensen är en håll-beat i vyn, inte fler pixlar.
**Status:** öppen (M35).

## 7. Visuell bekräftelse när man tar en dryck
> "någon form av visuell bekräftelse när man tar en manapotion eller något annat, för nu ser det bara ut som kortet försvinner."

Effekten `game/ui/reward_fx.gd` finns för belöningar; kort som spelas upp och försvinner behöver samma slags kvittering (mana, hp, guld).
**Status:** öppen (M35).

## 8. Kortborden: hög → solfjäder → använda → tillbaka
> "en animation som flyttar korten man har tillgängliga från en korthög i höger hörn, till handen man håller i (som förövrigt nu ser ut som man radat upp längst kanten och behöver vara mer som att man håller korten i en solfjäderform som i Referensspelet), och sedan till vänster sida i en hög av 'Använda kort'. Korten skall sedan samlas ihop och läggas i högen prydligt igen på höger sida."

Alltså fyra stationer: draghög uppe till höger → handen i solfjäder (inte en rad längs kanten) → använda kort i en hög till vänster → insamlade och prydligt tillbaka i högen till höger. Referensspelet solfjäder är referensen.
**Status:** klar (M34). **Kortborden är klara:** korten i högarna är i KORTETS egen storlek (93×128 px vid 1280×720, exakt som korten i handen), ETT kort ritas per kort i högen — 18 kort i leken ger 18 kanter man kan räkna — och raden under visar antalet. Varje kort bär samma genererade baksida (`tools/gen_card_back.py` → `assets/cards/_back.png`), så ingen kan se vad som ligger på tur. Ett kort som dras kommer från högen med BAKSIDAN UPP, glider in på sin plats och VÄNDER sig (skalan i x går mot noll och tillbaka, baksidan byts mot framsidan mitt i) — mätt med `-- handprov`: 5 av 9 kort låg med baksidan upp 0,6 s in i turbytet och 0 av 9 efter 1,1 s, och en svit på 11 bildrutor visar hela förloppet. **Det gamla:** draghögen står i höger marginal (blå, leken) och de använda i vänster (röda). Det spelade kortet flyger till den vänstra högen (och krymper in i den), nya kort kommer FRÅN högen till höger och glider in i solfjädern, och när leken tar slut flyttar den vänstra högen över till den högra — "samlas ihop och läggs i högen prydligt igen". `test_kortbord.gd` mäter allt fyra (14 kontroller, 0 fel). **Solfjädern är klar** (M34 första halva): korten ligger på en båge med omlott och vridning utåt — mätt `-- handprov`: 5 kort, 93×128 px, 57 px steg i sidled (omlott 35 px av 93), mittkortet högst och rakt (0,000 rad), ytterkorten 18 px lägre och vridna ±0,110 rad (±6,3°), alltså 12,6° mellan ytterkortens vinklar. Mittkortets underkant ligger kvar 6 px in i fönstrets nederkant precis där raden låg; ytterkorten hänger 12 px nedanför kanten, som en hand man håller lågt. Under: draghögen uppe till höger, högen av använda kort till vänster och insamlingen tillbaka byggdes i M34:s tredje halva och mäts av `tests/test_kortbord.gd` (14 kontroller, 0 fel) — raden "Kvar" som stod här var gammal.

## 9. Album/index över alla kort man äger
> "Man måste kunna öppna som en index över alla kort man äger och se vad de gör om man klickar/trycker på ett kort, och allt detta som om man öppnar ett album."

Ett uppslagsverk: bläddra bland ägda kort, tryck på ett och se vad det gör. Presenterat som att öppna ett album.
**Status:** klar (M34). Skärmen `album` i skalet, öppnas med **I** i byn (A/D tar platsvalet). Panelen visar det valda kortet STORT — namn, kostnad och effekten, alltså svaret på "vad det gör" — och under det en rad med sju tumnaglar, med det valda kortet lyft och centrerat; klick på en tumnagel väljer den, ←/→ bläddrar, I/Esc går tillbaka. Listan är **samlingen**, inte katalogen: rang > 0 (köpta) eller hyrda kamrater; sorterad på kostnad och sedan namn. `test_album.gd` mäter att ett kort med rang 0 inte kommer med, att den stora visningen är det valda kortet, att bläddringen går runt i båda ändar och att albumet är gömt under en körning (13 kontroller, 0 fel). Granskningsflaggan `-- skarm=album shot kortprov=8` fyller samlingen med åtta kort ur datat (fotoläget, skriver aldrig i sparfilen) och gav bilden som dömdes: "ALBUMET — kort 1 av 8", sju tumnaglar, det valda lyft, inget klippt.

## 10. Spara allt detta
> "Spara all denna info någonstans, då jag behöver starta om datorn efter uppdateringar."

Den här filen, plus en rad i minnet. Inget av detta får bara ligga i en chatt.
**Status:** klar (den här filen).

## 11. Grafisk HUD i svarta ytan — Diablo 1/2, men korten nedtill i mitten
> "Lägg även till att svarta ytan behöver få en grafisk HUD, lite som diablo 1/2, men korten har central plats nedtill. dock någon form av visuell hanterare för hälsa, mana och rustning."

Den svarta marginalen ska inte vara svart: den ska bli en ridad HUD-ram i Diablo 1/2:s anda — sten/metall-chrome, inte platta textrader. Korten har den centrala platsen nedtill, och hälsa, mana och rustning behöver var sin visuella hanterare: en orb, en mätare eller ett kärl som man ser nivån i, inte bara en siffra. Referenserna är Diablo 1:s och 2:s ram med orben till vänster och höger och bältet nedtill; skillnaden är att korten här tar mitten nedtill.

Ytorna i marginalen i dag: statusraden uppe till vänster, tangenthintsen uppe till höger, minikartan i övre högra hörnet (önskemål 2), korthanden nedtill i mitten och teckenförklaringen (önskemål 1). HUD-ramen ska rymma dem alla utan att någon hamnar över spelytan eller över varandra.

Alex om första versionen (2026-09-21): *"Gillade dock inte bakgrunden för HUD, det hade varit bättre med mörkare bakgrund, smuts, gotiskt, metall... inte platt å grått som det är nu"*. Ramens yta är därför mörk, smutsig metall: plåten ligger på c(2) med c(3) som ljus överkant, och smutsen är FORMAD — sot längs kanter och hörn, rinningar som börjar i översta sömmen och rinner ned, fläckar i klumpar (en stor med två små) och en sliten ljus fläck mitt på plåten — allt ur ett deterministiskt brus så fläckarna inte vandrar mellan ritningar. Fönstrets fyra hörn har en 45-gradig skärning i stället för räta vinklar. Mätt: marginalens medel gick 47,1 → **36,2** och spelvyn är fortfarande orörd (0 px över tröskeln).

**Status:** påbörjad (M36). Ramen är byggd: `game/ui/hud_ram.gd` ritar den svarta marginalen som nitade metallplåtar (plåt 48 px, fasade kanter, sömmar, nitar i plåthörnen) med en indragen metallist runt spelvyn, i fönstrets upplösning och ur `palette.json`. Mätt: skillnaden innanför spelvyn med ramen på är **0,00 i medel och 0 px över tröskeln** (ramen ritar ingenting i vyn), marginalen går från svart (medel 6,3) till plåtyta (47,1), och `tests/test_hud.gd` mäter att de fyra banden är exakt fönstret minus vyn utan överlapp. KVAR: kortens centrala plats nedtill och omplaceringen av de befintliga ytorna (statusraden, tipsen, minikartan, teckenförklaringen) så att ingen hamnar över spelytan eller över varandra. KLART: kärlen — `game/ui/hud_orb.gd` ritar tre skålar i marginalen (hälsa till vänster, mana till höger, rustning i vänsterkolumnen ovanför hälsan) med vätskenivå, ytlinje och glans; hälsan syns alltid, mana och rustning bara i strid (utanför en strid finns de inte). Mätt: kärlen ligger i sidokolumnerna (x 4..156 och 1124..1276 vid 1280x720), spelvyn är oförändrad (0 px över tröskeln), och `test_hud.gd` mäter mittpunkten och att nivån klipps till 0-1. Manans tak är en kalibrering (grundmanan + en hands manakort) eftersom manan inte har något tak i motorn; rustningens tak är stridens startvärde, alltså hur mycket som är kvar.

## 12b. Bildrutan: spelet gick i 4 fps
> (min egen mätning, inte ett önskemål: `-- fpsprov` gav 4 fps och sämsta bildruta 148 ms)

Orsaken var att byn och världskartan, som bara är GÖMDA under en körning, byggde om sina texter i varje bildruta (fontmätningarna i `UiText.storlek_som_ryms`), plus minikartans ordkolumn. Nu gör en gömd vy ingenting, och läget jämförs som ett tal i stället för en sträng av 400 tecken.
**Status:** klar (M37b). **4 fps → 55 fps**, sämsta bildruta 148 ms → 29 ms, skripttid 241 ms → 24,7 ms per bildruta. Det här är också förklaringen till att rörelsen kändes statisk: ett steg på 0,16 s är 9 bildrutor i 55 fps och 0,6 bildrutor i 4 fps.

## 12. Rörelsen: zoom när man går framåt, mjuk sväng
> "rörelsen är alldeles för statisk. Det behöver nästan bli en zoom-effekt när man går framåt, och någon form av mjuk rörelse när man svänger."

Kameran gled 0,10 s rakt igenom, utan skillnad mellan att gå och att svänga — och vinkeln räknades på tre ställen i `main.gd`. Steget ska få en vidvinkel-puff (zoom), svängen ska gå mjukare och kränga till, och vinkeln ska alltid tas åt närmaste håll.
**Status:** klar (M37). `Explore.yaw_for()` är nu den enda platsen där riktningen blir en vinkel, och `Explore.närmaste_vinkel()` ser till att svängen går kortaste vägen — utan den snurrade kameran 270 grader fel håll när svängen gick över 180-gradersgränsen (mätt: från väster till norr tog den +4,71 rad i stället för -1,57). Steget tar 0,16 s och vidvinkeln öppnar sig 8 grader mitt i steget; svängen tar 0,20 s och kränger 1,3 grader i sidled. Mätt med `-- stegprov` (samplar var 40:e ms): fov 70,00 → **78,00** → 70,00 över steget, rot.z 0 → 0,0220 → 0 över svängen, och svängens vinkel 0 → -1,571 rad = kortaste vägen. `test_run.gd` mäter att ingen sväng mellan två håll någonsin tar mer än ett halvt varv.

## 14. Intro, splashscreen och startmeny — och känslan från referensbilderna
> "Här har du en intro och en splashscreen. Lägg in startmenyn för 'Nytt spel' osv enligt sista bilden."
> (i samma meddelande en ljudfil, `Dungeon Arpeggios.mp3`, och två referensbilder)
> "Där har du även lite känslan jag är ute efter med vårt spel."

Spelet startade förr rakt in i byn: ingen titel, ingen musik, inget att välja. Nu finns en startmeny
över splashbilden — NYTT SPEL, LADDA SPEL, ALTERNATIV och AVSLUTA — med det valda valet markerat av en
brinnande dödskalle (som i referensen, i stället för en ram eller en pil), version och copyright i
botten. Musiken spelar på menyn och tystnar när körningen börjar. Känslan från referensbilderna sitter i
ett CRT-lager överst: skanlinjer, vinjett, välvd kant och en svag färgförskjutning — bilden ligger i en
gammal tjock-TV. CRT-läget och musiken går att stänga av i ALTERNATIV, och språkvalet ligger där.

**Status:** klar (M39). Splashbilden är Alex' egen referensbild (nedskalad till 1280x720 och med
referensens egen copyright-rad bortklippt — menyn skriver version och copyright själv, och två rader på
samma plats blev oläsligt). Märket ritas i kod ur spelets palett av `tools/gen_meny.py` (kontroll:
genomskinlig ram, skalle och låga finns, exakt symmetri) sedan första försöket föll i granskningen
("ser snarare ut som en döskalle i en lykta/arkadmaskin på en piedestal"). Musiken är
`assets/music/dungeon_arpeggios.mp3`, 3:02, med slinga på. LADDA SPEL återupptar den sparade körningen
(våning, HP, xp och hela leken i sparfilen; en avslutad körning tar bort läget). Mätt i
`tests/test_meny.gd` (36 kontroller, 0 fel) och `-- menyprov` (skärmbilder + mätning: radernas läge,
märkets läge, klicket, CRT-raden, musiken). CRT-lagret kostar **51 fps mot 55** i `-- fpsprov` (sämsta
bildruta 25 ms) — dyrare än det ser ut, men långt över de 30.

## 13. Fienderna får egna shaders — rökiga, glansiga, genomskinliga
> "Skulle även vilja att vi lägger till i min önskelista, att ge monstren egna shaders, så de kan vara rökiga, glansiga, genomskinliga osv."

I dag är varje fiende samma Sprite3D med samma material: bara en texturbild som byts. En rökig varelse
kan därför bara bli rökig med fler pixlar, och en genomskinlig bara genom att rita den halv. Önskemålet
är att varje fiende (eller varje fiendeTYP) kan få ett eget material med en shader ovanpå sin bild:
rök (mjuk rörelse och kant), glans (en ljusstrimma som vandrar), genomskinlighet (såll eller
alfa-tröskel), glöd och vågor. Pixelkonsten ska vara kvar — shadern lägger till, den ritar inte om —
och en fiende utan egen shader ska se ut precis som i dag.

**Status:** ej påbörjad (önskemål, inte mätt). Riktning att börja i: en `ShaderMaterial` per fiende i
fiendedatat (`game/data/enemies.json` eller motsvarande), med en standard-shader som gör ingenting, så
att inget ändras förrän en fiende faktiskt får en. Mätbart: en fiende med shader skiljer sig från sin
egen textur (pixlar utanför bildens kontur eller ändrad alfa) medan en utan är bit-identisk med i dag.

## 14. GUI:t enligt referensbilden — men korten i handen, inte en action bar

Alex' referensbild har en HUD där allt ligger i marginalerna: porträtt och staplar (HP, mana, rustning)
uppe till vänster, en loggruta nere till vänster och en fienderuta nere till höger, med spelvyn helt
fri. Hans invändning mot referensen: *"Kom dock ihåg att istället för Action Bar så skall vi ha
korten"* — solfjädern i mitten nedtill är kvar, och referensens action bar byggs inte.

**Status:** klar (M40). Statusblocket har Alex' hjälmporträtt och tre staplar som följer VÄRDET (halvt
liv = halv stapel, mätt i provet). Loggen håller fyra rader i en ring — skada i blodets färg, erfarenhet
och byte i guld, händelser i benets — och den nyaste raden står sist. Fienderutan visar målet med bild
och liv. Alla tre ligger i marginalen: **0 px innanför spelvyn**, mätt i `-- guiprov` med ett riktigt
1280x720-fönster och i `tests/test_gui.gd` (36 kontroller). Statusraden och sifferpanelen som stod där
förut ritas inte längre (samma siffror står i staplarna) och stridspanelen flyttade ur vyns mitt till
vyns övre vänstra hörn, så spelvyn är fri.

## 15. Material och rekvisita per ruta — i spelet, inte bara i editorn
> "editorn behöver ha så man kan välja texturer för väggar, tak, golv osv, även om man vill klistra in rekvisita"
> "man skall kunna gå in i banan, så som det blir när man spelar, och klistra in sånt man vill ha på plats, om något behöver ändras kan man göra det on the fly"

Byggläget (F1) finns: man står i våningen som den ser ut när man spelar och ställer ut start/strid/boss/spade/kista/fackla i rutan man tittar på, tar bort med X, gör rutan till golv eller vägg med G/V och sparar med F2.
**Status:** delvis klar (M82–M84). KVAR: **material per ruta** — `ytor` i `Dungeon.Floor` ("x,y" → material-id, med banans tema som fallback), klippt ur de tre materialarken i `game/images/`, valbart per yta (golv/vägg/tak) både i editorn och i byggläget; **rekvisita som egen nodtyp** (kista, spade, benhög, kandelaber, bur, kedja finns som tillgångar i `game/assets/props/`).

## 16. Hjältarnas kort och deras ikoner
> "Där skall korten på alla hjältar radas upp, så man kan välja dem, läsa om dem innan man köper dem, och sedan läggs de till i ens kortlek."

Kamraterna hyrs i byn (tio i `data/crawlers/00_kamrater.json`, egna kort i leken) och deras kort använder kortikonerna. Men tio hjälteikoner klipptes ur `heroes.jpeg` (M75, `game/assets/heroes/*.png`) och **används inte av någon rad kod** — mätt: noll träffar på `hero` i `game/**/*.gd` och i `game/data/`.
**Status:** öppen. Närmaste steg: koppla varje hjälteikon till sin kamrat (samma id som kortet) och visa den i hyrvyn, eller stryk ikonerna om kortikonerna ska gälla.

## 17. Kortens pixeltäthet i kortvalet
> "När man gått upp i level och får välja kort, så behöver pixeltätheten på korten dubbleras eller mer, för de är suddiga idag."

**Status:** klar 2026-09-23. Orsaken var inte konsten i sig utan VAR valet ritas: kortvalet låg inne i
480x270-vyn, och vyn skalas upp med ett heltal till fönstret (2x vid 1280x720). Allt i valet rastrerades
därför i vyns mått och förstorades efteråt — kortens text (5-7 px) blev grötig, och konstens pixlar olika
breda (mätt i bild: block av 2, 3, 4 och 5 px om varandra, för rutan var 2,8x konsten).

Valet ligger nu i FÖNSTRETS yta (`_runt`, där handens kort, menyn och HUD:en redan låg) och räknar i
fönsterpixlar: samma ruta på skärmen, men varje pixel ritas där den hamnar. Kortet är 225x316 px i båda
fallen — rastret är det dubbla (layoutskalan 0,745 -> 1,49). Ikonens konst ritas dessutom i HELA steg
(`CardView.Ikon`), så varje konstpixel blir lika stor i stället för 2-5 px om varandra.

Mätt: `tests/test_gui.gd` med fyra nya kontroller (valkortets skala >= 1, valets ruta = vyns ruta i
fönsterpixlar, ikonens steg 2x i en 180x150-ruta, proportionell nedskalning i en 20x20-ruta);
mekanismen avstängd (skalan utan fönstrets faktor) fäller skalkontrollen. Bildjämförelse av samma kort
före/efter visar grumlig text och ojämna konstpixlar före — skarp text och jämna pixlar efter.

## 18. Escape i en bana öppnar huvudmenyn — med Spara spel
> "Escape när man är i en bana skall öppna huvudmenyn, och då skall man även kunna välja 'Spara spel' så när man tar 'Ladda spel' från huvudmenyn så fortsätter den från var man befann sig."

**Status:** klar. `ESC` i en körning (`shell == "körning"`) visar huvudmenyn; banan står kvar bakom den
(inget pausas) och `ESC` i menyn lämnar tillbaka till samma ruta. Menyn har fått raden **SPARA SPEL**
före LADDA SPEL; den är spärrad utan pågående körning och säger varför, och ett tryck skriver sparfilen
även när inget ändrats sedan förra sparningen (`tvinga` — signaturen finns för att HUD:en inte ska
skriva 55 filer i sekunden, inte för att hindra en människa som trycker på en knapp) och kvitterar i
bottenraden: "sparat — fortsätt på våning N". Mätt i `tests/test_meny.gd` (51 kontroller): ESC in och ut,
raden spärrad respektive valbar, kvittensen, och att filen skrivs när den raderats mellan två tryck —
mekanismen avstängd fäller just den kontrollen.

## 19. Auran runt spökena — en kant, inte en ånga
> "Spökena ser ut som de ångar, det skall bara vara minimal aura runtom som ger en känsla av etheritet"

**Status:** klar 2026-09-23. Två saker gjorde andarna till rök, och båda satt i mekanismen:

1. **Auran var en FYLLNING över hela kroppen.** Maskens A-band (R=våt G=metall B=glas A=aura) täcker
   för en ande hela figuren, och shadern skrev `aura_farg * m.a` rakt in i ljuset — en varm dimma över
   hela vålnaden. Nu mäts i stället hur BLANDAD en ring av åtta prov kring pixeln är
   (`kantighet = 1 - |2·medel - 1|`): 0 helt innanför silhuetten, 1 på själva kanten. Auran blir en
   mjuk kant några px bred i stället för ett svep över kroppen, och färgen är kall och blek
   (0,68 · 0,80 · 1,00) i stället för varm (1,0 · 0,72 · 0,40) — en vitblek ande med varm dimma över
   sig läser som ånga.
2. **Den gamla "glansen" var en ångpuff.** `rok.png` är en mjuk radial fläck skalad 1,3x runt midjan;
   på en ande är den en dimma. Spökenas fläck togs bort och kanten bär dem.

Masken kunde inte ens skrivas för hans andar: `write_all` hoppade över hela `FRÅN_ALEX` — även masken,
som är materialdata och inte konst. En ny fiende i hans ark kunde alltså aldrig få en mask, och en
ändrad MATERIAL-plan gjorde tyst ingenting ("0 fiender" i utdata). Masken byggs nu ur alfakanalen i
hans PNG medan bilden lämnas orörd, och de sex gamla maskerna räknades om mot hans egentliga silhuett
(9-26 % av pixlarna flyttade sig — de satt på en figur han ritat om).

Mätt: `tools/mat_aura.py` på samma prov före och efter (brusgolvet mellan två körningar är 3 272 px
> 25). Ljuskanten ligger 6-8 px in per rad (en fyllning hade svept figurens hela bredd), tillskottet
50-55 i medel och **0 px över 240** — en läsbar kant utan utfrätning. Granskningen av samma bildruta:
"en enorm, överexponerad ljusbubbla bakom figuren" före mot "ren, subtil silhuett med en jämn eterisk
transparens" efter, och figuren är läsbarare än förut.

## 20. Kärlen sida vid sida, glaskänsla, rustning som följer med och kartans ruta
> "Den använda korthögen ligger över mana. gör både hälsa och mana mindre så de får plats bredvid varandre, men ändå som klot. Dessa är lite platta, så se om du kan öka känslan av glaskulor eller kanske gör dem som glasflaskor (gamla potion-flaskor typ) som håller mana och hälsa. Sen behöver vi ha en rustning som visar rustningens värde (som för övrigt skall följa med genom de olika striderna, inte nollas efter en strid). Informationen om vad varje grej på kartan kan vara en ruta som visas om man trycker på kartan eller en knapp, men behöver inte vara synlig hela tiden."

**Status:** klar 2026-09-23. Fyra saker, och den första var en riktig bugg:

1. **Krocken.** Korthögen ritades över manakärlet. Orsaken satt i två rader: HP-kärlet hade ALLTID sin
   fulla storlek (R_STOR) medan bara manan krymptes efter utrymmet, och klämmen mot korthögarna
   hoppades över när högens överkant låg ovanför den fria ytan (`h.position.y > fri_topp`) — då fanns
   ingen gräns kvar alls. Nu räknas radien ur BÅDE kolumnens bredd och det fria utrymmets höjd (med
   GOLV, inte avrundning: uppåt blev paret några px bredare än marginalen), och klämmen gäller alltid.
2. **Paret.** Hälsa och mana står sida vid sida med samma radie, rustningen som en rad under dem — och
   båda kärlen syns hela körningen (att gömma manan utanför strid gjorde paret osymmetriskt).
3. **Glaskänslan.** Vätskan är inte längre en färg: varje rad får en egen ljushet (mörkast vid botten,
   ljusast vid ytan) plus en skugga där vätskan möter skålens vägg, och glaset har en linsformad
   spegling uppe till vänster och en svagare nere till höger (samma grepp som referensens orbs).
4. **Rustningen följer med.** Den nollställdes vid varje TUR mot metans grundvärde, så ett
   rustningskort var borta innan nästa tur och ingen strid ärvde något. Poolen ägs nu av KÖRNINGEN
   (`Run.armor`), lämnas in när striden börjar och hämtas tillbaka i `finish_fight` (enda vägen ut).
   `start_turn` sätter bara ett GOLV (maxf mot grunden) så "+1 rustning vid turstart" ur metan
   fortfarande gäller men poolen aldrig sjunker. Stapelns tak är det högsta poolen nått — annars står
   stapeln alltid full och säger ingenting om värdet.
5. **Kartans ruta.** Teckenförklaringen är dold tills man klickar på kartan (kartan är nu en knapp:
   `mouse_filter = STOP` och `_gui_input`), och då ritas de sex orden som förut. Är den dold står ett
   litet "?" i kartans nedre högra hörn i stället — ett tecken, inte ett ord, alltså inget att
   översätta till tretton språk. Både `_draw` och ordlistan följer flaggan: orden ligger i ett eget
   lager över kontrollen, och glömde man `ord_rader()` blev det sex ord kvar under en karta som inte
   visade sina märken.

Mätt: `tests/test_gui.gd` mäter krocken i FYRA fönsterstorlekar (1280x720, 1896x1030, 1600x900,
1024x768) — vilken storlek felet sågs i går inte att gissa — plus att paret står sida vid sida i samma
storlek och att värdet i varje kärl ligger innanför fönstret. `tests/test_run.gd` mäter hela
rustningsvägen (7 rustning, en ny tur, striden slut, nästa strid börjar på 7). `tests/test_minikarta.gd`
mäter att rutan är stängd från början, att ett klick visar sex rader, att ett klick till gömmer dem och
att ett SLÄPP inte växlar. Sviten: se nedan.

## 21. Fiendernas täthet och täckning
> "Fiendens pixeltäthet behöver dubbleras eller ännu mer, och de får inte bli transparenta om de är som i detta fall, en cerberus."

**Suddet var en förminskning, inte en liten duk.** Kedjan var: hans ark (figurerna är 66–94 konstpixlar höga) → logisk ruta på 40 → duk på 80 → skärmen. Ledet i mitten skalade ned konsten 2–3 gånger, och uppskalningen till duken förstorade bara det utsuddade. Mätt i hans ark: **8 källpixlar per konstpixel** på den gamla arken, **2** på den nya (därför var den nya arken värst). Duken är nu **120 px = konsten i 1:1** (S = 1 i `gen_enemy_sheet.py`: hans ark ÄR konstpixlar; S > 1 gör bara blocken större), medan den ritade generatorn behåller sin logiska 32-ruta och skalar upp med S = 3 (där finns ingen konst att tappa, bara former att rita finare). Båda dukarna är 120, så spelet har ett `pixel_size` för alla.

**Storleken i världen är räknad i METER, inte i dukpixlar** (M76-regeln): `96 * 0,012 = 1,15 m` för en vanlig och `96 * 0,013 = 1,25 m` för en boss — exakt vad 80-duken gav (64 * 0,018 och 64 * 0,0195). Fötterna `ENEMY_FEET_PX * pixel_size = 0,48 m`. Ändras duken igen ska de två talen räknas om tillsammans; provet `test_assets.gd` räknar taket ur konsten med samma siffror.

**Genomskinligheten var `alpha_cut` + halva alfor.** Källans mask är 0/255, men BOX-nedskalningen medelvärdesbildar kanten, och `ALPHA_CUT_DISCARD` kastar allt under tröskeln — figuren blev gles och väggen syntes igenom (mätt i ruta 0 av cerberus: **1168 halvgenomsläppliga mot 392 helt täta**). Nu sätts alfan till 0/255 sist i `sätt_in` (ett halvt täck är täck): mätt **0 halvgenomsläppliga, 1452 täta**. Materialmaskerna läses ur konsten och måste därför köras EFTER arken — de låg kvar på 480x80 mot 720x120-konst tills generatorn kördes om.

## 22. Speglingen på stenen ned till en tiondel
> "Speculariteten är alldeles för hög, och behöver dras ned till kanske 10 % av nuvarande nivå."

Lyktans och facklornas `light_specular` stod på **1,0** — att ljuset *kunde* ge en högdager var ett medvetet M18-val (utan spegling kan varken vatten, ben, trä eller järn glänsa alls), men stenen fick en hård, vit, zebrarandig hinna längs fackelväggen som läses som olja eller plast, inte sten. Nu **0,1**, mätt i `-- glansprov` med spelets egen ytinställning (samma kamera, samma process): lyftet över "speglingen avstängd" gick från **+0,0438 till +0,0073** medel, alltså 17 % av det gamla, och de mörka partierna tillbaka från 63 % till 75 % (golvet utan spegling: 77 %). Flammorna, facklorna och ljusstyrkan (`LJUS_STYRKA`) är orörda — det var bara speglingen som drogs ned, och matt sten är hela poängen med en fackla i en korridor. Provets post 04 använder nu `LJUS_GLANS` i stället för ett eget 1,0, så "spelets värde" aldrig kan bli en gammal siffra.

## 23. Korten: hel skala och konst i 128
> "De behöver bli betydligt skarpare än så här nämligen."

Två fel ovanpå varandra. (1) **Skalan var ett bråk.** Kortvalets `valskala` räknades som `clamp(..., 0,45, 1,0) * k` = 0,745 * 3 = **2,235** vid 1896x1030, och handens var HAND_SKALA **1,75**. En konstpixel blir då 2 px och nästa 3 — samma fel som M91 tog bort ur *vyn* men lämnade i panelens och handens egen skala. Mätt i Alex' egen skärmbild av kortvalet: körningslängderna i konsten var 1, 2 och 3 px om varandra (1944 ettor), och 99 % av alla 2x2-block var ojämna. Nu **golvas skalan till ett heltal** (2 i kortvalet, 2 i handen — en tiondel större kort, aldrig ett bråk), och provet skriver ut kortens och ikonernas globala rutor: mätt ligger de på hela skärmpixlar (338, 319) med ikonrutan 290x300.

(2) **Ikonerna var för små för rutan.** Alex' potionsark har 2-5 källpixlar per konstpixel (mätt: kantavstånden i arket) — en flaska är ~200 konstpixlar hög — och `gen_card_icons.py` skalade ned den till 64, alltså 3 gånger förminskad, samma fel som fienderna hade i M76. Duken är nu **128** (dubbelt, Alex' egen siffra), 1,6 gånger ned i stället för 3, och stort kort ritar den i **steg 2 = två dukpixlar per konstpixel mot fyra förut** — alltså 4 skärmpixlar per konstpixel mot 8. Mätt i `test_kortbord.gd` på en riktig ikon ur arkivet.

De **modellritade** korten ligger kvar på 64: bildmodellens veckokvot är slut, och en nearest-uppskalning lägger inte till en enda detalj. Provet godkänner båda måtten. När kvoten är tillbaka kan de 56 göras om i 128 med samma recept.

**CRT-filtret var oskyldigt** (mätt, inte antaget): två bilder tagna före och efter ett byte från `filter_linear` till `filter_nearest` på skärmtexturen var pixel-identiska (0 av 1 952 880 pixlar skilde), så bytet gjordes om och filtret står kvar — effekten räknas i FRAGCOORD och ligger 1:1 med rutan.

## Ordning

M32, M33 (pixeltätheten), M36 (HUD-ramen) och M37 (rörelsen) är KLARA 2026-09-21. Sedan M34 (kortborden och albumet: punkt 8 och 9 — kort i solfjäder, hög av använda kort, dragningshög och albumet) och M35 (attackeffekt och dryckes-kvittering). M39 (intro, splash och startmeny) är KLAR 2026-09-21. M40 (GUI:t enligt referensen: statusblock, logg och fienderuta — punkt 14) är KLAR 2026-09-21. Kartpunkten (M41: Alex' egen 16-bit-karta över helvetet, lätt vinklad med kameran på markeringen, en nod per plats, upp till tio nivåer per nod med grön bock, farmning och en editor där han flyttar noderna) är KLAR 2026-09-21, liksom byn (M42: hans egen bild som by — gaten i mitten leder ut till kartan och EXIT-skylten stänger spelet), och kartan är uppdelad i sektioner där nästa sektion öppnar först när en bana i den förra är klarad (M43). Därefter punkt 13 (fiendernas egna shaders, M38) — den ligger sist för att den rör fiendernas material och därmed kan röra allt som ritar en fiende.
