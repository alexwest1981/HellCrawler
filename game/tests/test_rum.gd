## Prov för RUMMEN: facklorna på väggarna och att inget rum är tomt på innehåll (M117).
##
## Alex: *"Det behöver ut lite random facklor på väggarna, man måste få lite bättre 'ficklampa' med, så
## man ser något, det är väldigt mörkt. Å alla rum som är tomma på kartan måste fyllas ut lite."*
##
## Provet mäter REGLERNA, inte en bild — av samma skäl som test_dekor: MultiMesh-instansernas
## transformar går inte att läsa i huvudlöst läge (dummyns lagring är tom), så påfyllnaden mäts som
## rutan regeln ger, inte som en instans i världen. Det som DÄREMOT mäts på riktigt är noderna: en
## fackla är en `Dungeon.FloorNode` med en position, och den positionen avgör om facklan hamnar på
## väggen (`Dungeon._vägg_intill`, samma regel som `_add_lagor` i main.gd läser) eller blir en ställning
## på golvet.
##
##   godot --headless --path game --script res://tests/test_rum.gd
extends SceneTree

var fel := 0
var kontroller := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	kontroller += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fel += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


const FRÖ := 20260919
const SEEDS := [1, 7, 42, 1337, 90210]
const IDS := ["stage_01", "stage_10", "stage_40", "stage_90"]

func _initialize() -> void:
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var M := load("res://main.gd")
	if stages.is_empty() or bestiary.is_empty():
		print("%d kontroller, %d fel — avbryter (inget innehåll)" % [kontroller, fel])
		quit(1)
		return

	print("— facklorna står på väggarna, i lagom många rum —")
	var våningar := 0
	var facklor_totalt := 0
	var rum_totalt := 0
	var tomma_totalt := 0
	var inte_på_vägg: Array = []
	var utanför_rum: Array = []
	var dubbel_ruta: Array = []
	var fler_i_rum: Array = []
	var klump: Array = []
	var fyllnad_fel: Array = []
	var rekvisit_fel: Array = []
	var skilda: Array = []
	var exempel: Array = []
	for id in IDS:
		var s: Stages.StageDef = stages[id]
		if s == null:
			continue
		for v in int(s.floors):
			if MapIo.has_map(s.id, v):
				continue          # Alex' handritade våning: den är som han ritade den
			var frö := FRÖ + v * 7919
			var f := Dungeon.generate(s, v, frö, bestiary)
			if f == null:
				continue
			våningar += 1
			rum_totalt += f.rum.size()
			# Facklorna: antal, ruta och rum.
			var per_rum := {}
			var per_ruta := {}
			for n in f.nodes:
				if not per_ruta.has(n.pos):
					per_ruta[n.pos] = []
				(per_ruta[n.pos] as Array).append(n.kind)
			for np in per_ruta:
				var slag: Array = per_ruta[np]
				# BOSSEN OCH SPADEN delar ruta med flit (spaden delas ut av bossen, se `Dungeon.generate`).
				if slag.size() > 1 and not (slag.size() == 2 and slag.has("boss") and slag.has("shovel")):
					dubbel_ruta.append("%s v%d %s: %s" % [id, v + 1, str(np), ", ".join(slag)])
			var n_facklor := 0
			for n in f.nodes:
				if n.kind != "torch":
					continue
				n_facklor += 1
				var i: int = M._rum_index(f, n.pos)
				if i < 0:
					utanför_rum.append("%s v%d %s" % [id, v + 1, str(n.pos)])
				else:
					per_rum[i] = int(per_rum.get(i, 0)) + 1
				if not Dungeon._vägg_intill(f, n.pos):
					inte_på_vägg.append("%s v%d %s" % [id, v + 1, str(n.pos)])
			facklor_totalt += n_facklor
			if n_facklor < Dungeon.FACKLOR_MIN or n_facklor > Dungeon.FACKLOR_TAK:
				skilda.append("%s v%d: %d facklor (mål %d-%d)"
					% [id, v + 1, n_facklor, Dungeon.FACKLOR_MIN, Dungeon.FACKLOR_TAK])
			for i in per_rum:
				if int(per_rum[i]) > 1:
					fler_i_rum.append("%s v%d rum %d: %d facklor" % [id, v + 1, i, int(per_rum[i])])
			# DEN GAMLA KLUMPEN: facklorna lades i rummen i ordning, alltså i de första tre. Nu kommer
			# urvalet ur våningens eget rng; på en våning med många rum ska de inte alla ligga i toppen.
			if f.rum.size() >= 12 and not per_rum.is_empty():
				var sent := false
				for i in per_rum:
					if int(i) >= 3:
						sent = true
				if not sent:
					klump.append("%s v%d: alla %d facklor i de tre första rummen" % [id, v + 1, n_facklor])
			if per_rum.size() < mini(3, f.rum.size()):
				klump.append("%s v%d: bara %d rum har en fackla" % [id, v + 1, per_rum.size()])
			# TOMRUMMEN: en nod, en rekvisit eller en kandelaber. Provet läser spelets EGNA regel för
			# rekvisiter (`M._rekvisiter_per_rum`) — en egen kopia här vore en kopia som kan driva isär.
			var props: Dictionary = M._rekvisiter_per_rum(f, 4)
			for i in f.rum.size():
				var r: Rect2i = f.rum[i]
				var nod := false
				for n in f.nodes:
					if r.has_point(n.pos) and n.kind in ["encounter", "chest", "torch"]:
						nod = true
						break
				var rekvisita := int(props.get(i, 0)) > 0
				if nod or rekvisita:
					continue
				var p: Vector2i = M._rum_fyllnad(f, r)
				if p.x < 0:
					tomma_totalt += 1
					fyllnad_fel.append("%s v%d rum %d: ingen ruta att fylla" % [id, v + 1, i])
					continue
				if not f.is_floor_at(p) or not r.has_point(p):
					rekvisit_fel.append("%s v%d rum %d: %s är inte i rummet" % [id, v + 1, i, str(p)])
				for n in f.nodes:
					if n.pos == p:
						rekvisit_fel.append("%s v%d rum %d: %s har en nod" % [id, v + 1, i, str(p)])
			if exempel.size() < 3:
				exempel.append("%s v%d: %d rum, %d facklor" % [id, v + 1, f.rum.size(), n_facklor])
	check(skilda.is_empty(), "varje genererad våning har %d-%d facklor"
		% [Dungeon.FACKLOR_MIN, Dungeon.FACKLOR_TAK],
		"%d våningar, %.1f facklor per våning" % [våningar, float(facklor_totalt) / maxf(1.0, float(våningar))])
	check(inte_på_vägg.is_empty(), "varje fackla sitter på en ruta MED VÄGG intill", "; ".join(inte_på_vägg))
	check(utanför_rum.is_empty(), "och inne i ett rum, inte i en gång", "; ".join(utanför_rum))
	check(dubbel_ruta.is_empty(), "ingen ruta har två noder", "; ".join(dubbel_ruta))
	check(fler_i_rum.is_empty(), "högst en fackla per rum", "; ".join(fler_i_rum))
	check(klump.is_empty(), "facklorna ligger utspridda över våningen, inte i de första rummen",
		"; ".join(klump))
	check(rum_totalt > 0 and facklor_totalt > 0, "svepet mätte något", ", ".join(exempel))

	print("")
	print("— tomma rum fylls —")
	check(fyllnad_fel.is_empty(), "varje rum utan nod och utan rekvisit har en ruta att fylla",
		"; ".join(fyllnad_fel))
	check(rekvisit_fel.is_empty(), "fyllnadsrutan är en ledig golvruta i rummet", "; ".join(rekvisit_fel))
	check(tomma_totalt == 0, "inga rum står tomma efter påfyllningen", "%d st" % tomma_totalt)

	print("")
	print("— samma frö ger samma facklor (determinism) —")
	var s1: Stages.StageDef = stages["stage_01"]
	var fri := 0
	while fri < int(s1.floors) and MapIo.has_map(s1.id, fri):
		fri += 1
	var olika := 0
	var par_olika := 0
	for seed in SEEDS:
		var a := Dungeon.generate(s1, fri, seed, bestiary)
		var b := Dungeon.generate(s1, fri, seed, bestiary)
		var c := Dungeon.generate(s1, fri, seed + 1, bestiary)
		check(a.checksum() == b.checksum() and _fackelrutor(a) == _fackelrutor(b),
			"frö %d: samma våning och samma fackelrutor två gånger" % seed,
			"%d facklor" % a.nodes_of_kind("torch").size())
		if _fackelrutor(a) != _fackelrutor(c):
			olika += 1
		if a.nodes_of_kind("torch").size() != c.nodes_of_kind("torch").size():
			par_olika += 1
	check(olika > 0 or par_olika > 0, "ett annat frö ger en annan uppsättning facklor",
		"%d av %d frön skilde sig" % [olika, SEEDS.size()])

	print("")
	print("— den handritade våningen rörs inte —")
	var ritad := 0
	for id in ["stage_01", "stage_02"]:
		var s: Stages.StageDef = stages[id]
		if not MapIo.has_map(s.id, 0):
			continue
		var f := Dungeon.generate(s, 0, FRÖ, bestiary)
		ritad += 1
		check(f.rum.is_empty(), "%s v1 (Alex' karta) har inga rum att fylla" % id)
		check(not f.nodes_of_kind("torch").is_empty(),
			"och den har kvar sina egna facklor", "%d st" % f.nodes_of_kind("torch").size())
	check(ritad > 0, "det finns en handritad våning att mäta på", "%d st" % ritad)

	print("")
	print("— påfyllningen NÅR världen, inte bara regeln (SIST i filen med flit: blocket SKAPAR noder) —")
	# Provet bygger dekoren på en RIKTIG våning med spelets EGEN funktion. Instansernas transformar går
	# inte att läsa i huvudlöst läge (dummyns lagring är tom), men ANTALET går — `test_dekor` läser
	# samma siffra. Med `_dekor_täthet = 1` blir varje ruta markdekor, alltså lägger hashen INGA
	# rekvisiter, och varje kandelaber som räknas upp kommer från tomrumspåfyllningen: kallas den aldrig
	# blir svaret 0.
	var main: Node = load("res://main.gd").new()
	main.world = Node3D.new()
	main.add_child(main.world)
	var s4: Stages.StageDef = stages["stage_40"]
	var db := Cards.load_all()
	var körning = Run.new(s4, bestiary, Cards.make_pile(db, ["lash"]), 42, db)
	main.run = körning
	var fl = körning.explore.floor_ref
	var golv: Array = []
	for y in fl.h:
		for x in fl.w:
			if fl.is_floor_at(Vector2i(x, y)):
				golv.append(Vector2i(x, y))
	main._dekor_täthet = 1
	main._bygg_dekor(golv)
	var krona: MultiMeshInstance3D = main.world.get_node_or_null("dekor_kandelaber")
	check(krona != null, "dekoren byggdes på en riktig våning", "%d golvrutor" % golv.size())
	var väntade := 0
	for i in fl.rum.size():
		if (M._rum_fyllnad(fl, fl.rum[i]) as Vector2i).x >= 0:
			väntade += 1
	if krona != null:
		check(krona.multimesh.instance_count == väntade,
			"varje rum fick EN kandelaber när hashen inte lade en enda rekvisit",
			"%d instanser mot %d rum att fylla" % [krona.multimesh.instance_count, väntade])
	main.free()

	print("= %d kontroller, %d fel" % [kontroller, fel])
	quit(1 if fel > 0 else 0)


## Facklornas rutor som en sorterad lista — jämförelsen i determinismprovet ska inte bero på i vilken
## ordning noderna lades (och en sträng duger som nyckel).
func _fackelrutor(f) -> Array:
	var ut: Array = []
	for n in f.nodes_of_kind("torch"):
		ut.append(str(n.pos))
	ut.sort()
	return ut
