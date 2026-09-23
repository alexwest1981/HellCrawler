#!/usr/bin/env bash
# Kontaktkarta över fienderna: alla med namn, hp, skada och sex rutor var — för att kunna SE vad
# som finns i spelet utan att starta det. Källan är data/enemies/00_bestiary.json, alltså exakt
# samma siffror som spelet spelar med; ritas om varje gång den körs så den inte kan bli inaktuell.
#
#   tools/kontaktkarta.sh            -> game/assets/enemies/_kontaktkarta.png
#   tools/kontaktkarta.sh /tmp/foo.png
set -e
cd "$(dirname "$0")/../game"
ut="${1:-assets/enemies/_kontaktkarta.png}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bakgrund='#16151a'
text='#e8e4dc'

# En rad per fiende: text till vänster, de sex rutorna till höger.
python3 - "$tmp" <<'PY'
import json, sys, pathlib
tmp = pathlib.Path(sys.argv[1])
fiender = json.load(open("data/enemies/00_bestiary.json"))
rader = []
for i, f in enumerate(fiender):
    namn = f["name"]
    sort = "boss" if f.get("kind") == "boss" else "tier %d" % f["tier"]
    rad = f'{namn}\nhp {f["hp"]} · skada {f["damage"]} · {sort}'
    (tmp / f"text_{i:02d}.txt").write_text(rad)
    (tmp / f"namn_{i:02d}.txt").write_text(f['id'])
PY

i=0
while IFS= read -r id; do
  n=$(printf '%02d' "$i")
  magick "assets/enemies/$id.png" -filter point -resize 300% \
    -background "$bakgrund" -alpha remove -alpha off "$tmp/strip_$n.png"
  magick -size 330x120 -background "$bakgrund" -fill "$text" -pointsize 21 -gravity west \
    -font "DejaVu-Sans" caption:"@$tmp/text_$n.txt" "$tmp/textbild_$n.png"
  magick "$tmp/textbild_$n.png" "$tmp/strip_$n.png" +append "$tmp/rad_$n.png"
  i=$((i + 1))
done < <(python3 -c 'import json;print("\n".join(f["id"] for f in json.load(open("data/enemies/00_bestiary.json"))))')

magick -size 1080x54 -background "$bakgrund" -fill "$text" -pointsize 30 -font "DejaVu-Sans" \
  -gravity center caption:"HellCrawler — fienderna (sex rutor var: andas in, andas ut, spänner, hugger, träffad, död)" \
  "$tmp/rubrik.png"
magick "$tmp/rubrik.png" $(ls "$tmp"/rad_*.png | sort) -append \
  -border 10 -bordercolor "$bakgrund" "$ut"
echo "skrev $ut ($(identify -format '%wx%h' "$ut"), $i fiender)"
