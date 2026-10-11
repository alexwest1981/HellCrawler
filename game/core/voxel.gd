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

const GRANS := 0.35                  ## alfavärde över vilket en källpixel räknas som figur

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
	var x_min := fw
	var x_max := -1
	var y_min := fh
	var y_max := -1
	for py in fh:
		for px in fw:
			if img.get_pixel(ruta * fw + px, py).a >= GRANS:
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
static func ur_ark(tex: Texture2D, ruta: int, rutor: int, figur_höjd: float,
		antal_sidor: int = 32, antal_djup: int = 2) -> Voxel:
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
	var x_min := fw
	var x_max := -1
	var y_min := fh
	var y_max := -1
	for py in fh:
		for px in fw:
			if img.get_pixel(ruta * fw + px, py).a >= GRANS:
				x_min = mini(x_min, px)
				x_max = maxi(x_max, px)
				y_min = mini(y_min, py)
				y_max = maxi(y_max, py)
	if x_max < x_min or y_max < y_min:
		return v                              # tom ruta
	var bw := x_max - x_min + 1
	var bh := y_max - y_min + 1
	v.ruta = Rect2(Vector2(x_min, y_min), Vector2(bw, bh))
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
			var alfa := 0.0
			var n := 0
			for py in range(y0, mini(y1, y_max + 1)):
				for px in range(x0, mini(x1, x_max + 1)):
					var c := img.get_pixel(ruta * fw + px, py)
					# Alfaviktat medel: en kantpixel med låg alfa får inte bleka hela cellen.
					summa += Vector3(c.r, c.g, c.b) * c.a
					alfa += c.a
					n += 1
			if n == 0 or alfa / float(n) < GRANS:
				continue
			var färg := Color(summa.x / alfa, summa.y / alfa, summa.z / alfa)
			for k in v.djup:
				v.celler[Vector3i(cx, cy, k)] = färg
	v._förskjutning = Vector3(-float(kol) * 0.5, -float(v.sidor) * 0.5, -float(v.djup) * 0.5)
	v._bygg_mesh()
	return v


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
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9                       # matt yta, som resten av pixelkonsten (M59)
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.metallic = 0.0
	# FIGUREN BÄR SITT EGET LJUS (M74:s regel: en varelse i källaren lyser av sig själv). Utan emission
	# är en shaded voxelmodell i en mörk gång nästan svart — mätt i första renderingen: området kring
	# noden visade bara golvets rutnät, ingen figur. Emissionen är en kall ton (vålnadens egen) och låg,
	# så facklorna fortfarande SYNS på ytorna — vilket är hela poängen med att gå från platt bild till
	# geometri. Sprites löser samma sak med en additiv aura-quad (M72); en mesh kan bära det själv.
	mat.emission_enabled = true
	mat.emission = Color(0.52, 0.60, 0.72)
	mat.emission_energy_multiplier = 0.42
	mi.material_override = mat
	return mi


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
func lossna(antal: int) -> Array:
	var borta: Array = []
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
		borta.append(celler[yttre[i]])
		celler.erase(yttre[i])
	if not borta.is_empty():
		_mesh = null
	return borta


## HELA FIGUREN RASAR (M108). Alex: "Om de dör skall de rasa sönder i småbitar och försvinna."
## Returnerar antalet celler som gick sönder. Bitarna som flyger är samma `pixelregn` som redan
## spiller vid en träff (och mer av det vid ett dråp, se `_enemy_reaktion`).
func rasar() -> int:
	var n := celler.size()
	celler.clear()
	_mesh = null
	return n


func antal_celler() -> int:
	return celler.size()


func antal_ytor() -> int:
	var m := mesh()
	if m == null or m.get_surface_count() == 0:
		return 0
	return m.surface_get_array_index_len(0) / 3
