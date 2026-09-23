## Banans regel: en bana är inte bara SVÅRARE än nästa, den spelas ANNORLUNDA.
##
## Skillnaden mot svårighetsgraden är hela poängen. Svårighetsgraden ger fienden mer hp; en regel
## ändrar vad spelaren får göra. Regeln ligger i banans fil (`data/stages/<id>.json`, fältet `regel`)
## och ställs in i ban-editorns BANAN-panel — den som ritar banan väljer också hur den spelas.
##
## En regel som står i listan men inte gör något i motorn är en lögn mot den som väljer den, så
## listan och motorn hålls i samma fil: lägg till en rad här OCH grenen i Combat.play/start_turn.
class_name Regler
extends RefCounted

## Hälsa per kort när blodet betalar i stället för manan.
const BLOD_PRIS := 4.0

const ALLA := [
	{"id": "", "namn": "ingen regel", "text": "banan spelas som vanligt"},
	{"id": "blod_som_valuta", "namn": "Blod som valuta",
		"text": "räcker inte manan betalas kortet med %d hälsa" % int(BLOD_PRIS)},
	{"id": "ingen_mana", "namn": "Ingen mana",
		"text": "manan fylls aldrig på — varje kort betalas med %d hälsa" % int(BLOD_PRIS)},
]

static func id_finns(id: String) -> bool:
	for r in ALLA:
		if str(r["id"]) == id:
			return true
	return false

static func namn(id: String) -> String:
	for r in ALLA:
		if str(r["id"]) == id:
			return str(r["namn"])
	return ""

static func text(id: String) -> String:
	for r in ALLA:
		if str(r["id"]) == id:
			return str(r["text"])
	return ""

## Nästa regel i listan. Editorns ←/→ rullar med den här, så listan är enda sanningen om vilka
## regler som finns — inte en egen lista i editorn.
static func nasta(id: String, steg: int) -> String:
	var i := 0
	for k in ALLA.size():
		if str(ALLA[k]["id"]) == id:
			i = k
			break
	return str(ALLA[(i + steg + ALLA.size()) % ALLA.size()]["id"])
