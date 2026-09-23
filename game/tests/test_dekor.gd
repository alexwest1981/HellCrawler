extends SceneTree
## Prov för dekorationen (M84). Det som ska mätas är LÖFTET: gräset har ingen kollision, och en tuva är
## en instans i en MultiMesh — inte en nod med en kropp.
##
## Körs: DISPLAY=:99 godot --headless --path game --script res://tests/test_dekor.gd
##
## Provet instansierar INTE hela spelet (det bygger en våning och tar sekunder): `_dekor_nod` behöver
## bara `world` och en textur, så den anropas på en nod som aldrig läggs i trädet.

var fel := 0
var kontroller := 0


func check(villkor: bool, vad: String) -> void:
	kontroller += 1
	if not villkor:
		fel += 1
		print("  FEL: %s" % vad)


func _init() -> void:
	var main: Node = load("res://main.gd").new()
	main.world = Node3D.new()
	main.add_child(main.world)

	# 1) En tuva blir EN instans, och quadden är dukens pixelstorlek gånger DEKOR_PIXEL.
	var tex: Texture2D = load("res://assets/props/gräs.png")
	check(tex != null, "gräs.png laddar")
	var n: int = main._dekor_nod("gräs", [Transform3D(Basis(), Vector3(1.5, 0.0, 2.5))])
	check(n == 1, "en plats ger en instans (fick %d)" % n)
	var nod: MultiMeshInstance3D = main.world.get_node_or_null("dekor_gräs")
	check(nod != null, "noden dekor_gräs finns i världen")
	if nod != null:
		check(nod.multimesh.instance_count == 1, "instansantalet är 1")
		var duk: Vector2 = nod.multimesh.mesh.size
		var väntad: Vector2 = Vector2(float(tex.get_width()), float(tex.get_height())) * float(main.DEKOR_PIXEL)
		check(duk.is_equal_approx(väntad), "quadden är %s, väntade %s" % [duk, väntad])
		# 2) LÖFTET: ingen kollision. Ingen kropp, ingen form — och det går inte att glömma, för ingen
		#    skapas. Provet letar efter dem i stället för att lita på att de inte finns.
		check(_antal_kroppar(nod) == 0, "ingen fysikkropp under dekor_gräs")
		# Lyftet (att figuren står PÅ golvet) mäts INTE här: MÄTT att i huvudlöst läge svarar
		# `get_instance_transform` (0,0,0) hur transformen än sätts — dummyns MultiMesh-lagring är tom,
		# så provet skulle mäta sin egen nolla och se grönt ut. Lyftet verifieras i bild i stället
		# (`tools/play.sh -- shot`, där tuvorna ligger plant mot golvet).

	# 4) Vikttabellen: summan ska vara 1,0, annars faller en andel av rutorna utanför och blir gräs.
	var summa := 0.0
	for rad in main.DEKOR_VIKT:
		summa += float(rad[1])
	check(absf(summa - 1.0) < 0.001, "DEKOR_VIKT summerar till 1,0 (%.3f)" % summa)

	# 5) Tätheten 0 stänger av: ingen nod skapas alls.
	main._dekor_täthet = 0
	main._bygg_dekor([Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)])
	var antal_noder := 0
	for c in main.world.get_children():
		if str(c.name).begins_with("dekor_"):
			antal_noder += 1
	check(antal_noder == 1, "dekor=0 lägger inte till något (kvar: %d)" % antal_noder)

	print("= %d kontroller, %d fel" % [kontroller, fel])
	# Noden lades aldrig i trädet (provets hela poäng), så den städas för hand — annars gnäller Godot om
	# resurser "still in use at exit" och det ser ut som ett fel i ett grönt prov.
	main.free()
	quit(1 if fel > 0 else 0)


func _antal_kroppar(n: Node) -> int:
	var antal := 0
	if n is CollisionShape3D or n is CollisionObject3D:
		antal += 1
	for c in n.get_children():
		antal += _antal_kroppar(c)
	return antal
