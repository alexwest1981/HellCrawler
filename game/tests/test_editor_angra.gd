## Ångra (M157): Ctrl+Z / Ctrl+Y. Referenseditorn har det; utan det är varje felklick handarbete.
##
##   tools/ett_prov.sh tests/test_editor_angra.gd
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


func _tryck(key: Key, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	editor._unhandled_input(e)


func _noder() -> int:
	return editor.floor.nodes.size()


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	editor.position = Vector2.ZERO
	await process_frame
	await process_frame
	editor._historik.clear()
	editor._framtid.clear()

	# 1. Ingen historik: Ctrl+Z ska säga det, inte krascha.
	_tryck(KEY_Z, true)
	check(editor.status.contains("inget att ångra"), "Ctrl+Z utan historik säger till", editor.status)

	# 2. En nod: Ctrl+Z tar bort den, Ctrl+Y sätter tillbaka den.
	var p := Vector2i(-1, -1)
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and p.x < 0:
				p = Vector2i(x, y)
	check(p.x > 0, "det finns en golvruta att rita på")
	var före := _noder()
	editor.verktyg = "nod"
	editor.nod_kind = "chest"
	editor._vänster_ner(Vector2.ZERO, p)
	editor._vänster_upp()
	check(_noder() == före + 1, "kistan ställdes ut", "%d noder" % _noder())
	_tryck(KEY_Z, true)
	check(_noder() == före, "Ctrl+Z tog bort den igen", "%d noder" % _noder())
	_tryck(KEY_Y, true)
	check(_noder() == före + 1, "Ctrl+Y satte tillbaka den", "%d noder" % _noder())

	# 3. ETT drag = ETT steg: måla fem golvrutor i rad, en Ctrl+Z ska ta alla fem.
	editor._historik.clear()
	editor._framtid.clear()
	editor.verktyg = "ruta"
	editor.ruta_mark = Dungeon.WALL
	var rad: Array = []
	for y in range(1, editor.floor.h - 1):
		var i_rad: Array = []
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)):
				i_rad.append(Vector2i(x, y))
		if i_rad.size() >= 5 and rad.is_empty():
			rad = i_rad.slice(0, 5)
	check(rad.size() == 5, "det finns fem golvrutor i rad att måla över")
	if rad.size() == 5:
		editor._vänster_ner(Vector2.ZERO, rad[0])
		for i in range(1, 5):
			editor._måla_linje(rad[i - 1], rad[i])
		editor._vänster_upp()
		var väggar := 0
		for q in rad:
			if not editor.floor.is_floor_at(q):
				väggar += 1
		check(väggar == 5, "draget gjorde fem väggar", "%d av 5" % väggar)
		check(editor._historik.size() == 1, "och historiken har ETT steg för hela draget",
			"%d steg" % editor._historik.size())
		_tryck(KEY_Z, true)
		var kvar := 0
		for q in rad:
			if editor.floor.is_floor_at(q):
				kvar += 1
		check(kvar == 5, "en Ctrl+Z tog tillbaka hela draget", "%d av 5 golv igen" % kvar)

	# 4. Våningsbyte nollställer historiken: annars ångar man in förra våningens rutor här.
	editor._historik.clear()
	editor._vänster_ner(Vector2.ZERO, p)
	editor._vänster_upp()
	check(editor._historik.size() > 0, "en ändring lade en punkt")
	editor._våning(1)
	check(editor._historik.is_empty(), "våningsbytet tömde historiken")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
