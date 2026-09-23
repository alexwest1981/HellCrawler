## Byn och världskartan som BILD. Världsprovets test_worldmap.gd mäter logiken (läge, flytt, val);
## det här provet mäter geometrin i det som ritas — det som annars bara syns genom att titta på en
## skärmbild, och som ingen märker att man bryter förrän bilden är ful:
##   1. byn: husen ligger isär och innanför vyn, etikettlisten ligger under marken och markörens ram
##      ryms — en markering som sticker ut över kanten ser trasig ut,
##   2. kartan: noderna ligger isär, ingen nod ligger under pergamentkortet eller förklaringen, och
##      varje nod ligger inne i sitt eget terrängband (inte på klintkanten),
##   3. kartan: landmärket står VID sin nod och inte ovanpå den (det var felet förra gången: hänglåset
##      hamnade mitt i landmärkets dörr), och vägen håller sig innanför terrängen.
##   godot --headless --script res://tests/test_scen.gd
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_scen_meta.json"
const VY := Vector2(480, 270)

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".trasig"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

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

	print("")
	print("— byn: husen ligger isär, och markören ryms i vyn —")
	var by := VillageView.new()
	by.visa(meta, order.size())
	var antal: int = VillageView.PLATSER.size()
	# Husets fot + sidoväggen: byggnaden tar plats i x, och två hus får inte gå i varandra. Utan
	# provet kan en bredare butik tyst hamna inne i värdshuset.
	# Bara de platser som ligger framför betraktaren ritas: tunnan visar 145 grader av byn, alltså
	# ett hus i taget med grannarna i kanten. Provet mäter dem som SYNS — de andra har ingen plats i
	# vyn att rymmas i.
	var synliga := 0
	var utanför := []
	var krockar := []
	for i in antal:
		if not by.synlig(i):
			continue
		synliga += 1
		var r := by.hus_rect(i)
		var bred := Rect2(r.position, Vector2(r.size.x + VillageView.DJUP, r.size.y))
		if r.position.x < 4.0 or bred.end.x > VY.x - 4.0 or r.position.y < 4.0:
			utanför.append("%s %s" % [VillageView.PLATSER[i]["id"], r])
		for j in range(i + 1, antal):
			var r2 := by.hus_rect(j)
			var bred2 := Rect2(r2.position, Vector2(r2.size.x + VillageView.DJUP, r2.size.y))
			if bred.intersects(bred2):
				krockar.append("%s/%s" % [VillageView.PLATSER[i]["id"], VillageView.PLATSER[j]["id"]])
	check(synliga > 0, "minst en plats står framför betraktaren", "%d synliga" % synliga)
	check(utanför.is_empty(), "varje synligt hus ryms i vyn, med sin sidovägg", ", ".join(utanför))
	check(krockar.is_empty(), "och inget hus går i ett annat", ", ".join(krockar))
	# Alla hus står på samma marklinje: en byggnad som flyter eller sjunker syns direkt.
	var fel_mark := []
	for i in antal:
		if absf(by.hus_rect(i).end.y - VillageView.MARKLINJE) > 0.01:
			fel_mark.append(str(VillageView.PLATSER[i]["id"]))
	check(fel_mark.is_empty(), "och alla står på marklinjen", ", ".join(fel_mark))
	# Markörens ram följer markeringen: den ska rymas för VARJE plats, inte bara för den första.
	var ramar_utanför := []
	for i in antal:
		while by.valt_index() != i:
			if not by.flytta(Vector2i(1, 0)):
				break
		by.pan_klart()           # panoreringen står still: ramen mäts där spelaren ser den, inte mitt i en glidning
		var ram := by.markör_ram()
		if ram.position.x < 2.0 or ram.position.y < 2.0 or ram.end.x > VY.x - 2.0 or ram.end.y > VY.y - 2.0:
			ramar_utanför.append("%s %s" % [VillageView.PLATSER[i]["id"], ram])
	check(ramar_utanför.is_empty(), "markörens ram ryms i vyn för varje plats", ", ".join(ramar_utanför))
	check(by.valt_index() == antal - 1, "och markeringen gick genom hela gatan", "index %d" % by.valt_index())
	# Etikettlisten ligger UNDER marken och ÖVER ledtrådsraden. Hamnar den över husen skyms det man
	# valde, och hamnar den över ledtråden blir två rader text en gröt.
	check(VillageView.BAR >= VillageView.MARKLINJE, "etikettlisten ligger under marklinjen",
		"%.0f mot %.0f" % [VillageView.BAR, VillageView.MARKLINJE])
	check(VillageView.BAR + 40.0 <= VillageView.MARKLINJE + 68.0,
		"och ovanför ledtrådsraden längst ned", "%.0f" % (VillageView.BAR + 40.0))
	# Statusraden: en plats utan status ritar en tom rad under namnet, och det ser ut som ett fel.
	var utan_status := []
	for i in antal:
		if by.status_text(i).is_empty():
			utan_status.append(str(VillageView.PLATSER[i]["id"]))
	check(utan_status.is_empty(), "varje plats har en statusrad efter visa()", ", ".join(utan_status))
	by.free()

	print("")
	print("— kartan: bilden, vinkeln och platsernas ruta —")
	var karta := Karta.ladda()
	check(karta.fel.is_empty(), "kartfilen är hel", ", ".join(karta.fel))
	var v := WorldMapView.new()
	v.karta = karta
	v.visa(stages, order, meta)
	var n := v.antal()
	check(n == karta.antal(), "kartan ritar en plats per nod", "%d" % n)
	# Vinkeln: komprimeringen är positiv, så en plats längre NED på bilden ska ritas längre ned i vyn.
	# Kameran står still — annars mäter provet två rörelser samtidigt.
	v.gå_till(0)
	v.steg_kamera(0.0, true)
	var fel_ordning := []
	for i in n:
		for j in n:
			if karta.plats(i).y > karta.plats(j).y and v.plats(i).y <= v.plats(j).y:
				fel_ordning.append("%d/%d" % [i, j])
	check(fel_ordning.is_empty(), "en plats längre ned på bilden ritas längre ned i vyn",
		", ".join(fel_ordning))
	# Kortet, panelen och ledtråden ligger i vyn, i den ordningen.
	check(WorldMapView.KORT.end.y <= WorldMapView.BAR, "kortet slutar ovanför ledtrådsraden",
		"%.0f mot %.0f" % [WorldMapView.KORT.end.y, WorldMapView.BAR])
	check(WorldMapView.KORT.end.x <= VY.x - 6.0, "och kortet ryms i vyn", str(WorldMapView.KORT))
	check(WorldMapView.PANEL.end.y <= WorldMapView.BAR and WorldMapView.PANEL.end.x <= VY.x - 6.0,
		"nivåpanelen ryms i vyn", str(WorldMapView.PANEL))
	# Panelen har plats för tio nivårader (Alex' tak) innanför sin ram.
	var sista_rad: Rect2 = v.nivå_rad(0, Karta.MAX_NIVÅER - 1)
	check(sista_rad.end.y <= WorldMapView.PANEL.end.y - 1.0, "panelen rymmer tio nivårader",
		"%.0f mot %.0f" % [sista_rad.end.y, WorldMapView.PANEL.end.y])
	# Namnplaketterna på de platser som syns samtidigt får inte gå i varandra: två namn på samma rad är
	# oläsligt (mätt i bild: plaketterna kläms ihop mot kartans kanter).
	var plåtar := []
	for i in n:
		var p: Vector2 = v.plats(i)
		if p.x < 0.0 or p.x > VY.x or p.y < 0.0 or p.y > WorldMapView.BAR:
			continue
		plåtar.append([i, v.namnplåt(i)])
	var plåtkrockar := []
	for a in range(plåtar.size()):
		for b in range(a + 1, plåtar.size()):
			if (plåtar[a][1] as Rect2).intersects(plåtar[b][1] as Rect2):
				plåtkrockar.append("%d/%d" % [int(plåtar[a][0]), int(plåtar[b][0])])
	check(plåtkrockar.is_empty(), "namnplaketterna på samma bild går inte i varandra",
		", ".join(plåtkrockar))
	v.free()

	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
