# Träffläsbarhet

## Det som finns i worktreen

- [resonemang] `game/core/fx.gd`, `Fx.droppar()` skapar en `GPUParticles3D` med `one_shot = true` och `explosiveness = 1.0`: ett samlat utbrott är etablerat mönster.
- [resonemang] `game/core/combat.gd`, `_deal()` använder `_hit_plan()` för att dra av skada per mål; `preview()` använder också `_hit_plan()` och räknar träffar/multiplikator.
- [resonemang] `game/main.gd`, `_enemy_reaktion(mult)` jämför fiendens gamla och nya HP, sätter träffruta `ENEMY_HIT` (4) i 0,35 s, visar skadekvitto och returnerar bara första träffade `Sprite3D`. Döda får `ENEMY_DEAD`.
- [resonemang] `game/main.gd` spelar `hit` i andra stridsvägar och `crit` när kortets multiplikator är minst 3. Kortspelaren visar redan skade-/multiplikatortext i stridsloggen.
- [resonemang] `game/ui/fiende_material.gdshader` används av fiendens material-/glanslager, som skapas i `game/main.gd`; spelet ritar attackeffekt genom `attack_fx` i skärmkoordinater.
- [resonemang] `game/project.godot` anger 480×270 spelvy och NEAREST-filter. Tre samtidiga mål innebär att en enda returpekare från `_enemy_reaktion()` inte räcker för att rikta separat visuell reaktion till alla.

## Förslag: kort, lokal träffaccent

- [resonemang] Stapla så här: befintlig träffruta och glans först; en tydlig vit/varm silhuettblink ovanpå figuren i 50 ms; därefter kort, dämpad knuff och 1 px skak under 80 ms; små skadepixlar i 180 ms; befintligt kortsvep och CRT ligger kvar över scenen. Ingen långvarig aura eller stor skadetext ovanpå de 13 språkens UI.
- [resonemang] Vanlig träff: 2 bildrutor blink (33 ms vid 60 Hz), 2 px knuff bort från anfallaren över 80 ms och återgång över 100 ms; 1 px skak vid 0, 33, 66 ms. Krit (multiplikator ≥3): samma varaktighet, varm gul blink och 3 px knuff; skilj via färg och ljud (`crit` finns redan), inte via längre flash som döljer träffrutan.
- [resonemang] Huvudförslag är 5 partiklar per träff, `one_shot = true`, `explosiveness = 1.0`, `lifetime = 0.18`, `speed_scale = 1.0`, `amount = 5`. `ParticleProcessMaterial.gravity = Vector3(0, -5.0, 0)`, riktning uppåt, spridning 55°, `initial_velocity_min = 0.45`, `initial_velocity_max = 1.0`, `scale_min = 0.018`, `scale_max = 0.035` meter. Färg mörkröd/brun med alfa som tonas ut. Placera vid fiendens brösthöjd och ge partiklarna rörelse åt sidorna och uppåt.
- [resonemang] Med projektets `Sprite3D.pixel_size` måste meterstorlek mot skärmpixlar mätas med `-- figurprov`; 0,018–0,035 m är ett första försök på ungefär 1–3 spelpixlar, inte en verifierad omräkning. NEAREST gör små hårda fyrkanter läsbara; 5 stycken lämnar silhuetten synlig.
- [resonemang] GDScript-kärna (lägg som ny metod i `Fx` först vid implementation):

```gdscript
var p := GPUParticles3D.new()
p.one_shot = true
p.explosiveness = 1.0
p.amount = 5
p.lifetime = 0.18
p.speed_scale = 1.0
var m := ParticleProcessMaterial.new()
m.direction = Vector3(0.0, 1.0, 0.0)
m.spread = 55.0
m.gravity = Vector3(0.0, -5.0, 0.0)
m.initial_velocity_min = 0.45
m.initial_velocity_max = 1.0
m.scale_min = 0.018
m.scale_max = 0.035
p.process_material = m
```

- [resonemang] Tre fiender träffade samma bildruta: skapa ett utbrott per faktiskt skadat mål, alltså 15 partiklar totalt; samla träffdata från samma HP-plan som `_deal()` använder och spela en enda sammanfattande träffljudsignal. Separera utbrottens ursprung vid respektive fiende. Den befintliga `_enemy_reaktion()` returnerar bara första figuren, så detta kräver att reaktionsflödet lämnar ut samtliga träffade figurer/skador.
- [resonemang] Krit får inte förutsättas vara per träff: `_enemy_reaktion(mult)` tar kedjemultiplikatorn, och ett dråp får redan större skadekvitto. Håll därför kritaccenterna till `mult >= 3`; dråp kan fortsätta använda dödsrutan.
- [resonemang] Kostnaden är 5 GPU-partiklar per mål, 15 vid tre samtidiga träffar, tre små emitternoder om implementationen använder en nod per mål. Mät före/efter i samma stridsrum med `-- fpsprov`: jämför fps, sämsta bildruta, skript-/fysiktid, partikelmoln och partiklar. Använd `-- figurprov` för att granska blink, lagerordning och storlek på fiendesilhuetten. Kör mätningen med tre mål och samma upprepade träffsekvens.

## Alternativ

- [resonemang] Om nodkostnaden väger tyngre: ett enda emittermoln med 3 partiklar per målposition kan inte uttryckas med en vanlig emitternods enda position utan att mata manuella partiklar; behåll därför hellre fem per träff och ta bort emitternoden när `finished` signalerar klart. Det är enklare att förstå och budgetera än ett beständigt kontinuerligt moln.

## Motoregenskaper verifierade lokalt

- [resonemang] `godot --version` i worktreen gav `4.7.2.stable.official.ed1daf0bf`, samma som spelets angivna Godot 4.7.2-version.
- [resonemang] Jag kunde inte köra det begärda `ClassDB.class_get_property_list(...)`: Godot `--script` kräver en skriptfil, och uppdraget tillåter endast ändring av rapportfilen. Därför är nedanstående egenskapsnamn inte redovisade som verifierade genom ClassDB. `one_shot`, `explosiveness`, `amount`, `lifetime`, `speed_scale`, `process_material`, `direction`, `spread`, `gravity`, `initial_velocity_min/max`, `scale_min/max` förekommer i Godots befintliga `game/core/fx.gd` eller dess användning, men ingen påhittad motorutskrift hävdas.

## Vad jag inte kunde belägga

- [resonemang] Exakt motoregenskapslista från `ClassDB` och att samtliga föreslagna startvärden känns bäst i faktisk spelbild.
- [resonemang] Pixlar per meter vid fiendens position; kontrollera med `-- figurprov` eftersom perspektiv och `Sprite3D.pixel_size` påverkar skalan.
- [resonemang] Att 15 partiklar ger mätbar fps-skillnad; `-- fpsprov` måste köras i en reproducerbar strid. Jag körde inte testgrinden.
