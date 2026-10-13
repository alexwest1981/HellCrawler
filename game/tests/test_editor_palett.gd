## Provet för PALETTEN i fiendeeditorn (M120). Alex: *"en palett att plocka från i stället för att
## gissa vilka färger som finns"*.
##
## Provet mäter fem saker:
##   1. färgerna kommer ur SPELETS EGEN palett — varje ruta jämförs med `assets/palette.json`, raden
##      för raden, så en handplockad lista i editorn hade fallit här,
##   2. rutnätet har en ruta per färg och alla ligger innanför panelen,
##   3. ett klick i en ruta väljer DEN färgen (och märker den som vald),
##   4. klicket målar INTE i figuren — paletten ligger utanför duken och får inte falla igenom,
##   5. den valda färgen är den som hamnar i receptet när man målar.
##
## Provet skriver ALDRIG i spelets data.
##
## KÖRNING: tools/ett_prov.sh tests/test_editor_palett.gd
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


func _antal(editor: Control, nyckel: String) -> int:
	var r = editor.recept.get(editor.id, {})
	if typeof(r) != TYPE_DICTIONARY:
		return 0
	return (r.get(nyckel, []) as Array).size()


func _målad_färg(editor: Control, x: int, y: int) -> String:
	var r = editor.recept.get(editor.id, {})
	if typeof(r) != TYPE_DICTIONARY:
		return ""
	for punkt in (r.get("måla", []) as Array):
		if int(punkt[0]) == x and int(punkt[1]) == y:
			return str(punkt[2])
	return ""


func _initialize() -> void:
	print("— fiendeeditorns palett: färgerna ur spelets egen fil —")
	var scen: PackedScene = load("res://editor/fiendeeditor.tscn")
	check(scen != null, "scenen finns")
	if scen == null:
		quit(1)
		return
	var editor: Control = scen.instantiate()
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
	check(editor.bild != null, "fiendens duk är laddad", str(editor.id))
	if editor.bild == null:
		quit(1)
		return

	# 1. FÄRGERNA UR `assets/palette.json` — SAMMA FIL SOM GENERATORERNA LÄSER. Jämförelsen görs mot
	# filen, inte mot `Palett`: en kopia av listan i editorn skulle vara grön mot sig själv.
	var rå = JSON.parse_string(FileAccess.get_file_as_string("res://assets/palette.json"))
	check(rå is Array and rå.size() > 8, "palettfilen finns och har färger",
		"%d rader" % (rå.size() if rå is Array else 0))
	var antal: int = Palett.antal()
	check(antal == (rå as Array).size(), "Palett.antal() är filens antal", "%d" % antal)
	var fel_filg := 0
	for i in antal:
		var rad: Array = rå[i]
		var ur_filen := Color8(int(rad[0]), int(rad[1]), int(rad[2])).to_html(false)
		if Palett.c(i).to_html(false) != ur_filen:
			fel_filg += 1
	check(fel_filg == 0, "varje ruta är sin rad i palettfilen", "%d av %d fel" % [fel_filg, antal])

	# 2. RUTNÄTET: en ruta per färg, alla innanför panelen.
	var per: int = editor.palett_per_rad()
	var rader: int = editor.palett_rader()
	check(rader >= 1 and per * rader >= antal, "rutnätet rymmer varje färg",
		"%d per rad, %d rader" % [per, rader])
	check(per * (rader - 1) < antal, "ingen rad är tom (sista raden används)")
	var utanför := 0
	for i in antal:
		var r: Rect2 = editor.palett_ruta(i)
		if r.position.x < editor.PANEL_X - 0.5 or r.end.x > editor.PANEL_X + editor.PANEL_BREDD + 0.5:
			utanför += 1
	check(utanför == 0, "alla rutor ligger innanför panelen", "%d utanför" % utanför)

	# 3. ETT KLICK VÄLJER DEN FÄRGEN.
	editor.rensa(editor.id)
	var sudda_före := _antal(editor, "sudda")
	var måla_före := _antal(editor, "måla")
	var prover := [0, 13, antal - 1]
	var fel_val := 0
	for i in prover:
		editor.klick_palett(i)
		if editor.palett_vald() != i:
			fel_val += 1
	check(fel_val == 0, "klick i en ruta markerar DEN rutan som vald",
		"prövade %s av %d" % [str(prover), antal])

	# 4. KLICKET MÅLAR INTE I FIGUREN. Paletten ligger till höger om duken; föll klicket igenom
	# skulle varje färgval sätta en pixel i figuren på den plats man pekade.
	check(_antal(editor, "sudda") == sudda_före and _antal(editor, "måla") == måla_före,
		"ett klick i paletten rör inte figuren",
		"sudda %d, måla %d" % [_antal(editor, "sudda"), _antal(editor, "måla")])

	# 5. DEN VALDA FÄRGEN ÄR DEN SOM MÅLAS. Välj färg 13 och rita en pixel i duken: receptet ska bära
	# just den färgens hex, inte penselns gamla.
	editor.klick_palett(13)
	check(editor.verktyg == "måla", "att välja en färg ställer verktyget på måla", editor.verktyg)
	editor.klicka(40, 40, false)
	check(_målad_färg(editor, 40, 40) == Palett.c(13).to_html(false),
		"pixeln målades med palettfärgen",
		"%s mot palett 13 = %s" % [_målad_färg(editor, 40, 40), Palett.c(13).to_html(false)])
	# Och en ANNAN färg byter den valda — annars vore paletten en enda färg med 27 rutor.
	editor.klick_palett(2)
	editor.klicka(41, 40, false)
	check(_målad_färg(editor, 41, 40) == Palett.c(2).to_html(false) and editor.palett_vald() == 2,
		"en annan ruta ger en annan färg i duken",
		"%s mot %s" % [_målad_färg(editor, 41, 40), Palett.c(2).to_html(false)])

	# Utanför paletten finns ingen ruta: ett klick i duken ska inte tolkas som ett färgval.
	check(editor.palett_index_vid(editor.duk_skarm(Vector2i(60, 60))) == -1,
		"ett klick i duken är inget palettval")

	print("— fiendeeditorns palett: %d kontroller, %d fel —" % [checks, fails])
	quit(1 if fails > 0 else 0)
