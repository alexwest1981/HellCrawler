## Fiendepaletten (M155): välj VAD som ska spawna, som i referenseditorn — inte bara "en strid".
##
##   tools/ett_prov.sh tests/test_editor_fiende.gd
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


func _tom() -> void:
	editor.floor = MapIo.blank("stage_01", 0, 17, 17)
	editor.floor.nodes = []
	editor.floor.start = Vector2i(-1, -1)
	editor.floor.boss_pos = Vector2i(-1, -1)
	editor.floor.shovel_pos = Vector2i(-1, -1)
	editor.vald = []
	editor.verktyg = "valj"


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	editor.position = Vector2.ZERO
	await process_frame
	await process_frame

	# 1. Listan: bestiariets alla fiender, sorterade.
	var lista: Array = editor._fiendelista()
	check(lista.size() == editor.bestiary.size(), "paletten listar bestiariets fiender",
		"%d av %d" % [lista.size(), editor.bestiary.size()])
	# Banans egen pool först (de man får använda), resten efteråt — båda delarna sorterade.
	var pool: Array = []
	for e in Enemies.by_tier(editor.bestiary, editor.stage.tiers):
		pool.append(str(e.id))
	pool.sort()
	var först := lista.slice(0, pool.size())
	var resten := lista.slice(pool.size())
	resten.sort()
	check(först == pool, "banans fiender ligger först i paletten (%d)" % pool.size())
	check(resten == resten.duplicate() and lista.slice(pool.size()) == resten,
		"och resten är sorterad efteråt (%d)" % resten.size())
	var med_ikon := 0
	for id in lista:
		if editor._fiende_tex(str(id)) != null:
			med_ikon += 1
	check(med_ikon == lista.size(), "varje fiende har en ikon ur assets/enemies (%d av %d)"
		% [med_ikon, lista.size()])

	# 2. Klicket ställer en strid med DEN fienden.
	_tom()
	editor.verktyg = "fiende"
	editor.fiende_art = str(lista[0])
	editor._måla(Vector2i(4, 4))
	var nod = null
	for n in editor.floor.nodes:
		if n.pos == Vector2i(4, 4):
			nod = n
	check(nod != null, "det står en nod på rutan")
	if nod != null:
		check(nod.kind == "encounter", "och det är en strid (%s)" % nod.kind)
		check(nod.enemy_id == str(lista[0]), "med fienden man valde (%s)" % nod.enemy_id)

	# 3. En nod per ruta: en annan fiende på samma ruta ERSÄTTER.
	var andra := str(lista[1])
	editor.fiende_art = andra
	editor._måla(Vector2i(4, 4))
	var antal := 0
	var vilken := ""
	for n in editor.floor.nodes:
		if n.pos == Vector2i(4, 4):
			antal += 1
			vilken = n.enemy_id
	check(antal == 1 and vilken == andra, "andra klicket bytte fiende i stället för att lägga till",
		"%d nod(er), %s" % [antal, vilken])

	# 4. Utan vald fiende: generatorns eget val (deterministiskt ur positionen), inte tomt.
	_tom()
	editor.verktyg = "fiende"
	editor.fiende_art = ""
	editor._måla(Vector2i(6, 6))
	var slumpsatt := ""
	for n in editor.floor.nodes:
		if n.pos == Vector2i(6, 6):
			slumpsatt = n.enemy_id
	check(not slumpsatt.is_empty(), "utan val får rutan en fiende ur banan (%s)" % slumpsatt)

	# 5. ALLA FIENDER GÅR ATT SÄTTA UT (M165). Alex: *"sällan det går att klicka på en fiende och sätta
	#    ut den."* Förut krävde `placera` att fienden låg i banans tiers — 4 av 17 i stage_01 — och då
	#    hände ingenting för de andra 13. Provet ställer ut VARJE fiende på en egen ruta.
	_tom()
	editor.verktyg = "fiende"
	var placerade := 0
	var rutor: Array = []
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and rutor.size() < lista.size():
				rutor.append(Vector2i(x, y))
	for i in range(mini(lista.size(), rutor.size())):
		editor.fiende_art = str(lista[i])
		editor._måla(rutor[i])
		for n in editor.floor.nodes:
			if n.pos == rutor[i] and n.kind == "encounter" and n.enemy_id == str(lista[i]):
				placerade += 1
	check(placerade == mini(lista.size(), rutor.size()),
		"varje fiende i paletten går att ställa ut", "%d av %d" % [placerade, mini(lista.size(), rutor.size())])

	# 5b. KLICKET: en riktig knapptryckning i paletten ska välja fienden, och ett riktigt musklick i
	#     kartan ska ställa ut den — provet ovan anropar `_måla` direkt och hade inte märkt om knappen
	#     slutade koppla ihop sig med penseln.
	# Knappen hittas på sin IKON: palettens fiendeknappar har bilden men ingen text (namnet ligger i
	# hovringstexten), så en textsökning hittar dem inte.
	var knapp := ""
	var ikon: Texture2D = editor._fiende_tex(str(lista[0]))
	for b in editor.find_children("*", "Button", true, false):
		if b.icon != null and b.icon == ikon:
			knapp = "ikon"
			b.pressed.emit()
			break
	check(not knapp.is_empty(), "fiendeknappen finns i paletten (på sin ikon)", knapp)
	check(editor.verktyg == "fiende" and editor.fiende_art == str(lista[0]),
		"knapptryckningen väljer fienden", "%s / %s" % [editor.verktyg, editor.fiende_art])
	var mål := Vector2i(-1, -1)
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and mål.x < 0:
				mål = Vector2i(x, y)
	editor._layout_duk()
	var punkt: Vector2 = editor.anka + (Vector2(mål) + Vector2(0.5, 0.5)) * editor.cell
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = punkt
	editor._duk_input(mb)
	var satte := ""
	for n in editor.floor.nodes:
		if n.pos == mål and n.kind == "encounter":
			satte = n.enemy_id
	check(satte == str(lista[0]), "och ett musklick i kartan ställer ut den", satte)

	# 6. Ett okänt id vägras fortfarande, och rutan behåller det som stod där.
	editor.fiende_art = "finns_inte"
	var före_antal: int = editor.floor.nodes.size()
	editor._måla(Vector2i(2, 2))
	check(editor.floor.nodes.size() == före_antal, "en okänd fiende ställs inte ut")
	check(editor.status.contains("okänd fiende"), "och statusraden säger varför", editor.status)

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
