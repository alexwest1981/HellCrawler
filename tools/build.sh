#!/usr/bin/env bash
# Bygger de två release-varianterna (PCK inbäddad i varje fil) som laddas upp
# till itch.io eller läggs i Steam-depåerna.
#   Windows: game/build/windows/HellCrawler.exe
#   Linux:   game/build/linux/hellcrawler.x86_64
# Redigerarna och testträdet filtreras bort av export_presets.cfg, så de finns inte i bygget.
set -euo pipefail
cd "$(dirname "$0")/.."              # repo-roten
# Fångar att skriptet körs ur fel katalog: annars gissar Godot en sökväg och felar kryptiskt.
[ -f game/project.godot ] || { echo "fel: hittar inte game/project.godot — kör skriptet ur repot" >&2; exit 1; }
GODOT="${GODOT:-godot}"

mkdir -p game/build/windows game/build/linux

"$GODOT" --headless --path game --export-release "Windows Desktop" "build/windows/HellCrawler.exe"
"$GODOT" --headless --path game --export-release "Linux"           "build/linux/hellcrawler.x86_64"

echo
ls -lh game/build/windows game/build/linux
