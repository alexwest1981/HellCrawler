## En korthög i marginalen (M34, punkt 8): korten man har, ett kort per kort.
##
## Alex: *"staplarna med kort måste bli lika stora som korten är i spelet. Det får inte se ut som små
## rektanglar. ... Korten skall representera de faktiska korten man har i handen, så har jag 12 kort i
## min samling, så skall det finnas 12 kort, t ex 1 kort som är använt till vänster, 4 i handen och 7
## till höger. Korten skall ha en och samma baksida, så man inte ser vad som ligger härnäst på tur."*
##
## Alltså: kort i KORTETS storlek (samma som i handen), ETT ritat kort per kort i högen, och samma
## baksida (`assets/cards/_back.png`) på alla. Stapeln sprider sig i sidled BORT från spelvyn —
## precis så mycket att varje kort får sin egen kant, och aldrig mer än kolumnen rymmer. Antalet står
## under som siffra: att räkna arton kanter är att räkna i onödan.
class_name KortHog
extends Control

const STEG_MAX := 6.0              ## px mellan två kort när det finns plats
const STEG_MIN := 1.5              ## px när högen är stor: kanten ska fortfarande synas
const TEXT_HÖJD := 16.0            ## raden med antalet under stapeln

var antal := 0
var kort := Vector2(104, 144)      ## kortets yttermått i fönsterpx (CardView.HAND_SIZE * skala)
var spridning := 0.0               ## hur brett stapeln får sprida i sidled
var botten := 0.0                  ## stapelns nederkant (kortens underkant)
var riktning := 1                  ## +1 = högen växer åt höger, -1 = åt vänster
var färg := Color.WHITE            ## högens färg på den ritade fallskärmen
var tom := Color.BLACK
var _steg := 0.0

## Baksidan laddas en gång: den är samma kort på varje kort i varje hög.
static var _bak: Texture2D = null

func ställ_in(antalet: int, kort_mått: Vector2, sprid: float, bottenkant: float, rikt: int,
		f: Color, tom_färg: Color) -> void:
	antal = antalet
	kort = kort_mått
	spridning = sprid
	botten = bottenkant
	riktning = rikt
	färg = f
	tom = tom_färg
	if _bak == null and ResourceLoader.exists("res://assets/cards/_back.png"):
		_bak = load("res://assets/cards/_back.png")
	# Steget räknas ur hur många kort som ska synas: varje kort ska få en egen kant, och högen får
	# inte sprida mer än kolumnen rymmer. Fler kort = tunnare kant, aldrig färre kort.
	var n := maxi(1, antal)
	_steg = clampf(spridning / float(n - 1), STEG_MIN, STEG_MAX) if n > 1 else 0.0
	size = Vector2(kort.x + _steg * float(maxi(0, antal - 1)), kort.y + TEXT_HÖJD)
	queue_redraw()

## Positionen: `vid_vyn` är kanten mot spelvyn, och högen växer därifrån och utåt.
func placera_vid(vid_vyn: float) -> void:
	var x := vid_vyn if riktning > 0 else vid_vyn - kort.x - _steg * float(maxi(0, antal - 1))
	position = Vector2(x, botten - kort.y).floor()

## Det ÖVERSTA kortets mitt: dit ett spelat kort flyger, och där nästa kort ligger på tur.
func mitt() -> Vector2:
	return position + Vector2(_steg * float(maxi(0, antal - 1)) * float(riktning), 0.0) + kort * 0.5

## Steget mellan två kort i stapeln — provet mäter att varje kort får en egen kant.
func steg() -> float:
	return _steg

## Den tomma högens ruta: kortets mått mindre en bit, så den läses som en fördjupning i plåten och
## inte som ett kort.
func _tom_ruta() -> Rect2:
	var k := kort if kort.x > 0.0 else Vector2(58.0, 80.0)
	return Rect2(Vector2(2.0, 2.0), k - Vector2(4.0, 4.0))

func _draw() -> void:
	var f := ThemeDB.fallback_font
	if antal == 0:
		# TOM HÖG: en fördjupning i plåten — mörk botten och en NEUTRAL ram. Ramen ritades först i
		# högens egen färg, och en tom röd ram läses som en kvarglömd debug-ruta (granskningen:
		# "en röd rektangel som ser ut som en platshållare"), medan en tom plats i metallen läses som
		# just en tom plats. Siffran under står kvar: noll använda kort är en upplysning.
		draw_rect(_tom_ruta(), Palett.c(1))
		draw_rect(Rect2(Vector2.ZERO, kort), Palett.c(3), false, 1.0)
	else:
		# Bakifrån och framåt: det översta kortet ritas sist och ligger alltså överst i högen.
		for i in antal:
			var x := _steg * float(i) * float(riktning)
			var r := Rect2(Vector2(x, 0.0), kort)
			if _bak != null:
				draw_texture_rect(_bak, r, false)
			else:
				# Utan baksidan ritas kortet som en ram: konsten ska aldrig vara ett krav för att
				# kunna spela, och en osynlig hög vore värre än en enkel.
				draw_rect(r, tom)
				draw_rect(r.grow(-2.0), färg.darkened(0.35))
			if i < antal - 1:
				# DEN BLOTTADE KANTEN. Varje kort i en riktig hög visar en tunn kant av papperet. Utan
				# den flöt korten ihop till ETT kort: baksidans ram och kortet under har samma färg,
				# så tre pixlars förskjutning syntes inte alls (granskningen: "ser ut som platta
				# rektanglar"). Kanten ritas ovanpå varje kort, och nästa kort täcker allt utom den.
				var kant_x := x if riktning > 0 else x + kort.x - 1.0
				draw_rect(Rect2(kant_x, 0.0, 1.0, kort.y), Palett.c(7))
				draw_rect(Rect2(kant_x + (1.0 if riktning > 0 else -1.0), 0.0, 1.0, kort.y), Palett.c(1))
			if i == antal - 1:
				# Det ÖVERSTA kortet får en ljus kant: det ligger på tur (leken) eller spelades nyss
				# (de använda) — och det är dit ett kort flyger.
				draw_rect(r, färg.lightened(0.35), false, 1.0)
		if antal == 0:
			# En TOM hög ritas som en mörk fördjupning, inte som en färgad ram: en tom ram i blodets
			# färg lästes som en kvarglömd debug-ruta (granskningen: "en tom röd rektangel som ser ut
			# som en platshållare").
			draw_rect(_tom_ruta(), Palett.c(1))
			draw_rect(_tom_ruta(), Palett.c(3), false, 1.0)
	# Antalet under stapeln, i marginalens (fönstrets) storlek — ingen uppskalning, inget ordlager.
	draw_string(f, Vector2(0.0, size.y - 2.0), str(antal), HORIZONTAL_ALIGNMENT_CENTER, size.x, 12,
		Palett.c(7))
