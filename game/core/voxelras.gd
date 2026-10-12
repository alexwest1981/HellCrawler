## VOXLARNAS TYNGDLAG (M108). Alex: "Skulle vara häftigt om vi kunde få in någon form av tyngdlag på
## voxlarna, att när fienden dör, så går de sönder å ramlar ut över golvet under och studsar omkring lite
## innan de försvinner i random takt (ej för långsamt)."
##
## VARFÖR EN EGEN NOD: raset får inte bo på fienden. Striden tar bort figuren strax efter dödsögonblicket,
## och då rivs allt som hänger på den — det var därför Alex såg varken att de dog eller att bitarna for.
## Den här noden läggs i VÄRLDEN, på fiendens plats, och lever sitt eget liv.
##
## INGEN FYSNIKMOTOR: bitarna är mesh-noder med en egen liten rörelse (fart, tyngd, studs mot golvet), inte
## RigidBody3D. Ett tiotal kroppar per dråp hade kostat mer än hela striden, och det som ska LÄSAS är
## riktning och studs — inte exakt fysik.
##
## BITARNA ÄR BLOCK AV MODELLEN, och de är byggda med samma `Voxel` som kroppen: varje bit får modellens
## `sidor`, `höjd` och `_förskjutning`, så dess mesh hamnar på exakt samma plats i modellens rum som
## cellerna hade. Bitarna börjar alltså som figuren — och faller isär. Ingen omräkning av en enda pixel.
class_name VoxelRas
extends Node3D

const TYGND := 9.5             ## m/s², nedåt
const STUDSTAL := 0.35         ## hur mycket en bit behåller av farten när den slår i golvet
const MARKFRIKTION := 0.72     ## sidofarten bromsas i varje studs
const MIN_LIV := 0.75          ## kortaste liv, sekunder
const MAX_LIV := 1.6           ## längsta
const SNURR := 3.2             ## rad/s, så bitarna tumlar i stället för att glida

var _bitar: Array = []
var _golv := 0.0               ## golvets höjd i nodens EGET rum (sätts av `från`)


static func från(vx: Voxel, plats: Transform3D, golv_y: float, material: Material, block: int = 4) -> VoxelRas:
	var ras := VoxelRas.new()
	ras.global_transform = plats
	ras._golv = golv_y - plats.origin.y      # golvet i nodens lokala rum: bitarna rör sig lokalt
	# Cellerna grupperas i block: en bit är några celler i sidled, inte en pixel. En pixel per bit hade
	# blivit tusen noder och sett ut som ett pulver, inte som en kropp som går sönder.
	var grupper := {}
	var summor := {}
	for cell in vx.celler:
		var nyckel := Vector3i(cell.x / block, cell.y / block, cell.z / block)
		if not grupper.has(nyckel):
			grupper[nyckel] = {}
			summor[nyckel] = Vector3i.ZERO
		grupper[nyckel][cell] = vx.celler[cell]
		summor[nyckel] = Vector3i(summor[nyckel]) + cell
	var mitten := Vector3i(vx.kolumner / 2, vx.sidor / 2, maxi(1, vx.djup) / 2)
	for nyckel in grupper:
		var del := Voxel.new()
		del.sidor = vx.sidor
		del.djup = vx.djup
		del.höjd = vx.höjd
		del.kolumner = vx.kolumner
		del.celler = grupper[nyckel]
		del._förskjutning = vx._förskjutning
		var nod := del.nod()
		nod.material_override = material
		ras.add_child(nod)
		# Farten: UTÅT från modellens mitt och en aning uppåt, så bitarna sprider sig i stället för att
		# staplas på varandra. Sido- och höjdfarten skalas med modellens storlek, så en liten fiende får
		# korta kast och en stor får långa.
		var n := float(maxi(1, (grupper[nyckel] as Dictionary).size()))
		var medel := Vector3(summor[nyckel]) / n - Vector3(mitten)
		var m := maxf(vx.höjd, 0.2)
		var ut := Vector3(medel.x, medel.y, 0.0).normalized() * (0.6 + randf() * 0.9) * m
		ras._bitar.append({
			"nod": nod,
			"fart": Vector3(ut.x, absf(ut.y) * 0.6 + m * 1.4 + randf() * m * 0.8, randf_range(-0.3, 0.3) * m),
			"liv": randf_range(MIN_LIV, MAX_LIV),
			# Snurret behöver BÅDE en axel och en fart: `Node3D.rotate(axel, vinkel)`. En vektor med
			# tre vinklar finns inte som anrop, och det var ett kompileringsfel som gjorde att hela spelet
			# vägrade ladda.
			"axel": Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(),
		})
	return ras


## Bitarna faller, studsar mot golvet och försvinner i EGEN takt — Alex ville inte ha en gemensam
## nedsläckning: "innan de försvinner i random takt". Noden städar sig själv när sista biten är borta, så
## världen inte fylls av tomma noder efter en lång strid.
func _process(delta: float) -> void:
	var kvar := 0
	for bit in _bitar:
		var nod: MeshInstance3D = bit["nod"]
		if nod == null or not is_instance_valid(nod):
			continue
		var liv := float(bit["liv"]) - delta
		bit["liv"] = liv
		if liv <= 0.0:
			nod.visible = false
			continue
		kvar += 1
		var fart: Vector3 = bit["fart"]
		fart.y -= TYGND * delta
		nod.position += fart * delta
		if nod.position.y <= _golv:
			nod.position.y = _golv
			fart.y = absf(fart.y) * STUDSTAL
			fart.x *= MARKFRIKTION
			fart.z *= MARKFRIKTION
		bit["fart"] = fart
		nod.rotate(bit["axel"], SNURR * delta * (1.2 if randf() < 0.5 else 0.8))
	if kvar == 0:
		queue_free()


## Antalet bitar, för proven: en kropp som går sönder ska bli fler än en bit och färre än tusen.
func antal_bitar() -> int:
	return _bitar.size()
