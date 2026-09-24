class_name TreeSockets
extends RefCounted

## The socket file: where every tree node sits on the plate image. One home for the format, so the
## view that draws the nodes and the editor that places them can never disagree about it.
##
## Written by tools/gen_tree_sockets.py (machine measurement) and by the tree editor (a human hand),
## read by game/ui/tree_view.gd. A record is:
##
##   { "id": "iron_1", "x": 0.2012, "y": 0.0986, "r": 0.018, "size": "stor",
##     "effects": ["might", "armor"], "requires": ["iron_main"], "score": 0.064,
##     "guess_x": 0.2348, "guess_y": 0.1289 }
##
## `effects` are the upgrades ticked in the editor, `requires` the nodes this one has to wait for —
## both drawn/locked by hand in tools/trad_editor.sh and folded into the node by Meta. The keys are
## English like the rest of the data (data/tree.json uses `effect` and `requires`).
##
## x and y are fractions of the square plate image (0..1), r the socket's radius in the same unit,
## score how strongly the measurement found a pit there, and guess_x/guess_y where the lattice put it
## before measuring — kept so the editor can reset a node.

## Nodens storlek i TVÅ klasser, inte en fri radie. Plattan har två slags sockets — små gropar
## (radie 0,009, mätta) för små steg och tre stora medaljonger (0,018) för grenarnas huvudnoder — och
## Alex: "det måste gå att ha små noder med ... de skall bidra med små inkrementeringar. Jag behöver
## ha i editorn så jag kan välja liten eller stor nod som grafiskt mål." Klasserna ÄR plattans mått,
## så en liten nod hamnar i en liten grop.
## FYRA klasser, i den ordning Alex bygger trädet: "3 stora, 3 medelstora, 15 små, och 48 små" — alltså
## en trappa Stor -> Medelstor -> Liten -> Pytteliten. Måttet är plattans egna gropar: den vanligaste
## gropen mättes till 0,009 (den ligger på "liten"), medaljongerna till 0,018 ("stor"), och de två
## mittersta är stegen däremellan.
const SIZES := {"stor": 0.018, "medelstor": 0.013, "liten": 0.009, "pytteliten": 0.007}

## Vad en uppgradering ger på en LITEN respektive STOR nod. Ett enda hem för siffrorna: editorn visar
## dem när man kryssar, metan lägger in dem i noden, och vyn skriver dem i hovringstexten. Stegen är
## hälften så stora på en liten nod, för det är vad en liten grop får plats med.
## Ett steg per klass, i samma ordning som SIZES (stor först). Ett kryss kan ges 1-3 steg - Alex:
## "bocka i vad som skall ökas, och hur mycket" - så en stor nod med tre steg är grenens tunga nod.
const VALUES := {
	"might": [0.05, 0.035, 0.02, 0.01],
	"area": [0.12, 0.08, 0.05, 0.02],
	"max_hp": [10.0, 7.0, 4.0, 2.0],
	"armor": [2.0, 2.0, 1.0, 1.0],
	"mana": [2.0, 1.0, 1.0, 1.0],
	"hand": [1.0, 1.0, 1.0, 1.0],
	"gold": [0.15, 0.10, 0.05, 0.02],
	"revive": [2.0, 1.0, 1.0, 1.0],
	"draw_first": [2.0, 1.0, 1.0, 1.0],
}

const STEPS_MAX := 3                       ## flest steg ett kryss kan ges
## IKONLISTAN ÄR FILERNA PÅ DISKEN, inte en lista i koden. Alex: "jag kanske skapar egna ikoner, då
## dessa är rätt platta och inte matchar stilen på spelet än." Då skall han kunna lägga sin PNG i
## game/assets/tree/ och trycka G — ingen kodändring, ingen lista att hålla i takt. Kronringarna
## (namn_krona.png) hoppas över: de är grenens slut, inte en ikon att välja.
const ICON_DIR := "res://assets/tree"
const NAME_SV := {"eld": "Eld", "is": "Is", "magi": "Magi"}

## Vad en nod av klassen kostar i Corrupted Souls. Ett rimligt förval, ärligt utskrivet: en stor nod är
## grenens dyrbara, en pytteliten är billig.
const COST := {"stor": 40, "medelstor": 20, "liten": 8, "pytteliten": 4}

## Statistikorden i klartext, svenska som resten av datat. Används till hovringstexten och till
## editorns rader, så samma kryss beskrivs likadant på båda ställena.
const WORDS := {
	"might": "skada", "area": "område", "max_hp": "liv", "armor": "rustning", "mana": "mana",
	"hand": "kort i handen", "gold": "guld", "revive": "resning", "draw_first": "kort i första handen",
}

const PATH := "res://data/trad_sockets.json"
const IMAGE := "res://images/Gemini_Generated_Image_68qy7x68qy7x68qy.jpeg"
const SIDE := 1024


## id -> record. An empty dictionary means the file is missing or broken; the view then falls back to
## its lattice, which is worse but never nothing.
static func load_all(path: String = PATH) -> Dictionary:
	var out := {}
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return out
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		return out
	for record in data.get("sockets", []):
		if record is Dictionary and record.has("id"):
			out[str(record["id"])] = record
	return out


## The records as a list, in the order given (ids first, then anything else the file had). Writes are
## atomic: a half-written file would leave the tree with sockets in the wrong places and no way to
## tell which half is real.
static func write(records: Array, path: String = PATH) -> bool:
	var temp := path + ".new"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"image": IMAGE,
		"side": SIDE,
		"method": "placed by hand in game/editor/trad_editor.gd, or measured by tools/gen_tree_sockets.py",
		"sockets": records,
	}, " ", false) + "\n")
	file.close()
	return DirAccess.rename_absolute(temp, path) == OK


## A fresh record for a node the file does not know about yet.
static func blank(id: String, x: float, y: float, r: float) -> Dictionary:
	return {"id": id, "x": x, "y": y, "r": r, "score": 0.0, "guess_x": x, "guess_y": y}


## EN NOD SOM LAGTS TILL I EDITORN (+). Den finns inte i data/tree.json — den finns bara i socketfilen,
## och blir en riktig nod i spelet när metan läser filen. Därför bär posten hela definitionen.
static func added_node(id: String, x: float, y: float, branch: String, tier: int,
		graphics: String, klass: String, requires: Array) -> Dictionary:
	var namn: String = "%s %s" % [str(NAME_SV.get(graphics, graphics)), id.split("_")[-1]]
	return {
		"id": id, "x": x, "y": y, "r": float(SIZES.get(klass, SIZES["liten"])),
		"size": klass, "graphics": graphics, "effects": {}, "requires": requires,
		"added": true, "name": namn, "branch": branch, "tier": tier,
		"score": 0.0, "guess_x": x, "guess_y": y,
	}


## Posten som en färdig definition åt metan (samma form som tools/gen_tree.py skriver).
static func def_of(record: Dictionary) -> Dictionary:
	var id := str(record.get("id", ""))
	var klass := size_of(record)
	return {
		"id": id,
		"name": str(record.get("name", id)),
		"branch": str(record.get("branch", "")),
		"tier": int(record.get("tier", 1)),
		"effect": effect_of(record),
		"text": text_of(record),
		"graphics": str(record.get("graphics", "")),
		"cost": [0],
		"soul_cost": [int(COST.get(klass, COST["liten"]))],
		"max_rank": 1,
		"requires": record.get("requires", []),
		"added": true,
	}


## Nodens klass, "liten" eller "stor". Är klassen inte satt gäller den MÄTTA radien: plattans stora
## sockets är dubbelt så stora som de små, och en nod som ligger i en stor grop skall vara en stor nod.
static func size_of(record: Dictionary, nivå: int = 0) -> String:
	var klass := str(record.get("size", ""))
	if SIZES.has(klass):
		return klass
	# Grenens HUVUDNOD står i en medaljong, hur liten gropen än mättes som: den är trädets topp och
	# skall se ut som en sådan. Nivån kommer från vyn eller editorn, som båda vet den.
	if nivå == 1:
		return "stor"
	# Gropen avgör: ju större mätt socket, desto större klass.
	var r: float = float(record.get("r", 0.0))
	for namn in SIZES:
		if r >= float(SIZES[namn]) - 0.0015:
			return namn
	return "pytteliten"


## Klassens plats i trappan (0 = störst), för stegtabellen och för L-tangentens vandring.
static func size_index(klass: String) -> int:
	return maxi(0, SIZES.keys().find(klass))


static func next_size(klass: String) -> String:
	var namn: Array = SIZES.keys()
	return str(namn[(size_index(klass) + 1) % namn.size()])


## Alla ikoner i game/assets/tree/, sorterade. Ett eget verk läggs i mappen och dyker upp här.
static func icon_list() -> Array:
	var ut: Array = []
	var dir := DirAccess.open(ICON_DIR)
	if dir == null:
		return ICONS_FALLBACK.duplicate()
	for fil in dir.get_files():
		# I ett körande spel är filnamnen ".png.import"; i källträdet ".png". Båda duger.
		var namn := str(fil).trim_suffix(".import")
		if not namn.ends_with(".png") or namn.ends_with("_krona.png"):
			continue
		ut.append(namn.trim_suffix(".png"))
	ut.sort()
	return ut if not ut.is_empty() else ICONS_FALLBACK.duplicate()


## Om mappen inte går att läsa (ett paketerat spel) finns de här som sista utväg.
const ICONS_FALLBACK := ["eld", "is", "magi"]


## Grafiken: nodens egen om den valt en, annars grenens ikon.
static func graphics_of(record: Dictionary, branch_icon: String = "") -> String:
	var g := str(record.get("graphics", ""))
	return g if not g.is_empty() else branch_icon


## Radien som hör till klassen (bildandelar). Fri radie finns inte längre i editorn — den valde
## klassen är sanningen, och den följer plattans egna mått.
static func radius_of(record: Dictionary) -> float:
	return float(SIZES.get(size_of(record), SIZES["stor"]))


## Antalet pixlar för en radie, i en vy av höjden `vy_höjd`. ETT hem för räkningen: vyn ritade med
## `r * 2 * höjd * 0.8` och klippte till 12..40 px på två ställen, och editorn räknade på ett tredje.
static func size_px(r: float, view_height: float, platta_sida: float) -> int:
	return int(clampf(r * 2.0 * maxf(platta_sida, 60.0), 6.0, 40.0))


## Uppgraderingarna som är ikryssade på noden, som `effect` för metan: {"might": 0.02, "armor": 1.0}.
## Tomt när inget är ikryssat — då gäller nodens egen `effect` ur data/tree.json orörd.
static func effect_of(record: Dictionary) -> Dictionary:
	var ut := {}
	var spår: int = size_index(size_of(record))
	for typ in record.get("effects", {}):
		var par: Array = VALUES.get(str(typ), [])
		if par.size() == SIZES.size():
			ut[str(typ)] = float(par[spår]) * float(step_of(record, str(typ)))
	return ut


## Hur många steg ett kryss är satt till (1-3), eller 0 när det inte är ikryssat. Ett tal i
## `effects` är stegen; en gammal fil med en lista betyder ett steg per typ.
static func step_of(record: Dictionary, typ: String) -> int:
	var effekt = record.get("effects", {})
	if effekt is Array:
		return 1 if (effekt as Array).has(typ) else 0
	if effekt is Dictionary:
		return clampi(int((effekt as Dictionary).get(typ, 0)), 0, STEPS_MAX)
	return 0


## Värdet för ett enskilt kryss på en liten eller stor nod, som "3" eller "1 (% skada)"-färdig text
## för panelraden. Samma tabell som spelet räknar med.
static func effect_preview(typ: String, klass: String, steg: int = 1) -> String:
	var par: Array = VALUES.get(typ, [])
	if par.size() != SIZES.size():
		return "?"
	var värde: float = float(par[size_index(klass)]) * float(maxi(1, steg))
	return ("+%d %%" % roundi(värde * 100.0)) if värde < 1.0 else ("+%d" % roundi(värde))


## Kryssen som en läsbar rad, samma ord och samma formatering som hovringen visar.
static func text_of(record: Dictionary) -> String:
	var bitar: Array = []
	var spår: int = size_index(size_of(record))
	for typ in record.get("effects", {}):
		var par: Array = VALUES.get(str(typ), [])
		if par.size() != SIZES.size():
			continue
		var värde: float = float(par[spår]) * float(step_of(record, str(typ)))
		var ord: String = str(WORDS.get(str(typ), str(typ)))
		# Procenttecknet är ESCAPAT (%%): strängen går genom "%%"-formatering, och ett ensamt % där
		# hade tystat resten av raden.
		var tal: int = roundi(värde * 100.0) if värde < 1.0 else roundi(värde)
		bitar.append("+%d %% %s" % [tal, ord])
	return ", ".join(bitar)
