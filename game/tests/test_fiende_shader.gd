## Önskemål 13: fiendernas egna shaders. Provet mäter MEKANISMEN och effekten i den mån det går
## huvudlöst (dummy-renderaren ger ingen rityta), inte hur det ser ut på skärm — det är Alex' dom.
##
## Två saker måste hålla:
##   1. En fiende UTAN egen shader ritas bit-identiskt med i dag: inget lager läggs till, och
##      texturpixlarna är exakt samma som PNG:n på disken.
##   2. En fiende MED egen shader (ash_maw → "rok") får ett lager med sin shader, och effekten går
##      att mäta: röken breder ut sig utanför silhuettens kontur. Provet räknar de pixlarna ur
##      SAMMA utspädningsformel som shadern (max av åtta grannar), med radien läst ur materialet —
##      så provet och shadern kan aldrig glida isär.
##
## KÖRNING: godot --headless --script res://tests/test_fiende_shader.gd
extends SceneTree

var main: Node

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
		fails += 1


## Räknar pixlar utanför silhuettens kontur som röken täcker. `rad` är utspädningsradien i texlar,
## samma formel som shaderns `bred` = max av åtta grannar på radien `rok_vidd` (se fiende_rok.gdshader).
## En källpixel med alfa under tröskeln (utanför figuren) som får en täckande granne (dilaterad alfa
## över tröskeln) är en rökpixel utanför konturen.
func _utanför_kontur(img: Image, ram: int, rad: int) -> int:
	if rad <= 0:
		return 0
	var höjd := img.get_height()
	var antal := 0
	for y in ram:
		for x in ram:
			if img.get_pixel(x, y).a >= 0.5:
				continue
			var bred := img.get_pixel(x, y).a
			for i in 8:
				var v := float(i) * 0.7853981634
				var dx := roundi(cos(v) * rad)
				var dy := roundi(sin(v) * rad)
				bred = maxf(bred, img.get_pixel(clampi(x + dx, 0, ram - 1),
					clampi(y + dy, 0, höjd - 1)).a)
			if bred > 0.5:
				antal += 1
	return antal


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var best := main.bestiary as Dictionary

	print("— datat pekar ut en shader —")
	var ash_def = best.get("ash_maw")
	var skit_def = best.get("skitterling")
	check(ash_def != null and str(ash_def.shader) == "rok",
		"ash_maw har en egen shader i fiendedatat", str(ash_def.shader) if ash_def != null else "saknas")
	check(skit_def != null and str(skit_def.shader) == "",
		"skitterling har ingen egen shader (standarden gör ingenting)")

	print("— överstyrningsvägen läses —")
	var rok: Shader = main._fiende_shader("ash_maw")
	check(rok != null and rok is Shader, "shadern läses ur datat för ash_maw")
	check(main._fiende_shader("skitterling") == null, "en fiende utan shader får null")
	# Överstyrningsvägen är just det som kan sluta läsas tyst: läses inte `shader`-fältet får
	# ash_maw inget lager, och då står den här kontrollen röd. Shadern måste vara rätt FIL, inte
	# bara "någon shader".
	if rok != null:
		check(rok.resource_path.ends_with("fiende_rok.gdshader"),
			"och det är just fiende_rok.gdshader", rok.resource_path)

	print("— lagret —")
	var tex_ash: Texture2D = main._enemy_tex("ash_maw")
	var tex_skit: Texture2D = main._enemy_tex("skitterling")
	var lager: Sprite3D = main._fiende_shader_lager("ash_maw", tex_ash)
	check(lager != null, "ash_maw får ett lager med sin shader")
	check(main._fiende_shader_lager("skitterling", tex_skit) == null,
		"skitterling får inget lager (bit-identisk väg)")
	if lager != null:
		var m := lager.material_override as ShaderMaterial
		check(lager.name == "shader" and lager.is_in_group("fiende_shader"),
			"lagret heter shader och ligger i fiende_shader-gruppen")
		check(m != null and m.shader == rok, "lagret bär just fiendens shader")
		# Lagret klipper sin ruta ur arket, så att röken följer rätt kroppsdel när figuren byter ruta.
		check(lager.texture is AtlasTexture and (lager.texture as AtlasTexture).atlas == tex_ash,
			"lagrets textur är en AtlasTexture på fiendens eget ark")
		main._ruta_lager(lager, 3)
		var region: Rect2 = (lager.texture as AtlasTexture).region
		var w: int = tex_ash.get_width() / 6
		check(absf(region.position.x - w * 3.0) < 0.5, "lagret följer figurens ruta (ruta 3)")
		var vidd: float = float(m.get_shader_parameter("rok_vidd"))
		var alfa: float = float(m.get_shader_parameter("rok_alfa"))
		check(vidd > 0.0, "röken har en utspädningsradie (rok_vidd %.3f)" % vidd)
		check(alfa > 0.0 and alfa < 1.0, "och en genomsläpplig alfa (rok_alfa %.2f)" % alfa)
		# EFFEKTEN (mätt ur samma formel som shadern): röken täcker pixlar UTANFÖR silhuetten, och
		# med radien noll (standarden som gör ingenting) täcks inga.
		var img: Image = tex_ash.get_image()
		var ram: int = img.get_height()          # rutan är kvadratisk: höjden är rutan
		var rad: int = roundi(vidd * ram)
		var utanför: int = _utanför_kontur(img, ram, rad)
		var noll: int = _utanför_kontur(img, ram, 0)
		check(utanför > 0, "röken täcker %d pixlar utanför silhuettens kontur" % utanför)
		check(noll == 0, "utan utspädning täcks 0 pixlar utanför (standarden gör ingenting)", "%d" % noll)

	print("— en fiende utan shader är bit-identisk med i dag —")
	# Skitterling har varken mask eller egen shader: figuren får varken material- eller shaderlager,
	# och texturen den ritar är SAMMA resurs som den commitade PNG:n — `_enemy_tex` lämnar den orörd
	# (ingen retusch, ingen omkodning). En byte-jämförelse mot den råa PNG:n duger inte här: Godots
	# importpipeline skiljer sig från `Image.load_from_file` (mätt: 8 015 px skilde på en orörd bild),
	# så referensen är i stället den exakta resursen dagens kod redan ritar.
	check(main._fiende_lager("skitterling", tex_skit) == null,
		"skitterling får heller inget materiallager (ingen mask)")
	var committad: Texture2D = load("res://assets/enemies/skitterling.png")
	check(tex_skit != null and tex_skit == committad,
		"figurens textur är den commitade PNG:n, orörd (%s)" % tex_skit.resource_path.get_file())

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
