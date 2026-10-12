## Statusblocket uppe till vänster (M40): porträtt, siffrorna och en nivåbricka.
##
## MÄTT in i referensen: blocket ligger i den ÖVRE marginalen (fönstret är 1280x720 och spelvyn
## 960x540 centrerad, så marginalen ovanför vyn är 90 px hög) och når aldrig in över spelvyn.
##
## KÄRLEN TILLBAKA (M51). Alex: *"det är svårt som fan själv att se ... sin egen hälsa (jag gillade
## när du hade allt som klot innan, det får du gärna lägga tillbaka på ett lämpligt ställe)"*. De tre
## staplarna är därför borta ur blocket — nivån står i HudOrb-kärlen i sidomarginalerna (se main.gd),
## och SIFFRORNA står kvar här som en rad. En stapel och ett kärl som visar samma sak är två svar på
## en fråga; en rad med siffror är det exakta svaret.
class_name HudStatus
extends Control

const BREDD := 430.0
const HÖJD := 78.0
const PORTRÄTT := 48.0
var porträtt: TextureRect
var vital_label: Label
var bana_label: Label
var niva_label: Label
var guld_label: Label
var _skala := 1.0           ## blockets krympning mot fönstret, satt av sätt_skala

static func bygg() -> HudStatus:
	var s := HudStatus.new()
	s.name = "hud_status"
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.custom_minimum_size = Vector2(BREDD, HÖJD)
	s.size = Vector2(BREDD, HÖJD)
	s._bygg()
	return s

func _bygg() -> void:
	porträtt = TextureRect.new()
	porträtt.name = "portratt"
	porträtt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	porträtt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	porträtt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	porträtt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := "res://assets/ui/portratt.png"
	if ResourceLoader.exists(p):
		porträtt.texture = load(p)
	porträtt.size = Vector2(PORTRÄTT, PORTRÄTT)
	porträtt.position = Vector2(8.0, 15.0)
	add_child(porträtt)

	# Sifferraden: HP 57/60 · MANA 3/7 · RUST 0/1. Färgen är den ljusa neutrala (c7), inte c8 som
	# HudBar använde inuti en stapel — på en mörk plåt behöver siffrorna sin egen kontrast.
	vital_label = _text(15, Palett.c(7))

	bana_label = _text(14, Palett.c(7))
	niva_label = _text(17, Palett.c(13))
	guld_label = _text(13, Palett.c(14))

func _text(px: int, färg: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", färg)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## Lägger staplarna och texterna på plats. Görs vid varje `sätt` och inte i `_bygg`: en översättning
## som är längre än den svenska får inte klippas, och raderna flyttas därför efter textens höjd.
func _placera() -> void:
	_placera_skalad(_skala)

func _placera_skalad(k: float) -> void:
	var x := (8.0 + PORTRÄTT + 8.0) * k
	vital_label.position = Vector2(x, 12.0 * k)
	bana_label.position = Vector2(x, 33.0 * k)
	niva_label.position = Vector2(x, 49.0 * k)
	guld_label.position = Vector2(x + 96.0 * k, 49.0 * k)

## KRYMPER BLOCKET MED FÖNSTRET (M113). Blockets 430 px är 34 % av en 1280-ruta men 46 % av en
## 941-ruta — och i remsan står loggen, korträknaren, högarna och kartan på samma rad. MÄTT i 941x1018:
## med full bredd rymdes varken korträknaren (120 px) eller högarna (84 px). Allt skalas med samma
## faktor — plåten, porträttet, typsnittet och avstånden — så blockets RUTA blir mindre, inte bara
## texten: annars mätte provet den gamla rutan. Golvet 0,62 ger 9-10 px siffror, alltså läsbara.
func sätt_skala(k: float) -> void:
	_skala = clampf(k, 0.62, 1.0)
	# ORDNINGEN: minimimåttet först. Sätts `size` först kläms den till det GAMLA minimimåttet (430x78)
	# och blocket krympte aldrig — mätt i 941x1018: sätt_skala(0,63) gav en ruta på 430x78.
	custom_minimum_size = Vector2(roundf(BREDD * _skala), roundf(HÖJD * _skala))
	size = custom_minimum_size
	porträtt.size = Vector2(PORTRÄTT, PORTRÄTT) * _skala
	porträtt.position = Vector2(8.0, 15.0) * _skala
	for par in [[vital_label, 15], [bana_label, 14], [niva_label, 17], [guld_label, 13]]:
		(par[0] as Label).add_theme_font_size_override("font_size",
			maxi(9, int(round(float(par[1]) * _skala))))
	_placera_skalad(_skala)
	queue_redraw()

## Fyller blocket. `s` kommer från `main._status_data()` — nycklarna står där, så en ny siffra i HUD:en
## läggs till på ett ställe och inte i varje anrop.
func sätt(s: Dictionary) -> void:
	var i_strid: bool = bool(s.get("i_strid", false))
	var hp := float(s.get("hp", 0.0))
	var max_hp := maxf(1.0, float(s.get("max_hp", 1.0)))
	# Rubrikerna ur i18n: "rust" heter armor/Rüstung/防御/броня i de andra språken, och en hårdkodad
	# svensk rubrik hade stått kvar på alla 13.
	var delar := ["%s %.0f/%.0f" % [Tr.t("ui.hud.bar.hp", "HP"), hp, max_hp]]
	# Mana och rustning hör till striden: utanför en strid finns de inte, och en nolla vore att visa
	# något som inte gäller (samma skäl som kärlen hade).
	if i_strid:
		delar.append("%s %.0f/%.0f" % [Tr.t("ui.hud.bar.mana", "MANA"),
			float(s.get("mana", 0.0)), float(s.get("mana_max", 1.0))])
		delar.append("%s %.0f/%.0f" % [Tr.t("ui.hud.bar.rust", "RUST"),
			float(s.get("rust", 0.0)), float(s.get("rust_max", 1.0))])
	vital_label.text = "   ".join(delar)
	bana_label.text = str(s.get("bana", ""))
	niva_label.text = str(s.get("niva", ""))
	guld_label.text = str(s.get("guld", ""))
	_placera()
	queue_redraw()

func _draw() -> void:
	# Plåten och porträttramen ritas i blockets AKTUELLA storlek (M113): sätt_skala krymper rutan, och
	# ritades plåten i konstanten BREDD hade den blivit 430 px bred medan provet mätte 271.
	HudPlat.rita(self, Rect2(Vector2.ZERO, size))
	# Porträttets ram: en indragen öppning i plåten, med en ljus kant upptill och vänstertill.
	var k := _skala
	var r := Rect2(porträtt.position - Vector2(3.0, 3.0) * k, Vector2(PORTRÄTT + 6.0, PORTRÄTT + 6.0) * k)
	draw_rect(r, Palett.c(1))
	draw_rect(r, Palett.c(5), false, 2.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Palett.c(7))
