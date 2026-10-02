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
	main._start_run("stage_01", 20260919)
	await process_frame

	check(main._vy != null and main._vy.size == main.VY, "spelvyn är 480x270",
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
	check(int(skala) == int(maxf(1.0, floorf(minf(fönster.x / float(main.VY.x),
			fönster.y / float(main.VY.y))))),
		"skalan är det största heltal fönstret rymmer", "x%.0f" % skala)
	var mål := Vector2(main.VY) * skala
	check(main._vy_korg.position == ((fönster - mål) / 2.0).floor(), "vyn är centrerad",
		"@ %.0f,%.0f" % [main._vy_korg.position.x, main._vy_korg.position.y])
	check(main._vy_korg.size == Vector2(main.VY),
		"korgen är vyns storlek, inte fönstrets (annars skalas 3D:n upp och pixlarna smetas ut)",
		"%.0fx%.0f" % [main._vy_korg.size.x, main._vy_korg.size.y])
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
	check(överlapp > kortbredd * 0.2 and överlapp < kortbredd * 0.6,
		"korten ligger omlott som en solfjäder", "överlapp %.0f px av %.0f" % [överlapp, kortbredd])
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
	check(absf(botten - (fönster.y - 6.0)) <= 1.0, "mittkortets underkant ligger i fönstrets nederkant",
		"%.0f av %.0f" % [botten, fönster.y])

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
	print("— värdshuset: kortväggen ryms i vyn, också med sexton hjältar (önskemål 16) —")
	# Raden mättes för sex kort (se inn_box i _build_hud). Med sexton blev den 16 x 89 x 0,45 +
	# mellanrum = 640 px i en 480 px-vy, och korten försvann ut på båda sidor. Provet mäter
	# geometrin vid VARJE val och inte bara vid det första: fönstret flyttar sig med markeringen,
	# och det är i ändlägena raden kan hamna utanför.
	main.meta.gold = 999999
	main.shell = "vardshus"
	main._refresh_shell()          # samma väg som tangenterna tar: panelen OCH marginalens tipsrad
	await process_frame
	# Tipsen flyttade ut ur panelen (önskemål 16) eftersom de gjorde den 608 px bred. Att de står NÅNSTANS
	# är en kontroll, inte en detalj: en tangent man inte ser är en tangent man inte vet om.
	check(not main.hint_label.text.is_empty() and main.hint_label.text.contains("Esc"),
		"tangenterna står i marginalens tipsrad", "tips: %s" % main.hint_label.text)
	var linjer: Array = main.meta.crawler_lines()
	check(linjer.size() > main.INN_SYNLIGA, "fler hjältar än raden visar på en gång",
		"%d hyrbara mot %d platser" % [linjer.size(), main.INN_SYNLIGA])
	# Panelen ligger i vyn (barn till `hud`, som är ett barn till SubViewporten), så dess
	# globala rektangel är i VYNS eget rum: 0,0-480,270. Att mäta mot fönstret hade jämfört två
	# olika rum och gett rätt svar av fel skäl (eller tvärtom).
	var vy_rect := Rect2(Vector2.ZERO, Vector2(main.VY))
	var utanför := 0
	var för_hög := 0
	var tumme_ute := 0
	var fel_antal := 0
	var utan_markering := 0
	var min_panel := 1e9
	var max_panel := -1e9
	var max_höjd := 0.0
	for i in linjer.size():
		main.inn_index = i
		main._show_inn()
		await process_frame
		await process_frame          # queue_free: barnen är kvar till ramens slut
		# PANELEN, inte raden: panelen mäts mot sin bredaste rad, och en lång rad (etiketten) gör
		# panelen bredare än vyn. Raden är ett barn som följer med — mäts den i stället ser felet
		# mindre ut än det är (mätt: raden var 302 px medan panelen var 608).
		var panel: Rect2 = main.inn_panel.get_global_rect()
		min_panel = minf(min_panel, panel.position.x)
		max_panel = maxf(max_panel, panel.end.x)
		max_höjd = maxf(max_höjd, panel.size.y)
		if panel.position.x < vy_rect.position.x - 0.5 or panel.end.x > vy_rect.end.x + 0.5:
			utanför += 1
		if panel.position.y < vy_rect.position.y - 0.5 or panel.end.y > vy_rect.end.y + 0.5:
			för_hög += 1
		# Varje tumnagel, inte bara raden som ruta: ett kort kan sticka ut trots att raden ryms.
		for barn in main.inn_box.get_children():
			var tumme: Rect2 = (barn as Control).get_global_rect()
			if tumme.position.x < vy_rect.position.x - 0.5 or tumme.end.x > vy_rect.end.x + 0.5:
				tumme_ute += 1
		if main.inn_box.get_child_count() != mini(main.INN_SYNLIGA, linjer.size()):
			fel_antal += 1
		if not (main.inn_first <= i and i < main.inn_first + main.INN_SYNLIGA):
			utan_markering += 1
	check(utanför == 0, "kortväggen ligger innanför spelvyn på bredden vid varje val",
		"%d av %d val stack ut (panel %.0f..%.0f mot vyn %.0f..%.0f)"
			% [utanför, linjer.size(), min_panel, max_panel, vy_rect.position.x, vy_rect.end.x])
	# Höjden är den andra kanten på samma mynt: en fjärde textrad är 12 px, och panelen hade 15 px
	# kvar till vyns 270. Fyra rader ryms — fem gör det inte.
	check(för_hög == 0, "kortväggen ryms på höjden (270 px)", "högsta panelen %.0f px" % max_höjd)
	check(tumme_ute == 0, "varje tumnagel ligger inne i vyn", "%d kort stack ut" % tumme_ute)
	check(fel_antal == 0, "raden ritar INN_SYNLIGA tumnaglar (hela listan om den är kortare)",
		"%d val ritade fel antal" % fel_antal)
	check(utan_markering == 0, "det valda kortet är alltid med i raden",
		"%d val hamnade utanför" % utan_markering)
	# Änden: sista valet ska visa de SISTA korten, inte ett fönster med tomrum efter sig.
	main.inn_index = linjer.size() - 1
	main._show_inn()
	await process_frame
	check(main.inn_first == linjer.size() - main.INN_SYNLIGA,
		"sista valet visar de sista korten, inte tomrum",
		"först %d av %d" % [main.inn_first, linjer.size()])
	# Varje hyrbar har ett kort att visa: raden är meningslös om ett kort saknas i data.
	var utan_kort := []
	for rad_l in linjer:
		if main.db.get(str(rad_l["id"])) == null:
			utan_kort.append(str(rad_l["id"]))
	check(utan_kort.is_empty(), "varje hyrbar har sitt kort i data/cards",
		"%d hyrbara, saknas: %s" % [linjer.size(), str(utan_kort)])

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
