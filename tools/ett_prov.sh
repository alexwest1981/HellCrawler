#!/usr/bin/env bash
# Kör ETT test FRISTÅENDE — med egen, tom datakatalog precis som sviten (tools/test.sh, M108).
#
# Utan den här raden läser provet SPELARENS riktiga user:// (sparfilen i
# ~/.local/share/godot/app_userdata/<namn>/, som ligger under $XDG_DATA_HOME). MÄTT: tests/test_gui.gd
# fristående gav 266 kontroller / 3 fel mot spelarens sparfil och 267 kontroller / 0 fel med en färsk
# XDG_DATA_HOME — samma kod. Sparfilen bar spelarens samling (fem kort) och framsteg, så startleken
# blev en annan (deck_size 29 mot 23; startleken är grundleken + hyrd + den permanenta samlingen,
# main.gd _startleken) och provets kortspel avgjorde striden olika. Felet låg alltså i HUR provet
# kördes, inte i spelet.
#
# XDG_DATA_HOME läses vid processens START och kan inte sättas inifrån Godot — därför en wrapper i
# stället för en rad i testkoden. Samma mönster och samma namnkonvention (hc-, efter projektet) som
# test.sh använder för sviten, så ett enskilt prov och sviten svarar lika.
#
#   tools/ett_prov.sh tests/test_gui.gd
#   tools/ett_prov.sh tests/test_gui.gd --verbose      # extra flaggor går rakt till Godot
set -uo pipefail
cd "$(dirname "$0")/../game" || exit 1
prov="${1:?ange en testsökväg, t.ex. tests/test_gui.gd}"; shift
export HC_TEST=1
export XDG_DATA_HOME="${TMPDIR:-/tmp}/hc-prov-$$-data"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"
exec godot --headless --audio-driver Dummy --path . --script "res://$prov" "$@"
