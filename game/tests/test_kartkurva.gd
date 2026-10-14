## Kartans svårighetskurva (M118, ratt A i docs/balans.md §8): rummets grad ska vara en KURVA över
## våningen — lätta rum nära starten, hårda längre in — och packen ska följa graden, för det är den
## delen av svårigheten spelaren SER (fler figurer i rummet). Provet mäter formen, inte smaken.
##
## Första försöket skalade graden mot fel ände av skalan och blev en klump i den lätta ändan
## (grad 1: 21 rum, grad 4: 0 rum per våning) — då var kurvan ingen kurva och packen 1-2 fiender
## i stället för 1-3. Det är den här kontrollen som fångar det.
extends SceneTree

const FÖRSTA_HALVAN := 0.5        ## var gränsen mellan "nära starten" och "längre in" går

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _initialize() -> void:
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var db := Cards.load_all()
	var grader := {}
	var packar := {}
	var packlista := []
	var nara := []
	var langt_in := []
	for stage_id in ["stage_01", "stage_02", "stage_03"]:
		var stage = stages[stage_id]
		for floor_index in stage.floors:
			var f := Dungeon.generate(stage, floor_index, 810000 + floor_index * 7919, bestiary)
			var run := Run.new(stage, bestiary, [], 810000, db)
			run.explore = Explore.new(f)
			var längst := 0
			for n in f.nodes:
				längst = maxi(längst, absi(n.pos.x - f.start.x) + absi(n.pos.y - f.start.y))
			for n in f.nodes:
				if n.kind != "encounter":
					continue
				var g := Dungeon.rum_svarighet(f, n.pos, 810000)
				grader[g] = int(grader.get(g, 0)) + 1
				var antal := run.enemy_count_for(n, false)
				packar[antal] = int(packar.get(antal, 0)) + 1
				packlista.append(antal)
				var d := float(absi(n.pos.x - f.start.x) + absi(n.pos.y - f.start.y))
				if d / float(maxi(1, längst)) < FÖRSTA_HALVAN:
					nara.append(g)
				else:
					langt_in.append(g)
	print("grad: %s | packe: %s | rum: %d" % [_rad(grader, 1, Dungeon.RUM_SPANN + 2),
		_rad(packar, 1, 3), nara.size() + langt_in.size()])
	print("grad nära starten: %.2f | längre in: %.2f" % [_medel(nara), _medel(langt_in)])

	check(nara.size() > 0 and langt_in.size() > 0, "våningen har rum både nära och långt från starten",
		"%d nära, %d längre in" % [nara.size(), langt_in.size()])
	check(_medel(langt_in) > _medel(nara) + 0.5, "graden STIGER med avståndet (en kurva, inte ett brus)",
		"nära %.2f mot längre in %.2f" % [_medel(nara), _medel(langt_in)])
	check(_medel(packlista) >= 1.8 and _medel(packlista) <= 2.6,
		"medelpacken ligger kvar kring 2 — rummet flyttar SPRIDNINGEN, inte pressen",
		"%.2f fiender per rum (den gamla slumppacken gav 2,0)" % _medel(packlista))
	check(int(grader.get(Dungeon.RUM_SPANN + 2, 0)) > 0, "det finns rum i den hårdaste graden",
		"%d rum i grad %d" % [int(grader.get(Dungeon.RUM_SPANN + 2, 0)), Dungeon.RUM_SPANN + 2])
	check(int(packar.get(3, 0)) > 0 and int(packar.get(1, 0)) > 0, "både små och fulla packet förekommer",
		"1 fiende: %d rum, 3 fiender: %d rum" % [int(packar.get(1, 0)), int(packar.get(3, 0))])
	print("kontroller: %d, fel: %d" % [checks, fails])
	quit(1 if fails else 0)

func _medel(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var sum := 0.0
	for x in v:
		sum += float(x)
	return sum / float(v.size())

func _rad(d: Dictionary, fran: int, till: int) -> String:
	var ut := []
	for k in range(fran, till + 1):
		ut.append("%d:%d" % [k, int(d.get(k, 0))])
	return ", ".join(ut)
