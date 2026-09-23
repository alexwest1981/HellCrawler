## Stages som data: en JSON-fil per bana. Målet är 90 banor (genereras av tools/gen_stages.py ur
## kurvan i docs/skilltree.md) — det ska vara 90 filer, inte 90 scener.
class_name Stages
extends RefCounted

const DIR := "res://data/stages/"

class StageDef extends RefCounted:
	var id: String
	var name: String
	var theme: String = "default"     ## styr vilket tileset våningarna byggs med
	var floor_themes: Array = []      ## tema per våning: våning N tar floor_themes[N % storlek].
	                                  ## Utan listan används `theme` på varje våning. Gör att en
	                                  ## bana kan börja i en grotta och sluta i en krypta.
	var difficulty: int = 1           ## 1..30 (var 1..9; skalan förlängdes när banlistan blev 90)
	var floors: int = 3
	var tiers: Array = [1]            ## vilka fiende-tiers som får dyka upp
	var encounters_per_floor: int = 4
	var boss: String = ""             ## boss för våningarna
	var bosses: Array = []            ## flera bossar: våning N tar bosses[N % storlek]. Utan listan
	                                  ## används `boss` på varje våning. Fanns för att "Ash Sovereign"
	                                  ## stod i bestiariet utan att någon bana någonsin kallade på den.
	var final_boss: String = ""       ## sista våningens boss (oftast "pale_reaper"-liknande)
	var regel: String = ""            ## banans regel (mutator): HUR banan spelas, inte hur svår den är.
	                                  ## Id ur `Regler.ALLA`; tomt = vanlig bana. Sätts i ban-editorn.
	var gold_bonus: float = 0.0
	var xp_bonus: float = 0.0

	static func from_dict(d: Dictionary) -> StageDef:
		var s := StageDef.new()
		s.id = str(d.get("id", ""))
		if s.id.is_empty():
			push_error("stage utan id: %s" % d)
		s.name = str(d.get("name", s.id))
		s.theme = str(d.get("theme", "default"))
		var våningar := []
		for t in d.get("floor_themes", []):
			våningar.append(str(t))
		s.floor_themes = våningar
		s.difficulty = int(d.get("difficulty", 1))
		s.floors = int(d.get("floors", 3))
		var tiers := []
		for t in d.get("tiers", [1]):
			tiers.append(int(t))      # JSON ger flyttal även för heltal (1 -> 1.0)
		s.tiers = tiers
		s.encounters_per_floor = int(d.get("encounters_per_floor", 4))
		s.boss = str(d.get("boss", ""))
		var bossar := []
		for b in d.get("bosses", []):
			bossar.append(str(b))
		s.bosses = bossar
		s.final_boss = str(d.get("final_boss", ""))
		s.regel = str(d.get("regel", ""))
		s.gold_bonus = float(d.get("gold_bonus", 0.0))
		s.xp_bonus = float(d.get("xp_bonus", 0.0))
		return s

	## Tillbaka till samma form som filen har, så en ändring i verkstaden skriver en fil spelet kan
	## läsa igen. Ordningen är filens, inte en påhittad: en diff ska visa bara det man ändrade.
	func to_dict() -> Dictionary:
		# `bosses` stod i from_dict men saknades här: en bana med flera bossar tappade listan varje
		# gång editorn sparade den. Ett fält som läses men inte skrivs är en bugg som väntar.
		return {"id": id, "name": name, "theme": theme, "floor_themes": floor_themes.duplicate(),
			"difficulty": difficulty, "floors": floors, "tiers": tiers.duplicate(),
			"encounters_per_floor": encounters_per_floor, "boss": boss, "bosses": bosses.duplicate(),
			"final_boss": final_boss, "gold_bonus": gold_bonus, "xp_bonus": xp_bonus,
			"regel": regel}

## Fältens gränser, på ETT ställe: verkstaden klämmer med samma tal som den skriver, och en
## ändring här följer med både UI:t och filen. Taket på våningar (8) är spelets eget — en bana med
## fler våningar är längre än den sista bossen, och svårighetsgraden är 1..9 som referensens banor.
const FÄLT := [
	{"nyckel": "difficulty", "min": 1, "max": 9, "steg": 1, "text": "svårighetsgrad"},
	{"nyckel": "floors", "min": 1, "max": 8, "steg": 1, "text": "våningar"},
	{"nyckel": "encounters_per_floor", "min": 1, "max": 16, "steg": 1, "text": "strider per våning"},
	{"nyckel": "gold_bonus", "min": 0.0, "max": 3.0, "steg": 0.05, "text": "guldbonus"},
	{"nyckel": "xp_bonus", "min": 0.0, "max": 3.0, "steg": 0.05, "text": "xp-bonus"},
]

## Klämmer ett fält till sin gräns. Svarar med det nya värdet. Okänt fält = oförändrat (0).
static func kläm(nyckel: String, värde: float) -> float:
	for f in FÄLT:
		if str(f["nyckel"]) == nyckel:
			return clampf(värde, float(f["min"]), float(f["max"]))
	return 0.0

## Skriver en bana tillbaka till sin fil i data/stages/. Atomiskt som sparfilen: antingen finns hela
## filen eller den gamla kvar. Vägen byggs ur ID:T, så en ändring kan inte hamna i en annan banas fil.
static func skriv(s: StageDef, dir_path: String = DIR) -> bool:
	if s == null or s.id.is_empty():
		return false
	var fil := "%s%s.json" % [dir_path, s.id]
	var tmp := fil + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("kunde inte skriva %s" % tmp)
		return false
	f.store_string(JSON.stringify(s.to_dict(), " ") + "\n")
	f.close()
	var d := DirAccess.open(dir_path)
	if d == null:
		return false
	if d.file_exists(fil.get_file()):
		d.remove(fil.get_file())
	return d.rename(tmp.get_file(), fil.get_file()) == OK


## id -> StageDef
static func load_all(dir_path: String = DIR) -> Dictionary:
	var out := {}
	for d in Db.load_packs(dir_path):
		var s := StageDef.from_dict(d)
		if out.has(s.id):
			push_error("dubbelt stage-id: %s" % s.id)
		out[s.id] = s
	return out

## Temat för en våning: våningens eget (ritad karta), annars banans floor_themes, annars banans
## `theme`. Tomt svar = platt fallback (de gamla rutorna i assets/tiles/*.png).
static func theme_for(stage: StageDef, floor_index: int) -> String:
	if stage == null:
		return ""
	if not stage.floor_themes.is_empty():
		return str(stage.floor_themes[floor_index % stage.floor_themes.size()])
	if stage.theme != "" and stage.theme != "default":
		return stage.theme
	return ""


## Bossen på en given våning: sista våningen använder final_boss om den finns.
## En bana med `bosses`-lista trappar upp: våning 1 och 2 tar första bossen, våning 3 nästa, osv.
static func boss_for(stage: StageDef, floor_index: int) -> String:
	if floor_index >= stage.floors - 1 and not stage.final_boss.is_empty():
		return stage.final_boss
	if stage.bosses.is_empty():
		return stage.boss
	return str(stage.bosses[floor_index % stage.bosses.size()])
