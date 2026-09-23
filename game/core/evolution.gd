## Evolutionerna: två kort i leken blir ett. Recepten är DATA (data/evolutions.json) och resultatet
## är ett vanligt kort i samma pack som alla andra (data/cards/04_evolutioner.json) — så en ny
## evolution är två rader JSON, inte en kodändring.
##
## Regeln är referensens (research/01 §Evolutioner): BÅDA delarna konsumeras, och bara resultatet
## hamnar i leken. Det är den affären som gör att leken inte bara växer: man byter två kort mot ett
## bättre, och kortleken blir ett bygge i stället för en hög.
##
## Kortet som blir resultatet är märkt med nyckelordet "Evolved" och får därför ALDRIG dyka upp i
## kortvalet av sig själv (se Progress.draft) — det är bara receptet som ger det. Provet i
## tests/test_evolution.gd mäter båda riktningarna: att en uppgradering erbjuds när receptet finns,
## och att den aldrig erbjuds annars.
class_name Evolution
extends RefCounted

const PATH := "res://data/evolutions.json"
const KEYWORD := "Evolved"

## Läses en gång per körning: recepten är data som inte ändras under en körning.
static var _recept: Array = []

static func recipes() -> Array:
	if _recept.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) != TYPE_ARRAY:
			push_error("kunde inte läsa %s" % PATH)
			return []
		_recept = parsed
	return _recept

## Receptet som gör `card_id`, eller {} om kortet inte är en uppgradering.
static func for_card(card_id: String) -> Dictionary:
	for r in recipes():
		if str(r.get("card", "")) == card_id:
			return r
	return {}

## Är kortet en uppgradering? Kortets EGET nyckelord är sanningen (det är det som visas på kortet),
## inte en lista här — annars kunde datat och koden säga olika saker.
static func is_evolution(card: Cards.Card) -> bool:
	return card != null and card.keywords.has(KEYWORD)

## Hur många exemplar av ett kort leken har. Flera kopior betyder att receptet kan göras flera
## gånger — fyra Lash och fyra Vial ger fyra Leech Dagger över en lång körning.
static func count_in(deck: Array, card_id: String) -> int:
	var n := 0
	for c in deck:
		if c != null and c.id == card_id:
			n += 1
	return n

## Recepten som går att göra NU, i dataordning: båda delarna ligger i leken. Resultatet är
## kort-id:n (inte recept), för det är vad kortvalet och leken arbetar med.
static func available(deck: Array) -> Array:
	var ut := []
	for r in recipes():
		var ok := true
		for del in r.get("parts", []):
			if count_in(deck, str(del)) < 1:
				ok = false
				break
		if ok:
			ut.append(str(r.get("card", "")))
	return ut

## Genomför uppgraderingen: EN kopia av varje del ur leken, resultatet in. Allt eller inget —
## kontrolleras först, så ett halvt recept aldrig kan lämna leken utan en del och utan resultat.
## Returnerar false när en del saknas (t.ex. för att en annan uppgradering redan tog den).
static func consume(deck: Array, db: Dictionary, card_id: String) -> bool:
	var r := for_card(card_id)
	if r.is_empty() or not db.has(card_id):
		return false
	var delar: Array = r.get("parts", [])
	for del in delar:
		if count_in(deck, str(del)) < 1:
			return false
	for del in delar:
		var i: int = _index_of(deck, str(del))
		deck.remove_at(i)
	deck.append(db[card_id])
	return true

static func _index_of(deck: Array, card_id: String) -> int:
	for i in deck.size():
		if deck[i] != null and deck[i].id == card_id:
			return i
	return -1

## Receptet som en läsbar rad ("Lash + Vial"), för vyn: ett val ingen kan läsa är ett val man inte
## gör. Texten byggs ur delarnas EGNA namn, så den följer språkvalet utan en enda ny nyckel.
static func recipe_text(db: Dictionary, card_id: String) -> String:
	var r := for_card(card_id)
	if r.is_empty():
		return ""
	var namn := []
	for del in r.get("parts", []):
		var c: Cards.Card = db.get(str(del))
		namn.append(c.title() if c != null else str(del))
	return " + ".join(namn)
