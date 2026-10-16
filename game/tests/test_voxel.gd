extends SceneTree
## Prov för CELLTÄTHETEN i voxelmodellerna (M116).
##
## Alex 12/10: *"Öka grafiken på alla objekt med, dubblera om det behövs"* — föremålen ser grovhuggna ut,
## och det som styr hur fin en modell är hur många CELLER varje källpixel blir (`Voxel.ur_ark`, ratten
## `Voxel.DETALJ`). Provet bygger därför EN modell av varje slag spelet faktiskt gör — fiende, kista,
## spade, boss, markdekor och rekvisit — genom spelets EGEN väg, och mäter:
##
##   * celler per KÄLLPIXEL (tätheten: under 1,0 tappar modellen källkonstens detalj),
##   * celler och trianglar per modell,
##   * byggtiden, och summan för de modeller en VÅNINGSSTART bygger.
##
## Summan är den siffra som avgör om en dubblering håller: antalet modeller per våning är FIXT (en per
## ART — MultiMesen delar meshen mellan våningens alla instanser), så byggtiden skalar med arterna och
## inte med instanserna. Fienderna byggs vid STRIDENS start och räknas för sig.
##
## Körs: godot --headless --path game --script res://tests/test_voxel.gd

## Taket för en våningsstart: 10 modeller (kista, spade, boss, 4 markdekor, 3 rekvisiter) mättes till
## 64 028 celler och 143 568 trianglar med `DETALJ` 2. Taket ligger en bit över, så provet fångar en
## explosion (en ratt upp till 4 ger fyra gånger cellerna) utan att vara känsligt för en enstaka art.
const TAK_CELLER := 100000
const TAK_TRIANGULAR := 250000
## Och per fiende: den tyngsta modellen (pale_reaper, 74x65 px) mättes till 23 820 celler och 52 608
## trianglar. En fiende byggs vid stridens start, medan bildrutan väntar.
const TAK_FIENDE_CELLER := 35000
const TAK_FIENDE_TRIANGULAR := 80000

var fel := 0
var kontroller := 0


func check(villkor: bool, vad: String) -> void:
	kontroller += 1
	if not villkor:
		fel += 1
		print("  FEL: %s" % vad)


## En byggd modell, mätt. `per_px` är tätheten i HÖJLED (i sidled ska den vara densamma — cellen är
## kvadratisk, se `ur_ark`).
func _mät(namn: String, vx: Voxel, ms: float) -> Dictionary:
	var bh: float = vx.ruta.size.y
	var bw: float = vx.ruta.size.x
	var per_px := float(vx.sidor) / maxf(1.0, bh)
	var per_px_x := float(vx.kolumner) / maxf(1.0, bw)
	var cell_mm := 1000.0 * (vx.höjd / float(vx.sidor))
	print("  %-14s figur %3.0fx%-3.0f px, %3d x %-3d celler, %5d celler, %6d trianglar, %5.1f ms  (%.2f celler/källpixel i höjd, %.2f i sidled, cellen %.2f mm)"
		% [namn, bw, bh, vx.kolumner, vx.sidor, vx.antal_celler(), vx.antal_ytor(), ms, per_px, per_px_x, cell_mm])
	return {"namn": namn, "vx": vx, "ms": ms, "celler": vx.antal_celler(), "tri": vx.antal_ytor(),
		"per_px": per_px, "per_px_x": per_px_x}


func _init() -> void:
	var main: Node = load("res://main.gd").new()
	main.world = Node3D.new()
	main.add_child(main.world)
	var fiender: Array = []
	var våning: Array = []

	# 1) FIENDerna: arken i assets/enemies, byggda genom `_klä_voxel` — exakt den väg `_voxel_fiende`
	#    tar (samma funktion, samma pixelstorlek). `_klä_voxel` är delad av fiender och interiör.
	var ark: Array = []
	for f in DirAccess.get_files_at("res://assets/enemies"):
		if f.ends_with(".png") and not f.begins_with("_") and not f.ends_with("_mask.png"):
			ark.append(f.get_basename())
	ark.sort()
	for id in ark:
		var tex: Texture2D = load("res://assets/enemies/%s.png" % id)
		var spr := Sprite3D.new()
		var t0 := Time.get_ticks_usec()
		var byggde: bool = main._klä_voxel(spr, tex, main.ENEMY_FRAMES, 0.012)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var vx: Voxel = spr.get_meta("voxel", null)
		check(byggde and vx != null, "fienden %s blir en voxelmodell" % id)
		if vx != null:
			fiender.append(_mät(id, vx, ms))
		spr.free()

	# 2) INTERIÖREN: kistan, spaden och bossen är MARKÖRER (`_add_markör` → `_klä_voxel`, pixelstorlek
	#    0,008 — 128 px/m, se gen_props.py), alltså samma väg som fienderna. De byggs vid VÅNINGENS start.
	for namn in ["chest", "shovel", "boss"]:
		var tex: Texture2D = main._prop(namn)
		check(tex != null, "rekvisitan %s.png finns" % namn)
		if tex == null:
			continue
		var spr := Sprite3D.new()
		var t0 := Time.get_ticks_usec()
		main._klä_voxel(spr, tex, 1, 0.008)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var vx: Voxel = spr.get_meta("voxel", null)
		check(vx != null, "markören %s blir en voxelmodell" % namn)
		if vx != null:
			våning.append(_mät(namn, vx, ms))
		spr.free()

	# 3) MARKDEKOR OCH REKVISITER: `_dekor_nod` bygger EN modell per ART (MultiMesen delar den mellan
	#    våningens alla instanser), med dukens höjd som modellhöjd. Samma anrop som spelet gör — talen
	#    läses ur `main`, inte ur en kopia.
	for art in ["gräs", "småsten", "mossa", "rot", "bur", "kandelaber", "spricka_eld"]:
		var tex: Texture2D = main._prop(art)
		check(tex != null, "rekvisitan %s.png finns" % art)
		if tex == null:
			continue
		var duk := Vector2(float(tex.get_width()), float(tex.get_height())) * float(main.DEKOR_PIXEL)
		var t0 := Time.get_ticks_usec()
		var vx := Voxel.ur_ark(tex, 0, 1, duk.y, main.VOXEL_SIDOR, main.VOXEL_DJUP)
		vx.mesh()                                    # meshen byggs först här (den klockas med flit)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		våning.append(_mät(art, vx, ms))
	# Och att den RIKTIGA vägen (`_dekor_nod`) ger samma mesh: en MultiMesh vars mesh är voxelmodellen.
	var antal: int = main._dekor_nod("gräs", [Transform3D(Basis(), Vector3(1.5, 0.0, 2.5))])
	var nod: MultiMeshInstance3D = main.world.get_node_or_null("dekor_gräs")
	check(antal == 1 and nod != null and nod.multimesh.mesh != null,
		"dekorvägen lägger en voxelmodell i MultiMesen")

	# 4) TÄTHETEN. Varje modell ska ha minst EN cell per källpixel — under det tappar modellen
	#    källkonstens egen detalj (den gamla 64-cellersgränsen gjorde den 92 px höga fienden till
	#    0,70 celler/pixel, alltså varannan rad borta).
	var lägst := 99.0
	for m in fiender + våning:
		lägst = minf(lägst, minf(float(m["per_px"]), float(m["per_px_x"])))
	check(lägst >= 1.0, "ingen modell är grövre än en cell per källpixel (lägst %.2f)" % lägst)
	# DUBBLERINGEN: källkonsten sätter taket — en modell som redan har två celler per källpixel blir
	# inte finare av fler, bara dyrare. Så: varje modell ska antingen ha två celler per källpixel ELLER
	# ha nått källarkets egen pixelgrid (cellen under en källpixel).
	var grövre: Array = []
	for m in fiender + våning:
		var vx: Voxel = m["vx"]
		var cell_px := float(vx.ruta.size.y) / float(vx.sidor)
		if float(m["per_px"]) < 2.0 and cell_px > 1.0:
			grövre.append("%s (%.2f celler/pixel)" % [m["namn"], m["per_px"]])
	check(grövre.is_empty(), "varje modell har två celler per källpixel eller är pixel-exakt: %s"
		% str(grövre))

	# 5) GEOMETRIN FÅR INTE EXPLODERA. En fiende byggs vid stridens start och våningens tio modeller vid
	#    dess start; båda har ett tak (se konstanterna).
	var fiende_celler := 0
	var fiende_tri := 0
	var fiende_ms := 0.0
	for m in fiender:
		fiende_celler = maxi(fiende_celler, int(m["celler"]))
		fiende_tri = maxi(fiende_tri, int(m["tri"]))
		fiende_ms += float(m["ms"])
	var våning_celler := 0
	var våning_tri := 0
	var våning_ms := 0.0
	for m in våning:
		våning_celler += int(m["celler"])
		våning_tri += int(m["tri"])
		våning_ms += float(m["ms"])
	check(fiende_celler <= TAK_FIENDE_CELLER,
		"tyngsta fienden %d celler (tak %d)" % [fiende_celler, TAK_FIENDE_CELLER])
	check(fiende_tri <= TAK_FIENDE_TRIANGULAR,
		"tyngsta fienden %d trianglar (tak %d)" % [fiende_tri, TAK_FIENDE_TRIANGULAR])
	check(våning_celler <= TAK_CELLER, "våningsstarten %d celler (tak %d)" % [våning_celler, TAK_CELLER])
	check(våning_tri <= TAK_TRIANGULAR,
		"våningsstarten %d trianglar (tak %d)" % [våning_tri, TAK_TRIANGULAR])

	# SKALET (M143). Alex 16/10: *"Bara de synliga cellerna"*. Byborna byggs med `bara_synliga()`,
	# som stryker varje cell vars sex grannar är fyllda — de bidrog inte med en enda yta. Provet mäter
	# det som ska vara sant: YTORNA är exakt desamma som för en solid kropp, cellerna färre, och en
	# cell intill en grop behålls (annars faller väggen in i hålet — silhuetten vore inte kvar).
	var block := Voxel.new()
	for x in 5:
		for y in 5:
			for z in 5:
				block.celler[Vector3i(x, y, z)] = Color(0.5, 0.5, 0.5)
	var ytor_solid := block.antal_ytor()
	var ram_solid := block.mesh().get_aabb()
	var celler_solid := block.antal_celler()
	var skal := Voxel.new()
	skal.celler = block.celler.duplicate()
	var celler_skal := skal.bara_synliga()
	check(celler_skal == 98, "skalet av ett 5x5x5-block är 98 celler (125 - 27), mätt %d" % celler_skal)
	check(celler_skal < celler_solid, "skalet har färre celler än den solida kroppen (%d mot %d)"
		% [celler_skal, celler_solid])
	# YTORNA BLIR INTE FÄRRE — men de kan bli fler: när en inre cell stryks blottas grannens yta mot
	# den, och den ytan ligger inuti kroppen där ingen kamera ser den. Mätt: blocket 300 -> 408
	# trianglar, medan en bybo (smeden, djup 4) gav 3 848 båda vägarna — samma bild, samma ytor.
	check(skal.antal_ytor() >= ytor_solid,
		"skalet har inte färre ytor än den solida kroppen (%d mot %d)" % [skal.antal_ytor(), ytor_solid])
	var ram_skal := skal.mesh().get_aabb()
	check(ram_skal.is_equal_approx(ram_solid),
		"och ramen är oförändrad, alltså är konturen kvar (%s mot %s)" % [str(ram_skal.size), str(ram_solid.size)])
	var rör := Voxel.new()
	for x in 3:
		for y in 3:
			for z in 3:
				if x == 1 and y == 1:
					continue                  # en pipa rätt igenom: cellerna runt den har en tom granne
				rör.celler[Vector3i(x, y, z)] = Color(0.5, 0.5, 0.5)
	rör.bara_synliga()
	check(rör.celler.has(Vector3i(0, 1, 1)) and rör.celler.has(Vector3i(1, 0, 1)) \
			and rör.celler.has(Vector3i(2, 1, 1)) and rör.celler.has(Vector3i(1, 2, 1)),
		"cellerna intill pipan behålls (annars blir hålet igen)")

	print("  fiender: %d modeller, %d av dem är typen (en byggs per fiende i striden), tyngst %d celler / %d trianglar, %.0f ms för alla"
		% [fiender.size(), fiender.size(), fiende_celler, fiende_tri, fiende_ms])
	print("  våningsstart (kista, spade, boss, 4 markdekor, 3 rekvisiter): %d celler, %d trianglar, %.0f ms"
		% [våning_celler, våning_tri, våning_ms])
	print("= %d kontroller, %d fel" % [kontroller, fel])
	main.free()
	quit(1 if fel > 0 else 0)
