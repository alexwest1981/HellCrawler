# Fukt och vått: blöta golv, kondens och dimma vid marken

## Kort svar

Fukt blir läsbar när flera signaler pekar åt samma håll: mörkare sten, smala ljusreflexer, enstaka droppar och ett disskikt som bryter ljuskäglan nära marken. [resonemang] HellCrawler har redan en del av kedjan: ORM-kartor ger lokala blöta fläckar, golvvattnet får ett rörligt krusningsmaterial och droppar faller från utvalda tak- och väggplatser. [resonemang]

Den största möjliga kompletteringen är fukt som **nivådata**: banan skulle kunna välja markdimma, kondens-/droppintensitet och våthetsnivå utöver dagens tema och `dimma`. [resonemang] Det låter varje våning skilja sig från andra våningar i samma tema utan att göra all sten blank. [resonemang]

## Vad repot redan gör

`game/main.gd` bygger en `StandardMaterial3D` för golv och väggar i materialvägen runt `_add_boxes`: grundvärdena är `roughness = 1.0` och `metallic = 0.0`, ORM-kartans G-kanal kopplas till `roughness_texture` och B-kanalen till `metallic_texture`. [resonemang] `_yta_glans` mäter hur stor andel av råhetskartan som ligger i det blöta bandet (`GLANS_BLÖT = 0.40`) och slår på GGX-spegelkomponenten om andelen når `GLANS_BLÖT_ANDEL = 0.03`; matt yta får `SPECULAR_DISABLED`. [resonemang] Det är en bra grund för **fläckvis** våt sten: stenens höga råhet lämnas ifred medan markerade våta partier kan få högdagrar. [resonemang]

`metallic` är inte en fuktreglage. [belagt: https://docs.godotengine.org/en/4.2/tutorials/3d/standard_material_3d.html] Godots materialdokumentation beskriver metallic som materialets metalliska reflektionsmodell och roughness som hur suddig reflektionen blir; roughness 0 är spegel och 1 mycket utsmetad reflektion. [belagt: https://docs.godotengine.org/en/4.2/tutorials/3d/standard_material_3d.html] För sten som bara är våt bör metallic därför stanna nära noll och våtheten främst uttryckas genom råhetskartan, albedo och reflekterad ljuskälla. [resonemang]

Pölen har en separat väg i `game/core/fx.gd`: `pöl_material(mask, ruta)` bygger ett `ShaderMaterial`, använder en vattenmask med `discard`-form, ger krusning via normalstruktur och får tid uppdaterad genom `rulla(t)`. [resonemang] `_vatten_och_eld`, `_pölar` och `_vatten_ruta` i `game/main.gd` läser `assets/tiles/<tema>/_vatten.json`, lägger plattorna över ritade vattenfläckar och placerar droppställen. [resonemang] Dropparna skapas med `Fx.droppar`; `_droppställe` sätter dem vilande tills väntan löpt ut och `_droppa` startar en enstaka droppe i taget. [resonemang]

`game/ui/*.gdshader` är inte den vanliga världens golvmaterialgenerator. [resonemang] Den relevanta skuggningen av pölar ligger i `game/core/fx.gd`; `game/ui/crt.gdshader` är en skärmöverlagring och `fiende_material.gdshader` är ett maskstyrt lager på fiendekonst. [resonemang] I `game/main.gd` finns `Fx.pöl_material` och ORM-/`StandardMaterial3D`-vägen; rapportförslagen nedan utgår från dessa verifierade namn. [resonemang]

## Kondens, droppar och våt geometri

Droppar är redan en tydlig rörelsesignal, men spelkoden kopplar dem till slitna golv- och väggplatser och vattenmasker, inte till ett generellt kondensvärde för en nivå. [resonemang] En nivåparameter kan styra hur många möjliga droppställen används, väntetiden mellan dropparna eller sannolikheten att en fuktig vägg faktiskt droppar; en låg nivå ger enstaka ljud-/bildhändelser och en hög nivå bygger en aktiv läcka. [resonemang] Effekterna bör förbli sparsamma: vid 480×270 är en tydligt kontrasterad droppe som rör sig över några bildrutor lättare att uppfatta än många små partiklar. [resonemang]

Kondens kan också gestaltas utan genomskinliga glasrutor: mörka våta rinnspår på väggens ORM/albedo, glans på utvalda stenar och droppar vid enstaka fogar. [resonemang] För frostig eller pärlande kondens på en rekvisita kan en maskad shader fungera, men den ska skapa några stora, läsbara former i stället för högfrekvent brus. [resonemang] Små droppar, subtila normaler och reflektioner av miljön i ett mörkt rum riskerar att försvinna; den starkaste reflektionen som faktiskt finns att läsa är ofta spelarens lykta eller en fackla. [resonemang]

## Dimma vid marken och FogVolume

Global volymetrisk dimma är redan aktiverad i `game/main.gd`: `_vol`, densitet 0.014, albedo `Color(0.55, 0.52, 0.58)`, anisotropi 0.35, längd 26.0, GI-injektion 0.6 och ambient-injektion 0.25. [resonemang] `_apply_tema` sätter vanlig `env.fog_density` från temats `dimma` och skalar även `env.volumetric_fog_density` från samma temavärde. [resonemang] Lyktan och fackelljusen har egna bidrag till den volymetriska dimman: `_add_lykta` sätter `light_volumetric_fog_energy` till 1.0 och `_add_lagor` till 2.2. [resonemang]

Godot beskriver `FogVolume` som ett lokalt bidrag till global volymetrisk dimma; volymen syns bara när `Environment.volumetric_fog_enabled` är sant, och dess kostnad beror på skärmstorlek och materialkomplexitet. [belagt: https://docs.godotengine.org/en/latest/classes/class_fogvolume.html] Dokumentationen varnar också för att tunna volymer kan flimra när kameran rör sig och föreslår bland annat tjockare volym med lägre densitet. [belagt: https://docs.godotengine.org/en/latest/classes/class_fogvolume.html] Godots 4.7-funktionslista anger lokala FogVolume-former, däribland box, ellipsoid och cylinder. [belagt: https://docs.godotengine.org/en/4.7/about/list_of_features.html]

För knähög dimma är en låg, långlådaformad `FogVolume` per rum eller per dimmig zon den mest direkta prototypen; alternativet är höjddimma i `Environment`, som kan tona in dis under en viss höjd. [belagt: https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html] En enskild sammanhängande zon bör vara tillräckligt tjock för att undvika flimrande tunna skivor, och volymernas utbredning kan hämtas från rums-/golvgeometrin. [resonemang] Projektet bygger dock inte i nuläget lokala `FogVolume`-noder i den granskade världsbyggarkoden. [resonemang]

Godots dokumentation säger att volymetrisk dimma bara stöds i Forward+ och att detaljrikedomen kan bli sämre av filter som suddar dimman. [belagt: https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html] Samma dokumentation förklarar att volymetrisk dimma samverkar med ljus, vilket är den egenskap som kan göra en låg dimbank synlig runt lyktan och facklorna. [belagt: https://docs.godotengine.org/en/4.4/tutorials/3d/volumetric_fog.html] På en liten voxel-/froxelupplösning blir ett fåtal breda, ljusfångande disformer sannolikt tydligare än en tunn detaljrik markrulle. [resonemang]

## Speglingar och vad 480×270 faktiskt visar

En blöt yta ska ge en lokal ljusaccent, inte göra hela rummet blankt. [resonemang] Repots egna kommentarer i `game/main.gd` beskriver redan hur en bred spegling på alltför rå sten tvättade upp svärtan och fick pölen att drunkna; koden begränsar därför spegling till ytor där ORM-kartan har tillräcklig andel låga råhetsvärden. [resonemang] För en pöl passar maskad form, ett par ljusa fragment och långsam krusning bättre än en perfekt spegelbild i varje pixel. [resonemang]

Rendering i 480×270 betyder att 3D-effekter rasteriseras i en liten viewport innan bilden skalas upp; det sänker pixelarbetet jämfört med att rita hela 1080p-bilden, men geometriska och ljusrelaterade kostnader försvinner inte nödvändigtvis i samma takt. [resonemang] En kraftig blur kan vara billig men suddar också ut de få pixlar som bär tile-konstens struktur. [resonemang] `crt.gdshader` lägger efteråt på skanlinjer, vinjett, färgförskjutning och en hörnbegränsad buktning, så fin kontrast och små detaljer försvagas ytterligare av den slutliga bilden. [resonemang]

Sannolikt läsbart: en mörkare golvfläck med 2–5 pixlar av tydlig ljusreflex, en droppe med kontrasterande silhuett och en mjuk ljuspelare från lykta/fackla i dis. [resonemang] Sannolikt oläsbart eller dyrt för liten vinst: tunna vattenränder på enskilda texelpixlar, många små kondensdroppar, skarpa spegelbilder av hela rummet och tät låg dimma som täcker spelarens golvdetaljer. [resonemang]

## Fukt som nivåegenskap

Banformatet som skapas av `tools/gen_stages.py` innehåller bland annat `theme`, `floor_themes` och `regel`; dess `bygg()` skriver inte idag någon fuktprofil. [resonemang] `dimma` är för närvarande en temaljusegenskap i `TEMA_LJUS` i `game/main.gd`, inte ett fält i exempelvis `game/data/stages/stage_01.json`. [resonemang] Det innebär att första steget bör vara att bestämma var egenskapen hör hemma: om fukt varierar per bana, läggs den i stage-JSON och skapas av `tools/gen_stages.py`; om den varierar per våning, behöver även golvdata/importvägen bära värdet. [resonemang]

Ett litet startpaket kan vara `fukt` (0–1), `markdimma` (0–1) och `droppar` (0–1 eller en taktklass). [resonemang] `fukt` kan skala kontrast/våtandel på valda material och hur ofta vattenmasker får förekomma; `markdimma` kan styra densitet/höjd på den låga volymen; `droppar` kan styra urval och intervall för befintliga droppställen. [resonemang] Om pölar ska vara separat från generell stenfukt kan `vatten` beskriva pölmängd eller pölklass, men jag skulle undvika både `fukt` och `vatten` som överlappande nästan-synonymer utan en tydlig skillnad i spelet. [resonemang]

## Vad jag inte kunde belägga

- Jag kunde inte belägga en Godot-garanti för hur exakt `FogVolume` ser ut vid just HellCrawlers kamera, upplösning och rendererinställningar; det kräver en spelbild eller mätning i projektet. [resonemang]
- Jag kunde inte belägga att spelet kör Forward+ i alla sina startlägen/exporter; volymetrisk dimma är rendererberoende enligt Godots dokumentation. [belagt: https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html]
- Jag kunde inte belägga en befintlig `fukt`-, `markdimma`- eller `droppar`-egenskap i bandatat; förslagen är nya schemaidéer. [resonemang]
- Jag kunde inte belägga att en vald pixelstorlek för reflexen eller ett visst disvärde är visuellt optimalt utan skärmbildsprov. [resonemang]

## Vad jag skulle ändra i det här repot

1. **`tools/gen_stages.py`, `bygg()`**: lägg till ett fält `"fukt": 0.0` i varje genererad stage-dictionary; vid första inkrementet kan värdet sättas per bana/tema med några tydliga klasser. [resonemang] **Synlig skillnad:** befintliga banor förblir torra tills en bana får värde över noll; fuktiga banor får mer mörka, glansiga fläckar och tätare utvalda vattendrag. [resonemang]
2. **Stage-läsaren i `game/data/stages`-vägen och `game/main.gd`, `_apply_tema` / `_vatten_och_eld`**: verifiera först rätt laddad stage-definition i koden och skala `_apply_tema`-dimma samt urvalet i `_vatten_och_eld` efter `fukt`; behåll `GLANS_BLÖT` / `GLANS_BLÖT_ANDEL` som materialtrösklar tills bildprov visar behov av ändring. [resonemang] **Synlig skillnad:** samma grotta kan bli torr i en bana och droppande i en annan, utan att höja metallic på all sten. [resonemang]
3. **`game/main.gd`, ny lokal dis i världsbygget**: skapa en låg `FogVolume` med `FOG_VOLUME_SHAPE_BOX`, placera den bara i utrymmen där stage-värdets `markdimma` är aktivt och ge den stor horisontell utbredning men knähöjd. [belagt: https://docs.godotengine.org/en/latest/classes/class_fogvolume.html] **Synlig skillnad:** en mjuk ljusfångande dimbank skär över golvet och syns där lyktan/facklorna lyser, i stället för att hela rummets djup får samma dimtäthet. [resonemang]
4. **`game/core/fx.gd`, `dropp_väntan` / `_droppställe`-anropsparametrar (kontrollera aktuellt flöde vid implementation)**: låt stage-värdet för droppar skala väntan/urvalet, inte partikelstorleken först. [resonemang] **Synlig skillnad:** fuktiga banor får fler enstaka takdroppar med pauser; torra banor behåller långa tysta mellanrum. [resonemang]
5. **`tools/gen_tiles.py`, ORM-vattenmönstren**: behåll metallic för icke-metalliska golv nära noll och styr våtfläckens areal/råhetsband, eftersom den befintliga spelkoden redan letar efter låg råhet när den väljer spegling. [resonemang] **Synlig skillnad:** fler men avgränsade reflexfläckar på våta golv; stenmassan fortsätter läsa som matt sten. [resonemang]

Punkt 2 behöver anpassas till stage-läsarens verkliga returtyp och aktiva bana vid implementation; jag har inte påstått något nytt funktionsnamn för den läsaren. [resonemang]
