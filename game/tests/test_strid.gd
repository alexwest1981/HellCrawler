## Striden ska ske I RUMMET, inte i en meny.
##
## Alex: *"en strid måste ske i en separat scen i det rum man befinner sig, så det inte blir att man
## kliver fram, och tittar genom fienden, och bara ser sina kort."* Provet mäter därför tre saker, alla
## REN logik (ingen rendering, inga bilder):
##
##   1. SPELARENS RUTA ÄR INTE FIENDENS. Man gick in i striden med ett steg framåt, och kameran stod på
##      fiendens ruta — inne i figuren. Nu backas man till rutan före och vänds mot den.
##   2. KAMERAN SNÄPPER DIT. Den står i den nya rutan och riktningen i SAMMA bildruta (ingen tween som
##      hinner fram en halv sekund senare). Mätt i demoläget före ändringen: fienden stod 2,3 m bort i
##      stället för 1,15, därför att kamera-tweenen sackade efter stegen.
##   3. FIENDEN STÅR I BILD. Varje fiende i striden ligger innanför kamerans frustum och utanför
##      närplanet, och främsta ledet står på sin egen ruta — rummet finns kvar bakom dem.
##
## Vägen in är SPELARENS (`_step_forward`), inte en genväg till `_enter_node_here`: det var den vägen
## som bar felet, och ett prov som går en annan väg mäter en annan väg.
##
## FLIT-BORT (beviset för att provet kan gå rött): ta bort `_backa_till_rutan_före` ur `_enter_node_here`
## och provet faller på "spelarens ruta är inte fiendens"; ta bort `_snap_cam` och det faller på
## "kameran snäpper till rutan och riktningen".
##
##   godot --headless --script res://tests/test_strid.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


## Står punkten i bild? Kamerans närplan, riktning och bildruta, i SAMMA räkning som spelet använder när
## det ritar en siffra över en fiende (`is_position_behind` + `unproject_position` i `_slag_kvitto`).
## Frustum-planen duger inte: Godots `get_frustum` ger fjärrplanet med normalen utåt, så ett avstånd
## till en punkt 1,2 m framför kameran blev −3993 (mätt — provet fällde friska fiender).
func _i_bild(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	if cam.global_position.distance_to(p) <= cam.near:
		return false
	var s := cam.unproject_position(p)
	var ruta: Vector2 = cam.get_viewport().get_visible_rect().size
	return s.x >= 0.0 and s.x <= ruta.x and s.y >= 0.0 and s.y <= ruta.y


func _initialize() -> void:
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_01", 20260919)
	await process_frame

	var nod: Dungeon.FloorNode = null
	for n in main.run.explore.floor_ref.nodes:
		if n.kind == "encounter" and not n.cleared:
			nod = n
			break
	check(nod != null, "våningen har en strid att möta")
	if nod == null:
		print("  TOTALT: %d kontroller, %d fel" % [checks, fails])
		quit(1)
		return

	# Gå fram till rutan FRAMFÖR fienden. Sista biten görs av spelarens egen väg (`_step_forward`).
	var varv := 0
	while main.run.explore.path_to(nod.pos).size() > 2 and varv < 300:
		varv += 1
		if main.run.explore.step_toward(nod.pos) != "":
			print("  FEL  kunde inte gå fram till striden: fast på %s" % str(main.run.explore.pos))
			break
	await process_frame
	var rutan_före: Vector2i = main.run.explore.pos
	check(rutan_före != nod.pos, "spelaren står en ruta ifrån fienden före sista steget",
		"jag %s, fienden %s" % [str(rutan_före), str(nod.pos)])

	# Steget in i striden — exakt vad W-tangenten gör.
	main._step_forward()
	await process_frame

	check(main.active_combat != null and main.active_node == nod,
		"striden startar när man kliver in i rutan", "fiende %s" % nod.enemy_id)
	# 1: spelarens ruta är inte fiendens.
	check(main.run.explore.pos != nod.pos, "spelarens ruta är inte fiendens",
		"jag %s, fienden %s" % [str(main.run.explore.pos), str(nod.pos)])
	# Rutan före = rutan man kom ifrån, och blicken mot fienden.
	check(main.run.explore.pos == rutan_före, "kameran står i rutan FÖRE fienden",
		"%s" % str(main.run.explore.pos))
	check(main.run.explore.pos + Explore.STEP[main.run.explore.facing % 4] == nod.pos,
		"och blicken är riktad mot fienden",
		"facing %d" % main.run.explore.facing)

	# 2: kameran snäppte — ingen tween som glider efter.
	var cam: Camera3D = main.cam
	check(cam.position.is_equal_approx(main._cam_pos()), "kameran snäpper till rutan direkt",
		"kam %s, ruta %s" % [str(cam.position), str(main._cam_pos())])
	check(is_equal_approx(cam.rotation.y, -main.run.explore.facing * PI / 2.0),
		"och till riktningen direkt", "%.3f rad" % cam.rotation.y)

	# 3: fienderna står i bild, utanför närplanet, och främsta ledet står i rummet på sin egen ruta.
	var i_strid := 0
	var utanför: Array = []
	var nära: Array = []
	var i_mur: Array = []
	var fel_ruta: Array = []
	for e in main._enemies:
		if e.get("nod") != nod.pos:
			continue
		var spr: Sprite3D = e.get("spr")
		if not is_instance_valid(spr):
			continue
		var p: Vector3 = spr.global_position
		if not _i_bild(cam, p) or not _i_bild(cam, p + Vector3(0, 0.25, 0)):
			utanför.append("%s på %.2fm: mitten %s, huvudet %s" % [str(p),
				cam.global_position.distance_to(p), str(cam.unproject_position(p)),
				str(cam.unproject_position(p + Vector3(0, 0.25, 0)))])
		if cam.global_position.distance_to(p) <= cam.near * 2.0:
			nära.append("%.3fm" % cam.global_position.distance_to(p))
		if i_strid < 2:
			# Främsta ledet: på golv, och kvar vid sin egen ruta (rummet finns bakom dem).
			var ruta := Vector2i(int(floor(p.x)), int(floor(p.z)))
			if not main.run.explore.floor_ref.is_floor_at(ruta):
				i_mur.append(str(ruta))
			var avstånd := Vector2(p.x - (nod.pos.x + 0.5), p.z - (nod.pos.y + 0.5)).length()
			if avstånd > 1.0:
				fel_ruta.append("%.2fm från rutan" % avstånd)
		i_strid += 1

	check(i_strid > 0, "striden har figurer i vyn", "%d fiender" % i_strid)
	check(utanför.is_empty(), "varje fiende ligger innanför synfältet",
		"" if utanför.is_empty() else ", ".join(utanför))
	check(nära.is_empty(), "och ingen av dem innanför kamerans närplan",
		"" if nära.is_empty() else ", ".join(nära))
	check(i_mur.is_empty(), "och främsta ledet står på golv, inte inne i en mur",
		"" if i_mur.is_empty() else ", ".join(i_mur))
	check(fel_ruta.is_empty(), "och kvar vid fiendens egen ruta — rummet står bakom dem",
		"" if fel_ruta.is_empty() else ", ".join(fel_ruta))

	Meta.fotolage(false)
	print("  TOTALT: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
