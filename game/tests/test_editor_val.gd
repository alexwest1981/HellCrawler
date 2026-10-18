## Karteditorns REDIGERING (M146): att musen väljer rätt nod, att ett drag flyttar den utan att tappa
## dess data, och att reglerna vägrar där de ska vägra.
##
## Det här provet vaktar det som gick sönder i trädeditorn och som är samma fälla här: en dragning
## som bygger en NY post i stället för att mutera den tappar fiende, guld och xp tyst — noden ser
## flyttad ut och är i själva verket nyskapad med generatorns standardvärden.
##
## Provet anropar editorns EGNA funktioner (samma väg som musen tar), och skriver aldrig i spelets
## data: våningen byggs i minnet.
##
##   tools/ett_prov.sh tests/test_editor_val.gd
extends SceneTree

var fails := 0
var checks := 0
var editor = null

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])

## En TOM våning: `MapIo.blank` lägger dit en start själv, och då är det provet just ställde ut inte
## det första noden i listan. Nollställ allt, och leta upp noder på ruta i stället för på index.
func _tom() -> void:
	editor.floor = MapIo.blank("stage_01", 0, 17, 17)
	editor.floor.nodes = []
	editor.floor.start = Vector2i(-1, -1)
	editor.floor.boss_pos = Vector2i(-1, -1)
	editor.floor.shovel_pos = Vector2i(-1, -1)
	editor.vald = []
	editor.ändrad = false
	editor.verktyg = "valj"
	editor._layout_duk()


func _hitta(p: Vector2i):
	for n in editor.floor.nodes:
		if n.pos == p:
			return n
	return null


## Klick på rutans mitt genom editorns egen musväg (`_vänster_ner`), inte genom en genväg.
func _peka(p: Vector2i) -> void:
	editor._vänster_ner(editor._ruta_rect(p).get_center(), p)


func _släpp() -> void:
	editor._vänster_upp()


## Ett drag på `steg` rutor: en riktig mushändelse genom `_duk_input`.
func _dra(p: Vector2i, steg: Vector2i) -> void:
	_peka(p)
	var mm := InputEventMouseMotion.new()
	mm.position = editor._ruta_rect(p).get_center() + Vector2(steg) * editor.cell
	mm.relative = Vector2(steg) * editor.cell
	editor._duk_input(mm)
	_släpp()


func _antal_golv(typ: int) -> int:
	var n := 0
	for y in editor.floor.h:
		for x in editor.floor.w:
			if editor.floor.tiles[y][x] == typ:
				n += 1
	return n


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	editor.position = Vector2.ZERO
	await process_frame
	await process_frame
	check(editor.floor != null, "editorn har en våning", "")

	# --- 1. penseln sätter en nod där man klickar
	_tom()
	editor.verktyg = "nod"
	editor.nod_kind = "chest"
	editor._måla(Vector2i(5, 5))
	var kista = _hitta(Vector2i(5, 5))
	check(kista != null and kista.kind == "chest", "penseln satte en kista på rutan")
	check(kista != null and kista.gold > 0, "kistan fick banans guld", str(kista.gold if kista else 0))

	# --- 2. klick väljer den nod man pekar på
	editor.verktyg = "valj"
	_peka(Vector2i(5, 5))
	check(editor.vald.size() == 1 and editor.vald[0] == kista, "klick väljer noden på rutan")
	_släpp()

	# --- 3. ett drag FLYTTAR noden och behåller dess data
	_tom()
	MapIo.placera(editor.floor, "encounter", Vector2i(8, 8), editor.stage, editor.bestiary)
	var fiende = _hitta(Vector2i(8, 8))
	fiende.gold = 77
	fiende.xp = 13
	var fiendens_id: String = fiende.enemy_id
	_dra(Vector2i(8, 8), Vector2i(2, 0))
	var flyttad = _hitta(Vector2i(10, 8))
	check(flyttad != null and flyttad == fiende, "draget flyttade noden två rutor",
		"(%d,%d)" % [fiende.pos.x, fiende.pos.y])
	check(fiende.gold == 77 and fiende.xp == 13, "guld och xp följde med",
		"%d guld, %d xp" % [fiende.gold, fiende.xp])
	check(fiende.enemy_id == fiendens_id, "fienden är densamma efter draget", fiende.enemy_id)
	check(_hitta(Vector2i(8, 8)) == null, "ingen kvarleva på den gamla rutan")

	# --- 4. ett drag in i en vägg vägras, och noden står kvar
	editor.floor.tiles[8][11] = Dungeon.WALL
	_dra(Vector2i(10, 8), Vector2i(1, 0))
	check(fiende.pos == Vector2i(10, 8), "draget in i en vägg ändrade ingenting",
		"(%d,%d)" % [fiende.pos.x, fiende.pos.y])
	check(editor.status.contains("golv"), "statusraden säger varför", editor.status)

	# --- 5. piltangenterna puttar urvalet en ruta
	_peka(Vector2i(10, 8))
	_släpp()
	editor._putta(Vector2i(0, 1))
	check(fiende.pos == Vector2i(10, 9), "putten flyttade en ruta ned",
		"(%d,%d)" % [fiende.pos.x, fiende.pos.y])

	# --- 6. en upptagen ruta vägras (två noder i samma ruta går inte att skilja från en bugg)
	MapIo.placera(editor.floor, "chest", Vector2i(10, 10), editor.stage, editor.bestiary)
	editor._putta(Vector2i(0, 1))
	check(fiende.pos == Vector2i(10, 9), "putten in i en upptagen ruta vägrades",
		"(%d,%d)" % [fiende.pos.x, fiende.pos.y])

	# --- 7. Ctrl+D kopierar till en ledig ruta intill
	_tom()
	editor.verktyg = "nod"
	editor.nod_kind = "chest"
	editor._måla(Vector2i(6, 6))
	editor.verktyg = "valj"
	_peka(Vector2i(6, 6))
	_släpp()
	var före_kopior: int = editor.floor.nodes.size()
	editor._kopiera_vald()
	check(editor.floor.nodes.size() == före_kopior + 1, "kopian lades till",
		"%d -> %d" % [före_kopior, editor.floor.nodes.size()])

	# --- 8. starten får inte kopieras: kontrollen kräver exakt en
	_tom()
	MapIo.placera(editor.floor, "start", Vector2i(2, 2), editor.stage, editor.bestiary)
	_peka(Vector2i(2, 2))
	_släpp()
	var före_start: int = editor.floor.nodes.size()
	editor._kopiera_vald()
	check(editor.floor.nodes.size() == före_start, "starten kopierades inte", editor.status)

	# --- 9. Del tar bort urvalet, och startens pekare nollställs
	editor._ta_bort_vald()
	check(editor.floor.nodes.is_empty(), "Del tog bort noden")
	check(editor.floor.start == Vector2i(-1, -1), "startens pekare nollställdes",
		str(editor.floor.start))

	# --- 10. box-markering tar alla noder innanför rutan
	_tom()
	for p in [Vector2i(3, 3), Vector2i(4, 4), Vector2i(12, 14)]:
		MapIo.placera(editor.floor, "encounter", p, editor.stage, editor.bestiary)
	editor._vänster_ner(editor._ruta_rect(Vector2i(1, 1)).get_center(), Vector2i(1, 1))
	editor._box_till = editor._ruta_rect(Vector2i(6, 6)).get_center()
	_släpp()
	check(editor.vald.size() == 2, "boxen tog de två noderna innanför", str(editor.vald.size()))

	# --- 11. ett drag ritar en LINJE utan gluggar (Bresenham, inte en prick per händelse)
	_tom()
	editor.verktyg = "ruta"
	editor.ruta_mark = Dungeon.WALL
	var golv_före: int = _antal_golv(Dungeon.FLOOR)
	editor._måla_linje(Vector2i(2, 2), Vector2i(10, 7))
	var målade: int = golv_före - _antal_golv(Dungeon.FLOOR)
	check(målade == 9, "linjen målade 9 rutor (dx 8, dy 5)", str(målade))
	check(editor.floor.tiles[7][10] == Dungeon.WALL and editor.floor.tiles[2][2] == Dungeon.WALL,
		"båda ändarna är målade")

	# --- 12. panelen byggs om MITT I ett klick: varje radknapp (◀ ▶) trycks, och panelen ska komma
	# tillbaka hel. Det är den vägen som kraschar om `_tom` frigör knappen som äger signalen.
	_tom()
	var tryckta := 0
	for varv in 2:
		var knappar := []
		for c in editor.insp_box.get_children():
			for b in c.get_children():
				if b is Button and (b as Button).text in ["◀", "▶"]:
					knappar.append(b)
		for b in knappar:
			(b as Button).emit_signal("pressed")
			tryckta += 1
	check(tryckta > 20, "radknapparna går att trycka", "%d tryck" % tryckta)
	check(editor.floor != null and editor.stage != null and editor.insp_box.get_child_count() > 4,
		"panelen står kvar hel efter trycken",
		"%d rader" % editor.insp_box.get_child_count())
	check(editor.stage.difficulty >= 1 and editor.stage.difficulty <= 9
		and editor.stage.floors >= 1 and editor.stage.floors <= 8,
		"banans fält hölls inom sina gränser",
		"svårighet %d, våningar %d" % [editor.stage.difficulty, editor.stage.floors])

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
