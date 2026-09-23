## Karteditorn: rita en våning för hand och spara den till data/maps/<bana>_<våning>.json.
##
##   tools/editor.sh [bana] [våning]        (standard: stage_01 våning 1)
##
## Varför: spelets generator gissar former. Referensens rum är handbyggda (research/08-referensrum.md
## — 67 rum, varje relik har sitt eget), och en människa ritar bättre rum än en BSP-klyvning. Den
## här ytan är gjord för att rita snabbt: peka, klicka, spara. Våningen går genom samma kontroller
## som en genererad — går den inte att spela får den inte sparas, och felet står i panelen.
##
## Ytan är spelets egen logiska yta (480x270) — men fönstret är större och projektet ritar i RIKTIGA
## pixlar (`window/stretch/mode="disabled"`, samma val som gör spelets HUD skarp i stället för
## uppskalad). Siffrorna nedan är därför gjorda för 480x270, och `_skala()` räknar om dem till
## fönstret. Förut ritades 480x270 rakt av i ett 1280x720-fönster: hela editorn hamnade i övre vänstra
## hörnet med 8 px text (mätt: 425x269 px = 12 % av fönstret).
extends Control

const BASE := Vector2(480.0, 270.0)     ## ytan siffrorna nedan är gjorda för
const PANEL_BREDD := 242.0              ## panelens platsbehov i BASE-pixlar (längsta raden + marginal)
const PANEL_HÖJD := 330.0               ## panelens höjd i BASE-pixlar, räknad från fönstrets överkant
                                        ## ner till sista statusraden. Fellistan kapas mot kanten.

var s := 1.0                            ## panelens skalning mot BASE, kapad så panelen ryms på höjden
var cell := 13.0                        ## rutans kant i riktiga pixlar
var origin := Vector2(6, 24)            ## ritytans övre vänstra hörn
var panel_x := 238.0                    ## panelens vänsterkant

## Nodtyperna i den ordning tangenterna 1-6 väljer dem. Bokstaven är vad som ritas på rutan.
const NODE_TOOLS := [
	{"kind": "start", "ch": "S", "färg": Color(0.4, 0.95, 0.5), "namn": "start"},
	{"kind": "encounter", "ch": "E", "färg": Color(0.95, 0.42, 0.38), "namn": "strid"},
	{"kind": "boss", "ch": "B", "färg": Color(0.95, 0.4, 0.9), "namn": "boss"},
	{"kind": "shovel", "ch": "N", "färg": Color(0.45, 0.85, 0.95), "namn": "nedstigning"},
	{"kind": "chest", "ch": "K", "färg": Color(0.95, 0.82, 0.35), "namn": "kista"},
	{"kind": "torch", "ch": "F", "färg": Color(0.95, 0.62, 0.3), "namn": "fackla"},
]

var stages: Dictionary = {}
var bestiary: Dictionary = {}
var stage: Stages.StageDef = null
var floor_index := 0
var floor: Dungeon.Floor = null
var tool := 1                      ## index i NODE_TOOLS, eller -1 för markborste
var mark := Dungeon.FLOOR          ## markborstens ruta (golv/vägg)
var status := ""
var fel: Array = []
var genererad := false             ## utgångsläget kom ur generatorn, inte ur en fil
var cursor := Vector2i(-1, -1)
var målar := false
var _tex := {}                     ## temarutor för ritytan, cachade per tema/ruta

func _ready() -> void:
	stages = Stages.load_all()
	bestiary = Enemies.load_all()
	var args := OS.get_cmdline_user_args()
	var stage_id: String = args[0] if args.size() > 0 else "stage_01"
	floor_index = int(args[1]) if args.size() > 1 else 0
	stage = stages.get(stage_id)
	if stage == null:
		push_error("okänd bana: %s" % stage_id)
		stage = stages.values()[0]
	load_or_generate()
	set_process_input(true)
	queue_redraw()
	# Felsökningsflagga, samma vana som spelet: `-- shot` fotograferar editorn och avslutar, så
	# ytan går att granska utan att någon sitter framför den.
	if OS.get_cmdline_user_args().has("shot"):
		await get_tree().create_timer(1.0).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://editor.png")
		print("skärmbild: %s" % ProjectSettings.globalize_path("user://editor.png"))
		get_tree().quit()

## Ladda filen om den finns — annars generatorns våning, så att man alltid börjar med något som går
## att spela i stället för en tom yta.
func load_or_generate() -> void:
	fel = []
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
	queue_redraw()

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

## Nästa tema i listan. Tomt tema ("platt") är med i rundan, så man kan se skillnaden mot att inte
## ha något tema alls.
func _nasta_tema(steg: int) -> void:
	var lista := [""] + MapIo.THEMES
	var i := lista.find(floor.theme)
	if i < 0:
		i = 0
	i = (i + steg + lista.size()) % lista.size()
	floor.theme = str(lista[i])
	status = "tema: %s" % (floor.theme if not floor.theme.is_empty() else "(platt)")
	print("editorn: tema %s på %s våning %d" % [floor.theme, stage.id, floor_index + 1])
	queue_redraw()

func _node_at(p: Vector2i) -> Dungeon.FloorNode:
	for n in floor.nodes:
		if n.pos == p:
			return n
	return null

func _remove_node_at(p: Vector2i) -> void:
	# Reglerna bor i MapIo (samma som spelets byggläge): pekarna start/boss/nedstigning måste nollställas
	# när deras ruta töms, och det står på ett ställe i stället för två.
	MapIo.ta_bort(floor, p)

func _place(p: Vector2i) -> void:
	if tool < 0:
		floor.tiles[p.y][p.x] = mark
		if mark == Dungeon.WALL:
			_remove_node_at(p)          # en vägg kan inte bära en nod
		return
	# Reglerna bor i MapIo — samma som spelets byggläge (F1) använder: en nod per ruta, guldet ur banans
	# svårighet, fienden deterministiskt ur banan/våningen/rutan, och pekarna nollställs när rutan töms.
	# Den valda fienden (meta-raden "ny strid") följer med som argument och går före slumptalet.
	var d: Dictionary = NODE_TOOLS[tool]
	var fel := MapIo.placera(floor, str(d["kind"]), p, stage, bestiary, vald_fiende)
	status = fel

func _cell_at(pos: Vector2) -> Vector2i:
	var p := Vector2i(int((pos.x - origin.x) / cell), int((pos.y - origin.y) / cell))
	if p.x < 0 or p.y < 0 or p.x >= floor.w or p.y >= floor.h:
		return Vector2i(-1, -1)
	return p

func _gui_input(event: InputEvent) -> void:
	if floor == null:
		return
	if event is InputEventMouseButton and event.pressed:
		målar = true
		var p := _cell_at(event.position)
		if p.x < 0:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place(p)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Högerklick suddar: nod bort, eller vägg om rutan är tom.
			if _node_at(p) != null:
				_remove_node_at(p)
			else:
				floor.tiles[p.y][p.x] = Dungeon.WALL
		queue_redraw()
	elif event is InputEventMouseButton and not event.pressed:
		målar = false
	elif event is InputEventMouseMotion:
		var p := _cell_at(event.position)
		if p != cursor:
			cursor = p
			queue_redraw()
		if målar and p.x >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_place(p)
			queue_redraw()

## Utgången tillbaka till spelet: `change_scene_to_file` lämnar editorn och startar menyn. Samma väg
## som menyns genväg in hit, fast baklänges — Q/ESC stänger hela spelet, M går till menyn.
func till_menyn() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_1 and key <= KEY_6:
		tool = key - KEY_1
		status = "verktyg: %s" % NODE_TOOLS[tool]["namn"]
	elif key == KEY_G:
		tool = -1
		mark = Dungeon.FLOOR
		status = "verktyg: golv (vänster), vägg (höger)"
	elif key == KEY_V:
		tool = -1
		mark = Dungeon.WALL
		status = "verktyg: vägg"
	elif key == KEY_S:
		save()
	elif key == KEY_L:
		load_or_generate()
	elif key == KEY_N:
		floor = MapIo.blank(stage.id, floor_index)
		genererad = false
		fel = []
		status = "ny tom våning (17x17)"
	elif key == KEY_P:
		playtest()
	elif key == KEY_T:
		_nasta_tema(1)
	elif key == KEY_Y:
		_nasta_tema(-1)
	elif key == KEY_UP:
		meta_vald = (meta_vald - 1 + META_FÄLT.size()) % META_FÄLT.size()
		status = "%s: %s" % [META_FÄLT[meta_vald], _meta_värde(meta_vald)]
	elif key == KEY_DOWN:
		meta_vald = (meta_vald + 1) % META_FÄLT.size()
		status = "%s: %s" % [META_FÄLT[meta_vald], _meta_värde(meta_vald)]
	elif key == KEY_LEFT:
		_meta_ändra(-1)
	elif key == KEY_RIGHT:
		_meta_ändra(1)
	elif key == KEY_B:
		save_stage()
	elif key == KEY_COMMA:
		nasta_bana(-1)
	elif key == KEY_PERIOD:
		nasta_bana(1)
	elif key == KEY_EQUAL or key == KEY_PLUS:
		storlek(1)
	elif key == KEY_MINUS:
		storlek(-1)
	elif key == KEY_BRACKETLEFT:
		floor_index = max(0, floor_index - 1)
		load_or_generate()
	elif key == KEY_BRACKETRIGHT:
		floor_index = min(stage.floors - 1, floor_index + 1)
		load_or_generate()
	elif key == KEY_M:
		till_menyn()
	elif key == KEY_Q or key == KEY_ESCAPE:
		get_tree().quit()
	queue_redraw()

func save() -> void:
	fel = MapIo.save_map(floor)
	if fel.is_empty():
		genererad = false
		status = "sparad: %s" % MapIo.path_for(floor.stage_id, floor.index).get_file()
		print("karta sparad: %s" % ProjectSettings.globalize_path(MapIo.path_for(floor.stage_id, floor.index)))
	else:
		status = "kan inte spara — %d fel" % fel.size()
		for f in fel:
			print("  %s" % f)

func playtest() -> void:
	fel = MapIo.validate(floor)
	if not fel.is_empty():
		status = "rätta felen först (%d)" % fel.size()
		for f in fel:
			print("  %s" % f)
		return
	# Spara först: annars spelar man en våning som inte finns på disk, och tror att den gjorde det.
	var sista := MapIo.save_map(floor)
	if not sista.is_empty():
		status = "kunde inte spara före playtest"
		return
	var f := FileAccess.open("user://playtest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage_id": floor.stage_id, "floor": floor.index}))
	f.close()
	get_tree().change_scene_to_file("res://main.tscn")

# --- ritning -----------------------------------------------------------------
## Ytan: panelen ritas med `s`, rutnätet med `cell` (platsen som blir över när panelen tagit sin).
## Anropas överst i _draw(), så `size` alltid är den senaste fönsterstorleken utan en enda signal —
## och `_cell_at` räknar med samma tal som den senaste ritningen.
func _skala() -> void:
	var fönster := clampf(minf(size.x / BASE.x, size.y / BASE.y), 1.0, 8.0)
	# Panelen (som är den högsta av de två) får aldrig bli högre än fönstret: sista raden måste synas.
	# Höjden räknas från fönstrets överkant, alltså är det PANEL_HÖJD — inte origin.y + PANEL_HÖJD.
	s = minf(fönster, size.y / PANEL_HÖJD)
	origin = Vector2(6, 24) * s
	# Platsen som blir över: panelens bredd och den nedersta statusraden är redan borta.
	var kvar := Vector2(maxf(96.0, size.x - origin.x - PANEL_BREDD * s - 10.0 * s),
		maxf(96.0, size.y - origin.y - 20.0 * s))
	cell = maxf(4.0, minf(kvar.x / maxf(1.0, float(floor.w)), kvar.y / maxf(1.0, float(floor.h))))
	panel_x = origin.x + cell * float(floor.w) + 10.0 * s

func _fs(bas: float) -> int:
	return int(round(bas * s))

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.06, 0.08))
	if floor == null:
		return
	_skala()
	# rutnätet — med våningens EGNA rutor, så temat man väljer syns direkt i ritytan
	var vägg_tex := _tema_tex(floor.theme, "wall")
	var golv_tex := _tema_tex(floor.theme, "floor")
	for y in floor.h:
		for x in floor.w:
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			if floor.tiles[y][x] == Dungeon.FLOOR:
				if golv_tex != null:
					draw_texture_rect(golv_tex, r, true)
				else:
					draw_rect(r, Color(0.34, 0.33, 0.36))
					draw_rect(Rect2(r.position, Vector2(cell, maxf(1.0, cell * 0.08))), Color(0.40, 0.39, 0.42))
			elif vägg_tex != null:
				draw_texture_rect(vägg_tex, r, true)
			else:
				draw_rect(r, Color(0.13, 0.13, 0.16))
	# Noder: flera kan dela ruta (bossen och nedstigningen ligger medvetet på samma ruta — shoveln
	# kommer från bossen). Då staplas de i sidled, annars gömmer den ena den andra och man kan inte
	# se vad man ritat.
	var per_ruta := {}
	for n in floor.nodes:
		per_ruta[n.pos] = int(per_ruta.get(n.pos, 0)) + 1
	var ritade := {}
	for n in floor.nodes:
		var d := _tool_for(n.kind)
		if d.is_empty():
			continue
		var antal := int(per_ruta[n.pos])
		var i := int(ritade.get(n.pos, 0))
		ritade[n.pos] = i + 1
		var förskjutning := Vector2.ZERO
		if antal > 1:
			förskjutning = Vector2((i - (antal - 1) / 2.0) * cell * 0.42, 0.0)
		var c := origin + Vector2(n.pos) * cell + Vector2(cell / 2, cell / 2) + förskjutning
		var radie := cell * (0.34 if antal == 1 else 0.26)
		draw_circle(c, radie, d["färg"].darkened(0.45))
		draw_string(font, c + Vector2(-0.25, 0.26) * cell, str(d["ch"]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			_fs(9), d["färg"])
	if cursor.x >= 0:
		draw_rect(Rect2(origin + Vector2(cursor) * cell, Vector2(cell, cell)), Color(1, 1, 0.6), false,
			maxf(1.0, s))
	# panelen
	var y := origin.y
	draw_string(font, Vector2(panel_x, y), "KARTEDITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(10),
		Color(0.9, 0.9, 0.95))
	y += 14 * s
	var titel := "%s — våning %d/%d  (%dx%d)  tema: %s" % [Tr.name_of("stage", stage.id, stage.name),
		floor_index + 1, stage.floors, floor.w, floor.h,
		floor.theme if not floor.theme.is_empty() else "platt"]
	draw_string(font, Vector2(panel_x, y), titel, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8), Color(0.75, 0.75, 0.8))
	y += 14 * s
	if genererad:
		draw_string(font, Vector2(panel_x, y), "GENERERAD (spara för att behålla)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8), Color(0.95, 0.75, 0.35))
		y += 12 * s
	for i in NODE_TOOLS.size():
		var d: Dictionary = NODE_TOOLS[i]
		var vald: bool = tool == i
		var rad := "%d  %s  %s" % [i + 1, d["ch"], d["namn"]]
		draw_string(font, Vector2(panel_x, y), rad, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
			d["färg"] if vald else Color(0.62, 0.62, 0.68))
		if vald:
			draw_rect(Rect2(panel_x - 3 * s, y - 7 * s, 74 * s, 10 * s), d["färg"], false, maxf(1.0, s))
		y += 10 * s
	draw_string(font, Vector2(panel_x, y), "G golv   V vägg   (1-6 nod)", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
		Color(0.55, 0.55, 0.6))
	y += 14 * s
	draw_string(font, Vector2(panel_x, y), "S spara  L läs  N ny  P spela", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
		Color(0.55, 0.55, 0.6))
	y += 12 * s
	draw_string(font, Vector2(panel_x, y), "T/Y byter grafiktema  (%s)" % (floor.theme if floor.theme else "platt"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8), Color(0.7, 0.8, 0.95))
	y += 10 * s
	draw_string(font, Vector2(panel_x, y), "[ ] våning   M meny   Q avsluta", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
		Color(0.55, 0.55, 0.6))
	# Raden stod 4 px under den förra: 8 px text behöver 9-10 px för att inte krocka, så rubriken
	# skrevs ovanpå raden över. Nu är det ett avstånd mellan avsnitten i stället.
	y += 14 * s
	draw_string(font, Vector2(panel_x, y), "BANAN (↑↓ välj, ←→ ändra)", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
		Color(0.9, 0.85, 0.6))
	y += 10 * s
	draw_string(font, Vector2(panel_x, y), "%s   %s" % [stage.id, Tr.name_of("stage", stage.id, stage.name)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8), Color(0.75, 0.75, 0.8))
	y += 10 * s
	for i in META_FÄLT.size():
		var vald_rad: bool = meta_vald == i
		var rad_meta := "%s %s" % ["›" if vald_rad else " ", "%s: %s" % [META_FÄLT[i], _meta_värde(i)]]
		draw_string(font, Vector2(panel_x, y), rad_meta, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
			Color(0.95, 0.9, 0.6) if vald_rad else Color(0.62, 0.62, 0.68))
		y += 9 * s
	draw_string(font, Vector2(panel_x, y), "B spara banan   ,/. byt bana   +/- storlek",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8), Color(0.7, 0.8, 0.95))
	y += 12 * s
	# status och fel
	if not status.is_empty():
		draw_string(font, Vector2(panel_x, y), status, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
			Color(0.6, 0.95, 0.6))
		y += 11 * s
	# Fellistan är den enda raden som kan växa obegränsat (en våning kan ha många fel). Sista raden
	# får inte hamna under fönsterkanten — då ser det ut som att kontrollen godkände våningen.
	for i in fel.size():
		if y > size.y - 12 * s:
			draw_string(font, Vector2(panel_x, y), "(+%d fel, se terminalen)" % (fel.size() - i),
				HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8), Color(0.95, 0.45, 0.4))
			break
		draw_string(font, Vector2(panel_x, y), str(fel[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
			Color(0.95, 0.45, 0.4))
		y += 10 * s
	# nedre raden: vad som står under pekaren
	var rad := ""
	if cursor.x >= 0:
		var på_rutan := []
		for n in floor.nodes:
			if n.pos == cursor:
				på_rutan.append(n)
		if på_rutan.is_empty():
			rad = "golv/vägg (%d,%d)" % [cursor.x, cursor.y]
		else:
			var bitar := []
			for n in på_rutan:
				var s := str(n.kind)
				if not n.enemy_id.is_empty():
					s += " %s" % Tr.name_of("enemy", n.enemy_id, n.enemy_id)
				if n.gold > 0:
					s += " %d guld" % n.gold
				bitar.append(s)
			rad = "%s  (%d,%d)" % [" + ".join(bitar), cursor.x, cursor.y]
	draw_string(font, Vector2(origin.x, size.y - 6 * s), rad, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8),
		Color(0.8, 0.8, 0.85))

# --- banan (stage-meta), inte bara våningen ------------------------------------------------------
#
# Våningen är ritad och går att spara (S). Men en BANA är mer än en våning: namn, tema per våning,
# antal våningar, svårighetsgrad, vilka fiende-tiers som får dyka upp, bossar, och bonusarna. Fram
# till nu gick de bara att ändra genom att handredigera data/stages/<id>.json, och banan i editorn
# kom från kommandoraden — man kunde alltså inte byta bana utan att starta om.
#
# Fälten nedan redigeras med ↑/↓ (välj) och ←/→ (ändra). Textfält (namnet) visas bara: att skriva
# text i en 480x270-yta med tangentbord är en egen uppgift, och namnet byts sällan.
const META_FÄLT := ["regel", "tema", "våningar", "svårighet", "tiers", "strider/våning", "boss",
	"sista boss", "guld-bonus", "xp-bonus", "ny strid"]

const TIER_SETT := [[1], [1, 2], [1, 2, 3], [2, 3], [2, 3, 4], [3, 4]]

var meta_vald := 0                  ## rad i META_FÄLT som ←/→ ändrar
var vald_fiende := ""               ## "" = generatorns val (deterministiskt ur positionen)

func _meta_värde(i: int) -> String:
	match META_FÄLT[i]:
		"regel":
			# Regeln står med sin VERKAN, inte bara sitt namn: den som väljer ska se vad den gör.
			return "%s — %s" % [Regler.namn(stage.regel), Regler.text(stage.regel)]
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
			vald_fiende = str(_cykla(ids2, vald_fiende, steg))
	status = "%s: %s" % [fält, _meta_värde(meta_vald)]
	queue_redraw()

## Spara BANAN (stage-filen), inte våningen. Egen tangent (B) därför att de är två olika filer med
## två olika fel — och en våning som sparats medan banan är trasig ser ut som en lyckad körning.
func save_stage() -> void:
	if Stages.skriv(stage):
		status = "banan sparad: %s" % (Stages.DIR + stage.id + ".json").get_file()
		print("bana sparad: %s" % ProjectSettings.globalize_path(Stages.DIR + stage.id + ".json"))
	else:
		status = "kunde inte spara banan"
		print("  bana: %s" % stage.id)

func nasta_bana(steg: int) -> void:
	var ids := stages.keys()
	ids.sort()
	var i := ids.find(stage.id)
	stage = stages[ids[(i + steg + ids.size()) % ids.size()]]
	floor_index = clampi(floor_index, 0, max(0, stage.floors - 1))
	load_or_generate()
	status = "bana: %s" % stage.id

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
	status = "storlek %dx%d%s" % [floor.w, floor.h,
		(" — %d golvrutor föll bort" % kastat) if kastat > 0 else ""]

func _tool_for(kind: String) -> Dictionary:
	for d in NODE_TOOLS:
		if d["kind"] == kind:
			return d
	return {}
