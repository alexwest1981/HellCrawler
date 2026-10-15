#!/usr/bin/env bash
# Växlar mellan texturpaketets ytor och Alex' egna, med de toner och den relief som hör till varje
# uppsättning (de hänger ihop: paketets albedon ligger 2-2,5 gånger högre, så 3,0 i väggton blev
# utfrätt där och 0,95 blev svart på hans egna). Ingen egen uppsättning lagerförs: båda finns i git,
# paketet i M131 och hans egna i commiten före.
#
#   tools/ytor.sh egna     Alex' egna ark
#   tools/ytor.sh paket    texturpaketet (Texture Pack by Lynocs, CC0)
set -e
cd "$(dirname "$0")/.."
fall="${1:-}"
case "$fall" in
  egna)
    git checkout 39d1c253^ -- 'game/assets/tiles/*/wall*.png' 'game/assets/tiles/*/floor*.png' 'game/assets/tiles/*/ceiling*.png'
    sed -i 's/^const VÄGG_TON :=.*/const VÄGG_TON := Color(3.00, 3.10, 3.40)/; s/^const GOLV_TON :=.*/const GOLV_TON := Color(1.60, 1.52, 1.40)/; s/^const TAK_TON :=.*/const TAK_TON := Color(1.50, 1.60, 2.10)/; s/^\t\tmat.normal_scale = .*/\t\tmat.normal_scale = 4.0/; s/^const LJUS_STYRKA :=.*/const LJUS_STYRKA := 2.5/' game/main.gd
    ;;
  paket)
    git checkout HEAD -- 'game/assets/tiles/*/wall*.png' 'game/assets/tiles/*/floor*.png' 'game/assets/tiles/*/ceiling*.png'
    sed -i 's/^const VÄGG_TON :=.*/const VÄGG_TON := Color(0.95, 0.95, 0.95)/; s/^const GOLV_TON :=.*/const GOLV_TON := Color(0.58, 0.58, 0.58)/; s/^const TAK_TON :=.*/const TAK_TON := Color(0.72, 0.72, 0.72)/; s/^\t\tmat.normal_scale = .*/\t\tmat.normal_scale = 6.0/; s/^const LJUS_STYRKA :=.*/const LJUS_STYRKA := 4.0/' game/main.gd
    ;;
  *) echo "användning: tools/ytor.sh egna|paket"; exit 2;;
esac
cd game && timeout 300 env PATH=/usr/bin:$HOME/.local/bin:$PATH godot --headless --editor --quit --path . >/dev/null 2>&1
echo "ytorna: $fall (toner och relief satta för den uppsättningen)"
