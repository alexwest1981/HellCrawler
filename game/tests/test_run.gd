## Hela körningen headless: gå genom våningarna, slåss, ta shoveln, nedåt — och bevisa att
## utfallet går att återskapa med samma seed.
##   godot --headless --script res://tests/test_run.gd
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
	if db.is_empty() or stages.is_empty() or bestiary.is_empty():
		print("inget innehåll att köra")
		quit(1)
		return

	print("— utforskarläget —")
	var f := Dungeon.generate(stages["stage_01"], 0, 42, bestiary)
	var ex := Explore.new(f)
	check(ex.pos == f.start, "spelaren startar på startrutan")
	var start_facing := ex.facing
	for i in 4:
		ex.turn_right()
	check(ex.facing == start_facing, "fyra svängar höger = samma riktning")
	ex.turn_left()
	check(ex.facing == (start_facing + 3) % 4, "vänster är motsatt höger")
	# BAKLÄNGES (S): samma ruta, blicken kvar. Invarianten gäller även mot en vägg — antingen flyttar
	# steget spelaren, eller så står hen kvar och får "vaggen". Aldrig halvvägs.
	var här := ex.pos
	var riktning := ex.facing
	var fel := ex.backward()
	check((fel == "") != (ex.pos == här), "baklänges flyttar spelaren eller stannar vid vägg",
		"%s -> %s" % [fel, ex.pos])
	if fel == "":
		check(ex.forward() == "" and ex.pos == här, "fram igen står på samma ruta")
		check(ex.facing == riktning, "blicken är kvar i samma riktning efter ett baklängessteg")
	var boss_node = f.nodes_of_kind("boss")[0]
	var steps := 0
	while ex.pos != boss_node.pos and steps < 500:
		steps += 1
		if ex.step_toward(boss_node.pos) != "":
			break
	check(ex.pos == boss_node.pos, "går att gå till bossen ruta för ruta", "%d steg, %d svängar" % [ex.steps_taken, ex.turns_taken])
	check(ex.steps_taken >= steps, "varje ruta kostade ett steg")

	print("— en hel körning —")
	var deck := Cards.make_pile(db, [
		"lash", "lash", "lash", "lash",
		"dagger", "dagger", "dagger", "dagger",
		"axe", "axe", "axe", "axe",
		"bell", "bell", "ember_tome", "ember_tome", "deep_tome",
		"wild_mana", "wild_mana", "vial",
	])
	var stage: Stages.StageDef = stages["stage_01"]
	_tree_in_run(stage, bestiary, db, deck)
	var run := _new_run(stage, bestiary, deck, 20260919, db)
	var events := run.play_out()
	var kinds := {}
	for e in events:
		kinds[e.type] = int(kinds.get(e.type, 0)) + 1
	print("    %s (våning %d/%d, %d steg, %d strider vunna, %d förlorade, %.0f skada, %d guld, %d xp)" % [
		run.outcome, run.floor_index + 1, stage.floors, run.explore.steps_taken,
		run.fights_won, run.fights_lost, run.total_damage, run.gold, run.xp])

	check(run.finished, "körningen tar slut")
	check(run.outcome == "cleared" or run.outcome == "reaped", "utfallet är ett slut, inte en hängning", run.outcome)
	check(int(kinds.get("floor_enter", 0)) == stage.floors, "alla våningar besöktes",
		"%d av %d" % [int(kinds.get("floor_enter", 0)), stage.floors])
	check(int(kinds.get("combat_start", 0)) >= stage.floors * 4, "striderna spelades",
		"%d strider" % int(kinds.get("combat_start", 0)))
	check(int(kinds.get("shovel", 0)) >= stage.floors - 1, "shoveln togs varje gång den behövdes",
		"%d gånger" % int(kinds.get("shovel", 0)))
	check(int(kinds.get("stuck", 0)) == 0, "ingen våning var omöjlig att gå i")
	check(int(kinds.get("missing_enemy", 0)) == 0, "alla fiender i noderna finns i bestiariet")
	check(run.fights_won > 0, "minst en strid vunnits", "%d" % run.fights_won)
	check(_boss_fights(events) == stage.floors, "bossen på varje våning konfronterades",
		"%d av %d" % [_boss_fights(events), stage.floors])

	print("— samma seed = samma körning —")
	var run2 := _new_run(stage, bestiary, deck, 20260919, db)
	run2.play_out()
	check(run2.outcome == run.outcome, "samma utfall", "%s vs %s" % [run.outcome, run2.outcome])
	check(run2.gold == run.gold and run2.xp == run.xp, "samma guld och xp",
		"%d/%d vs %d/%d" % [run.gold, run.xp, run2.gold, run2.xp])
	check(is_equal_approx(run2.hp, run.hp), "samma HP kvar", "%.1f vs %.1f" % [run.hp, run2.hp])
	var run3 := _new_run(stage, bestiary, deck, 555, db)
	var events3 := run3.play_out()
	check(run3.outcome != "" and run3.explore.steps_taken != run.explore.steps_taken or run3.gold != run.gold,
		"en annan seed ger en annan körning", "%d steg vs %d" % [run3.explore.steps_taken, run.explore.steps_taken])

	print("")
	print("— kistor och facklor —")
	# De ritades på kartan men gjorde ingenting: man gick in i dem och det hände inget alls. Provet
	# letar upp en våning som FAKTISKT har dem (de läggs bara om rummen räcker) och mäter utfallet.
	var kista := {}
	var fackla := {}
	for sv in range(1, 80):
		var v := Dungeon.generate(stage, 0, sv, bestiary)
		for n in v.nodes:
			if n.kind == "chest" and kista.is_empty():
				kista = {"seed": sv, "pos": n.pos}
			elif n.kind == "torch" and fackla.is_empty():
				fackla = {"seed": sv, "pos": n.pos}
	check(not kista.is_empty(), "det finns en kista att hitta", str(kista))
	check(not fackla.is_empty(), "det finns en fackla att hitta", str(fackla))

	if not kista.is_empty():
		var rk := _new_run(stage, bestiary, deck, int(kista["seed"]), db)
		rk.hp = rk.max_hp * 0.5
		var hp_före := rk.hp
		var guld_före := rk.gold
		var nod := _node_at(rk, kista["pos"])
		var ut := rk.enter_node(nod)
		check(ut == null, "kistan är ingen strid")
		check(nod.cleared, "och den blir avklarad")
		check(rk.gold > guld_före or rk.hp > hp_före,
			"något hände när man öppnade den", "%d guld, %.0f hp" % [rk.gold, rk.hp])
		check(rk.events.back().type == "chest", "och det loggas som en kista",
			str(rk.events.back()))

		# Samma seed ska ge samma kista — annars är våningens determinism en lögn.
		var rk2 := _new_run(stage, bestiary, deck, int(kista["seed"]), db)
		rk2.hp = rk2.max_hp * 0.5
		rk2.enter_node(_node_at(rk2, kista["pos"]))
		check(rk2.gold == rk.gold and is_equal_approx(rk2.hp, rk.hp),
			"samma kista ger samma sak varje gång", "%d mot %d guld" % [rk2.gold, rk.gold])

	if not fackla.is_empty():
		var rf := _new_run(stage, bestiary, deck, int(fackla["seed"]), db)
		rf.hp = 10.0
		rf.enter_node(_node_at(rf, fackla["pos"]))
		check(rf.hp > 10.0, "facklan läker", "%.0f hp" % rf.hp)
		check(rf.hp <= rf.max_hp, "och aldrig över taket", "%.0f av %.0f" % [rf.hp, rf.max_hp])
		# En full spelare ska inte kunna dricka över taket: läkningen stannar vid max.
		var rf2 := _new_run(stage, bestiary, deck, int(fackla["seed"]), db)
		rf2.enter_node(_node_at(rf2, fackla["pos"]))
		check(is_equal_approx(rf2.hp, rf2.max_hp), "vid full HP händer inget farligt",
			"%.0f av %.0f" % [rf2.hp, rf2.max_hp])

	print("")
	print("— packet står i rader: bara den främre slår —")
	# Mätt fel som det här provet vaktar: run.gd satte ALLA fiender i rad 0. combat.gd:s regel är att
	# bara den främre raden slår och att nästa rad tar över när raden framför fallit (samma regel som
	# referensen, research/01 §6) — med hela packet i rad 0 slog alla varje runda, och Shove (som
	# knuffar bakåt) var verkningslöst. Följden mättes med tools/balance.gd i M30: svårighet 3 var
	# omöjlig att forcera, och stage_01 gick från 18/20 klarade till 11/20 utan rader.
	var rr := Run.new(stage, bestiary, deck, 20260919, db)
	var paket: Dungeon.FloorNode = null
	for n in rr.explore.floor_ref.nodes_of_kind("encounter"):
		if rr.enemy_count_for(n) > 1:
			paket = n
			break
	check(paket != null, "det finns ett möte med fler än en fiende på våningen")
	if paket != null:
		var c := rr.begin_fight(paket, false)
		check(c != null and c.enemies.size() > 1, "striden har ett packet",
			"%d fiender" % (c.enemies.size() if c != null else 0))
		var rader := []
		var summa := 0.0
		for e in c.enemies:
			rader.append(e.row)
			summa += e.damage
		check(int(rader.max()) > 0, "packet står i olika rader, inte allt i rad 0", str(rader))
		var hp_före := c.hp
		c.end_turn()
		var tappat := hp_före - c.hp
		check(tappat < summa, "bara den främre raden slår",
			"tappade %.0f av %.0f möjliga" % [tappat, summa])

	print("")
	print("— banans xp_bonus räknas —")
	# Fältet står i alla 40 bana-filer (0,0 på svårighet 1 och stigande till 0,6 på svårighet 7+) och
	# lästes av INGEN — en svårare bana gav samma xp per dödad fiende som den lättaste. Provet mäter EN
	# dödad fiende, inte en hel körning, så talet är exakt: xp = fiendens xp × antal × (1 + xp_bonus).
	var s5: Stages.StageDef = stages["stage_05"]
	var sparat_bonus := s5.xp_bonus
	var xp_utan := 0
	var xp_med := 0
	for bonus in [0.0, 1.0]:
		s5.xp_bonus = bonus
		var rx := Run.new(s5, bestiary, deck, 4242, db)
		var nod_xp: Dungeon.FloorNode = rx.explore.floor_ref.nodes_of_kind("encounter")[0]
		var cx := rx.begin_fight(nod_xp, false)
		for e in cx.enemies:
			e.hp = 0.0                      # fienden är död: striden är vunnen
		rx.finish_fight(nod_xp, cx)
		if bonus == 0.0:
			xp_utan = rx.xp
		else:
			xp_med = rx.xp
	s5.xp_bonus = sparat_bonus
	check(xp_utan > 0, "striden gav xp alls", "%d xp" % xp_utan)
	check(xp_med == xp_utan * 2, "xp_bonus 1,0 fördubblar xp:n för samma strid",
		"%d mot %d" % [xp_med, xp_utan])

	print("")
	print("— rustningen följer med mellan striderna (M75) —")
	# Alex: *"vi behöver ha en rustning som visar rustningens värde (som för övrigt skall följa med
	# genom de olika striderna, inte nollas efter en strid)"*. Rustningen nollställdes vid varje TUR
	# (`Combat.start_turn`) mot metans grundvärde, så ett rustningskort var borta innan nästa tur och
	# ingen strid ärvde något. Provet mäter hela vägen: samla rustning, avsluta striden, och se att
	# NÄSTA strid börjar med samma värde.
	var rustkörning := Run.new(stages["stage_01"], bestiary, deck, 777, db)
	var nod_r1: Dungeon.FloorNode = rustkörning.explore.floor_ref.nodes_of_kind("encounter")[0]
	var c1 := rustkörning.begin_fight(nod_r1, false)
	var grund := c1.armor
	c1.armor += 7.0
	c1.start_turn()                     # en ny tur fick förut nollställa poolen
	check(absf(c1.armor - (grund + 7.0)) < 0.001, "rustningen står kvar över en tur",
		"%.0f, väntade %.0f" % [c1.armor, grund + 7.0])
	for e in c1.enemies:
		e.hp = 0.0
	rustkörning.finish_fight(nod_r1, c1)
	check(absf(rustkörning.armor - (grund + 7.0)) < 0.001,
		"körningen tar över rustningen när striden är slut", "%.0f" % rustkörning.armor)
	check(rustkörning.armor_tak >= grund + 7.0,
		"och taket för stapeln följer med (annars står den alltid full)", "%.0f" % rustkörning.armor_tak)
	var nod_r2: Dungeon.FloorNode = rustkörning.explore.floor_ref.nodes_of_kind("encounter")[1]
	var c2 := rustkörning.begin_fight(nod_r2, false)
	check(absf(c2.armor - (grund + 7.0)) < 0.001, "och nästa strid BÖRJAR med samma rustning",
		"%.0f, väntade %.0f" % [c2.armor, grund + 7.0])

	print("")
	print("")
	print("— kamerans vinkel och svängen (M37) —")
	# `yaw_for` är den ENDA platsen där facing blir en vinkel (förut räknades den på tre ställen i
	# main.gd). 0 = norr (0 rad), 1 = öster (-90), 2 = söder (-180), 3 = väster (-270).
	check(is_equal_approx(Explore.yaw_for(0), 0.0) and is_equal_approx(Explore.yaw_for(2), -PI)
		and is_equal_approx(Explore.yaw_for(1), -PI / 2.0),
		"yaw_for: norr, öster och söder", "%.2f %.2f %.2f"
			% [Explore.yaw_for(0), Explore.yaw_for(1), Explore.yaw_for(2)])
	# SVÄNGEN ÖVER 180-GRÄNSEN: från väster (facing 3) till norr (facing 0) ska kameran gå KORT väg
	# (-90 grader). Utan `närmaste_vinkel` tog tweenen +4,71 rad i stället för -1,57 — mätt i
	# körning innan fixen (stegprovet), och det syns som att kameran snurrar fel håll.
	var från_väster := Explore.yaw_for(3)
	var till_norr := Explore.närmaste_vinkel(från_väster, Explore.yaw_for(0))
	check(absf((till_norr - från_väster) + PI / 2.0) < 0.001,
		"svängen väster -> norr tar kortaste vägen", "%.2f rad (kort väg är -1,57)" % (till_norr - från_väster))
	# Och den allmänna regeln: ingen sväng tar LÅNGA vägen. Ett halvt varv är tillåtet (två svängar
	# i rad möter man mot man, och då ÄR kortaste vägen 180 grader) — men aldrig mer.
	var värst := 0.0
	for a in 4:
		for b in 4:
			värst = maxf(värst, absf(Explore.närmaste_vinkel(Explore.yaw_for(a), Explore.yaw_for(b))
				- Explore.yaw_for(a)))
	check(värst <= PI + 0.001, "ingen sväng tar mer än ett halvt varv", "%.2f rad" % värst)

	print("")
	print("— bossens byte (M45): tre kort, och valet hamnar i den permanenta samlingen —")
	# En körning MED meta, så att bossvalen kan skrivas ner. Provet svarar på valen själv (autospelaren
	# lämnar dem köade) och jämför samlingen mot de val som FAKTISKT var bossval — inte mot en gissning.
	const SAMLING := "user://test_boss_samling.json"
	if FileAccess.file_exists(SAMLING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAMLING))
	var mt := Meta.load_or_new(SAMLING)
	check(mt.samling.is_empty(), "en ny spelare har en tom samling")
	var rb := _new_run(stage, bestiary, deck, 20260921, db, mt)
	rb.play_out()
	var bossval: Array = []
	var vanliga := 0
	for e in rb.events:
		if e.type == "boss_reward":
			bossval.append(e)
		elif e.type == "level_up":
			vanliga += 1
	check(not bossval.is_empty(), "bossen ger ett byte", "%d byten" % bossval.size())
	check(vanliga > 0, "nivåuppgångarna finns kvar som egna val", "%d st" % vanliga)
	var tre := true
	for e in bossval:
		if (e.choices as Array).size() != 3:
			tre = false
	check(tre, "varje byte har tre kort att välja mellan")

	# Svara på varje val i tur och ordning (pick_card tar alltid det första i kön) och håll reda på
	# vilka svar som hörde till en boss.
	var förväntad: Array = []
	var varv := 0
	while not rb.drafts.is_empty() and varv < 60:
		varv += 1
		var d: Dictionary = rb.drafts[0]
		var valt := ""
		for kandidat in d.choices:
			if rb.pick_card(str(kandidat)):
				valt = str(kandidat)
				break
		if valt.is_empty():
			break                       # uppgraderingens delar är borta: valet går inte att göra
		if bool(d.get("boss", false)):
			förväntad.append(valt)
	check(förväntad.size() == bossval.size(), "varje byte besvarades",
		"%d av %d" % [förväntad.size(), bossval.size()])
	check(mt.samling == förväntad, "bossvalen hamnade i den permanenta samlingen",
		"%s mot %s" % [str(mt.samling), str(förväntad)])
	# Tur och retur över sparfilen: samlingen är det som gör korten tillgängliga mellan banor.
	mt.save(SAMLING)
	var läst := Meta.load_or_new(SAMLING)
	check(läst.samling == mt.samling, "samlingen överlevde sparfilen", str(läst.samling))
	# Och bara bossvalen: en vanlig nivåuppgång får inte hamna i samlingen.
	var efter_vanlig := mt.samling.size()
	var d2: Dictionary = {"level": 3, "choices": [str(db.keys()[0])]}
	rb.drafts.append(d2)
	rb.pick_card(str((d2.choices as Array)[0]))
	check(mt.samling.size() == efter_vanlig, "en vanlig nivåuppgång hamnar inte i samlingen",
		"%d -> %d" % [efter_vanlig, mt.samling.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAMLING))

	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

## Noden på en ruta i den våning körningen står på.
func _node_at(r: Run, pos: Vector2i) -> Dungeon.FloorNode:
	for n in r.explore.floor_ref.nodes:
		if n.pos == pos:
			return n
	return null

func _boss_fights(events: Array) -> int:
	var n := 0
	for e in events:
		if e.type == "combat_start" and e.get("boss", false):
			n += 1
	return n

## TRÄDET IN I KÖRNINGEN (M44): en permanent uppgradering är bara permanent om körningens SIFFROR
## följer den. Metan som summerar `stat()` är halva beviset — här mäts talen körningen startar med,
## samma tal som HUD:en visar. Provet bygger två körningar med samma meta, före och efter köpen.
func _tree_in_run(stage: Stages.StageDef, bestiary: Dictionary, db: Dictionary, deck: Array) -> void:
	print("— trädet in i körningen —")
	var m := Meta.new()
	m._load_defs()
	var ren := Run.new(stage, bestiary, deck, 7, db, m)
	var bas_hp := ren.max_hp
	var bas_mana := ren.base_mana
	var bas_hand := ren.base_hand
	m.gold = 60000
	# REGELN (Alex, M88): en nod öppnas först när föräldern är FULLT uppgraderad. Provet köpte förut
	# varje nod en gång och väntade sig barnet på det — den gamla regeln, som `requires_met` inte
	# längre följer. `maxa` köper en nod till dess högsta rang, så provet beskriver den regel som
	# gäller. Alla tre träden maxas för att barnen ska öppnas av riktiga skäl, inte av tur.
	var maxa := func(id: String) -> void:
		while m.buy(id).ok:
			pass
	for id in ["body_1", "wick_1", "iron_1"]:
		maxa.call(id)
	check(m.buy("iron_2").ok, "nästa järnnod går att köpa när järnvägen är full")
	maxa.call("iron_2")
	maxa.call("wick_2")
	check(m.buy("wick_3").ok, "och fullt bloss ovanpå den (båda kraven fulla)")
	var med := Run.new(stage, bestiary, deck, 7, db, m)
	# Siffrorna hämtas ur metan själv — samma källa som spelet läser. Det som ska hållas är LÄNKEN
	# meta -> körning, inte ett handskrivet tal som råkade stämma när provet skrevs.
	check(med.max_hp == bas_hp + m.stat("max_hp"), "max-HP följer Tjockt skinn",
		"%.0f -> %.0f" % [bas_hp, med.max_hp])
	check(med.base_mana == bas_mana + int(m.stat("mana")), "manan följer trädet",
		"%d -> %d" % [bas_mana, med.base_mana])
	check(med.base_hand == bas_hand + int(m.stat("hand")), "handen följer trädet",
		"%d -> %d" % [bas_hand, med.base_hand])
	# Skadan ligger i striden (combat.might = meta.stat("might")), så den mäts på metan: båda
	# järnnoderna ska ha bidragit, och ingen av dem är köpt en enda gång.
	check(m.stat("might") > 0.0 and m.rank("iron_1") == 3 and m.rank("iron_2") > 0,
		"och skadan följer båda järnnoderna",
		"%.2f" % m.stat("might"))

## Testet prövar MASKINERIET, inte balansen: spelaren kör som en sen-game-karaktär, så att hela
## banan hinner köras. Balanssiffrorna kalibreras mot referensens dumpar (se PLAN.md).
func _new_run(stage: Stages.StageDef, bestiary: Dictionary, deck: Array, seed_value: int,
		card_db: Dictionary = {}, p_meta: Meta = null) -> Run:
	var r := Run.new(stage, bestiary, deck, seed_value, card_db, p_meta)
	r.hp = 400.0
	r.max_hp = 400.0
	r.recovery = 25.0
	r.base_mana = 5
	r.base_hand = 5
	return r
