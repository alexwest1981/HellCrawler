## Dörrar i karteditorn (M161): paletten, klicket, 3D-vyn och ångra.
##
##   tools/ett_prov.sh tests/test_editor_dorrar.gd
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


func _golv(n: int) -> Array:
	var ut: Array = []
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and ut.size() < n:
				ut.append(Vector2i(x, y))
	return ut


func _init() -> void:
	editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.floor.dörrar.clear()
	editor._historik.clear()
	editor._framtid.clear()

	# 1. Paletten har de tre typerna.
	var knappar := []
	for b in editor.find_children("*", "Button", true, false):
		if str(b.text) in MapIo.DÖRRAR:
			knappar.append(str(b.text))
	check(knappar.size() == MapIo.DÖRRAR.size(), "paletten har en knapp per dörrtyp",
		"%s" % str(knappar))

	# 2. Klicket ställer dörren på rutan, och 3D-vyn får en platta.
	var golv := _golv(3)
	check(golv.size() == 3, "det finns golvrutor")
	editor._sätt_verktyg("dörr", "trä")
	editor._måla(golv[0])
	check(editor.floor.dörrar.size() == 1, "trädörren står på rutan",
		"%d dörr(ar)" % editor.floor.dörrar.size())
	check(str(editor.floor.dörrar[0]["typ"]) == "trä", "med rätt typ")
	editor._sätt_verktyg("dörr", "galler")
	editor._måla(golv[1])
	check(editor.floor.dörrar.size() == 2, "en gallerdörr också (%d)" % editor.floor.dörrar.size())

	var figurer: int = editor.vy3d_värld.get_child_count()
	editor.vy3d_sen = 0.0
	editor._bygg_3d()
	check(editor.vy3d_värld.get_child_count() == figurer + 2, "båda syns i 3D-vyn",
		"%d -> %d" % [figurer, editor.vy3d_värld.get_child_count()])

	# 3. Två dörrar på samma ruta går inte, och beskedet säger varför.
	editor._måla(golv[0])
	check(editor.floor.dörrar.size() == 2, "en dörr på en upptagen ruta läggs inte till")
	check(editor.status.contains("öppnas av"), "klicket på en dörr binder om den i stället", editor.status)

	# 4. Högerklick tar bort dörren (före material och vägg).
	editor._höger(golv[0])
	check(editor.floor.dörrar.size() == 1, "högerklick tog bort dörren",
		"%d kvar" % editor.floor.dörrar.size())

	# 5. Ångra: en utställd dörr är ett steg.
	editor._historik.clear()
	editor._sätt_verktyg("dörr", "metall")
	editor._vänster_ner(Vector2.ZERO, golv[2])
	editor._vänster_upp()
	var med: int = editor.floor.dörrar.size()
	editor._stega(editor._historik, editor._framtid)
	check(editor.floor.dörrar.size() == med - 1, "Ctrl+Z tog bort den igen",
		"%d -> %d" % [med, editor.floor.dörrar.size()])

	# 6. NAMN OCH BINDNING (M163): spaken får ett namn, dörren ett eget, och ett klick på dörren
	#    binder den till nästa spak/nyckel.
	var g := _golv(6)
	editor.floor.dörrar.clear()
	editor.floor.nodes = editor.floor.nodes.filter(func(n): return n.kind in ["start", "boss", "shovel"])
	editor._sätt_verktyg("nod", "spak")
	editor._måla(g[3])
	editor._sätt_verktyg("nod", "nyckel")
	editor._måla(g[4])
	var spak := ""
	var nyckel := ""
	for n in editor.floor.nodes:
		if n.kind == "spak":
			spak = str(n.kod)
		elif n.kind == "nyckel":
			nyckel = str(n.kod)
	check(spak == "spak 1", "spaken fick namnet 'spak 1'", spak)
	check(nyckel == "nyckel 1", "nyckeln fick namnet 'nyckel 1'", nyckel)
	check(editor._lösningar().size() == 2, "båda går att binda till",
		str(editor._lösningar()))

	editor._sätt_verktyg("dörr", "metall")
	editor._måla(g[5])
	var d0: Dictionary = MapIo.dörr_vid(editor.floor, g[5])
	check(str(d0.get("kod", "")) == "", "dörren är obunden när den sätts ut")
	check(str(d0.get("namn", "")) == "dörr 1", "och heter 'dörr 1'", str(d0.get("namn", "")))

	editor._måla(g[5])
	check(str(MapIo.dörr_vid(editor.floor, g[5]).get("kod", "")) == spak,
		"ett klick på dörren band den till spaken", str(MapIo.dörr_vid(editor.floor, g[5])))
	check(editor.status.contains(spak), "och statusraden säger vem som styr den", editor.status)
	editor._måla(g[5])
	check(str(MapIo.dörr_vid(editor.floor, g[5]).get("kod", "")) == nyckel,
		"nästa klick flyttade bindningen till nyckeln")
	editor._skift = true
	editor._måla(g[5])
	editor._skift = false
	check(str(MapIo.dörr_vid(editor.floor, g[5]).get("kod", "")) == spak,
		"Skift gick bakåt igen")

	# 7. Filen: dörren överlever en tur genom JSON.
	var d := MapIo.to_dict(editor.floor)
	var tillbaka := MapIo.from_dict(d, editor.floor.stage_id, editor.floor.index)
	check(tillbaka.dörrar.size() == editor.floor.dörrar.size(), "dörrarna följer med filen",
		"%d" % tillbaka.dörrar.size())

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
