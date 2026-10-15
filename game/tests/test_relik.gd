## RELIK-LAGRET (M123). Referensen har 67 reliker och 52 arcanas; vi hade NOLL, och `docs/balans.md`
## §8 rad B säger rakt ut vad som saknas: "relicen som låser upp kedjan är kvar". Provet grindar
## mekanismen — att datan laddas, att en ratt i datan FAKTISKT når spelet, och att en relik inte kan
## tas två gånger. Hur relikerna BALANSERAR mäts i `test_balans.gd` (körningarna plockar dem ur kistor).
##
##   godot --headless --script res://tests/test_relik.gd
extends SceneTree

var checks := 0
var fails := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", what, "" if detail.is_empty() else "  (%s)" % detail])


func _initialize() -> void:
	print("— relikerna —")
	var db := Relics.load_all()
	check(db.size() >= 8, "relikerna laddas ur data", "%d reliker" % db.size())
	var okända: Array = []
	for id in db:
		for nyckel in db[id].effect:
			if not Relics.RATTAR.has(str(nyckel)):
				okända.append("%s.%s" % [id, nyckel])
	check(okända.is_empty(), "varje ratt i datan läses av någon kod",
		"%s" % ("alla kända" if okända.is_empty() else ", ".join(okända)))

	# 1) En ratt i datan måste nå körningen.
	var run := _run(20261231)
	var hp_före := run.max_hp
	var r: Relics.RelicDef = run.add_relic("iron_heart")
	check(r != null and is_equal_approx(run.max_hp, hp_före + 15.0),
		"en relik ur datan ändrar körningens ratt (järnhjärtat +15 max-HP)",
		"%.0f -> %.0f" % [hp_före, run.max_hp])
	check(run.add_relic("iron_heart") == null, "samma relik kan inte tas två gånger",
		"%d reliker i körningen" % run.relics.size())
	check(run.add_relic("finns_inte") == null, "ett okänt id gör ingenting")

	# 2) Kedjestenen: extra steg när kedjan FORTSÄTTER, aldrig en kedja ur tomma luften.
	var utan := _strid(false)
	var med := _strid(true)
	check(utan == 3 and med == 5, "kedjestenen tar kedjan högre (1-2-3 blir 1-3-5)",
		"utan %d, med %d (kedjan efter tre stigande kort)" % [utan, med])

	# 3) Den vässade eggen: +N per skaderad, precis som en ädelsten.
	var k1 := Combat.new(7)
	k1.begin([], [_fiende()])
	k1.mana = 20
	k1.hand = [_kort("lash")]
	var d1 := k1.play(0).damage
	var k2 := Combat.new(7)
	k2.begin([], [_fiende()])
	k2.mana = 20
	k2.hand = [_kort("lash")]
	k2.relic_damage = 4.0
	var d2 := k2.play(0).damage
	check(is_equal_approx(d2 - d1, 4.0), "relikens skada läggs på varje träff (12 -> 16 på lash)",
		"utan %.0f, med %.0f" % [d1, d2])

	# 4) Leveransen: ett VAL, inte en lott (VC-paritet 15/10). Provet mätte förut tjugo spelade
	#    körningar och krävde att minst en hittade en relik — men sedan reliken blev ett val ligger
	#    den inte på körningen förrän spelaren SVARAR, och rutten går genom handritade kartor
	#    (`data/maps/*.json`, generatorn är reserven), så sällan-kortet är inte provets sak.
	#    Grinden är därför deterministisk: slagfönstret är seedat (`(seed + x*31 + y*17) % 100`), så
	#    provet VÄLJER en ruta som ligger innanför det och prövar hela vägen — kista -> val -> relik.
	var rr2 := _run(4242)
	var nod := Dungeon.FloorNode.new()
	nod.kind = "chest"
	var träffad := false
	for y in 40:
		for x in 40:
			if (rr2.seed_value + x * 31 + y * 17) % 100 < 4:
				nod.pos = Vector2i(x, y)
				träffad = true
				break
		if träffad:
			break
	check(träffad, "provet hittar en kistruta innanför relikfönstret", "ruta %s" % str(nod.pos))
	var ev := rr2._open_chest(nod)
	check(str(ev.get("vad", "")) == "relikval", "kistan erbjuder ett relikval", str(ev.get("vad", "")))
	check(rr2.pending_draft_relic(), "och valet ligger i kön",
		"%s" % str(rr2.pending_relics()))
	var kandidater: Array = rr2.pending_relics()
	check(kandidater.size() >= 2, "med minst två kandidater att välja mellan", "%d" % kandidater.size())
	check(rr2.relics.is_empty(), "reliken ligger INTE på körningen förrän valet svaras", str(rr2.relics))
	if not kandidater.is_empty():
		check(rr2.pick_relic(str(kandidater[0])), "valet går att svara på")
		check(rr2.relics.size() == 1, "och då ligger reliken på körningen", str(rr2.relics))
		check(not rr2.pending_draft_relic(), "och kön är tom efteråt")
	# Ett VAL är deterministiskt: samma frö och samma ruta ger samma par.
	var rr3 := _run(4242)
	var ev2 := rr3._open_chest(nod)
	check(str(ev2.get("val", [])) == str(kandidater), "samma frö ger samma kandidater (valet är seedat)",
		"%s mot %s" % [str(ev2.get("val", [])), str(kandidater)])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fiende() -> Combat.Enemy:
	return Combat.Enemy.new("prov", 400.0, 3.0, 0, 0)


func _kort(id: String) -> Cards.Card:
	var db := Cards.load_all()
	return db[id]


## Kör tre stigande kort och svara med kedjan efter dem. Med kedjestenen blir den 5, utan 3.
## Korten väljs ur datan efter kostnad — inte med namn, som kunde sluta stämma när datan ändras.
func _strid(med_relik: bool) -> int:
	var k := Combat.new(11)
	k.begin([], [_fiende()])
	k.mana = 30
	var db := Cards.load_all()
	for önskad in [0, 1, 2]:
		for id in db:
			if db[id].cost == önskad and not db[id].is_wild():
				k.hand.append(db[id])
				break
	if med_relik:
		k.combo_bonus = 1
	# Spela korten i STIGANDE kostnad: det är hela kedjan.
	for i in 3:
		var billigast := -1
		for j in k.hand.size():
			if k.hand[j].cost <= k.mana and (billigast < 0 or k.hand[j].cost < k.hand[billigast].cost):
				billigast = j
		if billigast < 0:
			break
		k.play(billigast)
	return k.combo


func _run(seed_value: int) -> Run:
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var db := Cards.load_all()
	return Run.new(stages["stage_01"], bestiary,
		Cards.make_pile(db, load("res://main.gd").DECK.duplicate()), seed_value, db)


## Gå noderna direkt, samma väg som mätaren (`run._resolve`), tills körningen tar slut.
func _spela(run: Run) -> void:
	var vakt := 0
	while run.outcome == "" and vakt < 64:
		vakt += 1
		var n: Dungeon.FloorNode = run._next_objective()
		if n == null:
			break
		run._resolve(n)
		# RELIKVALET SVARAS (VC-paritet 15/10): reliken ges inte längre av att man går in i rummet —
		# den är ett VAL (referensens "Choose a reward"), och först när spelaren svarar hamnar den på
		# körningen. Provet tar den första kandidaten: det här provet mäter leveransen, inte policyn.
		var svar := 0
		while run.pending_draft_relic() and svar < 8:
			svar += 1
			var k: Array = run.pending_relics()
			if k.is_empty():
				break
			run.pick_relic(str(k[0]))
