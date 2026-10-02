# Ljuskäglor: den stilenliga god-rays-tekniken och lyktans kägla

Frågan har två ben: den inbyggda vägen (volymetrisk dimma + ljusens `light_volumetric_fog_energy`)
och den stilenliga vägen (nekotogd-tutorialens quad-/skärmrumsshader), och vilken av dem som
passar lyktan respektive facklorna i det här repot. Detta är en ren undersökning — rapporten är
den enda filen som skapats.

Godot-dokumentationen nedan är version 4.7 ("Godot Engine 4.7 documentation in English"), samma
huvudversion som repot bygger mot (`config/features=PackedStringArray("4.7")` i
`game/project.godot:16`).

## Vad en "ljuskägla" faktiskt är i Godot 4

Godot har ingen egen nod som heter "ljuskägla". Det man ser som en kägla i luften är ljus som
sprids i ett medium, och det finns två sätt att få det:

1. **Volymetrisk dimma** i `Environment` + `light_volumetric_fog_energy` per ljuskälla. Ljuset
   integreras genom en froxel-buffert (ett tredimensionellt rutnät i kamerarummmet) och lyser upp
   dimman. Detta är fysikaliskt inspirerat men bara Forward+.
2. **Fusk med quads/billboards**: en genomskinlig yta med en mjuk radiell textur som är additiv och
   alltid vänder sig mot kameran. Ingen beräkning av ljus i ett medium alls — bara en målad glöd.

Godots egen dokumentation säger att den volymetriska dimman *"is only supported in the Forward+
renderer, not the Mobile or Compatibility renderers"* `[belagt:
https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html]`. Repot sätter ingen
`rendering/renderer/rendering_method` i `game/project.godot` (filen är 35 rader och innehåller
ingen sådan rad), så det kör mot motorns standard, Forward+ `[resonemang]`. Repot skriver också
uttryckligen "Forward+" i flera mätkommentarer, t.ex. `game/main.gd:508` och `game/main.gd:366`
`[belagt: game/main.gd]`.

En viktig begränsning: *"Unlike non-volumetric fog, volumetric fog has a *finite* range. This
means volumetric fog cannot entirely cover a large world, as it will eventually stop being
rendered in the distance."* `[belagt: samma volymetriska dimma-sida]`. Det är därför repot kör
både vanlig exponentiell dimma (`env.fog_enabled = true`, `game/main.gd:686`) och volymetrisk
dimma samtidigt — dokumentationen rekommenderar precis den kombinationen för att dölja avlägsna
ytor.

## Den inbyggda vägen — vad repot redan gör

`game/main.gd` sätter upp båda dimtyperna i `_miljö`-blocket (raderna 686–720). Verifierade
värden i koden:

| Egenskap | Värde | Rad |
| --- | --- | --- |
| `env.fog_enabled` | `true` (exponentiell) | 686–690 |
| `env.volumetric_fog_enabled` | `_vol` (default `true`, `main.gd:540`) | 714 |
| `env.volumetric_fog_density` | `0.014` (grundvärde) | 715 |
| `env.volumetric_fog_albedo` | `Color(0.55, 0.52, 0.58)` | 716 |
| `env.volumetric_fog_anisotropy` | `0.35` | 717 |
| `env.volumetric_fog_length` | `26.0` | 718 |
| `env.volumetric_fog_gi_inject` | `0.6` | 719 |
| `env.volumetric_fog_ambient_inject` | `0.25` | 720 |

Tätheten och albedon skrivs dessutom om per tema i `_apply_tema()` (`game/main.gd:5234–5236`):
`env.volumetric_fog_density = clampf(dimma * 0.32, 0.006, 0.05)` och
`env.volumetric_fog_albedo = env.background_color.lightened(0.5)`. Kommentaren där säger att
taket 0,05 är mätt: över det blir lyktan en grå vägg.

Egenskapernas betydelse, från dokumentationen `[belagt: .../volumetric_fog.html]`:

- **Anisotropy**: 0,35 betyder att ljuset sprids något framåt — käglan syns tydligast när man ser
  *mot* ljuset. Det stämmer med repots kommentar "mest ljus framåt" (`game/main.gd:717`).
- **Length**: avståndet över vilket dimman beräknas. Repots 26 m mot dokumentationens standard 64
  är medvetet kort: *"For best quality fog, keep this as low as possible."* Lyktans räckvidd är
  9 m (`LYKTA_RACKVIDD`, `game/main.gd:342`) och facklans 6,5 m (`LAGA_RACKVIDD`, `main.gd:357`),
  så 26 m räcker med god marginal.
- **GI Inject / Ambient Inject**: skalar hur mycket globalt respektive omgivande ljus påverkar
  dimfärgen. Båda kostar lite prestanda över 0. Repot kör 0,6 och 0,25.

### Ljusen i dimman

Både lyktan och varje fackla är `OmniLight3D` (punktljus) med `light_volumetric_fog_energy` satt:

- Lyktan: `game/main.gd:5520–5533`. `_lykta.light_volumetric_fog_energy = 1.0` (rad 5532), och
  noden läggs som barn till kameran (`cam.add_child(_lykta)`, rad 5533) — den följer alltså
  spelaren.
- Facklorna: `game/main.gd:5554–5568`. `ljus.light_volumetric_fog_energy = 2.2` (rad 5563).
  Kommentaren säger att energin är högre än lyktans med flit — facklan ska synas på håll.

Dokumentationen bekräftar mekanismen: *"all light types will interact with volumetric fog. How
much each light will affect volumetric fog can be adjusted using the **Volumetric Fog Energy**
property on each light. Enabling shadows on a light will also make those shadows visible on
volumetric fog."* `[belagt: .../volumetric_fog.html]`. Egenskapsnamnet i kod är
`light_volumetric_fog_energy` (verifierat i `game/main.gd:5532` och `5563`).

En punktljuskälla har ingen riktning och ingen kon. Den volymetriska dimman runt en `OmniLight3D`
blir därför en **glödboll/klot**, inte en "kägla" — anisotropin gör den starkare sett mot ljuset,
men den har ingen kant. Vill man ha en synlig strålkonskägla är `SpotLight3D` rätt nod:
*"A Spotlight is a type of Light3D node that emits lights in a specific direction, in the shape of
a cone."* Den lyser i nodens -Z, med `spot_angle` (standard 45°, "the angular radius") och
`spot_range` `[belagt: https://docs.godotengine.org/en/stable/classes/class_spotlight3d.html]`.

### "Volumetrisk dimma som ren ljuslösning"

Dokumentationen har ett särskilt avsnitt om att använda volymetrisk dimma *enbart* som
ljusspridning utan att gråa ner rummet: sätt tätheten till lägsta värdet över noll (`0.0001`) och
höj ljusens `light_volumetric_fog_energy` till *"Values between `200.0` and `5000.0` usually work
well"* `[belagt: .../volumetric_fog.html]`. Repot är i den andra änden av skalan: täthet
0,006–0,05 och energi 1,0/2,2. Repot valde alltså den "dimma som också döljer avstånd"-modellen,
där dimman grånar även oupplysta ytor.

### Temporal reprojection och rörliga ljus

Dokumentationen varnar: temporal reprojection *"does lead to moving FogVolumes and Light3Ds
'ghosting' and leaving a trail behind them"*, och *"Short-lived dynamic lighting effects should
have **Volumetric Fog Energy** set to `0.0` to avoid ghosting."* `[belagt:
.../volumetric_fog.html]`. Repot har två rörliga saker: lyktan är barn till kameran och flyttas
varje bildruta, och `_fladdra()` (`game/main.gd:5987–5997`) modulerar facklornas energi med två
sinusvågor (`1.0 + 0.10*sin(...) + 0.05*sin(...)`). Att fackel-energin rör sig är i sig litet
(±15 %), men det är värt att veta att just rörliga ljus är den kända ghosting-källan.

## Den stilenliga vägen — nekotogd-tutorialen

Källan är `https://github.com/nekotogd/Stylized_Volumetric_Lights_Tutorial`. Repots README lyder
i sin helhet: *"Pre-written Code from my Stylized Volumetric Lights in Godot 3 Tutorial"* och
länkar videon `https://www.youtube.com/watch?v=y59QJg7yNkM` `[belagt:
.../README.md]`. Att det är Godot 3 syns också i shaderkoden: den använder den gamla
`SCREEN_TEXTURE` utan hint `[resonemang]`.

De fyra shader-filerna i fulltext `[belagt: raw.githubusercontent.com/nekotogd/...]`:

**`fullscreen_quad.shader`** — en helskärmsyta som ritar en platt färg:

```glsl
shader_type spatial;
render_mode unshaded;

uniform vec4 color : hint_color = vec4(1.0);

void vertex(){
	POSITION = vec4(VERTEX, 1.0);
}

void fragment(){
	ALBEDO = color.rgb;
}
```

`POSITION = vec4(VERTEX, 1.0)` är knepet som lägger quaden i urklippningsrymden och gör den
skärmfylld oavsett kamera.

**`object_brightness.shader`** — den "kägla" som läggs över ett föremål. Den räknar avståndet från
mitten i *vy-rymden* och tonar ut med `smoothstep`:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color : hint_color = vec4(1.0);
uniform float look_size = 3.0;
uniform float look_blend = 2.0;

varying vec3 model_position_view_space;
void vertex(){
	model_position_view_space = MODELVIEW_MATRIX[3].xyz;
}

void fragment(){
	float attenuation = distance(vec2(0.0), model_position_view_space.xy);
	attenuation = smoothstep(look_size, look_size + look_blend, attenuation);

	ALBEDO = mix(color.rgb, vec3(0.0), attenuation);
}
```

**`volumetric_camera_blur.shader`** — suddar skärmen och används som "mjuk" kopia:

```glsl
shader_type canvas_item;

uniform float blur_amount = 30.0;

void fragment(){
	vec3 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV, blur_amount).rgb;
	COLOR.rgb = screen_color;
}
```

**`main_camera_post_processing.shader`** — lägger ihop en separat viewport-textur additivt över
bilden:

```glsl
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D viewport_texture;
uniform float alpha : hint_range(0.0, 1.0) = 0.4;

void fragment(){
	vec3 volumetric_color = texture(viewport_texture, UV).rgb;
	COLOR = vec4(volumetric_color, alpha);
}
```

Läser man shaderkoden ser man att **ingen av dem rör djupet**. `object_brightness.shader` mäter
bara avstånd i `.xy` i vy-rymden; `volumetric_camera_blur.shader` samplar bara färg från
skärmen. Det finns ingen `DEPTH_TEXTURE`, ingen ocklusion och ingen räkning av ljus genom ett
medium. Att det ser volymetriskt ut är en *billboard med en mjuk radiell toning som adderas*, inte
spridning i dimma `[resonemang, grundat på shaderkoden ovan]`. Det stämmer med vad Godots egen
dokumentation kallar "Faking volumetric fog using quads":

> *"The fog effect has less realistic falloff, especially if the camera enters the fog."*
> *"Quads do not require temporal reprojection to look smooth, which makes them suited to
> fast-moving dynamic effects such as lasers. They can also represent small details which
> volumetric fog cannot do efficiently."*
> *"Quads work with any rendering method, including Mobile and Compatibility."*
> `[belagt: https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html]`

Godot 4-versionen av receptet (samma sida): `MeshInstance3D` med en `QuadMesh`,
`StandardMaterial3D` med `Shading Mode = Unshaded`, `Billboard > Mode = Enabled`, `Proximity Fade`
på, `Distance Fade = Pixel Alpha`, och en radiell albedotextur (alfakanalen = täthet).

### Från Godot 3 till Godot 4: SCREEN_TEXTURE och DEPTH_TEXTURE

Frågan nämner `DEPTH_TEXTURE`/`hint_depth_texture`. I Godot 4 är de gamla
Godot 3-uniformerna borta och ersatta av hints `[belagt:
https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html]`:

- Godot 3:s `SCREEN_TEXTURE` → `uniform sampler2D x : hint_screen_texture;` + den inbyggda
  variabeln `SCREEN_UV`. Exempel ur dokumentationen:
  `COLOR = textureLod(screen_texture, SCREEN_UV, 0.0);`.
- Godot 3:s `texture(SCREEN_TEXTURE, SCREEN_UV, lod)` → `textureLod(screen_tex, SCREEN_UV, lod)`,
  och filtret måste innehålla `mipmap` i namnet (`filter_nearest_mipmap` e.d.), annars har en LOD
  över 0 ingen effekt. Tutorialens `blur_amount`-sampling är alltså precis den rad som måste
  skrivas om.
- Godot 3:s `DEPTH_TEXTURE` (spatial) → `uniform sampler2D depth_texture : hint_depth_texture`.
  Djupet är icke-linjärt och måste vecklas ut med `INV_PROJECTION_MATRIX`:
  `vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);`.
- I 3D-dokumentationen: *"the screen is copied after the opaque geometry pass, but before the
  transparent geometry pass, so transparent objects will not be captured in the screen texture"*.

Repot använder redan Godot 4-mönstret för skärmläsning i `game/ui/crt.gdshader:32`:
`uniform sampler2D skarm : hint_screen_texture, filter_linear;` — det är alltså känt territorium.

## Lyktan mot facklorna — vilken väg passar vad

**Facklorna** är fasta punkter i rummet. Den inbyggda vägen passar dem bra: de är korta, stilla
(utom fladdret) och behöver lysa upp omgivningen. Men eftersom de är `OmniLight3D` blir dimman
runt dem klotformad, inte kägelformad. En riktig "kägla" skulle kräva `SpotLight3D`.

**Lyktan** sitter i handen och följer kameran. Här finns två rimliga läsningar:

- *Inbyggd väg, klot*: `OmniLight3D` som nu. Eftersom ljuset alltid ligger strax framför ögat
  fyller det luften framför spelaren jämnt — vilket passar en lykta som lyser åt alla håll.
- *Inbyggd väg, kägla*: byta till `SpotLight3D` riktad framåt ger en tydlig strålkonskägla. Men
  ett spotlight tappar ljuset åt sidorna, vilket kan göra golv/vägg intill mörkare och försämra
  läsbarheten i en 480×270-pixelvy.
- *Stilenlig quad*: en billboard med additiv radiell textur fäster på kameran. Det ger den
  "målade" glöden från tutorialen, fungerar i alla renderare, kräver ingen temporal reprojection
  och är nästan gratis i den låga upplösningen. Nackdelen är att den inte samspelar med miljön
  (ingen ocklusion, ingen påverkan av väggar) — exakt det Godot varnar för med "less realistic
  falloff".

En rimlig arbetsfördelning: behåll den volymetriska dimman för att facklor och lykta sprider ljus
i luften, och lägg den stilenliga quad-tekniken ovanpå för att ge lyktans glöd en tydlig, målad
form. De kan samexistera.

## Vad jag inte kunde belägga

- **Att tutorialens kommentarer säger att tekniken inte är volymetrisk.** Jag har läst de fyra
  shader-filerna i fulltext och README, men inte repo-kommentarer eller videon. Slutsatsen att
  ingen djupinformation används vilar på att shaderkoden inte samplar något djup `[resonemang]`,
  inte på en uttalad källa.
- **Videons innehåll.** Endast README:s titel och länk är belagda; jag har inte kunnat se videon,
  så alla visuella påståenden om tutorialens slutresultat är obelagda.
- **Att nekotogd-repot uttryckligen är Godot 3** är belagt via README ("Godot 3 Tutorial"), men
  vilken exakt Godot 3.x-version eller om shader-filerna är oförändrade över tid är inte
  verifierat.
- **Om ett `SpotLight3D` med `light_energy = 0` fortfarande bidrar till dimman.** Jag har inte
  hittat en källa på att `light_volumetric_fog_energy` är oberoende av `light_energy`; det är
  därför jag inte föreslår det som säkert i nästa avsnitt.
- **Vilket renderingsläge repot *faktiskt* startar i.** `game/project.godot` sätter ingen
  `rendering_method`; att det är Forward+ bygger på motorns standard och repots kommentarer
  `[resonemang]`, inte på en explicit inställning.

## Vad jag skulle ändra i det här repot

Alla förslag är experiment som ska mätas mot en bild, precis som repots andra rattar (t.ex.
`-- vol=0` finns redan som jämförelseflagga, `game/main.gd:629–630`).

1. **Låt fackelkäglan bli en kägla, inte ett klot.** I `_add_lagor()` (`game/main.gd:5554`) skapas
   `OmniLight3D.new()`. Pröva i stället `SpotLight3D.new()`, rikta dess -Z in i rummet (nodens
   rotation), sätt `spot_angle` kring 50–60° och `spot_range = LAGA_RACKVIDD` (6,5), och behåll
   `light_volumetric_fog_energy = 2.2` samt `light_energy = LAGA_ENERGI * _ljus_f`. Man skulle se
   en riktad ljuskägla i dimman i stället för en rund glödboll — men också mörkare ytor bakom
   facklan, så `LAGA_ENERGI` kan behöva höjas för att kompensera.
2. **Pröva dimma-som-ren-ljusspridning.** I `_apply_tema()` (`game/main.gd:5235`) är golvet i
   `clampf(..., 0.006, 0.05)`. Dokumentationens "volumetric lighting"-recept är täthet 0,0001 och
   ljusenergi 200–5000. Motsvarande ändring vore att sänka nedre gränsen mot 0,0001 och höja
   `_lykta.light_volumetric_fog_energy` (rad 5532) samt facklornas (rad 5563) kraftigt. Man skulle
   se att rummets oupplysta delar slutar gråna, medan bara ljusen blommar i luften. Eftersom
   tätheten är temastyrd och mätt, mät mot `-- vol=0` och samma kamera innan något blir standard.
3. **Testa temporal reprojection vid rörelse.** `env.volumetric_fog_temporal_reprojection_enabled`
   är inte satt i koden och har alltså dokumentationens standard `true`. Eftersom lyktan följer
   kameran och facklorna fladdrar, är det värt att mäta om det uppstår eftersläpning/trail när man
   straffar. Försök: sätt `env.volumetric_fog_temporal_reprojection_enabled = false` (eller sänk
   `volumetric_fog_temporal_reprojection_amount`) i `_miljö`-blocket vid rad 714–720 och jämför
   två skärmbilder tagna under samma rörelse. Man skulle se mindre smetning men möjligen mer
   jitter.
4. **Lägg den stilenliga quad-tekniken i `game/ui/`** som ett komplement, inte ersättning. Repot
   har redan en `canvas_item`-shader som läser skärmen (`game/ui/crt.gdshader`) och en HUD-stack;
   samma mönster med `hint_screen_texture` + `filter_linear_mipmap` räcker för tutorialens
   blur-add. En billboardad `QuadMesh` på kameran med `unshaded`, `billboard`, `proximity_fade` och
   additiv albedo skulle ge lyktans glöd en målad kant. Man skulle se en tydligare, mer
   "ritad" ljuskägla kring lyktan, oberoende av renderare. (Detta är alltså en framtida ändring —
   den här uppgiften fick bara skapa rapportfilen.)
5. **Rör inte lyktans typ utan att mäta sidoljuset.** Punkt 1:s byte till `SpotLight3D` är
   frestande för lyktan också, men ett spotlight släpper ljuset åt sidorna; i en mörk korridor på
   480×270 är sidoljuset det som gör golv och vägg läsbara. Mät hellre en quad-glöd ovanpå den
   befintliga `OmniLight3D` innan lyktans nodtyp byts.
