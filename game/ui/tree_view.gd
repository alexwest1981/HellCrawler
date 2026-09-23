class_name TreeView
extends PanelContainer

## Trädet som EGEN VY (M94). Alex: *"Trädet skall vara en egen vy, och det skall vara ikoner, med text
## när man hovrar över en ikon."*
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
var _rutnät: GridContainer
var _info: Label
var _meta: Meta

static func _släckt() -> Color:
	return Color(0.42, 0.40, 0.46)

static func _köpbar() -> Color:
	return Color(1, 1, 1)

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
	add_theme_stylebox_override("panel", _panel_stil())
	var box := VBoxContainer.new()
	add_child(box)

	var rubrik := Label.new()
	rubrik.name = "Rubrik"
	_rubrik = rubrik
	box.add_child(rubrik)

	var rutnät := GridContainer.new()
	rutnät.name = "Rutnät"
	_rutnät = rutnät
	rutnät.columns = GRENAR.size()
	box.add_child(rutnät)

	for nivå in range(1, HÖGSTA + 1):
		for gren in GRENAR:
			var cell := HBoxContainer.new()
			cell.name = "%s_%d" % [FILNAMN[gren], nivå]
			cell.add_theme_constant_override("separation", 1)
			rutnät.add_child(cell)

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
		barn.queue_free()
	_ikoner.clear()
	_rader.clear()

	for def in meta.defs:
		var gren: String = def.get("branch", "")
		if not FILNAMN.has(gren):
			continue
		var nivå: int = int(def.get("tier", 1))
		var cell := _rutnät.get_node_or_null("%s_%d" % [FILNAMN[gren], nivå]) as HBoxContainer
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


## Tillståndet är färgen. Allt annat (namn, pris, skäl) kommer ur metan.
func uppdatera() -> void:
	for id in _ikoner:
		var ikon: TextureRect = _ikoner[id]
		if _meta.is_maxed(id):
			ikon.modulate = _mättad()
		elif _meta.requires_met(id):
			ikon.modulate = _köpbar()
		else:
			ikon.modulate = _släckt()


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
