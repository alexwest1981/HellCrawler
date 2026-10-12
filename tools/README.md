# tools/ — kort register

Prov som rör spelkoden körs under `game/` och läser `user://`, som ligger under `$XDG_DATA_HOME`.
Det avgör HUR de måste startas:

- **`tools/test.sh`** — hela sviten (konsten, ljudet, språket, alla `tests/test_*.gd`). Sätter en
  egen, tom `XDG_DATA_HOME` per körning (M108) så inget prov ser spelarens sparfil. Kör den här för
  att veta om något gått sönder.

- **`tools/ett_prov.sh <testsökväg>`** — ETT prov fristående, med samma tomma `XDG_DATA_HOME` som
  sviten. Utan den läser ett enskilt prov spelarens riktiga `user://` och kan svara annat än sviten
  (mätt: `tests/test_gui.gd` gav 3 fel fristående och 0 i sviten — samma kod).

      tools/ett_prov.sh tests/test_gui.gd

Ett enskilt prov ska alltid startas via `ett_prov.sh`, inte med ett rått `godot ... --script`, om
svaret ska gå att jämföra med sviten.
