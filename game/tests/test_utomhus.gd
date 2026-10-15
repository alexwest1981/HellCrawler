extends SceneTree
## Himlen över ett slagfält: taket står på i generatorns våningar, och ett rum blir öppet bara om
## KARTAN säger det ("öppna": [[x, y, bredd, höjd]] i data/maps/<bana>_<våning>.json).

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	if not ok:
		fails += 1

func _initialize() -> void:
	# 1) kartdatan bär öppna rum
	var karta := {
		"tiles": ["#####", "#...#", "#...#", "#...#", "#####"],
		"öppna": [[1, 1, 3, 3]],
	}
	var f := MapIo.from_dict(karta, "prov", 0)
	check(f != null and f.öppna.size() == 1, "kartdatan kan öppna ett rum", str(f.öppna if f != null else []))
	check(f != null and f.är_öppen(Vector2i(2, 2)), "rutan i det öppna rummet är öppen")
	check(f != null and not f.är_öppen(Vector2i(0, 0)), "rutan utanför är inte det")
	if f != null:
		var tillbaka := MapIo.from_dict(MapIo.to_dict(f), "prov", 0)
		check(tillbaka.öppna.size() == 1, "och de överlever en sparad karta", str(tillbaka.öppna))

	# 2) generatorn lämnar taket på
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_05", 20260919)
	await process_frame
	await process_frame
	await process_frame
	var fl = main.run.explore.floor_ref
	check(fl.öppna.is_empty(), "generatorn öppnar inga rum — taket står på",
		"%d öppna rum i våning %d" % [fl.öppna.size(), fl.index + 1])

	# 3) och renderaren bygger himlen när någon SÄGER att rummet är öppet
	var bossrum := Rect2i(fl.boss_pos.x - 2, fl.boss_pos.y - 1, 5, 3)
	fl.öppna.append(bossrum)
	main._build_world()
	await process_frame
	var himlar: Array = main.world.find_children("himmel", "MeshInstance3D", true, false)
	var ljus: Array = main.world.find_children("himmel_ljus", "OmniLight3D", true, false)
	check(himlar.size() == 1, "en himmelyta över det öppna rummet", "%d" % himlar.size())
	check(ljus.size() == 1, "och en lampa över slagfältet", "%d" % ljus.size())
	if not himlar.is_empty():
		var mat := (himlar[0] as MeshInstance3D).material_override as StandardMaterial3D
		check(mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"himlen lyser av sig själv, inte av facklorna")
	if not ljus.is_empty():
		var l: OmniLight3D = ljus[0]
		check(not l.shadow_enabled, "lampan kastar inga skuggor (referensens lampor har m_shadows = None)")
		check(is_equal_approx(l.light_color.r, 0.877), "och har referensens egen färg", str(l.light_color))
	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
