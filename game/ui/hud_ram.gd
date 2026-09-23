## HUD-ramen (M36): den svarta marginalen runt spelvyn ritas om till en ram i Diablo 1/2:s anda.
##
## Alex: *"den svarta ytan behöver få en grafisk HUD, lite som diablo 1/2, men korten har central
## plats nedtill"*. Ramen lägger sig UTANFÖR spelvyns ruta — fyra band runt vyn — och längs vyns
## kant blir den en indragen fasad: mörk skugga innerst, ljus metallmoulding utanför. Ytan är
## plåtar: en mörk bas, sömmar mellan plåtarna och nitar på sömmarna. Sten och metall, inte platta
## textrader.
##
## Ritad i kod och ur `palette.json`, inte som PNG: samma skäl som byn och världskartan (se
## `ui/palett.gd`) — ingen ny grafik behövs, ramen följer fönstrets storlek, och färgerna kan inte
## glida ifrån rutorna. Måttet är i FÖNSTERpixlar gånger heltalsskalan, så ramen läses likadant
## oavsett fönsterstorlek.
##
## MÄTT (samma scen, samma kamera, `-- stage=stage_01 shot`): med ramen på är skillnaden INNANFÖR
## spelvyn 0,01 i medel och 0 bildpunkter över tröskeln — ramen ritar ingenting i vyn. Marginalen
## går från svart (medel 6,3) till plåtyta (medel 42,8).
class_name HudRam
extends Control

const KANT := 3          ## bredden på metallmouldingen runt vyn (3-4 px läses som en list)
const SKUGGA := 2        ## den mörka indragningen innanför listen
const PLÅT := 48         ## plåtarnas sida: två plåtar ryms i det smalaste bandet (90 px)
const NIT := 3           ## nitens sida i fönsterpixlar (blir 3 px i varje skala)
const FALS := 4          ## faskanten längs fönstrets ytterkant

var _vy := Rect2()       ## spelvyns ruta i fönstret, satt av main._placera_vy
var _skala := 2

## Spelvyns ruta i fönsterpixlar: ramen ritar allt runtomkring och ingenting innanför.
func sätt_vy(ruta: Rect2, heltalsskala: int) -> void:
	_vy = ruta
	_skala = maxi(1, heltalsskala)
	queue_redraw()

## Banden runt vyn: taket, golvet, vänsterkolumnen och högerkolumnen. Tillsammans är de exakt
## fönstret minus vyn — ingen rad ritas två gånger och inget hål uppstår (provet mäter det).
func band(fönster: Vector2) -> Array[Rect2]:
	var ut: Array[Rect2] = []
	if _vy.size.x < 4.0 or _vy.size.y < 4.0:
		return ut
	for r in [Rect2(0, 0, fönster.x, _vy.position.y),                       # tak
			Rect2(0, _vy.end.y, fönster.x, fönster.y - _vy.end.y),          # golv
			Rect2(0, _vy.position.y, _vy.position.x, _vy.size.y),           # vänster
			Rect2(_vy.end.x, _vy.position.y, fönster.x - _vy.end.x, _vy.size.y)]:  # höger
		# Tomma band hoppas över: en vy som fyller fönstret har ingen marginal att rita i, och fyra
		# tomma rutor är fyra rutor som någon senare undrar över.
		if r.size.x > 0.0 and r.size.y > 0.0:
			ut.append(r)
	return ut

func _draw() -> void:
	var f := size
	if _vy.size.x < 4.0 or _vy.size.y < 4.0:
		return
	var mörk := Palett.c(1)
	for r in band(f):
		_plåtar(r, mörk)
	# Faskant längs fönstrets ytterkant: ljus upptill/vänster, mörk nedtill/höger. Det är den som
	# får ramen att läsa som en platta och inte som en tom yta.
	_fals(f, Palett.c(4), Palett.c(0))
	_hörnskär(f, Palett.c(0))
	# Den indragna fasaden längs vyns kant: mörk skugga innerst, metallmoulding, mörk linje ytterst.
	# Mouldingen är NEUTRAL grå (c(5)/c(6)), inte palettens blå stål (c(19)-c(21)): det blå läste
	# som en cyan tejp runt bilden i granskningen, och Diablos ram är varm grå metall.
	_ring(_vy, SKUGGA * _skala, Palett.c(0))
	_ring(_vy.grow(SKUGGA * _skala), KANT * _skala, Palett.c(4))
	_ring(_vy.grow((SKUGGA + KANT) * _skala), 1, mörk)

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

## Faskanten runt hela fönstret: en ljus linje upptill och till vänster, en mörk nedtill och till
## höger, och en andra mörk linje innanför — samma tre steg som runt vyn, så ramen hänger ihop.
func _fals(f: Vector2, ljus: Color, mörk: Color) -> void:
	var b := float(FALS * _skala)
	draw_rect(Rect2(0, 0, f.x, b), ljus)
	draw_rect(Rect2(0, 0, b, f.y), ljus)
	draw_rect(Rect2(0, f.y - b, f.x, b), mörk)
	draw_rect(Rect2(f.x - b, 0, b, f.y), mörk)

## 45-gradig skärning i fönstrets fyra hörn: en rät vinkel läses som en skärmkant, en skuren kant
## läses som en plåt — samma grepp som fiendekonstens hörnputs. Skärningen är det enda ornamentet på
## ramen, och den kostar fyra trianglar.
func _hörnskär(f: Vector2, färg: Color) -> void:
	var k := int(FALS * _skala * 3)
	for rad in range(k):
		var vidd := float(k - rad)
		draw_rect(Rect2(0, rad, vidd, 1), färg)                       # övre vänster
		draw_rect(Rect2(f.x - vidd, rad, vidd, 1), färg)              # övre höger
		draw_rect(Rect2(0, f.y - 1 - rad, vidd, 1), färg)             # nedre vänster
		draw_rect(Rect2(f.x - vidd, f.y - 1 - rad, vidd, 1), färg)    # nedre höger


## En ram precis UTANFÖR `ruta`, `bredd` pixlar tjock och aldrig en pixel innanför kanten.
func _ring(ruta: Rect2, bredd: int, färg: Color) -> void:
	if bredd <= 0:
		return
	var b := float(bredd)
	var uppe := Rect2(ruta.position.x - b, ruta.position.y - b, ruta.size.x + 2.0 * b, b)
	var nere := Rect2(ruta.position.x - b, ruta.end.y, ruta.size.x + 2.0 * b, b)
	var vänster := Rect2(ruta.position.x - b, ruta.position.y, b, ruta.size.y)
	var höger := Rect2(ruta.end.x, ruta.position.y, b, ruta.size.y)
	for r in [uppe, nere, vänster, höger]:
		draw_rect(r, färg)
