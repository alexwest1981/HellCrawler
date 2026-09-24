## Metan: guldet, de permanenta uppgraderingarna och sparfilen. Överlever körningar — det är hela
## poängen med en roguelite: körningen tar slut, byn består.
##
## Filen är JSON med `save_version` från första versionen, skrivs ATOMISKT (till en temp-fil och
## byter namn) så en krasch halvvägs inte kan lämna en halv sparfil, och en trasig fil DÖPS OM
## i stället för att skrivas över — annars förstör en bugg i inläsningen spelarens framsteg utan
## att någon får veta det. Saknad fil är däremot normalt: det är en ny spelare, inte ett fel.
##
##   var meta := Meta.load_or_new()
##   meta.buy("might")
##   meta.save()
class_name Meta
extends RefCounted

const SAVE_VERSION := 5
## Fotoläget (`-- shot`, `-- skarmar` m.fl.) får en EGEN fil. En skärmbilds- eller demokörning
## får aldrig kunna skriva i spelarens profil: mätt innan den här raden fanns gick guldet
## 1852 -> 237 av en körning som bara skulle fotografera kartan.
static var PATH := "user://save.json"

static func fotolage(pa: bool) -> void:
	PATH = "user://save_prov.json" if pa else "user://save.json"
const DEFS_PATH := "res://data/powerups.json"
const CRAWLERS_PATH := "res://data/crawlers/00_kamrater.json"
const TREE_PATH := "res://data/tree.json"
const GEMS_PATH := "res://data/gems.json"
const GRADER := ["simpel", "fin", "god", "praktfull", "utsökt"]   ## 0..4, simpel -> utsökt
const FIRST_STAGE := "stage_01"    ## ny spelare har alltid den här banan öppen

var gold := 0
## SPLITTER (M57): den unika valutan. Den finns bara i kistorna på banorna — inte i butiken — och
## trädets permanenta noder (mana, hälsa, rustning) kostar den. Guldet räcker alltså inte till allt:
## de köp som gäller för all framtid kräver att man går ner och hämtar dem.
var shards := 0
## Corrupted Souls (CS): trädets valuta. Skild från guldet med flit — trädet ska inte kunna köpas
## med pengar man råkar ha i fickan, utan bara med sådant som bossar släpper ifrån sig.
var souls := 0
## ÄDELSTENARNA (M58): fickan, facken och det som sitter i korten.
##   gems:     familj -> [antal per grad 0..4]   (0 = simpel, 4 = utsökt)
##   gem_slots: kort-id -> antal öppnade fack (0-4, köps hos juveleraren)
##   gem_in:   kort-id -> fackens innehåll, fyra platser, null = tomt
var gems: Dictionary = {}
var gem_slots: Dictionary = {}
var gem_in: Dictionary = {}
var ranks: Dictionary = {}        ## id -> rang
var relics: Array = []
var language := Tr.SOURCE         ## språkvalet sparas: en gång valt ska det gälla nästa gång
var unlocked: Array = [FIRST_STAGE]   ## upplåsta banor. En lista, inte ett träd: banorna låses upp
                                      ## i svårighetsordning, så nästa bana är alltid nästa i listan.
var best_floor: Dictionary = {}   ## bana -> högsta våning man nått (1-baserat, 0 = aldrig varit där)
var runs := 0                     ## avslutade körningar, för byn och framtida prestationer
var hired: Array = []             ## hyrda kamrater (samma id som deras kort i data/cards)
## Den PERMANENTA kortsamlingen (M45): kort man vunnit av en boss. Id:n, inte kortobjekt, av samma
## skäl som allt annat i sparfilen — datat kan ändras utan att filen börjar ljuga. Samlingen är
## tillgänglig mellan alla banor: den ligger i startleken och visas i albumet.
var samling: Array = []
var crawlers: Array = []          ## kamraterna som går att hyra, ur data/crawlers
var gem_defs: Array = []          ## ädelstenarna, ur data/gems.json
var version := SAVE_VERSION
var defs: Array = []              ## uppgraderingarna, läsna ur data/powerups.json
var last_error := ""              ## satt när filen fanns men inte gick att läsa
## Inställningarna från startmenyns ALTERNATIV (M39). Standard är på: CRT-känslan och musiken hör till
## spelet, och en spelare som inte letat upp alternativen ska få dem.
var crt_på := true
var musik_på := true
## Den SPARADE KÖRNINGEN: "LADDA SPEL" i menyn återupptar den. Id:n och tal, inte kortobjekt — korten
## byggs ur datat igen, så en sparfil som bara bär id:n inte kan ljuga om vad ett kort gör när datat
## ändras. Tom = ingen körning att fortsätta (då är raden i menyn mörk och säger varför).
var korning: Dictionary = {}

## Läs sparfilen. Saknas den: en ny spelare. Går den inte att läsa: lägg den åt sidan och börja
## om, med skälet i last_error — spelaren ska få veta att något hände, inte tappa sina framsteg
## i tysthet.
static func load_or_new(path: String = PATH) -> Meta:
	var m := Meta.new()
	m._load_defs()
	m._load_crawlers()
	m._load_gems()
	if not FileAccess.file_exists(path):
		return m
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		m.last_error = "kunde inte öppna %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		return m
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		m.last_error = "%s är inte en sparfil (trasig JSON)" % path
		m._set_aside(path)
		return m
	var v := int(parsed.get("save_version", 0))
	if v > SAVE_VERSION:
		# En nyare version än vad spelet känner: rör den inte, spela utan meta i stället.
		m.last_error = "sparfilen är version %d, spelet klarar %d — spelar utan meta" % [v, SAVE_VERSION]
		return m
	m.gold = int(parsed.get("gold", 0))
	m.relics = parsed.get("relics", [])
	m.language = str(parsed.get("language", Tr.SOURCE))
	# Upplåsningen kom i version 2. En version 1-fil har spelat klart banor utan att någon skrev
	# ner det, så den får behålla sitt guld och sina ranger men börjar med bara första banan öppen
	# — alternativet vore att gissa vilka banor spelaren klarat, och en gissning som ger fel bana
	# är värre än en som ger en att spela igen.
	m.unlocked = parsed.get("unlocked", [FIRST_STAGE])
	m.best_floor = parsed.get("best_floor", {})
	m.runs = int(parsed.get("runs", 0))
	# Kamraterna kom i version 3. Äldre filer har inga hyrda, vilket är samma sak som en ny spelare.
	m.hired = parsed.get("hired", [])
	# Den permanenta kortsamlingen kom i version 4 (bossens byte). En version 3-fil har spelat utan
	# samling, och en tom samling är samma sak som en ny spelares.
	m.samling = parsed.get("samling", [])
	# Splitter och ädelstenar kom i version 5. En version 4-fil har varken valutan eller stenarna,
	# och tom ficka är samma sak som en ny spelares — inget guld räknas om till splitter, för
	# valutan ska bara finnas i kistorna.
	m.shards = int(parsed.get("shards", 0))
	var g = parsed.get("gems", {})
	m.gems = g if typeof(g) == TYPE_DICTIONARY else {}
	var gs = parsed.get("gem_slots", {})
	m.gem_slots = gs if typeof(gs) == TYPE_DICTIONARY else {}
	var gi = parsed.get("gem_in", {})
	m.gem_in = gi if typeof(gi) == TYPE_DICTIONARY else {}
	# Menyns inställningar och den sparade körningen (M39): en äldre fil saknar dem, och standarden
	# (på/på/ingen körning) är samma sak som en ny spelare.
	m.crt_på = bool(parsed.get("crt", true))
	m.musik_på = bool(parsed.get("musik", true))
	var sparad = parsed.get("korning", {})
	m.korning = sparad if typeof(sparad) == TYPE_DICTIONARY else {}
	if m.unlocked.is_empty():
		m.unlocked = [FIRST_STAGE]
	var r = parsed.get("ranks", {})
	if typeof(r) == TYPE_DICTIONARY:
		for k in r:
			m.ranks[str(k)] = int(r[k])
	m.version = v
	m._clamp_ranks()
	return m

## Lägg den trasiga filen åt sidan BREDVID sig själv: samma namn + .trasig. Ett fast namn hade
## kolliderat mellan den riktiga sparfilen och ett provs fil, och skrivit över den ena med den andra.
func _set_aside(path: String) -> void:
	var d := DirAccess.open(path.get_base_dir())
	if d != null:
		d.rename(path.get_file(), path.get_file() + ".trasig")

## Rangen får aldrig överstiga kortets tak: en handredigerad sparfil ska inte kunna ge rang 99.
func _clamp_ranks() -> void:
	for def in defs:
		var id := str(def.get("id", ""))
		var maks := int(def.get("max_rank", 0))
		if ranks.has(id):
			ranks[id] = clampi(int(ranks[id]), 0, maks)

## Uppgraderingarna = butikens åtta PLUS trädets noder, i samma lista. Samma köpväg, samma `stat()`,
## samma sparfil: skillnaden är att trädets noder har `branch` och `requires`, och därför ritas som
## ett nät i stället för som en radlista. Att ha två köpsystem hade gett två ställen att rätta
## balansen på.
func _load_defs() -> void:
	var text := FileAccess.get_file_as_string(DEFS_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("kunde inte läsa %s" % DEFS_PATH)
		return
	defs = parsed
	var träd = JSON.parse_string(FileAccess.get_file_as_string(TREE_PATH))
	if typeof(träd) == TYPE_ARRAY:
		# TRÄDEDITORNS VAL GÅR FÖRE DEN GENERERADE NODEN. Noden har redan en `effect` från
		# tools/gen_tree.py; kryssar man egna uppgraderingar i editorn ligger de i socketfilen, och då
		# ersätter de den genererade effekten helt (inte en blandning — det vore två sanningar om
		# samma nod). Är inget ikryssat är noden orörd.
		var sockets: Dictionary = TreeSockets.load_all()
		var kända := {}
		for def in träd:
			var id := str(def.get("id", ""))
			kända[id] = true
			var post: Dictionary = sockets.get(id, {})
			var effekt: Dictionary = TreeSockets.effect_of(post)
			if not effekt.is_empty():
				def["effect"] = effekt
				def["text"] = TreeSockets.text_of(post)
				def["edited"] = true
			# Kopplingen ritad i editorn bestämmer VILKA noder den här väntar på. Utan den vore
			# låsordningen den generatorn skrev, och en handritad kedja hade bara varit en bild.
			if post.has("requires"):
				def["requires"] = post["requires"]
				def["edited"] = true
			# Grafiken vald i editorn (eld, is, magi) följer med noden in i vyn.
			if not str(post.get("graphics", "")).is_empty():
				def["graphics"] = post["graphics"]
		# NODER SOM LAGTS TILL I EDITORN (+): de finns bara i socketfilen, och blir noder i trädet när
		# filen säger det — med sin egen gren, nivå, kostnad och sina egna uppgraderingar. Utan det här
		# syntes de i editorn men inte i spelet, och "+" hade varit en knapp som inte gjorde något.
		for id in sockets:
			var post: Dictionary = sockets[id]
			if kända.has(str(id)) or not bool(post.get("added", false)):
				continue
			var ny: Dictionary = TreeSockets.def_of(post)
			if str(ny.get("branch", "")).is_empty():
				continue
			träd.append(ny)
		defs += träd
	else:
		push_error("kunde inte läsa %s" % TREE_PATH)

func _load_crawlers() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CRAWLERS_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("kunde inte läsa %s" % CRAWLERS_PATH)
		return
	crawlers = parsed

## --- uppgraderingarna --------------------------------------------------------

func rank(id: String) -> int:
	return int(ranks.get(id, 0))

func is_maxed(id: String) -> bool:
	var def := def_for(id)
	return def.is_empty() or rank(id) >= int(def.get("max_rank", 0))

func def_for(id: String) -> Dictionary:
	for d in defs:
		if str(d.get("id", "")) == id:
			return d
	return {}

## Vad nästa rang kostar, eller -1 när den är full.
func next_cost(id: String) -> int:
	if is_maxed(id):
		return -1
	var costs: Array = def_for(id).get("cost", [])
	var r := rank(id)
	return int(costs[r]) if r < costs.size() else -1

## Vad nästa rang kostar i SPLITTER (M57). En nod kan kosta den unika valutan i stället för guld —
## aldrig båda — och då står `cost` kvar som nollor i datat, för formen är densamma. Poängen är att
## de permanenta noderna inte går att köpa hur mycket guld banken än bär.
func next_shard_cost(id: String) -> int:
	if is_maxed(id):
		return -1
	var costs: Array = def_for(id).get("shard_cost", [])
	var r := rank(id)
	return int(costs[r]) if r < costs.size() else 0

func kostar_splitter(id: String) -> bool:
	return def_for(id).has("shard_cost")

## Trädets noder betalas med CS. Grenen är kännetecknet — samma som village_lines() använder för att
## skilja trädet från uppgraderingarna, så en nod kan inte hamna i två fickor — och CS-priset måste
## FINNAS i datat. Utan det kravet blev en nod utan soul_cost gratis i stället för dyr, vilket är
## den värsta sortens tysta fel: provet visade "0 CS ✓" på en nod som skulle kosta.
func kostar_sjal(id: String) -> bool:
	var def := def_for(id)
	return not str(def.get("branch", "")).is_empty() and def.has("soul_cost")

## Priset i CS för nästa rang. Saknas raden i datat kostar nästa rang ingenting — då är noden
## billigare än tänkt, inte oåtkomlig.
func next_soul_cost(id: String) -> int:
	if is_maxed(id):
		return -1
	var costs: Array = def_for(id).get("soul_cost", [])
	var r := rank(id)
	return int(costs[r]) if r < costs.size() else 0

func add_souls(n: int) -> void:
	souls = max(0, souls + n)

## Kan den köpas? Skälet i klartext, så UI:t aldrig behöver gissa varför knappen inte gör något.
func can_buy(id: String) -> Dictionary:
	if def_for(id).is_empty():
		return {"ok": false, "reason": "okand"}
	if is_maxed(id):
		return {"ok": false, "reason": "full"}
	if not requires_met(id):
		return {"ok": false, "reason": "kraver", "krav": missing_requirement(id)}
	if kostar_sjal(id):
		if souls < next_soul_cost(id):
			return {"ok": false, "reason": "for_lite_cs", "pris": next_soul_cost(id)}
	elif kostar_splitter(id):
		if shards < next_shard_cost(id):
			return {"ok": false, "reason": "for_lite_splitter", "pris": next_shard_cost(id)}
	else:
		if gold < next_cost(id):
			return {"ok": false, "reason": "for_lite_guld"}
	return {"ok": true, "reason": ""}

## Trädets noder kräver varandra: en nod öppnas när dess förälder är FULLT uppgraderad.
##
## Alex: *"Jag vill ha dem så de bara blir tillgängliga när noden innan är fullt uppgraderad."*
## Ändrat från `rank(krav) < 1` (köpt en gång räckte): den regeln gjorde trädet till en solfjäder man
## kunde breda ut sig i. Nu måste en nod bli klar innan nästa i samma gren öppnar.
##
## Både `requires_met` och `missing_requirement` går genom samma kontroll, så UI:ts skäl i klartext
## aldrig kan säga något annat än knappen gör — inte ens när regeln ändras igen.
func _krav_kvar(id: String) -> String:
	for krav in def_for(id).get("requires", []):
		if not is_maxed(str(krav)):
			return str(krav)
	return ""


func requires_met(id: String) -> bool:
	return _krav_kvar(id).is_empty()


## Första oköpta kravet, i klartext — "LÅST" utan att säga av vad är en återvändsgränd.
func missing_requirement(id: String) -> String:
	var krav := _krav_kvar(id)
	return def_name(krav) if not krav.is_empty() else ""

## Namnet på en uppgradering eller en trädnod. Nyckeln kommer ur datat (powerup.<id> / tree.<id>),
## precis som för korten: en ny nod får ett värde att översätta utan att någon kod ändras.
## Trädets noder står på svenska i tree.json, så utan det här stod smeden på svenska i varje körning.
func def_name(id: String) -> String:
	var d := def_for(id)
	var sort := "tree" if not str(d.get("branch", "")).is_empty() else "powerup"
	return Tr.name_of(sort, id, str(d.get("name", id)))

## (missing_requirement ligger ovanför def_name, tillsammans med _krav_kvar — en definition, en regel.)

func buy(id: String) -> Dictionary:
	var v := can_buy(id)
	if not v.ok:
		return v
	# Priset dras ur RÄTT ficka: splitter för de permanenta noderna, guld för resten. Mätt i provet
	# test_meta: en splitter-nod lämnar guldet orört och tvärtom.
	if kostar_sjal(id):
		souls -= next_soul_cost(id)
	elif kostar_splitter(id):
		shards -= next_shard_cost(id)
	else:
		gold -= next_cost(id)
	ranks[id] = rank(id) + 1
	return {"ok": true, "reason": "", "rank": ranks[id]}

## Summan av en effektnyckel över alla ranger, t.ex. stat("might") = 0.3 vid tre ranger.
## Talet används rakt av i striden, så en ny uppgradering är en rad i JSON — inte en kodändring.
##
## Hyrda kamrater räknas in HÄR, inte i Run. Då får varje konsument sin kamratpåverkan utan en rad
## kod per stat: HP, mana, hand, rustning, läkning och skada läser alla samma funktion.
func stat(key: String) -> float:
	var sum := 0.0
	for d in defs:
		var eff: Dictionary = d.get("effect", {})
		if eff.has(key):
			sum += float(eff[key]) * float(rank(str(d.get("id", ""))))
	for id in hired:
		var kamrat: Dictionary = crawler_for(str(id)).get("passiv", {})
		if kamrat.has(key):
			sum += float(kamrat[key])
	return sum

func add_gold(n: int) -> void:
	gold = max(0, gold + n)

## --- kamraterna: hjältar man hyr, som egna kort i leken -----------------------

func _load_gems() -> void:
	gem_defs = []
	var text := FileAccess.get_file_as_string(GEMS_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("kunde inte läsa %s" % GEMS_PATH)
		return
	gem_defs = parsed

func gem_for(fam: String) -> Dictionary:
	for g in gem_defs:
		if str(g.get("id", "")) == fam:
			return g
	return {}

## Stenens verkan i en viss grad: värdet ur `grad`-listan, t.ex. ember grad 3 = 5 skada.
func gem_value(fam: String, grad: int) -> int:
	var g := gem_for(fam)
	var lista: Array = g.get("grad", [])
	if grad < 0 or grad >= lista.size():
		return 0
	return int(lista[grad])

func gem_text(fam: String, grad: int) -> String:
	var g := gem_for(fam)
	return str(g.get("text", "%d")) % gem_value(fam, grad)

func gem_name(fam: String, grad: int) -> String:
	return "%s (%s)" % [str(gem_for(fam).get("name", fam)), GRADER[clampi(grad, 0, 4)]]

## --- fickan -------------------------------------------------------------------
func gem_count(fam: String, grad: int) -> int:
	var rad: Array = gems.get(fam, [])
	if grad < 0 or grad >= rad.size():
		return 0
	return int(rad[grad])

func gem_add(fam: String, grad: int, n: int = 1) -> void:
	grad = clampi(grad, 0, GRADER.size() - 1)
	var rad: Array = gems.get(fam, [0, 0, 0, 0, 0])
	while rad.size() < GRADER.size():
		rad.append(0)
	rad[grad] = int(rad[grad]) + n
	gems[fam] = rad

## Tar en sten ur fickan. Falskt om den inte finns — anroparen får säga varför.
func gem_take(fam: String, grad: int) -> bool:
	if gem_count(fam, grad) <= 0:
		return false
	gem_add(fam, grad, -1)
	return true

func gem_bag() -> Array:
	var ut := []
	for fam in gems:
		var rad: Array = gems[fam]
		for grad in rad.size():
			if int(rad[grad]) > 0:
				ut.append({"fam": str(fam), "grad": grad, "antal": int(rad[grad])})
	return ut

## --- facken i korten ----------------------------------------------------------
## Priset stiger per fack: ett kort med fyra fack är ett långtidsprojekt, inte ett impulsköp.
const SLOT_PRIS := [300, 900, 2200, 5000]

func gem_slots_for(card_id: String) -> int:
	return int(gem_slots.get(card_id, 0))

func gem_slot_cost(card_id: String) -> int:
	var n := gem_slots_for(card_id)
	if n >= SLOT_PRIS.size():
		return 0
	return int(SLOT_PRIS[n])

func gem_in_slot(card_id: String, slot: int) -> Dictionary:
	var fack: Array = gem_in.get(card_id, [])
	if slot < 0 or slot >= fack.size():
		return {}
	var s = fack[slot]
	return s if typeof(s) == TYPE_DICTIONARY else {}

## Öppnar nästa fack i kortet för guld. Fyra är taket.
func buy_gem_slot(card_id: String) -> Dictionary:
	var n := gem_slots_for(card_id)
	if n >= SLOT_PRIS.size():
		return {"ok": false, "reason": "alla fack är öppna", "pris": 0}
	var pris: int = int(SLOT_PRIS[n])
	if gold < pris:
		return {"ok": false, "reason": "guldet räcker inte", "pris": pris}
	gold -= pris
	gem_slots[card_id] = n + 1
	return {"ok": true, "reason": "", "pris": pris, "fack": n + 1}

## Sätter en sten ur fickan i ett fack. Stenen lämnar fickan: samma sten kan inte sitta på två kort.
func socket(card_id: String, slot: int, fam: String, grad: int) -> Dictionary:
	if slot < 0 or slot >= gem_slots_for(card_id):
		return {"ok": false, "reason": "facket finns inte"}
	if not gem_in_slot(card_id, slot).is_empty():
		return {"ok": false, "reason": "facket är upptaget"}
	if not gem_take(fam, grad):
		return {"ok": false, "reason": "stenen finns inte i fickan"}
	var fack: Array = gem_in.get(card_id, [])
	while fack.size() < gem_slots_for(card_id):
		fack.append(null)
	fack[slot] = {"fam": fam, "grad": grad}
	gem_in[card_id] = fack
	return {"ok": true, "reason": ""}

## Plockar ur ett fack och lägger stenen tillbaka i fickan.
func unsocket(card_id: String, slot: int) -> Dictionary:
	var s := gem_in_slot(card_id, slot)
	if s.is_empty():
		return {"ok": false, "reason": "facket är tomt"}
	var fack: Array = gem_in.get(card_id, [])
	fack[slot] = null
	gem_in[card_id] = fack
	gem_add(str(s["fam"]), int(s["grad"]))
	return {"ok": true, "reason": ""}

## Vad stenarna i ETT kort ger. Nycklarna är stridens: damage, qty (träffar), armor, mana, gold.
func gem_bonus(card_id: String) -> Dictionary:
	var ut := {}
	for i in gem_slots_for(card_id):
		var s := gem_in_slot(card_id, i)
		if s.is_empty():
			continue
		var fam := str(s["fam"])
		var nyckel := str(gem_for(fam).get("key", ""))
		if nyckel.is_empty():
			continue
		ut[nyckel] = int(ut.get(nyckel, 0)) + gem_value(fam, int(s["grad"]))
	return ut

## Alla kort med stenar: kort-id -> bonuskarta. Striden får den här en gång per körning i stället för
## att fråga metat för varje spelat kort.
func gem_bonus_all() -> Dictionary:
	var ut := {}
	for card_id in gem_in:
		var b := gem_bonus(str(card_id))
		if not b.is_empty():
			ut[str(card_id)] = b
	return ut

## Vilken sten en kista ger. REN funktion — den lägger inget i fickan; körningen bär sina fynd och
## banken får dem först när körningen tar slut (samma regel som guldet). Slumpen kommer från
## körningens egen ström, så samma kista ger samma sten varje gång.
##
## Graden stiger med DJUPET: en simpel sten ligger på våning 1, en utsökt hittar man bara djupt nere.
func pick_sten(våning: int, rng: RandomNumberGenerator) -> Dictionary:
	if gem_defs.is_empty():
		return {}
	var fam := str(gem_defs[rng.randi_range(0, gem_defs.size() - 1)].get("id", ""))
	var bas := clampi(int(round(float(våning - 1) * 0.9)), 0, GRADER.size() - 1)
	var grad := clampi(bas + (1 if rng.randi_range(0, 9) < 4 else 0), 0, GRADER.size() - 1)
	return {"fam": fam, "grad": grad}

## Hur mycket splitter en kista på den våningen ger. Djupet betalar: våning 1 ger 1, våning 5 ger 3.
static func kista_splitter(våning: int) -> int:
	return clampi(1 + int(round(float(våning - 1) * 0.5)), 1, 4)

func crawler_for(id: String) -> Dictionary:
	for c in crawlers:
		if str(c.get("id", "")) == id:
			return c
	return {}

func is_hired(id: String) -> bool:
	return hired.has(id)

## Kan kamraten hyras? Skälet i klartext, som för uppgraderingarna.
func can_hire(id: String) -> Dictionary:
	var c := crawler_for(id)
	if c.is_empty():
		return {"ok": false, "reason": "okand"}
	if hired.has(id):
		return {"ok": false, "reason": "redan_hyrd"}
	if gold < int(c.get("price", 0)):
		return {"ok": false, "reason": "for_lite_guld"}
	return {"ok": true, "reason": ""}

## Hyr en kamrat: guldet dras en gång, och kortet ligger i startleken för alla kommande körningar.
func hire(id: String) -> Dictionary:
	var v := can_hire(id)
	if not v.ok:
		return v
	gold -= int(crawler_for(id).get("price", 0))
	hired.append(id)
	return {"ok": true, "reason": "", "price": int(crawler_for(id).get("price", 0))}

## --- den permanenta kortsamlingen (bossens byte, M45) ------------------------

## Lägg ett kort i den permanenta samlingen. Dubbletter är tillåtna med flit: två exemplar av samma
## kort är två kort i startleken, precis som i referensen.
func samla(id: String) -> bool:
	if id.is_empty():
		return false
	samling.append(id)
	return true

## Samlingen som en egen lista (main bygger startleken ur den).
func samlade_kort() -> Array:
	return samling.duplicate()

## Kamraterna som en läsbar radlista för värdshuset — samma form som butikens.
func crawler_lines() -> Array:
	var out := []
	for i in crawlers.size():
		var c: Dictionary = crawlers[i]
		var id := str(c.get("id", ""))
		out.append({
			"key": str(i + 1),
			"id": id,
			# Namnet är KORTETS: den hyrda kamraten läggs i leken som sitt eget kort, och båda
			# nycklarna (crawler.<id> / card.<id>) kommer ur samma data.
			"name": Tr.name_of("crawler", id, Tr.name_of("card", id, str(c.get("name", id)))),
			"price": int(c.get("price", 0)),
			"text": Tr.t("crawler.%s.text" % id, str(c.get("text", ""))),
			"hired": is_hired(id),
			"affordable": gold >= int(c.get("price", 0)),
		})
	return out

## --- upplåsningen -------------------------------------------------------------

func is_unlocked(stage_id: String) -> bool:
	return unlocked.has(stage_id)

## Lås upp en bana. Returnerar true bara när den var ny, så UI:t kan visa det en gång.
func unlock(stage_id: String) -> bool:
	if stage_id.is_empty() or unlocked.has(stage_id):
		return false
	unlocked.append(stage_id)
	return true

## Körningen är slut: skriv ner hur långt man kom och lås upp nästa bana om man nådde sista
## våningen. `order` är ban-id i svårighetsordning — nästa bana är nästa i den listan, så
## upplåsningen följer samma ordning som kartan visar. Returnerar den nyupplåsta banan, annars "".
func note_run(stage_id: String, floor_reached: int, last_floor: int, order: Array) -> String:
	runs += 1
	if floor_reached > int(best_floor.get(stage_id, 0)):
		best_floor[stage_id] = floor_reached
	if floor_reached < last_floor:
		return ""
	var i := order.find(stage_id)
	if i < 0 or i + 1 >= order.size():
		return ""
	var nästa := str(order[i + 1])
	return nästa if unlock(nästa) else ""

## Uppgraderingens rad: formen är översatt, siffran kommer ur `effect` i data/powerups.json.
## Texten kan därför inte säga en sak och koden göra en annan — den gamla area-raden påstod "+2 %
## skada" medan `Rules.damage` gav area/5 = +10 % per rang.
##
##   effect {"might": 0.1}       -> +10 % skada per rang
##   effect {"area": 0.5}        -> +10 % skada per rang (area/5: 0.5/5)
##   effect {"curse": 0.2}       -> två tal, samma värde (fiende-HP och guld)
const PROCENT_PER_ENHET := {"might": 100.0, "area": 20.0, "curse": 100.0}

func powerup_text(d: Dictionary) -> String:
	var eff: Dictionary = d.get("effect", {})
	var id := str(d.get("id", ""))
	var mall := Tr.t("powerup.%s.fmt" % id, str(d.get("text", "")))
	var tal: Array = []
	for nyckel in ["might", "area", "mana", "hand", "armor", "recovery", "max_hp", "curse"]:
		if eff.has(nyckel):
			tal.append(float(eff[nyckel]) * float(PROCENT_PER_ENHET.get(nyckel, 1.0)))
	if id == "curse" and tal.size() == 1:
		tal.append(tal[0])          # förbannelsen höjer både fiende-HP och guld med samma tal
	return mall % tal if not tal.is_empty() else mall

## Alla uppgraderingar som en läsbar radlista för byns butik. Trädets noder hoppas över: de hör till
## smeden, där de ritas med sina förkunskaper i stället för som en platt lista på 30 rader.
func village_lines() -> Array:
	var out := []
	for i in defs.size():
		var d: Dictionary = defs[i]
		if not str(d.get("branch", "")).is_empty():
			continue
		var id := str(d.get("id", ""))
		var maks := int(d.get("max_rank", 0))
		var r := rank(id)
		var pris := next_cost(id)
		out.append({
			"key": str(out.size() + 1),
			"id": id,
			"name": Tr.name_of("powerup", id, str(d.get("name", id))),
			"rank": r,
			"max_rank": maks,
			"cost": pris,
			"text": powerup_text(d),
			"affordable": pris >= 0 and gold >= pris,
		})
	return out

## --- trädet: smedens nodnät --------------------------------------------------

## Grenens namn i det aktuella språket. Nyckeln kommer ur datats eget namn (källspråket), så en gren
## som läggs till i trädet får ett värde att översätta utan en kodändring.
func branch_name(branch: String) -> String:
	return Tr.t("tree.branch.%s" % branch.to_lower(), branch)

func branches() -> Array:
	var out := []
	for d in defs:
		var b := str(d.get("branch", ""))
		if not b.is_empty() and not out.has(b):
			out.append(b)
	# Namnen är översatta i stället för datats egna: smeden skriver grenen i sin titel, och en svensk
	# gren i en tysk körning är samma fel som en svensk sträng i koden.
	for i in out.size():
		out[i] = branch_name(str(out[i]))
	return out

## En gren som en radlista. `låst` betyder att förkunskaperna inte är köpta, och `krav` säger vilken.
## `branch` är grenens NAMN i det aktuella språket (samma sträng som `branches()` ger), för det är
## den skalet håller i handen när det växlar gren.
func tree_lines(branch: String) -> Array:
	var out := []
	for d in defs:
		if branch_name(str(d.get("branch", ""))) != branch:
			continue
		var id := str(d.get("id", ""))
		out.append({
			"key": str(out.size() + 1),
			"id": id,
			"name": def_name(id),
			"rank": rank(id),
			"max_rank": int(d.get("max_rank", 0)),
			"cost": next_cost(id),
			"splitter": kostar_splitter(id),
			"shard_cost": next_shard_cost(id),
			"text": Tr.t("tree.%s.text" % id, str(d.get("text", ""))),
			"låst": not requires_met(id),
			"krav": missing_requirement(id),
			"affordable": can_buy(id).ok,
		})
	return out

## --- sparfilen ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"save_version": SAVE_VERSION, "gold": gold, "ranks": ranks.duplicate(),
		"relics": relics.duplicate(), "language": language, "unlocked": unlocked.duplicate(),
		"best_floor": best_floor.duplicate(), "runs": runs, "hired": hired.duplicate(),
		"samling": samling.duplicate(),
		"shards": shards, "gems": gems.duplicate(true), "gem_slots": gem_slots.duplicate(),
		"gem_in": gem_in.duplicate(true),
		"crt": crt_på, "musik": musik_på, "korning": korning.duplicate(true)}

func save(path: String = PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "kunde inte skriva %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
		return false
	f.store_string(JSON.stringify(to_dict(), "  "))
	f.close()
	# Byt namn i stället för att skriva över: antingen finns hela filen eller den gamla kvar.
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		last_error = "kunde inte öppna mappen för %s" % path
		return false
	if d.file_exists(path.get_file()):
		d.remove(path.get_file())
	var err := d.rename(tmp.get_file(), path.get_file())
	if err != OK:
		last_error = "kunde inte byta namn på %s (%s)" % [tmp, error_string(err)]
		return false
	version = SAVE_VERSION
	return true
