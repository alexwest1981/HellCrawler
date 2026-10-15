## Provet för HUD:ens rutor (M40): statusblocket uppe till vänster, loggen nere till vänster och
## statusblocket uppe till vänster och loggen nere till vänster — Alex' GUI-referens, med korten kvar i mitten i stället för en action bar.
##
## Två sorters kontroller:
##   * LOGIKEN (alltid): staplarnas fyllning följer värdet, loggens ring håller sina rader i ordning,
##     målet (namn och bild) hämtas ur striden; den egna fienderutan togs bort i M68.
##   * LÄGET (bara med ett fönster som rymmer vyn): att rutorna ligger i marginalen och inte över
##     spelvyn, korten eller varandra. I huvudlöst läge (tools/test.sh) är fönstret 64x64 och vyn
##     ryms inte alls, så de kontrollerna hoppas över där och mäts i stället i `-- guiprov`, som kör
##     med ett riktigt fönster. Ett prov som mäter en layout i ett 64 px fönster mäter ingenting.
##
## KÖRNING: godot --headless --script res://tests/test_gui.gd
extends SceneTree

var main: Node

var fails := 0
var checks := 0
var fönster := Vector2.ZERO
var vy := Rect2()

## Kvadarna som `_hugg` (M107) lägger i världen. Känns igen på shadern, inte på namnet: en nod som
## heter rätt men ritar fel är inget hugg.
func _hugg_kvadar(nod: Node) -> Array:
	var ut: Array = []
	for barn in nod.world.get_children():
		var mi := barn as MeshInstance3D
		if mi == null or not (mi.material_override is ShaderMaterial):
			continue
		var sh: Shader = (mi.material_override as ShaderMaterial).shader
		if sh != null and sh.resource_path.ends_with("hugg.gdshader"):
			ut.append(mi)
	return ut

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
		fails += 1

func ruta(n: Control) -> Rect2:
	return Rect2(n.global_position, n.size)

func överlappar(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b) and a.intersection(b).get_area() > 4.0

func måttbart() -> bool:
	return fönster.y >= 700.0 and vy.size.y > 0.0

## Rutan i FÖNSTRETS px. Valkorten ligger i vyn och skalas upp i fönstret; handens kort ligger
## redan i fönstret. Att jämföra dem utan omräkning gav "0 px krock" med 44 px verklig överlapp.
func fönsterruta(r: Rect2, xform: Transform2D) -> Rect2:
	var a: Vector2 = xform * r.position
	var b: Vector2 = xform * r.end
	return Rect2(a, b - a)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# SPRÅKET PINNAS EFTER main, inte före: `main._ready` läser sparfilens språk (`meta.language`)
	# och sätter det sist, så en pinne före instansieringen skrivs över. Provet jämför mot svenska
	# ordagrant ("NYTT SPEL", "tillbaka till byn"), och det ska inte hänga på vilket språk spelaren
	# råkade välja i sin egen sparfil.
	Tr.set_lang("sv")
	# Provet SPELAR en körning, och körningen sparar sig själv. Utan den här raden blir det spelarens
	# sparfil — mätt: en svitkörning skrev en pågående körning (676 -> 1190 byte) i save.json.
	Meta.fotolage(true)
	# Ett fönster i spelstorlek: provkörningen är huvudlös och startar i 64x64, där marginalerna inte
	# finns alls (vyn är 960x540 och hamnar utanför fönstret). Utan det mäter provet en layout ingen
	# spelar i — samma skäl och samma rad som tests/test_kortbord.gd.
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	# GLANSEN (M74): en glasfiende tvingas fram, så kontrollen av glansen nedan mäter MEKANISMEN och
	# inte vilka fiender våningen råkade bjuda på. Sedan M74 bär andarna sin aura som en kant ur
	# materialmasken, och den gamla varma dimfläcken (`rok.png`) togs bort för dem — den enda glans
	# kvar i våningen var just de två fläckarna, så kontrollen hade tyst mätt noll.
	# FÖRE `_start_run`: fienderna byggs MED våningen (mätt: sattes provet efter `_start_run` stod
	# 25 figurer med 0 glans kvar — `_fiendeprov` läses när figuren skapas, inte när striden börjar).
	main._fiendeprov = "glass_herald"
	main._start_run("stage_01", 20260919)
	main._placera_vy()
	await process_frame
	# En strid: gå fram till en fiende och slåss (kartan läggs i ordning, så provet inte gissar var).
	# PROVET VÄLJER EN STRID MED FLERA FIENDER (M100). Ledet — och därmed radregeln — syns bara när det
	# står fler än en, och en våning bjuder på båda slagen. Finns ingen sådan nod mäts den första bästa.
	var nod: Dungeon.FloorNode = null
	var flera: Dungeon.FloorNode = null
	for n in main.run.explore.floor_ref.nodes:
		if not n.cleared and (n.kind == "encounter" or n.kind == "boss"):
			if nod == null:
				nod = n
			if main.run.enemy_count_for(n, n.kind == "boss") > 1:
				flera = n
				break
	nod = flera if flera != null else nod
	main.run.explore.pos = nod.pos
	main.run.explore.facing = 0
	main._enter_node_here()
	main._refresh()                       # samma väg som spelet: striden ritas av _refresh
	await process_frame
	await process_frame
	fönster = main.get_viewport().get_visible_rect().size
	vy = Rect2(main._vy_korg.position, main._vy_korg.size * main._vy_korg.scale.x)
	print("  fönstret %.0fx%.0f, spelvyn %s, strid: %s" % [fönster.x, fönster.y, str(vy),
		"ja" if main.active_combat != null else "nej"])
	check(main.active_combat != null, "provet fick en strid att mäta i")

	## FIGURERNA STÅR I FORMATION, RAD FÖR RAD (M100). M66 lade dem på ETT led för att en 1 m-gång inte
	## rymde två sida vid sida — men då stod den bakre inne i den främre och man såg bara EN fiende
	## (Alex: *"om man stöter på mer än 1 fiende i en ruta, så är fighten fortfarande bara med 1 fiende
	## ... de ska ställa upp sig i formation - rad för rad"*). Regeln ligger i run.gd (`per_rad`,
	## `SIDLED`, `RADAVSTAND`) och är DENSAMMA som stridens rader.
	##
	## Provet mäter formationens EGENSKAPER, inte regeln om igen: raderna ligger på rätt djup, raderna
	## är symmetriska kring siktlinjen, främre radens mitt ligger mitt för spelaren, och två figurer i
	## samma rad står isär så att ingen skymmer den andra (det var hela felet).
	print("")
	print("— figurerna —")
	var figurer := main.get_tree().get_nodes_in_group("fiende_figur")
	var djup_fel := []
	var osymmetriska := []
	var skymda := []
	var mitt_fel := []
	if main.active_combat != null and main.cam != null:
		# UTGÅNGSPUNKTEN ÄR SPELARENS RUTA, inte fiendens: `_stage_fight` ställer upp ledet framför
		# spelaren (efter `_backa_till_rutan_före`), och det är därifrån avstånden mäts.
		var fram := Vector2(main.run.led_fram())
		var sido := Vector2(main.run.led_sido())
		var bas: Vector2 = Vector2(main.run.explore.pos) + Vector2(0.5, 0.5)
		var rader := {}
		for fig in figurer:
			if fig.position.distance_to(Vector3(bas.x, fig.position.y, bas.y)) > 3.0:
				continue
			var p := Vector2(fig.position.x, fig.position.z) - bas
			var d := p.dot(fram)
			var s := p.dot(sido)
			# BARA LEDET FRAMFÖR SPELAREN. Våningen har fiender i rummen runt omkring, och en figur
			# bakom spelaren, eller inne i ett annat rum, hör till en annan nod.
			if d < 0.4 or absf(s) > 1.2:
				continue
			# Djupet är 1,15 + led * 0,60 (0,75 + led * 0,45 när rutan framför är en vägg). Provet tar
			# den av de två som ligger närmast i stället för att gissa vilken gren som gällde.
			var led1 := roundf((d - 1.15) / Run.RADAVSTAND)
			var led2 := roundf((d - 0.75) / 0.45)
			var fel1: float = absf(d - (1.15 + led1 * Run.RADAVSTAND))
			var fel2: float = absf(d - (0.75 + led2 * 0.45))
			if mini(fel1, fel2) > 0.06:
				djup_fel.append("%s djupt %.2f m" % [str(fig.position), d])
				continue
			var led := int(led1) if fel1 <= fel2 else int(led2)
			if not rader.has(led):
				rader[led] = []
			rader[led].append({"fig": fig, "s": s, "pos": fig.position})
		for led in rader:
			var rad: Array = rader[led]
			var summa := 0.0
			for r in rad:
				summa += float(r["s"])
			# Symmetrin: en rad om två ska ligga lika långt på var sin sida om siktlinjen.
			if absf(summa) > 0.08:
				osymmetriska.append("rad %d: summa %+.2f m" % [led, summa])
			var sorterad := rad.duplicate()
			sorterad.sort_custom(func(a, b): return float(a["s"]) < float(b["s"]))
			for k in range(sorterad.size() - 1):
				var avstånd: float = float(sorterad[k + 1]["s"]) - float(sorterad[k]["s"])
				if avstånd < Run.SIDLED * 0.6:
					skymda.append("rad %d: %.2f m isär" % [led, avstånd])
			if led == 0:
				# FRÄMRE RADEN STÅR MITT FÖR SPELAREN. En ensam fiende står rakt fram; står flera i raden
				# är det RADENS MITT som ligger på siktlinjen (symmetrin ovan) och ingen får sticka ut
				# utanför rutan (0,75 m ≈ gångens halva bredd + marginal) — annars står ledet i väggen.
				if rad.size() == 1:
					for r in rad:
						if absf(float(r["s"])) > 0.15:
							mitt_fel.append("%s %.2f m i sidled" % [str(r["pos"]), float(r["s"])])
				else:
					for r in rad:
						if absf(float(r["s"])) > 0.75:
							mitt_fel.append("%s %.2f m utanför rutan" % [str(r["pos"]), float(r["s"])])
		# RADERNA I STRIDEN ÄR DESAMMA SOM I BILDEN (M100). Två fiender i främre raden slår båda två
		# (combat.gd: varje levande fiende med rad <= främsta raden), och då MÅSTE de stå i samma led i
		# bilden — annars slår någon som står bakom, eller står den som slår och väntar bakom en annan.
		var storlekar_bild := []
		var bild_nycklar := rader.keys()
		bild_nycklar.sort()
		for led in bild_nycklar:
			storlekar_bild.append(rader[led].size())
		var storlekar_modell := []
		if main.active_combat != null:
			var antal_rad := {}
			for e in main.active_combat.enemies:
				antal_rad[e.row] = int(antal_rad.get(e.row, 0)) + 1
			var modell_nycklar := antal_rad.keys()
			modell_nycklar.sort()
			for r in modell_nycklar:
				storlekar_modell.append(int(antal_rad[r]))
		check(storlekar_bild == storlekar_modell, "stridens rader är desamma som ledet i bilden",
			"%s mot %s" % [str(storlekar_bild), str(storlekar_modell)])
	check(figurer.size() > 0, "våningen har fiender att mäta (%d figurer)" % figurer.size())
	check(djup_fel.is_empty(), "raderna ligger på rätt djup (%d fel)" % djup_fel.size(),
		", ".join(djup_fel.slice(0, 3)))
	check(osymmetriska.is_empty(), "raderna är symmetriska kring siktlinjen (%d fel)"
		% osymmetriska.size(), ", ".join(osymmetriska.slice(0, 3)))
	check(skymda.is_empty(), "ingen figur i en rad skymmer sin granne (%d fel)" % skymda.size(),
		", ".join(skymda.slice(0, 3)))
	check(mitt_fel.is_empty(), "främre radens mitt står mitt för spelaren (%d fel)" % mitt_fel.size(),
		", ".join(mitt_fel.slice(0, 3)))
	## FÖRHANDSVISNINGEN ÖVER FIENDEN (M103). Alex: *"Sen vill jag se den skada som kommer ske över varje
	## fiende på närmaste rad (om det nu skulle finnas fiender bakom t ex) när jag hovrar över ett kort.
	## Nu får man ju chansa. Jag vill då att det visar hur mycket varje fiende har i hälsa först, å sen
	## var det landar efter attack."* Provet hovrar samma väg som musen (`_forward_index` +
	## `_refresh_battle`), läser texten över figuren, spelar kortet och kräver att den var sann.
	print("")
	print("— förhandsvisningen över fienden —")
	var visad := -1
	var p_förhand := {}
	for k in main.active_combat.hand.size():
		var q: Dictionary = main.active_combat.preview(k)
		if q.get("ok", false) and not q.get("hits", []).is_empty():
			visad = k
			p_förhand = q
			break
	check(visad >= 0, "det finns ett spelbart skadekort att förhandsvisa")
	if visad >= 0:
		var vy := -1
		for v in main.active_combat.hand.size():
			if main._hand_index(v) == visad:
				vy = v
				break
		main._forward_index = vy
		main._refresh_battle()
		var över := []
		for n in main._forhands_noder:
			if is_instance_valid(n):
				över.append(str(n.text))
		var väntade := []
		var hp_före := {}
		for h in p_förhand["hits"]:
			hp_före[h.enemy] = h.enemy.hp
			väntade.append("%.0f → %.0f" % [h.enemy.hp, maxf(0.0, h.enemy.hp - float(h.damage))])
		över.sort()
		väntade.sort()
		check(över == väntade, "texten över fienden är 'hp → efter'", "%s mot %s" % [str(över), str(väntade)])
		# Och den är SANN: spelet kortet på riktigt och jämför varje träffads hp-tapp med siffran.
		var fel := 0
		for h in p_förhand["hits"]:
			var e = h.enemy
			var före: float = hp_före[e]
			var skulle := float(h.damage)
			main.active_combat.play(visad)
			if absf(före - e.hp - skulle) > 0.001:
				fel += 1
		check(fel == 0, "siffran över fienden är den man får", "%d fel" % fel)
		main._forward_index = -1
		main._refresh_battle()
		check(main._forhands_noder.is_empty(), "förhandsvisningen städas bort när inget kort är framme",
			"%d kvar" % main._forhands_noder.size())

	## HUGGET (M107): Alex länkade procedural-cyclic-slash ("Vid attack, men behöver fler liknande
	## denna, så det blir variation"). Bågen är PROCEDURELL — ingen textur — så provet mäter det som
	## ger variationen (fyra rattar dras olika för varje hugg), att kvaden följer figurens höjd, och att
	## den städar efter sig. Anropet går genom `_slag_kvitto`, den enda vägen in för skada.
	print("")
	print("— hugget över fienden —")
	var hugg_fiende: Sprite3D = null
	for f in figurer:
		hugg_fiende = f as Sprite3D
		break
	check(hugg_fiende != null, "det finns en fiende att hugga")
	if hugg_fiende != null:
		main._slag_kvitto(hugg_fiende, 5.0, 1)
		var kvadar := _hugg_kvadar(main)
		check(kvadar.size() == 1, "slaget lägger en båge i världen", "%d kvadar" % kvadar.size())
		if kvadar.size() == 1:
			var rattar: Array = []
			for namn in ["vinkel", "riktning", "radie", "svep", "bredd", "styrka"]:
				rattar.append(float((kvadar[0].material_override as ShaderMaterial).get_shader_parameter(namn)))
			# Flyttal: 0,408 mot 0,40800001 är samma höjd, och ett == hade fällt ett riktigt hugg.
			check(is_equal_approx((kvadar[0].mesh as QuadMesh).size.x, 34.0 * hugg_fiende.pixel_size),
				"bågen har figurens höjd (34 x pixel_size)",
				"%.3f m" % (kvadar[0].mesh as QuadMesh).size.x)
			main._hugg(hugg_fiende)
			var kvadar2 := _hugg_kvadar(main)
			var olika := 0
			if kvadar2.size() == 2:
				for i in rattar.size():
					var ny := float((kvadar2[1].material_override as ShaderMaterial)
						.get_shader_parameter(["vinkel", "riktning", "radie", "svep", "bredd", "styrka"][i]))
					if absf(ny - float(rattar[i])) > 0.0001:
						olika += 1
			# Ett hugg är fyra SLUMPADE rattar (Alex: "behöver fler liknande denna, så det blir
			# variation"). Att alla sex blev lika är att slumptalet sitter fast.
			check(olika >= 2, "två hugg drar olika rattar (variationen)", "%d av 6 olika" % olika)
		await create_timer(main.HUGG_TID + 0.25).timeout
		check(_hugg_kvadar(main).is_empty(), "och bågen städar sig själv efter svepet",
			"%d kvar" % _hugg_kvadar(main).size())

	## SKAKET PÅ TRÄFFEN (M122): den STARKARE av två träffar vinner, styrkan dör ut, och när den gjort
	## det står kameran EXAKT tillbaka — en kvarglömd offset är en sned bild för alltid. Att kamerans
	## egna position inte rörs är hela poängen: den ägs av kamera-tweenen, och två skribenter på samma
	## egenskap är buggklassen repot varnar för. Skaket bor därför i `h_offset`/`v_offset`.
	print("")
	print("— skaket på träffen —")
	main._skak = 0.0
	main.skaka(0.3)
	main.skaka(0.1)
	check(is_equal_approx(main._skak, 0.3), "den starkare av två träffar vinner", "%.2f" % main._skak)
	main._skaka_vyn(0.05)
	check(main.cam.h_offset != 0.0 or main.cam.v_offset != 0.0, "skaket flyttar kameran",
		"%.4f / %.4f" % [main.cam.h_offset, main.cam.v_offset])
	var kamera_före: Vector3 = main.cam.position
	for i in 40:
		main._skaka_vyn(0.05)     # 40 x 50 ms = 2 s: mer än avtaget behöver för att nå noll
	check(is_equal_approx(main._skak, 0.0), "styrkan dör ut", "%.3f" % main._skak)
	check(main.cam.h_offset == 0.0 and main.cam.v_offset == 0.0, "och kameran ställs exakt tillbaka",
		"%.4f / %.4f" % [main.cam.h_offset, main.cam.v_offset])
	check(main.cam.position.is_equal_approx(kamera_före), "utan att kamerans egen plats rörs",
		str(main.cam.position))

	## KORTETS EGNA EFFEKTER (M103): glansen vid hover och förbränningen när kortet spelas. Båda bor i
	## EN överläggning ovanpå kortet (ui/kortfx.gdshader), för kortet är ett träd av Controls och en
	## canvas-shader ritar per del — en brinnfläck hade hamnat olika på ramen, konsten och texten.
	print("")
	print("— kortets glans och brand —")
	var kortvy: CardView = main.hand_views[0]
	check(kortvy != null and kortvy._fx != null and kortvy._fx_material != null
		and kortvy._fx_material.shader != null
		and kortvy._fx_material.shader.resource_path.ends_with("kortfx.gdshader"),
		"kortet har en överläggning med kortfx-shadern")
	await process_frame
	check(kortvy._fx.size.is_equal_approx(kortvy.home_size),
		"överläggningen har kortets eget mått", "%.1fx%.1f mot %.1fx%.1f"
		% [kortvy._fx.size.x, kortvy._fx.size.y, kortvy.home_size.x, kortvy.home_size.y])
	if kortvy.forward:
		kortvy.set_forward(false)
		await create_timer(0.2).timeout
	# ÖVERLÄGGNINGEN FÅR INTE LÄSA SKÄRMEN (M106c). Den första versionen gjorde det, och i Alex' fönster
	# blev ett kort alldeles svart: skärmkopian löste ut i svart i hans vy, och överläggningen är
	# ogenomskinlig, så den målade ut kortet (vit ram, kolsvart inuti — hans bild). Här räckte renderingen
	# — samma kod gav ett friskt kort. Provet läser därför shaderns KOD och kräver att ingen skärmtextur
	# finns kvar, vilket fångar felet även när maskinen råkar rendera rätt.
	var fx_shader: Shader = load("res://ui/kortfx.gdshader")
	check(fx_shader != null and not fx_shader.code.contains("hint_screen_texture"),
		"kortets överläggning ritar sin egen effekt och läser inte skärmen")
	kortvy.set_forward(true)
	await create_timer(0.2).timeout
	check(kortvy._param("glans") > 0.5 and kortvy._fx.visible,
		"glansen tänds när pekaren är över kortet", "glans %.2f" % kortvy._param("glans"))
	kortvy.set_forward(false)
	await create_timer(0.2).timeout
	check(kortvy._param("glans") < 0.5 and not kortvy._fx.visible,
		"och släcks när pekaren lämnar", "glans %.2f" % kortvy._param("glans"))
	kortvy.bränn(0.20, Vector2(12.0, 20.0))
	check(kortvy._fx.visible, "förbränningen tänder överläggningen")
	await create_timer(0.35).timeout
	check(kortvy.brinnt() >= 1.0 and not kortvy._fx.visible,
		"kortet brinner till slutet och överläggningen släcks", "brand %.2f" % kortvy.brinnt())

	# PANELEN ÄR OCKSÅ HEL (M106). Kortets alfa stod rätt hela tiden (mätt: [1.0, 1.0, 1.0, 1.0] före
	# och efter hover), men STILEN bar sin egen genomskinlighet: 0,94 i ledet och 0,97 framträdd. Det
	# var den som släppte igenom fängelsehålan bakom handen. Provet läser alfan ur stilen som LIGGER på,
	# i båda lägena, så en ny halvgenomskinlig stil fångas här och inte av en spelare.
	if main.hand_views.size() >= 2:
		var k0: CardView = main.hand_views[0]
		var k1: CardView = main.hand_views[1]
		if k0.forward:
			k0.set_forward(false)
			await create_timer(0.2).timeout
		k0.set_forward(true)
		k1.set_forward(false)
		await create_timer(0.2).timeout
		var skugga := k0.get_theme_stylebox("panel") as StyleBoxFlat
		# SKUGGAN (M106b). Alex länkade fyra skugg-shadrar till korten; alla fyra är samma sak — en mjuk
		# skugga under kortet — och den finns inbyggd i StyleBoxFlat. Provet kräver att den FINNS, så en
		# stil som tappar den fångas här och inte av att korten ser platta ut.
		check(skugga != null and skugga.shadow_size > 0 and skugga.shadow_color.a > 0.1,
			"kortet kastar en skugga (StyleBoxFlat, ingen shader)",
			"shadow_size %d, alfa %.2f" % [skugga.shadow_size if skugga != null else -1,
				skugga.shadow_color.a if skugga != null else -1.0])
		check(main._stylebox_alfa(k0) >= 0.999 and main._stylebox_alfa(k1) >= 0.999,
			"kortets panel är hel både framträdd och i ledet",
			"framträdd %.2f, i ledet %.2f" % [main._stylebox_alfa(k0), main._stylebox_alfa(k1)])
		k0.set_forward(false)
		await create_timer(0.2).timeout

	## DÖDSMÄLTAN (M103): bilden smälter nedåt när körningen tar slut i nederlag. Noden läser
	## SCREEN_TEXTURE, så den behöver ingen egen yta — och den ska vara SLÄCKT i vanliga fall (en
	## osynlig ruta som ligger och läser skärmen kostar en kopia av bilden varje bildruta).
	print("")
	print("— dödsmältan —")
	var mält_mat := main.dödsmälta.material as ShaderMaterial if main.dödsmälta != null else null
	check(mält_mat != null and mält_mat.shader != null
		and mält_mat.shader.resource_path.ends_with("malt.gdshader"),
		"dödsmältan finns med malt-shadern")
	check(main.dödsmälta != null and not main.dödsmälta.visible, "och syns inte i vanliga fall")
	main._dödsmälta_spela(0.15)
	check(main.dödsmälta.visible, "smältan tänds när den spelas")
	await create_timer(0.45).timeout
	check(not main.dödsmälta.visible, "och släcks när den är klar")

	# FIGUREN MÅSTE RITAS (M69). Mätt med `-- figurprov fienderödfärg` (figuren självlysande magenta,
	# allt annat i bilden oförändrat): med `material_override` ritar Sprite3D 73 px av figuren, med
	# Sprite3D:s EGET material 22 641 px. Rutan i arket väljs i motorns eget material, och en override
	# tar bort den vägen — figuren blir en nål i gången (Alex: *"spökena står inte vända mot kameran"*).
	# Provet bevakar precis det: ingen fiende får bära ett override, och skuggning + alfa-klippning ska
	# vara kvar (de ÄR figurens material).
	var med_override: Array = []
	var utan_figurmaterial: Array = []
	for f in figurer:
		var spr := f as Sprite3D
		if spr.material_override != null and not (spr.material_override is ShaderMaterial):
			med_override.append(spr.name)
		# Alfan ska antingen KLIPPS (fast figur, skarp kant mot väggarna) eller BLANDAS (genomsläpp,
		# se FIENDE_LOOK). Klippning på en genomsläpplig figur ger inget genomsläpp alls.
		var vill_klippa: int = SpriteBase3D.ALPHA_CUT_DISCARD if spr.modulate.a >= 1.0 \
			else SpriteBase3D.ALPHA_CUT_DISABLED
		if not spr.shaded or spr.alpha_cut != vill_klippa:
			utan_figurmaterial.append("%s (alfa %.2f, klipp %d)" % [spr.name, spr.modulate.a, spr.alpha_cut])
	check(figurer.size() > 0 and med_override.is_empty(),
		"ingen fiende har ett material_override av fel sort (%d av %d — 73 px mot 22 641 px i mätprovet)"
		% [med_override.size(), figurer.size()], ", ".join(med_override.slice(0, 3)))
	check(utan_figurmaterial.is_empty(),
		"figuren skuggas av lyktan och klipper sin alfa (%d av %d fel)"
		% [utan_figurmaterial.size(), figurer.size()], ", ".join(utan_figurmaterial.slice(0, 3)))
	# EGEN LOOK (M70). Alex: *"så spökena t ex är transparenta? dock bara någon procent, och inte
	# genomskinliga"*. Mätt i samma scen: 30 179 px skiljer sig åt mellan 6 procent genomsläpp och
	# helt fast, och figurens medel ljusnar 1,6 steg (väggen bakom anas). Provet bevakar mekanismen:
	# ett genomsläpp måste BLANDAS (alfa-klippning ger inget genomsläpp alls) och ingen fiende får
	# vara en hinna — under 0,85 är den inte en varelse längre.
	var blandade := 0
	var klippt_genomsläpp: Array = []
	var för_tunna: Array = []
	for f in figurer:
		var spr := f as Sprite3D
		var alfa := spr.modulate.a
		if alfa >= 1.0:
			continue
		blandade += 1
		if spr.alpha_cut != SpriteBase3D.ALPHA_CUT_DISABLED:
			klippt_genomsläpp.append(spr.name)
		if alfa < 0.85:
			för_tunna.append("%s %.2f" % [spr.name, alfa])
	check(blandade > 0, "någon fiende har genomsläpp (%d av %d — annars mäter kontrollen inget)"
		% [blandade, figurer.size()])
	check(klippt_genomsläpp.is_empty(),
		"genomsläppet BLANDAS, det klipps inte (%d av %d fel)"
		% [klippt_genomsläpp.size(), figurer.size()], ", ".join(klippt_genomsläpp.slice(0, 3)))
	check(för_tunna.is_empty(), "ingen fiende är en hinna (alfa under 0,85): %s"
		% ", ".join(för_tunna.slice(0, 3)))
	# SKUGGAN HAR FIGURENS FORM (M80). Alex: *"de verkar inte riktigt funka korrekt då all shader läggs
	# som i en fyrkant"*. En genomskinlig quad med alfa-klippningen AV skuggar hela RUTAN — Godots
	# skuggpass har ingen silhuett att klippa mot — så varje fiende bar en mörk fyrkant på golv och
	# vägg. Lagren ovanpå figuren och golvplattan får därför inte skugga alls; figuren som KLIPPER sin
	# alfa behåller sin skugga (den har en form att skugga med).
	var fyrkant: Array = []
	for f in figurer:
		var spr := f as Sprite3D
		if spr.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED \
				and spr.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			fyrkant.append("%s (figuren blandar alfan)" % spr.name)
		for barn in spr.get_children():
			var b := barn as Sprite3D
			if b != null and b.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				fyrkant.append(b.name)
	# Lagren byggs HÄR, av samma funktioner spelet använder: scenens fiender kan sakna mask, och då
	# mäter en kontroll på barnen ingenting — mätt: buggen gick rakt igenom en sådan kontroll.
	for eid in main.bestiary.keys():
		var sökväg := "res://assets/enemies/%s.png" % eid
		if not ResourceLoader.exists(sökväg):
			continue
		var textur: Texture2D = load(sökväg)
		for lag in [main._fiende_lager(eid, textur), main._fiende_shader_lager(eid, textur)]:
			if lag != null and lag.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				fyrkant.append(str(eid))
		var gl: Sprite3D = main._glans(Color.WHITE, 1.0, 0.0, 1.0)
		if gl.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			fyrkant.append("%s glans" % eid)
	for s in main.get_tree().get_nodes_in_group("fiende_skugga"):
		var pl := s as Sprite3D
		if pl != null and pl.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			fyrkant.append("golvplattan")
	check(fyrkant.is_empty(), "ingen fiendedel skuggar som en fyrkant (%d fel)" % fyrkant.size(),
		", ".join(fyrkant.slice(0, 3)))
	# DROPSHADOWEN STÅR STILL (M71). Alex: *"en platta som åker upp och ned? Det ser lite märkligt ut"*
	# — skuggan låg målad i figurens ruta och följde med i andningen. Provet mäter motsatsen: höjden
	# ska ligga på golvet och INTE röra sig medan figuren andas, men x/z ska följa figuren (striden
	# ställer upp den på en ny plats).
	# MASKEN (M73): en fiende MED maskfil får ett material, en UTAN får inget. Provet läser riktiga
	# filer, så det biter även när ingen maskad fiende råkar stå i våningens strid — och det mäter
	# rutnätet: masken måste ha samma storlek som arket, annars hamnar glansen på fel kroppsdel.
	var maskade: Array = []
	var fel_mask: Array = []
	for fil in DirAccess.get_files_at("res://assets/enemies"):
		if not fil.ends_with("_mask.png"):
			continue
		var id := fil.trim_suffix("_mask.png")
		var tex: Texture2D = main._enemy_tex(id)
		var l: Sprite3D = main._fiende_lager(id, tex)
		if l == null:
			fel_mask.append("%s (inget lager)" % id)
			continue
		# Lagret klipper sin ruta ur arket, så texturerna SKA vara AtlasTexture — och masken ska ha
		# exakt samma rutnät som konsten, annars hamnar glansen på fel kroppsdel.
		var ark: Texture2D = l.texture
		var m := l.material_override as ShaderMaterial
		var msk: Texture2D = m.get_shader_parameter("mask") if m != null else null
		var fel_ruta: bool = not (ark is AtlasTexture) or not (msk is AtlasTexture) \
			or (ark as AtlasTexture).atlas.get_width() != (msk as AtlasTexture).atlas.get_width() \
			or (ark as AtlasTexture).atlas.get_height() != (msk as AtlasTexture).atlas.get_height()
		# Rutan följer figuren: sätts regionen fel visar lagret en annan kroppsdel.
		main._ruta_lager(l, 3)
		var region: Rect2 = (ark as AtlasTexture).region
		if fel_ruta or absf(region.position.x - ark.get_width() * 3.0) > 0.5:
			fel_mask.append("%s (rutnätet stämmer inte)" % id)
		maskade.append(id)
	check(not maskade.is_empty(), "någon fiende har en materialmask (%d st)" % maskade.size())
	check(fel_mask.is_empty(), "varje mask har rätt rutnät och följer figurens ruta (%s)" % ", ".join(fel_mask))
	check(main._fiende_lager("skitterling", main._enemy_tex("skitterling")) == null,
		"en fiende UTAN maskfil får inget lager (Godots egen väg behålls)")
	# AURAN (M74): andarna bär sin aura som en KANT ur maskens A-kanal (se fiende_material.gdshader).
	# Utan A-kanalen finns ingen aura alls, och en borttagen rad i generatorns MATERIAL-plan vore
	# annars TYST: masken skulle bara sluta skrivas och figuren se lite tråkigare ut. Provet läser
	# A-kanalen i de riktiga filerna — fem andar ska ha den, metallen ska inte ha någon.
	var utan_aura: Array = []
	for id in ["candlewisp", "salt_wretch", "bell_drowned", "hollow_choir", "pale_reaper"]:
		var fil := "res://assets/enemies/%s_mask.png" % id
		if not ResourceLoader.exists(fil):
			utan_aura.append("%s (ingen maskfil)" % id)
			continue
		var bild := Image.load_from_file(ProjectSettings.globalize_path(fil))
		var aura_px := 0
		for y in range(bild.get_height()):
			for x in range(bild.get_width()):
				if bild.get_pixel(x, y).a > 0.5:
					aura_px += 1
		if aura_px < 1000:
			utan_aura.append("%s (%d px aura)" % [id, aura_px])
	check(utan_aura.is_empty(), "fem andar har en aura i sin mask (A-kanalen)", ", ".join(utan_aura))
	var järn := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/enemies/copper_warden_mask.png"))
	var järn_aura := 0
	for y in range(järn.get_height()):
		for x in range(järn.get_width()):
			if järn.get_pixel(x, y).a > 0.5:
				järn_aura += 1
	check(järn_aura == 0, "en metallfiende har ingen aura (bandet gäller per fiende)", "%d px" % järn_aura)
	# GLANSEN (M72): en aura/glans är en ADDITIV quad med emission över 1,0 — en unshaded yta kan
	# aldrig bli ljusare än vitt och då har glow inget att arbeta med. Provet bevakar just det: rätt
	# blandning, emission över 1,0 och att den sitter som BARN till figuren (den ska andas med den).
	var glansar := main.get_tree().get_nodes_in_group("fiende_glans")
	check(not glansar.is_empty(), "någon fiende har en glans/aura (%d st)" % glansar.size())
	# Styrkan är en smaksak, inte ett krav: glaset ligger på 0,90 och metallglinten på 1,5-1,6 (över
	# 1,0 = HDR = blomstrar). Vid 1,5 på en STOR fläck mättes en utfrätt vit klump (medel 98,8 och
	# 6 049 px över 240 i utsnittet) — samma siffra på en liten fläck är en glint. Provet kräver
	# därför det som ÄR mekanismen: additiv blandning, per-pixel skuggning (den enda vägen till HDR)
	# och att quaden sitter som barn till figuren.
	# Andarnas aura går INTE den här vägen sedan M74 (den är en kant ur materialmasken) — fläcken här
	# är glas, metall och den våta glansen.
	var fel_glans: Array = []
	for g in glansar:
		var gs := g as Sprite3D
		var gm := gs.material_override as StandardMaterial3D
		if gm == null or gm.blend_mode != BaseMaterial3D.BLEND_MODE_ADD \
				or gm.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
				or gs.get_parent() == null or not (gs.get_parent() is Sprite3D):
			fel_glans.append(gs.name)
	check(fel_glans.is_empty(), "auktor: additiv, per-pixel och barn till figuren (%s)"
		% ", ".join(fel_glans))
	var skuggor := main.get_tree().get_nodes_in_group("fiende_skugga")
	check(skuggor.size() == figurer.size(), "varje fiende har en egen skugga (%d skuggor, %d figurer)"
		% [skuggor.size(), figurer.size()])
	if not skuggor.is_empty():
		var sk0 := skuggor[0] as Sprite3D
		var höjd_före := sk0.position.y
		var spr0 := figurer[0] as Sprite3D
		var x_före := spr0.position.x
		for i in 30:
			await process_frame
		var spr_y := spr0.position.y
		check(absf(sk0.position.y - höjd_före) < 0.0001,
			"skuggan står STILL i höjdled medan figuren andas (%.4f, figurens y %.3f)"
			% [sk0.position.y, spr_y])
		# Golvplattan är 4 cm tjock (topp på 0,04) — under den försvinner skuggan helt (mätt: den låg
		# osynlig på 0,012 först). Över 0,10 m börjar den sväva.
		check(höjd_före > 0.04 and höjd_före < 0.10, "och den ligger på golvet (%.3f m)" % höjd_före)
		check(sk0.texture != null and sk0.visible,
			"skuggan har en textur och syns (%s, syns %s, %dx%d px)"
			% ["ja" if sk0.texture != null else "NEJ", str(sk0.visible),
				sk0.texture.get_width() if sk0.texture != null else 0,
				sk0.texture.get_height() if sk0.texture != null else 0])
		spr0.position.x = x_före + 1.0
		await process_frame
		check(absf(sk0.position.x - spr0.position.x) < 0.001,
			"skuggan följer figurens x när striden ställer upp den")
		spr0.position.x = x_före

	print("")
	print("— statusblocket —")
	check(main.hud_status != null and main.hud_status.visible, "statusblocket syns")
	check(main.hud_status.porträtt.texture != null, "porträttet är laddat (assets/ui/portratt.png)")
	# KÄRLEN (M51, omgjorda i M111 och flyttade till REMSAN i M113): hälsa, mana och rustning som KLOT.
	# Alex: *"Jag ser fortfarande inga Orbs heller, och jag skulle vilja ha 3 - HP, Mana och Armor.
	# Man måste veta om man har så man klarar sig genom en strid. Sätt dem nere i vardera hörn, men
	# placera Armor över HP. Nu är det dags att de syns oavsett upplösning."*
	#
	# PROVET MÄTER DET SOM FÖRUT GICK FEL, mot den NYA regeln: kloten ligger i BAREN under spelvyn
	# (M113), radien räknas ur Barens höjd i fönsterpixlar, och mitten — själva värdet — ligger i baren.
	# Den gamla placeringen räknade radien ur utrymmet mellan panelerna och klämde klotet till 20x20 px
	# i Alex' eget fönster (mätt), medan provet sade "syns [true, true, true]".
	var bar_ruta: Rect2 = main._bar(fönster)
	print("      baren %s (%.0f px hög)" % [str(bar_ruta), bar_ruta.size.y])
	var kärl := [main.orb_hp, main.orb_mana, main.orb_rust]
	for k in kärl:
		check(k != null and k.size.x >= 34.0, "kärlet syns och har en ruta (golvet är 34 px)",
			"%.0fx%.0f @ %.0f,%.0f" % [k.size.x, k.size.y, k.position.x, k.position.y])
		check(k.visible, "kärlet är synligt i strid")
		check(k.get_rect().position.x >= 0.0 and k.get_rect().position.y >= 0.0
				and k.get_rect().end.x <= fönster.x and k.get_rect().end.y <= fönster.y,
			"kärlet ryms helt i fönstret", "%s mot fönstret %.0fx%.0f" % [str(k.get_rect()), fönster.x, fönster.y])
		check(bar_ruta.has_point(k.get_rect().get_center()),
			"kärlets mitt ligger i REMSAN (hörnet är dess eget)", "%s mot baren %s" % [str(k.get_rect()), str(bar_ruta)])
	check(is_equal_approx(main.orb_hp.size.x, main.orb_mana.size.x)
			and is_equal_approx(main.orb_hp.size.x, main.orb_rust.size.x),
		"alla tre klot är lika stora", "hp %.0f, mana %.0f, rust %.0f" % [main.orb_hp.size.x,
			main.orb_mana.size.x, main.orb_rust.size.x])
	# RUSTNINGEN LIGGER ÖVER HÄLSAN (Alex: *"placera Armor över HP"*), i samma lodräta linje.
	check(absf(main.orb_rust.get_rect().get_center().x - main.orb_hp.get_rect().get_center().x) < 2.0
			and main.orb_rust.get_rect().end.y <= main.orb_hp.get_rect().position.y,
		"rustningen ligger rakt ÖVER hälsan", "rust %s, hp %s" % [str(main.orb_rust.get_rect()),
			str(main.orb_hp.get_rect())])
	# HÄLSAN I BARENS VÄNSTERKANT, MANAN I DEN HÖGRA (M113). Paret hp/rust står lodrätt i vänsterkanten
	# och manan ensam i högerkanten innanför minikartan — samma höjd är inte längre ett krav (hp:s mitt
	# ligger en halv klot under parets mitt).
	check(main.orb_hp.get_rect().get_center().x < bar_ruta.get_center().x
			and main.orb_mana.get_rect().get_center().x > bar_ruta.get_center().x,
		"hälsan ligger i barens vänstra kant och manan i den högra",
		"hp %s, mana %s" % [str(main.orb_hp.get_rect()), str(main.orb_mana.get_rect())])
	# STORLEKEN ÄR EN ANDEL AV SPELVYN, INTE AV UTKYMMET RUNT DEN. Radien ska vara 0,11 * 270 = 30
	# spelpixlar gånger heltalsskalan, alltså samma andel av vyn i varje fönster.
	for st in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(941, 1018)]:
		root.size = st
		main.get_viewport().size = st
		main._placera_vy()
		await process_frame
		var s: float = main._vy_korg.scale.x
		# RADIEN UR REMSANS HÖJD (M113), i FÖNSTERpixlar: paret hp + rustning ska rymmas ovanpå
		# varandra, så radien blir (barhöjd - luft - kanter - mellanrum) / 4. Klotet ritas i skala 1
		# (ett 3x-skalat klot gav 186 px i en 150 px remsa), alltså räknas måttet i px rakt av.
		var barh: float = main._bar(Vector2(st)).size.y
		var radie_v: float = clampf((barh - 2.0 * 6.0 - 4.0 * float(HudOrb.KANT) - main.KÄRL_MELLAN) / 4.0, 10.0, 40.0)
		var väntad: float = 2.0 * (radie_v + float(HudOrb.KANT))
		check(absf(main.orb_hp.size.x - väntad) <= 1.0,
			"klotet räknas ur REMSANS höjd i %s (%.0f px remsa)" % [st, barh],
			"%.0f px mot väntat %.0f px" % [main.orb_hp.size.x, väntad])
		check(main.orb_hp.get_rect().end.y <= float(st.y) and main.orb_mana.get_rect().end.x <= float(st.x)
				and main.orb_rust.get_rect().position.y >= 0.0,
			"och alla tre ryms i %s" % st, "hp %s rust %s" % [str(main.orb_hp.get_rect()),
				str(main.orb_rust.get_rect())])
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	main._placera_vy()
	await process_frame
	# KÄRLEN SYNS ÄVEN UTAN STRID (M102). Alex: *"Det finns ju idag ingen hälso- eller manakula, var har
	# du gömt dem? Jag vill se dem hela tiden, inte bara vid strid"*. En gammal grind i `_visa_gui` gömde
	# mana och rustning så fort `active_combat == null`, alltså i hela gången mellan striderna — och den
	# körde EFTER `_hud_sätt`, som säger motsatsen (M75). Kontrollen stänger av striden och kör samma väg
	# spelet kör, så den fäller grinden om den kommer tillbaka.
	var sparat_combat = main.active_combat
	main.active_combat = null
	main._visa_gui(true)
	check(main.orb_hp.visible and main.orb_mana.visible and main.orb_rust.visible,
		"kärlen syns även när ingen strid pågår", "hp %s, mana %s, rust %s" % [
			str(main.orb_hp.visible), str(main.orb_mana.visible), str(main.orb_rust.visible)])
	main.active_combat = sparat_combat
	main._visa_gui(true)
	# SKAKNINGEN VID TRÄFF (M102) ska lägga sig: en kula som vinglar i en sekund ser trasig ut.
	main.orb_hp.skaka(1.0)
	var stöt: float = main.orb_hp.skak()
	await create_timer(0.35).timeout
	check(stöt > 0.9 and main.orb_hp.skak() < 0.05, "kärlet skakar av stöten och lägger sig",
		"%.2f -> %.2f" % [stöt, main.orb_hp.skak()])
	# MANAPOOLENS TAK (M80). Alex: *"Där det står 3/7, vad är det?"* — orben visade `run.base_mana + 4`,
	# ett HÅRDKODAT +4 som bara råkade stämma för en spelare med exakt +4 i startmana. Taket ska vara
	# stridens egen pool, samma tal som `Combat.start_turn` fyller till varje tur.
	check(main.active_combat != null, "striden finns när kärlen mäts")
	if main.active_combat != null:
		var s_i_strid: Dictionary = main._status_data(main.run.hp, true)
		var pool: int = main.active_combat.base_mana + main.active_combat.mana_bonus
		check(int(s_i_strid["mana_max"]) == pool,
			"manakärlets tak är stridens pool, inte ett hårdkodat +4",
			"%d mot %d" % [int(s_i_strid["mana_max"]), pool])
	# KLOTEN RÖR INTE VARANDRA (M111). Förut var frågan om de fick plats BREDVID varandra; nu ligger
	# hälsa och rustning ovanpå varandra i samma hörn, och då är avståndet i höjdled det som gäller.
	check(not main.orb_hp.get_rect().intersects(main.orb_rust.get_rect())
			and not main.orb_hp.get_rect().intersects(main.orb_mana.get_rect()),
		"ingen av de tre kloten ligger över en annan",
		"hp %s rust %s mana %s" % [str(main.orb_hp.get_rect()), str(main.orb_rust.get_rect()),
			str(main.orb_mana.get_rect())])
	# KROCKEN I FLERA FÖNSTER (M75, omgjord i M111). Felet Alex såg förut ("Den använda korthögen ligger
	# över mana") kom av att radien räknades ur utrymmet mellan panelerna. Nu räknas den ur vyn, och
	# provet mäter att kloten fortfarande ryms i fönstret och inte krockar med korthögarna — i fyra
	# storlekar, för vilken Alex använder går inte att gissa.
	var storlekar := [Vector2i(1280, 720), Vector2i(1896, 1030), Vector2i(1600, 900), Vector2i(1024, 768)]
	var krockar: Array = []
	var värde_utanför: Array = []
	for st in storlekar:
		root.size = st
		main.get_viewport().size = st
		main._placera_vy()
		await process_frame
		var vy_nu := Rect2(main._vy_korg.position, main._vy_korg.size * main._vy_korg.scale.x)
		var bar_nu: Rect2 = main._bar(Vector2(st))
		var par: Array = [["hp", main.orb_hp], ["mana", main.orb_mana], ["rust", main.orb_rust]]
		for i in par.size():
			var a: Rect2 = par[i][1].get_rect()
			# MITTEN, alltså själva värdet, måste ligga i REMSAN och hela klotet i fönstret (M113).
			# Det är skillnaden mellan ett klot som ryms och ett klot som inte syns alls.
			var mitten: Vector2 = a.get_center()
			if not bar_nu.has_point(mitten):
				värde_utanför.append("%s i %s har mitten utanför remsan (%s)" % [par[i][0], st, str(a)])
			if a.position.x < -1.0 or a.position.y < -1.0 or a.end.x > float(st.x) + 1.0 or a.end.y > float(st.y) + 1.0:
				värde_utanför.append("%s hamnar utanför fönstret i %s (%s)" % [par[i][0], st, str(a)])
			for j in range(i + 1, par.size()):
				var b: Rect2 = par[j][1].get_rect()
				if a.intersects(b) and a.intersection(b).get_area() > 1.0:
					krockar.append("%s mot %s i %s" % [par[i][0], par[j][0], st])
			for h in [main.hog_drag, main.hog_använd]:
				if h == null or not h.visible:
					continue
				var hr: Rect2 = h.get_rect()
				if a.intersects(hr) and a.intersection(hr).get_area() > 1.0:
					krockar.append("%s mot korthögen i %s" % [par[i][0], st])
	check(krockar.is_empty(),
		"hälsa, mana och rustning krockar inte med korthögarna eller varandra i någon av fyra storlekar",
		", ".join(krockar.slice(0, 4)))
	check(värde_utanför.is_empty(), "och varje klot ryms i REMSAN och i fönstret i alla fyra",
		", ".join(värde_utanför.slice(0, 4)))
	# ALEX' EGET FÖNSTER (941x1018). Här är vyn 480x270 i skala 1, mitt i ett HÖGT fönster, och det var
	# där den gamla räkningen klämde klotet till 20x20 px. Nu är klotet 2 * (30 + 4) * 1 = 68 px — den
	# gamla gränsen 100 px gäller inte längre, för den räknades mot MARGINALEN. Det som mäts är att
	# klotet har samma andel av VYN som i alla andra fönster, och att alla tre ryms.
	root.size = Vector2i(941, 1018)
	main.get_viewport().size = Vector2i(941, 1018)
	main._placera_vy()
	await process_frame
	var bar_alex: Rect2 = main._bar(Vector2(941, 1018))
	var radie_alex: float = clampf((bar_alex.size.y - 12.0 - 4.0 * float(HudOrb.KANT) - main.KÄRL_MELLAN) / 4.0, 10.0, 40.0)
	check(absf(main.orb_hp.size.x - 2.0 * (radie_alex + float(HudOrb.KANT))) <= 1.0,
		"klotet räknas ur REMSANS höjd i Alex' eget fönster",
		"%.0f px mot väntat %.0f px (remsan %.0f px)" % [main.orb_hp.size.x,
			2.0 * (radie_alex + float(HudOrb.KANT)), bar_alex.size.y])
	check(main.orb_hp.get_rect().end.y <= 1018.0 and main.orb_rust.get_rect().position.y >= 0.0
			and bar_alex.has_point(main.orb_hp.get_rect().get_center()),
		"och kloten ligger i REMSAN, innanför fönstret",
		"hp %s, rust %s" % [str(main.orb_hp.get_rect()), str(main.orb_rust.get_rect())])
	# Tillbaka till provets eget fönster: resten av provet mäter layouten i 1280x720.
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	main._placera_vy()
	await process_frame
	check(main.hud_status.vital_label.text.contains("HP"),
		"sifferraden står kvar i statusblocket", main.hud_status.vital_label.text)
	var max_hp: float = main.active_combat.max_hp
	main.active_combat.hp = max_hp * 0.5
	main._hud_sätt(main.active_combat.hp, true)
	await process_frame
	check(absf(main.orb_hp.nivå() - 0.5) < 0.01, "HP-kärlet är halvfullt när livet är halvt",
		"%.2f för %.0f/%.0f" % [main.orb_hp.nivå(), main.active_combat.hp, max_hp])
	check(main.hud_status.vital_label.text.contains("%.0f" % (max_hp * 0.5)),
		"och siffran i blocket säger samma sak", main.hud_status.vital_label.text)
	main.active_combat.hp = max_hp
	main._hud_sätt(max_hp, true)
	await process_frame
	check(main.orb_hp.nivå() > 0.99, "och fullt när livet är fullt", "%.2f" % main.orb_hp.nivå())
	# RUSTNINGSKLOTET följer sin EGEN pool (M103): ett klot som står still medan värdet ändras är en
	# siffra utan nivå. Provet sätter rustningen till halva taket och mäter att vätskan följer.
	var max_rust: float = main.run.armor_tak
	main.active_combat.armor = max_rust * 0.5
	main._hud_sätt(main.active_combat.hp, true)
	await process_frame
	check(absf(main.orb_rust.nivå() - 0.5) < 0.02, "rustningsklotet är halvfyllt när rustningen är halv",
		"%.2f för %.0f/%.0f" % [main.orb_rust.nivå(), main.active_combat.armor, max_rust])
	check(not main.orb_rust.text.contains("/")
		and main.orb_rust.text == "%d" % int(main.active_combat.armor),
		"och siffran i klotet är MÄNGDEN rustning, utan bråk (M119)", main.orb_rust.text)
	main.active_combat.armor = 0.0
	main._hud_sätt(main.active_combat.hp, true)
	await process_frame

	print("")
	# FIENDERUTAN FINNS INTE LÄNGRE (M68). Alex: *"Rutan där det står Candlewisp ... den är lite
	# överflödig"* och sedan ett rakt besked: *"nr 3 kan du ta bort, den är överflödig"*. Kvar av
	# målrutan är MÅLET — namnet loggen skriver och bilden som ska finnas i assets/enemies.
	print("— målet —")
	var d: Dictionary = main._fiende_data(true)
	print("      mål: %s %.0f/%.0f, bild %s" % [str(d.get("namn", "")), float(d.get("hp", 0.0)),
		float(d.get("max_hp", 0.0)), "ja" if d.get("textur", null) != null else "nej"])
	check(not d.is_empty(), "striden har ett mål att namnge i loggen")
	check(d.get("textur", null) != null, "målets bild är laddad ur assets/enemies",
		"assets/enemies/%s.png" % str(d.get("id", d.get("namn", "?"))))
	var namn: String = str(d.get("namn", ""))
	check(namn != "" and namn != "null", "målet har ett namn", namn)
	check(main._fiende_data(false).is_empty(), "utanför en strid finns ingen fiende att visa")

	print("")
	print("— kortvalet (level up) lägger sig fritt ovanför handen —")
	# Alex: *"När man får välja kort vid vinst/level up så verkar kortet flytta på sig till vänster, och
	# täcker över det som låg där innan, och går inte att flytta på."* Valkorten och handens kort ligger
	# båda i FÖNSTRETS yta (`_runt`), så rutorna jämförs som de är.
	# Mätt före rättningen: valets nederkant 630, handens överkant
	# 586 — 44 px överlapp, och det vänstra valkortet låg under ett handkort och stal klicket.
	check(main.hand_views.size() > 0, "handen har kort när valet kommer (annars mäter kontrollen inget)",
		"%d kort" % main.hand_views.size())
	main.run.xp = Progress.xp_total(main.run.level + 1)
	main.run._check_level()
	main._show_draft()
	await process_frame
	await process_frame
	check(main.draft_panel.visible, "valpanelen syns när ett val väntar")
	# VALET LIGGER I FÖNSTRETS YTA (`_runt`), som handens kort — rutan är redan i fönsterpx. Förut låg
	# valet i vyn och räknades om med `_vy.get_screen_transform()`.
	var vr := Rect2(main.draft_panel.global_position, main.draft_panel.size)
	print("      valpanelen i fönstret: %s" % str(vr))
	var handtopp := 9999.0
	var krock := 0.0
	for v in main.hand_views:
		if not is_instance_valid(v):
			continue
		var kr := Rect2(v.global_position, v.size * v.scale)          # redan i fönsterpx
		handtopp = minf(handtopp, kr.position.y)
		krock = maxf(krock, vr.intersection(kr).get_area())
	print("      handens överkant %.0f, valets nederkant %.0f, överlapp %.0f px" % [handtopp, vr.end.y, krock])
	# VALET SKA RYMMAS I FÖNSTRET. Sedan korten blev 80 % större ryms inte både kortet och rubriken
	# ovanför handen (vyn är 270 px, panelen står på 40 och handens kort börjar på 189) — därför mäts
	# det som spelaren faktiskt förlorar på: att valet hamnar utanför bild eller att klicket far fel.
	var skärm := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	check(skärm.encloses(vr), "valet ryms i fönstret", "%s i %s" % [str(vr), str(skärm)])
	# KLICKET, inte geometrin: Alex' fel (M34) var att valkortet låg UNDER ett handkort och stal
	# klicket. Handen viker nu undan medan valet står uppe (se main._show_draft), så inget SYNLIGT
	# handkort kan ligga över ett valkort — och klicket provas på riktigt: samma väg som en riktig mus
	# (pekaren flyttas och händelsen skickas till fönstret, inte till funktionen tangenten använder).
	var överlapp: CardView = null
	var bäst := 0.0
	var klickbar: CardView = null
	for barn in main.draft_box.get_children():
		if barn is not CardView:
			continue
		var r := Rect2(barn.global_position, barn.size * barn.scale)
		if r.intersection(vr).get_area() > 0.0:
			klickbar = barn as CardView
		for v in main.hand_views:
			if not is_instance_valid(v) or not v.is_visible_in_tree():
				continue
			var a := r.intersection(Rect2(v.global_position, v.size * v.scale)).get_area()
			if a > bäst:
				bäst = a
				överlapp = barn as CardView
	check(överlapp == null, "inget SYNLIGT handkort ligger över ett valkort", "%.0f px överlapp" % bäst)
	check(klickbar != null, "minst ett valkort ligger i vyn (annars mäter kontrollen inget)")
	# VALKORTEN SKA RYMMAS I VYN. Fyra kort i nästan full storlek behöver 616 px i en 480 px-vy, och
	# då klipptes det fjärde kortet av mot panelens kant (sett i granskningen: bara kostnadssiffran
	# syntes). Taket på valkortets skala räknar därför även på bredden.
	var utanför := 0
	for barn in main.draft_box.get_children():
		if barn is not CardView:
			continue
		var r2 := Rect2(barn.global_position, barn.size * barn.scale)
		if not skärm.encloses(r2):
			utanför += 1
	check(utanför == 0, "alla valkort ryms i fönstret", "%d kort utanför" % utanför)
	# DENSITETEN (Alex: "pixeltätheten på korten behöver dubbleras eller mer, för de är suddiga
	# idag"). Valet ritas i FÖNSTERPIXLAR: kortet är minst sin egen designstorlek, och panelen täcker
	# exakt vyns ruta. Förut krymptes kortet till 0,745 av designen i vyn och skalades upp 2x — texten
	# rastrerades på 5-7 px och förstorades, vilket är det som såg suddigt ut.
	var valskala: float = 0.0
	for barn in main.draft_box.get_children():
		if barn is CardView:
			valskala = (barn as CardView)._skala
			break
	check(valskala >= 1.0, "valkortet ritas i minst sin egen storlek (ingen uppskalning)",
		"skala %.2f" % valskala)
	# VYNS RUTA ÄR INTE LÄNGRE 480x270 (M113): formen följer fönstret, så panelen mäts mot korgens
	# EGNA mått — annars mäter provet en ruta som inte finns.
	var vy_ruta := Rect2(main._vy_korg.position, main._vy_korg.size * main._vy_korg.scale.x)
	check(vr.size == vy_ruta.size and vr.position == vy_ruta.position,
		"valet täcker vyns ruta i fönsterpixlar", "%s (vyn %s)" % [str(vr), str(vy_ruta)])
	# KONSTENS PIXLAR: ritas i hela steg, annars blir de olika breda (mätt i bild före rättningen:
	# block av 2, 3, 4 och 5 px om varandra).
	var provtextur := PlaceholderTexture2D.new()
	provtextur.size = Vector2(64, 64)
	var ikon := CardView.Ikon.new()
	ikon.textur = provtextur
	ikon.size = Vector2(180, 150)
	check(ikon.steg() == 2, "ikonens konst ritas i hela steg (2x av 64 px i en 180x150-ruta)",
		"steg %d" % ikon.steg())
	ikon.size = Vector2(20, 20)
	check(ikon.steg() == 0, "och skalas ned proportionellt när rutan är mindre än konsten",
		"steg %d" % ikon.steg())
	# SJÄLVA KLICKET mäts inte här: i det här provet (som startas med ett fönster och ett konstlat
	# val) når den simulerade musen inte fram till valkortet, medan SAMMA kod i `-- vinstprov` gör det
	# — där klickas ett valkort efter en riktig strid och valet går från 4 till 0. Att tvinga fram ett
	# grönt svar här hade varit att mäta sin egen koordinatmiss; klicket mäts i provet som spelar.

	## ELDEN PÅ DE LYSANDE REKVISITERNAS MODELL (M110). Alex: *"hade varut häftigt om själva 'elden' på
	## ljusen brann"*. MÄTT FÖRE: rekvisitens ljusenergi stod STILL (1,125 -> 1,125 över 40 bildrutor)
	## och 0 av 11 dekor-material hade emission — elden fanns bara i ljuset, inte på modellen.
	## Provet mäter MEKANISMEN: att glöden rör sig över tid, att den hålls SVAG (ett lager över hela
	## modellen lästes förut som en vit kopia — tak-kronan "är helvit typ"), och att ljuset rör sig med
	## samma faktor. I en rendering flyttade glöden modellens medelfärg (0,4595, 0,3378, 0,2268) ->
	## (0,4972, 0,3768, 0,2613) och antalet nästan-vita pixlar stod still (50 -> 50): varmare, inte vitare.
	print("")
	print("— elden på de lysande rekvisiterna —")
	check(not main._låg_material.is_empty(), "våningen har en lysande rekvisit att mäta",
		"%d arter, %d ljus" % [main._låg_material.size(), main._låg_ljus.size()])
	if not main._låg_material.is_empty():
		var art: String = main._låg_material.keys()[0]
		# MATERIALET KAN VARA TVÅ SLAG (M115). De lysande rekvisiterna bär nu en shader som bara släpper
		# igenom lågcellerna, och styrkan ligger i parametern `glod` i stället för i
		# `emission_energy_multiplier`. En typad `StandardMaterial3D` här fällde HELA provet ("Trying to
		# assign value of type 'ShaderMaterial'"), och efter det körde ingenting: sviten stannade på
		# exit 124 (timeout) UTAN en FEL-rad — 174 kontroller försvann tyst.
		var eld = main._låg_material[art]
		var eld_shader: ShaderMaterial = eld as ShaderMaterial
		check(eld_shader != null and eld_shader.shader != null
				and eld_shader.shader.resource_path.ends_with("voxel_rekvisit.gdshader"),
			"modellens glöd är låg-shadern, inte ett material över hela modellen (%s)" % art)
		var lägst := 1e9
		var högst := -1e9
		var ljus_lägst := 1e9
		var ljus_högst := -1e9
		for i in 45:
			await process_frame
			var glod := 0.0
			if eld_shader != null:
				var v = eld_shader.get_shader_parameter("glod")
				if v != null:
					glod = float(v)
			lägst = minf(lägst, glod)
			högst = maxf(högst, glod)
			if not main._låg_ljus.is_empty():
				ljus_lägst = minf(ljus_lägst, (main._låg_ljus[0] as OmniLight3D).light_energy)
				ljus_högst = maxf(ljus_högst, (main._låg_ljus[0] as OmniLight3D).light_energy)
		check(högst - lägst > 0.005, "glöden FLADDRAR — den rör sig över tid",
			"%.4f..%.4f" % [lägst, högst])
		# TAKET: glöden är med flit svag. Ett lager kring 1,0 över hela modellen ÄR den vita kopia
		# som läxan handlar om, och det ska fällas här och inte av att en tak-krona ser blek ut.
		check(högst < 0.35, "men hålls SVAG (inget vitt lager över modellen)", "tak %.3f" % högst)
		if not main._låg_ljus.is_empty():
			check(ljus_högst - ljus_lägst > 0.01,
				"och rekvisitens LJUS fladdrar med — det stod still förut",
				"%.4f..%.4f (bas %.4f)" % [ljus_lägst, ljus_högst, main.LAGA_ENERGI * 0.6 * main._ljus_f])

	print("")
	print("— loggen —")
	check(main.hud_logg != null and main.hud_logg.visible, "loggen syns")
	main.hud_logg.töm()
	main._logga("första", Palett.c(11))
	main._logga("andra", Palett.c(14))
	await process_frame
	check(main.hud_logg.innehåll() == ["första", "andra"], "raderna kommer i ordning",
		str(main.hud_logg.innehåll()))
	for i in HudLogg.RADER + 2:
		main._logga("rad %d" % i, Palett.c(23))
	await process_frame
	var inne: Array = main.hud_logg.innehåll()
	check(inne.size() == HudLogg.RADER, "loggen håller bara sina rader (ringen)", "%d rader" % inne.size())
	check(str(inne[inne.size() - 1]) == "rad %d" % (HudLogg.RADER + 1), "den NYASTE raden står sist",
		str(inne[inne.size() - 1]))
	check(not str(inne[0]).begins_with("första"), "den äldsta raden har fallit ut", str(inne[0]))
	main.hud_logg.töm()
	## VAPNET SVINGER PÅ SKÄRMEN (M110). Alex: *"sen behöver vi se till att få vapnen att svingas när
	## man attackerar på skärmen med"*. Kortets EGEN bild (`_card_icon`) far genom bilden som en kvad på
	## kameran. Provet mäter det som skiljer ett sving från ett spöke: att det BARA kommer ur ett SPELAT
	## kort (hover och handens omläggning får aldrig starta ett), att det ritar kortets bild, och att
	## det tonar bort och städar sig själv.
	print("")
	print("— vapnet svingar på skärmen —")
	check(main.get_tree().get_nodes_in_group("vapensving").is_empty(),
		"ingen sving finns innan något kort spelats",
		"%d sving" % main.get_tree().get_nodes_in_group("vapensving").size())
	if main.hand_views.size() > 0 and is_instance_valid(main.hand_views[0]):
		main.hand_views[0].set_forward(true)   # hovringen: den får ALDRIG starta ett sving
		await process_frame
		check(main.get_tree().get_nodes_in_group("vapensving").is_empty(),
			"hovringen över ett kort startar inget sving",
			"%d sving" % main.get_tree().get_nodes_in_group("vapensving").size())
		main.hand_views[0].set_forward(false)
		await process_frame
	# Mana så att kortet GÅR att spela: svinget kommer ur den lyckade spelvägen, och ett kort som inte
	# får plats mäter ingenting.
	if main.active_combat != null:
		main.active_combat.mana = 99
	var spelat_id := ""
	var spelat_kort: Cards.Card = null
	if main.active_combat != null and not main.active_combat.hand.is_empty():
		spelat_kort = main.active_combat.hand[main._hand_index(0)]
		spelat_id = str(spelat_kort.id)
	# SVINGET MÄTS NÄR DET LÄGGS I TRÄDET, inte efteråt. En strid som tar slut i samma bildruta bygger
	# om världen (`_after_state_change` -> `_build_world`), och då dör kameran och kvaden med den —
	# mätt: kamerans id byttes i samma bildruta som kortet spelades, och gruppen var tom efteråt.
	# `node_added` fångar noden i den stund den kopplas in, medan den ännu lever.
	var sedd: Array = []
	var tittare := func(n: Node) -> void:
		var mi := n as MeshInstance3D
		if mi == null or not (mi.mesh is QuadMesh) or mi.get_parent() != main.cam:
			return
		var mm := mi.material_override as StandardMaterial3D
		if mm == null or mm.albedo_texture == null:
			return
		sedd.append({
			"ikon": mm.albedo_texture == main._card_icon(spelat_id),
		})
	main.get_tree().node_added.connect(tittare)
	await main._on_card(0)
	main.get_tree().node_added.disconnect(tittare)
	await process_frame
	print("      efter ett spelat kort: %s" % str(main.hud_logg.innehåll()))
	check(not main.hud_logg.innehåll().is_empty(), "ett spelat kort ger en loggrad")
	check(sedd.size() == 1, "men ett SPELAT kort lägger ett sving på kameran",
		"%d sving (%s)" % [sedd.size(), spelat_id])
	if sedd.size() == 1:
		check(bool(sedd[0]["ikon"]),
			"svinget ritar kortets EGEN bild — ingen ny konst")
	# SJÄLVSTÄDNINGEN mäts på en kamera som INTE byggs om under tiden: svepet läggs på nytt och ska vara
	# borta av sig självt efter sin tid (en kvad kvar i bilden är ett spöke). Antalet JÄMFÖRS med läget
	# före: tar striden slut i samma bildruta byggs världen om och det första svepet dör med kameran,
	# medan ett levande kamera har det kvar — båda är rätt, och provet ska inte hänga på vilket.
	if spelat_kort != null and main.cam != null:
		var före_antal := main.get_tree().get_nodes_in_group("vapensving").size()
		main._vapensving(spelat_kort)
		await process_frame
		check(main.get_tree().get_nodes_in_group("vapensving").size() == före_antal + 1,
			"svepet lever sin tid på skärmen",
			"%d mot %d före" % [main.get_tree().get_nodes_in_group("vapensving").size(), före_antal])
		await create_timer(main.SVING_TID + 0.5).timeout
		check(main.get_tree().get_nodes_in_group("vapensving").is_empty(),
			"och städar sig självt — ingen kvad blir kvar",
			"%d kvar" % main.get_tree().get_nodes_in_group("vapensving").size())
	# HANDEN BYGGS OM: samma väg spelet tar efter en tur — den får inte heller lämna ett sving efter sig.
	main._refresh_hand()
	main._refresh_battle()
	await process_frame
	check(main.get_tree().get_nodes_in_group("vapensving").is_empty(),
		"och ett varv med omlagd hand startar inget sving",
		"%d sving" % main.get_tree().get_nodes_in_group("vapensving").size())

	print("")
	print("— läget (mäts bara med ett fönster som rymmer vyn) —")
	if not måttbart():
		print("      hoppar över: fönstret är %.0fx%.0f och rymmer inte spelvyn (%s) — mäts i -- guiprov"
			% [fönster.x, fönster.y, str(vy)])
	else:
		var s := ruta(main.hud_status)
		var l := ruta(main.hud_logg)
		print("      status %s | logg %s" % [str(s), str(l)])
		# REMSAN (M113): både statusblocket och loggen ligger i baren UNDER spelvyn, och loggen i
		# barens högra del. Ingen av dem ritar inne i vyn.
		check(s.position.y >= vy.end.y, "statusblocket ligger i REMSAN under spelvyn",
			"överkant %.0f mot vyns underkant %.0f" % [s.position.y, vy.end.y])
		check(l.position.y >= vy.end.y, "loggen ligger i REMSAN under spelvyn")
		check(l.get_center().x >= fönster.x * 0.5, "och i remsans högra halva",
			"mitt %.0f av %.0f" % [l.get_center().x, fönster.x])
		for n in [main.hud_status, main.hud_logg]:
			check(not överlappar(ruta(n), vy), "%s ritar ingenting inne i spelvyn" % n.name)
		# Korten äger mitten nedtill: ingen ruta får ligga över handen.
		for v in main.hand_views:
			var k := ruta(v)
			check(not överlappar(k, l), "kortet %d krockar inte med loggen" % v.index)

	## SLUTSKÄRMEN (M48): bara dödade fiender och guld — och sedan tillbaka till byn. Butikslistan
	## hör till byn. Alex: *"Här skall man bara få information om hur många man dödat, hur mycket
	## guld man fick in, och sen tillbaka till byn."* Provet mäter TEXTEN, för det var texten han
	## pekade på i skärmdumpen. Sist i provet: körningen markeras som slut och sätts tillbaka efter.
	print("")
	print("— slutskärmen —")
	main.run.kills = 7
	main.run.gold = 123
	# `finished` rörs INTE: flaggan startar slutskärmens egen väg genom spelet, och provet skulle
	# hamna i en väntan på en bildruta som aldrig kommer (mätt: exit 124). Texten byggs direkt.
	main._unlocked_now = ""
	var slut: String = main._end_text()
	check(slut.contains("7 fiender dödade") and slut.contains("123 guld"),
		"slutskärmen visar dödade fiender och guld in", slut.replace("\n", " | "))
	check(not slut.contains("guld i banken"),
		"slutskärmen visar inte butikslistan", slut.replace("\n", " | "))
	check(slut.contains("tillbaka till byn"), "slutskärmen visar vägen tillbaka till byn",
		slut.replace("\n", " | "))

	## SALDOT (M61). Alex: *"Ingenstans visas det hur mycket gold man har, så det är omöjligt att veta
	## om man har råd eller ej."* Raden fanns i koden och fylldes med rätt text — men etiketten var
	## `visible = false` och sattes aldrig på, så den syntes i ingen skärm (mätt: byn hade ingen text
	## om guld alls). Provet mäter därför SYNLIGHETEN, talet mot metat, och att raden inte ligger över
	## en panel som redan bär saldot i sin egen rubrik.
	print("")
	print("— saldot —")
	# KÖPET GENOM TANGENTEN (Alex: *"det går inte att köra något där, trots att jag har tillräckligt
	# med guld"*). Provet trycker "1" i butiksläget och kräver att banken SJUNKER med radens pris och
	# att rangen stiger — annars ser spelaren bara en rad som säger OK och ingenting händer.
	main.shell = "butik"
	main.meta.add_gold(9000)      # blocken köper efter varandra: utan påfyllning blir en rad för dyr
	main._refresh_shell()
	var köpbar := -1
	for i in main.meta.village_lines().size():
		if int(main.meta.village_lines()[i]["cost"]) > 0:
			köpbar = i
			break
	var butiksrad: Dictionary = main.meta.village_lines()[köpbar]
	var guld_före: int = main.meta.gold
	var rang_före: int = main.meta.rank(str(butiksrad["id"]))
	main._input_shell(KEY_1 + köpbar)
	var rad_efter: Dictionary = main.meta.village_lines()[köpbar]
	check(main.meta.gold == guld_före - int(butiksrad["cost"]),
		"butiken drar radens pris ur banken (%d -> %d, pris %d)" % [guld_före, main.meta.gold, int(butiksrad["cost"])],
		"rangen %d -> %d, panelen säger %s" % [rang_före, main.meta.rank(str(butiksrad["id"])),
			str(rad_efter.get("rank", "?"))])
	check(main.meta.rank(str(butiksrad["id"])) == rang_före + 1, "och rangen stiger ett steg")
	# SAMMA PANEL, SMEDENS SHOP-LÄGE (M95). Byns butiksrader visas där också, men siffrorna gick till
	# TRÄDET — vars köp returnerar direkt när smedspanelen inte syns. Alex: *"det går inte att köra
	# något där, trots att jag har tillräckligt med guld"*: raden sade OK och ingenting hände.
	main.shell = "smed"
	main._smed_läge = "shop"
	main._refresh_shell()
	var köpbar2 := -1
	for i in main.meta.village_lines().size():
		if int(main.meta.village_lines()[i]["cost"]) > 0:
			köpbar2 = i
			break
	var rad2: Dictionary = main.meta.village_lines()[köpbar2]
	var guld2: int = main.meta.gold
	var rang2: int = main.meta.rank(str(rad2["id"]))
	main._input_shell(KEY_1 + köpbar2)
	check(main.meta.gold == guld2 - int(rad2["cost"]) and main.meta.rank(str(rad2["id"])) == rang2 + 1,
		"smedens shop-läge köper butiksraden, inte trädnoden (%d -> %d, rang %d -> %d)"
		% [guld2, main.meta.gold, rang2, main.meta.rank(str(rad2["id"]))])
	# KLICKYTORNA (önskemål 28): varje rad ska vara ett OBJEKT man trycker på, och trycket ska göra
	# exakt samma köp som siffran. Provet mäter både att ytorna ligger över sina rader och att ett
	# tryck betalar.
	main.shell = "butik"
	main._refresh_shell()
	var klickytor := main.get_tree().get_nodes_in_group("butik_rad")
	check(klickytor.size() == main.meta.village_lines().size(),
		"varje butiksrad har en klickbar yta (%d ytor mot %d rader)"
		% [klickytor.size(), main.meta.village_lines().size()])
	# VARAN ÄR ETT OBJEKT: knappen bär namn, rang, pris, märket och vad den gör — och en ruta att
	# trycka på (egen stil, inte en tom yta). En rad vars text saknar priset är inte en vara.
	var fel_varor: Array = []
	for i in klickytor.size():
		var k := klickytor[i] as Button
		var v: Dictionary = main.meta.village_lines()[i]
		# En fullt utvecklad vara (priset är slut) bär FULL utan märke: X betyder "har inte råd".
		var märke := "FULL" if int(v["cost"]) < 0 else ("OK" if bool(v["affordable"]) else "X")
		if not k.text.contains(str(v["name"])) or not k.text.contains(str(v["text"])) \
				or not k.text.contains(märke) or k.text.split("\n").size() < 3:
			fel_varor.append("%s: %s" % [v["name"], k.text.replace("\n", " / ")])
		if not (k.get_theme_stylebox("normal") is StyleBoxFlat):
			fel_varor.append("%s saknar ruta" % v["name"])
	check(fel_varor.is_empty(), "varje vara är ett objekt med namn, rang, pris, märke och ruta (%d fel)"
		% fel_varor.size(), " | ".join(fel_varor.slice(0, 2)))
	# RYMS DE I VYN? Panelen mäts mot sin bredaste vara, och en vara som sticker ut är text spelaren
	# aldrig ser. Måttet jämförs med SPELVYN i canvas-enheter (480x270) — panelen är centrerad, så
	# positioner i canvas-rymden säger ingenting om huruvida den ryms.
	check(main.butik_panel.size.x <= 480.0 and main.butik_panel.size.y <= 270.0,
		"butikspanelen ryms i spelvyn (%s)" % str(main.butik_panel.size))
	var bredaste := 0.0
	for y in klickytor:
		bredaste = maxf(bredaste, (y as Button).size.x)
	check(bredaste <= 424.0, "ingen vara är bredare än panelens tak (%.0f px av 424)" % bredaste)
	# OCH RUTNÄTET MÅSTE RYMMAS I PANELEN: ett rutnät som är bredare än panelen ritar utanför kanten,
	# och då ser spelaren en halv vara (mätt innan placeringen flyttades efter ramen: 418 mot 385).
	check(main.butik_rader.size.x <= main.butik_panel.size.x + 0.5,
		"rutnätet ryms i panelen (%.0f mot %.0f)" % [main.butik_rader.size.x, main.butik_panel.size.x])
	check(main.butik_label.text.split("\n").size() == 2,
		"rubriken bär bara titel och tips, varorna står som objekt under (%d rader)"
		% main.butik_label.text.split("\n").size())
	# Raden som trycks måste vara KÖPBAR (tidigare steg i provet har redan köpt de första): en
	# fullt utvecklad rad kostar -1 och nekas med rätta.
	var vald := -1
	for i in main.meta.village_lines().size():
		if int(main.meta.village_lines()[i]["cost"]) > 0:
			vald = i
			break
	var guld_klick: int = main.meta.gold
	var rad3: Dictionary = main.meta.village_lines()[vald]
	var rang3: int = main.meta.rank(str(rad3["id"]))
	(klickytor[vald] as Button).pressed.emit()
	check(main.meta.gold == guld_klick - int(rad3["cost"]) and main.meta.rank(str(rad3["id"])) == rang3 + 1,
		"ett tryck på raden köper den (%d -> %d, rang %d -> %d)"
		% [guld_klick, main.meta.gold, rang3, main.meta.rank(str(rad3["id"]))],
		"rad %d %s kostar %d, räcker %s, knappens text: %s"
		% [vald, str(rad3["id"]), int(rad3["cost"]), str(main.meta.gold >= int(rad3["cost"])),
			(klickytor[vald] as Button).text.replace("\n", " / ")])
	check((klickytor[2] as Button).focus_mode == Control.FOCUS_NONE,
		"och klickytan tar inte tangentbordet (annars slutar siffrorna fungera)")
	main.shell = "hem"
	main._refresh_shell()
	var saldo: String = main.top_label.text
	check(main.top_label.visible, "saldot SYNS i byn (den var osynlig förut)")
	check(saldo.contains(str(main.meta.gold)), "och raden säger samma guld som metat", saldo)
	check(saldo.contains(str(main.meta.shards)), "…och samma splitter", saldo)
	# VALUTARADEN SYNS ÖVERALLT UTOM I KÖRNINGEN (M95, Alex: *"Guld, Splitter och andra valutor inte
	# visas. Det måste de."*). Den låg förut bara på hem/karta/album — alltså var den borta i butiken,
	# i världshuset, hos smeden och hos juveleraren: exakt de skärmar där man handlar.
	main.shell = "smed"
	main._refresh_shell()
	check(main.top_label.visible, "saldot syns även hos smeden")
	main.shell = "juvelerare"
	main._refresh_shell()
	check(main.top_label.visible, "och hos juveleraren")
	main.shell = "trad"
	main._refresh_shell()
	check(main.top_label.visible, "och i trädet")
	check(main.top_label.text.contains("CS"), "och raden visar CS också", main.top_label.text)
	# ESC TILLBAKA TILL BYN FRÅN VARJE SKÄRM (M95). Alex: *"Varje del måste gå att backa ur tillbaka
	# till byn med antingen en knapp för exit, eller med esc-knappen."* Provet går igenom skalets
	# alla lägen i stället för att lita på att någon lade in en gren per skärm — det är precis den
	# sortens glömska som gör en skärm till en återvändsgränd. Körningen är undantagen (ESC = meny).
	var utan_väg_tillbaka := []
	for läge in main.SKAL_LÄGEN:
		main.shell = str(läge)
		main._refresh_shell()
		main._input_shell(KEY_ESCAPE)
		if main.shell != "hem" and str(läge) != "körning":
			utan_väg_tillbaka.append(str(läge))
	check(utan_väg_tillbaka.is_empty(), "ESC leder tillbaka till byn från varje skärm",
		"fastnade i: %s" % str(utan_väg_tillbaka))
	# TRÄDETS RUTNÄT HAR FLER ÄN EN RAD (M95). Alex' skärmbild visade fjorton ikoner på EN rad högst
	# upp i en svart ruta: vyn ärvde PanelContainer, och en Container äger sin storlek — den krympte
	# till sitt innehåll och struntade i den size skalet satte, så rutnätet fick ingen bredd. Nu mäts
	# det i stället för att tros: ikonernas globala rutor skall spänna över både höjd och bredd.
	# Vyns form mäts, inte ikonernas pixelpositioner: containrar lägger ut sina barn först i nästa
	# bildruta, och provet kör i samma. Det som avgör om rutnätet får en bredd är VILKEN KLASS vyn
	# är — en Container äger sin storlek och krympte till en rad, en Control tar den size skalet ger.
	main.shell = "trad"
	main._refresh_shell()
	check(not (main.trad_view is PanelContainer),
		"trädvyn är en Control (en Container äger sin storlek och krympte rutnätet till en rad)")
	# Socketfilen kan vara TOM (den nollas när trädet byter form) — det som skall hålla är att vyn
	# läser den och att varje nod ändå hamnar någonstans: socketdatan är ett komplement till rutnätet.
	check(main.trad_view._snäpp is Dictionary, "socketdatan är läst (filen får vara tom)")
	check(not main.trad_view.has_method("_platta") and main.trad_view.get("_platta") == null,
		"trädvyn har INGEN bakgrundsbild (M97: ett vanligt nodträd, bilden kommer senare)")
	check(main.trad_view._nodplan is Control and not (main.trad_view._nodplan is Container),
		"noderna ligger på en fri yta, inte i en container (platsen är trädrymdens, inte en rad)")
	# VARJE NOD HAR EN PLATS I TRÄDRYMMEN (M96), och vyn ritar just den platsen. Kontrollen hette förut
	# "noden ligger inne i vyn" och höll bara så länge trädet rymdes på plattan — trädet är byggt för
	# att växa förbi den. Egenskapen som skall hålla är mappningen, inte skärmkanten.
	var ytor := {}
	for tnid in main.trad_view._ikoner:
		var tnod: Control = main.trad_view._ikoner[tnid]
		var trad_rad: Dictionary = main.trad_view._rader[tnid]
		var post: Dictionary = main.trad_view._snäpp.get(tnid, {})
		var väntad: Vector2 = main.trad_view._ur_bild(float(post.get("x", 0.0)), float(post.get("y", 0.0)))
		var mitt: Vector2 = tnod.position + tnod.size * 0.5
		check(post.has("x") and mitt.distance_to(väntad) < 0.5,
			"noden %s ritas där trädrymden säger" % tnid, "%s mot %s" % [mitt, väntad])
		ytor[int(trad_rad.get("nivå", 0))] = tnod.position.y
	# NIVÅERNA RÄKNAS UR DATAT (M96), inte ur ett fast tal: "elva nivåer" stod här och faller nästa
	# gång en nod läggs till — vilket är precis vad trädet är byggt för.
	var nivåer := {}
	for datad in main.meta.defs:
		if not str(datad.get("branch", "")).is_empty():
			nivåer[int(datad.get("tier", 0))] = true
	check(ytor.size() == nivåer.size(), "varje nivå i datat har noder i vyn",
		"%d i vyn av %d i datat" % [ytor.size(), nivåer.size()])
	# ARMEN LÄSES UTÅT, MÄTT PÅ HUVUDNODERNA: grenens huvudnod är armens start och skall ligga närmast
	# spiralens mitt (0,5 / 0,5). Radordningen ("ovanför") gällde när formen var kolumner och rader
	# (M97); spiralen (M100) mäter samma sak i radie. Noderna mäts i trädrymden, inte på skärmen.
	for id in main.trad_view._ikoner:
		if not str(id).ends_with("_main"):
			continue
		var gren: String = str(main.trad_view._rader[id].get("gren", ""))
		var egen: float = (Vector2(float(main.trad_view._snäpp[id].get("x", 0.5)),
			float(main.trad_view._snäpp[id].get("y", 0.5))) - Vector2(0.5, 0.5)).length()
		var längst := 0.0
		for annat in main.trad_view._rader:
			var rad: Dictionary = main.trad_view._rader[annat]
			if str(rad.get("gren", "")) != gren:
				continue
			var post: Dictionary = main.trad_view._snäpp.get(annat, {})
			if not post.has("x"):
				continue
			längst = maxf(längst, (Vector2(float(post["x"]), float(post["y"])) - Vector2(0.5, 0.5)).length())
		check(egen < längst, "huvudnoden i %s ligger närmast spiralens mitt" % gren,
			"%.2f mot %.2f andelar" % [egen, längst])
	check(main.trad_view._ikoner.size() > 0, "och ikonerna hamnade i dem",
		"%d ikoner" % main.trad_view._ikoner.size())
	# Ingen kontroll för flaggan -- skarm=<namn>: den läser SKAL_LÄGEN nu, och att kontrollera att en
	# lista innehåller sig själv är ingen kontroll. Felet den avskaffade var att listan fanns i två
	# exemplar, varav det ena glömde trädet.
	# Provet lämnar skalet i byn igen: nästa kontroll mäter juvelerarpanelen i spelvyn, och stod
	# skalet kvar i ett annat läge mättes fel skärm (panelen var 884 px i en 480 px vy).
	main.shell = "hem"
	main._refresh_shell()
	# JUVELERAREN (M58) ryms i vyn. Texten växte från sex rader till nio när facken och fickan byggdes
	# ut, men panelen centreras i spelvyn — blev den högre än 270 px klipptes rubriken (guld och fack)
	# i överkant och kortraden i underkant. Mätt på Alex' skärmbild 23 sep. Måttet står här så en
	# framtida rad i panelen inte tyst knuffar ut texten igen.
	# VILKEN RAD SOM ÄR FÖR BRED (M104). Panelen mättes förr bara som en ruta, och felet syntes som
	# "panelen är 544 px" utan att någon rad pekades ut. Här mäts VARJE rad med samma font som ritar
	# den, så provet säger vilken rad som sprack — den bredaste raden är den som knuffar ut panelen.
	var radbredd := []
	var typsnitt := ThemeDB.fallback_font
	var radstorlek := 16
	for rad in main.jewel_label.text.split("\n"):
		radbredd.append([typsnitt.get_string_size(str(rad), HORIZONTAL_ALIGNMENT_LEFT, -1, radstorlek).x, str(rad)])
	radbredd.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	print("    juvelerarens bredaste rader: %s" % str(radbredd.slice(0, 3)))
	check(float(radbredd[0][0]) <= float(main.VY.x),
		"ingen rad i juvelerarpanelen är bredare än vyn",
		"%.0f px mot %.0f: '%s'" % [float(radbredd[0][0]), main.VY.x, radbredd[0][1]])
	# PANELENS BARN, inte bara texten: en rad mäts ur sin font, men en CONTAINER mäts ur sina barn —
	# och det var containern som var bred (texten var som mest 343 px i en 480 px vy).
	var barninfo := []
	for b in main.jewel_panel.get_children():
		barninfo.append("%s %s" % [b.get_class(), str((b as Control).size)])
	print("    juvelerarens barn: box %s (min %s, %d kort) | %s" % [
		str(main.jewel_box.size), str(main.jewel_box.custom_minimum_size),
		main.jewel_box.get_child_count(), ", ".join(barninfo)])
	var jr: Rect2 = Rect2(main.jewel_panel.position, main.jewel_panel.size)
	print("    juveleraren: panelen %.0fx%.0f px, y %.0f..%.0f, vyn är %.0f hög (%.0fx%.0f)"
		% [jr.size.x, jr.size.y, jr.position.y, jr.end.y, main._vy_mått().y,
			main._vy_mått().x, main._vy_mått().y])
	# VYNS MÅTT ÄR INTE LÄNGRE 480x270 (M113): panelen är placerad i fönsterpixlar på korgens ruta,
	# så provet mäter mot vyns VERKLIGA ruta (annars mäter det en ruta som inte finns).
	var vy_px := Rect2(main._vy_korg.position, main._vy_korg.size * main._vy_korg.scale.x)
	check(jr.position.y >= vy_px.position.y - 0.5 and jr.end.y <= vy_px.end.y + 0.5,
		"juvelerarpanelen ryms i spelvyn i höjd", "y %.0f..%.0f av %.0f..%.0f" % [jr.position.y, jr.end.y,
			vy_px.position.y, vy_px.end.y])
	check(jr.position.x >= vy_px.position.x - 0.5 and jr.end.x <= vy_px.end.x + 0.5,
		"och i sidled (tipsraden var 1236 px på en rad)", "x %.0f..%.0f av %.0f..%.0f" % [jr.position.x, jr.end.x,
			vy_px.position.x, vy_px.end.x])
	# THE BENCH (23 Sep): Alex drew a plank surface and wants the shop's cards to lie on it. The
	# texture is loaded from disk at startup, so a missing or unimported PNG would leave a silent
	# black panel — the exact failure mode this checks. Godot only sees a new PNG after `--import`.
	var bench: Texture2D = load(main.BENCH_TEXTURE) as Texture2D
	check(bench != null and bench.get_width() > 0, "the bench texture loads from disk",
		"%s (%dx%d)" % [main.BENCH_TEXTURE, 0 if bench == null else bench.get_width(),
			0 if bench == null else bench.get_height()])
	check(main._bench_style().texture == bench, "and the shop panel draws it (StyleBoxTexture)")
	main.shell = "karta"
	main._refresh_shell()
	check(main.top_label.visible, "på kartan syns den igen (ingen panel där)")

	# RÅDFRÅGAN (M61): priset stod där förut, men svaret fanns bara att få genom att jämföra talet med
	# saldot högst upp. Nu står ✓ eller ✗ bredvid priset, räknat ur samma `affordable` som köpet.
	# M61:s rad flyttade med trädet (M95): svaret står i vyns hovringstext i stället för i en
	# textlista hos smeden, och priset är CS — trädet köps inte för guld.
	main.meta.gold = 0
	main.meta.shards = 0
	main.meta.souls = 0
	# HUVUDNODEN KÖPT (M95): undernoderna öppnas av den, och priset står bara på en nod som går att köpa.
	main.meta.ranks["iron_main"] = 1
	main.shell = "trad"
	main._refresh_shell()
	main.trad_view._peka("iron_1")
	var utan: String = main.trad_view._info.text
	check(utan.contains("✗"), "utan CS står ett kryss vid priset", utan)
	main.meta.souls = 100000
	main._refresh_shell()
	main.trad_view._peka("iron_1")
	var med: String = main.trad_view._info.text
	check(med.contains("✓"), "med CS står en bock vid priset", med)
	check(med.contains("CS"), "och priset står i CS, inte i guld", med)
	main.meta.souls = 0
	main.meta.gold = 0
	main.meta.shards = 0
	main.shell = "hem"
	main._refresh_shell()

	## SPADEN EFTER STRIDEN (M109). Alex: *"gör spaden synlig efter fighten, samt att gungandet med
	## texten, gör det så den åker upp och ner, över spaden när spaden är synlig."*
	##
	## MÄTT FÖRE ÄNDRINGEN (det här provet + `-- grävprov`): spaden RITADES hela tiden — `visible ja`
	## både med bossen levande och efter striden — och det som gömdes var SKYLTEN, vars grind var
	## klickregeln `_spade_redo()`: den kräver att spelaren står PÅ eller INVID spadens ruta. Varken
	## spadnodens `cleared`-flagga eller bossens status gjorde spaden osynlig; `_build_world` byggde
	## den så länge spadnoden var oklarad, alltså även med bossen levande (i bossbilden läses den som
	## ett föremål bossen håller i). Nu ritas spaden först när bossen på rutan är besegrad.
	print("")
	print("— spaden efter striden —")
	var spade: Dungeon.FloorNode = null
	var bossen: Dungeon.FloorNode = null
	for n in main.run.explore.floor_ref.nodes:
		if n.kind == "shovel" and spade == null:
			spade = n
		elif n.kind == "boss" and bossen == null:
			bossen = n
	check(spade != null and bossen != null, "våningen har både en spade och en boss")
	check(bossen.pos == spade.pos, "spaden ligger på bossens ruta", str(spade.pos))
	var granne: Vector2i = spade.pos + Vector2i(0, 1)
	if not main.run.explore.floor_ref.is_floor_at(granne):
		granne = spade.pos + Vector2i(-1, 0)
	main.run.explore.pos = granne
	main.run.explore.face(spade.pos)
	# MED BOSSEN LEVANDE byggs ingen spade alls: den är hennes byte och ritas först när hon fallit.
	if not bossen.cleared:
		main._build_world()
		await process_frame
		check(main._spade_sprite == null and main._spade_skylt == null,
			"med bossen levande är spaden inte byggd — den låg förut inne i figuren")
		check(not main._skylt_syns(), "och skylten syns inte")
		# Bossen besegras SAMMA väg som striden tar: `enter_node` startar striden, `auto_play`
		# slåss klart, `finish_fight` räknar in resultatet — sedan byggs våningen om som spelet gör.
		var c = main.run.enter_node(bossen)
		if c != null:
			c.hp = 5000.0
			c.max_hp = 5000.0
			var varv := 0
			while not c.over() and varv < 200:
				varv += 1
				c.auto_play()
				if not c.over():
					c.end_turn()
			main.run.finish_fight(bossen, c)
			for i in 12:
				if not main._draft_pending():
					break
				main._on_draft_pick(0)
				await process_frame
	else:
		print("    bossen var redan besegrad av provets egen strid — före-mätningen hoppas över")
	main._after_state_change()
	await process_frame
	await process_frame
	var spr: Sprite3D = main._spade_sprite
	check(spr != null and is_instance_valid(spr) and spr.get_parent() == main.world,
		"efter striden är spaden byggd och står i världen")
	check(spr != null and spr.visible and spr.is_visible_in_tree(),
		"och den SYNS — det var hela kravet: spaden synlig efter fighten")
	check(spr != null and main.cam != null and main.cam.is_position_in_frustum(spr.global_position),
		"spaden står i kameran från rutan intill", str(main._spade_på_bild()))
	check(main._spade_redo(), "och klickregeln är orörd: spaden får tas från rutan intill",
		"ledtråd: \"%s\"" % main.hint_label.text)
	# KLICKREGELN SKA INTE HA RÖRTS: står spelaren långt bort får spaden fortfarande inte tas.
	main.run.explore.pos = main.run.explore.floor_ref.start
	main._refresh()
	check(not main._spade_redo(), "på andra sidan våningen får spaden fortfarande inte tas")
	# SKYLTEN SYNS SÅ LÄNGE SPADEN SYNS (M109) — inte bara från rutan intill, som förut.
	check(main._skylt_syns(), "men skylten syns ändå: den visar VAR, klicket säger NÄR")
	var skylt: Label3D = main._spade_skylt
	check(skylt != null and is_instance_valid(skylt), "och det är en Label3D över spadens ruta",
		"" if skylt == null else str(skylt.position))
	# TEXTEN UR I18N, INTE HÅRDKODAD: provet bygger om skylten i två språk och läser samma nyckel som
	# koden. Stod svenskan kvar efter språkbytet vore nyckeln inte inkopplad.
	if skylt != null and is_instance_valid(skylt):
		skylt.free()
	Tr.set_lang("sv")
	main._spade_skylt_bygg(spade)
	check(main._spade_skylt.text == "Gräv nedåt" and main._spade_skylt.text == Tr.t("ui.spade.skylt"),
		"skylten bär den svenska nyckeln ui.spade.skylt", main._spade_skylt.text)
	Tr.set_lang("en")
	skylt = main._spade_skylt
	skylt.free()
	main._spade_skylt_bygg(spade)
	check(main._spade_skylt.text == "Dig down",
		"och engelskan ger 'Dig down' — texten kommer ur i18n, inte ur en hårdkodad sträng",
		main._spade_skylt.text)
	var utan_rad := []
	for kod in Tr.codes():
		Tr.set_lang(kod)
		var v: String = Tr.t("ui.spade.skylt")
		if v.strip_edges().is_empty() or (kod != "en" and v == "Dig down"):
			utan_rad.append(kod)
	Tr.set_lang("sv")
	check(utan_rad.is_empty(), "nyckeln finns på alla tretton språk med eget värde",
		", ".join(utan_rad))
	# GUNGNINGEN: en SINUS PÅ HÖJDEN, räknad per bildruta i `_process` (förut en evig tween i sidled).
	# Provet mäter den i riktig tid: klockan nollas, och en kvarts period (0,42 s vid 3,7 rad/s) ska
	# ge toppen, ett halvt varv viloläget och tre kvarts varv botten. Båda sidor om viloläget krävs:
	# en rörelse som bara går uppåt är en drift, inte en gungning.
	var bas: float = main._spade_skylt_bas
	var x_före: float = main._spade_skylt.position.x
	var z_före: float = main._spade_skylt.position.z
	main._refresh()                    # samma väg som spelet tar: skylten tänds när spaden är byggd
	main._gunga = 0.0
	await create_timer(0.42).timeout
	var topp: float = main._spade_skylt.position.y
	await create_timer(0.43).timeout
	var mitten: float = main._spade_skylt.position.y
	await create_timer(0.42).timeout
	var botten: float = main._spade_skylt.position.y
	print("    skyltens höjd kring viloläget %.3f (SKYLT_HÖJD %.2f, SKYLT_FART %.1f): topp %.3f, mitten %.3f, botten %.3f"
		% [bas, main.SKYLT_HÖJD, main.SKYLT_FART, topp, mitten, botten])
	check(main._skylt_syns(), "skylten är tänd medan den gungar")
	check(topp - bas > main.SKYLT_HÖJD * 0.8, "kvarts varv upp: skylten når toppen",
		"%.3f över viloläget (%+.3f)" % [main.SKYLT_HÖJD, topp - bas])
	check(absf(mitten - bas) < main.SKYLT_HÖJD * 0.5, "halvt varv: tillbaka i viloläget",
		"%.3f mot %.3f" % [mitten, bas])
	check(bas - botten > main.SKYLT_HÖJD * 0.8, "och tre kvarts varv: skylten når botten",
		"%.3f under viloläget (%+.3f)" % [main.SKYLT_HÖJD, botten - bas])
	check(is_equal_approx(main._spade_skylt.position.x, x_före)
		and is_equal_approx(main._spade_skylt.position.z, z_före),
		"och den gungar bara i HÖJD — inte i sidled som förut",
		"x/z %.3f,%.3f mot %.3f,%.3f" % [main._spade_skylt.position.x, main._spade_skylt.position.z,
			x_före, z_före])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
