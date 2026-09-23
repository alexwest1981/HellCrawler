class_name RewardFx
extends Control

## StUNDEN man får något: kortet vänds in i bilden med en glöd, strålar och gnistor omkring sig.
##
## Alex: "en tydlig stund när man får ett föremål (kort som vänds in med glöd)". En kista som ger
## guld syntes tidigare bara som en rad i topplistan och ett myntljud — samma sak som att ingenting
## hände. Referensens bild av samma ögonblick är ett föremål som hänger i en ljusexplosion mitt i
## vyn, och det är det som byggs här: en glöd som växer, ett kort som vänder sig in (baksidan först,
## framsidan med bytet när det landar) och gnistor som stiger.
##
## Allt ritas med `Control._draw` och EN tidsvariabel, som angreppet (`ui/attack_fx.gd`): ingen
## animation att hålla reda på, ingen scen, inga bildfiler. Siffrorna bakom ritningen ligger i
## `stil()` — provet i tests/test_reward.gd mäter dem i stället för att titta på en bild, och `_draw`
## ritar ur exakt samma funktion.
##
##       fas        vad som händer
##       vänds      kortet kommer in från sidan: baksidan först, glöden växer
##       utbrott    framsidan landar — blixt, strålar och den starkaste glöden
##       håll       kortet står still och guppar; gnistor stiger
##       tonar      allt bleknar ut och lagret stänger av sig
const LÄNGD := 1.7                 ## hela stunden, i sekunder
const FLIPP := 0.36                ## ANDEL av tiden då kortet vänt sig in
const UT := 0.62                   ## ANDEL då utbrottet är över
const HÅLL := 0.72                 ## ANDEL då kortet börjar blekna
const KORT := Vector2(54, 74)      ## kortets mått i 480x270-vyn
const HÖJD := -18.0                ## kortets mitt ovanför vyens mitt (så texten under får plats)

var _t := 0.0
var _igång := false
var _titel := ""
var _text := ""
var _ikon := "guld"
var _färg := Color(0.94, 0.84, 0.48)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## Vad stunden visar. `ikon` är "guld" eller "läkning" (se `_ikon`), `färg` glödens ton.
func visa(titel: String, text: String, ikon := "guld", färg := Color(0.94, 0.84, 0.48)) -> void:
	_titel = titel
	_text = text
	_ikon = ikon
	_färg = färg
	_t = 0.0
	_igång = true
	visible = true
	set_process(true)
	queue_redraw()

## Översätt en händelse ur körningens eventström till vad stunden ska visa. EN källa: kistan,
## facklan och framtida byten går genom samma funktion, så en ny belöning inte kan bli tyst.
static func från_event(e: Dictionary) -> Dictionary:
	var vad := str(e.get("vad", ""))
	match str(e.get("type", "")):
		"card":
			# Kortet man spelade: rubriken är kortets namn (samma nyckel som handen använder, alltså
			# redan översatt) och raden de tal som faktiskt ändrades. Ett kort som bara gör skada har
			# ingen siffra att visa — skadan syns i striden — och ger därför ingen stund.
			var delar := []
			var m := int(e.get("mana", 0))
			var h := int(e.get("hp", 0))
			var g := int(e.get("gold", 0))
			if m != 0:
				delar.append(Tr.t("fmt.mana", "+%d mana") % m)
			if h != 0:
				delar.append(Tr.t("ui.reward.heal", "+%d hp") % h)
			if g != 0:
				delar.append(Tr.t("ui.reward.gold", "+%d guld") % g)
			if delar.is_empty():
				return {}
			var id := str(e.get("card", ""))
			return {"titel": Tr.t("card." + id, id.to_upper()), "ikon": "guld",
				"text": ", ".join(delar), "färg": Color(0.72, 0.78, 0.94)}
		"chest":
			# Ingenting att visa = ingen stund. En kista som ger 0 guld och 0 hp (man stod redan på
			# full hälsa) ska inte fira någonting: en stund för noll är en lögn om vad man fick.
			if int(e.get("gold", 0)) <= 0 and int(e.get("hp", 0)) <= 0:
				return {}
			if vad == "guld":
				return {"titel": Tr.t("ui.reward.chest", "KISTA"), "ikon": "guld",
					"text": Tr.t("ui.reward.gold", "+%d guld") % int(e.get("gold", 0)),
					"färg": Color(0.94, 0.84, 0.48)}
			return {"titel": Tr.t("ui.reward.chest", "KISTA"), "ikon": "läkning",
				"text": Tr.t("ui.reward.heal", "+%d hp") % int(e.get("hp", 0)),
				"färg": Color(0.82, 0.32, 0.30)}
		"torch":
			return {"titel": Tr.t("ui.reward.rest", "VILA"), "ikon": "läkning",
				"text": Tr.t("ui.reward.heal", "+%d hp") % int(e.get("hp", 0)),
				"färg": Color(0.86, 0.68, 0.34)}
		_:
			return {}

## Tiden. Egen funktion (och inte bara `_process`) så provet kan köra hela stunden utan en skärm.
func stega(dt: float) -> void:
	if not _igång:
		return
	_t += dt
	if _t >= LÄNGD:
		_t = LÄNGD
		_igång = false
		visible = false
		set_process(false)
	queue_redraw()

func aktiv() -> bool:
	return _igång

func titel() -> String:
	return _titel

func text() -> String:
	return _text

func _process(delta: float) -> void:
	stega(delta)

## Fasens namn. Provet läser den i stället för tiden, så en ändrad längd inte kan göra provet rätt
## av fel skäl.
func fas() -> String:
	if not _igång:
		return "klar"
	var p := _t / LÄNGD
	if p < FLIPP:
		return "vänds"
	if p < UT:
		return "utbrott"
	if p < HÅLL:
		return "håll"
	return "tonar"

## Allt ritningen behöver, som siffror: vilken sida som syns, hur bred kortet är (0 = kant mot
## betraktaren), skalan, alfan, glöden, blixten och strålarna. `_draw` ritar ur den här och provet
## mäter den — annars vore "kortet vänds in med en glöd" ett påstående utan mätning.
func stil() -> Dictionary:
	var p: float = clampf(_t / LÄNGD, 0.0, 1.0)
	# Vändningen: vinkeln går från -90° (kanten mot oss) till 0°, så bredden är |cos| och baksidan
	# syns i den första halvan. Ett kort som bara tonar in ser ut som en panel — det är KANTEN som
	# gör att ögat läser en vändning.
	var v: float = -PI / 2.0 * (1.0 - clampf(p / FLIPP, 0.0, 1.0))
	var bredd: float = maxf(0.04, absf(cos(v)))
	var baksida := p / FLIPP < 0.5 and p < FLIPP
	# Skalan: växer med vändningen och får en liten översläng när framsidan landar (samma grepp som
	# handens kort), sedan stilla gupp under hållet.
	var skala := 0.72 + 0.28 * clampf(p / FLIPP, 0.0, 1.0)
	if p >= FLIPP and p < UT:
		skala += 0.10 * sin((p - FLIPP) / (UT - FLIPP) * PI)
	elif p >= UT:
		skala += 0.012 * sin(_t * 4.2)
	var glöd := clampf(p / maxf(FLIPP, 0.001), 0.0, 1.0)
	if p >= UT:
		glöd *= 0.55 + 0.45 * (1.0 - clampf((p - UT) / (HÅLL - UT), 0.0, 1.0))
	var blixt := 0.0
	if p >= FLIPP:
		blixt = 0.45 * clampf(1.0 - (p - FLIPP) / maxf(UT - FLIPP, 0.001) * 0.55, 0.0, 1.0)
		if p >= UT:
			blixt *= clampf(1.0 - (p - UT) / maxf(HÅLL - UT, 0.001), 0.0, 1.0)
	var strålar := 0.0
	if p >= FLIPP:
		# Käglorna fullt ut nästan direkt efter vändningen (0,36 → 0,48) och kvar en bra bit in i
		# hållet: en blixt som redan slocknat när man tittar på den är ingen blixt.
		strålar = clampf((p - FLIPP) / 0.12, 0.0, 1.0)
		if p >= 0.48:
			strålar *= 0.75 + 0.25 * (1.0 - clampf((p - 0.48) / (LÄNGD - 0.48), 0.0, 1.0))
	var alfa := 1.0
	if p >= HÅLL:
		alfa = clampf(1.0 - (p - HÅLL) / maxf(1.0 - HÅLL, 0.001), 0.0, 1.0)
	return {"sida": "baksida" if baksida else "framsida", "bredd": bredd, "skala": skala,
		"alfa": alfa, "glöd": glöd, "blixt": blixt, "strålar": strålar, "vinkel": v}

# --- ritningen ---------------------------------------------------------------
func _draw() -> void:
	if not _igång or LÄNGD <= 0.0:
		return
	var s := stil()
	var alfa := float(s["alfa"])
	if alfa <= 0.01:
		return
	var vy := get_viewport_rect().size
	var c := Vector2(vy.x * 0.5, vy.y * 0.5 + HÖJD)
	# Blixten: hela vyn lyser till en bildruta när framsidan landar. Det är den som gör att ögat
	# tittar — utan den är stunden en panel som tonar in.
	if float(s["blixt"]) > 0.01:
		draw_rect(Rect2(Vector2.ZERO, vy),
			Color(_färg.r, _färg.g, _färg.b, float(s["blixt"]) * alfa))
	# Strålarna: sexton ekrar ut från kortet, längst i utbrottet (se `stil`). Det är den radiella
	# explosionen som gör stunden till en stund — glöden säger "något händer", ekrarna säger "det
	# händer HÄR och NU".
	if float(s["strålar"]) > 0.01:
		var ut: float = float(s["strålar"])
		for i in 16:
			var a: float = TAU * float(i) / 16.0 + 0.13
			var dir := Vector2(cos(a), sin(a))
			var inre := 18.0 + 14.0 * (1.0 - ut)
			var yttre := inre + (12.0 + 88.0 * ut) * (0.72 + 0.28 * sin(float(i) * 2.1))
			# Två lager per eker: en bred, svag stråle och en smal, ljus kärna. En enkel tunn linje
			# läses som ett streck, två lager läses som ljus (sett på bild: "thin and sparse rays").
			draw_line(c + dir * inre, c + dir * yttre,
				Color(_färg.r, _färg.g, _färg.b, 0.34 * ut * alfa), 5.0, true)
			draw_line(c + dir * inre, c + dir * yttre,
				Color(1.0, 0.97, 0.88, 0.85 * ut * alfa), 2.0, true)
		# Linsfläcken: två smala streck tvärs över, som i referensens bild av samma ögonblick.
		draw_line(c - Vector2(150.0, 0.0) * ut, c + Vector2(150.0, 0.0) * ut,
			Color(1.0, 0.96, 0.86, 0.45 * ut * alfa), 1.0, true)
		draw_line(c - Vector2(0.0, 34.0) * ut, c + Vector2(0.0, 34.0) * ut,
			Color(1.0, 0.96, 0.86, 0.30 * ut * alfa), 1.0, true)
	# Glöden: sju cirklar, mörkast ytterst och svaga var för sig. Fyra grova cirklar ger synliga
	# trappsteg i kanten (sett på bild: "stepped circular bands") — fler och svagare blir en mjuk
	# krans utan en enda extra rad kod.
	if float(s["glöd"]) > 0.02:
		var g: float = float(s["glöd"])
		for k in 7:
			var r: float = (22.0 + 30.0 * g) * (0.55 + 0.30 * float(k))
			var ton: float = 0.11 * (1.0 - 0.10 * float(k)) * g * alfa
			draw_circle(c, r, Color(_färg.r, _färg.g, _färg.b, ton))
		draw_circle(c, 14.0 * g, Color(1.0, 0.97, 0.88, 0.6 * g * alfa))
	# Gnistorna: sexton stycken som kastas UTÅT från kortet och slocknar på vägen. De far radiellt (som
	# i referensens utbrott) i stället för att stiga rakt upp, och läggs utanför glöden så de syns:
	# en gnista inuti kransen är bara brus i kransen.
	var p: float = clampf(_t / LÄNGD, 0.0, 1.0)
	if p > FLIPP * 0.6:
		for i in 16:
			var a: float = TAU * float(i) / 16.0 + 0.21
			var dir := Vector2(cos(a), sin(a))
			var fart: float = 0.7 + float((i * 53) % 7) / 7.0 * 0.6
			var up: float = clampf((p - FLIPP * 0.6) * 1.5 * fart, 0.0, 1.0)
			var pos := c + dir * (40.0 + 120.0 * up)
			var ton: float = (1.0 - up) * 1.0 * alfa
			draw_rect(Rect2(pos - dir * 7.0, Vector2(4, 4)), Color(1.0, 0.86, 0.52, 0.5 * ton))
			draw_rect(Rect2(pos, Vector2(4, 4)), Color(1.0, 0.93, 0.72, ton))
			draw_rect(Rect2(pos, Vector2(2, 2)), Color(1.0, 0.99, 0.94, ton))
	# Kortet: vändningen är en skalning i x (samma grepp som en rotation kring y-axeln i 2D), och
	# baksidan ritas i den första halvan.
	var mitt := c + Vector2(0.0, 4.0 * sin(_t * 3.1))
	draw_set_transform(mitt, 0.02 * sin(_t * 2.3), Vector2(float(s["bredd"]), float(s["skala"])))
	_kort(Rect2(-KORT / 2.0, KORT), str(s["sida"]) == "baksida", alfa)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Kortet. Framsidan bär bytet (ikon, rubrik och rad); baksidan är ett mönster — den behövs bara för
## att en vändning ska synas som en vändning.
func _kort(r: Rect2, baksida: bool, alfa: float) -> void:
	if baksida:
		draw_rect(r.grow(1.5), Color(0.03, 0.03, 0.05, 0.95 * alfa))
		draw_rect(r, Color(Palett.c(19).r, Palett.c(19).g, Palett.c(19).b, alfa))
		draw_rect(r.grow(-4.0), Color(Palett.c(6).r, Palett.c(6).g, Palett.c(6).b, 0.85 * alfa), false, 1.0)
		# Vapnet: en romb, samma märke som palettens guldram.
		var c := r.get_center()
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -9), c + Vector2(7, 0), c + Vector2(0, 9), c + Vector2(-7, 0),
		]), Color(Palett.c(6).r, Palett.c(6).g, Palett.c(6).b, 0.9 * alfa))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0),
		]), Color(0.9, 0.86, 0.74, 0.9 * alfa))
		return
	var f := ThemeDB.fallback_font
	draw_rect(r.grow(2.0), Color(0.02, 0.02, 0.03, 0.92 * alfa))
	draw_rect(r, Color(Palett.c(2).r, Palett.c(2).g, Palett.c(2).b, alfa))
	draw_rect(r, Color(Palett.c(6).r, Palett.c(6).g, Palett.c(6).b, alfa), false, 2.0)
	# Rubriken i en egen färgplatta, som kortets typrad i handen.
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4.0, 11.0)),
		Color(_färg.r * 0.7, _färg.g * 0.7, _färg.b * 0.7, alfa))
	draw_string(f, Vector2(r.position.x, r.position.y + 11.0), _titel, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, 9, Color(1.0, 0.98, 0.93, alfa))
	_rita_ikon(r, alfa)
	# Raden med bytet: 9 px över kortets underkant, inte 7 — bokstävernas nederkant låg fyra px från
	# ramen och såg klippt ut (sett på bild: "sits very close to the bottom border").
	draw_string(f, Vector2(r.position.x, r.end.y - 9.0), _text, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, 9, Color(1.0, 0.96, 0.86, alfa))

## Bytet: ett mynt eller ett hjärta, ritat i palettfärger som all annan grafik i spelet.
func _rita_ikon(r: Rect2, alfa: float) -> void:
	var c := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.48)
	if _ikon == "läkning":
		draw_circle(c + Vector2(-4, -3), 4.5, Color(0.72, 0.16, 0.18, alfa))
		draw_circle(c + Vector2(4, -3), 4.5, Color(0.72, 0.16, 0.18, alfa))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-8.4, -1.0), c + Vector2(8.4, -1.0), c + Vector2(0.0, 10.0),
		]), Color(0.80, 0.20, 0.22, alfa))
		draw_rect(Rect2(c + Vector2(-3, -4), Vector2(2, 2)), Color(0.98, 0.72, 0.70, alfa))
		return
	draw_circle(c, 9.0, Color(Palett.c(13).r, Palett.c(13).g, Palett.c(13).b, alfa))
	draw_circle(c, 6.5, Color(Palett.c(14).r, Palett.c(14).g, Palett.c(14).b, alfa))
	draw_circle(c, 2.0, Color(Palett.c(18).r, Palett.c(18).g, Palett.c(18).b, alfa))
	draw_rect(Rect2(c + Vector2(-5.0, -5.0), Vector2(2, 2)), Color(1.0, 0.99, 0.92, 0.9 * alfa))
