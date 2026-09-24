#!/usr/bin/env bash
# Trädeditorn: placera trädets noder för hand i plattan och spara dem till data/trad_sockets.json.
#
#   tools/trad_editor.sh
#
# Samma fil läses av spelets trädvy, så det du placerar är det som spelas. Tangenterna står i panelen.
set -euo pipefail
cd "$(dirname "$0")/../game"
exec godot --path . res://editor/trad_editor.tscn
