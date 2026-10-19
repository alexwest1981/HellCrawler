## Karteditorn (M146): palett, karta och egenskapspanel — formen Alex pekade ut i referenseditorn
## (Luminati Level Editor): välj, flytta, måla, se vad objektet ÄR, spara och spela.
##
##   tools/editor.sh [bana] [våning]        (standard: stage_01 våning 1)
##
## Varför: spelets generator gissar former. Referensens rum är handbyggda (research/08-referensrum.md
## — 67 rum, varje relik har sitt eget), och en människa ritar bättre rum än en BSP-klyvning.
##
## Ytan är en riktig widgetyta i fönstrets pixlar (inte spelets 480x270-logiska yta): tre kolumner
## med rullande paneler kräver riktig layout, rullning och klickytor — och en karta över 34x34 rutor
## behöver den plats som blir över, inte en fast ruta. Den gamla ytan ritade panelen som textrader i
## 480x270 och skalade upp den; en palett på 30 knappar fick inte plats där.
##
## Reglerna för en RUTA bor i `MapIo` (placera/ta_bort/flytta/kopiera) — samma funktioner som spelets
## byggläge (F1) använder, så en kista inte ger olika guld beroende på var den byggdes.
extends Control

const NODE_TOOLS := [
	{"kind": "start", "ch": "S", "färg": Color(0.4, 0.95, 0.5), "namn": "Start"},
	{"kind": "encounter", "ch": "E", "färg": Color(0.95, 0.42, 0.38), "namn": "Strid"},
	{"kind": "boss", "ch": "B", "färg": Color(0.95, 0.4, 0.9), "namn": "Boss"},
	{"kind": "shovel", "ch": "N", "färg": Color(0.45, 0.85, 0.95), "namn": "Nedstigning"},
	{"kind": "chest", "ch": "K", "färg": Color(0.95, 0.82, 0.35), "namn": "Kista"},
	{"kind": "torch", "ch": "F", "färg": Color(0.95, 0.62, 0.3), "namn": "Fackla"},
]

## Banans fält, i panelens ordning. `↑↓` väljer inte längre rad (pilarna flyttar urvalet i kartan),
## utan varje rad har egna ◀ ▶ — `meta_vald` håller reda på vilken rad som ändrades senast.
const META_FÄLT := ["regel", "tema", "våningar", "svårighet", "tiers", "strider/våning", "boss",
	"sista boss", "guld-bonus", "xp-bonus", "ny strid"]
const TIER_SETT := [[1], [1, 2], [1, 2, 3], [2, 3], [2, 3, 4], [3, 4]]

const FÄRG_BAK := Color(0.075, 0.08, 0.095)
const FÄRG_PANEL := Color(0.105, 0.11, 0.13)
const FÄRG_KANT := Color(0.20, 0.21, 0.25)
const FÄRG_TEXT := Color(0.82, 0.84, 0.88)
const FÄRG_DIM := Color(0.58, 0.60, 0.66)
const FÄRG_ACC := Color(0.55, 0.85, 0.62)
const FÄRG_FEL := Color(0.95, 0.45, 0.4)

var stages: Dictionary = {}
var bestiary: Dictionary = {}
var stage: Stages.StageDef = null
var floor_index := 0
var floor: Dungeon.Floor = null
var vald: Array = []                 ## valda noder (referenser, inte positioner: boss och nedstigning
                                     ## kan dela ruta i en inläst fil, och då måste man kunna välja en)
var meta_vald := 0
var vald_fiende := ""                ## "" = generatorns val (deterministiskt ur positionen)
var status := ""
var fel: Array = []
var genererad := false
var ändrad := false

## Penseln: "valj" väljer och flyttar, "nod" sätter en nod, "ruta" målar golv/vägg,
## "material" lägger ett material på rutan ("" = temats egen ruta).
var verktyg := "valj"
var vy := "plan"                     ## "plan" (golv ljust, vägg mörkt) eller "textur" (temats rutor)
var nod_kind := "encounter"
var ruta_mark := Dungeon.FLOOR
var yta_material := ""
var material_lista: Array = []
var rekvisita_arter: Array = []      ## arterna i assets/props (namngivna och de som arken gav dem)
var rekvisit_art := ""               ## vald rekvisit i paletten
var fiende_art := ""                 ## vald fiende: paletten "FIENDER" ställer ut en strid med den

## Kartans mått. `zoom` är en faktor ovanpå den inpassning som ryms i vyn, så fönsterbytet behåller
## den zoom man valt; `pan` är panoreringen i px och behålls likaså.
var cell := 20.0
var fit := 20.0
var zoom := 1.0
var anka := Vector2.ZERO
var pan := Vector2.ZERO
var hover := Vector2i(-1, -1)
var _tex := {}

var _målar := false
var _drar := false                   ## en nod hålls och flyttas
var _panorerar := false
var _drag_punkt := Vector2.ZERO
var _drag_delta := Vector2i.ZERO
var _ruta_från := Vector2i(-1, -1)   ## förra rutan i samma målardrag (en linje, inte en prick per händelse)
var _box_från := Vector2.ZERO
var _box_till := Vector2.ZERO
var _box_aktiv := false
var _skift := false
var _ctrl := false

var duk: Control = null
var _l_bana: Label = null
var _l_våning: Label = null
var _l_läge: Label = null
var status_rad: Label = null
var palett_box: VBoxContainer = null
var insp_box: VBoxContainer = null
var outliner: ItemList = null
var outliner_rubrik: Label = null
var _outliner_noder: Array = []
var _palett_knappar: Array = []
var _grupp: ButtonGroup = null
var _vy_grupp: ButtonGroup = null
var _vy_knappar := {}
var _storlek_knappar := {}
var _tema_knappar := {}
var _räknare: Dictionary = {}


class Duk extends Control:
	var ägare = null                     ## otypad: en Control kan inte anropa editorns egna funktioner

	func _draw() -> void:
		if ägare != null:
			ägare._rita_duk(self)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bygg_ui()
	stages = Stages.load_all()
	bestiary = Enemies.load_all()
	material_lista = _materiallista()
	rekvisita_arter = _rekvisitalista()
	var args := OS.get_cmdline_user_args()
	var stage_id: String = args[0] if args.size() > 0 else "stage_01"
	floor_index = int(args[1]) if args.size() > 1 else 0
	stage = stages.get(stage_id)
	if stage == null:
		push_error("okänd bana: %s" % stage_id)
		stage = stages.values()[0]
	load_or_generate()
	_bygg_palett()            # ikonerna är våningens rutor: först nu finns temat att hämta dem ur
	_uppdatera()
	# Felsökningsflagga, samma vana som spelet: `-- shot` fotograferar editorn och avslutar, så
	# ytan går att granska utan att någon sitter framför den.
	if OS.get_cmdline_user_args().has("shot"):
		await get_tree().create_timer(1.0).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://editor.png")
		print("skärmbild: %s" % ProjectSettings.globalize_path("user://editor.png"))
		get_tree().quit()


# --- data ---------------------------------------------------------------------------------------

## Ladda filen om den finns — annars generatorns våning, så att man alltid börjar med något som går
## att spela i stället för en tom yta.
func load_or_generate() -> void:
	fel = []
	vald = []
	ändrad = false
	pan = Vector2.ZERO
	zoom = 1.0
	if MapIo.has_map(stage.id, floor_index):
		floor = MapIo.load_map(stage.id, floor_index, stage, bestiary)
		genererad = false
		status = "läste %s" % MapIo.path_for(stage.id, floor_index).get_file()
	else:
		floor = Dungeon.generate(stage, floor_index, 20260919, bestiary)
		genererad = true
		status = "genererad våning — rätta den och spara"
	# Våningens tema: det ritade om det finns, annars banans. Så öppnar man en våning och ser den
	# med det tileset den faktiskt spelas med — inte med editorns gråa standard.
	if floor.theme.is_empty():
		floor.theme = Stages.theme_for(stage, floor_index)
	_layout_duk()
	_bygg_storlek_dialog()


## Arterna man kan ställa ut: samma mapp som spelets dekor läser (`assets/props`), så en ny rekvisit
## blir valbar samma dag den klipps — ingen lista i koden att glida ifrån. Nodbilderna (kista, spade,
## boss, fackla) hoppas över: de är nodtyper i kartan, inte lös rekvisita man strör ut.
const NODBILDER := ["chest", "shovel", "boss", "fackla", "benhög"]

## FIENDEPALETTEN (M155). Den här editorn ska gå att använda som referensen: man väljer VAD som ska
## spawna, inte bara "en strid". Ikonerna är fiendernas egna bilder ur assets/enemies, och klicket
## ställer en `encounter` med den fienden — `MapIo.placera` tar enemy_id som sista argument, så samma
## regel gäller som i byggläget (en nod per ruta, fienden deterministisk när man inte väljer).
func _fiendelista() -> Array:
	# BANANS EGNA FÖRST. `MapIo.placera` vägrar en fiende som inte finns i banans tiers, så paletten
	# ska börja med dem man faktiskt får använda — resten ligger kvar efteråt (en våning kan flyttas
	# till en annan bana, och då är listan redan rätt).
	var pool := []
	if stage != null:
		for e in Enemies.by_tier(bestiary, stage.tiers):
			pool.append(str(e.id))
	pool.sort()
	var ut := []
	for id in bestiary:
		if not pool.has(str(id)):
			ut.append(str(id))
	ut.sort()
	return pool + ut


func _fiende_tex(id: String) -> Texture2D:
	var key := "fiende/%s" % id
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	var p := "res://assets/enemies/%s.png" % id
	if ResourceLoader.exists(p):
		var källa := load(p) as Texture2D
		# FIGURENS EGEN YTA, inte hela arket: fiendearken är 128 px med luft runt figuren, och då blir
		# ansiktet en mörk prick i en tom ruta. Samma skäl som `_prop_yta` för rekvisitan.
		if källa != null:
			var img := källa.get_image()
			if img != null:
				# FIENDEARKEN ÄR EN REMSA (720x120 = sex rutor à 120 px), inte en figur. Helremsan i en
				# 26 px-ruta blir en grå linje. Ta första rutan, och sedan figurens yta inuti den.
				if img.get_width() > img.get_height() * 3 / 2:
					var sida := img.get_height()
					img = img.get_region(Rect2i(0, 0, sida, sida))
					var första := ImageTexture.create_from_image(img)
					var yta0 := img.get_used_rect()
					if yta0.size.x > 1 and yta0.size.y > 1:
						var a0 := AtlasTexture.new()
						a0.atlas = första
						a0.region = yta0
						_tex[key] = a0
						return a0
				var yta := img.get_used_rect()
				if yta.size.x > 1 and yta.size.y > 1:
					var atlas := AtlasTexture.new()
					atlas.atlas = källa
					atlas.region = yta
					tex = atlas
		if tex == null:
			tex = källa
	_tex[key] = tex
	return tex


func _rekvisitalista() -> Array:
	var ut := []
	for fil in DirAccess.get_files_at("res://assets/props"):
		if not fil.ends_with(".png") or fil.begins_with("_"):
			continue
		var art := fil.get_basename()
		if NODBILDER.has(art):
			continue
		ut.append(art)
	# NAMNGIVNA FÖRST. Alex' ark blev också 60 namnlösa snitt (`pwa97m_07`); de är lika giltiga
	# rekvisita, men paletten ska börja med det man kan läsa: bur, kranium, trälåda.
	ut.sort_custom(func(a, b):
		var an := _namngiven(str(a))
		var bn := _namngiven(str(b))
		if an != bn:
			return an
		return str(a) < str(b))
	return ut


## Har arten ett namn (bur, trälåda) eller är den ett snitt ur ett ark (pwa97m_07)?
func _namngiven(art: String) -> bool:
	for c in art:
		if c >= "0" and c <= "9":
			return false
	return true


## Materialen man kan måla med: samma filer som byggläget läser, ur mappen i stället för en tabell.
func _materiallista() -> Array:
	var ut := []
	for fil in DirAccess.get_files_at("res://assets/tiles/material"):
		if fil.ends_with(".png"):
			ut.append("material/" + fil.get_basename())
	ut.sort()
	return ut


## Rutan ur ett tema, cachad. `null` om temat eller rutan inte finns — då ritar editorn sin platta
## färg i stället, så en trasig katalog syns som en platt yta och inte som en krasch.
func _tema_tex(tema: String, namn: String) -> Texture2D:
	var key := "%s/%s" % [tema, namn]
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	for p in ["res://assets/tiles/%s/%s.png" % [tema, namn], "res://assets/tiles/%s.png" % namn]:
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	_tex[key] = tex
	return tex


func _material_tex(id: String) -> Texture2D:
	var key := "yta/%s" % id
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	var p := "res://assets/tiles/%s.png" % id
	if ResourceLoader.exists(p):
		tex = load(p)
	_tex[key] = tex
	return tex


func _prop_tex(art: String) -> Texture2D:
	var key := "rekvisit/%s" % art
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	var p := "res://assets/props/%s.png" % art
	if ResourceLoader.exists(p):
		tex = load(p)
	_tex[key] = tex
	return tex


func _nasta_tema(steg: int) -> void:
	var lista := [""] + MapIo.THEMES
	var i := lista.find(floor.theme)
	if i < 0:
		i = 0
	i = (i + steg + lista.size()) % lista.size()
	floor.theme = str(lista[i])
	ändrad = true
	status = "tema: %s" % (floor.theme if not floor.theme.is_empty() else "(platt)")
	print("editorn: tema %s på %s våning %d" % [floor.theme, stage.id, floor_index + 1])
	_uppdatera()


func _nod_vid(p: Vector2i) -> Dungeon.FloorNode:
	var funnen: Dungeon.FloorNode = null
	for n in floor.nodes:
		if n.pos == p:
			funnen = n
	return funnen


func _remove_node_at(p: Vector2i) -> void:
	# Reglerna bor i MapIo (samma som spelets byggläge): pekarna start/boss/nedstigning måste nollställas
	# när deras ruta töms, och det står på ett ställe i stället för två.
	MapIo.ta_bort(floor, p)


## Målar en ruta med penseln. Svarar "" om det gick, annars orsaken — statusraden visar den, så en
## knapp vars verkan man måste gissa inte går att skilja från en trasig.
func _place(p: Vector2i) -> String:
	match verktyg:
		"ruta":
			floor.tiles[p.y][p.x] = ruta_mark
			if ruta_mark == Dungeon.WALL:
				_remove_node_at(p)             # en vägg kan inte bära en nod
			floor.ytor.erase("%d,%d" % [p.x, p.y])
		"material":
			if yta_material.is_empty():
				floor.ytor.erase("%d,%d" % [p.x, p.y])
			else:
				floor.ytor["%d,%d" % [p.x, p.y]] = yta_material
		"rekvisita":
			var fr := MapIo.sätt_rekvisita(floor, rekvisit_art, p)
			if not fr.is_empty():
				return fr
		"fiende":
			var ff := MapIo.placera(floor, "encounter", p, stage, bestiary, fiende_art)
			if not ff.is_empty():
				return ff
		"nod":
			var f := MapIo.placera(floor, nod_kind, p, stage, bestiary, vald_fiende)
			if not f.is_empty():
				return f
		_:
			return ""
	ändrad = true
	return ""


func _tool_for(kind: String) -> Dictionary:
	for d in NODE_TOOLS:
		if d["kind"] == kind:
			return d
	return {}


# --- urval --------------------------------------------------------------------------------------

func _valj_ensam(n: Dungeon.FloorNode) -> void:
	vald = [n] if n != null else []


func _valj_lägg_till(n: Dungeon.FloorNode) -> void:
	if not vald.has(n):
		vald.append(n)


func _valj_växla(n: Dungeon.FloorNode) -> void:
	if vald.has(n):
		vald.erase(n)
	else:
		vald.append(n)


func _ta_bort_vald() -> void:
	if vald.is_empty():
		status = "inget valt"
		return
	var bort := 0
	for n in vald.duplicate():
		var p: Vector2i = n.pos
		bort += MapIo.ta_bort(floor, p)
	vald = []
	ändrad = ändrad or bort > 0
	status = "%d nod(er) borttagna" % bort
	_uppdatera()


## Ctrl+D: kopian läggs på första lediga golvruta intill — norr, öster, söder, väster, sedan diagonalt,
## så en rad kistor kopieras åt samma håll som man tittar.
func _kopiera_vald() -> void:
	if vald.size() != 1:
		status = "markera exakt en nod att kopiera"
		return
	var n: Dungeon.FloorNode = vald[0]
	var steg := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var sista := ""
	for d in steg:
		var till: Vector2i = n.pos + d
		sista = MapIo.kopiera(floor, n, till)
		if sista.is_empty():
			ändrad = true
			status = "%s kopierad till (%d,%d)" % [n.kind, till.x, till.y]
			_uppdatera()
			return
	status = sista


func _putta(steg: Vector2i) -> void:
	if vald.is_empty():
		return
	var f := MapIo.flytta(floor, vald, steg)
	status = f if not f.is_empty() else "flyttade %d nod(er)" % vald.size()
	ändrad = ändrad or f.is_empty()
	_uppdatera()


## Ramar in urvalet (eller hela våningen när inget är valt): zoom och panorering så allt syns.
func _rama_in() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_layout_duk()
	status = "ramar in %s" % ("urvalet" if not vald.is_empty() else "våningen")
	_uppdatera()


# --- ytan ---------------------------------------------------------------------------------------

func _bygg_ui() -> void:
	theme = _tema()
	var kolumn := VBoxContainer.new()
	kolumn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kolumn.add_theme_constant_override("separation", 0)
	add_child(kolumn)
	kolumn.add_child(_bygg_topp())
	var rad := HBoxContainer.new()
	rad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rad.add_theme_constant_override("separation", 0)
	kolumn.add_child(rad)
	rad.add_child(_bygg_vänster())
	rad.add_child(_bygg_mitten())
	rad.add_child(_bygg_höger())


## Mörk yta med spelets palett i stället för Godots grå standardtema. EN tema-instans på roten, så
## varje ny panel och knapp ärver den — en färg per widget är en tabell som glider isär.
func _tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13
	t.set_color("font_color", "Label", FÄRG_TEXT)
	t.set_color("font_color", "Button", FÄRG_TEXT)
	t.set_color("font_color", "ItemList", FÄRG_TEXT)
	t.set_stylebox("panel", "PanelContainer", _ruta_stil(FÄRG_PANEL, FÄRG_KANT, 1))
	t.set_stylebox("normal", "Button", _ruta_stil(Color(0.14, 0.15, 0.18), FÄRG_KANT, 1))
	t.set_stylebox("hover", "Button", _ruta_stil(Color(0.19, 0.21, 0.25), Color(0.3, 0.32, 0.36), 1))
	t.set_stylebox("pressed", "Button", _ruta_stil(Color(0.22, 0.30, 0.24), FÄRG_ACC, 1))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return t


func _ruta_stil(bak: Color, kant: Color, bredd: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bak
	s.border_color = kant
	s.set_border_width_all(bredd)
	s.set_corner_radius_all(3)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _etikett(text: String, storlek := 13, färg := FÄRG_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", storlek)
	l.add_theme_color_override("font_color", färg)
	return l


func _knapp(text: String, tips := "", åtgärd := Callable(), bredd := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tips
	b.focus_mode = Control.FOCUS_NONE       # annars äter knapparna piltangenterna (nudge/urval)
	if bredd > 0.0:
		b.custom_minimum_size.x = bredd
	if åtgärd.is_valid():
		b.pressed.connect(åtgärd)
	return b


func _bygg_topp() -> Control:
	var p := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(_etikett("KARTEDITOR", 15))
	h.add_child(VSeparator.new())
	h.add_child(_knapp("◀", "förra banan (,)", nasta_bana.bind(-1), 26))
	var namn := _etikett("", 13)
	namn.name = "Bana"
	namn.custom_minimum_size.x = 150
	_l_bana = namn
	h.add_child(namn)
	h.add_child(_knapp("▶", "nästa bana (.)", nasta_bana.bind(1), 26))
	h.add_child(VSeparator.new())
	h.add_child(_knapp("◀", "förra våningen ([)", _våning.bind(-1), 26))
	var våning: Label = _etikett("", 13)
	våning.name = "Våning"
	våning.custom_minimum_size.x = 110
	_l_våning = våning
	h.add_child(våning)
	h.add_child(_knapp("▶", "nästa våning (])", _våning.bind(1), 26))
	var luft := Control.new()
	luft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(luft)
	var läge := _etikett("", 12, FÄRG_DIM)
	läge.name = "Läge"
	_l_läge = läge
	h.add_child(läge)
	h.add_child(_knapp("Spara", "spara våningen (S)", save))
	h.add_child(_knapp("Bana", "spara banan (B)", save_stage))
	h.add_child(_knapp("Spela", "spara och spela våningen (P)", playtest))
	h.add_child(_knapp("Ny", "ny tom våning (N)", _ny_våning))
	return p


func _bygg_vänster() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 248
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(_etikett("PALETT", 11, FÄRG_DIM))
	var rull := ScrollContainer.new()
	rull.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rull.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rull)
	palett_box = VBoxContainer.new()
	palett_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palett_box.add_theme_constant_override("separation", 3)
	rull.add_child(palett_box)
	outliner_rubrik = _etikett("OBJEKT", 11, FÄRG_DIM)
	v.add_child(outliner_rubrik)
	outliner = ItemList.new()
	outliner.custom_minimum_size.y = 168
	# ingen fokus: en klickad lista som behåller fokus äter piltangenterna, och de flyttar urvalet
	outliner.focus_mode = Control.FOCUS_NONE
	outliner.item_selected.connect(_outliner_vald)
	v.add_child(outliner)
	return p


func _bygg_mitten() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	var d := Duk.new()
	d.ägare = self
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.custom_minimum_size = Vector2(340, 260)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	d.mouse_default_cursor_shape = Control.CURSOR_CROSS
	d.tooltip_text = "klick väljer · Skift+klick lägger till · Ctrl+klick växlar · drag flyttar\n" \
		+ "dra tom yta = box · Del tar bort · Ctrl+D kopierar · pilar flyttar 1 ruta\n" \
		+ "hjul zoomar · mitten+drag panorerar · F ramar in"
	d.resized.connect(_layout_duk)
	d.gui_input.connect(_duk_input)
	v.add_child(d)
	duk = d
	var p := PanelContainer.new()
	status_rad = _etikett("", 12, FÄRG_DIM)
	status_rad.clip_text = true
	p.add_child(status_rad)
	v.add_child(p)
	return v


func _bygg_höger() -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 300
	var rull := ScrollContainer.new()
	rull.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(rull)
	insp_box = VBoxContainer.new()
	insp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_box.add_theme_constant_override("separation", 4)
	rull.add_child(insp_box)
	return p


## Paletten: verktyg, rutor, noder och material — hittade ur samma källor som spelet läser (teman ur
## `MapIo.THEMES`, material ur mappen), så ett nytt ark blir valbart samma dag det klipps.
func _bygg_palett() -> void:
	for c in palett_box.get_children():
		palett_box.remove_child(c)
		c.queue_free()
	_palett_knappar = []
	_grupp = ButtonGroup.new()
	_verktygs_rubrik("VÄLJ")
	_palett_knapp(_knapp("Välj / flytta   (V)", "klick väljer, drag flyttar, dra tom yta = box",
		_sätt_verktyg.bind("valj")))
	_vy_rad()
	_verktygs_rubrik("RUTOR")
	var golv := _palett_knapp(_knapp("Golv   (G)", "måla golv", _sätt_verktyg.bind("ruta", "golv")))
	golv.icon = _tema_tex(floor.theme if floor != null else "", "floor")
	golv.add_theme_constant_override("icon_max_width", 18)   # utan taket blir rutan 64 px hög
	var vägg := _palett_knapp(_knapp("Vägg   (X)", "måla vägg (tar bort noden på rutan)",
		_sätt_verktyg.bind("ruta", "vägg")))
	vägg.icon = _tema_tex(floor.theme if floor != null else "", "wall")
	vägg.add_theme_constant_override("icon_max_width", 18)
	_verktygs_rubrik("NODER")
	for i in NODE_TOOLS.size():
		var d: Dictionary = NODE_TOOLS[i]
		var b := _palett_knapp(_knapp("%s   %s" % [d["ch"], d["namn"]],
			"tangent %d" % (i + 1), _sätt_verktyg.bind("nod", d["kind"])))
		b.add_theme_color_override("font_color", d["färg"])
	# FIENDEPALETTEN (M155): vad som ska spawna, inte bara "en strid". Samma ikonrutnät som rekvisitan.
	_verktygs_rubrik("FIENDER  (%d)" % _fiendelista().size())
	var fiender := GridContainer.new()
	fiender.columns = 4
	fiender.add_theme_constant_override("h_separation", 3)
	fiender.add_theme_constant_override("v_separation", 3)
	palett_box.add_child(fiender)
	for id in _fiendelista():
		var b := _palett_knapp(_knapp("", str(id), _sätt_verktyg.bind("fiende", id)), fiender)
		b.icon = _fiende_tex(str(id))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(34, 34)
		b.add_theme_constant_override("icon_max_width", 26)

	_verktygs_rubrik("MATERIAL  (%d)" % material_lista.size())
	var ingen := _palett_knapp(_knapp("Temats ruta", "ta bort materialöverstyrningen på rutan",
		_sätt_verktyg.bind("material", "")))
	ingen.add_theme_color_override("font_color", FÄRG_DIM)
	# Materialen som ett RUTNÄT av ikoner: 23 namn på egna rader är 23 rader rullning, och ikonen är
	# dessutom hela poängen — man känner igen arket på bilden, inte på filnamnet.
	var ytor := GridContainer.new()
	ytor.columns = 4
	ytor.add_theme_constant_override("h_separation", 3)
	ytor.add_theme_constant_override("v_separation", 3)
	_vikbar_rubrik("MATERIAL  (%d)" % material_lista.size(), ytor)
	palett_box.add_child(ytor)
	for id in material_lista:
		var b := _palett_knapp(_knapp("", str(id).replace("material/", ""),
			_sätt_verktyg.bind("material", id)), ytor)
		b.icon = _material_tex(str(id))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(30, 30)
		b.add_theme_constant_override("icon_max_width", 22)
	# REKVISITAN (M150): det man strör ut — stenar, grus, tunnor, burar, svampar. Samma ikonrutnät som
	# materialen, ur mappen spelets dekor läser, med artnamnet som hovringstext: 94 arter får inte bli
	# 94 rader text.
	var prylar := GridContainer.new()
	prylar.columns = 4
	prylar.add_theme_constant_override("h_separation", 3)
	prylar.add_theme_constant_override("v_separation", 3)
	_vikbar_rubrik("REKVISITA  (%d)" % rekvisita_arter.size(), prylar)
	palett_box.add_child(prylar)
	for art in rekvisita_arter:
		var b := _palett_knapp(_knapp("", str(art), _sätt_verktyg.bind("rekvisita", art)), prylar)
		b.icon = _prop_tex(str(art))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(34, 34)
		b.add_theme_constant_override("icon_max_width", 26)
	var tips := _etikett("S spara · O spara som block · L läs om · N ny · P spela · B spara banan\n" \
		+ "T/Y tema · K plan/textur · [ ] våning · ,/. bana\n" \
		+ "+/- storlek · M meny · Q avsluta", 11, FÄRG_DIM)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	palett_box.add_child(tips)
	_markera_verktyg()


## Vyn man ritar i: PLAN (rent papper) eller TEXTUR (temats rutor). Två knappar i stället för en
## växel, så man ser vilket läge man är i utan att gissa — och `K` gör samma sak från tangentbordet.
func _vy_rad() -> void:
	_verktygs_rubrik("VY")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	palett_box.add_child(h)
	_vy_grupp = ButtonGroup.new()
	_vy_knappar = {}
	for par in [["plan", "Plan", "golv ljust, vägg mörkt — så läser man en planlösning"],
			["textur", "Textur", "temats egna rutor och materialen, som spelet visar dem"]]:
		var b := _knapp(str(par[1]), str(par[2]), _sätt_vy.bind(str(par[0])))
		b.toggle_mode = true
		b.button_group = _vy_grupp
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 24
		h.add_child(b)
		_vy_knappar[str(par[0])] = b
	_markera_vy()


func _sätt_vy(v: String) -> void:
	vy = v
	_markera_vy()
	_stämpla()
	if duk != null:
		duk.queue_redraw()


func _markera_vy() -> void:
	for nyckel in _vy_knappar:
		(_vy_knappar[nyckel] as Button).set_pressed_no_signal(nyckel == vy)


## RUBRIK SOM VIKER IHOP SIN RUTA (M155). Referenseditorn har korta kategorilistor; vår rekvisita är
## 93 ikoner, och då ligger allt annat under vikningen. Klick på rubriken fäller ut/ihop rutnätet —
## palettens index räknas på knapparnas ordning, inte på vad som syns, så inget flyttar sig.
func _vikbar_rubrik(text: String, box: Control) -> Button:
	var knapp := Button.new()
	knapp.text = "▾ %s" % text
	knapp.flat = true
	knapp.alignment = HORIZONTAL_ALIGNMENT_LEFT
	knapp.add_theme_font_size_override("font_size", 10)
	knapp.add_theme_color_override("font_color", Color(0.66, 0.7, 0.78))
	knapp.custom_minimum_size.y = 14
	knapp.focus_mode = Control.FOCUS_NONE
	knapp.pressed.connect(func():
		box.visible = not box.visible
		knapp.text = ("▾ " if box.visible else "▸ ") + text)
	palett_box.add_child(knapp)
	return knapp


func _verktygs_rubrik(text: String) -> void:
	var l := _etikett(text, 10, Color(0.66, 0.7, 0.78))
	l.custom_minimum_size.y = 14
	palett_box.add_child(l)


func _palett_knapp(b: Button, box: Control = null) -> Button:
	b.toggle_mode = true
	b.button_group = _grupp
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 24
	# klipp texten: annars blir paletten så bred som det längsta materialnamnet, och kartan krymper
	b.clip_text = true
	(box if box != null else palett_box).add_child(b)
	_palett_knappar.append(b)
	return b


## Verktyget sätts på ETT ställe, så knapparnas markering och `verktyg` inte kan säga olika saker.
func _sätt_verktyg(typ: String, vad := "") -> void:
	verktyg = typ
	match typ:
		"ruta":
			ruta_mark = Dungeon.WALL if vad == "vägg" else Dungeon.FLOOR
		"nod":
			nod_kind = vad
		"material":
			yta_material = vad
		"rekvisita":
			rekvisit_art = vad
		"fiende":
			fiende_art = vad
	_markera_verktyg()
	_stämpla()
	if duk != null:
		duk.queue_redraw()


## Knapparnas turordning i `_palett_knappar`, på ETT ställe: valj, golv, vägg, noderna, temats ruta,
## materialen, rekvisitan. Nya sektioner läggs i paletten och räknas här.
func _palett_index() -> Dictionary:
	var i_nod := 3
	var i_mat_tema := i_nod + NODE_TOOLS.size()
	var i_mat := i_mat_tema + 1
	var i_rekv := i_mat + material_lista.size()
	var i_fiende := i_rekv + rekvisita_arter.size()
	return {"valj": 0, "golv": 1, "vagg": 2, "nod": i_nod, "mat_tema": i_mat_tema,
		"mat": i_mat, "rekv": i_rekv, "fiende": i_fiende}


func _markera_verktyg() -> void:
	var ix := _palett_index()
	var index := -1
	if verktyg == "valj":
		index = int(ix["valj"])
	elif verktyg == "ruta":
		index = int(ix["golv"]) if ruta_mark == Dungeon.FLOOR else int(ix["vagg"])
	elif verktyg == "nod":
		for i in NODE_TOOLS.size():
			if NODE_TOOLS[i]["kind"] == nod_kind:
				index = int(ix["nod"]) + i
	elif verktyg == "material":
		index = int(ix["mat_tema"]) if yta_material.is_empty() \
			else int(ix["mat"]) + material_lista.find(yta_material)
	elif verktyg == "rekvisita":
		index = int(ix["rekv"]) + rekvisita_arter.find(rekvisit_art)
	elif verktyg == "fiende":
		index = int(ix["fiende"]) + _fiendelista().find(fiende_art)
	# alla av först: en knappgrupp släpper inte en knapp som tryckts med set_pressed_no_signal
	for b in _palett_knappar:
		(b as Button).set_pressed_no_signal(false)
	if index >= 0 and index < _palett_knappar.size():
		(_palett_knappar[index] as Button).set_pressed_no_signal(true)


# --- kartans mått och ritning --------------------------------------------------------------------

## Inpassningen ryms i vyn; `zoom` är faktorn ovanpå. Anropas av `duk.resized`, av zoom och av
## inramningen — aldrig av `_draw`, så `_cell_at` och ritningen alltid räknar med SAMMA tal.
func _layout_duk() -> void:
	if duk == null or floor == null:
		return
	var yta: Vector2 = duk.size
	fit = minf((yta.x - 28.0) / maxf(1.0, float(floor.w)), (yta.y - 28.0) / maxf(1.0, float(floor.h)))
	fit = maxf(2.0, fit)
	cell = maxf(3.0, fit * zoom)
	anka = (yta - Vector2(floor.w, floor.h) * cell) * 0.5 + pan
	duk.queue_redraw()


func _ruta_vid(pos: Vector2) -> Vector2i:
	var p := Vector2i(floori((pos.x - anka.x) / cell), floori((pos.y - anka.y) / cell))
	if p.x < 0 or p.y < 0 or p.x >= floor.w or p.y >= floor.h:
		return Vector2i(-1, -1)
	return p


func _ruta_rect(p: Vector2i) -> Rect2:
	return Rect2(anka + Vector2(p) * cell, Vector2(cell, cell))


## Kartan ritas i två vyer. PLAN (standard) ritar ett rent papper: golv ljust, vägg mörkt, och en
## ljus kant runt varje golvyta. Det är inte en genväg — det är nödvändigt, för temats egna rutor kan
## vara IDENTISKA: `bro/floor.png` och `bro/wall.png` har samma md5 (mätt), så en karta över stage_01
## ritad med temats texturer har noll skillnad mellan golv och vägg. TEXTUR (`K`) visar temats rutor
## och materialen som de ser ut i spelet; kanten mellan golv och vägg ritas i båda vyerna, så gränsen
## syns även när texturerna inte skiljer sig.
func _rita_duk(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), FÄRG_BAK)
	if floor == null:
		return
	if vy == "textur":
		_rita_rutor(c)
	else:
		_rita_plan(c)
	_rita_rekvisita(c)
	_rita_kant(c)
	# rutnätet ovanpå rytorna: tunna linjer, en per ruta
	var linje := Color(0, 0, 0, 0.35)
	for x in floor.w + 1:
		var px := anka.x + x * cell
		c.draw_line(Vector2(px, anka.y), Vector2(px, anka.y + floor.h * cell), linje, 1.0)
	for y in floor.h + 1:
		var py := anka.y + y * cell
		c.draw_line(Vector2(anka.x, py), Vector2(anka.x + floor.w * cell, py), linje, 1.0)
	# öppna rum (taklösa): streckad ram, de ritas inte alls i spelet annars och var osynliga här förut
	for r in floor.öppna:
		var rr: Rect2 = r
		var rekt := Rect2(anka + Vector2(rr.position) * cell, Vector2(rr.size) * cell)
		c.draw_dashed_line(rekt.position, Vector2(rekt.end.x, rekt.position.y), FÄRG_ACC, 1.0, 5.0)
		c.draw_dashed_line(Vector2(rekt.end.x, rekt.position.y), rekt.end, FÄRG_ACC, 1.0, 5.0)
		c.draw_dashed_line(rekt.end, Vector2(rekt.position.x, rekt.end.y), FÄRG_ACC, 1.0, 5.0)
		c.draw_dashed_line(Vector2(rekt.position.x, rekt.end.y), rekt.position, FÄRG_ACC, 1.0, 5.0)
	# noderna
	var font := ThemeDB.fallback_font
	var text_px := clampi(int(cell * 0.62), 8, 20)
	for n in floor.nodes:
		var d := _tool_for(n.kind)
		if d.is_empty():
			continue
		var r := _ruta_rect(n.pos)
		var c_mitt := r.position + r.size * 0.5
		var vald_nod: bool = vald.has(n)
		c.draw_circle(c_mitt, cell * 0.34, d["färg"].darkened(0.55))
		c.draw_arc(c_mitt, cell * 0.34, 0.0, TAU, 20, d["färg"], maxf(1.0, cell * 0.06))
		if vald_nod:
			c.draw_arc(c_mitt, cell * 0.44, 0.0, TAU, 24, Color(1, 1, 0.75), maxf(1.5, cell * 0.09))
		c.draw_string(font, c_mitt + Vector2(-cell * 0.5, text_px * 0.35), str(d["ch"]),
			HORIZONTAL_ALIGNMENT_CENTER, cell, text_px, d["färg"])
	# pekarens ruta
	if hover.x >= 0:
		c.draw_rect(_ruta_rect(hover), Color(1, 1, 0.75, 0.9), false, maxf(1.0, cell * 0.07))
	# box-markeringen
	if _box_aktiv:
		var box := Rect2(_box_från, _box_till - _box_från).abs()
		c.draw_rect(box, Color(0.55, 0.85, 0.62, 0.12))
		c.draw_rect(box, FÄRG_ACC, false, 1.0)


## PLANVYN: väggarna är den mörka massan, golven är ljusa fält. Två värden med ~55 nivåers skillnad
## (0,09 mot 0,30) — ögat skiljer dem på en blick, och det gör det inte mellan temats två rutor.
const FÄRG_GOLV := Color(0.31, 0.33, 0.39)
const FÄRG_VÄGG := Color(0.085, 0.09, 0.11)
const FÄRG_GOLVKANT := Color(0.66, 0.73, 0.86)

func _rita_plan(c: Control) -> void:
	for y in floor.h:
		for x in floor.w:
			var p := Vector2i(x, y)
			var golv: bool = floor.tiles[y][x] == Dungeon.FLOOR
			var id := str(floor.ytor.get("%d,%d" % [x, y], ""))
			var r := _ruta_rect(p)
			var färg := FÄRG_GOLV if golv else FÄRG_VÄGG
			if not id.is_empty():
				# materialet syns som sin EGEN färg: en överstyrd ruta ska gå att känna igen utan
				# att man byter till texturvyn
				färg = _material_färg(id)
				if not golv:
					färg = färg.darkened(0.55)
			c.draw_rect(r, färg)


func _rita_rutor(c: Control) -> void:
	var vägg_tex := _tema_tex(floor.theme, "wall")
	var golv_tex := _tema_tex(floor.theme, "floor")
	for y in floor.h:
		for x in floor.w:
			var p := Vector2i(x, y)
			var r := _ruta_rect(p)
			var golv: bool = floor.tiles[y][x] == Dungeon.FLOOR
			var egen := _material_tex(str(floor.ytor.get("%d,%d" % [x, y], "")))
			var tex: Texture2D = egen
			if tex == null:
				tex = golv_tex if golv else vägg_tex
			if tex != null:
				c.draw_texture_rect(tex, r, false)
			else:
				c.draw_rect(r, Color(0.3, 0.29, 0.33) if golv else Color(0.12, 0.12, 0.15))
			if egen != null:
				# en överstyrd ruta får en hake i hörnet, så man ser att den inte följer temat
				c.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, 4)), FÄRG_ACC)


## BILDENS ANVÄNDA DEL. Arken har luft runt figuren (128 px ruta, figuren ~60 px), så ritas hela rutan
## blir en tunna 15 px bred i en 37 px ruta. `get_used_rect` ger figurens egen yta, och då fyller
## rekvisitan sin ruta — det är den skillnaden mellan "en fläck" och "en tunna".
func _prop_yta(art: String) -> Rect2:
	var key := "rekvisit_yta/%s" % art
	if _tex.has(key):
		return _tex[key]
	var tex := _prop_tex(art)
	var yta := Rect2()
	if tex != null:
		var img := tex.get_image()
		if img != null:
			yta = Rect2(img.get_used_rect())
	_tex[key] = yta
	return yta


## Rekvisitan ritas som sin EGEN bild i rutan — man känner igen en tunna på tunnan, inte på en bokstav.
## Figuren skalas in i rutan med bevarat förhållande och står på rutans nederkant, som regeln i spelet.
func _rita_rekvisita(c: Control) -> void:
	for r in floor.rekvisita:
		var p: Vector2i = r.get("pos", Vector2i(-1, -1))
		var rr := _ruta_rect(p)
		var art := str(r.get("art", ""))
		var tex := _prop_tex(art)
		if tex == null:
			c.draw_circle(rr.get_center(), cell * 0.16, FÄRG_ACC)
			continue
		var källa := _prop_yta(art)
		if källa.size.x <= 0.0 or källa.size.y <= 0.0:
			continue
		var skala := minf(rr.size.x * 0.9 / källa.size.x, rr.size.y * 0.9 / källa.size.y)
		var storlek := källa.size * skala
		var övre := Vector2(rr.position.x + (rr.size.x - storlek.x) * 0.5, rr.end.y - storlek.y - rr.size.y * 0.03)
		c.draw_texture_rect_region(tex, Rect2(övre, storlek), källa)


## KANTEN runt varje golvyta. Det är den som gör vyn läsbar: i texturvyn kan temats golv och vägg vara
## samma bild, och då är kanten den enda skillnaden som finns. Ritas bara mot vägg/utanför, alltså
## rummets kontur och inte ett rutnät till.
func _rita_kant(c: Control) -> void:
	var bredd := maxf(1.0, cell * 0.06)
	var k := FÄRG_GOLVKANT
	k.a = 0.9
	for y in floor.h:
		for x in floor.w:
			if floor.tiles[y][x] != Dungeon.FLOOR:
				continue
			var r := _ruta_rect(Vector2i(x, y))
			if y == 0 or floor.tiles[y - 1][x] != Dungeon.FLOOR:
				c.draw_line(r.position, Vector2(r.end.x, r.position.y), k, bredd)
			if y == floor.h - 1 or floor.tiles[y + 1][x] != Dungeon.FLOOR:
				c.draw_line(Vector2(r.position.x, r.end.y), r.end, k, bredd)
			if x == 0 or floor.tiles[y][x - 1] != Dungeon.FLOOR:
				c.draw_line(r.position, Vector2(r.position.x, r.end.y), k, bredd)
			if x == floor.w - 1 or floor.tiles[y][x + 1] != Dungeon.FLOOR:
				c.draw_line(Vector2(r.end.x, r.position.y), r.end, k, bredd)


## Ett materials medelfärg, samplad ur arket och lyft/sänkt till golvets värdeområde — ett kolsvart
## ark (obsidian) får inte läsas som vägg i planvyn.
var _yta_färg := {}

func _material_färg(id: String) -> Color:
	if _yta_färg.has(id):
		return _yta_färg[id]
	var ut := FÄRG_GOLV
	var tex := _material_tex(id)
	if tex != null:
		var img := tex.get_image()
		if img != null:
			# importerade PNG:er kan vara packade: get_pixel på ett packat format läser skräp (mätt i
			# fiendeeditorn), så konvertera först
			img.convert(Image.FORMAT_RGBA8)
			var summa := Vector3.ZERO
			var n := 0
			var steg := maxi(1, img.get_width() / 8)
			var y := 0
			while y < img.get_height():
				var x := 0
				while x < img.get_width():
					var px := img.get_pixel(x, y)
					if px.a > 0.5:
						summa += Vector3(px.r, px.g, px.b)
						n += 1
					x += steg
				y += steg
			if n > 0:
				ut = Color(summa.x / n, summa.y / n, summa.z / n)
	var l := ut.get_luminance()
	if l > 0.02:
		var f := clampf(0.5 / l, 0.8, 1.9)
		ut = Color(clampf(ut.r * f, 0.0, 1.0), clampf(ut.g * f, 0.0, 1.0), clampf(ut.b * f, 0.0, 1.0))
	_yta_färg[id] = ut
	return ut


# --- mus ----------------------------------------------------------------------------------------
func _duk_input(e: InputEvent) -> void:
	if floor == null:
		return
	_skift = e is InputEventWithModifiers and (e as InputEventWithModifiers).shift_pressed
	_ctrl = e is InputEventWithModifiers and (e as InputEventWithModifiers).ctrl_pressed
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		var p := _ruta_vid(mb.position)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zooma(mb.position, 1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zooma(mb.position, 1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panorerar = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_vänster_ner(mb.position, p)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_vänster_upp()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_höger(p)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		var p := _ruta_vid(mm.position)
		hover = p
		if _panorerar:
			pan += mm.relative
			_layout_duk()
			return
		if _box_aktiv:
			_box_till = mm.position
			duk.queue_redraw()
			return
		if _målar:
			# Ett drag ritar en LINJE: mushändelserna hoppar över rutor när pekaren går fort, och då
			# blir ett drag en rad prickar i stället för ett streck.
			if p.x < 0:
				_ruta_från = Vector2i(-1, -1)
				duk.queue_redraw()
				return
			if _ruta_från.x >= 0 and p != _ruta_från:
				_måla_linje(_ruta_från, p)
				_ruta_från = p
			elif _ruta_från.x < 0:
				_måla(p)
				_ruta_från = p
			duk.queue_redraw()
			return
		if _drar:
			var d := Vector2i(roundi((mm.position.x - _drag_punkt.x) / cell),
				roundi((mm.position.y - _drag_punkt.y) / cell))
			var steg: Vector2i = d - _drag_delta
			if steg != Vector2i.ZERO:
				var f := MapIo.flytta(floor, vald, steg)
				if f.is_empty():
					_drag_delta = d
					ändrad = true
				status = f if not f.is_empty() else "flyttar %d nod(er)" % vald.size()
				_stämpla()
			duk.queue_redraw()
			return
		duk.queue_redraw()


func _vänster_ner(pos: Vector2, p: Vector2i) -> void:
	if verktyg != "valj":
		_målar = true
		_ruta_från = p
		if p.x >= 0:
			_måla(p)
		duk.queue_redraw()
		return
	var n := _nod_vid(p) if p.x >= 0 else null
	if n != null:
		if _skift:
			_valj_lägg_till(n)
		elif _ctrl:
			_valj_växla(n)
		else:
			_valj_ensam(n)
			_drar = true
			_drag_punkt = pos
			_drag_delta = Vector2i.ZERO
		_stämpla()
		_uppdatera()
	else:
		if not _skift and not _ctrl:
			vald = []
		_box_aktiv = true
		_box_från = pos
		_box_till = pos
		_stämpla()
		_uppdatera()


func _vänster_upp() -> void:
	if _målar:
		_målar = false
		_ruta_från = Vector2i(-1, -1)
	if _box_aktiv:
		_box_aktiv = false
		var box := Rect2(_box_från, _box_till - _box_från).abs()
		if box.size.x > 3.0 or box.size.y > 3.0:
			for n in floor.nodes:
				if box.intersects(_ruta_rect(n.pos)) and not vald.has(n):
					vald.append(n)
			status = "%d nod(er) i rutan" % vald.size()
	_drar = false
	_drag_punkt = Vector2.ZERO
	_drag_delta = Vector2i.ZERO
	_stämpla()
	_uppdatera()


## Högerklick suddar: noden på rutan, materialöverstyrningen, annars blir rutan vägg — samma vana som
## den gamla editorn, och den enda gesten som inte kräver att man byter verktyg först.
func _höger(p: Vector2i) -> void:
	if p.x < 0:
		return
	if _nod_vid(p) != null:
		_remove_node_at(p)
		status = "nod borttagen på (%d,%d)" % [p.x, p.y]
	elif MapIo.ta_bort_rekvisita(floor, p):
		status = "rekvisitan borttagen på (%d,%d)" % [p.x, p.y]
	elif floor.ytor.has("%d,%d" % [p.x, p.y]):
		floor.ytor.erase("%d,%d" % [p.x, p.y])
		status = "temats ruta igen på (%d,%d)" % [p.x, p.y]
	else:
		floor.tiles[p.y][p.x] = Dungeon.WALL
		status = "vägg på (%d,%d)" % [p.x, p.y]
	ändrad = true
	_uppdatera()


func _måla(p: Vector2i) -> void:
	var f := _place(p)
	if not f.is_empty():
		status = f
	elif verktyg == "nod":
		status = "%s på (%d,%d)" % [nod_kind, p.x, p.y]
	elif verktyg == "ruta":
		status = "%s på (%d,%d)" % ["golv" if ruta_mark == Dungeon.FLOOR else "vägg", p.x, p.y]
	elif verktyg == "material":
		status = "%s på (%d,%d)" % [yta_material if not yta_material.is_empty() else "temats ruta", p.x, p.y]
	elif verktyg == "rekvisita":
		status = "%s på (%d,%d)" % [rekvisit_art, p.x, p.y]
	elif verktyg == "fiende":
		status = "strid med %s på (%d,%d)" % [fiende_art if not fiende_art.is_empty() else "slumpad", p.x, p.y]
	_stämpla()
	duk.queue_redraw()


## Bresenham mellan två rutor, så ett snabbt drag blir ett streck utan gluggar.
func _måla_linje(från: Vector2i, till: Vector2i) -> void:
	var x0 := från.x
	var y0 := från.y
	var dx := absi(till.x - x0)
	var dy := -absi(till.y - y0)
	var sx := 1 if x0 < till.x else -1
	var sy := 1 if y0 < till.y else -1
	var err := dx + dy
	while true:
		_måla(Vector2i(x0, y0))
		if x0 == till.x and y0 == till.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## Zoomar kring pekaren: punkten under musen ska stå still. Ett absolut läge hade hoppat så fort
## vyn är skalad — samma invariant som världskarte-editorns drag.
func _zooma(pos: Vector2, faktor: float) -> void:
	var före: Vector2i = _ruta_vid(pos)
	var offset := Vector2.ZERO
	if före.x >= 0:
		offset = (pos - anka) / cell
	zoom = clampf(zoom * faktor, 0.4, 6.0)
	_layout_duk()
	if före.x >= 0:
		pan += pos - anka - offset * cell
		_layout_duk()
	_stämpla()


# --- tangentbord --------------------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := e as InputEventKey
	var key := k.keycode
	if key >= KEY_1 and key <= KEY_6:
		_sätt_verktyg("nod", str(NODE_TOOLS[key - KEY_1]["kind"]))
	elif key == KEY_V:
		_sätt_verktyg("valj")
	elif key == KEY_G:
		verktyg = "ruta"
		ruta_mark = Dungeon.FLOOR
		_markera_verktyg()
		_stämpla()
	elif key == KEY_X or key == KEY_BACKSPACE:
		verktyg = "ruta"
		ruta_mark = Dungeon.WALL
		_markera_verktyg()
		_stämpla()
	elif key == KEY_S:
		save()
	elif key == KEY_L:
		load_or_generate()
		_uppdatera()
	elif key == KEY_N:
		storlek_dialog.popup_centered()
	elif key == KEY_P:
		playtest()
	elif key == KEY_T:
		_nasta_tema(1)
	elif key == KEY_Y:
		_nasta_tema(-1)
	elif key == KEY_B:
		save_stage()
	elif key == KEY_O:
		save_block()
	elif key == KEY_COMMA:
		nasta_bana(-1)
	elif key == KEY_PERIOD:
		nasta_bana(1)
	elif key == KEY_EQUAL or key == KEY_PLUS:
		storlek(1)
	elif key == KEY_MINUS:
		storlek(-1)
	elif key == KEY_BRACKETLEFT:
		_våning(-1)
	elif key == KEY_BRACKETRIGHT:
		_våning(1)
	elif key == KEY_DELETE:
		_ta_bort_vald()
	elif key == KEY_D and k.ctrl_pressed:
		_kopiera_vald()
	elif key == KEY_F:
		_rama_in()
	elif key == KEY_K:
		_sätt_vy("textur" if vy == "plan" else "plan")
	elif key == KEY_LEFT:
		_putta(Vector2i(-1, 0))
	elif key == KEY_RIGHT:
		_putta(Vector2i(1, 0))
	elif key == KEY_UP:
		_putta(Vector2i(0, -1))
	elif key == KEY_DOWN:
		_putta(Vector2i(0, 1))
	elif key == KEY_M:
		till_menyn()
	elif key == KEY_Q or key == KEY_ESCAPE:
		get_tree().quit()


## Utgången tillbaka till spelet: `change_scene_to_file` lämnar editorn och startar menyn. Samma väg
## som menyns genväg in hit, fast baklänges — Q/ESC stänger hela spelet, M går till menyn.
func till_menyn() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _våning(steg: int) -> void:
	floor_index = clampi(floor_index + steg, 0, max(0, stage.floors - 1))
	load_or_generate()
	_uppdatera()


## STORLEKEN NÄR MAN SKAPAR ETT NYTT RUM (M154). Alex: *"Jag vill själv kunna avgöra rum-storlek, så
## låt mig ange t ex 6x6, 9x3 eller vad jag behöver när jag skapar ett nytt rum."* N öppnar en liten
## ruta: bredd och höjd var för sig, 3-64 rutor. Ett block ÄR en våning, så storleken man skriver är
## exakt den man får — och `O` sparar den som block i data/blocks/.
var storlek_dialog: AcceptDialog = null
var _sd_bredd: SpinBox = null
var _sd_höjd: SpinBox = null


func _bygg_storlek_dialog() -> void:
	storlek_dialog = ConfirmationDialog.new()
	storlek_dialog.title = "Nytt rum (block)"
	storlek_dialog.ok_button_text = "Skapa"
	storlek_dialog.cancel_button_text = "Avbryt"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_sd_bredd = _storleksrad(box, "Bredd", floor.w if floor != null else 7)
	_sd_höjd = _storleksrad(box, "Höjd", floor.h if floor != null else 7)
	storlek_dialog.add_child(box)
	storlek_dialog.confirmed.connect(_skapa_rum)
	add_child(storlek_dialog)


func _storleksrad(box: VBoxContainer, text: String, värde: int) -> SpinBox:
	var rad := HBoxContainer.new()
	rad.add_theme_constant_override("separation", 10)
	var etikett := _etikett(text, 12, FÄRG_TEXT)
	etikett.custom_minimum_size = Vector2(64, 0)
	var ruta := SpinBox.new()
	ruta.min_value = 3
	ruta.max_value = 64
	ruta.step = 1
	ruta.value = värde
	ruta.custom_minimum_size = Vector2(96, 0)
	rad.add_child(etikett)
	rad.add_child(ruta)
	box.add_child(rad)
	return ruta


## Skapar våningen/rummet i den storlek man skrev. Samma nollställning som N gjorde förut.
func _skapa_rum() -> void:
	var w := clampi(int(_sd_bredd.value), 3, 64)
	var h := clampi(int(_sd_höjd.value), 3, 64)
	floor = MapIo.blank(stage.id, floor_index, w, h)
	genererad = false
	ändrad = false
	fel = []
	vald = []
	zoom = 1.0
	pan = Vector2.ZERO
	status = "nytt rum %d×%d — rita det och tryck O för att spara som block" % [w, h]
	_layout_duk()
	_uppdatera()


func _ny_våning() -> void:
	floor = MapIo.blank(stage.id, floor_index)
	genererad = false
	ändrad = false
	fel = []
	vald = []
	zoom = 1.0
	pan = Vector2.ZERO
	status = "ny tom våning (%dx%d)" % [floor.w, floor.h]
	_layout_duk()
	_uppdatera()


# --- egenskapspanelen ----------------------------------------------------------------------------

func _tom(box: Node) -> void:
	# remove_child först: queue_free ensam låter den gamla raden ligga kvar i en bildruta, och en
	# panel som byggs om vid varje klick visar då dubbletter.
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _rubrik(text: String) -> void:
	var l := _etikett(text, 11, FÄRG_DIM)
	l.custom_minimum_size.y = 18
	insp_box.add_child(l)


## En rad med etikett och två knappar: ← ändrar ned, → upp. Samma form för varje fält, så en ny rad
## inte kräver en ny inlärning.
func _rad(etikett: String, värde: String, ner: Callable, upp: Callable, tips := "") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var l := _etikett(etikett, 12, FÄRG_DIM)
	l.custom_minimum_size.x = 104
	l.clip_text = true
	h.add_child(l)
	h.add_child(_knapp("◀", tips, ner, 24))
	var v := _etikett(värde, 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.clip_text = true
	v.tooltip_text = tips
	h.add_child(v)
	h.add_child(_knapp("▶", tips, upp, 24))
	insp_box.add_child(h)


func _knapprad(texter: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for par in texter:
		var b := _knapp(str(par[0]), str(par[1]), par[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 26
		h.add_child(b)
	insp_box.add_child(h)


func _uppdatera() -> void:
	if insp_box == null or floor == null:
		return
	_tom(insp_box)
	_rubrik("EGENSKAPER")
	if vald.is_empty():
		insp_box.add_child(_etikett("Inget valt — klicka på en nod i kartan.", 12, FÄRG_DIM))
	else:
		_valda_rader()
	_rubrik("VÅNINGEN")
	_rad("Bana", "%s  %s" % [stage.id, Tr.name_of("stage", stage.id, stage.name)],
		nasta_bana.bind(-1), nasta_bana.bind(1), "byt bana (,/.)")
	_rad("Våning", "%d / %d" % [floor_index + 1, stage.floors],
		_våning.bind(-1), _våning.bind(1), "byt våning ([ ])")
	_rad("Storlek", "%d × %d" % [floor.w, floor.h], storlek.bind(-1), storlek.bind(1),
		"+/- ändrar rutnätet (krympning kastar golv och pekare)")
	_rad("Tema", floor.theme if not floor.theme.is_empty() else "(platt)",
		_nasta_tema.bind(-1), _nasta_tema.bind(1), "T/Y byter grafiktema")
	_räknare_rad()
	if genererad:
		insp_box.add_child(_etikett("GENERERAD — spara för att behålla", 12, Color(0.95, 0.75, 0.35)))
	_rubrik("BANAN")
	_rad("Regel", "%s — %s" % [Regler.namn(stage.regel), Regler.text(stage.regel)],
		_meta_klick.bind(0, -1), _meta_klick.bind(0, 1), "banans mutator")
	for i in META_FÄLT.size():
		if i == 0:
			continue                            # regeln står redan, med sin verkan
		_rad(str(META_FÄLT[i]), _meta_värde(i), _meta_klick.bind(i, -1), _meta_klick.bind(i, 1))
	_rubrik("KONTROLL")
	fel = MapIo.validate(floor)
	if fel.is_empty():
		insp_box.add_child(_etikett("Våningen går att spela.", 12, FÄRG_ACC))
	else:
		insp_box.add_child(_etikett("%d fel — går inte att spara" % fel.size(), 12, FÄRG_FEL))
		for f in fel.slice(0, 8):
			var l := _etikett("· %s" % f, 11, FÄRG_FEL)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			insp_box.add_child(l)
	_bygg_outliner()
	_stämpla()


func _räknare_rad() -> void:
	var golv := 0
	for y in floor.h:
		for x in floor.w:
			if floor.tiles[y][x] == Dungeon.FLOOR:
				golv += 1
	var strider := floor.nodes_of_kind("encounter").size()
	var facklor := floor.nodes_of_kind("torch").size()
	var fiender := {}
	for n in floor.nodes:
		if not n.enemy_id.is_empty():
			fiender[n.enemy_id] = true
	var andel := 100.0 * float(golv) / maxf(1.0, float(floor.w * floor.h))
	var l := _etikett("objekt %d · strider %d · facklor %d · fiender %d · golv %d %% · rekvisita %d"
		% [floor.nodes.size(), strider, facklor, fiender.size(), int(round(andel)), floor.rekvisita.size()],
		11, FÄRG_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_box.add_child(l)


## Den valda nodens egna fält. Fiendelistan är banans pool (samma som `MapIo.placera` väljer ur), så
## man inte kan sätta en fiende banan aldrig spelar.
func _valda_rader() -> void:
	var n: Dungeon.FloorNode = vald[0]
	var d := _tool_for(n.kind)
	insp_box.add_child(_etikett("%s  på (%d,%d)%s" % [d.get("namn", n.kind), n.pos.x, n.pos.y,
		"" if vald.size() == 1 else "  +%d till" % (vald.size() - 1)], 13,
		d.get("färg", FÄRG_TEXT)))
	if vald.size() > 1:
		_knapprad([["Ta bort alla", "ta bort urvalet (Del)", _ta_bort_vald]])
		return
	if n.kind == "encounter" or n.kind == "boss":
		_rad("Fiende", _fiende_text(n), _fiende.bind(-1), _fiende.bind(1), "fienden på rutan")
	_rad("Guld", str(n.gold), _guld.bind(-5), _guld.bind(5), "kistans/fiendens guld")
	_rad("XP", str(n.xp), _xp.bind(-1), _xp.bind(1), "erfarenhet")
	_knapprad([["Ta bort", "ta bort noden (Del)", _ta_bort_vald],
		["Kopiera", "kopia på ledig ruta intill (Ctrl+D)", _kopiera_vald]])


func _fiende_text(n: Dungeon.FloorNode) -> String:
	if n.enemy_id.is_empty():
		return "(ingen)"
	return "%s  %s" % [n.enemy_id, Tr.name_of("enemy", n.enemy_id, n.enemy_id)]


func _fiende_pool() -> Array:
	var pool := Enemies.by_tier(bestiary, stage.tiers)
	var ids := []
	for e in pool:
		ids.append(e.id)
	ids.sort()
	return ids


## Ett fiendeval skriver ALLA tre fälten: id, guld och xp hör ihop i bestiariet, och att bara byta id
## hade gett en fiende som lovar fel belöning.
func _fiende(steg: int) -> void:
	if vald.is_empty():
		return
	var n: Dungeon.FloorNode = vald[0]
	var ids := _fiende_pool()
	if ids.is_empty():
		status = "bestiariet har ingen fiende för tiers %s" % str(stage.tiers)
		return
	var i := ids.find(n.enemy_id)
	i = (i + steg + ids.size()) % ids.size() if i >= 0 else 0
	var e = bestiary[ids[i]]
	n.enemy_id = e.id
	n.gold = e.gold
	n.xp = e.xp
	ändrad = true
	status = "fiende: %s" % n.enemy_id
	_uppdatera()


func _guld(steg: int) -> void:
	if vald.is_empty():
		return
	var n: Dungeon.FloorNode = vald[0]
	n.gold = clampi(n.gold + steg, 0, 9999)
	ändrad = true
	_uppdatera()


func _xp(steg: int) -> void:
	if vald.is_empty():
		return
	var n: Dungeon.FloorNode = vald[0]
	n.xp = clampi(n.xp + steg, 0, 9999)
	ändrad = true
	_uppdatera()


## Objektlistan: en rad per nod, klick väljer och ramar in. Byggs om efter varje ändring, så den
## aldrig visar en nod som inte finns.
func _bygg_outliner() -> void:
	if outliner == null:
		return
	outliner.clear()
	_outliner_noder = []
	var sorterad := floor.nodes.duplicate()
	var nyckel := func(n): return "%s%03d%03d" % [n.kind, n.pos.y, n.pos.x]
	sorterad.sort_custom(func(a, b): return nyckel.call(a) < nyckel.call(b))
	for n in sorterad:
		var d := _tool_for(n.kind)
		var text := "%s  %s (%d,%d)" % [d.get("ch", "?"), d.get("namn", n.kind), n.pos.x, n.pos.y]
		if not n.enemy_id.is_empty():
			text += "  · %s" % Tr.name_of("enemy", n.enemy_id, n.enemy_id)
		outliner.add_item(text)
		_outliner_noder.append(n)
	outliner_rubrik.text = "OBJEKT  (%d)" % floor.nodes.size()


func _outliner_vald(i: int) -> void:
	if i < 0 or i >= _outliner_noder.size():
		return
	_valj_ensam(_outliner_noder[i])
	_uppdatera()


## Toppraden och statusraden. `hover` ger rutan under pekaren, så man vet VAD man är på väg att
## ändra innan man klickar — en yta utan den raden tvingar fram en gissning per klick.
func _stämpla() -> void:
	if floor == null or stage == null:
		return
	if _l_bana != null:
		_l_bana.text = Tr.name_of("stage", stage.id, stage.name)
	if _l_våning != null:
		_l_våning.text = "våning %d/%d" % [floor_index + 1, stage.floors]
	if _l_läge != null:
		_l_läge.text = "OSPARD *" if ändrad else ("genererad" if genererad else "sparad")
		_l_läge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35) if ändrad else FÄRG_DIM)
	if status_rad == null:
		return
	var bitar: Array = ["vy: %s" % ("plan" if vy == "plan" else "textur"), _pensel_text()]
	if hover.x >= 0:
		var n := _nod_vid(hover)
		var vad := "golv" if floor.is_floor_at(hover) else "vägg"
		if n != null:
			vad = n.kind if n.enemy_id.is_empty() else "%s %s" % [n.kind, n.enemy_id]
		var r := MapIo.rekvisita_vid(floor, hover)
		if not r.is_empty():
			vad += " + %s" % r.get("art", "")
		bitar.append("(%d,%d) %s" % [hover.x, hover.y, vad])
	bitar.append(status)
	status_rad.text = "  ·  ".join(bitar)


func _pensel_text() -> String:
	match verktyg:
		"ruta":
			return "pensel: %s" % ("golv" if ruta_mark == Dungeon.FLOOR else "vägg")
		"nod":
			return "pensel: %s" % nod_kind
		"material":
			return "pensel: %s" % (yta_material if not yta_material.is_empty() else "temats ruta")
		"rekvisita":
			return "pensel: %s" % (rekvisit_art if not rekvisit_art.is_empty() else "ingen rekvisit vald")
		"fiende":
			return "pensel: strid med %s" % (fiende_art if not fiende_art.is_empty() else "slumpad fiende")
	return "verktyg: välj / flytta"


# --- spara, spela, banan ------------------------------------------------------------------------

func save() -> void:
	fel = MapIo.save_map(floor)
	if fel.is_empty():
		genererad = false
		ändrad = false
		status = "sparad: %s" % MapIo.path_for(floor.stage_id, floor.index).get_file()
		print("karta sparad: %s" % ProjectSettings.globalize_path(MapIo.path_for(floor.stage_id, floor.index)))
	else:
		status = "kan inte spara — %d fel" % fel.size()
		for f in fel:
			print("  %s" % f)
	_uppdatera()


func playtest() -> void:
	fel = MapIo.validate(floor)
	if not fel.is_empty():
		status = "rätta felen först (%d)" % fel.size()
		for f in fel:
			print("  %s" % f)
		_uppdatera()
		return
	# Spara först: annars spelar man en våning som inte finns på disk, och tror att den gjorde det.
	var sista := MapIo.save_map(floor)
	if not sista.is_empty():
		status = "kunde inte spara före playtest"
		_uppdatera()
		return
	var f := FileAccess.open("user://playtest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage_id": floor.stage_id, "floor": floor.index}))
	f.close()
	get_tree().change_scene_to_file("res://main.tscn")


## Spara BANAN (stage-filen), inte våningen. Egen tangent (B) därför att de är två olika filer med
## två olika fel — och en våning som sparats medan banan är trasig ser ut som en lyckad körning.
func save_stage() -> void:
	if Stages.skriv(stage):
		status = "banan sparad: %s" % (Stages.DIR + stage.id + ".json").get_file()
		print("bana sparad: %s" % ProjectSettings.globalize_path(Stages.DIR + stage.id + ".json"))
	else:
		status = "kunde inte spara banan"
		print("  bana: %s" % stage.id)
	_stämpla()


## SPARA SOM BLOCK (M153): våningen man ritat blir en bit som generatorn kan lägga in i ett rum.
## Samma filformat som en karta, egen mapp — och start/boss/nedstigning TAS BORT, för de rutor ägs av
## den våning blocket hamnar i. Ett block med en start hade flyttat spelaren till en slumpad plats.
func save_block() -> void:
	var d: Dictionary = MapIo.to_dict(floor)
	d.erase("start")
	d.erase("boss")
	d.erase("shovel")
	# INGA NODER I ETT BLOCK (M153): kistor, facklor och strider räknas av generatorn, och ett block
	# som la dit en egen fackla sprängde facklornas tak. /rapportera/ att de togs bort, så man ser det.
	var bort := (d.get("nodes", []) as Array).size()
	d["nodes"] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Blockar.MAPP))
	var sökväg := "%s/%s_%d.json" % [Blockar.MAPP, floor.stage_id, floor.index]
	var fil := FileAccess.open(sökväg, FileAccess.WRITE)
	if fil == null:
		status = "kunde inte skriva blocket: %s" % sökväg.get_file()
		return
	fil.store_string(JSON.stringify(d, " ", false))
	fil.close()
	status = "block sparat: %s (%d×%d, %d noder togs bort)" % [
		sökväg.get_file(), floor.w, floor.h, bort]
	print("block sparat: %s" % ProjectSettings.globalize_path(sökväg))


func nasta_bana(steg: int) -> void:
	var ids := stages.keys()
	ids.sort()
	var i := ids.find(stage.id)
	stage = stages[ids[(i + steg + ids.size()) % ids.size()]]
	floor_index = clampi(floor_index, 0, max(0, stage.floors - 1))
	load_or_generate()
	status = "bana: %s" % stage.id
	_uppdatera()


## Storleken på rutnätet. Rutorna som får plats behålls (ankrade i övre vänstra hörnet), resten
## blir vägg — en krympning kastar bort golv, och det står i statusraden så det inte sker i tysthet.
func storlek(steg: int) -> void:
	var ny := clampi(floor.w + steg, 9, 31)
	if ny == floor.w:
		return
	var kastat := 0
	for y in floor.h:
		for x in range(min(ny, floor.w), floor.w):
			if floor.tiles[y][x] == Dungeon.FLOOR:
				kastat += 1
	var gamla := floor.tiles
	floor.w = ny
	floor.h = ny
	floor.tiles = []
	for y in floor.h:
		var rad := []
		for x in floor.w:
			if y < gamla.size() and x < gamla[y].size():
				rad.append(gamla[y][x])
			else:
				rad.append(Dungeon.WALL)
		floor.tiles.append(rad)
	# Noder utanför den nya kanten tas bort, annars pekar de på en ruta som inte finns.
	var behåll := []
	for n in floor.nodes:
		if n.pos.x < floor.w and n.pos.y < floor.h:
			behåll.append(n)
	floor.nodes = behåll
	# Pekarna (start/boss/nedstigning) är egna fält vid sidan av nodlistan. Faller deras ruta utanför
	# den nya kanten står de kvar och pekar på en ruta som inte finns — nollställ dem, annars sparar
	# kontrollen en våning som ser giltig ut men inte går att starta.
	var utanför := func(p: Vector2i) -> bool: return p.x >= floor.w or p.y >= floor.h
	if utanför.call(floor.start):
		floor.start = Vector2i(-1, -1)
	if utanför.call(floor.boss_pos):
		floor.boss_pos = Vector2i(-1, -1)
	if utanför.call(floor.shovel_pos):
		floor.shovel_pos = Vector2i(-1, -1)
	vald = []
	ändrad = true
	status = "storlek %dx%d%s" % [floor.w, floor.h,
		(" — %d golvrutor föll bort" % kastat) if kastat > 0 else ""]
	_layout_duk()
	_uppdatera()


# --- banans fält ---------------------------------------------------------------------------------

func _meta_värde(i: int) -> String:
	match META_FÄLT[i]:
		"regel":
			return Regler.namn(stage.regel)
		"tema":
			return Stages.theme_for(stage, floor_index)
		"våningar":
			return str(stage.floors)
		"svårighet":
			return str(stage.difficulty)
		"tiers":
			return str(stage.tiers)
		"strider/våning":
			return str(stage.encounters_per_floor)
		"boss":
			return stage.boss if not stage.boss.is_empty() else "(ingen)"
		"sista boss":
			return stage.final_boss if not stage.final_boss.is_empty() else "(ingen)"
		"guld-bonus":
			return "%.2f" % stage.gold_bonus
		"xp-bonus":
			return "%.2f" % stage.xp_bonus
		"ny strid":
			return vald_fiende if not vald_fiende.is_empty() else "(genererad)"
	return ""


func _cykla(lista: Array, nu, steg: int):
	var i := lista.find(nu)
	if i < 0:
		i = 0
	return lista[(i + steg + lista.size()) % lista.size()]


## En knapp i panelen väljer sin rad först, så `meta_vald` säger vilket fält som ändrades senast.
func _meta_klick(i: int, steg: int) -> void:
	meta_vald = i
	_meta_ändra(steg)


func _meta_ändra(steg: int) -> void:
	var fält: String = str(META_FÄLT[meta_vald])
	match fält:
		"regel":
			stage.regel = Regler.nasta(stage.regel, steg)
		"tema":
			var teman := [""] + MapIo.THEMES
			var nytt := str(_cykla(teman, Stages.theme_for(stage, floor_index), steg))
			# Temat bor både i banan (per våning) och i våningen. Skriv båda, annars ser man sitt val
			# i ritytan men banan spelar ett annat när våningen är genererad.
			while stage.floor_themes.size() <= floor_index:
				stage.floor_themes.append(stage.theme)
			stage.floor_themes[floor_index] = nytt
			floor.theme = nytt
		"våningar":
			stage.floors = clampi(stage.floors + steg, 1, 8)
		"svårighet":
			stage.difficulty = clampi(stage.difficulty + steg, 1, 9)
		"tiers":
			stage.tiers = _cykla(TIER_SETT, stage.tiers, steg)
		"strider/våning":
			stage.encounters_per_floor = clampi(stage.encounters_per_floor + steg, 1, 12)
		"boss", "sista boss":
			var pool := Enemies.by_tier(bestiary, [1, 2, 3, 4])
			if pool.is_empty():
				return
			var ids := []
			for e in pool:
				ids.append(e.id)
			ids.sort()
			var nu := stage.boss if fält == "boss" else stage.final_boss
			var nytt_id := str(_cykla(ids, nu, steg))
			if fält == "boss":
				stage.boss = nytt_id
			else:
				stage.final_boss = nytt_id
		"guld-bonus":
			stage.gold_bonus = clampf(snappedf(stage.gold_bonus + steg * 0.25, 0.25), -1.0, 4.0)
		"xp-bonus":
			stage.xp_bonus = clampf(snappedf(stage.xp_bonus + steg * 0.25, 0.25), -1.0, 4.0)
		"ny strid":
			var pool2 := Enemies.by_tier(bestiary, stage.tiers)
			if pool2.is_empty():
				return
			var ids2 := [""]
			for e in pool2:
				ids2.append(e.id)
			ids2.sort()
			vald_fiende = str(_cykla(ids2, vald_fiende, steg))
	status = "%s: %s" % [fält, _meta_värde(meta_vald)]
	_uppdatera()
