## Fiender som data. Samma mönster som korten: en JSON-fil per bestiarium.
class_name Enemies
extends RefCounted

const DIR := "res://data/enemies/"

class EnemyDef extends RefCounted:
	var id: String
	var name: String
	var hp: float
	var damage: float
	var tier: int = 1              ## 1..3 — vilken svårighetsgrad fienden hör hemma i
	var eyes: int = 0              ## bossar: slår när alla ögon öppnats
	var xp: int = 1
	var gold: int = 0
	var kind: String = "normal"    ## normal | elite | boss

	static func from_dict(d: Dictionary) -> EnemyDef:
		var e := EnemyDef.new()
		e.id = str(d.get("id", ""))
		if e.id.is_empty():
			push_error("fiende utan id: %s" % d)
		e.name = str(d.get("name", e.id))
		e.hp = float(d.get("hp", 10.0))
		e.damage = float(d.get("damage", 1.0))
		e.tier = int(d.get("tier", 1))
		e.eyes = int(d.get("eyes", 0))
		e.xp = int(d.get("xp", 1))
		e.gold = int(d.get("gold", 0))
		e.kind = str(d.get("kind", "normal"))
		return e

## id -> EnemyDef
static func load_all(dir_path: String = DIR) -> Dictionary:
	var out := {}
	for d in Db.load_packs(dir_path):
		var e := EnemyDef.from_dict(d)
		if out.has(e.id):
			push_error("dubbelt fiende-id: %s" % e.id)
		out[e.id] = e
	return out

static func by_tier(db: Dictionary, tiers: Array) -> Array:
	var out := []
	for id in db:
		if tiers.has(db[id].tier):
			out.append(db[id])
	return out
