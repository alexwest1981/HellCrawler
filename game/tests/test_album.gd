## Provet för ALBUMET (M34, punkt 9): indexet över de kort man äger.
##
## Alex: *"Man måste kunna öppna som en index över alla kort man äger och se vad de gör om man
## klickar/trycker på ett kort, och allt detta som om man öppnar ett album."*
##
## Provet biter på fyra saker som är lätta att tappa:
##   1. att listan är SAMLINGEN och inte katalogen (rang 0 betyder "finns i datat", inte "äger"),
##   2. att den stora visningen är DET VALDA kortet — annars bläddrar man utan att se något bytas,
##   3. att bläddringen går runt i båda ändar (en rad som tar slut tyst är en rad man fastnar i),
##   4. att albumet är GÖMT under en körning (en kvarglömd panel över korridoren).
##
## KÖRNING: godot --headless --script res://tests/test_album.gd
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
	print("— albumet: samlingen, bläddringen och den stora visningen —")
	# Fotoläget: provet rör metat (ranks) och får inte skriva i spelarens profil.
	Meta.fotolage(true)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# 1. TOM SAMLING. Alla kort finns i db, ingen ägs: albumet ska säga det, inte visa katalogen.
	main.meta.ranks.clear()
	main.meta.hired.clear()
	# Även bossamlingen (M45): provet sparar i fotoprofilen som alla köp gör, så en kvarlämnad samling
	# från förra körningen gjorde "tom samling" till "ett kort" (mätt).
	main.meta.samling.clear()
	main._på_plats("album")
	await process_frame
	var alla_i_db: int = main.db.size()
	check(main.album_ids.is_empty(), "tom samling ger inga kort (av %d i datat)" % alla_i_db,
		"%d kort" % main.album_ids.size())
	check(main.album_panel.visible, "albumet syns när det öppnas")
	check(main.album_stor.get_child_count() == 0, "ingen stor visning när det inte finns något att visa")

	# 2. SAMLINGEN = de ägda korten. Tre kort får rang, ett blir hyrd kamrat: fyra kort, inte fler.
	var ids: Array = main.db.keys()
	main.meta.ranks[str(ids[0])] = 1
	main.meta.ranks[str(ids[1])] = 2
	main.meta.ranks[str(ids[2])] = 1
	main.meta.ranks[str(ids[3])] = 0          # rang 0 = finns i datat, ägs inte
	main.meta.hired = [str(ids[4])]
	main._show_album()
	await process_frame
	check(main.album_ids.size() == 4, "fyra ägda kort (tre köpta och en hyrd)",
		"%d" % main.album_ids.size())
	check(not main.album_ids.has(str(ids[3])), "ett kort med rang 0 är inte med i albumet")
	# Sorteringen: kostnad först, sedan namn. Provet räknar om den och jämför — inte mot en lista
	# som kunde ha skrivits av samma fel som koden.
	var sorterad := true
	for i in range(1, main.album_ids.size()):
		if main._före(main.album_ids[i], main.album_ids[i - 1]):
			sorterad = false
	check(sorterad, "korten står i kostnadsordning",
		", ".join(main.album_ids).substr(0, 60))

	# 2b. DEN PERMANENTA KORTSAMLINGEN (M45): ett kort man vunnit av en boss är ägt utan att vara
	# köpt, syns i albumet, och följer med i startleken för varje ny bana ("tillgänglig mellan alla
	# banor"). Två exemplar av samma kort är två kort i leken, precis som referensen.
	var vunnet := str(ids[5])
	main.meta.samla(vunnet)
	main._show_album()
	await process_frame
	check(main.album_ids.has(vunnet), "ett kort ur bossamlingen syns i albumet", vunnet)
	main.meta.samla(vunnet)
	var lek: Array = main._start_lek()
	var i_leken := 0
	var i_grund := 0
	for k in lek:
		if (k as Cards.Card).id == vunnet:
			i_leken += 1
	for id in main.DECK:
		if str(id) == vunnet:
			i_grund += 1
	check(i_leken == 2 + i_grund, "båda exemplaren ligger i startleken (grundleken oräknad)",
		"%d i leken, %d i grundleken" % [i_leken, i_grund])
	check(lek.size() == main.DECK.size() + main.meta.hired.size() + 2,
		"leken är grundlek + hyrda + samlingen",
		"%d = %d + %d + 2" % [lek.size(), main.DECK.size(), main.meta.hired.size()])
	main.meta.samling.clear()      # tillbaka till provets utgångsläge: korten nedan räknas exakt

	# 3. DEN STORA VISNINGEN är det valda kortet, och radens valda kort står framträtt.
	main.album_index = 0
	main._show_album()
	await process_frame
	var stor: CardView = main.album_stor.get_child(0)
	check(stor.card.id == main.album_ids[0], "den stora visningen är det valda kortet",
		"%s (valt %s)" % [stor.card.id, main.album_ids[0]])
	var framträtt := 0
	for v in main.album_box.get_children():
		if (v as CardView).forward:
			framträtt += 1
	check(framträtt == 1, "exakt ett kort i raden står framträtt", "%d" % framträtt)

	# 4. BLÄDDRINGEN går runt i båda ändar.
	var n: int = main.album_ids.size()
	main._album_välj(-1)
	check(main.album_index == n - 1, "ett steg bakåt från första kortet landar på det sista",
		"%d av %d" % [main.album_index + 1, n])
	main._album_välj(n)
	check(main.album_index == 0, "ett steg framåt från sista kortet landar på det första",
		"%d" % main.album_index)
	main._album_välj(2)
	await process_frame
	check(main.album_index == 2 and main.album_stor.get_child(0).card.id == main.album_ids[2],
		"bläddringen byter den stora visningen")

	# 4b. KLICKET. Albumet ligger INNE i spelvyn (barn till `hud`, som är ett barn till SubViewporten),
	# och där kan musen stängas ute utan att tangenterna märker något: `gui_disable_input` på vyn eller
	# MOUSE_FILTER_IGNORE på korgen. Alex: "det går inte att välja ett kort där, det går inte att
	# klicka på dem". Provet skickar därför ett RIKTIGT musklick in i vyn på ett kort som inte är
	# framträtt, och ser att valet flyttar dit.
	var mål: CardView = null
	for v in main.album_box.get_children():
		if v is CardView and (v as CardView).index != main.album_index:
			mål = (v as CardView)
	var mål_index: int = mål.index      # fångas FÖRE klicket: albumet byggs om och kortet frigörs
	var mitten: Vector2 = mål.get_global_rect().get_center()
	var ned := InputEventMouseButton.new()
	ned.button_index = MOUSE_BUTTON_LEFT
	ned.pressed = true
	ned.position = mitten
	ned.global_position = mitten
	main._vy.push_input(ned)
	await process_frame
	await process_frame
	check(main.album_index == mål_index,
		"ett musklick i vyn väljer kortet (pekaren når panelen i spelvyn)",
		"klick på %d gav %d" % [mål_index, main.album_index])

	# 5. GÖMT UNDER EN KÖRNING. Samlingen töms först: körningen läser metat, och provet ska inte
	# lämna en påhittad samling efter sig till nästa prov i sviten.
	main.meta.ranks.clear()
	main.meta.hired.clear()
	main._start_run("stage_01", 20260919)
	await process_frame
	check(not main.album_panel.visible, "albumet är gömt under en körning")
	check(main.map_view.visible, "minikartan är framme under körningen i stället")

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
