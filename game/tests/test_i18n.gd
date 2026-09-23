## Språken: filerna, nyckeluppsättningen, uppslagningen och att valet fastnar i sparfilen.
##
## Det här provet vaktar tre saker som annars går sönder tyst:
##   1. Att en språkfil har SAMMA nycklar som svenska. En nyckel som bara finns i en fil är en rad
##      spelaren aldrig ser; en som saknas är en tom ruta i gränssnittet.
##   2. Att en halvfärdig fil inte går att välja (Tr.is_complete) — då visas svenska i stället.
##   3. Att hela vägen fungerar: Tr -> kortets text. Det är samma väg spelaren ser, och den
##      testas i två språk, inte bara i uppslagningen.
##   godot --headless --script res://tests/test_i18n.gd
extends SceneTree

var fails := 0
var checks := 0

const TEST_PATH := "user://test_i18n_save.json"

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _clean() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".trasig"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _init() -> void:
	var sv := Tr.table("sv")
	print("— språkfilerna —")
	check(sv.size() > 100, "svenska är källan", "%d nycklar" % sv.size())
	check(FileAccess.file_exists("res://data/i18n/en.json"), "engelskan finns")
	check(Tr.LANGUAGES.size() == 13, "tretton språk i listan", "%d" % Tr.LANGUAGES.size())

	# Referensens tolv språk + svenska. Tappas ett av dem ska det synas här, inte i menyn.
	var väntade := ["en", "de", "fr", "es", "it", "pl", "pt-BR", "ru", "ja", "ko", "zh-Hans", "zh-Hant"]
	for k in väntade:
		check(Tr.codes().has(k), "referensens språk %s finns med" % k)

	print("")
	print("— samma nycklar i alla filer —")
	for kod in Tr.codes():
		var t := Tr.table(kod)
		check(not t.is_empty(), "%s.json går att läsa" % kod, "%d nycklar" % t.size())
		var extra := []
		for nyckel in t:
			if not sv.has(nyckel):
				extra.append(nyckel)
		var tomma := []
		for nyckel in t:
			if str(t[nyckel]).strip_edges().is_empty():
				tomma.append(nyckel)
		check(extra.is_empty(), "%s har inga påhittade nycklar" % kod, ", ".join(extra).left(70))
		# Andra hållet: en nyckel som svenskan har men filen saknar. Kontrollen ovan såg bara
		# påhittade nycklar, så elva halvfärdiga filer (141 nycklar borta var) kunde passera — det
		# här provet föll på den baslinjen.
		var saknade := []
		for nyckel in sv:
			if not t.has(nyckel):
				saknade.append(nyckel)
		check(saknade.is_empty(), "%s har alla svenska nycklar" % kod,
			"%d saknas: %s" % [saknade.size(), ", ".join(saknade).left(70)])
		check(tomma.is_empty(), "%s har inga tomma rader" % kod, ", ".join(tomma).left(70))

	print("")
	print("— skärmarnas nycklar: koden har ingen fallback kvar att gömma sig i —")
	# De här texterna LÅG som fallbacksträngar i anropen (`Tr.t("ui.shop.title", "BUTIKEN — …")`), och
	# en fallback är osynlig i filerna: nyckeln fanns inte, koden svarade själv, och butiken,
	# värdshuset, smeden, kartan, belöningen och slutskärmen stod därför på svenska i en tysk körning.
	# Nu är de nycklar i sv.json och en.json, och generatorn fyller de elva andra. Provet faller om en
	# nyckel tappas (då tar kodens fallback tyst över igen) eller om en fil har fått svensk text.
	var skarmnycklar := [
		"ui.by.hint", "ui.map.hint", "ui.map.legend", "ui.map.none", "ui.map.locked_short",
		"ui.map.fresh", "ui.map.started", "ui.map.done", "ui.map.partial", "ui.map.missing",
		"ui.map.missing_id",
		"ui.map.locked", "ui.map.locked_first", "ui.map.diff", "ui.map.floors", "ui.map.boss",
		# Kartans nya delar (M41): nivåpanelen, teckenförklaringen och editorn.
		"ui.map.pick", "ui.map.levels", "ui.map.cleared", "ui.map.level_locked", "ui.map.partial",
		# Sektionerna: namnet och grinden.
		"ui.map.section", "ui.map.section_locked",
		"ui.map.legend.open", "ui.map.hint_editor", "ui.map.saved", "ui.map.save_failed",
		"ui.map.band.grove", "ui.map.band.ruin", "ui.map.band.ash",
		# Byns hus och statusrader: namnena och raderna stod som svenska strängar i PLATSER och i
		# visa(), så byn var svensk i varje körning. Statusraderna bär siffran i formatet, precis
		# som HUD:en.
		"ui.by.plats.butik", "ui.by.plats.vardshus", "ui.by.plats.smed", "ui.by.plats.karta",
		"ui.by.plats.avsluta",
		"ui.by.status.buy", "ui.by.status.none", "ui.by.status.deck", "ui.by.status.nodeck",
		"ui.by.status.unlocked", "ui.by.status.quit",
		# Minikartans teckenförklaring: samma kind-strängar som Dungeon.FloorNode bär (boss, encounter,
		# chest, torch, shovel) plus spelaren, som ritas som en egen prick med pil.
		"ui.map.nod.boss", "ui.map.nod.fight", "ui.map.nod.chest", "ui.map.nod.torch",
		"ui.map.nod.shovel", "ui.map.nod.player",
		"ui.shop.title", "ui.shop.hint", "ui.inn.title", "ui.inn.hired", "ui.inn.hint", "ui.inn.explain",
		"ui.smith.title", "ui.smith.branches", "ui.smith.maxed", "ui.smith.locked", "ui.smith.empty",
		"ui.smith.hint", "ui.reward.chest", "ui.reward.rest", "ui.reward.gold", "ui.reward.heal",
		"ui.end.unlocked", "ui.end.hint",
	]
	# Några rader är samma rad i två språk: "boss" heter boss på engelska, italienska och polska, och
	# "hp" står i både svenskan och engelskan. Det är översättning, inte en kvarglömd svensk rad.
	# (Boss-raden på pergamentkortet färgas på sitt INDEX, inte på det ordet — en översatt rad
	# tappade den mörkröda tonen när koden kände igen den på "boss".)
	var samma_som_svenska := ["en:ui.map.boss", "it:ui.map.boss", "pl:ui.map.boss", "en:ui.reward.heal"]
	var tappade := 0
	var svenska_rader := 0
	for n in skarmnycklar:
		if not (sv.has(n) and Tr.table("en").has(n)):
			tappade += 1
			print("      %s saknas i sv.json eller en.json" % n)
		for kod in väntade:
			Tr.set_lang(kod)
			var egen := Tr.t(n)
			if egen.strip_edges().is_empty() or (egen == str(sv[n]) and not samma_som_svenska.has("%s:%s" % [kod, n])):
				svenska_rader += 1
				print("      %s i %s: %s" % [n, kod, egen])
	Tr.set_lang("sv")
	check(tappade == 0, "alla %d skärmnycklar finns i sv.json och en.json" % skarmnycklar.size(),
		"%d saknas" % tappade)
	check(svenska_rader == 0, "ingen av dem står på svenska i ett annat språk",
		"%d rader" % svenska_rader)

	print("")
	print("— datalagrets nycklar: smeden och kamratlistan —")
	# Trädets noder och kamraterna stod på svenska i varje körning: namnen bor i data/tree.json och
	# data/crawlers/*.json, och datat kan inte översättas — det är NYCKLARNA som gör raden till en rad
	# i språkfilen. Provet bygger listan ur datat självt, så en nod som läggs till där måste ha ett
	# värde i alla tretton filer, inte bara i den språkvarianten någon råkade titta på.
	var datanycklar := []
	for n in JSON.parse_string(FileAccess.get_file_as_string("res://data/tree.json")):
		datanycklar.append("tree.%s" % str(n["id"]))
		datanycklar.append("tree.%s.text" % str(n["id"]))
		var grennyckel := "tree.branch.%s" % str(n["branch"]).to_lower()
		if not datanycklar.has(grennyckel):
			datanycklar.append(grennyckel)
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/crawlers/00_kamrater.json")):
		datanycklar.append("crawler.%s" % str(c["id"]))
		datanycklar.append("crawler.%s.text" % str(c["id"]))
	check(datanycklar.size() >= 30, "nycklarna kommer ur datat", "%d nycklar" % datanycklar.size())
	var datat_saknas := []
	var datat_svenskt := []
	# Engelskan är källspråket för kortnamnen, så kamratens namn får vara identiskt med svenskan där
	# (som "Lash"). De elva andra ska ha egna namn — annars stod kamratlistan på svenska ändå.
	var elva := []
	for k in väntade:
		if k != "en":
			elva.append(k)
	for n in datanycklar:
		if not (sv.has(n) and not str(sv[n]).strip_edges().is_empty()):
			datat_saknas.append("%s (sv)" % n)
			continue
		for kod in Tr.codes():
			var t := Tr.table(kod)
			if not t.has(n) or str(t[n]).strip_edges().is_empty():
				datat_saknas.append("%s (%s)" % [n, kod])
		var egna := elva if n.begins_with("crawler.") and not n.ends_with(".text") else väntade
		for kod in egna:
			Tr.set_lang(kod)
			var egen := Tr.t(n)
			if egen == str(sv[n]):
				datat_svenskt.append("%s (%s)" % [n, kod])
	Tr.set_lang("sv")
	check(datat_saknas.is_empty(), "alla %d datanycklar finns i alla tretton filer" % datanycklar.size(),
		", ".join(datat_saknas).left(70))
	check(datat_svenskt.is_empty(), "och ingen av dem står på svenska i ett annat språk",
		", ".join(datat_svenskt).left(70))
	# Grennamnen måste vara unika per språk: tree_lines slår upp grenen på NAMNET (skalet håller
	# namnet i handen, inte ett id), så två grenar som översatts likadant blev en enda gren i smeden.
	var grennycklar := []
	for n in datanycklar:
		if n.begins_with("tree.branch.") and not grennycklar.has(n):
			grennycklar.append(n)
	var gren_dubbletter := []
	for kod in Tr.codes():
		var sedda := {}
		for n in grennycklar:
			var v := str(Tr.table(kod).get(n, ""))
			if sedda.has(v):
				gren_dubbletter.append("%s: %s" % [kod, v])
			sedda[v] = true
	check(gren_dubbletter.is_empty(), "grennamnen är unika i varje språk", ", ".join(gren_dubbletter))

	print("")
	print("— gränssnittet måste vara helt, annars får språket inte väljas —")
	for kod in Tr.codes():
		check(Tr.is_complete(kod), "%s är komplett" % kod)
	# Ett språk utan fil, och ett påhittat kodnamn, ska nekas — annars blir gränssnittet tomt.
	check(not Tr.is_complete("xx"), "språk utan fil nekas")
	check(not Tr.set_lang("xx"), "och går inte att välja")
	check(not Tr.set_lang("kl"), "inte heller ett påhittat språk")

	print("")
	print("— uppslagningen —")
	check(Tr.set_lang("de"), "tyska går att välja")
	check(Tr.t("ui.battle.play_all") == "Alles spielen (P)",
		"tyskan svarar med sin egen rad", Tr.t("ui.battle.play_all"))
	check(Tr.t("finns.inte", "reserv") == "reserv", "okänd nyckel faller tillbaka på koden")
	check(Tr.set_lang("sv"), "tillbaka till svenska")
	check(Tr.t("ui.battle.play_all") == "Spela allt (P)", "och svenskan är svensk igen")

	# Förut mättes fallbacken här: japanskan hade inga bannamn och föll tillbaka på svenskan. Nu har
	# alla tretton språk egna namn, så provet mäter två saker i stället — att japanskan har ett eget
	# namn (inte svensk fallback), och att en nyckel ingen fil har faller tillbaka på namnet datat bär.
	check(Tr.set_lang("ja"), "japanska går att välja")
	var japanskt: String = Tr.name_of("stage", "stage_11", "Myrmarken")
	check(not japanskt.is_empty() and japanskt != "Myrmarken",
		"japanskan har ett eget namn på banan, inte den svenska fallbacken", japanskt)
	check(Tr.name_of("stage", "finns_inte", "Namnlös") == "Namnlös",
		"en nyckel ingen fil har faller tillbaka på namnet datat bär",
		Tr.name_of("stage", "finns_inte", "x"))
	Tr.set_lang("sv")
	check(Tr.name_of("stage", "stage_11", "x") == "Myrmarken", "svenskan har sitt eget namn")

	print("")
	print("— hela vägen: samma kort, två språk —")
	var db := Cards.load_all()
	var rustning: Cards.Card = null
	for id in db:
		for e in db[id].effects:
			if str(e.get("op", "")) == "armor":
				rustning = db[id]
				break
		if rustning != null:
			break
	check(rustning != null, "hittade ett kort med rustning", rustning.title() if rustning else "—")
	if rustning != null:
		Tr.set_lang("sv")
		var på_svenska := rustning.describe()
		Tr.set_lang("en")
		var på_engelska := rustning.describe()
		check(på_svenska.contains("rustning"), "kortets text är svensk", på_svenska)
		check(på_engelska.contains("armour"), "och engelsk på engelska", på_engelska)
		check(på_svenska != på_engelska, "texten byter språk med valet")
		# Siffrorna ska vara kvar: bara orden byts.
		if rustning.effects.size() > 0:
			var siffra := "%.0f" % float(rustning.effects[0].get("amount", 0.0))
			check(på_svenska.contains(siffra) and på_engelska.contains(siffra),
				"siffran %s står kvar i båda" % siffra)
	Tr.set_lang("sv")

	print("")
	print("— hur mycket som är översatt (mätt, inte gissat) —")
	var helt := 0
	for kod in Tr.codes():
		var c := Tr.coverage(kod)
		print("  %-8s %3.0f %%   %s" % [kod, c * 100.0, Tr.name_of_code(kod)])
		if c >= 0.99:
			helt += 1
	check(Tr.coverage("sv") == 1.0, "svenskan är hundra procent")
	check(Tr.coverage("en") > 0.4, "engelskan har innehållsnamnen", "%.0f %%" % (Tr.coverage("en") * 100.0))
	check(helt == Tr.codes().size(), "alla tretton språk är helt översatta", "%d" % helt)
	# Gränssnittet var kravet förut (0,15 räckte); nu är kravet hela filen — samma nycklar som
	# svenska, inga tomma rader. Siffran nedan fångar varje nyckel som tappas.
	for kod in väntade:
		check(Tr.coverage(kod) >= 0.99, "%s har hela texten översatt" % kod,
			"%.0f %%" % (Tr.coverage(kod) * 100.0))

	print("")
	print("— kontraktet mot koden: antalet platshållare —")
	# De nycklar gränssnittet formaterar med `% [...]` måste ha exakt så många platshållare som
	# anropet skickar argument. Det är här de två riktiga buggarna satt: statusraden och slutskärmen
	# tappade en platshållare i mina översättningar, och felet syntes bara som "String formatting
	# error" i en bildruta ingen tittar på. Mätt mot koden, inte gissat.
	var kontrakt := {
		# ui.end.summary: två tal sedan M48 — dödade fiender och guld in. Raden hade fyra förut
		# (våningar, strider, guld, xp) och Alex ville ha bara de två: *"Här skall man bara få
		# information om hur många man dödat, hur mycket guld man fick in."*
		# ui.hud.status: nio sedan M91 — raden visar BÅDE banken och omgångens guld (Alex: "I strid
		# skall ens totala, och det man dragit in på den omgången visas"). Kontraktet räknade kvar
		# åtta och fällde alla 13 språk i samma rad.
		"ui.hud.status": 9, "ui.end.summary": 2, "ui.draft.title": 1, "ui.draft.prompt": 1,
		"ui.stats.mana": 2, "ui.village.title": 1, "ui.village.hint": 1, "ui.village.price": 1,
		"ui.settings.coverage": 2, "ui.battle.enemy_row": 2, "ui.battle.player_row": 3,
		"ui.hud.rust": 1, "ui.hud.kort": 1, "ui.shell.status": 3,
		"ui.by.status.buy": 1, "ui.by.status.deck": 1, "ui.by.status.unlocked": 2,
		"ui.map.missing_id": 1,
		"fmt.damage": 2, "fmt.armor": 1, "fmt.heal": 1, "fmt.mana": 1, "fmt.draw": 1,
		"fmt.knockback": 1, "fmt.freeze": 1,
	}
	var re := RegEx.new()
	re.compile("%[-+0-9.]*[sdfi]")
	for nyckel in kontrakt:
		for kod in Tr.codes():
			Tr.set_lang(kod)
			# Genom Tr.t, inte tabellen direkt: det är den strängen koden formaterar. En nyckel som
			# är ren formatering (fmt.damage = "%.0f×%d") får saknas i en fil och faller då tillbaka
			# på svenska — det är avsiktligt, och provet mäter resultatet i stället för filen.
			var v := Tr.t(nyckel)
			var antal: int = re.search_all(v).size()
			check(antal == int(kontrakt[nyckel]), "%s i %s har %d platshållare" % [
				nyckel, kod, int(kontrakt[nyckel])], "hittade %d i %s" % [antal, v])
	Tr.set_lang("sv")

	print("")
	print("— uppgraderingarnas rad kommer ur effekten, inte ur en handskriven text —")
	# Byns area-rad påstod "+2 % skada" medan Rules.damage ger area/5 = +10 %. Provet mäter raden i
	# alla 13 språk: ingen platshållare kvar, och siffran är den effekten ger.
	var meta := Meta.load_or_new("user://test_i18n_meta.json")
	# Ett procenttecken är rätt i den färdiga raden ("+10 %") — det är PLATSHÅLLAREN som inte får
	# vara kvar. Samma mönster som kontraktet ovan.
	var re2 := RegEx.new()
	re2.compile("%[-+0-9.]*[sdfi]")
	var kvar := 0
	for kod in Tr.codes():
		Tr.set_lang(kod)
		for rad in meta.village_lines():
			var txt := str(rad["text"])
			if re2.search_all(txt).size() > 0 or txt.strip_edges().is_empty():
				kvar += 1
				print("      %s %s: %s" % [kod, rad["id"], txt])
	check(kvar == 0, "ingen uppgraderingsrad har kvar en platshållare eller är tom", "%d rader" % kvar)
	for kod in Tr.codes():
		Tr.set_lang(kod)
		var alla: Array = []
		for rad in meta.village_lines():
			alla.append(str(rad["text"]))
		var text: String = " | ".join(alla)
		# area (0,5/5 = 10) och might (0,1 = 10) och curse (0,2 = 20, två gånger)
		check(text.contains("10 ") or text.contains("10\u00a0") or text.contains("+10"),
			"%s: area- och might-raden visar 10" % kod, text.left(60))
	Tr.set_lang("sv")

	print("")
	print("— språkvalet fastnar i sparfilen —")
	_clean()
	var m := Meta.load_or_new(TEST_PATH)
	m.language = "de"
	m.gold = 42
	check(m.save(TEST_PATH), "sparade")
	var igen := Meta.load_or_new(TEST_PATH)
	check(igen.language == "de", "språket läses tillbaka", igen.language)
	check(igen.gold == 42, "och guldet är kvar", str(igen.gold))
	_clean()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
