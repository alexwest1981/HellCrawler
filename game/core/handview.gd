## Hand- och deck-vy som rena funktioner. Ingen UI, inget tillstånd — bara ordning och räkning,
## så det går att testa och så UI:t aldrig behöver gissa.
##
## Källa till reglerna: communityns rankade moddar (research/05-moddar.md).
## Referensens eget autospel sorterar höger-till-vänster och bryter kedjan; därför är sorteringen
## här en förstklassig funktion i stället för en detalj i UI-koden.
class_name HandView
extends RefCounted

const WILD_KEY := "W"

## Kortets roll för autospel och sortering. Lägre = spelas tidigare.
## 0 manakort → 1 utility → 2 companion → 3 attack → 4 övrigt.
static func role(card) -> int:
	match card.card_type:
		"mana":
			return 0
		"item":
			return 1
		"crawler":
			return 2
		"attack":
			return 3
	return 4

## Kortets kostnad för visning och sortering: wild räknas som "W" (efter alla tal när
## den sorteras stigande), negativ kostnad ligger före 0.
static func sort_value(card) -> int:
	if card.is_wild():
		return 99
	return card.cost

## Sorterad kopia. `mode`: "cost_asc" | "cost_desc" | "role". `wilds`: "right" | "left".
## Stabil inom samma kostnad (roll, sedan namn) så handen inte hoppar i onödan.
static func sorted(cards: Array, mode: String = "cost_asc", wilds: String = "right") -> Array:
	var out := []
	for i in order(cards, mode, wilds):
		out.append(cards[i])
	return out

## Visningsordningen som INDEX i handen: order(cards)[visad plats] = plats i handen.
##
## UI:t visar korten i den här ordningen men spelar dem med sitt riktiga index — därför är
## översättningen en egen funktion i stället för något UI-koden håller reda på. Provas i
## test_handview: varje index förekommer exakt en gång, och följer den valda ordningen.
static func order(cards: Array, mode: String = "cost_asc", wilds: String = "right") -> Array[int]:
	var idx: Array[int] = []
	for i in cards.size():
		idx.append(i)
	idx.sort_custom(func(a, b):
		var ca = cards[a]
		var cb = cards[b]
		if mode == "role":
			if role(ca) != role(cb):
				return role(ca) < role(cb)
		else:
			var av := sort_value(ca)
			var bv := sort_value(cb)
			if ca.is_wild() != cb.is_wild():
				var wild_first: bool = (wilds == "left")
				return ca.is_wild() == wild_first
			if av != bv:
				return av > bv if mode == "cost_desc" else av < bv
		if role(ca) != role(cb):
			return role(ca) < role(cb)
		return ca.name < cb.name
	)
	return idx

## Kort per kostnad: {0: 3, 1: 5, ..., "W": 2}. Används av deck-overlayn och balansverktyget.
static func deck_curve(cards: Array) -> Dictionary:
	var curve := {}
	for c in cards:
		var key = WILD_KEY if c.is_wild() else c.cost
		curve[key] = int(curve.get(key, 0)) + 1
	return curve

## Kort i rotationen = draw + hand + discard (+ exile, om man vill se förstörda kort).
static func rotation_size(piles: Array) -> int:
	var n := 0
	for p in piles:
		n += p.size()
	return n
