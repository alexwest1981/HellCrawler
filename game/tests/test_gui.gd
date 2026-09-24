## Provet för HUD:ens rutor (M40): statusblocket uppe till vänster, loggen nere till vänster och
## statusblocket uppe till vänster och loggen nere till vänster — Alex' GUI-referens, med korten kvar i mitten i stället för en action bar.
##
## Två sorters kontroller:
##   * LOGIKEN (alltid): staplarnas fyllning följer värdet, loggens ring håller sina rader i ordning,
##     målet (namn och bild) hämtas ur striden; den egna fienderutan togs bort i M68.
##   * LÄGET (bara med ett fönster som rymmer vyn): att rutorna ligger i marginalen och inte över
##     spelvyn, korten eller varandra. I huvudlöst läge (tools/test.sh) är fönstret 64x64 och vyn
##     ryms inte alls, så de kontrollerna hoppas över där och mäts i stället i `-- guiprov`, som kör
##     med ett riktigt fönster. Ett prov som mäter en layout i ett 64 px fönster mäter ingenting.
##
## KÖRNING: godot --headless --script res://tests/test_gui.gd
extends SceneTree

var main: Node

var fails := 0
var checks := 0
var fönster := Vector2.ZERO
var vy := Rect2()

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
		fails += 1

func ruta(n: Control) -> Rect2:
	return Rect2(n.global_position, n.size)

func överlappar(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b) and a.intersection(b).get_area() > 4.0

func måttbart() -> bool:
	return fönster.y >= 700.0 and vy.size.y > 0.0

## Rutan i FÖNSTRETS px. Valkorten ligger i vyn och skalas upp i fönstret; handens kort ligger
## redan i fönstret. Att jämföra dem utan omräkning gav "0 px krock" med 44 px verklig överlapp.
func fönsterruta(r: Rect2, xform: Transform2D) -> Rect2:
	var a: Vector2 = xform * r.position
	var b: Vector2 = xform * r.end
	return Rect2(a, b - a)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Ett fönster i spelstorlek: provkörningen är huvudlös och startar i 64x64, där marginalerna inte
	# finns alls (vyn är 960x540 och hamnar utanför fönstret). Utan det mäter provet en layout ingen
	# spelar i — samma skäl och samma rad som tests/test_kortbord.gd.
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	# GLANSEN (M74): en glasfiende tvingas fram, så kontrollen av glansen nedan mäter MEKANISMEN och
	# inte vilka fiender våningen råkade bjuda på. Sedan M74 bär andarna sin aura som en kant ur
	# materialmasken, och den gamla varma dimfläcken (`rok.png`) togs bort för dem — den enda glans
	# kvar i våningen var just de två fläckarna, så kontrollen hade tyst mätt noll.
	# FÖRE `_start_run`: fienderna byggs MED våningen (mätt: sattes provet efter `_start_run` stod
	# 25 figurer med 0 glans kvar — `_fiendeprov` läses när figuren skapas, inte när striden börjar).
	main._fiendeprov = "glass_herald"
	main._start_run("stage_01", 20260919)
	main._placera_vy()
	await process_frame
	# En strid: gå fram till en fiende och slåss (kartan läggs i ordning, så provet inte gissar var).
	var nod: Dungeon.FloorNode = null
	for n in main.run.explore.floor_ref.nodes:
		if not n.cleared and (n.kind == "encounter" or n.kind == "boss"):
			nod = n
			break
	main.run.explore.pos = nod.pos
	main.run.explore.facing = 0
	main._enter_node_here()
	main._refresh()                       # samma väg som spelet: striden ritas av _refresh
	await process_frame
	await process_frame
	fönster = main.get_viewport().get_visible_rect().size
	vy = Rect2(main._vy_korg.position, main._vy_korg.size * main._vy_korg.scale.x)
	print("  fönstret %.0fx%.0f, spelvyn %s, strid: %s" % [fönster.x, fönster.y, str(vy),
		"ja" if main.active_combat != null else "nej"])
	check(main.active_combat != null, "provet fick en strid att mäta i")

	## FIGURERNA STÅR PÅ SIKTLINJEN (M66). Alex: *"spökena står på sidan när man möter dem, även andra
	## fiender — har det att göra med hur trångt det är i gången?"* Ja, delvis: förskjutningen låg i
	## världens x och z, och den är SIDLED så fort spelaren kommer in i rummet från ett annat håll
	## (mätt i figurprov: två figurer 0,45 m i sidled när spelaren kom från x-hållet). Regeln nu: i
	## en strid står figuren i rutans mitt och de andra BAKOM varandra på linjen från spelaren genom
	## rutan. Provet mäter att ingen figur i striden ligger vid sidan om den linjen.
	print("")
	print("— figurerna —")
	var figurer := main.get_tree().get_nodes_in_group("fiende_figur")
	# REGELN MÄTS SOM ETT AVSTÅND TILL EN LINJE, inte som en kant mot en vägg: figurens duk är 1,44 m
	# och gången 1 m, så en kantmätning fäller även en korrekt placering (mätt i ett tidigare prov: 31
	# kanter "i vägg" när varje figur stod rätt). Det som var fel var SIDLEDET, och det mäts här som
	# avståndet från linjen spelaren -> rutan: noll betyder mitt för spelaren.
	# MÄTT SOM AVSTÅND TILL KAMERANS SIKTE, inte till en världsaxel: det är så det syns. Linjen är
	# kamerans högerled, och figuren ska ligga nära noll — "mitt för spelaren" är ett BILDKRAV.
	var vid_sidan := []
	if main.active_combat != null and main.cam != null:
		var snode: Vector2i = main.active_node_pos()
		var spelare: Vector3 = main._cam_pos()
		var bas: Basis = main.cam.global_transform.basis
		var höger := Vector3(bas.x.x, 0.0, bas.x.z).normalized()
		for fig in figurer:
			if fig.position.distance_to(Vector3(snode.x + 0.5, fig.position.y, snode.y + 0.5)) > 2.5:
				continue
			var b := Vector3(fig.position.x - spelare.x, 0.0, fig.position.z - spelare.z)
			var sidled: float = absf(höger.dot(b))
			if sidled > 0.15:
				vid_sidan.append("%s %.2f m i sidled" % [str(fig.position), sidled])
	check(figurer.size() > 0, "våningen har fiender att mäta (%d figurer)" % figurer.size())
	check(vid_sidan.is_empty(), "ingen fiende i striden står vid sidan om siktlinjen (%d av %d)"
		% [vid_sidan.size(), figurer.size()], ", ".join(vid_sidan.slice(0, 4)))
	# FIGUREN MÅSTE RITAS (M69). Mätt med `-- figurprov fienderödfärg` (figuren självlysande magenta,
	# allt annat i bilden oförändrat): med `material_override` ritar Sprite3D 73 px av figuren, med
	# Sprite3D:s EGET material 22 641 px. Rutan i arket väljs i motorns eget material, och en override
	# tar bort den vägen — figuren blir en nål i gången (Alex: *"spökena står inte vända mot kameran"*).
	# Provet bevakar precis det: ingen fiende får bära ett override, och skuggning + alfa-klippning ska
	# vara kvar (de ÄR figurens material).
	var med_override: Array = []
	var utan_figurmaterial: Array = []
	for f in figurer:
		var spr := f as Sprite3D
		if spr.material_override != null and not (spr.material_override is ShaderMaterial):
			med_override.append(spr.name)
		# Alfan ska antingen KLIPPS (fast figur, skarp kant mot väggarna) eller BLANDAS (genomsläpp,
		# se FIENDE_LOOK). Klippning på en genomsläpplig figur ger inget genomsläpp alls.
		var vill_klippa: int = SpriteBase3D.ALPHA_CUT_DISCARD if spr.modulate.a >= 1.0 \
			else SpriteBase3D.ALPHA_CUT_DISABLED
		if not spr.shaded or spr.alpha_cut != vill_klippa:
			utan_figurmaterial.append("%s (alfa %.2f, klipp %d)" % [spr.name, spr.modulate.a, spr.alpha_cut])
	check(figurer.size() > 0 and med_override.is_empty(),
		"ingen fiende har ett material_override av fel sort (%d av %d — 73 px mot 22 641 px i mätprovet)"
		% [med_override.size(), figurer.size()], ", ".join(med_override.slice(0, 3)))
	check(utan_figurmaterial.is_empty(),
		"figuren skuggas av lyktan och klipper sin alfa (%d av %d fel)"
		% [utan_figurmaterial.size(), figurer.size()], ", ".join(utan_figurmaterial.slice(0, 3)))
	# EGEN LOOK (M70). Alex: *"så spökena t ex är transparenta? dock bara någon procent, och inte
	# genomskinliga"*. Mätt i samma scen: 30 179 px skiljer sig åt mellan 6 procent genomsläpp och
	# helt fast, och figurens medel ljusnar 1,6 steg (väggen bakom anas). Provet bevakar mekanismen:
	# ett genomsläpp måste BLANDAS (alfa-klippning ger inget genomsläpp alls) och ingen fiende får
	# vara en hinna — under 0,85 är den inte en varelse längre.
	var blandade := 0
	var klippt_genomsläpp: Array = []
	var för_tunna: Array = []
	for f in figurer:
		var spr := f as Sprite3D
		var alfa := spr.modulate.a
		if alfa >= 1.0:
			continue
		blandade += 1
		if spr.alpha_cut != SpriteBase3D.ALPHA_CUT_DISABLED:
			klippt_genomsläpp.append(spr.name)
		if alfa < 0.85:
			för_tunna.append("%s %.2f" % [spr.name, alfa])
	check(blandade > 0, "någon fiende har genomsläpp (%d av %d — annars mäter kontrollen inget)"
		% [blandade, figurer.size()])
	check(klippt_genomsläpp.is_empty(),
		"genomsläppet BLANDAS, det klipps inte (%d av %d fel)"
		% [klippt_genomsläpp.size(), figurer.size()], ", ".join(klippt_genomsläpp.slice(0, 3)))
	check(för_tunna.is_empty(), "ingen fiende är en hinna (alfa under 0,85): %s"
		% ", ".join(för_tunna.slice(0, 3)))
	# DROPSHADOWEN STÅR STILL (M71). Alex: *"en platta som åker upp och ned? Det ser lite märkligt ut"*
	# — skuggan låg målad i figurens ruta och följde med i andningen. Provet mäter motsatsen: höjden
	# ska ligga på golvet och INTE röra sig medan figuren andas, men x/z ska följa figuren (striden
	# ställer upp den på en ny plats).
	# MASKEN (M73): en fiende MED maskfil får ett material, en UTAN får inget. Provet läser riktiga
	# filer, så det biter även när ingen maskad fiende råkar stå i våningens strid — och det mäter
	# rutnätet: masken måste ha samma storlek som arket, annars hamnar glansen på fel kroppsdel.
	var maskade: Array = []
	var fel_mask: Array = []
	for fil in DirAccess.get_files_at("res://assets/enemies"):
		if not fil.ends_with("_mask.png"):
			continue
		var id := fil.trim_suffix("_mask.png")
		var tex: Texture2D = main._enemy_tex(id)
		var l: Sprite3D = main._fiende_lager(id, tex)
		if l == null:
			fel_mask.append("%s (inget lager)" % id)
			continue
		# Lagret klipper sin ruta ur arket, så texturerna SKA vara AtlasTexture — och masken ska ha
		# exakt samma rutnät som konsten, annars hamnar glansen på fel kroppsdel.
		var ark: Texture2D = l.texture
		var m := l.material_override as ShaderMaterial
		var msk: Texture2D = m.get_shader_parameter("mask") if m != null else null
		var fel_ruta: bool = not (ark is AtlasTexture) or not (msk is AtlasTexture) \
			or (ark as AtlasTexture).atlas.get_width() != (msk as AtlasTexture).atlas.get_width() \
			or (ark as AtlasTexture).atlas.get_height() != (msk as AtlasTexture).atlas.get_height()
		# Rutan följer figuren: sätts regionen fel visar lagret en annan kroppsdel.
		main._ruta_lager(l, 3)
		var region: Rect2 = (ark as AtlasTexture).region
		if fel_ruta or absf(region.position.x - ark.get_width() * 3.0) > 0.5:
			fel_mask.append("%s (rutnätet stämmer inte)" % id)
		maskade.append(id)
	check(not maskade.is_empty(), "någon fiende har en materialmask (%d st)" % maskade.size())
	check(fel_mask.is_empty(), "varje mask har rätt rutnät och följer figurens ruta (%s)" % ", ".join(fel_mask))
	check(main._fiende_lager("skitterling", main._enemy_tex("skitterling")) == null,
		"en fiende UTAN maskfil får inget lager (Godots egen väg behålls)")
	# AURAN (M74): andarna bär sin aura som en KANT ur maskens A-kanal (se fiende_material.gdshader).
	# Utan A-kanalen finns ingen aura alls, och en borttagen rad i generatorns MATERIAL-plan vore
	# annars TYST: masken skulle bara sluta skrivas och figuren se lite tråkigare ut. Provet läser
	# A-kanalen i de riktiga filerna — fem andar ska ha den, metallen ska inte ha någon.
	var utan_aura: Array = []
	for id in ["candlewisp", "salt_wretch", "bell_drowned", "hollow_choir", "pale_reaper"]:
		var fil := "res://assets/enemies/%s_mask.png" % id
		if not ResourceLoader.exists(fil):
			utan_aura.append("%s (ingen maskfil)" % id)
			continue
		var bild := Image.load_from_file(ProjectSettings.globalize_path(fil))
		var aura_px := 0
		for y in range(bild.get_height()):
			for x in range(bild.get_width()):
				if bild.get_pixel(x, y).a > 0.5:
					aura_px += 1
		if aura_px < 1000:
			utan_aura.append("%s (%d px aura)" % [id, aura_px])
	check(utan_aura.is_empty(), "fem andar har en aura i sin mask (A-kanalen)", ", ".join(utan_aura))
	var järn := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/enemies/copper_warden_mask.png"))
	var järn_aura := 0
	for y in range(järn.get_height()):
		for x in range(järn.get_width()):
			if järn.get_pixel(x, y).a > 0.5:
				järn_aura += 1
	check(järn_aura == 0, "en metallfiende har ingen aura (bandet gäller per fiende)", "%d px" % järn_aura)
	# GLANSEN (M72): en aura/glans är en ADDITIV quad med emission över 1,0 — en unshaded yta kan
	# aldrig bli ljusare än vitt och då har glow inget att arbeta med. Provet bevakar just det: rätt
	# blandning, emission över 1,0 och att den sitter som BARN till figuren (den ska andas med den).
	var glansar := main.get_tree().get_nodes_in_group("fiende_glans")
	check(not glansar.is_empty(), "någon fiende har en glans/aura (%d st)" % glansar.size())
	# Styrkan är en smaksak, inte ett krav: glaset ligger på 0,90 och metallglinten på 1,5-1,6 (över
	# 1,0 = HDR = blomstrar). Vid 1,5 på en STOR fläck mättes en utfrätt vit klump (medel 98,8 och
	# 6 049 px över 240 i utsnittet) — samma siffra på en liten fläck är en glint. Provet kräver
	# därför det som ÄR mekanismen: additiv blandning, per-pixel skuggning (den enda vägen till HDR)
	# och att quaden sitter som barn till figuren.
	# Andarnas aura går INTE den här vägen sedan M74 (den är en kant ur materialmasken) — fläcken här
	# är glas, metall och den våta glansen.
	var fel_glans: Array = []
	for g in glansar:
		var gs := g as Sprite3D
		var gm := gs.material_override as StandardMaterial3D
		if gm == null or gm.blend_mode != BaseMaterial3D.BLEND_MODE_ADD \
				or gm.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
				or gs.get_parent() == null or not (gs.get_parent() is Sprite3D):
			fel_glans.append(gs.name)
	check(fel_glans.is_empty(), "auktor: additiv, per-pixel och barn till figuren (%s)"
		% ", ".join(fel_glans))
	var skuggor := main.get_tree().get_nodes_in_group("fiende_skugga")
	check(skuggor.size() == figurer.size(), "varje fiende har en egen skugga (%d skuggor, %d figurer)"
		% [skuggor.size(), figurer.size()])
	if not skuggor.is_empty():
		var sk0 := skuggor[0] as Sprite3D
		var höjd_före := sk0.position.y
		var spr0 := figurer[0] as Sprite3D
		var x_före := spr0.position.x
		for i in 30:
			await process_frame
		var spr_y := spr0.position.y
		check(absf(sk0.position.y - höjd_före) < 0.0001,
			"skuggan står STILL i höjdled medan figuren andas (%.4f, figurens y %.3f)"
			% [sk0.position.y, spr_y])
		# Golvplattan är 4 cm tjock (topp på 0,04) — under den försvinner skuggan helt (mätt: den låg
		# osynlig på 0,012 först). Över 0,10 m börjar den sväva.
		check(höjd_före > 0.04 and höjd_före < 0.10, "och den ligger på golvet (%.3f m)" % höjd_före)
		check(sk0.texture != null and sk0.visible,
			"skuggan har en textur och syns (%s, syns %s, %dx%d px)"
			% ["ja" if sk0.texture != null else "NEJ", str(sk0.visible),
				sk0.texture.get_width() if sk0.texture != null else 0,
				sk0.texture.get_height() if sk0.texture != null else 0])
		spr0.position.x = x_före + 1.0
		await process_frame
		check(absf(sk0.position.x - spr0.position.x) < 0.001,
			"skuggan följer figurens x när striden ställer upp den")
		spr0.position.x = x_före

	print("")
	print("— statusblocket —")
	check(main.hud_status != null and main.hud_status.visible, "statusblocket syns")
	check(main.hud_status.porträtt.texture != null, "porträttet är laddat (assets/ui/portratt.png)")
	# KÄRLEN (M51): hälsa, mana och rustning som nivåer man ser på håll, i sidomarginalerna. Provet
	# mäter att de SYNS, att de ligger i marginalen (aldrig över spelvyn) och att nivån följer VÄRDET —
	# halva livet ska ge ett halvfyllt kärl.
	## ALLA TRE KÄRLEN PÅ SAMMA SIDA (efter M64). Alex: *"Lägg hälsa och mana på samma sida, det
	## krockar med allt annat på höger sida"*. Hälsan är det stora kärlet; manan och rustningen delar
	## platsen under den och är därför mindre. Mätningen nedan fångar två fel jag själv gjorde på
	## vägen: ett kärl som hamnade 32 px utanför fönstret, och ett kärl som delade plats med kartan.
	var kärl := [main.orb_hp, main.orb_mana, main.rust_bar]
	for k in kärl:
		check(k != null and k.size.x > 60.0, "kärlet syns och har en ruta",
			"%.0fx%.0f @ %.0f,%.0f" % [k.size.x, k.size.y, k.position.x, k.position.y])
		check(k.visible, "kärlet är synligt i strid")
		check(k.get_rect().end.x <= vy.position.x or k.position.x >= vy.end.x,
			"kärlet ligger i sidomarginalen, inte över spelvyn",
			"kärl %s mot vyn %s" % [str(k.get_rect()), str(vy)])
		check(k.get_rect().position.x >= 0.0 and k.get_rect().end.x <= fönster.x,
			"kärlet ryms helt i fönstret", "%s mot fönstret %.0f brett" % [str(k.get_rect()), fönster.x])
	# Hälsokärlet är ALDRIG mindre än manan (manan krymper efter utrymmet; i ett läge utan korthögar
	# ryms båda i full storlek, och då är lika stort rätt svar).
	check(main.orb_hp.size.x >= main.orb_mana.size.x,
		"hälsokärlet är minst lika stort som manan", "%.0f mot %.0f" % [main.orb_hp.size.x, main.orb_mana.size.x])
	check(main.orb_mana.get_rect().end.x <= vy.position.x and main.rust_bar.get_rect().end.x <= vy.position.x,
		"hälsa, mana och rustning står på SAMMA sida (vänster)",
		"mana %s, rust %s" % [str(main.orb_mana.get_rect()), str(main.rust_bar.get_rect())])
	check(main.orb_mana.visible and main.rust_bar.visible, "mana och rustning syns i strid")
	# MANAPOOLENS TAK (M80). Alex: *"Där det står 3/7, vad är det?"* — orben visade `run.base_mana + 4`,
	# ett HÅRDKODAT +4 som bara råkade stämma för en spelare med exakt +4 i startmana. Taket ska vara
	# stridens egen pool, samma tal som `Combat.start_turn` fyller till varje tur.
	check(main.active_combat != null, "striden finns när kärlen mäts")
	if main.active_combat != null:
		var s_i_strid: Dictionary = main._status_data(main.run.hp, true)
		var pool: int = main.active_combat.base_mana + main.active_combat.mana_bonus
		check(int(s_i_strid["mana_max"]) == pool,
			"manakärlets tak är stridens pool, inte ett hårdkodat +4",
			"%d mot %d" % [int(s_i_strid["mana_max"]), pool])
	# PARET STÅR SIDA VID SIDA (M75). Alex: *"gör både hälsa och mana mindre så de får plats bredvid
	# varandre, men ändå som klot"*. Hälsan och manan ska ha samma storlek och samma höjd, manan till
	# höger om hälsan.
	check(is_equal_approx(main.orb_hp.size.x, main.orb_mana.size.x)
			and absf(main.orb_hp.position.y - main.orb_mana.position.y) < 2.0
			and main.orb_hp.get_rect().end.x <= main.orb_mana.position.x,
		"hälsan och manan står sida vid sida i samma storlek",
		"hp %s, mana %s" % [str(main.orb_hp.get_rect()), str(main.orb_mana.get_rect())])
	# KROCKEN I FLERA FÖNSTER (M75). Felet Alex såg ("Den använda korthögen ligger över mana") kom av
	# att HP-kärlet ALLTID hade full storlek medan bara manan krympte, och av att klämmen mot korthögen
	# hoppades över när högens överkant låg ovanför den fria ytan. Vilken fönsterstorlek han såg det i
	# går inte att gissa, så provet mäter krocken i fyra: kärlen mot varandra, mot korthögarna och mot
	# fönsterkanten.
	var storlekar := [Vector2i(1280, 720), Vector2i(1896, 1030), Vector2i(1600, 900), Vector2i(1024, 768)]
	var krockar: Array = []
	var värde_utanför: Array = []
	for st in storlekar:
		root.size = st
		main.get_viewport().size = st
		main._placera_vy()
		await process_frame
		var par: Array = [["hp", main.orb_hp], ["mana", main.orb_mana], ["rust", main.rust_bar]]
		for i in par.size():
			var a: Rect2 = par[i][1].get_rect()
			# SIFFRAN sitter i kärlets mitt. I ett fönster vars marginal är för smal för två kärl i
			# bredd (1024x768 ger 32 px marginal) klipps kanten — men mitten, alltså själva värdet,
			# måste ligga innanför fönstret. Det är skillnaden mellan ett litet kärl och ett kärl som
			# inte syns alls.
			var mitten: Vector2 = a.get_center()
			# Bara i fönster där marginalen KAN bära två kärl (>= 1280 px brett): i 1024x768 är
			# marginalen 32 px och två kärl med stenkant är 86 px, alltså får något klippas hur man än
			# lägger dem. Där mäts i stället att värdet inte hamnar utanför VÄNSTERKANTEN.
			if st.x >= 1280 and (mitten.x < 0.0 or mitten.y < 0.0
					or mitten.x > float(st.x) or mitten.y > float(st.y)):
				värde_utanför.append("%s i %s (%s)" % [par[i][0], st, str(a)])
			elif a.position.x < -1.0 or a.position.y < -1.0:
				värde_utanför.append("%s utanför övre vänstra hörnet i %s (%s)"
					% [par[i][0], st, str(a)])
			for j in range(i + 1, par.size()):
				var b: Rect2 = par[j][1].get_rect()
				if a.intersects(b) and a.intersection(b).get_area() > 1.0:
					krockar.append("%s mot %s i %s" % [par[i][0], par[j][0], st])
			for h in [main.hog_drag, main.hog_använd]:
				if h == null or not h.visible:
					continue
				var hr: Rect2 = h.get_rect()
				if a.intersects(hr) and a.intersection(hr).get_area() > 1.0:
					krockar.append("%s mot korthögen i %s" % [par[i][0], st])
	check(krockar.is_empty(),
		"hälsa, mana och rustning krockar inte med korthögarna eller varandra i någon av fyra storlekar",
		", ".join(krockar.slice(0, 4)))
	check(värde_utanför.is_empty(), "och värdet i varje kärl ligger innanför fönstret i alla fyra",
		", ".join(värde_utanför.slice(0, 4)))
	# Tillbaka till provets eget fönster: resten av provet mäter layouten i 1280x720.
	root.size = Vector2i(1280, 720)
	main.get_viewport().size = Vector2i(1280, 720)
	main._placera_vy()
	await process_frame
	check(main.hud_status.vital_label.text.contains("HP"),
		"sifferraden står kvar i statusblocket", main.hud_status.vital_label.text)
	var max_hp: float = main.active_combat.max_hp
	main.active_combat.hp = max_hp * 0.5
	main._hud_sätt(main.active_combat.hp, true)
	await process_frame
	check(absf(main.orb_hp.nivå() - 0.5) < 0.01, "HP-kärlet är halvfullt när livet är halvt",
		"%.2f för %.0f/%.0f" % [main.orb_hp.nivå(), main.active_combat.hp, max_hp])
	check(main.hud_status.vital_label.text.contains("%.0f" % (max_hp * 0.5)),
		"och siffran i blocket säger samma sak", main.hud_status.vital_label.text)
	main.active_combat.hp = max_hp
	main._hud_sätt(max_hp, true)
	await process_frame
	check(main.orb_hp.nivå() > 0.99, "och fullt när livet är fullt", "%.2f" % main.orb_hp.nivå())

	print("")
	# FIENDERUTAN FINNS INTE LÄNGRE (M68). Alex: *"Rutan där det står Candlewisp ... den är lite
	# överflödig"* och sedan ett rakt besked: *"nr 3 kan du ta bort, den är överflödig"*. Kvar av
	# målrutan är MÅLET — namnet loggen skriver och bilden som ska finnas i assets/enemies.
	print("— målet —")
	var d: Dictionary = main._fiende_data(true)
	print("      mål: %s %.0f/%.0f, bild %s" % [str(d.get("namn", "")), float(d.get("hp", 0.0)),
		float(d.get("max_hp", 0.0)), "ja" if d.get("textur", null) != null else "nej"])
	check(not d.is_empty(), "striden har ett mål att namnge i loggen")
	check(d.get("textur", null) != null, "målets bild är laddad ur assets/enemies",
		"assets/enemies/%s.png" % str(d.get("id", d.get("namn", "?"))))
	var namn: String = str(d.get("namn", ""))
	check(namn != "" and namn != "null", "målet har ett namn", namn)
	check(main._fiende_data(false).is_empty(), "utanför en strid finns ingen fiende att visa")

	print("")
	print("— kortvalet (level up) lägger sig fritt ovanför handen —")
	# Alex: *"När man får välja kort vid vinst/level up så verkar kortet flytta på sig till vänster, och
	# täcker över det som låg där innan, och går inte att flytta på."* Valkorten och handens kort ligger
	# båda i FÖNSTRETS yta (`_runt`), så rutorna jämförs som de är.
	# Mätt före rättningen: valets nederkant 630, handens överkant
	# 586 — 44 px överlapp, och det vänstra valkortet låg under ett handkort och stal klicket.
	check(main.hand_views.size() > 0, "handen har kort när valet kommer (annars mäter kontrollen inget)",
		"%d kort" % main.hand_views.size())
	main.run.xp = Progress.xp_total(main.run.level + 1)
	main.run._check_level()
	main._show_draft()
	await process_frame
	await process_frame
	check(main.draft_panel.visible, "valpanelen syns när ett val väntar")
	# VALET LIGGER I FÖNSTRETS YTA (`_runt`), som handens kort — rutan är redan i fönsterpx. Förut låg
	# valet i vyn och räknades om med `_vy.get_screen_transform()`.
	var vr := Rect2(main.draft_panel.global_position, main.draft_panel.size)
	print("      valpanelen i fönstret: %s" % str(vr))
	var handtopp := 9999.0
	var krock := 0.0
	for v in main.hand_views:
		if not is_instance_valid(v):
			continue
		var kr := Rect2(v.global_position, v.size * v.scale)          # redan i fönsterpx
		handtopp = minf(handtopp, kr.position.y)
		krock = maxf(krock, vr.intersection(kr).get_area())
	print("      handens överkant %.0f, valets nederkant %.0f, överlapp %.0f px" % [handtopp, vr.end.y, krock])
	# VALET SKA RYMMAS I FÖNSTRET. Sedan korten blev 80 % större ryms inte både kortet och rubriken
	# ovanför handen (vyn är 270 px, panelen står på 40 och handens kort börjar på 189) — därför mäts
	# det som spelaren faktiskt förlorar på: att valet hamnar utanför bild eller att klicket far fel.
	var skärm := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	check(skärm.encloses(vr), "valet ryms i fönstret", "%s i %s" % [str(vr), str(skärm)])
	# KLICKET, inte geometrin: Alex' fel (M34) var att valkortet låg UNDER ett handkort och stal
	# klicket. Handen viker nu undan medan valet står uppe (se main._show_draft), så inget SYNLIGT
	# handkort kan ligga över ett valkort — och klicket provas på riktigt: samma väg som en riktig mus
	# (pekaren flyttas och händelsen skickas till fönstret, inte till funktionen tangenten använder).
	var överlapp: CardView = null
	var bäst := 0.0
	var klickbar: CardView = null
	for barn in main.draft_box.get_children():
		if barn is not CardView:
			continue
		var r := Rect2(barn.global_position, barn.size * barn.scale)
		if r.intersection(vr).get_area() > 0.0:
			klickbar = barn as CardView
		for v in main.hand_views:
			if not is_instance_valid(v) or not v.is_visible_in_tree():
				continue
			var a := r.intersection(Rect2(v.global_position, v.size * v.scale)).get_area()
			if a > bäst:
				bäst = a
				överlapp = barn as CardView
	check(överlapp == null, "inget SYNLIGT handkort ligger över ett valkort", "%.0f px överlapp" % bäst)
	check(klickbar != null, "minst ett valkort ligger i vyn (annars mäter kontrollen inget)")
	# VALKORTEN SKA RYMMAS I VYN. Fyra kort i nästan full storlek behöver 616 px i en 480 px-vy, och
	# då klipptes det fjärde kortet av mot panelens kant (sett i granskningen: bara kostnadssiffran
	# syntes). Taket på valkortets skala räknar därför även på bredden.
	var utanför := 0
	for barn in main.draft_box.get_children():
		if barn is not CardView:
			continue
		var r2 := Rect2(barn.global_position, barn.size * barn.scale)
		if not skärm.encloses(r2):
			utanför += 1
	check(utanför == 0, "alla valkort ryms i fönstret", "%d kort utanför" % utanför)
	# DENSITETEN (Alex: "pixeltätheten på korten behöver dubbleras eller mer, för de är suddiga
	# idag"). Valet ritas i FÖNSTERPIXLAR: kortet är minst sin egen designstorlek, och panelen täcker
	# exakt vyns ruta. Förut krymptes kortet till 0,745 av designen i vyn och skalades upp 2x — texten
	# rastrerades på 5-7 px och förstorades, vilket är det som såg suddigt ut.
	var valskala: float = 0.0
	for barn in main.draft_box.get_children():
		if barn is CardView:
			valskala = (barn as CardView)._skala
			break
	check(valskala >= 1.0, "valkortet ritas i minst sin egen storlek (ingen uppskalning)",
		"skala %.2f" % valskala)
	var vyn_skala: float = maxf(1.0, floorf(minf(skärm.size.x / main.VY.x, skärm.size.y / main.VY.y)))
	check(vr.size == Vector2(main.VY) * vyn_skala and vr.position == main._vy_korg.position,
		"valet täcker vyns ruta i fönsterpixlar", "%s (vyn på %s)" % [str(vr), str(main._vy_korg.position)])
	# KONSTENS PIXLAR: ritas i hela steg, annars blir de olika breda (mätt i bild före rättningen:
	# block av 2, 3, 4 och 5 px om varandra).
	var provtextur := PlaceholderTexture2D.new()
	provtextur.size = Vector2(64, 64)
	var ikon := CardView.Ikon.new()
	ikon.textur = provtextur
	ikon.size = Vector2(180, 150)
	check(ikon.steg() == 2, "ikonens konst ritas i hela steg (2x av 64 px i en 180x150-ruta)",
		"steg %d" % ikon.steg())
	ikon.size = Vector2(20, 20)
	check(ikon.steg() == 0, "och skalas ned proportionellt när rutan är mindre än konsten",
		"steg %d" % ikon.steg())
	# SJÄLVA KLICKET mäts inte här: i det här provet (som startas med ett fönster och ett konstlat
	# val) når den simulerade musen inte fram till valkortet, medan SAMMA kod i `-- vinstprov` gör det
	# — där klickas ett valkort efter en riktig strid och valet går från 4 till 0. Att tvinga fram ett
	# grönt svar här hade varit att mäta sin egen koordinatmiss; klicket mäts i provet som spelar.
	print("")
	print("— loggen —")
	check(main.hud_logg != null and main.hud_logg.visible, "loggen syns")
	main.hud_logg.töm()
	main._logga("första", Palett.c(11))
	main._logga("andra", Palett.c(14))
	await process_frame
	check(main.hud_logg.innehåll() == ["första", "andra"], "raderna kommer i ordning",
		str(main.hud_logg.innehåll()))
	for i in HudLogg.RADER + 2:
		main._logga("rad %d" % i, Palett.c(23))
	await process_frame
	var inne: Array = main.hud_logg.innehåll()
	check(inne.size() == HudLogg.RADER, "loggen håller bara sina rader (ringen)", "%d rader" % inne.size())
	check(str(inne[inne.size() - 1]) == "rad %d" % (HudLogg.RADER + 1), "den NYASTE raden står sist",
		str(inne[inne.size() - 1]))
	check(not str(inne[0]).begins_with("första"), "den äldsta raden har fallit ut", str(inne[0]))
	main.hud_logg.töm()
	await main._on_card(0)
	await process_frame
	print("      efter ett spelat kort: %s" % str(main.hud_logg.innehåll()))
	check(not main.hud_logg.innehåll().is_empty(), "ett spelat kort ger en loggrad")

	print("")
	print("— läget (mäts bara med ett fönster som rymmer vyn) —")
	if not måttbart():
		print("      hoppar över: fönstret är %.0fx%.0f och rymmer inte spelvyn (%s) — mäts i -- guiprov"
			% [fönster.x, fönster.y, str(vy)])
	else:
		var s := ruta(main.hud_status)
		var l := ruta(main.hud_logg)
		print("      status %s | logg %s" % [str(s), str(l)])
		check(s.end.y <= vy.position.y, "statusblocket ligger OVANFÖR spelvyn",
			"underkant %.0f mot vyns överkant %.0f" % [s.end.y, vy.position.y])
		check(l.position.y >= vy.end.y, "loggen ligger UNDER spelvyn")
		check(l.end.x <= fönster.x * 0.5, "loggen ligger till vänster om mitten")
		for n in [main.hud_status, main.hud_logg]:
			check(not överlappar(ruta(n), vy), "%s ritar ingenting inne i spelvyn" % n.name)
		# Korten äger mitten nedtill: ingen ruta får ligga över handen.
		for v in main.hand_views:
			var k := ruta(v)
			check(not överlappar(k, l), "kortet %d krockar inte med loggen" % v.index)

	## SLUTSKÄRMEN (M48): bara dödade fiender och guld — och sedan tillbaka till byn. Butikslistan
	## hör till byn. Alex: *"Här skall man bara få information om hur många man dödat, hur mycket
	## guld man fick in, och sen tillbaka till byn."* Provet mäter TEXTEN, för det var texten han
	## pekade på i skärmdumpen. Sist i provet: körningen markeras som slut och sätts tillbaka efter.
	print("")
	print("— slutskärmen —")
	main.run.kills = 7
	main.run.gold = 123
	# `finished` rörs INTE: flaggan startar slutskärmens egen väg genom spelet, och provet skulle
	# hamna i en väntan på en bildruta som aldrig kommer (mätt: exit 124). Texten byggs direkt.
	main._unlocked_now = ""
	var slut: String = main._end_text()
	check(slut.contains("7 fiender dödade") and slut.contains("123 guld"),
		"slutskärmen visar dödade fiender och guld in", slut.replace("\n", " | "))
	check(not slut.contains("guld i banken"),
		"slutskärmen visar inte butikslistan", slut.replace("\n", " | "))
	check(slut.contains("tillbaka till byn"), "slutskärmen visar vägen tillbaka till byn",
		slut.replace("\n", " | "))

	## SALDOT (M61). Alex: *"Ingenstans visas det hur mycket gold man har, så det är omöjligt att veta
	## om man har råd eller ej."* Raden fanns i koden och fylldes med rätt text — men etiketten var
	## `visible = false` och sattes aldrig på, så den syntes i ingen skärm (mätt: byn hade ingen text
	## om guld alls). Provet mäter därför SYNLIGHETEN, talet mot metat, och att raden inte ligger över
	## en panel som redan bär saldot i sin egen rubrik.
	print("")
	print("— saldot —")
	main.shell = "hem"
	main._refresh_shell()
	var saldo: String = main.top_label.text
	check(main.top_label.visible, "saldot SYNS i byn (den var osynlig förut)")
	check(saldo.contains(str(main.meta.gold)), "och raden säger samma guld som metat", saldo)
	check(saldo.contains(str(main.meta.shards)), "…och samma splitter", saldo)
	# VALUTARADEN SYNS ÖVERALLT UTOM I KÖRNINGEN (M95, Alex: *"Guld, Splitter och andra valutor inte
	# visas. Det måste de."*). Den låg förut bara på hem/karta/album — alltså var den borta i butiken,
	# i världshuset, hos smeden och hos juveleraren: exakt de skärmar där man handlar.
	main.shell = "smed"
	main._refresh_shell()
	check(main.top_label.visible, "saldot syns även hos smeden")
	main.shell = "juvelerare"
	main._refresh_shell()
	check(main.top_label.visible, "och hos juveleraren")
	main.shell = "trad"
	main._refresh_shell()
	check(main.top_label.visible, "och i trädet")
	check(main.top_label.text.contains("CS"), "och raden visar CS också", main.top_label.text)
	# ESC TILLBAKA TILL BYN FRÅN VARJE SKÄRM (M95). Alex: *"Varje del måste gå att backa ur tillbaka
	# till byn med antingen en knapp för exit, eller med esc-knappen."* Provet går igenom skalets
	# alla lägen i stället för att lita på att någon lade in en gren per skärm — det är precis den
	# sortens glömska som gör en skärm till en återvändsgränd. Körningen är undantagen (ESC = meny).
	var utan_väg_tillbaka := []
	for läge in main.SKAL_LÄGEN:
		main.shell = str(läge)
		main._refresh_shell()
		main._input_shell(KEY_ESCAPE)
		if main.shell != "hem" and str(läge) != "körning":
			utan_väg_tillbaka.append(str(läge))
	check(utan_väg_tillbaka.is_empty(), "ESC leder tillbaka till byn från varje skärm",
		"fastnade i: %s" % str(utan_väg_tillbaka))
	# TRÄDETS RUTNÄT HAR FLER ÄN EN RAD (M95). Alex' skärmbild visade fjorton ikoner på EN rad högst
	# upp i en svart ruta: vyn ärvde PanelContainer, och en Container äger sin storlek — den krympte
	# till sitt innehåll och struntade i den size skalet satte, så rutnätet fick ingen bredd. Nu mäts
	# det i stället för att tros: ikonernas globala rutor skall spänna över både höjd och bredd.
	# Vyns form mäts, inte ikonernas pixelpositioner: containrar lägger ut sina barn först i nästa
	# bildruta, och provet kör i samma. Det som avgör om rutnätet får en bredd är VILKEN KLASS vyn
	# är — en Container äger sin storlek och krympte till en rad, en Control tar den size skalet ger.
	main.shell = "trad"
	main._refresh_shell()
	check(not (main.trad_view is PanelContainer),
		"trädvyn är en Control (en Container äger sin storlek och krympte rutnätet till en rad)")
	check(not main.trad_view._snäpp.is_empty(),
		"socketdatan från tools/gen_tree_sockets.py är läst (25 mätta sockets)", "%d" % main.trad_view._snäpp.size())
	check(main.trad_view._snäpp.has("iron_1") and float(main.trad_view._snäpp["iron_1"].get("score", 0)) > 0.0,
		"varje socket bär sitt mått (poängen ring minus grop)")
	check(main.trad_view._platta is TextureRect and main.trad_view._platta.texture != null,
		"trädvyn har referensbilden som platta (socketsen sitter i den)")
	check(main.trad_view._nodplan is Control and not (main.trad_view._nodplan is Container),
		"noderna ligger på en fri yta, inte i en container (de ska sitta i bildens sockets)")
	# Varje nod skall ha en plats i plattan, och nivåerna skall ligga i ordning uppifrån och ner.
	var ytor := {}
	for tnid in main.trad_view._ikoner:
		var tnod: Control = main.trad_view._ikoner[tnid]
		var trad_rad: Dictionary = main.trad_view._rader[tnid]
		ytor[int(trad_rad.get("nivå", 0))] = tnod.position.y
		check(tnod.position.x >= 0.0 and tnod.position.y >= 0.0
			and tnod.position.x + tnod.size.x <= main.trad_view.size.x
			and tnod.position.y + tnod.size.y <= main.trad_view.size.y,
			"noden %s ligger inne i vyn" % tnid, "%s" % tnod.position)
	check(ytor.size() == 6, "sex nivåer har noder", "%d" % ytor.size())
	var nivåer: Array = ytor.keys()
	nivåer.sort()
	var stigande := true
	for i in range(1, nivåer.size()):
		if float(ytor[nivåer[i]]) <= float(ytor[nivåer[i - 1]]):
			stigande = false
	check(stigande, "nivå 1 ligger ovanför nivå 6 (nivån bestämmer höjden, inte ordningen i datat)")
	check(main.trad_view._ikoner.size() > 0, "och ikonerna hamnade i dem",
		"%d ikoner" % main.trad_view._ikoner.size())
	# Ingen kontroll för flaggan -- skarm=<namn>: den läser SKAL_LÄGEN nu, och att kontrollera att en
	# lista innehåller sig själv är ingen kontroll. Felet den avskaffade var att listan fanns i två
	# exemplar, varav det ena glömde trädet.
	# Provet lämnar skalet i byn igen: nästa kontroll mäter juvelerarpanelen i spelvyn, och stod
	# skalet kvar i ett annat läge mättes fel skärm (panelen var 884 px i en 480 px vy).
	main.shell = "hem"
	main._refresh_shell()
	# JUVELERAREN (M58) ryms i vyn. Texten växte från sex rader till nio när facken och fickan byggdes
	# ut, men panelen centreras i spelvyn — blev den högre än 270 px klipptes rubriken (guld och fack)
	# i överkant och kortraden i underkant. Mätt på Alex' skärmbild 23 sep. Måttet står här så en
	# framtida rad i panelen inte tyst knuffar ut texten igen.
	var jr: Rect2 = Rect2(main.jewel_panel.position, main.jewel_panel.size)
	print("    juveleraren: panelen %.0fx%.0f px, y %.0f..%.0f, vyn är %.0f hög"
		% [jr.size.x, jr.size.y, jr.position.y, jr.end.y, main.VY.y])
	check(jr.position.y >= -0.5 and jr.end.y <= float(main.VY.y) + 0.5,
		"juvelerarpanelen ryms i spelvyn i höjd", "y %.0f..%.0f av %.0f" % [jr.position.y, jr.end.y, main.VY.y])
	check(jr.position.x >= -0.5 and jr.end.x <= float(main.VY.x) + 0.5,
		"och i sidled (tipsraden var 1236 px på en rad)", "x %.0f..%.0f av %.0f" % [jr.position.x, jr.end.x, main.VY.x])
	# THE BENCH (23 Sep): Alex drew a plank surface and wants the shop's cards to lie on it. The
	# texture is loaded from disk at startup, so a missing or unimported PNG would leave a silent
	# black panel — the exact failure mode this checks. Godot only sees a new PNG after `--import`.
	var bench: Texture2D = load(main.BENCH_TEXTURE) as Texture2D
	check(bench != null and bench.get_width() > 0, "the bench texture loads from disk",
		"%s (%dx%d)" % [main.BENCH_TEXTURE, 0 if bench == null else bench.get_width(),
			0 if bench == null else bench.get_height()])
	check(main._bench_style().texture == bench, "and the shop panel draws it (StyleBoxTexture)")
	main.shell = "karta"
	main._refresh_shell()
	check(main.top_label.visible, "på kartan syns den igen (ingen panel där)")

	# RÅDFRÅGAN (M61): priset stod där förut, men svaret fanns bara att få genom att jämföra talet med
	# saldot högst upp. Nu står ✓ eller ✗ bredvid priset, räknat ur samma `affordable` som köpet.
	# M61:s rad flyttade med trädet (M95): svaret står i vyns hovringstext i stället för i en
	# textlista hos smeden, och priset är CS — trädet köps inte för guld.
	main.meta.gold = 0
	main.meta.shards = 0
	main.meta.souls = 0
	main.shell = "trad"
	main._refresh_shell()
	main.trad_view._peka("iron_1")
	var utan: String = main.trad_view._info.text
	check(utan.contains("✗"), "utan CS står ett kryss vid priset", utan)
	main.meta.souls = 100000
	main._refresh_shell()
	main.trad_view._peka("iron_1")
	var med: String = main.trad_view._info.text
	check(med.contains("✓"), "med CS står en bock vid priset", med)
	check(med.contains("CS"), "och priset står i CS, inte i guld", med)
	main.meta.souls = 0
	main.meta.gold = 0
	main.meta.shards = 0
	main.shell = "hem"
	main._refresh_shell()

	print("")
	print("%d kontroller, %d fel" % [checks, fails])
	quit(1 if fails > 0 else 0)
