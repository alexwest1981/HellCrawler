# HellCrawler 0.2.0: torches, voxels and four times the floor

0.1.0 was the first version. Since then the dungeons were lit, every monster was rebuilt as a 3D model, and the floors grew to four times their size. The combat rules are the same.

## The floors are lit

Torches hang on the walls, the lantern throws further, and rooms that used to stand empty have something in them. The flames have a glow in the air around them, and dust shows only where the light reaches it.

The chandeliers used to lie on the floor. The art carries a chain at the top, and the placement rule gave every prop its bottom edge on the floor, so a chandelier blocked the walkway and the floor crack, the one prop that belongs on the ground, followed the same rule. They hang from the ceiling now, with the light at the flames instead of a metre above them.

## The monsters are models

Every monster is drawn as a 3D model built from its own sprite sheet: one cube per visible pixel, 64 cells high, and the chests and candelabras are built the same way. The cell density doubled in this release because the first pass read as rough-hewn.

A monster comes apart when it dies. Ten steps over about a second, so you watch the body fall, and the pieces land on the floor with weight of their own. Hits throw chips off the body while it still stands, and their count follows the damage: 6 at the least, 30 at the most, plus two per combo step. The chips are meant to work as a health reading, the way voxels come off a wall in Teardown.

## Four times the floor

A floor is exactly four times the area now: 34x34, 42x42 and 50x50 tiles, against 17x17, 21x21 and 25x25 before. Measured over 7830 generated floors in one run, the walkable tiles per floor went from 96, 152 and 229 to 470, 778 and 1192, and the walk from the start to the boss from 17, 26 and 34 steps to 42, 57 and 71. That walk also varies more between floors than it used to, a standard deviation of 8 to 12 steps against 2.

A few extra corridors between rooms that are not neighbours turn the floor into a network instead of one chain, and the boss is picked among the four farthest rooms instead of always waiting in the last one. The fight budget is per floor and did not change, so the bigger floors give you more to walk, not more gold. They cost frames, measured: 47 fps against 60 on the old floor size.

## Room for the whole encounter

An encounter has held two or three enemies for a while, but they stood in a column with the back one inside the front one, so you saw one monster and fought one monster at a time. How many fit in a row is counted from the room now: in a hall two or three stand side by side, and the next row waits 0.6 m behind. Both in the front row hit you, so the fight is the group you walked into.

## Cards and the tree

Cards are 25 percent bigger, 130x180 against 104x144, and they are no longer translucent. They sat at 0.94 to 0.97 alpha and let the dungeon show through, which is hard to plan with. The reward card turns in real perspective when you pick it, and a slash with four randomized dials (angle, direction, radius, sweep) runs over the enemy you hit.

The skill tree is 93 nodes on a spiral out of the middle, opens zoomed in, and pans and zooms with no edge to it. The blacksmith's node rows are translated from what each node does, and an editor places the nodes by hand.

Editors write the same data files the game reads: the world map, where you drag the places and Z undoes, the enemy editor, where you draw with the mouse, pick from the game's own 27 colors and mark the cells that glow, and the tree editor. The map file is written atomically, so an interrupted save cannot leave half a map.

Thirteen languages are in, the menu leads with English, and a test fails if the code asks for a key that no language file holds. The window title carries the commit of the source you are running; an exported build has no git folder and says so.

## What the tests caught

The headless suite is 2,836 checks across the game, the art, the sound and the languages, and it came out green on this build. Three of the runs turned out to be reading the player's own save file, because a bare headless run picks up the save from the user data directory and the save changes the starting deck. Those tests were measuring one machine's progress rather than the code. Each run gets a private data directory now. One test file run by hand measured 266 checks and 3 errors against the player's save, and 267 checks and 0 errors with a fresh directory.

A shader had a Swedish letter in a uniform name and never compiled, so the props were not drawn at all, and an earlier measurement of "71 props changed nothing in the image" had been measuring that broken shader.

The hit flash set the sprite color back to white, and white has alpha 1.0, so a semi-transparent ghost turned fully opaque on its first hit and stayed that way for the rest of the fight.

## What is thin

The Windows build exists, and the game has only ever been run on Linux with an NVIDIA card. Sound is in and has never been judged by an ear in a real speaker. The new floors are large, and the rooms mostly hold fights, a chest and three torches. Hand-made room modules are the next real step if the floors are to feel built.

Windows, Linux and a browser build are on the downloads page.
