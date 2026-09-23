## Textklienten: spela spelet i terminalen, utan grafik. Samma motor som testerna kör
## (Dungeon/Explore/Combat/Run) — klienten är bara in- och utmatning.
##
##   godot --headless --path . --script res://tools/play_text.gd -- stage_01 42
##
## Tangenter: w framåt · a/d sväng vänster/höger · p auto (nästa steg mot målet)
##            m karta · f kör klart resten · q avsluta
## I strid:   1-9 spela kortet · p spela allt (solvern) · e avsluta turen · q ge upp
extends SceneTree

var run: Run
var db: Dictionary
var seen_events := 0

const DECK := [
	"lash", "lash", "lash", "lash",
	"dagger", "dagger", "dagger", "dagger",
	"axe", "axe", "axe", "axe",
	"bell", "bell", "ember_tome", "ember_tome", "deep_tome",
	"wild_mana", "wild_mana", "vial",
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var stage_id := "stage_01"
	var seed_value := 1
	if args.size() > 0:
		stage_id = str(args[0])
	if args.size() > 1:
		seed_value = int(args[1])

	db = Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	if not stages.has(stage_id):
		var ids := stages.keys()
		ids.sort()
		print("okänd bana: %s. Välj bland: %s" % [stage_id, ", ".join(ids)])
		quit(1)
		return

	var stage: Stages.StageDef = stages[stage_id]
	print("=== %s (%s) · svårighet %d · %d våningar · seed %d ===" % [stage.name, stage.id, stage.difficulty, stage.floors, seed_value])
	print("w framåt · a/d sväng · p auto · m karta · f kör klart · q avsluta")
	print("i strid: 1-9 kort · p spela allt · e avsluta turen · q ge upp")

	run = Run.new(stage, bestiary, Cards.make_pile(db, DECK), seed_value, db)
	run.fighter = Callable(self, "_fight_interactive")
	_flush_events()
	_draw()

	while not run.finished:
		var cmd := _ask("> ")
		match cmd:
			"w":
				var err := run.explore.forward()
				if err != "":
					print("(vägg)")
				elif not run.resolve_here():
					pass
			"a":
				run.explore.turn_left()
			"d":
				run.explore.turn_right()
			"p":
				run.advance()
			"f":
				while not run.finished:
					run.advance()
					_flush_events()
					_draft_if_any()
			"m":
				pass
			"q", "":
				print("avslutar")
				quit(0)
				return
			_:
				print("(w/a/d/p/m/f/q)")
		_flush_events()
		_draft_if_any()
		if not run.finished:
			_draw()

	print("")
	print("=== %s — %d våningar, %d strider vunna, %d förlorade, %d guld, %d xp, nivå %d, %d kort i leken, HP %.0f ===" % [
		run.outcome_text(), run.floor_index + 1, run.fights_won, run.fights_lost, run.gold, run.xp,
		run.level, run.deck.size(), run.hp])
	quit(0)

## Kortvalet vid level up. Kön kan hålla flera val om flera nivåer togs på en gång.
func _draft_if_any() -> void:
	while not run.pending_draft().is_empty():
		var choices := run.pending_draft()
		print("")
		print("--- NIVÅ %d — välj ett kort ---" % run.level)
		for i in choices.size():
			var c: Cards.Card = db[choices[i]]
			print("  %d) %s (%s)  %s" % [i + 1, c.name, "W" if c.is_wild() else str(c.cost), c.describe()])
		var index := int(_ask("val> ")) - 1
		if index < 0 or index >= choices.size():
			index = 0
			print("(ogiltigt val — tar %s)" % choices[0])
		run.pick_card(choices[index])
		print("  valde %s" % db[choices[index]].name)

# --- striden (interaktiv) ---------------------------------------------------
func _fight_interactive(combat: Combat) -> void:
	print("")
	print("--- STRID: %d fiende(r) ---" % combat.alive_enemies().size())
	while not combat.over():
		_draw_combat(combat)
		var cmd := _ask("kort> ")
		if cmd == "e":
			var log := combat.end_turn()
			for e in log:
				print("  du tar %.0f skada (armor svalde %.0f) → HP %.0f" % [e.damage, e.absorbed, e.hp])
			continue
		if cmd == "p":
			for r in combat.auto_play():
				print("  spelade %s på x%d (%.0f skada)" % [r.card_id, r.multiplier, r.damage])
			continue
		if cmd == "q":
			combat.hp = 0.0
			print("  du ger upp")
			break
		if cmd.is_valid_int() and int(cmd) >= 1 and int(cmd) <= combat.hand.size():
			var r := combat.play(int(cmd) - 1)
			if r.ok:
				print("  spelade %s på x%d (%.0f skada)%s" % [r.card_id, r.multiplier, r.damage, "  [kedjan bröts]" if r.broke_chain else ""])
			else:
				print("  kan inte: %s" % r.reason)
			continue
		print("  (1-9 · p spela allt · e avsluta turen · q ge upp)")
	print("--- striden är över, HP %.0f ---" % combat.hp)

func _draw_combat(combat: Combat) -> void:
	var foes := []
	for e in combat.alive_enemies():
		foes.append("%s %.0f/%.0f" % [e.name, e.hp, e.max_hp])
	print("  fiender: %s" % ", ".join(foes))
	print("  HP %s  armor %.0f  mana %d  kedja x%d" % [_bar(combat.hp, combat.max_hp), combat.armor, combat.mana, Rules.damage_multiplier(combat.combo)])
	for i in combat.hand.size():
		var c: Cards.Card = combat.hand[i]
		var cost := "W" if c.is_wild() else str(c.cost)
		print("    %d) [%s] %-12s %s" % [i + 1, cost, c.name, c.describe()])

# --- utforskarläget ---------------------------------------------------------
func _draw() -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	print("")
	print("våning %d/%d · %s · HP %s · %d guld · %d xp · %d steg" % [
		run.floor_index + 1, run.stage.floors, run.stage.name, _bar(run.hp, run.max_hp), run.gold, run.xp, run.explore.steps_taken])
	var lines := []
	for y in f.h:
		var line := ""
		for x in f.w:
			var p := Vector2i(x, y)
			if p == run.explore.pos:
				line += _facing_char()
			else:
				line += _tile_char(f, p)
		lines.append(line)
	print("\n".join(lines))

func _tile_char(f: Dungeon.Floor, p: Vector2i) -> String:
	for n in f.nodes:
		if n.pos == p and not n.cleared:
			match n.kind:
				"encounter":
					return "E"
				"chest":
					return "C"
				"torch":
					return "T"
				"boss":
					return "B"
				"shovel":
					return "S"
	return "." if f.is_floor_at(p) else "#"

func _facing_char() -> String:
	match run.explore.facing:
		Explore.NORTH:
			return "^"
		Explore.EAST:
			return ">"
		Explore.SOUTH:
			return "v"
		_:
			return "<"

func _bar(value: float, max_value: float) -> String:
	var pct := 0.0 if max_value <= 0.0 else value / max_value
	var filled := int(round(pct * 10.0))
	return "%.0f/%.0f [%s%s]" % [value, max_value, "#".repeat(max(0, filled)), "-".repeat(max(0, 10 - filled))]

func _flush_events() -> void:
	while seen_events < run.events.size():
		var e: Dictionary = run.events[seen_events]
		seen_events += 1
		match str(e.get("type", "")):
			"floor_enter":
				print("")
				print(">>> NER TILL VÅNING %d" % (int(e.floor) + 1))
			"combat_end":
				print("    %s mot %s: %s efter %d turer (HP %.0f)" % [
					"vinst" if e.won else "förlust", e.enemy, "%.0f skada" % e.damage, e.turns, e.player_hp])
			"shovel":
				print("    du tar shoveln")
			"run_end":
				print("")
				print(">>> KÖRNINGEN SLUT: %s (%d våningar, %d guld, %d xp)" % [e.outcome, e.floors, e.gold, e.xp])
			"stuck":
				print("    FAST: %s" % str(e))

func _ask(prompt: String) -> String:
	printraw(prompt)
	return OS.read_string_from_stdin().strip_edges()
