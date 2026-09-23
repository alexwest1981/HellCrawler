## Editorns YTA: att skalningen mot fönstret gör ritytan stor nog att se och texten läsbar, och att
## panelen ryms innanför fönstret i alla storlekar.
##
## Utan `_skala()` ritade editorn sin gamla 480x270-yta rakt av i fönstret (projektet kör
## `window/stretch/mode="disabled"` och ritar i riktiga pixlar): hela ytan hamnade i övre vänstra
## hörnet med 8 px text — mätt 425x269 px = 12 % av ett 1280x720-fönster. Det är felet Alex såg
## ("baneditorn är alldeles för liten, går knappt att se något").
##
##   godot --headless --script res://tests/test_editor_yta.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _init() -> void:
	var editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)          # _ready kör: banor och bestiarium läses, våningen laddas
	await process_frame
	check(editor.floor != null, "editorn har en våning att lägga ut")

	# Fönstret spelet startar i, en fullskärm, och ett litet fönster. Panelen ska rymmas i ALLA, och i
	# de storlekar man faktiskt jobbar i ska texten gå att läsa. I ett 640x360-fönster ÄR 330 px panel
	# hela höjden, så texten kan inte bli mycket större än 8 px — det är aritmetik, inte en bugg.
	for fall in [[Vector2(1280, 720), 14], [Vector2(1920, 1080), 14], [Vector2(640, 360), 8]]:
		var storlek: Vector2 = fall[0]
		var minsta_text: int = fall[1]
		editor.size = storlek
		editor._skala()             # editorns EGEN funktion, inte en kopia av den
		var cell: float = editor.cell
		var s: float = editor.s
		var raster: float = cell * float(editor.floor.w)
		var text_px: int = editor._fs(8)
		var vad: String = "%dx%d: ruta %.1f px, text %d px, panel till x %.0f y %.0f" % [
			storlek.x, storlek.y, cell, text_px,
			editor.panel_x + editor.PANEL_BREDD * s, editor.PANEL_HÖJD * s]
		check(cell > 13.0, "rutan är större än den gamla fasta 13 px", vad)
		check(text_px >= minsta_text, "paneltexten går att läsa (minst %d px)" % minsta_text, vad)
		check(editor.origin.x + raster <= editor.panel_x, "rutnätet ritar inte in i panelen", vad)
		check(editor.panel_x + editor.PANEL_BREDD * s <= storlek.x + 1.0, "panelen ryms i sidled", vad)
		check(editor.PANEL_HÖJD * s <= storlek.y + 1.0, "panelens sista rad ligger över fönsterkanten", vad)

	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
