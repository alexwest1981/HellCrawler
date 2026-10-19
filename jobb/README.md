# jobb/ — min arbetsyta i HellCrawlers

Här lägger jag allt jag producerar själv, så att det aldrig blandas med spelets filer eller med dina
scener. Samma mappnamn används i varje projekt vi jobbar i.

```
jobb/
  blender_tools.py   verktyget: who(), snapshot(), overview()  — körs headless eller via bryggan
  terrang.py         berget: trappad bergskedja med förberg   (körs först)
  modeller.py        träd, gräs ur Quaternius-kitet, moln, måne, himmelplatta + stjärnor
  byggnader.py       husen: ett mesh per byggnad, hål, takpannor, gavel, port
  exportera.py       skriver game/assets/by/byn.glb (ljus delade, rekvisita parkerad)
  trad_positioner.json  trädens positioner, lästa ur filen innan de byggdes om
  README.md          den här filen (i git)
  bilder/            översiktsark och enkelvyer, <datum>_<scen>_*.png   (ej i git)
  snapshots/         kopior av .blend tagna FÖRE en skrivomgång        (ej i git)
```

## Så körs det

```bash
# översikt: kamera + front + sida + topp i ett ark (3840x2160), ~12 s för hela byn
blender -b assets/Untitled_byn_kedjan.blend --python jobb/blender_tools.py -- --overview

# vem svarar bryggan (pid, background, fil, objektantal)
blender -b assets/Untitled_byn_kedjan.blend --python jobb/blender_tools.py -- --who
```

### Ordningen för en scen-omgång

Stegen skriver till samma .blend och måste köras i den här ordningen — `exportera.py` läser det som de
tre andra byggde:

```bash
cp -p assets/Untitled_byn_kedjan.blend jobb/snapshots/$(date +%Y-%m-%d_%H%M)_fore-omgang.blend
blender -b assets/Untitled_byn_kedjan.blend --python jobb/terrang.py       # berget
blender -b assets/Untitled_byn_kedjan.blend --python jobb/modeller.py      # träd, gräs, moln, måne, himmel
blender -b assets/Untitled_byn_kedjan.blend --python jobb/byggnader.py     # husen
blender -b assets/Untitled_byn_kedjan.blend --python jobb/exportera.py     # -> game/assets/by/byn.glb
cd game && godot --headless --import && cd .. && bash tools/test.sh
```

Varje skript har `--check` (bygger utan att spara och skriver sina egna siffror) och `--no-save`.
`byggnader.py` tar dessutom `--hus Tavern` för att bygga om en enda byggnad.

**Efter varje export måste Godot importera om** (`godot --headless --import`). Utan det läser proven
den gamla glb:n ur `.godot`-cachen och svarar med förra omgångens siffror — det såg ut som ett
geometrifest och var en cache.

Via MCP-bryggan i din öppna Blender:

```python
exec(open("/home/alex/Projects/hellcrawlers/jobb/blender_tools.py").read())
result = who()          # eller snapshot("fore-texturbyte") / overview()
```

`overview()` rör inte filen: renderinställningarna och de tillfälliga kamerorna ställs tillbaka, och
inget sparas. Det den lämnar efter sig är bilderna i `jobb/bilder/`.

## Var scenerna bor

- `assets/Untitled_byn_kedjan.blend` — arbetsfilen vi redigerar (namnet är ditt, jag har inte bytt det).
- `assets/arkiv/` — äldre versioner, flyttade hit 19/10 från Downloads, Pictures och Documents
  (18 filer, 100 MB, varav `Untitled_RADDAD_efter_kraschen.blend` och `Untitled_byn_kedjan_Alex_0927.blend`
  bär din egen historik). Inget i arkivet är i git.
