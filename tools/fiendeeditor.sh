#!/usr/bin/env bash
# Fiendeeditorn: sudda och måla i fiendekonsten. Retuschen hamnar i data/enemies/retuschering.json
# och läggs på bilden när spelet laddar fienden — ingen PNG skrivs av editorn.
#
#   tools/fiendeeditor.sh [fiende] [shot]      fiende = t.ex. bone_wretch, shot = foto och avsluta
set -euo pipefail
cd "$(dirname "$0")/.."
export DISPLAY="${DISPLAY:-:99}"
ARGS=("$@")
FIENTE="${ARGS[0]:-}"
if [[ "${FIENTE}" == "shot" ]]; then FIENTE=""; fi
EXTRA=()
if [[ " ${ARGS[*]} " == *" shot "* ]]; then EXTRA+=("shot"); fi
godot --path game --rendering-driver opengl3 --audio-driver Dummy \
	res://editor/fiendeeditor.tscn -- ${FIENTE} "${EXTRA[@]}"
