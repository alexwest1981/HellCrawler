# Grafiken: vad som mättes och vad som byggdes (19–20/10)

Frågan var "HD-upplevelsen" — kvalitet på grafiken i **hela** spelet, inte bara en vy. Allt nedan är
mätt på skärmbilder i 1920×1080 tagna med `--rendering-driver opengl3` mot Xvfb, och jämförelserna är
gjorda på **samma vy i samma ögonblick** (två körningar med olika väntetid gav 2× skillnad i ljusstyrka
och alltså ingenting att jämföra — det misstaget gjordes först).

## 1. Supersampling: den enda ändringen som gav mätbar skärpa

`SSAA = 1,5`: vyn ritas 1,5× större än fönstret (`_vy.size = fönster × 1,5`) och skalas ned linjärt av
korgen. HUD:en följer med (`hud.transform` skalas `skala × 1,5`), så text, kort och paneler ritas i
samma högre upplösning — det är därför det gäller hela spelet och inte bara 3D:n.

| Mått (samma vy) | SSAA av | SSAA 1,5 | Ändring |
|---|---|---|---|
| Kantstyrka (medel av FIND_EDGES) | 26,43 | 20,23 | **−23 %** |
| Högfrekvent brus (avvikelse mot 1,4 px Gauss) | 15,24 | 12,97 | **−15 %** |
| Medelljus | 13,08 | 11,84 | −9 % |
| Bildtid (120 bildrutor) | 41,93 ms | 42,69 ms | +0,8 ms |

Kostnaden är alltså under 1 ms i den här scenen, och trappan på varje blockkant försvinner. Vid 1,0 ser
blockkanter och texturpixlar ut som en trappa; vid 1,5 är de mjuka utan att pixelkonsten tappar form.

## 2. MSAA: mätt, och det gör nästan ingenting

`_vy.msaa_3d = MSAA_4X` är på. Mätt mot MSAA av: **0,08 % av pixlarna ändras**, kantstyrkan 26,09 mot
26,06. Skälet är att rummet nästan bara består av plana ytor som fyller rutan — MSAA rätar ut
geometrikanter, och det finns knappt några. Den får vara kvar (den kostar inget), men den är inte
förklaringen till att bilden såg kantig ut.

## 3. Linjär filtrering med mipmaps: försökte, mätte, förkastade

Texturerna är 256 px och ritas ~128 px, alltså nedskalas de, och NEAREST hoppar över varannan pixel.
Teorin var att linjärt + mipmaps skulle lugna texturen. Mätt blev det motsatta:

| Mått | NEAREST | LINJÄRT + mipmaps |
|---|---|---|
| Medelljus | 12,22 | 24,67 (**2×**) |
| Kantstyrka | 24,95 | 49,09 |
| Högfrekvent brus | 14,89 | 25,61 |

Förklaringen: normal- och ORM-kartorna filtreras också. När normalerna medelvärdesbildas pekar de rakt
upp, ytan blir platt och ljuset faller på den som på en planskiva — bilden blir dubbelt så ljus och
dubbelt så brusig, och stenen tappar sin relief. Alltså: **albedon skulle kunna filtreras linjärt, men
normalen får aldrig göra det**. Flaggan `filter=1` finns kvar i koden för den som vill prova.

Mipmaps slogs på för de 519 ruttexturerna under försöket och slogs **av igen** när filtret förkastades
(33 % extra texturminne för ingenting när NEAREST används).

## 4. Det som INTE är löst

* **Texturen är brusig i sig.** Granskningen säger "slumpmässigt visuellt brus, inte sten". Det är
  konstens innehåll (256 px pixelkonst med hög frekvens), inte filtreringen. Att få stenen att läsa som
  sten kräver ny texturkonst: färre, större former, riktning i slaggan, kantdetaljer — inte mer
  upplösning.
* **Ljuset är platt i botten.** Mätt medelljus 12–24 av 255: rummet är nästan svart utanför lyktan, och
  där lyktan träffar finns ingen kontakt­skugga mellan blocken som ger djup. SSAO finns på
  (`intensity 1,8`), men rummet har för lite ljus för att skuggan ska synas.
* **Rekvisitan är reliefer.** Se `12-interior-och-objekt.md`: våra tunnor och bokhyllor är bilder med
  djup, inte modellerade objekt. Det syns så fort kameran inte står rakt framför.

## 5. Nästa tre, i ordning

1. **Ny stenkonst per tema** (störst effekt): färre former, riktning i slaggan, en mörk fog mellan
   blocken. `tools/gen_tiles_alex.py` är generatorn; 315 rutor.
2. **Kontaktmörker i fogarna**: en mörk kant i albedon (finns som `_kant_dämpad`) ska vara mörkare i
   fogen och ljusare på plattan, så blocken läses som block även i svagt ljus.
3. **Modellerad rekvisita** för de mest sedda objekten (tunna, kista, ljusstake), resten som i dag.
