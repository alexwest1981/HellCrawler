## DET OÄNDLIGA TRÄDET (M96). Alex: *"Jag vill att vi bygger ett oändligt skill tree där jag kan
## enkelt lägga till fler noder och bara peka vidare ju mer jag utvecklar spelet."*
##
## Provet mäter de egenskaper som gör trädet växande i stället för låst i plattan:
##   1. en nod UTANFÖR plattans kant (0..1) går att lägga dit — och att nå med panoreringen,
##   2. en nod som bara finns i DATAT, på en nivå ingen socket finns för, får en plats ändå,
##   3. en gren koden inte känner igen blir en nod i vyn i stället för att försvinna tyst.
##
## Det sista är det som betyder något för "peka vidare": den som lägger en nod i data/tree.json skall
## inte behöva röra vyn. Faller kontroll 2 är trädet fortfarande låst i sin nuvarande form.
##
## KÖRNING: godot --headless --script res://tests/test_trad_oandlig.gd
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
	Meta.fotolage(true)                  # provet får aldrig röra spelarens sparfil
	var meta := Meta.load_or_new()
	var vy := TreeView.new()
	root.add_child(vy)
	await process_frame                  # in i trädet först: visa() väntar in en bildruta själv
	vy.size = Vector2(480, 270)
	await vy.visa(meta, "PROV")
	await process_frame
	vy.placera_om()

	print("— rymden —")
	check(vy._ikoner.size() > 0, "trädet ritades", "%d noder" % vy._ikoner.size())
	var djup: String = str(vy.nod_ids()[0])
	# 2,5 / 3,2 ligger långt nedanför och till höger om bilden — och är fortfarande en giltig plats.
	# Det är hela skillnaden mot den låsta formen, där plattans kant var rymdens kant.
	vy.flytta(djup, 2.5, 3.2)
	var tillbaka: Vector2 = vy.till_bild(vy.nod_punkt(djup))
	check(tillbaka.distance_to(Vector2(2.5, 3.2)) < 0.01,
		"en nod går att lägga utanför plattan (2,5 / 3,2)", "%.2f %.2f" % [tillbaka.x, tillbaka.y])
	# OCH GÅ ATT NÅ: samma räkning som _gui_input gör när man drar med höger musknapp.
	vy.panorera(vy.size * 0.5 - vy.nod_punkt(djup))
	var efter: Vector2 = vy.nod_punkt(djup)
	check(efter.x >= 0.0 and efter.y >= 0.0 and efter.x <= vy.size.x and efter.y <= vy.size.y,
		"och panoreringen når den — den ligger i vyn", str(efter))

	print("— zoomen —")
	vy.nollställ()
	var före: float = vy._ur_bild(0.0, 0.0).distance_to(vy._ur_bild(1.0, 0.0))
	vy.zooma(vy.size * 0.5, 2.0)
	var nu: float = vy._ur_bild(0.0, 0.0).distance_to(vy._ur_bild(1.0, 0.0))
	check(absf(nu - före * 2.0) < 1.0, "zoomen fördubblar avståndet i trädrymden",
		"%.0f mot %.0f px" % [före, nu])
	# Punkten under pekaren står kvar: annars far trädet iväg åt sidan när man zoomar, och man tappar
	# bort sig i en rymd som inte har någon kant att hålla sig i.
	var pekare := Vector2(300.0, 200.0)
	var under_före: Vector2 = vy.till_bild(pekare)
	vy.zooma(pekare, 1.5)
	check(vy.till_bild(pekare).distance_to(under_före) < 0.01,
		"samma trädandel står kvar under pekaren när man zoomar")
	vy.nollställ()
	check(absf(vy._zoom - 1.0) < 0.001 and vy._pan.length() < 0.001,
		"nollställningen tar tillbaka plattans egen skala")

	print("— en nod som bara finns i datat —")
	# NIVÅ 14, EN GREN KODEN INTE KÄNNER, ingen socket och ingen egen ikon: exakt den nod Alex lägger
	# till nästa gång trädet skall peka vidare.
	meta.defs.append({
		"id": "prov_djup", "name": "Provnoden", "branch": "Nya grenen", "tier": 14,
		"effect": {"might": 0.05}, "text": "+5 % skada", "cost": [0], "soul_cost": [4],
		"max_rank": 1, "requires": [],
	})
	await vy.visa(meta, "PROV")
	vy.placera_om()
	check(vy._ikoner.has("prov_djup"), "en ny nod i datat får en ikon utan att koden rörs")
	check(int(vy._rader.get("prov_djup", {}).get("nivå", 0)) == 14, "och står på sin egen nivå",
		"nivå %s" % vy._rader.get("prov_djup", {}).get("nivå", 0))
	var ny_ikon: TextureRect = vy._ikoner.get("prov_djup", null)
	check(ny_ikon != null and ny_ikon.texture != null,
		"och den har en ikon att ritas med (lånad, tills grenen får en egen)")
	var post: Dictionary = vy._snäpp.get("prov_djup", {})
	check(post.has("x") and float(post.get("y", 0.0)) > 1.0,
		"dess plats fortsätter FÖRBI plattans kant i stället för att sluta vid den",
		"x %.2f y %.2f" % [float(post.get("x", 0.0)), float(post.get("y", 0.0))])
	# F visar hela trädet — vägen tillbaka till noderna när trädet vuxit förbi skärmen.
	vy.centrera()
	var p: Vector2 = vy.nod_punkt("prov_djup")
	check(p.x >= 0.0 and p.y >= 0.0 and p.x <= vy.size.x and p.y <= vy.size.y,
		"F (centrera) visar den, även med trädet utanför skärmen", str(p))
	check(vy._ikoner.size() > 63, "och de gamla noderna är kvar", "%d ikoner" % vy._ikoner.size())

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
