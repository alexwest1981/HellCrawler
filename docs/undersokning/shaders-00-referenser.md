# Shader-referenser: vad de ger HellCrawler

Alex länkade sex shaders (fem i omgången 11/10, plus retro-luma tidigare). Det här är vad var och en
faktiskt löser hos oss, vad den kostar, och var i koden den skulle landa. Länkarna är hämtade och
lästa, inte gissade.

Måttstocken är spelets egna förutsättningar: 480×270 intern upplösning, Forward+, pixelkonst på 128 px
rutor, ett mörkt rum där lyktan är nästan allt ljus (mätt: medelluminans ~19/255, 25 % av pixlarna
under 10).

---

## 1. cs-2 water — **taget i bruk, den viktigaste av dem**

`godotshaders.com/shader/cs-2-water/` (erBimo, juli 2026)

Animerade normal maps + flow map (två UV-uppsättningar som korsar varandra) + skärmrymdens refraktion
+ djupdimma + **fresnel-viktad reflektivitet**:

```glsl
float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
float reflect_amount = mix(reflectivity, 1.0, fresnel);
```

**Vad den gav oss:** fresnel-raden. Vår fukt-shader hade råhet 0,05 och rak spegling — i en mörk
korridor blev högdagern en nålsticka, och vätan syntes inte alls i provbilden. Med fresnel speglar
ytan mer i betraktningsvinkel, alltså lyser golvet framåt och är mörkt vid fötterna. Det är
skillnaden mellan "mörk fläck" och "våt fläck". Krusningen (en liten normalvobbel ur bruset) kom
också härifrån: en spegel ger ingen synlig glans, ett streck gör det.

**Kvar att hämta:** flow-mappen (två normal-UV som driver åt olika håll) om vi någon gång vill ha
rinnande vatten i en kanal, och skärmrymdens refraktion — men den senare kräver en genomskinlig
vattenyta med djup, och vi har ingen. Inte nu.

**Kod:** `game/core/fx.gd`, `VATTEN_SHADER`.

---

## 2. tiler (pseudo splatter) — **för damm och partiklar, senare**

`godotshaders.com/shader/tiler-pseudo-splatter/` (ProfesorShader, juli 2026)

En `canvas_item`-shader som lägger samma bild på slumpade storlekar, positioner och rotationer i ett
rutnät — utan loopar (18 rutor räknas parallellt i en enda `fract`/`floor`). Tänkt för 2D.

**Vad den ger oss:** ett sätt att få *variation utan instanser*. Vår damm och våra partiklar är redan
GPU-partiklar med slumpad start, så vi behöver den inte där. Den passar i stället dekor-*lagret*: i
dag är varje rekvisit en egen instans i en MultiMesh (mätt: 68 småsten + 22 kandelaber + 53 mossa på
en våning). Vill vi ha fler och billigare kan samma fläckbild målas i shadern i stället.

**Slutsats:** spara tills vi mäter att rekvisiten kostar. Just nu är de 143 instanser — det är
ingenting. Inte nu.

---

## 3. minimal retroreflective microfacet (MRM) — **nej, men intressant**

`godotshaders.com/shader/minimal-retroreflective-microfacet/` (tentabrobpy, juni 2026)

Godots standard-PBR utbytt mot en retroreflektiv mikrofacetmodell (vägskyltar, reflexvästar).

**Varför inte:** retroreflektion är precis motsatsen till fresnel — ytan kastar ljuset *tillbaka mot
källan* i stället för att spegla i betraktningsvinkeln. Alex såg den antagligen för glansen skull, och
för en metallisk eller glansig yta är den vacker, men vår sten är dielektrisk och matt. Att byta ut
hela ljusmodellen för att få en glans vi redan har (via fresnel, se 1) är mer risk än vinst.

**Om vi någon gång vill:** den ligger som en kopia av Godots egen `scene_forward_lights_inc` och
ersätter därmed all belysning i hela spelet — det ska i så fall mätas mot `-- fpsprov` och
glansprovet, inte smygas in. Inte nu.

---

## 4. heightmap voxel traversal — **het kandidat för OMD-looken**

`godotshaders.com/shader/heightmap-voxel-traversal/` (tentabrobpy, maj 2026)

En fragment-shader som ristar en höjdkarta som *voxlar*: strålen går genom ett rutnät i tangentrymden
och stannar vid första träffen, med normal per voxel ur höjdkartan. Ingen geometri, ingen mesh — bara
en textur och en loop med `max_steps` (64 räcker).

**Vad den ger oss:** One More Dungeon-looken. Deras väggar och golv är *blockiga* — man ser att rummet
är byggt av klossar. Vi har platta 1 m-rutor med en textur på. Med en höjdkarta per tema (8 nivåer) kan
samma platta ruta få synligt djup i stället för bara en teckning. Kostnaden är 64 texelsamplar per
bildpunkt och en extra textur — mätbart, men rimligt på 480×270.

**Vad som krävs innan:** höjdkartor i `tools/gen_tiles.py` (8 nivåer ur samma bild vi redan ritar),
och ett beslut om att rutorna ska ha djup alls. Inte nu, men det här är nästa steg mot OMD.

---

## 5. cone step mapping — **nej, samma mål men dyrare**

`godotshaders.com/shader/cone-step-mapping/` (ElSuicio, maj 2026)

Parallax med konsteg (LoneSock): en extra "konkarta" per textur gör att strålen kan hoppa framåt
exakt, i stället för att stega. 256 steg, `skip_vertex_transform`, egen TBN-matris, ~200 rader.

**Varför inte framför 4:** samma sak (djup på en platt yta), men den behöver en *till* målning —
konkartan — utöver höjdkartan, och den är känslig för UV-kontinuitet (våra rutor kantställs mot
varandra, där går sömmen). Välj 4. Inte nu.

---

## 6. retro luma color reduction (quantization/posterize/dithering) — **senare, efter ett beslut**

`godotshaders.com/shader/retro-luma-color-reduction-quantization-posterize-dithering/`

Post-process som kvantiserar färgen till ett fåtal luminanssteg, med ordnad dithering.

**Vad den ger oss:** en enhetlig retro-palett — bilden får samma färgantal som pixelkonsten. Vår CRT
ligger redan som post-process (`ui/crt.gdshader`) och gör skanlinjer, vinjett, kromaförskjutning och
hörnkrökning. Att lägga färgkvantisering på samma ställe är tio rader.

**Varför inte redan:** grynighetsmätningen (ljus48-02) visade att 25 % av bilden ligger under 10/255
och att CRT:n står för 20 % av ljuset. Kvantisering i den änden av skalan är där bandbildning syns
mest. Det ska mätas på en riktig bild innan det slås på, inte kännas efter. Inte nu.

---

## Sammanfattning

| Referens | Nytta | Status |
|---|---|---|
| cs-2 water | fresnel + krusning ger synlig våt yta | **inbyggd i `VATTEN_SHADER`** |
| heightmap voxel traversal | blockigt djup = OMD-looken | nästa steg, kräver höjdkartor |
| tiler pseudo splatter | variation utan instanser | spara tills rekvisiten kostar |
| retro luma | enhetlig palett i CRT-passet | mät först |
| cone step mapping | samma som 4, dyrare | nej |
| MRM (retroreflective) | annan ljusmodell | nej |

---

# Omgång 2 (11/10, tio till)

Samma måttstock. **Tre av tio sidor hade inget kodblock alls** — kontrollerat i rå HTML med `curl`,
inte bara i utdraget: `vfx-light-flare-streaks`, `vfx-frame-interpolator-with-gradient-tint` och
`proxima-ggx` publicerar koden hos sig (itch/GitHub), inte på sidan. De kan bara bedömas på sin
beskrivning.

| Referens | Vad den gör | Vad den ger oss | Status |
|---|---|---|---|
| **pixelated-fire** (Elliptical) | 3D-billboardeld, `filter_nearest`, `floor(UV*resolution)` kvantiserar flamman, 30 fps-takt | Våra facklor och sprickor är redan billboards med GPU-partiklar. Den här ger *pixlad* eld i 12–30 fps i stället för mjuk partikelström — exakt pixelkonstens regler (hit-02) | **het kandidat**, nästa grafiska steg |
| **dissolve with glowing burn edge** | `canvas_item`: fbm med domänvridning river organiska hål, glödande kant som svalnar | Dödsanimation. Vi har korn (Teardown-liknelsen); den här ger *bortfrätning* med glödkant. Passar eld- och smältvånare | kandidat |
| **magical-mist** | `shader_type fog`, FogVolume med brus + gradient som roterar | Dimma i grottan. Vi har volymetrisk dimma på redan (och den kostade 11 % gryn, mätt) | möjlig, mät mot grynigheten |
| **additive-volume-integral** | Additiv dimma/ljusskaft ur djupbufferten; densiteten integreras längs strålen (`F(t)-F(0)`) | Ljusskaft från facklor. Kräver `depth_test_disabled` och Forward+ (vi har båda) | möjlig |
| **linear-additive-volume** | Samma familj, enklare: bakre ytans avstånd minus främre = vägen genom volymen | Ljusskaft, retro/NPR. Samma plats i koden | möjlig |
| **growthshader** | Tillväxtkarta i UV2 driver vertexskala/förskjutning + upplösningskant | Växter/ kristaller som växer fram. Kräver en tillväxtkarta per mesh | senare |
| **disney-brdf** | Hela Disneys BRDF som materialmodell, med alla map-kanaler | Full PBR per material. Alldeles för mycket för pixelkonst — vi vill ha *mindre* brus i ljussättningen, inte fler kanaler | nej |
| **MRM/Disney/PBR-byten** | (tre olika ljusmodeller i samma omgång) | Se ovan | nej |
| **vfx-light-flare-streaks** | Två pass radiella sinussvep | Träff-glans vid slag. **Ingen kod på sidan** — egen variant vore ~20 rader om vi vill | nej (tills vidare) |
| **vfx-frame-interpolator** | Mjukar ut 16-frames VFX genom att blanda två rutor via en mask-kanal | **Fel för oss**: vi *kvantiserar* effekterna till 12 fps med flit (hit-02). Interpolering suddar ut precis det | nej |
| **proxima-ggx** (Callisto) | Diffus Burley + Schlick-GGX | Samme upphovsman har **Diffuse Burley + Specular Schlick-GGX** *med* kod på sajten — läs den i så fall | nej (läs den andra) |

## Vad jag tar med mig

1. **pixelated-fire** är den enda av de tio som direkt träffar vår stil: pixlad eld i fast bildfrekvens.
   Våra lågor är redan billboards, så det är ett materialbyte på ett ställe (`Fx._låga`), inte ett system.
2. Resten är ljusmodeller (nej — för mycket för 480×270 pixelkonst) eller tekniker för ytor vi inte har
   (hologram, skaft, tillväxt).
3. En notis om sajten: **tre av tio kodblock är tomma** även i rå HTML. Läs alltid `curl`-versionen
   innan något planeras kring en shader därifrån.


---

# Omgång 3 (11/10, sex till)

Samma måttstock. `double-dither` hade inget kodblock ens i rå HTML (kontrollerat med `curl`, samma
mönster som tre av tio i omgång 2 — författaren säljer koden på itch).

| Referens | Vad den gör | Vad den ger oss | Status |
|---|---|---|---|
| **basic self-shadowing from heightmap** (PickledSosig) | Strålmarschar en höjdkarta i ljusets riktning: ytan skuggar sig SJÄLV, utan geometri (32 steg) | **Andra halvan av OMD-looken.** Område 1 gav höjd-djupet (heightmap voxel traversal); den här ger skuggan som gör djupet läsbart — fogarnas och stenkanternas kontaktmörker. Båda behöver samma höjdkartor ur `tools/gen_tiles.py` | **het kandidat, i par med heightmap voxel traversal** |
| **billboard grass with wind** (Purga) | Vinden är ett BRUSFÄLT som rör sig över världen — bladen böjer sig i en våg, inte var för sig | Vår dekor har redan gräs som MultiMesh-billboards (`ui/dekor.gdshader`) men vinden är `sin(TIME * vind + fas)` per tuva: varje tuva vibrerar för sig, ingen vind FAR genom ängen. Ett advekterat brusfält i shadern är ~10 rader och **kräver ingen ny textur** (samma värdebrus som fuktshadern) | **billig vinst, görs när som helst** |
| **simple pixelated fire** (MIT, canvas_item) | Eld ur gradient + brus, kvantiserad till `pallet_size` färger via luminanströsklar | Metoden, inte shadern: att TRÖSKLA flamman till palettens steg är precis vad som får eld att läsa som pixelkonst. Hör i så fall i den 3D-varianten (`pixelated-fire`, omgång 2) — våra lågor är billboards i världen, inte canvas | metod värd att kopiera, inte filen |
| **retro parchment paper** (CC0, canvas_item) | Sepia + vinjett + pappersbrus + bläckblödning + smuts, 32 prover per bildpunkt | Färdigt för en 2D-panel (världskartan, albumet, slutet). MEN: sepia-mixen flyttar färgerna UT ur vår 27-färgspalett, och 32 texturprover per bildpunkt är 4 miljoner hämtningar per bildruta i 480x270 | nej tills en panel ska se ut som pergament — fråga då |
| **transition shader with patterns** (binbun) | Gradient + kaklad form-textur = vilken form som helst på en övergång | Våra övergångar är DIEGETISKA (kameran sjunker genom golvet, M44) — en formad torka läser som en MENYövergång och passar skalet, inte våningen. Skalet har ingen övergång att byta i dag | nej |
| **double dither** (nojoule) | Två ditherpass → cirklar med fransiga kanter, 5 alfasteg | Samma familj som ovan: hör till skal/övergångar. Idén (5 steg i stället för en mjuk ton) är retro och billig att skriva själv, men det finns ingen plats den behövs i dag | nej, tills en skärm ska tonas |

## Vad jag tar med mig ur omgång 3

1. **Höjdskuggan är den saknade halvan av OMD-jobbet.** Höjd-djup utan skugga är en gråsörja; skuggan
   är vad som gör fogarna läsbara. De två shaders (omgång 1 #4 och omgång 3 #1) är ETT jobb: bygg
   höjdkartor i `tools/gen_tiles.py`, lägg reliefen i tile-materialet, och mörklägg den med
   strålmarschen. Mät mot fps-provet innan den slås på för alla teman.
2. **Gräsvinden kan bytas i dag** utan en ny textur: ett advekterat värdebrus i `ui/dekor.gdshader`
   (samma `brus()` som fuktshadern) ger en våg genom ängen i stället för 53 tuvar som vibrerar var för
   sig.
3. **Pergament, dither och formade övergångar** är skalsaker. De rör inte våningen, och sepia-mixen
   bryter mot palettregeln — de väntar tills någon skärm faktiskt ska se gammal ut.

---

# Omgång 4 (11/10): kortens falska 3D, och en sandstorm utan kod

| Referens | Vad den gör | Vad den ger oss | Status |
|---|---|---|---|
| **faux 3d perspective for 2D canvas items** (CodeVogel, MIT) | Låtsas-3D på en canvas-item: roterar en textur i `rot_x`/`rot_y` med simulerad `fov`, med fram- och baksida (`use_front`) | **Korten** — men tricket kräver att rutan ritas som EN textur. `VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE` läser UV som plats i rutan, och vår `CardView` ritar konst OCH glyfer i samma CanvasItem: en glyfs UV är dess plats i fontatlaset, så texten skulle vrida sig till skräp. Författaren löser det med en SubViewport (rita kortet till en textur, vrid texturen) — och hans egen kommentarstråd handlar om att texten blir suddig där | **BYGGD 11/10:** `ui/kort3d.gdshader` + en `SubViewport` i `ui/reward_fx.gd`. Mätt: vriden 38,9° läser kortet som en trapets (kista_vand.png), framifrån är det skarpt (1:1), 8 kontroller i test_reward följer uniformerna. Se ONSKEMAL 34. Handens hover nöjer sig med en framskjutning på 8 % — en yta per kort var inte värt det |
| **sandstorm / fog** (MIT) | Volymetrisk dimma/sandstorm i en `FogVolume` | Ingen kod alls på sidan (curl: 0 kodblock, som `double-dither`). Vi har redan volymetrisk dimma, och den kostade 11 % gryn (mätt, ljus48-02) | nej |

## Vad jag tar med mig ur omgång 4

1. **Faux-3D hör till EN ruta, inte till handen.** I handen ligger 4-6 kort i en solfjäder där vridningen
   redan finns (`FAN_*`), och ett SubViewport per kort är 4-6 nya texturvägar i bildrutan för en
   kosmetisk vinst. Den plats där det faktiskt BERÄTTAR något är belöningskortet: det vänds in med en
   glöd (M45) och en riktig vändning i rummet i stället för en platt skalning är hela poängen.
2. **Kostnaden är en andra textväg, och den ska mätas.** Ett SubViewport-kort renderar sin text i
   viewportens upplösning, medan resten av skalet ritar text i FÖNSTRETS px (`UiText`). Blir texten
   mjuk märks det som löpmått på 1, 2 och 3 px om varandra — samma mätning som M78 använde för att
   fälla den ojämna kortskalan. Mät före/efter och behåll bara om måtten håller.
3. **Sandstormen behövs inte**: ingen kod publicerad, och vår dimma är redan mätt (den kostade gryn, och
   anisotropin är satt för att facklorna ska synas i luften).
