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
		antal += 1


## Bybons poster ur `bybor.json` — provet mäter mot SAMMA tabell som bygget läser.
static func poster() -> Array:
	if not FileAccess.file_exists(DATA):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (data is Dictionary):
		return []
	return (data as Dictionary).get("bybor", [])
