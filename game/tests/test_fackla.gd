## Facklan: att den sitter PÅ väggen (inte som en platta på golvet), att den hänger UNDER taket, och
## att LJUSET ÄR KVAR när vilan är tagen.
##
## Provet finns för två fel Alex såg, och båda mäts på DET SOM RITAS — noder i världen, inte på att en
## funktion finns:
##
##   1. "varför försvinner elden om man går på den? Det är menat som ljuskälla." Facklan är en
##      plockbar utforskningsnod (kistan, spaden, facklan): `run.enter_node` sätter `cleared`, och
##      `_add_lagor` HOPPADE ÖVER en cleared nod. Alltså slocknade både lågan och ljuset i samma stund
##      som man klev på rutan. Belöningen får tas en gång — ljuset får inte tas.
##   2. "antingen skall det vara en fackla som sitter på väggen, eller vedklabbar på golvet" — den
##      platta bruna skivan på golvet var varken eller. Ett takprov fäller om facklan skär genom taket.
##
##   godot --headless --script res://tests/test_fackla.gd
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

## Facklans delar i världen: hållaren (platta/krans/skaft/huvud), lågan och ljuset vid en ruta.
##
## Delarna letas upp i GRUPPEN "fackla", inte på namn: Godot döper om dubbletter ("@fackla_platta@2"),
## så ett namnfilter hittade bara den första facklan (mätt: 4 av 24 noder). Vilken del det är står i
## metan "del".
func _vid(main: Node, p: Vector2i) -> Dictionary:
	var ut: Dictionary = {"delar": [], "lågor": [], "ljus": []}
	var centrum := Vector3(p.x + 0.5, 0, p.y + 0.5)
	for n in main.get_tree().get_nodes_in_group("fackla"):
		if n.global_position.distance_to(centrum) < 1.5:
			ut["delar"].append(str(n.get_meta("del", "")))
	for n in main.world.find_children("*", "GPUParticles3D", true, false):
		if n.name == "låga" and n.global_position.distance_to(centrum) < 1.5:
			ut["lågor"].append(n)
	for l in main._lågor:
		if l.global_position.distance_to(centrum) < 1.5:
			ut["ljus"].append(l)
	return ut

func _torch_nodes(main: Node) -> Array:
	var ut: Array = []
	for n in main.run.explore.floor_ref.nodes:
		if n.kind == "torch":
			ut.append(n)
	return ut

func _initialize() -> void:
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_01", 20260919)
	await process_frame
	await process_frame

	var facklor := _torch_nodes(main)
	check(facklor.size() > 0, "våningen har facklor att prova", "%d st" % facklor.size())
	if facklor.is_empty():
		quit(1)
		return

	print("")
	print("— facklan är ett föremål på väggen, inte en platta på golvet —")
	var tunn: Array = []
	var löst: Array = []
	var på_golv: Array = []
	for n in facklor:
		var v := _vid(main, n.pos)
		# Delarna: plattan mot väggen, kransen, skaftet och huvudet. En platta på golvet hade varit
		# EN del (och ingen hållare alls).
		if not (v["delar"].has("fackla_platta") and v["delar"].has("fackla_krans")
				and v["delar"].has("fackla_skaft") and v["delar"].has("fackla_huvud")):
			tunn.append("%s: %s" % [str(n.pos), ", ".join(v["delar"])])
		# Lågan och ljuset ska sitta PÅ väggen: en bit bort från rutans mitt, åt något håll.
		if v["lågor"].is_empty() or v["ljus"].is_empty():
			continue
		var låga: Vector3 = (v["lågor"][0] as GPUParticles3D).global_position
		var från_centrum := Vector2(låga.x - (n.pos.x + 0.5), låga.z - (n.pos.y + 0.5)).length()
		if från_centrum < 0.1:
			löst.append("%s: %.2f m" % [str(n.pos), från_centrum])
		if låga.y < 0.25:
			på_golv.append("%s: y %.2f" % [str(n.pos), låga.y])
	check(tunn.is_empty(), "varje fackla har hållare, krans, skaft och huvud",
		"" if tunn.is_empty() else "; ".join(tunn))
	check(löst.is_empty(), "lågan sitter vid VÄGGEN, inte i rutans mitt",
		"" if löst.is_empty() else "; ".join(löst))
	check(på_golv.is_empty(), "och inte nere på golvet", "" if på_golv.is_empty() else "; ".join(på_golv))

	print("")
	print("— speglingen är EN ratt, inte en siffra på två ställen (M77) —")
	# Alex: *"Speculariteten är alldeles för hög, och behöver dras ned till kanske 10 % av nuvarande
	# nivå."* Provet mäter att LJUS_GLANS faktiskt NÅR ljusen: stod det en egen siffra på varje ljus
	# kunde ratten flyttas utan att något hände, och då mäter glansprovet en gammal inställning.
	var glans: float = preload("res://main.gd").LJUS_GLANS
	var fel_glans: Array = []
	for l in main._lågor:
		if not is_equal_approx(l.light_specular, glans):
			fel_glans.append("fackla %.2f" % l.light_specular)
	if main._lykta != null and not is_equal_approx(main._lykta.light_specular, glans):
		fel_glans.append("lyktan %.2f" % main._lykta.light_specular)
	check(fel_glans.is_empty(), "varje ljus bär speglingsratten LJUS_GLANS (%.2f)" % glans,
		"" if fel_glans.is_empty() else "; ".join(fel_glans))

	print("")
	print("— hela lågan är inne i rummet: under taket —")
	# Takhöjden är rummets EGEN siffra (TAK_HÖJD), inte ett fast tal i provet: flyttas taket ska
	# provet flytta med, och då faller det bara om facklan faktiskt skär genom taket.
	var över: Array = []
	for n in facklor:
		var v := _vid(main, n.pos)
		if v["lågor"].is_empty():
			continue
		var låga: Vector3 = (v["lågor"][0] as GPUParticles3D).global_position
		var krans: Vector3 = main._fackel_krans(n.pos, main._ut_från_vägg(main._vägg_sida(main.run.explore.floor_ref, n.pos)))
		var topp: float = låga.y + main.LAGA_ÖVERKANT
		print("      %s: golv 0,00  krans %.2f  låga %.2f  lågans topp %.2f  tak %.2f"
			% [str(n.pos), krans.y, låga.y, topp, main.TAK_HÖJD])
		if topp > main.TAK_HÖJD:
			över.append("%s: topp %.2f över tak %.2f" % [str(n.pos), topp, main.TAK_HÖJD])
	check(över.is_empty(), "lågan ligger under takplanet, inte genom det",
		"" if över.is_empty() else "; ".join(över))
	# FLIT-BORT: det fasta talet från första försöket (1,36 m) låg ÖVER taket på 1,0. Provet fäller
	# alltså på riktigt, och det är samma räkning som ovan.
	check(1.36 + main.LAGA_ÖVERKANT > main.TAK_HÖJD, "flit-bort: det gamla fasta talet fällde provet",
		"1,36 + %.2f mot tak %.2f" % [main.LAGA_ÖVERKANT, main.TAK_HÖJD])
	check(main.TAK_HÖJD - main.LAGA_TAK_AVSTÅND > 0.0,
		"takhöjden räcker för en låga med luft kvar", "tak %.2f" % main.TAK_HÖJD)

	print("")
	print("— en ruta utan vägg får en ställning på golvet (genererade våningar) —")
	# Den genererade våningen lägger facklan på en golvruta inuti ett rum, och där finns ingen vägg
	# att hänga på. Då ska facklan stå på en ställning — inte försvinna och inte hamna i taket.
	var öppen := Dungeon.Floor.new()
	öppen.w = 5
	öppen.h = 5
	for y in 5:
		var rad: Array[int] = []
		for x in 5:
			rad.append(Dungeon.FLOOR)
		öppen.tiles.append(rad)
	check(main._vägg_sida(öppen, Vector2i(2, 2)) == Vector2i.ZERO,
		"rutan utan vägggranne känns igen")
	var ställning: Vector3 = main._fackel_låga(Vector2i(2, 2), Vector3.ZERO)
	# Skaftet lutar även på ställningen (32 grader), så lågan hamnar en bit vid sidan av stolpen.
	# Stolpen står mitt i rutan, och lågan ska vara KVAR i rutan.
	var från_centrum := Vector2(ställning.x - 2.5, ställning.z - 2.5).length()
	check(från_centrum < 0.25, "ställningen står i rutan och lågan lutar in över den",
		"%.2f m från mitten" % från_centrum)
	check(ställning.y + main.LAGA_ÖVERKANT <= main.TAK_HÖJD,
		"och dess låga är också under taket", "topp %.2f" % (ställning.y + main.LAGA_ÖVERKANT))

	print("")
	print("— LJUSET STANNAR när vilan är tagen —")
	# Vägen in är spelets egen: spelaren går till rutan och `_enter_node_here` (samma anrop som
	# tangentbordet gör). Sedan byggs våningen om precis som vid ett tillståndsbyte.
	var fackla: Dungeon.FloorNode = facklor[0]
	var före := _vid(main, fackla.pos)
	var ljus_före: Array = före["ljus"]
	check(före["lågor"].size() > 0 and ljus_före.size() > 0,
		"facklan lyser innan vilan är tagen",
		"%d lågor, %d ljus, energi %.2f" % [före["lågor"].size(), ljus_före.size(),
			(0.0 if ljus_före.is_empty() else (ljus_före[0] as OmniLight3D).light_energy)])
	var energi_före := 0.0 if ljus_före.is_empty() else (ljus_före[0] as OmniLight3D).light_energy
	main.run.hp = main.run.max_hp * 0.5            # skadad: vilan SKA ge något, annars mäter provet inget
	var hp_skadad: float = main.run.hp
	var varv := 0
	while main.run.explore.pos != fackla.pos and varv < 400:
		varv += 1
		if main.run.explore.step_toward(fackla.pos) != "":
			break
		await process_frame
	check(main.run.explore.pos == fackla.pos, "spelaren står på facklans ruta", "%d steg" % varv)
	if main.run.explore.pos == fackla.pos:
		main._enter_node_here()                    # samma väg som tangentbordet
		await process_frame
		await process_frame
	check(fackla.cleared, "vilan är tagen en gång")
	check(main.run.hp > hp_skadad, "och den gav något", "hp %.0f -> %.0f"
		% [hp_skadad, main.run.hp])
	# ... och det som faktiskt ritas, EFTER att belöningen är tagen:
	var efter := _vid(main, fackla.pos)
	check(efter["ljus"].size() > 0, "ljuskällan finns kvar efter att vilan är tagen",
		"%d ljus" % efter["ljus"].size())
	var energi_efter := 0.0 if efter["ljus"].is_empty() else (efter["ljus"][0] as OmniLight3D).light_energy
	check(energi_efter > 0.0, "och den är TÄND (energi över noll)", "%.2f (före %.2f)"
		% [energi_efter, energi_före])
	check(efter["lågor"].size() > 0, "lågan brinner fortfarande", "%d lågor" % efter["lågor"].size())
	check(efter["delar"].has("fackla_platta") and efter["delar"].has("fackla_skaft"),
		"hållaren står kvar", ", ".join(efter["delar"]))
	check(efter["ljus"].size() == före["ljus"].size(), "ljuset varken försvinner eller fördubblas",
		"%d efter mot %d före" % [efter["ljus"].size(), före["ljus"].size()])
	# Belöningen får bara tas EN gång: samma ruta igen ska inte läka igen.
	var hp_efter: float = main.run.hp
	main.run.hp = hp_efter * 0.5
	main._enter_node_here()
	await process_frame
	check(absf(main.run.hp - hp_efter * 0.5) < 0.001, "och vilan kan inte tas om",
		"hp %.0f -> %.0f (oförändrat)" % [hp_efter * 0.5, main.run.hp])
	# Facklan är fortfarande en LJUSKÄLLA i listan som fladdrar i _process: utan den slocknar elden
	# (ljuset står still) eller slocknar helt (noden är borta).
	var i_listan := 0
	for l in main._lågor:
		if l.global_position.distance_to(Vector3(fackla.pos.x + 0.5, 0, fackla.pos.y + 0.5)) < 1.5:
			i_listan += 1
	check(i_listan == 1, "facklan står i fladdrets lista, en gång", "%d post(er)" % i_listan)

	# MATERIALET (M59): järnet ska ha metall OCH kant, träet ska vara matt. Alex: *"att metall ser ut
	# som metall"*. Provet frågar samma funktion som materialet gör (`_är_järn`), så en del inte kan
	# byta sida utan att provet faller — och flit-bort är att sätta `JARN_METALL := 0.0`.
	print("— järn och trä —")
	var järn_antal := 0
	var trä_antal := 0
	for n in main.get_tree().get_nodes_in_group("fackla"):
		if not (n is MeshInstance3D):
			continue
		var del_namn := str(n.get_meta("del", ""))
		if not del_namn.begins_with("fackla_"):
			continue
		var mm: Material = (n as MeshInstance3D).mesh.material
		if not (mm is StandardMaterial3D):
			continue
		var sm := mm as StandardMaterial3D
		if main._är_järn(del_namn):
			järn_antal += 1
			check(sm.metallic > 0.0 and sm.rim_enabled and sm.roughness < 0.5,
				"järndelen %s är metall med kant" % del_namn,
				"metall %.2f råhet %.2f" % [sm.metallic, sm.roughness])
		else:
			trä_antal += 1
			check(sm.metallic == 0.0 and not sm.rim_enabled, "trädelen %s är matt" % del_namn,
				"metall %.2f" % sm.metallic)
	check(järn_antal > 0 and trä_antal > 0, "både järn och trä finns i facklan",
		"%d järn, %d trä" % [järn_antal, trä_antal])

	Meta.fotolage(false)
	print("")
	print("  TOTALT: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
