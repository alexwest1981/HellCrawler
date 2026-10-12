## KARTAN SKA VARA KANT I KANT (M118).
##
## Alex: *"Kartan skall inte ha någon bottom bar, den skall vara kant i kant både uppe och nere"* — och
## efter en första rättning av VYN (M113, som gjorde spelvyn 100 % av fönstret): *"kartans bild tar
## bara ~50 % av fönstrets höjd, under den ligger informationsrutan, kontrollraden vid ~75 %, och de
## nedersta ~23 % är tom svart yta med en tunn grå ram längst ner"*. Felet satt alltså inte i vyn utan i
## KARTANS EGEN layout: rutan och ledtrådsraden låg i designmåttet 480x270 (rad 186-252 och 262) medan
## vyn nu är högre, så allt under rad 270 blev tom yta.
##
## Provet mäter fyra saker, i projektets och i Alex' fönsterstorlekar:
##   1. den RITADE kartytan (remsorna, exakt samma rutor som `_kartbild` ritar) täcker vyns fyra kanter
##      — andelen av vyns höjd är 100 %,
##   2. informationsremsan ligger i vyns NEDERKANT (ingen tom yta under den) och är tunn,
##   3. ingen vald plats hamnar bakom remsan,
##   4. nivåpanelen ryms ovanför remsan.
##
##   godot --headless --path game --script res://tests/test_karta_full.gd
extends SceneTree

var fails := 0
var checks := 0

## Fönstren provet mäter i: projektets standard, Alex' skärm, hans smala ruta och minimum.
## VYN RÄKNAS FRAM med spelets EGEN regel ur `main.gd::_placera_vy` (största hela skalan där 270
## spelpixlar ryms på höjden, bredden = fönsterbredden / skalan) — inte ur en gissning.
const FÖNSTER := [[1280, 720], [1896, 1018], [941, 1018], [800, 600]]
const VY_HÖJD := 270.0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## Vyns mått i spelpixlar för ett fönster, med `_placera_vy`s regel (utan remsa: skalet har ingen).
func _vy_storlek(f: Vector2) -> Vector2:
	var skala := 1.0
	for k in range(1, 9):
		if float(k) * VY_HÖJD > f.y:
			break
		skala = float(k)
	var bredd := clampf(floorf(f.x / skala), 160.0, 480.0 * 2.6)
	var höjd := maxf(VY_HÖJD, floorf(f.y / skala))
	return Vector2(bredd, höjd)

func _init() -> void:
	var stages := Stages.load_all()
	var order: Array = stages.keys()
	order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))
	var meta := Meta.load_or_new("user://test_karta_full_meta.json")
	var karta := Karta.ladda()
	check(karta.fel.is_empty(), "kartfilen är hel", ", ".join(karta.fel))

	print("")
	print("— kartan fyller vyn kant i kant, i varje fönster —")
	for f in FÖNSTER:
		var fönster := Vector2(f[0], f[1])
		var namn := "%dx%d" % [int(fönster.x), int(fönster.y)]
		var v := WorldMapView.new()
		v.karta = karta
		v.size = _vy_storlek(fönster)
		v.visa(stages, order, meta)
		# Kameran ställs på den valda platsen som spelet gör innan bilden tas (steg 0 = direkt).
		v.gå_till(0)
		v.steg_kamera(0.0, true)
		# 1) DEN RITADE YTAN. `kartyta()` är unionen av remsorna `_kartbild` ritar, alltså exakt det
		#    som hamnar i bild — inte en ram runt omkring.
		var yta := v.kartyta()
		var vy := v.size
		check(yta.position.y <= 0.5 and yta.position.x <= 0.5,
			"%s: kartytan når vyns över- och vänsterkant" % namn,
			"x %.0f, y %.0f" % [yta.position.x, yta.position.y])
		check(yta.end.x >= vy.x - 0.5 and yta.end.y >= vy.y - 0.5,
			"%s: och vyns under- och högerkant (kant i kant nertill)" % namn,
			"x %.0f av %.0f, y %.0f av %.0f" % [yta.end.x, vy.x, yta.end.y, vy.y])
		check(yta.size.y >= vy.y - 1.0,
			"%s: kartans andel av höjden" % namn,
			"%.0f %% (%.0f av %.0f spelpixlar)" % [100.0 * yta.size.y / maxf(1.0, vy.y),
				yta.size.y, vy.y])
		# 2) REMSAN: i vyns nederkant (inget under den) och tunn nog att vara ett överlägg.
		var rem := v.kort_ruta()
		check(absf(rem.end.y - vy.y) <= 0.5, "%s: remsan slutar på vyns nederkant" % namn,
			"%.0f mot %.0f" % [rem.end.y, vy.y])
		check(rem.size.y <= 48.0 and rem.size.y < vy.y * 0.25,
			"%s: remsan är ett tunt överlägg, inte ett band" % namn,
			"%.0f px = %.0f %% av höjden" % [rem.size.y, 100.0 * rem.size.y / vy.y])
		# 3) INGEN VALD PLATS BAKOM REMSAN — annars göms markören av sin egen information.
		var bakom: Array = []
		for i in v.antal():
			v.gå_till(i)
			v.steg_kamera(0.0, true)
			var p := v.plats(i)
			if p.y > v.bar() or p.y < 6.0 or p.x < 6.0 or p.x > vy.x - 6.0:
				bakom.append("%d(%.0f,%.0f)" % [i, p.x, p.y])
		check(bakom.is_empty(), "%s: varje vald plats hamnar i kartytan ovanför remsan" % namn,
			", ".join(bakom))
		# 4) NIVÅPANELEN: över remsan, innanför vyn, med plats för tio rader.
		var pan := v.panel_ruta()
		var sista: Rect2 = v.nivå_rad(0, Karta.MAX_NIVÅER - 1)
		check(pan.end.y <= v.bar() and pan.end.x <= vy.x - 6.0 and pan.position.x >= 6.0,
			"%s: nivåpanelen ryms ovanför remsan" % namn, str(pan))
		check(sista.end.y <= pan.end.y - 1.0, "%s: och rymmer tio nivårader" % namn,
			"%.0f mot %.0f" % [sista.end.y, pan.end.y])
		v.free()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
