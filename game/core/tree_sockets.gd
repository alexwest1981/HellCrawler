class_name TreeSockets
extends RefCounted

## The socket file: where every tree node sits on the plate image. One home for the format, so the
## view that draws the nodes and the editor that places them can never disagree about it.
##
## Written by tools/gen_tree_sockets.py (machine measurement) and by the tree editor (a human hand),
## read by game/ui/tree_view.gd. A record is:
##
##   { "id": "iron_1", "x": 0.2012, "y": 0.0986, "r": 0.018, "score": 0.064,
##     "guess_x": 0.2348, "guess_y": 0.1289 }
##
## x and y are fractions of the square plate image (0..1), r the socket's radius in the same unit,
## score how strongly the measurement found a pit there, and guess_x/guess_y where the lattice put it
## before measuring — kept so the editor can reset a node.

const PATH := "res://data/trad_sockets.json"
const IMAGE := "res://images/Gemini_Generated_Image_68qy7x68qy7x68qy.jpeg"
const SIDE := 1024


## id -> record. An empty dictionary means the file is missing or broken; the view then falls back to
## its lattice, which is worse but never nothing.
static func load_all(path: String = PATH) -> Dictionary:
	var out := {}
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return out
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		return out
	for record in data.get("sockets", []):
		if record is Dictionary and record.has("id"):
			out[str(record["id"])] = record
	return out


## The records as a list, in the order given (ids first, then anything else the file had). Writes are
## atomic: a half-written file would leave the tree with sockets in the wrong places and no way to
## tell which half is real.
static func write(records: Array, path: String = PATH) -> bool:
	var temp := path + ".new"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"image": IMAGE,
		"side": SIDE,
		"method": "placed by hand in game/editor/trad_editor.gd, or measured by tools/gen_tree_sockets.py",
		"sockets": records,
	}, " ", false) + "\n")
	file.close()
	return DirAccess.rename_absolute(temp, path) == OK


## A fresh record for a node the file does not know about yet.
static func blank(id: String, x: float, y: float, r: float) -> Dictionary:
	return {"id": id, "x": x, "y": y, "r": r, "score": 0.0, "guess_x": x, "guess_y": y}
