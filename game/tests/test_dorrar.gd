## Dörrar (M161). Alex: *"Hur gör vi om man vill sätta in en dörr? ... Och då vill jag kunna skapa olika
## dörrar, så som gallerdörrar, metalldörrar eller trädörrar, men de skall alla vara beroende av en
## lösning på vägen."*
##
## Provet mäter tre lager: kartreglerna (MapIo), gången (en låst dörr stoppar, en nyckel öppnar) och
## körningen (att plocka upp nyckeln löser koden).
##
##   tools/ett_prov.sh tests/test_dorrar.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	else:
		fails += 1
		print("  FEL  %s%s" % [vad, "" if detalj.is_empty() else "  (%s)" % detalj])


## En liten korridor: golv på rad 2, start i (1,2), dörr i (3,2), nyckel i (5,2).
func _bana() -> Dungeon.Floor:
	var f := MapIo.blank("stage_01", 0, 9, 5)
	for x in range(1, 8):
		f.tiles[2][x] = Dungeon.FLOOR
	f.nodes.clear()
	f.start = Vector2i(1, 2)
	var start := Dungeon.FloorNode.new()
	start.kind = "start"
	start.pos = Vector2i(1, 2)
	f.nodes.append(start)
	return f


func _init() -> void:
	# 1. KARTREGLERNA
	var f := _bana()
	check(MapIo.sätt_dörr(f, "trä", Vector2i(3, 2), "spak 1").is_empty(),
		"en trädörr går att sätta på golv")
	check(f.dörrar.size() == 1, "den ligger i våningens dörrlista")
	check(not MapIo.sätt_dörr(f, "trä", Vector2i(3, 2)).is_empty(), "två dörrar på samma ruta vägras")
	check(MapIo.sätt_dörr(f, "galler", Vector2i(1, 0)).contains("golv"), "en dörr i väggen vägras")
	check(MapIo.sätt_dörr(f, "fönster", Vector2i(4, 2)).contains("dörrtyp"),
		"en okänd dörrtyp vägras")
	for typ in MapIo.DÖRRAR:
		check(MapIo.DÖRRAR.has(typ), "dörrtypen %s finns" % typ)

	# 2. FILEN: dörrarna måste skrivas OCH läsas, annars ser filen rätt ut och spelet tappar dem.
	var d := MapIo.to_dict(f)
	check(d.has("dörrar") and (d["dörrar"] as Array).size() == 1, "dörren skrivs till filen")
	var tillbaka := MapIo.from_dict(d, "stage_01", 0)
	check(tillbaka != null and tillbaka.dörrar.size() == 1, "och läses tillbaka")
	check(tillbaka.dörrar[0]["pos"] == Vector2i(3, 2)
		and str(tillbaka.dörrar[0]["typ"]) == "trä" and str(tillbaka.dörrar[0]["kod"]) == "spak 1",
		"med ruta, typ och kod", str(tillbaka.dörrar[0]))

	# 3. GÅNGEN: en låst dörr stoppar, en löst kod öppnar.
	var ex := Explore.new(tillbaka)
	check(ex.dörr_låst(Vector2i(3, 2)), "dörren är låst från början")
	ex.pos = Vector2i(2, 2)
	ex.facing = Explore.EAST
	var err := ex.forward()
	check(err == "låst", "att gå in i den säger 'låst'", err)
	check(ex.pos == Vector2i(2, 2), "och man står kvar")
	ex.öppna("spak 1")
	check(not ex.dörr_låst(Vector2i(3, 2)), "spaken med samma namn öppnar dörren")
	err = ex.forward()
	check(err == "" and ex.pos == Vector2i(3, 2), "och då går den att gå igenom", err)

	# 4. EN ANNAN KOD ÖPPNAR INTE: låset hör ihop med sin nyckel.
	var f2 := _bana()
	MapIo.sätt_dörr(f2, "metall", Vector2i(3, 2), "spak 2")
	var ex2 := Explore.new(f2)
	ex2.öppna("spak 1")
	ex2.pos = Vector2i(2, 2)
	ex2.facing = Explore.EAST
	check(ex2.forward() == "låst", "spak 1 öppnar inte en dörr som lyssnar på spak 2")

	# 4b. OBUNDEN DÖRR: ingen spak öppnar den, och namnet är dörrens eget.
	var f2b := _bana()
	MapIo.sätt_dörr(f2b, "trä", Vector2i(3, 2))
	var ex2b := Explore.new(f2b)
	ex2b.öppna("spak 1")
	ex2b.öppna("")
	ex2b.pos = Vector2i(2, 2)
	ex2b.facing = Explore.EAST
	check(ex2b.forward() == "låst", "en obunden dörr går inte att öppna alls")
	check(str(f2b.dörrar[0]["namn"]) == "dörr 1", "och dörren har fått ett namn",
		str(f2b.dörrar[0]["namn"]))

	# 4c. RIKTNINGEN: dörren står tvärs gången, och ett manuellt val vinner över gissningen.
	var fx := _bana()
	for x in range(1, 8):
		fx.tiles[1][x] = Dungeon.WALL
		fx.tiles[3][x] = Dungeon.WALL         # gången går öst-väst
	MapIo.sätt_dörr(fx, "trä", Vector2i(3, 2), "spak 1")
	check(MapIo.dörr_riktning(fx, fx.dörrar[0]) == "z", "i en öst-västlig gång står plattan bred i z")
	fx.dörrar[0]["riktning"] = "x"
	check(MapIo.dörr_riktning(fx, fx.dörrar[0]) == "x", "men ett manuellt val vinner")
	fx.dörrar[0]["riktning"] = ""
	for y in range(1, 5):
		fx.tiles[y][1] = Dungeon.FLOOR
		fx.tiles[y][2] = Dungeon.FLOOR
		fx.tiles[y][3] = Dungeon.FLOOR
		fx.tiles[y][4] = Dungeon.WALL
		fx.tiles[y][0] = Dungeon.WALL
	check(MapIo.dörr_riktning(fx, fx.dörrar[0]) == "x", "i en nord-sydlig gång står den bred i x")

	# 5. KÖRNINGEN: nyckeln på rutan löser koden, spaken likaså.
	var stage: Stages.StageDef = Stages.load_all().values()[0]
	var bestiary := Enemies.load_all()
	var f3 := _bana()
	MapIo.sätt_dörr(f3, "galler", Vector2i(3, 2), "spak 1")
	var nyckel := Dungeon.FloorNode.new()
	nyckel.kind = "nyckel"
	nyckel.pos = Vector2i(4, 2)
	nyckel.kod = "spak 1"
	f3.nodes.append(nyckel)
	var spak := Dungeon.FloorNode.new()
	spak.kind = "spak"
	spak.pos = Vector2i(6, 2)
	spak.kod = "2"
	f3.nodes.append(spak)
	# Provvåningen är en korridor utan boss/strider/utgång, så `validate` har annat att anmärka på —
	# det är DÖRRARNA vi mäter: inget dörrfel.
	var dörrfel := []
	for rad in MapIo.validate(f3):
		if str(rad).contains("dörr"):
			dörrfel.append(str(rad))
	check(dörrfel.is_empty(), "dörren, nyckeln och spaken ger inget dörrfel", str(dörrfel))
	var run := Run.new(stage, bestiary, [], 7)
	check(run != null, "en körning går att skapa")
	if run != null:
		run.explore = Explore.new(f3)
		check(run.explore.dörr_låst(Vector2i(3, 2)), "dörren är låst i körningen")
		run.explore.pos = nyckel.pos
		run.enter_node(nyckel)
		check(not run.explore.dörr_låst(Vector2i(3, 2)), "nyckeln löste koden")
		check(nyckel.cleared, "och nyckeln är förbrukad")

	# 6. VALIDERINGEN fångar en dörr som inte lyssnar på något.
	var f4 := _bana()
	f4.dörrar.append({"pos": Vector2i(3, 2), "typ": "trä", "kod": ""})
	var utan := ""
	for rad in MapIo.validate(f4):
		if str(rad).contains("inte bunden"):
			utan = str(rad)
	check(not utan.is_empty(), "en dörr utan kod är ett fel", utan)

	print("")
	print("=== %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
