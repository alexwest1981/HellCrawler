## RELIKER (M123) — data, som korten och bestiariet.
##
## Referensen har 67 reliker och 52 arcanas; de formar varje körning, och de är den största
## innehållsskillnaden mot oss (vi hade NOLL — se `docs/balans.md` §8 rad B: "relicen som låser upp
## kedjan är kvar"). Det här är mekanismen: en relik är en LITEN uppsättning rattar som körningen
## läser, aldrig en rad kod per relik. Rattarna är desamma som körningen redan har (max-HP, mana,
## hand, rustning, helande, guld, kedjan), så en ny relik är data — och en ratt som inte finns i
## tabellen nedan FÅR INTE TIGA: `add_relic` skriver ut den.
class_name Relics
extends RefCounted

const DIR := "res://data/relics/"

## Rattarna som är byggda. Nyckeln är vad datan får skriva; värdet är vad den betyder.
const RATTAR := {
	"combo_extra": "kedjan tar så många steg extra när den fortsätter",
	"max_hp": "max-HP (och lika mycket aktuell HP)",
	"mana": "+N mana vid turstart",
	"hand": "+N kort i handen",
	"armor": "+N rustning när striden börjar",
	"recovery": "+N HP helas efter varje strid",
	"gold": "+andel guld (0,2 = +20 %)",
	"damage": "+N skada på varje skaderad kortet har",
}

class RelicDef extends RefCounted:
	var id: String
	var name: String
	var text: String
	var effect: Dictionary = {}

	static func from_dict(d: Dictionary) -> RelicDef:
		var r := RelicDef.new()
		r.id = str(d.get("id", ""))
		if r.id.is_empty():
			push_error("relik utan id: %s" % d)
		r.name = str(d.get("name", r.id))
		r.text = str(d.get("text", ""))
		var e: Variant = d.get("effekt", {})
		if typeof(e) == TYPE_DICTIONARY:
			r.effect = e
		for nyckel in r.effect:
			if not RATTAR.has(str(nyckel)):
				push_error("reliken %s vill röra ratten '%s', som ingen kod läser (%s)"
					% [r.id, nyckel, ", ".join(RATTAR.keys())])
		return r


## id -> RelicDef. En cache: mätaren skapar 240 körningar i samma process, och filen ska läsas en gång.
static var _cache: Dictionary = {}

static func load_all(dir_path: String = DIR) -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var out := {}
	for d in Db.load_packs(dir_path):
		var r := RelicDef.from_dict(d)
		if out.has(r.id):
			push_error("dubbelt relik-id: %s" % r.id)
		out[r.id] = r
	_cache = out
	return out
