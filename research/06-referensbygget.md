# Referensbygget: vad som går att läsa ur installationen

Mätt 2026-09-19 mot `~/Downloads/Referens.Crawlers-jc141` (en DwarFS-packad release av Steam-app
3265700, utvecklare **Nosebleed Interactive**, givare poncle — står i `app.info`). Bilden är
**inte krypterad**: den är DwarFS-komprimerad och gick att montera läsbar med `dwarfs-binary` som
följer med releasen (`--tool=dwarfs game-root.dwarfs /tmp/vcmnt`, ingen root, inget på skärmen).

**Gränsen jag håller:** allt nedan är *fakta om bygget* — arkitektur, klassnamn, nyckelnamn,
antal, format. Inga bilder, ljud, texter, kortnamn eller kod därifrån hamnar i vårt spel eller i
vårt repo. Våra egna namn och vår egen pixelkonst är regeln, och den gäller även när källan ligger
öppen framför mig.

## Vad som är läsbart, och vad som inte är det

| Del | Läsbart? |
|---|---|
`GameAssembly.dll` (86 MB) + `global-metadata.dat` (18,7 MB) | IL2CPP: ingen C#-källkod, men **193 968 strängar** och alla klassers/metoders namn går att läsa. Ingen kryptering. |
Addressables-katalogen (`StreamingAssets/aa/catalog.bin`) | Ja — hela innehållsträdet: 2 698 strängar, varje tillgångs adress och buntnamn. |
Buntarna (`*.bundle`) | LZ4-komprimerade; läses med UnityPy (venv i `/tmp/vcvenv`). |
Lokaliseringstabellerna | Ja, per språk. |
Sparfiler | `SaveData`/`PlayerPrefs`/`UserData` finns som namn; inget vi behöver. |

## Deras teknikstack (av 168 assemblys)

- Egen kod i `Assembly-CSharp`, `Nosebleed.Core.Runtime`, `Nosebleed.Library.Tweens.Runtime`,
  `Nosebleed.PlatformManager.*`, **`Pancake.dll` + `Pancake.DebugMenu.dll` + `UImGui.dll`** — det
  finns alltså en **debug-meny och en ImGui-overlay i det skeppade bygget** (förklarar `cimgui.dll`).
- Tredjepart: DOTween, Animancer, DarkTonic MasterAudio, DamageNumbersPro, Sirenix Odin, UniTask,
  Steamworks.NET, Epic Online Services, RTLTMPro (höger-till-vänster-text), SoftMaskForUGUI.
- **Unity Localization** (`LocalizeStringEvent`, `StringTable`, `SharedTableData`, `Locale`,
  `PseudoLocale`, `GameObjectLocalizer`) — se språkarkitekturen nedan.
- Nivåteknik: Addressables med en bunt per biom, `RoomTemplate`-prefabs, `DungeonTag`/
  `DungeonTagActivator`, `DungeonCullingRendererSettings`.

## Deras datamodell (klassnamn ur `monoscripts.bundle`, 137 st)

`CardModel`, `CardGemsModel`, `GemSlotModel`, `PowerUpConfig`, `RelicConfig`, `RoomTemplate`,
`KeywordTooltip`, `DestructibleCardCanvas/RT`, `DestructibleManaStatueView`,
`TutorialDungeonCutscene`, `PowerUpAchievement`.

Och deras innehåll är **data, inte kod** — ScriptableObject-tabeller:
`Cards`, `Gems`, `Relics`, `Arcanas`, `PowerUps`, `Keywords` + `GlobalKeywords`, `Effects`,
`Dungeons`, `Dialogue`, `Achievements`, `Menus`, `Common`, `Credits`.

## Innehållsvolym (nyckelrötter ur tabellerna, varianter som `_DESC`/`_BIO` avskalade)

| Tabell | Rötter | Vårt motsvarande |
|---|---|---|
Cards | 262 | 61 kort (mål 80+) |
Gems | 139 | — (gems ej byggt) |
Relics | 37 | — (ej byggt) |
Arcanas | 54 | — (ej byggt) |
Dungeons | 25 | 40 banor (200 våningar) |
PowerUps | 27 | 8 permanenta uppgraderingar |
Effects | 236 | 7 effekt-op + nyckelord |
Achievements | 418 | — |
Menus (UI-strängar) | 402 | 37 UI-strängar |

Deras **kort är Referensserien-vapnen och -figurerna** (`KNIFE`, `WHIP`, `MAGIC_WAND`,
`CHERRY_BOMB`, `BONE` + figurkort som `ANTONIO`, `AMBROJOE`) — samma IP-hållare, så det är deras
sak. För oss är slutsatsen den omvända: vårt eget namn- och motivregister är rätt väg, och det är
den enda delen av korten vi inte kan låna siffror ifrån.

Deras banor är VS-banor med numrerade varianter (`MAD_FOREST`, `MAD_FOREST_02`, `DAIRY_PLANT`,
`DAIRY_PLANT_02`, `DAIRY_PLANT_03`, `CAPPELLA_MAGNA`, `CAPPELLA_MAGNA_02`, …) — alltså färre
*bana* och fler *varianter* än våra 40 platta banor. Deras rum är **handbyggda prefabs** per biom
och relik (`RT_Relic_2x2_BraveStory` = 2×2-rutor), inte procedurgenererade som våra.

## Språkarkitekturen — det här är svaret på språkfrågan

Tolv språk: `en, fr, de, es, it, pl, pt-BR, ru, ja, ko, zh-Hans, zh-Hant`.
**Ingen skandinaviska alls** — svenska, danska och norska finns inte i referensen. Vår plan på sju
språk går alltså längre än originalet, inte efter det.

De har två lager tabeller, och det är exakt den arkitektur som behövs för Alex språkval:

1. `Cards Shared Data.asset`, `Gems Shared Data.asset`, `Menus Shared Data.asset`, … — **nycklarna**,
   språkoberoende (`MIGHT_DESC`, `NEW_GAME`, `CONTINUE`, `LOAD_GAME`, `DELETE_ALL_SAVE_DATA`, `QUIT`).
   Att deras startmeny har `NEW_GAME`/`CONTINUE`/`LOAD_GAME`/`DELETE_ALL_SAVE_DATA` är samma meny
   Alex bad om, med samma rader.
2. `Cards_en.asset`, `Cards_de.asset`, `Cards_fr.asset`, … — **värdena**, en tabell per innehållstyp
   och språk. Även *innehållet* är alltså översatt, inte bara gränssnittet.

De har dessutom en `PseudoLocale` — ett påhittat språk för att testa att allt verkligen är
översatt. Det är en billig och bra idé att stjäla som *princip*: en pseudo-svenska där varje nyckel
blir läsbar gör en oöversatt sträng självlysande i stället för tyst.

**Konsekvens för oss:** vår kortdata ska vara språkoberoende (namn och text hämtas ur en tabell per
språk via nyckel), precis som planerat i PLAN.md — nu bekräftat av hur originalet gör det, med
samma uppdelning i nycklar och värden.

## Moddar: inget stöd i bygget — laddaren kommer utifrån

Mätt i bygget: inga träffar på `BepInEx`, `MelonLoader` eller `Workshop` i metadata eller i
Addressables-katalogen. Spelet har alltså **ingen inbyggd moddladdare och ingen Workshop**. Det
stämmer med hur communityn gör: enligt `research/05-moddar.md` injicerar moddarna sin egen laddare
utifrån (**BepInEx IL2CPP** för `BetterCards`, `QoL Pack And Tools`, `BetterAutoPlay`;
**MelonLoader** + Tolk för `Lirin111/ReferensCrawlersAccessibility`). Moddarna är alltså riktiga
innehålls-/QoL-moddar, men de lever på att kapa processen — inte på någon officiell krok.

Det gör två saker tydliga för oss: (1) moddarna kan bara byggas mot ett IL2CPP-bygge av samma
version, vilket är skört, och (2) det finns ingen attityd i originalet att kopiera för "stödda
moddar" — vår plan att bygga in det bästa av dem som egna funktioner är därför ett *bättre* svar än
originalets, och `Pancake.DebugMenu` + `UImGui` i deras bygge är just den sorts krok moddare
använder när inget annat finns.

## Vad som är möjligt att gräva vidare i (inte gjort)

- **Exakta siffror** (kortens skada/kostnad, uppgraderingarnas priser, bössors HP): deras
  ScriptableObject-instanser ligger i buntarna, men IL2CPP-bygget har skalat bort typ-trädet, så
  fälten är råa bytes tills man kopplar in klasslayouten. Det kräver ett .NET-verktyg
  (Il2CppDumper) som inte finns installerat — möjligt, men ett eget pass.
- **Rumsmallarnas mått** (hur stora deras rum är, hur många rekvisita per rum): läsbart ur
  prefab-transformerna med UnityPy, och direkt användbart för vår dungeongenerator.
