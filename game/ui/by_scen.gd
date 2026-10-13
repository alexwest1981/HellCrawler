## BYN SOM 2D-LAGER MED PARALLAX (M123).
##
## Alex, om den förra byn: *"Husen skulle lyftas ut och läggas som objekt i en 2.5D-vy, gatan framför
## skulle vara 'marken de stod på'. Det här såg förjävligt ut."* Och om vad som förstörde bilden:
## *"Bort med det som förstör: den mörka genomskinliga slöjan över mitten, CRT-kurvaturen/svart i
## hörnen/sträckningen i sidled, och den gula urvalsrutan (gör markeringen till en glöd eller kontur
## på byggnaden i stället). Blurret ska bara träffa bakersta lagret — scenen ska vara skarp."*
##
## DEN FÖRRA VYN VAR EN 3D-SCEN (M122): den målade konsten och husen låg som kvadér i en perspektiv-
## kamera, och det var de kvaderna Alex såg. Den här filen är samma idé i 2D, där den hör hemma:
## konsten är en textur på ett BAKGRUNDSLAGER, varje byggnad är sin EGEN textur (klippt ur samma bild,
## se `tools/gen_by_hus.py`) på ett HUS-LAGER, och en kamera rör scenen en liten bit. Lagren har olika
## parallaxfaktor, alltså rör de sig olika mycket — det är djupet.
##
## VARFÖR DET GER DJUP: med kameran i `c` flyttar ett lager med faktorn `f` sig `c · f`. Bakgrunden har
## `f = 1,0` och husen `f = 1/DJUP_S = 1,33`, så en kamerarörelse på 16 px ger bakgrunden 16 px och
## husen 21,3 px — MÄTT i `game/tests/test_by_utklippt.gd` (nodernas egna canvas-transform), inte
## påstått.
##
## NOLLÄGET ÄR IDENTISKT MED DEN MÅLADE BILDEN. Kameran står i origo när den inte rörs
## (`ANCHOR_MODE_FIXED_TOP_LEFT` → canvas-transformen är identitet), och varje byggnad ligger på EXAKT
## sin egen ruta ur bilden. Bakgrunden är bilden med husen borttagna (hålen ifyllda), så husets ruta
## ligger dikt över sitt eget hål: den sammansatta vyn är pixel-identisk med `byn.png`. Rörelsen är det
## som ska ge djupet — inte en annan komposition.
##
## HÅLET. Tar man bort huset ur bakgrunden uppstår ett hål där det stod. Det syns bara när huset glider
## ifrån bakgrunden: den relativa rörelsen är `c · (f - 1) = c · 0,33`, alltså 5,3 vy-px vid `SVEP` —
## en remsa i rutans kant, aldrig mer.
##
## AVSTÅNDSBLURRET. Godots djupblurr (DOF) sitter på en `Camera3D` och finns inte i en 2D-scen alls (i
## Godot 4.8-dev7 har `Environment` noll egenskaper med "dof" eller "blur" — MÄTT, se
## `references/byn-2p5d.md`). Det som finns är samma sak som webbygget redan använde: en FÖRMJUKAD
## KOPIA av konsten på det bakersta lagret (`mjuk_kopia`). Den är PÅ när renderaren inte kan blurra
## själv (`gl_compatibility`, alltså webben — ett bakersta lager ska aldrig vara skarpt och aldrig
## svart) eller när en granskning ber om den med `dof=1`; annars är lagret SKARPT, och det är vad som
## gör nolläget pixel-identiskt med den målade bilden. Husen, gångaren och alla UI-lager ritas alltid
## ur den SKARPA konsten — blurret kan inte nå dem, för det finns bara i bakgrundens textur.
class_name ByScen
extends RefCounted

## Husens avstånd i andelar av bakgrundens: 0,75 = en fjärdedel närmare kameran. Bakgrundens
## förskjutning delat med den är husens — kvoten ÄR parallaxen.
const DJUP_S := 0.75
const BAK_FAKTOR := 1.0
const HUS_FAKTOR := 1.0 / DJUP_S
## Kamerans största sidledsrörelse, i VYNS px. Liten med flit: husen är urklippta ur SAMMA bild som
## bakgrunden, och en stor rörelse hade glidit ifrån sina egna målade konturer och blottat hålet.
const SVEP := 16.0
## Den förmjukade kopian görs i den här skalan och tillbaka: 4 = en kvarts upplösning.
const MJUK_NED := 4
## Glödens bredd, i KONSTENS px. En konstpixel är en skärmpixel, så glöden är lika bred i varje
## fönsterstorlek.
const GLOD_PX := 3.0

## `dof=1`: förmjuka bakersta lagret även på skrivbordet (granskningsflagga — den mäter hur mycket av
## bildens mjukhet som kommer av avståndsblurret och hur mycket som är konsten själv).
static var dof_på := false

## Sant när det bakersta lagret ska vara en FÖRMJUKAD kopia av konsten. Webbygget kör
## `gl_compatibility`, där ingenting i scenen kan blurra: där är kopian PÅ.
static func mjuk_bak() -> bool:
	return dof_på or RenderingServer.get_current_rendering_method() == "gl_compatibility"

var vp: SubViewport = null
var kam: Camera2D = null
var _bak: Sprite2D = null
var _bak_textur: Texture2D = null
var _hus: Array = []                     ## Sprite2D per byggnad, i samma ordning som `hus`
## Markeringen: TVÅ glödar, för den valda och för den hovrade (de kan vara olika hus). Var och en
## använder husets EGEN textur, uppskalad en aning, och ligger UNDER husen — bara silhuettens
## ytterkant syns. Ingen gul ruta, och ingen egen form som kan glida ifrån huset den märker.
var _glodar: Array = []
var _figur: Sprite2D = null
var _vy := Vector2(480.0, 270.0)
var _skala := 1.0                        ## vyns px per konstpixel (1/fönstrets heltalsskala)
var _art := Vector2.ZERO
var _gata := 0.0                         ## gatans rad i KONSTENS px
var _pan := 0.0
var _kx := 0.0
var _ky := 0.0

func klar() -> bool:
	return vp != null and kam != null and _bak != null

## Bygg scenen. `bak` är den målade bilden med husen borttagna, `hus` en lista av
## `{"ruta": Rect2 (konstens px), "textur": Texture2D}`, `gata_px` gatans rad i konstens px och
## `skala` vyns px per konstpixel (`VillageView.bild_storlek().y / bildens höjd`).
func bygg(förälder: Node, vy: Vector2, bak: Texture2D, hus: Array, gata_px: float, skala: float) -> void:
	riv()
	_vy = vy
	_skala = skala
	_art = Vector2(bak.get_width(), bak.get_height())
	_gata = gata_px
	vp = SubViewport.new()
	vp.size = Vector2i(int(vy.x), int(vy.y))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	# INGEN utjämning: pixlarna ska vara pixlar. Samma skäl som förut.
	vp.msaa_2d = Viewport.MSAA_DISABLED
	förälder.add_child(vp)
	# UNDERLAGET. Konsten täcker vyn i varje fönsterstorlek, men en ruta i markfärgen ligger bakom
	# ändå: blir vyn en gång större än konsten ska kanten vara mark, inte projektets rensfärg.
	var under := ColorRect.new()
	under.color = Palett.c(1)
	under.position = Vector2(-4.0 * SVEP, -4.0 * SVEP)
	under.size = vy + Vector2(8.0 * SVEP, 8.0 * SVEP)
	vp.add_child(under)
	# KAMERAN. Fast övre vänsterhörn: i origo är canvas-transformen identitet, alltså ritas scenen
	# exakt där den platta bilden ritades. Det är hela nolläget.
	kam = Camera2D.new()
	kam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	vp.add_child(kam)
	# BAKGRUNDSLAGRET. Faktorn 1,0 = följer kameran som vanlig värld.
	var bak_lager := Parallax2D.new()
	bak_lager.scroll_scale = Vector2(BAK_FAKTOR, 1.0)
	vp.add_child(bak_lager)
	_bak_textur = mjuk_kopia(bak) if mjuk_bak() else bak
	_bak = Sprite2D.new()
	_bak.texture = _bak_textur
	_bak.centered = false
	_bak.scale = Vector2(_skala, _skala)
	_bak.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bak_lager.add_child(_bak)
	# HUSLAGRET. Husen står närmare kameran än tavlan bakom och rör sig därför MER (faktor 4/3 mot
	# bakgrundens 1,0) — men den extra rörelsen läggs på i `_hus_position` i stället för här: Parallax2D
	# lägger sin förskjutning på en bråkdel av en vyn-pixel, och då hamnar husens konstpixel mellan två
	# vyn-pixlar och detaljerna byter plats i små steg när man panorerar (mätt i 941x1018: upprätning av
	# huslagret gav rest-SAD 7,03 i stället för 0, medan bakgrunden gav 0,000). `_lås` lägger extra-
	# rörelsen på konstens pixelgrid, så huset hamnar på hela skärmpixlar i VARJE kameraläge.
	var hus_lager := Parallax2D.new()
	hus_lager.scroll_scale = Vector2(BAK_FAKTOR, 1.0)
	vp.add_child(hus_lager)
	# MARKERINGEN ligger UNDER husen och använder husets EGEN textur, uppskalad en aning: bara
	# silhuettens ytterkant syns, som en glöd runt byggnaden. Ingen gul ruta, och ingen egen form som
	# kan glida ifrån huset den märker.
	_glodar.clear()
	for _k in 2:
		var g := Sprite2D.new()
		g.centered = true
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# ADDITIV blandning: glöden LÄGGS till bilden i stället för att måla över den, så en glöd
		# över ett mörkt tak lyser upp det i stället för att grumla det. I Godot 4 bor blandningen på
		# en CanvasItemMaterial (på noden hette den `blend_mode` i Godot 3).
		var gm := CanvasItemMaterial.new()
		gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = gm
		g.visible = false
		hus_lager.add_child(g)
		_glodar.append(g)
	_hus.clear()
	for h in hus:
		var r: Rect2 = h["ruta"]
		var s := Sprite2D.new()
		s.texture = h["textur"]
		s.centered = false
		s.scale = Vector2(_skala, _skala)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("ruta", r)
		hus_lager.add_child(s)
		_hus.append(s)
	# GÅNGAREN står på husens lager: hon går på gatan, framför husen, och följer dem när kameran rör
	# sig i stället för att glida mot tavlan bakom.
	_figur = Sprite2D.new()
	_figur.centered = false
	_figur.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figur.visible = false
	hus_lager.add_child(_figur)
	_sätt_allt()

## KONSTENS PIXELGRID. En konstpixel är en skärmpixel bara om konstens kant ligger på en hel konstpixel:
## steg = `_skala` vyn-px (en konstpixel). En halv pixel fel ger ojämna pixlar (två breda på sina
## ställen och tre på andra) fastän skalningen i sig är heltalig. Samma låsning som den platta vyn
## använde (`VillageView._pixel_låst`).
func _lås(v: float) -> float:
	if _skala <= 0.0:
		return v
	return roundf(v / _skala) * _skala

## Gatulinjen i vyn: samma andel av höjden som i byn.
func marklinje() -> float:
	return _vy.y * 0.78

## Konstens rad 0 i vyns px — låst till pixelgriden, så husen hamnar på sin egen rad ur bilden.
func topp_px() -> float:
	return _lås(marklinje() - _gata * _skala)

## En konstpunkts ruta i vyn, för en byggnad: rutan ligger på pixelgriden (hela konstpixlar), så
## huset hamnar dikt över sitt eget hål i bakgrunden.
func _lager_position(r: Rect2) -> Vector2:
	return Vector2(_lås(r.position.x * _skala - _pan), _lås(topp_px() + r.position.y * _skala))

## Husens EXTRA kamera-rörelse (faktor 4/3 mot bakgrundens 1,0), räknad ur `_kx` och låst till HELA
## vyn-pixlar. Inte till konstens grid: lagret ritas i vyns upplösning, och ligger det på en halv
## vyn-pixel väljer två grannpixlar i vyn OLIKA konstpixlar — då blir panoreringen inte en ren
## förskjutning av bilden (mätt: rest-SAD 8,48 mot 0,00 när förskjutningen hamnade på 5,5 vyn-px).
## I höjdled 0 — samma faktor uppåt som bakgrunden, annars lossnar fötterna från gatan.
## ponytail: hela vyn-px betyder att kamerarörelser under 1,5 vyn-px ger exakt samma rörelse som
## bakgrunden (ingen paralax alls) — 9 % av svepet. Uppgradera med en egen rasterisering av lagret
## (rita husen ur en SubViewport i SKÄRMENS upplösning) om djupet måste kännas från första pixeln.
func hus_forskjutning() -> Vector2:
	return Vector2(roundf(_kx * (HUS_FAKTOR / BAK_FAKTOR - 1.0)), 0.0)

func _hus_position(r: Rect2) -> Vector2:
	return _lager_position(r) + hus_forskjutning()

func _sätt_allt() -> void:
	if _bak != null:
		_bak.position = _lager_position(Rect2(Vector2.ZERO, Vector2.ZERO))
	for s in _hus:
		(s as Sprite2D).position = _hus_position((s as Sprite2D).get_meta("ruta"))
	for g in _glodar:
		if (g as Sprite2D).visible:
			_sätt_glod(g)
	if _figur != null and _figur.visible:
		_figur.position = _figur_position()

func _figur_position() -> Vector2:
	return Vector2(_lås(float(_figur.get_meta("ax")) * _skala - _pan),
		_lås(topp_px() + float(_figur.get_meta("ay")) * _skala)) + hus_forskjutning()

func sätt_pan(pan: float) -> void:
	_pan = pan
	_sätt_allt()

## Kameran i sidled och höjdled, i VYNS px, klamd till SVEP — se konstanten. Den ritas inte ut som en
## förskjutning här: kameran flyttar lagren, och lagren flyttar olika mycket. Det är parallaxen.
func sätt_kamera(kx: float, ky: float) -> void:
	_kx = clampf(kx, -SVEP, SVEP)
	_ky = clampf(ky, -SVEP, SVEP)
	if kam != null:
		kam.position = Vector2(-_kx, _ky)
	# Husens extra rörelse räknas ur `_kx` och läggs på HÄR, inte av Parallax2D (se hus_lager): den
	# blir alltså rätt i samma bildruta som kameran flyttas, utan att vänta på lagrets processnotis.
	_sätt_allt()

func kameraposition() -> Vector2:
	return Vector2(_kx, _ky)

## Lagrens parallaxfaktorer: bakgrunden först, husen sedan. Är de lika är det en bild som rör sig.
func lagerfaktorer() -> Vector2:
	return Vector2(BAK_FAKTOR, HUS_FAKTOR)

## MARKERINGEN: den valda byggnaden får en stark glöd runt sin EGEN silhuett, den hovrade en svagare.
## Glöden ligger under huset och huset är ogenomskinligt där det är hus, så bara silhuettens ytterkant
## syns — markeringen ÄR byggnadens form, inte en ruta runt den.
func sätt_markering(vald: int, hovrad: int = -1) -> void:
	_markera(0, vald, 1.0)
	_markera(1, hovrad if hovrad != vald else -1, 0.75)

func _markera(k: int, i: int, alfa: float) -> void:
	if k >= _glodar.size():
		return
	var g: Sprite2D = _glodar[k]
	if i < 0 or i >= _hus.size():
		g.visible = false
		return
	g.texture = (_hus[i] as Sprite2D).texture
	g.set_meta("ruta", (_hus[i] as Sprite2D).get_meta("ruta"))
	g.set_meta("alfa", alfa)
	g.visible = true
	_sätt_glod(g)

func _sätt_glod(g: Sprite2D) -> void:
	var r: Rect2 = g.get_meta("ruta")
	g.scale = Vector2(_skala * (r.size.x + 2.0 * GLOD_PX) / r.size.x,
		_skala * (r.size.y + 2.0 * GLOD_PX) / r.size.y)
	g.position = Vector2(_lås((r.position.x + r.size.x * 0.5) * _skala - _pan),
		_lås(topp_px() + (r.position.y + r.size.y * 0.5) * _skala)) + hus_forskjutning()
	var a := float(g.get_meta("alfa"))
	g.modulate = Color(1.0, 0.86, 0.45, a)

## Gångaren. `ax` och `ay` är i KONSTENS px (samma ruta som husen och gatan mäts i): en konstpixel är
## en skärmpixel, så `storlek_px` är figurens storlek både i konsten och på skärmen.
func sätt_figur(textur: Texture2D, ax: float, ay: float, storlek_px: Vector2, syns: bool) -> void:
	if _figur == null:
		return
	_figur.visible = syns
	if not syns or textur == null:
		return
	if _figur.texture != textur:
		_figur.texture = textur
	_figur.scale = Vector2(_skala * storlek_px.x / maxf(1.0, float(textur.get_width())),
		_skala * storlek_px.y / maxf(1.0, float(textur.get_height())))
	_figur.set_meta("ax", ax)
	_figur.set_meta("ay", ay)
	_figur.position = _figur_position()

## Bilden vyn ritar (den inre vyns textur). Null när scenen inte är byggd — då ritar vyn sin platta.
func textur() -> Texture2D:
	return vp.get_texture() if vp != null else null

func bakgrund_textur() -> Texture2D:
	return _bak_textur

## En konstpunkt som SKÄRMPUNKT, läst ur NODENS EGEN canvas-transform — provet mäter samma sak som
## ritas och inte en egen kopia av formeln. Spriten har `scale = _skala`, så transformen gör redan
## konstpixel-till-vyn-pixel: punkten matas in i KONSTENS px.
func bak_skärmpunkt(ax: float, ay: float) -> Vector2:
	if _bak == null:
		return Vector2.ZERO
	return _bak.get_global_transform_with_canvas() * Vector2(ax, ay)

func hus_skärmpunkt(i: int, ax: float, ay: float) -> Vector2:
	if i < 0 or i >= _hus.size():
		return Vector2.ZERO
	var s: Sprite2D = _hus[i]
	var r: Rect2 = s.get_meta("ruta")
	return s.get_global_transform_with_canvas() * (Vector2(ax, ay) - r.position)

## Den förmjukade kopian av konsten — ned i en kvarts upplösning och upp igen med mjukt filter.
## Används på det BAKERSTA lagret när djupblurr inte finns (webbygget) eller en granskning ber om den,
## så att "avstånd" betyder något även där i stället för att bli skarpt.
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
	_bak = null
	_bak_textur = null
	_hus.clear()
	_glodar.clear()
	_figur = null
