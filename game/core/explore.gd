## Utforskarläget: position, riktning, steg, svängar — och en väg till en ruta.
##
## Referensen rör sig ett steg i taget i 90°-svängar ("blobber"): rörelsen är en
## ruta-per-tangentryckning, inte fri. Därför är allt här diskret och deterministiskt.
## Allt som händer läggs som events i `log` — samma ström som UI, ljud och skärmläsare ska läsa.
class_name Explore
extends RefCounted

enum { NORTH, EAST, SOUTH, WEST }

const STEP := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var floor_ref: Dungeon.Floor
var pos: Vector2i
var facing: int = NORTH
var steps_taken := 0
var turns_taken := 0

func _init(p_floor: Dungeon.Floor) -> void:
	floor_ref = p_floor
	pos = p_floor.start

func turn_left() -> void:
	facing = (facing + 3) % 4
	turns_taken += 1

func turn_right() -> void:
	facing = (facing + 1) % 4
	turns_taken += 1

## Kamerans vinkel för en riktning. Den enda platsen där `facing` blir en vinkel: förut räknades
## den på tre ställen i main.gd, och när kameran började glida mellan stegen märktes det.
static func yaw_for(facing: int) -> float:
	return -float(facing) * PI / 2.0


## Närmaste ekvivalenta vinkel. Utan den snurrar kameran 270 grader ÅT FEL HÅLL när svängen går
## över 180-gradersgränsen: från väster (facing 3, yaw -4,71) till norr (facing 0, yaw 0) tog tweenen
## vägen +4,71 i stället för -1,57. wrapf lägger målet inom ett halvt varv från nuläget.
static func närmaste_vinkel(nu: float, mål: float) -> float:
	return nu + wrapf(mål - nu, -PI, PI)


## Ett steg framåt. Returnerar "" vid lyckat steg, annars orsaken ("vaggen").
func forward() -> String:
	var target: Vector2i = pos + STEP[facing]
	if not floor_ref.is_floor_at(target):
		return "vaggen"
	pos = target
	steps_taken += 1
	return ""

## Ett steg BAKLÄNGES (S). Samma ruta som `forward()` prövar, men åt andra hållet: blicken är kvar i
## samma riktning, så man backar i stället för att vända sig — det är skillnaden mot att trycka
## vänster-vänster-höger.
func backward() -> String:
	var target: Vector2i = pos - STEP[facing]
	if not floor_ref.is_floor_at(target):
		return "vaggen"
	pos = target
	steps_taken += 1
	return ""

## Rutan vi tittar på just nu (framför spelaren).
func ahead() -> Vector2i:
	return pos + STEP[facing]

## Noden spelaren står på: den första OAVKLARADE noden på rutan, annars den första.
## En ruta kan bära flera noder med flit — shoveln ligger på bossens ruta och får man först när
## bossen är besegrad. Att alltid returnera den första noden på rutan gjorde att shoveln aldrig
## kunde plockas upp: körningen låste sig på våningen för alltid (mätt i demoläget: 900 varv,
## "står på målet shovel; node_here ger boss (cleared ja)").
func node_here() -> Dungeon.FloorNode:
	var first: Dungeon.FloorNode = null
	for n in floor_ref.nodes:
		if n.pos != pos:
			continue
		if not n.cleared:
			return n
		if first == null:
			first = n
	return first

## Rutan spelaren har framför sig (den man tittar på). Används för att möta det man ser i stället
## för att snubbla in i det.
func pos_ahead() -> Vector2i:
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	return pos + dirs[facing % 4]

## Noden på rutan framför, om den är oavklarad. Den här delen gör att en fiende står en meter bort
## och tittar på dig när striden börjar, i stället för att striden startar med att du står på den.
func node_ahead() -> Dungeon.FloorNode:
	var p := pos_ahead()
	for n in floor_ref.nodes:
		if n.pos == p and not n.cleared:
			return n
	return null

## Vägen (lista av rutor, startrutan först) till en målruta. BFS över golvet.
func path_to(target: Vector2i) -> Array:
	if not floor_ref.is_floor_at(target):
		return []
	var came := {pos: pos}
	var queue: Array[Vector2i] = [pos]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p == target:
			break
		for d in STEP:
			var n: Vector2i = p + d
			if floor_ref.is_floor_at(n) and not came.has(n):
				came[n] = p
				queue.append(n)
	if not came.has(target):
		return []
	var path := []
	var walk := target
	while walk != pos:
		path.push_front(walk)
		walk = came[walk]
	path.push_front(pos)
	return path

## Vrid mot och ta ETT steg mot målet. Returnerar "" om vi kom närmare, annars orsaken.
## Detta är hela "gå till saken"-mekaniken: en ruta i taget, sväng först.
func step_toward(target: Vector2i) -> String:
	var path := path_to(target)
	if path.size() < 2:
		return "ingen_vag"
	var next: Vector2i = path[1]
	var want := _facing_to(next - pos)
	while facing != want:
		turn_right()
	var err := forward()
	return err

## Vilken riktning ett steg motsvarar.
static func _facing_to(delta: Vector2i) -> int:
	for i in STEP.size():
		if STEP[i] == delta:
			return i
	return NORTH

## Vänd blicken mot en ruta — riktningen, inte ett steg. Diagonala mål (något nodprovet kan stå i)
## avgörs av den dominerande axeln, och lika långt åt båda hållen går norr/söder först: det är samma
## regel som nodprovet hade innan den flyttade hit, så en kamera som riktas härifrån står som förut.
func face(target: Vector2i) -> void:
	var d := target - pos
	if d == Vector2i.ZERO:
		return
	facing = _facing_to(Vector2i(0, signi(d.y))) if absi(d.y) >= absi(d.x) \
		else _facing_to(Vector2i(signi(d.x), 0))
