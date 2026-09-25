## Prov för trädeditorn (M95): att noderna går att flytta, att mappningen bildandel <-> pixel är
## konsistent, och att filen editorn sparar är samma fil vyn läser.
##
## Provet skriver ALDRIG i spelets data: socketfilen skickas till en user://-temp och läses tillbaka
## därifrån. Läsvägen är däremot spelets egen (TreeSockets), så ett formatfel syns här.
##
## BITE: kontrollerna jämför vad som skrevs med vad som kom tillbaka. Skriver skrivaren ingenting
## (eller skriver fel fält) faller de — provet är alltså inte grönt av misstag.
extends SceneTree

var fails := 0
var checks := 0


func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok  %s" % what)
	else:
		fails += 1
		print("  FEL %s%s" % [what, ("  — " + detail) if not detail.is_empty() else ""])


func _initialize() -> void:
	Meta.fotolage(true)                    # editorn får aldrig röra spelarens sparfil
	var scene: PackedScene = load("res://editor/trad_editor.tscn")
	check(scene != null, "trädeditorns scen går att läsa")
	if scene == null:
		quit(1)
		return
	var editor: Control = scene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame

	check(editor.view != null, "editorn ritar spelets EGEN trädvy (inte en kopia)")

	# KOPPLINGEN: shift+drag mellan två noder skriver VILKA noden väntar på, och ringar vägras.
	editor.selected = "iron_1"
	editor.toggle_requirement("body_main", "iron_1")
	check((editor.records["iron_1"] as Dictionary)["requires"].has("body_main"),
		"ett drag mellan två noder skriver kopplingen",
		str(editor.records["iron_1"]["requires"]))
	editor.toggle_requirement("body_main", "iron_1")
	check(not (editor.records["iron_1"] as Dictionary)["requires"].has("body_main"),
		"och samma drag tar bort den igen")
	# En koppling TVÄRSÖVER grenarna är tillåten (ordningen får korsa grenar).
	editor.toggle_requirement("body_main", "iron_1")
	check((editor.records["iron_1"] as Dictionary)["requires"].has("body_main"),
		"en koppling tvärs över grenarna går igenom",
		str(editor.records["iron_1"]["requires"]))
	editor.toggle_requirement("body_main", "iron_1")
	# En RING vägras: iron_1 väntar redan på iron_main (genererat), så iron_main kan inte vänta på
	# iron_1 — då kunde ingen av dem köpas, någonsin.
	editor.toggle_requirement("iron_1", "iron_main")
	check(not (editor.records["iron_main"] as Dictionary).get("requires", []).has("iron_1"),
		"men en ring vägras (den skulle låsa båda noderna för alltid)",
		str(editor.records["iron_main"]["requires"]))
	check(editor.ids.size() > 0, "alla trädnoder är med i placeringslistan", "%d st" % editor.ids.size())
	check(editor.records.size() >= editor.ids.size(),
		"varje nod har en post (även de filen inte kände)", "%d poster" % editor.records.size())

	# Mappningen är invarianten: en bildandel blir en pixel och tillbaka igen, på samma punkt.
	editor.selected = "iron_1"
	editor.view.flytta("iron_1", 0.5, 0.5)
	var punkt: Vector2 = editor.view.nod_punkt("iron_1")
	var tillbaka: Vector2 = editor.view.till_bild(punkt)
	check(absf(tillbaka.x - 0.5) < 0.01 and absf(tillbaka.y - 0.5) < 0.01,
		"bildandel -> pixel -> bildandel är samma punkt", "%s" % tillbaka)

	# Flytta genom editorns egen väg, och kontrollera att posten och vyn följer.
	editor.selected = "wick_2"
	var före: Vector2 = editor.view.nod_punkt("wick_2")
	editor.step_selected(0.05, 0.05)
	var efter: Vector2 = editor.view.nod_punkt("wick_2")
	check(efter.distance_to(före) > 1.0, "piltangenternas väg flyttar noden i vyn",
		"%.1f px" % efter.distance_to(före))
	var väntad: float = editor.view.till_bild(före).x + 0.05
	check(absf(float(editor.records["wick_2"]["x"]) - väntad) < 0.02,
		"posten och vyn flyttar tillsammans",
		"post %.4f, väntad %.4f, vyn före %.4f" % [float(editor.records["wick_2"]["x"]), väntad, editor.view.till_bild(före).x])

	# Runturen: skriv med spelets skrivare, läs med spelets läsare.
	var poster: Array = []
	for id in editor.ids:
		if editor.records.has(id):
			poster.append(editor.records[id])
	# TVÅ KLASSER OCH KRYSSEN. Klasserna är plattans egna mått, och värdet halveras på en liten nod —
	# det är hela poängen med små noder: "de skall bidra med små inkrementeringar".
	var liten := {"size": "liten", "effects": ["might"]}
	var stor := {"size": "stor", "effects": ["might"]}
	check(is_equal_approx(float(TreeSockets.effect_of(liten)["might"]), 0.02)
		and is_equal_approx(float(TreeSockets.effect_of(stor)["might"]), 0.05),
		"liten nod ger litet steg, stor nod stort",
		"%.2f mot %.2f" % [TreeSockets.effect_of(liten)["might"], TreeSockets.effect_of(stor)["might"]])
	check(TreeSockets.radius_of(liten) < TreeSockets.radius_of(stor),
		"och den lilla noden ritas mindre", "%.3f mot %.3f" % [TreeSockets.radius_of(liten), TreeSockets.radius_of(stor)])
	check(TreeSockets.size_of({"r": 0.018}) == "stor" and TreeSockets.size_of({"r": 0.009}) == "liten"
		and TreeSockets.SIZES["stor"] > TreeSockets.PLATE["stor"],
		"klassen följer plattans grop när ingen valt, och den stora ritas större än gropen",
		"%s / %s, ritmått %.3f mot gropmått %.3f" % [TreeSockets.size_of({"r": 0.018}),
			TreeSockets.size_of({"r": 0.009}), TreeSockets.SIZES["stor"], TreeSockets.PLATE["stor"]])

	# MÄT ATT KRYSSET NÅR SPELET: lägg en skada på wick_2 i den RIKTIGA socketfilen, läs metan och se
	# att nodens effekt är utbytt (inte adderade). Utan metans sammanslagning står summan still.
	var original := FileAccess.get_file_as_string(TreeSockets.PATH)
	var m_före := Meta.load_or_new()
	m_före.ranks["wick_2"] = 1        # stat() räknar bara KÖPTA noder, så noden måste vara köpt
	var skada_före: float = m_före.stat("might")
	var hand_före: float = m_före.stat("hand")
	var kryssad: Array = []
	for id in editor.ids:
		var post: Dictionary = (editor.records[id] as Dictionary).duplicate(true)
		post["effects"] = ["might"] if str(id) == "wick_2" else []
		kryssad.append(post)
	check(TreeSockets.write(kryssad), "socketfilen med krysset går att skriva")
	var m_efter := Meta.load_or_new()
	m_efter.ranks["wick_2"] = 1
	# 0,02 och inte 0,05: wick_2 ligger i en LITEN grop, alltså är det en liten nod, och en liten nod
	# ger halva steget. Det är hela poängen — provet mäter att halveringen följer med ut i spelet.
	check(is_equal_approx(m_efter.stat("might") - skada_före, 0.02),
		"krysset i socketfilen blir nodens effekt i spelet (0,02 skada på en liten wick_2)",
		"%.3f -> %.3f" % [skada_före, m_efter.stat("might")])
	check(m_efter.stat("hand") < hand_före,
		"och den genererade effekten är BORTA, inte adderad",
		"hand %.2f -> %.2f" % [hand_före, m_efter.stat("hand")])
	var wick_post: Dictionary = {}
	for post in kryssad:
		if str((post as Dictionary).get("id", "")) == "wick_2":
			wick_post = post
	check(m_efter.def_for("wick_2").has("edited") and not TreeSockets.text_of(wick_post).is_empty(),
		"och noden är märkt som redigerad och bär sin egen text",
		TreeSockets.text_of(wick_post))
	# KOPPLINGEN NÅR SPELET: wick_3 får vänta på iron_main i stället för på den genererade kedjan,
	# och requires_met följer med (metans sammanslagning är det enda som gör det).
	var kedja: Array = []
	for id in editor.ids:
		var post2: Dictionary = (editor.records[id] as Dictionary).duplicate(true)
		if str(id) == "wick_3":
			post2["requires"] = ["iron_main"]
		kedja.append(post2)
	TreeSockets.write(kedja)
	var m_kedja := Meta.load_or_new()
	var väntar_före: bool = m_kedja.requires_met("wick_3")
	m_kedja.ranks["iron_main"] = int(m_kedja.def_for("iron_main").get("max_rank", 1))
	check((not väntar_före) and m_kedja.requires_met("wick_3"),
		"kopplingen i socketfilen blir nodens låsordning i spelet",
		"före köp %s, efter köp %s" % [väntar_före, m_kedja.requires_met("wick_3")])
	# LÄGG TILL EN NOD (+), fyra storlekar, grafik och steg - och att noden blir en riktig nod i spelet.
	editor.selected = "iron_1"
	var antal_före: int = editor.ids.size()
	editor.add_node()
	var nytt: String = str(editor.selected)
	check(editor.ids.size() == antal_före + 1 and nytt.begins_with("iron_"),
		"+ lägger till en nod i den valda nodens gren", nytt)
	check(nytt != "iron_1" and editor.records.has(nytt), "med ett eget id i grenens serie", nytt)
	check((editor.records[nytt] as Dictionary)["requires"] == ["iron_1"],
		"och den väntar på noden man tryckte + på (Stor -> Medelstor -> Liten)",
		str(editor.records[nytt]["requires"]))

	var klass_före: String = TreeSockets.size_of(editor.records[nytt])
	var klasser: Array = [klass_före]
	for i in 4:
		editor.toggle_size()
		klasser.append(TreeSockets.size_of(editor.records[nytt]))
	var trappan: Array = []
	for i in 5:
		trappan.append(str(TreeSockets.SIZES.keys()[(TreeSockets.size_index(klass_före) + i) % 4]))
	check(klasser == trappan and klasser.slice(0, 4).size() == 4,
		"L går genom de fyra storlekarna i trappans ordning och tillbaka",
		"%s (från %s)" % [str(klasser), klass_före])

	var ikon_före: String = TreeSockets.graphics_of(editor.records[nytt])
	editor.next_graphics()
	var ikon_nu: String = TreeSockets.graphics_of(editor.records[nytt])
	check(ikon_nu != ikon_före, "G byter grafik på noden", "%s -> %s" % [ikon_före, ikon_nu])
	# Och vyn ritar den nya grafiken, inte grenens: texturens sökväg är beviset (en nod med rätt id men
	# fel bild såg rätt ut i datat och tom ut på skärmen).
	var ritad: Texture2D = (editor.view._ikoner[nytt] as TextureRect).texture
	check(ritad != null and ritad.resource_path.ends_with("%s.png" % ikon_nu),
		"och vyn ritar just den grafik noden pekar på",
		ritad.resource_path if ritad != null else "ingen textur")

	# Krysset har TRE steg: av -> x1 -> x2 -> x3 -> av. "hur mycket" är samma knapp.
	editor.selected = nytt
	(editor.records[nytt] as Dictionary)["size"] = "stor"
	for i in 3:
		editor.toggle_upgrade("might")
	check(TreeSockets.step_of(editor.records[nytt], "might") == 3,
		"krysset går att ge tre steg", str(TreeSockets.step_of(editor.records[nytt], "might")))
	check(is_equal_approx(float(TreeSockets.effect_of(editor.records[nytt])["might"]), 0.15),
		"och tre steg på en stor nod är 3 x 0,05", str(TreeSockets.effect_of(editor.records[nytt])["might"]))
	editor.toggle_upgrade("might")
	check(TreeSockets.step_of(editor.records[nytt], "might") == 0, "och varvet slutar på av")
	editor.toggle_upgrade("might")

	# NODEN I SPELET: skriv filen och läs metan - den nya noden skall finnas med gren, kostnad och krav.
	var med_ny: Array = []
	for id in editor.ids:
		med_ny.append((editor.records[id] as Dictionary).duplicate(true))
	TreeSockets.write(med_ny)
	var m_ny := Meta.load_or_new()
	var def_ny: Dictionary = m_ny.def_for(nytt)
	check(not def_ny.is_empty() and str(def_ny.get("branch", "")) == "Järnvägen"
		and def_ny.has("soul_cost"),
		"noden blir en riktig trädnod i spelet (gren, kostnad)", str(def_ny.get("id", "SAKNAS")))
	check(not m_ny.requires_met(nytt), "och den är låst så länge föräldern inte är köpt")
	m_ny.add_souls(200)
	m_ny.ranks["iron_1"] = 1
	check(m_ny.requires_met(nytt) and m_ny.buy(nytt).ok,
		"och går att köpa när föräldern är köpt",
		"%s, %d CS kvar" % [m_ny.requires_met(nytt), m_ny.souls])

	# EGNA IKONER: lägg en PNG i game/assets/tree/ och den skall gå att välja med G — ingen kodändring.
	# Provet lägger dit en fil och tar bort den igen, så mappen är som den var.
	var egen := "prov_ikon_egenskapad"
	var bild := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bild.fill(Color(0.9, 0.2, 0.6, 1.0))
	var ikonväg: String = "%s/%s.png" % [TreeSockets.ICON_DIR, egen]
	var skrev: bool = bild.save_png(ikonväg) == OK
	var lista: Array = TreeSockets.icon_list()
	check(skrev and lista.has(egen), "en egen PNG i assets/tree blir en ikon att välja",
		"%d ikoner, egen med: %s" % [lista.size(), skrev])
	check(not lista.has("jarnvagen_krona") and lista.has("jarnvagen"),
		"kronringarna är inte valbara ikoner", str(lista))
	var borta: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(ikonväg))
	check(borta == OK and not TreeSockets.icon_list().has(egen),
		"och listan följer mappen (provet städar efter sig)", "bort=%d" % borta)

	# STORLEKARNA SYNS. Vid spelvyns höjd (270 px) klipptes förr både liten och pytteliten upp till
	# sex pixlar - de var EXAKT lika stora, så storleksvalet syntes inte. Nu mäts fyra olika tal, och
	# den stora klassen är dubbelt så stor som plattans medaljongmått (9 px -> 19 px).
	var px: Array = []
	for klass in TreeSockets.SIZES:
		px.append(TreeSockets.size_px(TreeSockets.SIZES[klass], 270.0, 270.0))
	check(px.size() == 4 and px[0] == px.max() and px[3] == px.min(),
		"de fyra klasserna ger fyra olika pixelstorlekar i spelvyn", str(px))
	check(TreeSockets.size_px(TreeSockets.SIZES["stor"], 270.0, 270.0)
		>= 2 * TreeSockets.size_px(0.018, 270.0, 270.0),
		"och den stora noden är dubbelt så stor som plattans medaljongmått",
		"%d px mot %d px" % [TreeSockets.size_px(TreeSockets.SIZES["stor"], 270.0, 270.0),
			TreeSockets.size_px(0.018, 270.0, 270.0)])

	# L ÄNDRAR NODEN MAN SER, inte bara ett tal i datat: vyns ikon byter storlek på riktigt.
	editor.size = Vector2(1280, 720)
	editor.view.size = Vector2(1048, 720)
	editor.selected = "wick_5"
	var storlek_före: float = (editor.view._ikoner["wick_5"] as Control).size.x
	editor.toggle_size()
	editor.view.placera_om()
	var storlek_efter: float = (editor.view._ikoner["wick_5"] as Control).size.x
	check(storlek_före != storlek_efter, "L ändrar ikonens storlek i vyn",
		"%.0f -> %.0f px" % [storlek_före, storlek_efter])
	editor.toggle_size()

	# DRAG TAPPAR INTE DEFINITIONEN. place_at byggde förr en NY post med bara id/x/y/r, och då försvann
	# added, size, effects, requires och namn - mätt i Alex' fil: tolv noder han lagt till hade ingen
	# definition kvar, och storleken han valt försvann så fort han rörde noden.
	editor.selected = nytt
	var behållna: Array = ["added", "size", "effects", "requires", "name", "branch", "tier", "graphics"]
	var saknade_före: Array = []
	for nyckel in behållna:
		if not (editor.records[nytt] as Dictionary).has(nyckel):
			saknade_före.append(nyckel)
	editor.place_at(Vector2(700.0, 300.0))
	var saknade_efter: Array = []
	for nyckel in behållna:
		if not (editor.records[nytt] as Dictionary).has(nyckel):
			saknade_efter.append(nyckel)
	check(saknade_före.is_empty() and saknade_efter.is_empty(),
		"ett drag behåller nodens hela definition", "fattas efter draget: %s" % str(saknade_efter))
	check((editor.records[nytt] as Dictionary)["size"] == "stor",
		"också storleken man valt", str((editor.records[nytt] as Dictionary).get("size")))

	# X TAR BORT EN GENERERAD NOD (gravsten) OCH SÄTTER TILLBAKA DEN.
	var före_antal: int = m_ny.defs.size()
	editor.selected = "iron_7"
	editor.remove_added()
	check(TreeSockets.is_removed(editor.records["iron_7"]),
		"X lägger en gravsten på en genererad nod", str(editor.records["iron_7"].get("removed")))
	check(editor.meta.defs.size() == före_antal - 1 and editor.meta.def_for("iron_7").is_empty(),
		"och noden är borta ur vyn direkt (utan att spara)",
		"%d -> %d" % [före_antal, editor.meta.defs.size()])
	editor.save()
	check(Meta.load_or_new().def_for("iron_7").is_empty(),
		"och efter S är den borta ur spelet också")
	editor.remove_added()
	check(not TreeSockets.is_removed(editor.records["iron_7"])
		and not editor.meta.def_for("iron_7").is_empty(),
		"och samma tangent sätter tillbaka den")

	# X TAR BORT EN EGEN NOD HELT.
	editor.selected = nytt
	editor.remove_added()
	check(not editor.records.has(nytt), "X tar bort en egen nod ur filen", nytt)

	var tillbaka_fil := FileAccess.open(TreeSockets.PATH, FileAccess.WRITE)
	tillbaka_fil.store_string(original)
	tillbaka_fil.close()

	check(TreeSockets.write(poster, "user://prov_sockets.json"), "socketfilen skrivs (atomiskt)")
	var läst: Dictionary = TreeSockets.load_all("user://prov_sockets.json")
	check(läst.size() == poster.size(), "lika många poster tillbaka som skickades",
		"%d mot %d" % [läst.size(), poster.size()])
	check(läst.has("wick_2") and absf(float(läst["wick_2"]["x"]) - float(editor.records["wick_2"]["x"])) < 0.0005,
		"den flyttade nodens x överlevde skrivning och inläsning",
		"%s mot %s" % [läst.get("wick_2", {}).get("x", "saknas"), editor.records["wick_2"]["x"]])

	# Återställningen skall gå tillbaka till den mätta gissningen, inte till noll.
	if editor.records.has("iron_1") and editor.records["iron_1"].has("guess_x"):
		editor.selected = "iron_1"
		editor.reset_selected()
		check(absf(float(editor.records["iron_1"]["x"]) - float(editor.records["iron_1"]["guess_x"])) < 0.0001,
			"R lägger noden tillbaka på den mätta gissningen")

	print("=== trädeditorn: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
