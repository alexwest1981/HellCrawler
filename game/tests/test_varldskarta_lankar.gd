## VÄGEN MELLAN PLATSERNA PÅ VÄRLDSKARTAN (M120) — och att den är SANN.
##
## Alex: *"Jag menade ju även huvudkartan, när man väljer var i världen man skall ned i en dungeon"* —
## alltså världskartan, skärmen där man väljer plats innan man går ned. Han vill se hur vägen går
## mellan punkterna även där: en linje mellan punkt A och B.
##
## Världskartan hade INGA kopplingar i sin data (bara noder och deras plats på en bild), så det fanns
## ingenting sant att dra en linje efter. Kopplingarna byggdes därför ur den upplåsning som redan
## FINNS: `Meta.note_run` låser upp NÄSTA bana i banordningen när man klarat en bana. Det här provet
## är grinden på att de linjer som ritas ÄR de kopplingarna — och bara de.
##
## Provet mäter fyra saker:
##   1. KOPPLINGARNA ÄR SANNA. Varje par (a, b) bevisas med spelets EGEN upplåsningsfunktion: att klara
##      a:s SISTA bana låser upp b:s FÖRSTA. Provets negativa kontroll: att klara a:s första bana gör
##      det INTE — kopplingen hör till den sista banan på platsen, inte till platsen i största
##      allmänhet. (Ett prov som bara mätte det positiva hållet hade godkänt en ritkod som drog en
##      linje från fel bana i platsen.)
##   2. INGEN KOPPLING SAKNAS OCH INGEN ÄR PÅHITTAD. Provet räknar fram paren med sin EGEN väg —
##      spelets upplåsningsfunktion får säga vilken bana som öppnar vilken, och bara den bana som
##      ÖPPNAR en plats räknas som en väg in i den — och jämför mängderna. 0 avvikelser är siffran
##      "antal linjer mot antal faktiska kopplingar".
##   3. DET ÄR EN VÄG, INTE ETT TRASSEL. Varje plats har högst en in och högst en ut, antalet par är
##      platserna minus ett, och hela kartan hänger ihop i en enda kedja från första till sista bana.
##      En karta där två platser pekar på samma plats (eller ingen) är ett fel i datan, inte en
##      smaksak i ritningen.
##   4. KARTAN RITAR DEM. Vyns `_ritade_vägar` är ett segment per koppling, och segmentets ÄNDPUNKTER
##      är platsernas skärmpunkter ur `plats()` — samma transform som markeringen och medaljongerna.
##      Provet läser varje ändpunkt TILLBAKA till en plats (motsatt väg), så ett streck mellan fel två
##      platser blir en avvikelse i stället för ett streck.
##
## FLIT-BORT (beviset för att provet kan gå rött, kört när ändringen lades):
##   * ta bort en rad ur `Karta.länkar` (t.ex. `if a < 0 or a == b or sedda.has(...)` -> lägg till
##     `if b == 7`): "0 avvikelser" faller och kontrollen för plats 7:s väg in saknas.
##   * ta bort `_vägar()` ur `WorldMapView._draw`: "kartan ritar ett streck per koppling" faller.
##   * låt `_vägar` rita `karta.bild_px` i stället för `plats`: ändpunktskontrollen faller (bildens
##     px är inte vyns, och lutningen gör att de två inte sammanfaller).
##
## KÖRNING: godot --headless --script res://tests/test_varldskarta_lankar.gd
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_varldskarta_lankar.json"


func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Färsk meta, ovanpå provets egen sparfil. `note_run` läser sparfilen, så provet får aldrig röra
## spelarens (Meta.fotolage styr den vägen).
func _meta() -> Meta:
	return Meta.load_or_new(TEST_PATH)


## VILKEN BANA SOM ÖPPNAR VILKEN — spelets egen funktion som domare, inte provets kopia av regeln.
## `unlocked` nollas före varje anrop: `unlock` lägger bara till det som inte redan står där, så en
## meta som minns förra svaret svarar "" på nästa bana.
func _öppnar(m: Meta, stages: Dictionary, order: Array, bana: String) -> String:
	var s: Stages.StageDef = stages.get(bana)
	if s == null:
		return ""
	m.unlocked = []
	return m.note_run(bana, int(s.floors), int(s.floors), order)


## PROVETS EGEN RÄKNING av vilken PLATS som öppnar vilken. Ägaren till varje bana läses ur kartans
## nivålistor, upplåsningen ur spelets funktion, och bara den bana som är en plats FÖRSTA bana räknas
## som en väg in i den — annars vore ett hopp mitt inuti en plats en koppling.
func _oberoende_par(stages: Dictionary, order: Array, karta: Karta) -> Dictionary:
	var m := _meta()
	var ägare := {}
	var först := {}
	for i in karta.antal():
		var l: Array = karta.nivåer(i)
		först[i] = str(l[0]) if not l.is_empty() else ""
		for id in l:
			ägare[str(id)] = i
	var par := {}
	for s in order:
		var u := _öppnar(m, stages, order, str(s))
		if u.is_empty():
			continue
		var a: int = int(ägare.get(str(s), -1))
		var b: int = int(ägare.get(u, -1))
		if a < 0 or b < 0 or a == b:
			continue
		if str(först.get(b, "")) != u:
			continue
		par[Vector2i(a, b)] = true
	return par


## Avvikelserna mellan två mängder par: vad som saknas och vad som är påhittat. Egen funktion, så
## provet kan köra den på en MEDVETET trasig mängd och visa att den mäter något (se flit-bort).
func _avvikelser(facit: Dictionary, mina: Dictionary) -> Dictionary:
	var saknas := []
	for k in facit:
		if not mina.has(k):
			saknas.append(str(k))
	var påhittade := []
	for k in mina:
		if not facit.has(k):
			påhittade.append(str(k))
	return {"saknas": saknas, "påhittade": påhittade,
		"antal": saknas.size() + påhittade.size()}


## Vilken plats en SKÄRMPUNKT hör till — den motsatta vägen, som gör ett streck på fel ställe till en
## avvikelse i stället för till ett streck.
func _plats_vid(v: WorldMapView, p: Vector2) -> int:
	for i in v.antal():
		if (v.plats(i) - p).length() < 0.01:
			return i
	return -1


func _initialize() -> void:
	Meta.fotolage(true)
	_clean()
	var stages := Stages.load_all()
	# Samma ordning som main.gd bygger, och samma som meta låser upp i: svårighet, sedan id.
	var order: Array = stages.keys()
	order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))

	print("VÄGEN MELLAN PLATSERNA PÅ VÄRLDSKARTAN: kopplingarna byggs ur upplåsningen och mäts mot den.")

	var karta := Karta.ladda()
	check(karta.fel.is_empty(), "kartfilen är hel och ren", ", ".join(karta.fel))
	var platser := karta.antal()
	var data: Array = karta.länkar(order)
	var mina := {}
	for l in data:
		var p: Vector2i = l
		mina[p] = true
	print("      %d platser, %d banor, %d kopplingar i data" % [platser, order.size(), data.size()])
	check(platser >= 2 and data.size() == platser - 1,
		"en kedja: %d platser ger %d kopplingar" % [platser, platser - 1],
		"%d kopplingar" % data.size())

	print("")
	print("— 1. varje koppling bevisas med spelets egen upplåsning —")
	var m := _meta()
	var utan_bevis := []
	var fel_håll := []
	for l in data:
		var p: Vector2i = l
		var a_nivåer: Array = karta.nivåer(p.x)
		var b_nivåer: Array = karta.nivåer(p.y)
		var sista := str(a_nivåer[a_nivåer.size() - 1])
		var första := str(b_nivåer[0])
		if _öppnar(m, stages, order, sista) != första:
			utan_bevis.append("%d->%d (%s öppnar inte %s)" % [p.x, p.y, sista, första])
		# Den negativa kontrollen: platsens FÖRSTA bana öppnar inte nästa plats. Går den kontrollen
		# igenom också har provet inte mätt att kopplingen hör till den sista banan.
		if a_nivåer.size() > 1 and _öppnar(m, stages, order, str(a_nivåer[0])) == första:
			fel_håll.append("%d->%d" % [p.x, p.y])
	check(utan_bevis.is_empty(),
		"varje koppling a->b: a:s SISTA bana låser upp b:s FÖRSTA (spelets note_run säger det)",
		", ".join(utan_bevis.slice(0, 3)))
	check(fel_håll.is_empty(),
		"och negativ kontroll: a:s FÖRSTA bana gör det inte (kopplingen hör till sista banan)",
		", ".join(fel_håll.slice(0, 3)))

	print("")
	print("— 2. antalet linjer mot antalet faktiska kopplingar: 0 avvikelser —")
	var facit := _oberoende_par(stages, order, karta)
	var av := _avvikelser(facit, mina)
	print("      faktiska kopplingar (provets egen väg): %d, kartans: %d" % [facit.size(), mina.size()])
	check(facit.size() == mina.size() and int(av["antal"]) == 0,
		"kopplingarna ÄR de faktiska — 0 avvikelser",
		"faktiska %d, kartans %d (%d saknas, %d påhittade)"
			% [facit.size(), mina.size(), (av["saknas"] as Array).size(),
				(av["påhittade"] as Array).size()])
	check(not facit.is_empty(), "kartan har riktiga kopplingar att rita", "%d" % facit.size())

	print("")
	print("— 3. en väg, inte ett trassel —")
	var in_ := {}
	var ut := {}
	for l in data:
		var p: Vector2i = l
		in_[p.y] = int(in_.get(p.y, 0)) + 1
		ut[p.x] = int(ut.get(p.x, 0)) + 1
	var flera := []
	for i in platser:
		if int(in_.get(i, 0)) > 1 or int(ut.get(i, 0)) > 1:
			flera.append("%d (in %d, ut %d)" % [i, int(in_.get(i, 0)), int(ut.get(i, 0))])
	check(flera.is_empty(), "varje plats har högst en väg in och högst en ut", ", ".join(flera))
	# Följ kedjan från platsen som äger den FÖRSTA banan: alla platser ska nås, annars är en plats en ö.
	var ägare_första := -1
	for i in platser:
		if str(karta.nivåer(i)[0]) == str(order[0]):
			ägare_första = i
			break
	var nästa := {}
	for l in data:
		var p: Vector2i = l
		nästa[p.x] = p.y
	var nådda := 0
	var här := ägare_första
	var sedd := {}
	while här >= 0 and not sedd.has(här):
		sedd[här] = true
		nådda += 1
		här = int(nästa.get(här, -1))
	check(ägare_första >= 0 and nådda == platser,
		"kedjan från första banan når alla %d platser" % platser,
		"%d av %d (från plats %d)" % [nådda, platser, ägare_första])
	var sista_plats := -1
	for i in platser:
		if str(karta.nivåer(i)[karta.nivåer(i).size() - 1]) == str(order[order.size() - 1]):
			sista_plats = i
	check(int(nästa.get(sista_plats, -1)) == -1,
		"och platsen med den SISTA banan är ändå inte en återvändsgränd i datan: kedjan slutar där",
		"plats %d" % sista_plats)

	print("")
	print("— 4. kartan ritar dem —")
	var meta := _meta()
	var v := WorldMapView.new()
	v.karta = karta
	v.size = Vector2(480.0, 270.0)
	root.add_child(v)
	v.visa(stages, order, meta)
	v.queue_redraw()
	await process_frame
	await process_frame
	var ritade: Array = v._ritade_vägar
	check(ritade.size() == data.size() and not ritade.is_empty(),
		"kartan ritar ett streck per koppling", "%d streck mot %d kopplingar" % [ritade.size(), data.size()])
	# Ändpunkterna läses TILLBAKA till platser. Är ett streck ritat mellan fel två platser blir paret
	# ett annat (eller ingen träff alls), och avvikelsen räknas upp.
	var ritade_par := {}
	var utan_plats := []
	for seg in ritade:
		var a := _plats_vid(v, seg[0])
		var b := _plats_vid(v, seg[1])
		if a < 0 or b < 0:
			utan_plats.append("%s -> %s" % [str(seg[0]), str(seg[1])])
			continue
		ritade_par[Vector2i(a, b)] = true
	check(utan_plats.is_empty(), "varje strecks ändpunkter är en plats på kartan",
		", ".join(utan_plats.slice(0, 3)))
	var av_ritat := _avvikelser(mina, ritade_par)
	print("      ritade streck lästa tillbaka till platser: %d par" % ritade_par.size())
	check(int(av_ritat["antal"]) == 0 and ritade_par.size() == data.size(),
		"och strecken ÄR kopplingarna: 0 avvikelser mellan ritat och sant",
		"ritat %d, sant %d (%d saknas, %d påhittade)"
			% [ritade_par.size(), data.size(), (av_ritat["saknas"] as Array).size(),
				(av_ritat["påhittade"] as Array).size()])
	# Att strecken ligger UNDER medaljongerna går inte att mäta här (det är ritordningen i `_draw`),
	# men ändpunkterna ska vara nodernas SKÄRMPUNKTER — inte bildens px, som lutningen flyttar.
	var fel_punkt := []
	for seg in ritade:
		var i := _plats_vid(v, seg[0])
		if i < 0 or (v.plats(i) - seg[0]).length() > 0.01:
			fel_punkt.append(str(seg[0]))
	check(fel_punkt.is_empty(), "ändpunkterna kommer ur plats() — samma transform som markeringen",
		", ".join(fel_punkt.slice(0, 3)))

	# Granskningsflaggan som pixlarna mäts med. Utan den här kontrollen kunde `vag=0` vara ett ord
	# som inte gör något, och då vore före/efter-bilderna samma bild.
	var av_v := WorldMapView.new()
	av_v.karta = karta
	av_v.vägar_av = true
	av_v.size = Vector2(480.0, 270.0)
	root.add_child(av_v)
	av_v.visa(stages, order, meta)
	av_v.queue_redraw()
	await process_frame
	await process_frame
	check(av_v._ritade_vägar.is_empty(),
		"granskningsflaggan vag=0 stänger av vägarna (så pixelskillnaden går att mäta)",
		"%d streck" % av_v._ritade_vägar.size())
	av_v.free()

	# SIST: jämföraren prövas på en medvetet trasig mängd. Ett "0 avvikelser" som också blev 0 för en
	# mängd det saknas en koppling i mäter ingenting.
	var stympad := mina.duplicate()
	stympad.erase(data[0])
	var fångad := _avvikelser(facit, stympad)
	var tom := _avvikelser(facit, facit)
	check(int(fångad["antal"]) == 1 and (fångad["saknas"] as Array).size() == 1,
		"jämföraren fångar en borttagen koppling (provet mäter något)",
		"%d avvikelse" % int(fångad["antal"]))
	check(int(tom["antal"]) == 0, "och ger 0 på en mängd som är lika med facit")
	v.free()
	_clean()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
