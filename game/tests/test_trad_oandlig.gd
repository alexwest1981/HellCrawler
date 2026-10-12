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
	# Fönstret måste rymma vyn: hovringen nedan skickas som en RIKTIG musrörelse, och en pekare utanför
	# fönstret når inga kontroller.
	root.size = Vector2i(480, 270)
	vy.size = Vector2(480, 270)
	await vy.visa(meta, "PROV")
	await process_frame
	vy.placera_om()

	# SYNLIGHET OCH AVSTÅND, MÄTT I PIXLAR (M98). Alex: "Separera dem så de inte ligger tätt inpå
	# varandra i listan nedåt, då det inte går att se dem ordentligt, och det behöver vara hover på
	# dem." Förr ritades 90 av 93 noder som 3 px — size_px-golvet — eftersom SIZES var satt mot en
	# platta som inte finns längre. Nio pixlar är golvet här: under det går varken att se eller hovra.
	print("— noderna syns och är åtskilda —")
	var minsta := 9999
	for id in vy._ikoner:
		minsta = mini(minsta, int((vy._ikoner[id] as Control).size.x))
	check(minsta >= 9, "ingen nod ritas mindre än 9 px", "%d px" % minsta)
	# SPIRALEN (M100). Alex: *"Jag tänker mig mer som 3 st spiraler som utgår från centrum, runt
	# varandra så man konstant arbetar sig utåt i spiralen från de 3 olika armarna."* Formen mäts
	# därför i RADIE ur mitten (0,5 / 0,5) — samma andelar som vyn räknar med, ingen kamera inblandad.
	print("— spiralen —")
	var ring := {}
	var vinkel := {}
	var per := {}                  ## gren -> nivå -> [id]
	for id in vy._ikoner:
		var post: Dictionary = vy._snäpp[id]
		var p := Vector2(float(post["x"]), float(post["y"])) - Vector2(0.5, 0.5)
		var g: String = str(vy._rader[id].get("gren", ""))
		var n: int = int(vy._rader[id].get("nivå", 0))
		ring[n] = maxf(float(ring.get(n, 0.0)), p.length())
		vinkel[id] = atan2(p.y, p.x)
		per[g] = per.get(g, {})
		var pg: Dictionary = per[g]
		pg[n] = pg.get(n, []) + [id]
	var rn: Array = ring.keys()
	rn.sort()
	var stigning := 1e9
	for i in range(rn.size() - 1):
		stigning = minf(stigning, float(ring[rn[i + 1]]) - float(ring[rn[i]]))
	check(stigning > 0.0, "nivåerna är ringar som går UTÅT — djupast längst ut",
		"minsta stigning %.3f andelar (%.0f px)" % [stigning, stigning * vy._sida()])
	# LEDET: de två syskonen på samma nivå ligger på SAMMA vinkel men olika radie — två spår, som
	# räls, parallella hela vägen ut. Låg de i stället ett på var sida om armens mittlinje klev det
	# inre spåret in i nivån innanför (mätt: 27 px mellan huvudnoden och nivå 2:s inre spår).
	var samma_vinkel := true
	var spår := 1e9
	for g in per:
		for n in per[g]:
			var ids: Array = per[g][n]
			if ids.size() < 2:
				continue
			var v0: float = float(vinkel[ids[0]])
			var radier: Array = []
			for id in ids:
				if absf(float(vinkel[id]) - v0) > 0.01:
					samma_vinkel = false
				radier.append((Vector2(float(vy._snäpp[id]["x"]), float(vy._snäpp[id]["y"])) - Vector2(0.5, 0.5)).length())
			radier.sort()
			spår = minf(spår, (float(radier[1]) - float(radier[0])) * vy._sida()
				- (vy._ikoner[ids[0]] as Control).size.x)
	check(samma_vinkel, "syskonen ligger på samma vinkel i sin arm")
	check(spår > 0.0, "och i två spår som inte går i varandra", "minsta luft %.0f px" % spår)
	# INGEN NOD PÅ EN ANNAN: spiralen möter sig själv ett varv längre ut, och det är där en kollision
	# skulle sitta. Kontrollen fångar både ledet (17,6 px mellan spåren gav 26 px-noder på varandra)
	# och varven.
	var närmast := 1e9
	var par := ""
	var alla: Array = vy._ikoner.keys()
	for i in range(alla.size()):
		for j in range(i + 1, alla.size()):
			var a: Control = vy._ikoner[alla[i]]
			var b: Control = vy._ikoner[alla[j]]
			var luft: float = (a.position + a.size * 0.5).distance_to(b.position + b.size * 0.5) \
				- (a.size.x + b.size.x) * 0.5
			if luft < närmast:
				närmast = luft
				par = "%s/%s" % [alla[i], alla[j]]
	check(närmast > 0.0, "ingen nod ligger på en annan", "minsta luft %.0f px (%s)" % [närmast, par])
	# Trädet öppnas i NATURLIG storlek (M99) och i spiralens MITT — där står man när inget är köpt.
	check(absf(vy._zoom - 1.0) < 0.001, "trädet öppnas i naturlig storlek (zoom 1)", "zoom %.3f" % vy._zoom)

	# HOVRINGEN GENOM EN RIKTIG MUSRÖRELSE, inte genom att kalla _peka: det är spelarens väg, och det
	# var den som var död — en 3 px-ikon gick i praktiken aldrig att träffa, och raden stod kvar efter
	# att pekaren lämnat noden.
	print("— hovringen —")
	var mus := InputEventMouseMotion.new()
	mus.position = vy.global_position + Vector2(2, 2)
	vy.get_window().push_input(mus)
	await process_frame
	var tomt: bool = vy._info.text.is_empty()
	var första: Control = vy._ikoner[vy.nod_ids()[0]]
	mus = InputEventMouseMotion.new()
	mus.position = vy.global_position + första.position + första.size * 0.5
	vy.get_window().push_input(mus)
	await process_frame
	check(not vy._info.text.is_empty(), "en riktig musrörelse över en nod fyller hovringsraden",
		vy._info.text)
	mus = InputEventMouseMotion.new()
	mus.position = vy.global_position + Vector2(2, 2)
	vy.get_window().push_input(mus)
	await process_frame
	check(tomt and vy._info.text.is_empty(), "och raden töms när pekaren lämnar noden")

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
	# PLATSEN LIGGER UTANFÖR PLATTAN (M96). Förr var plattans kant rymdens kant och en nod utanför
	# fick ingen plats. Med spiralen (M100) är rymden rund: gränsen går en halv andel från mitten,
	# alltså en radie på 0,5 — en nivå-14-nod ligger 0,68 andelar ut, långt förbi rutans kant.
	var px := float(post.get("x", 0.5)) - 0.5
	var py := float(post.get("y", 0.5)) - 0.5
	check(post.has("x") and sqrt(px * px + py * py) > 0.5,
		"dess plats fortsätter FÖRBI plattans kant i stället för att sluta vid den",
		"x %.2f y %.2f (radie %.2f)" % [float(post.get("x", 0.0)), float(post.get("y", 0.0)),
			sqrt(px * px + py * py)])
	# F visar hela trädet — vägen tillbaka till noderna när trädet vuxit förbi skärmen.
	vy.centrera()
	var p: Vector2 = vy.nod_punkt("prov_djup")
	check(p.x >= 0.0 and p.y >= 0.0 and p.x <= vy.size.x and p.y <= vy.size.y,
		"F (centrera) visar den, även med trädet utanför skärmen", str(p))
	check(vy._ikoner.size() > 63, "och de gamla noderna är kvar", "%d ikoner" % vy._ikoner.size())

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
