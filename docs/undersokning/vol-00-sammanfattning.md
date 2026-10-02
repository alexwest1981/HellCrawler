# Volymetri i HellCrawler: dimma, rök, moln, fukt och ljus

Fem undersökningsagenter (Orca-worktrees, en fråga var) fick samma verklighetsbeskrivning och kravet att
märka varje påstående `[belagt: <url>]` eller `[resonemang]`, avsluta med `## Vad jag inte kunde belägga`
och ge ett konkret förslag per fynd. Deras rapporter ligger i `vol-01` till `vol-05`. Det här är vad de
kom fram till, och vad som sedan MÄTTES i spelet.

| Rapport | Frågan | Kärnan |
|---|---|---|
| `vol-01-dimma.md` | Hur gör man dimman till synliga strålar? | `volumetric_fog_*` egenskap för egenskap; SpotLight för riktning; skuggor skär strålar; täthet/albedo/anisotropi/längd styr hur strålen läses |
| `vol-02-rok.md` | Rök och damm som samverkar med dimman | partiklar påverkar INTE dimman; dammet ska vara skuggat per pixel så det bara syns i ljuset; ≥2 spel-px per korn annars flimmer i CRT:n |
| `vol-03-moln.md` | Moln och takdimma | `FogVolume` finns i 4.7 (box/ellipsoid/kon, densitet, kant-mjukhet) och är vägen till lokal dimbank; Sky-materialet är fel verktyg inomhus |
| `vol-04-fukt.md` | Hur känns en fängelsehåla fuktig? | våt yta styrs av råhet (koden letar redan efter låg råhet), `fukt` som nivåegenskap i bandatat, dimma i knähöjd, droppar i pauser |
| `vol-05-ljus.md` | Ljuskäglan: inbyggt mot stilenligt | nekotogd-tutorialen är en screen-space render pass utan djup (kommentarerna i inlägget säger det själva); den inbyggda vägen med SpotLight + dimma passar spelet |

## Verifierat mot motorn, inte mot en påstådd källa

Alla egenskaper och klasser rapporterna föreslår finns i spelets egen Godot 4.7.2 — kontrollerat med
`ClassDB` i en headless-körning, inte genom att tro på en webbsida:

```
volumetric_fog_{enabled,density,albedo,emission,emission_energy,gi_inject,anisotropy,length,
                 detail_spread,ambient_inject,temporal_reprojection_enabled,
                 temporal_reprojection_amount,sky_affect}   FINNS
FogVolume-klassen                                          FINNS
Light3D.light_volumetric_fog_energy                        FINNS
```

Ingen av rapporternas fil- eller funktionshänvisningar är påhittad: varje `*.gd`, varje `func()` och
varje `env.*`-egenskap de namnger greppades mot koden (filer 8/8, funktioner 11/11, egenskaper 17/17 där
de fem "saknade" är Godot-egenskaper som ännu inte används i repot).

## Vad som MÄTTES i bilden (och vad rapporten hade fel om)

Provet: `DISPLAY=:0 godot --path game --audio-driver Dummy -- shot`, samma frö, samma fönsterstorlek
(941x1030 — olika storlek gör mätningen meningslös), jämfört mot baslinjen med PIL.

1. **Rapportens råd rakt av gav en SÄMRE bild.** Densitet ×0,20 (från 0,32), `ambient_inject` 0,25 → 0,10
   och `length` 26 → 18: 58 206 px (6,0 %) ändrades, medelljus 21,5 → 20,2 — och bilden blev för mörker.
   Granskaren kunde inte se någon stråle alls. Lärdomen: tätheten är det som SPRIDER ljuset; att sänka den
   för att "få bort diset" tar bort strålen också. Bara `ambient_inject`-sänkningen behölls.
2. **Lyktan kan inte visa en kägla, hur den än ställs in.** Anisotropin (0,35) skjuter ljuset FRAMÅT, och
   en lykta som sitter i kameran skickar allt bort från betraktaren — den som tittar in i sin egen lykta
   ser ingen stråle. Det är därför strålar i spel nästan alltid kommer från ljus man tittar MOT.
3. **Facklorna är rätt källa.** `light_volumetric_fog_energy` 2,2 → 6,0 och anisotropi 0,35 → 0,60:
   38 686 px (4,0 %) ändrades, allt inom den 480x270 stora spelvyn, medelljus 21,5 → 20,4. Granskaren ser
   nu en synlig gloria av ljus i LUFTEN kring varje fackla i stället för en ensam ljus prick, och
   väggar/golv är oförändrat läsbara. Jämförelsen ligger i `docs/skarmbilder/volymetri-v3-fackelgloria.png`
   (och det för mörka första försöket i `volymetri-v1-for-mork.png`).

Behållet i koden: lyktan är en `SpotLight3D` med 68° kägla (en riktning i stället för ett klot),
`ambient_inject` 0,10 (luften grånar inte där inget ljus går), facklornas luftglöd 6,0, anisotropi 0,60,
och dammet skuggas per pixel utan emission så det bara syns där ljuset träffar det.

## Kvar att bygga (med belägg i rapporterna)

- **Lokal dimbank med `FogVolume`** (vol-03, vol-04): en låg dimma i knähöjd som bara finns där nivån
  säger det. Kräver ett nytt fält i bandatat (`tools/gen_stages.py` + `data/stages/*.json`).
- **Skuggor på ett urval facklor** (vol-01): en fackla med `shadow_enabled` låter väggkanter och pelare
  skära mörka former genom dimman, vilket är det som gör ljuset till STRÅLAR. Kostar bildrutor per aktivt
  skuggande ljus — mät en fackla i taget.
- **`fukt` som nivåegenskap** (vol-04) och `fog_sky_affect`/temporal reprojection (vol-05 punkt 3): båda
  är mätbara men rör nivådata respektive rörelse, och hör till egna skivor.

## Vad jag inte kunde belägga

- Att den stilenliga screen-space-tekniken från nekotogd-tutorialen skulle vara bättre än den inbyggda
  vägen i 480x270. Tutorialen är Godot 3 och en render pass utan djup; att porta den är ett eget arbete med
  egen mätning, och ingenting i rapporterna visar att den skulle slå SpotLight + dimma här.
- Hur mycket fackelskuggorna kostar i bildrutor på den här maskinen (RTX 3060 Ti, 480x270): inte mätt.
- Om `FogVolume` kostar något mätbart vid den här upplösningen: inte mätt, bara belagt att klassen finns.
