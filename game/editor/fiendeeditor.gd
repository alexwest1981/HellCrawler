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
const FÖRSTORARE := 7                   ## sidan på förstorarens fönster, i logiska pixlar
## PANELENS LAYOUT i BASE-pixlar (M120: ytan ritar i den logiska 480x270-ytan, och `_ruta` skalar
## den till fönstret). Fillistan är den nya hyresgästen och de andra raderna har flyttat ihop för
## att ge den plats — förstoraren stod mitt i panelen och en lista UNDER den går inte att klicka i.
const PANEL_BREDD := 214.0              ## panelens egen bredd (480 - PANEL_X - marginal)
const LISTA_TOP := 118.0                ## fillistans överkant
const LISTA_BOTTEN := 200.0             ## dess underkant (rullarens fönster)
const LISTA_BREDD := 100.0              ## en cells bredd (så ett artnamn ryms)
const LISTA_RAD := 16.0                 ## en cells höjd
const FÖRSTORARE_ANKA := Vector2(PANEL_X, 206.0)
const FÖRSTORARE_ZOOM := 6.0
const TANGENT_ANKA := Vector2(PANEL_X + 52.0, 212.0)   ## tangentlistan, till höger om förstoraren

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
var _senaste := Vector2i(-1, -1)        ## förra pixeln i samma drag — strecket ritas HÄRIFRÅN (M120)

var _skala := 1.0
var _font: Font
var _font_storlek := 11
## FILLISTAN (M120). Alex: *"en lista över alla filer så man enkelt väljer vilken man redigerar"* —
## `,`/`.` bläddrar men säger inget om VILKA arter som finns. Rutnätet visar dem alla.
var rutnät: GridContainer = null
var rull: ScrollContainer = null
var _knappar := {}                      ## art -> knapp, så valet följer med i listan
var _knapp_vald := ""


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
	_bygg_lista()
	resized.connect(_om_skala)
	if args.has("shot"):
		if args.has("musprov"):
			# BILDEN AV STRECKET (prov): samma händelser en hand ger, in i samma `_gui_input`, och
			# sedan fotograferas ytan. Siffran står i `test_editor_mus.gd`; bilden visar linjen.
			musprov()
			await get_tree().process_frame
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
	_markera_lista()


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


## ETT STRECK MELLAN TVÅ MUSPUNKTER (M120). Alex: *"kunna rita med musen"* — och det som gör en
## frihandsritning till ett streck och inte till en rad prickar är INTERPOLERINGEN. En snabb dragning
## ger få mushändelser (mätt: en dragning över duken gav 3-9 händelser, alltså 3-9 pixlar), så ritar
## man bara den pixel händelsen pekar på blir linjen full av gluggar. Bresenham mellan förra och nya
## pixeln ritar varje pixel däremellan, och `klicka` är IDEMPOTENT, så ett streck som korsar sig själv
## inte blinkar bort sitt eget arbete.
##
## Räknaren svarar på hur många NYA pixlar draget gav (startpixeln ritades av förra händelsen).
func rita_till(från: Vector2i, till: Vector2i, höger: bool) -> int:
	if från.x < 0 or till.x < 0:
		return 0
	var ritade := 0
	var dx := absi(till.x - från.x)
	var dy := -absi(till.y - från.y)
	var steg_x := 1 if från.x < till.x else -1
	var steg_y := 1 if från.y < till.y else -1
	var fel := dx + dy
	var p := från
	while true:
		if p != från and klicka(p.x, p.y, höger):
			ritade += 1
		if p == till:
			break
		var dubbelt := 2 * fel
		if dubbelt >= dy:
			fel += dy
			p.x += steg_x
		if dubbelt <= dx:
			fel += dx
			p.y += steg_y
	return ritade


## Skärmpunkten i mitten av en konstpixel — den omvända vägen av `_duk_pixel`. Provet bygger sina
## mushändelser ur den (då mäts mappningen i båda riktningarna i stället för mot en fast koordinat,
## som skiljer sig mellan en huvudlös körning och spelet).
func duk_skarm(p: Vector2i) -> Vector2:
	return _ruta(ANKA) + _ruta(Vector2(p) * ZOOM) + _ruta(Vector2(ZOOM, ZOOM)) * 0.5


## ETT DRAG MED MUSEN, TILL BILDEN (prov). Bygger SAMMA händelser en hand ger — tryck, EN rörelse,
## släpp — och kör dem genom `_gui_input`, så bilden visar den väg koden faktiskt tar. Utan
## interpoleringen hade bilden visat två pixlar och 59 gluggar (mätt i `test_editor_mus.gd`).
func musprov() -> void:
	verktyg = "sudda"
	_musslag(Vector2i(24, 44), 1, true)
	_musslag(Vector2i(96, 78), 2, false)
	_musslag(Vector2i(96, 78), 1, false)


## 1 = vänsterknappen ned, 2 = rörelse, 3 = vänsterknappen upp.
func _musslag(p: Vector2i, slag: int, tryckt: bool) -> void:
	if slag == 2:
		var m := InputEventMouseMotion.new()
		m.position = duk_skarm(p)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		_gui_input(m)
		return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = tryckt
	e.position = duk_skarm(p)
	_gui_input(e)


## FILLISTAN (M120): alla redigerbara tillgångar (assets/enemies) i ett rutnät man klickar i.
##
## RADBRYTNINGEN OCH RULLAREN ÄR DE DELADE — `Kortvaggar` (ui/kortvaggar.gd), samma regel som
## värdshusets hjältar och butikens varor: helst 3 per rad, 4 bara när den fyller raden, och kapad av
## vad panelen RYMS. Ingen kopia i editorn: en kopia glider ifrån butikerna utan att någon märker det.
func _bygg_lista() -> void:
	if filer.is_empty() or rutnät != null:
		return
	rutnät = GridContainer.new()
	rutnät.add_theme_constant_override("h_separation", int(Kortvaggar.MELLANRUM))
	rutnät.add_theme_constant_override("v_separation", int(Kortvaggar.MELLANRUM))
	for namn in filer:
		var b := Button.new()
		b.text = namn
		b.toggle_mode = true
		# KNAPPAR I EN PANEL MÅSTE SLÄPPA TANGENTBORDET (FOCUS_NONE), annars tar de Enter och
		# piltangenterna och `_unhandled_input` slutar få dem — `,`/`.` och `S` hade dött tyst.
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", maxi(8, _fs(9)))
		b.pressed.connect(_valj_från_lista.bind(namn))
		rutnät.add_child(b)
		_knappar[namn] = b
	rull = Kortvaggar.rullare(rutnät, _fs(LISTA_BOTTEN - LISTA_TOP))
	add_child(rull)
	_lista_om()


## Listan mäts i RIKTIGA pixlar (det är widgets, inte vår egen logiska yta), och skalas om när
## fönstret ändras — en cell på 100 px ser annars ut att höra till en annan skala än texten bredvid.
func _lista_om() -> void:
	if rull == null or rutnät == null:
		return
	var storlek := Vector2(_fs(LISTA_BREDD), _fs(LISTA_RAD))
	rutnät.columns = Kortvaggar.kolumner(filer.size(), storlek.x, _fs(PANEL_BREDD))
	for namn in _knappar:
		(_knappar[namn] as Button).custom_minimum_size = storlek
	var fönster := Vector2(_fs(PANEL_BREDD), _fs(LISTA_BOTTEN - LISTA_TOP))
	rull.custom_minimum_size = fönster
	rull.position = _ruta(Vector2(PANEL_X, LISTA_TOP))
	rull.size = fönster
	_markera_lista()


## Valet märks i listan. Jämför mot förra valet: `_ladda` körs en gång per ritad pixel i ett streck,
## och att sätta om alla knappar per pixel vore arbete utan verkan.
func _markera_lista() -> void:
	if _knappar.is_empty() or _knapp_vald == id:
		return
	_knapp_vald = id
	for namn in _knappar:
		(_knappar[namn] as Button).set_pressed_no_signal(namn == id)


## ETT VAL UR LISTAN: samma väg som `,`/`.` tar (`index` + `_ladda`), så listan och tangentbordet
## inte kan komma ur fas med varandra.
func _valj_från_lista(namn: String) -> void:
	if not filer.has(namn):
		return
	index = filer.find(namn)
	_ladda(namn)
	status = "valde %s ur listan" % namn
	_lista_visa_val()
	queue_redraw()


func _lista_visa_val() -> void:
	await Kortvaggar.visa(rull, _knappar.get(id), get_tree())


func _om_skala() -> void:
	_skala_om()
	_lista_om()
	queue_redraw()


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
			_senaste = Vector2i(-1, -1)
			return
		var p := _duk_pixel(mb.position)
		if p.x < 0:
			return
		_drar = true
		_drar_höger = mb.button_index == MOUSE_BUTTON_RIGHT
		klicka(p.x, p.y, _drar_höger)
		_senaste = p
		queue_redraw()
		return
	if e is InputEventMouseMotion and _drar:
		var p := _duk_pixel((e as InputEventMouseMotion).position)
		if p.x < 0:
			# UTANFÖR duken: behåll `_senaste`, så strecket fortsätter från den pixel musen lämnade
			# i stället för att hoppa över allt som hände utanför.
			return
		var start := _senaste
		if start.x < 0:
			start = p
		rita_till(start, p, _drar_höger)      # ett STÄLL, inte en hop prickar — se rita_till
		_senaste = p
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


## En längd i BASE-pixlar som ett heltal i RIKTIGA pixlar — widgetar (listans celler) mäts i riktiga
## pixlar, medan panelen ritas i den logiska ytan. Samma tal ska styra båda, annars glider de isär.
func _fs(bas: float) -> int:
	return maxi(1, int(round(bas * _skala)))


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
	draw_rect(Rect2(mark - Vector2(1, 1), ruta_px + Vector2(2, 2)), Color(1, 1, 0.9, 0.9), false, 1.0)
	# FÖRSTORAREN (M82) — FLYTTAD (M120). Den stod mitt i panelen och fillistan tog den platsen; en
	# lista man inte kan klicka i för att en förstorare ligger över den är ingen lista. Nu står
	# förstoraren nere till vänster i panelen med tangentlistan till höger om sig.
	var f_anka := FÖRSTORARE_ANKA
	var f_zoom := FÖRSTORARE_ZOOM
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
	# Panelen. Rubriken är slagen ihop till TVÅ rader (M120): fillistan behöver den tredje.
	_text(Vector2(PANEL_X, 26), "FIENDE %d/%d · suddat %d · målat %d"
		% [index + 1, filer.size(), _antal("sudda"), _antal("måla")], Color(0.95, 0.85, 0.6))
	_text(Vector2(PANEL_X, 40), "%s · markör %d, %d · %s" % [id.to_upper(), markör.x, markör.y, verktyg])
	_text(Vector2(PANEL_X, 60), "pensel %s" % vald_färg.to_html(false))
	draw_rect(Rect2(_ruta(Vector2(PANEL_X + 96, 52)), _ruta(Vector2(12, 12))), vald_färg)
	draw_rect(Rect2(_ruta(Vector2(PANEL_X + 96, 52)), _ruta(Vector2(12, 12))), Color(0.6, 0.6, 0.65), false, 1.0)
	_text(Vector2(PANEL_X, 108), "FILER (%d) — klicka för att välja" % filer.size(), Color(0.9, 0.85, 0.6))
	# Tangentlistan: kompakt, till höger om förstoraren — ytan är 270 px hög och åtta rader à 14 px
	# gick utanför nederkanten när listan tog plats (mätt på bild).
	var rader := [
		"vänsterklick ritar · höger tar bort",
		"← → ↑ ↓ markör · space sudda",
		"T verktyg · C hämta färg · X rensa",
		", . art · S spara · M meny",
		"Q avsluta",
	]
	for n in rader.size():
		_text(Vector2(TANGENT_ANKA.x, TANGENT_ANKA.y + n * 9), rader[n], Color(0.7, 0.72, 0.78))
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
