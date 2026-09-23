## Spelets scen. Byggs helt i kod — ingen .tscn — så att hela vyn går att läsa i en fil och
## scenen aldrig kan hamna ur synk med datan.
##
## Vyn är förstapersons rutnät: väggar/golv/tak som MultiMesh (en nod, hundratals rutor),
## fiender och saker som billboard-sprites. Det är samma upplägg jag mätte i referensen:
## pixelart-texturer i 3D, sprites som skalar med avståndet.
##
## Ponytail: all grafik är genererad (8x8-rutor i kod) tills CC0-paketet kopplas in — ingen
## platshållare att städa bort, bara en texturfunktion att byta ut.
extends Node3D

const DECK := [
	"lash", "lash", "lash", "lash",
	"dagger", "dagger", "dagger", "dagger",
	"axe", "axe", "axe", "axe",
	"bell", "bell", "ember_tome", "ember_tome", "deep_tome",
	"wild_mana", "wild_mana", "vial",
	# Ett av varje nytt nyckelord i startleken: då hamnar de i handen på varje demokörning och
	# syns på bild, i stället för att bara finnas i datat.
	"shove", "icicle",
]

const COL_WALL := Color(0.50, 0.54, 0.64)
const COL_FLOOR := Color(0.26, 0.24, 0.30)
const COL_CEIL := Color(0.20, 0.19, 0.25)
## Antal super-rutor per yta. tools/gen_tiles.py bygger fyra ordningar av basvarianterna, och varje
## ruta väljer en av dem med hash — upprepningen blir därför fyra meter i stället för en halvmeter.
const SUPER_YTOR := 4
const NODE_COLORS := {
	"encounter": Color(0.85, 0.25, 0.25),
	"chest": Color(0.90, 0.75, 0.20),
	"torch": Color(0.95, 0.55, 0.15),
	"boss": Color(0.65, 0.25, 0.85),
	"shovel": Color(0.90, 0.90, 0.95),
}

var db: Dictionary
var stages: Dictionary
var bestiary: Dictionary
var run: Run

## Spelvyns ruta. 3D:n ritas i 480x270 — pixelkonsten ska vara pixelkonst — och skalas upp med
## HELTAL i fönstret. Se `_bygg_vy`: allt som hör till vyn (världen, ljuset, minikartan, panelerna
## och korten i den gamla storleken) ligger i den rutan, medan HUD:en runt omkring ligger i
## fönstret och därför ritas i fönstrets upplösning. Det var hela skillnaden: förut skalades
## HUD-texten upp tillsammans med vyn och blev grötig.
const VY := Vector2i(480, 270)
## Handens kort i fönstret. 1,6 var den gamla 480x270-storleken; Alex: "Korten behöver bli lite
## större" — 1,75 är knappt en tiondel större och räcker för att namnet ska läsas i solfjädern.
## Skalan är ETT vred: kortets inre mått, handens omlott och högarnas geometri räknas alla ur den.
const HAND_SKALA := 1.75
## Raden ger efter kring det kort man rör vid: grannarna sjunker en aning, ett steg i taget.
## Utan rörelsen åt grannarna är efterföljden (CardView.EFTERFÖLJD) bara en konstant — det fanns
## inget för dem att glida till, för en rad med mellanrum flyttar sig inte när ett kort växer.
const GRANN_SVIKT := 0.015         ## andel av korthöjden som grannarna svarar med (128 px -> 1,9)
# Solfjädern (M34): korten läggs på en båge i stället för i rad. Pivoten ligger i kortets
# NEDERKANT (se CardView._recenter_pivot), så vridningen svänger kortets överkant utåt — det är
# därför en solfjäder ser ut som en hand och en rad ser ut som en hylla.
const FAN_STEG := 0.055            ## rad vridning per kort i bågen (~3,2 grader)
## Kortets steg i sidled, som andel av kortets bredd. Sänkt från 0,62 när korten blev 80 % större:
## med 0,62 rymdes tolv kort bara om skalan krympte tillbaka (1,52 i stället för 1,75), och då hade
## korten inte blivit större alls på skärmen. Vid 0,50 ryms tolv kort i full skala — och mer av varje
## kort syns än förut (91 px mot 63 px), trots att omlottet är större.
const FAN_OMLOTT := 0.50           ## kortets steg i sidled, som andel av kortets bredd
const FAN_SJUNK := 0.07            ## andel av korthöjden som ytterkortet sitter lägre per steg

## Ljud: genererade av tools/gen_sfx.py, hämtade från res://assets/sfx. Saknas filen tiger
## spelet i stället för att krascha — konsten och ljudet ska aldrig vara ett krav för att köra.
const SFX_NAMES := ["card", "hit", "crit", "coin", "step", "pick", "level_up", "descend", "death"]
var sfx: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next := 0

var world: Node3D
var cam: Camera3D
var hud: CanvasLayer               ## lagret INNE i spelvyn (480x270): byn, kartan, panelerna, FX
var _vy: SubViewport               ## spelvyns ruta: 3D:n ritas i 480x270 och skalas upp med heltal
var _vy_korg: SubViewportContainer ## ... och dess plats i fönstret (centrerad, NEAREST)
var _vy_lager: CanvasLayer         ## lagret spelvyn ligger i (en Control under en Node3D ritas inte)
var _runt: CanvasLayer             ## HUD:en i ytan RUNT vyn, i fönstrets upplösning (skarp text)
var hud_ram: HudRam                ## ramen i marginalen (M36): sten och metall, ritad i kod
var meny: Huvudmeny                ## startmenyn (M39): splashbilden och de fyra valen
var crt: Crt                       ## CRT-lagret (M39) överst i HUD:en: skanlinjer, vinjett, välvd kant
var musik: Jukebox                 ## spellistan (M54): låtarna i assets/music, hittade vid start.
var alt_panel: PanelContainer      ## ALTERNATIV: språk, CRT och musik
var alt_label: Label
var alt_rader: Array[Label] = []   ## raderna i alternativen (klickbara, som menyraderna)
var alt_index := 0
## HUD:ens tre rutor (M40, Alex' GUI-referens): statusblocket uppe till vänster (porträtt, staplar,
## nivå) och loggen nere till vänster. De ersätter statusraden och kärlen:
## samma tre storheter (hälsa, mana, rustning), men som staplar med siffrorna på sig.
var hud_status: HudStatus
## Kärlen (M36, tillbaka i M51): hälsa, mana och rustning som NIVÅER man ser på håll, i
## sidomarginalerna — samma grepp som Diablos orbs. Alex: *"jag gillade när du hade allt som klot
## innan, det får du gärna lägga tillbaka på ett lämpligt ställe"*. Siffrorna står i statusblocket.
var orb_hp: HudOrb
var orb_mana: HudOrb
var rust_bar: HudBar       ## rustningen som rad: ett enda poäng är en stapel, inte ett kärl
var hud_logg: HudLogg
# Kortborden (M34, punkt 8): draghögen till höger och de använda till vänster. Korten kommer ur den
# ena och hamnar i den andra — utan dem är en spelad kortanimation bara ett kort som försvinner.
var hog_drag: KortHog
var hog_använd: KortHog
var _hög_förra_drag := 0            ## föregående antal i leken (för att se omshufflingen)
var _hög_förra_använd := 0
var _förra_hand: Array[String] = [] ## korten som låg i handen förra gången (för att se NYA kort)
var top_label: Label
var hint_label: Label
var kort_label: Label
var hand_zone: Control
var battle_panel: PanelContainer
var battle_label: Label
var draft_panel: PanelContainer
var draft_label: Label
var draft_box: HFlowContainer
var map_view: MapView
var hand_views: Array = []
var _forward_index := -1
var _play_all_btn: Button = null     ## medlemmar: språkbytet sätter om texten utan att bygga om HUD:en
var _end_turn_btn: Button = null
var _sort_mode := 0
var _hand_order: Array[int] = []
var meta: Meta = null
var _banked := false
var _enemies: Array = []        ## [{spr, y, fas, hp, läge, läge_t}] — figurerna i rummet, animerade i _process

# Rutorna i fiendebilden (tools/gen_enemy_art.py), i den ordning de ligger i PNG:n. Siffrorna står
# här och inte på sex ställen i koden: byter konsten ordning ska det vara en rad att ändra.
const ENEMY_IDLE_A := 0         ## andas in
const ENEMY_IDLE_B := 1         ## andas ut
const ENEMY_WINDUP := 2         ## spänner sig — förvarningen innan slaget faller
const ENEMY_STRIKE := 3         ## hugger
## Hur länge fienderna håller förvarningen innan slaget faller. Slaget VÄNTAR lika länge (se
## `_on_end_turn`): en håll-beat man hinner se, i stället för ett hugg som kommer mitt i spänningen.
const FÖRVARNING_TID := 0.6
const ENEMY_HIT := 4            ## träffad
const ENEMY_DEAD := 5           ## död
const ENEMY_FRAMES := 6

## EGEN LOOK PER FIENDE (M70). Alex: *"Kan vi ge alla fiender egna shaders, så spökena t ex är
## transparenta? dock bara någon procent, och inte genomskinliga"*.
##
## Varför det inte är en shader: en `material_override` är en STÄNGD väg för en figur med rutnät —
## mätt (`-- figurprov fienderödfärg`) ritar figuren 22 641 px med Sprite3D:s eget material och 73 px
## med en override, hur arket än läggs in. Men Sprite3D:s EGNA rattar räcker för det här: `modulate`
## bär färg och alfa, och `alpha_cut` bestämmer om alfan BLANDAS eller KLIPPS.
##
##   alfa 1,0             = fast figur, alfan klipps (skarp kant mot väggarna, M59)
##   alfa 0,94            = sex procent genomsläpp — anden anar väggen bakom sig
##   alfa under ~0,8      = en hinna, inte en varelse. Håll dig över 0,85.
##
## Fler rattar finns om de behövs: `ton` (färg, t.ex. kall för andar), och en riktig shader kräver att
## rutfönstret lösas först (se M69 i `_add_enemies`).
const FIENDE_LOOK := {
	# andar och vålnader: några procent genomsläpp, kall ton. AURAN (M74) bär de av sig själva — en
	# kant langs silhuetten ur materialmaskens A-kanal. Den gamla varma dimfläcken (`glans`, en 1,3x
	# mjuk `rok.png` kring midjan) togs bort: Alex: *"Spökena ser ut som de ångar, det skall bara vara
	# minimal aura runtom som ger en känsla av etheritet"*.
	"candlewisp": {"alfa": 0.94, "ton": Color(0.94, 0.99, 1.06)},
	"salt_wretch": {"alfa": 0.94, "ton": Color(0.96, 0.99, 1.05)},
	"bell_drowned": {"alfa": 0.94, "ton": Color(0.94, 0.98, 1.06)},
	"hollow_choir": {"alfa": 0.94, "ton": Color(0.96, 0.97, 1.07)},
	"pale_reaper": {"alfa": 0.93, "ton": Color(0.96, 0.96, 1.08)},
	# glas är glas: en aning mer genomsläpp, men fortfarande en varelse
	"glass_herald": {"alfa": 0.90, "ton": Color(0.98, 1.02, 1.06),
		"glans": {"färg": Color(0.85, 0.95, 1.0), "storlek": 0.95, "höjd": 0.80, "styrka": 0.90}},
	# metall: samma fläck som den våta glansen, men stramare och kallare — den sitter högt, där ljuset
	# träffar en axel eller en hjälm
	"copper_warden": {"glans": {"färg": Color(0.58, 0.70, 0.86), "storlek": 0.62, "höjd": 1.0, "styrka": 1.60}},
	"ash_sovereign": {"glans": {"färg": Color(0.66, 0.74, 0.88), "storlek": 0.66, "höjd": 1.05, "styrka": 1.50}},
}
# Kamerans känsla (M37): ett steg glider och får en vidvinkel-puff, en sväng glider mjukare och
# kränger till. Alex: "Det behöver nästan bli en zoom-effekt när man går framåt, och någon form av
# mjuk rörelse när man svänger." Siffrorna är små med flit — det här ska kännas i magen, inte synas.
## grundvinkeln. 70 gav rätt rumslighet i M27, men 70 LODRÄTT är 102 grader VÅGRÄTT i 16:9 — en
## vidvinkel som drar ut kanterna och läses som fisheye (Alex: *"det får inte vara fisheye alls, det
## skapar åksjuka"*). 62 lodrätt = 93 grader vågrätt, normal spelkamera. Framingen i gången ändras
## några procent: figuren på 1,15 m blir något större, väggarna vid kanten mindre utdragna.
const FOV := 62.0
const STEG_TID := 0.16          ## ett steg tar 0,16 s (var 0,10 utan puff)
const SVÄNG_TID := 0.20         ## svängen tar längre tid: den ska kännas mjuk, inte kvick
const PUFF := 8.0               ## vidvinkeln öppnar sig 8 grader mitt i steget och stänger sig igen
const SPADE_KLICKRADIE := 26.0  ## px i VYNS mått: spaden är ~30 px bred på en meters håll
const GRÄV_DJUP := 1.2          ## hur långt kameran sjunker genom golvet under en grävning (m)
const GRÄV_TID := 0.9           ## hela grävningen: ned, svart, upp (s)
const KRÄNG := 0.022            ## svängens rullning i radianer (~1,3 grader åt sidan)

# Fötterna står på dukens rad 99 (båda generatorerna — mätt), alltså 39 px under dukens mitt. Därför
# är figurens mitt 39-40 px över golvet — 40 * 0,012 = 0,48 m, mätt i METER och inte i dukpixlar (M76:
# duken är upplösning, inte storlek; 80-duken hade 27 * 0,018 = 0,486 m). En dukpixel skillnad (1,2 cm)
# lägger fötterna en hårsmån i golvet i stället för att sväva — det syns inte, ett svävande syns.
const ENEMY_FEET_PX := 40.0
## DROPSHADOWEN (M71). Alex: *"Kan vi även göra en riktig dropshadow, och inte en platta som åker upp
## och ned? Det ser lite märkligt ut"*. Skuggan är en egen platta på golvet: den ligger STILL medan
## figuren andas, och den krymper och bleknar när figuren stiger. (Den var målad i figurens ruta förut
## och följde därför med i andningen — se `gen_enemy_art.py`.)
const SKUGGA_HÖJD := 0.045        ## golvplattan är 4 cm tjock (topp på 0,04) — skuggan måste ligga ÖVER den
const SKUGGA_ALFA := 0.75         ## hur mycket golvet syns genom fläcken; resten är SKUGGA_FÄRG
const SKUGGA_FÄRG := 0.035        ## fläckens egen färg — nästan svart, men inte svart
const SKUGGA_BREDD := 0.95        ## andel av den 1,12 m breda fläcken (djupet blir 0,55 av bredden)
## Fiendernas livstapel över huvudet. MÄTT upp i M51: 0,52 x 0,075 m var för tunt för att läsas på en
## blick (Alex: *"det är svårt som fan själv att se fienders hälsa"*) — figuren är 1,15 m hög. En meter
## bred gick däremot för långt: två fiender står 0,42 m isär, så staplarna flöt ihop till EN grön balk
## över båda (mätt på skärmbild). 0,62 x 0,11 m är strax över huvudet och håller sig inom sin figur.
const BAR_W := 0.62
const BAR_H := 0.11
var _bar_texture: ImageTexture
var hit_flash: ColorRect
var gräv_slöja: ColorRect       ## mörkret under en grävning (M44): bilden svartnar medan kameran sjunker
var _spade_nod: Dungeon.FloorNode   ## spaden på våningen: den ENDA saken som klickas
var _spade_sprite: Sprite3D         ## ... och dess skylt, så klicket kan räkna ut var den står
var _gräver := false                ## en grävning pågår: klicket får inte starta en till mitt i
var attack_fx: AttackFx
var reward_fx: RewardFx        ## stunden man får något: kortet som vänds in med glöd
var _enemy_cache := {}
var _retusch := {}                    ## fiendens retuschering (M82), läses i `_ready`
# DEKORATIONEN (M84): gräs, rötter, mossa och småsten i miljön. Alex: *"andra saker i miljön som inte
# skall ha någon collision, men bidrar till mer... känsla?"*
#
# INGEN KOLLISION ÄR EN EGENSKAP, INTE EN FLAGGA: dekorationen läggs som instanser i en MultiMesh per
# art, och en MultiMesh har ingen fysik alls. Det finns alltså inget att glömma sätta — inget
# CollisionShape skapas, ingen kropp finns, och man går rakt igenom gräset.
#
# Vilka rutor som får något kommer ur `_strö` (samma hash som takdropparna): mönstret är stabilt per
# våning i stället för att hoppa varje gång vyn byggs om.
const DEKOR_PIXEL := 0.008            ## samma pixelstorlek som rekvisiten (128 px/m, se gen_props.py)
const DEKOR_TÄTHET := 4               ## var n:te golvruta får något (0 = av)
## Vikten mellan arterna: gräs vanligast, rot ovanligast. Summan ska bli 1,0 — läses uppifrån och ned.
const DEKOR_VIKT := [["gräs", 0.52], ["småsten", 0.22], ["mossa", 0.18], ["rot", 0.08]]
var _dekor_shader: Shader = null
var _dekor_täthet := DEKOR_TÄTHET     ## `-- dekor=<n>` rattar tätheten, `-- dekor=0` stänger av
var _mask_cache := {}
var _fiendeprov := ""            ## fiendevisprov=<id>: tvinga fram en fiendetyp i striden (prov)
var _skugg_tex: Texture2D = null
var _panel_last_size := {}     ## panel-id -> senast uppmätta storlek (se _place_panel)
var stats_panel: PanelContainer
var stats_label: Label
var _tile_cache := {}
var _prop_cache := {}
var end_panel: PanelContainer
var end_label: Label

# --- skalet: byn, butiken och banvalet ----------------------------------------
# Spelet börjar i BYN, inte i en körning. Byn är navet — guld i banken, banval, butik — och hit
# återvänder man när körningen är slut. Samma form som referensen (village → World Map → dungeon),
# och skälet att bygga det nu: hjältar, smed och juvelerare ska bo någonstans, och utan navet finns
# ingen plats att köpa dem på.
## Byn och världskartan är SCENER, inte textrutor: platser och banor ritas i kod (se game/ui/) med en
## markering man flyttar. `shell` styr vilken som visas; bara körningen ritar 3D-vyn.
var shell := "hem"              ## hem | butik | karta | körning. Bara körningen ritar 3D-vyn.
## Skärmarna i skalet. Listan finns för att en plats i byn som pekar fel ska mötas av en varning i
## stället för av en tom skärm (skalet ritar ingenting för ett läge det inte känner igen).
const SKAL_LÄGEN := ["hem", "butik", "vardshus", "smed", "karta", "album", "juvelerare",
	"banverkstad"]
## Raderna i ALTERNATIV-panelen: språk, CRT, musik och spår (M54). Byggs på ett ställe och fylls
## på ett ställe — antalet får inte stå som ett tal på två ställen.
const ALT_RADER := 4
var _stage_order: Array = []    ## ban-id i svårighetsordning — det är ordningen de låses upp i
var _unlocked_now := ""         ## bana som låstes upp när förra körningen tog slut (visas på slutskärmen)
## Vyn över byn och vyn över kartan. De äger sin egen markering och ritning; main.gd skickar in
## metat och tar emot valet. Samma delning som minikartan (MapView) har mot körningen.
var by_view: VillageView
var karta: Karta                ## kartans bild, vinkel och noder (data/karta.json)
var karta_view: WorldMapView
var butik_panel: PanelContainer
var butik_label: Label
var inn_panel: PanelContainer
var inn_label: Label
## Värdshuset som kortvägg (M56): det valda kortet stort, raden med alla under.
var inn_stor: CenterContainer
var inn_box: HBoxContainer
var inn_index := 0
## Skalorna för värdshusets kortvägg. Tre rader text + stort kort + rad + panelens kanter måste
## rymmas i spelvyns 270 px. Mätt i två omgångar: originalet (1.0/0.62) klippte RADEN, och 0.72/0.5
## klippte TITELRADEN — panelen blev 280 px med kanterna. 0.66/0.45 ger 255 px med marginal.
const INN_SKALA := 0.66
const INN_RAD := 0.45
## JUVELERAREN (M58): samma kortvägg som värdshuset, men raden är LEKEN och raderna ovanför är
## facken och fickan. Skalan är mätt mot spelvyns 480x270: hela leken ska rymmas i EN rad, och
## måttet kommer ur vyn, inte ur ögat (M93). Vid 0,5 blev raden 1236 px i en 480 px vy — panelen
## centreras, så x hamnade på -378 och vänsterkanten av varje rad låg utanför skärmen. Mätt nedåt i
## steg: 0,5 gav 1236 px, 0,18 gav 510 (kortet är ~340 px brett, alltså 8 x 0,18 x 340 + mellanrum),
## och 0,15 ger 436 + etikettens 440 → panelen 456, alltså innanför vyns 480. Vill man läsa namnen i
## raden krävs scroll eller radbrytning, och det är ett större ingrepp än att få allt att synas.
const JEWEL_RAD := 0.15
var jewel_panel: PanelContainer
var jewel_label: Label
var jewel_box: HBoxContainer
var jewel_kort := 0        ## valt kort i leken
var jewel_fack := 0        ## valt fack (0-3)
var jewel_sten := 0        ## vald sten i fickan
## BANVERKSTADEN (M60): Alex: *"samt så jag kan editera alla banor i spelet"*. Alla 40 banorna,
## fält för fält, med gränserna ur `Stages.FÄLT` — samma tal som filen skrivs med.
var verk_panel: PanelContainer
var verk_label: Label
var _verk_stage := 0       ## index i _stage_order
var _verk_fält := 0        ## index i Stages.FÄLT
var _verk_rad := ""        ## kvittot ("banan sparad")
var smed_panel: PanelContainer
var smed_label: Label
var _smed_vald := 0
## Temat för våningen som ritas just nu. Rutorna är samma pixelkonst, men ljuset skiljer platserna åt.
## Temats ljus: bakgrund (tomrummet utanför väggarna), omgivningsljus (det som lyser där lyktan inte
## når) och dimma. Rutorna är inte längre ostrukturerade — våningen är mörk och det man ser är
## lyktan i handen, så avståndet syns i bild. Siffrorna är mätta mot skärmbilder (se PLAN.md M17),
## inte gissade: omgivningen ligger på 0,18-0,30, för allt däröver plattar rummet ut och blir ett
## upplyst garage i stället för en krypta.
const TEMA_LJUS := {
	"asklunden": {"bakgrund": Color(0.07, 0.07, 0.10), "omgivning": Color(0.55, 0.52, 0.62), "energi": 0.30, "dimma": 0.030},
	"krypta": {"bakgrund": Color(0.04, 0.04, 0.07), "omgivning": Color(0.42, 0.40, 0.52), "energi": 0.20, "dimma": 0.055},
	"grotta": {"bakgrund": Color(0.05, 0.07, 0.09), "omgivning": Color(0.42, 0.50, 0.58), "energi": 0.26, "dimma": 0.045},
	"tunnel": {"bakgrund": Color(0.08, 0.06, 0.04), "omgivning": Color(0.60, 0.50, 0.38), "energi": 0.28, "dimma": 0.060},
	"bro": {"bakgrund": Color(0.02, 0.03, 0.05), "omgivning": Color(0.36, 0.44, 0.56), "energi": 0.18, "dimma": 0.040},
}
## Lyktan i handen: det enda ljus som följer spelaren. Falloffen är spelets viktigaste ljussiffra —
## för kort räckvidd och man ser inte rummet man går in i, för lång och mörkret (hela stämningen)
## försvinner.
const LYKTA_FALLOFF := 2.0
const LYKTA_ENERGI := 3.0
const LYKTA_RACKVIDD := 9.0
const LYKTA_FARG := Color(1.0, 0.86, 0.68)
## Facklorna i våningen: ett eget ljus per fackla, med fladdret i `_process`.
## Facklans styrka. Halverad från 1,5 (Alex: "väggarna har alldeles för hög effekt av ljuset
## från facklorna ... testa med 50% av nuvarande styrka") — det varma ljuset tvättade bort
## skillnaden mellan tak, golv och vägg.
const LAGA_ENERGI := 0.75
## Taket dämpas en aning: samma ljus på tak, golv och vägg gjorde att ytorna flöt ihop i mörkret
## (Alex: "tak och golv har samma textur som väggarna vilket gör att allt flyter ihop").
## Ytornas TON (M66). Ruta, normal och ORM är redan olika per yta, men det varma fackelljuset
## dränker skillnaden: mätt i bild låg taket på 23,17,14, väggen på 15,9,7 och golvet på 43,29,27 —
## samma brunhet i alla tre (Alex: *"det är ännu samma tak/golv som väggar"*). Tonen är den enda
## ratten som skiljer dem åt i LJUSET: taket kallt och mörkt, golvet lite ljusare och neutralt.
const TAK_TON := Color(0.60, 0.66, 0.90)
const GOLV_TON := Color(1.12, 1.06, 0.98)
const LAGA_RACKVIDD := 6.5
const LAGA_FARG := Color(1.0, 0.78, 0.55)
## LJUSET PÅ YTORNA: en faktor på lyktan och facklorna — ljuset som träffar väggar och golv.
##
## HELA ändringen ligger här, och den är en faktor och inte en omgivning: rummet är inte för mörkt för
## att SE (man ser var man går), det är för mörkt för att LÄSA reliefen i ytorna. Omgivningsljuset rörs
## därför inte — det är takten, inte en ljuskälla, och det lyfter de svarta partierna lika mycket som de
## ljusa (se `_apply_tema` och normalprovets huvudkommentar).
##
## MÄTT i EN körning, Forward+, samma kamera, `-- provruta=super` på en SUPER-RUTA:
##
##   `-- normalprov=0@0@1,4@0@1,0@0@2.5,4@0@2.5,0@0@4,4@0@4,0@0@1`
##
##   ljusfaktor  lykta   |normal_scale 0 − 4| medel / p99   vyns medel   p50    mörkt   ljust
##   1,0 (före)   3,0           2,13 / 44                  0,080       0,041   81 %    0 %
##   2,5          7,6           3,49 / 76                  0,127       0,075   65 %    1 %   <- denna
##   4,0         11,9           4,28 / 93                  0,157       0,102   58 %    2 %
##   brusgolv (samma inställning två gånger)  0,89 / 2     0,080 mot 0,082
##
## Relief-signalen VÄXER alltså med ljuset (+64 % vid 2,5 och +101 % vid 4,0) — det är hela beviset
## för att ändringen gör det den ska: ytorna var inte platta, de var oupplysta. 2,5 är vald för att
## mörkret finns kvar: två tredjedelar av vyn ligger fortfarande under 0,15. Vid 4,0 lyser halva
## rummet upp och stämningen börjar gå förlorad.
const LJUS_STYRKA := 2.5
## GLANSEN: `light_specular` på lyktan och facklorna — ljuset ska kunna ge HÖGDAGRAR, inte bara belysa.
##
## Den var 0,0 på båda ("ingen glans: rutorna är målade, inte polerade"), och konsekvensen var att ingen
## yta i spelet kunde glänsa av ljuset hur låg råhet den än hade: vattnets shader (råhet 0,05) och
## ORM-kartornas halvblanka ben och trä lyste matt, och metall blev "bara mörk och platt" (M18) — mätt
## med glansen AV, alltså utan det enda som kan ge en högdager.
##
## MÄTT i EN körning, Forward+, samma kamera (`-- glansprov`, se den funktionen): glansen AV mot PÅ över
## hela vyn lyfter medel 0,1720 → 0,2141 och de mörka partierna 59 % → 50 % — men glansen ENSAM räcker
## inte, se YTGLANS_TRÖSKEL: bredden i lyftet är stenen, inte en högdager.
##
## 0,1 (M77). Alex: *"Speculariteten är alldeles för hög, och behöver dras ned till kanske 10 % av
## nuvarande nivå"*. Mätt i samma prov, facklan 2 steg ifrån, med spelets egen ytinställning:
##   glans 1,0: medel 0,1514, mörkt 63 %   glans 0,1: medel 0,1149, mörkt 75 %
##   glans 0,0 (brusgolvet): medel 0,1076, mörkt 77 %
## Lyftet över brusgolvet gick från +0,0438 till +0,0073 — 17 % av det gamla, alltså Alex' tio procent
## så nära ratten räcker. 0,0 vore att stänga av speglingen helt, och då kan varken vattnet (råhet
## 0,05), benet, träet eller järnet få en högdager (M26-läxan).
const LJUS_GLANS := 0.1
## YTANS spegling och hur den hänger på RÅHETEN i materialets egen ORM-karta (G-kanalen).
##
## VARFÖR DEN FINNS: `light_specular` på ett material med Godots standard-spegling (F0 4 %) ger stenen en
## BRED spegel — råhet 0,94 gör loben nästan halvklotformad, och lyktan sitter 30 cm från väggen. Mätt i
## samma körning som ovan: hela vyn blir mjölkig (vision: *"a broad, low-exponent specular sheen that
## lifts the deep blacks into pale, foggy greys… milky, plasticky, and flatter"*), och vattnet får
## INGEN egen glans — pölen drunknar i stenen omkring den.
##
## OCH RATTEN ÄR INTE EN SIFFRA: `StandardMaterial3D.specular` finns INTE i Godot 4 (mätt med
## `ClassDB`: egenskapen heter `metallic_specular` och styr metallens F0; en skrivning till `specular`
## ger bara *"Godot 3.x SpatialMaterial remapped parameter not found: specular"* och gör ingenting).
## Dielektrikerns F0 är alltså fast, och den enda ratten per material är `specular_mode`: AV eller GGX.
## Därför är regeln en TRÖSKEL på råheten i stället för en skala — en yta som är så matt att speglingen
## ändå bara blir en hinna får ingen spegling alls, medan mossen, sprickan, benet, träet och vattnet
## (råhet 0,05-0,72) behåller sin.
const YTGLANS_TRÖSKEL := 0.80
## Råheten under vilken en pixel räknas som BLÖT, och hur stor del av ytan som måste vara blöt för att
## ytan ska få spegling. Mätt mot ORM-kartorna: de våta fläckarna ligger på 0,20-0,40 i råhet och
## täcker 3-17 % av rutan per yta, så 0,40 och 3 % fångar dem utan att en torr sten (0,85 överallt)
## kommer med. Ändras generatorns fukt måste de här två följa med — därför står de tillsammans.
const GLANS_BLÖT := 0.40
const GLANS_BLÖT_ANDEL := 0.03
## Metallen på JÄRNET i facklan (plattan, kransen, stolpen, foten). MÄTT: den ska vara 0 — `metallic`
## 0,7 på järndelarna (vid både råhet 0,55 och 0,25) gjorde rekvisiten MÖRKARE, ner till −126 av 255 i
## enstaka bildpunkter, utan en enda ljus högdager i rutan: en metallisk yta tappar sin albedo till en
## spegling, och i en mörk korridor finns inget att spegla. Bara råheten är satt (`_del` sätter
## metallen ur samma skäl).
const JARN_RAHET := 0.55
## Metallverkan (M59). Alex: *"att metall ser ut som metall"*. `metallic` gör ytan till en spegel i
## stället för ett färgat papper: F0 blir ytans färg i stället för 4 %, och råheten styr hur skarp
## högdagern blir. Råhet 0,55 (den gamla siffran, mätt för att hålla järnet halvblanka) gav en bred,
## grå hinna — metall vill ha en TRÅNG lob. 0,30 ger en liten het fläck där lyktan träffar, och det
## är den fläcken ögat läser som metall.
const JARN_METALL := 0.85
const JARN_RAHET_METALL := 0.30
## Hur starkt järnets kantljus (Fresnel) är. 0,4 är mätt fram på en fackla i korridoren: starkare gör
## metallen självlysande, svagare syns den inte alls i mörkret.
const JARN_RIM := 0.4
## Delarna i facklan som är TRÄ, inte järn. Listan står här och läses av både materialet (`_del`) och
## provet (`_järndelar`), så "vad som är järn" inte kan besvaras olika på två ställen.
const FACKLA_TRÄ := ["fackla_skaft", "fackla_huvud"]

## Är den här delen järn? Provet och materialet frågar samma funktion.
func _är_järn(namn: String) -> bool:
	return namn.begins_with("fackla_") and not FACKLA_TRÄ.has(namn)
## Trösklarna i `_bild_statistik`: vad som räknas som mörkt rum och som upplyst yta. 0,15 är ungefär
## där stenen slutar vara svart och 0,60 där den läses som målad, inte bara skuggad.
const MÖRK_TRÖSKEL := 0.15
const LJUS_TRÖSKEL := 0.60
## HÖGDAGERN i `_bild_statistik`: en bildpunkt över 0,85 är en glans, en låga eller en glödd, inte en
## upplyst stenyta. Räknas i PIXLAR (inte i procent), för det är den siffran glansprovet jämför.
const HÖGDAGER_TRÖSKEL := 0.85
## HUD:ens luft mot fönsterkanten (px) och den andra raden i marginalen (se `_placera_karta`).
## MÄTT: med 1280x720 är vyn 960x540, alltså 160 px svart marginal på sidorna och 90 px ovanför —
## kartan (76x60 i vyns skala = 152x120 i fönstret) ryms i hörnet med MARGINAL till godo.
const MARGINAL := 6.0
## Kärlens radie i fönsterpixlar (gånger heltalsskalan). Mätt i M36: 34 px ger 152 px brett med
## stenkanten, och marginalen är 160 px vid 1280x720 — 38 px gick 14 px in i spelvyn.
const R_STOR := 34
const R_LITEN := 22
const RAD_2_Y := 44.0
## Pixlar som räknas som ÄNDRADE i närprovet (`-- kistnara`): en kanal måste skilja mer än så.
## MÄTT: renderarens egen animation (elden, dimman, den temporala GI:n) går på GPU-tid och rör sig
## även med trädet pausat, så utan en tröskel mäts rummets brus i stället för kistan.
const KISTA_PIXELTRÖSKEL := 0.06
## TAKET: golvet ligger på 0, väggarna är 1x1x1-block (mitten på 0,5) och takplattan ritas på
## TAK_HÖJD. Takhöjden är alltså rummets egen siffra, och facklan räknar sin höjd UR DEN i stället för
## ur ett fast tal — flyttas taket någon gång följer facklan med.
##
## TAKET HÖJDES (M48). Alex: *"Höj taket, det är för lågt för fienden, de tar i taket."* MÄTT: de
## tio fiender han ritade är 52-64 px höga i duken, alltså 0,94-1,15 m i rummet, och de äldre
## fienderna 40-62 px — i en 1,00 m hög gång stack huvudet igenom taket. Höjden är nu 1,30 m, vilket
## rymmer den högsta figuren (64 px = 1,15 m) med 0,15 m luft kvar.
##
## Väggblocken följer taket (Vector3(1, TAK_HÖJD, 1) i stället för 1x1x1) — annars blev det en
## öppen springa mellan väggens överkant och takplattan. Stenkonsten blir 30 % högrest, vilket är
## vad en högre gång ser ut som. Allt som räknade ur taket följer med: facklan (LAGA_TAK_AVSTÅND),
## takdroppet (TAK_HÖJD - 0,06) och väggdropparna.
##
## BOSSARNA har fortfarande större pixel_size, men 0,026 gav 1,66 m för en 64 px-figur — huvudet
## försvann genom taket. 0,0195 ger 1,25 m, alltså strax under taket för den högsta figuren, och
## bossen är ändå rummets största varelse (en vanlig fiende toppar på 1,15 m).
const TAK_HÖJD := 1.3
const LAGA_LUTNING := 32.0        ## skaftets lutning ut från väggen, i grader
const LAGA_SKAFT := 0.26          ## skaftets längd (kort — rummet är en meter högt)
const LAGA_HUVUD := 0.30          ## var lågan sitter, mätt från kransen längs skaftets axel
const LAGA_TAK_AVSTÅND := 0.32    ## så mycket luft ska lågan ha kvar upp till taket ...
const LAGA_ÖVERKANT := 0.24       ## ... och så högt över sin fot den BRINNANDE lågan når (se provet)
var env: Environment
var _tema := ""
var _tema_ton := Color.WHITE
var _lykta: OmniLight3D = null
var _lågor: Array = []             ## fackelljusen, för fladdret i _process
var _fladder := 0.0
## Mätflaggor: `-- lykta=6 omgivning=0.05` provar en ljusnivå utan att bygga om. Stämningen är
## siffror, och en siffra ska gå att mäta på en skärmbild innan den hamnar i konstanterna.
var _lykta_energi := LYKTA_ENERGI
var _ljus_f := LJUS_STYRKA        ## ljuset på ytorna just nu, se LJUS_STYRKA (`_ljus_styrka` rattar den)
var _ljus_glans := LJUS_GLANS     ## `light_specular` på lyktan och facklorna (`_glans_styrka` rattar den)
var _omgivning := -1.0
var _lykta_falloff := LYKTA_FALLOFF
var _skugga := true                ## lyktans skuggor: mätt att de kostar några fps, se PLAN.md M17
var _kartor := true                ## normal- och ORM-kartorna (2.5D)
## Den MÅLADE kantens kontrast i albedon, dämpad (0-1). Se `_kant_dämpad`: en ritad kant ser likadan
## ut från varje vinkel, och det var hypotesen — att den skulle överrösta reliefen.
##
## HYPOTESEN ÄR MÄTT FALSK, och ratten är farlig: `_kant_dämpad` blandar albedon mot en NEDSKALAD
## kopia (4x ner, bilinjär upp), och vid 1,0 är det hela bilden som blir suddig — inte kanten.
## Mätt på en SUPER-RUTA i EN körning (samma kamera, Forward+):
##
##   relief-signalen (normal_scale 0 mot 4)   medel   p99
##   suddig albedo (kant 1,0)                 2,173   38,0
##   skarp albedo (kant 0,0)                  2,055   46,0
##   brusgolv (samma inställning två gånger)  0,195    1,0
##
## Dämpningen ger alltså INGEN mer relief (2,17 mot 2,06 ligger inom bruset) — den byter bara ut
## konsten mot en körtidskopia. Att albedon blev en körtidskopia var också det som fällde provet i
## test_normalprov ("albedo, normal och ORM hör till samma ruta": albedons resource_path blev tom,
## medan normal och ORM behöll sina). 0,0 = konsten som generatorn gjorde den, orörd, och samma
## resurs — provet fäller om albedon byts mot en körtidskopia igen.
## Ratten går att prova utan att bygga om: `-- kant=0.4`.
var _kant := KANT
const KANT := 0.0
var _kant_cache := {}
var _radhet_cache := {}            ## ORM-textur -> råhet (G-kanalens medelvärde), se `_radhet`
var _blöt_cache := {}              ## ORM-textur -> andelen blöta pixlar, se `_blöt_andel`
var _normalprov := -1.0            ## -- normalprov=0|1: mätflaggan för normalmappningen (se _normalprov_prov)
var _normalprov_lista := ""        ## samma flagga som "0,1,2,3": en svepning i stället för de fyra bilderna
## `-- provruta=super` mäter bara SUPER-RUTORNA (de stora ytorna som fyller skärmen). Utan den mäter
## provet allt som ritas — och då kan en liten yta med karta dölja att den stora saknar en.
var _provruta := ""
## `-- glansprov[=fackla|pöl]`: glansen A/B i en körning (se `_glansprov`). Tom = inte igång.
var _glansprov_pose := ""
## `-- fienderödfärg`: ger fiendefigurerna en SJÄLVLYSANDE magenta. Ett mätprov, inte en funktion:
## frågan *"hur brett ritas figuren?"* kan inte avgöras på en mörk figur i en mörk gång — men en
## magenta figur syns i bild och går att mäta. Provar gör det som faktiskt ritas, inte teorin.
var _fiende_rödfärg := false
var _ssr := true                   ## skärmbaserade reflektioner (vatten, ben)
var _ao := true                    ## kontaktmörker i fogar och hörn (SSAO)
var _ssil := true                  ## indirekt ljus ur samma pass (SSIL): ljuset som studsar i hörnen
var _vol := true                   ## volymetrisk dimma: ljuskäglorna i luften (facklor och lyktan)
var _kontrast := 1.0               ## `kontrast=N`: kontrasten i spelvyn (granskningsflagga)
var _crt_styrka := 1.0             ## `crt=N`: CRT-lagrets styrka (0 = av), granskningsflagga
var _crt_av := false               ## `crt=0`: CRT-lagret av — granskningsflagga, för att kunna MÄTA
                                   ## hur mycket kontrast lagret tar (samma skäl som ssr=0/vol=0)
var _fx := true
var _takdropp_på := true           ## -- tak=0 stänger av takdroppet (mätning, inte spel)
var _takställen: Array = []        ## [position, slag] per takdropp (nodprov=dropp går till ett av dem)
var _droppar: Array = []           ## droppställena: {nod, kvar, accent, rng} — klockan äger main.gd
var _dropprng := RandomNumberGenerator.new()   ## fröet sätts per våning i _build_world
var _världsbyggen := 0             ## hur många gånger vyn byggts om (mätt i fpsprov: ska vara 1 per våning)
var _frame_sum := 0.0
var _frame_n := 0
var _frame_worst := 0.0
var _cam_tween: Tween = null       ## kamera-glidningen, så en snäpp-kamera kan döda den (se _snap_cam)
# ALBUMET (M34, punkt 9): de ägda korten, det valda indexet och vyerna. Listan byggs när albumet
# öppnas — den läses inte i någon annan väg, så den kan inte hamna i otakt med metat.
var album_panel: PanelContainer
var album_label: Label
var album_box: HBoxContainer       ## tumnaglarna under det stora kortet
var album_stor: CenterContainer    ## den stora visningen
var album_ids: Array[String] = []
var album_index := 0

var active_node: Dungeon.FloorNode = null
var active_combat: Combat = null
var last_events := 0

func _ready() -> void:
	db = Cards.load_all()
	stages = Stages.load_all()
	bestiary = Enemies.load_all()
	# FIENDERETUSCHEN (M82) läses EN gång, innan första fienden ritas: receptet från fiendeeditorn
	# läggs på fiendebilden i `_enemy_tex`. Saknad fil är tomt recept (ingen retusch än).
	_retusch = Retusch.läs()
	# Metan läses EN gång, innan första körningen: guld, ranger och sparfilen. Ett trasigt eller
	# för nytt sparfilsläge säger ifrån i klartext i stället för att tyst spela som ny spelare.
	meta = Meta.load_or_new()
	if not meta.last_error.is_empty():
		push_warning("meta: %s" % meta.last_error)
		print("meta: %s" % meta.last_error)
	# Språket ur sparfilen, innan HUD:en byggs — annars står första bildrutan på svenska.
	if not Tr.set_lang(meta.language):
		meta.language = Tr.SOURCE
	# Felsökningsflagga: `-- lang=de` visar spelet på ett annat språk. Den rör inte sparfilen —
	# språkbytet i spelet sparar, och en granskning ska inte skriva över spelarens val.
	for f in OS.get_cmdline_user_args():
		if f.begins_with("lang="):
			Tr.set_lang(f.substr(5))
		elif f.begins_with("lykta="):
			_lykta_energi = float(f.substr(6))
		elif f.begins_with("omgivning="):
			_omgivning = float(f.substr(10))
		elif f.begins_with("dekor="):
			# Dekorationens täthet i körningen: `dekor=0` stänger av den (A/B-mätningen), `dekor=8` glesar
			# ut den. Rör inte konstanten — samma väg som de andra mätflaggorna.
			_dekor_täthet = int(f.substr(6))
		elif f.begins_with("falloff="):
			_lykta_falloff = float(f.substr(8))
		elif f.begins_with("kortprov="):
			# Granskningsflagga: fyll samlingen med N kort ur datat, så att ALBUMET går att döma på
			# bild innan man äger något (sparfilen är tom tills man handlat). Fotoläget sätts här:
			# flaggan får aldrig skriva i spelarens profil.
			Meta.fotolage(true)
			for id in db.keys().slice(0, int(f.substr(9))):
				meta.ranks[str(id)] = 1
		elif f == "skugga=0":
			_skugga = false
		elif f == "kartor=0":
			_kartor = false
		elif f.begins_with("provruta="):
			_provruta = f.substr(9)
		elif f.begins_with("kant="):
			_kant = clampf(float(f.substr(5)), 0.0, 1.0)
		elif f.begins_with("normalprov="):
			_normalprov_lista = f.substr(11)
			_normalprov = _prov_tal(_normalprov_lista.split(",")[0])["skala"]
		elif f == "fienderödfärg":
			_fiende_rödfärg = true
		elif f == "glansprov":
			_glansprov_pose = "fackla"
		elif f.begins_with("glansprov="):
			_glansprov_pose = f.substr(10)
		elif f == "ssr=0":
			_ssr = false
		elif f == "ao=0":
			_ao = false
		elif f == "ssil=0":
			_ssil = false
		elif f == "vol=0":
			_vol = false
		elif f.begins_with("kontrast="):
			# Granskningsflagga: kontrasten i spelvyn (`adjustment_contrast`). Frågan är om det går att
			# få mer separation mellan ytorna utan att röra konsten — mätt mot std i spelvyn.
			_kontrast = maxf(0.2, float(f.substr(9)))
		elif f.begins_with("ljus="):
			# Granskningsflagga: ljusstyrkan på lyktan och facklorna (`LJUS_STYRKA`). Behövs för att
			# kunna MÄTA hur histogrammet flyttar sig — ett starkt ljus som rullas av i tonemappningen
			# ger en ljus, platt bild (samma sak som `crt=0` mäter för CRT-lagret).
			_ljus_f = float(f.substr(5))
		elif f.begins_with("crt="):
			# Granskningsflagga: `crt=0` slår av CRT-lagret, `crt=0.5` halverar styrkan (skanlinjer,
			# vinjett, välvd kant). Behövs för att kunna MÄTA hur mycket av bildens kontrast lagret
			# tar — samma skäl som ssr=0/vol=0.
			var crt_v := clampf(float(f.substr(4)), 0.0, 1.0)
			_crt_av = crt_v <= 0.0
			_crt_styrka = crt_v
		elif f == "vsync=0":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		elif f == "fx=0":
			_fx = false
		elif f == "tak=0":
			_takdropp_på = false
	# Banordningen: karta och upplåsning följer svårighet, och vid lika svårighet id — samma
	# ordning varje gång, så "nästa bana" betyder samma sak i sparfilen som på kartan.
	# Kartan (M41): bilden, vinkeln och nodernas plats ur data/karta.json. Laddaren VALIDERAR (en nod
	# utanför bilden, en bana som inte finns, en elfte nivå) — en trasig kartfil ska säga det i loggen
	# i stället för att se ut som en karta utan noder.
	karta = Karta.ladda()
	for rad in karta.fel:
		push_warning("kartan: %s" % rad)
	_stage_order = stages.keys()
	_stage_order.sort_custom(func(a, b):
		var sa: Stages.StageDef = stages[a]
		var sb: Stages.StageDef = stages[b]
		if sa.difficulty != sb.difficulty:
			return sa.difficulty < sb.difficulty
		return str(a) < str(b))
	_load_sfx()
	_build_hud()
	# Bakgrundsfärg i stället för kolsvart: himlen/taket ovanför väggarna ska läsas som rum.
	# Färgen, omgivningsljuset och dimman byts per tema i `_apply_tema`.
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.10)
	# Omgivningsljuset är TAKTEN, inte en sol: det räcker för att man ska ana rummet utanför
	# lyktans krets. Ett platt ljus på allt (som förut) gav ingen rymd alls.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	# Ned från 0,25. Ett platt ljus på allt är inte ljus, det är en dimma: det lyfter de svarta
	# partierna lika mycket som de ljusa och dödar rymden. Det låg på 0,25 för att facklorna var
	# svaga — då ska facklorna upp, inte dimman. (Samma mätning gjordes i andra projektet: en
	# osynlig sol tvättade rummet vitt och togs bort.)
	env.ambient_light_energy = 0.08
	# Dimma: mörkret längst bort ska vara en vägg av luft, inte bara svart. Den bär också avståndet
	# i långa korridorer, där lyktan annars bara tar slut.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.10, 0.11, 0.15)
	env.fog_light_energy = 0.6
	env.fog_density = 0.04
	# Reflektioner: vattnet och benet ska spegla rummet, inte bara lyktan. SSR är skärmbaserat — det
	# som syns i bild kan speglas, vilket är precis vad en pöl i en korridor gör.
	env.ssr_enabled = _ssr
	env.ssr_max_steps = 32
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 12.0
	# Kontaktmörker i fogar och hörn: utan det syns reliefen från normalerna bara där ljuset råkar
	# falla på en kant. Radien är en meter — samma skala som blocken.
	env.ssao_enabled = _ao
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.8
	# SSIL: samma skärmpass som AO, men det lägger till det LJUS som studsar mellan ytorna i stället
	# för att bara mörkna fogarna. Det är skillnaden mellan "håligheter" och "ett rum där lyktan
	# lyser upp hörnet bredvid". Låg intensitet med flit: i en mörk korridor blir indirekt ljus
	# snabbt en grå hinna över hela bilden (samma läxa som ambientljuset på 0,25).
	env.ssil_enabled = _ssil and _ao
	env.ssil_intensity = 0.45
	env.ssil_radius = 2.0
	env.ssil_sharpness = 0.98
	# Volymetrisk dimma: ljuskäglorna i LUFTEN. Den vanliga dimman (ovan) lägger en ton över
	# avståndet; den här gör facklans och lyktans ljus till en kägla man ser — elden lyser inte bara
	# på stenen, den lyser i röken. Tätheten sätts per tema i `_apply_tema`, eftersom ett värde som
	# passar kryptan dränker brons öppna grotta.
	env.volumetric_fog_enabled = _vol
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.55, 0.52, 0.58)
	env.volumetric_fog_anisotropy = 0.35      # mest ljus framåt: käglan syns när man ser MOT ljuset
	env.volumetric_fog_length = 26.0
	env.volumetric_fog_gi_inject = 0.6        # låt lyktans ljus fylla dimman, inte bara dimma den
	env.volumetric_fog_ambient_inject = 0.25
	# Glow: det som gör elden "modern". Utan den är en låga en platt orange fläck; med den blomstrar
	# allt som är LJUSARE än vitt (HDR) — eld, lava, glöden i en spricka och reflexen i vatten — och
	# ingenting annat. Tröskeln ligger över 1,0 av det skälet: stenen får inte blomma.
	# KONTRAST (granskningsflagga `kontrast=N`): tonemappningen (AgX) rullar av högdagrarna och
	# krymper skillnaden mellan ytorna. En rak kontrastkurva efter den lägger tillbaka en del av
	# separationen — men höjer också svärtan, så den mäts (std i spelvyn) innan den får bli standard.
	env.adjustment_enabled = _kontrast != 1.0
	env.adjustment_contrast = _kontrast
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Tonemapping: AgX rullar av högdagrarna i stället för att klippa dem. Utan den blir en låga en
	# vit klump med hård kant (och glow gör den värre); med den får den en kärna, en krans och en
	# färg som går mot gult. Det är den enskilt största skillnaden mellan "portad plattformsspel"
	# och "modern motor", och den kostar en rad.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	# Miljön hör till SPELVYN: dimman, glöden och tonemappningen gäller den rutan, inte HUD:en
	# runt omkring (en WorldEnvironment i huvudscenen hade färgat hela fönstret).
	_vy.add_child(we)
	# Playtest från kart-editorn: en liten fil med bana och våning. Den konsumeras (tas bort) när den
	# lästs, så en kvarglömd fil inte flyttar nästa vanliga start.
	var pt := _take_playtest()
	# Samma väg från kommandoraden: `tools/play.sh -- stage=stage_03 vaning=2`. Våningen skrivs som
	# en människa räknar den (1 = första), inte som kod (0).
	for f in OS.get_cmdline_user_args():
		if f.begins_with("stage="):
			pt["stage_id"] = f.substr(6)
		elif f.begins_with("vaning="):
			pt["floor"] = maxi(0, int(f.substr(7)) - 1)
	# Felsökningsflaggor: `-- shot` tar en skärmbild och avslutar, `-- shots` spelar igenom hela
	# körningen och fotograferar varje skärm, `-- skarmar` fotograferar skalet (byn/butiken/kartan)
	# i stället. Flaggar man för något av dem startar körningen som förr: en flagga som ska granska
	# spelet ska inte stanna i en meny.
	var flags := OS.get_cmdline_user_args()
	# nodprov=<kind> fotograferar en nod på håll (kista, spade, fackla). Läses här också, för annars
	# startar spelet i byn i stället för i våningen och provet mäter en meny.
	var nodprov := ""
	Meta.fotolage(not flags.is_empty())   # varje --flagga = en körning som inte är spelarens
# skarm=by|butik|vardshus|smed|karta startar direkt på den skärmen. Utan den gick bara HELA
	# skalet att fotografera (`-- skarmar`), och en enskild skärm fick man leta upp med tangenterna.
	var skarm := ""
	for f in flags:
		if f.begins_with("nodprov="):
			nodprov = f.substr(8)
		elif f.begins_with("skarm="):
			skarm = f.substr(6)
		elif f.begins_with("fiendevisprov="):
			# Materialprovet (M73): tvinga fram EN fiendetyp i våningens strid, så en mask kan dömas mot
			# sin egen fiende i stället för mot den tier-1-figur som råkar stå där. Tvingar bara VILKEN
			# fiende som ställs upp — hur den ställs upp, och allt annat, är spelets egen väg.
			_fiendeprov = f.substr(14)
	if not _fiendeprov.is_empty():
		print("fiendevisprov: %s tvingas fram i våningens strider" % _fiendeprov)
	var kör: bool = (not pt.is_empty() or flags.has("shots") or flags.has("shot")
		or flags.has("kistprov") or flags.has("kistnara") or flags.has("fpsprov") or flags.has("fackelprov") or flags.has("figurprov")
		or flags.has("kortvalsprov")
		or flags.has("lageprov") or flags.has("stegprov") or flags.has("handprov") or flags.has("grävprov")
		or _normalprov >= 0.0
		or not _glansprov_pose.is_empty()
		or flags.has("guiprov") or flags.has("vinstprov")
		or not nodprov.is_empty()) and not flags.has("skarmar") and skarm.is_empty()
	if not kör:
		# Vanlig start (eller en enskild skärms skärmbildsläge): byn först. Ingen körning finns än,
		# så vyn är tom bakom panelerna — en kvarglömd korridor bakom byn vore en lögn om var man är.
		_build_empty_view()
		# STARTMENYN (M39) visas vid en RIKTIG spelarstart. Varje --flagga är en körning som granskar
		# spelet (fotoläge), och en meny mitt i en svit av skärmbilder hade gömt det som skulle
		# granskas — därför bara av sig själv, eller med `-- meny`/`-- menyprov` när menyn ÄR det som
		# ska granskas.
		if flags.is_empty() or flags.has("meny") or flags.has("menyprov"):
			_visa_meny()
			if flags.has("menyprov"):
				await _demo_meny()
			return
		_välj_skarm(skarm)
		if flags.has("skarmar"):
			_demo_shell()
		elif flags.has("shot"):
			await _shot_skarm(skarm)
		return
	if pt.is_empty():
		_start_run("stage_01", 20260919)
	else:
		# Sagt högt, av samma skäl som skärmbilderna: en flagga som tyst gör något annat än standard
		# går inte att skilja från en flagga som inte gjorde något.
		print("startar på %s våning %d" % [pt.get("stage_id", "stage_01"), int(pt.get("floor", 0)) + 1])
		_start_run(str(pt.get("stage_id", "stage_01")), 20260919, int(pt.get("floor", 0)))
	if flags.has("figurprov"):
		await _figurprov()
		return
	if flags.has("fpsprov"):
		await _fps_prov()
		return
	if _normalprov >= 0.0:
		await _normalprov_prov()
		return
	if flags.has("grävprov"):
		await _gräv_prov()
		return
	if flags.has("kistprov"):
		await _demo_chest()
		return
	if flags.has("kistnara"):
		await _kistnara_prov()
		return
	if flags.has("kortvalsprov"):
		await _demo_draft()
	if flags.has("guiprov"):
		await _demo_gui()
		return
	if flags.has("vinstprov"):
		await _demo_vinst()
		return
		return
	if flags.has("fackelprov"):
		await _demo_node("torch", "fackla", 45)     # 45 bildrutor: lågan behöver tid att byggas upp
		return
	if not _glansprov_pose.is_empty():
		await _glansprov()
		return
	if flags.has("lageprov"):
		await _lageprov()
		return
	if flags.has("handprov"):
		await _hand_prov()
		return
	if flags.has("stegprov"):
		await _steg_prov()
	if not nodprov.is_empty():
		# Dropp-provet väntar längre: en droppe är i luften nästan jämnt, men inte i varje bildruta.
		await _demo_node(nodprov, nodprov, 45 if nodprov == "dropp" else 2)
		return
	if flags.has("shots"):
		_demo_run()
	elif flags.has("shot"):
		await get_tree().create_timer(1.0).timeout
		var path := "user://shot.png"
		if not _spara_bild(path):
			get_tree().quit(1)
			return
		print("skärmbild: %s" % ProjectSettings.globalize_path(path))
		get_tree().quit()

## Skärmbild av en ruta. Spara den och svara om det gick.
##
## MÄTT: i huvudlöst läge finns ingen rityta alls (DisplayServer headless + dummy-renderare), så
## `get_texture().get_image()` svarar null och körningen dog med "Cannot call method 'save_png' on a
## null value" — ett mätinstrument som ser ut att ha mätt något, utan bild. Nu säger den till.
## Bilder kräver en rityta: `DISPLAY=:99 tools/play.sh ...` (Xvfb duger).
func _spara_bild(sökväg: String, ruta: Viewport = null) -> bool:
	var v: Viewport = get_viewport() if ruta == null else ruta
	var bild := v.get_texture().get_image()
	if bild == null or bild.is_empty():
		push_error("ingen bild kunde läsas (%s): huvudlöst läge har ingen rityta — kör med DISPLAY=:99"
			% sökväg)
		return false
	bild.save_png(sökväg)
	return true

## FPS-provet: rendera våningen i några sekunder utan att spela, och räkna bildrutorna. Demons siffra
## duger inte för att döma skuggor — den väntar mest på timers (mätt: 41 bildrutor över en hel körning).
## Det här provet gör ingenting annat än ritar, så siffran handlar om renderingen.
func _fps_prov(sekunder: float = 6.0) -> void:
	# UPPVÄRMNING först: de första sekunderna går åt till att bygga våningen och kompilera
	# skuggprogrammen, och de bildrutorna mäter inte SPELET. Mätt utan uppvärmning: 4 fps över 26
	# bildrutor (sämsta 148 ms) — med uppvärmning är siffran spelets. Uppvärmningen räknas för sig,
	# så att det går att se hur lång den var.
	var varma := 0
	var varm_t0 := Time.get_ticks_msec()
	while varma < 90 and (Time.get_ticks_msec() - varm_t0) < 5000:
		await get_tree().process_frame
		varma += 1
	var t0 := Time.get_ticks_msec()
	var n := 0
	var värst := 0.0
	while (Time.get_ticks_msec() - t0) / 1000.0 < sekunder:
		await get_tree().process_frame
		n += 1
		värst = maxf(värst, get_process_delta_time())
	var sek := (Time.get_ticks_msec() - t0) / 1000.0
	# Bildrutor per sekund är inte nog: hela körningen ligger nära 60 fps oavsett vad som slås på, så
	# kostnaden syns i RITANROPEN i stället — de beror inte på bildruteloppet. Partiklarna räknas
	# också: ett moln som slutat emittera syns inte i fps, men kostar fortfarande.
	var anrop := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	# VAR kostar bildrutan? En bildruta på 145 ms som inte rör sig alls när skuggor, lyktor,
	# partiklar och upplösning stängs av (mätt: 320x180 gav samma 145 ms som 1280x720, och ett TOMT
	# Godot-projekt på samma skärm gav 88 fps) är inte GPU:n. Skripttiden skiljer fallen åt.
	var skript := Performance.get_monitor(Performance.TIME_PROCESS)
	var fysik := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var moln := 0
	var partiklar := 0
	var slag := {}
	for c in find_children("*", "GPUParticles3D", true, false):
		moln += 1
		partiklar += (c as GPUParticles3D).amount
		var nyckel := "%s (%s)" % [c.name, c.get_parent().name]
		slag[nyckel] = int(slag.get(nyckel, 0)) + 1
	if OS.get_cmdline_user_args().has("fxprov"):
		print("    vyn byggd %d gånger" % _världsbyggen)
		for k in slag:
			print("    %s × %d" % [k, slag[k]])
	print("fpsprov: uppvärmning %d bildrutor på %.1f s, sedan %.0f fps över %d bildrutor på %.1f s, sämsta bildruta %.0f ms — skuggor %s, lykta %.1f, %d ritanrop, %d partikelmoln (%d partiklar)"
		% [varma, (t0 - varm_t0) / 1000.0, n / maxf(sek, 0.001), n, sek, värst * 1000.0,
		"på" if _skugga else "av", _lykta_energi * _ljus_f, anrop, moln, partiklar])
	print("fpsprov: skripttid %.1f ms, fysiktid %.1f ms per bildruta (resten är rendering/väntan)"
		% [skript * 1000.0, fysik * 1000.0])
	get_tree().quit()

## Mätflaggan för normalmappningen: `-- normalprov=0|1`.
##
## Varför den finns: Alex såg att våningen är helt platt trots att rutornas normal-kartor lutar
## 15-20 grader. Frågan "når kartan shadern?" går inte att svara på med ögat (albedon har ritade
## kanter och skuggor, så en platt yta ser ändå strukturerad ut) och inte med två körningar heller:
## LJUSET varierar mellan körningar — samma bygge gav medel-RGB 73 i en körning och 31 i en annan —
## så en skillnad mellan två processer drunknar i ljuset. Provet sätter därför normal_scale på DET
## MATERIAL SOM FAKTISKT RITAS och tar alla bilderna i SAMMA körning med samma kamera:
##
##   a: 0,0 (normalkartan av — golvet)   b: 1,0 (spelets eget värde)
##   c: 8,0 (avsiktligt extremt)         d: 0,0 igen (slumpens golv: fladdrande facklor, temporal GI)
##
## |a−b| är vad spelet gör i dag. |a−c| svarar på om kartan når shadern alls: händer inget vid 8x
## sitter felet i materialvägen, inte i kartan. |a−d| är den skillnad slumpen kan åstadkomma, och ett
## |a−b| i den storleken betyder "ingen skillnad" — därför mäts den i samma körning.
##
## `1` byter plats på 1,0 och 8,0, så svaret inte kan bero på vilken bild som råkades ritas först.
##
## Svensken i en post är `skala@kant`: `-- normalprov=4@0,4@1,4@0` mäter albedons målade kant av och
## på i SAMMA körning med samma kamera, med nolläget sist som brusgolv. Utan `@` sätts bara
## normal_scale, precis som förut.
func _normalprov_prov() -> void:
	await get_tree().create_timer(1.2).timeout    # låt ljuset och första bildrutan sätta sig
	var material := _ritade_material()
	# `-- provruta=super`: bara de stora ytorna. Annars kan en liten ruta med karta dölja att den
	# stora ytan man tittar på mest saknar en — och det är den ytan Alex ser som platt.
	if not _provruta.is_empty():
		var bara := []
		for m in material:
			if m.albedo_texture != null and m.albedo_texture.resource_path.contains(_provruta):
				bara.append(m)
		print("[normalprov] provruta=%s: %d av %d material i vyn" % [_provruta, bara.size(), material.size()])
		material = bara
	# Albedon så som rutan RITADES, före någon dämpning: svepningen måste kunna gå tillbaka till
	# nolläget, och en dämpad textur som dämpas igen är inte samma bild.
	var ursprung := {}
	for m in material:
		ursprung[m] = m.albedo_texture
	var utan := []
	var med_normal := 0
	var med_orm := 0
	for m in material:
		if m.normal_texture != null:
			med_normal += 1
		if m.normal_texture == null and m.albedo_texture != null:
			utan.append(m.albedo_texture.resource_path.get_file())
		if m.roughness_texture != null:
			med_orm += 1
	print("[normalprov] %d material i vyn, %d bär en normal_texture, %d en ORM-texture"
		% [material.size(), med_normal, med_orm])
	# Det som fäller provet: ett material som RITAS utan normalkarta är en platt yta. "Något material
	# någonstans bär en karta" duger inte som svar.
	if not utan.is_empty():
		print("[normalprov] FEL: de här materialen ritas utan normal_texture: %s" % ", ".join(utan))
	# En normalmap UTAN tangenter förkastas tyst. Provet svarar på det med samma körning som mäter:
	# mesh-formatet står i loggen bredvid siffrorna.
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		var arr: Array = (n as MultiMeshInstance3D).multimesh.mesh.surface_get_arrays(0)
		var tangent: int = 0
		if arr.size() > Mesh.ARRAY_TANGENT:
			tangent = (arr[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size()
		print("[normalprov] %s: %d ytor, tangenter %d, uv %d"
			% [n.name, arr.size(), tangent,
			(arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() if arr.size() > Mesh.ARRAY_TEX_UV else 0])
		break
	# Bilderna i SAMMA körning och med samma kamera. Nolläget (kartan av) först, sedan spelets eget
	# värde (1,0), det extrema (8,0), och sist nolläget igen — den sista är golvet för skillnaden
	# (facklorna fladdrar, GI:n är temporal), så ett |a−b| i den storleken betyder "ingen skillnad".
	# `normalprov=0,1,2,3` ger en svepning i stället: skalan man skickar in, i den ordningen.
	# `normalprov=4@0,4@1,4@0` sveper BÅDA rattarna: normal_scale 4,0 med albedons målade kant av,
	# på och av igen (sista bilden är brusgolvet).
	var skala: Array = [0.0, 1.0, 8.0, 0.0] if _normalprov < 0.5 else [0.0, 8.0, 1.0, 0.0]
	var kant: Array = [_kant, _kant, _kant, _kant]
	var ljus: Array = [-1.0, -1.0, -1.0, -1.0]
	if _normalprov_lista.contains(","):
		skala = []
		kant = []
		ljus = []
		for del in _normalprov_lista.split(","):
			var post := _prov_tal(del)
			skala.append(post["skala"])
			kant.append(post["kant"])
			ljus.append(post["ljus"])
		# Sista bilden är SAMMA inställning som den första igen: den är brusgolvet (facklorna
		# fladdrar, GI:n är temporal), och den ska ha samma ljus som bilden den jämförs med.
		skala.append(skala[0])
		kant.append(kant[0])
		ljus.append(ljus[0])
	var n := 0
	for i in skala.size():
		n += 1
		await _normalprov_bild(material, ursprung, skala[i], kant[i], ljus[i],
			"%02d-s%.1f-k%.2f-l%.1f" % [n, skala[i], kant[i], ljus[i]])
	get_tree().quit()


## En post i svepningen: "4" = normal_scale 4,0 och spelets kant; "4@0.5" = normal_scale 4,0 med den
## målade kanten halvvägs dämpad; "4@0@2" = samma sak med LJUSET på ytorna dubblat.
##
## Den TREDJE ratten är ljuset, och den finns för att reliefen bor i SKUGGNINGEN: samma yta med
## starkare ljus på sig ska ge en starkare relief-signal, och det ska gå att se i EN körning.
## Ljusnivåer mellan två körningar går inte att jämföra (samma läxa som resten av normalprovet).
func _prov_tal(del: String) -> Dictionary:
	var bitar := del.split("@")
	return {"skala": float(bitar[0]),
		"kant": float(bitar[1]) if bitar.size() > 1 else _kant,
		"ljus": float(bitar[2]) if bitar.size() > 2 else -1.0}


## Sätter normal_scale, albedons kant och LJUSET på materialet som ritas och sparar en bild. Skriver ut
## alla tre rattarna och bildens ljusfördelning: utan ljusnivån går det inte att se om en skillnad kom
## av normalkartan eller av att en fackla råkade flamma upp mellan bilderna — och utan FÖRDELNINGEN
## (inte bara medelvärdet) går det inte att se skillnad på "ytorna där ljuset faller blev ljusare" och
## "hela bilden lyftes av en dimma".
func _normalprov_bild(material: Array, ursprung: Dictionary, skala: float, kant: float, ljus: float,
		namn: String) -> void:
	for m in material:
		m.normal_scale = skala
		# Albedon byts mot sin dämpade version. Samma väg som världsbygget går, så provet mäter
		# mekanismen och inte en kopia av den.
		var tex: Texture2D = ursprung.get(m)
		if tex != null:
			m.albedo_texture = _kant_dämpad(tex, kant)
	# Ljuset på ytorna. -1 = rör inte lyktan (bilden tas med körningens eget ljus).
	if ljus > 0.0:
		_ljus_styrka(ljus)
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	var path := "user://normalprov-%s.png" % namn
	# EN läsning av rutan, och både bilden och siffran kommer ur den. Läste provet om rutan för
	# medelljusheten kunde en fackla flamma upp mellan de två och mätningen jämföra olika bildrutor.
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("ingen bild kunde läsas (%s): huvudlöst läge har ingen rityta — kör med DISPLAY=:99"
			% path)
		get_tree().quit(2)
		return
	img.save_png(path)
	var st := _bild_statistik(img)
	print("[normalprov] normal_scale %.1f kant %.2f lykta %.1f -> %s (medel %.4f, p50 %.4f, p90 %.4f, p99 %.4f, mörkt %d %%, ljust %d %%, %d material)"
		% [skala, kant, _lykta.light_energy if _lykta != null else 0.0,
			ProjectSettings.globalize_path(path), st["medel"], st["p50"],
			st["p90"], st["p99"], st["mörkt"], st["ljust"], material.size()])

## Ljusfördelningen i en bild: medel, median, p90, p99 och hur stor del av bilden som är MÖRK
## (under MÖRK_TRÖSKEL) respektive LJUS (över LJUS_TRÖSKEL), i procent.
##
## Medelvärdet ensamt döljer precis det som ska mätas här: en ändring som lyfter de mörka partierna
## (dimma, omgivningsljus) och en som lyfter ytorna där ljuset faller (lyktan, facklorna) kan ge samma
## medel men aldrig samma fördelning. Måttet är det ögat läser rummet med.
func _bild_statistik(img: Image) -> Dictionary:
	img.convert(Image.FORMAT_RGBA8)          # kanalerna nedan är RGBA i den ordningen
	var d := img.get_data()
	var n := img.get_width() * img.get_height()
	var v := PackedFloat32Array()
	v.resize(n)
	var mörkt := 0
	var ljust := 0
	var högdagrar := 0
	for i in n:
		var l := (float(d[i * 4]) + float(d[i * 4 + 1]) + float(d[i * 4 + 2])) / 765.0
		v[i] = l
		if l < MÖRK_TRÖSKEL:
			mörkt += 1
		elif l > LJUS_TRÖSKEL:
			ljust += 1
		if l > HÖGDAGER_TRÖSKEL:
			högdagrar += 1
	v.sort()
	var sum := 0.0
	for l in v:
		sum += l
	return {"medel": sum / float(maxi(n, 1)),
		"p50": v[int(n * 0.50)], "p90": v[int(n * 0.90)], "p99": v[int(n * 0.99)],
		"mörkt": int(round(100.0 * mörkt / float(maxi(n, 1)))),
		"ljust": int(round(100.0 * ljust / float(maxi(n, 1)))),
		"högdagrar": högdagrar}

## Materialet som FAKTISKT ritas i vyn — material_override först, annars mesh:ens material, alltså den
## väg renderaren själv går.
##
## MÄTT, två fällor i samma funktion:
## 1. `find_children("*", "MeshInstance3D")` hittar INTE väggar och golv. En `MultiMeshInstance3D` är
##    inget barn till `MeshInstance3D` — den är ett SYSKON (båda ärver `GeometryInstance3D`) och har
##    ingen `get_active_material`. Provet pekade därför på sex oskyldiga en-ytiga meshar och satte
##    normal_scale på dem, medan den ytan Alex tittar på stod orörd.
## 2. En `MultiMesh` ritar `multimesh.mesh`-ens material. `mesh.surface_get_material(0)` duger inte
##    heller: på en `BoxMesh` svarar den med sex TOMma standardmaterial (albedo nej, normal nej,
##    uv1 (1,1,1)) — ett per yta — medan det som ritas ligger i `PrimitiveMesh.material`.
## Båda fällorna gav samma symptom: en override som inte tar i något, och tre bilder som var
## identiska (0,1577 / 0,1581 / 0,1599). Det är därför provet skriver ut VILKA material det fick tag i.
func _ritade_material() -> Array:
	var ut: Array = []
	if world == null:
		return ut
	for n in world.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n
		var m: Material = gi.material_override
		if m == null and n is MultiMeshInstance3D:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			if mm != null and mm.mesh is PrimitiveMesh:
				m = (mm.mesh as PrimitiveMesh).material
		if m == null and n is MeshInstance3D:
			m = (n as MeshInstance3D).get_active_material(0)
		if m is StandardMaterial3D and not ut.has(m):
			ut.append(m)
	return ut

## Handprovet: solfjäderns geometri i siffror. Går fram till en fiende, startar striden och skriver
## varje korts plats, vinkel och storlek. "Det ser ut som en solfjäder" är ett omdöme; siffrorna
## visar att bågen finns, att korten vrider sig utåt och hur mycket ytterkortet sitter lägre.
func _hand_prov() -> void:
	var nod: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if not n.cleared and (n.kind == "encounter" or n.kind == "boss"):
			nod = n
			break
	if nod == null:
		print("[handprov] våningen har ingen fiende kvar (prova en annan bana)")
		get_tree().quit()
		return
	# Provet måste stå PÅ eller INVID fiendens ruta: `_gå_till_och_vänd` stannar en ruta ifrån (den
	# fotograferar noden på håll). Ett steg framåt mot noden, sedan är den under fötterna eller
	# framför — båda duger för `_enter_node_here`, som är samma väg in som tangentbordet tar.
	await _gå_till_och_vänd(nod.pos)
	run.explore.face(nod.pos)
	run.explore.forward()
	_snap_cam()
	_enter_node_here()
	for i in 45:
		await get_tree().process_frame
	if hand_views.is_empty():
		print("[handprov] striden startade inte (ingen hand byggdes)")
		get_tree().quit()
		return
	var n := hand_views.size()
	print("[handprov] %d kort i handen, kortstorlek %.0fx%.0f px" % [n, hand_views[0].home_size.x, hand_views[0].home_size.y])
	var mitten := (n - 1) / 2.0
	for i in n:
		var v: CardView = hand_views[i]
		print("[handprov]   kort %d: t %+.1f, pos (%.0f, %.0f), vinkel %+.3f rad (%+.1f grader)"
			% [i, float(i) - mitten, v.home_pos.x, v.home_pos.y, v.home_rot, rad_to_deg(v.home_rot)])
	if n >= 2:
		var ytter: CardView = hand_views[0]
		var ytter2: CardView = hand_views[n - 1]
		# Bågen mäts som hur mycket ytterkorten sitter lägre än mittenkortet, och som vinkeln mellan
		# ytterkortens vinklar: utan båge är båda noll.
		var djup: float = (ytter.home_pos.y + ytter2.home_pos.y) / 2.0 - _hand_topp_y()
		print("[handprov] bågen: ytterkorten sitter %.0f px lägre än mittenkortet, vinkelskillnaden är %.1f grader"
			% [djup, absf(rad_to_deg(ytter.home_rot - ytter2.home_rot))])
	# HUD-ytans egna rutor i siffror: en text som "ser avhuggen ut" i en granskning kan sitta rätt
	# — eller fel. Fönstret och räknarens ruta avgör, inte en läsares omdöme.
	var fönster := get_viewport().get_visible_rect().size
	# `position` är alltid relativ till förälderns övre vänstra hörn (även med bottenankare), så
	# nederkanten är position.y + höjden — inte fönstrets höjd plus positionen.
	print("[handprov] fönster %.0fx%.0f, korträknarens ruta (%.0f, %.0f) %.0fx%.0f = nederkant %.0f"
		% [fönster.x, fönster.y, kort_label.position.x, kort_label.position.y,
			kort_label.size.x, kort_label.size.y,
			kort_label.position.y + kort_label.size.y])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_spara_bild("user://shots/handprov.png")
	print("[handprov] bild i %s" % ProjectSettings.globalize_path("user://shots/handprov.png"))
	# Andra bilden: efter ETT spelat kort. Då ska siffran till vänster ha gått upp (kortet flög dit)
	# och en ny hand ha kommit från högen. Provet skriver båda siffrorna, så bilden och mätningen
	# säger samma sak.
	await _on_card(0)
	for i in 30:
		await get_tree().process_frame
	if active_combat != null:
		print("[handprov] efter ett spelat kort: lek %d, använda %d, hand %d"
			% [active_combat.draw_pile.size(), active_combat.discard_pile.size(),
				active_combat.hand.size()])
	_spara_bild("user://shots/handprov-efter.png")
	print("[handprov] bild efter spelat kort i %s"
		% ProjectSettings.globalize_path("user://shots/handprov-efter.png"))
	# Tredje bilden: EFTER TURENS SLUT, då nya kort dras ur högen och vänds. Provet fotograferar mitt
	# i vändningen (0,08 s in) och efteråt, och skriver hur många av handens kort som ligger med
	# baksidan upp — siffran och bilden säger samma sak.
	_on_end_turn()
	# Provet letar upp ögonblicket i stället för att gissa det: turbytet drar korten vid en tidpunkt
	# som beror på fiendens tur, så det samp
	# las var 0,1 s och bilden tas vid det FÖRSTA sampel där något kort ligger med baksidan upp —
	# det är mitt i vändningen. (Två tidigare försök mätte 0 för att de tittade för tidigt.)
	# Provet letar upp ögonblicket i stället för att gissa det, och fotograferar dessutom en SVIT:
	# turbytet drar korten vid en tidpunkt som beror på fiendens tur, så en enstaka bild kan träffa
	# före eller efter vändningen. Svitens bildrutor sätts ihop till en remsa (se bilderna i PLAN.md).
	var vända := 0
	var taget := false
	var t := 0.0
	for i in 24:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		vända = 0
		for v in hand_views:
			if (v as CardView).face_down:
				vända += 1
		if t <= 1.3:
			_spara_bild("user://shots/drag-%02d.png" % int(round(t * 10.0)))
		if vända >= 1 and not taget:
			taget = true
			var var_ := []
			for v in hand_views:
				if (v as CardView).face_down:
					var_.append("%d@x%.0f" % [(v as CardView).index, (v as CardView).position.x])
			print("[handprov] mitt i vändningen efter %.1f s: %d av %d kort har baksidan upp (%s)"
				% [t, vända, hand_views.size(), ", ".join(var_)])
			_spara_bild("user://shots/handprov-vand.png")
		if taget and vända == 0:
			print("[handprov] alla kort visar framsidan efter %.1f s" % t)
			break
	var kvar_vända := 0
	for v in hand_views:
		if (v as CardView).face_down:
			kvar_vända += 1
	print("[handprov] efter dragningen: %d av %d kort ligger med baksidan upp (ska vara 0), lek %d"
		% [kvar_vända, hand_views.size(), active_combat.draw_pile.size()])
	_spara_bild("user://shots/handprov-vand-efter.png")
	get_tree().quit()


## Mittenkortets överkant (solfjäderns högsta punkt), så att provet kan mäta bågen i px.
func _hand_topp_y() -> float:
	var topp := 0.0
	for v in hand_views:
		if v.home_pos.y < topp or topp == 0.0:
			topp = v.home_pos.y
	return topp


## Stegprovet: kamerans KÄNSLA i siffror. Ett steg och en sväng samplas var 40:e millisekund (tid,
## inte bildrutor — i demoläget går körningen i 7 fps och då vore varje sampel ett helt steg), och
## provet skriver vidvinkel, rullning och vinkel. Utan det är "det känns mjukt" ett omdöme.
func _steg_prov() -> void:
	for i in 4:
		await get_tree().process_frame
	print("[stegprov] utgång: fov %.2f rot.y %.3f rot.z %.3f" % [cam.fov, cam.rotation.y, cam.rotation.z])
	var steg_fel := run.explore.forward()
	if steg_fel != "":
		print("[stegprov] kunde inte gå framåt (%s) — mäter svängen i stället" % steg_fel)
	print("[stegprov] — ett steg framåt (STEG_TID %.2f s, puff %.0f grader) —" % [STEG_TID, PUFF])
	_animate_cam()
	for i in 6:
		await get_tree().create_timer(0.04).timeout
		print("[stegprov]   +%.2f s: fov %.2f rot.z %.4f pos %.2f" % [(i + 1) * 0.04, cam.fov,
			cam.rotation.z, cam.position.x])
	var före := cam.rotation.y
	run.explore.turn_right()
	print("[stegprov] — en sväng (SVÄNG_TID %.2f s, kräng %.3f) —" % [SVÄNG_TID, KRÄNG])
	_animate_cam()
	for i in 6:
		await get_tree().create_timer(0.04).timeout
		print("[stegprov]   +%.2f s: rot.y %.3f rot.z %.4f" % [(i + 1) * 0.04, cam.rotation.y,
			cam.rotation.z])
	var kortast := Explore.närmaste_vinkel(före, Explore.yaw_for(run.explore.facing)) - före
	print("[stegprov] svängen gick %.3f -> %.3f rad; kortaste vägen är %+.3f rad (%.0f grader)"
		% [före, cam.rotation.y, kortast, rad_to_deg(kortast)])
	get_tree().quit()


## Nodprovet: gå fram till en nod, ta två steg tillbaka och vänd dig om — och fotografera den.
##
## Varför inte bara stå på noden och titta? Därför att noderna ligger på GOLVRUTOR (man går fram till
## kistan eller facklan för att använda den). Står man på den har man den inne i kameran, och då mäter
## bilden ingenting. `fackelprov` är samma prov för facklan, som behöver längre väntan (lågan byggs
## upp över en halv sekund).
func _demo_node(kind: String, filnamn: String, vänta: int) -> void:
	var mål := Vector2i.ZERO
	if kind == "dropp":
		# Takdroppet sitter inte på en nod — det sitter där våningens frö lade det. Provet går till det
		# första stället och fotograferar TAKET, för det är därifrån det faller.
		if _takställen.is_empty():
			print("nodprov: våningen har inget takdropp (tak=0? eller tom våning)")
			get_tree().quit()
			return
		# Två saker avgör vilket ställe provet väljer: att kolumnen är LEDIG (står en fiende där ser man
		# ingen droppe alls — två försök fotograferade fiendehuvuden och jag mätte deras ögon som lava),
		# och att slaget syns (lava före vatten, för bilden ska dömas på det som syns mest).
		var upptagna := {}
		for n in run.explore.floor_ref.nodes:
			if not n.cleared:
				upptagna[n.pos] = true
		var val: Array = []
		for ställe in _takställen:
			var ruta := Vector2i(int(floor(ställe[0].x)), int(floor(ställe[0].z)))
			if upptagna.has(ruta):
				continue
			if val.is_empty() or (ställe[1] == "lava" and val[1] != "lava"):
				val = ställe
		if val.is_empty():
			val = _takställen[0]
		var var_det: Vector3 = val[0]
		mål = Vector2i(int(floor(var_det.x)), int(floor(var_det.z)))
		var avstånd_dropp := await _gå_till_och_vänd(mål)
		for i in vänta:
			await get_tree().process_frame
		# Starta droppen i stället för att hoppas på en. Med pauser mellan dropparna (2-6 s) är chansen
		# att en bild tagen på måfå innehåller en droppe liten, och ett prov som oftast fotograferar tom
		# luft mäter ingenting. Falltiden är en halv sekund, så bilden tas mitt i fallet.
		if not _starta_droppe_nära(var_det):
			print("nodprov: ingen droppe att starta vid %s" % str(var_det))
		for i in 6:
			await get_tree().process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
		_spara_bild("user://shots/%s.png" % filnamn)
		print("nodprov: takdropp (%s) vid %s, %d steg ifrån, bild i %s"
			% [val[1], str(var_det), avstånd_dropp,
				ProjectSettings.globalize_path("user://shots/%s.png" % filnamn)])
		get_tree().quit()
		return
	var nod: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == kind and not n.cleared:
			nod = n
			break
	if nod == null:
		print("nodprov: våningen har ingen %s (prova en annan bana eller våning)" % kind)
		get_tree().quit()
		return
	var avstånd := await _gå_till_och_vänd(nod.pos)
	await get_tree().process_frame
	for i in vänta:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_spara_bild("user://shots/%s.png" % filnamn)
	print("nodprov: %s (%s), %d steg ifrån, bild i %s"
		% [kind, str(nod.pos), avstånd, ProjectSettings.globalize_path("user://shots/%s.png" % filnamn)])
	get_tree().quit()


## Lågprovet: sex bilder ur SAMMA körning med samma kamera (Forward+), två rattar — lågans RUTA och
## lågans GLÖD (HDR-emission).
##
## Alex: *"facklans låga kan vara mindre med, den behöver inte vara stor alls, bara den lyser upp
## rummet"* — och *"en liten låga med samma ljusstyrka i rummet ska ge en krans, inte en vit klump.
## HDR-emissionen ligger på 4,0."* Poängen är alltså att skilja LJUSET från LÅGANS storlek: omni-ljuset
## i rummet står still (samma energi och räckvidd i alla sex bilderna, utskrivet i loggen), bara rutan
## och emissionen byts. Lågans pixelavtryck ska bli mindre, rummets ljushet oförändrad — och de två
## sista raderna är samma inställning som den nya lådan, alltså golvet för hur mycket elden hinner
## fladdra mellan två bilder i samma körning. Avtrycket läses ur bilderna som antal pixlar: kärna =
## grå ≥ 240 (utbränt), glöd = grå ≥ 200 (lågan med krans), vitt = min(R,G,B) ≥ 235, och rummets
## medel/p95 över spelvyn utan en fast ruta kring lågan (siffrorna står i fx.gd vid LÅGA_GLÖD).
##
## Att jämföra två KÖRNINGAR går inte: samma bygge gav medel-RGB 73 i en körning och 31 i en annan
## (samma läxa som normalprov).
const LÅGA_GAMMAL := Vector2(0.15, 0.20)
const LÅGA_GAMMAL_GLÖD := 4.0        # den delade GLÖD_ENERGI som lågan använde före LÅGA_GLÖD

func _lageprov() -> void:
	var nod: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == "torch":
			nod = n
			break
	if nod == null:
		print("lageprov: våningen har ingen fackla (prova en annan bana eller våning)")
		get_tree().quit()
		return
	var centrum := Vector3(nod.pos.x + 0.5, 0, nod.pos.y + 0.5)
	var avstånd := await _gå_till_och_vänd(nod.pos)
	for i in 45:                       # lågan behöver tid att byggas upp (se fackelprov)
		await get_tree().process_frame
	var lågor: Array = []
	for c in world.find_children("*", "GPUParticles3D", true, false):
		if c.name == "låga" and c.global_position.distance_to(centrum) < 1.5:
			lågor.append(c)
	var ljus := 0.0
	for l in _lågor:
		if l.global_position.distance_to(centrum) < 1.5:
			ljus = l.light_energy
	# Ljuset skrivs ut i SAMMA rad som bilderna: "mindre låga, samma ljus" är två siffror, och utan
	# den här raden går det inte att se att ljuset stod still mellan bilderna. (Hela talet, inte
	# avrundat: `var ljus := 0` blir en INT, och då skriver raden 1,00 för en energi på 1,58.)
	print("[lageprov] fackla %s, %d steg ifrån: %d lågor, ljusenergi %.2f, räckvidd %.1f m"
		% [str(nod.pos), avstånd, lågor.size(), ljus, LAGA_RACKVIDD])
	if lågor.is_empty():
		print("lageprov: hittade ingen låga vid facklan")
		get_tree().quit()
		return
	# Två rattar, en körning: lågans RUTA (storleken) och GLÖDEN (HDR-emissionen). Ratten är
	# mekanismen — allt annat står still — och sista raden är samma inställning som den nya, så
	# körningens eget brus syns i samma tabell (elden fladdrar mellan två bilder).
	await _lageprov_bild(lågor, LÅGA_GAMMAL, LÅGA_GAMMAL_GLÖD, "01-gammal")
	await _lageprov_bild(lågor, Fx.LÅGA_STORLEK, Fx.LÅGA_GLÖD, "02-ny")
	await _lageprov_bild(lågor, Fx.LÅGA_STORLEK, 4.0, "03-ny-glöd-4.0")
	await _lageprov_bild(lågor, Fx.LÅGA_STORLEK, 1.0, "04-ny-glöd-1.0")
	await _lageprov_bild(lågor, Fx.LÅGA_STORLEK, 0.6, "05-ny-glöd-0.6")
	await _lageprov_bild(lågor, Fx.LÅGA_STORLEK, Fx.LÅGA_GLÖD, "06-ny-igen")
	get_tree().quit()


## En bild med lågrutan `storlek` och glöden `glöd`. DE RATTARNA är mekanismen: allt annat (liv, färg,
## antal partiklar) står still, så skillnaden i bilden kommer från lågans yta och emission och inget
## annat. Facklans LJUS (omni-ljuset) rörs inte — det är hela poängen: mindre låga, samma ljus.
func _lageprov_bild(lågor: Array, storlek: Vector2, glöd: float, namn: String) -> void:
	for c in lågor:
		var q: QuadMesh = (c as GPUParticles3D).draw_pass_1
		q.size = storlek
		var m: StandardMaterial3D = q.material
		if m.emission_enabled:
			m.emission_energy_multiplier = glöd
	for i in 4:
		await get_tree().process_frame
	# Lågan lever LÅGA_LIV sekunder: en bild tagen direkt efter bytet visar bara de partiklar som
	# råkade finnas, inte den nya storleken.
	await get_tree().create_timer(Fx.LÅGA_LIV * 2.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var path := "user://shots/lageprov-%s.png" % namn
	_spara_bild(path)
	print("[lageprov] lågruta %s -> %s" % [str(storlek), ProjectSettings.globalize_path(path)])


## GLANSPROVET: `light_specular` (och metallen på en rekvisit) som A/B i EN körning, samma kamera, Forward+.
##
## Frågan: kan ljuset i spelet ge en HÖGDAGER alls? `light_specular = 0,0` på lyktan och facklorna
## (M26) tog bort speglingen från VARJE yta, och då kan varken vattnet (råhet 0,05), benet (0,45-0,60),
## träet (0,72) eller järnet glänsa hur låg råhet materialet än har — en glans med ljuset av är ingen
## glans. Provet rattar DET SOM FAKTISKT LYSTER (`_glans_styrka`, samma väg som världsbygget) och
## metallen på DET MATERIAL SOM FAKTISKT RITAS (`_järndelar` / pölens shader), och tar alla bilderna i
## samma process: ljuset skiljer mellan två körningar, så en skillnad mellan två processer går inte att
## skilja från att bygget självt skiljer sig.
##
##   `-- glansprov`       facklan i bild: lyktan, fackelljuset och järnplattan (rekvisiten)
##   `-- glansprov=pöl`   pölen i bild: vattnets shader (råhet 0,05 + krusningen)
##
##   01 glans 0,0  yta -1 (GGX, före)            läget FÖRE — ingen högdager möjlig
##   02 glans 1,0  yta -1 (GGX, före)            glansen på medan ytan står kvar på Godots standard
##   03 glans 1,0  yta -2 (ALLA av)              FLIT-BORT: hur mycket av lyftet är ytorna?
##   04 glans LJUS_GLANS  YTGLANS_TRÖSKEL 0,80  spelets värde: stenen utan spegling, mossen kvar
##   05 glans 1,0  tröskel 0,60                  ratten en bit ner (mer yta behåller sin spegling)
##   06 glans 1,0  tröskel 0,80  metall 0,7      järnet metalliskt (råhet 0,55: matt järn)
##   07 glans 1,0  tröskel 0,80  metall 0,7  råhet 0,25 (polerat järn — glänser det då?)
##   08 glans 0,0  yta -1                        = 01: BRUSGOLVET (fladdrande eld, temporal GI)
##
## |01−02| är glansen med ytan orörd, |02−03| hur mycket av lyftet som är YTORNA, |02−04| vad tröskeln
## gör med den, |04−06| och |04−07| rekvisitens metall vid två råheter, och |01−08| vad körningens eget
## brus kan åstadkomma — ett svar i brusgolvets storlek betyder "ingen skillnad".
func _glansprov() -> void:
	var mål := Vector2i.ZERO
	var pöl := _glansprov_pose == "pöl"
	if pöl:
		var mi := _pölnod()
		if mi == null:
			print("glansprov: våningen har ingen pöl (prova en annan bana eller våning)")
			get_tree().quit()
			return
		var t := mi.multimesh.get_instance_transform(0).origin
		mål = Vector2i(floori(t.x), floori(t.z))
	else:
		var nod: Dungeon.FloorNode = null
		for n in run.explore.floor_ref.nodes:
			if n.kind == "torch":
				nod = n
				break
		if nod == null:
			print("glansprov: våningen har ingen fackla (prova en annan bana eller våning)")
			get_tree().quit()
			return
		mål = nod.pos
	var avstånd := await _gå_till_och_vänd(mål)
	for i in 45:                       # elden byggs upp, och dimman/GI:n hinner sätta sig
		await get_tree().process_frame
	var järn := _järndelar()
	var vatten := _pöl_material()
	# Vattnets EGNA värde läses ur materialet, inte ur en kopia i provet: provet ska mäta spelets
	# vatten, och en siffra som står på två ställen driver isär.
	var vatten_metall := -1.0
	if vatten != null:
		vatten_metall = float(vatten.get_shader_parameter("glans"))
	# Vad provet tog i: en override som inte når något ger samma bild två gånger och ser ut som
	# "glansen gör ingen skillnad". Raden är beviset för att den nådde fram.
	var ytor := _ytmaterial().size()
	print("[glansprov] %s vid %s, %d steg ifrån: glans %.2f på lyktan och %d fackelljus, %d ytmaterial, %d järndelar, vatten %s (glans %.2f)"
		% ["pöl" if pöl else "fackla", str(mål), avstånd, _ljus_glans, _lågor.size(), ytor, järn.size(),
			"%d plattor" % _pölnod().multimesh.instance_count if vatten != null else "saknas",
			vatten_metall])
	if ytor == 0 and järn.is_empty() and vatten == null:
		print("glansprov: hittade inga ytor, ingen rekvisit och inget vatten att mäta på")
		get_tree().quit()
		return
	# Metallen höjs på den rekvisit som SYNS i bilden: järndelarna i fackel-läget och vattnets glans i
	# pöl-läget. Träet och benet lämnas orörda — de är halvblanka, inte metalliska.
	var v_höjd := 0.7 if pöl else vatten_metall
	var svep := [
		{"namn": "01-fore-glans-0", "glans": 0.0, "yta": -1.0},
		{"namn": "02-glans-1-yta-ggx", "glans": 1.0, "yta": -1.0},
		{"namn": "03-yta-av", "glans": 1.0, "yta": -2.0},
		# Rattarna är nu BLÖTA ANDELEN (M59), inte råhetens medelvärde: 0,03 är spelets eget värde,
		# 0,0 ger spegling överallt (flit-bort: var kom lyftet ifrån?) och 1,0 stänger av den helt.
		{"namn": "04-yta-blot-0.03-spelet", "glans": LJUS_GLANS, "yta": GLANS_BLÖT_ANDEL},
		{"namn": "05-yta-blot-0.0-allt", "glans": 1.0, "yta": 0.0},
		{"namn": "06-metall-0.7", "glans": 1.0, "yta": GLANS_BLÖT_ANDEL,
			"metall": 0.7 if not pöl else 0.0, "vatten": v_höjd},
		{"namn": "07-metall-0.7-rakhet-0.25", "glans": 1.0, "yta": GLANS_BLÖT_ANDEL,
			"metall": 0.7 if not pöl else 0.0, "råhet": 0.25, "vatten": v_höjd},
		{"namn": "08-fore-igen", "glans": 0.0, "yta": -1.0},
	]
	for post in svep:
		await _glansprov_bild(post, järn, vatten)
	get_tree().quit()


## En bild av glansprovet: posten (`glans` på ljuset, `yta` enligt `_yta_glans_svep`, `metall` och
## `råhet` på järndelarna, `vatten` = pölens glans) sätts, och bildens egen ljusfördelning skrivs ut med
## den — utan FÖRDELNINGEN går det inte att skilja "högdagern blev starkare" från "hela rutan lyftes".
func _glansprov_bild(post: Dictionary, järn: Array, vatten: ShaderMaterial) -> void:
	_glans_styrka(float(post.get("glans", 0.0)))
	_yta_glans_svep(float(post.get("yta", -1.0)))
	for m in järn:
		m.metallic = float(post.get("metall", 0.0))
		m.roughness = float(post.get("råhet", JARN_RAHET))
	if vatten != null and post.has("vatten"):
		vatten.set_shader_parameter("glans", float(post["vatten"]))
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var namn := str(post.get("namn", "bild"))
	var path := "user://shots/glansprov-%s-%s.png" % ["pöl" if _glansprov_pose == "pöl" else "fackla", namn]
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("ingen bild kunde läsas (%s): kör med DISPLAY=:99" % path)
		get_tree().quit(2)
		return
	img.save_png(path)
	var st := _bild_statistik(img)
	print("[glansprov] %s: glans %.1f yta %+.2f metall %.2f råhet %.2f (vatten %.2f) -> %s (medel %.4f, p50 %.4f, p99 %.4f, mörkt %d %%, högdagrar %d px)"
		% [namn, float(post.get("glans", 0.0)), float(post.get("yta", -1.0)),
			float(post.get("metall", 0.0)), float(post.get("råhet", JARN_RAHET)),
			float(post.get("vatten", -1.0)), ProjectSettings.globalize_path(path),
			st["medel"], st["p50"], st["p99"], st["mörkt"], st["högdagrar"]])



## Startar droppen vid ett ställe (`nodprov=dropp`). Returnerar false om inget ställe ligger där.
func _starta_droppe_nära(pos: Vector3) -> bool:
	for d in _droppar:
		var p: GPUParticles3D = d["nod"]
		if not is_instance_valid(p):
			continue
		if p.global_position.distance_to(pos) < 0.4:
			p.restart()
			return true
	return false


## Gå till noden, ta två steg tillbaka och vänd dig mot den. Returnerar avståndet i rutnätssteg.
func _gå_till_och_vänd(mål: Vector2i) -> int:
	var väg := []
	var varv := 0
	while run.explore.pos != mål and varv < 200:
		varv += 1
		var förr := run.explore.pos
		if run.explore.step_toward(mål) != "":
			print("nodprov: fast på väg till noden")
			break
		väg.append(förr)
		_sfx("step")
		_animate_cam()
		await get_tree().process_frame
	var steg := 0
	while not väg.is_empty() and steg < 2:
		if run.explore.step_toward(väg.pop_back()) != "":
			break
		steg += 1
		_sfx("step")
		_animate_cam()
		await get_tree().process_frame
	# Vänd mot noden: riktningen i rutnätet översatt till de fyra håll kameran kan stå i
	# (0 = norr = -y, 1 = öster, 2 = söder, 3 = väster — samma tabell som Explore.STEP).
	run.explore.face(mål)
	_snap_cam()
	return absi(mål.x - run.explore.pos.x) + absi(mål.y - run.explore.pos.y)


## Kortvalet fotograferat, för uppgraderingen måste SYNAS med sitt recept: ett val som konsumerar
## två kort utan att säga det är en fälla (M12). Provet går spelets väg — xp in, samma `_check_level()`
## som `finish_fight()` kallar, `_refresh()` ritar panelen — och svarar sedan med samma `_on_draft_pick()`
## som tangenten och klicket använder, så siffrorna är spelets och inte provets.
func _demo_draft() -> void:
	run.xp = Progress.xp_total(run.level + 1)     # exakt en nivå: samma tröskel som spelet räknar mot
	run._check_level()
	_refresh()
	_show_draft()                                # samma anrop spelet gör när valet kommer upp
	await get_tree().process_frame
	var val: Array = run.pending_draft()
	var uppgraderingar := 0
	var evo_index := -1
	for i in val.size():
		if Evolution.is_evolution(db[val[i]]):
			uppgraderingar += 1
			evo_index = i
	print("kortvalsprov: %d val, %d uppgradering: %s" % [val.size(), uppgraderingar, str(val)])
	print("kortvalsprov: raden kräver %.0f px, panelen är %.0f px" % [draft_box.custom_minimum_size.x,
		draft_panel.size.x])
	print("kortvalsprov: texten i valet — %s" % draft_label.text.replace("\n", " | "))
	print("kortvalsprov: panelen syns: %s" % ("ja" if draft_panel.visible else "nej"))
	# M78: konstens raster. Skalan är golvad till ett heltal, men ligger korten på DELADE skärmpixlar
	# blir blocken ändå 1 och 2 px om varandra — det syns bara i siffrorna, inte i koden.
	for v in draft_box.get_children():
		var ik: Control = null
		for b in v.find_children("*", "Control", true, false):
			if b is CardView.Ikon:
				ik = b
				break
		print("kortvalsprov: %s global %s %.0fx%.0f  ikon %s %.0fx%.0f steg %d" % [
			str(v.name), str(v.global_position), v.size.x, v.size.y,
			str(ik.global_position) if ik != null else "saknas",
			ik.size.x if ik != null else 0.0, ik.size.y if ik != null else 0.0,
			(ik as CardView.Ikon).steg() if ik != null else -1])
	# Vänta in ritningen innan bilden: de första bildrutorna går åt till att bygga shaders, och en bild
	# tagen direkt efter start blev helsvart (mätt: 2,7 kB svart PNG mot 40+ kB när vyn hunnit ritas).
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_spara_bild("user://shots/kortval.png")
	print("kortvalsprov: bild i %s" % ProjectSettings.globalize_path("user://shots/kortval.png"))
	# KLICKET. Tangenten har varit vägen hela tiden (1-4), men Alex: *"det går inte att välja ett kort
	# där, det går inte att klicka på dem"*. Provet flyttar pekaren till varje korts mitt, frågar vyn
	# VILKEN kontroll som ligger under pekaren (`gui_get_hovered_control`) och klickar sedan på det
	# sista kortets mitt — samma väg som en riktig mus, inte samma funktion som tangenten.
	# Korten ligger i FÖNSTRETS yta (`_runt`): pekarens ruta ÄR kortets ruta. Förut låg de i
	# SubViewporten och måste räknas om till fönstret — första försöket warp:ade till vyns koordinater
	# (108,210 i ett 1280x720-fönster) och mätte därför ingenting.
	var hover := []
	for barn in draft_box.get_children():
		if not (barn is CardView):
			continue
		var kort: CardView = (barn as CardView)
		var mitten: Vector2 = kort.get_global_rect().get_center()
		Input.warp_mouse(mitten)
		await get_tree().process_frame
		await get_tree().process_frame
		# Frågan ställs till FÖNSTRET: valets kort finns inte i vyn längre.
		var över: Control = get_viewport().gui_get_hovered_control()
		hover.append("kort %d fönstret %.0f,%.0f: %s" % [kort.index, mitten.x, mitten.y,
			"inget" if över == null else "%s %s filter=%d" % [över.name, över.get_class(), över.mouse_filter]])
	for rad in hover:
		print("kortvalsprov: pekaren över — %s" % rad)
	var sista: CardView = null
	for barn in draft_box.get_children():
		if barn is CardView:
			sista = (barn as CardView)
	if sista != null:
		var mitten: Vector2 = sista.get_global_rect().get_center()   # valets kort ligger i fönstret
		var ned := InputEventMouseButton.new()
		ned.button_index = MOUSE_BUTTON_LEFT
		ned.pressed = true
		ned.position = mitten
		ned.global_position = mitten
		# Fönstret, inte vyn: klicket ska gå SAMMA väg som en riktig mus (via SubViewportContainer).
		get_window().push_input(ned)
		await get_tree().process_frame
		await get_tree().process_frame
		var lyft := InputEventMouseButton.new()
		lyft.button_index = MOUSE_BUTTON_LEFT
		lyft.position = mitten
		lyft.global_position = mitten
		get_window().push_input(lyft)
		await get_tree().process_frame
		print("kortvalsprov: klick på kort %d i fönstret %.0f,%.0f — valet kvar efter: %d (var %d)"
			% [sista.index, mitten.x, mitten.y, run.pending_draft().size(), val.size()])
	# EFTERBILDEN (Alex: "kortet flyttar på sig till vänster, och täcker över det som låg där innan").
	# Här mäts vad som ligger kvar: varje kvarvarande kortvy med sin ruta och sin alfa, plus högens mitt
	# — flyger ett kort till högen ska det ha alfa 0 (eller vara borta), inte ligga kvar överst.
	await get_tree().create_timer(0.6).timeout
	print("kortvalsprov: efter valet — valet syns: %s, kort kvar i handen: %d"
		% ["ja" if draft_panel.visible else "nej", hand_views.size()])
	for v in hand_views:
		if is_instance_valid(v):
			print("kortvalsprov:   kvar i handen: kort %d @ %s alfa %.2f syns %s"
				% [v.index, str(v.position.round()), v.modulate.a, "ja" if v.visible else "nej"])
	if hog_använd != null:
		print("kortvalsprov:   använda-högen @ %s, %d kort, syns %s"
			% [str(hog_använd.position.round()), hog_använd.antal, "ja" if hog_använd.visible else "nej"])
	_spara_bild("user://shots/kortval-efter.png")
	if evo_index >= 0:
		var kort: Cards.Card = db[val[evo_index]]
		var delar: Array = Evolution.for_card(kort.id).get("parts", [])
		var före := run.deck.size()
		var del_fore := []
		for d in delar:
			del_fore.append(Evolution.count_in(run.deck, str(d)))
		_on_draft_pick(evo_index)
		await get_tree().process_frame
		var del_efter := []
		for d in delar:
			del_efter.append(Evolution.count_in(run.deck, str(d)))
		print("kortvalsprov: %s — leken %d → %d kort, delarna %s → %s, %s i leken: %d"
			% [kort.id, före, run.deck.size(), str(del_fore), str(del_efter), kort.id,
				Evolution.count_in(run.deck, kort.id)])
		print("kortvalsprov: valet kvar efter: %d (%s)"
			% [run.pending_draft().size(), str(run.pending_draft())])
	get_tree().quit()

## Klickar på spaden genom att skicka in ett RIKTIGT musklick i samma funktion som spelarens klick
## går genom (`_vy_klick`). Punkten räknas ur spadens projicerade läge och skalas upp till fönstret
## precis som `_vy_klick` skalas ned — provet biter därför också på omräkningen: är den fel hamnar
## klicket utanför spaden.
func _klick_på_spaden() -> bool:
	if _spade_sprite == null or not is_instance_valid(_spade_sprite) or cam == null or _vy_korg == null:
		return false
	var s := _spade_på_bild()
	if s == Vector2.ZERO:
		return false
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	m.position = s          # samma rum som ett riktigt klick kommer in i: vyns px (mätt)
	_vy_klick(m)
	return true

## GRÄVPROVET (M44): spaden KLICKAS, och grävningen mäts steg för steg.
##   1. Klick medan bossen lever: nekas, och våningen står kvar.
##   2. Bossen besegras (samma kod som striden använder).
##   3. Klick: kamerans y och slöjans alfa samplas var 40:e ms, och våningen byts mitt i mörkret.
## Kör: godot --path game -- grävprov
func _gräv_prov() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var boss: Dungeon.FloorNode = null
	var spade: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == "boss":
			boss = n
		elif n.kind == "shovel":
			spade = n
	if boss == null or spade == null:
		print("[grävprov] våningen saknar boss eller spade — inget att mäta")
		get_tree().quit(2)
		return
	# Spelaren ställs på rutan BREDVID spaden och vänder blicken mot den. Det är så man ser spaden:
	# står man PÅ dess ruta ligger den under fötterna och går inte att projicera alls (mätt).
	var grann: Vector2i = spade.pos + Vector2i(0, 1)
	if not run.explore.floor_ref.is_floor_at(grann):
		grann = spade.pos + Vector2i(-1, 0)
	run.explore.pos = grann
	run.explore.face(spade.pos)
	_snap_cam()
	_build_world()                    # kameran och spaden byggs om: spriten måste finnas för klicket
	await get_tree().process_frame
	print("[grävprov] står på %s och tittar på spaden på %s (bossen på samma ruta: %s)" % [
		str(run.explore.pos), str(spade.pos), "ja" if boss.pos == spade.pos else "nej"])
	await get_tree().create_timer(0.4).timeout   # kamerans projektion måste vara klar först
	print("[grävprov] spaden på bild: vyn %s, kameran %.2f över golvet, ledtråd: \"%s\"" % [
		str(_spade_på_bild()), cam.position.y, hint_label.text])
	# 1. FÖRTID: bossen lever. Klicket ska nekas och våningen stå kvar.
	var våning_före := run.floor_index
	var klickade := _klick_på_spaden()
	await get_tree().process_frame
	print("[grävprov]   klick med bossen levande: klickade %s, våning %d -> %d, spaden kvar %s" % [
		"ja" if klickade else "nej", våning_före, run.floor_index,
		"ja" if not spade.cleared else "nej"])
	_spara_bild("user://shots/grav-00-bossen-lever.png")
	# 2. Bossen besegras: samma väg som striden tar, utan att spela den för hand.
	# enter_node rensar noden OCH bygger striden — samma väg som striden tar. Att bygga striden för
	# hand lämnade bossen OKLARAD, och då nekades klicket av rätt skäl (mätt i första körningen).
	var c: Combat = run.enter_node(boss)
	if c == null:
		print("[grävprov] bossen gick inte att bygga")
		get_tree().quit(3)
		return
	c.hp = 5000.0
	c.max_hp = 5000.0
	var turer := 0
	while not c.over() and turer < 200:
		turer += 1
		c.auto_play()
		if not c.over():
			c.end_turn()
	run.finish_fight(boss, c)
	_after_state_change()
	await get_tree().process_frame
	var bossval: Array = run.pending_draft()
	print("[grävprov] bossen besegrad efter %d turer: bossens byte %s, spaden redo %s, ledtråd: \"%s\"" % [
		turer, str(bossval), "ja" if _spade_redo() else "nej", hint_label.text])
	_spara_bild("user://shots/grav-01-bossens-byte.png")
	# Bossens byte svaras på först (M45): valet blockerar rörelsen, precis som för spelaren.
	for i in 12:
		if not _draft_pending():
			break
		_on_draft_pick(0)
		await get_tree().process_frame
	print("[grävprov] efter bytet: redo att gräva %s, ledtråd: \"%s\"" % [
		"ja" if _spade_redo() else "nej", hint_label.text])
	_spara_bild("user://shots/grav-01b-klar-att-grava.png")
	# Kameran måste hinna byggas klart: unproject_position svarar (0,0) så länge projektionen inte
	# är satt, och då hamnar klicket i hörnet (mätt: "Condition p.d == 0").
	await get_tree().create_timer(0.4).timeout
	print("[grävprov] kameran: i trädet %s, viewport %s, aktuell %s, projektion klar %s" % [
		"ja" if cam.is_inside_tree() else "nej", str(cam.get_viewport()), "ja" if cam.current else "nej",
		"ja" if cam.get_camera_projection() != Projection() else "nej"])
	# 2b. DEN RIKTIGA MUSVÄGEN. Provet nedan anropar `_vy_klick` RAKT IN — det mäter varken
	# hit-testningen, korgens koordinater eller om spaden alls syns på skärmen. Alex: *"Det går inte
	# att klicka på spaden. Går man för nära försvinner den."* Här skickas ett RIKTIGT musklick in i
	# fönstret (samma väg som handen tar), från rutan intill OCH från rutan spaden ligger på, och
	# varje steg skrivs ut: syns spaden i kameran, var projiceras den, vilken kontroll får klicket,
	# och bytte våningen?
	var grann2: Vector2i = run.explore.pos
	for i in 2:
		if i == 0:
			# DEN RAPPORTERADE VÄGEN FÖRST: Alex går fram till spaden, och på hennes ruta försvinner
			# den ur kameran ("går man för nära försvinner den"). Det är den här körningen som ska
			# bevisa klicket, så den kommer först — den gräver och provet är klart.
			run.explore.pos = spade.pos
		run.explore.face(grann2)
		_snap_cam()
		_build_world()
		_refresh()                  # ledtråden byggs om: den ska säga vad som gäller DÄR spelaren står
		await get_tree().create_timer(0.4).timeout
		var s := _spade_på_bild()
		var syns: bool = _spade_sprite != null and is_instance_valid(_spade_sprite) \
			and _spade_sprite.visible and cam.is_position_in_frustum(_spade_sprite.global_position)
		print("[grävprov] %s: spelaren på %s, spaden i kameran %s, på bild %s, redo %s" % [
			"PÅ rutan" if i == 0 else "intill", str(run.explore.pos), "ja" if syns else "nej",
			str(s), "ja" if _spade_redo() else "nej"])
		_spara_bild("user://shots/grav-05-%s.png" % ("pa-rutan" if i == 0 else "intill"))
		var mitten := _vy.get_screen_transform() * s
		Input.warp_mouse(mitten)
		await get_tree().process_frame
		var hov: Control = get_viewport().gui_get_hovered_control()
		var ned := InputEventMouseButton.new()
		ned.button_index = MOUSE_BUTTON_LEFT
		ned.pressed = true
		ned.position = mitten
		ned.global_position = mitten
		get_window().push_input(ned)
		await get_tree().process_frame
		var lyft := InputEventMouseButton.new()
		lyft.button_index = MOUSE_BUTTON_LEFT
		lyft.position = mitten
		lyft.global_position = mitten
		get_window().push_input(lyft)
		await get_tree().process_frame
		print("[grävprov]   musklick i fönstret %.0f,%.0f: översta kontrollen %s, gräver %s" % [
			mitten.x, mitten.y, hov.name if hov != null else "ingen", "ja" if _gräver else "nej"])
		await get_tree().create_timer(1.6).timeout
		if run.floor_index > 0:
			print("[grävprov]   våningen byttes av det riktiga klicket — klart")
			get_tree().quit()
			return
		if i == 0:
			# Ett riktigt musklick som INTE gräver är felet Alex rapporterade: provet ska falla.
			print("[grävprov] FEL: ett riktigt musklick på spaden grävde inte (våning %d)" % (run.floor_index + 1))
			get_tree().quit(4)
			return
		# Rutan intill: där SYNS spaden, så träffen ska vara radien mot den projicerade punkten.
		print("[grävprov]   (rutan intill mätt som träffläge: avståndet ska vara inom radien)")
	# 3. Klicket, och mätningen av rörelsen.
	var bas := cam.position.y
	print("[grävprov] — grävningen (GRÄV_DJUP %.2f m, GRÄV_TID %.2f s) —" % [GRÄV_DJUP, GRÄV_TID])
	_klick_på_spaden()                # koroutinen startar; provet samplar medan den rör sig
	for i in 24:
		await get_tree().create_timer(0.04).timeout
		print("[grävprov]   +%.2f s: kamera y %.2f, slöja %.2f, våning %d" % [(i + 1) * 0.04,
			cam.position.y if cam != null else 0.0,
			gräv_slöja.color.a if gräv_slöja != null else -1.0, run.floor_index + 1])
		if i == 6:
			_spara_bild("user://shots/grav-02-mitt-i-morkret.png")
		if i == 15:
			_spara_bild("user://shots/grav-03-pa-vag-upp.png")
	await get_tree().create_timer(0.2).timeout
	print("[grävprov] efter: våning %d, kamera y %.2f, slöja %.2f, nya våningens spade orörd %s" % [
		run.floor_index + 1, cam.position.y, gräv_slöja.color.a,
		"ja" if _spade_nod != null and not _spade_nod.cleared else "nej"])
	_spara_bild("user://shots/grav-04-framme.png")
	print("[grävprov] bilder i %s" % ProjectSettings.globalize_path("user://shots"))
	get_tree().quit()

## Kistprovet: gå till våningens kista och in i den med SAMMA kod som tangentbordet, och skriv ut hp
## och guld före och efter. Provet i test_run mäter kärnan headless; det här mäter vägen genom UI:t
## (händelseloggen, ljudet, siffrorna i HUD:en) — annars är "kistan funkar" bara något jag tror.
func _demo_chest() -> void:
	var kista: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == "chest" and not n.cleared:
			kista = n
			break
	if kista == null:
		print("kistprov: våningen har ingen kista (prova en annan vaning)")
		get_tree().quit()
		return
	var varv := 0
	while run.explore.pos != kista.pos and varv < 200:
		varv += 1
		var err := run.explore.step_toward(kista.pos)
		if err != "":
			print("kistprov: fast — %s" % err)
			break
		_sfx("step")
		_animate_cam()
		await get_tree().process_frame
	print("kistprov: står på %s, kistan på %s" % [str(run.explore.pos), str(kista.pos)])
	var hp_före := run.hp
	var guld_före := run.gold
	_enter_node_here()
	_refresh()
	# Bilden tas MEDAN stunden är som starkast: ekrarna når full längd vid 0,48 av stundens 1,7 s och
	# gnistorna är som längst ut en bit in i utbrottet. En bildruta efter anropet hade visat kortet
	# kant in (samma fälla som M10: siffran fanns inte i bilden därför att draget inte hunnit lösas).
	await get_tree().create_timer(RewardFx.LÄNGD * 0.55).timeout
	print("kistprov: stundens fas %s, kortets bredd %.2f" % [
		reward_fx.fas(), float(reward_fx.stil()["bredd"]) if reward_fx != null else 0.0])
	print("kistprov: hp %.0f → %.0f · guld %d → %d · avklarad: %s"
		% [hp_före, run.hp, guld_före, run.gold, "ja" if kista.cleared else "nej"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_spara_bild("user://shots/kista.png")
	print("kistprov: bild i %s" % ProjectSettings.globalize_path("user://shots/kista.png"))
	kista = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == "torch" and not n.cleared:
			kista = n
			break
	if kista == null:
		print("kistprov: våningen har ingen fackla")
		get_tree().quit()
		return
	# Skadad spelare: facklan ska bara vara värd en omväg när man behöver den.
	run.hp = run.max_hp * 0.3
	varv = 0
	while run.explore.pos != kista.pos and varv < 200:
		varv += 1
		var err2 := run.explore.step_toward(kista.pos)
		if err2 != "":
			print("kistprov: fast på väg till facklan — %s" % err2)
			break
		_sfx("step")
		_animate_cam()
		await get_tree().process_frame
	hp_före = run.hp
	_enter_node_here()
	_refresh()
	await get_tree().process_frame
	print("kistprov: fackla — hp %.0f → %.0f av %.0f · avklarad: %s"
		% [hp_före, run.hp, run.max_hp, "ja" if kista.cleared else "nej"])
	_spara_bild("user://shots/fackla.png")
	print("kistprov: bild i %s" % ProjectSettings.globalize_path("user://shots/fackla.png"))
	get_tree().quit()

## NÄRPROVET (`-- kistnara`): kistan på nära håll — de två sakerna Alex såg, mätta i EN körning.
##
##   1. "Kistor försvinner när man kommer nära, det får de inte göra." Kameran flyttas i 0,1 m-steg
##      från rutan intill in i kistans egen ruta, och vid varje steg mäts tre saker: kistans DJUP
##      framåt (mot kamerans närplan — en skylt som står på kamerans egen ruta har djupet 0 och
##      klipps bort av närplanet), dess RUTA på skärmen i vyns px, och hur många bildpunkter i den
##      rutan som FAKTISKT ändras när kistans noder göms och visas igen. Den sista siffran är
##      beviset — en projektion kan visa något som renderaren klipper bort, men en bild som ändras
##      när noden göms är ett föremål som ritas. A/B-paret tas med trädet PAUSAT, annars räknas
##      eldens fladder som kistpixlar.
##   2. "…och inte snurra när man själv snurrar." Kameran ställs 1,5 m från kistan och tittar på den
##      från fyra håll (0°, 90°, 180°, 270°). En skylt som vänder sig mot kameran visar SAMMA bredd
##      från alla fyra hållen — den har ingen egen orientering, den följer spelaren. Ett föremål har
##      sin egen orientering i världen: kistans ruta i världen står still, medan bredden på skärmen
##      växlar mellan långsidan och kortsidan.
##   3. Till sist GÅR provet vägen spelaren går (`_step_forward`, samma anrop som W-tangenten) och
##      skriver ut vid vilket avstånd kistan blev avklarad. Öppnades den på håll försvinner den
##      medan den ännu står i bild, och det är den siffran hela önskemålet handlar om.
##
## Provet mäter samma sak för en skylt-sprite (så som kistan såg ut före M32) som för byggd
## geometri: `_kista_punkter` läser hörnen ur det som RITAS, inte ur en kopia av räkningen. Bilder i
## `user://shots/nara-*.png` och `user://shots/kista-vinkel-*.png`, siffrorna i samma körning.
func _kistnara_prov() -> void:
	var kista: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if n.kind == "chest":
			kista = n
			break
	if kista == null:
		print("kistnara: våningen har ingen kista")
		get_tree().quit()
		return
	var centrum := Vector3(kista.pos.x + 0.5, 0.0, kista.pos.y + 0.5)
	var fran := _granne(kista.pos)
	if fran == Vector2i(-1, -1):
		print("kistnara: kistan %s har ingen granne att komma ifrån" % str(kista.pos))
		get_tree().quit()
		return
	# Provet ställer kameran SJÄLV (och dödar tweenen): det mäter kistans siffror vid ett givet
	# avstånd, inte kamerans väg dit.
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	var riktning := Vector2(kista.pos - fran)          # från grannrutan in i kistan
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var noder := _kista_noder(kista)
	print("[kistnara] kistan på %s, in från %s: %d noder (%s), närplan %.2f m, öga %.2f m"
		% [str(kista.pos), str(fran), noder.size(), _kista_slag(noder), cam.near, _cam_pos().y])
	if noder.is_empty():
		print("[kistnara] kistan finns inte i världen (noden är avklarad och ritas inte) — inget att mäta")
		get_tree().quit()
		return

	print("")
	print("— A: vägen fram, 0,1 m i taget (kameran, samma bildruta) —")
	var brus := -1
	for i in 11:
		var d := 1.0 - 0.1 * float(i)
		cam.position = Vector3(centrum.x - riktning.x * d, 0.5, centrum.z - riktning.y * d)
		cam.rotation.y = atan2(-riktning.x, -riktning.y)
		cam.force_update_transform()
		await get_tree().process_frame
		var m := _kista_skärm(noder)
		# Rutan för det som ritas, och den faktiska skillnaden i bild. Bilden tas bara när något
		# alls syns: en helt bortklippt kista har inga pixlar att räkna (och det är svaret).
		var ruta: Rect2 = m["ruta"]
		var pixlar := await _kista_pixlar(noder, ruta)
		if brus < 0:
			brus = await _kista_brus(noder, ruta)
		print("  %4.1f m in | djup %5.2f m (närplan %.2f) | %s | %s | %s" % [
			d, float(m["djup"]), cam.near, _kista_text(m), _kista_pixtext(pixlar),
			"SYNS" if m["i_bild"] and int(pixlar["px"]) > 0 else "SYNS INTE"])
		if i == 0 or i == 5 or i == 8 or i == 10:
			_spara_bild("user://shots/nara-%.1f.png" % d)
	print("  brusgolv: %d px ändras i samma ruta när kistan är GÖMD i båda bilderna (facklorna står stilla med trädet pausat)" % brus)
	print("  kistans ruta i världen: %s" % str(_kista_världsruta(noder)))

	print("")
	print("— B: samma kista från fyra håll, 1,50 m —")
	var vinklar := [0.0, 90.0, 180.0, 270.0]
	var bredder := []
	for vinkel in vinklar:
		var u := deg_to_rad(vinkel)
		var av: Vector3 = Vector3(sin(u), 0.0, cos(u)) * 1.5
		cam.position = Vector3(centrum.x + av.x, 0.5, centrum.z + av.z)
		# Titta IN mot kistan: står kameran på +z ser den mot -z, alltså yaw 0 (se `_i_bild` i
		# test_strid — samma räkning som spelet använder för att rita en siffra över en fiende).
		cam.rotation.y = u
		cam.force_update_transform()
		await get_tree().process_frame
		var m := _kista_skärm(noder)
		var r: Rect2 = m["ruta"]
		bredder.append(r.size.x)
		print("  kamera-yaw %3.0f° | kistans ruta på skärmen %5.1f x %5.1f px | %s | världsruta %s" % [
			vinkel, r.size.x, r.size.y, _kista_text(m), str(_kista_världsruta(noder))])
		_spara_bild("user://shots/kista-vinkel-%03d.png" % int(vinkel))
	var minst: float = bredder[0]
	var störst: float = bredder[0]
	for b in bredder:
		minst = minf(minst, float(b))
		störst = maxf(störst, float(b))
	print("  bredden växlar %.0f-%.0f px mellan hållen (förhållande %.2f). En skylt som vänder sig med kameran har förhållandet 1,00 — den visar samma bild från varje håll och \"snurrar\" med spelaren."
		% [minst, störst, störst / maxf(minst, 0.01)])

	print("")
	print("— C: spelarens egen väg in (W-tangenten, ett steg i taget) —")
	var varv := 0
	while run.explore.pos != kista.pos and varv < 60:
		varv += 1
		var före: Vector2i = run.explore.pos
		# Vägen spelaren går: sväng mot målet (W/A/D) och stig in. `_enter_node_here` är SAMMA anrop
		# som W-tangenten gör efter varje steg — det är där en kista öppnas av sig själv på håll.
		var err := run.explore.step_toward(kista.pos)
		if err != "":
			print("  steg %d: fast på %s (%s)" % [varv, str(run.explore.pos), err])
			break
		_animate_cam()
		await get_tree().process_frame
		_enter_node_here()
		await get_tree().process_frame
		var avstånd := absi(kista.pos.x - run.explore.pos.x) + absi(kista.pos.y - run.explore.pos.y)
		print("  steg %d: %s → %s | %d ruta/or till kistan | avklarad: %s | noder i världen: %d" % [
			varv, str(före), str(run.explore.pos), avstånd, "ja" if kista.cleared else "nej",
			_kista_noder(kista).size()])
	print("[kistnara] kistan avklarad på %s, kvar i världen: %s" % [str(kista.pos),
		"%d noder" % _kista_noder(kista).size() if kista.cleared else "noden är orörd"])
	# Bilden av den PLUNDRADE kistan tas från rutan spelaren kom ifrån: från kistans egen ruta ser man
	# golvet under sina fötter, inte kistan — och det är den öppna kistan hela önskemålet handlar om
	# ("Kistor försvinner när man kommer nära, det får de inte göra"). Siffrorna står före bilden.
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	cam.position = Vector3(centrum.x - riktning.x, 0.5, centrum.z - riktning.y)
	cam.rotation.y = atan2(-riktning.x, -riktning.y)     # fri vinkel ur en riktning: kistprovet
	# tittar in från vilket håll som helst, så `facing` (fyra håll) duger inte här
	cam.force_update_transform()
	await get_tree().process_frame
	await get_tree().process_frame
	# Panelerna bort för bilden: striden startade av sig själv under vandringen, och stridspanelen och
	# belöningsrutan ligger mitt över kistan. De hör till gränssnittet, inte till det provet mäter.
	battle_panel.visible = false
	end_panel.visible = false
	draft_panel.visible = false
	reward_fx.visible = false
	var kvar := _kista_noder(kista)
	var m_slut := _kista_skärm(kvar)
	print("[kistnara] efter plundringen, från rutan intill: %s | %s" % [_kista_slag(kvar),
		_kista_text(m_slut)])
	_spara_bild("user://shots/kistnara-slut.png")
	get_tree().quit()


## Rutan intill en nod: den granne spelaren kan stå i och komma in ifrån. -1 = ingen.
func _granne(pos: Vector2i) -> Vector2i:
	for d in Explore.STEP:
		var p: Vector2i = pos + d
		if run.explore.floor_ref.is_floor_at(p):
			return p
	return Vector2i(-1, -1)


## Kistans noder i världen. Delarna i gruppen "kista" om kistan är byggd (M32), annars spriten med
## kistans egen bild — så att provet mäter samma kista före och efter ändringen.
func _kista_noder(n: Dungeon.FloorNode) -> Array:
	var ut: Array = []
	var centrum := Vector3(n.pos.x + 0.5, 0.0, n.pos.y + 0.5)
	for m in get_tree().get_nodes_in_group("kista"):
		if m is MeshInstance3D and m.global_position.distance_to(centrum) < 1.2:
			ut.append(m)
	if ut.is_empty() and world != null:
		for c in world.find_children("*", "Sprite3D", true, false):
			var s := c as Sprite3D
			if s.texture != null and s.texture.resource_path.contains("props/chest"):
				ut.append(s)
	return ut


## Vad kistan ÄR, som en rad: byggd geometri eller en skylt.
func _kista_slag(noder: Array) -> String:
	if noder.is_empty():
		return "finns inte"
	var skyltar := 0
	for n in noder:
		if n is Sprite3D and (n as Sprite3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			skyltar += 1
	if skyltar == noder.size():
		return "billboard-skylt"
	if skyltar > 0:
		return "%d av %d är skyltar" % [skyltar, noder.size()]
	return "byggd geometri"


## Kistans hörn i världen, så som det som RITAS har dem: en billboard-skylt ligger alltid i kamerans
## eget plan — hörnen räknas därför ur KAMERANS axlar, inte ur nodens transform — medan byggd
## geometri har sina hörn i världen (meshens ruta gånger nodens transform).
func _kista_punkter(noder: Array) -> Array:
	var ut: Array = []
	var höger := cam.global_transform.basis.x.normalized()
	var upp := cam.global_transform.basis.y.normalized()
	for nod in noder:
		if nod is Sprite3D:
			var s := nod as Sprite3D
			var c := s.global_position
			var halv := Vector2(s.texture.get_width(), s.texture.get_height()) * s.pixel_size * 0.5
			ut.append(c + höger * halv.x + upp * halv.y)
			ut.append(c - höger * halv.x + upp * halv.y)
			ut.append(c + höger * halv.x - upp * halv.y)
			ut.append(c - höger * halv.x - upp * halv.y)
		elif nod is MeshInstance3D:
			var mi := nod as MeshInstance3D
			var aabb := mi.get_aabb()
			for i in 8:
				ut.append(mi.global_transform * aabb.get_endpoint(i))
	return ut


## Kistans ruta på skärmen (vyns px) och dess minsta djup in i bilden. `klippta` är antalet hörn
## innanför kamerans närplan — är ALLA det klipps hela kistan bort, och det är svaret på varför en
## skylt på spelarens egen ruta försvinner.
func _kista_skärm(noder: Array) -> Dictionary:
	var vyn := Rect2(Vector2.ZERO, Vector2(VY))
	var minst := Vector2(INF, INF)
	var störst := Vector2(-INF, -INF)
	var djup := INF
	var klippta := 0
	var punkter := _kista_punkter(noder)
	for p in punkter:
		var fram := -cam.global_transform.basis.z.dot(p - cam.global_position)
		djup = minf(djup, fram)
		if fram < cam.near:
			klippta += 1
			continue
		var q := cam.unproject_position(p)
		minst.x = minf(minst.x, q.x)
		minst.y = minf(minst.y, q.y)
		störst.x = maxf(störst.x, q.x)
		störst.y = maxf(störst.y, q.y)
	var ruta := Rect2(minst, störst - minst) if klippta < punkter.size() else Rect2()
	return {"djup": djup, "klippta": klippta, "punkter": punkter.size(), "ruta": ruta,
		"i_bild": klippta < punkter.size() and vyn.intersects(ruta)}


func _kista_text(m: Dictionary) -> String:
	if int(m["klippta"]) >= int(m["punkter"]):
		return "%d/%d hörn innanför närplanet: helt bortklippt" % [int(m["klippta"]), int(m["punkter"])]
	var r: Rect2 = m["ruta"]
	var utanför := ""
	if not Rect2(Vector2.ZERO, Vector2(VY)).intersects(r):
		utanför = ", utanför bild"
	elif int(m["klippta"]) > 0:
		utanför = ", %d hörn klippta" % int(m["klippta"])
	return "skärm z=(%4.0f,%4.0f) %.0fx%.0f px%s" % [r.position.x, r.position.y, r.size.x, r.size.y, utanför]


func _kista_pixtext(px: Dictionary) -> String:
	if int(px["px"]) < 0:
		return "ingen bild kunde läsas"
	return "%d av %d px i rutan ändras när kistan göms" % [int(px["px"]), int(px["ruta"])]


## Kistans ruta i VÄRLDEN (AABB över alla dess delar). Den ska stå still hur kameran än står.
func _kista_världsruta(noder: Array) -> AABB:
	var ut := AABB()
	var först := true
	for n in noder:
		var a: AABB = (n as Sprite3D).get_aabb() if n is Sprite3D else (n as MeshInstance3D).get_aabb()
		for i in 8:
			var p: Vector3 = n.global_transform * a.get_endpoint(i)
			if först:
				ut = AABB(p, Vector3.ZERO)
				först = false
			else:
				ut = ut.expand(p)
	return ut


## En bild av SPELVYN (480x270) med kistans noder synliga eller gömda. Trädet pausas mellan de två
## bildrutorna, så skillnaden är kistans pixlar och ingenting annat — elden fladdrar, dimman rör sig
## och tonemappningen är temporal, och utan pausen mäts rummets brus.
func _bild_med_kista(noder: Array, synlig: bool) -> Image:
	for n in noder:
		n.visible = synlig
	var pausat: bool = get_tree().paused
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	var img := _vy.get_texture().get_image()
	get_tree().paused = pausat
	return img


## Hur många bildpunkter i kistans egen ruta som skiljer sig mellan "kistan gömd" och "kistan synlig".
## En kanal måste skilja mer än KISTA_PIXELTRÖSKEL för att räknas: MÄTT att renderarens EGNA
## animation (elden, dimman, den temporala GI:n) går på GPU-tid och alltså rör sig även med trädet
## pausat — utan tröskeln mättes rummets brus i stället för kistan (brusgolvet var 5385 px i samma
## ruta). Provet skriver ut brusgolvet med SAMMA tröskel, så siffran går att jämföra.
func _kista_pixlar(noder: Array, ruta: Rect2) -> Dictionary:
	var vyn := Vector2(VY)
	var r := ruta.grow(1.0).intersection(Rect2(Vector2.ZERO, vyn))
	if r.size.x < 1.0 or r.size.y < 1.0:
		r = Rect2(Vector2.ZERO, vyn)       # helt bortklippt: frågan är då om den syns NÅGONSTANS
	var utan: Image = await _bild_med_kista(noder, false)
	var med: Image = await _bild_med_kista(noder, true)
	if utan == null or med == null:
		return {"px": -1, "ruta": 0}
	utan.convert(Image.FORMAT_RGBA8)
	med.convert(Image.FORMAT_RGBA8)
	var x0 := clampi(int(floor(r.position.x)), 0, int(vyn.x) - 1)
	var y0 := clampi(int(floor(r.position.y)), 0, int(vyn.y) - 1)
	var x1 := clampi(int(ceil(r.end.x)), 1, int(vyn.x))
	var y1 := clampi(int(ceil(r.end.y)), 1, int(vyn.y))
	var px := 0
	var n := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			n += 1
			if _pixlar_olika(utan.get_pixel(x, y), med.get_pixel(x, y)):
				px += 1
	return {"px": px, "ruta": n}


## Två bildpunkter: en kanal som skiljer mer än KISTA_PIXELTRÖSKEL räknas som ändrad.
static func _pixlar_olika(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) > KISTA_PIXELTRÖSKEL or absf(a.g - b.g) > KISTA_PIXELTRÖSKEL \
		or absf(a.b - b.b) > KISTA_PIXELTRÖSKEL


## Brusgolvet för `_kista_pixlar`: samma A/B, men med kistan GÖMD i båda bilderna. Siffran är vad
## rummets eget liv kan åstadkomma i samma ruta — ett kistvärde i den storleken betyder "ingenting".
func _kista_brus(noder: Array, ruta: Rect2) -> int:
	var förra := []
	for n in noder:
		förra.append(n.visible)
	for n in noder:
		n.visible = false
	var pausat: bool = get_tree().paused
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	var a := _vy.get_texture().get_image()
	await RenderingServer.frame_post_draw
	var b := _vy.get_texture().get_image()
	get_tree().paused = pausat
	for i in noder.size():
		noder[i].visible = förra[i]
	if a == null or b == null:
		return -1
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var vyn := Vector2(VY)
	var r := ruta.grow(1.0).intersection(Rect2(Vector2.ZERO, vyn))
	var px := 0
	for y in range(clampi(int(floor(r.position.y)), 0, int(vyn.y) - 1),
			clampi(int(ceil(r.end.y)), 1, int(vyn.y))):
		for x in range(clampi(int(floor(r.position.x)), 0, int(vyn.x) - 1),
				clampi(int(ceil(r.end.x)), 1, int(vyn.x))):
			if _pixlar_olika(a.get_pixel(x, y), b.get_pixel(x, y)):
				px += 1
	return px


## Kart-editorns playtest: {stage_id, floor}. Läses en gång och raderas — annars skulle nästa
## vanliga start hamna på en ritad våning utan att någon bett om det.
func _take_playtest() -> Dictionary:
	var path := "user://playtest.json"
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	print("playtest: %s våning %d" % [d.get("stage_id", "?"), int(d.get("floor", 0)) + 1])
	return d

## Smeden: trädets noder, en gren i taget. Många små steg med stigande pris — det är hela poängen med
## ett nodnät: man köper något litet ofta, i stället för något stort sällan. Förkunskaperna syns på
## varje rad, så en låst nod säger av VAD den är låst.
func _smed_text() -> String:
	var grenar := meta.branches()
	if grenar.is_empty():
		return Tr.t("ui.smith.empty", "SMEDEN — inget att smida än")
	var gren := str(grenar[_smed_vald % grenar.size()])
	# SPLITTRET STÅR I RUBRIKEN (M57): de permanenta noderna köps för den, och en valuta man inte ser
	# saldot på går inte att planera efter.
	var rader := [Tr.t("ui.smith.title", "SMEDEN · %s — guld i banken: %d") % [gren, meta.gold],
		Tr.t("ui.smith.splitter", "splitter i fickan: %d") % meta.shards,
		Tr.t("ui.smith.branches", "gren %d av %d · ← → byter gren")
			% [_smed_vald % grenar.size() + 1, grenar.size()], ""]
	var linjer := meta.tree_lines(gren)
	for v in linjer:
		# Priset syns ALLTID, även på en låst nod: i ett träd med stigande priser är det priset man
		# planerar efter, och att gömma det bakom ett lås tar bort själva planeringen.
		# Priset står i den valuta noden faktiskt kostar. En splitter-nod med "0 guld" hade sett ut
		# som en gåva.
		var pris := (Tr.t("ui.smith.splitter_cost", "%d splitter") % int(v["shard_cost"])
			if bool(v.get("splitter", false)) else Tr.t("ui.village.price", "%d guld") % int(v["cost"]))
		var not_ := ""
		if int(v["max_rank"]) > 0 and int(v["rank"]) >= int(v["max_rank"]):
			pris = Tr.t("ui.smith.maxed", "full")
		elif bool(v["låst"]):
			not_ = "   " + Tr.t("ui.smith.locked", "låst: %s") % v["krav"]
		# Samma ✓/✗ som butiken: svaret på "har jag råd?" bredvid priset. För en splitter-nod är det
		# splittret som prövas — `can_buy` räknar rätt ficka.
		rader.append("%s %-16s %d/%d %s %9s  %s%s" % [v["key"], v["name"], v["rank"],
			v["max_rank"], "OK" if bool(v["affordable"]) else "X", pris, v["text"], not_])
	rader.append("")
	rader.append(Tr.t("ui.smith.hint", "1-%d = köp · Esc = tillbaka till byn") % linjer.size())
	return "\n".join(rader)

## Köp en nod i den visade grenen. Samma `meta.buy` som butiken — trädet är en annan VY över samma köp.
func _buy_node(i: int) -> void:
	var grenar := meta.branches()
	if grenar.is_empty():
		return
	var linjer := meta.tree_lines(str(grenar[_smed_vald % grenar.size()]))
	if i < 1 or i > linjer.size():
		return
	var id := str(linjer[i - 1]["id"])
	var res := meta.buy(id)
	if res.ok:
		_sfx("coin")
		print("smeden: %s till rang %d" % [id, int(res.get("rank", 0))])
		if not meta.save():
			push_warning("kunde inte spara: %s" % meta.last_error)
	else:
		print("kan inte köpa %s: %s" % [id, res.reason])

## Värdshuset: hjältar man hyr för guld. De blir EGNA KORT i startleken, och deras passiva verkan
## gäller varje tur så länge kortet finns i leken — en gång per tur, inte en gång per kopia i handen.
## Skärmen: kortväggen. Texten ovanför bär det som INTE står på kortet — den hyrdes passiva verkan,
## priset och hur man gör — och korten under är samma CardView som i leken. Texten byggs här och
## inte i en egen funktion som lämnar tillbaka en sträng: raden behöver veta vilket kort som är valt.
func _show_inn() -> void:
	var linjer := meta.crawler_lines()
	inn_index = clampi(inn_index, 0, maxi(0, linjer.size() - 1))
	for barn in inn_stor.get_children():
		barn.queue_free()
	for barn in inn_box.get_children():
		barn.queue_free()
	inn_panel.visible = true
	if linjer.is_empty():
		inn_label.text = Tr.t("ui.inn.tom", "inga hjältar att hyra")
		_place_panel(inn_panel, false)
		return
	var vald: Dictionary = linjer[inn_index]
	var id := str(vald["id"])
	var c: Cards.Card = db.get(id)
	# Priset står i guld — samma nyckel som byns prislappar, så en hjälte och en butiks­vara inte kan
	# säga olika saker om samma mynt. Nycklarna för väljandet är menyns egna ("W/S välj · Enter
	# bekräfta") och gäller ordagrant här: piltangenterna och W/S gör samma sak.
	inn_label.text = "%s\n%s — %s\n%s · %s · %s" % [
		Tr.t("ui.inn.title", "VÄRDSHUSET — guld i banken: %d") % meta.gold,
		str(vald["name"]), str(vald["text"]),
		(Tr.t("ui.inn.hired", "I LEEK") if bool(vald["hired"])
			else Tr.t("ui.village.price", "%d guld") % int(vald["price"])),
		Tr.t("ui.meny.hint", "W/S välj · Enter bekräfta"),
		Tr.t("ui.inn.hint", "1-%d = hyr · Esc = tillbaka till byn") % linjer.size()]
	# Det valda kortet stort, och hela raden under. Kortet är hjältens EGET kort (samma id som
	# kamraten), så det man läser om är exakt det som hamnar i leken.
	if c != null:
		inn_stor.add_child(CardView.make(c, inn_index, _card_icon(id), true, INN_SKALA))
	for i in linjer.size():
		var kid := str(linjer[i]["id"])
		var k: CardView = CardView.make(db.get(kid), i, _card_icon(kid), false, INN_RAD)
		k.set_forward(i == inn_index)
		k.picked.connect(_inn_klick)
		inn_box.add_child(k)
	_place_panel(inn_panel, false)

## Välj ett kort (piltangenterna). Ren förflyttning — klicket har sin egen väg, för ett klick på det
## valda ska köpa och ett klick på ett annat ska bara flytta markeringen.
func _inn_välj(i: int) -> void:
	var linjer := meta.crawler_lines()
	if linjer.is_empty():
		return
	inn_index = wrapi(i, 0, linjer.size())
	_show_inn()

## Klick på ett kort: ett tryck väljer det, ett tryck på det redan valda hyr det. Två tryck för att
## köpa, och priset står skrivet mellan dem.
func _inn_klick(i: int) -> void:
	if i == inn_index:
		_hire(i + 1)
	_show_inn()

## --- BANVERKSTADEN (M60) -----------------------------------------------------------------------
##
## Alex: *"Vi behöver bygga ut alla banor med, så du får gärna utöka arean jag kan göra banor i, samt
## så jag kan editera alla banor i spelet."* Kartan ger honom platserna (N = ny plats, se
## WorldMapView.ny_plats_för_vald); den här skärmen ger honom BANORNA: alla 40, fält för fält.
##
## Fälten och deras gränser kommer ur `Stages.FÄLT` — verkstaden visar samma tal som filen kläms
## med, så en ändring här kan inte skriva en bana spelet inte kan läsa. Att byta NAMN är text och
## ligger kvar i filen (den som döper en bana gör det en gång); det här är rattarna man drar i.
func _show_verkstad() -> void:
	if _stage_order.is_empty():
		verk_label.text = Tr.t("ui.verk.tom", "BANVERKSTADEN — inga banor att redigera")
		_place_panel(verk_panel, false)
		return
	_verk_stage = clampi(_verk_stage, 0, _stage_order.size() - 1)
	_verk_fält = clampi(_verk_fält, 0, Stages.FÄLT.size() - 1)
	var id := str(_stage_order[_verk_stage])
	var s: Stages.StageDef = stages.get(id)
	if s == null:
		verk_label.text = Tr.t("ui.verk.tom", "BANVERKSTADEN — inga banor att redigera")
		_place_panel(verk_panel, false)
		return
	var rader := [
		Tr.t("ui.verk.title", "BANVERKSTADEN · bana %d av %d") % [_verk_stage + 1, _stage_order.size()],
		"%s   (%s)" % [Tr.name_of("stage", id, s.name), id],
		""]
	for i in Stages.FÄLT.size():
		var f: Dictionary = Stages.FÄLT[i]
		var v := float(s.get(str(f["nyckel"])))
		var vis := ("%.2f" % v) if v != floorf(v) else str(int(v))
		rader.append("%s %-18s %s" % ["▸" if i == _verk_fält else " ", str(f["text"]), vis])
	rader.append("")
	rader.append(Tr.t("ui.verk.hint",
		"← → bana · W/S fält · +/− ändra · S = spara · Esc = tillbaka till kartan"))
	if not _verk_rad.is_empty():
		rader.append(_verk_rad)
	verk_label.text = "\n".join(rader)
	_place_panel(verk_panel, false)


## Ändrar det valda fältet med ett steg och klämmer till gränsen. Skriver INTE filen — det gör S, så
## man kan ångra sig innan något hamnar på disk.
func _verk_ändra(riktning: float) -> void:
	if _stage_order.is_empty():
		return
	var id := str(_stage_order[clampi(_verk_stage, 0, _stage_order.size() - 1)])
	var s: Stages.StageDef = stages.get(id)
	if s == null:
		return
	var f: Dictionary = Stages.FÄLT[_verk_fält]
	var nyckel := str(f["nyckel"])
	var nytt := Stages.kläm(nyckel, float(s.get(nyckel)) + riktning * float(f["steg"]))
	s.set(nyckel, int(nytt) if nytt == floorf(nytt) else nytt)
	_verk_rad = ""
	_show_verkstad()


## Sparar den visade banan. Läser om bandata efteråt, så en körning startar med det man just satte.
func _verk_spara() -> void:
	if _stage_order.is_empty():
		return
	var id := str(_stage_order[clampi(_verk_stage, 0, _stage_order.size() - 1)])
	var s: Stages.StageDef = stages.get(id)
	if s == null:
		return
	if Stages.skriv(s):
		_verk_rad = Tr.t("ui.verk.saved", "%s sparad") % id
		stages = Stages.load_all()
		print("verkstaden: %s sparad (%s)" % [id, str(s.to_dict())])
	else:
		_verk_rad = Tr.t("ui.verk.failed", "kunde inte skriva %s") % id
	_show_verkstad()


## JUVELERAREN (M58). Två stationer: FACKEN och FICKAN. Etiketten bär båda — korten i raden är
## lekens egna, och en rad per fack och en rad per sten står över dem. Tangenterna är de samma som
## överallt annars: piltangenter väljer, Enter gör, siffrorna 1-4 tar ett fack direkt.
func _show_jewel() -> void:
	var lek := _start_lek()
	jewel_kort = clampi(jewel_kort, 0, maxi(0, lek.size() - 1))
	for barn in jewel_box.get_children():
		barn.queue_free()
	jewel_panel.visible = true
	if lek.is_empty():
		jewel_label.text = Tr.t("ui.jewel.tom", "JUVELERAREN — inga kort att sätta stenar i")
		_place_panel(jewel_panel, false)
		return
	var c: Cards.Card = lek[jewel_kort]
	var fack := meta.gem_slots_for(c.id)
	var bonus := meta.gem_bonus(c.id)
	var rader := [
		Tr.t("ui.jewel.title", "JUVELERAREN — guld %d · splitter %d") % [meta.gold, meta.shards],
		"%s   %s%s" % [c.name, Tr.t("ui.jewel.slots", "fack %d/4") % fack,
			("   " + Tr.t("ui.jewel.bonus", "stenarna ger %s") % str(bonus)) if not bonus.is_empty() else ""]]
	# Station 1: facken. Ett fack som inte finns kostar guld att öppna — priset står på raden.
	for i in 4:
		var mark := "▸" if i == jewel_fack else " "
		var text := ""
		if i >= fack:
			text = Tr.t("ui.jewel.stangt", "stängt — %d guld att öppna") % meta.gem_slot_cost(c.id)
		else:
			var s := meta.gem_in_slot(c.id, i)
			text = Tr.t("ui.jewel.tomt", "tomt") if s.is_empty() \
				else meta.gem_name(str(s["fam"]), int(s["grad"]))
		rader.append("%s %d: %s" % [mark, i + 1, text])
	# Station 2: fickan. Stenarna kistorna gett, med namn och grad.
	var ficka := meta.gem_bag()
	rader.append("")
	if ficka.is_empty():
		rader.append(Tr.t("ui.jewel.ficka_tom", "fickan är tom — stenarna ligger i kistorna på banorna"))
	else:
		jewel_sten = clampi(jewel_sten, 0, ficka.size() - 1)
		var bitar := []
		for i in ficka.size():
			var rad: Dictionary = ficka[i]
			var m := "▸" if i == jewel_sten else " "
			bitar.append("%s%s x%d" % [m, meta.gem_name(str(rad["fam"]), int(rad["grad"])),
				int(rad["antal"])])
		rader.append("  ".join(bitar))
	# TIPS-RADEN BRÖTS I TVÅ (M93). Den är 1236 px på en rad ("← → kort · 1-4 fack · W/S sten ·
	# Enter = öppna/sätt/plocka ur · Esc = tillbaka"), och panelen centreras i den 480 px breda vyn —
	# hela vänsterkanten av varje rad hamnade utanför skärmen, rubriken med guldet först av allt.
	# En Labels egen minimibredd är textens bredd även med radbrytning på, så en bredd på etiketten
	# räcker inte (mätt: panelen blev 1236 px ändå). Här bryts strängen själv, vid mitten av dess
	# "·"-delar — samma struktur i alla 13 språk, så ingen översättning behöver röras.
	var tips := Tr.t("ui.jewel.hint",
		"← → kort · 1-4 fack · W/S sten · Enter = öppna/sätt/plocka ur · Esc = tillbaka")
	var bitar := tips.split("·", false)
	if bitar.size() >= 3:
		var mitt := int(ceil(bitar.size() / 2.0))
		rader.append(" · ".join(bitar.slice(0, mitt)).strip_edges())
		rader.append(" · ".join(bitar.slice(mitt)).strip_edges())
	else:
		rader.append(tips)
	jewel_label.text = "\n".join(rader)
	# Raden: hela leken. Det valda kortet är det som lyfts fram (`set_forward`), och facken syns på
	# korten som små märken (CardView) — förhandsvisningen ovanför togs bort i M93.
	for i in lek.size():
		var k: CardView = CardView.make(lek[i], i, _card_icon(lek[i].id), false, JEWEL_RAD)
		k.set_forward(i == jewel_kort)
		k.picked.connect(_jewel_klick)
		jewel_box.add_child(k)
	_place_panel(jewel_panel, false)

func _jewel_klick(i: int) -> void:
	if i == jewel_kort:
		_jewel_enter()
	else:
		jewel_kort = i
		jewel_fack = 0
	_show_jewel()

## Enter i juveleraren, i den ordningen en ny spelare möter den: facket finns inte -> öppna det;
## facket är tomt -> sätt stenen; facket är upptaget -> plocka ur den (tillbaka i fickan).
func _jewel_enter() -> void:
	var lek := _start_lek()
	if lek.is_empty():
		return
	var id: String = str(lek[jewel_kort].id)
	var fack := meta.gem_slots_for(id)
	if jewel_fack >= fack:
		var res := meta.buy_gem_slot(id)
		print("juveleraren: %s fack %d -> %s (%s)" % [id, fack + 1, res.ok, res.reason])
		if res.ok:
			_sfx("coin")
			meta.save()
			return
		return
	if not meta.gem_in_slot(id, jewel_fack).is_empty():
		var ur := meta.unsocket(id, jewel_fack)
		if ur.ok:
			_sfx("pick")
			meta.save()
		return
	var ficka := meta.gem_bag()
	if ficka.is_empty():
		return
	var rad: Dictionary = ficka[clampi(jewel_sten, 0, ficka.size() - 1)]
	var satt := meta.socket(id, jewel_fack, str(rad["fam"]), int(rad["grad"]))
	print("juveleraren: %s fack %d <- %s (%s)" % [id, jewel_fack + 1, rad["fam"], satt.reason])
	if satt.ok:
		_sfx("pick")
		meta.save()

## Hyr kamrat nummer i (1-baserat). Skälet skrivs ut i klartext — en tangent som inte gör något
## ska säga varför.
func _hire(i: int) -> void:
	var linjer := meta.crawler_lines()
	if i < 1 or i > linjer.size():
		return
	var id := str(linjer[i - 1]["id"])
	var res := meta.hire(id)
	if res.ok:
		_sfx("coin")
		print("hyrde %s för %d guld" % [id, res.price])
		if not meta.save():
			push_warning("kunde inte spara: %s" % meta.last_error)
		# Kortväggen ritas om: kortet ska visa "I LEEK" med en gång, inte först nästa gång skärmen
		# öppnas. Anroparen ritar också om, men den som hyr via siffran kom inte dit.
		if shell == "vardshus":
			_show_inn()
	else:
		print("kan inte hyra %s: %s" % [id, res.reason])

## Öppna en skärm. `skarm=`-flaggan går samma väg som tangenterna, så en skärmbild av en skärm
## bevisar att skärmen går att NÅ — inte bara att den finns i koden. Ett okänt namn säger ifrån i
## klartext i stället för att ge en tom skärm.
func _välj_skarm(skarm: String) -> void:
	if skarm.is_empty() or skarm == "by" or skarm == "hem":
		_show_home()
		return
	if skarm == "karta":
		karta_view.gå_till(_first_playable())
		shell = "karta"
		_refresh_shell()
		return
	if skarm == "butik" or skarm == "vardshus" or skarm == "smed" or skarm == "album" or skarm == "juvelerare" or skarm == "banverkstad":
		shell = skarm
		_refresh_shell()
		return
	print("okänd skärm: %s (by|butik|vardshus|smed|karta|album|juvelerare) — startar i byn" % skarm)
	_show_home()

## Man gick in i en plats i byn. Porten leder till kartan, och markeringen sätts på den bana man
## faktiskt kan spela — annars öppnar kartan sig på bana 1 varje gång, även när den är klar.
func _på_plats(skepp: String) -> void:
	# EXIT-skylten i byn stänger spelet. Den är ingen SKÄRM i skalet, så den tas före kontrollen
	# mot SKAL_LÄGEN — annars blev den "okänd plats" och skickade spelaren tillbaka till byn.
	# Samma avslut som menyns AVSLUTA: en väg ut, inte två olika.
	if skepp == "avsluta":
		get_tree().quit()
		return
	if not SKAL_LÄGEN.has(skepp):
		push_warning("okänd plats: %s — tillbaka till byn" % skepp)
		_show_home()
		return
	if skepp == "karta":
		karta_view.gå_till(_first_playable())
	shell = skepp
	_refresh_shell()

## Man gick in i en bana på kartan. Banan är vald; körningen tar över vyn.
func _på_bana(stage_id: String) -> void:
	_start_run(stage_id, randi())

## Rita om skalet. Panelen som hör till läget visas, de andra göms — och 3D-vyn ritas bara i en
## körning, eftersom det inte finns någon våning att visa förrän man valt en.
func _refresh_shell() -> void:
	var i_körning: bool = shell == "körning"
	by_view.visible = shell == "hem"
	karta_view.visible = shell == "karta"
	butik_panel.visible = shell == "butik"
	album_panel.visible = shell == "album"
	inn_panel.visible = shell == "vardshus"
	smed_panel.visible = shell == "smed"
	jewel_panel.visible = shell == "juvelerare"
	verk_panel.visible = shell == "banverkstad"
	map_view.visible = i_körning
	if map_view.visible != i_körning:
		pass
	if i_körning:
		return
	# Stridspanelerna hör till körningen. Att lämna dem orörda gav en kvarglömd panel över första
	# bokstaven i toppraden (mätt: 9x21 px) — den syntes inte under en körning, eftersom
	# _refresh_stats gömmer den, men skalet anropar aldrig den funktionen.
	stats_panel.visible = false
	battle_panel.visible = false
	draft_panel.visible = false
	end_panel.visible = false      # slutskärmen hör också till körningen; skalet tar hela vyn
	# Kärlen i marginalen hör också till körningen: i byn finns ingen hälsa att visa, och ett tomt
	# kärl där vore en siffra som inte gäller.
	_visa_gui(false)
	# TEXTEN FÖRST, placeringen efter: panelen mäts mot sitt innehåll, och den som placerades medan
	# etiketten var tom blev en liten ruta som texten flöt ut ur (sett på bild: raden om
	# tangenterna skars av vid skärmkanten).
	if shell == "hem":
		# Byn och kartan ritar sig själva: de får metat och ordningen, inte en färdig textrad.
		by_view.visa(meta, _stage_order.size())
	elif shell == "album":
		_show_album()
	elif shell == "karta":
		karta_view.visa(stages, _stage_order, meta)
	elif shell == "butik":
		butik_label.text = _village_text("by")
	elif shell == "vardshus":
		_show_inn()
	elif shell == "smed":
		smed_label.text = _smed_text()
	elif shell == "juvelerare":
		_show_jewel()
	elif shell == "banverkstad":
		_show_verkstad()
	for p in [butik_panel, smed_panel]:
		_place_panel(p, false)
	# SALDOT SYNS NU (M61). Alex: *"Ingenstans visas det hur mycket gold man har, så det är omöjligt
	# att veta om man har råd eller ej."* Raden fylldes förut men etiketten var `visible = false` och
	# sattes aldrig på — den syntes alltså ingenstans (mätt: byn har ingen text om guld alls).
	#
	# Panelskärmarna (butik, smed, värdshus, juveleraren) bär saldot i sin EGEN rubrik, så där vore
	# raden en dubblering över en panel som redan fyller vyn. Byn, kartan och albumet har ingen
	# rubrik — där står den i spelvyns överkant, som är tom.
	top_label.visible = shell == "hem" or shell == "karta" or shell == "album"
	top_label.text = "%s · %s" % [
		Tr.t("ui.shell.status", "HellCrawler · %d guld · %d/%d banor upplåsta")
			% [meta.gold, meta.unlocked.size(), _stage_order.size()],
		Tr.t("ui.shell.splitter", "%d splitter") % meta.shards]
	# Tipsen och korträknaren hör till KÖRNINGEN. Byn och kartan ritar sin egen text, och en
	# kvarglömd hand över byn vore en lögn om var man är.
	hint_label.text = ""
	kort_label.text = ""

func _show_home() -> void:
	shell = "hem"
	_refresh_shell()

## Skärmbild av EN skärm i skalet: `-- shot skarm=by` (eller karta). Samma väg som tangenterna tar
## (`_välj_skarm`), så bilden bevisar att skärmen går att NÅ — och en skärmbild är det enda som
## säger något om hur byn och kartan faktiskt ser ut.
func _shot_skarm(skarm: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_spara_bild("user://shot.png")
	print("skärmbild (%s): %s" % [skarm if not skarm.is_empty() else "by",
		ProjectSettings.globalize_path("user://shot.png")])
	get_tree().quit()

## En tom 3D-vy: skalet har ingen våning att bygga, men vyn klagar varje bildruta utan kamera.
## --- STARTMENYN (M39) -------------------------------------------------------------------------

## Rubrikerna i menyns ordning. Översatta av `Tr.t`, alltså samma texter i alla 13 språk (nycklarna
## ligger i tools/meny_i18n.py).
func _meny_rubriker() -> Array:
	# Den sista raden är TILLFÄLLIG och därför otversatt: en genväg till editorn så man slipper komma
	# ihåg terminaladressen. Att lägga en debug-rad i de 13 språkfilerna vore att översätta något som
	# ska bort igen — den får stå på svenska tills vidare.
	# SPARA SPEL står före LADDA SPEL: de två hör ihop, och den som just spelat letar efter spara.
	return [Tr.t("ui.meny.nytt", "NYTT SPEL"), Tr.t("ui.meny.spara", "SPARA SPEL"),
		Tr.t("ui.meny.ladda", "LADDA SPEL"),
		Tr.t("ui.meny.alternativ", "ALTERNATIV"), Tr.t("ui.meny.avsluta", "AVSLUTA"),
		"BANEDITOR (tillfällig)", "FIENDEEDITOR (tillfällig)"]

## Bottenraden: tipset överst, version och copyright under. Finns en sparad körning står det i tipset
## vad LADDA SPEL gör — en rad som säger "fortsätt på våning 3" är ett svar, "LADDA SPEL" är en fråga.
func _meny_botten() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	var tips := Tr.t("ui.meny.hint", "W/S välj · Enter bekräfta")
	if not _meny_meddelande.is_empty():
		# Kvittensen från SPARA SPEL står kvar tills menyn göms: annars försvinner beviset för att
		# trycket gjorde något.
		tips = _meny_meddelande
	elif not meta.korning.is_empty():
		tips = Tr.t("ui.meny.sparad", "fortsätt på våning %d") % (int(meta.korning.get("floor", 0)) + 1)
	return "%s\n%s · %s" % [tips, Tr.t("ui.meny.version", "Version %s") % version,
		Tr.t("ui.meny.copyright", "© 2026 HellCrawler")]

func _visa_meny() -> void:
	# Den sparade körningen avgör om LADDA SPEL går att välja, och en pågående körning om SPARA SPEL
	# gör det. Orsaken följer med in i raden, så en spärrad rad kan säga varför i stället för att bara
	# vara tyst.
	var spärrade := {}
	if meta.korning.is_empty():
		spärrade[2] = Tr.t("ui.meny.tom", "ingen sparad körning")
	if run == null or run.finished:
		spärrade[1] = Tr.t("ui.meny.inget", "ingen pågående körning")
	meny.visa(_meny_rubriker(), spärrade, _meny_botten())
	meny.visible = true
	_placera_meny()
	if meta.musik_på and musik.stream != null and not musik.playing:
		musik.play()

func _dölj_meny() -> void:
	meny.visible = false
	alt_panel.visible = false
	_meny_meddelande = ""
	# Musiken STOPPAS INTE här (M54). Förut tystnade spelet när körningen började; nu är spellistan
	# meningen att höras i byn och i banorna, så menyn lämnar över till samma spelare.
	if meta.musik_på and not musik.playing:
		musik.play()

func _placera_meny() -> void:
	if meny == null or not is_instance_valid(meny):
		return
	# Ingen storlek sätts här: menyn är full-rect-ankrad och får sin ruta av trädet (att sätta den
	# för hand i _ready gav "size overridden after _ready"). `_placera` läser `size` och faller
	# tillbaka på fönstrets ruta om trädet inte hunnit sätta den än.
	meny._placera()

func _meny_tangent(key: int) -> void:
	if key == KEY_ESCAPE:
		# ESC stänger menyn och lämnar tillbaka till det som låg bakom: banan man kom ifrån, eller
		# byn. Spelet stannade aldrig när menyn kom fram, så det räcker att gömma den.
		_dölj_meny()
		return
	if key == KEY_UP or key == KEY_W:
		meny.flytta(-1)
	elif key == KEY_DOWN or key == KEY_S:
		meny.flytta(1)
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		meny.bekräfta()

## Menyns val. Klicket och tangenten landar här båda två (`Huvudmeny.valt`), så de kan inte glida
## ifrån varandra.
func _meny_val(i: int) -> void:
	match i:
		0:
			# NYTT SPEL: skalet (byn) — samma väg som spelet alltid startade i, men först nu.
			_dölj_meny()
			_välj_skarm("")
		1:
			_spara_från_menyn()
		2:
			_fortsätt_körning()
		3:
			_visa_alternativ()
		4:
			get_tree().quit()
		5:
			# Editorn läser sina argument ur kommandoraden och har samma standard som tools/editor.sh
			# (stage_01, våning 1), så en tom argumentlista startar rätt våning.
			get_tree().change_scene_to_file("res://editor/editor.tscn")
		6:
			# Fiendeeditorn har samma standard som tools/fiendeeditor.sh: första fienden i listan.
			get_tree().change_scene_to_file("res://editor/fiendeeditor.tscn")

## SPARA SPEL i menyn. Körningen sparar sig visserligen själv så fort något ändras (M39), men den som
## ska stänga spelet vill kunna VÄLJA att spara — och se att det blev gjort. `tvinga` skriver filen
## även när inget ändrats sedan förra sparningen; annars vore raden tyst just när man trycker på den.
func _spara_från_menyn() -> void:
	if run == null or run.finished:
		return
	_spara_körning(true)
	_meny_meddelande = Tr.t("ui.meny.nusparad", "sparat — fortsätt på våning %d") % (run.floor_index + 1)
	_visa_meny()

## Återupptar den sparade körningen. Samma start som `-- våning`, men med hp, xp och leken ur
## sparfilen: `_start_run` bygger leken ur metat, och den sparade leken läggs över EFTERÅT (den bär
## köp, kortval och uppgraderingar som metat inte känner till).
func _fortsätt_körning() -> void:
	if meta.korning.is_empty():
		return
	var k := meta.korning
	var stage_id := str(k.get("stage", "stage_01"))
	if stages.get(stage_id) == null:
		push_error("sparfilen pekar på en okänd bana: %s" % stage_id)
		return
	_dölj_meny()
	_start_run(stage_id, int(k.get("seed", 20260919)), int(k.get("floor", 0)))
	var ids: Array = k.get("deck", [])
	if ids.size() > 0:
		run.deck = Cards.make_pile(db, ids)
	run.max_hp = float(k.get("max_hp", run.max_hp))
	run.hp = clampf(float(k.get("hp", run.hp)), 1.0, run.max_hp)
	run.xp = int(k.get("xp", 0))
	_refresh()
	print("fortsätter körningen: %s våning %d, %d kort i leken, HP %.0f/%.0f"
		% [stage_id, run.floor_index + 1, run.deck.size(), run.hp, run.max_hp])

## Sparar körningen så LADDA SPEL har något att ladda. Skrivs bara när något faktiskt ändrats: en
## signatur av bana, våning, hp, xp och lekens innehåll. Utan den skrev spelet sparfilen varje gång
## HUD:en ritades om (55 gånger i sekunden under en strid).
var _sparad_signatur := ""
## Kvittensen från SPARA SPEL i menyn ("sparat — fortsätt på våning 3"). Tom tills man sparar, och
## nollställd när menyn göms — annars står den kvar och påstår något om en körning man lämnat.
var _meny_meddelande := ""

## `tvinga`: skriv filen även när inget ändrats sedan förra sparningen. Menyns SPARA SPEL behöver det
## — signaturen finns för att HUD:en inte ska skriva 55 filer i sekunden, inte för att hindra en
## människa som trycker på en knapp.
func _spara_körning(tvinga := false) -> void:
	if run == null:
		return
	if run.finished:
		# Körningen är slut: då finns inget att fortsätta, och raden i menyn ska vara mörk igen.
		if meta.korning.is_empty() and _sparad_signatur == "slut":
			return
		_sparad_signatur = "slut"
		meta.korning = {}
		meta.save()
		return
	var ids := []
	for c in run.deck:
		ids.append(str(c.id))
	var sig := "%s|%d|%.1f|%d|%d|%d" % [run.stage.id, run.floor_index, run.hp, run.xp,
		ids.size(), hash(",".join(ids))]
	if sig == _sparad_signatur and not tvinga:
		return
	_sparad_signatur = sig
	meta.korning = {"stage": run.stage.id, "seed": run.seed_value, "floor": run.floor_index,
		"hp": run.hp, "max_hp": run.max_hp, "xp": run.xp, "deck": ids}
	if not meta.save():
		push_warning("kunde inte spara körningen: %s" % meta.last_error)

## --- ALTERNATIV (M39) -------------------------------------------------------------------------

func _visa_alternativ() -> void:
	alt_index = 0
	alt_panel.visible = true
	_rita_alternativ()
	_placera_alt()

func _rita_alternativ() -> void:
	var på := Tr.t("ui.alternativ.pa", "på")
	var av := Tr.t("ui.alternativ.av", "av")
	alt_label.text = Tr.t("ui.alternativ.titel", "ALTERNATIV")
	var texter := [
		Tr.t("ui.alternativ.sprak", "språk: %s") % Tr.name_of_code(Tr.lang),
		Tr.t("ui.alternativ.crt", "CRT-läge: %s") % (på if crt.är_på() else av),
		Tr.t("ui.alternativ.musik", "musik: %s") % (på if meta.musik_på else av),
		# Jukeboxen (M54). Spåret står med namn, och raden byter låt — menyns musik spelar ju redan,
		# så en ändring hörs direkt i stället för att sparas till senare.
		Tr.t("ui.alternativ.spar", "spår: %s") % (musik.nuvarande() if musik != null else ""),
	]
	for i in alt_rader.size():
		alt_rader[i].text = "%s %s" % ["▶" if i == alt_index else "  ", str(texter[i])]
		alt_rader[i].add_theme_color_override("font_color",
			Color(0.98, 0.76, 0.36) if i == alt_index else Color(0.80, 0.80, 0.84))
	_placera_alt()

## Raden som är vald byter värde. Samma funktion för tangenten och för klicket.
func _alt_byt(i: int) -> void:
	match i:
		0:
			_cycle_language()
		1:
			meta.crt_på = not meta.crt_på
			crt.sätt_på(meta.crt_på)
			meta.save()
		2:
			meta.musik_på = not meta.musik_på
			if meta.musik_på and musik.stream != null and not musik.playing:
				musik.play()
			elif not meta.musik_på and musik.playing:
				musik.stop()
			meta.save()
		3:
			# Nästa spår i spellistan. Alla sju (eller fler) ligger i mappen, så raden räknar upp
			# och lägger sig i ringen: den sista går till den första.
			musik.nästa()
			if not meta.musik_på:
				meta.musik_på = true
				meta.save()
	_rita_alternativ()

func _alternativ_tangent(key: int) -> void:
	if key == KEY_ESCAPE:
		alt_panel.visible = false
		_visa_meny()               # tillbaka till menyn, med samma val som förut
		return
	if key == KEY_UP or key == KEY_W:
		alt_index = wrapi(alt_index - 1, 0, alt_rader.size())
		_rita_alternativ()
	elif key == KEY_DOWN or key == KEY_S:
		alt_index = wrapi(alt_index + 1, 0, alt_rader.size())
		_rita_alternativ()
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE \
			or key == KEY_LEFT or key == KEY_RIGHT:
		_alt_byt(alt_index)

## Panelen centreras i FÖNSTRET. `_place_panel` hör till panelerna inne i spelvyn (480x270) och
## räknar i vyns mått — den här panelen är ett barn till `_runt` och hamnade därför uppe till vänster
## (mätt på skärmbild: panelen låg på 150,100 i stället för i mitten).
func _placera_alt() -> void:
	if alt_panel == null or not is_instance_valid(alt_panel):
		return
	var s := alt_panel.get_combined_minimum_size()
	alt_panel.size = s
	var ruta := get_viewport().get_visible_rect().size
	# Under menyraderna i stället för mitt på skärmen: centrerad hamnade panelen över logotypen och
	# över de två översta menyvalen (mätt på skärmbild), och "ALTERNATIV" stod två gånger under varandra.
	var y := (ruta.y - s.y) * 0.5
	if meny != null and not meny.rader.is_empty():
		var sista: Label = meny.rader[meny.rader.size() - 1]
		y = sista.position.y + sista.size.y + 28.0
		if y + s.y > ruta.y - 56.0:
			y = maxf(8.0, ruta.y - 56.0 - s.y)
	alt_panel.position = Vector2(((ruta.x - s.x) * 0.5), y).floor()

func _alt_peka(i: int) -> void:
	if i != alt_index:
		alt_index = i
		_rita_alternativ()

func _alt_klick(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		alt_index = i
		_alt_byt(i)

## Provet för menyn (M39): fotograferar den, mäter raderna och märket, flyttar valet med tangentbordet,
## KLICKAR på en rad med musen (samma väg som spelaren: ett riktigt musklick in i fönstret) och
## fotograferar ALTERNATIV. Mätt, inte tyckt — menyn är den första ytan spelaren möter.
func _demo_meny() -> void:
	await get_tree().create_timer(1.2).timeout      # bakgrundsbilden och shadern hinner ritas
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_placera_meny()
	print("menyprov: %d val, valt %d, menyn syns: %s, musiken: %s" % [meny.rader.size(),
		meny.valt_index, "ja" if meny.visible else "nej",
		"spelar %.1f s in" % musik.get_playback_position() if musik.playing else "tyst"])
	for i in meny.rader.size():
		print("menyprov: rad %d \"%s\" @ %.0f,%.0f (%.0fx%.0f)"
			% [i, meny.rader[i].text, meny.rader[i].position.x, meny.rader[i].position.y,
				meny.rader[i].size.x, meny.rader[i].size.y])
	print("menyprov: märket @ %.0f,%.0f (%s), botten: %s" % [meny.markör.position.x,
		meny.markör.position.y, "syns" if meny.markör.visible else "gömt",
		meny.botten.text.replace("\n", " | ")])
	print("menyprov: splashen %.0fx%.0f, CRT: %s (styrka %.2f)" % [meny.splash.size.x,
		meny.splash.size.y, "på" if crt.är_på() else "av", crt.styrka()])
	_spara_bild("user://shots/meny.png")
	# Märket ska stå vid den VALDA raden: flytta valet och se att det följer med.
	var före := meny.markör.position.y
	_meny_tangent(KEY_DOWN)
	await get_tree().process_frame
	print("menyprov: Enter ned -> valt %d, märket flyttade %.0f px (rad %d ligger på y %.0f)"
		% [meny.valt_index, meny.markör.position.y - före, meny.valt_index,
			meny.rader[meny.valt_index].position.y])
	_meny_tangent(KEY_UP)
	await get_tree().process_frame
	# KLICKET på sista raden (AVSLUTA hade avslutat spelet — provet klickar i stället på
	# ALTERNATIV, rad 2, och ser att panelen kommer upp).
	var rad: Label = meny.rader[2]
	var mitten: Vector2 = rad.get_global_rect().get_center()
	var ned := InputEventMouseButton.new()
	ned.button_index = MOUSE_BUTTON_LEFT
	ned.pressed = true
	ned.position = mitten
	ned.global_position = mitten
	get_window().push_input(ned)
	await get_tree().process_frame
	await get_tree().process_frame
	var lyft := InputEventMouseButton.new()
	lyft.button_index = MOUSE_BUTTON_LEFT
	lyft.position = mitten
	lyft.global_position = mitten
	get_window().push_input(lyft)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	print("menyprov: klick på rad 2 @ %.0f,%.0f -> alternativen syns: %s"
		% [mitten.x, mitten.y, "ja" if alt_panel.visible else "nej"])
	for i in alt_rader.size():
		print("menyprov: alternativ %d \"%s\"" % [i, alt_rader[i].text])
	_spara_bild("user://shots/meny-alternativ.png")
	# Byt CRT-läget och se att lagret faktiskt slås av (inte bara texten i raden).
	var var_på := crt.är_på()
	_alt_byt(1)
	await get_tree().create_timer(0.3).timeout
	print("menyprov: CRT-raden bytte läge: %s -> %s (lagret syns: %s)"
		% ["på" if var_på else "av", "på" if crt.är_på() else "av",
			"ja" if crt.visible else "nej"])
	_spara_bild("user://shots/meny-crt-av.png")
	_alt_byt(1)
	await get_tree().create_timer(0.3).timeout
	print("menyprov: bilderna i %s" % ProjectSettings.globalize_path("user://shots"))
	get_tree().quit()

## Provet för HUD:ens rutor (M40) i ett RIKTIGT fönster: provet i tests/test_gui.gd mäter logiken
## huvudlöst, men där är fönstret 64x64 och vyn ryms inte — layouten (rutorna i marginalen, inga
## krockar) går bara att mäta med ett fönster som rymmer 1280x720. Provet fyller också loggen och
## fienderutan så att bilden visar något och inte bara tomma plåtar.
func _demo_gui() -> void:
	_start_run("stage_01", 20260919)
	await get_tree().process_frame
	# Gå fram till en strid: kartan läggs i ordning, så provet letar upp en oavklarad nod i stället för
	# att gissa var spelaren står (utan en strid fylls varken loggen eller fienderutan).
	var nod: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if not n.cleared and (n.kind == "encounter" or n.kind == "boss"):
			nod = n
			break
	if nod != null:
		run.explore.pos = nod.pos
		run.explore.facing = 0
		_enter_node_here()
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout          # shaders och 3D:n hinner ritas
	_placera_vy()
	var f := get_viewport().get_visible_rect().size
	var vy := Rect2(_vy_korg.position, Vector2(VY) * _vy_korg.scale.x)
	print("guiprov: fönstret %.0fx%.0f, spelvyn %s (skala x%.0f)" % [f.x, f.y, str(vy), _vy_korg.scale.x])
	print("guiprov: status %s | logg %s" % [str(Rect2(hud_status.position, hud_status.size)),
		str(Rect2(hud_logg.position, hud_logg.size))])
	var sp := Rect2(battle_panel.global_position, battle_panel.size)
	var ht := Rect2(hint_label.global_position, hint_label.size)
	print("guiprov: tipsraden syns %s, text '%s', global %s, storlek %s" % [
		"ja" if hint_label.visible else "nej", hint_label.text.substr(0, 40), str(ht.position), str(ht.size)])
	print("guiprov: stridspanelen %s i fönstret (%.0f px innanför spelvyn), tipsraden %s, krock %s"
		% [str(sp), sp.intersection(vy).get_area(), str(ht), "JA" if sp.intersects(ht) else "nej"])
	for n in [["status", hud_status], ["logg", hud_logg]]:
		var r := Rect2((n[1] as Control).position, (n[1] as Control).size)
		var över_vy := r.intersection(vy).get_area()
		print("guiprov: %s ritar %.0f px innanför spelvyn (ska vara 0), ligger i %s"
			% [n[0], över_vy, "övre marginalen" if r.end.y <= vy.position.y
				else ("nedre marginalen" if r.position.y >= vy.end.y else "ÖVER VYN")])
	print("guiprov: statusrad %s | kärl hp %.2f, mana %.2f, rust %.2f, syns %s" % [
		hud_status.vital_label.text, orb_hp.nivå(), orb_mana.nivå(), rust_bar.andel(),
		str([orb_hp.visible, orb_mana.visible, rust_bar.visible])])
	# Kärlens och högarnas rutor i klartext: en kärl som ligger över en hög syns bara på bild, och det
	# var precis vad den gjorde (M51).
	for par in [["hp-kärl", orb_hp], ["mana-kärl", orb_mana], ["rust-rad", rust_bar],
			["draghög", hog_drag], ["slänghög", hog_använd], ["korträknare", kort_label]]:
		var n: Control = par[1]
		var txt := ""
		if par[0] == "korträknare" and kort_label != null:
			txt = "  text '%s'" % kort_label.text
		print("guiprov: %s %s syns %s%s" % [par[0], str(n.get_rect()) if n != null else "-",
			str(n.visible) if n != null else "-", txt])
	# BILD 1: hela HUD:en med en LEVANDE fiende (fienderutan syns bara då).
	print("guiprov: strid %s, fiender %d, mål %s" % ["ja" if active_combat != null else "nej",
		active_combat.enemies.size() if active_combat != null else 0, str(_fiende_data(true).get("namn", "-"))])
	_spara_bild("user://shots/gui.png")
	# BILD 2: loggen fylld — spela några kort och avsluta en tur, och se att raderna kommer i ordning.
	hud_logg.töm()
	for i in 2:
		if active_combat != null and not active_combat.over():
			await _on_card(0)
			await get_tree().create_timer(0.2).timeout
	if active_combat != null and not active_combat.over():
		_on_end_turn()
		await get_tree().create_timer(1.2).timeout
	print("guiprov: loggen har %d rader: %s" % [hud_logg.innehåll().size(), str(hud_logg.innehåll())])
	_spara_bild("user://shots/gui-logg.png")
	print("guiprov: bilderna i %s" % ProjectSettings.globalize_path("user://shots"))
	get_tree().quit()

## VINSTPROVET: spelar en hel strid till slutet med spelets EGNA vägar (kort, tur-slut), låter
## `finish_fight()` sätta upp kortvalet och fotograferar FÖRE och EFTER ett klick.
##
## Alex: *"När man får välja kort vid vinst/level up så verkar kortet flytta på sig till vänster, och
## täcker över det som låg där innan, och går inte att flytta på."* Det kortvalsprov som fanns byggde
## valet på en påtvingad nivå mitt i lugnet, utan strid — och där fanns ingen strid, inga spelade kort
## och ingen hög att landa i, så det kunde inte se felet. Det här provet går vägen han går.
##
## Provet skriver ut VARJE synlig kortvy i trädet med sin ruta och sin alfa: ett kort som flugit och
## blivit kvar står kvar i listan med sitt läge, och det är den raden som visar felet.
func _demo_vinst() -> void:
	_start_run("stage_01", 20260919)
	await get_tree().process_frame
	var nod: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes:
		if not n.cleared and (n.kind == "encounter" or n.kind == "boss"):
			nod = n
			break
	if nod == null:
		print("vinstprov: ingen strid att spela")
		get_tree().quit()
		return
	run.explore.pos = nod.pos
	run.explore.facing = 0
	_enter_node_here()
	await get_tree().process_frame
	print("vinstprov: striden börjar, %d fiender, hp %.0f" % [active_combat.enemies.size(),
		active_combat.hp])
	# MID-STRID: slå ut den första fienden medan handen ligger kvar nedtill. XP-tröskeln sätts ett steg
	# under, så dråpet tippar över nivån. Det är så valet möter spelaren — och det var där Alex såg
	# felet: panelen och handen ligger på samma plats.
	run.xp = Progress.xp_total(run.level + 1) - 1
	active_combat.enemies[0].hp = 1.0
	# ETT kort, inte hela striden: handen ska ligga kvar nedtill när valet kommer (det är där felet
	# syns), så provet spelar ett kort och stannar.
	if not active_combat.hand.is_empty():
		await _on_card(0)
	await get_tree().create_timer(0.5).timeout
	print("vinstprov: efter ett spelat kort — hand %d, handvyer %d, val syns %s" % [
		active_combat.hand.size() if active_combat != null else -1, hand_views.size(),
		"ja" if draft_panel.visible else "nej"])
	run.xp = Progress.xp_total(run.level + 1)
	run._check_level()
	_refresh()
	_show_draft()
	await get_tree().create_timer(0.4).timeout
	# KROCKEN: valets ruta mot handens. Ligger de över varandra är det felet Alex beskriver — kortet
	# han väljer ligger då ovanpå korten han redan håller, och inget av dem går att flytta.
	# Båda ligger i FÖNSTRETS yta (`_runt`), så rutorna jämförs som de är.
	var vr := Rect2(draft_panel.global_position, draft_panel.size)
	var handkrock := 0.0
	for v in hand_views:
		if is_instance_valid(v) and v.is_visible_in_tree():
			handkrock = maxf(handkrock, vr.intersection(
				Rect2(v.global_position, v.size * v.scale)).get_area())
	print("vinstprov: valpanelen %s mot handen — krock %.0f px" % [str(vr), handkrock])
	print("vinstprov: hand_views har %d poster, %d av dem är frigjorda" % [hand_views.size(),
		hand_views.filter(func(v): return not is_instance_valid(v)).size()])
	for i in hand_views.size():
		var v = hand_views[i]
		if not is_instance_valid(v):
			print("vinstprov:   post %d är FRIGJORD" % i)
			continue
		var kr := Rect2(v.global_position, v.size * v.scale)
		print("vinstprov:   handkort %d %s — krock med valet %.0f px" % [v.index, str(kr),
			vr.intersection(kr).get_area()])
	# HOVRINGEN, MÄTT: pekaren in över ett valkort ska LYFTA det (storleken växer uppåt från samma
	# underkant), inte flytta det i sidled. Delta i x är felet Alex ser — kortet hamnade i containerns
	# övre vänstra hörn, över grannen.
	var valkort: Array = []
	for barn in draft_box.get_children():
		if barn is CardView:
			valkort.append(barn)
	if not valkort.is_empty():
		var mål: CardView = valkort[valkort.size() / 2]
		var x_före: float = mål.position.x
		var y_före: float = mål.position.y
		var w_före: float = mål.size.x
		var mitt: Vector2 = mål.get_global_rect().get_center()   # valets kort ligger i fönstret
		Input.warp_mouse(mitt)
		await get_tree().create_timer(0.8).timeout
		print("vinstprov: pekaren över valkort %d — x %.0f -> %.0f, y %.0f -> %.0f, bredd %.0f -> %.0f, home_pos %s" % [
			mål.index, x_före, mål.position.x, y_före, mål.position.y, w_före, mål.size.x,
			str(mål.home_pos)])
		_spara_bild("user://shots/vinst-pekare.png")
		_kortvyer("efter pekaren")
		# Vem äger rutan med kortets text som syntes i granskningen? Leta efter texten i trädet.
		for n in _alla_barn(get_tree().root):
			var l := n as Control
			if l == null or not l.is_visible_in_tree():
				continue
			var txt := ""
			if n is Label:
				txt = (n as Label).text
			elif n is RichTextLabel:
				txt = (n as RichTextLabel).text
			if txt.contains("rustning") or txt.contains("Ash Veil"):
				print("vinstprov:   textruta %s '%s' @ %s (%.0fx%.0f) i %s" % [n.name, txt.replace("\n", " | "),
					str(l.global_position.round()), l.size.x, l.size.y, l.get_parent().name])
	print("vinstprov: striden över: %s (hp %.0f), valet syns: %s med %d val" % [
		"ja" if active_combat != null and active_combat.over() else "nej", run.hp,
		"ja" if draft_panel.visible else "nej", run.pending_draft().size()])
	await get_tree().create_timer(1.0).timeout
	_spara_bild("user://shots/vinst-fore.png")
	_kortvyer("före valet")
	# KLICKET: samma väg som en riktig mus (pekaren flyttas till kortets mitt i FÖNSTRET och klicket
	# skickas till fönstret, inte till funktionen tangenten använder).
	var val: Array = draft_panel.get_children()
	var sista: CardView = null
	for barn in draft_box.get_children():
		if barn is CardView:
			sista = (barn as CardView)
	if sista != null:
		var mitten: Vector2 = sista.get_global_rect().get_center()   # valets kort ligger i fönstret
		Input.warp_mouse(mitten)
		await get_tree().process_frame
		var ned := InputEventMouseButton.new()
		ned.button_index = MOUSE_BUTTON_LEFT
		ned.pressed = true
		ned.position = mitten
		ned.global_position = mitten
		get_window().push_input(ned)
		await get_tree().process_frame
		var lyft := InputEventMouseButton.new()
		lyft.button_index = MOUSE_BUTTON_LEFT
		lyft.position = mitten
		lyft.global_position = mitten
		get_window().push_input(lyft)
		print("vinstprov: klickade på kort %d i fönstret %.0f,%.0f — valet kvar: %d"
			% [sista.index, mitten.x, mitten.y, run.pending_draft().size()])
	await get_tree().create_timer(1.2).timeout
	_spara_bild("user://shots/vinst-efter.png")
	_kortvyer("efter valet")
	print("vinstprov: bilderna i %s" % ProjectSettings.globalize_path("user://shots"))
	get_tree().quit()

## En ruta i valets koordinater (vyn) omräknad till fönstrets px.
func _i_fönstret(r: Rect2) -> Rect2:
	var t := _vy.get_screen_transform()
	var a: Vector2 = t * r.position
	var b: Vector2 = t * r.end
	return Rect2(a, b - a)

## Varje SYNLIG kortvy i trädet, med ruta och alfa. Ett kort som flugit och blivit kvar syns här.
func _kortvyer(vad: String) -> void:
	print("vinstprov: kortvyer %s —" % vad)
	for n in _alla_barn(get_tree().root):
		var v := n as CardView
		if v == null or not v.is_visible_in_tree():
			continue
		print("vinstprov:   %s @ %s (%.0fx%.0f) alfa %.2f i %s" % [v.name, str(v.global_position.round()),
			v.size.x * v.scale.x, v.size.y * v.scale.y, v.modulate.a, v.get_parent().name])

func _alla_barn(n: Node) -> Array:
	var ut := [n]
	for b in n.get_children():
		ut.append_array(_alla_barn(b))
	return ut

func _build_empty_view() -> void:
	if cam != null:
		return
	world = Node3D.new()
	# Världen ritas i SPELVYN (480x270), inte i fönstret: det är den som ska vara pixelkonst.
	_vy.add_child(world)
	cam = Camera3D.new()
	cam.position = Vector3(0.0, 0.55, 0.0)
	world.add_child(cam)

## Tangenterna i skalet. Egen väg in i stället för att hänga på körningens: en meny som delar
## tangentbord med spelet bakom sig tappar en tangent så fort någon lägger till en i spelet.
func _input_shell(key: int) -> void:
	if shell == "album":
		match key:
			KEY_LEFT, KEY_A:
				_album_välj(album_index - 1)
			KEY_RIGHT, KEY_D:
				_album_välj(album_index + 1)
			KEY_I, KEY_ESCAPE:
				_på_plats("hem")
		return
	if shell == "hem":
		# Byn: markeringen flyttas mellan platserna, Enter går in. Siffrorna 1-4 är borta — en meny
		# med två vägar in (markering och siffra) har två ställen att hålla i synk, och bara en av
		# dem syns i bild.
		match key:
			KEY_LEFT, KEY_A:
				by_view.flytta(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				by_view.flytta(Vector2i(1, 0))
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				by_view.gå_in()          # valet kommer tillbaka via signalen vald -> _på_plats
			KEY_I:
				_på_plats("album")       # indexet över samlingen. A/D är upptagna av platsvalet.
			KEY_Q:
				get_tree().quit()
	elif shell == "butik":
		if key >= KEY_1 and key <= KEY_9:
			_buy(key - KEY_0)
			meta.save()
		elif key == KEY_ESCAPE:
			shell = "hem"
	elif shell == "vardshus":
		# Piltangenter (och W/S/A/D) väljer, Enter hyr det valda, siffrorna hyr direkt. Ett klick
		# gör samma sak: ett tryck väljer, ett tryck på det redan valda hyr.
		match key:
			KEY_LEFT, KEY_A, KEY_UP, KEY_W:
				_inn_välj(inn_index - 1)
			KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
				_inn_välj(inn_index + 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_hire(inn_index + 1)
				_show_inn()
			KEY_ESCAPE:
				shell = "hem"
			_:
				if key >= KEY_1 and key <= KEY_9:
					inn_index = key - KEY_1
					_hire(key - KEY_0)
					_show_inn()
	elif shell == "smed":
		match key:
			KEY_LEFT, KEY_A:
				_smed_vald = (_smed_vald - 1 + maxi(1, meta.branches().size())) % maxi(1, meta.branches().size())
			KEY_RIGHT, KEY_D:
				_smed_vald = (_smed_vald + 1) % maxi(1, meta.branches().size())
			KEY_ESCAPE:
				shell = "hem"
			_:
				if key >= KEY_1 and key <= KEY_9:
					_buy_node(key - KEY_0)
	elif shell == "juvelerare":
		# Piltangenter väljer KORT (← →) och STEN i fickan (W/S), siffrorna 1-4 tar ett fack, och
		# Enter gör det valet pekar på: öppnar facket, sätter stenen eller plockar ur den.
		var lek := _start_lek()
		match key:
			KEY_LEFT, KEY_A:
				jewel_kort = wrapi(jewel_kort - 1, 0, maxi(1, lek.size()))
				_show_jewel()
			KEY_RIGHT, KEY_D:
				jewel_kort = wrapi(jewel_kort + 1, 0, maxi(1, lek.size()))
				_show_jewel()
			KEY_UP, KEY_W:
				var f := meta.gem_bag()
				if not f.is_empty():
					jewel_sten = wrapi(jewel_sten - 1, 0, f.size())
				_show_jewel()
			KEY_DOWN, KEY_S:
				var f := meta.gem_bag()
				if not f.is_empty():
					jewel_sten = wrapi(jewel_sten + 1, 0, f.size())
				_show_jewel()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_jewel_enter()
				_show_jewel()
			KEY_ESCAPE:
				shell = "hem"
			_:
				if key >= KEY_1 and key <= KEY_4:
					jewel_fack = key - KEY_1
					_show_jewel()
	elif shell == "banverkstad":
		# ← → byter bana, W/↑ och ↓ byter fält, + och − rattar, S skriver filen och Esc går tillbaka
		# till kartan man kom ifrån. Att skriva är en egen tangent (S) så man kan ångra sig med Esc.
		match key:
			KEY_LEFT, KEY_A:
				_verk_stage = wrapi(_verk_stage - 1, 0, maxi(1, _stage_order.size()))
				_verk_rad = ""
				_show_verkstad()
			KEY_RIGHT, KEY_D:
				_verk_stage = wrapi(_verk_stage + 1, 0, maxi(1, _stage_order.size()))
				_verk_rad = ""
				_show_verkstad()
			KEY_UP, KEY_W:
				_verk_fält = wrapi(_verk_fält - 1, 0, Stages.FÄLT.size())
				_show_verkstad()
			KEY_DOWN:
				_verk_fält = wrapi(_verk_fält + 1, 0, Stages.FÄLT.size())
				_show_verkstad()
			KEY_S:
				_verk_spara()
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				_verk_ändra(1.0)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_verk_ändra(-1.0)
			KEY_ESCAPE:
				shell = "karta"
	elif shell == "karta":
		# `true` = körningen tog över (en nivå valdes); då ritar _start_run om skalet själv.
		if _karta_tangent(key):
			return
	_refresh_shell()

## Tangenterna på kartan, i två lager: nivåpanelen äger upp/ner och Enter när den är öppen (då väljer
## man nivå), annars flyttar pilarna markeringen. E = kart-editorn, och i den sparar S — S är annars
## "ner", så editorn tar S medan den är på.
func _karta_tangent(key: int) -> bool:
	if karta_view.editor:
		match key:
			KEY_LEFT, KEY_A:
				karta_view.flytta(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				karta_view.flytta(Vector2i(1, 0))
			KEY_UP, KEY_W:
				karta_view.flytta(Vector2i(0, -1))
			KEY_DOWN:
				karta_view.flytta(Vector2i(0, 1))
			KEY_S:
				print("kartan: %s" % Tr.t("ui.map.saved", "kartan sparad") if karta_view.skriv_karta()
					else "kartan: %s" % Tr.t("ui.map.save_failed", "kunde inte skriva kartan"))
			KEY_N:
				# Alex' editor: nivån panelen står på flyttas till en NY plats på kartan. Sedan
				# flyttar pilarna den — och S skriver filen. Fler banor = fler noder.
				if karta_view.ny_plats_för_vald():
					print("kartan: ny plats till %s" % karta_view.nod_text(karta_view.nivå_vald()))
			KEY_E, KEY_ESCAPE:
				karta_view.editor = false
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				# Sektionen är kartans grind — i editorn flyttas den valda noden mellan sektioner.
				karta_view.sätt_sektion(key - KEY_1 + 1)
		return false
	match key:
		KEY_E:
			karta_view.editor = true
		KEY_B:
			# BANVERKSTADEN (M60): banorna bakom kartan. `false` = skalet ritar om själv, så panelen
			# kommer upp utan en egen refresh-väg.
			var nodens: Array = karta_view.nivåer(karta_view.valt_index())
			_verk_stage = maxi(0, _stage_order.find(str(nodens[0]) if not nodens.is_empty() else ""))
			_verk_rad = ""
			shell = "banverkstad"
		KEY_UP, KEY_W:
			if not karta_view.flytta_nivå(-1):
				karta_view.flytta(Vector2i(0, -1))
		KEY_DOWN, KEY_S:
			if not karta_view.flytta_nivå(1):
				karta_view.flytta(Vector2i(0, 1))
		KEY_LEFT, KEY_A:
			karta_view.flytta(Vector2i(-1, 0))
		KEY_RIGHT, KEY_D:
			karta_view.flytta(Vector2i(1, 0))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var r := karta_view.försök_gå_in()
			if bool(r["ok"]):
				return true     # körningen tar över; _start_run ritar om skalet själv
			if str(r["reason"]) == "välj":
				_sfx("select")  # nivåpanelen öppnades: ett steg, inte ett fel
				return false
			# Låst plats eller låst nivå: säg ifrån i klartext (raden ritas på kartan) i stället för
			# att tiga — en tangent som inte gör något ser trasig ut.
			_sfx("hit")
			print("kartan: %s" % r["text"])
		KEY_ESCAPE:
			if karta_view.panel_öppen():
				karta_view.stäng_panel()
			else:
				shell = "hem"
	return false

## Noden med första upplåsta banan — kartan ska öppna sig där spelaren faktiskt kan spela, inte på
## plats 1 när plats 1 redan är klar. Kartan har en NOD per plats (10) med upp till tio banor var,
## så indexet är nodens, inte banans: 40 banor är inte 40 noder längre.
func _first_playable() -> int:
	if karta == null:
		return 0
	# Sektionen är grinden (core/karta.gd): markeringen ska stå på första platsen i en ÖPPEN sektion som
	# har något ospelat kvar, inte på banan som råkade låsas upp sist.
	var första := -1
	for i in karta.antal():
		if not karta.sektion_öppen(karta.sektion(i), meta):
			continue
		if första < 0:
			första = i
		for id in karta.nivåer(i):
			if not Karta.klarad(str(id), stages, meta):
				return i
	return maxi(0, första)

## Vilken nod på kartan som bär en bana. -1 = ingen (en bana utanför kartfilen ska inte flytta
## markeringen till plats 1 i tysthet).
func _nod_för(stage_id: String) -> int:
	if karta == null:
		return -1
	for i in karta.antal():
		if karta.nivåer(i).has(stage_id):
			return i
	return -1

## Fotografera skalet: byn, butiken, kartan och en låst bana. Samma väg som tangenterna tar, så
## bilden är ett bevis på att skärmen går att NÅ — inte bara att den finns i koden.
func _demo_shell() -> void:
	var dir := "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	_show_home()
	await get_tree().create_timer(0.4).timeout
	var n := await _shot(dir, 0, "by")
	shell = "butik"
	_refresh_shell()
	await get_tree().create_timer(0.3).timeout
	n = await _shot(dir, n, "butik")
	karta_view.gå_till(_first_playable())
	shell = "karta"
	_refresh_shell()
	await get_tree().create_timer(0.3).timeout
	n = await _shot(dir, n, "karta")
	shell = "vardshus"
	_refresh_shell()
	await get_tree().create_timer(0.3).timeout
	n = await _shot(dir, n, "vardshus")
	shell = "smed"
	_refresh_shell()
	await get_tree().create_timer(0.3).timeout
	n = await _shot(dir, n, "smed")
	# Sista PLATSEN (låst) fotograferas MED sitt besked: annars ser en låst plats bara ut som en mörk
	# medaljong, och raden som säger varför syns aldrig på bild.
	var sista := karta.antal() - 1
	karta_view.gå_till(sista)
	if not bool(karta_view.stanna()["ok"]):
		karta_view.försök_gå_in(sista)      # låst: ger beskedet i klartext, sänder ingenting
	shell = "karta"
	_refresh_shell()
	await get_tree().create_timer(0.3).timeout
	n = await _shot(dir, n, "karta-last")
	# Nivåvalet fotograferas också: panelen är den nya delen av kartan (upp till tio nivåer per plats),
	# och en panel som bara finns i koden är en panel ingen har sett.
	karta_view.gå_till(_first_playable())
	karta_view.försök_gå_in()
	await get_tree().create_timer(0.2).timeout
	n = await _shot(dir, n, "karta-niva")
	print("skalets skärmar: %d bilder i %s" % [n, ProjectSettings.globalize_path(dir)])
	get_tree().quit()

## Byns radlista. `läge` styr titel och sista rad: från slutskärmen går R till en ny körning, från
## byn går Esc tillbaka. En tangent som inte gör något får inte stå i gränssnittet.
## Butikens radlista. Slutskärmen visar den inte längre (M48) — den hör till byn, och `läge` har bara
## ett värde kvar: butiksvyn.
func _village_text(läge: String = "by") -> String:
	var titel := Tr.t("ui.shop.title", "BUTIKEN — guld i banken: %d") if läge == "by" \
		else Tr.t("ui.village.title", "BYN — guld i banken: %d")
	var rader := [titel % meta.gold]
	var linjer := meta.village_lines()
	rader.append(Tr.t("ui.shop.hint", "1-%d = köp · Esc = tillbaka till byn") % linjer.size())
	for v in linjer:
		var pris := Tr.t("ui.village.maxed", "FULL") if int(v["cost"]) < 0 else Tr.t("ui.village.price", "%d guld") % int(v["cost"])
		# OK = man har RÅD, X = man har inte råd. Priset stod här förut, men svaret på frågan "har
		# jag råd?" gick bara att få genom att jämföra talet med saldot högst upp — Alex: *"det är
		# omöjligt att veta om man har råd eller ej."* Talet är samma `affordable` som köpet själv
		# prövar, så märket kan inte säga något annat än köpet gör.
		#
		# BOKSTÄVER, INTE BOCKAR: första försöket använde ✓/✗, och granskningen av skärmbilden läste
		# dem som ett multiplikationstecken — pixeltypsnittet har inte de glyferna (kartans bock är
		# RITAD, inte skriven). OK och X finns i varje typsnitt och betyder samma sak på alla språk,
		# så märket behöver inte in i de tretton språkfilerna.
		rader.append("%s %-13s %d/%d  %s %-9s %s" % [
			v["key"], v["name"], v["rank"], v["max_rank"],
			"OK" if bool(v["affordable"]) else "X", pris, v["text"]])
	# Språkvalet bor i byn så länge det inte finns någon startmeny: samma yta som köpen, en rad.
	rader.append(Tr.t("ui.settings.language_hint", "L = byt språk (%s)") % Tr.name_of_code(Tr.lang))
	return "\n".join(rader)

## Köp uppgradering nummer i (1-baserat) ur byn. Skälet loggas i klartext: en knapp som inte gör
## något ska säga varför, inte tiga.
func _buy(i: int) -> void:
	var linjer := meta.village_lines()
	if i < 1 or i > linjer.size():
		return
	var v: Dictionary = linjer[i - 1]
	var res := meta.buy(str(v["id"]))
	if res.ok:
		_sfx("coin")
		if not meta.save():
			push_warning("kunde inte spara: %s" % meta.last_error)
	else:
		_sfx("hit")
		print("köp nekades: %s (%s)" % [v["name"], res.reason])
	_refresh()

## Fienderna i rummet: en figur per fiende striden kommer att spawna (Run.enemy_count_for — samma
## funktion som begin_fight räknar med, så vyn aldrig visar tre figurer där det blir två).
## Bilden är egen pixelkonst (tools/gen_enemy_art.py): SEX rutor i samma PNG — andas in, andas ut,
## spänner sig, hugger, träffad, död. Fler än två behövdes för att figuren ska kunna BERÄTTA något:
## med två rutor ser man att den rör sig, inte att den tänker hugga.
## Finns det golv åt sidan om rutan? Ett rum är flera rutor brett, en gång är en — och en fiende
## får bara ställas ut i sidled där det finns golv. Provet (test_material) mäter att ingen figur
## står i en vägg.
func _golv_bredvid(p: Vector2i) -> bool:
	if run == null or run.explore == null or run.explore.floor_ref == null:
		return false
	var f: Dungeon.Floor = run.explore.floor_ref
	return f.is_floor_at(p + Vector2i(1, 0)) or f.is_floor_at(p + Vector2i(-1, 0))


func _add_enemies(node: Dungeon.FloorNode, boss: bool) -> void:
	var eid: String = _fiendeprov if not _fiendeprov.is_empty() else str(node.enemy_id).to_lower()
	var tex := _enemy_tex(eid)
	var antal := run.enemy_count_for(node, boss)
	for i in antal:
		var spr := Sprite3D.new()
		spr.texture = tex if tex != null else _tex(NODE_COLORS.get(node.kind, Color.WHITE))
		spr.hframes = ENEMY_FRAMES if tex != null else 1
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.shaded = true                              # lyktan ska lysa på figuren, inte bara på golvet
		# Skär bort genomskinliga pixlar i stället för att blanda dem: en billboard med alfa sorteras
		# mot väggarna efter sitt mitt, och figuren ska klippas in, inte smetas ut.
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		# INGEN `material_override` PÅ EN FIGUR MED RUTNÄT (M69). Mätt med `-- figurprov fienderödfärg`
		# (figuren får en självlysande magenta, allt annat i bilden är oförändrat):
		#
		#   Sprite3D:s EGET material   22 641 magenta px = hela figuren (188 x 427 px i bild)
		#   `material_override`       73 px            = en nål man inte ser
		#
		# Rutan i arket väljs i motorns EGET material, och en override tar bort den vägen — hur arket än
		# läggs in (hela arket, `AtlasTexture` på rutan, `uv1_scale` 1/6) blir det 73 px. Det är precis
		# vad Alex ser: *"spökena står inte vända mot kameran"* — figuren ritas som en remsa i gången.
		# M59:s glans-fix (matt papper i stället för blank wellpapp) får alltså inte kosta figuren; den
		# matta ytan ligger kvar på spaden och rekvisitan, som är enruting och inte har något att tappa.
		# GLANSEN (M72): deklareras HÄR, före förgreningen — ett `var` inne i else-grenen är osynligt
		# för `_enemies.append` längre ned (block-scope i GDScript).
		var glans: Sprite3D = null
		if _fiende_rödfärg:
			spr.modulate = Color(4.0, 0.0, 4.0)      # mätmarkeringen: bara den hör till provet
		else:
			# EGEN LOOK (M70): alfa under 1 måste BLANDA, inte klippas — annars händer ingenting med
			# genomsläppet. Se FIENDE_LOOK för siffrorna och varför det inte är en shader.
			var look: Dictionary = FIENDE_LOOK.get(eid, {})
			var alfa: float = float(look.get("alfa", 1.0))
			var ton: Color = look.get("ton", Color.WHITE)
			if not look.is_empty():
				if alfa < 1.0:
					spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
				spr.modulate = Color(ton.r, ton.g, ton.b, alfa)
				# GLANSEN (M72): aura, våt glans eller metallglint. Den är ett BARN till figuren, så
				# den andas med den — en aura som står still medan varelsen rör sig är fel.
				var gl: Dictionary = look.get("glans", {})
				if not gl.is_empty():
					glans = _glans(gl["färg"], float(gl["storlek"]), float(gl["höjd"]), float(gl["styrka"]))
					spr.add_child(glans)
			# MATERIALET (M73): har fienden en mask läggs ett tunt lager OVANPÅ figuren. Figuren
			# behåller Godots eget material — ett `material_override` på en figur med rutnät är
			# förbjudet sedan M69 (arket trycktes in i quaden och figuren blev en 16 px remsa).
			var lager := _fiende_lager(eid, tex)
			if lager != null:
				lager.pixel_size = spr.pixel_size
				lager.scale = Vector3.ONE * 1.0005     # en hårsmån större, annars z-fightar lagret med figuren
				spr.add_child(lager)
		spr.add_to_group("fiende_figur")
		# Bossen är större än de andra, men måste rymmas under taket. Duken är 120 px (M76) och figuren
		# 96 px: 96 * 0,012 = 1,15 m för en vanlig, 96 * 0,013 = 1,25 m för en boss — exakt samma
		# höjder som 80-duken gav (64 * 0,018 och 64 * 0,0195). Duken växte, inte figuren.
		spr.pixel_size = 0.013 if boss else 0.012
		# SIDLEDET ÄR BORTA (M66). Förskjutningen låg förut i världens x och z, och den är SIDLED så
		# fort spelaren kommer in i rummet från ett annat håll: mätt i figurprov stod två figurer
		# 0,45 m i sidled när spelaren kom från x-hållet (Alex: *"spökena står på sidan när man möter
		# dem, även andra fiender — har det att göra med hur trångt det är i gången?"*). Före
		# striden står de i en liten RING kring sin ruta (lika långt åt alla håll, aldrig in i en
		# striden börjar ställs de upp i kolonn mitt för spelaren, se `_stage_fight`.
		var vinkel := TAU * float(i) / float(maxi(1, antal))
		var dx: float = cos(vinkel) * 0.20
		var dz: float = sin(vinkel) * 0.20
		# Fötterna står på dukens golvrad (100 av 120), alltså 40 px under dukens mitt. Därför är
		# figurens mitt 40 px över golvet — se ENEMY_FEET_PX.
		spr.position = Vector3(node.pos.x + 0.5 + dx, ENEMY_FEET_PX * spr.pixel_size, node.pos.y + 0.5 + dz)
		world.add_child(spr)
		# DROPSHADOWEN: en egen platta på golvet, platt (billboard av, vriden 90 grader), oskuggad och
		# med alfan BLANDAD (en skugga har mjuka kanter). Figuren äger sin x/z — höjden rör den inte.
		var sk := Sprite3D.new()
		sk.texture = _skuggtextur()
		sk.pixel_size = 0.035
		sk.shaded = false
		sk.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sk.rotation.x = -PI * 0.5
		sk.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sk.modulate = Color(SKUGGA_FÄRG, SKUGGA_FÄRG * 0.68, SKUGGA_FÄRG * 0.5, SKUGGA_ALFA)
		sk.scale = Vector3(SKUGGA_BREDD, SKUGGA_BREDD * 0.55, 1.0)
		sk.position = Vector3(spr.position.x, SKUGGA_HÖJD, spr.position.z)
		sk.name = "skugga"
		sk.add_to_group("fiende_skugga")
		world.add_child(sk)
		# Healthbaren: ett tunt streck över huvudet på de fiender man FAKTISKT slåss mot.
		# "16/16" i en textruta är inte samma sak som att se vem som snart faller (Alex: "det finns
		# inget enkelt sätt att se om man attackerar någon som är på väg att dö"). Baren är vänster-
		# ankrad (centered = false) så den krymper från höger, som en riktig stapel.
		var ben := Sprite3D.new()
		ben.texture = _bar_tex()
		ben.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ben.centered = false
		ben.pixel_size = 1.0
		ben.no_depth_test = true
		ben.modulate = Color(0.06, 0.06, 0.09, 0.85)
		ben.scale = Vector3(BAR_W, BAR_H, 1.0)
		ben.visible = false
		world.add_child(ben)
		var fyllnad := Sprite3D.new()
		fyllnad.texture = _bar_tex()
		fyllnad.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fyllnad.centered = false
		fyllnad.pixel_size = 1.0
		fyllnad.no_depth_test = true
		# Den mörka bottenplattan och den färgade fyllningen ligger på samma plats med no_depth_test,
		# så djupbufferten avgör inte vem som hamnar överst (Alex: "deras hälsobar har som en svart
		# overlay över sig"). render_priority 1 lägger fyllningen bevisligen framför plattan.
		fyllnad.render_priority = 1
		fyllnad.scale = Vector3(BAR_W, BAR_H * 0.6, 1.0)
		fyllnad.visible = false
		world.add_child(fyllnad)
		# 25,5 = samma höjd över figurens mitt som förut, räknad i METER: 17 px i 80-duken * 0,018
		# = 0,306 m, och 0,306 / 0,012 = 25,5 px i 120-duken.
		var bartopp := spr.position.y + 25.5 * spr.pixel_size + 0.02
		var barvänster := spr.position.x - BAR_W / 2.0
		ben.position = Vector3(barvänster, bartopp, spr.position.z)
		fyllnad.position = Vector3(barvänster + BAR_W * 0.06, bartopp + BAR_H * 0.2, spr.position.z)
		# hp spåras per figur så träff- och dödsrutan kan väljas: striden har sanningen, figuren
		# minns förra värdet. Indexen matchar — båda byggs ur samma enemy_count_for i samma ordning.
		_enemies.append({"spr": spr, "skugga": sk, "glans": glans, "y": spr.position.y,
			"fas": float(i) * 1.9 + float(node.pos.x),
			"hp": -1.0, "läge": -1, "läge_t": 0.0, "nod": node.pos,
			"bar": ben, "fyllnad": fyllnad})

## En 1x1 vit pixel som skalas till vilken stapel som helst. Ingen ikonfil behövs för en rektangel.
func _bar_tex() -> ImageTexture:
	if _bar_texture == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(img)
	return _bar_texture

## Healthbarerna: bara de fiender som hör till striden man står i visar sin stapel. De andra
## figurerna i våningen har ingen hp att visa, och en stapel över dem vore en gissning.
func _refresh_enemy_bars() -> void:
	var foes: Array = active_combat.enemies if active_combat != null else []
	# Var figurerna står ägs av `_stage_fight` (uppställningen framför spelaren) — den här funktionen
	# rör bara om staplarna SYNS. Två ställen som flyttar samma figur var sitt håll är en bugg som
	# väntar: först rätades de upp här och skrevs sedan över av uppställningen.
	for i in _enemies.size():
		var e: Dictionary = _enemies[i]
		var spr: Sprite3D = e.get("spr")
		var ben: Sprite3D = e.get("bar")
		var fyllnad: Sprite3D = e.get("fyllnad")
		if not is_instance_valid(ben) or not is_instance_valid(fyllnad):
			continue
		var syns: bool = i < foes.size() and e.get("nod") == active_node_pos() \
			and foes[i].max_hp > 0.0
		ben.visible = syns
		fyllnad.visible = syns
		if not syns:
			continue
		var andel: float = clampf(foes[i].hp / foes[i].max_hp, 0.0, 1.0)
		fyllnad.scale = Vector3(BAR_W * 0.88 * andel, BAR_H * 0.6, 1.0)
		# Grön -> gul -> röd. Färgen är den snabbaste läsningen: "den där faller snart".
		fyllnad.modulate = Color(0.45, 0.85, 0.40) if andel > 0.5 else \
			(Color(0.95, 0.75, 0.25) if andel > 0.25 else Color(0.90, 0.30, 0.25))

## Nodens ruta om en strid pågår — striden äger positionen, inte markören.
func active_node_pos() -> Vector2i:
	if active_node != null:
		return active_node.pos
	return Vector2i(-1, -1)

## Fiendefigurernas läge som en rad text: antal och var de står i förhållande till kameran.
## "Ingen fiende syns" och "figuren står bakom dig" är samma bild men två olika fel.
func _enemy_line() -> String:
	if _enemies.is_empty():
		return "fiender 0"
	var bitar := []
	for e in _enemies:
		var spr: Sprite3D = e["spr"]
		if not is_instance_valid(spr):
			continue
		var v := spr.global_position - cam.global_position
		var fram := cam.global_transform.basis.z.dot(v.normalized())
		bitar.append("%.1fm %s" % [v.length(), "framför" if fram < -0.3 else "vid sidan/bakom"])
	return "fiender %d: %s" % [_enemies.size(), ", ".join(bitar)]

## GLANSEN (M72). Aura, våt glans och metallglint är SAMMA sak: en andra quad, additiv, med emission
## ÖVER 1,0 så att den hamnar i HDR och blomstrar — en unshaded yta kan aldrig bli ljusare än vitt
## (mätt i M24: 222 ljusa pixlar efter mot 225 före, ingen glow hade något att arbeta med). Bara
## storlek, färg och höjd skiljer de tre:
##   aura    stor (1,3)      mättad färg  kring midjan  — varelsen lyser av sig själv, styrka 0,8
##   våt     liten (0,8)     vitblå       högt upp      — en glansfläck där ljuset träffar, styrka 1,0
##   metall  liten (0,6-0,7) kall, hård   högt upp      — samma fläck, stramare och kallare, styrka 1,5
##
## MÄTT styrka: 1,5 på en STOR fläck (aura 2,2) gav en utfrätt vit klump — medel 98,8 och 6 049 px
## över 240 i utsnittet kring figuren, och omgivningen drunknade i blomning. Samma 1,5 på en LITEN
## fläck är en glint. Dämpat till 1,3/0,80: medel 69,5 och 207 px över 240 — "en mjuk och naturligt
## avtonande aura/ljusgloria med en varm ton", och gången är fortfarande mörk.
##
## `material_override` är TILLÅTET här och bara här: texturen är en enda ruta, så det finns ingen
## hframes-UV att slå ut. Det var felet i M59, där samma override mosade ett sexrutorsark till en
## 16 px remsa (73 px mot 22 641). En quad med en ruta har inget rutnät att förstöra.
func _glans(färg: Color, storlek: float, höjd: float, styrka: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _skuggtextur()
	s.pixel_size = 0.035
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _skuggtextur()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.emission_enabled = true
	m.emission = färg
	m.emission_energy_multiplier = styrka
	m.disable_receive_shadows = true
	s.material_override = m
	s.scale = Vector3.ONE * storlek
	s.position = Vector3(0.0, höjd, 0.0)
	# Pulsens basvärden: andningen i _process skalar kring DEM, inte kring 1,0 (metallens glint har
	# styrka 2,2 — en puls mot 1,5 hade gjort den svagare än den är still).
	s.set_meta("basstorlek", storlek)
	s.set_meta("basstyrka", styrka)
	s.name = "glans"
	s.add_to_group("fiende_glans")
	return s


## Skuggans form: en mjuk rund fläck. `rok.png` är projektets mjuka partikel (alfa 0 → 214 → 0 över
## 32 px) — en egen PNG för en skugga vore en fil till för samma sak.
func _skuggtextur() -> Texture2D:
	if _skugg_tex == null:
		_skugg_tex = load("res://assets/fx/rok.png")
	return _skugg_tex


func _enemy_tex(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if not _enemy_cache.has(id):
		var path := "res://assets/enemies/%s.png" % id
		var bas: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if bas != null and _retusch.has(id):
			# FIENDERETUSCHEN (M82): Alex suddar och målar själv i fiendeeditorn. Receptet ligger i
			# data/enemies/retuschering.json och läggs på bilden HÄR — samma väg som allt annat fienden
			# ritar, så en retuschering syns direkt utan att köra om arkets generator. Bara de fiender
			# som faktiskt har ett recept får en egen bild; de andra behåller Godots egen textur.
			var bild: Image = bas.get_image()
			var antal := Retusch.tillämpa(bild, _retusch, id)
			bas = ImageTexture.create_from_image(bild) if antal > 0 else bas
		_enemy_cache[id] = bas
	var tex: Texture2D = _enemy_cache[id]
	return tex

## Fiendens yta som material (M73). Våt, metall, glas och aura är egenskaper per PIXEL, och en MASK
## säger var de sitter (R=våt G=metall B=glas A=aura). Fiender utan maskfil får null och behåller
## Godots eget material — vägen är opt-in per fiende, så en mask som blir fel kan bara slå ut sin egen.
##
## Ett `material_override` tar bort Sprite3D:s egen rutnätsräkning (M59: arket trycktes in i quaden och
## figuren blev en 16 px remsa), och därför räknar shadern rutan själv ur `ruta`. Materialet är eget per
## fiende — `ruta` är en uniform, och en delad ShaderMaterial hade gett alla samma ruta.
func _fiende_lager(id: String, tex: Texture2D) -> Sprite3D:
	if id.is_empty() or tex == null:
		return null
	if not _mask_cache.has(id):
		var p := "res://assets/enemies/%s_mask.png" % id
		_mask_cache[id] = load(p) if ResourceLoader.exists(p) else null
	var mask: Texture2D = _mask_cache[id]
	if mask == null:
		return null
	# Rutan klipps ur arket med en AtlasTexture i stället för med rutmatematik i shadern: Godot äger
	# redan räkningen, vi pekar bara på rätt sexkant.
	var ark := AtlasTexture.new()
	ark.atlas = tex
	var msk := AtlasTexture.new()
	msk.atlas = mask
	var l := Sprite3D.new()
	l.texture = ark
	l.hframes = 1
	l.pixel_size = tex.get_height() * 0.012 / 120.0        # samma skala som figuren (sätts om nedan)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED        # SAMMA billboard som figuren (M79, se shadern)
	l.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	l.render_priority = 2                                 # ovanpå figuren
	l.name = "material"
	l.set_meta("ark_atlas", ark)
	l.set_meta("mask_atlas", msk)
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/fiende_material.gdshader")
	m.set_shader_parameter("ark", ark)
	m.set_shader_parameter("mask", msk)
	l.material_override = m
	l.add_to_group("fiende_material")
	return l


## Lagret följer figurens ruta: AtlasTexture-regionen flyttas när figuren byter ruta. Egen rutmatematik
## behövs inte, och figuren själv rörs inte.
func _ruta(spr: Sprite3D) -> void:
	for barn in spr.get_children():
		if barn is Sprite3D and barn.name == "material":
			_ruta_lager(barn as Sprite3D, spr.frame)


## Flytta lagrets region till en ruta i arket.
func _ruta_lager(l: Sprite3D, ruta: int) -> void:
	var ark: AtlasTexture = l.get_meta("ark_atlas")
	var msk: AtlasTexture = l.get_meta("mask_atlas")
	var w := ark.atlas.get_width() / ENEMY_FRAMES
	ark.region = Rect2(ruta * w, 0, w, ark.atlas.get_height())
	msk.region = ark.region


## Fienderna andas: en långsam gungning och en kort "spänner sig"-ruta med ojämna mellanrum. Utan
## det står de helt still och läses som möbler i stället för som något som väntar på dig. Ett läge
## som satts av striden (spänner/hugger/träffad/död) går före andningen tills tiden runnit ut —
## dödsrutan ligger kvar för alltid, en död fiende ska inte resa sig igen.
func _process(delta: float) -> void:
	# Bildrutemätningen: snitt och SÄMSTA bildruta över hela körningen. Att läsa
	# Engine.get_frames_per_second() vid ett enstaka tillfälle ger vad som helst (mätt: 36 fps med
	# skuggor och 1 fps utan, vilket bara säger att siffran togs efter ett väntande).
	_frame_sum += delta
	_frame_n += 1
	_frame_worst = maxf(_frame_worst, delta)
	_fladdra(delta)          # facklorna brinner även i ett tomt rum — och det är de som lyser upp det
	_droppa(delta)           # takdroppet droppar, det rinner inte (se _droppa)
	if _enemies.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	for e in _enemies:
		var spr: Sprite3D = e["spr"]
		if not is_instance_valid(spr):
			continue
		var kvar: float = float(e.get("läge_t", 0.0)) - delta
		e["läge_t"] = kvar
		var läge: int = int(e.get("läge", -1))
		if läge >= 0 and kvar > 0.0:
			spr.frame = läge
			_ruta(spr)
			if läge == ENEMY_DEAD or läge == ENEMY_HIT:
				continue          # en träffad eller död kropp gungar inte med i andningen
		else:
			if läge >= 0 and läge != ENEMY_DEAD:
				e["läge"] = -1
			var fas: float = e["fas"]
			spr.frame = ENEMY_IDLE_B if fmod(t + fas, 3.1) > 2.72 else ENEMY_IDLE_A
			_ruta(spr)
		if int(e.get("läge", -1)) != ENEMY_DEAD:
			var fas2: float = e["fas"]
			spr.position.y = float(e["y"]) + sin(t * 1.7 + fas2) * 0.05
		# SKUGGAN: följer figurens x/z (uppställningen flyttar figuren) men ligger KVAR på golvet.
		# Höjden över viloraden krymper och bleknar den — det är skillnaden mot en platta som åker med.
		var sk2: Sprite3D = e.get("skugga")
		if sk2 != null:
			var hh: float = spr.position.y - float(e["y"])
			sk2.position.x = spr.position.x
			sk2.position.z = spr.position.z
			var s2: float = 1.0 - hh * 1.2
			sk2.scale = Vector3(SKUGGA_BREDD * s2, SKUGGA_BREDD * 0.55 * s2, 1.0)
			sk2.modulate.a = SKUGGA_ALFA * (1.0 - hh * 1.5)
		# GLANSEN andas den med: en aura som står still medan varelsen rör sig läses som ett klistermärke.
		var gn: Sprite3D = e.get("glans")
		if gn != null:
			var andning: float = 1.0 + sin(t * 2.3 + float(e["fas"])) * 0.06
			gn.scale = Vector3.ONE * andning * gn.get_meta("basstorlek", 1.0)
			(gn.material_override as StandardMaterial3D).emission_energy_multiplier = \
				float(gn.get_meta("basstyrka", 1.5)) * (1.0 + sin(t * 2.3 + float(e["fas"])) * 0.18)

## Sätt ett läge på en figur: vilken ruta och hur länge. Striden kallar på det här, _process
## räknar ned. -1 = tillbaka till andningen.
func _enemy_läge(e: Dictionary, frame: int, sekunder: float) -> void:
	e["läge"] = frame
	e["läge_t"] = sekunder

## Läs stridens fiender och visa vad som hände dem: tappad hälsa = träffad, noll = död.
## Det här är den enda kopplingen mellan stridens siffror och figurens rutor.
## `mult` är kedjemultiplikatorn för draget som just spelades — den styr hur stor siffran blir.
## Returnerar den FÖRSTA träffade figuren, så angreppet kan riktas mot den man faktiskt slog.
func _enemy_reaktion(mult: int = 1) -> Sprite3D:
	var träffad: Sprite3D = null
	if active_combat == null:
		return null
	var foes := active_combat.enemies
	for i in mini(foes.size(), _enemies.size()):
		var e: Dictionary = _enemies[i]
		var spr: Sprite3D = e["spr"]
		if not is_instance_valid(spr):
			continue
		var hp: float = foes[i].hp
		var förra: float = float(e.get("hp", hp))
		if förra < 0.0:
			e["hp"] = hp                # första mätningen: ett kvitto, inte en träff
			continue
		var skada := förra - hp
		if hp <= 0.0 and förra > 0.0:
			_enemy_läge(e, ENEMY_DEAD, 9999.0)
			_slag_kvitto(spr, skada, 3)          # ett dråp är alltid värt den stora siffran
			if träffad == null:
				träffad = spr
		elif hp < förra:
			_enemy_läge(e, ENEMY_HIT, 0.35)
			_slag_kvitto(spr, skada, mult)
			if träffad == null:
				träffad = spr
		e["hp"] = hp
	return träffad

## Rikta ett angrepp mot en figur. Vapnet ritas i SKÄRMKOORDINATER, så världspunkten måste räknas om
## — och står fienden bakom spelaren uteblir svepet i stället för att svepa mot ingenting.
func _attack_fx(kort: Cards.Card, spr: Sprite3D, mult: int) -> void:
	if attack_fx == null or not is_instance_valid(spr):
		return
	var mål := spr.global_position + Vector3(0.0, 0.22, 0.0)
	if cam.is_position_behind(mål):
		return
	attack_fx.spela(kort, cam.unproject_position(mål), mult)

## Samma läge på alla levande: fienderna gör sällan något ensamma.
func _enemy_läge_alla(frame: int, sekunder: float) -> void:
	for e in _enemies:
		if int(e.get("läge", -1)) == ENEMY_DEAD:
			continue
		_enemy_läge(e, frame, sekunder)

func _start_run(stage_id: String, seed_value: int, start_floor: int = 0) -> void:
	var stage: Stages.StageDef = stages.get(stage_id)
	if stage == null:
		push_error("okänd bana: %s" % stage_id)
		return
	run = Run.new(stage, bestiary, _start_lek(), seed_value, db, meta)
	# Banans regel SÄGS HÖGT i loggen när körningen börjar. En regel spelaren inte känner till är
	# inte en överraskning, den är ett fel — den står i editorn, och den ska stå här med.
	if not stage.regel.is_empty():
		_logga("%s — %s" % [Regler.namn(stage.regel), Regler.text(stage.regel)], Color(0.95, 0.75, 0.35))
	shell = "körning"             # banan är vald: 3D-vyn tar över från skalet
	_refresh_shell()
	# Startvåning: normalt 0, men kart-editorn kan släppa in en på en ritad våning.
	if start_floor > 0:
		run._enter_floor(clampi(start_floor, 0, stage.floors - 1))
	active_node = null
	active_combat = null
	last_events = 0
	_banked = false               # guldet från FÖRRA körningen är redan in i banken
	end_panel.visible = false
	battle_panel.visible = false
	draft_panel.visible = false
	_build_world()
	_refresh()

## Startleken: grundleken + hyrda kamrater + den PERMANENTA kortsamlingen (M45). Samlingen är därför
## "tillgänglig mellan alla banor" i ordets rätta mening — den följer med in i varje körning, inte bara
## som en visning i albumet. Egen funktion så provet kan mäta leken utan att starta en körning.
func _start_lek() -> Array:
	return Cards.make_pile(db, DECK + meta.hired + meta.samlade_kort())

## Minikartan: hela våningen synlig, spelaren som en ljus prick och oavklarade noder med EGNA märken.
## Rutorna var förr hela celler i nodens färg — på en liten karta blev det fyra färgade klossar utan
## innebörd. Nu: döskalle på bossen, liten prick för strider, kista för kistor, låga för facklor och
## en pil nedåt för shoveln. Det är skillnaden mellan "något är där" och "jag vet vad som väntar".
##
## KARTAN OCH DESS TECKENFÖRKLARING LIGGER I MARGINALEN (M32), inte i spelytan. MÄTT på Alex
## skärmbild: legenden låg som en remsa tvärs över övre halvan av 3D-vyn, från mitten till
## högerkanten, och Alex: *"Rutan med döskalle, strid, kista osv, den ligger nu i spelytan, den skall
## helst vara ren"*. Nu står kartan i fönstrets övre högra hörn med de sex orden i en kolumn under
## sig — allt i den svarta marginalen, utanför 480x270-rutan. Därför ligger kontrollen i FÖNSTRETS
## lager (`_runt`, se `_build_hud`) och skalas med korgen:s heltal: kartans pixelkonst blir densamma
## som förut, och ORDEN skrivs av UiText i fönsterstorlek i stället för att skalas upp.
##
## Orden (kista/fackla/…) är nycklar i i18n: här ritas bara formerna, orden hämtas med Tr.t, så
## kolumnen fungerar på alla 13 språk.
## Egen klass för att Control._draw är det enda rimliga sättet att rita 600 rutor utan 600 noder.
class MapView extends Control:
	const KARTA_HÖJD := 60.0         ## px i vyns skala: rutnätet
	const MAP_BREDD := 76.0
	## Kartans ruta. Teckenförklaringen ligger UNDER den, i marginalen — aldrig inuti.
	const MAP_SIZE := Vector2(MAP_BREDD, KARTA_HÖJD)
	## Teckenförklaringen: ett ord per rad, sex rader, under kartan. MÄTT (se `-- kistnara` och
	## ui/textprov.gd): värst polska "pochodnia" är 41 px vid 9 px, märket 9 px och luften 4, alltså
	## 54 px i vyns skala = 108 px i fönstret vid x2 — det ryms i marginalens 160 px med luft kvar.
	## Radhöjden är 14 och inte 11: typsnittet är 10 px över baslinjen och 3 under den vid 9 px (mätt
	## i textprov.gd), alltså 13 px bläck i en 11 px rad — då gick "döskalle":s översta två pixlar in
	## i kartan och en rad med underlängd (polska "gracz") rörde raden under sig.
	const RAD_HÖJD := 14.0           ## px per legendrad, i vyns skala (13 px bläck + 1 px luft)
	const LEGEND_HÖJD := RAD_HÖJD * 6.0
	## Märkets storlek i en legendrad: kartans cell (~3,5 px) går inte att läsa som form, så märket
	## ritas i den storlek formen krävs.
	const MÄRKE_PX := 9.0
	const LUFT := 4.0                ## px mellan märket och dess ord
	const ORD_FONT := 9              ## fontstorlek i vyns skala — ritas i 9 × skalans heltal
	## De sex märkena och deras ord. Nycklarna (ui.map.nod.*) finns i alla 13 språk, så kolumnen är
	## läsbar på varje språk i stället för att bära svenska ord i ritkoden.
	const NODER := ["boss", "fight", "chest", "torch", "shovel", "player"]

	var run: Run
	var last_state := 0          ## läget förra bildrutan (tal, se _process)
	var textlager: UiText            ## orden, ritade i FÖNSTRETS upplösning (se ui_text.gd)
	var visa_legend := false     ## teckenförklaringen visas först när man klickar på kartan (M75)

	func _ready() -> void:
		custom_minimum_size = MAP_SIZE
		# KARTAN ÄR EN KNAPP (M75). Alex: *"Informationen om vad varje grej på kartan kan vara en ruta
		# som visas om man trycker på kartan eller en knapp, men behöver inte vara synlig hela tiden."*
		# Ett klick på kartan fäller ut teckenförklaringen; den ligger kvar tills man klickar igen.
		mouse_filter = Control.MOUSE_FILTER_STOP
		# Lager 2: kartans ord är marginaltext och ska ligga över HUD:en (se UiText.fäst).
		textlager = UiText.fäst(self, 2)

	## Ett klick på kartan visar/döljer teckenförklaringen (M75). Texten ligger i ett eget lager över
	## kontrollen, så både `_draw` OCH ordlistan måste följa flaggan — annars blev det sex ord kvar
	## under en karta som inte längre visade sina märken.
	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT or not m.pressed:
			return
		visa_legend = not visa_legend
		if textlager != null:
			textlager.sätt(ord_rader())
		queue_redraw()
		accept_event()

	func _exit_tree() -> void:
		# Lagret ligger i FÖNSTRET (annars vore orden uppskalade igen): det måste bort med vyn.
		if textlager != null:
			textlager.frigör()

	func _process(_delta: float) -> void:
		# GÖMD VY GÖR INGET (samma skäl som i byn och på kartan: textbygget kostade bildrutan).
		if not is_visible_in_tree():
			return
		if run == null or run.explore == null:
			return
		# Rita bara om när något faktiskt ändrats — annars ritar vi 600 rutor i varje bildruta.
		# Läget som ett TAL, inte en sträng: 400 noder gav 400 strängbitar i varje bildruta. Antalet
		# öppnade noder räcker som mått — de blir bara fler, aldrig färre, och våningen ligger i talet.
		var öppnade := 0
		for n in run.explore.floor_ref.nodes:
			öppnade += 1 if n.cleared else 0
		var state := run.floor_index * 100000000 + run.explore.pos.x * 1000000 \
			+ run.explore.pos.y * 10000 + run.explore.facing * 100 + öppnade + (Tr.lang.hash() % 97)
		if state == last_state:
			return
		last_state = state
		# Orden sätts HÄR, inte i `_draw` (se WorldMapView._process): samma lista som provet mäter.
		# De står i marginalen och ligger alltså aldrig över vyn — inte ens när slutskärmens panel
		# (19 rader, högre än vyn) fyller den. De byggdes förut i VARJE bildruta (mätt: 4 fps i
		# fängelsehålan) trots att de bara ändras när spelaren flyttar sig eller öppnar en nod.
		if textlager != null:
			textlager.sätt(ord_rader())
		queue_redraw()

	func _draw() -> void:
		if run == null or run.explore == null:
			return
		var f: Dungeon.Floor = run.explore.floor_ref
		# Kartan ritar bara i SIN ruta: kolumnen med ord under den har ingen bottenplatta (den ligger
		# i marginalen mot svart), och kartans rutor ska ha den takt de alltid haft.
		var karta := MAP_SIZE
		draw_rect(Rect2(Vector2.ZERO, karta), Color(0.04, 0.04, 0.06, 0.85))
		var cell: float = min(karta.x / float(f.w), karta.y / float(f.h))
		var origin := (karta - Vector2(f.w, f.h) * cell) / 2.0
		for y in f.h:
			for x in f.w:
				var p := Vector2i(x, y)
				var col := Color(0.15, 0.15, 0.20) if f.is_floor_at(p) else Color(0.42, 0.45, 0.56)
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), col)
		for n in f.nodes:
			# Facklan står KVAR på kartan när vilan är tagen: ljuset är kvar på platsen (se
			# `_add_lagor`), och en markör som försvinner säger "här finns ingenting" om ett ställe
			# man fortfarande ser brinna.
			if n.kind == "start":
				continue
			if n.cleared and n.kind != "torch":
				continue
			_märke(n.kind, origin + Vector2(n.pos) * cell, cell)
		var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var d: Vector2i = dirs[run.explore.facing % 4]
		var me := origin + Vector2(run.explore.pos) * cell + Vector2(cell, cell) / 2.0
		draw_circle(me, max(1.5, cell * 0.4), Color(0.95, 0.95, 0.85))
		draw_line(me, me + Vector2(d) * cell, Color(0.95, 0.95, 0.85), 1.0)
		_legend()

	## Teckenförklaringen: samma märken som på kartan, en gång till och stora nog att se formen på
	## (9 px mot kartans 3,5), ett per rad under kartan. Orden ritas av `ord_rader` i fönstret och
	## står till höger om sitt märke (UiText-lagret ligger över den här kontrollen).
	##
	## Visas bara när `visa_legend` är satt (M75, ett klick på kartan). Är den dold ritas i stället ett
	## litet frågetecken i kartans nedre högra hörn — det säger att det finns något att trycka på, utan
	## ett ord som måste översättas till tretton språk.
	func _legend() -> void:
		if not visa_legend:
			return
		for i in NODER.size():
			var topp := MAP_SIZE.y + float(i) * RAD_HÖJD
			var kind := str(NODER[i])
			if kind == "player":
				# Spelaren: samma prick och pil som på kartan, så den raden också har sin form.
				var q := Vector2(MÄRKE_PX * 0.5, topp + RAD_HÖJD * 0.5)
				draw_circle(q, maxf(1.5, MÄRKE_PX * 0.3), Color(0.95, 0.95, 0.85))
				draw_line(q, q + Vector2(0, -MÄRKE_PX * 0.6), Color(0.95, 0.95, 0.85), 1.0)
			else:
				_märke(kind, Vector2(0.0, topp + (RAD_HÖJD - MÄRKE_PX) * 0.5), MÄRKE_PX)

	## Legendraden `i` i kartans koordinater: märket till vänster, ordet till höger om det.
	func rad_ruta(i: int) -> Rect2:
		return Rect2(MÄRKE_PX + LUFT, MAP_SIZE.y + float(i) * RAD_HÖJD, steg(), RAD_HÖJD)

	## Kartans eget mått. main.gd sätter `size`, men en vy som mätts utanför trädet (provet) ska mötas
	## av MAP_SIZE i stället för av noll.
	func _mått() -> Vector2:
		return Vector2(size.x if size.x > 0.0 else MAP_SIZE.x, size.y if size.y > 0.0 else MAP_SIZE.y)

	## Bredden på den bredaste legendraden i vyns skala: märket + det LÄNGSTA ordet i något av de 13
	## språken + luften. Räknas ur tabellerna i stället för ur en gissning, så en längre översättning
	## flyttar raden i stället för att klippas — och ur ALLA språk, så att raden står still när man
	## byter språk. Provet (test_minikarta.gd) mäter marginalens bredd mot den.
	func steg() -> float:
		var f := ThemeDB.fallback_font
		var värst := 0.0
		for kod in Tr.codes():
			var t: Dictionary = Tr.table(kod)
			for n in NODER:
				var nyckel := "ui.map.nod.%s" % n
				värst = maxf(värst, f.get_string_size(str(t.get(nyckel, n)), HORIZONTAL_ALIGNMENT_LEFT,
					-1, ORD_FONT).x)
		return MÄRKE_PX + värst + LUFT

	## Orden i legenden (se ui_text.gd): ett ord per rad under kartan, till höger om sitt märke.
	## Raderna är i kartans koordinater — `_draw` ritar märkena ur samma tal, och provet
	## (ui/textprov.gd, test_minikarta.gd) mäter dem mot kartans plats i FÖNSTRET.
	func ord_rader() -> Array:
		var f := ThemeDB.fallback_font
		var rader := []
		if not visa_legend:
			# DOLD: ett litet frågetecken i kartans nedre högra hörn säger att det finns något att
			# trycka på — utan ett ord som måste översättas till tretton språk. Det ritas som en RAD
			# i samma lager som orden (UiText), alltså skarpt: en `draw_string` inne i den här
			# kontrollen skalas upp med kartan och blev 39 px stor och grumlig (mätt).
			rader.append(UiText.rad("?", Vector2(MAP_SIZE.x - 7.0, MAP_SIZE.y - 3.0), 13,
				Palett.c(7), 10.0, HORIZONTAL_ALIGNMENT_RIGHT, "minikarta"))
			return rader
		for i in NODER.size():
			var topp := MAP_SIZE.y + float(i) * RAD_HÖJD
			# Baslinjen: bokstävernas bläck centreras i raden, så texten varken ligger i överkanten
			# eller tappar sin nedre del när fonten blir en pixel större.
			var y: float = topp + (RAD_HÖJD + f.get_ascent(ORD_FONT) - f.get_descent(ORD_FONT)) / 2.0
			rader.append(UiText.rad(Tr.t("ui.map.nod.%s" % NODER[i], NODER[i]),
				Vector2(MÄRKE_PX + LUFT, y), ORD_FONT, Palett.c(7), steg(), HORIZONTAL_ALIGNMENT_LEFT,
				"minikarta"))
		return rader

	## Märket för en nod. Allt ritas i cellens skala — ingen ikonfil behövs, och inget kan hamna
	## utanför kartan.
	##
	## MÄTT: cellen är 3,5 px på en 17x17-våning, och då blev döskallen, kistan och lågan 2x2 px
	## färgade klossar. En bildgranskare kunde inte skilja dem från prickar — "hard to read,
	## ambiguous colored dots lacking a legend" — trots att formerna ritas. Märket ritas därför i den
	## storlek som KRÄVS för att formen ska synas (en prick på två pixlar läses inte alls), centreras
	## på sin ruta och får en mörk bottenplatta så siluetten står mot kartan i stället för att flyta
	## ihop med den.
	const MÄRKE_MIN := 6.0           ## px: den minsta storlek en form kan läsas i
	const BOSS_STORLEK := 8.0        ## bossen finns en gång per våning och får vara störst

	func _märke(kind: String, p: Vector2, cell: float) -> void:
		var c: float = maxf(cell, BOSS_STORLEK if kind == "boss" else MÄRKE_MIN)
		var m := p + Vector2(cell, cell) / 2.0          # cellens mitt
		var o := m - Vector2(c, c) / 2.0                # märkets egen ruta, centrerad på cellen
		draw_rect(Rect2(o, Vector2(c, c)), Color(0.05, 0.05, 0.07))
		draw_rect(Rect2(o + Vector2(c, c) * 0.08, Vector2(c, c) * 0.84), Color(0.16, 0.15, 0.19))
		match kind:
			"boss":
				# Döskalle: ett ljust huvud med två mörka ögon och en mörk käke.
				draw_rect(Rect2(o + Vector2(c * 0.05, c * 0.12), Vector2(c * 0.9, c * 0.62)), Color(0.93, 0.93, 0.88))
				var öga: float = maxf(1.0, c * 0.16)
				draw_rect(Rect2(o + Vector2(c * 0.22, c * 0.32), Vector2(öga, öga)), Color(0.06, 0.06, 0.08))
				draw_rect(Rect2(o + Vector2(c * 0.62, c * 0.32), Vector2(öga, öga)), Color(0.06, 0.06, 0.08))
				draw_rect(Rect2(o + Vector2(c * 0.3, c * 0.62), Vector2(c * 0.4, c * 0.16)), Color(0.06, 0.06, 0.08))
			"fight":
				# Strid: en liten prick, inte en hel cell — man ska se kartan bakom sina fiender.
				draw_circle(m, maxf(1.2, c * 0.26), Color(0.85, 0.35, 0.30))
			"chest":
				draw_rect(Rect2(o + Vector2(c * 0.18, c * 0.3), Vector2(c * 0.64, c * 0.5)), Color(0.85, 0.68, 0.25))
				draw_rect(Rect2(o + Vector2(c * 0.18, c * 0.3), Vector2(c * 0.64, c * 0.16)), Color(0.95, 0.85, 0.45))
			"torch":
				draw_rect(Rect2(o + Vector2(c * 0.35, c * 0.2), Vector2(c * 0.3, c * 0.6)), Color(0.95, 0.6, 0.2))
				draw_rect(Rect2(o + Vector2(c * 0.42, c * 0.08), Vector2(c * 0.16, c * 0.2)), Color(1.0, 0.9, 0.55))
			"shovel":
				draw_rect(Rect2(o + Vector2(c * 0.42, c * 0.18), Vector2(c * 0.16, c * 0.5)), Color(0.7, 0.85, 0.9))
				draw_rect(Rect2(o + Vector2(c * 0.28, c * 0.62), Vector2(c * 0.44, c * 0.22)), Color(0.7, 0.85, 0.9))
			_:
				draw_circle(m, maxf(1.2, c * 0.24), NODE_COLORS.get(kind, Color.WHITE))

## Demoläge: spelar körningen med exakt samma anrop som tangenterna gör och fotograferar varje
## NY skärm (utforskning → strid → kortval → slut). Finns för att hela loopen ska gå att granska
## och regressa utan en skärm.
func _demo_run() -> void:
	var dir := "user://shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var n := 0
	var state := ""
	var fight_turns := 0
	var guard := 0
	await get_tree().create_timer(0.5).timeout
	while guard < 900:
		guard += 1
		var now := "utforskning"
		if run.finished:
			now = "slut"
		elif _draft_pending():
			now = "kortval"
		elif active_combat != null and not active_combat.over():
			now = "strid"
		if now != state:
			state = now
			if now == "strid" and _sort_mode == 0:
				# Handen visas i kedjeordning (kostnad stigande) från första striden: samma väg som
				# S-tangenten, så sorteringen syns i körningens logg och inte bara i koden.
				_cycle_sort()
			n = await _shot(dir, n, now)
			# Kortens fyra lägen, ett prov per fas: UTDELNINGEN (korten är på väg upp, ett i
			# taget), SVIKTEN (kortet viker sig ned under pekaren), LYFTET och STÖTEN när ett kort
			# spelas. Utan de bilderna går kortens rörelse aldrig att granska — och var bild får
			# kortens egna siffror (y, skala) i loggen, så fasen syns som ett tal och inte bara
			# som en bild. Siffrorna skrivs av _shot EFTER de två bildrutorna, alltså för samma
			# ögonblick som bilden visar.
			if now == "strid" and not hand_views.is_empty():
				n = await _shot(dir, n, "kort-utdelning")
				await get_tree().create_timer(0.35).timeout      # utdelningen är klar
				var mid: CardView = hand_views[hand_views.size() / 2]
				mid.set_forward(true)
				await get_tree().create_timer(0.015).timeout
				n = await _shot(dir, n, "kort-svikt")            # sviktens botten (3 px * handens 1,6)
				await get_tree().create_timer(0.1).timeout
				n = await _shot(dir, n, "kort-fram")             # lyftet, med översläng
				mid.set_forward(false)
			fight_turns = 0
		match now:
			"slut":
				# Byn: ett köp med guldet körningen gav. Räcker det inte loggas nekandet i klartext
				# — samma väg som en spelare utan 250 mynt går.
				var res := meta.buy("might")
				print("demo: byn — guld i banken %d, köp Might: %s (%s)" % [meta.gold, res.ok, res.reason])
				# BILDEN SKA VISA DET NAMNET LOVAR. Slutskärmen stod kvar bakom etiketten "by", och de
				# två bilderna var 98,6 % identiska (mätt: RMSE 0,014 mot 254-slut.png) — demon
				# fotograferade dödsrutan två gånger. T går till byn för spelaren (se _input), så
				# demon gör samma sak först och fotograferar sedan.
				_show_home()
				await get_tree().create_timer(0.4).timeout
				n = await _shot(dir, n, "by")
				break
			"kortval":
				_on_draft_pick(0)
			"strid":
				fight_turns += 1
				if fight_turns > 30:
					# Striden går inte att avsluta: fånga läget i siffror, inte bara i bild.
					print("demo: striden står still efter %d turer — spelar-hp %.0f, fiende-hp %.0f av %.0f, %d fiender, hand %d, mana %d" % [
						fight_turns, active_combat.hp, active_combat.total_enemy_hp(),
						active_combat.total_enemy_hp_max(), active_combat.enemies.size(),
						hand_views.size(), active_combat.mana])
					break
				if fight_turns == 1 and not hand_views.is_empty():
					# Första draget spelas med klickets animation: STÖTEN (kortet reser sig 12 % och
					# sätter sig) och FLYKTEN (34 px upp, förbi sin slutpunkt) fotograferas mitt i.
					# Vänta in flykten innan loopen går vidare, annars hinner solvern spela samma
					# kort medan tweenen fortfarande rör sig.
					_on_card(0)
					await get_tree().create_timer(0.015).timeout
					n = await _shot(dir, n, "kort-stot")        # stöten, mitt i slaget
					await get_tree().create_timer(0.1).timeout
					n = await _shot(dir, n, "kort-spelat")      # på väg ut ur handen
					# Slagets kvitto fotograferas först HÄR: kortet stöter och flyger i 0,16 s innan
					# draget löses, så bilderna ovan togs innan siffran över fienden fanns.
					await get_tree().create_timer(0.2).timeout
					n = await _shot(dir, n, "slag")
				else:
					# AWAIT är inte kosmetika här: `_on_play_all` och `_on_end_turn` är koroutiner, och
					# utan väntan gick loopen igenom sina 30 varv i EN bildruta medan fienderna stod
					# orörda — demoläget "körde" alltså en strid som aldrig hände och bröt efter 8
					# bilder ("striden står still efter 31 turer — fiende-hp 16 av 16", mätt).
					await _on_play_all()
					if active_combat != null and not active_combat.over():
						await _on_end_turn()        # korten är slut: turen måste avslutas för ny mana
			_:
				# Samma väg som spelaren går, men målet hämtas ur körningens egen plan (BFS)
				# i stället för att famla — en vägg-följare låser sig i ett hörn.
				var objective: Dungeon.FloorNode = run._next_objective()
				if objective == null:
					print("demo: inget mål kvar")
					break
				if run.explore.pos == objective.pos:
					var h: Dungeon.FloorNode = run.explore.node_here()
					print("demo: står på målet %s; node_here ger %s (cleared %s)" % [
						objective.kind, "inget" if h == null else h.kind, "ja" if h != null and h.cleared else "nej"])
					# SPADEN KLICKAS (M44): demoläget tar samma väg som spelaren, alltså ett
					# musklick på spaden — annars står körningen still på bossens ruta.
					if _spade_redo():
						print("demo: klickar på spaden (nivå %d klar)" % (run.floor_index + 1))
						await _gräv()
						await get_tree().process_frame
						_animate_cam()
						continue
					_enter_node_here()
					_refresh()
					await get_tree().process_frame
					continue
				var err := run.explore.step_toward(objective.pos)
				if err != "":
					print("demo: fast — %s, mål %s på %s, jag står på %s" % [
						err, objective.kind, str(objective.pos), str(run.explore.pos)])
					break
				_animate_cam()
				_enter_node_here()
				_refresh()
				await get_tree().process_frame
	print("demo: snitt %.0f fps (sämsta bildruta %.0f ms) över %d bildrutor — skuggor %s, lykta %.1f, omgivning %.2f"
		% [_frame_n / maxf(_frame_sum, 0.001), _frame_worst * 1000.0, _frame_n,
		"på" if _skugga else "av", _lykta_energi * _ljus_f, env.ambient_light_energy])
	print("shots: %d bilder, utfall %s pa vard %d, niva %d, %d varv, %d oavklarade (%s)" % [
		n, run.outcome, run.floor_index + 1, run.level, guard, _uncleared_kinds().size(),
		", ".join(_uncleared_kinds())])
	print("shots klara i: %s" % ProjectSettings.globalize_path(dir))
	get_tree().quit()

func _uncleared_kinds() -> Array:
	var out := []
	for n in run.explore.floor_ref.nodes:
		if not n.cleared:
			out.append(n.kind)
	return out

func _shot(dir: String, n: int, name: String) -> int:
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "%s/%02d-%s.png" % [dir, n, name]
	_spara_bild(path)
	# Mät UI:t samtidigt som bilden tas: en skärmbild visar att något saknas, de här siffrorna
	# visar varför (kortknappar, paneler, minikartans ruta). Kortens y och skala står med, för de
	# är fasen: en svikt ligger 3 px ned, ett lyft har vuxit, en stöt har skalan över 1.
	var kort := 0
	var matt := []
	for child in hand_zone.get_children():
		if child is CardView and not child.is_queued_for_deletion():
			kort += 1
			var k: CardView = child
			matt.append("%s %.0fx%.0f r%.0f y%.0f s%.2f%s" % [k.card.name, k.size.x, k.size.y,
				rad_to_deg(k.rotation), k.position.y, k.scale.x, " FRAM" if k.forward else ""])
	var val := 0
	for child in draft_box.get_children():
		if child is CardView and not child.is_queued_for_deletion():
			val += 1
	print("  %s | hand %d kort (%s) | val %d kort | stridspanel %s | stats %s | karta %.0fx%.0f @ %.0f,%.0f | vy %dx%d @ %.0f,%.0f x%.0f | kort \"%s\" | tips \"%s\" | %s%s" % [
		ProjectSettings.globalize_path(path), kort, "; ".join(matt),
		val, battle_panel.visible, stats_label.text if stats_panel.visible else "nej",
		map_view.size.x, map_view.size.y,
		map_view.position.x, map_view.position.y,
		_vy.size.x, _vy.size.y, _vy_korg.position.x, _vy_korg.position.y, _vy_korg.scale.x,
		kort_label.text, hint_label.text, _enemy_line(), _preview_text()])
	return n + 1

## Förhandsvisningen som siffra bredvid bilden, så riktmarkeringen går att kontrollera utan ögon.
func _preview_text() -> String:
	if _forward_index < 0 or active_combat == null:
		return ""
	var p := active_combat.preview(_forward_index)
	if not p.get("ok", false):
		return " | förhandsvisning: %s" % p.get("reason", "nej")
	var per := []
	for h in p["hits"]:
		per.append("%s −%.0f" % [h.enemy.name, h.damage])
	if per.is_empty():
		var kort: Cards.Card = active_combat.hand[_hand_index(_forward_index)]
		return " | förhandsvisning: ingen skada (%s)" % kort.name
	return " | förhandsvisning %s: %.0f skada ×%d" % [
		" + ".join(per), p["damage"], p["multiplier"]]

# --- 3D-vyn -----------------------------------------------------------------
func _build_world() -> void:
	_världsbyggen += 1
	if world != null:
		world.queue_free()
	_enemies.clear()
	# Spaden hör till våningen som byggdes: sprite-referensen pekar in i den gamla världen, och ett
	# klick mot ett frigjort objekt är ett klick mot ingenting.
	_spade_nod = null
	_spade_sprite = null
	# Droppställena hör till våningen som byggdes: utan rensningen ligger förra våningens ställen kvar
	# med sina positioner, och `nodprov=dropp` flyger till ett ställe som inte finns längre.
	_droppar.clear()
	_takställen.clear()
	world = Node3D.new()
	# Världen ritas i SPELVYN (480x270), inte i fönstret: det är den som ska vara pixelkonst.
	_vy.add_child(world)
	var f: Dungeon.Floor = run.explore.floor_ref
	# Dropparnas frö: samma regel som resten av våningen (samma våning ser likadan ut varje gång), så
	# takten går att fotografera och jämföra i stället för att vara olika varje gång.
	_dropprng.seed = hash(Vector3i(hash(run.stage.id), f.index, 7711))
	# Temat: våningens eget (ritad karta) → banans floor_themes → banans theme → platt fallback.
	_tema = f.theme if not f.theme.is_empty() else Stages.theme_for(run.stage, f.index)
	_apply_tema()
	print("våning %d: tema %s" % [f.index + 1, _tema if not _tema.is_empty() else "(platt)"])

	var walls := []
	var floors := []
	for y in f.h:
		for x in f.w:
			var p := Vector2i(x, y)
			if not f.is_floor_at(p):
				walls.append(p)
			else:
				floors.append(p)
	# Rutorna är egen pixelkonst (tools/gen_tiles.py), ritad i spelets palett. Mossiga väggar och
	# sprucket golv används där våningen har något att säga (trappa/boss), så rum skiljer sig åt.
	# Ytorna delas i slitna och hela PARTIER av ett mjukt fält (inte var sjätte ruta: en period är ett
	# mönster ögat hittar direkt). Vattnet — som bara finns i de slitna rutorna — blir därmed synligt
	# i parti, som om taket läcker över ett område, i stället för som ett jämnt utstrött mönster.
	# Bossrummet vänder på fördelningen: där är slitaget basen och de hela rutorna inslag.
	# Slitaget är en MINORITET (0,28/0,30). Fyra varianter gör våningen varierad, inte trasig; en
	# majoritet sliten yta är samma enfald som en majoritet hel — och bossrummet vände tidigare på
	# fördelningen ("där är slitaget basen"), vilket med fyra varianter bara betydde att EN ruta
	# upprepades över 72 % av väggarna. Inversionen är borta; bossrummet får sin särart av annat.
	var golv := _dela(floors, 11, 0.28, false)
	var vägg := _dela(walls, 23, 0.30, false)
	var slitet_golv: Array = golv[0]
	var fint_golv: Array = golv[1]
	var sliten_vägg: Array = vägg[0]
	var fin_vägg: Array = vägg[1]
	# De HELA ytorna får varsin super-ruta (64x64 byggd av tre varianter i fyra ordningar,
	# tools/gen_tiles.py). Upprepningen flyttar sig därmed från en halvmeter till fyra meter, och det
	# är upprepningsavståndet ögat läser — inte antalet bilder. Referensbygget: 1024 px per 3x3 m.
	# Skuggningsfröna är olika per grupp, annars lyser en ruta alltid lika ljust som den intill och
	# sömmen mellan grupperna syns som en kant.
	var vägggrupper := _gruppera(fin_vägg, 31, SUPER_YTOR)
	var golvgrupper := _gruppera(fint_golv, 41, SUPER_YTOR)
	for i in SUPER_YTOR:
		_add_boxes_ytor(vägggrupper[i], COL_WALL, TAK_HÖJD * 0.5, Vector3(1, TAK_HÖJD, 1),
			"wall_super_%d" % i, 31 + i, 1.0)
		_add_boxes_ytor(golvgrupper[i], COL_FLOOR, 0.02, Vector3(1, 0.04, 1), "floor_super_%d" % i,
			41 + i, 1.0, GOLV_TON)
	_add_boxes_ytor(sliten_vägg, COL_WALL, TAK_HÖJD * 0.5, Vector3(1, TAK_HÖJD, 1), "wall_moss", 37)
	_add_boxes_ytor(slitet_golv, COL_FLOOR, 0.02, Vector3(1, 0.04, 1), "floor_crack", 43, 2.0,
		GOLV_TON)
	_add_boxes_ytor(floors, COL_CEIL, TAK_HÖJD, Vector3(1, 0.04, 1), "ceiling", 47, 2.0, TAK_TON)
	# Siffrorna i loggen: hur stor del av ytorna som blev slitna partier. Utan dem går det inte att
	# se att fältet faktiskt delar våningen (en andel på 0 % eller 100 % ser ut som "ingen variation").
	print("  ytor: golv %d (%d slitna), vägg %d (%d slitna), tak %d"
		% [floors.size(), slitet_golv.size(), walls.size(), sliten_vägg.size(), floors.size()])

	# Dekorationen läggs EFTER golvet: den står på det. Ingen kollision, ingen nod per tuva — se DEKOR_*.
	_bygg_dekor(floors)

	# Området är mörkt; lyktan är det som lyser. Facklorna är rummets egna ljuspunkter.
	_add_lagor(f)
	# Effekterna: eld i facklorna, damm i luften, pölar och droppar där vattnet är målat.
	if _fx:
		_vatten_och_eld(f, slitet_golv, sliten_vägg)
		if _takdropp_på:
			_takdropp(f)

	for n in f.nodes:
		if n.kind == "start":
			continue
		# Facklan ritar sig SJÄLV (hållare, låga och ljus — se `_add_lagor`) och gör det även när
		# vilan är tagen. Den gamla rutmarkören (en 8x8-ruta i facklans färg) hamnade under lågan som
		# en orange fläck, och nu skulle den hamna under en eld mitt i luften. Med fx av finns ingen
		# eld, och då får markören stå kvar — annars vore facklan osynlig i mätläget.
		if n.kind == "torch":
			if not _fx and not n.cleared:
				_add_markör(n, n.kind)
			continue
		# KISTAN ÄR BYGGD GEOMETRI (M32), inte en skylt. MÄTT i `-- kistnara`: som billboard låg
		# alla fyra hörnen innanför kamerans närplan när spelaren stod på kistans egen ruta (0 av 1
		# px kvar — kistan försvann), och bredden på skärmen var 66 px från alla fyra håll (1,00):
		# skylten snurrar med spelaren. Alex: *"Kistor försvinner när man kommer nära, det får de
		# inte göra"* och *"…och inte snurra när man själv snurrar"*. En upplåst kista STÅR KVAR med
		# locket öppet i stället för att tas bort med noden.
		if n.kind == "chest":
			_kista_geometri(n, n.cleared)
			continue
		# En besegrad boss lämnar sina ben kvar. Noden är avklarad och ritar inget annars — men en
		# tom plats där bossen stod säger ingenting, och benen är ritade just för den platsen.
		if n.cleared:
			if n.kind == "boss":
				_add_markör(n, "boss")
			continue
		if n.kind == "encounter" or n.kind == "boss":
			_add_enemies(n, n.kind == "boss")
			continue
		_add_markör(n, n.kind)

	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.05
	cam.position = _cam_pos()
	cam.rotation.y = Explore.yaw_for(run.explore.facing)
	world.add_child(cam)
	# Lyktan hänger på kameran: den är i handen på spelaren och flyttar sig med den.
	_add_lykta()
	# Dammet hör till kameran (det syns bara i lyktskenet) och kameran byggs EFTER våningen, så det
	# kopplas in här. Kameran lever kvar mellan våningar — därför bara en damm-moln per körning.
	if _fx and cam.get_node_or_null("damm") == null:
		Fx.damm(cam)


## En nod som en sak på golvet: kistan, spaden, benen. Konsten ritas av tools/gen_props.py.
##
## Fallbacken är den gamla rutmarkören (en 8x8-schackruta i nodens färg). Den finns kvar för att en
## saknad bild ska ge en ful markör, inte en osynlig nod — men den är ingen bild: Alex såg den på
## golvet och frågade vad den föreställde, och svaret var "en schackruta".
func _add_markör(n: Dungeon.FloorNode, namn: String) -> void:
	var spr := Sprite3D.new()
	spr.texture = _prop(namn)
	if spr.texture == null:
		spr.texture = _tex(NODE_COLORS.get(namn, Color.WHITE))
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.shaded = true
	# 0,016 i stället för 0,01: på två stegs håll i en mörk grotta var kistan och spaden fem pixlar
	# höga och läste som fläckar i golvet (vision: "blends into the surrounding floor"). En kista på
	# en halv meter i en ruta på en meter är dessutom rätt storlek.
	# 0,008 sedan rekvisitan ritades om i dubbel duk (tools/gen_props.py): 0,016 gav rätt storlek när
	# duken var 32x24, och med 64x48 blir figuren dubbelt så stor i världen om siffran står kvar.
	spr.pixel_size = 0.008
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.position = Vector3(n.pos.x + 0.5, 0.35, n.pos.y + 0.5)
	world.add_child(spr)
	if namn == "shovel":
		# Spaden är den enda sak som KLICKAS (`_vy_klick`): spara noden och skylten, så klicket kan
		# räkna ut var på skärmen den står och om den får tas (bossen måste vara besegrad).
		_spade_nod = n
		_spade_sprite = spr


## Dekorationen (M84): gräs, rötter, mossa och småsten. Alex: *"saker i miljön som inte skall ha någon
## collision, men bidrar till mer... känsla?"*
##
## Ingen kollision är en EGENSKAP: en MultiMesh bär transformar, inte kroppar, så det finns inget
## CollisionShape att glömma och inget att stänga av. Gräset går att gå rakt igenom per konstruktion.
##
## EN MultiMesh PER ART, som för ytorna: fyra arter blir fyra ritningar för hela våningen i stället för
## en nod per tuva. Skalan per instans behålls i shadern (MODEL_MATRIX[3] är positionen, längderna på
## basens axlar är skalan) — samma fallgrop som gav den dubbla, vita fienden i M79.
func _bygg_dekor(golv: Array) -> void:
	if _dekor_täthet <= 0 or golv.is_empty():
		return
	if _dekor_shader == null:
		_dekor_shader = load("res://ui/dekor.gdshader")
	var per_art := {}
	for p in golv:
		if not _strö(p, _dekor_täthet):
			continue
		var v := _slump(p.x, p.y, 7717)
		var art := "gräs"
		var ackum := 0.0
		for rad in DEKOR_VIKT:
			ackum += float(rad[1])
			if v <= ackum:
				art = str(rad[0])
				break
		# Liten förskjutning inom rutan och egen storlek: två tuvor ska inte vara samma tuva.
		var dx := (_slump(p.x, p.y, 331) - 0.5) * 0.6
		var dz := (_slump(p.x, p.y, 557) - 0.5) * 0.6
		var s := 0.8 + _slump(p.x, p.y, 991) * 0.4
		if not per_art.has(art):
			per_art[art] = []
		(per_art[art] as Array).append(Transform3D(
			Basis().scaled(Vector3(s, s, s)),
			Vector3(float(p.x) + 0.5 + dx, 0.0, float(p.y) + 0.5 + dz)))
	var antal := 0
	for art in per_art:
		var n := _dekor_nod(art, per_art[art])
		antal += n
		print("  dekor: %-8s %3d st" % [art, n])
	print("  dekor: %d st på %d golvrutor (var %d:e ruta)" % [antal, golv.size(), _dekor_täthet])


## En MultiMesh per art. Quadden är dukens pixelstorlek gånger DEKOR_PIXEL, och instanserna lyfts så
## att figurens NEDERKANT står på golvet — quadden är centrerad kring sin origo.
func _dekor_nod(art: String, platser: Array) -> int:
	var tex := _prop(art)
	if tex == null or platser.is_empty() or not world:
		return 0
	var duk := Vector2(float(tex.get_width()), float(tex.get_height())) * DEKOR_PIXEL
	var mesh := QuadMesh.new()
	mesh.size = duk
	var mat := ShaderMaterial.new()
	mat.shader = _dekor_shader
	mat.set_shader_parameter("textur", tex)
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = platser.size()
	for i in platser.size():
		var t: Transform3D = platser[i]
		var s := t.basis.get_scale().y
		t.origin.y = duk.y * 0.5 * s          # figurens nederkant på golvet, se provet
		mm.set_instance_transform(i, t)
	var nod := MultiMeshInstance3D.new()
	nod.name = "dekor_" + art
	nod.multimesh = mm
	world.add_child(nod)
	return platser.size()


## Rekvisiten ur assets/props/ (tools/gen_props.py). Null om filen inte finns — anroparen faller
## tillbaka på rutmarkören.
func _prop(namn: String) -> Texture2D:
	var p := "res://assets/props/%s.png" % namn
	if _prop_cache.has(namn):
		return _prop_cache[namn]
	var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_prop_cache[namn] = tex
	return tex

## Spridningen: var n:te ruta (i genomsnitt) får en detalj. Hashen gör mönstret stabilt per våning i
## stället för att hoppa varje gång vyn byggs om.
##
## MÄTT FALLA: först var det `hash(...) % n == 0`, och den hash Godot ger för små Vector3i är inte jämn
## i de låga bitarna: av 108 väggrutor föll 6 ut i stället för 21 (var femte), så takdropp och
## vattendroppar blev en femtedel av vad de skulle vara. Nu dras värdet ur samma fält som resten av
## variationen och jämförs mot 1/n — 21 av 108 med samma indata.
func _strö(p: Vector2i, n: int) -> bool:
	# Eget frö, inte fältet: dropparna får inte ärva slitagets klumpar. De rutor som är slitna är ju
	# VALDA av fältet, så samma källa ger ett snett urval (mätt: 3 av 88 i stället för 18).
	return _slump(p.x, p.y, run.explore.floor_ref.index) < 1.0 / float(n)


## Mjukt fält i [0,1] som ändras i KLUMPAR om några rutor i stället för per ruta.
##
## Repetitionen satt inte i antalet rutbilder utan i MÖNSTRET: "var sjätte ruta" är en period, och ögat
## hittar den direkt (Alex: *"man skall inte bli trött på miljön"*). Ett mjukt fält ger fläckar i
## stället — ett slitet parti här, ett helt där — och samma fält styr en liten ljushetsskillnad per
## ruta, så två rutor med samma bild inte är identiska.
func _fält(p: Vector2i, frö: int) -> float:
	var k := 3                                # klumpens storlek i rutor (3 m)
	var bx := floori(float(p.x) / float(k))
	var by := floori(float(p.y) / float(k))
	var fx := float(p.x - bx * k) / float(k)
	var fy := float(p.y - by * k) / float(k)
	var a := lerpf(_vrån(bx, by, frö), _vrån(bx + 1, by, frö), fx)
	var b := lerpf(_vrån(bx, by + 1, frö), _vrån(bx + 1, by + 1, frö), fx)
	return lerpf(a, b, fy)


## Ett jämnt tal i [0,1) ur (x, y, frö): hash, inte slumptal — samma våning ska se likadan ut varje gång.
##
## MÄTT: Godots egen hash duger inte till det här. Den är jämn över ett stort plan men inte på en RAD
## eller i ett litet blocknät, och det är precis vad en våning är: 108 väggrutor gav 6 utfall där 21
## väntades. Finaliseraren nedan (PCG-klass: multiplicera-xor-skifta) ger 21 % på en rad, 22 % i en
## kolumn, 17 % i ett 6x6-nät och 20 % över hela planet — och de HÖGA bitarna används, för de låga
## bitarna av en produkt beror bara på de låga bitarna av indata.
static func _slump(x: int, y: int, frö: int) -> float:
	var n: int = (x * 0x9E3779B1 + y * 0x85EBCA77 + frö * 0xC2B2AE3D) & 0xFFFFFFFF
	n = (n ^ (n >> 15)) * 0x2545F491 & 0xFFFFFFFF
	n = (n ^ (n >> 13)) * 0x3D4D51CB & 0xFFFFFFFF
	n = n ^ (n >> 16)
	return float(n >> 8) / float(1 << 24)


## Ett hörn i fältet.
##
## Bitarna blandas först (multiplicera-xor-skifta). MÄTT: Godots hash för små Vector3i är en linjär
## kombination av delarna, så `% 1000` följer x med ett fast steg och blir ett mönster i stället för
## brus — av 108 väggrutor föll 9 ut där 21 väntades (var tolfte i stället för var femte).
func _vrån(bx: int, by: int, frö: int) -> float:
	# Primtalen sprider GRANNBLOCKEN. Utan dem är hashen jämn över 200x200 men närliggande block hamnar
	# nära varandra, och en liten våning (6x6 block) blir ett mönster i stället för ett urval: mätt
	# hamnade 95 av 112 golvrutor över tröskeln där 42 väntades.
	return _slump(bx, by, frö)


## Ytorna delas i slitna och hela PARTIER av det mjuka fältet.
##
## `spridning` är hur stor del som blir slitet. Bossrummet vänder på fördelningen (där är slitaget
## basen) — det var ett eget fynd från M17: att bara byta vilken lista som fick vilken ruta gav exakt
## samma våning.
## Delar cellerna i `antal` grupper efter ett hashfält. Varje grupp får sin egen super-ruta, och
## eftersom grannar hamnar i olika grupper upprepar sig kombinationen sällan — det är hela poängen
## med super-rutorna (fyra ordningar av tre varianter).
func _gruppera(celler: Array, frö: int, antal: int) -> Array:
	var ut: Array = []
	for i in antal:
		ut.append([])
	for p in celler:
		ut[int(_slump(p.x, p.y, frö) * antal)].append(p)
	return ut


func _dela(celler: Array, frö: int, andel: float, vänd: bool) -> Array:
	if celler.is_empty():
		return [[], []]
	# Tröskeln tas ur våningens EGNA värden i stället för att vara en fast siffra. Fältet är jämnt över
	# hundra rutor men inte över trettiosex block (mätt: medel 0,570 i stället för 0,500), så en fast
	# tröskel gav 59 % slitna där 38 % var tänkt. Nu blir andelen den jag ber om, varje gång.
	var ordnade := celler.duplicate()
	ordnade.sort_custom(func(a, b): return _fält(a, frö) < _fält(b, frö))
	var k := int(round(andel * float(ordnade.size())))
	var slitet := ordnade.slice(0, k)
	var hela := ordnade.slice(k)
	# `vänd` är bossrummet: där är slitaget basen och de hela rutorna inslag.
	return [hela, slitet] if vänd else [slitet, hela]


## Materialet på en ruta, "" om rutan ska ha temats egen. Id:t är en sökväg under assets/tiles/.
func _yta_material(c: Vector2i) -> String:
	if run == null or run.explore == null:
		return ""
	var f: Dungeon.Floor = run.explore.floor_ref
	return str(f.ytor.get("%d,%d" % [c.x, c.y], ""))

## Som `_add_boxes`, men rutorna delas först efter sin materialöverstyrning: en ruta som målats om
## ritas i sin egen grupp i stället för att tvinga hela ytan till samma bild. Rutorna utan material
## går i EN grupp, precis som förut — en våning utan överstyrningar ritas alltså exakt som i dag.
func _add_boxes_ytor(tiles: Array, color: Color, y: float, size: Vector3, ruta: String = "",
		skugga_frö: int = 0, upprepa: float = 2.0, ton: Color = Color.WHITE) -> void:
	var egna := {}
	var utan := []
	for c in tiles:
		var m := _yta_material(c)
		if m.is_empty():
			utan.append(c)
		elif egna.has(m):
			egna[m].append(c)
		else:
			egna[m] = [c]
	if not utan.is_empty():
		_add_boxes(utan, color, y, size, ruta, skugga_frö, upprepa, ton)
	for m in egna:
		_add_boxes(egna[m], color, y, size, m, skugga_frö, upprepa, ton)

## Väggar, golv och tak som ETT MultiMesh per yta. `ruta` är namnet på pixelkonsten i
## assets/tiles/; saknas den faller ytan tillbaka på den genererade schackrutan så spelet alltid
## går att starta (en saknad bild ska synas som ett platt golv, inte som en krasch).
##
## `skugga_frö` (0 = av) ger varje ruta en egen ljushet ur samma slags mjuka fält. Utan den ligger
## samma bild i exakt samma ton 600 gånger, och det är den likheten ögat tröttnar på.
func _add_boxes(tiles: Array, color: Color, y: float, size: Vector3, ruta: String = "",
		skugga_frö: int = 0, upprepa: float = 2.0, ton: Color = Color.WHITE) -> void:
	if tiles.is_empty():
		return
	var tex: Texture2D = _tile(ruta) if ruta != "" else null
	var mesh := BoxMesh.new()
	mesh.size = size
	# 2.5D: normal- och ORM-karta ur samma tema (samma namn + _n / _orm). Saknas de blir ytan som
	# förut — en saknad karta ska inte ge en osynlig vägg, bara en plattare yta.
	var normal: Texture2D = _tile(ruta + "_n", true) if (ruta != "" and _kartor) else null
	var orm: Texture2D = _tile(ruta + "_orm", true) if (ruta != "" and _kartor) else null
	var mat := StandardMaterial3D.new()
	# Tonen läggs på albedon (rutan, normalen och ORM-kartan rörs inte): taket ska läsas som tak
	# och golvet som golv även när samma varma fackla lyser på alla tre.
	mat.albedo_color = ton if tex != null else color * ton
	if tex != null:
		# Den målade kantens kontrast, dämpad. Normal- och ORM-kartorna rörs INTE: det är albedons
		# ritade kant som ska tystna, inte reliefen.
		mat.albedo_texture = _kant_dämpad(tex, _kant)
	else:
		mat.albedo_texture = _tex(color)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Ljussatt, inte ostrukturerat: våningen är mörk och lyktan i handen är det som lyser. Matt yta
	# (roughness 1, ingen spegling) så pixelkonsten inte ser ut som plast när ljuset faller på den.
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Glansen: ljuset kan ge högdagrar (se LJUS_GLANS), men BARA där ytan är blank — speglingen räknas
	# ur materialets egen råhet (se YTGLANS_TRÖSKEL), så stenen förblir matt medan pölen, benet, träet och
	# järnet blir blanka. Utan ORM-karta blir ytan matt (som förut).
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		# Ratten för hur mycket reliefen syns. MÄTT på en SUPER-RUTA i EN körning, samma kamera,
		# Forward+ (`-- normalprov=0@0,4@0,10@0,20@0 provruta=super`; 8 av 35 material i vyn är
		# super-rutor och ALLA 8 bär normal- och ORM-karta — en misstanke om att de stora ytorna
		# saknade kartor är alltså mätt fel: skillnaden mot normal_scale 0 är 2,10 i medel / 44 i
		# p99 vid 4,0, medan brusgolvet är 0,30 / 1,0. Signalen är 7x golvet i medel och 44x i p99.)
		# Mot 10,0 ger 2,74 och mot 20,0 ger 3,01: fyra gånger ratten köper +43 %. Reliefen SYNS
		# alltså, men taket är nära — ytan är mörk (vyns medelljushet 0,077) och normalens bidrag
		# växer med ljuset på ytan, inte med skalan. Vill man ha mer relief är lyktan/ljuset hävstången,
		# inte den här siffran.
		#
		# OCH RATTEN ÄR MÄTT SLUT (M27): skalan 4,0 mot 10,0 mot 20,0 i EN körning (`-- normalprov=
		# 4,10,20,4`) ger vyns medel 0,120 → 0,107 → 0,099 och mörkt 67 % → 74 % → 77 %, medan
		# ljuspölarna KRYMPER (p90 0,346 → 0,310 → 0,286). Den extra reliefen betalas alltså med det
		# Alex vill ha kvar: ljuset på golvet. Mörkret tvättas inte bort — pölarna äts upp.
		mat.normal_scale = 4.0
	if orm != null:
		mat.roughness_texture = orm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		# Ocklusionen ligger i ORM-kartans R-kanal (fogar och sprickor mörka). Utan
		# ao_light_affect dämpar AO ingenting alls — den är 0 i grunden och då syns kanalen
		# aldrig, hur mycket data den än bär.
		mat.ao_enabled = true
		mat.ao_texture = orm
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_light_affect = 1.0
		mat.metallic_texture = orm
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	_yta_glans(mat, GLANS_BLÖT_ANDEL)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	if skugga_frö != 0:
		mat.vertex_color_use_as_albedo = true
	# Varje block är 1x1 meter och visar hela rutan, så en 32x32-ruta med fyra tegelvarv blir
	# tegelstenar på 25 cm och läses som paneler i vyn (mätt: "modular panels" två gånger).
	# Pixelart-look utan glans: matt yta, ingen spegling (se _add_boxes).
	# 2 upprepningar per meter för 32x32-rutorna (64 px/m), 1 för 64x64-super-rutorna (samma täthet).
	mat.uv1_scale = Vector3(upprepa, upprepa, 1)
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# use_colors MÅSTE sättas innan mesh/instance_count: bufferten allokeras av dem, och efteråt
	# svarar MultiMesh med "Property not found" och ritar instanserna utan färg (mätt: tyst i bilden,
	# högt i loggen).
	if skugga_frö != 0:
		mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	var i := 0
	for p in tiles:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x + 0.5, y, p.y + 0.5)))
		if skugga_frö != 0:
			# ±12 % ljushet. Fältet är mjukt, så det blir partier med ljusare/mörkare yta i stället
			# för ett myrstadsmönster av prickar.
			var v := 0.88 + 0.24 * _fält(p, skugga_frö)
			mm.set_instance_color(i, Color(v, v, v))
		i += 1
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	world.add_child(node)

## Den MÅLADE kantens kontrast i albedon, dämpad. `grad` 0 = rutan exakt som den ritades, 1 = kantens
## 1-px-kontrast borta medan blockets färg och storform är kvar. Texten cachas per (ruta, grad):
## omskrivningen kostar en bildkopiering, och samma ruta används av hundratals instanser.
##
## VARFÖR DEN FINNS: normal-kartan når shadern — mätt i EN körning med samma kamera är |normal_scale
## 0 mot 4,0| 2,06 i medel och 46 i p99 mot ett brusgolv på 0,20 (två bilder med samma värde) — och
## ändå läser ytan platt. En MÅLAD kant ser likadan ut från varje vinkel; den är ritad, inte
## ljusatt, så ögat läser reliefen ur albedon i stället för ur ljuset, hur bra kartan än är. Tar man
## bort kantens hopp får ljuset svara för reliefen. Lågpasset är ner till en fjärdedel och upp igen
## (bilinjärt): en kant på 1 px försvinner, en form på 4 px finns kvar, och tonen i rutan rör sig
## inte.
##
## MEN HYPOTESEN HÖLL INTE (se KANT ovan): med suddig albedo är relief-signalen 2,17 mot 2,06 med
## skarp — inom bruset. Ratten kostar konst och köper ingen relief, så spelet kör 0,0.
## Albedon blandad mot sin egen suddiga version. `grad` 0 = originalet (samma resurs, ingen kopia),
## 1 = helt suddig. OBS: vid 1,0 är det inte "kanten" som dämpas, det är HELA bilden — funktionen är
## ett lågpassfilter, inte en kantdämpare. Blandningen görs på BYTEN i stället för med
## get_pixel/set_pixel: samma resultat, och en 64x64-super-ruta är 16 384 kanaler — get_pixel hade
## kostat i världsbygget.
## ponytail: en riktig kantdämpare hade läst grannpixlar och bara rört 1 px-kanter. Den behövs inte
## förrän någon mäter fram ett läge där konsten ska behållas OCH kanten tystas.
func _kant_dämpad(tex: Texture2D, grad: float) -> Texture2D:
	if tex == null or grad <= 0.0:
		return tex
	var nyckel := "%s@%.2f" % [tex.resource_path, grad]
	if _kant_cache.has(nyckel):
		return _kant_cache[nyckel]
	var img := tex.get_image()
	if img == null:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	var mjuk := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	mjuk.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	var ned := maxi(img.get_width() / 4, 1)
	mjuk.resize(ned, maxi(img.get_height() / 4, 1), Image.INTERPOLATE_BILINEAR)
	mjuk.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_BILINEAR)
	# Blandningen görs på BYTEN i stället för med get_pixel/set_pixel: samma resultat, och en
	# 64x64-super-ruta är 16 384 kanaler — get_pixel hade kostat märkbart i världsbygget.
	var a := img.get_data()
	var b := mjuk.get_data()
	for i in a.size():
		a[i] = int(round(lerpf(float(a[i]), float(b[i]), grad)))
	var ut := ImageTexture.create_from_image(Image.create_from_data(
		img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, a))
	_kant_cache[nyckel] = ut
	return ut


## Temats ljus in i miljön. Ett tema utan post (eller "(platt)") får en neutral, svag belysning —
## en saknad post ska synas som ett platt rum, inte som ett kolsvart.
func _apply_tema() -> void:
	var l: Dictionary = TEMA_LJUS.get(_tema, {})
	if env != null:
		env.background_color = l.get("bakgrund", Color(0.07, 0.07, 0.10))
		env.ambient_light_color = l.get("omgivning", Color(0.5, 0.5, 0.55))
		env.ambient_light_energy = _omgivning if _omgivning >= 0.0 else float(l.get("energi", 0.30))
		env.fog_density = float(l.get("dimma", 0.04))
		env.fog_light_color = env.background_color.lightened(0.06)
		# Den volymetriska dimman följer temats täthet, inte ett eget värde: ett tema som redan är
		# disigt (kryptan, tunneln) ska ha tjockare luft också där ljuset går genom den. Taket på
		# 0,05 är mätt: över det blir lyktan en grå vägg och rummet försvinner bakom sin egen luft.
		if _vol:
			env.volumetric_fog_density = clampf(float(l.get("dimma", 0.04)) * 0.32, 0.006, 0.05)
			env.volumetric_fog_albedo = env.background_color.lightened(0.5)

## Ljuset som faller på YTORNA: lyktan i handen och facklorna i rummet, gånger `f`. EN väg in, så
## mätprovet (`-- normalprov=…@ljus`), fladdret och världsbygget använder samma formel — annars mäter
## provet en kopia av mekanismen i stället för mekanismen (mätt: `_fladdra` skrev över lyktans energi
## varje bildruta, så en ratt på energin nådde aldrig fram till en bild).
##
## Omgivningsljuset är INTE med här: det är takten man ser rummet i, inte en ljuskälla, och en faktor
## på det hade tvättat bort mörkret i stället för att lysa upp ytorna.
func _ljus_styrka(f: float) -> void:
	_ljus_f = f
	if _lykta != null:
		_lykta.light_energy = _lykta_energi * _ljus_f
	for l in _lågor:
		if is_instance_valid(l):
			l.light_energy = LAGA_ENERGI * _ljus_f


## GLANSEN på ljuset: `light_specular` på lyktan och facklorna. EN väg in, av samma skäl som
## `_ljus_styrka`: mätprovet, fladdret och världsbygget ska röra samma egenskap, annars mäter provet
## en kopia av mekanismen. (Fladdret rör bara ENERGI, så glansen står still mellan bildrutorna.)
func _glans_styrka(v: float) -> void:
	_ljus_glans = v
	if _lykta != null:
		_lykta.light_specular = v
	for l in _lågor:
		if is_instance_valid(l):
			l.light_specular = v


## Ytans spegling ur materialets EGEN ORM-råhet: en yta som är mattare än `YTGLANS_TRÖSKEL` får ingen
## spegling alls (`SPECULAR_DISABLED`), en blankare behåller GGX. EN regel, delad av världsbygget och
## mätprovet (`_yta_glans_svep`) — annars mäter provet en kopia av mekanismen i stället för mekanismen
## (samma läxa som `_ljus_styrka`). Se YTGLANS_TRÖSKEL för varför det måste vara per yta.
func _yta_glans(m: StandardMaterial3D, tröskel: float) -> void:
	var matt := m.roughness_texture == null      # ingen karta = ingen kunskap = matt
	if not matt:
		# FUKTEN, inte medelvärdet (M59): en vägg med våta rinningar har HÖG medelråhet (stenen runt
		# omkring är torr) och blev därför "matt" — och då syntes ingen högdager alls på det blöta.
		# Frågan är i stället hur STOR del av ytan som är blöt (råhet under GLANS_BLÖT), för det är
		# den delen som ska glänsa. Utan blöta pixlar blir ytan matt som förut.
		var blöt := _blöt_andel(m.roughness_texture, GLANS_BLÖT)
		matt = blöt < tröskel
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED if matt else BaseMaterial3D.SPECULAR_SCHLICK_GGX


## Hur stor del av ORM-kartans G-kanal (råheten) som är BLÖT: pixlarna i kartans nedersta
## råhets-band. 0..1, cachat per textur som _radhet — samma ruta ritas av hundratals instanser.
##
## VARFÖR BANDET OCH INTE EN FAST GRÄNS (M59): kartans värden kommer ur Godots import och en fast
## gräns i "linjära" tal mötte fel tal — provet gav 0 % blött och ALLA ytor blev matta, trots att
## filerna har 3-17 % vatten (mätt ur PNG:n). Ett band räknat ur kartans EGNA min och max är
## oberoende av vilket talområde importen landar i (en monoton omvandling bevarar rangordningen).
##
## En karta utan spridning är TORR: sten med naturlig nyansskillnad har några procent i spridning,
## och att kalla den blöt vore att sätta glans på allt (den mjölkiga rutan i YTGLANS_TRÖSKEL).
const BLÖT_BAND := 0.35
const BLÖT_SPRIDNING := 0.25

func _blöt_andel(orm: Texture2D, gräns: float) -> float:
	if orm == null:
		return 0.0
	var nyckel := orm.get_instance_id()
	if _blöt_cache.has(nyckel):
		return _blöt_cache[nyckel]
	var andel := 0.0
	var img := orm.get_image()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		var d := img.get_data()
		var n := img.get_width() * img.get_height()
		var lägst := 255
		var högst := 0
		for i in n:
			var v := int(d[i * 4 + 1])
			lägst = mini(lägst, v)
			högst = maxi(högst, v)
		if float(högst - lägst) / 255.0 >= BLÖT_SPRIDNING:
			var band := float(lägst) + float(högst - lägst) * BLÖT_BAND
			var antal := 0
			for i in n:
				if float(int(d[i * 4 + 1])) < band:
					antal += 1
			andel = float(antal) / float(maxi(n, 1))
	_blöt_cache[nyckel] = andel
	return andel


## Råheten i ORM-kartans G-kanal som ett medelvärde per ruta (glTF-ordningen R ocklusion, G råhet,
## B metall). Läses ur BYTEN och cachas per textur: en 64x64-ruta är 4096 pixlar och samma ruta ritas
## av hundratals instanser, så en get_pixel-loop hade kostat i världsbygget.
func _radhet(orm: Texture2D) -> float:
	if orm == null:
		return 1.0
	if _radhet_cache.has(orm):
		return _radhet_cache[orm]
	var r := 1.0
	var img := orm.get_image()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
		var d := img.get_data()
		var n := img.get_width() * img.get_height()
		var sum := 0.0
		for i in n:
			sum += float(d[i * 4 + 1])
		r = sum / (255.0 * float(maxi(n, 1)))
	_radhet_cache[orm] = r
	return r


## Materialen som ritas på de STORA ytorna (golv, vägg, tak) — MultiMesh-instanserna, alltså den väg
## renderaren själv går. Facklans delar och pölarna är MeshInstance3D respektive en ShaderMaterial.
func _ytmaterial() -> Array:
	var ut: Array = []
	if world == null:
		return ut
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm == null or not (mm.mesh is PrimitiveMesh):
			continue
		var m: Material = (mm.mesh as PrimitiveMesh).material
		if m is StandardMaterial3D and not ut.has(m):
			ut.append(m)
	return ut


## Mätprovets ratt för ytornas spegling, med ett tecken: `v >= 0` är TRÖSKELN i regeln (`_yta_glans`),
## `v = -1` ger ALLA ytor spegling (GGX, Godots standard = läget FÖRE ändringen) och `v = -2` stänger av
## den på alla (flit-bort: var kom lyftet i bilden ifrån?). Svarar med hur många material den tog i.
func _yta_glans_svep(v: float) -> int:
	var ut: Array = _ytmaterial()
	for m in ut:
		if v < -1.5:
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		elif v < 0.0:
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		else:
			_yta_glans(m, v)
	return ut.size()


## MÄTNINGEN av figurerna (M59, rättad M69): hur många fiende-figurer som finns i vyn och hur många av
## dem som bär ett `material_override`. NOLL override är det rätta svaret — en override tar bort rutnätet
## och figuren ritas som en nål (mätt: 73 px mot 22 641 px, se `_add_enemies`). Egen funktion så provet
## läser samma sanning som vyn visar i stället för att räkna noder på egen hand.
## FIGURPROVET (M59). Alex: *"att fiender har någon form av material så de inte ser ut som blank
## wellpapp"* och *"så väggar kan se fuktiga ut, så det blänker gentemot ljus osv"*. Det är en
## BILD-fråga, så provet lämnar både siffror och en bild: går till ett rum med fiender, mäter hur
## många figurer som ritas matta (speglingen av), hur många ytor som är glansiga, och sparar vyn.
func _figurprov() -> void:
	var nod: Dungeon.FloorNode = null
	for n in run.explore.floor_ref.nodes_of_kind("encounter"):
		nod = n
		break
	if nod == null:
		print("figurprov: våningen har ingen strid att stå i")
		get_tree().quit()
		return
	await _gå_till_och_vänd(nod.pos)
	for i in 30:
		await get_tree().process_frame
	var fig := _figurmaterial_prov()
	var mörka := 0
	var glansiga := 0
	for m in _ytmaterial():
		if m.specular_mode == BaseMaterial3D.SPECULAR_DISABLED:
			mörka += 1
		else:
			glansiga += 1
	print("[figurprov] figurer i vyn: %d, varav med material_override: %d (ska vara 0) | ytor: %d matta, %d glansiga"
		% [fig["antal"], fig["blanka"], mörka, glansiga])
	# VAR STÅR FIGURERNA, I METER? Alex: *"spökena står på sidan när man möter dem, även andra
	# fiender — har det att göra med hur trångt det är i gången?"* Frågan besvaras med spelets egna
	# tal i stället för med ögat: figurens avvikelse från sin rutas mitt, hur bred figuren är i meter
	# och om rutan har golv bredvid (det som avgör sidledsspridningen).
	var spelare := _cam_pos()
	# Varför blir figuren en REMSA? Läs MEKANISMEN på plats i stället för att gissa: rutnätet (hframes)
	# och materialets albedo/uv-mappning är de två sakerna som bestämmer hur bred figuren ritas.
	for e in _enemies.slice(0, 1):
		var s0: Sprite3D = e.get("spr")
		if s0 == null:
			continue
		var mt: Material = s0.material_override
		var al: Texture2D = (mt as StandardMaterial3D).albedo_texture if mt is StandardMaterial3D else null
		var uv: Vector3 = Vector3.ZERO
		var uvo: Vector3 = Vector3.ZERO
		if mt is StandardMaterial3D:
			uv = (mt as StandardMaterial3D).uv1_scale
			uvo = (mt as StandardMaterial3D).uv1_offset
		print("[figurprov] figurens duk: %dx%d, hframes %d vframes %d, ruta %d, pixel_size %.4f, quad %.2f x %.2f m"
			% [s0.texture.get_width(), s0.texture.get_height(), s0.hframes, s0.vframes, s0.frame,
				s0.pixel_size, s0.texture.get_width() / float(maxi(1, s0.hframes)) * s0.pixel_size,
				s0.texture.get_height() / float(maxi(1, s0.vframes)) * s0.pixel_size])
		print("[figurprov] figurens material: %s, albedo %s (%s), uv1_scale %s, uv1_offset %s, region_enabled %s"
			% [mt.get_class() if mt != null else "inget", al.get_class() if al != null else "inget",
				al.resource_path if al != null else "-", str(uv), str(uvo), str(s0.region_enabled)])
	for e in _enemies:
		var spr: Sprite3D = e.get("spr")
		if spr == null or not is_instance_valid(spr):
			continue
		var fnod: Vector2i = e.get("nod")
		# VAR PÅ SKÄRMEN hamnar figuren, och hur stor SYNS den? Mätt som px i spelvyn: en figur som
		# står mitt för spelaren ska ha sin x nära vyns mitt (640) och vara många tiotal px bred — en
		# smal "nål" i bild betyder att något annat än konsten bestämmer bredden.
		var skärm := "utanför vyn"
		if cam.is_position_in_frustum(spr.global_position):
			var p0 := cam.unproject_position(spr.global_position)
			var ptopp := cam.unproject_position(spr.global_position + Vector3(0.0, 0.62, 0.0))
			var pbotten := cam.unproject_position(spr.global_position - Vector3(0.0, 0.58, 0.0))
			var psida := cam.global_transform.basis.x * (80.0 * spr.pixel_size * 0.5)
			var pv := cam.unproject_position(spr.global_position - psida)
			var ph := cam.unproject_position(spr.global_position + psida)
			skärm = "på skärmen x %.0f (vyns mitt 640, avvikelse %+.0f px), höjd %.0f px, bredd %.0f px (förhållande 1:%.1f)" % [
				p0.x, p0.x - 640.0, absf(ptopp.y - pbotten.y), absf(ph.x - pv.x),
				absf(ptopp.y - pbotten.y) / maxf(1.0, absf(ph.x - pv.x))]
		print("[figurprov] figur vid ruta %s: x %.2f (rutans mitt %.2f, avvikelse %+.3f m), z %.2f (djup %+.2f m mot spelaren), figuren %.2f m bred, golv bredvid: %s, spelaren (%.2f, %.2f), i vyn: %s, %s"
			% [str(fnod), spr.position.x, fnod.x + 0.5, spr.position.x - (fnod.x + 0.5), spr.position.z,
				spr.position.z - spelare.z, 80.0 * spr.pixel_size, str(_golv_bredvid(fnod)),
				spelare.x, spelare.z, str(cam.is_position_in_frustum(spr.global_position)), skärm])
	# Och VILKEN RUTA varje yta bär: taket ska bära temats tak-ruta, inte väggens.
	var sedda := {}
	for m in _ytmaterial():
		if m.albedo_texture != null and not sedda.has(m.albedo_texture.resource_path):
			sedda[m.albedo_texture.resource_path] = true
	var sökta := sedda.keys()
	sökta.sort()
	for s in sökta:
		print("[figurprov] yta: %s" % s)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_spara_bild("user://shots/figur-01-material.png")
	print("[figurprov] bild: %s" % ProjectSettings.globalize_path("user://shots/figur-01-material.png"))
	get_tree().quit()


func _figurmaterial_prov() -> Dictionary:
	var antal := 0
	var med_override := 0
	for n in get_tree().get_nodes_in_group("fiende_figur"):
		if not (n is Sprite3D):
			continue
		antal += 1
		if (n as Sprite3D).material_override != null:
			med_override += 1
	return {"antal": antal, "blanka": med_override}


func _järndelar() -> Array:
	var ut: Array = []
	for n in get_tree().get_nodes_in_group("fackla"):
		if not (n is MeshInstance3D) or n.mesh == null:
			continue
		if not str(n.get_meta("del", "")).begins_with("fackla_"):
			continue
		if not _är_järn(str(n.get_meta("del", ""))):
			continue                        # trä, inte järn (se `_fackel_geometri`)
		var m: Material = (n as MeshInstance3D).mesh.material
		if m is StandardMaterial3D and not ut.has(m):
			ut.append(m)
	return ut


## Pölnoden: pölplattorna ligger i EN MultiMesh som heter "pölar" (se `_pölar`), så både materialet
## och plattornas positioner går att läsa ur den.
func _pölnod() -> MultiMeshInstance3D:
	if world == null:
		return null
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		if n.name == "pölar" and (n as MultiMeshInstance3D).multimesh != null:
			return n
	return null


## Vattnets material: pölplattornas mesh bär shadern som ger glansen (`Fx.pöl_material`). Råheten
## (0,05) är vätan; metallen är YTANS andel av speglingen, och den provas i `_glansprov`.
func _pöl_material() -> ShaderMaterial:
	var nod := _pölnod()
	if nod == null:
		return null
	var m: Material = nod.multimesh.mesh.material
	return m if m is ShaderMaterial else null


## Lyktan i handen: ett ljus som följer kameran. Utan den är våningen antingen platt upplyst (allt
## syns, ingen stämning) eller svart (inget syns) — det är avståndet till ljuset som gör rummet.
func _add_lykta() -> void:
	_lykta = OmniLight3D.new()
	_lykta.light_color = LYKTA_FARG
	_lykta.light_energy = _lykta_energi * _ljus_f
	_lykta.omni_range = LYKTA_RACKVIDD
	_lykta.omni_attenuation = _lykta_falloff   # mjukare falloff än ren inverskvadrat, för pixelkonsten
	_lykta.light_specular = _ljus_glans          # GLANSEN: ljuset ska kunna ge högdagrar (se LJUS_GLANS)
	_lykta.shadow_enabled = _skugga
	_lykta.shadow_bias = 0.06                  # 1x1-block mot 1x1-block: standard ger randiga skuggor
	_lykta.position = Vector3(0.0, 0.25, 0.15) # strax framför och över ögat, som en lykta i handen
	# Hur mycket av lyktans ljus som syns i LUFTEN (den volymetriska dimman). Utan den här raden
	# lyser lyktan bara på stenen: ljuskäglan finns i miljön men inte i ljuset från handen.
	_lykta.light_volumetric_fog_energy = 1.0
	cam.add_child(_lykta)

## Facklorna: ett ljus per fackla i våningen. De är rummets egna ljuspunkter — en fackla som inte
## lyser är bara en bild av en fackla.
##
## LJUSET RITAS ÄVEN FÖR EN TÖMD FACKLA. Villkoret var `n.cleared` förut, och då slocknade elden i
## samma stund som man klev på rutan (Alex: *"varför försvinner elden om man går på den? Det är
## menat som ljuskälla."*). Noden är visserligen plockbar — vilan läker en gång, och det styr
## `cleared` — men en ljuskälla är en ljuskälla: belöningen tas en gång, hållaren står kvar och
## lågan brinner vidare. Provet för det ligger i tests/test_fackla.gd.
func _add_lagor(f: Dungeon.Floor) -> void:
	_lågor.clear()
	for n in f.nodes:
		if n.kind != "torch":
			continue
		# Var facklan sitter: på väggen i den första rutan som inte är golv. Står rutan fritt (en
		# genererad våning kan lägga facklan mitt i ett rum) får den en ställning på golvet i
		# stället — en låga utan hållare är en fläck i luften.
		var sida := _vägg_sida(f, n.pos)
		var ut := _ut_från_vägg(sida)
		var låga_pos := _fackel_låga(n.pos, ut)
		var ljus := OmniLight3D.new()
		ljus.light_color = LAGA_FARG
		ljus.light_energy = LAGA_ENERGI * _ljus_f
		ljus.omni_range = LAGA_RACKVIDD
		ljus.omni_attenuation = 1.6
		ljus.light_specular = _ljus_glans
		ljus.shadow_enabled = false            # flera skuggande punktljus per våning kostar mer än det ger
		# Facklans ljus i dimman: det är käglan runt lågan som gör elden till en LJUSKÄLLA och inte
		# till en orange fläck. Energin är högre än lyktans — facklan ska synas på håll i en korridor.
		ljus.light_volumetric_fog_energy = 2.2
		# Ljuset sitter I LÅGAN, inte i golvrutan: en eld i ögonhöjd lyser rummet, en eld på golvet
		# lyser bara sin egen fläck. Lyktan i handen står på 0,5 m, så en fackla på 1,3 m är över
		# spelarens huvud — som en fackla på en vägg ska vara.
		ljus.position = låga_pos
		world.add_child(ljus)
		_lågor.append(ljus)
		if _fx:
			# Hållaren, skaftet och huvudet. Geometrin byggs bara när elden ritas (`fx=0` är ett
			# mätläge), men LÅGANS POSITION räknas alltid ur samma funktion — annars kunde ljuset
			# och elden hamna på olika ställen i de två lägena.
			_fackel_geometri(n.pos, ut)
			Fx.fackla(world, låga_pos, 0.9)


## Väggsidan en fackla hänger på: den första grannrutan som INTE är golv, i en fast ordning så
## samma våning alltid ser likadan ut. Noll = rutan står fritt, ingen vägg finns.
func _vägg_sida(f: Dungeon.Floor, p: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if not f.is_floor_at(p + d):
			return d
	return Vector2i.ZERO


## Riktningen UT från väggen och in i rummet. Noll = ingen vägg (facklan står fritt).
func _ut_från_vägg(sida: Vector2i) -> Vector3:
	if sida == Vector2i.ZERO:
		return Vector3.ZERO
	return Vector3(-sida.x, 0, -sida.y)


## Skaftets lutning ut från väggen. Lågan ska en bit in i rummet, inte in i stenen.


## Skaftets riktning: upp, lutad ut från väggen med LAGA_LUTNING grader.
func _fackel_axel(ut: Vector3) -> Vector3:
	var u: Vector3 = ut if ut != Vector3.ZERO else Vector3(0, 0, 1)
	var lut := deg_to_rad(LAGA_LUTNING)
	return (Vector3.UP * cos(lut) + u * sin(lut)).normalized()


## Kransens mitt — punkten skaftet sitter i. REN räkning (inga noder): lågan, ljuset och geometrin
## måste komma ur samma tal, annars glider elden och ljuset ifrån hållaren.
##
## Höjden räknas NEDÅT från taket: lågan ska ha LAGA_TAK_AVSTÅND luft kvar upp till TAK_HÖJD, så
## kransen hamnar så mycket lägre som skaftets egen höjd (LAGA_HUVUD gånger cosinus för lutningen).
## Därför kan facklan inte skära genom taket hur rummet än byggs.
func _fackel_krans(p: Vector2i, ut: Vector3) -> Vector3:
	var c := Vector3(p.x + 0.5, 0, p.y + 0.5)
	var höjd := TAK_HÖJD - LAGA_TAK_AVSTÅND - LAGA_HUVUD * cos(deg_to_rad(LAGA_LUTNING))
	if ut == Vector3.ZERO:
		return c + Vector3(0, höjd, 0)
	return c - ut * 0.39 + Vector3(0, höjd, 0)


## Lågans position — där elden ritas och ljuset sitter.
func _fackel_låga(p: Vector2i, ut: Vector3) -> Vector3:
	return _fackel_krans(p, ut) + _fackel_axel(ut) * LAGA_HUVUD


## Facklan som föremål: järnplatta mot väggen, krans, tjärdoppat träskaft och ett svedt huvud.
##
## VARFÖR GEOMETRI OCH INTE EN BILD: två tidigare försök var plattor på golvet. Först en stencylinder
## (Alex: *"grå kullar på nästan varje golvruta"*), sedan en tunn svedd skiva under lågan. Skivan
## hade ingen form alls — bildgranskaren beskrev den som *"an elliptical, reddish-brown disc/pad
## lying flat on the floor"*, och Alex frågade vad det var: en fackla på väggen eller ved på golvet,
## inte en konturlös oval. En platta kan heller inte kasta skugga, och det är skuggan och siluetten
## som gör att en sak läser som en sak i en mörk korridor.
##
## Allt är primitiver: ingen bildfil, inget nytt beroende.
func _fackel_geometri(p: Vector2i, ut: Vector3) -> void:
	var c := Vector3(p.x + 0.5, 0, p.y + 0.5)
	var järn := Color(0.20, 0.20, 0.24)
	# Skaftets lutning ut från väggen: "ut" är riktningen in i rummet, och står facklan fritt får
	# den luta mot +z (det finns ingen vägg att luta ifrån).
	var u: Vector3 = ut if ut != Vector3.ZERO else Vector3(0, 0, 1)
	var x := Vector3.UP.cross(u).normalized()
	var krans := _fackel_krans(p, ut)
	var axel := _fackel_axel(ut)
	if ut == Vector3.ZERO:
		# Fri ruta: en ställning. Fot, stolpe, krans — samma krans som på väggen, så facklan ser ut
		# som samma sak var den än står. Stolpen går från golvet upp till kransen.
		_del(_cyl(0.11, 0.03), järn, c + Vector3(0, 0.015, 0), "fackla_fot",
			Transform3D(), JARN_RAHET)
		_del(_cyl(0.026, krans.y), järn, c + Vector3(0, krans.y * 0.5, 0), "fackla_stolpe",
			Transform3D(), JARN_RAHET)
		_del(_cyl(0.045, 0.09), järn, krans, "fackla_krans",
			Transform3D(), JARN_RAHET)
	else:
		# Plattan ligger mot stenen, kransen sitter en bit ut från den.
		_del(_box(0.14, 0.16, 0.05), järn, c - ut * 0.475 + Vector3(0, krans.y, 0),
			"fackla_platta", _bas(x, Vector3.UP, u), JARN_RAHET)
		_del(_cyl(0.045, 0.09), järn, krans, "fackla_krans", _bas(x, Vector3.UP, u),
			JARN_RAHET)
	# Skaftet: tjockare nedtill, som en pinne. Trä, inte järn: halvblankt (0,72) och omagnetiskt.
	_del(_cyl_topp(0.020, 0.030, LAGA_SKAFT), Color(0.30, 0.18, 0.09), krans + axel * (LAGA_SKAFT * 0.5),
		"fackla_skaft", _bas(x, axel, x.cross(axel)), 0.72)
	# Huvudet: tjärdoppat och svedt — det är den delen som brinner, och den ska vara mörk mot lågan.
	_del(_cyl_topp(0.042, 0.033, 0.12), Color(0.11, 0.08, 0.06), krans + axel * (LAGA_HUVUD - 0.06),
		"fackla_huvud", _bas(x, axel, x.cross(axel)))


## En ortonormal bas: x och y är riktningar, z räknas fram. Håller meshen rättvänd (en bas med fel
## tecken ritar insidan utåt och släcker ytan).
func _bas(x: Vector3, y: Vector3, z: Vector3) -> Transform3D:
	return Transform3D(Basis(x.normalized(), y.normalized(), z.normalized()), Vector3.ZERO)


## Kistans egen vinkel: framsidan (låset och lockets kant) vänder sig mot rutan spelaren kommer
## ifrån, så man möter kistans framsida och inte dess gavel. Kistan står alltså i VÄRLDENS axlar med
## sin egen orientering — det är just det en skylt inte har (MÄTT: bredden på skärmen var 66 px från
## alla fyra håll, förhållande 1,00, se `-- kistnara`).
func _kista_vinkel(n: Dungeon.FloorNode) -> float:
	var från := _granne(n.pos)
	if från == Vector2i(-1, -1):
		return 0.0                          # ingen granne att komma ifrån: står i världens axel
	var d := Vector2(n.pos - från)          # från kistan mot spelarens ruta
	return atan2(d.x, d.y)                  # +z i kistans eget mått pekar mot spelaren


## KISTAN SOM FÖREMÅL: byggd av primitiver — kropp, lock med gångjärn, två järnband och ett lås.
##
## VARFÖR GEOMETRI (M32): kistan var en `Sprite3D` med billboard, och båda felen Alex såg kommer ur
## det. MÄTT i `-- kistnara` med kameran i 0,1 m-steg in i kistans egen ruta: djupet går från 1,00 m
## till −0,00 m och vid 0,0 ligger ALLA fyra hörnen innanför närplanet (4/4 klippta, 0 av 1 px kvar i
## bilden) — en skylt står i kamerans eget plan, så den klipps bort i samma stund spelaren står på
## rutan. En byggd kista har sina hörn i världen: kameran står då 0,5 m över en 0,45 m hög kista och
## ser locket underifrån i stället för ingenting.
##
## ÖPPEN kista: locket vrids −100° kring gångjärnet och står kvar. Noden är avklarad och ritar
## ingenting annars — men Alex: *"Kistor försvinner när man kommer nära, det får de inte göra"*, och
## en plats där något plundrats ska se plundrad ut, inte tom ut.
func _kista_geometri(n: Dungeon.FloorNode, öppen: bool) -> void:
	var c := Vector3(n.pos.x + 0.5, 0.0, n.pos.y + 0.5)
	var yaw := Basis(Vector3.UP, _kista_vinkel(n))
	# Färgerna ur paletten (assets/palette.json), som rutorna: träet ur jord/trä-skalan och järnet ur
	# den kalla skalan. MÄTT i en bildgranskning av den färdiga kistan: banden lästes som "a lighter
	# tan band i samma ton som träet" när de var varma grå — järnet ska vara KALLT mot träet.
	var trä := Palett.c(17)                  # (96,68,44)
	var järn := Palett.c(19)                 # (44,58,70)
	var fot := 0.05                          # fötterna: kistan står på dem, inte i golvet
	# Kroppen: 0,52 x 0,30 x 0,36 m. Fötterna är fyra klossar i hörnen — de ger siluetten en undersida
	# och en skugga, som en platta på golvet aldrig får.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_del(_box(0.08, fot, 0.08), trä, c + yaw * Vector3(sx * 0.20, fot * 0.5, sz * 0.12),
				"kista_fot", Transform3D(yaw, Vector3.ZERO), 0.85, "kista")
	_del(_box(0.52, 0.30, 0.36), trä, c + yaw * Vector3(0, fot + 0.15, 0),
		"kista_botten", Transform3D(yaw, Vector3.ZERO), 0.85, "kista")
	# Järnbanden runt kroppen: TUNNA i x (ett band över locket, inte en platta) och en aning djupare och
	# högre än träet, annars ligger de inuti och syns inte. MÄTT: ett band som var 0,555 brett i x gav
	# kistan en världsruta på 0,855 i stället för 0,555 — det stack ut 0,19 på var sida.
	for bx in [-0.15, 0.15]:
		_del(_box(0.05, 0.31, 0.375), järn, c + yaw * Vector3(bx, fot + 0.15, 0),
			"kista_band", Transform3D(yaw, Vector3.ZERO), JARN_RAHET, "kista")
	# Låset sitter på framsidan och stannar där när locket fälls upp.
	_del(_box(0.11, 0.13, 0.05), järn, c + yaw * Vector3(0, fot + 0.24, 0.19),
		"kista_lås", Transform3D(yaw, Vector3.ZERO), JARN_RAHET, "kista")
	# En plundrad kista är ÖPPEN och därmed TOM: en mörk platta innanför kanten läses som hålet, och
	# utan den ser kroppen ut som en sluten låda med locket lyft ur den. Ingen urholkning i meshen —
	# en platta räcker, och den ritar ingen insida som kan hamna fel.
	if öppen:
		_del(_box(0.44, 0.04, 0.28), Color(0.05, 0.04, 0.04), c + yaw * Vector3(0, fot + 0.28, 0),
			"kista_inre", Transform3D(yaw, Vector3.ZERO), 1.0, "kista")
	# Locket: gångjärnet ligger i bakkanten på kroppens överkant. Locket vrids kring DEN linjen, inte
	# kring sin egen mitt (en dörr som roterar om sin mitt ser ut att lyfta ur gångjärnen).
	var gångjärn := Vector3(0, fot + 0.30, -0.18)
	var till_mitt := Vector3(0, 0.05, 0.18)  # från gångjärnet till lockets mitt, stängt läge
	var vrid := Basis(Vector3(1, 0, 0), deg_to_rad(-100.0)) if öppen else Basis.IDENTITY
	var lock_mitt: Vector3 = gångjärn + vrid * till_mitt
	_del(_box(0.54, 0.10, 0.38), trä, c + yaw * lock_mitt, "kista_lock",
		Transform3D(yaw * vrid, Vector3.ZERO), 0.85, "kista")
	for bx in [-0.15, 0.15]:
		_del(_box(0.05, 0.11, 0.395), järn, c + yaw * (lock_mitt + vrid * Vector3(bx, 0, 0)),
			"kista_band_lock", Transform3D(yaw * vrid, Vector3.ZERO), JARN_RAHET, "kista")


func _cyl(r: float, h: float) -> CylinderMesh:
	return _cyl_topp(r, r, h)


func _cyl_topp(r_topp: float, r_botten: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_topp
	m.bottom_radius = r_botten
	m.height = h
	return m


func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


## En del av facklan. Egen yta (`råhet` 0,55 för JÄRNET, 0,72 för träskaftet, 0,85 för det tjärade
## huvudet), och skugga PÅ — det är halva skillnaden mot en platta på golvet.
##
## METALLEN ÄR 0, OCH DET ÄR MÄTT: `metallic` 0,7 på järndelarna (både vid råhet 0,55 och 0,25) gör
## plattan MÖRKARE (upp till −126 av 255 i de värsta bildpunkterna) utan en enda ljus högdager i rutan
## — en metallisk yta tappar sin albedo till en spegling, och i en mörk korridor finns inget att
## spegla. Se PLAN.md M27: vision läser den som *"darker and flatter"*, inte som polerad. Glansen ska
## komma från LJUSET på en blank yta, inte från en metallkonstant.
##
## Delen hamnar i gruppen "fackla" (eller den man anger: kistan byggs av samma hjälpare och hamnar i
## "kista"). Namnet duger INTE som kännetecken: Godot gör dubbletter unika med ett @-suffix
## ("@fackla_platta@2"), så ett prov som letar på "fackla_*" hittar bara den FÖRSTA facklans delar
## (mätt: 4 av 24 noder). Gruppen kan inte döpas om.
func _del(mesh: Mesh, färg: Color, pos: Vector3, namn := "", bas := Transform3D(),
		råhet := 0.85, grupp := "fackla") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = färg
	# JÄRNET BLIR METALL (M59): samma del, men en spegel i stället för ett färgat papper. Trädelarna
	# (skaftet och huvudet) behåller sin matta yta — frågan ställs till `_är_järn`, samma funktion som
	# provet använder, så materialet och provet inte kan svara olika.
	var järn := _är_järn(namn)
	m.roughness = JARN_RAHET_METALL if järn else råhet
	m.metallic = JARN_METALL if järn else 0.0
	if järn:
		# KANTEN BÄR METALLEN I MÖRKER. Mätt: metallic 0,85 med råhet 0,30 gav ingen synlig glans i
		# korridoren — en metall speglar bara det som finns i den riktning ytan pekar, och i en mörk
		# gång finns inget där. Fresnel-kanten lyfter i stället ytans rand mot kameran, och det är
		# den randen ögat läser som metall (samma knep som stiliseringen använder i referensen).
		# Provet fäller en figur vars järn tappar kanten.
		m.rim_enabled = true
		m.rim = JARN_RIM
		m.rim_tint = 1.0
	# Speglingsläget: GGX, så en högdager KAN bildas här. Det är ljusets `light_specular` och ytans
	# råhet som avgör om den syns — järnet (0,30) är blankare än stenen (0,94) och får därför en.
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mesh.material = m
	mi.transform = Transform3D(bas.basis, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.name = namn if not namn.is_empty() else "fackla_del"
	mi.add_to_group(grupp)
	# Namnet kan Godot döpa om, meta kan den inte: provet läser VILKEN del det är ur metan.
	if not namn.is_empty():
		mi.set_meta("del", namn)
	world.add_child(mi)
	return mi


## Elden, vattnet och dammet. Elden hör till facklorna (se `_add_lagor`); här byggs resten:
##
##   dammet     sitter på kameran, för damm syns bara i ljuset — ett korn i mörkret är ingenting.
##   pölarna    en blank platta över det vatten som redan är MÅLAT i rutan. Rutans vatten ligger på
##              samma ställe i varje kopia av rutan (2x2 per meter), så plattan läggs ut 2x2 per
##              ruta — annars hamnar glansen bredvid vattnet.
##   dropparna  faller från taket ner i pölen, och från väggen där vattnet rinner. Fallsträckan
##              räknas fram, så droppen dör i samma stund som den når marken.
##
## Allt är samma sak som pixelkonsten redan säger, men i rörelse: kartan vet var vattnet är,
## `_vatten.json` talar om det, och den här koden gör något av det.
func _vatten_och_eld(f: Dungeon.Floor, slitet_golv: Array, sliten_vägg: Array) -> void:
	var pöl := _vatten_ruta("floor_crack")
	var mask := _tile("floor_crack_vatten", true)
	# Vattnet rinner ut ur väggen även där golvet inte har någon pöl (bron: trasiga plankor, inget
	# vatten i golvet). Lägg inte hela funktionen bakom pöl-kontrollen — då tystnar dropparna också.
	var har_pöl := not pöl.is_empty() and not slitet_golv.is_empty() and mask != null
	if har_pöl:
		har_pöl = Fx.pöl_material(mask, pöl) != null
	if har_pöl:
		_pölar(pöl, mask, slitet_golv)
	# Dropparna: inte i varje pöl — droppar överallt blir ett regn, och regn är en annan våning.
	for p in slitet_golv:
		if not _strö(p, 3):
			continue
		# Droppen faller mitt i pölen när våningen har en, annars mitt i rutan.
		var dx: float = p.x + 0.5
		var dz: float = p.y + 0.5
		if har_pöl:
			dx = p.x + (pöl[0] + pöl[2] * 0.5) / 64.0
			dz = p.y + (pöl[1] + pöl[3] * 0.5) / 64.0
		_droppställe(_dropprng, Vector3(dx, TAK_HÖJD - 0.06, dz), "vatten", _strö(p, 8))
	# Vattnet på väggen: en droppe då och då framför rutan där vattnet är MÅLAT, så det inte bara
	# glänser. Det ska droppa, inte rinna — väntan mellan dropparna ligger i Fx.DROPP_VÄNTAN, och
	# ett enstaka ställe per våning får en accent (tätare).
	for p in sliten_vägg:
		if not _strö(p, 5):
			continue
		var sida := _öppen_sida(f, p)
		if sida == Vector2i.ZERO:
			continue
		_droppställe(_dropprng,
			Vector3(p.x + 0.5 + sida.x * 0.35, TAK_HÖJD - 0.06, p.y + 0.5 + sida.y * 0.35), "vatten", _strö(p, 12))


## Ett droppställe: en droppe som väntar på sin tur i stället för att falla i ett flöde.
##
## Klockan ägs av `_droppa` (main.gd), inte av partikelnoden: `one_shot` + `restart()` är det enda
## sättet att ha kvar falltiden som den är och ändå få pauser mellan dropparna (se Fx.DROPP_VÄNTAN).
func _droppställe(rng: RandomNumberGenerator, pos: Vector3, slag: String, accent: bool = false) -> void:
	var p := Fx.droppar(world, pos, 0.9, slag)
	p.emitting = false                     # ingen droppe förrän väntan är slut
	# Första väntan är kortare: ett ställe som stått tyst i flera sekunder när man kommer in i rummet
	# ser trasigt ut, och provet (`nodprov=dropp`) ska hinna fotografera en droppe i luften.
	_droppar.append({"nod": p, "kvar": rng.randf_range(0.15, 1.2), "accent": accent, "rng": rng})


## Dropparna faller när väntan är slut — inte i ett jämnt flöde.
##
## Väntan dras om varje gång ur samma väntan-funktion som provet räknar droppar per minut ur, så
## takten är ojämn hela tiden och provet mäter spelets takt och inte sin egen kopia av den.
func _droppa(delta: float) -> void:
	for d in _droppar:
		d["kvar"] = float(d["kvar"]) - delta
		if d["kvar"] > 0.0:
			continue
		var p: GPUParticles3D = d["nod"]
		if is_instance_valid(p):
			p.restart()                    # EN droppe. Falltiden är orörd.
		d["kvar"] = Fx.dropp_väntan(d["rng"], d["accent"])


## Pölplattorna: rutans vatten i rutans egen form, 2x2 per meter som golvplattan, med shadern som ger
## glans och rullande krusning. Masken (Assets/tiles/<tema>/<ruta>_vatten.png) är vattnets form —
## plattan ritar inget där rutan är torr.
func _pölar(pöl: Array, mask: Texture2D, slitet_golv: Array) -> void:
	var material := Fx.pöl_material(mask, pöl)
	if material == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Ruttätheten LÄSES ur texturen i stället för att stå som en siffra. Den stod som 32,0 medan
	# rutorna var 32 px; när de blev 64 px blev pölarna dubbelt så stora och hamnade fel, utan att
	# något larmade. Med texturens bredd kan de inte drifta isär igen.
	var ruta_px := float(_tile("floor_crack_vatten", true).get_width())
	var platta := PlaneMesh.new()
	platta.size = Vector2(pöl[2] / ruta_px * 0.5, pöl[3] / ruta_px * 0.5)
	platta.material = material
	mm.mesh = platta
	mm.instance_count = slitet_golv.size() * 4
	var i := 0
	for p in slitet_golv:
		for j in 2:
			for k in 2:
				var t := Transform3D()
				t.origin = Vector3(p.x + (j + (pöl[0] + pöl[2] * 0.5) / ruta_px) * 0.5, 0.045,
					p.y + (k + (pöl[1] + pöl[3] * 0.5) / ruta_px) * 0.5)
				mm.set_instance_transform(i, t)
				i += 1
	var mi := MultiMeshInstance3D.new()
	mi.name = "pölar"
	mi.multimesh = mm
	world.add_child(mi)


## Vad som får droppa i en våning beror på temat — en bro av trä droppar inte lava. Grunden är alltid
## vatten, så varje våning har något som faller.
const TAKDROPP_SLAG := {
	"bro": ["vatten"],
	"aske": ["vatten", "blod"],
	"krypta": ["vatten", "blod", "slem"],
	"tunnel": ["vatten", "blod", "slem"],
	"grotta": ["vatten", "slem", "lava"],     # lavan hör till djupet, inte till plankorna
}


## Takdropp: enstaka ställen på våningen där det faller från taket — vatten, slem, blod eller lava.
##
## Alex: *"kan vi ha någon form av fx emitter från taken där det droppar allt från vatten, slem till
## blod och lava? Men inte överallt, utan random runtom på banan, i random takt?"*
##
## "Inte överallt" är 3-6 ställen oavsett våningens storlek, och positionerna kommer ur våningens eget
## frö: samma våning ser likadan ut varje gång, så ett skärmbildsprov och Alex tittar på samma sak.
## TAKTEN är olik per ställe (0,7-2,2 gånger grundtakten) — en jämn metronom över hela våningen är
## precis vad "random takt" inte ska vara.
func _takdropp(f: Dungeon.Floor) -> void:
	var slag: Array = TAKDROPP_SLAG.get(_tema, ["vatten"])
	var rng := RandomNumberGenerator.new()
	# Fröet tas ur banans ID (en sträng). INTE ur `run.stage` själv: det är en resurs, och hash() på
	# ett objekt är objektets identitet — alltså olika varje körning. Första försöket gjorde precis det,
	# och samma våning fick olika slags droppar varje gång (mätt: slem×4+lava×1 mot vatten×2+lava×2).
	rng.seed = hash(Vector3i(hash(run.stage.id), f.index, 4711))
	# Golvytorna först, sedan ett urval ur dem: att slumpa rutor och kasta bort de som är vägg ger
	# olika många ställen i olika våningar, och en liten våning kunde bli helt utan.
	var golv := []
	for y in f.h:
		for x in f.w:
			if f.is_floor_at(Vector2i(x, y)):
				golv.append(Vector2i(x, y))
	if golv.is_empty():
		return
	# 6-10 i stället för 3-6: en våning är stor och tre ställen möter man aldrig (Alex: "det droppar
	# inte längre något från taken"). Fler ställen är billiga — varje ställe är en partikel i taget.
	var antal := mini(rng.randi_range(6, 10), golv.size())
	var räknat := {}
	for i in antal:
		var p: Vector2i = golv[rng.randi_range(0, golv.size() - 1)]
		var sort: String = slag[rng.randi_range(0, slag.size() - 1)]
		räknat[sort] = int(räknat.get(sort, 0)) + 1
		var var_det := Vector3(p.x + 0.5 + rng.randf_range(-0.25, 0.25), TAK_HÖJD - 0.06,
			p.y + 0.5 + rng.randf_range(-0.25, 0.25))
		_takställen.append([var_det, sort])
		# Ett ställe per våning är accenten: det droppar tätare (0,6-1,6 s) än de andra (2-6 s).
		_droppställe(rng, var_det, sort, i == 0)
	if OS.get_cmdline_user_args().has("fxprov"):
		print("    takdropp: %d ställen %s" % [antal, str(räknat)])


## Rutans vatten som rektangel [x, y, w, h] i pixlar, ur `assets/tiles/<tema>/_vatten.json` (skriven
## av tools/gen_tiles.py). Saknas filen blir det inga pölar — en våning utan vatten är ingen krasch.
func _vatten_ruta(ruta: String) -> Array:
	var p := "res://assets/tiles/%s/_vatten.json" % _tema
	if _tema.is_empty() or not FileAccess.file_exists(p):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY or not d.has(ruta):
		return []
	return d[ruta]


## Den sida av en väggruta som vetter mot golv — där vattnet rinner ut i rummet. Noll om rutan är
## instängd (då finns det ingen sida att rinna på).
func _öppen_sida(f: Dungeon.Floor, p: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if f.is_floor_at(p + d):
			return d
	return Vector2i.ZERO

## Fladdret: två sinuser med olika frekvens per ljus, så ingen fackla brinner i takt med sin granne.
## Kostar ingenting (några multiplikationer per bildruta) och är skillnaden mellan en lampa och en eld.
func _fladdra(delta: float) -> void:
	_fladder += delta
	Fx.rulla(_fladder)   # krusningen i vattnet rullar i takt med tiden, inte med bildrutorna
	if _lågor.is_empty() and _lykta == null:
		return
	for i in _lågor.size():
		var l: OmniLight3D = _lågor[i]
		var f := 1.0 + 0.10 * sin(_fladder * (6.3 + i * 1.7)) + 0.05 * sin(_fladder * (17.0 + i * 3.1))
		l.light_energy = LAGA_ENERGI * _ljus_f * f
	if _lykta != null:
		_lykta.light_energy = _lykta_energi * _ljus_f * (1.0 + 0.02 * sin(_fladder * 3.1))
func _tile(name: String, tyst: bool = false) -> Texture2D:
	# Temat först, den platta rutan som fallback: en saknad temakatalog ska synas som en platt yta,
	# inte som en krasch eller en osynlig vägg.
	var key := "%s/%s" % [_tema, name]
	if _tile_cache.has(key):
		return _tile_cache[key]
	var tex: Texture2D = null
	for p in ["res://assets/tiles/%s/%s.png" % [_tema, name], "res://assets/tiles/%s.png" % name]:
		if _tema.is_empty() and p.contains("//"):
			continue
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	if tex == null and not tyst:
		push_warning("saknar rutan %s i temat %s — ytan ritas som schackruta" % [name, _tema])
	_tile_cache[key] = tex
	return tex

func _cam_pos() -> Vector3:
	return Vector3(run.explore.pos.x + 0.5, 0.5, run.explore.pos.y + 0.5)

## 8x8 schackruta i två nyanser — ger textur utan att vara en platshållarbild.
func _tex(base: Color) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var dark := (x + y) % 2 == 0
			img.set_pixel(x, y, base.darkened(0.25) if dark else base)
	return ImageTexture.create_from_image(img)

func _animate_cam() -> void:
	if cam == null:
		return
	# En pågående tween dödas: annars skriver två tweens på samma egenskap och sista ordet blir
	# slumpens (mätt i demoläget: kameran sackade en ruta efter spelaren när stegen gick fortare än
	# 0,10 s, och striden började med fienden 2,3 m bort i stället för 1,15).
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	# Steg eller sväng? Kameran vet det själv: flyttar målet sig är det ett STEG (då får farten en
	# vidvinkel-puff, "nästan en zoom-effekt"), annars är det en SVÄNG (då kränger den till i sidled).
	var mål := _cam_pos()
	var steg := mål.distance_to(cam.position) > 0.05
	var tid := STEG_TID if steg else SVÄNG_TID
	_cam_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(cam, "position", mål, tid)
	# Vinkeln läggs som NÄRMASTE varv, annars snurrar svängen 270 grader fel väg över 180-gränsen
	# (se Explore.närmaste_vinkel). Mätt i körning: från väster till norr gick kameran +4,71 i
	# stället för -1,57.
	_cam_tween.parallel().tween_property(cam, "rotation:y",
		Explore.närmaste_vinkel(cam.rotation.y, Explore.yaw_for(run.explore.facing)), tid)
	if steg:
		# Puffen ligger i SAMMA tween (en egen tween hade slagits med den här om kameran): vidvinkeln
		# öppnar sig under första 40 % av steget och stänger sig under resten.
		_cam_tween.parallel().tween_property(cam, "fov", FOV + PUFF, tid * 0.4)
		_cam_tween.tween_property(cam, "fov", FOV, tid * 0.6)
	else:
		# Svängen: rullningen går ut åt sidan och tillbaka. Den är det som gör att svängen känns
		# gjord av en kropp och inte av ett kamerastativ.
		_cam_tween.parallel().tween_property(cam, "rotation:z", KRÄNG, tid * 0.5)
		_cam_tween.tween_property(cam, "rotation:z", 0.0, tid * 0.5)

## Kameran SNÄPPER till rutan och riktningen direkt, utan glid. Striden börjar här: fienden ska stå i
## bild i samma bildruta som slaget börjar, inte en halv sekund senare när en tween hunnit fram.
func _snap_cam() -> void:
	if cam == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	cam.position = _cam_pos()
	cam.rotation.y = Explore.yaw_for(run.explore.facing)
	# Vidvinkeln och rullningen nollas också: dödas en puff mitt i steget står kameran kvar med
	# öppen vidvinkel eller en sned horisont, och striden börjar i en bild som ser fel ut.
	cam.fov = FOV
	cam.rotation.z = 0.0

# --- ljud -------------------------------------------------------------------
func _load_sfx() -> void:
	for name in SFX_NAMES:
		var path := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			sfx[name] = load(path)
	for i in 6:                                    # liten pool: ljud får överlappa
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

func _sfx(name: String) -> void:
	if not sfx.has(name) or sfx_players.is_empty():
		return
	var p := sfx_players[sfx_next % sfx_players.size()]
	sfx_next += 1
	p.stream = sfx[name]
	p.play()

func _card_icon(id: String) -> Texture2D:
	var path := "res://assets/cards/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null

# --- HUD --------------------------------------------------------------------
## Spelvyn i en egen ruta (480x270) och HUD:en runt omkring i fönstret.
##
## MÄTT: förut ritades HELA fönstret i 480x270 och skalades upp 2x, HUD-texten inräknad. En 9 px
## font blev 18 px stora fyrkanter. Alex: "HUD-texten ritas inne i den lilla vyn och är grötig".
## Nu är 3D:n kvar i sin egen upplösning (pixlarna ska synas) och HUD:en runt omkring ritas i
## fönstrets upplösning (1280x720), där bokstäverna är riktiga bokstäver.
func _bygg_vy() -> void:
	_vy = SubViewport.new()
	_vy.size = VY
	_vy.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# PEKAREN MÅSTE IN I VYN. Paneler som ligger inne i spelvyn (kortvalet, albumet, slagpanelen) är
	# barn till `hud`, och `hud` är ett barn till den här vyn — med `gui_disable_input = true` nådde
	# ingen mushändelse dem alls: Alex: "det går inte att välja ett kort där, det går inte att klicka
	# på dem". Tangenterna gick fria hela tiden (de kommer via `_unhandled_input`), så felet syntes
	# bara för den som klickade. Mätt i `-- kortvalsprov`: pekarens fråga "vilken kontroll ligger
	# under mig" svarade "inget" för alla fyra korten, och ett klick lämnade valet orört.
	_vy.gui_disable_input = false
	# Egen 3D-värld: annars delar vyn värld med huvudvyn, och då sätter WorldEnvironment (dimman,
	# glöden, tonemappningen) bakgrundsfärg på HELA fönstret i stället för bara i spelvyn.
	_vy.own_world_3d = true
	# Allt som hör till SPELVYN läggs in här: världen, ljuset, kameralagret, minikartan, panelerna
	# och korten i den gamla storleken. De räknar därför mot 480x270 precis som förut.
	hud = CanvasLayer.new()
	_vy.add_child(hud)
	_vy_korg = SubViewportContainer.new()
	# Vyn måste vara korgen:s BARN: det är barnet korgen letar upp och ritar. Låg vyn vid sidan om
	# ritade korgen ingenting alls (mätt: hela fönstret blev projektets rensfärg, grå 0,30).
	_vy_korg.add_child(_vy)
	# stretch AV: korgen får inte tvinga vyn till fönstrets storlek (då ritas 3D:n i 1280x720 och
	# pixelkonsten är borta). Vyn behåller sina 480x270 och korgen skalas i stället, med NEAREST —
	# annars smetas pixlarna ut till en grå röra i stället för att bli hårda fyrkanter.
	_vy_korg.stretch = false
	_vy_korg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Korgen måste TA emot pekaren, annars skickas inget vidare in i vyn (IGNORE = "delta inte i
	# mushändelser alls"). Rutorna som ska klickas i marginalerna ligger i `_runt` ovanpå och tar sina
	# egna klick först, så vyn behöver inte släppa igenom något.
	_vy_korg.mouse_filter = Control.MOUSE_FILTER_STOP
	# Klicket i spelvyn: spaden (M44). Kopplat på korgen i stället för _unhandled_input, för korgen
	# STOPPAR musen (annars hade panelerna i vyn fått klicken i stället).
	_vy_korg.gui_input.connect(_vy_klick)
	# I ett eget lager, inte direkt under scenens rot: en Control som hänger under en Node3D ritas
	# inte (den har ingen canvas) — mätt: hela spelvyn blev en tom bakgrundsfärg.
	_vy_lager = CanvasLayer.new()
	_vy_lager.layer = 0
	_vy_lager.add_child(_vy_korg)
	add_child(_vy_lager)
	_placera_vy()
	get_viewport().size_changed.connect(_placera_vy)
	_runt = CanvasLayer.new()
	_runt.layer = 1
	add_child(_runt)

## Heltalsskalad och centrerad. Skalan räknas om varje gång fönstret ändras, så en annan
## fönsterstorlek ger fortfarande hårda pixlar i stället för en halvskalad bild.
func _placera_vy() -> void:
	var f := Vector2(get_viewport().get_visible_rect().size)
	var skala := maxf(1.0, floorf(minf(f.x / float(VY.x), f.y / float(VY.y))))
	# Storleken sätts för hand: med stretch av (annars tvingas vyn till fönstrets mått och
	# pixelkonsten försvinner) behåller korgen annars sin standardstorlek 0x0 och ritar ingenting.
	_vy_korg.size = Vector2(VY)
	_vy_korg.scale = Vector2(skala, skala)
	_vy_korg.position = ((f - Vector2(VY) * skala) / 2.0).floor()
	# Ramen i marginalen (M36) behöver vyns ruta: den ritar fyra band runtom och ingenting innanför.
	if hud_ram != null:
		hud_ram.sätt_vy(Rect2(_vy_korg.position, Vector2(VY) * skala), int(skala))
	# HÖGARNA FÖRST (M51): kärlen och korträknaren mäts mot högens överkant, och mättes de innan högen
	# fanns på plats blev siffran satt efter en gammal ruta (mätt: kärlet hamnade över slänghögen).
	_placera_högarna(f, Rect2(_vy_korg.position, Vector2(VY) * skala), int(skala))
	_placera_gui(f)
	_placera_karta(f, skala)

## Kärlen (M36) i marginalens nedre hörn: hälsan till vänster, manan till höger och rustningen i
## vänsterkolumnen ovanför hälsan. Hörnen är fria — korten ligger i mitten (mätt: x 405..870 vid
## 1280x720, alltså långt ifrån marginalen) — och storleken följer fönstrets heltalsskala som ramen.
## Lägger HUD:ens tre rutor (M40). Alla tre ligger i MARGINALEN — statusblocket i den övre (fönstrets
## yta ovanför spelvyn, 90 px vid 1280x720), loggen och fienderutan i den nedre. Ingen av dem rör
## spelvyn, och det mäts i tests/test_gui.gd.
##
## Korträknaren flyttar till mitten under handen: den stod i vänstra hörnet, där loggen nu ligger, och
## den hör ihop med handen som står i mitten.
func _placera_gui(f: Vector2) -> void:
	if hud_status != null:
		hud_status.position = Vector2(8.0, 6.0)
	if hud_logg != null:
		hud_logg.position = Vector2(8.0, roundf(f.y - HudLogg.HÖJD - 6.0))
	if top_label != null:
		# Saldot (M61) står i den övre marginalens VÄNSTERKANT — samma yta som statusblocket i en
		# körning, men de syns aldrig samtidigt: statusblocket hör till körningen och saldot till
		# skalet (se `_refresh_shell`).
		top_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		top_label.size = Vector2(520.0, 23.0)
		top_label.position = Vector2(8.0, 6.0)
	if hint_label != null:
		# Tipsraden ligger i den ÖVRE marginalens högerkant, vänster om minikartan. Den sattes förut med
		# `position` på ett HÖGERANKARE, och då räknas positionen från förälderns vänsterkant: raden
		# hamnade 166 px utanför vänsterkanten — högerkanten såg tom ut och raden skymdes av
		# statusblocket (mätt i guiprovet, inte gissat).
		var skala: float = maxf(1.0, _vy_korg.scale.x)
		var kartkant := f.x - (MapView.MAP_SIZE.x * skala + MARGINAL + 8.0)
		hint_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint_label.size = Vector2(560.0, 23.0)
		hint_label.position = Vector2(kartkant - 560.0, RAD_2_Y)
	if orb_hp != null:
		var skala := maxi(1, int(round(_vy_korg.scale.x)))
		var kolumn := _vy_korg.position.x / 2.0      # mitten av vänsterkolumnen
		var fri_topp := _vy_korg.position.y
		var fri_botten := f.y - 6.0 - float(HudLogg.HÖJD)
		# HÖGARNA ÄGER SIN ÖVERKANT. Förut stod `h.position.y > fri_topp` i villkoret: en hög vars
		# överkant låg OVANFÖR den fria ytan hoppades då över, och ingenting hindrade kärlet från att
		# hamna över korten (Alex: *"Den använda korthögen ligger över mana"*). Klämmen gäller alltid.
		for h in [hog_drag, hog_använd]:
			if h != null and h.visible:
				fri_botten = minf(fri_botten, h.position.y - 8.0)
		var rust_h := HudBar.HÖJD
		# PARET (M75): hälsan och manan SIDA VID SIDA med samma radie, rustningen som en rad under.
		# Radien räknas ur BÅDE kolumnens bredd och det fria utrymmets höjd. Förut var HP-kärlet
		# alltid i full storlek (R_STOR) medan bara manan krymptes — räckte inte utrymmet sköt HP-kärlet
		# över korthögen, och i ett fönster där högen är stor försvann manan bakom den.
		var luft := 6.0
		var fri_h := fri_botten - fri_topp
		# Radien räknas med GOLV ur BÅDA mätten: avrundade man uppåt blev paret några px bredare än
		# kolumnen (mätt: hp-kärlet 3 px utanför vänsterkanten i 1896x1030) eller högre än utrymmet.
		var r_bredd := int(floor((kolumn - luft * 0.5) / (2.0 * float(skala)))) - HudOrb.KANT
		var r_höjd := int(floor((fri_h - luft - rust_h) * 0.5 / float(skala))) - HudOrb.KANT
		var par_r := clampi(mini(r_bredd, r_höjd), 6, R_STOR)
		var par_halv := float((par_r + HudOrb.KANT) * skala)
		var klump := par_halv * 2.0 + luft + rust_h
		var topp := fri_topp + maxf(0.0, (fri_h - klump) * 0.5)
		var par_mitt := topp + par_halv
		# PARET KLÄMS IN I FÖNSTRET. Är marginalen smalare än två kärl (mätt: 32 px i 1024x768) kan
		# paret inte centreras utan att hamna utanför vänsterkanten — då flyttas det i stället inåt så
		# att siffrorna i båda kärlen syns. Paret är 4*par_halv + luft brett, alltså ligger dess vänstra
		# kant på `kolumn - 2*par_halv - luft/2` när det står mitt i kolumnen.
		var par_vänster := maxf(0.0, kolumn - par_halv * 2.0 - luft * 0.5)
		orb_hp.ställ_in(par_r, Palett.c(11), Palett.c(2), skala)
		orb_mana.ställ_in(par_r, Palett.c(25), Palett.c(2), skala)
		orb_hp.placera_vid(Vector2(par_vänster + par_halv, par_mitt))
		orb_mana.placera_vid(Vector2(par_vänster + par_halv * 3.0 + luft, par_mitt))
		var stapel := maxf(60.0, 2.0 * par_halv + luft)
		rust_bar.ställ_in(Tr.t("ui.hud.bar.rust", "RUST"), Palett.c(22), Palett.c(2), Palett.c(25), stapel)
		rust_bar.position = Vector2(maxf(0.0, roundf(kolumn - (stapel + HudBar.RUBRIK_BREDD) * 0.5)),
			roundf(par_mitt + par_halv + luft))
	if kort_label != null:
		# Korträknaren står ÖVER HÖGEN TILL HÖGER (Alex: *"hur många kort man har (det borde ligga över
		# högen till höger, så man ser det hela tiden)"*). Förut låg den i botten mitt på, i en mörk ton
		# ingen såg. Rutan mäts med NEGATIVA offsets från bottenankaret: `position` räknas från
		# förälderns övre vänstra hörn även med ett bottenankare (se den gamla mätningen i M36).
		var tak := f.y - 60.0
		var vänster := f.x * 0.5 - 45.0
		var bredd := 90.0
		if hog_drag != null and hog_drag.kort.x > 0.0:
			bredd = maxf(90.0, hog_drag.kort.x)
			vänster = hog_drag.position.x
			tak = hog_drag.position.y - 26.0
		kort_label.offset_left = vänster
		kort_label.offset_right = vänster + bredd
		kort_label.offset_bottom = tak + 24.0 - f.y
		kort_label.offset_top = tak - f.y
		kort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## Rutorna syns när spelet visas: i tomvyn (skalet bakom en körning) finns ingen status att visa.
func _visa_gui(syns: bool) -> void:
	for n in [hud_status, hud_logg, orb_hp, orb_mana, rust_bar]:
		if n != null:
			n.visible = syns
	# Mana och rustning hör till striden: `_hud_sätt` trimmar dem efter läget, men kärlen får inte synas
	# en bildruta utanför en strid medan den väntar på sin tur.
	if orb_mana != null and active_combat == null:
		orb_mana.visible = false
		rust_bar.visible = false

## Korthögarna (M34, punkt 8) i sidokolumnerna: leken till höger och de använda till vänster, båda i
## kortets egen storlek och med underkanten mot kärlen. Se `_hög_geometri` för räkningen.
func _placera_högarna(_f: Vector2, _vy: Rect2, _skala: int) -> void:
	if hog_drag == null:
		return
	_visa_högarna(active_combat != null and not active_combat.over())

## Högens geometri: kortets mått, hur brett stapeln får sprida, och var högen står.
##
## Kortet har SAMMA storlek som handens kort (Alex: *"staplarna med kort måste bli lika stora som
## korten är i spelet"*), och högen växer BORT från spelvyn — inåt hade korten hamnat över korridoren.
## Underkanten läggs mot kärlen och överkanten mot det som redan äger kolumnen (minikartans ordrad
## till höger, statusraden till vänster), och de läses ur nodernas EGNA rutor: räknades de om här
## kunde de glida isär med kärlen.
func _hög_geometri(antal: int = 1) -> Dictionary:
	var skala := maxf(1.0, roundf(_vy_korg.scale.x))
	var vy := Rect2(_vy_korg.position, Vector2(VY) * skala)
	var air := 6.0 * skala
	# Kortet i högen har handens storlek när kolumnen rymmer den — men marginalen är 160 px och ett
	# kort i handen är 182, så ett fullstort kort hamnade utanför skärmkanten (mätt på skärmbild: högen
	# klipptes av mot ramen). Högens kort krymps därför till kolumnens bredd, aldrig under halva
	# handkortet — poängen med högen är att korten ska ses, inte att de ska vara små rektanglar.
	# Kortets bredd måste lämna plats åt KANTERNA: arton kort i en 160 px-kolumn gav 136 px kort plus
	# 1,5 px kant per kort = 152 px, alltså utanför skärmkanten, och högens ram klipptes av (mätt på
	# skärmbild: den vita ramen försvann i CRT-kanten). Kortet krymps därför så att korten OCH kanterna
	# ryms — och KortHogs eget prov mäter fortfarande att varje kort får en egen kant.
	var kanter := KortHog.STEG_MIN * float(maxi(0, antal - 1))
	var kortskala := clampf(minf(HAND_SKALA,
			(vy.position.x - 2.0 * air - kanter) / CardView.HAND_SIZE.x), 0.4, HAND_SKALA)
	var kort: Vector2 = CardView.HAND_SIZE * kortskala
	# Kolumnens bredd minus kortet och luften i båda kanter: samma räkning för båda högarna.
	var sprid: float = maxf(8.0 * skala, vy.position.x - kort.x - 2.0 * air)
	# Underkanten mot BOTTENBANDET (loggen och fienderutan, M40): högarna står i SIDOKOLUMNERNA och
	# rutorna i bottenbandet, så de möts i hörnen — och där får korten inte hamna. Före M40 var det
	# kärlen som satte gränsen; nu är gränsen den ruta som ligger längst ned i kolumnen.
	var bottenband := HudLogg.HÖJD + 3.0 * air
	var drag_botten := vy.end.y + air - bottenband
	var anv_botten := drag_botten
	return {"kort": kort, "sprid": sprid, "air": air, "vy": vy,
		"drag_botten": drag_botten, "anv_botten": anv_botten}


## Ritar högarna: antalet i leken och bland de använda, och FLYTTEN när leken tar slut: blir draghögen
## fler samtidigt som de använda blir NOLL är det omshufflingen, och då samlas de använda ihop och
## läggs tillbaka till höger — Alex: *"Korten skall sedan samlas ihop och läggas i högen prydligt igen
## på höger sida."* Villkoret läses ur siffrorna i stället för ur en händelse: samma väg som allt
## annat i HUD:en, och inget kan glida isär.
func _refresh_högarna(i_strid: bool) -> void:
	if hog_drag == null:
		return
	if not i_strid:
		_hög_förra_drag = 0
		_hög_förra_använd = 0
	_visa_högarna(i_strid)
	if not i_strid:
		return
	var drag := active_combat.draw_pile.size()
	var använd := active_combat.discard_pile.size()
	if drag > _hög_förra_drag and använd == 0 and _hög_förra_använd > 0:
		_samla_högarna()
	_hög_förra_drag = drag
	_hög_förra_använd = använd


## Högens kort och placering ur antalet: en väg in, delad av stridsbytet och fönsterbytet.
func _visa_högarna(i_strid: bool) -> void:
	hog_drag.visible = i_strid
	hog_använd.visible = i_strid
	if not i_strid:
		return
	var drag: int = active_combat.draw_pile.size()
	var använd: int = active_combat.discard_pile.size()
	# Geometrin får det STÖRSTA antalet: kortet måste vara litet nog att både korten och kanterna i
	# den fulla högen ryms i kolumnen (se _hög_geometri).
	var g := _hög_geometri(maxi(drag, använd))
	# Högerhögen växer åt höger (leken, blå) och vänsterhögen åt vänster (de använda, röd). Färgen är
	# bara fallskärmen om baksidan saknas — annars ritas korten med sin egen baksida.
	hog_drag.ställ_in(drag, g["kort"], g["sprid"], g["drag_botten"], 1, Palett.c(25), Palett.c(2))
	hog_drag.placera_vid(g["vy"].end.x + g["air"])
	hog_använd.ställ_in(använd, g["kort"], g["sprid"], g["anv_botten"], -1, Palett.c(11), Palett.c(2))
	hog_använd.placera_vid(g["vy"].position.x - g["air"])


## Antalet i leken och bland de använda, och FLYTTEN när leken tar slut: blir draghögen fler
## Omshufflingen: den tomma ramen till vänster far över till leken till höger och tillbaka. Korten
## är redan i leken (det är därför siffran steg), så det är högens egen gest — den visar VART de tog
## vägen, och det är hela poängen med de två högarna.
func _samla_högarna() -> void:
	if hog_använd == null or hog_drag == null:
		return
	var från := hog_använd.position
	var t := create_tween()
	t.tween_property(hog_använd, "position", hog_drag.position, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(hog_använd, "position", från, 0.25).set_trans(Tween.TRANS_SINE)
	print("[kortbord] leken tog slut: de använda samlades ihop och lades tillbaka (%.0f px)" % från.distance_to(hog_drag.position))


## Minikartan i MARGINALEN: fönstrets övre högra hörn (M32). HUD:en ligger i `_runt` och ritas i
## fönstrets upplösning, så kartan får sin plats i fönsterpx — och sin storlek ur korgen:s heltal,
## alltså samma pixelkonst som förut (kartan låg förr INUTI vyn, med orden som en remsa tvärs över
## den). Se `MapView` för mätningen.
func _placera_karta(f: Vector2, skala: float) -> void:
	if map_view == null:
		return
	map_view.size = MapView.MAP_SIZE
	map_view.scale = Vector2(skala, skala)
	map_view.position = Vector2(f.x - MapView.MAP_SIZE.x * skala - MARGINAL, MARGINAL)
	# Tangenttipsen: i marginalen till VÄNSTER om kartan och en rad ned — tipsen låg förr högst upp
	# till höger, där kartan nu står (mätt: de krockade, se test_minikarta.gd).
	# Tipsraden flyttade till `_placera_gui` (M40): den låg här och sattes EFTER `_placera_gui`, med
	# `position` på ett högerankare — alltså räknad från förälderns vänsterkant, 166 px utanför
	# skärmen. Allt som hör till marginalen sätts nu på ett ställe.

## HUD:en i ytan runtom spelvyn, i fönstrets upplösning.
##
## Korten i en RAD (inte en solfjäder) längst ner, antalet kort till vänster om dem, och högst upp
## hälsa, mana, rustning och de gamla tangenttipsen. Ingenting av det här skalas upp: texten ritas
## i den storlek den visas.
func _bygg_runt() -> void:
	# Ramen läggs in FÖRST: den är bakgrunden i marginalen, och allt annat i HUD:en — panelerna,
	# minikartan, korten — ritas ovanpå den (barn ritas i ordning).
	hud_ram = HudRam.new()
	hud_ram.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_ram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runt.add_child(hud_ram)

	# De tre rutorna (M40). De ligger i MARGINALEN: statusblocket i den övre (90 px vid 1280x720),
	# loggen och fienderutan i den nedre, alltså aldrig över spelvyn.
	hud_status = HudStatus.bygg()
	_runt.add_child(hud_status)
	# Kärlen skapas före placeringen (se _placera_gui): färgerna är spelets egna — blodet (c11) för
	# hälsan, vattnet (c25) för manan och benet (c22) för rustningen.
	orb_hp = HudOrb.new()
	orb_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runt.add_child(orb_hp)
	orb_mana = HudOrb.new()
	orb_mana.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runt.add_child(orb_mana)
	rust_bar = HudBar.new()
	rust_bar.name = "rust_bar"
	rust_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runt.add_child(rust_bar)
	hud_logg = HudLogg.bygg()
	_runt.add_child(hud_logg)

	# Korthögarna (M34): leken till höger i vattenfärgen (samma som manan — det är samma sak), de
	# använda till vänster i blodfärgen. Baksidorna är ritade, inte kortkonst: högen är en stapel,
	# inte ett kort man ska kunna läsa.
	hog_drag = KortHog.new()
	hog_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runt.add_child(hog_drag)
	hog_använd = KortHog.new()
	hog_använd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runt.add_child(hog_använd)

	# STATUSRADEN OCH Sifferpanelen är BORTA (M40): statusblocket uppe till vänster visar samma saker
	# som staplar och siffror på dem. Kvar finns två OSYNLIGA etiketter — de ritar ingenting, men
	# `-- shot`s lägesutskrift och proven läser HUD:ens tillstånd som text ur dem, och en skärmbild
	# visar bara att något SAKNAS medan siffrorna visar varför (samma skäl som när de byggdes).
	top_label = Label.new()
	top_label.name = "lage_top"
	top_label.visible = false
	_runt.add_child(top_label)
	stats_panel = PanelContainer.new()
	stats_panel.name = "lage_stats"
	stats_panel.visible = false
	stats_label = Label.new()
	stats_panel.add_child(stats_label)
	_runt.add_child(stats_panel)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Rad 2 i marginalen, högerställd mot kartans vänsterkant (positionen sätts av `_placera_karta`:
	# den beror på fönstret). Tipsen låg förr på rad 1, där kartan nu står.
	hint_label.position = Vector2(-6, RAD_2_Y)
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	_runt.add_child(hint_label)

	# Antalet kort: står vid kanten av den svarta ytan under vyn, där handen ligger.
	kort_label = Label.new()
	kort_label.add_theme_font_size_override("font_size", 18)
	kort_label.add_theme_color_override("font_color", Color(0.80, 0.84, 0.92))
	kort_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	kort_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Texten ställs mot rutans underkant: rutan är högre än en rad (den ärvdes från kärlens marginal),
	# och med
	# standardjusteringen (topp) hade siffran flutit ovanför handen.
	kort_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	kort_label.position = Vector2(8, -8)
	_runt.add_child(kort_label)

	# Handen hålls framför spelaren, och ligger därför i HUD-lagret (fönstret) och kan skjuta in en
	# bit över vyns nederkant — precis som en hand med kort gör.
	hand_zone = Control.new()
	hand_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE   # bara korten själva tar emot pekaren
	_runt.add_child(hand_zone)
	get_viewport().size_changed.connect(_rada_hand.bind(true))

	# STARTMENYN (M39). Den ligger i FÖNSTRET och läggs in efter allt annat: den ska täcka vyn, HUD:en
	# och korten när den är framme (barn ritas i ordning), men bara då.
	meny = Huvudmeny.bygg()
	meny.visible = false
	meny.valt.connect(_meny_val)
	_runt.add_child(meny)

	# ALTERNATIV: en liten panel över menyn. Tangentbord OCH klick, som menyraderna.
	alt_panel = PanelContainer.new()
	alt_panel.name = "alternativ"
	# Egen stil, inte `_panel_style()`: den är halvgenomskinlig (0,93), och över splashbilden lyste
	# facklor och sten igenom texten ("panelens bakgrund är inte helt ogenomskinlig", granskningen).
	var alt_stil := _panel_style()
	alt_stil.bg_color = Color(0.04, 0.04, 0.06, 0.98)
	alt_stil.set_border_width_all(2)
	alt_panel.add_theme_stylebox_override("panel", alt_stil)
	alt_panel.visible = false
	var abox := VBoxContainer.new()
	alt_panel.add_child(abox)
	alt_label = Label.new()
	alt_label.add_theme_font_size_override("font_size", 18)
	abox.add_child(alt_label)
	# Antalet rader står i EN konstant: raderna byggs här och fylls i _rita_alternativ, och två
	# magiska treor gled isär så fort en rad lades till (fjärde raden ritades men fanns inte).
	for i in ALT_RADER:
		var rad := Label.new()
		rad.name = "alt_%d" % i
		rad.add_theme_font_size_override("font_size", 17)
		rad.mouse_filter = Control.MOUSE_FILTER_STOP
		rad.mouse_entered.connect(_alt_peka.bind(i))
		rad.gui_input.connect(_alt_klick.bind(i))
		abox.add_child(rad)
		alt_rader.append(rad)
	_runt.add_child(alt_panel)

	# MUSIKEN (M54). En spellista, inte ett stycke: jukeboxen läser assets/music och spelar låtarna i
	# tur och ordning. Menyns gamla stycke är ett spår bland de andra och spelas först, så menyn låter
	# som förut. Musiken fortsätter in i byn och banorna — förut tystnade den när körningen började.
	musik = Jukebox.new()
	add_child(musik)
	var antal_spar := musik.ladda()
	print("jukebox: %d spår: %s" % [antal_spar, ", ".join(musik.spar)])
	musik.spela_efter_namn("Dungeon Arpeggios")

	# CRT-LAGRET (M39) läggs in SIST: det läser skärmen bakom sig och ska därför ha med både spelet,
	# HUD:en och menyn i sin bild.
	crt = Crt.bygg()
	crt.sätt_på((meta.crt_på if meta != null else true) and not _crt_av)
	crt.sätt_styrka(_crt_styrka)
	_runt.add_child(crt)
	get_viewport().size_changed.connect(_placera_meny)

func _build_hud() -> void:
	_bygg_vy()

	# Byn och världskartan läggs in FÖRST: de är hela bakgrunden i sina lägen, och allt annat i HUD:en
	# (panelerna, minikartan, korten) ska ritas ovanpå dem.
	# Måttet är VYN (480x270), inte fönstret: de ritar inne i spelvyn.
	by_view = VillageView.new()
	by_view.size = Vector2(VY)
	by_view.position = Vector2.ZERO
	by_view.vald.connect(_på_plats)
	by_view.visible = false
	hud.add_child(by_view)
	karta_view = WorldMapView.new()
	karta_view.karta = karta
	karta_view.size = Vector2(VY)
	karta_view.position = Vector2.ZERO
	karta_view.vald.connect(_på_bana)
	karta_view.visible = false
	hud.add_child(karta_view)

	# Statusraden, tangenttipsen, antalet kort och handen ligger i HUD-lagret RUNT vyn (se
	# _bygg_runt): de ritas i fönstrets upplösning. Här inne i vyn ritas bara det som hör till
	# själva bilden — blinket, svepet, belöningen och minikartan.
	#
	# Röd blink när man SJÄLV tar stryk. Ligger direkt efter toppraden, alltså UNDER panelerna och
	# korten: en blink över korten hade skymt det man ska läsa.
	hit_flash = ColorRect.new()
	hit_flash.color = Color(0.75, 0.10, 0.10, 0.0)
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hit_flash)
	# Grävslöjan (M44): bilden mörknar medan kameran sjunker genom golvet. Den ligger i HUD-lagret
	# ÖVER spelvyn (annars vore mörkret bara ett mörker i vyn) och fångar inga klick.
	gräv_slöja = ColorRect.new()
	gräv_slöja.color = Color(0, 0, 0, 0)
	gräv_slöja.set_anchors_preset(Control.PRESET_FULL_RECT)
	gräv_slöja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gräv_slöja.visible = false
	hud.add_child(gräv_slöja)

	# Angreppet: ett eget lager över 3D-vyn men UNDER kartan, panelerna och korten — svepet ska
	# skymma korridoren en blinkning, inte det man läser.
	attack_fx = AttackFx.new()
	hud.add_child(attack_fx)

	# Belöningen: kistan och facklan får sin stund. Lagret ligger över angreppet men under panelerna —
	# kortet vänds in i mitten av vyn, och det som står i paneler och kort ska fortfarande gå att läsa.
	reward_fx = RewardFx.new()
	hud.add_child(reward_fx)

	# Minikartan ligger i MARGINALEN (M32): fönstrets övre högra hörn, utanför spelvyn. Den läggs i
	# HUD-lagret `_runt` — som statusraden och tipsen — och positionen sätts av `_placera_karta`
	# (samma heltalsskala som korgen), inte mot VYNS mått.
	map_view = MapView.new()
	# Kartan läggs i `_runt` och ska ritas ÖVER ramen och CRT-lagret — annars ligger marginalens
	# metall ovanpå den (mätt: kartan ritades 76x60 @ 1122,6 men syntes inte alls i bilden).
	map_view.z_index = 2
	_runt.add_child(map_view)

	# Mana, kedja och rustning står i HUD-lagret runt vyn (se _bygg_runt): siffrorna man läser medan
	# man väljer kort ska ritas i fönstrets upplösning, och de står bara på ETT ställe.

	battle_panel = PanelContainer.new()
	battle_panel.set_anchors_preset(Control.PRESET_CENTER)
	battle_panel.add_theme_stylebox_override("panel", _panel_style())
	battle_panel.visible = false
	var box := VBoxContainer.new()
	battle_panel.add_child(box)
	battle_label = Label.new()
	battle_label.add_theme_font_size_override("font_size", 7)
	battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(battle_label)
	var buttons := HBoxContainer.new()
	_play_all_btn = Button.new()
	_play_all_btn.text = Tr.t("ui.battle.play_all", "Spela allt (P)")
	_play_all_btn.add_theme_font_size_override("font_size", 7)
	_play_all_btn.pressed.connect(_on_play_all)
	buttons.add_child(_play_all_btn)
	_end_turn_btn = Button.new()
	_end_turn_btn.text = Tr.t("ui.battle.end_turn", "Avsluta turen (E)")
	_end_turn_btn.add_theme_font_size_override("font_size", 7)
	_end_turn_btn.pressed.connect(_on_end_turn)
	buttons.add_child(_end_turn_btn)
	box.add_child(buttons)
	hud.add_child(battle_panel)

	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", _panel_style())
	end_panel.visible = false
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 10)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(end_label)
	hud.add_child(end_panel)

	# Skalets paneler: butiken, värdshuset och smeden. Samma bygge som slutskärmen — en panel och en
	# etikett — så de ärver typsnitt, kant och placering utan en rad egen stil. Byn och kartan står
	# inte här: de ritas (VillageView/WorldMapView), och en panel bakom en ritad scen hade bara varit
	# en ruta över bilden.
	#
	# Listan bär bara ID:N. Rubrikerna stod här förut (`Tr.t("ui.inn.title", "VÄRDSHUSET")`) och var
	# DÖD KOD: etiketten får sin text när skärmen öppnas (`_inn_text()` m.fl., rad ~1307), och de
	# anropen utelämnade dessutom `%d`/`%s` som nycklarna kräver — hade de någonsin ritats hade de
	# skrivit ut "guld i banken: %d" ordagrant. Nycklarna lever i sina riktiga anrop (rad ~1176/1216).
	var skal := ["butik", "smed"]
	for par in skal:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _panel_style())
		p.visible = false
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		hud.add_child(p)
		match str(par):
			"butik":
				butik_panel = p
				butik_label = l
			"vardshus":
				inn_panel = p
				inn_label = l
			_:
				smed_panel = p
				smed_label = l

	draft_panel = PanelContainer.new()
	draft_panel.set_anchors_preset(Control.PRESET_CENTER)
	draft_panel.add_theme_stylebox_override("panel", _bench_style())
	draft_panel.visible = false
	var dbox := VBoxContainer.new()
	# Innehållet centreras lodrätt: panelen är HELA vyn (se _show_draft), och rubrik + kort ska stå i
	# mitten av den, inte klistrade mot överkanten.
	dbox.alignment = BoxContainer.ALIGNMENT_CENTER
	draft_panel.add_child(dbox)
	draft_label = Label.new()
	draft_label.add_theme_font_size_override("font_size", 9)
	dbox.add_child(draft_label)
	draft_box = HFlowContainer.new()
	# HFlow radbryter, och dess MINSTA bredd är det bredaste barnet — utan en undre gräns blir
	# panelen en enda kolumn och de tre korten staplas lodrätt utanför skärmen (sett på bild).
	# Fyra platser räcker: kortvalet ger 3 val, 4 med Luck.
	draft_box.custom_minimum_size = Vector2(CardView.BIG_SIZE.x * 4.0 + 18.0, 0)
	draft_box.alignment = FlowContainer.ALIGNMENT_CENTER
	dbox.add_child(draft_box)
	# KORTVALET LIGGER I FÖNSTRETS YTA (`_runt`, som handens kort och menyn) — inte i 480x270-vyn.
	# Vyn skalas upp med ett heltal till fönstret, så det som ritades inne i vyn förstorades efteråt:
	# kortens text (5-7 px) blev grötig och konstens pixlar olika breda. Se `_show_draft`.
	_runt.add_child(draft_panel)

	# ALBUMET (M34, punkt 9). Alex: *"Man måste kunna öppna som en index över alla kort man äger och
	# se vad de gör om man klickar/trycker på ett kort, och allt detta som om man öppnar ett album."*
	# Bygget är kortvalets — panel, etikett, en rad kort — men med en STOR visning också: i valet
	# väljer man, i albumet läser man.
	album_panel = PanelContainer.new()
	album_panel.set_anchors_preset(Control.PRESET_CENTER)
	album_panel.add_theme_stylebox_override("panel", _panel_style())
	album_panel.visible = false
	var abox := VBoxContainer.new()
	album_panel.add_child(abox)
	album_label = Label.new()
	album_label.add_theme_font_size_override("font_size", 9)
	album_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abox.add_child(album_label)
	album_stor = CenterContainer.new()
	album_stor.custom_minimum_size = Vector2(CardView.BIG_SIZE.x + 8.0, CardView.BIG_SIZE.y + 4.0)
	abox.add_child(album_stor)
	album_box = HBoxContainer.new()
	# Raden är SÅ MÅNGA kort bred, med det valda i mitten: en rad som växer med samlingen blir
	# bredare än skärmen vid 41 kort, och då syns varken första eller sista kortet.
	album_box.custom_minimum_size = Vector2(CardView.HAND_SIZE.x * 0.62 * 7.0 + 6.0 * 4.0, 0)
	album_box.alignment = BoxContainer.ALIGNMENT_CENTER
	abox.add_child(album_box)
	hud.add_child(album_panel)

	# VÄRDSHUSET (M56). Alex: "Där skall korten på alla hjältar radas upp, så man kan välja dem, läsa
	# om dem innan man köper dem, och sedan läggs de till i ens kortlek." Samma bygge som albumet —
	# en stor visning och en rad tumnaglar — så hjälte­korten är SAMMA kort som i leken, ritade av
	# samma CardView. Det som inte står på kortet (hans passiva verkan och priset) står i etiketten.
	inn_panel = PanelContainer.new()
	inn_panel.set_anchors_preset(Control.PRESET_CENTER)
	inn_panel.add_theme_stylebox_override("panel", _bench_style())
	inn_panel.visible = false
	var ibox := VBoxContainer.new()
	inn_panel.add_child(ibox)
	inn_label = Label.new()
	inn_label.add_theme_font_size_override("font_size", 8)
	inn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ibox.add_child(inn_label)
	inn_stor = CenterContainer.new()
	# Mätt mot spelvyn (480x270): etiketten är tre rader (~36 px), så kortet och raden får 228 px
	# tillsammans. Med full BIG_SIZE (212) plus en rad i 0.62 (89) blev panelen 337 px och radens
	# nederkant skars av — sett på bild. Skalorna nedan ger 152 + 72 + 36 = 260 px.
	inn_stor.custom_minimum_size = Vector2(CardView.BIG_SIZE.x * INN_SKALA + 8.0,
		CardView.BIG_SIZE.y * INN_SKALA + 4.0)
	ibox.add_child(inn_stor)
	inn_box = HBoxContainer.new()
	inn_box.custom_minimum_size = Vector2(CardView.HAND_SIZE.x * INN_RAD * 6.0 + 5.0 * 4.0, 0)
	inn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ibox.add_child(inn_box)
	hud.add_child(inn_panel)

	# JUVELERAREN (M58). Två stationer i samma vy, som Alex beskrev dem: en för att göra PLATS i
	# korten (upp till fyra fack, mot guld) och en för att välja en sten ur det kistorna gett och
	# sätta den i ett valfritt kort. Korten är lekens egna, så det man sätter stenen i är det kort
	# man spelar.
	jewel_panel = PanelContainer.new()
	jewel_panel.set_anchors_preset(Control.PRESET_CENTER)
	jewel_panel.add_theme_stylebox_override("panel", _panel_style())
	# Panelen håller sig inom vyns bredd (480): bredden sätts HÄR, inte på etiketten, för det är
	# panelen som bestämmer hur mycket plats VBoxen får — och först då bryter etiketten sina rader.
	jewel_panel.custom_minimum_size = Vector2(456.0, 0.0)
	jewel_panel.visible = false
	var jbox := VBoxContainer.new()
	jewel_panel.add_child(jbox)
	jewel_label = Label.new()
	jewel_label.add_theme_font_size_override("font_size", 8)
	jewel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# BRYTS ÖVER FLERA RADER (M93): tipsraden ("← → kort · 1-4 fack · W/S sten · Enter = öppna/sätt/
	# plocka ur · Esc = tillbaka") är 1236 px lång på en rad. Panelen centreras i den 480 px breda vyn,
	# så hela vänsterkanten av varje rad hamnade utanför skärmen — rubriken med guldet först av allt.
	# Med en bredd och automatisk radbrytning ryms texten i vyn, och det gäller alla 13 språk utan att
	# en enda översättning behöver röras.
	jewel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jewel_label.custom_minimum_size = Vector2(440.0, 0.0)
	jbox.add_child(jewel_label)
	# DEN STORA FÖRHANDSVISNINGEN ÄR BORTTAGEN (M93). Den kostade ~90 px höjd, och panelen behövde
	# dem: texten växte från sex rader till nio när facken och fickan byggdes ut, och med den kvar
	# blev panelen 352 px i en 270 px hög vy — rubriken (guld, fack) klipptes i överkant och kortraden
	# i underkant. Kortet som visas stort ligger redan i raden under, och det VALDA kortet är det som
	# lyfts fram där, så ingen information försvann med förhandsvisningen.
	jewel_box = HBoxContainer.new()
	jewel_box.custom_minimum_size = Vector2(CardView.HAND_SIZE.x * JEWEL_RAD * 8.0 + 7.0 * 4.0, 0)
	jewel_box.alignment = BoxContainer.ALIGNMENT_CENTER
	jbox.add_child(jewel_box)
	hud.add_child(jewel_panel)

	# BANVERKSTADEN (M60): en panel och en etikett, som smeden och butiken — den visar en bana i
	# taget och fem fält man rattar med + och −. Gränserna kommer ur `Stages.FÄLT`, så verkstaden och
	# filen kan inte vara oense om vad som är tillåtet.
	verk_panel = PanelContainer.new()
	verk_panel.add_theme_stylebox_override("panel", _panel_style())
	verk_panel.visible = false
	verk_label = Label.new()
	verk_label.add_theme_font_size_override("font_size", 9)
	verk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verk_panel.add_child(verk_label)
	hud.add_child(verk_panel)

	# Sist: HUD:en i ytan RUNT vyn — status, tips, antal kort och handen, allt i fönstrets
	# upplösning. Den ligger i ett eget lager ovanpå spelvyn.
	_bygg_runt()
	# Och så platsen EN gång till: `_placera_vy` kördes i `_bygg_vy` innan minikartan och tipsen
	# fanns, och den hakar bara på fönstrets storleksbyte — ett fönster som startar i sin rätta
	# storlek (1280x720) ändrar sig aldrig, så kartan blev stående i (0,0) över statusraden tills
	# någon råkade dra i fönsterkanten. MÄTT i en skärmbild på 1280x720: orden låg på x 14..37,
	# y 66..123 i stället för i marginalen till höger.
	_placera_vy()

func _refresh() -> void:
	if run == null:
		_refresh_shell()      # skalet har ingen körning att visa: byn/kartan ritar sig själva
		return
	# Sparfilen hålls i takt med körningen (M39): LADDA SPEL i menyn ska kunna fortsätta där spelaren
	# var. Anropet är billigt — det skriver bara när våning, hp, xp eller leken ändrats.
	_spara_körning()
	var hint := Tr.t("ui.hud.hint", "WASD gå · 1-9 kort · P spela allt · E tur · S sortera (%s) · R om") % _sort_name()
	if _draft_pending():
		hint = Tr.t("ui.draft.prompt", "VÄLJ KORT: 1-%d (eller klicka)") % run.pending_draft().size()
	elif _spade_redo():
		# Spaden är den enda saken som klickas, och den ligger på bossens ruta: utan en rad som säger
		# det ser våningen ut som en återvändsgränd (Alex: "spaden måste klickas på").
		# Står spelaren PÅ spaden ligger den under fötterna och syns inte i kameran (mätt) — ledtråden
		# ska säga vad som gäller då, inte peka på något som inte syns.
		hint = (Tr.t("ui.hud.hint.grav_pa", "DU STÅR PÅ SPADEN — klicka för att gräva ned")
			if run.explore.pos == _spade_nod.pos
			else Tr.t("ui.hud.hint.grav", "KLICKA PÅ SPADEN för att gräva ned till nästa våning"))
	# Under en strid är det stridens HP som gäller — annars visar toppen ett gammalt värde medan
	# panelen visar det levande.
	var i_strid: bool = active_combat != null and not active_combat.over()
	var hp_nu: float = active_combat.hp if i_strid else run.hp
	# Alex: *"I strid skall ens totala, och det man dragit in på den omgången visas."* Två tal, för de
	# betyder olika saker: guldet i körningen försvinner när körningen tar slut och går då in i banken
	# (se _banked nedan). Utan banken ser spelaren bara vad han bär, och undrar varför butikens priser
	# inte går ihop med siffran i toppen.
	top_label.text = Tr.t("ui.hud.status", "%s %d/%d · nivå %d · HP %.0f/%.0f · bank %d · omgången %d · %d xp") % [
		Tr.name_of("stage", run.stage.id, run.stage.name), run.floor_index + 1, run.stage.floors,
		run.level, hp_nu, run.max_hp, meta.gold, run.gold, run.xp]
	_hud_sätt(hp_nu, i_strid)
	# Jukeboxen (M54): spåret som spelar står i tipsraden. Tangenten N byter, och utan namnet här
	# vore bytet tyst — en spellista man inte ser är en spellista man inte styr.
	if musik != null and musik.antal() > 0:
		hint += " · N ♪ %s" % musik.nuvarande()
	hint_label.text = hint
	_refresh_stats()
	_refresh_hand()          # räknar om handen OCH korträknaren: de hör ihop
	map_view.run = run

## HUD:ens tillstånd som en Dictionary (M40). Nycklarna står här och på ETT ställe, så en ny siffra i
## HUD:en inte behöver läggas till i varje anrop — och provet kan läsa samma ord som rutan ritar.
##
## Manans tak är en KALIBRERING, inte en spelregel: manan växer under striden och har inget tak i
## motorn, så stapeln skalas mot en normal stridsnivå (grundmanan plus en hands manakort). Rustningen
## har ett riktigt tak — stridens startvärde — så där är nivån hur mycket som är KVAR.
func _status_data(hp: float, i_strid: bool) -> Dictionary:
	var d := {
		"i_strid": i_strid,
		"hp": hp,
		"max_hp": run.max_hp,
		"bana": Tr.t("ui.hud.bana", "%s %d/%d") % [
			Tr.name_of("stage", run.stage.id, run.stage.name), run.floor_index + 1, run.stage.floors],
		"niva": Tr.t("ui.hud.niva", "NIVÅ %d") % run.level,
		"guld": Tr.t("ui.hud.guld", "%d guld · %d/%d xp") % [run.gold, run.xp,
			Progress.xp_total(run.level + 1)],
	}
	# MANAPOOLEN (M80). Här stod `run.base_mana + 4` på båda raderna — ett HÅRDKODAT +4 som bara råkade
	# stämma för en spelare med exakt +4 i startmana (Alex: *"Där det står 3/7, vad är det?"*). Poolen
	# är stridens eget tal, samma summa som `Combat.start_turn` fyller: grundmanan plus startmanan ur
	# metan. Nämnaren är alltså samma tal som räknaren fylls till, för varje spelare.
	var mana_pool := run.base_mana + (int(run.meta.stat("start_mana")) if run.meta != null else 0)
	if i_strid:
		d["mana"] = active_combat.mana
		mana_pool = active_combat.base_mana + active_combat.mana_bonus
	else:
		# UTANFÖR STRID står manan full: den fylls vid varje turs början, alltså är det talet det
		# spelaren möter när striden startar — och paret (hälsa, mana) står symmetriskt i stället för
		# att ena kärlet försvinner.
		d["mana"] = mana_pool
	d["mana_max"] = mana_pool
	# RUSTNINGEN (M75) kommer ur KÖRNINGEN, inte ur striden: poolen följer med mellan striderna, och
	# taket är det högsta den nått (en stapel som alltid står full säger ingenting om värdet).
	d["rust"] = active_combat.armor if i_strid else run.armor
	d["rust_max"] = run.armor_tak
	return d

## Fyller statusblocket och fienderutan. Kallas från `_refresh`, alltså samma väg som allt annat i
## HUD:en — inget kan visa ett värde som spelet inte har.
func _hud_sätt(hp: float, i_strid: bool) -> void:
	if hud_logg != null:
		hud_logg.sätt_rubrik(Tr.t("ui.hud.logg", "LOGG"))
	if hud_status != null:
		var gammal := hud_status.visible
		hud_status.visible = gammal and run != null
		var s := _status_data(hp, i_strid)
		hud_status.sätt(s)
		# Kärlen följer SAMMA siffror som texten: nivån räknas ur värdet och taket, och mana/rustning
		# visas bara i strid (samma regel som textraden).
		if orb_hp != null:
			orb_hp.visible = hud_status.visible
			orb_hp.sätt_nivå(float(s.get("hp", 0.0)) / maxf(1.0, float(s.get("max_hp", 1.0))))
			orb_hp.sätt_text("%d/%d" % [int(s.get("hp", 0.0)), int(s.get("max_hp", 1.0))])
			# MANAN OCH RUSTNINGEN SYNS HELA KÖRNINGEN (M75), inte bara i strid: paret står sida vid
			# sida (att gömma ena kärlet gjorde paret osymmetriskt), och rustningen är en pool man
			# samlar — den ska gå att se även mellan striderna.
			orb_mana.visible = hud_status.visible
			orb_mana.sätt_nivå(float(s.get("mana", 0.0)) / maxf(1.0, float(s.get("mana_max", 1.0))))
			orb_mana.sätt_text("%d/%d" % [int(s.get("mana", 0.0)), int(s.get("mana_max", 1.0))])
			rust_bar.visible = hud_status.visible
			rust_bar.sätt(float(s.get("rust", 0.0)), float(s.get("rust_max", 1.0)))

## Fiendernas namn som en rad, för loggen. En strid med tre fiender ska inte skriva tre rader när ett
## enda anfall faller — namnen räknas upp i en rad.
func _fiende_namn() -> String:
	if active_combat == null:
		return ""
	var namn := []
	for e in active_combat.enemies:
		if e.hp > 0.0:
			namn.append(Tr.name_of("enemy", e.id, e.name))
	if namn.is_empty():
		return Tr.t("ui.hud.logg.ingen", "ingen")
	return ", ".join(namn) if namn.size() <= 2 else "%s +%d" % [namn[0], namn.size() - 1]

## Målet: den FÖRSTA levande fienden, med sin egen bild (samma fil som 3D-vyn ritar) och sin livsmätare.
## En ruta per fiende blir en tabell; det som behövs mitt i en strid är motståndarens liv.
func _fiende_data(i_strid: bool) -> Dictionary:
	if not i_strid or active_combat == null:
		return {}
	for e in active_combat.enemies:
		if e.hp > 0.0:
			# Filen är gemener (assets/enemies/candlewisp.png) medan id:t i striden är versaliserat för
			# visning — provet fällde den på "assets/enemies/Candlewisp.png" och visade därmed VILKET
			# namn som inte hittades, i stället för att bara säga att bilden saknades.
			var path := "res://assets/enemies/%s.png" % e.id
			if not ResourceLoader.exists(path):
				path = "res://assets/enemies/%s.png" % e.id.to_lower()
			return {"rubrik": Tr.t("ui.hud.fiende", "FIENDE"),
				"id": e.id, "namn": Tr.name_of("enemy", e.id, e.name),
				"hp": e.hp, "max_hp": e.max_hp,
				"textur": load(path) if ResourceLoader.exists(path) else null}
	return {}

## Loggen: en rad per händelse, färgad efter sort. Färgen är inte dekoration — i en stridslogg hittar
## man skadan på färgen utan att läsa varje ord. Blod för skada, guld för erfarenhet och byte, ben för
## händelser (våning, kista, dryck).
func _logga(text: String, färg: Color) -> void:
	if hud_logg != null:
		hud_logg.logga(text, färg)


## Mana, kedja och rustning: siffrorna som avgör vilket kort man kan spela härnäst. Panelen hämtas
## ur _bygg_runt (fönstrets upplösning) och sitter ankrad, så den behöver ingen egen position —
## förut räknades den fram varje gång, mot vyns mått.
func _refresh_stats() -> void:
	var i_strid: bool = active_combat != null and not active_combat.over()
	# Panelen RITAS INTE (M40): mana och rustning står i statusblocket som staplar. Texten sätts kvar —
	# `-- shot` och proven läser HUD:ens tillstånd ur den, och en mätning ska inte kosta en ritad ruta.
	stats_panel.visible = false
	_refresh_högarna(i_strid)
	if not i_strid:
		return
	stats_label.text = "%s · %s" % [
		Tr.t("ui.stats.mana", "mana %d · ×%d") % [active_combat.mana,
			Rules.damage_multiplier(active_combat.combo)],
		Tr.t("ui.hud.rust", "rust %.0f") % active_combat.armor]

## Panelerna placeras mot SIN EGEN storlek. Ett rent center-ankare sätter panelens övre vänstra
## hörn i skärmens mitt, så panelen hamnar snett nedåt höger (sett på bild). Stridspanelen
## läggs högt: mitt i bilden skymde den fienden man slåss mot.
##
## Storleken cachas per panel. `get_combined_minimum_size()` mäter om hela UI-trädet, och den
## kördes vid VARJE hover över ett kort — det var den största delen av hackigheten i handen.
func _place_panel(panel: Control, at_top: bool) -> void:
	# Ankaret måste vara övre vänstra hörnet: med ett center-ankare räknas position FRÅN mitten,
	# så en centrering hamnar dubbelt så långt åt höger (sett på bild).
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var s := panel.get_combined_minimum_size()
	var nyckel := panel.get_instance_id()
	if _panel_last_size.get(nyckel) == s:
		return
	_panel_last_size[nyckel] = s
	panel.size = s
	# Panelerna ritar INNE i spelvyn (480x270): måttet är vyns, inte fönstrets.
	# Stridspanelen låg förut ovanför minikartans ORDRAD (där orden gick tvärs över vyns övre halva).
	# I M32 flyttade kartan OCH orden ut i marginalen — det finns ingen rad kvar i vyn att hålla sig
	# ovanför, så 40,0 är tillbaka: samma läge som före raden. Krocken mot kartan mäts i stället där
	# den kan uppstå (litet fönster, där marginalen är noll): tests/test_minikarta.gd jämför panelens
	# ruta i fönstret mot kartans.
	panel.position = Vector2((VY.x - s.x) / 2.0, 40.0 if at_top else (VY.y - s.y) / 2.0)

## Panelernas bakgrund: standardpanelen i Godot smälter in i den mörka 3D-vyn (sett på bild:
## texten såg ut att flyta fritt). En egen stil med kant ger texten ett fäste.
func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.93)
	sb.border_color = Color(0.45, 0.48, 0.60)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	return sb


## The cards lie on a BENCH. Alex generated a plank surface (images/desk2.jpeg, top-down, seamless)
## and said the shop should lay its cards on it rather than on a flat black panel. A StyleBoxTexture
## is the panel drawing the wood itself: no extra node to keep in sync with the panel size, and it
## scales with the panel. Tinted well below the raw plank, because a bright wood surface behind pale
## card text costs contrast — the rest of the game is read against near-black.
##
## The texture is assets/ui/bench.png, NOT the raw sheet: game/images/ is gitignored (Alex's
## generated sheets), so a fresh clone would have no bench and the panel would go black without a
## word. The crop is cut by hand from the clean middle of the plank and scaled to 512x288, which is
## the view's own 480x270 with a margin — one source pixel per drawn pixel, no resampling in game.
const BENCH_TEXTURE := "res://assets/ui/bench.png"


func _bench_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(BENCH_TEXTURE)
	sb.modulate_color = Color(0.32, 0.27, 0.23, 0.96)
	sb.set_content_margin_all(4)
	return sb

func _refresh_hand() -> void:
	var in_battle: bool = active_combat != null and not active_combat.over()
	for child in hand_zone.get_children():
		child.queue_free()
	hand_views.clear()
	_forward_index = -1          # handen är ny: ingen förhandsvisning hör till den gamla
	_hand_order.clear()
	# Antalet kort uppdateras HÄR, där handen faktiskt byggs: lästes siffran ur en annan väg stod
	# den kvar på 5 när ett kort spelats (mätt: handen hade 4 kort, räknaren sa 5).
	kort_label.text = ""
	if in_battle:
		kort_label.text = Tr.t("ui.hud.kort", "%d kort") % active_combat.hand.size()
	if not in_battle:
		return
	for i in active_combat.hand.size():
		_hand_order.append(i)                     # 0 = dragen ordning
	if _sort_mode == 1:
		_hand_order = HandView.order(active_combat.hand, "cost_asc")
	elif _sort_mode == 2:
		_hand_order = HandView.order(active_combat.hand, "role")
	# Kortets storlek: 1,6x den gamla, men krymper om handen är så stor att raden inte ryms i
	# fönstret. Bredden är det som tar slut först — höjden har hela den svarta ytan under vyn.
	var skala := HAND_SKALA
	var n := float(_hand_order.size())
	if n > 0.0:
		var f := get_viewport().get_visible_rect().size
		# Bredden som behövs är solfjäderns, inte radens: omlottet sparar plats, så en stor hand
		# behåller större kort än den gjorde i raden.
		skala = minf(skala, (f.x - 40.0) / (1.0 + (n - 1.0) * FAN_OMLOTT) / CardView.HAND_SIZE.x)
	# HELA SKALAN (M78): samma fel som i kortvalet — 1,75 ger konstpixlar som är 1 och 2 px breda om
	# varandra. Handens kort står i FÖNSTERPIXLAR (ingen k), så heltalet är skärmens: 2 i stället för
	# 1,75 (en tiondel större kort, samma storlek på varje konstpixel), och en stor hand som måste
	# krympa får 1 — aldrig ett bråk.
	skala = maxf(1.0, floorf(skala))
	for d in _hand_order.size():
		var c: Cards.Card = active_combat.hand[_hand_order[d]]
		# Riktiga kort i handen: kostnad, typ, namn och konst. Effekten träder fram när kortet
		# lyfts, och hela texten finns i verktygstipset. Indexet är VISAT index — spelaren trycker
		# på det han ser, och _hand_index översätter till handens riktiga plats.
		var v := CardView.make(c, d, _card_icon(c.id), false, skala)
		v.picked.connect(_on_card)
		v.forward_changed.connect(_on_card_forward)
		hand_views.append(v)
		hand_zone.add_child(v)
	# NYA KORT KOMMER FRÅN HÖGEN MED BAKSIDAN UPP (M34): korten som inte låg i handen förra gången
	# börjar vid draghögen, glider in på sin plats och VÄNDS — de delas inte ut som de andra.
	# Jämförelsen är på id, så ett kort som legat kvar i handen inte dras och vänds på nytt.
	# Detekteringen sker FÖRE `_rada_hand`: det är där utdelningen (dela_in) bestäms, och ett kort som
	# kommer från högen ska inte delas — det ska dras.
	var nya: Array = []
	if hog_drag != null and active_combat != null:
		for d in _hand_order.size():
			if not _förra_hand.has(active_combat.hand[_hand_order[d]].id):
				nya.append(d)
	for d in nya:
		hand_views[d].face_down = true
	_rada_hand(true)         # ny hand: korten ligger där de hör hemma direkt, utan att glida in
	for d in nya:
		var v: CardView = hand_views[d]
		v.position = hog_drag.mitt() - v.home_size * 0.5
		v.modulate.a = 0.0
		v.glide_to(v.home_pos, v.home_rot, float(d) * CardView.DELA_STEG)
		# Vändningen sker EFTER vägen in: kortet lägger sig på sin plats, och vänder sig där. Att
		# vända mitt i glidningen gav en vinglig rörelse (kortet är smalt som mest just när det rör sig).
		v.vänd_upp(0.16 + float(d) * CardView.DELA_STEG)
		var t := create_tween()
		t.tween_property(v, "modulate:a", 1.0, 0.14)
	_förra_hand.clear()
	for c in active_combat.hand:
		_förra_hand.append(c.id)

## Sortera handen: dragen -> kostnad -> roll. EN väg in, delad av tangenten och demoläget.
func _cycle_sort() -> void:
	_sort_mode = (_sort_mode + 1) % 3
	_refresh_hand()
	_refresh_battle()

## Visat kort-index -> handens index. Sorteras handen om får korten nya platser i vyn, och utan
## den här översättningen spelar siffran ett annat kort än det man ser.
func _hand_index(visat: int) -> int:
	if visat >= 0 and visat < _hand_order.size():
		return _hand_order[visat]
	return visat

## Sorteringslägen i tur och ordning. Kostnad stigande är spelets egen kedjeordning: korten
## spelas i stigande mana, så visad i den ordningen ligger nästa kort i kedjan först.
func _sort_name() -> String:
	var nycklar := ["ui.hud.sort.drawn", "ui.hud.sort.cost", "ui.hud.sort.role"]
	var svenska := ["dragen", "kostnad", "roll"]
	return Tr.t(nycklar[_sort_mode], svenska[_sort_mode])

## Handen ligger som en SOLFJÄDER längst ner i den svarta ytan under spelvyn (M34): en båge med
## omlott och korten vridna utåt från mitten. Alex: *"korten ligger ännu på rad, ... behöver vara mer
## som att man håller korten i en solfjäderform som i Referensspelet"*.
##
## Det VALDA kortet reser sig över de andra med ljus kant och rätar upp sig (CardView.set_forward) —
## det är valmarkeringen, och namnet läser man där: i solfjädern skymmer omlottet grannarnas namn med
## flit (35 px av 93 mätt), precis som en hand man håller i.
##
## OBS: korten positionssätts för hand — de får inte ligga i en container, den skriver över både
## position och storlek.
##
## `genast` = en NY hand: korten DELAS UT (ett i taget, med efterföljd). Annars glider de, för då
## är det ett kort som träder fram och de andra som viker undan.
func _rada_hand(genast: bool = false) -> void:
	var n := hand_views.size()
	if n == 0:
		return
	var f := get_viewport().get_visible_rect().size
	# SOLFJÄDER (M34). Alex: "korten ligger ännu på rad" — och en rad är en hylla, inte en hand.
	# Korten läggs på en båge: mittenkortet högst och rakt, ytterkorten längre ned och vridna utåt,
	# och med omlott. Raden dömdes tidigare bort för att omlottet gömde grannens namn (elva pixlar
	# mättes); i en solfjäder är det meningen — namnet läses på det framträdda kortet, och tipset
	# bär hela texten. Underkanten ligger kvar i fönstrets nederkant: korten skjuter in en bit över
	# vyns nederkant, precis som en hand med kort.
	var h: Vector2 = hand_views[0].home_size
	# STEGET i sidled: så stort att grannen syns, men aldrig större än att raden ryms i fönstret. Med
	# få kort läggs de nästan kant vid kant — fem kort visar hela kortet, namn och allt, i stället för
	# den halva som ett fast omlott gav. Först när handen är stor tas omlottet i, och 0,50 är golvet:
	# tunnare än så försvinner korten bakom varandra.
	var steg := clampf((f.x - 40.0 - h.x) / maxf(1.0, n - 1.0), h.x * FAN_OMLOTT, h.x)
	var mitten := (n - 1) / 2.0
	var x0 := (f.x - (steg * (n - 1) + h.x)) / 2.0
	# MITTKORTET ankrar: dess underkant ligger 6 px in i fönstrets nederkant, precis där raden låg.
	# Ytterkorten hänger lägre (bågen) och skärs av skärmkanten — en hand som hålls lågt ska skäras
	# av kanten, inte flyta mitt i bilden.
	var y0 := f.y - h.y - 6.0
	var grann: float = h.y * GRANN_SVIKT if _forward_index >= 0 else 0.0
	for i in n:
		var v: CardView = hand_views[i]
		# t = avståndet från mittenkortet i kort: negativt till vänster, positivt till höger.
		var t := float(i) - mitten
		var rot := t * FAN_STEG
		var pos := Vector2(x0 + i * steg, y0 + absf(t) * h.y * FAN_SJUNK)
		if genast:
			v.home_pos = pos
			v.home_rot = rot
			if not v.forward and not v.face_down:
				# Ett kort i taget: utdelningens efterföljd. Kort som kommer från HÖGEN hoppas över —
				# de dras och vänds i stället (se _refresh_hand).
				v.dela_in(i * CardView.DELA_STEG)
		elif not v.forward:
			# Grannarna följer efter det framträdda kortet: ju längre bort i bågen, desto senare.
			# Utan fördröjningen flyttar hela handen sig som en skiva — det var "hackigt".
			var steg_t: int = absi(i - _forward_index) if _forward_index >= 0 else 0
			v.glide_to(pos, rot, steg_t * CardView.EFTERFÖLJD)

## Stridspanelen är där fienderna SYNS, så riktmarkeringen hör hemma här: raden för varje fiende
## kortet skulle träffa märks och får sin skada. Siffran kommer från Combat.preview(), som räknar
## med samma regler som spelet — provet "visad skada = utfall" håller dem i synk.
##
## Kort text med flit. Panelen bar förut en rubrik, en rad per fiende med hp/max OCH en rad för
## spelarens hp — samma siffror som toppraden och healthbaren — och lästes som en vägg av text
## (Alex: "Rutan med text är överväldigande"). Kvar: vem som träffas och för hur mycket.
func _refresh_battle() -> void:
	if active_combat == null:
		return
	var vant := {}
	var p := {}
	if _forward_index >= 0:
		p = active_combat.preview(_hand_index(_forward_index))
		if p.get("ok", false):
			for h in p["hits"]:
				vant[h.enemy] = float(h.damage)
	var rader := []
	for e in active_combat.alive_enemies():
		var namn := Tr.name_of("enemy", e.id, e.name)
		if vant.has(e):
			rader.append(Tr.t("ui.battle.enemy_row", "▶ %s   −%.0f") % [namn, vant[e]])
		else:
			rader.append("   %s" % namn)
	if p.get("ok", false):
		var kort: Cards.Card = active_combat.hand[_hand_index(_forward_index)]
		if p["hits"].is_empty():
			# Kort utan skada (mana, rustning, drag): visa vad det GÖR i stället för "0 skada".
			rader.append("%s: %s" % [kort.title(), kort.describe()])
		else:
			rader.append("%s: %.0f · %s" % [kort.title(), p["damage"], "×%d" % p["multiplier"]])
	elif p.get("reason", "") == "for_lite_mana":
		rader.append(Tr.t("ui.battle.no_mana", "för lite mana"))
	# Två fiender med samma namn gav två IDENTISKA rader, och panelen blev dubbelt så hög som sitt
	# innehåll (Alex: "rutan där det står Candlewisp är på tok för stor, den behöver halveras").
	# Lika rader slås ihop till en rad med antal; olika skada står kvar som egna rader.
	var hopslagna := []
	for r in rader:
		if not hopslagna.is_empty() and hopslagna[-1][0] == r:
			hopslagna[-1][1] += 1
		else:
			hopslagna.append([r, 1])
	var slutrader := []
	for h in hopslagna:
		slutrader.append(h[0] if h[1] == 1 else "%s  ×%d" % [h[0], h[1]])
	battle_label.text = "\n".join(slutrader)
	_refresh_enemy_bars()     # samma sanning i världen som i panelen: striden äger båda
	# Stridspanelen läggs i vyns UNDERKANT (M40): referensen håller hela spelvyn fri och lägger
	# informationen i marginalerna, och panelen låg förr mitt i siktfältet och skymde korridoren och
	# fienderna (granskningen: "rutan med Candlewisp ligger mitt i siktfältet").
	# Stridspanelen flyttar UT ur spelvyn (M40). Referensen håller hela spelvyn fri och lägger allt i
	# marginalerna; panelen låg först mitt i siktfältet (skymde korridoren) och sedan i vyns underkant,
	# där korten klippte av knapparna (granskningen: "Spela allt/Avsluta turen kapas av korten").
	# Nu ligger den i den ÖVRE marginalen, till höger om statusblocket och vänster om tangenttipset.
	_place_panel(battle_panel, true)
	# Positionen är i VYN:s koordinater (panelen är barn till vyn): fönstrets yta fås som
	# vy.position + vy_koord * skala, så -42 i vyn blir 6 px från fönstrets överkant. Panelen läggs
	# till vänster om tangenttipset, som äger den övre marginalens högra halva.
	# Panelen läggs i VYN:s övre vänstra HÖRN: vyn klipper sina barn, så en panel utanför vyn ritas
	# inte alls (mätt: 0 px inritade i fönstret), och i mitten skymde den korridoren och fienderna.
	battle_panel.position = Vector2(4.0, 4.0)
	_refresh_stats()          # mana/kedja ändras varje spelat kort: håll siffrorna vid handen färska

## Ställ upp striden FRAMFÖR spelaren. Figuren står på sin ruta i våningen, och när man går in i
## striden står man PÅ den rutan — kameran hamnade inuti figuren och man såg inte alls det man slog
## mot (Alex: "om man går in i dem för att strida, de försvinner ur bild"). Nu flyttas de till en
## linje framför blicken: två i främre ledet, resten bakom, som en stridslinje.
func _stage_fight(node: Dungeon.FloorNode) -> void:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var fram: Vector2i = dirs[run.explore.facing % 4]
	var sido := Vector2i(-fram.y, fram.x)
	var bas := Vector2(run.explore.pos) + Vector2(0.5, 0.5)
	# Rummet kan vara en enda ruta: är rutan framför en vägg stannar ledet innanför spelarens ruta
	# i stället för att stå inne i en mur.
	var framme: bool = run.explore.floor_ref.is_floor_at(run.explore.pos + fram)
	var i := 0
	for e in _enemies:
		if e.get("nod") != node.pos:
			continue
		var spr: Sprite3D = e["spr"]
		if not is_instance_valid(spr):
			continue
		# I KOLONN, INTE PÅ LED (M66). Alex: *"spökena står på sidan när man möter dem, även andra
		# fiender — har det att göra med hur trångt det är i gången?"* Ja: ledet lade två figurer sida
		# vid sida med 0,85 m mellanrum, och i en 1 m-gång står de då tryckta mot varsin vägg, i
		# ögonvrån. Nu står de MITT FÖR spelaren, den ena bakom den andra: den främsta på 1,15 m och
		# varje följande 0,6 m bakom. Sidledet är kvar som en aning (±0,06 m) så den bakre inte
		# försvinner helt bakom den främre.
		var sida := (float(i % 2) - 0.5) * 0.12
		var d := (1.15 + float(i) * 0.60) if framme else (0.75 + float(i) * 0.45)
		var p: Vector2 = bas + Vector2(fram) * d + Vector2(sido) * sida
		spr.position.x = p.x
		spr.position.z = p.y
		_place_bar(e)
		i += 1

## Healthbarens plats räknas ur figurens position. Egen funktion för att uppställningen flyttar
## figurerna EFTER att staplarna byggts — utan det stod staplarna kvar där fienden stod först.
func _place_bar(e: Dictionary) -> void:
	var spr: Sprite3D = e.get("spr")
	var ben: Sprite3D = e.get("bar")
	var fyllnad: Sprite3D = e.get("fyllnad")
	if not is_instance_valid(spr) or not is_instance_valid(ben) or not is_instance_valid(fyllnad):
		return
	var topp := spr.position.y + 17.0 * spr.pixel_size + 0.02
	var vänster := spr.position.x - BAR_W / 2.0
	ben.position = Vector3(vänster, topp, spr.position.z)
	fyllnad.position = Vector3(vänster + BAR_W * 0.06, topp + BAR_H * 0.2, spr.position.z)
	e["y"] = spr.position.y

## Slagets kvitto. Utan det ser ett spelat kort likadant ut som ett ospelat: baren krymper, men
## inget HÄNDER (Alex: "det gäller att få till så det är en visuell bekräftelse att man attackerar
## med"). Tre saker på samma gång, för de svarar på olika frågor: SIFFRAN säger hur mycket, BLINKET
## säger att det tog, och KNUFFEN säger var.
func _slag_kvitto(spr: Sprite3D, skada: float, mult: int) -> void:
	if skada <= 0.0 or not is_instance_valid(spr):
		return
	var lbl := Label3D.new()
	lbl.text = "−%.0f" % skada
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.0032
	lbl.font_size = 52 if mult < 3 else 68
	# Kontur: siffran hamnar ofta mot ett ljust golv. 6 px, inte 12 — vid 12 åt konturen upp
	# bokstäverna och siffran lästes som ett mörkrött streck (sett i genomgången).
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.04, 0.03, 0.03, 0.95)
	lbl.modulate = Color(0.98, 0.98, 0.94) if mult < 2 else \
		(Color(1.0, 0.78, 0.28) if mult < 3 else Color(1.0, 0.45, 0.25))
	# Siffran fästs i SKÄRMKOORDINATER, inte i världen. Världsoffset gav olika höjd beroende på hur
	# långt bort fienden stod — vid 1,15 m hamnade talet uppe i stridspanelen (mätt två gånger).
	# Här räknas önskad skärmpunkt om till en världspunkt på fiendens djup: 34 px över bröstet och
	# en bit åt sidan, lika läsbart på alla avstånd.
	var sida := 44.0 if randf() < 0.5 else -44.0
	var bröst := spr.global_position + Vector3(0.0, 0.1, 0.0)
	var djup := cam.global_position.distance_to(bröst)
	var vy := Vector2(VY)          # skärmkoordinaterna är VYNS: kameran ritar i 480x270
	var skärm := cam.unproject_position(bröst) + Vector2(sida, -30.0)
	# Talet hålls inom den LÄSBARA korridoren. Står fienden nära hamnade bröstet högt i bild och
	# siffran bakom stridspanelen (mätt): kläm in den under panelerna och över korten i stället för
	# att lita på att världspunkten råkade landa bra.
	skärm.x = clampf(skärm.x, 26.0, vy.x - 26.0)
	skärm.y = clampf(skärm.y, vy.y * 0.34, vy.y * 0.76)
	lbl.position = cam.project_position(skärm, djup) if not cam.is_position_behind(bröst) \
		else bröst + Vector3(sida * 0.01, 0.1, 0.0)
	world.add_child(lbl)
	var t := create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y + djup * 0.35, 0.75) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.18)
	t.chain().tween_callback(lbl.queue_free)
	# Blink och knuff. Knuffen går i Z, aldrig i Y: _process andas figuren i Y, och två tweens på
	# samma egenskap slåss om sista ordet.
	var bas := spr.position
	var b := create_tween().set_parallel(true)
	b.tween_property(spr, "modulate", Color(2.4, 2.4, 2.4), 0.04)
	b.tween_property(spr, "position:z", bas.z + 0.09, 0.06)
	b.chain().tween_property(spr, "modulate", Color.WHITE, 0.2)
	b.tween_property(spr, "position:z", bas.z, 0.18).set_trans(Tween.TRANS_BACK)

## Man ska se att man SJÄLV blev träffad: en röd blink över vyn. Siffran i toppraden räcker inte —
## den läser man efteråt.
func _blink_röd(skada: float) -> void:
	if hit_flash == null:
		return
	hit_flash.color = Color(0.75, 0.10, 0.10, clampf(skada / 40.0, 0.10, 0.42))
	create_tween().tween_property(hit_flash, "color:a", 0.0, 0.45)

## Ett kort träder fram eller undan: visa/dölj vad det skulle göra, och låt de andra vika undan.
func _on_card_forward(index: int, on: bool) -> void:
	var förra := _forward_index
	_forward_index = index if on else -1
	if (_forward_index >= 0) != (förra >= 0):
		_rada_hand()          # bara när ett kort BÖRJAR eller SLUTAR vara framträtt: annars 60 tweens/s
	_refresh_battle()

func _flush_events() -> void:
	while last_events < run.events.size():
		var e: Dictionary = run.events[last_events]
		last_events += 1
		print("event: %s" % str(e))
		match e.type:
			"combat_end":
				_sfx("coin" if e.won else "death")
				_logga(Tr.t("ui.hud.logg.vinst", "striden är vunnen") if e.won
					else Tr.t("ui.hud.logg.forlust", "striden är förlorad"),
					Palett.c(23) if e.won else Palett.c(10))
			"level_up":
				_sfx("level_up")
				_logga(Tr.t("ui.hud.logg.niva", "nivå %d — välj ett kort") % run.level, Palett.c(14))
			"card_picked":
				_sfx("pick")
				# Bossens byte är permanent (M45): skriv sparfilen direkt, så en krasch mitt i
				# körningen inte kostar kortet (samma väg som butikens köp tar).
				if bool(e.get("samling", false)):
					_logga(Tr.t("ui.hud.logg.samling", "%s sparades i samlingen")
						% Tr.name_of("card", str(e.card), str(e.card)), Palett.c(14))
					if not meta.save():
						push_warning("kunde inte spara: %s" % meta.last_error)
			"boss_reward":
				_sfx("level_up")
				_logga(Tr.t("ui.hud.logg.boss_byte", "bossen är besegrad — välj ett kort till samlingen"),
					Palett.c(14))
			"shovel":
				_sfx("descend")
				_logga(Tr.t("ui.hud.logg.vaning", "ned till våning %d") % (run.floor_index + 1),
					Palett.c(23))
			"chest":
				_sfx("coin")
				_visa_belöning(e)
				var rad := ""
				if str(e.get("vad", "")) == "sten":
					rad = Tr.t("ui.hud.logg.sten", "kista: %s") % meta.gem_name(
						str(e.get("fam", "")), int(e.get("grad", 0)))
				elif str(e.get("vad", "")) == "läkning":
					rad = Tr.t("ui.hud.logg.kista_lak", "kista: %d HP") % int(e.get("hp", 0))
				else:
					rad = Tr.t("ui.hud.logg.kista", "kista: %d guld") % int(e.get("gold", 0))
				var sp := int(e.get("shards", 0))
				if sp > 0:
					rad += " · " + Tr.t("ui.hud.logg.splitter", "%d splitter") % sp
				_logga(rad, Palett.c(14))
			"torch":
				_sfx("pick")
				_visa_belöning(e)
				_logga(Tr.t("ui.hud.logg.fackla", "fackla tänd"), Palett.c(13))
			_:
				pass


## Belöningen SYNS: kistan och facklan vänder in sitt kort med en glöd mitt i vyn.
## Händelsen kommer ur körningens eventström — samma källa som ljudet, så en ny belöning inte kan
## bli tyst, och raden i topplistan är inte längre det enda som skiljer "man fick något" från
## "ingenting hände". En händelse utan innehåll ger ingen stund (se `RewardFx.från_event`).
func _visa_belöning(e: Dictionary) -> void:
	if reward_fx == null or not is_instance_valid(reward_fx):
		return
	var r := RewardFx.från_event(e)
	if r.is_empty():
		return
	var färg: Color = r["färg"]
	reward_fx.visa(str(r["titel"]), str(r["text"]), str(r["ikon"]), färg)

# --- handling ----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	# MENYN OCH ALTERNATIVEN LIGGER ÖVERST (M39) och delar inte tangentbord med spelet bakom sig: är
	# någon av dem framme går tangenten dit och ingen annanstans.
	if alt_panel != null and alt_panel.visible:
		_alternativ_tangent(key)
		return
	if meny != null and meny.visible:
		_meny_tangent(key)
		return
	# Språkbytet gäller i alla lägen (utforskning, strid, kortval, byn) — en tangent, samma svar.
	if key == KEY_L:
		_cycle_language()
		return
	# Jukeboxen (M54) svarar före skalet: musiken hör inte till en skärm, och N ska byta låt både i
	# byn och i en bana. Piltangenter och Enter går till menyn och skalet som förut — N är ledig.
	if key == KEY_N and musik != null and musik.antal() > 0:
		musik.nästa()
		_refresh()
		return
	# Skalet först: en meny delar inte tangentbord med spelet bakom sig.
	if shell != "körning":
		_input_shell(key)
		return
	if key == KEY_ESCAPE:
		# ESC i en bana går hem till menyn — där finns Spara spel, alternativen och avsluta. Banan
		# står kvar bakom menyn (inget pausas), och ESC i menyn lämnar tillbaka hit.
		_visa_meny()
		return
	if run.finished:
		# Slutskärmen visar köpen, och T går tillbaka till byn: där ligger både butiken, kartan och
		# nästa bana. R = samma bana igen, för den som vill försöka om direkt.
		if key == KEY_R:
			_start_run(run.stage.id, randi())
		elif key == KEY_T:
			_show_home()
			return
		elif key >= KEY_1 and key <= KEY_9:
			_buy(key - KEY_0)
		_refresh()
		return
	if _draft_pending():
		if key >= KEY_1 and key <= KEY_9:
			_on_draft_pick(key - KEY_1)
		return
	if active_combat != null and not active_combat.over():
		if key >= KEY_1 and key <= KEY_9:
			var i := key - KEY_1
			# Visa vilket kort tangenten tar: samma lyft som muspekaren gör.
			if i < hand_views.size():
				hand_views[i].raise_for_a_moment()
			_on_card(i)
			return
		if key == KEY_P:
			_on_play_all()
			return
		if key == KEY_E:
			_on_end_turn()
			return
		if key == KEY_S:
			_cycle_sort()
			return
		return
	match key:
		KEY_W, KEY_UP:
			_step_forward()
		KEY_S, KEY_DOWN:
			# S betyder "sortera handen" INNE i en strid (grenen ovanför) och "gå baklänges" när man
			# går. Två lägen, samma tangent — de kan inte krocka, och båda står i kommandoraden.
			_step_backward()
		KEY_A, KEY_LEFT:
			run.explore.turn_left()
			_animate_cam()
		KEY_D, KEY_RIGHT:
			run.explore.turn_right()
			_animate_cam()
		KEY_F1:
			byggläge = not byggläge
			_bygg_säg("BYGGLÄGE %s — 1-6 placerar, X tar bort, G/V golv eller vägg, M material, N temats ruta, F2 sparar" % ["på" if byggläge else "av"])
		KEY_F2:
			if byggläge:
				_bygg_spara()
		KEY_X:
			if byggläge:
				_bygg_bort()
		KEY_G:
			if byggläge:
				_bygg_yta(true)
		KEY_V:
			if byggläge:
				_bygg_yta(false)
		KEY_M:
			if byggläge:
				_bygg_material_nästa()
		KEY_N:
			if byggläge:
				_bygg_material_tema()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			# I byggläget ställer 1-6 ut det man tittar på (samma ordning som MapIo.KINDS). Utanför
			# byggläget är 1-9 korten, och de grenarna ligger före den här.
			if byggläge:
				_bygg_plats(str(MapIo.KINDS[key - KEY_1]))
		KEY_R:
			_start_run(run.stage.id, randi())
		_:
			pass
	_refresh()

## Kortvalet vid level up ligger överst: inget annat svarar medan det väntar.
func _draft_pending() -> bool:
	return not run.pending_draft().is_empty()

## Byt språk. Bara filer med hela gränssnittet översatt får väljas (Tr.set_lang nekar annars), och
## valet sparas direkt: det ska gälla nästa gång utan att man sparar något särskilt. Texten sätts
## om på de widgets som sätter sin text en gång (knapparna) — resten ritas var bildruta.
func _cycle_language() -> void:
	var koder := Tr.codes()
	var här := koder.find(Tr.lang)
	for steg in range(1, koder.size() + 1):
		var k: String = koder[(här + steg) % koder.size()]
		if not Tr.is_complete(k):
			continue
		if not Tr.set_lang(k):
			continue
		meta.language = k
		if not meta.save():
			push_warning("kunde inte spara språkvalet: %s" % meta.last_error)
		print("språk: %s — %s, %.0f %% av texten översatt" % [
			k, Tr.name_of_code(k), Tr.coverage(k) * 100.0])
		if _play_all_btn != null:
			_play_all_btn.text = Tr.t("ui.battle.play_all", "Spela allt (P)")
		if _end_turn_btn != null:
			_end_turn_btn.text = Tr.t("ui.battle.end_turn", "Avsluta turen (E)")
		if run != null and run.finished:
			end_label.text = _end_text()
		_refresh()
		return

## SLUTSKÄRMEN ÄR EN SAMMANFATTNING (M48). Alex: *"Här skall man bara få information om hur många man
## dödat, hur mycket guld man fick in, och sen tillbaka till byn."* Butikslistan (åtta uppgraderingar
## med priser) stod här förut och gjorde skärmen till en butik man inte bett om — den hör till byn.
##
## LAYOUTEN (radbrytningarna och ordningen) står här i koden och inte i språkfilerna — annars får
## varje nytt språk chansen att glömma en rad, och Godot svarar "not all arguments converted" i en
## bildruta ingen tittar på. Tabellerna bär meningar.
func _end_text() -> String:
	var slut := "%s\n\n%s" % [run.outcome_text(),
		Tr.t("ui.end.summary", "%d fiender dödade · %d guld in") % [run.kills, run.gold]]
	# Splitter och ädelstenar hör till sammanfattningen: de hittades under körningen och är hela
	# poängen med att gå ner i kistorna. Stenarna listas med namn och grad.
	if run.shards > 0 or not run.stenar.is_empty():
		slut += "\n" + Tr.t("ui.end.splitter", "%d splitter") % run.shards
		for s in run.stenar:
			slut += "\n  " + meta.gem_name(str(s["fam"]), int(s["grad"]))
	if not _unlocked_now.is_empty():
		var s: Stages.StageDef = stages.get(_unlocked_now)
		var namn := Tr.name_of("stage", _unlocked_now, s.name if s != null else _unlocked_now)
		slut += "\n\n" + Tr.t("ui.end.unlocked", "NY BANA UPPLÅST: %s") % namn
	return "%s\n\n%s\n\n%s" % [slut,
		Tr.t("ui.end.hint", "T = tillbaka till byn · R = samma bana igen"),
		Tr.t("ui.settings.language_hint", "L = byt språk (%s)") % Tr.name_of_code(Tr.lang)]

func _show_draft() -> bool:
	if not _draft_pending():
		draft_panel.visible = false
		hand_zone.visible = true
		# Stridspanelen tillbaka: den vek undan medan valet stod uppe (se _show_draft).
		battle_panel.visible = active_combat != null and not active_combat.over()
		return false
	# remove_child FÖRE queue_free: frigöringen är uppskjuten till slutet av bildrutan, och en
	# HFlowContainer lägger ut ALLA barn den har — alltså både de döda och de nya korten, i samma
	# ruta, under en bildruta. Det var felet Alex såg: "kortet flyttar på sig till vänster, och
	# täcker över det som låg där innan".
	for child in draft_box.get_children():
		draft_box.remove_child(child)
		child.queue_free()
	var choices := run.pending_draft()
	# Bossens byte (M45) har sin egen rubrik: valet blir permanent, och det ska synas att det är
	# något annat än en vanlig nivåuppgång.
	draft_label.text = (Tr.t("ui.draft.boss", "BOSSENS BYTE — välj ett kort till samlingen")
		if run.pending_draft_boss() else Tr.t("ui.draft.title", "NIVÅ %d — välj ett kort") % run.level)
	# Är en uppgradering med i valet står receptet under rubriken: den KONSUMERAR två kort, och ett
	# val som ser ut som ett gratis kort är ett val spelaren inte kan göra (samma skäl som "LÅST utan
	# att säga av vad" i smeden). Receptet byggs ur kortens egna namn — ingen ny översättning behövs.
	for id in choices:
		var vald: Cards.Card = db.get(id)
		if Evolution.is_evolution(vald):
			draft_label.text += "\n" + Tr.t("ui.draft.evo", "UPPGRADERING: %s → %s") % [
				Evolution.recipe_text(db, id), vald.title()]
	# VALKORTENS STORLEK: valet är en modal inne i vyn, och vyn är 270 px hög. Panelen står 40 px ned
	# och rubriken (med uppgraderingens recept) tar sin rad — resten är kortets. Utan taket hamnade
	# kortets nederkant UNDER skärmkanten när korten blev 80 % större (mätt i kortvalsprovet: kortet
	# började på 183 och var 212 högt i en 270 px-vy). Kortet är fortfarande större än handens kort.
	# Taket har TVÅ sidor: vyns höjd (rubriken tar sin rad) och vyns bredd (fyra kort i rad, som mest
	# med Luck). BREDDEN binder: fyra kort i 151 px behöver 616 px i en 480 px-vy, och det fjärde
	# kortet klipptes av mot panelens kant (mätt i granskningen — bara kostnadssiffran syntes). Kortet
	# blir 113x158 i vyn, fortfarande större än handens 91x126.
	# KORTVALET RITAS I FÖNSTRETS YTA (M91). Vyn skalas upp med ett heltal till fönstret (2x vid
	# 1280x720), så förut rastrerades allt i valet i 480x270 och förstorades efteråt: kortens text på
	# 5-7 px blev grötig, och konstens pixlar blev olika breda (mätt i bild: block av 2, 3, 4 och 5 px
	# om varandra). Alex: "pixeltätheten på korten behöver dubbleras eller mer, för de är suddiga
	# idag." Panelen ligger nu i `_runt` och räknar i FÖNSTERPIXLAR — samma ruta på skärmen som förut,
	# men varje pixel ritas där den hamnar. `k` är vyns skalning, så ytan blir exakt vyns på skärmen.
	var f := Vector2(get_viewport().get_visible_rect().size)
	var k := maxf(1.0, floorf(minf(f.x / float(VY.x), f.y / float(VY.y))))
	var yta := Vector2(VY) * k
	# Skalan är fortfarande räknad i vyns mått (taket sätts av vyns bredd och höjd) men multipliceras
	# med `k`: korten står på samma plats och i samma storlek på skärmen som förut — bara rastret blir
	# fönstrets i stället för vyns.
	var valskala := clampf(minf((VY.x - 30.0) / (CardView.BIG_SIZE.x * 4.0),
			(VY.y - 60.0) / CardView.BIG_SIZE.y), 0.45, 1.0) * k
	# HELA SKALAN (M78). Den räknade skalan är ett BRÅK (0,745 * k), och då hamnar kortets konstpixlar
	# på delade skärmpixlar: en konstpixel blir 2 px och nästa 3. Mätt i Alex' egen skärmbild av
	# kortvalet: körningslängderna i konsten var 1, 2 och 3 px om varandra (1944 ettor) — samma fel som
	# M91 tog bort ur vyn, kvar i panelens egen skala. Golvet till ett heltal: varje konstpixel lika
	# stor, och korten blir en aning mindre (2 i stället för 2,235 vid 1896x1030) men läses som
	# pixelkonst. Alex: *"De behöver bli betydligt skarpare än så här."*
	valskala = maxf(1.0, floorf(valskala))
	draft_box.custom_minimum_size.x = CardView.BIG_SIZE.x * valskala * 4.0 + 18.0 * k
	for i in choices.size():
		var c: Cards.Card = db[choices[i]]
		var v := CardView.make(c, i, _card_icon(c.id), true, valskala)
		v.picked.connect(_on_draft_pick)
		draft_box.add_child(v)
	draft_panel.visible = true
	draft_panel.move_to_front()
	# CRT-lagret läser skärmen bakom sig och ska ligga ÖVERST (se test_meny). Ett val som flyttar fram
	# sig själv hamnar annars ovanpå filtrets skärm, och då ser valet plötsligt annorlunda ut än
	# resten av spelet.
	if crt != null:
		_runt.move_child(crt, -1)
	# HANDEN VIKER UNDAN medan valet står uppe. Sedan korten blev 80 % större ryms inte valet ovanför
	# handen (mätt: valets nederkant 592 mot handens överkant 468), och överlappande rutor betyder att
	# handens kort kan ta klicket — precis Alex' fel i M34, som mättes igen i test_gui ("val 4 -> 4").
	# En modal där valet är det man gör: handen är inte användbar medan valet väntar, så den göms.
	# Provet kontrollerar att inget SYNLIGT handkort ligger över ett valkort.
	hand_zone.visible = false
	# ÖVRE delen av vyn (samma läge som förut, men vyns tak i stället för mitten): handen ligger i
	# vyns nederkant och sköt upp över valets nederkant. Mätt i fönsterpx: valets nederkant låg på
	# 630, handens överkant på 586 — 44 px överlapp, och det vänstra valkortet låg UNDER ett handkort
	# och gick inte att klicka på. at_top ger vyns tak, och taket är fritt.
	# HELA VYN (Alex: *"Denna ruta är lite för stor, den behöver bli mindre, eller läggas över hela
	# HUD'en"*). En lagom stor ruta mitt i bilden lämnade en tom svart yta runt sig, och rubriken
	# klipptes av mot vänsterkanten (mätt i granskningen: "VÅ 2" i stället för "NIVÅ 2"). Som modal
	# äger panelen hela rutan: rubriken ryms, korten får nästan full storlek, och inget ligger kvar
	# och skräpar bakom. Handen viker redan undan (se ovan). Nu i fönsterpixlar, på samma ruta av
	# skärmen som vyn (se `k` ovan).
	draft_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	draft_panel.size = yta
	draft_panel.position = _vy_korg.position
	# Stridspanelen (vyns övre vänstra hörn) viker undan medan valet står uppe: valet är det man gör.
	battle_panel.visible = false
	return true

## De kort spelaren ÄGER: köpta (rang > 0) och hyrda kamrater. Rang 0 betyder att kortet finns i
## datat men inte i spelarens samling — albumet ska visa samlingen, inte katalogen.
func _ägda_kort() -> Array[String]:
	var ut: Array[String] = []
	for id in db.keys():
		var s := str(id)
		if meta.rank(s) > 0 or meta.hired.has(s) or meta.samling.has(s):
			ut.append(s)
	# Sorterade på kostnad och sedan namn: albumet ska gå att bläddra igenom, och en slumpad ordning
	# (den man får ur en Dictionary) flyttar korten mellan två öppningar.
	ut.sort_custom(_före)
	return ut

func _före(a: String, b: String) -> bool:
	var ka: Cards.Card = db.get(a)
	var kb: Cards.Card = db.get(b)
	if ka.cost != kb.cost:
		return ka.cost < kb.cost
	return ka.title() < kb.title()

## Ritar albumet ur `album_ids` och `album_index`. Körs varje gång något ändras (öppning, bläddring,
## klick) och bygger om raden — sju kort är billigt, och en cache hade behövt hållas i takt med metat.
func _show_album() -> void:
	album_ids = _ägda_kort()
	album_index = clampi(album_index, 0, maxi(0, album_ids.size() - 1))
	for barn in album_stor.get_children():
		barn.queue_free()
	for barn in album_box.get_children():
		barn.queue_free()
	if album_ids.is_empty():
		album_label.text = "%s\n%s" % [Tr.t("ui.album.title", "ALBUMET"),
			Tr.t("ui.album.tom", "inga kort i samlingen än — de köps i butiken")]
		album_panel.visible = true
		_place_panel(album_panel, false)
		return
	var c: Cards.Card = db.get(album_ids[album_index])
	album_label.text = "%s — %s\n%s" % [Tr.t("ui.album.title", "ALBUMET"),
		Tr.t("ui.album.rad", "kort %d av %d") % [album_index + 1, album_ids.size()],
		Tr.t("ui.album.hint", "← → bläddra · I eller Esc = tillbaka till byn")]
	album_stor.add_child(CardView.make(c, album_index, _card_icon(c.id), true))
	var fönster := 7
	var från := clampi(album_index - fönster / 2, 0, maxi(0, album_ids.size() - fönster))
	for i in range(från, mini(album_ids.size(), från + fönster)):
		var k: CardView = CardView.make(db.get(album_ids[i]), i, _card_icon(album_ids[i]), false, 0.62)
		k.set_forward(i == album_index)      # det valda kortet står framträtt i raden
		k.picked.connect(_album_välj)
		album_box.add_child(k)
	album_panel.visible = true
	_place_panel(album_panel, false)

func _album_välj(i: int) -> void:
	if album_ids.is_empty():
		return
	album_index = wrapi(i, 0, album_ids.size())
	_show_album()


func _on_draft_pick(index: int) -> void:
	var choices := run.pending_draft()
	if index < 0 or index >= choices.size():
		return
	run.pick_card(choices[index])
	_flush_events()
	_show_draft()
	_refresh()

## BYGGLÄGE (F1): gå in i våningen som den SER UT när man spelar och ställ saker på plats — samma
## scen, samma kamera, samma ljus. Man placerar i rutan man TITTAR PÅ (`Explore.ahead()`), kastar om
## rutan till golv eller vägg, tar bort det som står där, och sparar till kartfilen med F2. Efter varje
## ändring byggs världen om, så man ser resultatet direkt i stället för att gissa.
##
## Varför inte en egen editor-vy: Alex: *"man skall kunna gå in i banan, så som det blir när man
## spelar, och klistra in sånt man vill ha på plats, om något behöver ändras kan man göra det on the
## fly"*. Planlösningen i `game/editor/` ritar en karta; här är man I kartan.
var byggläge := false
## 1-6 i byggläget: samma ordning som `MapIo.KINDS`.
const BYGG_NAMN := {"start": "start", "encounter": "strid", "boss": "boss", "shovel": "spade",
	"chest": "kista", "torch": "fackla"}

func _bygg_rutan() -> Vector2i:
	return run.explore.ahead()

func _bygg_säg(text: String) -> void:
	_logga(text, Color(0.6, 0.95, 0.85))

## Ställ en nod på rutan man tittar på. En nod per ruta och sort, precis som editorns borste: att
## lägga en kista på en kista ska inte ge två kistor.
func _bygg_plats(kind: String) -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	# Reglerna bor i MapIo, delade med ban-editorn: samma fiende, samma guld, samma "en per ruta och
	# sort" — oavsett vilken editor man använder.
	var p := _bygg_rutan()
	var fel := MapIo.placera(f, kind, p, run.stage, bestiary)
	if not fel.is_empty():
		_bygg_säg(fel)
		return
	_build_world()
	_bygg_säg("%s på (%d,%d)" % [BYGG_NAMN.get(kind, kind), p.x, p.y])

func _bygg_bort() -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	var p := _bygg_rutan()
	var bort := MapIo.ta_bort(f, p)
	if bort == 0:
		_bygg_säg("inget att ta bort på (%d,%d)" % [p.x, p.y])
		return
	_build_world()
	_bygg_säg("%d nod(er) borttagna på (%d,%d)" % [bort, p.x, p.y])

## Rutan framför blir golv eller vägg. Att göra en vägg av en ruta med en nod tar bort noden — en vägg
## kan inte bära något (samma regel som editorn).
func _bygg_yta(till_golv: bool) -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	var p := _bygg_rutan()
	f.tiles[p.y][p.x] = Dungeon.FLOOR if till_golv else Dungeon.WALL
	if not till_golv:
		for n in f.nodes:
			if n.pos == p:
				_bygg_bort()
				break
	_build_world()
	_bygg_säg("%s på (%d,%d)" % ["golv" if till_golv else "vägg", p.x, p.y])

## Materialen man kan måla med: samma filer som ligger i assets/tiles/material, sorterade. Listan
## läses från disken i stället för en tabell — lägger Alex ett ark till syns det direkt i spelet.
var bygg_material: Array = []
var bygg_material_i := -1

func _bygg_materiallista() -> Array:
	if bygg_material.is_empty():
		for fil in DirAccess.get_files_at("res://assets/tiles/material"):
			if fil.ends_with(".png"):
				bygg_material.append("material/" + fil.get_basename())
		bygg_material.sort()
	return bygg_material

## M: nästa material läggs på rutan man tittar på. Rutan byggs om, så bytet syns direkt — och det är
## samma väg som allt annat i byggläget: F2 sparar till kartfilen när man är nöjd.
func _bygg_material_nästa() -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	var p := _bygg_rutan()
	var lista := _bygg_materiallista()
	if lista.is_empty():
		_bygg_säg("inga material i assets/tiles/material")
		return
	bygg_material_i = (bygg_material_i + 1) % lista.size()
	f.ytor["%d,%d" % [p.x, p.y]] = lista[bygg_material_i]
	_build_world()
	_bygg_säg("%s på (%d,%d)" % [lista[bygg_material_i], p.x, p.y])

## N: rutan går tillbaka till sitt temas ruta (överstyrningen tas bort, temats bild gäller igen).
func _bygg_material_tema() -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	var p := _bygg_rutan()
	if not f.ytor.has("%d,%d" % [p.x, p.y]):
		_bygg_säg("ingen materialändring på (%d,%d)" % [p.x, p.y])
		return
	f.ytor.erase("%d,%d" % [p.x, p.y])
	_build_world()
	_bygg_säg("temats ruta igen på (%d,%d)" % [p.x, p.y])

func _bygg_spara() -> void:
	var f: Dungeon.Floor = run.explore.floor_ref
	var fel := MapIo.save_map(f)
	if fel.is_empty():
		_bygg_säg("sparat: %s" % MapIo.path_for(f.stage_id, f.index).get_file())
	else:
		_bygg_säg("kan inte spara — %s" % fel[0])

## Ett steg baklänges (S). Samma väg som framåtsteget, med `backward()` i stället: noden man backar
## in på löser ut som vanligt, annars kunde man backa in i en kista utan att få den.
func _step_backward() -> void:
	if run.finished or _draft_pending():
		return
	var err := run.explore.backward()
	if err != "":
		return
	_sfx("step")
	_animate_cam()
	_enter_node_here()

func _step_forward() -> void:
	if run.finished or _draft_pending():
		return
	var err := run.explore.forward()
	if err != "":
		return
	_sfx("step")
	_animate_cam()
	_enter_node_here()

## Striden sker i RUMMET, inte i en meny: står man på fiendens ruta backas man till rutan FÖRE den
## och vänds mot den, och kameran snäpper dit. Alex: *"en strid måste ske i en separat scen i det rum
## man befinner sig, så det inte blir att man kliver fram, och tittar genom fienden, och bara ser sina
## kort."*
##
## Rutan före är den man kom ifrån: utforskarläget går bara framåt (`forward()`), i den riktning man
## tittar, så rutan man kom ifrån ligger bakom blicken. Rummet man gick igenom står därmed kvar bakom
## fienden i stället för att ligga innanför kameran.
##
## MÄTT i demoläget FÖRE: när striden började stod fienden 2,3 m bort (kameran hade inte hunnit fram)
## och spelarens ruta VAR fiendens. Efter: fienden 1,15 m rakt fram, kameran i rutan före.
##
## En återvändsgränd har ingen ruta före. Då står spelaren kvar på rutan — en kamera inne i en mur
## vore värre än en närgången fiende — och provet i test_strid säger till om det någonsin sker.
func _backa_till_rutan_före(node: Dungeon.FloorNode) -> void:
	if run.explore.pos != node.pos:
		return
	var bak: Vector2i = run.explore.pos + Explore.STEP[(run.explore.facing + 2) % 4]
	if run.explore.floor_ref.is_floor_at(bak):
		run.explore.pos = bak
	run.explore.face(node.pos)

## Noden spelaren möter: den man står PÅ (efter en strid, eller en grop man klivit ned i), annars
## den man har FRAMFÖR sig. Att bara titta under fötterna betydde att striden startade med att man
## stod ovanpå fienden — figuren hamnade 0,4 m vid sidan och syntes inte alls (mätt i demoläget).
## EN väg in, delad av tangentbordet och demoläget — annars kan de glida ifrån varandra.
func _enter_node_here() -> void:
	var node := run.explore.node_here()
	if node == null or node.cleared:
		node = run.explore.node_ahead()
	if node == null or node.cleared:
		return
	if node.kind == "shovel":
		# SPADEN KLICKAS (Alex): "spaden måste klickas på när man dödat bossen". Vägen in i rutan
		# tog den förut, och då försvann våningen man just blev klar med innan man hunnit se den.
		return
	if node.kind == "encounter" or node.kind == "boss":
		# Rutan före fienden, och kameran dit: se `_backa_till_rutan_före`.
		_backa_till_rutan_före(node)
		_snap_cam()
		active_node = node
		active_combat = run.enter_node(node)
		if active_combat != null:
			battle_panel.visible = true
			_stage_fight(node)      # uppställning: fienderna måste stå FRAMFÖR spelaren
			# Baslinjen: figurens hp vid stridens START. Sattes den vid första slaget i stället
			# lästes det slaget som "första mätning" och visade varken siffra eller svep — mätt:
			# första kortet i varje strid var helt tyst.
			_enemy_reaktion()
			_refresh_battle()
			_refresh_hand()      # handen byggs bara vid tillståndsbyten, aldrig vid hover
			# Hela HUD:en också (M40): stridens startväg gick förbi _refresh, så statusblocket och
			# fienderutan stod kvar med förra stridens värden tills något annat rörde tillståndet —
			# mätt med guiprovet, där fienderutan var tom ända till dess _refresh kallades för hand.
			_refresh()
			return
	# shovel eller något annat: lös direkt och bygg om våningen
	run.enter_node(node)
	_after_state_change()

## Ligger spaden på spelarens ruta OCH är bossen besegrad? Då är det enda som återstår att klicka på
## den, och ledtråden ska säga det — en grind utan besked ser ut som en trasig tangent.
func _spade_redo() -> bool:
	if run == null or run.finished or _gräver or _spade_nod == null or _spade_nod.cleared:
		return false
	if _draft_pending():
		# Ett kortval blockerar rörelsen (bossens byte ligger framme): spaden får inte tas mitt i
		# valet, för då hade våningen bytts under panelen.
		return false
	# Man står PÅ spadens ruta (efter striden) eller på rutan intill och tittar på den. Båda är
	# "jag ser spaden", och bara den som ser den kan klicka på den.
	if run.explore.pos != _spade_nod.pos and run.explore.ahead() != _spade_nod.pos:
		return false
	for n in run.explore.floor_ref.nodes:
		if n.kind == "boss" and n.pos == _spade_nod.pos and not n.cleared:
			return false
	return true

## Var spaden står på SKÄRMEN (vyns px). Står man på dess ruta ligger den under spelaren, och då går
## den inte att projicera alls (kamerans plan: `unproject_position` svarar (0,0) och skriver
## "Condition p.d == 0" — mätt). Mitten av vyn är då den ärliga träffpunkten: man står på den.
## Var på skärmen spaden sitter, i VYNS px.
##
## Ligger spaden UNDER spelaren (samma ruta) är den utanför kamerans frustum, och då LJUGER
## `unproject_position`: den ger ett påhittat tal (mätt: (240,135) i stället för (240,164) — inte
## (0,0) som den gamla kontrollen letade efter, så den bet aldrig). Frågan ställs därför till
## frustumet, och svaret blir spelarens egna fötter: det är där spaden ligger.
func _spade_på_bild() -> Vector2:
	if _spade_sprite == null or not is_instance_valid(_spade_sprite) or cam == null:
		return Vector2.ZERO
	if cam.is_position_in_frustum(_spade_sprite.global_position):
		return cam.unproject_position(_spade_sprite.global_position)
	return Vector2(VY.x * 0.5, VY.y * 0.86)

## Ett musklick i spelvyn. SPADEN är den enda saken i korridoren som klickas; allt annat sköts med
## tangenterna. Ett klick som gör "något" någon annanstans är ett klick spelaren inte kan förutse.
func _vy_klick(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
		return
	var s := _spade_på_bild()
	if s == Vector2.ZERO:
		return
	# `m.position` ÄR redan i vyns px: Godot räknar om musklicket till kontrollens lokala rum innan
	# `gui_input` får det (mätt: ett klick i fönstret (640,554) kommer in som (240,232) — vyns px,
	# exakt). Att dela med `_vy_korg.scale.x` en gång till gjorde avståndet 145 px i stället för 0, och
	# klicket nekades TYST. Provet som "bevisade" klicket byggde sitt eget event och delade bort
	# skalningen själv, så det mätte sin egen omräkning i stället för spelarens väg.
	var p := m.position
	var d := p.distance_to(s)
	# STÅR SPELAREN PÅ SPADEN ÄR HELA VYN SPADEN: den ligger under fötterna, och ett klick på golvet
	# man tittar på är ett klick på den. Annars gäller radien mot den projicerade punkten.
	var under_fötterna: bool = run != null and _spade_nod != null and run.explore.pos == _spade_nod.pos
	# ETT KLICK SOM INTE GÖR NÅGOT SKA GÅ ATT SPÅRA. Raden hamnar i utdata, inte i HUD:en.
	print("vyns klick: rå %s, i vyn %s, spaden på %s, avstånd %.1f px (radie %.0f), under fötterna %s" % [
		str(m.position), str(p.round()), str(s.round()), d, SPADE_KLICKRADIE,
		"ja" if under_fötterna else "nej"])
	if d <= SPADE_KLICKRADIE or under_fötterna:
		_gräv()

## Gräv ned till nästa våning. Bossen måste vara besegrad först — spaden ligger på hennes ruta, och
## bytet får man av henne. Att klicka i förtid SÄGER det i stället för att tiga.
func _gräv() -> void:
	if not _spade_redo():
		if run != null and not run.finished and _spade_nod != null and not _spade_nod.cleared:
			_sfx("hit")
			_logga(Tr.t("ui.hud.logg.grav_vant", "spaden ligger på bossens ruta — besegra bossen och stå där"),
				Palett.c(11))
		return
	_gräver = true
	var bas := cam.position.y
	await _gräv_ned(bas)
	# Våningen byts MEDAN det är svart: annars ser man två våningar i samma bild, och själva
	# nedstigningen blir ett hopp.
	run.enter_node(_spade_nod)
	_after_state_change()
	await _gräv_upp(bas)
	_gräver = false

## Första halvan: kameran sjunker genom golvet och bilden mörknar.
func _gräv_ned(bas: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(cam, "position:y", bas - GRÄV_DJUP, GRÄV_TID * 0.45).set_trans(Tween.TRANS_SINE)
	if gräv_slöja != null:
		gräv_slöja.visible = true
		t.tween_property(gräv_slöja, "color:a", 1.0, GRÄV_TID * 0.35).set_delay(GRÄV_TID * 0.15)
	await t.finished

## Andra halvan: den NYA våningens kamera börjar där den gamla slutade (under golvet) och stiger upp
## medan ljuset kommer tillbaka. Rörelsen fortsätter i stället för att hoppa — kameran byggs om med
## våningen, så det är en annan kamera som reser sig.
func _gräv_upp(bas: float) -> void:
	cam.position.y = bas - GRÄV_DJUP
	var t := create_tween().set_parallel(true)
	t.tween_property(cam, "position:y", bas, GRÄV_TID * 0.45).set_trans(Tween.TRANS_SINE)
	if gräv_slöja != null:
		t.tween_property(gräv_slöja, "color:a", 0.0, GRÄV_TID * 0.5).set_delay(GRÄV_TID * 0.1)
	await t.finished
	if gräv_slöja != null:
		gräv_slöja.visible = false

func _after_state_change() -> void:
	# Händelserna töms HÄR, en gång per tillståndsbyte. Att bara tömma dem vid kortval gjorde att
	# kistor, facklor och stridslut låg kvar i kön utan ljud eller logg (och det var därför en kista
	# kändes som att gå in i en vägg).
	_flush_events()
	_build_world()
	_refresh_enemy_bars()      # striden är slut: staplarna ska bort med den
	if run.finished:
		battle_panel.visible = false
		end_panel.visible = true
		# Guldet går till banken EN gång, när körningen tar slut. Utan flaggan hade varje
		# uppdatering av skärmen lagt till samma guld igen.
		if not _banked:
			_banked = true
			meta.add_gold(run.gold)
			# Splitter och ädelstenar bankas med guldet, en gång per körning: körningen bär sina fynd
			# och banken får dem först när resan är slut (samma regel som guldet).
			meta.shards += run.shards
			for sten in run.stenar:
				meta.gem_add(str(sten["fam"]), int(sten["grad"]))
			if run.shards > 0 or not run.stenar.is_empty():
				print("bankade %d splitter och %d stenar" % [run.shards, run.stenar.size()])
			# Banan är slut: skriv ner hur långt man kom, och lås upp nästa bana om man nådde sista
			# våningen. Regeln är referensens — att NÅ sista våningen är att klara banan (Pale Reaper
			# dödar dig där), så "klar" betyder "kom dit", inte "överlevde".
			_unlocked_now = meta.note_run(run.stage.id, run.floor_index + 1, run.stage.floors,
				_stage_order)
			if not _unlocked_now.is_empty():
				print("ny bana upplåst: %s" % _unlocked_now)
			if not meta.save():
				push_warning("kunde inte spara: %s" % meta.last_error)
		end_label.text = _end_text()
		_place_panel(end_panel, false)
	_show_draft()
	_refresh()

func _on_card(index: int) -> void:
	if active_combat == null or index >= hand_views.size():
		return
	# Kortet lämnar handen synligt innan draget löses: man ska se VILKET kort som gick.
	if index < hand_views.size() and not run.finished:
		# Kortet flyger till HÖGEN av använda (M34): vägen ut ur handen slutar där kortet hamnar.
		var mål := hog_använd.mitt() if hog_använd != null and hog_använd.visible else Vector2.INF
		await hand_views[index].fly_out(mål)
	var hi := _hand_index(index)
	if active_combat == null or hi >= active_combat.hand.size():
		return
	# Kortet fångas INNAN det spelas: play() tar bort det ur handen, och angreppet behöver veta
	# vilket vapen som svingades (form och färg kommer ur kortet).
	var kort: Cards.Card = active_combat.hand[hi]
	# KVITTERINGEN (Alex: "nu ser det bara ut som kortet försvinner"): kortet lägger en händelse i
	# körningens ström, samma väg som kistan och facklan — då kan en ny kvittering inte bli tyst.
	# Siffrorna är SKILLNADEN mot före, inte råa värden: mana, hälsa och guld räknas ur samma tal som
	# staplarna visar, så en effekt som ligger i en underfunktion kvitteras också.
	var _mana_före: float = active_combat.mana
	var _hp_före: float = active_combat.hp
	var _guld_före: int = run.gold
	var r := active_combat.play(hi)
	if r.reason.is_empty():
		run.events.append({"type": "card", "card": r.card_id,
			"mana": int(round(active_combat.mana - _mana_före)),
			"hp": int(round(active_combat.hp - _hp_före)),
			"gold": run.gold - _guld_före})
	if not r.ok:
		print("kan inte spela: %s" % r.reason)
		_logga(Tr.t("ui.hud.logg.nej", "kan inte spela %s — %s") % [kort.title(), r.reason],
			Palett.c(22))
	else:
		_sfx("crit" if r.multiplier >= 3 else "card")
		# Loggen: vad kortet gjorde, med siffrorna ur speltillståndet. Skadan läses ur samma rapport som
		# fienden reagerar på, så raden kan inte säga något annat än slaget gjorde.
		if r.damage > 0.0:
			_logga(Tr.t("ui.hud.logg.skada", "%s: %.0f skada ×%d") % [kort.title(), r.damage,
				r.multiplier], Palett.c(11))
		else:
			_logga(Tr.t("ui.hud.logg.spelat", "%s spelas") % kort.title(), Palett.c(23))
		var träffad := _enemy_reaktion(r.multiplier)
		_attack_fx(kort, träffad, r.multiplier)     # figuren visar vad siffrorna redan gjort
	_end_or_continue()

func _on_play_all() -> void:
	if active_combat == null:
		return
	# Handen sparas före auto_play: den tömmer den, och varje spelat kort ska ha sitt eget vapen.
	var kvar: Array = active_combat.hand.duplicate()
	var results := active_combat.auto_play()
	for r in results:
		print("spelade %s x%d (%.0f)" % [r.card_id, r.multiplier, r.damage])
	if not results.is_empty():
		var best := 0
		for r in results:
			best = max(best, r.multiplier)
		_sfx("crit" if best >= 3 else "card")
		var träffad := _enemy_reaktion(best)
		# Solvern tömmer hela handen: ett svep per kort, tätt efter varandra. Ett enda svep hade
		# sett ut som ett kort, och det var fem.
		var senaste: Cards.Card = null
		for r in results:
			var k: Cards.Card = senaste
			for c in kvar:
				if str(c.id) == str(r.card_id):
					k = c
					break
			if k != null:
				senaste = k
				_attack_fx(k, träffad, r.multiplier)
				await get_tree().create_timer(0.09).timeout
	_end_or_continue()

func _on_end_turn() -> void:
	if active_combat == null:
		return
	## Förvarningen först: fienderna spänner sig INNAN slaget faller, så spelaren ser vem som slår
		# och vad det kostar. Två korta steg — en sekund sammanlagt — inte en väntan man sitter i.
		#
		# MÄTT FYND (önskemål 6): väntan var 0,35 s medan förvarningen hålls i 0,6 — slaget föll alltså
		# medan fienden fortfarande spände sig, och kvar blev bara hugget. Granskningarna pekade på samma
		# sak två gånger: det som saknas är en HÅLL-BEAT, inte fler pixlar. Väntan är därför lika lång som
		# förvarningen: spänningen hinner ses klart, och först då faller slaget.
		_enemy_läge_alla(ENEMY_WINDUP, FÖRVARNING_TID)
		await get_tree().create_timer(FÖRVARNING_TID).timeout
	if active_combat == null:
		return
	var hp_före: float = active_combat.hp
	active_combat.end_turn()
	if active_combat.hp < hp_före:
		_blink_röd(hp_före - active_combat.hp)
		# Loggen: vad fienderna gjorde med dig. Namnen är de levande fiendernas, så raden säger vem.
		_logga(Tr.t("ui.hud.logg.anfall", "%s slår dig: %.0f skada") % [_fiende_namn(), hp_före - active_combat.hp],
			Palett.c(12))
	_enemy_läge_alla(ENEMY_STRIKE, 0.35)
	await get_tree().create_timer(0.3).timeout
	_end_or_continue()

func _end_or_continue() -> void:
	if active_combat == null:
		return
	if active_combat.over():
		run.leave_node(active_node, active_combat)
		active_combat = null
		active_node = null
		battle_panel.visible = false
		_after_state_change()
		# Striden kan ha lämnat kvar en nod på samma ruta (shoveln ligger på bossens ruta).
		# Utan den här kollen måste spelaren gå bort och tillbaka för att plocka upp den.
		_enter_node_here()
		return
	_refresh_battle()
	_refresh_hand()
