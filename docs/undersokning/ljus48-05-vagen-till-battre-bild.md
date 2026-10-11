# Vägen till bättre bild: vad betyder ”pixlarna lossnar”?

Utgångsläget är 480×270 för spelvyn, 1280×720 som fönster och NEAREST i en egen SubViewport; HUD:ens yttre lager ritas i fönstrets upplösning (`game/project.godot:20-27`, `game/main.gd:42-47,76-83,6448-6474`). De orden beskriver olika mål: skarpare kanter, större/tydligare pixlar, färre artefakter eller mer detalj. De bör jämföras med samma scen, kamera och rörelse.

## 1. Intern upplösning

- **Behåll 480×270:** bibehåller nuvarande pixelstorlek och konstnärlig komposition; låg rasterkostnad. Kan inte skapa mer texturdetalj. `[resonemang]`
- **Rendera 3D i 1,5× eller 2× och skala sedan till 480×270:** fler prov kan jämna kanter och tunna geometrier före nedkvantisering, men vanligt nedskalningsfilter kan också sudda ut pixlar och öka kostnaden per pixel cirka 2,25× respektive 4× för 3D-rasterdelen. Effekternas hela kostnad följer inte nödvändigtvis pixelantalet. `[resonemang]`
- **Rendera 2× och kvantisera ned:** behåll yttre 480×270-komposition, reducera bilden till spelpalett/upplösning i ett särskilt steg. Det kan bevara detalj i geometri/ljus och ändå ge blockig slutbild; kräver render-textur plus nedskalningspass. Mät mot ren 480 och kontrollera om tunna konturer blir stabilare, inte bara mjukare. `[resonemang]`
- **Släpp heltalsregeln:** större renderupplösning kan ge mindre, fler detaljerade bildpunkter. I dag är skalningen **exakt 2×** — mätt i den här kopian med `-- guiprov`: spelvyn ligger på 960×540 i (160, 90) i ett 1280×720-fönster, alltså 2×2 fönsterpixlar per källpixel. (Uppdragets 2,667× var fel; `_placera_vy()` tar `floorf(minf(...))`, `game/main.gd:6496-6503`.) 2×-upplösning (960×540) ger 1,333× i samma fönster, ännu mindre och ojämna block. 3× (1440×810) passar exakt 1920×1080 med 1,333×, men i 1280×720 måste den beskäras eller skalas ned till 0,889×; välj alltså upplösning efter målskärmen. `[resonemang]`

**”Pixlarna lossnar”** kan betyda att blocken inte längre håller samma skärmstorlek, så formerna ser finare ut och rörliga kanter får subpixelvariation. Det kan också betyda att dither, scanlines och kromatisk förskjutning inte längre ligger i fas med källpixlarna. Jämför stillbild och panorering; räkna unika pixelbredder i kanter och se efter flimmer. `[resonemang]`

## 2. Uppskalningsfilter och HUD

- **NEAREST vid nuvarande 2×:** hårda pixlar i exakt 2×2-block; skalningen är heltal och räknas om per fönsterstorlek (`game/main.gd:6496-6503`), och korgen använder uttryckligen NEAREST (`game/main.gd:6466-6474`).
- **Uppskalning i praktiken:** spelvyn är redan heltalsskalad och centrerad, med 160 px marginal i sidled och 90 px på höjden. Att rita vyn mindre (1:1 eller 1⅓×) gör pixlarna mindre, inte jämnare — jämnheten är redan 2×2.
- **Interpolering/linjär:** jämnare storleksövergång och mindre trappsteg, men mjukare konturer och blandade färger. Prova för en mer målad bild; det tar inte bort källtexturens gråhet. `[resonemang]`
- **HUD:** text och UI inuti spelvyn följer dess 480×270 och skalas; HUD runtom ritas i fönsterupplösning och förblir skarp (`game/main.gd:76-80`, `game/project.godot:24-27`). Att höja enbart 3D-upplösningen lämnar den gamla HUD:en intakt; att höja hela SubViewporten ändrar också textens storlek/skärpa och kräver layoutprov. Mät liten text i skärmbild i faktisk visningsstorlek. `[resonemang]`

## 3. Palett- och Bayer 4×4-pass

Ett helbildspass kan kvantisera färger till en mindre palett och använda 4×4 Bayer-trösklar för att fördela fel mellan grannar. Resultatet blir avsiktlig konsoldither; det **lägger till** kornigt mönster men gör slumpmässigt gryn mindre synligt om färgkvantiseringen ersätter subtila nyanser. I mörk korridor kan dither bli ett rutnät över svag ljusgradient och försvaga läsbarheten; prova separat luma-/färgkvantisering och lägre ditherstyrka i skuggor. `[resonemang]`

Det finns redan en skärmläsande `canvas_item`-shader att bygga på (`game/ui/crt.gdshader:20-32,42-69`), men ingen Bayer- eller palettkod hittades under `game/` (sökning i repot). Palettelement finns i UI-paletten, men det belägger inte att den passar 3D-bilden (`game/ui/palett.gd:1-14`). En egen pass kostar shaderkod och ett A/B-prov; fps går inte att ange utan mätning. Samma fasta Bayer-mönster kan ge synligt stillastående rutnät; följ toningar och panorering. `[resonemang]`

## 4. Kantutjämning

- **MSAA i 3D-vyn:** jämnar geometriska polygonkanter, inte texturens interna pixlar; vid 480×270 är grundytan liten, men fler samples ökar render-/minnesarbete. För pixelkonst kan det göra avsiktliga hårda kanter mjuka, särskilt efter ytterligare uppskalning. Börja med 2×/4× A/B. `[belagt: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html]` `[resonemang]`
- **FXAA/CMAA:** helbildsdetektering av kanter kan jämna texturpixlar och UI om den körs efter kompositionen; den kan ge mjuka detaljer. Om den bara körs i 3D-passet hålls HUD:en utanför. Projektets webb-renderare är GL Compatibility (`game/project.godot:34`); Godots rendereröversikt anger 3D-MSAA i Compatibility, men postprocessingens stöd och den exakta kombinationen måste kontrolleras i den använda Godot-versionen och i webbbygget. `[belagt: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html]` `[resonemang]`
- **Inget alls:** behåller bildens hårda pixelkanter och är en rimlig baslinje för pixelkonst. Jämför med en stilla diagonal, fiendesilhuett och en panorering. Kontrollera både desktop och webb, eftersom projektets webb-renderare är GL Compatibility och saknar projektets Forward+-effekter (bland annat SSR/SSAO/SSIL; `game/main.gd:692-725`). `[resonemang]`

## 5. CRT och grynigheten

CRT-lagret är sannolikt en direkt del av upplevelsen ”grynig”: det mörkar varannan **fönsterrad**, vinjetterar hörnen, förskjuter rött/blått och buktar hörnen (`game/ui/crt.gdshader:17-19,34-40,54-68`). `crt=0` stänger av det för jämförelse, och `crt=N` skalar styrkan (`game/main.gd:649-655`). Shaderkommentarerna mäter att `filter_linear`→`filter_nearest` gav **0 av 1 952 880** olika pixlar, så filterbyte gör inte bilden renare (`game/ui/crt.gdshader:26-31`). En annan kommentar säger att skärmbilden var läsbar men nära för mörk: vinjetten sänktes från 0,85 till 0,60 eftersom statusraden och hörnen tappade kontrast (`game/ui/crt.gdshader:36-38`).

**Alternativ:** behåll full effekt för den gamla tjock-TV-känslan; mildra `crt=0.5` för mindre rad-/färgbrus; eller `crt=0` för ren baslinje. Alex ville enligt shaderkommentaren behålla buktningen eftersom den gav CRT-känsla, men hindra den från att bukta ”hej vilt när man vänder sig”; nu är buktningen koncentrerad till hörnen och mitten är nästan platt (`game/ui/crt.gdshader:4-15`). Testa scanline/kroma/vinjett var för sig om styrkeflaggan inte isolerar vad som stör. `[resonemang]`

## 6. Det som inte är en renderinställning

Texturernas målade gråskala och detalj ligger i källkonsten; ett filter kan interpolera, kvantisera eller färga om den, men inte återställa information som inte finns. Ljuset kan förstärka relief och separation, medan AgX rullar av högdagrar och glow lägger bloom (`game/main.gd:737-761`). För starkt omgivningsljus/SSIL kan lyfta mörkret till en grå hinna; kommentarerna varnar uttryckligen för det (`game/main.gd:688-699,718-725`). Renderpass kan ändra hur materialet läses, men om vägg, golv och tak har för lika målade värden behöver konsten skilja dem åt. Repots egen mätning fann liknande brunton på ytorna och ändrade tak-/golvton i materialbelysningen (`game/main.gd:360-389`). Det är konstbeslutet: materialvärden, palett, texturkontrast och ljusriktning. `[resonemang]`

## 7. Förslag på ordning och mätning

1. **Först isolera CRT:** samma `-- shot`-läge/scen, jämför `crt=1`, `crt=0.5`, `crt=0`. Mät bildens luminanskontrast och färgskillnad runt små kanter; låt Alex bedöma läsbarhet i korridor samt om tjock-TV-känslan finns kvar. Skärmprovets shot-funktion finns i `game/main.gd:777-830,890-895`.
2. **Prova uppskalning:** jämför NEAREST mot heltalspassning med samma utsnitt. Mät kantpixlarnas bredd (fördelning 2 eller 3 fönsterpixlar), småtextens läsbarhet och flimmer i rörelse. Behåll HUD utanför 3D-testet (`game/main.gd:76-80`).
3. **Prova högre 3D-upplösning och nedkvantisering:** 480-bas mot 1,5×/2× render → 480. Mät GPU-tid/fps och kanters stabilitet; fast scen och kamera krävs för att skilja förbättring från ljusvariation. Sedan kan Bayer-pass jämföras med identisk palett och ljus.
4. **AA sist:** MSAA 2×/4×/av i en vy med diagonaler och pixeltexturer. Mät GPU-tid och jämför om kanterna blivit renare utan att rutornas textur suddas. FXAA/CMAA kräver samma desktop/webbkontroll.

`-- normalprov` mäter främst normalmap/ytljus och har rapportvärden i kommentaren (`game/main.gd:375-389`, `game/main.gd:966-1106`); `-- glansprov` jämför glans och ytmaterial (`game/main.gd:397-408`, `game/main.gd:1585-1674`). De är användbara för att skilja materialljus från efterbehandling men testar inte i sig upplösning, AA eller palettpass. `tools/test_all.sh` är inte bildmätare, och ska inte köras här eftersom källbilderna saknas i denna worktree (uppdragsunderlag). `[resonemang]`

## Vad jag inte kunde belägga

- Ingen bildkörning gjordes; den här worktreen saknar ignorerade källbilder (`game/images/*`) enligt uppdragsunderlaget. Därför finns ingen egen före/efter-bild eller fpssiffra.
- Jag kunde inte belägga vilken mening Alex lägger i ”pixlarna lossnar” utöver möjliga visuella tolkningar ovan; det behöver knytas till om han menar storlek, jämnhet eller rörelseflimmer.
- Exakt MSAA-/FXAA-/CMAA-stöd och fps i den aktuella Godot-versionen och webbexporten är inte provkört. Godots aktuella översikt anger MSAA för Compatibility, men resultatet behöver verifieras i projektets exporterade build. `[belagt: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html]`

> **Rättat av Hermes efter leverans:** de två finska meningarna i avsnitt 4 är översatta, och
> felpremissen 2,667× (som kom från uppdraget, inte från agenten) är ersatt med den uppmätta
> 2×-skalningen. Övrig text är agentens.
