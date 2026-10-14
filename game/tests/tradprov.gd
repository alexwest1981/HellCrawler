## TILLFÄLLIG MÄTPROBE (M120): närbild på en trädstam i MOTORN (Godot), inte i Blender.
##   DISPLAY=:99 godot --path . --audio-driver Dummy --script res://tests/tradprov.gd
## Provet bygger by-scenen, sätter en EGEN ortografisk kamera på en stam och sparar rutan.
## Det rör ingenting i spelkoden och raderas efter mätningen.
extends SceneTree

const UT := "/home/alex/.hermes/cache/scratch/trad_godot.png"


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var scen: Node3D = load("res://scenes/by.tscn").instantiate()
	root.add_child(scen)
	for i in 8:
		await process_frame

	# Stammarna i byn.glb. Namnen kommer ur Blender-exporten ("*_Trunk").
	var stammar: Array = []
	for n in scen.find_children("*", "MeshInstance3D", true, false):
		if "trunk" in n.name.to_lower():
			stammar.append(n)
	print("stammar i scenen: %d" % stammar.size())
	if stammar.is_empty():
		quit(1)
		return

	# Den MITTERSTA stammen: den står fritt och är inte halvt klippt av en vägg.
	var mitten := Vector3.ZERO
	for n in stammar:
		mitten += (n as Node3D).global_position
	mitten /= stammar.size()
	var stam: Node3D = stammar[0]
	for n in stammar:
		if (n as Node3D).global_position.distance_to(mitten) < stam.global_position.distance_to(mitten):
			stam = n
	var aabb := (stam as MeshInstance3D).global_transform * (stam as MeshInstance3D).get_aabb()
	var mitt: Vector3 = aabb.get_center()
	var höjd: float = aabb.size.y
	# DEN NEDERSTA DELEN AV STAMMEN. Mätt: tallens våningar börjar 1,19 m över stammens fot
	# (stam z 0,50-3,07, nedersta våningen z 1,69), så en kamera i stamhöjd ser bara BARR — första
	# försöket fotograferade lövverket. Siktet ligger därför i stammens nedre tredjedel, under våningen.
	var låg := Vector3(mitt.x, aabb.position.y + 0.3 * höjd, mitt.z)

	var kam := Camera3D.new()
	kam.name = "tradprov_kamera"
	kam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Rakt framifrån (ingen tippning): barken döms lättast utan perspektiv.
	kam.position = låg + Vector3(0.0, -4.0, 0.0)
	scen.add_child(kam)
	kam.look_at(låg, Vector3.UP)
	kam.size = 1.5
	kam.current = true
	# BARA STAMMEN I BILDEN. Mätt: tallens våningar ligger runt stammen, och på 4 m håll fyllde de
	# rutan i två försök — bilden visade BARR, inte bark. Frågan gäller vad stammens yta visar, så
	# allt annat släcks: samma motor, samma mesh, samma material, ingen skymmande krona.
	for n in scen.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = (n == stam)
	print("bara stammen syns: %d av %d mesh-noder släckta" % [
		scen.find_children("*", "MeshInstance3D", true, false).size() - 1,
		scen.find_children("*", "MeshInstance3D", true, false).size()])
	for i in 6:
		await process_frame
	await create_timer(0.4).timeout

	var material: String = "-"
	var mi := stam as MeshInstance3D
	if mi.mesh != null and mi.mesh.get_surface_count() > 0:
		# Materialet på ytan stammen ritas med — och bilden den samplar, så siffran och rutan
		# kommer från samma sak.
		var m: Material = mi.get_active_material(0)
		if m != null:
			var tex: Texture2D = null
			if m is StandardMaterial3D:
				tex = (m as StandardMaterial3D).albedo_texture
			else:
				tex = m.get("shader_parameter/albedo_texture") as Texture2D
			material = "%s (%s)" % [m.resource_name, tex.resource_path if tex != null else "-"]
	print("stam: %s  mitt %s  höjd %.2f m  kamera.size %.2f" % [
		stam.name, str(mitt), höjd, kam.size])
	print("material: %s" % material)

	var bild := root.get_texture().get_image()
	if bild == null:
		print("ingen bild (viewport-texturen är null)")
		quit(1)
		return
	bild.save_png(UT)
	print("NÄRBILD (motor): %s  %dx%d" % [UT, bild.get_width(), bild.get_height()])
	quit(0)
