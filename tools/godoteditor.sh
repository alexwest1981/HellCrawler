#!/usr/bin/env bash
# Godot-editorn på projektet — öppna det för hand och flytta noder, utan att gå via mig.
#
#   tools/godoteditor.sh
#
# Motorn är samma 4.8-dev7 som spelet körs med (`~/.local/bin/godot` -> ~/.local/opt/godot-4.8-dev7/).
# Öppna ALDRIG projektet i en äldre motor (4.7.2 ligger i ~/.local/opt/ för Hell-projektet): den
# skriver om project.godot till sin egen version och backar hela projektet. Godot varnar för det —
# varningen är sann, och "OK" är det man inte ska trycka på.
set -euo pipefail
cd "$(dirname "$0")/../game"
exec godot --editor --path .
