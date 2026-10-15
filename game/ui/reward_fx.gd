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
## KORTET SJÄLVT ritas in i en egen yta (en SubViewport i kortets storlek) och vrids av shadern
## `ui/kort3d.gdshader`. Det är den enda vägen till en vändning MED djup: shadern läser UV som plats
## i rutan, och en glyfs UV är dess plats i fontatlaset — ett träd av Controls (text, paneler) kan
## alltså inte vridas direkt, bara EN textur kan. Förut skalades kortet i x, vilket är samma sak som
## en vändning utan perspektiv: kanterna stod still. Ytan är i kortets egen storlek (54x74), alltså
## 1:1 — kortet blir inte mjukare av omvägen.
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
const FOV := 90.0                  ## shaderns bildvinkel: 90 är kortets egen storlek, mindre vidgar

var _t := 0.0
var _igång := false
var _titel := ""
var _text := ""
var _ikon := "guld"
var _färg := Color(0.94, 0.84, 0.48)
var _kort3d: SubViewportContainer   ## kortets yta i vyn, vriden av shadern
var _kortruta: Control              ## rutan INNE i ytan, ritad av `rita_kort`

## Rutan i kortets yta. En Control kan inte få sin `_draw` utifrån, så den här lilla klassen lånar
## ritningen av stundens ägare — kortet ritas på ETT ställe (`rita_kort`), inte ett för vyn och ett
## för ytan.
class Kortruta extends Control:
	var ägare: RewardFx

	func _draw() -> void:
		if ägare != null:
			ägare.rita_kort(self)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_bygg_kort3d()

## Kortets yta: en SubViewport i kortets egen storlek, rutan i den, och behållaren med shadern överst.
## Uppdateringen står still när stunden inte spelar (`stega`), så ytan kostar ingenting i vila.
func _bygg_kort3d() -> void:
	_kort3d = SubViewportContainer.new()
	_kort3d.stretch = false
	_kort3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kort3d.size = KORT
	var vy := SubViewport.new()
	vy.size = Vector2i(KORT)
	vy.transparent_bg = true
	vy.disable_3d = true
	vy.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_kort3d.add_child(vy)
	_kortruta = Kortruta.new()
	(_kortruta as Kortruta).ägare = self
	_kortruta.size = KORT
	_kortruta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vy.add_child(_kortruta)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/kort3d.gdshader")
	mat.set_shader_parameter("fov", FOV)
	_kort3d.material = mat
	_kort3d.visible = false
	add_child(_kort3d)

## Kortets yta, för provet: shaderns vridning och vilken sida som ritas.
func kort3d() -> SubViewportContainer:
	return _kort3d

## Ytan inuti behållaren (den enda noden i den).
func _kort_vy() -> SubViewport:
	if _kort3d == null or _kort3d.get_child_count() == 0:
		return null
	return _kort3d.get_child(0) as SubViewport

## Kortet, ritat i ytans egna koordinater (origo i övre vänstra hörnet). Samma `_kort` som förut —
## bara en annan duk.
func rita_kort(ruta: Control) -> void:
	var s := stil()
	ruta.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_kort(ruta, Rect2(Vector2.ZERO, KORT), str(s["sida"]) == "baksida", float(s["alfa"]))

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
	# Ytan ritar bara medan stunden spelar: en SubViewport som uppdateras i vila är arbete för
	# ingenting.
	if _kort3d != null:
		var vy := _kort_vy()
		if vy != null:
			vy.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
			if m > 0:
				delar.append(Tr.t("fmt.mana", "+%d mana") % m)
			if h > 0:
				delar.append(Tr.t("ui.reward.heal", "+%d hp") % h)
			if g > 0:
				delar.append(Tr.t("ui.reward.gold", "+%d guld") % g)
			if delar.is_empty():
				return {}
			var id := str(e.get("card", ""))
			var ikon := "mana"
			var färg := Color(0.72, 0.78, 0.94)
			if h > 0 and m == 0 and g == 0:
				ikon = "läkning"
				färg = Color(0.82, 0.32, 0.30)
			elif g > 0 and m == 0 and h == 0:
				ikon = "guld"
				färg = Color(0.94, 0.84, 0.48)
			elif m > 0:
				ikon = "mana"
				färg = Color(0.72, 0.78, 0.94)
			elif h > 0:
				ikon = "läkning"
				färg = Color(0.82, 0.32, 0.30)
			elif g > 0:
				ikon = "guld"
				färg = Color(0.94, 0.84, 0.48)
			return {"titel": Tr.t("card." + id, id.to_upper()), "ikon": ikon,
				"text": ", ".join(delar), "färg": färg}
		"chest":
			# RELIKEN (M123) FÖRST: en relik ger varken guld eller HP, så den skulle falla på vakten
			# nedanför ("ingenting att visa = ingen stund") — och då vore lagrets största ögonblick
			# det enda som inte syntes. Namnet och texten kommer ur datan, som kortens.
			if vad == "relik":
				return {"titel": Tr.t("ui.reward.relic", "RELIK"), "ikon": "relik",
					"text": "%s — %s" % [str(e.get("namn", "")), str(e.get("text", ""))],
					"färg": Color(0.82, 0.58, 0.98)}
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
		var vy := _kort_vy()
		if vy != null:
			vy.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	#
	# `bredd` är vändningens MÅTT (provet mäter den) medan `vänd` är vinkeln shadern faktiskt vrids
	# till: 90° är kant in, 0° är framsidan mot betraktaren. Perspektivet gör sedan att den främre
	# kanten blir bredare än |cos| — det är skillnaden mellan en vändning och en skalning i x.
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
		"alfa": alfa, "glöd": glöd, "blixt": blixt, "strålar": strålar, "vinkel": v,
		"vänd": -rad_to_deg(v)}

# --- ritningen ---------------------------------------------------------------
func _draw() -> void:
	if not _igång or LÄNGD <= 0.0:
		if _kort3d != null:
			_kort3d.visible = false
		return
	var s := stil()
	var alfa := float(s["alfa"])
	if alfa <= 0.01:
		if _kort3d != null:
			_kort3d.visible = false
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
	# Kortet: ytan vrids av shadern (perspektiv) i stället för att skalas i x — en skalning är en
	# vändning där kanterna står still. Baksidan ritas i den första halvan, som förut. Ytan har
	# kortets egen storlek, så det är bara platsen och skalan som sätts här.
	var mitt := c + Vector2(0.0, 4.0 * sin(_t * 3.1))
	var skala: float = float(s["skala"])
	_kort3d.visible = true
	_kort3d.scale = Vector2.ONE * skala
	_kort3d.position = (mitt - KORT * 0.5 * skala).floor()
	var mat: ShaderMaterial = _kort3d.material
	mat.set_shader_parameter("rot_y_deg", float(s["vänd"]))
	mat.set_shader_parameter("rot_x_deg", rad_to_deg(0.02 * sin(_t * 2.3)))
	mat.set_shader_parameter("use_front", str(s["sida"]) == "framsida")
	_kortruta.queue_redraw()

## Kortet. Framsidan bär bytet (ikon, rubrik och rad); baksidan är ett mönster — den behövs bara för
## att en vändning ska synas som en vändning.
##
## `ruta` är noden som ritar, och det är därför den finns som argument: kortet ritas inne i kortets
## EGEN yta (Kortruta), och Godot tillåter bara ritning på den nod vars `_draw` körs. Att anropa
## `draw_rect` på stundens eget lager härifrån är felet "Drawing is only allowed inside this node's
## `_draw()`".
func _kort(ruta: CanvasItem, r: Rect2, baksida: bool, alfa: float) -> void:
	if baksida:
		ruta.draw_rect(r.grow(1.5), Color(0.03, 0.03, 0.05, 0.95 * alfa))
		ruta.draw_rect(r, Color(Palett.c(19).r, Palett.c(19).g, Palett.c(19).b, alfa))
		ruta.draw_rect(r.grow(-4.0), Color(Palett.c(6).r, Palett.c(6).g, Palett.c(6).b, 0.85 * alfa),
			false, 1.0)
		# Vapnet: en romb, samma märke som palettens guldram.
		var c := r.get_center()
		ruta.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -9), c + Vector2(7, 0), c + Vector2(0, 9), c + Vector2(-7, 0),
		]), Color(Palett.c(6).r, Palett.c(6).g, Palett.c(6).b, 0.9 * alfa))
		ruta.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0),
		]), Color(0.9, 0.86, 0.74, 0.9 * alfa))
		return
	var f := ThemeDB.fallback_font
	ruta.draw_rect(r.grow(2.0), Color(0.02, 0.02, 0.03, 0.92 * alfa))
	ruta.draw_rect(r, Color(Palett.c(2).r, Palett.c(2).g, Palett.c(2).b, alfa))
	ruta.draw_rect(r, Color(Palett.c(6).r, Palett.c(6).g, Palett.c(6).b, alfa), false, 2.0)
	# Rubriken i en egen färgplatta, som kortets typrad i handen.
	ruta.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4.0, 11.0)),
		Color(_färg.r * 0.7, _färg.g * 0.7, _färg.b * 0.7, alfa))
	ruta.draw_string(f, Vector2(r.position.x, r.position.y + 11.0), _titel,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, Color(1.0, 0.98, 0.93, alfa))
	_rita_ikon(ruta, r, alfa)
	# Raden med bytet: 9 px över kortets underkant, inte 7 — bokstävernas nederkant låg fyra px från
	# ramen och såg klippt ut (sett på bild: "sits very close to the bottom border").
	ruta.draw_string(f, Vector2(r.position.x, r.end.y - 9.0), _text, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, 9, Color(1.0, 0.96, 0.86, alfa))

## Bytet: ett mynt eller ett hjärta, ritat i palettfärger som all annan grafik i spelet.
func _rita_ikon(ruta: CanvasItem, r: Rect2, alfa: float) -> void:
	var c := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.48)
	if _ikon == "läkning":
		ruta.draw_circle(c + Vector2(-4, -3), 4.5, Color(0.72, 0.16, 0.18, alfa))
		ruta.draw_circle(c + Vector2(4, -3), 4.5, Color(0.72, 0.16, 0.18, alfa))
		ruta.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-8.4, -1.0), c + Vector2(8.4, -1.0), c + Vector2(0.0, 10.0),
		]), Color(0.80, 0.20, 0.22, alfa))
		ruta.draw_rect(Rect2(c + Vector2(-3, -4), Vector2(2, 2)), Color(0.98, 0.72, 0.70, alfa))
		return
	if _ikon == "relik":
		# AMULETTEN (M123): en ring med en sten i, för relikerna är det enda i spelet som är
		# UPPSAMAT i stället för förbrukat. Färgen skiljer den från guld och mana på en bildruta.
		ruta.draw_arc(c, 7.0, 0.0, TAU, 24, Color(0.86, 0.70, 0.42, alfa), 2.2)
		ruta.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -4.4), c + Vector2(3.6, 0), c + Vector2(0, 4.4), c + Vector2(-3.6, 0),
		]), Color(0.62, 0.34, 0.90, alfa))
		ruta.draw_rect(Rect2(c + Vector2(-1.2, -1.6), Vector2(2.4, 2.4)),
			Color(0.92, 0.80, 0.98, alfa))
		return
	if _ikon == "mana":
		# Mana-droppen/kristallen: en romb i manablått med ljus kärna och glans
		ruta.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -9), c + Vector2(7, 0), c + Vector2(0, 9), c + Vector2(-7, 0),
		]), Color(0.20, 0.45, 0.85, alfa))
		ruta.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0),
		]), Color(0.55, 0.78, 0.98, alfa))
		ruta.draw_rect(Rect2(c + Vector2(-2, -3), Vector2(2, 2)), Color(0.95, 0.98, 1.0, 0.9 * alfa))
		return
	ruta.draw_circle(c, 9.0, Color(Palett.c(13).r, Palett.c(13).g, Palett.c(13).b, alfa))
	ruta.draw_circle(c, 6.5, Color(Palett.c(14).r, Palett.c(14).g, Palett.c(14).b, alfa))
	ruta.draw_circle(c, 2.0, Color(Palett.c(18).r, Palett.c(18).g, Palett.c(18).b, alfa))
	ruta.draw_rect(Rect2(c + Vector2(-5.0, -5.0), Vector2(2, 2)), Color(1.0, 0.99, 0.92, 0.9 * alfa))
