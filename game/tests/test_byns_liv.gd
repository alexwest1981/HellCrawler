## BYNS LIV (M190): rök, fackelglöd och eldflugor i den målade byn.
##
## Alex, om byn: den ska leva, inte vara ett vykort. Effekterna ligger i ett eget Node2D (`Rök`) i
## `ui/village_view.gd`, och det finns två saker som kan gå fel tyst: att noden inte hamnar i trädet
## (då syns ingenting), och att den ritar i FEL ruta — rök som svävar en bit ifrån skorstenen ser
## påklistrad ut. Provet mäter båda, plus att den ritar om sig själv (animation som står still är
## ingen animation).
##
## Körs: tools/ett_prov.sh tests/test_byns_liv.gd
extends SceneTree

var checks := 0
var fails := 0


func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])


func _initialize() -> void:
	print("=== BYNS LIV (rök, glöd, eldflugor) ===")

	# -- 1. NODEN FINNS OCH LIGGER ÖVER BILDEN
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.meny.visible = false
	main.shell = "hem"
	main._refresh_shell()
	await process_frame
	var vy = main.by_view
	check(vy != null, "byvyn finns")
	if vy == null:
		print("=== TOTALT (liv): %d kontroller, %d fel ===" % [checks, fails])
		quit(1)
		return
	check(vy._rok != null, "röken är en egen nod i vyn")
	if vy._rok == null:
		print("=== TOTALT (liv): %d kontroller, %d fel ===" % [checks, fails])
		quit(1)
		return
	check(vy._rok.get_parent() == vy, "röken ligger i byvyns träd")
	check(vy._rok.z_index > 0, "röken ritas ÖVER bilden", "z_index %d" % vy._rok.z_index)

	# -- 2. RÄTT RUTA: bilden fyller vyn, och skorstenarna står i bildens övre del
	var mål: Vector2 = vy.bild_storlek()
	check(mål.x > 1.0 and mål.y > 1.0, "bildens designmått är känt", "%s" % str(mål))
	var ruta: Rect2 = vy.hd_ruta(vy.size.x / maxf(1.0, mål.x))
	check(absf(ruta.size.x - vy.size.x) < 2.0, "bilden fyller vyn i sidled",
		"bild %.0f px, vy %.0f px" % [ruta.size.x, vy.size.x])
	check(ruta.position.x > -1.0 and ruta.position.y > -1.0, "bilden börjar i vyns övre vänstra hörn",
		str(ruta.position))
	var fel: Array = []
	for sk in vy._rok.skorstenar:
		if float(sk.y) > 60.0 or float(sk.x) < 0.0 or float(sk.x) > 100.0:
			fel.append(sk)
	check(fel.is_empty(), "alla skorstenar står i bildens övre del (under 60 % höjd)", str(fel))
	var fackel_fel: Array = []
	for fa in vy._rok.facklor:
		if float(fa.y) > 60.0:
			fackel_fel.append(fa)
	check(fackel_fel.is_empty(), "facklorna står i portens höjd, inte på gatan", str(fackel_fel))

	# -- 3. DEN RITAR OM SIG: tiden går när vyn syns och står still när den är gömd
	var t0: float = vy._rok.t
	for i in 5:
		await process_frame
	var t1: float = vy._rok.t
	check(t1 > t0, "röken rör sig (tiden går)", "%.3f -> %.3f" % [t0, t1])
	vy.visible = false
	var t2: float = vy._rok.t
	for i in 5:
		await process_frame
	check(absf(vy._rok.t - t2) < 0.0001, "gömd by ritar ingen rök",
		"%.3f -> %.3f" % [t2, vy._rok.t])

	print("=== TOTALT (liv): %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
