# Träff: fallande fiendepixlar

- [resonemang] Målbilden passar en kort engångsskur vid fiendens position: små kantiga bitar skjuts lite utåt och faller, medan befintlig hit-animation, ljud och 2D-svep får fortsätta.
- [belagt: `game/core/fx.gd`, `Fx.droppar()` och `Fx._moln()`] Spelet bygger redan en `GPUParticles3D`-nod med quadmesh, material, `one_shot`, `explosiveness` och `ParticleProcessMaterial`; `droppar()` ger enstaka fallet och `local_coords = false` låter dem stanna i världen.
- [belagt: `game/core/combat.gd`, `_deal()`/`_hit_plan()`; `game/main.gd`, `_enemy_reaktion()`] Skadan kan träffa flera fiender; `_enemy_reaktion()` går igenom dem, sätter `ENEMY_HIT`/`ENEMY_DEAD`, och returnerar första träffade `Sprite3D`. Där finns den naturliga platsen att trigga en skur per träffad figur.
- [belagt: `game/main.gd`, `_attack_fx()`; `game/project.godot`] `_attack_fx()` använder målets världsposition och vyn är 480×270 med nearest-filter; fiender använder `ENEMY_HIT := 4`, `ENEMY_FRAMES := 6`; befintlig träff spelar `_sfx("hit")`/`_sfx("crit")`.

## Partikelväg och motorbevis

- [resonemang] För en liten skur i befintlig 3D-värld: använd `GPUParticles3D`, `one_shot = true`, `emitting = false` tills noden placeras, `amount` som antal per skur, `lifetime` som falltid och `explosiveness = 1.0` för att avfyra partiklarna samlat.
- [resonemang] `ParticleProcessMaterial.emission_shape` väljer startspridning (exempelvis `EMISSION_SHAPE_BOX`); det finns ingen separat burstmodul där. Skurens timing och hur samlat utsläppet är styrs av `GPUParticles3D.one_shot` och `explosiveness`.
- [resonemang] `restart()` återstartar ett helt one-shot-system och passar den befintliga `Fx.droppar()`-mallen. Om samma nod startas igen innan dess skur hunnit dö kan den gamla skuren kapas/ersättas; skapa en nod per slag eller återanvänd först när den är färdig.
- [resonemang] `emit_particle()` är för att injicera enskilda partiklar med transform/velocity/färg/custom-data. Det ger exakt kontroll per bit men kräver att anroparen matar varje pixel; för denna vanliga skur är `restart()` enklare. Jag kunde inte läsa metoden via den här egenskapsdumpen.
- [belagt: `game/core/fx.gd`, `Fx._moln()` och `Fx.droppar()`] `local_coords = false` används redan för partiklar som ska stå kvar i rummet när spelaren rör sig.
- [resonemang] Välj `local_coords = false` så partiklarna stannar vid slagplatsen när fienden sedan rör sig/dör. Sätt den till `true` endast om skuren avsiktligt ska följa nodens förälder.
- [belagt: Godot 4.7.2 ClassDB-utskrift nedan; `game/core/fx.gd`, `Fx.droppar()`] `ParticleProcessMaterial` har `direction`, `spread`, `initial_velocity_min/max`, `gravity`, `scale_min/max`, `scale_curve`, `color` och `color_ramp`; spelet använder flera av dessa direkt i droppfunktionen.
- [resonemang] `gravity` är accelerationen i världens axlar; välj nedåt-Y för fall. `direction` och `spread` ger en kon runt önskad riktning. `scale_min/max` väljer startskala och `scale_curve` ändrar storleken över livstiden; `color_ramp` ändrar färg och alfa över livstiden (eller `color` ger en fast färg).
- [belagt: Godot 4.7.2.stable.official.ed1daf0bf, headless `ClassDB.class_get_property_list()`] Relevanta rader från motorn (typ och egenskapsnamn):

```text
CLASS GPUParticles3D
emitting : bool
amount : int
lifetime : float
one_shot : bool
explosiveness : float
randomness : float
visibility_aabb : AABB
local_coords : bool
process_material : Object
draw_pass_1 : Object
CLASS CPUParticles3D
emitting : bool
amount : int
lifetime : float
one_shot : bool
explosiveness : float
visibility_aabb : AABB
local_coords : bool
mesh : Object
emission_shape : int
direction : Vector3
spread : float
gravity : Vector3
initial_velocity_min : float
initial_velocity_max : float
scale_amount_min : float
scale_amount_max : float
scale_amount_curve : Object
color : Color
color_ramp : Object
CLASS ParticleProcessMaterial
direction : Vector3
spread : float
initial_velocity_min : float
initial_velocity_max : float
gravity : Vector3
scale_min : float
scale_max : float
scale_curve : Object
color : Color
color_ramp : Object
```

## GPUParticles3D mot CPUParticles3D

- [resonemang] För 8–12 partiklar i en kort skur räcker båda normalt. `GPUParticles3D` följer redan spelets effektsystem och lämpar sig bättre om antalet/antal samtidiga effekter växer; `CPUParticles3D` har en CPU-simulering och är ett rimligt enklare alternativ för mycket små mängder eller när CPU-åtkomst till varje partikel behövs.
- [belagt: `game/core/fx.gd`, `Fx._moln()`] Spelets befintliga effektmönster och material/yta är byggda runt `GPUParticles3D`; håll huvudförslaget där för enhetlighet.
- [resonemang] För skarpa pixlar, rita små `QuadMesh`-rutor med nearest-filter, inte suddiga 32×32 radialprickar som `Fx.prick()`; den befintliga fiendens aura/glansmaterial ska inte återanvändas som partikelmaterial.

## Konkret förslag

- [resonemang] Skapa `Fx.träffpixlar(förälder: Node3D, pos: Vector3) -> GPUParticles3D` parallellt med `Fx.droppar()`: `amount = 10`, `lifetime = 0.32`, `one_shot = true`, `explosiveness = 1.0`, `local_coords = false`, `emitting = false`; lägg till noden vid fienden, anropa `restart()`, och låt den tas bort efter `lifetime` plus kort marginal.
- [resonemang] Använd `QuadMesh.size = Vector2(0.035, 0.035)` meter och ett `StandardMaterial3D` med `BaseMaterial3D.TEXTURE_FILTER_NEAREST`, `TRANSPARENCY_ALPHA`, `vertex_color_use_as_albedo = true`. Materialets yta bör vara en liten hård kvadrat, utan mjuk radial gradient.
- [resonemang] För `ParticleProcessMaterial`: `direction = Vector3(0, 0.35, 0)`, `spread = 150.0`, `initial_velocity_min = 0.35`, `initial_velocity_max = 1.1`, `gravity = Vector3(0, -3.5, 0)`, `scale_min = 0.75`, `scale_max = 1.25`; sätt `color_ramp` till mörkrött/brunt → fiendens accentfärg → alfa 0 och `scale_curve` till 1.0 → 0.6.
- [resonemang] Världsmåttet 0.035 m är ett startvärde: vid 480×270 och nearest-pixelrendering ska `-- figurprov`-bilden bekräfta att bitarna läses som några skärmpixlar på fiendens avstånd. Kamerans perspektiv gör att meter inte motsvarar konstant antal bildpunkter.
- [resonemang] Kostnad: 10 partiklar per träffad fiende; tre samtidiga träffar betyder 30 aktiva partiklar totalt och tre skur-noder om effekten görs per fiende. Återanvänd en poolad nod per fiende/effektplats först när den föregående skuren är klar, annars kan omstart kapa den.
- [belagt: `game/main.gd`, `--fpsprov`, `_figurprov()`] Mät före/efter med befintligt `--fpsprov` för bildrutetider/antal partikelmoln och `--figurprov` för fiendebilden. Jämför samma läge och körning; bildprovet är också kontroll av storlek/läsbarhet.

## Alternativ

- [resonemang] Om enskilda partiklar måste styras exakt: `CPUParticles3D` med samma one-shot-inställningar, eller GPU:ns `emit_particle()` om den tillgängliga metoden i projektets Godot-version verifieras mot motor-API:t. För den här skuren rekommenderas inte den extra komplexiteten.

## Vad jag inte kunde belägga

- [resonemang] Jag kunde verifiera klassernas egenskaper mot Godot 4.7.2 ClassDB, men dumpade inte metodlistan; därför lämnar jag `emit_particle()`-signaturen obekräftad.
- [resonemang] Jag har inte kört `--fpsprov` eller `--figurprov` med den nya effekten, eftersom den här uppgiften endast gäller research och rapport.
