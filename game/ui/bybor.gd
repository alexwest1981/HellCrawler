## Byns bybor: målningens egna figurer, resta som voxlar i 3D-byn (M129).
##
## Alex 15/10: *"Jag tog bort alla NPC's från modellen, tänkte att man kan klistra in från bilden de
## karaktärer som finns, men som voxlar, så de står där, men platt... typ."*
##
## VARFÖR VOXLAR OCH INTE EN QUAD: samma motor som fienderna (`game/core/voxel.gd`) — figuren byggs ur
## sin egen bild och blir en tunn relief (2 celler djup), alltså "platt" i ordets rätta mening, men med
## en yta som tar emot lyktan, facklorna och skuggorna i byn i stället för en platt ljus skylt.
##
## VAR DE STÅR ÄR INTE PÅHITTAT: `assets/by/bybor.json` bär varje bybos ruta i målningen, höjd i meter
## och position i världen. Positionen kommer ur husmappningen — husens mitt i `PLATSER` (procent av
## målningens bredd) mot husens mitt i `byn.glb` — så en bybo hamnar vid SAMMA hus i 3D-byn som i
## bilden (se `tools/gen_by_bybor.py`, som skriver filen).
##
## Hela gruppen är EN nod ("bybor") under `byn`, så Alex kan gömma eller flytta byn och bybor i ett
## grepp i editorn. Varje bybo är sitt eget barn med sitt id som namn, så en enskild figur går att
## hitta: `byn/bybor/gångerska`.
class_name Bybor
extends Node3D

const DATA := "res://assets/by/bybor.json"
## Mappen filerna i `bybor.json`s `bild`-fält ligger i.
const MAPP := "res://assets/by/"
## Celler i höjd per modell. `Voxel.DETALJ` (2) mångdubblar den, och taket är källkonstens egen höjd
## i px: en bybo på 100 px blir 32 celler = 3 px per cell, vilket räcker gott — vyn ritar hela byn i
## 313x270 px, så en bybo är ett tiotal skärmpixlar hög. Se `tests/test_bybor.gd` för byggtiden.
const SIDOR := 8

## SKUGGAN under varje bybo: samma recept som fiendernas golvfläck i `main.gd` (samma textur, samma färg,
## alfa och form) — byn och striden ska skugga likadant, och en figur utan fläck svävar i stället för att
## stå. Fläcken ligger `SKUGGA_ÖVER` över markens y (annars z-fightar den med marken), är omskuggad av
## (`cast_shadow` AV: en genomskinlig quad ska inte skugga hela rutan, se M80 i `main.gd`) och har MUKA
## kanter (`alpha_cut` AV).
const SKUGGA := "res://assets/fx/rok.png"
const SKUGGA_PIXEL := 0.035      ## px-storleken som ger fläcken 32 x 0.035 = 1,12 m bredd
const SKUGGA_BREDD := 1.12       ## fläckens bredd i meter vid skalan 1,0 (ur SKUGGA_PIXEL x texturens mått)
const SKUGGA_FÄRG := 0.035
const SKUGGA_ALFA := 0.75
const SKUGGA_ÖVER := 0.005       ## hur högt över markens y fläcken ligger
const SKUGGA_DJUP := 0.55        ## djupet som andel av bredden (samma som fiendernas)

var antal: int = 0


## Bygg byborna som barn till `förälder` (byns glb-instans). Returnerar gruppnoden.
static func bygg(förälder: Node3D) -> Bybor:
	var grupp := Bybor.new()
	grupp.name = "bybor"
	förälder.add_child(grupp)
	grupp.fyll()
	return grupp


func fyll() -> void:
	var text := ""
	if FileAccess.file_exists(DATA):
		text = FileAccess.get_file_as_string(DATA)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (data is Dictionary):
		push_warning("bybor: %s saknas eller är inte JSON — byn står tom" % DATA)
		return
	for post in (data as Dictionary).get("bybor", []):
		if not (post is Dictionary):
			continue
		var p: Dictionary = post
		var väg: String = MAPP + str(p.get("bild", ""))
		if not ResourceLoader.exists(väg):
			push_warning("bybor: %s saknas — bybon %s hoppas över" % [väg, str(p.get("id", "?"))])
			continue
		var tex: Texture2D = load(väg)
		if tex == null:
			continue
		var höjd := float(p.get("höjd_m", 1.0))
		# Alfa-redan-utklippt ark (byborna) hoppar över flodfyllningen: deras bakgrund ÄR alfan, och
		# fyllningen kostade 5/6 av byggtiden (MÄTT: 1 250 ms mot 250 ms för 21 bybor).
		var v := Voxel.ur_ark(tex, 0, 1, höjd, SIDOR, 2, false)
		if v.antal_celler() == 0:
			push_warning("bybor: %s gav en tom modell" % str(p.get("id", "?")))
			continue
		var mi := MeshInstance3D.new()
		mi.name = str(p.get("id", "bybo"))
		mi.mesh = v.mesh()
		mi.material_override = Voxel.material()
		# MODELLEN ÄR CENTRERAD KRING SITT ORIGO (`Voxel._förskjutning`), så fötterna står på
		# markens y när noden ligger ett halvt höjd-mått över den.
		var pos: Array = p.get("pos", [0.0, 0.0, 0.0])
		mi.position = Vector3(float(pos[0]), float(pos[1]) + höjd * 0.5, float(pos[2]))
		# Modellens EGEN plan ligger i xy med djupet i z, alltså mot kameran (byn ses från +z) —
		# ingen vridning behövs, och inställningen är densamma i editorn som i spelet.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.set_meta("bybo", p)
		mi.set_meta("celler", v.antal_celler())
		add_child(mi)
		# SKUGGAN PÅ MARKEN, i bybons EGEN bredd (cellerna är kvadratiska, så bredden följer höjden och
		# figurens proportioner): en häst får en lång fläck, fåret en kort.
		var bredd := höjd * float(v.kolumner) / float(maxi(1, v.sidor))
		skugga_under(mi.position.x, float(pos[1]), mi.position.z, bredd, str(p.get("id", "bybo")))
		antal += 1


## Golvfläcken. Receptet är fiendernas i `main.gd` (se konstanterna): en platt quad på marken, vriden
## 90 grader, omskuggad och med mjuka kanter.
func skugga_under(x: float, mark_y: float, z: float, bredd: float, id: String) -> Sprite3D:
	var sk := Sprite3D.new()
	sk.name = id + "_skugga"
	sk.texture = load(SKUGGA)
	sk.pixel_size = SKUGGA_PIXEL
	sk.shaded = false
	sk.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sk.rotation.x = -PI * 0.5
	sk.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sk.modulate = Color(SKUGGA_FÄRG, SKUGGA_FÄRG * 0.68, SKUGGA_FÄRG * 0.5, SKUGGA_ALFA)
	var f := maxf(0.35, bredd) / SKUGGA_BREDD
	sk.scale = Vector3(f, f * SKUGGA_DJUP, 1.0)
	sk.position = Vector3(x, mark_y + SKUGGA_ÖVER, z)
	sk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sk)
	return sk


## Bybons poster ur `bybor.json` — provet mäter mot SAMMA tabell som bygget läser.
static func poster() -> Array:
	if not FileAccess.file_exists(DATA):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (data is Dictionary):
		return []
	return (data as Dictionary).get("bybor", [])
