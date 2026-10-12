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
		# M108: meshen är en voxelmodell, inte en quad — den har ingen `size`. HÖJDEN är den siffra som
		# betyder något (den blir modellens höjd i meter), så det är den som mäts. Bredden följer figurens
		# eget förhållande och ska inte vara arkets.
		var mått: AABB = (nod.multimesh.mesh as Mesh).get_aabb()
		var väntad: Vector2 = Vector2(float(tex.get_width()), float(tex.get_height())) * float(main.DEKOR_PIXEL)
		check(is_equal_approx(mått.size.y, väntad.y), "modellen är %.3f m hög, väntade %.3f" % [mått.size.y, väntad.y])
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

	# 6) HÄNGER DE SOM SKA HÄNGA? Alex: *"Ljuskronorna ligger på golvet, å hänger inte i taket"*.
	#    Lyftet går inte att läsa ur MultiMesh i huvudlöst läge (dummyns lagring är tom), så provet
	#    mäter REGELN i stället: överkanten i taket för en krona, nederkanten på golvet för en tuva.
	var krona_h: float = 52.0 * float(main.DEKOR_PIXEL)
	var krona_y: float = main._dekor_y("kandelaber", krona_h, 1.0)
	check(absf(krona_y + krona_h * 0.5 - float(main.TAK_HÖJD)) < 0.001,
		"ljuskronans ÖVERKANT sitter i taket (%.2f m)" % (krona_y + krona_h * 0.5))
	check(krona_y - krona_h * 0.5 > 0.2,
		"och den hänger fritt över golvet (underkant %.2f m)" % (krona_y - krona_h * 0.5))
	var gräs_h: float = 26.0 * float(main.DEKOR_PIXEL)
	var gräs_y: float = main._dekor_y("gräs", gräs_h, 1.0)
	check(absf(gräs_y - gräs_h * 0.5) < 0.001, "och en tuva står på golvet (mitt %.3f m)" % gräs_y)
	check(main.REKVISIT_HÄNGER.has("bur") and not main.REKVISIT_HÄNGER.has("spricka_eld"),
		"buren hänger, sprickan i golvet ligger kvar på golvet")

	# GLÖDEN SITTER BARA PÅ LÅGORNA (M115) — SIST I PROVET MED FLIT: `_dekor_nod` SKAPAR noder, och
	# kontrollen strax ovan räknar dem ("dekor=0 lägger inte till något"). Låg de här först blev svaret 3
	# i stället för 1 — ett prov som rör tillståndet förstör proven efter sig (mätt: sviten röd på det).
	# Emissionen låg förut på HELA materialet, så metall, kedja och armar glödde med (Alex: *"lyser hela
	# kandelabern i taket, inte toppen på ljusen"*). Kontrollen kräver shadern som släpper igenom
	# lågfärgen — och att en rekvisit som inte lyser inte får något alls.
	main._dekor_nod("kandelaber", [Transform3D(Basis(), Vector3(1.5, 0.0, 2.5))])
	var mat_låga: Material = main._låg_material.get("kandelaber")
	check(mat_låga is ShaderMaterial,
		"kandelaberns glöd är shadern, inte ett material över hela modellen (%s)"
		% (mat_låga.get_class() if mat_låga != null else "inget material"))
	if mat_låga is ShaderMaterial:
		var sh: Shader = (mat_låga as ShaderMaterial).shader
		check(sh != null and sh.resource_path.ends_with("voxel_rekvisit.gdshader"),
			"och den är låg-shadern (%s)" % (sh.resource_path if sh != null else "ingen shader"))
	main._dekor_nod("bur", [Transform3D(Basis(), Vector3(1.5, 0.0, 2.5))])
	check(not main._låg_material.has("bur"), "en rekvisit som inte lyser får ingen glöd")

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
