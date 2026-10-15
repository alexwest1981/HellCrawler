#!/usr/bin/env bash
# UVPROVET — bevisar att en handvriden UV överlever kedjan när objektet äger sin UV (uv_keep), och att
# den SKRIVS ÖVER när det inte gör det (negativ kontroll; utan den vet man inte om måttet kan falla).
#
# MÄTT: Sign_Weaver_Board flagga=True  +3971.400 -> +3971.400  (behållen)
#       Sign_Bar_1_Board  flagga=False +1061.280 -> -1061.280  (omskriven, som väntat)
#
#   bash tools/uvprov.sh [modell.blend]        (standard: finaliserad_alex.blend i scratch)
set -e
MODELL="${1:-$HOME/.hermes/cache/scratch/finalisering/finaliserad_alex.blend}"
TMP="$(mktemp -d)"
cp "$MODELL" "$TMP/uvprov.blend"
blender -b "$TMP/uvprov.blend" --python tools/uvprov_setup.py \
    --python tools/apply_pixel_textures.py --python tools/uvprov_kolla.py 2>&1 |
    grep -E "FÖRE |EFTER |UV behållen"
echo "(jämför de två raderna: flagga=True ska vara lika, flagga=False ska ha bytt tecken)"
