## Provet för startmenyn, splashbilden, CRT-lagret, musiken och ALTERNATIV (M39).
##
## Alex gav två referensbilder och sa: *"Här har du en intro och en splashscreen. Lägg in startmenyn för
## 'Nytt spel' osv enligt sista bilden"* — och *"Där har du även lite känslan jag är ute efter"*.
## Provet mäter det som lätt tappas utan att synas: att raderna finns och är klickbara, att märket
## följer valet, att en spärrad rad säger varför, att spellistan går vidare (och inte slingar samma låt),
## att CRT-lagret
## ligger överst utan att äta pekaren, och att LADDA SPEL faktiskt ÅTERUPPTAR en sparad körning.
##
## KÖRNING: godot --headless --script res://tests/test_meny.gd
extends SceneTree

const SPARAT_PROV := "user://test_meny_korning.json"

var main: Node

func check(ok: bool, what: String, detail: String = "") -> void:
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
		fails += 1
	checks += 1

var fails := 0
var checks := 0

## En tangent genom spelets EGEN ingång (`_unhandled_input`), inte genom en kopia av grenarna.
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
	# REN SPARFIL TILL ATT BÖRJA MED. En körning sparar sig själv (det är meningen: LADDA SPEL ska ha
	# något att ladda), och en tidigare provkörning — eller ett tidigare prov i sviten — kan ha lämnat en
	# sparad körning i fönsterlägets fil. Utan den här raden beror provet på vad som råkade köras före:
	# mätt i sviten blev LADDA SPEL valbar, valet startade en körning, och de följande sju kontrollerna
	# föll på att menyn hade gömt sig.
	main.meta.korning = {}
	main.meta.save()
	# Menyn visas bara vid en riktig spelarstart: provet visar den själv, som `-- meny` gör.
	main._visa_meny()
	await process_frame
	await process_frame

	print("")
	print("— menyn —")
	check(main.meny != null and main.meny.visible, "startmenyn finns och syns")
	# Antalet läses ur menyns EGEN lista, inte ur en siffra i provet: en rad som läggs till ska fällas
	# av att texten saknas (nästa kontroll), inte av att provet räknade fem.
	check(main.meny.rader.size() == main._meny_rubriker().size(), "en rad per rubrik",
		"%d rader, %d rubriker" % [main.meny.rader.size(), main._meny_rubriker().size()])
	var texter := []
	for r in main.meny.rader:
		texter.append(r.text)
	check(texter == ["NYTT SPEL", "SPARA SPEL", "LADDA SPEL", "ALTERNATIV", "AVSLUTA",
			"BANEDITOR (tillfällig)", "FIENDEEDITOR (tillfällig)"],
		"valen står i referensens ordning", str(texter))
	check(main.meny.splash != null and main.meny.splash.texture != null,
		"splashbilden är laddad (%s)" % ("ja" if main.meny.splash.texture != null else "nej"))
	check(main.meny.splash.size == main.get_viewport().get_visible_rect().size,
		"splashbilden täcker fönstret", "%.0fx%.0f" % [main.meny.splash.size.x, main.meny.splash.size.y])

	print("")
	print("— märket följer valet —")
	check(main.meny.valt_index == 0, "första valet är markerat från början")
	var rad0: Label = main.meny.rader[0]
	var rad3: Label = main.meny.rader[3]
	check(main.meny.markör.position.x + main.meny.markör.size.x <= rad0.position.x,
		"märket står till VÄNSTER om raden",
		"märket slutar på x %.0f, raden börjar på %.0f"
			% [main.meny.markör.position.x + main.meny.markör.size.x, rad0.position.x])
	var mitt_rad: float = rad0.position.y + rad0.size.y * 0.5
	# Uttryckligen typade: `main` är en Node, så `main.meny...` har ingen känd typ och `:=` kan inte
	# sluta sig till en (GDScript vägrar gissa).
	var mitt_märke: float = main.meny.markör.position.y + main.meny.markör.size.y * 0.5
	check(absf(mitt_rad - mitt_märke) <= 2.0, "märket står i höjd med radens mitt",
		"skillnad %.1f px" % absf(mitt_rad - mitt_märke))
	main.meny.flytta(3)
	await process_frame
	check(main.meny.valt_index == 3 and main.meny.markör.position.y > rad0.position.y,
		"märket flyttar med valet", "valt %d, märket y %.0f" % [main.meny.valt_index,
			main.meny.markör.position.y])

	print("")
	print("— en spärrad rad tiger inte —")
	# Två rader är spärrade i utgångsläget, av två olika skäl: ingen körning att spara, och inget
	# sparat läge att ladda. Båda ska säga sitt.
	check(main.meny.spärrade.has(1), "SPARA SPEL är spärrad utan pågående körning",
		str(main.meny.spärrade.get(1, "")))
	check(main.meny.spärrade.has(2), "LADDA SPEL är spärrad utan sparad körning",
		str(main.meny.spärrade.get(2, "")))
	main.meny.välj(2)
	await process_frame
	main.meny.bekräfta()
	await process_frame
	check(main.meny.botten.text.contains("sparad"),
		"orsaken står i bottenraden när en spärrad rad väljs", main.meny.botten.text.split("\n")[0])

	print("")
	print("— klicket (samma väg som en riktig mus) —")
	var rad2: Label = main.meny.rader[3]           # ALTERNATIV (SPARA SPEL ligger före LADDA SPEL)
	var mitten: Vector2 = rad2.get_global_rect().get_center()
	var ned := InputEventMouseButton.new()
	ned.button_index = MOUSE_BUTTON_LEFT
	ned.pressed = true
	ned.position = mitten
	ned.global_position = mitten
	main.get_window().push_input(ned)
	await process_frame
	await process_frame
	check(main.alt_panel.visible, "ett musklick på ALTERNATIV öppnar panelen",
		"klick på %.0f,%.0f" % [mitten.x, mitten.y])
	for i in main.alt_rader.size():
		print("      alternativ %d: %s" % [i, main.alt_rader[i].text])
	check(main.alt_rader.size() == 4, "fyra rader: språk, CRT, musik och spår")
	check(main.alt_rader[0].text.contains("språk"), "första raden är språket")
	check(main.alt_rader[1].text.contains("CRT"), "andra raden är CRT-läget")
	check(main.alt_rader[2].text.contains("musik"), "tredje raden är musiken")
	# Jukeboxen (M54): raden visar spåret som spelar, och ett tryck byter till nästa i mappen.
	var spår_innan: String = main.musik.nuvarande()
	check(main.alt_rader[3].text.contains(spår_innan), "fjärde raden visar spåret som spelar",
		main.alt_rader[3].text)
	main._alt_byt(3)
	await process_frame
	check(main.musik.nuvarande() != spår_innan, "och ett tryck byter låt",
		"%s -> %s" % [spår_innan, main.musik.nuvarande()])
	check(main.alt_rader[3].text.contains(main.musik.nuvarande()), "raden följer bytet",
		main.alt_rader[3].text)

	print("")
	print("— CRT-lagret —")
	check(main.crt != null and main.crt.visible, "CRT-lagret är på (standard)")
	check(main.crt.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"CRT-lagret tar ingen pekare (annars blev menyn oklickbar)")
	check(main.crt.get_index() == main.crt.get_parent().get_child_count() - 1,
		"CRT-lagret ligger ÖVERST (det läser skärmen bakom sig)")
	check(is_equal_approx(main.crt.styrka(), 1.0), "styrkan går att mäta", "%.2f" % main.crt.styrka())
	var var_på: bool = main.meta.crt_på
	main._alt_byt(1)
	await process_frame
	check(main.meta.crt_på != var_på and main.crt.visible == main.meta.crt_på,
		"CRT-raden slår av och på lagret", "meta %s, lagret syns %s"
			% ["på" if main.meta.crt_på else "av", "ja" if main.crt.visible else "nej"])
	main._alt_byt(1)
	await process_frame

	print("")
	print("— musiken —")
	# M54: menyns gamla stycke är nu ett spår i spellistan. Slingan är AV med flit — jukeboxen går
	# vidare till nästa låt i stället för att mala samma i tre minuter.
	check(main.musik != null and main.musik.stream != null, "musikstycket är laddat")
	check(main.musik.antal() >= 6, "spellistan har låtarna ur mappen", "%d spår" % main.musik.antal())
	if main.musik.stream is AudioStreamMP3:
		check(not (main.musik.stream as AudioStreamMP3).loop, "ingen låt slingar — listan går vidare")
	check(main.musik.playing, "musiken spelar medan menyn är framme")
	var s_av: bool = main.meta.musik_på
	main._alt_byt(2)
	await process_frame
	check(main.meta.musik_på != s_av and main.musik.playing == main.meta.musik_på,
		"musik-raden stänger av och på ljudet")
	main._alt_byt(2)
	await process_frame

	print("")
	print("— NYTT SPEL lämnar menyn —")
	main.alt_panel.visible = false
	main.meny.välj(0)
	await process_frame
	main.meny.bekräfta()
	await process_frame
	await process_frame
	check(not main.meny.visible, "menyn göms när NYTT SPEL väljs")
	check(main.shell != "körning" and main.by_view.visible, "byn tar över", main.shell)
	# M54: musiken fortsätter in i byn och banorna. Förut tystnade den när körningen började, och
	# Alex ville ha spellistan just där ("när man är i själva banorna, eller byn").
	check(main.musik.playing, "musiken fortsätter när spelet börjar", main.musik.nuvarande())

	print("")
	print("— LADDA SPEL återupptar en sparad körning —")
	# En körning spelas fram några steg, sparas, och återupptas: våning, HP och leken ska komma tillbaka.
	main._start_run("stage_01", 20260919, 2)
	await process_frame
	main.run.hp = 37.0
	main.run.xp = 12
	main._spara_körning()
	var sparat: Dictionary = main.meta.korning.duplicate(true)
	check(int(sparat.get("floor", -1)) == 2, "sparfilen har våningen", "våning %d" % (int(sparat.get("floor", 0)) + 1))
	check(int(sparat.get("deck", []).size()) == main.run.deck.size(), "sparfilen har hela leken",
		"%d kort" % int(sparat.get("deck", []).size()))
	check(is_equal_approx(float(sparat.get("hp", 0.0)), 37.0), "sparfilen har HP", "%.0f" % float(sparat.get("hp", 0.0)))

	main.run.hp = 5.0                      # rör körningen, så att återupptagandet syns
	main._start_run("stage_01", 1, 0)      # ... och en helt ny körning på våning 1
	await process_frame
	# Den sparade raden skrivs EFTER den nya körningen: en körning som startar sparar sig själv direkt
	# (det är samma rad `_spara_körning` skriver), så annars vore det den nya körningen som återupptogs.
	main.meta.korning = sparat.duplicate(true)
	main._dölj_meny()
	main._fortsätt_körning()
	await process_frame
	check(main.run.floor_index == 2, "LADDA SPEL kommer tillbaka till våningen",
		"våning %d" % (main.run.floor_index + 1))
	check(is_equal_approx(main.run.hp, 37.0), "HP är det sparade", "%.0f" % main.run.hp)
	check(main.run.xp == 12, "xp är det sparade", "%d" % main.run.xp)
	check(main.run.deck.size() == int(sparat.get("deck", []).size()), "leken är den sparade",
		"%d kort" % main.run.deck.size())

	# En avslutad körning lämnar inget att fortsätta: raden i menyn ska bli mörk igen.
	main.run.finished = true
	main._spara_körning()
	check(main.meta.korning.is_empty(), "en avslutad körning tar bort det sparade läget")
	main.run.finished = false

	print("")
	print("— ESC i en bana: hem till menyn, och Spara spel —")
	# Alex: "Escape när man är i en bana skall öppna huvudmenyn, och då skall man även kunna välja
	# 'Spara spel' så när man tar 'Ladda spel' från huvudmenyn så fortsätter den från var man befann sig."
	check(main.shell == "körning" and main.run != null and not main.run.finished,
		"en körning är igång", main.shell)
	main.run.floor_index = 3           # en våning man kan känna igen i sparfilen
	_tangent(KEY_ESCAPE)
	await process_frame
	check(main.meny.visible, "ESC i banan öppnar huvudmenyn")
	check(not main.meny.spärrade.has(1), "SPARA SPEL går att välja mitt i en körning")

	# Ett tryck först, så att signaturen är i takt med körningen. Det är ANDRA trycket som avgör om
	# raden skriver ändå — då har ingenting ändrats sedan förra sparningen.
	main.meny.välj(1)
	main.meny.bekräfta()
	await process_frame

	# Beviset för att trycket SKRIVER filen: ta bort den först. Spararen har en signatur som gör att
	# den tiger när inget ändrats (HUD:en ritar om 55 gånger i sekunden) — men en rad man TRYCKER på
	# ska göra något varje gång, och en borttagen fil är det tydligaste vittnet.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.PATH))
	check(not FileAccess.file_exists(Meta.PATH), "sparfilen är borta före trycket")
	main.meny.välj(1)
	main.meny.bekräfta()
	await process_frame
	check(main.meny.botten.text.contains("sparat"), "kvittensen står i bottenraden",
		main.meny.botten.text.split("\n")[0])
	check(int(main.meta.korning.get("floor", -1)) == 3, "sparfilen har våningen man stod på",
		"våning %d" % (int(main.meta.korning.get("floor", 0)) + 1))
	check(FileAccess.file_exists(Meta.PATH),
		"trycket skriver filen även när inget ändrats (annars vore raden tyst)")

	# ... och ESC i menyn lämnar tillbaka till banan, med körningen i behåll.
	_tangent(KEY_ESCAPE)
	await process_frame
	check(not main.meny.visible and main.shell == "körning", "ESC i menyn går tillbaka till banan",
		main.shell)
	check(main.run.floor_index == 3, "körningen är kvar där den var",
		"våning %d" % (main.run.floor_index + 1))
	# Kvittensen hör till menyn: nästa gång den visas är den borta.
	_tangent(KEY_ESCAPE)
	await process_frame
	check(main.meny.visible and not main.meny.botten.text.contains("sparat"),
		"kvittensen står inte kvar nästa gång menyn visas", main.meny.botten.text.split("\n")[0])
	_tangent(KEY_ESCAPE)
	await process_frame

	# Städa: provet får inte lämna en påhittad körning i sparfilen till nästa prov i sviten.
	main.meta.korning = {}
	main.meta.save()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
