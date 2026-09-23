## Dungeongenerator. En våning = rutnät + noder (strider, kistor, facklor, boss, shovel).
##
## Metod: BSP-delning till rum, sedan L-korridorer mellan rummen i ordning. Att koppla rummen
## i sekvens ÄR ett spännande träd — ingen separat MST behövs.
## ponytail: linjär rumskedja ger förutsägbar topologi (alla våningar är "gång på gång").
## Bygg ut med extra kanter/slingor när spelkänslan kräver det, inte förr.
##
## Allt styrs av (stage, våning, seed) och är deterministiskt: samma seed = samma våning.
class_name Dungeon
extends RefCounted

const WALL := 0
const FLOOR := 1

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
	f.w = 17
	f.h = 17
	if stage.difficulty >= 5:
		f.w = 21
		f.h = 21
	if stage.difficulty >= 7:
		f.w = 25
		f.h = 25
	f.tiles = _blank(f.w, f.h)

	var rooms := _split(rng, Rect2i(1, 1, f.w - 2, f.h - 2), 4, 4)
	for r in rooms:
		_carve_room(f, r)
	for i in rooms.size() - 1:
		_carve_corridor(f, _center(rooms[i]), _center(rooms[i + 1]))

	f.start = _center(rooms[0])
	f.boss_pos = _center(rooms[rooms.size() - 1])
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
		push_error("stage %s saknar fiender i sina tiers %s" % [stage.id, stage.tiers])
	for i in range(1, rooms.size() - 1):
		var room: Rect2i = rooms[i]
		var spots := _spots(rng, room)
		for j in min(stage.encounters_per_floor, spots.size()):
			var n := FloorNode.new()
			n.kind = "encounter"
			var e = pool[rng.randi_range(0, pool.size() - 1)]
			n.enemy_id = e.id
			n.xp = e.xp
			n.gold = e.gold
			n.pos = spots[j]
			f.nodes.append(n)
		if spots.size() > stage.encounters_per_floor:
			var c := FloorNode.new()
			c.kind = "chest"
			c.pos = spots[stage.encounters_per_floor]
			c.gold = 10 + stage.difficulty * 5
			f.nodes.append(c)
		if spots.size() > stage.encounters_per_floor + 1:
			var t := FloorNode.new()
			t.kind = "torch"
			t.pos = spots[stage.encounters_per_floor + 1]
			f.nodes.append(t)
	return f

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
