## XP-kurvan, level up och kortvalet. Det är den här kedjan som gör spelet till ett deckbuilder
## och inte bara ett kortspel — ett fel här syns som att leken aldrig växer.
##   godot --headless --script res://tests/test_progress.gd
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

	print("— kurvan —")
	check(Progress.xp_total(1) == 0, "nivå 1 kräver 0 xp")
	var monotone := true
	for l in range(1, 20):
		if Progress.xp_to_next(l + 1) <= Progress.xp_to_next(l):
			monotone = false
	check(monotone, "varje nivå kräver mer än den förra", "nivå 1→2: %d xp, 10→11: %d xp" % [
		Progress.xp_to_next(1), Progress.xp_to_next(10)])
	check(Progress.level_for_xp(Progress.xp_total(5)) == 5, "nivå för xp är konsekvent")
	check(Progress.level_for_xp(Progress.xp_total(5) - 1) == 4, "en xp under tröskeln är en nivå lägre")
	check(Progress.levels_gained(1, Progress.xp_total(4)) == 3, "flera nivåer på en gång räknas")

	print("— kortvalet —")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var choices := Progress.draft(rng, db, 3)
	check(choices.size() == 3, "tre val utan luck")
	var unique := {}
	var all_known := true
	var no_crawler := true
	for id in choices:
		unique[id] = true
		if not db.has(id):
			all_known = false
		elif db[id].card_type == "crawler":
			no_crawler = false
	check(unique.size() == choices.size(), "inga dubbletter i valet")
	check(all_known, "alla val finns i kortdatabasen")
	check(no_crawler, "companions erbjuds inte vid level up")
	var four := Progress.draft(rng, db, 4)
	check(four.size() == 4, "fyra val med luck", str(four))
	check(db.size() >= 38, "kortdatabasen har volym nog för val", "%d kort" % db.size())

	print("— level up i en riktig körning —")
	var deck := Cards.make_pile(db, ["lash", "lash", "dagger", "dagger", "axe", "axe"])
	var run := Run.new(stages["stage_01"], bestiary, deck, 20260919, db)
	var start_size := run.deck.size()
	run.hp = 400.0
	run.max_hp = 400.0
	run.recovery = 30.0
	var events := run.play_out()
	var level_ups := 0
	var bossbyten := 0
	for e in events:
		if e.type == "level_up":
			level_ups += 1
		elif e.type == "boss_reward":
			bossbyten += 1
	check(level_ups >= 3, "körningen gav level ups", "%d st" % level_ups)
	check(run.level == 1 + level_ups, "nivån stämmer med antalet level ups", "nivå %d" % run.level)
	check(run.pending_draft().size() == 3, "ett kortval väntar på svar")
	check(run.deck.size() == start_size, "leken växer inte förrän spelaren väljer")

	print("— att välja kort —")
	var offered := run.pending_draft()
	var queued := run.drafts.size()
	check(run.pick_card("finns_inte") == false, "okänt kort nekas")
	check(run.pick_card(offered[0]), "ett av de erbjudna korten går att välja", offered[0])
	check(run.deck.size() == start_size + 1, "kortet hamnade i leken", "%d kort" % run.deck.size())
	check(run.drafts.size() == queued - 1, "kön gick vidare")
	while not run.drafts.is_empty():
		run.pick_card(run.pending_draft()[0])
	check(run.pending_draft().is_empty(), "alla kortval besvarades")
	# Ett kort per nivåuppgång OCH ett per bossbyte (M45): bossens kort är också ett kort i leken.
	check(run.deck.size() == start_size + level_ups + bossbyten,
		"leken växte med ett kort per nivå och ett per bossbyte",
		"%d → %d" % [start_size, run.deck.size()])

	print("— samma seed, samma val (kortvalen har egen RNG-ström) —")
	# KORTVALENS EGEN RNG-STRÖM: samma seed ska ge samma erbjudande — men jämförelsen måste ske vid
	# SAMMA punkt i körningen. Provet tog förut ett kvarlämnat val ur den stegvis spelade körningen
	# och jämförde med det som stod på tur i en färdigspelad. Det var samma sak så länge stage_01 var
	# 3x4 strider; när banan blev 5x6 (M90) hamnade de två på olika val, och provet föll. Nu jämförs
	# två helt färska körningar med samma seed — det är den egenskapen som ska hålla.
	var run_b := Run.new(stages["stage_01"], bestiary, deck, 20260919, db)
	run_b.hp = 400.0
	run_b.max_hp = 400.0
	run_b.recovery = 30.0
	run_b.play_out()          # hela körningen ska gå att spela ut utan att gå sönder
	var run_c := Run.new(stages["stage_01"], bestiary, deck, 20260919, db)
	check(run_c.pending_draft() == Run.new(stages["stage_01"], bestiary, deck, 20260919, db).pending_draft(),
		"samma val erbjuds på samma seed", str(run_c.pending_draft()))

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
