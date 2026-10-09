#!/usr/bin/env bash
# Laddar upp de byggda varianterna till itch.io med butler. En kanal per plattform, så itch visar
# rätt nedladdning per plattform — samma filer Steam-depåerna skulle få. Kanalen "html" blir
# webbversionen, men FÖRSTA gången måste "This file will be played in the browser" bockas i på
# itch-sidan: butler kan inte sätta det, och kanalnamnet gör det inte åt dig.
#
# Engångs: skapa spelet på itch.io och kör `butler login` (öppnar webbläsaren), eller sätt
# BUTLER_API_KEY. Sedan:
#   ITCH_TARGET=<itch-användare>/<spelslugen> tools/itch/push.sh
# Bygg först med tools/build.sh om spelet ändrats.
set -euo pipefail
: "${ITCH_TARGET:?sätt ITCH_TARGET=<itch-användare>/<spel>, t.ex. alexwest81/hellcrawler}"
cd "$(dirname "$0")/../.."          # repo-roten
# butler skulle annars bara säga att sökvägen inte finns.
{ [ -d game/build/windows ] && [ -d game/build/linux ] && [ -d game/build/web ]; } \
  || { echo "fel: inga byggen i game/build/ — kör tools/build.sh först" >&2; exit 1; }

VER="$(sed -n 's/^config\/version="\(.*\)"/\1/p' game/project.godot)"
[ -n "$VER" ] || VER="0.0.0"

butler push game/build/windows "${ITCH_TARGET}:windows" --userversion "$VER" --fix-permissions
butler push game/build/linux   "${ITCH_TARGET}:linux"   --userversion "$VER" --fix-permissions
# Ingen --fix-permissions här: webbversionen har inga körbara filer.
butler push game/build/web     "${ITCH_TARGET}:html"    --userversion "$VER"
