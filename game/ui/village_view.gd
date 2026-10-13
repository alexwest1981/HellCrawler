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
##   * den VALDA platsen: guldram runt hela byggnaden + en platta på gatan,
##   * den man HOVRAR över: en varm ljusvägg som tonar nedåt huset, och husets namn ovanför.
##
## Klickytan är samma ruta — man klickar på huset man ser, inte på en prick bredvid det. `hus_rect`
## (den kompakta rutan kring platsens punkt) finns kvar som INVARIANT för provet: två platsers punkter
## får inte krocka. Den är också träffyta i reserv, för ett hus vars kropp ligger utanför vyn.
class_name VillageView
extends Control

## Platsen man valde och gick in i. `skepp` är skalets läge (main.gd), inte en egen sorts plats.
signal vald(skepp: String)

const BILD := "res://assets/ui/byn.png"

## Platserna i gatuordning (vänster → höger, som bilden visar dem): `x` är platsens mitt på BILDEN i
## procent av bredden, `x0`/`x1` är HUSETS KROPP i procent av bildens bredd (klickytan och det som
## märks, M122) och `färg` är platsens ton ur paletten.
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
	{"id": "tradet", "namn": "THREAD OF DESTINY", "skepp": "trad", "x": 8.5, "x0": 2.0, "x1": 15.0, "färg": 1},
	{"id": "smed", "namn": "BLACKSMITH", "skepp": "smed", "x": 22.5, "x0": 14.0, "x1": 31.0, "färg": 12},
	{"id": "vardshus", "namn": "THE TAVERN", "skepp": "vardshus", "x": 40.0, "x0": 32.0, "x1": 48.0, "färg": 13},
	{"id": "karta", "namn": "THE GATE", "skepp": "karta", "x": 53.5, "x0": 45.0, "x1": 62.0, "färg": 25},
	{"id": "juvelerare", "namn": "JEWELER", "skepp": "juvelerare", "x": 69.0, "x0": 63.0, "x1": 75.0, "färg": 30},
	# EXIT-skylten i bilden (längst till höger) stänger spelet. Alex: "Exit på bilden behöver vara
	# till att avsluta spelet." Den är ingen skärm i skalet — `_på_plats` i main.gd känner igen
	# "avsluta" och avslutar, och provet mot SKAL_LÄGEN hoppar över just den här platsen.
	{"id": "avsluta", "namn": "EXIT", "skepp": "avsluta", "x": 80.5, "x0": 75.0, "x1": 86.0, "färg": 14},
]
const MÄRKE := Vector2(20.0, 26.0)   ## platsens PUNKT-ruta: invarianten provet mäter (och klick i reserv)
const DJUP := 6.0                    ## platsens skugga i sidled (provet räknar in den i krockmåttet)
## Husets ÖVERKANT i procent av bildens höjd. Taken i Alex' bild ligger på 7–11 % av höjden (MÄTT:
## den första raden som avviker från himlens färg i varje hus' spann), och ramen och ljusväggen ska
## täcka huset — inte himlen ovanför det. 9 % ligger mitt i det spannet.
const HUS_TOPP := 9.0
## Hur högt upp på huset ljusväggen når, i andelar av husets höjd: ljuset kommer NEDIFRÅN, som från en
## lykta på gatan, och tonar ut uppåt.
const LJUS_DJUP := 0.45
## Gatan och listen ligger på ANDELAR av vyns höjd, inte på fasta px (M113). Alex, i byn: *"Detta är
## inte en by i helskärm..."* — scenen tog 62 % av höjden och listen 27 %. Med 0,78 och 0,86 fyller
## bilden hela höjden (dess gatulinje ligger på 78 % av bildens höjd, se BILDENS_GATA) och listen
## blir ett TUNT ÖVERLÄGG i nederkanten (14 %): MÄTT 1896x1018 före 62 %, efter 100 % scen.
## Konstanterna nedan är DESIGNMÅTTET vid 270 px — samma tal som förr, och bara till för provet.
const MARKLINJE := 168.0             ## gatan i designmåttet (270 px hög vy)
const GATA := 172.0
const BAR := 196.0                   ## etikettlistens överkant i designmåttet
const GUPP := [0, 1, 2, 1]           ## markörens gupp i fyra bildrutor: pixelkonst hackar, den glider inte
## Hur fort panoreringen stannar: 1 - exp(-fart * delta). Låg fart = lång, mjuk förflyttning.
const PAN_FART := 8.0
## Var i bildens HÖJD gatan ligger, i procent: märkena ställs på gatans linje, och bilden skjuts i
## höjdled så att den linjen hamnar på MARKLINJE. Utan det står märkena i himlen på en panoramabild
## som är 2,5 gånger bredare än hög.
const BILDENS_GATA := 78.0

var _vald := 0
## Platsen muspekaren står över, eller -1. Sätts på musens RÖRELSE i `_gui_input` och ritas som en
## ljusvägg på huset + husets namn ovanför.
var _hover := -1
## Bildens vänsterkant i vyns koordinater (logiska px). Panoreringen är en förflyttning och inte en
## vinkel: den kan stanna mitt i, och i ändarna tar den slut.
var _pan := 0.0
var _pan_mål := 0.0                  ## dit panoreringen är på väg; `_process` glider dit (aldrig ett hopp)
var _status: Array = []              ## [{text, ljus}] per plats — det som står under namnet i listen
var _t := 0.0
var _ram := 0                        ## bildrutan i guppet; ritas bara om när den byter
var _tex: Texture2D = null           ## byns bild, läst en gång
var textlager: UiText                ## orden, ritade i FÖNSTRETS upplösning (se ui_text.gd)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP      # byn tar emot klick (husen är klickbara)
	_pan = _mål_pan(_vald)                        # bilden står vid den valda platsen från start
	_pan_mål = _pan
	set_process(true)
	textlager = UiText.fäst(self)
	# Pekaren lämnar vyn: hovringen ska inte ligga kvar på ett hus man inte längre pekar på.
	mouse_exited.connect(_släpp_hovring)

func _exit_tree() -> void:
	# Lagret ligger i FÖNSTRET (annars vore orden uppskalade igen): det måste bort med vyn.
	if textlager != null:
		textlager.frigör()

func _släpp_hovring() -> void:
	if _hover != -1:
		_hover = -1
		queue_redraw()

## Byns bild. Saknas filen ritas en mörk platta i stället: en by utan bild ska synas som en tom scen,
## inte som en krasch — och husen går fortfarande att välja.
func byscen() -> Texture2D:
	if _tex == null and ResourceLoader.exists(BILD):
		_tex = load(BILD)
	return _tex

## Fyll statusraderna ur metat. Anropas varje gång skärmen visas: guld och framsteg ändras av
## körningen, och en gammal siffra på markeringen är en lögn om spelarens läge.
func visa(meta: Meta, antal_banor: int) -> void:
	# Vyn kan ha fått sin storlek sedan förra gången (fönstret ändras): panoreringen räknas om mot den
	# valda platsen, annars står markeringen snett i vyn.
	_pan = _mål_pan(_vald)
	_pan_mål = _pan
	_hover = -1
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
	queue_redraw()

func valt_index() -> int:
	return _vald

## Platsen muspekaren står över (-1 = ingen). Egen funktion för att provet ska kunna bevisa att
## hovringen träffar rätt HUS — och att den släpps när pekaren lämnar vyn.
func hovrad() -> int:
	return _hover

## Släpp hovringen. Kopplad till `mouse_exited` OCH anropad av provet (en vymus i ett prov ger inget
## mouse_exited), så regeln finns på ett ställe.
func släpp_hovring() -> void:
	_släpp_hovring()

## Statusraden under en plats namn. Egen funktion (i stället för `_status` direkt) för att provet ska
## kunna mäta att varje plats har en rad — en plats utan status ritar en tom rad, och en tom rad
## under ett namn ser ut som ett fel.
func status_text(i: int) -> String:
	if i < 0 or i >= _status.size():
		return ""
	return str(_status[i]["text"])

## Bildens mått i VYNS koordinater. Hela höjden syns och bredden följer bildens eget förhållande —
## det är "originalsize": ingen förstoring, ingen skevhet. En 3232x1312-bild blir 665x270 logiska px
## i en 480x270-vy, alltså 185 px att panorera i sidled.
func bild_storlek() -> Vector2:
	var vp := _vy()
	var bild := byscen()
	if bild == null or bild.get_height() <= 0:
		return vp
	return Vector2(vp.y * float(bild.get_width()) / float(bild.get_height()), vp.y)

## Platsens x i BILDENS koordinater (logiska px från bildens vänsterkant), ur dess procent.
func _plats_x(i: int) -> float:
	return bild_storlek().x * float(PLATSER[i]["x"]) / 100.0

## Husets ruta i VYNS px (M122): den målade byggnadens kropp ur `x0`/`x1`, klippt mot vyn. Klickytan,
## ramen och ljusväggen räknas ur SAMMA ruta — två rutor hade glidit isär, och då klickar man på ett
## hus och märker ett annat. En tom ruta betyder att huset ligger utanför vyn.
func byggnad_rect(i: int) -> Rect2:
	if i < 0 or i >= PLATSER.size():
		return Rect2()
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
func _mål_pan(i: int) -> float:
	var vp := _vy()
	return clampf(_plats_x(i) - vp.x * 0.5, 0.0, maxf(0.0, bild_storlek().x - vp.x))

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
	var nästa := _vald + (1 if dir.x > 0 else -1)
	# Stopp i ändarna, som förut: en panorering som viker runt skulle fara från bildens ena kant till
	# den andra i ett svep, och det är precis den sortens kast Alex inte tål.
	if nästa < 0 or nästa >= PLATSER.size():
		return false
	_vald = nästa
	_pan_mål = _mål_pan(_vald)
	queue_redraw()
	return true

## Panorera till den valda platsen direkt, utan glid. Provet (och en skärmbild) behöver ett vaket
## läge utan att vänta på bildrutor, och spelet använder samma väg när vyn visas på nytt.
func pan_klart() -> void:
	_pan = _pan_mål
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
	var skepp := str(PLATSER[_vald]["skepp"])
	vald.emit(skepp)
	return skepp

## Platsens kompakta PUNKT-ruta. Provet mäter den (två platsers punkter får inte krocka), och den är
## träffyta i reserv: ett hus vars kropp ligger nästan helt utanför vyn har ingen ruta kvar att klicka
## i, men punkt-rutan står alltid vid gatulinjen.
func hus_rect(i: int) -> Rect2:
	return Rect2(plats_px(i) - MÄRKE / 2.0, MÄRKE)

## Vilken plats ligger under pekaren? Husets EGEN ruta först — man klickar på byggnaden man ser — och
## punkt-rutan i reserv. -1 = inget hus.
func plats_vid(p: Vector2) -> int:
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
	if absf(_pan_mål - _pan) > 0.05:
		_pan = lerpf(_pan, _pan_mål, 1.0 - exp(-PAN_FART * delta))
		if absf(_pan_mål - _pan) <= 0.05:
			_pan = _pan_mål
		queue_redraw()
	# Orden sätts HÄR, inte i `_draw`: lagret ligger i fönstret och måste ha raderna innan bildrutan
	# ritas (annars står den första bildrutan tom).
	_ord()

func _gui_input(event: InputEvent) -> void:
	# HOVRINGEN (M122): vilket hus pekaren står över. Läses på musens RÖRELSE, och vyn ritas bara om
	# när platsen BYTS — en ommålning per musrörelse vore en ommålning per bildruta.
	if event is InputEventMouseMotion:
		var ny := plats_vid((event as InputEventMouseMotion).position)
		if ny != _hover:
			_hover = ny
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
		return
	# Klicket går på SAMMA ruta som hovringen: huset man ser är knappen.
	var träff := plats_vid(m.position)
	if träff >= 0:
		gå_in(träff)

# --- ritningen ---------------------------------------------------------------
func _draw() -> void:
	var vp := _vy()
	var bild := byscen()
	if bild != null:
		_bilden(vp, bild)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Palett.c(1))
	# En mörk ton nedtill, tonad i åtta steg: etiketterna ska läsas mot en lugn yta, inte mot
	# kullerstenen — och en rak kant mellan bilden och listen läses som en skarv.
	for k in 8:
		draw_rect(Rect2(0.0, bar_topp() - 8.0 + float(k), vp.x, 1.0), _a(Palett.c(0), 0.10 * float(k)))
	_bar(vp)
	# Husen SIST av scenen: den valda ramen och hovringens ljusvägg ligger ovanpå bilden. Ingen
	# cirkel ritas i den här vyn — kloten är borta (M122).
	for i in PLATSER.size():
		_hus(i)

## Bilden: EN ruta, flyttad i sidled och skjuten i höjdled så att gatulinjen hamnar på MARKLINJE.
## Ingen remsa, ingen avbildning, ingen faktor — det finns ingenting kvar som kan dra i pixlarna, och
## det var hela poängen: Alex blev åksjuk av varje form av uttöjning.
func _bilden(vp: Vector2, bild: Texture2D) -> void:
	var mål := bild_storlek()
	draw_texture_rect_region(bild,
		Rect2(-_pan, marklinje() - mål.y * BILDENS_GATA / 100.0, mål.x, mål.y),
		Rect2(0.0, 0.0, float(bild.get_width()), float(bild.get_height())))

## Orden i FÖNSTRETS upplösning (se ui_text.gd). Vyn ritar bara bilden, husen och listen — så
## pixelkonsten är kvar i vyns mått medan bokstäverna ritas skarpa i fönstret.
func _ord() -> void:
	if textlager != null:
		textlager.sätt(etiketter())

func _vy() -> Vector2:
	return Vector2(size.x if size.x > 0.0 else 480.0, size.y if size.y > 0.0 else 270.0)

## Gatulinjen i vyns px: 78 % av höjden, alltså samma andel av BILDEN som ligger över gatan
## (BILDENS_GATA). Då fyller bilden hela höjden kant i kant.
func marklinje() -> float:
	return _vy().y * 0.78

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

## HUSET MÄRKS (M122), inte en prick bredvid det. Den valda platsen får en guldram runt hela
## byggnaden och en platta på gatan; huset man hovrar över får en varm ljusvägg nedifrån och en
## ljusram. Ljuset kommer NEDIFRÅN (lyktan på gatan), därför tonar väggen ut uppåt.
func _hus(i: int) -> void:
	var r := markör_ram() if i == _vald else byggnad_rect(i)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var vald := i == _vald
	var hovrad := i == _hover
	if not vald and not hovrad:
		return
	# Ljusväggen: åtta remsor med stigande alfa nedåt. Ingen cirkel och ingen boll — det är husets
	# egen yta som lyser.
	var band: float = r.size.y * LJUS_DJUP / 8.0
	for k in 8:
		var t := float(k) / 7.0
		var alfa := (0.10 if vald else 0.13) * (0.35 + 0.65 * t)
		draw_rect(Rect2(r.position.x, r.end.y - band * float(k + 1), r.size.x, band),
			_a(Palett.c(13), alfa))
	# Ramen: två px, i guld för den valda och i en ljusare ton för hovringen.
	draw_rect(r, Palett.c(14) if vald else Palett.c(13), false, 2.0)
	if not vald:
		return
	# Plattan på gatan: den valda platsen står PÅ den. Fyra px guld med en mörk kant runt om, lika
	# bred som huset — den gamla plattan var 20 px bred och hörde till det lilla märket.
	var platta := Rect2(r.position.x, marklinje() + 2.0, r.size.x, 4.0)
	draw_rect(platta.grow(1.0), Palett.c(1))
	draw_rect(platta, Palett.c(14))
	draw_rect(Rect2(platta.position + Vector2(2.0, 1.0), Vector2(platta.size.x - 4.0, 1.0)), Palett.c(13))
	# Guppet: ett litet märke i plattans mitt som andas, så markeringen syns röra sig även när bilden
	# står still (det gamla guppet satt i pilen ovanför märket).
	var mitt := platta.get_center().x
	var b: float = 6.0 + float(GUPP[_ram]) * 2.0
	draw_rect(Rect2(mitt - b / 2.0, platta.end.y + 1.0, b, 2.0), Palett.c(1))
	draw_rect(Rect2(mitt - b / 2.0 + 1.0, platta.end.y + 1.0, b - 2.0, 1.0), Palett.c(14))

## Etikettlisten längst ned: en mörk list med en guldkant och en ruta per plats. Texten står I
## listen — över en bild med hus och gata drunknar den i kullerstenen (granskningen av den gamla
## byn: "text unreadable over busy terrain").
func _bar(vp: Vector2) -> void:
	draw_rect(Rect2(0.0, bar_topp(), vp.x, 40.0), Palett.c(1))
	draw_rect(Rect2(0.0, bar_topp(), vp.x, 1.0), Palett.c(14))
	draw_rect(Rect2(0.0, bar_topp() + 1.0, vp.x, 1.0), Palett.c(9))
	var cell := vp.x / float(PLATSER.size())
	for i in PLATSER.size():
		var x := float(i) * cell
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
	var cell := vp.x / float(PLATSER.size())
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
	var hint := Tr.t("ui.by.hint", "← → välj plats · Enter = gå in · L = språk · Q = avsluta")
	rader.append(UiText.rad(hint, Vector2(0.0, 264.0),
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
