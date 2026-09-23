## Provet biter på det enda som kan förstöra spelarens profil: att en körning som bara ska
## fotografera skriver i samma fil som spelet. Mätt fel innan raden fanns: en körning som
## skulle fotografera kartan sänkte guldet 1852 -> 237, och en samtidig session sparade
## det värdet. Fixen är en enda flaskhals (Meta.PATH), därför mäts den och inget annat.
##   godot --headless --script res://tests/test_sparfil.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	print(("  ok   %s" if ok else "  FEL  %s") % what + ("" if detail.is_empty() else "  (%s)" % detail))
	if not ok:
		fails += 1

func _init() -> void:
	check(Meta.PATH == "user://save.json", "vanlig start skriver i spelarens profil", Meta.PATH)
	Meta.fotolage(true)
	check(Meta.PATH != "user://save.json", "fotoläget får en egen fil", Meta.PATH)

	var m := Meta.load_or_new()
	m.gold = 7
	m.save()
	check(FileAccess.file_exists(Meta.PATH), "fotoläget kan spara sin egen fil", Meta.PATH)

	var profil := "user://save.json"
	var orörd := true
	if FileAccess.file_exists(profil):
		orörd = JSON.parse_string(FileAccess.get_file_as_string(profil)).get("gold") != 7
	check(orörd, "spelarens profil är orörd av fotoläget")

	Meta.fotolage(false)
	check(Meta.PATH == "user://save.json", "och tillbaka efter fotoläget", Meta.PATH)
	DirAccess.remove_absolute("user://save_prov.json")

	print("  TOTALT: %d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
