extends SceneTree
## Utomhus: man ska kunna gå UT genom en dörröppning och stå på en bro med himmel runtom — och man
## ska fortfarande inte kunna kliva av bron. Himlen är ett val i kartdatan ("öppna"), inte något
## generatorn hittar på (Alex 15/10: "vi ser ut att behöva tak på stället").

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	if not ok:
		fails += 1

## Ett rum, en dörröppning i väggen och en en-ruta-bred bro utanför — bron är öppen, rummet inte.
func _bron() -> Dictionary:
	return {
		"tiles": [
			"#####",
			"#...#",
			"#...#",
			"##.##",
			"##.##",
			"##.##",
			"##.##",
			"#####",
		],
		"öppna": [[2, 3, 1, 4]],
		"nodes": [{"kind": "start", "pos": [2, 2]}],
	}

func _initialize() -> void:
	# 1) kartdatan bär öppna rum
	var f := MapIo.from_dict(_bron(), "prov", 0)
	check(f != null and f.öppna.size() == 1, "kartdatan kan öppna ett rum", str(f.öppna if f != null else []))
	check(f != null and f.är_öppen(Vector2i(2, 4)), "bron är öppen (taket byggs inte där)")
	check(f != null and not f.är_öppen(Vector2i(2, 2)), "rummet är stängt")
	if f != null:
		check(MapIo.from_dict(MapIo.to_dict(f), "prov", 0).öppna.size() == 1, "och de överlever en sparad karta")

	# 2) och man kan GÅ ut genom dörren och ut på bron
	if f != null:
		var ex := Explore.new(f)
		check(ex.pos == Vector2i(2, 2), "hjälten står i rummet", str(ex.pos))
		ex.facing = Explore.SOUTH
		check(ex.forward() == "", "ett steg genom dörröppningen går", str(ex.pos))
		check(ex.pos == Vector2i(2, 3), "och han står i öppningen", str(ex.pos))
		check(ex.forward() == "", "och vidare ut på bron", str(ex.pos))
		check(ex.pos == Vector2i(2, 4), "ute på bron", str(ex.pos))
		# bron är en ruta bred: ingen fysik behövs, rutnätet är staketet
		check(not f.is_floor_at(Vector2i(1, 4)), "rutan bredvid bron finns inte — man kan inte kliva av")
		check(not f.is_floor_at(Vector2i(2, 7)), "och inte vidare förbi bron")

	# 3) renderaren: himlen är ett valv runt våningen, inte en skiva per rum
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
	check(main.world.find_children("himmel", "MeshInstance3D", true, false).is_empty(),
		"och då finns ingen himmel i världen alls")
	fl.öppna.append(Rect2i(fl.boss_pos.x - 2, fl.boss_pos.y - 1, 5, 3))
	main._build_world()
	await process_frame
	var valv: Array = main.world.find_children("himmel", "MeshInstance3D", true, false)
	var toppar: Array = main.world.find_children("himmel_topp", "MeshInstance3D", true, false)
	var ljus: Array = main.world.find_children("himmel_ljus", "OmniLight3D", true, false)
	check(valv.size() == 1, "himlen är ETT valv runt våningen", "%d" % valv.size())
	check(toppar.size() == 1, "med ett tak över", "%d" % toppar.size())
	check(ljus.size() == 1, "och en lampa över slagfältet", "%d" % ljus.size())
	if not valv.is_empty():
		var cyl := (valv[0] as MeshInstance3D).mesh as CylinderMesh
		check(cyl != null and not cyl.cap_top, "valvet är öppet upptill (taket ligger för sig)")
		var mat := (valv[0] as MeshInstance3D).material_override as StandardMaterial3D
		check(mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"himlen lyser av sig själv, inte av facklorna")
	if not toppar.is_empty():
		var tmat := (toppar[0] as MeshInstance3D).material_override as StandardMaterial3D
		check(tmat != null and tmat.albedo_texture == null, "taket har EN färg, ingen rändig gradient")
	if not ljus.is_empty():
		var l: OmniLight3D = ljus[0]
		check(not l.shadow_enabled, "lampan kastar inga skuggor (referensens lampor har m_shadows = None)")
		check(is_equal_approx(l.light_color.r, 0.877), "och har referensens egen färg", str(l.light_color))
	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
