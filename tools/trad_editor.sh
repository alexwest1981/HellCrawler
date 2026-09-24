#!/usr/bin/env bash
# Trädeditorn: placera trädets noder för hand i plattan och spara dem till data/trad_sockets.json.
#
#   tools/trad_editor.sh
#
# Samma fil läses av spelets trädvy, så det du placerar är det som spelas. Tangenterna står i panelen.
set -euo pipefail
cd "$(dirname "$0")/../game"

# En egen ikon (PNG i assets/tree/) måste importeras av Godot innan den går att ladda, annars ser
# noden tom ut trots att filen finns. Importen är snabb och gör inget om inget är nytt.
godot --headless --path . --import >/dev/null 2>&1 || true

exec godot --path . res://editor/trad_editor.tscn
