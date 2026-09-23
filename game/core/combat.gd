## Headless stridsmotor — inga noder, ingen grafik. Allt som avgör utfall ligger här, så det
## går att köra tusentals strider i test och balansera utan att starta spelet.
##
## Mätt ur referensen: mana bas 2, hand 3 kort/tur, kedja i stigande manakostnad, samma
## kostnad två gånger i rad bryter kedjan, wild bryter aldrig, kedjan nollställs vid turstart.
class_name Combat
extends RefCounted

class Enemy extends RefCounted:
	var id: String
	var name: String
	var hp: float
	var max_hp: float
	var damage: float
	var row: int = 0                  ## 0 = främre raden (slår först)
	var eyes_max: int = 0             ## bossar: slår när alla ögon öppnats (0 = vanlig fiende)
	var eyes_open: int = 0
	var frozen: int = 0               ## frusen i så många turer; står still och tinar en tur i taget

	func _init(p_id: String, p_hp: float, p_damage: float, p_row: int = 0, p_eyes: int = 0) -> void:
		id = p_id
		name = p_id
		hp = p_hp
		max_hp = p_hp
		damage = p_damage
		row = p_row
		eyes_max = p_eyes

	func alive() -> bool:
		return hp > 0.0

## Resultatet av en spelad kortlek, för test och logg.
class PlayResult extends RefCounted:
	var ok := false
	var betalat_med_blod := false     ## kortet gick igenom med banans regel "blod som valuta"
	var reason := ""
	var card_id := ""
	var combo := 0                    ## combo-värdet kortet resolverades vid
	var multiplier := 1               ## 1+combo — det spelaren ser
	var damage := 0.0
	var broke_chain := false
	var killed: Array = []
	var gold := 0                     ## guld ur en ädelsten (girigstenen), läggs på körningen

# --- staten -----------------------------------------------------------------
var rng: RandomNumberGenerator
var base_mana := 2                ## Mana-staten (Cooldown-PowerUp ger +1/rang, max +2)
var base_hand := 3                ## Hand-staten (Speed-PowerUp ger +1/rang, max +2)
var armor_stat := 0
var mana_bonus := 0               ## +N mana vid turstart (trädnoden "start_mana")
var draw_bonus := 0               ## +N kort i öppningshanden (trädnoden "draw_first")
var hp := 50.0
var max_hp := 50.0
var armor := 0.0
var might := 0.0                  ## faktor: 10.0 = 1000 %
var area := 0.0
var gems: Array = []              ## multiplikatorer, t.ex. [2.0]
## Ädelstenarna som sitter i korten (M58): kort-id -> {damage, qty, armor, mana, gold}. Sätts av
## Run en gång per körning, så striden slipper fråga metat för varje spelat kort. Utan stenar är
## kartan tom och ingenting händer.
var gem_bonus: Dictionary = {}
## Guld som ädelstenarna i korten har gett under striden. Körningen tömmer summan när striden är
## slut — striden äger myntet, körningen bokför det.
var gold_found := 0
## Banans regel (mutator). Läses av `play()` och `start_turn()`; sätts av Run ur banans fil.
var regel := ""

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var exile_pile: Array = []
var enemies: Array = []

var mana := 0
var combo := 0
var last_cost := Rules.NO_CARD_YET

func _init(seed_value: int = 1) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

## Starta en strid: ny tur, tomma högar, fiender enligt listan.
func begin(deck: Array, enemy_list: Array) -> void:
	draw_pile = deck.duplicate()
	_shuffle(draw_pile)               # seedad: samma seed = samma körning (krävs för buggrapporter)
	hand.clear()
	discard_pile.clear()
	exile_pile.clear()
	enemies = enemy_list
	combo = 0
	last_cost = Rules.NO_CARD_YET
	start_turn()

func start_turn() -> void:
	# Regeln "ingen mana": manan fylls aldrig på, alltså betalas varje kort i blod av samma gate i
	# play(). En regel ska inte behöva en egen betalväg — den ska stänga den vanliga.
	mana = 0 if regel == "ingen_mana" else base_mana + mana_bonus
	# RUSTNINGEN (M75): en GOLV, inte en nollställning. Här stod förut `armor = float(armor_stat)`, och
	# den gjorde poolen till en per-tur-sköld: allt ett rustningskort gav var borta innan nästa tur,
	# och ingen strid ärvde något. Alex: *"skall följa med genom de olika striderna, inte nollas efter
	# en strid"*. Grunden ur metan ("+1 rustning vid turstart") lyfts fortfarande in, men bara UPPÅT —
	# poolen ägs av körningen (se `Run.armor`) och kan aldrig sjunka av en ny tur.
	armor = maxf(armor, float(armor_stat))
	combo = 0
	last_cost = Rules.NO_CARD_YET
	draw(base_hand + draw_bonus)

func draw(n: int) -> void:
	for i in n:
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())

## Seedad blandning (Fisher-Yates). Array.shuffle() använder en global RNG och gör körningar
## ojämförbara — då går en buggrapport inte att återskapa.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Blodet betalar bara när banans regel säger det, och aldrig om det skulle kunna döda: hälsan måste
## räcka med marginal, annars blir ett gratis kort ett sätt att dö av misstag.
func _kan_betala_med_blod() -> bool:
	if regel != "blod_som_valuta" and regel != "ingen_mana":
		return false
	return hp > Regler.BLOD_PRIS

## Spela kortet på plats `index` i handen. Returnerar alltid ett resultat — aldrig tyst.
func play(index: int, target: Enemy = null) -> PlayResult:
	var r := PlayResult.new()
	if index < 0 or index >= hand.size():
		r.reason = "inget_kort"
		return r
	var card: Cards.Card = hand[index]
	r.card_id = card.id
	if not card.is_wild() and card.cost > mana:
		# BANANS REGEL "blod som valuta": räcker inte manan får blodet betala. Samma gate för ALLA
		# kort, så det finns ingen väg runt regeln — och kvittot står i resultatet, så UI:t kan visa
		# att kortet kostade hälsa.
		if not _kan_betala_med_blod():
			r.reason = "for_lite_mana"     # kortet stannar på handen
			return r
		hp -= Regler.BLOD_PRIS
		r.betalat_med_blod = true

	var continuing := Rules.continues_chain(card.cost, last_cost)
	var combo_used := combo
	if not continuing:
		combo_used = 0
		r.broke_chain = true

	r.combo = combo_used
	r.multiplier = Rules.damage_multiplier(combo_used)
	# Priset drogs redan i blod när regeln lät det gå igenom — att dra manan OCKSÅ vore att ta betalt
	# två gånger (mätt av provet: manan gick till -2 på ett kort som kostat 3 med 1 mana kvar).
	if not card.is_wild() and not r.betalat_med_blod:
		mana -= card.cost
	r.damage = _apply_effects(card, combo_used, target, r)
	# Bossar: ett öga öppnas per SPELAT KORT (inte per träff) — sex spelade kort = bossen slår.
	for e in enemies:
		if e.alive() and e.eyes_max > 0:
			e.eyes_open += 1
	combo = Rules.combo_after(card.cost, last_cost, combo)
	if not card.is_wild():
		last_cost = card.cost
	hand.remove_at(index)
	if card.keywords.has("Destroy"):
		exile_pile.append(card)
	else:
		discard_pile.append(card)
	r.ok = true
	return r

## Avsluta turen: fienden slår (främre raden först), sedan ny tur.
func end_turn() -> Array:
	var log := enemy_turn()
	start_turn()
	return log

## Fiendernas tur. Bossar med ögon slår när alla ögon är öppna.
func enemy_turn() -> Array:
	var events := []
	# ponytail: bara främre raden slår (rad 0). Bakre rader avancerar när raden framför är död.
	# Bara den främsta raden slår: lägsta raden bland de levande. Bakre rader avancerar när raden
	# framför är död — och om ALLA knuffats bakåt är den lägsta raden den främsta, annars kunde en
	# knuff göra fienden farligare i stället för ofarlig.
	var front_row := 9999
	for e in enemies:
		if e.alive():
			front_row = mini(front_row, e.row)
	var dmg_total := 0.0
	for e in enemies:
		if not e.alive():
			continue
		# Frusen: står still i N turer. Räknas ner HÄR, en gång per tur, så "frys 2" betyder att
		# fienden står över den här turen och nästa — inte två extra turer för att två kort spelades.
		if e.frozen > 0:
			e.frozen -= 1
			events.append({"type": "thaw", "enemy": e.id, "left": e.frozen})
			continue
		if e.eyes_max > 0 and e.eyes_open < e.eyes_max:
			continue
		if e.row > front_row:
			continue
		dmg_total += e.damage
	if dmg_total > 0.0:
		var absorbed: float = min(armor, dmg_total)
		armor -= absorbed
		hp = max(0.0, hp - (dmg_total - absorbed))
		events.append({"type": "player_hit", "damage": dmg_total, "absorbed": absorbed, "hp": hp})
	return events

func alive_enemies() -> Array:
	var out := []
	for e in enemies:
		if e.alive():
			out.append(e)
	return out

func over() -> bool:
	return hp <= 0.0 or alive_enemies().is_empty()

# --- vyhjälpmedel (fiende-HP saknas helt i referensen — tre moddar bygger samma sak) ---------
func total_enemy_hp() -> float:
	var sum := 0.0
	for e in enemies:
		if e.alive():
			sum += e.hp
	return sum

func total_enemy_hp_max() -> float:
	var sum := 0.0
	for e in enemies:
		if e.alive():
			sum += e.max_hp
	return sum

func enemy_hp_percent() -> float:
	var m := total_enemy_hp_max()
	if m <= 0.0:
		return 0.0
	return total_enemy_hp() / m * 100.0

# --- smart autospel ------------------------------------------------------------------------
## Referensens "Play All" är en blind trigger: den spelar höger-till-vänster och fortsätter även
## när kort spricker. Den här versionen är en solver med uttalade regler:
##   1. spela bara kort som FORTSÄTTER kedjan (stigande kostnad) — annars stanna
##   2. inom samma steg: manakort före utility före companion före attack
##   3. wild kort används bara som bro när inget annat kort kan spelas
##   4. spela aldrig Destroy-kort automatiskt (de är engångsresurser spelaren vill behålla)
##   5. spela aldrig ett kort som saknar manakostnad kvar att betala
## Returnerar loggen över vad som spelades, i ordning.
func auto_play(max_cards: int = 99, allow_wilds: bool = true) -> Array:
	var log := []
	for step in max_cards:
		var index := _best_index(allow_wilds)
		if index < 0:
			break
		var r := play(index)
		if not r.ok:
			break
		log.append(r)
	return log

## Bästa spelbara kortet just nu, eller -1. Reglerna står i auto_play().
func _best_index(allow_wilds: bool) -> int:
	var best := -1
	var best_key := []
	for i in hand.size():
		var card: Cards.Card = hand[i]
		if card.keywords.has("Destroy"):
			continue
		if card.is_wild():
			continue                     # wilds hanteras efteråt, som bro
		if card.cost > mana:
			continue
		if card.cost <= last_cost:
			continue                     # skulle bryta kedjan — stanna hellre
		var key := [card.cost, HandView.role(card), card.name]
		if best < 0 or _less(key, best_key):
			best = i
			best_key = key
	if best >= 0:
		return best
	# Ingen fortsättning finns. En wild kan öppna en — men bara då, och bara om den finns.
	if allow_wilds:
		for i in hand.size():
			if hand[i].is_wild():
				return i
	return -1

static func _less(a: Array, b: Array) -> bool:
	for i in min(a.size(), b.size()):
		if a[i] == b[i]:
			continue
		if typeof(a[i]) == TYPE_INT and typeof(b[i]) == TYPE_INT:
			return a[i] < b[i]
		return str(a[i]) < str(b[i])
	return a.size() < b.size()

## Ska kortet i handen spelas i stigande ordning? Används av förhandsvisningen.
func chain_continues(card: Cards.Card) -> bool:
	return Rules.continues_chain(card.cost, last_cost)

## Vad kortet skulle göra NU: vilka fiender det träffar och för hur mycket. REN — den spelar inte
## kortet, drar inte mana och rör inte kedjan. Den räknar med EXAKT samma regler och samma
## målutdelning som play() (båda går genom _hit_plan), så siffran spelaren ser är den han får.
## En förhandsvisning som gissar är värre än ingen.
func preview(index: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "combo": 0, "multiplier": 1, "hits": [], "damage": 0.0,
		"card_id": ""}
	if index < 0 or index >= hand.size():
		out.reason = "inget_kort"
		return out
	var card: Cards.Card = hand[index]
	out.card_id = card.id
	if not card.is_wild() and card.cost > mana:
		out.reason = "for_lite_mana"
		return out
	var combo_used := combo if chain_continues(card) else 0
	out.combo = combo_used
	out.multiplier = Rules.damage_multiplier(combo_used)
	var total := 0.0
	var per_enemy := {}
	var kvar := {}                    # hypotetiskt HP under uträkningen, så överkill kapas rätt
	for effect in card.effects:
		if str(effect.get("op", "")) != "damage":
			continue
		# Samma ädelsten som play() räknar med — annars visade förhandsvisningen en siffra som inte
		# är den man får (och den regeln står redan överst i den här funktionen).
		var sten: Dictionary = gem_bonus.get(card.id, {})
		var n := float(effect.get("hits", 1)) + float(sten.get("qty", 0))
		var base := float(effect.get("base_damage", 0.0))
		var dmg := Rules.damage(float(effect.get("damage", 0.0)) + float(sten.get("damage", 0)),
			combo_used, base, n, might, area, gems)
		for h in _hit_plan(dmg, int(n), null, kvar):
			var e: Enemy = h.enemy
			var amount := float(h.damage)
			kvar[e] = float(kvar.get(e, e.hp)) - amount
			total += amount
			per_enemy[e] = float(per_enemy.get(e, 0.0)) + amount
	# EN rad per fiende med summan: ett kort med tre skadeeffekter mot samma fiende är en träff på
	# 78, inte tre rader på 26. (Första versionen listade samma fiende tre gånger.)
	var hits := []
	for e in per_enemy.keys():
		hits.append({"enemy": e, "damage": per_enemy[e]})
	out.hits = hits
	out.damage = total
	out.ok = true
	return out

# --- effekter ---------------------------------------------------------------
## Ny op = en rad här. Korten själva är data.
## Motorns hela effekt-vokabulär. Provet läser den här listan mot kortdatat, så en felstavad op
## ("knock_back") blir ett rött prov i stället för en tyst push_error mitt i en strid.
const OPS: Array[String] = ["damage", "armor", "heal", "mana", "draw", "knockback", "freeze"]

func _apply_effects(card: Cards.Card, combo_used: int, target: Enemy, r: PlayResult) -> float:
	var total := 0.0
	# ÄDELSTENARNA (M58). Stenen i kortet lägger sin verkan PÅ kortets egen: skadan och träffarna
	# gäller varje skaderad kortet har ("+2 skada på kortet" = +2 per träff, inte +2 en gång), medan
	# rustning, mana och guld ges en gång per spelat kort. Utan stenar är kartan tom och raden nedan
	# kostar ingenting.
	var sten: Dictionary = gem_bonus.get(card.id, {})
	for effect in card.effects:
		var op := str(effect.get("op", ""))
		match op:
			"damage":
				var hits := float(effect.get("hits", 1)) + float(sten.get("qty", 0))
				var base := float(effect.get("base_damage", 0.0))
				var dmg := Rules.damage(float(effect.get("damage", 0.0)) + float(sten.get("damage", 0)),
					combo_used, base, hits, might, area, gems)
				total += _deal(dmg, int(hits), target, r)
			"armor":
				armor += float(effect.get("amount", 0.0))
			"heal":
				hp = min(max_hp, hp + float(effect.get("amount", 0.0)))
			"mana":
				mana += int(effect.get("amount", 0))
			"draw":
				draw(int(effect.get("amount", 1)))
			"knockback":
				# Knuffa bakåt: en fiende i bakre raden slår inte förrän raden framför är död
				# (se enemy_turn). Träffar samma mål som kortets skada, så riktmarkeringen stämmer.
				var steg := int(effect.get("amount", 1))
				for h in _hit_plan(0.0, int(effect.get("hits", 1)), target):
					var bak: Enemy = h.enemy
					bak.row += steg
			"freeze":
				# Frusen står still i N turer (tinas i enemy_turn). Längsta frysningen gäller:
				# två frys-kort ska inte kunna stapla 4 turer på samma fiende.
				var turer := int(effect.get("amount", 1))
				for h in _hit_plan(0.0, int(effect.get("hits", 1)), target):
					var mal: Enemy = h.enemy
					mal.frozen = maxi(mal.frozen, turer)
			_:
				push_error("okänd effekt-op: %s (%s)" % [op, card.id])
	if not sten.is_empty():
		# En gång per spelat kort, oavsett hur många rader det har. Guldet hamnar både i resultatet
		# (för den som visar det spelade kortet) och i stridens summa (som körningen tömmer).
		armor += float(sten.get("armor", 0))
		mana += int(sten.get("mana", 0))
		r.gold += int(sten.get("gold", 0))
		gold_found += int(sten.get("gold", 0))
	return total

## Dela ut skada. `hits` styr hur många fiender som träffas, i turordning (främre raden först).
func _deal(dmg: float, hits: int, target: Enemy, r: PlayResult) -> float:
	var done := 0.0
	for h in _hit_plan(dmg, hits, target):
		var e: Enemy = h.enemy
		e.hp -= float(h.damage)
		done += float(h.damage)
		if not e.alive():
			r.killed.append(e.id)
	return done

## Vem ett anfall träffar och för hur mycket — UTAN att ändra något. Både _deal och preview()
## läser den här, så förhandsvisningen kan inte visa något annat än det som sedan händer.
## `target` (valt mål) träffas först; resten i fiendelistans ordning. Skadan kapas av fiendens HP
## precis som i striden, så "24" betyder 24 även när fienden bara har 6 kvar.
## `remaining` är bara för preview(): där räknas flera effekter mot samma fiende, så kapningen
## måste ske mot det HP som är KVAR efter de tidigare effekterna — annars visar överkill för mycket.
func _hit_plan(dmg: float, hits: int, target: Enemy, remaining: Dictionary = {}) -> Array:
	var chosen := []
	if target != null and target.alive():
		chosen.append(target)
	for e in enemies:
		if e.alive() and not chosen.has(e) and chosen.size() < hits:
			chosen.append(e)
	var out := []
	var n := 0
	for e in chosen:
		if n >= hits:
			break
		var hp_left: float = float(remaining.get(e, e.hp))
		out.append({"enemy": e, "damage": min(dmg, hp_left)})
		n += 1
	return out
