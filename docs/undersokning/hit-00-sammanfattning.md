# Träffeffekter: pixlar som ramlar av fienden

Fyra undersökningsagenter (Orca-worktrees, en fråga var) fick samma verklighetsbeskrivning och kravet att
märka varje påstående `[belagt: <url>]` eller `[resonemang]` och avsluta med `## Vad jag inte kunde
belägga`. Deras rapporter ligger i `hit-01` till `hit-04`. Det här är vad de kom fram till, vad som
kontrollerades, och vad som blev kod.

| Rapport | Frågan | Kärnan |
|---|---|---|
| `hit-01-partiklar.md` | Vilken partikelväg ger en engångsskur? | `GPUParticles3D` med `one_shot`, `explosiveness = 1.0` och `restart()`; `local_coords = false` så skuren stannar vid slagplatsen; `emit_particle()` bara om varje korn ska styras |
| `hit-02-pixelkonst.md` | Hur ska det SE UT vid 480x270? | Fyrkantiga quads på 2–4 spel-pixlar i fiendens palett, riktig tyngd (-9,8); `_moln` + `_yta` räcker, ingen ny bildfil |
| `hit-03-arkitekturen.md` | Var kopplas det in med minsta ingrepp? | I `_enemy_reaktion()`s gren för tappad hälsa — en placering efter returen skulle missa träffar på flera fiender |
| `hit-04-feedback.md` | Vad gör träffen läsbar utöver kornen? | Flash, knuff och skak i millisekunder; krit skiljs med färg och ljud, inte med längre flash |

## Motorn, mätt i stället för trodd

Alla fyra rapporterna flaggade samma lucka: ingen av dem kunde köra den begärda `ClassDB`-dumpen
(worktreen saknar `.godot/`, och uppdraget tillät bara rapportfilen). Kontrollen gjordes därför i den
levande koden i efterhand, i spelets egen 4.7.2 (`ed1daf0bf`):

```
GPUParticles3D     one_shot, explosiveness, amount, amount_ratio, lifetime, speed_scale, fixed_fps,
                   interp_to_end, precess, randomness, local_coords, draw_order, visibility_aabb,
                   sub_emitter, trail_enabled, draw_pass_1..4, transform_align        FINNS
ParticleProcessMaterial  direction, spread, flatness, gravity, initial_velocity_min/max, velocity_curve,
                   angular_velocity_min/max, scale_min/max, scale_curve, color, color_ramp,
                   lifetime_randomness, emission_shape (+ punkt/box/ring/kon), use_rotation_3d   FINNS
standardvärden      gravity (0,-9.8,0) · spread 45° · initial_velocity 0–0 · scale 1–1
```

Två detaljer som bara syntes i den här kontrollen: `lifetime_randomness` finns på **materialet**, inte på
noden (rapport 02 hade rätt om det), och `GPUParticles3D` har **ingen** `lifetime_randomness`.

## Varje hänvisning kontrollerades mot koden

Filer, funktioner och radnummer i rapporterna greppades mot den levande koden. Allt stämde utom **ett**
namn: två rapporter skrev `_on_play_card()`, och anroparen heter `_on_card()` (`main.gd:8475`). Namnet är
rättat. I övrigt: `_deal` 422, `preview` 317, `_hit_plan` 438, `_enemy_reaktion` 4429, `_attack_fx` 4460,
`_figurprov` 5632, `_fps_prov` 906, `_slag_kvitto` 7564, `pixel_size`-raden 4032, `fx.gd` 179/210/429 —
alla finns där de påstods. Rapport 02:s tolv påståenden kontrollerades en efter en: palettens 27 färger
(index 8 = 226,220,208 · 10 = 108,30,32 · 11 = 168,48,40 · 12 = 226,92,44 · 13 = 240,156,60) stämmer,
liksom `Palett.c()`, `local_coords = false` och `visibility_aabb` i `_moln`, `vertex_color_use_as_albedo`
i `_yta`, `fov = 62.0`, `SubViewport` och träffrutans 0,35 s.

## Mätt: vad en spel-pixel är på fiendens avstånd

Rapport 02 mätte kameran i headless Godot (`Camera3D.unproject_position`, 480x270, fov 62, KEEP_HEIGHT):

| avstånd | px per meter | 1 spel-pixel |
|---|---|---|
| 1,00 m | 224,7 | 4,5 mm |
| **1,15 m (fienden)** | **195,4** | **5,1 mm** |
| 2,00 m | 112,3 | 8,9 mm |

Alltså: 2 px ≈ 0,010 m och 4 px ≈ 0,021 m. Kornen är **0,014 m ≈ 3 px** — under två pixlar flimrar de i
CRT:ns skanlinjer, samma gräns som dammet har.

## En riktig bugg hittades på vägen

Rapport 02 upptäckte att träff-flashen i `_slag_kvitto` (`main.gd:7605`) tweenar `spr.modulate` till
`Color(2.4, 2.4, 2.4)` och **tillbaka till `Color.WHITE`** — och `Color.WHITE` har alfa 1,0. En fiende med
genomsläpp (`FIENDE_LOOK`, alfa 0,94) blir alltså **helt fast efter första träffen den får**. Fixat genom
att spara och återställa figurens egen modulate i stället för att gissa vitt.

## Vad jag inte kunde belägga

- Att 0,014 m känns rätt i bild: siffran är räknad ur kameran. Efter bygget granskades den i ett
  träffprov (`docs/skarmbilder/träff-pixlar.png`): kornen läses som 1-3 px fyrkantiga bitar i fiendens
  palett, strax under och vid sidan av figuren — alltså i den storlek siffran förutsade.
- Den faktiska kostnaden i ritanrop och bildrutor för tre träffar i samma bildruta: effekten är byggd och
  antalet är mätt (8 korn per träff, upp till 14 vid kedja och 14 vid dråp, alla kortlivade), men
  `-- fpsprov` spelar inga kort och kan därför inte mäta den. Tid är alltså fortfarande omätt.
- Rapport 02:s invändning mot dammets egen kommentar ("två spel-pixlar" vid kameran är ~18 px, vid fienden
  ~6 px) är rimlig och står kvar: principen håller, omräkningen i kommentaren gjorde det inte.
