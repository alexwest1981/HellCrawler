## Prövar att angreppet får rätt VAPEN ur rätt kort. Färgen och formen kommer ur kortet, och ett
## nytt attackkort ska alltid få ett streck — aldrig en tyst attack (det var hela poängen med
## Alex anmärkning). Ritar görs inte här: det är en bild, det läses med ögonen.
##   godot --headless --script res://tests/test_attack_fx.gd
extends SceneTree

var fails := 0
var checks := 0


func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func kort(id: String, typ: String) -> Cards.Card:
	var c := Cards.Card.new()
	c.id = id
	c.card_type = typ
	return c


func _init() -> void:
	print("=== angreppets vapen")
	check(AttackFx._typ_för(kort("lash", "attack")) == "piska", "Lash blir en piska")
	check(AttackFx._typ_för(kort("dagger", "attack")) == "klinga", "Dagger blir ett blad")
	check(AttackFx._typ_för(kort("choir_bell", "attack")) == "ring", "Choir Bell blir ringar")
	check(AttackFx._typ_för(kort("ash_tome", "mana")) == "glöd", "Ash Tome blir en glimt")
	check(AttackFx._typ_för(kort("vial", "item")) == "mjuk", "Vial blir gnistor, inte ett hugg")
	check(AttackFx._typ_för(kort("helt_nytt_kort", "attack")) == "klinga",
		"okänt attackkort får ändå ett streck")
	check(AttackFx._typ_för(kort("okant", "item")) == "mjuk", "okänd typ får den lugna formen")

	# Alla riktiga attackkort i datan ska ge ett vapen ur den ritade floran, aldrig en tom ruta.
	var db := Cards.load_all()
	var tomma: Array = []
	for id in db:
		var c: Cards.Card = db[id]
		if str(c.card_type) != "attack":
			continue
		if not ["klinga", "piska", "kross", "ring", "glöd", "mjuk"].has(AttackFx._typ_för(c)):
			tomma.append(id)
	check(tomma.is_empty(), "varje attackkort i datan får en ritad form",
		"%d kort, saknas: %s" % [db.size(), str(tomma)])

	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
