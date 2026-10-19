extends RefCounted
class_name Blockar
## BLOCK (M153): färdiga små bitar våning som generatorn lägger in i ett rum som har plats.
##
## Ett block ÄR en vanlig våning i samma JSON-format som `data/maps/` (w, h, tiles, ytor, rekvisita,
## nodes) — Alex ritar det i karteditorn och trycker `O`, och filen hamnar i `data/blocks/`. Inget nytt
## filformat, ingen ny ritare, ingen egen sparare: `MapIo` läser rutorna och `MapIo.placera` sätter
## noderna, så en kista i ett block ger samma guld som en kista någon annanstans.
##
## VARFÖR BLOCK: kartan ska vara slumpad, men rummen ska vara byggda av människor. Generatorn delar
## ytan med BSP och gräver korridorerna EFTERÅT — därför kan ett block stänga hur mycket det vill inuti
## rummet, förbindelserna grävs genom det.
##
## ETT BLOCK BÄR INGEN SPELMEKANIK: inga kistor, facklor eller strider. De räknas av generatorn
## (`_strids_tak`, facklornas tak och "högst en fackla per rum"), och ett block som la dit en egen fackla
## sprängde tre kontroller i `test_dungeon` (29 våningar, 15,6 facklor per våning, två noder på samma
## ruta). Blockets innehåll är rutor, material och rekvisita — innehållet i rummet är spelets.

const MAPP := "res://data/blocks"
## Läser alla block i mappen. Ett block utan giltiga rutor hoppas över med ett fel — en tom stämpel ser
## ut som ett tomt rum, och då letar man i generatorn i stället för i filen.
static func ladda_alla(dir: String = MAPP) -> Array:
	var ut := []
	if not DirAccess.dir_exists_absolute(dir):
		return ut
	for fil in DirAccess.get_files_at(dir):
		if not fil.ends_with(".json"):
			continue
		var b := _läs(dir.path_join(fil))
		if b.is_empty():
			push_error("blocket %s går inte att läsa (w, h och tiles krävs)" % fil)
			continue
		ut.append(b)
	ut.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return ut


static func _läs(sökväg: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(sökväg)
	if text.is_empty():
		return {}
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var rader: Array = d.get("tiles", [])
	if rader.is_empty():
		return {}
	var bredd := str(rader[0]).length()
	for r in rader:
		if str(r).length() != bredd:
			return {}                      # en rad som är kortare gör stämpeln sned: vägra hellre
	# "nodes" LÄSES MED FLIT INTE: se filhuvudet. En gammal fil med noder får behålla dem i JSON men
	# de stämplas aldrig in — då kan ett block inte längre flytta en fackelkontroll i smyg.
	var prylar := []
	for r in d.get("rekvisita", []):
		var p: Array = r.get("pos", [])
		if p.size() == 2:
			prylar.append({"art": str(r.get("art", "")), "pos": Vector2i(int(p[0]), int(p[1]))})
	return {"id": sökväg.get_file().get_basename(), "w": bredd, "h": rader.size(),
		"tiles": rader, "ytor": d.get("ytor", {}), "rekvisita": prylar}


## Roterar blocket 90 grader medurs, `varv` gånger. Rutorna, noderna och rekvisitan följer med —
## roterar man bara rutnätet hamnar kistan i väggen.
static func rotera(b: Dictionary, varv: int) -> Dictionary:
	var v := ((varv % 4) + 4) % 4
	var rader: Array = b["tiles"].duplicate()
	var w: int = b["w"]
	var h: int = b["h"]
	var prylar: Array = (b.get("rekvisita", []) as Array).duplicate(true)
	for i in v:
		var ny := []
		for x in w:
			var rad := ""
			for y in range(h - 1, -1, -1):
				rad += str(rader[y])[x]
			ny.append(rad)
		rader = ny
		# (x, y) -> (h - 1 - y, x) i den VRIDNA rutan, räknat med mätten före vridningen
		for p in prylar:
			var pp: Vector2i = p["pos"]
			p["pos"] = Vector2i(h - 1 - pp.y, pp.x)
		var t := w
		w = h
		h = t
	return {"id": b["id"], "w": w, "h": h, "tiles": rader, "ytor": b.get("ytor", {}),
		"rekvisita": prylar}


## Ryms blocket i rummet? Blockets ytterram ÄR rummets vägg när det läggs kant i kant, så hela blocket
## får plats i hela rummet (inte bara innanför rummets ram). Mätt i generatorn: rummen är 3x3 till 7x7,
## så ett block större än 7x7 får aldrig plats — blocken ska ritas i rummets storlek, inte som en våning.
static func passar(b: Dictionary, rum: Rect2i) -> bool:
	return int(b["w"]) <= rum.size.x and int(b["h"]) <= rum.size.y


## VAR SKA BLOCKET LIGGA (M154)? Alex bestämmer storleken själv ("6x6, 9x3 eller vad jag behöver"),
## och då kan blocket vara större än rummet. Rummet får VÄXA ut i berget tills blocket ryms — men bara
## ut i berg: en ruta som redan är golv (annat rum) får inte tas, för då hade två rum gått i varandra.
## Svarar en tom Rect2i när det inte finns plats åt något håll (då hoppas blocket över).
static func plats(f: Dungeon.Floor, rum: Rect2i, b: Dictionary) -> Rect2i:
	var bw := int(b["w"])
	var bh := int(b["h"])
	if bw <= rum.size.x and bh <= rum.size.y:
		return rum
	var w := maxi(rum.size.x, bw)
	var h := maxi(rum.size.y, bh)
	for hörn in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		var x := rum.position.x - ((w - rum.size.x) if int(hörn[0]) == 1 else 0)
		var y := rum.position.y - ((h - rum.size.y) if int(hörn[1]) == 1 else 0)
		var r := Rect2i(x, y, w, h)
		if r.position.x < 1 or r.position.y < 1 or r.end.x > f.w - 1 or r.end.y > f.h - 1:
			continue
		if not _bara_berg(f, r, rum):
			continue
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				f.tiles[yy][xx] = Dungeon.FLOOR
		return r
	return Rect2i()


## Är allt utanför rummet men innanför `r` berg (vägg)? Rummet självt räknas inte.
static func _bara_berg(f: Dungeon.Floor, r: Rect2i, rum: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if rum.has_point(p):
				continue
			if f.tiles[p.y][p.x] != Dungeon.WALL:
				return false
	return true


## STÄMPLA: blockets INNANMÄTE skrivs in, inte dess ram. Rummets egna väggar står kvar, så ett block
## som är mindre än rummet lämnar golv runt sig (annars skar blockets ram loss en remsa golv som ingen
## gång når — mätt: 25 igenfyllda rutor på en enda våning). Blockets ytterring är bara dess egen form.
static func stämpla(f: Dungeon.Floor, b: Dictionary, rum: Rect2i, varv: int) -> Dictionary:
	var vridet := rotera(b, varv)
	if not passar(vridet, rum):
		return {}
	var bw := int(vridet["w"])
	var bh := int(vridet["h"])
	var offset := rum.position + Vector2i((rum.size.x - bw) / 2, (rum.size.y - bh) / 2)
	var rader: Array = vridet["tiles"]
	for y in rader.size():
		var rad := str(rader[y])
		for x in rad.length():
			if x == 0 or y == 0 or x == bw - 1 or y == bh - 1:
				continue                 # ramen: rummet har redan väggar där
			var p := offset + Vector2i(x, y)
			if p.x < 1 or p.y < 1 or p.x >= f.w - 1 or p.y >= f.h - 1:
				continue
			f.tiles[p.y][p.x] = Dungeon.FLOOR if rad[x] == "." else Dungeon.WALL
	# Materialen (M87) följer med rutorna: ett block som är ritat i sten ska inte bli trä.
	for k in vridet.get("ytor", {}):
		var del := str(k).split(",")
		if del.size() != 2:
			continue
		var p := offset + Vector2i(int(del[0]), int(del[1]))
		if f.is_floor_at(p):
			f.ytor["%d,%d" % [p.x, p.y]] = str(vridet["ytor"][k])
	var satta := 0
	for r in vridet.get("rekvisita", []):
		var p: Vector2i = offset + (r["pos"] as Vector2i)
		if f.is_floor_at(p) and MapIo.sätt_rekvisita(f, str(r["art"]), p).is_empty():
			satta += 1
	return {"id": str(vridet["id"]), "pos": offset, "varv": varv, "rutor": rader.size(),
		"rekvisita": satta}
