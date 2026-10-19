## BYN SOM EN RIKTIG SCEN (M127).
##
## Alex: *"Detta ser verkligen inte bra ut alls — Ingen ljussättning, vinkeln är fel (behöver se ut
## som man ser i nån grad uppifrån så gatan syns med, mer inzoomat så man kommer närmare, muren bakom
## till höger är fel texturer på osv. Hade du gjort detta som en scen, så kunde jag editera själv."*
##
## DET SISTA VAR HELA POÄNGEN: nodträdet byggdes HÄR, så kameran och ljusen fanns bara som rader kod
## och Alex kunde inte flytta dem. Nu ligger de i `res://scenes/by.tscn` — byn.glb som INSTANS,
## kameran som `Camera3D`, solljuset och nattljuset som `DirectionalLight3D` och röken som
## `GPUParticles3D` — och den här filen är scenens eget skript. Öppna scenen i editorn, markera
## `kamera` eller `sol` och flyg/vrid: vyn ritas efter det som står i noden, inte efter ett läge i kod.
##
## Filen gör tre saker:
##
##   1. KNYTER sig till noderna i scenen (`byn`, `kamera`, `miljö`, `rök`). Ett prov som gör
##      `By3D.new()` utan scenfilen får SAMMA nodträd (scenen instansieras och barnen flyttas hit), för
##      att det provet ska mäta det spelet visar och inte en kopia byggd i kod.
##   2. RÄKNAR VYN: husens ruta i vyns px ur modellens meshar och KAMERANS EGEN projektion
##      (`projicera`, `hus_rect`). Det är samma ruta som klicket, hovringen, glöden och gångaren
##      använder (M126), så klickytan kan inte glida ifrån huset man ser.
##   3. SLÄCKER de två riktningsljus i glb:n som scenens egna `sol`/`fyllnad` ersätter.
##
## HIMMEL, DIMMA OCH VOLYMETRISKT LJUS (M142) bor i `res://scenes/by.tscn`s Environment (`miljö`).
## Alex 16/10: *"Kan vi lägga in volumetric lighting, kanske lite dimma, någon skybox ... så det inte
## ser så tråkigt ut?"*. Förut var bakgrunden en PLATT FÄRG (background_mode 1, samma gråblå som
## ambienten) — en tom vägg bakom husen — och ingen dimma alls. Nu: en ProceduralSkyMaterial i
## nattpalett (vald mot månljuset 0,62/0,72/0,98 och facklornas varma fönster), dimma med
## `fog_sun_scatter` så att månljuset glöder i den, och volymetrisk dimma med anisotropi 0,32 som
## samlar ljusskärven framåt så att strålarna syns i stället för en grå matta.
## LJUSET ÄR ORÖRT (sol 0,25, fyllnad 0,08, måne 0,15): dimman läggs ovanpå i stället för att
## skruva upp ljuset, så byn inte krockar med den pågående ljusändringen i den andra sessionen.
## Godots .tscn-format tillåter inga kommentarer (mätt: en `#`-rad gav "Parse Error: Expected '['"
## och hela scenen föll), och därför står motiveringen här i stället.
##
## KAMERAN (M127): ortografisk, tippad nedåt så att gatan, taken och marken syns. MÄTT i vyns px:
## 480x270 → 313x339 vid Alex' 941x1018 (SubViewportContainer, heltalsskala 3). Läget står i
## `res://scenes/by.tscn` tillsammans med motiveringen — ett prov (tests/test_by_kamera.gd) fäller om
## någon sätter tillbaka den rakt framifrån.
class_name By3D
extends Node3D

## Scenen. Den här filen ÄR dess skript: noderna (byn.glb, kamera, ljus, rök) bor i .tscn-filen.
const SCEN := "res://scenes/by.tscn"
const GLB := "res://assets/by/byn.glb"

## LJUSEN I FILEN ÄR GODOTS, INTE BLENDERS. byn.glb bar först Alex' eget ljus med som punkter
## (KHR_lights_punctual) i BLENDERS enheter (lux/candela): Main_Sun 2186, Tavern_Warm_Glow 11 957,
## Forge_PointLight 8696, fyra facklor på 4076. Godot läser talet rakt av, och Blenders enheter är
## tusen gånger Godots energi — MÄTT: med ljusen som de kom blev 52 % av bilden REN VIT (255,255,255),
## medelljushet 203 av 255 och fyra färger i hela rutan. Den här filen delade därför varje ljus med
## 2 000 varje gång scenen byggdes ...
##
## ... OCH DET VAR FEL STÄLLE. Raden kör bara när SPELET kör. Öppnade Alex `res://scenes/by.tscn` i
## editorn stod ljusen kvar i Blenders enheter och HELA BYN MÅLADES VIT — han såg texturerna bara i
## vissa vinklar, vilket är exakt symptomet på överbelysning. Att scenen går att redigera är hela
## poängen med den, så dämpningen ligger nu i FILEN: `tools/uv_byn.py` delar ljusen när byn.glb
## exporteras (`exportera`), och den här filen räknar inte om någonting. Spelet, editorn och varje
## annat program som öppnar filen ser alltså SAMMA by. Talen i filen är: Main_Sun 1,09,
## Front_Fill 0,26, Tavern_Warm_Glow 5,98, Forge_PointLight 4,35, facklorna 2,04.
##
## HALVERADE (M127): mätningen i prototypen visade att det var PUNKTLJUSEN och inte solen som brände
## ut väggarna — med dem släckta föll pixlarna över 240 från 1,17 % till 0,05 %, och att höja värmen
## gjorde saken värre (2,03 %). Facklorna står 0,3 m från stenmuren och klippte den till 255. Delaren
## är därför 2 000 och inte 1 000 (den ligger i `tools/uv_byn.py`): nattvarianten landar på 0,32 %
## över 240 och den utbrända stenfasadens yta faller 84 %. Fönstervärmen sitter i glb:ns EGNA
## självlysande glastexturer (PX_Window Warm, Exit_Sign_Glow) och rörs inte av den raden.

## DE TVÅ RIKTNINGSLJUSEN I FILEN, som scenens egna noder `sol` och `fyllnad` ersätter: samma
## riktning, färg och styrka, men de går att ställa in i scenen (och `sol` bär skuggorna). Att ha båda
## tända vore att lysa byn två gånger.
const GLB_SLÄCKT := ["Main_Sun", "Front_Fill"]

## Rökens mitt, i glTF-koordinater. MÄTT, inte gissad: de fem rökkloten Chimney_Smoke_0..4 (material
## Smoke_Grey) låg på Blender (-11,25, 1,75, 6,00) till (-9,85, 1,95, 8,20); klustercentrum blir
## (-10,65, 1,85, 7,03) i Blender, alltså (-10,65, 7,03, -1,85) i glTF. Emitterns nod i scenen står
## här, och tests/test_by_rok.gd jämför nodens läge med den här konstanten.
## Mätt i modellen 19/10: skorstenens översta block (Chimney_Cap) har topp i Blender
## (-11.25, 1.75, 5.32) = Godot (-11.25, 5.32, -1.75). Det gamla värdet låg 1,71 m för högt och
## 0,55 m fel i x, alltså från en tidigare modell — provet föll med 1,80 m fel.
const RÖK_MITT := Vector3(-11.25, 5.32, -1.75)

## GATULINJEN (M127): den rad i världen gångaren går på. Gatan är ett PLAN, och med en tippad kamera
## är varje z sin egen rad i bilden — därför är siffran en z-koordinat och inte en y. MÄTT ur byn.glb:
## Road_Bed ligger z -0,10..2,30, alltså gatans mitt på z = 1,10 (Cobble_Road z -0,15..2,33 håller med).
const GATU_Z := 1.10

var by: Node3D = null            ## byn.glb, instansen i scenen
var rök: GPUParticles3D = null   ## röken — provet i tests/test_by_rok.gd mäter den
var kamera: Camera3D = null      ## scenens kamera; projektionen nedan räknar ur DEN
var miljö: WorldEnvironment = null
## BYBORNA (M129): målningens figurer resta som voxlar under `byn/bybor`. Byggs här först när glb:n
## finns, och ligger som EN nod under byn så de följer modellen och går att gömma i editorn.
var bybor: Bybor = null
## VYN som byn ritas i, i px. Projektionen (`projicera`) räknar ur den, och `village_view._bygg_by3d`
## sätter den till samma ruta som SubViewporten fick. Utan den kunde rutan och husens px glida isär.
var vy := Vector2(480.0, 270.0)

func _ready() -> void:
	_knyt()

## Noderna ur scenen. Saknas de (en `By3D.new()` utan scenfilen, som proven gör) byggs SAMMA nodträd
## genom att scenen instansieras och dess barn flyttas hit.
func _knyt() -> void:
	if get_node_or_null("byn") == null:
		_bygg_i_kod()
	by = get_node_or_null("byn") as Node3D
	kamera = get_node_or_null("kamera") as Camera3D
	miljö = get_node_or_null("miljö") as WorldEnvironment
	rök = get_node_or_null("rök") as GPUParticles3D
	if by != null:
		_släck_dubblar(by)
		_bygg_bybor()
		# GRÄSET BYGGS EFTER BILDEN. Mätt: 630 tuvor + markplattan i `_knyt` drog byns byggtid från
		# 347 till 600-740 ms, alltså över provets tak (600 ms) — och tuvorna syns ändå först i nästa
		# bildruta. `call_deferred` lägger dem där de hör: efter att vyn ritats en gång.
		_bygg_gras.call_deferred()

## GRÄSET (A-testet 19/10). Alex: *"jag vill kunna ha liknande effekter, känsla, rörliga grässtrån
## osv"* (referensen Luminati har ett fält som vajar, med svaj i toppen och stilla rot).
##
## Vi har redan exakt den rörelsen: `ui/dekor.gdshader` ritar en billboard vars topp svajar ur
## världsläget och vars rot står still — den används till kryptans gräs. Här återanvänds den rakt av i
## stället för att skrivas igen; det som är nytt är bara VAR tuvorna sås.
##
## Tuvorna står i FÖRGRUNDEN (z 2,35..9,5, framför kullerstensgatan som slutar på 2,3) — det var den
## största tomma ytan i vyn efter att kameran tippades 30°. Ingen kollision, ingen nod per tuva: en
## MultiMesh per sort, som i kryptan.
const GRAS_TEX := "res://assets/by/gras_tuvor.png"
const GRAS_SHADER := "res://ui/dekor.gdshader"
const GRAS_RUTA := 32                 ## px per tuva i arket
const GRAS_PIXEL := 0.018             ## meter per arkpixel: 32 px blir 0,58 m hög tuva
const GRAS_PER_SORT := 210
## Fältet slutar i markkanten, inte ute över vattnet: marken (`Grass_Main`) går till z 3,5 och där
## börjar `Cliff_Face` — vattnet och klippan — som faller till y -3,1. MÄTT: med fältet ut till z 7,95
## låg gräset som ett lock ÖVER vattnet, och Alex fick "inget av vattnet som är närmast kameran".
const GRAS_FÄLT := Rect2(-19.0, 1.55, 38.0, 1.95)  ## x/z-rymden tuvorna sås i (fältets z är djup)
## z startar 1,55 och inte vid gatukanten 2,3: en hård rak skarv mellan sten och gräs läser som en
## inklistrad remsa. Tuvorna får spilla 0,8 m in över kullerstenen i stället.
const GRAS_FRÖ := 20261019
## Fältets eget lager (2): gräset och dess mark lyss av `grasljus`, som bara har den här masken.
const GRAS_LAGER := 1 << 1

func _bygg_gras() -> void:
	if by == null or get_node_or_null("gras") != null:
		return
	if not ResourceLoader.exists(GRAS_TEX) or not ResourceLoader.exists(GRAS_SHADER):
		return
	var ark: Texture2D = load(GRAS_TEX)
	var shader: Shader = load(GRAS_SHADER)
	var rot := Node3D.new()
	rot.name = "gras"
	by.add_child(rot)
	# MARKEN UNDER TUVORNA. Utan den står gräset som lösa pixlar i ett svart hål (mätt: det såg ut som
	# brus, inte som gräs) — tuvan behöver en yta att växa ur. Plattan ligger strax över glb:ns egen
	# mark (y 0) och använder byns grass-textur med treplanar-UV, som väggarna i kryptan.
	var gräs_tex := "res://assets/by/tex/grass.png"
	if ResourceLoader.exists(gräs_tex):
		var plan := PlaneMesh.new()
		plan.size = Vector2(GRAS_FÄLT.size.x + 6.0, GRAS_FÄLT.size.y + 0.6)
		var mark := StandardMaterial3D.new()
		mark.albedo_texture = load(gräs_tex)
		mark.uv1_triplanar = true
		mark.uv1_scale = Vector3(2.2, 2.2, 2.2)
		mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mark.roughness = 1.0
		# Albedon i By-paketet är mörk (gräset mäter 0,15 linjärt); på en plan yta med 26° sol blir
		# det en svart matta. Tonen lyfter marken till samma nivå som husens fasader.
		mark.albedo_color = Color(3.4, 3.3, 2.5)
		plan.material = mark
		var mark_nod := MeshInstance3D.new()
		mark_nod.name = "grasmark"
		mark_nod.mesh = plan
		mark_nod.position = Vector3(GRAS_FÄLT.position.x + GRAS_FÄLT.size.x * 0.5, 0.005,
			GRAS_FÄLT.position.y + GRAS_FÄLT.size.y * 0.5)
		mark_nod.layers = GRAS_LAGER          # bara fältets eget ljus rör den (se GRAS_LJUS)
		rot.add_child(mark_nod)
	var rng := RandomNumberGenerator.new()
	# KITETS GRÄS (Quaternius Stylized Nature MegaKit, CC0): riktiga blad i stället för en lapp.
	# MÄTT: Grass_Common_Tall är 166 ytor och 1,84 m hög i källan, alltså 0,48 m vid skalan 0,26 —
	# samma höjd som en tuva på 32 arkpixlar. Finns meshen används den; annars faller vi tillbaka på
	# billboard-tuvorna nedanför (samma ark som förut).
	if _kit_gras(rot, rng):
		pass                                   # kitets blad ritar fältet (se `_kit_gras`)
	else:
		for sort in 3:
			rng.seed = GRAS_FRÖ + sort
			var duk := AtlasTexture.new()
			duk.atlas = ark
			duk.region = Rect2(sort * GRAS_RUTA, 0, GRAS_RUTA, GRAS_RUTA)
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("textur", duk)
			mat.set_shader_parameter("svep", 0.022)
			mat.set_shader_parameter("vind", 1.1)
			var fyrkant := QuadMesh.new()
			fyrkant.size = Vector2(GRAS_RUTA, GRAS_RUTA) * GRAS_PIXEL
			fyrkant.material = mat
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = fyrkant
			mm.instance_count = GRAS_PER_SORT
			for i in GRAS_PER_SORT:
				# Tätt vid gatan, glesare utåt: tuvorna ska möta kullerstensranden, inte sluta i luften.
				var z := GRAS_FÄLT.position.y + pow(rng.randf(), 0.6) * GRAS_FÄLT.size.y
				var x := GRAS_FÄLT.position.x + rng.randf() * GRAS_FÄLT.size.x
				var s := 0.65 + rng.randf() * 0.85
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, 0.0, z)))
			var mmn := MultiMeshInstance3D.new()
			mmn.name = "gras_%d" % sort
			mmn.multimesh = mm
			mmn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmn.layers = GRAS_LAGER
			rot.add_child(mmn)
	# FÄLTETS EGET LJUS. Mätt: förgrunden låg på 0,09-0,14 i luminans medan gatan låg på 0,4 — den
	# ligger i skuggan av husen och tallarna (solen står 26° upp, alltså kastar 5-meterssaker 10 m
	# skugga). Ett eget, varmt riktningsljus som bara når fältets lager lyfter marken utan att röra
	# byns ljusbalans (som ägs av en annan ändring).
	var gräs_ljus := DirectionalLight3D.new()
	gräs_ljus.name = "grasljus"
	gräs_ljus.light_cull_mask = GRAS_LAGER
	gräs_ljus.light_color = Color(1.0, 0.86, 0.66)
	gräs_ljus.light_energy = 3.0
	gräs_ljus.shadow_enabled = false
	gräs_ljus.rotation_degrees = Vector3(-54.0, 18.0, 0.0)
	rot.add_child(gräs_ljus)
	_bygg_kit_props(rot, rng)

## KITETS GRÄS. Quaternius Stylized Nature MegaKit (CC0 1.0), fri att lägga i repot: `Grass_Common_Tall`
## är 166 ytor riktiga blad (1,84 m höga i källan), inte en billboard. Bladen står still i världen och
## syns därför från sidan när kameran tippar — det är hela skillnaden mot en lapp som vänder sig mot
## kameran. Texturens 512 px rand kvantiseras till paletten i `tools/gen_gras_kit.py` (8 färger kvar).
const GRAS_KIT_MESH := "res://assets/by/quaternius/Grass_Common_Tall.gltf"
const GRAS_KIT_TEX := "res://assets/by/quaternius/Grass_pixel.png"
const GRAS_KIT_SHADER := "res://ui/gras3d.gdshader"
const GRAS_KIT_ANTAL := 1500
const GRAS_KIT_SKALA := 0.38          ## källan är 1,84 m hög; 0,38 ger 0,70 m tuva

func _kit_gras(rot: Node3D, rng: RandomNumberGenerator) -> bool:
	if not ResourceLoader.exists(GRAS_KIT_MESH) or not ResourceLoader.exists(GRAS_KIT_TEX):
		return false
	if not ResourceLoader.exists(GRAS_KIT_SHADER):
		return false
	var scen: PackedScene = load(GRAS_KIT_MESH)
	if scen == null:
		return false
	var prov := scen.instantiate()
	var mesh: Mesh = null
	for n in prov.find_children("*", "MeshInstance3D", true, false):
		mesh = (n as MeshInstance3D).mesh
		break
	prov.free()
	if mesh == null:
		return false
	var mat := ShaderMaterial.new()
	mat.shader = load(GRAS_KIT_SHADER)
	mat.set_shader_parameter("textur", load(GRAS_KIT_TEX))
	mat.set_shader_parameter("svep", 0.045)
	mat.set_shader_parameter("vind", 1.1)
	mesh.surface_set_material(0, mat)
	rng.seed = GRAS_FRÖ
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = GRAS_KIT_ANTAL
	for i in GRAS_KIT_ANTAL:
		var z := GRAS_FÄLT.position.y + pow(rng.randf(), 0.6) * GRAS_FÄLT.size.y
		var x := GRAS_FÄLT.position.x + rng.randf() * GRAS_FÄLT.size.x
		var s := GRAS_KIT_SKALA * (0.75 + rng.randf() * 0.55)
		var vrid := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(vrid, Vector3(x, 0.0, z)))
	var mmn := MultiMeshInstance3D.new()
	mmn.name = "gras_kit"
	mmn.multimesh = mm
	mmn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmn.layers = GRAS_LAGER
	rot.add_child(mmn)
	return true

## KITETS REKVISITA. Quaternius Fantasy Props MegaKit (CC0 1.0) — tunnor, lådor, säckar, korgar som
## "dräller omkring" i världen. Modellerna är redan i meter (Barrel 0,90 m, Bench 2,78 m bred), alltså
## samma skala som byn, och atlaserna är pixelade till 256 px / 24 färger av `tools/kit_props.py`.
##
## De ställs på GATANS framkant (z 1,6-2,2) och i fältkanten, inte överallt: husen har redan egna målade
## rekvisiter i `byn.glb`, och två sorters tunnor i samma bild är värre än inga.
const KIT_PROPS := "res://assets/by/quaternius/props"
## Bänken togs bort: 2,78 m bred och platt lästes den som en ljus planka i vyn, inte som möbel.
const KIT_ART := ["Barrel", "Crate_Wooden", "Bag", "Bucket_Wooden_1", "Chest_Wood", "Pot_1", "Rope_3"]
## (x, z) längs gatan — handplacerat, för en slumpad tunna kan hamna i dörren.
const KIT_PLATSER := [
	Vector2(-13.2, 1.8), Vector2(-9.3, 2.0), Vector2(-5.6, 1.7), Vector2(-2.2, 2.1),
	Vector2(1.4, 1.8), Vector2(4.6, 2.0), Vector2(7.8, 1.7), Vector2(11.0, 2.0),
]

func _bygg_kit_props(rot: Node3D, rng: RandomNumberGenerator) -> void:
	if not DirAccess.dir_exists_absolute(KIT_PROPS):
		return
	var n := 0
	for i in KIT_PLATSER.size():
		var art: String = KIT_ART[i % KIT_ART.size()]
		var fil := "%s/%s.gltf" % [KIT_PROPS, art]
		if not ResourceLoader.exists(fil):
			continue
		var scen: PackedScene = load(fil)
		if scen == null:
			continue
		var prov := scen.instantiate()
		var mesh: Mesh = null
		for c in prov.find_children("*", "MeshInstance3D", true, false):
			mesh = (c as MeshInstance3D).mesh
			break
		prov.free()
		if mesh == null:
			continue
		# Pixelkonst: NEAREST på varje yta. Importen sätter linjär filtrering, och då suddas atlasen
		# upp till målade ytor igen — hela poängen med att kvantisera den försvinner.
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as BaseMaterial3D
			if m != null:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var mi := MeshInstance3D.new()
		mi.name = "kit_%s_%d" % [art, i]
		mi.mesh = mesh
		mi.layers = GRAS_LAGER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector2 = KIT_PLATSER[i]
		mi.position = Vector3(p.x, 0.0, p.y)
		mi.rotation.y = rng.randf_range(-PI, PI)
		rot.add_child(mi)
		rot.add_child(_skugga_under(mesh, mi.position))
		n += 1
	print("by: %d kit-rekvisiter längs gatan" % n)

## KONTAKTSSKUGGA. Utan den svävar en tunna: propsen kastar ingen skugga (skuggor av förgrundssaker
## kostar mer än de smakar i en ortografisk vy) och står på en plan yta som redan är mörk. En mjuk,
## mörk rundel under varje sak kostar en quad och gör att den sitter fast i marken.
func _skugga_under(mesh: Mesh, där: Vector3) -> MeshInstance3D:
	var a := mesh.get_aabb()
	var bredd := maxf(a.size.x, a.size.z) * 1.25
	var ton := Gradient.new()
	ton.set_color(0, Color(0, 0, 0, 0.55))
	ton.set_color(1, Color(0, 0, 0, 0.0))
	var duk := GradientTexture2D.new()
	duk.gradient = ton
	duk.fill = GradientTexture2D.FILL_RADIAL
	duk.fill_from = Vector2(0.5, 0.5)
	duk.fill_to = Vector2(1.0, 0.5)
	duk.width = 64
	duk.height = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = duk
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var plan := PlaneMesh.new()
	plan.size = Vector2(bredd, bredd)
	plan.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plan
	mi.position = Vector3(där.x, 0.012, där.z)
	mi.layers = GRAS_LAGER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Byborna hänger under `byn` (modellen), inte under den här noden: de hör till byggnaden, och en
## by som flyttas i scenen ska ta dem med sig. Redan byggda (scenen kan knytas om) lämnas i fred.
func _bygg_bybor() -> void:
	if by == null:
		return
	var gammal := by.get_node_or_null("bybor")
	if gammal != null:
		bybor = gammal as Bybor
		return
	bybor = Bybor.bygg(by)

func _bygg_i_kod() -> void:
	var s: Node = load(SCEN).instantiate()
	for b in s.get_children():
		# ÄGAREN BORT FÖRST: barnen ägs av den tillfälliga roten, och en ägare som frigörs lämnar en
		# dinglande referens (Godot varnar: "will make owner inconsistent"). Utan raden står barnen
		# kvar med en ägare som inte finns.
		b.owner = null
		s.remove_child(b)
		add_child(b)
	s.free()

## Se till att noderna finns. Anropas av den som bara har en By3D-referens: vyn kan bygga byn utanför
## ett träd, och då har `_ready` inte körts.
func _säkerställ() -> void:
	if by == null:
		_knyt()

## Släck de riktningsljus i glb:n som scenens egna noder ersätter (se GLB_SLÄCKT). Allt annat i filen
## — skyltglöden, facklorna, ässjan, värdshusets fönster — är kvar och lyser som förut.
func _släck_dubblar(rot: Node) -> void:
	for namn in GLB_SLÄCKT:
		var n := rot.get_node_or_null(namn)
		if n != null:
			(n as Node3D).visible = false

func sätt_vy(v: Vector2) -> void:
	vy = v

# --- var husen står (M126) ---------------------------------------------------
#
# VARFÖR DET HÄR FINNS: klickytorna låg kvar i den gamla 2D-scenen och räknades ur platsernas procent
# av panoramabilden, medan det som RITAS är byn.glb. Rutan flyttade sig med panoreringen, 3D-byn står
# still, och klicket hamnade därför 34-115 px (medel 79 px i en 313 px-vy) från det hus man ser.
#
# Nodnamnen i Alex' scen grupperar objekten per plats (`Weaver_*`, `Smith_*`, `Tavern_*`, `Gate_*`,
# `Jeweler_*`, `Exit_*`). Prefixet står på PLATSER-posten som `3d` och läses därifrån — en plats byter
# hus i DATAN, inte här.

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
	_säkerställ()
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

## ORTOGRAFISK, TIPPAD KAMERA: vyns px för en världspunkt ur KAMERANS EGEN transform.
## Kameran ser längs sin egen -Z, och med `keep_aspect = KEEP_WIDTH` är den SYNLIGA BREDDEN alltid
## `kamera.size` (i meter) — alltså är px per meter `vy.x / kamera.size` i BÅDA ledden. Den gamla
## formeln upprepade kamerans läge som konstanter i den här filen; nu läses läget ur noden, så en
## kamera Alex flyttar i editorn flyttar klickytorna med sig.
##
## MÄTT mot kamerans EGEN `unproject_position` (Godots projektionsmatris, en annan väg än den här) i
## tests/test_by_skylt.gd och tests/test_by_kamera.gd. Den här formeln är orto­grafisk: byter man
## projektion till perspektiv räknar kameran själv, för då är px/meter inte längre konstant.
func projicera(p: Vector3) -> Vector2:
	if kamera == null:
		return Vector2.ZERO
	if kamera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return kamera.unproject_position(p)
	var t: Transform3D = kamera.global_transform if kamera.is_inside_tree() else kamera.transform
	var lok: Vector3 = t.affine_inverse() * p
	var per_enhet: float = vy.x / kamera.size if kamera.keep_aspect == Camera3D.KEEP_WIDTH \
		else vy.y / kamera.size
	return Vector2(vy.x * 0.5 + lok.x * per_enhet, vy.y * 0.5 - lok.y * per_enhet)

## Platsens hus som ruta i vyns px. ALLA ÅTTA HÖRNEN projiceras: kameran är tippad, och rutan mellan
## två motstående hörn är inte en roterad lådas ruta i bilden (det var den bara så länge kameran såg
## rakt framifrån). Tom ruta = platsen finns inte i byn.
func hus_rect(prefix: String) -> Rect2:
	var a := hus_aabb(prefix)
	if a.size.x <= 0.0 and a.size.y <= 0.0:
		return Rect2()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in 8:
		var p := projicera(a.get_endpoint(i))
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	return Rect2(mn, mx - mn)

## GATULINJEN i vyns px: gatan gångaren går på (`GATU_Z`), där figurens fötter står. Med en tippad
## kamera är gatan ett BAND och varje z sin egen rad — den här raden är den gångaren går på.
func marklinje_px() -> float:
	return projicera(Vector3(0.0, 0.0, GATU_Z)).y
