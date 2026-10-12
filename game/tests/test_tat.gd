## INGEN YTA BAKOM KORTEN FÅR VARA GENOMSLÄPPLIG (M118).
##
## Alex: *"kort blir transparenta i bakgrunden, det är ett stort nej"* och *"utgå från att all
## genomskinlighet i handen och i bakomliggande paneler är fel — korten ska vara täta."*
##
## MÄTT MED `-- genomsynprov` (A/B i en körning: samma bild över fängelsehålan, sedan över en VIT vy;
## pixlar som ändras inuti en ruta läcker): stridspanelen ändrade 2 840 av sina 2 976 px (95,4 %) —
## alfa 0,93 i `_panel_style` släppte igenom 7 % av fängelsehålan. Efter fixen: 0 px. Kortens kärna
## (12 px indragen, innanför rundningen) ändrade 0 px redan före — kortens EGEN yta var tät; det var
## panelerna bakom dem, bannern och platshållaren INUTI kortet (0,85), bänkskivan (0,97) och
## varuraderna i butiken (0,66/0,55) som läckte.
##
## Det här provet är grinden: varje stil som ritar en yta i kortet eller bakom det ska ha alfa 1,0.
## Provet läser stilarna ur NODERNA (kortet byggs som spelet bygger det), inte ur en kopia av koden.
##
##   godot --headless --path game --script res://tests/test_tat.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj := "") -> void:
	checks += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	if not ok:
		fails += 1

## Alfa på en StyleBox, oavsett typ: StyleBoxFlat bär färgen, StyleBoxTexture bär modulate.
func _alfa(sb: StyleBox) -> float:
	if sb == null:
		return 1.0
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).bg_color.a
	return (sb as StyleBoxTexture).modulate_color.a

func _initialize() -> void:
	print("— ingen yta i kortet eller bakom det får släppa igenom —")

	# 1) KORTET SJÄLVT: varje Control i kortet med en panelstil. Kortet byggs med SAMMA `make` som
	#    handen använder, så det provet läser är det spelaren ser.
	var db := Cards.load_all()
	var id := ""
	for k in db.keys():
		id = str(k)
		break
	var kort: Cards.Card = db[id]
	var v := CardView.make(kort, 0, null, false, 1.0)
	root.add_child(v)
	await process_frame
	var ytor := [["kortets botten", v]]
	_leta(v, ytor)
	var läcker: Array = []
	for par in ytor:
		var a := _alfa((par[1] as Control).get_theme_stylebox("panel"))
		if a < 1.0:
			läcker.append("%s %.2f" % [par[0], a])
	check(läcker.is_empty(), "varje yta i kortet är tät (alfa 1,0)", ", ".join(läcker))
	check(_alfa(v.get_theme_stylebox("panel")) == 1.0, "kortets egen botten", 
		"alfa %.2f" % _alfa(v.get_theme_stylebox("panel")))
	# Och kortet i LYFT läge (`set_forward`): samma väg som hover tar.
	v.set_forward(true)
	await process_frame
	check(_alfa(v.get_theme_stylebox("panel")) == 1.0, "och i lyft läge (hover)",
		"alfa %.2f" % _alfa(v.get_theme_stylebox("panel")))
	v.queue_free()
	await process_frame

	# 2) PANELERNA BAKOM KORTEN. Stilarna byggs av Main, och provet läser dem ur en instans av spelet
	#    — alltså exakt de stilobjekt som läggs på panelerna, inte en avskrift.
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var pan: StyleBoxFlat = main._panel_style()
	check(pan.bg_color.a == 1.0, "stridspanelernas bakgrund (`_panel_style`)", "alfa %.2f" % pan.bg_color.a)
	var bänk: StyleBox = main._bench_style()
	check(_alfa(bänk) == 1.0, "bänkskivan bakom korten i värdshuset/kortvalet/butiken (`_bench_style`)",
		"alfa %.2f" % _alfa(bänk))
	var rad_ja: StyleBoxFlat = main._varu_stil(true)
	var rad_nej: StyleBoxFlat = main._varu_stil(false)
	check(rad_ja.bg_color.a == 1.0 and rad_nej.bg_color.a == 1.0,
		"butikens varurader, både det man har råd med och inte (`_varu_stil`)",
		"alfa %.2f / %.2f" % [rad_ja.bg_color.a, rad_nej.bg_color.a])
	# Dämpningen av det man inte har råd med ska bäras av FÄRGEN, inte av genomsläpp (samma regel som
	# kortens markering): mörkare plåt, inte genomskinligare.
	check(rad_nej.bg_color.v < rad_ja.bg_color.v,
		"och den man inte har råd med är mörkare, inte mer genomskinlig",
		"%.2f mot %.2f" % [rad_nej.bg_color.v, rad_ja.bg_color.v])
	# Trädet (en plats i byn) följer samma regel: en panel över vyn släpper inte igenom.
	var träd := TreeView.new()
	check(_alfa(träd._panel_stil()) == 1.0, "trädets panel (`TreeView._panel_stil`)",
		"alfa %.2f" % _alfa(träd._panel_stil()))
	träd.free()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)

## Varje Control under `n` som bär en egen panelstil, med sitt namn — så en läckande yta går att peka ut.
func _leta(n: Node, ut: Array) -> void:
	for barn in n.get_children():
		if barn is Control and (barn as Control).has_theme_stylebox_override("panel"):
			ut.append(["%s (%s)" % [(barn as Control).name, barn.get_class()], barn])
		_leta(barn, ut)
