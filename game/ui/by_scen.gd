## BYN SOM EN 3D-SCEN (M122). Alex: *"Jag vill ha en by i 2.5D med paralax och crisp grafik, vilket det
## inte är idag."*
##
## Byn är inte längre EN platt bild i en Control. Den är en grund 3D-scen — samma väg dungeonen redan
## går (geometri i 3D med en kamera, inget nytt system): den målade konsten ligger som ett BAKRE lager
## på ett djup, husen som EGNA objekt på ett annat, och kameran kan panna lite i sidled och höjdled.
## Då rör sig lagren OLIKA mycket — det är paralax, och djupet är det som ger den.
##
## VARFÖR DET GER DJUP: en punkt på avståndet `z` flyttar sig `Δx · (px_per_meter(z))` px när kameran
## flyttar sig `Δx` meter. Är husen på `s` andelar av bakgrundens avstånd tar de `1/s` gånger så stor
## förskjutning. Med `DJUP_S = 0,75` ger kamerans 16 px alltså bakgrunden 16 px och husen 16/0,75 =
## 21,3 px — MÄTT i `game/tests/test_by_2p5d.gd`, inte påstått.
##
## SKÄRPAN BEVARAS: kvaderna är ritade så att konsten hamnar på SAMMA plats och i SAMMA storlek som den
## platta bilden gjorde (samma `skala`: vyns px per konstpixel, se `VillageView.bild_storlek`), och
## materialen filtrerar NEAREST utan mipmaps. Den inre vyn har vyns egen storlek, så skalningen upp
## till skärmen är fortfarande fönstrets heltal — varje konstpixel blir en jämn kloss.
##
## DOF (djupblurret). Alex: *"lägg på distance blur / depth of field så att det som är på avstånd blir
## lite suddigt och ger djupkänsla."* MÄTT: i Godot 4.8-dev7 bor DOF på `CameraAttributesPractical`
## (`dof_blur_far_enabled`, `dof_blur_far_distance`, `dof_blur_far_transition`, `dof_blur_amount`) och
## kopplas till kameran via `Camera3D.attributes`. `Environment` har INGA sådana egenskaper i den här
## versionen — noll av dess 123 egenskaper innehåller "dof" eller "blur". Det är alltså fortfarande
## inställningar på en resurs som redan finns, men på kamerans attributresurs i stället för på
## miljön. Ingen egen blur-shader: bara Godots egen fjärr-blur.
##
## Bara FJÄRR-blur, och måttligt (`DOF_STYRKA`): husen, gångaren och alla UI-lager ska vara orörda,
## medan det bakersta lagret blir mätbart mjukare. Finns inte djupblurret i renderaren (webbygget kör
## `gl_compatibility` — MÄTT `RenderingServer.get_current_rendering_method()`) läggs i stället en
## FÖRMJUKAD kopia av konsten på det bakersta lagret, så djupet syns även där i stället för att bli
## skarpt. Rattarna sitter här och ingen annanstans.
class_name ByScen
extends RefCounted

## Spelets mått: 256 px per 0,5 m (se `hellcrawler-art`) — 512 konstpixlar per meter.
const KONST_PX_PER_M := 512.0
## Bakgrundens avstånd från kameran, i meter. Husen och gångaren står på DJUP_S av det.
const NÄRA_M := 2.0
## Husens djup i andelar av bakgrundens: 0,75 = en fjärdedel närmare kameran. Kvoten är paralaxen:
## bakgrundens förskjutning delat med den.
const DJUP_S := 0.75
## Kamerans största sidledsrörelse, i VYNS px. Liten med flit: husen är urklippta ur SAMMA bild som
## bakgrunden, så en stor rörelse glider ifrån sina egna målade konturer.
const SVEP := 16.0
## Djupblurret: bara fjärr-blur, måttligt. Husen står på 1,50 m, bakgrunden på 2,00 m.
const DOF_AVSTÅND := 1.95           ## var fjärr-blurret börjar, i meter. Husen står på 1,50 och
                                    ## bakgrunden på 2,00: MÄTT att 1,70 gav 6,2 % ändrade pixlar i
                                    ## husen (toningen nådde in i dem), 1,95 ger 0,0 %.
const DOF_ÖVERGÅNG := 0.10          ## hur långt det tonar in. Kort, annars når toningen husen.
const DOF_STYRKA := 0.05            ## 0,08 = låg styrka (Alex: "måttligt"); höj om det ska synas mer
## Den förmjukade kopian (web-vägen) görs i den här skalan och tillbaka: 4 = en kvarts upplösning.
const MJUK_NED := 4

## `dof=0`: granskningsflagga (M122) — slår av fjärr-blurret så provet kan mäta vad SOM HELST av
## skillnaden som kommer av blurret och vad som kommer av geometrin. Samma skäl som `crt=0`.
static var dof_av := false

var vp: SubViewport = null
var kam: Camera3D = null
var attribut: CameraAttributesPractical = null
var _bak: MeshInstance3D = null
var _hus: Array = []
var _figur: MeshInstance3D = null
var _konst: Texture2D = null
var _bak_textur: Texture2D = null
var _vy := Vector2(480.0, 270.0)
var _skala := 1.0
var _art := Vector2.ZERO
var _gata := 0.0
var _pan := 0.0
var _kx := 0.0
var _ky := 0.0

## Finns djupblurret i den renderare som körs? Skrivbordet kör forward_plus (finns), webbygget kör
## gl_compatibility (finns inte). Läses ur renderingsservern — inte gissat.
static func dof_finns() -> bool:
	return not dof_av and RenderingServer.get_current_rendering_method() != "gl_compatibility"

func klar() -> bool:
	return vp != null and kam != null and _bak != null

## Bygg scenen. `skala` är vyns px per konstpixel (`VillageView.bild_storlek().x / bildens bredd`),
## `hus` husens rutor i konstens px och `gata` gatans rad i konstens px.
func bygg(förälder: Node, vy: Vector2, konst: Texture2D, hus: Array, gata_px: float, skala: float) -> void:
	riv()
	_vy = vy
	_skala = skala
	_konst = konst
	_art = Vector2(konst.get_width(), konst.get_height())
	_gata = gata_px
	vp = SubViewport.new()
	vp.size = Vector2i(int(vy.x), int(vy.y))
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_DISABLED          ## ingen utjämning: pixlarna ska vara pixlar
	förälder.add_child(vp)
	vp.world_3d = World3D.new()
	var miljö := Environment.new()
	miljö.background_mode = Environment.BG_COLOR
	miljö.background_color = Palett.c(1)
	miljö.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	miljö.ambient_light_color = Color(1, 1, 1)
	var we := WorldEnvironment.new()
	we.environment = miljö
	vp.add_child(we)
	kam = Camera3D.new()
	kam.projection = Camera3D.PROJECTION_PERSPECTIVE
	# FOV så att EN konstpixel blir EN pixel i den inre vyn: vyns höjd ska motsvara verkligheten.
	kam.fov = rad_to_deg(2.0 * atan(_vy.y / (2.0 * NÄRA_M * KONST_PX_PER_M * _skala)))
	kam.near = 0.05
	kam.far = 20.0
	vp.add_child(kam)
	# DJUPBLURRET. Bara fjärr-blur. Finns det inte i renderaren stängs det av och bakgrunden får i
	# stället en förmjukad kopia (se `_mjuk`), så webbygget inte blir skarpt.
	attribut = CameraAttributesPractical.new()
	attribut.dof_blur_near_enabled = false
	attribut.dof_blur_far_enabled = dof_finns()
	attribut.dof_blur_far_distance = DOF_AVSTÅND
	attribut.dof_blur_far_transition = DOF_ÖVERGÅNG
	attribut.dof_blur_amount = DOF_STYRKA
	kam.attributes = attribut
	_bak_textur = konst if dof_finns() else mjuk_kopia(konst)
	var alfa := konst.get_image() != null and konst.get_image().detect_alpha() != Image.ALPHA_NONE
	_bak = _kvad(_bak_textur, Rect2(Vector2.ZERO, _art), 1.0, alfa)
	vp.add_child(_bak)
	_hus.clear()
	for r in hus:
		var nät := _kvad(konst, (r as Rect2), DJUP_S, alfa)
		vp.add_child(nät)
		_hus.append(nät)
	_figur = _kvad(null, Rect2(), DJUP_S, false)
	_figur.visible = false
	vp.add_child(_figur)
	_sätt_allt()

## En kvad: en textur (eller en REGION av en, i konstens px) på djupet `s`.
func _kvad(textur: Texture2D, region: Rect2, s: float, alfa: bool) -> MeshInstance3D:
	var nät := MeshInstance3D.new()
	var kvad := QuadMesh.new()
	# Kvadens mått i VÄRLDEN: konstens px gånger `_skala` (vyns px per konstpixel) gånger meter per
	# vyn-px (s/(512·skala)) — skalorna tar ut varandra och kvar blir konstens px delat med 512.
	kvad.size = region.size * s / KONST_PX_PER_M
	nät.mesh = kvad
	if textur != null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if region.position == Vector2.ZERO and region.size == _art:
			mat.albedo_texture = textur
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = textur
			atlas.region = region
			mat.albedo_texture = atlas
		if alfa:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
		nät.material_override = mat
	return nät

## En konstpunkt (ax, ay) i VÄRLDEN på djupet `s`, så att den projiceras exakt dit den platta bilden
## hade ritat den. Det är den enda formeln som binder konsten till 3D-rymden.
func _värld(ax: float, ay: float, s: float) -> Vector3:
	var vx: float = ax * _skala - _pan
	var vy: float = marklinje() + (ay - _gata) * _skala
	var m_per_px: float = s / (KONST_PX_PER_M * _skala)
	return Vector3((vx - _vy.x * 0.5) * m_per_px, -(vy - _vy.y * 0.5) * m_per_px, -NÄRA_M * s)

## Gatulinjen i vyn: samma andel av höjden som i byn (0,78, se MARKLINJE/GATA).
func marklinje() -> float:
	return _vy.y * 0.78

func _sätt_allt() -> void:
	if _bak != null:
		_bak.position = _värld(_art.x * 0.5, _art.y * 0.5, 1.0)
	for nät in _hus:
		if (nät as Node).has_meta("centrum"):
			var c: Vector2 = nät.get_meta("centrum")
			nät.position = _värld(c.x, c.y, DJUP_S)
	if _figur != null and _figur.visible:
		_figur.position = _värld(float(_figur.get_meta("ax")), float(_figur.get_meta("ay")), DJUP_S)

## Husens mitt i konstens px. Vyn sätter dem efter `bygg` (den äger PLATSER).
func sätt_hus_centrum(i: int, centrum: Vector2) -> void:
	if i >= 0 and i < _hus.size():
		_hus[i].set_meta("centrum", centrum)
		_hus[i].position = _värld(centrum.x, centrum.y, DJUP_S)

func sätt_pan(pan: float) -> void:
	_pan = pan
	_sätt_allt()

## Kameran i sidled och höjdled, i VYNS px. Klamd till SVEP — se konstanten.
func sätt_kamera(kx: float, ky: float) -> void:
	_kx = clampf(kx, -SVEP, SVEP)
	_ky = clampf(ky, -SVEP, SVEP)
	if kam != null:
		var m_per_px: float = 1.0 / (KONST_PX_PER_M * _skala)
		kam.position = Vector3(_kx * m_per_px, -_ky * m_per_px, 0.0)

## Lagrens avstånd från kameran i meter: x = bakgrunden, y = husen. Provet läser dem härifrån i
## stället för att räkna om konstanterna själv — mätt på de faktiska kvaderna, inte på formeln.
func lagerdjup() -> Vector2:
	if kam == null or _bak == null:
		return Vector2.ZERO
	var hus := 0.0
	if not _hus.is_empty():
		hus = absf((_hus[0] as Node3D).position.z - kam.position.z)
	return Vector2(absf(_bak.position.z - kam.position.z), hus)

func kameraposition() -> Vector2:
	return Vector2(_kx, _ky)

## Gångaren: hon står på husens djup och följer därför husen, inte bakgrunden.
func sätt_figur(textur: Texture2D, ax: float, ay: float, storlek_px: Vector2, syns: bool) -> void:
	if _figur == null:
		return
	_figur.visible = syns
	if not syns or textur == null:
		return
	var storlek := storlek_px * DJUP_S / KONST_PX_PER_M
	if absf((_figur.mesh as QuadMesh).size.x - storlek.x) > 0.00001:
		(_figur.mesh as QuadMesh).size = storlek
	var mat := _figur.material_override as StandardMaterial3D
	if mat == null or mat.albedo_texture != textur:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.albedo_texture = textur
		_figur.material_override = mat
	_figur.set_meta("ax", ax)
	_figur.set_meta("ay", ay)
	_figur.position = _värld(ax, ay, DJUP_S)

## Bilden vyn ritar (den inre vyns textur). Null när scenen inte är byggd — då ritar vyn sin platta.
func textur() -> Texture2D:
	return vp.get_texture() if vp != null else null

func bakgrund_textur() -> Texture2D:
	return _bak_textur

## En konstpunkt som SKÄRMPUNKT i den inre vyn — läst ur kamerans egen projektion, så provet mäter
## samma sak som ritas och inte en egen kopia av formeln.
func skärmpunkt(ax: float, ay: float, s: float) -> Vector2:
	if kam == null:
		return Vector2.ZERO
	return kam.unproject_position(_värld(ax, ay, s))

## Den förmjukade kopian av konsten av konsten — ned i en kvarts upplösning och upp igen med mjukt
## filter. Används bara där djupblurret inte finns (webbygget), så "avstånd" betyder något även där.
func mjuk_kopia(konst: Texture2D) -> Texture2D:
	var bild := konst.get_image()
	if bild == null:
		return konst
	bild = bild.duplicate()
	bild.convert(Image.FORMAT_RGBA8)
	bild.resize(maxi(1, bild.get_width() / MJUK_NED), maxi(1, bild.get_height() / MJUK_NED), Image.INTERPOLATE_BILINEAR)
	bild.resize(konst.get_width(), konst.get_height(), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(bild)

func riv() -> void:
	if vp != null and is_instance_valid(vp):
		vp.get_parent().remove_child(vp)
		vp.queue_free()
	vp = null
	kam = null
	attribut = null
	_bak = null
	_hus.clear()
	_figur = null
