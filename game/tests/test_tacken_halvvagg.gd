## Täcken och halvväggar (M166). Alex: *"hur gör jag om jag vill tala om för golvet att det skall på
## vissa delar täckas av gräs t ex? Eller att en viss yta skall ha en halvvägg, som lämnar spelaren en vy
## över helvetets öppna vidder?"*
##
##   tools/ett_prov.sh tests/test_tacken_halvvagg.gd
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


func _init() -> void:
	var f := MapIo.blank("stage_01", 0, 11, 7)
	var golv := Vector2i(3, 3)

	# 1. TÄCKENA: bara på golv, bara kända arter.
	check(MapIo.sätt_täcke(f, "gräs", golv).is_empty(), "gräs går att lägga på golv")
	check(MapIo.täcke_vid(f, golv) == "gräs", "och ligger på rutan")
	check(MapIo.sätt_täcke(f, "gräs", Vector2i(0, 0)).contains("golv"), "en vägg vägrar täcket")
	check(MapIo.sätt_täcke(f, "lava", golv).contains("okänt"), "en okänd art vägras",
		MapIo.sätt_täcke(f, "lava", golv))
	check(MapIo.sätt_täcke(f, "mossa", golv).is_empty() and MapIo.täcke_vid(f, golv) == "mossa",
		"ett nytt täcke på samma ruta ersätter (en per ruta)")
	check(MapIo.ta_bort_täcke(f, golv) and MapIo.täcke_vid(f, golv).is_empty(),
		"och det går att ta bort")

	# 2. FILEN: täckena måste skrivas OCH läsas.
	MapIo.sätt_täcke(f, "gräs", golv)
	var d := MapIo.to_dict(f)
	check(d.has("täcken"), "täckena skrivs till filen")
	var tillbaka := MapIo.from_dict(d, "stage_01", 0)
	check(MapIo.täcke_vid(tillbaka, golv) == "gräs", "och läses tillbaka på samma ruta")

	# 3. HALVVÄGGEN: eget tecken i filen, och den stänger gången.
	f.tiles[4][5] = Dungeon.HALVVÄGG
	var d2 := MapIo.to_dict(f)
	check(str(d2["tiles"][4])[5] == MapIo.HALV_CH, "halvväggen skrivs som '%s'" % MapIo.HALV_CH,
		str(d2["tiles"][4]))
	var t2 := MapIo.from_dict(d2, "stage_01", 0)
	check(t2.tiles[4][5] == Dungeon.HALVVÄGG, "och läses tillbaka som halvvägg")
	check(not t2.is_floor_at(Vector2i(5, 4)), "halvväggen är inte golv — man kan inte gå in i den")
	var ex := Explore.new(t2)
	ex.pos = Vector2i(4, 4)
	ex.facing = Explore.EAST
	check(ex.forward() == "vaggen", "och gången stoppas av den", ex.forward())

	# 4. EDITORN: knappen, målningen, högerklick och 3D-figuren.
	var editor = load("res://editor/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	var g: Array = []
	for y in range(1, editor.floor.h - 1):
		for x in range(1, editor.floor.w - 1):
			if editor.floor.is_floor_at(Vector2i(x, y)) and g.size() < 4:
				g.append(Vector2i(x, y))
	editor._sätt_verktyg("ruta", "halvvägg")
	check(editor.ruta_mark == Dungeon.HALVVÄGG, "H väljer halvvägg")
	editor._måla(g[0])
	check(editor.floor.tiles[g[0].y][g[0].x] == Dungeon.HALVVÄGG, "klicket gör rutan till halvvägg")

	editor._sätt_verktyg("täcke", "gräs")
	editor._måla(g[1])
	check(MapIo.täcke_vid(editor.floor, g[1]) == "gräs", "täckespenseln lägger gräs")
	editor._bygg_3d()
	var har_täcke := false
	var har_halv := false
	for barn in editor.vy3d_värld.get_children():
		if barn.material_override != null and barn.material_override.albedo_texture != null:
			har_täcke = true
	check(har_täcke, "gräset syns som en liggande figur i 3D-vyn")
	for barn in editor.vy3d_värld.get_children():
		if barn is MeshInstance3D and barn.mesh is BoxMesh:
			if is_equal_approx((barn.mesh as BoxMesh).size.y, 0.62):
				har_halv = true
	check(har_halv, "och halvväggen ritas låg i 3D-vyn (0,62 m)")

	editor._höger(g[0])
	check(editor.floor.tiles[g[0].y][g[0].x] != Dungeon.HALVVÄGG, "högerklick tar bort halvväggen")
	editor._höger(g[1])
	check(MapIo.täcke_vid(editor.floor, g[1]).is_empty(), "och täcket")

	# 5. PENSELN: storlek, form och sudd. Referenseditorn har brushSize 1–9 och kvadrat/rund; Alex vill
	#    måla ett helt område i stället för att klicka ruta för ruta.
	var mitt: Vector2i = g[2]
	editor._sätt_verktyg("täcke", "mossa")
	editor._sätt_pensel(3)
	check(editor.pensel_storlek == 3, "penseln går att ställa till 3")
	editor._måla(mitt)
	var målade := 0
	var golv_i_fältet := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q2: Vector2i = mitt + Vector2i(dx, dy)
			if not editor.floor.is_floor_at(q2):
				continue
			golv_i_fältet += 1
			if MapIo.täcke_vid(editor.floor, q2) == "mossa":
				målade += 1
	check(målade == golv_i_fältet and målade > 3,
		"en 3×3-pensel målar alla golvrutor i fältet (väggar hoppas över)",
		"%d av %d" % [målade, golv_i_fältet])
	editor._växla_penselform()
	check(editor.pensel_form == "rund", "formen växlar till rund")
	# En golvruta en bit bort, så den runda penselns hörn garanterat ligger över golv och inte vägg.
	var annan := Vector2i(-1, -1)
	for y in range(2, editor.floor.h - 3):
		for x in range(2, editor.floor.w - 3):
			if annan.x >= 0:
				continue
			var q3 := Vector2i(x, y)
			var alla_golv := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not editor.floor.is_floor_at(q3 + Vector2i(dx, dy)):
						alla_golv = false
			if alla_golv:
				annan = q3
	check(annan.x >= 0, "hittade ett 3×3-golvparti att måla på")
	editor._måla(annan)
	check(MapIo.täcke_vid(editor.floor, annan) == "mossa", "mitten målas")
	check(MapIo.täcke_vid(editor.floor, annan + Vector2i(1, 1)).is_empty(),
		"men hörnet gör det inte — den runda penseln rundar av")
	for i in 12:
		editor._sätt_pensel(editor.pensel_storlek + 1)
	check(editor.pensel_storlek == 9, "storleken stannar vid 9")
	for i in 12:
		editor._sätt_pensel(editor.pensel_storlek - 1)
	check(editor.pensel_storlek == 1, "och vid 1")
	editor._växla_penselform()
	editor._sätt_pensel(3)
	editor._höger(mitt)
	check(MapIo.täcke_vid(editor.floor, mitt).is_empty()
		and MapIo.täcke_vid(editor.floor, mitt + Vector2i(1, 1)).is_empty(),
		"högerklick suddar hela penselytan")
	editor._sätt_pensel(1)
	var strider_före := 0
	for n in editor.floor.nodes:
		if n.kind == "encounter":
			strider_före += 1
	editor._sätt_verktyg("fiende", "bone_wretch")
	editor._måla(annan)
	var strider_efter := 0
	for n in editor.floor.nodes:
		if n.kind == "encounter":
			strider_efter += 1
	check(strider_efter <= strider_före + 1,
		"penseln rör inte fiender — en fiende hör till en ruta",
		"%d -> %d" % [strider_före, strider_efter])

	# 6. TOM RUTA (M170). Alex: *"skall man kunna plocka bort både golv och vägg, så man ser skybox
	#    utanför halvväggen"*. Tom = varken golv eller vägg, och inget får stå kvar på rutan.
	var ft2 := MapIo.blank("stage_01", 0, 9, 7)
	ft2.tiles[3][4] = Dungeon.TOM
	var dt := MapIo.to_dict(ft2)
	check(str(dt["tiles"][3])[4] == MapIo.TOM_CH, "tom ruta skrivs som mellanslag",
		"[%s]" % str(dt["tiles"][3]))
	var tillbaka2 := MapIo.from_dict(dt, "stage_01", 0)
	check(tillbaka2.tiles[3][4] == Dungeon.TOM, "och läses tillbaka som tom")
	check(not tillbaka2.is_floor_at(Vector2i(4, 3)), "en tom ruta är inte golv")
	check(tillbaka2.tiles[3][4] != Dungeon.WALL, "och inte vägg — det är hela skillnaden mot berg")

	editor._sätt_verktyg("ruta", "tom")
	check(editor.ruta_mark == Dungeon.TOM, "T väljer tom ruta")
	var tomruta: Vector2i = g[3]
	MapIo.sätt_täcke(editor.floor, "gräs", tomruta)
	MapIo.sätt_rekvisita(editor.floor, "trälåda", tomruta)
	editor._måla(tomruta)
	check(editor.floor.tiles[tomruta.y][tomruta.x] == Dungeon.TOM, "klicket gör rutan tom")
	check(MapIo.täcke_vid(editor.floor, tomruta).is_empty(), "täcket togs bort från hålet")
	check(MapIo.rekvisita_vid(editor.floor, tomruta).is_empty(), "och rekvisitan")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
