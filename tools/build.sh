#!/usr/bin/env bash
# Bygger de tre release-varianterna (PCK som egen fil, så butler kan diffa) som laddas upp
# till itch.io eller läggs i Steam-depåerna.
#   Windows: game/build/windows/HellCrawler.exe
#   Linux:   game/build/linux/hellcrawler.x86_64
#   Webb:    game/build/web/index.html  (spelas i webbläsaren; GL-renderaren, se project.godot)
# Redigerarna, testträdet och källbilderna (images/, 92 MB som inget spelobjekt pekar på)
# filtreras bort av export_presets.cfg, så de finns inte i bygget.
set -euo pipefail
cd "$(dirname "$0")/.."              # repo-roten
# Fångar att skriptet körs ur fel katalog: annars gissar Godot en sökväg och felar kryptiskt.
[ -f game/project.godot ] || { echo "fel: hittar inte game/project.godot — kör skriptet ur repot" >&2; exit 1; }
GODOT="${GODOT:-godot}"

mkdir -p game/build/windows game/build/linux game/build/web

"$GODOT" --headless --path game --export-release "Windows Desktop" "build/windows/HellCrawler.exe"
"$GODOT" --headless --path game --export-release "Linux"           "build/linux/hellcrawler.x86_64"
"$GODOT" --headless --path game --export-release "Web"             "build/web/index.html"

echo
ls -lh game/build/windows game/build/linux game/build/web
