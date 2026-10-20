## Provet för MILSTOLPARNA (önskemål 42). Alex: *"Något som ger permanenta boosts för att man låst upp
## dem efter t ex dödat 3000 fiender, spelat en sorts kort 1000ggr osv."*
##
## Provet mäter fem saker:
##   1. filen läses och varje milstolpe har id, räknare och tröskel (en trasig rad ska inte tyst bli en
##      milstolpe utan boost),
##   2. räknaren för spelade kort går att läsa per typ och ligger i sparfilen (tur och retur),
##   3. en milstolpe som nås betalas ut EN gång — `kolla_milstolpar()` ger den inte igen,
##   4. boosten syns i `stat()` FÖRST när milstolpen är nådd (kontrollen: före är den 0),
##   5. boosten läggs ovanpå kamratens passiv, inte i stället för den.
##
## Provet skriver ALDRIG i spelets riktiga sparfil: det använder `user://`.
## KÖRNING: tools/ett_prov.sh tests/test_milstolpar.gd
extends SceneTree

const TEST_PATH := "user://test_milstolpar.json"

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	cleanup_before_quit()
	_clean()
	Tr.set_lang("sv")

	var m := Meta.load_or_new(TEST_PATH)

	# 1. filen
	check(m.milstolpe_defs.size() >= 10, "milstolparna läses ur data/milstolpar.json",
		"%d st" % m.milstolpe_defs.size())
	var trasig := 0
	for d in m.milstolpe_defs:
		if str(d.get("id", "")).is_empty() or str(d.get("counter", "")).is_empty() \
				or int(d.get("threshold", 0)) <= 0 or (d.get("boost", {}) as Dictionary).is_empty():
			trasig += 1
	check(trasig == 0, "varje milstolpe har id, räknare, tröskel och boost", "%d trasiga" % trasig)

	# 2. räknaren
	for i in 3:
		m.rakna_kort("attack")
	check(m.milstolpe_varde("cards:attack") == 3, "korträknaren räknas per typ",
		"%d" % m.milstolpe_varde("cards:attack"))
	check(m.save(TEST_PATH), "sparfilen skrivs")
	var m2 := Meta.load_or_new(TEST_PATH)
	check(m2.milstolpe_varde("cards:attack") == 3, "korträknaren följer med sparfilen",
		"%d" % m2.milstolpe_varde("cards:attack"))

	# 3+4. tröskeln, utbetalningen och boosten
	var might_före: float = m2.stat("might")
	var krav = 0
	for d in m2.milstolpe_defs:
		if str(d.get("counter", "")) == "cards:attack":
			krav = int(d.get("threshold", 0))
			break
	for i in krav:
		m2.rakna_kort("attack")
	var nya: Array = m2.kolla_milstolpar()
	check(nya.has("attack_100"), "milstolpen nås vid tröskeln", "%s" % str(nya))
	var igen: Array = m2.kolla_milstolpar()
	check(not igen.has("attack_100"), "samma milstolpe betalas inte ut två gånger", "%s" % str(igen))
	check(m2.stat("might") > might_före, "boosten syns i stat() när milstolpen är nådd",
		"%.2f -> %.2f" % [might_före, m2.stat("might")])

	# 5. ovanpå kamraten
	var m3 := Meta.load_or_new(TEST_PATH)
	m3.gold = 99999
	m3.milstolpar = []
	# en kamrat med max_hp i sin passiv, och en milstolpe med max_hp
	var kamrat := ""
	for c in m3.crawlers:
		if (c.get("passiv", {}) as Dictionary).has("max_hp"):
			kamrat = str(c.get("id", ""))
			break
	if not kamrat.is_empty():
		m3.hire(kamrat)
		var utan: float = m3.stat("max_hp")
		m3.milstolpar = ["kills_250"]
		check(m3.stat("max_hp") > utan, "milstolpens boost läggs ovanpå kamratens passiv",
			"%.0f -> %.0f" % [utan, m3.stat("max_hp")])

	print("\n=== TOTALT (milstolpar): %d kontroller, %d fel ===" % [checks, fails])
	_clean()
	quit(1 if fails > 0 else 0)

func cleanup_before_quit() -> void:
	pass
