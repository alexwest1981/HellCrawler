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

# SPÄRR MOT PLACEHOLDER-KONST (M199). Alex: *"Vi skall inte publicera något förrän allt är utbytt
# till egen grafik"*. Allt som lånats in från Vampire Crawlers för att kunna SE byn ligger i
# `game/assets/vc_lan/` med en `PLACEHOLDER`-fil bredvid. Finns den mappen, eller står den i en
# scen/ett skript, går bygget inte igenom — en release med någon annans konst är ett brott, inte en
# bugg. Radera mappen och kontrollera att `grep -r vc_lan game/` är tom när egen konst är på plats.
if [ -d game/assets/vc_lan ] || grep -rql "assets/vc_lan" game --include=*.gd --include=*.tscn --include=*.tres 2>/dev/null; then
	echo "fel: placeholder-konst från VC ligger kvar (game/assets/vc_lan) — bygget vägrar." >&2
	echo "     Byt ut den mot egen grafik innan något publiceras." >&2
	exit 1
fi

mkdir -p game/build/windows game/build/linux game/build/web

"$GODOT" --headless --path game --export-release "Windows Desktop" "build/windows/HellCrawler.exe"
"$GODOT" --headless --path game --export-release "Linux"           "build/linux/hellcrawler.x86_64"
"$GODOT" --headless --path game --export-release "Web"             "build/web/index.html"

echo
ls -lh game/build/windows game/build/linux game/build/web
