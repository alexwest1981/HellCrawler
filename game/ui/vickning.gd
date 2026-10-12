class_name Vickning
extends RefCounted
## SMÅRÖRELSER (idle): en liten sinus som gör att en stillastående figur ser LEVANDE ut i stället för
## att stå som en pappfigur. Alex: *"det skulle vara ballt om de typ rörde sig lite, så t ex att spöket
## gungar fram å tillbaka"*.
##
## EN mekanism för alla figurer (`steg`): ingen nod per fiende, ingen mesh, ingen timer och inget som
## byggs om per bildruta — `steg` sätter `nod.position = viloläge + riktning * sin(...)`, alltså en
## sinus och två vektoroperationer per figur och bildruta. Per typ räcker det med TVÅ rader: en rad i
## `TYPER` (hur typen rör sig) och en i `KLASS` (vilken typ en fiende är). En klass per fiendetyp hade
## varit fler filer och mer kod för samma sinus, och nästa fiende hade behövt en egen klass innan den
## kunde vicka.
##
## FASFRYSNING (proven). Allt som rör sig i tiden läser klockan genom `nu()`. Sätter provet
## `frusen_fas` står klockan still i den fasen, och två körningar ger BYTE-IDENTISKA bilder (jämför
## md5 på skärmbilden — se `game/tests/test_vickning.gd`). `main.gd` läser `frysfas=<tal>` ur
## kommandoraden, så en bild går att jämföra med nästa. Utan frysning vickar figuren olika i varje
## körning — det är själva poängen med rörelsen, och därför ett problem för ett provbildsprov.
static var frusen_fas: float = NAN


## Klockan. ETT ställe läser den, så frysningen gäller allt som är tidsberoende.
static func nu() -> float:
	if not is_nan(frusen_fas):
		return frusen_fas
	return Time.get_ticks_msec() / 1000.0


## Bildrutans tid för allt som räknar sin EGEN tid i stället för att läsa klockan (fladdret i `_fladdra`
## gör det): 0 när fasen är fryst, annars `delta`. Utan den fortsätter elden och lyktan att brinna i fas
## med verkligheten medan figurerna står still — och då är två provbilder fortfarande olika. MÄTT: hela
## vyn skilde sig mellan två körningar i samma frysta fas, upp till 27 av 255 per kanal, för att lyktan
## fladdrade ±2 %.
static func delta(d: float) -> float:
	return 0.0 if not is_nan(frusen_fas) else d


## RÖRELSEN PER TYP.
##
## `axel` är riktningen, läst i KAMERANS bas: x är sidled på skärmen (kamerans höger), y är upp i
## världen. Sidledet är kamerans höger och inte världens x med flit (M66): figuren möts oftast
## FRAMIFRÅN i en gång, och en vickning i världens x försvinner helt när spelaren kommer längs
## x-led — samma fälla som en gång gjorde att figurerna "stod på sidan", fast i rörelse i stället
## för i placering.
##
## `amplitud` i meter (hur långt den vickar), `takt` i radianer per sekund (ett varv = 2π/takt
## sekunder, så 1,0 är drygt sex sekunder — en andning, inte en studs). Siffrorna är små med flit:
## det här ska kännas i ögonvrån, inte synas i bild.
const TYPER := {
	# gungar i sidled med lite bobb — en kropp utan fötter i golvet
	"svävande": {"axel": Vector3(1.0, 0.35, 0.0), "amplitud": 0.055, "takt": 1.00},
	# nästan omärklig andning och en aning vagg — en tung kropp som står still
	"fast":     {"axel": Vector3(0.25, 1.0, 0.0), "amplitud": 0.012, "takt": 1.35},
	# liten tryckning i höjd, snabbare — en kropp som inte står still
	"kryp":     {"axel": Vector3(0.0, 1.0, 0.0),  "amplitud": 0.022, "takt": 2.10},
	# INGEN rörelse. Amplitud 0 är ett VILLKOR och inte ett litet tal: `steg` sätter då viloläget
	# exakt, utan sinus och utan avrundning.
	"stilla":   {"axel": Vector3.ZERO,            "amplitud": 0.0,   "takt": 0.0},
}

## Vilken rörelse varje fiende får, ur bestiariets id (data/enemies/00_bestiary.json). Indelningen är
## den `FIENDE_LOOK` redan gör — andar och vålnader har genomsläpp och kall ton — plus namnen: ben,
## vax och pansar andas, djur och svärmar trycker. En fiende utan rad får `STANDARD`, alltså en rörelse
## i stället för ett fel. Provet (`test_vickning`) räknar ändå bestiariets id mot tabellen, så en ny
## fiende tvingar fram ett medvetet val i stället för att tyst ärva en andning.
const STANDARD := "fast"
const KLASS := {
	# ANDAR OCH VÅLNADER (samma sex som FIENDE_LOOK ger genomsläpp): långsam gungning i sidled.
	"candlewisp": "svävande", "salt_wretch": "svävande", "bell_drowned": "svävande",
	"hollow_choir": "svävande", "pale_reaper": "svävande", "glass_herald": "svävande",
	# …och Ash Maw, som är rök och inte ben (bestiariets egen `shader`: "rok")
	"ash_maw": "svävande",
	# BEN, VAX OCH PANSAR: nästan omärklig andning
	"bone_wretch": "fast", "ossuary_king": "fast", "copper_warden": "fast",
	"wax_sentinel": "fast", "bellmother": "fast",
	# DJUR, KRYP OCH SVÄRMAR: liten tryckning i höjd, snabbare
	"skitterling": "kryp", "mire_hound": "kryp", "chime_swarm": "kryp",
	"verdigris": "kryp", "ash_sovereign": "kryp",
}


static func klass(eid: String) -> String:
	return KLASS.get(eid, STANDARD)


## Sätt figurens position. `bas` är VILOLÄGET (platsen utan vickning) och ägs av den som ställer upp
## figuren: vickningen lägger bara sin förskjutning ovanpå, så uppställningen och rörelsen aldrig
## skriver över varandra.
##
## `fas` är figurens EGEN förskjutning i sinusen — två likadana figurer ska inte vicka i takt, och
## `_add_enemies` räknar den ur index och rutans x (`float(i) * 1,9 + ruta.x`, samma fas som andningen
## och rutanvändningen redan använder).
##
## `kam` ger sidledet; utan kamera vickar figuren i världens x och y, vilket är rätt svar för en nod
## som inte står i en vy.
static func steg(nod: Node3D, bas: Vector3, t: float, klass_namn: String, fas: float,
		kam: Camera3D = null) -> void:
	var p: Dictionary = TYPER.get(klass_namn, TYPER[STANDARD])
	var amp: float = float(p["amplitud"])
	if amp <= 0.0:
		nod.position = bas
		return
	var axel: Vector3 = p["axel"]
	var sid := Vector3.RIGHT
	if kam != null:
		sid = kam.global_transform.basis.x.normalized()
	var riktning := (sid * axel.x + Vector3.UP * axel.y).normalized()
	nod.position = bas + riktning * (sin(t * float(p["takt"]) + fas) * amp)
