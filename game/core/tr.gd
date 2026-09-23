## Översättning: nycklar i koden och i datat, värden i en tabell per språk.
##
## Samma tvålagersmodell som referensbygget (se research/06-referensbygget.md): spellogiken och
## datat äger NYCKLARNA ("card.lash", "ui.draft.prompt"), och varje språk äger VÄRDENA i
## data/i18n/<kod>.json. Att lägga till ett språk är då en fil — inte en kodändring.
##
## Tre regler som gör att en halvfärdig översättning aldrig kan tömma gränssnittet:
##   1. Saknad nyckel faller tillbaka på svenska (källspråket), sedan på den text koden skickade.
##   2. Alla filer har samma nyckeluppsättning — provet i tests/test_i18n.gd mäter det.
##   3. En språkfil vars ui.* inte är komplett får inte väljas (Tr.is_complete).
class_name Tr
extends RefCounted

const DIR := "res://data/i18n/"
const SOURCE := "sv"

## Språken i spelet: de tolv som referensen har, plus svenska. Se research/06-referensbygget.md —
## originalet har ingen skandinaviska alls, så vår svenska är ett tillägg, inte ett lån.
const LANGUAGES := [
	{"code": "sv", "name": "Svenska"},
	{"code": "en", "name": "English"},
	{"code": "de", "name": "Deutsch"},
	{"code": "fr", "name": "Français"},
	{"code": "es", "name": "Español"},
	{"code": "it", "name": "Italiano"},
	{"code": "pl", "name": "Polski"},
	{"code": "pt-BR", "name": "Português (Brasil)"},
	{"code": "ru", "name": "Русский"},
	{"code": "ja", "name": "日本語"},
	{"code": "ko", "name": "한국어"},
	{"code": "zh-Hans", "name": "简体中文"},
	{"code": "zh-Hant", "name": "繁體中文"},
]

static var lang := SOURCE
static var _tabeller := {}          ## kod -> {nyckel: värde}


static func codes() -> Array:
	var ut := []
	for l in LANGUAGES:
		ut.append(l["code"])
	return ut


static func name_of_code(code: String) -> String:
	for l in LANGUAGES:
		if l["code"] == code:
			return l["name"]
	return code


## Sätt språk. Okänt språk eller en fil som saknar ui-nycklar nekas — hellre svenska än ett
## halvtomt gränssnitt.
static func set_lang(code: String) -> bool:
	if not codes().has(code) or not is_complete(code):
		return false
	lang = code
	return true


static func table(code: String) -> Dictionary:
	if _tabeller.has(code):
		return _tabeller[code]
	var t := {}
	var path := DIR + code + ".json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			t = parsed
	_tabeller[code] = t
	return t


## Kravet för att ett språk ska få väljas: en egen översättning av HELA gränssnittet
## (ui.*, fmt.*, kw.* — nycklar som bara är platshållare, som "▶ %s %.0f/%.0f −%.0f", räknas som
## neutrala och behöver ingen översättning). Innehållsnamnen får komma i etapper: Tr faller
## tillbaka på svenska/engelska, och Tr.coverage visar hur långt språket kommit.
const NEEDED := ["ui.", "fmt.", "kw."]


static func is_complete(code: String) -> bool:
	if code == SOURCE:
		return true
	var t := table(code)
	var källa := table(SOURCE)
	for k in källa:
		if not _needed(k):
			continue
		var v := str(t.get(k, ""))
		if v.strip_edges().is_empty() and not _neutral(källa[k]):
			return false
	return true


static func _needed(key: String) -> bool:
	for p in NEEDED:
		if key.begins_with(p):
			return true
	return false


## Är strängen ren formatering (inga bokstäver att översätta)? Då får den vara identisk överallt.
static func _neutral(v: String) -> bool:
	var kvar := v.replace("%.0f", "").replace("%d", "").replace("%s", "").replace("%%", "")
	for c in kvar:
		if c.to_upper() != c.to_lower():
			return false
	return true


## Hur stor del av ALLA nycklar språket har egna värden för. ui.* är kravet, innehållet (kort,
## fiender, banor) får vara översatt i etapper — och siffran visas i menyn i stället för att
## döljas.
static func coverage(code: String) -> float:
	var källa := table(SOURCE)
	if källa.is_empty():
		return 0.0
	var t := table(code)
	var egna := 0
	for k in källa:
		var v := str(t.get(k, ""))
		if not v.strip_edges().is_empty():
			egna += 1
	return float(egna) / float(källa.size())


## Slå upp en nyckel: aktuellt språk -> svenska -> den text koden skickade med.
static func t(key: String, fallback: String = "") -> String:
	var v := str(table(lang).get(key, ""))
	if v.is_empty():
		v = str(table(SOURCE).get(key, ""))
	return v if not v.is_empty() else fallback


## Namn på innehåll (kort, fiende, bana, uppgradering): tabellen först, sedan det namn datat
## självt bär. Så kan en ny korttyp läggas till utan att någon översättning måste finnas först.
static func name_of(kind: String, id: String, fallback: String) -> String:
	return t("%s.%s" % [kind, id], fallback)
