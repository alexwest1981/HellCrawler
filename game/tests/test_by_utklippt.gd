## BYGGNADERNA UR BILDEN (M123): husen är egna objekt, gatan är marken, och kameran ger djupet.
##
## Alex, om den förra byn: *"Husen skulle lyftas ut och läggas som objekt i en 2.5D-vy, gatan framför
## skulle vara 'marken de stod på'. Det här såg förjävligt ut."*
##
##   godot --headless --script res://tests/test_by_utklippt.gd
##
## Provet mäter fyra saker, en rubrik per punkt — varje sak är antingen en siffra ur en NOD eller en
## pixel ur en bild:
##   1. UTKLIPPT: varje byggnad har sin EGEN textur, att texturen är exakt sin ruta i bilden (mått
##      och pixlar), och att himlen ovanför taket blev genomskinlig. Den FULLSTÄNDIGA pixelkontrollen
##      (varje pixel, inte var femte) görs av `tools/gen_by_hus.py --check`, som sviten kör först.
##   2. GATAN ÄR MARKEN: varje hus FOT ligger på gatulinjen i den ritade scenen — läst ur nodernas
##      EGET canvas-transform, inte ur en formel — och nolläget ligger exakt på husets ruta i bilden.
##   3. PARALLAXEN: kameran panter N px, lager A flyttar a px och lager B b px, a ≠ b, och husen (det
##      närmare lagret) rör sig MER än bakgrunden. Gångaren står på husens lager.
##   4. BAKERSTA LAGRET: husen är orörda medan det bakersta lagret blir mätbart mjukare, och
##      markeringen är platsens EGEN form — inte en gul ruta runt den.
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_by_utklippt_meta.json"
const VY := Vector2(480, 270)
const BILD := "res://assets/ui/byn.png"
const DIR := "res://assets/ui/byn/"
## Provtätheten i pixelkontrollerna. Den exakta kontrollen (varje pixel) gör generatorn; här räcker
## ett fint nät, och det står i raden hur många pixlar som faktiskt provades.
const STEG := 5

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".trasig"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Kantkontrast: medelvärdet av skillnaden mellan grannpixlar. Lågt = mjukt. Samma mått som den
## gamla byns bildmätning använde, så siffrorna går att jämföra rakt av.
func _kantkontrast(bild: Image) -> float:
	if bild == null:
		return 0.0
	var b := bild
	if b.get_format() != Image.FORMAT_RGBA8:
		b = b.duplicate()
		b.convert(Image.FORMAT_RGBA8)
	var summa := 0.0
	var antal := 0
	for y in range(0, b.get_height(), 3):
		for x in range(1, b.get_width(), 3):
			var a := b.get_pixel(x - 1, y)
			var c := b.get_pixel(x, y)
			summa += absf(a.r - c.r) + absf(a.g - c.g) + absf(a.b - c.b)
			antal += 1
	return summa / maxf(1.0, float(antal))

func _gå_klart(g: Gångare, dt: float = 0.05) -> void:
	var antal := 0
	while g.går() and antal < 100000:
		g.steg(dt)
		antal += 1

func _initialize() -> void:
	var stages := Stages.load_all()
	var order: Array = stages.keys()
	_clean()
	var meta := Meta.load_or_new(TEST_PATH)

	# ---------------------------------------------------------------- 1. HUSEN ÄR EGNA TEXTURER
	print("")
	print("— 1. husen är utklippta ur bilden —")
	var by := VillageView.new()
	by.size = VY
	by.visa(meta, order.size())
	var konst := by.byscen()
	check(konst != null, "byns bild finns att klippa ur", BILD)
	if konst == null:
		print("")
		print("%d kontroller, %d fel" % [checks, fails + 1])
		quit(1)
		return
	var källa := konst.get_image()
	källa.convert(Image.FORMAT_RGB8)
	var art := Vector2(konst.get_width(), konst.get_height())
	var rutor: Array = []
	for i in VillageView.PLATSER.size():
		rutor.append(by._konst_ruta(i, art))
	var husbilder: Array = []
	var saknas := []
	var fel_ruta := []
	var fel_px := []
	var tomma := []
	var provade := 0
	var genomskinliga := 0
	for i in VillageView.PLATSER.size():
		var id := str(VillageView.PLATSER[i]["id"])
		var fil := "%shus_%s.png" % [DIR, id]
		if not ResourceLoader.exists(fil):
			saknas.append(id)
			husbilder.append(null)
			continue
		var hus := (load(fil) as Texture2D).get_image()
		hus.convert(Image.FORMAT_RGBA8)
		husbilder.append(hus)
		var r: Rect2 = rutor[i]
		if hus.get_width() != int(r.size.x) or hus.get_height() != int(r.size.y):
			fel_ruta.append("%s %dx%d mot %dx%d" % [id, hus.get_width(), hus.get_height(),
				int(r.size.x), int(r.size.y)])
		var olika := 0
		var tom := 0
		for y in range(0, hus.get_height(), STEG):
			for x in range(0, hus.get_width(), STEG):
				var p := hus.get_pixel(x, y)
				if p.a < 0.5:
					tom += 1
					continue
				var q := källa.get_pixel(int(r.position.x) + x, int(r.position.y) + y)
				if absf(p.r - q.r) > 0.0 or absf(p.g - q.g) > 0.0 or absf(p.b - q.b) > 0.0:
					olika += 1
		provade += int(ceil(float(hus.get_height()) / STEG)) * int(ceil(float(hus.get_width()) / STEG))
		genomskinliga += tom
		if olika > 0:
			fel_px.append("%s %d px" % [id, olika])
		if tom == 0:
			tomma.append(id)
	check(saknas.is_empty(), "varje byggnad har sin EGEN textur i assets/ui/byn/", ", ".join(saknas))
	check(fel_ruta.is_empty(), "och texturen är exakt sin ruta i bilden (konstens px)", ", ".join(fel_ruta))
	check(fel_px.is_empty(), "0 ändrade pixlar mot bildens ruta — huset är KLIPPT, inte ritat",
		"%d px provade i %d hus, alla lika bilden" % [provade, VillageView.PLATSER.size()]
			if fel_px.is_empty() else ", ".join(fel_px))
	check(tomma.is_empty(), "och himlen ovanför taket blev GENOMSKINLIG (annars släpar huset himmel med sig)",
		"%d av %d provade pixlar (%.1f %%)" % [genomskinliga, provade,
			100.0 * float(genomskinliga) / maxf(1.0, float(provade))])
	# ÖVERLAPPANDE HUS: två rutor kan gå in i varandra (mätt: 1 par, tradet/smed). Där får husen inte
	# säga OLIKA om samma pixel — den enas genomskinliga himmel över den andras hus hade lämnat ett hål
	# i bakgrunden som ingen täcker. Masken är global, så svaret ska vara noll olika pixlar.
	var par := 0
	var olika_alfa := 0
	for i in VillageView.PLATSER.size():
		for j in VillageView.PLATSER.size():
			if i >= j or husbilder[i] == null or husbilder[j] == null:
				continue
			var a: Rect2 = rutor[i]
			var b: Rect2 = rutor[j]
			var över := a.intersection(b)
			if över.size.x < 1.0 or över.size.y < 1.0:
				continue
			par += 1
			for y in range(int(över.position.y), int(över.end.y), 2):
				for x in range(int(över.position.x), int(över.end.x), 2):
					var pa: float = (husbilder[i] as Image).get_pixel(int(x - a.position.x), int(y - a.position.y)).a
					var pb: float = (husbilder[j] as Image).get_pixel(int(x - b.position.x), int(y - b.position.y)).a
					if absf(pa - pb) > 0.5:
						olika_alfa += 1
	check(olika_alfa == 0, "hus som överlappar varandra säger SAMMA sak om varje pixel (ingen hål-krock)",
		"%d par överlappar, %d pixlar olika" % [par, olika_alfa])
	# BAKGRUNDEN: bilden med hålen ifyllda. Den ska finnas, ha bildens mått, och vara ORÖRD utanför
	# husens rutor — annars har generatorn ändrat något den inte äger.
	var bak_fil := DIR + "bak.png"
	check(ResourceLoader.exists(bak_fil), "bakgrunden med husen borttagna finns", bak_fil)
	if ResourceLoader.exists(bak_fil):
		var bak_img := (load(bak_fil) as Texture2D).get_image()
		bak_img.convert(Image.FORMAT_RGB8)
		check(bak_img.get_size() == Vector2i(int(art.x), int(art.y)),
			"och har bildens mått", "%dx%d" % [bak_img.get_width(), bak_img.get_height()])
		var utanför := 0
		var prov := 0
		for y in range(0, bak_img.get_height(), 11):
			for x in range(0, bak_img.get_width(), 11):
				var i_ruta := false
				for r in rutor:
					if (r as Rect2).has_point(Vector2(x, y)):
						i_ruta = true
						break
				if i_ruta:
					continue
				prov += 1
				if bak_img.get_pixel(x, y) != källa.get_pixel(x, y):
					utanför += 1
		check(utanför == 0, "och är ORÖRD utanför husens rutor — hålen är det enda som ändrats",
			"%d pixlar provade utanför rutorna, %d ändrade" % [prov, utanför])
	by.free()

	# ---------------------------------------------------------------- 2. GATAN ÄR MARKEN
	print("")
	print("— 2. gatan är marken de står på —")
	var korg := SubViewportContainer.new()
	korg.stretch = false
	korg.scale = Vector2(3, 3)
	var vp := SubViewport.new()
	vp.size = Vector2i(VY)
	korg.add_child(vp)
	root.add_child(korg)
	await process_frame
	var by3 := VillageView.new()
	by3.size = VY
	vp.add_child(by3)
	by3.visa(meta, order.size())
	await process_frame
	var scen := by3.scen3d()
	check(scen != null and scen.klar(), "byn ritas som 2D-lager med en kamera — inte som en 3D-kvad", "ByScen")
	if scen == null:
		by3.free()
		korg.queue_free()
		_clean()
		print("")
		print("%d kontroller, %d fel" % [checks, fails + 1])
		quit(1)
		return
	scen.sätt_kamera(0.0, 0.0)
	var bild := by3.bild_storlek()
	var skala: float = bild.y / art.y
	var bom := []
	var fot_avvikelse := 0.0
	for i in VillageView.PLATSER.size():
		var r: Rect2 = rutor[i]
		var fot := scen.hus_skärmpunkt(i, r.position.x + r.size.x * 0.5, r.position.y + r.size.y)
		var avvik: float = absf(fot.y - scen.marklinje())
		fot_avvikelse = maxf(fot_avvikelse, avvik)
		if avvik > 0.75:
			bom.append("%s %.2f px" % [str(VillageView.PLATSER[i]["id"]), avvik])
	check(bom.is_empty(), "varje hus FOT ligger på gatulinjen i den ritade scenen",
		"största avvikelse %.2f vy-px, gatan på %.1f (rad %.1f i konstens px)" % [fot_avvikelse,
			scen.marklinje(), by3._gata_px])
	# NOLLÄGET: huset ligger på EXAKT sin egen ruta ur bilden. Det är det som gör den sammansatta vyn
	# pixel-identisk med den målade bilden — rörelsen ska ge djupet, inte en annan komposition.
	var fel_noll := 0.0
	for i in VillageView.PLATSER.size():
		var r: Rect2 = rutor[i]
		var hörn := scen.hus_skärmpunkt(i, r.position.x, r.position.y)
		fel_noll = maxf(fel_noll, absf(hörn.x - (r.position.x * skala - by3.pan())))
		fel_noll = maxf(fel_noll, absf(hörn.y - (scen.topp_px() + r.position.y * skala)))
	check(fel_noll < 0.02, "och ligger exakt på sin egen ruta i bilden när kameran vilar (nolläget)",
		"största avvikelse %.4f vy-px = %.3f skärm-px" % [fel_noll, fel_noll * 3.0])
	# Kamera i vila: bakgrunden ligger där den platta bilden ritade den.
	var förväntad_x: float = art.x * 0.5 * skala - by3.pan()
	check(absf(scen.bak_skärmpunkt(art.x * 0.5, art.y * 0.5).x - förväntad_x) < 0.5,
		"och bakgrunden ligger där den platta bilden hade ritat den",
		"%.1f px mot väntade %.1f" % [scen.bak_skärmpunkt(art.x * 0.5, art.y * 0.5).x, förväntad_x])

	# ---------------------------------------------------------------- 3. PARALLAXEN
	print("")
	print("— 3. parallaxen: lagren rör sig OLIKA mycket —")
	var ax := art.x * 0.5
	var ay := art.y * 0.5
	scen.sätt_kamera(0.0, 0.0)
	await process_frame
	var a0 := scen.bak_skärmpunkt(ax, ay)
	var b0 := scen.hus_skärmpunkt(0, ax, ay)
	var n := ByScen.SVEP
	scen.sätt_kamera(n, 0.0)
	await process_frame
	var a1 := scen.bak_skärmpunkt(ax, ay)
	var b1 := scen.hus_skärmpunkt(0, ax, ay)
	var flytt_a: float = absf(a1.x - a0.x)
	var flytt_b: float = absf(b1.x - b0.x)
	var faktorer := scen.lagerfaktorer()
	check(faktorer.y > faktorer.x, "lagren har OLIKA parallaxfaktor",
		"bakgrund %.2f, hus %.2f" % [faktorer.x, faktorer.y])
	check(absf(flytt_a - n * faktorer.x) < 0.5, "bakgrunden flyttar sig kamerans väg gånger sin faktor",
		"%.1f px av %.1f × %.2f" % [flytt_a, n, faktorer.x])
	check(absf(flytt_b - n * faktorer.y) < 0.5, "och husen kamerans väg gånger SIN faktor",
		"%.1f px av %.1f × %.2f" % [flytt_b, n, faktorer.y])
	check(flytt_b > flytt_a + 1.0, "husen rör sig MER än bakgrunden — riktningen är djupet",
		"hus %.1f px mot bakgrund %.1f px (%.2f gånger)" % [flytt_b, flytt_a, flytt_b / maxf(0.001, flytt_a)])
	check(absf(flytt_b - flytt_a) > 1.0, "och skillnaden är mätbar, inte avrundning",
		"skillnad %.1f px vid en kamerarörelse på %.0f px" % [absf(flytt_b - flytt_a), n])
	# Hålet bakom huset: den relativa rörelsen är den yta som kan bli synlig. MÄTT, inte gissat.
	var hål_px: float = absf(flytt_b - flytt_a)
	check(hål_px < n * (faktorer.y - faktorer.x) + 0.5 and hål_px * 3.0 < 20.0,
		"hålet bakom huset är en REMSA, inte ett hål i scenen",
		"%.1f vy-px = %.1f skärm-px vid fullt SVEP (kameran är klamd dit)" % [hål_px, hål_px * 3.0])
	# Kameran är KLAMD: en rörelse långt utanför SVEP flyttar inte scenen längre.
	scen.sätt_kamera(4.0 * n, 0.0)
	await process_frame
	var a2 := scen.bak_skärmpunkt(ax, ay)
	check(absf(absf(a2.x - a0.x) - n * faktorer.x) < 0.5, "kameran stannar vid SVEP",
		"begärt %.0f px, flyttade %.1f" % [4.0 * n, absf(a2.x - a0.x)])
	scen.sätt_kamera(0.0, 0.0)
	# GÅNGAREN står på det hus man SER (M126): hennes punkt är 3D-husets EGET mitt i vyn, med fötterna
	# på gatulinjen. 2D-scenens huslager ritar ingenting längre — hon bars av en textur som inte ritas
	# — så hon kan inte längre mätas på det lagret. Att hon följer husen är nu samma sak som att hon
	# står på husets projicerade ruta.
	var g: Gångare = by3.gångaren()
	by3.gå_till(3)
	_gå_klart(g)
	await process_frame
	var punkt: Vector2 = by3.ståplats()
	var hus3: Rect2 = by3.byggnad_rect(3)
	# HAN STÅR PÅ GATAN, INTE VID HUSET MAN VALDE (M141): platsen markeras av plattan och glöden på
	# huset — figuren var förut en avbildning av menyraden.
	check(punkt.x < hus3.position.x or punkt.x > hus3.end.x,
		"figuren står på sin egen fläck, inte vid det valda huset",
		"x %.0f mot husets ruta %.0f-%.0f" % [punkt.x, hus3.position.x, hus3.end.x])
	check(absf(punkt.y - by3.gata_y()) < 0.01,
		"och står på gatulinjen — husens fot i 3D-byn",
		"y %.2f mot gatulinjen %.2f" % [punkt.y, by3.gata_y()])
	scen.sätt_kamera(0.0, 0.0)

	# ---------------------------------------------------------------- 4. BAKERSTA LAGRET
	print("")
	print("— 4. bara bakersta lagret blir mjukare —")
	var bak_tex := by3.bak_textur()
	check(bak_tex != null, "scenen ritar bakgrunden ur bak.png, inte ur den målade bilden",
		"bakgrundens textur är %dx%d" % [bak_tex.get_width(), bak_tex.get_height()] if bak_tex != null else "saknas")
	var mjuk := scen.mjuk_kopia(bak_tex)
	var rå: float = _kantkontrast(bak_tex.get_image())
	check(mjuk != null and mjuk.get_width() == bak_tex.get_width(),
		"den förmjukade kopian har bakgrundens mått", "%dx%d" % [mjuk.get_width(), mjuk.get_height()])
	var mjuk_kk: float = _kantkontrast(mjuk.get_image())
	check(mjuk_kk < rå * 0.9, "och är MÄTBART mjukare — bakersta lagret blir aldrig skarpt",
		"kantkontrast %.2f mot bakgrundens %.2f (%.0f %% lägre)" % [mjuk_kk, rå, 100.0 * (1.0 - mjuk_kk / rå)])
	# HUSEN ÄR ORÖRDA: deras textur är alltid den urklippta, aldrig en kopia av en kopia.
	var hus_kk: Array = []
	for i in VillageView.PLATSER.size():
		var p := "%shus_%s.png" % [DIR, str(VillageView.PLATSER[i]["id"])]
		if ResourceLoader.exists(p):
			hus_kk.append(_kantkontrast((load(p) as Texture2D).get_image()))
	var hus_min: float = hus_kk.min() if not hus_kk.is_empty() else 0.0
	var hus_max: float = hus_kk.max() if not hus_kk.is_empty() else 0.0
	check(hus_min > mjuk_kk * 2.0, "medan husen är SKARPA — avståndsblurret kan inte nå dem",
		"husens kantkontrast %.1f-%.1f mot bakgrundens %.1f" % [hus_min, hus_max, mjuk_kk])
	# MARKERINGEN ÄR BYGGNADENS EGEN FORM: glöden använder husets textur (samma pixlar), inte en ruta.
	scen.sätt_markering(2, -1)
	await process_frame
	var glod_ok := scen._glodar.size() == 2 and (scen._glodar[0] as Sprite2D).visible
	var glod_textur: Texture2D = (scen._glodar[0] as Sprite2D).texture if glod_ok else null
	check(glod_ok and glod_textur != null and glod_textur == (scen._hus[2] as Sprite2D).texture,
		"markeringen är byggnadens EGEN silhuett (samma textur som huset), inte en ruta runt det",
		"husets textur" if glod_textur != null and glod_textur == (scen._hus[2] as Sprite2D).texture else "annan")
	# OCH den kan inte glida ifrån huset den märker: glöden sitter på husets egen ruta.
	check((scen._glodar[0] as Sprite2D).get_meta("ruta") == rutor[2],
		"och står på exakt husets ruta", str((scen._glodar[0] as Sprite2D).get_meta("ruta")))
	scen.sätt_markering(-1, -1)
	check(not (scen._glodar[0] as Sprite2D).visible, "och släcks när inget är valt")
	# SKÄRPAN i den här vyn är kvar: 1:1-vägen gäller fortfarande efter ombyggnaden.
	check(by3.fönsterskala() == 3.0, "vyns ritläge är oförändrat skarpt (skala 3)", "%.0f" % by3.fönsterskala())
	by3.free()
	korg.queue_free()

	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
