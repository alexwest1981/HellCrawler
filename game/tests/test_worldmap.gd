## Världskartan (M41) och valet av bana. Provet biter på logiken i WorldMapView och på kartans data:
##   1. kartfilen: nodernas plats, nivåerna, och att en trasig fil SÄGER det (11 nivåer, nod utanför),
##   2. markeringen: den flyttas bara till en plats som finns, och hela kartan går att nå,
##   3. lägena: låst, öppen, påbörjad och klar går att skilja på (och den klara har en grön bock),
##   4. en låst plats nekas med ett besked i klartext — den sänder inget val,
##   5. nivåpanelen: upp till tio nivåer per plats, Enter väljer, en klar plats går att spela om,
##   6. transformen och kameran: platsen man valt ligger i kartytan och fokus glider dit,
##   7. editorn: pilarna flyttar NODEN, och S skriver tillbaka till filen man läste.
## Sist samma sak för byn: markeringen går bara mellan platser som finns, och Enter ger rätt skärm.
##
## Vyn instansieras utan skärm och mäts genom de funktioner bilden ritas ur (läge/stil/plats) —
## annars vore "det syns på bilden" ett påstående utan mätning.
##   godot --headless --script res://tests/test_worldmap.gd
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_karta_meta.json"
const TRASIG := "user://test_karta_trasig.json"
const EDIT := "user://test_karta_edit.json"
const SEKT := "user://test_karta_sektion.json"

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".trasig", TRASIG, EDIT, SEKT, SEKT + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Skriv en kartfil i user:// med noderna från `noder`, så en TRASIG fil går att mäta på.
func _skriv_karta(noder: Array) -> bool:
	var f := FileAccess.open(TRASIG, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"bild": "res://assets/ui/varldskarta.png", "noder": noder}))
	f.close()
	return true

func _init() -> void:
	var stages := Stages.load_all()
	# Samma ordning som main.gd bygger: svårighet, sedan id. Kartans väg ÄR upplåsningsordningen.
	var order: Array = stages.keys()
	order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))
	check(order.size() == 40, "fyrtio banor i ordningen", "%d" % order.size())
	check(Palett.antal() == 27, "paletten läses ur assets/palette.json", "%d färger" % Palett.antal())
	_clean()

	print("")
	print("— kartfilen: bilden, vinkeln och platsernas läge —")
	var karta := Karta.ladda()
	check(karta.fel.is_empty(), "kartfilen är hel och ren", ", ".join(karta.fel))
	check(karta.antal() == 10, "kartan har tio platser (en per nod)", "%d" % karta.antal())
	check(karta.antal() < order.size(), "och fler banor än platser: en plats bär flera nivåer",
		"%d platser, %d banor" % [karta.antal(), order.size()])
	check(ResourceLoader.exists(karta.bild), "kartans bild finns på disken", karta.bild)
	var utanför := []
	var över_taket := []
	var tomma := []
	for i in karta.antal():
		var p := karta.plats(i)
		if p.x < 0.0 or p.x > 100.0 or p.y < 0.0 or p.y > 100.0:
			utanför.append("%s %.0f/%.0f" % [str(karta.noder[i]["plats"]), p.x, p.y])
		if karta.nivåer(i).size() > Karta.MAX_NIVÅER:
			över_taket.append(str(karta.noder[i]["plats"]))
		if karta.nivåer(i).is_empty():
			tomma.append(str(karta.noder[i]["plats"]))
	check(utanför.is_empty(), "varje plats ligger på kartan (0..100 %)", ", ".join(utanför))
	check(över_taket.is_empty(), "ingen plats har fler än %d nivåer" % Karta.MAX_NIVÅER,
		", ".join(över_taket))
	check(tomma.is_empty(), "och ingen plats är tom på nivåer", ", ".join(tomma))
	# Varje nivå ska peka på en bana som finns, och ordningen ska vara svårighetsordningen.
	var alla_id := []
	for i in karta.antal():
		for id in karta.nivåer(i):
			alla_id.append(str(id))
	check(alla_id.size() == order.size(), "kartan använder alla %d banor" % order.size(),
		"%d nivåer" % alla_id.size())
	check(alla_id == order, "och i svårighetsordning — upplåsningen följer kartan")
	# Vinkeln ligger i DATA: en karta utan lutning är en plansch, och en fil utan zoom är fel fil.
	check(karta.lutning > 0.0 and karta.komprimering < 1.0 and karta.zoom > 1.0,
		"kartan är vinklad och större än vyn (zoom, komprimering, lutning)",
		"zoom %.2f, komp %.2f, lutning %.2f" % [karta.zoom, karta.komprimering, karta.lutning])

	print("")
	print("— en trasig kartfil SÄGER det, i stället för att se tom ut —")
	var elva := []
	for i in 11:
		elva.append("stage_%02d" % (i + 1))
	var skrev := _skriv_karta([
		{"plats": "för många nivåer", "x": 50.0, "y": 50.0, "nivåer": elva},
		{"plats": "utanför kartan", "x": 120.0, "y": -5.0, "nivåer": ["stage_12"]},
		{"plats": "utan bana i bandata", "x": 20.0, "y": 20.0, "nivåer": ["stage_9999"]},
	])
	check(skrev, "en provfil går att skriva", TRASIG)
	var trasig := Karta.ladda(TRASIG)
	check(trasig.antal() == 3, "laddaren läser även en trasig fil", "%d noder" % trasig.antal())
	var feltext := ", ".join(trasig.fel)
	check(feltext.contains("taket"), "elva nivåer i en plats är ett fel", feltext)
	check(feltext.contains("utanför kartan"), "en plats utanför bilden är ett fel", feltext)
	check(feltext.contains("stage_9999"), "en bana som inte finns är ett fel", feltext)
	check(trasig.sökväg == TRASIG, "kartan minns filen den lästes ur (editorn skriver tillbaka dit)",
		trasig.sökväg)

	print("")
	print("— markeringen flyttas bara till en plats som finns, och hela kartan går att nå —")
	var meta := Meta.load_or_new(TEST_PATH)
	var v := WorldMapView.new()
	v.karta = karta
	v.visa(stages, order, meta)
	check(v.antal() == karta.antal(), "kartan har en nod per PLATS, inte per bana", "%d noder" % v.antal())
	check(v.läge(0) == "öppen" and v.läge(karta.antal() - 1) == "låst",
		"ny spelare: första platsen öppen, sista låst", "%s / %s" % [v.läge(0), v.läge(karta.antal() - 1)])
	v.gå_till(0)
	check(not v.flytta(Vector2i(0, 0)), "ingen riktning flyttar ingenting")
	check(v.flytta(Vector2i(0, -1)) and v.valt_index() == 1, "upp går till glaciärsjön",
		"nod %d" % v.valt_index())
	check(v.flytta(Vector2i(0, 1)) and v.valt_index() == 0, "och ned tillbaka till porten",
		"nod %d" % v.valt_index())
	# Kartan är fri: "vänster" betyder vänster inom ±60 grader, så närmaste plats dit är is-sjön
	# (52 grader upp till vänster) — inte ett "nej" för att ingen ligger rakt västerut.
	check(v.flytta(Vector2i(-1, 0)) and v.valt_index() == 2, "vänster går till is-sjön",
		"nod %d" % v.valt_index())
	# Hela kartan ska gå att nå med de fyra riktningarna: kartan är fri, så ingen plats får bli en ö.
	var nådda := {0: true}
	var kö := [0]
	var riktningar := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not kö.is_empty():
		var i: int = kö.pop_back()
		for d in riktningar:
			v.gå_till(i)
			if v.flytta(d) and not nådda.has(v.valt_index()):
				nådda[v.valt_index()] = true
				kö.append(v.valt_index())
	check(nådda.size() == karta.antal(), "hela kartan går att nå, plats för plats",
		"%d av %d" % [nådda.size(), karta.antal()])

	print("")
	print("— låst, upplåst, påbörjad och klar går att skilja på —")
	# En PLATS bär flera banor, så upplåsningen gäller den bana som platsen faktiskt håller — inte
	# `order[1]`, som ligger i plats 0 (mätte: platsen såg låst ut och provet mätte fel sak).
	var noll: Array = karta.nivåer(0)
	var ett: Array = karta.nivåer(1)
	meta.unlock(str(ett[0]))
	meta.unlock(str(ett[1]))     # två nivåer öppna på plats 1, så nivåvalet har något att välja mellan
	# Klar = man NÅDDE sista våningen (samma regel som meta.note_run): Pale Reaper dödar dig där.
	meta.best_floor[str(noll[0])] = stages[str(noll[0])].floors
	v.visa(stages, order, meta)
	check(v.läge(0) == "påbörjad", "en plats med en klar nivå är påbörjad, inte klar", v.läge(0))
	check(v.läge(9) == "låst", "den sista platsen är fortfarande låst", v.läge(9))
	meta.best_floor[str(ett[0])] = 1
	v.visa(stages, order, meta)
	check(v.läge(1) == "påbörjad", "en bana man varit på men inte klarat är påbörjad", v.läge(1))
	var delvis := float(v.stil(1)["delvis"])
	check(delvis > 0.0 and delvis < 1.0, "med hur långt man kom", "%.2f" % delvis)
	# Klara HELA platsen: alla dess nivåer till sista våningen.
	for id in noll:
		meta.best_floor[str(id)] = stages[str(id)].floors
	v.visa(stages, order, meta)
	check(v.läge(0) == "klar", "alla nivåer klara = platsen är klar", v.läge(0))
	var öppen := v.stil(1)
	var klar := v.stil(0)
	var låst := v.stil(9)
	check(öppen != klar and öppen != låst and klar != låst, "de tre lägena ritas olika")
	check(bool(låst["lås"]) and not bool(öppen["lås"]) and not bool(klar["lås"]),
		"hänglåset sitter bara på den låsta")
	check(bool(klar["klar"]) and not bool(öppen["klar"]), "bocken sitter bara på den klara")
	check(Color(klar["kant"]) == Palett.c(15), "och bocken är GRÖN (palettens gröna)", str(klar["kant"]))
	check(float(klar["delvis"]) == 1.0, "den klara är full")

	print("")
	print("— en låst plats nekas med ett besked, och sänder inget val —")
	var såg := []
	v.vald.connect(func(id: String): såg.append(id))
	v.gå_till(karta.antal() - 1)
	var r := v.stanna()
	check(not bool(r["ok"]), "sista platsen är låst för en ny spelare")
	check(str(r["reason"]) == "låst", "och skälet är låst", str(r["reason"]))
	check(str(r["text"]).begins_with("LÅST"), "beskedet säger LÅST och vad som krävs", str(r["text"]))
	# Kravet är SEKTIONEN, inte en namnad bana: "klara en bana i sektion 4 först" (krav står tomt, för
	# det finns ingen enskild bana att peka på).
	check(str(r["text"]).contains("4") and str(r["krav"]).is_empty(),
		"och kravet är en bana i sektionen före, inte en namngiven bana", str(r["text"]))
	var låst_in := v.försök_gå_in(karta.antal() - 1)
	check(not bool(låst_in["ok"]) and såg.is_empty(), "att gå in i en låst plats sänder inget val")
	check(not v.besked().is_empty(), "men lämnar ett besked som ritas på kartan", v.besked())
	check(not v.panel_öppen(), "och öppnar ingen nivåpanel")
	v.flytta(Vector2i(0, -1))
	check(v.besked().is_empty(), "beskedet försvinner när man flyttar vidare")
	check(not bool(v.försök_gå_in(999)["ok"]), "ett index utanför kartan nekas")
	check(v.valt_index() != 999, "och markeringen flyttar sig inte dit")

	print("")
	print("— nivåpanelen: upp till tio nivåer per plats, och en klar plats går att spela om —")
	v.gå_till(1)
	var r1 := v.försök_gå_in(1)
	check(str(r1["reason"]) == "välj", "Enter på en öppen plats öppnar nivåvalet, den går inte in direkt",
		str(r1["reason"]))
	check(v.panel_öppen(), "och panelen är öppen")
	check(såg.is_empty(), "inget val är sänt än")
	check(v.nivå_vald() == 0, "panelen står på den första ospelade nivån", "nivå %d" % v.nivå_vald())
	var innan := v.nivå_vald()
	check(v.flytta_nivå(1) and v.nivå_vald() == innan + 1, "ned flyttar nivåvalet",
		"nivå %d" % v.nivå_vald())
	check(v.flytta_nivå(-9) and v.nivå_vald() == 0, "och valet kläms vid första nivån")
	# Enter igen = kör den valda nivån. Banan ur signalen är SAMMA väg som klicket använder.
	var nivåer: Array = karta.nivåer(1)
	v.flytta_nivå(1)
	var vald_nivå := v.nivå_vald()
	var r2 := v.försök_gå_in()
	check(bool(r2["ok"]) and såg == [str(nivåer[vald_nivå])],
		"Enter kör den valda nivån, och valet sänds som bana", str(såg))
	check(str(r2["stage_id"]) == str(nivåer[vald_nivå]), "rätt bana för rätt nivå", str(r2["stage_id"]))
	# Innanför en ÖPPEN sektion är varje nivå spelbar, även den meta inte har låst upp: det är
	# SEKTIONEN som är grinden (Alex), och platsen ligger i sektion 1.
	v.gå_till(1)
	v.försök_gå_in(1)
	v.flytta_nivå(9)
	check(v.nivå_vald() == nivåer.size() - 1, "valet stannar på sista nivån", "nivå %d" % v.nivå_vald())
	såg.clear()
	var sista := v.försök_gå_in()
	check(bool(sista["ok"]) and såg == [str(nivåer[nivåer.size() - 1])],
		"en nivå i en öppen sektion går att köra även om meta inte låst upp den", str(såg))
	v.stäng_panel()
	check(not v.panel_öppen(), "panelen går att stänga")
	# Farma: en helt klar plats ska öppna på nivå 1 och kunna köras om.
	v.gå_till(0)
	såg.clear()
	v.försök_gå_in(0)
	check(v.panel_öppen() and v.nivå_vald() == 0, "en helt klar plats öppnar på nivå 1 (farma direkt)",
		"nivå %d" % v.nivå_vald())
	var rf := v.försök_gå_in()
	check(bool(rf["ok"]) and såg == [str(karta.nivåer(0)[0])], "och omkörningen sänder samma bana igen",
		str(såg))

	print("")
	print("— vinkeln, kameran och kartans ruta —")
	# Platsen man valt ska hamna i KARTYTAN (ovanför kortet): en nod bakom sitt eget kort syns bara på bild.
	var utanför_rutan := []
	for i in v.antal():
		v.gå_till(i)
		v.steg_kamera(0.0, true)
		var p := v.plats(i)
		if p.x < 6.0 or p.x > 474.0 or p.y < 6.0 or p.y > WorldMapView.KORT.position.y - 4.0:
			utanför_rutan.append("%d(%d,%d)" % [i, int(p.x), int(p.y)])
	check(utanför_rutan.is_empty(),
		"varje vald plats hamnar i kartytan, ovanför kortet och innanför ramen", ", ".join(utanför_rutan))
	# Namnplaketten hör till kartytan: låg den inne i kortet skar den in i listen (mätt i bild, och
	# klämmen gick förut till BAR-12 = 244 — alltså mitt i kortet, som slutar på 252).
	var plåtar_i_listen := []
	for i in v.antal():
		v.gå_till(i)
		v.steg_kamera(0.0, true)
		var plåt := v.namnplåt(i)
		if plåt.end.y > WorldMapView.KORT.position.y or plåt.position.y < 6.0:
			plåtar_i_listen.append("%d(%.0f..%.0f)" % [i, plåt.position.y, plåt.end.y])
	check(plåtar_i_listen.is_empty(), "namnplaketten ligger i kartytan, inte i listen",
		", ".join(plåtar_i_listen))
	# Fokus: kameran glider mot markeringen i stället för att hoppa — efter ett steg är den närmare.
	v.gå_till(0)
	v.steg_kamera(0.0, true)
	v.gå_till(karta.antal() - 1)
	var avstånd_före := (v.plats(karta.antal() - 1) - Vector2(240.0, (WorldMapView.BAR - 6.0) * 0.5)).length()
	v.steg_kamera(0.05)
	var avstånd_efter := (v.plats(karta.antal() - 1) - Vector2(240.0, (WorldMapView.BAR - 6.0) * 0.5)).length()
	check(avstånd_efter < avstånd_före, "kameran glider mot den valda platsen",
		"%.1f -> %.1f px" % [avstånd_före, avstånd_efter])
	# Vinkeln ska vara en vinkel: med lutning och komprimering hamnar platserna på andra ställen än utan.
	var kopia := Karta.ladda()
	check(kopia.zoom > 1.0, "kartan är större än vyn (zoom ur filen)", "%.2f" % kopia.zoom)
	var platt := WorldMapView.new()
	platt.karta = kopia
	platt.visa(stages, order, meta)
	platt.gå_till(0)
	platt.steg_kamera(0.0, true)
	var kant_före := (platt.plats(0) - platt.plats(1)).length()
	kopia.lutning = 0.0
	kopia.komprimering = 1.0
	platt.steg_kamera(0.0, true)
	var kant_efter := (platt.plats(0) - platt.plats(1)).length()
	check(absf(kant_före - kant_efter) > 1.0, "vinkeln flyttar platserna (lutning och komprimering ritas)",
		"%.1f -> %.1f px" % [kant_före, kant_efter])
	platt.free()

	print("")
	print("— editorn: pilarna flyttar noden, och S skriver tillbaka till filen —")
	var redigera := Karta.ladda()
	check(redigera.skriv(EDIT), "kartan går att skriva till en provfil", EDIT)
	var red := WorldMapView.new()
	red.karta = Karta.ladda(EDIT)
	red.visa(stages, order, meta)
	red.editor = true
	red.gå_till(2)
	var innan_p := red.karta.plats(2)
	var vald_innan := red.valt_index()
	check(red.flytta(Vector2i(1, 0)), "i editorn flyttar höger NODEN")
	check(red.valt_index() == vald_innan, "och markeringen står kvar på samma plats")
	check(red.karta.plats(2).x > innan_p.x, "noden flyttades i sidled",
		"%.1f -> %.1f" % [innan_p.x, red.karta.plats(2).x])
	# Klämmen: en nod kan inte flyttas utanför kartan.
	red.flytta_nod(2, Vector2(-999.0, -999.0))
	check(red.karta.plats(2) == Vector2(0.0, 0.0), "en plats kan inte flyttas utanför kartan (0..100)",
		str(red.karta.plats(2)))
	red.flytta_nod(2, Vector2(40.0, 40.0))
	check(red.karta.plats(2) == Vector2(40.0, 40.0), "och den går att sätta exakt",
		str(red.karta.plats(2)))
	check(red.nod_text(2).contains("40.0"), "editorns rad säger samma tal som filen", red.nod_text(2))
	check(red.nod_text(2).contains("S2"), "och visar vilken sektion noden ligger i", red.nod_text(2))
	check(red.sätt_sektion(3), "editorn flyttar den valda noden till en annan sektion")
	check(red.karta.sektion(2) == 3, "och noden ligger i sektion 3", str(red.karta.sektion(2)))
	check(not red.sätt_sektion(3), "att sätta samma sektion igen gör ingenting")
	check(red.skriv_karta(), "S sparar kartan")
	check(not red.sparad().is_empty(), "och ger ett kvitto", red.sparad())
	var tillbaka := Karta.ladda(EDIT)
	check(tillbaka.plats(2) == Vector2(40.0, 40.0), "filen har den nya platsen när den läses om",
		str(tillbaka.plats(2)))
	check(tillbaka.antal() == karta.antal(), "och alla platser är kvar", "%d" % tillbaka.antal())
	check(tillbaka.sektion(2) == 3, "sektionen följer med filen (editorn suddar inte sektionerna)",
		"S%d" % tillbaka.sektion(2))
	# --- M60: en NY plats åt en bana (Alex: *"utöka arean jag kan göra banor i"*) --------------
	print("")
	print("— en ny plats åt en bana —")
	var ny_karta := Karta.ladda()
	var antal_innan := ny_karta.antal()
	var nod_med_två := -1
	for i in antal_innan:
		if ny_karta.nivåer(i).size() > 1:
			nod_med_två = i
			break
	check(nod_med_två >= 0, "kartan har en nod med fler än en nivå att flytta ur")
	var flyttad := str(ny_karta.nivåer(nod_med_två)[0])
	var nytt: int = ny_karta.nivå_till_ny_nod(nod_med_två, 0, 50.0, 50.0, 2)
	check(nytt >= 0, "nivån flyttas till en NY nod")
	check(ny_karta.antal() == antal_innan + 1, "kartan har en plats mer",
		"%d -> %d" % [antal_innan, ny_karta.antal()])
	check(str(ny_karta.nivåer(nytt)[0]) == flyttad, "och banan ligger i den nya noden", flyttad)
	check(not ny_karta.nivåer(nod_med_två).has(flyttad), "…och inte kvar i den gamla")
	check(ny_karta.sektion(nytt) == 2, "den nya platsen får sektionen man flyttade till",
		"S%d" % ny_karta.sektion(nytt))
	check(not str(ny_karta.noder[nytt]["plats"]).is_empty(), "och den nya nodens namn är inte tomt",
		str(ny_karta.noder[nytt]["plats"]))
	# En nod som TÖMS tas bort: en nod utan nivåer är ett fel i filen, inte ett tillstånd.
	var en_kvar := -1
	for i in ny_karta.antal():
		if ny_karta.nivåer(i).size() == 1:
			en_kvar = i
			break
	var bana_kvar := str(ny_karta.nivåer(en_kvar)[0])
	var n2: int = ny_karta.nivå_till_ny_nod(en_kvar, 0, 10.0, 10.0, 1)
	check(n2 >= 0 and ny_karta.antal() == antal_innan + 1, "en tömd nod tas bort (antalet står still)",
		"%d platser" % ny_karta.antal())
	check(ny_karta.skriv(EDIT), "…och kartan går att skriva")
	var läst := Karta.ladda(EDIT)
	check(str(läst.nivåer(läst.antal() - 1)[0]) == bana_kvar, "filen har banan i den nya noden",
		bana_kvar)
	check(läst.fel.is_empty(), "och filen är felfri när den läses om", ", ".join(läst.fel))
	check(ny_karta.byt_plats(0, "Provporten"), "en plats går att döpa om")
	check(str(ny_karta.noder[0]["plats"]) == "Provporten", "…och namnet står i noden")
	check(not ny_karta.byt_plats(0, "   "), "ett tomt namn avvisas")

	var skräp := WorldMapView.new()
	check(not skräp.skriv_karta(), "en editor utan karta sparar ingenting (och kraschar inte)")
	check(skräp.etiketter(Vector2(480.0, 270.0)).size() == 1,
		"och en tom vy säger det med en rad i stället för att krascha")
	skräp.free()
	red.free()
	_clean()
	v.free()

	print("")
	print("— sektionerna: grinden mellan kartans delar —")
	# Alex: "man inte kan gå till en del av kartan om man inte klarat minst en bana av delen innan,
	# det måste vara uppdelat i sektioner 1, 2, 3 osv."
	_clean()
	var ny := Karta.ladda()
	check(ny.sektioner() == [1, 2, 3, 4], "kartan har sektionerna 1..4 i ordning", str(ny.sektioner()))
	check(ny.sektion_noder(1).size() == 2 and ny.sektion_noder(4).size() == 2,
		"varje sektion bär sina noder", "%d + %d" % [ny.sektion_noder(1).size(),
			ny.sektion_noder(4).size()])
	var färsk := Meta.load_or_new(SEKT)
	var kvy := WorldMapView.new()
	kvy.karta = ny
	kvy.visa(stages, order, färsk)
	var öppna := []
	for i in ny.antal():
		if kvy.läge(i) != "låst":
			öppna.append(i)
	check(öppna == ny.sektion_noder(1), "ny spelare: bara sektion 1 är öppen", str(öppna))
	# Klara EN bana i sektion 1 -> sektion 2 öppnar. Inte sektion 3.
	var första_id := str(ny.nivåer(0)[0])
	färsk.best_floor[första_id] = int((stages[första_id] as Stages.StageDef).floors)
	kvy.visa(stages, order, färsk)
	check(ny.sektion_klar(1, färsk) == 1, "en bana i sektion 1 är klarad",
		str(ny.sektion_klar(1, färsk)))
	check(kvy.läge(2) != "låst" and kvy.läge(4) != "låst", "och det öppnar hela sektion 2",
		"%s / %s" % [kvy.läge(2), kvy.läge(4)])
	check(kvy.läge(5) == "låst" and kvy.läge(9) == "låst", "men inte sektion 3 och 4",
		"%s / %s" % [kvy.läge(5), kvy.läge(9)])
	# Beskedet ska namnge SEKTIONEN, inte banan strax före i svårighetsordningen.
	kvy.gå_till(9)
	var rlåst := kvy.försök_gå_in()
	check(not bool(rlåst["ok"]) and str(rlåst["text"]).contains("4"),
		"en plats i en låst sektion nekas med sektionens nummer", str(rlåst["text"]))
	# Sektionen bestämmer åt båda håll: en upplåst bana i en låst sektion är ändå låst ...
	färsk.unlock(str(ny.nivåer(9)[0]))
	kvy.visa(stages, order, färsk)
	check(kvy.läge(9) == "låst", "en upplåst bana i en låst sektion är ändå låst", kvy.läge(9))
	# ... och i en öppen sektion är banan spelbar utan att meta har låst upp den.
	check(not färsk.is_unlocked(str(ny.nivåer(2)[0])), "banan i sektion 2 är inte upplåst i meta")
	kvy.gå_till(2)
	var röppen := kvy.försök_gå_in()
	check(str(röppen["reason"]) == "välj" and kvy.panel_öppen(),
		"men spelbar: sektionen är öppen (Enter öppnar nivåpanelen)", str(röppen["reason"]))
	kvy.free()
	_clean()

	print("")
	print("— byn: markeringen flyttas mellan platserna, och Enter ger rätt skärm —")
	var by := VillageView.new()
	by.visa(meta, order.size())
	var mål := []
	by.vald.connect(func(skepp: String): mål.append(skepp))
	check(by.valt_index() == 0, "markeringen börjar på den första platsen")
	var platser: int = VillageView.PLATSER.size()
	# PANORERINGEN (M50) tar stopp i ändarna: Alex: *"det gör inget om det tar stopp när man når vardera
	# hörn"*. Bildens kanter är taket, och en markering som vek runt skulle fara från ena kanten till
	# den andra i ett svep.
	check(not by.flytta(Vector2i(-1, 0)) and by.valt_index() == 0,
		"vänster från första platsen flyttar ingenting")
	check(not by.flytta(Vector2i(0, -1)) and not by.flytta(Vector2i(0, 1)),
		"gatan har ingen granne uppåt eller nedåt")
	var steg := 0
	while by.flytta(Vector2i(1, 0)):
		steg += 1
	check(steg == platser - 1, "höger går genom hela gatan", "%d steg av %d" % [steg, platser - 1])
	check(not by.flytta(Vector2i(1, 0)), "och stannar på den sista platsen")
	# Sista platsen är EXIT-skylten i bilden: den stänger spelet i stället för att öppna en skärm.
	var skepp := by.gå_in()
	check(skepp == "avsluta", "Enter på sista platsen (EXIT-skylten) stänger spelet", skepp)
	check(mål == [skepp], "valet sänds som skärm (samma väg som Enter och klick)", str(mål))
	check(by.gå_in(0) == str(VillageView.PLATSER[0]["skepp"]),
		"och att gå in i första platsen ger den platsen", by.gå_in(0))
	# Porten i mitten leder ut till världskartan. Den mäts på sitt eget skepp, inte på sin plats i
	# raden: porten låg SIST förut, men i Alex' bild ligger den i mitten och EXIT-skylten sist.
	var port := -1
	for i in VillageView.PLATSER.size():
		if str(VillageView.PLATSER[i]["skepp"]) == "karta":
			port = i
	check(port >= 0 and by.gå_in(port) == "karta", "porten leder ut till världskartan", "index %d" % port)
	check(by.gå_in(99) == "", "en plats som inte finns går inte att gå in i")
	# Kontraktet mot main.gd (SKAL_LÄGEN): varje plats ska peka på en skärm skalet känner igen.
	# En plats som pekar fel gav förr en TOM skärm — skalet ritar ingenting för ett okänt läge.
	# Undantaget är just EXIT-skylten: den är ingen skärm, och main.gd tar den före kontrollen.
	# Listan LÄSES ur main.gd (SKAL_LÄGEN) i stället för att stå kopierad här: en kopia glider isär
	# från kontraktet den bevakar, och då blir provet en gissning (det hände när juveleraren kom till).
	# main.gd har ingen `class_name` — den laddas som skript, samma väg som test_fx tar för att
	# läsa TAKDROPP_SLAG. Att skriva `Main.` rakt av går inte (mätt: "Identifier Main not declared").
	var main_skript: GDScript = load("res://main.gd")
	var kända: Array = main_skript.SKAL_LÄGEN.duplicate()
	kända.append("avsluta")
	var okända := []
	for plats in VillageView.PLATSER:
		if not kända.has(str(plats["skepp"])):
			okända.append(str(plats["skepp"]))
	check(okända.is_empty(), "alla byns platser pekar på en skärm som finns", ", ".join(okända))
	by.free()
	_clean()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
