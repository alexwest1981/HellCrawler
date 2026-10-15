## LJUDTÄCKNINGEN (M122). MÄTT mot referensen: Vampire Crawlers har 106 AudioClip och vi spelade NIO,
## medan 400 licensierade ljud låg oanvända i `assets/tredjepart/ljud_400`. Värst av allt: anrop som
## frågade efter ett ljud som inte fanns (`_sfx("select")`) — de SÅG ut att spela något och spelade
## ingenting, utan ett ljud, utan en rad i loggen.
##
## Provet grindar båda hållen:
##   1. varje namn koden frågar efter finns i `data/sfx.json` OCH har en fil på disk,
##   2. varje rad i kartan pekar på en fil som finns (en död rad är en platshållare som lurar),
##   3. täckningen: hur många av paketets 400 ljud som faktiskt används, och hur många händelser
##      koden spelar ljud för. Siffran skrivs ut varje körning så en ny tyst händelse syns som ett hopp.
extends SceneTree

const KARTA := "res://data/sfx.json"
const PAKET := "res://assets/tredjepart/ljud_400"

var checks := 0
var fails := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", what, "" if detail.is_empty() else "  (%s)" % detail])


func _initialize() -> void:
	print("— ljudkartan —")
	var text := FileAccess.get_file_as_string(KARTA)
	var karta: Variant = JSON.parse_string(text)
	check(typeof(karta) == TYPE_DICTIONARY, "data/sfx.json går att läsa", KARTA)
	if typeof(karta) != TYPE_DICTIONARY:
		print("%d kontroller, %d fel" % [checks, fails])
		quit(1)
		return

	# 2) Rader som pekar på VÅRA EGNA ljud (assets/sfx) måste ha filen — de är i git, så en död rad är
	#    ett fel. Rader som pekar på det olicensierade paketet (`assets/tredjepart/ljud_400`, utanför
	#    git enligt CREDITS.md) får saknas: en färsk klon spelar då inget där, vilket är hela poängen
	#    med att paketet hålls utanför. Att kräva filen hade gjort provet rött i en färsk klon utan
	#    att något var fel med koden (mätt: paketet är ocommittat — `git ls-files` gav 0 träffar).
	var döda: Array = []
	var utanför_git: Array = []
	var antal_ljud := 0
	for name in karta:
		if str(name).begins_with("_"):
			continue
		antal_ljud += 1
		var path := str(karta[name])
		if ResourceLoader.exists(path):
			continue
		if path.begins_with("res://assets/sfx/"):
			döda.append("%s -> %s" % [name, path])
		else:
			utanför_git.append(str(name))
	check(döda.is_empty(), "varje rad mot våra EGNA ljud pekar på en fil som finns",
		"%d ljud i kartan, %s" % [antal_ljud, "inga döda rader" if döda.is_empty() else ", ".join(döda)])
	if not utanför_git.is_empty():
		print("  not  %d ljud ligger i det olicensierade paketet (utanför git): de tiger i en färsk klon  (%s)"
			% [utanför_git.size(), ", ".join(utanför_git.slice(0, 6))])

	# 1) Varje namn KODEN frågar efter måste finnas i kartan. Fällan provet finns för: `_sfx("select")`
	#    (inget select.wav) — ett anrop som ser ut att spela något och inte gör det.
	var re := RegEx.new()
	# FÅNGAR HELA ANROPET, även med parenteser inuti: `_sfx("a" if x.size() > 1 else "b")`. Mönstret
	# `[^)]*` stannade vid första `)` (inuti `size()`) och missade då namnet EFTER villkoret — provet
	# såg 17 namn i stället för 18 och kallade `enemy_die` oanvänt (mätt: en grind med en blind fläck).
	re.compile("_sfx\\((.*)\\)")
	var inre := RegEx.new()
	inre.compile("\"([a-z_0-9]+)\"")
	var efterfrågade := {}
	var filer := _gd_filer("res://")
	for f in filer:
		# PROVEN HOPPAS ÖVER: deras kommentarer förklarar mönstret med exempel (`_sfx("a" if … else "b")`),
		# och ett exempel i en kommentar är inte ett anrop. Mätt: utan hoppet krävde grinden ljud som
		# heter "a" och "b".
		if f.begins_with("res://tests/"):
			continue
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			for n in inre.search_all(m.get_string(1)):
				efterfrågade[n.get_string(1)] = f
	var saknade: Array = []
	for name in efterfrågade:
		if str(name).begins_with("_"):
			continue
		if not karta.has(name):
			saknade.append("%s (i %s)" % [name, efterfrågade[name]])
	check(saknade.is_empty(), "varje ljud koden frågar efter finns i kartan",
		"%d namn i %d .gd-filer, %s" % [efterfrågade.size(), filer.size(),
			"inget tyst anrop" if saknade.is_empty() else ", ".join(saknade)])

	# 3) Täckningen, som siffra. Den ska RÖRA SIG uppåt när en tyst händelse kopplas in.
	var paketfiler := _filer_under(PAKET, ".wav")
	var från_paketet := 0
	for name in karta:
		if str(karta[name]).begins_with(PAKET) and paketfiler.has(str(karta[name])):
			från_paketet += 1
	check(från_paketet > 0, "paketets ljud används (de låg oanvända i 400 filer)", "%d av %d wav-filer" % [
		från_paketet, paketfiler.size()])
	print("  LÄGET: %d ljud i kartan, %d händelser koden spelar ljud för, %d filer i paketet" % [
		antal_ljud, efterfrågade.size(), paketfiler.size()])

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Alla .gd-filer under en katalog (inte `.godot`: den cachen är inte källkod).
func _gd_filer(dir_path: String) -> Array:
	var ut: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return ut
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				ut += _gd_filer(dir_path.path_join(n))
		elif n.ends_with(".gd"):
			ut.append(dir_path.path_join(n))
		n = d.get_next()
	d.list_dir_end()
	return ut


func _filer_under(dir_path: String, ändelse: String) -> Array:
	var ut: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return ut
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			ut += _filer_under(dir_path.path_join(n), ändelse)
		elif n.ends_with(ändelse):
			ut.append(dir_path.path_join(n))
		n = d.get_next()
	d.list_dir_end()
	return ut
