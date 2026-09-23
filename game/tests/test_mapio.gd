## Kartfilerna: formatet, kontrollerna och att en handritad våning faktiskt spelar.
##
## Det här provet vaktar tre saker:
##   1. Att en trasig våning INTE går att spara (kontrollerna är grinden, inte en varning).
##   2. Att en sparad våning kommer tillbaka exakt som den var (rutnät och noder).
##   3. Att spelet använder den: Dungeon.generate ska ge kartans rutor, inte generatorns.
##   godot --headless --script res://tests/test_mapio.gd
extends SceneTree

const TESTDIR := "user://test_kartor/"
const DEMO := "stage_01"

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
	var d := DirAccess.open(TESTDIR)
	if d == null:
		return
	for fil in d.get_files():
		d.remove(fil)

func _nod(f: Dungeon.Floor, kind: String, pos: Vector2i, enemy: String = "") -> void:
	var n := Dungeon.FloorNode.new()
	n.kind = kind
	n.pos = pos
	n.enemy_id = enemy
	f.nodes.append(n)
	if kind == "start":
		f.start = pos
	elif kind == "boss":
		f.boss_pos = pos
	elif kind == "shovel":
		f.shovel_pos = pos

func _init() -> void:
	_städa()
	print("— en våning som inte går att spela får inte sparas —")
	var tom := MapIo.blank("test_bana", 0, 11, 11)
	var fel := MapIo.validate(tom)
	check(fel.size() >= 3, "en tom yta nekas", "%d fel: %s" % [fel.size(), "; ".join(fel).left(80)])
	check(not fel.is_empty() and "boss" in "; ".join(fel), "och felet säger vad som fattas")
	var skrivna := MapIo.save_map(tom, TESTDIR)
	check(skrivna.size() >= 3, "spara vägrar", "%d fel" % skrivna.size())
	check(not MapIo.has_map("test_bana", 0, TESTDIR), "och ingen fil skapades")

	print("")
	print("— en riktig våning: tur och retur —")
	var f := MapIo.blank("test_bana", 0, 11, 11)
	f.nodes = []
	_nod(f, "start", Vector2i(2, 2))
	_nod(f, "boss", Vector2i(8, 8), "bellmother")
	_nod(f, "shovel", Vector2i(8, 8))
	_nod(f, "encounter", Vector2i(5, 2), "skitterling")
	_nod(f, "encounter", Vector2i(2, 5), "crawler")
	_nod(f, "encounter", Vector2i(5, 5), "hound")
	_nod(f, "encounter", Vector2i(8, 2), "wisp")
	_nod(f, "chest", Vector2i(5, 8))
	check(MapIo.validate(f).is_empty(), "den uppfyller kraven", "; ".join(MapIo.validate(f)))
	check(MapIo.save_map(f, TESTDIR).is_empty(), "den sparades utan fel")
	check(MapIo.has_map("test_bana", 0, TESTDIR), "filen finns på disken")

	var tillbaka := MapIo.load_map("test_bana", 0, null, {}, TESTDIR)
	check(tillbaka != null, "och går att läsa igen")
	if tillbaka != null:
		var a: Array = MapIo.to_dict(f)["tiles"]
		var b: Array = MapIo.to_dict(tillbaka)["tiles"]
		check(a == b, "rutnätet är identiskt", "%d rader" % b.size())
		check(tillbaka.nodes.size() == f.nodes.size(), "lika många noder",
			"%d mot %d" % [tillbaka.nodes.size(), f.nodes.size()])
		check(tillbaka.start == f.start and tillbaka.boss_pos == f.boss_pos
			and tillbaka.shovel_pos == f.shovel_pos, "start, boss och nedstigning pekar rätt")
		var slag := {}
		for n in tillbaka.nodes:
			slag[n.kind] = int(slag.get(n.kind, 0)) + 1
		check(int(slag.get("encounter", 0)) == 4, "fyra strider följde med", str(slag))
		var boss: Dungeon.FloorNode = null
		for n in tillbaka.nodes:
			if n.kind == "boss":
				boss = n
		check(boss != null and boss.enemy_id == "bellmother", "bossens id följde med")

	print("")
	print("— en avskuren boss fångas —")
	var stängd := MapIo.load_map("test_bana", 0, null, {}, TESTDIR)
	if stängd != null:
		# Muren runt bossen: rutan och alla fyra grannar blir vägg.
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var p: Vector2i = stängd.boss_pos + d
			stängd.tiles[p.y][p.x] = Dungeon.WALL
		var fel2 := MapIo.validate(stängd)
		check(not fel2.is_empty(), "kontrollerna fångar den", "; ".join(fel2).left(90))
		check("boss går inte att nå" in "; ".join(fel2), "och säger vilken nod som är avskuren",
			"; ".join(fel2).left(90))

	print("")
	print("— spelet använder den handritade våningen —")
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var stage: Stages.StageDef = stages.get(DEMO)
	check(stage != null, "demobanan finns", DEMO)
	check(MapIo.has_map(DEMO, 0), "och har en ritad våning 1",
		MapIo.path_for(DEMO, 0).get_file())
	var ritad := MapIo.load_map(DEMO, 0, stage, bestiary)
	check(ritad != null, "den går att läsa")
	if ritad != null:
		var fel3 := MapIo.validate(ritad)
		check(fel3.is_empty(), "och uppfyller samma krav som generatorn", "; ".join(fel3))
		var från_generatorn := Dungeon.generate(stage, 0, 20260919, bestiary)
		var karta_rutor: Array = MapIo.to_dict(ritad)["tiles"]
		var spel_rutor: Array = MapIo.to_dict(från_generatorn)["tiles"]
		check(spel_rutor == karta_rutor, "Dungeon.generate ger kartans rutor, inte generatorns",
			"%dx%d" % [från_generatorn.w, från_generatorn.h])
		# Och en våning UTAN ritad karta ska fortfarande genereras.
		var v2 := Dungeon.generate(stage, 1, 20260919, bestiary)
		check(MapIo.to_dict(v2)["tiles"] != karta_rutor, "våning 2 genereras som förut",
			"%dx%d" % [v2.w, v2.h])
		# Strider utan fiende får en ur banans pool när kartan läses av spelet.
		var utan: Dungeon.Floor = MapIo.load_map(DEMO, 0, stage, bestiary)
		var med_fiende := 0
		for n in utan.nodes:
			if n.kind == "encounter" and not n.enemy_id.is_empty():
				med_fiende += 1
		check(med_fiende >= 4, "och varje strid har en fiende", "%d strider" % med_fiende)

	# --- M29: en ritad våning får inte hämta sin boss ur en ANNAN bana -------------------------
	# Mätt fel som detta prov vaktar: stage_01:s ritade våning 1 hade `bellmother` (900 hp, 6 ögon,
	# svårighet 7:s boss i stage_25) i stället för banans egen `hollow_choir`. Följden mättes med
	# tools/balance.gd: svårighet 1 var 0/20 för standardspelaren — den gick inte att vinna alls.
	# Provet läser VARJE ritad våning och kräver att bossen står i banans egen lista, så en
	# inaktuell boss i en karta blir ett rött prov i stället för ett omätbart omöjligt spel.
	print("")
	print("— varje ritad våning använder banans egen boss —")
	var katalog := DirAccess.open(MapIo.DIR)
	var kartfiler: Array = []
	if katalog != null:
		for fil in katalog.get_files():
			if fil.ends_with(".json"):
				kartfiler.append(fil)
	kartfiler.sort()
	check(kartfiler.size() >= 1, "kartmappen har filer", str(kartfiler))
	for fil in kartfiler:
		var bana: PackedStringArray = fil.get_basename().rsplit("_", true, 1)
		var bana_id := str(bana[0]) if bana.size() == 2 else ""
		var våningsnr := int(bana[1]) if bana.size() == 2 else -1
		var bana_def: Stages.StageDef = stages.get(bana_id)
		check(bana_def != null, "%s: banan finns" % fil, bana_id)
		if bana_def == null:
			continue
		var ritad_våning := MapIo.load_map(bana_id, våningsnr, bana_def, bestiary)
		if ritad_våning == null:
			check(false, "%s: går att läsa" % fil)
			continue
		var tillåtna := []
		for b in [bana_def.boss, bana_def.final_boss]:
			if not str(b).is_empty() and not tillåtna.has(str(b)):
				tillåtna.append(str(b))
		for b in bana_def.bosses:
			if not tillåtna.has(str(b)):
				tillåtna.append(str(b))
		var boss_nod: Dungeon.FloorNode = null
		for n in ritad_våning.nodes:
			if n.kind == "boss":
				boss_nod = n
		check(boss_nod != null, "%s: har en boss" % fil)
		if boss_nod != null:
			check(tillåtna.has(boss_nod.enemy_id),
				"%s: bossen %s står i banans lista" % [fil, boss_nod.enemy_id], str(tillåtna))
			var def: Enemies.EnemyDef = bestiary.get(boss_nod.enemy_id)
			check(def != null, "%s: bossen finns i bestiariet" % fil)

	# --- M30: den ritade våningen bestämmer sin egen längd --------------------------------------
	# Frågan kom från M29: stage_01:s ritade våning 1 bär 13 strider medan `stage_01.json` deklarerar
	# `encounters_per_floor: 4`. Ska den ritade vägen läsa fältet (bugg) eller bestämma själv (smak)?
	#
	# Mätt svar: fältet är GENERATORNS ratt. dungeon.gd läser det per MELLANRUM (min(fältet, platser)
	# i varje rum mellan start och boss), alltså ger en genererad våning i praktiken ~2× det deklarerade
	# antalet — stage_01 (deklarerat 4) får 8 strider per genererad våning, stage_05/09 (5) får 10.
	# Fältet är alltså redan inte "strider per våning" på den genererade vägen, och en ritad våning som
	# läste det som ett tak skulle få färre strider än generatorns våningar. En ritad karta har sina
	# noder i filen, och editorn skapar en ny våning som tom ruta (MapIo.blank) — fältet har aldrig nått
	# en ritad våning. Slutsatsen är alltså: INTE en bugg utan en smakfråga för Alex (flaggad i M30).
	# Provet pinnar beslutet så att en framtida "fix" som klipper de ritade striderna syns direkt.
	print("")
	print("— den ritade våningen bestämmer sin egen längd —")
	var rv := MapIo.load_map(DEMO, 0, stage, bestiary)
	var rått: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapIo.path_for(DEMO, 0)))
	var i_filen := 0
	for n in rått.get("nodes", []):
		if str(n.get("kind", "")) == "encounter":
			i_filen += 1
	var laddade := 0
	for n in rv.nodes:
		if n.kind == "encounter":
			laddade += 1
	check(laddade == i_filen, "att läsa kartan kapar inte striderna i den",
		"%d laddade av %d i filen" % [laddade, i_filen])
	check(laddade > stage.encounters_per_floor, "fler strider än banans deklarerade antal",
		"%d ritade mot deklarerat %d" % [laddade, stage.encounters_per_floor])
	check(laddade >= MapIo.MIN_ENCOUNTERS, "och minst så många som kartkraven kräver", "%d" % laddade)
	var gen1 := Dungeon.generate(stage, 1, 20260919, bestiary)
	var i_generatorn := 0
	for n in gen1.nodes:
		if n.kind == "encounter":
			i_generatorn += 1
	check(i_generatorn >= stage.encounters_per_floor,
		"generatorns våning följer fältet (minst så många strider)",
		"%d genererade mot deklarerat %d" % [i_generatorn, stage.encounters_per_floor])

	_städa()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
