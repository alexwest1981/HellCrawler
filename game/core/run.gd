## En körning: gå genom våningarna, slåss om striderna, ta shoveln, nedåt.
##
## Allt som händer uttrycks som EVENTS ({"type": ...}) i en lista som anroparen läser. UI:t,
## ljudet och skärmläsaren konsumerar samma ström — vilket är precis vad communityns
## tillgänglighetsmoddar inte kunde eftermonstrera i referensen (research/05-moddar.md §3.4).
##
## Modellen är medvetet liten: en spelare, en hög, en fiende i taget. Nyckeltal som inte är
## kända (fiende-HP-skalning, recovery) ligger som rattar med kommentar — inte som gissningar
## utspridda i koden.
class_name Run
extends RefCounted

const MAX_STEPS := 5000            ## skyddsräcke: en körning ska alltid ta slut
const MAX_TURNS_PER_FIGHT := 60

# --- rattar (kalibreras mot referensens dumpar senare) --------------------------------------
var hp_per_difficulty := 0.10      ## fiende-HP: +10 % per svårighetsgrad
var hp_per_floor := 0.15           ## ...och +15 % per våning nedåt
var damage_per_difficulty := 0.06
var recovery := 3.0                ## helas så här mycket efter varje strid
var enemies_per_encounter := [1, 3]

# --- tillstånd ------------------------------------------------------------------------------
var stage: Stages.StageDef
var bestiary: Dictionary
var deck: Array
var seed_value: int
var explore: Explore
var floor_index := 0
var hp := 60.0
var max_hp := 60.0
## RUSTNINGEN (M75) är en POOL som följer med genom körningen. Alex: *"vi behöver ha en rustning som
## visar rustningens värde (som för övrigt skall följa med genom de olika striderna, inte nollas efter
## en strid)"*. Förut nollställdes den vid varje TUR (`Combat.start_turn`) mot metans grundvärde, så
## allt man samlade med ett rustningskort var borta innan nästa tur — och nästa strid började på noll.
## `armor_stat` är grunden ur metan, `armor_tak` det högsta poolen nått (taket för stapeln i HUD:en:
## en stapel som alltid är full ger inget besked om värdet).
var armor := 0.0
var armor_stat := 0
var armor_tak := 1.0
var gold := 0
var shards := 0                   ## splitter ur kistorna — bankas med guldet när körningen tar slut
var stenar: Array = []            ## ädelstenar hittade i kistor: {"fam": .., "grad": ..}
var _restored := false            ## har den andra chansen (revive) använts i den här körningen?
var xp := 0
var base_mana := 3
var base_hand := 4
var events: Array = []
var finished := false
var outcome := ""                  ## "reaped" (dödad av slutet, som i referensen) | "cleared" | "dead"
var fights_won := 0
## Dödade fiender i körningen. Slutskärmen svarar på Alex' fråga "hur många man dödat" — antalet
## fiender i striden, inte antalet strider (en strid kan ha fyra stycken).
var kills := 0
var fights_lost := 0
var total_damage := 0.0

# --- progression ---------------------------------------------------------------------------
var card_db: Dictionary = {}       ## kortdatabasen (behövs för kortvalen vid level up)
var meta: Meta = null              ## permanent uppgraderingar; null = standardspelaren
var level := 1
var drafts: Array = []             ## kö av kortval: [{level, choices: [id, ...]}, ...]
var luck := 0                      ## >0 ger ett fjärde val, som referensens Luck
var rng_draft: RandomNumberGenerator

## Kortvalet som väntar på ett svar (tom lista = inget väntar).
func pending_draft() -> Array:
	if drafts.is_empty():
		return []
	return drafts[0].choices

## Väntar ett BOSS-val? Rubriken, ljudet och loggraden skiljer sig från en vanlig nivåuppgång: ett
## bossval skrivs dessutom till den permanenta samlingen (se pick_card).
func pending_draft_boss() -> bool:
	return not drafts.is_empty() and bool(drafts[0].get("boss", false))

## Spelaren har valt ett kort. Läggs i leken, kön går vidare.
func pick_card(id: String) -> bool:
	if drafts.is_empty():
		return false
	if not card_db.has(id):
		push_error("okänt kort i kortvalet: %s" % id)
		return false
	var entry: Dictionary = drafts[0]
	if not entry.choices.has(id):
		return false
	var kort: Cards.Card = card_db[id]
	var boss_val := bool(entry.get("boss", false))
	# Uppgraderingen: två kort konsumeras, ett läggs in (Evolution.consume). Delarna kan ha tagits
	# av en annan uppgradering mellan att valet skapades och att det besvaras; då STRYKS valet i
	# stället för att bli ett gratis kort — och i stället för att kön fastnar på ett val som inte
	# går att göra (rörelsen är blockerad så länge ett kortval väntar).
	if Evolution.is_evolution(kort):
		if not Evolution.consume(deck, card_db, id):
			entry.choices.erase(id)
			if entry.choices.is_empty():
				drafts.remove_at(0)
			return false
	else:
		deck.append(kort)
	# BOSSENS BYTE (Alex): *"När bossen dör skall ett minigame ge en 3 kort att välja mellan, och
	# sedan skall det sparas i ens permanenta kort-samling."* Kortet läggs i leken för körningen OCH
	# i metat, så det finns kvar mellan banor. Skrivningen sker på ETT ställe — hade UI:t gjort det
	# hade en autospelad körning (prov, demoläge) tappat sina bossval i tysthet.
	if boss_val and meta != null:
		meta.samla(id)
	drafts.remove_at(0)
	events.append({"type": "card_picked", "card": id, "level": entry.level, "deck_size": deck.size(),
		"evo": Evolution.is_evolution(kort), "samling": boss_val})
	return true

## Kortvalet: korten ur datan, och uppgraderingen när receptet ligger i leken. Ett val per kortval
## (MAX_EVO_PER_DRAFT), och raden får aldrig bli bredare än de fyra platser panelen är byggd för.
const MAX_EVO_PER_DRAFT := 1
const DRAFT_ROW_MAX := 4          ## samma fyra platser som draft_box.custom_minimum_size

func _check_level() -> void:
	if card_db.is_empty():
		return
	while xp >= Progress.xp_total(level + 1):
		level += 1
		var choices := Progress.draft(rng_draft, card_db, 3 + (1 if luck > 0 else 0), level / 4)
		# Uppgraderingen läggs EFTER korten: den är ett byte (två kort blir ett), inte ett kort man
		# får. Står receptet i leken men man väljer ett vanligt kort är uppgraderingen kvar till
		# nästa nivå — inget går förlorat på att tveka.
		var evo := Evolution.available(deck)
		for i in mini(evo.size(), MAX_EVO_PER_DRAFT):
			# Flera färdiga recept: kortvalet visar dem i TUR OCH ORDNING (nivån är startpunkten) i
			# stället för att alltid visa det första i datat — annars fick spelaren aldrig se de
			# andra, och i en körning med tre recept gick bara ett att upptäcka.
			var vald := str(evo[(level + i) % evo.size()])
			if choices.size() < DRAFT_ROW_MAX and not choices.has(vald):
				choices.append(vald)
		drafts.append({"level": level, "choices": choices})
		events.append({"type": "level_up", "level": level, "choices": choices})

## Bossens byte: tre kort ur datat (Progress.draft håller uppgraderingar och kamrater utanför och
## ger alltid tre val), köade som ett vanligt kortval med flaggan som gör det permanent.
func _boss_draft() -> void:
	if card_db.is_empty():
		return
	var choices := Progress.draft(rng_draft, card_db, 3, level / 4)
	if choices.is_empty():
		return
	drafts.append({"level": level, "choices": choices, "boss": true})
	events.append({"type": "boss_reward", "level": level, "choices": choices})

## Om satt tar den här callable:n över striderna (interaktivt läge) i stället för autospelaren.
## Anropas med Combat-objektet; den som sätter den ansvarar för att striden spelas klart.
var fighter: Callable = Callable()

func _init(p_stage: Stages.StageDef, p_bestiary: Dictionary, p_deck: Array, p_seed: int = 1,
		p_card_db: Dictionary = {}, p_meta: Meta = null) -> void:
	stage = p_stage
	bestiary = p_bestiary
	deck = p_deck
	seed_value = p_seed
	card_db = p_card_db
	meta = p_meta
	# Metan läggs på HÄR, en gång per körning, i stället för att varje strid letar upp den.
	# Nullbar: en körning utan meta är standardspelaren (balansmätaren och alla prov kör så).
	if meta != null:
		max_hp += meta.stat("max_hp")
		hp = max_hp
		base_mana += int(meta.stat("mana"))
		base_hand += int(meta.stat("hand"))
		recovery += meta.stat("recovery")
	rng_draft = RandomNumberGenerator.new()
	rng_draft.seed = p_seed * 7919 + 13      # egen ström: kortvalen ska inte påverkas av striden
	_enter_floor(0)

## Svårighetsgraden: förbannelsen gör fienderna tåligare MEN guldet rikare — samma byteshandel
## som referensen. Utan meta är båda faktorerna 1.
func curse_scale() -> float:
	return 1.0 + (meta.stat("curse") if meta != null else 0.0)

func gold_bonus() -> float:
	# `gold` är ren vinst; `curse` är byteshandeln (tåligare fiender mot mer guld). Två nycklar, för
	# de är två olika köp i trädet.
	return 1.0 + stage.gold_bonus + ((meta.stat("curse") + meta.stat("gold")) if meta != null else 0.0)

## En nyckel ur trädet som heltal, 0 utan meta. Raden finns för att de sju nya noderna annars hade
## fått var sin `if meta != null`-gren i kistan och i stridsstarten.
func stat_int(key: String) -> int:
	return int(meta.stat(key)) if meta != null else 0

func _enter_floor(index: int) -> void:
	floor_index = index
	var f := Dungeon.generate(stage, index, seed_value + index * 7919, bestiary)
	explore = Explore.new(f)
	events.append({"type": "floor_enter", "floor": index, "stage": stage.id})

## Kör tills körningen är slut. Returnerar eventlistan.
func play_out() -> Array:
	var guard := 0
	while not finished and guard < MAX_STEPS:
		guard += 1
		advance()
	if not finished:
		finished = true
		outcome = "dead"
		events.append({"type": "run_end", "outcome": outcome, "note": "skyddsräcket slog till"})
	return events

## Ett steg i körningen: gå mot nästa mål, eller lös det vi står på.
func advance() -> void:
	if finished:
		return
	var objective := _next_objective()
	if objective == null:
		_finish()
		return
	if explore.pos == objective.pos:
		_resolve(objective)
		return
	var err := explore.step_toward(objective.pos)
	if err != "":
		# ponytail: ingen omväg runt hinder — BFS-vägen går alltid fram. Om den inte gör det
		# är våningen trasig, och det ska synas som ett event i stället för en tyst hängning.
		events.append({"type": "stuck", "at": str(explore.pos), "target": str(objective.pos), "why": err})
		_finish()

## Målet just nu: alla strider, sedan bossen, sist shoveln (nedstigningen).
## Avklarade noder hoppas över — annars slåss man mot bossen i evighet.
func _next_objective() -> Dungeon.FloorNode:
	var f := explore.floor_ref
	var best: Dungeon.FloorNode = null
	var best_dist := 1 << 30
	for n in f.nodes:
		if n.cleared or n.kind != "encounter":
			continue
		var d: int = abs(n.pos.x - explore.pos.x) + abs(n.pos.y - explore.pos.y)
		if d < best_dist:
			best_dist = d
			best = n
	if best != null:
		return best
	# Kistan: värd en omväg, men EFTER fienden — den som är svag ska inte lockas dit först.
	for n in f.nodes:
		if not n.cleared and n.kind == "chest":
			return n
	# Facklan: bara en omväg om man är skadad. En hel spelare går raka vägen till nästa fiende.
	if hp < max_hp * 0.5:
		for n in f.nodes:
			if not n.cleared and n.kind == "torch":
				return n
	for n in f.nodes:
		if not n.cleared and n.kind == "boss":
			return n
	for n in f.nodes:
		if not n.cleared and n.kind == "shovel":
			return n
	return null

func _resolve(node: Dungeon.FloorNode) -> void:
	node.cleared = true
	match node.kind:
		"encounter":
			_fight(node, false)
		"boss":
			_fight(node, true)
		"shovel":
			descend()
		"chest":
			events.append(_open_chest(node))
		"torch":
			events.append(_rest())
		_:
			pass

## Kistan: guld eller en klunk läkning, avgjort av körningens seed och nodens position — samma kista
## ger samma sak varje gång. Låg den på ett tärningsslag som inte var seedat vore våningen "slumpad"
## på ett sätt som gör determinismprovet till en lögn.
func _open_chest(node: Dungeon.FloorNode) -> Dictionary:
	# SPLITTER I VARJE KISTA (M57): den unika valutan finns bara här, aldrig i butiken, och mängden
	# följer djupet. Utan den står trädets permanenta noder still hur mycket guld man än bär hem.
	var sp := Meta.kista_splitter(floor_index + 1)
	shards += sp
	var slag := (seed_value + node.pos.x * 31 + node.pos.y * 17) % 100
	# Två trädnoder flyttar FÖNSTREN i samma seedade slag: girigheten ger fler stenfönster (gem_find)
	# och färre läkefönster (chest_luck). Slaget är detsamma — bara gränserna rör sig.
	var sten_fönster := 15 + stat_int("gem_find") * 10
	var guld_fönster := 85 + stat_int("chest_luck") * 5
	# ÄDELSTEN (M58): var sjunde kista ungefär. Slaget är seedat, som guld/läkning — en kista som
	# gav en sten första gången ger samma sten nästa gång.
	if slag < sten_fönster and meta != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + node.pos.x * 7919 + node.pos.y * 104729
		var sten := meta.pick_sten(floor_index + 1, rng)
		if not sten.is_empty():
			stenar.append(sten)
			return {"type": "chest", "vad": "sten", "shards": sp, "fam": sten["fam"],
				"grad": int(sten["grad"])}
	if slag < guld_fönster:
		# Värdet kommer ur NODEN (generatorn satte det), inte ur en ny formel här: annars fanns
		# kistans värde på två ställen och den ena kunde glida ifrån den andra.
		var g := int(round(float(node.gold) * gold_bonus()))
		gold += g
		return {"type": "chest", "vad": "guld", "gold": g, "shards": sp}
	var läkt := _heal(0.15)
	return {"type": "chest", "vad": "läkning", "hp": läkt, "shards": sp}

## Facklan: en andhämtning. Vilan läker en sjättedel av max-HP, aldrig över taket.
func _rest() -> Dictionary:
	return {"type": "torch", "vad": "vila", "hp": _heal(0.16)}

func _heal(andel: float) -> int:
	var läkt := mini(ceili(max_hp * andel), int(max_hp - hp))
	if läkt <= 0:
		return 0
	hp += läkt
	return läkt

## UI-vägen in i en nod: spelaren står på den. Returnerar striden som ska spelas, eller null
## om noden inte var en strid (då är den redan löst, t.ex. nedstigning).
func enter_node(node: Dungeon.FloorNode) -> Combat:
	if node.cleared:
		return null
	node.cleared = true
	match node.kind:
		"encounter":
			return begin_fight(node, false)
		"boss":
			return begin_fight(node, true)
		"shovel":
			descend()
		"chest":
			events.append(_open_chest(node))
		"torch":
			events.append(_rest())
	return null

## UI-vägen ut ur striden: räkna in resultatet.
func leave_node(node: Dungeon.FloorNode, combat: Combat) -> void:
	finish_fight(node, combat)

## Antal fiender i en nod. EN källa för vyn och för striden: vyn ritar samma antal figurer som
## begin_fight sedan spawnar, annars visar rummet tre varelser där det blir två.
func enemy_count_for(node: Dungeon.FloorNode, is_boss: bool = false) -> int:
	if is_boss:
		return 1
	return enemies_per_encounter[0] + (seed_value + node.pos.x + node.pos.y) % (enemies_per_encounter[1] - enemies_per_encounter[0] + 1)

## Bygg striden för en nod — men spela den inte. UI och tester äger speltiden.
func begin_fight(node: Dungeon.FloorNode, is_boss: bool) -> Combat:
	var def: Enemies.EnemyDef = bestiary.get(node.enemy_id)
	if def == null:
		events.append({"type": "missing_enemy", "id": node.enemy_id})
		return null
	var scale_hp := (1.0 + hp_per_difficulty * (stage.difficulty - 1) + hp_per_floor * floor_index) \
		* curse_scale()
	var scale_dmg := 1.0 + damage_per_difficulty * (stage.difficulty - 1)
	var count := enemy_count_for(node, is_boss)
	var foes := []
	for i in count:
		# RADEN: packet står i rad 0, 1, 2 — inte hela packet i rad 0. combat.gd:s regel är att bara
		# den främre raden slår och att nästa rad tar över när raden framför fallit ("främre raden
		# attackerar; nästa grupp måste avancera innan den kan slå", research/01 §6). Låg alla i rad 0
		# slog hela packet varje runda, och därmed var regeln — och Shove-kortet, som knuffar bakåt —
		# verkningslös. Mätt i M30 (20 körningar, samma lek och seeds): med rader 7/20 → 11/20 når
		# våning 2 på svårighet 3, 11/20 → 18/20 klarar stage_01, 4/20 → 8/20 klarar stage_05.
		var e := Combat.Enemy.new(def.name, def.hp * scale_hp, def.damage * scale_dmg, i, def.eyes)
		foes.append(e)
	events.append({"type": "combat_start", "enemy": def.id, "count": count, "boss": is_boss})

	var combat := Combat.new(seed_value + node.pos.x * 31 + node.pos.y)
	combat.hp = hp
	combat.max_hp = max_hp
	combat.base_mana = base_mana
	combat.base_hand = base_hand
	combat.regel = stage.regel          # banans regel följer med in i striden
	# Måste, area, rustning och gems kommer ur metan: det är de permanenta uppgraderingarna som
	# gör att en svårare bana går att klara. Utan meta är de 0 (standardspelaren).
	if meta != null:
		combat.gem_bonus = meta.gem_bonus_all()
		combat.mana_bonus = int(meta.stat("start_mana"))
		combat.draw_bonus = int(meta.stat("draw_first"))
		combat.might = meta.stat("might")
		combat.area = meta.stat("area")
		combat.armor_stat = int(meta.stat("armor"))
	# RUSTNINGEN (M75): poolen lämnas till striden och hämtas tillbaka i `finish_fight`. Är poolen
	# mindre än grunden ur metan får man grunden — annars började en körning med 0 hur mycket rustning
	# man än köpt för splitter.
	armor_stat = combat.armor_stat
	armor = maxf(armor, float(armor_stat))
	armor_tak = maxf(armor_tak, maxf(armor, float(armor_stat)))
	combat.armor = armor
	combat.begin(deck.duplicate(), foes)
	return combat

## Räkna in en spelad strid: HP, guld, xp, recovery och död.
func finish_fight(node: Dungeon.FloorNode, combat: Combat) -> void:
	var def: Enemies.EnemyDef = bestiary.get(node.enemy_id)
	hp = combat.hp
	# RUSTNINGEN TILLBAKA TILL KÖRNINGEN (M75): striden räknar på sin egen kopia (den behöver bara ett
	# tal att dra ifrån), och poolen — och taket för stapeln — skrivs hit när striden är slut. Det här
	# är den ENDA vägen ut ur en strid, så det finns inget andra ställe att glömma.
	armor = combat.armor
	armor_tak = maxf(armor_tak, armor)
	total_damage += combat.total_enemy_hp_max() - combat.total_enemy_hp()
	# Girigstenens guld: striden har samlat det, körningen bokför det. Töms vid varje stridslut, så
	# en sten inte kan betala två gånger.
	gold += combat.gold_found
	combat.gold_found = 0
	var won := combat.alive_enemies().is_empty()
	if won and def != null:
		fights_won += 1
		gold += int(round(def.gold * max(1, combat.enemies.size()) * gold_bonus()))
		# Banans `xp_bonus` är DATA — 0,0 på svårighet 1 och stigande till 0,6 på svårighet 7+ i alla
		# 40 filer — och lästes av INGEN (mätt i M30). Utan den var en svårare bana bara dyrare, aldrig
		# rikare på xp, trots att filerna påstod motsatsen.
		var antal := maxi(1, combat.enemies.size())
		kills += antal
		xp += int(round(float(def.xp * antal) * (1.0 + stage.xp_bonus)))
		# Märg i såret (recovery) läker per STRID; benskäraren (heal_kill) läker per DRÄPT fiende.
		hp = min(max_hp, hp + recovery + float(stat_int("heal_kill") * antal))
		# BOSSEN FÖRST (M45): *"När bossen dör skall ett minigame ge en 3 kort att välja mellan"* —
		# bytet är det som hör till bossens död, och nivåuppgången (som bossens xp gav) kommer efter.
		# Låg nivåvalet först visade panelen "NIVÅ 2 — välj ett kort" i samma sekund som bossen föll,
		# och då syntes bytet aldrig (mätt i `-- grävprov`: rubriken var nivåns, inte bossens).
		if node.kind == "boss":
			_boss_draft()
		_check_level()
	else:
		fights_lost += 1
	events.append({"type": "combat_end", "enemy": node.enemy_id, "won": won,
		"player_hp": hp, "damage": combat.total_enemy_hp_max() - combat.total_enemy_hp()})

	if hp <= 0.0:
		# ANDRA CHANSEN (M57): trädnoden `revive` reser en dödad spelare EN gång per körning, med
		# 1 HP. Provet mäter båda vägarna: med noden lever körningen vidare, utan den tar den slut
		# som förut. Flaggan ligger på körningen, så en ny körning har sin egen chans.
		if not _restored and meta != null and meta.stat("revive") > 0.0:
			_restored = true
			hp = 1.0
			events.append({"type": "revive", "hp": hp, "floor": floor_index + 1})
			return
		# Att dö på sista våningen ÄR att klara banan — så fungerar referensen (Red Death).
		if floor_index >= stage.floors - 1:
			_finish_with("reaped")
		else:
			_finish_with("dead")

## Den automatiska vägen (tester, uppspelning): bygg, spela klart, räkna in.
func _fight(node: Dungeon.FloorNode, is_boss: bool) -> void:
	var combat := begin_fight(node, is_boss)
	if combat == null:
		return
	var turns := 0
	if fighter.is_valid():
		fighter.call(combat)        # interaktiv klient (text): den sköter striden själv
	else:
		while not combat.over() and turns < MAX_TURNS_PER_FIGHT:
			turns += 1
			combat.auto_play()
			if not combat.over():
				combat.end_turn()
	finish_fight(node, combat)

## Spelaren står på en nod: lös den. Returnerar true om något hände.
## Den interaktiva klienten anropar den här när spelaren själv går fram till en nod.
func resolve_here() -> bool:
	var node := explore.node_here()
	if node == null or node.cleared:
		return false
	_resolve(node)
	advance()          # hämta eventuella följdeffekter (nedstigning, död)
	return true

func descend() -> void:
	events.append({"type": "shovel", "floor": floor_index})
	if floor_index + 1 >= stage.floors:
		_finish_with("cleared")
		return
	_enter_floor(floor_index + 1)

## Utfallet i klartext, på spelets språk. Maskinnamnet ("dead") ska inte möta spelaren.
func outcome_text() -> String:
	match outcome:
		"dead":
			return Tr.t("ui.outcome.dead", "död")
		"reaped":
			return Tr.t("ui.outcome.reaped", "skördad — du föll för liemannen på sista våningen")
		"cleared":
			return Tr.t("ui.outcome.cleared", "banan klarad")
		_:
			return outcome

func _finish() -> void:
	_finish_with("cleared")

func _finish_with(result: String) -> void:
	if finished:
		return
	finished = true
	outcome = result
	events.append({"type": "run_end", "outcome": outcome, "floors": floor_index + 1,
		"gold": gold, "xp": xp, "hp": hp, "fights_won": fights_won, "fights_lost": fights_lost,
		"kills": kills,
		"steps": explore.steps_taken, "turns": explore.turns_taken})
