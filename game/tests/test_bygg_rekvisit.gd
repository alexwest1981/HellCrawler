## Möblering i 3D (M154). Alex: *"Viktigaste är att jag kan \"möblera\" det i 3d om jag vill med."*
##
## Provet går genom spelets EGEN väg — byggläget i `main.gd` på en riktig körning — inte genom en kopia:
##   * K/L bläddrar bland arterna i assets/props och går runt (och hoppar över nodbilderna),
##   * P ställer rekvisiten på rutan man TITTAR PÅ,
##   * X tar bort den igen (efter noderna, som förut),
##   * och den hamnar i kartfilen när man sparar (F2), så en tunna man ställt i 3D ligger kvar.
##
##   tools/ett_prov.sh tests/test_bygg_rekvisit.gd
extends SceneTree

var main: Node
var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


## Två golvrutor bredvid varandra utan noder: spelaren står i den västra och tittar österut, så
## `ahead()` är den östra. Utan det kan provet peka på en ruta som redan bär en fackla, och då mäter
## X-kontrollen noden i stället för rekvisiten.
func _par(f: Dungeon.Floor) -> Array:
	for y in range(1, f.h - 1):
		for x in range(1, f.w - 2):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if not (f.is_floor_at(a) and f.is_floor_at(b)):
				continue
			var upptagen := false
			for n in f.nodes:
				if n.pos == a or n.pos == b:
					upptagen = true
			if not upptagen:
				return [a, b]
	return []


func _init() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_01", 20260919)
	await process_frame
	var f: Dungeon.Floor = main.run.explore.floor_ref
	check(f != null, "en våning finns att möblera")

	# 1. Artlistan: samma mapp som spelets dekor, nodbilderna undantagna.
	var arter: Array = main._bygg_rekvisitlista()
	check(arter.size() > 50, "byggläget hittar rekvisitan i assets/props (%d arter)" % arter.size())
	check(not arter.has("chest") and not arter.has("boss"), "nodbilderna är inte valbara")

	# 2. K/L bläddrar och går RUNT (annars kommer man inte tillbaka till första arten).
	main.byggläge = true
	main.bygg_rekvisit = ""
	main._bygg_rekvisit_cykla(1)
	var första: String = main.bygg_rekvisit
	check(första == str(arter[0]), "K väljer den första arten", första)
	main._bygg_rekvisit_cykla(-1)
	check(main.bygg_rekvisit == str(arter[arter.size() - 1]),
		"L från den första går bakåt till den sista (runt)", main.bygg_rekvisit)
	main._bygg_rekvisit_cykla(1)
	check(main.bygg_rekvisit == första, "och framåt igen till den första")

	# 3. P ställer den på rutan man tittar på.
	var par := _par(f)
	check(par.size() == 2, "det finns två lediga golvrutor intill varandra")
	if par.size() == 2:
		var står: Vector2i = par[0]
		var mål: Vector2i = par[1]
		main.run.explore.pos = står
		main.run.explore.facing = Explore.EAST
		check(main._bygg_rutan() == mål, "rutan man tittar på är rutan österut", str(main._bygg_rutan()))
		main.bygg_rekvisit = "trälåda"
		main._bygg_rekvisit()
		var ställd: Dictionary = MapIo.rekvisita_vid(f, mål)
		check(str(ställd.get("art", "")) == "trälåda", "P ställde rekvisiten där", str(ställd))
		main.bygg_rekvisit = "kandelaber"
		main._bygg_rekvisit()
		check(f.rekvisita.size() == 1 and str(MapIo.rekvisita_vid(f, mål).get("art", "")) == "kandelaber",
			"en ny art på samma ruta ERSÄTTER (en per ruta)", "%d st" % f.rekvisita.size())

		# 4. X tar bort den.
		main._bygg_bort()
		check(MapIo.rekvisita_vid(f, mål).is_empty(), "X tog bort rekvisiten")

		# 5. Den hamnar i kartfilen. F2 skriver våningen; här mäts samma sak utan att röra spelets data.
		main.bygg_rekvisit = "bur"
		main._bygg_rekvisit()
		var d: Dictionary = MapIo.to_dict(f)
		var kvar := 0
		for r in d.get("rekvisita", []):
			if Vector2i(int(r["pos"][0]), int(r["pos"][1])) == mål:
				kvar += 1
		check(kvar == 1, "rekvisiten skrivs till våningen (sparas med F2)")
		var tillbaka := MapIo.from_dict(d, f.stage_id, f.index)
		check(not MapIo.rekvisita_vid(tillbaka, mål).is_empty(),
			"och läses tillbaka på samma ruta")

	# 6. En rekvisit i en vägg vägras med besked (samma regel som editorn).
	main.bygg_rekvisit = "trälåda"
	var vägg := Vector2i(-1, -1)
	for y in range(1, f.h - 1):
		for x in range(1, f.w - 1):
			if not f.is_floor_at(Vector2i(x, y)):
				vägg = Vector2i(x, y)
				break
		if vägg.x > 0:
			break
	if vägg.x > 0:
		var fel := MapIo.sätt_rekvisita(f, "trälåda", vägg)
		check(fel.contains("golv"), "en vägg vägrar rekvisiten", fel)

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
