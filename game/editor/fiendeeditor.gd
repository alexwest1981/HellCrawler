## Fiendeeditorn (M82). Alex: *"Där står texten ABYSSAL nere på fienden ... samt att armar svävar i
## luften. Kan vi göra så att det finns editor för fienden med, så man manuellt kan editera vad som är
## kropp, vad som inte skall synas osv? Mer eller mindre kunna rita om dem om det behövs."*
##
##   tools/fiendeeditor.sh [fiende]        (standard: första fienden i bokstavsordning)
##
## Ytan ritar fienden i spelets EGEN duk (120x120 logiska pixlar) uppskalad så man ser pixlarna, med
## markören som ett kors och en förstorare bredvid. `space` suddar pixeln (och tar tillbaka den),
## `C` hämtar färgen under markören och `enter` målar med den. Retuschen skrivs till
## `data/enemies/retuschering.json` — ett RECEPT, inte en PNG (konsten ägs av `tools/`, se
## `hellcrawler-editors`), och spelet lägger receptet på bilden när fienden laddas (se `core/retusch.gd`).
##
## Retuschen gäller ALLA sex rutor: pixlarna är dukens, och en skarv eller en lös klo sitter på samma
## ställe i varje pose. Rutorna ritas inte här — arket är 720x120 och ruta 1 är den stilla posen.
extends Control

const BASE := Vector2(480.0, 270.0)
const DUK := 120.0                      ## fiendens logiska duk (px)
const ZOOM := 2.0                       ## skärmpixlar per logisk pixel i ritytan
const ANKA := Vector2(8.0, 26.0)        ## ritytans övre vänstra hörn i BASE-pixlar
const PANEL_X := ANKA.x + DUK * ZOOM + 10.0
const FÖRSTORARE := 9                   ## sidan på förstorarens fönster, i logiska pixlar

var filer: Array[String] = []           ## fiendens id:n, ur assets/enemies (arkets ägare är sanningen)
var index := 0
var id := ""
var bild: Image = null                  ## fiendens ruta 1, MED receptet pålagt (det man ser är det man får)
var recept: Dictionary = {}
var markör := Vector2i(60, 60)
var vald_färg := Color(0.75, 0.6, 0.5)
var verktyg := "sudda"                  ## "sudda" eller "måla": vad VÄNSTERklicket gör (T byter)
var status := ""
var _drar := false                      ## musknappen är nere: dragning målar flera pixlar
var _drar_höger := false

var _skala := 1.0
var _font: Font
var _font_storlek := 11


func _ready() -> void:
	_skala_om()
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_font = ThemeDB.fallback_font
	for f in DirAccess.get_files_at("res://assets/enemies"):
		# "_"-filerna är inte fiender: `_kontaktkarta.png` är generatorns granskningsark.
		if f.ends_with(".png") and not f.ends_with("_mask.png") and not f.begins_with("_"):
			filer.append(f.get_basename())
	filer.sort()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and filer.has(args[0]):
		index = filer.find(args[0])
	recept = Retusch.läs()
	if filer.is_empty():
		status = "inga fiender i assets/enemies"
		return
	_ladda(filer[index])
	if args.has("shot"):
		await _skott()


func _ladda(nytt_id: String) -> void:
	id = nytt_id
	var textur: Texture2D = load("res://assets/enemies/%s.png" % id)
	bild = textur.get_image()
	# Bara ruta 1 (120x120 av arket): rutan är vad spelet ritar som "stilla".
	bild = bild.get_region(Rect2i(0, 0, int(DUK), int(DUK)))
	# Bilden ur en importerad PNG kan vara packad — då blir ImageTexture vit och förstoraren visar
	# ändå rätt (den läser pixlar, inte texturen). Mätt: ritytan blev 99 % vit innan detta.
	if bild.get_format() != Image.FORMAT_RGBA8:
		bild.convert(Image.FORMAT_RGBA8)
	var antal := Retusch.tillämpa(bild, recept, id)
	status = "%d pixlar ur receptet" % antal if antal > 0 else "inget recept för %s" % id


func _antal(nyckel: String) -> int:
	var r = recept.get(id, {})
	return (r.get(nyckel, []) as Array).size() if typeof(r) == TYPE_DICTIONARY else 0


## Ett sudd (IDEMPOTENT): pixeln är suddad, hur många gånger man än drar över den. Musen går hit —
## en växling hade blinkat av och an när ett svep gick över samma pixel två gånger.
func sudda_av(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= int(DUK) or y >= int(DUK):
		return false
	var r: Dictionary = recept.get(id, {"sudda": [], "måla": []})
	var sudda: Array = r.get("sudda", [])
	if not sudda.has([x, y]):
		sudda.append([x, y])
	# En suddad pixel kan inte vara målad samtidigt — annars vinner den ena tyst.
	var måla: Array = r.get("måla", [])
	for i in range(måla.size() - 1, -1, -1):
		if måla[i][0] == x and måla[i][1] == y:
			måla.remove_at(i)
	r["måla"] = måla
	r["sudda"] = sudda
	recept[id] = r
	_ladda(id)
	status = "suddade (%d, %d)" % [x, y]
	return true


## Tar bort BÅDE suddet och målningen för pixeln: den är som den kom ur arket igen. Det här är
## högerklicket — "ta bort" vad man än har lagt där.
func återställ(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= int(DUK) or y >= int(DUK):
		return false
	var r: Dictionary = recept.get(id, {"sudda": [], "måla": []})
	var ändrad := false
	var sudda: Array = r.get("sudda", [])
	if sudda.has([x, y]):
		sudda.erase([x, y])
		r["sudda"] = sudda
		ändrad = true
	var måla: Array = r.get("måla", [])
	for i in range(måla.size() - 1, -1, -1):
		if måla[i][0] == x and måla[i][1] == y:
			måla.remove_at(i)
			r["måla"] = måla
			ändrad = true
	if ändrad:
		recept[id] = r
		_ladda(id)
		status = "tillbaka som i arket (%d, %d)" % [x, y]
	return true


func _är_suddad(x: int, y: int) -> bool:
	var r = recept.get(id, {})
	if typeof(r) != TYPE_DICTIONARY:
		return false
	return (r.get("sudda", []) as Array).has([x, y])


## Tangentbordet VÄXLAR (space): samma pixel två gånger tar tillbaka. Musen är idempotent — båda går
## genom samma två funktioner, så en regel finns bara på ett ställe.
func växla_sudda(x: int, y: int) -> bool:
	if _är_suddad(x, y):
		return återställ(x, y)
	return sudda_av(x, y)


## Vad ett musklick (eller en dragning) gör på pixeln: vänster = verktyget, höger = ta bort.
func klicka(x: int, y: int, höger: bool) -> bool:
	if x < 0 or y < 0 or x >= int(DUK) or y >= int(DUK):
		return false
	markör = Vector2i(x, y)
	if höger:
		return återställ(x, y)
	return måla(x, y, vald_färg) if verktyg == "måla" else sudda_av(x, y)


func måla(x: int, y: int, färg: Color) -> bool:
	if x < 0 or y < 0 or x >= int(DUK) or y >= int(DUK):
		return false
	var r: Dictionary = recept.get(id, {"sudda": [], "måla": []})
	var måla_lista: Array = r.get("måla", [])
	for i in range(måla_lista.size() - 1, -1, -1):
		if måla_lista[i][0] == x and måla_lista[i][1] == y:
			måla_lista.remove_at(i)
	måla_lista.append([x, y, färg.to_html(false)])
	# Målar man över en suddad pixel är den målad, inte suddad.
	var sudda: Array = r.get("sudda", [])
	sudda.erase([x, y])
	r["måla"] = måla_lista
	r["sudda"] = sudda
	recept[id] = r
	_ladda(id)
	status = "målade (%d, %d) %s" % [x, y, färg.to_html(false)]
	return true


func rensa(id_att_rensa: String) -> void:
	recept.erase(id_att_rensa)
	_ladda(id)


func spara(till: String = Retusch.FIL) -> String:
	var fel := Retusch.skriv(recept, till)
	status = "sparat: %s" % till if fel.is_empty() else fel
	return fel


## Skärmpunkt -> konstpixel i duken (-1, -1 om utanför). Räknas i skärmpixlar: rutan är ZOOM
## skärmpixlar per konstpixel, och skalningen mot fönstret ligger i `_skala`.
func _duk_pixel(p: Vector2) -> Vector2i:
	_skala_om()
	var steg := _skala * ZOOM
	if steg <= 0.0:
		return Vector2i(-1, -1)
	var lokal := (p - _ruta(ANKA)) / steg
	var px := Vector2i(int(floor(lokal.x)), int(floor(lokal.y)))
	if px.x < 0 or px.y < 0 or px.x >= int(DUK) or px.y >= int(DUK):
		return Vector2i(-1, -1)
	return px


## MUSEN (M83). Alex: *"vänsterklick lägga till, höger ta bort"*. Vänster = verktyget på pixeln,
## höger = ta bort det man lagt där, och en nedtryckt knapp fortsätter rita när musen dras — samma
## funktion varje gång, som är idempotent, så ett svep suddar ett streck utan att blinka.
func _gui_input(e: InputEvent) -> void:
	if bild == null:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		if not mb.pressed:
			_drar = false
			return
		var p := _duk_pixel(mb.position)
		if p.x < 0:
			return
		_drar = true
		_drar_höger = mb.button_index == MOUSE_BUTTON_RIGHT
		klicka(p.x, p.y, _drar_höger)
		queue_redraw()
		return
	if e is InputEventMouseMotion and _drar:
		var p := _duk_pixel((e as InputEventMouseMotion).position)
		if p.x >= 0:
			klicka(p.x, p.y, _drar_höger)
			queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if bild == null or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = (e as InputEventKey).keycode
	match k:
		KEY_LEFT: markör.x = maxi(0, markör.x - 1)
		KEY_RIGHT: markör.x = mini(int(DUK) - 1, markör.x + 1)
		KEY_UP: markör.y = maxi(0, markör.y - 1)
		KEY_DOWN: markör.y = mini(int(DUK) - 1, markör.y + 1)
		KEY_SPACE:
			växla_sudda(markör.x, markör.y)
		KEY_T:
			verktyg = "måla" if verktyg == "sudda" else "sudda"
			status = "verktyget är %s — vänsterklick %s" % [verktyg, "målar" if verktyg == "måla" else "suddar"]
		KEY_C:
			var c := bild.get_pixel(markör.x, markör.y)
			if c.a > 0.0:
				vald_färg = c
				status = "hämtade färgen %s" % c.to_html(false)
			else:
				status = "pixeln är tom — inget att hämta"
		KEY_ENTER, KEY_KP_ENTER:
			måla(markör.x, markör.y, vald_färg)
		KEY_COMMA:
			index = (index - 1 + filer.size()) % filer.size()
			_ladda(filer[index])
		KEY_PERIOD:
			index = (index + 1) % filer.size()
			_ladda(filer[index])
		KEY_X:
			rensa(id)
			status = "rensade retuschen för %s" % id
		KEY_S:
			spara()
		KEY_M:
			get_tree().change_scene_to_file("res://main.tscn")
		KEY_Q, KEY_ESCAPE:
			get_tree().quit()
	queue_redraw()


func _skala_om() -> void:
	_skala = minf(size.x / BASE.x, size.y / BASE.y)
	if _skala <= 0.0:
		_skala = 1.0


func _ruta(v: Vector2) -> Vector2:
	return v * _skala


func _text(v: Vector2, t: String, färg := Color(0.85, 0.87, 0.9)) -> void:
	draw_string(_font, _ruta(v), t, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(_font_storlek * _skala)), färg)


func _draw() -> void:
	_skala_om()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.09))
	if bild == null:
		_text(Vector2(10, 20), status)
		return
	var duk_ruta := Rect2(_ruta(ANKA), _ruta(Vector2(DUK, DUK) * ZOOM))
	# Schackbrädet visar vad som är tomt: en suddad pixel är ett hål i figuren, inte en mörk pixel.
	var ruta_px := _ruta(Vector2(ZOOM, ZOOM))          # en konstpixel på skärmen
	var schack_px := _ruta(Vector2(2.0 * ZOOM, 2.0 * ZOOM))   # schackbrädets ruta: 2x2 konstpixlar
	var i := 0
	while i * 2 < int(DUK):
		var j := 0
		while j * 2 < int(DUK):
			var f := Color(0.16, 0.16, 0.19) if (i + j) % 2 == 0 else Color(0.12, 0.12, 0.15)
			# Schackbrädet räknas i KONSTPIXLAR och ritas i skärmpixlar: rutan är 2x2 konstpixlar,
			# alltså 2*ZOOM skärmpixlar — tar man 2 px där täcker mönstret bara en fjärdedel
			# (mätt: 99 504 av 389 276 px var bräde, resten bakgrund).
			draw_rect(Rect2(duk_ruta.position + _ruta(Vector2(i, j) * 2.0 * ZOOM), schack_px), f)
			j += 1
		i += 1
	# FIGUREN PIXEL FÖR PIXEL (M82). Här stod `draw_texture_rect_region` (och före det
	# `draw_texture_rect`): BÅDA ritade en helvit ruta i den här scenen — mätt med ett skott där
	# bakgrunden gjordes röd (den blev röd, rutan förblev vit), och samma vita ruta kom med Godots
	# EGEN importerade textur. Pixlarna är rätt (förstoraren läser dem), så det är texturritningen i
	# en Control utan kamera som faller — och en pixeleditor vill ändå rita sina pixlar.
	# ponytail: 120x120 `draw_rect` per ommålning (14400 anrop). Ytan målas om på tangenttryck, inte
	# per bildruta; blir den slö drar man ner ZOOM eller ritar bara den synliga delen.
	var px_stege := _ruta(Vector2(ZOOM, ZOOM))
	for y in int(DUK):
		for x in int(DUK):
			var c := bild.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			draw_rect(Rect2(duk_ruta.position + _ruta(Vector2(x, y) * ZOOM), px_stege), c)
	# Suddade pixlar markeras ovanpå bilden: hålet syns, men man ska också se VAR man var.
	for punkt in (recept.get(id, {}).get("sudda", []) as Array):
		var p := duk_ruta.position + _ruta(Vector2(float(punkt[0]), float(punkt[1])) * ZOOM)
		draw_rect(Rect2(p, ruta_px), Color(0.85, 0.25, 0.25, 0.45))
	var mark := duk_ruta.position + _ruta(Vector2(markör) * ZOOM)
	draw_rect(Rect2(mark - Vector2(1, 1), ruta_px + Vector2(2, 2)), Color(1, 1, 1, 0.9), false, 1.0)
	# Förstoraren: fönstret runt markören i 7x, så en pixel går att se innan man suddar den.
	# LAYOUTEN ÄR MÄTT PÅ BILD: låg förstoraren på 150 täckte den sex rader av tangentlistan.
	var f_anka := Vector2(PANEL_X, 104.0)
	var f_zoom := 7.0
	var halv := FÖRSTORARE / 2
	draw_rect(Rect2(_ruta(f_anka) - Vector2(2, 2), _ruta(Vector2(FÖRSTORARE, FÖRSTORARE) * f_zoom) + Vector2(4, 4)),
		Color(0.2, 0.2, 0.24))
	for y in FÖRSTORARE:
		for x in FÖRSTORARE:
			var sx := markör.x - halv + x
			var sy := markör.y - halv + y
			var c := Color(0.1, 0.1, 0.12)
			if sx >= 0 and sy >= 0 and sx < int(DUK) and sy < int(DUK):
				c = bild.get_pixel(sx, sy)
				if c.a <= 0.0:
					c = Color(0.16, 0.16, 0.19) if (x + y) % 2 == 0 else Color(0.12, 0.12, 0.15)
			draw_rect(Rect2(_ruta(f_anka + Vector2(x, y) * f_zoom), _ruta(Vector2(f_zoom, f_zoom))), c)
	draw_rect(Rect2(_ruta(f_anka + Vector2(halv, halv) * f_zoom), _ruta(Vector2(f_zoom, f_zoom))),
		Color(1, 1, 1, 0.85), false, 1.0)
	# Panelen
	_text(Vector2(PANEL_X, 26), "FIENDE %d/%d" % [index + 1, filer.size()], Color(0.95, 0.85, 0.6))
	_text(Vector2(PANEL_X, 44), id.to_upper())
	_text(Vector2(PANEL_X, 62), "markör %d, %d · %s" % [markör.x, markör.y, verktyg])
	_text(Vector2(PANEL_X, 80), "suddat %d · målat %d" % [_antal("sudda"), _antal("måla")])
	draw_rect(Rect2(_ruta(Vector2(PANEL_X, 88)), _ruta(Vector2(12, 12))), vald_färg)
	draw_rect(Rect2(_ruta(Vector2(PANEL_X, 88)), _ruta(Vector2(12, 12))), Color(0.6, 0.6, 0.65), false, 1.0)
	_text(Vector2(PANEL_X + 18, 98), "pensel %s" % vald_färg.to_html(false))
	# Tangentlistan ligger UNDER förstoraren (mätt på bild: överlapp annars) och de två sista raderna
	# är slagna ihop — ytan är 270 px hög och nio rader à 14 px gick utanför nederkanten.
	var rader := [
		"← → ↑ ↓   flytta markören",
		"vänsterklick  sudda/måla",
		"högerklick    ta bort",
		"C  hämta färg · space  sudda",
		"T  verktyg: sudda ⇄ måla",
		", .   förra / nästa fiende",
		"X  rensa · S  spara",
		"M  meny · Q  avsluta",
	]
	for n in rader.size():
		_text(Vector2(PANEL_X, 176 + n * 11), rader[n], Color(0.7, 0.72, 0.78))
	_text(Vector2(ANKA.x, 18), "%s — retuschen gäller alla sex rutor" % id, Color(0.6, 0.62, 0.68))
	_text(Vector2(ANKA.x, 262), status, Color(0.85, 0.9, 0.7))


## Fotograferar ytan och avslutar — samma väg som de andra editorerna granskas på bild.
func _skott() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://fiendeeditor.png")
	print("fiendeeditor: bild i user://fiendeeditor.png")
	get_tree().quit()
