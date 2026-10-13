## EXIT-SKYLTEN I BYN (M123): den ligger i konsten långt till höger om det vyn visar, och den ska
## SYNAS när man går till platsen — som sin EGEN byggnad i hus-lagret, klippt ur samma bild, och
## panoreringen ska flytta den precis som de andra husen.
##
## VARFÖR PROVET FINNS. Vyn och BILDEN kunde glida isär: `pan_klart()` satte vyns panorering utan att
## säga det till scenen, så bilden stod kvar på sin gamla plats medan vyn (och markörens ruta) redan
## hade flyttat sig. MÄTT vid sista platsen: `_pan` stod på 976 vyn-px medan bakgrunden ritades vid
## 0 — utsnittet var kvar på konstens x 0..1278, och EXIT-skylten (som ligger på konstens x
## 2424..2780) fanns inte i bilden fast vyns EGEN ruta för platsen låg mitt i vyn. Det är den
## fällan som gör att "skylten syns inte" kan vara sant i bild och falskt i vyns egna tal.
##
##   godot --headless --script res://tests/test_by_skylt.gd
##
## Provet mäter i SPELETS EGEN SKALA — en `SubViewportContainer` med heltalsskalan 2 och en
## `SubViewport` i den, alltså samma 2:1-väg som `main.gd` bygger för 1280x720 (se `_korg` i
## `ui/village_view.gd`). Utan korgen räknar `bild_storlek()` om konsten till vyns HÖJD, och då är
## både utsnittet och panoreringens räckvidd något helt annat än spelarens — mätningen hade svarat på
## en by ingen ser (mätt: panoreringen når konstens x 899 i stället för 1952).
##
##   1. SKYLTEN ÄR KONSTENS EGNA PIXLAR: hus_avsluta.png mot byn.png, rutan räknad ur `PLATSER`.
##   2. DEN SYNS NÄR PLATSEN VÄLJS: vyns ruta för den ligger i vyn, OCH scenen ritar den på SAMMA px
##      (vyns tal och bilden är samma sak — det var felet).
##   3. DEN FÖLJER PANORERINGEN som de andra husen, och nolläget (första platsen) rör inte bilden.
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
	print("— 2. skylten SYNS när platsen väljs: vyn och bilden pekar på samma px —")
	# Nolläget först: panoreringen 0, alltså konstens egen vänsterkant i vyns vänsterkant.
	by.gå_till(0)
	by.pan_klart()
	check(absf(by.pan()) < 0.01, "första platsen står i nolläget (panoreringen 0)", "%.2f" % by.pan())
	check(by.scen3d() != null and by.scen3d().klar(), "2D-scenen är byggd")
	var noll := by.scen3d().bak_skärmpunkt(0.0, 0.0) if by.scen3d() != null else Vector2(-1.0, -1.0)
	check(absf(noll.x) < 1.0, "och bildens vänsterkant står på vyns vänsterkant (utsnittet är konstens eget)",
		"%.2f px" % noll.x)
	var r0 := by.byggnad_rect(i_exit)
	check(r0.size.x <= 0.0 or r0.position.x >= VY.x,
		"skylten syns alltså inte i nolläget — den ligger utanför utsnittet", str(r0))
	# GÅ TILL SKYLTEN. Panorereringen ska flytta BILDEN med, inte bara vyns egen ruta.
	by.gå_till(i_exit)
	by.pan_klart()
	var r_exit := by.byggnad_rect(i_exit)
	check(r_exit.size.x > 0.0 and r_exit.size.y > 0.0,
		"platsen för EXIT-skylten hamnar i vyn när den väljs (rutan har en yta)", str(r_exit))
	check(r_exit.position.x >= 0.0 and r_exit.end.x <= VY.x,
		"och hela är innanför vyns kanter", "x %.0f..%.0f av %.0f" % [r_exit.position.x, r_exit.end.x, VY.x])
	# DET HÄR ÄR FELET SOM MÄTTES: vyns ruta och scenens egen canvas-transform måste säga SAMMA px.
	# Jämförelsen görs på husets FOT (konstens gatulinje): den ligger mitt i vyn, så varken rutan eller
	# scenen klipper den — toppen av huset ligger ovanför vyns överkant och klipps av rutan.
	var scen := by.scen3d()
	var scen_fot := scen.hus_skärmpunkt(i_exit, r.position.x, r.end.y)
	var ruta_fot := Vector2(r_exit.position.x, r_exit.end.y)
	check(scen_fot.distance_to(ruta_fot) < 1.5,
		"scenen ritar skylten där vyns ruta säger (vyn och bilden är samma sak)",
		"scen %.1f,%.1f mot ruta %.1f,%.1f" % [scen_fot.x, scen_fot.y, ruta_fot.x, ruta_fot.y])
	# Och huset ska stå på BAKGRUNDENS egen konst-x: bakgrunden och hus-lagret ritas i samma scen, så
	# samma konstpunkt hamnar på samma skärm-x (kameran står still här).
	var topp_bild := scen.bak_skärmpunkt(r.position.x, r.end.y)
	check(absf(scen_fot.x - topp_bild.x) < 1.0,
		"och skyltens vänsterkant står på samma konst-x som bakgrunden under den",
		"hus %.1f mot bakgrund %.1f" % [scen_fot.x, topp_bild.x])

	print("")
	print("— 3. skylten följer panoreringen som de andra husen —")
	# Två platser: skillnaden i panorering ska vara EXAKT skillnaden i scenens px för VARJE hus, alltså
	# också för skylten. Flyttade hus-lagret inte med skulle avståndet hus/bakgrund byta värde här.
	by.gå_till(0)
	by.pan_klart()
	var pan0 := by.pan()
	var start := []
	for i in VillageView.PLATSER.size():
		start.append(scen.hus_skärmpunkt(i, 0.0, 0.0).x)
	by.gå_till(i_exit)
	by.pan_klart()
	var pan1 := by.pan()
	var slut := []
	for i in VillageView.PLATSER.size():
		slut.append(scen.hus_skärmpunkt(i, 0.0, 0.0).x)
	var dpan := pan0 - pan1
	var fel := []
	for i in VillageView.PLATSER.size():
		var d: float = float(slut[i]) - float(start[i])
		if absf(d - dpan) > 1.0:
			fel.append("%s %.1f mot panoreringen %.1f" % [str(VillageView.PLATSER[i]["id"]), d, dpan])
	check(fel.is_empty(), "varje hus flyttar sig exakt med panoreringen, skylten inräknad",
		"%.0f px, %d hus: %s" % [dpan, slut.size(), ", ".join(fel)])
	check(absf(float(slut[i_exit]) - float(start[i_exit])) > 1.0,
		"och skylten flyttade sig (den hänger inte kvar på skärmen)",
		"%.1f px" % (float(slut[i_exit]) - float(start[i_exit])))

	_clean()
	(byggt["korg"] as SubViewportContainer).free()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
