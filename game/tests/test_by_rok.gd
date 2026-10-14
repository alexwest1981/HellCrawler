## RÖKEN I BYN: att molnen och rökbollarna är BORTA ur byn.glb, och att en smoke emitter står på
## deras uppmätta mitt i stället — med pixelkonstens stil.
##
## Alex: *"Röken som kommer upp ur ena huset är texturerad med sten — ta bort bollarna av rök och gör om
## dem till en smoke emitter."*
##
## Provet mäter fyra saker:
##   1. BORTA UR FILEN: byn.glb innehåller NOLL mesh-noder med rök- eller molnnamm (Chimney_Smoke_*,
##      Cloud_*). Exporten hoppar över dem (tools/apply_pixel_textures.py, sektionen SMOKE).
##   2. EMITTERN: en GPUParticles3D finns, den står på rökens uppmätta klustercentrum
##      (-10,65, 7,03, -1,85 i glTF-koordinater, ur tools/byn_mappning.json), den är TÄND och den
##      stiger uppåt.
##   3. STILEN: små, axelräta fyrkanter (QuadMesh, ingen rotation), oskuggat material, NEAREST-filtrering
##      och ingen glöd i scenens miljö — "ingen utsmetning" på varje ledd.
##   4. I BY-SCENEN, INTE I SPELLOOPEN: byn.glb har ingen konsument i main.tscn, och provet fäller om
##      en By3D-instans dyker upp där.
##
## BILDEN: `bildprovet` ritar två rutor av samma vy — en med röken tänd och en med den släkt — och
## räknar pixlarna som skiljer. Det är antalet rökpixlar i bilden. Headless finns ingen renderare, så
## där hoppas just det provet över (en rad utan ok/FEL, alltså inte räknad i någon summa):
##
##   tools/prov.sh -- --script res://tests/test_by_rok.gd       # med Xvfb, skriver PNG:n
##   godot --headless --script res://tests/test_by_rok.gd       # sviten
extends SceneTree

var fails := 0
var checks := 0

const RÖK_PLATS := Vector3(-10.65, 7.03, -1.85)
const PNG := "/home/alex/.hermes/cache/scratch/omd/byn_rok.png"

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## Alla noder i ett träd, på djupet (meshar, ljus, partiklar ... allt).
func _alla(n: Node, ut: Array = []) -> Array:
	ut.append(n)
	for b in n.get_children():
		_alla(b, ut)
	return ut

func _namn_med(rot: Node, ord: Array) -> Array:
	var ut: Array = []
	for n in _alla(rot):
		var l: String = str(n.name).to_lower()
		for k in ord:
			if l.contains(k):
				ut.append(n.name)
				break
	return ut

## Två bilder, antalet pixlar som skiljer (jämför bytes, inte pixel för pixel).
func _skillnad(a: Image, b: Image) -> int:
	if a == null or b == null:
		return -1
	var x: PackedByteArray = a.get_data()
	var y: PackedByteArray = b.get_data()
	if x.size() != y.size():
		return -1
	var n := 0
	for i in range(0, x.size(), 4):
		if x[i] != y[i] or x[i + 1] != y[i + 1] or x[i + 2] != y[i + 2]:
			n += 1
	return n

## Rökens AREA i bilden: referensrutan är exakt samma vy med röken SLÄCKT (emitting = false + restart
## tömmer molnet), och varje pixel som skiljer sig är en rökpixel. Att sätta amount = 0 duger inte:
## Godot vägrar ("Amount of particles cannot be smaller than 1"), och då står partiklarna kvar och
## skillnaden blir bara deras egen rörelse mellan två rutor (mätt: 1260 px — inte arean).
func _mät_area(sub: SubViewport, vy: By3D, spara: bool = false) -> int:
	vy.rök.emitting = false
	vy.rök.restart()
	for i in 5:
		await process_frame
	var utan: Image = sub.get_texture().get_image()
	vy.rök.emitting = true
	vy.rök.restart()
	for i in 40:
		await process_frame
	var med: Image = sub.get_texture().get_image()
	if spara and med != null and utan != null:
		med.save_png(PNG)
		utan.save_png(PNG.replace(".png", "_utan.png"))
	return _skillnad(med, utan)

func _initialize() -> void:
	print("=== RÖKEN I BYN ===")
	var bild := DisplayServer.get_name() != "headless"

	# -- 1. BORTA UR FILEN
	var pack: PackedScene = load(By3D.GLB)
	check(pack != null, "byn.glb laddar som PackedScene")
	if pack == null:
		print("=== TOTALT (rök): %d kontroller, %d fel ===" % [checks, fails])
		quit(1)
		return
	var råt: Node = pack.instantiate()
	root.add_child(råt)
	await process_frame
	var kvar := _namn_med(råt, ["smoke", "cloud", "chimney_smoke", "puff"])
	check(kvar.is_empty(), "0 rök-/moln-noder kvar i byn.glb", "hittade %d: %s" % [kvar.size(), str(kvar.slice(0, 5))])
	var meshar: Array = []
	for n in _alla(råt):
		if n is MeshInstance3D:
			meshar.append(n)
	check(meshar.size() > 1800, "byn finns kvar i filen", "%d mesh-noder" % meshar.size())
	råt.queue_free()
	await process_frame

	# -- 2. EMITTERN. Vyn ligger i en egen SubViewport (det är den som kan bli en bild), så nodträdet
	# provas i samma träd som bildprovet sedan ritar.
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var vy := By3D.new()
	sub.add_child(vy)
	await process_frame
	await process_frame
	var rök: GPUParticles3D = null
	for n in _alla(vy):
		if n is GPUParticles3D:
			rök = n
	check(rök != null, "en GPUParticles3D finns i by-scenen")
	if rök == null:
		print("=== TOTALT (rök): %d kontroller, %d fel ===" % [checks, fails])
		quit(1)
		return
	var avst := rök.position.distance_to(RÖK_PLATS)
	check(avst < 0.01, "emittern står på rökens uppmätta mitt", "%.2f m fel, %s" %
		[avst, str(rök.position)])
	check(rök.emitting, "emittern är TÄND")
	check(rök.amount > 0 and rök.lifetime > 0.0, "emittersystemet är byggt",
		"%d partiklar, %.1f s liv" % [rök.amount, rök.lifetime])
	var pm: ParticleProcessMaterial = rök.process_material
	check(pm != null and pm.direction.y > 0.0, "röken stiger uppåt",
		"" if pm == null else "riktning %s" % str(pm.direction))

	# -- 3. STILEN
	var ruta: QuadMesh = rök.draw_pass_1
	check(ruta != null, "partiklarna ritas som fyrkanter (QuadMesh)")
	if ruta != null:
		check(ruta.size.x <= 0.6 and ruta.size.y <= 0.6, "fyrkanten är liten",
			"%.2f x %.2f m" % [ruta.size.x, ruta.size.y])
		var m: BaseMaterial3D = ruta.material
		check(m != null and m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
			"ingen utsmetning: NEAREST-filtrering")
		check(m != null and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"pixelkonst: oskuggat material (ingen ljussättning som mjukar kanterna)")
		check(m != null and m.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED,
			"fyrkanterna vänder sig mot kameran, inte bort")
	check(pm != null and pm.angle_min == 0.0 and pm.angle_max == 0.0,
		"axelräta fyrkanter (ingen rotation)")
	check(vy.miljö != null and vy.miljö.environment.glow_enabled == false,
		"ingen glöd i scenens miljö")
	check(rök.use_fixed_seed and rök.seed == By3D.RÖK_FRÖ,
		"partiklarna har ett FAST frö (samma rök varje körning)",
		"frö %d" % rök.seed)

	# -- 4. I BY-SCENEN, INTE I SPELLOOPEN
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var i_spel := 0
	for n in _alla(main):
		if n is By3D:
			i_spel += 1
	check(i_spel == 0, "by-scenen ligger INTE i spelmotorn (main.tscn)", "%d By3D-instanser" % i_spel)
	main.queue_free()
	await process_frame

	# -- 5. BILDEN
	if not bild:
		print("  (bildprovet hoppas över: headless renderar inget — kör tools/prov.sh --script res://tests/test_by_rok.gd)")
	else:
		# Alex: "mät gärna rökens andel av bilden med och utan fast frö." Båda mäts och skrivs ut.
		# Pixel-exakthet MELLAN två restarts går inte att mäta här: bildrutan avgör hur långt röken
		# hunnit, och den varierar (mätt: 1835 px skiljer med fast frö, 2017 utan — bilduppdateringens
		# timing dominerar, inte fröet). Fröet mäts därför på sin EGENSKAP (kontrollen ovan) och här
		# redovisas AREAN, som är jämförbar mellan körningarna.
		var med_frö := await _mät_area(sub, vy, true)
		vy.rök.use_fixed_seed = false
		var utan_frö := await _mät_area(sub, vy)
		vy.rök.use_fixed_seed = true
		var px := 1280 * 720
		check(med_frö > 0, "röken RITAS: pixlar som skiljer sig från rutan utan rök",
			"%.2f %% av bilden med fast frö (%d px), %.2f %% utan (%d px); bilderna %s och %s" %
			[100.0 * med_frö / float(px), med_frö, 100.0 * utan_frö / float(px), utan_frö,
			 PNG, PNG.replace(".png", "_utan.png")])

	print("=== TOTALT (rök): %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
