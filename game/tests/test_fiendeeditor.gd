## Provet för fiendeeditorn och fiendens retuschering (M82).
##
## Provet mäter tre saker som är lätta att tappa och svåra att se:
##   1. att ett streck i editorn BITER på bilden (pixeln blir genomskinlig / får färgen),
##   2. att en pixel man INTE rört står kvar (annars suddar receptet hela figuren),
##   3. att receptet går att spara och läsa tillbaka med samma innehåll (editorn och spelet delar filen).
##
## Det skriver ALDRIG i spelets data: allt hamnar i `user://retuschprov/`. Editorns EGNA funktioner
## anropas — aldrig en kopia av dem.
##
## KÖRNING: godot --headless --path game --script res://tests/test_fiendeeditor.gd
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


func _initialize() -> void:
	print("— fiendeeditorn: sudda, måla, spara —")
	var scen: PackedScene = load("res://editor/fiendeeditor.tscn")
	check(scen != null, "scenen finns")
	if scen == null:
		quit(1)
		return
	var editor: Control = scen.instantiate()
	root.add_child(editor)
	await process_frame
	check(editor.filer.size() > 0, "editorn hittar fienderna i assets/enemies",
		"%d st" % editor.filer.size())
	check(editor.bild != null, "fiendens duk är laddad")
	if editor.bild == null:
		quit(1)
		return
	# 1. ETT STRECK BITER. Pixeln måste vara EN DEL AV FIGUREN: duken har transparenta hörn, och en
	# suddad pixel i ett hörn ser likadan ut före och efter ("pixeln är tillbaka" var grön av misstag
	# så länge bilden lästes i ett packat format, där alfan lästes som 1).
	var px := Vector2i(-1, -1)
	var id: String = editor.id
	for y in range(20, 100):
		for x in range(20, 100):
			if editor.bild.get_pixel(x, y).a > 0.5:
				px = Vector2i(x, y)
				break
		if px.x >= 0:
			break
	check(px.x >= 0, "provet hittar en täckande pixel i figuren", str(px))
	if px.x < 0:
		quit(1)
		return
	var orörd: Color = editor.bild.get_pixel(40, 40)
	editor.växla_sudda(px.x, px.y)
	check(editor.bild.get_pixel(px.x, px.y).a == 0.0, "en suddad pixel blir genomskinlig på bilden",
		str(editor.bild.get_pixel(px.x, px.y)))
	check(editor._antal("sudda") == 1, "suddet hamnade i receptet", str(editor._antal("sudda")))
	check(editor.bild.get_pixel(40, 40) == orörd, "en pixel man inte rört står kvar")

	# 2. ÅNGRA
	editor.växla_sudda(px.x, px.y)
	check(editor._antal("sudda") == 0, "samma pixel en gång till tar tillbaka suddet")
	check(editor.bild.get_pixel(px.x, px.y).a > 0.0, "pixeln är tillbaka på bilden")

	# 2b. MUSEN (M83): Alex: *"vänsterklick lägga till, höger ta bort"*. Vänsterklicket är IDEMPOTENT
	# (ett svep över samma pixel två gånger får inte blinka tillbaka), högerklicket tar bort allt man
	# lagt på pixeln.
	editor.klicka(px.x, px.y, false)
	editor.klicka(px.x, px.y, false)
	check(editor._antal("sudda") == 1, "två vänsterklick på samma pixel ger ETT sudd",
		str(editor._antal("sudda")))
	check(editor.bild.get_pixel(px.x, px.y).a == 0.0, "vänsterklick suddar pixeln")
	editor.klicka(px.x, px.y, true)
	check(editor._antal("sudda") == 0, "högerklick tar bort suddet")
	check(editor.bild.get_pixel(px.x, px.y).a > 0.0, "pixeln är tillbaka efter högerklick")
	# Högerklicket tar bort målningen också, inte bara suddet.
	editor.måla(px.x, px.y, Color8(10, 200, 20))
	check(editor._antal("måla") == 1, "målningen ligger i receptet")
	editor.klicka(px.x, px.y, true)
	check(editor._antal("måla") == 0, "högerklick tar bort målningen med")
	# Mappningen mellan skärmpunkt och konstpixel är det enda som står mellan musen och receptet.
	# Provet mäter INVARIANTEN (punkten ska hamna inuti den pixel mappningen pekar ut) i stället för
	# en fast koordinat: fönsterstorleken skiljer sig mellan en headless-körning och spelet.
	editor._skala_om()
	var mål := Vector2i(30, 40)
	var skärmpunkt: Vector2 = editor._ruta(editor.ANKA) + editor._ruta(Vector2(mål) * editor.ZOOM) + Vector2(1, 1)
	var träff: Vector2i = editor._duk_pixel(skärmpunkt)
	var pixel_ruta := Rect2(editor._ruta(editor.ANKA) + editor._ruta(Vector2(träff) * editor.ZOOM),
		editor._ruta(Vector2(editor.ZOOM, editor.ZOOM)))
	check(pixel_ruta.has_point(skärmpunkt), "skärmpunkten hamnar i den pixel mappningen pekar ut",
		"%s i %s" % [str(skärmpunkt), str(pixel_ruta)])
	check(editor._duk_pixel(Vector2(1, 1)) == Vector2i(-1, -1), "en punkt utanför duken ger ingen pixel")

	# 3. MÅLA
	var röd := Color8(230, 26, 26)
	editor.måla(7, 8, röd)
	check(editor.bild.get_pixel(7, 8).is_equal_approx(röd), "den målade pixeln får färgen",
		str(editor.bild.get_pixel(7, 8)))
	check(editor._antal("måla") == 1, "målningen hamnade i receptet")

	# 4. SUDDA OCH MÅLA SAMMA PIXEL: den ena vinner, aldrig båda
	editor.växla_sudda(7, 8)
	check(editor._antal("måla") == 0 and editor._antal("sudda") == 1,
		"en suddad pixel tas bort ur målningarna (ingen dubbelbokning)",
		"måla %d, sudda %d" % [editor._antal("måla"), editor._antal("sudda")])

	# 5. SPARA OCH LÄS TILLBAKA
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://retuschprov"))
	var fil := "user://retuschprov/retuschering.json"
	var fel: String = editor.spara(fil)
	check(fel.is_empty(), "receptet sparades", fel)
	var tillbaka := Retusch.läs(fil)
	check(tillbaka.has(id), "id:t finns i den lästa filen", id)
	check(Retusch.tillämpa(editor.bild.duplicate(), tillbaka, id) == 1,
		"receptet läses tillbaka och biter på en färsk bild")

	# 6. RENSA
	editor.rensa(id)
	check(editor._antal("sudda") == 0 and editor._antal("måla") == 0, "rensa tar bort hela retuschen")
	check(not editor.recept.has(id), "och id:t är borta ur receptet")

	print("kontroller: %d, fel: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
