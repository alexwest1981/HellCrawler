# 00 — Egna mätningar på officiella skärmbilder (Steam, app 3265700)

Källa: Steam Store-appdetails-API (`https://store.steampowered.com/api/appdetails?appids=3265700&l=english`),
hämtat 2026-09-19. Bilderna i `screenshots/` är poncles egna marknadsföringsbilder, nedladdade
enbart för analys — de får **inte** återanvändas i en egen klon (upphovsrätt).

## Vad bilderna bevisar (mätt, inte resonerat)

### Rendering / perspektiv
- Det är **äkta 3D-geometri med pixelart-texturer** — inte en raycaster och inte platta bilder.
  Golv och väggar ligger i perspektiv och skalan stämmer mellan våning och vägg (biblioteksscenen:
  bokhyllor, röda mattor, tända lyktor på hyllor).
- Fiender och dekor är **billboard-sprites** som skalar med avståndet (fladdermusen i förgrunden är
  stor och har en ritad skugga under sig; träd/staket/hus krymper mot horisonten i utomhusscenen).
- Marknadsbilderna är renderade i 1920×1080, men pixelstorleken i sprites och pixel-fonten motsvarar
  en intern upplösning runt **320×180–640×360** som skalas upp. Spelytan ligger dessutom i en ram
  (mörk argyle-bakgrund i kanterna) — dvs. spelet renderar en lågupplöst viewport centrerad i fönstret.

### HUD (layouten är identisk mellan bilderna)
- Överst: XP-bar med `Lv N`, samt resursräknare (skalle, mynt) och pausknapp.
- Statistik-panel som i Referensserien: ikoner med **procentvärden** (mätta exempel: 75 %, 60 %,
  38 %, 50 %, 120 %, 185 %, 92 %, 115 %) — alltså Might-/Area-/Luck-/Greed-/Growth-/Curse-liknande stats.
- Nere till vänster: hjärta med HP (`50/50`, `56`, `5.5/5.5`) + sköld med armor (`5`, `6`).
- Nere till höger: **blå mana-orb med siffra** (`2`, `7`, `10`, `12`) och knappen `End Turn`.
- Nere till vänster/mitten: knappen **`Play All`** → autospel finns inbyggt i spelet (bekräftas av
  modden "BetterAutoPlay" som gör just den knappen smartare).
- Vänsterkant: tre staplar — **draw / discard / exile** (mätta tal: 3 / 3 / 13; 3 / 6 / 0).

### Kortstrid (mätt från kortens egen text)
- Varje kort: namn, **kostnad i blå cirkel** (mätta kostnader: 0, 1, 2, 3 **och 8**) samt effekttext.
- Nyckelord som syns i bild: `Wild.`, `Destroy.`, `FREE` (banderoll med blixt), `Cost+`, `Evolved.`,
  `Crawler`, `Copy`, `Return`, `Knockback`, `Area 2x`, raritetsbokstav (`U`).
- Exempel på effekttext: `Deal 50 damage.` · `Deal 43 damage to multiple enemies with 20% Knockback chance.`
  · `Add 2 Armor.` · `Heal 1 HP. Destroy. Wild.` · `Add 4 Mana. Destroy. Wild.` · `Increase Hand by 1. (2 Duration) Crawler`
  · `Deal 12 damage to 5 enemies. Knockback. Area 2x.` · `Deal 39 damage. Cost+.`
- **Combo-multiplikatorn visas som ett hexagonalt märke PÅ det valda kortet**, med texten
  `COMBO MULTIPLIER` runt om och ett tal i mitten (mätta värden i olika bilder: **1, 3 och 40**).
- Överdrift firas: popup-texten **`ULTRA MAXIMUM OVERKILL`** med guldbelopp (`$5000`).
- Stora tal skrivs med punkt som tusentalsavgränsare: `Deal 2.048 damage` (= 2048).

### Fiender och rum
- Fiender står i grupp som sprites i scenen (fyra lila magiker i rad; en mekanisk arm som boss;
  en spöklik varelse). En av fienderna markeras med röd skalle = valt mål.
- Fiendens HP-bar ligger överst i mitten med fiendens egen nivå (`Lv 16`, `Lv 21`).
- Rummen är inredda per tema (bibliotek, utomhusväg mot by) — temat följer Referensserien banor.

## Vad jag INTE kunde mäta här
- Exakta multiplikatorformler. Wikins Combosida säger: "For an X-combo, the effect is equivalent to
  playing the card X additional times repeatedly" (källa: `sources/Crawlers:Combo.md`). Det motsäger
  de fan-sidor som påstår ×2/×3/×4/×5 per steg — se OSÄKERT i huvudrapporten.
- Om kartan har fog of war (recensenter säger nej; ingen egen mätning möjlig utan speltid).
- Rutnätets storlek, antal våningar per dungeon, körningslängd i minuter.
