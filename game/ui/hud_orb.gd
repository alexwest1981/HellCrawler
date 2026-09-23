## Ett kärl i HUD-ramen (M36): hälsa, mana och rustning som en nivå man SER, inte bara en siffra.
##
## Alex: *"någon form av visuell hanterare för hälsa, mana och rustning"*. Kärlet är en rund skål i
## sten och metall med vätska i: fyllnadsgraden är nivån, och ytan har en egen ljus rad så man ser
## var nivån står även när kärlet nästan är fullt. Referensen är Diablo 1:s orbs till vänster och
## höger.
##
## Ritad i kod ur `palette.json`, som ramen och byn (`ui/palett.gd`): ingen ny grafik, och färgerna
## kan inte glida ifrån rutorna. Cirkeln ritas RAD FÖR RAD utan halvtoner — en slät `draw_circle`
## hade sett ut som en annan bild än pixelkonsten runt omkring.
class_name HudOrb
extends Control

const KANT := 4          ## stenkanten runt kärlet, i fönsterpixlar gånger skalan

var _radie := 38         ## kärlets radie i fönsterpixlar (utan skalan)
var _skala := 2
var _nivå := 0.0         ## 0,0-1,0: hur fullt kärlet är
var _färg := Color.RED   ## vätskans färg
var _tom := Color.BLACK  ## kärlets insida ovanför vätskan
## Siffran i kärlet ("3/7"). Nivån är en höjd på en skala — Alex: *"Manan är nu slut, men den gråblå
## cirkeln till höger är halvfull... jag behöver ha ett fungerande manaklot"*. Vätskan visar rätt
## nivå (mätt: 3/7 gav 43 %, precis som formeln säger), men en höjd går inte att jämföra med ett
## KORT som kostar 2. Siffran talar samma språk som korten, och rustningen får sin på samma sätt.
var text := ""

## `färg` är vätskan; storleken sätts i fönsterpixlar och multipliceras med heltalsskalan, samma
## skala som spelvyn och ramen.
func ställ_in(radie: int, färg: Color, tom: Color, heltalsskala: int) -> void:
	_radie = radie
	_färg = färg
	_tom = tom
	_skala = maxi(1, heltalsskala)
	size = Vector2(2 * (_radie + KANT), 2 * (_radie + KANT)) * _skala
	queue_redraw()

## Sätter kärlet så att dess MITT hamnar på `mitt`: storleken räknas ur radien och skalan, och
## den som placerar behöver inte kunna räkna ut var cirkeln ligger i sin egen ruta.
func placera_vid(mitt: Vector2) -> void:
	position = (mitt - Vector2.ONE * (_radie + KANT) * _skala).floor()


## Nivån klipps till 0,0-1,0: en nivå över 1,0 ritar inte utanför kärlet (överfull är samma som full).
func sätt_nivå(nivå: float) -> void:
	var ny := clampf(nivå, 0.0, 1.0)
	if absf(ny - _nivå) < 0.004:      # en halv dukpixel: mindre än så syns inte
		return
	_nivå = ny
	queue_redraw()

## Siffran som ritas mitt i kärlet. Ritas bara om när den ändras (kärlen redan vid varje bildruta i
## strid, och en text som sätts till samma sak ska inte kosta en omritning).
func sätt_text(ny: String) -> void:
	if ny == text:
		return
	text = ny
	queue_redraw()


func _draw() -> void:
	var r := _radie * _skala
	var c := Vector2(r, r) + Vector2(KANT, KANT) * _skala
	var sten := Palett.c(3)
	var sten_ljus := Palett.c(6)
	var järn := Palett.c(5)
	var mörk := Palett.c(1)

	# Skålen: en pixelcirkel rad för rad (ingen halvton), med stenkant runt om.
	_cirkel(c, r, mörk)
	_cirkel(c, r - 1 * _skala, sten)
	_cirkel(c, r - KANT * _skala, mörk)

	# VÄTSKAN MED DJUP (M75). Alex: *"Dessa är lite platta, så se om du kan öka känslan av glaskulor"*.
	# Vätskan var EN färg med en ljus ytrad — en fylld cirkel läses som en platt klump. En glaskula
	# har ljuset upptill och skuggan nedtill: varje rad får därför en egen ljushet (mörkast vid
	# botten, ljusast vid ytan) och en extra skugga där vätskan möter skålens vägg.
	var inner := float(r - KANT * _skala)
	var topp := c.y + inner - 2.0 * inner * _nivå
	if _nivå > 0.001:
		var botten_y := c.y + inner
		var djup_höjd := maxf(1.0, botten_y - topp)
		for y in range(int(topp), int(botten_y) + 1):
			var halv := sqrt(maxf(0.0, inner * inner - pow(float(y) - c.y, 2.0)))
			if halv < 1.0:
				continue
			var nedåt := clampf((float(y) - topp) / djup_höjd, 0.0, 1.0)
			var mot_kant := clampf(absf(float(y) - c.y) / inner, 0.0, 1.0)
			draw_rect(Rect2(c.x - halv, y, 2.0 * halv, 1.0),
				_färg.darkened(nedåt * 0.30 + mot_kant * 0.10))
		var yta := sqrt(maxf(0.0, inner * inner - pow(topp - c.y, 2.0)))
		draw_rect(Rect2(c.x - yta, topp, 2.0 * yta, 1.0 * _skala), _ljusare(_ljusare(_färg)))
		draw_rect(Rect2(c.x - yta, topp + 1.0 * _skala, 2.0 * yta, 1.0 * _skala), _mörkare(_färg))

	# GLASBLÄNKEN: en linsformad spegling uppe till vänster och en svagare nere till höger. Det är
	# den som gör kärlet till glas — högdagern sitter där en rund yta möter ljuset, oavsett nivån.
	if _nivå > 0.35:
		_båge(c, inner * 0.55, -1.05, -0.45, _ljusare(_ljusare(_färg)))
	_spegling(c - Vector2(inner * 0.40, inner * 0.44), maxf(1.5, inner * 0.19),
		maxf(2.0, inner * 0.40), Palett.c(10))
	_spegling(c + Vector2(inner * 0.42, inner * 0.30), maxf(1.0, inner * 0.10),
		maxf(1.5, inner * 0.20), Palett.c(8))

	# Metallkanten överst: en ljus glansbåge på vänster sida och en mörk skugga till höger, så
	# skålen läses som rund och inte som en platt cirkel.
	_båge(c, r - 2 * _skala, -0.75, -0.15, järn)
	_båge(c, r - 2 * _skala, 0.30, 0.85, mörk)
	draw_rect(Rect2(c.x - r, c.y - r, 2.0 * r, 1.0 * _skala), sten_ljus)

	# SIFFRAN: i kärlets mitt, i FÖNSTRETS upplösning (samma skäl som texten i vyn), med en mörk
	# skugga ett steg nedåt så den läses även över den ljusa vätskeytan.
	if text != "":
		var f := ThemeDB.fallback_font
		var st := maxi(8, int(round(float(_radie) * _skala * 0.62)))
		var bredd := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, st).x
		var bas := c + Vector2(-bredd * 0.5, st * 0.36)
		draw_string(f, bas + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, st, mörk)
		draw_string(f, bas, text, HORIZONTAL_ALIGNMENT_LEFT, -1, st, Color(0.95, 0.95, 0.90))

## En linsformad spegling (bredast i mitten, spetsig i ändarna), ritad rad för rad. `halvbredd` och
## `halvhöjd` mäts i fönsterpixlar; formen är en ellips, som en högdager på glas.
func _spegling(mitt: Vector2, halvbredd: float, halvhöjd: float, färg: Color) -> void:
	for i in range(int(-halvhöjd), int(halvhöjd) + 1):
		var t := float(i) / maxf(1.0, halvhöjd)
		var halv := halvbredd * sqrt(maxf(0.0, 1.0 - t * t))
		if halv < 0.5:
			continue
		draw_rect(Rect2(floor(mitt.x - halv), floor(mitt.y) + i, 2.0 * halv, 1.0),
			Color(färg.r, färg.g, färg.b, 0.55 - 0.30 * absf(t)))

## En fylld cirkel rad för rad. Ingen antialiasing: pixelkonst.
func _cirkel(c: Vector2, r: float, färg: Color) -> void:
	if r <= 0.0:
		return
	for y in range(int(c.y - r), int(c.y + r) + 1):
		var halv := sqrt(maxf(0.0, r * r - pow(float(y) - c.y, 2.0)))
		if halv < 0.5:
			continue
		draw_rect(Rect2(c.x - halv, y, 2.0 * halv, 1.0), färg)

## Ett bågstycke av skålens kant, i radianer (0 = rakt upp, positivt motsols).
func _båge(c: Vector2, r: float, från: float, till: float, färg: Color) -> void:
	var steg := 0.06
	var vinkel := från
	while vinkel <= till:
		var p := c + Vector2(sin(vinkel), -cos(vinkel)) * r
		draw_rect(Rect2(floor(p.x), floor(p.y), 1.0 * _skala, 1.0 * _skala), färg)
		vinkel += steg

## Nivån som den ritas (efter klippning) — för provet, som annars inte kan se om 1,5 blev 1,0.
func nivå() -> float:
	return _nivå


func _ljusare(f: Color) -> Color:
	return f.lightened(0.20)

func _mörkare(f: Color) -> Color:
	return f.darkened(0.35)
