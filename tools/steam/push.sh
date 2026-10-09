#!/usr/bin/env bash
# Laddar upp de byggda varianterna till Steam med steamcmd. En appID, en depå per OS —
# Steam-klienten ger varje spelare rätt bygge, ingen kod i spelet behöver veta vilket.
#
# ID:na finns i Steamworks under App Admin > Depots (skapa en depå per OS där först).
# Kör sedan, med ditt Steamworks-kontonamn:
#   STEAM_USER=<kontonamn> APPID=<appid> DEPOT_WIN=<win-depå> DEPOT_LINUX=<linux-depå> \
#     tools/steam/push.sh
# steamcmd frågar efter lösenord/2FA — det stannar i terminalen, aldrig i den här filen.
# Standard: bygget hamnar på betagrenen (SetLive=beta). Sätt BRANCH= för att inte sätta live.
set -euo pipefail
: "${STEAM_USER:?sätt STEAM_USER (Steamworks-kontonamnet)}"
: "${APPID:?sätt APPID}"
: "${DEPOT_WIN:?sätt DEPOT_WIN (depå-ID för Windows-bygget)}"
: "${DEPOT_LINUX:?sätt DEPOT_LINUX (depå-ID för Linux-bygget)}"
STEAMCMD="${STEAMCMD:-steamcmd}"
BRANCH="${BRANCH-beta}"

cd "$(dirname "$0")/../.."          # repo-roten
OUT="$PWD/game/build/steam"
mkdir -p "$OUT"

cat > "$OUT/depot_win.vdf" <<EOF
"DepotBuildConfig"
{
	"DepotID" "$DEPOT_WIN"
	"ContentRoot" "$PWD/game/build/windows"
	"FileMapping" { "LocalPath" "*" "DepotPath" "." "recursive" "1" }
	"FileExclusion" "*.pdb"
}
EOF

cat > "$OUT/depot_linux.vdf" <<EOF
"DepotBuildConfig"
{
	"DepotID" "$DEPOT_LINUX"
	"ContentRoot" "$PWD/game/build/linux"
	"FileMapping" { "LocalPath" "*" "DepotPath" "." "recursive" "1" }
}
EOF

cat > "$OUT/app_build.vdf" <<EOF
"AppBuild"
{
	"AppID" "$APPID"
	"Desc" "HellCrawler $(date +%F)"
	"BuildOutput" "$OUT/output"
	"ContentRoot" "$PWD"
	"SetLive" "$BRANCH"
	"Preview" "0"
	"Depots"
	{
		"$DEPOT_WIN" "depot_win.vdf"
		"$DEPOT_LINUX" "depot_linux.vdf"
	}
}
EOF

"$STEAMCMD" +login "$STEAM_USER" +run_app_build "$OUT/app_build.vdf" +quit
