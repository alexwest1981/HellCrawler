class_name Fx
extends RefCounted

## Effekter i rummet: eld, rök, damm, droppar och den blöta pölen.
##
## Alex: "vi behöver hitta ett sätt att ge vatten 'blöt effekt', men vi behöver även skapa effekter
## (eld, rinnande vatten, rök, damm, såna saker)".
##
## Inga bildfiler, ingen shader och inget nytt beroende — Godot har allt:
##
##   pricken     GradientTexture2D med radiell fyllning = en mjuk rund prick (32x32).
##   partikeln   QuadMesh med billboard + den pricken. Partikelns färg och genomskinlighet kommer
##               som VERTEXFÄRG, därför måste materialet ha `vertex_color_use_as_albedo` — utan det
##               är färgrampen i ParticleProcessMaterial verkningslös och elden blir grå.
##   formen      ParticleProcessMaterial: riktning, spridning, tyngd, turbulens (Godots inbyggda
##               brus) och färg-/skalgrader. Turbulensen är skillnaden mellan en kon av prickar och
##               en låga som slickar uppåt.
##   vattnet     NoiseTexture2D med `as_normal_map` = en krusning utan en enda bildfil. Den rullas
##               i uv1_offset varje bildruta, och eftersom pölen inte har någon albedotextur rör sig
##               BARA normalen — alltså spegelglansen i vattnet, inte marken under det.
##
## Gränsen mot ui/attack_fx.gd: den ritar kortens anfall i 2D ovanpå bilden. Det här är saker som
## står I rummet — de hör till kameran i 3D, inte till skärmen.

## Färgerna kommer ur spelets egen palett, inte ur en färdig partikeltextur.
const ELD_HET := Color(1.00, 0.94, 0.66)
const ELD_VARM := Color(1.00, 0.66, 0.24)
const ELD_SVAL := Color(0.42, 0.16, 0.06)
## Hur mycket över vitt en ljuskälla lyser. Över 1,0 = HDR, och det är först då miljöns glow (tröskel
## 1,0) och AgX har något att arbeta med: lågan får en kärna, en krans och en färg som går mot gult.
const GLÖD_ENERGI := 4.0
# Röken är LJUSARE än mörkret omkring den, inte mörkare: en mörk rök mot en mörk grottvägg syns inte
# alls. På en ljus bakgrund hade den varit mörk — här är rummet mörkt.
const RÖK := Color(0.46, 0.42, 0.39)
const DAMM := Color(0.72, 0.68, 0.60)
const VATTEN := Color(0.30, 0.55, 0.66)

## Droppslagen: vad som kan falla från taket. Färgen kommer ur spelets palett (inte ur en bildfil), och
## varje slag har sin egen TRÖGHET — slem och blod är segare än vatten, och lavan glöder.
##
## Blod görs mörkare än man tror: mot en mörk grottvägg läses ett ljust rött som rosa (samma läxa som
## röken, som var tvungen att vara ljusare än mörkret omkring sig).
const DROPP := {
	# STORLEKEN ÄR MÄTT, INTE TYST. Alex: *"Det droppar inte längre något från taken"* — men provet
	# (`nodprov=dropp`) hittade en droppe i luften och fotograferade den: den fanns, den syntes bara
	# inte. 0,03x0,055 m på tre meters håll är två bildpunkter mot en ditherad brun vägg, och
	# granskningen av bilden sa ordagrant att den "drunknar helt i bakgrundsbruset". Dubbelt så stor
	# ruta och högre alfa är skillnaden mellan ett takdropp man ser och en tro att det slutat droppa.
	"vatten": {"färg": VATTEN, "liv": 0.5, "storlek": Vector2(0.06, 0.11),
		"blandning": BaseMaterial3D.BLEND_MODE_MIX},
	"slem": {"färg": Color(0.34, 0.56, 0.22), "liv": 0.85, "storlek": Vector2(0.075, 0.125),
		"blandning": BaseMaterial3D.BLEND_MODE_MIX},
	"blod": {"färg": Color(0.40, 0.08, 0.09), "liv": 0.62, "storlek": Vector2(0.06, 0.11),
		"blandning": BaseMaterial3D.BLEND_MODE_MIX},
	"lava": {"färg": Color(1.0, 0.55, 0.16), "liv": 0.55, "storlek": Vector2(0.032, 0.05),
		"blandning": BaseMaterial3D.BLEND_MODE_ADD},
}

static var _prick: Texture2D = null
static var _krus: NoiseTexture2D = null
static var _shader: Shader = null
static var _pölar: Array = []

## Vattnets METALL (shaderns `glans`). Inte 0: vatten är ingen metall, men speglingen sitter inte bara
## i råheten, och den lilla andelen är det som gör krusningen SYNLIG i glansen. Siffran står på ETT
## ställe — shaderns standardvärde, materialet och mätprovet (`-- glansprov=pöl`) läser samma konstant.
## MÄTT: höjd till 0,7 blir vattnet mörkare och plattare i stället för blankare (se PLAN.md M27).
const VATTEN_METALL := 0.06
## Vattnets shader. Masken (vattnets form) ligger still; bara krusningen rullar — det är den enda
## skillnaden mellan "en blå fläck" och "en blöt fläck". Kanten klipps bort, så plattan får pölens form.
const VATTEN_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

/* filter_linear_mipmap, INTE filter_nearest: pölens mask är 32 px och ligger utsträckt över en
   ruta på en meter. Med nearest och utan mipnivåer hamnar alfatestet (m.a < 0.5) och vippar på
   måfå på håll — pölens kant blev ett SPRÄCKLIGT 1-bits dithermönster i stället för en kant.
   Mipnivåerna medelvärdesbildar masken och kanten blir mjuk. Krusningen samplas likadant: ett
   brus utan mipnivåer är bara brus på håll. */
uniform sampler2D mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D krus : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 mask_uv = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec2 rullning = vec2(0.030, 0.022);
// Krusningen är det som syns: glansen vandrar över vattnet när normalen rör sig. Metallen är låg med
// flit — en metallisk yta speglar omgivningen, och i en mörk korridor finns ingenting att spegla, så
// den blev bara mörk och platt. Vätan ligger i råheten och krusningen, inte i metallen. (GLSL
// kommenterar med //, inte # — en # här fick hela shadern att sluta kompilera.)
uniform float krus_skala = 4.0;
uniform float normal_djup = 0.9;
uniform float matthet = 0.05;
uniform float glans = %s;
uniform float tid = 0.0;

void fragment() {
	vec4 m = texture(mask, UV * mask_uv.xy + mask_uv.zw);
	if (m.a < 0.5) {
		discard;
	}
	ALBEDO = m.rgb;
	ROUGHNESS = matthet;
	METALLIC = glans;
	NORMAL_MAP = texture(krus, UV * krus_skala + rullning * tid).rgb;
	NORMAL_MAP_DEPTH = normal_djup;
}
"""


## Vattnets shader, byggd första gången den behövs.
static func shader() -> Shader:
	if _shader == null:
		var s := Shader.new()
		s.code = VATTEN_SHADER % VATTEN_METALL
		_shader = s
	return _shader


## Den mjuka pricken. Byggd av en gradient i koden: partiklar är suddiga på 32 px, så en bildfil
## hade bara varit samma gradient med ett extra steg i kedjan.
static func prick() -> Texture2D:
	if _prick == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_prick = t
	return _prick


## Krusningen: brus som NORMAL-karta. Sömlös, så att rullningen aldrig visar en söm.
static func krusning() -> NoiseTexture2D:
	if _krus == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		var t := NoiseTexture2D.new()
		t.noise = n
		t.as_normal_map = true
		t.seamless = true
		t.normalize = true
		t.width = 128
		t.height = 128
		_krus = t
	return _krus


## En färgskala till partiklarna: het → varm → sval → genomskinlig.
static func _skala(färger: Array) -> GradientTexture1D:
	# Punktlistan sätts som hela arrayer: Gradient.set_color() kräver att punkten redan finns, och
	# en ny Gradient har bara två.
	var g := Gradient.new()
	var o := PackedFloat32Array()
	var c := PackedColorArray()
	for i in färger.size():
		o.append(float(i) / float(maxi(färger.size() - 1, 1)))
		c.append(färger[i])
	g.offsets = o
	g.colors = c
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## Partikelns yta: en quad som står mot kameran, med formens sprite och partikelns egen färg.
##
## `form` är filen i assets/fx/ (gråskala + alfa, ritad av tools/gen_fx.py). Saknas den faller ytan
## tillbaka på den runda pricken — en saknad fil ska ge en sämre eld, inte en krasch.
##
## `glöd` = ytan ÄR en ljuskälla (elden, lavan). En unshaded yta skriver ut sin albedo rakt av och
## kan därför aldrig bli ljusare än vitt — ingen glow och ingen tonemapping har något att arbeta med
## (mätt i M24: 222 ljusa pixlar efter mot 225 före). Med emission över 1,0 hamnar lågan i HDR, och
## då blomstrar den. Formen och alfakanalen kommer fortfarande ur texturen, så elden behåller sin
## flamma i stället för att bli en klump.
static func _yta(blandning: int, form := "", filter: int = BaseMaterial3D.TEXTURE_FILTER_LINEAR,
		glöd := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if glöd \
		else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = blandning
	var tex: Texture2D = prick()
	if not form.is_empty():
		var p := "res://assets/fx/%s.png" % form
		if ResourceLoader.exists(p):
			tex = load(p)
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	# Utan den här raden är färgrampen i ParticleProcessMaterial verkningslös: partikelns färg och
	# alfa kommer in som vertexfärg, och materialet måste vilja använda den.
	m.vertex_color_use_as_albedo = true
	m.texture_filter = filter
	if glöd:
		m.emission_enabled = true
		m.emission = ELD_HET
		m.emission_energy_multiplier = GLÖD_ENERGI
	return m


## Ett emitterande moln. `aabb` måste sättas: GPUParticles3D gallras mot sin egen ruta, och med
## standardrutan försvinner partiklarna så fort kameran rör sig en meter.
##
## `storlek` är partikelns ruta i meter (x, y). Eld är högre än bred — en kvadratisk prick läses som
## en glödande kloss — och rutans proportioner följer formens sprite.
static func _moln(antal: int, liv: float, blandning: int, storlek: Vector2, form := "",
		glöd := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = antal
	p.lifetime = liv
	p.local_coords = false                  # partikeln stannar i rummet när spelaren går
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 9, 12))
	var q := QuadMesh.new()
	q.size = storlek
	q.material = _yta(blandning, form, BaseMaterial3D.TEXTURE_FILTER_LINEAR, glöd)
	p.draw_pass_1 = q
	return p


## En fackla: lågan, röken ovanför och glöden som far upp. Allt i en nod, så en fackla är ett anrop.
##
## LÅGAN ÄR LITEN MED FLIT. Alex: *"facklans låga kan vara mindre med, den behöver inte vara stor
## alls, bara den lyser upp rummet."* LJUSET gör jobbet — omni-ljuset i main.gd (LAGA_ENERGI 1,5 och
## LAGA_RACKVIDD 6,5 m) rörs inte av den här ändringen — och lågan visar bara var ljuset kommer ifrån.
##
## MÄTT med `-- lageprov` (EN körning, samma kamera, Forward+, 44 partiklar i lågan; pixlar ur bilden,
## inte ur koden):
##
##   lågruta m    glöd   kärna px   glöd px   vit andel av kärnan   rum medel
##   0,15×0,20    4,0     1088       3712           0,89             50,11
##   0,075×0,115  4,0      560       1444           0,86             48,76
##   0,075×0,115  2,0      448       1332           0,77             48,65   <- denna
##   0,075×0,115  2,0      312       1264           0,74             48,81   <- samma igen = brusgolv
##   0,075×0,115  1,0      296       1016           0,86             48,91
##   0,075×0,115  0,6      268       1116           0,69             48,02
##
## (kärna = grå ≥ 240, glöd = grå ≥ 200, vit = min(R,G,B) ≥ 235; rum p95 = 121,67 i alla sex
## bilderna. Brusgolvet är 2,0-raden mot sin egen upprepning: samma inställning två gånger i samma
## körning skiljer ±20 % på ytan, för elden fladdrar.)
##
##   * LÅGAN SOM YTA: 3712 px → 1332 px, en tredjedel, med samma låga antal partiklar per yta (tät,
##     liten tunga i stället för en gles liten eller en stor). Klart över bruset. Det är Alex
##     beställning — och sedan en täthetshöjning till (22 → 44 partiklar) på hans begäran.
##   * GLÖDEN: den utbrända kärnan är 448 px vid 2,0 mot 560 vid 4,0, och vit andel 0,77 mot 0,86.
##     Vid 0,6 blir kärnan 268 px och vit andel 0,69, men då tunnas kransen (1116 px mot 1332).
##     HDR-emissionen måste ligga över glödkurvans tröskel för att ge en krans alls; 2,0 vald.
##   * RUMMET STÅR STILL: medel 48,0-48,9 mot 50,11 och p95 identiskt 121,67. Det är hela kravet —
##     mindre låga, samma ljus — och det är omni-ljuset i main.gd som håller det.
##
## Rattarna (kalibrera om lågan utan att röra ljuset): LÅGA_STORLEK, LÅGA_ANTAL, LÅGA_GLÖD.
##
## TÄTHET, INTE STORLEK: antalet partiklar är högt (test_fx kräver minst 30) medan rutan är liten.
## En gles liten låga läses som lösa prickar; en tät liten låga läses som en tunga. Att höja antalet
## höjer den additiva ljusheten i kärnan, så GLÖD-siffran nedan är mätt MED detta antal — ändras
## antalet måste glöden mätas om (`-- lageprov`).
const LÅGA_ANTAL := 44
const LÅGA_STORLEK := Vector2(0.075, 0.115)
const LÅGA_LIV := 0.42
const LÅGA_GLÖD := 2.0
const RÖK_ANTAL := 12
const RÖK_STORLEK := Vector2(0.20, 0.20)
const GLÖD_STORLEK := 0.05

static func fackla(förälder: Node3D, pos: Vector3, skala := 1.0) -> Node3D:
	var rot := Node3D.new()
	rot.position = pos
	förälder.add_child(rot)

	# Lågan: kort liv, stiger, hetast i mitten och svalnar mot toppen. Turbulensen ger den sin vingliga
	# form — utan den är elden en kon av prickar. Rutan är HÖGRE än bred (0,075 x 0,115 m) och
	# partiklarna lutar slumpmässigt: en kvadratisk prick i additiv blandning läses annars som en
	# glödande kloss.
	var låga := _moln(LÅGA_ANTAL, LÅGA_LIV, BaseMaterial3D.BLEND_MODE_ADD, LÅGA_STORLEK * skala,
		"laga", true)
	# Lågans EGEN glöd (LÅGA_GLÖD), inte den delade GLÖD_ENERGI: lavaprickarna i sjön använder samma
	# HDR-emission, och de är inte mätta i det här provet. Att sänka den delade siffran hade ändrat
	# lavan också — utan en mätning.
	((låga.draw_pass_1 as QuadMesh).material as StandardMaterial3D).emission_energy_multiplier = LÅGA_GLÖD
	var lm := ParticleProcessMaterial.new()
	lm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	lm.emission_sphere_radius = 0.05 * skala
	lm.direction = Vector3(0, 1, 0)
	lm.spread = 11.0
	lm.angle_min = -25.0
	lm.angle_max = 25.0
	lm.initial_velocity_min = 0.5 * skala
	lm.initial_velocity_max = 1.0 * skala
	lm.gravity = Vector3(0, 0.9, 0)          # eld stiger: tyngden pekar uppåt
	lm.damping_min = 0.8
	lm.damping_max = 1.7
	lm.scale_min = 0.55
	lm.scale_max = 1.2
	lm.scale_curve = _kurva([1.0, 0.85, 0.45, 0.0])
	lm.color_ramp = _skala([ELD_HET, ELD_VARM, ELD_SVAL, Color(ELD_SVAL.r, ELD_SVAL.g, ELD_SVAL.b, 0.0)])
	lm.turbulence_enabled = true
	lm.turbulence_noise_strength = 0.7 * skala
	lm.turbulence_noise_scale = 3.0
	lm.turbulence_noise_speed = Vector3(2.2, 1.4, 2.2)
	lm.turbulence_influence_over_life = _kurva([0.2, 0.5, 0.85, 1.0])
	låga.process_material = lm
	låga.name = "låga"
	rot.add_child(låga)

	# Röken: långsammare, mörkare och mindre än förut (samma skäl som lågan: en stor ruta med samma
	# densitet läses som en rökridå över en liten eld). Den stiger ur lågans topp och bleknar.
	var rök := _moln(RÖK_ANTAL, 2.8, BaseMaterial3D.BLEND_MODE_MIX, RÖK_STORLEK * skala, "rok")
	rök.position = Vector3(0, 0.2 * skala, 0)
	var rm := ParticleProcessMaterial.new()
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	rm.emission_sphere_radius = 0.06 * skala
	rm.direction = Vector3(0, 1, 0)
	rm.spread = 24.0
	rm.angle_min = -180.0
	rm.angle_max = 180.0
	rm.initial_velocity_min = 0.1
	rm.initial_velocity_max = 0.26
	rm.gravity = Vector3(0, 0.1, 0)
	rm.damping_min = 0.2
	rm.damping_max = 0.6
	rm.scale_min = 0.7
	rm.scale_max = 1.6
	rm.scale_curve = _kurva([0.4, 0.9, 1.4, 1.9])
	var rk := RÖK
	rm.color_ramp = _skala([Color(rk.r, rk.g, rk.b, 0.0), Color(rk.r, rk.g, rk.b, 0.58),
		Color(rk.r, rk.g, rk.b, 0.30), Color(rk.r, rk.g, rk.b, 0.0)])
	rm.turbulence_enabled = true
	rm.turbulence_noise_strength = 0.5
	rm.turbulence_noise_scale = 1.1
	rm.turbulence_noise_speed = Vector3(0.5, 0.3, 0.5)
	rm.turbulence_influence_over_life = _kurva([0.2, 0.6, 1.0, 1.0])
	rök.process_material = rm
	rök.name = "rök"
	rot.add_child(rök)

	# Glöden: enstaka gnistor som far högre och slocknar. Få och långsamma — de syns bara mot mörkret,
	# och det är hela poängen.
	var glöd := _moln(12, 1.9, BaseMaterial3D.BLEND_MODE_ADD, Vector2.ONE * GLÖD_STORLEK * skala, "gnista")
	glöd.position = Vector3(0, 0.1 * skala, 0)
	var gm := ParticleProcessMaterial.new()
	gm.direction = Vector3(0, 1, 0)
	gm.spread = 34.0
	gm.initial_velocity_min = 0.5
	gm.initial_velocity_max = 1.1
	gm.gravity = Vector3(0, 1.3, 0)
	gm.scale_min = 0.5
	gm.scale_max = 1.0
	gm.scale_curve = _kurva([1.0, 0.7, 0.3, 0.0])
	gm.color_ramp = _skala([Color(1.0, 0.85, 0.5, 1.0), ELD_VARM, ELD_SVAL, Color(ELD_SVAL.r, ELD_SVAL.g, ELD_SVAL.b, 0.0)])
	gm.turbulence_enabled = true
	gm.turbulence_noise_strength = 1.1
	gm.turbulence_noise_scale = 1.6
	gm.turbulence_noise_speed = Vector3(0.9, 0.6, 0.9)
	glöd.process_material = gm
	glöd.name = "glöd"
	rot.add_child(glöd)
	return rot


## Dammet: pyttesmå korn som driver omkring i lyktskenet. De sitter på KAMERAN, för det är bara i
## ljuset de syns — ett dammkorn i mörkret är ingenting. Långt liv och nästan ingen rörelse, så det
## är luften själv som står stilla och inte ett partikelsystem som sprutar.
##
## Färgen är varm och ljuset svagt med flit: ett ljust korn över en kall grotta läses som snö.
static func damm(kamera: Node3D) -> GPUParticles3D:
	var p := _moln(40, 9.0, BaseMaterial3D.BLEND_MODE_ADD, Vector2(0.018, 0.018))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(4.0, 1.6, 4.0)
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.01
	m.initial_velocity_max = 0.06
	m.gravity = Vector3(0.01, -0.004, 0.0)   # sjunker sakta, som damm gör
	m.scale_min = 0.5
	m.scale_max = 1.4
	m.scale_curve = _kurva([0.0, 1.0, 1.0, 0.0])
	m.color_ramp = _skala([Color(DAMM.r, DAMM.g, DAMM.b, 0.0), Color(DAMM.r, DAMM.g, DAMM.b, 0.26),
		Color(DAMM.r, DAMM.g, DAMM.b, 0.18), Color(DAMM.r, DAMM.g, DAMM.b, 0.0)])
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.12
	m.turbulence_noise_scale = 0.6
	m.turbulence_noise_speed = Vector3(0.15, 0.08, 0.15)
	p.process_material = m
	p.position = Vector3(0, 0.4, 0)
	p.name = "damm"
	kamera.add_child(p)
	return p


## Dropparnas takt: ett ställe ska DROPPA, inte rinna.
##
## MÄTT FÖRE: `takt` skalade droppens LIVSTID, och i kontinuerligt läge släpper en GPUParticles3D
## `amount / lifetime` partiklar i sekunden. Med 4 partiklar och 0,35-1,1 s liv blev det 3,6-11,4
## droppar i SEKUNDEN på ett enda ställe — och våningen har ett tjugotal ställen (golv, vägg, tak).
## Det är en kran, inte ett takdropp, och Alex såg det: *"ser ut som det rinner, och inte droppar lite
## då och då"*. Falltiden rörs inte (droppen ska dö när den når marken); det är VÄNTAN mellan
## dropparna som är ny, och den dras om varje gång så takten aldrig blir en metronom.
const DROPP_VÄNTAN := Vector2(2.0, 6.0)          ## sekunder mellan dropparna på ett vanligt ställe
const DROPP_VÄNTAN_ACCENT := Vector2(0.6, 1.6)   ## accenter: något enstaka ställe som tätare

## Hur länge ett ställe väntar innan nästa droppe faller.
##
## En REN funktion med flit: provet räknar droppar per minut ur EXAKT samma tal som spelet använder.
## Ett prov som räknar sin egen kopia av takten mäter provet, inte spelet.
static func dropp_väntan(rng: RandomNumberGenerator, accent: bool = false) -> float:
	var v: Vector2 = DROPP_VÄNTAN_ACCENT if accent else DROPP_VÄNTAN
	return rng.randf_range(v.x, v.y)


## Dropparna: vatten som faller från taket och ner i pölen. Livstiden är satt efter falltiden —
## droppen ska försvinna när den når marken, inte fortsätta under golvet.
##
## EN droppe per start (`one_shot`): stället startas om av den som äger klockan (se main.gd `_droppa`),
## och väntan mellan två startar kommer ur `dropp_väntan`. Den som bygger våningen sätter `emitting`
## till false så att droppen inte faller förrän väntan är slut.
##
## `slag` är vad som faller (se DROPP).
static func droppar(förälder: Node3D, pos: Vector3, fall: float, slag := "vatten") -> GPUParticles3D:
	var d: Dictionary = DROPP.get(slag, DROPP["vatten"])
	var liv: float = float(d["liv"])
	var tfall := liv * 0.9
	var p := _moln(1, liv, int(d["blandning"]), d["storlek"], "droppe", slag == "lava")
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0                        # hela knippet på en gång: EN droppe, inte ett streck
	p.randomness = 0.5                           # spridningen mellan partiklarna
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 1.5
	# Tyngden räknas ur fallsträckan i stället för att gissas: d = ½·g·t² ger g = 2d/t². En droppe
	# från taket ska inte sväva, och den ska inte heller vara förbi pölen när man tittar på den.
	m.gravity = Vector3(0, -2.0 * fall / (tfall * tfall), 0)
	# STARTPUNKTEN FÅR INTE VARA EN PUNKT (M68). Flera ställen släpper samtidigt och alla startar i
	# takets höjd — då står dropparna på RAD tvärs över vyn. Mätt: prickarna rör sig med VÄRLDEN mellan
	# två bilder (olika höjd i samma remsa), alltså är de partiklar och inte skanlinjer eller dither.
	# En liten ask i stället för en punkt gör att en kull droppar aldrig linjerar.
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.03, 0.06, 0.03)
	m.scale_min = 0.7
	m.scale_max = 1.3
	# Livstidens ojämnhet sitter på MATERIALET (mätt: GPUParticles3D har `randomness`, materialet har
	# `lifetime_randomness`). Det är den som gör att ett enskilt ställe inte tickar som en metronom.
	m.lifetime_randomness = 0.5
	m.scale_curve = _kurva([0.4, 1.0, 1.0, 0.6])
	var v: Color = d["färg"]
	# 0,95 i stället för 0,85: droppen får inte blekna in i bakgrunden den faller mot.
	m.color_ramp = _skala([Color(v.r, v.g, v.b, 0.0), Color(v.r, v.g, v.b, 0.95),
		Color(v.r, v.g, v.b, 0.95), Color(v.r, v.g, v.b, 0.0)])
	p.process_material = m
	p.name = "droppar_%s" % slag
	förälder.add_child(p)
	return p


## Pölen: rutan vatten i rutans EGEN form, med låg råhet och en krusning som normal — rullad.
##
## Här tog Godots inbyggda material slut: `uv1_offset` flyttar ALLA texturer på materialet (det finns
## ingen UV-inställning per textur i StandardMaterial3D), så en rullad offset hade dragit iväg med
## pölens form också. Tjugo rader shader ger det som behövs: masken ligger still, krusningen rör sig.
##
## Masken är rutan med bara vattnet kvar (allt annat genomskinligt), så plattan ÄR den målade pölen och
## inte en rektangel ovanpå den — kanten klipps bort med `discard`.
static func pöl_material(mask: Texture2D, ruta: Array) -> ShaderMaterial:
	var sh := shader()
	if sh.code.is_empty() or ruta.size() < 4:
		return null                    # en shader utan kod är det enda vi kan upptäcka här; ett
		                               # kompileringsfel skriver Godot själv ut i loggen
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("mask", mask)
	m.set_shader_parameter("krus", krusning())
	m.set_shader_parameter("mask_uv", Vector4(ruta[2] / 32.0, ruta[3] / 32.0, ruta[0] / 32.0,
		(32 - ruta[1] - ruta[3]) / 32.0))
	# Tiden sätts även här, inte bara i rulla(): en parameter som aldrig satts har inget värde förrän
	# shadern har kompilerats, och då är den null den första bildrutan.
	m.set_shader_parameter("tid", 0.0)
	# Glansen sätts uttryckligen, inte bara som shaderns standardvärde: ett värde som finns i koden
	# men aldrig satts går inte att LÄSA tillbaka (mätprovet `-- glansprov=pöl` läser det), och en
	# standard som bara finns i shadertexten är en siffra som driver isär från spelets.
	m.set_shader_parameter("glans", VATTEN_METALL)
	_pölar.append(m)
	return m


## Krusningen rullar. Anropas varje bildruta med tiden sedan start. Alla pölar delar material per
## ruta, så det är några få material som får en ny tid — inte en uppdatering per pöl.
static func rulla(t: float) -> void:
	for m in _pölar:
		m.set_shader_parameter("tid", t)


static func _kurva(värden: Array) -> CurveTexture:
	var c := Curve.new()
	for i in värden.size():
		c.add_point(Vector2(float(i) / float(värden.size() - 1), värden[i]))
	var t := CurveTexture.new()
	t.curve = c
	return t
