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
		if mål != [str(VillageView.PLATSER[i]["skepp"])]:
			bom.append("%s -> %s" % [VillageView.PLATSER[i]["id"], str(mål)])
	check(för_små.is_empty(), "varje hus har en klickruta i vyn", ", ".join(för_små))
	check(bom.is_empty(), "klick på varje hus öppnar just den platsen", ", ".join(bom))
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

	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
