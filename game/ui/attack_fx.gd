class_name AttackFx
extends Control

## Angreppet SYNS: ett vapen far genom bilden mot målet, i den form kortet förtjänar.
##
## Alex: "Det saknas fortfarande någon form av visuell bekräftelse att man gjort en attack, t ex
## kniv som far förbi, en piska som snärtar till". Siffran och blinket talar om VAD som hände;
## det här talar om ATT man slog — och med vad.
##
## Allt ritas med Control._draw och en enda tidsvariabel: inga texturer, ingen animation att hålla
## reda på. Rörelsen är kort (0,3 s) med flit — den ska skymma synfältet en blinkning, inte en scen.
##
##       klinga  kniv, dolk, nagel        ett snabbt streck som skär genom bilden
##       piska   Lash, tång, törne          en lång kurva som snärtar och rullar tillbaka
##       kross   klubba, slaga, knogjärn    en tung båge som landar med en stöt
##       ring    klocka, korus, hymn        ringar som slår ut från målet
##       glöd    tome, bok, krita, runa     en ljusglimt som stiger vid målet
##       mjuk    dryck, salva, väktare      stilla stigande gnistor (inget vapen)

const ORIGO := Vector2(0.62, 0.94)      ## varifrån slaget kommer, i andelar av vyn

var _typ := "klinga"
var _färg := Color(0.95, 0.95, 0.92)
var _mål := Vector2.ZERO
var _styrka := 1
var _t := 0.0
var _längd := 0.3
var _igång := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Starta en attack. `card` ger formen och färgen, `mål` är fiendens plats i skärmkoordinater,
## `styrka` är kedjemultiplikatorn (ett kedjat slag ska se kraftigare ut, inte bara göra mer).
func spela(card, mål: Vector2, styrka: int = 1) -> void:
	_typ = _typ_för(card)
	_färg = _färg_för(card)
	_mål = mål
	_styrka = maxi(1, styrka)
	_längd = 0.42 if _typ == "piska" else 0.3
	if _typ == "ring":
		_längd = 0.5
	_t = 0.0
	_igång = true
	set_process(true)
	queue_redraw()


## Vilket vapen kortet slåss med. Nyckelord i id:t först — korten heter vad de ÄR (lash, dagger,
## bell, tome) — och kortets typ som reserv, så ett nytt attackkort alltid får ett streck.
static func _typ_för(card) -> String:
	var id: String = str(card.id).to_lower()
	var namn: String = str(card.title()).to_lower()
	var t := "%s %s" % [id, namn]
	for ord_ in ["lash", "whip", "tång", "thorn", "bramble"]:
		if t.contains(ord_):
			return "piska"
	for ord_ in ["bell", "chime", "choir", "hymn", "song", "klocka"]:
		if t.contains(ord_):
			return "ring"
	for ord_ in ["tome", "book", "scroll", "chalk", "rune", "grimoire", "krita"]:
		if t.contains(ord_):
			return "glöd"
	for ord_ in ["club", "mace", "hammer", "flail", "knuckle", "bulwark", "shove", "claw", "fist"]:
		if t.contains(ord_):
			return "kross"
	for ord_ in ["vial", "salve", "draught", "ward", "ring", "potion", "sval", "dryck"]:
		if t.contains(ord_):
			return "mjuk"
	if str(card.card_type) == "attack":
		return "klinga"
	if str(card.card_type) == "mana" or str(card.card_type) == "wild":
		return "glöd"
	return "mjuk"


func _färg_för(card) -> Color:
	# Färgen kommer ur SAMMA tabell som kortets kant (CardView.TYPE_COLORS): svepet ska ha kortets
	# färg, inte en påhittad. Andra värdet i paret är textfärgen, den ljusa.
	var par: Array = CardView.TYPE_COLORS.get(str(card.card_type), CardView.TYPE_COLORS["wild"])
	return (par[1] as Color).lightened(0.15)


func _process(delta: float) -> void:
	if not _igång:
		return
	_t += delta
	if _t >= _längd:
		_igång = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not _igång:
		return
	var p: float = clampf(_t / _längd, 0.0, 1.0)
	# Vyns mått, inte Control:ens egen storlek: den är (0,0) — mätt — eftersom föräldern är ett
	# CanvasLayer utan layout. Målet från cam.unproject_position är i SAMMA rymd (480x270-basvyn),
	# så båda hörnen stämmer.
	var vy := get_viewport_rect().size
	var från := Vector2(vy.x * ORIGO.x, vy.y * ORIGO.y)
	match _typ:
		"klinga":
			_klinga(från, p)
		"piska":
			_piska(från, p)
		"kross":
			_kross(från, p)
		"ring":
			_ringar(p)
		"glöd":
			_glöd(p)
		_:
			_mjuk(p)


## Ett streck som skär genom bilden. Spetsen går först (40 % av tiden), sedan tonar spåret ut.
func _klinga(från: Vector2, p: float) -> void:
	var spets: float = minf(1.0, p / 0.4)
	var spill: float = clampf((p - 0.4) / 0.6, 0.0, 1.0)
	var mot := _mål - från
	var start := från + mot * (0.06 * spets)
	var slut := från + mot * (0.6 + 0.4 * spets)
	var vinkel := mot.normalized()
	var tvär := Vector2(-vinkel.y, vinkel.x)
	# Bågen: en lätt krökning gör svepet till ett hugg i stället för en linjal.
	var böj := 0.10 * mot.length() * (1.0 - 0.6 * spets)
	for i in 10:
		var a := float(i) / 9.0
		var b := float(i + 1) / 9.0
		var pa := start.lerp(slut, a) + tvär * böj * sin(a * PI)
		var pb := start.lerp(slut, b) + tvär * böj * sin(b * PI)
		var ton: float = (0.35 + 0.65 * a) * (1.0 - spill)
		var bredd: float = 1.0 + 2.0 * _styrka * 0.5
		draw_line(pa, pb, Color(_färg.r, _färg.g, _färg.b, ton), bredd, true)
	# Bladet: en smal triangel vid spetsen, bara medan hugget går.
	if spill < 0.6:
		var a: float = 1.0 - spill
		draw_colored_polygon(PackedVector2Array([
			slut + vinkel * 26.0 * a, slut + tvär * 5.0 * a, slut - tvär * 5.0 * a,
		]), Color(1.0, 1.0, 0.98, 0.9 * a))


## Piskan: en lång kurva med en våg längs vägen. Spetsen snärtar (pik) och rullen går tillbaka.
func _piska(från: Vector2, p: float) -> void:
	var ut: float = minf(1.0, p / 0.45)
	var in_: float = clampf((p - 0.45) / 0.55, 0.0, 1.0)
	var mot := _mål - från
	var vinkel := mot.normalized()
	var tvär := Vector2(-vinkel.y, vinkel.x)
	var längd: float = mot.length() * (0.35 + 0.65 * ut) * (1.0 - 0.25 * in_)
	var snärt: float = sin(in_ * PI) * 0.35
	var punkter := PackedVector2Array()
	for i in 24:
		var a := float(i) / 23.0
		var bas := från + vinkel * längd * a
		var våg: float = sin(a * PI * 2.4 - p * 22.0) * 22.0 * a * (1.0 - 0.5 * in_)
		punkter.append(bas + tvär * (våg + snärt * 40.0 * a * a))
	var ton: float = 0.30 + 0.70 * (1.0 - in_)
	draw_polyline(punkter, Color(_färg.r, _färg.g, _färg.b, ton), 1.5 + 0.5 * _styrka, true)
	# Snärten: en ljus fläck där piskan vänder.
	var spets: Vector2 = punkter[punkter.size() - 1]
	draw_circle(spets, 3.0 + 2.0 * _styrka, Color(1.0, 0.98, 0.92, ton))


## Tygnd: en kort båge som landar, med en ring och stötstrålar i nedslaget.
func _kross(från: Vector2, p: float) -> void:
	var ned: float = minf(1.0, p / 0.5)
	var efter: float = clampf((p - 0.5) / 0.5, 0.0, 1.0)
	var mot := _mål - från
	var vinkel := mot.normalized()
	var tvär := Vector2(-vinkel.y, vinkel.x)
	var mitt := från.lerp(_mål, 0.35 + 0.45 * ned)
	var böj := 44.0 * (1.0 - 0.5 * ned)
	var punkter := PackedVector2Array()
	for i in 12:
		var a := float(i) / 11.0
		punkter.append(från.lerp(_mål, 0.1 + 0.85 * a) + tvär * böj * sin(a * PI) * (1.0 - 0.7 * ned))
	draw_polyline(punkter, Color(_färg.r, _färg.g, _färg.b, 0.85 * (1.0 - efter)), 3.0 + 1.5 * _styrka, true)
	if ned > 0.85:
		var kraft: float = efter
		for i in 9:
			var a: float = TAU * float(i) / 9.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(_mål + dir * (6.0 + 26.0 * kraft), _mål + dir * (14.0 + 46.0 * kraft),
				Color(1.0, 0.95, 0.85, 0.8 * (1.0 - kraft)), 2.0, true)
		draw_arc(_mål, 10.0 + 40.0 * kraft, 0.0, TAU, 24,
			Color(1.0, 0.98, 0.92, 0.6 * (1.0 - kraft)), 1.5, true)


## Klockan: tre ringar som slår ut från målet.
func _ringar(p: float) -> void:
	for i in 3:
		var fördröjd: float = clampf((p - 0.16 * i) / 0.6, 0.0, 1.0)
		if fördröjd <= 0.0:
			continue
		var r: float = 8.0 + 52.0 * fördröjd
		draw_arc(_mål, r, 0.0, TAU, 28,
			Color(_färg.r, _färg.g, _färg.b, 0.75 * (1.0 - fördröjd)), 1.0 + 1.5 * _styrka, true)


## Boken/ruman: en glimt som stiger och en ljus kärna vid målet.
func _glöd(p: float) -> void:
	var upp: float = clampf(p / 0.75, 0.0, 1.0)
	var ned: float = clampf((p - 0.75) / 0.25, 0.0, 1.0)
	var alfa: float = 0.85 * (1.0 - ned)
	for i in 5:
		var a := float(i) / 4.0
		var m: Vector2 = _mål + Vector2(sin(a * 7.0 + p * 8.0) * 16.0, -26.0 * upp * (0.5 + a))
		draw_circle(m, 2.0 + 2.0 * (1.0 - a), Color(_färg.r, _färg.g, _färg.b, alfa * (0.8 - 0.4 * a)))
	draw_circle(_mål, 14.0 + 10.0 * upp - 12.0 * ned, Color(_färg.r, _färg.g, _färg.b, alfa * 0.35))


## Utan vapen: ett par lugna gnistor som stiger. Ett rustningskort ska inte se ut som ett hugg.
func _mjuk(p: float) -> void:
	var alfa: float = 0.6 * (1.0 - p)
	for i in 4:
		var a := float(i) / 3.0
		var m: Vector2 = _mål + Vector2(-14.0 + 28.0 * a, -34.0 * p * (0.6 + a))
		draw_circle(m, 2.5, Color(_färg.r, _färg.g, _färg.b, alfa))
