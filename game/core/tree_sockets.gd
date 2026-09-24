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
const SIZES := {"liten": 0.009, "stor": 0.018}

## Vad en uppgradering ger på en LITEN respektive STOR nod. Ett enda hem för siffrorna: editorn visar
## dem när man kryssar, metan lägger in dem i noden, och vyn skriver dem i hovringstexten. Stegen är
## hälften så stora på en liten nod, för det är vad en liten grop får plats med.
const VALUES := {
	"might": [0.02, 0.05],
	"area": [0.05, 0.12],
	"max_hp": [4.0, 10.0],
	"armor": [1.0, 2.0],
	"mana": [1.0, 2.0],
	"hand": [1.0, 1.0],
	"gold": [0.05, 0.15],
	"revive": [1.0, 2.0],
	"draw_first": [1.0, 2.0],
}

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


## Nodens klass, "liten" eller "stor". Är klassen inte satt gäller den MÄTTA radien: plattans stora
## sockets är dubbelt så stora som de små, och en nod som ligger i en stor grop skall vara en stor nod.
static func size_of(record: Dictionary, nivå: int = 0) -> String:
	var klass := str(record.get("size", ""))
	if klass == "liten" or klass == "stor":
		return klass
	# Grenens HUVUDNOD står i en medaljong, hur liten gropen än mättes som: den är trädets topp och
	# skall se ut som en sådan. Nivån kommer från vyn eller editorn, som båda vet den.
	if nivå == 1:
		return "stor"
	return "stor" if float(record.get("r", 0.0)) >= 0.015 else "liten"


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
	var klass := size_of(record)
	var spår: int = 0 if klass == "liten" else 1
	for typ in record.get("effects", []):
		var par: Array = VALUES.get(str(typ), [])
		if par.size() == 2:
			ut[str(typ)] = float(par[spår])
	return ut


## Värdet för ett enskilt kryss på en liten eller stor nod, som "3" eller "1 (% skada)"-färdig text
## för panelraden. Samma tabell som spelet räknar med.
static func effect_preview(typ: String, klass: String) -> String:
	var par: Array = VALUES.get(typ, [])
	if par.size() != 2:
		return "?"
	var värde: float = float(par[0 if klass == "liten" else 1])
	return ("+%d %%" % roundi(värde * 100.0)) if värde < 1.0 else ("+%d" % roundi(värde))


## Kryssen som en läsbar rad, samma ord och samma formatering som hovringen visar.
static func text_of(record: Dictionary) -> String:
	var bitar: Array = []
	for typ in record.get("effects", []):
		var par: Array = VALUES.get(str(typ), [])
		if par.size() != 2:
			continue
		var värde: float = float(par[0 if size_of(record) == "liten" else 1])
		var ord: String = str(WORDS.get(str(typ), str(typ)))
		# Procenttecknet är ESCAPAT (%%): strängen går genom "%%"-formatering, och ett ensamt % där
		# hade tystat resten av raden.
		var tal: int = roundi(värde * 100.0) if värde < 1.0 else roundi(värde)
		bitar.append("+%d %% %s" % [tal, ord])
	return ", ".join(bitar)
