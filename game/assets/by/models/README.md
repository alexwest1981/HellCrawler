# Byns byggnader i 3D

Lågpolymodeller, en GLB per byggnad. Byggs om med

```
blender --background --python tools/gen_by_hus3d.py
blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät
```

Origo ligger på markplanet mitt i varje byggnad, +Z upp i Blender (GLB-exporten gör Y-up).
Enheter är meter. Grunden (sockeln) är fotavtrycket; takutsprång, skyltar och lyktor sticker
ut utanför den. Samlingsfilen med alla sex på rad är `assets/by_hus_3d.blend`
(utanför git, samma regel som repots övriga .blend-filer).

| Byggnad | Grund b × d (m) | Högsta punkt (m) | Trianglar | Texturer |
|---|---|---|---|---|
| `tradet.glb` | 4.4 × 3.2 | 5.2 | 200 | fönsterkarm, järn, ljust_virke, mörkt_virke, sten |
| `smed.glb` | 5.0 × 3.6 | 6.2 | 164 | fönsterkarm, järn, ljust_virke, mur, mörkt_virke, sten |
| `vardshus.glb` | 6.0 × 4.0 | 7.3 | 572 | fönsterkarm, järn, ljust_virke, mörkt_virke, puts, skiffer, sten |
| `karta.glb` | 5.2 × 3.6 | 8.0 | 340 | järn, mur, mörkt_virke, sten |
| `juvelerare.glb` | 4.2 × 3.0 | 4.6 | 164 | fönsterkarm, järn, ljust_virke, murgröna, mörkt_virke, puts, sten |
| `avsluta.glb` | 4.2 × 3.0 | 4.1 | 140 | fönsterkarm, ljust_virke, mörkt_virke, sten |

Färgade material utan textur (samma palett som spelet): glöd, fönster, lykta,
tyg_rött, tyg_blått, glas_mörkt, skyltfält, fönsterkarm.

Texturerna är spelets egna rutor i `game/assets/tiles/material/`, ett varv per ~2,2 m

| Material i GLB | Ruta |
|---|---|
| `glöd` | `magma_rock.png` |
| `järn` | `corroded_metal.png` |
| `ljust_virke` | `woven_bamboo.png` |
| `mur` | `fortified_stone_bricks.png` |
| `murgröna` | `wall_with_ivy.png` |
| `mörkt_virke` | `wooden_palisades.png` |
| `puts` | `chiseled_marble.png` |
| `skiffer` | `polished_obsidian_wall.png` |
| `sten` | `ancient_stone.png` |

Referensbilderna (`by2d/byn_vc.png`, `vc_lan/town/Town_BG.png`) är bara tittade på —
ingen av dem är använd som textur.
