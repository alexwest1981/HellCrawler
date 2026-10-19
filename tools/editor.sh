#!/usr/bin/env bash
# Karteditorn: rita en våning för hand och spara den till data/maps/<bana>_<våning>.json.
#
#   tools/editor.sh                 # stage_01, våning 1
#   tools/editor.sh stage_05 2      # bana och våning — våningen räknas som du gör: 1 = första
#
# Tangenterna står i panelen: 1-6 nod, G golv, X vägg, S spara, L läs, N ny, P spela, [ ] byt våning.
# O sparar våningen som BLOCK i data/blocks/ — generatorn lägger in det i ett rum som har plats.
# Musen gör resten: klick väljer, drag flyttar, dra tom yta = box, hjul zoomar, Del/Ctrl+D.
set -euo pipefail
cd "$(dirname "$0")/../game"
BANA="${1:-stage_01}"
VANING="${2:-1}"
# Filen och editorn räknar våningar från 0; människan från 1. Byt bara här, på ett ställe.
exec godot --path . res://editor/editor.tscn -- "$BANA" "$(( VANING - 1 ))"
