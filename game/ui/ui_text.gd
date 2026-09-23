## Text i FÖNSTRETS upplösning, ritad ovanpå spelvyn (480x270).
##
## MÄTT: all text i vyn ritades i 480x270 och skalades upp med NEAREST till fönstret — en 10 px-rad
## blev 20 px stora fyrkanter, och en rad som var bredare än sin ruta KLIPPtes av draw_string. Värst
## var beskedet på kartan: "BLOQUEADO — supera El Coro de la Madre de las Campanas primero" är 267 px
## i en ruta på 166 px (se ui/textprov.gd, som mäter varje rad mot sin ruta i alla 13 språk).
##
## HUD:en (main.gd, `_runt`) ritas redan i fönstrets upplösning. Den här klassen ger byn och kartan
## samma skärpa utan att de flyttar ut ur vyn: BILDEN ritas kvar i 480x270 (pixelkonsten ska vara
## pixelkonst), och ORDEN ritas i fönstret, i den storlek de visas.
##
## Lagret ligger i roten: en CanvasLayer under en SubViewport ritas INUTI vyn, alltså uppskalad —
## samma fel en gång till. Punkterna räknas därför om ur vyns SubViewportContainer (korgen i main.gd),
## som är heltalsskalad och centrerad, så en punkt i vyn hamnar rätt även när fönstret ändras.
class_name UiText
extends Control

## Vyn texten hör till (VillageView / WorldMapView). Punkterna i raderna är i VYNS koordinater.
var källa: Control
## Det som ska ritas: se `rad()`. Sätts av vyns `_draw` — samma lista som provet mäter.
var rader: Array = []
## Senaste omräkningen (vy → fönster): ritas om bara när den ändras.
var _m := Transform2D.IDENTITY

## Nycklarna i en rad (samma form som `stil` och `_status` i resten av koden):
##   text     strängen
##   pos      vänsterkant/baslinje, i VYN (480x270)
##   storlek  fontstorlek i vyn — ritas i storlek × skalans heltal i fönstret
##   färg     textfärgen
##   bredd    rutans bredd i vyn (-1 = ingen ruta: texten får sin egen bredd)
##   align    HORIZONTAL_ALIGNMENT_*
##   grupp    radens namn, bara för proven (se ui/textprov.gd): rader i samma grupp får inte gå i
##            varandra
##   skugga   färgen på skuggan ett steg nedåt/höger, eller null
static func rad(text: String, pos: Vector2, storlek: int, färg: Color, bredd: float = -1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, grupp: String = "", skugga = null) -> Dictionary:
	return {"text": text, "pos": pos, "storlek": storlek, "färg": färg, "bredd": bredd,
		"align": align, "grupp": grupp, "skugga": skugga}

## Fäster ett textlager i FÖNSTRET åt vyn `v` och lämnar tillbaka det. Vyn behöver bara kalla på
## `sätt()` med sina rader och `frigör()` när den försvinner.
## `lager_nr` styr ordningen mot HUD:en. Vyns ord (byn, kartan) hör till lager 0: de ligger över
## bilden men UNDER marginalernas HUD (lager 1). Minikartans ord är MARGINALtext och ligger i själva
## HUD:en — de måste därför ligga ÖVER den (lager 2), annars ritar kartan över sina egna ord (mätt:
## teckenförklaringens sex märken syntes men ingen av orden).
static func fäst(v: Control, lager_nr: int = 0) -> UiText:
	var lager := CanvasLayer.new()
	lager.layer = lager_nr
	var t := UiText.new()
	t.källa = v
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE      # vyn tar emot klicken, inte orden
	lager.add_child(t)
	fönsterförälder(v).add_child(lager)
	return t

## Skalnoden: den HÖGSTA förfadern som ligger i FÖNSTRETS vy (inte i den uppskalade 480x270-vyn —
## den skulle rita texten i 480x270, samma fel en gång till). MÄTT, tre försök:
##   * rotnoden (Window): Godot NEKAR add_child inuti skalets `_ready` ("Parent node is busy setting
##     up children") — hela textlagret uteblev.
##   * SubViewportContainer och CanvasLayer: add_child går igenom, men lagret RITAS INTE (mätt: en
##     röd provruta syntes inte i skärmbilden).
##   * skalnoden — samma nod som HUD-lagret `_runt` hänger i (main.gd) — ritar ✓
static func fönsterförälder(v: Node) -> Node:
	var rot := v.get_tree().root
	var skalnoden: Node = v
	var n: Node = v
	while n != null and n != rot:
		if n.get_viewport() == rot:
			skalnoden = n
		n = n.get_parent()
	return skalnoden

## Bort med lagret. Det ligger i FÖNSTRET och följer alltså inte med vyn när den frigörs.
func frigör() -> void:
	var lager := get_parent()
	if lager == null:
		return
	if lager.is_inside_tree():
		lager.queue_free()
	elif lager.get_parent() == null:
		# Lagret kom aldrig in i trädet (appen avslutades innan den uppskjutna raden hann köra):
		# utan förälder är ett direkt free() ofarligt.
		lager.free()
	# Annars rivs trädet just nu och friar lagret självt. Ett free() här ger bara Godot-varningen
	# "Condition data.parent is true" (mätt: den kom från den här raden) — noden har kvar sin
	# förälder även efter NOTIFICATION_EXIT_TREE.

func sätt(nya: Array) -> void:
	rader = nya
	queue_redraw()

## Den största fontstorleken där ALLA texterna ryms i sin ruta. Språken är olika långa — tyskan är
## längst, japanskan kortast — så en fast storlek klipper tyskan och lämnar japanskan onödigt liten.
## `ruta` <= 0 betyder "ingen ruta": då finns inget att rymmas i.
static func storlek_som_ryms(texter: Array, ruta: float, minst: int, störst: int,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> int:
	if ruta <= 0.0:
		return störst
	var f := ThemeDB.fallback_font
	for s in range(störst, minst - 1, -1):
		var ryms := true
		for t in texter:
			if f.get_string_size(str(t), align, -1, s).x > ruta:
				ryms = false
				break
		if ryms:
			return s
	return minst

## Raden sådan den ritas i fönstret: punkten och fontstorleken efter korgen (heltalsskalan). `_draw`
## ritar ur den och provet mäter ur den — samma omräkning, inte två.
static func i_fönstret(raden: Dictionary, m: Transform2D) -> Dictionary:
	var skala: float = maxf(1.0, roundf(m.get_scale().x))
	return {"text": str(raden["text"]), "pos": m * Vector2(raden["pos"]),
		"storlek": maxi(1, int(roundf(float(raden["storlek"]) * skala))),
		"bredd": float(raden["bredd"]) * skala, "align": int(raden["align"]),
		"färg": raden["färg"], "grupp": str(raden.get("grupp", ""))}

func _process(_delta: float) -> void:
	var kvar := källa != null and is_instance_valid(källa)
	# Skalet gömmer vyn när körningen tar över: då ska orden inte ligga kvar över fängelsehålan.
	visible = kvar and källa.is_visible_in_tree()
	if not kvar:
		return
	# Ny fönsterstorlek = nytt skalans heltal (korgen är heltalsskalad). Räknas om varje bildruta och
	# ritas bara när den ÄNDRAS: annars stod orden kvar i fel storlek tills vyn råkade rita om.
	var m := _mapp()
	if m != _m:
		_m = m
		queue_redraw()

func _draw() -> void:
	if källa == null or not is_instance_valid(källa):
		return
	var m := _mapp()
	var f := ThemeDB.fallback_font
	for raden in rader:
		var w := i_fönstret(raden, m)
		var skugga = raden.get("skugga", null)
		if skugga != null:
			# Skuggan flyttas ett steg i VYN (som förut), alltså ett steg × skalan i fönstret.
			draw_string(f, w["pos"] + m.get_scale(), w["text"], w["align"], w["bredd"], w["storlek"],
				Color(skugga))
		draw_string(f, w["pos"], w["text"], w["align"], w["bredd"], w["storlek"], Color(w["färg"]))

## Från en punkt i KÄLLANS egna koordinater till samma punkt i fönstret. Ligger källan i spelvyn
## skalas den upp av korgen (SubViewportContainer, heltalsskalad och centrerad). Ligger den i
## FÖNSTRETS lager (minikartan efter M32) finns ingen korg — då är källans egen canvas-transform
## vägen, och SKALAN i den (kartan ritas i vyns koordinater med scale = fönstrets heltal) ger
## fontstorleken, samma tal som förut kom ur korgen. Mätt: utan den grenen ritades ingenting, för
## kontrollen krävde en korg som en nod i marginalen aldrig har.
func _mapp() -> Transform2D:
	var korg := _korg()
	if korg != null:
		return korg.get_global_transform_with_canvas() * källa.get_global_transform()
	return källa.get_global_transform_with_canvas()

## Korgen vyn ritas upp i (SubViewportContainer i main.gd). Finns den inte är källan ingen vy i
## 480x270 — då finns inget att räkna om (se `_mapp`).
func _korg() -> SubViewportContainer:
	var vp := källa.get_viewport()
	var förälder := vp.get_parent() if vp != null else null
	return förälder as SubViewportContainer
