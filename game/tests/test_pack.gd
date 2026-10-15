extends SceneTree
## FORMATIONSGRINDEN (M126). Provet svarar på en fråga sviten inte ställde: HÄNDER radregeln i verklig
## strid? MÄTT före M126: i 560 möten (fem frön × tre banor) hade **0** en bakre rad, för `per_rad`
## blev alltid >= antalet fiender — båda kommer ur samma rumsterm. Alltså var bakre radens 0,6,
## knuffen och telegrammets val overksamma utan att något prov sa till: kameraprovet mätte
## formationens geometri i en scen, inte om packet någonsin delades i rader.
##
## Grindarna:
##   1. en betydande andel av mötena har en bakre rad (mätt 190 av 560 = 34 %, krav minst 20 %)
##   2. den bakre raden är en ANNAN fiende än rummets egen (annars är packet kloner och valet trivialt)
##   3. den främre raden ÄR rummets egen fiende (rummets identitet)
##   4. samma rum ger samma pack varje gång (determinismen — annars är mätarens siffror en lögn)
##   5. packet slår lika hårt som om alla stod främst (radfaktorn i `begin_fight`)

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
	var stages := Stages.load_all()
	var bestiary := Enemies.load_all()
	var db := Cards.load_all()
	var ids: Array = db.keys()
	var pack := 0
	var med_bakre := 0
	var blandade := 0
	var främre_fel := 0
	print("— formationen i verkliga möten —")
	for stage_id in ["stage_01", "stage_02", "stage_03"]:
		var stage: Stages.StageDef = stages[stage_id]
		for frö in 4:
			var kort := []
			for i in 22:
				kort.append(ids[(frö * 7 + i) % ids.size()])
			var run := Run.new(stage, bestiary, Cards.make_pile(db, kort), 5000 + frö * 97, db)
			var vakt := 0
			while not run.finished and vakt < 40:
				vakt += 1
				var noder: Array = run.explore.floor_ref.nodes
				for n in noder:
					if n.cleared or n.kind != "encounter":
						continue
					var c: Combat = run.begin_fight(n, false)
					if c == null:
						continue
					pack += 1
					var rader := []
					var namn := []
					for e in c.enemies:
						rader.append(e.row)
						namn.append(e.name)
					if int(rader.max()) > 0:
						med_bakre += 1
						# den bakre raden: en annan fiende än rummets egen?
						var rumsnamn: String = bestiary[n.enemy_id].name
						for i in c.enemies.size():
							if c.enemies[i].row > 0 and c.enemies[i].name != rumsnamn:
								blandade += 1
								break
					if c.enemies[0].name != bestiary[n.enemy_id].name:
						främre_fel += 1
				var spade = null
				for n in noder:
					if n.kind == "shovel" and not n.cleared:
						spade = n
				if spade == null:
					break
				run._resolve(spade)
	print("pack: %d, med bakre rad: %d, blandade: %d" % [pack, med_bakre, blandade])
	var andel := float(med_bakre) / maxf(1.0, float(pack))
	check(pack >= 100, "provet fick möten att mäta i", str(pack))
	check(andel >= 0.20, "en bakre rad finns i en betydande andel av mötena (radregeln lever)",
		"%.0f %% (%d av %d, krav 20 %%)" % [andel * 100.0, med_bakre, pack])
	check(blandade >= 1, "den bakre raden är en ANNAN fiende (inte en klon)", "%d av %d bakre rader" % [blandade, med_bakre])
	check(främre_fel == 0, "den främre raden är rummets EGEN fiende", "%d fel" % främre_fel)

	# 4. determinismen: samma rum, samma pack — två körningar med samma frö
	print("— samma rum ger samma pack —")
	var a := _pack_för(stages["stage_01"], bestiary, db, ids, 4711)
	var b := _pack_för(stages["stage_01"], bestiary, db, ids, 4711)
	check(a == b and not a.is_empty(), "samma frö ger samma pack", "%d möten, %s" % [a.size(),
		"lika" if a == b else "OLIKA"])

	# 5. trycket: raderna ändrar formen, inte trycket
	print("— raderna ändrar formen, inte trycket —")
	var c5 := Combat.new(1)
	var foes := []
	for i in 3:
		foes.append(Combat.Enemy.new("prov", 1000.0, 10.0, i / 2))     # raderna 0, 0, 1
	c5.begin([], foes)
	c5.hp = 1000.0
	c5.max_hp = 1000.0
	var före := c5.hp
	c5.enemy_turn()
	var tappat := före - c5.hp
	check(is_equal_approx(tappat, 26.0), "tre i två rader slår 26 (2 x 10 + 1 x 10 x 0,6)",
		"%.0f" % tappat)
	# Invarianten: den radviktade summan gånger faktorn är EXAKT antalet fiender, alltså slår packet
	# lika hårt som om alla stod främst.
	var per := 2
	var viktad := float(per) + float(3 - per) * Combat.BAKRE_SLAG
	check(is_equal_approx(viktad * Run.radfaktor(3, per), 3.0),
		"och skalningen ger packet samma tryck som en enda rad",
		"%.0f x %.4f = %.4f" % [viktad, Run.radfaktor(3, per), viktad * Run.radfaktor(3, per)])
	# Bossen: munstycket som kostade 29 % av bossens skada (per räknades ur det vanliga rummet).
	check(is_equal_approx(Run.radfaktor(1, 1), 1.0) and is_equal_approx(Run.radfaktor(1, 2), 1.0),
		"ett ensamt pack skalas aldrig (bossen slog 29 % svagare av det felet)",
		"%.4f / %.4f" % [Run.radfaktor(1, 1), Run.radfaktor(1, 2)])

	print("")
	print("kontroller: %d, fel: %d" % [checks, fails])
	quit(1 if fails else 0)

func _pack_för(stage: Stages.StageDef, bestiary: Dictionary, db: Dictionary, ids: Array,
		frö: int) -> Array:
	var kort := []
	for i in 22:
		kort.append(ids[i % ids.size()])
	var run := Run.new(stage, bestiary, Cards.make_pile(db, kort), frö, db)
	var ut := []
	var vakt := 0
	while not run.finished and vakt < 12:
		vakt += 1
		for n in run.explore.floor_ref.nodes:
			if n.cleared or n.kind != "encounter":
				continue
			var c: Combat = run.begin_fight(n, false)
			if c == null:
				continue
			var namn := []
			for e in c.enemies:
				namn.append("%s@%d" % [e.name, e.row])
			ut.append(",".join(namn))
		var spade = null
		for n in run.explore.floor_ref.nodes:
			if n.kind == "shovel" and not n.cleared:
				spade = n
		if spade == null:
			break
		run._resolve(spade)
	return ut
