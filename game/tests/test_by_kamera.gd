## BYN SOM SCEN: KAMERAN OCH LJUSET (M127).
##
## Alex: *"Detta ser verkligen inte bra ut alls — Ingen ljussättning, vinkeln är fel (behöver se ut som
## man ser i nån grad uppifrån så gatan syns med, mer inzoomat så man kommer närmare... Hade du gjort
## detta som en scen, så kunde jag editera själv."*
##
## Provet mäter det han klagade på, i fyra avsnitt:
##
##   1. SCENEN: nodträdet kommer ur `res://scenes/by.tscn` — byn.glb är en INSTANS, kameran är en
##      `Camera3D`, solljuset en `DirectionalLight3D` med skuggor och rökens emitter en nod. Provet
##      fäller om någon av dem byggs i kod i stället (då kan Alex inte flytta dem i editorn).
##   2. VINKELN: kameran är tippad nedåt, och marken är ett BAND i bilden i stället för en linje. MÄTT
##      i vyns px: med dagens kamera är marken (z 3,5 till -5,6) 40 px hög och husen 46-97 px.
##   3. KLICKYTORNA: husets ruta räknas ur modellens meshar och KAMERANS projektion, och provet räknar
##      fram SAMMA ruta med kamerans EGEN `unproject_position` (en annan väg) — glider klickytan från
##      huset faller det. Alla sex husen ska dessutom rymmas i vyn (inget hus skuret vid kanten).
##   4. LJUSET (bara när det finns en rityta — headless renderar ingenting, se test_by_rok.gd): vad
##      solen gör med bilden. Marken mäts genom att rita vyn två gånger, en gång med markens meshar
##      dolda (skillnaden ÄR marken), och skuggan genom att släcka solens skugga och mäta vad som
##      ljusnar. Och inga utbrända pixlar (> 240) i stenhusets fasad.
##
##   godot --headless --script res://tests/test_by_kamera.gd          # sviten (avsnitt 1-3)
##   DISPLAY=:99 godot --path . --script res://tests/test_by_kamera.gd # med bilden (avsnitt 4)
extends SceneTree

var fails := 0
var checks := 0

const VY := Vector2(313, 339)
## Markens framkant och bakersta synliga kant (z 3,5 = markens framkant i glb:n, -5,6 = borgmuren).
const MARK_FRAM := 3.5
const MARK_BAK := -5.6
## Markens yta är de här materialen i byn.glb (materialens NAMN, inte filnamnen: en del av glb:ns
## texturer ligger kvar inne i filen — `res://assets/by/byn.glb::ImageTexture_...` — och bara några
## bröts ut som byn_*.png. Namnet är det som gäller för alla).
const MARK_PLATTOR := ["PX_Cobblestone Grey", "PX_Cobblestone Brown", "PX_Cobblestone Mossy",
	"PX_Grass Flowers", "PX_Dirt Stony", "PX_Sand Path"]
## Stenhuset: PORTEN (Gate) är murad av sten (PX_Stone) — där mäts utbrändheten.
const STEN_PLATTA := "PX_Stone"
const MARK_PNG := "/home/alex/.hermes/cache/scratch/omd/byn_kamera.png"

func check(ok: bool, what: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])
	else:
		fails += 1
		print("  FEL  %s%s" % [what, "" if detail.is_empty() else "  (%s)" % detail])

## DET PLATTA LÄGET (före M127): rakt framifrån, ortho 34, kameran på (0,5, 3,6, 22,0). Provet ställer
## tillbaka kameran dit och mäter samma sak — det är jämförelsen som avgör om vinkeln gör någon
## skillnad, och den fäller om någon sätter tillbaka kameran.
const PLATT_LÄGE := Vector3(0.5, 3.6, 22.0)
const PLATT_BREDD := 34.0

## Materialets namn (PX_Stone, PX_Grass Flowers ...). Texturfilens namn duger inte: en del av glb:ns
## bilder ligger kvar INUTI filen (`byn.glb::ImageTexture_...`) och har ingen sökväg.
func _matnamn(m: MeshInstance3D) -> String:
	if m.mesh == null:
		return ""
	for s in m.mesh.get_surface_count():
		var mat := m.mesh.surface_get_material(s)
		if mat != null and not mat.resource_name.is_empty():
			return mat.resource_name
		if mat is BaseMaterial3D:
			var t: Texture2D = (mat as BaseMaterial3D).albedo_texture
			if t != null:
				return t.resource_path.get_file()
	return ""

func _alla_meshar(rot: Node) -> Array:
	var ut: Array = []
	for n in rot.find_children("*", "MeshInstance3D", true, false):
		ut.append(n)
	return ut

## Husen i byn (prefixet ur PLATSER: Weaver, Smith, Tavern, Gate, Jeweler, Exit).
func _husen(by: By3D) -> Dictionary:
	var ut := {}
	for p in VillageView.PLATSER:
		ut[str(p["3d"])] = by.hus_rect(str(p["3d"]))
	return ut

func _höjder(rutor: Dictionary) -> String:
	var d := []
	for k in rutor:
		d.append("%s %.0f" % [k, (rutor[k] as Rect2).size.y])
	return ", ".join(d)

## Två bilder, antalet pixlar som skiljer sig (marken, skuggan).
func _skillnad(a: Image, b: Image) -> int:
	if a == null or b == null:
		return -1
	var x: PackedByteArray = a.get_data()
	var y: PackedByteArray = b.get_data()
	if x.size() != y.size():
		return -1
	var n := 0
	for i in range(0, x.size(), 4):
		if x[i] != y[i] or x[i + 1] != y[i + 1] or x[i + 2] != y[i + 2]:
			n += 1
	return n

## En ruta av en bild, som (medel-ljushet, antal pixlar över 240).
func _ljushet(img: Image, r: Rect2i) -> Array:
	if img == null:
		return [0.0, 0]
	var summa := 0.0
	var antal := 0
	var brända := 0
	for y in range(maxi(0, r.position.y), mini(img.get_height(), r.position.y + r.size.y)):
		for x in range(maxi(0, r.position.x), mini(img.get_width(), r.position.x + r.size.x)):
			var c := img.get_pixel(x, y)
			var l := (c.r + c.g + c.b) / 3.0
			summa += l
			antal += 1
			if l > 240.0 / 255.0:
				brända += 1
	return [summa / maxf(1.0, float(antal)), brända]

## HELA BILDENS ljushet och hur mycket av den som är utbränd. Utan den här raden kan ett ljus som
## klipper hela rutan till vitt (mätt en gång: 52 % av bilden) se ut som "ljusstarkt" i stället.
func _helhetsmått(img: Image) -> Array:
	if img == null:
		return [0.0, 0]
	var d: PackedByteArray = img.get_data()
	var summa := 0.0
	var brända := 0
	var n := 0
	for i in range(0, d.size(), 4):
		var l: float = (float(d[i]) + float(d[i + 1]) + float(d[i + 2])) / 3.0
		summa += l
		n += 1
		if l > 240.0:
			brända += 1
	return [summa / maxf(1.0, float(n)), brända]

## Ritar vyn en gång och lämnar bilden. `dölj` är materialnamn vars meshar ska vara osynliga,
## `behåll` nodnamns-prefix som INTE får döljas (facklornas lågor har stenplattan — en låga får lysa,
## och den är ingen fasad), `skugga` styr solens skugga. Röken är SLÄCKT i varje mätning: den rör sig
## mellan bildrutorna och hade räknats som skillnad mellan två bilder (samma skäl som i test_by_rok.gd).
func _bild(sub: SubViewport, by: By3D, dölj: Array = [], skugga: bool = true, behåll: Array = []) -> Image:
	var undan := []
	for m in _alla_meshar(by):
		var mi := m as MeshInstance3D
		if not (_matnamn(mi) in dölj) or not mi.visible:
			continue
		var hoppa := false
		for k in behåll:
			if str(mi.name).begins_with(str(k)):
				hoppa = true
				break
		if hoppa:
			continue
		mi.visible = false
		undan.append(mi)
	var sol := by.get_node_or_null("sol") as DirectionalLight3D
	if sol != null:
		sol.shadow_enabled = skugga
	by.rök.emitting = false
	by.rök.restart()
	for i in 6:
		await process_frame
	var img: Image = sub.get_texture().get_image()
	if sol != null:
		sol.shadow_enabled = true
	for m in undan:
		(m as MeshInstance3D).visible = true
	# RGBA8: vyns textur kommer tillbaka som RGB8 (3 byte per pixel), och mätningen nedan räknar i
	# fyra byte per pixel. Utan omvandlingen läser genomdraget förbi bufferten.
	if img != null and img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

func _initialize() -> void:
	var bild := DisplayServer.get_name() != "headless"
	print("=== BYN SOM SCEN: KAMERAN OCH LJUSET ===")

	# ---------------------------------------------------------------- 1. SCENEN
	print("")
	print("— 1. scenen: kameran, ljusen och röken är NODER Alex kan flytta —")
	check(ResourceLoader.exists(By3D.SCEN), "scenen finns som fil", By3D.SCEN)
	var pack: PackedScene = load(By3D.SCEN)
	check(pack != null, "och laddar som PackedScene")
	var rå: Node = pack.instantiate()
	check(rå is By3D, "scenens rot bär interaktionsskriptet (ui/by_3d.gd)", str(rå.get_script()))
	var kam_nod := rå.get_node_or_null("kamera") as Camera3D
	check(kam_nod != null and kam_nod.get_parent() == rå,
		"kameran är en Camera3D-NOD i scenen", str(kam_nod))
	check(kam_nod != null and kam_nod.current, "och den är scenens aktuella kamera (annars ritas inget)")
	var sol_nod := rå.get_node_or_null("sol") as DirectionalLight3D
	check(sol_nod != null and sol_nod.shadow_enabled,
		"solljuset är en DirectionalLight3D med SKUGGOR", str(sol_nod))
	check(rå.get_node_or_null("måne") is DirectionalLight3D,
		"nattljuset är en egen nod", str(rå.get_node_or_null("måne")))
	check(rå.get_node_or_null("miljö") is WorldEnvironment, "miljön är scenens egen nod")
	var rök_nod := rå.get_node_or_null("rök") as GPUParticles3D
	check(rök_nod != null and rök_nod.emitting, "röken är en nod och TÄND", str(rök_nod))
	var byn_nod := rå.get_node_or_null("byn")
	check(byn_nod != null and byn_nod.scene_file_path == By3D.GLB,
		"byn.glb är en INSTANS i scenen (inte inläst i kod)", str(byn_nod.scene_file_path if byn_nod != null else ""))
	rå.free()

	# ---------------------------------------------------------------- 2. VINKELN OCH INZOOMNINGEN
	print("")
	print("— 2. vinkeln och inzoomningen —")
	var sub := SubViewport.new()
	sub.size = Vector2i(VY)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var by := By3D.new()
	sub.add_child(by)
	by.sätt_vy(VY)
	await process_frame
	check(by.kamera != null and by.by != null, "byn är byggd och kameran hittad", str(by.kamera))
	if by.kamera == null:
		print("=== TOTALT (kamera): %d kontroller, %d fel ===" % [checks, fails])
		quit(1)
		return
	var kam := by.kamera
	var lut: float = -rad_to_deg(kam.rotation.x)
	check(lut >= 20.0 and lut <= 45.0, "kameran ser UPPIFRÅN — tippad nedåt inom 20-45 grader",
		"%.0f grader" % lut)
	check(kam.projection == Camera3D.PROJECTION_ORTHOGONAL and kam.keep_aspect == Camera3D.KEEP_WIDTH,
		"ortografisk med KEEP_WIDTH (px per meter är samma överallt)",
		"projektion %d, keep %d" % [kam.projection, kam.keep_aspect])
	# HUSEN OCH MARKEN, i vyns px — med den tippade kameran och med det platta läget.
	var tippad := _husen(by)
	var mark_tippad: float = by.projicera(Vector3(0.0, 0.0, MARK_FRAM)).y - by.projicera(Vector3(0.0, 0.0, MARK_BAK)).y
	var pxm_tippad: float = VY.x / kam.size
	# Det platta läget: kameran ställs tillbaka, allt annat lika.
	var sparat := kam.transform
	var sparad_bredd := kam.size
	kam.rotation = Vector3.ZERO
	kam.size = PLATT_BREDD
	kam.position = PLATT_LÄGE
	var platt := _husen(by)
	var mark_platt: float = absf(by.projicera(Vector3(0.0, 0.0, MARK_FRAM)).y - by.projicera(Vector3(0.0, 0.0, MARK_BAK)).y)
	var pxm_platt: float = VY.x / kam.size
	kam.transform = sparat
	kam.size = sparad_bredd
	print("      husens höjd i px, tippad: %s" % _höjder(tippad))
	print("      husens höjd i px, platt:  %s" % _höjder(platt))
	print("      px/m %.2f mot %.2f; marken %.0f px mot %.0f px i en %d px hög vy" %
		[pxm_tippad, pxm_platt, mark_tippad, mark_platt, int(VY.y)])
	check(mark_platt < 1.0, "kontrollen: i det platta läget är marken en LINJE (därför syntes ingen gata)",
		"%.2f px" % mark_platt)
	check(mark_tippad >= 25.0, "med den tippade kameran är marken ett BAND i bilden — gatan syns",
		"%.0f px = %.0f %% av vyns höjd" % [mark_tippad, 100.0 * mark_tippad / VY.y])
	var tunnast := 1e9
	var höjder := []
	var utanför := []
	for p in VillageView.PLATSER:
		var k := str(p["3d"])
		var r: Rect2 = tippad[k]
		tunnast = minf(tunnast, r.size.x)
		höjder.append(r.size.y / maxf(1.0, (platt[k] as Rect2).size.y))
		if r.position.x < 0.0 or r.end.x > VY.x or r.position.y < 0.0 or r.end.y > VY.y:
			utanför.append(str(p["id"]))
	# MEDIANEN, inte det minsta: "Exit" är en SKYLT (en tunn skyltbräda) och blir inte högre av att
	# kameran tippar — husen gör det. Ingen plats får bli mindre än den var.
	höjder.sort()
	var median: float = höjder[höjder.size() / 2]
	check(höjder[0] >= 1.0 and median >= 1.2,
		"husen tar STÖRRE plats än i det platta läget (inzoomat)",
		"median %.2f gånger höjden, sämsta %.2f" % [median, höjder[0]])
	check(utanför.is_empty(), "och hela byn ryms — inget hus skuret av vid kanten",
		", ".join(utanför))
	check(kam.size <= PLATT_BREDD, "vyn är inte vidare än den platta (inzoomad eller lika bred)",
		"%.1f m mot %.1f m" % [kam.size, PLATT_BREDD])

	# ---------------------------------------------------------------- 3. KLICKYTORNA
	print("")
	print("— 3. klickytorna linjerar med husen (kamerans EGEN projektion) —")
	var fel := []
	for p in VillageView.PLATSER:
		var prefix := str(p["3d"])
		var a := by.hus_aabb(prefix)
		if a.size == Vector3.ZERO:
			fel.append("%s saknar hus" % prefix)
			continue
		for i in 8:
			var hörn := a.get_endpoint(i)
			var d: float = kam.unproject_position(hörn).distance_to(by.projicera(hörn))
			if d > 0.5:
				fel.append("%s %.2f px" % [prefix, d])
	check(fel.is_empty(), "vyns projektion och kamerans EGEN ger samma px (alla hus, alla hörn)",
		"största felet < 0,5 px" if fel.is_empty() else ", ".join(fel))
	# GATULINJEN: gångaren går på gatan, och hon ska stå på en rad som ligger i markens BAND.
	var gata := by.marklinje_px()
	var överst: float = by.projicera(Vector3(0.0, 0.0, MARK_BAK)).y
	var nederst: float = by.projicera(Vector3(0.0, 0.0, MARK_FRAM)).y
	check(gata > överst and gata < nederst, "gångarens gatulinje ligger inne i markens band",
		"%.0f px i bandet %.0f..%.0f" % [gata, överst, nederst])

	# ---------------------------------------------------------------- 4. LJUSET
	print("")
	print("— 4. ljuset: solljus med skugga på marken, och ingen utbränd fasad —")
	if not bild:
		print("  (ljusprovet hoppas över: headless renderar inget — kör med DISPLAY=:99 och --path .)")
	else:
		var full := await _bild(sub, by)
		var utan_mark := await _bild(sub, by, MARK_PLATTOR)
		var utan_skugga := await _bild(sub, by, [], false)
		var utan_sten := await _bild(sub, by, [STEN_PLATTA], true, ["Torch_"])
		# ETT GENOMDRAG över vyn. Bildens bytes läses EN gång var (get_data() kopierar hela bufferten,
		# och att kalla den per pixel hade gjort mätningen 100 000 gånger dyrare).
		var df: PackedByteArray = full.get_data()
		var dm: PackedByteArray = utan_mark.get_data()
		var ds: PackedByteArray = utan_skugga.get_data()
		var dt: PackedByteArray = utan_sten.get_data()
		# "VID HUSEN" = husens EGNA projicerade rutor utvidgade 6 px; resten är den öppna marken.
		var nära := Rect2()
		var först := true
		for p in VillageView.PLATSER:
			var r: Rect2 = (tippad[str(p["3d"])] as Rect2).grow(6.0)
			nära = r if först else nära.merge(r)
			först = false
		var mark_px := 0
		var skugga_px := 0
		var mark_skugga := 0
		var skuggad_ljus := 0.0      ## marken där solens skugga faller, MED skuggan
		var skuggad_utan := 0.0      ## samma pixlar, med solens skugga AVSTÄNGD
		var skuggad_antal := 0
		var under := 0.0             ## marken intill husen (till upplysning, inte en grind)
		var under_antal := 0
		var öppen := 0.0
		var öppen_antal := 0
		for yy in int(VY.y):
			for xx in int(VY.x):
				var i: int = (yy * int(VY.x) + xx) * 4
				var är_mark: bool = df[i] != dm[i] or df[i + 1] != dm[i + 1] or df[i + 2] != dm[i + 2]
				var i_skugga: bool = df[i] != ds[i] or df[i + 1] != ds[i + 1] or df[i + 2] != ds[i + 2]
				if är_mark:
					mark_px += 1
				if i_skugga:
					skugga_px += 1
					if är_mark:
						mark_skugga += 1
				if not är_mark:
					continue
				# SKUGGAN MÄTS PÅ SAMMA PIXLAR MED OCH UTAN SKUGGAN, inte genom att jämföra marken
				# vid husen med marken längre bort: på natten ligger fönstrens och facklornas varma
				# pooler just intill husen, så marken intill husen är LJUSARE än gatan (MÄTT: 52,8
				# mot 34,2) trots att skuggan ligger där. Att släcka skuggan och mäta SAMMA pixel
				# rensar bort både solen och lamporna och lämnar skuggans egen verkan.
				var l: float = (float(df[i]) + float(df[i + 1]) + float(df[i + 2])) / 3.0
				if i_skugga:
					skuggad_ljus += l
					skuggad_utan += (float(ds[i]) + float(ds[i + 1]) + float(ds[i + 2])) / 3.0
					skuggad_antal += 1
				if xx >= int(nära.position.x) and xx < int(nära.end.x) \
						and yy >= int(nära.position.y) and yy < int(nära.end.y):
					under += l
					under_antal += 1
				else:
					öppen += l
					öppen_antal += 1
		var px := int(VY.x) * int(VY.y)
		check(mark_px > 0, "marken RITAS (den andel av bilden som ändras när markens meshar döljs)",
			"%.1f %% av vyn (%d px)" % [100.0 * mark_px / px, mark_px])
		check(skugga_px > 0 and mark_skugga > 0,
			"solen kastar SKUGGA — marken mörknar under och bakom husen",
			"%d px skugga i hela bilden, %.2f %% av vyn; %d px på marken (%.0f %% av marken)" %
			[skugga_px, 100.0 * skugga_px / px, mark_skugga, 100.0 * mark_skugga / maxf(1.0, float(mark_px))])
		var m_skuggad: float = skuggad_ljus / maxf(1.0, float(skuggad_antal))
		var m_utan: float = skuggad_utan / maxf(1.0, float(skuggad_antal))
		check(skuggad_antal > 0, "marken i skuggan går att mäta", "%d px" % skuggad_antal)
		check(m_skuggad < m_utan, "skuggan MÖRKNAR marken — husen står PÅ marken",
			"%.1f med skuggan mot %.1f utan (%.0f %% mörkare, %d px skuggad mark)" %
			[m_skuggad, m_utan, 100.0 * (1.0 - m_skuggad / maxf(1.0, m_utan)), skuggad_antal])
		print("      till upplysning: marken intill husen %.1f mot marken längre bort %.1f (de varma "
			% [under / maxf(1.0, float(under_antal)), öppen / maxf(1.0, float(öppen_antal))]
			+ "poolerna ligger vid väggarna)")
		# STENHUSET: porten är murad av sten, och en fasad som klipper till vitt är ingen fasad. Provet
		# mäter STENPLATTANS EGNA pixlar (de som ändras när stenens meshar döljs) — inte husets ruta,
		# för i den rutan står också facklor och lyktor, och en lykta får lysa.
		var sten_px := 0
		var sten_brända := 0
		var sten_max := 0.0
		for i in range(0, df.size(), 4):
			if df[i] == dt[i] and df[i + 1] == dt[i + 1] and df[i + 2] == dt[i + 2]:
				continue
			sten_px += 1
			var sl: float = (float(df[i]) + float(df[i + 1]) + float(df[i + 2])) / 3.0
			sten_max = maxf(sten_max, sl)
			if sl > 240.0:
				sten_brända += 1
		# GRINDEN MÅSTE HA NÅGOT ATT MÄTA: en trasig dölj-lista ger noll stenpixlar, och då hade
		# kontrollen "inga utbrända pixlar" passat utan att titta på något alls. Gränsen är inte
		# noll utan en halv procent och 250 av 255: Alex får vrida på ljuset i editorn, och en grind
		# som faller för att han drar upp solen en aning är ingen hjälp. Det vita är felet (mätt en
		# gång: 52 % av hela bilden), inte en enstaka ljus pixel.
		check(sten_px >= 500 and sten_brända <= int(0.005 * sten_px) and sten_max <= 250.0,
			"ingen utbränd stenfasad (högst 0,5 % över 240, ljusaste under 251)",
			"%d stenpixlar, %d över 240, ljusaste %.0f av 255" % [sten_px, sten_brända, sten_max])
		# HELHETEN: ett ljus som klipper rutan till vitt är felet provet i test_by_rok.gd beskriver
		# (MÄTT en gång: 52 % av bilden ren vit). Här mäts samma sak på den färdiga vyn.
		var helt: Array = _helhetsmått(full)
		check(float(helt[1]) <= 0.01 * px, "och bilden är inte utbränd i stort (högst 1 % över 240)",
			"medelljushet %.0f av 255, %.2f %% över 240 (%d px)" %
			[float(helt[0]), 100.0 * float(helt[1]) / px, int(helt[1])])
		full.save_png(MARK_PNG)
		print("      bilden sparad: %s" % MARK_PNG)

	print("")
	print("=== TOTALT (kamera): %d kontroller, %d fel ===" % [checks, fails])
	quit(1 if fails > 0 else 0)
