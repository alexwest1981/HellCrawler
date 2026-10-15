## Körbart självtest av KORTENS BETEENDE mot referensen (M119).
##   cd game && ../tools/ett_prov.sh tests/test_kort_beteende.gd
## Två saker som referensens kort har och våra inte hade:
##   1. flaggan per kort (`ReceivesComboMultiplier`): kortet får ingen kedjemultiplikator
##   2. Crawlers: kortet STANNAR i spel och triggar sina effekter när spelaren gör det de reagerar på,
##      och lämnar efter `duration` gånger ("Crawlers trigger 2 more abilities before leaving")
## Dessutom: ett vanligt kort ska bete sig precis som förut — det är hela poängen med att lägga
## beteendet i DATA. Får de 80 andra korten ett annat liv är ändringen inte paritet, den är en ny lek.
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
	Tr.set_lang("sv")
	var db := Cards.load_all()

	print("— kedjan går att vägra (flaggan per kort) —")
	var c := Combat.new(2026)
	# FEM fiender: `hits` är antalet FIENDER ett kort träffar, inte antalet slag mot en. Med en enda
	# fiende klipps bells fem träffar till en, och kontrollen "39×5" skulle mäta fel sak.
	var fem := []
	for i in 5:
		fem.append(combat_enemy(100000.0, 5.0))
	c.begin([], fem)
	c.mana = 20
	c.hand = [db["lash"], db["dagger"], db["shrouded_bell"], db["warlock_shard"]]
	var r0 := c.play(0)
	check(r0.multiplier == 1 and is_equal_approx(r0.damage, 12.0), "lash (kostnad 0) slår på ×1",
		"×%d, %.0f skada" % [r0.multiplier, r0.damage])
	var r1 := c.play(0)
	check(r1.multiplier == 2, "dagger fortsätter kedjan till ×2", "×%d" % r1.multiplier)
	var r2 := c.play(0)
	check(r2.multiplier == 1 and not r2.broke_chain,
		"shrouded_bell (flaggan) tar ingen multiplikator — men bryter inte kedjan",
		"×%d, bröt=%s" % [r2.multiplier, str(r2.broke_chain)])
	check(is_equal_approx(r2.damage, 230.0), "shrouded_bell gör sin egen skada (46×5), ingen multiplikator",
		"%.0f" % r2.damage)
	check(c.combo == 3, "kedjan räknade ändå vidare genom den flaggade", "combo %d" % c.combo)
	var r3 := c.play(0)
	check(r3.multiplier == 4, "kortet efter den flaggade får steget den gav", "×%d" % r3.multiplier)

	# FÖRHANDSVISNINGEN MÅSTE LOVA SAMMA SOM SLAGET GER (M125). `play` och `preview` hade varje sin egen
	# regel: förhandsvisningen visade en multiplikator för de flaggade korten som `play` aldrig gav —
	# alltså en siffra spelaren såg men inte fick. Kontrollen mäter BÅDA på samma ställning och kräver
	# att de är lika; den fäller den gamla koden (då stod det ×3 i förhandsvisningen och ×1 i slaget).
	print("")
	print("— förhandsvisningen och slaget säger samma sak —")
	var cvis := Combat.new(4242)
	cvis.begin([], [combat_enemy(100000.0, 5.0)])
	cvis.mana = 20
	cvis.hand = [db["lash"], db["dagger"], db["shrouded_bell"]]
	cvis.play(0)                                 # lash: kedjan står på 1
	cvis.play(0)                                 # dagger: kedjan står på 2
	var visad := cvis.preview(0)
	var slagen := cvis.play(0)
	check(visad.multiplier == slagen.multiplier,
		"det flaggade kortets förhandsvisning visar samma multiplikator som slaget ger",
		"visad ×%d, slagen ×%d" % [visad.multiplier, slagen.multiplier])
	check(visad.damage == slagen.damage,
		"och samma skada", "visad %.0f, slagen %.0f" % [visad.damage, slagen.damage])

	print("— kortet som stannar i spel (Crawlers + Duration) —")
	var c2 := Combat.new(2026)
	c2.begin([], [combat_enemy(100000.0, 5.0)])
	c2.mana = 20
	c2.hand = [db["tarboy"], db["lash"], db["ember_tome"], db["ember_tome"]]
	var t0 := c2.play(0)
	check(c2.field.size() == 1 and t0.triggered.is_empty(), "tarboy går IN i spel och reagerar inte på sig själv",
		"%d i spel, %d reaktioner" % [c2.field.size(), t0.triggered.size()])
	check(not c2.discard_pile.has(db["tarboy"]) and not c2.exile_pile.has(db["tarboy"]),
		"kortet i spel ligger varken i kast- eller exilhögen")
	var t1 := c2.play(0)
	check(t1.triggered.is_empty(), "ett attackkort triggar den inte (den reagerar på mana)", "0 reaktioner")
	var t2 := c2.play(0)
	check(t2.triggered.size() == 1 and str(t2.triggered[0].card_id) == "tarboy",
		"ett manakort får den att reagera", "%d reaktioner" % t2.triggered.size())
	check(c2.field.size() == 1 and int(c2.field[0]["kvar"]) == 1, "den är kvar med en reaktion mindre",
		"%d i spel, %d kvar" % [c2.field.size(), int(c2.field[0]["kvar"])])
	var t3 := c2.play(0)
	check(t3.triggered.size() == 1 and c2.field.is_empty(), "andra reaktionen är den sista — då lämnar den bordet",
		"%d i spel" % c2.field.size())
	check(c2.discard_pile.has(db["tarboy"]), "och hamnar i kast-högen, inte i tomma intet")

	print("— ett vanligt kort beter sig precis som förut —")
	var c3 := Combat.new(2026)
	c3.begin([], [combat_enemy(100000.0, 5.0)])
	c3.mana = 20
	c3.hand = [db["lash"], db["dagger"]]
	c3.play(0)
	c3.play(0)
	check(c3.field.is_empty(), "inget ligger i spel efter två vanliga kort")
	check(c3.discard_pile.size() == 2, "båda ligger i kast-högen", "%d kort" % c3.discard_pile.size())

	print("— datat bär flaggorna, och spelaren kan läsa dem —")
	var utan_kedja := ["grave_choir", "the_long_winter", "shrouded_bell", "frost_bell"]
	var flaggade := 0
	var stora := 0
	for id in db:
		var card: Cards.Card = db[id]
		var skada := 0.0
		for e in card.effects:
			if str(e.get("op", "")) == "damage":
				skada += float(e.get("damage", 0.0)) * float(e.get("hits", 1))
		# REGELN (docs/balans.md §8): stort OCH sällsynt vägrar kedjan. Ett vanligt stort kort får den —
		# mätt: med flaggan på startlekens enda avslutare (bell, 195 för 2 mana) dog decken, slump 5->2
		# och rutten 17->6 av 60. Flaggan är ett verktyg för de kort som DYRT dyker upp ur draften,
		# inte en tröskel som slår mot allt stort.
		if skada >= 150.0 and card.rarity == "rare":
			stora += 1
			if not card.receives_combo:
				flaggade += 1
	check(flaggade == stora and stora >= 1,
		"varje stort (≥150) SÄLLSYNT kort vägrar kedjan", "%d av %d" % [flaggade, stora])
	var saknas := []
	for id in utan_kedja:
		if bool(db[id].receives_combo):
			saknas.append(id)
	check(saknas.is_empty(), "de fyra namngivna korten är flaggade", "saknas: %s" % str(saknas))
	check(db["bell"].receives_combo and db["emberstorm"].receives_combo,
		"startlekens stora vanliga kort BEHÅLLER kedjan (annars dör decken — mätt)")
	check(db["tarboy"].duration == 2 and db["tarboy"].trigger == "mana",
		"tarboy stannar 2 turer och reagerar på mana",
		"%d turer, %s" % [db["tarboy"].duration, db["tarboy"].trigger])
	check(db["cleric_of_light"].duration == 2 and db["cleric_of_light"].trigger == "attack",
		"cleric_of_light stannar 2 turer och reagerar på attacker",
		"%d turer, %s" % [db["cleric_of_light"].duration, db["cleric_of_light"].trigger])
	check(db["lash"].receives_combo and db["lash"].duration == 0,
		"lash är orörd (kedja, engångskort)")
	var b: String = db["shrouded_bell"].describe()
	var t: String = db["tarboy"].describe()
	check(b.contains("utan kedja"), "kortet säger själv att det står utanför kedjan", b)
	check(t.contains("stannar 2 turer") and t.contains("mana"),
		"och kompanjonen säger att den stannar och vad den reagerar på", t)
	var l: String = db["lash"].describe()
	check(l == "12×1", "ett vanligt korts text är oförändrad", l)

	print("kontroller: %d, fel: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)

func combat_enemy(hp: float, dmg: float, row: int = 0, eyes: int = 0) -> Combat.Enemy:
	return Combat.Enemy.new("provfiende", hp, dmg, row, eyes)
