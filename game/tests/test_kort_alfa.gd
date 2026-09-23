## Kortet får aldrig stå halvgenomskinligt i handen.
##
## Alex: *"Korten ... får inte bli transparenta när man hovrar, det stör spelandet."* Orsaken var inte
## hoverrörelsen: utdelningen (`dela_in`) sänker alfan till 0,25 och driver upp den igen med SAMMA
## tween som hoverrörelsen använder. Kom pekaren in under utdelningen dödade hoverkoden den tweenen,
## och kortet låg kvar på 25 % synlighet hela striden.
##
## Provet mäter exakt det: dela ut ett kort med fördröjning, hover det MITT i utdelningen, och läs
## alfan. Det är den enda raden som skiljer ett helt kort från ett spöke, och den faller utan fixen
## (mätt: 0,25 mot 1,0).
##
##   godot --headless --path game --script res://tests/test_kort_alfa.gd
extends SceneTree

var fails := 0
var checks := 0

func check(ok: bool, vad: String, detalj := "") -> void:
	checks += 1
	print("  %s  %s%s" % ["ok  " if ok else "FEL ", vad, "" if detalj.is_empty() else "  (%s)" % detalj])
	if not ok:
		fails += 1

func _initialize() -> void:
	var db := Cards.load_all()
	var id := ""
	for k in db.keys():
		id = str(k)
		break
	var kort: Cards.Card = db[id]
	var v := CardView.make(kort, 0, null, false, 1.0)
	root.add_child(v)
	await process_frame

	print("— kortet är helt när man hovrar det —")
	# Utdelningen: 0,2 s fördröjning + blekningen. Alfa sätts till 0,25 direkt.
	v.dela_in(0.2)
	await process_frame
	check(v.modulate.a < 1.0, "utdelningen börjar halvgenomskinlig (annars mäter provet inget)",
		"alfa %.2f" % v.modulate.a)
	# HOVERN, mitt i utdelningen — felet Alex såg.
	v.set_forward(true)
	await process_frame
	check(v.modulate.a == 1.0, "hover under utdelningen lämnar kortet HELT", "alfa %.2f" % v.modulate.a)
	# Hoverrörelsen KRAMAR kortet några procent med en gång (det är svikten), så exakt 1,0 är fel krav:
	# det som mäts är att utdelningens 0,94 inte ligger kvar.
	check(absf(v.scale.x - 1.0) < 0.06, "och utan kvarvarande ihoppressning från utdelningen",
		str(v.scale))
	# Och det ska hålla: rörelsen får inte bleka kortet igen.
	for i in 20:
		await process_frame
	check(v.modulate.a == 1.0, "alfan står kvar på 1 efter hela hoverrörelsen", "alfa %.2f" % v.modulate.a)
	# Undan igen: samma sak, kortet lägger sig i ledet utan att blekna.
	v.set_forward(false)
	for i in 20:
		await process_frame
	check(v.modulate.a == 1.0, "och efter återgången", "alfa %.2f" % v.modulate.a)

	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
