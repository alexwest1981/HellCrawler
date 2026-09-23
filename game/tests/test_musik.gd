## Jukeboxen (M54): spellistan ÄR mappen.
##
## Provet mäter det som är själva löftet till Alex — *"gör så man bara kan lägga till fler låtar, så
## hamnar de i spelaren"* — genom att räkna filerna i assets/music och jämföra med jukeboxens spår.
## En hårdkodad lista i koden skulle falla på den första raden: den kan inte veta hur många filer
## mappen har. Resten är ringen (nästa/förra), namnen och att varje spår går att spela.
##
##   godot --headless --script res://tests/test_musik.gd
extends SceneTree

const MAPP := "res://assets/music"
const ÄNDELSER := [".mp3", ".ogg", ".wav"]

var fails := 0
var checks := 0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## Filerna i mappen, räknade av provet självt — inte ur jukeboxens egen lista.
func _filer_i_mappen() -> Array[String]:
	var ut: Array[String] = []
	var d := DirAccess.open(MAPP)
	if d == null:
		return ut
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir():
			for ä in ÄNDELSER:
				if n.to_lower().ends_with(ä):
					ut.append(n)
					break
		n = d.get_next()
	d.list_dir_end()
	ut.sort()
	return ut

func _initialize() -> void:
	print("— jukeboxen —")
	var filer := _filer_i_mappen()
	check(filer.size() >= 6, "låtarna ligger i mappen", "%d filer" % filer.size())

	var jb := Jukebox.new()
	# In i trädet: en AudioStreamPlayer kan bara spela som barn till en nod, och provet ska mäta
	# riktig uppspelning — inte bara vilket spår som blev valt.
	root.add_child(jb)
	# En bildruta först: noden är i trädet först efter att trädet kört ett varv, och först då går
	# det att spela (mätt: "Playback can only happen when a node is inside the scene tree").
	await process_frame
	var antal := jb.ladda()
	check(antal == filer.size(), "jukeboxen hittar ALLA filer i mappen — inte en lista i koden",
		"%d spår mot %d filer" % [antal, filer.size()])
	check(jb.spar.size() == antal, "varje spår har ett namn")

	# Namnen kommer ur filnamnen, med understreck utbytta: det är så en ny fil får sin titel utan
	# att någon skriver in den någonstans.
	var väntade := []
	for f in filer:
		väntade.append(String(f).get_basename().replace("_", " "))
	var fattas := []
	for n in väntade:
		if not jb.spar.has(n):
			fattas.append(n)
	check(fattas.is_empty(), "namnen kommer ur filnamnen", ", ".join(fattas))
	var unika := {}
	for n in jb.spar:
		unika[n] = true
	check(unika.size() == jb.spar.size(), "inga två spår heter samma sak",
		"%d namn" % unika.size())

	# Spåren: varje ström ska finnas och ha en längd. En tom eller trasig fil hade blivit tystnad
	# i spelaren utan att något sade till.
	var tysta := []
	for i in jb.antal():
		var s: AudioStream = jb._strömmar[i]
		if s == null or s.get_length() <= 0.0:
			tysta.append(jb.spar[i])
	check(tysta.is_empty(), "alla spår går att spela och har en längd", ", ".join(tysta))
	var slingar := []
	for i in jb.antal():
		var s: AudioStream = jb._strömmar[i]
		if s is AudioStreamMP3 and (s as AudioStreamMP3).loop:
			slingar.append(jb.spar[i])
	check(slingar.is_empty(), "ingen låt slingar — listan går vidare till nästa", ", ".join(slingar))

	# Ringen: sista spåret går till det första, och ett för litet tal hamnar rätt.
	var spelat := jb.spela(0)
	check(spelat == jb.spar[0], "första spåret går att spela", spelat)
	var sista := jb.spela(jb.antal() - 1)
	check(sista == jb.spar[jb.antal() - 1], "sista spåret går att spela", sista)
	var efter := jb.nästa()
	check(efter == jb.spar[0], "efter sista kommer första", efter)
	var före := jb.förra()
	check(före == jb.spar[jb.antal() - 1], "och före första kommer sista", före)
	check(jb.spela(999) == jb.spar[(999 % jb.antal())], "ett för stort tal läggs i ringen",
		jb.nuvarande())

	# Menyns stycke är ett spår bland de andra, och menyn ska börja på sitt eget.
	var meny := jb.spela_efter_namn("Dungeon Arpeggios")
	check(meny == "Dungeon Arpeggios", "menyns stycke hittas på namn", meny)
	check(jb.nuvarande() == "Dungeon Arpeggios", "och är spåret som spelas")
	var okänt := jb.spela_efter_namn("finns_inte_alls")
	check(okänt != "" and jb.nuvarande() != "Dungeon Arpeggios",
		"ett namn som inte finns börjar om från första spåret i stället för att bli tyst", okänt)

	jb.free()
	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
