## Kortens RÖRELSE mätt som siffror, bildruta för bildruta.
##
## Provet kör de fyra rörelserna i en riktig bildrute-loop (headless), samplar position, storlek,
## skala och genomskinlighet VARJE bildruta, skriver kurvan som en tabell per fas och kontrollerar
## de egenskaper Alex känner i handen:
##
##   svikt     — hur djupt kortet viker sig ned under pekaren och hur mycket det trycks ihop,
##               hur länge, hur mycket lyftet överslänger och när det satt sig
##   återgång  — samma svikt ned igen, och att kortet landar exakt på sin hemplats
##   spelat    — STÖTEN (skalan) och FLYKTEN (px upp, med översväng) plus tiden till utgång
##   utdelat   — efterföljden: när varje kort startar, hur mycket det växer in, när det står
##               still — och att underkanten aldrig lämnar den svarta ytan under tiden
##   efterföljd— att raden ger efter ett kort i taget när ett kort träder fram, och att varje kort
##               landar exakt på sin plats
##
##   godot --headless --path game --script res://tests/test_kortrorelse.gd
##
## Bilderna i samma faser tas av demoläget: `DISPLAY=:99 godot --path game -- shots` (kort-utdelning,
## kort-svikt, kort-fram, kort-stot, kort-spelat) och _shot skriver kortens y och skala för samma
## bildruta. Två tabeller, inte två intryck — talen här är en kurva, bilderna är ögonblick ur den.
##
## OBS: Tween.custom_step() rör INTE en tween i Godot 4.7.2 (mätt: pausad, opausad och parallell
## stod stilla). Klockan måste därför vara bildrutorna själva, och tiden nedan är summan av
## deltat — samma väg som spelet går.
extends SceneTree

const CARD := CardView.HAND_SIZE
const TOL := 0.6                 ## px: innanför den här är något "på plats"
const FAS_MAX := 0.75            ## s: en fas tar slut när rörelsen står still, eller här

var fails := 0
var checks := 0

var _db: Dictionary
var _namn := ["svikt", "återgång", "spelat", "utdelat", "efterföljd", "valkort"]
var _fas := -1
var _uppvarm := 0
var _t := 0.0
var _logg: Array = []
var _kort: Array = []
var _hemma: Array = []           ## varje korts hem-y, för utdelningsfasen
var _start_x: Array = []         ## varje korts x före efterföljden
var _matt: Array = []            ## sammanfattningen, en rad per fas

## Ett prov: skriver vad som MÄTTES, inte bara att det gick bra. En tröskel som inte kan förklara
## sig själv är ett omdöme, och ett omdöme kan inte jämföras med originalet.
func check(ok: bool, vad: String, detalj := "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])

# ---------------------------------------------------------------- provets gång

func _initialize() -> void:
	_db = Cards.load_all()
	print("— kortens rörelse, bildruta för bildruta (px och ms) —")

func _process(delta: float) -> bool:
	# Värm upp först: den FÖRSTA bildrutan efter _initialize tog 43 ms (mätt), och hela svikten
	# (45 ms) försvann inuti den — kurvan saknade sin egen första fas. Fem bildrutor utan rörelse
	# ger korta, jämna delta innan klockan startar.
	if _uppvarm < 5:
		_uppvarm += 1
		if _uppvarm == 5:
			_nästa_fas()
		return false
	_t += delta
	var rad := {"t": _t * 1000.0, "k": []}
	for k in _kort:
		rad["k"].append({"x": (k as CardView).position.x, "y": (k as CardView).position.y,
			"h": (k as CardView).size.y, "s": (k as CardView).scale.x,
			"sy": (k as CardView).scale.y, "a": (k as CardView).modulate.a})
	_logg.append(rad)
	if _stilla() or _t >= FAS_MAX:
		_avsluta_fasen()
	return false

func _nästa_fas() -> void:
	_fas += 1
	if _fas >= _namn.size():
		_sammanfatta()
		return
	# Fas 1 mäter korten fas 0 lämnade (det framträdda som ska tillbaka), de andra två nya.
	if _fas >= 2:
		for k in _kort:
			(k as CardView).queue_free()
		_kort = []
	_hemma = []
	_logg = []
	_t = 0.0
	match _fas:
		0:
			var k := _kort_på(Vector2(100, 200))
			_starta([k], Callable(k, "set_forward").bind(true))
		1:
			_starta(_kort, Callable(_kort[0], "set_forward").bind(false))
		2:
			var k := _kort_på(Vector2(100, 200))
			_starta([k], Callable(k, "fly_out"))
		3:
			# En ny hand: fyra kort som delas ut ett i taget. De sätts där handen sätter dem, med
			# handens egen fördröjning — samma konstant som main.gd läser.
			var nya: Array = []
			for i in 4:
				var v := _kort_på(Vector2(100.0 + i * 70.0, 200.0))
				_hemma.append(v.position.y)
				nya.append(v)
			_kort = nya
			for i in nya.size():
				(nya[i] as CardView).dela_in(i * CardView.DELA_STEG)
		4:
			# Raden ger efter kring det kort man pekar på: alla kort glider 20 px ifrån det, ett
			# kort i taget. Samma fördröjning som _rada_hand ger dem (steg * EFTERFÖLJD).
			_kort = []
			for i in 4:
				var v := _kort_på(Vector2(100.0 + i * 70.0, 200.0))
				_start_x.append(v.position.x)
				_kort.append(v)
			for i in _kort.size():
				(_kort[i] as CardView).glide_to(Vector2(_start_x[i] + 20.0, 200.0), 0.0,
					i * CardView.EFTERFÖLJD)		
		5:
			# KORTVALET: kortet ligger i en CONTAINER i stället för att få sin plats av handen. Pekaren
			# in ska inte flytta det en pixel: hemplatsen var (0,0), och både svikten och lyftet räknar
			# position UR home_pos — kortet for 200 px in i grannen (Alex, två gånger: "kortet flyttar
			# på sig till vänster, och täcker över det som låg där innan").
			var b := HFlowContainer.new()
			b.size = Vector2(400, 200)
			b.position = Vector2(60, 360)
			root.add_child(b)
			b.add_child(CardView.make(_db["lash"], 0, null, true))
			var v := CardView.make(_db["lash"], 1, null, true)
			b.add_child(v)
			# Läget containern ger kortet. Provets container sorterar inte om sig medan fasen mäter, så
			# talet står kvar tills rörelsen börjar — och det är det som ska stå kvar EFTERÅT.
			v.position = Vector2(96, 0)
			_starta([v], Callable(v, "set_forward").bind(true))

## Startar fasen: hemvärden sparas och rörelsen sätts igång utan await (annars stannar samplingen).
func _starta(kort: Array, anrop: Callable) -> void:
	_kort = kort
	for k in kort:
		_hemma.append((k as CardView).home_pos.y)
	anrop.call()

func _kort_på(pos: Vector2) -> CardView:
	var v := CardView.make(_db["lash"], 0, null, false)
	v.home_pos = pos
	v.home_size = CARD
	v.home_rot = 0.0
	v.size = CARD
	v.position = pos
	root.add_child(v)
	return v

	return null

## Rörelsen står still: position, storlek och skala lika i fyra bildrutor i rad.
func _stilla() -> bool:
	if _logg.size() < 6:
		return false
	var a: Dictionary = _logg[_logg.size() - 1]
	var b: Dictionary = _logg[_logg.size() - 5]
	for i in (a["k"] as Array).size():
		var ka: Dictionary = a["k"][i]
		var kb: Dictionary = b["k"][i]
		if absf(ka["x"] - kb["x"]) > 0.02 or absf(ka["y"] - kb["y"]) > 0.02 \
				or absf(ka["h"] - kb["h"]) > 0.02 \
				or absf(ka["s"] - kb["s"]) > 0.002 or absf(ka["sy"] - kb["sy"]) > 0.002 \
				or absf(ka["a"] - kb["a"]) > 0.02:
			return false
	return true

# ---------------------------------------------------------------- faser

func _avsluta_fasen() -> void:
	match _fas:
		0: _fas_svikt()
		1: _fas_återgång()
		2: _fas_spelat()
		3: _fas_utdelat()
		4: _fas_efterföljd()
		5: _fas_valkort()
	_nästa_fas()

## Kurvan och siffrorna för en fas, i en klump: tabellen först, sedan domarna.
func _fas_rubrik() -> void:
	print("  %s:" % _namn[_fas])

## Last time the value was outside the tolerance — everything after it is settled.
func _satt(vals: Array, mål: float, tol := TOL) -> float:
	var sista := 0.0
	for v in vals:
		if absf(v["v"] - mål) > tol:
			sista = v["t"]
	return sista

func _topp(vals: Array) -> Array:
	var m := -1e9
	var t := 0.0
	for v in vals:
		if v["v"] > m:
			m = v["v"]
			t = v["t"]
	return [m, t]

func _fas_svikt() -> void:
	_fas_rubrik()
	var hem: float = _hemma[0]
	var y := []
	var h := []
	var kram := []
	for rad in _logg:
		var k: Dictionary = rad["k"][0]
		y.append({"t": rad["t"], "v": k["y"] - hem})
		h.append({"t": rad["t"], "v": k["h"]})
		kram.append({"t": rad["t"], "v": CARD.y - k["h"] * k["sy"]})   # ihoppressningen i px
		print("     t %4.0f ms   y %+6.1f px   höjd %6.1f px   underkant %6.1f   kramad %4.1f px" % [
			rad["t"], k["y"] - hem, k["h"], k["y"] + k["h"], CARD.y - k["h"] * k["sy"]])
	# Efter svikten ska UNDERKANTEN stå still: kortet växer ur sin egen underkant. Räknades
	# storlek och position ur var sitt tal gled underkanten 20 px ned under raden och tillbaka
	# (mätt i en tidigare version) — kortet såg ut att sjunka genom skärmkanten.
	var hem_botten: float = hem + CARD.y
	var glid := 0.0
	for rad in _logg:
		if rad["t"] <= CardView.SVIKT_TID * 1000.0:
			continue
		var kb: Dictionary = rad["k"][0]
		glid = maxf(glid, absf(kb["y"] + kb["h"] - hem_botten))
	var djup := _topp(y)
	var topp := _topp(h)
	var kramtopp := _topp(kram)
	var mål: float = CARD.y * CardView.FORWARD
	var satt := _satt(h, mål)
	var översläng: float = topp[0] - mål
	print("     => svikt %+.1f px ned vid %.0f ms | kramad %.1f px vid %.0f ms | lyftet: topp %.1f px (mål %.0f, översläng %+.1f) vid %.0f ms | satt %.0f ms" % [
		djup[0], djup[1], kramtopp[0], kramtopp[1], topp[0], mål, översläng, topp[1], satt])
	_matt.append("svikt: %+.1f px ned + %.1f px ihop vid %.0f ms | lyftets översläng %+.1f px | satt %.0f ms | underkanten still %.1f px" % [
		djup[0], kramtopp[0], djup[1], översläng, satt, glid])
	check(djup[0] >= 1.5 and djup[0] <= 7.0, "pekaren ger en svikt ned",
		"%+.1f px (vill 2–6)" % djup[0])
	check(djup[1] >= 15.0 and djup[1] <= 130.0, "svikten är en blinkning, inte en väntan",
		"%.0f ms till botten" % djup[1])
	check(kramtopp[0] >= 1.0 and kramtopp[0] <= 8.0, "kortet ger sig: det trycks ihop under pekaren",
		"%.1f px lägre (skalan, inte rutan)" % kramtopp[0])
	check(översläng >= 1.0, "lyftet överslänger och sätter sig", "%+.1f px" % översläng)
	check(satt >= 120.0 and satt <= 400.0, "kortet har satt sig i framträtt läge",
		"%.0f ms" % satt)
	check(glid <= 2.0, "kortet växer ur sin underkant, det glider inte ned genom raden",
		"underkanten rör sig %.1f px under lyftet" % glid)

## Återgången mäts som en IHOPPRESSNING, inte som en förflyttning: underkanten står still hela
## vägen, så svikten syns i höjden — kortet trycks 4 px lägre än sin hemhöjd på vägen ned och
## sätter sig. Det är samma rörelse sedd från rätt håll.
func _fas_återgång() -> void:
	_fas_rubrik()
	var hem: float = _hemma[0]
	var h := []
	for rad in _logg:
		var k: Dictionary = rad["k"][0]
		h.append({"t": rad["t"], "v": k["h"]})
		print("     t %4.0f ms   y %+6.1f px (hem 0)   höjd %6.1f px (hem %.0f)   kramad %4.1f px" % [
			rad["t"], k["y"] - hem, k["h"], CARD.y, CARD.y - k["h"] * k["sy"]])
	var kram := []
	for rad in _logg:
		kram.append({"t": rad["t"], "v": CARD.y - rad["k"][0]["h"] * rad["k"][0]["sy"]})
	var svikt := _topp(kram)
	var satt := _satt(kram, 0.0)
	var slut: Dictionary = _logg[_logg.size() - 1]["k"][0]
	print("     => ihopklämt %.1f px (skalan) vid %.0f ms | satt %.0f ms | landar y %+.2f, höjd %+.2f från hem" % [
		svikt[0], svikt[1], satt, slut["y"] - hem, slut["h"] - CARD.y])
	_matt.append("återgång: trycks %.1f px ihop på vägen ned | satt %.0f ms" % [svikt[0], satt])
	check(svikt[0] >= 0.5 and svikt[0] <= 9.0, "kortet sviktar ned i ledet igen",
		"%.1f px ihopklämt" % svikt[0])
	check(satt >= 50.0 and satt <= 300.0, "återgången är klar", "%.0f ms" % satt)
	check(absf(slut["y"] - hem) < 0.01 and absf(slut["h"] - CARD.y) < 0.01,
		"kortet landar exakt på sin hemplats",
		"y %+.2f px, höjd %+.2f px från hem" % [slut["y"] - hem, slut["h"] - CARD.y])

func _fas_spelat() -> void:
	_fas_rubrik()
	var y0: float = _hemma[0]
	var skala := []
	var upp := []
	var alfa := []
	for rad in _logg:
		var k: Dictionary = rad["k"][0]
		skala.append({"t": rad["t"], "v": k["s"]})
		upp.append({"t": rad["t"], "v": y0 - k["y"]})
		alfa.append({"t": rad["t"], "v": k["a"]})
		print("     t %4.0f ms   skala %.3f   upp %6.1f px (mål %.0f)   alfa %.2f" % [
			rad["t"], k["s"], y0 - k["y"], CardView.FLYKT_PX, k["a"]])
	var stöt := _topp(skala)
	var flykt := _topp(upp)
	var översväng: float = flykt[0] - CardView.FLYKT_PX
	var borta := _satt(alfa, 0.0, 0.02)
	print("     => stöt %.3f vid %.0f ms | flykt %.1f px (mål %.0f, översväng %+.1f) vid %.0f ms | borta %.0f ms" % [
		stöt[0], stöt[1], flykt[0], CardView.FLYKT_PX, översväng, flykt[1], borta])
	_matt.append("spelat: stöt %.3f vid %.0f ms | flykt %.1f px (översväng %+.1f) | borta %.0f ms" % [
		stöt[0], stöt[1], flykt[0], översväng, borta])
	check(stöt[0] >= 1.05, "kortet stöter till när det spelas", "skala %.3f" % stöt[0])
	check(stöt[1] >= 10.0 and stöt[1] <= 140.0, "stöten är snabb", "%.0f ms till toppen" % stöt[1])
	check(översväng >= 1.0, "flykten far förbi sin slutpunkt och kommer tillbaka",
		"%+.1f px över målet" % översväng)
	check(borta >= 100.0 and borta <= 350.0, "kortet är ute ur handen",
		"%.0f ms" % borta)

func _fas_utdelat() -> void:
	_fas_rubrik()
	var starter := []
	var inne := []
	var djup := []
	var översläng := []
	var utanför := 0.0
	for i in _kort.size():
		var start := -1.0
		var slut := 0.0
		var minst := 1e9
		var mest := -1e9
		for rad in _logg:
			var k: Dictionary = rad["k"][i]
			if start < 0.0 and absf(k["s"] - CardView.DELA_KRYMP) > 0.003:
				start = rad["t"]
			minst = minf(minst, k["s"])
			mest = maxf(mest, k["s"])
			if absf(k["s"] - 1.0) > 0.002:
				slut = rad["t"]
		starter.append(start)
		inne.append(slut)
		djup.append((1.0 - minst) * CARD.y)
		översläng.append((mest - 1.0) * CARD.y)
	for rad in _logg:
		var delar := []
		var på_plats := 0
		for i in _kort.size():
			var k: Dictionary = rad["k"][i]
			delar.append("k%d s%.3f av %.0f" % [i, k["s"], k["h"] * k["sy"]])
			if absf(k["y"] - _hemma[i]) < 0.01:
				på_plats += 1
		# Underkanten får aldrig lämna den svarta ytan: handen ligger längst ned i fönstret, och
		# en utdelning som reste därifrån drog korten utanför kanten (mätt: 26 px nedanför).
		if på_plats < _kort.size():
			utanför += 1.0
		print("     t %4.0f ms   %s" % [rad["t"], "  ".join(delar)])
	print("     => start %.0f, %.0f, %.0f, %.0f ms | växer in från %.1f px lägre | översläng %+.1f px | på plats %.0f, %.0f, %.0f, %.0f ms" % [
		starter[0], starter[1], starter[2], starter[3], djup[0], översläng[0],
		inne[0], inne[1], inne[2], inne[3]])
	_matt.append("utdelat: start %.0f/%.0f/%.0f/%.0f ms | växer in från %.1f px lägre | översläng %+.1f px | sista på plats %.0f ms" % [
		starter[0], starter[1], starter[2], starter[3], djup[0], översläng[0], inne[3]])
	var steg: float = starter[1] - starter[0]
	check(starter[0] <= 80.0, "första kortet börjar direkt", "%.0f ms" % starter[0])
	check(steg >= 25.0 and steg <= 90.0, "korten kommer ett i taget (efterföljd)",
		"%.0f ms mellan kort 0 och 1 (DELA_STEG är %.0f ms)" % [steg, CardView.DELA_STEG * 1000.0])
	check(djup[0] >= 2.0, "kortet växer in, det bara står där inte", "%.1f px lägre vid start" % djup[0])
	check(översläng[0] >= 0.2, "kortet sätter sig med en översläng",
		"%+.1f px över hemstorleken" % översläng[0])
	check(inne[3] <= 600.0, "hela utdelningen är klar i tid", "sista kortet på plats %.0f ms" % inne[3])
	check(utanför == 0.0, "kortens underkant lämnar aldrig den svarta ytan medan de delas ut",
		"%d av %d bildrutor utanför" % [int(utanför), _logg.size()])

## Handens efterföljd: när ett kort träder fram ger raden efter — ett kort i taget, inte alla i
## samma bildruta. Fyra kort glider 20 px i sida med samma fördröjning som _rada_hand ger dem.
func _fas_efterföljd() -> void:
	_fas_rubrik()
	var start := []
	var satt := []
	var landat := 0.0
	for i in _kort.size():
		var x0: float = _start_x[i]
		var s := -1.0
		var e := 0.0
		for rad in _logg:
			var k: Dictionary = rad["k"][i]
			if absf(k["x"] - x0) > 0.5:
				if s < 0.0:
					s = rad["t"]
				e = rad["t"]
		start.append(s)
		satt.append(e)
		landat = maxf(landat, absf((_kort[i] as CardView).position.x - (x0 + 20.0)))
	for rad in _logg:
		var delar := []
		for i in _kort.size():
			delar.append("k%d x %6.1f" % [i, rad["k"][i]["x"]])
		print("     t %4.0f ms   %s" % [rad["t"], "  ".join(delar)])
	print("     => start %.0f, %.0f, %.0f, %.0f ms | satt %.0f, %.0f, %.0f, %.0f ms | kvar av målet %.2f px" % [
		start[0], start[1], start[2], start[3], satt[0], satt[1], satt[2], satt[3], landat])
	_matt.append("efterföljd: start %.0f/%.0f/%.0f/%.0f ms | satt %.0f ms | kvar av målet %.2f px" % [
		start[0], start[1], start[2], start[3], satt[3], landat])
	var minsta: float = 1e9
	for i in range(1, start.size()):
		minsta = minf(minsta, start[i] - start[i - 1])
	check(start[0] <= 25.0, "kortet närmast börjar röra sig direkt", "%.0f ms" % start[0])
	var steg_ms: float = CardView.EFTERFÖLJD * 1000.0
	check(minsta >= steg_ms * 0.55 and minsta <= steg_ms * 1.8,
		"korten följer efter varandra i tur och ordning",
		"minsta steget %.0f ms mot konstanten %.0f ms" % [minsta, steg_ms])
	check(landat <= 0.2, "varje kort landar exakt på sin plats", "%.2f px från målet" % landat)
	check(satt[3] <= 350.0, "hela efterföljden är klar i tid", "sista kortet satt %.0f ms" % satt[3])

## Valkortet: position och höjd ska stå STILLA hela fasen. Ingen svikt, inget lyft — i en rad markerar
## kanten vilket kort som är valt, och kortet är redan stort nog att visa sin egen text.
func _fas_valkort() -> void:
	_fas_rubrik()
	var x: float = _logg[0]["k"][0]["x"]
	var h: float = _logg[0]["k"][0]["h"]
	var dx := 0.0
	var dh := 0.0
	for rad in _logg:
		dx = maxf(dx, absf(rad["k"][0]["x"] - x))
		dh = maxf(dh, absf(rad["k"][0]["h"] - h))
	print("     => start x %.1f, höjd %.1f | största rörelsen %.2f px i sidled, %.2f px i höjd" % [x, h, dx, dh])
	_matt.append("valkort: x %.1f -> %.1f (%.2f px), höjd %.1f -> %.1f (%.2f px)" % [
		x, _logg[-1]["k"][0]["x"], dx, h, _logg[-1]["k"][0]["h"], dh])
	check(dx <= TOL, "valkortet rör sig inte i sidled när pekaren kommer in", "%.2f px" % dx)
	check(dh <= TOL, "och växer inte i valet", "%.2f px" % dh)

# ---------------------------------------------------------------- sammanfattning

func _sammanfatta() -> void:
	print("")
	print("— vad en rörelse gör, i siffror —")
	for rad in _matt:
		print("  %s" % rad)
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
