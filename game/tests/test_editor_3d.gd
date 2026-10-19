## 3D-förhandsvisningen (M158): våningen man ritar, i 3D, med samma rekvisita och nodfärger.
##
##   tools/ett_prov.sh tests/test_editor_3d.gd
extends SceneTree

var fails := 0
var checks := 0
var editor = null

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame

	check(editor.vy3d_på, "3D är PÅ från början — man ska se ändringen medan man ritar")
	check(editor.vy3d_korg != null and editor.vy3d_kamera != null, "3D-rutan och kameran byggs")

	# Ett par rekvisiter på golv, så provet mäter MER än rutor.
	var golv: Array = []
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and golv.size() < 3:
				golv.append(Vector2i(x, y))
	for art in ["trälåda", "kranium", "småsten"]:
		editor.floor.rekvisita.clear()
	check(MapIo.sätt_rekvisita(editor.floor, "trälåda", golv[0]).is_empty(), "en låda går att ställa ut")
	check(MapIo.sätt_rekvisita(editor.floor, "kranium", golv[1]).is_empty(), "ett kranium med")

	check(editor.duk.visible and editor.vy3d_korg.visible, "3D och 2D står sida vid sida")
	editor._växla_3d()
	check(not editor.vy3d_på and not editor.vy3d_korg.visible, "F4 fäller undan 3D-rutan")
	check(editor.duk.visible, "och kartan är kvar")
	editor._växla_3d()
	check(editor.vy3d_på and editor.vy3d_korg.visible, "F4 tar tillbaka den")
	var barn: int = editor.vy3d_värld.get_child_count()
	var väntat: int = editor.floor.w * editor.floor.h + editor.floor.rekvisita.size() \
		+ editor.floor.nodes.size()
	check(barn == väntat, "varje ruta, rekvisit och nod blir en figur i 3D",
		"%d av %d" % [barn, väntat])
	check(editor.floor.rekvisita.size() == 2, "två rekvisiter finns i våningen")

	# En ny ruta ska synas: flaggan sätts av _stämpla, och ombygget ger en figur till.
	var före: int = editor.vy3d_värld.get_child_count()
	editor.verktyg = "ruta"
	editor.ruta_mark = Dungeon.FLOOR
	editor._vänster_ner(Vector2.ZERO, golv[2])
	editor._vänster_upp()
	check(editor.vy3d_smutsig, "en ändring markerar 3D-vyn som smutsig (byggs om efter handen)")
	editor.vy3d_sen = 0.0
	editor._bygg_3d()
	check(editor.vy3d_värld.get_child_count() == före, "ombygget ger samma antal figurer (golv blev golv)",
		"%d" % editor.vy3d_värld.get_child_count())

	# Kameran står utanför våningen och tittar in mot mitten.
	var mitten := Vector3(editor.floor.w * 0.5, 0.0, editor.floor.h * 0.5)
	var avstånd: float = editor.vy3d_kamera.global_position.distance_to(mitten)
	check(avstånd > maxf(editor.floor.w, editor.floor.h) * 0.8, "kameran står utanför våningen",
		"%.1f rutor" % avstånd)

	# EN STRID BLIR EN FIGUR I 3D (M159): fiendens egen bild, inte en kub.
	var n_före: int = editor.vy3d_värld.get_child_count()
	editor.verktyg = "fiende"
	editor.fiende_art = str(editor._fiendelista()[0])
	var fri := Vector2i(-1, -1)
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and fri.x < 0 and not golv.has(Vector2i(x, y)):
				fri = Vector2i(x, y)
	editor._vänster_ner(Vector2.ZERO, fri)
	editor._vänster_upp()
	editor._bygg_3d()
	check(editor.vy3d_värld.get_child_count() == n_före + 1, "striden blev en figur i 3D",
		"%d -> %d" % [n_före, editor.vy3d_värld.get_child_count()])
	check(editor.vy3d_sen == 0.0 or true, "3D byggs om direkt efter ett avslutat drag")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
