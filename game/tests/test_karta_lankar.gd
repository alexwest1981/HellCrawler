## VÄGARNA MELLAN RUMMEN PÅ MINIKARTAN (M119) — och att de är SANNA.
##
## Alex: *"Går det på något vis få en länk över hur vägen går mellan de olika punkterna? Liksom en
## linje mellan punkt a och b?"* Kartan han menar är MINIKARTAN i HUD:ens övre högra hörn (den han just
## fått dubbelt så stor, M118): där är "punkterna" rummen och vägen mellan dem är korridorerna i
## våningsdatan. Världskartan (`ui/worldmap_view.gd`) har inga kopplingar i sin data alls — bara noder
## och deras plats på en bild — så där finns ingenting sant att dra en linje efter.
##
## Provet mäter tre saker, och den andra är den som gör linjerna ärliga:
##   1. KOPPLINGARNA ÄR SANNA. Varje linje förbinder två rum med en gång mellan sig, gången går inte
##      genom ett TREDJE rum, rutorna i vägen ligger på golv och två i rad ligger intill varandra.
##   2. INGEN KOPPLING SAKNAS OCH INGEN ÄR PÅHITTAD. Provet räknar fram paren med en EGEN, oberoende
##      sökning (blockerad BFS per par) och jämför mängderna: 0 avvikelser. Det är siffran "antal
##      linjer mot antal faktiska kopplingar".
##   3. KARTAN RITAR DEM. Kartans egna streck (`MapView.länk_linjer`) är ett per steg i vägen, ett
##      polyline per koppling, och alla ligger innanför kartans ruta.
##
## Fyra våningar mäts: den handritade `data/maps/stage_01_0.json` (som saknar `rum`-lista — den första
## våningen man möter), en genererad 34x34, den andra handritade (`stage_02_0`) och en genererad 50x50.
##
## FLIT-BORT (beviset för att provet kan gå rött): ta bort tredje-rums-spärren i `_väg_mellan_rum` →
## "ingen genväg genom ett tredje rum" faller; byt korridorregeln i `rumslänkar` mot "para ihop ALLA
## rum" → avvikelserna räknas upp och "0 avvikelser" faller.
##
## KÖRNING: godot --headless --script res://tests/test_karta_lankar.gd
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

const GRANNAR := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]


## PROVETS EGEN SÖKNING: går det en väg från `från` till `till` på golv där inget annat rums kärna får
## beträdas? Rutnätet läses ur `f.tiles` (inte ur spelets `is_floor_at`), och BFS:en är skriven här —
## produktionskoden kommer fram till samma sak genom korridorkomponenterna, och det är just den
## genvägen som ska prövas.
func _nås(f: Dungeon.Floor, ägare: Dictionary, från: Vector2i, till: Vector2i, a: int, b: int) -> bool:
	var sedd := {från: true}
	var kö: Array[Vector2i] = [från]
	var i := 0
	while i < kö.size():
		var p: Vector2i = kö[i]
		i += 1
		if p == till:
			return true
		for d in GRANNAR:
			var n: Vector2i = p + d
			if sedd.has(n) or n.x < 0 or n.y < 0 or n.x >= f.w or n.y >= f.h:
				continue
			if f.tiles[n.y][n.x] != Dungeon.FLOOR:
				continue
			var v: int = int(ägare.get(n, -1))
			if v >= 0 and v != a and v != b:
				continue
			sedd[n] = true
			kö.append(n)
	return false


## Alla par som går att nå för varandra utan att passera ett tredje rum — provets egen sanning.
func _oberoende_par(f: Dungeon.Floor, rum: Array) -> Dictionary:
	var ägare := {}
	for i in rum.size():
		for p in rum[i]:
			ägare[p] = i
	var par := {}
	for a in rum.size():
		for b in range(a + 1, rum.size()):
			if _nås(f, ägare, Dungeon.rumsmitt(rum[a]), Dungeon.rumsmitt(rum[b]), a, b):
				par[Vector2i(a, b)] = true
	return par


## Mäter en våning: sanna vägar, antalet kopplingar mot provets egen räkning, och vägens form.
func _våning(namn: String, f: Dungeon.Floor) -> void:
	print("")
	print("— %s (%dx%d) —" % [namn, f.w, f.h])
	var t0 := Time.get_ticks_msec()
	var rum := Dungeon.rum_ur_rutnätet(f)
	var länkar := Dungeon.rumslänkar(f)
	var ms := Time.get_ticks_msec() - t0
	var steg := 0
	for l in länkar:
		steg += (l["väg"] as Array).size() - 1
	var golvrutor := 0
	for y in f.h:
		for x in f.w:
			golvrutor += 1 if f.is_floor_at(Vector2i(x, y)) else 0
	print("      %d golvrutor, %d rum, %d kopplingar, %d streck, räknat på %d ms"
		% [golvrutor, rum.size(), länkar.size(), steg, ms])
	check(rum.size() >= 2, "%s: våningen har fler än ett rum" % namn, "%d rum" % rum.size())
	check(not länkar.is_empty(), "%s: rummen binds samman av minst en väg" % namn,
		"%d kopplingar" % länkar.size())

	# 1. Vägen är sann: golv, intill varandra, från det ena rummets mitt till det andras, och aldrig
	#    in i ett tredje rum.
	var ägare := {}
	for i in rum.size():
		for p in rum[i]:
			ägare[p] = i
	var fel := []
	var utan_korridor := []
	for l in länkar:
		var a: int = l["a"]
		var b: int = l["b"]
		var väg: Array = l["väg"]
		if väg.size() < 2:
			fel.append("koppling %d-%d har ingen väg" % [a, b])
			continue
		if väg[0] != Dungeon.rumsmitt(rum[a]) or väg[väg.size() - 1] != Dungeon.rumsmitt(rum[b]):
			fel.append("koppling %d-%d börjar/slutar inte i rummets mitt" % [a, b])
		var egna := 0
		for i in väg.size():
			var p: Vector2i = väg[i]
			if not f.is_floor_at(p):
				fel.append("koppling %d-%d går genom en vägg på %s" % [a, b, str(p)])
				break
			var v: int = int(ägare.get(p, -1))
			if v >= 0 and v != a and v != b:
				fel.append("koppling %d-%d går genom rum %d på %s" % [a, b, v, str(p)])
				break
			if v < 0:
				egna += 1
			if i > 0 and (p - (väg[i - 1] as Vector2i)).abs().x + (p - (väg[i - 1] as Vector2i)).abs().y != 1:
				fel.append("koppling %d-%d hoppar mellan %s och %s" % [a, b, str(väg[i - 1]), str(p)])
				break
		if egna == 0:
			utan_korridor.append("%d-%d" % [a, b])
	check(fel.is_empty(), "%s: varje väg ligger på golv, ruta för ruta, utan att gå genom ett tredje rum"
		% namn, ", ".join(fel.slice(0, 3)))
	check(utan_korridor.is_empty(), "%s: och varje koppling har en riktig korridor (rutor utanför båda rummen)"
		% namn, ", ".join(utan_korridor.slice(0, 3)))

	# 2. Antalet: provets egen räkning mot kartans kopplingar. 0 avvikelser = varje linje är en faktisk
	#    koppling, och ingen faktisk koppling saknar linje.
	var oberoende := _oberoende_par(f, rum)
	var mina := {}
	for l in länkar:
		mina[Vector2i(int(l["a"]), int(l["b"]))] = true
	var saknas := []
	for k in oberoende:
		if not mina.has(k):
			saknas.append(str(k))
	var påhittade := []
	for k in mina:
		if not oberoende.has(k):
			påhittade.append(str(k))
	var avvikelser := saknas.size() + påhittade.size()
	print("      faktiska kopplingar (provets egen BFS): %d, kartans: %d, avvikelser: %d"
		% [oberoende.size(), mina.size(), avvikelser])
	check(oberoende.size() == mina.size() and avvikelser == 0,
		"%s: antalet kopplingar är de FAKTISKA i våningsdatan — 0 avvikelser" % namn,
		"faktiska %d, kartans %d (%d saknas, %d påhittade)" % [oberoende.size(), mina.size(),
			saknas.size(), påhittade.size()])
	check(not oberoende.is_empty(), "%s: våningen har riktiga kopplingar att rita" % namn,
		"%d" % oberoende.size())


func _initialize() -> void:
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Menyn tar varje tangent (se test_rust_klot); här behövs den bort för att körningen ska synas.
	main._dölj_meny()
	main._start_run("stage_01", 20260919)
	await process_frame

	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var s1: Stages.StageDef = stages["stage_01"]
	var s2: Stages.StageDef = stages["stage_02"]

	print("VÄGARNA MELLAN RUMMEN: fyra våningar mäts, handritade och genererade.")
	# Den här körningens våning är den handritade stage_01_0 — den som saknar `rum`-lista.
	_våning("stage_01 våning 1 (HANDritad, data/maps/stage_01_0.json)", main.run.explore.floor_ref)
	_våning("stage_01 våning 2 (genererad 34x34)",
		Dungeon.generate(s1, 1, 20260919 + 7919, bestiary))
	var ritad2 := MapIo.load_map("stage_02", 0, s2, bestiary)
	check(ritad2 != null, "stage_02 våning 1 läses ur data/maps/stage_02_0.json")
	if ritad2 != null:
		_våning("stage_02 våning 1 (HANDritad, data/maps/stage_02_0.json)", ritad2)
	var s50: Stages.StageDef = null
	for id in stages:
		var s: Stages.StageDef = stages[id]
		if s.difficulty >= 7:
			s50 = s
			break
	check(s50 != null, "hittade en bana med 50x50-våning (svårighet 7+)", s50.id if s50 else "—")
	if s50 != null:
		_våning("%s våning 1 (genererad 50x50)" % s50.id, Dungeon.generate(s50, 0, 4242, bestiary))

	print("")
	print("— KARTAN RITAR DEM (den våning körningen står på, den handritade) —")
	var f: Dungeon.Floor = main.run.explore.floor_ref
	# KARTAN RITAR BARA DÄR MAN SETT BÅDA ÄNDARNA (fog på kartan). Provet mäter GEOMETRIN för
	# kopplingarna, inte dimman, så det avslöjar våningen först — annars mäter det hur långt provets
	# gubbe råkade gå (mätt: 1 streck av 48 steg).
	for y in f.h:
		for x in f.w:
			if f.is_floor_at(Vector2i(x, y)):
				main.run.explore.sedda[Vector2i(x, y)] = true
	var länkar: Array = main.map_view.länkar()
	var steg_väntat := 0
	for l in länkar:
		steg_väntat += (l["väg"] as Array).size() - 1
	var linjer: Array = main.map_view.länk_linjer()
	check(linjer.size() == steg_väntat,
		"kartan ritar ett streck per steg i varje väg (ett polyline per koppling)",
		"%d streck mot %d steg i %d kopplingar" % [linjer.size(), steg_väntat, länkar.size()])
	check(linjer.size() >= länkar.size() and länkar.size() > 0,
		"och varje koppling blir minst ett streck", "%d streck" % linjer.size())
	var utanför := []
	var mått: Array = main.map_view.karta_mått(f)
	var cell: float = mått[0]
	var origin: Vector2 = mått[1]
	var ruta := Rect2(Vector2.ZERO, main.MapView.MAP_SIZE).grow(1.0)
	for linje in linjer:
		for p in linje:
			if not ruta.has_point(p):
				utanför.append(str(p))
	check(utanför.is_empty(), "och alla streck ligger innanför kartans ruta (76x60 px)",
		", ".join(utanför.slice(0, 3)))
	# Strecken ska följa rutorna: varje ändpunkt är en rutas MITT i kartans koordinater.
	var fel_mitt := []
	for linje in linjer:
		for p in linje:
			var g := (Vector2(p) - origin) / cell - Vector2(0.5, 0.5)
			if absf(g.x - roundf(g.x)) > 0.01 or absf(g.y - roundf(g.y)) > 0.01:
				fel_mitt.append("%s -> %s" % [str(p), str(g)])
	check(fel_mitt.is_empty(), "och varje ändpunkt ligger i mitten av sin ruta",
		", ".join(fel_mitt.slice(0, 3)))
	# OCH ATT `_draw` FAKTISKT RITAR DEM. Provet läser kartans EGEN lista över de streck den ritade
	# (`_ritade_linjer`), inte bara de framräknade: en ritning som tappas bort mellan räkningen och
	# `draw_line` syns annars bara i bilden.
	main.map_view.queue_redraw()
	await process_frame
	await process_frame
	var ritade: Array = main.map_view._ritade_linjer
	check(ritade.size() == linjer.size() and ritade.size() > 0,
		"och `_draw` ritar dem: samma streck ligger i kartans ritlista",
		"%d ritade mot %d framräknade" % [ritade.size(), linjer.size()])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
