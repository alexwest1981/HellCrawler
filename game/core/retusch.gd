## Retuscheringen av fiendekonsten (M82). Alex: *"Kan vi göra så att det finns editor för fienden med,
## så man manuellt kan editera vad som är kropp, vad som inte skall synas osv."*
##
## VARFÖR ETT RECEPT OCH INTE EN PNG: konsten ägs av generatorerna i `tools/` — en editor får aldrig
## skriva en PNG (se `hellcrawler-editors`). Fiendeeditorn skriver därför ett recept av LOGISKA pixlar i
## duken (120x120, samma ruta som spelet ritar), och den här filen lägger receptet på bilden när fienden
## laddas. Ett streck i editorn syns alltså direkt i spelet, utan att något körs om.
##
## EN KOPIA AV REGELN, INTE TVÅ: `tillämpa` används av både spelet (`main._enemy_tex`) och provet.
##
## ponytail: retuschen är knuten till logiska pixlar, så kör någon `tools/gen_enemy_new.py` igen och
## figuren byter form kan en suddad pixel hamna fel. Dra i `X` i editorn och måla om den dagen det
## händer — att versionsbinda receptet mot arkets kontrollsumma vore mer maskineri än nytta nu.
extends RefCounted
class_name Retusch

const FIL := "res://data/enemies/retuschering.json"


## Receptet. Saknad fil är tomt recept (samma regel som sparfilerna: en frånvarande fil är inte ett
## fel, en trasig är det — då står skälet i felsträngen i stället för att tyst bli tomt).
static func läs(sökväg: String = FIL) -> Dictionary:
	if not FileAccess.file_exists(sökväg):
		return {}
	var f := FileAccess.open(sökväg, FileAccess.READ)
	if f == null:
		push_warning("retuscheringen kunde inte öppnas: %s" % sökväg)
		return {}
	var text := f.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("retuscheringen är trasig (%s) — körs utan" % sökväg)
		return {}
	return data


## Skriver receptet atomiskt (temp + rename) och svarar med "" eller skälet i klartext. Skrivaren tar
## emot mappen så provet kan skriva i `user://` i stället för i spelets data.
static func skriv(recept: Dictionary, sökväg: String = FIL) -> String:
	var katalog := sökväg.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(katalog)):
		var fel := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(katalog))
		if fel != OK:
			return "kunde inte skapa %s (%d)" % [katalog, fel]
	var tmp := sökväg + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "kunde inte skriva %s" % tmp
	f.store_string(JSON.stringify(recept, "\t"))
	f.close()
	var flyttad := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(sökväg))
	if flyttad != OK:
		return "kunde inte byta namn på %s (%d)" % [tmp, flyttad]
	return ""


## Lägger receptet för `id` på `bild` (en Image av fiendens ark). Svarar med antalet ändrade pixlar.
## Pixlar utanför bilden hoppas över: ett recept som skrivits mot en annan duk ska inte krascha spelet.
static func tillämpa(bild: Image, recept: Dictionary, id: String) -> int:
	if bild == null or id.is_empty() or not recept.has(id):
		return 0
	var r = recept[id]
	if typeof(r) != TYPE_DICTIONARY:
		return 0
	# Bilden från en importerad PNG kan vara packad (och då tystar set_pixel alfan och färgerna blir
	# ett steg fel). Receptet skrivs och läses i RGBA8 — samma format som editorn visar.
	if bild.get_format() != Image.FORMAT_RGBA8:
		bild.convert(Image.FORMAT_RGBA8)
	var ändrade := 0
	for punkt in r.get("sudda", []):
		if typeof(punkt) == TYPE_ARRAY and punkt.size() >= 2:
			var x := int(punkt[0])
			var y := int(punkt[1])
			if x >= 0 and y >= 0 and x < bild.get_width() and y < bild.get_height():
				bild.set_pixel(x, y, Color(0, 0, 0, 0))
				ändrade += 1
	for punkt in r.get("måla", []):
		if typeof(punkt) == TYPE_ARRAY and punkt.size() >= 3:
			var x := int(punkt[0])
			var y := int(punkt[1])
			if x >= 0 and y >= 0 and x < bild.get_width() and y < bild.get_height():
				bild.set_pixel(x, y, Color.html(str(punkt[2])))
				ändrade += 1
	return ändrade
