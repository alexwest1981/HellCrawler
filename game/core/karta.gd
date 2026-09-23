## Kartan (M41): världskartan som DATA — bilden, vinkeln och nodernas plats på den.
##
## Alex: *"Här har du en karta över helvetet i 16bit. Jag skulle vilja ha den lätt vinklad, så när man
## går över kartan, så ser man den som i 3d-ish, och fokus följer spelarens markering. Du behöver
## placera ut noder som matchar punkter på kartan som kan vara en bana. ... en nod kan innehålla upp
## till 10 olika levels, baserat på svårighetsgrad ... och en grön bock visar om den är klar, men man
## skall kunna spela om en bana om man behöver farma pengar."*
##
## Filen är därför ritningen och banorna åtskilda: BILDEN äger utseendet (hans egen 16-bit-karta),
## noderna äger bara en plats på den (x/y i procent) och en lista av banor i svårighetsordning. Nya
## banor behöver inte röra ritkoden, och en flyttad nod är ett tal i en JSON — inte en kodändring.
##
## Ordningen i `nivåer` ÄR svårighetsordningen: nivå 1 är den lättaste. Upp till MAX_NIVÅER per nod.
##
## SEKTIONER (Alex): *"vi behöver även föra så man inte kan gå till en del av kartan om man inte klarat
## minst en bana av delen innan, det måste vara uppdelat i sektioner 1, 2, 3 osv."* Sektionen är alltså
## porten på kartan: sektion 1 är öppen, sektion N öppnar när minst EN bana i sektion N-1 är klarad.
## Grinden ligger i DATAN (`sektion` per nod), inte i koden, så han kan flytta en nod mellan sektioner
## i editorn (eller i filen) utan att röra upplåsningen.
##
## Laddaren VALIDERAR. En nod utanför bilden, en nivå som inte finns i bandata eller en elfte nivå är
## fel i DATA, och de ska synas som ett fel — inte som en nod som inte går att klicka på. `fel` bär
## raderna och provet läser dem.
class_name Karta
extends RefCounted

const PATH := "res://data/karta.json"
const MAX_NIVÅER := 10             ## Alex' tak: en nod rymmer upp till tio nivåer
const SEKTION_STANDARD := 3        ## noder per sektion när filen inte säger något (gamla kartor)
const BILD_BREDD := 1280.0         ## kartbildens px (16:9, samma mått som fönstret)
const BILD_HÖJD := 720.0

var bild := ""                     ## resursvägen till kartan
var sökväg := PATH                 ## filen kartan lästes ur — editorn skriver tillbaka till DEN
var zoom := 1.9                    ## kartans skala mot vyns bredd (1,0 = hela kartan i vyn)
var komprimering := 0.82           ## vinkeln: y-led kläms ihop (sett snett uppifrån)
var lutning := 0.18                ## vinkeln: hur mycket kartan skjuts i sidled nedåt
var noder: Array = []              ## [{plats, x, y, sektion, nivåer: [bana, ...]}]
var fel: Array = []                ## rader om något i filen inte håller

static func ladda(fil := PATH) -> Karta:
	var k := Karta.new()
	k.sökväg = fil
	var sökväg := fil
	if not FileAccess.file_exists(sökväg):
		k.fel.append("kartfilen saknas: %s" % sökväg)
		return k
	var rå = JSON.parse_string(FileAccess.get_file_as_string(sökväg))
	if not (rå is Dictionary):
		k.fel.append("kartfilen går inte att läsa som JSON: %s" % sökväg)
		return k
	k.bild = str(rå.get("bild", ""))
	k.zoom = float(rå.get("zoom", k.zoom))
	k.komprimering = float(rå.get("komprimering", k.komprimering))
	k.lutning = float(rå.get("lutning", k.lutning))
	if not ResourceLoader.exists(k.bild):
		k.fel.append("kartans bild finns inte: %s" % k.bild)
	var bandata: Dictionary = Stages.load_all()
	for n in rå.get("noder", []):
		var nr: int = k.noder.size()
		var nod := {
			"plats": str(n.get("plats", "")),
			"x": float(n.get("x", 50.0)),
			"y": float(n.get("y", 50.0)),
			# Sektionen är 1-baserad. Saknas den (en karta skriven före sektionerna) grupperas noderna
			# i tre och tre — samma form som filen har nu, så gamla kartor får en vettig grind.
			"sektion": maxi(1, int(n.get("sektion", 1 + nr / SEKTION_STANDARD))),
			"nivåer": [],
		}
		for id in n.get("nivåer", []):
			nod["nivåer"].append(str(id))
		if n.has("sektion") and int(n["sektion"]) < 1:
			k.fel.append("nod %d har sektion %d (den första är 1)" % [nr, int(n["sektion"])])
		if float(nod["x"]) < 0.0 or float(nod["x"]) > 100.0 or float(nod["y"]) < 0.0 or float(nod["y"]) > 100.0:
			k.fel.append("nod %d ligger utanför kartan (%.1f, %.1f)" % [nr, nod["x"], nod["y"]])
		if (nod["nivåer"] as Array).is_empty():
			k.fel.append("nod %d har inga nivåer" % nr)
		if (nod["nivåer"] as Array).size() > MAX_NIVÅER:
			k.fel.append("nod %d har %d nivåer (taket är %d)" % [nr, (nod["nivåer"] as Array).size(),
				MAX_NIVÅER])
		for id in nod["nivåer"]:
			if not bandata.has(id):
				k.fel.append("nod %d: banan %s finns inte i bandata" % [nr, id])
		k.noder.append(nod)
	if k.noder.is_empty():
		k.fel.append("kartfilen har inga noder")
	return k

## --- Alex' editor: att GÖRA fler banor, inte bara flytta dem (M60) ---------------------------
##
## Alex: *"så du får gärna utöka arean jag kan göra banor i, samt så jag kan editera alla banor i
## spelet"*. Kartan ÄR platsen han gör banor på, så fler banor = fler noder. En nod finns bara för att
## den bär minst en nivå (se `ladda`: "nod N har inga nivåer" är ett fel), så en ny nod skapas med en
## nivå i sig, och den nod man tömmer tas bort. Invarianten hålls kvar i stället för att editorn
## lägger en tom nod i filen som spelet sedan klagar på.

## Flyttar nivå `k` ur nod `från` till en NY nod på (x, y) i sektionen `sektion`. Svarar med den nya
## nodens index, eller -1 om inget kunde flyttas. Den gamla noden tas bort om den blev tom — och den
## nya nodens namn blir banans eget, så en ny plats heter något man känner igen i listan.
func nivå_till_ny_nod(från: int, k: int, x: float, y: float, sektion: int) -> int:
	if från < 0 or från >= noder.size():
		return -1
	var lista: Array = noder[från]["nivåer"]
	if k < 0 or k >= lista.size():
		return -1
	var bana := str(lista[k])
	var namn := bana
	for s in Stages.load_all().values():
		if s.id == bana:
			namn = s.name
			break
	var ny := {
		"plats": namn,
		"x": roundf(clampf(x, 0.0, 100.0) * 10.0) / 10.0,
		"y": roundf(clampf(y, 0.0, 100.0) * 10.0) / 10.0,
		"sektion": maxi(1, sektion),
		"nivåer": [bana],
	}
	lista.remove_at(k)
	if lista.is_empty():
		noder.remove_at(från)
	noder.append(ny)
	return noder.size() - 1

## Byter namn på en plats. Tomt namn avvisas: en plats utan namn går inte att känna igen i listan.
func byt_plats(i: int, namn: String) -> bool:
	if i < 0 or i >= noder.size() or namn.strip_edges().is_empty():
		return false
	noder[i]["plats"] = namn.strip_edges()
	return true

func antal() -> int:
	return noder.size()

func nivåer(i: int) -> Array:
	return noder[i]["nivåer"] if i >= 0 and i < noder.size() else []

## Nodens sektion (1-baserad). Sektionen är kartans grind, inte banordningen: innanför en öppen
## sektion får alla banor spelas, och nästa sektion öppnar på EN klarad bana i den förra.
func sektion(i: int) -> int:
	if i < 0 or i >= noder.size():
		return 1
	return maxi(1, int(noder[i].get("sektion", 1)))

## Alla sektionsnummer i ordning (1, 2, 3 ...).
func sektioner() -> Array:
	var ut := []
	for n in noder:
		var s := maxi(1, int(n.get("sektion", 1)))
		if not ut.has(s):
			ut.append(s)
	ut.sort()
	return ut

## Indexen för noderna i en sektion, i filens ordning.
func sektion_noder(n: int) -> Array:
	var ut := []
	for i in noder.size():
		if sektion(i) == n:
			ut.append(i)
	return ut

## En bana är KLARAD när hela vägen ned är gången — samma mått som kartans gröna bock.
static func klarad(id: String, bandata: Dictionary, meta: Meta) -> bool:
	var s: Stages.StageDef = bandata.get(id)
	return s != null and meta != null and int(meta.best_floor.get(id, 0)) >= int(s.floors)

## Hur många banor i sektionen som är klarade (0 = ingen).
func sektion_klar(n: int, meta: Meta) -> int:
	var bandata: Dictionary = Stages.load_all()
	var antal := 0
	for i in sektion_noder(n):
		for id in nivåer(i):
			if klarad(str(id), bandata, meta):
				antal += 1
	return antal

## Får man gå in i sektionen? Sektion 1 är öppen; sektion N kräver minst EN klarad bana i sektion N-1
## (Alex: "man inte kan gå till en del av kartan om man inte klarat minst en bana av delen innan").
func sektion_öppen(n: int, meta: Meta) -> bool:
	if n <= 1:
		return true
	if meta == null:
		return false
	return sektion_klar(n - 1, meta) > 0

## Nodens plats i procent av bilden.
func plats(i: int) -> Vector2:
	if i < 0 or i >= noder.size():
		return Vector2.ZERO
	return Vector2(float(noder[i]["x"]), float(noder[i]["y"]))

## Nodens plats i BILDENS px — den som transformen ritar ur.
func bild_px(i: int) -> Vector2:
	var p := plats(i)
	return Vector2(p.x / 100.0 * BILD_BREDD, p.y / 100.0 * BILD_HÖJD)

## Alla bannamn i en nod, i svårighetsordning. Namnen är banans egna (och därmed översatta); en nod
## har inget eget namn att översätta, för platsen ÄR sina nivåer.
func nivå_namn(i: int) -> String:
	var b := nivåer(i)
	if b.is_empty():
		return ""
	return Tr.name_of("stage", str(b[0]), str(b[0]))

## Skriver tillbaka nodernas platser (kart-editorn). Skrivs till res:// — projektet körs ur källkoden,
## och en redigerad karta ska hamna i filen man committar, inte i en cache.
func skriv(fil := "") -> bool:
	# Tom väg = skriv tillbaka till filen man LÄSTE (editorn). En egen variabel: namnet `sökväg`
	# är fältet, och att skugga det i sin egen tilldelning är precis den sortens fälla som kostar en dag.
	var mål := fil if not fil.is_empty() else sökväg
	var ut := {"bild": bild, "zoom": zoom, "komprimering": komprimering, "lutning": lutning, "noder": []}
	for n in noder:
		ut["noder"].append({
			"plats": str(n["plats"]),
			"x": roundf(float(n["x"]) * 10.0) / 10.0,
			"y": roundf(float(n["y"]) * 10.0) / 10.0,
			# Sektionen MÅSTE med — annars suddade editorn ut den varje gång han sparade en flyttad nod.
			"sektion": maxi(1, int(n.get("sektion", 1))),
			"nivåer": n["nivåer"],
		})
	var f := FileAccess.open(mål, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(ut, " ", false))
	f.close()
	return true
