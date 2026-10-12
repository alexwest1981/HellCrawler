class_name TreeView
extends Control

## Trädet som EGEN VY (M94). Alex: *"Trädet skall vara en egen vy, och det skall vara ikoner, med text
## när man hovrar över en ikon."*
##
## CONTROL, INTE PANELCONTAINER (M95). Första versionen ärvde PanelContainer, och en Container ÄGER
## sin storlek — den krymper till sitt innehåll och struntar i den size som skalet sätter. Följden
## syntes på Alex' skärmbild: rutnätet hade ingen bredd, så de fjorton ikonerna lade sig på EN rad
## högst upp i en svart ruta. Byns och kartans vyer ärver Control och sätter sin size själva; trädet
## gör nu samma sak, och panelen inuti fyller den ytan.
##
## Formen är grenarna lodrätt och nivåerna vågrätt: fyra kolumner (Järnvägen, Benknippet, Glöden,
## Girigheten) och sex rader (nivå 1 längst upp, kronan nederst). Inuti en ruta står den grenens
## noder på den nivån sida vid sida — 22 px per ikon, för med fyra kolumner och upp till fem noder
## per ruta blir raden 460 px i en 480 px vy. Det är samma räkning som bänken och trädikonerna: rita
## i den storlek ytan faktiskt har.
##
## Ikonen är grenens (8 bilder räcker — nivån syns på HUR DEN LYser, inte på att den byter bild).
## Färgen är tillståndet: släckt metall = låst, blek = köpbar, varm = fullt uppgraderad. Det är
## samma information som vyn hade i text förut, men läst i ett svep i stället för rad för rad.
##
## Texten kommer när muspekaren vilar på en ikon: namn, vad den ger, rang och pris — och när den inte
## går att köpa står skälet där, från metan (samma rad som butiken hade).

## OÄNDLIG TRÄDRYMD (M96). Alex: *"Jag vill att vi bygger ett oändligt skill tree där jag kan enkelt
## lägga till fler noder och bara peka vidare ju mer jag utvecklar spelet. Just nu är spelet låst i
## den nuvarande formen."*
##
## Förr VAR plattan världen: nio rader i en bild, och en nod som inte fick plats i dem hade ingen
## plats alls. Nu är x och y trädets EGNA koordinater i andelar som får växa förbi 0..1 — plattan är
## en bild som ligger i rymden (0..1 = dess kant), inte rymdens kant. Vyn visar ett UTSNITT av rymden,
## och panorering och zoom flyttar utsnittet. Plattans 75 uppmätta sockets gäller fortfarande; en nod
## utan socket får sin plats av rutnätet nedan, som fortsätter förbi plattan i stället för att sluta
## vid den.
##
## RYMDEN RITAS I ETT PAR FUNKTIONER: `_ur_bild` (trädandel -> pixel) och `till_bild` (tillbaka).
## Panoreringen och zoomen bor i dem, alltså följer varje nod, varje ring, varje koppling och
## trädeditorns markör med automatiskt — ingen annan räknar pixlar själv.
##
## Formen är grenarna i kolumner och nivåerna i rader. Inuti en ruta står den grenens noder på den
## nivån sida vid sida.
##
## SEDAN M100 är formen en SPIRAL UR MITTEN: grenarna är spiralens armar, nivån är avståndet utåt.
## Se konstanterna nedan.
##
## Ikonen är grenens (8 bilder räcker — nivån syns på HUR DEN LYser, inte på att den byter bild).
## Färgen är tillståndet: släckt metall = låst, blek = köpbar, varm = fullt uppgraderad. Det är
## samma information som vyn hade i text förut, men läst i ett svep i stället för rad för rad.
##
## Texten kommer när muspekaren vilar på en ikon: namn, vad den ger, rang och pris — och när den inte
## går att köpa står skälet där, från metan (samma rad som butiken hade).

## GRENARNA LÄSES UR DATAT (M96). Förr stod de tre i en konstant, och en nod vars `branch` inte stod
## där försvann TYST ur vyn — den fanns i datat och gick att köpa via metan, men syntes inte. Nu blir
## varje grennamn i datat en egen kolumn, i den ordning det dyker upp.
const FILNAMN := {
	"Järnvägen": "jarnvagen", "Benknippet": "benknippet", "Glöden": "gloden",
}
## Nivåerna kommer ur DATAT, inte ur en konstant: konstanten nedan är bara ett golv för en tom fil.
const HÖGSTA := 6

## ETT NODTRÄD SOM ÄR EN SPIRAL UR MITTEN (M100/M101). Alex skickade en bildserie med spiraler: *"Jag
## tänker mig mer som 3 st spiraler som utgår från centrum, runt varandra så man konstant arbetar sig
## utåt i spiralen från de 3 olika armarna."* Grenarna är spiralens tre ARMAR, och DJUPET är avståndet
## utåt — inte en rad nedåt. Sedan M101: *"De behöver ligga mer separerade, det måste vara luft mellan
## noderna och linjerna som ansluter till dem. Det gör inget alls om man får pan'a över hela kartan
## med musen. Huvudnoderna kan ligga tätare mot varandra, sen sprid ut dem mer."*
##
## BÅGEN ÄR KONSTANT, VINKELN ÄR INTE. Vinkeln per nivå är `SPIRAL_BUE / radien`, alltså ligger två
## nivåer LIKA långt ifrån varandra hela vägen ut (mätt: 56-62 px mot 48-152 px med en fast vinkel per
## nivå). Spiralen varvar därför tätt i mitten och allt långsammare utåt.
##
## SPÅREN LIGGER PÅ ÖMSE SIDOR om armens mittlinje (`SPIRAL_LED`), så huvudnoden — som är ensam på sin
## nivå — hamnar PÅ linjen och de två syskonen gafflar ut på var sin sida. Låg båda spåren utanför
## linjen klev det inre spåret in i nivån innanför.
##
## KOPPLINGARNA RITAS SOM BÅGAR genom trädrymden (`_båge`), inte som raka linjer: en rak linje mellan
## två nivåer skar rakt genom nästa arms noder (mätt: 13 px in i en nod), för bågen mellan två nivåer
## är ~59 px medan noderna är 26 px.
##
## En nod vars socketpost har `pin` ligger där den ligger (handplacerad i trädeditorn) — alla andra
## följer spiralen. Rymden är samma som förut: andelar, oändlig, panorering och zoom.
const MITT := Vector2(0.5, 0.5)  ## spiralens mitt i trädrymden
const SPIRAL_R0 := 0.28        ## armens startradie: grenens huvudnod
const SPIRAL_DRAD := 0.08      ## radietillväxt per nivå
const SPIRAL_BUE := 0.22       ## bågen mellan två nivåer, i andelar: vinkeln per nivå = BUE / radien
const SPIRAL_LED := 0.16       ## spårens avstånd: de två syskonen ligger 0,16 andelar (43 px) isär


## Grennamnen ur DATAT, i den ordning de dyker upp. En ny gren (noder med ett nytt `branch`) blir en
## egen kolumn utan att koden rörs.
func _grenar() -> Array:
	var ut: Array = []
	if _meta == null:
		return ut
	for d in _meta.defs:
		var g := str(d.get("branch", ""))
		if not g.is_empty() and not ut.has(g):
			ut.append(g)
	return ut


## Grenens ikonfil: den egna om den finns, annars den första grenens. En gren utan egen ikon skall
## inte bli en osynlig nod — den ritas med ett lån tills någon ritar dess egen.
func _grenikon(gren: String) -> String:
	var första: String = str(_grenlista[0]) if not _grenlista.is_empty() else ""
	for namn in [str(FILNAMN.get(gren, "")), str(FILNAMN.get(första, ""))]:
		if namn.is_empty():
			continue
		if ResourceLoader.exists("res://assets/tree/%s.png" % namn):
			return namn
	return "eld"

var _ikoner := {}                  ## id -> TextureRect
var _rader := {}                   ## id -> Dictionary (gren, nivå, def)
var _rubrik: Label
var _högsta := HÖGSTA               ## antal nivåer i datat, räknat i visa()
var _snäpp := {}                   ## id -> {x, y, r} ur game/data/trad_sockets.json (mätta sockets)
var _nodplan: Control
var _info: Label
var _ritare: Control
var _meta: Meta
var _grenlista: Array = []          ## grennamnen i datats ordning (M96)
## UTSNITTET (M96). Zoomen och panoreringen bor i _ur_bild/till_bild och ingen annanstans, alltså
## följer noderna, ringarna, kopplingarna och trädeditorns markör med utan att veta om dem.
var _zoom := 1.0
var _pan := Vector2.ZERO
## Har någon själv zoomat eller panorerat? Då får vyn INTE rätta sig själv: den som valt ett utsnitt
## skall behålla det. Är trädet orört visar visa() hela trädet på en gång — MÄTT före M97: ett träd på
## 16 nivåer rymdes inte i vyn, och en spelare som öppnade trädet såg bara de sju översta raderna.
var _rörd := false
var _drar := false                  ## höger (eller mitten) nere: musen panorerar
const ZOOM_MIN := 0.25
const ZOOM_MAX := 3.0

static func _släckt() -> Color:
	return Color(0.42, 0.40, 0.46)

static func _köpbar() -> Color:
	return Color(1, 1, 1)

## Köpt men inte maxad: inre glöd, ljuset hålls innanför ramen. Steg 2 i Alex' bild.
static func _köpt() -> Color:
	return Color(0.92, 0.72, 0.42)

## GRENFÄRGERNAS METALL (M95). Referensbilden har grenar i koppar, guld och stål; våra fyra får var
## sin metall, så en gren går att känna igen på färgen och inte bara på ikonen.
const GREN_FÄRG := {
	"Järnvägen": Color(0.62, 0.68, 0.78),      # stål
	"Benknippet": Color(0.80, 0.76, 0.66),     # ben
	"Glöden": Color(0.85, 0.42, 0.24),         # glöd
	"Girigheten": Color(0.86, 0.70, 0.28),     # guld
}
const SOCKET_R := 11.0                        ## socketens radie: klotet ar 22 px i diameter
const SOCKET := Color(0.21, 0.20, 0.22)         ## fattningens kropp: aldrad metall
const SOCKET_SKUGGA := Color(0.08, 0.08, 0.09)   ## urgravd insida, skuggan nedtill
const KARNA := Color(0.11, 0.11, 0.13)           ## klotet nar noden ar last
const LJUSBLANK := Color(0.60, 0.58, 0.64)       ## blanken i overkant
const NIT := Color(0.34, 0.32, 0.36)             ## nitarna runt ringen
const JÄRN := Color(0.16, 0.15, 0.17)          ## kall gjutjärn: låst nod
const JÄRN_LJUS := Color(0.42, 0.40, 0.44)     ## öppen men orörd
const GULD := Color(0.98, 0.84, 0.44)          ## full uppgraderad, som referensens gyllene kedja

static func _mättad() -> Color:
	return Color(1.0, 0.88, 0.62)     # varm: grenen är fylld


func _ready() -> void:
	_bygg()


## Byggs på ett ställe och kan kallas om: _refresh_shell kan köra innan barnets _ready har hunnit
## (skalet sätter sin vy under sin egen uppstart), och då finns ingen Rubrik att sätta text i.
func _bygg(läs_fil: bool = true) -> void:
	if _info != null:
		return
	custom_minimum_size = Vector2(456, 0)
	var ram := PanelContainer.new()
	ram.name = "Ram"
	ram.set_anchors_preset(Control.PRESET_FULL_RECT)
	ram.add_theme_stylebox_override("panel", _panel_stil())
	# RAMEN TAR INGEN MUS (M96): den är bara en bakgrund, och en Control som sväljer klicket hindrar
	# vyns egen panorering (allt utom ikonerna ligger under den). Utan det här nådde högerdrag och
	# hjul aldrig fram till _gui_input.
	ram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ram)
	var box := VBoxContainer.new()
	ram.add_child(box)

	var rubrik := Label.new()
	rubrik.name = "Rubrik"
	_rubrik = rubrik
	box.add_child(rubrik)

	# SOCKETDATA. Filen skrivs av trädeditorn (för hand: game/editor/trad_editor.gd) och läses här.
	# Formatet ägs av TreeSockets, så vyn och editorn kan inte glida ifrån varandra. Posten bär det en
	# människa lagt till — kryss, krav, klass, ikon — och en plats bara om noden dragits (`pin`).
	if läs_fil:
		_snäpp = TreeSockets.load_all()

	# Nodlagret: en fri yta (INTE en container) — noderna sitter på sina platser i trädrymden, och en
	# container hade lagt dem i sin egen ordning i stället.
	_nodplan = Control.new()
	_nodplan.name = "Noder"
	_nodplan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nodplan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nodplan)

	_ritare = Ritar.new()
	_ritare.vy = self
	add_child(_ritare)

	_info = Label.new()
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)


## Vyns yta, med ett golv för en vy som ännu inte fått sin storlek.
func _yta() -> Vector2:
	var yta: Vector2 = size
	if yta.x < 8.0 or yta.y < 8.0:
		yta = Vector2(480, 270)
	return yta


## En andel i pixlar: trädets enhet ritas i vyhöjden gånger zoomen. (Talet hette "plattans sida" när en
## bild var trädets måttstock; enheten står kvar, bilden är borta sedan M97.)
func _sida() -> float:
	return _yta().y * _zoom


## EN PUNKT I TRÄDRYMMEN TILL PIXLAR — den ENDA platsen som vet om zoom och panorering. x = 0 och x = 1
## är trädets två ytterkanter (plattans, när den fanns: rutnätet lägger grenarna inom samma intervall),
## och y räknas uppifrån. Värden utanför 0..1 är giltiga; det är där ett växande träd fortsätter.
func _ur_bild(x: float, y: float) -> Vector2:
	var yta: Vector2 = _yta()
	return Vector2(yta.x * 0.5 + (x - 0.5) * _sida(), y * _sida()) + _pan


func _panel_stil() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# TÄT (M118): samma regel som `Main._panel_style` — en panel över vyn släpper inte igenom något.
	sb.bg_color = Color(0.05, 0.05, 0.08)
	sb.border_color = Color(0.45, 0.48, 0.60)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	return sb


## Bygger om rutan ur metan. Anropas när vyn öppnas och efter varje köp — allt som visas kommer
## därifrån, så vyn kan inte hamna i otakt med sparfilen.
## `läs_fil = false` behåller socketposterna som redan ligger i minnet. Trädeditorn använder det: den
## bygger om vyn efter att ha lagt till eller tagit bort en nod, och får inte tappa de placeringar som
## ännu inte sparats (filen är sanningen för spelaren, minnet för den som redigerar).
func visa(meta: Meta, titel: String, läs_fil: bool = true) -> void:
	_bygg(läs_fil)
	_meta = meta
	_rubrik.text = titel
	for barn in _ikoner.values():
		# remove_child FÖRST — samma fälla som hos juveleraren: en andra visa() i samma bildruta
		# mätte annars de gamla ikonerna också och nodlagret växte för varje omritning.
		_nodplan.remove_child(barn)
		barn.queue_free()
	_ikoner.clear()
	_rader.clear()

	_högsta = HÖGSTA
	_grenlista = _grenar()
	# NIVÅN UR DATAT, MED EN RESERVVÄG (M95). De 88 noderna från generatorn bär `tier`. De 25 äldre
	# noderna gör inte det — och `def.get("tier", 1)` gjorde då ALLA till nivå 1, vilket är exakt vad
	# mätningen visade: 25 ikoner på samma y (31 px) i en rad 811 px bred i en 480 px vy.
	# Reservvägen räknar nodens plats i sin egen gren: datat står i kedjeordning (requires pekar
	# bakåt), så den nionde noden i en gren är grenens nionde steg. Samma tal, ur samma källa som
	# låsningen — den som lägger noder i fel ordning får fel nivå, och det syns direkt.
	var sloträknare := {}
	var räknare := {}
	var steg := {}
	var antal := {}                 ## "gren|nivå" -> antal noder, så syskonen kan fördelas kring spåret
	for d in meta.defs:
		var g := str(d.get("branch", ""))
		if g.is_empty():
			continue
		räknare[g] = int(räknare.get(g, 0)) + 1
		_högsta = maxi(_högsta, int(d.get("tier", räknare[g])))
		steg[str(d.get("id", ""))] = mini(_högsta, räknare[g])
		var n: int = int(d.get("tier", räknare[g]))
		antal["%s|%d" % [g, n]] = int(antal.get("%s|%d" % [g, n], 0)) + 1

	for def in meta.defs:
		var gren: String = def.get("branch", "")
		# GATEN ÄR "HAR NODEN EN GREN", inte "står grenen i en lista i koden" (M96): en fjärde gren
		# blev förut en nod som fanns i datat, gick att köpa och inte syntes.
		if gren.is_empty():
			continue
		var nivå: int = int(def.get("tier", 0))
		if nivå < 1:
			nivå = int(steg.get(str(def.get("id", "")), 1))
		var plats: int = int(sloträknare.get("%s|%d" % [gren, nivå], 0))
		sloträknare["%s|%d" % [gren, nivå]] = plats + 1
		var id: String = def["id"]
		var ikon := TextureRect.new()
		ikon.name = id
		# Grafiken: nodens egen (vald i editorn) om den har en, annars grenens ikon. Kronringen hör
		# till grenens slut och finns bara för grenikonerna — en iskristall blir inte krona av att
		# ligga sist, så filen måste finnas först.
		var ikonnamn: String = TreeSockets.graphics_of(def, _grenikon(gren))
		var med_krona: String = "%s_krona" % ikonnamn
		if nivå >= _högsta and ResourceLoader.exists("res://assets/tree/%s.png" % med_krona):
			ikonnamn = med_krona
		ikon.texture = load("res://assets/tree/%s.png" % ikonnamn)
		# INGEN custom_minimum_size: den pinnade ikonen. Sätts den en gång (här, vid skapandet) kan
		# storleken aldrig bli mindre efteråt — layouten håller kvar golvet, och trädeditorns L såg ut
		# att inte göra något alls (mätt: 22 px före och 22 px efter ett klassbyte). Storleken sätts i
		# stället explicit i placera_om/sätt_radie, ur klassens radie.
		ikon.custom_minimum_size = Vector2.ZERO
		# Utan detta vinner texturEN:s egen storlek (32 px) över custom_minimum_size, och ikonen
		# blev större än sin socket — mätt: 32 px ikon i en 22 px socket. Noden skall vara klotet.
		ikon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ikon.mouse_filter = Control.MOUSE_FILTER_PASS
		ikon.mouse_entered.connect(_peka.bind(id))
		# UT. En ikon hade ingen mouse_exited, så den SISTA nodens rad stod kvar efter att pekaren
		# lämnat den — hovringen såg död ut. Raden töms när pekaren lämnar just den nod som visas.
		ikon.mouse_exited.connect(_peka_bort.bind(id))
		ikon.gui_input.connect(_klick.bind(id))
		# NODEN SOM EN PLATS I RYMDEN, inte som en pixel. Att räkna pixelpositioner en gång och
		# behålla dem var felet: vyn får sin storlek EFTER att noderna skapats, och i ett annat fönster
		# låg varje klot kvar där det räknades för den gamla storleken (mätt av provet: en nod gav
		# bildandel -0,39 i stället för 0,05). Nu sparas andelen, och pixlarna räknas om varje gång
		# vyn får en ny storlek — av placera_om(), på ett ställe.
		var sock: Dictionary = _snäpp.get(id, {})
		# KLASSEN: den valda om någon valt (trädeditorns L), annars nivåns egen trappa. Storleken ÄR
		# klassens radie hela vägen — inget annat räknar pixlar.
		var klass: String = TreeSockets.size_of(sock, nivå)
		var r_kvar: float = TreeSockets.radius_of({"size": klass})
		var fx: float
		var fy: float
		if TreeSockets.pinned(sock):
			# HANDPLACERAD (trädeditorn): människan slår rutnätet, annars vore drag meningslöst.
			fx = float(sock["x"])
			fy = float(sock["y"])
		else:
			# SPIRALEN (M100/M101): armen, nivåns vinkel och spåret i sidled. Se konstanterna ovan.
			var gren_nr: int = maxi(0, _grenlista.find(gren))
			var antal_grenar: int = maxi(1, _grenlista.size())
			var ålder: float = float(maxi(0, nivå - 1))
			var nyckel: String = "%s|%d" % [gren, nivå]
			var syskon: int = maxi(1, int(antal.get(nyckel, 1)))
			# SPÅRET: syskonen ligger på ömse sidor om armens mittlinje, så en ensam nod (huvudnoden)
			# hamnar PÅ linjen och de två leden gafflar ut på var sin sida.
			var sida: float = float(plats) - (float(syskon) - 1.0) * 0.5
			# VINKELN FÖLJER BÅGEN: vinkeln per nivå är SPIRAL_BUE / radien, alltså ligger två nivåer
			# lika långt ifrån varandra hela vägen ut i stället för allt längre (mätt på bild: 56-62 px
			# mot 48-152 px med en fast vinkel per nivå).
			var vinkel: float = TAU * float(gren_nr) / float(antal_grenar)
			for i in range(int(ålder)):
				vinkel += SPIRAL_BUE / (SPIRAL_R0 + float(i) * SPIRAL_DRAD)
			var radie: float = SPIRAL_R0 + ålder * SPIRAL_DRAD + sida * SPIRAL_LED
			fx = MITT.x + cos(vinkel) * radie
			fy = MITT.y + sin(vinkel) * radie
		var post: Dictionary = sock
		post["id"] = id
		post["x"] = fx
		post["y"] = fy
		post["r"] = r_kvar
		post["size"] = klass
		_snäpp[id] = post
		_nodplan.add_child(ikon)
		_ikoner[id] = ikon
		_rader[id] = {"gren": gren, "nivå": nivå, "def": def}

	placera_om()
	uppdatera()
	# Ramarna och rören ritas i _draw och behöver rutornas VERKLIGA läge: containrarna lägger ut sina
	# barn först i slutet av bildrutan, och en ritning som sker innan dess lägger alla ramar i hörnet
	# (mätt: inga ramar och inga rör syntes alls). En bildruta väntas därför in, och ritningen begärs
	# om — samma skäl som gör att ett prov inte kan mäta layouten.
	await get_tree().process_frame
	placera_om()
	# NATURLIG STORLEK FRÅN BÖRJAN (M99), på spelarens front, så länge ingen valt ett utsnitt själv.
	# `F` (centrera) visar hela trädet när som helst. Alex: *"Inzoomat."*
	if not _rörd:
		visa_front()


## Tillstånden är fyra, inte tre. Alex' stegbild visar dem i ordning: låst (död metall), köpt (inre
## glöd, ljuset hålls innanför ramen), maxad (energin BRYTER ramen — aura utanför) och kronan
## (störst, högst upp). Färgen bär tillståndet; texten kommer vid hovring.
func uppdatera() -> void:
	for id in _ikoner:
		var ikon: TextureRect = _ikoner[id]
		var rank: int = _meta.rank(id)
		var max_rank: int = int(_meta.def_for(id).get("max_rank", 1))
		if rank > 0 and rank >= max_rank:
			ikon.modulate = _mättad()          # maxad: varm, och rutan runt om lyser i vyn
		elif rank > 0:
			ikon.modulate = _köpt()            # köpt: inre glöd, ingen aura
		elif _meta.requires_met(id):
			ikon.modulate = _köpbar()          # öppen men orörd
		else:
			ikon.modulate = _släckt()          # låst: död metall


## Ritaren (M95): en tunn Control som ligger ÖVERST i vyn och ritar ramar och rör.
##
## Varför en egen klass: en Controls _draw hamnar UNDER dess barn, och panelen inuti vyn har en nästan
## opak bakgrund — ramarna ritades alltså och försvann bakom den (mätt: inga ramar och inga rör syntes
## trots att koden körde). Den här läggs som sista barn och ritar ovanpå allt, och den ritar samma sak
## som vyn räknar ut.
class Ritar:
	extends Control

	var vy: TreeView

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE     # klick går till ikonerna under
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if vy != null:
			vy._rita(self)


## EN KANT GENOM TRÄDRYMMEN (M101): punkterna följer spåret mellan föräldern och barnet i stället för
## att gå rakt. Den raka linjen skar genom nästa arms noder — mätt: linjen från en nod på nivå 9 till
## sin förälder gick 13 px IN i en nod på nivå 3 i en annan arm. Skälet är att bågen mellan två nivåer
## är ~59 px medan noderna är 26 px: en rak linje är ett korda som skär in i grannskapet. Bågen håller
## sig i sin egen arms spår, där ingen annan nod finns.
## Ändpunkterna är nodernas MITTPUNKTER; _rita kortar bort den del som ligger inne i kloten.
func _båge(från: String, till: String) -> PackedVector2Array:
	var ut := PackedVector2Array()
	var a: Dictionary = _snäpp.get(från, {})
	var b: Dictionary = _snäpp.get(till, {})
	if not (a.has("x") and b.has("x")):
		return ut
	var pa: Vector2 = Vector2(float(a["x"]), float(a["y"])) - MITT
	var pb: Vector2 = Vector2(float(b["x"]), float(b["y"])) - MITT
	var ra: float = pa.length()
	var rb: float = pb.length()
	var va: float = atan2(pa.y, pa.x)
	var vb: float = atan2(pb.y, pb.x)
	# KORTASTE VÄGEN I VINKEL: annars ritas ett helt varv baklänges när två nivåer ligger på var sin
	# sida om 0 grader.
	var dv: float = wrapf(vb - va, -PI, PI)
	var steg: int = 16
	for i in range(steg + 1):
		var t: float = float(i) / float(steg)
		var v: float = va + dv * t
		var r: float = ra + (rb - ra) * t
		ut.append(_ur_bild(MITT.x + cos(v) * r, MITT.y + sin(v) * r))
	return ut


## KOPPLINGAR OCH RINGAR (M96). Kopplingarna är nodernas EGNA krav: en linje per `requires`, alltså
## samma kant som låset läser. Förut ritades en stång per gren mellan nivåerna, och den band trädet
## till plattans sex rader — en nod på nivå tolv hade fått sin stång ritad mot en rad som inte finns.
## Kanten följer noden vart den än flyttar, och en tvärlänk mellan två grenar syns som den länk den är.
## Färgen bär tillståndet: mörk kall metall när ingen av noderna är köpt, grenens metall när vägen är
## gången, och guldlågan runt en full nod.
func _rita(du: CanvasItem) -> void:
	if _meta == null or _ikoner.is_empty():
		return
	# EN BÅGE PER KRAV, kortad till nodernas kanter: ett rör genom klotet hade sett ut som en
	# genomborrad nod.
	for id in _ikoner:
		var ikon: Control = _ikoner[id]
		var c: Vector2 = ikon.position + ikon.size * 0.5
		var köpt: bool = _meta.rank(id) > 0
		for krav in _rader[id]["def"].get("requires", []):
			var förälder: String = str(krav)
			if not _ikoner.has(förälder):
				continue
			var f: Control = _ikoner[förälder]
			var fc: Vector2 = f.position + f.size * 0.5
			var båge: PackedVector2Array = _båge(förälder, id)
			if båge.size() < 2:
				continue
			var från: int = 0
			while från < båge.size() - 2 and båge[från].distance_to(fc) < f.size.x * 0.5 + 2.0:
				från += 1
			var till: int = båge.size() - 1
			while till > från + 1 and båge[till].distance_to(c) < ikon.size.x * 0.5 + 2.0:
				till -= 1
			var kant := PackedVector2Array()
			for i in range(från, till + 1):
				kant.append(båge[i])
			var tänd: bool = köpt or _meta.rank(förälder) > 0
			var färg: Color = GREN_FÄRG.get(str(_rader[id].get("gren", "")), JÄRN_LJUS) if tänd else JÄRN
			du.draw_polyline(kant, färg, 3.0)
			du.draw_polyline(kant, JÄRN_LJUS, 1.0)
	# SOCKETRINGARNA. Bara ringar, inga fyllda skivor: den här ritaren ligger ÖVERST i vyn (en Controls
	# egen _draw hamnar under barnen, och panelen är nästan opak), så en fylld skiva hade målat över
	# ikonerna — mätt: socketarna syntes och var alldeles tomma. Ringens innerkant hamnar på 9 px och
	# ikonen är 8 px radie, så klotet syns genom fattningen. Ringen bär tillståndet: mörk metall =
	# låst, grenens metall = köpt, guldlåga = full.
	for id in _ikoner:
		var ikon: Control = _ikoner[id]
		var rad: Dictionary = _rader[id]
		var gren: String = str(rad.get("gren", ""))
		var rank: int = _meta.rank(id)
		var maks: int = int(_meta.def_for(id).get("max_rank", 1))
		var färg: Color = JÄRN
		if rank > 0 and rank >= maks:
			färg = GULD
		elif rank > 0:
			färg = GREN_FÄRG.get(gren, JÄRN_LJUS)
		elif _meta.requires_met(id):
			färg = JÄRN_LJUS
		var c: Vector2 = ikon.position + ikon.size * 0.5
		var rr: float = ikon.size.x * 0.5 + 1.5
		du.draw_arc(c, rr, 0.0, TAU, 28, färg, 2.5, true)
		du.draw_arc(c, rr, -PI * 0.85, -PI * 0.15, 10, LJUSBLANK, 1.5, true)
		if rank > 0 and rank >= maks:
			du.draw_arc(c, rr + 3.0, 0.0, TAU, 28, GULD, 1.5, true)


## Noden som hovringstexten tillhör (M98). mouse_entered sätter den, mouse_exited tömmer bara om det är
## samma nod — annars hade flytten mellan två grannnoder kunnat tömma den nya radens text.
var _hovrad := ""


## Pekaren lämnade noden: töm raden om det är DEN som visas.
func _peka_bort(id: String) -> void:
	if _hovrad == id:
		_hovrad = ""
		_info.text = ""


func _peka(id: String) -> void:
	var def: Dictionary = _meta.def_for(id)
	var rad: Dictionary = _rader[id]
	# Är uppgraderingarna ikryssade i trädeditorn gäller DE, inte den genererade raden: annars visar
	# hovringen en effekt noden inte har (och i18n-värdet för texten vore dessutom fel).
	var egen: String = TreeSockets.text_of(_snäpp.get(id, {}))
	# RADEN ÄR ÖVERSATT, som namnet: texten kommer ur trädets i18n-rad och faller tillbaka på datats
	# svenska. Förr läste vyn `def.text` rakt av — alltså den svenska raden — så en tysk spelare såg
	# "Geschliffene Schneide — +2 % might" medan smedens lista (tree_lines) visade den översatta.
	var rad_text: String = Tr.t("tree.%s.text" % id, String(def.get("text", "")))
	var text: String = "%s — %s" % [_meta.def_name(id),
		egen if not egen.is_empty() else rad_text]
	var rang: int = _meta.rank(id)
	var max_rank: int = int(def.get("max_rank", 1))
	if _meta.is_maxed(id):
		text += "  ·  fullt uppgraderad (%d/%d)" % [rang, max_rank]
	else:
		text += "  ·  %d/%d" % [rang, max_rank]
		if _meta.requires_met(id):
			# Priset i trädets EGEN valuta, och svaret på om man har råd — M61:s rad från smedens
			# textlista, flyttad med trädet. Ett kryss säger att knappen inte gör något, vilket är
			# hela poängen: svaret ska stå där, inte räknas ut genom att jämföra två tal.
			var pris: int = _meta.next_soul_cost(id)
			text += "  ·  %d CS %s" % [pris, "✓" if _meta.souls >= pris else "✗"]
		else:
			text += "  ·  %s" % _meta.missing_requirement(id)
	_hovrad = id
	_info.text = text


func _klick(event: InputEvent, id: String) -> void:
	if redigering:
		return          # i editorn betyder ett klick "välj den här noden", inte "köp den"
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Samma väg som butiken: metan avgör om det går, och vyn ritar om det som blev.
		_meta.buy(id)
		uppdatera()
		_peka(id)


## ------------------------------------------------------------------------------------------------
## Ytan utåt, för trädeditorn (M95). Editorn ritar spelets EGEN vy och behöver flytta noder i den —
## inte en kopia av den, som skulle glida ifrån spelets utseende. Tre funktioner: var en nod ligger,
## hur en skärmpunkt blir bildandelar, och hur en nod flyttas.
## ------------------------------------------------------------------------------------------------

## Peka-läget stängs: ett klick i vyn köper ingenting.
var redigering := false


## Nodernas id, i den ordning vyn ritade dem. Frågan "vilka noder finns i trädet" har ett svar, och
## det står här — editorn bygger sin lista på den i stället för att gissa ur metan.
func nod_ids() -> Array:
	return _ikoner.keys()


## Nodens mitt i vyns pixlar.
func nod_punkt(id: String) -> Vector2:
	var ikon: Control = _ikoner.get(id, null)
	if ikon != null:
		return ikon.position + ikon.size * 0.5
	# Ingen ikon: en nod som tagits bort i trädeditorn. Räkna ur socketposten i stället, så markören
	# står där noden LÅG och går att sätta tillbaka (annars hamnade den i hörnet).
	var post: Dictionary = _snäpp.get(id, {})
	if post.has("x"):
		return _ur_bild(float(post["x"]), float(post["y"]))
	return Vector2.ZERO


## Vyns pixlar -> bildandelar. Samma räkning som _ur_bild, baklänges — och bara på ett ställe, så
## editorn och vyn alltid menar samma punkt.
func till_bild(punkt: Vector2) -> Vector2:
	var yta: Vector2 = _yta()
	var p: Vector2 = punkt - _pan
	return Vector2((p.x - yta.x * 0.5) / _sida() + 0.5, p.y / _sida())


## Flytta en nod till en plats i bilden. Nu skriver den också `pin`: en nod som FLYTTATS skall ligga
## kvar där någon lade den, även när vyn byggs om — rutnätet gäller bara de orörda noderna (M97).
func flytta(id: String, x: float, y: float) -> void:
	var ikon: Control = _ikoner.get(id, null)
	if ikon == null:
		return
	ikon.position = _ur_bild(x, y) - ikon.size * 0.5
	var record: Dictionary = _snäpp.get(id, {})
	record["id"] = id
	record["x"] = x
	record["y"] = y
	record["pin"] = true
	_snäpp[id] = record


## Sätt nodens storlek. Socketens radie är i bildandelar, samma enhet som x och y.
## Radien OCH klassen. Klassen måste med: placera_om räknar storleken ur klassens radie, så en
## ändring som bara skrev r skulle räknas bort vid nästa omläggning (mätt: 12 px före och 12 px efter
## ett klassbyte i editorn, eftersom _snäpp behöll den gamla klassen).
func sätt_radie(id: String, r: float, klass: String = "") -> void:
	var ikon: Control = _ikoner.get(id, null)
	if ikon == null:
		return
	var size_px: int = TreeSockets.size_px(r, _yta().y, _sida())
	var mitt: Vector2 = ikon.position + ikon.size * 0.5
	ikon.size = Vector2(size_px, size_px)
	ikon.position = mitt - ikon.size * 0.5
	var record: Dictionary = _snäpp.get(id, {})
	record["id"] = id
	record["r"] = r
	if not klass.is_empty():
		record["size"] = klass
	_snäpp[id] = record


## Lägg varje nod där trädrymden säger, i vyns NUVARANDE storlek, zoom och panorering. EN
## platsräkning: visa(), en storleksändring, en panorering och en zoom går alla genom den här. Utan
## den låg noderna kvar på positioner räknade för en annan storlek — och spelet ritar i riktiga
## pixlar, så fönstrets storlek ÄR ytans storlek.
func placera_om() -> void:
	if _ikoner.is_empty() or size.x < 8.0 or size.y < 8.0:
		return
	for id in _ikoner:
		var post: Dictionary = _snäpp.get(id, {})
		if not post.has("x"):
			continue
		var ikon: Control = _ikoner[id]
		var r: float = TreeSockets.radius_of(post)
		var size_px: int = TreeSockets.size_px(r, _yta().y, _sida())
		if size_px != int(ikon.size.x):
			ikon.size = Vector2(size_px, size_px)
			post["r"] = r
			_snäpp[id] = post
		ikon.position = _ur_bild(float(post["x"]), float(post["y"])) - ikon.size * 0.5
	if _ritare != null:
		_ritare.queue_redraw()


## Vyn byter storlek: noderna skall följa med, inte ligga kvar.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		placera_om()


## Rita om ramarna och ringarna (de ligger i ritaren ovanpå allt).
func rita_om() -> void:
	placera_om()


## ------------------------------------------------------------------------------------------------
## UTSNITTET: panorering och zoom (M96)
## ------------------------------------------------------------------------------------------------
## Trädet får växa förbi skärmen — det är hela poängen med en oändlig rymd — och då måste utsnittet
## gå att flytta. Hjul = zoom kring pekaren, höger (eller mitten) dragen = panorering, F = visa hela
## trädet. Samma grepp som i varje annat nodträd, och inget av dem ritar något eget: de flyttar bara
## utsnittet i _ur_bild, så noder, ringar, kopplingar och editorns markör följer med.
const PAN_KNAPPAR := [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var knapp := event as InputEventMouseButton
		if knapp.button_index == MOUSE_BUTTON_WHEEL_UP and knapp.pressed:
			zooma(knapp.position, 1.15)
		elif knapp.button_index == MOUSE_BUTTON_WHEEL_DOWN and knapp.pressed:
			zooma(knapp.position, 1.0 / 1.15)
		elif PAN_KNAPPAR.has(knapp.button_index):
			_drar = knapp.pressed
	elif event is InputEventMouseMotion and _drar:
		panorera((event as InputEventMouseMotion).relative)


## F visar hela trädet. Tangenten ligger här och inte i skalet: trädeditorn ritar samma vy, och båda
## skall hitta sina noder på samma sätt.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	if (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_F:
		centrera()
		get_viewport().set_input_as_handled()


## Panorera utsnittet, i vyns pixlar.
func panorera(delta: Vector2) -> void:
	_rörd = true
	_pan += delta
	placera_om()


## Zooma kring en punkt i vyn. Punkten under pekaren står kvar (samma trädandel före och efter) —
## utan det far trädet iväg åt sidan när man zoomar, och man tappar bort sig.
func zooma(punkt: Vector2, faktor: float) -> void:
	var före: Vector2 = till_bild(punkt)
	_rörd = true
	_zoom = clampf(_zoom * faktor, ZOOM_MIN, ZOOM_MAX)
	_pan += punkt - _ur_bild(före.x, före.y)
	placera_om()


## Öppna trädet i NATURLIG storlek (zoom 1) med spelarens FRONT i mitten: den djupaste nod som är
## köpt, annars grenarnas huvudnoder. Zoom 1 är nodernas egen skala — 19–32 px med kopplingar som går
## att följa — medan helhetsvyn (`centrera`, `F`) ritar de djupaste noderna 9 px, precis på golvet för
## att kunna hovra. Mätt i 480x270: zoom 1 visar 8 av 16 nivåer och hela grenen man står i.
func visa_front() -> void:
	# Mitten av spiralen: fronten när inget är köpt är de tre armarnas huvudnoder kring den.
	var mål := MITT
	var djupast := 0
	for id in _rader:
		if _meta == null or _meta.rank(id) <= 0:
			continue
		var nivå: int = int(_rader[id].get("nivå", 0))
		if nivå <= djupast:
			continue
		var post: Dictionary = _snäpp.get(id, {})
		if not post.has("x"):
			continue
		djupast = nivå
		mål = Vector2(float(post["x"]), float(post["y"]))
	# Panoreringen räknas som i centrera(): nollställ först, annars mäts avståndet mot den gamla pan.
	_zoom = 1.0
	_pan = Vector2.ZERO
	_pan = _yta() * 0.5 - _ur_bild(mål.x, mål.y)
	placera_om()


## Visa HELA trädet: räkna ut hur stor rymd noderna spänner över och sätt zoom och panorering så att
## den ryms. Det här är svaret på "hur hittar jag mina nya noder" när trädet vuxit förbi skärmen.
func centrera() -> void:
	var minsta := Vector2(INF, INF)
	var största := Vector2(-INF, -INF)
	for id in _ikoner:
		var post: Dictionary = _snäpp.get(id, {})
		if not post.has("x"):
			continue
		var p := Vector2(float(post["x"]), float(post["y"]))
		minsta.x = minf(minsta.x, p.x)
		minsta.y = minf(minsta.y, p.y)
		största.x = maxf(största.x, p.x)
		största.y = maxf(största.y, p.y)
	if minsta.x > största.x:
		nollställ()
		return
	# RYMDEN MÄTS I ANDELAR och plattan ritas i vyhöjden per andel, alltså ryms `vyhöjd` andelar på
	# höjden: zoomen som visar hela trädet är 1 / rymdens höjd. Bredden räknas i samma enhet — en andel
	# är lika många pixlar i x som i y. Ett grow() ger marginal åt alla håll, och gör en ensam nod
	# (noll storlek) till en rymd som går att visa.
	var rymd := Rect2(minsta, största - minsta).grow(0.1)
	var yta: Vector2 = _yta()
	_zoom = clampf(minf(yta.x / (rymd.size.x * yta.y), 1.0 / rymd.size.y), ZOOM_MIN, ZOOM_MAX)
	var mitten: Vector2 = rymd.get_center()
	_pan = Vector2.ZERO
	_pan = yta * 0.5 - _ur_bild(mitten.x, mitten.y)
	placera_om()


## Tillbaka till utgångsläget: zoom 1, ingen panorering — alltså en andel = vyhöjden i pixlar.
func nollställ() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	placera_om()
