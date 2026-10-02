# Rök och damm i en volymetrisk scen: partiklar, dimma och hur de samverkar

Frågan: hur får man rök (och svävande damm) att samverka med den volymetriska dimman i stället för
att se ut som platta kort?

Kortversionen först: rök- och dammpartiklar samverkar **inte alls** med Godots volymetriska dimma.
Dimman räknas i en egen froxelbuffert som bara läser *ljus, GI, omgivning och djup* — aldrig partiklars
färg eller alfa. Partiklarna ritas däremot som vanliga genomskinliga quads *ovanpå* resultatet. Vill man
att röken ska "hänga ihop" med dimman måste man därför lura ögat: antingen låta dimman och röken dela
färg/täthet så de tonar ihop, eller byta teknik — "rök i ljuset" (damm som bara syns i lyktkäglan) görs
med **ljuspåverkade** partiklar, inte med dimman.

Nedan går jag igenom varje del av frågan, med repots egen kod som facit.

## 1. Nuläget i repot (verifierat mot koden)

Alla partiklar i spelet byggs i `game/core/fx.gd` (klassen `Fx`), alltid med `GPUParticles3D` via
`_moln()`. Det finns **ingen** `CPUParticles3D` i repot — jag grepade efter både `GPUParticles3D` och
`CPUParticles3D` och hittade bara den förra.

- **Röken** ovanför en fackla: `Fx.fackla()`, `game/core/fx.gd:310`, `_moln(RÖK_ANTAL, 2.8,
  BLEND_MODE_MIX, RÖK_STORLEK, "rok")`. `RÖK_STORLEK = Vector2(0.20, 0.20)` (`fx.gd:265`).
- **Dammet**: `Fx.damm()`, `fx.gd:368`, `_moln(40, 9.0, BLEND_MODE_ADD, Vector2(0.018, 0.018))`.
  Det sitter **på kameran** (`kamera.add_child(p)`, `fx.gd:390`) och kopplas in en gång i
  `main.gd:4845` (`Fx.damm(cam)`).
- **Partikelytan** (`fx.gd:179`, `_yta()`): en `QuadMesh` med `billboard_mode = BILLBOARD_ENABLED`
  och `billboard_keep_scale = true`. Skuggningen sätts av `glöd`-flaggan:
  `shading_mode = SHADING_MODE_PER_PIXEL` om `glöd` (elden/lavan, som är *emitterande*), annars
  `SHADING_MODE_UNSHADED` — alltså röken och dammet är **unshaded**, de varken tar emot eller påverkar
  ljus.
- **Dimman** byggs i `main.gd:714–720` på `WorldEnvironment` (`env.volumetric_fog_enabled = _vol`,
  `volumetric_fog_density = 0.014`, `albedo`, `anisotropy = 0.35`, `length = 26.0`, `gi_inject = 0.6`,
  `ambient_inject = 0.25`). Per tema: `_apply_tema()` sätter
  `volumetric_fog_density = clampf(dimma * 0.32, 0.006, 0.05)` (`main.gd:5235`).
- **Ljuset i dimman**: lyktan `_lykta.light_volumetric_fog_energy = 1.0` (`main.gd:5532`), varje fackla
  `ljus.light_volumetric_fog_energy = 2.2` (`main.gd:5563`).

Redan här syns problemet: röken/dammet är unshaded quads, dimman är en separat volym. De två lagren
möts bara i färgrymden, inte i ljuset.

## 2. GPUParticles3D mot CPUParticles3D

Dokumentationen beskriver `CPUParticles3D` som en CPU-baserad emitter och hänvisar till
`GPUParticles3D` som "samma funktion med hårdvaruacceleration, men som kanske inte kör på äldre
enheter" [belagt: https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html].

För rök/damm i den här scenen spelar skillnaden nästan ingen roll — **båda ritas som samma billboards
och båda är osynliga för dimman**:

| | GPUParticles3D | CPUParticles3D |
|---|---|---|
| Var partiklarna simuleras | GPU | CPU |
| Skala | hundratusentals partiklar | tusentals, innan det tar CPU-tid |
| Åtkomst från GDScript | i princip ingen (bara via shader/`ParticleProcessMaterial`) | läser/skriver `emission_points`, `emission_colors`, `emission_normals` per partikel |
| Interaktion med volymetrisk dimma | ingen | ingen |

Den enda riktiga skillnaden som är relevant här är att `CPUParticles3D` exponerar per-partikel-data
(`emission_points`, `emission_colors`, `emission_normals`) [belagt:
https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html], vilket gör det möjligt att
exempelvis placera ett dammkorn exakt i lyktkäglans kon. Men eftersom käglan ändå rör sig med spelaren
är det mycket enklare att låta ljuset sköta sorteringen (se §6) än att räkna ut konen i CPU-kod.
Spelets val av `GPUParticles3D` är alltså rätt; problemet ligger inte i simuleringen utan i *ytan*.

## 3. `material_override` med `shading_mode`

`GPUParticles3D` (och `CPUParticles3D`) ärver `material_override` från `GeometryInstance3D`
[belagt: https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html]. En override
byts ut mot **alla** material i emitterarens draw-passer och är det enda material som ritas.

I det här repot används **inte** `material_override` på partiklarna — materialet sitter i stället på
varje `draw_pass_1`-quad (`q.material = _yta(...)`, `fx.gd:219`), och `game/tests/test_fx.gd:45` kräver
uttryckligen att `låga.material_override == null`. Det är medvetet: `_moln()` bygger en enda pass, så en
override vore bara ett onödigt lager, och för eldens del måste materialets `shading_mode` vara
`SHADING_MODE_PER_PIXEL` med emission (glöden) medan röken i samma fackla ska vara unshaded — två
material som inte kan dela en override.

Poängen att ta med sig om man ändå använder `material_override`: `shading_mode` på det materialet
bestämmer **om kortet deltar i ljuset eller inte**. `SHADING_MODE_UNSHADED` "inaktiverar all interaktion
med ljus" [belagt: https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html]. En unshaded
billboard visar alltid sin texturfärg — den läser platt oavsett var ljuset står. Det är exakt vad som
händer med röken i dag: `_yta()` ger röken `SHADING_MODE_UNSHADED` (`fx.gd:182–183`), så den är ett
platt, självlysande kort som ligger ovanpå en dimma som faktiskt reagerar på ljuset. De två "motsäger"
varandra för ögat.

## 4. Particle-billboards i en volymetrisk scen

En particle-billboard är en quad som alltid vänder Z-axeln mot kameran
(`BILLBOARD_ENABLED`) [belagt: https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html].
Det ger den klassiska "platta kortet"-känslan i en 3D-volym: från sidan är röken en pappskiva med en
rök-textur på, och den genomskinliga kanten mot dimman är skarp.

Godots egen dokumentation för volymetrisk dimma beskriver ett bättre sätt att tänka på det här: en
"fake volumetric fog" av quads — `StandardMaterial3D` med `Shading > Shading Mode = Unshaded`,
`Billboard > Mode = Enabled`, **`Proximity Fade` påslagen** och **`Distance Fade = Pixel Alpha`**
[belagt: https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html]. Det är `proximity_fade`
och `distance_fade` som är nyckeln: de mjukar ut quadens kant så den inte läser som ett kort med en hård
silhuett, utan tonar in i omgivningen. I repot saknas båda på röken — `_yta()` sätter bara
`transparency = TRANSPARENCY_ALPHA`, `blend_mode`, `billboard_mode` och `vertex_color_use_as_albedo`
(`fx.gd:184–197`).

Samma avsnitt nämner också de två problemen med quad-approach: transparens-sorteringsfel när sprites
överlappar, och att kostnaden kan överskrida äkta volymetrisk dimma när många sprites ligger nära
kameran [belagt: samma URL]. För dammet (40 additiva quads rakt i ansiktet på kameran) är det andra
akademiskt, men sorteringsfelet är reellt när ett rökkort passerar ett dammkort.

## 5. `StandardMaterial3D` med `billboard_mode` + `depth_draw_mode`

Båda egenskaperna sitter på `BaseMaterial3D` (ärvs av `StandardMaterial3D`):

- **`billboard_mode`** [belagt: https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html]:
  - `BILLBOARD_DISABLED` (0) — quaden ligger fast i världen.
  - `BILLBOARD_ENABLED` (1) — Z-axeln mot kameran (det repot använder).
  - `BILLBOARD_FIXED_Y` (2) — X-axeln mot kameran, Y låses (stående skyltar som inte ska luta).
  - `BILLBOARD_PARTICLES` (3) — för partikel-flipbooks; aktiverar `particles_anim_*`.
  För rök/damm är `ENABLED` rätt; `PARTICLES` är bara relevant om man byter till en animerad rökflipbook.
- **`depth_draw_mode`** [belagt: samma URL]:
  - `DEPTH_DRAW_OPAQUE_ONLY` (0, default) — transparenter skriver **inte** djup.
  - `DEPTH_DRAW_ALWAYS` (1) — skriver djup även i den transparenta passen.
  - `DEPTH_DRAW_DISABLED` (2) — skriver aldrig djup.

Här ligger ett konkret samspel med dimman: rök med `DEPTH_DRAW_ALWAYS` skriver djup, och därmed
**occluderar** röken det som är bakom — inklusive dimmans froxel-sampel vid kanterna — så rökens
silhuett "skär" hål i dimman i stället för att smälta ihop med den. Med default (`OPAQUE_ONLY`) skrivs
inget djup, och röken blandas additivt/mixat ovanpå dimman utan att störa den. För en rök som ska
samverka med dimman vill man i de allra flesta fall **inte** skriva djup — tvärtom vill man använda
`proximity_fade`/`distance_fade` (§4) för att mjuka upp kanten.

En separat men viktig egenskap: `FLAG_DISABLE_FOG` / `disable_fog` stänger av "mottagning av depth-baserad
eller volymetrisk dimma" för ett material [belagt:
https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html]. Det är den enda "kopplingen"
mellan ett partikelmaterial och dimman som finns — och den är en *avstängning*, inte en samverkan.

## 6. Hur partiklar påverkar dimman — de gör det inte (och varför)

Den volymetriska dimman beräknas i en froxelbuffert och tar sin indata från:

- **ljus** — "alla ljustyper interagerar med volymetrisk dimma", reglerat per ljus via
  `Volumetric Fog Energy` [belagt: https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html],
- **skuggor** — "att slå på skuggor på ett ljus gör också skuggorna synliga i den volymetriska dimman"
  [belagt: samma URL],
- **GI, ambient och sky** via `GI Inject`, `Ambient Inject` och `Sky Affect` [belagt: samma URL].

Partiklar är **ingen av de sakerna**. En rökpartikel är inte ett ljus, den har ingen `volumetric_fog_energy`,
och en genomskinlig billboard skriver varken djup (default) eller deltar i ljusens skuggkarta — så den
kan inte heller kasta en skugga in i froxelbufferten. Därför färgar, skymmer eller lyser partiklar **inte**
dimman: dimman ritas precis som om partiklarna inte fanns, och partiklarna ritas sedan ovanpå. Att en
dammpartikel råkar ligga mitt i lyktkäglan gör alltså inte käglan ljusare, och en rökridå gör inte dimman
bakom den mörkare.

Detta är delvis ett resonemang: dokumentationen säger uttryckligen att det är *ljus* som interagerar med
dimman, men den formulerar aldrig negativt "partiklar påverkar inte dimman". Slutsatsen "partiklar är
inte ljus, alltså påverkar de inte dimman" följer dock direkt ur ljuskravet [resonemang, grundat i
https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html].

## 7. "Rök i ljuset": damm som syns BARA i lyktans kägla

Eftersom partiklar inte kan styra dimman är rätt verktyg för "damm i ljuskäglan" **ljuspåverkade
partiklar**, inte dimman. Två vägar:

1. **Per-pixel-skuggade dammkorn.** Ge dammpartikeln `SHADING_MODE_PER_PIXEL`, `albedo_color = DAMM`,
   `emission_enabled = false` (inget självlysande). Ett per-pixel-material "skuggas per pixel" och deltar
   i belysning [belagt: https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html]. Lyktan
   är den enda punktljuskällan på dammets plats, så kornen är ljusa bara i käglan och nästan svarta
   utanför (ambient-energin är 0.18–0.30 per tema, `main.gd:330–336`). Det är den "riktiga" lösningen:
   dammet är bara synligt för att det reflekterar lyktskenet.
2. **Additivt unshaded damm med låg alfa (dagens lösning).** `Fx.damm()` använder `BLEND_MODE_ADD` med
   en color_ramp som toppar på alfa 0,26 (`fx.gd:381–382`). Additiv blandning *lägger* färg ovanpå
   bakgrunden, så ett korn i totalt mörker (bakgrund ≈ 0,02–0,07) blir en svag grå prick — alltså syns
   det **även utanför** käglan, bara mycket svagare. Kommentaren i `fx.gd:363–367` ("det är bara i ljuset
   de syns") är alltså en sanning med modifikation: additiv blandning gör kornen *tydligare* mot ljus
   bakgrund, men de försvinner inte i mörkret.

Variant 1 är den som faktiskt uppfyller "syns BARA i lyktans kägla". En finess: med `emission_enabled`
**och** per-pixel-skuggning kan man också ge kornen en mycket svag glöd (`emission_energy_multiplier`
runt 0,1–0,2) så de aldrig blir helt svarta mot ett kolmörkt hörn — samma knep som elden använder i
`_yta()` men tvärtom nedskruvat [resonemang].

## 8. Lågupplösningen: 2 px i 480×270, och bandning i CRT:n

Vyn är 480×270 (`VY`, `main.gd:47`), ritad i en `SubViewport` och uppskalad med NEAREST till fönstret
(`_vy_korg.texture_filter = TEXTURE_FILTER_NEAREST`, `main.gd:6134`). Kamerans vertikala FOV är 62°
(`FOV := 62.0`, `main.gd:190`; `cam.fov = FOV`, `main.gd:4836`).

Räkningen (vertikalt): synfältet vid avstånd `d` är `2·d·tan(31°) ≈ 1,20·d` meter på 270 px, så
**1 px ≈ 0,00445·d meter**. En partikel som är `s` meter bred är därför
`s / (0,00445·d) = 225·s/d` bildpunkter [resonemang, trigonometri].

- För `s = 0,018 m` (dagens damm, `fx.gd:369`): **2 px vid ≈ 2 m**, 1 px vid ≈ 4 m. Dammet lever i en
  box med extents 4×1,6×4 m runt kameran (`emission_box_extents = Vector3(4.0, 1.6, 4.0)`, `fx.gd:372`),
  så kornen i ytterkanten är ofta bara 1 px.
- Vill man att ett korn ska vara 2 px på avståndet `d` ska storleken vara `2·0,00445·d ≈ 0,0089·d` meter.
  Vid 2 m: ≈ 0,018 m (dagens värde), vid 4 m: ≈ 0,036 m (dubbelt så stort).

Det här är redan mätt i repot, för dropparna: en droppe på 0,03×0,055 m var "två bildpunkter mot en
ditherad brun vägg" och "drunknade helt i bakgrundsbruset" — därför dubblerades droppen
(`fx.gd:44–48`). Dammet lider av samma sak men är inte mätt.

**Bandning i CRT:n.** Postprocessen `game/ui/crt.gdshader` mörknar varannan rad i *fönstret* med
`rad = mod(FRAGCOORD.y, 2.0)` och `f *= 1.0 − skanlinje·step(1.0, rad)` (`crt.gdshader:60–62`), plus en
kromatisk förskjutning som samplar R och B på `uv.x ± px` (`crt.gdshader:54–58`). Eftersom spelvyn är
uppskalad ×2–×3 till fönstret, täcker ett 1-spelpixel-korn 2–3 fönsterpixlar — och då hamnar en av dess
rader på en mörknad skanlinje. Ett korn som driver vertikalt växlar därför mellan att ligga på en ljus och
en mörk rad, och flimrar/bandar; den kromatiska förskjutningen delar dessutom upp ett 1-px-korn i röda och
blå kanter.

Hur man undviker det:
1. **Håll kornen ≥ 2 spel-px** (storlek enligt ovan), så varje korn alltid täcker både en ljus och en
   mörk skanlinjefas — flimret medelvärdesbildas bort. [resonemang]
2. **Mjuk kant, inte hård pixelkant.** Dammet använder redan en radiell gradient (`Fx.prick()`,
   `fx.gd:119`) och `TEXTURE_FILTER_LINEAR` (`_moln()`, `fx.gd:219`) — en mjuk alfa-kant gör att
   skanlinjemörkningen träffar en gradient i stället för en binär kant. Behåll det. [resonemang]
3. **Dimman själv bandar också** vid högre täthet; dokumentationen hänvisar till avsnittet
   "Color banding" för motåtgärder (ditring etc.)
   [belagt: https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html#doc-3d-rendering-limitations-color-banding].
   Repots täthet är låg (0,006–0,05), så dimman bandar troligen mindre än vad kornen gör i CRT-lagret.

## Vad jag inte kunde belägga

- **"Partiklar påverkar inte dimman" som ett explicit dokumentationspåstående.** Godot-dokumentationen
  listar bara vad som *gör* interagera med dimman (ljus, skuggor, GI/ambient/sky); den skriver aldrig
  ordagrant att partiklar inte gör det. Slutsatsen är min inferens ur ljuskravet (§6).
- **Exakta storleks-/avståndssiffror för "2 px"** är trigonometri ur repots `FOV` och `VY`, inte en
  uppmätt siffra — jag har inte kört ett bildprov. Den enda *mätta* datapunkten är droppen i
  `fx.gd:44–48`.
- **Hur mycket dammet faktiskt flimrar i CRT:n** (om kornen ens ligger på en skanlinje oftare än inte)
  är inte uppmätt här; det är en effekt jag argumenterar för, inte ett facit.
- **Per-pixel-damm + additiv blandning** kan ge en dubbelbelysning (kornet ljussätts *och* adderas);
  exakt vilken blend/albedo som ger bäst "korn i käglan" är en provkörning, inte belagd.

## Vad jag skulle ändra i det här repot

Konkret, i ordning efter nytta per rad:

1. **`game/core/fx.gd`, `Fx.damm()` (rad 369):** byt `Vector2(0.018, 0.018)` mot
   `Vector2(0.032, 0.032)`. Det håller kornen ≥ 2 spel-px även på dammboxens bortre kant (~4 m), så de
   slutar flimra i CRT-skanlinjerna. *Skillnad man ser:* dammet blir stabilt och jämnt i stället för
   flimrande prickar.

2. **`game/core/fx.gd`, `_yta()` (rad 182–197):** sätt `proximity_fade_enabled = true`,
   `proximity_fade_distance ≈ 0.4` och `distance_fade_mode = DISTANCE_FADE_PIXEL_ALPHA` med
   `distance_fade_min/max` satta efter rökkvadens storlek. Det mjukar upp rökkortets hårda kant så röken
   tonar in i dimman i stället för att lägga sig som en pappskiva ovanpå. *Skillnad man ser:* röken
   ovanför facklorna löses upp mot dimman i stället för att ha en skarp kort-kant.

3. **`game/core/fx.gd`, `Fx.damm()` (rad 368):** byt dammmaterialet från unshaded additivt till
   `SHADING_MODE_PER_PIXEL` med `albedo_color = DAMM`, `emission_enabled = false` (motsvarande
   `glöd=true`-grenen i `_yta()` men utan emission). Det gör kornen till små reflektorer som bara lyser i
   lyktans (och facklornas) ljus. *Skillnad man ser:* dammet syns bara i ljuskäglorna, i stället för att
   vara svaga jämngrå prickar i hela rummet — "rök i ljuset".

4. **Rör inte `depth_draw_mode` på röken** (låt den ligga kvar på default `DEPTH_DRAW_OPAQUE_ONLY`). Att
   sätta `DEPTH_DRAW_ALWAYS` skulle låta röken skriva djup och *skära hål* i dimman bakom sig — precis
   tvärtom mot vad frågan vill uppnå. Anteckna det i `_yta()` som en varning snarare än en ändring.
