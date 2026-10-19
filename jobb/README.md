# jobb/ — min arbetsyta i HellCrawlers

Här lägger jag allt jag producerar själv, så att det aldrig blandas med spelets filer eller med dina
scener. Samma mappnamn används i varje projekt vi jobbar i.

```
jobb/
  blender_tools.py   verktyget: who(), snapshot(), overview()  — körs headless eller via bryggan
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
