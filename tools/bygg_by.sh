#!/bin/sh
# Bygger om byns husmodeller från Blender och importerar dem till Godot.
# Alex: "gör allt redo så jag kan editera ALLT själv i antingen blender eller en egen editor".
#
#   tools/bygg_by.sh            bygg alla hus ur assets/by_hus_3d.blend-riggen (tools/gen_by_hus3d.py)
#   tools/bygg_by.sh --kolla    importera bara om modellerna och rapportera triangelantal
#
# Tar 8–9 minuter för alla sex husen: Blender bygger geometrin, Godot importerar GLB-filerna.
set -e
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

blender --background --python tools/gen_by_hus3d.py || {
	echo "Blender-bygget misslyckades — se utskriften ovan" >&2
	exit 1
}

# godot --import finns inte i 4.8.dev7; editorn med --quit gör samma importjobb.
(cd game && godot --headless --editor --quit >/dev/null 2>&1)

echo "klart: game/assets/by/models/*.glb är ombyggda och importerade"
