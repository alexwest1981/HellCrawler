## BANVERKSTADEN (M60): Alex: *"så får du gärna utöka arean jag kan göra banor i, samt så jag kan
## editera alla banor i spelet"*.
##
## Provet mäter de två halvorna:
##
##   1. BANAN SKRIVS OCH LÄSES TILLBAKA. En ratt i verkstaden ändrar en StageDef, `Stages.skriv`
##      skriver filen och `load_all` läser den igen — samma tal. Gränserna kläms med samma tabell
##      som UI:t visar (`Stages.FÄLT`), så en ändring kan inte skriva en bana spelet inte kan läsa.
##   2. FILEN MAN SKRIVER ÄR BANANS EGEN. Vägen byggs ur id:t; ett okänt id skriver ingenting.
##
## FLIT-BORT: byt `Stages.kläm(...)` mot värdet rakt av och provet faller på "utanför gränsen kläms".
##
##   godot --headless --script res://tests/test_verkstad.gd
extends SceneTree

const PROV := "user://provbanor/"

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

func _initialize() -> void:
	var stages := Stages.load_all()
	check(stages.size() >= 40, "bandata har alla banor", "%d" % stages.size())
	check(Stages.FÄLT.size() >= 5, "verkstaden har fält att ratta", "%d" % Stages.FÄLT.size())

	# --- 1. klämmen ---------------------------------------------------------------------------
	print("— gränserna —")
	check(Stages.kläm("difficulty", 99.0) == 9.0, "svårighetsgraden kläms till 9", "%.0f" % Stages.kläm("difficulty", 99.0))
	check(Stages.kläm("difficulty", -3.0) == 1.0, "…och till 1 nedåt", "%.0f" % Stages.kläm("difficulty", -3.0))
	check(Stages.kläm("floors", 40.0) == 8.0, "våningarna kläms till taket", "%.0f" % Stages.kläm("floors", 40.0))
	check(Stages.kläm("okänt_fält", 5.0) == 0.0, "ett okänt fält ger 0 (ingen gissning)")

	# --- 2. skriv och läs tillbaka ------------------------------------------------------------
	print("— skriv och läs tillbaka —")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROV))
	var en: Stages.StageDef = null
	for s in stages.values():
		en = s
		break
	check(en != null, "en bana att prova med", en.id if en != null else "")
	if en == null:
		quit(1)
		return
	var svårighet_innan := en.difficulty
	en.difficulty = Stages.kläm("difficulty", float(en.difficulty) + 3.0) as int
	en.floors = int(Stages.kläm("floors", 5.0))
	en.gold_bonus = Stages.kläm("gold_bonus", 0.75)
	var skrev: bool = Stages.skriv(en, PROV)
	check(skrev, "banan skrivs till en fil", PROV + en.id + ".json")
	var tillbaka := Stages.load_all(PROV)
	var läst: Stages.StageDef = tillbaka.get(en.id)
	check(läst != null, "och filen går att läsa igen")
	if läst != null:
		check(läst.difficulty == en.difficulty, "svårighetsgraden är den man satte",
			"%d -> %d" % [svårighet_innan, läst.difficulty])
		check(läst.floors == 5, "våningarna är de man satte", "%d" % läst.floors)
		check(is_equal_approx(läst.gold_bonus, 0.75), "guldbonusen är den man satte",
			"%.2f" % läst.gold_bonus)
		check(läst.id == en.id, "id:t är oförändrat", läst.id)
		check(läst.name == en.name, "och namnet följde med", läst.name)
		check(läst.boss == en.boss and läst.final_boss == en.final_boss,
			"bossarna följde med (verkstaden skriver inte bort det den inte rör)")
		check(läst.tiers == en.tiers, "och fiende-tiers likaså", str(läst.tiers))
	# Filens namn är id:t: en tom StageDef skriver ingenting.
	var tom := Stages.StageDef.new()
	check(not Stages.skriv(tom, PROV), "en bana utan id skriver ingen fil")
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(PROV)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROV + f))

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
