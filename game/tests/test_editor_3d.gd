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

	check(not editor.vy3d_på, "3D är av från början (2D-vyn är den man ritar i)")
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

	editor._växla_3d()
	check(editor.vy3d_på, "3D-läget är på")
	check(editor.duk.visible == false and editor.vy3d_korg.visible, "3D-rutan tar kartans plats")
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

	editor._växla_3d()
	check(not editor.vy3d_på and editor.duk.visible, "tillbaka i 2D: kartan syns igen")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
