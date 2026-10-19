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

	# 5. En fiende UTANFÖR banans tiers vägras med besked (och rutan behåller det som stod där).
	#    Förut blev noden stående utan fiende — en tom strid som bara syns som en ruta.
	var utanför := ""
	for id in lista:
		var i_pool := false
		for e in Enemies.by_tier(editor.bestiary, editor.stage.tiers):
			if str(e.id) == str(id):
				i_pool = true
		if not i_pool:
			utanför = str(id)
			break
	if not utanför.is_empty():
		editor.verktyg = "fiende"
		editor.fiende_art = utanför
		var före: int = editor.floor.nodes.size()
		editor._måla(Vector2i(8, 8))
		var efter: int = editor.floor.nodes.size()
		check(efter == före, "fienden utanför banans tiers ställs inte ut",
			"%d -> %d noder" % [före, efter])
		check(editor.status.contains("tiers") or editor.status.contains("finns inte"),
			"och statusraden säger varför", editor.status)

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
