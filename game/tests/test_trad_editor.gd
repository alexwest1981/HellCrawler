## Prov för trädeditorn (M95): att noderna går att flytta, att mappningen bildandel <-> pixel är
## konsistent, och att filen editorn sparar är samma fil vyn läser.
##
## Provet skriver ALDRIG i spelets data: socketfilen skickas till en user://-temp och läses tillbaka
## därifrån. Läsvägen är däremot spelets egen (TreeSockets), så ett formatfel syns här.
##
## BITE: kontrollerna jämför vad som skrevs med vad som kom tillbaka. Skriver skrivaren ingenting
## (eller skriver fel fält) faller de — provet är alltså inte grönt av misstag.
extends SceneTree

var fails := 0
var checks := 0


func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok  %s" % what)
	else:
		fails += 1
		print("  FEL %s%s" % [what, ("  — " + detail) if not detail.is_empty() else ""])


func _initialize() -> void:
	Meta.fotolage(true)                    # editorn får aldrig röra spelarens sparfil
	var scene: PackedScene = load("res://editor/trad_editor.tscn")
	check(scene != null, "trädeditorns scen går att läsa")
	if scene == null:
		quit(1)
		return
	var editor: Control = scene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame

	check(editor.view != null, "editorn ritar spelets EGEN trädvy (inte en kopia)")
	check(editor.ids.size() > 0, "alla trädnoder är med i placeringslistan", "%d st" % editor.ids.size())
	check(editor.records.size() >= editor.ids.size(),
		"varje nod har en post (även de filen inte kände)", "%d poster" % editor.records.size())

	# Mappningen är invarianten: en bildandel blir en pixel och tillbaka igen, på samma punkt.
	editor.selected = "iron_1"
	editor.view.flytta("iron_1", 0.5, 0.5)
	var punkt: Vector2 = editor.view.nod_punkt("iron_1")
	var tillbaka: Vector2 = editor.view.till_bild(punkt)
	check(absf(tillbaka.x - 0.5) < 0.01 and absf(tillbaka.y - 0.5) < 0.01,
		"bildandel -> pixel -> bildandel är samma punkt", "%s" % tillbaka)

	# Flytta genom editorns egen väg, och kontrollera att posten och vyn följer.
	editor.selected = "wick_2"
	var före: Vector2 = editor.view.nod_punkt("wick_2")
	editor.step_selected(0.05, 0.05)
	var efter: Vector2 = editor.view.nod_punkt("wick_2")
	check(efter.distance_to(före) > 1.0, "piltangenternas väg flyttar noden i vyn",
		"%.1f px" % efter.distance_to(före))
	var väntad: float = editor.view.till_bild(före).x + 0.05
	check(absf(float(editor.records["wick_2"]["x"]) - väntad) < 0.02,
		"posten och vyn flyttar tillsammans",
		"post %.4f, väntad %.4f, vyn före %.4f" % [float(editor.records["wick_2"]["x"]), väntad, editor.view.till_bild(före).x])

	# Runturen: skriv med spelets skrivare, läs med spelets läsare.
	var poster: Array = []
	for id in editor.ids:
		if editor.records.has(id):
			poster.append(editor.records[id])
	check(TreeSockets.write(poster, "user://prov_sockets.json"), "socketfilen skrivs (atomiskt)")
	var läst: Dictionary = TreeSockets.load_all("user://prov_sockets.json")
	check(läst.size() == poster.size(), "lika många poster tillbaka som skickades",
		"%d mot %d" % [läst.size(), poster.size()])
	check(läst.has("wick_2") and absf(float(läst["wick_2"]["x"]) - float(editor.records["wick_2"]["x"])) < 0.0005,
		"den flyttade nodens x överlevde skrivning och inläsning",
		"%s mot %s" % [läst.get("wick_2", {}).get("x", "saknas"), editor.records["wick_2"]["x"]])

	# Återställningen skall gå tillbaka till den mätta gissningen, inte till noll.
	if editor.records.has("iron_1") and editor.records["iron_1"].has("guess_x"):
		editor.selected = "iron_1"
		editor.reset_selected()
		check(absf(float(editor.records["iron_1"]["x"]) - float(editor.records["iron_1"]["guess_x"])) < 0.0001,
			"R lägger noden tillbaka på den mätta gissningen")

	print("=== trädeditorn: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
