# Belysning, grynighet och fienderna — vad undersökningen kom fram till

Fem research-agenter (Orca, codex) körde 2026-10-11, en fråga var, i var sin worktree från `97377a2`.
Rapporterna ligger som `ljus48-01` … `ljus48-05` i den här mappen. Det här är sammanfattningen, plus
**mina egna mätningar** — för agenterna kunde inte köra spelet (worktreen saknar gitignorerat
källmaterial) och flera av deras förslag byggde på en siffra jag hade gett dem fel.

## Först: en felpremiss som jag själv skickade ut

Jag skrev i två uppdrag att spelvyn skalas **2,667×** (480×270 → 1280×720). Det är fel. Mätt med spelets
eget prov (`-- guiprov`) i den här kopian:

```
guiprov: fönstret 1280x720, spelvyn [P: (160.0, 90.0), S: (960.0, 540.0)] (skala x2)
```

Skalan är `floorf(minf(...))` (`game/main.gd:6496-6503`), alltså **exakt 2×**, spelvyn 960×540 centrerad
med 160 px marginal i sidled och 90 px på höjden, och HUD:en runt om ritas i fönstrets upplösning.
Pixlarna är 2×2 fönsterpixlar — inte ojämna 2/3-block. Agenten på grynigheten (02) hittade felet själv
och skrev emot uppdraget; rapport 05 byggde vidare på det och är rättad i efterhand (noten står i filen).

## Mätt: vad bilden faktiskt är gjord av

Alla siffror är från Forward+ (Vulkan) i Xvfb `:99`, `--audio-driver Dummy`, samma scen och kamera.
`vy-medel` är spelvyns medelljushet 0–255. `HF` är medelvärdet av `|grannskillnad|` i spelvyn, alltså
högfrekvent innehåll (det ögat läser som gryn/skimmer).

| Körning | HF hela | HF nära | vy-medel | jämn−udda rad |
|---|---|---|---|---|
| `shot` (allt på, som spelet körs) | 4,63 | 6,19 | **12,94** | **+2,64** |
| `shot crt=0` | 6,85 | 9,84 | 21,08 | +0,24 |
| `shot ssr=0 ao=0 ssil=0 vol=0` | 5,14 | 6,84 | 13,63 | +2,64 |
| `shot skala ×2 (mipmaps av)` = baslinjen igen | 4,63 | 6,19 | 12,94 | +2,64 |
| alla 863 texturer med mipmaps + `NEAREST_WITH_MIPMAPS` | 4,84 | 6,77 | 13,44 | +2,76 |

`shot` två gånger gav 4,633 och 4,632 — instrumentet är deterministiskt, så skillnader under ~1 % är
brus och allt över är verkligt.

**Vad siffrorna säger:**

1. **Bilden är väldigt mörk: medelljushet 12,94 av 255 (5 %).** Det är den enskilt viktigaste raden.
   I ett så mörkt fönster blir varje litet påslag synligt, och 8-bitarskvantiseringen ligger nära
   ett steg per nyans.
2. **CRT-lagret är regelbunden struktur, inte slumpbrus — men det är hälften av upplevelsen.**
   Det mörkar varannan fönsterrad med **+2,64 av 255** (mätt som jämna mot udda raders medelljushet),
   och det sänker hela vyns ljushet från 21,08 till 12,94 medan det *tar bort* 25 % högfrekvent innehåll.
   Räkna på det: skanlinje-svängningen är **20 % av bildens egen medelljushet**. I en ljus bild vore
   samma skanlinjer nästan ingenting. `crt=0` finns som flagga, och spelaren kan stänga av CRT i
   alternativen (`game/core/meta.gd:71,135`) — men Alex ville ha CRT-känslan, så frågan är styrka, inte av/på.
3. **Normalmappen betalar relief med ljuset.** Repots eget prov (`-- normalprov`, samma kamera, brusgolv
   i samma körning) mätt av mig: `normal_scale` 0 → vy-medel 35,73 · 1 → 17,83 · 8 → 12,65, medan HF
   bara går 6,41 → 6,76 → 4,46. Reliefen vid 1,0 kostar alltså **halva ljuset** för +5 % högfrekvent
   innehåll, och vid 8 är bilden så mörk att den krossas. Repot har redan mätt att ratten är slut
   (`game/main.gd:5401-5404`: 4→10→20 ger 0,120→0,107→0,099 i medel och krymper ljuspölarna).
4. **Mipmaps är inte grynfixen.** Jag satte `mipmaps/generate=true` på alla 863 texturer och bytte
   ytmaterialet till `NEAREST_WITH_MIPMAPS` (`game/main.gd:5379`) i en kopia, importerade om och mätte:
   högfrekvent innehåll **ökade** 4,5 % och bilden blev 3,9 % ljusare. Inget skimmer försvann.
   Förklaringen står i koden: ytornas albedo är en **runtime-textur** (`_kant_dämpad()` gör en
   `ImageTexture` av en nedskalad/uppskalad blanding, `game/main.gd:5471-5497`) och en sån har aldrig
   mipmaps hur importinställningen än ser ut. Att tro att importflaggan styr den bilden är fel.
5. **Efterbehandlingen brusar inte vid nuvarande värden.** SSR/AO/SSIL/volymdimma av gav 11 % *mer*
   högfrekvent innehåll (5,14 mot 4,63). Deras bidrag är mjukt (kontaktmörker, dimma), inte gryn.
   Obs: i GL/Compatibility (webb-bygget) är de av redan i koden — `rymd_ljus = RenderingServer.get_rendering_device() != null`
   (`game/main.gd:694`), så en mätning gjord med `--rendering-driver opengl3` säger ingenting om dem.
   Mitt första A/B var just ett sånt blindskott; det är inte med i tabellen.
6. **Rutnätet är rent.** Ingen ojämn skalning att fixa. Det som ser "pixligt" ut är avsiktligt
   (NEAREST) och det som ser grynigt ut är mörker + skanlinjer + relief, inte uppskalningen.

## Vad 4.8 ger som är värt något här

Från `ljus48-01`, med varje påstående kontrollerat mot release notes av mig (alla fem PR-nummer stämmer):

- **Multi-bounce-approximation av AO (GH-115426, dev4).** Release-noten säger rakt ut att scener förut
  blev *för mörka* eftersom interreflektioner saknades. I en vy med 5 % medelljushet är det här den mest
  relevanta nyheten i hela 4.8 — kontrollera om våra SSAO/SSIL-inställningar kan sänkas när AO:n inte
  längre övermörkar. Forward+ bara.
- **Decals i Compatibility (GH-118070, dev4)** — tak 64 per bildruta, 8 per yta. Öppnar för brännmärken,
  blod och blodspår även i webbversionen, som i dag inte kan något av det.
- **SSCS/screen-space contact shadows (GH-118045, dev6)** — gäller riktningsljus, alltså **inte** vår
  lykta och våra facklor (båda är OmniLight/SpotLight). Läs inte in mer i den än så.
- Mip-nivåbaserad texturströmning (dev5) — VRAM, inte utseende. Stäng av tills någon mäter.
- Många av sakerna som ser ut som "4.8 gör bilden bättre" finns redan i 4.7 och används redan.

## Vad som skall göras först — och i vilken ordning

1. **Ljuskalibrering mot ett målvärde.** Vyn ligger på 12,94/255. Bestäm ett mål (t.ex. 20–25 i medel
   med samma "mörka korridor"-känsla), och nå det med lyktans energi och facklornas, inte med
   omgivningsljuset (repot har redan mätt att platt omgivningsljus tvättar bort rymden, `game/main.gd:688-699`).
   Mät med `_bild_statistik`-siffrorna i `-- normalprov`-utskriften, samma kamera varje gång.
2. **Sänk `normal_scale` från 4,0 och se vad som händer med ljuspölarna.** Den är den enda ratten jag
   hittat som både mörkar bilden och lägger till högfrekvent innehåll. 4,0 → 2,0 är ett prov, inte en åsikt.
3. **CRT-styrkan som en siffra, inte av/på.** `crt=N` skalar hela effekten; skanlinjerna är 20 % av
   bildens medelljushet. Prova skanlinje och kroma separat (`game/ui/crt.gdshader` har egna uniforms)
   och visa Alex tre bilder: som nu, halv skanlinje, ingen — det är ett tyck-beslut och han ska tycka.
4. Sedan, om bilden fortfarande är grynig: palett-/ditherpass eller högre intern 3D-upplösning
   (rapport 05 avsnitt 1–3) — men först efter 1–3, annars mäter man sin egen ljussättning.

## Fienderna: pixlarna som lossnar (Alex förtydligade 2026-10-11)

Hans egna ord: *"Tänk dig spelet Teardown, när man slår sönder något, så lossnar voxlar från objektet.
Samma med fienden, Lite som en hälsodeklaration över deras hälsa."*

Alltså inte "byt ut fiendebilden mot en voxelmodell". Det är **förlusten** som ska synas: när man slår en
fiende lossnar bitar ur den, och mängden bitar som lossnat ÄR hälsoindikatorn. Det svarar på voxelfrågan
med "nej, inte hela figuren" — en fiende som tappar material är en voxel som går sönder, och det går att
bygga på en bilboard med figurens egen palett.

- Fienderna är `Sprite3D`, sex rutor, `BILLBOARD_ENABLED`, `NEAREST`, `ALPHA_CUT_DISCARD`, `pixel_size`
  0,012 (1,44 m quad, `game/main.gd:3981-3990`, `4046-4062`). Ingen voxelmodell behövs för att bitar
  ska lossna.
- Receptet finns redan i repot: `docs/undersokning/hit-02-pixelkonst.md:3-8,57-82` föreslår 6–12 små
  fyrkantsquads ur figurens egen palett, 2–4 spelpixlar, 0,55 s livstid, och pekar ut träffkroken.
  `game/core/fx.gd` har redan en partikelfabrik (damm) att utgå ifrån i stället för att bygga en ny.
- Det som gör det till Teardown och inte bara gnistor: **antalet bitar ska följa skadan**, och figuren ska
  se tunnare/sargad ut när den är nära död (bitar borta ur silhuetten, inte bara röda blink).
- Kostnaden är en kväll, det syns i 480×270, och det kräver ingen ny konst — bara palettdragning ur
  fiendens egen ruta.
- Om han *också* vill prova volym på riktigt: **en boss**, i Blender headless (arbetsflödet finns redan i
  projektet), ställd bredvid sin egen sprite i samma rum, samma kamera och ljus, A/B-fotograferad. Mät
  silhuettens höjd i pixlar, pixeländringen vid 30° sidovinkel och frame time vid 1/10/20 kopior. Blir
  bossen bättre är frågan därefter om de andra 16 är värda samma arbete.

## Källor och kontroller

- Agentrapporterna: `ljus48-01` … `ljus48-05` (fem filer, en fråga var). Varje `fil:rad` jag stickprovade
  stämde (`game/main.gd:5379`, `:6496-6503`, `:3981-3990`, `game/ui/crt.gdshader:17-40`), och alla fem
  GH-numren i rapport 01 kontrollerades mot release-noterna: 115426, 118070, 109737, 118045, 107958.
- Fyra rättelser är gjorda i efterhand och märkta i filerna: felpremissen 2,667× (två ställen i 05),
  två finska meningar (05), påståendet att projektet står på Godot 4.7 (04), ett stavfel (04).
- Mätningarna ovan går att köra om: `DISPLAY=:99 godot --path game --audio-driver Dummy -- shot crt=0`
  och `-- normalprov=0`, plus `Xvfb :99 -screen 0 1280x720x24 +extension GLX` om skärmen inte finns.
  Skärmbilder hamnar i `~/.local/share/godot/app_userdata/HellCrawler/`.
