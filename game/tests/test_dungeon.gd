## Svep över ALLA stages/våningar/seeds. Det här är testet som gör att 40 banor är 40 datafiler
## och inte 40 överraskningar: en bana som inte går att spela fångas här, inte av spelaren.
##   godot --headless --script res://tests/test_dungeon.gd
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

const SEEDS := [1, 7, 42, 1337, 90210]

func _initialize() -> void:
	print("— innehållet laddar —")
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	check(stages.size() >= 40, "minst 40 stages", "%d st" % stages.size())
	check(bestiary.size() >= 16, "bestiariet laddar", "%d fiender" % bestiary.size())

	var missing := []
	var bossar_i_bruk := {}
	for id in stages:
		var s: Stages.StageDef = stages[id]
		if not bestiary.has(s.boss):
			missing.append("%s -> %s" % [s.id, s.boss])
		if not s.final_boss.is_empty() and not bestiary.has(s.final_boss):
			missing.append("%s -> %s" % [s.id, s.final_boss])
		for b in s.bosses:
			if not bestiary.has(b):
				missing.append("%s -> %s" % [s.id, b])
			bossar_i_bruk[str(b)] = true
		bossar_i_bruk[s.boss] = true
		bossar_i_bruk[s.final_boss] = true
	check(missing.is_empty(), "alla stage-bossar finns i bestiariet", ", ".join(missing))

	# Och omvändningen: en boss i bestiariet som INGEN bana någonsin kallar på är dött innehåll.
	# "Ash Sovereign" (1400 hp) stod så i flera veckor — ritad, namnsatt på 13 språk och omöjlig
	# att möta. Det här provet är hela anledningen till att det upptäcktes.
	var oanvända := []
	for id in bestiary:
		if str(bestiary[id].kind) == "boss" and not bossar_i_bruk.has(id):
			oanvända.append(id)
	check(oanvända.is_empty(), "varje boss i bestiariet används av minst en bana",
		"oanvända: %s" % str(oanvända))

	if stages.is_empty() or bestiary.is_empty():
		print("")
		print("%d kontroller, %d fel — avbryter (inget innehåll att svepa)" % [checks, fails])
		quit(1)
		return

	print("— determinism —")
	var s1: Stages.StageDef = stages["stage_01"]
	# Välj en våning som INTE är handritad: en ritad karta ska vara identisk varje gång (det är hela
	# poängen), så seed-spridningen kan bara mätas på en genererad våning.
	var fri_våning := 0
	while fri_våning < s1.floors and MapIo.has_map(s1.id, fri_våning):
		fri_våning += 1
	check(fri_våning < s1.floors, "det finns en genererad våning att mäta på",
		"våning %d av %d" % [fri_våning + 1, s1.floors])
	var a := Dungeon.generate(s1, fri_våning, 42, bestiary)
	var b := Dungeon.generate(s1, fri_våning, 42, bestiary)
	var c := Dungeon.generate(s1, fri_våning, 43, bestiary)
	check(a.checksum() == b.checksum(), "samma seed ger identisk våning", "checksum %d" % a.checksum())
	check(a.checksum() != c.checksum(), "olika seed ger olika våning", "checksum %d vs %d" % [a.checksum(), c.checksum()])
	# Och en handritad våning ska strunta i seedet — det är den nya avsiktliga motsatsen.
	if MapIo.has_map(s1.id, 0):
		var r1 := Dungeon.generate(s1, 0, 42, bestiary)
		var r2 := Dungeon.generate(s1, 0, 43, bestiary)
		check(r1.checksum() == r2.checksum(), "en handritad våning är likadan för alla seed",
			"checksum %d" % r1.checksum())

	print("— svep: alla stages x %d seeds x alla våningar —" % SEEDS.size())
	var floor_count := 0
	var unreachable := 0
	var no_boss := 0
	var no_shovel := 0
	var too_few_encounters := 0
	var unknown_enemy := []
	var same_tile := 0
	var empty_floor := 0
	var checksum_dupes := {}
	for id in stages:
		var stage: Stages.StageDef = stages[id]
		for seed_value in SEEDS:
			for fi in stage.floors:
				var f := Dungeon.generate(stage, fi, seed_value, bestiary)
				floor_count += 1
				if Dungeon.unreachable_nodes(f).size() > 0:
					unreachable += 1
				if f.nodes_of_kind("boss").is_empty():
					no_boss += 1
				if f.nodes_of_kind("shovel").is_empty():
					no_shovel += 1
				if f.nodes_of_kind("encounter").size() < 4:
					too_few_encounters += 1
				if f.start == f.boss_pos:
					same_tile += 1
				var floors_tiles := 0
				for row in f.tiles:
					for t in row:
						if t == Dungeon.FLOOR:
							floors_tiles += 1
				if floors_tiles < 20:
					empty_floor += 1
				for n in f.nodes:
					if n.kind == "encounter" and not bestiary.has(n.enemy_id):
						unknown_enemy.append(n.enemy_id)
				var key := "%d:%d" % [f.index, f.checksum()]
				checksum_dupes[key] = checksum_dupes.get(key, 0) + 1

	check(unreachable == 0, "varje våning är sammankopplad (alla noder nåbara)", "%d våningar" % floor_count)
	check(no_boss == 0, "varje våning har en boss")
	check(no_shovel == 0, "varje våning har en shovel")
	check(same_tile == 0, "start och boss ligger aldrig på samma ruta")
	check(empty_floor == 0, "ingen våning är tom på golv")
	check(too_few_encounters == 0, "varje våning har minst 4 strider")
	check(unknown_enemy.is_empty(), "inga okända fiende-id:n i noderna", ", ".join(unknown_enemy.slice(0, 3)))

	print("— banornas form —")
	var floor_min := 99
	var floor_max := 0
	for id in stages:
		var s: Stages.StageDef = stages[id]
		floor_min = min(floor_min, s.floors)
		floor_max = max(floor_max, s.floors)
	check(floor_min >= 3, "ingen bana är kortare än 3 våningar", "min %d" % floor_min)
	check(floor_max <= 8, "ingen bana är längre än 8 våningar", "max %d" % floor_max)
	var total_floors := 0
	for id in stages:
		total_floors += stages[id].floors
	check(total_floors >= 150, "innehållsvolymen räcker för ~40 banor", "%d våningar totalt" % total_floors)

	# --- en svårighetsgrad = EN uppsättning rattar ------------------------------------------------
	# De 40 banorna byggdes som 9 svårighetsgrader × 4-9 filer: varje grupp är samma bana med eget namn
	# och tema (M4:s tabell säger redan stage_01-04, 05-08, 09-12). Därför gav mätaren identiska rader
	# ända in i sista decimal för stage_09, 10, 11 och 12 — samma rattar och samma 20 seeds ger samma
	# körningar, och det är data, inte en trasig väljare (M30, och mätaren skriver nu "SAMMA BANA SOM").
	# Det här provet vaktar det som INTE är avsiktligt: en fil vars rattar hör till en annan
	# svårighetsgrad än den påstår — exakt den felklassen M29 hittade (ett datafält som pekade på
	# svårighet 7 i en svårighet-1-bana).
	print("")
	print("— en svårighetsgrad = en uppsättning rattar —")
	var svårigheter := {}
	var grupper := {}
	for id in stages:
		var s: Stages.StageDef = stages[id]
		svårigheter[s.difficulty] = int(svårigheter.get(s.difficulty, 0)) + 1
		# Samma fältlista som mätarens `_avtryck` (tools/balance.gd): det som styr en körning. Temat
		# är inte med — det ritar våningen men rör ingen siffra.
		var avtryck := "%d våningar %d möten tiers %s boss %s slut %s" % [
			s.floors, s.encounters_per_floor, str(s.tiers), s.boss, s.final_boss]
		if not grupper.has(avtryck):
			grupper[avtryck] = []
		grupper[avtryck].append({"id": s.id, "sv": s.difficulty})
	var saknade := []
	for d in range(1, 10):
		if not svårigheter.has(d):
			saknade.append(d)
	check(saknade.is_empty(), "varje svårighetsgrad 1-9 har minst en bana", "saknas: %s" % str(saknade))
	var blandade := []
	var klonrader := []
	for avtryck_nyckel in grupper:
		var rader: Array = grupper[avtryck_nyckel]          # [{id, sv}, ...]
		var sv: Array = []
		var namn: Array = []
		for r in rader:
			namn.append("%s (sv %d)" % [r["id"], r["sv"]])
			if not sv.has(r["sv"]):
				sv.append(r["sv"])
		klonrader.append("%d banor: %s" % [namn.size(), ", ".join(namn)])
		if sv.size() > 1:
			blandade.append(", ".join(namn))
	check(blandade.is_empty(),
		"samma rattar hör till EN svårighetsgrad (ingen fil har fel svårighetsgrad)",
		"; ".join(blandade))
	print("    %d unika uppsättningar rattar för %d banor" % [grupper.size(), stages.size()])
	for rad in klonrader:
		print("      %s" % rad)

	print("")
	print("%d kontroller, %d fel i %d genererade våningar" % [checks, fails, floor_count])
	quit(1 if fails > 0 else 0)
