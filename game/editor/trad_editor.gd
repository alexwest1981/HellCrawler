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
## Keys, also listed in the side panel: click or drag = move, arrow keys = nudge, L = small/large
## node, 1-9 = tick an upgrade (or click its row), T = next node, R = reset to the measured guess,
## S = save, M = menu, ESC or Q = quit.
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
		# lista ur metan tog med åtta id som inte har någon nod på plattan. Markören hamnade då i
		# hörnet (mätt: noden "might", x -25 %) och "T nästa nod" vandrade in i noder som inte finns
		# i trädet. Ett hem för frågan "vilka noder finns i trädet".
		ids.append(str(id))
	records = TreeSockets.load_all()
	for id in ids:
		if not records.has(id):
			# A node the file does not know: take where the view put it (its lattice) as the start.
			var frac: Vector2 = view.till_bild(view.nod_punkt(str(id)))
			records[id] = TreeSockets.blank(str(id), frac.x, frac.y, 0.018)
		var post: Dictionary = records[id]
		if not post.has("size"):
			# Plattans grop bestämmer utgångsklassen; grenens huvudnod är stor oavsett gropen.
			post["size"] = TreeSockets.size_of(post, int(view._rader.get(str(id), {}).get("nivå", 0)))
		if not post.has("effekt"):
			post["effekt"] = []
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
		du.draw_line(point - Vector2(9, 0), point + Vector2(9, 0), Color(0.95, 0.4, 0.3), 1.0)
		du.draw_line(point - Vector2(0, 9), point + Vector2(0, 9), Color(0.95, 0.4, 0.3), 1.0)

	var x := view.size.x + 8.0
	var y := 18.0
	du.draw_string(font, Vector2(x, y), "TRADEDITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.95, 0.9, 0.7))
	y += 16.0
	if records.has(selected):
		var record: Dictionary = records[selected]
		var klass: String = TreeSockets.size_of(record)
		var lines := [
			"node: %s" % selected,
			"x %.1f %%   y %.1f %%" % [float(record.get("x", 0.0)) * 100.0, float(record.get("y", 0.0)) * 100.0],
			"node size: %s (r %.1f %%)" % [klass, TreeSockets.radius_of(record) * 100.0],
			"pit %.2f (0 = none found)" % float(record.get("score", 0.0)),
			"tier %d, rank %d/%d" % [
				int(view._rader.get(selected, {}).get("nivå", 0)), meta.rank(selected),
				int(meta.def_for(selected).get("max_rank", 1))],
			"",
			"click / drag  move",
			"arrows        nudge",
			"L             small / large node",
			"1-9 / click   tick upgrade",
			"T             next node",
			"R             reset to measured",
			"S             SAVE",
			"M             menu",
			"ESC / Q       quit",
			"",
			"UPGRADES (%s node)" % klass,
		]
		for line in lines:
			du.draw_string(font, Vector2(x, y), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.86, 0.86, 0.9))
			y += 13.0
		# Kryssraderna. Ytan för varje rad sparas, så ett klick vet vad det träffade — panelen är ett
		# formulär, och en rad som ser klickbar ut men inte är det är värre än ingen rad.
		effekt_ytor.clear()
		var ikryssade: Array = record.get("effekt", [])
		for typ in TreeSockets.VALUES:
			var rad := Rect2(x, y - 11.0, PANEL_WIDTH - 16.0, 13.0)
			var på: bool = ikryssade.has(typ)
			du.draw_rect(rad, Color(0.2, 0.5, 0.3, 0.35) if på else Color(0.2, 0.2, 0.25, 0.35), true)
			du.draw_string(font, Vector2(x + 4.0, y), "%s %s  (%s, rank %d)" % [
				"[x]" if på else "[ ]", str(TreeSockets.WORDS.get(typ, typ)),
				TreeSockets.effect_preview(typ, klass), meta.rank(selected)], HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, Color(0.95, 0.95, 0.85) if på else Color(0.7, 0.7, 0.75))
			effekt_ytor[typ] = rad
			y += 13.0
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


func mouse_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			dragging = button.pressed
			if button.pressed:
				# Ett klick i panelen är ett kryss, aldrig en förflyttning: noderna bor till vänster
				# om panelen, så en träff här kan bara vara en rad.
				if button.position.x >= view.size.x:
					dragging = false
					for typ in effekt_ytor:
						if (effekt_ytor[typ] as Rect2).has_point(button.position):
							toggle_upgrade(str(typ))
					return
				var hit := node_at(button.position)
				if not hit.is_empty():
					selected = hit
				else:
					# A click on bare stone still moves the SELECTED node there: on a sparse plate
					# that is faster than dragging it across an empty half.
					place_at(button.position)
				overlay.queue_redraw()
	elif event is InputEventMouseMotion and dragging:
		place_at((event as InputEventMouseMotion).position)


## Put the selected node where the pointer is, in the plate's own coordinates.
func place_at(point: Vector2) -> void:
	if selected.is_empty():
		return
	var frac: Vector2 = view.till_bild(point)
	records[selected] = {
		"id": selected, "x": frac.x, "y": frac.y,
		"r": float(records.get(selected, {}).get("r", 0.018)),
		"score": float(records.get(selected, {}).get("score", 0.0)),
		"guess_x": float(records.get(selected, {}).get("guess_x", frac.x)),
		"guess_y": float(records.get(selected, {}).get("guess_y", frac.y)),
	}
	apply()
	overlay.queue_redraw()


## Push the record into the view and redraw it. One place: the editor never moves an icon itself.
func apply() -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	view.flytta(selected, float(record["x"]), float(record["y"]))
	view.sätt_radie(selected, TreeSockets.radius_of(record))
	view.rita_om()


func step_selected(dx: float, dy: float) -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	record["x"] = clampf(float(record["x"]) + dx, 0.0, 1.0)
	record["y"] = clampf(float(record["y"]) + dy, 0.0, 1.0)
	records[selected] = record
	apply()
	overlay.queue_redraw()


## Byt mellan plattans två nodstorlekar. Klasserna är mätta ur bilden (0,009 och 0,018), inte
## påhittade: en liten nod skall hamna i en liten grop.
func toggle_size() -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	record["size"] = "liten" if TreeSockets.size_of(record) == "stor" else "stor"
	record["r"] = TreeSockets.radius_of(record)
	records[selected] = record
	status = "%s is now a %s node" % [selected, record["size"]]
	apply()
	overlay.queue_redraw()


## Kryssa uppgraderingar. Ett kryss per typ; värdet följer storleken och räknas fram i TreeSockets,
## så panelen och spelet visar samma siffra. Spara (S) skriver dem till socketfilen.
func toggle_upgrade(typ: String) -> void:
	if not records.has(selected) or not TreeSockets.VALUES.has(typ):
		return
	var record: Dictionary = records[selected]
	var lista: Array = record.get("effekt", [])
	if lista.has(typ):
		lista.erase(typ)
	else:
		lista.append(typ)
	record["effekt"] = lista
	records[selected] = record
	var text: String = TreeSockets.text_of(record)
	status = "%s: %s" % [selected, text if not text.is_empty() else "no upgrades ticked"]
	overlay.queue_redraw()


func next_node() -> void:
	if ids.is_empty():
		return
	var index: int = ids.find(selected)
	selected = str(ids[(index + 1) % ids.size()])
	overlay.queue_redraw()


func reset_selected() -> void:
	if not records.has(selected):
		return
	var record: Dictionary = records[selected]
	record["x"] = float(record.get("guess_x", record["x"]))
	record["y"] = float(record.get("guess_y", record["y"]))
	records[selected] = record
	status = "%s back at the measured guess" % selected
	apply()
	overlay.queue_redraw()


func save() -> void:
	var out: Array = []
	for id in ids:
		if records.has(id):
			out.append(records[id])
	for id in records:
		if not ids.has(id):
			out.append(records[id])
	if TreeSockets.write(out):
		status = "saved %d nodes -> %s" % [out.size(), TreeSockets.PATH]
	else:
		status = "COULD NOT WRITE %s" % TreeSockets.PATH
	overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if event.is_shift_pressed() and key != KEY_S:
		pass
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
