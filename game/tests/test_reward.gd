## Stunden man får något: att kistan och facklan VERKLIGEN ger en stund, och att stunden har en
## början, en topp och ett slut. Provet mäter `stil()` — samma siffror som `_draw` ritar ur — så
## "kortet vänds in med en glöd" är en mätning och inte ett påstående om en bild.
##
## Tre saker prövas, och alla tre kan falla:
##   1. vändningen: baksidan först, kanten mot betraktaren i början, framsidan till sist,
##   2. toppen: glöden och blixten når en högsta nivå (en stund utan topp är ingen stund),
##   3. kopplingen: texten kommer ur körningens EGEN händelse (samma siffra som guldet i banken).
##   godot --headless --script res://tests/test_reward.gd
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

func _init() -> void:
	print("— stunden: kortet vänds in med en glöd —")
	var fx := RewardFx.new()
	check(not fx.aktiv(), "ingenting visas innan något hänt")
	check(fx.fas() == "klar", "och fasen är klar", fx.fas())
	fx.visa("KISTA", "+25 guld")
	check(fx.aktiv(), "kistan startar en stund")
	check(fx.fas() == "vänds", "och den börjar med vändningen", fx.fas())
	check(fx.titel() == "KISTA" and fx.text() == "+25 guld", "rubriken och bytet följer med",
		"%s / %s" % [fx.titel(), fx.text()])
	var start := fx.stil()
	check(str(start["sida"]) == "baksida", "kortet kommer in med baksidan först", str(start["sida"]))
	check(float(start["bredd"]) < 0.25, "och kanten mot betraktaren (en vändning, inte en panel)",
		"%.2f" % float(start["bredd"]))
	check(float(start["bredd"]) > 0.0, "men aldrig noll bred (då försvinner den)")

	# Hela stunden, bildruta för bildruta (samma steg som _process tar).
	var dt := 1.0 / 60.0
	var max_bredd := 0.0
	var max_glöd := 0.0
	var max_blixt := 0.0
	var max_alfa := 0.0
	var min_bredd := 1.0
	var framsida := false
	var faser := {}
	var varv := 0
	while fx.aktiv() and varv < 1000:
		varv += 1
		var s := fx.stil()
		faser[fx.fas()] = true
		max_bredd = maxf(max_bredd, float(s["bredd"]))
		min_bredd = minf(min_bredd, float(s["bredd"]))
		max_glöd = maxf(max_glöd, float(s["glöd"]))
		max_blixt = maxf(max_blixt, float(s["blixt"]))
		max_alfa = maxf(max_alfa, float(s["alfa"]))
		if str(s["sida"]) == "framsida":
			framsida = true
		fx.stega(dt)
	check(framsida, "framsidan kommer in under stunden")
	check(max_bredd <= 1.001, "kortet blir aldrig bredare än sig självt (ingen förvridning)",
		"%.2f" % max_bredd)
	check(max_bredd > 0.95, "och når full bredd", "%.2f" % max_bredd)
	check(min_bredd < 0.25, "efter att ha varit kant in", "%.2f" % min_bredd)
	check(max_glöd > 0.9, "glöden når sin topp", "%.2f" % max_glöd)
	check(max_blixt > 0.2, "och en blixt syns när framsidan landar", "%.2f" % max_blixt)
	check(max_alfa > 0.99, "kortet står helt framme en stund", "%.2f" % max_alfa)
	check(faser.size() >= 4, "stunden har alla sina faser", str(faser.keys()))
	check(faser.has("vänds") and faser.has("utbrott") and faser.has("håll") and faser.has("tonar"),
		"vänds → utbrott → håll → tonar")
	check(varv < 1000, "och den tar slut av sig själv", "%d bildrutor, %.2f s" % [varv, varv * dt])
	check(not fx.aktiv() and fx.fas() == "klar", "efteråt är lagret avstängt")
	check(float(fx.stil()["alfa"]) == 0.0, "och allt har bleknat ut (inget ligger kvar över vyn)")

	print("")
	print("— bytet kommer ur körningens egen händelse —")
	check(RewardFx.från_event({}).is_empty(), "en okänd händelse ger ingen stund")
	check(RewardFx.från_event({"type": "combat_end"}).is_empty(), "och en strid är inte ett byte")
	# En kista som ger noll (man stod på full hälsa och kistan gav läkning) ska inte fira något.
	check(RewardFx.från_event({"type": "chest", "vad": "läkning", "hp": 0}).is_empty(),
		"en belöning på noll ger ingen stund")
	check(not RewardFx.från_event({"type": "chest", "vad": "guld", "gold": 5}).is_empty(),
		"men fem guld gör det")
	var db := Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var deck := Cards.make_pile(db, ["lash", "lash", "dagger", "dagger", "axe", "axe"])
	var run := Run.new(stages["stage_01"], bestiary, deck, 4242, db)
	var kista = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == "chest":
			kista = n
			break
	check(kista != null, "våningen har en kista")
	if kista != null:
		# Skadad spelare: kistan ger antingen guld eller läkning, och en läkning på en full spelare
		# är noll — provet skulle då mäta "ingen stund" utan att ha prövat stunden.
		run.hp = run.max_hp * 0.5
		var varv2 := 0
		while run.explore.pos != kista.pos and varv2 < 400:
			varv2 += 1
			if run.explore.step_toward(kista.pos) != "":
				break
		var guld_före := run.gold
		run.enter_node(kista)
		var e := {}
		for h in run.events:
			if str(h.get("type", "")) == "chest":
				e = h
		check(not e.is_empty(), "kistan lämnade en händelse i strömmen")
		var r := RewardFx.från_event(e)
		check(not r.is_empty(), "händelsen blir en stund")
		check(str(r["titel"]) == "KISTA", "med rubriken ur händelsen", str(r.get("titel", "")))
		if str(e.get("vad", "")) == "guld":
			var vunnet := int(e.get("gold", 0))
			check(run.gold == guld_före + vunnet, "guldet i stunden är samma guld som i banken",
				"%d + %d = %d" % [guld_före, vunnet, run.gold])
			check(str(r["text"]).contains(str(vunnet)) and str(r["text"]).contains("guld"),
				"och texten visar samma siffra", str(r["text"]))
			check(str(r["ikon"]) == "guld", "med myntet som ikon", str(r["ikon"]))
		else:
			var läkt := int(e.get("hp", 0))
			check(str(r["text"]).contains(str(läkt)), "läkningen i stunden är stridens siffra", str(r["text"]))
			check(str(r["ikon"]) == "läkning", "med hjärtat som ikon", str(r["ikon"]))
	# Facklan ger också en stund — en belöning mindre än kistan, men samma väg in.
	var vila := RewardFx.från_event({"type": "torch", "vad": "vila", "hp": 9})
	check(not vila.is_empty() and str(vila["text"]).contains("9"), "facklan ger sin stund", str(vila))

	print("")
	print("— played cards: visual receipt for mana, hp or gold —")
	# 1. Event translation: cards that change mana, hp, or gold produce receipts with exact amounts and variants.
	var ev_mana := {"type": "card", "card": "ash_tome", "mana": 1, "hp": 0, "gold": 0}
	var r_mana := RewardFx.från_event(ev_mana)
	check(not r_mana.is_empty(), "mana card event produces a receipt")
	check(str(r_mana["ikon"]) == "mana", "mana card carries the mana variant", str(r_mana.get("ikon", "")))
	check(r_mana["färg"] == Color(0.72, 0.78, 0.94), "mana card carries mana blue colour", str(r_mana.get("färg", "")))
	check(str(r_mana["text"]).contains("1") and str(r_mana["text"]).contains("mana"),
		"mana receipt text contains exact amount", str(r_mana.get("text", "")))

	var ev_hp := {"type": "card", "card": "salve", "mana": 0, "hp": 4, "gold": 0}
	var r_hp := RewardFx.från_event(ev_hp)
	check(not r_hp.is_empty(), "heal card event produces a receipt")
	check(str(r_hp["ikon"]) == "läkning", "heal card carries the heal variant", str(r_hp.get("ikon", "")))
	check(r_hp["färg"] == Color(0.82, 0.32, 0.30), "heal card carries heal red colour", str(r_hp.get("färg", "")))
	check(str(r_hp["text"]).contains("4") and str(r_hp["text"]).contains("hp"),
		"heal receipt text contains exact amount", str(r_hp.get("text", "")))

	var ev_gold := {"type": "card", "card": "dagger", "mana": 0, "hp": 0, "gold": 5}
	var r_gold := RewardFx.från_event(ev_gold)
	check(not r_gold.is_empty(), "gold card event produces a receipt")
	check(str(r_gold["ikon"]) == "guld", "gold card carries the gold variant", str(r_gold.get("ikon", "")))
	check(r_gold["färg"] == Color(0.94, 0.84, 0.48), "gold card carries gold yellow colour", str(r_gold.get("färg", "")))
	check(str(r_gold["text"]).contains("5") and str(r_gold["text"]).contains("guld"),
		"gold receipt text contains exact amount", str(r_gold.get("text", "")))

	var ev_dmg := {"type": "card", "card": "lash", "mana": 0, "hp": 0, "gold": 0}
	check(RewardFx.från_event(ev_dmg).is_empty(), "damage-only card produces no receipt")

	var ev_zero := {"type": "card", "card": "axe", "mana": -1, "hp": 0, "gold": 0}
	check(RewardFx.från_event(ev_zero).is_empty(), "negative mana cost delta produces no receipt")

	# 2. Combat integration: playing cards in combat produces the expected receipts.
	var c := Combat.new(999)
	c.hp = 30.0
	c.max_hp = 50.0
	c.mana = 5
	var foes := [Combat.Enemy.new("dummy", 100.0, 1.0, 0)]
	c.begin([], foes)
	c.hp = 30.0
	c.mana = 5

	# Card that only deals damage: exactly 0 receipts
	c.hand = [db["lash"]]
	var res_lash := c.play(0)
	check(res_lash.ok, "played damage card lash successfully")
	check(res_lash.damage > 0.0, "lash dealt damage", "%.1f" % res_lash.damage)
	check(res_lash.mana == 0 and res_lash.hp == 0 and res_lash.gold == 0,
		"lash changed neither mana, hp nor gold in effects")
	var receipt_lash := RewardFx.från_event({"type": "card", "card": res_lash.card_id,
		"mana": res_lash.mana, "hp": res_lash.hp, "gold": res_lash.gold})
	check(receipt_lash.is_empty(), "damage card produces exactly zero receipts")

	# Mana card (ash_tome): exactly 1 receipt with +1 mana and blue color
	c.hand = [db["ash_tome"]]
	var mana_before := c.mana
	var res_mana := c.play(0)
	check(res_mana.ok, "played mana card ash_tome successfully")
	check(res_mana.mana == 1, "ash_tome gained 1 mana", "%d" % res_mana.mana)
	check(c.mana == mana_before + 1, "combat mana state updated accordingly")
	var receipt_mana := RewardFx.från_event({"type": "card", "card": res_mana.card_id,
		"mana": res_mana.mana, "hp": res_mana.hp, "gold": res_mana.gold})
	check(not receipt_mana.is_empty(), "played mana card produces a receipt")
	check(str(receipt_mana["ikon"]) == "mana",
		"mana card produces exactly one receipt with mana variant")
	check(receipt_mana["färg"] == Color(0.72, 0.78, 0.94),
		"mana card receipt carries mana blue color")
	check(str(receipt_mana["text"]).contains("1") and str(receipt_mana["text"]).contains("mana"),
		"mana receipt carries exact amount (+1 mana)", str(receipt_mana["text"]))

	# Heal card (salve): exactly 1 receipt with +4 hp and red color
	c.hand = [db["salve"]]
	var hp_before := c.hp
	var res_salve := c.play(0)
	check(res_salve.ok, "played heal card salve successfully")
	check(res_salve.hp == 4, "salve restored 4 hp", "%d" % res_salve.hp)
	check(c.hp == hp_before + 4.0, "combat hp state updated accordingly")
	var receipt_heal := RewardFx.från_event({"type": "card", "card": res_salve.card_id,
		"mana": res_salve.mana, "hp": res_salve.hp, "gold": res_salve.gold})
	check(not receipt_heal.is_empty(), "played heal card produces a receipt")
	check(str(receipt_heal["ikon"]) == "läkning",
		"heal card produces exactly one receipt with heal variant")
	check(receipt_heal["färg"] == Color(0.82, 0.32, 0.30),
		"heal card receipt carries heal red color")
	check(str(receipt_heal["text"]).contains("4") and str(receipt_heal["text"]).contains("hp"),
		"heal receipt carries exact amount (+4 hp)", str(receipt_heal["text"]))

	# Gold from card with gem: exactly 1 receipt with +10 gold and gold color
	c.gem_bonus = {"dagger": {"gold": 10}}
	c.hand = [db["dagger"]]
	var res_dagger := c.play(0)
	check(res_dagger.ok, "played dagger with greed gem successfully")
	check(res_dagger.gold == 10, "greed gem on card yielded 10 gold", "%d" % res_dagger.gold)
	var receipt_gold := RewardFx.från_event({"type": "card", "card": res_dagger.card_id,
		"mana": res_dagger.mana, "hp": res_dagger.hp, "gold": res_dagger.gold})
	check(not receipt_gold.is_empty(), "played gold card produces a receipt")
	check(str(receipt_gold["ikon"]) == "guld",
		"gold card produces exactly one receipt with gold variant")
	check(receipt_gold["färg"] == Color(0.94, 0.84, 0.48),
		"gold card receipt carries gold yellow color")
	check(str(receipt_gold["text"]).contains("10") and str(receipt_gold["text"]).contains("guld"),
		"gold receipt carries exact amount (+10 guld)", str(receipt_gold["text"]))

	# Visual receipt execution: card receipt steps through all animation phases
	var fx_card := RewardFx.new()
	fx_card.visa(str(receipt_mana["titel"]), str(receipt_mana["text"]),
		str(receipt_mana["ikon"]), receipt_mana["färg"])
	check(fx_card.aktiv(), "mana card receipt launches the FX animation")
	check(fx_card.fas() == "vänds", "receipt starts with flipping card phase")
	var fx_ticks := 0
	while fx_card.aktiv() and fx_ticks < 1000:
		fx_ticks += 1
		fx_card.stega(1.0 / 60.0)
	check(not fx_card.aktiv() and fx_card.fas() == "klar",
		"mana card receipt animation completes and shuts off")
	fx_card.free()

	fx.free()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
