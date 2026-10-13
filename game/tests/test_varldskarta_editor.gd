## VÄRLDSKARTEDITORN (M121) — att DRA platserna på kartan med musen, SPARA dem och ÅNGRA.
##
## Alex: *"Kan vi skapa en world map editor istället, så jag kan flytta noderna själv?"* Provet mäter
## det han bad om, och bara det:
##
##   1. DRAGNINGEN FÖLJER PEKAREN, i två fönsterstorlekar (1280x720 och 1896x1018 — samma två som
##      `test_karta_full` mäter layouten i). En musdragning flyttar EN nod med exakt musens delta, och
##      ingen annan nod och inget annat fält rörs. En skalningsbugg här är exakt den sorten man märker
##      direkt med musen, så den mäts i två rutor och inte i en.
##   2. RUNDTUREN — spara, läs filen igen, samma x/y. Och en TEXTTDIFF mot originalet som visar att
##      BARA de två x/y-raderna ändrats: plats, sektion, nivåer och allt annat är byte-identiskt.
##   3. ÅNGRA — positionen före dragningen är tillbaka, exakt; en andra ångra säger ifrån.
##   4. SÄKERHETEN — skrivningen är ATOMISK (ingen `.tmp` kvar) och originalet läggs åt sidan EN gång.
##
## Provet rör ALDRIG `res://data/karta.json`: det läser originalet och skriver till en egen fil i
## `user://`. Grinden mot att spara över spelets egen data ligger i den regeln, inte i en kommentar.
##
##   godot --headless --script res://tests/test_varldskarta_editor.gd
##   (eller: tools/test.sh, som kör varje tests/test_*.gd)
extends SceneTree

var fails := 0
var checks := 0

const PROV := "user://prov_karta_editor.json"
const ORIGINAL := "res://data/karta.json"
const META_PROV := "user://prov_karta_editor_meta.json"
const VY_HÖJD := 270.0

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## Samma regel som `main.gd::_placera_vy` (och `test_karta_full.gd`): skalet har ingen remsa, så vyn
## är fönstret delat med den största hela skalan där 270 spelpixlar ryms på höjden.
func _vy_storlek(f: Vector2) -> Vector2:
	var skala := 1.0
	for k in range(1, 9):
		if float(k) * VY_HÖJD > f.y:
			break
		skala = float(k)
	return Vector2(clampf(floorf(f.x / skala), 160.0, 480.0 * 2.6), maxf(VY_HÖJD, floorf(f.y / skala)))

## Mus-händelserna spelet SJÄLVT tar emot. Musen läses i `_gui_input` (en Control med
## `MOUSE_FILTER_STOP` konsumerar den innan `_unhandled_input` ser den) — se skillen.
func _mus_tryck(på: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = på
	e.position = pos
	e.global_position = pos
	return e

func _mus_rörelse(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	return e

## Texten rad för rad: [[radnummer, originalrad, ny rad]] för varje rad som SKILJER.
func _raddiff(a: String, b: String) -> Array:
	var ra := a.split("\n")
	var rb := b.split("\n")
	var ut := []
	for i in mini(ra.size(), rb.size()):
		if ra[i] != rb[i]:
			ut.append([i, ra[i], rb[i]])
	if ra.size() != rb.size():
		ut.append([-1, "%d rader" % ra.size(), "%d rader" % rb.size()])
	return ut

## Nyckeln och talet ur en JSON-rad: `   "x": 54.0,` -> ["x", 54.0].
func _rad_tal(rad: String) -> Array:
	var del := rad.strip_edges().trim_suffix(",").split(":")
	if del.size() < 2:
		return ["?", 0.0]
	return [str(del[0]).strip_edges().replace("\"", ""), float(str(del[1]).strip_edges())]

## Färsk kopia av den riktiga kartan i user://, plus städning av det förra provets spår (en kvarglömd
## `.bak` skulle annars se ut som "backupen skrevs inte").
func _förbered_provfiler() -> bool:
	for p in [PROV, PROV + ".bak", PROV + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var text := FileAccess.get_file_as_string(ORIGINAL)
	if text.is_empty():
		return false
	var f := FileAccess.open(PROV, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true

func _init() -> void:
	Meta.fotolage(true)
	var stages := Stages.load_all()
	var order: Array = stages.keys()
	order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))
	var meta := Meta.load_or_new(META_PROV)
	var original_text := FileAccess.get_file_as_string(ORIGINAL)
	check(not original_text.is_empty(), "kartfilen går att läsa", ORIGINAL)
	check(_förbered_provfiler(), "en provkopia av kartan skrivs i user://", PROV)
	var karta := Karta.ladda(PROV)
	check(karta.fel.is_empty() and karta.antal() >= 10, "provkopian är en hel karta",
		"%d platser" % karta.antal())

	# --- 1) DRAGNINGEN FÖLJER PEKAREN, I TVÅ FÖNSTER ------------------------------------------------
	print("")
	print("— dragningen: en nod, exakt musens delta, i två fönster —")
	var vald := 0
	for fönst in [[1280, 720], [1896, 1018]]:
		var fönster := Vector2(fönst[0], fönst[1])
		var namn := "%dx%d" % [int(fönster.x), int(fönster.y)]
		var v := WorldMapView.new()
		v.karta = Karta.ladda(PROV)
		v.size = _vy_storlek(fönster)
		v.visa(stages, order, meta)
		v.editor = true
		v.gå_till(vald)
		v.steg_kamera(0.0, true)                 # kameran står still; ingen `_process` i ett prov
		var innan: Array = []
		for i in v.karta.antal():
			innan.append((v.karta.noder[i] as Dictionary).duplicate(true))
		var p0 := v.plats(vald)
		# MÅLET ligger på filens 0,1 %-rutnät. Då är avrundningen i `sätt_nod` ingen avrundning, och
		# det som mäts är TRANSFORMEN — inte den halva tiondelen.
		var mål_procent := v.karta.plats(vald) + Vector2(4.5, -5.5)
		var mål_bild := Vector2(mål_procent.x / 100.0 * Karta.BILD_BREDD,
			mål_procent.y / 100.0 * Karta.BILD_HÖJD)
		var mål_vy := v._vy_px(mål_bild)
		var mus_delta := mål_vy - p0
		# En RIKTIG dragning: ned på noden, rörelse, upp.
		v._gui_input(_mus_tryck(true, p0))
		check(v._drag == vald, "%s: greppet tar tag i noden under pekaren" % namn, "drag %d" % v._drag)
		v._gui_input(_mus_rörelse(mål_vy))
		v._gui_input(_mus_tryck(false, mål_vy))
		var p1 := v.plats(vald)
		var rörelse := p1 - p0
		check(v._drag == -1, "%s: släppet lämnar noden" % namn)
		check(absf(p1.x - mål_vy.x) < 0.001 and absf(p1.y - mål_vy.y) < 0.001,
			"%s: noden ligger UNDER pekaren efter dragningen" % namn,
			"%.3f, %.3f mot musen %.3f, %.3f" % [p1.x, p1.y, mål_vy.x, mål_vy.y])
		check(absf(rörelse.x - mus_delta.x) < 0.001 and absf(rörelse.y - mus_delta.y) < 0.001,
			"%s: nodens rörelse är EXAKT musens (dx, dy)" % namn,
			"mus %.3f, %.3f  nod %.3f, %.3f  rest %.4f, %.4f"
				% [mus_delta.x, mus_delta.y, rörelse.x, rörelse.y,
					rörelse.x - mus_delta.x, rörelse.y - mus_delta.y])
		check(absf(rörelse.x) > 10.0 and absf(rörelse.y) > 10.0, "%s: rörelsen är mätbar" % namn,
			"%.1f, %.1f px" % [rörelse.x, rörelse.y])
		check(v.karta.plats(vald) == Vector2(roundf(mål_procent.x * 10.0) / 10.0,
			roundf(mål_procent.y * 10.0) / 10.0),
			"%s: och x/y står på filens 0,1 %%-rutnät" % namn, str(v.karta.plats(vald)))
		# INGEN ANNAN NOD och INGET ANNAT FÄLT. Djup jämförelse av varje nods dict.
		var rörda := []
		var fältfel := []
		for i in v.karta.antal():
			var förr: Dictionary = innan[i]
			var nu: Dictionary = v.karta.noder[i]
			if str(förr) == str(nu):
				continue
			rörda.append(i)
			for nyckel in förr.keys():
				if str(förr[nyckel]) != str(nu[nyckel]):
					fältfel.append("%d:%s" % [i, nyckel])
		check(rörda == [vald], "%s: bara EN nod rörs" % namn, "rörda %s" % str(rörda))
		check(fältfel == ["%d:x" % vald, "%d:y" % vald] or fältfel == ["%d:y" % vald, "%d:x" % vald],
			"%s: och bara dess x och y (plats, sektion, nivåer orörda)" % namn, str(fältfel))

	# --- 1b) EN RÅ DELTA (sub-pixel): noden följer musen även mellan rutnätsstegen -------------------
	print("")
	print("— dragningen: en rå musdelta, inte bara rutnätet —")
	var v2 := WorldMapView.new()
	v2.karta = Karta.ladda(PROV)
	v2.size = _vy_storlek(Vector2(1280.0, 720.0))
	v2.visa(stages, order, meta)
	v2.editor = true
	v2.gå_till(vald)
	v2.steg_kamera(0.0, true)
	var q0 := v2.plats(vald)
	var delta := Vector2(64.0, -24.0)            # ett delta som INTE ligger på 0,1 %-rutnätet
	v2._gui_input(_mus_tryck(true, q0))
	v2._gui_input(_mus_rörelse(q0 + delta))
	var q1 := v2.plats(vald)
	var rest := (q1 - q0) - delta
	check(rest.length() < 0.5, "en rå (64, -24)-dragning flyttar noden inom en halv px",
		"rest %.3f, %.3f px" % [rest.x, rest.y])

	# --- 2) RUNDTUREN OCH TEXTTDIFFEN ---------------------------------------------------------------
	print("")
	print("— rundturen: spara, läs igen, och en textdiff mot originalet —")
	var r := WorldMapView.new()
	r.karta = Karta.ladda(PROV)
	r.size = _vy_storlek(Vector2(1280.0, 720.0))
	r.visa(stages, order, meta)
	r.editor = true
	r.gå_till(vald)
	r.steg_kamera(0.0, true)
	var från := r.karta.plats(vald)
	r.sätt_nod(vald, från + Vector2(7.5, 3.5))   # en flytt som ger nya TIOTAL i filen
	var till := r.karta.plats(vald)
	check(till != från, "noden flyttades", "%.1f, %.1f -> %.1f, %.1f" % [från.x, från.y, till.x, till.y])
	check(r.skriv_karta(), "S sparar kartan", r.sparad())
	check(not r.sparad().is_empty(), "och ger ett kvitto", r.sparad())
	# ATOMISKT: temp-filen är borta (bytet av namn gick igenom).
	check(not FileAccess.file_exists(PROV + ".tmp"), "ingen halvskriven .tmp ligger kvar (atomiskt byte)")
	# BACKUP: originalet läggs åt sidan, och det är ORIGINALET — inte en tidigare provkopia.
	check(FileAccess.file_exists(PROV + ".bak"), "originalet läggs åt sidan som .bak")
	check(FileAccess.get_file_as_string(PROV + ".bak") == original_text,
		"och .bak är BYTE-IDENTISK med originalet")
	var tillbaka := Karta.ladda(PROV)
	check(tillbaka.fel.is_empty(), "den sparade filen är felfri", ", ".join(tillbaka.fel))
	check(tillbaka.plats(vald) == till, "rundturen ger samma x/y",
		"%.1f, %.1f mot %.1f, %.1f" % [tillbaka.plats(vald).x, tillbaka.plats(vald).y, till.x, till.y])
	check(tillbaka.antal() == r.karta.antal(), "och alla %d platser är kvar" % r.karta.antal(),
		"%d" % tillbaka.antal())
	# TEXTTDIFFEN: exakt två rader skiljer, och de är nodens x och y.
	var sparad_text := FileAccess.get_file_as_string(PROV)
	var diff := _raddiff(original_text, sparad_text)
	check(diff.size() == 2, "textdiffen mot originalet är TVÅ rader", "%d rader skiljer" % diff.size())
	var nycklar := []
	var tal := {}
	for d in diff:
		var kt := _rad_tal(str(d[2]))            # den NYA raden: nyckeln OCH det nya talet
		tal[str(kt[0])] = float(kt[1])
	for k in tal.keys():
		nycklar.append(str(k))
	nycklar.sort()
	check(nycklar == ["x", "y"], "och de två raderna är nodens x och y", str(nycklar))
	check(absf(float(tal.get("x", -1000.0)) - till.x) < 0.001
		and absf(float(tal.get("y", -1000.0)) - till.y) < 0.001,
		"talet i filen är nodens nya x/y", "%s mot %s" % [str(tal), str(till)])
	check(original_text.split("\n").size() == sparad_text.split("\n").size(),
		"radantalet är oförändrat (ingen rad lades till eller togs bort)")

	# --- 3) ÅNGRA -----------------------------------------------------------------------------------
	print("")
	print("— ångra: tillbaka till positionen före dragningen —")
	var u := WorldMapView.new()
	u.karta = Karta.ladda(PROV)
	u.size = _vy_storlek(Vector2(1280.0, 720.0))
	u.visa(stages, order, meta)
	u.editor = true
	u.gå_till(vald)
	u.steg_kamera(0.0, true)
	var före := u.karta.plats(vald)
	check(not u.kan_ångra(), "inget att ångra innan man rört något")
	# En RIKTIG dragning, och sedan en riktig ångra ur samma tillstånd.
	var start := u.plats(vald)
	u._gui_input(_mus_tryck(true, start))
	u._gui_input(_mus_rörelse(start + Vector2(40.0, -20.0)))
	u._gui_input(_mus_tryck(false, start + Vector2(40.0, -20.0)))
	var efter := u.karta.plats(vald)
	check(efter != före, "en dragning flyttade noden", "%.1f, %.1f -> %.1f, %.1f"
		% [före.x, före.y, efter.x, efter.y])
	check(u.kan_ångra(), "och det finns något att ångra")
	check(u.ångra(), "ångra lägger tillbaka den")
	check(u.karta.plats(vald) == före, "positionen är EXAKT den före dragningen",
		"%.1f, %.1f mot %.1f, %.1f" % [u.karta.plats(vald).x, u.karta.plats(vald).y, före.x, före.y])
	check(u.valt_index() == vald, "och noden blev den valda (man ser vilken som flyttades tillbaka)")
	check(not u.kan_ångra(), "en andra ångra har inget att ta")
	check(not u.ångra(), "och den svarar ifrån i stället för att göra något tyst")
	# Finjusteringen (piltangenterna) går samma väg: ett tryck, och sedan tillbaka exakt.
	u.gå_till(vald)
	var nud_starth := u.karta.plats(vald)
	u.nudga(Vector2i(1, 0))
	var nud_efter := u.karta.plats(vald)
	check(nud_efter != nud_starth, "pilen flyttar noden ett steg", "%.1f -> %.1f"
		% [nud_starth.x, nud_efter.x])
	check(u.ångra() and u.karta.plats(vald) == nud_starth,
		"och ångra lägger tillbaka finjusteringen EXAKT")

	# --- 4) BACKUPEN RÖRS INTE AV EN SENARE SPARNING -------------------------------------------------
	print("")
	print("— backupen: originalet tryggas EN gång —")
	var bak_innan := FileAccess.get_file_as_string(PROV + ".bak")
	r.sätt_nod(vald, r.karta.plats(vald) + Vector2(1.0, 1.0))
	check(r.skriv_karta(), "ännu en sparning går igenom")
	check(FileAccess.get_file_as_string(PROV + ".bak") == bak_innan,
		"och .bak står kvar som originalet (ingen andra backup skriver över den)")

	# Städa: provet lämnar inte sina filer efter sig.
	for p in [PROV, PROV + ".bak", PROV + ".tmp", META_PROV]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
