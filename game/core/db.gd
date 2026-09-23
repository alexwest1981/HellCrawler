## En lastare för alla data-pack (kort, fiender, stages). Skrivs en gång, används tre gånger —
## så ett nytt innehållsslag kostar en rad, inte en ny lastare.
class_name Db
extends RefCounted

## Alla JSON-filer i `dir_path`, i namnordning, ihopslagna till en lista.
## Filnamnsordningen gör resultatet deterministiskt: samma filer = samma innehåll varje körning.
## En trasig fil är ett fel som syns och loggas — aldrig en tyst tom lista.
static func load_packs(dir_path: String) -> Array:
	var out := []
	var names := []
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".json"):
			names.append(f)
	if names.is_empty():
		push_error("inga data-pack i %s" % dir_path)
		return out
	names.sort()
	for f in names:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir_path + f))
		if parsed == null:
			push_error("trasig JSON: %s%s" % [dir_path, f])
			continue
		# En pack-fil får vara en lista (många objekt) eller ett enda objekt
		# (en fil per sak — så stages skrivs: en bana per fil).
		match typeof(parsed):
			TYPE_ARRAY:
				for d in parsed:
					out.append(d)
			TYPE_DICTIONARY:
				out.append(parsed)
			_:
				push_error("oväntad JSON-rot (lista eller objekt förväntades): %s%s" % [dir_path, f])
	return out

## Slå upp en post på id, med tydligt fel i stället för en tyst null.
static func by_id(items: Dictionary, id: String, what: String) -> Variant:
	if not items.has(id):
		push_error("okänt id: %s (%s)" % [id, what])
		return null
	return items[id]
