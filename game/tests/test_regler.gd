## Banans regel (mutator): att banan SPELAS annorlunda, att den kommer tillbaka ur filen, och att
## en bana utan regel är exakt som förut.
##
## Provet vaktar tre saker:
##   1. Utan regel händer ingenting: ett kort som kostar mer än manan nekas (for_lite_mana).
##   2. Med "blod som valuta" går SAMMA kort igenom och priset tas i hälsa — manan står still.
##   3. Blodet betalar aldrig om det skulle kunna döda, och "ingen mana" fyller aldrig på manan.
##   godot --headless --script res://tests/test_regler.gd
extends SceneTree

const TESTDIR := "user://test_regler/"

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _kort(kost: int) -> Cards.Card:
	var k := Cards.Card.new()
	k.id = "provkort"
	k.name = "Provkort"
	k.cost = kost
	k.card_type = "attack"
	return k

## En strid med ETT kort på handen och givna förutsättningar. Ingen scen, ingen grafik: regeln bor i
## motorn, och det är motorn provet mäter.
func _prov(regel: String, mana: int, hp: float, kost: int) -> Dictionary:
	var c := Combat.new(7)
	c.regel = regel
	c.mana = mana
	c.hp = hp
	c.max_hp = 100.0
	# Högen heter `draw_pile` i motorn (inte `deck` — det är Run:s namn på samma sak).
	c.draw_pile.clear()
	c.draw_pile.append(_kort(1))
	c.hand.clear()
	c.hand.append(_kort(kost))
	var r := c.play(0)
	return {"ok": r.ok, "skal": r.reason, "blod": r.betalat_med_blod, "hp": c.hp, "mana": c.mana}

func _init() -> void:
	print("")
	print("— banans regel —")

	var utan := _prov("", 1, 20.0, 3)
	check(not utan["ok"] and utan["skal"] == "for_lite_mana", "utan regel nekas kortet som förut",
		"%s/%s" % [utan["ok"], utan["skal"]])

	var med := _prov("blod_som_valuta", 1, 20.0, 3)
	check(med["ok"], "med blod som valuta går samma kort igenom")
	check(med["blod"], "resultatet säger att blodet betalade")
	check(is_equal_approx(med["hp"], 20.0 - Regler.BLOD_PRIS), "hälsan är priset",
		"%.0f -> %.0f" % [20.0, med["hp"]])
	check(med["mana"] == 1, "manan rördes inte", str(med["mana"]))

	var dödlig := _prov("blod_som_valuta", 1, Regler.BLOD_PRIS, 3)
	check(not dödlig["ok"] and dödlig["skal"] == "for_lite_mana",
		"blodet betalar inte när det skulle döda", "hp %.0f" % dödlig["hp"])

	var ingen := _prov("ingen_mana", 0, 20.0, 2)     # manan ÄR noll med den regeln
	check(ingen["ok"] and ingen["blod"], "ingen mana: kortet betalas med blod")
	var c := Combat.new(7)
	c.regel = "ingen_mana"
	c.base_mana = 3
	c.mana = 9
	c.draw_pile.clear()
	c.draw_pile.append(_kort(1))
	c.start_turn()
	check(c.mana == 0, "ingen mana: turstarten fyller inte på manan", str(c.mana))

	# Listan och motorn: varje id i Regler.ALLA ska antingen vara tomt eller kännas igen av motorn.
	var kända := 0
	for r in Regler.ALLA:
		var id := str(r["id"])
		if id.is_empty() or id == "blod_som_valuta" or id == "ingen_mana":
			kända += 1
	check(kända == Regler.ALLA.size(), "varje regel i listan har en gren i motorn",
		"%d av %d" % [kända, Regler.ALLA.size()])
	check(Regler.nasta("", 1) == "blod_som_valuta" and Regler.nasta("blod_som_valuta", -1) == "",
		"editorns rullning går genom listan")

	# Filen: regeln måste överleva en sväng genom data/stages/<id>.json.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TESTDIR))
	var s := Stages.StageDef.new()
	s.id = "provbana"
	s.regel = "blod_som_valuta"
	s.bosses = ["copper_warden"]
	check(Stages.skriv(s, TESTDIR), "banan skrivs")
	var tillbaka := Stages.load_all(TESTDIR)
	var läst: Stages.StageDef = tillbaka.get("provbana")
	check(läst != null and läst.regel == "blod_som_valuta", "regeln kom tillbaka ur filen",
		läst.regel if läst != null else "saknas")
	check(läst != null and läst.bosses.size() == 1, "bosses-listan skrivs nu tillbaka",
		str(läst.bosses) if läst != null else "saknas")

	var d := DirAccess.open(TESTDIR)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
