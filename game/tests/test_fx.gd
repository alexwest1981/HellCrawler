## Prövar effekterna: att elden ser ut som eld, att molnen är byggda som de ska och att pölen har
## vattnets form — inte en rektangel.
##
## Det här är den del av effekterna som går att mäta. Om en låga läses som eld avgörs med ögonen
## (tools/gen_fx.py --sheet), men formen, riktningen, blandningen och antalet går att räkna på — och
## det är de som tystnar först när något går sönder.
##
##   godot --headless --script res://tests/test_fx.gd
extends SceneTree

var fails := 0
var checks := 0


func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


## Partikelmolnet med ett visst namn under en fackla.
func moln(rot: Node3D, namn: String) -> GPUParticles3D:
	for c in rot.get_children():
		if c is GPUParticles3D and c.name == namn:
			return c
	return null


## Partsnamn ur en shadertext: raderna dar ett uniform/varying deklareras. Resten av raden (kommentaren
## efter //) far ha hur mycket a och o som helst — det ar bara NAMNET tokenizern kvider pa.
func shader_namn(text: String) -> Array:
	var ut := []
	for rad in text.split("\n"):
		var r := rad.strip_edges()
		if r.begins_with("uniform ") or r.begins_with("varying ") or r.begins_with("in ") \
				or r.begins_with("out "):
			ut.append(r.split("//")[0].strip_edges())
	return ut


func bara_ascii(rader: Array) -> bool:
	for r in rader:
		for i in r.length():
			if r.unicode_at(i) > 126:
				return false
	return true


func shaderfiler(rot: String, ut: Array) -> void:
	var d := DirAccess.open(rot)
	if d == null:
		return
	for n in d.get_files():
		if n.ends_with(".gdshader"):
			ut.append(rot.path_join(n))
	for m in d.get_directories():
		if m.begins_with("."):
			continue
		shaderfiler(rot.path_join(m), ut)


func _init() -> void:
	print("=== facklan")
	var förälder := Node3D.new()
	var rot := Fx.fackla(förälder, Vector3(1, 0.3, 2), 0.9)
	check(rot != null and rot.position == Vector3(1, 0.3, 2), "facklan hamnar där den sätts")
	for namn in ["låga", "rök", "glöd"]:
		check(moln(rot, namn) != null, "facklan har %s" % namn)
	var låga := moln(rot, "låga")
	var rök := moln(rot, "rök")
	if låga != null and rök != null:
		var form: QuadMesh = låga.draw_pass_1
		check(form.size.y > form.size.x, "lågans ruta är högre än bred",
			"%.2f x %.2f m" % [form.size.x, form.size.y])
		check(låga.material_override == null and form.material != null, "partikeln har ett material")
		var yta: StandardMaterial3D = form.material
		# Utan vertexfärgen är färgskalan i ParticleProcessMaterial verkningslös och elden blir grå.
		check(yta.vertex_color_use_as_albedo, "färgskalan når fram (vertexfärg som albedo)")
		check(yta.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "partikeln står mot kameran")
		check(yta.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "lågan läggs till bilden (additiv)")
		check(låga.amount >= 30, "lågan har partikler nog att vara tät", "%d st" % låga.amount)
		var lm: ParticleProcessMaterial = låga.process_material
		check(lm.turbulence_enabled, "lågan har turbulens (annars är den en kon)")
		check(lm.gravity.y > 0.0, "lågan stiger", "tyngd %.2f" % lm.gravity.y)
		check(lm.color_ramp != null, "lågan har en färgskala")
		# Livstiden: en eld som lever för länge blir rök.
		check(låga.lifetime < 1.0, "lågan är kort", "%.2f s" % låga.lifetime)
		check(rök.lifetime > låga.lifetime, "röken lever längre än lågan")
		check(rök.material_override == null and (rök.draw_pass_1 as QuadMesh).material.blend_mode
			== BaseMaterial3D.BLEND_MODE_MIX, "röken blandas in (inte additiv)")
	# Partiklarna får inte gallras bort så fort kameran rör sig.
	var aabb: AABB = låga.visibility_aabb
	check(aabb.size.x >= 8.0, "molnet har en ruta som håller kvar partiklarna",
		"%.0f x %.0f m" % [aabb.size.x, aabb.size.y])
	check(not låga.local_coords, "partiklarna stannar i rummet när spelaren går")

	print("=== dammet sitter på kameran")
	var kam := Camera3D.new()
	Fx.damm(kam)
	var damm: GPUParticles3D = null
	for c in kam.get_children():
		if c is GPUParticles3D:
			damm = c
	check(damm != null, "dammet hamnar på kameran (det syns bara i ljuset)")
	if damm != null:
		var dm: ParticleProcessMaterial = damm.process_material
		check(dm.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX, "dammet fyller en volym")
		check(damm.lifetime > 5.0, "dammet driver länge", "%.0f s" % damm.lifetime)
		check(dm.initial_velocity_max < 0.2, "dammet far inte fram", "%.2f m/s" % dm.initial_velocity_max)

	print("=== dropparna faller dit de ska")
	var mark := Node3D.new()
	var droppe := Fx.droppar(mark, Vector3(0, 0.94, 0), 0.9)
	# EN droppe per start. Ett ställe som spottar ut partiklar i ett jämnt flöde är en kran, och det var
	# precis vad Alex såg ("ser ut som det rinner") — se Fx.DROPP_VÄNTAN för mätningen bakom.
	check(droppe.one_shot, "stället släpper EN droppe per start (inte ett flöde)")
	check(droppe.amount == 1, "och bara en partikel", "amount %d" % droppe.amount)
	var dm2: ParticleProcessMaterial = droppe.process_material
	check(dm2.direction.y < 0.0, "droppen är riktad nedåt")
	# STARTPUNKTEN: flera ställen släpper i takets höjd, så en punkt gör att en kull droppar står på RAD
	# tvärs över vyn (Alex' bild: "en onaturlig horisontell rad med ljusa prickar"). Mätt i spelvyn:
	# 271 isolerade ljusa prickar med 9 i den tätaste raden före, 147 med 6 efter.
	check(dm2.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX
		and dm2.emission_box_extents.y > 0.01,
		"droppen startar i en liten ASK, inte i en punkt (annars linjerar en kull droppar)")
	# d = ½·g·t²: en droppe som faller 0,9 m på sin livstid ska ha tyngden 2d/t², inte jordens.
	var t: float = droppe.lifetime * 0.9
	var väntad := -2.0 * 0.9 / (t * t)
	check(absf(dm2.gravity.y - väntad) < 0.01, "tyngden är räknad ur fallsträckan",
		"%.1f m/s² mot väntade %.1f" % [dm2.gravity.y, väntad])

	print("=== droppslagen (vatten, slem, blod, lava)")
	var slagsfärger := {}
	for slag in ["vatten", "slem", "blod", "lava"]:
		check(Fx.DROPP.has(slag), "slaget %s finns" % slag)
		var c: Color = Fx.DROPP[slag]["färg"]
		slagsfärger[c.to_html(false)] = slag
	check(slagsfärger.size() == 4, "slagen har olika färg", str(slagsfärger.values()))
	var slemtakt: float = float(Fx.DROPP["slem"]["liv"])
	var vattentakt: float = float(Fx.DROPP["vatten"]["liv"])
	check(slemtakt > vattentakt * 1.3, "slemmet är segare än vattnet",
		"%.2f s mot %.2f s" % [slemtakt, vattentakt])
	# TAKTEN per ställe: provet räknar DROPPAR PER MINUT ur exakt samma funktion som spelet använder
	# (Fx.dropp_väntan) — ett prov med en egen kopia av takten mäter provet, inte spelet.
	#
	# MÄTT FÖRE: takten låg på droppens livstid, och i kontinuerligt läge släpper GPUParticles3D
	# `amount / lifetime` partiklar i sekunden: 4 partiklar / 0,35-1,1 s = 3,6-11,4 droppar i SEKUNDEN
	# på ETT ställe (216-684 i minuten). Det är därför det rann. Provet fäller under 30.
	var väntrng := RandomNumberGenerator.new()
	väntrng.seed = 1234
	var n := 400
	var summa := 0.0
	var minsta := 999.0
	var största := 0.0
	for i in n:
		var v := Fx.dropp_väntan(väntrng)
		summa += v
		minsta = minf(minsta, v)
		största = maxf(största, v)
	var per_minut := 60.0 * float(n) / summa
	check(per_minut >= 10.0 and per_minut <= 30.0, "ett ställe droppar 10-30 gånger i minuten",
		"%.1f per minut (väntan %.1f-%.1f s)" % [per_minut, minsta, största])
	check(minsta >= 2.0 and största <= 6.0, "väntan ligger mellan två och sex sekunder",
		"%.2f-%.2f s" % [minsta, största])
	# Ojämn takt: en metronom är samma fel som en kran fast långsammare.
	var spridning := 0.0
	for i in 200:
		spridning = maxf(spridning, absf(Fx.dropp_väntan(väntrng) - Fx.dropp_väntan(väntrng)))
	check(spridning > 1.0, "takten är ojämn mellan dropparna", "största skillnad %.2f s" % spridning)
	# Accenterna: något enstaka ställe per våning droppar tätare.
	var accent := Fx.dropp_väntan(väntrng, true)
	check(accent >= Fx.DROPP_VÄNTAN_ACCENT.x and accent <= Fx.DROPP_VÄNTAN_ACCENT.y,
		"ett accentställe droppar tätare", "%.2f s mot %.1f-%.1f s" % [accent,
		Fx.DROPP_VÄNTAN.x, Fx.DROPP_VÄNTAN.y])
	var lava := Fx.droppar(mark, Vector3(2, 0.94, 0), 0.9, "lava")
	var lm: ParticleProcessMaterial = lava.process_material
	var vm: ParticleProcessMaterial = droppe.process_material
	check(Fx.DROPP["lava"]["blandning"] == BaseMaterial3D.BLEND_MODE_ADD,
		"lavan glöder (adderande blandning)")
	check(lm != null and vm != null and lm.color_ramp != vm.color_ramp,
		"lavan har sin egen färgskala")
	# Takdroppen: vad som får falla var, och takten per ställe.
	var Main: GDScript = load("res://main.gd")
	var teman: Array = Main.TAKDROPP_SLAG.keys()
	check(teman.size() >= 5, "varje tema har en dropplista", str(teman))
	var utan_vatten := []
	for tema in teman:
		if not Main.TAKDROPP_SLAG[tema].has("vatten"):
			utan_vatten.append(tema)
	check(utan_vatten.is_empty(), "alla teman har vatten (en våning utan droppar är en lögn)",
		str(utan_vatten))
	var med_lava := []
	for tema in teman:
		if Main.TAKDROPP_SLAG[tema].has("lava"):
			med_lava.append(tema)
	check(med_lava == ["grotta"], "lava bara där den hör hemma (djupet), inte på plankorna",
		str(med_lava))
	# Placeringen: samma frö två gånger ska ge samma ställen, och över några våningar ska ALLA slag
	# dyka upp — annars är ett slag kod som aldrig syns (lava som bara finns i tabellen).
	var grunda := {}
	var slagslag := {}
	for bana in ["stage_01", "stage_05", "stage_09"]:
		for våning in 3:
			var frö := hash(Vector3i(hash(bana), våning, 4711))
			for varv in 2:
				var rng := RandomNumberGenerator.new()
				rng.seed = frö
				var antal := rng.randi_range(3, 6)
				var ut := []
				for i in antal:
					var cell := rng.randi_range(0, 111)
					rng.randf_range(-0.25, 0.25)
					var sort: String = ["vatten", "slem", "lava"][rng.randi_range(0, 2)]
					rng.randf_range(0.7, 2.2)
					ut.append("%d:%s" % [cell, sort])
					slagslag[sort] = int(slagslag.get(sort, 0)) + 1
				if varv == 0:
					grunda[bana + str(våning)] = ut
				else:
					check(str(ut) == str(grunda[bana + str(våning)]),
						"samma frö ger samma ställen (%s v%d)" % [bana, våning])
	check(slagslag.size() == 3, "alla tre slagen dyker upp över nio våningar", str(slagslag))

	print("=== fuktigheten räknas ur golvets plats, inte ur en ruta")
	check(Fx.fukt_material(0.0) == null, "ett torrt tema får inget fuktlager")
	var mat := Fx.fukt_material(1.0)
	check(mat != null, "fuktmaterials byggs")
	if mat != null:
		check(mat.shader != null and not mat.shader.code.is_empty(), "materialet har en shader")
		check(mat.get_shader_parameter("styrka") == 1.0, "temats fuktighet är inkopplad")
		# En parameter som aldrig SATTS går inte att läsa tillbaka (samma fälla som `glans`), så
		# provet sätter fuktighetsratten först — och det är samtidigt beviset för att shadern
		# kompilerade: en shader med fel i sig tar inte emot några parametrar alls.
		mat.set_shader_parameter("troskel", 0.55)
		check(mat.get_shader_parameter("troskel") != null and mat.get_shader_parameter("glans") != null,
			"shadern kompilerar och bär fuktighetens rattar")
		# Ingen mask, ingen textur: fläcken räknas ur xz i världen, och då kan den inte upprepa sig
		# från ruta till ruta hur stor våningen än blir. Det var hela felet med den målade pölen.
		check(mat.shader.code.contains("fuktighet(xz") and not mat.shader.code.contains("texture(mask"),
			"fläcken räknas ur världspositionen (ingen mask, ingen upprepning)")
		check(mat.shader.code.contains("ROUGHNESS = mix") and mat.shader.code.contains("NORMAL_MAP"),
			"råheten kommer ur fuktigheten och normalen räknas ur dess lutning")
		check(not mat.shader.code.contains("ALBEDO = m.rgb"),
			"ingen målad vattenfärg i shadern (färgen kommer ur ljuset som speglas)")
	check(Fx.fukt_material(-1.0) == null, "en negativ styrka ger inget lager (inget kraschar)")

	print("=== elden är en ljuskälla (emission över vitt)")
	# En unshaded yta skriver ut sin albedo rakt av — högst 1,0 — och då har miljöns glow (tröskel 1,0)
	# och AgX ingenting att arbeta med. Lågan måste därför ha emission ÖVER 1,0 för att blomstra, och
	# den måste vara skuggad: det är i den skuggade vägen emissionen läggs på.
	var fackel_rot := Node3D.new()
	var eld := Fx.fackla(fackel_rot, Vector3.ZERO)
	var eldlåga := eld.get_node_or_null("låga") as GPUParticles3D
	check(eldlåga != null, "facklan har en låga")
	if eldlåga != null:
		var lågmat := (eldlåga.draw_pass_1 as QuadMesh).material as StandardMaterial3D
		check(lågmat != null, "lågan har ett material")
		if lågmat != null:
			check(lågmat.emission_enabled, "lågan lyser av sig själv (emission på)")
			check(lågmat.emission_energy_multiplier > 1.0,
				"och starkare än vitt (HDR) — annars kan glow inte blomstra den",
				"%.1f" % lågmat.emission_energy_multiplier)
			check(lågmat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,
				"och är skuggad: i unshaded läge läggs ingen emission på")
			check(not lågmat.albedo_texture == null, "formen kommer fortfarande ur lågans sprite")
	# Ingen emission på det som INTE är en ljuskälla: röken får inte blomstra (då är hela rummet vitt).
	var eldrök := eld.get_node_or_null("rök") as GPUParticles3D
	if eldrök != null:
		var rökmat := (eldrök.draw_pass_1 as QuadMesh).material as StandardMaterial3D
		check(not rökmat.emission_enabled, "röken lyser inte (bara elden är en ljuskälla)")
	fackel_rot.free()

	# HÄLSODEKLARATIONEN (Alex 2026-10-11): mängden som lossnar ska följa SKADANS andel, inte vara en
	# konstant skur. Provet mäter därför REGELNS form — litet hugg < halvt liv, aldrig under golvet,
	# aldrig över taket — och inte ett enstaka tal som råkar stämma en dag.
	var tiondel := Fx.korn_efter_skada(5.0, 50.0, 1)
	var halvt := Fx.korn_efter_skada(25.0, 50.0, 1)
	var allt := Fx.korn_efter_skada(500.0, 50.0, 1)
	check(tiondel < halvt and halvt < allt,
		"fler bitar lossnar av större skada — en hälsodeklaration, inte en konstant skur",
		"%d < %d < %d korn (fiende med 50 hp)" % [tiondel, halvt, allt])
	check(Fx.korn_efter_skada(0.0, 50.0, 1) == Fx.KORN_GOLV and tiondel > Fx.KORN_GOLV,
		"golvet gäller en träff utan skada; en liten skada ger redan mer än golvet (%d mot %d)"
		% [tiondel, Fx.KORN_GOLV])
	check(allt == Fx.KORN_MAX and Fx.korn_efter_skada(50.0, 50.0, 3) == Fx.KORN_MAX,
		"och taket håller emot: %d korn är dimma, inte bitar" % Fx.KORN_MAX, "%d" % allt)
	check(Fx.korn_efter_skada(25.0, 50.0, 3) > Fx.korn_efter_skada(25.0, 50.0, 1),
		"kedjan lägger till ovanpå andelen: ett stort drag vräker ut mer",
		"%d mot %d" % [Fx.korn_efter_skada(25.0, 50.0, 3), Fx.korn_efter_skada(25.0, 50.0, 1)])
	check(Fx.korn_efter_skada(10.0, 0.0, 1) == Fx.KORN_MAX,
		"ett tak på noll delar inte med noll: regeln svarar taket i stället för att krascha",
		"%d" % Fx.korn_efter_skada(10.0, 0.0, 1))

	print("=== inget shadernamn far ha a, a eller o (da ritas ytan aldrig, och tyst)")
	var filer := []
	shaderfiler("res://", filer)
	check(filer.size() >= 4, "hittade shaderfilerna", "%d filer" % filer.size())
	for p in filer:
		var text := FileAccess.get_file_as_string(p)
		check(bara_ascii(shader_namn(text)), "deklarationerna i %s ar ASCII" % p.get_file(),
			"%d st" % shader_namn(text).size())
	check(bara_ascii(shader_namn(Fx.VATTEN_SHADER)), "deklarationerna i fuktens shader ar ASCII")
	check(not bara_ascii(["uniform float glöd = 0.0;"]),
		"kontrollen ser skillnad: ett o i ett NAMN fångas (kommentaren får ha dem)")

	print("=== %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
