## Rekvisitan i karteditorn (M150): att paletten hittar arterna ur mappen, att ett klick ställer ut
## det man valt, att en ruta bara bär EN sak, och att kartfilen får fältet i BÅDA riktningarna.
##
## Fältet är nytt i formatet, och den fällan är känd: skrivs det i `to_dict` men läses inte i
## `from_dict` ser filen rätt ut och spelet ignorerar den. Provet skriver, läser TILLBAKA och kräver
## att art och ruta finns kvar.
##
##   tools/ett_prov.sh tests/test_editor_rekvisita.gd
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


func _tom() -> void:
	editor.floor = MapIo.blank("stage_01", 0, 17, 17)
	editor.floor.nodes = []
	editor.floor.start = Vector2i(-1, -1)
	editor.floor.boss_pos = Vector2i(-1, -1)
	editor.floor.shovel_pos = Vector2i(-1, -1)
	editor.floor.rekvisita = []
	editor.vald = []
	editor.verktyg = "valj"
	editor._layout_duk()


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	editor.size = Vector2(1280, 720)
	editor.position = Vector2.ZERO
	await process_frame
	await process_frame

	# 1. Paletten: arterna ur mappen, nodbilderna undantagna.
	check(editor.rekvisita_arter.size() > 50, "paletten hittar rekvisitan i assets/props",
		"%d arter" % editor.rekvisita_arter.size())
	for art in ["småsten", "trälåda", "bur", "kandelaber"]:
		check(editor.rekvisita_arter.has(art), "arten %s är valbar" % art)
	for nodbild in ["chest", "shovel", "boss"]:
		check(not editor.rekvisita_arter.has(nodbild), "%s är ingen rekvisit (det är en nod)" % nodbild)

	# 2. Ett klick ställer ut det valda.
	_tom()
	editor.verktyg = "rekvisita"
	editor.rekvisit_art = "trälåda"
	editor._måla(Vector2i(5, 5))
	check(editor.floor.rekvisita.size() == 1, "klicket ställde ut en rekvisit",
		"%d st" % editor.floor.rekvisita.size())
	var r: Dictionary = MapIo.rekvisita_vid(editor.floor, Vector2i(5, 5))
	check(str(r.get("art", "")) == "trälåda", "det är arten man valde", str(r.get("art", "")))

	# 3. En ruta bär EN sak: nästa klick byter art i stället för att lägga till.
	editor.rekvisit_art = "bur"
	editor._måla(Vector2i(5, 5))
	check(editor.floor.rekvisita.size() == 1, "andra klicket lade inte till en till",
		"%d st" % editor.floor.rekvisita.size())
	check(str(MapIo.rekvisita_vid(editor.floor, Vector2i(5, 5)).get("art", "")) == "bur",
		"arten byttes på rutan")

	# 4. Högerklick suddar rekvisitan.
	editor._höger(Vector2i(5, 5))
	check(editor.floor.rekvisita.is_empty(), "högerklick tog bort den")

	# 5. I en vägg vägras den — med besked.
	editor.floor.tiles[5][6] = Dungeon.WALL
	editor.rekvisit_art = "trälåda"
	editor._måla(Vector2i(6, 5))
	check(editor.floor.rekvisita.is_empty(), "ingen rekvisit i en vägg")
	check(editor.status.contains("golv"), "statusraden säger varför", editor.status)

	# 6. Kontrollen fångar en trasig post (inläst fil kan bära vad som helst).
	_tom()
	editor.floor.tiles[5][6] = Dungeon.WALL
	editor.floor.rekvisita = [{"art": "trälåda", "pos": Vector2i(6, 5)},
		{"art": "finns_inte", "pos": Vector2i(2, 2)}]
	var fel := MapIo.validate(editor.floor)
	var sa_vagg := false
	var sa_okand := false
	for f in fel:
		if f.contains("vägg"):
			sa_vagg = true
		if f.contains("okänd rekvisita"):
			sa_okand = true
	check(sa_vagg, "kontrollen säger att rekvisitan står i en vägg", str(fel))
	check(sa_okand, "kontrollen säger att arten inte finns", str(fel))

	# 7. Filen: skriv, läs tillbaka, jämför art och ruta. Ingen skrivning till spelets data.
	_tom()
	editor.verktyg = "rekvisita"       # _tom nollställer verktyget: utan raden målar provet ingenting
	editor.rekvisit_art = "småsten"
	editor._måla(Vector2i(3, 4))
	editor._måla(Vector2i(9, 12))
	check(editor.floor.rekvisita.size() == 2, "två rekvisiter utställda",
		"%d st" % editor.floor.rekvisita.size())
	var d: Dictionary = MapIo.to_dict(editor.floor)
	check(d.has("rekvisita"), "kartan skriver fältet rekvisita")
	var tillbaka := MapIo.from_dict(d, "stage_01", 0)
	check(tillbaka.rekvisita.size() == 2, "två poster kom tillbaka",
		"%d st" % tillbaka.rekvisita.size())
	var kvar := {}
	for rr in tillbaka.rekvisita:
		kvar[Vector2i(rr.get("pos", Vector2i(-1, -1)))] = str(rr.get("art", ""))
	check(str(kvar.get(Vector2i(3, 4), "")) == "småsten", "arten och rutan överlevde rundturen",
		str(kvar))

	# 8. Räknaren i panelen ser dem (den siffra man tittar på när man ritar).
	editor._uppdatera()
	var nämner := false
	for c in editor.insp_box.get_children():
		if c is Label and (c as Label).text.contains("rekvisita 2"):
			nämner = true
	check(nämner, "egenskapspanelen räknar rekvisitan")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
