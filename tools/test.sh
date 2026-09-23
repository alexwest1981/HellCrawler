#!/usr/bin/env bash
# Kör hela sviten. Exit != 0 = något är fel.
# timeout per test: ett script som inte kan parsas hänger annars i evighet (124 = fel).
# --import först: nya class_name-registreringar hamnar annars inte i klasscachen och alla
# tester faller på "Identifier X not declared" i stället för på det man mätte.
set -uo pipefail
cd "$(dirname "$0")/../game" || exit 1
timeout 200 godot --headless --path . --import >/dev/null 2>&1
fail=0
# Tillgångarna först: rutorna och ljudet är genererade av verktyg, och deras egna prov mäter
# sådant Godot-testet inte kan se (palett, ljushet, sömlös skarv).
echo "=== tools/gen_tiles.py --check"
python3 ../tools/gen_tiles.py --check || fail=1
echo "=== tools/gen_fx.py --check"
python3 ../tools/gen_fx.py --check || fail=1
echo "=== tools/gen_props.py --check"
python3 ../tools/gen_props.py --check || fail=1
echo "=== tools/gen_sfx.py --check"
python3 ../tools/gen_sfx.py --check || fail=1
echo "=== tools/gen_enemy_art.py --check"
python3 ../tools/gen_enemy_art.py --check || fail=1
# Fienderna ur Alex' eget ark (tio monster han ritade): rutornas mått, fötternas rad och att alla sex
# rutor rör sig. De tio är undantagna i generatorn och i palettkontrollen, så utan det här provet
# vore hans bilder de enda tillgångarna utan en grind.
echo "=== tools/gen_enemy_sheet.py --check"
python3 ../tools/gen_enemy_sheet.py --check || fail=1
# Kortikonerna ur Alex' ark (potionsarket): 64x64, tat nog och bara palettfarger — samma krav som
# test_assets.gd staller pa de 56 aldre ikonerna. Utan det har provet vore hans ikoner de enda
# tillgangarna utan grind.
echo "=== tools/gen_card_icons.py --check"
python3 ../tools/gen_card_icons.py --check || fail=1
# Språkfilerna: samma nycklar i alla 13, inga tomma rader. Utan detta prov kan en nyckels felstavning
# i en fil bli en tom ruta i gränssnittet på ett språk ingen av oss läser.
echo "=== tools/gen_i18n.py --check"
python3 ../tools/gen_i18n.py --check || fail=1
# Summan räknas ur ok/FEL-raderna, inte ur filernas egna sammanfattningar: de är indragna med
# två mellanslag och försvinner ur en naiv summering. Mätt: ett sådant försök gav 559 i stället
# för 567 — åtta kontroller var tysta. Summan skrivs därför av skriptet självt.
tmp=$(mktemp)
{
  for t in tests/test_*.gd; do
    echo "=== $t"
    timeout 120 godot --headless --path . --script "res://$t" || echo "  ##FEL## $t föll: exit $?"
  done
} 2>&1 | tee "$tmp"
ok=$(grep -c '^  ok ' "$tmp")
fel=$(grep -c '^  FEL ' "$tmp")
stupade=$(grep -c '^  ##FEL## ' "$tmp")
echo "=== TOTALT: $((ok + fel)) kontroller, $fel fel"
rm -f "$tmp"
## Röret ovan kör vänsterledet i ett eget skal, så ett fail=1 därifrån når aldrig hit: hela
## sviten kunde vara röd och scriptet ändå avsluta med 0. Utgångskoden sätts därför ur loggen:
## FEL-raderna OCH en testfil som föll (timeout eller parsefel skriver ingen FEL-rad).
test "$fel" -eq 0 || fail=1
test "$stupade" -eq 0 || fail=1
exit $fail
