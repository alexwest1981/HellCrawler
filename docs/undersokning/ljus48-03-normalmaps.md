# Normalmaps: vad ger relief som syns i 480×270?

## Kort svar

Reliefen är redan verklig i materialvägen. Den stora vinsten kommer av användbar ljusriktning och relief i rätt skala, inte att skruva normalstyrkan tills varje texel sticker ut. I repots mätning gav `normal_scale=4` en signal tydligt över mätbruset; starkare skala började äta upp ljuspölarna. Det bevisar att normalen påverkar bilden, inte att reliefen är lätt att läsa för en människa på 480×270. (game/main.gd:966-986, 5391-5405; PLAN.md:1076-1081)

## Hur kartorna blir till

- Den aktiva rutgeneratorn är `tools/gen_tiles.py` (inte `game/tools/...`). Den gör höjd av palettens ton/materialdata, jämnar höjden, och räknar tangentnormal med Sobel över wrapade grannar. Rutorna är nu 128×128 px för 0,5 m, alltså 256 texel/m; `jämna()` dämpar enstaka pixelspretighet före normalen. (tools/gen_tiles.py:46, 96-101, 153-185)
- Normalens R/G är tangentens X/Y och B är Z. Godot väntar sig X+, Y+, Z+ (OpenGL-konvention); en DirectX-karta med Y− måste inverteras. Höjd→normal ska därför ha rätt axelriktning, tangentbas och en konsekvent höjdskala. Kontrollera visuellt med ett enkelt riktningsljus: felvänt Y ger omvänd skuggning, inte mindre relief. (tools/gen_tiles.py:172-190; [belagt: Godots materialdokumentation](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html))
- ORM är R=occlusion, G=roughness, B=metallic. Repot väljer uttryckligen röd/grön/blå kanal för respektive materialingång; AO är aktiverad och `ao_light_affect=1`, så ocklusionen är inte död här. En ORM-fil som bara kopplas till roughness utan att sätta kanalväljare läser fel data. (tools/gen_tiles.py:196-218; game/main.gd:5406-5417; [belagt: BaseMaterial3D-kanalval](https://docs.godotengine.org/en/4.1/classes/class_basematerial3d.html))
- Albedons målade fog är inte höjdkartan. `kant=1` suddar albedon, men normal/ORM lämnas orörda; tidigare A/B gav 2,17 mot 2,06 medel och bedömdes ligga inom variationen. Den dämpningen suddar alltså konsten utan belagd reliefvinst. (game/main.gd:515-529, 5370-5376; PLAN.md:930-942)
- Varning för två generatorer: `tools/gen_plattor.py` skapar 512×512 färgplattor utan normal- eller ORM-utdata; `tools/gen_material_tiles.py` klipper materialark till albedo och skalar till mallstorlek, också utan kartor. De kan inte antas få relief av den aktiva `gen_tiles.py`-kedjan. (tools/gen_plattor.py:36-43, 100-107; tools/gen_material_tiles.py:22-28, 64-79, 110-115)

## Godot-rattar och shaderfällor

- `normal_scale` multiplicerar normalens avvikelse; noll är platt normal och högt värde överdriver lutning. För repots material är grundvärdet 4.0, och svepet säger att 4→10→20 ger bara +43/+47% bildskillnad men mörknar vyn och krymper ljusfläckar. Kanalval för normal är i huvudsak importer-/konventionsfråga; `BaseMaterial3D` använder normaltexturen med röd/grön kanal, medan roughness/metallic/AO har egna kanalväljare. (game/main.gd:5391-5408; PLAN.md:1076-1081; [belagt: Godot-material](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html))
- `roughness_texture` formar glanslobbens bredd/styrka per pixel; `metallic_specular` hör till metallens F0 och skapar inte diffus relief. Repot använder `roughness_texture_channel=GREEN`, metallic från blå och AO från röd. Den äldre mätningen visar dessutom att glans på alla ytor tvättade upp medianen; materialens egen råhetströskel begränsar det. (game/main.gd:390-423, 5406-5418; PLAN.md:1023-1054)
- Mipmaps hjälper när texturen krymper i fjärran genom att minska alias/brus, men filtrerar också bort de minsta höjdkontrasterna. Anisotropisk filtrering bevarar sampling bättre på sneda/avlånga ytor; den kan inte återställa detaljer som täcker klart mindre än en skärmpixel. I 480×270 gäller Nyquist i praktiken: återkommande mönster under cirka två skärmpixlar per period blir instabilt/aliasat; enskilda drag behöver ofta flera pixlar för att läsas som form. Filterneareast är nu valt för standardmaterialen, så provresultat beror på mip-/importinställningar och projektrenderare. ([belagt: mipmaps och import](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_images.html), [belagt: anisotropisk filtrering](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html); [resonemang])
- Egen spatial shader får bara det den själv skriver. `dekor.gdshader` sätter ALBEDO/ROUGHNESS/SPECULAR men ingen `NORMAL_MAP`; shadern är skuggad (inte `unshaded`), men växtdekorens texturrelief påverkar därför inte normalen. `fiende_material.gdshader` är däremot `unshaded` additivt glanslager och ska inte tolkas som normalmappad yta. En shader som inte matar `NORMAL_MAP` är tyst platt relativt normalmap. (game/ui/dekor.gdshader:15-18, 31-38; game/ui/fiende_material.gdshader:21-25, 52-82; [belagt: spatial shader NORMAL_MAP](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html))

## Vad överlever vid 480×270?

Skärmpixelstorlek beror på projektionsyta, avstånd, ytans vinkel och skärmens faktiska visning. 256 texel/m beskriver källan, inte hur många pixlar en texel upptar i bilden. På en stor yta långt bort kan många texlar hamna i samma pixel: högfrekvent normalbrus flimrar eller filtreras bort. Större, sammanhängande fogar/fasetter överlever längre; större normalstyrka gör inte högfrekventa detaljer mer upplösta. (tools/gen_tiles.py:46, 153-185; [resonemang])

`normalprov` är användbart som tekniskt A/B: samma körning/kamera, material som faktiskt ritas, normal av/på, brusgolv genom upprepning, och valfria svep för kant och lyktnivå. `|a−b|` är medel absolut RGB-skillnad per pixel (0–255); den är inte ett perceptuellt reliefmått. Utskriftens medel/p50/p90/p99 samt mörkt/ljust beskriver bildens ljushetsfördelning; de säger inte om en människa uppfattar ett tegel som upphöjt. (game/main.gd:966-986, 1031-1109, 1111-1143)

Det finns alltså inget repo-belagt universellt synlighetsgolv. Sätt ett ärligt tekniskt golv som upprepad nollbildsvariation plus förutbestämd marginal, mät A/B på samma låsta bildyta och körning, redovisa både medel och percentiler samt ROI för golv/vägg. Sätt separat ett mänskligt golv: blindad A/B vid slutlig 480×270, normal spelrörelse och representativa ljuslägen; observatören ska kunna välja reliefbilden bättre än slumpen och beskriva var den sitter. Lås tröskeln före jämförelse. (game/main.gd:978-986, 1031-1053; [resonemang])

## Vad 4.8 ändrar

Den 11 oktober 2026 är Godot 4.8 fortfarande förhandsversion (arkivet anger dev7). Det jag kunde belägga som ny rendererfunktion är mip-level texture streaming i 4.8-dev5: motorn kan använda relevanta mipnivåer utifrån avstånd. Det kan påverka vilken mipnivå som används, men ändrar inte normalernas konvention eller ger materialet automatisk relief. Ingen granskad 4.8-källa visar att `normal_scale`, ORM eller `NORMAL_MAP`-regler ändras; en full release-notes-jämförelse krävs innan man kallar 4.8 slutligt. ([belagt: 4.8-dev5](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-5/), [belagt: 4.8-arkivet](https://godotengine.org/download/archive/))

## Mätbart kontra mänskligt

Kod kan verifiera texturkoppling, valda kanaler, tangent/UV-data, pixelstatistik och reproducerbar A/B-skillnad; repots prov gör flera av dessa kontroller. Koden kan inte avgöra om skillnaden ser ut som relief, målade kanter, plastglans eller brus vid normal spelhastighet. Det kräver bildgranskning på faktisk målupplösning och ljussättning. (game/main.gd:1005-1029, 1095-1143; [resonemang])

## Vad jag inte kunde belägga

- Jag körde inte Godot-prov: detta underlag bygger på repots incheckade mätlogg/kommentarer och dokumentationsgranskning, inte en ny körning.
- Ingen manuell blindgranskning av just 480×270-bilder kunde göras; därför anges inget påhittat perceptuellt tröskelvärde.
- Generatorn `gen_material_tiles.py` kan inte skapa normal-/ORM-kartor med nuvarande kod; källbilderna saknas i worktreen och generatorn kördes inte.
