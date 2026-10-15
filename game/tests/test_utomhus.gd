extends SceneTree
## TILLFÄLLIGT: öppnar en GENERERAD våning (stage_05 har ingen ritad karta) och mäter himlen:
## takrutorna ska vara färre än golvrutorna, himmelytan och lampan ska finnas i världen.

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])

func _initialize() -> void:
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_05", 20260919)
	await process_frame
	await process_frame
	await process_frame
	var f = main.run.explore.floor_ref
	check(not f.öppna.is_empty(), "generatorn gör bossrummet öppet", "%d rum: %s" % [f.öppna.size(), str(f.öppna)])
	var öppna_rutor := 0
	for r in f.öppna:
		öppna_rutor += (r as Rect2i).size.x * (r as Rect2i).size.y
	var himlar: Array = main.world.find_children("himmel", "MeshInstance3D", true, false)
	var ljus: Array = main.world.find_children("himmel_ljus", "OmniLight3D", true, false)
	check(himlar.size() == f.öppna.size(), "en himmelyta per öppet rum", "%d ytor" % himlar.size())
	check(ljus.size() == f.öppna.size(), "och en lampa över slagfältet", "%d lampor" % ljus.size())
	if not ljus.is_empty():
		var l: OmniLight3D = ljus[0]
		check(not l.shadow_enabled, "lampan kastar inga skuggor (referensens lampor har m_shadows = None)")
		check(is_equal_approx(l.light_color.r, 0.877), "och har referensens egen färg", str(l.light_color))
	if not himlar.is_empty():
		var mi: MeshInstance3D = himlar[0]
		var mat := mi.material_override as StandardMaterial3D
		check(mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"himlen är oupplyst (den lyser av sig själv, inte av facklor)")
		var plan := mi.mesh as PlaneMesh
		check(plan != null and plan.size.x >= float((f.öppna[0] as Rect2i).size.x),
			"och ytan täcker rummet", str(plan.size) if plan != null else "ingen yta")
	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
