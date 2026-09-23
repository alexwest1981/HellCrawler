## Prövar UI-VÄGEN: exakt de anrop main.gd gör (enter_node → spela kort → leave_node → shovel).
## Autospelarens väg testas i test_run.gd; den här sviten fångar att knapptryckningarnas väg
## räknar rätt — att HP, guld, xp och våningsbyte hamnar rätt när spelaren äger speltiden.
##   godot --headless --script res://tests/test_ui_path.gd
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

func _initialize() -> void:
	var db := Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var deck := Cards.make_pile(db, ["lash", "lash", "dagger", "dagger", "axe", "axe", "ember_tome", "wild_mana"])
	var stage: Stages.StageDef = stages["stage_01"]
	var run := Run.new(stage, bestiary, deck, 4242, db)

	print("— gå till en nod och slåss genom UI-vägen —")
	var target := _nearest(run, "encounter")
	check(target != null, "våningen har en strid att gå till")
	if target == null:
		quit(1)
		return
	var guard := 0
	while run.explore.pos != target.pos and guard < 400:
		guard += 1
		if run.explore.step_toward(target.pos) != "":
			break
	check(run.explore.pos == target.pos, "spelaren gick fram till noden", "%d steg" % run.explore.steps_taken)

	var events_before := run.events.size()
	var combat := run.enter_node(target)
	check(combat != null, "enter_node gav en strid")
	check(target.cleared, "noden markerades avklarad")
	var start_hp := run.hp
	var turns := 0
	while not combat.over() and turns < 40:
		turns += 1
		combat.auto_play()
		if not combat.over():
			combat.end_turn()
	check(combat.over(), "striden tog slut", "%d turer" % turns)
	run.leave_node(target, combat)
	check(run.events.size() > events_before, "striden loggades i eventströmmen")
	if combat.hp > 0.0:
		check(run.gold > 0 and run.xp > 0, "guld och xp räknades in", "%d guld, %d xp" % [run.gold, run.xp])
		check(run.hp >= combat.hp, "recovery helade efter striden", "%.0f → %.0f" % [combat.hp, run.hp])
	else:
		check(run.hp <= 0.0, "döden fördes vidare till körningen")
	check(not _node_still_offered(run, target), "samma nod erbjuds inte igen")

	print("— shoveln tar oss ned —")
	var floor_before := run.floor_index
	var shovel := _nearest(run, "shovel")
	guard = 0
	while run.explore.pos != shovel.pos and guard < 600:
		guard += 1
		if run.explore.step_toward(shovel.pos) != "":
			break
	check(run.explore.pos == shovel.pos, "spelaren gick till shoveln")
	run.enter_node(shovel)
	check(run.floor_index == floor_before + 1, "nedstigningen bytte våning", "våning %d" % (run.floor_index + 1))
	check(run.explore.pos == run.explore.floor_ref.start, "nya våningen börjar på sin startruta")

	print("— bossen ger shoveln: samma ruta, två noder —")
	var boss := _nearest(run, "boss")
	check(boss != null, "våningen har en boss")
	guard = 0
	while run.explore.pos != boss.pos and guard < 800:
		guard += 1
		if run.explore.step_toward(boss.pos) != "":
			break
	check(run.explore.pos == boss.pos, "spelaren gick fram till bossen")
	check(run.explore.node_here().kind == "boss", "noden på rutan är bossen",
		"node_here: %s" % run.explore.node_here().kind)
	var boss_fight := run.enter_node(boss)
	check(boss_fight != null, "bossen gav en strid")
	while not boss_fight.over() and turns < 200:
		turns += 1
		boss_fight.auto_play()
		if not boss_fight.over():
			boss_fight.end_turn()
	run.leave_node(boss, boss_fight)
	if run.hp > 0.0:
		# Det här är buggen som lämnade körningen på våning 1 för alltid: shoveln ligger på
		# bossens ruta, och efter striden måste uppslaget hitta DEN, inte den avklarade bossen.
		var after: Dungeon.FloorNode = run.explore.node_here()
		check(after != null and after.kind == "shovel",
			"efter bossen ligger shoveln överst på rutan", "node_here: %s" % ("inget" if after == null else after.kind))
		if after != null and after.kind == "shovel":
			var floor_before_boss := run.floor_index
			run.enter_node(after)
			check(run.floor_index == floor_before_boss + 1, "shoveln tog oss ned till nästa våning",
				"våning %d" % (run.floor_index + 1))
	else:
		check(true, "spelaren dog mot bossen (shoveln är inte relevant då)")

	print("")
	print("— kortet är ett kort, inte en textknapp —")
	var sample: Cards.Card = db["lash"]
	var v := CardView.make(sample, 3, null, false)
	check(v.index == 3, "kortet vet sin plats i handen", "index %d" % v.index)
	check(v.custom_minimum_size == CardView.HAND_SIZE, "kortet har kortstorlek",
		"%.0fx%.0f" % [v.custom_minimum_size.x, v.custom_minimum_size.y])
	check(v.cost_text() == str(sample.cost), "kostnaden står på kortet",
		"%s kostar %s" % [sample.name, v.cost_text()])
	var texts := []
	for n in v.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	for n in v.find_children("*", "RichTextLabel", true, false):
		texts.append((n as RichTextLabel).text)
	check(texts.has(sample.name), "namnet står på kortet", ", ".join(texts))
	# Innehållet får inte KRAVA mer plats än kortet har: en radbrytande Label rapporterar sin
	# minimihöjd för en pyttebred ruta och tvingade korten till 105–195 px i stället för 80.
	var need := v.get_combined_minimum_size()
	check(need.y <= CardView.HAND_SIZE.y and need.x <= CardView.HAND_SIZE.x,
		"kortets innehåll ryms i kortstorleken",
		"kräver %.0fx%.0f, kortet är %.0fx%.0f" % [need.x, need.y,
			CardView.HAND_SIZE.x, CardView.HAND_SIZE.y])
	check(v.tooltip_text.contains(sample.describe()), "hela effekten finns i verktygstipset")
	var wild := CardView.make(db["wild_mana"], 0, null, true)
	check(wild.cost_text() == "W", "wild-kortet visar W i stället för en siffra", wild.cost_text())
	check(wild.custom_minimum_size == CardView.BIG_SIZE, "kortvalet har större kort",
		"%.0fx%.0f" % [wild.custom_minimum_size.x, wild.custom_minimum_size.y])
	v.free()
	wild.free()

	print("")
	print("— förhandsvisningen stämmer med utfallet —")
	# Siffran spelaren ser vid hover måste vara den han får. Provet spelar korten på riktigt och
	# jämför varje fiendes HP-tapp med det preview() visade — per fiende, inte bara summan.
	var run2 := Run.new(stage, bestiary, deck, 777, db)
	var foe2 := _nearest(run2, "encounter")
	var c2 := run2.enter_node(foe2)
	check(c2 != null, "strid att förhandsvisa i")
	var visade := 0
	var fel := 0
	var varv := 0
	while c2 != null and not c2.over() and varv < 40:
		varv += 1
		var p := c2.preview(0)
		if not p.ok:
			c2.end_turn()
			continue
		var vant := {}
		for h in p.hits:
			vant[h.enemy] = float(h.damage)
		var fore := {}
		for e in c2.alive_enemies():
			fore[e] = e.hp
		var res := c2.play(0)
		visade += 1
		if int(res.multiplier) != int(p.multiplier):
			fel += 1
		for e in vant.keys():
			if absf(fore[e] - e.hp - float(vant[e])) > 0.001:
				fel += 1
		if c2.hand.is_empty():
			c2.end_turn()
	check(visade > 0 and fel == 0, "visad skada = utfall", "%d kort, %d fel" % [visade, fel])

	# Ett kort med TVÅ skadeeffekter mot samma fiende: den andra effekten ska kapas mot det HP som
	# är kvar (40 - 30 = 10), inte mot fiendens ursprungliga HP. Utan kapningen lovar
	# förhandsvisningen 60 skada på en fiende med 40 HP.
	var tva := Cards.Card.from_dict({
		"id": "test_tva", "name": "Test Två", "cost": 0, "type": "attack",
		"effects": [{"op": "damage", "damage": 30, "hits": 1}, {"op": "damage", "damage": 30, "hits": 1}]})
	var halv := Combat.Enemy.new("test_halv", 40.0, 3.0, 0, 0)
	var c3 := Combat.new(5)
	c3.begin([tva], [halv])
	var p3 := c3.preview(0)
	var fore: float = halv.hp
	var r3 := c3.play(0)
	check(absf(float(p3["damage"]) - (fore - halv.hp)) < 0.001,
		"två effekter mot samma fiende lovar inte mer än fienden har",
		"visade %.0f, gjorde %.0f" % [p3["damage"], fore - halv.hp])
	check(p3["hits"].size() == 1, "en rad per fiende, inte en per effekt",
		"%d rader" % p3["hits"].size())
	check(int(r3.multiplier) == int(p3["multiplier"]), "multiplikatorn stämmer")

	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _nearest(run: Run, kind: String) -> Dungeon.FloorNode:
	var best: Dungeon.FloorNode = null
	var best_d := 1 << 30
	for n in run.explore.floor_ref.nodes:
		if n.kind != kind or n.cleared:
			continue
		var d: int = abs(n.pos.x - run.explore.pos.x) + abs(n.pos.y - run.explore.pos.y)
		if d < best_d:
			best_d = d
			best = n
	return best

func _node_still_offered(run: Run, node: Dungeon.FloorNode) -> bool:
	var next := run._next_objective()
	return next != null and next.pos == node.pos
