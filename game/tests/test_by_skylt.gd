## EXIT-SKYLTEN I BYN (M123, omskrivet i M126): den ligger i konsten långt till höger om det som
## panoramabilden visade i nolläget, och den ska SYNAS och gå att KLICKA på.
##
## VARFÖR PROVET FANNS. Vyn och BILDEN kunde glida isär: `pan_klart()` satte vyns panorering utan att
## säga det till 2D-scenen, så bilden stod kvar på sin gamla plats medan vyn (och markörens ruta) redan
## hade flyttat sig. MÄTT vid sista platsen: `_pan` stod på 976 vyn-px medan bakgrunden ritades vid
## 0 — utsnittet var kvar på konstens x 0..1278, och EXIT-skylten (som ligger på konstens x
## 2424..2780) fanns inte i bilden fast vyns EGEN ruta för platsen låg mitt i vyn.
##
## VARFÖR DET SER ANNORLUNDA UT (M126). Det som ritas är nu `byn.glb`, inte panoramabilden, och 3D-byn
## står STILL. Hela byn ryms i vyn (den synliga bredden är kamerans 34 enheter), så skylten behöver
## inte panoreras in — den SYNS. Det som kan gå fel är i stället att klickrutan inte ligger på huset,
## och det är vad det här provet mäter: skyltens ruta är husets EGET läge i byn, projicerad med
## kamerans EGEN projektion, och ett klick i mitten öppnar EXIT.
##
##   godot --headless --script res://tests/test_by_skylt.gd
##
## Provet mäter i SPELETS EGEN SKALA — en `SubViewportContainer` med heltalsskalan 2 och en
## `SubViewport` i den, alltså samma 2:1-väg som `main.gd` bygger för 1280x720 (se `_korg` i
## `ui/village_view.gd`). Utan korgen räknar `bild_storlek()` om konsten till vyns HÖJD, och då är
## både utsnittet och panoreringens räckvidd något helt annat än spelarens.
##
##   1. SKYLTEN ÄR KONSTENS EGNA PIXLAR: hus_avsluta.png mot byn.png, rutan räknad ur `PLATSER`.
##   2. DEN SYNS OCH GÅR ATT KLICKA PÅ I 3D-BYN: rutan ligger i vyn, den är husets egen position
##      projicerad (samma px som kameran ger), och ett klick i mitten öppnar EXIT — inte grannen.
extends SceneTree

var fails := 0
var checks := 0

const BILD := "res://assets/ui/byn.png"
const TEST_PATH := "user://test_by_skylt_meta.json"
## Provtätheten i pixelkontrollen av texturen. Den FULLSTÄNDIGA kontrollen (varje pixel) gör
## `tools/gen_by_hus.py --check`, som sviten kör först; här räcker ett fint nät.
const STEG := 7
## Skalan `main.gd` ger korgen i 1280x720 (VY 480x270 och finns i projektet): fönstret delat i 270
## höga vyn. Provet bygger samma två lager och mäter i dem.
const SKALA := 2
const VY := Vector2(640, 360)

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Vyn i spelets skala: korgen (`SubViewportContainer`, heltalsskalan) → vyn (`SubViewport`) → byvyn.
## KORGEN MÅSTE IN I TRÄDET: `Node.get_viewport()` svarar null utanför det, och då tar `_korg()` i vyn
## den ANDRA vägen i `bild_storlek()` — konsten räknas om till vyns HÖJD och både utsnittet och
## panoreringens räckvidd blir en annan (mätt: huset mättes 97,5 px brett i stället för 178, och
## panoreringen kunde bara nå konstens x 899 i stället för 1952). Provet hade alltså svarat på en by
## spelaren aldrig ser. Väntan på en bildruta är samma väg `test_by_2p5d.gd` tar (M122): vyn får inte
## läggas i korgen medan trädet sätter upp sina barn.
func _bygg(korg_skala: int, korg_storlek: Vector2) -> Dictionary:
	var korg := SubViewportContainer.new()
	korg.stretch = false
	korg.size = korg_storlek
	korg.scale = Vector2(korg_skala, korg_skala)
	var vy := SubViewport.new()
	vy.size = Vector2i(int(korg_storlek.x), int(korg_storlek.y))
	korg.add_child(vy)
	root.add_child(korg)
	await process_frame
	var by := VillageView.new()
	vy.add_child(by)
	by.size = korg_storlek
	return {"korg": korg, "vy": vy, "by": by}

## Platsen vars `skepp` är "avsluta" (EXIT-skylten i bilden), eller -1. Slås upp i PLATSER i stället
## för att peka på ett index: platsernas ordning är gatans, och den kan ändras.
func _exit_plats() -> int:
	for i in VillageView.PLATSER.size():
		if str(VillageView.PLATSER[i]["skepp"]) == "avsluta":
			return i
	return -1

## Ett klick in i vyns EGEN ingång (`_gui_input`) — samma väg som spelets mus tar.
func _klick(by: VillageView, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	by._gui_input(e)

## Kör gångaren fram till målet i fasta steg: platsen öppnas först när figuren är framme.
func _gå_klart(g: Gångare, dt: float = 0.05) -> void:
	var antal := 0
	while g.går() and antal < 100000:
		g.steg(dt)
		antal += 1

## Konstens ruta för en plats, i konstens px — SAMMA formel som `village_view._konst_ruta` och
## `tools/gen_by_hus.py` använder, räknad ur `PLATSER` och bildens EGNA mått.
func _ruta(by: VillageView, i: int, art: Vector2) -> Rect2:
	return by._konst_ruta(i, art)

## Andelen px i nätet där byggnadens textur är BYTE-IDENTISK med sin ruta i konsten: [lika, synliga,
## tomma, olika_i_himlen]. Himlen (alfa 0) räknas för sig: Godots import nollställer RGB-värdet hos en
## HELT genomskinlig pixel (mätt: 248 px i hus_avsluta.png), och de pixlarna ritas aldrig — det som
## ska vara konstens egna pixlar är de SYNLIGA.
func _identisk(textur: Image, konst: Image, r: Rect2) -> Array:
	var lika := 0
	var synliga := 0
	var tom := 0
	var olika_himmel := 0
	for y in range(int(r.position.y), int(r.end.y), STEG):
		for x in range(int(r.position.x), int(r.end.x), STEG):
			var a := textur.get_pixel(x - int(r.position.x), y - int(r.position.y))
			var b := konst.get_pixel(x, y)
			if a.a == 0.0:
				tom += 1
				if a.r != b.r or a.g != b.g or a.b != b.b:
					olika_himmel += 1
				continue
			synliga += 1
			if a.r == b.r and a.g == b.g and a.b == b.b:
				lika += 1
	return [lika, synliga, tom, olika_himmel]

func _init() -> void:
	# Provet läser metat (`visa` behöver det) men ska aldrig röra spelarens sparfil.
	Meta.fotolage(true)
	_clean()
	var meta := Meta.load_or_new(TEST_PATH)
	var art_tex: Texture2D = load(BILD)
	check(art_tex != null, "byns bild finns på disken", BILD)
	if art_tex == null:
		print("\n%d kontroller, %d fel" % [checks, fails])
		quit(1)
		return
	var art := Vector2(art_tex.get_width(), art_tex.get_height())
	var konst := art_tex.get_image()
	if konst.get_format() != Image.FORMAT_RGBA8:
		konst.convert(Image.FORMAT_RGBA8)

	print("")
	print("— 1. EXIT-skylten är konsten, inte en ritad skylt —")
	var i_exit := _exit_plats()
	check(i_exit >= 0, "byn har en plats för EXIT-skylten", str(i_exit))
	if i_exit < 0:
		print("\n%d kontroller, %d fel" % [checks, fails])
		quit(1)
		return
	# KORGEN FÖRST: allt nedan mäts i spelets skala (se filhuvudet).
	var byggt: Dictionary = await _bygg(SKALA, VY)
	var by: VillageView = byggt["by"]
	check(by.fönsterskala() == float(SKALA), "provet mäter i spelets skala (korgen läses av vyn)",
		"skala %.0f, ruta %.1f x %.1f" % [by.fönsterskala(), by.bild_storlek().x, by.bild_storlek().y])
	by.visa(meta, 100)
	var r := _ruta(by, i_exit, art)
	check(r.size.x > 100.0 and r.size.y > 100.0, "skyltens ruta i konsten är ett hus, inte en prick",
		"%dx%d px på konstens %dx%d" % [r.size.x, r.size.y, art.x, art.y])
	# Skylten står till HÖGER om det nolläget visar — det är därför den måste ritas som eget objekt i
	# hus-lagret och panoreras in, i stället för att lita på bakgrunden.
	check(r.position.x > VY.x, "och den ligger utanför nollägets utsnitt — den måste panoreras in",
		"konstens x %.0f..%.0f mot vyns bredd %.0f" % [r.position.x, r.end.x, VY.x])
	var fil := "res://assets/ui/byn/hus_%s.png" % str(VillageView.PLATSER[i_exit]["id"])
	check(ResourceLoader.exists(fil), "skyltens egen textur finns", fil)
	var tex: Texture2D = load(fil) if ResourceLoader.exists(fil) else null
	if tex != null:
		var timg := tex.get_image()
		if timg.get_format() != Image.FORMAT_RGBA8:
			timg.convert(Image.FORMAT_RGBA8)
		check(Vector2(timg.get_width(), timg.get_height()) == r.size,
			"texturen är exakt sin ruta i konsten (mått)",
			"%dx%d mot %dx%d" % [timg.get_width(), timg.get_height(), r.size.x, r.size.y])
		var m := _identisk(timg, konst, r)
		check(int(m[0]) == int(m[1]),
			"och 0 ändrade RGB-pixlar där huset SYNS — det är KLIPPT ur bilden, inte ritat",
			"%d av %d synliga px i nätet (var %d:e), %d genomskinliga himmelpx" % [int(m[0]), int(m[1]), STEG, int(m[2])])
		check(int(m[2]) > 0 and int(m[1]) > 0,
			"med både genomskinlig himmel och ogenomskinligt hus (inte en tom eller hel ruta)",
			"%d himmel, %d hus av %d px" % [int(m[2]), int(m[1]), int(m[1]) + int(m[2])])

	print("")
	print("— 2. skylten SYNS och går att klicka på i 3D-byn —")
	# NOLLÄGET först: den valda platsen är den första, och 3D-byn står still — hela byn ryms i vyn
	# (den synliga bredden är kamerans 34 enheter). Motsatsen var felet i M123: då låg skylten
	# utanför utsnittet i nolläget och måste panoreras in.
	by.gå_till(0)
	by.pan_klart()
	check(absf(by.pan()) < 0.01, "första platsen står i nolläget (panoreringen 0)", "%.2f" % by.pan())
	var r0 := by.byggnad_rect(i_exit)
	check(r0.size.x > 0.0 and r0.size.y > 0.0,
		"skylten har alltså en klickruta REDAN i nolläget — den ligger i vyn", str(r0))
	check(r0.position.x >= 0.0 and r0.end.x <= VY.x and r0.position.y >= 0.0 and r0.end.y <= VY.y,
		"och hela rutan ligger innanför vyns kanter",
		"x %.0f..%.0f, y %.0f..%.0f av %.0f x %.0f" % [r0.position.x, r0.end.x, r0.position.y, r0.end.y, VY.x, VY.y])
	# RUTAN ÄR HUSETS EGET LÄGE I BYN, projicerat. Provet räknar fram samma ruta med kamerans EGEN
	# `unproject_position` — en ANNAN väg än vyns `projicera` — så en ruta som satt bredvid huset (som
	# 2D-rutan gjorde, mätt 114,5 px fel för just EXIT) faller här.
	var b3: By3D = by.by3d()
	check(b3 != null and b3.by != null, "3D-byn är byggd ur byn.glb", "By3D")
	if b3 == null:
		_clean()
		(byggt["korg"] as SubViewportContainer).free()
		print("\n%d kontroller, %d fel" % [checks, fails])
		quit(1)
		return
	var aabb := b3.hus_aabb("Exit")
	check(aabb.size != Vector3.ZERO, "och platsen finns som ett eget hus i modellen", str(aabb))
	var fel := 0.0
	for hörn in [aabb.position, aabb.position + aabb.size]:
		fel = maxf(fel, b3.kamera.unproject_position(hörn).distance_to(b3.projicera(hörn)))
	check(fel < 0.5, "klickrutan är husets position projicerad med kamerans EGEN projektion",
		"största avvikelse %.3f px" % fel)
	# KLICKET. Mitten av rutan — det hus man SER — ska öppna EXIT och ingenting annat.
	var mål := []
	by.vald.connect(func(skepp: String): mål.append(skepp))
	_klick(by, by.byggnad_rect(i_exit).get_center())
	_gå_klart(by.gångaren())
	check(mål == ["avsluta"], "klick i mitten av skyltens ruta öppnar EXIT", str(mål))

	print("")
	print("— 3. grannarna är kvar där de ska, och ingen ruta ligger ovanpå en annan mitt —")
	# Hela gatan går att klicka på: mitten av VARJE plats' ruta öppnar just den platsen.
	var bom := []
	for i in VillageView.PLATSER.size():
		mål.clear()
		_klick(by, by.byggnad_rect(i).get_center())
		_gå_klart(by.gångaren())
		if mål != [str(VillageView.PLATSER[i]["skepp"])]:
			bom.append("%s -> %s" % [str(VillageView.PLATSER[i]["id"]), str(mål)])
	check(bom.is_empty(), "klick i mitten av varje hus öppnar just den platsen", ", ".join(bom))
	# Skylten ligger till HÖGER om alla andra hus: ordningen på gatan är husens x i modellen.
	var höger_om := true
	for i in VillageView.PLATSER.size():
		if i != i_exit and by.byggnad_rect(i).get_center().x > by.byggnad_rect(i_exit).get_center().x:
			höger_om = false
	check(höger_om, "och skylten står längst till höger, som sist i PLATSER",
		"mitten %.0f av vyns %.0f px" % [by.byggnad_rect(i_exit).get_center().x, VY.x])

	_clean()
	(byggt["korg"] as SubViewportContainer).free()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
