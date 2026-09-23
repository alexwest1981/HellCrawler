#!/usr/bin/env bash
# Startikon i startmenyn för den som laddat hem spelet från GitHub.
#
# Skriptet hittar sin egen katalog och skriver en .desktop-post som pekar på DEN hämtade kopian —
# därför står inga sökvägar hårdkodade här. Källkodsprojekt behöver ingen byggnad: posten startar
# trädet, alltså alltid den senaste versionen.
#
# Användning:
#   ./install.sh              lägg in startikonen
#   ./install.sh --uninstall  ta bort den
#
# Enda beroendet är godot 4 (i PATH eller i ~/.local/bin). Saknas det installeras posten ändå —
# spelet säger själv till när det startar — och skriptet skriver vad som fattas.
#
# VARIABELNAMNET MÅSTE VARA ASCII: skalenligt "HÄR=..." tolkas inte som en tilldelning av bash utan
# körs som ett kommando ("HÄR=/sökväg: No such file or directory"). Texten och kommentarerna är
# svenska, men identifierarna hålls i a-z.
set -euo pipefail

HAR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMN="hellcrawler"
MAL="$HOME/.local/share/applications/$NAMN.desktop"
IKON="$HAR/game/assets/cards/black_lantern.png"
START="$HAR/tools/play.sh"

if [ "${1:-}" = "--uninstall" ]; then
	rm -f "$MAL"
	if command -v update-desktop-database >/dev/null; then
		update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
	fi
	echo "Startikonen är borttagen: $MAL"
	exit 0
fi

if [ ! -x "$START" ] || [ ! -f "$IKON" ]; then
	echo "FEL: ser inte spelet härifrån ($HAR)." >&2
	echo "     Väntade $START och $IKON — kör skriptet från den hämtade katalogen." >&2
	exit 1
fi

# En hämtad zip (till skillnad från en git-klon) tappar körbiten.
chmod +x "$START"

if ! command -v godot >/dev/null && [ ! -x "$HOME/.local/bin/godot" ]; then
	echo "VARNING: hittar inget godot. Startikonen läggs in ändå, men spelet startar inte förrän"
	echo "         godot 4 finns i PATH eller i ~/.local/bin. (godotengine.org/download)"
fi

mkdir -p "$(dirname "$MAL")"
cat > "$MAL" <<-EOF
	[Desktop Entry]
	Type=Application
	Name=HellCrawler
	Comment=Startar spelet ur källkoden (alltid senaste versionen)
	Exec=$START
	Icon=$IKON
	Terminal=false
	Categories=Game;
	StartupNotify=false
EOF

if command -v update-desktop-database >/dev/null; then
	update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi
if command -v desktop-file-validate >/dev/null; then
	desktop-file-validate "$MAL" || true
fi

echo "Klart. Sök efter HellCrawler i startmenyn (posten ligger i $MAL)."
echo "Ser du den inte direkt: starta om skalet/fältet — menyerna läser sina poster vid start."
