## Ett spelkort: typfärgad banner med kostnad och namn, konst, och effekt.
##
## Kortet ligger INTE i en ruta. Det hålls framför spelaren i en solfjäder (position och rotation
## sätts av handen i main.gd) och TRÄDER FRAM när pekaren är över det: det växer ur solfjädern,
## rätar upp sig och visar sin effekttext. Samma widget i kortvalet, men där i stor storlek.
##
## Färgen är kortets TYP (attack röd, item gul, mana blå, crawler grön, wild grå) — i referensen
## bär kortet sin typ i färgen, inte som en textrad.
class_name CardView
extends PanelContainer

signal picked(index: int)
## Träder fram/undan. Handen använder den för att visa vad kortet skulle göra.
signal forward_changed(index: int, on: bool)

## Kortets yta. Alex: *"Korten behöver ännu bli större, de är för små för spelet, kanske rent av
## 80 % större."* Båda talen är därför 1,8x de gamla (58x80 -> 104x144, 84x118 -> 151x212). Allt som
## räknar ytor (högar, kortval, album, HUD) räknar ur de här, så en ändring här slår igenom överallt.
# Alex 11/10: "Öka kortens storlek med 25% med." 104x144 -> 130x180, och den stora läsrutan följer med
# (151x212 -> 189x265): stod den kvar hade det framträdda kortet bara varit 16 % större än ledet, och
# hela poängen med läsrutan är att den är märkbart större.
const HAND_SIZE := Vector2(130, 180)
const BIG_SIZE := Vector2(189, 265)
const FORWARD := 1.5              # så mycket växer kortet när det träder fram ur handen

## Rörelsen. Talen är MÄTTA av `tests/test_kortrorelse.gd`, som kör varje rörelse i en riktig
## bildrute-loop och skriver ut kurvan per bildruta (px och ms). Siffrorna nedan är den körningens,
## vid skala 1,0 — handens kort är 1,6 gånger så stora, så samma rörelse är 1,6 gånger så många px:
##   svikt:    kortet 3,0 px ned och 3,2 px ihop, botten vid 41 ms; lyftets översläng 4,0 px
##             (topp 124 av 120) vid 138 ms, satt efter 186 ms — underkanten står still hela vägen
##   tillbaka: trycks 3,2 px ihop vid 60 ms, satt efter 107 ms, landar exakt på hemplatsen
##   spelat:   stöten 1,131 vid 20 ms, flykten 37,4 px (34 + 3,4 översväng) vid 93 ms, borta 155 ms
##   utdelat:  ett kort i taget, 45 ms isär; kortet växer in från 94 % (4,8 px lägre) med en
##             översläng på 0,6 % och står still efter 180 ms
## Svikten och stöten är det taktila: kortet ger vika under pekaren och stöter till när det
## spelas. Utan dem är det bara en storleksändring och en blekning.
const SVIKT_PX := 3.0             ## px ned: så djupt viker kortet sig under pekaren
const SVIKT_TID := 0.045          ## s: ned OCH upp igen — en blinkning, inte en väntan
## Kramningen går i SKALAN, inte i rutan: en Control kan inte bli mindre än custom_minimum_size,
## och korten sätter sin minimistorlek till sin hemstorlek. Mätt: höjden stannade på exakt 80,0 px
## och ihoppressningen syntes inte alls när den drevs genom `size` — en osynlig rörelse.
const KRAM := Vector2(1.02, 0.96)  ## kortet trycks ihop under svikten (bredare, lägre)
## Det framträdda kortet LUTAR: överkanten skjuts bakåt medan det lyfter (8 % lägre), och rätar upp
## sig när det satt sig. En framskjutning är perspektivets synliga del — kortet är lika brett men
## kortare upptill — och den är den billiga vägen till "en aning 3D" i handen: en riktig vridning
## kräver en egen yta per kort (se ui/reward_fx.gd), alltså 4-6 ytor i bildrutan.
const LUTA := Vector2(1.0, 0.92)
const LUTA_TID := 0.12            ## s: rätar upp sig efter lyftet
const LYFT_TID := 0.16            ## s: lyftet till framträtt läge (BACK = översläng)
const ÅTER_TID := 0.12            ## s: ned i ledet igen när pekaren lämnar
const STÖT_SKALA := 1.12          ## stöten när kortet spelas, som andel av sin storlek
const STÖT_TID := 0.07            ## s: stöten
const FLYKT_PX := 34.0            ## px: hur högt kortet lyfter på vägen ut ur handen
const FLYKT_TID := 0.16           ## s: flykten ut, med översläng (BACK)
const DELA_STEG := 0.045          ## s: fördröjningen mellan korten — utdelningens efterföljd
const DELA_TID := 0.18            ## s: ett korts väg in — skalan växer, ingen resa
const DELA_KRYMP := 0.94          ## kortet är så mycket mindre (4,8 px lägre) när det delas ut
const EFTERFÖLJD := 0.022         ## s per steg: grannarna följer efter det framträdda kortet
const VÄND_HALV := 0.09           ## s per halva av vändningen: kortet vrids runt sin axel i 0,18 s
const VÄND_SMAL := 0.06           ## hur smalt kortet blir mitt i vändningen (aldrig exakt 0: en
                                  ## ruta på noll pixlar försvinner ur trädet och tweenen dör tyst)

## PSEUDO-3D I DETALJVYN (big). Samma lutning som LUTA — en kant skjuts bakåt = en skalning under 1 —
## men i det stora kortet FÖLJER den pekaren i stället för att vara fast: musen till vänster/höger
## sänker den kanten och vrider kortet kring sin egen mitt. Siffran är LUTA:s EGEN avvikelse (1-0,92),
## så effekten är precis lika stor som handens framskjutning och aldrig mer — kortet varken skalas upp
## eller suddas, och alfan rörs inte (kortet får inte bli genomskinligt). Se `big_lutning`.
const LUTA_MAX := 1.0 - LUTA.y    ## hur mycket en kant skjuts bakåt vid fullt utslag (= LUTA:s djup)
const VRI_MAX := 0.05             ## rad: hur mycket kortet vrider sig kring sin mitt vid fullt utslag

## Typfärger mätta ur referensens kort: attack röd, item/passiv gul, mana blå, crawler grön,
## wild grå. Textfärgen är samma ton ljusare, så den går att läsa mot den mörka kortytan.
const TYPE_COLORS := {
	"attack": [Color(0.62, 0.16, 0.16), Color(0.98, 0.55, 0.50)],
	"item": [Color(0.60, 0.48, 0.12), Color(0.98, 0.88, 0.48)],
	"mana": [Color(0.16, 0.34, 0.62), Color(0.60, 0.80, 1.00)],
	"crawler": [Color(0.20, 0.48, 0.26), Color(0.62, 0.92, 0.62)],
	"wild": [Color(0.36, 0.36, 0.42), Color(0.78, 0.78, 0.84)],
}

var index := -1
var card: Cards.Card

## Var kortet hör hemma i solfjädern. Sätts av handen; kortet självt rör dem inte.
var home_pos := Vector2.ZERO
var home_size := HAND_SIZE
var home_rot := 0.0
var forward := false
var face_down := false          ## kortet kom från högen och ligger med baksidan upp tills det vänts

var _effect: RichTextLabel
var _big := false
var _skala := 1.0
var _tween: Tween
var _vänd_tween: Tween            ## vändningen, i sin egen tween: lyftet och vändningen får inte döda varandra
var _bak: TextureRect
static var _baksida: Texture2D   ## baksidan, laddad en gång för alla kort
## KORTETS EGNA EFFEKTER (M103): glansen vid hover och förbränningen när kortet spelas, i EN överläggning
## ovanpå kortet (se ui/kortfx.gdshader). Skälet att det är en överläggning och inte ett material på
## kortets delar: kortet är ett träd, och en canvas-shader ritar per del med delens egen UV — en brinnande
## fläck hade hamnat fel på var och en av dem.
var _fx: ColorRect
var _fx_material: ShaderMaterial
var _glans_på := false
var _brand_på := false

## Bygg ett färdigt kort. `icon` får vara null (11 av 67 kort har ingen bild än — de får en TYDLIG
## platshållare i stället för en tom ruta). `skala` förstorar både rutan och texten; handen ligger i
## fönstrets upplösning och behöver 1,6 gånger så stora kort som den gamla 480x270-handen.
static func make(c: Cards.Card, i: int, icon: Texture2D, big: bool, skala := 1.0) -> CardView:
	var v := CardView.new()
	v.index = i
	v.card = c
	v._build(icon, big, skala)
	# Överläggningen läggs efter `_build`, alltså ÖVERST i trädet: den läser skärmen under sig, och då
	# måste hela kortet vara ritat först.
	v._bygg_fx()
	return v

## Överläggningen (M103). En egen ruta över kortet med kortets egna mått, osynlig i vila, och med
## `mouse_filter` IGNORE så att den inte stjäl hover eller klick från kortet.
func _bygg_fx() -> void:
	_fx_material = ShaderMaterial.new()
	_fx_material.shader = load("res://ui/kortfx.gdshader")
	_fx_material.set_shader_parameter("storlek", home_size)
	_fx = ColorRect.new()
	_fx.material = _fx_material
	_fx.color = Color.WHITE       # färgen kommer ur shadern (skärmen under); alfan ur rutan
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.visible = false
	add_child(_fx)

## Tänd eller släck glansen. Medan den lyser följer strimman pekaren (`_process`), och rutan är synlig —
## en överläggning som läser skärmen kostar en kopia av bilden varje bildruta, så den får inte stå på.
func _tänd_glans(on: bool) -> void:
	if _fx == null:
		return
	_glans_på = on
	_fx.visible = on or _brand_på
	set_process(on)
	var t := create_tween()
	t.tween_method(_sätt_glans, _glans_värde(), 1.0 if on else 0.0, 0.12)
	# Muspekaren finns bara när kortet ligger i trädet: `set_forward` anropas också medan kortet byggs
	# (kortvalet och samlingen sätter sitt läge innan de läggs in), och `get_local_mouse_position` fäller
	# hela anropet då.
	if on and is_inside_tree():
		_sätt_glans_pos(get_local_mouse_position())

## Uniformer som inte satts ännu svarar null (standardvärdet bor i shadern), och `float(null)` fäller
## hela anropet. Läs dem genom den här, så både koden och proven får ett tal.
func _param(namn: String) -> float:
	if _fx_material == null:
		return 0.0
	var v: Variant = _fx_material.get_shader_parameter(namn)
	return 0.0 if v == null else float(v)

func _glans_värde() -> float:
	return _param("glans")

func _sätt_glans(v: float) -> void:
	_fx_material.set_shader_parameter("glans", v)

func _sätt_glans_pos(p: Vector2) -> void:
	_fx_material.set_shader_parameter("glans_pos", p)

func _process(_delta: float) -> void:
	var p := get_local_mouse_position()
	if _glans_på:
		_sätt_glans_pos(p)
	# PSEUDO-3D:n (big) går genom SAMMA `_process` som glansen, alltså bara medan kortet är hoverat
	# (`forward` sätts av set_forward, och `_tänd_glans` tänder `_process`). I handen händer ingenting:
	# där äger de fyra rörelserna kortets tal, och en femte skrivare är buggklassen M67.
	if _big and forward:
		big_lutning(p)

## PSEUDO-3D i detaljvyn (big): lägg lutningen för pekarens plats `p` (kortets egna koordinater).
## Anropas av `_process` med musens faktiska plats; provet anropar den med givna platser.
##
## Den rör INTE positionen — bara skalan och vridningen, kring mittpivoten (`_pivot`). Positionen är
## det tal fyra rörelser redan slåss om i handen (M67), och glansen löste samma knut genom att inte röra
## den; den här gör likadant. `_big`-villkoret är det som håller handen orörd: spelet pekar aldrig på ett
## big-kort i handen.
func big_lutning(p: Vector2) -> void:
	if not _big:
		return
	var halv := size * 0.5
	# Pekarens läge i kortet, normaliserat till -1..1 från mitten (kanten = fullt utslag).
	var d := Vector2(clampf((p.x - halv.x) / maxf(halv.x, 1.0), -1.0, 1.0),
		clampf((p.y - halv.y) / maxf(halv.y, 1.0), -1.0, 1.0))
	# Lutningen: den kant pekaren lutar mot skjuts bakåt (skalan under 1, LUTA:s mekanism), och kortet
	# vrider sig en aning mot samma sida. Aldrig mer än LUTA:s djup, så inget blir suddigt av effekten.
	scale = Vector2(1.0 - LUTA_MAX * absf(d.x), 1.0 - LUTA_MAX * absf(d.y))
	rotation = VRI_MAX * d.x

## FÖRBRÄNNINGEN (M103). Alex: *"när ett kort man förbränner vid användning?"* — kortet som spelas
## brinner bort från punkten man klickade, i stället för att bara blekna. Rutan tänds, radien växer till
## hela kortet och släcks sedan: en överläggning som ligger kvar hade fortsatt att äta av skärmen.
func bränn(varv: float = 0.38, punkt := Vector2.INF) -> void:
	if _fx == null:
		return
	_brand_på = true
	_fx.visible = true
	_fx_material.set_shader_parameter("storlek", home_size)
	_fx_material.set_shader_parameter("brand_punkt", home_size * 0.5 if punkt == Vector2.INF else punkt)
	_fx_material.set_shader_parameter("brand", 0.0)
	var t := create_tween()
	t.tween_method(_sätt_brand, 0.0, 1.25, varv).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(_släck_brand)

func _sätt_brand(v: float) -> void:
	_fx_material.set_shader_parameter("brand", v)

func _släck_brand() -> void:
	_brand_på = false
	if _fx != null:
		_fx.visible = _glans_på

## Hur långt förbränningen har kommit (0 = helt kort). För provet.
func brinnt() -> float:
	return _param("brand")

func cost_text() -> String:
	return "W" if card.is_wild() else str(card.cost)

## Kortets två färger: [kant/banner, text].
func type_colors() -> Array:
	return TYPE_COLORS.get(card.card_type, TYPE_COLORS["wild"])

## En px i kortets egen skala. Skalan följer med i texten också: ett kort som är 1,6 gånger så stort
## med 7 px text ser bara ut som ett litet kort med grötig text (Alex: "HUD-texten är grötig").
func _px(v: float) -> int:
	return maxi(1, roundi(v * _skala))

## Kortets konst, ritad i en HELTALS multipel av sin egen storlek.
##
## En konstpixel som blir 2,3 px bred intill en som blir 2 px är det som ser suddigt ut — mätt i
## kortvalet: block av 2, 3, 4 och 5 px om varandra, för rutan var 2,8 gånger konsten. Med hela steg
## blir varje pixel lika stor, och konsten läses som pixelkonst. Är konsten STÖRRE än rutan (handens
## små kort) går en jämn multipel inte, och då skalas den ned proportionellt som förut.
class Ikon extends Control:
	var textur: Texture2D

	func _ready() -> void:
		# Rutan får sin storlek av containern: rita om när den ändras.
		resized.connect(queue_redraw)

	func _draw() -> void:
		if textur == null:
			return
		var st := Vector2(textur.get_width(), textur.get_height())
		if st.x <= 0.0 or st.y <= 0.0:
			return
		var s := steg()
		var mål := st * minf(size.x / st.x, size.y / st.y)      # proportionellt, om konsten är större
		if s >= 1:
			mål = st * float(s)                                # hela steg: varje pixel lika stor
		draw_texture_rect(textur, Rect2(((size - mål) * 0.5).floor(), mål), false)

	## Steget konsten ritas i. 0 betyder att rutan är mindre än konsten och att den skalas ned
	## proportionellt (handens små kort) — då finns ingen jämn multipel att ta.
	func steg() -> int:
		if textur == null or size.x <= 0.0 or size.y <= 0.0:
			return 0
		return int(minf(size.x / float(textur.get_width()), size.y / float(textur.get_height())))

func _build(icon: Texture2D, big: bool, skala := 1.0) -> void:
	_big = big
	_skala = skala
	home_size = (BIG_SIZE if big else HAND_SIZE) * _skala
	custom_minimum_size = home_size
	size = home_size
	# Innehållet får sticka ut: det framträdda kortet är större än sin hemplats och visar sin
	# effekttext, och en ruta som klipper hade gömt just det man ska se.
	clip_contents = false
	face_down = false
	# Verktygstipset behövs i HANDEN (omlottet gömmer namnet), men i ett kortval ligger korten i en rad
	# och visar hela sin text själva — då blir tipset en ruta ovanpå en granne (mätt: PopupPanel
	# "Ash Veil (2) +12 rustning" över Emberstorm i kortvalet).
	if not big:
		tooltip_text = "%s (%s)\n%s" % [card.title(), cost_text(), card.describe()]
	add_theme_stylebox_override("panel", _style(false))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _px(2 if big else 1))
	add_child(box)

	# Bannern: kostnaden och namnet på typens färg, som kortets titelrad i referensen.
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _banner_style())
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(2))
	banner.add_child(row)
	var cost := Label.new()
	cost.text = " %s " % cost_text()
	cost.add_theme_font_size_override("font_size", _px(9 if big else 8))
	cost.add_theme_stylebox_override("normal", _badge(card.is_wild()))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost)

	# RichTextLabel med fit_content=false KLIPPER i stället för att kräva plats. En vanlig Label
	# med radbrytning rapporterar sin minimihöjd för en pyttebred ruta — mätt: korten växte till
	# 105–195 px höga i stället för 80, olika för varje namn, och PanelContainer följde efter.
	var name_label := RichTextLabel.new()
	name_label.text = card.title()
	name_label.bbcode_enabled = false
	name_label.fit_content = false
	name_label.scroll_active = false
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Höjden ska rymma TVÅ rader: namn som "Deep Tome" och "Choir Bell" bryts, och med 15 px räckte
	# rutan bara till en rad — nedre halvan av andra radens bokstäver klipptes av mot konsten (sett i
	# granskningen av solfjädern, och felet fanns i raden också). De 5 px:en tas från konsten, som har
	# EXPAND_FILL och bara blir 5 px kortare: kortets yttermått är låst av HAND_SIZE.
	name_label.custom_minimum_size = Vector2(0, _px(28 if big else 20))
	# 7 px i handen, inte 8: "Deep Tome" och "Choir Bell" klipptes mitt i ordet mot kortets kant
	# (sett i granskningen). Namnet måste rymmas — det är så man väljer kort.
	name_label.add_theme_font_size_override("normal_font_size", _px(10 if big else 7))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	if icon != null:
		var ik := Ikon.new()
		ik.textur = icon
		ik.custom_minimum_size = Vector2(0, _px(44 if big else 28))
		ik.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ik.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ik)
	else:
		box.add_child(_platshållare())

	_effect = RichTextLabel.new()
	_effect.text = highlight_numbers(card.describe())
	_effect.bbcode_enabled = true
	_effect.fit_content = false
	_effect.scroll_active = false
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.custom_minimum_size = Vector2(0, _px(22))
	_effect.add_theme_font_size_override("normal_font_size", _px(7))
	_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect.modulate = Color(0.85, 0.88, 0.95)
	_effect.visible = big          # i handen syns den först när kortet träder fram
	box.add_child(_effect)

	for n in box.get_children():
		if n is Control:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP

	# BAKSIDAN (M34): en täckande ruta med kortets baksida, osynlig tills kortet kommer från högen.
	# Den läggs SIST bland barnen och ligger alltså överst — ett kort som kommer från högen får inte
	# visa vad det är förrän det vänts (Alex: *"Korten skall ha en och samma baksida, så man inte ser
	# vad som ligger härnäst på tur."*).
	_bak = TextureRect.new()
	_bak.texture = baksida_textur()
	_bak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bak.stretch_mode = TextureRect.STRETCH_SCALE
	_bak.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bak.visible = false
	_bak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bak)

	mouse_entered.connect(set_forward.bind(true))
	mouse_exited.connect(set_forward.bind(false))
	gui_input.connect(_on_gui_input)
	resized.connect(_recenter_pivot)
	_recenter_pivot()

## Kortets baksida, samma fil till varje kort (tools/gen_card_back.py). Laddas en gång för alla kort:
## baksidan är densamma på varje kort, och en fil per kort vore samma bild femtiosju gånger.
static func baksida_textur() -> Texture2D:
	if _baksida == null and ResourceLoader.exists("res://assets/cards/_back.png"):
		_baksida = load("res://assets/cards/_back.png")
	return _baksida


## VÄNDER UPP KORTET: det kommer från högen med baksidan upp och vrids runt sin lodräta axel —
## skalan i x går mot noll och tillbaka, och vid noll byts baksidan mot framsidan. Det är skillnaden
## mellan "ett kort som dyker upp i handen" och "ett kort som dras". Pivoten ligger i nederkanten
## (`_recenter_pivot`), så vändningen sker kring kortets egen fot, precis som man vänder ett kort.
func vänd_upp(fördröjning := 0.0) -> void:
	if _baksida == null:
		face_down = false
		return
	face_down = true
	_bak.visible = true
	if _vänd_tween != null and _vänd_tween.is_valid():
		_vänd_tween.kill()
	_vänd_tween = create_tween()
	if fördröjning > 0.0:
		_vänd_tween.tween_interval(fördröjning)
	_vänd_tween.tween_property(self, "scale:x", VÄND_SMAL, VÄND_HALV) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_vänd_tween.tween_callback(_visa_framsida)
	_vänd_tween.tween_property(self, "scale:x", 1.0, VÄND_HALV) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _visa_framsida() -> void:
	face_down = false
	_bak.visible = false

## Siffrorna i effekttexten i gult, som i referensen ("Deal 124 damage" med 124 markerat). Utan
## det dränks talen i texten, och talen är det man jämför kort emellan.
static func highlight_numbers(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\d+")
	return re.sub(text, "[color=#ffcc44]$0[/color]", true)

## Kortets VRIDPUNKT. Handens kort vrider sig kring sin FOT (det vänds upp ur högen kring nederkanten
## och lyfter ur ledet), det stora kortet kring SIN EGEN MITT — pseudo-3D:n ska svänga det om mitten,
## inte om ett hörn.
func _pivot() -> Vector2:
	return size * 0.5 if _big else Vector2(size.x / 2.0, size.y)

## Pivot i nederkanten: kortet vrids och växer kring sin egen nederkant, som ett kort i en hand.
func _recenter_pivot() -> void:
	pivot_offset = _pivot()

## Träder fram ur ledet: kortet SVIKTAR (ger vika ned under pekaren) och lyfter sedan ur handen
## med en liten översläng. Allt annat är kvar på sin plats i raden — det är den som ger "håller
## dem framför sig".
##
## Med tween, inte hopp, och i två faser. Första versionen satte storlek och rotation direkt, och
## handen kändes hackig: ögat läser en förflyttning på 16 ms som ett hopp. Andra versionen hade
## bara lyftet (TRANS_BACK) och kändes mjuk men inte taktil — inget i rörelsen svarade på att man
## rörde vid kortet. Svikten är det svaret: 3 px ned i 45 ms, sedan lyftet. Villkoret är att
## tweenen inte får kännas väntad — därför en blinkning, inte en dipp man sitter i.
func set_forward(on: bool) -> void:
	if on == forward:
		return
	forward = on
	# HEMPLATSEN FÖR KORT SOM LIGGER I EN CONTAINER (kortvalet): handens kort får sin home_pos av
	# `_rada_hand`, men ett kort som en container lägger ut har ingen — och både svikten (`_vik`) och
	# lyftet (`_väx`) räknar position UR home_pos. Med (0,0) for kortet till containerns övre vänstra
	# hörn och la sig över grannen (Alex: "kortet flyttar på sig till vänster, och täcker över det
	# som låg där innan"). Hemplatsen tas ur läget containern gav det, vid varje pekaringång — så en
	# omsortering av containern fångas nästa gång pekaren kommer in.
	if on and get_parent() is Container:
		home_pos = position
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# KORTET SKA VARA HELT NÄR MAN RÖR DET (Alex: "får inte bli transparenta när man hovrar, det stör
	# spelandet"). Utdelningen (`dela_in`) sänker alfan till 0,25 och driver upp den igen med SAMMA
	# tween som hoverrörelsen: kom pekaren in under utdelningen dödades upptweenen, och kortet låg kvar
	# på 25 % synlighet i handen hela striden. Här sätts slutläget först — alfa 1 och ingen kvarvarande
	# ihoppressning — så att rörelsen börjar från ett helt kort.
	modulate.a = 1.0
	scale = Vector2.ONE
	var mål_rot: float = 0.0 if on else home_rot
	z_index = 3 if on else 0
	_effect.visible = on or _big
	add_theme_stylebox_override("panel", _style(on))
	# GLANSEN (M103): en ljusstrimma som följer pekaren medan den är över kortet. Tänds bara då — en
	# överläggning som läser skärmen kostar en kopia av bilden, och det ska man inte betala i vila.
	_tänd_glans(on)
	var f := _fas()
	_tween = create_tween()
	if on:
		# Ingen fördröjning före svikten: pekaren ska svara direkt, och en väntan på 20-60 ms känns
		# som tröghet. Olikheten mellan korten kommer i stället ur att de tar olika lång tid på sig
		# (0.85-1.25 av nominell tid), vilket är det som bryter vågen när man drar pekaren längs raden.
		# FAS 1 — svikten: kortet trycks ned och kramas ihop, kvar kring sin hemplats. Mätt som fel
		# först: drev jag storleken mot det framträdda måttet redan här växte kortet 80 -> 118 px
		# på 45 ms och svikten syntes inte alls — hela rörelsen var lyftet, med 45 ms försprång.
		_tween.tween_method(_vik, 0.0, 1.0, SVIKT_TID * f) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# DETALJVYN: svikten (positionen) är kvar, men kramningen hoppas över i big — skalan ägs där av
		# pseudo-3D:n (big_lutning i _process). Skrev båda vore det två system på samma tal (M67).
		if not _big:
			_tween.parallel().tween_method(_kram, 0.0, 1.0, SVIKT_TID * f) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# FAS 2 — lyftet ur ledet: hela vägen upp med översläng, kramningen ut igen mot LUTA (kortet
		# lutar bakåt medan det lyfter), och sist en egen fas där det rätar upp sig.
		_tween.chain()
		_tween.tween_method(_väx, 0.0, 1.0, LYFT_TID * f) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# DETALJVYN: LUTA-dippen och vridningen är handens lyft — i big ägs skalan och vridningen av
		# pseudo-3D:n (big_lutning, driven av pekaren), och att tweena dem här vore en fjärde skrivare.
		if not _big:
			_tween.parallel().tween_property(self, "scale", LUTA, LYFT_TID * f) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "rotation", mål_rot, LYFT_TID * f) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Lutningen rätas ut i ett EGET steg efter lyftet: lade man den i samma fas skulle kortet
			# stå kvar och luta medan det redan satt sig.
			_tween.chain()
			_tween.tween_property(self, "scale", Vector2.ONE, LUTA_TID * f) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# Tillbaka i ledet, med samma svikt: kortet kramas ihop när det sätter sig och rätar ut
		# sig. Mätt: 3,2 px ihop (4 %) vid 60 ms, satt efter 107 ms.
		_tween.tween_method(_väx, 1.0, 0.0, ÅTER_TID * f) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Kramningen är handens (skalan); i big har pseudo-3D:n slutat skriva (forward blev false), så
		# vridningen tweenas tillbaka till hemroten i båda lägena — men skalan rörs bara i handen.
		if not _big:
			_tween.parallel().tween_method(_kramfjäder, 0.0, 1.0, ÅTER_TID * f)
		_tween.parallel().tween_property(self, "rotation", mål_rot, ÅTER_TID * f) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	forward_changed.emit(index, on)


## Kortets egen tid, 0.85-1.25, räknad ur platsen i raden (Alex: *"Rörelsen skall vara lite random,
## så det inte blir en 'vågen'-effekt"*). Determinismen är med flit: samma kort rör sig likadant varje
## gång man pekar på det, så det blir karaktär och inte slump. 37 är coprimt mot 100, så grannar i
## raden får så olika värden som möjligt.
func _fas() -> float:
	return 0.85 + 0.40 * float((absi(index) * 37) % 100) / 100.0

## Det framträdda måttet. I ett KORTVAL (big) växer kortet inte: korten ligger i en rad som
## containern äger, och en växt skjuter kortet in över grannen och ut över panelens ram (mätt: 84 ->
## 126 px bredd, 21 px in på varje granne och 59 px ovanför sin egen plats). Valkortet är redan stort
## och visar hela sin text, så växten ger ingenting och kostar layouten. Kanten och z-ordningen
## markerar valet i stället.
func målsize() -> Vector2:
	return home_size if _big else home_size * FORWARD

## Svikten: hela kortet SVIKT_PX ned under pekaren, kvar kring sin hemplats. t 0 -> 1.
func _vik(t: float) -> void:
	position = Vector2(home_pos.x, home_pos.y + SVIKT_PX * _skala * t)
	pivot_offset = _pivot()

## Kramningen: kortet trycks ihop kring sin underkant (pivoten ligger i nederkanten, så bara
## överkanten ger sig). t 0 = normalt, 1 = ihopklämt.
func _kram(t: float) -> void:
	scale = Vector2.ONE.lerp(KRAM, t)

## Landningen: kramningen går 0 -> 1 -> 0, alltså ihop och ut igen. Utan den blev kortet liggande
## ihopklämt i handen (mätt: 3,2 px lägre än sin hemhöjd även efter att rörelsen var slut).
func _kramfjäder(t: float) -> void:
	_kram(sin(t * PI))

## Lyftets läge: UNDERKANTEN STÅR STILL och kortet växer uppåt. t 0 = hemma, 1 = framträtt
## (och strax förbi, när BACK ger översläng: 120 -> 124 px höjd).
##
## Storlek OCH position räknas ur samma tal. Tweenades de var för sig gled underkanten 20 px ned
## under handen och kom tillbaka (mätt: kortet såg ut att sjunka genom skärmkanten) — storleken
## växte snabbare än positionen sjönk. Ett tal, två egenskaper: ingen glidning.
func _väx(t: float) -> void:
	var s: Vector2 = home_size.lerp(målsize(), t)
	size = s
	position = Vector2(home_pos.x + (home_size.x - s.x) / 2.0,
		home_pos.y + home_size.y - s.y)
	pivot_offset = _pivot()

## Kortet delas ut: det växer in på sin plats, ett kort i taget (`fördröjning` är efterföljden).
## Mätt: korten låg på plats redan i första bildrutan förut, så en ny hand small till utan
## utdelning.
##
## Ingen förflyttning: handen står redan i den svarta ytan längst ned i fönstret, och en utdelning
## som kom underifrån drog kortens underkant 26 px utanför kanten (mätt, och provet "raden ligger i
## den svarta ytan längst ner" föll med rätta på det — en handkorts underkant får aldrig lämna
## fönstret, det var hela poängen med att flytta handen till marginalen). Vägen in är därför
## skalan, som växer kring kortets egen underkant, och blekningen — inte en resa.
func dela_in(fördröjning: float = 0.0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = home_pos
	rotation = home_rot
	size = home_size
	scale = Vector2.ONE * DELA_KRYMP
	pivot_offset = _pivot()
	modulate.a = 0.25
	_tween = create_tween()
	if fördröjning > 0.0:
		_tween.tween_interval(fördröjning)         # efterföljden: EGET steg, inte parallellt
	_tween.tween_property(self, "scale", Vector2.ONE, DELA_TID) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, DELA_TID * 0.6)

## Platshållaren för ett kort som inte har någon bild än (11 av 67; cron hämtar dem). En TOM ruta ser
## ut som ett trasigt kort — den här ser ut som ett kort som väntar på sin bild: typens färg, ett
## inramat fält och ett stort frågetecken. Namnet står i bannern ovanför, så kortet går att välja.
func _platshållare() -> Control:
	var p := PanelContainer.new()
	p.name = "ikon_platshallare"
	var sb := StyleBoxFlat.new()
	var c: Color = type_colors()[0]
	# TÄT (M118): kortet ska inte gå att se igenom NÅGONSTANS, och en del med alfa 0,85 är en genomsyn
	# ett steg mindre. Platshållarens dämpning bärs av färgen (halva typfärgen), inte av alfan.
	sb.bg_color = Color(c.r * 0.5, c.g * 0.5, c.b * 0.5)
	sb.border_color = type_colors()[1]
	sb.set_border_width_all(_px(1))
	sb.set_corner_radius_all(_px(3))
	sb.set_content_margin_all(_px(2))
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, _px(44 if _big else 28))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q := Label.new()
	q.text = "?"
	q.add_theme_font_size_override("font_size", _px(22 if _big else 16))
	q.add_theme_color_override("font_color", type_colors()[1])
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(q)
	return p

## Glid till en ny plats i handen. Handen flyttar korten när ett av dem träder fram — utan den
## här vägen skrev _rada_hand positionen direkt och hela handen hoppade till.
##
## `fördröjning` är efterföljden: grannarna startar en aning efter det kort man rör vid, så raden
## öppnar sig som en solfjäder i stället för att flytta sig som en skiva. Mätt: 22 ms per steg.
func glide_to(pos: Vector2, rot: float, fördröjning: float = 0.0) -> void:
	home_pos = pos
	home_rot = rot
	if forward:
		return                     # det framträdda kortet ägs av sin egen tween
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if fördröjning > 0.0:
		_tween.tween_interval(fördröjning)         # efterföljden: EGET steg, inte parallellt
	_tween.tween_property(self, "position", pos, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation", rot, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Stöten: kortet reser sig en aning och sätter sig igen på 70 ms. Den ritas i SKALAN, inte i
## rutan — skalan är en renderingsform som layouten inte rör, och kortet är färdigt att flyga ut
## medan stöten spelar. Utan den smällde kortet inte till när det spelades, det bara bleknade.
func stöt() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * STÖT_SKALA, STÖT_TID * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, STÖT_TID * 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Kortet lämnar handen: det stöter till, lyfter och bleknar. Anropas innan draget spelas, så man
## ser VILKET kort som gick — referensen visar samma sak, där flyger kortet ut ur handen.
## Överslängen i flykten (TRANS_BACK) är efterföljden: kortet far förbi sin slutpunkt och kommer
## tillbaka, i stället för att glida rakt upp och dö.
## `mål` är högens mitt (M34): kortet ska LANDА i högen man spelade det till, inte bara försvinna
## uppåt — i referensen ser man vilket kort som gick OCH var det hamnar. Utan mål flyger kortet rakt
## upp och bleknar, som förut (kortvalet och proverna använder den vägen, och där finns ingen hög).
func fly_out(mål := Vector2.INF) -> void:
	z_index = 4
	stöt()
	var slut := position + Vector2(0, -FLYKT_PX * _skala)
	var krymp := 1.0
	if mål != Vector2.INF:
		slut = mål - size * 0.5 * scale
		krymp = 0.45
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", slut, FLYKT_TID) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, FLYKT_TID)
	if krymp != 1.0:
		# Kortet krymper in i högen: samma storlek hela vägen läste som ett kort som flög FÖRBI
		# högen (sett i granskningen av första försöket).
		t.tween_property(self, "scale", scale * krymp, FLYKT_TID).set_trans(Tween.TRANS_SINE)
	await t.finished

## Anropas av tangentbordet (1-9) så valet syns även när muspekaren inte är framme.
## 0,24 s: svikten (45 ms) + lyftet, som är färdigt först efter 186 ms (mätt). Vid 0,18 s rycktes
## kortet tillbaka mitt i lyftet.
func raise_for_a_moment() -> void:
	set_forward(true)
	await get_tree().create_timer(0.24).timeout
	if is_inside_tree():
		set_forward(false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		picked.emit(index)

## Kanten bär kortets typ; det framträdda kortet får en ljus, tjock kant som i referensen.
func _style(raised: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# KORTET SKA VARA HELT (Alex 11/10: "Korten blir ännu transparenta vid hover, det får de inte
	# bli. Det blir svårt att vara taktiskt då."). Panelen låg på 0,97 framträdd och 0,94 i ledet —
	# alltså släppte korten igenom fängelsehålan bakom sig hela tiden, och ett kort man inte kan läsa
	# är ett kort man inte kan planera med. Handen ligger ovanpå VYN, inte i marginalen, så det finns
	# ingenting att släppa igenom. Alfa 1 i båda lägena; framträdandet syns på ramen, lyftet och skalan.
	sb.bg_color = Color(0.10, 0.10, 0.15) if raised else Color(0.07, 0.07, 0.11)
	sb.border_color = Color(0.95, 0.97, 1.0) if raised else type_colors()[0]
	sb.set_border_width_all(_px(2) if raised else _px(1))
	sb.set_corner_radius_all(_px(4))
	sb.set_content_margin_all(_px(3))
	# SKUGGAN. Alex länkade fyra skugg-shadrar till korten (soft drop shadow för pixel art, simple och
	# dynamic shadow för 2D-sprites, card-shadow pseudo-3D). Alla fyra gör samma sak — en mjuk skugga
	# under kortet som lyfter det från underlaget — och den är inbyggd: StyleBoxFlat bär shadow_size,
	# shadow_offset och shadow_color. Noll shader, noll textur, inget nytt lager. Det framträdda kortet
	# kastar en större skugga och längre ned, vilket är det som gör lyftet läsbart även mot mörk botten.
	sb.shadow_size = _px(3 if raised else 2)
	sb.shadow_offset = Vector2(_px(1), _px(3 if raised else 1))
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	return sb

## Titellisten i kortets typfärg.
func _banner_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c: Color = type_colors()[0]
	# TÄT (M118): bannern låg på 0,85 och lät kortets egen botten lysa igenom titelremsan.
	sb.bg_color = Color(c.r, c.g, c.b)
	sb.set_corner_radius_all(_px(2))
	sb.set_content_margin_all(_px(1))
	return sb

## Kostnaden som en liten bricka. Wild-kort är grå i referensen (kostnad "W").
func _badge(wild: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.30, 0.34) if wild else Color(0.14, 0.26, 0.50)
	sb.set_corner_radius_all(_px(2))
	sb.set_content_margin_all(_px(1))
	return sb
