# Voxlar mot fiendebilder: kostnad, bildvinst och ett litet prov

Alex frågar om fienderna ska bli voxlar för att "pixlar lossnar". Kort svar: **behåll bilderna för vanliga fiender; gör hellre en meshad boss som pilot om målet också är volym och sidovinkel.** Pixelregnet kräver inte voxelmodeller. Vid spelvyns storlek är det osäkert att den extra geometrin syns bättre än en välgjord skärveleffekt.

## 1. Vad som ritas i dag

- Varje fiende skapas som `Sprite3D`, får `hframes = 6`, `BILLBOARD_ENABLED`, närmaste texturfiltrering, ljussättning och alfaklippning. Texturen visas genom Sprite3D:s inbyggda material; override används inte, eftersom provet gav 73 färgade bildpixlar mot 22 641 med eget material (`game/main.gd:3975-3988`, `3989-3997`).
- Arket är sex rutor à 120×120. Animationstillstånden är vila in/ut, förvarning, hugg, träff och död (`game/main.gd:140-151`; sexruteformat och arkgeneratorhistorik: `PLAN.md:2149-2161`). Generatorfilerna finns inte i detta worktree; `PLAN.md:2149-2174` beskriver `tools/gen_enemy_sheet.py` och `gen_enemy_art.py`, men dagens versioner kunde inte läsas här.
- Vanlig fiende har `pixel_size = 0,012`; boss 0,013. Koden beskriver 96 synliga bildrader som 1,15 respektive 1,25 m; hela 120-rutans quad är 1,44/1,56 m hög (`game/main.gd:4046-4049`). Fötterna placeras 40 bildpixlar under quadens mitt (`game/main.gd:4059-4062`).
- Materialet är alltså motorns Sprite3D-material med ljus, `NEAREST`, billboard och alfaklippning. Extra mask-/röklager kan vara egna Sprite3D-barn, bara när fienden har sådana (`game/main.gd:4014-4042`, `game/main.gd:4280-4284`, `game/main.gd:4332-4340`).
- Spelrutan är 480×270 (`game/main.gd:42-47`; viewporten får `VY` i `game/main.gd:6448-6451`). Exakt aktuell skärmyta i pixlar och antal fiender som samtidigt syns i en bild kunde jag **inte** läsa ur en körning/skärmbild. `enemy_count_for` ger 1–`enemies_per_encounter` vanliga figurer per möte, boss 1 (`game/core/run.gd:383-388`); det är spawnat antal, inte garanti att alla ryms i kameran.
- En äldre uppmätning räknar 195,4 skärmpixlar per meter vid 1,15 m i en annan beskriven fiendevy (`docs/undersokning/hit-02-pixelkonst.md:29-40`). Multiplicerat med dagens bildhöjd 1,15 m blir cirka 225 px — **beräkning**, inte mätning av nuvarande skärmbild. Den motsäger tumregeln ~40 px hög i frågan, så avstånd/pose/versionsskillnad måste lösas före en säker pixeluppgift.

## 2. Vad voxlar/mesh faktiskt kostar

Arbetsinsatsen är huvudsakligen innehåll och animation, inte rå polygonräkning.

- **Modeller:** voxelasset per fiendetyp, export och import, pivoter/origin, mått som passar takhöjden 1,30 m, UV eller materialpalett, och en materialindelning. En Blender-proceduralmodell kan byggas headless i befintligt arbetsflöde enligt uppdragets PLAN.md-hänvisning, men något aktuellt genereringsrecept kunde inte beläggas i detta worktree. Modellerna blir också en ny visuell stil att hålla konsekvent.
- **Animation:** sex spriteposer blir rigg + clips eller sex poser/meshvarianter: idle loop, windup, attack, hit och death. Minst fyra semantiska övergångar måste kopplas till nuvarande tillståndsindex. Riggad kropp kräver viktning/ben; voxelstil kan i stället använda separata kroppsbitar eller poserade meshdelar. Det senare riskerar att se ut som att kroppen går sönder vid lederna. Detta är arbetsbedömning, inte repo-mätning.
- **Material:** palett/albedo, roughness/metallic, normals vid behov; ljus och skugga måste stämmas med rumsbelysning. Vill du behålla pixelkanterna måste texturer/atlas vara nearest och renderingen fortfarande lågupplöst. Bilboard-inställningen i ett standardmaterial skulle vända en mesh mot kameran och därmed upphäva poängen med sidovy; mesh-fienden ska normalt vara riktad och få verklig belysning. Standardmaterial har billboardlägen `[belagt: https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html]`.
- **Dragningar:** en vanlig MeshInstance3D med ett material = ungefär ett mesh-drag per fiende och per renderpass; 10–20 fiender innebär ungefär 10–20 mesh-dragningar per bildruta, alltså vid 60 fps cirka **600–1 200 per sekund**. Extra materialpass/skuggpass kan tillkomma. Detta är en uppskattning av submissions, inte uppmätt GPU-tid eller exakt Godot draw-call-räknare. Nuvarande sprites är också geometri och har i grunden ett drag per Sprite3D/pass; eventuell mask/rök ger separata lager.
- `MultiMesh` kan reducera många likadana meshinstanser till ett anrop, men fienderna använder olika mesh/material och olika animationstillstånd. Att gruppera kräver därför delning per art/pose/material och mer styrlogik. Godot beskriver MultiMesh som instansiering med ett draw call för många instanser, med gemensam näkyta/AABB `[belagt: https://docs.godotengine.org/en/4.1/classes/class_multimesh.html]`. Vid 10–20 fiender är detta inte den första flaskhalsen att lösa `[resonemang]`.

## 3. Billigare vägar, rangordnade efter effekt per insats

1. **Pixelregn vid träff.** Behåll bilder; spawn 6–12 små färgade fyrkantsquads ur fiendens palett. Tidigare undersökning föreslår GPUParticles3D, 2–4 spelpixlar, 0,55 s liv och pekar ut träffkroken (`docs/undersokning/hit-02-pixelkonst.md:3-8`, `57-82`, `116-118`). Det adresserar ordagrant att pixlar lossnar. Extra particle-draw räknades där som plan, inte profilerades (`docs/undersokning/hit-02-pixelkonst.md:120-126`).
2. **Lager/2,5D:** behåll huvudbilden och lägg en separat sidoprofil eller en smal andra bildplan på utvalda fiender. Ger djup/parallax vid liten vinkel, men läsbarheten beror på vinkel och överlapp `[resonemang]`. Billigare än 17 modeller och riggar.
3. **Meshad silhuett med sprite-albedo:** extrudera konturen lite eller använd ett par plana korsande meshplan, med befintlig bild som albedo. Ger sidkant/skugga och håller konsten, men en enkel extrudering visar plattans tjocklek, inte riktig anatomi `[resonemang]`.
4. **Normalmappad billboard:** bevarar nuvarande bild och animation; kan ge riktad ljusrelief, men silhuetten fortsätter vara platt. PLAN har redan en normalmätning: normal_scale 0→4 gav medelbildskillnad cirka 2,055–2,173 och p99 38–46; större styrka ökade medelskillnad bara till 2,735/3,006 (`PLAN.md:933-935`). Det är skillnad i pixelvärden, inte bevis på upplevd 3D-vinst.
5. **Full voxel endast bossar:** tydligare stilbrott per arbetstimme eftersom bossen syns som specialfall och det är få modeller. Behåll vanliga sprites. Det ger riktig sidovy för bossen, men behöver fortfarande poser/animationer och testas mot taket (`game/main.gd:4046-4049`; `PLAN.md:2210-2224`).

## 4. Vad Godot 4.8 hjälper med

Projektet står på Godot **4.8-dev7** (`game/project.godot:16` = `PackedStringArray("4.8")`, bytt 2026-10-11). 4.8-dev7 är en förhandsversion, så en 4.8-specifik funktion är fortfarande en versionsfråga, inte något som redan är i bruk. Den officiella 4.8-dev-5-posten är en utvecklingssnapshot `[belagt: https://godotengine.org/article/dev-snapshot-godot-4-8-dev-5/]`; jag hittar ingen 4.8-specifik förändring i de efterfrågade funktionerna att luta beslutet mot.

- **Meshinstanser/MultiMesh:** etablerad motorfunktion, även utan 4.8. Hjälper om många exemplar delar mesh/material; liten vinst för få unika fiender `[belagt: https://docs.godotengine.org/en/4.1/classes/class_multimesh.html]`.
- **LOD:** mesh-LOD kan minska geometri på avstånd, men med en fiende kring 40 px blir det få pixlar att spara. Automatisk mesh-LOD beskrivs i motordokumentationen; ingen mätning på detta projekt `[belagt: https://docs.godotengine.org/en/4.x/tutorials/3d/mesh_lod.html]`.
- **StandardMaterial3D billboard:** finns redan i Godot 4, ingen 4.8-vinst. Om materialet billboardas försvinner sidvinkelvinsten `[belagt: https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html]`.
- **Decals:** animerade decals skulle kunna markera träff/blod men är ytterligare en yta/renderpass och är inte samma sak som att geometriska pixlar lossnar. Det finns ingen användning för animerade decals belagd i repot här `[resonemang]`.
- **Webb/GL:** `game/project.godot:34` väljer `gl_compatibility` för webb. Compatibility är OpenGL-baserad; Forward+/Mobile använder RenderingDevice och stöds inte som webbväg enligt renderöversikten `[belagt: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html]`. Håll piloten till mesh, StandardMaterial3D, enkel textur och vanlig animation; undvik att göra den beroende av Forward+-specifika effekter `[resonemang]`.

## 5. En kvällspilot

Gör **en** voxel/low-poly boss i Blender med 3–4 palettmaterial, en idle-rörelse och tre poser/klipp: windup, attack, hit/death kan börja som två enkla clips/poseövergångar. Visa den bredvid samma bosses befintliga sprite i identiskt rum, avstånd, ljus, 480×270 och samma röda träffblink. Ingen ombyggnad av hela fiendesystemet. Människan ska kunna växla A/B och se stillbild, sidsteg/kameravinkel, idle, attack och pixelregn.

Mät: (1) faktisk silhuetthöjd/bredd i pixelbild, (2) antal pixlar som ändras mellan rakt fram och 30° sidovinkel, (3) frame time och draw calls vid 1, 10 och 20 kopior, (4) webbläsare/Compatibility fungerande, (5) om träffens pixelregn läses lika tydligt på sprite och mesh. Jämför bildfiler och mät med samma kamera. Renderprofilen blir **mätt** först efter den körningen; dragningstalen ovan är bara uppskattning.

## 6. Motargumentet

Om fienden verkligen är ungefär 40 px hög i spelvyn är 3D-formens små detaljer kvantiserade till få bildrutor. Mesh ger rimligen tydligast vinst i silhuett när kameran flyttar sig; i stilla förstapersonsvy med billboard som redan alltid vänder mot kameran kan den skillnaden vara obetydlig `[resonemang]`. Huvud, armar och voxelkanter kan dessutom bli ett par pixlar breda och flimra eller smälta ihop.

Repohistoriken varnar för att fixa fel sak: pixelkonstens träffförslag använder fyrkantiga 2–4-pixelsbitar, men dess egen rapport säger att exakt färgfördelning och ritanropskostnad inte mättes (`docs/undersokning/hit-02-pixelkonst.md:57-82`, `116-126`). Ljusriktning/relief är däremot synlig i repots mätningar: PLAN rapporterar skillnader vid normalmappning men också snabbt avtagande medelvinst vid högre styrka (`PLAN.md:933-935`); ljusundersökningen föreslår en billig billboard-quad i 480×270 och säger att den saknar ocklusion (`docs/undersokning/vol-05-ljus.md:241-256`). Det talar för en visuell A/B, inte ett generellt byte av alla fiender.

## Vad jag inte kunde belägga

- En aktuell körbild där fiendens pixelbbox kan mätas, eller hur många fiender som faktiskt syns samtidigt i kameran. Tidigare pixel/meter-provet ger ett svar som inte stämmer med ~40 px, sannolikt annan scen/pose/avstånd.
- Aktuella `game/tools/gen_enemy_sheet.py` och `game/tools/gen_enemy_art.py` finns inte i worktree; PLAN.md dokumenterar dem historiskt. Jag körde inte generatorer eller spel.
- Exakta draw calls/GPU-tid för 10–20 instanser, eller att en lågpoly/voxelboss är läsbar i webbexport. Angivna submissions är uppskattning, inte profileringsresultat.
- En särskild ny 4.8-funktion för voxlar/decals/LOD som ändrar slutsatsen; projektet står på 4.8-dev7 och webb-renderaren är Compatibility.

> **Rättat av Hermes efter leverans:** påståendet att projektet anger Godot 4.7 (`game/project.godot:16`)
> var fel — raden säger `PackedStringArray("4.8")` sedan motorn byttes 2026-10-11. Ett stavfel
> (`ändrasuu`) är rättat. Övrig text är agentens.
