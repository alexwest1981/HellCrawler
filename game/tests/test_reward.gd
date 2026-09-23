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
	fx.free()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
