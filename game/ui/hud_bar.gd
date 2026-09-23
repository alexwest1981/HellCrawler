## En livsstapel (M40): rubrik, fylld del och siffrorna PÅ stapeln — referensens `HP: 140/150`.
##
## Referensen har staplar i stället för kärl: en stapel är lättare att läsa på avstånd än en sfär, och
## siffrorna ryms inuti den. Provet mäter fyllningens BREDD mot värdet, för det är den kopplingen som
## gör en stapel till en mätare och inte till en bild.
class_name HudBar
extends Control

const RUBRIK_BREDD := 44.0      ## px till vänster om stapeln, för "HP"/"MANA"/"RUST"
const HÖJD := 15.0
const TEXT_PX := 12

var rubrik := ""
var fyllning := Color.WHITE
var bottenfärg := Color.BLACK
var ramfärg := Color.WHITE
var värde := 0.0
var maxvärde := 1.0
var siffer_text := ""

## `bredd` är stapelns bredd (utan rubriken). Rutan blir rubriken + luft + stapeln.
func ställ_in(rub: String, f: Color, b: Color, r: Color, bredd: float) -> void:
	rubrik = rub
	fyllning = f
	bottenfärg = b
	ramfärg = r
	custom_minimum_size = Vector2(RUBRIK_BREDD + bredd, HÖJD)
	size = custom_minimum_size
	queue_redraw()

func sätt(v: float, m: float) -> void:
	värde = v
	maxvärde = maxf(1.0, m)
	siffer_text = "%.0f/%.0f" % [värde, maxvärde]
	queue_redraw()

## Hur stor del av stapeln som är fylld, 0-1. Kläms: en nivå över taket (eller under noll) får inte ritas
## utanför stapeln, och det är precis vad en manabar gör utan tak i motorn.
func andel() -> float:
	return clampf(värde / maxf(1.0, maxvärde), 0.0, 1.0)

func _draw() -> void:
	var f := get_theme_font("font")
	var st := TEXT_PX
	var b := Rect2(Vector2(RUBRIK_BREDD, 0.0), Vector2(size.x - RUBRIK_BREDD, HÖJD))
	draw_rect(b, bottenfärg)
	if f != null and not rubrik.is_empty():
		draw_string(f, Vector2(0.0, HÖJD - 3.0), rubrik, HORIZONTAL_ALIGNMENT_LEFT, RUBRIK_BREDD - 4.0, st,
			ramfärg)
	var inre := b.grow(-1.0)
	var fylld := Rect2(inre.position, Vector2(inre.size.x * andel(), inre.size.y))
	draw_rect(fylld, fyllning)
	# En ljus linje på fyllningens överkant: en stapel utan den är en platt kloss.
	draw_rect(Rect2(fylld.position, Vector2(fylld.size.x, 1.0)), fyllning.lightened(0.35))
	draw_rect(b, ramfärg, false, 1.0)
	if f != null and not siffer_text.is_empty():
		draw_string(f, Vector2(b.position.x + 3.0, HÖJD - 3.0), siffer_text,
			HORIZONTAL_ALIGNMENT_RIGHT, b.size.x - 6.0, st, Palett.c(8))
