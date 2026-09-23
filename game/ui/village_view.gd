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
class_name VillageView
extends Control

## Platsen man valde och gick in i. `skepp` är skalets läge (main.gd), inte en egen sorts plats.
signal vald(skepp: String)

const BILD := "res://assets/ui/byn.png"

## Platserna i gatuordning (vänster → höger, som bilden visar dem): `x` är platsens mitt på BILDEN i
## procent av bredden, och `färg` är märkets ton ur paletten.
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
	{"id": "tradet", "namn": "THREAD OF DESTINY", "skepp": "trad", "x": 8.5, "färg": 1},
	{"id": "smed", "namn": "BLACKSMITH", "skepp": "smed", "x": 22.5, "färg": 12},
	{"id": "vardshus", "namn": "THE TAVERN", "skepp": "vardshus", "x": 40.0, "färg": 13},
	{"id": "karta", "namn": "THE GATE", "skepp": "karta", "x": 53.5, "färg": 25},
	{"id": "juvelerare", "namn": "JEWELER", "skepp": "juvelerare", "x": 69.0, "färg": 30},
	# EXIT-skylten i bilden (längst till höger) stänger spelet. Alex: "Exit på bilden behöver vara
	# till att avsluta spelet." Den är ingen skärm i skalet — `_på_plats` i main.gd känner igen
	# "avsluta" och avslutar, och provet mot SKAL_LÄGEN hoppar över just den här platsen.
	{"id": "avsluta", "namn": "EXIT", "skepp": "avsluta", "x": 80.5, "färg": 14},
]
const MÄRKE := Vector2(20.0, 26.0)   ## märkets ruta: klickytan, och den ruta provet mäter krockar med
const DJUP := 6.0                    ## märkets skugga i sidled (provet räknar in den i krockmåttet)
const MARKLINJE := 168.0             ## gatan i bilden: märkenas nederkant (62 % av vyns 270 px)
const GATA := 172.0
const BAR := 196.0                   ## etikettlistens överkant
const GUPP := [0, 1, 2, 1]           ## markörens gupp i fyra bildrutor: pixelkonst hackar, den glider inte
## Hur fort panoreringen stannar: 1 - exp(-fart * delta). Låg fart = lång, mjuk förflyttning.
const PAN_FART := 8.0
## Var i bildens HÖJD gatan ligger, i procent: märkena ställs på gatans linje, och bilden skjuts i
## höjdled så att den linjen hamnar på MARKLINJE. Utan det står märkena i himlen på en panoramabild
## som är 2,5 gånger bredare än hög.
const BILDENS_GATA := 78.0

var _vald := 0
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
	mouse_filter = Control.MOUSE_FILTER_STOP      # byn tar emot klick (märkena är klickbara)
	_pan = _mål_pan(_vald)                        # bilden står vid den valda platsen från start
	_pan_mål = _pan
	set_process(true)
	textlager = UiText.fäst(self)

func _exit_tree() -> void:
	# Lagret ligger i FÖNSTRET (annars vore orden uppskalade igen): det måste bort med vyn.
	if textlager != null:
		textlager.frigör()

## Byns bild. Saknas filen ritas en mörk platta i stället: en by utan bild ska synas som en tom scen,
## inte som en krasch — och märkena går fortfarande att välja.
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
	return Vector2(_plats_x(i) - _pan, MARKLINJE - MÄRKE.y / 2.0)

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

## Märkets ruta på skärmen: klickytan, och den ruta provet mäter krockar i. Samma ruta som `_märke`
## ritar ur — två ställen hade glidit isär.
func hus_rect(i: int) -> Rect2:
	return Rect2(plats_px(i) - MÄRKE / 2.0, MÄRKE)

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
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in PLATSER.size():
		# Rutan vidgas några pixlar: man klickar på märket, inte på ett provrör.
		if hus_rect(i).grow(6.0).has_point(m.position):
			gå_in(i)
			return

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
		draw_rect(Rect2(0.0, BAR - 8.0 + float(k), vp.x, 1.0), _a(Palett.c(0), 0.10 * float(k)))
	_bar(vp)
	for i in PLATSER.size():
		_märke(i)
	_markör()

## Bilden: EN ruta, flyttad i sidled och skjuten i höjdled så att gatulinjen hamnar på MARKLINJE.
## Ingen remsa, ingen avbildning, ingen faktor — det finns ingenting kvar som kan dra i pixlarna, och
## det var hela poängen: Alex blev åksjuk av varje form av uttöjning.
func _bilden(vp: Vector2, bild: Texture2D) -> void:
	var mål := bild_storlek()
	draw_texture_rect_region(bild,
		Rect2(-_pan, MARKLINJE - mål.y * BILDENS_GATA / 100.0, mål.x, mål.y),
		Rect2(0.0, 0.0, float(bild.get_width()), float(bild.get_height())))

## Orden i FÖNSTRETS upplösning (se ui_text.gd). Vyn ritar bara bilden, märkena och listen — så
## pixelkonsten är kvar i vyns mått medan bokstäverna ritas skarpa i fönstret.
func _ord() -> void:
	if textlager != null:
		textlager.sätt(etiketter())

func _vy() -> Vector2:
	return Vector2(size.x if size.x > 0.0 else 480.0, size.y if size.y > 0.0 else 270.0)

## En färg ur paletten med genomskinlighet. Ljuset ritas som fläckar med alfa — det finns ingen
## ljuskälla i en ritad scen, så fläcken ÄR ljuset.
func _a(c: Color, alfa: float) -> Color:
	return Color(c.r, c.g, c.b, alfa)

## Ett platsmärke: en nål i platsens färg med mörk kontur, en skugga på gatan och en ljusblänk. Den
## VALDA nålen är större och har en glöd — markeringen är det man letar efter i bilden.
func _märke(i: int) -> void:
	if not synlig(i):
		return
	var p := plats_px(i)
	var f: Color = Palett.c(int(PLATSER[i]["färg"]))
	var vald := i == _vald
	var r := 7.0 if vald else 5.5
	# Skuggan på gatan: utan den svävar nålen över bilden.
	draw_colored_polygon(_ellips(Vector2(p.x, MARKLINJE + 1.0), r + 2.0, 2.5), _a(Palett.c(0), 0.35))
	if vald:
		for k in 3:
			draw_circle(p, r + 4.0 + float(k) * 2.0 + float(GUPP[_ram]), _a(Palett.c(13), 0.07))
	draw_circle(p, r + 1.5, Palett.c(1))
	draw_circle(p, r, f)
	draw_circle(Vector2(p.x - r * 0.3, p.y - r * 0.35), r * 0.35, f.lightened(0.45))
	# Spetsen: nålen står PÅ gatan.
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 2.0, p.y + r - 1.0),
		Vector2(p.x + 2.0, p.y + r - 1.0), Vector2(p.x, MARKLINJE)]), Palett.c(1))
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 1.0, p.y + r - 2.0),
		Vector2(p.x + 1.0, p.y + r - 2.0), Vector2(p.x, MARKLINJE - 1.0)]), f.darkened(0.2))

## Markörens ram: märket med sju px marginal. Egen funktion för att provet ska kunna mäta att ramen
## ryms i vyn — en markering som sticker ut över kanten syns bara på bild.
func markör_ram() -> Rect2:
	return hus_rect(_vald).grow(7.0)

## Markeringen: en platta i guld på gatan under märket och en pil ovanför som guppar. En hel ram runt
## huset skar rakt igenom bilden (granskningen av den gamla byn: "the selection rectangle cuts
## straight through building art") — markeringen ska peka ut platsen, inte skära i den.
func _markör() -> void:
	var ytter := markör_ram()
	var mitt := plats_px(_vald).x
	# Plattan: platsen står PÅ den valda rutan. Tre pixlar guld med en mörk kant runt om.
	var platta := Rect2(ytter.position.x + 3.0, MARKLINJE + 2.0, ytter.size.x - 6.0, 4.0)
	draw_rect(platta.grow(1.0), Palett.c(1))
	draw_rect(platta, Palett.c(14))
	draw_rect(Rect2(platta.position + Vector2(2.0, 1.0), Vector2(platta.size.x - 4.0, 1.0)), Palett.c(13))
	# Pilen: en spets med skaft, mörk kant runt om, som guppar med bildrutan.
	var y := ytter.position.y - 14.0 + float(GUPP[_ram])
	draw_colored_polygon(PackedVector2Array([
		Vector2(mitt - 8.0, y), Vector2(mitt + 8.0, y), Vector2(mitt, y + 10.0)]), Palett.c(1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(mitt - 6.0, y + 1.0), Vector2(mitt + 6.0, y + 1.0), Vector2(mitt, y + 8.0)]),
		Palett.c(14))

## Etikettlisten längst ned: en mörk list med en guldkant och en ruta per plats. Texten står I
## listen — över en bild med hus och gata drunknar den i kullerstenen (granskningen av den gamla
## byn: "text unreadable over busy terrain").
func _bar(vp: Vector2) -> void:
	draw_rect(Rect2(0.0, BAR, vp.x, 40.0), Palett.c(1))
	draw_rect(Rect2(0.0, BAR, vp.x, 1.0), Palett.c(14))
	draw_rect(Rect2(0.0, BAR + 1.0, vp.x, 1.0), Palett.c(9))
	var cell := vp.x / float(PLATSER.size())
	for i in PLATSER.size():
		var x := float(i) * cell
		if i == _vald:
			draw_rect(Rect2(x + 1.0, BAR + 2.0, cell - 2.0, 38.0), _a(Palett.c(4), 0.55))
		if i > 0:
			draw_rect(Rect2(x, BAR + 3.0, 1.0, 34.0), Palett.c(3))
			draw_rect(Rect2(x + 1.0, BAR + 3.0, 1.0, 34.0), Palett.c(2))

## Etiketterna med sin ruta, i VYNS koordinater: platsens namn och statusraden i sin cell, och
## ledtråden över hela bredden. `_draw` ritar bara bilden, märkena och listen — orden ritas i
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
	var bas1 := BAR + 3.0 + f.get_ascent(storlek)
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
