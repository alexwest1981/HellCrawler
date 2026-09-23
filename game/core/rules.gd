## Spelets regler på ETT ställe. Allt annat (strid, test, verktyg) anropar dessa.
##
## Skadeformeln är mätt ur referensens wiki och kontrollräknad mot wikins eget exempel:
##   Damage = (CardDamage + CardDamage*Combo + BaseDamage*Amount)
##            * (1+Might) * (1+Area/5) * GemMultiplier1 * GemMultiplier2
## Kedjan är LINJÄR: Combo N ger CardDamage*(1+N). Inte ×120 för 0→1→2→3 (den siffran
## kommer från fan-sidor som multiplicerar 2·3·4·5 — wikins två sidor motsäger dem).
class_name Rules
extends RefCounted

const WILD_COST := -1          # kort med kostnaden "W" — bryter aldrig kedjan
const NO_CARD_YET := -99       # last_cost innan något kort spelats i kedjan

## Skadan ett kort gör vid en given combo-nivå.
## might/area anges som faktorer (10.0 = 1000 %). gems är multiplikatorer, t.ex. [3.0, 3.0].
static func damage(card_damage: float, combo: int, base_damage: float, amount: float,
		might: float, area: float, gems: Array = []) -> float:
	var value := (card_damage + card_damage * float(combo) + base_damage * amount) \
		* (1.0 + might) * (1.0 + area / 5.0)
	for g in gems:
		value *= float(g)
	return value

## Visad multiplikator på kortet (hexagonen i referensen: combo-värdet, inte multiplikatorn).
static func damage_multiplier(combo: int) -> int:
	return combo + 1

## Får kortet med `cost` spelas efter ett kort med `last_cost` utan att kedjan bryts?
static func continues_chain(cost: int, last_cost: int) -> bool:
	if cost == WILD_COST:
		return true          # wild är en bro: varken bryter eller räknas upp
	return cost > last_cost

## Ny combo-nivå efter att ett kort spelats.
static func combo_after(cost: int, last_cost: int, combo: int) -> int:
	if cost == WILD_COST:
		return combo         # wild ger ingen egen multiplikator
	if continues_chain(cost, last_cost):
		return combo + 1
	return 1                 # kedjan bröts: detta kort är första kortet i en ny kedja
