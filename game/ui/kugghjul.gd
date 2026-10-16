class_name Kugghjul
extends Control

## KUGGHJULET (M139): en liten knapp uppe till höger som öppnar ALTERNATIV-panelen. Alex: *"eller om vi
## fixar en settingsikon uppe till höger på skärmen, som man kommer åt vart som helst efter startmenyn,
## att man kan välja karaktär där"*.
##
## Panelen är spelets EGEN (språk, CRT, musik) och hjältvalet ligger i den, så en enda knapp räcker —
## ingen ny meny, ingen ny skärm. Den ritas för hand (åtta tänder runt en ring): det finns ingen ikon i
## `assets/`, och en pixelbild hade behövt en egen fil för något som är tolv rader kod.
signal klick

const PX := 34.0
const MARGINAL := 14.0
const TAND := 4.0
const FÄRG := Color(0.80, 0.62, 0.34)
const FÄRG_ÖVER := Color(0.969, 0.722, 0.314)      ## samma guld som menytexten (`ui/huvudmeny.gd`)
const RING := 3.0

var _över := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(PX, PX)
	mouse_entered.connect(_sätt_över.bind(true))
	mouse_exited.connect(_sätt_över.bind(false))

func _sätt_över(över: bool) -> void:
	_över = över
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := PX * 0.28
	var f := FÄRG_ÖVER if _över else FÄRG
	for i in 8:
		var v := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		draw_rect(Rect2(c + v * (r * 1.45) - Vector2(TAND, TAND) * 0.5, Vector2(TAND, TAND)), f)
	draw_arc(c, r, 0.0, TAU, 24, f, RING, true)
	draw_arc(c, r * 0.45, 0.0, TAU, 16, f, 2.0, true)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		klick.emit()
		accept_event()
