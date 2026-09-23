## Hand- och deck-vyn. Reglerna kommer från communityns rankade moddar (research/05-moddar.md):
## wilds till vänster eller höger, kort med "gratis denna tur" på ursprungligt värde (ännu inte
## implementerat), sortering som VIEW-state — originalhanden får aldrig muteras av en sortering.
##   godot --headless --script res://tests/test_handview.gd
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

func _initialize() -> void:
	var db := Cards.load_all()
	var hand := [db["emberstorm"], db["wild_mana"], db["lash"], db["dagger"], db["ash_tome"]]

	print("— sortering —")
	var asc := HandView.sorted(hand, "cost_asc", "right")
	check(_costs(asc) == "0,0,1,3,W", "stigande kostnad med wild längst till höger", _costs(asc))
	var asc_left := HandView.sorted(hand, "cost_asc", "left")
	check(_costs(asc_left) == "W,0,0,1,3", "wild till vänster när man ber om det", _costs(asc_left))
	var desc := HandView.sorted(hand, "cost_desc", "right")
	check(_costs(desc) == "3,1,0,0,W", "fallande kostnad", _costs(desc))
	var by_role := HandView.sorted(hand, "role", "right")
	check(by_role[0].card_type == "mana", "rollsortering sätter manakort först", by_role[0].id)

	print("— visningsordningen: visat index -> handens index —")
	# Vyn visar korten i en ordning men spelar dem med sitt riktiga index. Översättningen måste
	# vara en permutation: tappas en plats blir ett kort ospelbart, delas en plats spelas fel kort.
	var ord := HandView.order(hand, "cost_asc", "right")
	check(ord.size() == hand.size(), "varje kort får en plats", "%d av %d" % [ord.size(), hand.size()])
	var unika := {}
	for i in ord:
		unika[i] = true
	check(unika.size() == hand.size(), "ingen plats tappas eller delas",
		"%d unika av %d" % [unika.size(), hand.size()])
	var ord_costs := []
	for i in ord:
		ord_costs.append("W" if hand[i].is_wild() else str(hand[i].cost))
	check(",".join(ord_costs) == "0,0,1,3,W", "visningen följer kostnaden stigande",
		",".join(ord_costs))
	var via_order := []
	for i in ord:
		via_order.append(hand[i])
	var via_sorted := HandView.sorted(hand, "cost_asc", "right")
	var lika := via_order.size() == via_sorted.size()
	for k in via_order.size():
		if via_order[k] != via_sorted[k]:
			lika = false
	check(lika, "order() och sorted() ger samma sak", "en sortering, två vägar in")
	check(hand[0].id == "emberstorm", "handen själv är orörd efter en sortering", hand[0].id)
	var roll_ord := HandView.order(hand, "role", "right")
	check(hand[roll_ord[0]].card_type == "mana", "rollordningen sätter manakortet först",
		"%s på plats %d" % [hand[roll_ord[0]].id, roll_ord[0]])
	check(_costs(hand) == "3,W,0,1,0", "originalhanden är orörd efter sortering", _costs(hand))
	check(asc[0] != hand[0], "sortering ger en kopia, inte samma objekt")

	print("— deck-vyn —")
	var curve := HandView.deck_curve(hand)
	check(int(curve.get(0, 0)) == 2, "två 0-kort i kurvan", str(curve))
	check(int(curve.get("W", 0)) == 1, "wild räknas i sin egen hink")
	check(HandView.rotation_size([hand, [], [db["lash"]]]) == 6, "kort i rotationen = alla högar")

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _costs(cards: Array) -> String:
	var parts := []
	for c in cards:
		parts.append("W" if c.is_wild() else str(c.cost))
	return ",".join(parts)
