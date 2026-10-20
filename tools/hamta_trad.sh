#!/usr/bin/env bash
# Hämtar Poly Havens pinjeträd (CC0) — modellen är ~900 MB uppackad och ligger därför inte i git.
#   bash tools/hamta_trad.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p game/assets/by/trad
python3 - <<'PY'
import json, urllib.request, os
mål = "game/assets/by/trad"
t = json.load(urllib.request.urlopen("https://api.polyhaven.com/files/pine_tree_01"))
g = t["gltf"]["1k"]["gltf"]
urllib.request.urlretrieve(g["url"], os.path.join(mål, "pine_tree_01.gltf"))
for post in g.get("include", {}).values():
    u = post["url"]
    urllib.request.urlretrieve(u, os.path.join(mål, u.split("/")[-1]))
print("hämtat:", len(os.listdir(mål)), "filer")
PY
