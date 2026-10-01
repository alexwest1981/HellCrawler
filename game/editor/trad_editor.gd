## The tree editor: place the tree's nodes by hand and save them (M95).
##
##   tools/trad_editor.sh          (or the TRADEDITOR line in the start menu)
##
## WHY: the sockets in the plate image are not on a grid, and none of the measurements I made (a
## grid overlay, two of my own detectors, cv2's Hough, snapping each node to the nearest pit) hit all
## of them. Alex: "can you make an editor for just the skill tree, where I can place all the nodes by
## hand instead?" This is that, and it ends the guessing: a human eye on the plate beats any filter I
## write.
##
## THE SURFACE IS THE TREE VIEW. The editor builds the same TreeView the game shows and puts one
## layer on top of it, so the plate, the orbs, the socket rings and the scaling are exactly what gets
## played. What differs is the mouse (drag a node) and the keys (S saves the same file the view reads).
##
## Keys, also listed in the side panel: click or drag = move, arrow keys = nudge, + = add a node
## (under and in the branch of the selected one), L = node size (stor, medelstor, liten, pytteliten),
## G = next icon (the branch's own, eld, is, magi), 1-9 = tick an upgrade and give it 1-3 steps,
## SHIFT + drag between two nodes = draw which node the second one waits for, C = clear that node's
## links, X = remove a node you added, T = next node, R = reset to the measured guess, S = save,
## M = menu, ESC or Q = quit.
##
## NODES YOU ADD LIVE IN THE SOCKET FILE, not in data/tree.json (that one is generated and would eat
## them on the next run). The record carries the whole definition — branch, tier, icon, size, effects,
## what it waits for — and Meta makes it a real node when it reads the tree. Alex: "can I add nodes as
## needed, or have you locked something? ... I want to press + on a node, put graphics on them (fire,
## ice, magic), pick a size and tick what goes up and by how much."
##
## THE LINKS ARE A DEVELOPMENT TOOL ONLY. They are drawn in the editor and nowhere else — the game
## keeps painting its own rods — but they are what the game LIVES by: the link is written as the
## node's `requires`, so the drawn order is the order the tree unlocks in. Alex: "can you make it so
## you drag a link between nodes, in the order they have to be unlocked? They should not be visible
## afterwards, only for development's sake."
##
## TWO KINDS OF NODE, TWO KINDS OF PIT. The plate has small pits (radius 0.009, measured) and three
## large medallions (0.018). L picks which one the node is aimed at, and the ticked upgrades are worth
## half as much on a small node — Alex: "it has to be possible to have small nodes too ... they should
## contribute small increments. I need the editor to pick small or large node as the graphical target,
## and then to tick which upgrades they do." The ticks and the class are written into the socket file
## (TreeSockets), and Meta folds them into the node's effects when it loads the tree.
##
## The save is the whole point, so it is written through TreeSockets (one home for the format) and it
## says in the panel how many nodes were written and to where. A save that says nothing is
## indistinguishable from a broken key.
extends Control

const PANEL_WIDTH := 232.0
const STEP := 0.002                    ## one arrow-key nudge, in image fractions
const GRAB_PIXELS := 22.0              ## how close the pointer has to be to grab a node

var view: TreeView
var overlay: Overlay
var meta: Meta
var ids: Array = []                    ## every tree node id, in placement order
var records: Dictionary = {}           ## id -> the record that will be written
var selected := ""
var dragging := false
var status := ""
var effekt_ytor: Dictionary = {}       ## typ -> Rect2, så panelens rader går att klicka
var genererade: Dictionary = {}        ## id -> true för de 63 noderna ur data/tree.json
var rensa_knapp: Rect2 = Rect2()       ## panelens knapp: rensa ALLA kopplingar
var rensa_väntar: int = 0              ## tidsstämpel för första trycket (0 = ingen väntan)
var alla_defs: Array = []              ## metans defs som de var vid start (originalet att bygga om ur)
var link_from := ""                    ## noden en koppling dras FRÅN (shift+drag), "" annars
var link_pekar := Vector2.ZERO         ## pekarens läge, till gummibandet medan man drar
var panning := false                   ## höger (eller mitten) nere: utsnittet panoreras (M96)


## The layer above the view: it takes the mouse (so a click selects instead of buying) and draws both
## the marker and the panel. A Control's own _draw ends up UNDER its children — measured twice
## tonight — so the editor's drawing lives here, in the topmost node.
class Overlay:
	extends Control

	var editor: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		if editor != null:
			editor.draw_overlay(self)

	func _gui_input(event: InputEvent) -> void:
		if editor != null:
			editor.mouse_event(event)


func _ready() -> void:
	# Photo mode: the editor must never touch Alex' save file. It reads the tree for the node ids and
	# the ranks, and the ranks are shown in the panel — the save itself has no business here.
	Meta.fotolage(true)
	meta = Meta.load_or_new()

	view = TreeView.new()
	view.position = Vector2.ZERO
	view.size = Vector2(maxf(320.0, size.x - PANEL_WIDTH), size.y)
	add_child(view)
	view.visa(meta, "TRADEDITOR")

	overlay = Overlay.new()
	overlay.editor = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	for id in view.nod_ids():
		# Nodlistan kommer från VYN, inte från metan: vyn ritar exakt de noder som har en gren, och en
		# lista ur metan tog med åtta id som inte har någon nod i TRÄDET (eller, före M97, ingen socket
		# på plattan). Markören hamnade då i hörnet (mätt: noden "might", x -25 %) och "T nästa nod"
		# vandrade in i noder som inte finns i trädet. Ett hem för frågan "vilka noder finns i trädet".
		ids.append(str(id))
	for id in ids:
		genererade[str(id)] = true
	alla_defs = meta.defs.duplicate(true)
	records = TreeSockets.load_all()
	# Poster som inte längre är noder i spelet (gravstenar och experiment man glömt) skall ändå gå att
	# välja och städa bort — de ritas som en röd markör i stället för en ikon.
	for id in records:
		if not ids.has(str(id)):
			ids.append(str(id))
	for id in ids:
		if not records.has(id):
			# En nod filen inte känner: ingen egen plats och ingen egen klass — rutnätet och nivån ger
			# dem. Bara det en människa ändrar skrivs till filen.
			records[id] = TreeSockets.blank(str(id))
		var post: Dictionary = records[id]
		# KEDJAN VISAS SOM DEN ÄR. Noden har krav ur generatorn; editorn visar dem (så ordningen syns
		# och går att ändra) och skriver dem först när du sparar — från och med då äger filen ordningen.
		if not post.has("requires"):
			post["requires"] = meta.def_for(str(id)).get("requires", []).duplicate()
		if not post.has("effects"):
			post["effects"] = {}
		records[id] = post
	if not ids.is_empty():
		selected = str(ids[0])
	status = "%d nodes, %d in the file" % [ids.size(), TreeSockets.load_all().size()]

	# Skärmbildsläge, samma mönster som baneditorn: fotografera ytan och avsluta, så editorn kan
	# granskas på bild utan att någon sitter framför den (och utan att ett fönster dyker upp).
	if OS.get_cmdline_user_args().has("shot"):
		_shot()


func _shot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var bild := get_viewport().get_texture().get_image()
	bild.save_png("user://trad_editor.png")
	print("trad_editor.png: %s" % ProjectSettings.globalize_path("user://trad_editor.png"))
	get_tree().quit()


func draw_overlay(du: CanvasItem) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	# The marker: a box around the selected node, a cross at its centre, and a fine crosshair grid
	# over the whole plate so a position can be read off by eye.
	if records.has(selected) and view != null:
		var record: Dictionary = records[selected]
		var point: Vector2 = view.nod_punkt(selected)
		du.draw_line(Vector2(0, point.y), Vector2(view.size.x, point.y), Color(0.3, 0.9, 0.4, 0.25), 1.0)
		du.draw_line(Vector2(point.x, 0), Vector2(point.x, view.size.y), Color(0.3, 0.9, 0.4, 0.25), 1.0)
		du.draw_rect(Rect2(point - Vector2(16, 16), Vector2(32, 32)), Color(0.95, 0.85, 0.3), false, 2.0)
		if not view._ikoner.has(selected):
			# Ingen ikon: borttagen (gravsten) eller en post utan definition. Ett rött kryss säger
			# både var den låg och att den inte finns i spelet just nu.
			var kryss: Color = Color(0.95, 0.35, 0.3, 0.9)
			du.draw_line(point - Vector2(10, 10), point + Vector2(10, 10), kryss, 2.0)
			du.draw_line(point - Vector2(10, -10), point + Vector2(10, -10), kryss, 2.0)
		du.draw_line(point - Vector2(9, 0), point + Vector2(9, 0), Color(0.95, 0.4, 0.3), 1.0)
		du.draw_line(point - Vector2(0, 9), point + Vector2(0, 9), Color(0.95, 0.4, 0.3), 1.0)

	# KOPPLINGARNA. Tunna, mörka linjer för hela trädet (det är så man ser ordningen man byggt) och
	# gröna för den valda noden. De finns bara här: spelet ritar sina egna rör och vet inget om dem.
	for id in records:
		var post: Dictionary = records[id]
		var till: Vector2 = view.nod_punkt(str(id))
		for krav in post.get("requires", []):
			if not records.has(str(krav)):
				continue
			var från: Vector2 = view.nod_punkt(str(krav))
			var vald: bool = str(id) == selected or str(krav) == selected
			du.draw_line(från, till, Color(0.35, 0.95, 0.45, 0.85) if vald else Color(0.1, 0.1, 0.14, 0.55),
				2.0 if vald else 1.0)
			if vald:
				du.draw_circle(till, 3.0, Color(0.35, 0.95, 0.45, 0.8))
	if not link_from.is_empty():
		du.draw_line(view.nod_punkt(link_from), link_pekar, Color(0.95, 0.8, 0.3, 0.9), 2.0)
		du.draw_circle(link_pekar, 4.0, Color(0.95, 0.8, 0.3, 0.9))

	var x := view.size.x + 8.0
	var y := 18.0
	du.draw_string(font, Vector2(x, y), "TRADEDITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.95, 0.9, 0.7))
	y += 16.0
	if records.has(selected):
		var record: Dictionary = records[selected]
		# NODENS EGENSKAPER KOMMER UR DATAT (tree.json), inte ur socketposten: posten bär bara det en
		# människa lagt till (kryss, krav, klass, ikon, pin). Det var därför panelen visade "branch: -"
		# och en tom ikonrad för varje genererad nod.
		var def: Dictionary = meta.def_for(selected)
		var nivå: int = _nivå(selected)
		var klass: String = TreeSockets.size_of(record, nivå)
		var gren: String = str(def.get("branch", record.get("branch", "-")))
		var ikon: String = TreeSockets.graphics_of(record, str(view.FILNAMN.get(gren, "")))
		var plats: String
		if TreeSockets.pinned(record):
			plats = "x %.1f %%   y %.1f %%   (pinned by hand)" % [
				float(record["x"]) * 100.0, float(record["y"]) * 100.0]
		else:
			plats = "in the lattice: %s, tier %d" % [gren, nivå]
		var lines := [
			"node: %s   (%s)" % [selected, str(def.get("name", "?"))],
			plats,
			"node size: %s (r %.1f %%, %d px in the game view)" % [klass,
				TreeSockets.radius_of(record, nivå) * 100.0,
				TreeSockets.size_px(TreeSockets.radius_of(record, nivå), 270.0, 270.0)],
			"state: %s" % ("REMOVED (X brings it back)" if TreeSockets.is_removed(record)
				else ("yours (+)" if not genererade.has(selected) else "from tree.json")),
			"icon: %s" % (ikon if not ikon.is_empty() else "-"),
			"branch: %s" % gren,
			"ticks: %s" % TreeSockets.ticks_text(record, nivå),
			"waits for: %s" % (", ".join(PackedStringArray(record.get("requires", []))) if not record.get("requires", []).is_empty() else "-"),
			"tier %d, rank %d/%d" % [
				nivå, meta.rank(selected), int(meta.def_for(selected).get("max_rank", 1))],
			"",
			"click / drag  move",
			"arrows        nudge",
			"wheel         zoom",
			"right-drag    pan",
			"F             fit the whole tree",
			"+             add a node here",
			"L             node size (4 steps)",
			"G             next icon (%d in assets/tree)" % TreeSockets.icon_list().size(),
			"1-9 / click   tick upgrade, x1-x3 (again = next step)",
			"X             remove / bring back",
			"SHIFT + drag  draw a link",
			"C             clear this node's links",
			"T             next node",
			"R             back to the lattice",
			"S             SAVE",
			"M             menu",
			"ESC / Q       quit",
			"",
			"UPGRADES (%s node, x1-x3 steps)" % klass,
		]
		for line in lines:
			du.draw_string(font, Vector2(x, y), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.86, 0.86, 0.9))
			y += 13.0
		# Kryssraderna. Ytan för varje rad sparas, så ett klick vet vad det träffade — panelen är ett
		# formulär, och en rad som ser klickbar ut men inte är det är värre än ingen rad.
		effekt_ytor.clear()
		for typ in TreeSockets.VALUES:
			var rad := Rect2(x, y - 11.0, PANEL_WIDTH - 16.0, 13.0)
			var steg: int = TreeSockets.step_of(record, typ)
			var på: bool = steg > 0
			du.draw_rect(rad, Color(0.2, 0.5, 0.3, 0.35) if på else Color(0.2, 0.2, 0.25, 0.35), true)
			# STEGEN SYNS SOM RUTOR. Alex: "någon indikation på att tick upgrade har körts, så man vet hur
			# många gånger något är uppgraderingsbart." Tre rutor per kryss — fyllda = antalet steg — och
			# värdet till höger är stegens sammanlagda värde, ur samma tabell som spelet räknar med.
			var rutor := ""
			for i in TreeSockets.STEPS_MAX:
				rutor += "■" if i < steg else "□"
			du.draw_string(font, Vector2(x + 4.0, y), "%s %s %s (%s)" % [
				"[x]" if på else "[ ]", str(TreeSockets.WORDS.get(typ, typ)), rutor,
				TreeSockets.effect_preview(typ, klass, maxi(1, steg))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.95, 0.95, 0.85) if på else Color(0.7, 0.7, 0.75))
			effekt_ytor[typ] = rad
			y += 13.0
		# RENSA ALLA KOPPLINGAR. Två tryck: Alex' egen regel från anslutningspanelen ("Koppla från
		# kräver två tryck"), och här behövs den - ett enda klick raderar ordningen för hela trädet.
		y += 6.0
		rensa_knapp = Rect2(x, y, PANEL_WIDTH - 18.0, 18.0)
		du.draw_rect(rensa_knapp, Color(0.62, 0.24, 0.22, 0.75) if rensa_väntar
			else Color(0.26, 0.24, 0.3, 0.6), true)
		du.draw_rect(rensa_knapp, Color(0.85, 0.5, 0.45, 0.9) if rensa_väntar
			else Color(0.5, 0.5, 0.55, 0.8), false, 1.0)
		du.draw_string(font, Vector2(x + 5.0, y + 13.0),
			"PRESS AGAIN: clear ALL links" if rensa_väntar else "CLEAR ALL LINKS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1.0, 0.95, 0.9) if rensa_väntar else Color(0.88, 0.88, 0.92))
		y += 22.0
	du.draw_string(font, Vector2(x, size.y - 10.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.6, 0.95, 0.7))


## Which node is under the pointer, or "" when none is close enough.
func node_at(point: Vector2) -> String:
	var best := ""
	var best_distance := GRAB_PIXELS
	for id in ids:
		var distance: float = (view.nod_punkt(str(id)) - point).length()
		if distance < best_distance:
			best_distance = distance
			best = str(id)
	return best


## Vyns egna grepp (M96): overlayn tar VARJE musehändelse, så vyn får aldrig se dem — hjul och
## högerdrag skickas vidare till den i stället för att dubbleras här. Returnerar true när händelsen
## var vyns.
func view_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var knapp := event as InputEventMouseButton
		if knapp.button_index == MOUSE_BUTTON_WHEEL_UP and knapp.pressed:
			view.zooma(knapp.position, 1.15)
			return true
		if knapp.button_index == MOUSE_BUTTON_WHEEL_DOWN and knapp.pressed:
			view.zooma(knapp.position, 1.0 / 1.15)
			return true
		if knapp.button_index == MOUSE_BUTTON_RIGHT or knapp.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = false
			panning = knapp.pressed
			return true
	elif event is InputEventMouseMotion and panning:
		view.panorera((event as InputEventMouseMotion).relative)
		return true
	return false


func mouse_event(event: InputEvent) -> void:
	# Vyn slutar rätta sig själv så snart någon rör den: den som valt ett utsnitt skall behålla det.
	# (F visar hela trädet igen, och visa() centrerar bara ett orört träd.)
	view._rörd = true
	if view_gesture(event):
		overlay.queue_redraw()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			# SHIFT + drag ritar en koppling i stället för att flytta: draget börjar på noden som
			# skall vara FÖRST, och släpps på noden som skall vänta på den.
			if button.shift_pressed:
				dragging = false
				if button.pressed:
					link_from = node_at(button.position)
					link_pekar = button.position
					if link_from.is_empty():
						status = "shift + drag FROM the node that comes first"
				else:
					var till := node_at(button.position)
					if not link_from.is_empty() and not till.is_empty():
						toggle_requirement(link_from, till)
					link_from = ""
				overlay.queue_redraw()
				return
			dragging = button.pressed
			if button.pressed:
				# Ett klick i panelen är ett kryss, aldrig en förflyttning: noderna bor till vänster
				# om panelen, så en träff här kan bara vara en rad.
				if button.position.x >= view.size.x:
					dragging = false
					for typ in effekt_ytor:
						if (effekt_ytor[typ] as Rect2).has_point(button.position):
							toggle_upgrade(str(typ))
					if rensa_knapp.has_point(button.position):
						clear_all_requirements()
					return
				var hit := node_at(button.position)
				if not hit.is_empty():
					selected = hit
				else:
					# A click on bare stone still moves the SELECTED node there: on a sparse plate
					# that is faster than dragging it across an empty half.
					place_at(button.position)
				overlay.queue_redraw()
	elif event is InputEventMouseMotion:
		if dragging:
			place_at((event as InputEventMouseMotion).position)
		elif not link_from.is_empty():
			link_pekar = (event as InputEventMouseMotion).position
			overlay.queue_redraw()


## Put the selected node where the pointer is, in the tree's own coordinates.
func place_at(point: Vector2) -> void:
	if selected.is_empty():
		return
	var frac: Vector2 = view.till_bild(point)
	# ÄNDRA POSTEN, BYGG INTE EN NY. Första versionen skrev en fräsch ordbok med bara id/x/y/r, och då
	# tappade varje drag nodens `added`, `size`, `effects`, `requires` och namn — mätt i Alex' fil:
	# tolv noder han lagt till med + hade ingen definition kvar, och storleken han valt försvann så
	# fort han rörde noden. Det var därför de inte gick att ta bort eller storleksändra.
	var post: Dictionary = records.get(selected, {})
	post["id"] = selected
	post["x"] = frac.x
	post["y"] = frac.y
	post["r"] = float(post.get("r", 0.018))
	post["score"] = float(post.get("score", 0.0))
	post["guess_x"] = float(post.get("guess_x", frac.x))
	post["guess_y"] = float(post.get("guess_y", frac.y))
	records[selected] = post
	apply()
	overlay.queue_redraw()


## Nivån (tier) för en nod. Datat äger den, vyn vet den. Behövs för klassens trappa: en nod långt ned
## i en gren är en liten nod, och ett kryss på den ger den lilla nodens steg (M97).
func _nivå(id: String) -> int:
	var n: int = int(meta.def_for(id).get("tier", 0))
	if n > 0:
		return n
	return int(view._rader.get(id, {}).get("nivå", 1))


## Push the record into the view and redraw it. One place: the editor never moves an icon itself.
func apply() -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	var nivå: int = _nivå(selected)
	# EN FLYTTAD NOD PINNAS (M97): rutnätet lägger alla andra, men den du dragit skall ligga kvar där du
	# lade den. Utan märket hade vyn lagt tillbaka den i rutnätet, och draget sett ut att inte ha gjort
	# något alls nästa gång trädet byggdes om.
	if record.has("x") and record.has("y"):
		record["pin"] = true
		view.flytta(selected, float(record["x"]), float(record["y"]))
	view.sätt_radie(selected, TreeSockets.radius_of(record, nivå), TreeSockets.size_of(record, nivå))
	view.rita_om()


func step_selected(dx: float, dy: float) -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	# ETT DRAG MED PILTANGENTERNA ÄR ETT DRAG (M97): noden får sin egen plats OCH pin-märket, annars
	# lägger rutnätet tillbaka den och tangenten ser död ut — posten flyttades, men det syntes ingenstans.
	# En nod som ännu följer rutnätet har ingen egen plats: då TAS den över från där den står, så en
	# pilknapp flyttar noden i stället för att kasta den till hörnet.
	if not record.has("x"):
		var frac: Vector2 = view.till_bild(view.nod_punkt(selected))
		record["x"] = frac.x
		record["y"] = frac.y
	# KLÄMMAN ÄR RYMDEN, INTE PLATTAN (M96): trädet växer förbi bildens kant, så en nod skall kunna
	# flyttas dit den hör. Gränsen står kvar som skydd mot en tangent som far iväg av misstag.
	record["x"] = clampf(float(record["x"]) + dx, -3.0, 6.0)
	record["y"] = clampf(float(record["y"]) + dy, -3.0, 12.0)
	record["pin"] = true
	records[selected] = record
	apply()
	overlay.queue_redraw()


## Nästa nodstorlek (L). Trappan är fyra klasser, och klassen är det som ritas — radien räknas ur den,
## så inget annat behöver uppdateras här.
func toggle_size() -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	var nivå: int = _nivå(selected)
	record["size"] = TreeSockets.next_size(TreeSockets.size_of(record, nivå))
	record.erase("r")        # radien är klassens, inte postens: en kvarvarande r skulle vinna
	records[selected] = record
	status = "%s is now a %s node (%s, %d px in the game view)" % [selected, record["size"],
		"nivå %d" % nivå, TreeSockets.size_px(TreeSockets.radius_of(record, nivå), 270.0, 270.0)]
	apply()
	overlay.queue_redraw()


## Kryssa uppgraderingar. Ett kryss per typ; värdet följer storleken och räknas fram i TreeSockets,
## så panelen och spelet visar samma siffra. Spara (S) skriver dem till socketfilen.
func toggle_upgrade(typ: String) -> void:
	if not records.has(selected) or not TreeSockets.VALUES.has(typ):
		return
	# ETT KRYSS LANDAR I EN NOD SOM OFTAST INTE HAR NÅGON effects-NYCKEL ÄN. Vakten frågade efter
	# "är effekten en Dictionary?" — men .get() med en standard ger just en tom Dictionary, så svaret
	# var alltid ja, raden `record["effects"]` kastade, och siffrorna 1-9 gjorde ingenting alls på en
	# genererad nod (mätt i provet: steg 0, 0, 0). Frågan skall vara om NYCKELN finns.
	var record: Dictionary = records[selected]
	if not (record.get("effects") is Dictionary):
		record["effects"] = {}
	var effekt: Dictionary = record["effects"]
	# Varvet: av -> x1 -> x2 -> x3 -> av. Ett kryss per klick, och "hur mycket" är samma knapp - Alex:
	# "bocka i vad som skall ökas, och hur mycket".
	var steg: int = (TreeSockets.step_of(record, typ) + 1) % (TreeSockets.STEPS_MAX + 1)
	if steg == 0:
		effekt.erase(typ)
	else:
		effekt[typ] = steg
	record["effects"] = effekt
	records[selected] = record
	var text: String = TreeSockets.text_of(record, _nivå(selected))
	status = "%s: %s" % [selected, text if not text.is_empty() else "no upgrades ticked"]
	overlay.queue_redraw()


## Dra/ångra en koppling: `till` skall vänta på `från`. Ett drag mellan två noder som redan hänger
## ihop tar bort kopplingen, så samma gest gör båda.
func toggle_requirement(från: String, till: String) -> void:
	if från == till or not records.has(från) or not records.has(till):
		return
	var post: Dictionary = records[till]
	# FÖRSTA DRAGET LÄGGER TILL, det ersätter inte: en nod som redan väntar på något (ur generatorn)
	# behåller sin kedja och får den nya kopplingen ovanpå. Utan det här tappade ett drag tyst den
	# ordning som redan fanns — och ringkontrollen kunde inte se den.
	if not post.has("requires"):
		post["requires"] = meta.def_for(till).get("requires", []).duplicate()
	var lista: Array = post["requires"]
	if lista.has(från):
		lista.erase(från)
		status = "%s no longer waits for %s" % [till, från]
	elif skulle_låsa(från, till):
		# En ring skulle låsa BÅDA noderna för alltid (ingen av dem går att köpa). Vägras med besked.
		status = "REFUSED: %s already waits for %s (a ring locks both)" % [från, till]
		overlay.queue_redraw()
		return
	else:
		lista.append(från)
		status = "%s waits for %s" % [till, från]
	post["requires"] = lista
	records[till] = post
	apply()
	_skriv_krav(till, lista)
	overlay.queue_redraw()


## Skulle `från` hamna efter `till` om kopplingen drogs? Gå uppåt från `från` och se om `till` finns.
## ponytail: enkel kedjegång, räcker för ett träd som ritats för hand; byt mot topologisk sortering om
## trädet någonsin blir stort nog att gången märks.
func skulle_låsa(från: String, till: String) -> bool:
	var kö: Array = [från]
	var sedda: Dictionary = {}
	while not kö.is_empty():
		var id: String = str(kö.pop_back())
		if id == till:
			return true
		if sedda.has(id):
			continue
		sedda[id] = true
		# Gå efter METANS kedja, inte bara editorns egna länkar: nodens genererade krav ingår också,
		# och en ring genom dem låser lika hårt. toggle_requirement håller metans def uppdaterad, så
		# nästa kontroll ser den nya länken.
		for krav in meta.def_for(id).get("requires", []):
			kö.append(str(krav))
	return false


## EN plats som skriver en nods krav: posten i filen OCH definitionen metan läser. Utan det andra
## halvan fortsätter låset — och linjen — som om ingenting hänt. Det var precis hur C såg ut: posten
## tömdes, metan behöll kravet, och kopplingen stod kvar på skärmen. Alex: "det går inte att ta bort hur
## någon nod är kopplad, C gör inget alls."
func _skriv_krav(id: String, lista: Array) -> void:
	if not records.has(id):
		return
	var post: Dictionary = records[id]
	post["requires"] = lista
	records[id] = post
	var def: Dictionary = meta.def_for(id)
	if not def.is_empty():
		def["requires"] = lista
	view.uppdatera()          # låsen ritas om: kopplingen är spelets regel, inte bara en linje
	view.rita_om()            # och vyn ritar sina linjer ur samma krav


## Rensa den valda nodens kopplingar (C). Går genom samma skrivväg som ett drag — se _skriv_krav.
func clear_requirements() -> void:
	if not records.has(selected):
		return
	_skriv_krav(selected, [])
	status = "%s waits for nothing" % selected
	overlay.queue_redraw()


## LÄGG TILL EN NOD (+). Den hamnar i den valda nodens gren, ett steg under den och med den som krav —
## det är så trädet byggs: Stor -> Medelstor -> Liten -> Pytteliten. Id:t följer grenens egen serie
## (iron_main -> iron_21), så nya och genererade noder hör ihop utan en tabell någonstans.
func add_node() -> void:
	if selected.is_empty() or not view._rader.has(selected):
		status = "select a node first: the new one joins its branch"
		overlay.queue_redraw()
		return
	var rad: Dictionary = view._rader[selected]
	var gren := str(rad.get("gren", ""))
	var förälder_id: String = selected
	var rot: String = selected.trim_suffix(selected.split("_")[-1])
	var högst := 0
	for id in records:
		var namn := str(id)
		if namn.begins_with(rot):
			högst = maxi(högst, int(namn.trim_prefix(rot)) if namn.trim_prefix(rot).is_valid_int() else 0)
	var nytt := "%s%d" % [rot, högst + 1]
	var ikon: String = str(view.FILNAMN.get(gren, "jarnvagen"))
	# Nya noden hamnar ett steg UNDER den valda, i samma gren och med den som krav — rutnätet ger den
	# platsen (ingen pin), så den syns direkt i kolumnen under sin förälder. Det är så trädet växer:
	# peka vidare, en nod i taget, utan att röra koden.
	var post: Dictionary = TreeSockets.added_node(nytt, gren, int(rad.get("nivå", 1)) + 1, ikon, "liten", [selected])
	records[nytt] = post
	ids.append(nytt)
	selected = nytt
	# Noden in i metan och vyn: den skall synas direkt, inte först efter en omstart.
	meta.defs.append(TreeSockets.def_of(post))
	view.visa(meta, "TRADEDITOR", false)
	status = "added %s (%s, %s) - it waits for %s" % [nytt, post["name"], post["size"], förälder_id]
	overlay.queue_redraw()


## TA BORT EN NOD (X), och sätt tillbaka den med samma tangent.
##
## En nod du lagt till själv (+) försvinner ur filen. En GENERERAD nod (någon av de 63 ur
## data/tree.json) får en GRAVSTEN i stället: posten ligger kvar med "removed": true, och metan
## hoppar över den. Utan gravstenen hade generatorn skapat noden igen vid nästa körning, och "bort"
## hade betytt "tillbaka" — Alex: "jag kan inte ta bort de överflödiga".
func remove_added() -> void:
	if selected.is_empty() or not records.has(selected):
		return
	var post: Dictionary = records[selected]
	if genererade.has(selected):
		post["removed"] = not bool(post.get("removed", false))
		status = "%s %s" % [selected, "removed" if post["removed"] else "back in the tree"]
		records[selected] = post
	else:
		status = "removed %s (it was one of yours)" % selected
		records.erase(selected)
		ids.erase(selected)
		if view._ikoner.has(selected):
			var ikon: Node = view._ikoner[selected]
			ikon.queue_free()
			view._ikoner.erase(selected)
			view._rader.erase(selected)
	# Metan byggs om ur ORIGINALET (en kopia som togs vid start), inte ur filen: en gravsten är en
	# ändring i vilka noder som finns, och den skall synas i vyn DIREKT — inte först när man sparat.
	# Läste man filen här kom den borttagna noden tillbaka i vyn, såg ut som om X inte gjorde något. Editorns egen lista behåller också borttagna id, annars gick de inte att sätta tillbaka.
	_bygg_meta()
	ids.clear()
	for id in view.nod_ids():
		ids.append(str(id))
	for id in records:
		if not ids.has(str(id)):
			ids.append(str(id))
	if records.has(selected) and not genererade.has(selected):
		selected = str(ids[0]) if not ids.is_empty() else ""
	view.visa(meta, "TRADEDITOR", false)
	overlay.queue_redraw()


## Trädet som det ser ut NU: originalen (sparade vid start) minus gravstenar, plus egna noder.
func _bygg_meta() -> void:
	var ut: Array = []
	for d in alla_defs:
		var post: Dictionary = records.get(str(d.get("id", "")), {})
		if TreeSockets.is_removed(post):
			continue
		var kopia: Dictionary = (d as Dictionary).duplicate(true)
		var effekt: Dictionary = TreeSockets.effect_of(post)
		if not effekt.is_empty():
			kopia["effect"] = effekt
			kopia["text"] = TreeSockets.text_of(post)
		if not str(post.get("graphics", "")).is_empty():
			kopia["graphics"] = post["graphics"]
		if post.has("requires"):
			kopia["requires"] = post["requires"]
		ut.append(kopia)
	for id in records:
		var post: Dictionary = records[id]
		if not bool(post.get("added", false)) or TreeSockets.is_removed(post):
			continue
		if not ut.any(func(d): return str(d.get("id", "")) == str(id)):
			ut.append(TreeSockets.def_of(post))
	meta.defs = ut


## Nästa grafik: grenens egen ikon först, sedan eld, is, magi.
func next_graphics() -> void:
	if not records.has(selected):
		return
	var post: Dictionary = records[selected]
	# Grenens egen ikon först (den är nodens förval), sedan ALLA filer i assets/tree — lägger du dit en
	# egen PNG finns den här utan att någon kod ändras.
	var förval: String = str(view.FILNAMN.get(str(post.get("branch", "")), "jarnvagen"))
	var val: Array = [förval]
	for namn in TreeSockets.icon_list():
		if str(namn) != förval:
			val.append(str(namn))
	if val.is_empty():
		return
	var nu: int = val.find(TreeSockets.graphics_of(post, förval))
	post["graphics"] = str(val[(nu + 1) % val.size()])
	records[selected] = post
	for d in meta.defs:
		if str(d.get("id", "")) == selected:
			d["graphics"] = post["graphics"]
	status = "%s gets the %s icon  (%d icons in %s)" % [
		selected, post["graphics"], val.size(), TreeSockets.ICON_DIR]
	view.visa(meta, "TRADEDITOR", false)
	overlay.queue_redraw()


## RENSA ALLA KOPPLINGAR (panelens knapp). Första trycket armar, andra trycket inom fyra sekunder
## rensar - samma tvåtrycksregel som anslutningspanelen i GodJIRA använder. Ett enda klick som raderar
## låsordningen för hela trädet är för lätt att göra av misstag.
func clear_all_requirements() -> void:
	var nu := Time.get_ticks_msec()
	if rensa_väntar == 0 or nu - rensa_väntar > 4000:
		rensa_väntar = nu
		status = "press CLEAR ALL LINKS again within 4 s"
		overlay.queue_redraw()
		return
	var antal := 0
	for id in records:
		var post: Dictionary = records[id]
		if not (post.get("requires", []) as Array).is_empty():
			antal += 1
		post["requires"] = []
		records[id] = post
	rensa_väntar = 0
	_bygg_meta()
	view.uppdatera()
	status = "cleared the links on %d nodes - draw the order again" % antal
	overlay.queue_redraw()


func next_node() -> void:
	if ids.is_empty():
		return
	var index: int = ids.find(selected)
	selected = str(ids[(index + 1) % ids.size()])
	overlay.queue_redraw()


## R: släpp noden tillbaka till rutnätet. Den gamla betydelsen ("tillbaka till den mätta gissningen")
## hörde till plattan, och den finns inte längre (M97) — nu betyder R "följ rutnätet igen".
func reset_selected() -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	record.erase("pin")
	record.erase("x")
	record.erase("y")
	record.erase("guess_x")
	record.erase("guess_y")
	record.erase("score")
	records[selected] = record
	# Vyns egen post bär också platsen: den måste glömmas, annars ligger ikonen kvar där den låg.
	view._snäpp.erase(selected)
	status = "%s is back in the lattice (no pins)" % selected
	view.visa(meta, "TRADEDITOR", false)
	overlay.queue_redraw()


func save() -> void:
	var out: Array = []
	# Skriv in gren och nivå i posten: filen skall stå för sig själv, så en nod som flyttats eller en
	# ny nod går att läsa utan tree.json. Döda plattnycklar (mätta x/y, grop, gissning) städas bort —
	# de beskrev en bild som inte längre ritas (M97).
	for id in records:
		var post: Dictionary = records[id]
		var def: Dictionary = meta.def_for(str(id))
		if not def.is_empty():
			post["tier"] = int(def.get("tier", 1))
			post["branch"] = str(def.get("branch", ""))
		for död in ["score", "guess_x", "guess_y"]:
			post.erase(död)
		if not TreeSockets.pinned(post):
			post.erase("x")
			post.erase("y")
			post.erase("r")
		out.append(post)
	if TreeSockets.write(out):
		status = "saved %d node records -> %s" % [out.size(), TreeSockets.PATH]
	else:
		status = "COULD NOT WRITE %s" % TreeSockets.PATH
	overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	view._rörd = true          # en tangent = användaren äger utsnittet (se mouse_event)
	var key := (event as InputEventKey).keycode
	var fine := STEP * (5.0 if event.is_shift_pressed() else 1.0)
	match key:
		KEY_LEFT:
			step_selected(-fine, 0.0)
		KEY_RIGHT:
			step_selected(fine, 0.0)
		KEY_UP:
			step_selected(0.0, -fine)
		KEY_DOWN:
			step_selected(0.0, fine)
		KEY_L:
			toggle_size()
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			add_node()
		KEY_G:
			next_graphics()
		KEY_X:
			remove_added()
		KEY_C:
			clear_requirements()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			var typen: Array = TreeSockets.VALUES.keys()
			var nr: int = key - KEY_1
			if nr < typen.size():
				toggle_upgrade(str(typen[nr]))
		KEY_T:
			next_node()
		KEY_R:
			reset_selected()
		KEY_S:
			save()
		KEY_M:
			get_tree().change_scene_to_file("res://main.tscn")
		KEY_Q, KEY_ESCAPE:
			get_tree().quit()
