## Världskartan (M41): Alex' 16-bit-karta över helvetet, lätt vinklad, med noder som fokus följer.
##
## Alex: *"Jag skulle vilja ha den lätt vinklad, så när man går över kartan, så ser man den som i
## 3d-ish, och fokus följer spelarens markering. Du behöver placera ut noder som matchar punkter på
## kartan som kan vara en bana. Om du gör en editor åt mig för kartan, så kan jag placera ut noderna
## om det underlättar. Sedan nästa punkt där, är att en nod kan innehålla upp till 10 olika levels,
## baserat på svårighetsgrad, så man väljer väl där vilken man vill köra, och en grön bock visar om
## den är klar, men man skall kunna spela om en bana om man behöver farma pengar."*
##
## Delningen är densamma som i byn: BILDEN och siffrorna i `data/karta.json` äger utseendet och
## platserna, den här filen äger bara det som bär information — noderna, nivåväljaren, kortet,
## markeringen och editorn. Att flytta en nod är ett tal i en JSON, inte en kodändring.
##
## Vinkeln är ingen 3D-kamera utan två tal ur filen: `komprimering` klämmer ihop kartan i y-led och
## `lutning` skjuter de nedre raderna i sidled. Bilden ritas därför i horisontella REMSOR — varje
## remsa är fortfarande en rak ruta på skärmen, så ingen shader behövs.
## ponytail: remsor i stället för en shader; byt till en riktig projektion om kameran ska kunna vridas.
##
## Kameran hänger på markeringen: den valda noden glider mot mitten av den fria kartytan (ovanför
## kortet, så en nod aldrig hamnar bakom sin egen panel), och kameran kläms innanför kartans kant.
## Nodens plats på SKÄRMEN räknas alltid ur transformen (`plats`) — aldrig ur en egen kopia, annars
## glider markeringen ifrån bilden.
class_name WorldMapView
extends Control

## Banan man valde att spela. Enter, klick och provet går samma väg.
signal vald(stage_id: String)

# --- kartan (data) ---
var karta: Karta = null                ## sätts av main.gd FÖRE `visa()`
var editor := false                    ## kart-editorn: dra noderna med musen, S = spara

# --- mått (vyn är 480x270) ---
const NOD := 9.0                       ## nodens radie: en medaljong, inte en ruta
const KLICKRADIE := 15.0
const PULS := [0, 1, 2, 1]             ## markörens puls i fyra bildrutor
const BAS := 480.0 / Karta.BILD_BREDD  ## bildens px -> vyns px vid zoom 1
const REMSOR := 96                     ## lutningen ritas i så här många horisontella remsor
const KAMERA_FART := 5.0               ## hur fort fokus glider mot den valda noden (per sekund)
## INFORMATIONSREMSAN LIGGER PÅ KARTAN (M118). Alex såg kartan fylla ~50 % av fönstret med rutan
## under, kontrollraden vid 75 % och en TOM svart yta med ram längst ned. Rutorna flyttade ned kartan
## i stället för att ligga ovanpå den. Nu är kartytan HELA vyn (se `_kartruta`) och remsan en tunn
## sak längst ned: 44 px i designmåttet, tre rader, och den täcker bara den nedersta åttondelen.
## 40 och inte 66: den valda platsen längst ned på kartan (Nedre porten, 88 %) hamnar som mest
## 0,12 x kartans höjd över vyns underkant — 50 px i 480x270 — och en remsa på 66 px hade lagt sig
## över markören. `test_karta_full` är grinden: "varje vald plats hamnar i kartytan ovanför remsan".
const KORT_H := 40.0
const KORT_MARG := 6.0
const PANEL_BREDD := 174.0             ## nivåpanelen: samma ruta som förut, ovanför remsan
const PANEL_HÖJD := 108.0
const LEGEND_STEG := 64.0              ## px mellan teckenförklaringens tre märken
const LEGEND_BREDD := 192.0            ## teckenförklaringens yta, mätt från remsans högerkant
const RAD_HÖJD := 9.0
const HINT_MARG := 6.0                 ## ledtrådsraden ligger I remsan (sista raden)
## VÄGEN MELLAN PLATSERNA (M120). Färgen är minikartans jordväg (palett 18) — samma väg ska se ut som
## samma väg i båda kartorna. Fallan under den är mörk: världskartans BILD är ljus på sina ställen
## (snö, lava), och en ensam jordväg försvann i snön. Fållan är bredare än vägen, så det som syns
## runt kanten är en kant och inte en andra väg.
const VÄG_FÄRG := 18
const VÄG_BREDD := 3.0
const VÄG_FÅLLA := 5.0

var _noder: Array = []                 ## [{plats, nivåer, öppen, klar, delvis, finns, ...}]
var _vald := 0
var _besked := ""                      ## klartextraden när man försöker gå in i en låst plats
var _sparad := ""                      ## editorns kvitto ("kartan sparad")
var _ordning: Array = []               ## banordningen (main.gd äger den)
var _stages: Dictionary = {}
var _meta: Meta = null
## VÄGEN MELLAN PLATSERNA (M120): paren ur `Karta.länkar` (se den för varifrån kopplingarna kommer).
## Byggs om i `visa()` tillsammans med noderna — banordningen ändras inte under en körning, men
## kartan läses om varje gång skärmen visas, och en väg byggd ur förra lägets noder vore en väg som
## inte finns.
var _länkar: Array = []
## Paren som RITADES senast, som SEGMENT ([ändpunkt A, ändpunkt B]) — samma grepp som minikartans
## `_ritade_linjer`. Provet mäter den här listan i stället för att räkna om kartans mått själv: det som
## ska bevisas är vad kartan ritar, och en egen formel i provet kunde glida ifrån `_draw`. Att strecken
## bär sina ÄNDPUNKTER (och inte bara paret) är det som gör att ett streck på fel ställe syns.
var _ritade_vägar: Array = []
## Granskningsflagga (`vag=0`): vägarna av. Utan den går det inte att MÄTA hur många pixlar linjerna
## lägger till i SAMMA scen — samma skäl som `crt=0` för CRT-lagret.
var vägar_av := false
## GÅNGAREN (M122): EN figur som går mellan platserna — samma komponent som i byn (`ui/gangare.gd`).
## Ingen promenad kopplas hit längre (M138): markören snappar till platsen man valt.
## Den går i KARTANS px (före kameran), så den står kvar på sin plats på kartan medan kameran glider.
var _gångare: Gångare = null
var _figur: Texture2D = null
var _figur_väg := ""

## Filen markören ritar (jämförs med byns i provet — samma hjälte på båda ställena, M138).
func figur_väg() -> String:
	return _figur_väg
var _t := 0.0
var _ram := 0
var _tex: Texture2D = null
var _kamera := Vector2.ZERO            ## kartans px i kartytans mitt (glider mot den valda noden)
var _kamera_startad := false
var _panel := false                    ## nivåpanelen är öppen
var _nivå := 0                         ## nivån panelen står på
var _drag := -1                        ## editorn: noden som hålls med muspekaren
var _drag_mus := Vector2.ZERO          ## pekarens punkt (vyns px) när noden greppades
var _drag_nod := Vector2.ZERO          ## nodens plats (procent) vid samma grepp
## ÅNGRA (en nivå): positionen FÖRE den senaste flytten. Sätts när rörelsen BÖRJAR (greppet eller ett
## piltryck), inte per musrörelse — annars skrev varje bildruta över målet och Z återställde ett steg
## i stället för hela dragningen. `i` = -1 betyder "inget att ångra".
var _före := {"i": -1, "x": 0.0, "y": 0.0}
## Granskningsflagga: kameran står still. En provbild ska visa FÖRE och EFTER i SAMMA ruta, och en
## kamera som glider mot den flyttade noden hade gett två bilder av olika utsnitt.
var kamera_fryst := false
var textlager: UiText                  ## orden, ritade i FÖNSTRETS upplösning (se ui_text.gd)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	textlager = UiText.fäst(self)
	# Gångaren skapas på begäran (M122) — se `gångaren()`: ett prov gör en `WorldMapView.new()` utan
	# träd, och då körs aldrig `_ready`.

## Gångaren. Provet mäter samma sak här som i byn: vägen, tiden och att platsen öppnas först framme.
func gångaren() -> Gångare:
	if _gångare == null:
		_gångare = Gångare.new()
	return _gångare

## VAR FIGUREN GÅR: nodens plats i KARTANS px (`_fort`, alltså före kameran). Kameran glider mot den
## valda noden, och en punkt i skärmens px hade då glidit ifrån sin nod.
func gångpunkt(i: int) -> Vector2:
	if i < 0 or i >= _noder.size():
		return Vector2.ZERO
	return _fort(_bild_px(i))

## GÅ TILL PLATSEN OCH ÖPPNA DEN. Ingen promenad och ingen väntan (M138): markören står på platsen
## direkt och panelen öppnas i samma anrop — skalet har inget "går"-läge att vänta på längre.
func gå_till_och_in(i: int = -1) -> Dictionary:
	if i < 0:
		i = _vald
	if i >= _noder.size():
		return försök_gå_in(i)
	if i != _vald:
		gå_till(i)
		_ställ_gångaren(i)
		queue_redraw()
	return försök_gå_in(i)

## Markören står på den valda platsen (M138: inget gående — den snappar).
func _låt_gångaren_gå(i: int) -> void:
	_ställ_gångaren(i)

## Ställ figuren vid en plats utan att gå (när vyn visas).
func _ställ_gångaren(i: int) -> void:
	gångaren().starta(gångpunkt(i), gångpunkt(i))

func _exit_tree() -> void:
	# Lagret ligger i FÖNSTRET (annars vore orden uppskalade igen): det måste bort med vyn.
	if textlager != null:
		textlager.frigör()

func antal() -> int:
	return _noder.size()

func valt_index() -> int:
	return _vald

func besked() -> String:
	return _besked

func sparad() -> String:
	return _sparad

func panel_öppen() -> bool:
	return _panel

func nivå_vald() -> int:
	return _nivå

# --- bygget -------------------------------------------------------------------
## Bygg om kartan ur `data/karta.json` och metat. Anropas varje gång skärmen visas: upplåsningen
## ändras av körningen, och en karta som visar förra körningens läge lurar spelaren till en låst dörr.
##
## `order` och `stages` behålls i signaturen: main.gd äger banordningen, och en nod vars banor saknas
## i bandata ska ritas som en låst plats — inte som en tom dörr.
func visa(stages: Dictionary, order: Array, meta: Meta) -> void:
	_ordning = order
	_stages = stages
	_meta = meta
	_noder.clear()
	_länkar = [] if karta == null else karta.länkar(_ordning)
	if karta == null:
		queue_redraw()
		return
	for i in karta.antal():
		var nivåer: Array = karta.nivåer(i)
		var sekt: int = karta.sektion(i)
		var klar := 0
		var delvis := 0.0
		var finns := false
		var boss := ""
		var svårighet := 1
		var våningar := 1
		var bäst := 0
		for id in nivåer:
			var s: Stages.StageDef = stages.get(str(id))
			if s == null:
				continue
			finns = true
			svårighet = maxi(svårighet, int(s.difficulty))
			våningar = maxi(våningar, int(s.floors))
			var nådd := int(meta.best_floor.get(str(id), 0))
			if nådd >= int(s.floors):
				klar += 1
			delvis += clampf(float(nådd) / maxf(1.0, float(s.floors)), 0.0, 1.0)
			if bäst < nådd:
				bäst = nådd
			if boss.is_empty() and not str(s.boss).is_empty():
				boss = str(s.boss)
		_noder.append({
			"plats": str(karta.noder[i]["plats"]),
			"nivåer": nivåer,
			"sektion": sekt,
			"sektion_klar": karta.sektion_klar(sekt, meta),
			# Grinden är SEKTIONEN, inte banordningen (Alex: "man inte kan gå till en del av kartan om
			# man inte klarat minst en bana av delen innan"). Innanför en öppen sektion är varje bana
			# spelbar, och en plats i en låst sektion är låst hur upplåsta banorna än är i sig.
			"öppen": finns and karta.sektion_öppen(sekt, meta),
			"klar": finns and klar == nivåer.size(),
			"delvis": delvis / maxf(1.0, float(nivåer.size())),
			"finns": finns,
			"klar_nivåer": klar,
			"bäst": bäst,
			"svårighet": svårighet,
			"våningar": våningar,
			"boss": "" if boss.is_empty() else Tr.name_of("enemy", boss, boss),
		})
	_vald = clampi(_vald, 0, maxi(0, _noder.size() - 1))
	_nivå = clampi(_nivå, 0, maxi(0, nivåer(_vald).size() - 1))
	_kamera_startad = false                # kameran hoppar till första platsen, glider sedan
	_ställ_gångaren(_vald)
	queue_redraw()

## Nodens plats i BILDENS px (ur filen). Transformen gör den till en skärmpunkt.
func _bild_px(i: int) -> Vector2:
	return karta.bild_px(i) if karta != null else Vector2.ZERO

## Nodens mitt i VYNS px, genom transformen. Provet mäter den: markeringen ska sitta på noden även
## när kameran glider.
func plats(i: int) -> Vector2:
	if i < 0 or i >= _noder.size():
		return Vector2.ZERO
	return _vy_px(_bild_px(i))

func gå_till(i: int) -> void:
	_vald = clampi(i, 0, maxi(0, _noder.size() - 1))
	_besked = ""
	_sparad = ""
	_panel = false
	_nivå = 0
	_låt_gångaren_gå(_vald)
	queue_redraw()

## Markeringen flyttas till den NÄRMASTE noden i den riktningen (inom ±60 grader). Kartan är fri —
## det finns ingen rad att följa — så "höger" betyder höger, inte "nästa i listan". I editorn flyttar
## pilarna NODEN i stället (ett steg = en halv px på bilden): en editor utan finjustering går inte
## att få exakt. `false` = ingen nod dit, markeringen står kvar.
func flytta(dir: Vector2i) -> bool:
	if _noder.is_empty() or dir == Vector2i.ZERO:
		return false
	if editor:
		return nudga(dir)
	var här := _bild_px(_vald)
	var bäst := -1
	var bäst_d := 0.0
	for j in _noder.size():
		if j == _vald:
			continue
		var d := _bild_px(j) - här
		var längd := d.length()
		if längd < 0.001:
			continue
		var cosv := (d.x * float(dir.x) + d.y * float(dir.y)) / längd
		if cosv < 0.5:
			continue                       # utanför ±60 grader: inte "den riktningen"
		if bäst < 0 or längd < bäst_d:
			bäst = j
			bäst_d = längd
	if bäst < 0:
		return false
	_vald = bäst
	_besked = ""
	_panel = false
	_nivå = 0
	# Figuren går till den nya platsen (M122). Panelen öppnas inte av en flytt — det gör Enter
	# (`gå_till_och_in`) när figuren är framme.
	_låt_gångaren_gå(_vald)
	queue_redraw()
	return true

## Läget på en plats. Fyra lägen och de syns i bild: låst (mörk sten med hänglås), öppen (medaljong i
## svårighetsfärgen), påbörjad (med en guldstapel för hur långt man kom) och klar (med grön bock).
## En plats vars banor inte finns i bandata ritas som låst — den har inget öppet läge.
func läge(i: int) -> String:
	if i < 0 or i >= _noder.size():
		return "tom"
	var n: Dictionary = _noder[i]
	if not bool(n["finns"]):
		return "saknas"
	if bool(n["klar"]):
		return "klar"
	if bool(n["öppen"]):
		return "påbörjad" if float(n["delvis"]) > 0.0 else "öppen"
	return "låst"

func status_text(i: int) -> String:
	match läge(i):
		"saknas":
			return Tr.t("ui.map.missing", "saknas i bandata")
		"låst":
			return Tr.t("ui.map.locked_short", "låst")
		"klar":
			return Tr.t("ui.map.done", "klar")
		"påbörjad":
			return Tr.t("ui.map.floors", "%d/%d våningar") % [int(_noder[i]["bäst"]), int(_noder[i]["våningar"])]
		_:
			return Tr.t("ui.map.fresh", "inte spelad")

## Svårighetsfärgen: grön → ben → röd. Samma axel som banordningen, så kartan visar färden från det
## lätta till det svåra utan en enda siffra.
func _svårighetsfärg(svårighet: int) -> Color:
	if svårighet <= 3:
		return Palett.c(15)
	if svårighet <= 6:
		return Palett.c(22)
	return Palett.c(11)

## Hur en plats ser ut, som siffror i stället för som ritningar. `_draw` ritar ur den här och provet
## mäter den — "låst, upplåst och avklarad går att skilja på" är då samma sak i provet som i bilden.
func stil(i: int) -> Dictionary:
	var tom := {"fyllnad": Palett.c(2), "kant": Palett.c(4), "lås": true, "klar": false, "delvis": 0.0}
	if i < 0 or i >= _noder.size():
		return tom
	var n: Dictionary = _noder[i]
	var f := _svårighetsfärg(int(n["svårighet"]))
	match läge(i):
		"låst", "saknas":
			return tom
		"klar":
			return {"fyllnad": f, "kant": Palett.c(15), "lås": false, "klar": true, "delvis": 1.0}
		"påbörjad":
			return {"fyllnad": f, "kant": Palett.c(21), "lås": false, "klar": false,
				"delvis": float(n["delvis"])}
		_:
			return {"fyllnad": f, "kant": Palett.c(8), "lås": false, "klar": false, "delvis": 0.0}

## Får man gå in? En låst plats nekas med en rad i klartext — att inte göra någonting alls ser ut som
## en trasig tangent. `krav` är den bana man måste klara först.
func stanna() -> Dictionary:
	if _noder.is_empty():
		return {"ok": false, "reason": "tom", "stage_id": "", "text": "", "krav": "", "index": _vald}
	var n: Dictionary = _noder[_vald]
	if not bool(n["finns"]):
		return {"ok": false, "reason": "saknas", "stage_id": "",
			"text": Tr.t("ui.map.missing_id", "%s saknas i bandata") % str(n["plats"]), "krav": "",
			"index": _vald}
	if bool(n["öppen"]):
		return {"ok": true, "reason": "", "stage_id": _första_ospelade_id(_vald), "text": "", "krav": "",
			"index": _vald}
	# Sektionen är den YTTRE grinden. Ligger platsen i en låst sektion sägs det — kravet är en bana i
	# sektionen före, inte banan strax före i svårighetsordningen (den ligger ofta i en annan del av
	# kartan, och "klara Lavafallen först" vore ett felaktigt svar på fel fråga).
	if karta != null and not karta.sektion_öppen(int(n["sektion"]), _meta):
		return {"ok": false, "reason": "låst", "stage_id": "", "krav": "", "index": _vald,
			"text": Tr.t("ui.map.section_locked", "LÅST — klara en bana i sektion %d först")
				% int(n["sektion"])}
	var krav := _krav_namn(_vald)
	var text := Tr.t("ui.map.locked", "LÅST — klara %s först") % krav if not krav.is_empty() \
		else Tr.t("ui.map.locked_first", "LÅST — den här platsen är inte öppen än")
	return {"ok": false, "reason": "låst", "stage_id": "", "text": text, "krav": krav, "index": _vald}

## Gå in i en plats. Ett index som inte finns nekas (den som pekar på en plats som inte finns ska inte
## hamna på en annan), en låst plats får ett besked, och en öppen plats öppnar NIVÅPANELEN: Alex vill
## välja nivå där, så Enter betyder "öppna nivåerna" och sedan "kör den här nivån".
func försök_gå_in(i: int = -1) -> Dictionary:
	if i < 0:
		i = _vald
	if i >= _noder.size():
		return {"ok": false, "reason": "finns_inte", "stage_id": "", "text": "", "krav": "", "index": _vald}
	var flyttad := i != _vald
	_vald = i
	var r := stanna()
	if not bool(r["ok"]):
		_besked = str(r["text"])
		_panel = false
		queue_redraw()
		return r
	if not _panel or flyttad:
		_panel = true
		_nivå = _första_ospelade(_vald)
		_besked = ""
		queue_redraw()
		return {"ok": false, "reason": "välj", "stage_id": "", "text": "", "krav": "", "index": _vald}
	var id := _nivå_id(_vald, _nivå)
	if id.is_empty():
		_besked = Tr.t("ui.map.level_locked", "den nivån är inte upplåst än")
		queue_redraw()
		return {"ok": false, "reason": "låst_nivå", "stage_id": "", "text": _besked, "krav": "",
			"index": _vald}
	_besked = ""
	vald.emit(id)
	return {"ok": true, "reason": "", "stage_id": id, "text": "", "krav": "", "index": _vald}

# --- nivåerna (Alex: upp till tio per nod) -------------------------------------
func nivåer(i: int) -> Array:
	return _noder[i]["nivåer"] if i >= 0 and i < _noder.size() else []

func flytta_nivå(steg: int) -> bool:
	if not _panel:
		return false
	var l: Array = nivåer(_vald)
	if l.is_empty():
		return false
	_nivå = clampi(_nivå + steg, 0, l.size() - 1)
	queue_redraw()
	return true

func stäng_panel() -> void:
	_panel = false
	queue_redraw()

## SVÅRIGHETSTRAPPAN (önskemål 24, punkt 4): vänster/höger i nivåpanelen väljer steg för den nivå panelen
## står på. Bara upplåsta steg går att välja — metan äger räknarna och klämmer valet, så vyn kan inte
## råka visa ett steg som inte finns. Sparfilen skrivs direkt: ett val man gjort ska inte tappas för att
## man stänger spelet i stället för att spela en körning.
func steg_ändra(n: int) -> int:
	if _meta == null or not _panel:
		return 0
	var l: Array = nivåer(_vald)
	if _nivå < 0 or _nivå >= l.size():
		return 0
	var id := str(l[_nivå])
	var ny := _meta.steg_sätt(id, _meta.steg_valt_för(id) + n)
	_meta.save()
	queue_redraw()
	return ny

## VADSLAGNINGEN (önskemål 24, punkt 7): V vrider 0 -> 25 % -> 50 % av banken för den nivå panelen står
## på, och sparar valet direkt (samma regel som steget). Insatsen i guld räknas ur BANKEN, så raden och
## körningen säger samma summa.
func vad_vrid() -> float:
	if _meta == null or not _panel:
		return 0.0
	var l: Array = nivåer(_vald)
	if _nivå < 0 or _nivå >= l.size():
		return 0.0
	var id := str(l[_nivå])
	var ny := _meta.vad_vrid(id)
	_meta.save()
	queue_redraw()
	return ny

## Raden för vadet, eller "" när inget är satsat (då ska kortet inte nämna det).
func vad_text() -> String:
	if _meta == null:
		return ""
	var l: Array = nivåer(_vald)
	var k: int = _nivå if _panel else 0
	if k < 0 or k >= l.size():
		return ""
	var id := str(l[k])
	var insats := _meta.vad_insats(id)
	if insats <= 0:
		return ""
	return Tr.t("ui.map.wager", "vad: %d guld (2x om du klarar banan)") % insats

## Steg-raden för den nivå panelen står på (eller nodens första nivå när panelen är stängd). Tom när
## metan saknas eller nivån inte finns — då ska kortet inte påstå något om svårigheten.
func steg_text() -> String:
	if _meta == null:
		return ""
	var l: Array = nivåer(_vald)
	var k: int = _nivå if _panel else 0
	if k < 0 or k >= l.size():
		return ""
	var id := str(l[k])
	var valt := _meta.steg_valt_för(id)
	var tak := _meta.steg_max_för(id)
	return Tr.t("ui.map.step", "trappsteg %d/%d · fiender +%d %% · guld +%d %%") % [valt, tak,
		int(round(Meta.STEG_FIENDE * float(valt) * 100.0)),
		int(round(Meta.STEG_GULD * float(valt) * 100.0))]

## Måttet för en nivårad: samma siffror som `_panel_ruta` ritar ur, så provet kan mäta att raderna
## ryms i panelen.
func nivå_rad(i: int, k: int) -> Rect2:
	var pr := panel_ruta()
	return Rect2(pr.position.x + 3.0, pr.position.y + 13.0 + float(k) * RAD_HÖJD,
		pr.size.x - 6.0, RAD_HÖJD)

## Nivåns bana, eller "" om den inte finns i bandata. Upplåsningen sköts av SEKTIONEN (en plats i en
## öppen sektion har alla sina banor spelbara), och panelen ritas bara för en öppen plats.
func _nivå_id(i: int, k: int) -> String:
	var l: Array = nivåer(i)
	if k < 0 or k >= l.size():
		return ""
	var id := str(l[k])
	return id if _stages.has(id) else ""

## Den nivå man är framme vid: den första som inte är klar. Är allt klart blir det nivå 1 — att farma
## en klar plats ska vara ETT Enter, inte en runda genom panelen.
func _första_ospelade(i: int) -> int:
	var l: Array = nivåer(i)
	for k in l.size():
		var s: Stages.StageDef = _stages.get(str(l[k]))
		if s == null or _meta == null:
			continue
		if int(_meta.best_floor.get(str(l[k]), 0)) < int(s.floors):
			return k
	return 0

func _första_ospelade_id(i: int) -> String:
	var l: Array = nivåer(i)
	if l.is_empty():
		return ""
	return str(l[_första_ospelade(i)])

## Namnet på banan man måste klara först: den som ligger steget före nodens första nivå i
## banordningen. Upplåsningen följer svårighet, inte kartans geometri, så grannen på kartan är fel svar.
func _krav_namn(i: int) -> String:
	var l: Array = nivåer(i)
	if l.is_empty():
		return ""
	var första := str(l[0])
	for k in _ordning.size():
		if str(_ordning[k]) != första or k == 0:
			continue
		var före := str(_ordning[k - 1])
		var s: Stages.StageDef = _stages.get(före)
		return Tr.name_of("stage", före, s.name if s != null else före)
	return ""

# --- transformen: bild, vinkel, kamera ----------------------------------------
func _vy() -> Vector2:
	return Vector2(size.x if size.x > 0.0 else 480.0, size.y if size.y > 0.0 else 270.0)

## Kartytan: vyn utan kortens rad nedtill. Kameran centrerar i DEN rutan, så en vald nod aldrig
## hamnar bakom sitt eget kort.
func _kartruta() -> Rect2:
	var vp := _vy()
	return Rect2(0.0, 0.0, vp.x, vp.y)

## Informationsremsan (M118): platsen, svårigheten, framstegen och tecknen, som ett TUNT överlägg
## längst ned PÅ kartan. Remsans underkant ligger på vyns underkant, så ingen tom yta blir kvar under
## den (den gamla rutan slutade 14 px ovanför och lämnade bandet Alex såg).
func kort_ruta() -> Rect2:
	var vp := _vy()
	return Rect2(KORT_MARG, vp.y - KORT_H, vp.x - 2.0 * KORT_MARG, KORT_H)

## Nivåpanelen: samma ruta som förut (174x108, tio rader), men förankrad i remsan i stället för i en
## hårdkodad 480x270-ruta — den ligger över kartan och flyttar den inte.
func panel_ruta() -> Rect2:
	var k := kort_ruta()
	return Rect2(k.end.x - PANEL_BREDD, k.position.y - PANEL_HÖJD - 4.0, PANEL_BREDD, PANEL_HÖJD)

## Kartytans nederkant: remsans överkant, med luft emellan. Allt som ska ligga i kartytan mäts mot
## den (nodernas synlighet, namnplaketterna).
func bar() -> float:
	return kort_ruta().position.y - 4.0

## Ledtrådsraden: remsans SISTA rad, inte en egen rad under en ruta.
func hint_y() -> float:
	return kort_ruta().end.y - HINT_MARG

## Fokusets höjd: mitten av den FRIA kartytan ovanför remsan. Den valda platsen centreras där, så en
## nod aldrig hamnar bakom sin egen information.
func _fokus_y() -> float:
	return (_vy().y - KORT_H) * 0.5

## Kamerans mål: den valda noden i kartytans mitt, klämd så kartan TÄCKER vyn helt (ingen tom yta
## ovanför eller under bilden). Klämmen är räknad ur fokuset och vyns höjd, inte ur en marginal: med
## 0,35 x rutan kunde kartans kant stanna 50 px innanför vyns kant — och då syns en svart rand, som
## Alex beskrev den ("kartans bild tar bara ~50 % av fönstret").
func _kamera_mål() -> Vector2:
	var ruta := _kartruta()
	var b := _bbox()
	var mål := _fort(_bild_px(_vald))
	if b.size.x > ruta.size.x:
		mål.x = clampf(mål.x, b.position.x + ruta.size.x * 0.5, b.end.x - ruta.size.x * 0.5)
	else:
		mål.x = b.get_center().x
	if b.size.y > ruta.size.y:
		var fy := _fokus_y()
		mål.y = clampf(mål.y, b.position.y + fy, b.end.y + fy - ruta.size.y)
	else:
		mål.y = b.get_center().y
	return mål

func _zoom() -> float:
	return karta.zoom if karta != null else 1.0

## px på skärmen per px i bilden. 1,0 = HELA bilden ryms i den fria kartytan (M260).
##
## Alex: *"visa hela direkt, och inte bara en del av den"*. Förut var skalan BAS * zoom, där BAS bara
## visste om vyns bredd — kortets höjd (40 px längst ned) åt upp utrymme som skalan inte tog hänsyn till,
## så bilden skars av i över- eller underkant beroende på fönstret. Nu räknas skalan ur den FAKTISKA
## fria ytan: den minsta av bredd- och höjdkvoten, alltså "contain" i stället för "cover".
func _s() -> float:
	if _noder.is_empty():
		return BAS * _zoom()
	var fri := _vy()
	var kort := kort_ruta()
	if kort.size.y > 0.0:
		fri.y = maxf(1.0, kort.position.y)
	return minf(fri.x / Karta.BILD_BREDD, fri.y / Karta.BILD_HÖJD) * _zoom()

func _komprimering() -> float:
	return karta.komprimering if karta != null else 1.0

func _lutning() -> float:
	return karta.lutning if karta != null else 0.0

## BILDENS px -> kartans px (vinklad): y kläms ihop och de nedre raderna skjuts i sidled. Kartans
## mitt är origo, så kameran kan tala om vilken punkt som ska ligga i kartytans mitt.
func _fort(p: Vector2) -> Vector2:
	var s := _s()
	return Vector2(
		(p.x - Karta.BILD_BREDD * 0.5 + (p.y - Karta.BILD_HÖJD * 0.5) * _lutning()) * s,
		(p.y - Karta.BILD_HÖJD * 0.5) * _komprimering() * s)

## Kartans px -> vyns px, genom kameran. ORIGO är FOKUSET (M118), inte vyns mitt: den valda platsen
## ska stå i mitten av den FRIA kartytan ovanför remsan, och klämmen i `_kamera_mål` räknar ur samma
## punkt. Använde klämmen ett annat origo än ritningen hamnade den nedersta platsen (Nedre porten,
## 88 % av bildens höjd) UNDER remsan — mätt i `test_karta_full`.
func _vy_px(p_bild: Vector2) -> Vector2:
	return _fort(p_bild) - _kamera + fokus()

## Vyns px -> bildens px (editorn: muspekaren ska bli ett tal i filen). Exakt invers av `_fort`.
func _omvänt(vy: Vector2) -> Vector2:
	var s := maxf(0.0001, _s())
	var kart := vy + _kamera - fokus()
	var y := kart.y / (_komprimering() * s) + Karta.BILD_HÖJD * 0.5
	var x := kart.x / s - (y - Karta.BILD_HÖJD * 0.5) * _lutning() + Karta.BILD_BREDD * 0.5
	return Vector2(x, y)

## Kartans ruta i kartans px (de fyra vinklade hörnen). Kameran kläms innanför den, så fokus aldrig
## lämnar kartan och visar tom svart yta.
func _bbox() -> Rect2:
	var r := Rect2(_fort(Vector2.ZERO), Vector2.ZERO)
	for p in [Vector2(Karta.BILD_BREDD, 0.0), Vector2(0.0, Karta.BILD_HÖJD),
			Vector2(Karta.BILD_BREDD, Karta.BILD_HÖJD)]:
		r = r.expand(_fort(p))
	return r

## Fokuset (M118): punkten den valda platsen centreras mot — vyns mitt i sidled och mitten av den FRIA
## kartytan ovanför remsan i höjdled. Egen funktion så provet kan mäta kameraglidningen mot samma
## punkt som kameran faktiskt siktar på.
func fokus() -> Vector2:
	return Vector2(_vy().x * 0.5, _fokus_y())

## Ett steg av kameraglidningen. Egen funktion för att provet ska kunna köra den utan en skärm —
## `_process` gör ingenting i en vy som inte sitter i trädet (se den gömd-vy-fällan i M37b).
func steg_kamera(delta: float, direkt := false) -> void:
	var mål := _kamera_mål()
	if direkt or not _kamera_startad:
		_kamera = mål
		_kamera_startad = true
		queue_redraw()
		return
	if _kamera.distance_to(mål) > 0.15:
		_kamera = _kamera.lerp(mål, clampf(KAMERA_FART * delta, 0.0, 1.0))
		queue_redraw()

# --- editorn (Alex: "så kan jag placera ut noderna") --------------------------
## Flytta den valda noden ett steg. Steget är 0,1 % av bilden (drygt en px) — SAMMA precision som
## filen sparas med: ett mindre steg avrundades bort i `flytta_nod` och tangenten gjorde ingenting
## (mätt: 26,0 -> 26,0 efter ett tryck).
func nudga(dir: Vector2i) -> bool:
	if karta == null or _noder.is_empty():
		return false
	_minns(_vald)
	flytta_nod(_vald, Vector2(float(dir.x), float(dir.y)) * 0.1)
	return true

## Flytta nod i med ett steg i PROCENT av bilden. Kläms till 0..100: en nod utanför kartan är ett fel
## i filen, och editorn ska inte kunna skapa ett.
func flytta_nod(i: int, dprocent: Vector2) -> void:
	if karta == null or i < 0 or i >= karta.antal():
		return
	sätt_nod(i, karta.plats(i) + dprocent)

## Sätter en nods x/y (i procent av bilden). Dragningen OCH finjusteringen går genom den, så klämmen
## till kartan och avrundningen till filens 0,1 % bara finns på ett ställe.
func sätt_nod(i: int, p: Vector2) -> void:
	if karta == null or i < 0 or i >= karta.antal():
		return
	karta.noder[i]["x"] = roundf(clampf(p.x, 0.0, 100.0) * 10.0) / 10.0
	karta.noder[i]["y"] = roundf(clampf(p.y, 0.0, 100.0) * 10.0) / 10.0
	_sparad = ""
	queue_redraw()

## ÅNGRA (en nivå): kom ihåg var noden stod innan rörelsen började. Anropas av greppet och av
## finjusteringen — ALDRIG av varje musrörelse, för då vore målet det föregående steget i dragningen.
func _minns(i: int) -> void:
	if karta == null or i < 0 or i >= karta.antal():
		return
	_före = {"i": i, "x": float(karta.noder[i]["x"]), "y": float(karta.noder[i]["y"])}

## Har en rörelse skett som går att ångra? Provet och statusraden frågar.
func kan_ångra() -> bool:
	return int(_före["i"]) >= 0

## Lägger tillbaka noden på den plats den hade innan den senaste dragningen eller finjusteringen.
## `false` när inget finns att ångra — en knapp vars verkan man måste gissa går inte att skilja från en
## trasig. Noden blir den VALDA, så man ser vilken som flyttades tillbaka, och kvittot nollas (filen på
## disk är nu inte längre vad vyn visar).
func ångra() -> bool:
	var i: int = int(_före["i"])
	if karta == null or i < 0 or i >= karta.antal():
		return false
	karta.noder[i]["x"] = float(_före["x"])
	karta.noder[i]["y"] = float(_före["y"])
	_före = {"i": -1, "x": 0.0, "y": 0.0}
	_vald = i
	_sparad = ""
	queue_redraw()
	return true

## Editorn: flytta den valda noden till en annan sektion (tangent 1..9 på kartan i editorn). Noden
## byter då grind, så läget räknas om — en nod i en öppen sektion är spelbar, inte låst.
func sätt_sektion(n: int) -> bool:
	if karta == null or _noder.is_empty():
		return false
	var nr := clampi(n, 1, 9)
	if karta.sektion(_vald) == nr:
		return false
	karta.noder[_vald]["sektion"] = nr
	visa(_stages, _ordning, _meta)
	queue_redraw()
	return true

## EN NY PLATS ÅT EN BANA (M60). Alex: *"så du får gärna utöka arean jag kan göra banor i"* — den
## valda nivån flyttas till en NY nod ett litet steg ifrån sin gamla, och sedan finjusterar pilarna
## var den står. Att placera den intill är med flit: den som gör en bana vill se var den hamnade.
##
## Namnet blir banans eget (Karta sätter det), sektionen den valda nodens, och den gamla noden
## försvinner om den blev tom — en nod utan nivåer är ett fel i filen, inte ett tillstånd.
func ny_plats_för_vald() -> bool:
	if karta == null or _noder.is_empty() or not _panel:
		return false
	var id := _nivå_id(_vald, _nivå)
	if id.is_empty():
		return false
	var gamla := karta.plats(_vald)
	var nytt: int = karta.nivå_till_ny_nod(_vald, _nivå, gamla.x + 6.0, gamla.y + 4.0,
		karta.sektion(_vald))
	if nytt < 0:
		return false
	_vald = nytt
	_panel = false
	_sparad = ""
	visa(_stages, _ordning, _meta)
	queue_redraw()
	return true


## Skriv kartan till den fil den lästes ur — den fil man committar. Kvittot syns i vyn.
func skriv_karta() -> bool:
	_sparad = ""
	if karta == null:
		return false
	if karta.skriv():
		_sparad = Tr.t("ui.map.saved", "kartan sparad")
		queue_redraw()
		return true
	_sparad = Tr.t("ui.map.save_failed", "kunde inte skriva kartan")
	queue_redraw()
	return false

## En rad för editorn: platsens namn och dess tal. Egen funktion, så provet kan mäta att raden säger
## samma tal som filen.
func nod_text(i: int) -> String:
	if karta == null or i < 0 or i >= karta.antal():
		return ""
	var p := karta.plats(i)
	return "%s  S%d  %.1f / %.1f" % [str(karta.noder[i]["plats"]), karta.sektion(i), p.x, p.y]

func _process(delta: float) -> void:
	# GÖMD VY GÖR INGET: vyn ligger kvar i trädet under en körning (se M37b — 241 ms per bildruta,
	# 4 fps, när en gömd vy byggde sina textrader varje bildruta).
	if not is_visible_in_tree():
		return
	# KAMERAN STÅR STILL UNDER EN DRAGNING. Glider den medan man drar flyttar den kartan UNDER
	# pekaren, och noden lämnar muspekaren i stället för att följa den (kameran siktar på den valda
	# noden, som är just den man håller i). `kamera_fryst` är samma lås som granskningsflagga.
	if _drag < 0 and not kamera_fryst:
		steg_kamera(delta)
	# Figuren går ett steg per bildruta medan den går. Kommer den fram sänder den `framme`, och då
	# öppnas platsen (se `_framme`) — därför ritas vyn om varje bildruta och inte bara vid pulsen.
	if gångaren().går():
		gångaren().steg(delta)
		queue_redraw()
	_t += delta
	var ram := int(_t * 6.0) % PULS.size()
	if ram != _ram:
		_ram = ram
		queue_redraw()
	_ord()

func _gui_input(event: InputEvent) -> void:
	if karta == null:
		return
	if event is InputEventMouseMotion and _drag >= 0:
		# NODEN FÖLJER PEKAREN: platsen vid greppet PLUS musens rörelse sedan greppet, räknad genom
		# samma transform som ritar den (`_omvänt`). Skillnaden — inte pekarens punkt — annars hoppar
		# en nod man greppat en bit ifrån sitt märke till mitten under pekaren.
		var mm := event as InputEventMouseMotion
		var d := _omvänt(mm.position) - _omvänt(_drag_mus)
		sätt_nod(_drag, _drag_nod + Vector2(d.x / Karta.BILD_BREDD * 100.0, d.y / Karta.BILD_HÖJD * 100.0))
		return
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if m.button_index != MOUSE_BUTTON_LEFT:
		return
	if not m.pressed:
		_drag = -1
		return
	# Närmaste nod inom klickradien. I editorn är det samma träffyta — man tar tag i noden man ser.
	var bäst := -1
	var bäst_d := KLICKRADIE
	for i in _noder.size():
		var d := plats(i).distance_to(m.position)
		if d < bäst_d:
			bäst = i
			bäst_d = d
	if bäst < 0:
		return
	if editor:
		_vald = bäst
		_drag = bäst
		_drag_mus = m.position
		_drag_nod = karta.plats(bäst)
		_minns(bäst)                           # ångra: positionen FÖRE hela dragningen
		steg_kamera(0.0, true)                 # kameran hakar fast i noden man tar tag i
		queue_redraw()
		return
	försök_gå_in(bäst)

# --- ritningen ----------------------------------------------------------------
func _draw() -> void:
	var vp := _vy()
	draw_rect(Rect2(Vector2.ZERO, vp), Palett.c(1))
	_kartbild(vp)
	# Vägarna mellan platserna UNDER noderna: medaljongerna ska ligga PÅ vägen, som märkena gör på
	# minikartan. En väg över en medaljong skar genom den.
	_vägar()
	if editor:
		_editor_rutor()
	for i in _noder.size():
		if _syns(i):
			_nod(i)
	# Markeringen ritas EFTER noderna: den valda ska ligga överst, med sin glöd under sig.
	if not _noder.is_empty():
		_glöd(_vald)
		_nod(_vald)
		_markerad(_vald)
	_figur_rita()
	_kort(vp)
	if _panel:
		_panel_ruta()          # panelen ligger ÖVER kortet: den ritas efter (annars täcks den)
	_bård(vp)

func _ord() -> void:
	if textlager != null:
		textlager.sätt(etiketter(_vy()))

## Gångaren ritas på kartan, OVANFÖR noderna och deras markering: hon står på platsen. Figuren ligger
## i kartans px (se `gångpunkt`), så kameran dras in här — annars gled figuren ifrån sin nod.
func _figur_rita() -> void:
	if karta == null:
		return
	var väg := Meta.hjalte_bild()
	if _figur_väg != väg:
		_figur_väg = väg
		_figur = null
		if ResourceLoader.exists(väg):
			_figur = load(väg)
	if _figur == null:
		return
	var p := gångaren().pos() - _kamera + fokus()
	var m: Vector2 = _figur.get_size() * VillageView.FIGUR_SKALA
	var x := p.x + gångaren().vick_sida()
	var y := p.y - gångaren().vick_gupp()
	draw_colored_polygon(_ellips(Vector2(x, y + m.y * 0.05), m.x * 0.36, 2.0), _a(Palett.c(0), 0.32))
	draw_texture_rect(_figur, Rect2(Vector2(x - m.x * 0.5, y - m.y), m), false)

## Kartan i horisontella remsor: varje remsa är en rak ruta på skärmen (vinkeln sitter i
## transformen), så ingen shader behövs. Bara de remsor som syns i vyn ritas.
func _kartbild(vp: Vector2) -> void:
	var bild := _bild()
	if bild == null:
		return
	var h := Karta.BILD_HÖJD / float(REMSOR)
	for r in REMSOR:
		var y0 := float(r) * h
		var a := _vy_px(Vector2(0.0, y0))
		var b := _vy_px(Vector2(Karta.BILD_BREDD, y0))
		var höjd := maxf(0.6, absf(_vy_px(Vector2(0.0, y0 + h)).y - a.y))
		if a.y + höjd < 0.0 or a.y > vp.y:
			continue
		var x0 := minf(a.x, b.x)
		var bredd := absf(b.x - a.x)
		if x0 + bredd < 0.0 or x0 > vp.x:
			continue
		draw_texture_rect_region(bild, Rect2(x0, a.y, bredd, höjd),
			Rect2(0.0, y0, Karta.BILD_BREDD, h))

## Kartans bild, läst en gång.
func _bild() -> Texture2D:
	if _tex == null and karta != null and ResourceLoader.exists(karta.bild):
		_tex = load(karta.bild)
	return _tex

## Den RITADE kartytan i vyn (M118): unionen av remsorna `_kartbild` ritar — alltså exakt det som
## hamnar i bild, inte en omslutande ram. Provet mäter den mot vyns fyra kanter: "kant i kant" är
## kravet, och en remsa är en rak ruta så unionen är rätt mått (lutningen ligger i `_fort`).
func kartyta() -> Rect2:
	var h := Karta.BILD_HÖJD / float(REMSOR)
	var hel := Rect2()
	for r in REMSOR:
		var y0 := float(r) * h
		var a := _vy_px(Vector2(0.0, y0))
		var b := _vy_px(Vector2(Karta.BILD_BREDD, y0))
		var höjd := maxf(0.6, absf(_vy_px(Vector2(0.0, y0 + h)).y - a.y))
		var ruta := Rect2(minf(a.x, b.x), a.y, absf(b.x - a.x), höjd)
		hel = ruta if r == 0 else hel.merge(ruta)
	return hel

## En karta som saknar bild är ett fel i data (laddaren säger det): rita ingen bakgrund alls i stället
## för att gissa, och låt noderna synas mot den mörka ytan.
func _syns(i: int) -> bool:
	var p := plats(i)
	var vp := _vy()
	return p.x > -30.0 and p.x < vp.x + 30.0 and p.y > -30.0 and p.y < vp.y + 30.0

## Den valda nodens glöd: skivor som växer och krymper med pulsen — en nod som LYser, inte en ram.
func _glöd(i: int) -> void:
	var p := plats(i)
	var puls := float(PULS[_ram])
	for k in 3:
		draw_circle(p, NOD + 4.0 + float(k) * 2.5 + puls, _a(Palett.c(26), 0.06))
	draw_circle(p, NOD + 5.0 + puls, _a(Palett.c(26), 0.30))

## VÄGEN MELLAN PLATSERNA (M120). Ett streck per koppling ur `Karta.länkar` — aldrig ett par som inte
## står där, och aldrig ett par som står där utan streck. Ritade i ALLA led (ingen bortklippning efter
## `_syns`): kartan är större än vyn, och en väg vars mitt korsar rutan ska synas även när båda
## ändarna ligger utanför den. Antalet ritade streck är därför exakt antalet kopplingar, vilket är det
## provet räknar.
##
## Ändpunkterna kommer ur `plats()` — samma transform som markeringen och medaljongerna — så vägen
## hänger i bilden även när kameran glider.
func _vägar() -> void:
	_ritade_vägar.clear()
	if vägar_av or _länkar.is_empty() or _noder.is_empty():
		return
	for l in _länkar:
		var par: Vector2i = l
		var a := plats(par.x)
		var b := plats(par.y)
		draw_line(a, b, _a(Palett.c(1), 0.55), VÄG_FÅLLA)
		draw_line(a, b, Palett.c(VÄG_FÄRG), VÄG_BREDD)
		_ritade_vägar.append([a, b])

## En plats är en medaljong: skugga, kant, skiva och ett märke i mitten som säger läget. Fyra likadana
## rutor går inte att skilja på, och ett läge man ser på formen behöver ingen text.
func _nod(i: int) -> void:
	var p := plats(i)
	var s := stil(i)
	# Skuggan på marken: noden står på kartan.
	draw_colored_polygon(_ellips(Vector2(p.x, p.y + NOD - 1.0), NOD, NOD * 0.45), _a(Palett.c(0), 0.35))
	if bool(s["lås"]):
		# Låst: en stenhäll med sprickor och ett hänglås, en aning MINDRE än en öppen nod — den
		# öppna ska vara den som syns.
		var k := 0.84
		draw_circle(p, NOD * k, Palett.c(1))
		draw_circle(p, NOD * k - 1.0, Palett.c(3))
		draw_circle(p + Vector2(-1.0, -1.0), NOD * k - 3.0, Palett.c(4))
		draw_line(p + Vector2(-4.0, -2.0), p + Vector2(-2.0, 0.0), Palett.c(3), 1.0)
		draw_line(p + Vector2(2.0, 2.0), p + Vector2(4.0, 0.0), Palett.c(3), 1.0)
		_lås(p)
		return
	draw_circle(p, NOD, Palett.c(1))
	draw_circle(p, NOD - 1.0, Color(s["kant"]))
	draw_circle(p + Vector2(0.0, -0.5), NOD - 3.0, s["fyllnad"])
	draw_rect(Rect2(p.x - 3.0, p.y - 3.0, 6.0, 1.0), s["fyllnad"].lightened(0.25))
	if bool(s["klar"]):
		_bock(p)
		return
	# Ingången: en mörk öppning med en varm rand överst — platsen man går in i.
	draw_rect(Rect2(p.x - 3.0, p.y - 3.0, 6.0, 6.0), Palett.c(1))
	draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 4.0, 5.0), Palett.c(13))
	draw_rect(Rect2(p.x - 2.0, p.y - 4.0, 4.0, 2.0), Palett.c(14))
	var delvis := float(s["delvis"])
	if delvis > 0.0:
		# Guldstapeln under noden: hur långt man kom. Utan den ser en påbörjad ut som en orörd.
		draw_rect(Rect2(p.x - NOD, p.y + NOD + 1.0, NOD * 2.0, 2.0), Palett.c(1))
		draw_rect(Rect2(p.x - NOD, p.y + NOD + 1.0, NOD * 2.0 * delvis, 2.0), Palett.c(14))

## Hänglåset på en låst plats. `s` är skalan: samma lås ritas mindre i teckenförklaringen.
func _lås(p: Vector2, s: float = 1.0) -> void:
	draw_rect(Rect2(p + Vector2(-3, 1) * s, Vector2(6, 5) * s), Palett.c(7))
	draw_rect(Rect2(p + Vector2(-3, 1) * s, Vector2(6, 1) * s), Palett.c(8))
	draw_rect(Rect2(p + Vector2(-2, -3) * s, Vector2(1, 4) * s), Palett.c(6))
	draw_rect(Rect2(p + Vector2(1, -3) * s, Vector2(1, 4) * s), Palett.c(6))
	draw_rect(Rect2(p + Vector2(-1, -4) * s, Vector2(2, 1) * s), Palett.c(6))
	draw_rect(Rect2(p + Vector2(-1, 2) * s, Vector2(2, 1) * s), Palett.c(1))

## Den gröna bocken på en avklarad plats (Alex: "en grön bock visar om den är klar").
func _bock(p: Vector2) -> void:
	draw_line(p + Vector2(-3.5, 0.0), p + Vector2(-1.0, 3.0), Palett.c(1), 3.0)
	draw_line(p + Vector2(-1.0, 3.0), p + Vector2(4.0, -3.0), Palett.c(1), 3.0)
	draw_line(p + Vector2(-3.5, -0.5), p + Vector2(-1.0, 2.5), Palett.c(15), 1.0)
	draw_line(p + Vector2(-1.0, 2.5), p + Vector2(4.0, -3.5), Palett.c(15), 1.0)

## Namnplaketten ovanför en nod. Egen funktion för att texten ritas i FÖNSTRET (ui_text.gd) medan
## plaketten ritas i vyn: båda räknar ur samma ruta, och provet mäter att namnet ryms i den.
func namnplåt(i: int) -> Rect2:
	var p := plats(i)
	var vp := _vy()
	var namn := str(_noder[i]["plats"])
	var bredd: float = ThemeDB.fallback_font.get_string_size(namn, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8.0
	var x: float = clampf(p.x - bredd / 2.0, 3.0, vp.x - bredd - 3.0)
	# Klämd mellan bården och remsan: med 2 låg plaketten mot ramen ("texten ligger klistrad mot den
	# övre ramen"), och med kortets överkant hamnade den INUTI listen (mätt i bild: Nedre portens skylt
	# skar rakt in i kortets överkant). Plaketten hör till kartytan, inte till remsan. M118: remsan
	# ligger nu i vyns nederkant, så klämmen mäts mot dess ruta — inte mot ett designmått.
	return Rect2(Vector2(x, clampf(p.y - NOD - 17.0 - float(PULS[_ram]), 10.0, kort_ruta().position.y - 14.0)),
		Vector2(bredd, 12.0))

## Markeringen: fyra klamrar runt noden och namnet på en plakett ovanför. Klamrar pekar ut platsen —
## en hel ram runt medaljongen skar genom den.
func _markerad(i: int) -> void:
	var p := plats(i)
	var r := Rect2(p - Vector2(NOD + 4.0, NOD + 4.0), Vector2(NOD * 2.0 + 8.0, NOD * 2.0 + 8.0))
	var gupp := float(PULS[_ram])
	var klamrar := [
		[Vector2(r.position.x, r.position.y - gupp), Vector2(5, 2)],
		[Vector2(r.position.x, r.position.y - gupp), Vector2(2, 5)],
		[Vector2(r.end.x - 5, r.position.y - gupp), Vector2(5, 2)],
		[Vector2(r.end.x - 2, r.position.y - gupp), Vector2(2, 5)],
		[Vector2(r.position.x, r.end.y - 2 + gupp), Vector2(5, 2)],
		[Vector2(r.position.x, r.end.y - 5 + gupp), Vector2(2, 5)],
		[Vector2(r.end.x - 5, r.end.y - 2 + gupp), Vector2(5, 2)],
		[Vector2(r.end.x - 2, r.end.y - 5 + gupp), Vector2(2, 5)],
	]
	for k in klamrar:
		draw_rect(Rect2(k[0], k[1]), Palett.c(1))
		draw_rect(Rect2(k[0] + Vector2(1.0, 1.0), k[1] - Vector2(2.0, 2.0)), Palett.c(8))
	var plåt := namnplåt(i)
	draw_rect(plåt, Palett.c(1))
	draw_rect(Rect2(plåt.position, Vector2(plåt.size.x, 1.0)), Palett.c(14))
	draw_rect(Rect2(plåt.position + Vector2(0.0, 10.0), Vector2(plåt.size.x, 1.0)), Palett.c(7))

## Kartans bård: en ram i mässing runt hela ytan, så skärmen läses som en karta och inte som en meny.
## (Namnet är inte `_ram` — det är pulsens bildruta, och två saker med samma namn i samma klass är
## ett parsefel, inte en varning.)
func _bård(vp: Vector2) -> void:
	draw_rect(Rect2(3, 3, vp.x - 6, vp.y - 6), Palett.c(6), false, 2.0)
	draw_rect(Rect2(6, 6, vp.x - 12, vp.y - 12), Palett.c(3), false, 1.0)
	for p in [Vector2(6, 6), Vector2(vp.x - 12, 6), Vector2(6, vp.y - 12), Vector2(vp.x - 12, vp.y - 12)]:
		draw_rect(Rect2(p, Vector2(6, 6)), Palett.c(6))
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(4, 4)), Palett.c(4))

## Informationsremsan: platsen, svårigheten, framstegen och teckenförklaringen, i ett tunt band längst
## ned PÅ kartan (M118). Texten står I remsan — över pixelkonsten drunknar den.
func _kort(_vp: Vector2) -> void:
	var r := kort_ruta()
	draw_rect(r.grow(1.0), Palett.c(1))
	draw_rect(r, _a(Palett.c(2), 0.94))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Palett.c(14))
	draw_rect(Rect2(r.position + Vector2(0.0, 1.0), Vector2(r.size.x, 1.0)), Palett.c(9))
	# Teckenförklaringen: samma märken som kartan ritar, i remsans ÖVRE rad till höger. Utan den är tre
	# medaljonger tre medaljonger.
	var y := r.position.y + 8.5
	var slag := ["låst", "öppen", "klar"]
	for k in slag.size():
		var p := Vector2(_legend_x(k), y)
		match str(slag[k]):
			"låst":
				draw_circle(p, 5.0, Palett.c(3))
				_lås(p, 0.8)
			"klar":
				draw_circle(p, 5.0, Palett.c(15))
				_bock(p)
			_:
				draw_circle(p, 5.0, Palett.c(21))
				draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 4.0, 4.0), Palett.c(1))

## Teckenförklaringens bredd, mätt från remsans högerkant. 192 px räcker för tre märken med sina ord i
## en 480 px-vy; i en SMAL vy (941x1018 ger 313 px) krymper den, annars hamnade sista märket utanför
## remsan — och ett märke utanför remsan är ett märke ingen ser.
func _legend_bredd() -> float:
	return clampf(kort_ruta().size.x * 0.34, 140.0, LEGEND_BREDD)

## Märkenas x, mätt från remsans högerkant (se `_legend_bredd`).
func _legend_x(k: int) -> float:
	var r := kort_ruta()
	return r.end.x - _legend_bredd() + 5.0 + float(k) * LEGEND_STEG

## Nivåpanelen: en rad per nivå, med grön bock på de klara och hänglås på de som inte är upplåsta.
## Provet mäter att raderna ryms i rutan.
func _panel_ruta() -> void:
	# Panelen är ett LOCK över kartans nedre högra hörn (tio nivårader är 108 px): därför en tät
	# fyllnad och en ram runt om, så den inte flyter ihop med remsan under sig (mätt i bild:
	# "panelen saknar tydlig bottenram och kliver rakt över skiljelinjen").
	var pr := panel_ruta()
	draw_rect(pr.grow(2.0), Palett.c(1))
	draw_rect(pr.grow(1.0), Palett.c(6))
	draw_rect(pr, Palett.c(2))
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, 1.0)), Palett.c(14))
	draw_rect(Rect2(pr.position + Vector2(0.0, 1.0), Vector2(pr.size.x, 1.0)), Palett.c(9))
	draw_rect(Rect2(pr.position.x, pr.end.y - 1.0, pr.size.x, 1.0), Palett.c(6))
	var l: Array = nivåer(_vald)
	for k in l.size():
		var r := nivå_rad(_vald, k)
		if k == _nivå:
			draw_rect(r, _a(Palett.c(4), 0.55))
		var s: Stages.StageDef = _stages.get(str(l[k]))
		var nådd := int(_meta.best_floor.get(str(l[k]), 0)) if _meta != null else 0
		var klar := s != null and nådd >= int(s.floors)
		var mp := Vector2(r.position.x + 6.0, r.position.y + 4.5)
		if klar:
			_bock(mp)
		elif s == null:
			_lås(mp, 0.7)
		else:
			draw_rect(Rect2(mp.x - 2.0, mp.y - 2.0, 4.0, 4.0), Palett.c(13))

## Editorns rutor: ett rutnät var tionde procent (utan det går det inte att se var en nod hamnar),
## en ring kring varje nod att ta tag i, och en ram kring den valda.
func _editor_rutor() -> void:
	for k in 11:
		var x := float(k) * 10.0
		var vx := _vy_px(Vector2(Karta.BILD_BREDD * x / 100.0, 0.0)).x
		var vy2 := _vy_px(Vector2(Karta.BILD_BREDD * x / 100.0, Karta.BILD_HÖJD)).x
		draw_line(Vector2(vx, 0.0), Vector2(vy2, bar()), _a(Palett.c(26), 0.12), 1.0)
		var hy := _vy_px(Vector2(0.0, Karta.BILD_HÖJD * x / 100.0)).y
		var hy2 := _vy_px(Vector2(Karta.BILD_BREDD, Karta.BILD_HÖJD * x / 100.0)).y
		draw_line(Vector2(0.0, hy), Vector2(_vy().x, hy2), _a(Palett.c(26), 0.12), 1.0)
	for i in _noder.size():
		draw_arc(plats(i), NOD + 3.0, 0.0, TAU, 16, _a(Palett.c(14), 0.55), 1.0)
	if not _noder.is_empty():
		var p := plats(_vald)
		draw_rect(Rect2(p - Vector2(NOD + 7.0, NOD + 7.0), Vector2(NOD + 7.0, NOD + 7.0) * 2.0),
			Palett.c(14), false, 1.0)

# --- etiketterna (ritas i fönstret av ui_text.gd, mäts av ui/textprov.gd) ------
func etiketter(vp: Vector2) -> Array:
	var rader := []
	if _noder.is_empty():
		# En tom vy (provet skapar en) ska säga det med en rad, inte krascha.
		rader.append(UiText.rad(Tr.t("ui.map.none", "ingen bana vald"), Vector2(0.0, vp.y * 0.5), 11,
			Palett.c(5), vp.x, HORIZONTAL_ALIGNMENT_CENTER, "tom", Palett.c(1)))
		return rader
	# 1) Namnplåtarna på de noder som syns.
	for i in _noder.size():
		if not _syns(i):
			continue
		var r := namnplåt(i)
		var namn := str(_noder[i]["plats"])
		rader.append(UiText.rad(namn, Vector2(r.position.x + 2.0, r.position.y + r.size.y - 3.0),
			UiText.storlek_som_ryms([namn], r.size.x - 4.0, 8, 10, HORIZONTAL_ALIGNMENT_CENTER),
			Palett.c(13) if i == _vald else Palett.c(8), r.size.x - 4.0,
			HORIZONTAL_ALIGNMENT_CENTER, "plåt", Palett.c(1)))
	# 2) Remsan: platsen (och bossen), svårigheten, framstegen och teckenförklaringens ord. TÄTA rader:
	# remsan är 44 px (M118), så raderna ligger på 13, 26 och 39 px — annars flyttar informationen
	# ned kartan i stället för att ligga på den.
	var rem := kort_ruta()
	var n: Dictionary = _noder[_vald]
	var leg := _legend_bredd()
	var x0 := rem.position.x + 5.0
	var namn_bredd := maxf(80.0, rem.size.x - 10.0 - leg - 6.0)
	var rad1 := str(n["plats"]) if str(n["boss"]).is_empty() \
		else "%s · %s" % [str(n["plats"]), str(n["boss"])]
	rader.append(UiText.rad(rad1, Vector2(x0, rem.position.y + 12.0),
		UiText.storlek_som_ryms([rad1], namn_bredd, 8, 12, HORIZONTAL_ALIGNMENT_LEFT), Palett.c(14),
		namn_bredd, HORIZONTAL_ALIGNMENT_LEFT, "kort", Palett.c(1)))
	var bredd := rem.size.x - 10.0
	var rad2 := "%s · %s" % [Tr.t("ui.map.diff", "sv%d") % int(n["svårighet"]), status_text(_vald)]
	var steg := steg_text()
	if not steg.is_empty():
		rad2 += " · " + steg
	var vad := vad_text()
	if not vad.is_empty():
		rad2 += " · " + vad
	rad2 += " · %s · %s · %s" % [Tr.t("ui.map.section", "SEKTION %d") % int(n["sektion"]),
		Tr.t("ui.map.levels", "%d nivåer") % nivåer(_vald).size(),
		Tr.t("ui.map.cleared", "%d klara") % int(n["klar_nivåer"])]
	rader.append(UiText.rad(rad2, Vector2(x0, rem.position.y + 24.0),
		UiText.storlek_som_ryms([rad2], bredd, 8, 10, HORIZONTAL_ALIGNMENT_LEFT), Palett.c(8), bredd,
		HORIZONTAL_ALIGNMENT_LEFT, "kort", Palett.c(1)))
	var kol := [["låst", Tr.t("ui.map.locked_short", "låst")],
		["öppen", Tr.t("ui.map.legend.open", "öppen")],
		["klar", Tr.t("ui.map.done", "klar")]]
	for k in 3:
		var ord := str(kol[k][1])
		var bx := _legend_x(k) + 8.0
		rader.append(UiText.rad(ord, Vector2(bx, rem.position.y + 12.0),
			UiText.storlek_som_ryms([ord], float(LEGEND_STEG) - 14.0, 8, 9, HORIZONTAL_ALIGNMENT_LEFT),
			Palett.c(7), float(LEGEND_STEG) - 14.0,
			HORIZONTAL_ALIGNMENT_LEFT, "kort", Palett.c(1)))
	# 3) Nivåpanelen: rubriken och en rad per nivå — nummer och namn till vänster, status till höger.
	if _panel:
		var titel := Tr.t("ui.map.pick", "VÄLJ NIVÅ")
		var pr := panel_ruta()
		rader.append(UiText.rad(titel, Vector2(pr.position.x + 4.0, pr.position.y + 10.0),
			UiText.storlek_som_ryms([titel], pr.size.x - 20.0, 8, 10, HORIZONTAL_ALIGNMENT_LEFT),
			Palett.c(14), pr.size.x - 20.0, HORIZONTAL_ALIGNMENT_LEFT, "panel", Palett.c(1)))
		var l: Array = nivåer(_vald)
		for k in l.size():
			var r := nivå_rad(_vald, k)
			var s: Stages.StageDef = _stages.get(str(l[k]))
			var namn := Tr.name_of("stage", str(l[k]), s.name if s != null else str(l[k]))
			var nådd := int(_meta.best_floor.get(str(l[k]), 0)) if _meta != null else 0
			var klar := s != null and nådd >= int(s.floors)
			var vänster := "%d. %s" % [k + 1, namn]
			# Återbruk: samma siffra som kortet visar för en påbörjad plats ("v1/3"), så panelen och
			# kortet säger samma sak om samma läge.
			var höger := Tr.t("ui.map.done", "klar") if klar \
				else Tr.t("ui.map.partial", "v%d/%d") % [nådd, int(s.floors) if s != null else 1]
			var färg := Palett.c(15) if klar else Palett.c(13)
			rader.append(UiText.rad(vänster, Vector2(r.position.x + 12.0, r.position.y + 7.0),
				UiText.storlek_som_ryms([vänster], r.size.x - 44.0, 8, 9, HORIZONTAL_ALIGNMENT_LEFT),
				färg, r.size.x - 44.0, HORIZONTAL_ALIGNMENT_LEFT, "panel", Palett.c(1)))
			rader.append(UiText.rad(höger, Vector2(r.position.x + r.size.x - 30.0, r.position.y + 7.0),
				UiText.storlek_som_ryms([höger], 28.0, 8, 9, HORIZONTAL_ALIGNMENT_RIGHT), färg, 28.0,
				HORIZONTAL_ALIGNMENT_RIGHT, "panel", Palett.c(1)))
	# 4) Editorn: talen för den nod man håller i, och kvittot efter en skrivning.
	if editor:
		var rad := nod_text(_vald)
		rader.append(UiText.rad(rad, Vector2(6.0, kort_ruta().position.y - 6.0),
			UiText.storlek_som_ryms([rad], vp.x - 12.0, 9, 11, HORIZONTAL_ALIGNMENT_LEFT), Palett.c(14),
			vp.x - 12.0, HORIZONTAL_ALIGNMENT_LEFT, "editor", Palett.c(1)))
		if not _sparad.is_empty():
			rader.append(UiText.rad(_sparad, Vector2(6.0, kort_ruta().position.y - 18.0),
				UiText.storlek_som_ryms([_sparad], vp.x - 12.0, 9, 11, HORIZONTAL_ALIGNMENT_LEFT),
				Palett.c(15), vp.x - 12.0, HORIZONTAL_ALIGNMENT_LEFT, "editor", Palett.c(1)))
	# 5) Sist: beskedet (en låst plats) eller ledtråden. Beskedet MÅSTE ligga sist — provet jämför
	#    sista raden med `besked()`, och en rad som byter plats med ledtråden är ett fel i bild.
	var nederst := Tr.t("ui.map.hint", "← → ↑ ↓ välj plats · Enter = nivåer · Esc = byn") if not editor \
		else Tr.t("ui.map.hint_editor", "dra noden · piltangenter = finjustera · Z = ångra · S = spara · E = klar")
	var färg := Palett.c(7)
	var grupp := "ledtråd"
	if not _besked.is_empty():
		nederst = _besked
		färg = Palett.c(11)
		grupp = "besked"
	var hint_bredd := rem.size.x - 10.0
	rader.append(UiText.rad(nederst, Vector2(x0, rem.end.y - 4.0),
		UiText.storlek_som_ryms([nederst], hint_bredd, 8, 11, HORIZONTAL_ALIGNMENT_LEFT), färg,
		hint_bredd, HORIZONTAL_ALIGNMENT_LEFT, grupp, Palett.c(1)))
	return rader

func _a(c: Color, alfa: float) -> Color:
	return Color(c.r, c.g, c.b, alfa)

func _ellips(p: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var v := TAU * float(i) / 12.0
		pts.append(p + Vector2(cos(v) * rx, sin(v) * ry))
	return pts
