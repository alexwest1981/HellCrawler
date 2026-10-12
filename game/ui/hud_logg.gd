## Loggfönstret nere till vänster (M40), som i Alex' GUI-referens: de senaste händelserna i striden
## med färg efter sort — skada i blodets färg, erfarenhet i guld, händelser i benets.
##
## Fönstret är en RING av fast längd: en strid kan ge hundra rader, och en logg som växer fyller till slut
## hela skärmen. De äldsta raderna faller ut när nya kommer in.
class_name HudLogg
extends Control

const BREDD := 262.0
## 84 px är TAKET. Sedan M113 ligger loggen i remsan i botten, och remsan är 90-150 px hög: då måste
## rutan kunna krympa med remsan, annars stack den utanför. `sätt_höjd` räknar om radavståndet och
## typsnittet ur höjden den får — mätt i en 90 px remsa blir raderna 11 px höga och texten 10 px, alltså
## läsbar; en högre remsa ger 12 px text som förut. Rubriken (18 px) behålls när höjden räcker till den.
const HÖJD := 84.0
const RADER := 4
const TEXT_PX := 12
## Rubrikens höjd i rutan, i px: rubriken ("LOGG") + linjen under den. Krymps när remsan är låg.
const RUBRIK_HÖJD := 18.0

var rubrik_text := ""     ## rubriken ritas i _draw (benfärg) — se sätt_rubrik
var rader: Array[Label] = []
var _text: Array = []          ## [{text, färg}] yngst sist
var _rubrik_px := 12           ## rubrikens typsnittsstorlek, satt av sätt_höjd
var _rad_topp := 22.0          ## första radens y, satt av sätt_höjd

static func bygg() -> HudLogg:
	var l := HudLogg.new()
	l.name = "hud_logg"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(BREDD, HÖJD)
	l.size = Vector2(BREDD, HÖJD)
	l._bygg()
	return l

## Anpassar rutan till remsan (M113): tar höjden den får (högst HÖJD) och lägger om rubriken och de
## fyra raderna så att de ryms. Texten krymper med höjden men försvinner aldrig — en logg som är
## oläslig är samma sak som ingen logg, och remsan är 90 px i sitt lägsta läge.
func sätt_höjd(h: float, bredd: float = BREDD) -> void:
	var hh := clampf(h, 56.0, HÖJD)
	var bb := clampf(bredd, 120.0, BREDD)
	# Minimimåttet först, annars kläms rutan till byggens 262x84 och loggen krymper aldrig (mätt).
	custom_minimum_size = Vector2(bb, hh)
	size = custom_minimum_size
	var rubrik := RUBRIK_HÖJD if hh >= 74.0 else 13.0
	var rad := maxf(9.0, (hh - rubrik - 2.0) / float(RADER))
	_rubrik_px = clampi(int(rad) + 1, 9, TEXT_PX)
	_rad_topp = rubrik + 4.0
	for i in rader.size():
		rader[i].add_theme_font_size_override("font_size", clampi(int(rad) - 1, 8, TEXT_PX))
		rader[i].size = Vector2(bb - 12.0, rad)
		rader[i].position = Vector2(6.0, _rad_topp + rad * float(i))
	queue_redraw()

func _bygg() -> void:
	for i in RADER:
		var l := Label.new()
		l.name = "logg_%d" % i
		l.add_theme_font_size_override("font_size", TEXT_PX)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		l.size = Vector2(BREDD - 12.0, float(TEXT_PX) + 4.0)
		l.position = Vector2(6.0, 22.0 + (TEXT_PX + 3.0) * i)
		add_child(l)
		rader.append(l)

## En ny rad. `färg` är radens sort (blod/guld/ben), inte dekoration: i en stridslogg är det färgen som
## gör att man hittar skadan utan att läsa varje ord.
func logga(text: String, färg: Color) -> void:
	if text.strip_edges().is_empty():
		return
	_text.append({"text": text, "färg": färg})
	while _text.size() > RADER:
		_text.pop_front()
	_rita_rader()

func töm() -> void:
	_text.clear()
	_rita_rader()

## Rubriken ("LOGG") sätts av anroparen: fönstret vet inte vilket språk spelet står på, och en svensk
## rubrik inbränd i ritkoden hade blivit kvar på alla 13.
func sätt_rubrik(t: String) -> void:
	# Rubriken RITAS i _draw (i benfärg). Den sattes först i en Label som låg kvar ovanpå med sin egen
	# standardfärg, och `rubrik_text` — den som _draw faktiskt läser — blev aldrig satt: rubriken
	# ritades alltså aldrig alls, och en mätning av rutans pixlar visade bara plåtens färger
	# (granskningen: "texten LOGG är extremt mörk och smälter nästan ihop med bakgrunden").
	rubrik_text = t
	queue_redraw()

func _rita_rader() -> void:
	for i in rader.size():
		if i < _text.size():
			rader[i].text = str(_text[i]["text"])
			rader[i].add_theme_color_override("font_color", _text[i]["färg"])
		else:
			rader[i].text = ""

## Raderna som text, äldst först — för provet och för `-- shot`, som skriver HUD:ens tillstånd som text
## i stället för att bara fotografera det.
func innehåll() -> Array:
	var ut := []
	for r in _text:
		ut.append(str(r["text"]))
	return ut

func _draw() -> void:
	HudPlat.rita(self, Rect2(Vector2.ZERO, size), 0.88)
	# Rubriken i BENFÄRG (Palett.c(22)), inte i plåtens: den råkade hamna i samma mörka ton som plåten
	# och försvann (granskningen: "texten LOGG är extremt mörk och smälter nästan ihop med
	# bakgrunden"). Linjen under skiljer rubriken från raderna. Båda följer `_rubrik_px` (sätt_höjd):
	# i en låg remsa är rubriken 9-10 px och linjen ligger tätt under den.
	draw_string(get_theme_font("font"), Vector2(8.0, float(_rubrik_px) + 2.0), rubrik_text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, _rubrik_px, Palett.c(22))
	draw_rect(Rect2(8.0, float(_rubrik_px) + 4.0, size.x - 16.0, 1.0), Palett.c(4))
