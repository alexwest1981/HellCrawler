## Storleken när man skapar ett nytt rum (M154). Alex: *"Jag vill själv kunna avgöra rum-storlek, så låt
## mig ange t ex 6x6, 9x3 eller vad jag behöver när jag skapar ett nytt rum."*
##
## N öppnar rutan; provet mäter att våningen/rummet blir EXAKT den storlek man skriver (inte kvadratisk,
## inte 17x17), att gränserna håller, och att nollställningen görs som förut (inga noder kvar från förra
## våningen, ingen markering).
##
##   tools/ett_prov.sh tests/test_editor_rum.gd
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


func _skapa(w: int, h: int) -> void:
	editor._sd_bredd.value = w
	editor._sd_höjd.value = h
	editor._skapa_rum()


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	editor.position = Vector2.ZERO
	await process_frame
	await process_frame

	check(editor.storlek_dialog != null, "storleksrutan byggs (N öppnar den)")
	check(editor.storlek_dialog != null and editor.storlek_dialog.dialog_text.is_empty(),
		"rutan frågar inte om något annat än storleken")

	# Kvadrat, som förut — men vald av Alex.
	_skapa(6, 6)
	check(editor.floor.w == 6 and editor.floor.h == 6, "6×6 blir exakt 6×6",
		"%d×%d" % [editor.floor.w, editor.floor.h])

	# Det som inte gick förut: en rektangel.
	_skapa(9, 3)
	check(editor.floor.w == 9 and editor.floor.h == 3, "9×3 blir exakt 9×3",
		"%d×%d" % [editor.floor.w, editor.floor.h])
	check(editor.floor.tiles.size() == 3, "och rutnätet har tre rader (%d)" % editor.floor.tiles.size())
	check(editor.floor.tiles[0].size() == 9, "och nio kolumner (%d)" % editor.floor.tiles[0].size())
	check(editor.floor.is_floor_at(Vector2i(1, 1)), "innanmätet är golv (man ritar direkt)")
	check(not editor.floor.is_floor_at(Vector2i(0, 0)), "kanten är vägg (rummet har ram)")

	# Nollställningen: inga noder eller markeringar kvar från våningen innan.
	check(editor.floor.rekvisita.is_empty(), "ingen rekvisita kvar från förra våningen")
	check(editor.vald.is_empty(), "inget är markerat")
	check(not editor.ändrad, "våningen räknas som orörd (inget att spara av misstag)")
	check(editor.status.contains("9×3"), "statusraden säger vilken storlek man fick", editor.status)

	# Gränserna: för litet blir 3, för stort blir 64 — en våning på 1×1 går inte att spela.
	_skapa(1, 1)
	check(editor.floor.w == 3 and editor.floor.h == 3, "1×1 klipps till 3×3",
		"%d×%d" % [editor.floor.w, editor.floor.h])
	_skapa(999, 999)
	check(editor.floor.w == 64 and editor.floor.h == 64, "999 klipps till 64",
		"%d×%d" % [editor.floor.w, editor.floor.h])

	# Ett block i den storleken går att spara: storleken är det blocket får.
	_skapa(9, 3)
	var sparad := MapIo.to_dict(editor.floor)
	check((sparad["tiles"] as Array).size() == 3, "kartfilen får tre rader, som våningen")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
