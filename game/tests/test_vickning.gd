extends SceneTree
## Prov för VICKNINGEN (idle-rörelsen): att figuren rör sig lite, att två figurer inte rör sig i takt,
## att fasen kan FRYSAS så ett bildprov blir byte-identiskt — och att en död och en träffad kropp står
## still.
##
## Körs: DISPLAY=:99 godot --headless --path game --script res://tests/test_vickning.gd
##
## Provet ritar ingenting, men det kör `main.gd`s EGEN `_process` på en main som aldrig läggs i trädet.
## Det är samma väg spelet går — regeln om döda och träffade kroppar bor i den funktionen — utan att
## bygga en våning. Ett prov som mätte en KOPIA av regeln hade varit nöjd med en kopia som var fel.
##
## Kameran ligger i TRÄDET med flit: `global_transform` på en nod utanför trädet svarar identiteten i
## ett debugbygge, och då hade kamera-vinkeln (M66) varit omätbar.

const PX := 0.012                    ## figurens pixel_size: samma som `_add_enemies` ger en vanlig fiende
const FASER := [0.0, 0.5]            ## de två faserna som jämförs
const TOPP := PI * 0.5               ## den fas där sinusen står i sin topp (sin(t * 1,0) = 1)
const DT := 1.0 / 60.0

var fel := 0
var kontroller := 0
var _main: Node
var _rot: Node3D                     ## i trädet, bär kameran
var _kam: Camera3D


func check(villkor: bool, vad: String, detalj: String = "") -> void:
	kontroller += 1
	if villkor:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fel += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


## En låtsasfiende: en Sprite3D i `main.world` med samma nycklar som `_add_enemies` ger den.
func _figur(x: float, eid: String, fas: float, klass_namn := "") -> Dictionary:
	var spr := Sprite3D.new()
	spr.hframes = _main.ENEMY_FRAMES
	spr.pixel_size = PX
	spr.position = Vector3(x + 0.5, 0.48, 3.5)
	_main.world.add_child(spr)
	var e := {"spr": spr, "bas": spr.position, "vick":
		klass_namn if not klass_namn.is_empty() else Vickning.klass(eid),
		"fas": fas, "hp": -1.0, "läge": -1, "läge_t": 0.0, "nod": Vector2i.ZERO}
	_main._enemies.append(e)
	return e


func _avstånd(e: Dictionary) -> Vector3:
	return (e["spr"] as Sprite3D).position - (e["bas"] as Vector3)


func _mm(v: float) -> float:
	return v * 1000.0


## Rörelsen i bildpunkter: samma omräkning som `_figurprov` gör (meter / pixel_size).
func _px(v: float) -> float:
	return v / PX


## Provet körs i `_process` och inte i `_initialize`: när `_initialize` anropas har trädet inte
## kopplats in än (`SceneTree.initialize` sätter `root` i trädet EFTER MainLoop.initialize), och
## `global_transform` på en nod utanför trädet svarar identiteten i ett debugbygge. Kameran vore alltså
## osynlig för provet. Returnerar true = körningen är klar.
func _process(_delta: float) -> bool:
	_main = load("res://main.gd").new()
	_main.world = Node3D.new()
	_main.add_child(_main.world)
	_rot = Node3D.new()
	root.add_child(_rot)
	_kam = Camera3D.new()
	_rot.add_child(_kam)
	_main.cam = _kam

	print("— vickningen: smårörelser, faser och fasfrysning —")

	# 1) TABELLEN. Varje fiende i bestiariet har en rörelse, och varje rörelse finns i TYPER — en ny
	#    fiende ska tvinga fram ett val i stället för att tyst ärva en andning.
	var best: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/enemies/00_bestiary.json"))
	var utan: Array = []
	for rad in best:
		if not Vickning.KLASS.has(str(rad["id"])):
			utan.append(str(rad["id"]))
	check(best.size() == 17 and utan.is_empty(), "varje fiende i bestiariet har en rörelse",
		"%d fiender, saknas: %s" % [best.size(), "ingen" if utan.is_empty() else ", ".join(utan)])
	var okända: Array = []
	for eid in Vickning.KLASS:
		if not Vickning.TYPER.has(Vickning.KLASS[eid]):
			okända.append(eid)
	check(okända.is_empty(), "och varje typ i tabellen finns i TYPER",
		"typer: %s" % ", ".join(Vickning.TYPER.keys()))
	check(Vickning.klass("finns_inte_som_fiende") == Vickning.STANDARD,
		"och en fiende utan rad får STANDARD i stället för ett fel", Vickning.STANDARD)

	# 2) AMPLITUDERNA. Ordningen är poängen: anden gungar MEST, benet andas nästan ingenting, krypet
	#    trycker i höjd.
	var g := _figur(0.0, "candlewisp", 0.0)
	var sk := _figur(4.0, "bone_wretch", 0.0)
	var sl := _figur(8.0, "mire_hound", 0.0)
	var stilla := _figur(12.0, "kista", 0.0, "stilla")
	var gh: Dictionary = Vickning.TYPER["svävande"]
	var bh: Dictionary = Vickning.TYPER["fast"]
	var sh: Dictionary = Vickning.TYPER["kryp"]
	print("  amplituder: svävande %s mm, fast %s mm, kryp %s mm, stilla 0 mm"
		% [sn("%.1f" % _mm(float(gh["amplitud"]))), sn("%.1f" % _mm(float(bh["amplitud"]))),
			sn("%.1f" % _mm(float(sh["amplitud"])))])
	check(float(gh["amplitud"]) > float(bh["amplitud"]) * 3.0,
		"anden gungar mycket mer än benet andas",
		"%s mm mot %s mm" % [sn("%.1f" % _mm(float(gh["amplitud"]))), sn("%.1f" % _mm(float(bh["amplitud"])))])
	check(float(bh["amplitud"]) > 0.0 and float(bh["amplitud"]) <= 0.02,
		"benet andas men nästan omärkligt", "%s mm" % sn("%.1f" % _mm(float(bh["amplitud"]))))
	check(is_zero_approx(float(sh["axel"].x)) and float(sh["amplitud"]) > 0.0,
		"krypet trycker i HÖJD (ingen sidled)", "axel %s" % str(sh["axel"]))

	# 3) "STILLA" ÄR EXAKT. Ingen sinus, ingen avrundning — annars vandrar en rekvisit sakta iväg.
	for i in 20:
		Vickning.steg(stilla["spr"], stilla["bas"], float(i) * 0.37, "stilla", 1.234, _kam)
	check(_avstånd(stilla).length() == 0.0, "en stilla-typ står på millimetern rätt",
		"avvikelse %.6f m över 20 olika tider" % _avstånd(stilla).length())

	# 4) FASERNA. Samma figur, samma klocka, två faser: den ska stå olika. Det är mätningen som säger
	#    att rörelsen FINNS — och siffrorna rapporten hänvisar till.
	print("  fasförskjutningen (samma figur, samma t, två faser):")
	var olika := 0
	for rad in [["candlewisp", g], ["bone_wretch", sk], ["mire_hound", sl]]:
		var e: Dictionary = rad[1]
		Vickning.steg(e["spr"], e["bas"], 0.0, Vickning.klass(str(rad[0])), FASER[0], _kam)
		var a := _avstånd(e)
		Vickning.steg(e["spr"], e["bas"], 0.0, Vickning.klass(str(rad[0])), FASER[1], _kam)
		var b := _avstånd(e)
		var d := (b - a).length()
		print("    %-11s fas 0,0 → %s mm (%s px), fas 0,5 → %s mm (%s px), skillnad %s mm"
			% [str(rad[0]), sn("%.2f" % _mm(a.length())), sn("%.2f" % _px(a.length())),
				sn("%.2f" % _mm(b.length())), sn("%.2f" % _px(b.length())), sn("%.2f" % _mm(d))])
		if str(rad[0]) == "candlewisp":
			check(d > 0.02, "spöket står tydligt olika vid fas 0,0 och 0,5",
				"skillnad %s mm" % sn("%.1f" % _mm(d)))
			# Riktningen mäts i sinusens TOPP (t = π/2), där förskjutningen är som störst.
			Vickning.steg(e["spr"], e["bas"], TOPP, "svävande", 0.0, _kam)
			var topp := _avstånd(e)
			check(absf(topp.x) > absf(topp.y) * 1.5, "och gungningen ligger i SIDLED (M66-kravet)",
				"i toppen: x %s mm mot y %s mm" % [sn("%.2f" % _mm(topp.x)), sn("%.2f" % _mm(topp.y))])
		if str(rad[0]) == "bone_wretch":
			check(d < 0.025, "men skelettet rör sig knappt mellan samma faser",
				"skillnad %s mm" % sn("%.1f" % _mm(d)))
		if d > 0.0001:
			olika += 1
	check(olika == 3, "och alla tre typerna skiljer fas 0,0 från 0,5", "%d av 3" % olika)

	# 5) FASFRYSNINGEN. Klockan står still i den frysta fasen, och två mätningar ger SAMMA tal — samma
	#    sak som gör att två provkörningar ger samma bild (md5 på PNG:n, se rapporten).
	check(is_equal_approx(Vickning.delta(DT), DT), "levande klocka ger fladdret sin bildrutetid",
		"%.4f" % Vickning.delta(DT))
	Vickning.frusen_fas = 0.7
	check(Vickning.delta(DT) == 0.0,
		"och NOLL när fasen är fryst — elden och lyktan står still med figurerna", "0,0000")
	check(is_equal_approx(Vickning.nu(), 0.7), "fryst fas: klockan svarar exakt fasen",
		"nu() = %s" % sn("%.4f" % Vickning.nu()))
	var text1 := _figurbild()
	OS.delay_msec(5)                     # riktig tid går — det ska inte spela någon roll
	var text2 := _figurbild()
	Vickning.frusen_fas = NAN
	check(text1 == text2, "två mätningar i samma frysta fas är byte-identiska",
		"sha256 %s…" % text1.sha256_text().substr(0, 16))
	print("    fryst fas 0,7: %s" % text1)
	var text3 := _figurbild()
	check(text3 != text1, "utan frysning är de olika (klockan lever)",
		"sha256 %s…" % text3.sha256_text().substr(0, 16))
	var före := Vickning.nu()
	OS.delay_msec(4)
	check(Vickning.nu() > före, "och den levande klockan går framåt med riktig tid",
		"%s ms" % sn("%.1f" % _mm(Vickning.nu() - före)))

	# 6) KAMERAN (M66). Gungningen ligger i kamerans sidled, inte i världens x: vrider spelaren kameran
	#    90 grader följer rörelsen med, med SAMMA längd. En vickning i världens x hade försvunnit helt
	#    när spelaren kom längs x — samma fälla som en gång satte figurerna "på sidan".
	#    Mäts i sinusens topp (t = π/2, fas 0): där är förskjutningen som störst.
	_rot.rotation.y = 0.0
	Vickning.steg(g["spr"], g["bas"], TOPP, "svävande", 0.0, _kam)
	var rak := _avstånd(g)
	_rot.rotation.y = PI * 0.5
	Vickning.steg(g["spr"], g["bas"], TOPP, "svävande", 0.0, _kam)
	var vriden := _avstånd(g)
	_rot.rotation.y = 0.0
	check(absf(rak.x) > 0.04 and absf(rak.z) < 0.01, "kameran norrut: gungningen går i x",
		"x %+.3f m, z %+.3f m" % [rak.x, rak.z])
	check(absf(vriden.z) > 0.04 and absf(vriden.x) < 0.01, "kameran österut: samma gungning går i z",
		"x %+.3f m, z %+.3f m" % [vriden.x, vriden.z])
	check(absf(rak.length() - vriden.length()) < 0.0005,
		"och längden är densamma (en vridning, inte mer rörelse)",
		"%s mm mot %s mm" % [sn("%.2f" % _mm(rak.length())), sn("%.2f" % _mm(vriden.length()))])

	# 7) DÖD OCH TRÄFFAD. Regeln bor i `main._process`, så den mäts genom att köra den.
	for e in [g, sk, sl, stilla]:
		e["spr"].position = e["bas"]
	var levande := _figur(16.0, "candlewisp", 0.0)
	Vickning.frusen_fas = FASER[0]
	_main._process(DT)
	var vid_noll := _avstånd(levande)
	Vickning.frusen_fas = FASER[1]
	_main._process(DT)
	var vid_hälften := _avstånd(levande)
	check((vid_hälften - vid_noll).length() > 0.02, "en levande figur flyttas av _process",
		"%s mm mellan fas 0,0 och 0,5" % sn("%.1f" % _mm((vid_hälften - vid_noll).length())))
	var träffad := _figur(20.0, "candlewisp", 0.0)
	träffad["läge"] = _main.ENEMY_HIT
	träffad["läge_t"] = 0.35
	var före_hit: Vector3 = träffad["spr"].position
	for i in 5:
		Vickning.frusen_fas = float(i) * 0.2
		_main._process(DT)
	check(träffad["spr"].position == före_hit, "en träffad kropp står still under träffrutan",
		"rörde sig %.4f m över 5 bildrutor" % (träffad["spr"].position - före_hit).length())
	var död := _figur(24.0, "candlewisp", 0.0)
	Vickning.frusen_fas = FASER[0]
	_main._process(DT)
	var före_död: Vector3 = död["spr"].position
	död["läge"] = _main.ENEMY_DEAD
	död["läge_t"] = 9999.0
	for i in 30:
		Vickning.frusen_fas = float(i) * 0.1        # 30 olika faser: ingen av dem får röra kroppen
		_main._process(DT)
	check(död["spr"].position == före_död, "och en död kropp rör sig inte i någon fas",
		"rörde sig %.4f m över 30 bildrutor" % (död["spr"].position - före_död).length())

	# 8) KOSTNADEN. Ingen ny nod och ingen ny mesh per bildruta — antalet noder är detsamma efter 100
	#    bildrutor — och en sinus per figur. Tiden mäts över 1000 bildrutor med alla figurer i samma
	#    `_process`, alltså den verkliga svansen och inte en gissning.
	var noder_före := _räkna(_main.world)
	for i in 100:
		Vickning.frusen_fas = float(i) * 0.01
		_main._process(DT)
	check(_räkna(_main.world) == noder_före, "vickningen skapar ingenting per bildruta",
		"%d noder kvar efter 100 bildrutor" % _räkna(_main.world))
	Vickning.frusen_fas = 0.0
	var antal: int = _main._enemies.size()
	# (a) HELA `_process` med alla figurer: siffran spelaren betalar per bildruta.
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		_main._process(DT)
	var per_bildruta := float(Time.get_ticks_usec() - t0) / 1000.0     # µs per bildruta
	# (b) BARA vickningen, mätt rakt på funktionen över 20 000 varv — så sinusens egen kostnad står
	#     för sig och inte göms i resten av `_process`.
	var varv := 20000
	var t1 := Time.get_ticks_usec()
	for i in varv:
		for e in _main._enemies:
			Vickning.steg(e["spr"], e["bas"], 0.0, str(e["vick"]), float(e["fas"]), _kam)
	var ns_figur := float(Time.get_ticks_usec() - t1) * 1000.0 / float(varv * antal)
	print("  kostnaden: %d figurer i samma _process, %s µs per bildruta — vickningen själv %s ns per figur och bildruta"
		% [antal, sn("%.2f" % per_bildruta), sn("%.0f" % ns_figur)])
	check(per_bildruta < 100.0, "hela svansen av figurer kostar under 100 µs per bildruta",
		"%s µs för %d figurer" % [sn("%.2f" % per_bildruta), antal])
	check(ns_figur < 2000.0, "och vickningen själv under 2 µs per figur",
		"%s ns per figur" % sn("%.0f" % ns_figur))
	Vickning.frusen_fas = NAN

	print("= %d kontroller, %d fel" % [kontroller, fel])
	_main.free()
	quit(1 if fel > 0 else 0)
	return true


## Figurens avstånd från viloläget för ALLA figurer, som text — två körningar i samma frysta fas ska ge
## samma text. Det är samma sak som en bildhash, men utan att rita något.
func _figurbild() -> String:
	var bitar: Array = []
	for e in _main._enemies:
		Vickning.steg(e["spr"], e["bas"], Vickning.nu(), str(e["vick"]), float(e["fas"]), _kam)
		var a: Vector3 = (e["spr"] as Node3D).position - (e["bas"] as Vector3)
		bitar.append("%+.6f,%+.6f,%+.6f" % [a.x, a.y, a.z])
	return ";".join(bitar)


func _räkna(n: Node) -> int:
	var antal := 1
	for c in n.get_children():
		antal += _räkna(c)
	return antal


## Decimaltecknet: siffrorna skrivs med komma i rapporten, men koden räknar med punkt.
func sn(s: String) -> String:
	return s.replace(".", ",")
