## XP-kurvan och kortvalet vid level up. Ren logik, inget tillstånd — så kurvan går att mäta
## och balansera utan att spela.
##
## Referensens exakta kurva är inte känd (står i OSÄKERT i research/01). Talen här är därför
## RATTAR: de ligger på ett ställe, och ett test mäter att de beter sig (monotont, rimlig takt).
class_name Progress
extends RefCounted

## XP som krävs för att gå från `level` till nästa nivå.
static func xp_to_next(level: int) -> int:
	return 12 + 9 * (level - 1) + 3 * (level - 1) * (level - 1)

## Total XP som krävs för att ha nått `level` (nivå 1 = 0).
static func xp_total(level: int) -> int:
	var sum := 0
	for l in range(1, level):
		sum += xp_to_next(l)
	return sum

## Vilken nivå en viss XP-mängd motsvarar.
static func level_for_xp(xp: int) -> int:
	var level := 1
	while xp >= xp_total(level + 1):
		level += 1
	return level

## Antal nivåer som `xp` räcker till, givet att man redan är på `level`.
static func levels_gained(level: int, xp: int) -> int:
	return max(0, level_for_xp(xp) - level)

## Korten som erbjuds vid en level up. Basen är 3 val; referensen ger ett fjärde med Luck.
static func draft(rng: RandomNumberGenerator, db: Dictionary, count: int = 3, rarity_bias: int = 0) -> Array:
	var pool := []
	for id in db:
		var card: Cards.Card = db[id]
		if card.card_type == "crawler":
			continue                         # companions kommer från egna källor, inte level up
		# En uppgradering kommer BARA ur sitt recept (Evolution.consume), aldrig ur högen: annars
		# vore "två kort blir ett" bara en etikett, och de 15 uppgraderingarna låg i valet på
		# samma villkor som korten. Provet mäter att ingen av dem någonsin erbjuds här.
		if Evolution.is_evolution(card):
			continue
		pool.append(id)
	if pool.is_empty():
		return []
	pool.sort()                              # deterministiskt innan RNG:n rör den
	var out := []
	var wants: Array = ["common", "common", "uncommon"] if rarity_bias <= 0 else ["uncommon", "uncommon", "rare"]
	for i in count:
		var rarity: String = wants[i % wants.size()]
		var candidates := []
		for id in pool:
			if db[id].rarity == rarity and not out.has(id):
				candidates.append(id)
		if candidates.is_empty():
			for id in pool:
				if not out.has(id):
					candidates.append(id)
		if candidates.is_empty():
			break
		out.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return out
