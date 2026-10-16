class_name HjältVal
extends Control

## HJÄLTVALET (M138). Alex: *"Hjältarna skall man kunna välja vilken man vill använda, det är bara en
## markör i byn var man står ... det skall inte tillföra mer än lite 'Jag har valt min egen karaktär i
## spelet'-känsla."*
##
## Alltså precis så mycket: en rad med de tolv figurerna ur Alex' hjälteark (`game/images/heroes.jpeg`,
## klippta av `tools/gen_hjalte.py`). Ett klick sätter `Meta.hjalte`, och den figuren ritar både byn
## (`ui/village_view.gd`) och kartan (`ui/worldmap_view.gd`) — samma markör på båda ställena. Ingen
## meny, ingen nivå, ingen siffra.
signal bytt(id: String)

## Figuren är klippt till 48 px höjd; 44 ryms i raden under menyvalen utan att röra bottenraden.
const PX := 44.0
const LUFT := 8.0                               ## px mellan figurerna
const RAM_LUFT := 3.0                           ## hur långt utanför figuren den valda ramas in
const GULD := Color(0.969, 0.722, 0.314)        ## samma guld som menytexten (`ui/huvudmeny.gd`)
const DATA := "res://assets/ui/hjalte.json"     ## skriven av `tools/gen_hjalte.py`

var id: Array[String] = []
var namn: Array[String] = []
var bilder: Array[Texture2D] = []
var vald := 0

func _init() -> void:
	_ladda()

func _ready() -> void:
	# Klicket ska stanna här (menyns rader lyssnar också, och de ligger UNDER den här raden).
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _ladda() -> void:
	if not FileAccess.file_exists(DATA):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (parsed is Dictionary):
		return
	for p: Variant in (parsed as Dictionary).get("hjalte", []):
		if not (p is Dictionary):
			continue
		var väg := "res://assets/ui/%s" % str((p as Dictionary).get("bild", ""))
		if not ResourceLoader.exists(väg):
			continue
		id.append(str((p as Dictionary).get("id", "")))
		namn.append(str((p as Dictionary).get("namn", "")))
		bilder.append(load(väg) as Texture2D)
	vald = maxi(0, id.find(Meta.hjalte))

## Figurens ruta i raden, centrerad i radens egen bredd, så raden står mitt i fönstret oavsett hur
## många hjältar arket gav.
func ruta(i: int) -> Rect2:
	var bredd := (PX + LUFT) * float(bilder.size()) - LUFT
	var x0 := (size.x - bredd) * 0.5
	return Rect2(x0 + float(i) * (PX + LUFT), (size.y - PX) * 0.5, PX, PX)

func _draw() -> void:
	for i in bilder.size():
		var r := ruta(i)
		draw_texture_rect(bilder[i], r, false)
		if i == vald:
			draw_rect(r.grow(RAM_LUFT), GULD, false, 2.0)

## Välj hjälte nummer `i`. Valet ligger i `Meta` (alltså i sparfilen) och sänds vidare, så skalet kan
## spara det.
func välj(i: int) -> void:
	if i < 0 or i >= id.size() or i == vald:
		return
	vald = i
	Meta.hjalte = id[i]
	bytt.emit(id[i])
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (e as InputEventMouseButton).position
		for i in bilder.size():
			if ruta(i).has_point(p):
				välj(i)
				accept_event()
				return

## Antalet hjältar i raden (arket ger tolv; provet mäter mot filen).
func antal() -> int:
	return bilder.size()
