## Provet för LJUSKÄLLAN i fiendeeditorn (M120). Alex: *"någon knapp för 'isLightSource=true' eller
## något"* — och kravet är att flaggan SKA GÖRA NÅGOT, inte bara stå i en ruta i UI:t.
##
## Provet mäter fem saker:
##   1. kryssrutan växlar flaggan (och ett klick i den ritar INTE i figuren — den ligger utanför duken),
##   2. tangenten `L` gör samma sak (samma funktion, ett ställe),
##   3. flaggan kommer med till FILEN och läses tillbaka (det är det som sparas),
##   4. SPELETS egen väg ger modellen kandelaberns glöd-shader (M115) när flaggan är satt, och rör inte
##      materialet när den inte är det — det är kontrollen, och den visar att flaggan är mekanismen,
##   5. shadern är SAMMA som kandelabern bär (`main._laga_shader`), inte en ny glöd-väg.
##
## Provet skriver ALDRIG i spelets data: receptet sparas i `user://`.
##
## KÖRNING: tools/ett_prov.sh tests/test_editor_ljuskalla.gd
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


func _shaderväg(m) -> String:
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		return (m as ShaderMaterial).shader.resource_path.get_file()
	return ""


func _tangent(kod: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = kod
	e.pressed = true
	return e


func _initialize() -> void:
	print("— fiendeeditorns ljuskälla: flaggan, filen och glöden —")
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
	if not editor.has_method("vaxla_ljuskalla"):
		print("  FEL  editorns script laddades inte (se Parse Error ovan)")
		quit(1)
		return
	check(editor.bild != null, "fiendens duk är laddad", str(editor.id))
	if editor.bild == null:
		quit(1)
		return
	editor.rensa(editor.id)

	# 1. KRYSSRUTAN. Receptet är rent, så flaggan ska vara av — och växlingen fram och tillbaka ska ge
	# tillbaka samma läge (en växling, inte en envägsväg).
	var var_av: bool = not editor.ljuskalla()
	check(var_av, "flaggan är av i ett rent recept")
	check(editor.vaxla_ljuskalla(), "kryssrutan slår PÅ flaggan")
	check(editor.ljuskalla(), "flaggan står i receptet efter växlingen")
	check(not editor.vaxla_ljuskalla(), "och växlar tillbaka till av")
	check(not editor.ljuskalla(), "flaggan är av igen")
	editor.vaxla_ljuskalla()          # på igen, för resten av provet

	# ETT KLICK I KRYSSRUTAN ritar inte i figuren: den ligger till höger om duken, och utan vakten
	# hade varje kryss satt en pixel i figuren på den plats man pekade.
	var måla_före := _antal(editor, "måla")
	var r: Rect2 = editor.ljuskalla_ruta()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = editor._ruta(r.position + r.size * 0.5)
	editor._gui_input(e)
	check(not editor.ljuskalla(), "ett klick i kryssrutan växlar flaggan (av)")
	check(_antal(editor, "måla") == måla_före, "klicket i kryssrutan rör inte figuren",
		"målat %d" % _antal(editor, "måla"))

	# 2. TANGENTEN `L` ÄR SAMMA FUNKTION (ett ställe, två vägar in).
	editor._unhandled_input(_tangent(KEY_L))
	check(editor.ljuskalla(), "`L` slår på flaggan")

	# 3. FILEN. Flaggan hör till det som SPARAS, annars är den borta vid nästa start.
	var väg := "user://ljuskallprov/retuschering.json"
	var fel: String = editor.spara(väg)
	check(fel.is_empty(), "receptet sparades", väg)
	var läst := Retusch.läs(väg)
	check(Retusch.ar_ljuskalla(läst, editor.id), "flaggan kom med till filen", editor.id)
	check(not Retusch.ar_ljuskalla(läst, "finns_inte_alls"), "en okänd art ärver inte flaggan")
	check(not Retusch.ar_ljuskalla({}, editor.id), "ett tomt recept svarar av")

	# 4. SPELET. `_voxel_fiende` är den väg fienden tar när striden ställs upp (M108), och den ska ge
	# modellen kandelaberns glöd-shader när flaggan står i receptet.
	var art: String = editor.id
	var tex: Texture2D = load("res://assets/enemies/%s.png" % art)
	check(tex != null, "arkets bild finns för arten", art)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if not main.has_method("_voxel_fiende"):
		print("  FEL  spelets script laddades inte")
		quit(1)
		return
	var nod := Dungeon.FloorNode.new()
	nod.enemy_id = art
	main._fiendeprov = ""
	# PÅ: modellen ska bära glödschadern.
	main._retusch = {art: {"ljuskalla": true}}
	var spr := Sprite3D.new()
	spr.pixel_size = 0.012
	main._voxel_fiende(spr, nod)
	var mi := spr.get_node_or_null("voxel") as MeshInstance3D
	check(mi != null, "spelet byggde en voxelmodell av figuren", art)
	if mi == null:
		quit(1)
		return
	var m: Material = mi.material_override
	check(_shaderväg(m) == "voxel_rekvisit.gdshader",
		"flaggan ger modellen kandelaberns glöd-shader", _shaderväg(m))
	check(m is ShaderMaterial and is_equal_approx(
		float((m as ShaderMaterial).get_shader_parameter("glod")), main.LJUSKALLA_GLÖD),
		"glöden är spelets EGEN siffra (LJUSKALLA_GLÖD)", str(main.LJUSKALLA_GLÖD))
	check(m is ShaderMaterial and (m as ShaderMaterial).shader == main._laga_shader(),
		"det är kandelaberns egen shader, inte en ny glöd-väg (M115)")

	# AV: materialet ska vara modellens eget — annars är det inte flaggan som gör skillnaden.
	var spr2 := Sprite3D.new()
	spr2.pixel_size = 0.012
	main._retusch = {art: {"ljuskalla": false}}
	main._voxel_fiende(spr2, nod)
	var mi2 := spr2.get_node_or_null("voxel") as MeshInstance3D
	check(mi2 != null, "modellen byggs även utan flaggan")
	check(_shaderväg(mi2.material_override) != "voxel_rekvisit.gdshader",
		"utan flaggan rörs materialet inte", _shaderväg(mi2.material_override))

	print("— fiendeeditorns ljuskälla: %d kontroller, %d fel —" % [checks, fails])
	quit(1 if fails > 0 else 0)
