#!/usr/bin/env bash
# Hämtar senaste versionen från GitHub och lägger in den i den här kopian.
#
# Spelet har ingen byggnad — uppdateringen är en git-uppdatering och inget mer. Startikonen pekar på
# den här katalogen, så den behöver inte läggas om efteråt: sökvägen ändras inte av en uppdatering.
#
# Användning:
#   ./update.sh
#
# VARIABELNAMNET MÅSTE VARA ASCII (se install.sh): "HÄR=..." körs som ett kommando av bash.
set -euo pipefail

HAR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HAR"

if ! command -v git >/dev/null; then
	echo "FEL: hittar inget git." >&2
	exit 1
fi

if [ ! -d .git ]; then
	echo "FEL: den här kopian är inte en git-klon (ingen .git-katalog), så den kan inte uppdateras" >&2
	echo "     härifrån. Ladda hem zip-filen på nytt i stället, från samma sida du hämtade den." >&2
	exit 1
fi

# Snabb framspolning först — den vanliga vägen, och den som inte rör något lokalt.
# Har man egna ändringar i trädet faller den, och då gör samma kommando samma sak med --autostash:
# ändringarna läggs undan, uppdateringen går in, och de läggs tillbaka. Det är git:s egen
# sammanslagning, inte en egen påhittad.
if ! git pull --ff-only; then
	echo "Egna ändringar i trädet (eller egna commits) — försöker igen med ändringarna undanlagda:"
	git pull --ff-only --autostash
fi

echo
echo "Klart. Senaste commit i den här kopian:"
git log --oneline -1
