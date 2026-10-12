## Provet för HUD:en i ytan RUNT spelvyn.
##
## MÄTT: förut ritades hela fönstret i 480x270 och skalades upp 2x, HUD-texten inräknad — en 9 px
## font blev 18 px stora fyrkanter ("grötig"). Nu ritas 3D:n i en SubViewport 480x270 som skalas upp
## med heltal och NEAREST, medan HUD:en ligger i fönstret (1280x720) och ritas i sin egen storlek.
##
## Provet biter på fyra saker som är LÄTTA att tappa och svåra att se:
##   1. att SubViewporten är korgen:s BARN (ligger den vid sidan om ritar korgen ingenting alls —
##      mätt: hela fönstret blev projektets rensfärg),
##   2. att korgen är heltalsskalad, centrerad och NEAREST (annars är pixelkonsten borta),
##   3. att HUD:en ligger i FÖNSTRET och inte inne i vyn (annars blir texten grötig igen),
##   4. att korten ligger i en rad i den svarta ytan, och att ett kort utan ikon får en TYDLIG
##      platshållare (11 av 67 kort saknar bild — en tom ruta ser ut som ett trasigt kort).
##
## KÖRNING: godot --headless --script res://tests/test_hud.gd
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

func _initialize() -> void:
	print("— spelvyn: en egen ruta, heltalsskalad —")
	# Fotoläget först: provet startar en riktig körning, och en körning som bara mäter får inte
	# skriva i spelarens profil (samma flaskhals som test_sparfil vaktar).
	Meta.fotolage(true)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# SPRÅKET PINNAS EFTER main, inte före: `main._ready` läser sparfilens språk (`meta.language`)
	# och sätter det sist, så en pinne före instansieringen skrivs över. Provet jämför mot svenska
	# ordagrant ("NYTT SPEL", "tillbaka till byn"), och det ska inte hänga på vilket språk spelaren
	# råkade välja i sin egen sparfil.
	Tr.set_lang("sv")
	main._start_run("stage_01", 20260919)
	await process_frame

	# SKRAFFERINGEN PÅ MINIKARTAN (M105). Alex skickade "hand-drawn hatch lines" till kartan uppe till
	# höger. Våningens egna rutor är en eller två pixlar på en 50x50-våning, så de kan inte skrafferas —
	# men kartan har tomrum runt våningen, och det är det en handritad karta skraffrar. Tomrummet är
	# kartans EGEN bakgrundsfärg, och den går in i shadern som `tom_ton` ur samma konstant som rutan
	# målas i (`MapView.TOM`), så de två inte kan glida isär.
	var mm: ShaderMaterial = main.map_view.material as ShaderMaterial
	check(mm != null and mm.shader != null and mm.shader.resource_path.ends_with("pergament.gdshader"),
		"minikartan bär pergament-shadern")
	check(mm != null and mm.get_shader_parameter("storlek") == Vector2(main.MapView.MAP_SIZE),
		"och sin egen storlek som uniform", str(mm.get_shader_parameter("storlek")) if mm != null else "-")
	var tom_ton: Variant = mm.get_shader_parameter("tom_ton") if mm != null else null
	check(tom_ton != null and absf((tom_ton as Vector3).x - main.map_view.TOM.r) < 0.001
		and absf((tom_ton as Vector3).y - main.map_view.TOM.g) < 0.001
		and absf((tom_ton as Vector3).z - main.map_view.TOM.b) < 0.001,
		"tomrummets färg kommer ur kartans egen konstant (en källa)", str(tom_ton))

	# VYN FÖLJER FÖNSTRET (M113): höjden är designmåttet eller mer, bredden kommer ur fönstret. Att
	# kräva 480x270 vore att kräva den inramade rutan som Alex ville bort.
	check(main._vy != null and main._vy.size == Vector2i(main._vy_korg.size),
		"spelvyn har korgen egna mått", "%dx%d" % [main._vy.size.x, main._vy.size.y])
	check(main._vy != null and main._vy.size.y >= int(main.VY.y),
		"och minst 270 spelpixlar på höjden (designmåttet ryms)",
		"%dx%d" % [main._vy.size.x, main._vy.size.y])
	check(main._vy.get_parent() == main._vy_korg,
		"vyn ligger I korgen (annars ritas ingenting alls)")
	check(main._vy.own_world_3d, "vyn har sin egen 3D-värld (miljön läcker inte ut i fönstret)")

	var skala: float = main._vy_korg.scale.x
	# Fönstret mäts, inte gissas: provet körs också i huvudlöst läge (tools/test.sh), där fönstret är
	# en annan storlek. Att skriva in 1280x720 i provet hade fällt det i den körningen av fel skäl.
	var fönster: Vector2 = main.get_viewport().get_visible_rect().size
	print("  fönstret är %.0fx%.0f" % [fönster.x, fönster.y])
	check(absf(skala - roundf(skala)) < 0.001, "skalan är ett heltal", "x%.2f" % skala)
	check(main._vy_korg.size == Vector2(main._vy.size),
		"korgen är vyns storlek, inte fönstrets (annars skalas 3D:n upp och pixlarna smetas ut)",
		"%.0fx%.0f" % [main._vy_korg.size.x, main._vy_korg.size.y])
	var mål := Vector2(main._vy_korg.size) * skala
	check(main._vy_korg.position.y == 0.0, "vyn ligger i ÖVERKANTEN (ingen inramad ruta)",
		"@ %.0f,%.0f" % [main._vy_korg.position.x, main._vy_korg.position.y])
	check(absf(main._vy_korg.position.x - floorf((fönster.x - mål.x) * 0.5)) <= 1.0,
		"och det som blev över i sidled delas lika",
		"@ %.0f av %.0f" % [main._vy_korg.position.x, fönster.x - mål.x])
	# SKALAN OCH REMSAN HÖR IHOP (M113): skalan är det största heltal där vyn OCH remsan ryms, och
	# remsan ligger i 100-150 px. MÄTS BARA MED ETT FÖNSTER SOM RYMMER DEM: i huvudlöst läge är
	# fönstret 64 px, designmåttet (270 + 100) får inte plats alls, och siffran hade mätt fel sak.
	var barh: float = main._bar(fönster).size.y
	if fönster.y < float(main.VY.y) + 100.0:
		print("      hoppar över remsans mått: fönstret är %.0fx%.0f och rymmer inte vyn + remsan — mäts i -- guiprov"
			% [fönster.x, fönster.y])
	else:
		check(main._vy_korg.size.y * skala + barh <= fönster.y + 1.0,
			"vyn och remsan ryms i fönstret", "%.0f + %.0f av %.0f"
				% [main._vy_korg.size.y * skala, barh, fönster.y])
		check((main._vy_korg.size.y + 1.0) * skala + 100.0 > fönster.y,
			"och skalan är den största som ryms", "en spelpixel till hade krävt mer än fönstret")
		check(barh >= 100.0 and barh <= 150.0, "remsan ligger i 100-150 px", "%.0f px" % barh)
	check(main._vy_korg.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"uppskalningen är NEAREST")
	# PEKAREN NÅR IN I VYN. Kortvalet och albumet är paneler INNE i spelvyn (barn till `hud`, som är
	# ett barn till vyn), och två flaggor kan stänga ute musen från dem utan att något annat syns:
	# `gui_disable_input` på vyn och MOUSE_FILTER_IGNORE på korgen. Tangenterna går fria ändå (de
	# kommer via `_unhandled_input`), så felet visar sig bara för den som klickar — Alex: "det går
	# inte att välja ett kort där, det går inte att klicka på dem". Mätt i `-- kortvalsprov`.
	check(not main._vy.gui_disable_input,
		"vyn tar emot pekaren (annars går panelerna i vyn inte att klicka på)")
	check(main._vy_korg.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"korgen för pekaren vidare in i vyn",
		"filter %d" % main._vy_korg.mouse_filter)

	print("")
	print("— HUD:en runt vyn ligger i FÖNSTRET —")
	for par in [["statusraden", main.top_label], ["tangenttipsen", main.hint_label],
			["korträknaren", main.kort_label], ["handen", main.hand_zone]]:
		var n: Node = par[1]
		check(n != null and n.get_viewport() == main.get_viewport(),
			"%s ritas i fönstret, inte i den lilla vyn" % par[0])
	# Texten ska vara STÖRRE än den gamla 9 px-raden: det var storleken som gjorde den grötig när
	# hela vyn skalades upp. Siffran mäts ur kontrollen, inte ur koden.
	var storlek: int = main.top_label.get_theme_font_size("font_size")
	check(storlek >= 16, "statusraden har fönsterstor text", "%d px" % storlek)

	var i_strid: bool = main.active_combat != null and not main.active_combat.over()
	check(main.top_label.text != "", "statusraden har en text", main.top_label.text)
	check(main.hint_label.text.contains("WASD"), "tangenttipsen står i samma yta", main.hint_label.text)
	check(not i_strid or main.stats_label.text.contains("rust"),
		"mana, kedja och RUSTNING står på samma rad", main.stats_label.text)

	print("")
	print("— korten i en rad, och en tydlig platshållare —")
	var db := Cards.load_all()
	var kort: Cards.Card = db["lash"]
	# Kortets två ytterlägen: med ikon och utan. Provet mäter BÅDA — annars ser det bara att den
	# vanliga vägen fungerar och missar de 11 korten som saknar bild.
	# Skalan läses ur spelet (main.HAND_SKALA): med ett eget 1,6 i provet mätte det sin egen siffra i
	# stället för spelets, och såg grönt ut även när handens kort var en annan storlek.
	var med := CardView.make(kort, 0, _ikon(db["lash"]), false, main.HAND_SKALA)
	var utan := CardView.make(kort, 0, null, false, main.HAND_SKALA)
	check(utan.find_child("ikon_platshallare", true, false) != null,
		"kort utan ikon får en platshållare")
	check(utan.find_child("ikon_platshallare", true, false) == null
			or _text_i(utan.find_child("ikon_platshallare", true, false)) != "",
		"platshållaren är inte tom (ett frågetecken, inte en tom ruta)")
	check(med.find_child("ikon_platshallare", true, false) == null,
		"kort MED ikon får ingen platshållare")
	check(utan.custom_minimum_size == CardView.HAND_SIZE * main.HAND_SKALA,
		"kortet i handen har handskalan mot den gamla storleken",
		"%.0fx%.0f" % [utan.custom_minimum_size.x, utan.custom_minimum_size.y])

	# SOLFJÄDERN (M34): fem kort i fönstrets nedre kant, i en båge med omlott och vridna utåt.
	# Kontrollen mäter formen, inte bara antalet: utan båge och vridning är det en rad igen, och
	# det var precis vad Alex såg ("korten ligger ännu på rad").
	main.hand_views.clear()
	for barn in main.hand_zone.get_children():
		barn.queue_free()
	for i in 5:
		var v := CardView.make(kort, i, null, false, main.HAND_SKALA)
		main.hand_views.append(v)
		main.hand_zone.add_child(v)
	await process_frame
	main._rada_hand(true)
	await process_frame
	var xs := []
	var underkant := 0.0
	var överlapp := 0.0
	for v in main.hand_views:
		xs.append(v.home_pos.x)
		underkant = maxf(underkant, v.home_pos.y + v.home_size.y)
	xs.sort()
	for i in range(1, xs.size()):
		överlapp = maxf(överlapp, main.hand_views[0].home_size.x - (xs[i] - xs[i - 1]))
	check(main.hand_views.size() == 5, "fem kort i handen")
	# Omlottet är MED FLIT: en solfjäder är en hög man håller i, inte en hylla. Överlappet får inte
	# vara noll (då är det en rad) och inte så stort att bara kanten av nästa kort syns.
	var kortbredd: float = main.hand_views[0].home_size.x
	# STEGET ÄR MÅTTET (Alex 12/10: korten ska ligga TÄTARE, steget i sidled mellan två kort får vara
	# högst 0,45 x kortets bredd). Överlappet är kortbredd minus steget, alltså 0,55 eller mer — den
	# gamla gränsen 0,6 mätte överlappet och föll på en solfjäder som är RÄTT.
	var steg: float = kortbredd - överlapp
	check(steg > 0.0 and steg <= kortbredd * 0.45,
		"korten ligger tätare än 0,45 x kortets bredd", "steg %.0f px av %.0f" % [steg, kortbredd])
	# Bågen: mittenkortet högst, ytterkorten lägre — och vridna utåt, speglade kring mitten.
	var mitten: CardView = main.hand_views[2]
	var vänster: CardView = main.hand_views[0]
	var höger: CardView = main.hand_views[4]
	check(mitten.home_pos.y < vänster.home_pos.y - 5.0 and mitten.home_pos.y < höger.home_pos.y - 5.0,
		"mittkortet sitter högst i bågen", "mitt %.0f, ytter %.0f/%.0f"
			% [mitten.home_pos.y, vänster.home_pos.y, höger.home_pos.y])
	check(vänster.home_rot < -0.01 and höger.home_rot > 0.01,
		"ytterkorten är vridna utåt från mitten", "vänster %+.3f, höger %+.3f rad"
			% [vänster.home_rot, höger.home_rot])
	check(is_zero_approx(mitten.home_rot), "mittkortet står rakt", "%.3f rad" % mitten.home_rot)
	# ANKARET: mittkortets underkant ligger 6 px in i fönstrets nederkant, precis där raden låg.
	# Ytterkorten hänger nedanför kanten med flit — en hand som hålls lågt skärs av skärmkanten.
	var botten: float = mitten.home_pos.y + mitten.home_size.y
	# UNDERKANTEN LIGGER 6 px ÖVER REMSAN (M113): handen hålls framför spelaren och remsan är golvet
	# den vilar på. Ankrades den i fönstrets nederkant hamnade korten UNDER remsan.
	var bar_topp: float = main._bar(fönster).position.y
	check(absf(botten - (bar_topp - 6.0)) <= 1.0, "mittkortets underkant ligger vid remsans överkant",
		"%.0f av %.0f" % [botten, bar_topp])

	print("")
	print("— varje text i HUD:en är en NYCKEL, inte en svensk sträng i koden —")
	# Kravet är fullständigt stöd för 13 språk: en hårdkodad svensk sträng i ritkoden står kvar på
	# svenska i en tysk körning (mätt på skalet: ui.shop.title var bara en kodfallback). Provet
	# läser HUD:ens egna nycklar ur sv.json och en.json — generatorn fyller de övriga elva.
	var nycklar := ["ui.hud.status", "ui.hud.hint", "ui.hud.kort", "ui.hud.rust",
		"ui.stats.mana", "ui.shell.status"]
	for fil in ["sv", "en"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/i18n/%s.json" % fil))
		for n in nycklar:
			check(data.has(n), "%s finns i %s.json" % [n, fil])
	# Och att koden använder just de nycklarna: en nyckel som ingen formaterar är död vikt.
	var källa := FileAccess.get_file_as_string("res://main.gd")
	for n in nycklar:
		check(källa.contains("\"%s\"" % n), "koden formaterar %s" % n)

	print("")
	print("— ramen i marginalen (M36) —")
	# Ramen ritar fyra band UTANFÖR spelvyn. Provet mäter geometrin: banden ska tillsammans vara
	# exakt fönstret minus vyn (ingen rad dubbelritad, inget hål), och ingen av dem får rita en enda
	# pixel innanför vyns kant. Att ingen bildpunkt i vyn ändras med ramen på är mätt i skärmbild
	# (0 px över tröskeln, medel 0,01) — den här kontrollen är det som gör att det håller.
	var ram := HudRam.new()
	var ram_vy := Rect2(160, 90, 960, 540)     # 480x270 i heltalsskalan 2, centrerad i 1280x720
	var ram_fönster := Vector2(1280, 720)
	ram.sätt_vy(ram_vy, 2)
	var banden := ram.band(ram_fönster)
	check(banden.size() == 4, "ramen har fyra band (tak, golv, vänster, höger)", "%d" % banden.size())
	var ram_area := 0.0
	var ram_inne := 0.0
	for r in banden:
		ram_area += r.size.x * r.size.y
		var k := r.intersection(ram_vy)
		ram_inne += k.size.x * k.size.y
	var ram_väntat := ram_fönster.x * ram_fönster.y - ram_vy.size.x * ram_vy.size.y
	check(absf(ram_area - ram_väntat) < 0.5, "banden är exakt fönstret minus vyn",
		"%.0f mot %.0f px" % [ram_area, ram_väntat])
	check(ram_inne < 0.5, "ingen av banden ritar i spelvyn", "%.0f px" % ram_inne)
	# Ett fönster utan marginal (vyn fyller allt) ska ge NOLL band i stället för fyra tomma: annars
	# ritar ramen en kant överst och nederst i en vy som redan fyller fönstret.
	ram.sätt_vy(Rect2(0, 0, 1280, 720), 2)
	check(ram.band(ram_fönster).is_empty(), "en vy utan marginal ger inga band")
	ram.free()

	# KÄRLEN ÄR BORTA (M40). De fyra skålarna i marginalen ersattes av staplar i statusblocket, och
	# `game/ui/hud_orb.gd` togs bort med dem: en nivå över taket klipps till 0-1 av `HudBar.andel()`
	# i stället, och det mäts i tests/test_gui.gd (halvt liv = halv stapel, fullt liv = full stapel).
	# Att behålla en ritad komponent som ingen ritar vore att lämna kvar en bild av hur HUD:en SÅG ut.

	print("")
	print("— värdshuset: hjältarna som figurer i ett rutnät (högst 4 per rad, helst 3) —")
	# REGELN MÄTS MED FLER HJÄLTAR ÄN TAKET, annars mäter provet ingenting (Alex' ord: en lista på
	# fyra eller färre kan aldrig visa om raden bryts). Den riktiga listan har sexton.
	main.meta.gold = 999999
	var linjer: Array = main.meta.crawler_lines()
	check(linjer.size() > main.KORT_TAK, "fler hjältar än en rad får plats (annars mäter provet inget)",
		"%d hjältar mot taket %d" % [linjer.size(), main.KORT_TAK])
	main.shell = "vardshus"
	main._refresh_shell()          # samma väg som tangenterna tar: panelen OCH marginalens tipsrad
	await process_frame
	# Tipsen flyttade ut ur panelen (önskemål 16) eftersom de gjorde den 608 px bred. Att de står
	# NÅNSTANS är en kontroll, inte en detalj: en tangent man inte ser är en tangent man inte vet om.
	check(not main.hint_label.text.is_empty() and main.hint_label.text.contains("Esc"),
		"tangenterna står i marginalens tipsrad", "tips: %s" % main.hint_label.text)
	# Panelen ligger i vyn (barn till `hud`, som är ett barn till SubViewporten), så dess
	# globala rektangel är i VYNS eget rum: 0,0-480,270. Att mäta mot fönstret hade jämfört två
	# olika rum och gett rätt svar av fel skäl (eller tvärtom).
	# VYNS RUTA ÄR INTE 480x270 (M113): den följer fönstret, och panelerna placeras i VYNS EGET rum
	# (barn till `hud`), alltså i spelpixlar — inte i fönsterpixlar. Provet mäter därför mot vyns
	# aktuella mått. I huvudlöst läge är fönstret 64 px och vyn 160 px bred; panelen är 310 px och
	# kan inte rymmas alls, så de kontrollerna hoppas över där (samma regel som remsans mått ovan).
	var vy_rect := Rect2(Vector2.ZERO, main._vy_mått())
	var rymmer_panel: bool = main._vy_mått().x >= float(main.VY.x)
	var utanför := 0
	var för_hög := 0
	var rader_för_breda := 0
	var vald_ute := 0
	var detalj_ute := 0
	var detalj_fel := 0
	var min_panel := 1e9
	var max_panel := -1e9
	var max_höjd := 0.0
	var max_rad := 0
	for i in linjer.size():
		main.inn_index = i
		main._show_inn()
		await process_frame
		await process_frame          # queue_free: barnen är kvar till ramens slut
		await process_frame          # _kortvägg_visa väntar två bildrutor på layouten
		await process_frame
		await process_frame
		var panel: Rect2 = main.inn_panel.get_global_rect()
		min_panel = minf(min_panel, panel.position.x)
		max_panel = maxf(max_panel, panel.end.x)
		max_höjd = maxf(max_höjd, panel.size.y)
		if panel.position.x < vy_rect.position.x - 0.5 or panel.end.x > vy_rect.end.x + 0.5:
			utanför += 1
		if panel.position.y < vy_rect.position.y - 0.5 or panel.end.y > vy_rect.end.y + 0.5:
			för_hög += 1
		# RADEN, INTE RUTNÄTET: figurerna grupperas på sin y, och varje grupp är en ritad rad. Taket
		# är fyra (Alex: "högst 4 figurer per rad — helst 3"), mätt på de RITADE raderna.
		var rader := {}
		for barn in main.inn_rutnät.get_children():
			var figur: Control = barn
			var nyckel := int(round(figur.position.y))
			rader[nyckel] = int(rader.get(nyckel, 0)) + 1
		for antal in rader.values():
			max_rad = maxi(max_rad, int(antal))
			if int(antal) > main.KORT_TAK:
				rader_för_breda += 1
		# DEN VALDA FIGUREN SKA SYNAS: rutnätet rullar, så valet kan hamna utanför sin ruta. Att valet
		# följer med i bild är hela poängen med rullaren (annars ser man inte vad man valt).
		var synlig: Rect2 = main.inn_scroll.get_global_rect()
		var vald_nod: Control = main.inn_rutnät.get_child(i)
		var vr: Rect2 = vald_nod.get_global_rect()
		if vr.position.y < synlig.position.y - 1.0 or vr.end.y > synlig.end.y + 1.0:
			vald_ute += 1
		# DETALJRADEN står still medan rutnätet rullar — den får aldrig hamna utanför vyn.
		var dr: Rect2 = main.inn_detalj.get_global_rect()
		if dr.position.x < vy_rect.position.x - 0.5 or dr.end.x > vy_rect.end.x + 0.5 \
				or dr.position.y < vy_rect.position.y - 0.5 or dr.end.y > vy_rect.end.y + 0.5:
			detalj_ute += 1
		# …och den visar DEN VALDA hjälten: namn, förmåga och läget (pris eller I LEEK). Formen är ny,
		# innehållet är detsamma som kortväggen bar (namn, pris, förmåga, val).
		var rad: Dictionary = linjer[i]
		var väntat: String = (Tr.t("ui.inn.hired", "I LEEK") if bool(rad["hired"])
			else Tr.t("ui.village.price", "%d guld") % int(rad["price"]))
		if main.inn_det_namn.text != str(rad["name"]) or main.inn_det_text.text != str(rad["text"]) \
				or main.inn_det_pris.text != väntat:
			detalj_fel += 1
	if not rymmer_panel:
		print("      hoppar över hjältepanelens ruta: vyn är %.0f px bred och panelen är %.0f px — mäts i -- guiprov"
			% [main._vy_mått().x, max_panel - min_panel])
	check(not rymmer_panel or utanför == 0, "hjältepanelen ligger innanför spelvyn på bredden vid varje val",
		"%d av %d val stack ut (panel %.0f..%.0f mot vyn %.0f..%.0f)"
			% [utanför, linjer.size(), min_panel, max_panel, vy_rect.position.x, vy_rect.end.x])
	check(not rymmer_panel or för_hög == 0, "och på höjden (270 px)", "högsta panelen %.0f px" % max_höjd)
	check(rader_för_breda == 0, "ingen rad har fler än KORT_TAK figurer (%d)" % main.KORT_TAK,
		"bredaste raden %d figurer, %d rader över taket" % [max_rad, rader_för_breda])
	check(max_rad >= 3, "och raden fylls (helst tre per rad, aldrig färre än en fylld rad)",
		"%d i den bredaste raden" % max_rad)
	check(main.inn_rutnät.columns == main.kortvägg_kolumner(linjer.size(), float(main.INN_FIGUR)),
		"rutnätets kolumner kommer ur den DELADE regeln",
		"%d mot %d" % [main.inn_rutnät.columns,
			main.kortvägg_kolumner(linjer.size(), float(main.INN_FIGUR))])
	check(vald_ute == 0, "den valda figuren rullas i bild",
		"%d av %d val stod utanför rutnätets ruta" % [vald_ute, linjer.size()])
	check(not rymmer_panel or detalj_ute == 0, "detaljraden står kvar inne i vyn medan rutnätet rullar",
		"%d av %d val hamnade utanför" % [detalj_ute, linjer.size()])
	check(detalj_fel == 0, "och den visar namn, förmåga och pris för DEN VALDA",
		"%d av %d val visade fel" % [detalj_fel, linjer.size()])
	# BEKRÄFTA-knappen (Alex' referens: Confirm när man är klar) hyr den valda — samma väg som Enter.
	var guld_före: int = main.meta.gold
	var köpbar := -1
	for i in linjer.size():
		if not bool(main.meta.crawler_lines()[i]["hired"]):
			köpbar = i
			break
	if köpbar >= 0:
		main.inn_index = köpbar
		main._show_inn()
		await process_frame
		check(not main.inn_hyr.disabled, "en ohyr hjälte kan bekräftas",
			"knappen säger '%s'" % main.inn_hyr.text)
		main.inn_hyr.pressed.emit()
		await process_frame
		check(bool(main.meta.crawler_lines()[köpbar]["hired"]), "BEKRÄFTA hyr den valda figuren",
			"%d → %d guld" % [guld_före, main.meta.gold])
	# Varje hyrbar har ett porträtt att visa: rutnätet är meningslöst om en bild saknas.
	var utan_bild := []
	for rad_l in main.meta.crawler_lines():
		if main._card_icon(str(rad_l["id"])) == null:
			utan_bild.append(str(rad_l["id"]))
	check(utan_bild.is_empty(), "varje hyrbar har sitt porträtt (hjältearket eller kortet)",
		"%d hyrbara, saknas: %s" % [linjer.size(), str(utan_bild)])

	# SMALA FÖNSTER (Alex: "Ändringen ska hålla i smala fönster"). Panelen ritas INNE i spelvyn
	# (480x270), som skalas upp och centreras i fönstret — ett annat fönster flyttar alltså inte
	# panelen, men vyn kan hamna utanför kanten om den inte ryms. Proven mäter BÅDA, i Alex' eget
	# 941x1018 och i 1280x720: panelen mot vyn, och vyns ruta mot fönstret.
	for fönsterstorlek in [Vector2i(1280, 720), Vector2i(941, 1018)]:
		root.size = fönsterstorlek
		main.get_viewport().size = fönsterstorlek
		main._placera_vy()
		await process_frame
		main.inn_index = linjer.size() - 1     # valet längst ned i rutnätet: där rullaren är som mest
		main._show_inn()
		for i in 4:
			await process_frame
		var panel: Rect2 = main.inn_panel.get_global_rect()
		# VYN ÄR INTE 480x270 (M113): den följer fönstret, och panelen är ett barn till `hud` i
		# VYNS eget rum. Provet mäter därför mot vyns AKTUELLA mått — samma regel som längre upp.
		var vyn := Rect2(Vector2.ZERO, main._vy_mått())
		check(panel.position.x >= vyn.position.x - 0.5 and panel.end.x <= vyn.end.x + 0.5
				and panel.position.y >= vyn.position.y - 0.5 and panel.end.y <= vyn.end.y + 0.5,
			"hjältepanelen ryms i spelvyn i %dx%d" % [fönsterstorlek.x, fönsterstorlek.y],
			"panel x %.0f..%.0f y %.0f..%.0f mot vyn %.0f..%.0f" % [panel.position.x, panel.end.x,
				panel.position.y, panel.end.y, vyn.end.x, vyn.end.y])
		# Och vyns ruta PÅ SKÄRMEN räknas ur korgen (dess egen storlek × skalan), inte ur designmåttet
		# 480x270: korgen är vyns storlek, och det är den som skalas upp i fönstret.
		var på_skärmen := Rect2(main._vy_korg.position, main._vy_korg.size * main._vy_korg.scale.x)
		check(på_skärmen.position.x >= -0.5 and på_skärmen.end.x <= float(fönsterstorlek.x) + 0.5
				and på_skärmen.position.y >= -0.5 and på_skärmen.end.y <= float(fönsterstorlek.y) + 0.5,
			"och spelvyn ryms i fönstret i %dx%d" % [fönsterstorlek.x, fönsterstorlek.y],
			"vyn x %.0f..%.0f y %.0f..%.0f" % [på_skärmen.position.x, på_skärmen.end.x,
				på_skärmen.position.y, på_skärmen.end.y])
	# Tillbaka till provets eget fönster: resten av provet mäter i 1280x720.
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	main._placera_vy()
	await process_frame

	# BELÖNINGEN EFTER KÖRNINGEN (önskemål 24). Mätt genom spelets EGEN väg: körningen avslutas,
	# tillståndsbytet bankar och rullar boxen, och valet betalas ut av `_box_pick` — samma funktion
	# som tangenten 1-3 kallar. Att bara prova `Meta` hade inte sagt om boxen alls kom fram.
	print("")
	print("— belöningen efter körningen (önskemål 24) —")
	main.run._finish_with("dead")
	main._after_state_change()
	await process_frame
	check(main._box_val.size() == 3, "boxen rullas när körningen tar slut",
		"%d val: %s" % [main._box_val.size(), str(main._box_val)])
	check(main.end_panel.visible, "och slutskärmen står framme")
	check(main.meta.gold > 0, "utbetalningen för djupet hamnade i banken", "%d guld" % main.meta.gold)
	check(main._box_best_index() >= 0 and main._box_best_index() < main._box_val.size(),
		"och en ospelad box pekar på ett giltigt val", "index %d" % main._box_best_index())
	var guld_fore: int = main.meta.gold
	var valt: Dictionary = main._box_val[0]
	main._box_pick(0)
	await process_frame
	check(main._box_val.is_empty(), "valet tömmer boxen")
	check(not main._box_logg.is_empty(), "och raden för det valda står kvar", main._box_logg)
	check(main.meta.gold != guld_fore or str(valt.get("kind", "")) != "gold",
		"och valet betalades ut", "%d → %d (%s)" % [guld_fore, main.meta.gold, str(valt.get("kind", ""))])
	# Och ett andra val ska inte kunna betala ut igen: boxen är tom, och _box_pick ska tiga.
	var guld_efter: int = main.meta.gold
	main._box_pick(0)
	check(main.meta.gold == guld_efter, "ett andra tryck betalar inte ut igen", "%d guld" % main.meta.gold)
	# Den bästa ordningen: ett kort väger tyngre än en sten, som väger tyngre än guld.
	main._box_val = [{"kind": "gold", "amount": 10}, {"kind": "card", "id": "lash"},
		{"kind": "shards", "amount": 2}]
	check(main._box_best_index() == 1, "en ospelad box tar det BÄSTA valet",
		"index %d" % main._box_best_index())
	main._box_val = []
	# Efterlysningarna (önskemål 24, punkt 3): raden ska stå på slutskärmen — antingen en som brast
	# ut, eller den som är närmast. En trasig formatsträng syntes inte i texten förrän här.
	check(main.end_label.text.contains("efterlysning") or main.end_label.text.contains("EFTERLYSNING"),
		"slutskärmen visar efterlysningen",
		main.end_label.text.substr(0, 60).replace("\n", " / "))

	# VADSLAGNINGEN OCH SJÄLEN (önskemål 24, punkt 7 och 8) genom spelets EGEN väg: insatsen dras när
	# körningen startar, ett klarat vad betalar tillbaka dubbelt, och en död körning betalar ingenting.
	print("")
	print("— vadet och själen genom körningens väg (önskemål 24, punkt 7 och 8) —")
	main.meta.gold = 1000
	main.meta.vad_valt["stage_01"] = 0.25
	main.meta.hired = []
	main._start_run("stage_01", 4242)
	check(main._vad_insats == 250, "insatsen är en fjärdedel av banken vid starten",
		"%d guld" % main._vad_insats)
	check(main.meta.gold == 750, "och den DROGS när körningen började", "%d guld" % main.meta.gold)
	main.run._finish_with("dead")
	main._after_state_change()
	check(main.meta.gold < 750 + main._vad_insats * 2, "en död körning betalar inte tillbaka vadet",
		"%d guld" % main.meta.gold)
	check(main.end_label.text.contains("VADET FÖRLORAT"), "och slutskärmen säger det",
		main.end_label.text.substr(0, 40).replace("\n", " / "))
	main.meta.vad_valt["stage_01"] = 0.25
	main._start_run("stage_01", 4243)
	var efter_start: int = main.meta.gold
	main.run._enter_floor(main.run.stage.floors - 1)
	main.run._finish_with("cleared")
	main._after_state_change()
	check(main.meta.gold >= efter_start + main._vad_insats * 2,
		"en klarad bana betalar tillbaka vadet dubbelt",
		"%d -> %d guld (%d insats)" % [efter_start, main.meta.gold, main._vad_insats])
	check(main.end_label.text.contains("VADET VANN"), "och slutskärmen säger det",
		main.end_label.text.substr(0, 40).replace("\n", " / "))

	# DAGENS KÖRNING (önskemål 24, punkt 5): T startar den, den kan bara tas en gång per dygn, och den
	# betalar 50 % mer. Skillnaden mäts mot en IDENTISK körning utan dagens flagga — samma frö, samma
	# golv, tom pung och inga mål som kan brista mitt i mätningen.
	print("")
	print("— dagens körning (önskemål 24, punkt 5) —")
	main.meta.dagens_datum = ""
	main.meta.vad_valt = {}
	main.meta.gold = 500
	main._start_dagens()
	check(main._dagens, "dagens körning startade", "%s" % main.run.stage.id)
	check(main.meta.dagens_datum == Time.get_date_string_from_system(), "och dagens datum skrevs ner",
		main.meta.dagens_datum)
	var dagens_fro: int = main.run.seed_value
	main._start_dagens()
	check(main.run.seed_value == dagens_fro, "ett andra tryck startar ingen ny körning",
		"frö %d" % main.run.seed_value)
	var utan_dagens := _bankad_guld(main, 20260919, false)
	var med_dagens := _bankad_guld(main, 20260919, true)
	check(abs(med_dagens - int(round(float(utan_dagens) * 1.5))) <= 1,
		"dagens körning betalar 50 % mer för samma körning",
		"%d mot %d guld" % [med_dagens, utan_dagens])

	print("")
	print("— %d kontroller, %d fel —" % [checks, fails])
	quit(1 if fails > 0 else 0)

## Kortets ikon om den finns — samma väg som main.gd:s _card_icon.
func _ikon(c: Cards.Card) -> Texture2D:
	var p := "res://assets/cards/%s.png" % c.id
	return load(p) if ResourceLoader.exists(p) else null

## Texten i ett Controls barn (platshållarens frågetecken).
func _text_i(n: Node) -> String:
	for barn in n.get_children():
		if barn is Label:
			return (barn as Label).text
	return ""


## Bankar en avslutad körning med samma frö och samma golv och svarar med guldet som lades till. Alla
## efterlysningar märks som kvitterade först, så inget mål kan brista mitt i en mätning — kvar blir
## körningens egen belöning, och det är den som är 50 % högre för dagens körning.
func _bankad_guld(m: Node, seed_value: int, dagens: bool) -> int:
	for c in Meta.CONTRACTS:
		if not m.meta.uppdrag_kvitterade.has(str(c["id"])):
			m.meta.uppdrag_kvitterade.append(str(c["id"]))
	m.meta.vad_valt = {}
	m.meta.gold = 0
	m._start_run("stage_01", seed_value)
	m._dagens = dagens
	m.run.gold = 0
	m.run._enter_floor(m.run.stage.floors - 1)
	m.run._finish_with("cleared")
	m._after_state_change()
	return m.meta.gold
