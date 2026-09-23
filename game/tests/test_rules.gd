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
