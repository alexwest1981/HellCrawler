## Editorns YTA (M146): att kartan får den plats som blir över, att panelerna ryms i fönstret, att
## texten går att läsa och att musen träffar den ruta pekaren står på.
##
## Den gamla ytan ritade panelen som textrader i 480x270 och skalade upp den. En palett på 30 knappar,
## en egenskapspanel och en objektlista fick inte plats där, så ytan är nu riktig widgetlayout i
## fönstrets pixlar — och då är det HÄR invarianten mäts: kartan ska äga merparten av ytan, och
## mappningen skärmpunkt -> ruta ska vara en rundtur.
##
##   tools/ett_prov.sh tests/test_editor_yta.gd
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
	# Fönstret är 480x270 i projektet; provet sätter en riktig storlek på en yta som ligger i hörnet,
	# så mätningen handlar om layouten och inte om var scenen råkade hamna.
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	editor.position = Vector2.ZERO
	await process_frame
	await process_frame
	check(editor.floor != null, "editorn har en våning att lägga ut")
	var duk: Control = editor.duk
	check(duk != null, "kartan är en egen yta i layouten")

	# Fönstret spelet startar i och en fullskärm: kartan ska äga merparten, panelerna rymmas, och en
	# ruta på en 34x34-våning ska gå att se (10 px är gränsen där en nod ännu läses som en nod).
	for fall in [Vector2(1280, 720), Vector2(1920, 1080)]:
		editor.size = fall
		editor.position = Vector2.ZERO       # grow BOTH växer kring mitten: håll ytan i hörnet
		await process_frame
		await process_frame
		var karta: Rect2 = duk.get_global_rect()
		var vad := "%dx%d: karta %.0fx%.0f px, ruta %.1f px" % [fall.x, fall.y, karta.size.x, karta.size.y,
			editor.cell]
		check(karta.size.x >= fall.x * 0.45, "kartan äger minst 45 %% av bredden", vad)
		check(karta.size.y >= fall.y * 0.55, "kartan äger minst 55 %% av höjden", vad)
		check(editor.cell >= 10.0, "en ruta är minst 10 px (34x34-våning)", vad)
		check(karta.position.x >= 240.0, "paletten ligger till vänster om kartan", vad)
		check(karta.end.x <= fall.x - 290.0, "egenskapspanelen ligger till höger om kartan", vad)
		check(int(editor.theme.default_font_size) >= 11, "texten går att läsa",
			"%d px" % int(editor.theme.default_font_size))

	# Mappningen skärmpunkt -> ruta -> punkt: varje ruta ska träffa SIG SJÄLV. Mätt som invariant,
	# inte som en fast koordinat — fönsterstorleken skiljer sig mellan körningar.
	editor.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	var bom := 0
	for y in editor.floor.h:
		for x in editor.floor.w:
			var p := Vector2i(x, y)
			if editor._ruta_vid(editor._ruta_rect(p).get_center()) != p:
				bom += 1
	check(bom == 0, "varje ruta mappar till sig själv", "%d bom av %d" % [bom, editor.floor.w * editor.floor.h])

	# Zoom kring pekaren: punkten under musen ska stå still (annars glider kartan under handen).
	var pos: Vector2 = duk.size * 0.5
	var före: float = editor.cell
	var värld: Vector2 = (pos - editor.anka) / före
	editor._zooma(pos, 1.5)
	var efter: float = editor.cell
	var värld_efter: Vector2 = (pos - editor.anka) / efter
	check(efter > före, "zoomen gör rutan större", "%.1f -> %.1f px" % [före, efter])
	check(värld.distance_to(värld_efter) < 0.05, "punkten under pekaren står still",
		"%.3f rutor" % värld.distance_to(värld_efter))
	editor._rama_in()
	var cell_efter: float = editor.cell
	check(absf(cell_efter - före) < 0.01, "F ramar in till inpassningen igen", "%.1f px" % cell_efter)

	print("  %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
