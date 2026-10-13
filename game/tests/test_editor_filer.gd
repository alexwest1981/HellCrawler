## Provet för FILLISTAN i fiendeeditorn (M120). Alex: *"en lista över alla filer så man enkelt väljer
## vilken man redigerar"* — i stället för att komma ihåg sökvägar och bläddra med `,`/`.`.
##
## Provet mäter fem saker:
##   1. listan har EN cell per redigerbar tillgång (och fler än en rad: annars mäter provet ingenting),
##   2. radbrytningen är den DELADE regeln (`Kortvaggar`) och ingen rad har fler än taket,
##   3. ett val i listan laddar DEN arten (och bara den knappen är markerad),
##   4. tangentbordet och listan följer varandra (` . ` byter art och markeringen flyttar med),
##   5. rullaren rullar — och valet skjuts i bild när det ligger utanför fönstret.
##
## Provet skriver ALDRIG i spelets data.
##
## KÖRNING: tools/ett_prov.sh tests/test_editor_filer.gd
extends SceneTree

var fails := 0
var checks := 0


func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


## Antalet celler per rad, räknat ur barnens y-position (samma mätning som `test_hud.gd` gör på
## butikernas rutnät: formen på raden är det som bevisar radbrytningen).
func _rader(rutnät: GridContainer) -> Dictionary:
	var per_rad := {}
	for b in rutnät.get_children():
		var rad: int = int(round((b as Control).position.y))
		per_rad[rad] = int(per_rad.get(rad, 0)) + 1
	return per_rad


func _initialize() -> void:
	print("— fiendeeditorns fillista: rutnätet, valet och rullaren —")
	var scen: PackedScene = load("res://editor/fiendeeditor.tscn")
	check(scen != null, "scenen finns")
	if scen == null:
		quit(1)
		return
	var editor: Control = scen.instantiate()
	# FÖNSTRET SÄTTS (projektets storlek): i en huvudlös körning är fönstret 64x36, och panelens
	# skalning (`_skala`) blir då en tiondel — radbrytningen skulle mätas på en yta som inte finns i
	# spelet. Ankaret lossas så ytan får sin egen storlek, och `resized` räknar om layouten som vanligt.
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	root.add_child(editor)
	await process_frame
	await process_frame
	# ETT TOLKNINGSFEL I EDITORN FÅR PROVET ATT HÄNGA i stället för att falla (scriptfelet
	# avbryter `_initialize` och trädet snurrar vidare). Vakta först, så sviten får en rad
	# i stället för två minuters timeout.
	if not editor.has_method("palett_vald"):
		print("  FEL  editorns script laddades inte (se Parse Error ovan)")
		quit(1)
		return
	check(editor._skala > 2.0, "ytan är skalad till ett riktigt fönster (annars mäts fel yta)",
		"_skala %.2f" % editor._skala)
	check(editor.filer.size() > 0, "editorn hittar tillgångarna", "%d st" % editor.filer.size())
	if editor.filer.is_empty():
		quit(1)
		return
	check(editor.rutnät != null and editor.rull != null, "listan är byggd")
	if editor.rutnät == null:
		quit(1)
		return

	# 1. EN CELL PER TILLGÅNG.
	check(editor.rutnät.get_child_count() == editor.filer.size(),
		"en cell per redigerbar tillgång",
		"%d celler mot %d filer" % [editor.rutnät.get_child_count(), editor.filer.size()])
	var per_rad := _rader(editor.rutnät)
	check(per_rad.size() > 1, "listan har fler än en rad (annars mäter provet ingenting)",
		"%d rader" % per_rad.size())

	# 2. RADBRYTNINGEN ÄR DEN DELADE REGELN.
	var cell: Vector2 = (editor.rutnät.get_child(0) as Control).custom_minimum_size
	var väntat: int = Kortvaggar.kolumner(editor.filer.size(), cell.x, editor._fs(editor.PANEL_BREDD))
	check(editor.rutnät.columns == väntat, "kolumnerna kommer ur Kortvaggar.kolumner",
		"%d kolumner (cell %.0f px)" % [editor.rutnät.columns, cell.x])
	var bredast := 0
	for rad in per_rad:
		bredast = maxi(bredast, int(per_rad[rad]))
	check(bredast <= Kortvaggar.TAK, "ingen rad har fler celler än taket",
		"%d av taket %d" % [bredast, Kortvaggar.TAK])
	# Den DELADE regeln är oförändrad av flytten: de tre måtten ur husets egen tabell.
	var huset := [
		[16, 64.0, 4], [28, 64.0, 4], [8, 205.0, 2],
	]
	var fel_hus := 0
	for post in huset:
		if Kortvaggar.kolumner(int(post[0]), float(post[1])) != int(post[2]):
			fel_hus += 1
	check(fel_hus == 0, "värdshuset/juveleraren/butiken får samma kolumner som förr",
		"16->4, 28->4, 8 varor->2; %d fel" % fel_hus)

	# KNAPPARNA SLÄPPER TANGENTBORDET (annars dör `,`/`.` och `S` tyst — se `kortvaggar.md`).
	var med_fokus := 0
	for b in editor.rutnät.get_children():
		if (b as Button).focus_mode != Control.FOCUS_NONE:
			med_fokus += 1
	check(med_fokus == 0, "ingen cell tar tangentbordet (FOCUS_NONE)", "%d med fokus" % med_fokus)

	# 3. ETT VAL I LISTAN LADDAR DEN ARTEN.
	var först: String = editor.filer[0]
	var sist: String = editor.filer[editor.filer.size() - 1]
	check(editor.id == först, "editorn börjar på första arten", editor.id)
	(editor._knappar[sist] as Button).emit_signal("pressed")
	await process_frame
	check(editor.id == sist, "ett klick i listan väljer den arten", "%s -> %s" % [först, editor.id])
	check(editor.bild != null, "den valda arten är laddad", editor.id)
	var markerade := 0
	for namn in editor._knappar:
		if (editor._knappar[namn] as Button).button_pressed:
			markerade += 1
	check(markerade == 1 and (editor._knappar[sist] as Button).button_pressed,
		"bara den valda cellen är markerad", "%d markerade" % markerade)
	# Namnet i receptet är den valda arten — valet når hela vägen in i retuscheringen.
	check(editor._antal("sudda") == (editor.recept.get(sist, {}).get("sudda", []) as Array).size(),
		"retuschen läses för den valda arten", sist)

	# 4. TANGENTBORDET FÖLJER MED. ` . ` byter art som förr, och markeringen flyttar med — annars
	# skulle listan visa en art medan ytan visar en annan.
	var index_före: int = editor.index
	var e := InputEventKey.new()
	e.keycode = KEY_PERIOD
	e.pressed = true
	editor._unhandled_input(e)
	await process_frame
	check(editor.index == (index_före + 1) % editor.filer.size(), "`.` byter art som förr",
		"%d -> %d" % [index_före, editor.index])
	check((editor._knappar[editor.id] as Button).button_pressed,
		"markeringen följer tangentbordet", editor.id)

	# 5. RULLAREN. Höjden är innehållets — eller taket när innehållet är högre: innehållet är högre
	# här, alltså ska fönstret vara LÄGRE än innehållet (annars finns inget att rulla i).
	var innehåll: float = editor.rutnät.get_combined_minimum_size().y
	var fönster: float = editor.rull.custom_minimum_size.y
	check(innehåll > fönster, "innehållet är högre än rullarens fönster",
		"innehåll %.0f px mot fönster %.0f px" % [innehåll, fönster])
	# Välj den SISTA cellen: den ligger utanför fönstret, och `Kortvaggar.visa` ska skjuta den i bild.
	editor._valj_från_lista(editor.filer[editor.filer.size() - 1])
	for i in 4:
		await process_frame
	check(editor.rull.scroll_vertical > 0, "valet utanför fönstret skjuts i bild",
		"scroll_vertical %d" % int(editor.rull.scroll_vertical))

	print("— fiendeeditorns fillista: %d kontroller, %d fel —" % [checks, fails])
	quit(1 if fails > 0 else 0)
