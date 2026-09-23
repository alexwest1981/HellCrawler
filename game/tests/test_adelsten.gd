## Splitter och ädelstenar (M57/M58) — den unika valutan, facken i korten och stenarnas verkan.
##
## Alex: *"Vi måste även skapa ett gemstone-system för även gems skall gömma sig i kistor, och de
## gemstone's skall ha olika properties och finnas i 5 olika nivåer av varje, från simpel till
## exquisite, å de skall gå att sätta i sina kort (som man för övrigt skall kunna låsa upp fler slots
## i hos juveleraren)."*
##
## Provet mäter fyra saker, alla REN logik:
##   1. SPLITTRET: en splitter-nod drar splitter och lämnar guldet orört — och tvärtom. Valutan är
##      bara unik om den inte kan köpas för pengar.
##   2. FACKEN: priset stiger per fack, fyra är taket, och guldet måste räcka.
##   3. STENARNA: en sten lämnar fickan när den sätts i ett kort, kommer tillbaka när den plockas ur,
##      och två stenar i samma fack går inte.
##   4. VERKAN: stenen i kortet syns i STRIDEN — och förhandsvisningen visar samma siffra som slaget
##      ger (en förhandsvisning som gissar är värre än ingen).
##
## FLIT-BORT (beviset för att provet kan gå rött): sätt `combat.gem_bonus = {}` i begin_fight och
## provet faller på "stenen ger samma skada i förhandsvisningen som i slaget"; byt `shards -=` mot
## `gold -=` i Meta.buy och det faller på "…och guldet står orört".
##
##   godot --headless --script res://tests/test_adelsten.gd
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

func _met() -> Meta:
	var m := Meta.new()
	m._load_defs()
	m._load_crawlers()
	m._load_gems()
	return m

func _initialize() -> void:
	var db := Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	if db.is_empty() or stages.is_empty() or bestiary.is_empty():
		print("inget innehåll att köra")
		quit(1)
		return

	# --- 1. splittret ---------------------------------------------------------------------------
	print("— splittern —")
	var m := _met()
	check(m.gem_defs.size() == 5, "fem stenfamiljer i datat", "%d" % m.gem_defs.size())
	m.gold = 200000
	m.souls = 40
	var låst := m.buy("iron_5")
	check(not låst.ok, "en trädgren med kravet ogjort går inte att köpa", str(låst.reason))
	m.ranks["iron_4"] = 3
	var guld_före := m.gold
	var cs_pris := m.next_soul_cost("iron_5")
	var köpt := m.buy("iron_5")
	check(köpt.ok, "trädgrenen köps")
	# TRÄDET KOSTAR CS (M95, Alex: *"Skills i skill tree skall inte kosta guld, de skall kosta CS"*).
	check(m.souls == 40 - cs_pris, "…och CS drogs", "40 -> %d (pris %d)" % [m.souls, cs_pris])
	check(m.gold == guld_före, "…och guldet står orört", "%d" % m.gold)
	# Fickorna är bara unika om de inte blandas: en guld-nod (uppgraderingen might) rör inte CS.
	var m2 := _met()
	m2.gold = 1000
	m2.souls = 40
	var guld_pris := m2.next_cost("might")
	check(m2.buy("might").ok, "guld-noden köps för guld")
	check(m2.souls == 40, "…och CS står orört", "%d" % m2.souls)
	check(m2.gold == 1000 - guld_pris, "…och guldet drogs", "%d (pris %d)" % [m2.gold, guld_pris])
	# Utan CS går trädet inte, hur mycket guld som helst.
	var m3 := _met()
	m3.gold = 999999
	m3.ranks["iron_4"] = 3
	m3.souls = maxi(0, m3.next_soul_cost("iron_5") - 1)     # en CS för lite, inte ett gissat tal
	var fattig := m3.buy("iron_5")
	check(not fattig.ok and str(fattig.reason) == "for_lite_cs",
		"guld köper INTE en trädgren", str(fattig.reason))

	# --- 2. facken ------------------------------------------------------------------------------
	print("— facken —")
	var m4 := _met()
	m4.gold = 100000
	var kort := str(db.keys()[0])
	var priser := []
	for i in 4:
		priser.append(m4.gem_slot_cost(kort))
		var res := m4.buy_gem_slot(kort)
		check(res.ok, "fack %d öppnas" % (i + 1), "pris %d" % int(res.get("pris", 0)))
	check(priser == [300, 900, 2200, 5000], "priset stiger per fack", str(priser))
	check(m4.gem_slots_for(kort) == 4, "fyra fack är taket")
	check(not m4.buy_gem_slot(kort).ok, "ett femte fack går inte att köpa")
	var m5 := _met()
	m5.gold = 100
	check(not m5.buy_gem_slot(kort).ok, "utan guld blir facket inte öppnat")
	check(m5.gem_slots_for(kort) == 0, "…och inget fack öppnades")

	# --- 3. stenarna i fickan och i facken ------------------------------------------------------
	print("— stenarna —")
	var m6 := _met()
	m6.gold = 100000
	m6.buy_gem_slot(kort)
	m6.buy_gem_slot(kort)
	m6.gem_add("ember", 0)
	m6.gem_add("ember", 2)
	check(m6.gem_count("ember", 0) == 1 and m6.gem_count("ember", 2) == 1, "fickan håller räkningen per grad")
	check(m6.gem_bag().size() == 2, "fickan listar två stenar", str(m6.gem_bag().size()))
	check(not m6.socket(kort, 3, "ember", 2).ok, "ett fack som inte är öppnat tar ingen sten",
		"bara fack 1-2 är öppna")
	var satt := m6.socket(kort, 0, "ember", 2)
	check(satt.ok, "stenen sätts i ett öppet fack")
	check(m6.gem_count("ember", 2) == 0, "…och lämnar fickan")
	check(not m6.socket(kort, 0, "ember", 0).ok, "samma fack tar inte två stenar")
	var ur := m6.unsocket(kort, 0)
	check(ur.ok, "stenen går att plocka ur")
	check(m6.gem_count("ember", 2) == 1, "…och kommer tillbaka till fickan")
	check(m6.gem_in_slot(kort, 0).is_empty(), "…och facket är tomt igen")

	# --- 4. verkan i striden --------------------------------------------------------------------
	print("— verkan i striden —")
	var m7 := _met()
	m7.gold = 100000
	var skada_kort := ""
	for id in db.keys():
		var c: Cards.Card = db[id]
		for e in c.effects:
			if str(e.get("op", "")) == "damage" and str(skada_kort).is_empty():
				skada_kort = str(id)
	if skada_kort.is_empty():
		check(false, "hittade ett skadekort att mäta med")
	else:
		m7.buy_gem_slot(skada_kort)
		m7.buy_gem_slot(skada_kort)
		m7.gem_add("ember", 3)          # +5 skada
		check(m7.socket(skada_kort, 0, "ember", 3).ok, "emberstenen sätts i kortet")
		check(int(m7.gem_bonus(skada_kort).get("damage", 0)) == 5, "stenen ger +5 skada",
			str(m7.gem_bonus(skada_kort)))
		var utan := _strid(stages, bestiary, db, m7, skada_kort, false)
		var med := _strid(stages, bestiary, db, m7, skada_kort, true)
		check(med > utan, "stenen höjer skadan i slaget", "%.0f -> %.0f" % [utan, med])
		var förhands := _förhands(stages, bestiary, db, m7, skada_kort, true)
		check(is_equal_approx(förhands, med), "förhandsvisningen visar samma siffra som slaget",
			"%.0f mot %.0f" % [förhands, med])

	# --- 5. kistan och stenen ur den ------------------------------------------------------------
	print("— kistan —")
	check(Meta.kista_splitter(1) == 1 and Meta.kista_splitter(5) == 3,
		"splitter per kista stiger med djupet", "%d / %d" % [Meta.kista_splitter(1), Meta.kista_splitter(5)])
	var m8 := _met()
	var f := Dungeon.generate(stages["stage_01"], 0, 42, bestiary)
	var kista: Dungeon.FloorNode = null
	for n in f.nodes_of_kind("chest"):
		kista = n
		break
	if kista == null:
		check(false, "våningen har en kista att mäta")
	else:
		var r := Run.new(stages["stage_01"], bestiary, Cards.make_pile(db, ["lash", "lash"]), 42, db, m8)
		var händelse := r._open_chest(kista)
		check(int(händelse.get("shards", 0)) > 0, "kistan ger splitter",
			str(händelse.get("shards", 0)))
		check(r.shards == int(händelse.get("shards", 0)), "…och körningen bär den", "%d" % r.shards)
		# Sten-vägen ska vara NÅBAR (15 % av kistorna) och SEEDAD: samma frö och samma kista ger
		# samma sten. Provet går igenom 60 kistor och kräver båda.
		var med_sten := 0
		var avgjord := true
		# Fröna måste SPRIDAS: kistans slag är (frö + rutans position) % 100, och intilliggande frön
		# ger intilliggande slag — en tät svit hamnade utanför stenfönstret och mätte 0 av 60 kistor
		# (mätt). Här går fröna över hela intervallet i stället.
		for s in 120:
			var ra := Run.new(stages["stage_01"], bestiary, Cards.make_pile(db, ["lash", "lash"]),
				s * 3 + 1, db, m8)
			var rb := Run.new(stages["stage_01"], bestiary, Cards.make_pile(db, ["lash", "lash"]),
				s * 3 + 1, db, m8)
			var k: Dungeon.FloorNode = ra.explore.floor_ref.nodes_of_kind("chest")[0]
			ra._open_chest(k)
			rb._open_chest(k)
			if not ra.stenar.is_empty():
				med_sten += 1
			if str(ra.stenar) != str(rb.stenar):
				avgjord = false
		check(med_sten > 0, "kistorna gömmer stenar", "%d av 120 kistor" % med_sten)
		check(avgjord, "och samma kista ger samma sten varje gång")

	# --- 6. graden stiger med djupet ------------------------------------------------------------
	print("— graden —")
	var djupt := 0.0
	var grunt := 0.0
	var m9 := _met()
	for i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		grunt += int(m9.pick_sten(1, rng).get("grad", 0))
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 1000 + i
		djupt += int(m9.pick_sten(6, rng2).get("grad", 0))
	grunt /= 200.0
	djupt /= 200.0
	check(djupt > grunt + 1.0, "djupet ger högre grad", "våning 1: %.2f, våning 6: %.2f" % [grunt, djupt])
	check(grunt < 1.5, "våning 1 ger mest simpel sten", "%.2f" % grunt)

	print("=== adelsten: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

## Spelar ETT slag med kortet på en fiende och svarar med skadan. `med_sten` styr om striden får
## stenarnas bonuskarta — samma körning, samma frö, samma kort: bara kartan skiljer.
func _strid(stages: Dictionary, bestiary: Dictionary, db: Dictionary, m: Meta, kort_id: String,
		med_sten: bool) -> float:
	var r := Run.new(stages["stage_01"], bestiary, Cards.make_pile(db, [kort_id]), 5, db, m)
	var nod: Dungeon.FloorNode = r.explore.floor_ref.nodes_of_kind("encounter")[0]
	var c := r.begin_fight(nod, false)
	if not med_sten:
		c.gem_bonus = {}
	c.hand = [db[kort_id]]
	c.mana = 9
	c.start_turn()
	c.hand = [db[kort_id]]
	var res := c.play(0)
	return res.damage

## Förhandsvisningen: samma strid, men kortet spelas aldrig.
func _förhands(stages: Dictionary, bestiary: Dictionary, db: Dictionary, m: Meta, kort_id: String,
		med_sten: bool) -> float:
	var r := Run.new(stages["stage_01"], bestiary, Cards.make_pile(db, [kort_id]), 5, db, m)
	var nod: Dungeon.FloorNode = r.explore.floor_ref.nodes_of_kind("encounter")[0]
	var c := r.begin_fight(nod, false)
	if not med_sten:
		c.gem_bonus = {}
	c.mana = 9
	c.hand = [db[kort_id]]
	var p := c.preview(0)
	return float(p.get("damage", 0.0))
