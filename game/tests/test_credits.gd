## Provet för krediteringen (Alex 14/10): *"Jag vill ha en Credits-avdelning i spelet med, där vi
## öppet är tacksamma för allt som kunnat användas från andra utvecklare."*
##
## Provet vaktar fyra saker som annars går sönder tyst:
##   1. Att krediteringen GÅR ATT NÅ — genom menyns EGEN väg (välj + bekräfta), och att ESC lämnar
##      tillbaka. En rad som finns men inte svarar är samma klass av fel som en tom skärm.
##   2. Att varje paket vi använder står där. Provet jämför mot en EGEN lista, inte mot
##      data/credits.json: läste det samma fil som spelet ritar ur vore det en spegel av sig själv och
##      skulle inte märka att ett paket tappats ur filen.
##   3. Att effektpaketets ORDAGRANNA kreditrad står där — licensen kräver den uttryckligen.
##   4. Att RUBRIKEN finns på alla tretton språk och att ingen av de tolv andra faller tillbaka på
##      svenskan (`Tr.t` faller tillbaka på svenska, så en saknad översättning syns bara som en svensk
##      rad; den kontrollen är därför den som fångar ett språk som tappats).
##
## KÖRNING: godot --headless --script res://tests/test_credits.gd
extends SceneTree

## Effektpaketets kreditrad, ordagrant ur paketets license.txt:
##   "Pixel Art Assets - Will Tice / unTied Games"
## Licensen säger "please give attribution in the credits", och raden får inte skrivas om.
const FX_KREDIT := "Pixel Art Assets - Will Tice / unTied Games"

## Paketen spelet använder. Listan är provets egen sanning — se punkt 2 i filhuvudet.
const MÅSTE := ["Medieval Village MegaKit", "Fantasy Props MegaKit", "KayKit Dungeon Pack",
	"KayKit RPG Tools Bits", "KayKit Fantasy Weapons Bits", "SBS Tiny Texture Pack 1",
	"SBS Tiny Texture Pack 2", "SBS Horror Texture Pack", "Super Pixel Effects Gigapack",
	"32rogues", "400 Sounds Pack", "Horror SFX Free", "Item icons"]

var main: Node
var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _tangent(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	main._unhandled_input(ev)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Språket pinnas EFTER main, som i test_meny: `_ready` läser sparfilens språk och sätter det sist.
	Tr.set_lang("sv")
	Meta.fotolage(true)
	# Provet visar menyn självt (den visas bara vid en riktig spelarstart) och skriver INTE spelarens
	# sparfil: Meta.fotolage ovan leder spararen till en provfil.
	main.meta.korning = {}
	main.meta.save()
	main._visa_meny()
	await process_frame
	await process_frame

	print("")
	print("— krediteringen nås genom menyn —")
	# Raden letas upp på TEXT, inte på ett index: ett index i provet vore en andra sanning om
	# menyordningen, och den glider isär så fort en rad flyttas.
	var rubriker: Array = main._meny_rubriker()
	var idx := rubriker.find(Tr.t("ui.meny.credits", "TACK TILL"))
	check(idx >= 0, "TACK TILL står i menyns rubriklista", str(rubriker))
	check(main.credits_panel != null and not main.credits_panel.visible,
		"krediteringen är gömd medan menyn visas")
	main.meny.välj(idx)
	await process_frame
	main.meny.bekräfta()
	await process_frame
	check(main.credits_panel.visible, "menyns rad öppnar krediteringen (samma väg som ALTERNATIV)",
		"rad %d" % idx)
	check(main.credits_rader.size() > 0, "krediteringen har rader",
		"%d rader" % main.credits_rader.size())
	check(not main.credits_rubrik.text.strip_edges().is_empty(),
		"rubriken står i rutan", main.credits_rubrik.text)

	# Panelen ska rymmas i fönstret: en ruta som skjuter ut upptill döljer den översta raden. I
	# huvudlöst läge (sviten) är fönstret 64x64 och ingenting ryms — samma grind som test_gui har
	# (`måttbart`): mätningen hör till en körning med ett riktigt fönster, inte hit.
	var ruta := main.get_viewport().get_visible_rect().size
	if ruta.y >= 400.0:
		check(main.credits_panel.position.y >= 0.0
				and main.credits_panel.position.y + main.credits_panel.size.y <= ruta.y,
			"panelen ryms i fönstret", "y %.0f + %.0f mot %.0f" % [main.credits_panel.position.y,
				main.credits_panel.size.y, ruta.y])
	else:
		print("      (panelens höjd mäts bara i ett fönster som rymmer den: %.0f px högt här, %.0f px rad behövs)"
			% [ruta.y, main.credits_panel.size.y])

	print("")
	print("— varje paket vi använder står där —")
	# Texten läses ur de RITADE raderna, inte ur filen: det är den spelaren ser.
	var sedd := ""
	for r in main.credits_rader:
		sedd += r.text + "\n"
	var borta := []
	for namn in MÅSTE:
		if not sedd.contains(namn):
			borta.append(namn)
	check(borta.is_empty(), "alla %d paket står i rutan" % MÅSTE.size(), "borta: %s" % ", ".join(borta))
	check(sedd.contains(FX_KREDIT), "effektpaketets kreditrad står ORDAGRANT: \"%s\"" % FX_KREDIT)
	check(sedd.contains("32rogues") and sedd.contains("Seth Boyles"),
		"32rogues tackas (Seth Boyles) — tack vare, även om filerna inte ligger i repot")
	check(main.credits_tack.text.contains("CREDITS.md"),
		"hänvisningen till CREDITS.md står i rutan", main.credits_tack.text)

	print("")
	print("— rubriken finns på alla tretton språk —")
	var sv_titel := Tr.t("ui.credits.titel")
	var tomma := []
	var svenska := []
	for kod in Tr.codes():
		Tr.set_lang(kod)
		var titel := Tr.t("ui.credits.titel").strip_edges()
		if titel.is_empty():
			tomma.append("%s (rubrik)" % kod)
		elif kod != "sv" and titel == sv_titel:
			svenska.append(kod)
		if Tr.t("ui.credits.tack").strip_edges().is_empty():
			tomma.append("%s (tackrad)" % kod)
	Tr.set_lang("sv")
	check(tomma.is_empty(), "rubriken och tackraden finns i alla %d språk" % Tr.codes().size(),
		"tomma: %s" % ", ".join(tomma))
	# En rad som faller tillbaka på svenskan är en rad spelaren inte kan läsa på sitt språk — samma
	# fel som en tom ruta, bara svårare att se.
	check(svenska.is_empty(), "ingen av de tolv andra visar svensk rubrik", ", ".join(svenska))

	print("")
	print("— ESC lämnar tillbaka till menyn —")
	_tangent(KEY_ESCAPE)
	await process_frame
	check(not main.credits_panel.visible, "ESC stänger krediteringen")
	check(main.meny.visible, "menyn är kvar bakom (samma väg tillbaka som ALTERNATIV)")

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
