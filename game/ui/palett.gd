## Paletten: färgerna i assets/palette.json, för den grafik som ritas i kod.
##
## Rutorna, rekvisitan och fiendebilderna målas i den här filen (tools/gen_*.py läser samma fil).
## Byn och världskartan ritas med draw_rect/draw_line i stället för i PNG:er — ingen ny grafik
## behövs — och då är palette.json det enda som håller dem i spelets stil. En handplockad Color()
## hade glidit ifrån rutorna utan att någon märkt det.
class_name Palett
extends RefCounted

const PATH := "res://assets/palette.json"

static var _färger: Array[Color] = []

## Färg nummer i (0-26 i palette.json, ordningen är filens radordning).
static func c(i: int) -> Color:
	if _färger.is_empty():
		var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Array:
			for rad in raw:
				_färger.append(Color8(int(rad[0]), int(rad[1]), int(rad[2])))
	if _färger.is_empty():
		return Color.MAGENTA          # magenta syns direkt: palettfilen är borta
	return _färger[clampi(i, 0, _färger.size() - 1)]

static func antal() -> int:
	c(0)                              # se till att filen är läst
	return _färger.size()
