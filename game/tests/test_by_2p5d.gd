## BYN I 2.5D (M122): kloten borta, huset är knappen, skärpan mätt i konstpixlar, gångaren — och
## paralaxen mellan lagren.
##
## Alex' tre klagomål, i hans egna ord:
##   * "Det är de färgade kloten du lagt in i byn som är ett av problemen."
##   * "Jag vill ha en by i 2.5D med paralax och crisp grafik, vilket det inte är idag."
##   * "...en karaktär som går mellan punkterna i byn, och på kartan."
##
## Provet mäter fyra saker, en rubrik per punkt:
##   1. KLOTEN: noll `draw_circle` i byns ritningsfil, varje plats nåbar med ett KLICK på sitt hus,
##      hovringen träffar rätt hus och visar dess namn.
##   2. SKÄRPAN: konsten ritas i 1:1 mot skärmens pixelgrid (en konstpixel = en skärmpixel) — mätt
##      som skal-förhållandet mot fönstrets heltalsskala, både med och utan korg.
##   3. GÅNGAREN: EN komponent, som går till den valda platsen och först DÅ öppnar den — och samma
##      komponent på världskartan. Provet mäter vägen, tiden och att rätt plats öppnas.
##   4. PARALLAXEN: byn är 2D-lager; kameran pannas N px och lager A flyttar a px, lager B b px, a≠b.
##   5. VALET (M124): ingen ram runt det valda huset, och EN pil över den valda posten i listen som
##      flyttar sig med valet. Alex: *"Jag vill bara ha en pil ovanför det man valt i listen under."*
##
## M123: själva utklippningen av husen, gatulinjen och nolläget mäts i `test_by_utklippt.gd`. Här står
## den del som hörde hit: lagren, klickytan, skärpan och gångaren.
##
##   godot --headless --script res://tests/test_by_2p5d.gd
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_by_2p5d_meta.json"
const VY := Vector2(480, 270)

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

## En riktig mushändelse in i vyns EGEN ingång (`_gui_input`) — samma väg som spelets mus tar.
func _klick(vy, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	vy._gui_input(e)

func _rör(vy, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	vy._gui_input(e)

## Antalet `draw_circle` i en fil. Klotet VAR en `draw_circle` per plats (fyllning, kontur, glöd,
## blänk) — noll kvar är samma sak som noll klot i renderingen.
func _cirkel_antal(sökväg: String) -> int:
	var text := FileAccess.get_file_as_string(sökväg)
	if text.is_empty():
		return -1
	return text.count("draw_circle(")

## Markeringens ruta i FÖNSTERpixlar: summan av de glödar i scenen som SYNS (en plats för den valda
## och en för den hovrade — de kan vara olika hus). Tom när ingen ritas, alltså noll pixlar markering.
## Rutan räknas ur nodens EGET läge, skal och textur, inte ur en formel: provet mäter det som RITAS.
func _markering_ruta(vy) -> Rect2:
	var scen: ByScen = vy.scen3d()
	var rutor := []
	if scen != null:
		for g in scen._glodar:
			var s := g as Sprite2D
			if s == null or not s.visible or s.texture == null:
				continue
			var m := s.scale * Vector2(s.texture.get_size())
			rutor.append(Rect2(s.position - m * 0.5, m))
	if rutor.is_empty():
		return Rect2()
	var r: Rect2 = rutor[0]
	for i in range(1, rutor.size()):
		r = r.merge(rutor[i])
	var k: float = vy.fönsterskala()
	return Rect2(r.position * k, r.size * k)


## Kör gångaren fram till målet i fasta steg, och säg hur många steg (och hur lång tid) det tog.
## Kantkontrasten i en bild: medelvärdet av skillnaden mellan grannpixlar. Lågt = mjukt (samma mått
## som rapportens bildmätning av det bakersta lagret).
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

func _gå_klart(g: Gångare, dt: float = 0.05) -> Dictionary:
	var antal := 0
	while g.går() and antal < 100000:
		g.steg(dt)
		antal += 1
	return {"steg": antal, "tid": float(antal) * dt}


func _initialize() -> void:
	var stages := Stages.load_all()
	var order: Array = stages.keys()
	order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))
	_clean()
	var meta := Meta.load_or_new(TEST_PATH)

	# ---------------------------------------------------------------- 1. KLOTEN BORTA
	print("")
	print("— 1. kloten borta: huset är knappen —")
	# VYN MÅSTE STÅ I ETT TRÄD (M126): klickrutan räknas ur husets position i byn.glb, och provet
	# mäter den vägen med kamerans EGEN `unproject_position` — den svarar bara för en kamera som står
	# i en rytas vy. Utan korgen (en bar SubViewport) är `fönsterskala()` fortfarande 1, så 2D-vägens
	# reservruta mäts som förut.
	var vp1 := SubViewport.new()
	vp1.size = Vector2i(VY)
	root.add_child(vp1)
	await process_frame
	var by := VillageView.new()
	by.size = VY
	vp1.add_child(by)
	await process_frame
	by.visa(meta, order.size())
	var antal: int = VillageView.PLATSER.size()
	check(_cirkel_antal("res://ui/village_view.gd") == 0,
		"noll draw_circle i byns ritning (klot, bollar, glöd var alla cirklar)",
		"%d kvar" % _cirkel_antal("res://ui/village_view.gd"))
	# Varje plats går att komma in i MED ETT KLICK PÅ SITT HUS. Panoreringen flyttas dit först
	# (precis som när spelaren bläddrar dit), och klicket läggs i husets egen ruta.
	var mål := []
	by.vald.connect(func(skepp: String): mål.append(skepp))
	var bom := []
	var för_små := []
	for i in antal:
		while by.valt_index() < i:
			if not by.flytta(Vector2i(1, 0)):
				break
		by.pan_klart()
		var r := by.byggnad_rect(i)
		if r.size.x < 8.0 or r.size.y < 8.0:
			för_små.append("%s %s" % [VillageView.PLATSER[i]["id"], str(r)])
			continue
		mål.clear()
		_klick(by, r.get_center())
		# Klicket startar GÅNGEN; platsen öppnas när figuren är framme (det är punkten 4 nedan).
		_gå_klart(by.gångaren())
		if mål != [str(VillageView.PLATSER[i]["skepp"])]:
			bom.append("%s -> %s" % [VillageView.PLATSER[i]["id"], str(mål)])
	check(för_små.is_empty(), "varje hus har en klickruta i vyn", ", ".join(för_små))
	check(bom.is_empty(), "klick på varje hus öppnar just den platsen (när figuren gått dit)", ", ".join(bom))
	# DET NYA BETTET (M126): klickytan ska vara husets EGEN position i byn.glb, och det bevisas med en
	# ANNAN väg än vyns egen formel. Provet räknar fram husets ruta ur modellens meshar med kamerans
	# `unproject_position` och klickar i MITTEN av DEN rutan. Låg klickytan vid sidan av huset — som
	# 2D-rutan gjorde, MÄTT 34-115 px fel, medel 79 px i en 313 px-vy — öppnade klicket en annan plats
	# eller ingen alls, och det här provet föll.
	var bmod: By3D = by.by3d()
	check(bmod != null and bmod.by != null, "3D-byn är byggd ur byn.glb — det är den som ritas", "byn.glb")
	if bmod != null and bmod.by != null:
		var fel_ruta := []
		var bom3 := []
		var utan_hus := []
		for i in antal:
			var pre := str(VillageView.PLATSER[i].get("3d", ""))
			var a := bmod.hus_aabb(pre)
			if a.size == Vector3.ZERO:
				utan_hus.append("%s (%s)" % [str(VillageView.PLATSER[i]["id"]), pre])
				continue
			# RUTAN KLIPPS MOT VYN, precis som vyns egen klickruta (`byggnad_rect` klipper mot
			# vyns ruta): med den tippade kameran står husets FOT under vyns nederkant i en
			# 480x270-vy, och en ruta där bara överdelen syns är kortare än modellens egen ruta.
			# Jämförde provet sin OKLIPPTA ruta med vyns klippta mätte det bara kanten (MÄTT:
			# 4,3 px för trädet, 9,1 px för porten) — rutan själv låg rätt hela tiden.
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for k in 8:
				var pk := bmod.kamera.unproject_position(a.get_endpoint(k))
				mn = Vector2(minf(mn.x, pk.x), minf(mn.y, pk.y))
				mx = Vector2(maxf(mx.x, pk.x), maxf(mx.y, pk.y))
			var r3 := Rect2(mn, mx - mn).intersection(Rect2(Vector2.ZERO, VY))
			var rv := by.byggnad_rect(i)
			var avvik: float = rv.get_center().distance_to(r3.get_center())
			if avvik > 1.0:
				fel_ruta.append("%s %.1f px" % [str(VillageView.PLATSER[i]["id"]), avvik])
			mål.clear()
			_klick(by, r3.get_center())          # klicket kommer ur MODELLEN, inte ur vyns ruta
			_gå_klart(by.gångaren())
			if mål != [str(VillageView.PLATSER[i]["skepp"])]:
				bom3.append("%s -> %s" % [str(VillageView.PLATSER[i]["id"]), str(mål)])
		check(utan_hus.is_empty(), "varje plats har ett eget hus i byn.glb (prefixet i PLATSER)", ", ".join(utan_hus))
		check(fel_ruta.is_empty(),
			"vyns klickruta är husets EGEN ruta ur modellen — kamerans projektion, inte en 2D-ruta",
			", ".join(fel_ruta))
		check(bom3.is_empty(), "klick i MITTEN av 3D-huset öppnar just den platsen", ", ".join(bom3))
	# HUSET ÄR KNAPPEN, inte en prick bredvid: ett klick högt upp på huset (långt ifrån platsens
	# punkt på gatan) ska träffa samma plats. Det var det som var fel förut — man siktade på en boll.
	by.flytta(Vector2i(-1, 0))
	while by.valt_index() != 0:
		if not by.flytta(Vector2i(-1, 0)):
			break
	by.pan_klart()
	var r0 := by.byggnad_rect(0)
	var högt := Vector2(r0.get_center().x, r0.position.y + 6.0)
	# "Platsens punkt på gatan" är den punkt koden SJÄLV ställer platsen på i 3D-vyn —
	# `gångpunkt`: husets projicerade mitt i sidled, på modellens gatulinje `gata_y` (samma väg som
	# klickrutan och gångaren). Den gamla `plats_px` är 2D-scenens ankare (bildens procent minus
	# panoreringen, marklinjen på 78 % av vyns höjd): panoreringen flyttar inget i 3D-byn, och MÄTT
	# låg den 14 px fel i sidled och 90 px fel i höjd mot husets egen fot — provet mätte alltså
	# avståndet till ett ankare som inte längre finns i vyn, inte till huset.
	# KARAKTÄREN HAR SIN EGEN FLÄCK PÅ GATAN (M141) — han står inte längre vid det valda huset — så
	# avståndet mäts mot HANS punkt: klicket ska ta på husets kropp, långt ifrån honom.
	var punkt := by.ståplats()
	var avstånd := högt.distance_to(punkt)
	mål.clear()
	_klick(by, högt)
	_gå_klart(by.gångaren())
	check(mål == ["trad"] and avstånd > 40.0,
		"klicket tar på husets kropp, inte bara vid markörens punkt",
		"klicket %.0f px ovanför platsens punkt" % avstånd)
	# Hovringen: rätt hus, och namnet syns.
	_rör(by, by.byggnad_rect(2).get_center())
	check(by.hovrad() == 2, "hovringen träffar huset man pekar på",
		"%d (%s)" % [by.hovrad(), str(VillageView.PLATSER[2]["id"])])
	var hovring := []
	for rad in by.etiketter():
		if str(rad.get("grupp", "")) == "hovring":
			hovring.append(str(rad["text"]))
	check(hovring.size() == 1, "hovringen visar husets namn", ", ".join(hovring))
	check(not hovring.is_empty() and hovring[0] == Tr.t("ui.by.plats.vardshus", "THE TAVERN"),
		"och det är RÄTT namn", ", ".join(hovring))
	# HOVRINGSGLÖDEN sitter PÅ huset (M126): banden ritas utanför husets EGEN ruta, så glödens yttre ruta
	# är den inre utvidgad med alla bandens bredd — en glöd som ritades kring en annan ruta (t.ex.
	# 2D-rutans) hade glidit ifrån huset. MÄTT på provbilden i 941x1018: de pixlar som skiljer sig från
	# samma bild UTAN hovring ligger i exakt husets ruta ± 6 vyn-px, på alla fyra sidor.
	var gr := by.glod_rect()
	var hr := by.byggnad_rect(2)
	check(gr.encloses(hr) and absf(gr.size.x - (hr.size.x + 12.0)) < 0.01
			and absf(gr.size.y - (hr.size.y + 12.0)) < 0.01
			and gr.get_center().distance_to(hr.get_center()) < 0.01,
		"hovringsglöden ligger runt husets EGEN ruta — 6 vyn-px utanför på varje sida, samma mitt",
		"glöd %s mot huset %s" % [str(gr), str(hr)])
	by.släpp_hovring()
	check(by.hovrad() == -1, "och hovringen släpps när pekaren lämnar")
	check(by.glod_rect() == Rect2(), "och då ritas ingen glöd alls", str(by.glod_rect()))
	by.free()
	vp1.queue_free()

	# ---------------------------------------------------------------- 2. SKÄRPAN
	print("")
	print("— 2. skärpan: en konstpixel = en skärmpixel —")
	# Konstens mått och fönstrets heltalsskala avgör om bilden ritas 1:1.
	var prov := VillageView.new()
	prov.size = VY
	var konst := prov.byscen()
	check(konst != null, "byns konst finns att mäta", "res://assets/ui/byn.png")
	if konst != null:
		# Utan korg (ett prov utan fönster) finns ingen skala att räkna mot — då ryms hela konstens
		# höjd i vyn, precis som förr.
		var b1 := prov.bild_storlek()
		check(absf(b1.x * float(konst.get_height()) - b1.y * float(konst.get_width())) < 1.0
				and prov.fönsterskala() == 1.0,
			"utan korg följer rutan konstens eget förhållande (ingen skevhet)",
			"%.1f x %.1f, skala %.0f" % [b1.x, b1.y, prov.fönsterskala()])
		# MED en korg i skala 3 (samma väg som spelet): konsten ska ritas i 1/3 vyn-pixel per
		# konstpixel — alltså EXAKT en skärmpixel per konstpixel, ingen omsampling.
		var korg := SubViewportContainer.new()
		korg.stretch = false
		korg.scale = Vector2(3, 3)
		var vp := SubViewport.new()
		vp.size = Vector2i(VY)
		korg.add_child(vp)
		root.add_child(korg)
		await process_frame                   # vyn måste vara i trädet innan `get_viewport()` svarar
		vp.add_child(prov)
		check(prov.fönsterskala() == 3.0, "fönstrets heltalsskala läses ur korgen",
			"%.0f" % prov.fönsterskala())
		var b3 := prov.bild_storlek()
		check(absf(b3.x * 3.0 - float(konst.get_width())) < 0.01
				and absf(b3.y * 3.0 - float(konst.get_height())) < 0.01,
			"i skala 3 ritas konsten 1:1 mot skärmpixlarna",
			"%.2f x %.2f vyn-px = %.1f x %.1f skärm-px mot konstens %d x %d"
				% [b3.x, b3.y, b3.x * 3.0, b3.y * 3.0, konst.get_width(), konst.get_height()])
		# Kanten LÅSES till pixelgriden: annars ligger konstens pixelkanter mitt emellan skärmens och
		# varje pixel blir omsamplad (2 px bred på sina ställen, 3 på andra).
		var steg := 1.0 / 3.0
		var låst := prov._pixel_låst(10.17)
		check(absf(låst / steg - roundf(låst / steg)) < 0.001,
			"konstens kant snäpps till en hel konstpixel",
			"10,17 -> %.4f vyn-px = %d konstpixlar" % [låst, int(roundf(låst / steg))])
		# Och den gamla vägen (fit-height, icke-heltalig) ska INTE vara den som används i spelet: den
		# gav 3,87 konstpixlar per vyn-pixel, alltså 0,775 per skärmpixel.
		var gammal := VY.y * float(konst.get_width()) / float(konst.get_height())
		check(absf(b3.x - gammal) > 100.0,
			"skalan är inte längre den gamla (hela höjden i vyn)",
			"%.1f mot gamla %.1f vyn-px" % [b3.x, gammal])
		prov.free()
		korg.free()
	else:
		prov.free()

	# ---------------------------------------------------------------- 3. GÅNGAREN
	print("")
	print("— 3. gångaren: EN figur, två skärmar —")
	var by2 := VillageView.new()
	by2.size = VY
	by2.visa(meta, order.size())
	var öppnade := []
	by2.vald.connect(func(skepp: String): öppnade.append(skepp))
	var g: Gångare = by2.gångaren()
	check(g != null, "byn har en gångare", "Gångare (ui/gangare.gd)")
	var ställe: Vector2 = by2.ståplats()
	check(by2.gå_till(3), "man kan öppna en plats (porten, plats 3)")
	# KARAKTÄREN STÅR PÅ GATAN (M141). Alex 16/10: *"Sen vill jag att ens karaktär står på gatan, och
	# inte menyn"* — han har sin egen fläck i byn, promenerar inte (M138) och flyttas INTE av menyraden.
	check(not g.går(), "figuren GÅR inte — han står stilla", "går=%s" % str(g.går()))
	check(g.pos().distance_to(ställe) < 0.5, "och står kvar på sin fläck på gatan",
		"%.2f px från fläcken" % g.pos().distance_to(ställe))
	check(öppnade == ["karta"], "platsen öppnas i samma anrop", str(öppnade))
	# VÄXLINGEN flyttar honom inte: platsen man valt visas av plattan, glöden och pilen på huset.
	öppnade.clear()
	by2.flytta(Vector2i(1, 0))
	check(not g.går() and g.pos().distance_to(ställe) < 0.5,
		"och att växla plats flyttar honom inte",
		"går=%s avstånd %.2f px" % [str(g.går()), g.pos().distance_to(ställe)])
	check(öppnade.is_empty(), "ett steg i sidled öppnar ingenting", str(öppnade))
	by2.free()

	# HJÄLTEN MAN VALDE RITAR BÅDE BYN OCH KARTAN (M138). Samma fil på båda ställena — det är hela
	# poängen med en markör: man ska känna igen sin figur var man än är.
	var vald_före: String = Meta.hjalte
	by2 = VillageView.new()
	by2.size = VY
	by2.visa(meta, order.size())
	by2._sätt_figur()
	var byväg_före: String = by2.figur_väg()
	var väljaren := HjältVal.new()
	väljaren.size = Vector2(941.0, HjältVal.PX + 12.0)
	check(väljaren.antal() == 12, "hjältvalet har de tolv hjältarna ur arket",
		"%d st" % väljaren.antal())
	# Fångas i en LISTA, inte i en vanlig variabel: en lambda tar sina lokala variabler med VÄRDE, så
	# en tilldelning inifrån lambda:n syns inte utanför (mätt: `bytt_till` förblev tom).
	var fångat: Array[String] = []
	väljaren.bytt.connect(func(h: String) -> void: fångat.append(h))
	väljaren.välj(1)
	check(Meta.hjalte == väljaren.id[1], "och ett klick sätter valet i Meta",
		"%s -> %s" % [väljaren.id[1], Meta.hjalte])
	check(fångat == [väljaren.id[1]], "valet sänds vidare (så skalet kan spara det)", str(fångat))
	by2._sätt_figur()
	check(by2.figur_väg() != byväg_före and by2.figur_väg().ends_with("%s.png" % Meta.hjalte),
		"byn byter figur när valet byts", by2.figur_väg())
	var kvy := WorldMapView.new()
	kvy.karta = Karta.ladda()
	kvy.visa(stages, order, meta)
	kvy._figur_rita()
	check(kvy.figur_väg() == by2.figur_väg(), "och kartan ritar SAMMA figur", kvy.figur_väg())
	# VALET ÖVERLEVER EN OMSTART: det ligger i sparfilen, inte bara i minnet.
	var provfil := "user://prov_hjalte.json"
	var m2 := Meta.new()
	m2.save(provfil)
	var laddad := Meta.load_or_new(provfil)
	check(laddad != null and laddad.to_dict()["hjalte"] == Meta.hjalte,
		"hjälten sparas i sparfilen", str(Meta.hjalte))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(provfil))
	Meta.hjalte = vald_före
	by2.free()
	väljaren.free()

	# SAMMA KOMPONENT PÅ KARTAN. Klassens identitet är beviset: två kopior hade varit två saker som
	# glider isär, och Alex bad om EN karaktär som går på båda ställena.
	check(kvy.gångaren() != null and kvy.gångaren() is Gångare,
		"kartan har samma Gångare-klass som byn — inte en egen kopia",
		"%s" % ("Gångare" if kvy.gångaren() is Gångare else "annat"))
	kvy.gå_till(0)
	kvy.steg_kamera(0.0, true)
	var mål_nod := -1
	for i in kvy.antal():
		if i != 0 and kvy.läge(i) != "låst":
			mål_nod = i
			break
	if mål_nod < 0:
		mål_nod = mini(1, kvy.antal() - 1)
	var kg: Gångare = kvy.gångaren()
	var ktill: Vector2 = kvy.gångpunkt(mål_nod)
	var svar := kvy.gå_till_och_in(mål_nod)
	# INGET GÅNG-LÄGE (M138): svaret är inte "går", för det finns ingenting att vänta på.
	check(str(svar["reason"]) != "går", "Enter öppnar platsen direkt — inget gångläge att vänta på",
		"reason=%s" % str(svar["reason"]))
	check(not kg.går() and kg.pos().distance_to(ktill) < 0.5,
		"och figuren står på NODEN i samma anrop",
		"går=%s, %.2f px från noden" % [str(kg.går()), kg.pos().distance_to(ktill)])
	check(kvy.panel_öppen() or not kvy.besked().is_empty(),
		"panelen (eller beskedet) är uppe direkt",
		"panel=%s besked='%s'" % [str(kvy.panel_öppen()), kvy.besked()])
	kvy.free()

	# ---------------------------------------------------------------- 4. 2.5D: paralax och distansblur
	print("")
	print("— 4. 2.5D: paralax och distansblur —")
	var by3 := VillageView.new()
	by3.size = VY
	# Vyn måste in i trädet först: lagrens skärmpunkter läses ur deras canvas-transform, och den
	# svarar bara för en nod som står i en scen (samma skäl som korgen i avsnitt 2).
	var korg4 := SubViewportContainer.new()
	korg4.stretch = false
	korg4.scale = Vector2(3, 3)
	var vp4 := SubViewport.new()
	vp4.size = Vector2i(VY)
	korg4.add_child(vp4)
	root.add_child(korg4)
	await process_frame
	vp4.add_child(by3)
	by3.visa(meta, order.size())
	await process_frame
	var scen := by3.scen3d()
	check(scen != null and scen.klar(), "byn ritas som 2D-lager med en kamera, inte som en platt bild", "ByScen")
	var art := by3.byscen()
	var ax := float(art.get_width()) * 0.5
	var ay := float(art.get_height()) * 0.5
	# FAKTORERNA: bakgrund och hus har OLIKA parallaxfaktor. Det är faktorn som ger paralaxen.
	var faktorer := scen.lagerfaktorer()
	check(faktorer.y > faktorer.x, "bakgrund och hus har OLIKA parallaxfaktor",
		"bakgrund %.2f, hus %.2f (kvot %.2f)" % [faktorer.x, faktorer.y, faktorer.y / faktorer.x])
	# PLACERINGEN: i vila ligger konsten exakt där den platta bilden ritade den.
	scen.sätt_kamera(0.0, 0.0)
	await process_frame
	var förväntad: float = ax * (by3.bild_storlek().x / float(art.get_width())) - by3.pan()
	var p0 := scen.bak_skärmpunkt(ax, ay)
	check(absf(p0.x - förväntad) < 0.5, "konsten hamnar där den platta bilden hade ritat den",
		"%.1f px mot väntade %.1f" % [p0.x, förväntad])
	# PARALAXEN. Kameran pannar N px; samma konstpunkt mäts på bakgrundens och husens lager.
	# Parallax2D lägger sin förskjutning i sin EGEN processnotis, alltså i bildrutan EFTER att
	# kameran flyttats — precis som i en körande körning. Provet väntar därför en bildruta, samma väg
	# som spelet tar, i stället för att läsa ett halvfärdigt mellanläge.
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
	check(absf(flytt_a - n * faktorer.x) < 0.5, "bakgrunden flyttar sig precis kamerans väg gånger sin faktor",
		"%.1f px av %.1f" % [flytt_a, n])
	check(absf(flytt_b - n * faktorer.y) < 0.5, "husen flyttar sig MER — de står närmare kameran",
		"%.1f px (%.1f × %.2f)" % [flytt_b, n, faktorer.y])
	check(absf(flytt_a - flytt_b) > 1.0,
		"lagren rör sig OLIKA mycket — det är paralaxen (lika mycket är ingen paralax)",
		"bakgrund %.1f px mot hus %.1f px (%.2f gånger, kvoten 1/%.2f)" % [flytt_a, flytt_b, flytt_b / flytt_a, ByScen.DJUP_S])
	scen.sätt_kamera(0.0, 0.0)
	# AVSTÅNDSBLURRET (Alex: "lägg på distance blur"). I 2D finns inget djupblurr: det bakersta lagret
	# får en FÖRMJUKAD kopia av konsten, och husen ritas alltid ur den SKARPA urklippta texturen.
	var bak_tex := by3.bak_textur()
	check(bak_tex != null, "scenen ritar bakgrunden ur bak.png (husen borttagna)", "bak.png")
	var mjuk := scen.mjuk_kopia(bak_tex)
	var rå: float = _kantkontrast(bak_tex.get_image())
	check(mjuk != null and mjuk.get_width() == bak_tex.get_width(),
		"den förmjukade kopian har bakgrundens mått", "%dx%d" % [mjuk.get_width(), mjuk.get_height()])
	var mjuk_kk: float = _kantkontrast(mjuk.get_image())
	var hus_kk: float = _kantkontrast(load("res://assets/ui/byn/hus_tradet.png").get_image())
	check(mjuk_kk < rå * 0.9, "och är MÄTBART mjukare än bakgrunden — webbygget blir inte skarpt",
		"kantkontrast %.2f mot bakgrundens %.2f (%.0f %% lägre)" % [mjuk_kk, rå, 100.0 * (1.0 - mjuk_kk / rå)])
	check(hus_kk > mjuk_kk * 2.0, "medan husen är SKARPA — de ritas ur sin egen urklippta textur",
		"husets kantkontrast %.1f mot den mjuka bakgrundens %.1f" % [hus_kk, mjuk_kk])
	# och SKÄRPAN i den här vyn är kvar: 1:1-vägen gäller fortfarande efter 2D-ombyggnaden
	check(by3.fönsterskala() == 3.0, "vyn ritarläget är oförändrat skarpt (skala 3)", "%.0f" % by3.fönsterskala())

	# ---------------------------------------------------------------- 5. PILEN (M124)
	print("")
	print("— 5. valet märks i listen: pilen, inte en ram runt huset —")
	# RAMEN OCH LJUSVÄGGEN RUNT DET VALDA HUSET. Alex: *"Det är idag någon weird ram runt det som är
	# markerat, och det har jag tyckt väldigt illa om. Jag vill bara ha en pil ovanför det man valt i
	# listen under."* Markeringen har varit en gul ruta och sedan en glöd som följde husets silhuett;
	# båda ritade kring HELA huset (MÄTT på provbilden i 941x1018: 522x795 px, från fönstrets överkant
	# ned till gatan). Ingen av dem får finnas kvar — för NÅGON plats, inte bara den första.
	#
	# PILEN: en pil, ovanför den valda postens cell i listen, med spetsen nedåt. Rutorna mäts i
	# FÖNSTERpixlar (vyn ritas i heltalsskala 3 här, precis som i spelet), och den ska FLYTTA sig med
	# valet — ett fast läge hade pekat på samma post hela gatan igenom.
	var poster: int = VillageView.PLATSER.size()
	var cell: float = by3._vy().x / float(poster) * by3.fönsterskala()
	var ramar := []
	var fel_mitt := []
	var pil_rutor := []
	var pil_mitt := []
	for i in poster:
		while by3.valt_index() != i:
			if not by3.flytta(Vector2i(1, 0)):
				break
		by3.pan_klart()
		var mr := _markering_ruta(by3)
		if mr != Rect2():
			ramar.append("%s %s" % [str(VillageView.PLATSER[i]["id"]), str(mr)])
		var pr := by3.pil_rect()
		pil_rutor.append(Rect2(pr.position * by3.fönsterskala(), pr.size * by3.fönsterskala()))
		pil_mitt.append(pr.get_center().x * by3.fönsterskala())
		if absf(pil_mitt[i] - (float(i) + 0.5) * cell) > 1.0 * by3.fönsterskala():
			fel_mitt.append("%s %.1f mot %.1f" % [str(VillageView.PLATSER[i]["id"]),
				pil_mitt[i], (float(i) + 0.5) * cell])
	check(ramar.is_empty(), "ingen ram och ingen ljusvägg ritas runt det valda huset",
		"markeringens ruta är tom för varje plats (0 px)" if ramar.is_empty() else ", ".join(ramar))
	check(fel_mitt.is_empty(), "pilen sitter centrerad över den valda posten",
		"postmitt i fönsterpixlar: %s" % str(pil_mitt))
	# FLYTTEN: i sidled med valet (en cell per steg), i SAMMA höjd — en pil som vandrar i höjdled pekar
	# inte längre på en post.
	var flytt: float = absf(pil_mitt[poster - 1] - pil_mitt[0])
	var väntad_flytt: float = float(poster - 1) * cell
	check(absf(flytt - väntad_flytt) <= 1.0 * by3.fönsterskala()
			and absf(pil_rutor[poster - 1].position.y - pil_rutor[0].position.y) < 0.01,
		"och den flyttar sig med valet — en cell i sidled per steg, i samma höjd",
		"%.0f px mellan första och sista posten (%.0f väntat), y %.0f" % [flytt, väntad_flytt, pil_rutor[0].position.y])
	# OVANFÖR LISTEN, med spetsen nedåt: pilen ska peka PÅ posten, inte ligga inne i den.
	check(pil_rutor[0].end.y <= by3.bar_topp() * by3.fönsterskala() + 0.01,
		"pilen ligger ovanför listen och pekar ned på posten",
		"pilens underkant %.0f, listens överkant %.0f" % [pil_rutor[0].end.y, by3.bar_topp() * by3.fönsterskala()])
	by3.free()
	korg4.queue_free()

	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
