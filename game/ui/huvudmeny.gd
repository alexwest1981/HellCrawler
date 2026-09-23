## Startmenyn (M39): splashbilden med menyvalen, som i referensen Alex gav.
##
## Alex: *"Här har du en intro och en splashscreen. Lägg in startmenyn för 'Nytt spel' osv enligt sista
## bilden."* Bilden visar logotypen (som ligger i splashbilden), valen i mitten, det valda valet
## markerat med en BRINNANDE DÖDSKALLE till vänster i stället för en ram eller en pil, och längst ned
## version + copyright. Antalet rader ägs av anroparen (`_meny_rubriker` i main.gd) — raderna skapas på
## begäran, så en ny rad (Spara spel) behöver bara läggas i listan där.
##
## Menyn ligger i FÖNSTRETS yta (`_runt`), inte i 480x270-vyn: texten ska vara skarp, och menyn ska
## ritas över hela skärmen. Den ritar ingenting själv — den bygger Labels och en TextureRect, så allt
## går att mäta (position, storlek, färg) i stället för att bara synas på en bild.
class_name Huvudmeny
extends Control

signal valt(index: int)          ## spelaren bekräftade ett val (index i anroparens rubriklista)

const VAL := ["nytt", "spara", "ladda", "alternativ", "avsluta"]   ## ui.meny.<namn> i i18n
const TEXT_PX := 26
const RAD_AVSTÅND := 40.0        ## px mellan raderna
const TOPP := 352.0              ## första radens y i 720 px högt fönster (mätt mot referensen)
const MARKOR_SKALA := 2
const MARKOR_LUFT := 14.0        ## px mellan märket och radens text
const GULD := Color(0.969, 0.722, 0.314)      ## referensens guldfärg, #F7B850
const DIM := Color(0.36, 0.30, 0.22)          ## en rad som inte går att välja
const SKUGGA := Color(0, 0, 0, 0.75)          ## textens skugga: guld på färgrik bakgrund behöver den

var splash: TextureRect
var rader: Array[Label] = []
var markör: TextureRect
var botten: Label

var valt_index := 0
var spärrade := {}               ## index -> orsak: raden går inte att välja, och VARFÖR står i botten
var bekräfta_igen := false       ## en spärrad rad som bekräftas visar orsaken i bottenraden

static func bygg() -> Huvudmeny:
	var m := Huvudmeny.new()
	m.name = "huvudmeny"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_PASS      # raderna tar sina egna klick
	m._bygg()
	return m

func _bygg() -> void:
	splash = TextureRect.new()
	splash.name = "splash"
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/ui/splash.jpg"
	if ResourceLoader.exists(path):
		splash.texture = load(path)
	add_child(splash)

	for i in VAL.size():
		_skapa_rad(i)

	markör = TextureRect.new()
	markör.name = "markor"
	markör.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	markör.stretch_mode = TextureRect.STRETCH_KEEP
	markör.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	markör.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mpath := "res://assets/ui/markor.png"
	if ResourceLoader.exists(mpath):
		markör.texture = load(mpath)
	add_child(markör)

	botten = Label.new()
	botten.name = "botten"
	botten.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	botten.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botten.add_theme_font_size_override("font_size", 15)
	botten.add_theme_color_override("font_color", Color(0.88, 0.86, 0.80))
	botten.add_theme_color_override("font_shadow_color", SKUGGA)
	botten.add_theme_constant_override("shadow_offset_x", 1)
	botten.add_theme_constant_override("shadow_offset_y", 1)
	add_child(botten)

## Sätter texterna. `rubriker` är fyra färdiga strängar (översatta av anroparen), `spärrade` är de
## index som inte går att välja med orsaken som ska stå i bottenraden, och `bottentext` är version +
## copyright (plus en eventuell orsak när en spärrad rad väljs — den läggs till av `_visa_orsak`).
## En rad. Raden byggdes tidigare bara för VAL:s fyra nycklar, så en femte rubrik försvann TYST — en
## rad som finns i listan men inte i menyn är samma klass av fel som en knapp som inte gör något.
## Nu skapas rader på begäran, och VEM SOM HELST som lägger en rubrik i listan får en rad.
func _skapa_rad(i: int) -> Label:
	var l := Label.new()
	l.name = "val_%s" % (VAL[i] if i < VAL.size() else str(i))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_STOP          # raden ska kunna klickas, som i referensen
	l.add_theme_font_size_override("font_size", TEXT_PX)
	l.add_theme_color_override("font_shadow_color", SKUGGA)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_entered.connect(_peka.bind(i))
	l.gui_input.connect(_klick.bind(i))
	add_child(l)
	rader.append(l)
	return l

func visa(rubriker: Array, spärrade_rader: Dictionary, bottentext: String) -> void:
	spärrade = spärrade_rader
	while rader.size() < rubriker.size():
		_skapa_rad(rader.size())
	botten.text = bottentext
	for i in rader.size():
		rader[i].text = str(rubriker[i]) if i < rubriker.size() else ""
	valt_index = clampi(valt_index, 0, rader.size() - 1)
	if spärrade.has(valt_index) and spärrade.size() < rader.size():
		valt_index = _närmaste_valbara(valt_index, 1)
	_placera()

func _närmaste_valbara(från: int, steg: int) -> int:
	for i in rader.size():
		var k := wrapi(från + steg * (i + 1), 0, rader.size())
		if not spärrade.has(k):
			return k
	return från

func _text_bredd(i: int) -> float:
	var f := rader[i].get_theme_font("font")
	var st := rader[i].get_theme_font_size("font_size")
	if f == null or rader[i].text.is_empty():
		return 0.0
	return f.get_string_size(rader[i].text, HORIZONTAL_ALIGNMENT_LEFT, -1, st).x

## Raderna centreras kring fönstrets mitt med textens EGEN bredd (inte en fast ruta): märket ska sitta
## tätt intill texten, och en fast ruta hade lämnat ett glapp som beror på översättningens längd.
func _placera() -> void:
	var f := size
	if f.x <= 0.0:
		f = get_viewport_rect().size
	# Raderna i överkanten av splashens fria yta (logotypen ligger i bilden, ovanför): blocket centreras
	# kring TOPP så att en längre översättning inte flyttar det nedre paret utanför skärmen.
	var topp := TOPP + (f.y - 720.0) * 0.5
	for i in rader.size():
		var b := _text_bredd(i)
		rader[i].size = Vector2(b + 4.0, float(TEXT_PX) + 8.0)
		rader[i].position = Vector2(roundf(f.x * 0.5 - b * 0.5 - 2.0), roundf(topp + RAD_AVSTÅND * i))
		if spärrade.has(i):
			rader[i].add_theme_color_override("font_color", DIM)
		else:
			rader[i].add_theme_color_override("font_color", GULD if i == valt_index else Color(0.80, 0.62, 0.34))
	var mw := 23.0 * MARKOR_SKALA
	var mh := 21.0 * MARKOR_SKALA
	markör.size = Vector2(mw, mh)
	markör.position = Vector2(roundf(rader[valt_index].position.x - mw - MARKOR_LUFT),
		roundf(rader[valt_index].position.y + (rader[valt_index].size.y - mh) * 0.5))
	markör.visible = not spärrade.has(valt_index) or spärrade.size() == rader.size()
	botten.size = Vector2(f.x, 44.0)
	botten.position = Vector2(0.0, roundf(f.y - 52.0))

func välj(i: int) -> void:
	valt_index = wrapi(i, 0, rader.size())
	_placera()

func flytta(steg: int) -> void:
	if rader.is_empty():
		return
	var k := valt_index
	for _i in rader.size():
		k = wrapi(k + steg, 0, rader.size())
		if not spärrade.has(k):
			break
	valt_index = k
	_placera()

## Raden som är vald. Anropas av tangenten (Enter) och av klicket — samma väg för båda.
func bekräfta() -> void:
	if spärrade.has(valt_index):
		_visa_orsak()
		return
	valt.emit(valt_index)

## En spärrad rad tiger inte: varför den inte går att välja står i bottenraden.
func _visa_orsak() -> void:
	bekräfta_igen = true
	botten.text = "%s\n%s" % [botten.text.split("\n")[0], str(spärrade[valt_index])]

func _peka(i: int) -> void:
	if spärrade.has(i):
		return
	if i != valt_index:
		valt_index = i
		_placera()

func _klick(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		valt_index = i
		_placera()
		bekräfta()
