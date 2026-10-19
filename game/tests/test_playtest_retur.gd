## Playtest-rundan (M156): P i karteditorn → spela våningen i 3D → F1 möblera → F2 spara → F3 tillbaka
## till editorn, som läser våningen från disk. F3 ska bara finnas i en playtest, inte i en vanlig start.
##
##   tools/ett_prov.sh tests/test_playtest_retur.gd
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


func _ny_main() -> Node:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	return m


func _tryck(m: Node, key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	m._unhandled_input(e)


func _init() -> void:
	# 1. Utan playtest: F3 gör ingenting (en vanlig start ska inte hoppa in i editorn).
	var vanlig := _ny_main()
	await process_frame
	# Tangenterna når bara fram i en KÖRNING (vyn), inte i byn — och menyn ligger överst och äter dem
	# först. Provet trycker alltså i en startad våning med menyn stängd.
	vanlig._start_run("stage_01", 20260919)
	await process_frame
	if vanlig.meny != null:
		vanlig.meny.visible = false
	vanlig._playtestad = false
	_tryck(vanlig, KEY_F3)
	await process_frame
	check(current_scene == null or not str(current_scene.scene_file_path).ends_with("editor.tscn"),
		"F3 i en vanlig start byter inte scen")

	# 2. Med playtest: F3 går till editorn.
	vanlig.queue_free()
	await process_frame
	var pt := _ny_main()
	await process_frame
	pt._start_run("stage_01", 20260919)
	await process_frame
	if pt.meny != null:
		pt.meny.visible = false
	pt._playtestad = true
	_tryck(pt, KEY_F3)
	await process_frame
	await process_frame
	var väg := "" if current_scene == null else str(current_scene.scene_file_path)
	check(väg.ends_with("editor/editor.tscn"), "F3 i en playtest går tillbaka till editorn", väg)

	# 3. Editorn öppnar DEN våning man spelade, inte stage_01 våning 1: F3 har inga argument att skicka.
	var f := FileAccess.open("user://senast.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage_id": "stage_03", "floor": 2}))
	f.close()
	var red = load("res://editor/editor.tscn").instantiate()
	root.add_child(red)
	await process_frame
	await process_frame
	check(red.floor.stage_id == "stage_03" and red.floor.index == 2,
		"editorn öppnar våningen man senast spelade",
		"%s %d" % [red.floor.stage_id, red.floor.index])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://senast.json"))

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
