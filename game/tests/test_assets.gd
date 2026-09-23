## Prövar att konsten och ljudet finns OCH går att använda: varje kort i datan ska ha en 64x64-bild
## som bara använder spelets palett, och varje ljudevent en läsbar WAV. Ett trasigt asset ska falla
## här i stället för att bli en tom knapp eller ett tyst spel.
##   godot --headless --script res://tests/test_assets.gd
extends SceneTree

const SIZE := 64
## Kortikonens tillåtna mått (M78): 128 för de som klipps ur Alex' ark, 64 för de modellritade (se
## kommentaren i loopen — modellens kvot är slut och en nearest-uppskalning lägger inte till detalj).
const SIZE_OK := [64, 128]
const SFX := ["card", "hit", "crit", "coin", "step", "pick", "level_up", "descend", "death"]

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _initialize() -> void:
	var db := Cards.load_all()

	print("— paletten (samma fil som generatorn läser) —")
	var palette := {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://assets/palette.json"))
	check(raw is Array, "palette.json går att läsa")
	if raw is Array:
		for row in raw:
			palette[Vector3i(int(row[0]), int(row[1]), int(row[2]))] = true
	# Paletten växer när ett TEMA behöver en färg (jord, trä, grottblå, ben), men de 16 första
	# ligger fast: rutor, kort och figurer refererar dem med sina index, så en insättning i mitten
	# hade bytt färg på allt som redan är ritat. Provet bevakar ordningen, inte antalet.
	check(palette.size() >= 16, "paletten har minst de 16 grundfärgerna", "%d" % palette.size())
	if raw is Array and raw.size() >= 16:
		var grund := {}
		for i in 16:
			grund[Vector3i(int(raw[i][0]), int(raw[i][1]), int(raw[i][2]))] = true
		check(grund.size() == 16, "de 16 första är fortfarande 16 unika färger", "%d" % grund.size())

	print("— kortens bilder —")
	var missing := []
	var bad_size := []
	var off_palette := []
	var empty := []
	var all_colors := {}
	for id in db:
		var path := "res://assets/cards/%s.png" % id
		# KÄLLFILEN, inte bara den importerade: .godot/imported/ behåller sin .ctex när en png tas bort,
		# så ResourceLoader.exists() svarar ja på en ikon som inte finns på disken längre (mätt
		# 2026-09-20: elva borttagna ikoner passerade kontrollen och lästes ur cachen).
		if not FileAccess.file_exists(path):
			missing.append(id)
			continue
		if not ResourceLoader.exists(path):
			missing.append(id)
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			missing.append(id)
			continue
		var img := tex.get_image()
		# TVÅ STORLEKAR (M78). Kortens ikoner som KLIPPS ur Alex' ark (tools/gen_card_icons.py) är 128
		# px — konsten i 1:1, samma svar som fienderna fick i M76, och Alex' egen önskan (*"pixeltätheten
		# på korten behöver dubbleras eller mer, för de är suddiga idag"*). De MODELLRITADE ligger kvar
		# på 64: bildmodellens veckokvot är slut, och att skala upp dem med nearest lägger inte till en
		# enda detalj — bara större block. Provet godkänner båda och kräver att bilden är en av dem.
		var sida := img.get_width()
		if sida != img.get_height() or not SIZE_OK.has(sida):
			bad_size.append("%s %dx%d" % [id, img.get_width(), img.get_height()])
			continue
		var seen := {}
		var opaque := 0
		for y in sida:
			for x in sida:
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				opaque += 1
				seen[Vector3i(roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0))] = true
		for key in seen:
			all_colors[key] = true
			if not palette.has(key):
				off_palette.append(id)
				break
		if opaque < sida * sida / 20:
			empty.append(id)
	check(missing.is_empty(), "varje kort har en bild", "%d kort, saknas: %s" % [db.size(), str(missing)])

	# En felstavad effekt-op dör tyst i striden (push_error i loggen och ingenting händer på
	# skärmen). Här jämförs datat mot motorns egen lista, så ett stavfel blir ett rött prov.
	var okanda := []
	var ops := {}
	for id in db:
		for e in db[id].effects:
			var op := str(e.get("op", ""))
			if not Combat.OPS.has(op):
				okanda.append("%s:%s" % [id, op])
			ops[op] = true
	check(okanda.is_empty(), "alla effekt-op finns i motorn",
		"%d olika op i datat, okanda: %s" % [ops.size(), str(okanda)])
	check(ops.size() == Combat.OPS.size(), "och motorn har inga oanvända op",
		"%d i motorn, %d i bruk" % [Combat.OPS.size(), ops.size()])
	print("— fiendernas bilder —")
	# Samma krav som korten: egen pixelkonst, och sex rutor i en rad på en DUK som är lika stor för alla
	# fiender. Duken växte till 120 px i M76: Alex' ark har 2-8 källpixlar per konstpixel, och 40-duken
	# skalade ned hans figurer 2-3 gånger — det var suddigheten (Alex: *"Fiendens pixeltäthet behöver
	# dubbleras eller ännu mer"*). 120 px är konsten i 1:1, och pixel_size i main.gd är räknad i METER
	# så att figurerna är exakt lika stora som förut. Att rutorna SKILJER sig mäts i
	# tools/gen_enemy_art.py --check, som testkörningen kör.
	# ALFAN prövas också: bilderna var RGB en gång, och då blev varje fiende en opak svart ruta i
	# korridoren — en fiende som inte syns är ett fel som måtten ensamma inte fångar.
	# Alex' egna tio (tools/gen_enemy_sheet.py): se undantaget i palettkontrollen nedan.
	const ALEX_EGNA := ["skitterling", "candlewisp", "salt_wretch", "glass_herald", "chime_swarm",
		"hollow_choir", "verdigris", "ash_maw", "bell_drowned", "bellmother",
		# ... och de sju han ritade om 22 sep 2026 (tools/gen_enemy_new.py klipper dem ur hans nya
		# monsterark). Samma regel som för de tio: bilden äger utseendet, palettkravet gäller den
		# konst generatorn ritar.
		"copper_warden", "ossuary_king", "ash_sovereign", "mire_hound",
		"bone_wretch", "wax_sentinel", "pale_reaper"]
	var best := Enemies.load_all()
	var utan_bild := []
	var fel_matt := []
	var utan_alfa := []
	var utanfor_palett := []
	var över_taket := []
	# Taket läses ur SPELET (main.gd), inte ur ett eget tal: flyttas rummet följer provet med.
	var tak: float = preload("res://main.gd").TAK_HÖJD
	for id in best:
		var path := "res://assets/enemies/%s.png" % id
		if not ResourceLoader.exists(path):
			utan_bild.append(id)
			continue
		var tex := load(path) as Texture2D
		var img := tex.get_image() if tex != null else null
		if img == null or img.get_width() != 720 or img.get_height() != 120:
			fel_matt.append("%s %sx%s" % [id, img.get_width() if img else 0, img.get_height() if img else 0])
			continue
		# FIGUREN SKA RYMMAS UNDER TAKET (M48). Alex: *"Höj taket, det är för lågt för fienden, de
		# tar i taket."* Höjden räknas ur KONSTEN, inte ur en gissning: den översta raden med färg
		# mot golvraden 100, gånger pixel_size. Bossarnas skala (0,013) är den värsta — en fiende som
		# ryms som vanlig men inte som boss sticker huvudet genom taket i bossrummet.
		var topp := 120
		for y in 120:
			var funnen := false
			for x in 720:
				if img.get_pixel(x, y).a > 0.5:
					topp = y
					funnen = true
					break
			if funnen:
				break
		if topp < 120:
			var höjd: float = float(100 - topp) * 0.013
			if höjd > tak:
				över_taket.append("%s %.2f m över %.2f" % [id, höjd, tak])
		# Hörnen ska vara genomskinliga: figuren klipps in i vyn, den ligger inte i en ruta.
		var hörn := [img.get_pixel(0, 0), img.get_pixel(719, 0), img.get_pixel(0, 119), img.get_pixel(719, 119)]
		for c in hörn:
			if c.a > 0.05:
				utan_alfa.append(id)
				break
		for y in 120:
			for x in 720:
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				# DE TIO ALEX RITADE (tools/gen_enemy_sheet.py) går fria från palettkravet: deras
				# färger är hans, och att tvinga in dem i spelets 16 färger vore att rita om hans konst
				# (hans regel: bilden äger utseendet). Mått, genomskinliga hörn och alfakravet nedan
				# gäller dem som alla andra, och deras eget prov mäter rutor och fötter.
				if not palette.has(Vector3i(roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0))):
					if id in ALEX_EGNA:
						continue
					utanfor_palett.append(id)
					break
			if utanfor_palett.has(id):
				break
	check(utan_bild.is_empty(), "varje fiende har en bild", "%d fiender, saknas: %s" % [best.size(), str(utan_bild)])
	check(fel_matt.is_empty(), "fiendebilderna är 720x120 (sex rutor, 120 px duk)", str(fel_matt))
	check(utan_alfa.is_empty(), "fiendebilderna har genomskinlig bakgrund", str(utan_alfa))
	check(utanfor_palett.is_empty(), "fiendebilderna använder palettens färger", str(utanfor_palett))
	check(över_taket.is_empty(), "ingen fiende är högre än taket (inte ens som boss)", str(över_taket))

	## Rekvisiten (tools/gen_props.py): kistan, spaden och benen. Provet mäter att de FINNS — annars
	## faller spelet tyst tillbaka på den gamla rutmarkören, och det var den Alex inte kände igen.
	var props_saknas := []
	for namn in ["chest", "shovel", "boss"]:
		if not ResourceLoader.exists("res://assets/props/%s.png" % namn):
			props_saknas.append(namn)
	check(props_saknas.is_empty(), "rekvisiten finns (kista, spade, ben)", str(props_saknas))

	check(bad_size.is_empty(), "bilderna är 64x64 eller 128x128", str(bad_size))
	check(off_palette.is_empty(), "bilderna använder bara palettens färger", "utanför: %s" % str(off_palette))
	check(empty.is_empty(), "ingen bild är i praktiken tom", str(empty))
	## Taket är palettens storlek, inte 16: paletten växer när ett tema behöver en färg (rutor och
	## fiender använder dem redan) och generatorn kvantiserar mot SAMMA fil som provet läser.
	check(all_colors.size() <= palette.size(), "högst lika många färger som paletten", str(all_colors.size()) + " av " + str(palette.size()))

	print("— ljuden —")
	var missing_sfx := []
	var broken_sfx := []
	for name in SFX:
		var path := "res://assets/sfx/%s.wav" % name
		if not ResourceLoader.exists(path):
			missing_sfx.append(name)
			continue
		var stream := load(path)
		if stream == null or not (stream is AudioStream):
			broken_sfx.append(name)
	check(missing_sfx.is_empty(), "alla ljudevent har en fil", "%d ljud, saknas: %s" % [SFX.size(), str(missing_sfx)])
	check(broken_sfx.is_empty(), "ljudfilerna går att spela upp i Godot", str(broken_sfx))

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
