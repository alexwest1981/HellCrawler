## HUD:ens yta runt spelvyn (M36, omgjord i M113).
##
## Alex: *"den svarta ytan behöver få en grafisk HUD, lite som diablo 1/2, men korten har central
## plats nedtill"* — och sedan, när ramen låg där: *"ännu en grå ram runt spelfönstret (det man ser
## dungeon i), jag vill bara ha en bottom border a la Doom 2"* / *"den jävla grå ramen runt rutan man
## spelar i, ta bort skiten, det skall bara vara en bottom bar"*.
##
## RAMEN RUNT VYN ÄR BORTTAGEN. Ingen plåt, ingen faskant, ingen indragen fasad och ingen kantlinje
## ritas längre runt spelvyn — ritkoden för den är raderad (inte avstängd med en flagga). Det som
## ligger kvar runt vyn är BAKGRUNDSFÄRGEN, och den ENDA ytan som ritas är BAREN under vyn: plåtar i
## golvbandet, precis som Diablo/Doom-remsan. Vyn läser då som hela fönstret med en remsa under.
##
## Ritad i kod och ur `palette.json`, inte som PNG: samma skäl som byn och världskartan (se
## `ui/palett.gd`) — ingen ny grafik behövs, ytan följer fönstrets storlek, och färgerna kan inte
## glida ifrån rutorna. Måttet är i FÖNSTERpixlar gånger heltalsskalan.
##
## MÄTT (guiprov): 0 px i en 6 px bred remsa längs vyns kanter skiljer sig från bakgrundsfärgen —
## ingen kantlinje mot vyn. Och 0 px av plåtarna ligger innanför vyns ruta.
class_name HudRam
extends Control

## Bakgrunden runt vyn: samma färg som spelets egen himmel/tak (`env.background_color` i
## `main._ready`, 0.07/0.07/0.10). Sidokolumnerna som blir över när heltalsskalan inte fyller bredden
## målas i den, så att bilden läser som ett fönster och inte som en inramad ruta (M113).
const BAKGRUND := Color(0.07, 0.07, 0.10)
const PLÅT := 48         ## plåtarnas sida: två plåtar ryms i barens kortaste höjd (BAR_HOJD * 1 px)
const NIT := 3           ## nitens sida i fönsterpixlar (blir 3 px i varje skala)

## STENPLATTAN (M113). Alex skickade en stenbild och bestämde: *"sträck ut den"*. Plattan (348x150,
## tools/gen_bar_sten.py ur tools/refs/bar_sten_kalla.jpg) TÖJS över barens fulla bredd — den upprepas
## inte — och höjden delas i 9 delar: kantlinjerna (6 px upptill, 7 px nertill) ligger FIXA och bara
## den mjuka mitten töjs. Utan 9-delningen smetades 1 px-linjerna ut till gråa band när remsan är
## lägre än 150 px (mätt: plattan skalas 0,6-1,0 i höjd beroende på fönstret).
const STEN := "res://assets/ui/bar_sten.png"
const STEN_TOPP := 6.0
const STEN_BOTTEN := 7.0
var _sten: StyleBoxTexture

var _vy := Rect2()       ## spelvyns ruta i fönstret, satt av main._placera_vy
var _skala := 2
var _mjuk := false       ## `sten=mjuk`: LINEAR filtrering i stället för NEAREST
var _bar := true         ## remsan ritas bara i en körning (M113): byn/kartan/menyerna har ingen

## Spelvyns ruta i fönsterpixlar: ytorna ritas runtomkring och ingenting innanför.
## REMSAN SYNS BARA I EN KÖRNING (M113). Alex: *"Det skall inte vara en bar i botten förrän man är
## inne i dungeons"*. Grinden sitter här, i bakgrunden, och `main._visa_gui` gömmer innehållet i
## samma läge — annars stod plåtarna (och stenen) kvar i byn med tomma rutor ovanpå.
func sätt_bar_syns(syns: bool) -> void:
	if _bar == syns:
		return
	_bar = syns
	queue_redraw()

func sätt_vy(ruta: Rect2, heltalsskala: int) -> void:
	_vy = ruta
	_skala = maxi(1, heltalsskala)
	queue_redraw()

## Stenbakgrunden i baren: en StyleBoxTexture som TÖJS i sidled (`STRETCH` — Alex: *"sträck ut den"*)
## och i höjdled bara i sin mjuka mitt (9-delning via kanternas marginaler). Filtreringen avgör vad
## töjningen gör: NEAREST (pixelkonst, standard) dubblar rader och ger hårda pixelränder, LINEAR jämnar
## ut dem. Alex fick båda i provbilderna och valde det som står i `_mjuk` (se rapporten).
func _sten_ruta() -> StyleBoxTexture:
	if _sten == null:
		_sten = StyleBoxTexture.new()
		if ResourceLoader.exists(STEN):
			_sten.texture = load(STEN)
		_sten.texture_margin_top = STEN_TOPP
		_sten.texture_margin_bottom = STEN_BOTTEN
		_sten.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		_sten.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _mjuk else CanvasItem.TEXTURE_FILTER_NEAREST
	return _sten

## Granskningsflagga `sten=mjuk`: ritar baren med mjuk filtrering i stället för NEAREST, så att
## provbilden kan visa vad töjningen gör med pixlarna.
func sätt_sten_mjuk(mjuk: bool) -> void:
	_mjuk = mjuk
	_sten = null
	queue_redraw()

## Banden runt vyn: taket, golvet, vänsterkolumnen och högerkolumnen. Tillsammans är de exakt
## fönstret minus vyn — ingen rad ritas två gånger och inget hål uppstår (provet mäter det).
## TAKET ÄR TOMT SEDAN M113: vyn ligger i överkanten (`_vy.position.y = 0`), så bandet ovanför vyn har
## höjden noll och hoppas över. Kvar blir tre band — och baren under vyn är det tredje (golvbandet):
## plåtarna där är ingen egen kontroll utan just den här bakgrunden.
func band(fönster: Vector2) -> Array[Rect2]:
	var ut: Array[Rect2] = []
	if _vy.size.x < 4.0 or _vy.size.y < 4.0:
		return ut
	for r in [Rect2(0, 0, fönster.x, _vy.position.y),                       # tak
			Rect2(0, _vy.end.y, fönster.x, fönster.y - _vy.end.y),          # golv (remsan)
			Rect2(0, _vy.position.y, _vy.position.x, _vy.size.y),           # vänster
			Rect2(_vy.end.x, _vy.position.y, fönster.x - _vy.end.x, _vy.size.y)]:  # höger
		# Tomma band hoppas över: en vy som fyller fönstret har ingen marginal att rita i, och fyra
		# tomma rutor är fyra rutor som någon senare undrar över.
		# Golvbandet (remsan) hoppas över när ingen körning är igång (M113).
		if r == Rect2(0, _vy.end.y, fönster.x, fönster.y - _vy.end.y) and not _bar:
			continue
		if r.size.x > 0.0 and r.size.y > 0.0:
			ut.append(r)
	return ut

## Ytorna HUD:en ritar runtom vyn: GOLVBANDET (baren under vyn) i plåtar, och sidokolumnerna i
## bakgrundsfärgen. Provet mäter listan: ingen yta får ligga inne i vyn, och bara baren får vara plåt.
##
## Det är här "ingen ram runt spelvyn" (M113) bor: det finns ingen yta kvar som ritar något annat än
## baren och bakgrunden, alltså kan ingen grå plåt hamna vid vyns kant.
func ytor(fönster: Vector2) -> Array:
	var ut := []
	for r in band(fönster):
		ut.append({"ruta": r, "plåtar": r.position.y >= _vy.end.y - 0.5})
	return ut

func _draw() -> void:
	var f := size
	if _vy.size.x < 4.0 or _vy.size.y < 4.0:
		return
	# BAKGRUNDEN I SIDOKOLUMNERNA (M113). Alex: *"ännu en grå ram runt spelfönstret (det man ser
	# dungeon i), jag vill bara ha en bottom border a la Doom 2"*. Kolumnerna som blir över när
	# heltalsskalan inte fyller bredden är därför en PLATT färg — samma som spelets egen himmel/tak
	# (`env.background_color`, 0.07/0.07/0.10) — och inte en plåtyta med faskant och nitar. Ingen
	# kantlinje ritas mot vyn: bilden ska läsa som hela fönstret med en remsa under, inte som en
	# inramad ruta. MÄTT i guiprovet: 0 px i sidobanden skiljer sig från bakgrundsfärgen.
	var mörk := Palett.c(1)
	for yta in ytor(f):
		var r: Rect2 = yta["ruta"]
		if bool(yta["plåtar"]):
			# BAREN: stenplattan (M113). Plåtarna med nitar ligger kvar som fallback om tillgången
			# saknas — en bar utan bakgrund är värre än en bar med fel bakgrund, och provet mäter att
			# filen finns (game/tests/test_assets.gd).
			var sten := _sten_ruta()
			if sten.texture != null:
				draw_style_box(sten, r)
			else:
				_plåtar(r, mörk)
		else:
			draw_rect(r, BAKGRUND)

## Smutsen på EN plåt. Den är formad, inte strödd: sotet ligger i kanterna och i hörnen (där det
## fastnar), rinningarna börjar i översta sömmen och rinner ned, och fläckarna kommer i KLUMPAR —
## en stor med ett par små intill. Första försöket strödde lika stora prickar jämnt över plåten, och
## granskningen dömde det som brus: "patina klumpar sig, följer kanter och varierar i skala".
func _smutsa(bandet: Rect2, x: int, y: int, steg: int, smuts: Color, repa: Color) -> void:
	var bx := int(x / float(steg))
	var by := int(y / float(steg))
	var s := _skala
	# Kanten: mörka segment längs nederkanten och längs sömmarna, med hashad längd.
	var frök := _brus(bx * 11, by * 3)
	var längd := (6 + frök % 20) * s
	_ruta(bandet, Rect2(x + s + (frök % maxi(1, steg - längd - s)), y + steg - 2 * s, längd, s), smuts)
	var fröh := _brus(bx * 3, by * 23)
	_ruta(bandet, Rect2(x + s, y + s + (fröh % maxi(1, steg - 12 * s)), s, (4 + fröh % 14) * s), smuts)
	# Klumpen: en stor fläck med två mindre intill, alldeles innanför kanten.
	var frö := _brus(bx * 7 + 1, by * 13 + 1)
	var kx := x + 4 * s + (frö % maxi(1, steg - 20 * s))
	var ky := y + 4 * s + ((frö / 7) % maxi(1, steg - 20 * s))
	_ruta(bandet, Rect2(kx, ky, 4 * s, 3 * s), smuts)
	_ruta(bandet, Rect2(kx + 4 * s, ky + 2 * s, 2 * s, 2 * s), smuts)
	_ruta(bandet, Rect2(kx - 2 * s, ky + 3 * s, 2 * s, s), smuts)
	# Rinningarna: de börjar i översta sömmen och rinner nedåt, olika långt.
	for i in 2:
		var frör := _brus(bx * 31 + i, by * 17 + i)
		var rx := x + 4 * s + (frör % maxi(1, steg - 8 * s))
		_ruta(bandet, Rect2(rx, y + s, s, (6 + (frör / 11) % 22) * s), smuts)
	# Den slitna fläcken: mitt på plåten, ljus — det är där något tagit i.
	var frös := _brus(bx * 53, by * 29)
	_ruta(bandet, Rect2(x + 4 * s + (frös % maxi(1, steg - 20 * s)),
		y + 6 * s + ((frös / 5) % maxi(1, steg - 10 * s)),
		(6 + (frös / 3) % 14) * s, s), repa)


## Ett litet deterministiskt brus. SAMMA ruta ger samma smuts varje gång: annars vandrar fläckarna
## var gång ramen ritas om, och en HUD som rör på sig ser trasig ut. Hashen är den vanliga
## XOR-multiplikatorn — den behöver bara vara jämn och snabb, inte statistiskt fin.
func _brus(x: int, y: int) -> int:
	var n := x * 73856093 ^ y * 19349663
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


## Plåtarna: sömmar var PLÅT:e fönsterpixel och en nit där sömmarna möts. Ytan är MÖRK, smutsig
## metall — en jämn färg läses som platt grått (mätt i granskning: "inte platt å grått"), så varje
## plåt får en lodrät ljusgradient, fläckar, rinningar och en repa, alla ur `_brus`. Klipps mot
## bandet: en plåt ritas aldrig in i spelvyn.
func _plåtar(bandet: Rect2, mörk: Color) -> void:
	var steg := PLÅT * _skala
	var n := NIT * _skala
	var söm := 2 * _skala
	var kant := 2 * _skala
	var plåt := Palett.c(2)          # plåtens yta: mörk, inte c(3) — ramens bas ska vara nära svart
	var topp := Palett.c(3)          # ...och en ton upp i överkanten, det är metallen som lyser
	var smuts := Palett.c(1)         # fläckar och rinningar
	var repa := Palett.c(4)          # repor: ljusare än ytan, mörkare än faskanten
	var ljus := Palett.c(5)          # faskantens ljusa sida
	var järn := Palett.c(5)          # nitens kropp (en ton över plåten: nitar ska synas i smutsen)
	var glans := Palett.c(7)         # nitens glans
	# Rutnätet ankras i BANDETS eget hörn, inte i fönstrets: annars hamnar sömmarna och nitarna
	# utanför ett smalt band (mätt: 90 px-bandet visade bara två lodräta sömmar och inga nitar alls
	# — rutnätet låg på 192 px och nuddade aldrig bandets rader).
	var y := floorf(bandet.position.y / float(steg)) * steg
	while y <= bandet.end.y:
		var x := floorf(bandet.position.x / float(steg)) * steg
		while x <= bandet.end.x:
			var r := Rect2(x, y, float(steg), float(steg))
			# Plåten: ytan, en faskant upptill/vänster (ljus) och nedtill/höger (mörk), och en söm
			# runt om. Faskanten är det som gör att plåten läses som en plåt och inte som ett fält.
			_ruta(bandet, r, plåt)
			_ruta(bandet, Rect2(x + söm, y + söm, steg - söm, (steg - söm) / 3), topp)           # metallen lyser upptill
			_ruta(bandet, Rect2(x + söm, y + söm, steg - söm, kant), ljus)                       # överkant
			_ruta(bandet, Rect2(x + söm, y + söm, kant, steg - söm), ljus)                       # vänsterkant
			_ruta(bandet, Rect2(x + söm, y + steg - söm - kant, steg - söm, kant), mörk)          # nederkant
			_ruta(bandet, Rect2(x + steg - söm - kant, y + söm, kant, steg - söm), mörk)          # högerkant
			_ruta(bandet, Rect2(x, y, float(steg), float(söm)), mörk)                            # söm över
			_ruta(bandet, Rect2(x, y, float(söm), float(steg)), mörk)                            # söm vänster
			_smutsa(bandet, x, y, steg, smuts, repa)
			# Nitarna sitter i plåtens fyra hörn, innanför faskanten: 2 px in (gånger skalan). En
			# mörk ring under varje nit gör att den sitter PÅ plåten i stället för i den.
			var inne := 2 * _skala
			for h in [Vector2(inne, inne), Vector2(steg - inne - n, inne),
					Vector2(inne, steg - inne - n), Vector2(steg - inne - n, steg - inne - n)]:
				_ruta(bandet, Rect2(Vector2(x, y) + h + Vector2(1, 1) * _skala,
					Vector2(n, n) + Vector2.ONE * _skala), mörk)
				_nit(bandet, Vector2(x, y) + h, n, järn, glans)
			x += steg
		y += steg

## En fylld ruta klippt mot bandet (utan klippning skulle en plåt måla inne i spelvyn).
func _ruta(bandet: Rect2, r: Rect2, färg: Color) -> void:
	var k := r.intersection(bandet)
	if k.size.x > 0.0 and k.size.y > 0.0:
		draw_rect(k, färg)

func _nit(bandet: Rect2, p: Vector2, sida: int, järn: Color, ljus: Color) -> void:
	_ruta(bandet, Rect2(p, Vector2(sida, sida)), järn)
	_ruta(bandet, Rect2(p, Vector2(sida, 1)), ljus)
	_ruta(bandet, Rect2(p, Vector2(1, sida)), ljus)
