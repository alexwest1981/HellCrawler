## Vandringsprovet: mäter HUR en våning ser ut, inte bara att den går att spela.
##
##   godot --headless --path . --script res://tools/vandring.gd -- [antal seeds] [bana]
##
## Frågan provet svarar på är Alex': "banorna ska genereras random så man aldrig kan lära sig dem
## utantill, och de ska vara minst 4x så stora som de är nu — det ska ta lite tid att ta sig genom."
## Då behövs siffror på fyra saker per våning: hur stor ytan är, hur många rum och strider den bär,
## hur LÅNG vägen från start till bossen är (i steg, det är den som tar tid), och hur många återvänds-
## gränder den har (en kedja av rum har nästan inga, en riktig graf har fler).
##
## Provet rör ingenting: det genererar våningar, mäter dem och skriver ut en tabell. Exit 1 om någon
## våning inte går att spela (onåbar nod) — annars 0.
##
## ÄR INTE SAMMA SAK SOM tests/test_dungeon.gd, som prövar att EN våning uppfyller kontraktet.
## Det här är mätinstrumentet för formen över många våningar och seeds.
extends SceneTree

const SEEDS := [1, 7, 42, 1337, 90210, 424242, 555, 8888, 31337, 2026]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var antal := SEEDS.size()
	if args.size() >= 1:
		antal = int(args[0])
	var bara := ""
	if args.size() >= 2:
		bara = args[1]

	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var idn := stages.keys()
	idn.sort()

	var rader := []
	var kontrakt_fel := 0
	for id in idn:
		var stage: Stages.StageDef = stages[id]
		if not bara.is_empty() and id != bara:
			continue
		for våning in stage.floors:
			var start := Time.get_ticks_msec()
			for i in antal:
				var f := Dungeon.generate(stage, våning, SEEDS[i] * 7919 + våning, bestiary)
				if f == null:
					print("FEL: %s våning %d seed %d gav ingen våning" % [id, våning + 1, SEEDS[i]])
					kontrakt_fel += 1
					continue
				var dåliga := Dungeon.unreachable_nodes(f)
				if not dåliga.is_empty():
					print("FEL: %s våning %d seed %d har %d onåbara noder" % [id, våning + 1, SEEDS[i], dåliga.size()])
					kontrakt_fel += 1
				rader.append(_mät(f, id, våning, SEEDS[i], stage.difficulty))
			if bara.is_empty() and antal >= 5:
				continue
			print("  %s våning %d: %d våningar mätta på %d ms" % [id, våning + 1, antal, Time.get_ticks_msec() - start])

	# Sammanställningen: medelvärden över alla våningar, och per svårighetsgrad så en ändring syns där.
	print("")
	print("%-10s %-6s %5s %5s %6s %6s %6s %6s %6s %6s" % [
		"bana", "vån", "yta", "rutor", "öppna", "strider", "kistor", "facklor", "väg", "återv.gr"])
	var per_svårighet := {}
	for r in rader:
		if not bara.is_empty():
			print("%-10s %-6s %5d %5d %6d %6d %6d %6d %6d %6d" % [
				r["bana"], r["våning"], r["w"] * r["h"], r["golv"], r["öppna"], r["strider"], r["kistor"],
				r["facklor"], r["väg"], r["återvändsgränder"]])
		var nyckel: int = r["svårighet"]
		if not per_svårighet.has(nyckel):
			per_svårighet[nyckel] = {"n": 0, "yta": 0, "golv": 0, "strider": 0, "öppna": 0, "väg": 0, "väg2": 0, "återvändsgränder": 0, "kistor": 0, "facklor": 0}
		var d: Dictionary = per_svårighet[nyckel]
		d["n"] += 1
		for k in ["yta", "golv", "strider", "öppna", "väg", "återvändsgränder", "kistor", "facklor"]:
			d[k] += r[k]
		d["väg2"] += r["väg"] * r["väg"]
	print("")
	print("%-12s %5s %9s %8s %7s %9s %7s %9s %7s %8s %8s" % [
		"svårighet", "antal", "yta", "golvrutor", "öppna", "strider", "kistor", "facklor", "väg", "väg sd", "återv.gr"])
	var svårigheter := per_svårighet.keys()
	svårigheter.sort()
	for s in svårigheter:
		var d: Dictionary = per_svårighet[s]
		var n: int = maxi(1, d["n"])
		var medel: float = float(d["väg"]) / n
		# Standardavvikelsen i väglängd: hur olika långa våningarna är inom samma svårighet. Liten
		# spridning betyder att alla våningar tar ungefär lika lång tid — alltså en rytm man lär sig,
		# även om kartan ritas om varje gång.
		var sd: int = int(round(sqrt(maxf(0.0, float(d["väg2"]) / n - medel * medel))))
		print("%-12d %5d %9d %8d %7d %9d %7d %9d %7d %8d %8d" % [
			s, d["n"], d["yta"] / n, d["golv"] / n, d["öppna"] / n, d["strider"] / n, d["kistor"] / n,
			d["facklor"] / n, d["väg"] / n, sd, d["återvändsgränder"] / n])
	print("")
	print("OK: %d våningar mätta, ingen med onåbara noder" % rader.size() if kontrakt_fel == 0
		else "FEL: %d kontraktsbrott av %d våningar" % [kontrakt_fel, rader.size()])
	quit(1 if kontrakt_fel > 0 else 0)


## Mäter en våning: yta, rumsstorlek, noder, vägen start->boss i steg, och återvändsgränder.
func _mät(f, bana: String, våning: int, seed: int, svårighet: int) -> Dictionary:
	var golv := 0
	for y in f.h:
		for x in f.w:
			if f.tiles[y][x] == Dungeon.FLOOR:
				golv += 1
	# Rummen räknas som de rutor där hela 3x3-grannskapet är golv — det är rummets inre, och en
	# korridor (en ruta bred) har inga sådana. "öppna" är alltså golvyta som går att röra sig i på
	# riktigt, till skillnad från golvrutor som mest är korridorens enkelrad.
	var öppna := 0
	for y in f.h:
		for x in f.w:
			var hel := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not f.is_floor_at(Vector2i(x + dx, y + dy)):
						hel = false
						break
				if not hel:
					break
			if hel:
				öppna += 1
	# Vägen start -> boss i STEG (BFS), inte i rakt avstånd: det är stegen spelaren tar.
	var väg := _steg(f, f.start, f.boss_pos)
	# Återvändsgränder: golvrutor med exakt en golvgrannne. En ren rumskedja har två (start och boss)
	# eller några få; en förgrenad våning har fler — det är den siffran som säger om våningen går att
	# LÄRA sig (alltid samma form) eller inte.
	var åter := 0
	for y in f.h:
		for x in f.w:
			if f.tiles[y][x] != Dungeon.FLOOR:
				continue
			var grannar := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if f.is_floor_at(Vector2i(x, y) + d):
					grannar += 1
			if grannar <= 1:
				åter += 1
	var slag := {}
	for n in f.nodes:
		slag[n.kind] = int(slag.get(n.kind, 0)) + 1
	return {
		"bana": bana, "våning": våning + 1, "seed": seed, "w": f.w, "h": f.h, "yta": f.w * f.h,
		"golv": golv, "öppna": öppna, "väg": väg, "återvändsgränder": åter,
		"strider": int(slag.get("encounter", 0)), "kistor": int(slag.get("chest", 0)),
		"facklor": int(slag.get("torch", 0)), "svårighet": svårighet,
	}


## Antal steg mellan två rutor (BFS). -1 om de inte hänger ihop.
func _steg(f, a: Vector2i, b: Vector2i) -> int:
	var sedd := {a: 0}
	var kö: Array[Vector2i] = [a]
	while not kö.is_empty():
		var p: Vector2i = kö.pop_front()
		if p == b:
			return sedd[p]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if f.is_floor_at(n) and not sedd.has(n):
				sedd[n] = int(sedd[p]) + 1
				kö.append(n)
	return -1
