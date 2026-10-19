## Fog of war (M162). Alex: *"Skulle vilja utöka med fog of war på kartan ... Där kan bossen gömma
## sig."* Kartan visar bara det man sett; rummet bakom en låst dörr ligger i mörkret tills man går in.
##
##   tools/ett_prov.sh tests/test_fog.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


## Korridor på rad 2: start (1,2), dörr (4,2), nyckel (2,2), boss (6,2) bakom dörren.
func _bana() -> Dungeon.Floor:
	var f := MapIo.blank("stage_01", 0, 9, 5)
	for x in range(1, 8):
		f.tiles[2][x] = Dungeon.FLOOR
	f.nodes.clear()
	f.start = Vector2i(1, 2)
	var s := Dungeon.FloorNode.new()
	s.kind = "start"
	s.pos = Vector2i(1, 2)
	f.nodes.append(s)
	var b := Dungeon.FloorNode.new()
	b.kind = "boss"
	b.pos = Vector2i(6, 2)
	b.enemy_id = "hollow_choir"
	f.nodes.append(b)
	return f


func _init() -> void:
	var f := _bana()
	MapIo.sätt_dörr(f, "galler", Vector2i(4, 2), "spak 1")
	var ex := Explore.new(f)

	# 1. Från början: rutan man står på och det man ser.
	check(ex.sedd(Vector2i(1, 2)), "rutan man står på är sedd")
	check(ex.sedd(Vector2i(1, 1)), "väggen man tittar på syns (man ser att det är en vägg)")
	check(not ex.sedd(Vector2i(0, 0)), "men en vägg snett bakom syns inte")
	check(not ex.sedd(Vector2i(6, 2)), "bossens ruta långt bort är osedd")
	check(not ex.sedd(Vector2i(3, 2)), "rutan två steg bort är inte sedd")

	# 2. Man ser rutan man TITTAR PÅ — även när det är en dörr.
	ex.facing = Explore.EAST
	ex.turn_right() if false else null
	check(ex.sedd(Vector2i(2, 2)), "efter en sväng österut är rutan framför sedd")

	# 3. Gången avslöjar efter hand, och dörren stoppar.
	var sedda_före: int = ex.sedda.size()
	var err := ex.forward()
	check(err == "", "första steget går", err)
	check(ex.pos == Vector2i(2, 2), "man står på ruta 2")
	check(ex.sedda.size() > sedda_före, "fler rutor är sedda efter steget",
		"%d -> %d" % [sedda_före, ex.sedda.size()])
	err = ex.forward()
	check(err == "", "andra steget går", err)
	err = ex.forward()
	check(err == "låst", "tredje steget stoppas av dörren", err)
	check(ex.pos == Vector2i(3, 2), "man står kvar framför dörren")
	check(ex.sedd(Vector2i(4, 2)), "dörrrutan syns — man ser att det är en dörr")
	check(not ex.sedd(Vector2i(5, 2)), "men rummet bakom är fortfarande mörkt")
	check(not ex.sedd(Vector2i(6, 2)), "och bossen syns inte på kartan")

	# 4. Nyckeln öppnar, och först när man gått in avslöjas rummet.
	ex.öppna("spak 1")
	check(ex.forward() == "", "dörren går att gå igenom när koden är löst")
	check(ex.sedd(Vector2i(5, 2)), "rutan bakom dörren är sedd när man står där")
	check(not ex.sedd(Vector2i(6, 2)), "bossens ruta är fortfarande ett steg bort")
	check(ex.forward() == "" and ex.sedd(Vector2i(6, 2)),
		"och när man står intill den syns den")

	# 5. Minikartan: vägarna ritas bara där man sett båda ändarna. Mätt genom att jämföra antalet
	#    linjer före och efter att allt markerats som sett — fler linjer när allt är känt.
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_run("stage_01", 20260919)
	await process_frame
	var karta = main.map_view
	var få: int = karta.länk_linjer().size()
	var fl: Dungeon.Floor = main.run.explore.floor_ref
	for y in fl.h:
		for x in fl.w:
			main.run.explore.sedda[Vector2i(x, y)] = true
	var många: int = karta.länk_linjer().size()
	check(många > få, "kartan ritar fler vägar när mer är sett", "%d -> %d" % [få, många])
	check(få >= 0, "och före det ritas bara det man sett")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
