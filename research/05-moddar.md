# 05 — Community-moddar till Referensspelet

**Hämtat 2026-09-19.** Källor: Thunderstore publika API + paketsidornas HTML, Nexus Mods modsidor (game id 9148) och `next.nexusmods.com/games/…`-snapshot, GitHub REST + raw README, poncles egna patchnoter (v1.5, 23 juni 2026). Inga SEO-listartiklar eller LLM-svar.

## 1. Rankning (mätta siffror)

### Nexus Mods — spelets huvudscen

| Mod | Endorse. | Total DLs | Unique | Uppdaterad | Av |
|-----|---------:|----------:|-------:|-----------|-----|
| **BetterCards** | 17 | 652 | 449 | 2026-07-12 | TovaK66 |
| **QoL Pack And Tools** | 17 | 852 (960*) | 656 | 2026-05-06 | liwenhao0427 |
| **BetterAutoPlay** | 15 | 572 | 412 | 2026-05-23 | CriticalRange |
| **Deck Balance Viewer** | 3 | 133 | 113 | 2026-05-04 | Fenrir2006 |
| **Enemy Health Display** | 2 | 133 | 125 | 2026-06-03 | RoyalBae |
| **Auto Card Sort** | 2 | 127* | — | 2026-06-03 | RoyalBae |
| **SVCU** | 2 | 101* | — | 2026-05-30 | vatch |
| **Referensspelet Mod Thai** | 1 | 90 | 76 | 2026-05-15 | Yo090 |
| Trainer | — | — | — | — | NyanDoggo |
| Unlocks Everything | — | — | — | — | NyanDoggo |

Källa: `nexusmods.com/referenscrawlerstheturbowildcardfromreferenssurvivors/mods/{1,2,3,5,6,7,8,9,10,11}`. Mod-id 1–11 är publicerade (4 opublicerad, 12+ finns ej). `*` = från `next.nexusmods.com/games/referenscrawlerstheturbowildcardfromreferenssurvivors` samma dag. Nexus döljer DLs under en tröskel → Trainer/Unlocks Everything saknar mätbara tal och rangordnas därför inte.

### Thunderstore (`thunderstore.io/c/referensspelet/`) — endast 4 paket

| Paket | Nedladdningar | Likes | Uppdaterad |
|-------|--------------:|------:|-----------|
| ebkr/r2modman (manager, alla spel) | 10,5 M | 1,4 K | 2026-08-21 |
| BepInEx/BepInExPack_IL2CPP (loader, alla IL2CPP-spel) | 827,2 K | 39 | 2026-03-23 |
| **TovaK/BetterCards** (samma som Nexus #1) | **1,1 K** | 0 | 2026-07-12 |
| **Statsly/RunsHistory** — automatisk run-statistik | **204** | 0 | 2026-06-24 |

### GitHub (★ mätta 2026-09-19)

17★ `ZTMYO/ReferensCrawlersMods` (fiende-HP + sortering + MoreInfo) · 7★ `wtksana/vcmod` (sorteringsknapp, autoplay-filter, break-räknare) · 4★ `TovaK66/BetterCards` · 2★ `CriticalRange/BetterAutoPlay`, `liwenhao0427/ReferensCrawlersMods`, `Ucat233/Referensspelet-mods` (ComboClickMod) · 1★ `C330only/ReferensCrawlersCardSorter`, `damianharouff/referensspelet-coins` · 0★ `AnLifeX/…` (EvoTrackerMod), `jwd83/…DeckCurveViewer`, `Lirin111` och `Jericho-Dread` (skärmläsare), `QuantumBoIt/FarmBot`, `johann…/card-grouper`, `Lawgikill/…`, `unkvolism/…SaveEditor`, `EvanJ585/…mana-counter`.

## 2. Vad varje mod gör

**BetterAutoPlay.** Byter ut sorteringsordningen base-spelets autospel använder. Kort klassas i fem tiers: **0 mana-generator** (Empty Tome), **1 utility** (Candles, stat-buffs), **2 crawler** (FCC-companion), **3 attack** (Whip, Runetracer), **4 okänt**. Algoritm: (a) startkort = kort som fortsätter befintlig combo, annars högsta prioritet; (b) välj nästa kort som *bibehåller* mana-kostnaden, sen kort som **ökar** den (mana-generatorer prioriteras inom steget), sist kort som sänker; (c) resten sorteras role → mana gain → mana cost → evolved. Slår automatiskt på spelets Combo-sorteringsläge. MIT.

**BetterCards** (12 språk). **Badges vid level-up:** EVO (kromatisk medalj) när valet fullbordar en evolution-combo du saknar; EVO *bis* (silver + grön ✓) när combon redan täcks; NEW (regnbågspill) när du äger noll exemplar; ×N (guldspill) med exakt antal ägda kopior. **Card Lock:** högerklick, `.` eller numpad-Del på ett kort (hand/draw/discard) → gyllene hänglås ersätter mana-orbet och spelet behandlar kortet som oaffärbart: klick/drag/space ger spelets egna "can't afford"-skak + ljud. Auto-skip: om alla kort är låsta/oaffärbara avslutas turen **om** spelets "End turn automatically" är på. Lås persisterar per-kort via GUID i `BepInEx/config/BetterCards.locks.txt`; två kopior spåras separat.

**QoL Pack And Tools** (Windows x64, inbäddad BepInEx + `Install and Launch.bat`). Plugins: `EnemyHealthOverlay` (fiende-HP + front-row-target-info, dragbar), `DpsOverlay` (turens skada, totalskada, stridsstatistik), `DevConsole` (`~`: lägg till gems, kort, välj events), `ImageReplacer` (PNG med Unity Sprite-namn i `…/ReferensCrawlers.ImageReplacer/images/` byter kort-/gembilder). QoL: **kostnadsfilter** (siffertangenter filtrerar kort på kostnad, inkl. negativa), **auto-select** efter spelat kort, **combo-aware play-all**, **kvarvarande spelturer på break-kort**, **hand-sortering** (mushjul, Q/E, LT/RT), BetterCards-badges inbakade. v2026.05.6.

**SVCU.** DPS Overlay, Enemy HP Overlay, Combat Tracker, Combo Badges (combo-milstolpar), Break Countdown (timer för shield/break-fas), XP Overlay, Hand Tools, Dev Console (`~`). **Inkompatibel med QoL Pack And Tools** — båda patchar samma system.

**Enemy Health Display.** Små **hjärtikoner ovanför fiender** som töms visuellt vid skada. Medvetet **inga exakta HP-siffror**. Hjärtstilen matchar spelets spelar-HP-UI. Ändrar inte stats/saves.

**Auto Card Sort.** Inhemsk-lookande **sorteringsknapp** + **deck-composition-overlay** på Deck Pile- och Level Up-skärmen. v1.0.1 inkluderar kort i hand i level-up-kostnadsräkningen och lade overlayn även på card-sacrifice-skärmar.

**ZTMYO:s tre plugins.** `ShowEnemyHpMod`: **total HP för alla fiender + procent** högst upp i stridsvyn, mjuk bar-animation, kort fördröjning efter träff, Harmony-patch (ingen per-frame-scenesökning). `SortCardMod`: mushjul ned/upp = stigande/fallande, RT/LT = samma; debounce; avstängd vid Esc/paus/inställningar; `free`-kort sorteras på **face value**. `MoreInfoMod`: "combo-able mana", och **kvarvarande spelturer på sprucket kort** vid hover.

**wtksana/vcmod** (7★). "整理手牌"-**knapp i stridsvyn** (vänsterklick sorterar, höger-drag flyttar + sparar position). Auto-sortering efter drag med konfigurerbar fördröjning och 1,5 s suppression efter spelat kort. Regler: kostnad upp/ner, **wildcards längst vänster eller höger**, samma kostnad → namn, "gratis denna tur"-kort på **ursprungligt combo-face-value** (inte 0). Autoplay-filter: bara wildcards, **hoppa över kort med 1 break kvar**, prioritet temporary → destroy → uncracked → mana → attack → övriga. Break-countdown i korttexten. Tekniknot: spelet kör nya Input System — moddar får inte anropa `UnityEngine.Input`; `MonoBehaviour` måste registreras via `ClassInjector.RegisterTypeInIl2Cpp<T>()`.

**ComboClickMod.** Högerklick i strid spelar automatiskt **combo-bara** kort; `` ` `` växlar läge. "Combo": bara highlightade combo-kort (normala först, wildcards sen). "Full auto": föredrar combo-bara, annars **lägsta kostnad**. Auto-hoppar över consumption/destroy-kort. Lägesikon nere till vänster.

**EvoTrackerMod.** Panel som skannar **alla evolutionsrecept** (2, 3+ komponenter) och visar insamlingsstatus + antal ägda delar; klara recept gulmarkeras och förblir klara efter konsumtion. Kortmarkering vid level-up: **★ 需要** (röd = del saknas), **✓ 已有(xN)** (grön), **★ 已进化(xN)** (guld). Recept-favoriter via högerklick (rad = hela receptet, ingrediensrad = en del); markerade kort får lila highlight + `[!]`. F8 togglar; panelen sänker opaciteten när musen lämnar den.

**Deck Balance Viewer.** Overlay med **realtids-mana-kurva** (bas-kostnader), **totalt antal kort i rotationen** (draw+hand+discard), "Details" expanderar till full kortlista med antal, dragbart fönster. Toggle **F9**. v1.2 stödjer negativa mana-kort.

**ReferensCrawlersCardSorter.** Auto-sorterar synlig hand **stigande** på kostnad; `X`/special efter numeriska; stabil inom samma kostnad; behåller spelets kortavstånd (ingen stapel); väntar ~0,9 s efter draw-animation; rensar stale hover-offset. Config: `SortIntervalSeconds 0.35`, `SortAfterHandChangeDelaySeconds 0.9`, `SortOnlyWhenUnlocked`, `SkipWhileInteracting`, `ResetSelectionWhenSorting`.

**Lirin111/ReferensCrawlersAccessibility** (MelonLoader + Tolk → NVDA/SAPI, "feature-complete and tested"). Läser **varje menyalternativ** (namn: värde; toggles on/off, sliders i procent; keybinding-rader "action: keyboard / controller"). Strid: kort-hover (namn, färg, kostnad, beskrivning), skada given/tagen, HP/armor/mana, **enemy intents**, fiendestats, victory. Utforskning: **spatiala stereo-cues** som panoreras/pitchas med riktning och avstånd för fiender, bossar, kistor, mynt, mana, reliker, evolution tables, kort, höns, golvutgången, förstörbara objekt, events och **gömda karaktärs-kistor**. Info-tangenter: status, kompassriktning och **tur-för-tur-väg till närmaste** outforskade ruta/förstörbara/pickup/utgång. **Audio Cues Glossary** i Settings → Sound med sparad per-cue-volym. 12 språk.

**Jericho-Dread/ReferensCrawlersAccessibility** (BepInEx + NVDA Controller Client, v0.1.14). Tal för fokuserade menyer, kort, rewards, gems, shops, town buildings, dialoger, transienta pickups. Kortbeskrivning i ordningen **namn, kostnad, effekt, keyword-betydelser**. On-demand HUD: health, gold, mana, level+XP, modifiers. Dungeon: position, riktning, öppna utgångar, aktuell ruta, kvarvarande events, encounters, förstörbara, pickups, kistor, reliker. Hotkeys `Ctrl+F1..F10`, `- = [ ] . /`; handkontroll L3/R3 + båda triggers + D-pad. Kända brister: **ingen kart-pathfinding, ingen kollisionsmedveten rörelse**, ingen kontinuerlig miljövägledning.

**FarmBot.** 22-stegs loop: världskarta → välj värld (Dairy Plant) → stage (Curdling Factory) → dungeon-nuke → lös level-up-prompter → läs minimap → gå till treasure-markers → öppna kistor → cash-out → gå till exit → nästa våning → avsluta via pausmenyn → bekräfta dialoger → town → nästa run.

**Card-grouper** (johann…). Vid tröskel (default 20 kort) visas en stabil gruppbar `0/3  1/7  2/5 … W/4` per numerisk kostnad; tomma grupper visas (`4/0`), `W` alltid synlig, aktiv grupp följer spelets aktuella combo-/aritmetikmål. Plus export/utbyte av kortbilder.

**Save-editorer.** `unkvolism` (Rust): sätter `TotalCoins` i både `ProfileSaveData` och `ProgressionSaveData`, låser upp karaktärer på kortnamn. `damianharouff` (Python) dokumenterar **checksumman**: `base64(sha1(utf8(reindent(Data) med CRLF)))`, tidsstämplad backup.

**Companions/cheats.** `EvanJ585`: browser-verktyg; mana-buckets 0–5, wildcards mot mjukt mål **12 % av leken, max 6**, vikter 0–4 = **26/24/22/18/10**. `Lawgikill`: andra-skärms-tracker som läser save-filen och följer `HandPile`/`DrawPile`/`DiscardPile`/`ComboPile` via `cardPileId` — **avslöjar att högarna serialiseras läsbart**. `Trainer` (F1), `Unlocks Everything` (Insert → `U` ×2 upplåser, `R` återställer), `Mod Thai`, `Statsly/RunsHistory` (run-statistik).

## 3. Vad som bör vara standard i vår klon

1. **Handsortering som förstklassigt view-state** — unsorted / kostnad upp / ner / färg, behåll kortidentitet och selektion vid omsortering, sortera **efter** draw-animationen, ~1 s suppression efter spelat kort. `free`-kort på ursprungligt face-value (vcmod visar varför).
2. **Fiende-HP direkt i UI** — den största kvarvarande luckan (§4). Bygg både per-fiende-indikator och aggregerad "total HP + %"-rad, och gör siffran tillgänglig; moddarna *döljer* exakt HP av stilskäl, vi kan äga båda via en inställning.
3. **Autospel som faktisk combo-solver** — tiersystemet ovan är en fungerande spec. Lägg till vcmods säkerhetsnät: spela **aldrig** ett kort med 1 break kvar, aldrig destroy-kort automatiskt, och ge uttryckliga regler ("endast wildcards", "hoppa över break-kort") i stället för en odokumenterad heuristik.
4. **Tillgänglighet som arkitektur** — bygg en **event-buss för spelläge** från början: varje state-ändring (drag, skada, pickup, turstart) emitterar ett strukturerat event som UI, ljudcues och skärmläsare konsumerar. Spatiala ljudcues är billiga då, nära omöjliga att eftermontera.
5. **Kortets kvarvarande spelturer synligt på kortet** — break-mekaniken är central och base-spelet döljer räkningen (tre oberoende moddar lägger till den).
6. **Combo-/evolutions-assistans i level-up-vyn** — EVO / EVO-bis / NEW / ×N är fyra distinkta testbara tillstånd. Gör recepten till **data**, inte hårdkodad logik.
7. **Deck-overlay med antal per kostnad** — mana-kurva + kortantal per bucket finns fortfarande inte (§4).
8. **Kortlås mot misstag** — återanvänd spelets egna "kan inte betala"-feedback (skak + ljud) i stället för en ny felsignal; det är hela poängen.
9. **Run-historik/statistik** — billigt om varje run redan loggas strukturerat.

**Problem vi slipper:** all ren sorterings- och deck-view-funktionalitet (Auto Card Sort, CardSorter, delar av vcmod, Deck Balance/Curve Viewer) är svar på att spelet **saknade** dem vid launch och fick dem i v1.5 — bygg sortering, deck view och break-räkning som kärnfunktioner. Dev Console, Image Replacer, FarmBot och save-editorerna finns för att spelet inte exponerar konsol, bilder eller save-data: **debug-verktyg, inte features**.

## 4. Vad moddarna avslöjar om spelets egna begränsningar

**Finns redan inbyggt:**

- **Autospel — ja.** Base-spelet har **"Play All"**. Den är en *trigger*, inte en solver: Steam-spelare beskriver "It plays all cards in your hand going from right to left, skipping cards it can't play"; den bygger inte om handen till 0→1→2→3, tar ingen hänsyn till wildcards, "can't actually play all when draw effects are present", och **fortsätter spela även om kort spricker** ("turns out it *does* continue and breaks everything"). **Exakt det hål BetterAutoPlay, ComboClickMod och vcmod täpper.**
- **"End turn automatically"-inställning** finns (BetterCards refererar den som villkor för auto-skip).
- **Kortsortering och enhetlig deck view kom i v1.5 (23 juni 2026)** — poncles egen QOL-patch: sortering på **Mana-kostnad eller Färg** (upp/ner flyttar markeringen till nästa kategori) samt en deck view som visar alla kort och vilken hög de ligger i. Före det var detta rena mod-territorium (Steam-tråden "Auto-sort cards by mana cost?" 11 maj 2026 fick svaret att sortering var planerad).
- Kontrollstöd, nytt Input System, Endless Mode (v1.5).

**Saknas fortfarande — och är därför moddar byggs:**

- **Fiende-HP visas inte alls.** Reddit-tråden "Fixes & Suggestions Feedback" säger rakt ut: *"Encounters should have some form of health indicator. Having cards specify their amount of damage serves little purpose if you have no idea how much health a target has."* Tre moddar (Enemy Health Display, ZTMYO ShowEnemyHp, QoL Packs EnemyHealthOverlay) svarar på samma lucka och konkurrerar om samma UI-yta (SVCU är uttryckligen inkompatibel med QoL Pack).
- **Break-/crack-räkning per kort** visas inte. **Combo-bar mana / vilka kort som kan comboas** visas inte. **Antal ägda kopior i level-up-vyn** visas inte. **Varning innan autospel förstör kort** finns inte.
- **Ingen komplett kart-pathfinding eller miljövägledning** för blinda spelare.
- **Ingen dev-konsol, ingen bildutbytes-pipeline, ingen läsbar statistik-historik.**

## OSÄKERT

- **Nexus-siffrorna är ett ögonblick.** Modsidorna och `next.nexusmods.com` skiljer sig samma dag (QoL Pack 852 vs 960 DLs; Auto Card Sort 0/"--" på modsidan men 2/127 på game-sidan). Trainer och Unlocks Everything har **inga mätbara tal** → listade, ej rangordnade.
- **Endorsements/Downloads är inte jämförbara mellan plattformar.** Nexus kräver konto, Thunderstore inte. Nexus-talen är ett *golv* för faktisk användning.
- **Thunderstores tal för r2modman/BepInExPack är globala** aggregat (131 resp. 529 dependants), inte spelspecifika. Endast BetterCards (1,1 K) och RunsHistory (204) är meningsfulla.
- **Ingen API:lista gav hela Nexus-inventariet.** Jag enumererade mod-id 1–17 manuellt; 1–11 finns (4 opublicerad), 12+ "Not found". **10 publicerade** — moddar utanför det spannet har jag missat.
- **SVCU:s och Auto Card Sorts DLs** kommer enbart från game-sidans snapshot (101 resp. 127).
- **GitHub-★ är inte användning.** Lirin111 har 0★ men beskrivs som "feature-complete and tested". ZTMYO har 17★ men finns **inte** på Nexus/Thunderstore → faktisk räckvidd okänd.
- **Ingen mod har körts.** Funktionsbeskrivningarna är författarnas egna README/Nexus-påståenden. BetterAutoPlay-tierordningen och `Play All`-beteendet är dubbelkollade mot både repo och Steam-diskussion; övriga detaljer vilar på en källa var.
- **r/referenscrawlers och Steams forum är bara lästa via sökresultat** (`web_extract` på Steam-tråden gav mest navigeringsskal), så moddar som bara nämns där utanför GitHub/Nexus/Thunderstore har jag inte fångat.
- **v1.5-datumet har två versioner i källorna:** poncles Steam-inlägg och SteamDB anger **23 juni 2026** (build 23803422); Wikipedia och playday refererar ett inlägg daterat 14 juli. Jag har använt 23 juni.
