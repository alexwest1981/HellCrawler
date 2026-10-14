## Balansmätaren: klarar en SLUMPMÄSSIG lek de tre första banorna?
##
## Alex (14/10): *"man kan i dagsläget klicka på tre random kort och fortfarande klara sig hela vägen
## genom 3 levels utan att anstränga sig."* Det här provet är den meningen som ett tal: samma banor och
## samma seedade lekar, men två policies — en som väljer SLUMPMÄSSIGT bland de spelbara korten, och
## spelets egen autospelare — och två lekar: spelets riktiga startlek (main.gd:s DECK, den spelaren
## faktiskt får) och tre kort dragna slumpmässigt ur databasen (den hårdare tolkningen).
##
## Grindarna går åt båda hållen med flit:
##   * slumpen får INTE klara banorna (annars finns ingen svårighet att tala om), och
##   * autospelaren SKA klara dem (annars är ändringen en vägg, inte en balans).
##
##   cd game && ../tools/ett_prov.sh tests/test_balans.gd
##   cd game && ../tools/ett_prov.sh tests/test_balans.gd -- --rattprov    # tabellen som valde ratten
extends SceneTree

## Grindarna går åt BÅDA hållen med flit:
##   * slumpen får inte vara en STRATEGI. Alex' anmälan var att den alltid klarade sig (mätt: 38 av 60,
##     63 %); gränsen står på var tionde körning — en lott, inte en väg. Noll är inte rätt krav: provet
##     spelar utan meta och utan träd, och en enstaka tursammansättning avgör en körning.
##   * den bästa policyn ska klara banorna (golv), och klara dem KLART oftare än slumpen (förhållande).
##     Golvet fångar en VÄGG: föll båda policies lika hårt vore ändringen ingen balans.
##   * och kartan ska gå att AGERA på: rutten (som går förbi de hårdaste rummen) ska slå att slåss med allt.
const ANTAL := 20                     ## körningar per bana och policy, med startleken
const ANTAL_SLUMP3 := 10              ## den hårdare tolkningen ("tre slumpkort") är dyrare per körning
const STAGE_IDS := ["stage_01", "stage_02", "stage_03"]
const SLUMP_GRANS := 6                ## så många klarade körningar får slumpen ha av 60 (var tionde)
## Autospelaren och rutten är grova heuristiker (ingen riktning av skadan, ingen försvarsprioritering,
## inga Destroy-kort), alltså en GOLV för mänskligt spel — inte ett tak.
const AUTO_ANDEL := 0.20
const AUTO_OVER_SLUMP := 3.0

var fails := 0
var checks := 0
var policy_rng: RandomNumberGenerator
var policy_damage := 0.0

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
		print("saknar kort, banor eller fiender")
		quit(1)
		return

	var ids: Array = db.keys()
	ids.sort()
	var rattprov := OS.get_cmdline_user_args().has("--rattprov")

	var referens := Run.new(stages["stage_01"], bestiary, [], 1, db)
	print("startvärden | våningar=%d | mana=%d | hand=%d | återhämtning=%.1f HP/strid | startlek=%d kort"
		% [referens.stage.floors, referens.base_mana, referens.base_hand, referens.recovery,
			startleken().size()])
	print("            | fiende-HP %+.0f%%/svårighet %+.0f%%/våning | fiende-skada %+.0f%%/svårighet %+.0f%%/våning"
		% [referens.hp_per_difficulty * 100.0, referens.hp_per_floor * 100.0,
			referens.damage_per_difficulty * 100.0, referens.damage_per_floor * 100.0])
	print("            | fiender/möte %d–%d | fiende-tier 1: HP %s"
		% [referens.enemies_per_encounter[0], referens.enemies_per_encounter[1], _tier1(bestiary)])

	print("\nbana | lek | policy | n | klarade | dog | medelvåning | förlorade strider | skada tagen | nivå (kort) | vunna strider")
	var summa := {"slump": 0, "auto": 0, "rutt": 0}
	var mojligt := ANTAL * STAGE_IDS.size()
	if rattprov:
		_rattprov(stages["stage_01"], bestiary, db, ids)
		print("kontroller: %d, fel: %d" % [checks, fails])
		quit(0)
		return
	for stage_id in STAGE_IDS:
		var stage: Stages.StageDef = stages[stage_id]
		for lek in ["startlek", "slump3"]:
			for policy in ["slump", "auto", "rutt"]:
				var n := ANTAL if lek == "startlek" else ANTAL_SLUMP3
				var total := _serie(stage, bestiary, db, ids, lek, policy, n)
				print("%s | %s | %s | %d | %.0f%% | %.0f%% | %.2f | %.2f | %.1f | %.1f | %.1f" % [
					stage_id, lek, policy, n, 100.0 * total.clear / n, 100.0 * total.dead / n,
					total.floor / n, float(total.lost) / n, total.damage / n,
					total.niva / n, total.strider / n])
				if lek == "startlek":
					summa[policy] += total.clear

	var basta: int = maxi(summa["auto"], summa["rutt"])
	check(summa["slump"] <= SLUMP_GRANS, "slumpen klarar inte de tre banorna",
		"klarade %d av %d (högst %d får klara)" % [summa["slump"], mojligt, SLUMP_GRANS])
	var basta_andel := float(basta) / mojligt
	var over_slump := basta_andel / maxf(0.01, float(summa["slump"]) / mojligt)
	check(basta_andel >= AUTO_ANDEL and over_slump >= AUTO_OVER_SLUMP,
		"att spela bättre går bättre: bästa policyn klarar fler än slumpen",
		"auto %d, rutt %d av %d (bästa %.0f %%, minst %.0f %%) = %.1f gånger slumpen (minst %.1f)"
			% [summa["auto"], summa["rutt"], mojligt, basta_andel * 100.0,
				AUTO_ANDEL * 100.0, over_slump, AUTO_OVER_SLUMP])
	check(summa["rutt"] >= summa["auto"], "kartan går att agera på: rutten slår att slåss med allt",
		"rutt %d mot auto %d av %d" % [summa["rutt"], summa["auto"], mojligt])
	if rattprov:
		_rattprov(stages["stage_01"], bestiary, db, ids)
	print("kontroller: %d, fel: %d" % [checks, fails])
	quit(1 if fails else 0)

## Spelets egen startlek, ur EN källa (`main.gd`). Provet får inte ha en egen kopia: då mäter det en
## lek som spelet slutat dela ut.
func startleken() -> Array:
	return load("res://main.gd").DECK.duplicate()

func _tier1(bestiary: Dictionary) -> String:
	var rader := []
	for e in bestiary.values():
		if int(e.tier) == 1:
			rader.append("%d HP/%d skada" % [int(e.hp), int(e.damage)])
	return ", ".join(rader)

## En serie körningar: samma frö ger samma lek, samma val och samma utfall.
func _serie(stage: Stages.StageDef, bestiary: Dictionary, db: Dictionary, ids: Array,
		lek: String, policy: String, n: int) -> Dictionary:
	var total := {"clear": 0, "dead": 0, "reaped": 0, "floor": 0.0, "lost": 0, "damage": 0.0,
		"niva": 0.0, "strider": 0.0}   ## nivå = antal kort körningen tagit (ett val per nivå), strider = vunna
	for i in n:
		var seed_value := 810000 + i * 13 + STAGE_IDS.find(stage.id) * 10000
		var val := RandomNumberGenerator.new()
		val.seed = seed_value * 31 + 7
		var kort := []
		if lek == "startlek":
			kort = startleken()      ## högen blandas i `Combat.begin` med stridens EGET frö — inte här
		else:
			for j in 3:
				kort.append(ids[val.randi_range(0, ids.size() - 1)])
		var run := Run.new(stage, bestiary, Cards.make_pile(db, kort), seed_value, db)
		run.fighter = Callable(self, "_slump_fighter" if policy == "slump" else "_auto_fighter")
		policy_rng = RandomNumberGenerator.new()
		policy_rng.seed = seed_value * 7919 + 53
		policy_damage = 0.0
		_play_nodes(run, policy)
		total.clear += int(run.outcome == "cleared" or run.outcome == "reaped")
		total.dead += int(run.outcome == "dead")
		total.reaped += int(run.outcome == "reaped")
		total.floor += run.floor_index + 1
		total.lost += run.fights_lost
		total.damage += policy_damage
		total.niva += run.level
		total.strider += run.fights_won
	return total

## Slumppolicyn: välj likformigt bland de spelbara korten, avsluta turen när inget går att spela.
## Det är "klicka på tre kort" — ingen strategi, ingen kedja, ingen hänsyn till vad som är starkt.
func _slump_fighter(combat: Combat) -> void:
	var turns := 0
	while not combat.over() and turns < Run.MAX_TURNS_PER_FIGHT:
		turns += 1
		var cards_played := 0
		while cards_played < 99:
			var playable := []
			for i in combat.hand.size():
				var card: Cards.Card = combat.hand[i]
				if card.is_wild() or card.cost <= combat.mana:
					playable.append(i)
			if playable.is_empty():
				break
			if not combat.play(playable[policy_rng.randi_range(0, playable.size() - 1)]).ok:
				break
			cards_played += 1
		if not combat.over():
			var before := combat.hp
			combat.end_turn()
			policy_damage += before - combat.hp

func _auto_fighter(combat: Combat) -> void:
	var turns := 0
	while not combat.over() and turns < Run.MAX_TURNS_PER_FIGHT:
		turns += 1
		combat.auto_play()
		if not combat.over():
			var before := combat.hp
			combat.end_turn()
			policy_damage += before - combat.hp

## Samma noder i samma ordning som `Run._next_objective()` — utan BFS-rörelsen ruta för ruta.
## Vägvalet rör inte stridsutfallet, och att räkna om vägen för varje ruta gör en serie onödigt dyr.
##
## KORTVALEN SVARAS HÄR. Nivåuppgångarna köas i `run.drafts` och besvaras i spelet av spelaren (och
## rörelsen är blockerad så länge ett val väntar). Svarar mätaren inte på dem mäter den en spelare som
## aldrig tar ett kort — och det är en annan, mycket svagare spelare än den Alex beskriver. Policyn
## svarar som sin motsvarighet: slumpen drar ett likformigt val, autospelaren tar det starkaste kortet.
##
## RUTTPOLICYN (A i docs/balans.md §8) hoppar över de HÅRDA rummen när HP:t är lågt. Kartans svårighet
## är ingen svårighet förrän den går att agera på — i en blobber går man förbi rummet med tre varelser
## och tar det lätta först. Utan en policy som får välja bort rum mäter provet bara att kurvan finns,
## inte att den är värd något.
func _play_nodes(run: Run, policy: String) -> void:
	while not run.finished:
		var floor_nodes: Array = run.explore.floor_ref.nodes
		for kind in ["encounter", "chest"]:
			for node in floor_nodes:
				if run.finished or node.cleared or node.kind != kind:
					continue
				if policy == "rutt" and kind == "encounter" and _hoppa_over(run, node):
					continue
				run._resolve(node)
				_svara_pa_kortval(run, policy != "slump")
		if run.hp < run.max_hp * 0.5:
			for node in floor_nodes:
				if node.kind == "torch" and not node.cleared:
					run._resolve(node)
					_svara_pa_kortval(run, policy != "slump")
		for node in floor_nodes:
			if not run.finished and node.kind == "boss" and not node.cleared:
				run._resolve(node)
				_svara_pa_kortval(run, policy != "slump")
		for node in floor_nodes:
			if not run.finished and node.kind == "shovel" and not node.cleared:
				run._resolve(node)
				_svara_pa_kortval(run, policy != "slump")

## Rutten: ett rum i de två hårdaste graderna tas bara när kroppen tål det. Tröskeln är satt efter vad
## rummets grad betyder (se `Dungeon.rum_svarighet`): grad 3 och 4 är fulla packet.
func _hoppa_over(run: Run, node: Dungeon.FloorNode) -> bool:
	return run.rum_svarighet(node) >= Dungeon.RUM_SPANN + 1 and run.hp < run.max_hp * 0.7

## Svara på varje väntande kortval. Ett val som inte går att göra (uppgraderingens delar är borta)
## stryks av `pick_card` — därför prövar vi nästa, och bryter först när ingen har gått igenom.
func _svara_pa_kortval(run: Run, kompetent: bool) -> void:
	var vakt := 0
	while not run.pending_draft().is_empty() and vakt < 64:
		vakt += 1
		var val: Array = run.pending_draft().duplicate()
		if not kompetent:
			# Seedad slumpordning — `Array.shuffle()` använder den GLOBALA rng:n och gjorde provet
			# omätbart (samma frön gav olika svar mellan två körningar; se `Combat._shuffle`).
			var kvar := val.duplicate()
			val = []
			while not kvar.is_empty():
				val.append(kvar.pop_at(policy_rng.randi_range(0, kvar.size() - 1)))
		else:
			val.sort_custom(func(a, b): return _styrka(run.card_db.get(a)) > _styrka(run.card_db.get(b)))
		var svarat := false
		for id in val:
			if run.pick_card(str(id)):
				svarat = true
				break
		if not svarat:
			return

## Grov rangordning av ett kortval för autospelaren: skada först, sedan rustning, sedan mana.
func _styrka(kort) -> float:
	if kort == null:
		return -1.0
	var v := 0.0
	for e in kort.effects:
		match str(e.get("op", "")):
			"damage":
				v += float(e.get("damage", 0)) * float(e.get("hits", 1))
			"armor":
				v += float(e.get("amount", 0)) * 2.0
			"mana":
				v += float(e.get("amount", 0)) * 4.0
			"heal":
				v += float(e.get("amount", 0)) * 3.0
	return v

## Vilken ratt flyttar mest? En ratt i taget mot basen (HEAD), samma frön och samma startlek, och BÅDA
## policies — frågan är inte bara "blir det svårare" utan "blir det svårare för den som klickar
## slumpmässigt och samtidigt möjligt för den som spelar". Tabellen är den som valde åtgärden.
func _rattprov(stage: Stages.StageDef, bestiary: Dictionary, db: Dictionary, ids: Array) -> void:
	var rattar := {
		"bas (våning 0,15/0,12 + rum, xp 1)": {},
		"xp_per_extra=0,75": {"xp_per_extra": 0.75},
		"xp_per_extra=0,5": {"xp_per_extra": 0.5},
		"xp_per_extra=0,25": {"xp_per_extra": 0.25},
		"fiender=3 (inverteringen)": {"enemies_per_encounter": [3, 3]},
		"fiender=3, xp_per_extra=0,5": {"enemies_per_encounter": [3, 3], "xp_per_extra": 0.5},
		"rum av (levererad press)": {"hp_per_room": 0.0, "damage_per_room": 0.0},
	}
	print("\nRattprov stage_01, startlek, n=%d per rad och policy" % ANTAL)
	print("variant | slump | auto | nivå (kort) slump/auto")
	for namn in rattar:
		var rad := []
		var niva := []
		for policy in ["slump", "auto"]:
			var sum := 0
			var niva_sum := 0.0
			for i in ANTAL:
				var seed_value := 810000 + i
				var best = _skalad_bestiary(bestiary, rattar[namn].get("hp_faktor", 1.0),
					rattar[namn].get("dmg_faktor", 1.0))
				var run := Run.new(stage, best, Cards.make_pile(db, startleken()), seed_value, db)
				for nyckel in rattar[namn]:
					if nyckel != "hp_faktor" and nyckel != "dmg_faktor":
						run.set(nyckel, rattar[namn][nyckel])
				run.fighter = Callable(self, "_slump_fighter" if policy == "slump" else "_auto_fighter")
				policy_rng = RandomNumberGenerator.new()
				policy_rng.seed = seed_value * 7919 + 53
				policy_damage = 0.0
				_play_nodes(run, policy)
				sum += int(run.outcome == "cleared" or run.outcome == "reaped")
				niva_sum += run.level
			rad.append("%d/%d (%.0f%%)" % [sum, ANTAL, 100.0 * sum / ANTAL])
			niva.append("%.1f" % (niva_sum / ANTAL))
		print("%s | %s | %s | %s / %s" % [namn, rad[0], rad[1], niva[0], niva[1]])

## En kopia av bestiariet med fiende-HP och/eller fiende-skada skalad. Kopiorna byggs per variant, så
## en skalad fiende inte läcker in i nästa rad (samma EnemyDef-objekt delas annars av alla körningar).
func _skalad_bestiary(bestiary: Dictionary, hp_faktor: float, dmg_faktor: float) -> Dictionary:
	if is_equal_approx(hp_faktor, 1.0) and is_equal_approx(dmg_faktor, 1.0):
		return bestiary
	var ut := {}
	for id in bestiary:
		var e: Enemies.EnemyDef = bestiary[id]
		var d := {"id": e.id, "name": e.name, "hp": e.hp * hp_faktor, "damage": e.damage * dmg_faktor,
			"tier": e.tier, "eyes": e.eyes, "xp": e.xp, "gold": e.gold, "kind": e.kind}
		ut[id] = Enemies.EnemyDef.from_dict(d)
	return ut
