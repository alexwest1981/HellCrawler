## Kort som DATA, aldrig som kod per kort. Korten ligger i data/cards/*.json — en fil per
## "pack" — så 80+ kort är en innehållsfråga, inte en kodfråga.
##
## Effekter är en lista av operationer ({"op": "...", ...}) som Combat tolkar. Ny op = en rad
## i Combat._apply_effect(), aldrig en ny klass per kort.
class_name Cards
extends RefCounted

const DIR := "res://data/cards/"

## Ett kort. Allt utom id/namn/kostnad är frivilligt så enkla kort förblir korta i JSON.
class Card extends RefCounted:
	var id: String
	var name: String
	var cost: int
	var card_type: String          # attack | item | wild | crawler | mana
	var rarity: String = "common"
	var effects: Array = []        # [{op, ...}, ...]
	var keywords: Array = []       # ["Destroy", "Evolved", "Return", ...]
	var text: String = ""          # visas på kortet; tom = genereras ur effekterna

	func is_wild() -> bool:
		return cost == Rules.WILD_COST

	## Namnet som visas. Datats eget namn är källan (svenska/engelska), men språkfilen får
	## översätta det: Tr.name_of letar i "card.<id>" och faller tillbaka på datat.
	func title() -> String:
		return Tr.name_of("card", id, name)

	## Kortets effekt som kort text. Tom text i datan betyder att texten räknas fram ur effekterna
	## — ett nytt kort behöver bara sina siffror i JSON, aldrig en handskriven rad att hålla i synk.
	## Formuleringarna ("+%.0f rustning", "knuffa %d rad") är nycklar: samma siffror, olika språk.
	func describe() -> String:
		if not text.is_empty():
			return text
		var parts := []
		for e in effects:
			match str(e.get("op", "")):
				"damage":
					parts.append(Tr.t("fmt.damage", "%.0f×%d") % [float(e.get("damage", 0.0)), int(e.get("hits", 1))])
				"armor":
					parts.append(Tr.t("fmt.armor", "+%.0f rustning") % float(e.get("amount", 0.0)))
				"heal":
					parts.append(Tr.t("fmt.heal", "+%.0f HP") % float(e.get("amount", 0.0)))
				"mana":
					parts.append(Tr.t("fmt.mana", "+%d mana") % int(e.get("amount", 0)))
				"draw":
					parts.append(Tr.t("fmt.draw", "dra %d") % int(e.get("amount", 1)))
				"knockback":
					parts.append(Tr.t("fmt.knockback", "knuffa %d rad") % int(e.get("amount", 1)))
				"freeze":
					parts.append(Tr.t("fmt.freeze", "frys %d tur") % int(e.get("amount", 1)))
		for k in keywords:
			# Nyckelordet i datat står med versal ("Evolved"), nycklarna i tabellen är gemena
			# ("kw.evolved"): uppslaget MÅSTE gemenas, annars faller varje nyckelord tillbaka på
			# engelska på kortet — i alla 13 språk (mätt: 3 nyckelord × 13 språk var döda).
			parts.append(Tr.t("kw." + str(k).to_lower(), str(k)))
		return ", ".join(parts)

	static func from_dict(d: Dictionary) -> Card:
		var c := Card.new()
		c.id = str(d.get("id", ""))
		if c.id.is_empty():
			push_error("kort utan id: %s" % d)
		c.name = str(d.get("name", c.id))
		c.cost = int(d.get("cost", 0))
		c.card_type = str(d.get("type", "attack"))
		c.rarity = str(d.get("rarity", "common"))
		c.effects = d.get("effects", [])
		c.keywords = d.get("keywords", [])
		c.text = str(d.get("text", ""))
		return c

## Alla kort i alla pack, som en ordbok id -> Card. Läser filerna i namnordning så
## resultatet är deterministiskt (samma seed + samma filer = samma kortlista).
static func load_all(dir_path: String = DIR) -> Dictionary:
	var out := {}
	for d in Db.load_packs(dir_path):
		var card := Card.from_dict(d)
		if out.has(card.id):
			push_error("dubbelt kort-id: %s" % card.id)
		out[card.id] = card
	return out

## Bygg en draghög ur en lista av id:n (upprepade id:n = flera exemplar).
static func make_pile(db: Dictionary, ids: Array) -> Array:
	var pile := []
	for id in ids:
		if db.has(id):
			pile.append(db[id])
		else:
			push_error("okänt kort-id i hög: %s" % id)
	return pile
