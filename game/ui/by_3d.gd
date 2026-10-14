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

func _ready() -> void:
	if rök == null:
		bygg()

func bygg() -> void:
	by = load(GLB).instantiate()
	by.name = "byn"
	add_child(by)

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
