## PROV: orden i byn och på kartan — ryms de i sina rutor, i alla 13 språk?
##
## MÄTT: all text i vyn ritades i 480x270 och skalades upp 2x till fönstret. En rad som var bredare än
## sin ruta KLIPPtes av draw_string (spanska beskedet var 267 px i en ruta på 166 px), och bandnamnen
## i teckenförklaringen stod i en enda rad med 58 px steg medan spanska "LA ARBOLEDA" är 54 px — den
## gick rakt in i nästa märke. Båda felen syntes bara på bild.
##
## Provet mäter SAMMA lista som bilden ritar ur (`VillageView.etiketter()` / `WorldMapView.etiketter()`)
## och räknar om raderna till fönsterpixlar med UiText.i_fönstret — samma omräkning som `UiText._draw`
## använder, inte en kopia av den. Det prövar fyra saker per språk:
##   1. att varje rads BREDD ryms i sin ruta (annars klipps den),
##   2. att raden ligger innanför vyn (0..480, 0..270),
##   3. att två rader i samma grupp inte går i varandra, och
##   4. att fontens höjd i fönsterpixlar vid 1280x720 — före och efter — står i tabellen.
##
##   godot --headless --path game --script res://ui/textprov.gd
extends SceneTree

## Minikartan (MapView i main.gd) ritar sina sex märken i vyn, men ORDEN ritas i fönstret: provet
## instansierar samma klass och mäter dess rader i stället för en kopia av dem.
const Main := preload("res://main.gd")

var fails := 0
var checks := 0

const VY := Vector2(480, 270)
const TEST_PATH := "user://test_textprov_meta.json"

## Fönstrets skalning av vyn: korgen är heltalsskalad och centrerad (main.gd `_placera_vy`). 1280x720
## ger x2, 1920x1080 ger x3 (och 480x270, alltså huvudlöst, ger x1) — alla tre mäts.
const SKALOR := [1, 2, 3]
const PLATS_X := 160.0             ## var vyn ligger i ett 1280x720-fönster: bara för att rutan ska
const PLATS_Y := 90.0              ## mätas på riktig plats, inte i origo

## Storlekarna raderna ritades i FÖRE (i vyns px): det är den siffra tabellen jämför mot. De stod i
## draw_string-anropen i VillageView/WorldMapView (se git-historiken för b3 167a9).
const FÖRE := {
	"bar": 10, "hint": 9, "plakett": 9, "kort": 9, "legend": 8, "ledtråd": 9, "besked": 8,
}

## Rutorna bakom grupperna, i vyns px: en rad som hamnar utanför sin platta eller panel syns inte
## eller krockar med kanten. (Byns list ritas 196..236; kortet och förklaringen 180..252.)
const PANELER := {
	"bar": Rect2(0.0, 196.0, 480.0, 40.0),
	"kort": Rect2(6.0, 180.0, 280.0, 72.0),
	"legend": Rect2(292.0, 180.0, 182.0, 72.0),
}

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".trasig"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Fönsterpunkten för en punkt i vyn, för en viss skalning (samma räkning som UiText gör ur korgen).
func _mapp(skala: int) -> Transform2D:
	return Transform2D(Vector2(skala, 0.0), Vector2(0.0, skala), Vector2(PLATS_X, PLATS_Y))

## Radens bläckrektur i fönstret: där bokstäverna FAKTISKT står (rutans kant är inte texten).
func _bläck(rad: Dictionary, m: Transform2D) -> Rect2:
	var f := ThemeDB.fallback_font
	var w := UiText.i_fönstret(rad, m)
	var text := str(w["text"])
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(w["storlek"])).x
	var vänster: float = float(w["pos"].x)
	if int(w["align"]) == HORIZONTAL_ALIGNMENT_CENTER:
		vänster += (float(w["bredd"]) - tw) / 2.0
	var över: float = f.get_ascent(int(w["storlek"]))
	var under: float = f.get_descent(int(w["storlek"]))
	return Rect2(Vector2(vänster, float(w["pos"].y) - över), Vector2(tw, över + under))

## Raderna med sin position flyttad. Minikartans rader är i KARTANS koordinater (den har sitt eget
## `size`), allt annat i provet mäts i VYNS (480x270) — samma förskjutning som kartans plats i vyn.
func _flytt(rader: Array, förskjutning: Vector2) -> Array:
	var ut := []
	for rad in rader:
		var kopia: Dictionary = rad.duplicate()
		kopia["pos"] = Vector2(rad["pos"]) + förskjutning
		ut.append(kopia)
	return ut

## Mäter en lista rader i EN skalning: bredden mot rutan, rutan innanför vyn, och bläcket.
func _mät(rader: Array, skala: int, märke: String) -> Array:
	var bläck := []
	for rad in rader:
		var m := _mapp(skala)
		var w := UiText.i_fönstret(rad, m)
		var grupp := str(w["grupp"])
		var text := str(w["text"])
		var tw: float = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(w["storlek"])).x
		# 1. bredden mot rutan. Rutan är i samma enheter (vyns px × skalan), alltså samma jämförelse
		# som draw_string gör när den klipper.
		check(tw <= float(w["bredd"]) + 0.01,
			"%s: raden ryms i sin ruta" % märke,
			"%s: %.0f px i %.0f px (%s, %d px)" % [text.left(34), tw, float(w["bredd"]), grupp,
				int(w["storlek"])])
		var r := _bläck(rad, m)
		# 2. rutan (och bläcket) innanför vyn.
		var vyn := Rect2(Vector2(PLATS_X, PLATS_Y), VY * float(skala))
		check(vyn.encloses(r),
			"%s: raden ligger innanför vyn" % märke,
			"%s: %s i %s" % [text.left(24), r, vyn])
		bläck.append({"ruta": r, "grupp": grupp, "text": text, "storlek": int(w["storlek"])})
		# 2b. Rutan BAKOM raden (plattan, kortet, förklaringen): en rad utanför sin panel syns inte
		# eller skär kanten. Det var så den sista bandraden hamnade utanför förklaringen.
		if PANELER.has(grupp):
			var panel: Rect2 = PANELER[grupp]
			var panel_fönster := Rect2(m * panel.position, panel.size * m.get_scale().x)
			check(panel_fönster.encloses(r), "%s: raden ligger innanför sin panel" % märke,
				"%s: %s i %s (%s)" % [text.left(24), r, panel_fönster, grupp])
	return bläck

## 3. Två rader i samma grupp får inte ligga över varandra.
func _krockar(bläck: Array, märke: String) -> void:
	var krockar := []
	for i in bläck.size():
		for j in range(i + 1, bläck.size()):
			var a: Dictionary = bläck[i]
			var b: Dictionary = bläck[j]
			if str(a["grupp"]) != str(b["grupp"]):
				continue
			if Rect2(a["ruta"]).intersects(Rect2(b["ruta"])):
				krockar.append("%s mot %s (%s)" % [str(a["text"]).left(14), str(b["text"]).left(14),
					str(a["grupp"])])
	check(krockar.is_empty(), "%s: ingen rad ligger över en annan" % märke, ", ".join(krockar))

## 4. Höjden i fönsterpixlar vid 1280x720: det raden VAR (fonten i vyn × 2, alltså den uppskalade
##    fyrkanten) och det den är nu (fonten rastrerad i fönstret). px-kolumnerna är FONTSTORLEKAR i
##    fönsterpixlar; höjd-kolumnerna är bokstävernas höjd i samma enhet.
func _höjdtabell(rader: Array, märke: String) -> void:
	var f := ThemeDB.fallback_font
	var m := _mapp(2)
	var grupper := {}
	var ordning := []
	for rad in rader:
		var grupp := str(rad.get("grupp", ""))
		if grupp.is_empty():
			continue
		var w := UiText.i_fönstret(rad, m)
		if not grupper.has(grupp):
			grupper[grupp] = {"min": int(w["storlek"]), "max": int(w["storlek"]),
				"text": str(rad["text"]).left(24)}
			ordning.append(grupp)
		var g: Dictionary = grupper[grupp]
		g["min"] = mini(int(g["min"]), int(w["storlek"]))
		g["max"] = maxi(int(g["max"]), int(w["storlek"]))
	print("  %-12s %-9s %-9s %-9s %-9s" % ["grupp", "före px", "höjd före", "efter px", "höjd efter"])
	for grupp in ordning:
		var g: Dictionary = grupper[grupp]
		var före := int(FÖRE.get(grupp, 9)) * 2
		var storlek := str(g["min"]) if int(g["min"]) == int(g["max"]) else "%d-%d" % [g["min"], g["max"]]
		print("  %-12s %-9d %-9.0f %-9s %-9.0f  (%s · %s)" % [grupp, före,
			f.get_string_size("Ag", HORIZONTAL_ALIGNMENT_LEFT, -1, före).y, storlek,
			f.get_string_size("Ag", HORIZONTAL_ALIGNMENT_LEFT, -1, int(g["max"])).y,
			märke, str(g["text"])])

func _init() -> void:
	var stages := Stages.load_all()
	var order: Array = stages.keys()
	order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))
	_clean()
	var meta := Meta.load_or_new(TEST_PATH)
	# Lite framsteg, så fler rader är i spel: en påbörjad och en avklarad bana.
	meta.unlock(str(order[1]))
	meta.unlock(str(order[2]))
	meta.best_floor[str(order[1])] = 1
	meta.best_floor[str(order[2])] = stages[str(order[2])].floors
	var sista := order.size() - 1

	print("")
	print("— 13 språk: ryms varje rad i sin ruta, och ligger den innanför vyn? —")
	print("   (vyn ritas i 480x270 och korgen skalas x1/x2/x3: 1280x720 är x2, alltså den rad man ser)")
	var by_rader: Array = []
	var karta_rader: Array = []
	var besked_rader: Array = []
	var tom_rader: Array = []
	var storlekar := {}                                ## språk -> grupp -> största fontstorlek i fönstret
	for kod in Tr.codes():
		Tr.set_lang(kod)
		var by := VillageView.new()
		by.visa(meta, order.size())
		var by_r := by.etiketter()
		var bläck := _mät(by_r, 2, "%s byn" % kod)
		_krockar(bläck, "%s byn" % kod)
		var karta := WorldMapView.new()
		karta.visa(stages, order, meta)
		karta.gå_till(0)                            # öppen bana: ledtråden står längst ned
		var karta_r := karta.etiketter(VY)
		_krockar(_mät(karta_r, 2, "%s kartan" % kod), "%s kartan" % kod)
		# Samma karta med den LÅSTA sista banan vald: då står beskedet i stället för ledtråden, och
		# det var den raden som klipptes (267 px i en ruta på 166 px på spanska).
		karta.gå_till(sista)
		karta.försök_gå_in(sista)
		var besked_r := karta.etiketter(VY)
		_krockar(_mät(besked_r, 2, "%s besked" % kod), "%s besked" % kod)
		check(str(besked_r[besked_r.size() - 1]["text"]) == karta.besked(),
			"%s: beskedet står på den nedersta raden" % kod)
		# Och kartan utan vald bana ("ingen bana vald" i banderollen).
		var tom := WorldMapView.new()
		tom.visa(stages, [], meta)
		var tom_r := tom.etiketter(VY)
		_krockar(_mät(tom_r, 2, "%s tom" % kod), "%s tom" % kod)
		var val := {}
		for rad in by_r + karta_r + besked_r + tom_r:
			var grupp := str(rad.get("grupp", ""))
			var w := UiText.i_fönstret(rad, _mapp(2))
			val[grupp] = maxi(int(val.get(grupp, 0)), int(w["storlek"]))
		storlekar[kod] = val
		if kod == "sv":
			by_rader = by_r
			karta_rader = karta_r
			besked_rader = besked_r
			tom_rader = tom_r
		# Skalorna: samma rader i x1 och x3 — annars är "skarp text" bara sant i 1280x720.
		for skala in SKALOR:
			_mät(by_r, skala, "%s byn x%d" % [kod, skala])
			_mät(karta_r, skala, "%s kartan x%d" % [kod, skala])
		by.free()
		karta.free()
		tom.free()
	Tr.set_lang("sv")

	print("")
	print("— fontens storlek per språk (fönsterpx vid 1280x720, vyns px i parentes) —")
	print("   Språken är olika långa: storleken är den största som ryms i rutan för DET språket.")
	for kod in Tr.codes():
		var s: Dictionary = storlekar[kod]
		print("  %-8s listen %2d (%d)   ledtråden %2d (%d)   kortet %2d (%d)   förklaringen %2d-%2d" % [
			kod, int(s.get("bar", 0)), int(s.get("bar", 0)) / 2, int(s.get("hint", 0)),
			int(s.get("hint", 0)) / 2, int(s.get("kort", 0)), int(s.get("kort", 0)) / 2,
			int(s.get("legend", 18)), int(s.get("legend", 22))])

	print("")
	print("— fontens storlek och höjd i fönsterpixlar vid 1280x720 (x2) —")
	_höjdtabell(by_rader, "byn")
	_höjdtabell(karta_rader, "kartan")
	_höjdtabell(besked_rader, "beskedet")
	_höjdtabell(tom_rader, "ingen bana")

	print("")
	print("— minikartans teckenförklaring med ORD, i den SVARTA MARGINALEN (M32) —")
	# Minikartan (MapView i main.gd) ritar de sex märkena i vyns pixelkonst (76x60 px) — men inga ord:
	# värst polska "pochodnia" är 41 px vid 9 px medan kartans ruta är 76 px bred. Orden står därför i
	# en KOLUMN under kartan, ett ord per rad, och hela kolumnen ligger i marginalen till HÖGER om
	# spelvyn (Alex: "Rutan med döskalle, strid, kista osv, den ligger nu i spelytan, den skall helst
	# vara ren" / "skulle vilja flytta även minimap upp till högra hörnet").
	# Kartan ligger i FÖNSTRETS lager och skalas med korgen:s heltal (`_placera_karta`), så en punkt i
	# kartan är kartans position + punkten × skalan. Provet mäter samma rader som bilden ritar ur
	# (`MapView.ord_rader`) och samma ruta som `_legend` ritar märkena ur (`MapView.rad_ruta`).
	var f := ThemeDB.fallback_font
	var skala := 2
	var mk := Main.MapView.new()
	mk.size = Main.MapView.MAP_SIZE
	mk.scale = Vector2(skala, skala)
	var fönster := Vector2(1280, 720)
	var vy := Rect2(Vector2(PLATS_X, PLATS_Y), VY * float(skala))
	var mk_pos := Vector2(fönster.x - Main.MapView.MAP_SIZE.x * skala - Main.MARGINAL, Main.MARGINAL)
	var karta := Rect2(mk_pos, Main.MapView.MAP_SIZE * float(skala))
	var kolumn := Rect2(mk_pos, Vector2(karta.size.x,
		(Main.MapView.MAP_SIZE.y + Main.MapView.LEGEND_HÖJD) * float(skala)))
	var m_karta := Transform2D(Vector2(skala, 0.0), Vector2(0.0, skala), mk_pos)
	print("  spelvyn slutar på x %.0f. Kartan: %.0f,%.0f %.0fx%.0f px, orden i en kolumn under den (%d rader, %.0f px höga). Fönstret är %.0fx%.0f." % [
		vy.end.x, karta.position.x, karta.position.y, karta.size.x, karta.size.y,
		Main.MapView.NODER.size(), kolumn.end.y - karta.end.y, fönster.x, fönster.y])
	check(karta.position.x >= vy.end.x, "kartan ligger helt till höger om spelvyn (spelytan är ren)",
		"%.0f mot %.0f" % [karta.position.x, vy.end.x])
	check(karta.end.x <= fönster.x and kolumn.end.y <= fönster.y,
		"kartan och hela ordkolumnen ryms i fönstret",
		"högerkant %.0f, underkant %.0f" % [karta.end.x, kolumn.end.y])
	# Orden i alla 13 språk: bläcket innanför marginalen, under kartans rutor, och inga två rader i
	# samma språk över varandra (13 px bläck i en 14 px rad — det var radhöjden som var för liten).
	var värst := ""
	var värst_b := 0.0
	for kod in Tr.codes():
		Tr.set_lang(kod)
		var bläck: Array[Rect2] = []
		var texter := []
		for i in mk.ord_rader().size():
			var rad: Dictionary = mk.ord_rader()[i]
			var r := _bläck(rad, m_karta)
			bläck.append(r)
			texter.append(str(rad["text"]))
			check(r.position.x >= karta.position.x and r.end.x <= fönster.x
					and r.position.y >= karta.end.y,
				"%s: ordet står i marginalen under kartan" % kod,
				"%s: %s" % [str(rad["text"]).left(20), r])
			check(not karta.intersects(r), "%s: ordet rör inte kartans rutor" % kod,
				"%s i %s" % [str(rad["text"]).left(20), karta])
			if r.size.x > värst_b:
				värst_b = r.size.x
				värst = "%s: %s" % [kod, str(rad["text"])]
		var krock := ""
		for a in bläck.size():
			for b in range(a + 1, bläck.size()):
				if bläck[a].intersects(bläck[b]):
					krock = "\"%s\" och \"%s\": %s / %s" % [texter[a], texter[b], bläck[a], bläck[b]]
		check(krock.is_empty(), "%s: de sex raderna går inte i varandra" % kod, krock)
	Tr.set_lang("sv")
	var ledig: float = fönster.x - (karta.position.x + (Main.MapView.MÄRKE_PX + Main.MapView.LUFT) * skala)
	print("  längsta ordet i fönstret: %s = %.0f px. Marginalen ger %.0f px åt texten (märket och luften står före den)." % [
		värst, värst_b, ledig])
	check(värst_b <= ledig, "det bredaste ordet (13 språk) får plats i marginalen",
		"%.0f mot %.0f" % [värst_b, ledig])
	# Stridspanelen ligger INNE i vyn (main.gd `_place_panel`, y 40..102 vid 1280x720) medan orden
	# ligger utanför den — panelen kan alltså inte skära genom sin egen text längre. Det mäts i
	# stället för att påstås: panelens ruta i fönstret mot kartan och kolumnen.
	var panel := Rect2(vy.position + Vector2((VY.x - 200.0) / 2.0, 40.0) * float(skala),
		Vector2(200.0, 62.0) * float(skala))
	var krock_karta := panel.intersection(karta)
	var krock_ord := panel.intersection(kolumn)
	print("  stridspanelen (200x62 px i vyn = 400x124 i fönstret) ligger på x %.0f..%.0f, y %.0f..%.0f" % [
		panel.position.x, panel.end.x, panel.position.y, panel.end.y])
	check(krock_karta.size == Vector2.ZERO and krock_ord.size == Vector2.ZERO,
		"stridspanelen går inte in i kartan eller i ordkolumnen",
		"kartan %.0f,%.0f / orden %.0f,%.0f" % [krock_karta.size.x, krock_karta.size.y,
			krock_ord.size.x, krock_ord.size.y])
	# Slutskärmens panel bär hela byns lista och är HÖGRE än vyn (mätt nedan). Den ligger inuti vyn,
	# och orden i marginalen — därför täcker den inte orden längre (före M32 låg orden ovanpå vyn och
	# var tvungna att stängas av när körningen var slut, se MapView._process).
	var slut_rader := meta.village_lines().size() + 11
	var radhöjd: float = f.get_height(10)
	var slut_h: float = float(slut_rader) * radhöjd + 10.0
	print("  slutskärmen: %d rader × %.0f px = %.0f px panel — vyn är %.0f px hög, orden står utanför den" % [
		slut_rader, radhöjd, slut_h, VY.y])
	check(slut_h > VY.y and karta.position.x >= vy.end.x,
		"slutskärmens panel är högre än vyn, men orden ligger i marginalen utanför den",
		"%.0f px mot %.0f px" % [slut_h, VY.y])
	mk.free()

	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
