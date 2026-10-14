## BYN SOM 3D-SCEN — Alex' egen Blender-scen (byn.glb) med röken som PARTIKLAR.
##
## Alex: *"Röken som kommer upp ur ena huset är texturerad med sten — ta bort bollarna av rök och gör om
## dem till en smoke emitter."* Mätt i den förra körningen: röken och molnen (Cloud_White 15 +
## Smoke_Grey 5) föll igenom namnklassningen ända till stenplattan. De är därför BORTA ur byn.glb —
## exporten hoppar över dem (tools/apply_pixel_textures.py, sektionen SMOKE) — och röken ligger i
## stället här, som en GPUParticles3D på rökens uppmätta mitt.
##
## VARFÖR I GODOT OCH INTE I BLENDER: glTF bär inga partikelsystem. En emitter i .blend-filen hade
## alltså inte överlevt exporten alls, hur den än såg ut där.
##
## MÄTT (tools/apply_pixel_textures.py, skrivet i tools/byn_mappning.json): de fem rökkloten
## Chimney_Smoke_0..4 (material Smoke_Grey) låg på Blender (-11,25, 1,75, 6,00) till (-9,85, 1,95,
## 8,20). Klustercentrum blir (-10,65, 1,85, 7,03) i Blender — i glTF (Y upp) är samma punkt
## (-10,65, 7,03, -1,85), och det är RÖK_MITT.
##
## STILEN ÄR PIXELKONST: partiklarna är små, AXELRÄTA fyrkanter (ingen rotation, ingen textur, ingen
## mjuk kant), materialet är oskuggat med NEAREST-filtrering och partiklarna simuleras i fast 30 fps —
## samma regler som resten av spelet (project.godot: default_texture_filter = 0).
##
## Nodträdet byggs i kod, precis som by_scen.gd bygger 2.5D-vyn.
class_name By3D
extends Node3D

const GLB := "res://assets/by/byn.glb"

## Rökens mitt, i glTF-koordinater. Mätt, inte gissad (se huvudkommentaren).
const RÖK_MITT := Vector3(-10.65, 7.03, -1.85)
## Rökmaterialets egen färg i Alex' scen (Smoke_Grey, Principled BSDF basfärg).
const RÖK_FÄRG := Color(0.72, 0.74, 0.78)
## Partiklarnas frö. FASTA: annars drar varje restart en ny slumpström och röken blir en annan varje
## gång vyn laddas — omöjligt att jämföra två renderingar eller två provkörningar då.
const RÖK_FRÖ := 20261014
const RÖK_ANTAL := 160
const RÖK_LIV := 4.0

## Fyrkantens kant i meter. En platta är 1 m, så partikeln är en halv ruta — små fyrkanter, inte bollar.
const RÖK_RUTA := 0.45

## Spelets EGEN frontvy, samma kamera som texturrenderingarna i tools/byn_tex_prov.py: Blender
## (0,5, -22,0, 3,6), ortho_scale 34. glTF vänder på Y och Z, så i Godot står kameran på
## (0,5, 3,6, 22,0) och tittar rakt fram (Godots kamera ser mot -Z utan rotation).
const KAMERA_PLATS := Vector3(0.5, 3.6, 22.0)
const KAMERA_ORTHO := 34.0

var by: Node3D = null            ## byn.glb, instansierad
var rök: GPUParticles3D = null   ## röken — provet i tests/test_by_rok.gd mäter den
var kamera: Camera3D = null
var miljö: WorldEnvironment = null
## VYN som byn ritas i, i px. Projektionen (`projicera`) räknar ur den, och `village_view._bygg_by3d`
## sätter den till samma ruta som SubViewporten fick. Utan den kunde rutan och husens px glida isär.
var vy := Vector2(480.0, 270.0)

## LJUSEN I FILEN ÄR BLENDERS, INTE GODOTS. byn.glb bär Alex' eget ljus med som punkter
## (KHR_lights_punctual): Main_Sun 2186, Front_Fill 512, Tavern_Warm_Glow 11 957,
## Forge_PointLight 8696 och fyra facklor på 4076. Godot läser talet rakt av, och Blenders enheter
## (lux / candela) är tusen gånger Godots energi — MÄTT i den här vyn: med ljusen som de kom blev
## 52 % av bilden REN VIT (255,255,255), medelljushet 203 av 255 och fyra färger i hela rutan. Taken
## och gatan klipptes till vitt och byn syntes inte. Delade med tusen blir det Alex' egen bild:
## medelljushet 150,0 mot Blenders rendering av samma fil 146,2, och 115 färger mot 130.
const LJUS_DELARE := 1000.0

func _ready() -> void:
	if rök == null:
		bygg()

## Skala om ljusen i den instansierade scenen. Uniformt — hela ljusriggen delas med samma tal, så
## förhållandet mellan solen, facklorna och skyltglöden är det Alex satte i Blender.
func _dämpa_ljus(rot: Node) -> void:
	for n in rot.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		l.light_energy = l.light_energy / LJUS_DELARE

func bygg() -> void:
	by = load(GLB).instantiate()
	by.name = "byn"
	add_child(by)
	_dämpa_ljus(by)

	kamera = Camera3D.new()
	kamera.name = "kamera"
	kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# KEEP_WIDTH: Blenders ortho_scale är den STÖRSTA ledden (bredden i 16:9). Utan den raden tolkar
	# Godot size som HÖJDEN och vyn blir 34 m hög i stället för 19,1 — då ritas byn 1,8x för litet.
	kamera.keep_aspect = Camera3D.KEEP_WIDTH
	kamera.size = KAMERA_ORTHO
	kamera.near = 0.05
	kamera.far = 200.0
	kamera.position = KAMERA_PLATS
	add_child(kamera)

	# Himlen. Utan ett WorldEnvironment ritar Godot 3D-vyn på en tom, svart bakgrund, och då syns
	# varken husen eller röken i ett provfoto. Båda färgerna är hämtade ur game/assets/palette.json
	# (index 26 = himmelsblå, index 21 = den gråblå tonen) — inga påhittade färger.
	miljö = WorldEnvironment.new()
	miljö.name = "miljö"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(104.0 / 255.0, 156.0 / 255.0, 180.0 / 255.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(108.0 / 255.0, 128.0 / 255.0, 134.0 / 255.0)
	e.ambient_light_energy = 1.0
	e.glow_enabled = false          # ingen utsmetning: en glödande rök vore motsatsen till pixelkonst
	e.ssao_enabled = false
	e.fog_enabled = false
	miljö.environment = e
	add_child(miljö)

	rök = GPUParticles3D.new()
	rök.name = "rök"
	rök.position = RÖK_MITT
	rök.amount = RÖK_ANTAL
	rök.lifetime = RÖK_LIV
	rök.preprocess = RÖK_LIV * 0.5   # röken är TÄND när vyn öppnas, inte tom i två sekunder
	rök.local_coords = false         # röken stiger där skorstenen är, den följer inte noden
	rök.fixed_fps = 30               # fast steg, som resten av spelet — ingen mellanliggande utjämning
	rök.use_fixed_seed = true        # samma rök varje gång (annars ny slumpström per restart)
	rök.seed = RÖK_FRÖ
	rök.emitting = true
	# Utan en egen ruta klipper kameran bort partiklarna så fort de lämnar sin startpunkt.
	rök.visibility_aabb = AABB(Vector3(-3.0, -1.0, -1.5), Vector3(6.0, 9.0, 3.0))

	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.45, 0.22, 0.22)
	# Uppåt och en aning åt sidan: mätt stiger röken från (-11,25, 6,00) till (-9,85, 8,20).
	p.direction = Vector3(0.33, 1.0, 0.10)
	p.spread = 10.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.22, 0.30, 0.0)
	p.scale_min = 0.4
	p.scale_max = 1.0
	p.angle_min = 0.0                # AXELRÄTA fyrkanter — pixelkonst, inte snurrande lappar
	p.angle_max = 0.0
	p.color = RÖK_FÄRG
	# Tonar ut: frisk rök vid skorstenen, tunn uppe i toppen.
	var ton := Gradient.new()
	ton.set_color(0, Color(RÖK_FÄRG.r, RÖK_FÄRG.g, RÖK_FÄRG.b, 0.85))
	ton.set_color(1, Color(RÖK_FÄRG.r, RÖK_FÄRG.g, RÖK_FÄRG.b, 0.0))
	ton.add_point(0.55, Color(RÖK_FÄRG.r, RÖK_FÄRG.g, RÖK_FÄRG.b, 0.5))
	var ramp := GradientTexture1D.new()
	ramp.gradient = ton
	p.color_ramp = ramp
	rök.process_material = p

	var ruta := QuadMesh.new()
	ruta.size = Vector2(RÖK_RUTA, RÖK_RUTA)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true   # partiklarnas färg och tonande alfa
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ruta.material = m
	rök.draw_pass_1 = ruta
	add_child(rök)

# --- var husen står (M126) ---------------------------------------------------
#
# VARFÖR DET HÄR FINNS: klickytorna låg kvar i den gamla 2D-scenen och räknades ur platsernas procent
# av panoramabilden, medan det som RITAS är byn.glb. Rutan flyttade sig med panoreringen, 3D-byn står
# still, och klicket hamnade därför 34-115 px (medel 79 px i en 313 px-vy) från det hus man ser.
#
# Nodnamnen i Alex' scen grupperar objekten per plats (`Weaver_*`, `Smith_*`, `Tavern_*`, `Gate_*`,
# `Jeweler_*`, `Exit_*`). Prefixet står på PLATSER-posten som `3d` och läses därifrån — en plats byter
# hus i DATAN, inte här.

func sätt_vy(v: Vector2) -> void:
	vy = v

## Nodens transform upp till byn (`by`). INTE `global_transform`: den svarar bara för en nod som står
## i ett träd, och ett prov bygger byn direkt i en SubViewport som inte behöver vara i ett.
func _kedja(m: Node3D) -> Transform3D:
	var t := m.transform
	var p := m.get_parent()
	while p != null and p != by:
		var n3 := p as Node3D
		if n3 == null:
			break
		t = n3.transform * t
		p = p.get_parent()
	return t

## Världens ruta kring en plats' hus: föreningen av mesharnas AABB vars nodnamn börjar med `prefix`.
## Tom ruta när ingen nod matchar — då finns ingen 3D-klickruta och vyn faller tillbaka på 2D-scenen.
func hus_aabb(prefix: String) -> AABB:
	if prefix.is_empty():
		return AABB()
	if by == null:
		bygg()                      # `_ready` har inte körts: vyn kan vara byggd utanför ett träd
	if by == null:
		return AABB()
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	var n := 0
	for c in by.find_children("%s*" % prefix, "MeshInstance3D", true, false):
		var m := c as MeshInstance3D
		var a := m.get_aabb()
		var t := _kedja(m)
		for i in 8:
			var w: Vector3 = t * a.get_endpoint(i)
			mn = Vector3(minf(mn.x, w.x), minf(mn.y, w.y), minf(mn.z, w.z))
			mx = Vector3(maxf(mx.x, w.x), maxf(mx.y, w.y), maxf(mx.z, w.z))
		n += 1
	return AABB(mn, mx - mn) if n > 0 else AABB()

## ORTOGRAFISK PROJEKTION: vyns px för en världspunkt. Kameran står still (`KAMERA_PLATS`) och ser
## rakt fram (-Z) med KEEP_WIDTH, så den SYNLIGA BREDDEN är alltid `KAMERA_ORTHO` och höjden följer
## vyns form. MÄTT: formeln och kamerans EGEN `unproject_position` ger samma px (0,01 px fel), och
## provet jämför dem — annars kunde kameran flyttas utan att rutan följde med.
func projicera(p: Vector3) -> Vector2:
	var per_enhet := vy.x / KAMERA_ORTHO
	return Vector2(vy.x * 0.5 + (p.x - KAMERA_PLATS.x) * per_enhet,
		vy.y * 0.5 - (p.y - KAMERA_PLATS.y) * per_enhet)

## Platsens hus som ruta i vyns px. Tom ruta = platsen finns inte i byn.
func hus_rect(prefix: String) -> Rect2:
	var a := hus_aabb(prefix)
	if a.size.x <= 0.0 and a.size.y <= 0.0:
		return Rect2()
	var p0 := projicera(a.position)
	var p1 := projicera(a.position + a.size)
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)),
		Vector2(absf(p1.x - p0.x), absf(p1.y - p0.y)))

## GATULINJEN i vyns px: världens y = 0, där husen står. Gångaren går på den.
func marklinje_px() -> float:
	return projicera(Vector3(KAMERA_PLATS.x, 0.0, 0.0)).y
