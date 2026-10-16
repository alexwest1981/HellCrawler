class_name Voxel
extends RefCounted

## En voxelmodell byggd ur en pixelbild — samma ark som figurerna i dag ritas från.
##
## VARFÖR (Alex 11/10): "jag bad ju om att göra om dem till voxlar eller liknande som kan gå sönder vid
## attack, de är ännu platta png's". En billboard kan per konstruktion inte gå sönder; en voxelmodell
## kan — cellerna tas bort en och en där slaget träffar, och blir spillror.
##
## INGEN NY KONST OCH INGEN BLENDER: varje SYNLIG pixel i arket blir en kub. Arket är 120x120 px per
## ruta, vilket är för många kuber för en mesh i en strid, så bilden sampas ned till ett rutnät på
## `sidor` celler i bredd och blir `djup` celler tjock — figuren är en relief, inte en skulptur.
##
## Bara YTTERYTOR läggs in: en kub vars granne finns bidrar inte med den sidan. Norm och färg sätts per
## hörn (normalen ur riktningen, aldrig ur vindningen), så ljuset blir rätt även om en triangels
## ordning skulle bli fel — materialet ritar dessutom båda sidorna.
##
## Matt yta (0,9), precis som resten av pixelkonsten (M59): blank plast har ingen plats i källaren.

const GRANS := 0.35                  ## täckning över vilken en cell räknas som figur
const SVART_GRANS := 0.06            ## ljushet under vilken en pixel ser ut som bakgrund (svart duk)

## CELLTÄTHETEN (M116). Alex 12/10: *"Öka grafiken på alla objekt med, dubblera om det behövs"*, efter
## att föremålen lästs som grovhuggna. Det som avgör hur fin en modell är hur många CELLER varje
## KÄLLPIXEL blir: anroparen ber om ett antal celler i höjd (`antal_sidor` — i praktiken `VOXEL_SIDOR`
## eller figurens egen höjd i px), och den här ratten mångdubblar den. 2 = varje källpixel blir 2x2
## celler, alltså halva kubstorleken i världen. EN ratt för ALLA modeller (fiender, kistor, rekvisita,
## flora) — alla går genom `ur_ark`.
##
## TAKET ÄR KÄLLKONSTEN, inte en siffra: över två celler per källpixel finns ingen information kvar,
## bara fler ytor. Mätt FÖRE ratten: en fiende på 92 px blev 0,70 celler per pixel (varannan rad borta),
## medan en 16x5 px mossa fick 12,8 — 26 240 celler och 54 632 trianglar för en tuva. Taket
## `DETALJ * figurens höjd i px` ger den stora figuren tillbaka sin detalj och den lilla sin form.
const DETALJ := 2                    ## celler per källpixel (tak; se ovan)

const HORN := {
	Vector3i(1, 0, 0): [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	Vector3i(-1, 0, 0): [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	Vector3i(0, 1, 0): [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	Vector3i(0, -1, 0): [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	Vector3i(0, 0, 1): [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	Vector3i(0, 0, -1): [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
}

var sidor: int = 32                  ## celler i bredd (arket är kvadratiskt per ruta)
var djup: int = 2                    ## celler i tjocklek
var höjd: float = 1.0                ## figurens höjd i meter
var celler := {}                     ## Vector3i -> Color: modellen som den ser ut NU (hugg tömmer den)
var kolumner: int = 32               ## celler i sidled, ur figurens egen bredd (sätts av ur_ark)
## Figurens ruta i arket (px), så anroparen kan räkna ut var modellen ska stå i förhållande till
## billboardens ruta — och hur hög den är i meter (`ruta.size.y * pixel_size`).
var ruta := Rect2()

var _mesh: ArrayMesh = null
## Modellen centreras kring nodens origo, precis som Sprite3D:s mitt: figurens mitt hamnar där noden
## står, och fötterna på position.y - höjd/2. Utan det står modellen med vänsterkanten i nodens origo
## och hamnar en halv figur fel i sidled.
var _förskjutning := Vector3.ZERO


## Figurens mått i KÄLLPIXLAR (bredd, höjd) — alfans omfång i rutan.
##
## Mätt: candlewispens cell är 120x120 px men figuren är 105 px hög. Att räkna höjden ur CELLEN (34 px,
## som healthbaren gör) gav en voxelmodell på 0,41 m medan spöket på skärmen är 105 x 0,012 = 1,26 m —
## den stod som ett litet grönt skräp på golvet bredvid figuren den skulle ersätta. Höjden ska räknas ur
## figurens EGEN höjd gånger pixel_size, och den här ger måttet.
static func figur_ruta(tex: Texture2D, ruta: int, rutor: int) -> Rect2:
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null:
		return Rect2()
	var fw: int = img.get_width() / maxi(1, rutor)
	var fh: int = img.get_height()
	# Bakgrunden räknas EN gång per RUTA, inte per cell (flodfyllning från ramen), och bara den som
	# hänger ihop med ramen tas bort — en svart mantel inuti figuren blir kvar som figur.
	var bg := bakgrund(img, Rect2(Vector2(ruta * fw, 0), Vector2(fw, fh)))
	var x_min := fw
	var x_max := -1
	var y_min := fh
	var y_max := -1
	for py in fh:
		for px in fw:
			if bg[py * fw + px] == 0:
				x_min = mini(x_min, px)
				x_max = maxi(x_max, px)
				y_min = mini(y_min, py)
				y_max = maxi(y_max, py)
	if x_max < x_min or y_max < y_min:
		return Rect2()
	# POSITIONEN OCKSÅ, inte bara storleken: figuren sitter inte alltid mitt i arkrutan, och en voxel
	# som centreras på rutan hamnar en bit fel (upp eller ned) jämfört med var billboarden ritade den.
	return Rect2(Vector2(x_min, y_min), Vector2(x_max - x_min + 1, y_max - y_min + 1))


## Bygg ur en ruta i ett ark. `ruta` är rutan i sidled (figurerna ligger som en vågrät remsa),
## `rutor` är antalet rutor i arket.
## DUKENS FÄRG LÄSES UR KANTEN (M108). Alex: *"Eller om någon annan färg funkar bättre, typ rosa
## eller vit, grön..."* — den behöver inte väljas alls. Den vanligaste ogenomskinliga färgen längs
## ramen ÄR duken, så svart, vit, rosa, grön och alfa spelar samma roll, utan en inställning.
##
## Färgen kvantiseras (5 bitar per kanal) och kräver en majoritet av kanten: en bild utan duk — eller
## en där figuren når ända ut — får ingen nyckel, och då avgör alfan ensam. Annars hade en fullmatad
## bild kunnat äta upp sig själv.
static func nyckelfärg(img: Image, r: Rect2) -> Color:
	var räknare := {}
	var w := int(r.size.x)
	var h := int(r.size.y)
	var röster: Array = []
	for x in w:
		for y in [0, h - 1]:
			röster.append(Vector2i(x, y))
	for y in h:
		for x in [0, w - 1]:
			röster.append(Vector2i(x, y))
	for p in röster:
		var c := img.get_pixel(int(r.position.x) + p.x, int(r.position.y) + p.y)
		if c.a < GRANS:
			continue
		var nyckel := Vector3i(int(c.r * 32.0), int(c.g * 32.0), int(c.b * 32.0))
		if not räknare.has(nyckel):
			räknare[nyckel] = [0, Vector3.ZERO]
		var post: Array = räknare[nyckel]
		post[0] = int(post[0]) + 1
		post[1] = Vector3(post[1]) + Vector3(c.r, c.g, c.b)
	var bäst := 0
	var färg := Color(0, 0, 0, 0)
	for k in räknare:
		var post: Array = räknare[k]
		if int(post[0]) > bäst:
			bäst = int(post[0])
			färg = Color(post[1].x / post[0], post[1].y / post[0], post[1].z / post[0])
	return färg if float(bäst) >= float(röster.size()) * 0.4 else Color(0, 0, 0, 0)


## En pixel är TOM om den är genomskinlig eller ligger nära dukens färg. Toleransen är tilltagen (0,18)
## för att en kant mot duken är halvtransparent och brusig — och den är ofarlig, för bara den bakgrund
## som HÄNGER IHOP MED KANTEN tas bort. En mörk fläck inuti figuren ligger inte nära kanten.
static func _tom(img: Image, x: int, y: int, nyckel: Color) -> bool:
	var c := img.get_pixel(x, y)
	if c.a < GRANS:
		return true
	if nyckel.a <= 0.0:
		return false
	return Vector3(c.r - nyckel.r, c.g - nyckel.g, c.b - nyckel.b).length() < 0.18


## BAKGRUNDEN, på riktigt (M108). Alex: *"bygga någon motor som kan göra fiender i voxlar av en bild —
## med färger från bilden, där den skiter i den svarta bakgrunden runtom men gör voxlar av allt inuti."*
##
## Flodfyllning från rektangelns kant: allt som hänger ihop med kanten OCH ser tomt ut är bakgrund.
## En färgtröskel hade räckt ända till första svarta manteln — en svart yta INUTI figuren når inte
## kanten och blir därför figur, precis som han beskrev det ("allt inuti").
static func bakgrund(img: Image, r: Rect2) -> PackedByteArray:
	var w := int(r.size.x)
	var h := int(r.size.y)
	var nyckel := nyckelfärg(img, r)
	var bg := PackedByteArray()
	bg.resize(w * h)
	var kö: Array = []
	var sådd := func(x: int, y: int) -> void:
		var i := y * w + x
		if bg[i] == 0 and _tom(img, int(r.position.x) + x, int(r.position.y) + y, nyckel):
			bg[i] = 1
			kö.append(i)
	for x in w:
		sådd.call(x, 0)
		sådd.call(x, h - 1)
	for y in h:
		sådd.call(0, y)
		sådd.call(w - 1, y)
	var huvud := 0
	while huvud < kö.size():
		var i: int = kö[huvud]
		huvud += 1
		var x := i % w
		var y := i / w
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + int(d[0])
			var ny: int = y + int(d[1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if bg[ny * w + nx] == 1:
				continue
			if not _tom(img, int(r.position.x) + nx, int(r.position.y) + ny, nyckel):
				continue
			bg[ny * w + nx] = 1
			kö.append(ny * w + nx)
	# SPRICKORNA STÄNGS. I en platt bild är en genomskinlig pixelrad mellan huvudet och kroppen, eller
	# inne i munnen, en detalj. Som voxlar blir samma rad ett HÅL rakt igenom modellen. Alex: "Det är
	# lite glipor i hunden, mellan huvuden å i munnen osv, tror det är för att den räknat bort det som
	# mask?" — ja, precis så. En stängning (väx en pixel, krymp en pixel) lagar varje spricka som är en
	# pixel bred och lämnar figurens silhuett orörd.
	return _stäng(bg, w, h)


## Morfologisk stängning på figuren (bg: 0 = figur, 1 = bakgrund): väx figuren ett steg och krymp den
## igen. En spricka som är en pixel bred försvinner, en rak kant står kvar, och en ensam lös pixel (som
## krymper bort) hade ändå blivit en kub utan kontakt med figuren.
static func _stäng(bg: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var växt := PackedByteArray()
	växt.resize(w * h)
	# PackedByteArray fylls med NOLLOR, och noll betyder FIGUR här — utan den här raden var hela rutan
	# figur redan från början, och stängningen lämnade en fylld kvadrat (mätt: 8 192 celler i 64x64 rutor
	# för en hund på 73x64 px). Allt är bakgrund tills växningen säger annat.
	växt.fill(1)
	for y in h:
		for x in w:
			if bg[y * w + x] == 0:
				växt[y * w + x] = 0
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]:
					var nx: int = x + int(d[0])
					var ny: int = y + int(d[1])
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						växt[ny * w + nx] = 0
	var ut := PackedByteArray()
	ut.resize(w * h)
	for y in h:
		for x in w:
			if växt[y * w + x] == 1:
				ut[y * w + x] = 1
				continue
			var hel := true
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]:
				var nx: int = x + int(d[0])
				var ny: int = y + int(d[1])
				if nx < 0 or ny < 0 or nx >= w or ny >= h or växt[ny * w + nx] == 1:
					hel = false
					break
			ut[y * w + x] = 0 if hel else 1
	return ut


## Bakgrunden ur ALFAN, för ark som redan är utklippta (byborna, M129). Flodfyllningen nedan kostar
## en runda över varje pixel i GDScript och är till för ett ark med OGENOMSKINLIG duk; har bilden
## redan genomskinlig bakgrund är alfan hela sanningen, och då är den här vägen ~4x billigare.
## MÄTT 15/10: 21 bybor med flodfyllning 1 250 ms, med alfan i stället 250 ms.
static func bakgrund_ur_alfa(img: Image, r: Rect2) -> PackedByteArray:
	var w := int(r.size.x)
	var h := int(r.size.y)
	var bg := PackedByteArray()
	bg.resize(w * h)
	for y in h:
		for x in w:
			if img.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a < GRANS:
				bg[y * w + x] = 1
	return bg


static func ur_ark(tex: Texture2D, ruta: int, rutor: int, figur_höjd: float,
		antal_sidor: int = 32, antal_djup: int = 2, bakgrundsprov: bool = true) -> Voxel:
	var v := Voxel.new()
	v.sidor = antal_sidor
	v.djup = antal_djup
	v.höjd = figur_höjd
	if tex == null:
		return v
	var img := tex.get_image()
	if img == null:
		return v
	var fw: int = img.get_width() / maxi(1, rutor)
	var fh: int = img.get_height()
	# FIGURENS RUTA, INTE HELA CELLEN. Arket har en tom ram runt figuren (cellen är 120x120 px och
	# figuren ungefär 34 px), så att sampla hela cellen gav en pyttefigur i ett hav av tomma celler.
	# Alfans omfång hittas först och bara det sampas: då går hela rutnätet åt figuren, och höjden i
	# meter betyder figurens höjd — samma mått som healthbaren räknar ur (34 x pixel_size).
	# Bakgrunden räknas EN gång per RUTA, inte per cell (flodfyllning från ramen), och bara den som
	# hänger ihop med ramen tas bort — en svart mantel inuti figuren blir kvar som figur.
	var bg := bakgrund(img, Rect2(Vector2(ruta * fw, 0), Vector2(fw, fh))) if bakgrundsprov \
		else bakgrund_ur_alfa(img, Rect2(Vector2(ruta * fw, 0), Vector2(fw, fh)))
	var x_min := fw
	var x_max := -1
	var y_min := fh
	var y_max := -1
	for py in fh:
		for px in fw:
			if bg[py * fw + px] == 0:
				x_min = mini(x_min, px)
				x_max = maxi(x_max, px)
				y_min = mini(y_min, py)
				y_max = maxi(y_max, py)
	if x_max < x_min or y_max < y_min:
		return v                              # tom ruta
	var bw := x_max - x_min + 1
	var bh := y_max - y_min + 1
	v.ruta = Rect2(Vector2(x_min, y_min), Vector2(bw, bh))
	# CELLTÄTHETEN (M116): anroparens begäran mångdubblas — men aldrig förbi `DETALJ` celler per
	# källpixel, för över källkonstens egen pixelgrid finns ingen information kvar (se `DETALJ`).
	v.sidor = clampi(antal_sidor * DETALJ, 1, maxi(1, bh * DETALJ))
	# Cellen är LIKA många källpixlar i x och y (annars blir voxlarna rektanglar), och antalet celler i
	# sidled följer figurens bredd — en smal figur ska inte töjas ut till en kvadrat.
	var cell := float(bh) / float(v.sidor)
	var kol := maxi(1, roundi(float(bw) / cell))
	v.kolumner = kol
	# Cell y räknas NEDIFRÅN och källan uppifrån: en bild har sin rad 0 högst upp.
	for cy in v.sidor:
		var y0 := y_min + int(cy * cell)
		var y1 := maxi(y0 + 1, y_min + int((cy + 1) * cell))
		for cx in kol:
			var x0 := x_min + int(cx * cell)
			var x1 := maxi(x0 + 1, x_min + int((cx + 1) * cell))
			var summa := Vector3.ZERO
			var n := 0
			for py in range(y0, mini(y1, y_max + 1)):
				for px in range(x0, mini(x1, x_max + 1)):
					if bg[py * fw + px] == 1:
						continue                       # bakgrund, och bara den som når kanten
					var c := img.get_pixel(ruta * fw + px, py)
					summa += Vector3(c.r, c.g, c.b)
					n += 1
			# Cellen blir en voxel om tillräckligt mycket av den är figur — en tunn kant ska inte bli
			# en klump, och en cell som bara snuddar figuren ska inte bli något alls.
			if n == 0 or float(n) / float(maxi(1, (y1 - y0) * (x1 - x0))) < GRANS:
				continue
			var färg := Color(summa.x / float(n), summa.y / float(n), summa.z / float(n))
			# FIGUREN STÅR RÄTT VÄG. `cy` räknas nedifrån (modellens y=0 är fötterna) medan `y0` räknas
			# uppifrån (en bild har sin rad 0 högst upp) — utan speglingen hamnade bildens översta rad i
			# modellens nederkant och figuren blev UPP OCH NED: mätt såg hunden ut som en varelse med
			# utskotten uppåt, och Alex kände inte igen den alls.
			for k in v.djup:
				v.celler[Vector3i(cx, v.sidor - 1 - cy, k)] = färg
	v._förskjutning = Vector3(-float(kol) * 0.5, -float(v.sidor) * 0.5, -float(v.djup) * 0.5)
	v._bygg_mesh()
	return v


## BARA DE SYNLIGA CELLERNA (M143). Alex 16/10: *"Bara de synliga cellerna"*. En solid kropp är mest
## inre celler, och `_bygg_mesh` hoppar ändå över varje yta som har en granne — de inre cellerna kostar
## alltså ingenting i bilden, bara minne, byggtid och celltaket. En cell behålls om minst en av dess
## sex grannar är tom (den har då minst en yta kvar); resten stryks. Ytorna blir EXAKT desamma, så
## bilden är oförändrad — mätt: samma rendering på pixeln, men cellerna räckte till dubbelt djup.
## Anropas av den som vill ha djup utan att betala för gods som aldrig syns; modeller som ska HUGGAS
## (fienderna i striden) lämnas solida, för där river varje borttagen cell fram nya ytor.
## Returnerar antalet celler kvar.
func bara_synliga() -> int:
	var kvar := {}
	for nyckel in celler:
		var c: Vector3i = nyckel
		for riktning in HORN:
			if not celler.has(c + riktning):
				kvar[nyckel] = celler[nyckel]
				break
	celler = kvar
	return celler.size()


## Meshen som den ser ut nu. Byggs om efter ett hugg (några tusen ytor tar en bråkdel av en bildruta,
## och ett hugg händer en gång per kort).
func mesh() -> ArrayMesh:
	if _mesh == null:
		_bygg_mesh()
	return _mesh


func _bygg_mesh() -> void:
	var st := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var s := höjd / float(sidor)              # en cell i meter
	# x räknas från figurens vänsterkant, alltså från 0: rutnätet är redan kring figuren, så en
	# förskjutning hade flyttat hela modellen i sidled.
	for cell in celler:
		var färg: Color = celler[cell]
		for riktning in HORN:
			if celler.has(cell + riktning):
				continue                      # grannen finns: den sidan är inte en yta
			var hörn: Array = HORN[riktning]
			var bas := st.size()
			for h in hörn:
				st.append((Vector3(cell.x, cell.y, cell.z) + h + _förskjutning) * s)
				nor.append(Vector3(riktning))
				col.append(färg)
			idx.append_array([bas, bas + 1, bas + 2, bas, bas + 2, bas + 3])
	var ary := []
	ary.resize(Mesh.ARRAY_MAX)
	ary[Mesh.ARRAY_VERTEX] = st
	ary[Mesh.ARRAY_NORMAL] = nor
	ary[Mesh.ARRAY_COLOR] = col
	ary[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if st.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ary)
	_mesh = m


## Nuvarande mesh i en nod som kan läggas i världen. Cellerna byggs i meter, så noden skalas inte.
func nod() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh()
	mi.material_override = material()
	return mi


## MODELLENS MATERIAL (M112). Ett `ShaderMaterial` i stället för `StandardMaterial3D`, av ETT skäl:
## fienden ska lysa svagt av SIN EGEN färg när ljuset står bakom den (Alex: *"då är de grådassiga, så
## man skulle behöva avge lite ljus själv"*). Det går inte att uttrycka i `StandardMaterial3D` —
## emissionen där är en FAST färg, och en fast färg över hela kroppen är precis vad som mättes bort i
## M74: "en fast emission lägger samma ljus över allt och späder ut figurens egna färger".
##
## Shadern (`ui/voxel_fiende.gdshader`) låter Godots EGEN ljusmodell vara kvar — ingen `light()`-funktion
## skrivs — och lägger bara på `EMISSION = färgen * min_ljus`. Facklorna, lyktan och skuggorna lyser
## modellen exakt som förut; det som ändras är golvet under ljuset.
##
## `min_ljus` är en ratt och inte en siffra i shadern: provet mäter skillnaden mot `minljus=0` (den
## gamla modellen) i SAMMA scen, och Alex kan dra i den utan att shadern kompileras om.
static var min_ljus := 0.20

## MATERIALET ÄR ETT FÖR ALLA MODELLER. Ett eget `ShaderMaterial` per `nod()` är dyrare utan att köpa
## något: inställningarna är globala, och varje material är sin egen shadervariant att kompilera.
static var _material: ShaderMaterial = null

static func material() -> Material:
	if _material == null:
		var sh: Shader = load("res://ui/voxel_fiende.gdshader")
		_material = ShaderMaterial.new()
		_material.shader = sh
		_material.set_shader_parameter("grovhet", 0.9)
	_material.set_shader_parameter("min_ljus", min_ljus)
	return _material


## FIGUREN GÅR SÖNDER: cellerna inom `radie` från `lokal_punkt` tas bort och meshen byggs om.
## Returnerar cellernas färger, så anroparen kan låta dem flyga som spillror.
## ponytail: hela meshen byggs om per hugg (några tusen ytor) — bygg bara den berörda delen om någon
## mäter att det känns.
func hugg(lokal_punkt: Vector3, radie: float) -> Array:
	var s := höjd / float(sidor)
	var borta: Array = []
	var r2 := radie * radie
	for cell in celler.keys():
		var mitten := (Vector3(cell) + Vector3(0.5, 0.5, 0.5) + _förskjutning) * s
		if mitten.distance_squared_to(lokal_punkt) <= r2:
			borta.append(celler[cell])
			celler.erase(cell)
	if not borta.is_empty():
		_mesh = null                          # byggs på nytt vid nästa mesh()
	return borta


## LOSSA BITAR (M108). Alex: "Det kan lossna random bitar av fienden om de inte dör direkt av
## attacken." Ytterkanten först — en flisa slås av en figur som står kvar, och mittcellerna håller
## ihop den tills den faller.
## Returnerar de borttagna cellerna som {cell: värde} — inte bara värdena (M115). Den som tar emot flisan
## ska kunna bygga bitar av den SOM FLYGER (se `VoxelRas`), inte bara bygga om modellen: Alex 12/10:
## *"Vad hände med att det skulle lossna voxlar vid attack?"* — cellerna lossnade, men flög aldrig.
func lossna(antal: int) -> Dictionary:
	var borta: Dictionary = {}
	if antal <= 0 or celler.is_empty():
		return borta
	# Hur många grannar varje cell har: ju färre, desto mer utsatt kant.
	var kandidater: Array = []
	for cell in celler.keys():
		var grannar := 0
		for riktning in HORN:
			if celler.has(cell + riktning):
				grannar += 1
		kandidater.append([grannar, cell])
	kandidater.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	# Slumpa bland de yttre: annars lossnar alltid samma flisa.
	var yttre: Array = []
	for i in mini(kandidater.size(), maxi(antal * 3, antal)):
		yttre.append(kandidater[i][1])
	yttre.shuffle()
	for i in mini(antal, yttre.size()):
		borta[yttre[i]] = celler[yttre[i]]
		celler.erase(yttre[i])
	if not borta.is_empty():
		_mesh = null
	return borta


## DÖDSRASET, I STEG (M108). Alex: "de ramlar sönder i bitar när de dör, eller så går det för fort. I
## så fall får du sakta ner det ordentligt."
##
## Tar bort alla celler under andelen `f` av höjden: 0 = allt kvar, 1 = tomt. Raset går NEDIFRÅN och upp,
## för en kropp faller ihop underifrån — den försvinner inte uppifrån. Anropas upprepade gånger av en
## tween i stället för att tömmas i ett enda steg, som var Alex' klagomål: figuren slocknade i stället för
## att rasa.
func rasa_till(f: float) -> int:
	var gräns := f * float(sidor)
	var borta := 0
	for cell in celler.keys():
		if float(cell.y) < gräns:
			celler.erase(cell)
			borta += 1
	if borta > 0:
		_mesh = null
	return borta


func antal_celler() -> int:
	return celler.size()


func antal_ytor() -> int:
	var m := mesh()
	if m == null or m.get_surface_count() == 0:
		return 0
	return m.surface_get_array_index_len(0) / 3
