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
##   3. DÄMPAR de ljus som följer med glb:n (se LJUS_DELARE) och SLÄCKER de två riktningsljus som
##      scenens egna `sol`/`fyllnad` ersätter.
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

## LJUSEN I FILEN ÄR BLENDERS, INTE GODOTS. byn.glb bär Alex' eget ljus med som punkter
## (KHR_lights_punctual): Main_Sun 2186, Front_Fill 512, Tavern_Warm_Glow 11 957,
## Forge_PointLight 8696 och fyra facklor på 4076. Godot läser talet rakt av, och Blenders enheter
## (lux / candela) är tusen gånger Godots energi — MÄTT: med ljusen som de kom blev 52 % av bilden REN
## VIT (255,255,255), medelljushet 203 av 255 och fyra färger i hela rutan. Delade med tusen blir det
## Alex' egen bild: medelljushet 150,0 mot Blenders rendering av samma fil 146,2.
##
## HALVERADE (M127): mätningen i prototypen visade att det var PUNKTLJUSEN och inte solen som brände
## ut väggarna — med dem släckta föll pixlarna över 240 från 1,17 % till 0,05 %, och att höja värmen
## gjorde saken värre (2,03 %). Facklorna står 0,3 m från stenmuren och klippte den till 255. Med
## halv styrka (2 000 i stället för 1 000) landar nattvarianten på 0,32 % över 240 och den utbrända
## stenfasadens yta faller 84 %. Fönstervärmen sitter i glb:ns EGNA självlysande glastexturer
## (PX_Window Warm, Exit_Sign_Glow) och rörs inte av den här raden.
const LJUS_DELARE := 2000.0

## DE TVÅ RIKTNINGSLJUSEN I FILEN, som scenens egna noder `sol` och `fyllnad` ersätter: samma
## riktning, färg och styrka, men de går att ställa in i scenen (och `sol` bär skuggorna). Att ha båda
## tända vore att lysa byn två gånger.
const GLB_SLÄCKT := ["Main_Sun", "Front_Fill"]

## Rökens mitt, i glTF-koordinater. MÄTT, inte gissad: de fem rökkloten Chimney_Smoke_0..4 (material
## Smoke_Grey) låg på Blender (-11,25, 1,75, 6,00) till (-9,85, 1,95, 8,20); klustercentrum blir
## (-10,65, 1,85, 7,03) i Blender, alltså (-10,65, 7,03, -1,85) i glTF. Emitterns nod i scenen står
## här, och tests/test_by_rok.gd jämför nodens läge med den här konstanten.
const RÖK_MITT := Vector3(-10.65, 7.03, -1.85)

## GATULINJEN (M127): den rad i världen gångaren går på. Gatan är ett PLAN, och med en tippad kamera
## är varje z sin egen rad i bilden — därför är siffran en z-koordinat och inte en y. MÄTT ur byn.glb:
## Road_Bed ligger z -0,10..2,30, alltså gatans mitt på z = 1,10 (Cobble_Road z -0,15..2,33 håller med).
const GATU_Z := 1.10

var by: Node3D = null            ## byn.glb, instansen i scenen
var rök: GPUParticles3D = null   ## röken — provet i tests/test_by_rok.gd mäter den
var kamera: Camera3D = null      ## scenens kamera; projektionen nedan räknar ur DEN
var miljö: WorldEnvironment = null
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
		_dämpa_ljus(by)
		_släck_dubblar(by)

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

## Skala om ljusen i den instansierade scenen. Uniformt — hela ljusriggen delas med samma tal, så
## förhållandet mellan skyltglöden, facklorna och ässjan är det Alex satte i Blender.
func _dämpa_ljus(rot: Node) -> void:
	for n in rot.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		l.light_energy = l.light_energy / LJUS_DELARE

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
