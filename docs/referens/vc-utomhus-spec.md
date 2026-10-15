# Vampire Crawlers – hur de gör "utomhus" i en dungeon (himmelett, horisont, ljus, rumsgränser)

Research underlag: `il2cpp/dump.cs` (Il2CppDumper, typ/fält/signaturer), VC:s egna bundles via UnityPy,
samt `vc_texter/*.json`. Allt är läsning av VC:s filer – inget spel i HellCrawlers är ändrat.

Källor förkortas: `dump.cs:N` = radnummer i `/home/alex/.hermes/cache/scratch/il2cpp/dump.cs`.
Bundle = fil i `.../StreamingAssets/aa/StandaloneWindows64/`.

---

## 0. Sammanfattning i en rad

De har **ingen fungerande himmel via RenderSettings i dungeon-scenen** – himlen är **geometri och sprites
inne i rumsmallarna** (kuber/plan med en cubemap-shader, sprite-stackar, gradient-shadern), medan
kameran i dungeonsläget rensar till **SolidColor** och nivåns himmels-/dim-inställningar kommer från
`DungeonConfig` + `EnvironmentConfig` (per bana, inte per rum).

---

## 1. Hur himlen/horisonten är byggd, steg för steg

### 1.1 Scenbilden: dungeon-kameran ritar INGEN skybox

`level3` är spelets stora spelscen (rötterna innehåller `CommandRunner`, `Main Camera`,
`DungeonCameraPostFx`, `DungeonCameraWeapons`, `DungeonCameraNoFx`, `RT_CardCam`).

| Objekt i level3 | Fält | Värde |
|---|---|---|
| `DungeonCameraPostFx` (Camera) | `m_ClearFlags` | **2 = SolidColor** ("Color"), bg (0,0,0,0) |
| `DungeonCameraNoFx` (Camera) | `m_ClearFlags` | 4 = Nothing |
| `DungeonCameraWeapons` (Camera) | `m_ClearFlags` | 4 = Nothing, bg (0.565, 0.726, 0.715) |
| `DungeonCameraPostFx` (**Skybox**-komponent) | `m_CustomSkybox` | `{FileID 0, PathID 0}` = **NULL** |

Enums bekräftar tolkningen: `Skybox = 1; Color = 2; SolidColor = 2; Depth = 3; Nothing = 4` (`dump.cs:519052`).
Scenens `RenderSettings` (level3) har dessutom `m_Fog: false`, `m_SkyboxMaterial: {FileID 0, PathID 0}` (NULL),
`m_AmbientMode: 3` (= Flat, `dump.cs:540357`), `m_AmbientIntensity: 1.0`.

Jämför med **staden** (`level2`, "Gorton"): `_TownCamera` har `m_ClearFlags = 1` (= Skybox) och en
`Skybox`-komponent med `m_CustomSkybox = {FileID 1, PathID 11}` – en verklig materialreferens (externt
löst; den enda skybox-kompatibla materialen i projektet är `TutorialSkybox`, se `sharedassets0`).
Staden är alltså den enda platsen där Unitys skybox-slot faktiskt används för kamera-himlen.

**Slutsats:** i dungeons syns ingen Unity-skybox. Himlen man ser är *saker i rummet*.

### 1.2 Mönstret "FauxSkybox": kubemappade plan/kuber runt rummet

Fyra materialfamiljer bär himlen inne i rummen (alla på en ShaderGraph-shader med cubemap-sample):

* `FakeSkyBox` (biome-sharedshaders) – tex-envarna är `_RotatingCubemap`, `_StaticCubemap` och en
  genererad `_SampleCubemap_975f5046002b4743af911b7b33ca3d15_Cube_1_Cubemap`.
* `CappellaFauxSkybox`, `CappellaStainedGlassFauxSkybox` (biome-capellamagna),
  `GalloFauxSkybox` (biome-gallotower) – samma shader-familj.

Lästa värden (typett-träd ur bundlarna):

| Material | `_RotatingCubemap` | `_StaticCubemap` | `_RotationSpeed` | `_Lightning` | `_blendOpacity` | `_Color` (HDR) | `_Cull` |
|---|---|---|---|---|---|---|---|
| `FakeSkyBox` | null | null | 1.0 | 0.0 | 0.0 | `_Color` vit, `_lightningClolour` (22,6 20,7 18,7) | 2 |
| `CappellaFauxSkybox` | CappellaMagnaSkybox | – | **0.1** | 0.0 | 0.0 | (1.28, 1.74, 2.04) | 2 |
| `CappellaStainedGlassFauxSkybox` | CappellaStainedGlassSkybox | – | **0.1** | 0.0 | 0.0 | (2.41, 5.70, 7.86) | 2 |
| `GalloFauxSkybox` | GalloTower_Sky | SkylineSkyboxAlpha | **−1.0** | 0.0 | 0.5 / 1.0 | (4.35, 7.22, 11.98), `_lightningClolour` (27,7 6,4 135,6) | 2 |
| `TutorialSkybox` (i biome-capellamagna) | CreditsSkybox | – | 0.0 | 0.0 | 0.0 | vit | 2 |

Exempel på geometri, med världsposition/skala räknad ur transform-hierarkin:

* **Gallo Tower, balkongrum** (`GalloTower_Layout_2x3_Balcony_Dead_02`): ett objekt som heter
  **`FauxSkyboxBlocker`** (egen mesh, `GalloFauxSkybox`) med skala **5.11 × 17.86 × 8.30** – en stor
  "vägg/slabbe" som målar himlen och skymmer tomheten. Ett annat balkongrum har
  `FauxSkyboxBlocker` i skala 6.01 × 5.75 × 9.49.
* Samma balkongrum har `Plane`-objekt (Unitys inbyggda Plan-mesh, 10×10) med `GalloFauxSkybox`:
  `GalloTower_Layout_2x3_Balcony_02/Plane` på **(0.02, 18.32, −0.06)**, skala 2.43 × 7.46 × 3.60
  (himlen *ovanför*), och `GalloTower_Layout_3x3_Balcony_01/Plane (1)` på **(0, −5.20, −0.06)**,
  skala 3.61 × 2.36 × 3.60 (himlen *nedanför* – det är ett torn man ser ut/down ifrån).
* Korridorer: `GalloTower_Corridor_Straight_01_Corridor/Plane … Plane (5)` i skala ~0.11–0.41 × 1–1.9 × 0.39
  = smala fönster/springor med himmel bakom.

### 1.3 Cappella Magna: fönster mot himlen (blandat inne/ute) + en sluten "himmelkub"

* **1901 renderers** i `biome-capellamagna` använder något av faux-skybox-materialen. Vanliga
  `StainedGlass_01/02/03/08/09/10/11`-meshar har faux-skybox-materialet i ett eget materialslot –
  t.ex. `CappellaMagna_Layout_3x3_Dead_02/StainedGlass_08 (15)` med
  `['ext','ext','CappellaStainedGlassFauxSkybox']`. Det är precis mekanismen "inomhus med
  dörr/fönster mot himlen": glasmåleriet *är* hålet mot cubemapen.
* **Ender-bossens epilog-rum har en riktig himmelbox:** hierarkin
  `CappellaMagna_EnderBoss_Epilogue_Layout/Sky/Sky`, `Sky (1)`, `Sky (2)`, `Sky (3)`, `Sky (4)`,
  alla med materialet **`TutorialSkybox`** (→ CreditsSkybox, HDR BC6H) och skala **152.1 × 0.108 × 7.912**
  (och takplanet `Sky (1)` 9.24 × 1.0 × 7.91, y = 169.47). Fyra plan kring x ≈ 69.9–79.0, z ≈ 98.5–103.6,
  y = 88.57 → en **sluten box av himmelstexturerade kvadrater** runt arenan.
* `CappellaMagna_EnderBoss_Falling_Layout/AnimatedSky/...` – en animerad himmel (se 1.4).
* `MadForestBossClouds` finns även i Cappella-bundlen (samma molnmaterial återanvänds).

### 1.4 `EnderBossSky` – vad klassen gör

`public class EnderBossSky : MonoBehaviour` (`dump.cs:77635`), fält:

```
[SerializeField] private TriggerColliderEvents _triggerEvents;   // 0x20
[SerializeField] private AnimancerComponent _animancerComponent; // 0x28
[SerializeField] private ClipTransition _skyClip;                // 0x30
[SerializeField] private float _skyTransitionTime;               // 0x38
// Awake, OnDestroy, StartSkySequence(Collider other)
```

Instansen finns i `roomtamplates-unique_assets_rt_enderboss.bundle` på GameObjectet
**`RT_EnderBoss/DungeonLayout/CappellaMagna_EnderBoss_Falling_Layout/AnimatedSky`**, med lästa värden:

* `_skyTransitionTime = 120.0` (sekunder)
* `_skyClip` = `{"_FadeDuration": 0.25, "_Speed": 1.0}` med `_Clip` → AnimationClip
  **`EnderFallSunset`** (m_MuscleClipSize 486896 B, m_SampleRate 60)
* `_triggerEvents` → en `TriggerColliderEvents`-komponent (dvs. himmelbytet startar när spelaren går in i en trigger)

`EnderFallSunset` är en **komprimerad** kurva (m_FloatCurves tom; `m_ClipBindingConstant.genericBindings`
= 46 st). Attributhasharna matchar exakt `m_Color.r/g/b/a` (2526845255 / 4215373228 / 2334886179 /
304273561 = zlib.crc32 av dessa namn), med target-`typeID 212` = **SpriteRenderer** och `typeID 4` = Transform.
Det betyder: **solnedgången animeras genom att färga/tona sprite-lager över 120 sekunder**, inte genom att
byta skybox eller riktljus.

`AnimatedSky`-hierarkin är just en sådan sprite-stack (sortingOrder i parentes, lästa färger):

| Objekt | typ | sortingOrder | färg (start) | storlek |
|---|---|---|---|---|
| `AnimatedSky/skyColour` | SpriteRenderer | **−1** | (0.357, 0.918, 0.992, 1) | 5.12 × 5.12 |
| `AnimatedSky/Sun` | SpriteRenderer | 0 | vit | 1 × 1 |
| `AnimatedSky/stars` | SpriteRenderer | 1 | vit, **alpha 0.0** | 5.12 × 5.12 |
| `AnimatedSky/MadForestBossClouds/CloudsP (1..3)` | SpriteRenderer | 2 | (0.765, 0.918, 0.992) alpha 0.43/0.67/0.81 | 3.2 × 3.2 |
| `AnimatedSky/Clouds (2)` | SpriteRenderer | 2 | vit | 11 × 8 |
| `AnimatedSky/Clouds (1)` | SpriteRenderer | 3 | vit | 6.4 × 4.8 |
| `AnimatedSky/stars_(PropDarkener)` | SpriteRenderer | 4 | vit, alpha 0.0 | 5.12 × 5.12 |
| `AnimatedSky/atmos` | SpriteRenderer | 0 | (0.914, 0, 0.210) alpha 0.0 | 1 × 1 |

Dessutom: `AnimatedSky/Sphere`, `AnimatedSky/Volume` (post-fx-volym), fyra ParticleSystem,
`AnimatedSky/Particle System` med `ParticlesUnlit`.

### 1.5 Horisonten sitter i en shader, inte i en mesh: `cloudscroll_*`

Materialen `cloudscroll_<Nivå>` bor i `sharedassets0.assets` (dvs. nivågemensamma, inte i rumsbundlarna)
och använder samma shader (`ext:f1/pid255`) med **en skärmpositions-split = horisontlinjen**:

| Material | `_ColorTop` (RGBA) | `_ColorBottom` (RGBA) | `_ScreenPositionSplit` (x=horisont, y=tak) | `_XScroll`,`_YScroll` |
|---|---|---|---|---|
| `cloudscroll_TinyBridge` | (0.059, 0.114, 0.169, 0.349) | (0.278, 0.788, 0.996, 0.467) | **0.5**, 1.0 | 0.05, 0.003 |
| `cloudscroll_Tutorial` | (1.0, 0.657, 0.552, 1) | (0.370, 0.520, 0.708, 1) | **0.6**, 1.0 | 0.001, 0.001 |
| `cloudscroll_DairyPlant` | (0.448, 0.498, 0.613, 0.878) | (0.482, 0.757, 0.910, 0.212) | **0.6**, 0.85 | 0.001, 0.001 |
| `cloudscroll_MadForest Dusk` | (0.792, 0.146, 0.146, 1) | (1.0, 0.650, 0.410, 0.349) | **0.6**, 0.85 | 0.001, 0.001 |
| `cloudscroll_MadForest Night` | (0, 0, 0, 1) | (0.019, 0.024, 0.274, 0) | **0.6**, 0.85 | 0.001, 0.001 |
| `cloudscroll_Town` (sharedassets2) | vit, a=1 | vit, a=0 | **0.3**, 1.0 | 0.004, 0.004 |
| `cloudscroll_MadForest 1` (biome-madforest) | (0.358, 0, 0, 1) | vit | **0.4**, 0.8 | 0.0, 0.0 |
| `MadForestEerieClouds` (biome-sharedshaders) | (0, 0.918, 1, 0) | (0.934, 0, 0.348, 0) | **0.5**, 1.0 | 0.0, 0.0 |

Samma shader används alltså för **himlens gradient (toppfärg → horisontfärg) + scrollande molntextur**.
Dairy Plants "dimma" (`MilkFog`, `fog`) och `cloudscroll_EnderBossCloud` (biome-capellamagna,
`_MainTex: LowerClouds`, `_YScroll −0.5`) följer samma mönster.

### 1.6 Är himlen per scen eller per rum?

**Båda, på olika nivåer** – belagt:

* **Per bana (nivå):** `DungeonConfig` (`dump.cs:89718`) har `private Material _skyboxMaterial; // 0x98`
  och `private EnvironmentConfig _environmentConfig; // 0xA0` samt `private VolumeProfile _cameraVolumeProfile; // 0x90`.
  Alla `*Skybox`-materialen ligger samlade i `sharedassets0.assets`:
  `SkyboxNull, CappellaMagnaSkybox, DairyPlantSkybox, DairyPlantSkybox 1, MadForestDuskSkybox,
  MadForestNightSkybox, TinyBridgeSkybox, TinyBridgeSkybox 1, TutorialSkybox, MG_Skybox` +
  `cloudscroll_DairyPlant / _MadForest Dusk / _MadForest Night / _TinyBridge / _Tutorial`.
  Notera **två varianter per bana** (t.ex. `DairyPlantSkybox` och `DairyPlantSkybox 1`, `TinyBridgeSkybox`
  och `TinyBridgeSkybox 1`) och **Dusk/Night**-par för Mad Forest.
* **Per rum (rumsmall):** själva himmelsobjekten finns inne i rumsbundlarna
  (`biome-capellamagna`, `biome-gallotower`, `roomtamplates-unique_assets_rt_enderboss`) – t.ex.
  `CappellaMagna_EnderBoss_Epilogue_Layout/Sky/*` och `GalloTower_Layout_2x3_Balcony_*/FauxSkyboxBlocker`.
  `RoomTemplate` (`dump.cs:74534`) har däremot **inga** himmels- eller miljöfält (bara
  `_roomDimensions`, `_tileTemplates`, `_spawnPoints`, `_propTemplates`, `_roomTemplateEventsOdin`,
  `_exitCandidates`) – himlen följer alltså med som *prefab-innehåll*, inte som konfiguration.
* **Per scen (staden):** `WeatherEffect` (`dump.cs:37744`) med `WeatherSettings` (`dump.cs:37679`):
  `_townCamera`, `_clouds` (SpriteRenderer), `_transitionDuration`, `List<WeatherSettings>`, och per
  väder: `VolumeProfile CameraPPProfile`, `Material SkyBoxMaterial`, `Material CloudsMaterial`,
  `List<GameObject> ExtraObjects`, `AchievementConfig UnlockRequirement`. Väder-typerna är
  `Day = 0, Evening = 1, Night = 2` (`dump.cs:37672`-ish, `WeatherEffect.WeatherType`), och
  `TransitionWeatherAsync` lerpar `tempSkyboxMat`/`tempCloudsMat`.

### 1.7 Rummet "Wing Balcony" – ett negativt belägg

`roomtamplates-unique_assets_rt_wingbalcony.bundle` är **4 353 byte** och innehåller bara
`GameObject: ['Prop_New', 'RT_CM_WingBalcony']`, 2 Transforms och 3 MonoBehaviours
(`''`, `Tag_Layout_WingBalcony`). Ingen mesh, inget material, ingen himmel.
Balkong-himlen ligger alltså i *GalloTowers* balkonglayouter, inte i den lilla bundle som heter "wingbalcony".

---

## 2. Tabell: himmels-/ljusmaterial och var de bor

| Material | Bundle/fil | Cubemap/textur | Nyckelvärden |
|---|---|---|---|
| `FakeSkyBox` | biome-sharedshaders | `_SampleCubemap_…` = **SkylineLightningAlpha** (1024, DXT1, 11 mips) | `_RotationSpeed=1`, `_Lightning=0`, `_blendOpacity=0` |
| `GalloFauxSkybox` | biome-gallotower | `_RotatingCubemap=GalloTower_Sky` (1024, DXT1); `_StaticCubemap=SkylineSkyboxAlpha` (512, RGB24) | `_RotationSpeed=−1`, `_blendOpacity=0.5`, `_BlendOpacity=1`, `_Color`=(4.35,7.22,11.98) |
| `CappellaFauxSkybox` | biome-capellamagna | `_RotatingCubemap=CappellaMagnaSkybox` (512, RGB24, 10 mips) | `_RotationSpeed=0.1`, `_Color`=(1.28,1.74,2.04) |
| `CappellaStainedGlassFauxSkybox` | biome-capellamagna | `_RotatingCubemap=CappellaStainedGlassSkybox` (512, RGB24, 10 mips) | `_RotationSpeed=0.1`, `_Color`=(2.41,5.70,7.86) |
| `TutorialSkybox` (material) | biome-capellamagna **och** sharedassets0 | `_RotatingCubemap`/`_Tex`=**CreditsSkybox** (1024, BC6H) resp. `Cubemap:TutorialSkybox` (1024, DXT1) | `_RotationSpeed=0`; i sharedassets0: `_Cull=2` (Cull Back), inga blend-värden |
| `CappellaMagnaSkybox` (material) | sharedassets0 | `_Tex=Cubemap:CappellaMagnaSkybox` | `_Cull=0` (Cull Off), `_XScroll=_YScroll=1`, `_Blend=13.31`, `_blend=0.8` |
| `DairyPlantSkybox`, `DairyPlantSkybox 1` | sharedassets0 | `DairyPlantSkybox` (512, **BC6H/HDR**, 10 mips) resp. `DairyPlantSkybox2` (512, DXT1) | samma som Cappella |
| `MadForestDuskSkybox`, `MadForestNightSkybox` | sharedassets0 | 512 RGB24 (Dusk 10 mips / Night 1 mip) | `_Cull=2` |
| `TinyBridgeSkybox`, `TinyBridgeSkybox 1` | sharedassets0 | `Cubemap:GalloTower_Sky` | `_Cull=2` |
| `MG_Skybox` (Moongolow) | sharedassets0 | tex-envs tomma | `_RotationSpeed=0.01`, `_Cull=0`, `_Blend=13.31`, `_blend=0.8`, `_Color`=(1.29,2.10,1.98) |
| `SkyboxNull` | sharedassets0 | – | `_Color`=(0.238,0.387,0.481, **a=0.204**) – en halvtransparent "ingen himmel" |
| `cloudscroll_*` (5 st, se 1.5) | sharedassets0 | `_MainTex` ev. molntextur | `_ScreenPositionSplit`, `_ColorTop`, `_ColorBottom`, `_XScroll/_YScroll` |
| `EmissiveSprite_Lightning`, `LightningScroll` | sharedassets0 | – | `_Color`=(1.06,1.06,1.06); `_XScroll=0.01` |
| `cloudscroll_MadForest 1`, `cloudscroll_EnderBossCloud`, `MadForestEerieClouds`, `starscroll_CappellaUltimae`, `EnderSun`, `CloudParticle_03`, `enderCutsceneCloud`, `ParticlesUnlit`, `Star_01A` | biome-madforest / biome-capellamagna / biome-sharedshaders | `LowerClouds`, `EnderStars`, `Star_01`, `CloudsP`, `CloudsB`, `CloudsEnder`, `Cloud` | se 1.5 / 1.4 |
| `fogFull`, `fogGround`, `fogDrowner` | sharedassets3 | – | alla på samma shader (`ext:f7/pid249`), `_QueueControl=0`, **inga sparade färger** → styrs av globala shader-variabler |
| `fogTown` | sharedassets2 | – | – |
| `MilkFog`, `fog` | biome-dairyplant | `_BaseMap` (bl.a. externt pid −4493484974381118794) | MilkFog: `_Surface=1`, `_ZWrite=0`, `_Color.a=0.247`, `_ScreenPositionSplit`=(0.5,1.0), `_ColorTop`=vit, `_ColorBottom`=(0.934,0,0.348) |
| `ReflectionProbe-1` (cubemap) | biome-shared | 256 px, fmt 24, 9 mips | reflektion, inte himmel |

### Alla cubemaps som följer med

| Cubemap | Bundle/fil | Storlek / format / mips |
|---|---|---|
| `CappellaMagnaSkybox` | biome-capellamagna + sharedassets0 | 512, RGB24 (3), 10 |
| `CappellaStainedGlassSkybox` | biome-capellamagna | 512, 3, 10 |
| `CreditsSkybox` | biome-capellamagna | 1024, **BC6H (25)**, 1 |
| `GalloTower_Sky` | biome-gallotower + sharedassets0 | 1024, DXT1 (10), 1 |
| `SkylineSkyboxAlpha` | biome-gallotower | 512, 3, 10 |
| `SkylineLightningAlpha` | biome-sharedshaders + sharedassets0 | 1024, 10, 11 |
| `TutorialSkybox` | roomtemplates-unique-shared + sharedassets0 | 1024, 10, 1 |
| `MadForestDuskSkybox` / `MadForestNightSkybox` | sharedassets0 | 512, 3, 10 / 512, 3, 1 |
| `DairyPlantSkybox` / `DairyPlantSkybox2` | sharedassets0 | 512, 25 (HDR), 10 / 512, 10, 10 |
| `ReflectionProbe-1` | biome-shared | 256, 24, 9 |
| `ArcanaChest` | sharedassets0 | 512, 3, 10 |

---

## 3. Ljusinställningar – lästa värden

### 3.1 Scenens RenderSettings (alla fyra level-filer är nästan identiska)

`level0/1/2/3` `RenderSettings`:

| Fält | Värde |
|---|---|
| `m_Fog` | **false** |
| `m_FogColor` | (0.5, 0.5, 0.5, 1) – level3: (0.321, 0.321, 0.321, 1) |
| `m_FogMode` | 3 (level3: **1** = Linear) |
| `m_FogDensity` | 0.01 |
| `m_LinearFogStart` / `m_LinearFogEnd` | 0 / 300 (level3: **1 / 5**) |
| `m_AmbientMode` | **3 = Flat** |
| `m_AmbientSkyColor` | (0.212, 0.227, 0.259, 1) |
| `m_AmbientEquatorColor` | (0.114, 0.125, 0.133, 1) |
| `m_AmbientGroundColor` | (0.047, 0.043, 0.035, 1) |
| `m_AmbientIntensity` | 1.0 |
| `m_SubtractiveShadowColor` | (0.42, 0.478, 0.627, 1) |
| `m_SkyboxMaterial` | **NULL** (FileID 0 / PathID 0) |
| `m_Sun` | **NULL** |
| `m_DefaultReflectionMode / Resolution` | 0 / 128 |
| `m_ReflectionIntensity` | 1.0 |
| `m_AmbientProbe` | alla 27 SH-koefficienter = 0 (ingen bakad probe) |

`LightmapSettings` i alla scener: `m_EnableBakedLightmaps: false`, `m_EnableRealtimeLightmaps: false`,
`m_EnvironmentLightingMode: 0`, `m_Lightmaps: []`, `m_LightProbeGroups` tomma – **inga bakade ljus, inga lightmaps**.

### 3.2 Ljuskällor i rummen

I **alla** rumsbundlar finns bara **punktljus med samma värden**:

| Bundle | antal Light | typ | färg | intensitet | range | skuggor | `m_Lightmapping` |
|---|---|---|---|---|---|---|---|
| biome-shared | 59 | 2 = Point | (0.877, 0.658, 0.203) varm | **0.75** | **2.0** | 0 = None | 4 = **Realtime** |
| biome-capellamagna | 3 613 | 2 | samma | 0.75 | 2.0 | 0 | 4 |
| biome-inlaidlibrary | 2 152 | 2 | samma | 0.75 | 2.0 | 0 | 4 |
| roomtamplates…rt_enderboss | 644 | 2 | samma | 0.75 | 2.0 | 0 | 4 |
| roomtamplates…rt_credits | 8 | 2 | samma | 0.75 | 2.0 | 0 | 4 |
| roomtamplates…rt_tutorial | 24 | 2 | samma | 0.75 | 2.0 | 0 | 4 |
| biome-tinybridge, biome-moongolowteaser | **0** | – | – | – | – | – | – |
| biome-gallotower (i vc_faux2-läsning) | alla | 2 | samma | 0.75 | 2.0 | 0 | 4 |

Enums: `LightmapBakeType Realtime = 4` (`dump.cs:519014`). Det finns **inget riktljus (Directional)** och
inga skuggkastande lampor i rumsmallarna. "Utomhusljuset" kommer alltså inte från en sol utan från
himmelstexturen (HDR-cubemap) + Flat ambient + ev. post-fx/volym.

I staden (`level2`) finns 32 ljus, varav en typ-2-lampa med intensitet **21.94**, range 49.95 och
skuggor (`m_Type 2, m_Shadows.m_Type 1`), plus många smålampor med intensitet 0.75, range 2.0, inga skuggor.

### 3.3 Dimma som INTE är Unity-fog

`Dungeon3DMapView` (`dump.cs:42509`) har:

```
private static readonly int FOG_COLOR_ID;   // 0x0
private static readonly int FOG_DEPTH_ID;   // 0x4
private Material _groundFogMat;             // 0x88
private Material _fullFogMat;               // 0x90
[SerializeField] private Skybox _dungeonSkybox;          // 0x78
[SerializeField] private PostProcessSettingHandler _dungeonCameraPPHandler; // 0x80
```

och `DungeonConfig.EnvironmentConfig` (`dump.cs:89892`) bär värdena:

```
AmbientMode AmbientLightingMode; Color AmbientColor, SkyColor, EquatorColor, GroundColor;
Color GroundFogColor; float GroundFogDepthFade; Color FullFogColor; float FullFogDepthFade;
bool UseEnvironmentFog; Color FogColor; FogMode FogMode; float FogDensity, FogStartDistance, FogEndDistance;
```

Dimman drivs alltså via **material + globala shader-variabler** (`fogFull`/`fogGround`/`fogDrowner` har
inga sparade färger – allt kommer från globala ID:n). Dessutom: `DisableFogForCamera` (`dump.cs:68934`)
med `_cameras`/`_fogEnabled` som slår av/på dimma per kamera via `RenderPipelineManager`
(`DisableFog/EnableFog(ScriptableRenderContext, Camera)`), och `GlobalShaderVariableHandler`
(`dump.cs:69076`, endast `Update()` – inga fält) som sätter globala shader-variabler varje frame.

**Värdena i `EnvironmentConfig` per bana kunde inte läsas** – `DungeonConfig` ärver
`SerializedScriptableObject` (Odin), och inga `DungeonConfig`-assets finns i de 35 bundlarna,
`sharedassets*`, `level*` eller `resources.assets` (skannat: nycklarna `_skyboxMaterial`,
`_environmentConfig`, `_cameraVolumeProfile` förekommer inte i något MonoBehaviour-typett-träd).

---

## 4. Hur spelaren hålls inne

Tre mekanismer, alla belagda i rumsbundlarna:

1. **Osynlig platt "Collision"-platta per ruta.** I `rt_tutorial` finns `GameObject` som heter
   **`Collision`** med `BoxCollider` och **storlek 10 × 5.686562332130052e-13 × 10**
   (dvs. 10×10 med noll höjd), `m_IsTrigger = false`, **utan renderer**. Rutten är alltså 10×10 enheter,
   och spelaren är inlåst till de rutor som har en sådan platta.
   Vid sidan om finns `Collision (1)`-varianter **med** renderer (synliga) och
   `TriggerCollider` (10 × 10 × 10, `m_IsTrigger = true`) samt `AudioTriggerCollider` (10 × 10 × 10, trigger).
2. **Himmelgeometrin är också vägg.** Varje `Sky`-plan i EnderBoss-epilogen har en `MeshCollider`
   (`convex = false`) på samma mesh: `CappellaMagna_EnderBoss_Epilogue_Layout/Sky/Sky (2)`,
   `Sky (3)`, `Sky (4)` (skala 152.1 × 0.108 × 7.912) och `Sky (1)` (9.24 × 1.0 × 7.91).
   Samma sak i Gallo Tower: `…/Balcony_01/Plane (1)`, `…/Balcony_02/Plane`, `…/Corridor_Straight_01_Corridor/Plane…`
   har `MeshCollider` på samma Plan-mesh (Unitys inbyggda Plane, 10×10, externt pid 10209).
3. **En mesh som heter `FauxSkyboxBlocker`** i Gallo Towers balkongrum – himmelmaterial på en stor slabbe
   som både fyller vyn och (via sin mesh) står i vägen.

Inga kollisionsobjekt med namn som `Bound*`/`Wall*`/`Blocker*`/`Invisible*` bär colliders i de bundlar jag
skannade (enderboss, tinybridge, inlaidlibrary, moongolow: noll träffar) – det finns alltså ingen separat
"osynlig vägg"-mesh, utan gränsen är ruttplattorna (1) plus himmel­planen (2).

---

## 5. Vad som INTE kunde beläggas

* **Värdena i `DungeonConfig._environmentConfig` per bana** (ambient-färger, dimfärg/densitets­värden,
  `UseEnvironmentFog`) – inga DungeonConfig-assets finns i de filer jag har; klassen är dessutom
  Odin-serialiserad (`SerializedScriptableObject`) så fälten kan ligga i ett binärt block.
  Endast **schemat** är belagt (`dump.cs:89892`).
* **Koden som tilldelar `DungeonConfig._skyboxMaterial` till scenens `Skybox`-komponent.** Båda ändarna
  finns (`DungeonConfig.SkyboxMaterial` `dump.cs:89760`, `Dungeon3DMapView._dungeonSkybox` `dump.cs:42538`,
  och `Skybox`-komponenten på `DungeonCameraPostFx` i level3), men Il2CppDumper ger inga metodkroppar,
  så själva tilldelningen kunde inte läsas. Att det *sker* är en slutsats av att scenens
  `m_CustomSkybox` är NULL medan nivåmaterialen finns i `sharedassets0`.
* **Vilket material `level2`-scenens `Skybox`-komponent pekar på** (`m_CustomSkybox = {FileID 1, PathID 11}`).
  Den externa fil-tabellen kunde inte lösas med UnityPy 1.25 (`Environment` saknar `externals`).
  Kandidat: `TutorialSkybox` (enda skybox-kompatibla materialen) – **ej belagt**.
* **Vad `GlobalShaderVariableHandler.Update()` och `TransitionWeatherAsync` faktiskt sätter** – inga fält,
  inga metodkroppar.
* **Shader-namnen.** Alla Shader-objekt i bundlarna har `m_Name = ""` (namnen strippade); jag kan bara
  citera materialnamn, tex-env-nycklar och externa shader-referenser (`ext:f6/pid…`).
* **Om `SkyboxNull` används som "släck himlen" på någon bana** – materialet finns i `sharedassets0`
  med `_Color`-alpha 0.204, men ingen referens från en `Skybox`- eller `DungeonConfig`-asset kunde läsas.
* **`EnderBossSky`-klassens exakta beteende i kod** – endast fältvärden och att den ligger på `AnimatedSky`
  med `_skyTransitionTime = 120` och clip `EnderFallSunset` är belagt; metodkroppar saknas.
* **Ingen bana beskrivs som utomhus i texten.** `Dungeons_en_en.json` har bara 42 poster och alla
  beskrivningar är stämnings­texter; den enda himmelreferensen är en dialograd, `"A cathedral in the sky??"`.

---

## 6. Vad som är värt att kopiera i Godot

Två spår: **(A) kopiera deras metod** och **(B) Godots motsvarighet**. Vi har inga skybox-material än.

### A. Deras metod, rakt av

1. **Himlen är rummets geometri, inte en scen-inställning.** Skapa himlen som *noder i rumsmallen*:
   en inhägnad av plan (kuber) med ett sky-material, eller en sprite-stack. Då kan ett rum vara
   "öppet" medan grannen är grotta, utan att någon scen-inställning ändras.
2. **Cubemap i en shader, inte i WorldEnvironment.** Deras `FauxSkybox*` = plan/kuber som samplar en
   cubemap, med `_RotationSpeed` (0.1 för Cappella, −1 för Gallo) för långsam drift och `_Cull Off`
   på `CappellaMagnaSkybox` (så man ser den inifrån och utifrån). I Godot: `ShaderMaterial` på en
   `BoxMesh`/`PlaneMesh` med `samplerCube` + `TIME * speed` i rotation.
3. **Horisont = en skärmpositions-split i shadern.** `_ScreenPositionSplit` (0.4/0.5/0.6 av skärmhöjden)
   med `_ColorTop` och `_ColorBottom` ger "himmel möter mark" utan en enda mesh. I Godot:
   `SCREEN_UV.y` jämfört med en `horizon`-uniform, `mix(bottom, top, step(horizon, ...))`, plus
   `_XScroll/_YScroll`-motsvarighet = `UV + TIME * scroll` på en molntextur.
4. **Dimma som material med globala parametrar.** `fogFull`/`fogGround`/`fogDrown` har inga egna färger;
   de läses från globala shader-variabler (`FOG_COLOR_ID`, `FOG_DEPTH_ID`) som sätts per bana.
   I Godot: `Environment` per rum, eller en `ShaderMaterial` som läser `shader_parameter` som sätts
   globalt via `RenderingServer.global_shader_parameter_set` – exakt samma arkitektur.
5. **Ljussättningen utomhus är "Flat ambient + varma punktlampor".** Alla rum har samma
   punktlampa (0.877, 0.658, 0.203), intensitet 0.75, range 2.0, **inga skuggor**, **Realtime**,
   och ambient = Flat. Inga bakade lightmaps i hela spelet. Det är billigt och ser bra ut – kopiera rakt.
6. **Spelaren hålls inne av platta osynliga kollisioner per ruta** (10×10, noll höjd) plus
   MeshCollider på himmel­planen. Det ger "du kan gå i rummet men inte ut i tomheten" utan att bygga väggar.
7. **Animerad himmel = sprite-lager med sortingOrder + färgkurvor över lång tid.**
   `skyColour (−1) → Sun (0) → stars (1) → clouds (2–3) → atmos (0)` med
   `EnderFallSunset`-clip (120 s) som bara animerar `m_Color.r/g/b/a`. I Godot: `CanvasLayer`- eller
   sprite-lager i världen med `modulate`-animation (`AnimationPlayer`), 120 s, triggad av en `Area3D`.
8. **En `SkyboxNull`-material som "himmel av"** (halvtransparent mörkblå) för rum som ska kännas stängda.

### B. Godots motsvarighet (där vi inte behöver kopiera deras hacks)

| Deras lösning | Godot-motsvarighet |
|---|---|
| FauxSkybox-plan med cubemap-shader | `WorldEnvironment` med `Sky`-resurs satt **per rum** (Environment-resurs per rum via `Area3D`/`WorldEnvironment` med lägre prioritet), eller samma metod med `ShaderMaterial` på plan om vi vill ha deras look exakt |
| `cloudscroll_*` gradient + `_ScreenPositionSplit` | `ProceduralSkyMaterial` (Ground/Horizon/Sky-övergångar) eller en `ColorRect`-shader på `CanvasLayer` bakom 3D-vyn. Godots `Sky` med `PanoramaSkyMaterial` (en enda HDRI-bild) är den enklaste vägen och ersätter deras 10 material |
| `DungeonConfig._skyboxMaterial` + `Skybox`-komponent | `Environment`-resurs per bana, refererad från vår dungeon-config; ingen kod som måste tilldela material → mindre maskineri |
| `MeshCollider` på himmelplanen | `StaticBody3D` + `CollisionShape3D` (`BoxShape3D`) – billigare och inte beroende av mesh |
| Flat ambient + punktlampor, inga lightmaps | `Environment.ambient_light_source = AMBIENT_SOURCE_COLOR`, `ambient_light_color/energy`; `OmniLight3D` utan `shadow_enabled`, `light_energy = 0.75`, `omni_range = 2.0` |
| Globala shader-variabler för dimfärg | `RenderingServer.global_shader_parameter_set()` – identiskt koncept |

**Rekommendation (lazy):** bygg rummet som en `RoomTemplate`-scen med en **valfri `sky`-nod** (plan/box med
`ShaderMaterial` eller en `WorldEnvironment`-overrider) + **en osynlig `StaticBody3D`-platta per ruta**
(10×10, höjd 0) + **Flat ambient + varma OmniLight3D utan skuggor**. Det ger öppna slagfält utanför stängda
ytor med minsta möjliga nytt maskineri, och vi ärver deras bevisade prestandaprofil. Skippa deras
cubemap-rotation och molnscroll tills vi faktiskt vill ha rörlig himmel – `PanoramaSkyMaterial` med en
enda himmelsbild räcker för första versionen.
