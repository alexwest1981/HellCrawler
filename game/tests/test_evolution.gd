## Evolutionerna: recepten som data, och att två kort verkligen blir ett.
##
## Provet mäter hela kedjan, för varje led kan gå sönder tyst:
##   1. DATAT — varje recept pekar på kort som finns, inget kort är sin egen del, ingen kedja,
##      och varje kort som BÄR nyckelordet "Evolved" har ett recept (annars är märkningen en lögn).
##   2. KORTVALET — en uppgradering får aldrig dyka upp ur högen av sig själv, bara ur sitt recept.
##   3. BYTET — två delar ur leken, ett kort in (leken KRYMPER med ett), och ett halvt recept
##      genomförs aldrig (en del som redan tagits ger inget gratis kort).
##   4. I EN KÖRNING — uppgraderingen erbjuds vid level up när receptet ligger i leken, och samma
##      seed ger samma erbjudande.
##   godot --headless --script res://tests/test_evolution.gd
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

## Den råa anfallsstyrkan i kortets data (damage × hits) — samma mått för del och resultat, så
## jämförelsen inte beror på combo eller fiender. Det är SIFFRAN man byter upp sig i.
func _rå(card: Cards.Card) -> float:
	var sum := 0.0
	for e in card.effects:
		if str(e.get("op", "")) == "damage":
			sum += float(e.get("damage", 0.0)) * float(e.get("hits", 1))
	return sum

func _initialize() -> void:
	var db := Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()

	print("— recepten (data/evolutions.json) —")
	var recept := Evolution.recipes()
	check(recept.size() == 17, "sjutton recept", "%d" % recept.size())
	var okanda := []
	var sjalva := []
	var dubbel := []
	var kedja := []
	var sedda := {}
	for r in recept:
		var cid := str(r.get("card", ""))
		var delar: Array = r.get("parts", [])
		if delar.size() != 2:
			okanda.append("%s: %d delar" % [cid, delar.size()])
		if not db.has(cid):
			okanda.append(cid)
			continue
		if sedda.has(cid):
			dubbel.append(cid)
		sedda[cid] = true
		for d in delar:
			if not db.has(str(d)):
				okanda.append("%s → %s" % [cid, str(d)])
			if str(d) == cid:
				sjalva.append(cid)
			# En del får inte själv vara en uppgradering: två kort blir ett, inte tre blir ett.
			if db.has(str(d)) and db[str(d)].keywords.has(Evolution.KEYWORD):
				kedja.append("%s + %s" % [str(d), cid])
	check(okanda.is_empty(), "varje recept pekar på kort som finns", ", ".join(okanda))
	check(sjalva.is_empty(), "inget kort är sin egen del")
	check(dubbel.is_empty(), "inget kort har två recept", ", ".join(dubbel))
	check(kedja.is_empty(), "ingen del är själv en uppgradering", ", ".join(kedja))

	var utan_recept := []
	var utan_nyckelord := []
	for id in db:
		if db[id].keywords.has(Evolution.KEYWORD) and Evolution.for_card(id).is_empty():
			utan_recept.append(id)
	for r in recept:
		var cid := str(r.get("card", ""))
		if db.has(cid) and not db[cid].keywords.has(Evolution.KEYWORD):
			utan_nyckelord.append(cid)
	check(utan_recept.is_empty(), "varje kort märkt Evolved har ett recept", str(utan_recept))
	check(utan_nyckelord.is_empty(), "och varje resultat är märkt Evolved", str(utan_nyckelord))

	print("")
	print("— vad bytet ger: del mot resultat (rå anfallsstyrka, kostnad) —")
	var svagare := []
	var billigare := []
	for r in recept:
		var cid := str(r.get("card", ""))
		var delar: Array = r.get("parts", [])
		var först: Cards.Card = db.get(str(delar[0]))
		var sista: Cards.Card = db[cid]
		if _rå(sista) < _rå(först):
			svagare.append("%s %.0f < %s %.0f" % [cid, _rå(sista), str(delar[0]), _rå(först)])
		if sista.cost < först.cost:
			billigare.append("%s %d < %s %d" % [cid, sista.cost, str(delar[0]), först.cost])
		print("  %-16s %5.0f  (kostnad %d)   mot %-14s %5.0f  (kostnad %d)" % [
			cid, _rå(sista), sista.cost, str(delar[0]), _rå(först), först.cost])
	check(svagare.is_empty(), "uppgraderingen är aldrig svagare än sin första del", ", ".join(svagare))
	check(billigare.is_empty(), "och aldrig billigare (kedjan flyttas inte nedåt)", ", ".join(billigare))

	print("")
	print("— kortvalet får aldrig ge en uppgradering gratis —")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var sedda_val := {}
	var antal_val := 0
	for i in 4000:
		# rarity_bias 0..2 = samma tre lägen koden använder (level/4), alla måste vara rena.
		for id in Progress.draft(rng, db, 3, i % 3):
			sedda_val[id] = true
			antal_val += 1
	var läckta := []
	for id in sedda_val:
		if db[id].keywords.has(Evolution.KEYWORD):
			läckta.append(id)
	check(antal_val > 3000, "kortvalet ger val (svepet är inte tomt)", "%d val" % antal_val)
	check(sedda_val.size() > 30, "och ur hela högen, inte ur ett hörn", "%d olika kort" % sedda_val.size())
	check(läckta.is_empty(), "ingen uppgradering erbjuds ur högen", "%d val, läckta: %s" % [antal_val, str(läckta)])

	print("")
	print("— receptet i leken —")
	var deck := Cards.make_pile(db, ["lash", "lash", "shove", "dagger", "dagger", "vial",
		"axe", "bell", "ember_tome"])
	var klara := Evolution.available(deck)
	check(klara.has("whiplash"), "lash + shove är ett recept", str(klara))
	check(klara.has("leech_dagger"), "dagger + vial är ett recept")
	check(klara.has("emberstorm"), "axe + ember_tome är ett recept när ember_tome ligger i leken", str(klara))
	check(not klara.has("icicle_storm"), "och ett recept vars delar inte ligger i leken erbjuds inte")
	check(Evolution.available(Cards.make_pile(db, ["dagger"])).is_empty(), "en del ensam är inget recept")
	check(Evolution.count_in(deck, "lass") == 0 and Evolution.count_in(deck, "lash") == 2,
		"antalet exemplar räknas per id", "%d lash, %d lass" % [
			Evolution.count_in(deck, "lash"), Evolution.count_in(deck, "lass")])
	check(Evolution.recipe_text(db, "whiplash") == "Lash + Shove",
		"receptet går att läsa ur delarnas egna namn", Evolution.recipe_text(db, "whiplash"))

	print("")
	print("— bytet: två delar ur leken, ett kort in —")
	var före := deck.size()
	var lash_före := Evolution.count_in(deck, "lash")
	check(Evolution.consume(deck, db, "whiplash"), "bytet genomförs")
	check(deck.size() == före - 1, "leken KRYMPER med ett kort", "%d → %d" % [före, deck.size()])
	check(Evolution.count_in(deck, "lash") == lash_före - 1, "en Lash försvann",
		"%d → %d" % [lash_före, Evolution.count_in(deck, "lash")])
	check(Evolution.count_in(deck, "shove") == 0, "och Shove är borta")
	check(Evolution.count_in(deck, "whiplash") == 1, "resultatet ligger i leken")
	check(not Evolution.available(deck).has("whiplash"),
		"receptet är förbrukat — Shove finns inte längre")
	check(not Evolution.consume(deck, db, "whiplash"), "ett halvt recept genomförs aldrig")
	check(deck.size() == före - 1, "och ett nekat byte rör inte leken", "%d" % deck.size())
	check(not Evolution.consume(deck, db, "lash"), "ett kort utan recept kan inte konsumeras")
	check(Evolution.consume(deck, db, "leech_dagger"), "ett andra recept går att göra")
	check(Evolution.count_in(deck, "dagger") == 1 and Evolution.count_in(deck, "vial") == 0,
		"och tar exakt en kopia av varje del")

	print("")
	print("— i en körning: erbjudandet vid level up —")
	var körlek := Cards.make_pile(db, ["lash", "lash", "shove", "dagger", "dagger", "vial",
		"axe", "axe", "ember_tome", "bell"])
	var run := Run.new(stages["stage_01"], bestiary, körlek, 20260921, db)
	run.hp = 400.0
	run.max_hp = 400.0
	run.recovery = 30.0
	run.play_out()
	var erbjudna := []
	for d in run.drafts:
		for id in d.choices:
			if db[id].keywords.has(Evolution.KEYWORD):
				erbjudna.append(id)
	check(run.drafts.size() >= 3, "körningen gav kortval", "%d val" % run.drafts.size())
	check(not erbjudna.is_empty(), "uppgraderingen erbjuds när receptet ligger i leken", str(erbjudna))
	check(erbjudna.size() <= run.drafts.size(),
		"och högst ett per kortval (flera recept väntar till nästa nivå)",
		"%d erbjudanden i %d val" % [erbjudna.size(), run.drafts.size()])
	var unika := {}
	for id in erbjudna:
		unika[id] = true
	check(unika.size() == 3, "körningen erbjöd alla tre recepten som låg i leken",
		"%d av 3: %s" % [unika.size(), str(erbjudna)])
	check(not erbjudna.is_empty() and erbjudna[0] == "emberstorm",
		"och valet roterar mellan dem (nivån väljer startpunkt), inte alltid samma", str(erbjudna))

	var start_storlek := körlek.size()
	var nivåer := 0
	var tagna := 0
	var nekade := 0
	while not run.drafts.is_empty():
		var val: Array = run.pending_draft()
		var evo_id := ""
		for id in val:
			if db[id].keywords.has(Evolution.KEYWORD):
				evo_id = id
		if not evo_id.is_empty() and run.pick_card(evo_id):
			tagna += 1
		else:
			# Erbjudandet var inaktuellt (delarna togs av ett tidigare byte) — valet stryks, och
			# det är därför nekade val aldrig kan bli ett gratis kort.
			if not evo_id.is_empty():
				nekade += 1
			run.pick_card(val[0])
			nivåer += 1
	check(tagna >= 1, "uppgraderingen gick att ta i körningen", "%d tagna, %d nekade (inaktuella)" % [tagna, nekade])
	var i_leken := 0
	for c in körlek:
		if c.keywords.has(Evolution.KEYWORD):
			i_leken += 1
	check(i_leken == tagna, "och bara de tagna ligger i leken — ett nekat val ger inget kort",
		"%d uppgraderingar i leken, %d tagna" % [i_leken, tagna])
	check(run.deck.size() == start_storlek + nivåer - tagna,
		"leken växer med ett per kort och KRYMPER med ett per uppgradering",
		"%d → %d (%d kort, %d uppgraderingar)" % [start_storlek, run.deck.size(), nivåer, tagna])
	check(Evolution.count_in(körlek, "shove") == 0,
		"delen är förbrukad — ingen Shove kvar i leken efter bytet")

	# Samma seed, samma erbjudande: annars går en buggrapport inte att återskapa.
	var körlek_b := Cards.make_pile(db, ["lash", "lash", "shove", "dagger", "dagger", "vial",
		"axe", "axe", "ember_tome", "bell"])
	var run_b := Run.new(stages["stage_01"], bestiary, körlek_b, 20260921, db)
	run_b.hp = 400.0
	run_b.max_hp = 400.0
	run_b.recovery = 30.0
	run_b.play_out()
	var erbjudna_b := []
	for d in run_b.drafts:
		for id in d.choices:
			if db[id].keywords.has(Evolution.KEYWORD):
				erbjudna_b.append(id)
	check(erbjudna_b == erbjudna, "samma seed ger samma erbjudanden", str(erbjudna_b))

	print("")
	print("— den trasiga kanten: valet som inte längre går att göra —")
	var tunn := Cards.make_pile(db, ["leech_dagger"])
	var run_c := Run.new(stages["stage_01"], bestiary, tunn, 7, db)
	run_c.drafts.append({"level": 2, "choices": ["leech_dagger"]})
	check(not run_c.pick_card("leech_dagger"), "en uppgradering utan sina delar nekas")
	check(run_c.deck.size() == 1, "och leken är orörd", "%d kort" % run_c.deck.size())
	check(run_c.drafts.is_empty(), "valet stryks i stället för att kön fastnar på det")

	print("")
	print("— nyckelordet når fram till kortet —")
	# MÄTT FÖRST: uppslaget var "kw.Evolved" (datats versal) mot tabellen "kw.evolved". Alla tre
	# nyckelordens översättningar (3 × 13 språk) föll därför tillbaka på engelska på varje kort, i
	# varje språk — nycklar som fanns men aldrig nådde en skärm. Raden nedan mäter kortets TEXT.
	var ordet := Tr.t("kw.evolved", "?")
	var råa := 0
	for id in db:
		if db[id].describe().contains("Evolved"):
			råa += 1
	check(råa == 0, "ingen korttext visar det råa engelska nyckelordet", "%d kort av %d" % [råa, db.size()])
	check(db["emberstorm"].describe().contains(ordet),
		"uppgraderingen säger %s på kortet" % ordet, db["emberstorm"].describe())
	Tr.lang = "de"
	check(db["emberstorm"].describe().contains(Tr.t("kw.evolved", "?")),
		"och på språket man valt", db["emberstorm"].describe())
	Tr.lang = "sv"

	print("")
	print("— motorn känner igen uppgraderingen —")
	var c1 := Combat.new(11)
	c1.base_hand = 2
	c1.begin(Cards.make_pile(db, ["whiplash"]), [Combat.Enemy.new("prov", 200.0, 0.0)])
	var r1 := c1.play(0)
	var c2 := Combat.new(11)
	c2.base_hand = 2
	c2.begin(Cards.make_pile(db, ["lash"]), [Combat.Enemy.new("prov", 200.0, 0.0)])
	var r2 := c2.play(0)
	check(r1.damage > r2.damage, "uppgraderingen gör mer skada än sin del i en strid",
		"%.0f mot %.0f" % [r1.damage, r2.damage])
	check(c1.enemies[0].row > c2.enemies[0].row, "och knuffar bakåt (ärvd från Shove)",
		"rad %d mot %d" % [c1.enemies[0].row, c2.enemies[0].row])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
