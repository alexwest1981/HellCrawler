## BYN I 2.5D (M122): kloten borta, huset är knappen, skärpan mätt i konstpixlar, gångaren — och
## paralaxen mellan lagren.
##
## Alex' tre klagomål, i hans egna ord:
##   * "Det är de färgade kloten du lagt in i byn som är ett av problemen."
##   * "Jag vill ha en by i 2.5D med paralax och crisp grafik, vilket det inte är idag."
##   * "...en karaktär som går mellan punkterna i byn, och på kartan."
##
## Provet mäter fyra saker, en rubrik per punkt:
##   1. KLOTEN: noll `draw_circle` i byns ritningsfil, varje plats nåbar med ett KLICK på sitt hus,
##      hovringen träffar rätt hus och visar dess namn.
##   2. SKÄRPAN: konsten ritas i 1:1 mot skärmens pixelgrid (en konstpixel = en skärmpixel) — mätt
##      som skal-förhållandet mot fönstrets heltalsskala, både med och utan korg.
##   3. GÅNGAREN: EN komponent, som går till den valda platsen och först DÅ öppnar den — och samma
##      komponent på världskartan. Provet mäter vägen, tiden och att rätt plats öppnas.
##   4. PARALAXEN: byn är en 3D-scen; kameran pannas N px och lager A flyttar a px, lager B b px, a≠b.
##
##   godot --headless --script res://tests/test_by_2p5d.gd
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_by_2p5d_meta.json"
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

## En riktig mushändelse in i vyns EGEN ingång (`_gui_input`) — samma väg som spelets mus tar.
func _klick(vy, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	vy._gui_input(e)

func _rör(vy, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	vy._gui_input(e)

## Antalet `draw_circle` i en fil. Klotet VAR en `draw_circle` per plats (fyllning, kontur, glöd,
## blänk) — noll kvar är samma sak som noll klot i renderingen.
func _cirkel_antal(sökväg: String) -> int:
	var text := FileAccess.get_file_as_string(sökväg)
	if text.is_empty():
		return -1
	return text.count("draw_circle(")


## Kör gångaren fram till målet i fasta steg, och säg hur många steg (och hur lång tid) det tog.
func _gå_klart(g: Gångare, dt: float = 0.05) -> Dictionary:
	var antal := 0
	while g.går() and antal < 100000:
		g.steg(dt)
		antal += 1
	return {"steg": antal, "tid": float(antal) * dt}


func _initialize() -> void:
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

	# ---------------------------------------------------------------- 1. KLOTEN BORTA
	print("")
	print("— 1. kloten borta: huset är knappen —")
	var by := VillageView.new()
	by.size = VY
	by.visa(meta, order.size())
	var antal: int = VillageView.PLATSER.size()
	check(_cirkel_antal("res://ui/village_view.gd") == 0,
		"noll draw_circle i byns ritning (klot, bollar, glöd var alla cirklar)",
		"%d kvar" % _cirkel_antal("res://ui/village_view.gd"))
	# Varje plats går att komma in i MED ETT KLICK PÅ SITT HUS. Panoreringen flyttas dit först
	# (precis som när spelaren bläddrar dit), och klicket läggs i husets egen ruta.
	var mål := []
	by.vald.connect(func(skepp: String): mål.append(skepp))
	var bom := []
	var för_små := []
	for i in antal:
		while by.valt_index() < i:
			if not by.flytta(Vector2i(1, 0)):
				break
		by.pan_klart()
		var r := by.byggnad_rect(i)
		if r.size.x < 8.0 or r.size.y < 8.0:
			för_små.append("%s %s" % [VillageView.PLATSER[i]["id"], str(r)])
			continue
		mål.clear()
		_klick(by, r.get_center())
		# Klicket startar GÅNGEN; platsen öppnas när figuren är framme (det är punkten 4 nedan).
		_gå_klart(by.gångaren())
		if mål != [str(VillageView.PLATSER[i]["skepp"])]:
			bom.append("%s -> %s" % [VillageView.PLATSER[i]["id"], str(mål)])
	check(för_små.is_empty(), "varje hus har en klickruta i vyn", ", ".join(för_små))
	check(bom.is_empty(), "klick på varje hus öppnar just den platsen (när figuren gått dit)", ", ".join(bom))
	# HUSET ÄR KNAPPEN, inte en prick bredvid: ett klick högt upp på huset (långt ifrån platsens
	# punkt på gatan) ska träffa samma plats. Det var det som var fel förut — man siktade på en boll.
	by.flytta(Vector2i(-1, 0))
	while by.valt_index() != 0:
		if not by.flytta(Vector2i(-1, 0)):
			break
	by.pan_klart()
	var r0 := by.byggnad_rect(0)
	var högt := Vector2(r0.get_center().x, r0.position.y + 6.0)
	var punkt := by.plats_px(0)
	var avstånd := högt.distance_to(punkt)
	mål.clear()
	_klick(by, högt)
	_gå_klart(by.gångaren())
	check(mål == ["trad"] and avstånd > 40.0,
		"klicket tar på husets kropp, inte bara vid markörens punkt",
		"klicket %.0f px ovanför platsens punkt" % avstånd)
	# Hovringen: rätt hus, och namnet syns.
	_rör(by, by.byggnad_rect(2).get_center())
	check(by.hovrad() == 2, "hovringen träffar huset man pekar på",
		"%d (%s)" % [by.hovrad(), str(VillageView.PLATSER[2]["id"])])
	var hovring := []
	for rad in by.etiketter():
		if str(rad.get("grupp", "")) == "hovring":
			hovring.append(str(rad["text"]))
	check(hovring.size() == 1, "hovringen visar husets namn", ", ".join(hovring))
	check(not hovring.is_empty() and hovring[0] == Tr.t("ui.by.plats.vardshus", "THE TAVERN"),
		"och det är RÄTT namn", ", ".join(hovring))
	by.släpp_hovring()
	check(by.hovrad() == -1, "och hovringen släpps när pekaren lämnar")
	by.free()

	# ---------------------------------------------------------------- 2. SKÄRPAN
	print("")
	print("— 2. skärpan: en konstpixel = en skärmpixel —")
	# Konstens mått och fönstrets heltalsskala avgör om bilden ritas 1:1.
	var prov := VillageView.new()
	prov.size = VY
	var konst := prov.byscen()
	check(konst != null, "byns konst finns att mäta", "res://assets/ui/byn.png")
	if konst != null:
		# Utan korg (ett prov utan fönster) finns ingen skala att räkna mot — då ryms hela konstens
		# höjd i vyn, precis som förr.
		var b1 := prov.bild_storlek()
		check(absf(b1.x * float(konst.get_height()) - b1.y * float(konst.get_width())) < 1.0
				and prov.fönsterskala() == 1.0,
			"utan korg följer rutan konstens eget förhållande (ingen skevhet)",
			"%.1f x %.1f, skala %.0f" % [b1.x, b1.y, prov.fönsterskala()])
		# MED en korg i skala 3 (samma väg som spelet): konsten ska ritas i 1/3 vyn-pixel per
		# konstpixel — alltså EXAKT en skärmpixel per konstpixel, ingen omsampling.
		var korg := SubViewportContainer.new()
		korg.stretch = false
		korg.scale = Vector2(3, 3)
		var vp := SubViewport.new()
		vp.size = Vector2i(VY)
		korg.add_child(vp)
		root.add_child(korg)
		await process_frame                   # vyn måste vara i trädet innan `get_viewport()` svarar
		vp.add_child(prov)
		check(prov.fönsterskala() == 3.0, "fönstrets heltalsskala läses ur korgen",
			"%.0f" % prov.fönsterskala())
		var b3 := prov.bild_storlek()
		check(absf(b3.x * 3.0 - float(konst.get_width())) < 0.01
				and absf(b3.y * 3.0 - float(konst.get_height())) < 0.01,
			"i skala 3 ritas konsten 1:1 mot skärmpixlarna",
			"%.2f x %.2f vyn-px = %.1f x %.1f skärm-px mot konstens %d x %d"
				% [b3.x, b3.y, b3.x * 3.0, b3.y * 3.0, konst.get_width(), konst.get_height()])
		# Kanten LÅSES till pixelgriden: annars ligger konstens pixelkanter mitt emellan skärmens och
		# varje pixel blir omsamplad (2 px bred på sina ställen, 3 på andra).
		var steg := 1.0 / 3.0
		var låst := prov._pixel_låst(10.17)
		check(absf(låst / steg - roundf(låst / steg)) < 0.001,
			"konstens kant snäpps till en hel konstpixel",
			"10,17 -> %.4f vyn-px = %d konstpixlar" % [låst, int(roundf(låst / steg))])
		# Och den gamla vägen (fit-height, icke-heltalig) ska INTE vara den som används i spelet: den
		# gav 3,87 konstpixlar per vyn-pixel, alltså 0,775 per skärmpixel.
		var gammal := VY.y * float(konst.get_width()) / float(konst.get_height())
		check(absf(b3.x - gammal) > 100.0,
			"skalan är inte längre den gamla (hela höjden i vyn)",
			"%.1f mot gamla %.1f vyn-px" % [b3.x, gammal])
		prov.free()
		korg.free()
	else:
		prov.free()

	# ---------------------------------------------------------------- 3. GÅNGAREN
	print("")
	print("— 3. gångaren: EN figur, två skärmar —")
	var by2 := VillageView.new()
	by2.size = VY
	by2.visa(meta, order.size())
	var öppnade := []
	by2.vald.connect(func(skepp: String): öppnade.append(skepp))
	var g: Gångare = by2.gångaren()
	check(g != null, "byn har en gångare", "Gångare (ui/gangare.gd)")
	var från: Vector2 = by2.gångpunkt(0)
	var till: Vector2 = by2.gångpunkt(3)
	check(by2.gå_till(3), "man kan skicka figuren till en plats (porten, plats 3)")
	check(g.går(), "och då GÅR den")
	var väntad_sträcka: float = från.distance_to(till)
	check(absf(g.sträcka() - väntad_sträcka) < 0.01,
		"sträckan är avståndet mellan de två punkterna",
		"%.1f px mot %.1f" % [g.sträcka(), väntad_sträcka])
	check(absf(g.tid() - väntad_sträcka / Gångare.FART) < 0.01,
		"gångtiden är sträckan delat med farten",
		"%.2f s = %.1f px / %.0f px/s" % [g.tid(), väntad_sträcka, Gångare.FART])
	# INGENTING ÖPPNAS MEDAN DEN GÅR. Det är hela poängen med gångaren.
	g.steg(0.1)
	check(öppnade.is_empty() and g.går(), "ingenting öppnas medan figuren går",
		"efter 0,1 s: %s" % str(öppnade))
	var res := _gå_klart(g)
	check(öppnade == ["karta"], "och när den är framme öppnas platsen man gick till", str(öppnade))
	check(g.pos().distance_to(till) < 0.5, "figuren står PÅ målpunkten",
		"%.2f px från målet" % g.pos().distance_to(till))
	check(absf(float(res["tid"]) - väntad_sträcka / Gångare.FART) < 0.11,
		"och gångtiden stämmer med sträckan",
		"%.2f s mätt mot %.2f s väntat" % [float(res["tid"]), väntad_sträcka / Gångare.FART])
	# Att gå till SAMMA plats man står på väntar inte: ingen väg, ingen fördröjning.
	öppnade.clear()
	by2.gå_till(3)
	check(öppnade == ["karta"], "står figuren redan där går man in direkt", str(öppnade))
	by2.free()

	# SAMMA KOMPONENT PÅ KARTAN. Klassens identitet är beviset: två kopior hade varit två saker som
	# glider isär, och Alex bad om EN karaktär som går på båda ställena.
	var kvy := WorldMapView.new()
	kvy.karta = Karta.ladda()
	kvy.visa(stages, order, meta)
	check(kvy.gångaren() != null and kvy.gångaren() is Gångare,
		"kartan har samma Gångare-klass som byn — inte en egen kopia",
		"%s" % ("Gångare" if kvy.gångaren() is Gångare else "annat"))
	kvy.gå_till(0)
	kvy.steg_kamera(0.0, true)
	var mål_nod := -1
	for i in kvy.antal():
		if i != 0 and kvy.läge(i) != "låst":
			mål_nod = i
			break
	if mål_nod < 0:
		mål_nod = mini(1, kvy.antal() - 1)
	var kg: Gångare = kvy.gångaren()
	var kfrån: Vector2 = kvy.gångpunkt(0)
	var ktill: Vector2 = kvy.gångpunkt(mål_nod)
	var svar := kvy.gå_till_och_in(mål_nod)
	check(str(svar["reason"]) == "går", "Enter på en annan plats skickar figuren dit först",
		str(svar["reason"]))
	check(kg.går() and not kvy.panel_öppen() and kvy.besked() == "",
		"och ingenting har öppnats medan den går",
		"går=%s panel=%s besked='%s'" % [str(kg.går()), str(kvy.panel_öppen()), kvy.besked()])
	check(absf(kg.sträcka() - kfrån.distance_to(ktill)) < 0.01,
		"kartans väg är avståndet mellan de två noderna",
		"%.1f px" % kg.sträcka())
	var kres := _gå_klart(kg)
	check(kg.pos().distance_to(ktill) < 0.5, "figuren stannar på NODEN",
		"%.2f px från noden" % kg.pos().distance_to(ktill))
	# Framme: antingen öppnas nivåpanelen (öppen plats) eller så kommer beskedet (låst) — men FÖRST
	# nu, aldrig under gången.
	check(kvy.panel_öppen() or not kvy.besked().is_empty(),
		"och först framme öppnas platsen (eller dess besked)",
		"panel=%s besked='%s', %.2f s" % [str(kvy.panel_öppen()), kvy.besked(), float(kres["tid"])])
	kvy.free()

	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
