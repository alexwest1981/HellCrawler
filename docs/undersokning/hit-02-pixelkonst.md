# Pixlar som ramlar av fienden vid träff: teknik, storlek och samspel med träffrutan

Frågan: när ett kort slår en fiende ska figuren "tappa pixlar" — små bitar som lossnar och faller. Hur
görs det i spelets 480x270-pixelkonst, och hur kopplas det till träffrutan och glans-/auralagret?

Kortversionen: bygg **en `GPUParticles3D` per träff** med `one_shot = true`, monterad i världen (inte
som barn till figuren), med **fyrkantiga quads på 2-4 spel-pixlar** i fiendens palettindex och verklig
fallfysik. 2 px är golvet: **under två spel-pixlar flimrar kornen i CRT:ns skanlinjer** (`fx.gd:372`).
Tekniken återanvänder `Fx._moln()`/`Fx._yta()`; ingen ny bildfil. Träffrutan och glansen lämnas orörda.

## 1. Nuläget i repot (verifierat mot koden)

- **Träffen upptäcks på ett ställe**: `_enemy_reaktion()` (`game/main.gd:4429`). Vid tappad hp:
  `_enemy_läge(e, ENEMY_HIT, 0.35)` (`4451`) + `_slag_kvitto(spr, skada, mult)` (`4452`); vid hp ≤ 0
  `ENEMY_DEAD` (`4446`) + `_slag_kvitto(..., 3)` (`4447`). Det är här effekten hör hemma.
- **Träffrutan** = ruta 4 `ENEMY_HIT` (`149`), död = ruta 5 (`150`), `ENEMY_FRAMES = 6` (`151`);
  fiende-arket är **720x120 = 6 rutor à 120x120** (mätt med `Image.load_from_file` i headless Godot).
- **Kvittot** `_slag_kvitto` (`7564`): siffran fästs via `cam.unproject_position()` (`7587`) i `world`
  (`7595`) och `spr.modulate` blinkar till vitt (`7605`-`7607`). **Angreppet** (`_attack_fx`, `4460`)
  siktar på `spr.global_position + (0,0.22,0)` (`4463`). **Glansen** (`FIENDE_LOOK`, `167`; `4006`-`4011`)
  är ett **barn** till figuren; `material_override` är **stängd väg** (`156`, `4012`-`4014`).
- **Partikelbyggaren**: `Fx._moln(...)` (`fx.gd:210`) sätter `local_coords = false` (`215`) och tvingar
  `visibility_aabb = AABB((-6,-3,-6),(12,9,12))` (`216`) — **utan AABB:n gallras partiklarna bort när
  kameran rör sig**. `Fx._yta` (`179`) ger quadden med `vertex_color_use_as_albedo = true` (`196`).
  Droppen (`429`) är färdigt recept: `one_shot`, `explosiveness`, `emission_shape = BOX` (`448`).

## 2. Vad "en spel-pixel" är (mätt mot motorn)

Vyn är `SubViewport` i **480x270** (`main.gd:6368`-`6369`), kameran `fov = 62.0` (`192`) med
`KEEP_HEIGHT`, och fienden står **1,15 m** fram (`_stage_fight`, `7539`). Headless Godot 4.7.2 med
samma kamera i 480x270 (`Camera3D.unproject_position`):

| avstånd | px per meter | 1 spel-pixel |
|---|---|---|
| 1,00 m | 224,7 | 4,5 mm |
| **1,15 m (fienden)** | **195,4** | **5,1 mm** |
| 2,00 m | 112,3 | 8,9 mm |

Vid 1,15 m: **2 px ≈ 0,010 m, 4 px ≈ 0,021 m**. Quadden får inte understiga `Vector2(0.010, 0.010)`;
rekommenderat **0,014 m ≈ 3 px** med `scale_min/max` 0,7-1,4.

## 3. Färgen: palettindex, inte namn

`game/assets/palette.json` har **27 färger**, lästa med `Palett.c(i)` (`game/ui/palett.gd`). Namnen
högst upp i `tools/gen_enemy_art.py` (`78`-`82`) är **föråldrade** — filens egen varning (`407`-`412`)
säger att `BONE = 10` nu är mörkrött rgb(108,30,32) och `ORANGE = 15` mossgrönt. Använd index + rgb:
**blod/rött = 11 (168,48,40), 10 (108,30,32); ben/vitt = 8 (226,220,208), 23 (204,194,168); glöd =
13 (240,156,60), 12 (226,92,44)**.

## 4. Tre tekniker

**a) Fyrkantiga quads (väljs)**: `_moln` + `ParticleProcessMaterial`, ett ritanrop, lösa färgpixlar —
kan se ut som konfetti om färgen är fel. **b) Sprite-debris**: 4-12 `AtlasTexture`-bitar ur figurens
ark med egen livstid, sann mot konsten men pill och många ritanrop. **c) Shader-dissolve**: figuren
vittrar sönder, 0 extra ritanrop, men `material_override` är en stängd väg (`main.gd:156`).

## 5. Huvudförslag: `Fx.skärva()` + en krok i `_enemy_reaktion`

Ny statisk funktion i `game/core/fx.gd`, byggd på `_moln()`. Texturen nollas så rutan blir en solid
färgkloss (vid 3 px går rund prick och kvadrat ändå inte att skilja):

```gdscript
## PIXELREGNET (ny): fyrkantiga spillror som faller från en träffad fiende.
static func skärva(förälder: Node3D, pos: Vector3, färger: Array[Color], antal := 8) -> GPUParticles3D:
	var p := _moln(antal, 0.55, BaseMaterial3D.BLEND_MODE_MIX, Vector2(0.014, 0.014))
	var yta := (p.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	yta.albedo_texture = null
	yta.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 70.0
	m.initial_velocity_min = 0.7          # spatten uppåt först
	m.initial_velocity_max = 2.0
	m.gravity = Vector3(0.0, -9.8, 0.0)   # riktig tyngd: läses som bitar, inte rök
	m.angular_velocity_min = -420.0
	m.angular_velocity_max = 420.0
	m.scale_min = 0.7
	m.scale_max = 1.4
	m.scale_curve = _kurva([1.0, 1.0, 1.0, 0.0])
	m.lifetime_randomness = 0.35          # OBS: på MATERIALET, inte på GPUParticles3D
	m.color_ramp = _skala([färger[0], färger[0], färger[1]])
	p.process_material = m
	p.name = "pixelregn"
	förälder.add_child(p)
	return p
```

Kroken i `game/main.gd` där `hp < förra` (vid `4450`):

```gdscript
# PIXLARNA i VÄRLDEN, inte som barn till figuren — annars ärver de träffens blink och lyser vitt.
var bröst := spr.global_position + Vector3(0.0, 0.22, 0.0)
Fx.skärva(world, bröst, [Palett.c(11), Palett.c(8)], 6 + mini(mult, 3) * 2)
```

Blodigt: `[Palett.c(11), Palett.c(10)]`; glödande (lava/wisp): `[Palett.c(13), Palett.c(12)]`.
**6-12** per träff; dråp 3x antal — samma anrop, ingen egen loop.

## 6. Samspel, kostnad och alternativ

- **Tid**: `ENEMY_HIT` håller **0,35 s** (`4451`), fragmenten lever **0,55 s** → de överlever flinet.
- **Blinket**: i `world` ärver partiklarna inte `spr.modulate`; som barn till `spr` blir de
  överexponerade. **Glansen** (eget barn, `4011`) rörs inte. Känd sidoeffekt: blinket sätter `modulate`
  till `Color.WHITE` (`7607`) och skriver över `FIENDE_LOOK`-alfan (0,94) — befintlig bugg.
- **Kostnad**: `-- fpsprov` (`main.gd:906`) räknar moln/partiklar (`936`-`940`) och sämsta bildruta
  (`922`); `-- figurprov` (`5632`) mäter figuren i px. Ett slag = 6-12 partiklar, tre slag samma
  bildruta = +3 ritanrop. `one_shot` frigör molnet självt — ingen hög att städa. (Sprite-debris ger
  4-12 ritanrop; shader-dissolve måste först lösa rutfönstret — båda valdes bort i §4.)

## Vad jag inte kunde belägga

- Att `fx.gd:372`-regeln "under två spel-pixlar" stämmer i **meter**: dammet sitter på kameran och
  0,032 m där är ~18 px, medan samma mått på fiendens 1,15 m blir ~6 px. Regeln fungerar som princip,
  men omräkningen i kommentaren går inte ihop med någon mätning.
- Exakt **färgfördelning per fiende-ark**: arken är ditrade, så ingen ren färglista kan läsas ur PNG:n.
- Den faktiska **kostnaden i ritanrop**: siffrorna i §6 är en plan, inte en körning.
