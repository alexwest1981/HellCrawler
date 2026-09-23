## Rutans regler, delade av ban-editorn och spelets byggläge (F1): en nod per ruta och sort, en vägg
## bär ingenting, pekarna (start/boss/nedstigning) nollställs när rutan töms, och samma ruta ger samma
## fiende varje gång.
##
## Provet finns därför att två kopior av den här regeln gled isär: byggläget skrevs med egen kod, och
## en kista som gav olika guld beroende på var man byggde den är en bugg ingen letar efter.
##   godot --headless --script res://tests/test_bygg.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## Rutan med en nod av en sort, oavsett var i listan den hamnar. `MapIo.blank` lägger dit en start och
## en nedstigning själv, så ett index duger inte som svar på "finns kistan?".
func _hitta(f: Dungeon.Floor, kind: String, p: Vector2i):
	for n in f.nodes:
		if n.kind == kind and n.pos == p:
			return n
	return null

## En tom, helt golvlagd våning: annars ärver provet noderna som `blank` lade dit och mäter dem.
func _tom(namn: String, sida: int = 9) -> Dungeon.Floor:
	var f := MapIo.blank(namn, 0)
	f.nodes.clear()
	f.start = Vector2i(-1, -1)
	f.shovel_pos = Vector2i(-1, -1)
	f.boss_pos = Vector2i(-1, -1)
	for y in f.h:
		for x in f.w:
			f.tiles[y][x] = Dungeon.FLOOR
	return f

func _init() -> void:
	print("")
	print("— rutan: en nod per ruta och sort —")
	var bestiary := Enemies.load_all()
	var stages := Stages.load_all()
	var stage: Stages.StageDef = stages["stage_01"]
	var f := _tom("provbana")
	var p := Vector2i(4, 4)

	check(MapIo.placera(f, "chest", p, stage, bestiary) == "", "kistan ställs ut")
	check(_hitta(f, "chest", p) != null, "kistan finns på rutan")
	var kista = _hitta(f, "chest", p)
	check(MapIo.placera(f, "chest", p, stage, bestiary) != "", "en kista på en kista nekas")
	check(f.nodes.size() == 1, "fortfarande en nod", str(f.nodes.size()))
	check(kista != null and kista.gold > 0, "kistan har guld ur banans svårighet",
		str(kista.gold) if kista != null else "saknas")
	check(MapIo.placera(f, "kista", p, stage, bestiary) != "", "okänd nodtyp nekas")
	# En nod per ruta: en fackla på kistans ruta tar bort kistan, den staplas inte.
	check(MapIo.placera(f, "torch", p, stage, bestiary) == "", "facklan ställs ut")
	check(_hitta(f, "chest", p) == null and _hitta(f, "torch", p) != null,
		"en nod per ruta — kistan vek för facklan")

	# Två våningar med samma namn, våning och ruta ska ge SAMMA fiende.
	var a := _tom("provbana")
	var b := _tom("provbana")
	MapIo.placera(a, "encounter", p, stage, bestiary)
	MapIo.placera(b, "encounter", p, stage, bestiary)
	var fa = _hitta(a, "encounter", p)
	var fb = _hitta(b, "encounter", p)
	check(fa != null and fb != null and fa.enemy_id == fb.enemy_id and not fa.enemy_id.is_empty(),
		"samma ruta ger samma fiende varje gång", fa.enemy_id if fa != null else "saknas")

	# En uttryckligen vald fiende går före slumptalet (ban-editorns rad "ny strid").
	var c := _tom("provbana")
	var vald: String = (Enemies.by_tier(bestiary, stage.tiers)[0] as Enemies.EnemyDef).id
	check(MapIo.placera(c, "encounter", p, stage, bestiary, vald) == "", "strid med vald fiende")
	check(_hitta(c, "encounter", p).enemy_id == vald, "den valda fienden står där", vald)

	# Pekarna: starten är ett eget fält, inte bara en nod i listan.
	check(MapIo.placera(f, "start", Vector2i(1, 1), stage, bestiary) == "", "starten ställs ut")
	check(f.start == Vector2i(1, 1), "start-pekaren flyttar med", str(f.start))
	check(MapIo.ta_bort(f, Vector2i(1, 1)) == 1, "starten tas bort")
	check(f.start == Vector2i(-1, -1), "start-pekaren nollställs när rutan töms", str(f.start))

	# En vägg bär ingenting: gör rutan till vägg och pröva samma placering.
	var vägg := _tom("provbana")
	vägg.tiles[2][2] = Dungeon.WALL
	check(MapIo.placera(vägg, "chest", Vector2i(2, 2), stage, bestiary) != "", "noden nekas i en vägg")
	check(vägg.nodes.is_empty(), "inget hamnade i listan", str(vägg.nodes.size()))

	# Material per ruta: det följer med kartfilen både ut och in, och en ruta utan överstyrning ritas
	# som förut (tom sträng = temats ruta).
	var med := _tom("provbana")
	med.tiles[3][3] = Dungeon.WALL
	med.ytor["3,3"] = "material/magma_rock"
	med.ytor["4,4"] = "material/hammered_alloy"
	var d: Dictionary = MapIo.to_dict(med)
	check(str(d.get("ytor", {}).get("3,3", "")) == "material/magma_rock",
		"materialet skrivs till kartfilen", str(d.get("ytor", {}).get("3,3", "")))
	var tillbaka := MapIo.from_dict(d, "provbana", 0)
	check(tillbaka != null and tillbaka.ytor.get("4,4", "") == "material/hammered_alloy",
		"materialet läses tillbaka", str(tillbaka.ytor.get("4,4", "")) if tillbaka != null else "kartan föll")
	check(str(tillbaka.ytor.get("9,9", "")) == "",
		"en ruta utan material är tom (temat gäller)", "tom")

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
