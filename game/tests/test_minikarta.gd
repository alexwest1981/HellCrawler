## Provet för minikartan och dess teckenförklaring efter M32: de ligger i den SVARTA MARGINALEN,
## utanför spelvyn.
##
## Alex: *"Rutan med döskalle, strid, kista osv, den ligger nu i spelytan, den skall helst vara ren"*
## och *"skulle vilja flytta även minimap upp till högra hörnet"*.
##
## MÄTT FÖRE (skärmbild 1280x720, samma körning): kartan stod i (0,0) och orden låg på x 14..37,
## y 66..123 — i den VÄNSTRA marginalen, över statusraden, i halv storlek. Orsaken var ordningen och
## inte formeln: `_placera_vy` kördes i `_bygg_vy` innan minikartan och tipsen fanns, och den hakar
## bara på fönstrets storleksbyte — ett fönster som startar i 1280x720 ändrar sig aldrig. Provet
## mäter därför kartans ruta vid START, utan att någon rör fönstret.
##
## Provet biter på fyra saker som är lätta att tappa:
##   1. att kartan läggs i FÖNSTRETS lager (ligger den kvar i vyn ritas den i 480x270 och skalas upp),
##   2. att rutan hamnar i marginalen till höger om vyn, med fönstrets heltal som skala,
##   3. att orden (alla 13 språk, värst polska) ryms i marginalen — och att de ritas i FÖNSTRETS
##      storlek, inte uppskalade (den grenen saknades: en nod i marginalen har ingen korg att räkna ur,
##      och då ritades ingenting alls),
##   4. att stridspanelen inte skär in i kartan eller ordkolumnen.
##
## Fönstret i en huvudlös körning är 64x64 och går inte att sätta (mätt: `root.size` studsar tillbaka
## till 64x64). De två första punkterna mäts därför i DEN HÄR körningens fönster — att positionen är
## satt alls — och marginalen mäts i mål-fönstret, som läses ur projektets EGNA inställning
## (display/window/size/window_*_override) i stället för att skrivas in som ett tal i provet.
##
## KÖRNING: godot --headless --script res://tests/test_minikarta.gd
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

## Överlappet mellan två rutor, i px. Noll (eller negativt) = ingen krock.
func _överlapp(a: Rect2, b: Rect2) -> Vector2:
	return Vector2(minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x),
		minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y))

func _initialize() -> void:
	# Fotoläget först: provet startar en riktig körning och får inte skriva i spelarens profil.
	Meta.fotolage(true)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_run("stage_01", 20260919)
	await process_frame
	main._placera_vy()
	await process_frame

	var fönster: Vector2 = main.get_viewport().get_visible_rect().size
	var skala: float = main._vy_korg.scale.x
	print("  den här körningens fönster är %.0fx%.0f, skalan x%.0f" % [fönster.x, fönster.y, skala])

	print("")
	print("— kartan läggs i FÖNSTRETS lager, och får sin plats vid start —")
	check(main.map_view.get_viewport() == main.get_viewport(),
		"minikartan ritas i fönstret, inte i den lilla vyn")
	check(main.map_view.scale.x == skala, "kartan skalas med fönstrets heltal",
		"x%.0f mot x%.0f" % [main.map_view.scale.x, skala])
	# Formeln står här med flit som en egen rad: det är DEN kontrollen som fällde den gamla koden,
	# där kartan aldrig blev placerad och stod kvar i (0,0) över statusraden.
	check(main.map_view.position == Vector2(fönster.x - main.MapView.MAP_SIZE.x * skala - main.MARGINAL,
			main.MARGINAL), "kartan har sin plats (inte kvar i 0,0)",
		"@ %.0f,%.0f" % [main.map_view.position.x, main.map_view.position.y])
	# Och att platsen sätts EFTER att kartan byggts. Kontrollen läser källan, och det är med flit:
	# i en huvudlös körning byter fönstret storlek av sig självt (100x100 → 64x64), så
	# storlekssignalen räddar positionen och felet syns bara i ett riktigt fönster (MÄTT i
	# skärmbilden på 1280x720: kartan stod kvar i 0,0 över statusraden).
	var källa := FileAccess.get_file_as_string("res://main.gd").split("\n")
	var i_runt := -1
	for i in källa.size():
		if str(källa[i]).strip_edges() == "_bygg_runt()":
			i_runt = i
	check(i_runt >= 0, "källan bygger HUD:en runt vyn")
	var nästa := ""
	if i_runt >= 0:
		for j in range(i_runt + 1, källa.size()):
			var t: String = str(källa[j]).strip_edges()
			if t.is_empty() or t.begins_with("#"):
				continue
			nästa = t
			break
	check(nästa == "_placera_vy()", "och placerar kartan efter att den byggts", nästa)

	# Mål-fönstret: projektets egen fönsterstorlek (den Alex spelar i), och skalans heltal ur vyn.
	var mål := Vector2(
		float(ProjectSettings.get_setting("display/window/size/window_width_override", 1280)),
		float(ProjectSettings.get_setting("display/window/size/window_height_override", 720)))
	var mål_skala: float = floorf(minf(mål.x / float(main.VY.x), mål.y / float(main.VY.y)))
	main._placera_karta(mål, mål_skala)
	await process_frame
	var vy := Rect2((mål - Vector2(main.VY) * mål_skala) / 2.0, Vector2(main.VY) * mål_skala)
	var karta := Rect2(main.map_view.position, main.MapView.MAP_SIZE * main.map_view.scale)
	print("  mål-fönstret %.0fx%.0f: vyn %.0fx%.0f @ %.0f,%.0f, marginal till höger %.0f px, kartan %.0fx%.0f @ %.0f,%.0f"
		% [mål.x, mål.y, vy.size.x, vy.size.y, vy.position.x, vy.position.y,
			mål.x - vy.end.x, karta.size.x, karta.size.y, karta.position.x, karta.position.y])

	print("")
	print("— kartan ligger i MARGINALEN, utanför spelvyn —")
	check(karta.position.x >= vy.end.x, "kartan ligger helt till höger om spelvyn",
		"kartans vänsterkant %.0f mot vyns högerkant %.0f" % [karta.position.x, vy.end.x])
	check(karta.end.x <= mål.x, "kartans högerkant ryms i fönstret",
		"%.0f av %.0f" % [karta.end.x, mål.x])
	var kolumn := Rect2(karta.position,
		Vector2(karta.size.x, (main.MapView.MAP_SIZE.y + main.MapView.LEGEND_HÖJD) * mål_skala))
	check(kolumn.end.y <= mål.y, "kartans ordkolumn ryms i fönstret",
		"underkant %.0f av %.0f" % [kolumn.end.y, mål.y])
	# Den BREDASTE raden i något av de 13 språken, mätt ur tabellerna (MapView.steg) och räknad om
	# till fönsterpx: märket och luften ligger till vänster om ordet.
	var text_vänster: float = karta.position.x + (main.MapView.MÄRKE_PX + main.MapView.LUFT) * mål_skala
	var rad_bredd: float = main.map_view.steg() * mål_skala
	check(text_vänster + rad_bredd <= mål.x, "den bredaste ordraden (13 språk) ryms i marginalen",
		"%.0f px text från %.0f, fönstret är %.0f" % [rad_bredd, text_vänster, mål.x])

	print("")
	print("— orden ritas i FÖNSTRETS upplösning (där de står) —")
	# Orden hör till TECKENFÖRKLARINGEN, som sedan M75 visas först när man klickar på kartan — provet
	# fäller ut den (samma flagga som klicket sätter) och mäter raderna som förut.
	main.map_view.visa_legend = true
	var rader: Array = main.map_view.ord_rader()
	check(rader.size() == main.MapView.NODER.size(), "ett ord per märke", "%d rader" % rader.size())
	# Samma omräkning som `UiText._draw` använder — en nod i marginalen har ingen korg, och den
	# grenen saknades helt: skalans heltal kom ur korgen och fanns inte, så ingenting ritades.
	var w := UiText.i_fönstret(rader[0], main.map_view.textlager._mapp())
	var ruta: Rect2 = main.map_view.rad_ruta(0)
	check(w["storlek"] == main.MapView.ORD_FONT * int(mål_skala),
		"orden ritas i ORD_FONT x skalans heltal", "%d px" % int(w["storlek"]))
	check(absf(w["pos"].x - (karta.position.x + ruta.position.x * mål_skala)) < 0.6,
		"ordet står till höger om sitt märke, i fönstrets mått",
		"x %.0f mot %.0f" % [w["pos"].x, karta.position.x + ruta.position.x * mål_skala])
	check(w["pos"].x >= karta.position.x and w["pos"].y >= karta.end.y,
		"och innanför marginalen, under kartans rutor", "%.0f,%.0f" % [w["pos"].x, w["pos"].y])

	print("")
	print("— stridspanelen krockar inte med kartan eller orden —")
	main.battle_panel.visible = true
	main._place_panel(main.battle_panel, true)
	await process_frame
	# Panelens ruta i MÅL-fönstret: vyns plats där (vy) + panelens egen ruta gånger skalans heltal —
	# samma omräkning som korgen gör i det riktiga fönstret, men räknad för 1280x720 i stället för
	# för den här körningens 64x64.
	var panel := Rect2(vy.position + main.battle_panel.position * mål_skala,
		main.battle_panel.size * mål_skala)
	var o := _överlapp(panel, karta)
	check(o.x <= 0.0 or o.y <= 0.0, "stridspanelen går inte in i kartan",
		"panel %.0f..%.0f, %.0f..%.0f mot kartan %.0f..%.0f, %.0f..%.0f"
			% [panel.position.x, panel.end.x, panel.position.y, panel.end.y,
				karta.position.x, karta.end.x, karta.position.y, karta.end.y])
	var ok := _överlapp(panel, kolumn)
	check(ok.x <= 0.0 or ok.y <= 0.0, "och inte in i ordkolumnen",
		"panel till %.0f, kolumnen från %.0f (överlapp %.0f,%.0f)"
			% [panel.end.y, kolumn.position.y, ok.x, ok.y])

	## RITORDNINGEN (M62). Kartan låg i HUD-lagret men UNDER ramen och CRT-lagret: den ritades
	## (mätt: `_draw` körde med rätt ruta, 76x60 @ 1122,6) och syntes ändå inte alls i skärmbilden —
	## marginalens metall låg ovanpå. Och kartans ord låg i ett textlager UNDER HUD:en, så kartans
	## egen bakgrund målade över sin egen teckenförklaring (märkena syntes, orden inte).
	## Provet mäter därför ORDNINGEN, som är det som gick sönder: z över ramen, ordlagret över HUD:en.
	print("")
	print("— ritordningen —")
	check(main.map_view.z_index > 0,
		"kartan ritas över ramen och CRT-lagret (z %d)" % main.map_view.z_index)
	var textlager: Node = main.map_view.textlager
	check(textlager != null and textlager.get_parent() != null
			and (textlager.get_parent() as CanvasLayer).layer > main._runt.layer,
		"och dess ord ligger över HUD:en (lager %d mot HUD:ens %d)"
			% [textlager.get_parent().layer if textlager != null and textlager.get_parent() != null else -1,
				main._runt.layer])

	## MANAKÄRLET (M64). Kärlet låg på samma höjd som hälsan — men minikartan äger toppen av höger
	## kolumn, och sedan kartan blev synlig igen (M62) låg kartan och teckenförklaringen ovanpå
	## kärlet (mätt: kartan 1122,6..1274,126 mot kärlet 1124,93..1276,245). Alex såg följden som
	## *"manan är slut men cirkeln är halvfull"*: den övre delen av kärlet var kartan. Provet mäter
	## att rutorna inte möts.
	print("")
	print("— manakärlet —")
	var kskala: float = maxf(1.0, roundf(main.map_view.scale.x))
	var kartblock := Rect2(main.map_view.position,
		Vector2(main.MapView.MAP_SIZE.x, main.MapView.MAP_SIZE.y + main.MapView.LEGEND_HÖJD) * kskala)
	var manaruta := Rect2(main.orb_mana.position, main.orb_mana.size * kskala)
	# Kärlen står i VÄNSTER marginal nu; kontrollen att inget av dem ryms utanför fönstret kostade
	# ingenting att behålla och fångade en riktig miss (manakärlet 32 px utanför vänsterkanten).
	# "Kärlet ryms i fönstret" mäts i test_gui, där en riktig strid har lagt ut HUD:en. Här är
	# provet på kartan, och ett kärl som inte ritats har kvar sin förra position — en mätning av
	# den säger ingenting om spelet.
	check(not manaruta.intersects(kartblock), "manakärlet ligger inte under kartan",
		"kärl %.0f..%.0f, %.0f..%.0f mot kartan %.0f..%.0f, %.0f..%.0f"
			% [manaruta.position.x, manaruta.end.x, manaruta.position.y, manaruta.end.y,
				kartblock.position.x, kartblock.end.x, kartblock.position.y, kartblock.end.y])

	print("")
	print("— teckenförklaringen är en ruta man tar fram (M75) —")
	# Alex: *"Informationen om vad varje grej på kartan kan vara en ruta som visas om man trycker på
	# kartan eller en knapp, men behöver inte vara synlig hela tiden."*
	# Provet anropar `_gui_input` DIREKT (kontrollen är att klicket når fram, och den mäts av
	# `mouse_filter`-raden nedanför): en riktig mus kräver ett fönster med en pekare, och huvudlöst
	# läge har ingen. Det som mäts här är VÄXLINGEN och att orden följer med.
	main.map_view.visa_legend = false   # provet fällde ut den ovan; läget ska mätas från stängt
	check(not main.map_view.visa_legend, "teckenförklaringen är dold från början")
	check(main.map_view.ord_rader().size() == 1 and str(main.map_view.ord_rader()[0]["text"]) == "?",
		"och under kartan står bara ett frågetecken (tipset om att det går att trycka)",
		"%d rad(er)" % main.map_view.ord_rader().size())
	check(main.map_view.mouse_filter == Control.MOUSE_FILTER_STOP, "kartan tar emot klick")
	var klick := InputEventMouseButton.new()
	klick.button_index = MOUSE_BUTTON_LEFT
	klick.pressed = true
	main.map_view._gui_input(klick)
	check(main.map_view.visa_legend and main.map_view.ord_rader().size() == main.MapView.NODER.size(),
		"ett klick visar alla orden", "%d rader" % main.map_view.ord_rader().size())
	main.map_view._gui_input(klick)
	check(not main.map_view.visa_legend and main.map_view.ord_rader().size() == 1,
		"och ett klick till gömmer dem igen")
	var släpp := InputEventMouseButton.new()
	släpp.button_index = MOUSE_BUTTON_LEFT
	släpp.pressed = false
	main.map_view._gui_input(släpp)
	check(not main.map_view.visa_legend, "ett SLÄPP växlar inte (annars blev det två slag per klick)")

	print("")
	print("— %d kontroller, %d fel —" % [checks, fails])
	quit(1 if fails > 0 else 0)
