## Provet för KORTBORDEN (M34, punkt 8): draghögen till höger, de använda till vänster, och flyttarna
## mellan dem.
##
## Alex: *"en animation som flyttar korten man har tillgängliga från en korthög i höger hörn, till
## handen man håller i ... och sedan till vänster sida i en hög av 'Använda kort'. Korten skall sedan
## samlas ihop och läggas i högen prydligt igen på höger sida."*
##
## Provet biter på fyra saker:
##   1. att siffrorna kommer ur SPELETS högar (`draw_pile`/`discard_pile`) och inte ur en egen räknare,
##   2. att högen är TOM när leken är slut (en tom stapel som ser full ut är en lögn om läget),
##   3. att den spelade kortet flyger till den ANVÄNDA högens mitt — inte rakt upp, som förut,
##   4. att omshufflingen (leken tar slut) får den vänstra högen att flyga till den högra.
##
## KÖRNING: godot --headless --script res://tests/test_kortbord.gd
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
	print("— kortborden: siffrorna, flykten och insamlingen —")
	Meta.fotolage(true)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Ett fönster i spelstorlek: provkörningen är headless och startar i 64x64, där marginalerna inte
	# finns alls (vyn är 960x540 och hamnar utanför). Utan det här mäter provet ett fönster ingen
	# spelar i — och "innanför fönstret" blir en kontroll som inte kan gå igenom.
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	main._start_run("stage_01", 20260919)
	main._placera_vy()
	await process_frame

	check(main.hog_drag != null and main.hog_använd != null, "båda högarna finns")
	check(not main.hog_drag.visible, "högarna är gömda utanför en strid (ingen lek att visa)")

	# En strid: gå fram till en fiende och slåss.
	var nod: Dungeon.FloorNode = null
	for n in main.run.explore.floor_ref.nodes:
		if not n.cleared and (n.kind == "encounter" or n.kind == "boss"):
			nod = n
			break
	main.run.explore.pos = nod.pos
	main.run.explore.facing = 0
	main._enter_node_here()
	await process_frame
	check(main.active_combat != null, "striden startade")
	main._refresh_stats()
	await process_frame
	check(main.hog_drag.visible and main.hog_använd.visible, "högarna syns i striden")

	# 1. Siffrorna kommer ur spelets egna högar.
	check(main.hog_drag.antal == main.active_combat.draw_pile.size(),
		"draghögens siffra är spelets lek", "%d mot %d" % [main.hog_drag.antal,
			main.active_combat.draw_pile.size()])
	check(main.hog_använd.antal == main.active_combat.discard_pile.size(),
		"den använda högens siffra är spelets slänghög", "%d" % main.hog_använd.antal)

	# 1b. KORTEN I HÖGEN ÄR KORTSTORA, och det ligger ETT KORT PER KORT i högen.
	#     Alex: "staplarna med kort måste bli lika stora som korten är i spelet ... så har jag 12 kort
	#     i min samling, så skall det finnas 12 kort".
	# Sedan handkortet blev 80 % större (182 px) ryms det inte i marginalkolumnen (160 px): högens kort
	# är därför så stort kolumnen TILLÅTER — korten OCH deras kanter ska rymmas, annars klipps högens
	# ram av mot skärmkanten (mätt på skärmbild). Alex' poäng var att korten ska SYNAS och vara ett per
	# kort, inte att de nödvändigtvis är exakt handens mått.
	var hand_kort: Vector2 = CardView.HAND_SIZE * main.HAND_SKALA
	var kolumn: float = main._hög_geometri(1)["kort"].x      # kolumnen vid ett kort = dess tak
	check(main.hog_drag.kort.x <= hand_kort.x and main.hog_drag.kort.x > hand_kort.x * 0.4,
		"högens kort är handens storlek, krympt till marginalen",
		"%.0fx%.0f mot handens %.0fx%.0f (kolumnen %.0f)" % [main.hog_drag.kort.x, main.hog_drag.kort.y,
			hand_kort.x, hand_kort.y, kolumn])
	var n_lekar: int = main.active_combat.draw_pile.size()
	var väntad_bredd: float = main.hog_drag.kort.x + main.hog_drag.steg() * float(n_lekar - 1)
	check(is_equal_approx(main.hog_drag.size.x, väntad_bredd), "ett kort per kort i leken ger stapelns bredd",
		"%.1f px för %d kort" % [main.hog_drag.size.x, n_lekar])
	check(main.hog_drag.steg() >= KortHog.STEG_MIN, "varje kort i högen får en egen kant",
		"%.2f px per kort" % main.hog_drag.steg())

	# 1c. BAKSIDAN: samma bild på varje kort, och ett kort som kommer från högen vänder sig.
	check(CardView.baksida_textur() != null, "kortbaksidan finns som bild (assets/cards/_back.png)")
	var prov: CardView = CardView.make(main.db.values()[0], 0, null, false, 1.0)
	main.hand_zone.add_child(prov)
	prov.vänd_upp()
	await process_frame
	check(prov.face_down, "ett kort som kommer från högen ligger med baksidan upp")
	await create_timer(0.5).timeout
	check(not prov.face_down, "kortet visar framsidan efter vändningen")
	prov.queue_free()
	await process_frame

	# 1d. KORTETS KONST I HELA STEG (M78). Alex: *"De behöver bli betydligt skarpare än så här."*
	# Stort kort ritar konsten i `steg()` hela multiplar av sin egen storlek, och skalans golv gör att
	# varje konstpixel blir lika bred — men bara om konsten har tillräckligt många pixlar. Med 64 px
	# ikoner blev steget 4 (åtta skärmpixlar per konstpixel); de klippta ikonerna är nu 128, alltså
	# steg 2. Provet mäter att en RIKTIG ikon ur arkivet hamnar i steg 2 i den stora rutan — annars är
	# Alex' "betydligt skarpare" borta utan att något annat säger till.
	var ark_id := ""
	for id in main.db:
		var ik: Texture2D = main._card_icon(id)
		if ik != null and ik.get_width() >= 128:
			ark_id = id
			break
	check(ark_id != "", "minst en kortikon är klippt ur arket (128 px)")
	if ark_id != "":
		var stort: CardView = CardView.make(main.db[ark_id], 0, main._card_icon(ark_id), true, 2.0)
		main._runt.add_child(stort)
		await process_frame
		var ikon: Control = null
		for b in stort.find_children("*", "Control", true, false):
			if b is CardView.Ikon:
				ikon = b
				break
		var steg := (ikon as CardView.Ikon).steg() if ikon != null else -1
		check(steg == 2, "stort kort ritar en 128 px-ikon i steg 2 (två dukpixlar per konstpixel)",
			"steg %d" % steg)
		stort.queue_free()
		await process_frame

	# 2. Den använda högen ritar en SYNLIG ram när den är tom (granskningen såg bara en siffra 0
	#    förut: ramen ritades i marginalens eget svarta).
	var tom_före: int = main.hog_använd.antal
	check(tom_före == 0, "den använda högen är tom innan något spelats")

	# 3. Flykten: kortet ska till den vänstra högens mitt.
	# Läget mäts mot HANDEN (fönstrets mitt) och inte mot vyns ruta: i provkörningen (headless) är
	# fönstret mindre än vyn, och då ligger marginalerna utanför skärmen. Det som ska hålla är
	# ordningen — använda till vänster, leken till höger, båda innanför fönstret.
	var mål: Vector2 = main.hog_använd.mitt()
	var fönster: Vector2 = main.get_viewport().get_visible_rect().size
	var hand_x := fönster.x / 2.0
	check(mål.x < hand_x, "målet ligger till VÄNSTER om handen", "x %.0f mot mitten %.0f"
		% [mål.x, hand_x])
	check(main.hog_drag.mitt().x > hand_x, "draghögen ligger till HÖGER om handen",
		"x %.0f mot mitten %.0f" % [main.hog_drag.mitt().x, hand_x])
	check(mål.x >= 0.0 and main.hog_drag.mitt().x <= fönster.x,
		"båda högarna står innanför fönstret", "%.0f och %.0f av %.0f"
			% [mål.x, main.hog_drag.mitt().x, fönster.x])

	# Spela ett kort: det ska hamna i den använda högen (siffran upp) och handen bli en kortare.
	var hand_före: int = main.active_combat.hand.size()
	await main._on_card(0)
	main._refresh_stats()
	await process_frame
	check(main.hog_använd.antal == 1, "ett spelat kort hamnar i den använda högen",
		"%d" % main.hog_använd.antal)
	check(main.active_combat.hand.size() == hand_före - 1, "handen blev en kortare",
		"%d -> %d" % [hand_före, main.active_combat.hand.size()])

	# 4. Omshufflingen: leken tar slut och de använda blir en ny lek. Provet sätter siffrorna själv
	#    (en riktig omshuffling kräver en hel lek) och mäter att den vänstra högen FLYTTAR sig.
	main._hög_förra_drag = 1
	main._hög_förra_använd = 3
	main.active_combat.draw_pile = [null, null, null, null, null]
	main.active_combat.discard_pile = []
	main._refresh_stats()
	var före_pos: Vector2 = main.hog_använd.position
	await create_timer(0.20).timeout
	var flyttad: float = main.hog_använd.position.distance_to(före_pos)
	check(flyttad > 50.0, "omshufflingen flyttar de använda mot leken", "%.0f px" % flyttad)
	check(main.hog_drag.antal == 5 and main.hog_använd.antal == 0,
		"siffrorna följer den nya leken", "lek %d, använda %d" % [main.hog_drag.antal,
			main.hog_använd.antal])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
