#!/usr/bin/env bash
# Startar spelet. Allt annat (tester, balans, konst, ljud) ligger i tools/.
set -euo pipefail
# ~/.local/bin först: godot ligger där, och en genväg på skrivbordet startar scriptet i en miljö som
# inte alltid har den katalogen i PATH (MÄTT: "exec: godot: not found" med PATH=/usr/bin:/bin).
export PATH="$HOME/.local/bin:$PATH"
cd "$(dirname "$0")/../game"
exec godot --path . "$@"
