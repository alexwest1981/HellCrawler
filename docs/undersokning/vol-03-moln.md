# Moln och takdimma: volymetriska moln i Godot 4 och vad som funkar inomhus

## Kort svar

För himmel och väder på avstånd passar ett `Sky`-material: det ritar en bakgrund och kan beskriva moln med shaderberäkningar, men det är inte en volym som kan ligga mellan spelaren och en vägg. [belagt: https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/sky_shader.html]

För en lokal bank dimma i en fängelsehåla är `FogVolume` den mest träffsäkra inbyggda funktionen: den adderar eller tar bort dimma i en form, använder miljöns volymetriska dimma och påverkas av ljus. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogvolume.html] [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html]

HellCrawler har redan global volymetrisk dimma, spelarlykta och fackelljus som visar sig i dimman. Därför är nästa rimliga prov en liten lokal `FogVolume`, inte ännu ett globalt molnsystem. [resonemang] Koden sätter `_vol`, densitet `0.014`, albedo `Color(0.55, 0.52, 0.58)`, anisotropi `0.35`, längd `26.0`, GI-injektion `0.6` och ambient-injektion `0.25` i `game/main.gd`; `_apply_tema()` skalar sedan densiteten efter nivåns `dimma`. [resonemang]

## Sky-material mot ett volymetriskt moln

Ett sky shader-material körs för synlig himmelsbakgrund och kan dessutom köras för att uppdatera radianskubkartan som används till omgivningsljus och reflektioner. Godot-dokumentationen visar halvupplösta och kvartsupplösta delpass för att beräkna exempelvis moln billigare än full upplösning. [belagt: https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/sky_shader.html]

Det passar moln som himmelsbild, horisont och fjärrväder. Det betyder inte att sky shadern gör en rökbank i rummet: resultatet är bakgrundsfärg, inte en lokal volym som skymmer geometri och tar emot ljus genom rummet. [resonemang]

En sampler-baserad volymetrisk molnshader på en mesh/box ger större frihet över en lokalt avgränsad volym: shadern kan provta en 3D-densitetskarta eller brusfält längs sikten genom lådan och komponera molnformen. Det är en egen raymarch-/volym-renderingsteknik och kräver att man hanterar transparens, provtagningssteg och ljusning själv; dokumentationen för Godots inbyggda `FogVolume` beskriver i stället froxelbaserad dimma och `FogMaterial`/fogshader. [resonemang] [belagt: https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html]

I HellCrawler är en boxshader mest motiverad för en tydligt stiliserad, konstnärligt formad molnklump som ska se ut som objekt. Den är mindre attraktiv som vanlig takdimma: specialshading kostar mer utveckling och kan ge mjukare/blurrare former än pixelbildens detaljnivå tål. Spelets spelvy renderas i `game/main.gd` till `VY := Vector2i(480, 270)` och skalas upp, medan CRT-shadern appliceras efteråt. Den låga källupplösningen gör en del skärmkostnader små, men gör inte tappade molndetaljer skarpare. [resonemang]

## FogVolume finns i Godot 4.7

Ja. Godot 4.7 har noden `FogVolume`; den ärver `VisualInstance3D` och bidrar till WorldEnvironmentens volymetriska dimma. Volymen kan också dra bort dimma med negativ `FogMaterial.density`. Den syns bara när `Environment.volumetric_fog_enabled` är på. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogvolume.html]

Formerna är `BOX`, `ELLIPSOID`, `CONE`, `CYLINDER` och `WORLD`. `WORLD` fungerar globalt; de övriga tar `size`/utbredning. Kon och cylinder passas in i angiven storlek, men icke-uniform storleksändring via `size` stöds inte för dem; skala noden om proportionerna ska ändras. Tunna volymer kan flimra när kameran rör sig. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogvolume.html] [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html]

`FogMaterial` har:

- `density`: mer positiv densitet ger tätare dimma; mycket hög densitet kan ge undersamplingsränder. Negativ densitet tar bort dimma. Värden mellan `-0.001` och `0.001` behandlas som noll för lokala material. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]
- `albedo`: volymens enkel-spridningsfärg, blandad med annan dimma. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]
- `emission`: färgar/lyser upp själva dimman men kastar inte ljus eller skuggor på andra ytor. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]
- `edge_fade`: högre värde mjukar volymens kanter; lägre ger hårdare kant. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]
- `height_falloff`: låter densiteten minska med höjden. Noll ger jämn densitet; högre värde ger skarpare höjdövergång. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]
- `density_texture`: valfri 3D-textur som skalar densiteten rumsligt. Den inbyggda teksturen är statisk; animerat brus kräver fogshader. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]

### Dimma vid golvet

Lägg en `FogVolume` i rummet med `shape = ELLIPSOID` eller `BOX`, stor nog att täcka en låg bank över golvet men inte hela rummet. Ge den `FogMaterial`, försiktig positiv `density`, dimfärgad `albedo`, märkbar `edge_fade` och positiv `height_falloff`; centrera höjdtröskeln nära golvnivån. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogvolume.html] [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html] Den exakta densiteten beror på rumsskala, projektets befintliga globala täthet och önskad pixelkontrast, så börja lågt och justera visuellt. [resonemang]

### Rökpuff i korridor

För en stillastående eller långsamt föränderlig puff: liten `ELLIPSOID`-volym, `FogMaterial` och låg/måttlig densitet med mjuka kanter. För en puff som rör sig eller måste tydligt expandera/krympa går det att animera volymens transform/storlek, men snabba förflyttningar kan ge temporal efterbildning i volymdimman. [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html] Om puffens inre ska bölja på ett särskilt sätt, använd 3D-densitetstextur för statiskt mönster eller fogshader för animation. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]

För en låga eller glödande rök kan `emission` ge färg inuti dimman, men den lyser inte upp golv eller väggar. Behövs belysta ytor ska en faktisk ljuskälla användas. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogmaterial.html]

## Dimma, ljus och kostnad

Godot kan använda global icke-volymetrisk dimma och volymetrisk dimma samtidigt. Den vanliga dimman påverkar scenen över avstånd; den volymetriska dimman sprider ljus och reagerar på ljus och ljusskuggor. Volymetrisk dimma finns endast i Forward+-renderaren. [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html]

HellCrawler har redan vanlig exponentiell dimma (`fog_density = 0.04`) utöver volymdimman. Det är rimligt: den vanliga dimman kan behålla djup/avståndston medan lokal volym ger synliga ljusstrålar. Men flera starka dimlager kan lyfta svärtan och sudda ut små pixelkontraster, så börja med att lägga till lokala volymer utan att samtidigt öka global densitet. [resonemang]

Ljus har egen `Volumetric Fog Energy`; ljusskuggor syns också i dimman när skuggor är aktiverade. Att exkludera ett ljus från dimberäkning genom att sätta dess volymenergi till noll ger en liten prestandavinst. [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html] HellCrawler sätter lyktans `light_volumetric_fog_energy = 1.0` i `_add_lykta()` och facklornas till `2.2` när de skapas. `_process()` fladdrar ljuset; det är alltså ljuskällor som lyser igenom den befintliga dimman. [resonemang]

Kostnaden beror på froxelbuffertens storlek och djup, ljusen som påverkar dimman, GI-injektion, samt FogVolume-skärmutbredning och materialkomplexitet. Fler/tätare pixlar kan ge mer detalj men maksar beräkningskostnaden; mindre volymdjup är billigare men kan ge rörelseartefakter. Filter jämnar ut grova kanter men suddar också detaljer. [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html] Godot anger uttryckligen att FogVolume-prestanda följer dess relativa storlek på skärmen och materialets komplexitet, så små och enkla volymer är rätt utgångspunkt. [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogvolume.html]

Låg renderupplösning gör en effekt som arbetar per skärmpixel potentiellt billigare än 1080p, eftersom 480×270 är 129 600 pixlar mot 2 073 600. Det är en stor skillnad i pixelantal, men inte en garanti för motsvarande GPU-vinst: froxelupplösning, ljus, transparens och efterbehandling har egna kostnader. [resonemang]

## FogVolume jämfört med partiklar

`FogVolume` beskriver sammanhängande dimma som fyller en region och integreras i volymdimman; ljuskäglor och skuggor kan därför uppträda genom densiteten. [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html] `GPUParticles3D` avger i stället ett valt antal separata partiklar med partikelmaterial och en eller flera draw-pass-meshar. [belagt: https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html]

Välj `FogVolume` för en låg dimbank, tunn rökhinna eller tät luftzon; välj partiklar för askflagor, gnistor eller tydligt avgränsade rökfläckar med egen rörelse. Partiklar kan ge synliga sprite-/meshformer snarare än optiskt sammanhängande luft. En kombination fungerar för rökpuff: lokal svag `FogVolume` för själva luften och få partiklar för fragment som driver iväg. [resonemang]

## Vad jag inte kunde belägga

Jag hittade ingen verifierbar aktuell prestandasiffra för FogVolume eller sampler-baserade moln på HellCrawlers målmaskin. Godots dokumentation beskriver kostnadsfaktorer, inte en universell budget. [resonemang]

Jag kunde inte bekräfta från projektfilerna vilken renderer projektet väljer i sin Godot-projektkonfiguration, eftersom den filen inte finns i den här worktreens rot. Volymdimman kan vara inställd i koden men kräver Forward+ för att renderas. [belagt: https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html] [resonemang]

## Vad jag skulle ändra i det här repot

1. `game/main.gd`, `_apply_tema()`: behåll den befintliga globala dimman som bas; prova en lokal `FogVolume` för en enda korridor eller ett rum innan de globala värdena (`0.014` basdensitet och temaberoende densitet) ändras. Jag skulle se en avgränsad, låg dimbank i rummet samtidigt som övriga siktlinjer och lyktans/facklornas ljuskäglor i stort sett behåller sitt nuvarande utseende. [resonemang]
2. Nivådata ligger i `game/data/stages/*.json` och nivåerna genereras av `tools/gen_stages.py`. Innan placering kodas bör befintligt JSON-format och generatorns nod-/objekttyper utökas med en valfri lokal dimvolym; jag verifierade inte något existerande dimvolymfält och anger därför inget påhittat fältnamn. [resonemang]
3. För ett första handbyggt prov: `FogVolume.shape = ELLIPSOID`, `size ≈ Vector3(8, 1.5, 4)`, `FogMaterial.density` försiktigt över noll, `edge_fade ≈ 0.5`, `height_falloff ≈ 1.0`. De är startvärden att jämföra i scenen, inte Godot-standardvärden eller uppmätta slutvärden. Jag skulle se en mjukt avtonad dimma nära golvet; om den flimrar skulle jag göra volymen tjockare och sänka densiteten. [resonemang] [belagt: https://docs.godotengine.org/en/4.7/classes/class_fogvolume.html]
