#!/usr/bin/env bash
# Kör spelet för ett PROV — tyst, och utan att synas på skrivbordet.
#
# Alex: *"Kan du testa spelen ljudlöst?"* Ett prov som låter eller öppnar ett fönster över det han
# arbetar med är ett prov som stör, och det ska inte hänga på att den som skriver kommandot kommer
# ihåg en flagga. Samma två rader som `tools/fiendeeditor.sh` redan hade:
#
#   --audio-driver Dummy   inget ljud alls. Ljudet hör till SPELARENS körning, alltså tools/play.sh.
#   DISPLAY=:99            Xvfb i stället för skrivbordet (sätts bara om DISPLAY inte redan är satt).
#
# Provet kör som vanligt (inte --headless): bildprov, fps-prov och ljusprov BEHÖVER rendera. Ett prov
# som bara läser siffror kan lika gärna köras med `--headless` direkt, som testsviterna gör.
#
#   tools/prov.sh -- stage=stage_90 vaning=3 fpsprov
#   tools/prov.sh -- shot
#   tools/prov.sh -- guiprov
set -euo pipefail
cd "$(dirname "$0")/../game"
export PATH="$HOME/.local/bin:$PATH"
export DISPLAY="${DISPLAY:-:99}"
exec godot --path . --audio-driver Dummy "$@"
