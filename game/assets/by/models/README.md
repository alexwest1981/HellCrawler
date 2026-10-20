# Byns byggnader i 3D

En GLB per byggnad, byggd av `tools/gen_by_hus3d.py` ur spelets egna materialrutor.
Byggs om med

```
blender --background --python tools/gen_by_hus3d.py
blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät
```

Origo ligger på markplanet mitt i varje byggnad, +Z upp i Blender (GLB-exporten gör Y-up).
Fasaden ligger åt -Y i Blender, alltså +Z i GLB:n. Enheter är meter. Grunden (sockeln) är
fotavtrycket; takutsprång, skyltar, trappor och ässjor sticker ut utanför den.
Samlingsfilen med alla sex på rad är `assets/by_hus_3d.blend` (utanför git, samma regel
som repots övriga .blend-filer). Turnaround-bilder ligger i `granskning/`.

Varje hus exporteras som en mesh per material (Noder nedan), inte en nod per spik:
det håller GLB:n på ett tiotal draw calls per hus i byn. `--kolla` kräver 3 000-15 000
trianglar per hus, grund på 4-6 × 3-4 m och högsta punkt på 4-8 m.

| Byggnad | Grund b × d (m) | Högsta punkt (m) | Trianglar | Noder | Texturer |
|---|---|---|---|---|---|
| `tradet.glb` | 4.6 × 3.4 | 5.8 | 5472 | 16 | järn, ljust_virke, mur, mörkt_virke, sten |
| `smed.glb` | 5.2 × 3.8 | 7.0 | 11348 | 17 | järn, ljust_virke, mur, mörkt_virke, sten |
| `vardshus.glb` | 6.0 × 4.0 | 7.9 | 7456 | 16 | järn, ljust_virke, mur, mörkt_virke, puts, skiffer, sten |
| `karta.glb` | 5.5 × 3.9 | 7.9 | 4692 | 12 | järn, ljust_virke, mur, mörkt_virke, puts, sten |
| `juvelerare.glb` | 4.7 × 3.3 | 5.3 | 7056 | 16 | järn, ljust_virke, mur, murgröna, mörkt_virke, puts, sten |
| `avsluta.glb` | 4.4 × 3.0 | 4.8 | 4932 | 15 | järn, ljust_virke, mur, mörkt_virke, sten |

Varje hus är ihopsatt av riktiga byggdelar:

- **tradet** — timmerstockar med knutar, spåntak, hängande väv, tygrullar, tunna
- **smed** — murat skiftverk, öppen ässja med glödbädd, kåpa, bälg, städ med hammare, verktygstavla, kolhög
- **vardshus** — puts med korsvirke och snedsträvor, utkragad övervåning, balkong, lyktor
- **karta** — murverk block för block runt valvet, kilstenar, krenelering, port med järnband, fana
- **juvelerare** — kvadersten, skyltfönster med galler och smycken, murgröna, hörnkvadrar
- **avsluta** — timmer, spåntak, grindstolpar, bom och skylt över vägen

Material utan textur (platta färger i byns palett): takpannor, spån, tegel, glöd,
fönster, lyktglas, tyg_rött, tyg_blått, glas_mörkt, skyltfält, mässing, kol, vatten, lera,
fönsterkarm.

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

Referensbilderna (`by2d/byn_vc.png`, `by2d/byn.png`, `vc_lan/town/Town_BG.png`) är
bara tittade på — ingen av dem är använd som textur.
