## Körbart självtest av spelets regler. Ingen motor, ingen grafik:
##   godot --headless --script res://tests/test_rules.gd
## Exit 0 = grönt, 1 = fel. Varje kontroll skriver vad den mätte, så en trasig regel syns
## som en siffra och inte som ett rött kryss.
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
	print("— skadeformeln mot referensens eget exempel —")
	# Wiki: Knife 40, Combo 25, Amount 50, Might 1000 %, Area 1000 %, två Triple Damage = 427 680
	var w := Rules.damage(40.0, 25, 8.0, 50.0, 10.0, 10.0, [3.0, 3.0])
	check(is_equal_approx(w, 427680.0), "wikins exempel ger 427 680", "fick %.0f" % w)
	check(Rules.damage(40.0, 0, 0.0, 0.0, 0.0, 0.0) == 40.0, "combo 0 = x1")
	check(Rules.damage(40.0, 3, 0.0, 0.0, 0.0, 0.0) == 160.0, "combo 3 = x4 (linjärt, inte x120)")

	print("— kedjan i strid —")
	var db := Cards.load_all()
	check(db.size() >= 14, "kortdatabasen laddar", "%d kort" % db.size())
	var c := Combat.new(1234)
	c.begin([], [combat_enemy(1000.0, 5.0)])
	c.mana = 20
	# 0-kostnad → 1-kostnad → 2-kostnad
	c.hand = [db["lash"], db["dagger"], db["axe"]]
	var r0 := c.play(0)
	check(r0.multiplier == 1, "första kortet spelar på x1", "x%d" % r0.multiplier)
	var r1 := c.play(0)
	check(r1.multiplier == 2, "andra kortet i stigande ordning ger x2", "x%d" % r1.multiplier)
	var r2 := c.play(0)
	check(r2.multiplier == 3, "tredje kortet ger x3", "x%d" % r2.multiplier)
	check(is_equal_approx(r2.damage, db["axe"].effects[0]["damage"] * 3.0), "tredje kortets skada är exakt x3", "%.0f skada" % r2.damage)
	check(c.mana == 17, "manan drogs korrekt (0+1+2)", "mana %d" % c.mana)

	print("— samma kostnad två gånger bryter kedjan —")
	var c2 := Combat.new(1)
	c2.begin([], [combat_enemy(1000.0, 5.0)])
	c2.mana = 20
	c2.hand = [db["lash"], db["dagger"], db["axe"], db["axe"]]
	c2.play(0); c2.play(0); c2.play(0)
	var broke := c2.play(0)
	check(broke.broke_chain, "fjärde kortet (2 efter 2) markerar kedjebrott")
	check(broke.multiplier == 1, "och resolverar på x1", "x%d" % broke.multiplier)

	print("— wild är en bro —")
	var c3 := Combat.new(1)
	c3.begin([], [combat_enemy(1000.0, 5.0)])
	c3.hand = [db["lash"], db["wild_mana"], db["axe"]]
	c3.play(0)
	var wild := c3.play(0)
	check(wild.multiplier == 2, "wild resolverar på aktuell combo", "x%d" % wild.multiplier)
	var after_wild := c3.play(0)
	check(after_wild.multiplier == 2, "kortet efter wild fortsätter kedjan utan att höja", "x%d" % after_wild.multiplier)

	print("— mana är en grind, inte ett förslag —")
	var c4 := Combat.new(1)
	c4.begin([], [combat_enemy(1000.0, 5.0)])
	c4.hand = [db["emberstorm"]]
	var blocked := c4.play(0)
	check(not blocked.ok and blocked.reason == "for_lite_mana", "3-kostnadskort nekas vid 2 mana", blocked.reason)
	check(c4.hand.size() == 1, "och kortet ligger kvar på handen")

	print("— fienden svarar, armor tar smällen först —")
	var c5 := Combat.new(1)
	c5.begin([], [combat_enemy(50.0, 7.0)])
	c5.armor = 3.0
	c5.hp = 50.0
	c5.enemy_turn()
	check(c5.armor == 0.0, "armor absorberar 3", "armor %.0f" % c5.armor)
	check(c5.hp == 46.0, "HP tar resten (7-3)", "hp %.0f" % c5.hp)

	print("— bossens sex ögon —")
	var c6 := Combat.new(1)
	c6.begin([], [combat_enemy(5000.0, 20.0, 0, 6)])
	c6.hand = [db["ash_tome"], db["ash_tome"], db["ash_tome"], db["ash_tome"], db["ash_tome"], db["ash_tome"], db["ash_tome"]]
	for i in 3:
		c6.play(0)
	c6.enemy_turn()
	check(c6.hp == c6.max_hp, "efter 3 spelade kort: bossen slår inte", "hp %.0f" % c6.hp)
	for i in 3:
		c6.play(0)
	c6.enemy_turn()
	check(c6.hp == c6.max_hp - 20.0, "efter 6 spelade kort: bossen slår", "hp %.0f" % c6.hp)

	print("— Destroy hamnar i exile, vanliga kort i discard —")
	var c7 := Combat.new(1)
	c7.begin([], [combat_enemy(1000.0, 5.0)])
	c7.hand = [db["vial"], db["lash"]]
	c7.play(0)
	c7.play(0)
	check(c7.exile_pile.size() == 1 and c7.exile_pile[0].id == "vial", "Destroy-kortet i exile")
	check(c7.discard_pile.size() == 1 and c7.discard_pile[0].id == "lash", "övriga i discard")

	print("— smart autospel (communityns #1-modd, inbyggd) —")
	var db2 := Cards.load_all()
	var jumbled := [db2["emberstorm"], db2["lash"], db2["dagger"], db2["axe"]]
	# naivt: spela handen i den ordning den ligger (så gör referensens Play All)
	var naive := Combat.new(7)
	naive.begin([], [combat_enemy(100000.0, 1.0)])
	naive.mana = 30
	naive.hand = jumbled.duplicate()
	var naive_damage := 0.0
	for i in 4:
		var nr := naive.play(0)
		naive_damage += nr.damage
	# smart: solvern
	var smart := Combat.new(7)
	smart.begin([], [combat_enemy(100000.0, 1.0)])
	smart.mana = 30
	smart.hand = jumbled.duplicate()
	var log := smart.auto_play()
	var smart_damage := 0.0
	var ascending := true
	var prev := -99
	var chain_broke := false
	for r in log:
		smart_damage += r.damage
		if r.broke_chain:
			chain_broke = true
		var card: Cards.Card = db2[r.card_id]
		if not card.is_wild() and card.cost <= prev:
			ascending = false
		if not card.is_wild():
			prev = card.cost
	check(log.size() == 4, "solvern spelade hela handen", "%d kort" % log.size())
	check(ascending, "i strikt stigande manakostnad", "ordning: %s" % _order(db2, log))
	check(not chain_broke, "och bröt aldrig kedjan")
	check(smart_damage > naive_damage, "mätt: solvern gör mer skada än naiv ordning",
		"%.0f mot %.0f" % [smart_damage, naive_damage])
	check(smart.mana >= 0, "manan går aldrig under noll", "%d" % smart.mana)

	var safe := Combat.new(7)
	safe.begin([], [combat_enemy(100000.0, 1.0)])
	safe.mana = 30
	safe.hand = [db2["vial"], db2["lash"]]
	var safe_log := safe.auto_play()
	var played_vial := false
	for r in safe_log:
		if r.card_id == "vial":
			played_vial = true
	check(not played_vial, "Destroy-kort spelas aldrig automatiskt", "spelade %d kort" % safe_log.size())

	print("— fiende-HP (saknas helt i referensen) —")
	var hp := Combat.new(7)
	hp.begin([], [combat_enemy(100.0, 1.0), combat_enemy(300.0, 1.0)])
	check(is_equal_approx(hp.total_enemy_hp(), 400.0), "total HP summeras", "%.0f" % hp.total_enemy_hp())
	hp.enemies[0].hp = 50.0
	check(is_equal_approx(hp.enemy_hp_percent(), 87.5), "procent räknas på kvarvarande fiender",
		"%.1f %%" % hp.enemy_hp_percent())

	_prov_nyckelord()
	_run_shared_fixtures()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _order(db: Dictionary, log: Array) -> String:
	var parts := []
	for r in log:
		var c: Cards.Card = db[r.card_id]
		parts.append("W" if c.is_wild() else str(c.cost))
	return ",".join(parts)

## De två nya nyckelorden: knuff (bakåt i raden) och frys (står över turer).
func _prov_nyckelord() -> void:
	print("— knuffen: den farliga främre raden tystas —")
	var c7 := Combat.new(1)
	var fram := combat_enemy(60.0, 9.0)          # farlig, står främst
	var bakom := combat_enemy(60.0, 3.0, 1)      # svag, står bakom
	c7.begin([], [fram, bakom])
	c7.hp = 100.0
	var knuff := Cards.Card.new()
	knuff.id = "prov_knuff"
	knuff.cost = 0
	knuff.effects = [{"op": "knockback", "amount": 2, "hits": 1}]
	c7.hand = [knuff]
	c7.play(0)
	check(fram.row == 2, "den främre knuffas bakom den andra", "rad %d" % fram.row)
	c7.enemy_turn()
	check(c7.hp == 97.0, "och den svaga bakom slår i stället för den farliga", "hp %.0f" % c7.hp)
	# Motprov: utan knuffen tar den farliga främre raden smällen över 9 i stället för 3.
	var c7b := Combat.new(1)
	c7b.begin([], [combat_enemy(60.0, 9.0), combat_enemy(60.0, 3.0, 1)])
	c7b.hp = 100.0
	c7b.enemy_turn()
	check(c7b.hp == 91.0, "utan knuff slår den främre (9 i stället för 3)", "hp %.0f" % c7b.hp)
	# En ensam fiende som knuffas bakåt har ingen framför sig och slår därför ändå: en knuff får
	# inte kunna låsa striden för alltid.
	var c7c := Combat.new(1)
	var ensam := combat_enemy(60.0, 9.0)
	c7c.begin([], [ensam])
	c7c.hp = 100.0
	c7c.hand = [knuff]
	c7c.play(0)
	c7c.enemy_turn()
	check(ensam.row == 2 and c7c.hp == 91.0, "en ensam fiende slår även knuffad", "hp %.0f" % c7c.hp)

	print("— frysningen: står still och tinar en tur i taget —")
	var c8 := Combat.new(1)
	c8.begin([], [combat_enemy(60.0, 8.0)])
	c8.hp = 100.0
	var frys := Cards.Card.new()
	frys.id = "prov_frys"
	frys.cost = 0
	frys.effects = [{"op": "freeze", "amount": 2, "hits": 1}]
	c8.hand = [frys]
	c8.play(0)
	c8.enemy_turn()
	check(c8.hp == 100.0, "tur 1: frusen, ingen skada", "hp %.0f" % c8.hp)
	c8.enemy_turn()
	check(c8.hp == 100.0, "tur 2: fortfarande frusen", "hp %.0f" % c8.hp)
	c8.enemy_turn()
	check(c8.hp == 92.0, "tur 3: tinad och slår", "hp %.0f" % c8.hp)
	c8.hand = [frys]
	c8.play(0)
	c8.hand = [frys]
	c8.play(0)
	check(c8.enemies[0].frozen == 2, "två frys-kort staplar inte till 4", "frusen %d turer" % c8.enemies[0].frozen)
	# Korttexten: en op utan text på kortet är osynlig för spelaren, även om regeln fungerar.
	var db := Cards.load_all()
	check(db["icicle"].describe().contains("frys 1 tur"), "frys-kortet skriver vad det gör",
		db["icicle"].describe())
	check(db["shove"].describe().contains("knuffa 1 rad"), "knuff-kortet skriver vad det gör",
		db["shove"].describe())

func combat_enemy(hp: float, dmg: float, row: int = 0, eyes: int = 0) -> Combat.Enemy:
	return Combat.Enemy.new("test_dummy", hp, dmg, row, eyes)

## The shared fixtures: the same file the Roblox port runs in Luau
## (~/Projects/hellcrawler_roblox/tests/fixtures/rules.luau, override with HELLCRAWLER_FIXTURES).
## The file is the truth, so a rule that drifts between the two implementations shows up as a
## number here instead of in a game. Missing file is skipped loudly, not silently.
const SHARED_FIXTURES := "Projects/hellcrawler_roblox/tests/fixtures/rules.luau"

func _run_shared_fixtures() -> void:
	var path := OS.get_environment("HELLCRAWLER_FIXTURES")
	if path.is_empty():
		path = OS.get_environment("HOME").path_join(SHARED_FIXTURES)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("— shared fixtures unread (Roblox clone missing?): %s —" % path)
		return
	print("— shared fixtures, the same cases the Luau port runs —")
	var read := 0
	for raw in file.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("--") or not line.contains("|"):
			continue
		var parts := line.split("|")
		if parts.size() < 4:
			check(false, "a fixture line without four fields", line)
			continue
		read += 1
		var fn_name := parts[1].strip_edges()
		var got: Variant
		if fn_name == "scenario":
			got = _run_scenario(parts[2])
		else:
			got = _shared_call(fn_name, _shared_args(parts[2]))
		var want: Variant = _shared_value(parts[3])
		var ok := _shared_equal(got, want)
		check(ok, parts[0].strip_edges(), "" if ok else "wanted %s, got %s" % [want, got])
	check(read >= 68, "the shared fixtures were read", "%d cases" % read)

## A fight is a state machine, so those cases are a step list instead of one call:
##   "seed 1; enemies troll:1000:5; mana 20; hand lash,dagger,axe; play 0; probe damage"
## The last step is always a probe, and its value is what the expected field is compared with.
func _run_scenario(steps: String) -> Variant:
	var state := {"seed": 1, "deck": [], "combat": null, "last": null, "deck_start": 0}
	var value: Variant = null
	for raw in steps.split(";"):
		var step := raw.strip_edges()
		if step.is_empty():
			continue
		var parts := step.split(" ", false, 1)
		var verb := parts[0]
		var rest := parts[1].strip_edges() if parts.size() > 1 else ""
		match verb:
			"seed":
				state.seed = int(rest)
			"deck":
				state.deck = _cards_from(rest)
			"enemies":
				var enemies := []
				for text in rest.split(","):
					var f := text.split(":")
					enemies.append(Combat.Enemy.new(f[0], float(f[1]), float(f[2]),
						int(f[3]) if f.size() > 3 else 0, int(f[4]) if f.size() > 4 else 0))
				state.combat = Combat.new(int(state.seed))
				state.combat.begin(state.deck, enemies)
				state.last = null
			"hand":
				state.combat.hand = _cards_from(rest)
			"play":
				state.last = state.combat.play(int(rest))
			"turn":
				state.combat.enemy_turn()
			"autoplay":
				state.autoplay = state.combat.auto_play()
			"evo":
				state.evo_ok = Evolution.consume(state.deck, Cards.load_all(), rest)
			"floor":
				var f2 := rest.split(":")
				state.floor = Dungeon.generate(Stages.load_all()[f2[0]], int(f2[1]) - 1, int(f2[2]), Enemies.load_all())
			"run":
				var f3 := rest.split(":")
				var stages := Stages.load_all()
				state.deck_start = state.deck.size()
				state.run = Run.new(stages[f3[0]], Enemies.load_all(), state.deck, int(f3[1]), Cards.load_all())
				state.run.play_out()
			"regel":
				state.combat.regel = rest
			"hp":
				state.combat.hp = float(rest)
			"maxhp":
				state.combat.max_hp = float(rest)
			"armor":
				state.combat.armor = float(rest)
			"mana":
				state.combat.mana = int(rest)
			"probe":
				value = _probe(rest, state)
			_:
				push_error("unknown step: %s" % step)
	return value

func _probe(name: String, state: Dictionary) -> Variant:
	var c = state.combat
	var last = state.last
	match name:
		"mana":
			return c.mana
		"hp":
			return c.hp
		"armor":
			return c.armor
		"combo":
			return c.combo
		"hand":
			return c.hand.size()
		"exile":
			return c.exile_pile.size()
		"discard":
			return c.discard_pile.size()
		"damage":
			return last.damage if last != null else 0.0
		"multiplier":
			return last.multiplier if last != null else 0
		"reason":
			return last.reason if last != null else ""
		"ok":
			return last.ok if last != null else false
		"broken":
			return last.broke_chain if last != null else false
		"paid_with_blood":
			return last.betalat_med_blod if last != null else false
		"frozen":
			return c.enemies[0].frozen
		"row":
			return c.enemies[0].row
		"over":
			return c.over()
		"available":
			return "+".join(Evolution.available(state.deck))
		"deck":
			return state.deck.size()
		"deck_ids":
			var ids := []
			for card in state.deck:
				ids.append(card.id)
			return "+".join(ids)
		"evo_ok":
			return state.evo_ok
		"autoplay_count":
			return state.autoplay.size()
		"autoplay_ascending":
			var db := Cards.load_all()
			var prev := -2
			var ok := true
			for r in state.autoplay:
				var card: Cards.Card = db[r.card_id]
				if not card.is_wild():
					if card.cost <= prev:
						ok = false
					prev = card.cost
			return ok
		"autoplay_broke":
			for r in state.autoplay:
				if r.broke_chain:
					return true
			return false
		"unreachable":
			return Dungeon.unreachable_nodes(state.floor).size()
		"has_boss":
			return not state.floor.nodes_of_kind("boss").is_empty()
		"has_shovel":
			return not state.floor.nodes_of_kind("shovel").is_empty()
		"start_is_floor":
			return state.floor.is_floor_at(state.floor.start)
		"floor_w":
			return state.floor.w
		"run_finished":
			return state.run.finished
		"run_outcome_known":
			return state.run.outcome in ["dead", "reaped", "cleared"]
		"run_end_count":
			var ends := 0
			for e in state.run.events:
				if str(e.get("type", "")) == "run_end":
					ends += 1
			return ends
		"run_deck_delta":
			var picked := 0
			for e in state.run.events:
				if str(e.get("type", "")) == "card_picked":
					picked += 1
			return state.run.deck.size() - int(state.deck_start) - picked
	push_error("unknown probe: %s" % name)
	return null

func _cards_from(ids: String) -> Array:
	var db := Cards.load_all()
	var out := []
	for id in ids.split(","):
		out.append(db[id.strip_edges()])
	return out

func _shared_call(fn_name: String, args: Array) -> Variant:
	match fn_name:
		"damage":
			return Rules.damage(args[0], int(args[1]), args[2], args[3], args[4], args[5],
				args[6] if args.size() > 6 else [])
		"damage_multiplier":
			return Rules.damage_multiplier(int(args[0]))
		"continues_chain":
			return Rules.continues_chain(int(args[0]), int(args[1]))
		"combo_after":
			return Rules.combo_after(int(args[0]), int(args[1]), int(args[2]))
		"xp_to_next":
			return Progress.xp_to_next(int(args[0]))
		"xp_total":
			return Progress.xp_total(int(args[0]))
		"level_for_xp":
			return Progress.level_for_xp(int(args[0]))
		"levels_gained":
			return Progress.levels_gained(int(args[0]), int(args[1]))
	return null

## Splits on commas at depth 0, so "[3,3]" stays in one piece — same rule as run.luau.
func _shared_args(text: String) -> Array:
	var args := []
	var depth := 0
	var current := ""
	for i in text.length():
		var ch := text[i]
		if ch == "[":
			depth += 1
		elif ch == "]":
			depth -= 1
		if ch == "," and depth == 0:
			args.append(_shared_value(current))
			current = ""
		else:
			current += ch
	if not current.strip_edges().is_empty():
		args.append(_shared_value(current))
	return args

func _shared_value(text: String) -> Variant:
	var s := text.strip_edges()
	if s == "true":
		return true
	if s == "false":
		return false
	if s.begins_with("["):
		var list := []
		for item in s.substr(1, s.length() - 2).split(","):
			if not item.strip_edges().is_empty():
				list.append(float(item))
		return list
	if s.is_valid_float():
		return float(s)
	return s ## a bare word ("for_lite_mana") is a value too, not a broken number

## Relative tolerance, because two languages will not agree bit for bit on floats.
func _shared_equal(got: Variant, want: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(got) in numbers and typeof(want) in numbers:
		return absf(float(got) - float(want)) <= 1e-6 * maxf(1.0, absf(float(want)))
	return got == want
