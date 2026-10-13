## GÅNGAREN (M122): EN figur som går mellan två punkter och säger till när den är framme.
##
## Alex: *"Sen hade vi behövt ha en karaktär som går mellan punkterna i byn, och på kartan."* EN
## komponent för båda ställena — byn (`ui/village_view.gd`) och världskartan (`ui/worldmap_view.gd`)
## delar samma `Gångare`, så vägen, farten och vickningen inte kan bli två olika saker på två skärmar.
##
## Den ritar INGENTING själv: den vet var den är och när den är framme, och vyn ritar figuren på
## `pos()`. Ingen nod, ingen timer, ingen mesh som byggs om per bildruta — ett steg är två
## vektoroperationer och en sinus.
##
## TIDEN kommer från klockan i `Vickning` (den som `frysfas=` ställer om), så två provbilder i samma
## frysta fas visar figuren i samma steg. SJÄLVA FÖRFLYTTNINGEN räknas däremot ur `delta`, så ett prov
## kan köra vägen i fasta steg och veta exakt var figuren står.
class_name Gångare
extends RefCounted

## Figurens fart i VYN-px per sekund. 90 px/s går en gata på 300 px på 3,3 s — långsamt nog att se att
## den går, snabbt nog att man inte väntar. EN ratt: tid = sträcka / FART, och provet mäter båda.
const FART := 90.0
## Vickningen medan figuren går: en sida-till-sida-gung i vyns px och en gupp i höjdled, i SAMMA stil
## som `Vickning` ger fienderna (amplitud + takt, ingen ny sorts rörelse).
const VICK_SIDA := 1.6
const VICK_GUPP := 1.4
const VICK_TAKT := 9.0
## En väg som är kortare än så här är ingen väg: figuren står still och är framme direkt.
const MIN_VÄG := 0.5

## Sänds när figuren når målet. Anroparen öppnar platsen HÄR och inte vid tangenttrycket — det är
## hela poängen: man går in när man är framme.
signal framme

var _från := Vector2.ZERO
var _till := Vector2.ZERO
var _pos := Vector2.ZERO
var _går := false
var _sträcka := 0.0
var _gått := 0.0
var _riktning := 1.0

## Börja gå från `från` till `till`. Är punkterna nästan samma står figuren still (och är framme).
func starta(från: Vector2, till: Vector2) -> void:
	_från = från
	_till = till
	_pos = från
	_sträcka = från.distance_to(till)
	_gått = 0.0
	_riktning = -1.0 if till.x < från.x else 1.0
	_går = _sträcka > MIN_VÄG
	if not _går:
		_pos = till

## Ett steg. `true` = figuren kom fram JUST nu, och då — och bara då — öppnar anroparen platsen.
func steg(delta: float) -> bool:
	if not _går:
		return false
	_gått = minf(_sträcka, _gått + FART * delta)
	_pos = _från.lerp(_till, _gått / maxf(0.0001, _sträcka))
	if _gått >= _sträcka - 0.01:
		_går = false
		_pos = _till
		framme.emit()
		return true
	return false

## Stanna där figuren står. Målet är kvar, så `steg` kan fortsätta — används när en vy göms.
func stanna() -> void:
	_går = false

func pos() -> Vector2:
	return _pos

func går() -> bool:
	return _går

## Vilket håll figuren är vänd åt: -1 vänster, 1 höger.
func riktning() -> float:
	return _riktning

## Vägens längd i vyns px. Provet (och en vinkelräknande vy) läser den i stället för att räkna om.
func sträcka() -> float:
	return _sträcka

## Hur lång tid vägen tar, i sekunder: sträcka / fart. Noll när figuren står still.
func tid() -> float:
	return _sträcka / FART if _går or _sträcka > MIN_VÄG else 0.0

## Sidledsförskjutningen i px just nu: gungningen medan figuren går, noll när den står.
func vick_sida() -> float:
	return 0.0 if not _går else sin(Vickning.nu() * VICK_TAKT) * VICK_SIDA

## Guppet i höjdled, i px: två steg per sida-sväng (fötterna), alltid positivt — figuren lyfts, den
## sjunker inte genom gatan.
func vick_gupp() -> float:
	return 0.0 if not _går else absf(sin(Vickning.nu() * VICK_TAKT)) * VICK_GUPP
