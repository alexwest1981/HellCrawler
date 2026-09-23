## Ban-editorn: att banan (stage-meta) går att ändra och spara, och att en storleksändring inte
## lämnar en våning som ser giltig ut men inte går att spela.
##
## Det här provet vaktar tre saker:
##   1. Att fälten hålls inom sina gränser (svårighet 1-9, våningar 1-8, tiers ur den kända listan).
##   2. Att banan kommer tillbaka exakt som den skrevs (Stages.skriv -> Stages.load_all).
##   3. Att en krympning tar bort noder OCH nollställer start/boss/nedstigning som hamnat utanför.
##   godot --headless --script res://tests/test_editor.gd
extends SceneTree

const TESTDIR := "user://test_banor/"

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _städa() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TESTDIR))
	var d := DirAccess.open(TESTDIR)
	if d == null:
		return
	for fil in d.get_files():
		d.remove(fil)

func _init() -> void:
	_städa()
	var editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)          # _ready kör: banor och bestiarium läses, våningen laddas
	await process_frame

	check(editor.stage != null and editor.floor != null, "editorn startar med en bana och en våning",
		editor.stage.id)

	# 1. Gränserna. Välj svårighetsraden och dra den uppåt många steg.
	editor.meta_vald = editor.META_FÄLT.find("svårighet")
	for i in 30:
		editor._meta_ändra(1)
	check(editor.stage.difficulty == 9, "svårigheten klämmer vid 9", str(editor.stage.difficulty))
	for i in 30:
		editor._meta_ändra(-1)
	check(editor.stage.difficulty == 1, "svårigheten klämmer vid 1", str(editor.stage.difficulty))

	editor.meta_vald = editor.META_FÄLT.find("våningar")
	for i in 30:
		editor._meta_ändra(1)
	check(editor.stage.floors == 8, "våningarna klämmer vid 8", str(editor.stage.floors))

	editor.meta_vald = editor.META_FÄLT.find("tiers")
	var sedda := {}
	for i in 12:
		editor._meta_ändra(1)
		sedda[str(editor.stage.tiers)] = true
	check(sedda.size() >= 4, "tiers rullar genom flera kända set", str(sedda.keys()))

	# Bossen ska vara ett id ur bestiariet, inte en påhittad sträng.
	editor.meta_vald = editor.META_FÄLT.find("boss")
	editor._meta_ändra(1)
	check(editor.bestiary.has(editor.stage.boss), "bossen är en fiende ur bestiariet", editor.stage.boss)

	# 2. Runturen genom filen.
	editor.stage.difficulty = 4
	editor.stage.floors = 5
	editor.stage.boss = "copper_warden"
	check(Stages.skriv(editor.stage, TESTDIR), "banan skrivs")
	var tillbaka := Stages.load_all(TESTDIR)
	var s: Stages.StageDef = tillbaka.get(editor.stage.id)
	check(s != null, "banan läses tillbaka")
	if s != null:
		check(s.difficulty == 4 and s.floors == 5 and s.boss == "copper_warden",
			"fälten kom tillbaka exakt", "%d/%d/%s" % [s.difficulty, s.floors, s.boss])

	# 3. Storleken. Gör en våning med start i hörnet, väx och krymp.
	editor.floor = MapIo.blank(editor.stage.id, 0)
	var start := Dungeon.FloorNode.new()
	start.kind = "start"
	start.pos = Vector2i(editor.floor.w - 1, editor.floor.h - 1)     # i det som ska kastas
	editor.floor.nodes.append(start)
	editor.floor.start = start.pos
	editor.floor.tiles[3][3] = Dungeon.FLOOR
	var före: int = editor.floor.w
	editor.storlek(1)
	check(editor.floor.w == före + 1, "växer ett steg", "%d -> %d" % [före, editor.floor.w])
	check(editor.floor.tiles[3][3] == Dungeon.FLOOR, "golvet som fanns är kvar")
	var noder_före: int = editor.floor.nodes.size()
	editor.storlek(-2)
	check(editor.floor.nodes.size() < noder_före, "krympningen tar bort noder utanför kanten",
		"%d -> %d" % [noder_före, editor.floor.nodes.size()])
	check(editor.floor.start == Vector2i(-1, -1), "starten nollställs när rutan försvinner",
		str(editor.floor.start))

	_städa()
	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
