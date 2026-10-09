#!/usr/bin/env bash
# Bygger de två release-varianterna som Steam-depåerna pekar på.
#   Windows: game/build/windows/HellCrawler.exe      (en .exe, PCK inbäddad)
#   Linux:   game/build/linux/hellcrawler.x86_64     (en binär, PCK inbäddad)
# Redigerarna och testträdet filtreras bort av export_presets.cfg, så de finns inte i bygget.
set -euo pipefail
cd "$(dirname "$0")/../.."          # repo-roten
GODOT="${GODOT:-godot}"

mkdir -p game/build/windows game/build/linux

"$GODOT" --headless --path game --export-release "Windows Desktop" "build/windows/HellCrawler.exe"
"$GODOT" --headless --path game --export-release "Linux"           "build/linux/hellcrawler.x86_64"

echo
ls -lh game/build/windows game/build/linux
