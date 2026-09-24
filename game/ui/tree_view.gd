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
var _meta: Meta

static func _släckt() -> Color:
	return Color(0.42, 0.40, 0.46)

static func _köpbar() -> Color:
	return Color(1, 1, 1)

## Köpt men inte maxad: inre glöd, ljuset hålls innanför ramen. Steg 2 i Alex' bild.
static func _köpt() -> Color:
	return Color(0.92, 0.72, 0.42)

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
