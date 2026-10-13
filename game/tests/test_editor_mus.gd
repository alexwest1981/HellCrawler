## Provet för MUSEN i fiendeeditorn (M120). Alex ville RITA med musen, och det som avgör om ett drag
## blir ett streck eller en rad prickar är interpoleringen mellan två mushändelser.
##
## Provet mäter fyra saker:
##   1. mappningen skärmpunkt -> konstpixel fram och tillbaka (en INVARIANT, inte en fast koordinat),
##   2. att ETT drag (två mushändelser, långt ifrån varandra) ritar en obruten linje — noll gluggar,
##   3. att det gamla sättet (en pixel per händelse) ger gluggar i SAMMA drag: mekanismen är bevisad,
##   4. att strecket är IDEMPOTENT och att tangentbordet är kvar oförändrat.
##
## Provet skriver ALDRIG i spelets data: receptet muteras bara i minnet (`rensa`), och scenen läses.
##
## KÖRNING: tools/ett_prov.sh tests/test_editor_mus.gd
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


## De suddade pixlarna som en mängd. Provet frågar editorns EGET recept, inte en kopia av det.
func _sudda(editor: Control) -> Dictionary:
	var m := {}
	var r = editor.recept.get(editor.id, {})
	if typeof(r) != TYPE_DICTIONARY:
		return m
	for p in (r.get("sudda", []) as Array):
		m[Vector2i(int(p[0]), int(p[1]))] = true
	return m


## Gluggarna längs en linje: varje x mellan ändpunkterna ska ha MINST en suddad pixel. Räknas ur
## geometrin (en horisontell/kraftigt lutande linje har ett x per steg), inte ur en kopia av
## Bresenham — provet ska mäta EGENSKAPEN "obruten", inte koden som ritar den.
func _gluggar(m: Dictionary, a: Vector2i, b: Vector2i) -> int:
	var hål := 0
	var x0: int = mini(a.x, b.x)
	var x1: int = maxi(a.x, b.x)
	for x in range(x0, x1 + 1):
		var finns := false
		for p in m.keys():
			if p.x == x:
				finns = true
				break
		if not finns:
			hål += 1
	return hål


func _musklick(editor: Control, p: Vector2i, tryckt: bool, höger := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT if höger else MOUSE_BUTTON_LEFT
	e.pressed = tryckt
	e.position = editor.duk_skarm(p)
	editor._gui_input(e)


func _musrörelse(editor: Control, p: Vector2i) -> void:
	var e := InputEventMouseMotion.new()
	e.position = editor.duk_skarm(p)
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	editor._gui_input(e)


func _initialize() -> void:
	print("— fiendeeditorn: musen, draget och gluggarna —")
	var scen: PackedScene = load("res://editor/fiendeeditor.tscn")
	check(scen != null, "scenen finns")
	if scen == null:
		quit(1)
		return
	var editor: Control = scen.instantiate()
	root.add_child(editor)
	await process_frame
	check(editor.bild != null, "fiendens duk är laddad", str(editor.id))
	if editor.bild == null:
		quit(1)
		return

	# 1. MAPPNINGEN FRAM OCH TILLBAKA. Fönsterstorleken skiljer sig mellan en huvudlös körning och
	# spelet, så en fast skärmkoordinat hade mätt något annat än det provet pekar på. Invarianten är
	# att punkten hamnar INUTI den pixel mappningen pekar ut.
	var fel_mappning := 0
	var prover := [Vector2i(0, 0), Vector2i(60, 60), Vector2i(119, 119), Vector2i(17, 91), Vector2i(99, 3)]
	for p in prover:
		var tillbaka: Vector2i = editor._duk_pixel(editor.duk_skarm(p))
		if tillbaka != p:
			fel_mappning += 1
	check(fel_mappning == 0, "skärm -> pixel -> skärm är samma pixel i båda riktningarna",
		"%d av %d fel" % [fel_mappning, prover.size()])

	# Ett rent recept för arten: `rensa` muterar bara minnet.
	editor.rensa(editor.id)
	editor.verktyg = "sudda"

	# 2. ETT DRAG, TVÅ HÄNDELSER. Tryck i A, EN rörelse till B, släpp. Det är precis ett snabbt drag:
	# mellanhändelserna finns inte, och det är dem interpoleringen ritar.
	var a := Vector2i(30, 30)
	var b := Vector2i(90, 70)
	var t0 := Time.get_ticks_usec()
	_musklick(editor, a, true)
	_musrörelse(editor, b)
	_musklick(editor, b, false)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var m := _sudda(editor)
	var minst: int = maxi(absi(b.x - a.x), absi(b.y - a.y)) + 1
	var hål := _gluggar(m, a, b)
	check(m.size() >= minst, "draget ritade en obruten linje mellan händelserna",
		"%d pixlar (minst %d), %.1f ms" % [m.size(), minst, ms])
	check(hål == 0, "noll gluggar längs linjen", "%d av %d x-kolumner saknade pixel" % [hål, absi(b.x - a.x) + 1])
	check(m.has(a) and m.has(b), "båda ändpunkterna är ritade", "%s -> %s" % [str(a), str(b)])

	# 3. MOTPROVET: samma drag på det GAMLA sättet (en pixel per händelse). Provet biter bara om det
	# kan visa att skillnaden kommer från interpoleringen — annars vore strecket målat ändå.
	editor.rensa(editor.id)
	_musklick(editor, a, true)
	editor.klicka(b.x, b.y, false)          # händelsen ritas rakt av, som förr: ingen linje emellan
	_musklick(editor, b, false)
	var gammalt := _sudda(editor)
	check(_gluggar(gammalt, a, b) > 0, "utan interpoleringen blir SAMMA drag fullt av gluggar",
		"%d pixlar, %d gluggar" % [gammalt.size(), _gluggar(gammalt, a, b)])

	# 4. IDEMPOTENT: samma streck två gånger får inte blinka bort sitt eget arbete (musen suddar,
	# den växlar inte). Mätt som samma mängd efter ett andra drag över samma väg.
	editor.rensa(editor.id)
	_musklick(editor, a, true)
	_musrörelse(editor, b)
	_musklick(editor, b, false)
	var första := _sudda(editor)
	_musklick(editor, a, true)
	_musrörelse(editor, b)
	_musklick(editor, b, false)
	var andra := _sudda(editor)
	check(första.size() == andra.size() and första.size() > 0,
		"ett andra drag över samma streck ändrar ingenting (idempotent)",
		"%d -> %d pixlar" % [första.size(), andra.size()])

	# Högerklicket RENSAR (kvar från M83): samma väg med höger knapp måste ta bort strecket.
	_musklick(editor, a, true, true)
	_musrörelse(editor, b)
	_musklick(editor, b, false, true)
	check(_sudda(editor).size() == 0, "högerknappen rensar strecket",
		"%d pixlar kvar" % _sudda(editor).size())

	# 5. TANGENTBORDET ÄR KVAR. Det är ett ALTERNATIV, inte vägen — markören flyttas och space växlar
	# pixeln, precis som förr (samma två funktioner som musen går genom).
	var mark: Vector2i = editor.markör
	editor._unhandled_input(_tangent(KEY_RIGHT))
	check(editor.markör.x == mini(editor.bild.get_width() - 1, mark.x + 1),
		"piltangenten flyttar markören", "%s -> %s" % [str(mark), str(editor.markör)])
	editor._unhandled_input(_tangent(KEY_SPACE))
	var efter_space := _sudda(editor).has(editor.markör)
	editor._unhandled_input(_tangent(KEY_SPACE))
	var efter_igen := _sudda(editor).has(editor.markör)
	check(efter_space and not efter_igen, "space växlar pixeln under markören (tangentbordet kvar)")

	print("— fiendeeditorns mus: %d kontroller, %d fel —" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _tangent(kod: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = kod
	e.pressed = true
	return e
