## BYBORNA I BYN (M129): målningens egna figurer, resta som voxlar i 3D-byn.
##
## Alex 15/10: *"Jag tog bort alla NPC's från modellen, tänkte att man kan klistra in från bilden de
## karaktärer som finns, men som voxlar, så de står där, men platt... typ."*
##
## Provet mäter FEM saker, i den ordning ett fel hade synts i spelet:
##   1. TABELLEN: `assets/by/bybor.json` finns, har lika många poster som figurerna på disk, och varje
##      post har en bild som laddar.
##   2. BILDEN: varje figur har både täckta och tomma pixlar, och figurens nederkant ligger i rutans
##      nederkant — annars står modellen och svävar över marken.
##   3. MODELLEN: en voxelmodell per post, med celler, byggd ur figurens EGEN bild (höjden i meter är
##      postens, inte cellens) och en RELIEF: djupet är några centimeter, inte en kropp — det är det
##      "platt" betyder.
##   4. MARKEN: modellens underkant står på postens mark-y (gatans 0,08 / hagens 0,12), och bybon
##      ligger inom byns x-spann.
##   5. KOSTNADEN: antalet celler och byggtiden för hela gruppen. Byn byggs en gång när vyn visas, så
##      en sekund är en synlig hake — taket står här.
##
## Körs: tools/ett_prov.sh tests/test_bybor.gd

extends SceneTree

var fel := 0
var kontroller := 0

## Tak för byggtiden för HELA gruppen (mätt: se utskriften). Byns vyn byggs när spelaren går in i
## byn; ligger gruppen på ett par hundra millisekunder syns den inte.
const TID_TAK_MS := 600
## Tak för antalet celler i hela gruppen (21 bybor). En bybo på 32 cellers höjd ligger på 1 000-3 000
## celler; går en post över det är det en ruta som är för stor, inte en bybo.
const CELL_TAK := 60_000

## Bilden provet sparar (bybor synliga) och jämför mot (bybor gömda). Samma mapp som de andra
## by-provens bilder (test_by_rok.gd skriver dit).
const PNG := "/home/alex/.hermes/cache/scratch/omd/byn_bybor.png"
const TEST_META := "user://test_bybor_meta.json"


## Städa provets egen metafil: annars ligger den kvar i user:// och nästa provkörning läser den.
func _clean() -> void:
	for p in [TEST_META, TEST_META + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Två bilder, antalet pixlar som skiljer (jämför bytes, inte pixel för pixel). Formaten kan skilja
## mellan två hämtningar ur samma yta (yta → bild går via en konvertering), så båda tvingas till
## RGBA8 först och storlekarna jämförs innan loopen — annars läser den förbi änden och provet dör
## på en krasch i stället för att mäta.
func _skillnad(a: Image, b: Image) -> int:
	if a == null or b == null:
		return -1
	# `Image.convert` konverterar PÅ PLATS (ingen retur), så båda bilderna tvingas till RGBA8 först.
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var x: PackedByteArray = a.get_data()
	var y: PackedByteArray = b.get_data()
	if x.size() != y.size() or x.size() == 0:
		print("    (bilderna har olika mått: %s mot %s)" % [str(a.get_size()), str(b.get_size())])
		return -1
	var n := 0
	for i in range(0, x.size(), 4):
		if x[i] != y[i] or x[i + 1] != y[i + 1] or x[i + 2] != y[i + 2]:
			n += 1
	return n


func check(villkor: bool, vad: String) -> void:
	kontroller += 1
	if not villkor:
		fel += 1
		print("  FEL: %s" % vad)


func _init() -> void:
	var poster: Array = Bybor.poster()
	check(not poster.is_empty(), "bybor.json finns och har poster (%d)" % poster.size())
	check(poster.size() >= 20, "minst 20 bybor i tabellen (fick %d)" % poster.size())

	# 1 och 2: bilderna.
	var antal_på_disk := 0
	for post in poster:
		var p: Dictionary = post
		var id := str(p.get("id", "?"))
		var väg := Bybor.MAPP + str(p.get("bild", ""))
		check(ResourceLoader.exists(väg), "%s: bilden finns (%s)" % [id, väg])
		if not ResourceLoader.exists(väg):
			continue
		antal_på_disk += 1
		var tex: Texture2D = load(väg)
		var img: Image = tex.get_image() if tex != null else null
		check(img != null, "%s: bilden går att läsa" % id)
		if img == null:
			continue
		var ck := img.get_size()
		var mått: Array = p.get("px", [0, 0])
		check(Vector2i(int(mått[0]), int(mått[1])) == ck,
			"%s: bilden är %dx%d px som tabellen säger (%dx%d)" % [id, int(mått[0]), int(mått[1]), ck.x, ck.y])
		# Figuren: täckta pixlar i nederkanten, och några i toppen. Godots EGEN `get_used_rect`
		# räknar ut alfans omfång — ingen egen pixelrunda som kan mäta fel.
		var använt: Rect2i = img.get_used_rect()
		check(använt.size.x > 0 and använt.size.y > 0, "%s: figuren har pixlar" % id)
		check(använt.position.y <= 4, "%s: figuren når rutans överkant (rad %d)" % [id, använt.position.y])
		check(använt.position.y + använt.size.y >= ck.y - 4,
			"%s: figuren når rutans nederkant (%d av %d)" % [id, använt.position.y + använt.size.y, ck.y])

	# 3-5: modellerna, byggda genom spelets EGEN väg (Bybor.bygg på en tom förälder).
	var förälder := Node3D.new()
	root.add_child(förälder)
	var t0 := Time.get_ticks_msec()
	var grupp := Bybor.bygg(förälder)
	var tid := Time.get_ticks_msec() - t0
	check(grupp.antal == antal_på_disk, "en nod per post (%d av %d)" % [grupp.antal, antal_på_disk])
	var celler := 0
	for barn in grupp.get_children():
		var mi := barn as MeshInstance3D
		var p: Dictionary = mi.get_meta("bybo") if mi != null and mi.has_meta("bybo") else {}
		var id := str(p.get("id", mi.name)) if mi != null else "?"
		check(mi != null and mi.mesh != null, "%s: noden har en mesh" % id)
		if mi == null or mi.mesh == null:
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		var höjd := float(p.get("höjd_m", 1.0))
		var pos: Array = p.get("pos", [0.0, 0.0, 0.0])
		check(is_equal_approx(aabb.size.y, höjd),
			"%s: modellen är %.3f m hög, tabellen säger %.3f" % [id, aabb.size.y, höjd])
		# RELIEFEN: djupet är en bråkdel av höjden. En quad eller en kropp hade varit tjock.
		check(aabb.size.z < aabb.size.y * 0.25, "%s: platt (djup %.3f m mot höjd %.3f)" % [id, aabb.size.z, aabb.size.y])
		# MARKEN: underkanten på postens mark-y.
		var underkant: float = mi.position.y + aabb.position.y
		check(absf(underkant - float(pos[1])) < 0.01,
			"%s: står på marken (underkant %.3f mot %.3f)" % [id, underkant, float(pos[1])])
		check(absf(mi.position.x - float(pos[0])) < 0.01, "%s: x %.2f som tabellen" % [id, mi.position.x])
		check(float(pos[0]) > -18.0 and float(pos[0]) < 18.0, "%s: inom byns x-spann" % id)
		# CELLERNA: modellen bär sitt eget antal (satt när den byggdes), så provet räknar inte om
		# meshens trianglar till celler — en gissning som ändras varje gång modellen ändras.
		celler += int(mi.get_meta("celler", 0))
	check(tid < TID_TAK_MS, "byggtiden %.0f ms under taket %d ms" % [tid, TID_TAK_MS])
	check(celler > 0 and celler < CELL_TAK, "cellerna i hela gruppen: %d under taket %d" % [celler, CELL_TAK])
	print("  bybor: %d st, %d celler, byggt på %.0f ms" % [grupp.antal, celler, tid])

	# 6. INKOPPLINGEN: by-vyns EGEN väg (ui/village_view.gd -> ui/by_3d.gd) ska bära gruppen under
	# `byn`, så en by som flyttas i scenen tar byborna med sig — och Alex hittar dem i editorn.
	var byvy := VillageView.new()
	byvy.size = Vector2(480, 270)
	root.add_child(byvy)
	byvy.visa(Meta.load_or_new(TEST_META), 1)
	var nod: By3D = byvy.by3d()
	var under_byn: Node = null if nod == null or nod.by == null else nod.by.get_node_or_null("bybor")
	check(under_byn != null, "by-vyns By3D bär byborna under `byn` (byn/bybor)")
	check(under_byn != null and under_byn.get_child_count() == poster.size(),
		"och gruppen har en nod per post (%d)" % (under_byn.get_child_count() if under_byn != null else 0))
	byvy.free()
	_clean()
	await process_frame

	# 7. BILDEN: byborna i by-vyns EGEN 3D-yta (`byvy.by3d_textur()`, samma textur spelet ritar i
	# rutan). Två rutor av samma vy — en med gruppen GÖMD och en med den synlig — och skillnaden är
	# bybornas pixlar. `projicera` svarar i SAMMA px som den texturen, så beskärningen stämmer.
	if DisplayServer.get_name() != "headless":
		var vy2 := VillageView.new()
		vy2.size = Vector2(941, 1018)
		root.add_child(vy2)
		vy2.visa(Meta.load_or_new(TEST_META), 1)
		for i in 6:
			await process_frame
		var nod2: By3D = vy2.by3d()
		var grupp2: Node = null if nod2 == null or nod2.by == null else nod2.by.get_node_or_null("bybor")
		var tex: Texture2D = vy2.by3d_textur()
		if grupp2 != null and tex != null:
			grupp2.visible = false
			for i in 4:
				await process_frame
			var utan: Image = tex.get_image()
			grupp2.visible = true
			for i in 4:
				await process_frame
			var med: Image = tex.get_image()
			utan.save_png(PNG)
			med.save_png(PNG.replace(".png", "_med.png"))
			var antal_px := _skillnad(med, utan)
			var px := med.get_width() * med.get_height()
			check(antal_px > 200, "byborna RITAS i byns kamera (%d px = %.2f %% av rutan)" %
				[antal_px, 100.0 * antal_px / float(px)])
			print("  bilden %dx%d: %s (utan bybor: %s)" %
				[med.get_width(), med.get_height(), PNG.replace(".png", "_med.png"), PNG])
			# VAR DE STÅR I BILDEN, ur spelets egen projektion — det är de tal en beskärning behöver.
			for post in poster:
				var p: Dictionary = post
				var pos: Array = p.get("pos", [0, 0, 0])
				var sp: Vector2 = nod2.projicera(Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
				print("    %-14s vy-px (%.0f, %.0f)" % [str(p.get("id", "?")), sp.x, sp.y])
		else:
			check(false, "gruppen bybor och 3D-ytan finns i by-vyn")
		vy2.queue_free()
		await process_frame
	else:
		print("  (bildprovet hoppas över: headless renderar inget — kör med DISPLAY=:99)")

	print("=== %s: %d kontroller, %d fel ===" % ["BYBOR", kontroller, fel])
	quit(1 if fel > 0 else 0)
