## Jukeboxen: spellistan är MAPPEN, inte en lista i koden.
##
## Alex: *"kanske rent av göra så man bara kan lägga till fler låtar, så hamnar de i spelaren?"* — ja,
## och det är hela designen. `ladda()` läser `assets/music` vid start, sorterar filerna på namn och
## gör varje fil till ett spår. En ny låt är en fil i mappen; ingen rad någonstans att komma ihåg.
##
## Spelaren ligger på huvudnoden och inte i HUD:en: ljud hör inte till en yta. Låtarna spelas i
## tur och ordning (spåret tar slut -> nästa), inte i slinga — det är skillnaden mellan en spellista
## och ett stycke, och menyns gamla stycke är nu ett spår bland de andra.
class_name Jukebox
extends AudioStreamPlayer

const MAPP := "res://assets/music"
## Ändelsen avgör vad som blir ett spår. Fler format läggs till här den dag någon lägger en .wav i
## mappen — listan är medvetet kort.
const ÄNDELSER: Array[String] = [".mp3", ".ogg", ".wav"]

var spar: Array[String] = []          ## visningsnamn, samma ordning som strömmarna
var _strömmar: Array[AudioStream] = []
var index := 0

func _init() -> void:
	volume_db = -6.0
	# Spåret tar slut -> nästa. Kopplas här och inte i ladda(), så en omladdning inte lägger på
	# ännu en lyssnare (två lyssnare hade hoppat två spår fram varje gång).
	finished.connect(nästa)

## Läser mappen. Lämnar tillbaka antalet spår, så ett prov kan mäta det utan att räkna filer själv.
func ladda() -> int:
	spar.clear()
	_strömmar.clear()
	var d := DirAccess.open(MAPP)
	if d == null:
		push_warning("jukeboxen hittade ingen musikmapp: %s" % MAPP)
		return 0
	var filer: Array[String] = []
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir():
			var låg := n.to_lower()
			for ändelse in ÄNDELSER:
				if låg.ends_with(ändelse):
					filer.append(n)
					break
		n = d.get_next()
	d.list_dir_end()
	filer.sort()
	for f in filer:
		var ström: AudioStream = load(MAPP + "/" + f)
		if ström == null:
			continue
		# Slingan AV på varje spår: jukeboxen går vidare till nästa, den mal samma låt.
		if ström is AudioStreamMP3:
			(ström as AudioStreamMP3).loop = false
		elif ström is AudioStreamOggVorbis:
			(ström as AudioStreamOggVorbis).loop = false
		_strömmar.append(ström)
		spar.append(f.get_basename().replace("_", " "))
	index = 0
	return spar.size()

func antal() -> int:
	return _strömmar.size()

func nuvarande() -> String:
	return spar[index] if index >= 0 and index < spar.size() else ""

## Spela spår nummer i. Negativa och för stora tal läggs i ringen, så en anropare som räknar fel
## hamnar på ett spår i stället för i tystnad.
func spela(i: int) -> String:
	if _strömmar.is_empty():
		return ""
	index = wrapi(i, 0, _strömmar.size())
	stream = _strömmar[index]
	play()
	return nuvarande()

func nästa() -> String:
	return spela(index + 1)

func förra() -> String:
	return spela(index - 1)

## Startar spellistan på ett spår med ett givet namn (utan ändelse och med _ som mellanslag).
## Menyn vill börja på sitt eget stycke; hittas det inte börjar listan från början.
func spela_efter_namn(namn: String) -> String:
	var i := spar.find(namn)
	return spela(i if i >= 0 else 0)
