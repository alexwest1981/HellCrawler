## Metan: uppgraderingar, guld och sparfilen. Sparfilen är den enda platsen i spelet där en bugg
## kan förstöra något för spelaren (framsteg), så den provas hårdare än resten: tur och retur,
## trasig fil, för ny fil, handredigerad rang.
##   godot --headless --script res://tests/test_meta.gd
extends SceneTree

const TEST_PATH := "user://test_save.json"
const TEST_BROKEN := "user://test_save.json.trasig"

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_BROKEN]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _initialize() -> void:
	_clean()

	print("— en ny spelare —")
	var m := Meta.load_or_new(TEST_PATH)
	check(m.defs.size() >= 6, "uppgraderingarna lästes ur data", "%d st" % m.defs.size())
	check(m.gold == 0 and m.ranks.is_empty(), "ny spelare har inget guld och inga ranger")
	check(m.last_error.is_empty(), "ingen feltext för en saknad fil (det är normalt)", m.last_error)

	print("")
	print("— köp —")
	var utan := m.buy("might")
	check(not utan.ok and utan.reason == "for_lite_guld", "utan guld blir det inget köp", utan.reason)
	m.add_gold(250)
	var kop := m.buy("might")
	check(kop.ok and m.gold == 0 and m.rank("might") == 1, "250 guld ger första rangen",
		"guld %d, rang %d" % [m.gold, m.rank("might")])
	check(absf(m.stat("might") - 0.10) < 0.0001, "rangen blir en stat", "%.2f" % m.stat("might"))
	m.add_gold(10000)
	for i in 10:
		m.buy("might")
	check(m.is_maxed("might") and m.rank("might") == 5, "rangen stannar på taket",
		"rang %d av 5" % m.rank("might"))
	check(m.next_cost("might") == -1, "en full uppgradering har inget pris")
	check(m.can_buy("might").reason == "full", "och går inte att köpa", m.can_buy("might").reason)
	check(absf(m.stat("might") - 0.50) < 0.0001, "fem ranger är +50 %", "%.2f" % m.stat("might"))
	check(m.buy("finns_inte").reason == "okand", "okänt id avvisas", m.buy("finns_inte").reason)

	print("")
	print("— tur och retur över sparfilen —")
	m.add_gold(777)
	m.ranks["cooldown"] = 2
	m.add_souls(9)
	var skrev := m.save(TEST_PATH)
	check(skrev, "filen skrevs", m.last_error)
	var igen := Meta.load_or_new(TEST_PATH)
	check(igen.gold == m.gold, "guldet överlevde", "%d -> %d" % [m.gold, igen.gold])
	check(igen.ranks == m.ranks, "rangerna överlevde", str(igen.ranks))
	# CS är trädets valuta och måste överleva en omstart som guldet: den som tjänat ihop till en
	# permanent nod ska inte hitta fickan tom nästa gång.
	check(igen.souls == 9, "CS överlevde omstarten", "%d -> %d" % [m.souls, igen.souls])
	check(igen.last_error.is_empty(), "ingen feltext vid en frisk fil", igen.last_error)

	print("")
	print("— en trasig fil får inte kosta spelaren framstegen —")
	_write(TEST_PATH, "{trasigt json utan slut}")
	var trasig := Meta.load_or_new(TEST_PATH)
	check(not trasig.last_error.is_empty(), "felet rapporteras i klartext", trasig.last_error)
	check(FileAccess.file_exists(TEST_BROKEN), "den trasiga filen lades åt sidan, inte bort")

	print("")
	print("— en nyare sparfil rörs inte —")
	_write(TEST_PATH, JSON.stringify({"save_version": 99, "gold": 5000, "ranks": {"might": 5}}))
	var nyare := Meta.load_or_new(TEST_PATH)
	check(nyare.last_error.contains("99"), "versionen nämns i skälet", nyare.last_error)
	check(nyare.gold == 0, "inget lästes ur den nyare filen", "guld %d" % nyare.gold)
	check(FileAccess.file_exists(TEST_PATH), "filen ligger kvar orörd")

	print("")
	print("— den permanenta kortsamlingen (M45) —")
	var m2 := Meta.load_or_new(TEST_PATH)
	check(m2.samling.is_empty(), "en ny spelare har en tom samling")
	m2.samla("lachrymose_bell")
	m2.samla("lachrymose_bell")       # dubbletter är två exemplar, inte ett fel
	m2.samla("")
	check(m2.samling.size() == 2, "två exemplar av samma kort, och ett tomt id avvisas",
		str(m2.samling))
	m2.save(TEST_PATH)
	var m3 := Meta.load_or_new(TEST_PATH)
	check(m3.samling == m2.samling, "samlingen överlevde sparfilen", str(m3.samling))
	# Kopian mäts genom att MUTERA den: två listor med samma innehåll är lika i GDScript, så en
	# jämförelse säger ingenting om den ena är den andras kopia.
	var kopia: Array = m3.samlade_kort()
	kopia.append("spöke")
	check(m3.samling.size() == 2, "samlade_kort ger en KOPIA (metat kan inte muteras utifrån)",
		str(m3.samling))
	# En version 3-fil (skriven innan samlingen fanns) ska läsas utan att något går sönder: en tom
	# samling är samma sak som en ny spelares, och guldet och rangerna ska vara kvar.
	_write(TEST_PATH, JSON.stringify({"save_version": 3, "gold": 321, "ranks": {"might": 1},
		"unlocked": ["stage_01"], "hired": ["wander"]}))
	var v3 := Meta.load_or_new(TEST_PATH)
	check(v3.last_error.is_empty(), "en version 3-fil läses utan fel", v3.last_error)
	check(v3.gold == 321 and v3.rank("might") == 1, "guldet och rangerna är kvar",
		"%d guld, rang %d" % [v3.gold, v3.rank("might")])
	check(v3.samling.is_empty() and v3.hired == ["wander"],
		"och samlingen är tom medan kamraten är kvar", str(v3.samling))

	print("")
	print("— en handredigerad rang klipps mot taket —")
	_write(TEST_PATH, JSON.stringify({"save_version": 1, "gold": 10, "ranks": {"might": 99}}))
	var fusk := Meta.load_or_new(TEST_PATH)
	check(fusk.rank("might") == 5, "rang 99 blir 5", "rang %d" % fusk.rank("might"))

	print("")
	print("— metan når striden —")
	var db := Cards.load_all()
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var deck := Cards.make_pile(db, ["lash", "lash", "dagger", "dagger", "axe", "axe"])
	var stage: Stages.StageDef = stages["stage_01"]
	var utan_meta := Run.new(stage, bestiary, deck, 4242, db)
	var med := Meta.load_or_new(TEST_PATH)
	med.ranks["cooldown"] = 2
	med.ranks["speed"] = 2
	med.ranks["might"] = 5
	med.ranks["hollow_heart"] = 3
	var med_meta := Run.new(stage, bestiary, deck, 4242, db, med)
	check(med_meta.max_hp == utan_meta.max_hp + 30.0, "+3 Hollow Heart ger 30 mer max-HP",
		"%.0f mot %.0f" % [med_meta.max_hp, utan_meta.max_hp])
	check(med_meta.base_mana == utan_meta.base_mana + 2, "+2 Cooldown ger 2 mer mana",
		"%d mot %d" % [med_meta.base_mana, utan_meta.base_mana])
	check(med_meta.base_hand == utan_meta.base_hand + 2, "+2 Speed ger 2 kort mer på handen",
		"%d mot %d" % [med_meta.base_hand, utan_meta.base_hand])
	var n1 := utan_meta._next_objective()
	var n2 := med_meta._next_objective()
	var c1 := utan_meta.enter_node(n1)
	var c2 := med_meta.enter_node(n2)
	check(c1 != null and c2 != null, "båda körningarna kom in i en strid")
	if c1 != null and c2 != null:
		check(c2.might > c1.might, "musten når striden", "%.2f mot %.2f" % [c2.might, c1.might])
		check(c2.mana == c1.mana + 2, "manan når striden", "%d mot %d" % [c2.mana, c1.mana])
		check(c2.hand.size() == c1.hand.size() + 2, "handen är större",
			"%d mot %d" % [c2.hand.size(), c1.hand.size()])
		check(c2.max_hp == c1.max_hp + 30.0, "max-HP når striden",
			"%.0f mot %.0f" % [c2.max_hp, c1.max_hp])

	print("")
	print("— förbannelsen: tåligare fiender, rikare byte —")
	var förbannad := Meta.load_or_new(TEST_PATH)
	förbannad.ranks["curse"] = 5
	var r_utan := Run.new(stage, bestiary, deck, 7, db)
	var r_med := Run.new(stage, bestiary, deck, 7, db, förbannad)
	var fo_utan: Combat.Enemy = r_utan.enter_node(r_utan._next_objective()).enemies[0]
	var fo_med: Combat.Enemy = r_med.enter_node(r_med._next_objective()).enemies[0]
	check(fo_med.max_hp > fo_utan.max_hp, "förbannelsen gör fienden tåligare",
		"%.0f mot %.0f" % [fo_med.max_hp, fo_utan.max_hp])
	check(r_med.gold_bonus() > r_utan.gold_bonus(), "och guldet rikare",
		"%.2f mot %.2f" % [r_med.gold_bonus(), r_utan.gold_bonus()])

	print("")
	print("— upplåsningen —")
	# Byns karta: en ny spelare har EN bana, och nästa bana låses upp när man når sista våningen.
	# Regeln är att NÅ sista våningen räknas som klarat (referensens Red Death dödar dig där).
	_clean()
	var order := ["stage_01", "stage_02", "stage_03"]
	var spel := Meta.load_or_new(TEST_PATH)
	check(spel.unlocked == ["stage_01"], "ny spelare har bara första banan",
		str(spel.unlocked))
	check(spel.is_unlocked("stage_01"), "första banan är öppen")
	check(not spel.is_unlocked("stage_02"), "andra banan är låst")

	var ny := spel.note_run("stage_01", 1, 3, order)
	check(ny.is_empty(), "dog man på våning 1 låses inget upp", "fick '%s'" % ny)
	check(spel.runs == 1, "körningen räknades", "runs %d" % spel.runs)
	check(int(spel.best_floor.get("stage_01", 0)) == 1, "bästa våningen skrevs ner",
		"våning %d" % int(spel.best_floor.get("stage_01", 0)))

	ny = spel.note_run("stage_01", 3, 3, order)
	check(ny == "stage_02", "nådde man sista våningen öppnas nästa bana", "fick '%s'" % ny)
	check(spel.is_unlocked("stage_02"), "och den är öppen efteråt")
	check(int(spel.best_floor.get("stage_01", 0)) == 3, "bästa våningen uppdaterades",
		"våning %d" % int(spel.best_floor.get("stage_01", 0)))
	check(spel.note_run("stage_01", 3, 3, order).is_empty(),
		"samma bana två gånger låser inte upp något igen")

	# Tur och retur: upplåsningen är framsteg, och den ska överleva en omstart av spelet.
	spel.add_gold(120)
	check(spel.save(TEST_PATH), "sparfilen skrivs")
	var spel2 := Meta.load_or_new(TEST_PATH)
	check(spel2.gold == 120, "guldet överlevde", "%d guld" % spel2.gold)
	check(spel2.unlocked.has("stage_02"), "upplåsningen överlevde", str(spel2.unlocked))
	check(int(spel2.best_floor.get("stage_01", 0)) == 3, "bästa våningen överlevde")
	check(spel2.runs == 3, "körningarna räknades med", "runs %d" % spel2.runs)

	# En version 1-fil (före upplåsningen) har guld och ranger men ingen bana: den ska behålla
	# guldet och börja med första banan öppen, inte tappa allt eller gissa.
	_clean()
	_write(TEST_PATH, '{"save_version": 1, "gold": 900, "ranks": {"might": 2}, "language": "en"}')
	var gammal := Meta.load_or_new(TEST_PATH)
	check(gammal.gold == 900, "gammal sparfil behåller guldet", "%d guld" % gammal.gold)
	check(gammal.rank("might") == 2, "och sina ranger", "might %d" % gammal.rank("might"))
	check(gammal.unlocked == ["stage_01"], "och får första banan öppen", str(gammal.unlocked))
	check(gammal.last_error.is_empty(), "utan att klaga", gammal.last_error)

	print("")
	_tree_checks()
	_crawler_checks()
	_box_checks()
	_uppdrag_checks()
	_steg_checks()
	_vad_checks()
	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

## Trädet: smedens nodnät. Små steg med stigande pris, och förkunskaper som säger av VAD en nod är
## låst. Egen funktion av samma skäl som kamraterna: namnen krockar annars med kurvorna ovanför.
func _tree_checks() -> void:
	print("— trädet —")
	var mt := Meta.load_or_new(TEST_PATH + ".trad")
	check(mt.branches().size() == 3, "trädet har tre grenar, som plattan", str(mt.branches()))
	var järn := mt.tree_lines("Järnvägen")
	check(järn.size() >= 3, "Järnvägen har noder", "%d st" % järn.size())
	check(mt.village_lines().size() == 8, "butiken visar bara de åtta basuppgraderingarna",
		"%d rader" % mt.village_lines().size())
	check(bool(järn[1]["låst"]), "andra noden är låst innan den första är köpt",
		"krav: %s" % järn[1]["krav"])
	var spärr := mt.buy("iron_2")
	check(not spärr.ok and spärr.reason == "kraver", "och går inte att köpa förbi",
		"%s (%s)" % [spärr.reason, spärr.get("krav", "")])

	mt.add_souls(1000)
	# GRENENS HUVUDNOD FÖRST (M95): varje gren har en huvudnod som öppnar grenen, och de tjugo
	# undernoderna hänger på den. Utan den är varje undernod låst — det är trädets form, inte ett fel.
	check(mt.buy("iron_main").ok, "grenens huvudnod går att köpa först")
	var cs_pris := mt.next_soul_cost("iron_1")
	var skada_före: float = mt.stat("might")
	check(mt.buy("iron_1").ok, "sedan går första undernoden att köpa")
	check(mt.rank("iron_1") == 1, "och får rang 1", "%d" % mt.rank("iron_1"))
	check(is_equal_approx(mt.stat("might") - skada_före, 0.02), "noden höjer skadan med sitt lilla steg",
		"%.3f" % (mt.stat("might") - skada_före))
	# TRÄDET KOSTAR CS (M95): guld räcker inte, hur mycket man än har.
	check(mt.souls == 1000 - 40 - cs_pris, "CS-priset drogs (huvudnoden 40 + nodens eget)",
		"%d CS (pris %d)" % [mt.souls, cs_pris])
	check(mt.gold == 0, "och guldet stod orört", "%d guld" % mt.gold)
	# REGELN (Alex): nästa nod öppnas först när noden innan är FULLT uppgraderad. Att den är köpt en
	# gång räcker inte — det var den gamla regeln, och det här paret provar att den är borta.
	# REGELN (Alex): en nod öppnas först när noden innan är FULLT uppgraderad. Trädets noder har en
	# rang var (ett köp = full), så låsningen mäts som den faktiskt beter sig: syskonet till en köpt
	# nod är öppet, barnet till en OKÖPT nod är låst.
	check(not mt.requires_met("iron_4"), "barnet till en oköpt nod är låst")
	check(mt.requires_met("iron_2"), "men huvudnodens båda barn är öppna när den är köpt")
	# Rangen får inte gå förbi taket: taket läses ur datat, inte ur provet.
	var tak: int = int(mt.def_for("might").get("max_rank", 1))
	mt.add_gold(5000)
	for i in tak + 2:
		mt.buy("might")
	check(mt.rank("might") == tak, "rangen stannar vid taket", "%d av %d" % [mt.rank("might"), tak])
	check(not mt.buy("might").ok, "och en full nod kan inte köpas igen", mt.buy("might").reason)

## Kamraterna: hyrda hjältar som egna kort i leken. Egen funktion för att hålla nöjet åtskilt
## från sparfilens egna prov — och för att variabelnamnen inte ska krocka med kurvorna ovanför.
func _crawler_checks() -> void:
		print("— kamraterna —")
		# En kamrat är ett KORT i leken plus en passiv verkan, och passiven gäller varje tur så länge
		# kortet finns i leken. Provet mäter två körningar som skiljer sig i EXAKT en hyrd kamrat.
		_clean()
		var m3 := Meta.load_or_new(TEST_PATH)
		check(m3.crawler_lines().size() >= 6, "kamraterna laddar ur data",
			"%d st" % m3.crawler_lines().size())
		check(not m3.can_hire("ashhound").ok, "utan guld går ingen att hyra",
			m3.can_hire("ashhound").reason)
		check(not m3.can_hire("finns_inte").ok, "okänd kamrat nekas")
		check(is_equal_approx(m3.stat("mana"), 0.0), "ingen hyrd: ingen manabonus")

		# Priset läses ur datat, inte ur provet: en kamrat som kostar 1500 guld fick inte fälla provet
		# bara för att någon skrev in 300 här en gång. Alex ville ha dem DYRA — man ska inte kunna
		# köpa alla snabbt — så provet mäter att de ligger över butikens småsaker, inte exakta tal.
		var pris := 0
		for rad in m3.crawler_lines():
			if str(rad["id"]) == "ashhound":
				pris = int(rad["price"])
		check(pris >= 1000, "kamraterna är dyra", "%d guld för den billigaste" % pris)
		m3.add_gold(pris)
		var hyr := m3.hire("ashhound")
		check(hyr.ok, "med guld går den att hyra", str(hyr))
		check(m3.gold == 0, "guldet drogs", "%d guld" % m3.gold)
		check(m3.is_hired("ashhound"), "och den är hyrd")
		check(m3.hire("ashhound").reason == "redan_hyrd", "samma kamrat kan inte hyras två gånger")
		check(is_equal_approx(m3.stat("mana"), 1.0), "den hyrda ger +1 mana", "%.1f" % m3.stat("mana"))

		# Mätt i spelet, inte bara i metan: körningen ska få bonusen, och leken ska innehålla kortet.
		var slog: Stages.StageDef = Stages.load_all()["stage_01"]
		var best: Dictionary = Enemies.load_all()
		var kortdb := Cards.load_all()
		check(kortdb.has("ashhound"), "kamratens kort finns i kortdatan")
		# "Mer avancerade fördelar": en kamrat ska ge TVÅ saker i passiven och TVÅ i sitt kort.
		# Annars är den bara ännu en nivå i smedens träd till ett högre pris. Mätt ur datat, så en
		# ny kamrat som läggs in tunn fälls av provet i stället för av Alex på värdshuset.
		var tunna := []
		for c in m3.crawlers:
			var cid := str(c.get("id", ""))
			if (c.get("passiv", {}) as Dictionary).size() < 2:
				tunna.append("%s: passiven" % cid)
			if not kortdb.has(cid) or (kortdb[cid] as Cards.Card).effects.size() < 2:
				tunna.append("%s: kortet" % cid)
		check(tunna.is_empty(), "alla kamrater ger två saker i passiven och två i kortet",
			", ".join(tunna))
		var tom_meta := Meta.load_or_new(TEST_PATH + ".tom")
		tom_meta.gold = 0
		var r_utan := Run.new(slog, best, Cards.make_pile(kortdb, ["lash"]), 5, kortdb, tom_meta)
		var r_med := Run.new(slog, best, Cards.make_pile(kortdb, ["lash", "ashhound"]), 5, kortdb, m3)
		check(r_med.base_mana == r_utan.base_mana + 1, "den hyrda höjer manan i körningen",
			"%d mot %d" % [r_med.base_mana, r_utan.base_mana])
		check(is_equal_approx(r_med.max_hp, r_utan.max_hp), "och rör inget annat än sin egen stat",
			"%.0f mot %.0f" % [r_med.max_hp, r_utan.max_hp])

		check(m3.save(TEST_PATH), "sparfilen skrivs med kamraterna")
		var m4 := Meta.load_or_new(TEST_PATH)
		check(m4.hired == ["ashhound"], "hyrd kamrat överlevde", str(m4.hired))
		check(is_equal_approx(m4.stat("mana"), 1.0), "och bonusen räknas efter omstart")

## Belöningen efter körningen (önskemål 24): utbetalningen, oddsen, garantin och utbetalningen av ett
## val. Egen funktion av samma skäl som trädet och kamraterna: namnen krockar annars med kurvorna ovan.
func _box_checks() -> void:
	print("")
	print("— belöningen efter körningen (önskemål 24) —")
	var m := Meta.load_or_new(TEST_PATH + ".box")
	m.gold = 0
	m.shards = 0
	m.samling = []
	m.hired = []
	m.boxar_utan_stor = 0
	# UTBETALNINGEN är deterministisk: djup och dråp, ingenting annat.
	var ytan := m.run_payout(1, 0)
	var djupet := m.run_payout(6, 0)
	var med_drap := m.run_payout(1, 10)
	check(int(djupet["gold"]) > int(ytan["gold"]), "djupet betalar mer än ytan",
		"%d mot %d guld" % [int(djupet["gold"]), int(ytan["gold"])])
	check(int(med_drap["gold"]) > int(ytan["gold"]), "och dråpen räknas med",
		"%d mot %d guld" % [int(med_drap["gold"]), int(ytan["gold"])])
	check(int(djupet["shards"]) > int(ytan["shards"]), "splitter följer också djupet",
		"%d mot %d" % [int(djupet["shards"]), int(ytan["shards"])])
	# Andelen vid död (punkt 9): en död körning behåller sin del, en som nådde sista våningen allt.
	check(is_equal_approx(Meta.share_of_outcome("dead"), Meta.DEATH_SHARE),
		"en död körning behåller sin andel", "%.2f" % Meta.share_of_outcome("dead"))
	check(is_equal_approx(Meta.share_of_outcome("cleared"), 1.0), "en klarad bana behåller allt")
	check(is_equal_approx(Meta.share_of_outcome("reaped"), 1.0),
		"och en skördad på sista våningen räknas som klarad")
	# ODDSEN: summan ska vara hundra i varje band, annars ljuger raden spelaren ser.
	var summor := []
	var summa_ok := true
	for vaning in [1, 3, 6, 9, 12]:
		var summa := 0
		for k in m.box_odds(vaning):
			summa += int(m.box_odds(vaning)[k])
		summor.append(summa)
		if summa != 100:
			summa_ok = false
	check(summa_ok, "oddsen summerar till hundra i varje djupband", str(summor))
	check(int(m.box_odds(12)["card"]) > int(m.box_odds(1)["card"]),
		"och den stora vinsten blir vanligare med djupet",
		"kort %d %% mot %d %%" % [int(m.box_odds(12)["card"]), int(m.box_odds(1)["card"])])
	# BOXEN: tre OLIKA val varje gång, och garantin tvingar fram en stor vinst.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	var db := Cards.load_all()
	var olika := true
	for i in 40:
		var val := m.roll_box(3, rng, db)
		if val.size() != 3:
			olika = false
			break
		var a := str(val[0].get("kind", ""))
		var b := str(val[1].get("kind", ""))
		var c := str(val[2].get("kind", ""))
		if a == b or b == c or a == c:
			olika = false
			break
	check(olika, "fyrtio boxar i rad ger tre olika val varje gång")
	m.boxar_utan_stor = 0
	var stor_pa := -1
	for i in Meta.BOX_GUARANTEE + 2:
		var val2 := m.roll_box(6, rng, db)
		for v in val2:
			if ["card", "companion"].has(str(v.get("kind", ""))) and stor_pa < 0:
				stor_pa = i + 1
	check(stor_pa > 0 and stor_pa <= Meta.BOX_GUARANTEE + 2,
		"garantin ger en stor vinst inom %d boxar" % (Meta.BOX_GUARANTEE + 2),
		"första stora på box %d" % stor_pa)
	# Och den TVINGAR: med räknaren på gränsen MÅSTE nästa box bjuda en stor vinst, inte "kan".
	m.boxar_utan_stor = Meta.BOX_GUARANTEE
	var tvang := m.roll_box(6, rng, db)
	var tvang_stor := false
	for v in tvang:
		if ["card", "companion"].has(str(v.get("kind", ""))):
			tvang_stor = true
	check(tvang_stor, "en box med räknaren på %d bjuder alltid en stor vinst" % Meta.BOX_GUARANTEE,
		str(tvang))
	check(m.boxar_utan_stor == 0, "och den stora vinsten nollställer räknaren",
		str(m.boxar_utan_stor))
	# UTBETALNINGEN av ett val: varje slag hamnar i rätt bestånd.
	var guld_fore := m.gold
	m.box_pay({"kind": "gold", "amount": 120})
	check(m.gold == guld_fore + 120, "guldvalet betalas ut", "%d guld" % m.gold)
	var splitter_fore := m.shards
	m.box_pay({"kind": "shards", "amount": 4})
	check(m.shards == splitter_fore + 4, "splittervalet betalas ut", "%d splitter" % m.shards)
	var fam := str(m.gem_defs[0].get("id", "")) if not m.gem_defs.is_empty() else ""
	if fam.is_empty():
		check(false, "ädelstensdatan gick att läsa")
	else:
		m.box_pay({"kind": "gem", "fam": fam, "grad": 3})
		var rad: Array = m.gems.get(fam, [])
		check(rad.size() > 3 and int(rad[3]) == 1,
			"stenvalet hamnar i fickan på rätt grad", "%s %s" % [fam, str(rad)])
	var kortid := ""
	for id in db:
		if (db[id] as Cards.Card).card_type != "crawler":
			kortid = str(id)
			break
	if kortid.is_empty():
		check(false, "kortleken hade ett kort att ge")
	else:
		m.box_pay({"kind": "card", "id": kortid})
		check(m.samling.has(kortid), "kortvalet hamnar i samlingen", kortid)
	var kamrat := str(m.crawlers[0].get("id", "")) if not m.crawlers.is_empty() else ""
	if kamrat.is_empty():
		check(false, "kamratdatan gick att läsa")
	else:
		m.box_pay({"kind": "companion", "id": kamrat})
		check(m.hired.has(kamrat), "kamratvalet blir hyrd", kamrat)
	# Garantiräknaren bor i sparfilen: den ska överleva en omstart.
	m.boxar_utan_stor = 7
	check(m.save(TEST_PATH), "sparfilen skrivs med boxräknaren")
	var m2 := Meta.load_or_new(TEST_PATH)
	check(m2.boxar_utan_stor == 7, "och räknaren överlevde omstarten", str(m2.boxar_utan_stor))


## Efterlysningarna (önskemål 24, punkt 3): räknarna summeras över körningar, och ett mål brister ut
## EXAKT en gång — även efter en omstart av spelet, för annars kunde samma mål betalas varje gång.
func _uppdrag_checks() -> void:
	print("")
	print("— efterlysningarna över flera körningar (önskemål 24, punkt 3) —")
	var m := Meta.load_or_new(TEST_PATH + ".uppdrag")
	m.gold = 0
	m.shards = 0
	m.runs = 0
	m.kills_total = 0
	m.floors_total = 0
	m.uppdrag_kvitterade = []
	m.hired = []
	var order := ["stage_01", "stage_02"]
	m.note_run("stage_01", 3, 5, order, 20)
	m.note_run("stage_01", 4, 5, order, 35)
	check(m.kills_total == 55, "dråpen summeras över körningar", str(m.kills_total))
	check(m.floors_total == 7, "och våningarna likaså", str(m.floors_total))
	check(m.runs == 2, "körningarna räknas", str(m.runs))
	var prog := m.contract_progress()
	check(prog.size() == Meta.CONTRACTS.size(), "varje mål har ett nuläge", "%d mål" % prog.size())
	var nasta := m.contract_next()
	check(not nasta.is_empty() and str(nasta["id"]) == "drap_50",
		"det närmaste målet är det längst hunna", str(nasta.get("id", "")))
	# 50 av 50 dråp: målet brister ut, betalas, och kan inte betalas igen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var guld_fore := m.gold
	var rader := m.contracts_claim(rng)
	check(rader.size() == 1, "ett mål brast ut", str(rader))
	check(m.gold == guld_fore + 150, "och dess guld betalades", "%d -> %d" % [guld_fore, m.gold])
	check(m.uppdrag_kvitterade.has("drap_50"), "målet är kvitterat", str(m.uppdrag_kvitterade))
	check(m.contracts_claim(rng).is_empty(), "och det betalas inte ut igen")
	check(m.gold == guld_fore + 150, "guldet står still vid ett andra försök", "%d guld" % m.gold)
	check(m.save(TEST_PATH), "sparfilen skrivs med efterlysningarna")
	var m2 := Meta.load_or_new(TEST_PATH)
	check(m2.kills_total == 55 and m2.floors_total == 7, "räknarna överlevde omstarten",
		"%d dråp, %d våningar" % [m2.kills_total, m2.floors_total])
	check(m2.uppdrag_kvitterade.has("drap_50"), "och kvitteringen likaså", str(m2.uppdrag_kvitterade))
	check(m2.contracts_claim(rng).is_empty(), "så ett kvitterat mål betalas inte ut efter en omstart")
	# Kamratmålet (60 våningar) ger en kamrat som ännu inte är hyrd, och flera mål kan brista på en gång.
	m2.floors_total = 60
	m2.uppdrag_kvitterade = []
	var kamrat_fore := m2.hired.size()
	var rader2 := m2.contracts_claim(rng)
	check(m2.hired.size() > kamrat_fore, "våningmålet ger en kamrat", str(m2.hired))
	check(rader2.size() >= 2, "och flera mål kan brista i samma körning", str(rader2))

## Svårighetstrappan (önskemål 24, punkt 4): valet kläms mot det upplåsta, klarat på sitt HÖGSTA steg
## öppnar nästa, och utbetalningen läser samma tal som kartans rad visar.
func _steg_checks() -> void:
	print("")
	print("— svårighetstrappan (önskemål 24, punkt 4) —")
	var m := Meta.load_or_new(TEST_PATH + ".steg")
	m.runs = 0
	m.kills_total = 0
	m.floors_total = 0
	m.steg_max = {}
	m.steg_valt = {}
	var order := ["stage_01", "stage_02"]
	check(m.steg_max_för("stage_01") == 0, "en ospelad bana har bara grundsteget")
	m.steg_sätt("stage_01", 5)
	check(m.steg_valt_för("stage_01") == 0, "och valet kläms mot det upplåsta",
		"valde %d" % m.steg_valt_för("stage_01"))
	check(m.steg_fiende_faktor("stage_01") == 1.0 and m.steg_guld_faktor("stage_01") == 1.0,
		"steg 0 rör varken fiender eller guld")
	# Klarat på sista våningen: nästa steg öppnas.
	m.note_run("stage_01", 3, 3, order, 0)
	check(m.steg_upplast == 1 and m.steg_upplast_bana == "stage_01",
		"klarat på högsta steget öppnar nästa", "steg %d" % m.steg_upplast)
	check(m.steg_max_för("stage_01") == 1, "och taket står på 1", str(m.steg_max_för("stage_01")))
	# Att DÖ på ett högre steg öppnar ingenting: trappan reses genom att klara, inte genom att försöka.
	m.steg_sätt("stage_01", 1)
	m.note_run("stage_01", 1, 3, order, 0)
	check(m.steg_upplast == 0 and m.steg_max_för("stage_01") == 1,
		"en död körning öppnar inget nytt steg", str(m.steg_max_för("stage_01")))
	# Klarat på steg 0 medan taket står på 1: ingen gratis upplåsning (valet läses, inte taket).
	m.steg_sätt("stage_01", 0)
	m.note_run("stage_01", 3, 3, order, 0)
	check(m.steg_upplast == 0, "och steg 0 öppnar inte nästa steg gratis",
		"tak %d" % m.steg_max_för("stage_01"))
	# Faktorerna: samma tal som kartans rad räknar ur.
	m.steg_sätt("stage_01", 1)
	check(is_equal_approx(m.steg_fiende_faktor("stage_01"), 1.0 + Meta.STEG_FIENDE),
		"fiendefaktorn följer steget", "%.2f" % m.steg_fiende_faktor("stage_01"))
	check(is_equal_approx(m.steg_guld_faktor("stage_01"), 1.0 + Meta.STEG_GULD),
		"och guldfaktorn likaså", "%.2f" % m.steg_guld_faktor("stage_01"))
	# Utbetalningen: en körning på ett högre steg betalar mer — samma golv, samma dråp.
	var utan := m.run_payout(3, 10)
	var med := m.run_payout(3, 10, "stage_01")
	check(int(med["gold"]) > int(utan["gold"]), "och körningen betalar mer på ett högre steg",
		"%d mot %d guld" % [int(med["gold"]), int(utan["gold"])])
	check(int(m.run_payout(3, 10, "stage_02")["gold"]) == int(utan["gold"]),
		"medan en annan banas steg inte spiller över", str(utan["gold"]))
	check(m.save(TEST_PATH), "sparfilen skrivs med trappan")
	var m2 := Meta.load_or_new(TEST_PATH)
	check(m2.steg_max_för("stage_01") == 1 and m2.steg_valt_för("stage_01") == 1,
		"taket och valet överlevde omstarten",
		"%d/%d" % [m2.steg_valt_för("stage_01"), m2.steg_max_för("stage_01")])

## Vadslagningen och de räddade själarna (önskemål 24, punkt 7 och 8): valet vrider i tre steg, insatsen
## räknas ur banken och kan aldrig bli mer än man har, och en själ som räddas är en som INTE redan är hyrd.
func _vad_checks() -> void:
	print("")
	print("— vadslagningen och de räddade själarna (önskemål 24, punkt 7 och 8) —")
	var m := Meta.load_or_new(TEST_PATH + ".vad")
	m.gold = 400
	m.vad_valt = {}
	m.hired = []
	check(m.vad_för("stage_01") == 0.0, "inget vad är inget vad")
	check(m.vad_vrid("stage_01") == 0.25, "första vridet ger en fjärdedel", str(m.vad_för("stage_01")))
	check(m.vad_vrid("stage_01") == 0.5, "andra vridet hälften", str(m.vad_för("stage_01")))
	check(m.vad_vrid("stage_01") == 0.0, "och tredje vrider tillbaka till noll", str(m.vad_för("stage_01")))
	m.vad_valt["stage_01"] = 0.25
	check(m.vad_insats("stage_01") == 100, "insatsen är en fjärdedel av banken",
		"%d guld" % m.vad_insats("stage_01"))
	m.gold = 3
	check(m.vad_insats("stage_01") == 0, "och aldrig mer än man har", "%d guld" % m.vad_insats("stage_01"))
	m.gold = 7
	check(m.vad_insats("stage_01") == 1, "avrundat nedåt", "%d guld" % m.vad_insats("stage_01"))
	m.gold = 400
	check(m.save(TEST_PATH), "sparfilen skrivs med vadet")
	var m2 := Meta.load_or_new(TEST_PATH)
	check(is_equal_approx(m2.vad_för("stage_01"), 0.25), "och valet överlevde omstarten",
		str(m2.vad_för("stage_01")))
	# Själen: en kamrat som inte redan är hyrd. Ett andra anrop får inte ge samma igen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var först := m2.radda_sjal(rng)
	check(not först.is_empty(), "en själ gick att rädda", först)
	check(m2.hired.has(först), "och hon blev hyrd", str(m2.hired))
	var andra := m2.radda_sjal(rng)
	check(andra != först, "en andra själ är en ANNAN kamrat", "%s mot %s" % [först, andra])
