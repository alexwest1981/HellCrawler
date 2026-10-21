# Byns byggnader i 3D

En GLB per byggnad och en för brunnen, byggda av `tools/gen_by_hus3d.py` ur spelets
egna materialrutor, de nedladdade mapseten i `texturer/` och platta palettfärger.
Formerna följer `game/assets/by2d/byn_referens.png`. Byggs om med

```
blender --background --python tools/gen_by_hus3d.py
blender --background --python tools/gen_by_hus3d.py -- --kolla   # importera tillbaka och mät
```

Origo ligger på markplanet mitt i varje byggnad, +Z upp i Blender (GLB-exporten gör Y-up).
Fasaden ligger åt -Y i Blender, alltså +Z i GLB:n. Enheter är meter. Grunden (sockeln)
är fotavtrycket; takutsprång, skyltar, trappor och ässjor sticker ut utanför den.
Samlingsfilen med alla sju på rad är `assets/by_hus_3d.blend` (utanför git, samma regel
som repots övriga .blend-filer). Turnaround-bilder ligger i `granskning/`.

Husen är byggda i bynivå: 9-14 m breda, 6-9 m djupa och 10-18 m höga (porttornet
högst, värdshuset störst av husen). Varje hus exporteras som en mesh per material
(Noder nedan), inte en nod per spik. `--kolla` kräver 20 000-250 000 trianglar per hus
(brunnen 2 500-40 000), grund inom måtten ovan, högsta punkt 10-18 m och högst 20 MB
per fil.

| Modell | Grund b × d (m) | Högsta punkt (m) | Trianglar | Noder | UV-varv/m | Texturer |
|---|---|---|---|---|---|---|
| `tradet.glb` | 12.5 × 7.5 | 10.5 | 50744 | 17 | 0.021 | järn, ljust_virke, mur, mörkt_virke, sten |
| `smed.glb` | 12.5 × 8.5 | 15.2 | 98244 | 25 | 0.025 | glödhet, järn, ljust_virke, läder, mur, mörkt_virke, puts, rök_0, rök_1, rök_2, rök_3, sot, sten |
| `vardshus.glb` | 13.5 × 8.5 | 15.7 | 64724 | 19 | 0.015 | järn, ljust_virke, mur, mörkt_virke, puts, sten |
| `karta.glb` | 17.8 × 6.8 | 11.7 | 63772 | 15 | 0.018 | järn, ljust_virke, mur, mur_grå, mörkt_virke, puts, sot, sten |
| `juvelerare.glb` | 9.1 × 6.6 | 12.1 | 40540 | 19 | 0.024 | järn, ljust_virke, mur, mörkt_virke, puts, sten |
| `avsluta.glb` | 9.5 × 6.5 | 12.1 | 42428 | 16 | 0.023 | järn, ljust_virke, mur, mörkt_virke, puts, sten |
| `brunn.glb` | 2.3 × 2.3 | 2.6 | 3576 | 10 | 0.156 | järn, ljust_virke, mur, mörkt_virke, puts, sten |

Varje modell är ihopsatt av riktiga byggdelar:

- **tradet** — öppet klädstånd: åtta stolpar med knästrävor, sparrar och åsar, brant skiffertak, klädstreck med plagg i fem färger, disk med tygrullar, tunnor, ved och plankor
- **smed** — murat grått stenhus med brant skiffertak, hög skorstensstock, rundbågig ässja med glödbädd och kåpa, stor blåsbälg med spak och läder, städ på stubbe med hammare, verktygstavla, pall, kolhög, släckfat, spann och ved
- **vardshus** — krämvit puts med mörkbrunt korsvirke i två våningar, utkragad övervåning med bjälkändar, brant skiffertak med takkupa och fönster, tända spröjsade fönster, lyktor, skylt med ölmugg, bänk och tunnor
- **karta** — massivt porttorn av stora stenblock, krenelerad topp med kragstenar, smala skyttegluggar, rundbågig port med järnbandade träportar, fallgaller, facklor, A-skylt och tunnor
- **juvelerare** — puts med mörkbrunt korsvirke, stort upplyst skyltfönster med färgade stenar och skiffertak över, mörk trädörr, litet fönster ovanför, A-skylt, blommor
- **avsluta** — puts och korsvirke som värdshuset men mindre, skiffertak, diskret skylt, lykta, bänk, tunnor och ved samt en låg grind
- **brunn** — rundad stenring i sex skift med krönsten, trästolpar med knästrävor, vindspel med vev, rep och hink, vatten i botten

## UV-kartor

Varje mesh har två UV-kartor:

- **`UVMap`** (TEXCOORD_0) — unik, packad 0-1 utan överlapp, med några millimeters
  marginal mellan öarna. En gemensam texteldensitet för hela byggnaden: den största
  materialgruppen sätts till 0,94 av kartan, resten får samma skala. Det är den här
  kartan man byter till en egen målad textur på. Dolda baksidor (insidan av en
  väggkärna innanför murskinnet) delar UV-yta med framsidan — de syns aldrig, och
  det sparar atlasutrymme; alla synliga ytor har egna icke överlappande öar.
- **`Upprepning`** (TEXCOORD_1) — löpande projektion per byggdel, den spelets sömlösa
  rutor sitter på via en UV Map-nod i materialet. Virke projiceras med u längs
  fiberriktningen, så ådringen följer stockens längd även när den ligger ner.

Densiteten i `UVMap` är densamma i alla delar av en byggnad men skiljer sig mellan
byggnaderna (ett stort tak kräver mer UV-yta). Antalet pixlar per meter är varv/m ×
atlasbredd:

| Modell | Varv/m | px/m vid 2048² | px/m vid 8192² |
|---|---|---|---|
| `tradet` | 0.021 | 43 | 173 |
| `smed` | 0.025 | 51 | 206 |
| `vardshus` | 0.015 | 30 | 123 |
| `karta` | 0.018 | 36 | 144 |
| `juvelerare` | 0.024 | 48 | 195 |
| `avsluta` | 0.023 | 47 | 191 |
| `brunn` | 0.156 | 318 | 1275 |

För att måla en egen textur räcker alltså inte 2048² för husen; UV-ytan är byggd för en
atlas på 8-16 k. Den löpande kartan, som materialen använder i dag, ligger på 512 px/m:
0,5 varv/m för de inkopierade 1024-bilderna (2 m per ruta) och 0,45 varv/m för spelets
256-rutor (en ruta per ~2,2 m, samma tegelskala som referensen).

### Del → material → UV-yta

UV-ytan är den unika kartans area för delen, i m² (flera öar per del när delens ytor
pekar åt olika håll).

| Del | Material | UV-yta (m²) | Öar |
|---|---|---|---|
| `rekvisita` | `ljust_virke` | 63.79 | 6 |
| `lykta` | `lyktglas` | 4.15 | 18 |
| `skylt` | `mässing` | 1.64 | 6 |
| `rekvisita` | `lera` | 0.83 | 6 |
| `rekvisita` | `rep` | 0.54 | 6 |

Material utan textur (platta färger i byns palett): takpannor, spån, tegel, glöd,
låga, fönster, lyktglas, tyg_rött, tyg_blått, tyg_grönt, tyg_gult, tyg_turkost,
glas_mörkt, skyltfält, mässing, kol, vatten, lera, fönsterkarm, rep, halm.

## Texturer

| Material i GLB | Bild |
|---|---|
| `glöd` | `magma_rock.png` |
| `järn` | `järn.png + järn_normal.png + järn_orm.png` |
| `ljust_virke` | `trä_ljust.png + trä_ljust_normal.png + trä_ljust_orm.png` |
| `läder` | `läder.png + läder_normal.png + läder_orm.png` |
| `mur` | `sten_grå.png` |
| `mur_grå` | `sten_grå_neutral.png` |
| `mässing` | `mässing.png + mässing_normal.png + mässing_orm.png` |
| `mörkt_virke` | `bark_normal.jpg + bark_normal_normal.jpg` |
| `puts` | `chiseled_marble.png` |
| `sten` | `sten_grå.png` |
| `tyg_blått` | `tyg_väv.png + tyg_väv_normal.png + tyg_väv_orm.png` |
| `tyg_grönt` | `tyg_väv.png + tyg_väv_normal.png + tyg_väv_orm.png` |
| `tyg_gult` | `tyg_väv.png + tyg_väv_normal.png + tyg_väv_orm.png` |
| `tyg_rött` | `tyg_väv.png + tyg_väv_normal.png + tyg_väv_orm.png` |
| `tyg_turkost` | `tyg_väv.png + tyg_väv_normal.png + tyg_väv_orm.png` |

Två sorters ytor används:

- **`game/assets/tiles/material/`** — spelets egna 256-rutor (puts, tegel, murgröna,
  glöd, bambu m.m.), satta på den löpande UV-kartan med 0,45 varv/m så en ruta täcker
  ~2,2 m — samma tegelskala som referensbilden.
- **`texturer/`** — 16 rutor utklippta ur de nedladdade mapseten med
  `tools/klipp_texturer.py`: kläd-, läder- (T_Trim_Props), trä- (T_Trim_Furniture),
  järn- (T_Trim_Metal) och mässingsytor ur Fantasy Props MegaKit samt gråsten ur
  Stylized Nature MegaKit. Alla fem har BaseColor + Normal + ORM (R = AO, G = grovhet,
  B = metall) kopplade; GLB:n bär alltså även `occlusionTexture` och
  `metallicRoughnessTexture`. Texeldensiteten är 512 px/m (varv/m = 512 / bildbredd),
  så en 256-ruta upprepar sig var 0,5 m.

Bara de atlasrutor som faktiskt används är inkopierade, och varje ruta är vald för
låg kantmismatch (se `mät` i klippverktyget) så den kan repeteras utan synlig söm.
Ingen preview-bild eller skärmdump används som textur, och
`game/assets/by2d/`-bilderna är bara tittade på.
