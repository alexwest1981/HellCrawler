# 10 — Antirepetition: rutmönster, dekal-lager, makro-variation och avgrundsdjup

Utgångsläge: rutnät på 1 m, 32×32 px-rutbilder, 5 rutor per tema (wall, wall_moss, floor, floor_crack, ceiling), 5 teman, golv/vägg som MultiMesh, sliten variant på var 6:e/var 8:e ruta enligt hash.

## 1. Rutbildsvariation — antal varianter och urvalsmetod

Det finns **ingen publicerad kanonisk siffra** för antalet varianter per material — se UNVERIFIED-listan. Urvalsmetoderna är däremot väldokumenterade, och de avgör om det läser som rutnät:

- **Hash per ruta + slumpad offset/orientering.** Inigo Quilez teknik 1: bestäm vilken ruta samplet ligger i, generera fyra pseudo-slumptal för rutan och använd dem för att offsetta/spegelvända rutbilden. Källan namnger själv problemen: sömmar vid rutgränserna, och derivator som hoppar så mipmapping går sönder. https://iquilezles.org/articles/texturerepetition
- **Flera rutbilder, blendade, maskade av ett index.** Quilez teknik 3 använder fyra parallella rutbilder med `smoothstep`-blandning över rutor och visar "Variation 2", "Variation 4", "Variation 6" som separata masklager — dvs. 4–6 variationer i ett material för två texture fetches. Samma URL.
- **Texture bombing** (GPU Gems kap. 20): dela UV-rymden i celler och placera en bild på slumpad plats i varje cell; fler bilder per cell ger mer variation, och man väljer bland fyra sub-bilder via ett index ur en slump-textur. https://developer.nvidia.com/gpugems/gpugems/part-iii-materials/chapter-20-texture-bombing
- **Wang tiles** (Cohen m.fl. 2003): icke-periodisk plattsättning ur en liten uppsättning kantmatchande brickor. https://dl.acm.org/doi/abs/10.1145/882262.882265
- **Poisson-disk / blue noise** (Bridson, SIGGRAPH 2007): O(N)-generering av sampel med minsta avstånd r, framtagen just för att undvika den klustring som jämn slumptal ger — används för att sprida props/dekaler. https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
- **Grimrocks faktiska metod.** I `defineTile` är `wall`, `floor` och `ceiling` **tabeller av objektnamn med relativa sannolikheter**, som används för att slumpmässigt plocka pjäser när levels genereras — antalet varianter är alltså inte en konstant utan en viktad lista. Dessutom finns `ceilingEdgeVariations`: 16 varianter för alla kombinationer av angränsande rutor (bitmask), dvs. autotiling/blob. https://www.grimrock.net/modding/scripting-reference/

**Slutsats för vår baseline:** felet är inte att 5 rutor är "för få" — det är att slit-varianten fördelas av en lågfrekvent hash på 1 m-skalan. Det är precis Quilez teknik 1, och precis det han varnar för: hashen tar bort *periodiciteten* men lämnar *rutnätets skala*, och ögat läser mönstret. Källans botemedel är att blenda mot grannrutorna nära kanten. Grimrock läser dessutom mindre rutmässigt för att deras grid är 3×3 m med 1024×1024 px per 3×3 m — nio gånger vår yta per upprepning. https://www.gamebanshee.com/news/114315-the-making-of-legend-of-grimrock-ii-s-levels.html

## 2. Dekaler och överlager

Godots Decal-nod projicerar en textur i realtid på ogenomskinliga/genomskinliga ytor, utan mesh-generering, och kan flyttas varje frame med liten prestandapåverkan. Dokumentationen säger uttryckligen att dekaler hjälper till att "break up texture repetition" och få mönster att se naturligare ut, och lyfter organiska detaljer som jordfläckar. https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html

- **Kostnadsmodellen.** Dekal-rendering bestäms mest av skärmtäckning och antal; få stora dekaler är dyrare än många små. Dokumentationens åtgärder: håll `Extents.y` (projektionslängden) kort för bättre culling, och slå på Distance Fade (LOD; dekalen klipps bort efter Begin+Length). Samma URL.
- **Renderar-stöd.** Dekaler stöds inte i Compatibility-renderaren; där rekommenderar dokumentationen Sprite3D för (mestadels) platta ytor. Samma URL.
- **Pixelart.** Sätt projektinställningen `Rendering > Textures > Decals > Filter` till ett Nearest-läge, annars blir dekalerna grumliga. Samma URL.
- **Billigare än dekal-noder i vårt fall:** MultiMesh är en enda draw-primitiv, och shadern kan läsa `INSTANCE_ID`/`INSTANCE_CUSTOM` för per-instans-variation. https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html Vill man välja ruta per instans via en textur-array går det, men Godot kan inte visa en Texture2DArray med de inbyggda shaderarna — man måste skriva egen shader. https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_images.html
- Triplanar/projektion utan UV finns inbyggt i StandardMaterial3D, och Quilez har en billigare två-fetch-variant ("biplanar"). https://www.patreon.com/inigoquilez/posts/biplanar-texture-44186600

**Omdöme (min inferens, inte ett dokumentationspåstående):** billigast i Godot 4 är att lägga variationen i det MultiMesh vi redan har — per-instans custom data → shader — och använda Decal-noder sparsamt för handplacerade hotspots, eftersom varje dekal är ett eget projicerat pass som skalar med skärmtäckning.

## 3. Makro-variation — bryta upp 1 m-rutnätet

- **Landmarks / "weenies".** Begreppet kommer från Walt Disney och avser det som drar blicken och får besökaren att röra sig mot ett mål; Scott Rogers GDC-föredrag "Everything I Learned About Level Design I Learned from Disneyland" förde in det i level design. https://gdcvault.com/play/1305/Everything-I-Learned-About-Level och https://www.gamedeveloper.com/design/video-everything-i-learned-about-level-design-i-learned-from-disneyland En konkret taxonomi finns för Ghost of Tsushima, inklusive "Short Flag"-weenies som bara syns på kort avstånd. https://www.gamedeveloper.com/design/a-taxonomy-of-weenies-the-landmarks-that-define-i-ghost-of-tsushima-i-
- **Art-ledd procgen, inte algoritm-ledd.** Red Hook byggde Darkest Dungeon 2:s procgen-system med konstnären som drivande part; ett "tile balancing"-verktyg var avgörande för hur biomer såg ut och förblev läsbara. https://schedule.gdconf.com/session/evolving-worlds-from-the-crumbling-chaos-the-art-led-approach-of-darkest-dungeon-2s-procedural-generation-system/906953 och https://gdcvault.com/play/1035493/Evolving-Worlds-from-the-Crumbling
- **Höjd och vertikalitet.** Legend of Grimrock II lade till "multi-height levels" utöver ettan. https://en.wikipedia.org/wiki/Legend_of_Grimrock_II I Grimrocks scripting reference motsvaras det av `PlatformComponent`, `HeightmapComponent`, `PitComponent` och `ceilingShaft` (objekt som spawnas automatiskt om det finns en grop ovanför) — vertikalitet är byggd som komponenter, inte som större texturer. https://www.grimrock.net/modding/scripting-reference/
- **Informationsmängd.** Dan Taylors tio principer för level design (GDC 2013) handlar om att spelaren ska kunna navigera utan för mycket eller för lite information. https://www.gamedeveloper.com/design/video-the-ten-principles-for-better-level-design
- **Byt tema per stratum, inte per våning.** Etrian Odyssey ger varje stratum egen visuell identitet men återanvänder backdrops över fem våningar — vilket spelare klagat på: "5 floors with the same backdrops and design is getting dull". https://gamefaqs.gamespot.com/boards/893659-etrian-odyssey-v-beyond-the-myth/75973471

## 4. Avgrund/djup utan botten

- **Ingen bottengeometri — botten är en kill plane.** Minecrafts "void" är utrymmet utanför det byggbara området: entiteter faller oändligt i Java Edition och tar ~4 skada var 0,5 s under Y=−128; i Bedrock finns en osynlig barriär på Y=−105. Djupet säljs med "void fog" som ökar från Y=17 tills bara några block syns, mörkgrå partiklar från nivå 16 och nedåt, och debug-raden "Outside of world..." under Y=0. https://minecraft.wiki/w/Void
- **Godot-dimma för samma sak.** Environment har `fog_enabled` med `fog_mode = FOG_MODE_DEPTH` och `fog_depth_begin` (default 10.0), `fog_depth_end` (100) och `fog_depth_curve`. https://docs.godotengine.org/en/latest/classes/class_environment.html Volumetrisk dimma har ändligt räckvidd, och dokumentationen säger: "If you wish to hide distant areas from the player, it's recommended to enable both non-volumetric fog and volumetric fog at the same time". Volumetrisk dimma stöds bara i Forward+ och kan lokaliseras med FogVolume (shape, density, height falloff). https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html
- **Man ska kunna falla ned men inte gå ut.** Eye of the Beholder II: gropen i Catacombs nivå 1 släpper ned partyt i en liten cell under, och enda vägen ut är att kasta ett föremål genom dörrens galler så det träffar knappen på andra sidan. https://gamerwalkthroughs.com/eye-of-the-beholder-2/catacomb-level-1/ och https://www.gamebanshee.com/eyeofthebeholderii/walkthrough/catacombs-1.php
- **Osynliga/ytterst subtila kanter.** I Dungeon Master är groparna uppenbara, men en rad längre ned är osynliga utom en svag kontur, och man kan locka monster över en grop och öppna den under dem. https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/DungeonMaster och https://the-spoiler.com/RPG/FTL/dungeon.master.1.html
- **Staplade gropar och chasm-tile.** Grimrock hade buggen "falling into double pits (two pits on top of each other) does not work", dvs. flera våningar djupa hål. https://www.gamebanshee.com/news/106317-legend-of-grimrock-development-update-v15-106317.html Motorn har dessutom automap-tilen "chasm" och spawnar `ceilingShaft` när det finns en grop ovanför. https://www.grimrock.net/modding/scripting-reference/
- **Kameran och ljudet gör fallet.** Enligt Grimrocks officiella forum ger en grop automatiskt tiltad kamera och fall-ljud; enbart en elevation-drop gör det inte, och motorn skriver "ignoring teleportation -- party falling to level below" om man försöker teleportera under ett fall. https://www.grimrock.net/forum/viewtopic.php?t=14681
- **Parallax-lager.** I en 2D-komponerad crawler (Bard's Tale/EO-stil) ger Godots Parallax2D lager som rör sig olika snabbt mot kameran och därmed illusorisk skärpedjup. https://docs.godotengine.org/en/stable/classes/class_parallax2d.html Motsvarigheten i en riktig 3D-crawler (fjärrgeometri i olika skala + dimma) saknar primärkälla — UNVERIFIED.

## 5. Trötthet — vad är faktiskt belagt?

- **"Environment fatigue" som etablerad term med toleranstid finns inte belagt.** Jag hittar ingen akademisk källa som mäter hur länge en spelare tolererar ett tema i en dungeon crawler. UNVERIFIED.
- **"Visual fatigue" förekommer och mäts indirekt.** En masteruppsats valde medvetet en nivå som återbesöks för att den "raises the likelihood of players experiencing visual fatigue over time"; testare i den statiska versionen "were fatigued by the environment slightly more" och spelade färre omgångar, medan den randomiserade versionen uppmuntrade fortsatt utforskning. Notera nyansen: layoutrandomisering hade effekt, loot-placering hade försumbar effekt. https://theseus.fi/handle/10024/892471
- **Variation ≠ upplevd variation.** Kate Comptons "10,000 bowls of oatmeal"-problem: allt innehåll kan vara matematiskt unikt utan att upplevas som unikt. https://www.galaxykate.com/zines/EncyclopediaOfGenerativity-KateCompton.pdf Det formaliseras i "Why Oatmeal is Cheap: Kolmogorov Complexity and Procedural Generation". https://arxiv.org/pdf/2305.02131 En CHI-studie jämför dessutom upplevd procedurgenererad mot mänskligt designad nivå. https://arxiv.org/html/2602.14254v1
- **Vad som anses vara nyckeln: form och fokuspunkt, inte fler texturer.** Weenie/landmark-traditionen (GDC Disneyland) och Darkest Dungeon 2:s art-ledda tile-balansering pekar båda på form, siluett och fokalpunkt snarare än fler material. https://gdcvault.com/play/1305/Everything-I-Learned-About-Level och https://gdcvault.com/play/1035493/Evolving-Worlds-from-the-Crumbling Att just ljus/färg är den avgörande faktorn är inte belagt i någon källa jag hittat — UNVERIFIED.

## Källor

1. https://iquilezles.org/articles/texturerepetition — Inigo Quilez, textur-repetition (hash per tile, teknik 1–3)
2. https://developer.nvidia.com/gpugems/gpugems/part-iii-materials/chapter-20-texture-bombing — GPU Gems kap. 20, Texture Bombing
3. https://dl.acm.org/doi/abs/10.1145/882262.882265 — Cohen m.fl., Wang Tiles for Image and Texture Generation (2003)
4. https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf — Bridson, Fast Poisson Disk Sampling (SIGGRAPH 2007)
5. https://www.grimrock.net/modding/scripting-reference/ — Legend of Grimrock, officiell scripting reference (`defineTile`, chasm, ceilingShaft, ceilingEdgeVariations)
6. https://www.gamebanshee.com/news/114315-the-making-of-legend-of-grimrock-ii-s-levels.html — Återpublicerat Grimrock-devblogg-inlägg (texel-upplösning 1024² per 3×3 m)
7. https://www.gamebanshee.com/news/104715-legend-of-grimrock-building-the-dungeon.html — Återpublicerat "Building the dungeon" (primär: http://www.grimrock.net/2011/09/08/building-the-dungeon/)
8. https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html — Godot 4 "Using decals"
9. https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html — Godot 4 "Optimization using MultiMeshes"
10. https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_images.html — Godot importtyper (Texture2DArray)
11. https://www.patreon.com/inigoquilez/posts/biplanar-texture-44186600 — Quilez, biplanar texture mapping
12. https://gdcvault.com/play/1305/Everything-I-Learned-About-Level — Scott Rogers, GDC, Disneyland/weenies
13. https://www.gamedeveloper.com/design/video-everything-i-learned-about-level-design-i-learned-from-disneyland — sammanfattning av samma GDC-tal
14. https://www.gamedeveloper.com/design/a-taxonomy-of-weenies-the-landmarks-that-define-i-ghost-of-tsushima-i- — weenie-taxonomi
15. https://schedule.gdconf.com/session/evolving-worlds-from-the-crumbling-chaos-the-art-led-approach-of-darkest-dungeon-2s-procedural-generation-system/906953 — GDC 2025, DD2 art-ledd procgen
16. https://gdcvault.com/play/1035493/Evolving-Worlds-from-the-Crumbling — GDC Vault, samma tal
17. https://en.wikipedia.org/wiki/Legend_of_Grimrock_II — Grimrock II: multi-height levels
18. https://www.gamedeveloper.com/design/video-the-ten-principles-for-better-level-design — Dan Taylor, GDC 2013
19. https://gamefaqs.gamespot.com/boards/893659-etrian-odyssey-v-beyond-the-myth/75973471 — EO V, klagomål på återanvända backdrops
20. https://minecraft.wiki/w/Void — Minecrafts void, void fog, void-partiklar
21. https://docs.godotengine.org/en/latest/classes/class_environment.html — Godot Environment (fog_mode, fog_depth_*)
22. https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html — Godot volumetrisk dimma och FogVolume
23. https://gamerwalkthroughs.com/eye-of-the-beholder-2/catacomb-level-1/ — EOB2, grop → cell
24. https://www.gamebanshee.com/eyeofthebeholderii/walkthrough/catacombs-1.php — EOB2, grop-ambush (#12), kasta sten genom gallret
25. https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/DungeonMaster — Dungeon Master, osynliga gropar
26. https://the-spoiler.com/RPG/FTL/dungeon.master.1.html — Dungeon Master, "Invisible Pits ... only faintly outlined"
27. https://www.gamebanshee.com/news/106317-legend-of-grimrock-development-update-v15-106317.html — Grimrock-devuppdatering (staplade gropar, distance fog)
28. https://www.grimrock.net/forum/viewtopic.php?t=14681 — Grimrocks officiella forum (grop → tiltad kamera + fall-ljud)
29. https://docs.godotengine.org/en/stable/classes/class_parallax2d.html — Godot Parallax2D
30. https://theseus.fi/handle/10024/892471 — Randomizing Linear Levels (visual fatigue i återbesökt nivå)
31. https://www.galaxykate.com/zines/EncyclopediaOfGenerativity-KateCompton.pdf — Kate Compton, Encyclopedia of Generativity
32. https://arxiv.org/pdf/2305.02131 — Why Oatmeal is Cheap: Kolmogorov Complexity and Procedural Generation
33. https://arxiv.org/html/2602.14254v1 — Playing the Imitation Game: How Perceived Generated Content Shapes Player Experience (CHI)
