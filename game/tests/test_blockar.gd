## Blocken (M153): Alex ritar små bitar i editorn, generatorn lägger in dem i rum som har plats.
##
## Provet mäter fyra saker som var för sig kan gå tyst fel:
##  1. filerna läses (och en rad som är olika lång vägras i stället för att ge en sned stämpel),
##  2. rotationen vrider rutorna OCH noderna/rekvisitan (annars hamnar kistan i väggen),
##  3. stämpeln skriver in väggar i rummet och sätter sina objekt på golv,
##  4. våningen går fortfarande att spela: rumsmitten är golv (start/boss står där) och varje nod nås
##     — det är den kontrollen som betyder något, för ett block som stänger våningen ser fint ut i filen.
##
##   tools/ett_prov.sh tests/test_blockar.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, vad: String) -> void:
	checks += 1
	if ok:
		print("  ok   %s" % vad)
	else:
		fails += 1
		print("  FEL  %s" % vad)


func _tom(w: int, h: int) -> Dungeon.Floor:
	var f := Dungeon.Floor.new()
	f.stage_id = "stage_01"
	f.index = 0
	f.w = w
	f.h = h
	f.tiles = []
	for y in h:
		var rad := []
		for x in w:
			rad.append(Dungeon.WALL)
		f.tiles.append(rad)
	return f


func _init() -> void:
	# 1. Filerna
	var block := Blockar.ladda_alla()
	check(block.size() >= 3, "blocken i data/blocks läses (%d st)" % block.size())
	for b in block:
		var rader: Array = b["tiles"]
		var jämna := true
		for r in rader:
			if str(r).length() != int(b["w"]):
				jämna = false
		check(jämna and rader.size() == int(b["h"]),
			"%s: %d×%d och alla rader lika långa" % [b["id"], b["w"], b["h"]])
		check(not b.has("nodes"), "%s bär inga noder (mekaniken ägs av generatorn)" % b["id"])

	# 2. Rotationen: fyra varv är tillbaka, ett varv är en annan bild, och punkterna följer med.
	var krypta: Dictionary = {}
	for b in block:
		if str(b["id"]) == "krypta":
			krypta = b
	check(not krypta.is_empty(), "krypta finns bland blocken")
	if not krypta.is_empty():
		var noll: Dictionary = Blockar.rotera(krypta, 0)
		var fyra: Dictionary = Blockar.rotera(krypta, 4)
		check(fyra["tiles"] == noll["tiles"], "fyra varv ger tillbaka samma rutor")
		var ett: Dictionary = Blockar.rotera(krypta, 1)
		check(ett["tiles"] != noll["tiles"], "ett varv är en annan bild")
		check(int(ett["w"]) == int(krypta["h"]) and int(ett["h"]) == int(krypta["w"]),
			"mätten byter plats (%d×%d -> %d×%d)" % [krypta["w"], krypta["h"], ett["w"], ett["h"]])
		var kista_före: Vector2i = krypta["rekvisita"][0]["pos"]
		var kista_efter: Vector2i = ett["rekvisita"][0]["pos"]
		check(kista_efter == Vector2i(int(krypta["h"]) - 1 - kista_före.y, kista_före.x),
			"rekvisitan flyttar med rotationen (%s -> %s)" % [kista_före, kista_efter])
		# och den ligger på golv i den vridna rutan
		var på_golv := str(ett["tiles"][kista_efter.y])[kista_efter.x] == "."
		check(på_golv, "och hamnar på en golvruta i den vridna bilden")

	# 3. Passar / passar inte
	var litet := Rect2i(0, 0, 2, 2)
	var stort := Rect2i(0, 0, 13, 9)
	check(not Blockar.passar(krypta, litet), "krypta (7×5) ryms inte i ett 2×2-rum")
	check(Blockar.passar(krypta, stort), "men i ett 13×9-rum")

	# 4. Stämpeln: ett rum som redan är golv får blockets väggar, och objekt bara på golv.
	var rum := Rect2i(1, 1, 7, 7)
	var f := _tom(10, 10)
	for y in range(1, 10):
		for x in range(1, 10):
			f.tiles[y][x] = Dungeon.FLOOR
	var pelare: Dictionary = {}
	for b in block:
		if str(b["id"]) == "pelarsal":
			pelare = b
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ut: Dictionary = Blockar.stämpla(f, pelare, rum, 0)
	check(not ut.is_empty(), "pelarsalen stämplades in (%s @ %s)" % [ut.get("id", "-"), ut.get("pos", "-")])
	var väggar_inuti := 0
	for y in range(1, 10):
		for x in range(1, 10):
			if not f.is_floor_at(Vector2i(x, y)):
				väggar_inuti += 1
	check(väggar_inuti > 0, "den satte väggar INUTI rummet (%d rutor)" % väggar_inuti)
	var prylar := 0
	var utanför := 0
	for r in f.rekvisita:
		var p: Vector2i = r["pos"]
		if f.is_floor_at(p):
			prylar += 1
		else:
			utanför += 1
	check(utanför == 0, "ingen rekvisit hamnade i en vägg (%d på golv, %d utanför)" % [prylar, utanför])
	check(prylar > 0, "blockets rekvisita kom med (%d st)" % prylar)

	# 4b. STORLEKEN BESTÄMMER ALEX (M154): ett block får vara större än rummet, och då växer rummet ut i
	# berget. Bara i berg — en ruta som redan är golv (ett annat rum) får inte tas.
	var lång: Dictionary = {}
	for b in block:
		if int(b["w"]) >= 9:
			lång = b
	check(not lång.is_empty(), "det finns ett block som är bredare än 9 (långsal)")
	if not lång.is_empty():
		var r2 := _tom(22, 22)
		for y in range(4, 9):
			for x in range(4, 9):
				r2.tiles[y][x] = Dungeon.FLOOR
		var yta: Rect2i = Blockar.plats(r2, Rect2i(4, 4, 5, 5), lång)
		check(yta.size.x >= int(lång["w"]) and yta.size.y >= int(lång["h"]),
			"rummet växte så 9x3-blocket ryms (%d×%d)" % [yta.size.x, yta.size.y])
		check(r2.is_floor_at(Vector2i(yta.position.x, yta.position.y)),
			"och det nya området blev golv")
		# Granne: ett annat rum ligger där blocket skulle växa — då vägrar den i stället för att slå
		# ihop två rum.
		var r3 := _tom(22, 22)
		for y in range(4, 9):
			for x in range(4, 9):
				r3.tiles[y][x] = Dungeon.FLOOR
		for y in range(4, 9):
			for x in range(9, 16):
				r3.tiles[y][x] = Dungeon.FLOOR      # rummet intill
		var nära: Rect2i = Blockar.plats(r3, Rect2i(4, 4, 5, 5), lång)
		var krock := nära.size.x > 0 and nära.end.x > 9
		check(not krock, "den tar inte mark som redan är ett annat rum")

	# 5. Våningen: 12 frön på svårighet 3 ska gå att spela, och blocken ska synas i rummen.
	var stages := Stages.load_all()
	var stage = stages["stage_01"]
	var bestiary := Enemies.load_all()
	var med_block := 0
	var med_stort := 0
	var osammanhängande := 0
	var mitt_i_vägg := 0
	var olika_frön := {}
	for i in 12:
		var frö := 1000 + i * 7
		var våning: Dungeon.Floor = Dungeon.generate(stage, 1, frö, bestiary)
		if våning == null:
			check(false, "våning %d gick inte att bygga" % frö)
			continue
		if våning.blockar.size() > 0:
			med_block += 1
		for b in våning.blockar:
			if b["id"] == "långsal":
				med_stort += 1
		for n in Dungeon.unreachable_nodes(våning):
			osammanhängande += 1
		for r in våning.rum:
			var c: Vector2i = Dungeon._center(r)
			if not våning.is_floor_at(c):
				mitt_i_vägg += 1
		olika_frön[våning.checksum()] = true
		var igen: Dungeon.Floor = Dungeon.generate(stage, 1, frö, bestiary)
		if igen == null or igen.checksum() != våning.checksum():
			check(false, "samma frö %d gav inte samma våning" % frö)
			continue
	check(osammanhängande == 0, "alla noder nås på alla 12 våningar (%d oåtkomliga)" % osammanhängande)
	check(mitt_i_vägg == 0, "rumsmitten är golv på alla 12 våningar (%d i vägg)" % mitt_i_vägg)
	check(olika_frön.size() == 12, "12 frön ger 12 olika våningar (%d unika)" % olika_frön.size())
	check(med_block >= 6, "blocken används (%d av 12 våningar fick minst ett)" % med_block)
	check(med_stort > 0, "det 9 rutor breda blocket fick plats (%d gånger)" % med_stort)

	# 6. Rutnätets textform: ett block som sparas från editorn måste gå att läsa tillbaka. Samma
	#    kontroll som för kartan — skrivs fältet men läses inte, ser filen rätt ut och spelet ignorerar den.
	var prov := _tom(7, 7)
	for y in range(1, 6):
		for x in range(1, 6):
			prov.tiles[y][x] = Dungeon.FLOOR
	prov.rekvisita = [{"art": "trälåda", "pos": Vector2i(2, 2)}]
	prov.nodes = []
	var d: Dictionary = MapIo.to_dict(prov)
	var rader: Array = d["tiles"]
	var text_ok := true
	for r in rader:
		if typeof(r) != TYPE_STRING:
			text_ok = false
	check(text_ok, "rutnätet skrivs som textrader (samma form som blocken läser)")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
