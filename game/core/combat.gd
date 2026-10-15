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
	var mana := 0                     ## mana gained from card effects
	var hp := 0                       ## hp healed by card effects
	## Vad KOMPANJONERNA I SPEL gjorde av det här kortet (M119): en rapport per reaktion, i samma form
	## som kortets egen, så UI:t kan kvittera dem likadant och testerna mäta dem.
	var triggered: Array = []

# --- staten -----------------------------------------------------------------
var rng: RandomNumberGenerator
var base_mana := 2                ## Mana-staten (Cooldown-PowerUp ger +1/rang, max +2)
var base_hand := 3                ## Hand-staten (Speed-PowerUp ger +1/rang, max +2)
var armor_stat := 0
var relic_damage := 0.0           ## reliken "den vässade eggen" (M123): +N per skaderad kortet har
var combo_bonus := 0              ## reliken "kedjestenen" (M123): extra steg när kedjan FORTSÄTTER
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
## Kompanjonerna som STANNAR i spel (M119): [{kort: Card, kvar: int}]. Ett kort med `duration > 0`
## hamnar här i stället för i kast- eller exilhögen, och reagerar på det spelaren spelar.
var field: Array = []
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
	field.clear()
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
	var combo_used := _combo_used(card)
	if not continuing:
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
	var combo_före := combo
	combo = Rules.combo_after(card.cost, last_cost, combo)
	# KEDJESTENEN (M123): en relik gör varje stigande steg värt mer — men bara när kedjan FORTSÄTTER.
	# En relik ska inte kunna starta en kedja ur tomma luften; då vore den inte en belöning för att
	# spela korten i rätt ordning. (`combo > 1` = steget är en fortsättning, inte en nystart.)
	if combo_bonus > 0 and combo > combo_före and combo > 1:
		combo += combo_bonus
	if not card.is_wild():
		last_cost = card.cost
	hand.remove_at(index)
	if card.duration > 0:
		# KORTET STANNAR (M119). Referensens Crawlers ligger kvar i spel och gör sitt när spelaren gör
		# det de reagerar på ("Deal 40 damage [...] when a purple card is played"), och lämnar efter
		# `duration` sådana gånger. Ett kort i spel hamnar varken i kast- eller exilhögen — det står på
		# bordet, och ligger kvar där striden varar.
		field.append({"kort": card, "kvar": card.duration})
	elif card.keywords.has("Destroy"):
		exile_pile.append(card)
	else:
		discard_pile.append(card)
	r.triggered = _reagera_i_spel(card)
	r.ok = true
	return r

## MÅLET FÖR ETT KORT (M121, ratt E). Referensen telegraferar fiendens drag och låter spelaren välja
## mål; våra kort gick alltid på främre raden. Regeln är den spelaren kan LÄSA ur telegrammet:
## träffa den som slår hårdast härnäst — då försvinner hela slaget om den faller, och kapningen i
## `_hit_plan` gör att fokuseringen aldrig slösar skada på en fiende som ändå dör. När ingen slår
## (frusna, boss med stängda ögon) är svaret den främre raden, alltså samma svar som förut i det
## läge där svaret inte kan bli bättre. Ett försök med målstyrning UTAN telegrammet föll tidigare
## (docs/balans.md §7): det var en gissning, och den var sämre än att låta bli.
func _målval(index: int) -> Enemy:
	if index < 0 or index >= hand.size():
		return null
	var hetast: Enemy = null
	for rad in inkommande():
		var e: Enemy = rad["enemy"]
		if hetast == null or e.damage > hetast.damage:
			hetast = e
	if hetast != null:
		return hetast
	var framst := 9999
	for e in enemies:
		if e.alive():
			framst = mini(framst, e.row)
	if framst == 9999:
		return null
	for e in enemies:
		if e.alive() and e.row == framst:
			return e
	return null

## Kompanjonerna i spel reagerar på kortet som just spelades (M119). Effekterna går genom SAMMA väg som
## ett spelat kort (`_apply_effects`), men utan kedjemultiplikator: de är redan betalda en gång, och
## kedjan hör till korten på handen. Varje reaktion räknas ner, och vid noll lämnar kortet bordet.
## Ett kort som just gick in i spel reagerar inte på sig självt.
func _reagera_i_spel(spelat: Cards.Card) -> Array:
	var ut := []
	for i in range(field.size() - 1, -1, -1):
		var post: Dictionary = field[i]
		var kort: Cards.Card = post["kort"]
		if kort == spelat:
			continue
		if not kort.trigger.is_empty() and kort.trigger != spelat.card_type:
			continue
		var rr := PlayResult.new()
		rr.card_id = kort.id
		rr.ok = true
		rr.damage = _apply_effects(kort, 0, null, rr)
		post["kvar"] = int(post["kvar"]) - 1
		if int(post["kvar"]) <= 0:
			field.remove_at(i)
			discard_pile.append(kort)
		ut.append(rr)
	return ut

## Avsluta turen: fienden slår (främre raden först), sedan ny tur.
func end_turn() -> Array:
	var log := enemy_turn()
	start_turn()
	return log

## VEM som slår nästa fiende tur och för hur mycket — TELEGRAMMET, utan att röra något. Referensen
## visar fiendens drag innan man spelar; spelarens svar (och provets målpolicy) behöver samma siffra.
## Regeln bor i `_slagsverk`, som `enemy_turn` också läser — annars kunde telegrammet ljuga.
func inkommande() -> Array:
	var front_row := _främre_rad()
	var ut := []
	for e in enemies:
		if _slår_nästa_tur(e, front_row):
			ut.append({"enemy": e, "damage": _slagsverk(e, front_row)})
	return ut

## SLAGSVERKAN (M124): hur hårt fienden slår när turen kommer. Främre raden slår fullt, bakre raden
## slår svagare — men den SLÅR. Före den här ändringen slog bara främre raden, och då var målvalet
## alltid samma svar (främre raden) och betydde ingenting: mätt 11 mot 11 för mål- och autopolicyn.
## Telegrammet och `enemy_turn` läser SAMMA funktion, annars kan telegrammet ljuga.
const BAKRE_SLAG := 0.6             ## bakre radens andel av sin skada
func _slagsverk(e: Enemy, front_row: int) -> float:
	if e.row <= front_row:
		return e.damage
	return e.damage * BAKRE_SLAG

## Lägsta raden bland de levande = den främre. Bakre rader avancerar när raden framför är död.
func _främre_rad() -> int:
	var framst := 9999
	for e in enemies:
		if e.alive():
			framst = mini(framst, e.row)
	return framst

## Slår fienden när turen kommer? Frusen står still, en boss med stängda ögon slår inte, och alla
## levande rader slår (den bakre svagare, se `BAKRE_SLAG`).
func _slår_nästa_tur(e: Enemy, front_row: int) -> bool:
	if not e.alive():
		return false
	if e.frozen > 0:
		return false
	if e.eyes_max > 0 and e.eyes_open < e.eyes_max:
		return false
	return _slagsverk(e, front_row) > 0.0

## Fiendernas tur. Bossar med ögon slår när alla ögon är öppna.
func enemy_turn() -> Array:
	var events := []
	# ALLA rader slår (M124), den bakre svagare. En knuff gör alltså inte längre fienden ofarlig — den
	# flyttar den till den svagare raden, vilket är vad kortet säger att det gör.
	var front_row := _främre_rad()
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
		if not _slår_nästa_tur(e, front_row):
			continue
		dmg_total += _slagsverk(e, front_row)
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
##   1. spela först kort som FORTSÄTTER kedjan (stigande kostnad) — de bär multiplikatorn
##   2. inom samma steg: manakort före utility före companion före attack
##   3. när ingen fortsättning finns: BÖRJA EN NY KEDJA av det starkaste spelbara kortet
##   4. wild kort används bara som bro när inget annat kort kan spelas
##   5. spela aldrig Destroy-kort automatiskt (de är engångsresurser spelaren vill behålla)
##   6. spela aldrig ett kort som saknar manakostnad kvar att betala
##   7. inom SAMMA kostnad går ett kort som STANNAR i spel först (det betalar igen nästa tur)
##   8. MÅLVAL (ratt E) är avstängt som förval: `målval=true` siktar kortet på den fiende telegrammet
##      (`inkommande()`) säger slår hårdast härnäst, i stället för på främre raden. Slås på av den
##      policy som ska bevisa att målvalet är värt något — annars vore skillnaden omätbar.
##
## REGEL 3 ÄR MÄTT IN (14/10): förut STANNADE autospelaren vid första glappet och lämnade både mana och
## kort ospelade. I en mätning klarade slumppolicyn 8 % av körningarna och solvern 2 % — den var alltså
## SÄMRE än att klicka på måfå. En solver som är sämre än slumpen är inte en solver. Talen, ratten och
## hela balansmätningen: `docs/balans.md`.
## Returnerar loggen över vad som spelades, i ordning.
func auto_play(max_cards: int = 99, allow_wilds: bool = true, målval: bool = false,
		avvärj: bool = false) -> Array:
	var log := []
	for step in max_cards:
		var index := _best_index(allow_wilds)
		var mål: Enemy = null
		if avvärj:
			var av := _avvärj_index()
			if av >= 0:
				index = av
				mål = _avvärj_mål
		if index < 0:
			break
		if mål == null and målval:
			mål = _målval(index)
		var r := play(index, mål)
		if not r.ok:
			break
		log.append(r)
	return log

## AVVÄRJNINGEN (M124): telegrammet säger vem som slår nästa tur och för hur mycket. Valet det gör
## möjligt är inte bara "vem ska jag slå" utan "ska jag slå eller STÄNGA AV": finns ett frys-kort på
## handen och ett slag värt att stoppa, är svaret det kortet, mot den som slår hårdast. Utan en policy
## som fattar det valet mäter provet bara att målvalet inte hjälper — frågan är om spelet ERBJUDER
## valet. Returnerar index för kortet att spela (och sätter `_avvärj_mål`), eller -1 för "slå som
## vanligt". Tröskeln är en andel av din HP: att frysa ett slag för 4 när man har 100 HP är att slösa
## ett kort, och det ska policyn inte göra.
const AVVÄRJ_ANDEL := 0.15
var _avvärj_mål: Enemy = null
func _avvärj_index() -> int:
	_avvärj_mål = null
	var värst_skada := 0.0
	for rad in inkommande():
		var e: Enemy = rad["enemy"]
		if e.frozen > 0:
			continue
		var d := float(rad["damage"])
		if d > värst_skada:
			värst_skada = d
			_avvärj_mål = e
	if _avvärj_mål == null or värst_skada < hp * AVVÄRJ_ANDEL:
		_avvärj_mål = null
		return -1
	for i in hand.size():
		var c: Cards.Card = hand[i]
		if c.is_wild() or c.keywords.has("Destroy") or c.cost > mana:
			continue
		for eff in c.effects:
			if str(eff.get("op", "")) == "freeze":
				return i
	_avvärj_mål = null
	return -1

## Bästa spelbara kortet just nu, eller -1. Reglerna står i auto_play().
func _best_index(allow_wilds: bool) -> int:
	var best := _basta_kort(true)        # 1. fortsätt kedjan
	if best >= 0:
		return best
	best = _basta_kort(false)            # 3. börja en ny kedja
	if best >= 0:
		return best
	# Ingen ny kedja heller. En wild kan öppna en — men bara då, och bara om den finns.
	if allow_wilds:
		for i in hand.size():
			if hand[i].is_wild():
				return i
	return -1

## Starkaste spelbara kortet, med eller utan kravet att det fortsätter kedjan.
## Sorteringsnyckeln är (kostnad, roll, namn): billigast först, och därför blir en ny kedja en
## stigande trappa så länge handen räcker.
func _basta_kort(maste_fortsatta: bool) -> int:
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
		if maste_fortsatta and card.cost <= last_cost:
			continue
		if not maste_fortsatta and card.cost == last_cost and last_cost != Rules.NO_CARD_YET:
			continue                     # samma steg bryter kedjan utan att höja den
		# Kostnaden är FÖRST (kedjan är en stigande trappa), och inom samma kostnad går ett kort som
		# stannar i spel före ett engångskort: det lägger sin effekt på bordet och betalar igen nästa
		# tur. Regeln står överst i avsnittet (regel 7).
		var key := [card.cost, 0 if card.duration > 0 else 1, HandView.role(card), card.name]
		if best < 0 or _less(key, best_key):
			best = i
			best_key = key
	return best

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

## KEDJAN KORTET FAKTISKT FÅR — EN regel, läst av både `play` och `preview`.
## - Kedjan måste fortsätta: kostnaden ska öka (wild är en bro och ger ingen egen multiplikator).
## - Kortet får VÄGRA sin multiplikator (M119, referensens `ReceivesComboMultiplier` per kort). Steget
##   i kedjan räknas ändå vidare, för nästa kort.
## - Kedjan kan vara LÅST bakom en relik (se `KEDJAN_KRÄVER_RELIK`).
## Låg de två första på varsitt ställe (en i `play`, en i `preview`) visade förhandsvisningen en
## multiplikator som kortet inte fick: samma klass av fel som telegrammet finns för att förhindra.
func _combo_used(card: Cards.Card) -> int:
	if KEDJAN_KRÄVER_RELIK and combo_bonus <= 0:
		return 0                     # ingen Kedjesten: ingen multiplikator
	if not Rules.continues_chain(card.cost, last_cost):
		return 0
	if not card.receives_combo:
		return 0
	return combo

## KEDJAN SOM BELÖNING (M125, ratt B, docs/balans.md §8): referensen kräver relicen Combo Stack för
## `ReceivesComboMultiplier` — multiplikatorn är en VINST, inte grundtillståndet.
##
## MÄTT 15/10 med flaggan PÅ: **0 av 90** körningar klarar banorna (slump 0, auto 0, rutt 0, mål 0,
## avvärj 1). Vår lek är balanserad RUNT att kedjan alltid ligger på — multiplikatorn är skademotorn
## (×2 till ×4 på varje kort), inte en krydda. Att kopiera referensens modell genom att vända en
## flagga tar bort motorn: kortens grundskada skulle först behöva höjas i samma veva, och det är
## kortens egen balans (Alex'), inte en ratt. Flaggan står därför kvar på false med mätningen
## dokumenterad — inte som en glömd ratt.
const KEDJAN_KRÄVER_RELIK := false

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
	var combo_used := _combo_used(card)
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
				var dmg := Rules.damage(float(effect.get("damage", 0.0)) + float(sten.get("damage", 0)) + relic_damage,
					combo_used, base, hits, might, area, gems)
				total += _deal(dmg, int(hits), target, r)
			"armor":
				armor += float(effect.get("amount", 0.0))
			"heal":
				var hp_before := hp
				hp = min(max_hp, hp + float(effect.get("amount", 0.0)))
				r.hp += int(round(hp - hp_before))
			"mana":
				var m := int(effect.get("amount", 0))
				mana += m
				r.mana += m
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
		var gm := int(sten.get("mana", 0))
		mana += gm
		r.mana += gm
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
