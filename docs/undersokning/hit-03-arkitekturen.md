# Träffeffekt: pixlar från fienden

## Hook och ansvar

- [belagt: res://game/core/combat.gd#L422] `_deal()` drar av HP och registrerar dödsfall; [belagt: res://game/core/combat.gd#L317] `preview()` räknar bara, utan att ändra striden. Effekten hör därför efter spelad skada, inte i förhandsvisningen.
- [belagt: res://game/main.gd#L4429] Huvudhook: `main.gd::_enemy_reaktion(mult)` (rad 4429). När `hp < förra` vet den träffad `spr` och skadan; den hanterar redan både levande träff och död och returnerar första träffade figuren.
- [belagt: res://game/main.gd#L8515] `_on_card()` anropar `_enemy_reaktion()` efter `active_combat.play()` och skickar sedan samma figur till `_attack_fx()`. [resonemang] Lägg droppskuren där inne i grenen för minskad HP, så varje skadad fiende får sin skur; en enstaka placering efter retur skulle missa träffar på flera fiender.
- [belagt: res://game/core/fx.gd#L429] Återanvänd `Fx.droppar(förälder, pos, fall, slag)` som form: den skapar en engångsskur med `GPUParticles3D`, `one_shot`, `amount`, `lifetime`, `draw_pass_1` och `ParticleProcessMaterial`. [belagt: res://game/core/fx.gd#L119] `Fx.prick()` ger en 32×32 radiell GradientTexture2D; [belagt: res://game/core/fx.gd#L179] `Fx._yta()` ger billboard-material med vertexfärg. Båda passar som kodskapad pixelkärna utan ny bildfil.
- [resonemang] Bygg små kantiga fragment med `QuadMesh` och pixelstor textur, `BaseMaterial3D.TEXTURE_FILTER_NEAREST` och `BLEND_MODE_MIX`; `Fx._yta()` accepterar redan filterargument men sätter själv billboard och `prick()` som textur. En separat träffyta behöver därför bygga vidare på dessa delar om skarpa pixlar är målet. Blodrött kan färga processmaterialets `color`/`color_ramp`.

## Konkret startvärde

```gdscript
# Förslag, inte befintlig hjälpfunktion: anropas i hp-minskningsgrenen i _enemy_reaktion.
var p := Fx.droppar(world, spr.global_position + Vector3(0, 0.30, 0), 0.22, "blod")
p.amount = 8
p.lifetime = 0.28
var m := p.process_material as ParticleProcessMaterial
m.direction = Vector3(0, 1, 0)
m.spread = 160.0
m.initial_velocity_min = 0.45
m.initial_velocity_max = 1.05
m.gravity = Vector3(0, -3.0, 0)
m.scale_min = 0.45
m.scale_max = 0.8
```

- [resonemang] `Fx.droppar()` är källans källa för materialets egenskaper, livstid, hastighet och gravitation; ovan skrivs de föreslagna värdena efter skapandet eftersom dess befintliga droppar är fallande droppar, inte en radiell träffskur. `amount = 8` betyder åtta fragment per skadat mål; `0.28 s` håller effekten kort och `0.45–0.8 m/s` med nedåtriktad gravitation ger synligt men litet utslag.
- [resonemang] Fiendernas sprites använder `pixel_size = 0.012` (boss `0.013`) i `main.gd` rad 4032. Vid `0.012 m/dukpixel` blir quadens `0.06–0.096 m` ungefär 5–8 fiendepixlar. Kamerans perspektiv avgör skärmpixlarna, så fintrimma i bildprov vid spelvyn 480×270; `0.45–0.8 m` är här ett projekterat fragmentmått, inte garanterade skärmpixlar.
- [resonemang] Pool vid tre träffar i samma bildruta: behåll tre återanvändbara `GPUParticles3D`-noder och välj ledig nod per anrop; om alla är upptagna, återstarta den äldsta. Varje instans har 8 platser, alltså 24 aktiva platser vid tre slag. Skapa poolen vid start/rumsskapande; ge varje nod ny position och `restart()`. `Fx.droppar()` skapar en nod varje gång, så direkt användning utan pool lämnar en kortlivad nod per slag.

## Ljud, kuvaus ja moottorivarmistus

- [belagt: res://game/main.gd#L8515] `_on_card()` spelar i dag `_sfx("crit" if r.multiplier >= 3 else "card")`; [belagt: res://game/main.gd#L8353] och [belagt: res://game/main.gd#L3754] finns `_sfx("hit")` på andra händelsevägar. [resonemang] Lägg eventuell ny träffaccent vid samma HP-minskningsgren som partiklarna, alternativt behåll kortljudet där det är och prova mixen; låt inte varje partikel spela ett eget ljud. Ett dödsträffsljud kan också hamna där med `hp <= 0`.
- [belagt: res://game/main.gd#L5632] `-- figurprov` kör `_figurprov()` och sparar `user://shots/figurprov.png`; [belagt: res://game/main.gd#L945] `-- fpsprov` mäter bildrutor och räknar `GPUParticles3D.amount`. [resonemang] Figurprovet fotograferar fienden, inte en träffanimering: lägg till/återanvänd ett träffbildprov som spelar ett slag, väntar cirka 0,1 s och sparar via `_spara_bild()` medan fragmenten syns. Kör därefter fpsprov med effekten på och jämför partikelantal/bildtid.
- [belagt: res://game/project.godot] Installerad motor: `4.7.2.stable.official.ed1daf0bf`. [resonemang] Försöket att anropa Godot med ett tillfälligt GDScript genom process-substitution och `--script -` misslyckades eftersom Godot behandlade sökvägen som en resursfil; jag skapade ingen extrafil. Därför kunde jag inte köra den begärda `ClassDB.class_get_property_list()`-dumpen. Propertynamnen i förslagskoden är de som `fx.gd` själv använder för `ParticleProcessMaterial`, men de är inte verifierade med ClassDB i denna undersökning.

## Vad jag inte kunde belägga

- [resonemang] Jag kunde inte verifiera egenskapslistorna genom motorns ClassDB, så förslagskodens propertynamn måste bekräftas innan implementation.
- [resonemang] Jag kunde inte mäta fragmentens faktiska skärmpixelstorlek eller fpskostnad för en träff; det kräver en bild av träffen och en körning av `-- fpsprov` med effekten inkopplad.
