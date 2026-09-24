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

const GRENAR := ["Järnvägen", "Benknippet", "Glöden", "Girigheten"]
const FILNAMN := {
	"Järnvägen": "jarnvagen", "Benknippet": "benknippet",
	"Glöden": "gloden", "Girigheten": "girigheten",
}
const HÖGSTA := 6
const IKON_PX := 22

var _ikoner := {}                  ## id -> TextureRect
var _rader := {}                   ## id -> Dictionary (gren, nivå, def)
var _rubrik: Label
var _rutnät: VBoxContainer
var _celler := {}                  ## "gren_nivå" -> HBox, fylld i _bygg (ingen sökväg, en referens)
var _info: Label
var _ritare: Control
var _meta: Meta

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
const JÄRN := Color(0.16, 0.15, 0.17)          ## kall gjutjärn: låst nod
const JÄRN_LJUS := Color(0.42, 0.40, 0.44)     ## öppen men orörd
const GULD := Color(0.98, 0.84, 0.44)          ## full uppgraderad, som referensens gyllene kedja

static func _mättad() -> Color:
	return Color(1.0, 0.88, 0.62)     # varm: grenen är fylld


func _ready() -> void:
	_bygg()


## Byggs på ett ställe och kan kallas om: _refresh_shell kan köra innan barnets _ready har hunnit
## (skalet sätter sin vy under sin egen uppstart), och då finns ingen Rubrik att sätta text i.
func _bygg() -> void:
	if _info != null:
		return
	custom_minimum_size = Vector2(456, 0)
	var ram := PanelContainer.new()
	ram.name = "Ram"
	ram.set_anchors_preset(Control.PRESET_FULL_RECT)
	ram.add_theme_stylebox_override("panel", _panel_stil())
	add_child(ram)
	var box := VBoxContainer.new()
	ram.add_child(box)

	var rubrik := Label.new()
	rubrik.name = "Rubrik"
	_rubrik = rubrik
	box.add_child(rubrik)

	# RADER AV RUTOR, INTE ETT RUTNÄT (M95). Först ett GridContainer med fyra kolumner — men ett
	# rutnät lägger ut sina barn efter SIN EGEN bredd, och bredden kom inifrån en panel som mätte sig
	# själv. Följden stod på Alex' skärmbild: alla ikoner på en rad i en svart ruta. En VBox med sex
	# HBox-rader (en per nivå, fyra grenrutor i varje) behöver ingen bredd för att veta var sakerna
	# skall ligga — den lägger ut dem i den ordning de kommer, och raderna kan inte hamna ovanpå
	# varandra. Samma rutor, samma namn, samma uppslag i visa().
	_rutnät = VBoxContainer.new()
	_rutnät.name = "Rutnät"
	_rutnät.add_theme_constant_override("separation", 2)
	box.add_child(_rutnät)
	for nivå in range(1, HÖGSTA + 1):
		var rad := HBoxContainer.new()
		rad.name = "rad_%d" % nivå
		rad.add_theme_constant_override("separation", 6)
		_rutnät.add_child(rad)
		for gren in GRENAR:
			var cell := HBoxContainer.new()
			cell.name = "%s_%d" % [FILNAMN[gren], nivå]
			cell.add_theme_constant_override("separation", 1)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rad.add_child(cell)
			_celler["%s_%d" % [FILNAMN[gren], nivå]] = cell

	_ritare = Ritar.new()
	_ritare.vy = self
	add_child(_ritare)

	_info = Label.new()
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)


func _panel_stil() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.96)
	sb.border_color = Color(0.45, 0.48, 0.60)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	return sb


## Bygger om rutan ur metan. Anropas när vyn öppnas och efter varje köp — allt som visas kommer
## därifrån, så vyn kan inte hamna i otakt med sparfilen.
func visa(meta: Meta, titel: String) -> void:
	_bygg()
	_meta = meta
	_rubrik.text = titel
	for barn in _ikoner.values():
		# remove_child FÖRST — samma fälla som hos juveleraren: en andra visa() i samma bildruta
		# mätte annars de gamla ikonerna också och rutnätet växte för varje omritning.
		_rutnät.remove_child(barn)
		barn.queue_free()
	_ikoner.clear()
	_rader.clear()

	# NIVÅN UR DATAT, MED EN RESERVVÄG (M95). De 88 noderna från generatorn bär `tier`. De 25 äldre
	# noderna gör inte det — och `def.get("tier", 1)` gjorde då ALLA till nivå 1, vilket är exakt vad
	# mätningen visade: 25 ikoner på samma y (31 px) i en rad 811 px bred i en 480 px vy.
	# Reservvägen räknar nodens plats i sin egen gren: datat står i kedjeordning (requires pekar
	# bakåt), så den nionde noden i en gren är grenens nionde steg. Samma tal, ur samma källa som
	# låsningen — den som lägger noder i fel ordning får fel nivå, och det syns direkt.
	var räknare := {}
	var steg := {}
	for d in meta.defs:
		var g := str(d.get("branch", ""))
		if g.is_empty():
			continue
		räknare[g] = int(räknare.get(g, 0)) + 1
		steg[str(d.get("id", ""))] = mini(HÖGSTA, räknare[g])

	for def in meta.defs:
		var gren: String = def.get("branch", "")
		if not FILNAMN.has(gren):
			continue
		var nivå: int = int(def.get("tier", 0))
		if nivå < 1 or nivå > HÖGSTA:
			nivå = int(steg.get(str(def.get("id", "")), 1))
		var cell: HBoxContainer = _celler.get("%s_%d" % [FILNAMN[gren], nivå], null)
		if cell == null:
			continue
		var id: String = def["id"]
		var ikon := TextureRect.new()
		ikon.name = id
		ikon.texture = load("res://assets/tree/%s%s.png" % [FILNAMN[gren],
			"_krona" if nivå >= HÖGSTA else ""])
		ikon.custom_minimum_size = Vector2(IKON_PX, IKON_PX)
		ikon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ikon.mouse_filter = Control.MOUSE_FILTER_STOP
		ikon.mouse_entered.connect(_peka.bind(id))
		ikon.gui_input.connect(_klick.bind(id))
		cell.add_child(ikon)
		_ikoner[id] = ikon
		_rader[id] = {"gren": gren, "nivå": nivå, "def": def}

	uppdatera()
	# Ramarna och rören ritas i _draw och behöver rutornas VERKLIGA läge: containrarna lägger ut sina
	# barn först i slutet av bildrutan, och en ritning som sker innan dess lägger alla ramar i hörnet
	# (mätt: inga ramar och inga rör syntes alls). En bildruta väntas därför in, och ritningen begärs
	# om — samma skäl som gör att ett prov inte kan mäta layouten.
	await get_tree().process_frame
	if _ritare != null:
		_ritare.queue_redraw()


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


## RAMAR OCH RÖR (M95). Referensbilden är byggd av två saker: en gjutjärnsram runt varje nod och
## massiva rör mellan dem. Båda ritas i stället för att läggas som bilder — en ram per nod hade varit
## 88 bilder för samma form, och rören måste följa rutornas verkliga läge (som bara containrarna
## känner). Färgen bär tillståndet: mörk kall metall när noden är låst, grenens metallfärg när den är
## köpt, och guld när den är full.
func _rita(du: CanvasItem) -> void:
	if _meta == null or _celler.is_empty():
		return
	# Rör mellan nivåerna, ett per gren: nedre kanten av en ruta till övre kanten av nästa. Ett rör
	# lyser i grenens metall när det finns minst en köpt rang i grenen på den nivån eller ovanför —
	# alltså när kraften faktiskt har letts dit, samma läsning som referensens glödande ledningar.
	for gren in GRENAR:
		var f := str(FILNAMN[gren])
		var köpta := {}
		for id in _rader:
			var rad: Dictionary = _rader[id]
			if str(rad.get("gren", "")) == gren and _meta.rank(id) > 0:
				köpta[int(rad.get("nivå", 0))] = true
		for nivå in range(1, HÖGSTA + 1):
			var upp: Control = _celler.get("%s_%d" % [f, nivå], null)
			var ned: Control = _celler.get("%s_%d" % [f, nivå + 1], null)
			if upp == null or ned == null:
				continue
			var x: float = upp.global_position.x - global_position.x + upp.size.x * 0.5
			var y1: float = upp.global_position.y - global_position.y + upp.size.y
			var y2: float = ned.global_position.y - global_position.y
			if y2 <= y1:
				continue
			var tänd: bool = köpta.has(nivå) or köpta.has(nivå + 1)
			var rör: Color = GREN_FÄRG.get(gren, JÄRN_LJUS) if tänd else JÄRN
			du.draw_line(Vector2(x, y1), Vector2(x, y2), rör, 3.0)
			du.draw_line(Vector2(x, y1), Vector2(x, y2), JÄRN_LJUS, 1.0)
	# Ram runt varje nodruta: mörk gjutjärn med en ljusare inre kant, och guld när rutan är full.
	for id in _ikoner:
		var ikon: Control = _ikoner[id]
		var rad: Dictionary = _rader[id]
		var gren: String = str(rad.get("gren", ""))
		var rank: int = _meta.rank(id)
		var maks: int = int(_meta.def_for(id).get("max_rank", 1))
		var färg := JÄRN
		if rank > 0 and rank >= maks:
			färg = GULD
		elif rank > 0:
			färg = GREN_FÄRG.get(gren, JÄRN_LJUS)
		elif _meta.requires_met(id):
			färg = JÄRN_LJUS
		var r := Rect2(ikon.global_position - global_position - Vector2(2, 2),
			ikon.size + Vector2(4, 4))
		du.draw_rect(r, färg, false, 2.0)
		# Nitar i hörnen: fyra punkter som gör ramen till metall i stället för en grå ruta.
		for hörn in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			du.draw_rect(Rect2(hörn - Vector2(1, 1), Vector2(2, 2)), färg)


func _peka(id: String) -> void:
	var def: Dictionary = _meta.def_for(id)
	var rad: Dictionary = _rader[id]
	var text: String = "%s — %s" % [_meta.def_name(id), String(def.get("text", ""))]
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
	_info.text = text


func _klick(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Samma väg som butiken: metan avgör om det går, och vyn ritar om det som blev.
		_meta.buy(id)
		uppdatera()
		_peka(id)
