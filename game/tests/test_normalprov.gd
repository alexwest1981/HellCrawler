## Provet biter på DET MATERIAL SOM FAKTISKT RITAS — inte på "något material någonstans".
##
## Alex såg våningen som helt platt trots att rutornas normal-kartor lutar 15-20 grader. Provet mäter
## därför materialvägen ända fram till den mesh som ritas, för det är där en normalmap kan försvinna
## tyst: en MultiMesh ritar mesh:ens material (inte nodens), materialet kan skuggas av en
## material_override, och en mesh utan tangenter/UV får sin normalmap förkastad utan ett ord.
##
## Mätt 2026-09-20, i en körning med samma kamera (`tools/play.sh -- normalprov=0`): skillnaden mellan
## normal_scale 0,0 och spelets 1,0 är medel 5,26 och p99 60 per pixel, mot 0,83 / 2 för två bilder med
## SAMMA värde (fladdrande facklor, temporal GI). Kartan når alltså shadern — 8,0 ger 15,2 / 97 — och
## materialvägen var frisk hela tiden. Det här provet är till för att den slutsatsen ska hålla: blir
## ytan någon gång platt igen, faller provet på den yta som ritas.
##
## FLIT-BORT: sätt `main._kartor = false` innan `_start_run` och provet faller på "varje ritad yta
## bär sin normal_texture" (0 av 11) — det är beviset för att det kan gå rött.
##   godot --headless --script res://tests/test_normalprov.gd
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

func _initialize() -> void:
	# Fotoläget först: provet startar en riktig körning, och en körning som bara mäter får inte skriva
	# i spelarens profil (samma flaskhals som test_sparfil vaktar).
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.world == null or main.world.find_children("*", "MultiMeshInstance3D", true, false).is_empty(),
		"spelet startar i byn — ingen våning ritas än")
	main._start_run("stage_01", 20260919)
	await process_frame

	var mmis: Array = main.world.find_children("*", "MultiMeshInstance3D", true, false)
	check(mmis.size() > 0, "våningen ritas med MultiMesh", "%d ytor" % mmis.size())

	# Det som fäller provet: en yta som ritas utan sin normalkarta ÄR en platt yta.
	var utan: Array = []
	var utan_orm: Array = []
	var utan_tangent: Array = []
	var utan_uv: Array = []
	var med_override: Array = []
	var hoppade := 0
	for n in mmis:
		var mi: MultiMeshInstance3D = n
		if mi.name.begins_with("dekor_"):
			# Dekorationen (M84) är en billboard av ett shader-material — en SPRITE, inte en yta med relief.
			# Den ska inte bära någon normalkarta, precis som rekvisiderna (Sprite3D) inte gör; provet
			# mäter ytorna. Utan detta rad fälldes gräset för att det inte är en vägg.
			hoppade += 1
			continue
		var m: Material = mi.multimesh.mesh.material
		if not (m is StandardMaterial3D):
			utan.append("%s (inget standardmaterial)" % mi.name)
			continue
		if m.albedo_texture == null or m.normal_texture == null:
			utan.append(mi.name)
		if m.albedo_texture == m.normal_texture and m.normal_texture != null:
			utan.append("%s (normal = albedo, fel karta)" % mi.name)
		if m.roughness_texture == null:
			utan_orm.append(mi.name)
		if m.normal_scale <= 0.0:
			utan.append("%s (normal_scale %.1f)" % [mi.name, m.normal_scale])
		if mi.material_override != null:
			med_override.append(mi.name)
		# En normalmap UTAN tangenter eller UV förkastas tyst av shadern.
		var arr: Array = mi.multimesh.mesh.surface_get_arrays(0)
		if arr.size() <= Mesh.ARRAY_TANGENT or (arr[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty():
			utan_tangent.append(mi.name)
		if arr.size() <= Mesh.ARRAY_TEX_UV or (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).is_empty():
			utan_uv.append(mi.name)

	var n_ytor := mmis.size() - hoppade
	check(utan.is_empty(), "varje ritad yta bär sin normal_texture",
		"%d av %d%s" % [n_ytor - utan.size(), n_ytor, "" if utan.is_empty() else ", utan: " + ", ".join(utan)])
	check(utan_orm.is_empty(), "och sin ORM-karta (råhet, metall, ocklusion)",
		"" if utan_orm.is_empty() else ", ".join(utan_orm))
	check(utan_tangent.is_empty() and utan_uv.is_empty(), "meshen bär tangenter och UV",
		"tangent saknas: %d, uv saknas: %d" % [utan_tangent.size(), utan_uv.size()])
	# En override på noden vinner över mesh:ens material, och då ritas ytan utan kartorna hur fina de
	# än är i mesh:en. (Det var precis den fällan ett tidigare mätprov gick i: det satte normal_scale på
	# material som ingen yta ritade.)
	check(med_override.is_empty(), "ingen yta skuggar mesh-materialet med en override",
		"" if med_override.is_empty() else ", ".join(med_override))

	# Kartorna ska vara SAMMA tema som albedon, inte en gammal fil: tre av varandra oberoende kort ur
	# samma familj. Ett byte av tema ska flytta alla tre.
	var m0: StandardMaterial3D = (mmis[0] as MultiMeshInstance3D).multimesh.mesh.material
	var stammar := [
		m0.albedo_texture.resource_path.get_basename(),
		m0.normal_texture.resource_path.get_basename().trim_suffix("_n"),
		m0.roughness_texture.resource_path.get_basename().trim_suffix("_orm"),
	]
	check(stammar[0] == stammar[1] and stammar[0] == stammar[2], "albedo, normal och ORM hör till samma ruta",
		", ".join(stammar))
	# En albedo som är en KÖRTIDSKOPIA (dämpad kant, uppskalad bild) har ingen resource_path alls, och
	# då jämför kontrollen ovan en tom sträng mot en filsökväg. Den här raden säger varför, i stället
	# för att peka på normal- och ORM-kartorna som är oskyldiga. (Mätt: den fällde provet i en körning
	# och felet såg ut som "kartorna saknas på super-rutan" — de fanns, albedon var kopian.)
	check(not m0.albedo_texture.resource_path.is_empty(),
		"albedon är filens textur, inte en körtidskopia (då är normal/ORM inte problemet)",
		"albedo: %s" % m0.albedo_texture.resource_path)

	# --- ljuset på ytorna: ratten som gör reliefen SYNLIG --------------------------------
	# Ytorna är inte platta i data (ovan), rummet var för MÖRKT för att ögat skulle läsa dem.
	# Provet mäter att LJUS_STYRKA NÅR FRAM till ljusen i världen: `_fladdra` skrev över lyktans
	# energi varje bildruta förut, och då gav den tredje ratten i normalprovet samma bild två
	# gånger — en ratt som inte når fram ser ut som en ratt som inte gör någon skillnad.
	var lykta: OmniLight3D = main._lykta
	check(lykta != null, "lyktan finns i vyn")
	if lykta != null:
		var väntat: float = main.LYKTA_ENERGI * main.LJUS_STYRKA
		check(absf(lykta.light_energy - väntat) < väntat * 0.05,
			"lyktans ljus är LYKTA_ENERGI × LJUS_STYRKA",
			"%.2f mot %.2f" % [lykta.light_energy, väntat])
	var torrfel := ""
	for l in main._lågor:
		var v: float = main.LAGA_ENERGI * main.LJUS_STYRKA
		if absf(l.light_energy - v) > v * 0.2:
			torrfel = "%.2f mot %.2f" % [l.light_energy, v]
			break
	check(not main._lågor.is_empty() and torrfel.is_empty(),
		"facklorna bär samma faktor (%d facklor)" % main._lågor.size(), torrfel)
	# Fladdret ritar om energin varje bildruta: faktorn ska stå kvar efter ett antal bildrutor.
	for i in 10:
		await process_frame
	if lykta != null:
		var väntat2: float = main.LYKTA_ENERGI * main.LJUS_STYRKA
		check(absf(lykta.light_energy - väntat2) < väntat2 * 0.05,
			"och fladdret skriver inte över den", "%.2f" % lykta.light_energy)
	# Ratten provet drar i: 1,0 = läget FÖRE ändringen (samma yta, samma kamera, en körning).
	main._ljus_styrka(1.0)
	if lykta != null:
		check(absf(lykta.light_energy - main.LYKTA_ENERGI) < main.LYKTA_ENERGI * 0.05,
			"ratten sätter läget före ändringen (×1,0)", "%.2f" % lykta.light_energy)
	main._ljus_styrka(main.LJUS_STYRKA)
	check(main.LJUS_STYRKA > 1.0, "ändringen är en HÖJNING av ljuset på ytorna",
		"×%.2f" % main.LJUS_STYRKA)

	# --- GLANSEN: högdagern ---------------------------------------------------------------
	# Reliefen (ovan) gör ytorna LÄSBARA; glansen gör dem blanka där de ska vara det. Ljuset måste
	# bära `light_specular`, annars kan ingen yta få en högdager hur blank den än är — den var 0,0 på
	# lyktan och facklorna ("ingen glans: rutorna är målade, inte polerade").
	check(lykta != null and lykta.light_specular > 0.0,
		"lyktan bär light_specular (annars ingen högdager)",
		"%.2f" % lykta.light_specular)
	var med_glans := 0
	for l in main._lågor:
		if l.light_specular > 0.0:
			med_glans += 1
	check(not main._lågor.is_empty() and med_glans == main._lågor.size(),
		"och facklorna bär den (%d av %d)" % [med_glans, main._lågor.size()])

	# Speglingens regel mot DET MATERIAL SOM RITAS: mattare än tröskeln = speglingen AV (annars blir
	# stenen mjölkig, mätt: hela vyn lyfte 0,172 -> 0,214 och p50 0,094 -> 0,146), blankare = PÅ
	# (annars finns ingen högdager kvar). Råheten läses ur materialets EGEN ORM-karta.
	var matta := 0
	var blanka := 0
	var felglans: Array = []
	for n in mmis:
		# Untyped on purpose: the water lies in the same list as a ShaderMaterial, and naming the
		# type here (StandardMaterial3D) killed the whole test with a script error. A type error in
		# _initialize does NOT end the tree — it keeps running, so the suite reported a 420-second
		# timeout with no reason at all, and the reason only showed in the raw output.
		var mat: Material = (n as MultiMeshInstance3D).multimesh.mesh.material
		if not (mat is StandardMaterial3D):
			continue
		var m := mat as StandardMaterial3D
		if m.roughness_texture == null:
			continue
		var rå: float = main._radhet(m.roughness_texture)
		var matt: bool = m.specular_mode == BaseMaterial3D.SPECULAR_DISABLED
		if matt:
			matta += 1
		else:
			blanka += 1
		# REGELN ÄR BYTT (M59): speglingen följer nu den BLÖTA ANDELEN, inte råhetens medelvärde.
		# Alex: *"så väggar kan se fuktiga ut, så det blänker gentemot ljus"* — en vägg med våta
		# rinningar har hög medelråhet (stenen runt omkring är torr) och blev "matt" med den gamla
		# regeln, alltså ingen högdager alls på det blöta.
		var blöt: float = main._blöt_andel(m.roughness_texture, main.GLANS_BLÖT)
		if matt != (blöt < main.GLANS_BLÖT_ANDEL):
			felglans.append("%s (blött %.0f %%, spegling %s)" % [(n as MultiMeshInstance3D).name,
				blöt * 100.0, "av" if matt else "på"])
	check(felglans.is_empty(), "speglingen följer hur blöt ytan är (gräns %.0f %%)"
		% (main.GLANS_BLÖT_ANDEL * 100.0),
		"%d matta, %d blanka%s" % [matta, blanka, "" if felglans.is_empty() else ", fel: " + ", ".join(felglans)])
	check(blanka > 0, "de våta ytorna får spegling", "%d av %d ytor" % [blanka, matta + blanka])

	# Ratten provet drar i: den ska NÅ alla ritade ytor i BÅDA riktningarna. En ratt som inte når fram
	# ger samma bild två gånger och ser ut som "glansen gör ingen skillnad" (samma fälla som `_ljus_styrka`).
	var n_glansytor: int = main._ytmaterial().size()
	check(main._yta_glans_svep(-2.0) == n_glansytor and main._yta_glans_svep(-1.0) == n_glansytor,
		"glansratten når varje ritad yta (%d)" % n_glansytor)
	main._yta_glans_svep(main.GLANS_BLÖT_ANDEL)

	# Järnet (M59): Alex: *"att metall ser ut som metall"*. metallic ENSAM gjorde bara plattan
	# mörkare (mätt i M27: −126 av 255 utan en enda ljus högdager — en metall speglar bara det som
	# finns i den riktning ytan pekar, och i en mörk korridor finns inget där). Därför bär KANTEN
	# (Fresnel) metallen: metallic + rim + låg råhet, dömt på närbild i `-- fackelprov`.
	var järn: Array = main._järndelar()
	check(järn.size() > 0, "facklornas järndelar hittas", "%d material" % järn.size())
	var metallfel: Array = []
	for m in järn:
		var sm := m as StandardMaterial3D
		if sm.metallic <= 0.0 or not sm.rim_enabled:
			metallfel.append("metall %.2f kant %s" % [sm.metallic, sm.rim_enabled])
	check(metallfel.is_empty(), "och var och en är metall med kant", ", ".join(metallfel))

	# --- mätinstrumentet -----------------------------------------------------------------
	# Sifferraderna i normalprovet är bara värda något om fördelningen mäts rätt: en bild med kända
	# tal (halva svart, halva vit) ska ge medel 0,50, p50 1,00 och hälften mörka.
	var bild := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	bild.set_pixel(0, 0, Color.BLACK)
	bild.set_pixel(1, 0, Color.WHITE)
	bild.set_pixel(0, 1, Color.BLACK)
	bild.set_pixel(1, 1, Color.WHITE)
	var st: Dictionary = main._bild_statistik(bild)
	check(absf(st["medel"] - 0.5) < 0.01 and st["mörkt"] == 50 and st["ljust"] == 50,
		"ljusfördelningen mäts rätt på en bild med kända tal",
		"medel %.2f, p50 %.2f, mörkt %d %%, ljust %d %%"
			% [st["medel"], st["p50"], st["mörkt"], st["ljust"]])

	Meta.fotolage(false)
	print("  TOTALT: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
