#!/usr/bin/env bash
# Laddar upp de byggda varianterna till itch.io med butler. En kanal per OS, så itch visar
# rätt nedladdning per plattform — samma två filer Steam-depåerna skulle få.
#
# Engångs: skapa spelet på itch.io och kör `butler login` (öppnar webbläsaren), eller sätt
# BUTLER_API_KEY. Sedan:
#   ITCH_TARGET=<itch-användare>/<spelslugen> tools/itch/push.sh
# Bygg först med tools/build.sh om spelet ändrats.
set -euo pipefail
: "${ITCH_TARGET:?sätt ITCH_TARGET=<itch-användare>/<spel>, t.ex. alexwest1981/hellcrawler}"
cd "$(dirname "$0")/../.."          # repo-roten

VER="$(sed -n 's/^config\/version="\(.*\)"/\1/p' game/project.godot)"
[ -n "$VER" ] || VER="0.0.0"

butler push game/build/windows "${ITCH_TARGET}:windows" --userversion "$VER" --fix-permissions
butler push game/build/linux   "${ITCH_TARGET}:linux"   --userversion "$VER" --fix-permissions
