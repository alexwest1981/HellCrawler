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
const HAND_SIZE := Vector2(104, 144)
const BIG_SIZE := Vector2(151, 212)
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

## Bygg ett färdigt kort. `icon` får vara null (11 av 67 kort har ingen bild än — de får en TYDLIG
## platshållare i stället för en tom ruta). `skala` förstorar både rutan och texten; handen ligger i
## fönstrets upplösning och behöver 1,6 gånger så stora kort som den gamla 480x270-handen.
static func make(c: Cards.Card, i: int, icon: Texture2D, big: bool, skala := 1.0) -> CardView:
	var v := CardView.new()
	v.index = i
	v.card = c
	v._build(icon, big, skala)
	return v

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

## Pivot i nederkanten: kortet vrids och växer kring sin egen nederkant, som ett kort i en hand.
func _recenter_pivot() -> void:
	pivot_offset = Vector2(size.x / 2.0, size.y)

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
	_tween = create_tween()
	if on:
		# FAS 1 — svikten: kortet trycks ned och kramas ihop, kvar kring sin hemplats. Mätt som fel
		# först: drev jag storleken mot det framträdda måttet redan här växte kortet 80 -> 118 px
		# på 45 ms och svikten syntes inte alls — hela rörelsen var lyftet, med 45 ms försprång.
		_tween.tween_method(_vik, 0.0, 1.0, SVIKT_TID) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_method(_kram, 0.0, 1.0, SVIKT_TID) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# FAS 2 — lyftet ur ledet: hela vägen upp med översläng, kramningen ut igen.
		_tween.chain()
		_tween.tween_method(_väx, 0.0, 1.0, LYFT_TID) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "scale", Vector2.ONE, LYFT_TID) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "rotation", mål_rot, LYFT_TID) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Tillbaka i ledet, med samma svikt: kortet kramas ihop när det sätter sig och rätar ut
		# sig. Mätt: 3,2 px ihop (4 %) vid 60 ms, satt efter 107 ms.
		_tween.tween_method(_väx, 1.0, 0.0, ÅTER_TID) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_method(_kramfjäder, 0.0, 1.0, ÅTER_TID)
		_tween.parallel().tween_property(self, "rotation", mål_rot, ÅTER_TID) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	forward_changed.emit(index, on)

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
	pivot_offset = Vector2(size.x / 2.0, size.y)

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
	pivot_offset = Vector2(size.x / 2.0, size.y)

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
	pivot_offset = Vector2(size.x / 2.0, size.y)
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
	sb.bg_color = Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.85)
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
	sb.bg_color = Color(0.10, 0.10, 0.15, 0.97) if raised else Color(0.07, 0.07, 0.11, 0.94)
	sb.border_color = Color(0.95, 0.97, 1.0) if raised else type_colors()[0]
	sb.set_border_width_all(_px(2) if raised else _px(1))
	sb.set_corner_radius_all(_px(4))
	sb.set_content_margin_all(_px(3))
	return sb

## Titellisten i kortets typfärg.
func _banner_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c: Color = type_colors()[0]
	sb.bg_color = Color(c.r, c.g, c.b, 0.85)
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
