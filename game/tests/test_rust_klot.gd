## RUSTNINGSKLOTET: MÄNGDEN UTAN BRÅK — OCH UPPDATERAT NÄR RUSTNINGEN ÄNDRAS (M119).
##
## Alex: *"När man mottagit en armor, så händer inget med armor-orben, den skall bara visa mängden
## armor, inget 1/1 eller 8/8. Har man 8 i armor skall det bara stå 8."* Det var TVÅ fel i samma rad:
##
##   (a) `_hud_sätt` skrev "%d/%d" även i rustningsklotet (hp och mana behåller sitt bråk med flit —
##       Alex nämnde bara rustningen, och provet mäter de två andra i samma andetag så att ett byte
##       inte kan smyga med dem).
##   (b) `_end_or_continue` — den ENDA vägen ut ur ett spelat kort, ur "spela allt" (P) och ur en
##       avslutad tur (E) — ritade om stridspanelen och handen men aldrig HUD:ens siffror. Klotet
##       stod därför still medan rustningen växte: "inget händer med armor-orben".
##
## Vägen är SPELARENS: tangenten 1-9 genom `_unhandled_input` (samma ingång som tangentbordet) och E
## för tur-slut — inte en genväg till `_hud_sätt`. Det provet ger är rustningsKORTET: startleken
## (`DECK`) har inget, så handen får ett `warding_ring` (+8) ur spelets EGEN kortdatabas.
##
## FLIT-BORT (beviset för att provet kan gå rött): sätt tillbaka `"%d/%d"` i `_hud_sätt` → tre fel
## ("utan MÄNGDEN", "och klotet visar den nya mängden", "klotet följde med ned"); ta bort
## `_refresh()` ur `_end_or_continue` → "klotet UPPDATERADES när rustningen ändrades" faller.
##
## KÖRNING: godot --headless --script res://tests/test_rust_klot.gd
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

## En tangent genom spelets EGEN ingång (`_unhandled_input`), precis som tangentbordet.
func _tangent(main, k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	main._unhandled_input(ev)

## Indexet i handen för ett kort som GER rustning (kortets EGNA effektlista), annars -1.
func _rustkort_i_handen(hand: Array) -> int:
	for i in hand.size():
		for e in hand[i].effects:
			if str(e.get("op", "")) == "armor":
				return i
	return -1


func _initialize() -> void:
	# Fotoläget först: provet startar en riktig körning och får inte skriva i spelarens profil.
	Meta.fotolage(true)
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# MENYN MÅSTE BORT FÖRST: `_visa_meny` ligger överst i `_unhandled_input` och tar VARJE tangent, så
	# en tangent i det här provet hade hamnat i menyn och ingenting hade rört spelet (mätt: kortet
	# spelades aldrig och klotet stod still — samma fel som provet skulle mäta, av fel skäl). Spelet
	# självt stänger menyn i `_meny_val`/`_fortsätt_körning` innan körningen startar.
	main._dölj_meny()
	await process_frame
	check(not main.meny.visible, "menyn är stängd, så tangenterna når spelet")
	main._start_run("stage_01", 20260919)
	await process_frame

	# Fram till en strid, och in i den med SPELARENS steg (samma väg som test_strid).
	var nod: Dungeon.FloorNode = null
	for n in main.run.explore.floor_ref.nodes:
		if n.kind == "encounter" and not n.cleared:
			nod = n
			break
	check(nod != null, "våningen har en strid att möta")
	if nod == null:
		print("  TOTALT: %d kontroller, %d fel" % [checks, fails])
		quit(1)
		return
	var varv := 0
	while main.run.explore.path_to(nod.pos).size() > 2 and varv < 300:
		varv += 1
		if main.run.explore.step_toward(nod.pos) != "":
			print("  FEL  kunde inte gå fram till striden: fast på %s" % str(main.run.explore.pos))
			break
	await process_frame
	main._step_forward()
	await process_frame
	await create_timer(0.5).timeout
	check(main.active_combat != null and not main.active_combat.over(),
		"striden är igång", str(nod.enemy_id))

	print("")
	print("— klotet visar MÄNGDEN, inte ett bråk —")
	# UTGÅNGSLÄGET: en körning med noll rustning. Raden är satt av spelets egen väg (starten av
	# körningen går genom `_refresh`), och den ska säga 0 — inte 0/1.
	var text_före: String = main.orb_rust.text
	var rust_före: float = main.active_combat.armor
	print("      före: klotet '%s', rustning %.0f, tak %.0f" % [text_före, rust_före, main.run.armor_tak])
	check(not text_före.contains("/"), "rustningsklotet visar ingen bråkdel", text_före)
	check(text_före == "%d" % int(rust_före), "och siffran är MÄNGDEN rustning",
		"klot '%s' mot rustning %.0f" % [text_före, rust_före])
	check(main.orb_hp.text.contains("/"), "hp-klotet behåller x/y", main.orb_hp.text)
	check(main.orb_mana.text.contains("/"), "och manaklotet med", main.orb_mana.text)

	print("")
	print("— ett rustningskort på +8, spelat med tangenten —")
	var i := _rustkort_i_handen(main.active_combat.hand)
	var gav_kortet := false
	if i < 0:
		main.active_combat.hand.append(main.db["warding_ring"])
		main._refresh_hand()
		await process_frame
		i = _rustkort_i_handen(main.active_combat.hand)
		gav_kortet = true
	check(i >= 0, "handen har ett rustningskort", "index %d%s" % [i, " (lagt dit av provet)" if gav_kortet else ""])
	if i >= 0:
		_tangent(main, KEY_1 + i)
		await create_timer(1.0).timeout
		var rust_efter: float = main.active_combat.armor
		print("      efter: klotet '%s', rustning %.0f" % [main.orb_rust.text, rust_efter])
		check(rust_efter > rust_före, "kortet gav rustning",
			"%.0f -> %.0f" % [rust_före, rust_efter])
		check(main.orb_rust.text == "%d" % int(rust_efter),
			"och klotet visar den nya mängden", "klot '%s' mot rustning %.0f"
				% [main.orb_rust.text, rust_efter])
		# DET HÄR ÄR ALEX' FEL: utan uppdateringen står klotet kvar på sitt gamla tal.
		check(main.orb_rust.text != text_före, "klotet UPPDATERADES när rustningen ändrades",
			"'%s' -> '%s'" % [text_före, main.orb_rust.text])

		print("")
		print("— tur-slut: fienden slår, och rustningen absorberar —")
		var inför_tur: float = main.active_combat.armor
		_tangent(main, KEY_E)
		# 0,6 s förvarning + 0,3 s slag + marginal: samma väntan som `_on_end_turn` själv tar.
		await create_timer(2.2).timeout
		if main.active_combat == null:
			print("      striden tog slut i turen — rustningen kan inte mätas vidare")
		else:
			var efter_tur: float = main.active_combat.armor
			print("      efter turen: klotet '%s', rustning %.0f" % [main.orb_rust.text, efter_tur])
			check(efter_tur < inför_tur, "fiendens slag åt av rustningen",
				"%.0f -> %.0f" % [inför_tur, efter_tur])
			check(main.orb_rust.text == "%d" % int(efter_tur),
				"och klotet följde med ned", "klot '%s' mot rustning %.0f"
					% [main.orb_rust.text, efter_tur])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
