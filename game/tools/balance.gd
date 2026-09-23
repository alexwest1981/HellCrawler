## Balansmätaren: spelar ett gäng körningar med STANDARDspelaren (inga hack) och skriver ut
## hur långt den kommer. Det är instrumentet som avgör om rattarna i run.gd är rimliga, i
## stället för att någon gissar.
##
##   godot --headless --path . --script res://tools/balance.gd -- [antal seeds] [stage] [rang] [evo]
##
## `evo` = 1: standardspelaren tar en uppgradering när kortvalet erbjuder en (annars den första
## kortplatsen). Det är ratten som mäter vad EVOLUTIONERNA ger: samma körningar, samma seed, samma
## lek — skillnaden är om bytet två-kort-blir-ett används.
##
## Exit 1 om målet inte nås: på svårighet 1 ska de flesta körningarna nå våning 2, och några
## ska nå sista våningen. Rattarna är fortfarande PLATSHÅLLARE mot referensens siffror (som är
## okända) — målet är formen på kurvan, inte talen.
extends SceneTree

const RUNS_PER_STAGE := 20

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := RUNS_PER_STAGE
	var only := ""
	var rank := 0
	var evo := 0
	if args.size() >= 1:
		runs = int(args[0])
	if args.size() >= 2:
		only = args[1]
	if args.size() >= 3:
		rank = int(args[2])            # samma rang på alla uppgraderingar: 0 = standardspelaren
	if args.size() >= 4:
		evo = int(args[3])             # 1 = spelaren gör uppgraderingarna sina recept erbjuder
	print("läge: %d körningar per bana, rank %d, uppgraderingar %s" % [
		runs, rank, "PÅ" if evo > 0 else "av"])

	# Metan mäts som en egen variabel, inte som en ändrad standard: rattarna i run.gd ska vara
	# orörda, och skillnaden ska gå att läsa ur samma körning.
	var meta: Meta = null
	if rank > 0:
		meta = Meta.load_or_new("user://balance_meta.json")
		meta.gold = 999999
		for d in meta.defs:
			var id := str(d.get("id", ""))
			var maks := int(d.get("max_rank", 0))
			meta.ranks[id] = mini(rank, maks)
		print("meta: rang %d på alla uppgraderingar (must %+.0f %%, mana %+d, hand %+d, rustning %+d, max-HP %+.0f, förbannelse %+.0f %%)" % [
			rank, 100.0 * meta.stat("might"), int(meta.stat("mana")), int(meta.stat("hand")),
			int(meta.stat("armor")), meta.stat("max_hp"), 100.0 * meta.stat("curse")])

	var db := Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var deck := Cards.make_pile(db, [
		"lash", "lash", "lash", "lash", "dagger", "dagger", "dagger", "dagger",
		"axe", "axe", "axe", "axe", "bell", "bell", "ember_tome", "ember_tome", "deep_tome",
		"wild_mana", "wild_mana", "vial",
	])

	var ids := stages.keys()
	ids.sort()
	# Vilka banor som delar MEKANISKT avtryck. Utan det här stod tre identiska rader i tabellen utan
	# förklaring (mätt: stage_10, stage_11 och stage_12 gav samma siffror in i sista decimal), och det
	# såg ut som en trasig väljare. Det är det inte: filerna är samma bana.
	var grupper := {}
	for id in ids:
		var s: Stages.StageDef = stages[id]
		if s.difficulty > 3:
			continue
		var a := _avtryck(s)
		if not grupper.has(a):
			grupper[a] = []
		grupper[a].append(id)
	var problems := 0
	for stage_id in ids:
		if only != "" and stage_id != only:
			continue
		var stage: Stages.StageDef = stages[stage_id]
		if stage.difficulty > 3:
			continue                      # svårighet 4+ är NG+ och ska vara hård
		var floors_reached := []
		var levels := []
		var skador := []
		var deaths := 0
		var finished := 0
		var uppgraderingar := 0
		for i in runs:
			# FÄRSK lek per körning. `deck` delades förut av alla 20 körningarna, och `Run.pick_card`
			# lägger till i samma lista — mätt: körning 1 startade med 20 kort, körning 8 med 34.
			# Mätaren mätte alltså 20 olika lekar och blev starkare ju längre den körde, medan
			# standardspelaren börjar varje körning från samma startlek (main.gd bygger en färsk hög
			# per körning). Siffrorna i PLAN.md före M28 är lästa med den gamla mätaren.
			var run := Run.new(stage, bestiary, deck.duplicate(), 1000 + i, db, meta)
			# Körningen drivs steg för steg i stället för med `play_out()`, så kortvalen besvaras
			# MEDAN körningen pågår — som spelaren gör. Med `play_out()` svarades valen efteråt,
			# alltså hade leken i mätningen alltid varit startleken (och ingen uppgradering kunde
			# påverka något: mätt var siffrorna identiska med och utan dem, 5/20 mot 5/20).
			var skydd := 0
			while not run.finished and skydd < 5000:
				skydd += 1
				run.advance()
				# Kortvalen besvaras som en spelare hade gjort: uppgraderingen om den erbjuds och
				# `evo` är på, annars första kortplatsen — läget FÖRE uppgraderingarna.
				while not run.drafts.is_empty():
					var val: Array = run.pending_draft()
					var taget := ""
					if evo > 0:
						for id in val:
							if db[id].keywords.has(Evolution.KEYWORD):
								taget = str(id)
								break
					if taget.is_empty() or not run.pick_card(taget):
						run.pick_card(val[0])
					else:
						uppgraderingar += 1
			floors_reached.append(run.floor_index + 1)
			levels.append(run.level)
			skador.append(run.total_damage)
			if run.outcome == "dead":
				deaths += 1
			else:
				finished += 1
		floors_reached.sort()
		levels.sort()
		skador.sort()
		var median_floor: int = floors_reached[floors_reached.size() / 2]
		var reached_second := 0
		var reached_last := 0
		for f in floors_reached:
			if f >= 2:
				reached_second += 1
			if f >= stage.floors:
				reached_last += 1
		var syskon: Array = (grupper.get(_avtryck(stage), []) as Array).duplicate()
		syskon.erase(stage_id)
		var klon := "" if syskon.is_empty() else " · SAMMA BANA SOM %s" % ", ".join(syskon)
		print("%s (svårighet %d, %d våningar): median våning %d · nådde våning 2 i %d/%d · klarade banan %d/%d · median nivå %d · döda %d · uppgraderingar %d · median skada %.0f%s" % [
			stage_id, stage.difficulty, stage.floors, median_floor, reached_second, runs,
			reached_last, runs, levels[levels.size() / 2], deaths, uppgraderingar,
			skador[skador.size() / 2], klon])
		if stage.difficulty == 1 and reached_second < runs * 3 / 4:
			print("  → FÖR HÅRT: färre än tre av fyra når våning 2 på svårighet 1")
			problems += 1
		if stage.difficulty == 1 and reached_last == 0:
			print("  → FÖR HÅRT: ingen körning klarar ens den lättaste banan")
			problems += 1
	print("")
	print("%d problem" % problems)
	quit(1 if problems > 0 else 0)


## Banans MEKANISKA fingeravtryck: de fält som styr en körning. Två banor med samma avtryck ger
## identiska rader i tabellen ända ned i sista decimal — för de är samma bana i två filer (mätt i
## M30: stage_09–12 är fyra filer med samma rattar, och mätaren kör samma 20 seeds på varje bana, så
## likheten är inte ett sammanträffande utan data). Temat ingår INTE: det ritar våningen men rör inte
## en enda siffra, och två banor som bara skiljer sig i tema ska få samma rad — det är sant och ska
## stå kvar.
func _avtryck(s: Stages.StageDef) -> String:
	return "%dv %de tiers%s boss %s slut %s guld %.2f xp %.2f" % [
		s.floors, s.encounters_per_floor, str(s.tiers), s.boss, s.final_boss, s.gold_bonus, s.xp_bonus]
