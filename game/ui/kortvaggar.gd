## KORTVÄGGARNAS RADBRYTNING — i ETT exemplar (M120).
##
## Alex: *"högst 4 per rad, helst 3"*, *"det är OK att man får scrolla upp och ned"* och *"storlek före
## packning — hellre 3 stora kort än 6 små"*. Regeln bodde i `main.gd` (där värdshuset, juveleraren och
## butiken använder den), men fiendeeditorn radar upp sina tillgångar på SAMMA sätt — och en kopia där
## hade glidit ifrån butikernas. Därför en delad klass: de fyra talen och de tre funktionerna står på
## ett ställe, och `main.gd` läser dem härifrån i stället för att äga en andra uppsättning.
class_name Kortvaggar
extends RefCounted

const KOLUMNER := 3            ## helst tre per rad
const TAK := 4                 ## fler får ALDRIG ritas i en rad
const MELLANRUM := 6.0         ## px mellan två celler i rutnätet
const TAKBREDD := 468.0        ## hur brett ett rutnät får bli i den 480 px vida vyn


## Raden bryts vid KOLUMNER (3), och vid TAK (4) bara när det behövs för att fylla: 3 kolumner lämnar
## EN ensam cell på sista raden precis när antalet är 3n+1, och delar 4 jämnt (4, 16) är den fjärde
## kolumnen det som fyller raden i stället för att lämna en efter sig.
## Sedan kapas talet av vad som RYMS i bredden: butikens varor är 205 px breda och 3 av dem hade blivit
## 631 px i en 480 px-vy — då står hellre 2 stora än 3 avklippta. Aldrig fler än TAK.
##
## `bredd` är den yta rutnätet får använda: spelets egen vy (468 px) eller en panels egen bredd.
static func kolumner(antal: int, cell: float, bredd: float = TAKBREDD) -> int:
	var regel := KOLUMNER
	if antal > KOLUMNER and antal % KOLUMNER == 1 and antal % TAK == 0:
		regel = TAK
	var ryms := int(floor((bredd + MELLANRUM) / maxf(cell + MELLANRUM, 1.0)))
	return clampi(mini(regel, ryms), 1, TAK)


## Lägg rutnätet i en rullare. Höjden är innehållets — eller `tak` när innehållet är högre, och då
## rullar resten. `custom_minimum_size` är det som ger rullaren en FAST höjd: utan den mäter den sitt
## innehåll och panelen blir lika hög som hela listan, alltså inget att rulla i. I sidled rullas aldrig.
static func rullare(rutnät: GridContainer, tak: float) -> ScrollContainer:
	rutnät.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rull := ScrollContainer.new()
	rull.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# INNEHÅLLET MÅSTE KLIPPAS MOT RUTANS KANT. Utan det ritar rullaren sina sista rader UNDER sin
	# egen ruta — mätt i fiendeeditorn (M120): femte raden av fillistan hamnade ovanpå tangentlistan.
	# En rullare som inte klipper är ingen rullare, den är en lista som läcker.
	rull.clip_contents = true
	rull.custom_minimum_size = Vector2(0.0, minf(rutnät.get_combined_minimum_size().y, tak))
	rull.add_child(rutnät)
	return rull


## Skjut den valda cellen i bild — rutnätet är högre än sin ruta, så valet kan hamna nedanför kanten.
## VÄNTAR TVÅ BILDRUTOR FÖRST: containern har inte lagt ut cellerna ännu, och en rullare som mäts
## innan dess har ingen höjd att rulla inom — mätt: rullningen hamnade på MAXVÄRDET varje gång valet
## låg utanför den första raden, alltså längst ned i stället för på valet.
static func visa(rull: ScrollContainer, nod: Control, träd: SceneTree) -> void:
	if rull == null or nod == null or träd == null:
		return
	await träd.process_frame
	await träd.process_frame
	# Cellen kan ha bytts ut under väntan (två omritningar i samma ram frigör den gamla): rulla bara
	# ett barn som fortfarande ligger i rullaren. `is_instance_valid` FÖRST — en frigjord nod fäller
	# hela anropet på `is_inside_tree`.
	if not (is_instance_valid(rull) and is_instance_valid(nod)):
		return
	if nod.is_inside_tree() and rull.is_ancestor_of(nod):
		rull.ensure_control_visible(nod)
