## Dungeongenerator. En våning = rutnät + noder (strider, kistor, facklor, boss, shovel).
##
## Metod: BSP-delning till rum, L-korridorer mellan rummen i ordning — kedjan är ryggraden och gör
## att varje rum går att nå, så ingen separat MST behövs. Utöver kedjan läggs några extra förbindelser
## (se `generate`), så våningen blir ett nät i stället för en gång.
##
## STORLEK OCH INNEHÅLL (Alex 2026-10-11): *"banorna genereras random så man aldrig kan lära sig
## banorna utantill, samt att de är minst 4x så stora som de är nu, det skall ta lite tid att ta sig
## genom."* Ytan är därför exakt 4x den gamla (17/21/25 -> 34/42/50) och rummen är fler. Strider,
## kistor och facklor per VÅNING är däremot oförändrade (mätta, se `_strids_tak`) — en fyrdubblad yta
## ska ge mer att GÅ, inte mer guld och xp: balanskurvan är mätt med tools/balance.gd och ska inte
## flyttas av en storleksändring.
##
## Allt styrs av (stage, våning, seed) och är deterministiskt: samma seed = samma våning.
class_name Dungeon
extends RefCounted

const WALL := 0
const FLOOR := 1

## Våningens yta i rutor — 4x den gamla vid varje svårighetsgrad.
static func _yta(difficulty: int) -> Vector2i:
	if difficulty >= 7:
		return Vector2i(50, 50)        # var 25x25
	if difficulty >= 5:
		return Vector2i(42, 42)        # var 21x21
	return Vector2i(34, 34)            # var 17x17


## Hur många strider en våning bär TOTALT (inte per rum). Talen 9/18/35 är MÄTTA med
## tools/vandring.gd på den gamla generatorn över 7830 våningar (svårighet 1-4 / 5-6 / 7+), och de är
## de tal som ska hållas: våningen blev fyra gånger större, men guld och xp per våning är mätt med
## tools/balance.gd och ska inte flyttas av en storleksändring. Den extra ytan ger mer att GÅ.
##
## Banans egen ratt `encounters_per_floor` ("strider per våning" i editorn) räknas mot 8: en bana som
## står på 8 får de uppmätta 9/18/35, en som står på 4 får hälften och en på 16 får dubbelt. 8:an är
## medianen av de 90 banornas värden (de ligger på 6-10; ingen står på defaulten 4).
##
## Förr räknades ratten PER RUM, och där tog rummet slut: ett rum på 3x3 har några få inre rutor, så
## en bana som bad om 10 strider per rum fick 3. Det verkliga antalet per våning bestämdes alltså av
## ytan, inte av ratten — mätt (stage_40, svårighet 10, ratten 8): 24-44 strider per våning, medan
## ratten gav 35-40. Nu är rummen stora nog att ratten slår igenom helt.
static func _strids_tak(stage) -> int:
	var mätt := 9.0
	if stage.difficulty >= 5:
		mätt = 18.0
	if stage.difficulty >= 7:
		mätt = 35.0
	return maxi(1, int(round(mätt * float(stage.encounters_per_floor) / 8.0)))


## Kistor och facklor per våning: tak, inte en per rum. Mätt före ändringen: 0-1 kista och 0-1 fackla
## per våning i snitt. Fler rum betyder inte fler kistor — guldet per våning ska stå still. Facklorna
## får bli några fler: de är landmärken i en fyra gånger större våning, och ljuset är redan mätt
## (60 fps med skuggor på, se `-- fpsprov`).
const KISTOR_PER_VÅNING := 1
## FACKLORNA (M117). Alex: *"Det behöver ut lite random facklor på väggarna ... det är väldigt mörkt"*
## och *"alla rum som är tomma på kartan måste fyllas ut lite"*. Antalet styrs av ANDELEN rum som får
## en fackla, med ett GOLV (en våning ska aldrig vara utan ljus, och test_fackla behöver en fackla att
## mäta på) och ett TAK (en fackla per rum är en eldfest, och varje fackla är ett skuggande ljus som
## kostar). Se `_facklor`: rummen och rutorna kommer ur våningens eget frö.
const FACKLOR_MIN := 3
const FACKLOR_ANDEL := 0.33
const FACKLOR_TAK := 12

class FloorNode extends RefCounted:
	var kind: String            ## encounter | chest | torch | boss | shovel | start
	var pos: Vector2i
	var enemy_id: String = ""
	var gold: int = 0
	var xp: int = 0
	var cleared := false          ## avklarad (strid vunnen, eller shovel använd)

class Floor extends RefCounted:
	var stage_id: String
	var index: int
	var theme: String = ""         ## tileset-tema för våningen. Tomt = banans tema, sen platt fallback
	var w: int
	var h: int
	var tiles: Array = []          ## Array[Array[int]]
	var nodes: Array = []
	## Rummens rektanglar (BSP-bladen), i den ordning de byggdes. Används av påfyllningen av tomma rum
	## (`_bygg_dekor` i main.gd) och av proven. En HANDritad våning har inga rum här — den är ritad som
	## Alex ritade den, och då finns inget "tomt rum" att fylla.
	var rum: Array = []
	## Material per ruta ("x,y" -> material-id, se assets/tiles/material/): en ruta med eget material
	## ritas med det i stället för temats ruta. Tomt = temat gäller, precis som förut. Id:t är en
	## sökväg utan ändelse under assets/tiles/, så motorn hittar bilden utan en egen tabell.
	var ytor: Dictionary = {}
	var start := Vector2i.ZERO
	var boss_pos := Vector2i.ZERO
	var shovel_pos := Vector2i.ZERO

	func is_floor_at(p: Vector2i) -> bool:
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			return false
		return tiles[p.y][p.x] == FLOOR

	## Enkel meningsfull kontrollsumma för determinism-testet.
	func checksum() -> int:
		var sum := 0
		for y in h:
			for x in w:
				if tiles[y][x] == FLOOR:
					sum += 1 + x * 31 + y * 7
		for n in nodes:
			sum += 1000003 + hash("%s:%d:%d" % [n.kind, n.pos.x, n.pos.y])
		return sum

	func nodes_of_kind(kind: String) -> Array:
		var out := []
		for n in nodes:
			if n.kind == kind:
				out.append(n)
		return out

## Genererar en våning. `stage` är en Stages.StageDef, `bestiary` en ordbok id -> EnemyDef.
## Har Alex ritat våningen för hand (data/maps/<stage>_<våning>.json) gäller den — generatorn är
## reserven, inte herren. Filen går genom samma kontroller som generatorn (MapIo.validate), så en
## våning som inte går att spela kan inte hamna här.
static func generate(stage, floor_index: int, seed_value: int, bestiary: Dictionary) -> Floor:
	var ritad := MapIo.load_map(stage.id, floor_index, stage, bestiary)
	if ritad != null:
		return ritad
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var f := Floor.new()
	f.stage_id = stage.id
	f.index = floor_index
	var mått := _yta(stage.difficulty)
	f.w = mått.x
	f.h = mått.y
	f.tiles = _blank(f.w, f.h)

	# Rummen. BSP-delningen går djupare än förr (6 i stället för 4), så den större ytan får FLER rum i
	# stället för bara större: det är rummen man går mellan, och det är de som gör våningen lång.
	var rooms := _split(rng, Rect2i(1, 1, f.w - 2, f.h - 2), 4, 6)
	f.rum = rooms                      # rummen följer med våningen: påfyllningen och proven läser dem
	for r in rooms:
		_carve_room(f, r)
	for i in rooms.size() - 1:
		_carve_corridor(f, _center(rooms[i]), _center(rooms[i + 1]))
	# Kedjan är ryggraden och garanterar att varje rum går att nå. Men en ren kedja har samma FORM varje
	# gång: man lär sig "följ gången till slutet" utan att titta på kartan, och det är precis det Alex
	# ville bort. Några extra förbindelser mellan rum som inte ligger intill varandra gör våningen till
	# ett nät — det finns genvägar att hitta och rum man inte måste passera. Få, inte många: varje extra
	# förbindelse gör våningen lättare att lära sig, och en genväg rakt till bossen kortar den väg vi
	# just gjorde lång.
	for i in mini(rooms.size() / 4, 5):
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := rng.randi_range(0, rooms.size() - 1)
		if absi(a - b) > 1:
			_carve_corridor(f, _center(rooms[a]), _center(rooms[b]))

	# BOSSEN LIGGER INTE ALLTID SIST. Rummen kommer i BSP-ordning, inte i avståndsordning, så det
	# SISTA rummet är en fast punkt på varje våning — och mätt blev vägen från start till boss exakt
	# 51 steg på våning efter våning vid svårighet 2-4 (standardavvikelse 2): samma promenad varje gång,
	# trots att kartan ritas om. "Man kan inte lära sig banorna utantill" gäller alltså kartan men inte
	# rytmen. Bossen väljs därför slumpmässigt bland de rum som ligger längst bort från start (den
	# bortersta fjärdedelen), så LÄNGDEN på promenaden varierar med våningen.
	# ponytail: urvalet mäter rakt avstånd mellan rumscentrum, inte verklig gångväg efter att
	# extraförbindelserna slagits — en genväg kan korta vägen efteråt. Räcker för spridningen.
	var start_centrum := _center(rooms[0])
	var ordning := range(1, rooms.size())
	ordning.sort_custom(func(a, b):
		return _avstånd(_center(rooms[a]), start_centrum) > _avstånd(_center(rooms[b]), start_centrum))
	var topp: int = maxi(1, int(ceil(ordning.size() * 0.25)))
	var boss_rum: int = ordning[rng.randi_range(0, topp - 1)]

	f.start = start_centrum
	f.boss_pos = _center(rooms[boss_rum])
	f.shovel_pos = f.boss_pos        # shoveln får man av bossen på våningen

	var start_node := FloorNode.new()
	start_node.kind = "start"
	start_node.pos = f.start
	f.nodes.append(start_node)

	var boss_node := FloorNode.new()
	boss_node.kind = "boss"
	boss_node.pos = f.boss_pos
	boss_node.enemy_id = Stages.boss_for(stage, floor_index)
	f.nodes.append(boss_node)

	var shovel_node := FloorNode.new()
	shovel_node.kind = "shovel"
	shovel_node.pos = f.shovel_pos
	f.nodes.append(shovel_node)

	# Innehåll i rummen mellan start och boss.
	var pool := Enemies.by_tier(bestiary, stage.tiers)
	if pool.is_empty():
		# Ingen fiende att lägga ut: våningen går inte att bygga, och den ska inte byggas halvfärdig.
		# Förr skrevs felet och koden fortsatte rakt in i rng.randi_range(0, -1) på den tomma listan
		# -> "Out of bounds get index '-1'" -> generate returnerade null -> test_dungeon dog mitt i
		# _initialize, och ett scriptfel där avslutar INTE trädet. Provet hängde i 120 sekunder och
		# sviten kallade det en timeout, utan ett ord om stage_46 och dess tier 4.
		push_error("stage %s saknar fiender i sina tiers %s" % [stage.id, stage.tiers])
		return null
	# Striderna: budgeten är VÅNINGENS (se _strids_tak), och den delas ut ett slag per rum i taget —
	# runda för runda — så striderna hamnar utspridda över våningen i stället för att klumpa ihop sig i
	# de första rummen. Rummen är fler än striderna, så många rum blir tomma; det är där kistan,
	# facklan och rekvisiten bor.
	var platser := []
	for i in range(1, rooms.size() - 1):
		# Start- och bossrutan hoppas över: bossen står nu i ett rum som kan få egna strider, och två
		# noder på samma ruta är en nod som skymmer den andra (kartan ritar dem ovanpå varandra).
		var rum: Array = []
		for p in _spots(rng, rooms[i]):
			if p != f.boss_pos and p != f.start:
				rum.append(p)
		platser.append(rum)
	var per_rum: Array[int] = []
	per_rum.resize(platser.size())
	per_rum.fill(0)
	var kvar := _strids_tak(stage)
	var runda := 0
	while kvar > 0 and not platser.is_empty() and runda < 4096:
		var r := runda % platser.size()
		if per_rum[r] < platser[r].size():
			per_rum[r] += 1
			kvar -= 1
		runda += 1
	var kistor := 0
	for i in platser.size():
		var rum: Array = platser[i]
		for j in per_rum[i]:
			var n := FloorNode.new()
			n.kind = "encounter"
			var e = pool[rng.randi_range(0, pool.size() - 1)]
			n.enemy_id = e.id
			n.xp = e.xp
			n.gold = e.gold
			n.pos = rum[j]
			f.nodes.append(n)
		if kistor < KISTOR_PER_VÅNING and rum.size() > per_rum[i]:
			var c := FloorNode.new()
			c.kind = "chest"
			c.pos = rum[per_rum[i]]
			c.gold = 10 + stage.difficulty * 5
			f.nodes.append(c)
			kistor += 1
	_facklor(f, rng, rooms)
	return f


## FACKLORNA PÅ VÄGGARNA. Alex: *"Det behöver ut lite random facklor på väggarna ... det är väldigt
## mörkt."* En fackla i ungefär en tredjedel av rummen — men MINST FACKLOR_MIN, så en våning aldrig blir
## mörk (och tests/test_fackla.gd har en fackla att mäta på), och HÖGST FACKLOR_TAK: en våning ska
## kännas upplyst, inte som en eldfest.
##
## Rutan måste ha en VÄGG intill. `_add_lagor` i main.gd sätter lågan mot väggen, och en fackla utan
## vägg blir en ställning på golvet i stället för en fackla på väggen — den gamla placeringen tog sina
## rutor ur `_spots`, som bara ger rummets INRUTOR, så varenda genererad fackla stod fritt på golvet.
##
## Vilka rum och vilka rutor som får en fackla kommer ur våningens EGET rng, så samma frö ger samma
## facklor varje körning. Lagd EFTER striderna och kistan: de drar sitt ur samma ström först, och då är
## fiendernas och kistans rutor oförändrade när facklorna blir fler.
static func _facklor(f: Floor, rng: RandomNumberGenerator, rooms: Array) -> void:
	if rooms.size() < 3:
		return
	var upptagna := {}
	for n in f.nodes:
		upptagna[n.pos] = true
	# Rummen mellan startrummet och det sista: samma rum som striderna delas ut i.
	var kandidater := []
	for i in range(1, rooms.size() - 1):
		var rutor := _väggrutor(f, rooms[i], upptagna)
		if not rutor.is_empty():
			kandidater.append(rutor)
	if kandidater.is_empty():
		return
	var nyckel := {}
	for j in kandidater.size():
		nyckel[j] = rng.randf()
	var ordning := range(kandidater.size())
	ordning.sort_custom(func(a, b): return nyckel[a] < nyckel[b])
	var antal: int = mini(maxi(int(round(float(kandidater.size()) * FACKLOR_ANDEL)), FACKLOR_MIN),
		mini(FACKLOR_TAK, kandidater.size()))
	for j in antal:
		var rutor: Array = kandidater[ordning[j]]
		var p: Vector2i = rutor[rng.randi_range(0, rutor.size() - 1)]
		var t := FloorNode.new()
		t.kind = "torch"
		t.pos = p
		f.nodes.append(t)
		upptagna[p] = true


## Rutor i ett rum som har en VÄGG intill och är lediga, i läsordning. Sidorna läses i samma ordning
## som `_vägg_sida` i main.gd, så lågan hamnar mot den vägg rutan faktiskt gränsar till.
static func _väggrutor(f: Floor, room: Rect2i, upptagna: Dictionary) -> Array:
	var ut := []
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			var p := Vector2i(x, y)
			if not f.is_floor_at(p) or upptagna.has(p):
				continue
			if _vägg_intill(f, p):
				ut.append(p)
	return ut


## Har rutan en vägg bland sina fyra grannar?
static func _vägg_intill(f: Floor, p: Vector2i) -> bool:
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if not f.is_floor_at(p + d):
			return true
	return false

# --- rutnät -----------------------------------------------------------------
static func _blank(w: int, h: int) -> Array:
	var rows := []
	for y in h:
		var row: Array[int] = []
		for x in w:
			row.append(WALL)
		rows.append(row)
	return rows

static func _center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)

## Rakt avstånd (Manhattan) mellan två rutor: gångvägen är längre, men till att VÄLJA ut de bortersta
## rummen räcker det — och det kostar inget att räkna.
static func _avstånd(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _carve_room(f: Floor, r: Rect2i) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if x > 0 and y > 0 and x < f.w - 1 and y < f.h - 1:
				f.tiles[y][x] = FLOOR

static func _carve_corridor(f: Floor, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		x += 1 if b.x > x else -1
		if x > 0 and x < f.w - 1:
			f.tiles[y][x] = FLOOR
	while y != b.y:
		y += 1 if b.y > y else -1
		if y > 0 and y < f.h - 1:
			f.tiles[y][x] = FLOOR

## BSP: dela rektangeln tills bitarna är för små, gör rum av bladen.
static func _split(rng: RandomNumberGenerator, rect: Rect2i, min_size: int, depth: int) -> Array:
	var rooms := []
	if depth <= 0 or (rect.size.x < min_size * 2 + 2 and rect.size.y < min_size * 2 + 2):
		rooms.append(_room_in(rng, rect))
		return rooms
	var split_horizontal := rect.size.y > rect.size.x
	if rect.size.x > rect.size.y * 1.25:
		split_horizontal = false
	elif rect.size.y > rect.size.x * 1.25:
		split_horizontal = true
	if split_horizontal:
		var cut := rng.randi_range(min_size + 1, max(min_size + 1, rect.size.y - min_size - 1))
		rooms += _split(rng, Rect2i(rect.position, Vector2i(rect.size.x, cut)), min_size, depth - 1)
		rooms += _split(rng, Rect2i(rect.position + Vector2i(0, cut), Vector2i(rect.size.x, rect.size.y - cut)), min_size, depth - 1)
	else:
		var cut := rng.randi_range(min_size + 1, max(min_size + 1, rect.size.x - min_size - 1))
		rooms += _split(rng, Rect2i(rect.position, Vector2i(cut, rect.size.y)), min_size, depth - 1)
		rooms += _split(rng, Rect2i(rect.position + Vector2i(cut, 0), Vector2i(rect.size.x - cut, rect.size.y)), min_size, depth - 1)
	return rooms

static func _room_in(rng: RandomNumberGenerator, rect: Rect2i) -> Rect2i:
	var w: int = max(3, rect.size.x - rng.randi_range(2, 4))
	var h: int = max(3, rect.size.y - rng.randi_range(2, 4))
	var x: int = rect.position.x + max(0, (rect.size.x - w) / 2)
	var y: int = rect.position.y + max(0, (rect.size.y - h) / 2)
	return Rect2i(x, y, w, h)

## Golvytor i ett rum, i slumpad ordning men deterministiskt, utan att ligga i väggkanten.
static func _spots(rng: RandomNumberGenerator, room: Rect2i) -> Array:
	var all := []
	for y in range(room.position.y + 1, room.position.y + room.size.y - 1):
		for x in range(room.position.x + 1, room.position.x + room.size.x - 1):
			all.append(Vector2i(x, y))
	# deterministisk blandning: sortera på ett slumptal per ruta
	var keys := {}
	for p in all:
		keys[p] = rng.randf()
	all.sort_custom(func(a, b): return keys[a] < keys[b])
	return all

# --- kontroller -------------------------------------------------------------
## Alla golvrutor som går att nå från startpunkten (flood fill).
static func reachable(f: Floor) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	if not f.is_floor_at(f.start):
		return seen
	seen[f.start] = true
	queue.append(f.start)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if f.is_floor_at(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen

## Noder som inte går att nå — tom lista betyder att våningen går att spela.
static func unreachable_nodes(f: Floor) -> Array:
	var seen := reachable(f)
	var bad := []
	for n in f.nodes:
		if not seen.has(n.pos):
			bad.append(n)
	return bad
