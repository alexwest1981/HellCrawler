## Byn (M42): Alex' egen 16-bit-scen som by — husen, gatan och porten är hans bild, och spelet lägger
## bara sina platser ovanpå den.
##
## Alex: *"Kan du använda detta som by istället? Att gaten i mitten är för att gå ut till strid? osv?"*
## Gaten i mitten ÄR platsen "karta": den leder ut ur byn till världskartan och vidare till strid —
## samma plats som förut, men nu står märket där bilden visar en port.
##
## Bilden äger utseendet (1280x720, samma mått som fönstret) och platserna äger bara en x-position på
## gatan, i procent av bredden. Kvar av den gamla ritade byn är det som bär INFORMATION: märkena,
## markören och etikettlisten längst ned med namn och status. Himlen, åsarna, husen, gatan och
## staketet ritas inte längre i kod — de finns i bilden.
##
## Alla platser står på SAMMA gata (bilden är en sidovy), så marklinjen är en konstant och varje
## märkes nederkant ligger på den. Provet mäter att märkena ryms i vyn, att de inte krockar och att
## de står på linjen.
##
## PANORERING (M50). Alex: *"det gör inget om det tar stopp när man når vardera hörn, men det får inte
## bli den kräkframkallande effekten mer ... du kan få pan'a bilden höger till vänster, men minska till
## originalsize igen, då bilden blir alldeles skev i dagsläget."*
##
## Cylindern är alltså BORTTAGEN, inte justerad: ingen avbildning som kan dra i pixlarna finns kvar.
## Bilden ritas i sin egen skala — hela höjden syns, bredden följer bildens förhållande, ingen
## förstoring och ingen skevhet — och flyttas i sidled tills den valda platsen står mitt i vyn.
## Panoreringen glider mjukt och tar stopp i ändarna; en jämn förflyttning åt ett håll tål ögat, det
## var vridningen och uttöjningen som inte gick.
##
## MÄTT: kantdragningen i den gamla cylinder-avbildningen var 2,4-11 gånger i kanten (tan), och den
## krympte till 0,64-0,84 med sin — men Alex blev åksjuk av båda. Nu finns ingen faktor alls: varje
## bildpixel ritas lika bred var den än hamnar.
##
## HUSEN ÄR KNAPPARNA (M122). Alex: *"Det är de färgade kloten du lagt in i byn som är ett av
## problemen."* Klot-märkena — en nål med en färgad boll per plats, ritad ovanpå bilden — är BORTA.
## Ingen cirkel ritas någonstans i den här vyn (provet läser filen och kräver noll `draw_circle`).
## I stället märks platsen SJÄLV, ur husets EGEN ruta i bilden (`byggnad_rect`):
##
##   * den VALDA platsen: EN PIL ovanför sin post i listen längst ned, och plattan på gatan,
##   * den man HOVRAR över: en svag glöd runt husets silhuett, och husets namn ovanför.
##
## RAMEN RUNT DET VALDA HUSET ÄR BORTA (M124). Alex: *"Det är idag någon weird ram runt det som är
## markerat, och det har jag tyckt väldigt illa om. Jag vill bara ha en pil ovanför det man valt i
## listen under."* Först var ramen en gul ruta, sedan en glöd runt husets silhuett — båda ritade runt
## HELA huset (MÄTT i 941x1018: markeringens ruta var 522x795 px, från fönstrets överkant ned till
## gatan). Nu ritar vyn ingen markering kring huset alls: `pil_rect` i listen bär valet.
##
## KLICKYTAN KOMMER UR 3D-BYN (M126). Alex: byn ritas ur `byn.glb` (se `ui/by_3d.gd`), men klickytorna
## låg kvar i den här filen och räknades ur platsernas procent av panoramabilden. 3D-byn står STILL
## medan 2D-rutan flyttade sig med panoreringen, så klicket hamnade 34-115 px (medel 79 px i en 313 px
## vy) från huset — man klickade på fel hus. Nu räknas platsens ruta ur husets EGNA position i byn.glb
## (`By3D.hus_rect`, prefixet i `3d` på varje plats) och projiceras till vyn; klicket, hovringen,
## glöden och gångaren pekar därför på SAMMA hus som ritas. Utan byn.glb (ett prov utan 3D) gäller
## 2D-rutan i `_byggnad_rect_2d` som förut — en by utan modell ska fortfarande gå att välja i.
##
## `hus_rect` (den kompakta rutan kring platsens punkt) finns kvar som INVARIANT för provet: två
## platsers punkter får inte krocka. Den är också träffyta i reserv, för ett hus vars kropp ligger
## utanför vyn.
class_name VillageView
extends Control

## Platsen man valde och gick in i. `skepp` är skalets läge (main.gd), inte en egen sorts plats.
signal vald(skepp: String)

## BYN ENLIGT VC (M193): en bred målad gata med låg horisont, överdimensionerade hus i rad och
## små figurer — samma uppbyggnad som Vampire Crawlers by, med vår egen konst (genererad, 1264x806).
## PLACEHOLDER (M200): byns riktiga bakgrund, utdragen ur VC:s `sharedassets2` — bara för att kunna SE
## byn fungera innan vår egen bildgenerator är tillbaka. `tools/build.sh` VÄGRAR bygga så länge den här
## raden pekar på `assets/vc_lan`: inget får publiceras med någon annans konst.
const BILD := "res://assets/vc_lan/town/Town_BG.png"
## Byn som MÅLAD 2.5D-scen (M172). False = Alex' panorama ritas, 3D-scenen är urkopplad.
const BY3D := false
## BYN ROTERAR (M194). Alex: *"man roterar i byn på VC ... mellan porten ut, smeden, museet å allt
## det. Inte en platt jävla bild!"* Vyn är en 360-gata: bilden läggs sida vid sida med sin egen
## spegelvändning (skarven blir osynlig), `_pan` är vridningen, och vänster/höger vrider till nästa
## plats. Figur och namn står still i mitten medan världen glider förbi.
const ROTERA := true
## Figuren som går i byn (och på kartan): en av HJÄLTARNA ur Alex' hjälteark (`game/images/heroes.jpeg`,
## klippta av `tools/gen_hjalte.py`, som också sparar namnen i `assets/ui/hjalte.json`).
## HJÄLTEN MAN VALDE (M138): figuren är en MARKÖR, och valet (i huvudmenyn) styr både byn och kartan.
## Här finns ingen konstant att byta — `Meta.hjalte` är källan. De tolv är valerius, elara, gregor,
## sylvia, ragnar, seraphina, kael, arthur, lyra, brutus, zoltar och isabel.
## Hur stor figuren ritas i vyns px. Hjälten är klippt till 48 px höjd och ritas i skalan 1,0 —
## samma höjd som den gamla 23x21-markören ritades (46 px), alltså en människa mot ett tvåvåningshus
## (husen är ~250 vyn-px höga), inte en prick.
const FIGUR_SKALA := 1.0

## Platserna i gatuordning (vänster → höger, som bilden visar dem): `x` är platsens mitt på BILDEN i
## procent av bredden, `x0`/`x1` är HUSETS KROPP i procent av bildens bredd (2D-reservrutan, se
## `_byggnad_rect_2d`) och `färg` är platsens ton ur paletten. `3d` är husets nodnamns-prefix i
## `byn.glb` — det som gör att klickytan, hovringen, glöden och gångaren hamnar på det hus man SER
## (M126). Prefixet är en MÄTNING av Alex' scen (`Weaver_*`/`Smith_*`/…), inte en gissning.
##
## NAMNEN ÄR ENGELSKA EFTERSOM SKYLTARNA I BILDEN ÄR DET. Alex: *"Döp det till Thread of Destiny, Sen
## kommer Blacksmith, Sen The Tavern, sen The Gate, sen Jeweler, och sist Exit."* Bilden bär redan
## sina skyltar målade (BLACKSMITH, THE TAVERN, JEWELER, EXIT ➔, och porten utan text) — svenska namn
## ovanpå engelska skyltar vore två språk på samma hus. Texten är data här och ingen i18n-nyckel: den
## beskriver bilden.
##
## X-POSITIONERNA KOM UR ETT SAMTAL MED BILDEN, EFTER ATT HA VARIT FEL. Den förra listan påstod i en
## kommentar att siffrorna var "LÄSTA ur panoramabilden", men de höll inte: Alex såg att Butiken
## pekade på juvelerarhuset (*"Det står Butiken, men det pekar vid juveleraren på bilden"*), och han
## hade rätt — Butiken stod på 69 %, vilket är inne i JEWELER (63–75 %), och JUVELERAREN stod på
## 31 %, vilket är inne i THE TAVERN (32–48 %). En kommentar är inte en mätning.
##
## Husen ligger nu på: väveriet utan skylt 2–15 % (trädet), Blacksmith 14–31 %, The Tavern 32–48 %,
## stadsporten 45–62 %, Jeweler 63–75 %, EXIT ➔ 75–86 %.
##
## BUTIKEN HAR INGEN DÖRR I BILDEN. Den är inte med i Alex' lista och det finns inget hus kvar till
## den, så platsen är borta härifrån — skärmen finns kvar i skalet (och nås av skalsvepet). Ska
## kortköpet ha en egen dörr får han säga vilket hus den ska bo i.
const PLATSER := [
	{"id": "tradet", "namn": "THREAD OF DESTINY", "skepp": "trad", "x": 24.0, "3d": "Weaver", "x0": 16.0, "x1": 33.0, "topp": 44.0, "färg": 1},
	{"id": "smed", "namn": "BLACKSMITH", "skepp": "smed", "x": 41.0, "3d": "Smith", "x0": 34.0, "x1": 48.0, "topp": 40.0, "färg": 12},
	{"id": "vardshus", "namn": "THE TAVERN", "skepp": "vardshus", "x": 57.0, "3d": "Tavern", "x0": 49.0, "x1": 66.0, "topp": 38.0, "färg": 13},
	{"id": "karta", "namn": "THE GATE", "skepp": "karta", "x": 72.0, "3d": "Gate", "x0": 66.0, "x1": 79.0, "topp": 30.0, "färg": 25},
	{"id": "juvelerare", "namn": "JEWELER", "skepp": "juvelerare", "x": 84.0, "3d": "Jeweler", "x0": 79.0, "x1": 91.0, "topp": 42.0, "färg": 30},
	# EXIT-skylten stänger spelet (Alex: "Exit på bilden behöver vara till att avsluta spelet").
	{"id": "avsluta", "namn": "EXIT", "skepp": "avsluta", "x": 95.0, "3d": "Exit", "x0": 91.0, "x1": 100.0, "topp": 60.0, "färg": 14},
]
const MÄRKE := Vector2(20.0, 26.0)   ## platsens PUNKT-ruta: invarianten provet mäter (och klick i reserv)
const DJUP := 6.0                    ## platsens skugga i sidled (provet räknar in den i krockmåttet)
## Husets ÖVERKANT i procent av bildens höjd. Taken i Alex' bild ligger på 7–11 % av höjden (MÄTT:
## den första raden som avviker från himlens färg i varje hus' spann), och ramen och ljusväggen ska
## täcka huset — inte himlen ovanför det. 9 % ligger mitt i det spannet.
const HUS_TOPP := 9.0
## Gatan och listen ligger på ANDELAR av vyns höjd, inte på fasta px (M113). Alex, i byn: *"Detta är
## inte en by i helskärm..."* — scenen tog 62 % av höjden och listen 27 %. Med 0,78 och 0,86 fyller
## bilden hela höjden (dess gatulinje ligger på 78 % av bildens höjd, se BILDENS_GATA) och listen
## blir ett TUNT ÖVERLÄGG i nederkanten (14 %): MÄTT 1896x1018 före 62 %, efter 100 % scen.
## Konstanterna nedan är DESIGNMÅTTET vid 270 px — samma tal som förr, och bara till för provet.
const MARKLINJE := 168.0             ## gatan i designmåttet (270 px hög vy)
const GATA := 172.0
const BAR := 196.0                   ## etikettlistens överkant i designmåttet
const GUPP := [0, 1, 2, 1]           ## markörens gupp i fyra bildrutor: pixelkonst hackar, den glider inte
## PILEN (M124): den valda platsens post i listen märks med EN pil OVANFÖR sig, som pekar ned på den.
## Raderna är pilens bredd uppifrån och ned — skaft och spets, hårda kanter, ingen rundad form.
const PIL_BREDD := [3, 3, 7, 5, 3, 1]
const PIL_H := 6.0                   ## pilens höjd i vyns px
## Hur fort panoreringen stannar: 1 - exp(-fart * delta). Låg fart = lång, mjuk förflyttning.
const PAN_FART := 8.0
## Var i bildens HÖJD gatan ligger, i procent: märkena ställs på gatans linje, och bilden skjuts i
## höjdled så att den linjen hamnar på MARKLINJE. Utan det står märkena i himlen på en panoramabild
## som är 2,5 gånger bredare än hög.
const BILDENS_GATA := 86.0

var _vald := 0
## Platsen muspekaren står över, eller -1. Sätts på musens RÖRELSE i `_gui_input` och ritas som en
## ljusvägg på huset + husets namn ovanför.
var _hover := -1
## GÅNGAREN (M122): EN figur som går mellan platserna i byn — samma komponent som på världskartan.
## Den står vid den valda platsen, går dit man väljer, och FÖRST NÄR DEN ÄR FRAMME öppnas platsen.
var _gångare: Gångare = null
## Figurens bild, läst en gång (samma markörfigur som huvudmenyn använder).
var _figur: Texture2D = null
## Bildens vänsterkant i vyns koordinater (logiska px). Panoreringen är en förflyttning och inte en
## vinkel: den kan stanna mitt i, och i ändarna tar den slut.
var _pan := 0.0
var _pan_mål := 0.0                  ## dit panoreringen är på väg; `_process` glider dit (aldrig ett hopp)
var _status: Array = []
## LISTAN VÄXER (M192): som i VC visas bara de platser som har en anledning just nu. En plats utan
## ärende står inte grå i listen — den finns inte, och dyker upp när den får ett. `_synliga` är
## indexen i PLATSER som ritas, och kolumnerna räknas ur DEN längden.
var _synliga: Array = []              ## [{text, ljus}] per plats — det som står under namnet i listen
var _t := 0.0
var _ram := 0                        ## bildrutan i guppet; ritas bara om när den byter
var _tex: Texture2D = null           ## byns bild, läst en gång
## BYN I 2D (M123): bakgrund och hus på var sitt lager med egna parallaxfaktorer, och en kamera som
## rör sig en liten bit. Husen är EGNA texturer, klippta ur `byn.png` (se `tools/gen_by_hus.py`), och
## står på gatulinjen — gatan är marken de står på.
## BYN SOM 3D (M125): Alex' egen texturerade scen `byn.glb` ritas i vyn i stället för den platta
## bakgrundsbilden. `ui/by_3d.gd` bygger glb:n, ställer den ortografiska kameran på texturens
## frontvy och lägger röken som partiklar; scenen ligger i sin EGEN SubViewport (samma väg som
## 2D-lagren ritades i) och är sin EGEN 3D-värld — annars hade byns himmelsblå
## `WorldEnvironment` lagt sig över kryptans ljus, eftersom vyn ligger kvar i trädet under en
## körning. `_draw` ritar 3D-texturen när den finns: den gamla bakgrundsbilden (byn.png/bak.png)
## ritas då inte alls, varken över eller under byn.

## LEVANDE BY (M190): rök, glöd och eldflugor i den målade byn.
## VARFÖR EGEN NOD: byns `_draw` mäter text (UiText.storlek_som_ryms) och fick MÄTT 241 ms per
## bildruta när den kördes varje ruta — därför ritas den bara när markörens gupp byter (6 ggr/s).
## Röken måste gå mjukt, så den ligger i ett eget Node2D som ritar om sig själv varje ruta. Byter
## bildrutan i den dyra vyn rör inte röken, och röken rör inte texten.
class Rök extends Node2D:
	var vy = null
	var t := 0.0
	## Skorstenar och ljuskällor i procent av bildens bredd/höjd, lästa ur bilden: smedens skorsten
	## (29 %, 30 %), krogens skorsten (52 %, 27 %), facklorna vid porten (75 %, 26 %).
	var skorstenar: Array = [Vector3(29.0, 30.0, 1.0), Vector3(52.0, 27.0, 0.7)]
	var facklor: Array = [Vector3(73.6, 27.0, 1.0), Vector3(76.4, 27.0, 1.0)]

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		t += delta
		queue_redraw()

	var _puff_tex: Texture2D = null

	func _puff() -> Texture2D:
		if _puff_tex != null:
			return _puff_tex
		# En mjuk rund fläck, ritad en gång. Hård `draw_circle` läser som bollar, inte som rök.
		var s := 64
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		for y in s:
			for x in s:
				var d := (Vector2(x, y) - Vector2(s, s) * 0.5).length() / (float(s) * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a * 0.55))
		_puff_tex = ImageTexture.create_from_image(img)
		return _puff_tex

	func _draw() -> void:
		# Effekterna hör till den MÅLADE byn: i 3D-byn finns rök-emittern och facklorna i scenen.
		if vy == null or not vy.hd_aktiv:
			return
		# Skalan räknas ur vyns EGEN storlek, inte ur main._skala: röken äger ingen referens till
		# skalet och ska inte behöva en. `bild_storlek()` är designmåttet, `size` är ytan den ritas i.
		var mål: Vector2 = vy.bild_storlek()
		if mål.x < 1.0:
			return
		var ruta: Rect2 = vy.hd_ruta(vy.size.x / mål.x)
		if ruta.size.x < 1.0:
			return
		var tex := _puff()
		# RÖKEN: fem staplar per skorsten, var och en med egen förskjutning så det inte pulserar i takt.
		for sk in skorstenar:
			var bas := ruta.position + Vector2(float(sk.x) / 100.0 * ruta.size.x,
				float(sk.y) / 100.0 * ruta.size.y)
			for i in 5:
				var fas: float = fmod(t * 0.16 + float(i) / 5.0 + float(sk.x) * 0.01, 1.0)
				var upp: float = fas * ruta.size.y * 0.22
				var ving: float = sin(fas * 6.28 + float(i)) * ruta.size.x * 0.006
				var st: float = (0.012 + fas * 0.026) * float(sk.z) * ruta.size.y
				var ton: float = (1.0 - fas) * 0.30 * float(sk.z)
				draw_texture_rect(tex, Rect2(bas + Vector2(ving, -upp), Vector2(st, st)), false,
					Color(0.62, 0.64, 0.70, ton))
		# FACKLORNA: ett andetag i ljuset, aldrig ett blink — 0,9 till 1,1 i styrka.
		for fa in facklor:
			var p := ruta.position + Vector2(float(fa.x) / 100.0 * ruta.size.x,
				float(fa.y) / 100.0 * ruta.size.y)
			var puls: float = 1.0 + 0.18 * sin(t * 5.3 + float(fa.x))
			var st2: float = ruta.size.y * 0.075 * puls
			draw_texture_rect(tex, Rect2(p - Vector2(st2, st2) * 0.5, Vector2(st2, st2)), false,
				Color(1.0, 0.62, 0.24, 0.35))
		# ELDFLUGORNA: tio punkter som driver långsamt uppåt och slocknar.
		for i in 10:
			var fas2: float = fmod(t * 0.10 + float(i) * 0.137, 1.0)
			var x: float = (0.15 + 0.75 * fmod(float(i) * 0.37, 1.0) + 0.02 * sin(t * 0.7 + float(i)))
			var y: float = 0.45 - fas2 * 0.32
			var a2: float = sin(fas2 * 3.14159) * 0.55
			var p2 := ruta.position + Vector2(x * ruta.size.x, y * ruta.size.y)
			draw_texture_rect(tex, Rect2(p2, Vector2(6.0, 6.0) * (ruta.size.y / 540.0)), false,
				Color(1.0, 0.85, 0.45, a2))

## KARUSELLEN (M195/M202): byggnaderna står på en ring och vyn vrider ett steg i taget. LÄST UR VC:s kod
## (`TownViewController` + `ButtonCarousel` + `TownBuilding`, se research/16): byn är inga panoramor,
## den är en ring av byggnadsobjekt med egen bild och egen låst/upplåst text.
var _vinkel_hus := {}
var _kam_vinkel := 0.0
var _rot := 0.0
var _rot_mål := 0.0
var _byggnadstex: Dictionary = {}
var _rok: Rök = null
var _by3d_vp: SubViewport = null
var _by3d: By3D = null
## FÖNSTERPIXLAR PER VY-PIXEL (M152). Vyn ligger i `hud`, som skalas upp med heltalet (3 i ett 941 px
## fönster), så en SubViewport i vyns LOGISKA mått renderade 3D:n i en tredjedel av fönstrets
## upplösning och skalades sedan upp 3x — Alex: *"Nr 1, lite för låg upplösning för min smak, det
## behöver bli mer crisp... tänk dig 2.5D HD."* Nu renderas 3D:n i FÖNSTRETS px och krymps ihop till
## vyns logiska ruta; projektionen räknar fortfarande i logiska px, så klick, rutor och figurer står
## kvar där de stod.
var pixlar := 1.0
var _by3d_sprite: Sprite2D = null
var _scen3d: ByScen = null
var _gata_px := 0.0                   ## gatans rad i KONSTENS px (scenen mäter därifrån)
var _bak_tex: Texture2D = null        ## bilden med husen borttagna, läst en gång
## Kamerans sidled/höjdled i vyns px. Följer pekaren (man ser sig om i byn); `kamerapan=` låser den.
## HD-LAGRET (M173): när main ritar panoramat i fönstrets pixlar (1:1) hoppar vyn över bilden och
## ritar bara listen, etiketterna och figuren. Sätts av main när skalet är "hem".
var hd_aktiv := false
var _kamerapan := Vector2.ZERO
var _kamera_låst := false
var textlager: UiText                ## orden, ritade i FÖNSTRETS upplösning (se ui_text.gd)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP      # byn tar emot klick (husen är klickbara)
	# NEAREST satt HÄR och inte bara i projektet: skärpan är ett krav på den här vyn (M122), och ett
	# filter som ärvs från en projektinställning kan ändras utan att någon tittar på byn.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# RÖKEN LIGGER ÖVERST (M190): eget lager så den kan ritas om varje ruta utan att byns dyra
	# textmätning körs. `show_behind_parent` är av — rök ska läggas ÖVER bilden.
	# 3D-ringen är avstängd medan placeholder-bilden används: VC:s bakgrund är redan en färdig scen.
	if ROTERA:
		_bygg_ring()
	_rok = Rök.new()
	_rok.vy = self
	_rok.z_index = 1
	add_child(_rok)
	_pan = _mål_pan(_vald)                        # bilden står vid den valda platsen från start
	_pan_mål = _pan
	set_process(true)
	textlager = UiText.fäst(self)
	# Pekaren lämnar vyn: hovringen ska inte ligga kvar på ett hus man inte längre pekar på.
	mouse_exited.connect(_släpp_hovring)
	# Gångaren börjar vid den valda platsen och står still tills man väljer en annan.
	_ställ_gångaren()

func _exit_tree() -> void:
	# Lagret ligger i FÖNSTRET (annars vore orden uppskalade igen): det måste bort med vyn.
	if textlager != null:
		textlager.frigör()

func _släpp_hovring() -> void:
	if _hover != -1:
		_hover = -1
		_om_markering()
		queue_redraw()

## Gångaren: håller reda på VAR markören står. Ingen promenad kopplas hit (M138).
func gångaren() -> Gångare:
	# Skapas på begäran: ett prov gör en `VillageView.new()` utan träd, och då körs aldrig `_ready`.
	# Att kräva en färdig gångare hade gjort `flytta` till en krasch i varje sådant prov.
	if _gångare == null:
		_gångare = Gångare.new()
	return _gångare

## VAR FIGUREN STÅR (M141). Alex 16/10: *"Sen vill jag att ens karaktär står på gatan, och inte
## menyn"*. Figuren hör till GATAN, inte till menyraden: den står på sin egen fläck i byns mitt och
## rör sig inte när man växlar plats. Vilken plats man valt visas av plattan, glöden och pilen på
## huset — förut flyttades figuren till varje valt hus, och då var karaktären en avbildning av menyn
## i stället för en figur i byn.
const GÅNGAR_ANDEL := 40.0        ## andel av konstens bredd: krogens mitt, där gatan är som bredast

## VAR FIGUREN GÅR (M126): på gatulinjen, framför huset — i VYNS px, vid husets EGET mitt. SAMMA ruta
## som klicket använder, så figuren står på det hus man ser och inte på en panorering som inte ritar
## något. `y` är gatulinjen (`gata_y`).
func ståplats() -> Vector2:
	var bild := byscen()
	var art := float(bild.get_width()) if bild != null else 3232.0
	return Vector2(art * GÅNGAR_ANDEL / 100.0 - _pan, gata_y())

## GATULINJEN I VYN. Med 3D-byn är den världens y = 0 projicerad — husens fot. Den gamla 2D-scenen
## lade gatan på 78 % av vyns höjd, vilket är en ANNAN linje än husens fot (M126); figuren och
## plattan ska stå på den linje husen faktiskt står på.
func gata_y() -> float:
	if _by3d != null and is_instance_valid(_by3d) and _by3d.by != null:
		return _by3d.marklinje_px()
	return marklinje()

## Platsens x i KONSTENS px. Farten i `Gångare` (90 px/s) är då 90 SKÄRM-pixlar per sekund i varje
## fönsterstorlek, eftersom konsten ritas 1:1 — samma tempo som förr, men nu på rätt plats.
func _plats_konst_x(i: int) -> float:
	var bild := byscen()
	var art := float(bild.get_width()) if bild != null else 3232.0
	return art * float(PLATSER[i]["x"]) / 100.0

## Ställ figuren vid den valda platsen. Figuren GÅR inte (M138, Alex 16/10: *"ta för den delen även bort
## själva promenaden mellan, låt den snappa fram och tillbaka när man växlar"*), så det här är den ENDA
## vägen figuren flyttas: den står på sin plats, direkt.
func _ställ_gångaren() -> void:
	gångaren().starta(ståplats(), ståplats())

## GÅ TILL EN PLATS OCH IN I DEN. Platsen öppnas DIREKT (M138): ingen promenad, ingen väntan på att
## figuren ska komma fram — markören står på platsen i samma ögonblick man trycker.
func gå_till(i: int = -1) -> bool:
	if i < 0:
		i = _vald
	if i < 0 or i >= PLATSER.size():
		return false
	_vald = i
	_pan_mål = _mål_pan(_vald)
	_om_markering()
	_ställ_gångaren()
	queue_redraw()
	gå_in(i)
	return true

## Byns bild. Saknas filen ritas en mörk platta i stället: en by utan bild ska synas som en tom scen,
## inte som en krasch — och husen går fortfarande att välja.
func byscen() -> Texture2D:
	if _tex == null and ResourceLoader.exists(BILD):
		_tex = load(BILD)
	return _tex

## BYGG 3D-BYN. Byggs bara när vyns ruta har ändrats — samma regel som 2D-scenen: 1919 meshar och
## en partikelemitter ska inte byggas om i varje bildruta (`visa` anropas varje gång skalet ritar).
##
## SCENEN ÄR EN FIL (M127): kameran, ljusen, miljön och röken står i `res://scenes/by.tscn` (se
## ui/by_3d.gd). Den här raden instansierar den — samma scen Alex öppnar i editorn — i stället för att
## bygga nodträdet i kod. SubViewporten är kvar som en TUNN VÄGG runt scenen: 3D:n ritas till en textur
## som vyn ritar i sin egen upplösning, och `own_world_3d` håller byns himmel borta från kryptan.
##
## RITAS BARA NÄR VYN SYNS (`UPDATE_WHEN_VISIBLE`): byn ligger kvar i trädet under en körning, och en
## SubViewport i UPDATE_ALWAYS hade ritat 1919 meshar per bildruta i fängelsehålan också — samma
## kostnad som `_process`-spärren i den här filen finns för att undvika.
func _bygg_by3d(vy: Vector2) -> void:
	# 2.5D HD (M172). Alex: *"2.5D HD. Kör"* — byn ritas som sin målade bild (assets/ui/byn.png,
	# 3232×1312), inte som en Blender-scen i en SubViewport. 3D-vägen ligger kvar i filen och tänds
	# igen genom att sätta BY3D till true; ingenting raderas.
	if not BY3D:
		return
	var mal := Vector2i(int(round(vy.x * maxf(1.0, pixlar))), int(round(vy.y * maxf(1.0, pixlar))))
	if (_by3d_vp != null and is_instance_valid(_by3d_vp) and _by3d_vp.size == mal):
		if _by3d != null and is_instance_valid(_by3d):
			_by3d.sätt_vy(vy)        # samma ruta: projektionen ska räkna i vyns px varje gång
		return
	if not ResourceLoader.exists(By3D.SCEN) or not ResourceLoader.exists(By3D.GLB):
		return
	if _by3d_vp != null and is_instance_valid(_by3d_vp):
		_by3d_vp.queue_free()
	_by3d_vp = SubViewport.new()
	_by3d_vp.size = mal
	# EGEN VÄRLD. Scenen bär sitt eget WorldEnvironment (skymningshimmel, omgivningsljus), och en
	# WorldEnvironment lägger sig i den värld den står i: delade vyn värld med spelvyn hade byns
	# himmel och ljus lagt sig över kryptan.
	_by3d_vp.own_world_3d = true
	_by3d_vp.transparent_bg = false
	_by3d_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_by3d_vp.msaa_2d = Viewport.MSAA_DISABLED
	add_child(_by3d_vp)
	_by3d = load(By3D.SCEN).instantiate() as By3D
	if _by3d == null:
		return
	_by3d_vp.add_child(_by3d)
	_by3d.sätt_vy(vy)            # husens rutor räknas i SAMMA px som vyn ritar (M126)
	# 3D-bilden läggs i en egen Sprite2D UNDER vyns egen ritning: bara den ska filtreras linjärt
	# (den krymps från fönsterpx till vyns ruta), medan husens platta, figuren och texten behåller
	# NEAREST och sin kantiga stil.
	if _by3d_sprite == null:
		_by3d_sprite = Sprite2D.new()
		_by3d_sprite.centered = false
		_by3d_sprite.show_behind_parent = true
		# NEAREST, inte linjärt: texturen ligger redan i fönstrets px och ritas 1:1 (939 px textur i
		# en 313 px-ruta som skalas 3x). Linjär filtrering på en 1:1-mappning är ingen uppskalning men
		# den samplar mellan två texlar och lägger tillbaka en halv pixel sudd — MÄTT: kantenergin sjönk
		# från 0,1015 till samma nivå som den gamla 3x-uppskalningen.
		_by3d_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_by3d_sprite)
	_by3d_sprite.texture = _by3d_vp.get_texture()
	_by3d_sprite.scale = Vector2.ONE / maxf(1.0, pixlar)

## 3D-byns bild — textur i vyns mått. Null när scenen inte är byggd (glb:n saknas), och i en
## huvudlös körning finns ingen rityta: `_draw` faller då tillbaka på 2D-vyn, precis som förut.
func by3d_textur() -> Texture2D:
	if _by3d_vp == null or not is_instance_valid(_by3d_vp):
		return null
	return _by3d_vp.get_texture()

## 2D-SCENEN (M123). Null när konsten saknas — då ritar vyn sin platta som förr.
func scen3d() -> ByScen:
	return _scen3d

## 3D-byn (M125): glb-noden, för den som vill mäta den (provet i tests/test_by_rok.gd bygger sin egen).
func by3d() -> By3D:
	return _by3d

## Husets ruta i KONSTENS px: samma tal som klickytan räknar ur (`x0`/`x1`, `HUS_TOPP`, `BILDENS_GATA`)
## och SAMMA avrundning som `tools/gen_by_hus.py` — en halv pixel här hade lagt huset snett över sitt
## eget hål i bakgrunden.
func _konst_ruta(i: int, art: Vector2) -> Rect2:
	var p: Dictionary = PLATSER[i]
	var x0 := int(roundf(art.x * float(p["x0"]) / 100.0))
	var x1 := int(roundf(art.x * float(p["x1"]) / 100.0))
	var topp := float(p.get("topp", HUS_TOPP))
	var y0 := int(roundf(art.y * topp / 100.0))
	var y1 := int(roundf(art.y * BILDENS_GATA / 100.0))
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))

## Bakgrunden: bilden med husen borttagna (hålen ifyllda med gata/himmel). Saknas den ritas HELA
## bilden i stället — husen ligger då kvar i bakgrunden, men husets eget objekt ovanpå visar samma
## pixlar, så vyn ser likadan ut i vila. Ett hål är värre än inget hål.
func bak_textur() -> Texture2D:
	var p := "res://assets/ui/byn/bak.png"
	if _bak_tex == null and ResourceLoader.exists(p):
		_bak_tex = load(p)
	if _bak_tex != null:
		return _bak_tex
	return byscen()

## Byggnadens EGNA textur, klippt ur `byn.png`. Saknas filen (generatorn har inte körts) ritas husets
## ruta ur källbilden i stället: samma pixlar, bara samma bild en gång till.
func _hus_textur(i: int) -> Texture2D:
	var p := "res://assets/ui/byn/hus_%s.png" % str(PLATSER[i]["id"])
	if ResourceLoader.exists(p):
		return load(p)
	var konst := byscen()
	if konst == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = konst
	atlas.region = _konst_ruta(i, Vector2(konst.get_width(), konst.get_height()))
	return atlas

## Bygg scenen för vyns aktuella storlek. Husens rutor i KONSTENS px är desamma som klickytan
## (`x0`/`x1`) och höjden går från `HUS_TOPP` ned till gatulinjen — huset man ser är det som reses.
## Byggs om bara när vyns storlek har ändrats: i en kedja av bildrutor räcker det.
func _bygg_scen() -> void:
	# 2.5D HD (M174): den gamla scenen (bak.png + hus ur den gamla konsten) hör till 3D-vägen. Byggdes
	# den ändå ritade den ÖVER HD-lagret — mätt: bilden visade den gamla dagsljusbyn med band och
	# urklippta hus trots att HD-texturen var rätt.
	if not BY3D:
		_scen3d = null
		return
	# 3D-BYN först (M125): den är det som ritas, och den byggs ur SAMMA ruta som 2D-scenen.
	_bygg_by3d(_vy())
	var konst := byscen()
	if konst == null or konst.get_height() <= 0:
		_scen3d = null
		return
	var vy := _vy()
	if _scen3d != null and _scen3d.klar() and _scen3d.vp.size == Vector2i(int(vy.x), int(vy.y)):
		return
	var bak := bak_textur()
	if bak == null:
		_scen3d = null
		return
	var art := Vector2(konst.get_width(), konst.get_height())
	_gata_px = art.y * BILDENS_GATA / 100.0
	var hus: Array = []
	for i in PLATSER.size():
		hus.append({"ruta": _konst_ruta(i, art), "textur": _hus_textur(i)})
	if _scen3d == null:
		_scen3d = ByScen.new()
	_scen3d.bygg(self, vy, bak, hus, _gata_px, bild_storlek().y / art.y)
	_scen3d.sätt_pan(_pan)
	_scen3d.sätt_kamera(_kamerapan.x, _kamerapan.y)
	_om_markering()

## Markeringen. Med 3D-byn ritas hovringsglöden i VYN kring husets projicerade ruta (`_glod`) — 2D-scenens
## glöd låg på husets EGEN textur, och den texturen ritas inte längre. Anropas när valet eller hovringen
## ändras, och det är den ENDA vägen till markeringen: två anrop hade kunnat säga olika saker om vad
## som är valt.
func _om_markering() -> void:
	queue_redraw()

## Kameran i sidled/höjdled. Pekaren styr den (en liten rörelse ger djupkänsla), och `kamerapan=x,y`
## låser den så en provbild kan mäta paralaxen i SAMMA scen.
func kamera_lås(px: Vector2, låst: bool = true) -> void:
	_kamerapan = px
	_kamera_låst = låst
	if _scen3d != null:
		_scen3d.sätt_kamera(_kamerapan.x, _kamerapan.y)
		queue_redraw()

func kameraposition() -> Vector2:
	return _kamerapan

## Fyll statusraderna ur metat. Anropas varje gång skärmen visas: guld och framsteg ändras av
## körningen, och en gammal siffra på markeringen är en lögn om spelarens läge.
func visa(meta: Meta, antal_banor: int) -> void:
	# Vyn kan ha fått sin storlek sedan förra gången (fönstret ändras): panoreringen räknas om mot den
	# valda platsen, annars står markeringen snett i vyn.
	_pan = _mål_pan(_vald)
	_pan_mål = _pan
	_hover = -1
	_bygg_scen()
	# SCENEN MÅSTE FÅ PANORERINGEN ÄVEN NÄR DEN INTE BYGGS OM. `_bygg_scen` lämnar tidigt när vyns
	# storlek är oförändrad, och då står BILDEN kvar på sin gamla panorering medan vyn (och markören)
	# redan har flyttat sig — samma felfamilj som `pan_klart` (mätt: gömd mitt i ett glid, sedan visad
	# igen stod husen kvar där glidet släppte). Anropet är idempotent och flyttar bara sprites.
	if _scen3d != null:
		_scen3d.sätt_pan(_pan)
	_om_markering()
	_ställ_gångaren()
	var tree_buyable := 0
	for gren in meta.branches():
		for rad in meta.tree_lines(str(gren)):
			# Räknat med can_buy, inte med radens pris: trädets noder betalas i CS (M95), och radens
			# "cost" är guldpriset som inte längre gäller. can_buy vet vilken ficka som gäller, så
			# siffran i byn och krysset i vyn kan inte säga olika saker.
			if not bool(rad.get("låst", false)) \
					and bool(meta.can_buy(str(rad.get("id", ""))).get("ok", false)):
				tree_buyable += 1
	var upplåsta: int = meta.unlocked.size()
	# Rader och siffror: FORMEN är översatt, SIFFRAN kommer ur läget. En rad per plats och i SAMMA
	# ordning som PLATSER (Thread of Destiny, Blacksmith, The Tavern, The Gate, Jeweler, Exit) — en
	# rad som hamnar under fel skylt är samma fel som Alex såg på husen.
	# Butikens rad är borta med butikens dörr: uthyrningens "i leken" hör till värdshuset, och
	# uppgraderingarnas antal hörde till butiken som inte längre har ett hus.
	_status = [
		{"text": Tr.t("ui.by.status.buy", "%d att köpa") % tree_buyable if tree_buyable > 0
			else Tr.t("ui.by.status.none", "inget att köpa"), "ljus": tree_buyable > 0},
		{"text": Tr.t("ui.by.status.smith", "ingen verkstad än"), "ljus": false},
		{"text": Tr.t("ui.by.status.deck", "%d i leken") % meta.hired.size()
			if not meta.hired.is_empty() else Tr.t("ui.by.status.nodeck", "inga hyrda"),
			"ljus": not meta.hired.is_empty()},
		{"text": Tr.t("ui.by.status.unlocked", "%d av %d upplåsta") % [upplåsta, antal_banor],
			"ljus": upplåsta > 1},
		{"text": Tr.t("ui.by.status.gems", "%d stenar i fickan") % meta.gem_bag().size()
			if not meta.gem_bag().is_empty() else Tr.t("ui.by.status.nogems", "inga stenar"),
			"ljus": not meta.gem_bag().is_empty()},
		# EXIT-skylten: ingen siffra, bara vad platsen gör. Den ligger sist, som i bilden.
		{"text": Tr.t("ui.by.status.quit", "lämna spelet"), "ljus": false},
	]
	_räckna()
	queue_redraw()

## Vilka platser som syns just nu. Porten och EXIT finns alltid (man måste kunna gå ut i världen och
## ut ur spelet); resten syns när statusraden är tänd, alltså när platsen har något att erbjuda.
func _räckna() -> void:
	_synliga = []
	for i in PLATSER.size():
		var id := str(PLATSER[i]["id"])
		# KÄRNAN FINNS ALLTID: porten, värdshuset (där man hyr), smeden (landmärket i bilden) och
		# EXIT. Det som VÄXER fram är de två som har ett mätt villkor: handeln (något att köpa) och
		# juveleraren (något i fickan).
		var alltid: bool = id in ["karta", "avsluta", "smed", "vardshus"]
		if alltid or (i < _status.size() and bool(_status[i]["ljus"])):
			_synliga.append(i)
	if _synliga.is_empty():
		_synliga = [0]
	if not _synliga.has(_vald):
		_vald = int(_synliga[0])

func synliga() -> Array:
	return _rader()

## Kolumnerna som ritas. Tom `_synliga` betyder "vyn är inte uppdaterad än" (en färsk instans, ett
## prov) — då gäller alla platser, annars ritades ingen rad alls.
func _rader() -> Array:
	if _synliga.is_empty():
		var alla := []
		for i in PLATSER.size():
			alla.append(i)
		return alla
	return _synliga

## Kolumnen en plats står i, räknad bland raderna som ritas.
func _kol(i: int) -> int:
	return _rader().find(i)

func valt_index() -> int:
	return _vald

## Panoreringen i vyns px. Provet räknar ut var konsten ska hamna och jämför med 3D-scenens kamera.
func pan() -> float:
	return _pan

## Platsen muspekaren står över (-1 = ingen). Egen funktion för att provet ska kunna bevisa att
## hovringen träffar rätt HUS — och att den släpps när pekaren lämnar vyn.
func hovrad() -> int:
	return _hover

## Släpp hovringen. Kopplad till `mouse_exited` OCH anropad av provet (en vymus i ett prov ger inget
## mouse_exited), så regeln finns på ett ställe.
func släpp_hovring() -> void:
	_släpp_hovring()

## Sätt hovringen till en plats. Samma väg som musen tar i `_gui_input`, men utan en mus: proven
## använder den, och granskningsflaggan `byhov=N` fotograferar glöden på ett bestämt hus.
func hovra(i: int) -> void:
	var ny := i if i >= 0 and i < PLATSER.size() else -1
	if ny != _hover:
		_hover = ny
		_om_markering()

## Statusraden under en plats namn. Egen funktion (i stället för `_status` direkt) för att provet ska
## kunna mäta att varje plats har en rad — en plats utan status ritar en tom rad, och en tom rad
## under ett namn ser ut som ett fel.
func status_text(i: int) -> String:
	if i < 0 or i >= _status.size():
		return ""
	return str(_status[i]["text"])

## Korgens heltalsskala: fönsterpixlar per vyn-pixel. Läses ur samma nod som textlagret räknar ur
## (SubViewportContainer i main.gd, heltalsskalad och centrerad), så vyn och orden kan inte tro olika
## saker om hur stora pixlarna är. Utanför spelet (ett prov utan korg) finns ingen skala: 1.
func fönsterskala() -> float:
	var korg := _korg()
	if korg == null or korg.scale.x <= 0.0:
		return 1.0
	return maxf(1.0, roundf(korg.scale.x))

## Korgen vyn ritas upp i (SubViewportContainer i main.gd). Samma uppslag som `UiText._korg`.
func _korg() -> SubViewportContainer:
	var vp := get_viewport()
	if vp == null:
		return null
	return vp.get_parent() as SubViewportContainer

## SKÄRPAN (M122). Alex: *"Jag vill ha en by i 2.5D med paralax och crisp grafik, vilket det inte är
## idag."* Skärpan satt i OMSAMPLINGEN, inte i filtret: 3232x1312 konst ritas i 835x339 vyn-pixlar
## (3,87 konstpixlar per vyn-pixel — ett icke-heltal) och skalas sedan upp 3x. Varje skärmpixel fick
## sin färg ur 0,775 konstpixlar, alltså kastades detalj bort och pixlarna blev ojämna.
##
## Nu ritas konsten så att EN konstpixel är EXAKT en skärmpixel: vyn-pixlar per konstpixel = 1/k, där
## k är fönstrets heltalsskala. Ingen omsampling alls — varje skärmpixel ÄR konstens egen pixel.
##
## Utan korg (ett prov utan fönster) finns ingen fönsterskala att räkna mot: då ryms hela konstens
## HÖJD i vyn, som förr. Provet mäter 1:1-vägen genom att sätta en korg i skala 3.
func bild_storlek() -> Vector2:
	var vp := _vy()
	var bild := byscen()
	if bild == null or bild.get_height() <= 0:
		return vp
	# 2.5D HD (M172): utan 3D-ruta finns ingen SubViewport att mäta mot, och bilden ska fylla vyns
	# HÖJD (panoramat är 3232×1312, alltså bredare än 16:9 — det är sidledes man går). Förut räknades
	# storleken ur 3D-rutans heltalsskala, och då ritades bilden 1:1: 3232 px in i en 480 px-vy, vilket
	# visade en förstorad urklippt fläck i stället för byn (mätt: vyn visade vävstugan, inte torget).
	if not BY3D:
		return vp
	if false:
		# Panoramat är ritat i 3232×1312 och visas i 665×270: en nerskalning på 4,9×. NEAREST kastar då
		# fyra av fem pixlar och bilden läser som brus/moiré (mätt i skärmbilden). Linjär filtrering med
		# mipmaps ger en mjuk, målad nerskalning — "HD"-känslan i en 480×270-vy.
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		return Vector2(vp.y * float(bild.get_width()) / float(bild.get_height()), vp.y)
	var k := fönsterskala()
	if _korg() == null:
		return Vector2(vp.y * float(bild.get_width()) / float(bild.get_height()), vp.y)
	return Vector2(float(bild.get_width()) / k, float(bild.get_height()) / k)

## Rita PÅ PIXELGRIDEN: en konstpixel är en skärmpixel bara om konstens kant ligger på en hel
## konstpixel. En förskjutning på en halv pixel (MÄTT: gatulinjen hamnade 0,70 vyn-px fel = 2,1
## skärm-px) gav ojämna pixlar — två breda på sina ställen och tre på andra — fastän skalningen i sig
## var heltalig. Steget är 1/k: en konstpixel i vyns px.
func _pixel_låst(v: float) -> float:
	var steg := 1.0 / fönsterskala()
	return roundf(v / steg) * steg

## Platsens x i BILDENS koordinater (logiska px från bildens vänsterkant), ur dess procent.
func _plats_x(i: int) -> float:
	if ROTERA:
		# Jämnt fördelade över omgången: vridningen ska gå ett steg per byggnad, oavsett var i
		# konsten huset råkade hamna.
		return _omgang() * (float(i) + 0.5) / float(PLATSER.size())
	return bild_storlek().x * float(PLATSER[i]["x"]) / 100.0

## Husets ruta i VYNS px — KLICKYTAN (M126). Med 3D-byn är den husets EGEN position i byn.glb
## (`By3D.hus_rect`), projicerad till vyn, klippt mot vyns kanter. Man klickar alltså på det hus man
## SER. Utan byn.glb gäller 2D-rutan (`_byggnad_rect_2d`), så en by utan modell går att välja i.
func byggnad_rect(i: int) -> Rect2:
	if i < 0 or i >= PLATSER.size():
		return Rect2()
	var r := _hus_3d_rect(i)
	if r.size.x > 0.0 and r.size.y > 0.0:
		return r.intersection(Rect2(Vector2.ZERO, _vy()))
	return _byggnad_rect_2d(i)

## Platsens hus ur 3D-byn, i vyns px. Tom ruta när scenen inte är byggd eller platsen saknar ett
## `3d`-prefix — då finns ingen 3D-ruta att klicka i och 2D-rutan tar över.
func _hus_3d_rect(i: int) -> Rect2:
	if _by3d == null or not is_instance_valid(_by3d):
		return Rect2()
	return _by3d.hus_rect(str(PLATSER[i].get("3d", "")))

## 2D-RESERVRUTAN (M122, reserv sedan M126): husets kropp ur `x0`/`x1` i panoramabilden, klippt mot
## vyn, flyttad med panoreringen. Den flyttade sig medan bilden gjorde det — vilket var hela felet när
## 3D-byn står still — så den används bara när byn.glb inte finns. En tom ruta betyder att huset ligger
## utanför vyn.
func _byggnad_rect_2d(i: int) -> Rect2:
	var b := bild_storlek()
	var p: Dictionary = PLATSER[i]
	var x0 := b.x * float(p["x0"]) / 100.0 - _pan
	var x1 := b.x * float(p["x1"]) / 100.0 - _pan
	# Husets överkant på SKÄRMEN: bilden ritas med gatulinjen på `marklinje()`, så en rad i bilden
	# hamnar på marklinje() - bildens höjd * (gatan - raden).
	var topp := marklinje() - b.y * (BILDENS_GATA - HUS_TOPP) / 100.0
	return Rect2(x0, topp, x1 - x0, marklinje() - topp).intersection(Rect2(Vector2.ZERO, _vy()))

## Hur långt bilden ska flyttas för att plats i ska stå mitt i vyn. Ändarna är taket: panoreringen går
## inte förbi bildens kant (Alex: "det gör inget om det tar stopp när man når vardera hörn").
## Omgångens längd: bild + spegel, tre gånger om. Konsten är EN vy (1264x806), och en 360-gata
## behöver en remsa som är flera skärmar lång — annars snurrar byn ett helt varv på två steg.
const VARV_PAR := 3
func _period() -> float:
	return bild_storlek().x * 2.0 * float(VARV_PAR)

func _mål_pan(i: int) -> float:
	if ROTERA:
		# VRIDNINGEN GÅR RUNT (M201). Alex: *"Den roterar inte"*. Platsen ska stå mitt i vyn och
		# vridningen är en omgång = bildens bredd; kortaste vägen dit, annars snurrar byn nästan ett
		# helt varv när man går bakåt.
		var per := _omgang()
		var mål := _plats_x(i) - _vy().x * 0.5
		var skillnad := fposmod(mål - _pan + per * 0.5, per) - per * 0.5
		return fposmod(_pan + skillnad, per)
	# 2.5D HD (M174): bilden fyller vyn exakt, så det finns inget att panorera. Alex: *"något weird
	# parallax som flyttar sig åt fel håll när man rör muspekaren"* — bort.
	if not BY3D:
		return 0.0
	var vp := _vy()
	return clampf(_plats_x(i) - vp.x * 0.5, 0.0, maxf(0.0, bild_storlek().x - vp.x))

## En omgång: hur långt vridningen går innan byn kommer tillbaka till samma läge.
func _omgang() -> float:
	return maxf(_vy().x, bild_storlek().x)

## Ligger platsen inom vyn? De utanför ritas inte — ett märke utanför kanten syns inte, och klickytan
## ska inte fånga ett klick som hör till bilden.
func synlig(i: int) -> bool:
	var x := _plats_x(i) - _pan
	return x > -MÄRKE.x and x < _vy().x + MÄRKE.x

## Platsens mitt i VYNS koordinater: bildens x minus panoreringen. Y-läget är konstant — marklinjen
## står stilla, det är bara bilden som flyttas i sidled.
func plats_px(i: int) -> Vector2:
	return Vector2(_plats_x(i) - _pan, marklinje() - MÄRKE.y / 2.0)

## Flytta markeringen. Byn är en gata: bara vänster/höger har någon granne, och i ändarna tar det
## stopp — en panorering som vek runt skulle fara från bildens ena kant till den andra i ett svep.
func flytta(dir: Vector2i) -> bool:
	if dir.x == 0:
		return false
	var kol := _kol(_vald)
	var nästa_kol := kol + (1 if dir.x > 0 else -1)
	# Stopp i ändarna, som förut: en panorering som viker runt skulle fara från bildens ena kant till
	# den andra i ett svep, och det är precis den sortens kast Alex inte tål.
	if nästa_kol < 0 or nästa_kol >= _rader().size():
		return false
	var nästa: int = int(_rader()[nästa_kol])
	_rot_mål += (1.0 if dir.x > 0 else -1.0)

	_vald = nästa
	_pan_mål = _mål_pan(_vald)
	_om_markering()
	# FIGUREN SNAPPAR TILL PLATSEN (M138). Alex 16/10: *"ta för den delen även bort själva promenaden
	# mellan, låt den snappa fram och tillbaka när man växlar"*. Att bara FLYTTA markeringen öppnar
	# ingenting — det gör `gå_till` (Enter/klick).
	_ställ_gångaren()
	queue_redraw()
	return true

## Panorera till den valda platsen direkt, utan glid. Provet (och en skärmbild) behöver ett vaket
## läge utan att vänta på bildrutor, och spelet använder samma väg när vyn visas på nytt.
##
## PANORERINGEN BOR I SCENEN (M123, mätt): bakgrunden och husen är sprites vars positioner räknas ur
## `_pan`, så att sätta `_pan` utan att säga det till scenen lämnar BILDEN kvar på sin gamla plats
## medan vyn tror att den flyttat sig. Mätt: vid sista platsen stod `_pan` på 976 vyn-px medan
## bakgrunden ritades vid 0 — utsnittet var kvar på konstens x 0..1278 och EXIT-skylten (konstens
## x 2424..2780) fanns inte i bilden, fast vyns egen ruta för platsen låg mitt i vyn. Glidet döljer
## felet i spelet (det anropar `sätt_pan` varje bildruta); den här vägen och `visa()` gjorde det inte.
func pan_klart() -> void:
	_pan = _pan_mål
	if _scen3d != null:
		_scen3d.sätt_pan(_pan)
	queue_redraw()

## Gå in i plats i. Utan index: den valda. Ett index som inte finns nekas — den som pekar på en
## plats som inte finns ska INTE hamna på en annan (det var precis vad som hände innan: ett index
## utanför listan betydde "strunta i det" och gick in i den plats markeringen råkade stå på).
func gå_in(i: int = -1) -> String:
	if i < 0:
		i = _vald
	if i >= PLATSER.size():
		return ""
	_vald = i
	_pan_mål = _mål_pan(_vald)
	_om_markering()
	var skepp := str(PLATSER[_vald]["skepp"])
	vald.emit(skepp)
	queue_redraw()
	return skepp

## Platsens kompakta PUNKT-ruta. Provet mäter den (två platsers punkter får inte krocka), och den är
## träffyta i reserv: ett hus vars kropp ligger nästan helt utanför vyn har ingen ruta kvar att klicka
## i, men punkt-rutan står alltid vid gatulinjen.
func hus_rect(i: int) -> Rect2:
	return Rect2(plats_px(i) - MÄRKE / 2.0, MÄRKE)

## Vilken plats ligger under pekaren? Husets EGEN ruta först — man klickar på byggnaden man ser — och
## punkt-rutan i reserv. -1 = inget hus.
func plats_vid(p: Vector2) -> int:
	# KLICK GÅR ALLTID (M192): husen SYNS i scenen även när platsen inte har ett ärende, så ett klick
	# på dem ska gå in. Det är LISTAN som växer, som i VC — inte byn.
	for i in PLATSER.size():
		if byggnad_rect(i).has_point(p):
			return i
	for i in PLATSER.size():
		if hus_rect(i).grow(6.0).has_point(p):
			return i
	return -1

func _process(delta: float) -> void:
	# GÖMD VY GÖR INGET: byn och kartan ligger kvar i trädet under en körning, och deras textbyggen
	# (fontmätningarna i UiText.storlek_som_ryms) kördes varje bildruta fast ingen såg dem — mätt:
	# skripttiden var 241 ms per bildruta i fängelsehålan, alltså spelet gick i 4 fps.
	# `_process` går före ritningen, så raderna är satta innan den första synliga bildrutan.
	if not is_visible_in_tree():
		return
	# Guppet ritas om BARA när bildrutan byter (6 per sekund). En full ommålning var bildruta
	# för en guppande triangel är 60 gånger mer arbete än markören är värd.
	_t += delta
	var ram := int(_t * 6.0) % GUPP.size()
	if ram != _ram:
		_ram = ram
		queue_redraw()
	# Panoreringen glider mot målet. Glider den klart ritas vyn om en sista gång och sedan inte mer:
	# en stillastående bild ska kosta ingenting.
	if ROTERA and absf(_rot_mål - _rot) > 0.0005:
		_rot = lerpf(_rot, _rot_mål, 1.0 - exp(-PAN_FART * delta))
		if absf(_rot_mål - _rot) <= 0.0005:
			_rot = _rot_mål
		queue_redraw()
	if absf(_pan_mål - _pan) > 0.05:
		_pan = lerpf(_pan, _pan_mål, 1.0 - exp(-PAN_FART * delta))
		if absf(_pan_mål - _pan) <= 0.05:
			_pan = _pan_mål
			if ROTERA:
				_pan = fposmod(_pan, _period())
		if _scen3d != null:
			_scen3d.sätt_pan(_pan)      # husen och bakgrunden flyttas i 3D-rymden, inte på skärmen
		# KARAKTÄREN FÖLJER GATAN (M141): han står på en fast fläck i byn, så när panoreringen glider
		# flyttar han med världen i stället för att stå kvar mot en gata som rör sig under honom.
		_ställ_gångaren()
		queue_redraw()
	_sätt_figur()
	# Orden sätts HÄR, inte i `_draw`: lagret ligger i fönstret och måste ha raderna innan bildrutan
	# ritas (annars står den första bildrutan tom).
	_ord()

func _gui_input(event: InputEvent) -> void:
	# HOVRINGEN (M122): vilket hus pekaren står över. Läses på musens RÖRELSE, och vyn ritas bara om
	# när platsen BYTS — en ommålning per musrörelse vore en ommålning per bildruta.
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		# KAMERAN SER SIG OM (M122): pekaren drar kameran en liten bit i sid- och höjdled. Det är den
		# rörelsen som ger paralax — husen och bakgrunden flyttar sig olika mycket (se by_scen.gd).
		if not _kamera_låst and _scen3d != null:
			var halv := _vy() * 0.5
			if BY3D:
				_kamerapan = Vector2((pos.x - halv.x) / maxf(1.0, halv.x), (pos.y - halv.y) / maxf(1.0, halv.y)) * ByScen.SVEP
			_scen3d.sätt_kamera(_kamerapan.x, _kamerapan.y)
		var ny := plats_vid(pos)
		if ny != _hover:
			_hover = ny
			_om_markering()
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
		return
	# Klicket går på SAMMA ruta som hovringen: huset man ser är knappen. Och det GÅR dit — man kommer
	# in först när figuren är framme (`gå_till`), inte i samma ögonblick man klickar.
	var träff := plats_vid(m.position)
	if träff >= 0:
		gå_till(träff)

# --- ritningen ---------------------------------------------------------------
func _draw() -> void:
	var vp := _vy()
	if ROTERA:
		_rita_roterande(vp)
		return
	# 3D-BYN (M125) ritas när den finns: Alex' texturerade scen ur sin egen ruta, kant i kant i vyn.
	# Den gamla bakgrundsbilden ritas då INTE — varken över eller under byn (grenen nedan är
	# reservvägen för en körning utan rityta eller ett projekt utan byn.glb).
	var by3d_tex := by3d_textur()
	if _by3d_sprite != null and _by3d_sprite.texture != null:
		pass                                  # 3D:n ligger under vyn som Sprite2D (M152)
	elif by3d_tex != null:
		draw_texture_rect(by3d_tex, Rect2(Vector2.ZERO, vp), false)
	elif _scen3d != null and _scen3d.klar() and not hd_aktiv:
		# 3D-SCENEN (M122): bakgrund och hus ritas i den inre vyn, på var sitt djup, och den ritas
		# 1:1 här — en pixel i den inre vyn är en pixel i vyn, som skalas till skärmen med heltalet.
		draw_texture_rect(_scen3d.textur(), Rect2(Vector2.ZERO, vp), false)
	elif hd_aktiv:
		pass                                  # HD-lagret under vyn äger bilden (M174)
	elif byscen() != null:
		_bilden(vp, byscen())
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Palett.c(1))
	# HOVRINGSGLÖDEN ÄR BORTA (M152). Alex: *"Rutan som blir runt det som är markerat — det ser inte
	# jättebra ut, det skippar jag helst."* Den var en rektangel i tre band runt husets ruta, och en
	# rektangel runt ett hus i en tippad 3D-vy läser som en urklippt bildruta. Kvar som svar på
	# hovringen: husets namn i listen och markörens form.
	# En mörk ton nedtill, tonad i åtta steg: etiketterna ska läsas mot en lugn yta, inte mot
	# kullerstenen — och en rak kant mellan bilden och listen läses som en skarv.
	for k in 8:
		draw_rect(Rect2(0.0, bar_topp() - 8.0 + float(k), vp.x, 1.0), _a(Palett.c(0), 0.10 * float(k)))
	_bar(vp)
	_pil()
	# Plattan den valda platsen står på, SIST av scenen.
	for i in PLATSER.size():
		_hus(i)
	# GÅNGAREN sist: hon går på gatan framför husen, alltså närmast betraktaren.
	if not ROTERA:
		_gångare_ritning()

## HOVRINGSGLÖDEN ÄR BORTA (M152) — se `_draw`. Den här raden finns kvar bara för att provet ska
## kunna mäta att ingen ram ritas: den svarar alltid tom.
func glod_rect() -> Rect2:
	return Rect2()

## Figurbilden: figurens egen ruta i vyn, centrerad i sidled på `pos()` och med fötterna på den.
func figur_rect() -> Rect2:
	var p := gångaren().pos()
	var m: Vector2 = Vector2(_figur.get_size()) * FIGUR_SKALA if _figur != null else Vector2.ZERO
	return Rect2(p.x + gångaren().vick_sida() - m.x * 0.5,
		p.y - m.y - gångaren().vick_gupp(), m.x, m.y)

## HUSET MÄRKS (M123). Glöden runt byggnadens silhuett ligger i `_glod`; kvar här är plattan på gatan:
## den valda platsen STÅR på den, och det är den som säger "gatan är marken de står på".
func _hus(i: int) -> void:
	if i != _vald:
		return
	var r := markör_ram()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	# Plattan på gatan: fyra px guld med en mörk kant runt om, lika bred som huset. Den ligger på
	# husets EGEN projicerade ruta (M126) — 2D-scenens kameraförskjutning hörde till en scen som inte
	# ritas, och lade plattan vid sidan av huset.
	var platta := Rect2(r.position.x, gata_y() + 2.0, r.size.x, 4.0)
	draw_rect(platta.grow(1.0), Palett.c(1))
	draw_rect(platta, Palett.c(14))
	draw_rect(Rect2(platta.position + Vector2(2.0, 1.0), Vector2(maxf(0.0, platta.size.x - 4.0), 1.0)), Palett.c(13))
	# Guppet: ett litet märke i plattans mitt som andas, så markeringen syns röra sig även när bilden
	# står still (det gamla guppet satt i pilen ovanför märket).
	var mitt := platta.get_center().x
	var b: float = 6.0 + float(GUPP[_ram]) * 2.0
	draw_rect(Rect2(mitt - b / 2.0, platta.end.y + 1.0, b, 2.0), Palett.c(1))
	draw_rect(Rect2(mitt - b / 2.0 + 1.0, platta.end.y + 1.0, b - 2.0, 1.0), Palett.c(14))

## Figuren (M126). Hon ritas i VYN (`_gångare_ritning`) — 2D-scenen som bar henne förut ritas inte
## längre, och en figur ingen ser är ingen gångare. Här laddas bara texturen, en gång.
var _figur_väg := ""

## Filen markören ritar. Provet jämför den med kartans: samma hjälte på båda ställena (M138).
func figur_väg() -> String:
	return _figur_väg

func _sätt_figur() -> void:
	# TEXTUREN BYTS NÄR VALET BYTS: provet och spelet kan välja hjälte medan vyn lever, och en markör
	# som visar den förra hjälten vore en lögn om vad man valt.
	var väg := Meta.hjalte_bild()
	if _figur_väg != väg:
		_figur_väg = väg
		_figur = null
		if ResourceLoader.exists(väg):
			_figur = load(väg)

## GÅNGAREN: figuren står på gatulinjen framför huset och ritas i HUSENS px (samma ruta som klicket och
## glöden), centrerad i sidled på sin punkt med fötterna på den. Vickningen följer med.
func _gångare_ritning() -> void:
	if _figur == null:
		return
	draw_texture_rect(_figur, figur_rect(), false)

## Bilden: EN ruta, flyttad i sidled och skjuten i höjdled så att gatulinjen hamnar på MARKLINJE.
## Ingen remsa, ingen avbildning, ingen faktor — det finns ingenting kvar som kan dra i pixlarna, och
## det var hela poängen: Alex blev åksjuk av varje form av uttöjning.
##
## Rutan LÅSES till pixelgriden (`_pixel_låst`, M122): storleken är redan ett helt antal konstpixlar,
## och kanten måste också ligga på en. Både panoreringen och gatulinjen snäpps, så gatulinjen hamnar
## högst en skärmpixel från MARKLINJE — billigare än att låta varje pixel bli omsamplad.
func _bilden(vp: Vector2, bild: Texture2D) -> void:
	var mål := bild_storlek()
	draw_texture_rect_region(bild,
		Rect2(_pixel_låst(-_pan),
			_pixel_låst(marklinje() - mål.y * BILDENS_GATA / 100.0), mål.x, mål.y),
		Rect2(0.0, 0.0, float(bild.get_width()), float(bild.get_height())))

## Orden i FÖNSTRETS upplösning (se ui_text.gd). Vyn ritar bara bilden, husen och listen — så
## pixelkonsten är kvar i vyns mått medan bokstäverna ritas skarpa i fönstret.
func _ord() -> void:
	# ROTERANDE BY (M194): namn och status ritas i vyns egen `_draw` för platsen i mitten. Den gamla
	# listan med sex rader hör till den platta vyn och skulle ligga dubbelt över remsan.
	if textlager != null:
		textlager.sätt([] if ROTERA else etiketter())

func _vy() -> Vector2:
	return Vector2(size.x if size.x > 0.0 else 480.0, size.y if size.y > 0.0 else 270.0)

## Gatulinjen i vyns px: 78 % av höjden, alltså samma andel av BILDEN som ligger över gatan
## (BILDENS_GATA). Då fyller bilden hela höjden kant i kant.
func marklinje() -> float:
	return _vy().y * 0.78

## Panoramat i FÖNSTRETS pixlar. `skala` = fönsterhöjd / 270 (4 vid 1080p). Samma formel som `_bilden`
## använder i vyn, bara gånger skalan — annars glider HD-bilden i sidled mot markören och listen.
func hd_ruta(skala: float) -> Rect2:
	var bild := byscen()
	if bild == null:
		return Rect2()
	var mål := bild_storlek()
	if not BY3D:
		return Rect2(0.0, 0.0, mål.x * skala, mål.y * skala)
	var y := marklinje() - mål.y * BILDENS_GATA / 100.0
	return Rect2(-_pan * skala, y * skala, mål.x * skala, mål.y * skala)


## Etikettlistens överkant: den sista fjortondelen av höjden. Listen är ett överlägg på scenen,
## inte ett band under den.
func bar_topp() -> float:
	return _vy().y * 0.85

## En färg ur paletten med genomskinlighet. Ljuset ritas som fläckar med alfa — det finns ingen
## ljuskälla i en ritad scen, så fläcken ÄR ljuset.
func _a(c: Color, alfa: float) -> Color:
	return Color(c.r, c.g, c.b, alfa)

## Markeringens ram: den valda platsens hus, klippt till vyn med två px marginal. Egen funktion för
## att provet ska kunna mäta att ramen ALLTID ryms i vyn — en markering som sticker ut över kanten
## syns bara på bild.
func markör_ram() -> Rect2:
	var vp := _vy()
	return byggnad_rect(_vald).intersection(Rect2(2.0, 2.0, vp.x - 4.0, vp.y - 4.0))

## PILENS ruta i VYNS px: EN pil, centrerad över den VALDA postens cell i listen, med spetsen nedåt
## och två px ovanför listen. Den läses ur `_vald` — samma källa som listens guldruta och plattan på
## gatan — så pilen, posten och markören kan inte säga olika saker om vad som är valt.
##
## Mitten läggs på en HALV vyn-pixel och bredderna är udda: då ligger varje rads båda kanter på
## pixelgriden och radbredderna blir exakt 3, 3, 7, 5, 3, 1. MÄTT på provbilden i 941x1018 (där en
## vyn-pixel är tre skärmpixlar) med mitten på ett heltal: raderna hamnade en pixel snett mot varandra
## och 4 px-breda rader blev 18 eller 21 px. Priset för gridläget är att pilen ligger högst en halv
## vyn-pixel från cellens mitt — cellen är 52 px bred, så det syns inte.
func pil_rect() -> Rect2:
	var cell := _vy().x / float(maxi(1, _rader().size()))
	var bredd: float = float(PIL_BREDD.max())
	var mitten := floorf((float(_kol(_vald)) + 0.5) * cell) + 0.5
	return Rect2(mitten - bredd * 0.5, bar_topp() - PIL_H - 2.0, bredd, PIL_H)

## Pilen ritas rad för rad: hård pixelkonst i Palett.c(14) med en mörk kant i Palett.c(1) — samma
## färgpar som den valda postens guldtext och som plattan på gatan använder.
func _pil() -> void:
	var r := pil_rect()
	var mitt := r.get_center().x
	for rad in PIL_BREDD.size():
		var b := float(PIL_BREDD[rad])
		var y := r.position.y + float(rad)
		draw_rect(Rect2(mitt - b * 0.5 - 1.0, y, b + 2.0, 1.0), Palett.c(1))
		draw_rect(Rect2(mitt - b * 0.5, y, b, 1.0), Palett.c(14))

## Etikettlisten längst ned: en mörk list med en guldkant och en ruta per plats. Texten står I
## listen — över en bild med hus och gata drunknar den i kullerstenen (granskningen av den gamla
## byn: "text unreadable over busy terrain").
## BYGGNADEN SOM EGEN BILD: en ruta ur bykonsten (x0..x1, topp..botten), cachad per plats. Det är
## samma sak som VC:s `TownBuilding` — varje byggnad är ett objekt, inte en fläck i en gemensam bild.
func _byggnadstextur(i: int) -> Texture2D:
	if _byggnadstex.has(i):
		return _byggnadstex[i]
	var tex := byscen()
	if tex == null:
		return null
	var p: Dictionary = PLATSER[i]
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var x0 := w * float(p["x0"]) / 100.0
	var x1 := w * float(p["x1"]) / 100.0
	var y0 := h * float(p["topp"]) / 100.0
	# KANTEN MÅSTE TONA UT (M195): en rätkantig urklippning läser som en söm genom himmel och träd
	# (mätt på skärmbild: hårda vertikala linjer). Alfan tonas över 12 % av bredden på var sida.
	var bild := tex.get_image()
	if bild == null:
		return null
	var region := Rect2i(int(x0), int(y0), int(maxf(8.0, x1 - x0)), int(maxf(8.0, h - y0)))
	var bit := bild.get_region(region)
	bit.convert(Image.FORMAT_RGBA8)
	var bw := bit.get_width()
	var kant := maxi(2, int(float(bw) * 0.12))
	for y in bit.get_height():
		for x in bw:
			var a := 1.0
			if x < kant:
				a = float(x) / float(kant)
			elif x >= bw - kant:
				a = float(bw - 1 - x) / float(kant)
			if a < 1.0:
				var c := bit.get_pixel(x, y)
				bit.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * a))
	var ut := ImageTexture.create_from_image(bit)
	_byggnadstex[i] = ut
	return ut

## Hur långt platsen står från den valda, kortaste vägen runt ringen (−n/2 … n/2).
func _delta(i: int) -> float:
	var n := PLATSER.size()
	return fposmod(float(i) - _rot + float(n) * 0.5, float(n)) - float(n) * 0.5


## BYN I 3D (M198). Alex: *"De har någon form av 3d i sin meny"*. VC:s by är geometri med
## pixelart-texturer (mätt i research/00) och karusellen (`ButtonCarousel`) vrider kameran mellan
## byggnaderna. Här är samma sak i miniatyr: sex byggnadskroppar på en ring, kameran i mitten, och
## vridningen är kamerans vinkel. Konstens urklipp blir byggnadernas fasad.
## Medelfärgen ur en rad i bykonsten (0 = överkant, 1 = nederkant). Cachad: läses en gång.
var _bakfärger: Dictionary = {}
func _bakfärg(y: float) -> Color:
	var nyckel := int(y * 100.0)
	if _bakfärger.has(nyckel):
		return _bakfärger[nyckel]
	var tex := byscen()
	if tex == null:
		return Palett.c(1)
	var bild := tex.get_image()
	if bild == null:
		return Palett.c(1)
	var rad := clampi(int(y * float(bild.get_height())), 0, bild.get_height() - 1)
	var summa := Color(0, 0, 0, 0)
	var n := 0
	for x in range(0, bild.get_width(), 8):
		summa += bild.get_pixel(x, rad)
		n += 1
	summa /= maxf(1.0, float(n))
	_bakfärger[nyckel] = summa
	return summa

var _ring_vp: SubViewport = null
var _ring_kam: Camera3D = null
var _ring_byggd := false

func _bygg_ring() -> void:
	var mått := Vector2i(int(_vy().x), int(_vy().y))
	_ring_vp = SubViewport.new()
	_ring_vp.size = mått
	_ring_vp.own_world_3d = true
	_ring_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ring_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_ring_vp)
	var värld := Node3D.new()
	_ring_vp.add_child(värld)
	# LJUSET: kallt omgivningsljus och en varm sol, samma förhållande som i konsten.
	var env := Environment.new()
	# SKYBOX (M208): himlen är en egen panorama i spelets palett (tools/gen_himmel.py), inte en
	# tom färg. Den ger horisont, måne och dis, och omgivningsljuset tas ur den så byn hänger ihop
	# med himlen i stället för att stå i ett svart rum.
	env.background_mode = Environment.BG_SKY
	var himmel := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	# KVÄLLSHIMMEL (M212): Poly Havens "belfast_sunset_puresky" (CC0) i 1k, i stället för den ritade
	# himlen. `puresky` har ingen mark, alltså ingen horisont som krockar med vår egen.
	var kväll: Texture2D = load("res://assets/by2d/kvallshimmel.hdr")
	pano.panorama = kväll if kväll != null else load("res://assets/by2d/himmel.png")
	pano.filter = false
	himmel.sky_material = pano
	env.sky = himmel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	# DIMHED (M209): Alex: *"det blir så tvärt avslutat"*. Marken tonar ut i himlens färg.
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.34, 0.44)
	env.fog_density = 0.011
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.ambient_light_energy = 0.55
	# GLOW OCH DJUP (M225): Alex: *"det känns 1995 a la playstation 1 ... det behöver ha glow,
	# depthmapping, normalmapping"*. Glöd kräver Forward+ (Vulkan), inte Compatibility — därför syntes
	# ingen ljusspill i de tidigare skärmbilderna (de kördes med --rendering-driver opengl3).
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true
	env.ssao_radius = 1.8
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	env.ssil_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	värld.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.7
	sol.light_color = Color(1.0, 0.86, 0.70)
	sol.rotation_degrees = Vector3(-38.0, 34.0, 0.0)
	värld.add_child(sol)
	# MARKEN: en skiva med gatans färg.
	var golv := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(40.0, 40.0)
	golv.mesh = plan
	var gm := StandardMaterial3D.new()
	var gattex: Texture2D = load("res://assets/tiles/material/ancient_stone.png")
	gm.albedo_texture = gattex
	gm.uv1_scale = Vector3(12.0, 12.0, 1.0)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gm.albedo_color = Color(0.75, 0.75, 0.78)
	golv.material_override = gm
	värld.add_child(golv)
	# HUSEN UR DATA (M204): `data/by.json` är byns layout — ringens radie och varje hus vinkel,
	# mått och material. Samma princip som rummen: layouten är en fil, konsten är spelets egna rutor.
	var data: Dictionary = {}
	var fil := FileAccess.open("res://data/by.json", FileAccess.READ)
	if fil != null:
		data = JSON.parse_string(fil.get_as_text())
		fil.close()
	var radie := float(data.get("radie", 9.0))
	for hus_data in data.get("hus", []):
		var d: Dictionary = hus_data
		var vinkel := deg_to_rad(float(d.get("vinkel", 0.0)))
		var hus := Node3D.new()
		hus.position = Vector3(sin(vinkel) * radie, 0.0, cos(vinkel) * radie)
		# FASADEN INÅT (M211): modellerna byggdes med fasaden åt +Z, och på ringen pekade `vinkel` dem
		# utåt — därför såg man baksidan. Ett halvt varv gör att man ser dörr och fönster.
		hus.rotation.y = vinkel + PI
		_vinkel_hus[str(d.get("id", ""))] = vinkel
		värld.add_child(hus)
		# MODELLEN (M210): huset är en Blender-modell (tools/gen_by_hus3d.py), inte en låda.
		# Saknas filen ritas ingen kropp alls — då syns felet direkt i stället för en tyst låda.
		# PORTEN (M236): Alex: *"jag tänkte mig annars bara att det hade räckt om gaten såg ut som denna"*.
		# karta-modellen (porttornet) ritas inte längre — porten är en egen träport (port.glb ur
		# wooden-gate.zip) och muren tar slut på varsin sida om den.
		var modell: PackedScene = null
		if str(d.get("id", "")) != "karta":
			modell = load("res://assets/by/models/%s.glb" % str(d.get("id", "")))
		if modell != null:
			var instans := modell.instantiate()
			# SKALA (M221): Alex: *"de skall liksom inte tillhora en smurf"*. Modellerna ar byggda i
			# 4-6 m; gangavstandet gor dem sma i rutan, sa de skalas upp till byniva.
			instans.scale = Vector3.ONE
			hus.add_child(instans)
			# TEXTURERNA (M231): Alex: *"sen behöver vi se över texturen på det hela"*. Modellernas
			# material importeras med skarp närmaste-grann-filter, vilket kraschar i kanterna på långt
			# håll. Linjärt filter MED mipmaps och anisotropi ger mjuka övergångar utan att reliefen
			# försvinner (normalkartorna ligger kvar — vi byter bara filtrering, inte material).
			for mi in instans.find_children("*", "MeshInstance3D", true, false):
				for yta in mi.mesh.get_surface_count():
					var mat = mi.get_active_material(yta)
					if mat is StandardMaterial3D:
						var kopia: StandardMaterial3D = mat.duplicate()
						kopia.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
						kopia.anisotropy_1_enabled = true
						if kopia.normal_enabled:
							kopia.normal_scale = 1.8
						mi.set_surface_override_material(yta, kopia)
		var w := float(d.get("w", 5.0))
		var h := float(d.get("h", 4.2))
		var djup := float(d.get("d", 3.4))
		if str(d.get("id", "")) == "karta":
			continue
		# FÖNSTERLJUSET: en varm punkt framför fasaden, som ett upplyst fönster i mörkret.
		var lykta := OmniLight3D.new()
		lykta.position = Vector3(w * 0.18, minf(h * 0.35, 4.5), djup * 0.5 + 1.2)
		lykta.light_color = Color(1.0, 0.72, 0.36)
		lykta.light_energy = 1.1
		lykta.omni_range = 6.0
		hus.add_child(lykta)
		# VÄGEN UT (M228): Alex: *"Porten får gärna stå lite på glänt ... så man ser att det är en väg
		# ut ur byn"*. Portvalvet är genomgående, men på natten läser en mörk öppning som en stängd port.
		# En lykta på utsidan kastar ljus genom valvet, så öppningen syns och vägen ut blir läsbar.
		if str(d.get("id", "")) == "karta":
			var ute := OmniLight3D.new()
			ute.position = Vector3(0.0, 2.6, -djup * 0.5 - 2.6)
			ute.light_color = Color(1.0, 0.66, 0.34)
			ute.light_energy = 3.4
			ute.omni_range = 11.0
			hus.add_child(ute)

	# SJÄLVA PORTEN: träporten ur wooden-gate.zip, skalad till 5,0 m bred och 4,5 m hög, ställd där
	# karta-huset står och vänd mot torget.
	var portscen: PackedScene = load("res://assets/by/models/port.glb")
	if portscen != null:
		var port := portscen.instantiate()
		var pv := deg_to_rad(180.0)
		port.position = Vector3(sin(pv) * 25.6, 0.0, cos(pv) * 25.6)
		# Modellen har bredden langs Blender-Y, som blir -Z i Godot: ett kvarts varv sa porten vander
		# sin breda sida mot torget i stallet for att sta kant mot kant.
		port.rotation.y = pv + PI * 0.5
		port.scale = Vector3.ONE * 32.0
		# Materialet ur .blend-filen följer inte med i exporten (bara en tom Principled), så porten
		# kläs här med zip-filens egna bilder via modellens UV-karta.
		var port_mat := StandardMaterial3D.new()
		port_mat.albedo_texture = load("res://assets/by/texturer/port_albedo.png")
		port_mat.normal_enabled = true
		port_mat.normal_texture = load("res://assets/by/texturer/port_normal.png")
		port_mat.normal_scale = 1.4
		port_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		port_mat.roughness = 0.9
		for mi in port.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = port_mat
		värld.add_child(port)

	# KAMERAN i mitten, i ögonhöjd.
	_ring_kam = Camera3D.new()
	_ring_kam.position = Vector3(0.0, 4.0, 0.0)
	_ring_kam.rotation_degrees = Vector3(8.0, 0.0, 0.0)
	_ring_kam.fov = 75.0
	värld.add_child(_ring_kam)
	_bygg_landskap(värld)
	_bygg_rekvisita(värld)
	_bygg_himmel_dekor(värld)
	_ring_byggd = true

## Kameran tittar på plats i. Vinkeln räknas ur ringens delning, så byggnaden står rakt fram.
## Kameran står i mitten och VRIDER sig med `_rot` — mjukt mellan stegen, inte hackigt per byggnad.
func _ring_titta(i: int) -> void:
	if _ring_kam == null:
		return
	# KAMERAN TITTAR PÅ DET VALDA HUSETS EGET HUS (M224). Två fel låg bakom att etiketten och bilden
	# aldrig stämde: kameran räknade vinkel ur index i den FILTRERADE listan (som kan hoppa över hus),
	# och Godots kamera ser längs -Z medan husen står på +Z-sidan — alltså tittade den på huset mittemot
	# (mätt: THE SMITH i etiketten, porttornet i bilden). Nu slås vinkeln upp på husets id och kameran
	# vrids PI + vinkeln, som är riktningen till huset.
	var id := ""
	if i >= 0 and i < _synliga.size():
		id = str(PLATSER[int(_synliga[i])].get("skepp", ""))
	var mål: float = float(_vinkel_hus.get(id, 0.0)) + PI
	var skillnad: float = wrapf(mål - _kam_vinkel, -PI, PI)
	_kam_vinkel += skillnad * 0.25
	_ring_kam.rotation = Vector3(0.0, _kam_vinkel, 0.0)

## KARUSELLEN (M202). Alex: *"Det är ännu ingen karusell"*. Byggnaderna står på en RING kring
## kameran: vinkeln avgör var de hamnar i sidled, hur stora de är och hur mycket de vrids bort.
## Den valda står rakt fram (vinkel 0), grannarna vrids in mot mitten, de bakom är mindre och mörkare.
## Bredden krymper med cosinus för vinkeln — det är den som gör att en byggnad ser VRIDEN ut och inte
## bara flyttad.
func _rita_roterande(vp: Vector2) -> void:
	# 3D-RINGEN RITAS NÄR DEN FINNS (M203). M202 skrev över den här grenen med 2D-karusellen, så
	# vyn visade bildskivor fast 3D-scenen var byggd — mätt: `_ring_vp` fanns, men ritades aldrig.
	if _ring_vp != null:
		_ring_titta(_vald)
		draw_texture_rect(_ring_vp.get_texture(), Rect2(Vector2.ZERO, vp), false)
		_rita_remsa(vp)
		return
	# Himlen och marken: en lugn bakgrund som inte konkurrerar med byggnaderna.
	draw_rect(Rect2(0.0, 0.0, vp.x, marklinje()), _bakfärg(0.08))
	draw_rect(Rect2(0.0, marklinje(), vp.x, vp.y - marklinje()), _bakfärg(0.95))
	var n := PLATSER.size()
	var steg := TAU / float(n)
	var lista := []
	for i in n:
		var varv := fposmod(float(i) - _rot + float(n) * 0.5, float(n)) - float(n) * 0.5
		var vinkel := varv * steg
		if absf(vinkel) > PI * 0.72:
			continue                       # bakom kameran
		lista.append([cos(vinkel), i, vinkel])
	lista.sort_custom(func(a, b): return float(a[0]) < float(b[0]))   # bakt först
	for post in lista:
		var djup: float = float(post[0])          # 1 = rakt fram, -1 = rakt bakom
		var i: int = int(post[1])
		var vinkel: float = float(post[2])
		var tex := _byggnadstextur(i)
		if tex == null:
			continue
		var andel := (djup + 1.0) * 0.5           # 0..1
		var skala := lerpf(0.52, 1.0, andel)
		var h2 := vp.y * 0.60 * skala
		var förh := maxf(0.08, float(tex.get_width()) / float(tex.get_height()))
		# VRIDNINGEN: bredden krymper med cosinus, så huset viker sig bort från kameran.
		var w2 := h2 * förh * maxf(0.12, absf(cos(vinkel)))
		var x := vp.x * 0.5 + sin(vinkel) * vp.x * 0.46
		var ton := lerpf(0.42, 1.0, andel)
		# Skuggan under huset binder det till marken.
		draw_rect(Rect2(x - w2 * 0.55, marklinje() - 2.0, w2 * 1.10, maxf(2.0, vp.y * 0.012)),
			_a(Palett.c(0), 0.35 * andel))
		draw_texture_rect(tex, Rect2(x - w2 * 0.5, marklinje() - h2, w2, h2), false,
			Color(ton, ton, ton, 1.0))
	_rita_remsa(vp)

func _rita_remsa(vp: Vector2) -> void:
	var namn := Tr.t("ui.by.plats.%s" % str(PLATSER[_vald]["id"]), str(PLATSER[_vald]["namn"]))
	var status: String = status_text(_vald)
	var f := ThemeDB.fallback_font
	var remsa := maxf(46.0, vp.y * 0.10)
	draw_rect(Rect2(0.0, vp.y - remsa, vp.x, remsa), _a(Palett.c(1), 0.86))
	draw_rect(Rect2(0.0, vp.y - remsa, vp.x, 1.0), Palett.c(14))
	draw_string(f, Vector2(0.0, vp.y - remsa * 0.50), namn, HORIZONTAL_ALIGNMENT_CENTER, vp.x,
		int(vp.y * 0.042), Palett.c(14))
	draw_string(f, Vector2(0.0, vp.y - remsa * 0.16), status, HORIZONTAL_ALIGNMENT_CENTER, vp.x,
		int(vp.y * 0.030), _a(Palett.c(5), 0.9))

func _bar(vp: Vector2) -> void:
	draw_rect(Rect2(0.0, bar_topp(), vp.x, 40.0), Palett.c(1))
	draw_rect(Rect2(0.0, bar_topp(), vp.x, 1.0), Palett.c(14))
	draw_rect(Rect2(0.0, bar_topp() + 1.0, vp.x, 1.0), Palett.c(9))
	var cell := vp.x / float(maxi(1, _rader().size()))
	for i in _rader():
		var x := float(_kol(i)) * cell
		if i == _vald:
			draw_rect(Rect2(x + 1.0, bar_topp() + 2.0, cell - 2.0, 38.0), _a(Palett.c(4), 0.55))
		if i > 0:
			draw_rect(Rect2(x, bar_topp() + 3.0, 1.0, 34.0), Palett.c(3))
			draw_rect(Rect2(x + 1.0, bar_topp() + 3.0, 1.0, 34.0), Palett.c(2))

## Etiketterna med sin ruta, i VYNS koordinater: platsens namn och statusraden i sin cell, och
## ledtråden över hela bredden. `_draw` ritar bara bilden, husen och listen — orden ritas i
## FÖNSTRETS upplösning (se ui_text.gd), och det är den här listan provet i ui/textprov.gd mäter.
func etiketter() -> Array:
	var vp := _vy()
	var f := ThemeDB.fallback_font
	var cell := vp.x / float(maxi(1, _rader().size()))
	var namn := []
	var status := []
	for i in PLATSER.size():
		# Platsens namn ur språkfilen, med namnet i PLATSER som reserv: en ny plats syns med sitt
		# namn även innan någon har översatt den.
		namn.append(Tr.t("ui.by.plats.%s" % str(PLATSER[i]["id"]), str(PLATSER[i]["namn"])))
		status.append(status_text(i))
	# Den största storlek som ryms i cellen för DET HÄR språket (tyskan är längst, japanskan kortast):
	# en fast storlek klipper tyskan eller lämnar japanskan onödigt liten. 4 px luft — en rad som är
	# bredare än sin ruta klipps av draw_string.
	var storlek := UiText.storlek_som_ryms(namn + status, cell - 4.0, 9, 12, HORIZONTAL_ALIGNMENT_CENTER)
	# Baslinjerna räknas ur fontens EGNA mått: en större font får inte hamna i knät på raden ovanför.
	var bas1 := bar_topp() + 3.0 + f.get_ascent(storlek)
	var bas2 := bas1 + f.get_descent(storlek) + 3.0 + f.get_ascent(storlek)
	var rader := []
	for i in PLATSER.size():
		var x := float(i) * cell
		rader.append(UiText.rad(namn[i], Vector2(x, bas1), storlek,
			Palett.c(14) if i == _vald else Palett.c(8), cell, HORIZONTAL_ALIGNMENT_CENTER, "bar",
			Palett.c(1)))
		if status[i].is_empty() or i >= _status.size():
			continue
		rader.append(UiText.rad(status[i], Vector2(x, bas2), storlek,
			Palett.c(13) if bool(_status[i]["ljus"]) else Palett.c(5), cell,
			HORIZONTAL_ALIGNMENT_CENTER, "bar", Palett.c(1)))
	# HOVRINGENS NAMN (M122): namnet på huset man pekar på, i husets egen bredd. Egen grupp — raden
	# finns bara när pekaren är över ett hus, och proven hovrar aldrig.
	if _hover >= 0:
		var r := byggnad_rect(_hover)
		var hnamn: String = namn[_hover]
		var bredd: float = clampf(maxf(r.size.x, 70.0), 70.0, vp.x - 8.0)
		var hx: float = clampf(r.get_center().x - bredd * 0.5, 4.0, vp.x - bredd - 4.0)
		var hy: float = clampf(r.position.y + 13.0, 13.0, bar_topp() - 14.0)
		rader.append(UiText.rad(hnamn, Vector2(hx, hy),
			UiText.storlek_som_ryms([hnamn], bredd - 6.0, 10, 14, HORIZONTAL_ALIGNMENT_CENTER),
			Palett.c(14), bredd, HORIZONTAL_ALIGNMENT_CENTER, "hovring", Palett.c(1)))
	# LEDTRÅDEN LIGGER OVANFÖR LISTEN. Alex 16/10: *"listningen över var man befinner sig, och att det
	# ligger text mitt mellan dem, det ser förjävligt ut"*. Baslinjen var hårdkodad till 264, alltså
	# INNE i listen (som går från `bar_topp()` = 85 % av höjden och 40 px ner, till vyns botten), och
	# därmed rakt över platsernas statusrader. Nu 6 px ovanför listen i stället, med luft kvar till
	# hovringsetiketten (som högst når 14 px ovanför).
	var hint := Tr.t("ui.by.hint", "← → välj plats · Enter = gå in · L = språk · Q = avsluta")
	rader.append(UiText.rad(hint, Vector2(0.0, bar_topp() - 6.0),
		UiText.storlek_som_ryms([hint], vp.x - 8.0, 9, 12, HORIZONTAL_ALIGNMENT_CENTER),
		Palett.c(7), vp.x, HORIZONTAL_ALIGNMENT_CENTER, "hint", Palett.c(1)))
	return rader

## En ellips som polygon: skuggor är ellipser, inte cirklar — en cirkel på en gata läses som en boll.
func _ellips(p: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var v := TAU * float(i) / 12.0
		pts.append(p + Vector2(cos(v) * rx, sin(v) * ry))
	return pts


## LANDSKAPET (M209): gräsplan ut till dimman, en ring av granar och bergsryggar bakom, så byn står i
## ett landskap i stället för på en skiva med en hård kant. Allt i lågpoly och spelets färger.
func _bygg_landskap(värld: Node3D) -> void:
	var äng := MeshInstance3D.new()
	var planmesh := PlaneMesh.new()
	planmesh.size = Vector2(200.0, 200.0)
	äng.mesh = planmesh
	var planmat := StandardMaterial3D.new()
	planmat.albedo_color = Color(0.15, 0.21, 0.16)
	planmat.roughness = 1.0
	äng.material_override = planmat
	äng.position = Vector3(0.0, -0.02, 0.0)
	värld.add_child(äng)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	_bygg_skog(värld)

	# SKYDDSMUREN (M211): Alex: *"lägg hellre en mur i bakgrunden, så det känns som man är skyddad i
	# byn"*. En ring av mursten bakom husen, med en mörkare krönrad, så byn ligger inom murar.
	# MURVARIATION (M225): Alex: *"muren behöver ha lite variation"*. Tre stenmaterial i rotation,
	# höjd- och lutningsvariation per sektion och en mörkare ton då och då, så muren inte är 64 likadana
	# klossar. Samma sak ger fogarna liv när SSAO och glöd är på.
	# MUREN (M233). Alex: *"Muren ser forjavlig ut ... ser inte ut som en mur med de texturerna, och
	# alla vaggar som anvander samma textur: Byt"*. Forsta versionen var 64 likadana ladA med en textur
	# skalad 2x — det laser som tapet, inte mur. Nu byggs muren av ENSKILDA STENAR i skift: 5 kurser per
	# sektion, 2-3 stenar per kurs, slumpad bredd, djup, ton och ett av tva stenmaterial. Kronraden
	# ligger ovanpa och foljer sektionens hojd.
	var sten_tex: Array[Texture2D] = [
		load("res://assets/tiles/material/fortified_stone_bricks.png"),
		load("res://assets/tiles/material/ancient_stone.png"),
	]
	# NORMALMAPS (M234): Alex: *"vad hände med att sätta på normalmapping, så det ger det hela lite liv,
	# någon för ljuset att landa på och skapa skuggor?"*. Stenmaterialen hade ingen normalmap alls —
	# tools/gen_normal.py ritar dem ur albedon (Sobel), så fogar och stensprång får riktning i ljuset.
	var sten_norm: Array[Texture2D] = [
		load("res://assets/tiles/material/fortified_stone_bricks_normal.png"),
		load("res://assets/tiles/material/ancient_stone_normal.png"),
	]
	var murrng := RandomNumberGenerator.new()
	murrng.seed = 991
	const KURSER := 5
	const KURSHOJD := 0.84
	# MUREN TAR SLUT VID PORTEN (M236): Alex: *"att muren tar stop på varsin sida om den gaten"*.
	# Sektioner inom 9 grader av portens vinkel (180 grader, huset karta) hoppas över.
	var port_vinkel := deg_to_rad(180.0)
	for i in 64:
		var vinkel3 := TAU * float(i) / 64.0
		if absf(wrapf(vinkel3 - port_vinkel, -PI, PI)) < deg_to_rad(9.0):
			continue
		var mitt := Vector3(sin(vinkel3) * 26.0, 0.0, cos(vinkel3) * 26.0)
		var sidled := Vector3(cos(vinkel3), 0.0, -sin(vinkel3))
		var mur := Node3D.new()
		mur.position = mitt
		mur.rotation.y = vinkel3
		värld.add_child(mur)
		for kurs in KURSER:
			var x := -1.45
			var förskjutning := 0.0 if kurs % 2 == 0 else 0.5   # förband: varannan kurs förskjuten
			x += förskjutning
			while x < 1.45:
				var bredd := murrng.randf_range(0.38, 1.25)
				if murrng.randf() < 0.05:                        # enstaka saknad sten (mörk ficka)
					x += bredd + 0.02
					continue
				var sten := MeshInstance3D.new()
				var låda := BoxMesh.new()
				var höjd := KURSHOJD * murrng.randf_range(0.86, 1.06)
				var djup := 0.92 + murrng.randf_range(-0.05, (0.12 if murrng.randf() < 0.12 else 0.04))
				låda.size = Vector3(minf(bredd, 1.45 - x), höjd - 0.03, djup)
				sten.mesh = låda
				sten.position = Vector3(x + bredd * 0.5, kurs * KURSHOJD + höjd * 0.5, murrng.randf_range(-0.03, 0.03))
				var mm := StandardMaterial3D.new()
				var vilken := murrng.randi_range(0, 1)
				mm.albedo_texture = sten_tex[vilken]
				mm.normal_enabled = true
				mm.normal_texture = sten_norm[vilken]
				mm.normal_scale = murrng.randf_range(1.0, 1.8)
				mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				# Skalan ar i stenar per meter, inte i varv: en sten ska vara en sten, inte en tapetruta.
				mm.uv1_scale = Vector3(murrng.randf_range(0.8, 1.5), murrng.randf_range(0.8, 1.5), 1.0)
				mm.uv1_offset = Vector3(murrng.randf(), murrng.randf(), 0.0)
				mm.roughness = 0.95
				var ton := murrng.randf_range(0.62, 1.0)
				mm.albedo_color = Color(ton, ton * murrng.randf_range(0.97, 1.03), ton * 0.96)
				sten.material_override = mm
				mur.add_child(sten)
				x += bredd + 0.02
		# KRÖNET: en mörkare, sammanhängande stenrad ovanpå, så muren får en avslutning.
		var krön := MeshInstance3D.new()
		var krönbox := BoxMesh.new()
		krönbox.size = Vector3(2.92, 0.34, 1.06)
		krön.mesh = krönbox
		krön.position = Vector3(0.0, KURSER * KURSHOJD + 0.17, 0.0)
		var km2 := StandardMaterial3D.new()
		km2.albedo_texture = sten_tex[0]
		km2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		km2.uv1_scale = Vector3(2.5, 0.6, 1.0)
		km2.albedo_color = Color(0.45, 0.45, 0.46)
		krön.material_override = km2
		mur.add_child(krön)

	# BERGSKEDJOR (M218): Alex: *"Bergen får inte vara pyramider, de måste se ut som berg"*. Två
	# ryggar med midpunktsförflyttning — en riktig kam med toppar och sadlar, inte koner.
	_bergskedja(värld, 190.0, 22.0, 58.0, Color(0.16, 0.19, 0.28), 11)
	_bergskedja(värld, 155.0, 10.0, 40.0, Color(0.20, 0.24, 0.34), 23)


## REKVISITA (M213): Alex: *"sätt ut lite tunnor, något städ vid smeden, barbord utanför tavernan.
## Helt enkelt inreda inne i byn så det ser bebott ut."* Pjäserna är Quaternius fantasyprylar (CC0) som
## ligger i game/assets/by/rekvisita. De ställs utifrån varje hus vinkel, så de hamnar där huset står.
func _bygg_rekvisita(värld: Node3D) -> void:
	var data: Dictionary = {}
	var fil := FileAccess.open("res://data/by.json", FileAccess.READ)
	if fil != null:
		data = JSON.parse_string(fil.get_as_text())
		fil.close()
	var radie := float(data.get("radie", 18.0))
	# Möbleringen per hus: [namn, avstånd från byns mitt, sidled]. Avståndet räknas in mot torget,
	# så pjäserna hamnar framför fasaden och inte inuti huset.
	var möblering := {
		"smed": [["Workbench", 4.2, -2.6], ["Anvil", 3.4, -1.3], ["Anvil_Log", 4.6, -1.7], ["Whetstone", 3.2, 0.5],
				 ["WeaponStand", 4.4, 1.9], ["Barrel", 3.8, 2.7], ["Bucket_Wooden_1", 3.4, -0.2],
				 ["Crate_Wooden", 5.2, -3.3], ["Torch_Metal", 2.8, -3.5], ["Torch_Metal", 2.8, 3.2]],
		"vardshus": [["Table_Large", 3.9, -2.3], ["Chair_1", 3.3, -2.7], ["Chair_1", 4.5, -1.9],
					 ["Table_Plate", 3.9, -1.5], ["Mug", 4.2, -1.2], ["Bench", 3.7, 1.7],
					 ["Stool", 3.1, 2.5], ["Barrel_Apples", 4.7, 2.9], ["Cauldron", 4.9, -3.1],
					 ["Banner_1", 3.0, 0.5]],
		"tradet": [["Stall_Empty", 3.7, -1.9], ["Crate_Wooden", 4.5, -2.5], ["Barrel", 3.5, 1.7],
				   ["Chest_Wood", 4.3, 2.3], ["Bottle_1", 3.2, 0.4], ["Banner_1", 3.0, 0.9]],
		"juvelerare": [["Table_Large", 3.5, -1.3], ["CandleStick_Stand", 3.1, 0.5], ["Chest_Wood", 4.1, 1.5],
					   ["Pot_1", 3.3, 2.1], ["Crate_Metal", 4.6, -2.4]],
		"karta": [["Torch_Metal", 3.1, -2.5], ["Torch_Metal", 3.1, 2.5], ["Banner_2", 4.1, -3.1],
				  ["Crate_Wooden", 4.5, 3.1], ["Dummy", 4.7, 1.7], ["Barrel", 4.0, 3.6]],
		"avsluta": [["Barrel", 3.1, -1.5], ["Crate_Metal", 4.1, 1.3], ["Pot_1", 3.4, 1.9]],
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for hus_data in data.get("hus", []):
		var d: Dictionary = hus_data
		var lista = möblering.get(str(d.get("id", "")), [])
		var vinkel := deg_to_rad(float(d.get("vinkel", 0.0)))
		for post in lista:
			var scen: PackedScene = load("res://assets/by/rekvisita/%s.gltf" % str(post[0]))
			if scen == null:
				push_warning("saknar pjäs: " + str(post[0]))
				continue
			var pjäs := scen.instantiate()
			var avstånd := radie - float(post[1])
			var sidled := float(post[2])
			pjäs.position = Vector3(sin(vinkel) * avstånd + cos(vinkel) * sidled, 0.0,
					cos(vinkel) * avstånd - sin(vinkel) * sidled)
			pjäs.rotation.y = vinkel + PI + rng.randf_range(-0.25, 0.25)
			pjäs.scale = Vector3.ONE * rng.randf_range(0.95, 1.2)
			värld.add_child(pjäs)
	# BRUNNEN (M221): mitt på torget, vid sidan om kameran så den syns när man vrider mellan husen.
	var brunn: PackedScene = load("res://assets/by/models/brunn.glb")
	if brunn != null:
		var b := brunn.instantiate()
		b.position = Vector3(sin(deg_to_rad(90.0)) * 7.0, 0.0, cos(deg_to_rad(90.0)) * 7.0)
		b.rotation.y = deg_to_rad(90.0)
		värld.add_child(b)
	print("rekvisita: utplacerad")


## SKOGEN (M215): Stylized Nature MegaKit, sex trädmodeller som instansieras i ringen.
func _bygg_skog(värld: Node3D) -> void:
	var modeller: Array[PackedScene] = []
	for namn in ["Pine_1", "Pine_2", "Pine_3", "CommonTree_1", "CommonTree_2", "CommonTree_3"]:
		var scen: PackedScene = load("res://assets/by/trad2/%s.gltf" % namn)
		if scen != null:
			modeller.append(scen)
	if modeller.is_empty():
		push_warning("Inga trädmodeller hittades i assets/by/trad2")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	for i in 90:
		var vinkel := TAU * float(i) / 90.0 + rng.randf_range(-0.05, 0.05)
		# Inga träd framför porten (180 grader): de skymde öppningen i vyn.
		if absf(wrapf(vinkel - PI, -PI, PI)) < deg_to_rad(11.0):
			continue
		var radie := rng.randf_range(30.0, 56.0)
		var träd := modeller[rng.randi_range(0, modeller.size() - 1)].instantiate()
		träd.scale = Vector3.ONE * rng.randf_range(1.15, 1.95)
		träd.rotation.y = rng.randf_range(0.0, TAU)
		träd.position = Vector3(sin(vinkel) * radie, 0.0, cos(vinkel) * radie)
		värld.add_child(träd)
	print("skog: ", 90, " träd ur ", modeller.size(), " modeller")


## MÅNE, STJÄRNOR OCH MOLN (M217): Alex: *"nu saknas det några fina berg, lite moln, en måne, stjärnor"*.
## Allt är enkla noder med `disable_fog`, så de syns genom dimman — himlen ska inte dränkas av markdimman.
func _bygg_himmel_dekor(värld: Node3D) -> void:
	# MÅNEN: en blek skiva högt uppe, unshaded så den inte påverkas av byns ljus.
	var måne := MeshInstance3D.new()
	var kula := SphereMesh.new()
	kula.radius = 11.0
	kula.height = 22.0
	kula.radial_segments = 20
	kula.rings = 10
	måne.mesh = kula
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.93, 0.94, 0.88)
	mm.disable_fog = true
	måne.material_override = mm
	måne.position = Vector3(-150.0, 105.0, -300.0)
	värld.add_child(måne)
	# STJÄRNORNA: ett gäng små kuber på himlavalvet, i ett MultiMesh (ett draw call).
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	var mmesh := MultiMesh.new()
	mmesh.transform_format = MultiMesh.TRANSFORM_3D
	mmesh.mesh = BoxMesh.new()
	var antal := 260
	mmesh.instance_count = antal
	for i in antal:
		var vinkel := rng.randf_range(0.0, TAU)
		var höjd := rng.randf_range(0.10, 0.95)
		var riktning := Vector3(cos(vinkel) * sqrt(1.0 - höjd * höjd), höjd, sin(vinkel) * sqrt(1.0 - höjd * höjd))
		var storlek := rng.randf_range(0.7, 1.9)
		mmesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * storlek), riktning * 320.0))
	var stjärnor := MultiMeshInstance3D.new()
	stjärnor.multimesh = mmesh
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.82, 0.86, 0.95)
	sm.disable_fog = true
	stjärnor.material_override = sm
	värld.add_child(stjärnor)
	# MOLNEN: kluster av små lådor, inte en enda stor skiva — en skiva läses som en glasskiva.
	for i in 12:
		var v := rng.randf_range(0.0, TAU)
		var kluster := Node3D.new()
		kluster.position = Vector3(cos(v) * rng.randf_range(110.0, 230.0), rng.randf_range(72.0, 118.0), sin(v) * rng.randf_range(110.0, 230.0))
		värld.add_child(kluster)
		for j in rng.randi_range(4, 7):
			var puff := MeshInstance3D.new()
			var låda := BoxMesh.new()
			låda.size = Vector3(rng.randf_range(16.0, 34.0), rng.randf_range(7.0, 13.0), rng.randf_range(14.0, 26.0))
			puff.mesh = låda
			var molnmat := StandardMaterial3D.new()
			molnmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			molnmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			molnmat.albedo_color = Color(0.62, 0.67, 0.80, 0.16)
			molnmat.disable_fog = true
			puff.material_override = molnmat
			puff.position = Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(-6.0, 6.0), rng.randf_range(-24.0, 24.0))
			kluster.add_child(puff)


## BERG (M218): en kam runt hela vyn, byggd av en profil med midpunktsförflyttning (då blir topparna
## ojämna och hamnar på olika avstånd, som en riktig bergskedja). Unshaded, ingen dimma — silhuett.
func _bergskedja(värld: Node3D, radie: float, bas: float, topp: float, färg: Color, frö: int) -> void:
	const ANTAL := 384
	var rng := RandomNumberGenerator.new()
	rng.seed = frö
	var profil := PackedFloat32Array()
	profil.resize(ANTAL)
	# Mjuk kam: summa av få sinusar ger breda toppar och sadlar. Midpunktsförflyttning gav nålar
	# (mätt: profilen varierade för mycket mellan närliggande punkter), alltså lågfrekvent i stället.
	var fas := [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
	for i in ANTAL:
		var v := TAU * float(i) / float(ANTAL)
		profil[i] = 0.50 \
			+ 0.26 * sin(v * 3.0 + fas[0]) \
			+ 0.16 * sin(v * 7.0 + fas[1]) \
			+ 0.08 * sin(v * 13.0 + fas[2]) \
			+ 0.05 * sin(v * 29.0 + fas[3])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ANTAL:
		var j := (i + 1) % ANTAL
		var v0 := TAU * float(i) / float(ANTAL)
		var v1 := TAU * float(j) / float(ANTAL)
		var h0 := bas + (topp - bas) * clampf(profil[i], 0.0, 1.0)
		var h1 := bas + (topp - bas) * clampf(profil[j], 0.0, 1.0)
		var r0 := radie + sin(v0 * 3.0 + float(frö)) * 8.0
		var p0 := Vector3(sin(v0) * r0, h0, cos(v0) * r0)
		var b0 := Vector3(sin(v0) * r0, -6.0, cos(v0) * r0)
		var p1 := Vector3(sin(v1) * r0, h1, cos(v1) * r0)
		var b1 := Vector3(sin(v1) * r0, -6.0, cos(v1) * r0)
		st.add_vertex(b0); st.add_vertex(p0); st.add_vertex(p1)
		st.add_vertex(b0); st.add_vertex(p1); st.add_vertex(b1)
	var berg := MeshInstance3D.new()
	berg.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = färg
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	berg.material_override = mat
	värld.add_child(berg)
