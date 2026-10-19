## Lägg till area (M160). Alex: *"Om jag kommit till utkanten skall jag kunna klicka på en knapp för att
## lägga till mer area att bygga på, för om man går hela vägen ut mot en kant, så blir det bara svart."*
##
##   tools/ett_prov.sh tests/test_editor_utoka.gd
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

	var w0: int = editor.floor.w
	var h0: int = editor.floor.h
	check(w0 > 5 and h0 > 5, "utgångsvåningen har en storlek", "%d×%d" % [w0, h0])

	# Knappen finns där man letar: i RUTOR-sektionen, inte bara som tangent.
	var knapp := ""
	for b in editor.find_children("*", "Button", true, false):
		if str(b.text).contains("Lägg till area"):
			knapp = str(b.text)
	check(not knapp.is_empty(), "knappen 'Lägg till area' finns i paletten", knapp)

	# 1. Grunden: det man ritat ligger kvar, och de nya rutorna är berg.
	var gammal: Array = []
	for y in range(h0):
		var rad: Array = []
		for x in range(w0):
			rad.append(editor.floor.tiles[y][x])
		gammal.append(rad)
	var noder0: int = editor.floor.nodes.size()
	var rekvisiter0: int = editor.floor.rekvisita.size()
	editor._sd_bredd.value = w0 + 8
	editor._sd_höjd.value = h0 + 3
	editor._utöka_karta()
	check(editor.floor.w == w0 + 8 and editor.floor.h == h0 + 3, "våningen växte",
		"%d×%d" % [editor.floor.w, editor.floor.h])
	check(editor.floor.tiles.size() == h0 + 3, "det finns rader för hela höjden")
	check(editor.floor.tiles[0].size() == w0 + 8, "och kolumner för hela bredden")

	var lika := 0
	for y in range(h0):
		for x in range(w0):
			if editor.floor.tiles[y][x] == gammal[y][x]:
				lika += 1
	check(lika == w0 * h0, "de gamla rutorna är orörda", "%d av %d" % [lika, w0 * h0])

	var nytt_golv := 0
	for y in range(editor.floor.h):
		for x in range(editor.floor.w):
			if (x >= w0 or y >= h0) and editor.floor.is_floor_at(Vector2i(x, y)):
				nytt_golv += 1
	check(nytt_golv == 0, "ingen ny ruta blev golv av misstag (man målar själv)", "%d" % nytt_golv)
	check(editor.floor.nodes.size() == noder0, "noderna är kvar", "%d" % editor.floor.nodes.size())
	check(editor.floor.rekvisita.size() == rekvisiter0, "rekvisitan är kvar")

	# 2. Våningen går fortfarande att spela och att rita i.
	check(MapIo.validate(editor.floor).is_empty(), "våningen är fortfarande giltig",
		str(MapIo.validate(editor.floor)))

	# 3. Att måla i den nya arean fungerar (det är hela poängen).
	var ny := Vector2i(w0 + 2, h0 + 1)
	editor.verktyg = "ruta"
	editor.ruta_mark = Dungeon.FLOOR
	editor._vänster_ner(Vector2.ZERO, ny)
	editor._vänster_upp()
	check(editor.floor.is_floor_at(ny), "en ruta i den nya arean går att måla golv på")

	# 4. Krympning vägras — den skulle kasta bort det man ritat.
	var fel := MapIo.utöka(editor.floor, w0, h0)
	check(fel.contains("krympning"), "krympning vägras med besked", fel)
	check(editor.floor.w == w0 + 8, "och storleken står kvar")

	# 5. Ångra: utökningen är ett steg som går tillbaka.
	editor._historik.clear()
	editor._sd_bredd.value = editor.floor.w + 4
	editor._sd_höjd.value = editor.floor.h
	editor._utöka_karta()
	var bred: int = editor.floor.w
	editor._stega(editor._historik, editor._framtid)
	check(editor.floor.w == bred - 4, "Ctrl+Z tar tillbaka utökningen", "%d -> %d" % [bred, editor.floor.w])

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
