## Kartfiler: en våning ritad för hand, i samma format som generatorn producerar i minnet.
##
##   data/maps/<stage_id>_<våning>.json
##
## Rutnätet skrivs som rader av tecken — "#" vägg, "." golv — så filen går att läsa och rätta i en
## textredigerare, och så en git-diff visar exakt vilka rutor som flyttades. Noderna ligger för sig
## med sina egna fält, eftersom de har egenskaper (fiende, guld) som en bokstav inte kan bära.
##
## Varför filen finns: generatorn (core/dungeon.gd) gissar former, och referensen gör inte det —
## deras rum är handbyggda prefabs (research/08-referensrum.md). Nu kan Alex rita dem i editorn, och
## varje handritad våning går genom EXAKT samma kontroller som en genererad: nåbarhet, boss, shovel,
## minst fyra strider. En karta som inte går att spela får inte sparas.
class_name MapIo
extends RefCounted

const DIR := "res://data/maps/"
const WALL_CH := "#"
const FLOOR_CH := "."
const KINDS := ["start", "encounter", "boss", "shovel", "chest", "torch", "nyckel", "spak"]

## DÖRRARNA (M161). Alex: *"Hur gör vi om man vill sätta in en dörr? ... de skall alla vara beroende av
## en lösning på vägen."* Tre slag (trä, metall, galler) med SAMMA regel: dörren står på en golvruta och
## är låst tills koden den lyssnar på är löst — en nyckel man plockat upp eller en spak man dragit.
const DÖRRAR := ["trä", "metall", "galler"]


static func dörr_vid(f: Dungeon.Floor, p: Vector2i) -> Dictionary:
	for d in f.dörrar:
		if d["pos"] == p:
			return d
	return {}


## Namnet en ny dörr/nyckel/spak får: "dörr 1", "dörr 2" … Så man kan säga VILKEN dörr man menar när
## man binder den till en spak, i stället för att alla heter "1".
static func namn_för(f: Dungeon.Floor, slag: String) -> String:
	var n := 1
	var tagna := {}
	for d in f.dörrar:
		tagna[str(d.get("namn", ""))] = true
	for nd in f.nodes:
		if not str(nd.kod).is_empty():
			tagna[str(nd.kod)] = true
	while tagna.has("%s %d" % [slag, n]):
		n += 1
	return "%s %d" % [slag, n]


static func sätt_dörr(f: Dungeon.Floor, typ: String, p: Vector2i, kod: String = "") -> String:
	if not DÖRRAR.has(typ):
		return "okänd dörrtyp: %s" % typ
	if not f.is_floor_at(p):
		return "dörren måste stå på golv"
	if not dörr_vid(f, p).is_empty():
		return "det står redan en dörr där"
	f.dörrar.append({"pos": p, "typ": typ, "namn": namn_för(f, "dörr"), "kod": kod.strip_edges()})
	return ""


## VILKEN VÄG DÖRREN STÅR (M164). Alex: *"Sen måste den kunna avgöra om det finns väggar nära, och
## isåfall vända dörren så den står mot väggen ... men trädörren är vänd på fel ledd, och jag kan inte
## hitta hur jag vänder den."*
##
## En dörr står TVÄRS gången den sitter i: plattan är bred åt det håll gången inte går. Finns väggar
## både norr och söder om rutan går gången öst-väst, och då är plattan bred i z ("z"). Finns väggarna
## öster och väster blir den bred i x ("x"). `riktning` i dörren är ett MANUELLT val som vinner över
## gissningen — annars vore en dörr i en korsning omöjlig att få rätt.
static func dörr_riktning(f: Dungeon.Floor, d: Dictionary) -> String:
	var vald := str(d.get("riktning", ""))
	if vald == "x" or vald == "z":
		return vald
	var p: Vector2i = d.get("pos", Vector2i(-1, -1))
	var ns := not f.is_floor_at(p + Vector2i(0, -1)) and not f.is_floor_at(p + Vector2i(0, 1))
	var öv := not f.is_floor_at(p + Vector2i(-1, 0)) and not f.is_floor_at(p + Vector2i(1, 0))
	if ns and not öv:
		return "z"
	if öv and not ns:
		return "x"
	return "x"


static func ta_bort_dörr(f: Dungeon.Floor, p: Vector2i) -> bool:
	for i in f.dörrar.size():
		if f.dörrar[i]["pos"] == p:
			f.dörrar.remove_at(i)
			return true
	return false

## Teman = tileset-kataloger under assets/tiles/. Namnen valideras här, som nodtyperna: en bana med
## ett tema som inte finns blir ett fel i editorn i stället för ett platt golv i spelet.
const THEMES := ["asklunden", "krypta", "grotta", "tunnel", "bro"]
const MIN_ENCOUNTERS := 4


static func path_for(stage_id: String, floor_index: int, dir: String = DIR) -> String:
	return "%s%s_%d.json" % [dir, stage_id, floor_index]


static func has_map(stage_id: String, floor_index: int, dir: String = DIR) -> bool:
	return FileAccess.file_exists(path_for(stage_id, floor_index, dir))


## Läser en handritad våning. Saknas filen: null (då generar dungeon.gd en i stället).
## Saknade enemy_id på en strid fylls ur banans egen pool, så en karta inte blir inaktuell bara för
## att fiendelistan ändras.
static func load_map(stage_id: String, floor_index: int, stage = null, bestiary: Dictionary = {}, dir: String = DIR) -> Dungeon.Floor:
	var path := path_for(stage_id, floor_index, dir)
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("kartan %s är inte en karta (trasig JSON)" % path)
		return null
	var f := from_dict(parsed, stage_id, floor_index)
	if f == null:
		return null
	_fill_enemies(f, stage, bestiary)
	return f


## Bygger en Floor ur en karta. Null om rutnätet är obegripligt (fel tecken, olika radlängder).
static func from_dict(d: Dictionary, stage_id: String, floor_index: int) -> Dungeon.Floor:
	var rader: Array = d.get("tiles", [])
	if rader.is_empty():
		push_error("kartan för %s våning %d saknar tiles" % [stage_id, floor_index])
		return null
	var f := Dungeon.Floor.new()
	f.stage_id = stage_id
	f.index = floor_index
	f.theme = str(d.get("theme", ""))
	f.h = rader.size()
	f.w = str(rader[0]).length()
	f.tiles = []
	for y in f.h:
		var rad := str(rader[y])
		if rad.length() != f.w:
			push_error("kartan %s_%d: rad %d är %d tecken, första raden är %d" % [
				stage_id, floor_index, y, rad.length(), f.w])
			return null
		var row: Array[int] = []
		for x in f.w:
			var ch := rad[x]
			if ch != WALL_CH and ch != FLOOR_CH:
				push_error("kartan %s_%d: okänt tecken '%s' på rad %d" % [stage_id, floor_index, ch, y])
				return null
			row.append(Dungeon.FLOOR if ch == FLOOR_CH else Dungeon.WALL)
		f.tiles.append(row)
	# Öppna rum: [x, y, bredd, höjd] i rutor — taket byggs inte där och himlen läggs över (se
	# main._öppen_himmel). Ett slagfält under öppen himmel är alltså något man RITAR in, inte något
	# generatorn hittar på. Formen är Rect2i som resten av rumslistorna.
	for r in d.get("öppna", []):
		if r is Array and (r as Array).size() == 4:
			f.öppna.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		elif r is Rect2i:
			f.öppna.append(r)
	for k in d.get("ytor", {}):
		f.ytor[str(k)] = str(d["ytor"][k])
	# Handplacerad rekvisita (M150). Ett fält till betyder en rad i BÅDA riktningarna — skrivs det i
	# `to_dict` men läses inte här ser filen rätt ut och spelet ignorerar den.
	for r in d.get("rekvisita", []):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var art := str(r.get("art", ""))
		var pos: Array = r.get("pos", [])
		if art.is_empty() or pos.size() != 2:
			push_error("kartan %s_%d: rekvisita utan art eller pos" % [stage_id, floor_index])
			continue
		f.rekvisita.append({"art": art, "pos": Vector2i(int(pos[0]), int(pos[1]))})
	# Dörrarna (M161), samma fälla som rekvisitan: ett fält som bara skrivs syns i filen och ignoreras
	# av spelet.
	for r in d.get("dörrar", []):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var pos: Array = r.get("pos", [])
		if pos.size() != 2:
			push_error("kartan %s_%d: dörr utan pos" % [stage_id, floor_index])
			continue
		f.dörrar.append({"pos": Vector2i(int(pos[0]), int(pos[1])), "typ": str(r.get("typ", "")),
			"namn": str(r.get("namn", "")), "kod": str(r.get("kod", "")),
			"riktning": str(r.get("riktning", ""))})
	for nd in d.get("nodes", []):
		var pos: Array = nd.get("pos", [])
		if pos.size() != 2:
			push_error("kartan %s_%d: nod utan pos" % [stage_id, floor_index])
			continue
		var n := Dungeon.FloorNode.new()
		n.kind = str(nd.get("kind", ""))
		n.pos = Vector2i(int(pos[0]), int(pos[1]))
		n.enemy_id = str(nd.get("enemy_id", ""))
		n.kod = str(nd.get("kod", ""))
		n.gold = int(nd.get("gold", 0))
		n.xp = int(nd.get("xp", 0))
		f.nodes.append(n)
		if n.kind == "start":
			f.start = n.pos
		elif n.kind == "boss":
			f.boss_pos = n.pos
		elif n.kind == "shovel":
			f.shovel_pos = n.pos
	return f


static func to_dict(f: Dungeon.Floor) -> Dictionary:
	var rader := []
	for y in f.h:
		var rad := ""
		for x in f.w:
			rad += FLOOR_CH if f.tiles[y][x] == Dungeon.FLOOR else WALL_CH
		rader.append(rad)
	var noder := []
	for n in f.nodes:
		var d := {"kind": n.kind, "pos": [n.pos.x, n.pos.y]}
		if not n.enemy_id.is_empty():
			d["enemy_id"] = n.enemy_id
		if not n.kod.is_empty():
			d["kod"] = n.kod
		if n.gold != 0:
			d["gold"] = n.gold
		if n.xp != 0:
			d["xp"] = n.xp
		noder.append(d)
	var d := {"stage_id": f.stage_id, "floor": f.index, "theme": f.theme, "tiles": rader,
		"nodes": noder, "ytor": f.ytor}
	if not f.öppna.is_empty():
		var rum := []
		for r in f.öppna:
			var rr: Rect2i = r
			rum.append([rr.position.x, rr.position.y, rr.size.x, rr.size.y])
		d["öppna"] = rum
	if not f.dörrar.is_empty():
		var dörrlista := []
		for r in f.dörrar:
			var p: Vector2i = r.get("pos", Vector2i(-1, -1))
			dörrlista.append({"typ": str(r.get("typ", "")), "kod": str(r.get("kod", "")),
				"namn": str(r.get("namn", "")), "riktning": str(r.get("riktning", "")),
				"pos": [p.x, p.y]})
		d["dörrar"] = dörrlista
	if not f.rekvisita.is_empty():
		var prylar := []
		for r in f.rekvisita:
			var p: Vector2i = r.get("pos", Vector2i(-1, -1))
			prylar.append({"art": str(r.get("art", "")), "pos": [p.x, p.y]})
		d["rekvisita"] = prylar
	return d


## Skriver kartan, men BARA om den går att spela. Felen returneras i stället för att skrivas —
## editorn visar dem, och en trasig våning kan aldrig hamna i spelet genom att man trycker spara.
static func save_map(f: Dungeon.Floor, dir: String = DIR) -> Array:
	var fel := validate(f)
	if not fel.is_empty():
		return fel
	var d := DirAccess.open(dir)
	if d == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		d = DirAccess.open(dir)
	if d == null:
		return ["kunde inte öppna mappen %s" % dir]
	var path := path_for(f.stage_id, f.index, dir)
	var tmp := path + ".tmp"
	var fil := FileAccess.open(tmp, FileAccess.WRITE)
	if fil == null:
		return ["kunde inte skriva %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]]
	fil.store_string(JSON.stringify(to_dict(f), "  ") + "\n")
	fil.close()
	# Samma vana som sparfilen: skriv till temp och byt namn, så en krasch inte lämnar en halv fil.
	if d.file_exists(path.get_file()):
		d.remove(path.get_file())
	var err := d.rename(tmp.get_file(), path.get_file())
	if err != OK:
		return ["kunde inte byta namn på %s (%s)" % [tmp, error_string(err)]]
	return []


## Kontrollerna. Samma krav som generatorn måste uppfylla — annars vore det fria händer att rita en
## våning ingen kan spela klart.
static func validate(f: Dungeon.Floor) -> Array:
	var fel := []
	if f.w < 5 or f.h < 5:
		fel.append("våningen är för liten (%dx%d)" % [f.w, f.h])
	if not f.theme.is_empty() and not THEMES.has(f.theme):
		fel.append("okänt tema: %s (finns: %s)" % [f.theme, ", ".join(THEMES)])
	var antal := {}
	for n in f.nodes:
		antal[n.kind] = int(antal.get(n.kind, 0)) + 1
		if not KINDS.has(n.kind):
			fel.append("okänd nodtyp: %s" % n.kind)
		if not f.is_floor_at(n.pos):
			fel.append("%s står i en vägg (%d,%d)" % [n.kind, n.pos.x, n.pos.y])
	for krav in ["start", "boss", "shovel"]:
		if int(antal.get(krav, 0)) != 1:
			fel.append("exakt en %s krävs (hittade %d)" % [krav, int(antal.get(krav, 0))])
	if int(antal.get("encounter", 0)) < MIN_ENCOUNTERS:
		fel.append("minst %d strider krävs (hittade %d)" % [MIN_ENCOUNTERS, int(antal.get("encounter", 0))])
	# Kan man gå från start till bossen och shoveln? Samma flood fill som generatorn provas med.
	for n in Dungeon.unreachable_nodes(f):
		if n.kind in ["boss", "shovel", "encounter"]:
			fel.append("%s går inte att nå (%d,%d)" % [n.kind, n.pos.x, n.pos.y])
	# Rekvisitan: arten måste finnas som ark (annars står det en osynlig sak i våningen) och rutan
	# måste vara golv. En per ruta — två saker i samma ruta går inte att skilja från en bugg.
	for r in f.dörrar:
		var p: Vector2i = r.get("pos", Vector2i(-1, -1))
		if not DÖRRAR.has(str(r.get("typ", ""))):
			fel.append("okänd dörrtyp: %s" % r.get("typ", ""))
		if p.x < 0 or p.y < 0 or p.x >= f.w or p.y >= f.h:
			fel.append("dörren ligger utanför kartan (%d,%d)" % [p.x, p.y])
		elif not f.is_floor_at(p):
			fel.append("dörren står i en vägg (%d,%d)" % [p.x, p.y])
		if not ["", "x", "z"].has(str(r.get("riktning", ""))):
			fel.append("dörren %s har okänd riktning: %s" % [str(r.get("namn", "?")),
				str(r.get("riktning", ""))])
		if str(r.get("kod", "")).strip_edges().is_empty():
			fel.append("dörren %s (%d,%d) är inte bunden till någon spak eller nyckel"
				% [str(r.get("namn", "?")), p.x, p.y])
	var dörr_rutor := {}
	for r in f.dörrar:
		var p: Vector2i = r.get("pos", Vector2i(-1, -1))
		if dörr_rutor.has(p):
			fel.append("två dörrar på samma ruta (%d,%d)" % [p.x, p.y])
		dörr_rutor[p] = true
	var rekvisita_rutor := {}
	for r in f.rekvisita:
		var art := str(r.get("art", ""))
		var p: Vector2i = r.get("pos", Vector2i(-1, -1))
		if art.is_empty() or not ResourceLoader.exists("assets/props/%s.png" % art):
			fel.append("okänd rekvisita: %s" % art)
		if not f.is_floor_at(p):
			fel.append("rekvisitan %s står i en vägg (%d,%d)" % [art, p.x, p.y])
		if rekvisita_rutor.has(p):
			fel.append("två rekvisiter på samma ruta (%d,%d)" % [p.x, p.y])
		rekvisita_rutor[p] = true
	return fel


## En ny, tom våning: golv i hela ytan innanför en väggkant. Utgångsläget för den som ritar.
static func blank(stage_id: String, floor_index: int, w: int = 17, h: int = 17) -> Dungeon.Floor:
	var f := Dungeon.Floor.new()
	f.stage_id = stage_id
	f.index = floor_index
	f.w = w
	f.h = h
	f.tiles = []
	for y in h:
		var row: Array[int] = []
		for x in w:
			row.append(Dungeon.WALL if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else Dungeon.FLOOR)
		f.tiles.append(row)
	var start := Dungeon.FloorNode.new()
	start.kind = "start"
	start.pos = Vector2i(2, 2)
	f.nodes.append(start)
	f.start = start.pos
	return f


## MER AREA (M160). Alex: *"Om jag kommit till utkanten skall jag kunna klicka på en knapp för att
## lägga till mer area att bygga på, för om man går hela vägen ut mot en kant, så blir det bara svart."*
##
## Våningen växer åt höger och nedåt: det man ritat ligger kvar på sina rutor, och de NYA rutorna är
## berg (vägg) — inget blir spelbart av misstag, man målar golv själv där man vill ha rum. Krympning
## vägras: den skulle kasta bort det man ritat utan att säga till.
static func utöka(f: Dungeon.Floor, w: int, h: int) -> String:
	if w < f.w or h < f.h:
		return "krympning stöds inte: %d×%d är mindre än %d×%d" % [w, h, f.w, f.h]
	if w == f.w and h == f.h:
		return "samma storlek som förut"
	for y in range(f.h):
		for x in range(f.w, w):
			f.tiles[y].append(Dungeon.WALL)
	for y in range(f.h, h):
		var rad: Array[int] = []
		for x in w:
			rad.append(Dungeon.WALL)
		f.tiles.append(rad)
	f.w = w
	f.h = h
	return ""

## --- noder på en ruta: reglerna på ETT ställe ------------------------------------------------
##
## Ban-editorn (tools/editor.sh) och byggläget i spelet (F1) gör exakt samma sak: ställer en nod på en
## ruta och tar bort det som står där. Två kopior av den regeln glider isär förr eller senare — och en
## fiende som blir olika beroende på vilken editor man råkade använda är en bugg ingen letar efter.

## Ställer en nod på rutan. Svarar "" om det gick, annars orsaken i klartext.
static func placera(f: Dungeon.Floor, kind: String, p: Vector2i, stage: Stages.StageDef,
		bestiary: Dictionary, vald_fiende: String = "") -> String:
	if not KINDS.has(kind):
		return "okänd nodtyp: %s" % kind
	if not f.is_floor_at(p):
		return "nodtypen måste stå på golv"
	for n in f.nodes:
		if n.pos == p and n.kind == kind:
			# Samma nodtyp på samma ruta är normalt ett dubbelklick — men en strid man byter FIENDE på
			# ska bytas ut, inte vägras (M155). Annars kan man inte rätta en felvald fiende utan att
			# sudda rutan först.
			var byter_fiende: bool = kind == "encounter" and not vald_fiende.is_empty() and n.enemy_id != vald_fiende
			if not byter_fiende:
				return "%s står redan där" % kind
	# EN HANDPLACERAD FIENDE FÅR VARA VILKEN SOM HELST (M165). Alex: *"sällan det går att klicka på en
	# fiende och sätta ut den."* Vakten här krävde att fienden fanns i BANANS tiers — stage_01 har 4 av
	# 17 fiender i tier 1, så 13 av 17 klick svarade "finns inte i banans tiers" och ingenting hände.
	# Att rita en våning är att bestämma; spelet slår upp fienden i bestiariet (`run.gd`), inte i
	# banans svårighetslista. Bara ett okänt id vägras, och det före `ta_bort` så rutan behålls.
	if kind == "encounter" and not vald_fiende.is_empty() and not bestiary.has(vald_fiende):
		return "okänd fiende: %s" % vald_fiende
	# En nod per ruta: två sorters noder på samma ruta blir två figurer i samma ruta, och man ser inte
	# vad man byggt. Den gamla noden tas bort (och dess pekare nollställs) i stället.
	ta_bort(f, p)
	var ny := Dungeon.FloorNode.new()
	ny.kind = kind
	ny.pos = p
	var svårighet: int = stage.difficulty if stage != null else 1
	if kind == "encounter" and stage != null:
		var pool := Enemies.by_tier(bestiary, stage.tiers)
		if not vald_fiende.is_empty():
			# En uttryckligen vald fiende går före slumptalet, och den hämtas ur BESTIARIET — inte ur
			# banans pool: en handritad våning får ha en fiende från vilken tier som helst.
			var vald: Enemies.EnemyDef = bestiary[vald_fiende]
			ny.enemy_id = vald.id
			ny.xp = vald.xp
			ny.gold = vald.gold
			pool = []
		if not pool.is_empty():
			# Deterministiskt ur banan, våningen och rutan: kartan spelar likadant varje gång, men tål
			# att fiendelistan ändras.
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%d:%d:%d" % [f.stage_id, f.index, p.x, p.y])
			var e = pool[rng.randi_range(0, pool.size() - 1)]
			ny.enemy_id = e.id
			ny.xp = e.xp
			ny.gold = e.gold
	elif kind == "chest":
		ny.gold = 10 + svårighet * 5
	elif kind == "nyckel" or kind == "spak":
		# NYCKELN OCH SPAKEN FÅR ETT NAMN (M163): "spak 1", "nyckel 2". Namnet är det dörrarna binder
		# sig till, så en våning kan ha flera lås som öppnas var för sig — det var hela poängen.
		ny.kod = namn_för(f, "nyckel" if kind == "nyckel" else "spak")
	elif kind == "torch":
		ny.gold = 2 + svårighet
	elif kind == "boss" and stage != null:
		ny.enemy_id = Stages.boss_for(stage, f.index)
	f.nodes.append(ny)
	if kind == "start":
		f.start = p
	elif kind == "boss":
		f.boss_pos = p
	elif kind == "shovel":
		f.shovel_pos = p
	return ""

## Tar bort allt på rutan och nollställer pekarna (start/boss/nedstigning är egna fält vid sidan av
## nodlistan). Svarar med antalet borttagna noder.
static func ta_bort(f: Dungeon.Floor, p: Vector2i) -> int:
	var kvar := []
	var bort := 0
	for n in f.nodes:
		if n.pos == p:
			bort += 1
			if n.kind == "start":
				f.start = Vector2i(-1, -1)
			elif n.kind == "boss":
				f.boss_pos = Vector2i(-1, -1)
			elif n.kind == "shovel":
				f.shovel_pos = Vector2i(-1, -1)
		else:
			kvar.append(n)
	f.nodes = kvar
	return bort

## Flyttar ett urval noder lika långt (M146: drag och piltangenter i karteditorn). Reglerna är
## desamma som för `placera`: en nod måste stå på golv, två noder får inte dela ruta, och pekarna
## start/boss/nedstigning följer med sin nod. Allt-eller-inget — ett halvt flyttat urval är ett
## urval man inte kan lita på, och en flyttad start som pekar på sin gamla ruta går inte att spela.
static func flytta(f: Dungeon.Floor, noder: Array, delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return ""
	if noder.is_empty():
		return "inget valt"
	var med := {}
	for n in noder:
		med[n] = true
	var mål := {}
	for n in noder:
		var p: Vector2i = n.pos + delta
		if not f.is_floor_at(p):
			return "rutan (%d,%d) är inte golv" % [p.x, p.y]
		mål[p] = true
		for annan in f.nodes:
			if med.has(annan):
				continue
			if annan.pos == p:
				return "rutan (%d,%d) är upptagen av %s" % [p.x, p.y, annan.kind]
	if mål.size() != noder.size():
		return "två noder skulle hamna på samma ruta"
	for n in noder:
		n.pos += delta
		if n.kind == "start":
			f.start = n.pos
		elif n.kind == "boss":
			f.boss_pos = n.pos
		elif n.kind == "shovel":
			f.shovel_pos = n.pos
	return ""


## En kopia av en nod på en annan ruta. start/boss/nedstigning får INTE kopieras: `validate` kräver
## exakt en av varje, så kopian vore en våning som inte går att spara.
static func kopiera(f: Dungeon.Floor, n: Dungeon.FloorNode, till: Vector2i) -> String:
	if n == null:
		return "inget valt"
	if n.kind in ["start", "boss", "shovel"]:
		return "%s får det bara finnas en av" % n.kind
	if not f.is_floor_at(till):
		return "rutan (%d,%d) är inte golv" % [till.x, till.y]
	for annan in f.nodes:
		if annan.pos == till:
			return "rutan (%d,%d) är upptagen" % [till.x, till.y]
	var ny := Dungeon.FloorNode.new()
	ny.kind = n.kind
	ny.pos = till
	ny.enemy_id = n.enemy_id
	ny.gold = n.gold
	ny.xp = n.xp
	f.nodes.append(ny)
	return ""


## --- rekvisita på en ruta: reglerna på ETT ställe ------------------------------------------------
##
## Rekvisitan är samma lager som dekoren i `main._bygg_dekor`: ingen kollision, ingen nod — men den
## handplacerade varianten får inte hamna under den slumpade. En per ruta, som noderna.

## Rekvisitan på rutan, eller {} om där inte står någon.
static func rekvisita_vid(f: Dungeon.Floor, p: Vector2i) -> Dictionary:
	for r in f.rekvisita:
		if Vector2i(r.get("pos", Vector2i(-1, -1))) == p:
			return r
	return {}


## Ställer en rekvisit på rutan. Svarar "" om det gick, annars orsaken i klartext.
static func sätt_rekvisita(f: Dungeon.Floor, art: String, p: Vector2i) -> String:
	if art.is_empty():
		return "ingen rekvisit vald"
	if not ResourceLoader.exists("assets/props/%s.png" % art):
		return "okänd rekvisit: %s" % art
	if not f.is_floor_at(p):
		return "rekvisitan måste stå på golv"
	for r in f.rekvisita:
		if Vector2i(r.get("pos", Vector2i(-1, -1))) == p:
			r["art"] = art
			return ""
	f.rekvisita.append({"art": art, "pos": p})
	return ""


## Tar bort rekvisitan på rutan. Svarar true om något togs bort.
static func ta_bort_rekvisita(f: Dungeon.Floor, p: Vector2i) -> bool:
	var kvar := []
	var bort := false
	for r in f.rekvisita:
		if Vector2i(r.get("pos", Vector2i(-1, -1))) == p:
			bort = true
		else:
			kvar.append(r)
	f.rekvisita = kvar
	return bort


## Strider utan fiende får en ur banans pool, deterministiskt ur sin egen position — samma karta
## spelar alltså likadant varje gång, men tål att fiendelistan ändras.
static func _fill_enemies(f: Dungeon.Floor, stage, bestiary: Dictionary) -> void:
	if stage == null or bestiary.is_empty():
		return
	var pool := Enemies.by_tier(bestiary, stage.tiers)
	if pool.is_empty():
		return
	for n in f.nodes:
		if n.kind != "encounter" or not n.enemy_id.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%d:%d:%d" % [f.stage_id, f.index, n.pos.x, n.pos.y])
		var e = pool[rng.randi_range(0, pool.size() - 1)]
		n.enemy_id = e.id
		n.xp = e.xp
		n.gold = e.gold
