extends SceneTree
## Ljuset som Alex dömde "alldeles för murrigt" (15/10). Siffrorna kommer ur `-- ljusprov`, som mäter
## samma scen i samma process; den här grinden kör en våning och läser att rattarna står kvar där.

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	if not ok:
		fails += 1

func _initialize() -> void:
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_01", 20260919)
	await process_frame
	await process_frame
	var täthet: float = main.env.volumetric_fog_density
	check(täthet >= 0.030 - 0.0005, "dimman ligger på minst 0,030 (0,022 = mörkt 51 % av vyn)", "%.4f" % täthet)
	var bäst := 0.0
	for l in main.world.find_children("*", "Light3D", true, false):
		bäst = maxf(bäst, (l as Light3D).light_volumetric_fog_energy)
	check(is_equal_approx(bäst, 9.0), "facklans ljus i dimman står på 9,0 (1 397 högdagerpixlar mot 778 vid 6,0)",
		"%.1f" % bäst)
	check(main.env.fog_density <= 0.04 + 0.0005, "avståndsdimman ligger kvar på sitt tak (den grumlar)", "%.4f" % main.env.fog_density)
	# VÄGGARNAS TON: buggen var att väggarna inte fick någon ton alls och därför blev nästan svarta
	# (rak textur × albedo 0,21 sRGB ≈ 0,035 linjärt). Två saker ska stå kvar: talet, och att anropet
	# som bygger väggarna faktiskt skickar in det.
	check(minf(main.VÄGG_TON.r, minf(main.VÄGG_TON.g, main.VÄGG_TON.b)) > 2.0, "väggtonen står kvar över 2,0 (annars är väggen svart av sin albedo)",
		str(main.VÄGG_TON))
	var källkod := FileAccess.get_file_as_string("res://main.gd")
	check(källkod.contains('1.0, VÄGG_TON'), "och väggbygget skickar in den")
	check(not källkod.contains('"wall_moss", 37)'), "ingen väggyta står kvar utan ton (den gamla buggen)")
	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
